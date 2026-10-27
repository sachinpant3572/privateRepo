# HANDOFF: road-parallel plots, estates and clusters

Task (Sachin, 2026-10-27): "Some of the building are put diagonally or not in parallel with the main
roads, is there a reason for this? Also, for such building can we build parks or other things around
them ... the plot always remains parallel to the roads and in a symmetrical shape. The only other
places where buildings are built on uneven land are small towns, or ghettos etc ... Research well and
then implement".

## Diagnosis (verified in code)

- `build_country.py _place_near` (landmarks, town civic buildings, truck stop) turned each lot to face
  the nearest point of the *buffered road area's boundary*. Near curves, junctions and the round caps
  at road ends that point is off to the side, so the lot came out turned: Hollis farm, the Larkspur
  vineyard, the gator farm, town halls, the truck-stop group.
- Street and farm lots were already square to their road (tangent normal), but the fields and vines
  round them (`country_tiles.gd _fields`) sat on a world-axis 25 m grid, so on a diagonal road a
  square-on farm still looked turned against its own fields (Wheaton, Golden Flats).
- City plan cells (`city_cells.gd`) build every building inside a frontage frame (`ctx.frame`); not
  part of the problem, not changed.

## Research (2026-10-27)

Checked through search summaries only: the research tools could not open any primary page or PDF.
[V] means a source states it; [I] means inferred.

- Lots [V]: US subdivision codes require side lot lines "substantially at right angles to or radial
  to" the street. CityEngine's skeleton subdivision makes "the sides of the lots perpendicular to the
  roads", with each lot facing its nearest street. Typical lot 60x120 ft (18x37 m). Florida reference
  (Miami-Dade RU-1): front setback 4.6-7.6 m.
- Estates [V]: Palm Beach houses lay out along one axis from street to water: gate in a 2.4 m
  hedge, entrance garden or motor court with fountain, house, pool terrace, formal gardens. Olmsted
  sited houses toward the view ("a commanding view to the south", a lake) rather than the road.
  Tennis court 36.6x18.3 m fence to fence. Circular drive 12-18 m across.
- Farms [V]: PLSS puts county roads and fields on a north-south grid; shelterbelts go on the north
  and west sides only, at least 20 m from the road edge. Vine rows 2.7-3 m apart, blocks 61-76 m.
- Clusters [V]: shotgun houses sit square on narrow lots; mobile-home parks keep parallel lots,
  3 m or more apart, with 7.3-7.9 m internal roads. [I] For organic clusters, keep the outer parcel
  street-aligned and jitter the houses inside it: small towns ±3-8°, ghettos ±10-20° and 2-6 m gaps.
- **Deviation:** PLSS would keep fields on world north-south axes even beside a diagonal road.
  Sachin's rule ("all plots are sold parallely") wins, so fields are cells square to their road.

## Decisions

- D-1 **Plots.** A new `plots` list in country.json: `[x, y, yaw, w, d, type, parts]`. Every plot is a
  rectangle square to its fronting road (yaw from the road piece's tangent at the frontage point), in
  the same lot frame as lots (x along the road, -z towards it). The generator lays out everything
  inside a plot as `parts` `[kind, x, z, w, d, rot]` in the plot frame (one source of truth, checked
  with shapely); `country_tiles.gd` only draws them (new `kits/grounds_kit.gd`).
- D-2 **Facing rule.** Every lot is square to its road, except houses inside an estate (may turn) and
  dwellings inside a cluster (jittered). `_place_near` now takes the side and yaw from the nearest
  road piece's centreline tangent and sets the lot back a fixed distance, like street lots.
- D-3 **Estates** (wealthy): Magnolia Heights mansions, Verdant Hills villas, the Hale Estate.
  Rectangular plot about 60-90 m wide, 60-90 m deep; boundary wall or hedge with a centred gate,
  axial drive, circular forecourt with fountain, mirrored parterre gardens, pool with deck and pool
  house behind the house, tennis court, tree rows. Two layouts: `axial` (house square to the plot) and
  `diagonal` (square plot, house turned 45 deg, grounds round it). The plot stays square to the road.
- D-4 **Clusters** (small villages, bayou camps, Blackwater Bayou, trailer parks): a road-square
  plot (low post fence, dirt yard, shared track) with 3-6 dwellings at jittered spots and turns.
  Wheaton (a proper town) keeps square lots on its grid.
- D-5 **Fields.** Crop and vine fields become plots too: cells along each farmland or hills road,
  square to it, several cells deep, one crop per run of cells; the world-grid `_fields` keeps only
  the bayou ponds. Farmsteads (farmhouse, barn, silos) sit in a fenced farmyard plot with a windbreak.
- D-6 Plots go in the tile of their centre (like lots); fields are cut into cells of 50 m or less so
  each draws whole from its own tile. Trees and ponds keep off plots (`_clear`).

- D-7 **View rule.** An estate house turns 45° only on a square plot (80 m or more, sides within
  8 m of each other) whose view lies off the road axis: the nearest water within 350 m, or for
  Verdant Hills villas (sun) south and west. Today that gives 3 turned houses, all Verdant Hills
  villas; the Hale Estate and the Heights mansions stay axial.
- D-8 **No plot beside a crooked road.** `_free` also runs `_square_to_roads`: every road piece
  within its half-width + 10 m of a plot must run within 6° of the plot's axes. This stops a field
  fronting a lane from clipping a diagonal highway at 11°.
- D-9 **Cluster homes** use smaller lots (`CLUSTER_LOT`: house 11x12, stilt house 10x10, shack 8x9)
  on a jittered grid (±4 m, ±3 m), with gaps of 2.5 m (bayou town) to 7 m (camps). Trailers stand
  in two parallel rows, per the park research.
- D-10 **Windbreak** of oaks 8 m apart on the north and west sides of a farmyard, per the shelterbelt
  research. Cypress looked black and sparse from above.
- D-11 **Test metric.** `test_country_plots_square_to_their_roads` measures each lot and plot
  against the road tangent at its nearest road point. The tangent is interpolated between the two
  pieces at a node, but not across a corner (dot < 0.87). A chord metric gave false 35° readings
  on curves. Limits are lots < 4°, plots < 5°, and the Hollis farm < 4°. On the old data the test
  fails at 76°.

## Results

2530 lots; plots: 21 estates, 91 clusters, 17 farmyards, 2072 field cells. Worst lot 2.2°, worst
plot 3.4°. Suite 543 checks, 0 failed. Shots c01-c24 read on contact sheets. c04, c05 and c13
now follow their landmark ids, because the landmarks moved when they were squared to the road.

## Open questions

- The cruise terminal and the seaplane base face their road, not the water. Should waterfront
  landmarks face the water instead?
- Wheaton keeps its square grid lots. Sachin may want some uneven clusters at the town edge.

## Traps and constraints

- Any change to `build_country.py` shifts the rng sequence, which moves everything placed after it.
  Regenerate the data and recheck the tests and shots each time.
- Shots must use landmark ids, not fixed coordinates, for the same reason.
- `mb.flat` polygons must wind with increasing angles (positive area), or they draw invisible.
- Grounds surfaces are layered: base pad at -0.005, surfaces at +0.005, lot pads at 0.03. Keep
  yard patches above the base pad.

- Street plan must dump identical (seed 1234); the country only reads it.
- Lot yaw follows Godot `Basis(UP, yaw)`: local x -> (cos, -sin), local z -> (sin, cos);
  `yaw_facing(nx, ny) = atan2(nx, ny)` with (nx, ny) pointing from the road to the lot.
- The `mansion` kit draws its own lawn pad, forecourt loop, drive and gate piers inside its lot.
