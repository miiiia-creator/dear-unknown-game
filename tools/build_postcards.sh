#!/usr/bin/env bash
# Turn source postcard films into what the game actually loads.
#
# For each assets/postcards/<city>.mp4 this produces:
#   <city>.jpg  — frame zero, the still the reveal mosaic resolves into
#   <city>.ogv  — a seamless loop, the only video format Godot decodes
#
# Two things this handles that are easy to get wrong:
#
#  * Generated "looping" clips rarely loop. They drift from first frame to last
#    and cut back hard. Playing forward then reversed is seamless by
#    construction and, for a slow push-in, reads as breathing rather than as a
#    trick.
#  * The still must be frame zero of the same film, or the hand-off from the
#    resolved image to the playing video jumps.
#
# Usage:  tools/build_postcards.sh [city ...]     (default: all mp4s present)

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/assets/postcards"

# Homebrew's default ffmpeg dropped libtheora; ffmpeg-full keeps it but is
# keg-only, so it is not on PATH.
FFMPEG=""
for candidate in /opt/homebrew/opt/ffmpeg-full/bin/ffmpeg \
                 /usr/local/opt/ffmpeg-full/bin/ffmpeg \
                 "$(command -v ffmpeg || true)"; do
    if [ -x "$candidate" ] && "$candidate" -hide_banner -encoders 2>/dev/null | grep -qi theora; then
        FFMPEG="$candidate"
        break
    fi
done
if [ -z "$FFMPEG" ]; then
    echo "No ffmpeg with libtheora found. Install with: brew install ffmpeg-full" >&2
    exit 1
fi

QUALITY="${THEORA_QUALITY:-6}"   # 0-10; 6 keeps the grain without ballooning

cd "$DIR"

if [ "$#" -gt 0 ]; then
    sources=("$@")
else
    sources=()
    for f in *.mp4; do
        [ -e "$f" ] || continue
        sources+=("$(basename "$f" .mp4)")
    done
fi

for name in "${sources[@]}"; do
    src="$name.mp4"
    [ -e "$src" ] || { echo "skip $name (no $src)"; continue; }

    # City ids are lowercase; source files arrive however they arrive.
    city="$(echo "$name" | tr '[:upper:]' '[:lower:]')"

    # A hand-placed still is usually higher resolution than the film, and the
    # mosaic reveal is what looks at it most closely — so never clobber one.
    # Only extract frame zero when the city has no still of its own.
    if [ -e "$city.jpg" ] && [ ! -e "$city.fromvideo" ]; then
        echo "  keeping existing $city.jpg (delete it to re-extract from the film)"
    else
        "$FFMPEG" -v error -y -i "$src" -vf "select=eq(n\,0)" -vframes 1 \
            -q:v 2 "$city.jpg"
        touch "$city.fromvideo"
    fi

    "$FFMPEG" -v error -y -i "$src" -an -filter_complex \
        "[0:v]split[a][b];[b]reverse[r];[a][r]concat=n=2:v=1[out]" \
        -map "[out]" -c:v libtheora -q:v "$QUALITY" "$city.ogv"

    printf "%-10s still %-7s loop %-8s (%ss)\n" \
        "$city" \
        "$(du -h "$city.jpg" | cut -f1)" \
        "$(du -h "$city.ogv" | cut -f1)" \
        "$("$FFMPEG" -v error -i "$city.ogv" -f null - 2>&1 >/dev/null; \
           ffprobe -v error -show_entries format=duration -of csv=p=0 "$city.ogv")"
done
