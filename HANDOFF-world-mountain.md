# HANDOFF: world phase 2, Mount Calder (the mountain range)

Task (Sachin, quoted in the main session's brief): "Mountain should be raised to 1000mtrs, with several
small mountains around it, and continuing mountain line, seemlessly mering with the city and around it,
just like we have in San Andreas and GTA V." / "I want the mountain to be such that the whole city, or
most of it can be seen from the top ... either by flying or riding a bike to top or by driving, and the
mountain should have multiple ways to reach, either by main road, by the forest itself, or by shortcuts,
through underpasses etc." / "No this wont be skipped. We will build everything."

Built by a sub-agent in worktree `.claude/worktrees/agent-a01c2f4e315ebd3c5`, branch
`worktree-agent-a01c2f4e315ebd3c5` (from b6e2e21). Follows `HANDOFF-roads-mountain.md` (M-6, the old
114 m Bellerive Hills, which become the foothills).

## Baseline (before this work)

- Committed `country.json` was stale against the committed plan: suite 1542 passed, 16 failed, plus
  millions of NaN transform errors (`test_country_tiles_stream` put the player at Vector3.INF, a missing
  `deco_row` lot) and `terrain.gd:64` index errors from NaN input.
- After regenerating `country.json` from the current plan and guarding `Terrain.height()` against NaN:
  **1543 passed, 15 failed** (9 tests: city_streams_cells, street_plan_is_a_california_grid,
  city_outline_is_organic, perspective_camera, hero_seen_under_roofs, taxi_phone_call_and_skip,
  country_joins_the_city, country_tiles_stream, every_home_has_a_way_in). These belong to the street
  plan the main session is rewriting; this work must not add to them.

## Decisions

- W-1 **Shape** (`tools/mountain.py`): Mount Calder, summit (950,-2750), a cone with a rounded plateau
  (r 85 m) whose foot radius and concavity vary by bearing, plus sharp-topped crest "tents" (West Ridge
  to Cinder Ridge, East Ridge to the Verdant Hills, N, S, SW, W, SE, NE spurs), value and ridged noise
  growing with height (none on the plateau), faded to 0 over 260 m from the urban outline. The old
  Gaussian hills stay as foothills, raised up to x1.9 toward the massif.
- W-2 **Water**: the Morrow now runs round the range's west and north foot in a gorge (world_map.json
  river line moved; Pine Creek re-laid; Dellwood, Fernmoor and the sawmill moved to the north foot).
  The range stops at the river (held under WALL x distance past BANK) and fades out past it.
- W-3 **Planner** (`tools/mountain_plan.py`, offline, minutes per line): A* over (8 m cell, heading)
  keeping each line to its design grade on the smoothed ground, hairpins as arcs, optional tunnels
  (straight, level, under 15 m+ of ground) and bridges. Output `tools/mountain_lines.json`
  `{id: {cls, name, tag, keep_head, pts, spans [[s0, s1, kind]]}}`; the builder only reads it.
  `calder` needs a bbox override (300,-3000,2000,-300): a wider box runs out of states.
- W-4 **Map routes re-laid** over the range (tag "route": Route 9, Wheaton Road, Dam Road,
  Firebreak Road, Pinecrest Logging Road, Old Post Road) and written back into world_map.json with
  their bridge landmarks (scratchpad wm_routes.py logic; rerun after re-planning).
- W-5 **Road bridges are wet-only** (`_wet_only`): the game lays roads on Terrain.height and decks
  only over water, so a planned bridge keeps just its water stretch +-4 m.
- W-6 **No road tunnels**: the game cannot draw a road under ground. Road tunnel spans would stop the
  road at barricaded portals; the planner found none needed. Rail tunnels and viaducts are taken out
  of `rails` and exported as `structures` (data only, no meshes yet).
- W-7 **Trail underpasses**: a trail crossing a lane or bigger passes under it (span 'u', +-(hw+12) m,
  pinned UNDER_DROP 6.5 m below the road); the trail piece inside is not laid. Data only.
- W-8 **Summit** (`SUMMIT_SITES`, local metres): car park 36x24, restaurant 40x30, helipad 30x30,
  viewing deck 24x14, cable top 26x16, flat pads in the grid; `country.json` `mountain.sites`.
- W-9 **Cable car** (`Mountain.cable()`): bottom (0,-430) at the city's north edge, mid-station
  (475,-1590), top at the summit; towers where clearance < 18 m or spans > 400 m, 30-45 m tall.
- W-10 **Play area** extended over the range (mtn.poly, 14.5 km2, 5.2 km2 of it over Red Pine).
  Red Pine inside it gets only terrain, roads, forest and pads (no homes); homes up to 400 m.
- W-11 **Game side**: country.gd reads `structures`, `rail_pass`, `mountain`; flora: pine forest from
  120 m, oaks thinning above 450 m, rock above ~700 m; `_hill_shade` rock from 650 m; top-down camera's
  open-ground rays start 400 m over the ground there and its far plane grows with ground height.
- W-12 **Rail pass** (`rail_pass` in mountain_plan.py): the Morrow Freight Line from (-50,-850) to
  (1500,-4930), one leg (a waypoint pins the line's height there, which broke the 2.5% grade), cells
  outside the range blocked except 250 m round its ends (`inside`) so it stays inside the river loop,
  no viaducts over water (`wet_bridges=False`). Result: 5640 m at 2.5%, along the east gorge wall,
  viaducts 2456-2546 and 5480-5614 m, a 1 km tunnel through the NW spur at 3455-4462 m.
  world_map.json's freight line is `[o[0]] + pass reversed + o[5:]` (wm_routes.py). The builder
  fillets rails at r 300 m; spans are found again on the built line within 8 m (`_spans_on`).
- W-13 **Rail crossings** (`Mountain.grade`, `_rail_finish`): the rail is graded first; a road
  crossing it where their own heights differ by >= RAIL_CLEAR (7 m) passes over or under it as is;
  the other crossings are chosen together along the road by a small DP (a road and the rail sharing
  a gorge cross several times): at grade, under (h-7, rail bridge) or over (h+7, rail cover), cost
  10 x miss against every pin and the previous choice + |v - own| (+2 for a separation). Each
  separation becomes a rail span (half hw+6 'b', hw+10 't') and a data-only `structures` entry.
  The reported grade leaves out steps between two pins on the same earlier road (shared stretch).
- W-14 **Wheaton Road** re-planned with `low_bridges` (deck no higher than LOW_DECK 4 m over 0,
  clearance -1): a wet-only high bridge left a 10 m step at the bank. Dam Road and Pinecrest bridges
  are outside the play area (render only) and keep their planned bridges.
- W-15 **Loose ends**: a map route's end within 2 m of the play-area edge is not pinned to the ground
  (it is barricaded there), which had made 30% stubs.
- W-16 **Hill sites by search**: hill letters (160 m) and masts (120 m) take the nearest spot clear of
  the re-laid ways (spiral every 10 m x 16 angles, 3 m off roads); the observatory keeps its design
  spot and its drive from OBSERVATORY_ROAD_END (join_ends skips that end). Calder Trail now starts
  past the observatory's back corner (it cut the lot).
- W-17 **Farmyards** skip a spot where a home's front has no road within REACH_MAX (a curve on the
  re-laid Wheaton Road left a cottage with no way in).
- W-18 `tools/mountain_world_map.py <pre-range world_map.json>` writes the re-laid routes and bridge
  landmarks into world_map.json (orig: `git show b6e2e21:game/data/world_map.json`).
- W-19 **Shared stretches** (`Mountain.grade`): where a road or track runs near-parallel (|cos| >=
  0.7) within the two half widths + 16 m of an earlier non-trail, non-rail way, its points take that
  way's height, kept only where every pin stays reachable at the class grade (without that check it
  made new kinks: Canyon 0.17, Larkspur 0.5). This fixed Crest Drive and Summit Fire Road.
- W-20 **Hairpin legs**: the A* has no path memory, so after a hairpin a leg can drift back to 9-14 m
  of the leg below; the two cores at different heights share grid nodes and the grade spikes.
  `separate()` (mountain_plan.py; `--separate ids` re-runs it on stored lines) pushes a line's own
  near-parallel legs apart to 2hw + 10 m (at most 2r - 1), smoothed, ends fixed, <= 12 m; specs with
  `separate=True` (calder 5.8 m, west_ridge_track 2.6 m). A spec's `apart` ids are ways it alone is
  pushed off (hw + ohw + 10 m, not within 12 m of a joint/crossing); `apart` on Larkspur made
  4.8 m kinks and was dropped. A blanket push off every earlier way was tried and dropped: Calder
  rides on Observatory/Crest/Canyon for stretches (shared carriageway) and slid off (610 m). Lines
  joining a moved line ("on" ends) are snapped back on (`_resnap`, 40 m taper).
  The tracks' real trouble was their ends: West Ridge met Calder at (731,-2539) and then ran 760 m
  more beside it to (860,-2620); Larkspur crossed Calder 8 times and shadowed Summit Fire Road 8 m
  off. Both now end "on" Calder where they first meet it ((731,-2539); (1340,-1343)).
- W-23 **join_ends** skips the summit car-park end of Mount Calder Road: it had tied it with a
  straight 79 m 47% track to West Ridge Track's junction.
- W-24 **test_bellerive_hills "grass through" 0.297 m** at Canyon Freeway (2673,-1545) was the test's
  `_surface_top`, not the road: the lane sample (hw/4 across) lay exactly on a strip triangle edge
  (hill strips are halved to HILL_PIECE) and float32 put it outside both; the helper now allows 1e-4.
- W-21 **Grid priority** (`Mountain.grid`): the rail core always owns a node (dk = d - 1000; Route 9
  had creased the shelf), trails yield to any road (d + 1000) and a trail's margin no longer flattens
  a pad (the deck). Partly-covered rail spans are clipped to the pass, not dropped (`_rail_finish`).
  test_mount_calder skips rail points off the height grid (past the play area: drawn only).
- W-22 **Summit**: sites moved clear of the spiral (SUMMIT_SITES comment: a box needs hw + 15 m from
  a road); Mount Calder Road's last 60 m are level into the car park (`grade(flat_end=)`); the
  restaurant sits on the car park's level (one terrace; it is 8 m away).

## Open issues

- The view of the whole city from the top needs a far LOD (terrain and city silhouettes): the
  country streams 130 m round the player and Look up hazes the ground out from 140 to 420 m.
- Tunnels, viaducts, underpasses, the cable car and summit buildings are data only (no meshes).
