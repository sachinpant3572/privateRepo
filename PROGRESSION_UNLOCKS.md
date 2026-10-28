# Story unlocks: the city opens as Jules rises (2026-10-28)

Sachin, 2026-10-28: "I think the best place to introduce more things is with the story
progression, we can show that this is a new city, and the hero has come up to escape his part,
the other parts of the city are still being built. This way we can start with some activities,
and keep unlocking new showrooms, or activities as more story goes by and player explores other
places [...] think of it like how we expand a franchise from scratch [...] This will keep the
players hooked to play and explore new places and things continously." Then: "Or suggest anything
else that seems much better to you".

Labels: V = checked in this repo (file:line), *suggested* = a proposal. Costs are in sessions.
Activity names point to `ACTIVITY_IDEAS.md` (N-rows), `ACTIVITY_ROADMAP.md` (packages, R-n) and
`ACTIVITY_ATLAS.md` (city packs, CP-n). Reviewed once on 2026-10-28; its findings are fixed here.

## 1. Framing: keep the canon, get the same effect

The pitch as written clashes with the canon in three places (V):
- Bellerive is not new: French settlers founded it about 300 years ago (`WORLD_BIBLE.md:50`).
- Jules is not a stranger: they come home twelve years after the Great Storm to find their
  cousin Teo (`MVP_DESIGN.md:158-159`, `ACT1_MISSIONS.md:60`).
- Jules is written so "the name works for any gender" (`WORLD_BIBLE.md:216-217`), and "fixed
  character or customizable" is still open (`MVP_DESIGN.md:322`). This doc uses "they".

The canon already holds what the pitch needs (V):
- The Great Storm drowned half the city 12 years ago. Aurum rebuilt the rich half 10 years ago
  and left the Floodline Wards abandoned (`WORLD_BIBLE.md:32-34`, `:58-59`).
- Now the Solvera Line is being built, with "building sites across the map", and opening it is
  the story's spine (`WORLD_BIBLE.md:60`, `game/data/world_map.json:98`).
- Each city ships behind a story gate (`WORLD_V3_PLAN.md:355-357`).
- Jules left after the storm and became the best getaway driver in Porto Brisa
  (`WORLD_BIBLE.md:214-215`). That past comes due in expansion 1 (`WORLD_BIBLE.md:246-247`).

**Recommendation: "the Rebuild"**, with four unlock drivers:
1. **The city reopens.** The Wards still stand empty and the Line's building sites are
   everywhere. Venues and showrooms sit behind "Opening soon" hoardings and open at story beats,
   each with an opening day. Outside the city, roads and Solvera Line stations open region by
   region.
2. **Jules builds a franchise.** From the act 1 food stand (mission 7), Jules leases "For lease"
   lots in each new place and opens branches (section 3.3). A branch brings that place's
   activity, local reputation and washing room. This is the "expand a franchise from scratch"
   loop, played by the player.
3. **Jules buys back the Wards.** The Wards' hoardings are funded by the player, not the story:
   pay clean cash to reopen a block, and its venue opens (`ACTIVITY_IDEAS.md` N8, "Buy back the
   Wards"). The player rebuilds the home Aurum left to rot, and laundered money has a use.
4. **Exploring pays.** A region's venues appear on the map after the first visit, or after a
   phone tip. The first visit pays a small reward and fills the phone's "New in town" page.

*Suggested* canon touch for the "escape" part: Jules also comes home to get out of the
getaway-driver life. The bible already has that life (`:214-215`) and has it come due later
(`:246-247`), so this adds only a motive, not a beat.

Why this beats a brand-new city: the storm, the empty Wards and the Line's building sites
explain every closed door. The map stays open for free roam, which mission 1 unlocks
(`ACT1_MISSIONS.md:43`). Unlocks gate venues, showrooms and regions outside Bellerive, never
Bellerive's streets.

## 2. Pacing rules

- **Something new every 20-30 minutes** of play in act 1, and every 1-2 missions later.
- **Never more than two new things at once.** Anything more waits for a trigger (section 3.1's
  last column): a first visit, a phone tip a game day later, or a side mission. Each new thing
  arrives with a short intro: a phone call, a flyer or an opening-day event (ribbon, free first
  go, a crowd).
- **Always show what's next.** Two or three hoardings in sight say what's coming and what opens
  it ("Opens when the road west reopens", "Fund it: $X clean").
- **The basics are always on**: free roam, street races, random events and collectibles from
  the start, as act 1 already plans (`ACT1_MISSIONS.md:190`).
- **Every region keeps its own reason to visit**: its signature activity (atlas D3) opens on the
  first visit. If its build phase hasn't landed (flight school needs phase 3 aircraft), a
  hoarding stands there instead. Its city pack opens with that place's act.

## 3. Unlock ladder

### 3.1 Act 1, Bellerive

The "Unlocks" column of `ACT1_MISSIONS.md:41-55` is kept (V). The rest is *suggested*.

| After mission | Already in act 1 (V) | Adds (two at most) | Later, by trigger |
|---|---|---|---|
| Start | Street races, random events, collectibles | Food stalls and the diner (package 1); the corner store with arcade cabinets (package 11) | |
| 1 Homecoming | The map | Lantern Quarter bars and the Blue Lantern (package 10); the first hoardings | |
| 2 Empty Rooms | Phone | Phone media; photo mode (packages 13 and 7) | The read-only Bourse ticker, as a phone tip the next game day (`STOCK_MARKET_DESIGN.md` §11, item 4) |
| 3 Lantern Lights | Taxi side job | Pool and darts (package 21); clothing shops and barbers (package 8) | |
| 4 Wharf Rats | Courier side job | Ironwharf's paintball maze; the trampoline park | The shooting range (first visit to Ironwharf); the fixer's call when Jules first holds dirty cash (people route, section 4) |
| 5 Krewe Business | Airboat, Krewe rep | Airboat racing: a first course in Blackwater Bayou's channels, and the full Glades course in Saltgrass Parish, reached by airboat (atlas D3, E3); bayou fishing at the Stilt Hall dock (N4) | |
| 6 Gilded Invitation | Aurum rep | Bourse trading (stock doc §11, item 4); Gilt's bowling alley | The escape room and the yoga studio (package 28), on the first walk through Gilt |
| 7 Street Business | First business, safehouse, wardrobe | The franchise's first "For lease" lot (section 3.3); the fronts laundering route (section 4) | The first "Fund it" hoarding in the Wards (driver 3) |
| 8 Hoops | Streetball league, boxing | The gym and fight styles (package 17) | The Wards' batting cage, once its block is bought back |
| 9 Floodwater | First half of the ledger | The Old Streetcar Depot reopens as a gaming café (packages 11-12); the travelling fair on Liberty Green from its next season (package 32) | |
| 10 Magnolia | Second half of the ledger | Magnolia Heights' tennis club; the road east to Verdant Hills, with balloon rides on the first visit (CP-1) | The cat café (first visit to Magnolia Heights) |
| 11 Crescent Bridge | Captain Reyes | The road west over the Crescent Bridge: Saltgrass Parish by car (Route 1), and Golden Flats north of it | The tractor pull and pie contest when the fair tours Golden Flats (CP-1); a flight-school hoarding at the crop-duster strip |
| 12 Cargo | Teo rescued | Brisa Beach's year-round fun pier (package 32) | |
| 13 Two Crowns | Act 2 opening | The first showroom, used cars (section 3.3; N19's car salesman); the gang laundering route for the path chosen | |

### 3.2 Later acts (spine from `WORLD_BIBLE.md:239-250`)

| Opens with | Places | Opens there (*suggested*) |
|---|---|---|
| Act 2, the money route | Concordia, Sovereign County, the Keys | CP-3 and the Keys half of CP-2 (cheaper version, atlas D5); the luxury showroom in Concordia; the Keys marina's boat dealer; company laundering (section 4); the Exchange broker office (stock doc §11, item 6) |
| Act 2 side roads (road crews finish, build phase 3) | Hollow Mesa, Cinder County, Miravel Shores, Red Pine | One place every 1-2 missions, each with its signature: land-sailing and the Sable Junction rodeo; parachute jumps from Cinder Peak (package 31) and kalaripayattu from the hermit master; the lake triathlon (package 29) and wakeboarding; lumberjack games. The flight school opens at the Golden Flats strip and the Ironwharf Seaplane Base (package 30) |
| Act 3, the line | Las Brasas, Fort Granite | CP-2's Las Brasas half (Muay Thai, desert golf, glow bowling); jumps from the Solvera Line bridges; the exotic showroom; the Velvet Aces' route, taken over or shut down |
| Steelhaven strand | Steelhaven, Corran | CP-4; the muscle-car showroom |
| Act 4, the vault | Isla Serena | The finale's island venues (not yet designed) |
| Expansions 1 and 2 | Porto Brisa, the California city | CP-5, CP-6 |

Each new place opens with the same beat: arrival, the signature activity, two hoardings and a
"For lease" lot for the next franchise branch.

### 3.3 Franchise branches and showrooms (*suggested*, new row N27)

- **Lease lots.** Every place from act 1 on has one or two "For lease" lots behind a hoarding.
  Leasing is a big legal buy (section 4). A branch takes one game day to fit out, then holds its
  opening day.
- **Branch types**, each with its reward:

  | Branch | Opens in that place | Also |
  |---|---|---|
  | Gym | The place's fight style or fitness master (Muay Thai in Las Brasas, judo in Concordia) | Stamina training |
  | Garage and showroom | Repairs, tuning, and the place's showroom stock at a discount | Vehicle storage |
  | Café | The place's food minigame and a save point | Local tips on the phone |
  | Club front | Music or dance nights (E2) | The biggest wash allowance |

  Every branch also adds local reputation and a daily wash allowance for the fronts route
  (section 4).
- **What a branch does not add: income.** All business takings stay under
  `biz_cap_w_per_day`, 0.35 W per game day (stock doc §6.6, sim check 8). Washing turns dirty
  cash into clean but creates no money, so it sits outside that cap. The franchise pays in
  access, reputation and washing room, which keeps the economy safe.
- **Showrooms**, one catalogue per place, using the game's own cars (no real brands). Each has
  two or three models found nowhere else, so every opening gives something new to drive:

  | Showroom | Opens | Stock |
  |---|---|---|
  | Used cars (N19's lot) | Mission 13 | Cheap runabouts, taxis, vans |
  | Luxury | Act 2, Concordia | Saloons, coupés, limousines |
  | Boats | Act 2, the Keys marina | Speedboats, a cabin cruiser |
  | Aircraft | With the flight-school licence (package 30) | The light plane, seaplane, helicopter |
  | Exotic | Act 3, Las Brasas | Supercars, desert buggies |
  | Muscle | Steelhaven strand | Muscle cars, hot rods |

  Buying, a test drive, and colour and trim choice. Stealing from showrooms stays with
  `TODO.md:84`.
- **Cost (N27): about 2 sessions**: lots, branch types, fit-out and rewards 1; catalogues, the
  buy and test-drive screens 1. Cheaper: 1 session, with branches only and showrooms as a
  phone catalogue.

## 4. Money laundering (Sachin: "Use multiple ways of money laundering, either through corporates or individuals or gangs, this will progress with the story")

Today there is one cash pool (`game/scripts/main.gd:38`, V). The *suggested* design:
- **Two balances.** Dirty cash comes from crime (robberies, heists, street-business raids,
  sabotage jobs). Clean cash comes from missions' legal pay, side jobs, business takings and
  share sales. The HUD shows one total, with the split on tap.
- **Spending.** Everyday buys (food, clothes, ammo, repairs, taxis, venue fees, private sales
  on the R-13 marketplace) take either, dirty first, so mobile players never juggle.
  **Big legal buys need clean cash**: property, lease lots, branches, showroom vehicles (the N19
  used lot included), boats and aircraft from dealers, school fees (flight, sailing, diving),
  Wards blocks (driver 3) and Bourse shares (stock doc §11, item 11).
- **Selling.** Stolen goods, and anything any dirty cash paid for, sell for dirty cash. Items
  bought with clean cash sell for clean. Every owned vehicle and property carries this flag, so
  buying and reselling never washes money.
- **Routes**, each opened by the story:

| Route | Opens | How it works | Cut, limit, risk |
|---|---|---|---|
| People: a fixer and a bookkeeper | The first dirty cash, by mission 4 | Hand over a bag; clean cash the next game day | 30%; a small daily cap; no risk |
| Your own fronts (the franchise) | Mission 7, more with each branch | Each business washes up to its wash allowance per game day; an auto-wash switch does it daily | 10%; the allowance is a hard cap, anything over it is refused |
| Gangs, one side | Mission 13, the side chosen | The Krewe moves it through the bayou, or Aurum's people through Gilt | 20%; big batches, a 1-day wait; costs rep with the other side |
| Gangs, both sides | Mission 13, if Jules plays both | Half-size batches through each side | 25%; each batch may be noticed by the other side (a rep hit) |
| Companies | Act 2 (Concordia and the Keys) | Shell companies and Keys accounts | 5-8%; large batches, a 3-day wait; a batch over the size limit draws an audit (a fine and an investigation mission) |
| The Velvet Aces' route | Act 3 | A hotel and lounge front (no casino games, `GANGSTAR_CONCEPT.md:101`) to take over or shut down | Story-set |

- **No loops.** Every route costs more than nothing. Nothing turns clean cash into dirty at a
  profit. The Bourse takes only clean cash. Washed cash never counts as business takings, so it
  never raises the business cap or the next day's allowance.
- **No reload dodges.** Audit and "noticed" rolls, and batches still waiting, follow the stock
  doc's §6.5 rules 1-3: nothing rerolls on load, the result is saved before it is shown, and
  the seed is fresh on load. Waits count game days on `market.clock` (§6.6), not the hour shown.
- **A light sink on purpose.** Because everyday buys spend dirty cash first, many players pay a
  cut only for big buys. On mobile that is right: laundering is a choice for players who want
  the big things, never a chore. The real sinks are the big legal buys themselves.
- **Cost**: `ACTIVITY_IDEAS.md` N20, 2.5 sessions, its tests included (section 5).

## 5. Build plan (N26, with N20 and N27 beside it)

- **Data**: `game/data/unlocks.json`. Each entry has an id, a kind (venue, activity, region,
  showroom, route, lease lot, Wards block), a place and its requirements (a mission passed, an
  act, a region visited, a reputation level, a price paid). It also says whether it shows a
  hoarding first, and its teaser text.
- **Code**: a `game/scripts/unlocks.gd` autoload with `is_open(id)`, `on_mission_pass(id)`,
  `on_region_entered(id)`, `newly_opened()` and an `opened(id)` signal.
  - Hooks (V, current code): `game/scripts/missions/mission_manager.gd` `_pass()` (line 150)
    calls it.
  - `interiors.gd` `lock_reason()` (line 99) adds "Opening soon".
  - `places.gd` places a hoarding prop at closed spots.
  - The phone gets a "New in town" page, shown the way `hud.gd:181` gates the phone today.
  - `city.gd:719-750` keeps filtering by build phase; story gates are a separate layer.
- **Save**: one bump to `SAVE_VERSION` 3, shared with the stock market's planned bump. It adds:
  - `unlocks` (opened, seen, visited, funded), rebuilt from `done` on load, so an old save gets
    everything its missions earned (N26);
  - `cash_dirty` and `cash_clean`; a v2 save's `cash` loads as clean (N20);
  - the dirty/clean flag on owned vehicles and property, waiting batches with their due game
    day, today's washing per route, and committed rolls (N20);
  - `branches`: lot, type and opening day (N27).
- **Tests** (`game/tests/run.sh`):
  - N26: passing a mission opens its venues; a v2 save loads with the right unlocks; a closed
    venue refuses entry with its reason; a first visit is counted once.
  - N20: a v2 save's cash loads as clean; every cut is above zero; dirty cash can't buy shares
    or big legal buys; a dirty-bought car sells for dirty cash; the fronts cap refuses extra;
    a reload doesn't change a committed roll or a waiting batch.
  - N27: a branch adds its allowance and reputation, never takings above the cap.
- **Cost (N26): about 2 sessions**: registry, save, hooks and tests 1; hoardings, opening-day
  events and the phone page 1. Cheaper: 1 session with the registry, the lock check and a plain
  phone list, but no hoardings and no opening days. That loses most of the "city being built"
  feel, so the full 2 is recommended.

## 6. Open points for Sachin

1. **Canon touch**: should Jules also be running from the Porto Brisa getaway life (section 1)?
   Recommended: yes. The bible already has that life (`WORLD_BIBLE.md:214-215`); this only
   makes it a motive, and it is the "escape" part of the pitch.
2. **Hero**: stay with the gender-neutral Jules (`WORLD_BIBLE.md:216-217`, `MVP_DESIGN.md:322`),
   or fix the hero as a man, since the pitch says "his"?
3. **Act and build order** (inference from `WORLD_V3_PLAN.md:346-353` and `WORLD_BIBLE.md:239-250`):
   with the phase 3 places opening as act 2 side roads (section 3.2), phase 3 fits act 2. The
   clash left is that act 2 needs Concordia (phase 5) and the Keys (phase 4), while act 3's Las
   Brasas is also phase 4. Either build Concordia before Las Brasas, or swap acts 2 and 3.
   Recommended: build the Keys and Concordia first, since the ledger story leads there.
4. **Districts**: the recommendation gates venues and regions only, never Bellerive's streets.
   Fence off districts too, the GTA III way? Recommended: no; free roam is the hook from
   mission 1.
