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

## The city: "Port Lafitte" (New Orleans-inspired, fictional)

About 2 km x 2 km of game space, 6 districts, each with its own look, music
and faction presence.

| District | Feel | Role |
|---|---|---|
| Old Quarter | Balconies, jazz bars, tourist streets | Story hub, shops, nightlife events |
| Riverside Docks | Cranes, warehouses, ships | Smuggling missions, boats, heist targets |
| Garden Heights | Mansions, oak-lined streets | Wealthy targets, property to buy |
| Lower Wards | Shotgun houses, corner stores | Turf wars, street business, basketball courts |
| Downtown | Towers, nightlife, offices | Syndicate HQ, high-wanted zone |
| Bayou Edge | Swamp, stilt houses, airboats | Hidden places, lore, boat chases |

Connected by a **streetcar line** (fixed-route fast travel; the city's
signature transport) and **taxis** (ride anywhere, or drive one as a side job).

## Story act 1 (~12-15 missions, ~4-6 hours)

Placeholder premise, to be replaced or refined:

> The player returns to Port Lafitte after years away and finds their
> family's corner business swallowed by a turf war between two factions. A
> storm night, a missing cousin and a stolen ledger pull them in. Act 1 ends
> with a choice: side with one faction, or play both against each other.

- **Opening (first 10 minutes)**: arrival, a chase through the Old Quarter on
  a stolen scooter, first fight, first car. Tutorial is the action.
- **Missions 2-6**: learn the city, meet both factions, unlock phone, wanted
  system, first safehouse and street business.
- **Missions 7-12**: rising stakes: docks shoot-out, bayou boat chase,
  Garden Heights break-in, a betrayal.
- **Finale**: faction choice, which sets act 2's opening (teased, not built).

Every mission offers at least two approaches (stealth / loud / vehicle).

## Factions (MVP)

- **Bayou Wolves**: smugglers from the swamp edge; loyal, old-school.
- **Crescent Syndicate**: downtown money; polished, ruthless.
- **Police (PLPD)**: not joinable; drives the wanted system.

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
| 2. Vertical slice | Old Quarter at final quality, first 3 missions, phone, one random event set | Playtesters want to keep playing |
| 3. Alpha | All 6 districts, act 1 complete, all MVP systems | Feature complete |
| 4. Beta | Content polish, performance on min device, monetization, analytics | Stable on min device |
| 5. Soft launch | 2-3 test countries | Retention near targets |
| 6. Global launch | Android, then iOS | |

Timelines depend on team size; to be estimated once the team and the split
between Claude, AI tools and people are decided.

## Open decisions

1. Business model: free-to-play (proposed) or paid upfront.
2. City name, premise and faction names.
3. Protagonist: fixed character or customizable.
4. Launch markets for soft launch.
5. Team: who does art, animation and QA alongside Claude.
