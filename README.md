# The Box

A simple **3d-printable** box for assessing whether the **CMA** participant's equipment satisfies the dimensionality requirements of the desired category.

![The box: L-shaped cavity, engraved labels, CMA logo panel](assets/render/preview/box_iso.png)

- This repository contains the openscad files, the assets and build scripts.
- You can download the print-ready `.stl` files from the [CMA website](https://www.cma-sport.com/resources).

![The Duty set assembled: insert seated](assets/render/preview/set_assembled.png)

![The Sport set: L-shaped cavity, engraved labels, CMA logo panel](assets/render/preview/box_iso_sport.png)

![The Sport set assembled: insert seated](assets/render/preview/set_assembled_sport.png)

## Dimensions

Inner dimensions of the box (nominal values, as printed on the labels).
The modeled cavity adds +0.4 mm to every inner dimension (nozzle-width
print clearance), so the printed cavity ends up at least the nominal
size.

### Duty Division (insert installed)

- **Length**: 210 mm
- **Height**: 145 mm
- **Width**: 40 mm

### Duty Optics Division (insert removed)

- **Length**: 210 mm
- **Height**:
  - First half along length: 145 mm
  - Second half along length: 175 mm (optic pocket)
- **Width**: 40 mm

### Sport Division (insert installed)

- **Length**: 225 mm
- **Height**: 155 mm
- **Width**: 45 mm

### Sport Optics Division (insert removed)

- **Length**: 225 mm
- **Height**:
  - First half along length: 155 mm
  - Second half along length: 185 mm (optic pocket)
- **Width**: 45 mm

## Design

- Edges, rims, and outer corners are rounded.
- +0.40 mm is added to every nominal inner dimension.
- Wall and floor strength is 3.2mm.
- The final outer dimensions are 216.8 x 181.8 x 43.6 mm (Duty) and
  231.8 x 191.8 x 48.6 mm (Sport).

## Printing Notes

- These are large parts, make sure the bed is level and calibrate before printing.
- The Duty box and the insert can be printed on a 220x220 bed at the
  same time (tight fit).
- The Sport set does **not** fit a 220x220 bed and we haven't completed a test print at this time. Please open an issue or contact us if the part is defective.
- The Sport sets require a bed of at least 235 x 235 mm to print box and insert side by side.
- We used default settings (15% infill) for all test prints using CR-PLA with a Creality K1C.
- The Duty Box print takes approximately 8 hours depending on settings and whether the insert is printed alongside the box. One set takes around 230g of PLA (@15% infill), therefore four sets can be printed from a standard 1kg spool.
  - **Box**: 191g of PLA and 6h 45min printing time.
  - **Insert**: 38g of PLA and 1h 15min.
  
## Project Structure and Build Notes

Tested and rendered with `OpenSCAD version 2026.10.03` (any OpenSCAD AppImage
dropped into `bin/` works — `build.sh` picks up `bin/OpenSCAD-*.AppImage`,
git-ignored; binary STL export via `--export-format binstl`) on Ubuntu
2024.04; also verified with `OpenSCAD version 2021.01` (CGAL, same
dimensions - `build.sh` falls back to it when no AppImage is present).

Two divisions (Duty and Sport, same shapes, different dimensions) share
one geometry library. `build.sh` renders all four STLs into `build/`:

- `openscad/cma_box_lib.scad`: all box and insert geometry, fully
  parameterized (shells, cavity, rim fillets, corner rounds, label and
  logo placement). The entry files only set parameters and labels.
- `openscad/duty_division.scad` + `openscad/duty_division_insert.scad`:
  the Duty set (210 x 145/175 x 40)
- `openscad/sport_division.scad` + `openscad/sport_division_insert.scad`:
  the Sport set (225 x 155/185 x 45)

Adding a division means four label SVGs (see below), two thin entry
files and one line in `build.sh`. The insert files derive their body
from the box's nominal parameters - keep them matched.

Three utility scripts:

- `assets/font/create_label_svgs.py`: Regenerate after changing a label
  string (needs Rubik-SemiBold.ttf from the font, not shipped here - see
  the script's error for where it looks). Writes one SVG set per
  division into `assets/font/label_svgs/<division>/` plus
  `label_data.scad` / `label_data.json` - the single source of each
  line's advance width and height, read by `cma_box_lib.scad` and
  `make_lineart.py` (the `.scad` files never hard-code those numbers):
  `uv run --with fonttools python3 assets/font/create_label_svgs.py`
- `assets/logo/trace_logo.sh`: regenerates the SVG from the AVIF
  (ImageMagick + `uvx vtracer`)
- `assets/render/make_lineart.py`: vector line-art renders for the README
  (black/white outlines from the STLs, hidden-line removed); writes
  PNG + SVG into `assets/render/preview/` for every division (pass a
  subset to render only some, e.g. `... make_lineart.py sport`):
  `uv run --with numpy --with matplotlib python3 assets/render/make_lineart.py`

One build script:

- `build.sh`

## Acknowledgements

Development of this project was sponsored and carried out by [WWB AG](https://wwb.swiss) for CMA.

## Licenses

- Code build and preprocess scripts: Creative Commons Attribution 4.0 International
- Assets:
  - Logo: CMA proprietary 
  - Font: OFL (`OFL.txt`)
  