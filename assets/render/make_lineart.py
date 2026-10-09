#!/usr/bin/env python3
"""Vector line-art renders for The Box (clean black-on-white outlines).

Parses the binary STLs (build/*.stl), runs hidden-line removal per
orthographic/iso view (numpy painter depth buffer over front-facing
triangles), and draws the surviving edges with matplotlib. No OpenSCAD
shading, no raster dither - true vector lines, PNG + SVG per view.

Edge rules (d = normal . view_dir; states front/back/edge-on):
  {front,back}            -> silhouette, kept
  {front,front} sharp     -> kept (engravings, cavity walls, corners;
                             smooth fillet facets at 0.05 deg drop out)
  {front,edge-on}         -> kept (vertical walls: opening contours)
  {edge-on,edge-on} sharp -> kept (concave wall-wall corners)
  then EVERYTHING is tested against the depth buffer (edge sampled at 4
  interior points): hidden lines - e.g. the pocket-floor label seen
  THROUGH the seated insert - are dropped.

Usage:
  uv run --with numpy --with matplotlib python3 assets/render/make_lineart.py
"""
import os
import struct

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.collections as mcoll
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BUILD = os.path.join(ROOT, "build")
OUT = os.path.join(ROOT, "assets", "render", "preview")
os.makedirs(OUT, exist_ok=True)

CREASE_DEG = 14.0   # min dihedral for a front-front crease to count
EPS = 0.02          # |n.vd| below this = edge-on (~1.15 deg)
GRID = 2200         # depth-buffer resolution
TOL = 0.15          # mm: edge sample depth vs visible surface tolerance

# Engraved TEXT regions (world xy per part, + rim plane z). Inside a
# region, edges lying ON the rim plane (the top-face cut contour, one
# label_depth=0.8 above the floor) are dropped; the floor contours are
# kept -> single-stroke outlines, like a font. A 3.6 mm engraving doubled
# rim+floor strokes into an unreadable scribble otherwise. The logo panel
# is NOT in a region (its inverted relief is drawn whole, reads fine).
# Rectangles from the .scad: label_svg centers (body/2, cy +- lh/2) and
# advance*size/100 widths (see assets/font/label_svgs header comments).
ENGRAVE = {
    "box": [
        # pocket-floor label: rim plane z = wall = 3.2, floor 2.4
        (3.6, 101.6, 87.0, 95.6, 3.2),     # floor_title (cap 6.5)
        (4.6, 100.6, 80.8, 87.4, 3.2),     # floor_dims   (cap 3.6)
    ],
    "insert": [
        # top-face label: rim plane z = body_d = 40, floor 39.2
        (10.5, 94.3, 14.6, 23.0, 40.0),    # insert_title (cap 8)
        (5.3, 99.5, 7.6, 14.0, 40.0),      # insert_dims  (cap 4)
    ],
}


def in_region(x0, y0, x1, y1, reg):
    lo_x, hi_x, lo_y, hi_y, _ = reg
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    return (lo_x <= cx <= hi_x) and (lo_y <= cy <= hi_y)


def load_binary_stl(path, offset=(0.0, 0.0, 0.0), tag=None):
    with open(path, "rb") as f:
        f.seek(80)
        (n,) = struct.unpack("<I", f.read(4))
        buf = np.frombuffer(f.read(n * 50), dtype=np.uint8).reshape(n, 50)
    tri = buf[:, 12:48].copy().view(np.float32).reshape(n, 3, 3).astype(np.float64)
    off = np.asarray(offset, dtype=float)
    tri += off
    key = np.round(tri.reshape(-1, 3), 4)          # weld 0.1um-apart verts
    uniq, inv = np.unique(key, axis=0, return_inverse=True)
    faces = inv.reshape(n, 3)
    nrm = np.cross(uniq[faces[:, 1]] - uniq[faces[:, 0]],
                   uniq[faces[:, 2]] - uniq[faces[:, 0]])
    ln = np.linalg.norm(nrm, axis=1)
    keep = ln > 1e-12                               # drop degenerate tris
    # IMPORTANT: filter faces AND normals together - misaligned nrm/faces
    # silently fabricates "silhouette" edges from back-facing triangles.
    return uniq, faces[keep], nrm[keep] / ln[keep][:, None], off, tag


def build_edges(faces):
    e = np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]])
    e = np.sort(e, axis=1)
    order = np.lexsort((e[:, 1], e[:, 0]))
    e, fid = e[order], np.tile(np.arange(len(faces)), 3)[order]
    key = e[:, 0].astype(np.int64) * (e[:, 1].max() + 2) + e[:, 1]
    first = np.flatnonzero(np.r_[True, key[1:] != key[:-1]])
    cnt = np.diff(np.r_[first, len(key)])
    e0 = fid[first]
    e1 = np.full(len(first), -1)
    has2 = cnt >= 2
    e1[has2] = fid[first[has2] + 1]
    return e[first], e0, e1


def orthobasis(vd):
    up0 = np.array([0.0, 0.0, 1.0])
    if abs(vd @ up0) > 0.95:
        up0 = np.array([0.0, 1.0, 0.0])
    right = np.cross(up0, vd)
    right /= np.linalg.norm(right)
    up = np.cross(vd, right)
    return right, up


VIEWS = {
    "iso":   np.array([1.0, -1.0, 1.1]) / np.linalg.norm([1, -1, 1.1]),
    "top":   np.array([0.0, 0.0, 1.0]),
    "front": np.array([0.0, -1.0, 0.0]),
    "end":   np.array([-1.0, 0.0, 0.0]),
}


def depth_buffer(pts, faces, vd, right, up, bbox):
    """Per-pixel max depth of front-facing triangles (visible-surface map)."""
    x0, x1, y0, y1 = bbox
    sx = (GRID - 1) / max(x1 - x0, 1e-9)
    sy = (GRID - 1) / max(y1 - y0, 1e-9)
    zbuf = np.full((GRID, GRID), -1e9, dtype=np.float64)
    A, B, C = pts[faces[:, 0]], pts[faces[:, 1]], pts[faces[:, 2]]
    d = np.cross(B - A, C - A) @ vd
    front = d > 1e-9
    A, B, C = A[front], B[front], C[front]
    AX = A @ right; AY = A @ up; dA = A @ vd
    BX = B @ right; BY = B @ up; dB = B @ vd
    CX = C @ right; CY = C @ up; dC = C @ vd
    gx0 = np.floor((np.minimum.reduce([AX, BX, CX]) - x0) * sx).astype(int) - 1
    gx1 = np.ceil((np.maximum.reduce([AX, BX, CX]) - x0) * sx).astype(int) + 1
    gy0 = np.floor((np.minimum.reduce([AY, BY, CY]) - y0) * sy).astype(int) - 1
    gy1 = np.ceil((np.maximum.reduce([AY, BY, CY]) - y0) * sy).astype(int) + 1
    v1x, v1y, v2x, v2y = BX - AX, BY - AY, CX - AX, CY - AY
    den = v1x * v2y - v2x * v1y
    n_tri = len(A)
    for i in range(n_tri):
        if den[i] == 0.0:
            continue
        ix0 = max(gx0[i], 0); ix1 = min(gx1[i], GRID)
        iy0 = max(gy0[i], 0); iy1 = min(gy1[i], GRID)
        if ix0 >= ix1 or iy0 >= iy1:
            continue
        xs = (np.arange(ix0, ix1) + 0.5) / sx + x0
        ys = (np.arange(iy0, iy1) + 0.5) / sy + y0
        px = xs[None, :] - AX[i]
        py = ys[:, None] - AY[i]
        u = (px * v2y[i] - py * v2x[i]) / den[i]
        v = (py * v1x[i] - px * v1y[i]) / den[i]
        m = (u >= 0) & (v >= 0) & (u + v <= 1)
        if not m.any():
            continue
        z = dA[i] + u * (dB[i] - dA[i]) + v * (dC[i] - dA[i])
        sub = zbuf[iy0:iy1, ix0:ix1]
        np.maximum(sub, np.where(m, z, -1e9), out=sub)
    return zbuf


def line_segments(parts, view_name):
    vd = VIEWS[view_name]
    right, up = orthobasis(vd)
    pts_all = np.concatenate([p[0] for p in parts])
    faces, off = [], 0
    for (u, f, _n, _o, _t) in parts:
        faces.append(f + off)
        off += len(u)
    faces = np.concatenate(faces)

    AX = pts_all @ right; AY = pts_all @ up
    pad = 0.03 * max(AX.max() - AX.min(), AY.max() - AY.min()) + 1
    bbox = (AX.min() - pad, AX.max() + pad, AY.min() - pad, AY.max() + pad)
    zbuf = depth_buffer(pts_all, faces, vd, right, up, bbox)
    x0, x1, y0, y1 = bbox
    sx = (GRID - 1) / (x1 - x0); sy = (GRID - 1) / (y1 - y0)

    out = []
    for (uniq, faces, nrm, off, tag) in parts:
        ue, e0, e1 = build_edges(faces)
        bad = e1 < 0
        e1 = np.where(bad, e0, e1)                    # boundary edge guard
        n0, n1 = nrm[e0], nrm[e1]
        s0 = np.sign(np.where(np.abs(n0 @ vd) < EPS, 0, n0 @ vd)).astype(int)
        s1 = np.sign(np.where(np.abs(n1 @ vd) < EPS, 0, n1 @ vd)).astype(int)
        crease = np.degrees(np.arccos(np.clip((n0 * n1).sum(1), -1, 1)))
        sharp = crease > CREASE_DEG
        sb = np.abs(s0 - s1) == 2
        ff = (s0 == 1) & (s1 == 1)
        fe = ((s0 == 1) & (s1 == 0)) | ((s0 == 0) & (s1 == 1))
        ee = (s0 == 0) & (s1 == 0)
        cand = sb | (ff & sharp) | fe | (ee & sharp)
        cand |= bad
        # drop the doubled rim-side contours of engraved text: inside a
        # label region, edges lying on the rim plane are the cut opening,
        # a duplicate of the floor contour 0.8 mm below -> scribble
        if tag in ENGRAVE:
            pa_r, pb_r = uniq[ue[:, 0]], uniq[ue[:, 1]]
            drop = np.zeros(len(ue), bool)
            for reg in ENGRAVE[tag]:
                lo_x, hi_x, lo_y, hi_y, rim_z = reg
                mx = (pa_r[:, 0] + pb_r[:, 0]) / 2 - off[0]
                my = (pa_r[:, 1] + pb_r[:, 1]) / 2 - off[1]
                # in-region: drop rim-plane contours (the top-face cut
                # opening) - a duplicate of the floor glyph contour 0.8 mm
                # below, which ghosts small text
                zhi = np.maximum(pa_r[:, 2], pb_r[:, 2]) - off[2]
                inside = ((mx >= lo_x) & (mx <= hi_x)
                          & (my >= lo_y) & (my <= hi_y))
                drop |= inside & (zhi > rim_z - 0.1)
            cand &= ~drop
        if not cand.any():
            continue
        ue_c = ue[cand]
        pa, pb = uniq[ue_c[:, 0]], uniq[ue_c[:, 1]]
        tt = np.linspace(0.15, 0.85, 4)[None, :, None]
        ex = pa[:, None, :] * (1 - tt) + pb[:, None, :] * tt   # (E,4,3)
        gx = ((ex @ right) - x0) * sx
        gy = ((ex @ up) - y0) * sy
        gi = np.clip(np.rint(gy).astype(int), 0, GRID - 1)
        gj = np.clip(np.rint(gx).astype(int), 0, GRID - 1)
        d = ex @ vd
        visible = ((d - zbuf[gi, gj]) > -TOL).any(1)
        sil_c = sb[cand]
        keep = sil_c | visible
        x_a, y_a = pa @ right, pa @ up
        x_b, y_b = pb @ right, pb @ up
        out.append(np.stack([x_a[keep], y_a[keep], x_b[keep], y_b[keep]], 1))
    out = [o for o in out if len(o)]
    return np.concatenate(out) if out else np.zeros((0, 4))


def draw(parts, view_name, name, lw=0.6):
    segs = line_segments(parts, view_name)
    if len(segs) == 0:
        print(f"{name}: NO SEGMENTS")
        return
    xmin, ymin = segs[:, [0, 2]].min(), segs[:, [1, 3]].min()
    xmax, ymax = segs[:, [0, 2]].max(), segs[:, [1, 3]].max()
    pad = 0.03 * max(xmax - xmin, ymax - ymin) + 1
    fig = plt.figure()
    ax_ = fig.add_axes([0, 0, 1, 1])
    ax_.add_collection(mcoll.LineCollection(
        segs.reshape(-1, 2, 2), colors="black", linewidths=lw))
    ax_.set_xlim(xmin - pad, xmax + pad)
    ax_.set_ylim(ymin - pad, ymax + pad)
    ax_.set_aspect("equal")
    ax_.axis("off")
    fig.set_size_inches((xmax - xmin + 2 * pad) / 25.4,
                        (ymax - ymin + 2 * pad) / 25.4)
    for ext in ("png", "svg"):
        fig.savefig(os.path.join(OUT, f"{name}.{ext}"), dpi=300,
                    facecolor="white")
    plt.close(fig)
    print(f"wrote {name}: {len(segs)} lines")


if __name__ == "__main__":
    box = load_binary_stl(os.path.join(BUILD, "duty_division.stl"), tag="box")
    ins = load_binary_stl(os.path.join(BUILD, "duty_division_insert.stl"),
                          offset=(0.2, 72.9, 3.2), tag="insert")  # seated

    # the two hero images (README): empty box showing the L-cavity + floor
    # label, and the assembled gauge with the insert seated
    draw([box], "iso", "box_iso", lw=0.5)
    draw([box, ins], "iso", "set_assembled", lw=0.5)
