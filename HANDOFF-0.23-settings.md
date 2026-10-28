# 0.23 settings: screen shake slider, sliders for multi-choice settings

Sachin's ask: "Also, screen shake is too much, give me a slider to change it,
give me sliders for other settings too that have multiple options."

## What changed
- `game/scripts/top_down_camera.gd`: `shake_strength` (0..1, default 0.5)
  beside `shake()`; `_apply_shake` multiplies the offset by it. Nothing else
  in the file is touched (another 0.23 package edits x-ray and intro camera).
- `game/scripts/main.gd`: settings key `"shake"` in percent (default 50),
  `SHAKES` (0..100 by 10), `shake_percent()` (bad or missing value -> 50,
  like `fps_limit()`), applied in `apply_settings()`.
- `game/scripts/settings_screen.gd`: `_stepper` replaced by `_slider`
  (HSlider over value indices, step 1, a tick per value, name + value text
  on the line above, 56 px tall with a 40 px round handle, accent fill).
  `steppers` renamed `sliders`. Row metas: slider, value, values, key, refresh.
- Sliders now: Distance, Drive zoom-out, Angle, Camera turn, Screen shake
  (Camera); Quality, FPS limit (Graphics); Driving (Controls); Weather (Game).
  Two-state buttons stay: View, Look down near towers, Detail, the effect
  toggles, Show FPS, Log, BUG button.

## Decisions
- Default shake 50%: Sachin said "too much"; half the offset keeps crashes
  and explosions readable while clearly calmer. 100% equals the old shake.
- Screen shake lives in the Camera tab (it moves the view; the preview is
  there). Letting go of it shakes the preview once at the new strength.
- Reset camera does not reset shake or Camera turn (same as before for
  Camera turn; its hint names what it resets).
- Camera turn, Driving and Weather were cycle buttons with 3-4 choices;
  they became sliders too, since Sachin asked for sliders on every setting
  with multiple options. Order: Follow -> 90° turns -> North up (most turning
  to none); Stick, Arrows, Tilt; Auto, Clear, Rain, Storm.
- Value stored is the list value (not the index), so saves stay as before.

## Rejected
- Keeping - and + buttons beside the slider: halves the slider's width in
  the 500 px list; a tap on the track already jumps to a tick.
- A continuous 0-100 slider for shake: ticks every 10% match the brief and
  the other sliders.

## Traps
- HSlider jumps to the finger on press and takes the drag; with
  `MOUSE_FILTER_PASS` the ScrollContainer still sees it. `_drop_held` (on
  `scroll_started`) puts back the settings snapshot taken on `drag_started`
  and hides/shows the slider, which drops its grab (checked in a probe and
  in `test_settings_sliders_snap_and_apply`). `drag_started` fires before
  the first `value_changed`.
- Quality redraws the tab (its effect toggles). While a finger holds it the
  redraw waits for `drag_ended`, or the slider would be freed mid-drag.
- `tests/control_shots.gd` used `page.steppers`; updated to `sliders`.
