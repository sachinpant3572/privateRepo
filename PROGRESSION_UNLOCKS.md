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
`ACTIVITY_ATLAS.md` (city packs, CP-n).

## 1. Framing: keep the canon, get the same effect

The pitch as written clashes with the canon in three places (V):
- Bellerive is not new: French settlers founded it about 300 years ago (`WORLD_BIBLE.md:50`).
- Jules is not a stranger: they come home twelve years after the Great Storm to find their
  cousin Teo (`MVP_DESIGN.md:155`, `ACT1_MISSIONS.md:60`).
- Jules is written as gender-neutral, and "fixed or customizable" is still open
  (`MVP_DESIGN.md:319`). This doc uses "they".

The canon already holds what the pitch needs (V):
- The Great Storm drowned half the city, and Aurum is rebuilding it (`WORLD_BIBLE.md:31-35`).
- There are building sites across the map, and the Solvera Line is "under construction; opening
  it is the story's spine" (`WORLD_BIBLE.md:58-60`, `game/data/world_map.json:98`).
- Each city ships behind a story gate (`WORLD_V3_PLAN.md:355-357`).

**Recommendation: "the Rebuild"**, with three unlock drivers:
1. **The city reopens.** Half of Bellerive is still being rebuilt. Venues and showrooms sit
   behind "Opening soon" hoardings and open at story beats, each with an opening day. Outside
   the city, roads, bridges and Solvera Line stations open region by region.
2. **Jules builds a franchise.** From the act 1 food stand (mission 7), Jules opens branches
   (gym, garage and showroom, café, club front) on "For lease" lots in each new place. A branch
   brings that place's activities: a gym branch in Las Brasas brings the Muay Thai master. This
   is the "expand a franchise from scratch" loop, played by the player.
3. **Exploring pays.** A region's venues appear on the map after the first visit, or after a
   phone tip. The first visit pays a small reward and fills the phone's "New in town" page.

*Suggested* canon touch for the "escape" part: Jules also comes home to get out of the
getaway-driver life in Porto Brisa. The canon already makes that past come back in expansion 1
("Jules's past as a getaway driver and Lua Ferreira come due", `WORLD_BIBLE.md:246-247`), so
this adds a motive without changing a beat.

Why this beats a brand-new city: the storm and the rebuild explain every closed door. The map
stays open for free roam, which mission 1 unlocks (`ACT1_MISSIONS.md:43`). Unlocks gate venues,
showrooms and regions, never Bellerive's streets.

## 2. Pacing rules

- **Something new every 20-30 minutes** of play in act 1, and every 1-2 missions later.
- **Never more than two new things at once.** Each one arrives with a short intro: a phone
  call, a flyer or an opening-day event (ribbon, free first go, a crowd).
- **Always show what's next.** Two or three hoardings in sight say what's coming and what opens
  it ("Opens when the Crescent Bridge reopens").
- **The basics are always on**: free roam, street races, random events and collectibles from
  the start, as act 1 already plans (`ACT1_MISSIONS.md:190`).
- **Every region keeps its own reason to visit**: its signature activity (atlas D3) opens on the
  first visit, and its city pack opens with that place's act.

## 3. Unlock ladder

### 3.1 Act 1, Bellerive

The "Unlocks" column of `ACT1_MISSIONS.md:41-55` is kept (V). The additions are *suggested*.

| After mission | Already in act 1 (V) | Adds (*suggested*) |
|---|---|---|
| Start | Street races, random events, collectibles | Food stalls and the diner (package 1), the corner store, arcade cabinets in the 24-7s (package 11) |
| 1 Homecoming | The map | Lantern Quarter bars and the Blue Lantern (package 10); the first hoardings |
| 2 Empty Rooms | Phone | Phone media and photo mode (packages 13 and 7); the read-only Bourse ticker (`STOCK_MARKET_DESIGN.md` §11, item 4) |
| 3 Lantern Lights | Taxi side job | Pool and darts in the Lantern Quarter (package 21) |
| 4 Wharf Rats | Courier side job | Ironwharf's paintball maze and trampoline park; the shooting range |
| 5 Krewe Business | Airboat, Krewe rep | Saltgrass Parish: bayou fishing and airboat racing (CP-1 signature) |
| 6 Gilded Invitation | Aurum rep | Gilt opens its doors: bowling, the escape room, the yoga studio (package 28); Bourse trading |
| 7 Street Business | First business, safehouse, wardrobe | Clothing shops and barbers (package 8); the **franchise** starts; the first laundering route (section 4) |
| 8 Hoops | Streetball league, boxing | The gym and fight styles (package 17); the Wards' batting cage |
| 9 Floodwater | First half of the ledger | The Old Streetcar Depot reopens as a gaming café (packages 11-12) |
| 10 Magnolia | Second half of the ledger | Magnolia Heights: the tennis club and the cat café |
| 11 Crescent Bridge | Captain Reyes | The bridge reopens: Brisa Beach's pier and the fair (package 32), Golden Flats and Verdant Hills |
| 12 Cargo | Teo rescued | The airport: flight school at the crop-duster strip (package 30) |
| 13 Two Crowns | Act 2 opening | The first used-car showroom (N19 car salesman); gang laundering for the side Jules chose |

### 3.2 Later acts (spine from `WORLD_BIBLE.md:239-250`)

| Opens with | Places | Opens there (*suggested*) |
|---|---|---|
| Act 2, the money route | Concordia, Sovereign County, the Keys | CP-3 and the Keys half of CP-2 (cheaper version, atlas D5); a luxury car showroom in Concordia; company laundering (section 4); the Exchange broker office (`STOCK_MARKET_DESIGN.md` §11, item 6) |
| Act 2 side roads (road crews finish) | Miravel, Red Pine | Their signatures (CP-1): wakeboarding, lumberjack games |
| Act 3, the line | Las Brasas, Hollow Mesa, Cinder, Fort Granite | CP-2's Las Brasas half and CP-1's desert signatures; parachute jumps (package 31); an exotic-car showroom; the Velvet Aces' route, taken over or shut down |
| Steelhaven strand | Steelhaven, Corran | CP-4; a muscle-car showroom |
| Act 4, the vault | Isla Serena | The finale's island venues (not yet designed) |
| Expansions 1 and 2 | Porto Brisa, the California city | CP-5, CP-6 |

Each new place opens with the same beat: arrival, the signature activity, two hoardings and a
"For lease" lot for the next franchise branch.

## 4. Money laundering (decision 8: "Use multiple ways of money laundering, either through corporates or individuals or gangs, this will progress with the story")

Today there is one cash pool (`game/scripts/main.gd:38`, V). The *suggested* design:
- **Two balances.** Dirty cash comes from crime (robberies, heists, street-business raids,
  sabotage jobs). Clean cash comes from missions' legal pay, side jobs, business takings and
  share sales. The HUD shows one total, with the split on tap.
- **Spending.** Everyday buys (food, clothes, ammo, repairs, taxis) take either, dirty first, so
  mobile players never juggle. Big legal buys need clean cash: property, showroom cars, new
  branches, school fees and the Bourse (stock doc §11, item 11).
- **Routes**, each opened by the story. Every route takes a cut, and the cut is the money sink:

| Route | Opens | How it works | Cut, limit, risk |
|---|---|---|---|
| People: a fixer and a bookkeeper | Mission 7 | Hand over a bag; get clean cash the next game day | 30%; a small daily cap; none |
| Your own fronts (the franchise) | Mission 7, more with each branch | Each business washes up to its takings per game day; an auto-wash switch does it daily | 10%; washing more than the takings raises an audit chance (a fine) |
| Gangs | Mission 13, by the side chosen | The Krewe moves it through the bayou, or Aurum's people through the Gilt | 20%, big batches, a 1-day wait; costs rep with the other side |
| Companies | Act 2 (Concordia and the Keys) | Shell companies and Keys accounts; investigation missions follow big moves | 5-8%, large batches, a 3-day wait; audits |
| The Velvet Aces' route | Act 3 | A hotel and lounge front (no casino games, `GANGSTAR_CONCEPT.md:101`) to take over or shut down | Story-set |

- **No loops**: every route costs more than nothing; nothing turns clean cash into dirty at a
  profit; the Bourse takes only clean cash; business takings stay under `biz_cap_w_per_day`
  0.35 W per game day across all branches (stock doc §6.6, sim check 8). More branches add
  places and variety, not unlimited income.
- **Cost**: `ACTIVITY_IDEAS.md` N20, now 2.5 sessions (was 1.5).

## 5. Build plan (N26)

- **Data**: `game/data/unlocks.json`. Each entry has an id, a kind (venue, activity, region,
  showroom, route, lease lot), a place and its requirements (a mission passed, an act, a region
  visited, a reputation level). It also says whether it shows a hoarding first, and its
  teaser text.
- **Code**: a `game/scripts/unlocks.gd` autoload with `is_open(id)`, `on_mission_pass(id)`,
  `on_region_entered(id)`, `newly_opened()` and an `opened(id)` signal.
  - Hooks (V, current code): `mission_manager.gd` `_pass()` (line 150) calls it.
  - `interiors.gd` `lock_reason()` (line 99) adds "Opening soon".
  - `places.gd` places a hoarding prop at closed spots.
  - The phone gets a "New in town" page, shown the way `hud.gd:181` gates the phone today.
  - `city.gd:719-750` keeps filtering by build phase; story gates are a separate layer.
- **Save**: one bump to `SAVE_VERSION` 3, shared with the stock market's planned bump. It adds
  `unlocks` (opened, seen, visited). On load, unlocks are rebuilt from `done`, so an old save
  gets everything its missions earned.
- **Tests** (`game/tests/run.sh`):
  - passing a mission opens its venues;
  - a v2 save loads with the right unlocks;
  - a closed venue refuses entry with its reason;
  - a first visit is counted once;
  - the laundering cut is never below zero and dirty cash can't buy shares.
- **Cost: about 2 sessions**: registry, save, hooks and tests 1; hoardings, opening-day events
  and the phone page 1. Cheaper: 1 session with the registry, the lock check and a plain phone
  list, but no hoardings and no opening days. That loses most of the "city being built" feel,
  so the full 2 is recommended.

## 6. Open points for Sachin

1. **Canon touch**: should Jules also be running from the Porto Brisa getaway life (section 1)?
   Recommended: yes, since it is the "escape" part of the pitch and costs nothing.
2. **Hero**: stay with the gender-neutral Jules (`MVP_DESIGN.md:319`), or fix the hero as a man,
   as the pitch says "his"?
3. **Act and build order** (inference from `WORLD_V3_PLAN.md:346-353` and `WORLD_BIBLE.md:239-250`):
   act 2 needs Concordia (build phase 5) and the Keys (phase 4), but act 3's Las Brasas is also
   phase 4. Either build Concordia before Las Brasas, or swap acts 2 and 3. Recommended: build
   the Keys and Concordia first, since the ledger story leads there.
4. **Districts**: the recommendation gates venues and regions only, never Bellerive's streets.
   Fence off districts too, the GTA III way? Recommended: no; free roam is the hook from
   mission 1.
