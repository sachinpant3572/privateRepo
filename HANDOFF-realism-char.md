# HANDOFF: realism pass, CHAR package (hero and NPC models, animation, perception)

Sachin, 2026-10-28: "Also, improve the hero model, improve the NPC models too." "Also, improve the
Hero animations, and also the NPC animations. Build common NPC animations for every category of
people, and then these animation will keep getting repeated by them, depending upon the situation
they see, hear or are in. Think of all situations they can be, and then build animations and
mecahnics behind to handle them accordingly at exact moments." "Test verify everything thoroughly."

Owned files: character_kit.gd, rig.gd, humanoid.gd, npc.gd, pedestrian.gd, patron.gd, cop.gd,
player.gd (animation calls only), new senses.gd, tests in test_runner.gd, tests/char_shots.*.

## Decisions

- Perception is one static script (`scripts/senses.gd`), not an autoload: no project.godot edit.
  `Senses.emit(tree, kind, pos, source, data)` walks the "perceivers" group once (distance check,
  then hearing radius or a 65° sight cone, 3 m all-round awareness). No raycasts. Peds also run a
  staggered scan every 0.35-0.5 s for things that are states rather than events (a car coming at
  them, a car on their sidewalk, the wanted player, a body, the player sprinting past, a siren).
- Reaction choice is a pure function `Senses.choose(category, personality, kind, near)`, so the
  tests can check every category x situation. Timing is `Senses.delay(...)`: base by event (loud is
  fast) + distance / 343 m/s + personality and elderly offsets, clamped to 0.15-0.6 s; the
  reaction is queued with an at-time on the physics clock and starts on that tick.
- Categories (new look key `category`): office, worker, tourist, gang, elderly, athlete,
  shopkeeper, medic, cop, general. Personality: brave, timid, curious, calm.
- Witness calls (`call`) report a crime only when the event was a player crime (`data.crime`) and
  the player is not wanted yet, so evasion and mission fights are untouched.
- Get-up plays inside the last GETUP_TIME of a knockdown, so knockdown lengths (and the tests that
  time them) do not change.
- Idle acts (phone call, smoke, lean, hail, chat) wait 18-45 s after spawn so the sidewalk-prop
  test's walkers are not held up.
- Grounding: for upright poses the hip height comes from the leg angles (the lower foot touches the
  ground), so crouches, kneels, cowers and the walk's double-support dip are physical.
- Hooks outside owned files: `fx.gd` crash() and knock() emit "crash" (one line each). No guns,
  horns or explosions exist yet; those kinds are API-ready and covered by tests through emit().

## Rejected

- Per-NPC raycasts for sight: cost on Android; the cone plus radius reads right from above.
- An autoload for perception: needs project.godot, which another package may touch.

## Open questions

## Traps

- `godot -s script.gd` cannot compile player.gd (autoloads absent): inline looks in scratch scripts.
- test_people_walk_past_sidewalk_props builds peds on a fake city with only `sidewalk_loops`:
  every scan must tolerate missing city fields and no player.
