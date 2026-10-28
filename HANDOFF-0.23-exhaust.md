# 0.23: exhaust smoke, tyre smoke and tyre marks

Sachin, 2026-10-28: "Also add Vehicle exhaust smoke depending upon the type
of vehicle, its size and current notions, and also tyre smoke when drifting
or braking, tyre marks when drifting and braking hard. All these factors
will be based on the type of vehicle, its size and category, current
pollution norms in US, speed etc."

## Where it lives

- `scripts/kits/vehicle_emissions.gd`: per-kind fuel, outlets (tailpipes,
  truck stacks), tyre width, twin tyres, mark tracks, smoker and old-diesel
  chances, pops, ABS; `roll()` per vehicle, raised by district poverty.
- `scripts/puffs.gd`: one MultiMesh of camera-facing soft quads (one draw
  call), pool `MAX 260` (lower on Low and Medium via `Fx.set_quality`), no
  puffs beyond `RANGE 70 + camera height` from the camera.
- `scripts/fx.gd`: `Fx.puff`, `Fx.tyre_mark` (dark strips in a MultiMesh;
  `_skid_alpha` mirrors the alpha because the headless renderer drops
  MultiMesh colours).
- `scripts/vehicle.gd` `_exhaust` and the tyre part of `_effects`.

## Decisions (US norms behind each)

- Healthy petrol cars (EPA Tier 3, catalyst): water vapour only, on a cold
  engine (`COLD_START`) or cool, damp air, and only at low speed.
- Diesel trucks since 2010 have particulate filters and run clean; CARB's
  Truck and Bus rule keeps most older ones off California roads. A small
  "old" share (farm exemptions, out-of-state rigs) puffs soot under load
  and on each upshift. Some pickups and vans are diesel.
- Worn engines ("smokers") give blue-grey oil smoke pulling away; chance
  per kind, up to 3x in poor districts. Tuk-tuks and cargo trikes are the
  likeliest.
- EVs, the e-moped and bicycles emit nothing. Sports, muscle, super cars
  and roadsters pop on the overrun.
- Tyres: FMVSS 126 puts ABS and stability control on every light vehicle
  since MY2012, so a hard stop leaves faint broken marks and no smoke.
  Motorbikes, trikes and bicycles have no ABS rule here: they lock up,
  mark dark and smoke. Drifts, handbrake and burnouts mark and smoke in
  proportion to slip speed and tyre load; twin rear tyres mark wide.
- Wet roads: no marks, no smoke.
- Night: puffs are unshaded, so they darken with night to 0.5, not to
  black (street and car lights catch smoke).

## Shots (`SHOTS=exhaust`, 7 shots)

- Shot at (1080, 0, 620) in the wards: low-rise and sunlit. Downtown
  streets at noon lie in tower shadow, where dark rubber does not show.
- Move the (hidden) player there first: the city streams round the player,
  otherwise the street is water.
- Aim the camera before driving: puffs beyond RANGE of the camera are
  never made. A fixed focus forces pitch >= 65 deg and no cutaway, so frame
  near the lane or the camera sits inside buildings.

## Traps

- Tests: free a car and wait 2 frames before the next phase (the freed car
  still marks for a frame). Pin `_emit.smoker = false` where the test
  expects vapour: a rolled smoker gives grey oil smoke.
