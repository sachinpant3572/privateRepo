# Handoff: homes by wealth and land value

Sachin, 2026-10-28: "When you are creating the buildings in any region, I hope you are aware about the
surroundings, physics, economic worth of that region too. The buildings too need to be built
accordingly. We also need to build the houses for the corporate CEOs, owners, business owners,
builders, regular employees, and show different aspects of wealth. See how the richer the people get
the more bigger and private property they live in, whether it is private houses or apartments in high
rise buildings, and the less money the person has the closeby they live, either in small houses in a
specific region that is known to be poor, or in small apartments in cheap buildings. My purpose of
building this game is to let the players feel like they are in a living breathing accurate depiction
of different cities, regions, etc."

Same day he asked what it would cost to make Bellerive as big as GTA V's Los Santos (answered: 8-12
sessions). His decision: "Lets keep it the same as it is planned for now, lets not make it bigger, we
will introduce more things inside so the whole city feels much more lively than GTA V". So the city
keeps its planned size (the 4.7 km² outline in world_map.json), and every tier fits inside it.

## Starting state (survey, 2026-10-28)

- No land-value, wealth, rent or condition field anywhere. The district `faction` is loaded and never
  read. Storm damage in the Wards is random. No flood-zone data.
- City homes: Creole townhouses (Quarter), shotgun houses (Wards), barred bungalows, housing
  projects, SRO hotels, motels and tent rows (Wards and skid row), brownstone and painted-lady rows
  (Morrow Point). Towers are offices only: there is no residential tower and no penthouse.
- Country homes: house (14x14 ranch), mansion and estates (Heights, mountain), garden_apartments,
  condo_tower and deco_hotel (beach), rowhouse rows (fringe), capes (shore), trailers, shacks and
  stilt houses (bayou), farm homes.
- Value-like inputs: water and coast, the terrain grid (hills), the Beltway and rails, docks and
  industry (Ironwharf), parks (Liberty Green, lawns), and the district rects (distance downtown).
- NPCs have no home, job or income. Homes cannot be entered.

## Decisions (proposed)

- W-1 Land value V in 0..1 at any point: the district or zone base, plus water within about 300 m,
  height and view (terrain), and parks; minus the freeway, rails, docks and industry within about
  150 m, and low ground by the river or bayou (flood). Computed in the generator for the country and
  per block in the city; kept with each lot and block.
- W-2 Six tiers of household, chosen from V and the district (with some spread, so streets mix):
  - T5 owners and CEOs: gated estates (wall, gatehouse, long drive), or a penthouse on a residential
    tower.
  - T4 business owners and builders: an executive house (2 storeys, 3-car garage, pool, hedge), or a
    luxury condo tower.
  - T3 professionals and managers: suburban houses, townhouses, mid-rise condos.
  - T2 regular employees: tract houses, rowhouses, garden apartments, plain mid-rise rentals.
  - T1 low wage: shotgun houses, bungalows, cheap walk-ups, SROs, motels, trailer parks.
  - T0 poorest: housing projects, shacks, tent rows.
- W-3 Wealth shows in:
  - lot size and density (homes per hectare fall with each tier);
  - setback, and privacy: open lawn, then picket fence, hedge, wall, then a gate with a gatehouse;
  - cars: beaters, then sedans, then luxury;
  - upkeep: peeling paint, bars, boarded windows and yard junk at the bottom; manicured at the top;
  - pools, and roof decks on towers.
- W-4 Surroundings and physics: flood-prone homes stand on piers or stilts; hill homes on stepped
  pads facing the view; the coast gets storm shutters; tall towers only where the district allows
  (none in the historic Quarter).
- W-5 Checks:
  - the generator prints homes per tier per zone;
  - tests assert that mean land value and lot area rise with tier, and density falls;
  - every tier is present in Bellerive.

## Phases and rough cost (one session = one long sitting like today's)

1. Value field, tier assignment, and tier markers (fences, upkeep, cars) on the existing kinds:
   1-2 sessions.
2. New kinds:
   - a residential tower with a penthouse (crown, roof pool, doorman canopy, garage ramp);
   - mid-rise condos;
   - cheap mid-rise apartment blocks;
   - an executive house;
   - an estate gatehouse.
   2 sessions.
3. Placing them: Midtown and Gilt residential towers by the park and the river; Morrow Point
   mid-rises; cheap blocks in the Wards and by the docks; country tiers by V. 1 session.

Full plan: 4-5 sessions. Cheaper option: phase 1, plus only the residential tower and the cheap
block, for 2-3 sessions.

## Open questions

- Settled 2026-10-28: the city keeps its planned size.
- Enterable homes (safehouses) are planned in INTERIORS_SERVICES_PLAN.md and not in this scope.
