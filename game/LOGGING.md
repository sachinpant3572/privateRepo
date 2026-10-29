# Game log

`scripts/game_log.gd`, a node `main.gd` adds first thing. It records the
session, a snapshot of the game once a second, events as they happen and every
engine and script error, so a shared log shows what went wrong, when, where and
how the game was running.

## Files

- `user://logs/log0.txt` is the current log; at 4 MB it moves to `log1.txt`
  (and `log1` to `log2`; three files are kept, at most 12 MB). A new session
  also starts a fresh `log0`. Each file starts with the session header
  (`continued=1` on a file that follows a full one).
- Lines are buffered and written every 3 s, on a report, and when the app is
  paused, loses focus or closes. A crash line is written on an engine crash.
- The last 1,500 lines are also kept in memory for reports.

## Settings > Game > Log

- **Log** on/off (on by default). Off writes nothing; on again starts a new
  file section with the header.
- **BUG button** shows a small BUG button under SKY on the HUD that marks an
  issue (the same as Report issue, without the export).
- **Report issue** writes a REPORT block (below) and opens Export.
- **Export log** saves all three files as one `solvera_log_<date>.txt`. On
  Android this is the system Save dialog (Storage Access Framework: pick
  Downloads, Drive or anywhere; no permissions). Without a native dialog
  (desktop, tests) it goes to `user://logs/export/`.
- **Copy log** puts the header and the newest 200 KB on the clipboard.

## Line format

```
t=<seconds since start> kind=<kind> key=value key=value ...
```

Values: floats to 2 places, positions `x,y,z` in metres (0.1 m), booleans
`1`/`0`, missing or empty `-`, text with spaces in double quotes (a `"` inside
becomes `'`). Keys named `t` or `kind` in the data are written `x_t`/`x_kind`.

## Kinds

| kind | when |
|---|---|
| `session` `device` `display` `render` `memory` `settings` `camera` `save` | header: version, engine, device model, OS, CPU, screen and scale, renderer and GPU, RAM, every setting (plus `gfx_*`, the graphics tier in use), camera, save slot |
| `snap` | once a second (fields below) |
| `hitch` | a frame over 50 ms and over 1.5x the last second's average frame (at most one line per 0.5 s): `ms` plus a full snapshot |
| `enter_car` `exit_car` | `car` kind, `model`, `stolen` / `passenger`, `thrown`, `speed`, `car_hp`, `at` |
| `crash` `prop_down` | a crash involving the player or over 9 m/s; a prop knocked down |
| `hit_by_car` `knockdown` `death` | a person (`who`, distance `d` from the player, `at`) |
| `enter_place` `leave_place` | interiors |
| `wanted` | the wanted level changed |
| `mission_start` `mission_step` `mission_pass` `mission_fail` `mission_abandon` `respawn` | missions and deaths |
| `settings` | the settings that changed, and `gfx_quality` |
| `save` `load` | the save slot |
| `weather` `night` `day` `area` `region` | seen changing between two snapshots |
| `app_paused` `app_resumed` `focus_out` `focus_in` `close_request` `memory_warning` `engine_crash` `session_end` | the app |
| `error` `warning` | every engine and script error or warning: `type` (error, warning, script, shader, stderr), `at` file:line, `fn`, `msg`, `why`, `stack` (4 frames). At most 30 lines a second; repeats are counted in `error_repeats` |
| `REPORT` ... `report_snap`, `> ` lines, `REPORT_END` | Report issue / BUG: number, date, a full snapshot, then the last 60 s of log lines prefixed `> ` |
| `copy` `export` `log_on` `log_off` | the log itself |

## Snapshot fields (`snap`, `report_snap`, `hitch`)

| field | meaning |
|---|---|
| `clock` | device wall clock |
| `fps` `fps_min` | average and worst-frame FPS over the last second |
| `ft_avg` `ft_max` | average and worst frame time, ms |
| `f33` `f50` `frames` | frames over 33 ms and over 50 ms; frames this second |
| `cpu` `phys` | engine process and physics time per frame, ms |
| `draws` `prims` `objs` | draw calls, primitives, objects rendered last frame (all passes) |
| `shd_prims` | of `prims`, those drawn into the shadow maps |
| `mem` `vmem` | static and video memory, MB |
| `nodes` `orphans` `bodies` `pairs` | node count, orphan nodes, active physics bodies, collision pairs |
| `paused` | game paused (menus) |
| `cars` `cars30` `cars60` `moving` | vehicles in the world, within 30 m and 60 m, moving |
| `near` | the three nearest other vehicles within 30 m: `kind@distance`, `:still` when stopped |
| `people` `people30` | people (not the player), within 30 m |
| `peds` `traffic` `cops` `copcars` | population and police counts |
| `lit_cars` `lit_lamps` | cars and street lamps with real lights now |
| `cells` `cell_job` `tiles` | city cells loaded, a cell build running, country tiles loaded |
| `game_time` `hour` `weather` `rain` `wet` `clouds` `night` | in-game clock and weather (0-1 amounts) |
| `pos` `head` `speed` | position (m), heading (0 = north, 90 = east), km/h |
| `moving_kmh` | driving: how fast the car really moves (km/h); `speed` is what the wheels are driven at |
| `mode` `car_hp` | `foot`, `drive:<kind>` or `passenger:<kind>`; car health |
| `area` `area_kind` `region` `in_city` | district, region or town name; the state region; inside the city plan |
| `road` `road_cls` `surface` `road_d` | nearest road, its class and surface, metres from its centreline (looked up again after moving 3 m) |
| `indoors` `place` | inside a place, and which |
| `hp` `cash` `wanted` `unseen` | health, cash, wanted level, seconds unseen by police |
| `act` | what the player is doing (sitting, a gesture, fighting, knocked, dialogue, dead...) |
| `mission` `step` `taxi` | active mission, objective text, taxi state |
| `outfit` | outfit and colours |
| `cam` `zoom` `dzoom` `pitch` `fov` `cam_d` `cam_h` `turn` `look_up` | camera mode, zoom, drive zoom, pitch (degrees), FOV, distance and height above the player, turn mode, looking at the sky |
| `hitches` | frames over 50 ms since the start |

## Cost

Per frame the log only adds up frame times (under 1 µs). The once-a-second
snapshot line costs about 0.14 ms and the road lookup (on its own frame, half
a second later) under 0.1 ms, measured headless in a debug build
(`test_game_log_snapshot_and_events` prints both).
