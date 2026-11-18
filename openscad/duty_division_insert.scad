// ============================================================
// CMA - The Box : Duty Division INSERT (filler block)
// https://github.com/wwb-ag/cma-box
//
// Fills the optic pocket of duty_division.scad, restoring the plain
// 210 x 145 x 40 gauge opening. Keep it inserted to test the Duty
// (non-optic) Division, remove it to test the Duty Optics Division.
//
// Geometry lives in cma_box_lib.scad; the body is DERIVED from the
// box's nominal parameters, so keep inner_l / inner_w / opt_h / fit
// matched with duty_division.scad:
//   Length = (inner_l + fit) / 2 - fit  x  Height = opt_h - fit  x
//   Depth = inner_w (NOMINAL - the printed pocket depth comes out
//   ~0.4 short (the floor prints a nozzle width thick), so the
//   nominal depth sits flush with the rim while a clearanced depth
//   stood proud).
//
// LABELS (self-describing gauge): the top face carries
//   "DUTY DIVISION / Length: 210 Height: 145 Width: 40"
// matching the opening when the insert is in place. The pocket floor
// underneath (see duty_division.scad) carries
//   "DUTY OPTIC DIVISION / Length: 210 Height: 145/175 Width: 40"
// for the insert-removed case. The insert is a plain drop-in (no
// keyway). Label engraved side UP in print orientation (no supports).
// ============================================================

include <cma_box_lib.scad>

/* [Parameters] */
// Nominal inner length [mm] of the box (keep matched)
inner_l = 210; // [10:1:400]
// Nominal inner width [mm] of the box = insert depth (keep matched)
inner_w = 40; // [10:1:200]
// Extra height of the optic half [mm] of the box (keep matched)
opt_h = 30; // [0:1:60]
// Printer clearance [mm] of the box (keep matched)
fit = 0.4; // [0:0.05:1]
// Vertical corner radius [mm] (0 = sharp): rounds the 4 convex
// outer corners (sharp convex corners bulge when printing)
corner_r = 2.0; // [0:0.5:4]
// Top-edge fillet radius [mm] (0 = sharp): rounds the 4 edges
// around the top face (same treatment as the box rim fillets)
top_fillet_r = 1.0; // [0:0.1:2]
// Label text height [mm] - top face is only 105 x 30 mm, keep
// the dimension line small enough to fit the 105 mm length
label_size = 4.0; // [3:0.5:20]
label_title_size = 8.0; // [4:0.5:20]  (title line)
// Label engrave depth [mm]
label_depth = 0.8;  // [0.4:0.1:2]
// Line spacing: center-to-center distance = label_lh x dims-line size
label_lh = 2.0;     // [1:0.1:3]
// Label rotation [deg] (0 = reads with +y up, as modeled)
label_rot = 0;      // [0:15:359]

cma_box_insert(
    inner_l = inner_l, inner_w = inner_w, opt_h = opt_h, fit = fit,
    title_label = "duty/insert_title", dims_label = "duty/insert_dims",
    corner_r = corner_r, top_fillet_r = top_fillet_r,
    label_size = label_size, label_title_size = label_title_size,
    label_depth = label_depth, label_lh = label_lh, label_rot = label_rot
);
