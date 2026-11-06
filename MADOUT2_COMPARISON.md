# MadOut2 vs Solvera: scope, popularity and lessons (2026-10-30)

Sachin's request, word for word: "check later how much ambitious is MadOut2, the open world android
game. And how ambitious is our game compared to it, what all our game lacks, what are the best
features of MadOut2, and how has it become so popularx and what can we learn from this."

Research only. Nothing was built.

## 0. Method, labels and limits

- **No web page could be opened.** `apps.apple.com` and `appgoblin.info` failed in WebFetch as
  outside this container's network allowlist (getaddrinfo ENOTFOUND), so no further hosts were
  tried. `play.google.com` was blocked earlier and was not retried. Every web fact below comes from
  **WebSearch result summaries** that quote the page named in brackets. The earlier pass in
  `ACTIVITY_ROADMAP.md` (section 0) worked the same way.
- **Labels** on every fact:
  - **V**: a search summary quoting an official page (store listing, Steam, APKMirror release notes);
  - **S**: secondary (a tracker estimate, guide, APK or review site). Treat numbers as rough;
  - **R**: reused from `ACTIVITY_ROADMAP.md` (its sources [M1]-[M3], listed there at lines 362-372);
  - **I**: my inference, not a fact.
- **Solvera facts** come from the repo only (code, data, docs), with file references. "Built" means it
  is in code now; "planned" means it is only in a plan or TODO.
- Source ids ([A1] and so on) are listed in section 7.

## 1. MadOut2 in numbers and scope

| Item | What was found | Label, source |
|---|---|---|
| Developer | App Store seller: Vladislav Ivanchuk. Newer Android builds: MadOut Games LLC FZ | V [A1][A5]; V [A6] |
| Studio size | MadOut Games, Astana (Kazakhstan): "29 employees" and "51-100" on the same page, which also calls the team small | S [A12], conflicting |
| Lineage | MadOut (Steam, 5 June 2015, a combat racer by Nuligine / MadOut Games); MadOut2 BigCityOnline on Steam 21-22 Feb 2017, now "[CLOSED]", all-time peak 432 players | V [A9][A10]; S [A11] |
| Mobile launch | iOS listing dated 12 May 2017 | S [A8] |
| Names over time | "MadOut2 BigCityOnline", then "MadOut 2: Grand Auto Racing", now "MadOut 2: NTE RP racing game" on APKMirror and localised titles such as "Online Auto RP Welt" (DE) and "RP Voiture Monde" (FR). Package `com.MadOut.BIG` | V [A1][A5]; S [A7] |
| Platforms | Android, iOS; the Steam version is closed | V [A1][A10] |
| Installs | Google Play: **100M+ downloads, about 1.2M reviews** (quoted from the Play listing in a search summary; page not opened). AppBrain puts it in the 100M-1B bracket | V [A2]; S [A3] |
| Rating | 4.2 from about 1.04M ratings; 4.1 from 1,039,411 (older snapshot, 97.3M installs) | S [A4][A7] |
| Revenue | About $100K+ a month, split 48% purchases and 52% ads (estimate); Adapty also says about $100K a month and 500K downloads a month. Sensor Tower, Russia iOS only: weekly revenue peaks of about $18.8K (Q2 2021) and $9.4K (Q2 2025) | S [A13][A14]; S [A15] |
| Setting and map | "Stylish Eastern Europe locations", city streets out to desert. **Map size and city count: not found** | V [A1]; S [A16] |
| Vehicles | "More than 70 types of cars, from farm tractor to premium cars"; a tank (18.05); 17.05 added 3 bikes, 8 cars, 20 tuning options, 6 outfits, 6 weapon skins | V [A1]; R [M2]; V [A5] |
| Multiplayer | "Up to 200 players on the server" (one source says 100). Modes: free roam, role play, Cops vs Bandits (mass shootouts), racing and parkour; 1v1 and drag races; single player offline | V [A1]; S [A16]; R [M2] |
| Progression | Clans with seasons, clan tasks, clan currency, a clan shop and officer ranks (19.54); district capture by winning gang shootouts; professions (the guide starts with police); daily and weekly tasks that pay Diamonds (premium currency); story missions (30+; 19.54 reworked missions 3, 4, 6, 7); buyable houses and real estate (12.03) | V [A5]; S [A17][A18]; R [M1][M2] |
| Monetisation | Free with in-app purchases, loot boxes ("random items") and ads. US prices: special offer $0.99, Small Box $3.99, Remove Ads $0.99; coin packs $2.99-14.99, boxes $3.99 and $9.99. **A VIP tier was not found** | V [A1]; S [A14] |
| Update cadence | Versions 10.48, 12.03, 12.07, 13.05 (July 2024), 16.09, 17.01, 17.05, 18.05, 19.54 (21 May 2026), 19.57 (1 June 2026); APK sites list 21.20-21.22 | V [A5][A6]; S [A7] |
| Engine | **Probably Unity, not verified.** SteamDB lists Unity for the sibling game MadOut Open City, and a MadOut Games job ad asks for a Unity programmer | I from S [A19] |
| Low-end phones | Third-party claim: 2 GB RAM and a Snapdragon 800 minimum, Android 4.1 or 4.4+; players report heat, lag and crashes on older phones; an object-density setting helps | S [A20][A4] |

**How ambitious it is for its team (I).** MadOut2 is an online open world with 70+ cars, guns,
houses, clans, seasons and 200-player servers, live for over 9 years on two stores, built by one
named developer that grew into a studio of perhaps 30-100 people. The ambition is in **breadth
and online systems**, not in polish: reviewers in 2025-26 still call it "alpha"-like. It shipped
early and kept growing in public.

## 2. Best features and main weaknesses

### What players praise (S unless marked)

1. **The closest thing to GTA Online on a phone.** An App Store reviewer: "probably one of the most
   similar games to GTA on iOS/Android"; Sportskeeda's Android GTA-alike lists put it first for its
   online mode and call it a "Russian version of GTA" [A21][A22].
2. **Real people in the world.** Free roam, role play, cops vs bandits and races with up to 200
   players; "the online community is fun to interact with at times" [A1][A21].
3. **Freedom and destruction.** "Freedom, and destruction, that is simply unmatched in the mobile
   space"; "no restrictions in movement or actions" [A16][A21].
4. **Driving and cars.** A "weighty, realistic driving model"; tuning that other players can see
   [A16][A21].
5. **A lot to spend on.** Weapons, cars, houses and clothes [A17].

### What players complain about (S)

1. **Ads**: the top complaint theme in one sentiment summary; ads during online play; paying does not
   always remove them [A4][A21][A23].
2. **Performance**: heat, lag and frame drops, worst on older phones [A4][A21].
3. **Bugs**: random crashes, falling through the map, cars spawning into the ground; "still looks
   and plays like an alpha version" after 8 years [A21].
4. **Controls**: "choppy" and "bad controls" [A21][A23].
5. **Pay-to-win and loot boxes** [A4][A1].
6. **Not enough variety**: players ask for more combat, crouching, and bank or shop robberies [A16].

Reddit: the searches found **no Reddit threads**, so Reddit opinion is not covered.

## 3. Why it became popular

| Mechanism | Evidence | Label |
|---|---|---|
| It filled an empty niche: "GTA Online" on a phone, free | Every GTA-alike list cites its online mode as the reason; Gangstar and the Rockstar ports are single player | S [A22]; I |
| Free to play, with both ads and purchases | Store listing; the estimated revenue is about half ads | V [A1]; S [A13] |
| Nine years of updates | Version numbers from 10.x to 21.x; clan seasons and story missions still added in 2026 | V [A5][A6] |
| Retention systems | Daily and weekly tasks, clans, seasons, district capture: reasons to log in each day | V [A5]; S [A18] |
| Search-friendly names and localisation | Renamed to "Grand Auto Racing", then "RP" titles, translated per store; "Grand Auto" catches GTA searches | V [A1]; I |
| A home market | Eastern European setting; charts in Sensor Tower's Russia top-5 crime game lists (2021, 2025) | V [A1]; S [A15] |
| Runs on modest phones (claimed) | 2 GB RAM floor claimed, but players report lag | S [A20]; I |
| Mobile, not PC | The Steam version peaked at 432 players and closed; mobile reached 100M+ | S [A11]; V [A2]; I |
| YouTube and TikTok creators | **Not verified**: no search found creator coverage or view counts | none |

**In short (I):** it was first and free in a niche players wanted badly (GTA with friends on a phone),
and it never stopped updating. Polish was never its edge.

## 4. Solvera vs MadOut2

Solvera 0.25.2 (`game/project.godot`). Built = in code now; planned = docs only.

| Area | MadOut2 | Solvera built | Solvera planned |
|---|---|---|---|
| World size | Unknown size; Eastern European city out to desert [A1][A16] | Bellerive's urban footprint of about 5.4 km² (`HANDOFF-bellerive-lv.md:132`) plus streamed country in 4,119 tiles of 100 m (about 41 km², I) within a 9.6 x 6.8 km box, with the 1,000 m Mount Calder and its roads (`game/data/country.json`, `HANDOFF-world-mountain.md`) | A 12 x 9 km state with 4 cities, 16 towns and an island expansion (`game/README.md:168`, `WORLD_V3_PLAN.md`) |
| Vehicles | 70+ cars, bikes, a tank [A1][M2] | 24 road kinds, bicycle to semi, including tuk-tuk, convertibles, police and taxi (`kits/vehicle_kit.gd:19`); 2 flyable helicopters (`helicopter.gd`, `heliports.gd`); damage, fire, wrecks | Boats, planes, trains you ride (`GANGSTAR_CONCEPT.md`) |
| People and AI | Real players; NPC depth not found | 18 pedestrians and 8 traffic cars around the player (`population.gd:12,15`) who wander, flee or fight; traffic lanes and signals; cops who deploy | Routines, ambient scenes, density by zone (`TODO.md:401`) |
| Missions and story | 30+ story missions [M1] | Missions 1-3 of 13 in act 1, with replay (`scripts/missions/`); a deep world bible (`WORLD_BIBLE.md`) | Missions 4-13, robberies, heists (`TODO.md:502`) |
| Multiplayer | Servers up to 200, 4+ modes, clans [A1][A5] | None (single player, offline) | Leaderboards, ghost races, weekly events; real-time is out of the MVP (`MVP_DESIGN.md:223-229`) |
| Economy | Coins, Diamonds, clan currency; buy cars, guns, houses [A17][A18] | Cash from missions; spend on cabs, snacks and diner meals (`taxi.gd`, `inventory.gd`, `interiors.gd`) | Businesses, property, stock market (`STOCK_MARKET_DESIGN.md`) |
| Customisation | Tuning (20 options in one update), outfits, weapon skins [A5] | NPC outfit system (`kits/character_kit.gd`); no shop, no car tuning | Clothes shops, barbers, mod garage (`INTERIORS_SERVICES_PLAN.md`) |
| Combat and police | Guns, shootouts, Cops vs Bandits, district capture [A1][A5] | Melee only (punch-kick combo, knockdown, blood); wanted levels 1-2 (`wanted.gd:6`) | 8 weapons, wanted 3-5 (`game/README.md:530-534`) |
| Graphics and performance | Players report heat, lag, crashes [A4][A21] | 4 quality presets (`graphics.gd:13`); 120 fps on a Galaxy S25 Ultra, 30 fps on a low-end phone (`game/README.md:4`); day and night, weather, fire, blood | Final art outside the Lantern Quarter |
| Camera and controls | Third person; controls called "choppy" [A16][A21] | Top-down perspective camera; drag-and-resize touch layout (`game/README.md:389`) | Full 3D camera (parked, `TODO.md:462`) |
| Interiors | Houses, shooting range (17.05) [A5] | Corner stores and diners with staff and customers (`places.gd:16`, `interiors.gd`) | About 14 place types in 6 phases |
| Activities | Races, parkour, drag, parking, cargo jobs, shooting range [A1][A5][A18] | Taxi rides (as a passenger), helicopter flights, story missions | 91-item checklist in `ACTIVITY_ROADMAP.md`; arcades, sports |
| Audio | Has audio (not researched) | **None**: no `AudioStream` in `game/scripts` | AI-generated soundtracks (`GANGSTAR_CONCEPT.md`) |
| Release | Live since 2017, 100M+ installs [A2] | Debug APK only (`game/README.md:396`) | Free to play, rewarded ads only (`MVP_DESIGN.md:240`) |

**How ambitious is Solvera compared with it? (I)** On paper, Solvera's plan is bigger in single
player depth: a multi-city state, a 13-mission act 1 with a real story, interiors, sports and arcades.
Its built world is already detailed: about 5 km² of city plus mountains and country, a 1,500-plus
check test suite (`HANDOFF-world-mountain.md`), working day and night and fire. But today Solvera is
**a strong engine and world with little to do**, while MadOut2 is **a rough world with a great deal
to do, and other people in it**. The `ACTIVITY_ROADMAP.md` tally said the same on 10-28: 13 items
built and about 60 missing out of 91.

## 5. What Solvera lacks compared with MadOut2, ranked by how much players notice it

1. **Guns and shootouts.** Every crime-game player expects them; MadOut2 builds whole modes on them.
   Solvera has melee only.
2. **Sound.** Silence is the first thing a player notices; Solvera has no audio at all.
3. **Repeatable things to do for money.** Races, jobs (taxi driver, delivery, parking), parkour.
   Solvera has 3 missions and no repeatable earning.
4. **Things to buy, own and show off.** Cars, tuning, clothes, houses. Solvera's cash has almost
   nowhere to go.
5. **A reason to come back each day.** Daily and weekly tasks, seasons, events.
6. **Other people.** Multiplayer is MadOut2's core; Solvera has no online layer, not even
   leaderboards.
7. **Volume.** 70+ cars against 24; 30+ missions against 3.
8. **Higher wanted levels.** Chases stop at 2 stars.
9. **Being in players' hands.** MadOut2 learned from 9 years of players; Solvera has had none.

What Solvera already does better, from what players say about MadOut2 (I): frame rate on low-end
phones measured in tests, no ads yet, editable controls, a real story, crash and test discipline.

## 6. Lessons: ranked recommendations (recommend only; nothing started)

Sizes are rough, in AI sessions of 3-5 hours, the unit `ACTIVITY_ROADMAP.md` uses.

| # | What | Why | Size |
|---|---|---|---|
| 1 | **Close the core loop before adding more world**: earn (repeatable jobs and races on existing roads, using the mission system) → spend (buy cars, a tuning garage, clothes shop) → show off | MadOut2's pull is "lots to do and buy"; Solvera's gap is exactly that. World size is not the problem | 8-12 sessions |
| 2 | **Guns and wanted levels 3-5** (already planned as phase 6) | The genre's minimum; MadOut2's most-used modes are shootouts | 6-8 |
| 3 | **A first audio pass**: engines, tyres, impacts, punches, ambience, UI, from CC0 or code-synthesised sounds | Cheapest large gain in feel; silence reads as unfinished | 3-5 |
| 4 | **Get it in players' hands early**: a Play closed test, then an open beta in one region, with crash reports and simple analytics | MadOut2 won by shipping rough in 2017 and improving in public; feedback beats guessing | 2-4, plus store setup |
| 5 | **Daily and weekly tasks, plus the "light online" of `MVP_DESIGN.md`**: leaderboards, ghost races, weekly events | Gives the daily return reason MadOut2 gets from tasks and clan seasons, without servers | 3-5, plus a small backend |
| 6 | **Make MadOut2's weaknesses our selling points**: rewarded ads only (already decided), a low-end frame-rate gate on a real cheap phone, no fall-through bugs, good controls | Its top complaints are ads, heat and lag, bugs and controls; players actively look for an alternative | ongoing; gates already exist |
| 7 | **Store presence**: a title and description with the words players search for (open world, crime, cars, city), localised listings, a short trailer and photo mode for creators | MadOut2 renamed itself toward search terms and localised every store; creator reach is unverified but cheap to enable | 1-2, plus art |
| 8 | **Real-time multiplayer only after the single-player loop works**, and only as a separate decision | It is MadOut2's core but needs servers, anti-cheat and moderation; months of work, not sessions (I) | very large; not now |

**Cheaper option to switch to:** if only one step is taken, do 3 (audio) and the "earn" half of 1
(street races and one job). That is about 6-8 sessions and fixes the two gaps a first-time player
meets in the first five minutes.

## 7. Sources

All were seen only as WebSearch summaries (section 0).

- [A1] App Store listing, id1214765807: https://apps.apple.com/us/app/madout-2-grand-auto-racing/id1214765807 ·
  regional: https://apps.apple.com/tw/app/id1214765807 · https://apps.apple.com/DE/app/id1214765807
- [A2] Google Play listing (quoted in a search summary, not opened; blocked host):
  https://play.google.com/store/apps/details?id=com.MadOut.BIG
- [A3] AppBrain developer page: https://www.appbrain.com/dev/MadOut+Games+LLC+FZ/
- [A4] AppiReview: https://appireview.pages.dev/com.MadOut.BIG
- [A5] APKMirror, 19.54 notes and older builds: https://www.apkmirror.com/apk/madout-games-llc-fz/madout2-big-city-online/ ·
  https://www.apkmirror.com/?p=10710295 (17.05) ·
  https://apkmirror.com/apk/ivanchuk-vladislav/madout2-big-city-online/madout2-big-city-online-12-07-release
- [A6] APKMirror 18.05 and 16.09: https://www.apkmirror.com/apk/ivanchuk-vladislav/madout2-big-city-online/madout2-big-city-online-18-05-release/ ·
  https://www.apkmirror.com/apk/ivanchuk-vladislav/madout2-big-city-online/madout2-big-city-online-16-09-release/
- [A7] Grand-screen: https://grand-screen.com/games/madout-2-grand-auto-racing/ · Uptodown:
  https://madout2-bigcityonline.en.uptodown.com/android · apkvision: https://apkvision.org/games/action/madout2-bigcityonline-apk-16656/
- [A8] TouchArcade thread: https://toucharcade.com/community/threads/madout2-bigcityonline-by-vladislav-ivanchuk.305473/
- [A9] MadOut on Steam (2015): https://store.steampowered.com/app/352170 · https://steamspy.com/app/352170
- [A10] MadOut2 BigCityOnline [CLOSED]: https://www.wasdland.com/game/madout2-bigcityonline-closed-586980/ ·
  https://steambase.io/games/madout2-bigcityonline-closed/steam-charts
- [A11] Steam Charts: https://steamcharts.com/app/586980
- [A12] Prospeo company page: https://prospeo.io/c/madout-games-revenue
- [A13] AppGoblin: https://appgoblin.info/apps/1214765807 (WebFetch blocked; search summary only)
- [A14] Adapty paywall library: https://adapty.io/paywall-library/madout2-big-city-online/
- [A15] Sensor Tower, Russia top-5 crime games: https://sensortower.com/blog/2025-q2-ios-top-5-crime%20games-units-ru-6011691c241bc16eb88b4dc2 ·
  https://sensortower.com/blog/2021-q2-ios-top-5-crime%20games-units-ru-6011691c241bc16eb88b4dc2
- [A16] Editors' and listing summaries: https://app.fanli.com/app/madout-2 · https://vgtimes.com/games/madout-2-bigcityonline/ ·
  https://www.taptap.io/post/7923404
- [A17] BlueStacks beginner guide (RU, EN): https://www.bluestacks.com/ru/blog/game-guides/madout2-big-city-online/mdo-beginners-guide-ru.html ·
  https://www.bluestacks.com/blog/game-guides/madout2-big-city-online/mdo-beginners-guide-en.html
- [A18] BlueStacks tips and professions guides: https://www.bluestacks.com/blog/game-guides/madout2-big-city-online/mdo-tips-tricks-en.html ·
  https://www.bluestacks.com/ru/blog/game-guides/madout2-big-city-online/mdo-professions-guide-ru.html
- [A19] SteamDB, MadOut Open City (Unity): https://steamdb.info/app/428190/charts · job ad:
  https://quick-offer.ru/job/senior-unity-programmer-54139
- [A20] Requirements claims: https://apkvision.org/games/action/madout2-bigcityonline-16656/ ·
  https://filehippo.com/android/download_madout2-bigcityonline/
- [A21] Player reviews: https://apps.apple.com/app/1214765807 · https://www.taptap.io/app/48850 ·
  https://www.taptap.io/post/7923404
- [A22] Sportskeeda GTA-alike lists: https://sportskeeda.com/gta/5-best-offline-games-like-gta-5-google-play-store-2021 ·
  https://sportskeeda.com/esports/5-best-open-world-android-games-like-gta
- [A23] Japanese review roundup: https://appmatch.jp/1214765807-3/
- [M1]-[M3]: see `ACTIVITY_ROADMAP.md` lines 362-372.

**Could not verify:** map size and number of cities; team size (sources conflict); the engine;
an official minimum device; a VIP or subscription tier; per-country downloads beyond Russia iOS;
lifetime revenue; YouTube, TikTok or Reddit influence; whether the 100M+ figure counts unique users
or installs.
