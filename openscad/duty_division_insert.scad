// ============================================================
// CMA - The Box : CONVERTIBLE INSERT (filler block)
// https://github.com/wwb-ag/cma-box
//
// Fills the optic pocket of duty_division.scad, restoring the
// plain 210 x 145 x 40 gauge opening. Keep it inserted to test
// the Duty (non-optic) Division, remove it to test the Duty
// Optics Division.
//
// LABELS (self-describing gauge): the top face carries
//   "DUTY DIVISION / Length: 210 Height: 145 Width: 40"
// matching the opening when the insert is in place. The pocket
// floor underneath (see duty_division.scad) carries "DUTY OPTIC
// DIVISION / Length: 210 Height: 145/175 Width: 40" for the
// insert-removed case. The insert is a plain drop-in (no keyway).
//
// Dimensions (match duty_division.scad):
//   Length 104.8 mm x Height 29.6 mm x Depth 40.0 mm
//   = ((210 + 0.4) / 2 - 0.4)  x  (30 - 0.4)  x  40
//   - plan (length/height): 0.4 mm smaller per axis than the
//     pocket for drop-in clearance,
//   - depth: NOMINAL 40.0, NOT 40.4 - the printed pocket depth
//     comes out ~0.4 short (floor prints a nozzle width thick),
//     so 40.0 sits level with the box rim while 40.4 stood proud.
//   If you change the box's inner_l / inner_w / fit, change
//   these to match.
//
// CONVEX VERTICAL CORNERS: all 4
// outer corners are rounded with corner_r (vertical corner
// radius, full height) - sharp convex corners deposit extra
// material when printing and bulge slightly. Label stays clear
// of the rounds.
//
// Printed in use position: 104.8 x 29.6 mm footprint on the bed,
// 40.0 mm tall, engraved label side UP (no supports in that
// orientation), fits the K1C bed easily.
// ============================================================

/* [Parameters] */
// Pocket length [mm] = (inner_l + fit) / 2 - 0.4 of the box
// (105.2 - 0.4 drop-in clearance)
body_l = 104.8;   // [10:0.1:400]
// Pocket height [mm] = opt_h - 0.4 of the box (30 - 0.4)
body_h = 29.6;    // [1:0.1:60]
// Pocket depth [mm] = NOMINAL inner_w of the box (40, not 40.4:
// printed pocket depth is ~0.4 short, so 40.0 sits flush)
body_d = 40.0;    // [10:0.1:200]
// Vertical corner radius [mm] (0 = sharp): rounds the 4 convex
// outer corners (sharp convex corners bulge when printing)
corner_r = 2.0;   // [0:0.5:4]
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

// ---- Brand-font label line as SVG ----------------------------
// The Rubik label lines live in assets/font/label_svgs/ (generated
// by assets/font/create_label_svgs.py). Every SVG is normalized to
// CAP HEIGHT = 100 units; OpenSCAD's viewBox import maps 1 unit ->
// 0.352778 mm, so the cap imports as 35.2778 mm and scaling by
// size/35.2778 sets the cap height to 'size' mm. adv_u/h_u = the
// SVG's advance width and height in units (see the comment baked
// into each SVG). The import includes the y-flip (reads correctly
// from above) - do NOT mirror it.
module label_svg(file, adv_u, h_u, size) {
    f = size / 35.2778;
    translate([-adv_u * 0.352778 * f / 2, -h_u * 0.352778 * f / 2, 0])
        scale([f, f, 1])
        linear_extrude(label_depth + 0.1)
        import(file, center = false);
}

// ---- Label on the insert top face --------------------------
// States the NOMINAL gauge dims of the box with the insert in:
// 210 x 145 x 40 (Duty Division). Two lines (title + dims), line
// centers spaced label_lh x size apart; title on top = +y side.
module label_module() {
    lh = label_size * label_lh;
    // title line (larger, reads first)
    translate([body_l / 2, body_h / 2 + lh / 2, body_d - label_depth])
        rotate([0, 0, label_rot])
        label_svg("../assets/font/label_svgs/insert_title.svg",
                  1047.29, 102.86, label_title_size);
    // dimensions line
    translate([body_l / 2, body_h / 2 - lh / 2, body_d - label_depth])
        rotate([0, 0, label_rot])
        label_svg("../assets/font/label_svgs/insert_dims.svg",
                  2354.29, 135.86, label_size);
}

// ---- Convex vertical corner rounding ------------------------
// TRUE tangent round on each of the 4 convex outer corners:
// cutter = corner block (r x r on the material side, full
// height) MINUS a cylinder of radius r centered INSIDE the
// material at (r, r) from the corner - leaves a smooth quarter
// cylinder tangent to both faces (not the cuspy "quarter
// circle" of a cylinder centered on the corner vertex).
module corner_round_cutter(r) {
    nf = 64;
    for (c = [[0, 0, 1, 1], [body_l, 0, -1, 1],
              [0, body_h, 1, -1], [body_l, body_h, -1, -1]]) {
        x0 = c[2] < 0 ? c[0] - r : c[0];
        y0 = c[3] < 0 ? c[1] - r : c[1];
        difference() {
            translate([x0, y0, -1])
                cube([r, r, body_d + 2]);
            translate([c[0] + c[2] * r, c[1] + c[3] * r, -1])
                cylinder(r = r, h = body_d + 2, $fn = nf);
        }
    }
}

// ---- Top-edge fillet (around the top face, radius r) --------
// Rounds the 4 horizontal edges of the top face. Per edge: band
// slab on the material side (r wide, from top-r to top) MINUS the
// fillet cylinder (axis along the edge, center at (face -/+ r,
// top - r)) - same pattern as the box rim fillets, tangent to
// the face and to the top plane.
module top_fillet_cutter(r) {
    nf = 64;
    L = 400;
    ez = body_d - r;
    // edges along X: y = 0 (material +y) and y = body_h (material -y)
    for (e = [[0, 1], [body_h, -1]]) {
        y_e = e[0]; s = e[1];
        ylo = s == 1 ? y_e : y_e - r;
        difference() {
            translate([-L, ylo, ez])
                cube([2 * L, r, r]);
            translate([0, y_e + s * r, ez])
                rotate([0, 90, 0])
                    cylinder(r = r, h = 2 * L, center = true, $fn = nf);
        }
    }
    // edges along Y: x = 0 (material +x) and x = body_l (material -x)
    for (e = [[0, 1], [body_l, -1]]) {
        x_e = e[0]; s = e[1];
        xlo = s == 1 ? x_e : x_e - r;
        difference() {
            translate([xlo, -L, ez])
                cube([r, 2 * L, r]);
            translate([x_e + s * r, 0, ez])
                rotate([90, 0, 0])
                    cylinder(r = r, h = 2 * L, center = true, $fn = nf);
        }
    }
}

// ---- Solid -------------------------------------------------
difference() {
    // body: pocket fill minus 0.4 per plan axis
    translate([0, 0, 0])
        cube([body_l, body_h, body_d]);
    if (corner_r > 0)
        corner_round_cutter(corner_r);
    if (top_fillet_r > 0)
        top_fillet_cutter(top_fillet_r);
    label_module();
}

echo(str("Insert body: ", body_l, " x ", body_h, " x ", body_d, " mm (print height ", body_d, " mm, footprint ", body_l, " x ", body_h, " mm)"));
echo(str("Corner rounds: r ", corner_r, " mm on the 4 outer corners; top-edge fillet r ", top_fillet_r, " mm"));
echo(str("Label: \"DUTY DIVISION / Length: 210 Height: 145 Width: 40\" ", label_size, " mm, depth ", label_depth, " mm"));
