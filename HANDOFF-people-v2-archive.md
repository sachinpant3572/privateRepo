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

