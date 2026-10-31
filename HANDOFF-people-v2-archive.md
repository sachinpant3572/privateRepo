# HANDOFF people v2: archive

Finished history moved out of HANDOFF-people-v2.md.

## First plan (2026-10-29, built)

1. `game/tools/people/build_people.py` (offline, numpy + pyfqmr + trimesh):
   body group of base.obj, macro targets per body variant, pose the arms
   down and curl the fingers with the MH rig (LBS), fit each of our 17
   BONES segments (per-bone affine along the bone, blended by weight), so
   rig.gd animations and held-item offsets stay as they are. Decimate once
   (head kept denser), carry weights, parts and variant positions to the
   decimated vertices by barycentric lookup on the source surface.
2. Output one binary file per LOD in `game/assets/people/`, shared topology
   for all variants; GDScript blends variants per look (gender, weight,
   muscle, age) like MakeHuman does.
3. `scripts/kits/body_kit.gd`: per-face region rules from the look (top,
   sleeves, bottoms, shoes, socks, hair) -> vertex colours, cloth pushed out
   along the normal, a lip strip at each cloth edge; then the existing kit's
   extras (hair styles, hats, bags, glasses, prints) on the same mesh. One
   surface, one draw call.
4. Frame budget: about 3.5k tris near, about 1.2k far; 20 people about 70k
   of the 180-200k budget.

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
