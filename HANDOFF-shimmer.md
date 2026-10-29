# Shimmer and texture overlap (2026-10-29)

Sachin: "There are shimmering, and texture overlap issues occurring in the game."
No location given; causes found with a probe (`game/tests/shimmer_shots.tscn`).

## Probe

- `xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --resolution 1280x720 res://tests/shimmer_shots.tscn -- <dir>`
  (env: `ONLY=spot,spot`, `AA=1`, `QUALITY=…`, `ZPROBE=1`, `ZNEAR=…`).
- Spots: 5 landmarks, 5 road classes, 2 mixed-surface country junctions, a driveway.
  Views foot (26 m), drive (62 m), and with ZPROBE far (80 m, drive zoom 1.3).
- Default mode: shot a, camera nudged 1/3 px, shot b. Pixels that change are what
  crawls when the camera moves. ZPROBE: same place, near plane n vs 1.5n, shadows off:
  only depth precision differs, so changed pixels are surfaces fighting.
- Metric: `compare -fuzz 5%/15% -metric AE`, plus RMSE. AE5 rises with MSAA (soft edges
  change a little everywhere), so read AE15 (hard flips) and RMSE for MSAA.
- Never use `/tmp/shots.log`: other sessions write it. Log next to the output dir.

## Findings

1. Shader aliasing (main cause of shimmer). `game/scripts/mesh_builder.gd`, SURFACE_COMMON
   `pattern()` and `surface()`: asphalt speckle (1/9 m cells), crack hairlines (12 mm),
   concrete speckle, paver/brick/tile joints, roof seams, solar cells, siding laps and
   foliage noise were point-sampled, smaller than a pixel at drive zoom (0.086 m/px).
   Before: AE15 = 4.5k–72k px per 1/3-px nudge (drive 24k–72k).
2. No AA by default: High (the default preset) had `aa` off; only Ultra had 4x MSAA.
   Building edges, kerbs, lane-marking boxes, poles and railings stair-step and crawl.
3. Z-fighting ("texture overlap"), proven with ZPROBE (near n vs 1.5n, shadows off):
   - Country road strips (`country_tiles.gd` `_road`) all lay at ROAD_Y. `_strip` runs to the
     node centres, so at a junction, past the pad circle (r = w/2+0.6 < (w/2)·√2 at the
     corners), strips of different surfaces overlapped in one plane: stripes flicker.
     junction2 (-160, 492.8; highway worn/fresh + streets) AE15 foot 5013, drive 6097.
     The junction pad (ROAD_Y+0.003) and the driveway (ROAD_Y+0.002) sat inside that range too.
   - City quarter streets (`city_cells.gd` `_street` "quarter"): paving boxes run 0.5 m past
     the setback into the junction; two PAVER_KINDS met in one plane (boulevard spot,
     wedges by the crosswalk, AE15 drive 793).
   - Depth precision: near plane 1 m with 1.5–3 mm layers fights from ~150 m out
     (24-bit depth, Δz ≈ z²/(near·2^24)).
   - Not z-fighting: quay (water animation), bird flocks (moreau, city_hall, union_station,
     aurum, avenue: scattered dots that move between shots).

## Fixes

- Shader (commit a7b713f): `fine(fw, size)` fades detail smaller than ~a pixel to its
  average; `aa_line()` box-filters joints/seams, keeping average coverage. fwidth taken
  once at the top of `surface()` (uniform control flow). Crack lines rewritten to the
  same look with a filtered width. After: AE15 drive 8k–20k (2–4x less), foot 4k–14k.
- AA: `graphics.gd` PRESETS.high.aa = true (High is the default; Ultra is now the same
  set). `main.gd:44` default settings `"aa": true` (one-line change). Existing saves keep
  their own aa value (settings merge from the save): re-pick High or turn on Smooth edges.
  Cheaper option if phones slow down: set PRESETS.high.aa and main.gd aa back to false
  (AA on Ultra only, as in 0.22).
- Camera (`top_down_camera.gd`): NEAR_CLIP 0.3; perspective near = max(1, 0.15·0.3·base)
  = 1.86 m on foot, 4.42 m driving, 5.71 m at zoom 1.3. The near fade already discards
  everything nearer than 0.35·fade (2.15 / 5.16 / 6.66 m), so nothing visible is clipped.
  Orthographic keeps 1 m. Look-up/close-up still lerp from it to 0.3/0.2 (unchanged).
- Country (`country_tiles.gd`): SURFACE_LIFT dirt 0 / gravel 1.5 / washed 3 / worn 4.5 /
  fresh 6 mm over ROAD_Y; DRIVEWAY_Y +7.5 mm; PAD_Y +9 mm; far roads: loose at dirt, paved
  at worn. Markings (boxes to 0.02) stay above.
- City (`city_cells.gd`): PAVER_LAYERS order pavers/tile_brown/tile_white/setts; each quarter
  paving box is lifted 1.5 mm per layer (top ≤ 0.0195, under the zebra at 0.025).

## Results (ZPROBE, AE15 before -> after)

- junction1 foot 4497 -> 0; junction2 foot 5013 -> 0, drive 6097 -> 5, far 1142 -> 8;
  boulevard drive 793 -> 1; city_hall drive 509 -> 0; lantern_square far 319 -> 2.
- Left: bird dots (random flocks) and the driveway spot's boardwalk lines (see Open).
- Images: `/tmp/shimmer_shots/z_beforeafter_diffs.png` (red = changed pixels).

## AA in Compatibility (facts, with sources)

- godot-docs `tutorials/3d/3d_antialiasing.rst` (raw.githubusercontent.com): MSAA and SSAA
  in all renderers; TAA, FSR2 Forward+ only; FXAA, SMAA, roughness limiter not in
  Compatibility. "2× MSAA may be usable in some circumstances, but higher MSAA levels are
  unlikely to run smoothly on mobile GPUs."
- Godot source `drivers/gles3/storage/render_scene_buffers_gles3.cpp` (4.4-stable): on
  Android it renders with `glFramebufferTexture2DMultisampleEXT`
  (EXT_multisampled_render_to_texture): "MSAA is only done in tile memory only. On mobile
  this means MSAA never leaves tile memory = efficiency!" No resolve pass, no extra
  bandwidth; the cost is mainly fragment work on edge pixels. The 4.7.2 Linux binary has
  the same path (its "isn't supported on this platform" string).
- graphics.gd's 0.22 note already judged AA "cheap on phone GPUs" (Ultra = High + AA).
- Cost could not be measured here (llvmpipe, no phone GPU).

## Rejected

- FXAA/SMAA/TAA: not available in Compatibility.
- Render scale > 1 (SSAA): 2.25–4x fragment cost.
- Textures/mipmaps: the world has no textures; patterns are procedural.
- Editing settings_screen.gd ("Smooth edges … 4x MSAA" label): off limits this task.

## Tests (test_runner.gd, end of file)

- test_shader_patterns_filter_by_footprint, test_high_preset_and_default_have_msaa,
  test_camera_near_plane_keeps_depth_precision, test_ground_layers_never_share_a_plane.
- test_graphics_quality_presets (line 1674) now expects 4x MSAA on a new game.

## Docs host

- docs.godotengine.org is blocked from this container (CONNECT 403); used raw.githubusercontent.com.
