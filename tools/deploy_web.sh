#!/usr/bin/env bash
# Build the web version and publish it to GitHub Pages.
#
# Every step that used to be done by hand is here, because doing it by hand is
# how the shipped index.html ended up describing a .pck that was no longer the
# one being served.
#
# Run:  tools/deploy_web.sh ["commit message"]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/web"
PAGES="$ROOT/build/pages"
MSG="${1:-Web build}"

cd "$ROOT"

echo "-- exporting"
godot --headless --path . --export-release "Web" "$OUT/index.html" >/dev/null

echo "-- the share page rides along"
cp "$ROOT/web/postcard.html" "$OUT/postcard.html"
rm -f "$OUT"/*.import

# The looping paintings are kept out of the pack — ten megabytes on a download
# that already takes half a minute — and served as plain files instead. A card
# fetches its own the first time somebody opens it.
echo "-- postcard motion as loose files"
mkdir -p "$OUT/motion"
cp "$ROOT"/assets/postcards/*.ogv "$OUT/motion/" 2>/dev/null || true
ls "$OUT/motion" | sed "s/^/   /"

# Godot's own service worker installs alongside the previous one and waits for
# every tab to close before taking over. On a redeploy that means the old
# worker keeps serving the old index.html and index.js while the new .wasm and
# .pck come from the network — a loader and a payload from different builds,
# which hangs on the loading screen forever. Patch it to take over at once and
# reload the page when it replaces an older version.
echo "-- making the service worker replace itself cleanly"
python3 - "$OUT/index.service.worker.js" <<'PATCH'
import sys, pathlib

path = pathlib.Path(sys.argv[1])
src = path.read_text()

install_old = "event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));"
install_new = ("event.waitUntil(caches.open(CACHE_NAME)"
               ".then((cache) => cache.addAll(CACHED_FILES))"
               ".then(() => self.skipWaiting()));")

activate_old = """	).then(function () {
		// Enable navigation preload if available.
		return ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();
	}));"""
activate_new = """	).then(async function (removed) {
		if ('navigationPreload' in self.registration) {
			await self.registration.navigationPreload.enable();
		}
		await self.clients.claim();
		// Only when this worker replaced an older build: the page currently open
		// was served by that build and must not keep running against this one.
		if (removed && removed.length > 0) {
			for (const client of await self.clients.matchAll({ type: 'window' })) {
				client.navigate(client.url);
			}
		}
	}));"""

for old, new in ((install_old, install_new), (activate_old, activate_new)):
    if old not in src:
        sys.exit("service worker template changed; patch no longer applies")
    src = src.replace(old, new)

path.write_text(src)
PATCH

echo "-- staging"
mkdir -p "$PAGES"
find "$PAGES" -maxdepth 1 -type f ! -name ".nojekyll" -delete
rm -rf "$PAGES/motion"
cp -R "$OUT"/. "$PAGES"/
touch "$PAGES/.nojekyll"

echo "-- publishing"
cd "$PAGES"
git add -A
if git diff --cached --quiet; then
	echo "   nothing changed"
	exit 0
fi
git commit -q -m "$MSG"
git push -q origin main
echo "-- pushed; Pages usually takes a minute"
