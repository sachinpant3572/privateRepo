# World build: variation 2 city, 1000 m range, trains, summit (2026-10-29)

Sachin, 2026-10-29: "Lets continue with 2." / "Mountain should be raised to
1000mtrs, with several small mountains around it, and continuing mountain
line, seemlessly mering with the city and around it, just like we have in
San Andreas and GTA V." / "we have built a train line too, for regular travel
and for freightlines too this will cover every district, cover the mountain
(can build a tunnel or go around it) so scenic views can be seen, and will
cross it in between too. Build this too as best as possible." / underpasses
and tunnels: "No this wont be skipped. We will build everything."

Research behind it: reference/world/map_and_mountain_research.md.
#105 (Bellerive at LV size) folds into phase 1: its open test failures are
on the street plan that phase 1 rewrites.

## Phases (rough cost; order fixed by dependencies)

1. **City plan, variation 2 adjusted** (~30-42 h). Downtown grid kept;
   field-traced curves outside it; Wards, Ironwharf and docks keep a tight
   straight grid (class divide); rich districts (Cable Hill contour streets,
   Florida coast, river edge) curve, with variation 4's stronger pull along
   water; main-road crossings kept for malls; roundabouts where field
   arterials cross; A's Mirador and Canyon roads. Reserve the rail corridor
   (phase 4) in the plan. Then #105's tests, full suite.
2. **Mountain range** (~25-40 h). Calder massif ~1000 m, smaller peaks
   (400-750 m) around it, a ridge line running on east into Verdant Hills and
   west toward Cinder Ridge, foothills (50-300 m) starting at the city's north
   edge. Bigger terrain grid, roads re-graded (main road with switchbacks,
   forest trails, shortcuts), country regenerated.
3. **Grade separation** (~14-22 h). Bridge decks over roads and valleys,
   underpasses, tunnels (portals, see-through for the top-down camera),
   vehicles and people on deck heights. Trains reuse it.
4. **Trains** (~30-50 h). Passenger line through every district with
   stations; freight line to the docks, Ironwharf, Golden Flats and the
   quarry; across the range by a pass with tunnels, viaducts and a scenic
   shelf on the flank (grade <= 2.5 %). Ride as passenger; freight and
   passenger trains run on a timetable; level crossings in town.
5. **Far view** (~16-24 h). Low-detail whole-city and whole-terrain meshes,
   haze, lit windows at night; summit view mode; telescope that streams the
   real cells where it aims.
6. **Summit set** (~18-28 h). Cable car Cable Hill to summit (long, two stages
   with a mid-station), summit restaurant with terrace, helipad, deck,
   telescopes, off-road grip on trails.

Total ~135-205 h. Milestone APKs after phases 2, 4 and 6. Flying from the
helipad needs helicopters: task #82, not started (Sachin's word needed).

## Decided

- **1000 m geometry [M].** A 1000 m peak needs a base of ~2-3 km to the city
  (mean slope 35-45 %, like Chiliad's 798 m). Peak goes north into Red Pine
  (phase 3, unbuilt), around world (7100, 3900): ~2.2 km from the city's
  north edge (world y ~6080). From there the city lies 10-22 degrees below the
  horizon (near edge 2.2 km, far corners ~5 km). Today's Bellerive Hills
  (114 m) become the foothills and lower peaks.
- **Seam with the city:** foothills start at the city edge; the country layer
  (already terrain-following) carries hillside streets and homes up from the
  city's streets, Vinewood Hills style. The city itself stays flat
  (HANDOFF-bellerive-lv "SF district flat"). Sloped city districts are the
  bigger option (+40-70 h).
- Dellwood (phase 3 town at (6800, 3700), unbuilt) sits on the new massif:
  move it to the north foot.

## Open

- Golden Flats Expressway and phase 2 roads on the new west flank: re-route
  or pass; settle with the terrain sketch in phase 2.

## Traps

- Godot runs need `timeout`; gates per CLAUDE.md.
