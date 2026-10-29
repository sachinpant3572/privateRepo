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

## Plan

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
- Shapes per gender: base, heavy, thin, muscle, old (MH macros); the game
  blends base + sum w*(shape - base). MH maxweight is mild (+8-10% waist),
  so weights may extrapolate to 1.5.
- Mesh LOD works in gl_compatibility (tested: ArrayMesh lods dict, sphere
  switched 16640 -> 100 prims between 48 and 96 m for key 0.2). The far
  index array must hold the extras too (LOD swaps the whole surface).
- Clothes: offline the decimated mesh is cut along fixed rest-height levels
  (hems, cuffs, sock and shoe tops) per part group, so every hem is a clean
  edge loop; runtime picks a region per face from its part and rest height,
  splits vertices at region borders, pushes cloth out by its thickness and
  joins the two edges with a lip strip. Hair is a scalp-region shell.
- Old kit details (shoes, skirts, hats, bags, phone, prints, panels, belts,
  collars) are kept and re-seated: `_surf`/`_girth` read a per-look torso
  table from the blended body instead of the old ellipse profile. The old
  torso loft, limbs, hands and head are replaced by the body.
- Gender: look.body "male"/"female" (random looks: col 1 male, col 2
  female; named looks set it). Shape weights from build, category
  (athlete muscle, elderly old).

## Traps

- `git ls-tree -l` on a blobless clone fetches every blob; use sparse.
- `pkill -f <pat>` kills its own shell if the pattern is in the command.
