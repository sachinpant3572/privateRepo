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
`ACTIVITY_ATLAS.md` (city packs, CP-n). Reviewed twice on 2026-10-28; both rounds of findings
are fixed here.

## 1. Framing: keep the canon, get the same effect

The pitch as written clashes with the canon in three places (V):
- Bellerive is not new: French settlers founded it about 300 years ago (`WORLD_BIBLE.md:50`).
- Jules is not a stranger: they come home twelve years after the Great Storm to find their
  cousin Teo (`MVP_DESIGN.md:158-159`, `ACT1_MISSIONS.md:60`).
- Jules is written so "the name works for any gender" (`WORLD_BIBLE.md:216-217`), and "fixed
  character or customizable" is still open (`MVP_DESIGN.md:322`). This doc uses "they".

The canon already holds what the pitch needs (V):
- The Great Storm drowned half the city 12 years ago, and the Floodline Wards were abandoned for
  years. Ten years ago Aurum "rebuilt" Bellerive, buying flooded land for almost nothing
  (`WORLD_BIBLE.md:32-34`, `:58-59`). Wards families live there again today, with High Water
  fighting to keep their homes (`WORLD_BIBLE.md:77`, `:190`).
- Now the Solvera Line is being built, with "building sites across the map", and opening it is
  the story's spine (`WORLD_BIBLE.md:60`, `game/data/world_map.json:98`).
- Each city ships behind a story gate (`WORLD_V3_PLAN.md:355-357`).
- Jules left after the storm and became the best getaway driver in Porto Brisa
  (`WORLD_BIBLE.md:214-215`). That past comes due in expansion 1 (`WORLD_BIBLE.md:246-247`).

**Recommendation: "the Rebuild"**, with four unlock drivers:
1. **The city reopens.** Storm-damaged blocks in the Wards stand boarded up beside the
   families who stayed, and the Line's building sites are everywhere. Venues and showrooms sit behind "Opening soon" hoardings and open at story beats,
   each with an opening day. Outside the city, roads and Solvera Line stations open region by
   region.
2. **Jules builds a franchise.** From the act 1 food stand (mission 7), Jules leases "For lease"
   lots in each new place and opens branches (section 3.3). A branch brings that place's
   activity, local reputation and washing room. This is the "expand a franchise from scratch"
   loop, played by the player.
3. **Jules buys back the Wards.** N8's loop (`ACTIVITY_IDEAS.md:285-288`, V): buy
   storm-damaged houses with clean cash, renovate them, then rent them to Wards families (High
   Water reputation) or flip them. Rent and flip profits count as business takings, under the
   cap (section 3.3). *Suggested* addition to N8: a renovated corner lot can hold a venue (the
   batting cage, laser tag), and its hoarding reads "Buy and renovate". The player rebuilds the
   home Aurum bought up cheap, and laundered money has a use.
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
- **Never more than two new things at once** on top of the mission's own unlocks
  (`ACT1_MISSIONS.md`'s column). Anything more waits for a trigger (section 3.1's last column):
  a phone tip a game day later, a first visit away from the mission's own ground, or a side
  mission. Each new thing
  arrives with a short intro: a phone call, a flyer or an opening-day event (ribbon, free first
  go, a crowd).
- **Always show what's next.** Two or three hoardings in sight say what's coming and what opens
  it ("Opens when the road west reopens", "Buy and renovate: $X clean").
- **The basics are always on**: free roam, street races, random events and collectibles from
  the start, as act 1 already plans (`ACT1_MISSIONS.md:190`).
- **Every region outside Bellerive keeps its own reason to visit**: its signature activity
  (atlas D3) opens on the first visit, and its city pack opens with that place's act. Inside
  Bellerive the streets are never gated, so a district's venue (Brisa Beach's pier) opens with
  its mission and shows a hoarding until then.

## 3. Unlock ladder

### 3.1 Act 1, Bellerive

The "Unlocks" column of `ACT1_MISSIONS.md:41-55` is kept (V). The rest is *suggested*. Venues
marked (u) are on `ACTIVITY_IDEAS.md`'s "not costed yet" list (atlas D4 homes); until they are
costed, their slot can hold a costed stand-in from the same row.

| After mission | Already in act 1 (V) | Adds (two at most) | Later, by trigger |
|---|---|---|---|
| Start | Street races, random events, collectibles | Food stalls and the diner (package 1); the corner store with arcade cabinets (package 11) | |
| 1 Homecoming | The map | Lantern Quarter bars and the Blue Lantern (package 10); the first hoardings | |
| 2 Empty Rooms | Phone | Phone media; photo mode (packages 13 and 7) | The read-only Bourse ticker, as a phone tip the next game day (`STOCK_MARKET_DESIGN.md` §11, item 4) |
| 3 Lantern Lights | Taxi side job | Pool and darts (package 21); clothing shops and barbers (package 8) | The fixer's call the game day after Jules first holds dirty cash (people route, section 4) |
| 4 Wharf Rats | Courier side job | Ironwharf's paintball maze (u); the trampoline park (u) | The shooting range, by phone tip the next game day |
| 5 Krewe Business | Airboat, Krewe rep | Airboat racing: a first course in Blackwater Bayou's channels, and the full Glades course in Saltgrass Parish, reached by airboat (atlas D3, E3); bayou fishing at the Stilt Hall dock (N4) | |
| 6 Gilded Invitation | Aurum rep | Bourse trading (stock doc §11, item 4); Gilt's bowling alley | The escape room (u) and the yoga studio (package 28), on the first walk through Gilt after the mission |
| 7 Street Business | First business, safehouse, wardrobe | The franchise's first "For lease" lot (section 3.3) | The fronts laundering route, when the bookkeeper calls the first game day the stand has takings; the first "Buy and renovate" house in the Wards (driver 3) |
| 8 Hoops | Streetball league, boxing | The gym and fight styles (package 17) | The Wards' batting cage (u), once its corner lot is renovated |
| 9 Floodwater | First half of the ledger | The Old Streetcar Depot reopens as a gaming café (packages 11-12); the travelling fair on Liberty Green from its next season (package 32) | |
| 10 Magnolia | Second half of the ledger | Magnolia Heights' tennis club; the road east to Verdant Hills, with balloon rides on the first visit (CP-1) | The cat café (first visit to Magnolia Heights) |
| 11 Crescent Bridge | Captain Reyes | The road west over the Morrow (Route 1, beside the Crescent Bridge): Saltgrass Parish by car, with Cypress Bend and Gator Point; the wildlife photography challenge in the Glades (N25) | |
| 12 Cargo | Teo rescued | Brisa Beach's year-round fun pier (package 32) | |
| 13 Two Crowns | Act 2 opening | The first showroom, used cars (section 3.3; N19's car salesman); the laundering route for the path chosen | |

### 3.2 Later acts (spine from `WORLD_BIBLE.md:239-250`)

| Opens with | Places | Opens there (*suggested*) |
|---|---|---|
| Act 2, the money route | Concordia, Sovereign County, the Keys | CP-3 and the Keys half of CP-2 (cheaper version, atlas D5); the luxury showroom in Concordia; the Keys marina's boat dealer; company laundering (section 4); the Exchange broker office (stock doc §11, item 6) |
| Act 2 side roads (road crews finish, build phase 3) | Golden Flats, Hollow Mesa, Cinder County, Miravel Shores, Red Pine | One place every 1-2 missions, each with its signature: Golden Flats' flight school at the crop-duster strip and the Ironwharf Seaplane Base (package 30), with the tractor pull and pie contest at the Wheaton showground (the fair's rides join in fair season); land-sailing and the Sable Junction rodeo (a mechanical bull and dirt-bike barrels, no live animals); parachute jumps from Cinder Peak (package 31) and kalaripayattu from the hermit master; the lake triathlon (package 29) and wakeboarding; lumberjack games. Golden Flats waits for phase 3 because its only roads from Bellerive (Routes 40 and 9) are phase 3 (`world_map.json`) |
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
  | Gym | Advanced lessons from the place's fight master (the style itself opens with the act's city pack: Muay Thai in Las Brasas, judo in Concordia) | Stamina training |
  | Garage and showroom | Repairs, tuning, and the place's showroom stock at a discount | Vehicle storage |
  | Café | The place's food minigame and a save point (it writes the one save slot, stock doc §6.5 rule 5) | Local tips on the phone |
  | Club front | Music or dance nights (E2) | The biggest wash allowance |

  Every branch also adds local reputation and a daily wash allowance for the fronts route
  (section 4).
- **What a branch does not add: income.** All business takings stay under
  `biz_cap_w_per_day`, 0.35 W per game day (stock doc §6.6, sim check 8). Washing turns dirty
  cash into clean but creates no money, so it sits outside that cap. Money the player spends
  at their own businesses never counts as takings. The franchise pays in access, reputation
  and washing room, which keeps the economy safe.
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
  buy and test-drive screens 1. Needs N8, N20, N26 and the vehicles behind each catalogue
  (package 15 cars, package 26 boats, phase 3 aircraft). Cheaper: 1 session, with branches only and showrooms as a
  phone catalogue.

## 4. Money laundering (Sachin: "Use multiple ways of money laundering, either through corporates or individuals or gangs, this will progress with the story")

Today there is one cash pool (`game/scripts/main.gd:38`, V), and `_pass()` adds one
`m.reward` (`mission_manager.gd:159`, V). The *suggested* design:
- **Two balances.** Dirty cash comes from crime (robberies, heists, street-business raids,
  sabotage jobs) and from criminal missions: each mission's reward gets a clean or dirty tag
  in its data (act 1: missions 3 and 4 pay dirty, so the people route has a use from the
  start). Clean cash comes from legal mission pay, side jobs, business takings and share
  sales. The HUD shows one total, with the split on tap.
- **Spending.** Everyday buys (food, clothes, ammo, repairs, taxis, venue fees, private sales
  on the R-13 marketplace) take either, dirty first, so mobile players never juggle.
  **Big legal buys need clean cash**: property, lease lots, branches, showroom vehicles (the N19
  used lot included), boats and aircraft from dealers, school fees (flight, sailing, diving),
  Wards houses (driver 3) and Bourse shares (stock doc §11, item 11).
- **Selling.** Stolen goods, and anything any dirty cash paid for, sell for dirty cash. Items
  bought with clean cash sell for clean. Every owned vehicle and property carries this flag, so
  buying and reselling never washes money. A resale pays a fixed share (about 60%) of the price
  the player actually paid, never of list price, so a branch discount can't be resold at a
  profit. Renovated houses are the one exception: their flip profit is business takings, under
  the cap.
- **Routes**, each opened by the story:

| Route | Opens | How it works | Cut, limit, risk |
|---|---|---|---|
| People: a fixer and a bookkeeper | The first dirty cash (mission 3) | Hand over a bag; clean cash the next game day | 30%; a small daily cap; no risk |
| Your own fronts (the franchise) | Mission 7, more with each branch | Each business washes up to its wash allowance per game day; an auto-wash switch does it daily | 10%; the allowance is a hard cap, anything over it is refused |
| The side Jules chose | Mission 13 | Krewe side (a gang): the Krewe moves it through the bayou. Aurum side (a corporate): Aurum's Gilt firms book it as consulting fees | 20%; a daily batch cap, a 1-day wait; costs rep with the other side |
| High Water, if Jules played both | Mission 13, the "play both" ending, where Krewe and Aurum destroy each other and High Water walks away with the money (`ACT1_MISSIONS.md:176-178`) | Nia's crew moves it through Wards businesses | 25%; a smaller daily batch cap, a 1-day wait; no rival to anger |
| Companies | Act 2 (Concordia and the Keys) | Shell companies and Keys accounts; each shell company is a big legal buy | 5-8%; a 3-day wait; a volume cap per game week that grows with each shell company; the audit rolls on the rolling 7-game-day total, so splitting batches doesn't dodge it (a fine and an investigation mission) |
| The Velvet Aces' route | Act 3 | A hotel and lounge front (no casino games, `GANGSTAR_CONCEPT.md:101`) to take over or shut down | Story-set |

- **No loops.** Every route costs more than nothing. Nothing turns clean cash into dirty at a
  profit. The Bourse takes only clean cash. Washed cash never counts as business takings, so it
  never raises the business cap or the next day's allowance.
- **No reload dodges.** Audit rolls and batches still waiting, follow the stock
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
- **Save**: `SAVE_VERSION` 3, shared with the stock market's planned bump. N17, N20, N26 and
  N27 can ship in any order, so each loader checks for its own key, never the version number:
  - `unlocks` (opened, seen, visited, funded); a save without it rebuilds them from `done`, so
    an old save gets everything its missions earned (N26);
  - `cash_dirty` and `cash_clean`; a save without `cash_clean` loads its `cash` as clean (N20);
  - the dirty/clean flag on owned vehicles and property, waiting batches with their due game
    day, today's washing per route, and committed rolls (N20);
  - `branches`: lot, type and opening day (N27).
- **Tests** (`game/tests/run.sh`):
  - N26: passing a mission opens its venues; a save without `unlocks` loads with the right ones; a closed
    venue refuses entry with its reason; a first visit is counted once.
  - N20: a save without `cash_clean` loads its cash as clean; every cut is above zero; dirty
    cash can't buy shares or big legal buys; a dirty-bought car sells for dirty cash; the
    fronts cap refuses extra; splitting a large sum into small company batches still trips the
    weekly audit; a reload doesn't change a committed roll or a waiting batch; a dirty-tagged
    mission reward lands as dirty.
  - N27: a branch adds its allowance and reputation, never takings above the cap; buying at the
    branch discount and reselling always loses money.
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
