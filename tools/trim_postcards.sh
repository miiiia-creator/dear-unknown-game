#!/usr/bin/env bash
# Cut the generator's "豆包AI生成" watermark off the bottom of every clip, and
# re-cut the matching still from the same frame so the card looks identical
# whether or not the motion has loaded yet.
#
# Cropping rather than painting over it: the clips are 4:3 and the card is 3:2,
# so the bottom rows were being thrown away by the cover crop anyway. Taking
# them here removes the watermark completely and leaves a video that is already
# the card's shape — no crop at all at runtime.
#
# Masters live in assets/postcards/source/ (kept out of Godot's import path by
# .gdignore). This reads those and writes the shipped files, so it is safe to
# run again after tweaking the numbers.
#
# Run:  tools/trim_postcards.sh [city ...]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/assets/postcards"
SRC="$DIR/source"

for candidate in /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg \
                 /usr/local/opt/ffmpeg-full/bin/ffmpeg \
                 "$(command -v ffmpeg || true)"; do
	if [ -x "$candidate" ] && "$candidate" -hide_banner -encoders 2>/dev/null | grep -q libtheora; then
		FFMPEG="$candidate"
		break
	fi
done
[ -n "${FFMPEG:-}" ] || { echo "No ffmpeg with libtheora. brew install ffmpeg-full" >&2; exit 1; }

# Inset rather than a plain top crop: the generator paints a cream border into
# the frame, and the card already has a paper edge of its own. Thirty-six rows
# in on every side drops both that border and the watermark, and 888x592 is
# the card's own 3:2 — so nothing is cropped again at runtime.
CROP="crop=888:592:36:36"

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
	targets=()
	for f in "$SRC"/*.orig.ogv; do
		[ -e "$f" ] || continue
		targets+=("$(basename "$f" .orig.ogv)")
	done
fi

for city in "${targets[@]}"; do
	master="$SRC/$city.orig.ogv"
	[ -f "$master" ] || { echo "no master for $city, skipping"; continue; }
	"$FFMPEG" -v error -y -i "$master" -vf "$CROP" -c:v libtheora -q:v 7 -an "$DIR/$city.ogv"
	# Frame zero of the same crop: the still and the first video frame agree.
	"$FFMPEG" -v error -y -i "$master" -vf "$CROP" -frames:v 1 -q:v 3 "$DIR/$city.jpg"
	printf "%-10s video %6.1f MB   still %5.0f KB\n" "$city" \
		"$(stat -f%z "$DIR/$city.ogv" | awk '{print $1/1048576}')" \
		"$(stat -f%z "$DIR/$city.jpg" | awk '{print $1/1024}')"
done
