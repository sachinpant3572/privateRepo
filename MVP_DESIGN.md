# MVP design: one-city open-world crime game

Status: **draft**, Oct 26, 2026. Builds on `GANGSTAR_CONCEPT.md` (phase 1 of
its suggested phasing). Names below are placeholders; nothing is decided until
marked **Decision**.

Research: `reference/README.md` (top-down games reference bible) compares
five top-down mobile games and proposes 25 changes for Solvera (Part C).

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
| Look | Code-built 3D in a stylised but present-day look: real materials (glass, metal, asphalt, brick), modern roofs and street furniture, classic top-down camera (see "Camera decision" and "Look update, Oct 27") | One model works from every angle, so vehicles and clothing stay cheap; the detail sits in the shader, so it costs no textures or extra draw calls. |
| Min device | ~4 GB RAM, mid-range 2021 Android chip | Covers most active devices in India and similar markets. |
| Frame rate | 30 fps locked on min device, 60 fps option on high-end | Battery and heat matter on phones. |
| Install size | Base under 150 MB, rest downloaded as content packs | Store limits and data costs. |
| Offline | Fully playable offline; online only for leaderboards, events, cloud save | Patchy connections. |

## Camera decision

**Update (Oct 28, 2026): perspective top-down by default.** Same north-up
view, but in true perspective (65° pitch, 35° field of view) like GTA
Chinatown Wars, so towers lean out as you pass; buildings that hide the
ground round and ahead of the player are cut away. Settings > View keeps the
classic flat 60° view below, and Settings > Zoom sets 80-130%. See
HANDOFF-perspective-camera.md. Full 3D is parked in TODO.md.

**Decision (Oct 26, 2026): classic top-down view only.** North is up, and the
camera looks down at 60° below the horizon, a 3/4 view that shows the fronts
of buildings and people, like the Java-era Gangstar games, Stardew Valley, Crashlands and
Chronomon. The isometric view is dropped.

What this means for the art:
- **Roofs are what players see most**: give them detail and variety (tiles,
  vents, water tanks, rooftop gardens, signs).
- **Characters read from above**: big heads, hats and hair, strong shoulder
  colours, clear outlines, so people are recognisable at a glance.
- **Vehicles read by silhouette and roof colour**: taxis, police and
  faction cars get distinct roof markings.
- **Height still matters**: planes and helicopters later show altitude with
  zoom and shadows, as Chronomon-style games do with jumps and flight.

## Visual direction: classic + modern

**Decision (Oct 26, 2026)**: "high-quality graphics" means a readable cartoon
look that combines old and new game mechanics and effects, not realism,
and clearly better than the classic games in every area.
Every effect must look good at a glance on a phone screen and have a low-end
setting that keeps 30 fps on the min-spec device.

**Look update (Oct 27, 2026)**, after Sachin: "The graphics still seem
primitive, I mean it is good to show a vintage style but the game is set in
the current modern times, and we need to show more details." The toon,
"readable cartoon" look is replaced by a stylised present-day one:
- shading: Burley diffuse with GGX highlights instead of toon bands, ACES
  tonemapping; glass mirrors the sky, paint and metal shine;
- surfaces: a code per vertex picks a material in the city shader (asphalt
  with cracks and patches, concrete slabs, pavers, brick, lap siding,
  standing-seam metal, roof membrane, solar cells, grass), so detail costs
  no textures; Settings > Detail low turns the patterns off;
- roofs (most of what the camera sees): parapets, HVAC, solar rows,
  skylights, stair huts, terraces, green roofs; towers get curtain walls;
- streets: stop bars, lane arrows, bike boxes, parking lines; LED lights,
  mast-arm signals, bus shelters, bike-share docks, EV chargers, e-scooters;
- vehicles: present-day body shapes with glass.
The decisions and their costs are in `HANDOFF-modern-look.md`.

| From the classic games (Java Gangstar, GTA 2 era) | From modern games |
|---|---|
| **Top-down camera**, north up, perspective or classic (in the prototype) | Smooth follow, lead ahead of cars, zoom out with speed (in the prototype) |
| Wanted stars, instant carjacking, arcade driving | Day/night lighting, neon at night, weather (rain, storms, flooding) |
| Big, readable characters and cars; clear colours | Particles: skid marks, tyre smoke, sparks, dust, splashes |
| Arrows and markers to the next objective | Screen shake and hit-stop on punches and crashes, phone vibration |
| Rampages, hidden packages, stunt jumps | Knockdowns with physics, breakable props (hydrants, lamp posts, fences) |
| Radio stations in cars | Music that changes by district and action (AI-generated) |
| Quick mission restarts | Buildings dissolve around the player, and silhouettes show who is hidden (in the prototype) |

**Keeping the action visible.** Even from steeply above, tall buildings must
never hide what the player needs to see:
- **Cutaway** (in the prototype): when a building blocks the view of the
  player, it dissolves in a circle around them, then closes again.
- **X-ray silhouettes** (in the prototype): the player in yellow, police in
  blue, anyone attacking in red.
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
- **Quality is enough for the art style**: code-built 3D with shader
  materials and a fixed top-down camera don't need Unity's rendering lead.
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

**Decision (Oct 26, 2026): free-to-play.**
- Soft currency: cash (earned everywhere). Premium currency: buys cosmetics,
  vehicles and time-savers only.
- Optional rewarded ads (double payout, instant taxi); never forced ads
  mid-mission.
- Cosmetic season track.
- No energy timers, no pay-to-win, no paid loot boxes (from the design
  pillar).

Guardrails from the research (`reference/README.md`, B12):
- **Tune the economy for play, not for sales.** Never sell relief from pain
  the design creates (Survival RPG's diamonds, Bad 2 Bad's paid storage).
- **Rewarded ads only, after missions, capped per hour.** No interstitials
  at area transitions; load ads off the main thread and never during combat.
- **One-time "Remove ads + starter pack" purchase.**
- **Main paid items:** outfits, vehicle paint and parts, safehouse decor,
  the cosmetic season track; later, optional story packs at a fair price.
- **Depth for revenue:** cosmetics and seasons, not a thin finite game
  (Survival RPG's ~20M installs earn little).
- **Value tied to the account** (cloud save, events) rather than DRM.
- **One brand word** in every store title ("Solvera: ...").

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

**Status (Oct 27, 2026)**:
- **Milestone 1 is done.** The demo map ran smoothly on real phones: a
  steady 120 fps on a Galaxy S25 Ultra and 30 fps on a phone with a much
  weaker CPU and GPU, which meets the 30 fps exit check and confirms Godot.
  The 6-block grey box had already grown into the **demo map**: 1.3 km x
  1.1 km of Bellerive (25 x 22 blocks: Gilt District, Lantern Quarter,
  Floodline Wards, Ironwharf and the Morrow River), streamed in cells,
  built from the asset kits.
- **Milestone 2 (vertical slice) is under way**:
  - **Missions 1-3**, the phone, a minimap and a full map are in;
  - the Lantern Quarter is getting its final look: day and night, rain,
    lit windows, lamp pools and neon, shopfronts, festoon lights and
    effects;
  - **still missing**: the random event set and a playtest.

  **Map overhaul (Oct 27)**: the first demo map read as a chessboard.
  Following the research in `reference/MAP_BUILDING.md`, Bellerive's streets
  now follow the river's crescent, with a road hierarchy (boulevards with
  neutral grounds, avenues, a river road, narrow Quarter streets and
  pedestrian lanes), uneven blocks, T-junctions and a park superblock. The
  Morrow was reshaped near the city to match.

  **Map v2 (Oct 27)**: the bent grid still read as a grid, so the street
  plan was rebuilt as a real street network, after how GTA and Watch Dogs
  built their cities (`reference/MAP_BUILDING.md` section 6):
  - each district has its own curved, fanned street pattern, meeting the
    next along seam roads;
  - blocks have any shape;
  - Liberty Avenue is the diagonal, and Morrow Bridge crosses to a new
    far-bank district, Morrow Point;
  - the demo window grew to 1.3 km x 1.5 km (25 x 28 blocks' worth).

  The extra night, rain and effects work costs about 0.3-0.6 ms of CPU per
  frame on desktop. A Detail LOW setting and a shadows toggle are in the
  phone for weak devices. See `game/README.md`.

Timelines depend on team size; to be estimated once the team and the split
between Claude, AI tools and people are decided.

## Character art decision

**Decision (Oct 27, 2026)**: characters will be **AI-generated 3D models
with a standard animation set**: models made with an image-to-3D tool,
auto-rigged to a standard humanoid skeleton, sharing one set of animation
clips.

**For now, no credits are being spent.** The prototype's people are built
in code on a humanoid skeleton that uses the standard bone names (Hips,
Spine, Chest, LeftUpperArm...) and are animated in code. Modelled characters
on the same skeleton can replace them later without changing the gameplay
or animation code.

## Open decisions

1. Protagonist: fixed character or customizable.
2. Launch markets for soft launch.
3. Team: who does art, animation and QA alongside Claude.
4. Which of the 25 research proposals to adopt (`reference/README.md`, C2).
