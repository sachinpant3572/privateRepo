# 0.25.2: touch controls (fix stick, floating arrows, previews, layout editor)

Sachin, 2026-10-29: "Fix the Stick + Pedals controls please. Also, instead
slider for controls, show them on the preview screens. Give an option like
arrow + pedals, but the arrow can be anywhere where the players touches
through his finger, not in the specified bottom left button. They have a
name for this setting, I dont know what it is called now. Show previews for
all these settings, and also allow the players to resize the buttons, or
change their placements." Then: "And also allow resetting the placement
back to original places".

## What was wrong with Stick + pedals (code reading, scripts/touch_controls.gd)

- The phone and settings pause the tree, and the touch layer stopped
  getting events, so a stick or pedal let go while they were open stayed
  held: the car drove on or the hero walked on after closing; the stick then
  stayed tied to the dead touch and jumped. No focus-out handling either.
- A new press on a reused touch index overwrote a held button without
  letting it go (GAS stuck on).
- A thumb sliding off a pedal onto empty screen kept the pedal pressed.
- With the camera turning behind the car (the default), the stick did gas,
  brake, reverse and steering at once from its angle (up = gas, past 110°
  brake/reverse with mirrored steering, full lock lifts gas), on top of
  GAS/BRAKE pedals: two ways to drive that fight, and steering alone crept
  the car forward.

## Decisions

- Stick + pedals: the stick is the wheel only (its sideways lean, small
  dead zone, smooth curve); GAS/BRAKE drive, as with a pad's left stick and
  triggers. W/S keep driving on a keyboard. North-up and step cameras keep
  the old "head where the stick points" (sideways lean means nothing there).
- New layout "Floating arrows + pedals" (scheme "float"): the arrows appear
  under the thumb wherever it lands on the stick's half of the screen;
  slide left or right of that point to steer, like the arrow buttons
  (digital). The common name is a floating (or dynamic) joystick; for
  left/right only, "floating steering".
- Pause-proof touches: the touch layer always processes; while paused it
  only takes releases. Focus-out, hiding and pausing the app let go of
  everything.
- Settings > Controls: four layout cards, each with a drawn preview of that
  layout, instead of the slider; the live preview on the right shows the
  chosen layout's controls over the game view.
- Layout editor (Settings > Controls > Edit layout): full screen over the
  game view, On foot / Driving; drag a control to move it, tap it and use
  - / + to resize (60%-160%); Reset puts that mode back; Done saves.
  Stored in settings "touch_layout" {id: {x, y, s}} (offsets from the
  control's corner, so they hold on wider screens). The stick's side of the
  screen follows where its home is (left-handed layouts work).

## Options (cost)

- Chosen: all of the above, about 3-4 h.
- Not now: opacity slider, per-button visibility, pinch-to-resize (the -/+
  buttons are easier to hit and test).

## Results (2026-10-29)

- Built as decided. New tests (all pass): test_floating_arrows_steer_where_
  the_thumb_lands, test_stick_is_the_wheel_only, test_touches_never_stick,
  test_touch_layout_moves_resizes_and_resets, test_settings_controls_cards_
  and_layout_editor. Updated: test_camera_turns_with_car (GAS/BRAKE drive,
  the stick only steers), the two settings-tab tests (no Driving slider).
- Shots (control_shots.tscn, 13): every layout incl. floating arrows held,
  the Controls tab cards + overlay, the editor (GAS moved, 130%), the game
  with the moved layout.

## Review fixes

- A thumb that slid off a pedal or arrow and comes back onto one (without
  lifting) presses it again (`_slid_off`); tested.
- The editor keeps controls below its 120 px bar (`top_margin`), which
  also keeps them off the HUD's top buttons; tested.
- The log copies the settings deeply, so layout edits show in device logs.
- Not added: a save-file round trip of touch_layout through save_game
  (the JSON round trip is tested).

## Traps

- _new_game sets camera_turn "north": a test of the turning-camera stick
  must set "car" itself (and put it back).
- The theme's default Button style barely shows over the editor's dark bar:
  its buttons get an explicit StyleBoxFlat.
- touch_controls.gd has no class_name: tests find previews by script.
- Background shot runs from agents may share /tmp/shots.log: use own names.
