# Hill content: archived notes

## Phase 2 plan (life)

- Flora bands by height already exist (flora_kit `pick`: pine from 120 m,
  oaks thinning above 450 m, rock above 680 m); phase 2 adds wildflower
  meadows and ferns only.
- Packages (cost ~ each builder 1-2 h + an Opus review; the cheaper option
  is all in the main session, slower and serial):
  W wildlife (builder): scripts/wildlife.gd, kits/animal_kit.gd,
  tests/wildlife_tests.gd. C calendar + events (builder): scripts/calendar.gd,
  scripts/events.gd, tests/calendar_tests.gd. H hunting (after W; touches
  inventory, shop, hud, player): main session. Hikers/runners/hunters on
  trails (generator walks + population looks): main session.
- Test modules: test_runner.gd runs `TEST_MODULES` (each a script with
  `const TESTS` and `func test_x(t)`), so builders never edit test_runner.gd.

## Phase 1 plan (done)

1. **Places** (#122). Generator (main session): a `hill_places` step in
   build_country.py before `street_lots`, from a HILL_PLACES table (kind,
   x, y, id): frontage lots along the nearest way for the two villages, a
   trailer park cluster, single sites for the rest; the lab road and the
   timber haul as mountain_plan SPECS; Tallow Lake and Fernmoor Pond as
   level water with dug beds; streams as ribbons; walks in the villages so
   people spawn; mountain-zone diner/store/hunting store open as places.
   Kit (builder agent, owns scripts/kits/hill_kit.gd): research_lab,
   lab_gate, sawmill, cult_compound, ranger_post, logging_camp,
   mine_entrance, stone_ring, hot_spring, cold_spring, mountain_hotel,
   lodge_hotel, rave_clearing, bungee_platform, fairground, hunting_store.
   Reused kinds: diner, gas_station, general_store, motel, truck_stop, bar,
   house, garage, town_hall, trailer park (cluster style "trailers").
