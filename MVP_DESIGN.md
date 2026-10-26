# MVP design: one-city open-world crime game

Status: **draft**, Oct 26, 2026. Builds on `GANGSTAR_CONCEPT.md` (phase 1 of
its suggested phasing). Names below are placeholders; nothing is decided until
marked **Decision**.

## MVP goal

Prove, in one city, that the game is fun and keeps players coming back:
- Driving, fighting and exploring feel good on a touch screen.
- Story act 1 hooks players and the faction choice makes them want act 2.
- Daily and weekly loops hit the retention targets in soft launch
  (D1 40%+, D7 20%+, D30 10%+).

Everything not needed to prove that waits for later phases.

## Platform and tech

| Area | Proposal | Why |
|---|---|---|
| Platforms | Android first, iOS right after | Larger audience in target markets; one codebase covers both. |
| Engine | **Decision: Godot 4** | See "Engine decision" below. |
| Look | Low-poly 3D, toon shading, fixed orthographic isometric camera | Reads as 2D isometric cartoon, but one model works from every angle, so vehicles and clothing stay cheap. |
| Min device | ~4 GB RAM, mid-range 2021 Android chip | Covers most active devices in India and similar markets. |
| Frame rate | 30 fps locked on min device, 60 fps option on high-end | Battery and heat matter on phones. |
| Install size | Base under 150 MB, rest downloaded as content packs | Store limits and data costs. |
| Offline | Fully playable offline; online only for leaderboards, events, cloud save | Patchy connections. |

## Visual direction: classic + modern

**Decision (Oct 26, 2026)**: "high-quality graphics" means a readable cartoon
look that combines old and new game mechanics and effects, not realism.
Every effect must look good at a glance on a phone screen and have a low-end
setting that keeps 30 fps on the min-spec device.

| From the classic games (Java Gangstar, GTA 2 era) | From modern games |
|---|---|
| **Classic camera**: optional steep top-down view, north up (in the prototype) | Isometric 3D default view with smooth follow, lead and speed zoom |
| Wanted stars, instant carjacking, arcade driving | Day/night lighting, neon at night, weather (rain, storms, flooding) |
| Big, readable characters and cars; clear colours | Particles: skid marks, tyre smoke, sparks, dust, splashes |
| Arrows and markers to the next objective | Screen shake and hit-stop on punches and crashes, phone vibration |
| Rampages, hidden packages, stunt jumps | Knockdowns with physics, breakable props (hydrants, lamp posts, fences) |
| Radio stations in cars | Music that changes by district and action (AI-generated) |
| Quick mission restarts | Buildings dissolve around the player, and silhouettes show who is hidden (in the prototype) |

**Keeping the action visible in the isometric view.** Buildings must never
hide what the player needs to see:
- **Cutaway** (in the prototype): anything between the camera and the player
  dissolves in a circle around them.
- **X-ray silhouettes** (in the prototype): the player in yellow, police in
  blue, anyone attacking in red.
- **Classic camera** (in the prototype): steep top-down view with almost no
  occlusion.
- **Objective markers and arrows** always draw on top (vertical slice).
- **Level design**: mission-critical interactions (fights, pickups, doors)
  sit on streets, plazas and courtyards, with the camera side kept open.

## Engine decision

**Decision (Oct 26, 2026): Godot 4**, chosen over Unity 6.

Why:
- **Built mostly by Claude**: Godot scenes and scripts are compact, readable
  text, so Claude can edit them directly. That means far fewer tokens per
  feature than Unity's large generated scene files and editor round-trips.
- **Works in cloud sessions**: the engine runs headless in the container, so
  Claude can build, test and export Android builds there, which fits working
  from a phone. Unity needs a desktop with the editor open.
- **Quality is enough for the art style**: low-poly 3D, toon shading and a
  fixed isometric camera don't need Unity's rendering lead.
- **Free, no royalties**, and smaller base downloads.

Accepted risks and how to handle them:
- **Low-end Android performance**: use Godot's lighter renderer, keep draw
  calls and shaders simple, stream the city in chunks, profile on a real
  min-spec phone from the first prototype.
- **Ads, payments, analytics**: official Google Play Billing plugin; ad
  networks and analytics through community or vendor plugins, checked and
  chosen before the beta.
- **Open-world streaming**: custom chunk loading code instead of ready-made
  tools.
- **Smaller asset store**: rely on generated and custom assets.
- **Consoles later**: possible only through third-party porting companies.

Fallback: if the prototype can't hold 30 fps on a min-spec phone, revisit the
engine then, while switching is still cheap.

## The city: Bellerive (New Orleans-inspired, fictional)

Names, history and factions come from `WORLD_BIBLE.md`; positions and sizes
from the map data `game/data/world_map.json` (picture: `bellerive_map.svg`).

About 2 km x 1.25 km of game space on the Morrow River, 6 districts, each with
its own look, music and faction presence.

| District | Feel | Role |
|---|---|---|
| Lantern Quarter | Balconies, jazz bars, tourist streets | Story hub, shops, nightlife events |
| Ironwharf | Cranes, warehouses, ships | Smuggling missions, boats, heist targets |
| Magnolia Heights | Mansions, oak-lined streets | Wealthy targets, property to buy |
| Floodline Wards | Shotgun houses, storm scars, street courts | Turf wars, street business, basketball courts |
| Gilt District | Towers, Aurum Tower, Union Station | Aurum HQ, high-wanted zone |
| Blackwater Bayou | Swamp, stilt houses, airboats | Hidden places, lore, boat chases |

Connected by a **streetcar line** (fixed-route fast travel; the city's
signature transport) and **taxis** (ride anywhere, or drive one as a side job).

## Story act 1 (~12-15 missions, ~4-6 hours)

Premise (full story spine in `WORLD_BIBLE.md`):

> Jules Moreau returns to Bellerive twelve years after the Great Storm to
> find their cousin Teo missing with a ledger of Aurum's bribes. Caught
> between the Marrow Krewe and the Aurum Consortium, Jules ends act 1 with a
> choice: side with one, or play both against each other.

- **Opening (first 10 minutes)**: arrival, a chase through the Lantern Quarter on
  a stolen scooter, first fight, first car. Tutorial is the action.
- **Missions 2-6**: learn the city, meet both factions, unlock phone, wanted
  system, first safehouse and street business.
- **Missions 7-12**: rising stakes: docks shoot-out, bayou boat chase,
  Magnolia Heights break-in, a betrayal.
- **Finale**: faction choice, which sets act 2's opening (teased, not built).

Every mission offers at least two approaches (stealth / loud / vehicle).

## Factions (MVP)

- **Marrow Krewe**: bayou smuggling families; loyal, old-school.
- **Aurum Consortium**: corporate money; polished, ruthless.
- **High Water**: the Floodline crew; minor faction in act 1.
- **Police (Bellerive PD)**: not joinable; drives the wanted system.

Reputation is tracked per faction and per district. It unlocks missions, shop
discounts and allies, and decides who attacks the player on sight.

## Systems in the MVP

| System | MVP scope |
|---|---|
| On foot | Run, sprint, climb low walls, cover, melee (one fighting style + one unlockable) |
| Weapons | ~8: bat, knife, pistol, revolver, SMG, shotgun, rifle, molotov |
| Vehicles | ~8 cars, 2 motorbikes, 1 bicycle, 2 boats (speedboat, airboat), taxi |
| Transport | Streetcar line, taxis |
| Wanted system | 5 levels: patrol cars, roadblocks, SWAT, helicopter, boats on water |
| Phone hub | Contacts, mission offers, map, bank, vehicle and property marketplace, social feed |
| Street business | 3 types (food stand, garage, nightclub front); passive income, raids, supply runs |
| Property | 3 safehouses (save, garage, wardrobe), furnishable |
| Shops | Clothing, weapons, vehicle tuning, food; all enterable |
| Customization | Clothing (~60 items), vehicle paint and parts |
| Skills | Driving, shooting, stamina, strength; grow with use |
| Sports | Street basketball (3v3) and boxing, each with ranks and a weekly league |
| Side jobs | Taxi, courier, street races, vigilante |
| Random events | ~15 types: muggings, chases, accidents, people asking for help, rival ambushes |
| Collectibles | Hidden packages, graffiti tags, landmark photos, 3 secret areas with lore |
| Living world | Day/night, rain and storms, NPC routines, traffic |
| Audio | AI-generated score per district + 3 radio stations with DJ chatter |
| Online (light) | Leaderboards, weekly events, cloud save |

## Not in the MVP

Second city, island, planes, helicopters (except police), trains, metro,
airships, cruise ships, other sports, heists (beyond one story mission),
New Game+, real-time multiplayer.

## Core loops

- **Moment to moment**: drive, fight, explore; something happening every
  block.
- **Session (10-20 min)**: mission or side job or event → cash and reputation
  → buy, upgrade, unlock.
- **Daily**: phone jobs, business income, daily match, event hotspots.
- **Weekly**: turf war, sports league, weekly challenge, shop rotation.

## Economy and monetization

**Proposal**: free-to-play, which is how most Android revenue is earned.
- Soft currency: cash (earned everywhere). Premium currency: buys cosmetics,
  vehicles and time-savers only.
- Optional rewarded ads (double payout, instant taxi); never forced ads
  mid-mission.
- Cosmetic season track.
- No energy timers, no pay-to-win, no paid loot boxes (from the design
  pillar).

Alternative: paid upfront plus cosmetic store. Simpler, fewer players.

## Controls

Left stick to move, right side buttons (attack, sprint, enter vehicle,
weapon wheel); tap-to-aim with soft auto-aim; optional tilt steering;
controller support.

## Analytics from build one

Tutorial funnel, mission start/complete/fail/quit, session length, D1/D7/D30,
where players quit, economy sources and sinks, crash and performance per
device.

## Milestones

| Milestone | Contents | Exit check |
|---|---|---|
| 1. Prototype | Grey-box district, driving, on-foot, fighting, wanted levels 1-2 | Driving and fighting are fun on a phone, at 30 fps on a min-spec phone (confirms the engine choice) |
| 2. Vertical slice | Lantern Quarter at final quality, first 3 missions, phone, one random event set | Playtesters want to keep playing |
| 3. Alpha | All 6 districts, act 1 complete, all MVP systems | Feature complete |
| 4. Beta | Content polish, performance on min device, monetization, analytics | Stable on min device |
| 5. Soft launch | 2-3 test countries | Retention near targets |
| 6. Global launch | Android, then iOS | |

**Status**: milestone 1 (prototype) is playable in `game/`, pending the
fun and 30 fps checks on a real phone. See `game/README.md`.

Timelines depend on team size; to be estimated once the team and the split
between Claude, AI tools and people are decided.

## Open decisions

1. Business model: free-to-play (proposed) or paid upfront.
2. Names: proposed in `WORLD_BIBLE.md`, awaiting approval.
3. Protagonist: fixed character or customizable.
4. Launch markets for soft launch.
5. Team: who does art, animation and QA alongside Claude.
