#!/usr/bin/env bash
# Trace CMA-logo.avif (this dir) -> cma_logo.svg (this dir)
# The AVIF logo is beige on transparent; the alpha channel is the silhouette.
# Requirements: ImageMagick (convert), uvx (for vtracer).
set -euo pipefail
cd "$(dirname "$0")"
PAD=20
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
convert CMA-logo.avif -alpha extract -threshold 50% \
    -crop 605x109+7+10 +repage "$TMP/logo.png"
# pad the content-tight crop with transparent (black) margin: canvas = 645x149
convert "$TMP/logo.png" -bordercolor black -border ${PAD}x${PAD} "$TMP/logo.png"
uvx --from vtracer vtracer --input "$TMP/logo.png" --output cma_logo.svg \
    --colormode bw --filter_speckle 16
# OpenSCAD 2021.01 SVG import: WITHOUT a viewBox it imports 1:1
# (1 unit = 1 mm, no y-flip) - the logo would render oversized and
# misoriented. With viewBox it does the 0.75pt (0.352778 mm/unit)
# conversion and the y-flip, exactly like the duty_division.scad
# expects. Add viewBox if the tracer did not emit one.
if ! grep -q 'viewBox' cma_logo.svg; then
    sed -i 's|<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="645" height="149">|<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="645" height="149" viewBox="0 0 645 149">|' cma_logo.svg
fi
echo "wrote $(pwd)/cma_logo.svg ($(stat -c%s cma_logo.svg) bytes, canvas 645x149 incl. ${PAD}px pad)"
