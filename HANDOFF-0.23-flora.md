# 0.23: plant variety and a green/dry mix on the hills

Sachin, 2026-10-28: "Add more variety of trees, in the mountains, bushes,
shrubs etc too. And add greenary + dry land a mix of both. See gta Vs
mountaineous region."

## Where it starts (survey)

- Country scatter (`country_tiles.gd` `_trees`): a 10 m grid. Each zone has
  one kind and a spacing in `TREES`. The mountain zone is chaparral on
  every cell, with 18% round oaks. Nothing reads height, slope, aspect or
  moisture.
- Hill ground: `_hill_shade` bakes light and colour per vertex (9 m
  triangles): scrub on north faces, gold on south faces, rock above 70 m.
  There is no patchiness, so whole faces read as one colour.
- Everything is baked into one mesh per tile, so there is no MultiMesh and
  no LOD. Quality presets do not scale plant counts.
- Trees on hill tiles are draped vertex by vertex, which shears their crowns.

## GTA V reference (what reads as "Los Santos hills")

GTA V's hills are Southern California chaparral and oak savanna:
- Vinewood Hills and Tataviam: south and west faces are golden grass with
  scattered chaparral, yucca and lone oaks.
- North faces and canyons: dense, dark green scrub oak, chamise and live
  oak woodland.
- Canyon floors: sycamores and green grass along the creeks.
- Mount Chiliad: pines and green on the cool upper north side.
- Ridges: exposed rock outcrops and boulders.
- Roadsides: eucalyptus groves.
The look comes from green and dry patches broken up by aspect, height and
water, not from a single colour per zone.

## Design (decided)

- `scripts/kits/flora_kit.gd` (new): the species meshes and the ecology
  model. `country_tiles.gd` calls it.
- Moisture `m` (0..1) at a point combines:
  - north-facing aspect;
  - low ground (canyon floors and the base of the hills are wetter);
  - a smooth world-space noise (patches of about 60-120 m), so the mix is
    patchy but seamless across tiles.
  The same `m` drives both the ground colour and the species, so green
  ground carries green plants.
- Ground: `_hill_shade` lerps between dry gold and green grass by `m`,
  keeps the north-face scrub darkening and the baked light, and shows rock
  on steep faces (not only high ones).
- Species by band (kind is weighted by `m`, height and slope):
  - wet low ground (riparian): sycamore, live oak, green bush, green grass;
  - wet mid slopes: live oak woodland, scrub oak, toyon bush, eucalyptus
    groves in noise patches;
  - high and wet (above about 75 m): pines with some oaks;
  - middle: chaparral, manzanita (red stems), scrub oak;
  - dry: golden grass tufts, yucca, prickly pear, sparse chaparral, a lone
    oak;
  - steep or high: boulders and rock outcrops.
- Ground cover: a second, finer scatter (5 m grid) on wild hill ground
  (grass tufts, small bushes, rocks). The flat country zones get
  weighted species mixes instead of a single kind (variety everywhere).
- Hill trees are lifted rigidly to the ground under the trunk (`_rigid`),
  no longer sheared.
- Cost and phones:
  - caps per tile (`MAX_TREES`, `MAX_COVER`);
  - Low quality halves the ground cover (`CountryTiles.cover` set from
    main.gd like `Fx.set_quality`);
  - tile rebuild cost is measured.

## Options and cost

- Chosen: the ecology model, about 9 new species, patchy green/dry ground,
  ground cover and mixed zones. Main session, about 1.5-2 h and roughly
  250-350k tokens.
- Cheaper: add species to the zone tables only (no moisture or ground
  change), about 40 min. Rejected, because Sachin asked for the green/dry
  mix by name, and that is the ground model.

## Traps

- The tile rng order: trees draw from `ctx.rng`, so changes reshuffle
  later picks in a tile. Fine here: nothing after `_trees` relies on the
  layout (check the tests).
- Noise must be in world space, or the patches break at tile seams.
- Tiles build on worker threads: the kit stays static, with no node access.

## Built (state)

- `flora_kit.gd`: 13 kinds (`KINDS`), `moisture`, `ground`, `pick`,
  `pick_from`, `plant`, `tufts`, `rock`, `noise`.
- `country_tiles.gd`: `_trees` = `_scatter` (ecology on wild hill ground,
  weighted zone mixes elsewhere) + `_cover` (5 m grid, hill tiles only);
  `_plant` lifts each plant rigidly (`_rigid`); `_hill_shade` takes the
  ecology's ground on wild verts (`Ctx.wild`).
- `main.gd`: `Country.Tiles.cover` is 0.5 on Low, else 1.
- Tuning after the first shots: green was lime and wide views read all
  gold, so GREEN went to (0.27, 0.37, 0.18), DRY to (0.72, 0.6, 0.36), the
  green smoothstep to (0.26, 0.64), patch weight 0.62 -> 0.8, and dry faces
  got more chaparral (1.2 * dry) and less grass (3.0 * dry).
- Measured: north faces 0.62 moisture against 0.27 south; ground about
  63% golden / 37% green on a hill sample; 13 kinds picked; worst hill tile
  build 67-76 ms headless on the cloud box (was about 19 ms), on worker
  threads.
- Test: `test_flora_kit_and_hill_ecology`. Shots: `SHOTS=flora`.
