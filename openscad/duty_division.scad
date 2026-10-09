// ============================================================================
// CMA - The Box : Duty Division - CONVERTIBLE (Optics/Non-Optics)
// https://github.com/wwb-ag/cma-box
//
// Combined / convertible gauge box for BOTH divisions:
//   - Duty Division        : gear fits 210 x 145 x 40
//   - Duty Optics Division : gear fits 210 x 175 x 40, but the
//     175 mm height is only needed over HALF the length (the
//     optic sits on one half of the slide).
//
// The cavity is an L: base 210 x 145 x 40 plus a fixed extra
// pocket 105 x 30 x 40 (30 = 175 - 145) in the TOP RIGHT corner
// of the plan view (the matching INSERT sits there). The OUTER
// shape is a regular rectangle
// (216.8 x 181.8 x 43.6): the area left of the pocket is solid
// fill, a flat plaque flush with the rim, carrying the CMA logo
// (inverted relief). The INSERT (duty_division_insert.scad)
// fills the pocket, restoring the plain
// 210 x 145 x 40 version.
//
// LABELS (self-describing gauge):
//   - The insert carries "DUTY DIVISION / Length: 210
//     Height: 145 Width: 40" on its top face -> with the insert
//     in, the reading matches the opening.
//   - The pocket floor (the area covered by the insert) carries
//     "DUTY OPTIC DIVISION / Length: 210 Height: 145/175
//     Width: 40" -> with the insert lifted out, the reading
//     matches the L-shaped opening (145 over one half, 175 over
//     the other).
//   - The plaque (left of the pocket) carries the CMA logo
//     (inverted relief); all text labels are deterministic SVG
//     outlines (see label_svg() below), not text().
//
// CONVEX VERTICAL CORNERS: sharp convex corners deposit extra
// material when printing and bulge slightly. Round them all with
// corner_r (vertical corner radius, full wall height): box = the
// 4 OUTER + the 1 INNER corner where the plaque meets the pocket
// (the L's convex material corner); insert = its 4 outer corners.
// Concave corners stay sharp - only the convex side rounds.
//
// INSERT FIT (both parts):
//   - the insert's plan is 0.4 mm smaller per axis than the
//     pocket (104.8 x 29.6) for drop-in clearance,
//   - its depth is the NOMINAL 40.0, not 40.4: the printed pocket
//     depth comes out ~0.4 short (floor prints a nozzle width
//     thick), so 40.0 sits flush with the rim while 40.4 stood
//     proud.
//
// PRINT CLEARANCE: +0.40 mm (one 0.4 mm nozzle width) is added
// to every nominal inner dimension, because a printed cavity
// comes out up to one nozzle width undersized.
// Print error should therefore be in range +0.00 to +0.80 < 1mm
// The MODELED cavity is 210.4 x 145.4/175.4 x 40.4; the LABELS 
// still state the nominal 210 / 145 / 175 / 40.
//
// Rounded edges: TRUE round fillets on
// both top rim edges - outer rim radius 1.0 mm, inner rim radius
// 2.0 mm (double the outer), applied to every opening edge
// (incl. the pocket and shelf edges) and around the outer top
// perimeter.
//
// Inner dimensions (per README, nominal; + fit = modeled):
//   Length : 210 mm   Height : 145 mm (+30 over half length)
//   Width  :  40 mm
//
// Wall strength: 3.2 mm (= 8 perimeter lines at 0.4 mm nozzle).
//
// ORIENTATION NOTE - spec dims are the firearm's natural
// orientation (length x height seen from the side, width =
// thickness). The box lies flat on the bench: LENGTH x HEIGHT
// is the footprint, WIDTH (40 mm) is vertical. Built in print
// orientation: X = Length, Y = Height, Z = Width (walls up from
// a 3.2 mm floor). Footprint 216.8 x 181.8 mm fits the 220 x
// 220 bed (K1C).
// ============================================================================

/* [Parameters] */
// Wall thickness [mm] (multiple of 0.4 nozzle line width)
wall = 3.2; // [1:0.1:10]
// Printer clearance [mm]: one 0.4 mm nozzle width added to every
// NOMINAL inner dimension (printed cavities run up to a nozzle
// width undersized). Labels always print the nominal values.
fit = 0.4; // [0:0.05:1]
// Nominal inner length [mm] (firearm length)
inner_l = 210; // [10:1:400]
// Nominal inner height, non-optic half [mm]
inner_h = 145; // [10:1:400]
// Nominal inner width [mm] (firearm thickness = vertical wall height)
inner_w = 40; // [10:1:200]
// Extra height of the optic half [mm] (175 = inner_h + opt_h);
// NOT clearanced - it is a delta, the fit rides on inner_h
opt_h = 30; // [0:1:60]
// Fillet radius on the OUTER top rim edge [mm] (0 = sharp)
outer_r = 1.0; // [0:0.1:2]
// Fillet radius on the INNER top rim edge [mm]
// (double the outer; clamped so outer + inner <= wall)
inner_r = 2.0; // [0:0.1:3]
// Vertical corner radius [mm] (0 = sharp). Rounds the CONVEX
// vertical edges (4 outer + the L's inner corner): sharp convex
// corners deposit extra material in FDM and bulge slightly
corner_r = 2.0; // [0:0.5:4]
// CMA logo on the plaque (top-left): INVERTED relief - recessed
// design panel with the bars/letters raised (elements keep their
// current size; logo_w = element width in mm, 0 = no logo)
logo_w = 90; // [0:1:110]
// Logo recess depth [mm]
logo_depth = 0.8; // [0.4:0.1:2]
// Engraved label on the POCKET FLOOR (visible when the insert is
// removed) - on/off only. The wording lives in
// assets/font/label_svgs/floor_*.svg (generated by
// assets/font/create_label_svgs.py), not in this file.
floor_label = true; // [true,false]
// Floor label sizes [mm] - the pocket band is only 30 mm deep
// (105.2 mm long), keep the lines small enough to fit it.
floor_label_size = 3.6; // [3:0.5:20]
floor_title_size = 6.5; // [3:0.5:20]  (title line)
// Label engrave depth [mm]
label_depth = 0.8; // [0.4:0.1:2]
// Line spacing: center-to-center distance = label_lh x dims-line size
label_lh = 2.0; // [1:0.1:3]
// Label rotation [deg] (0 = reads with +y up)
label_rot = 0; // [0:15:359]

// Derived (nominal + fit = modeled/printed geometry)
il = inner_l + fit; // 210.4 mm (X)
ih = inner_h + fit; // 145.4 mm (Y, non-optic half)
iw = inner_w + fit; //  40.4 mm (Z)
pocket_l = il / 2; // 105.2 mm (half length)
inner_ht = ih + opt_h; // 175.4 mm (Y, optic half)
outer_l = il + 2 * wall; // 216.8 mm (X)
outer_hb = ih + 2 * wall; // 151.8 mm (Y, non-optic half)
outer_ht = inner_ht + 2 * wall; // 181.8 mm (Y, total)
outer_w = iw + wall; //  43.6 mm (Z)
o_c = min(outer_r, wall / 2);
i_c = max(0, min(inner_r, wall - o_c));

// ---- Outer shell (regular rectangle, floor at Z = 0) -----------------------
// Full 216.8 x 181.8 x 43.6 block. The area LEFT of the optic
// pocket (x < 0, y > 72.7) is solid fill - a flat plaque flush
// with the rim, carrying the CMA logo. Uses a bit more
// material; the print footprint is unchanged.
module outer_shell() {
  translate([-outer_l / 2, -outer_hb / 2, 0])
    cube([outer_l, outer_ht, outer_w]);
}

// ---- Outer rim fillet cutter (top perimeter, radius r) ---------------------
// Rounds the four horizontal edges where the outer wall faces
// meet the top face. Per edge: R = intersection(the two outer
// half-slabs) MINUS the fillet cylinder (axis along the edge,
// radius r, centered at (face - r, top - r)); subtract R.
module outer_fillet_cutter(r) {
  L = 400;
  nf = 64;
  // arc center z
  ez = outer_w - r;
  // arc center x (right/left)
  ex = outer_l / 2 - r;
  // arc center y (top edge)
  ey = -outer_hb / 2 + outer_ht - r;
  // arc center y (bottom edge)
  eyb = -outer_hb / 2 + r;
  // +x and -x top edges
  for (s = [1, -1]) {
    difference() {
      intersection() {
        translate([s == 1 ? ex : -outer_l / 2, -L, ez])
          cube([s == 1 ? L : r, 2 * L, r + 1]);
        translate([-L, -L, ez])
          cube([2 * L, 2 * L, r + 1]);
      }
      translate([s * ex, 0, ez])
        rotate([90, 0, 0])
          cylinder(r=r, h=2 * L, center=true, $fn=nf);
    }
  }
  // +y and -y top edges (the inward slab width is r, outward is r+1)
  for (s = [1, -1]) {
    difference() {
      intersection() {
        translate([-L, s == 1 ? ey : eyb - r, ez])
          cube([2 * L, s == 1 ? r + 1 : r, r + 1]);
        translate([-L, -L, ez])
          cube([2 * L, 2 * L, r + 1]);
      }
      translate([0, s == 1 ? ey : eyb, ez])
        rotate([0, 90, 0])
          cylinder(r=r, h=2 * L, center=true, $fn=nf);
    }
  }
}

// ---- Cavity (L-prism, open top) --------------------------------------------
// Pocket in the TOP RIGHT: x in [0, 105.2], y in [72.7, 102.7].
module cavity() {
  union() {
    // base 210.4 x 145.4
    translate([-il / 2, -ih / 2, wall])
      cube([il, ih, iw]);
    // optic pocket 105.2 x 30, top-right
    translate([0, ih / 2, wall])
      cube([pocket_l, opt_h, iw]);
  }
}

// ---- Inner rim fillet cutter (quarter-circle, radius r) --------------------
// The rounded opening is "the L cavity grown by the fillet
// profile" g(z) = r - sqrt(r^2 - (z - (outer_w - r))^2) at each
// height (g = 0 at z = outer_w - r, g = r at z = outer_w).
// Cross-sections stay rectilinear and the corners miter as
// curved corner edges: each "grown slab" is a box (bounds grown
// by r, z in [outer_w - r, outer_w]) MINUS its two edge
// cylinders (axis along the slab direction, radius r, centered
// at grown-bounds minus r, z = outer_w - r). The grown L is
// (base slab_x intersect slab_y) union (pocket slab_x intersect
// slab_y), subtracted from the shell.
module slab_x(x_lo, x_hi, r) {
  z0 = outer_w - r;
  L = 400;
  nf = 64;
  difference() {
    translate([x_lo - r, -L, z0])
      cube([x_hi - x_lo + 2 * r, 2 * L, r]);
    translate([x_lo - r, 0, z0])
      rotate([90, 0, 0])
        cylinder(r=r, h=2 * L, center=true, $fn=nf);
    translate([x_hi + r, 0, z0])
      rotate([90, 0, 0])
        cylinder(r=r, h=2 * L, center=true, $fn=nf);
  }
}
module slab_y(y_lo, y_hi, r) {
  z0 = outer_w - r;
  L = 400;
  nf = 64;
  difference() {
    translate([-L, y_lo - r, z0])
      cube([2 * L, y_hi - y_lo + 2 * r, r]);
    translate([0, y_lo - r, z0])
      rotate([0, 90, 0])
        cylinder(r=r, h=2 * L, center=true, $fn=nf);
    translate([0, y_hi + r, z0])
      rotate([0, 90, 0])
        cylinder(r=r, h=2 * L, center=true, $fn=nf);
  }
}
module fillet_cutter(r) {
  intersection() {
    slab_x(-il / 2, il / 2, r);
    slab_y(-ih / 2, ih / 2, r);
  }
  intersection() {
    slab_x(0, pocket_l, r);
    slab_y(ih / 2, ih / 2 + opt_h, r);
  }
}

// ---- Convex vertical corner rounding ---------------------------------------
// TRUE tangent round on each CONVEX vertical corner: cutter =
// corner block (r x r on the material side, full height) MINUS a
// cylinder of radius r centered INSIDE the material at (r, r)
// from the corner. That leaves a smooth quarter-cylinder that is
// tangent to both faces - NOT the cuspy "quarter circle" you get
// from a cylinder centered on the corner vertex.
// Convex corners: the 4 OUTER + the L's INNER corner at
// (0, ih/2). The inner corner cutter starts at the FLOOR TOP
// (wall), so it never cuts through the pocket floor. Concave
// cavity corners (wall meets wall) stay sharp on purpose.
module corner_round_cutter(r) {
  nf = 64;
  // [cx, cy, sx, sy, z0]: corner point, material-side signs, z start
  for (
    c = [
      [-outer_l / 2, -outer_hb / 2, 1, 1, -1],
      [outer_l / 2, -outer_hb / 2, -1, 1, -1],
      [-outer_l / 2, -outer_hb / 2 + outer_ht, 1, -1, -1],
      [outer_l / 2, -outer_hb / 2 + outer_ht, -1, -1, -1],
      [0, ih / 2, -1, 1, wall],
    ]
  ) {
    x0 = c[2] < 0 ? c[0] - r : c[0];
    y0 = c[3] < 0 ? c[1] - r : c[1];
    hh = outer_w + 1 - c[4];
    difference() {
      translate([x0, y0, c[4]])
        cube([r, r, hh]);
      translate([c[0] + c[2] * r, c[1] + c[3] * r, c[4]])
        cylinder(r=r, h=hh, $fn=nf);
    }
  }
}

// ---- Brand-font label line as SVG ------------------------------------------
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
        import(file, center=false);
}

// ---- Label on the pocket floor (covered when insert is in) ------------------
// States nominal dims; height reads 145/175 because the L
// opening is 145 over one half, 175 over the optic half. Two
// lines (title + dims), line centers spaced label_lh x size
// apart; title on top = +y side.
module floor_label_module() {
  cy = ih / 2 + opt_h / 2; // pocket center y
  lh = floor_label_size * label_lh;
  // title line (larger, reads first)
  translate([pocket_l / 2, cy + lh / 2, wall - label_depth])
    rotate([0, 0, label_rot])
      label_svg(
        "../assets/font/label_svgs/floor_title.svg",
        1506.14, 102.86, floor_title_size
      );
  // dimensions line (nominal values, incl. the optic 175)
  translate([pocket_l / 2, cy - lh / 2, wall - label_depth])
    rotate([0, 0, label_rot])
      label_svg(
        "../assets/font/label_svgs/floor_dims.svg",
        2667.14, 143.71, floor_label_size
      );
}

// ---- CMA logo on the plaque (top-left), INVERTED relief ---------------------
// assets/logo/cma_logo.svg was traced from assets/logo/CMA-logo.avif
// (beige-on-transparent two-tone logo -> alpha silhouette), with
// a PADDED canvas (20 px margin each side). The trace with the
// padding imports as the BACKGROUND region (canvas with the
// bars/letters as holes): cutting the import DIRECTLY recesses
// the design panel + margin and leaves the elements RAISED at
// surface height (inverted relief, distinct from the recessed
// letter text labels); the margin keeps every element clear of
// the recess border.
// NOTE: OpenSCAD SVG import uses points: 1 SVG unit = 0.75 pt =
// 0.352778 mm; y comes out flipped so it reads correctly from
// above.
module logo_module() {
  s = 0.352778; // mm per SVG unit
  aw = 645 * s; // padded canvas (SVG units 645x149)
  ah = 149 * s;
  f = logo_w / (605 * s); // logo_w = ELEMENT width; pad scales along
  translate(
    [
      -outer_l / 4,
      ih / 2 + (opt_h + wall) / 2,
      outer_w - logo_depth,
    ]
  )
    scale([f, f, 1])
      translate([-aw / 2, -ah / 2, 0])
        linear_extrude(logo_depth + 0.1)
          import("../assets/logo/cma_logo.svg", center=false);
}

// ---- Solid ------------------------------------------------------------------
difference() {
  outer_shell();
  if (o_c > 0)
    outer_fillet_cutter(o_c);
  cavity();
  if (i_c > 0)
    fillet_cutter(i_c);
  if (corner_r > 0)
    corner_round_cutter(corner_r);
  if (logo_w > 0)
    logo_module();
  if (floor_label)
    floor_label_module();
}

echo(str("Footprint (L x H): ", outer_l, " x ", outer_ht, " mm, wall height (W): ", outer_w, " mm"));
echo(str("Nominal inner (L x H x W): ", inner_l, " x ", inner_h, " x ", inner_w, " mm (+ fit ", fit, " = ", il, " x ", ih, " x ", iw, " mm modeled)"));
echo(str("Nominal optic height: ", inner_h + opt_h, " mm over half length (modeled ", inner_ht, "); pocket ", pocket_l, " x ", opt_h, " x ", iw, " mm"));
echo(str("Rim fillets: outer ", o_c, " mm, inner ", i_c, " mm (flat top annulus ", wall - o_c - i_c, " mm)"));
echo(str("Convex vertical corner rounds: r ", corner_r, " mm (4 outer + L inner corner)"));
echo(str("Floor label: ", floor_label ? "on" : "off", " (SVG), size ", floor_label_size, " mm, depth ", label_depth, " mm"));
