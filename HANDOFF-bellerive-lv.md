# Bellerive at Las Venturas size, California + San Fierro + Florida

Sachin, 2026-10-29: "Make Bellerive the size of Las Venturas then, but with
California + San Fierro + Florida mix." (After being told Bellerive's city
is ~2.6 km² of land against San Fierro 3.2-3.6, Las Venturas 4.1-4.2,
Liberty City 8.06, Los Santos ~10-12.) This lifts the 2026-10-28 "keep the
planned size" rule for the city; #104 (organic outline) carries on inside it.

## Target

- City land (as test_city_outline_is_organic measures it: land inside the
  edge loops, sampled every 20 m) **4.1-4.3 km²**, from 2.62 km² now: about
  +1.6 km². Las Venturas: 4.1 km² of land in named districts, 4.2 km² engine
  box (reference/world/gta_san_andreas.md 1.2).
- The outline stays organic (fill < 0.8, no straight edge run > ~420 m).

## Geography (local metres = world - (6150, 6650))

- Now: core bbox (-300,-330)..(1660,1800); the Morrow River comes down the
  west side and crosses the city east-west at y ~1110-1220, then turns south
  to the Gulf at (1550, 2000). The Gulf coast is y 2000 in the south and
  runs diagonally (1450,2000)-(2250,1350)-(2750,650) in the east. The
  Bellerive Hills (terrain grid x 152..2232, y -1848..-408, peaks ~72 m) lie
  just north; their foothills are 0-15 m at y -600.
- Growth, three directions:
  - **North, San Fierro** (~0.35-0.45 km²): the edge moves from y ~-330 up to
    ~-700 between x ~0 and ~1300, onto the foothills. Painted Victorian rows
    (style "painted" exists), a Chinatown (new style), a cable car line from
    downtown up the hill, a hilltop park with a tower, a crooked street.
  - **East and south-east, Florida** (~0.8-0.9 km²): from x ~1460 out to the
    beach, taking in Brisa Beach (now country beach_town / eastside suburbs).
    Ocean Drive along the sand with Deco hotels, palms, lifeguard towers and
    condo towers; a Little Havana strip (calle with low pastel shops) behind.
  - **South bank to the Gulf** (~0.2-0.3 km²): Morrow Point grows down to the
    coast (y ~1960): a waterfront with piers (SF Embarcadero / FL marina).
- California stays the frame: the arterial grid and boulevards run on into
  the new districts, palms along them, strip malls on the arterials.
- The New Orleans Lantern Quarter, the DC civic centre and Manhattan Midtown
  stay (built, missions use them); the request adds a mix, it does not ask
  to remove them.

## Decided

- **SF district flat for now (2026-10-29).** Feasibility read (Explore):
  cars, people, camera, blood, debris and birds already follow
  Terrain.height and there is no ground collider, but the city builds its
  ground and streets from large flat primitives (city_cells.gd:214, 219,
  273, 284, 312, 323, 329; lots :173) with y = 0 throughout. Real slopes need
  an offline grading of the city street graph (like tools/mountain.py), a
  drape pass with subdivided ground and road pieces, building plinths, and
  lifted lenses and doors, plus Terrain.drop returning 0 inside the city
  (country.gd:438-470 would sink cars 0.26 m). Estimate 40-70 h for one
  0.5-0.8 km² district. Chosen: SF flavour on flat ground at the foot of the
  Bellerive Hills (painted rows, Chinatown, cable car, piers, hilltop view
  on the real hill behind), ~16-23 h for the whole growth. Real slopes are
  the bigger option for Sachin to switch to.

## Traps carried over from #104

- The trim's notch/spur rules: outline wiggles must be 2+ blocks to show.
- Country package (agent, worktree) is generic over the core: rerun its
  generator after the core changes.
- perf_probe on the trimmed city (2026-10-29): parked 123k triangles
  (shadow 84k), fast 145k (shadow 88k), against 104k / 114k in 0.25.2.
  To fix before the APK.
