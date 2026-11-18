#!/usr/bin/env python3
"""Generate SVG outlines (brand font, Rubik) for the gauge-box labels.

OUTPUT / SAMPLING: every SVG is normalized so the CAP HEIGHT is exactly
100 units (1 unit = 0.352778 mm after OpenSCAD's viewBox import, so a
100-unit cap imports as 35.2778 mm; the .scad scales by
label_size / 35.2778 to hit the requested text size). Glyph coordinates
from the font are y-up; they are flipped to SVG's y-down via the path
transform. The bbox encloses all glyphs (including the small
descender of "/"), baseline near the bottom.

Layout: one glyph after another using hmtx advances; no kerning (fine
for label text).

One label set per division; every set produces four SVGs written to
label_svgs/<set>/ plus two machine-readable companions consumed by the
.scad side and the line-art renderer (so the advance-width/height
numbers exist in exactly one place):

  label_svgs/label_data.scad - LABEL_DATA rows [name, text, advance,
    height] for cma_box_lib.scad's label_svg() lookup,
  label_svgs/label_data.json - the same rows for assets/render.

Usage: uv run --with fonttools python3 assets/font/create_label_svgs.py
"""

import json
import os

from fontTools.misc.transform import Transform
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

# Nominal gauge dims per division (mm); optics height = height + optic_extra
SETS = {
    "duty": dict(length=210, height=145, optic_extra=30, width=40),
    "sport": dict(length=225, height=155, optic_extra=30, width=45),
}

CAP = 100.0  # normalized cap height, units

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "label_svgs")

# The Rubik font binaries are no longer shipped in this repo (only
# OFL.txt stays, see assets/font/Rubik/OFL.txt). Resolve the font from
# the repo (if present), the user font dir, or the system font dirs.
FONT_CANDIDATES = [
    os.path.join(HERE, "Rubik", "static", "Rubik-SemiBold.ttf"),
    os.path.join(os.path.expanduser("~"), ".local", "share", "fonts",
                 "Rubik-SemiBold.ttf"),
    os.path.join(os.path.expanduser("~"), ".fonts", "Rubik-SemiBold.ttf"),
    "/usr/share/fonts/truetype/rubik/Rubik-SemiBold.ttf",
]
FONT = next((p for p in FONT_CANDIDATES if os.path.isfile(p)), None)
if FONT is None:
    raise SystemExit(
        "Rubik-SemiBold.ttf not found. It is not shipped with the repo "
        "(only the OFL license is). Install it, e.g.:\n"
        "  mkdir -p ~/.local/share/fonts && cp Rubik-SemiBold.ttf ~/.local/share/fonts/\n"
        f"Searched: {FONT_CANDIDATES}")

os.makedirs(OUT, exist_ok=True)

# Per set: (file name, string) - the .scad label modules reference these
# SVGs by "set/name" through label_data.scad; if you change a string
# below, regenerate (the .scad side needs no edits - it reads the
# advance/height values from label_data.scad).
def labels_for(set_name, d):
    return [
        (f"{set_name}/insert_title", f"{set_name.upper()} DIVISION"),
        (f"{set_name}/insert_dims",
         f"Length: {d['length']} Height: {d['height']} Width: {d['width']}"),
        (f"{set_name}/floor_title", f"{set_name.upper()} OPTIC DIVISION"),
        (f"{set_name}/floor_dims",
         f"Length: {d['length']} Height: {d['height']}/{d['height'] + d['optic_extra']} "
         f"Width: {d['width']}"),
    ]

font = TTFont(FONT)
upem = font["head"].unitsPerEm
cmap = font.getBestCmap()
glyph_set = font.getGlyphSet()
hmtx = font["hmtx"]
os2 = font["OS/2"]
cap_fu = os2.sCapHeight or max(glyph_set["D"].bounds[3], glyph_set["H"].bounds[3])
# font units -> normalized units
sc = CAP / cap_fu
space_adv = hmtx[cmap[ord(" ")]][0]

results = {}
for set_name, d in SETS.items():
    set_dir = os.path.join(OUT, set_name)
    os.makedirs(set_dir, exist_ok=True)
    for fname, text in labels_for(set_name, d):
        glyphs = []
        x_cursor = 0
        ymin = 1e9
        ymax = -1e9
        for ch in text:
            if ch == " ":
                x_cursor += space_adv
                continue
            gname = cmap[ord(ch)]
            g = font["glyf"][gname]
            ymin = min(ymin, g.yMin * sc)
            ymax = max(ymax, g.yMax * sc)
            glyphs.append((gname, x_cursor))
            x_cursor += hmtx[gname][0]

        # advance width (units)
        w = x_cursor * sc
        # svg height (y-down)
        H = ymax - ymin

        # explicit affine: y_svg = -(y_norm) + (H + ymin) so the ink bbox
        # EXACTLY fills 0..H (cap top -> 0, descender -> H).

        T_glob = Transform(sc, 0, 0, -sc, 0, H + ymin)
        parts = []
        for gname, xc in glyphs:
            spen = SVGPathPen(glyph_set)
            T_glyph = Transform().translate(xc * sc, 0)
            glyph_set[gname].draw(TransformPen(spen, T_glyph.transform(T_glob)))
            d_attr = spen.getCommands()
            if d_attr:
                parts.append(d_attr)
        svg = (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.3f}" height="{H:.3f}" '
            f'viewBox="0 0 {w:.3f} {H:.3f}">\n'
            f'<!-- {fname}: "{text}" | Rubik SemiBold, cap 100 units, '
            f'advance {w:.2f}, height {H:.2f} -->\n'
            f'<path d="{" ".join(parts)}"/>\n</svg>\n'
        )
        path = os.path.join(set_dir, os.path.basename(fname) + ".svg")
        with open(path, "w") as f:
            f.write(svg)
        results[fname] = dict(text=text, adv=round(w, 2), h=round(H, 2))
        print(f"{fname:26s} advance {w:8.2f}  height {H:6.2f}  -> {path}")

# label_data.scad - the single source the .scad side reads (do not hand-
# copy advance/height values into OpenSCAD code anywhere).
with open(os.path.join(OUT, "label_data.scad"), "w") as f:
    f.write("// GENERATED by assets/font/create_label_svgs.py - DO NOT EDIT.\n")
    f.write("// One row per label SVG: [name, text, advance, height] in\n")
    f.write("// normalized SVG units (cap height = 100 units = 35.2778 mm at\n")
    f.write("// 1:1 import). Consumed by openscad/cma_box_lib.scad.\n")
    f.write("LABEL_DATA = [\n")
    for name, r in results.items():
        f.write(f'    ["{name}", "{r["text"]}", {r["adv"]:.2f}, {r["h"]:.2f}],\n')
    f.write("];\n")

# label_data.json - same rows for assets/render/make_lineart.py.
with open(os.path.join(OUT, "label_data.json"), "w") as f:
    json.dump(results, f, indent=2)
    f.write("\n")

print(f"wrote {os.path.join(OUT, 'label_data.scad')} and label_data.json "
      f"({len(results)} labels, {len(SETS)} sets)")
