# Curved roads and a sharp zoomable map (research, 2026-10-29)

Sachin, 2026-10-29: "the roads within the major city centre can be perfectly
parallel and 90 degrees to each other which they are right now, but there
should be some curved roads too, sometime there might be only one road,
sometimes it could be multiple roads next to each other, but perfectly
connecting straight to other roads, or strecthing till the city outside
area ... Also, we need to show a high quality map from top down, that should
retain its high quality even when zoomed in, and it should show, streets
running in between the houses, or buildings etc."

Tags: [M] measured here, [V] verified in a source, [I] inferred.

## 1. Where Bellerive stands

- Street plan (`tests/plan_dump.gd`, 949 nodes, 111.6 km of street), length
  by bearing mod 90 [M]:
  - 84.2% within +-2.5 deg of the city grid (0/90);
  - 11.0% on the two turned grids: Lantern Quarter East (30 deg, about 4.4% at
    30) and Brisa Beach (-39 deg, about 6.6% at 50-55 and 35);
  - **about 5% anything else**: Liberty Avenue (one straight diagonal), the
    river roads (River Road and Levee Road follow the bank) and the jogs.
  - So Bellerive has no curved street a player would notice outside the
    riverbank.
- Real cities [V/M, california_topdown.md 2.1-2.5]:
  - SF: 70% on one grid, 22% on a second, 6% curved;
  - South LA: 91% on grid;
  - central LA: 28% off its three grids (hill roads, diagonal boulevards);
  - Irvine: 29% curved parkways.
  - Hill and coast districts run up to 30% curved; flat ones 10% or less.
  - **Curves sit inside cells bounded by straight arterials**, or are long
    old roads (Sunset Blvd, Mulholland) that the grid butts into.
- Map now: `map_image.gd` bakes one raster at `PX_M = 1.0` (1 px per metre),
  with blocks coloured per district and no buildings. `full_map.gd` allows
  zoom to 4x, so at full zoom one metre is a 4-pixel smear.

## 2. Curved roads: how other generators and games do it

- **Tensor-field street modelling** (Chen, Esch, Wonka, Mueller, Zhang,
  SIGGRAPH 2008) [V]. A field of directions is built from the following,
  and streets are traced along it:
  - grid elements (straight);
  - radial elements;
  - the coast, rivers and terrain.

  Grids and curves blend smoothly where the field changes. The probabletrain
  city generator is a browser version of it [V].
  - Pros: the most natural mix.
  - Cons: it replaces the whole street layout and every hand-placed set
    piece (Founders Circle, civic centre, Liberty Green, landmark lots), and
    the tests and country exits that hang off them.
  - https://www2.cs.uh.edu/~chengu/Publications/streetModeling/street_modeling.html
  - https://web.engr.oregonstate.edu/~zhange/images/street_sig08.pdf
  - https://probabletrain.itch.io/city-generator
- **GTA maps are hand-drawn** [I from the maps in gta_san_andreas.md and
  gta_v_vi.md]. The same rule as the real cities holds:
  - grid downtowns;
  - a few long curving roads (Los Santos: Vinewood hills roads and the
    Del Perro freeway curves; Liberty City: Broker's curving parkways);
  - curved suburb streets inside arterial cells.
- **Patch warping** (what street_plan.gd already has): a patch's lines can be
  bent (`bend`: v grows by bend*u^2), fanned (`fan`) or curved across
  (`bend_u`), so a group of neighbouring streets curves together, all
  parallel. Map v2 used them (f2f02ad, "curved, fanned districts"); the
  California re-grid (cacae77, task #33, when Sachin asked for parallel
  roads) set every patch to a straight grid, so no patch uses them now. `_spline` (Catmull-Rom) already draws curved single roads.

## 3. Options for the curves

| | What | Curved share | Cost, time |
|---|---|---|---|
| **A (recommended)** | Single curved roads plus bent street groups. The downtown grids stay straight. | about 13-16% curved or off-grid | 8-12 h |
| B | A plus a contour-following hill district (Cable Hill streets follow the foothill heights, loops and cul-de-sacs; still flat ground, see HANDOFF-bellerive-lv "SF district flat") | about 18-20% | A + 6-10 h |
| C | Tensor-field generator replacing the street layout | any | 30-50 h, and every plan-bound test and set piece reworked |

**Option A for Bellerive (each item joins the grid at a T or X junction and
runs to a city exit, where the country's lead-in carries it on):**

1. **One long curving boulevard, Sunset style.** It starts from Founders
   Circle, crosses Cable Hill in a wide S along the foot of the Bellerive
   Hills, and leaves the city at the north-west, where the country carries
   it into the hills. It is a single road: grid streets end on it in Ts or
   cross it in Xs. Made with `_spline` from 4-6 control points.
2. **Groups of parallel curved streets.**
   - **Morrow Point** (south bank, `point_w`/`point_e`): its east-west streets
     bend with the river (`bend`), like Coral Gables' curving rows. Point
     Avenue and Harbor Avenue stay straight as the frame.
   - **Calle Luna** (`havana_e`): a curved fan (`fan`, `bend_u`) between
     Hibiscus and Seagrape. Three or four streets curve together, like
     Little Havana's side streets meeting the bay road.
3. **A shore parkway.** Along the Morrow's south bank west of the bridge,
   where Levee Road already follows the water, a second curving road one
   block inland, parallel to it. That makes a pair of curves side by side.
4. **Two or three single curved connectors in the suburb cells** at the city
   edge (north-east lobe, south-west). Each one bends from one grid street to
   the next, the way a Valley street swings round a wash.
5. Kept straight: Gilt (downtown), Midtown, the Wards, the civic centre,
   Liberty Green, all arterials. That is "the major city centre perfectly
   parallel".

Checks to add: the share of curved length per district (downtown 0%, the
listed districts 20-40%, city 13-16%); every curved road ends on a junction
or an exit (no dead ends); the existing block-size, lot and traffic tests keep
passing.

Why A: it gives each pattern Sachin named (a single curved road, several
curved roads side by side, curves meeting straight roads, curves running out
of the city) at a quarter of the cost of C, and it reuses the patch machinery.
B is the bigger option if the hill district should look like SF's Twin Peaks
or Oakland's hills.

## 4. The map: how other open-world games show it

- **GTA V**: the pause map and radar are raster texture tiles (minimap
  `.ytd` dictionaries in a 2x3 grid of large textures). Mods add more
  textured tiles. Fully zoomed in, roads and footprints go soft [V cfx.re
  forum; I from play].
  https://forum.cfx.re/t/extra-map-tiles-v2-add-extra-textured-tiles-on-the-pause-menu-map-and-minimap-new-and-revamped-version/5344181
- **Web maps** (Mapbox, Google, Apple) switched to **vector tiles**: geometry
  is sent as shapes and drawn at the screen's own resolution. It stays sharp
  at every zoom, a tile shows more detail as zoom rises, and labels stay
  upright and readable [V].
  - https://docs.mapbox.com/data/tilesets/guides/vector-tiles-introduction/
  - https://www.thunderforest.com/articles/vector-vs-raster-maps/
  - https://mapatlas.eu/blog/vector-tiles-vs-raster-tiles
- A sharper raster would cost too much memory [I, arithmetic]. At 4 px/m the
  city alone (about 2.5 x 2.5 km) is 10,000 x 10,000 px, 400 MB uncompressed
  RGBA. The country is far larger.

## 5. Map recommendation: vector map

- **Layers:**
  - land, water and parks;
  - blocks and lots;
  - roads as ribbons at their real widths, coloured by class (freeway,
    boulevard, avenue, street, lane), with sidewalks;
  - building footprints;
  - landmarks and places;
  - street, district and landmark labels.
- **Drawing:** layers are drawn as 2D meshes (ArrayMesh or Polygon2D, cut
  into tiles of about 500 m, with off-screen tiles skipped). Godot then
  rasterises them at the screen's resolution on every frame. 2D MSAA
  smooths the edges.
- **Detail by zoom:**
  - far: districts, highways and arterials;
  - middle: every street with its name;
  - near: lots, building footprints, alleys and driveways, place icons.

  MAX_ZOOM goes from 4 to about 12, where one house fills a thumb.
- **Footprints:** city buildings are made at run time by the cell builders
  from the seeded plan. A headless dump, like `plan_dump.gd`, runs the
  builders' footprint step and writes `data/map_footprints.json`. A test
  checks that it matches the plan, so it is regenerated whenever the plan
  changes. Country houses come from the plots in `country.json`.
- **Minimap:** keeps the raster for now. It is small, and the camera never
  zooms it far. It can move to the same layers later.
- **Cost:** about 12-18 h, including the dump, the layers, the zoom levels,
  the labels, tests and shots.
- **When:** after the curved roads settle, as Sachin allowed ("if you ... are
  planning to add them later once everything is built out ... that is fine
  too").
