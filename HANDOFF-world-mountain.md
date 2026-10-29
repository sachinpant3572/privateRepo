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
