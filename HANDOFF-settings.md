# HANDOFF: 0.19 settings screen, FPS limit, headlights

Sachin's ask (2026-10-28): "Lets keep all these settings, but also show a preview
for each camera setting change, we can overhaul the settings screen to show the
pewview side by side without resuming the game, lets create multiple tabs for
settings to keep respective settings in their own tabs, lets offer FPS limiter
(30, 60, 75, 90, 120) also the setting scrollbar is a bit hard to scroll, + the
car light stopped showing in some parts while travelling at night. And what do
you mean by Tilt near Towers?"

## Decisions

- **Headlights on slopes.** The beams and the red tail pool were flat quads at
  the car's height, so on a grade they sank under the road ahead (uphill) or
  floated off it. They now use `MeshBuilder.ground_glow_material()`: the vertex
  shader drops each vertex onto the terrain height, read from a global RG8
  texture of the country height grid (`terrain_dm`, `terrain_grid`, set by
  `Terrain.load_data`). The beam is cut into 5 pieces so it bends over a crest.
  Lamp pools (y 0.7, at the lamps) stay on the plain glow material.
  Verified with `SHOTS=lights` (flat, crest and canyon, uphill and downhill).
- **Settings screen** (`scripts/settings_screen.gd`): a full-screen page inside
  the phone with tabs Camera / Graphics / Controls / Game. The list is on the
  left with a hint under each row; on the right a live preview: a SubViewport
  sharing the world, its camera copying the game camera every frame. The game
  stays paused; only the game camera is set to process (ALWAYS) while the page
  is open, so setting changes ease in the preview exactly as in play. The main
  viewport's 3D is switched off while the page covers it (one 3D render, not two).
- **Preview "Driving fast"**: `camera.preview_drive` makes the camera frame as
  if driving at full speed up the screen, so Drive zoom-out shows even on foot.
  Touching Drive zoom-out switches the preview to it; a button under the
  preview switches back.
- **"Tilt near towers"** is renamed **"Look down near towers"** with a hint
  (among tall buildings the camera tips further down, up to 85°, then returns
  to the chosen Angle; OFF keeps the Angle). The saved key stays `auto_tilt`.
- **FPS limit**: setting `fps_limit` in [30, 60, 75, 90, 120], default 120
  (Sachin's phone already runs at 120); `Engine.max_fps`. Graphics tab.
- **Scrolling**: phone and settings buttons pass drags through to their
  ScrollContainer (MOUSE_FILTER_PASS); when a drag turns into a scroll
  (`scroll_started`) the button under the finger is cancelled, so a scroll never
  presses a setting. The scrollbar is 26 px wide with a solid grabber, and each
  tab is short.

## Rejected

- Cutting the settings page to half the screen and showing the real game view
  beside it: the camera centres the player on the full screen, so the player
  would sit under the page's edge.

## Traps

- Tests hold stepper and button references across `phone.close()`: closing
  hides the page but never frees its rows.
- **Paused preview stays current** (review fix): the world is paused while the
  page is open, so every 0.25 s the page re-applies the light
  (`atmosphere._apply(0)`), refits the shadows and refreshes the headlights
  (`update_beams` on group "vehicles"); every frame it runs the city's and
  country's own threaded streaming step (`_process(delta)`), so a wider view
  fills in a cell at a time with no hitch. `stream_now` was tried first and
  rejected: it builds every missing cell on the main thread in one call, a
  long freeze on a phone at Distance 130%. Rain particles run while the page
  is open. Weather changed while paused changes at once (only when it changes). Camera turn and Look down near towers only show once the
  player moves or is among towers; their hints say so.
- Not fixed, on purpose: closing from "Driving fast" eases the zoom back in
  over about a second (looks like a transition). 75 and 90 FPS can judder on a
  120 Hz screen; the hint says so (Sachin asked for those values).
- Real-device scroll is not testable headless: ScrollContainer drag-scrolls
  only when a touchscreen is present, so the test emits `scroll_started`.
