# HANDOFF people v2: MakeHuman crowd bodies on our skeleton

Sachin, 2026-10-29, on the hybrid plan ("one skeleton for everyone; hero and
story characters from Meshy or a bought model; the crowd from MakeHuman
bodies with a set of outfits"): "Yeah lets do this. But will this affect
the Framerates?"

## Sources and licence

- MakeHuman 1.x assets, CC0 since Sept 2020 (LICENSE.ASSETS.md in
  github.com/makehumancommunity/makehuman). Used: data/3dobjs/base.obj
  (hm08, 19158 v), targets/macrodetails (+ height, proportions),
  rigs/default.mhskel (joints = mean of listed vertices) and
  rigs/default_weights.mhw (163 bones, CC0).
- Fetch (GitHub works, the MakeHuman sites do not):
  `git clone --filter=blob:none --sparse --depth 1
  https://github.com/makehumancommunity/makehuman /tmp/mh/mh` then
  `git sparse-checkout set makehuman/data/3dobjs makehuman/data/targets/macrodetails makehuman/data/rigs`.
- Blocked from the container (not retried): Sketchfab API, Meshy API,
  blender.org, makehumancommunity.org (files., static., www.), tuxfamily.
  So the MakeHuman clothes, hair, proxies and game-engine rig are not
  available: clothes are made as shells of the body.

## Decisions

- Fit: MH body posed (arms down, palms in, fingers relaxed) and kept in its
  own proportions, scaled whole per gender (base shape 1.76 m male, 1.65 m
  female; shapes share the gender's scale). Sachin, 10-29, on 0.24: "The
  human shoulders are too high, looks like a deformity". Cause: our BONES
  table (shoulder 1.41, neck 1.45, head 1.53) vs a real 1.75 m body
  (shoulder 1.40, neck 1.50, head 1.60) squashes the neck; forcing MH onto
  it put the shoulder tops above the chin. Now male chin 1.51 / shoulder top
  1.49, neck joint 1.51. Joints per shape in body.json; build_rig must use
  the look's blended joints (nothing outside the kit hard-codes heights).
- Decimation: meshoptimizer (keeps a vertex subset), importance by scaling
  (head 2.6x, hands 1.5x, feet 0.6x since shoes cover them). One vertex
  buffer for every shape; far LOD = index subset of the same buffer.
  Result: 1502 v, near 3000 tris (head 1016, hand 229), far 1000.
- Shapes per gender: base, fat, thin, muscle, old, young, tall, short
  (MH macros); the game blends base + sum w*(shape - base), joints too.
  Sachin, 10-29: "Build different models for different heights, weight and
  muscles, some will be short, some skinny, some muscular, some have huge
  height, some are fatty, some are normal, some are young, some are old,
  some are mid aged, some are adults but just crossed 18. We need to have
  several body types with a mix of these properties." Axes: young = MH age
  0.344 (18 yrs) kept at adult height; mid-aged = old 0.25-0.45 (MH age is
  linear 25-90 yrs); tall/short = MH height macro (full weight 2.5 m /
  1.4 m, so looks use 0-0.4); thin to 1.3.
- Fat (Sachin, 10-29: "I dont see fat body types, a bit chubby, then fatty,
  and then super fat, in all different heights and both genders"). MH
  weight 1 adds under 10% to the waist, so `fat` = weight 1 + MH detail
  targets (FAT in build_people.py: pregnant belly, waist/hips/bust/thigh/
  neck/arm/calf circ, buttocks, torso depth, limb fat, cheeks) x 1.7: the
  shape is super fat. Looks: about 0.25 chubby, 0.55 fatty, 1.0 super fat,
  any stature, both genders (checked front and back on a 24-body render).
  Faces fill out with it (Sachin, 10-29: "Fat should be visible on some of
  their faces too, based on how much bodyfat do they have"): head-fat,
  neck-double, chin width and inner cheeks are in FAT. The mesh is
  simplified on a body half way to fat so bellies and hips keep triangles. Wide shapes turn
  the arms out (`pose_rest(spread=)`) until the forearm clears the body by
  ARM_GAP (male fat 0.18 rad, female fat 0.26; slim shapes 0-0.06). The
  upper arm of a fat body rests on its side. Joints blend linearly, so a
  chubby look gets a part spread.
- Look keys: body (male/female), weight (-1 thin..1 fat), muscle, age (-1
  young..1 old), stature (-1 short..1 tall); `height` stays a uniform
  scale. A body-type table in the kit (normal, skinny, chubby, fatty,
  super fat, muscular, short, very tall, teen-adult, mid-aged, old, mixes)
  picks them.
- Mesh LOD works in gl_compatibility (tested: ArrayMesh lods dict, sphere
  switched 16640 -> 100 prims between 48 and 96 m for key 0.2). The far
  index array must hold the extras too (LOD swaps the whole surface).
- Clothes (revised, no offline cuts): the kit computes fit tables at
  runtime from the blended verts (torso slices: half width and front/back
  depth on a height grid, shoulder-top silhouette; neck ellipse; limb radii;
  foot and head boxes). Regions (per vertex since 0.25, below) from part and canonical
  centroid (skin, top, sleeve, cuff, bottoms, socks, hidden feet, scoop,
  beard); vertices split at region borders with shared positions; cloth
  offset = max of adjacent regions (tee ~0.004, puffer ~0.036). Offline
  adds only a per-vertex face attribute (lips, brows, beard areas).
- Old kit extras are kept and warped onto the body by a post-pass, chosen
  by bone mark or a MeshBuilder `tags` entry: torso (level by joint knots,
  x/z remapped to the body's half width and depth, shoulder-top remap
  above 1.40), skirt (radial), neck (collars, necklace, hood), head (affine
  from the kit head, c = (0, 1.69, 0), to the body head box), arm/leg
  (segment frames between joints), foot (shoe box to foot box), hand items
  (moved by the hand joint delta). Removed in body mode: torso loft,
  shoulder balls, limb tubes, `_hand`, neck tube, head loft and face parts,
  beard ball. Body extras: eyeballs with irises at the blended eye centres.
- Hero mesh (Sachin, 10-29: "Ensure that our hero has much better
  structure and looks than the NPCs"): a second, denser simplification of
  the same body, `hero/` blocks beside `crowd/` in body.bin (5002 v, near
  10000 tris, far 3000; crowd 1502 v, 3000/1000). Only one hero is on
  screen, so the cost is about 7k tris more than a crowd person. Hero look:
  athletic (muscle about 0.5, tall about 0.15), the kit's finer `hero`
  details (sides 12, stripes).
- Gender: look.body "male"/"female" (random looks: col 1 male, col 2
  female; named looks set it). Shape weights from build, category
  (athlete muscle, elderly old).

## Kit integration (0.25)

- Regions per vertex (`BodyKit._region`), not per face. A triangle whose
  corners differ is split along its edges: on one bone's part the cut is
  found by bisecting `_region` (6 steps); across two parts it sits where
  the two bones' skin weights are equal (smooth armholes). Regions with the
  same colour and thickness merge first, the far LOD is never cut, and
  hidden feet are not cut. Cost: near crowd body 3000 -> about 3440 tris.
- The waistband is a level line between the hip and spine joints
  (`_below_waist`, `waist` per outfit, none for dresses), not the bones'
  ragged border; it runs over the thigh tops too (LEVEL_PARTS, bisected
  across parts). Tucked tops end under the belt (0.9). Under skirts and
  dresses the top 30% of the thighs takes the skirt's colour.
- Neckline: `fit().neckline`, 16 angle bins, where the neck outline meets
  the chest (male front about 1.455, back about 1.52; women's back clamped
  to neck joint - 0.03). Collars map old heights over 1.465 onto it, a
  quarter lower under the jaw, at 2x WARP_GAP.
- Warp (`CharacterKit._warp`): torso details by height knots and the body's
  slice outline, lift kept at 60% (WARP_KEEP) plus WARP_GAP 4 mm; limbs
  along the new bones; head by the head box; rigid groups (`rigid` tag)
  move whole. Normals after the warp take the side of the old normals
  (Godot winds front faces clockwise, so the cross product points in: it
  had turned every warped detail dark); coincident corners facing alike
  share normals. Details within 3 cm of the hem sit over the thicker cloth.
- Body mode drops the kit's hem bands: the body's TOP/BOTTOMS border is the
  hem. Open fronts: 3x3 quads at 30 mm lift (16 z-fought the crowd chest).
  Belts are a straight ring (`_ring`) at 1.06x the old torso.
- Budgets (near LOD, measured): crowd average about 4230 tris (was 2440 on
  0.24), most about 4660; hero 11200. 20 people about 85k of the 180-200k
  frame budget; the far LOD is under half.
- Cast looks set the body keys; convertible seats use `hip_height`.

## Review fixes (10-29, review of 9d7ccca..7f7fe5d)

- Seats and rides: the rig's lifts assumed the old 0.92 m hip; now
  `lift + (0.92 - hip) * h` with `hip` from `hip_height(look)` stored on the
  Rig at build; `_leg_drop` takes the look's thigh and shin lengths.
- Build time (crowd 2.8 -> 25-36 ms, hero 85 ms, on the main thread at
  spawn): the region/cut work depends only on mesh, gender, the dress's
  shape fields and which regions merge, so it is cached as a recipe
  (output vertex = source a, b, t, region; skin mix; wound near/far
  indices; per-vertex region mask for the push). A build only lerps.
  fit() uses per-mesh edge and limb vertex lists instead of whole sweeps.
  Measured (12 category looks, this container, ms): crowd add_body 21.1 ->
  1.2 with the recipe cached, 12-13 for a new recipe (LRU of 64 dresses);
  fit 5.8 -> 3.5 (results byte-identical); whole CharacterKit.build 25.5 ->
  about 5. Hero add_body 4.1 cached / 32 new, whole build about 8-14 (was 85).
- Hats: covering headwear sets the scalp thickness to 0 (no hair through).
- T-junctions: three-region triangles split as a fan through a centre
  point; whole-region triangles (hidden corner) take their neighbours'
  cut points on cut edges, so no edge is cut on one side only.
- Face lines: build_people.py exports a smooth margin per face code
  (`face_m` block, 4 floats: lips, beard, neck beard, scalp); an edge
  between two face codes is cut where the deciding code's margin is 0.

## Traps

- `git ls-tree -l` on a blobless clone fetches every blob (use sparse);
  `pkill -f <pat>` kills its own shell if the pattern is in the command.

## Hero systems (planned, after the kit integration)

Sachin, 10-29: "We can also setup a skinny, muscular, fat system like in
GTA for our Hero, and Hair + Beard growth mechanism like from RDR2."
- Body: hero `fat` and `muscle` stats (0..1) drive the look's weight and
  muscle blend. Eating (diner meals, store food, bag snacks) adds fat;
  sprinting, walking and boxing at The Pit burn it; boxing and workouts
  add muscle; going long without food loses both slowly. Saved with the
  game; the hero mesh is rebuilt when a stat moves past a step.
- Hair and beard: lengths grow with game days (hair slower than beard),
  drawn as length steps of the kit's hair and beard; a barber place trims
  or styles them for cash. Saved with the game.

