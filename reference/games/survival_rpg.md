# Survival RPG (Bew Games): game dossier

Part of the [Top-down games reference bible](../README.md). Same 16 numbered sections as every other dossier, so `#7-combat-and-weapons` (for example) works in each file.

*Research for "Solvera" (top-down 3/4 open-world crime game, Godot, Android/iOS). Compiled 2026-10-26.*

**How this was researched, and its limits.** WebFetch failed with DNS errors on every domain tried (Google Play, App Store, fandom, BlueStacks, marlvel.ai), and the shared web-search budget ran out after about 35 searches. Everything below therefore comes from search-engine summaries of primary pages (store listings, Steam, the community wiki, AppBrain, review sites), not from reading those pages directly. Every figure has a URL next to it. Anything I could not confirm is marked **unverified**. Inferences are labelled as inferences. Screen-level details such as tile size, HUD layout and camera zoom could not be checked from text sources. The official "Full gameplay" YouTube playlists linked in section 2 are the best next step for those.

---

## 1. Overview and facts

**Identifying the game.** "Survival RPG" is a series of 2D pixel-art survival-adventure RPGs from **Bew Games inc.** (sometimes styled "BEW Games") on Android, iOS and, later, PC. Sources: [Google Play developer page](https://play.google.com/store/apps/dev?id=6670339010912734522&hl=en), [AppBrain developer page](https://www.appbrain.com/dev/Bew+Games+inc./), [bewgames.com](https://bewgames.com/).

**Developer and team.**

- The community wiki credits the games to "Bew Games (Eric Bouchard)" ([wiki: SRPG 5](https://survival-rpg-games.fandom.com/wiki/Survival_RPG_5), [wiki: SRPG 1](https://survival-rpg-games.fandom.com/wiki/Survival_RPG_1)).
- A ZoomInfo profile lists Eric Bouchard as President of Bew Games, with earlier roles at Ubisoft, Gameloft and Microids and as Director of Software Development at Sherpa ([ZoomInfo](https://www.zoominfo.com/p/Eric-Bouchard/10497751335)). This comes from an aggregator and is **unverified**. If it is true, it is a link to Gameloft, the publisher of Gangstar.
- On LinkedIn, Bouchard says the third game took "10 mois" (10 months) of work and that *Survival RPG: Open World* shipped "after more than one year of development" ([LinkedIn](https://www.linkedin.com/in/eric-bouchard-88b8953/), via search summary).
- **Team size has not been published.** The single-person credit and the 10–12-month cycles suggest a solo developer or a very small team (inference). The French wording and the "Bouchard" name hint at a Québec base (inference, **unverified**).

**Series entries** (fan wiki ordering: [Survival RPG Games Wiki](https://survival-rpg-games.fandom.com/wiki/Survival_RPG_Games_Wiki)):

| # | Title(s) seen in stores | Package / ID | Mobile release | PC (Steam) |
|---|---|---|---|---|
| 1 | Survival RPG 1: Lost Treasure (also "Island Escape", "Treasure Hunt", "Treasure Island", "Dungeon Quest") | com.bewgames.survivaladventure / iOS id1228652601 | iOS first released May 8, 2017 ([mwm.ai](https://mwm.ai/apps/survival-rpg-1-lost-treasure/1228652601)); wiki says May 7, 2017 ([wiki](https://survival-rpg-games.fandom.com/wiki/Survival_RPG_1)) | Jan 9, 2021, $4.99 ([Steam](https://store.steampowered.com/app/1480050/Survival_RPG_The_Lost_Treasure/)) |
| 2 | Survival RPG 2: Temple Ruins 2D (also "Ruins of Lost Temple", "Epic Adventure") | com.bewgames.templeruins / iOS id1330199727 | On Google Play since April 2019 ([AppBrain](https://www.appbrain.com/app/survival-rpg-2-temple-ruins-2d/com.bewgames.templeruins)); Apr 10, 2019 ([napkforpc](https://napkforpc.com/apk/com.bewgames.templeruins/)) | Jan 28, 2021 ([Steam](https://store.steampowered.com/app/1491180/Survival_RPG_2_The_Temple_Ruins/)) |
| 3 | Survival RPG 3: Lost in Time 2D (also "Time Travel 2D") | com.bewgames.lostintime | Oct 9, 2020 (wiki, via search summary) | Feb 19, 2021 ([Steam](https://store.steampowered.com/app/1491190/Survival_RPG_3_Lost_in_Time/)) |
| — | Survival RPG: Open World Pixel (Android) / Open World Craft (iOS) | com.bewgames.openworld / iOS id1583465544 | On Google Play from about Jan 2022 ([AppBrain](https://www.appbrain.com/app/survival-rpg-open-world-pixel/com.bewgames.openworld), via search summary) | Google Play Games PC ([GP PC](https://play.google.com/pc-store/games/details?id=com.bewgames.openworld)) |
| 4 | Survival RPG 4: Haunted Manor (also "Haunted House", "Ghost Mystery") | com.bewgames.hauntedmanor / iOS id1624256421 | Aug 23, 2023 ([wiki](https://survival-rpg-games.fandom.com/wiki/Survival_RPG_4), [TapTap](https://www.taptap.io/app/33601245)); TapTap announcements give iOS Aug 24 and Android Aug 28, 2023 | — |
| 5 | Survival RPG 5 / Survival RPG: Pirate Adventure | com.bewgames.pirate / iOS id6468485843 | May 5, 2025 ([wiki](https://survival-rpg-games.fandom.com/wiki/Survival_RPG_5)) | Google Play Games PC ([GP PC](https://play.google.com/pc-store/games/details?id=com.bewgames.pirate&hl=en_SG)) |

There is also a "Survival RPG Complete Bundle" on PC ([gg.deals](https://gg.deals/games/published-by-bew-games/)).

**Ambiguity.**

1. The user's example "Survival RPG: Open World Pixel" is a real title, but it is an **unnumbered spin-off** that sits between #3 and #4 in the series, not a main entry.
2. Each game has had many store titles. The iOS listing for #1 has appeared as "Lost Treasure", "Treasure hunt", "Treasure Island" and "Dungeon Quest" ([App Store variants](https://apps.apple.com/us/app/survival-rpg-1-treasure-hunt/id1228652601), [AO](https://apps.apple.com/ao/app/survival-rpg-1-treasure-island/id1228652601), [AE](https://apps.apple.com/ae/app/survival-rpg-1-dungeon-quest/id1228652601)). AppBrain's URL slugs keep older names such as "island-escape" ([AppBrain](https://www.appbrain.com/app/survival-rpg-1-island-escape/com.bewgames.survivaladventure)).
3. Other games also use "Survival RPG" in their names, for example *Mutiny: Pirate Survival RPG* (Helio Games) and *Lost Island: Survival & RPG*. They are unrelated.
4. Each PC version is a separate product from its mobile version.

**Most popular entry: Survival RPG 1: Lost Treasure.** AppBrain calls it the developer's most popular app, with 5M+ installs on Google Play ([AppBrain dev](https://www.appbrain.com/dev/Bew+Games+inc./)).

**Downloads, ratings and revenue**

| Title | Google Play tier | AppBrain estimate | Ratings |
|---|---|---|---|
| SRPG 1 | 5M+ | ~9.6M lifetime; ~14–20K in the last 30 days ([AppBrain](https://www.appbrain.com/app/survival-rpg-1-island-escape/com.bewgames.survivaladventure)) | 4.56 from ~180K (AppBrain); GP ~4.6 from ~210K (search summary); iOS 4.6 from ~2.5K ([App Store](https://apps.apple.com/us/app/-/id1228652601)); Steam 90% positive of 32 |
| SRPG 2 | 1M+ | ~4.2M lifetime; 190K in the last 30 days at crawl time ([AppBrain](https://www.appbrain.com/app/survival-rpg-2-temple-ruins-2d/com.bewgames.templeruins)) | iOS ~4.6 from ~1.7K ([App Store](https://apps.apple.com/us/app/survival-rpg-2-temple-ruins-2d/id1330199727)); ~4.4 from ~109K (apk-combo, a third party) |
| SRPG 3 | 1M+ ([Google Play](https://play.google.com/store/apps/details?id=com.bewgames.lostintime&hl=en_US), via search summary) | n/a | n/a |
| Open World | 1M+ | ~1.6M; ~13K in the last 30 days ([AppBrain](https://www.appbrain.com/app/survival-rpg-open-world-pixel/com.bewgames.openworld)) | GP ~4.6 from ~32–35K reviews |
| SRPG 4 | not found (**unverified**) | not found | GP 4.5 from ~23.1K; iOS 4.6 from ~566 ([App Store](https://apps.apple.com/us/app/survival-rpg-4-haunted-manor/id1624256421)) |
| SRPG 5 | 100K+ (search summary) | ~57K at an older crawl ([AppBrain](https://www.appbrain.com/app/survival-rpg-pirate-adventure/com.bewgames.pirate)) | 4.55 from ~5K (AppBrain); iOS 4.9 from 208 ([App Store](https://apps.apple.com/us/app/survival-rpg-pirate-adventure/id6468485843)) |

- **Portfolio totals.** AppBrain lists 6 apps, active since 2017, about 20M installs (about 900K in the last 30 days) and an average rating of 4.57 from about 390K ratings ([AppBrain dev](https://www.appbrain.com/dev/Bew+Games+inc./)). The studio's own site claims "18M+ players" ([bewgames.com](https://bewgames.com/)).
- **Revenue.** No public figure exists. data.ai's estimate for SRPG 1 in the US App Store was under 5K downloads and under $5K revenue for the previous month ([data.ai](https://data.ai/en/apps/ios/app/survival-rpg-the-lost-treasure)). games-stats estimates about $2,600 lifetime for the Steam version of SRPG 1, with no period stated ([games-stats](https://games-stats.com/steam/game/survival-rpg-the-lost-treasure/)). AppMagic has a publisher page whose figures I could not read ([AppMagic](https://appmagic.rocks/publisher/bew-games-inc-/1_6670339010912734522/?hl=en)). Any revenue number for the series is **unverified**.
- **Business model.** Free to play, with ads, IAP and a paid "Remove Ads" option. The PC versions are premium ($4.99 for SRPG 1 on Steam, historical low $1.49, per [gg.deals](https://gg.deals/game/survival-rpg-the-lost-treasure/)). See section 12.
- **Content rating.** "Everyone", Mild Fantasy Violence (Open World on Google Play, via search summary). The App Store age rating is 9+ ([PL listing](https://apps.apple.com/pl/app/survival-rpg-1-treasure-island/id1228652601)).

**Engine and tech: unverified.** I found no evidence of the engine in any listing, on SteamDB (no page came back) or on AppBrain (its "technologies" section was not in the snippet). AppBrain counts 16 libraries in Open World ([AppBrain](https://www.appbrain.com/app/survival-rpg-open-world-pixel/com.bewgames.openworld)). Unpacking an APK and looking for `libunity.so` or a Godot `.pck` file would answer the question.

---

## 2. Camera and visual presentation

- **View.** The series is described as "retro, top-down 2D pixel-art" (Steam store and SteamSpy, via search summary: [Steam](https://store.steampowered.com/app/1480050/Survival_RPG_The_Lost_Treasure/)), and as "a nostalgic pixel art world" on Google Play ([GP](https://play.google.com/store/apps/details?id=com.bewgames.survivaladventure&hl=en)). Text sources do not say whether the view is straight overhead or a 3/4 "JRPG" view; this is **unverified**. Store screenshots described in search results show a ship near a shoreline next to a dungeon entrance, which fits a SNES-era top-down 3/4 view (inference).
- **Lighting carries the gameplay.**
    - **Day and night.** One reviewer says the lighting stays "monotone, until 9 at night when it suddenly dims into nightfall, and you're surrounded by snakes" (Google Play review, via [search summary](https://play.google.com/store/apps/details?id=com.bewgames.survivaladventure&hl=en)). In a top-down 2D game, night is mostly a tint plus a change in which enemies spawn. That is cheap to build and reads clearly.
    - **Darkness as a gate.** You must craft a candle to explore dark dungeons ([App Store](https://apps.apple.com/us/app/survival-rpg-1-lost-treasure/id1228652601)). A light radius in a top-down view becomes both a gate and a source of tension.
- **World map with fog of war.** Steam players report a bug where opening the world map inside a cave or hut "reveals the whole map as if explored" ([Steam discussions](https://steamcommunity.com/app/1480050/discussions/)). This shows that the overworld map uses discovered-area fog and that interiors are separate scenes.
- **Remaster.** SRPG 1 version 7.1.0 (Jan 2024) was billed as the "Remastered version", with "a new interface and renewed graphics" ([App Store NZ](https://apps.apple.com/nz/app/survival-rpg-1-lost-treasure/id1228652601)). The developer has kept refreshing a 2017 game's presentation rather than leaving it.
- **Criticism of the look.** Some players dislike the retro presentation (Open World review, via search summary: [GP](https://play.google.com/store/apps/details?id=com.bewgames.openworld&hl=en_US)). Others praise the art style (SRPG 2 reviews).
- **UI and HUD.** Confirmed: an on-screen d-pad or "360-degree" stick, a single context **action button** (attack, collect, place objects) and a close-menu control ([GamePretty key mapping](https://gamepretty.com/survival-rpg-the-lost-treasure-key-mapping/); GP review). One iPad user said the d-pad sits "too far into the screen" ([App Store review](https://apps.apple.com/us/app/survival-rpg-1-lost-treasure/id1228652601)). The layout of health, hunger and inventory bars is **unverified**. Watch the official full-gameplay playlists for those details: [SRPG 1](https://www.youtube.com/playlist?list=PLQtdLq7Ck37XDj97OVGY9iisRvrzrsbne), [SRPG 2](https://www.youtube.com/playlist?list=PLQtdLq7Ck37W_TIvMyw3LaLWSMJWraeY3), [SRPG 3](https://www.youtube.com/playlist?list=PLQtdLq7Ck37V2vMTD-DHFcqzuCPms05dW), [SRPG 4](https://www.youtube.com/playlist?list=PLQtdLq7Ck37X7BkAYpxzkNjx8ehnoI_Oa).

---

## 3. Core gameplay loops

- **Moment to moment.** Walk with the d-pad and press one context button to gather, mine, attack or place, while avoiding or fighting creatures. The single verb keeps touch input simple. Reviewers of SRPG 4 notice when that button feels less responsive ([search summary of GP reviews](https://play.google.com/store/apps/details?id=com.bewgames.hauntedmanor&hl=en_US)), which shows how central it is.
- **Session loop.** Gather and forage, return to the shelter to craft, use the new tool to open a new area or puzzle, then find the next recipe or item.
    - SRPG 1 has "more than 70 items" and "40 crafting recipes" ([search summary of GP/App Store](https://apps.apple.com/us/app/-/id1228652601)).
    - SRPG 2 has 70 recipes ([App Store](https://apps.apple.com/us/app/survival-rpg-2-temple-ruins-2d/id1330199727)).
    - SRPG 3 has 220+ items and 85 recipes ([AppBrain](https://www.appbrain.com/app/survival-rpg-3:-lost-in-time-adventure-retro-2d/com.bewgames.lostintime)).
- **Long-term loop.** Reach the finite story goal: the treasure, the artifact, or solving the timeline. The games are designed to be finished, not played forever.
    - One listing estimates about 6 hours for SRPG 1. Players report anywhere from under 24 hours to 44 hours (AppBrain comments and listings, via [search summary](https://www.appbrain.com/app/survival-rpg:-lost-treasure-adventure-retro-2d/com.bewgames.survivaladventure)).
    - Replay comes from ranks based on completion time, a hardcore mode and a permanent attack/defense bonus for finishing (SRPG 1 v8.0.x, [App Store](https://apps.apple.com/us/app/survival-rpg-1-treasure-hunt/id1228652601)).
    - The Open World spin-off moves the loop toward sandbox play: home decoration, choosing a world type, and ongoing quests ([GP](https://play.google.com/store/apps/details?id=com.bewgames.openworld&hl=en_US)).
- **No XP levels.** One reviewer liked that pacing "doesn't rely on 'leveling up'"; power comes from crafted gear (search summary of reviews, [GP](https://play.google.com/store/apps/details?id=com.bewgames.survivaladventure&hl=en_IN)).

---

## 4. World building and regions

- **SRPG 1: an archipelago.** "Exploration of multiple islands with dungeons, caverns and dark forests" ([Steam](https://store.steampowered.com/app/1480050/Survival_RPG_The_Lost_Treasure/)). Known features include a mountain near the starting shelter, a spider cave with a lava floor, a sulfur island almost exactly due south, and a gold cave behind a cracked wall ([ChapterCheats Q&A](https://www.chaptercheats.com/qna/iphone-ipod/385586/survival-rpg-the-lost-treasure-answers/212352), [compass Q&A](https://www.chaptercheats.com/qna/iphone-ipod/385586/survival-rpg-the-lost-treasure-answers/182741)).
- **Gating is classic "Metroidvania-lite".** Each gate needs a tool or item:
    - **Ladders.** Three are needed: two for the mountain and one for the cave ([ChapterCheats](https://www.chaptercheats.com/qna/iphone-ipod/385586/survival-rpg-the-lost-treasure-answers/182741)).
    - **Canoe.** Lets you travel "farther south" to the sulfur island.
    - **Compass.** Needed to navigate there.
    - **Sulfur.** Leads to sulfuric acid and then explosives. Two explosives are needed in the whole game, for cracked walls ([ChapterCheats](https://www.chaptercheats.com/qna/iphone-ipod/385586/survival-rpg-the-lost-treasure-answers/212352)).
    - **Candle.** Opens dark dungeons ([App Store](https://apps.apple.com/us/app/survival-rpg-1-lost-treasure/id1228652601)).
    - **Lava.** A lava floor must be crossed, and how to do it is unclear to some players ([Steam discussions](https://steamcommunity.com/app/1480050/discussions/)).
- **Secrets.**
    - Hidden resources need a metal detector ([wiki items](https://survival-rpg-games.fandom.com/wiki/Items_(SRPG1))).
    - Treasure maps point to hidden treasure ([Steam](https://store.steampowered.com/app/1480050/Survival_RPG_The_Lost_Treasure/)).
    - Batteries are found by using your treasure map ([wiki](https://survival-rpg-games.fandom.com/wiki/Items_(SRPG1))).
    - Puzzles unlock hidden treasures ([GP](https://play.google.com/store/apps/details?id=com.bewgames.survivaladventure&hl=en_US)).
- **Later entries grow in scale.**
    - SRPG 2 has "more than 30 dungeons, caverns, jungles, ships, temples and huts" ([App Store](https://apps.apple.com/us/app/-/id1330199727)).
    - SRPG 3 has "more than 50 dungeons, caves, castles and fortresses" across three eras: Medieval, Jurassic and Future ([AppBrain](https://www.appbrain.com/app/survival-rpg-3:-lost-in-time-adventure-retro-2d/com.bewgames.lostintime)).
    - SRPG 4 has a manor and nearby areas, with **time-travel gates** that switch between two eras of the same map to reach otherwise blocked areas ([rpg-site](https://rpg-site.com/2025/09/10/survival-rpg-4-haunted-manor/)). This reuses one map twice as content.
- **Open World.**
    - Players choose "a mountain world, an island world or both" ([GP](https://play.google.com/store/apps/details?id=com.bewgames.openworld)).
    - Biomes include islands, deserts, jungles and oceans, with bridges crafted to reach them, plus caves, dungeons, medieval castles and temples.
    - A ship crosses the ocean, which has sea monsters such as sharks ([App Store](https://apps.apple.com/us/app/survival-rpg-open-world-craft/id1583465544)).
    - One mod-APK site calls the world "randomly generated" ([LiteAPKs](https://liteapks.com/survival-rpg-open-world-pixel.html)). This is **unverified**, and the official listings say nothing about procedural generation.
- **SRPG 5.** The ocean, islands, a pirate ship, dungeons and caves ([GP](https://play.google.com/store/apps/details?id=com.bewgames.pirate)).

---

## 5. Story and narrative progression

- **Premises.** Each entry has a simple hook stated in a single line:
    - **SRPG 1.** While seeking a treasure, a storm strands you on "a pristine island"; you must find the lost treasure and return home ([wiki](https://survival-rpg-games.fandom.com/wiki/Survival_RPG_1)). The App Store hook asks whether "the island's secrets trap you forever" ([App Store](https://apps.apple.com/us/app/survival-rpg-1-lost-treasure/id1228652601)). Whether there are multiple endings is **unverified**.
    - **SRPG 2.** "Rumors of a magical artifact that lies among the temple ruins" lead you to a jungle temple, across 7 story chapters ([Steam](https://store.steampowered.com/app/1491180/Survival_RPG_2_The_Temple_Ruins/)).
    - **SRPG 3.** Something is disrupting the timeline; you teleport between eras over 7 chapters in 3 timelines ([AppBrain](https://www.appbrain.com/app/survival-rpg-3:-lost-in-time-adventure-retro-2d/com.bewgames.lostintime)).
    - **SRPG 4.** "The story begins with the mysterious disappearance of your magical artifact." It has 7 chapters and is pitched as concluding the series' mystery ([App Store](https://apps.apple.com/us/app/survival-rpg-4-haunted-manor/id1624256421), [rpg-site](https://rpg-site.com/2025/09/10/survival-rpg-4-haunted-manor/)).
    - **SRPG 5.** You wake on an unknown island with no memory and must unite three pirate clans led by rival brothers who have hunted a legendary treasure for decades ([GP](https://play.google.com/store/apps/details?id=com.bewgames.pirate)).
- **How the story is told.** Chapter structure plus quests from NPCs (SRPG 4, 5 and Open World listings). Reviewers praise "the plot and characters" in SRPG 4 (GP reviews via search summary). Named characters and cutscene style are **unverified**.
- **Tone.** Light, adventurous, family-friendly ("Everyone" rating). The pitches recall 80s adventure films. SRPG 4 adds a gentle ghost-mystery flavour.
- **Through-line.** The artifact links SRPG 2 to 4, which gives the series a meta-narrative and a reason to cross-sell sequels.

---

## 6. Missions and quests design

- **Linear goal chains.** One reviewer calls SRPG 1 "very linear", with new recipes unlocked only after set goals (search summary, [GP](https://play.google.com/store/apps/details?id=com.bewgames.survivaladventure&hl=en_IN)). Quests mostly take the form "find or build X to open Y" (see the gates in section 4).
- **NPC quests** appear in later entries. "Quests from numerous NPCs" (SRPG 5) and "several quests offered by RPG characters" (Open World) ([App Store SRPG5](https://apps.apple.com/us/app/survival-rpg-pirate-adventure/id6468485843), [App Store OW](https://apps.apple.com/us/app/survival-rpg-open-world-craft/id1583465544)).
- **Puzzles for rare loot.** "Puzzles for rare loot" (SRPG 5). An App Store reviewer of SRPG 1 praised the puzzles (search summary).
- **Hints.** SRPG 4 has an in-game hint system that unlocks each hint after "a couple of ads" ([rpg-site](https://rpg-site.com/2025/09/10/survival-rpg-4-haunted-manor/)). The community wiki also keeps FAQ and hint pages ([wiki](https://survival-rpg-games.fandom.com/wiki/FAQs/_Hints_(Haunted_Manor))). Hints are needed because progress depends on specific items.
- **Failure modes.**
    - **Soft-locks from finite resources.** Ore is limited, so crafting too much early can leave a player unable to finish ([App Store review](https://apps.apple.com/us/app/survival-rpg-1-lost-treasure/id1228652601), via search summary).
    - **Stalls.** One SRPG 2 player was stuck at 67.8% completion ([App Store](https://apps.apple.com/us/app/survival-rpg-2-temple-ruins-2d/id1330199727)).
    - **Unclear solutions.** Players were confused about the lava crossing (Steam).
    - **Unfindable bosses.** A player could not find the ogre and shark bosses again (App Store review).

---

## 7. Combat and weapons

- **Basic combat.** Action-button melee against roaming creatures. "You will have to fight monsters ... craft tools, weapons and armors" ([Steam](https://store.steampowered.com/app/1480050/Survival_RPG_The_Lost_Treasure/)).
- **Weapons widen over the series.** SRPG 5 rotates between "swords, spells and bows", has several arrow types, and a Wooden Sword recipe of 8 tree branches, 12 pine logs, 5 vines and 8 pebbles ([wiki equipment](https://survival-rpg-games.fandom.com/wiki/Equipment_(Pirate_Adventure))). Open World has crafted armor and swords ([GP](https://play.google.com/store/apps/details?id=com.bewgames.openworld)).
- **Upgrade path.** Upgrades are material tiers through crafting: wood, then mined metals, then smelted metals in a furnace (Open World furnace: 20 rock, 8 clay, 3 fire). Fire itself is 4 tree branches, 3 pebbles and 2 lichen ([wiki crafting](https://survival-rpg-games.fandom.com/wiki/Crafting_(Open_world))). There are no XP levels.
- **Enemies.**
    - SRPG 1: snakes at night (GP review), spiders (spider cave).
    - SRPG 2: 35+ monsters and bosses ([App Store](https://apps.apple.com/us/app/survival-rpg-2-temple-ruins-2d/id1330199727)).
    - SRPG 3: 40+ monsters, including dinosaurs and dragons ([AppBrain](https://www.appbrain.com/app/survival-rpg-3:-lost-in-time-adventure-retro-2d/com.bewgames.lostintime)).
    - SRPG 4: ghosts ([search summary](https://rpg-site.com/2025/09/10/survival-rpg-4-haunted-manor/)).
    - Open World: sharks and other sea monsters.
- **Bosses.** SRPG 1 has an ogre boss, a shark boss (reward: "Dead shark") and a final boss (reward: a chest) ([wiki items](https://survival-rpg-games.fandom.com/wiki/Items_(SRPG1)); App Store review). In SRPG 5, some reviewers found "a couple of bosses" too demanding ([App Store](https://apps.apple.com/us/app/survival-rpg-pirate-adventure/id6468485843)).
- **Death.** Originally "nothing is lost when you die" (SRPG 1 review). An optional hardcore permadeath mode came later ([App Store](https://apps.apple.com/us/app/survival-rpg-1-treasure-hunt/id1228652601)). Night is dangerous early on and manageable once you are stronger.

---

## 8. Progression and upgrades

- **Crafting is the progression system.** Players most often praise it as "satisfying" (search summary of reviews). New recipes unlock from story goals, not a skill tree.
- **Stations and buildings.** Open World includes Campfire, Chemistry Table, Fireplace, Leatherworking Bench (8 pine logs, 1 bear fur, 3 rope), Oven and Furnace ([wiki tools](https://survival-rpg-games.fandom.com/wiki/Tools_(open_world))). Its listings also mention shelters, home decoration, bridges and the ship ([GP](https://play.google.com/store/apps/details?id=com.bewgames.openworld&hl=en_US)). SRPG 2 mentions farming ([App Store](https://apps.apple.com/us/app/survival-rpg-2-temple-ruins-2d/id1330199727)).
- **Survival needs.** Food foraging is confirmed. Water is confirmed in Open World ("find food and water"). Separate thirst or energy meters in SRPG 1 are **unverified**.
- **Economy.** There are two currencies: gathered materials and premium **diamonds**. Diamonds can **replace missing resources**. One SRPG 4 player complained that the diamond cost of resources became "triple what it used to be" ([search summary](https://play.google.com/store/apps/details?id=com.bewgames.hauntedmanor&hl=en_US)).
- **Pacing problems.** The main complaint across entries is grind.
    - SRPG 1: you "may need to grind for materials and food".
    - SRPG 2: "too many resources needed"; players must revisit areas ([AppGamer](https://www.appgamer.com/survival-rpg-2-temple-ruins-adventure-retro-2d/)).
    - SRPG 5: becomes "overly grindy about 60% of the way through" ([GP](https://play.google.com/store/apps/details?id=com.bewgames.pirate&hl=en_US)).
    - Open World: "a little overwhelming due to all the crafting options".
    - Inference: the grind and the diamond shortcut are linked by design.
- **Gating.** Progression is gated by items, never by timers. I found no evidence of energy timers in any entry.

---

## 9. Vehicles, mounts, movement and physics

- **Boats are the vehicle gate in nearly every entry.**
    - SRPG 1: a **canoe** extends your range south ([ChapterCheats](https://www.chaptercheats.com/qna/iphone-ipod/385586/survival-rpg-the-lost-treasure-answers/212352)), with a compass for navigation.
    - Open World: build "a ship to conquer the ocean and fight sea monsters" ([App Store](https://apps.apple.com/us/app/survival-rpg-open-world-craft/id1583465544)).
    - SRPG 2: ships appear as explorable locations.
    - SRPG 5: a pirate ship is a location ([GP](https://play.google.com/store/apps/details?id=com.bewgames.pirate)). Whether the player builds one is **unverified**.
- **Traversal tools.** Ladders, bridges, rope and a rock pulley ([wiki crafting](https://survival-rpg-games.fandom.com/wiki/Crafting_(Open_world))), explosives, and time-travel gates in SRPG 4.
- **Mounts.** No mounts or horses were found in any source.
- **Physics.** Simple tile-based, top-down movement. No physics-driven vehicles were reported. Boat handling details are **unverified**.

---

## 10. Things to do and activities

- **Activities.**
    - Gathering, mining (with a metal detector for hidden deposits), foraging and **fishing** (there is a "Fishing fly" IAP: [App Store](https://apps.apple.com/us/app/survival-rpg-1-lost-treasure/id1228652601)).
    - Farming (SRPG 2).
    - Treasure-map hunts, puzzles, dungeon crawling and boss fights.
    - NPC quests (later entries), home decoration (Open World), sea combat (Open World) and time-era hopping (SRPG 3 and 4).
- **Meta activities** (SRPG 1, 2025–26 updates): achievements, a completion-time score and rank, hardcore mode and cloud saves ([App Store](https://apps.apple.com/us/app/survival-rpg-1-treasure-hunt/id1228652601)).
- **Density.** The scale numbers (30+ / 50+ dungeons, 70–220 items) suggest dense, hand-placed points of interest (inference). One App Store reviewer of SRPG 5 says that "when bored, an achievement, ability, or new activity appears" ([App Store](https://apps.apple.com/us/app/survival-rpg-pirate-adventure/id6468485843)).

---

## 11. Player hooks and retention

- **Hooks.**
    - A strong one-line mystery ("find the lost treasure", "the artifact disappeared").
    - Constant small unlocks: a new tool opens new ground.
    - The castaway fantasy with a finite, beatable goal.
    - Offline play: "play offline with no internet connection needed" (store listings).
    - "Easy to pick up and put down" (App Store review of SRPG 5).
- **Series as retention.** The real retention engine is a **chain of finite games** rather than live ops. Each entry promotes the next, and the artifact plot spans SRPG 2–4. The developer's portfolio of 6 apps collects about 900K installs a month (AppBrain dev), though the split between titles is unknown.
- **Long-tail updates.** SRPG 1 was still being updated in 2026 (v9.x, May 2026), nine years after launch ([App Store CA](https://apps.apple.com/ca/app/survival-rpg-1-lost-treasure/id1228652601)). The updates add replay systems (ranks, hardcore, achievements) rather than new story.
- **Weakness.** After the credits there is little reason to keep playing besides speedrun ranks and hardcore mode. Open World is the developer's attempt at an endless format.

---

## 12. Monetization and mistakes

**Model.** Free download, with ads, consumable diamond IAP and a "Remove Ads" IAP.

**Prices on the SRPG 1 US App Store (2026 listing, [App Store](https://apps.apple.com/us/app/survival-rpg-1-lost-treasure/id1228652601), via search summary):**

| Item | Price |
|---|---|
| Remove Ads | $2.99 (was $0.99 in the 2023 listing) |
| 200 diamonds | $3.99 |
| 550 diamonds | $6.99 (was $4.99 in 2023) |
| 1000 diamonds | $9.99 (was $6.99 in 2023) |
| Explorer Bundle | $12.99 |
| Fishing fly | $3.99 |

SRPG 4 uses the same diamond tiers ([App Store](https://apps.apple.com/us/app/survival-rpg-4-haunted-manor/id1624256421)).

**Ad placement.**

- Interstitials play on **area transitions**. One reviewer says they appear "only when transitioning between areas" and that a built-in ad can run about 30 seconds (GP review, via search summary).
- Rewarded ads unlock hints (SRPG 4).
- Open World reviewers complain of "random ads" popping up ([GP](https://play.google.com/store/apps/details?id=com.bewgames.openworld&hl=en_US)).
- On the positive side, SRPG 4 reviewers say "the few ads are also not annoying" and players do not call the games pay to win: "reasonably priced items are not necessary to enjoy the game".

**Likely mistakes and lost revenue** (all inferences from the evidence above):

1. **Small revenue for the install count.** About 20M installs, yet data.ai puts SRPG 1 in the US App Store at under $5K a month. Finite single-player games with optional diamonds monetize poorly per install.
2. **Selling a fix for grind it creates.** Resource-replacement diamonds paired with growing grind, plus a reported 3x price rise, invite "cash grab" complaints and risk eroding goodwill.
3. **Soft-locks.** Limited ore can make a run unfinishable. This causes churn and 1-star reviews at the moment of highest investment.
4. **Price creep.** Remove Ads tripled and diamond packs rose between 2023 and 2026. That suggests ARPU pressure. Its effect on conversion is unknown.
5. **Fragmented branding.** Each app has worn many store names ("Lost Treasure", "Treasure Island", "Dungeon Quest", "Open World Pixel" vs "Open World Craft"). This looks like ASO keyword testing (inference), but it dilutes the brand and confuses search, as this research found.
6. **PC ports did not take off.** Steam SRPG 1 has 32 reviews and a revenue estimate of about $2,600. Reported issues: no gamepad support, a black screen on startup, and touch-centric controls ([Steam discussions](https://steamcommunity.com/app/1480050/discussions/)).
7. **No live-ops or social layer** was found. Retention depends on sequels.

---

## 13. Assets and production

- **Team and cadence.** Credited to one person (Eric Bouchard). Development cycles are about 10 months for SRPG 3 and more than 12 months for Open World (LinkedIn, via search summary). Six games shipped from 2017 to 2025, about one a year. Team size is **unverified**.
- **Art pipeline.** Pixel art, almost certainly tile-based (inference), refreshed in the 2024 remaster. Whether art is made in-house or bought is **unverified**.
- **Reuse.** The same systems repeat across entries: action button, recipe crafting, chapter structure, diamond store and boat gates. Each sequel mainly adds a theme (temple, time travel, manor, pirates) and more items. SRPG 4's two-era map gets double use from one layout, and SRPG 3's three eras do the same with a theme swap (inference).
- **Content volume.**

| Entry | Items | Recipes | Locations | Monsters |
|---|---|---|---|---|
| SRPG 1 | 70+ | 40 | — | — |
| SRPG 2 | — | 70 | 30+ | 35+ |
| SRPG 3 | 220+ | 85 | 50+ | 40+ |

- **Handmade vs procedural.** The numbered games are handmade, with fixed puzzle solutions and treasure locations. Open World *may* be procedural, but the only source is a mod-APK site, so this is **unverified**.
- **Audio.** No information found (**unverified**).
- **File size.** About 50 MB for the Open World APK ([AppBrain](https://www.appbrain.com/app/survival-rpg-open-world-pixel/com.bewgames.openworld)). About 56 MB for SRPG 4 (mirror sites, via search summary). Both are tiny by modern standards.

---

## 14. Performance and smoothness on mobile

- **Controls.**
    - An on-screen d-pad or a 360-degree stick, plus one action button.
    - Complaints: the d-pad sits too far in on iPad; the action button is less responsive in SRPG 4; "controls were difficult" (SRPG 2 review); no keyboard or gamepad support on PC and Google Play Games.
    - The Google Play Games PC listing advertises improved controls ([GP PC](https://play.google.com/pc-store/games/details?id=com.bewgames.survivaladventure)).
- **Saves.**
    - Manual save and restore in settings.
    - Cloud save added in v8.5.5, and "seamless" automatic cross-device sync with achievements in v9.0.0 ([App Store](https://apps.apple.com/us/app/survival-rpg-1-lost-treasure/id1228652601), via search summary).
- **Offline play** is a selling point in every listing.
- **Device support.**
    - The latest Open World build needs Android 7.0+ (Uptodown); older builds ran on Android 4.4+ (AppBrain).
    - iOS: iPhone and iPad (wiki).
    - PC: through Steam and Google Play Games.
- **Known issues.**
    - World-map fog bug; black screen on startup (Steam).
    - Soft-lock from limited ore.
    - Completion stall at 67.8% (SRPG 2).
    - Formal performance data such as frame rates or crash rates is not public.

---

## 15. Reception

- **Players.**
    - Very positive and consistent: 4.5–4.9 stars across all entries and stores (section 1). About 390K Google Play ratings across the portfolio average 4.57 (AppBrain).
    - Praise: satisfying crafting, puzzles, story and characters (SRPG 4), the "balance between repetition and progress" (SRPG 5), pick-up-and-put-down sessions, offline play and fair IAP.
    - Criticism: grind, ads (transition interstitials and random pop-ups), controls, soft-locks and linearity.
- **Critics.**
    - Essentially no professional coverage. Metacritic lists the games without critic scores ([Metacritic SRPG1](https://www.metacritic.com/game/survival-rpg-the-lost-treasure/), [SRPG2](https://www.metacritic.com/game/survival-rpg-2-temple-ruins/)). Kotaku has only a database stub ([Kotaku](https://kotaku.com/games/survival-rpg-4-haunted-manor)).
    - The only review-style pieces found were [rpg-site.com](https://rpg-site.com/2025/09/10/survival-rpg-4-haunted-manor/) and AppGamer (4.3 from 10 user reviews: [AppGamer](https://www.appgamer.com/survival-rpg-2-temple-ruins-adventure-retro-2d/)).
    - I found no coverage on Pocket Gamer, TouchArcade or AppAdvice.
- **Takeaway.** This is a quiet, word-of-mouth and ASO-driven success: millions of installs with no press.

---

## 16. Lessons for Solvera

### Adopt
1. **One context action button plus a stick.** Make Solvera's primary button contextual (attack, enter car, talk, pick up), with a small number of secondary buttons. Treat button responsiveness as a top-priority metric; Survival RPG reviewers notice when it slips.
2. **Gate the open world with abilities and tools, not levels.** SRPG 1's ladder → canoe → compass → explosives chain gives a clear sense of progress in a small map. Solvera equivalents: a lockpick for garages, a boat licence or speedboat for islands, explosives for vault walls, a police scanner for hidden jobs.
3. **Lighting as gameplay in a top-down view.** A night tint that changes enemy and police behaviour, and torch or headlight radius in interiors. Both are cheap in Godot (CanvasModulate, Light2D) and read well at 3/4 view.
4. **Fog-of-war world map, with interiors as separate scenes.** Test map reveal inside interiors; SRPG's bug shows this edge case is easy to miss.
5. **Offline-first play with cloud saves that sync across devices.** These are core expectations. Ship them at launch, not in v9.
6. **Replay layers on finished content.** Completion-time ranks, a hardcore or permadeath mode, achievements and a new-game-plus stat bonus extended SRPG 1's tail for years at little cost.
7. **Small install size** (about 50 MB). Keep Solvera's base APK lean and stream optional assets later.

### Adapt
1. **Chapters plus a one-line hook.** Use the 7-chapter structure, with a single framing mystery per region or island, and short NPC quest chains instead of cinematic cutscenes.
2. **Time-era map reuse becomes district states.** SRPG 4 reuses one map in two eras. Solvera could reuse a district in states such as day/night, gang-controlled/liberated or before/after a heist to double content per tile set.
3. **Theme swaps on a stable core.** Bew ships a new theme each year on the same systems. Plan Solvera's post-launch content as themed islands or districts on stable systems.
4. **Rewarded-ad hints become optional rewarded ads for convenience.** Use them for hints, taxi fast-travel or a cooldown skip, never for core progress.
5. **Boats as the main vehicle gate.** For an island crime map, a first boat that opens the archipelago is a strong mid-game moment. Add the physics-driven cars that Survival RPG lacks.
6. **ASO title testing**, but keep one fixed brand word in every variant ("Solvera: …") so search and word of mouth still converge.

### Avoid
1. **Selling fixes for grind you designed in.** Do not monetize resource shortcuts and then increase grind or raise prices (the SRPG 4 "triple cost" complaint). Prefer cosmetic items, a fair one-time premium unlock ("Remove ads + starter pack") and battle-pass-style cosmetics.
2. **Finite critical resources.** Never let a run become unfinishable (limited ore). Story-critical materials must respawn or have a fallback source.
3. **Interstitials at area transitions.** Players notice and resent them. Put ads only after a mission ends, and cap their frequency.
4. **Touch controls placed without checking tablets.** Make control positions configurable (scale and offset), and test on iPad and foldables.
5. **Late PC or console ports without gamepad or keyboard support.** If Solvera goes to Google Play Games or PC, ship input remapping on day one.
6. **Weak monetization depth.** Survival RPG shows that 20M installs of a finite, ad-plus-diamond game earns little (data.ai: under $5K a month for SRPG 1 on the US App Store). Plan a business model with real ARPDAU depth: cosmetics, vehicles and outfits, a season structure and an optional premium story pack.
7. **Opaque puzzle gating without in-world signposting.** Lava crossings, stalls at 67.8%, unfindable bosses. Use quest markers or a "hint at cost" system plus diegetic cues so players do not need to look things up.

---

### Source notes and open questions
- **Not verified:** engine, team size, audio, HUD layout, SRPG 4 download count, mobile revenue, endings and named characters, whether Open World is procedural, and thirst or energy meters.
- **Best next steps:**
    - Read the store pages and the [fan wiki](https://survival-rpg-games.fandom.com/wiki/Survival_RPG_Games_Wiki) directly.
    - Watch the official full-gameplay playlists for screen-level camera and HUD analysis.
    - Unpack an APK to identify the engine.
    - Read the [AppMagic publisher page](https://appmagic.rocks/publisher/bew-games-inc-/1_6670339010912734522/?hl=en) for revenue estimates.
