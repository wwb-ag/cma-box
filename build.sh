#!/usr/bin/env bash
# Build the convertible box and its insert to (binary) STL.
# Prefers the OpenSCAD 2026 AppImage in bin/ (manifold kernel: box render
# 0.29s vs 203s on 2021.01/CGAL, binary STL export); falls back to a
# 2021.01 install (ASCII STL only).
set -euo pipefail
cd "$(dirname "$0")"

APPIMAGE="$(ls "$PWD"/bin/OpenSCAD-*.AppImage 2>/dev/null | head -n1 || true)"
if [[ -n "$APPIMAGE" && -x "$APPIMAGE" ]]; then
    OPENSCAD=("$APPIMAGE" --export-format binstl)
else
    echo "note: no OpenSCAD AppImage in bin/, falling back to system openscad (ASCII STL)" >&2
    OPENSCAD=(openscad)
fi

# OpenSCAD refuses to write into a nonexistent output dir (exit 1); fresh
# clones have no git-ignored build/.
mkdir -p build
for v in duty_division duty_division_insert; do
    "${OPENSCAD[@]}" -o "build/$v.stl" \
        -D '$fs=0.05' -D '$fa=0.05' \
        "openscad/$v.scad"
done
