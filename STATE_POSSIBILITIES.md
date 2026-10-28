# Solvera: what each place could hold

A planning list to go with the rough relief sketch, `docs/state_sketch.png` (half-size copy:
`docs/state_sketch_small.png`). Neither is game code. The sketch's heights are invented: each listed
peak elevation is multiplied by 0.2, so Cinder Peak's 2,140 m becomes 428 m, and the shading uses 3x
vertical exaggeration. Mesas and dry lakes are placed for the sketch only. To regenerate it:

    python3 game/tools/state_relief.py docs/state_sketch.png --small docs/state_sketch_small.png
    # add --grid to also write the height grid (docs/state_sketch.png.npy, 10 m cells)

Each section gives the terrain in one line, then what is already planned (with its source), then
"could hold later". An idea taken from the docs carries its source; an idea that is my own suggestion
is marked **(new idea)**. Sources: WV3 = WORLD_V3_PLAN.md, ATL = ACTIVITY_ATLAS.md, RM =
ACTIVITY_ROADMAP.md, BIB = WORLD_BIBLE.md, IDEAS = ACTIVITY_IDEAS.md. Phases are the ones in WV3 §7.

Ground rules carried over from the docs: no hunting (RM §1.1 and IDEAS N25 replace it with the
wildlife photography challenge); no real casinos or betting, no drug jobs, no religion and no
pay-to-win (IDEAS §6); no real-world brands.

## Regions

### Hollow Mesa County (desert, phase 3)
Terrain: high, dry plateau (50-120 m on the sketch) with scattered mesas, two dry lakes and Sable Butte.
- Planned: Sable Junction rodeo, land-sailing on the dry lakes, stargazing at Mesa Arch and
  tow-truck runs (ATL D2/D3); ghost towns Bottle Flats and Dust Hollow, the Old Salt Mine,
  the Skyward Fellowship camp and the Starlite Motel (WV3 §3); the Solvera Line through Ridge Tunnel.
- Could hold later:
  - Off-road desert rally across the dry lakes and between the mesas (ATL Part B, desert).
  - Ghost-town scavenger hunts and a Dust Hollow "story" mission chain (BIB Countryside).
  - Freight-train heist on the Solvera Line in the cut by Ridge Tunnel, using the R-23 heist kit **(new idea)**.
  - Rock-climbing routes up the mesa walls, sharing the R-31 climbing gear **(new idea)**.
  - Old Salt Mine as a hideout or a mine-cart chase **(new idea)**.
  - Night-sky photography spots for the wildlife and photo challenge (IDEAS N25) **(new idea)**.

### Fort Granite Reservation (military, phase 3)
Terrain: a flat basin at about 60 m, with the airfield and the Granite Dry Lake test range.
- Planned: Fort Granite Airfield with jets, and the Vault under Fort Granite as a legend
  (WV3 §3; BIB Legends); fenced-off restricted area.
- Could hold later:
  - The Vault break-in as the state's largest R-23 heist, ending the Vault legend **(new idea)**.
  - Stealing a jet from the airfield (WV3 §3 plans the jets; the theft is a **new idea**).
  - Test-range driving trials in prototype vehicles **(new idea)**.
  - Extend the planned trespass wanted level (WV3 §3, §4) to airspace over the base **(new idea)**.

### Cinder County (mountains, phase 3)
Terrain: the state's high ground, with Cinder Peak (428 m on the sketch), Widow's Tooth (392) and
Granite Dome (374), steep valleys, and the Morrow and Cinder rivers rising here.
- Planned: R-31 parachute jumps from Cinder Peak; the Granite Dome crag; a hill climb up the
  observatory switchbacks; mountain biking; base jumping; the kalaripayattu hermit (ATL D2/D3);
  Cinder Peak Observatory, Cinder Peak Radar, Silverbell ghost town and mine, Pinecrest heli tours,
  and the Silver Train legend (WV3 §3; BIB Legends).
- Could hold later:
  - Hang gliding and wingsuit lines from Cinder Peak down towards Miravel **(new idea)**.
  - A Silverbell Mine expedition that finds the Silver Train (BIB Legends; the mission form is a **new idea**).
  - Mountain-pass rally and a winter "chains on" delivery over Cinder Pass **(new idea)**.
  - A Cinder Peak Radar sabotage or rescue mission **(new idea)**.

### Miravel Shores (lakeside, phase 3)
Terrain: Lake Miravel behind Granite Gorge Dam (lake level about 88 m on the sketch), with wooded slopes.
- Planned: R-29 lake triathlon; wakeboarding; the Drowned Village dive; the dam tour guide job;
  Harlow Marina boat rentals; Miravel Pines campground (ATL D2/D3; RM R-26, R-29; BIB Legends).
- Could hold later:
  - Bungee jump off Granite Gorge Dam **(new idea)**.
  - Whitewater rafting on the Cinder River below the dam, down towards Ember Canyon **(new idea)**.
  - A dam-sabotage threat mission, defended by the player rather than carried out **(new idea)**.
  - Lake fishing tournament (fishing is planned in ATL A3; the tournament is a **new idea**).
  - Seaplane rides from Harlow, sharing the Ironwharf seaplane code **(new idea)**.

### Red Pine County (forest, phase 3)
Terrain: rolling forest at about 60-110 m, cut by the Morrow River and Pine Creek.
- Planned: lumberjack games, a logging-road rally, canoeing, wildlife photography from the fire
  lookout, and a roller rink in Dellwood (ATL D2/D3); the Greenhold commune, the Dellwood sawmill
  ruin, Red Pine campground and Fernmoor village (WV3 §3).
- Could hold later:
  - Forest-fire response: fire truck and water-bomber plane missions from the lookout **(new idea)**.
  - Zip lines and a treetop course near the campground **(new idea)**.
  - Pine Creek ford as a shortcut for off-road chases (the ford is already in world_map.json).
  - Horse trail rides, with no betting **(new idea)**.
  - A ghost-story night at the sawmill ruin (BIB Countryside tone) **(new idea)**.

### Golden Flats County (farmland, phase 2)
Terrain: almost flat (about 10-20 m), crossed by the Morrow and Cinder rivers, with Ember Canyon at its west edge.
- Planned: R-30 flight school at the crop-duster strip; a crop-duster air race; a tractor pull;
  the R-32 county fair; a drive-in (ATL D2/D3; RM R-30, R-32); Wheaton, the Ridley Crossing truck
  stop, Hollis Farm and the grain elevators (WV3 §3).
- Could hold later:
  - Truck-driving and haulage jobs from Ridley Crossing (ATL D2 shift jobs).
  - A corn maze with a timed run and a hidden collectible **(new idea)**.
  - Harvest jobs: combine driving and grain runs to the elevators **(new idea)**.
  - Storm chasing across the flats (planned for Corran in ATL D3; a farmland version is a **new idea**).
  - Hot-air balloon launches, shared with Verdant Hills **(new idea)**.

### Saltgrass Parish (bayou, phase 2)
Terrain: sea-level swamp (0-3 m) laced with Black Bayou, Turtle Slough and the river mouths.
- Planned: airboat racing; Glades Airboat Tours; the gator farm; the moonshine still; Cypress Bend
  and Gator Point villages (ATL A2, D2/D3; WV3 §3).
- Could hold later:
  - A swamp boat chase through the bridges on the Cinder and Morrow mouths **(new idea)**.
  - Wildlife photography of the gators and birds (IDEAS N25).
  - A bayou smuggling route linked to the Keys speedboat runs (ATL A4 Bellerive) **(new idea)**.

### Verdant Hills (hills, phase 2)
Terrain: gentle hills (about 30-75 m) with Bluegill Lake, vineyards and the state's main airport.
- Planned: hot-air balloons, Old Post Road cycling, Bluegill Lake fishing, archery and a grape
  stomp at the Larkspur Estate vineyard (ATL D2/D3); Bellerive International and the Aurum Cargo
  Hangar (WV3 §3).
- Could hold later:
  - Villa party heists in the hill estates, using the R-23 heist kit **(new idea)**.
  - Airport cargo theft from the Aurum Cargo Hangar (a story site already) **(new idea)**.
  - Horse riding and a show-jumping course, with no betting **(new idea)**.

### Bellerive Hills (low ridge, phase 1)
Terrain: a low ridge behind Bellerive (Calder Peak, listed 114 m, about 23 m on the sketch).
- Planned: Crest Drive and the Canyon Freeway (game/README.md; HANDOFF-roads-mountain.md); the Lumen
  Observatory and the Hillside Letters (world_map.json landmarks).
- Could hold later:
  - A night time trial along Crest Drive with the city lights below **(new idea)**.
  - Mountain-bike downhill from Calder Peak to the city edge **(new idea)**.
  - A Hillside Letters stunt jump or photo spot **(new idea)**.

### Sovereign County (parkland, phase 5 in WV3; phase 4 in world_map.json)
Terrain: low parkland (about 15-45 m) around Sovereign Bay, with Signal Hill (62 m on the sketch) and Haverly.
- Planned: sailing school and yacht racing, Haverly golf, fencing and the Signal Hill time trial
  (ATL D2/D3); Sovereign International and Capital Downtown airports (WV3 §3).
- Could hold later:
  - The Sovereign Bay regatta as a season finale (ATL D3 places a regatta in the Keys; a bay version is a **new idea**).
  - Polo-style horse riding at Haverly, with no betting **(new idea)**.

### Corran County (rust belt, phase 6 in WV3; phase 4 in world_map.json), with Heron Isle
Terrain: low, flat (about 15-30 m) lakeshore along Lake Corran, with the Headlands to the north-east.
- Planned: the lighthouse trail, storm chasing, ice racing, the Shore Road time trial and laser tag
  in the Port Ash cannery (ATL D2/D3); Naval Air Station Headlands, Camp Corran, the Headlands
  lighthouse, Port Ash ghost port, and the Heron Isle park (WV3 §2.2, §3).
- Could hold later:
  - Jet and helicopter theft at NAS Headlands (WV3 §3 plans the aircraft; the theft is a **new idea**).
  - Ice fishing and a frozen-lake drift course in winter (ice racing is planned; fishing on it is a **new idea**).
  - A sunken-freighter dive off Port Ash, and smuggling drops on the lake **(new idea)**.
  - Heron Isle birdwatching for the photo challenge (IDEAS N25) **(new idea)**.

### The Keys and Isla Serena (islands, phase 4)
Terrain: low islands (0-5 m) strung across the Gulf: Pelican Key, Middle Keys, Serena Keys, then Isla Serena.
- Planned: fish-tagging dives, snorkelling, sea fishing, a speedboat race, silat and the regatta
  (ATL A2, D2/D3); Coast Guard Station Pelican Key, the Keys Fuel Dock, Serena Grand Resort,
  Isla Serena Airstrip and Smugglers' Cove (WV3 §3).
- Could hold later:
  - Coast Guard boat theft, and a smuggler-versus-patrol chase out of Smugglers' Cove **(new idea)**.
  - Deep-sea fishing charter beyond Isla Serena **(new idea)**.
  - Island-hop seaplane deliveries from the airstrip **(new idea)**.
  - A Keys treasure dive tied to the Sunken Casino legend (BIB Legends; the dive is a **new idea**).

## Cities

### Bellerive (Gulf city, phase 1, playable)
Terrain: flat coastal plain at sea level (the sketch has no region polygon for it, so it is drawn as plain).
- Planned: Act 1; the Brisa Beach fun pier (R-32); the second-line march and jazz; Keys speedboat
  runs; a hurricane evacuation; the Drowned Streetcar legend; R-31 jumps from the Aurum Tower
  (WV3 §2.4; ATL A4; RM R-31, R-32; BIB Legends).
- Could hold later:
  - Seaplane tours from Ironwharf Seaplane Base **(new idea)**.
  - Cruise-terminal smuggling jobs **(new idea)**.
  - Rooftop free-running routes through the Lantern Quarter **(new idea)**.

### Las Brasas (neon desert city, phase 4)
Terrain: flat desert floor (about 60-80 m on the sketch) inside Hollow Mesa County.
- Planned: Ember Heights golf; the Skyhook airship; the Sign Yard; the Flood Tunnels; an airship heist
  over the canyon; the Dust Riders gun run; the Fellowship pilgrimage (WV3 §2.3; ATL A4). The resort
  casinos are scenery only: no betting (IDEAS §6).
- Could hold later:
  - A flood-tunnel chase in a flash flood **(new idea)**.
  - Stunt shows and a car-jump arena on the edge of town **(new idea)**.

### Concordia (capital, phase 5)
Terrain: low parkland city on Sovereign Bay.
- Planned: cable cars and the gripman job; the Exchange; the State Museums heist; the Crimson Gate
  Bridge; R-31 jumps from the Solvera Line bridges (WV3 §2.1; ATL A4; RM R-23, R-31).
- Could hold later:
  - A Crimson Gate Bridge base jump **(new idea)**.
  - Motorcade escort and protection jobs around the Capitol **(new idea)**.
  - Bay ferry races between the Ferry Building and Haverly **(new idea)**.

### Steelhaven (motor city, phase 6)
Terrain: flat lakeshore city in Corran County.
- Planned: drag racing; ice hockey; scrap runs; the Polka Dot Block; a Loop chase; Narrows contraband
  over the toll bridge (WV3 §2.2; ATL A4).
- Could hold later:
  - Restoring the Old Ostrander Plant as a player-owned workshop **(new idea)**.
  - Abandoned-airport street racing at Steelhaven City Airport (already closed in world_map.json) **(new idea)**.
  - Union-hall strike and protest storylines at Local 12 **(new idea)**.

## Suggested order

Follow WV3 §7. Phase 2 opens the near countryside (Golden Flats, Saltgrass and Verdant Hills), and
its cheapest wins are the flight school, airboats, balloons and the fair. Phase 3 is the big terrain
phase: Hollow Mesa, Cinder, Miravel, Red Pine and Fort Granite. Build the shared outdoor kit here
(climbing, parachutes, boats, photo mode), because most later ideas reuse it. Phase 4 brings Las
Brasas and the Keys, with the Vault and airship heists as headline jobs. Phase 5 is Concordia and
Sovereign; phase 6 is Steelhaven and Corran. world_map.json gives Corran and Sovereign phase 4, but
WV3 §7 and ATL A3/D2 give 6 and 5, so the data should change to match before either is built.
