# Crashlands and Crashlands 2: game dossier

Part of the [Top-down games reference bible](../README.md). Same 16 numbered sections as every other dossier, so `#7-combat-and-weapons` (for example) works in each file.

**How this was researched.** Direct page fetching was blocked in this environment: WebFetch failed DNS for every domain tried (steampowered.com, bscotch.net, toucharcade.com), and the proxy refused curl. The session's shared web-search budget also ran out after about 45 searches. Every claim below therefore comes from search-engine result extracts of the cited pages, not from reading the full pages. Treat the exact wording as "per the cited source's extract". Anything I could not tie to a source is marked **unverified**. Third-party sales trackers (SteamSpy-style estimators) are labelled as estimates. Gaps that need a follow-up pass are listed at the end of section 16.

Short names used below: **CL1** = Crashlands (2016). **CL2** = Crashlands 2 (2025). **Bscotch** = Butterscotch Shenanigans, the St. Louis studio of brothers Sam, Seth and Adam Coster.

---

## 1. Overview and facts

### Crashlands 1
- **Developer and publisher:** Butterscotch Shenanigans, which self-published ([Wikipedia](https://en.wikipedia.org/wiki/Crashlands)). Sam Coster is credited as designer ([Wikipedia](https://en.wikipedia.org/wiki/Crashlands)). Seth Coster was co-designer and lead programmer ([GDC Vault, "Crashlands: Design by Chaos"](https://gdcvault.com/play/1025089/-Crashlands-Design-by)). Adam Coster built the back-end narrative tool, the "Crashlands Creator" ([Game Developer, "Telling stories in Crashlands"](https://www.gamedeveloper.com/design/telling-stories-in-crashlands)).
- **Origin:**
    - The concept dates from a September 2013 brainstorm ([PocketGamer.biz, "Two years of cancer and crafting"](https://www.pocketgamer.biz/feature/62742/the-making-of-crashlands/)).
    - Sam was diagnosed with Stage 4b lymphoma at the end of October 2013. The team then dropped an endless runner, *Extreme Slothcycling*, and switched to Sam's GameMaker prototype, because he did not want the runner "to be the last game I make before I die" ([PocketGamer.biz](https://www.pocketgamer.biz/feature/62742/the-making-of-crashlands/)).
    - Release slipped from summer 2015 to January 2016 ([PocketGamer.biz](https://www.pocketgamer.biz/feature/62742/the-making-of-crashlands/)).
- **Release dates:**
    - iOS, Android and Steam (Windows/Mac) on **21 January 2016**, all on the same day ([Android Police](https://www.androidpolice.com/2016/01/21/crashlands-from-butterscotch-shenanigans-crash-lands-onto-android-steam-and-ios-today/)).
    - Nintendo Switch on **8 November 2018**, which added local co-op with a second player as Juicebox ([RPGamer](https://rpgamer.com/2018/11/crashlands-now-available-on-switch/), [GamingOnLinux](https://www.gamingonlinux.com/2018/11/the-amusing-story-driven-crafting-rpg-crashlands-adds-local-co-op-support)).
    - Xbox One on 29 January 2021 according to Wikipedia's infobox ([Wikipedia](https://en.wikipedia.org/wiki/Crashlands)). I found no second source, so this date is **unverified**.
- **Engine:** GameMaker Studio ([Wikipedia](https://en.wikipedia.org/wiki/Crashlands)).
- **Price at launch:** about $5 on mobile and $15 on Steam ([Android Police](https://www.androidpolice.com/2016/01/21/crashlands-from-butterscotch-shenanigans-crash-lands-onto-android-steam-and-ios-today/), [TouchArcade Dec 2015](https://toucharcade.com/2015/12/08/the-crashlands-saga-comes-full-circle-when-the-game-releases-in-january-2016/)). A later MobileSyrup listing gives $6.99 iOS, $7.29 Android and $16.99 Steam, probably Canadian prices ([MobileSyrup](https://mobilesyrup.com/?p=158584)). Premium, single purchase per platform.
- **Steam price change:** in August 2017 the Steam price was permanently cut from $14.99 to $9.99 ([TouchArcade](https://toucharcade.com/2017/08/15/crashlands-sells-500k-copies-goes-on-sale-for-40-off-to-celebrate/), [Bscotch blog](https://blog.bscotch.net/post/crashlands-hits-500k-units-and-celebrates-with-a-price-drop/)).
- **Sales and players (primary sources first):**
    - **500,000+ units across all platforms by August 2017**, with "the vast majority" on iOS and Android ([TouchArcade](https://toucharcade.com/2017/08/15/crashlands-sells-500k-copies-goes-on-sale-for-40-off-to-celebrate/), [Bscotch blog](https://blog.bscotch.net/post/crashlands-hits-500k-units-and-celebrates-with-a-price-drop/)). About 118,000 of those were on PC ([PC Gamer, via search extract](https://www.pcgamer.com/au/crashlands-studio-reveals-its-next-project-scuffle-buddies)).
    - **First-anniversary post (21 Jan 2017)** ([Bscotch blog](https://blog.bscotch.net/post/crashlands-anniversary/)):
        - 6.6 million installs, "most from pirates".
        - About 0.5 million of those installs came from BscotchID users.
        - 240,000 BscotchID players logged 474 years of playtime; the author extrapolates this to about 6,000 years across all players.
        - 210 million creatures killed and 60 million fish caught.
    - **Launch-window revenue order** ([PocketGamer.biz](https://www.pocketgamer.biz/feature/62742/the-making-of-crashlands/)): Steam led for the first 3 days, while its pop-up ad ran. iOS then overtook it and kept a steady lead. Google Play was third, at about half of Steam's revenue.
    - **Return on investment:** with no paid advertising, the game earned enough to pay the founders two years of development backpay, double the team and fund a year of runway ([Game Developer, "Notes from an indie cross-platform launch"](https://www.gamedeveloper.com/business/notes-from-an-indie-cross-platform-launch)).
    - **"131,000 units in 10 days"** appears only in a Wikipedia summary, and the 10-day PocketGamer.biz interview declined to give numbers. **Unverified.**
    - **2024 sales:** the original sold more copies in 2024 than in "the past several years combined", which the studio credits to Crashlands 2 hype and "very aggressive discounting" ([Bscotch blog, 2024 Bscotch Wrapped](https://blog.bscotch.net/post/2024-bscotch-wrapped/)).
    - **Third-party Steam-only estimates**, which are not official and disagree with each other:
        - 668k units and $2.42M gross ([steamdata.ai](https://steamdata.ai/game/391730/crashlands)).
        - 440k units and $4.4M ([SteamPulse](https://steampulse.org/game/391730)).
        - $2.83M gross and $0.84M net ([Steam Revenue Calculator](https://steam-revenue-calculator.com/app/391730/crashlands)).
- **Ratings:**
    - Metacritic: iOS 93, PC 78, Switch 75 ([Wikipedia](https://en.wikipedia.org/wiki/Crashlands)).
    - OpenCritic: top-critic average 76, 55% recommend ([OpenCritic](https://opencritic.com/game/2173/crashlands)).
    - Steam: "Very Positive", about 5,500 reviews in an older snapshot ([Steam](https://store.steampowered.com/app/391730/_/)) and 6,735 by July 2026 ([Steambase](https://steambase.io/apps/391730)).
    - Awards: TouchArcade Game of the Year 2016 ([Bscotch blog](https://blog.bscotch.net/post/crashlands-gets-toucharcades-2016-game-of-the-year-award/)).

### Crashlands 2
- **Announcement history:**
    - In August 2020 a non-playable "Crashlands 2" test listing appeared on Google Play at a $99.99 placeholder price, used to stop accidental purchases on Google's testing tracks. Bscotch had done the same for *Levelhead* ([Android Police 2020](https://www.androidpolice.com/2020/08/19/crashlands-2-android-early-access-testing/)).
    - Formal announcement on **7 June 2023** ([Gematsu](https://www.gematsu.com/2023/06/crashlands-2-announced-for-pc-ios-and-android), [press release](https://gamespress.westeu-v2.propressroom.com/Crashlands-2-Sequel-to-the-Award-Winning-Crafting-RPG-Announced)). The plan then was Steam in 2024 and mobile exclusively through **Netflix Games** ([press release](https://gamespress.westeu-v2.propressroom.com/Crashlands-2-Sequel-to-the-Award-Winning-Crafting-RPG-Announced)).
    - The Netflix deal ended in October/November 2024, during Netflix's wider games retreat. Adam Coster said "nothing went wrong exactly" ([What's on Netflix](https://www.whats-on-netflix.com/news/why-crashlands-2-wont-be-coming-to-netflix-games/)).
- **Release:** **10 April 2025**, the same day on Steam (Windows, Steam Deck), iOS and Android. Consoles are "not currently planned" ([Bscotch support](https://www.bscotch.net/support/crashlands-2), [press release](https://gamespress.com/Open-World-Crafting-RPG-Crashlands-2-Launches-on-PC-Mobile-April-10-20)).
- **Price:** **$24.99 on Steam** (with Valve's regional pricing) and **$9.99 on mobile** ([Bscotch support](https://www.bscotch.net/support/crashlands-2)). Google Play has also shown $6.99 ([Google Play](https://play.google.com/store/apps/details?id=com.bscotch.crashlands2&hl=en_US)), so the price probably changed later. Premium, with full cross-platform save sync ([press release](https://gamespress.com/Open-World-Crafting-RPG-Sequel-Crashlands-2-Available-Now-on-PC-Mobile)). I found no ads or IAP mentioned in any listing, but "no IAP" is **unverified** as an explicit statement.
- **Engine and tools:** GameMaker, Clip Studio Paint and Spine, plus custom tools, many of them public on Bscotch's GitHub ([Bscotch, "How did we make Crashlands 2?"](https://www.bscotch.net/support/crashlands-2/how-made)).
- **Development length:** about 4.5 years net, of which about one year went into tools ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-built-with-gamemaker)). The team built *Levelhead* (2020) between the two games ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
- **Sales:** no official unit or revenue figures found. Third-party estimates, all **unverified**:
    - About $990k lifetime revenue, about $800k gross / $500k net, about 50k owners ([gamesensor](https://gamesensor.info/app/1401730), [games-stats](https://games-stats.com/steam/game/crashlands-2/), [Playtracker](https://playtracker.net/insight/game/110113)).
    - About 240k wishlists at release, with an estimated 17% converted within 30 days (same trackers).
- **Steam peak concurrent players:** 5,881 in April 2025 ([SteamCharts](https://steamcharts.com/app/1401730)). PCGamesN reportedly cited 8,559 ([PCGamesN](https://www.pcgamesn.com/crashlands-2/new-survival-game-steam)); the two figures conflict and I could not resolve them. By 2026 the 30-day peak was about 124 ([SteamCharts](https://steamcharts.com/app/1401730)).
- **Ratings:**
    - Metacritic 82 from 6 critics; user score 8.3 ([Metacritic](https://www.metacritic.com/game/crashlands-2/)).
    - OpenCritic: top-critic average 81 from 11 critics, 82% recommend ([OpenCritic](https://opencritic.com/game/18373/crashlands-2)).
    - Steam: 93% positive of 663 reviews in an early snapshot ([PCGamesN](https://www.pcgamesn.com/crashlands-2/new-survival-game-steam)), and 88% of 2,180 later ([GG.deals](https://gg.deals/game/crashlands-2/)).
- **Merchandise:** a Flux & Juicebox plushie on Makeship sold 253 units, 126% funded ([Makeship](https://www.makeship.com/products/flux-juicebox-plushie)).

---

## 2. Camera and visual presentation

### Crashlands 1
- **Camera:** fixed top-down with a slight 3/4 tilt. Characters and props are drawn as upright sprites standing on a flat ground plane, Don't Starve-like in framing ([Wikipedia](https://en.wikipedia.org/wiki/Crashlands)). There is no camera rotation. The exact pitch angle is my own observation of the style and is **unverified**.
- **Resolution and proportions:** the game was authored for **540p**, which left few pixels per character. That is why Flux and the creatures are big-headed "mascot style" figures with chunky silhouettes ([Game Rant interview](https://gamerant.com/crashlands-2-interview-sequel-butterscotch-shenanigans/), [GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
- **Art tools:** art was made in Inkscape (vector), later replaced by Clip Studio for CL2 ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
- **Look:** bright saturated colours, heavy black outlines and goofy squash-and-stretch animation. These elements were deliberately kept for the sequel ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
- **Readability:** at small phone sizes, the outlines and silhouette-first creature design make threats readable. PC Gamer praised the "simple controls and a clean UI" ([PC Gamer](https://www.pcgamer.com/crashlands-review/)).
- **Visual compromises:** the postmortem admits the visuals were "rough" by business standards, even though they served the creative goals ([Game Developer postmortem](https://www.gamedeveloper.com/business/postmortem-butterscotch-shenanigans-i-crashlands-i-)).
- **Accessibility:** a 2016 patch added colourblind options and an improved map ([Pocket Gamer](https://www.pocketgamer.co.uk/crashlands/update-crashlands-is-getting-a-new-patch-tomorrow-adds-new-colorblind-options-en/)).
- **Base building:** bases were essentially floor plans with knee-high walls, because the top-down view could not show tall structures without hiding the player ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).

### Crashlands 2
- **Camera:** an **isometric** view. It is still 2D in GameMaker, not 3D. Sam Coster: "We're still using Game Maker… a solid 2D engine", and focusing on 2D lets them move fast ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)). The "3D look" comes from isometric framing, layered sprites and Spine skeletal animation, not from 3D rendering.
- **Why they changed the view:**
    - Charm: even simple actions, such as Flux running, should "evoke emotion or make people laugh". "Overflowing with charm" was a core pillar ([Game Rant](https://gamerant.com/crashlands-2-interview-sequel-butterscotch-shenanigans/)).
    - Building: the isometric view enables **roofed, walled buildings** that tie into crafting and research ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
- **Resolution:** moved to **1080p**, which allowed far more detail and moved away from mascot proportions ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
- **Character art:** the player character is built from **56 individually animated gear pieces**, against roughly 5–6 in CL1, so armour pieces mix and match visibly ([Game Rant](https://gamerant.com/crashlands-2-combat-builds-map-world-gear-items/)).
- **Readability:**
    - Enemy attacks are drawn as on-ground **telegraphs**, which double as the player's own aiming reticle ([Bscotch blog, Hand-to-Pan Combat](https://blog.bscotch.net/post/crashlands-2-hand-to-pan-combat/)).
    - Strange Creatures (daily minibosses) and anomalous creatures are marked on the map with paw-print icons ([TapTap dev post](https://www.taptap.cn/moment/721327067836187627)).
- **Visual complaints:**
    - The fixed camera can hide parts of the world, especially during building ([Steam user review](https://steamcommunity.com/profiles/76561198042198830/recommended/1401730/)).
    - Night is hard to see on phones ([TapTap reviews](https://www.taptap.io/app/33793848/review)).
- **HUD:** one universal context button for attack, tools and interaction keeps the mobile HUD small ([Gaming on Phone review](https://gamingonphone.com/reviews/crashlands-2-game-review/)).

---

## 3. Core gameplay loops

### Crashlands 1
- **Moment to moment:** walk, harvest a resource node (tap it and Flux auto-uses the right tool), fight creatures for drops, return to a crafting station.
- **Session loop:** quest giver → needs recipe X → recipe needs materials from creature Y → craft gear that beats Y → unlock the next station or tier.
- **Inventory:** it never asks you to manage it. Adam proposed scrapping the inventory screen, making storage unlimited, and only showing what you have when it is relevant to what you want to make ([PC Gamer](https://www.pcgamer.com/how-a-terminal-cancer-diagnosis-inspired-comedy-crafting-game-crashlands/)). The Epic Games Store listing markets this as a "self-managing, infinite inventory that retrieves your tools when you need them" ([Epic](https://store.epicgames.com/p/crashlands)).
- **Macro loop:** a story chain through three biomes, each with a new crafting tier, stations, a boss and a hub of characters ([Bscotch blog, The Manual](https://blog.bscotch.net/post/crashlands-the-manual)).
- **Genre framing:** the team aimed for "Diablo, Pokémon and Terraria" ([Game Developer postmortem](https://www.gamedeveloper.com/business/postmortem-butterscotch-shenanigans-i-crashlands-i-)). The game was marketed as a "story-driven crafting RPG" ([Game Developer](https://www.gamedeveloper.com/design/video-the-last-game-i-make-before-i-die-a-i-crashlands-i-postmortem)).

### Crashlands 2
- **Same backbone, new framing:** "thrival", not survival. There is no hunger or starvation and no inventory management, and the goal is "showing up and being awesome" ([Game Rant](https://gamerant.com/crashlands-2-survival-game-genre-inventory-loot-crafting/)).
- **Recipe sources:** quests and recipes now come largely from **research done by friends**: alien companions, each with their own stories, who unlock recipes as the relationship grows ([Game Rant](https://gamerant.com/crashlands-2-interview-sequel-butterscotch-shenanigans/), [PC Gamer](https://www.pcgamer.com/crashlands-2-crashes-into-the-pc-gaming-show-its-very-crashlandsy-says-dev/)).
- **Added loops:**
    - Home building with roommates, farming and pets ([App Store](https://apps.apple.com/us/app/crashlands-2/id1528199331)).
    - Daily Strange Creatures in each region ([App Store](https://apps.apple.com/us/app/crashlands-2/id1528199331)).
    - From update 1.3, the Juice Forge gear-upgrade and re-roll loop ([TapTap dev post](https://www.taptap.cn/moment/721327067836187627)).
- **Death:** the original death penalty stays. You drop half your inventory and must recover it, an idea Coster links to Valheim, where corpse runs "become their own adventure" ([Game Rant](https://gamerant.com/crashlands-2-survival-game-genre-inventory-loot-crafting/)).

---

## 4. World building and regions

### Crashlands 1
- **Setting:** the planet **Woanope**. Three explorable biomes: **Savanna** (warm; one-legged grazers called Wompits), **Bawg** (one giant living organism that spawned most of its life) and **Tundra** ([Bscotch blog, The Manual](https://blog.bscotch.net/post/crashlands-the-manual), [Pre-Beta Devlog #3](https://blog.bscotch.net/post/spider-monkeys-and-biomes-crashlands-pre-beta-devlog-3/)).
- **Procedural plus hand-made:** the biomes are "infinitely(ish)-large, procedurally-generated" ([Bscotch blog](https://blog.bscotch.net/post/crashlands-the-manual)). Story locations are hand-designed **outposts** (villages, characters, boss arenas) placed on top of the random terrain, and they change state as quests progress ([crashlands-public campaigns README on GitHub](https://github.com/bscotch/crashlands-public/blob/develop/campaigns/README.md), [Game Rant](https://gamerant.com/crashlands-2-combat-builds-map-world-gear-items/)).
- **Early generation cost:** when Seth first got world generation working, it took 7 minutes to generate a world that took 4 minutes to run across ([Kotaku](https://kotaku.com/the-last-game-i-make-before-i-die-fighting-cancer-by-m-1758326409)).
- **Gating:** each biome opens through the story; travel needs story items or gadgets, and the threat level rises per biome. The exact gating items are **unverified**.
- **Weakness:** procedural filler between outposts made exploration feel samey. Sam later called the switch away from procedural generation the sequel's "most significant fundamental change", made so the team could author discovery moments ([Game Rant](https://gamerant.com/crashlands-2-combat-builds-map-world-gear-items/)).

### Crashlands 2
- **Fully hand-built world.** "Ditch procedural world generation entirely and build the whole world by hand for meaningful exploration." Weapons, gadgets, recipes and quests are hidden around the world on purpose ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
- **Regions:** the marshy forests of **Maarla's Mantle**, the deserts of **The Husk** and the ice floes of **The Aquadunes**, in a different part of Woanope ([press release](https://www.gamedeveloper.com/press-release/open-world-crafting-rpg-sequel-crashlands-2-available-now-on-pc-mobile), [Vice](https://www.vice.com/en/article/sam-coster-creative-director-for-crashlands-2-details-how-the-sequel-is-bigger-and-better-than-ever-interview/)).
- **Ecology:** the announcement highlighted "ecological interactions", with creatures interacting with each other ([press release](https://gamespress.westeu-v2.propressroom.com/Crashlands-2-Sequel-to-the-Award-Winning-Crafting-RPG-Announced)).
- **Daily world events:** Strange Creatures (repeatable minibosses) appear in every major region at the start of each in-game day ([App Store](https://apps.apple.com/us/app/crashlands-2/id1528199331)).

---

## 5. Story and narrative progression

### Crashlands 1
- **Premise:** you play **Flux Dabes**, a galactic trucker. A "chin-strapped alien menace" named **Hewgodooko** derails her shipment and strands her on Woanope with her robot sidekick **Juicebox** ([App Store](https://apps.apple.com/us/app/crashlands/id808296431)).
- **Antagonist:** Hewgodooko is a Veeru. He has a 3-phase Savanna boss fight and steals Flux's packages to power his machine ([bscotch.wiki.gg](https://bscotch.wiki.gg/wiki/Hewgodooko)).
- **Tone:** absurdist, self-aware comedy, with "fun combat, great writing" ([PC Gamer](https://www.pcgamer.com/crashlands-review/)). Side stories touch on politics, mythology and invention, alongside plenty of fetch and kill quests ([GamingTrend](https://gamingtrend.com/reviews/crashlands-review/)).
- **Delivery:** almost entirely quest dialogue boxes with NPCs. **More than 50,000 words** were written by two people in about three months, which the postmortem credits to Adam's "Crashlands Creator" tool ([Game Developer](https://www.gamedeveloper.com/design/telling-stories-in-crashlands)).
- **Quest system:** the narrative system is built on one deliberately minimal "Quest" building block that can express many story shapes ([Game Developer, "Telling stories in Crashlands"](https://www.gamedeveloper.com/design/telling-stories-in-crashlands)).
- **Ending:** the details are **unverified**. Q is cited as a late-game foe ([IGF](https://www.igf.com/crashlands-1)).

### Crashlands 2
- **Premise:** Flux returns to Woanope. She is still a trucker, now in need of "some serious rest and relaxation", and crash-lands in a new region ([App Store](https://apps.apple.com/us/app/crashlands-2/id1528199331)).
- **Returning characters:** Grandmammy and her Fifth Arm squad ([Vice](https://www.vice.com/en/article/sam-coster-creative-director-for-crashlands-2-details-how-the-sequel-is-bigger-and-better-than-ever-interview/)).
- **Writing team:** a full-time writer produced a story bible ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)), and the core team includes "one narrative designer" ([Bscotch](https://www.bscotch.net/support/crashlands-2/how-made)).
- **Tone shift:** the stated aim was "from goofy to gut-punching", adding emotional beats to the comedy ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)). Friendships are a pillar ([press release](https://gamespress.westeu-v2.propressroom.com/Crashlands-2-Sequel-to-the-Award-Winning-Crafting-RPG-Announced)).
- **Criticism:** still unvoiced and very text-heavy ([Steam review](https://steamcommunity.com/profiles/76561198042198830/recommended/1401730/)). Kotaku called it "wildly overwritten", though it treated this as a minor issue ([Kotaku](https://kotaku.com/crashlands-2-butterscotch-shenanigans-ios-android-steam-1851782672)).
- **Ending:** the details are **unverified**.

---

## 6. Missions and quests design

### Crashlands 1
- **Quest types** ([GamingTrend](https://gamingtrend.com/reviews/crashlands-review/), [AppUnwrapper](https://appunwrapper.com/2016/02/03/crashlands-review/)):
    - Main story quests that unlock essential tools and stations.
    - Optional side quests that give bonuses.
    - Menial quests, such as building furniture, mixed with heroic ones, such as boss kills.
- **Givers:** outpost NPCs; quests change the outposts over time ([GitHub README](https://github.com/bscotch/crashlands-public/blob/develop/campaigns/README.md)).
- **Quest count:** **unverified**. No source gave a number.
- **Weakness:** critics called the fetch and kill quests "seemingly endless" ([GamingTrend](https://gamingtrend.com/reviews/crashlands-review/)). PC Gamer said the game went from fun to "repetitive and predictable" ([PC Gamer](https://www.pcgamer.com/crashlands-review/)).

### Crashlands 2
- **Givers:** quests come mainly from befriended alien companions through "research", RPG-companion style. The "random, quirky quests" of CL1 are kept ([Game Rant](https://gamerant.com/crashlands-2-interview-sequel-butterscotch-shenanigans/)).
- **Friendship NPCs:** some NPCs exist just to hang out with, and they teach crafting tips ([PC Gamer](https://www.pcgamer.com/crashlands-2-crashes-into-the-pc-gaming-show-its-very-crashlandsy-says-dev/)).
- **Hidden quests:** quests are hidden in hand-placed spots in the world ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
- **Repeatable content:**
    - Daily Strange Creatures ([App Store](https://apps.apple.com/us/app/crashlands-2/id1528199331)).
    - Five side bosses with their own story added in 1.3 ([TapTap dev post](https://www.taptap.cn/moment/721327067836187627)).
- **Design note from the developers:** you don't need to do everything, but the game is "better balanced" if you do more than just tick off quests ([Vice](https://www.vice.com/en/article/sam-coster-creative-director-for-crashlands-2-details-how-the-sequel-is-bigger-and-better-than-ever-interview/)). In other words, they expect exploration to pay for itself.
- **Quest count:** **unverified**.

---

## 7. Combat and weapons

### Crashlands 1
- **Controls:** a one-touch scheme. You tap or click a target and Flux walks over and attacks. Sam later said this limited combat depth ([Gaming on Phone interview](https://gamingonphone.com/interviews/indie-spotlight-crashlands-2-butterscotch-shenanigans-returns-with-a-bigger-bolder-adventure/)).
- **Gear:** combat is gear-check heavy. Armour sets and a weapon crafted from each biome's creatures set your stats.
- **Enemy readability:** enemies telegraph attacks, which you dodge by walking out of the marked area. Critics called the combat "challenging" but not harshly punishing ([OpenCritic](https://opencritic.com/game/2173/crashlands)).
- **Bosses:** story bosses and "legendary monsters" acting as minibosses ([GamingTrend](https://gamingtrend.com/reviews/crashlands-review/)).
- **COMBOver patch (v1.3, May 2018)** ([GamingOnLinux](https://www.gamingonlinux.com/2018/05/story-driven-crafting-rpg-crashlands-has-a-huge-combat-overhaul/)):
    - Bscotch admitted combat "fell flat over time" and that player choice felt sparse.
    - Added 36 weapons.
    - Gave each weapon type a role: bleed only on swords, stun only on hammers.
    - Added a combo system in which trinkets and gadgets grant abilities, for example a "Stun Mirror" that strikes stunned targets with lightning.
    - Added a consumable hotbar slot and one-tap loadout swap.
    - Added Hardcore and Creative modes.

### Crashlands 2
- **Three pillars** ([Bscotch blog, Hand-to-Pan Combat](https://blog.bscotch.net/post/crashlands-2-hand-to-pan-combat/)):
    - **Telegraphs**, which also serve as the player's aiming reticle.
    - A **dodge roll called the "Juke"**.
    - **Ranged options**: spears, bombs and throwable fish.
- **Controls and abilities:**
    - Full directional control replaced one-touch ([Gaming on Phone](https://gamingonphone.com/interviews/indie-spotlight-crashlands-2-butterscotch-shenanigans-returns-with-a-bigger-bolder-adventure/)).
    - Almost every ability hits all targets inside its telegraph shape ([Gaming on Phone](https://gamingonphone.com/interviews/indie-spotlight-crashlands-2-butterscotch-shenanigans-returns-with-a-bigger-bolder-adventure/)).
    - Different telegraph sizes and "funky stuff we did with abilities" ([Game Rant](https://gamerant.com/crashlands-2-combat-builds-map-world-gear-items/)).
- **Weapon classes** ([Game Rant](https://gamerant.com/crashlands-2-best-weapon-types-ranked/)):
    - Throwables.
    - Knuckles: fast chain hits.
    - Gadgets: buffs, attacks or jokes.
    - Crushers: successor to hammers.
    - Spears and daggers.
- **Weapon longevity:** weapons "last longer before you need to upgrade", and switching class changes how you play ([Game Rant](https://gamerant.com/crashlands-2-combat-builds-map-world-gear-items/)).
- **Gear tuning (1.3 update):** random weapon stats, and the Juice Forge returns for upgrades, re-rolls and refinement ([TapTap dev post](https://www.taptap.cn/moment/721327067836187627)).
- **Complaints:**
    - Combat can feel "stat-checky" ([OpenCritic excerpts](https://opencritic.com/game/18373/-/reviews)).
    - Fights don't always live up to the preparation, and multi-enemy fights get messy ([Hardcore Gamer](https://hardcoregamer.com/review-crashlands-2/)).
    - On mobile, spam-attack inputs can swallow a dodge ([TapTap](https://www.taptap.io/app/33793848/review)).

---

## 8. Progression and upgrades

### Crashlands 1
- **Crafting tree:** more than **500 craftable items** ([App Store](https://apps.apple.com/us/app/crashlands/id808296431)). Each biome adds stations, and each station adds recipes.
- **Discovery:** recipes are "discovered" by harvesting new materials, which makes curiosity the progression driver. This is a well-known mechanic, but I found no source for it, so it is **unverified**.
- **Inventory:** unlimited and self-managing ([PC Gamer](https://www.pcgamer.com/how-a-terminal-cancer-diagnosis-inspired-comedy-crafting-game-crashlands/)). Sam said the team "had inventory for quite a long time" before cutting it, and threw out about twice as many features as shipped ([iFanzine](https://ifanzine.com/butterscotch-shenanigans-sam-coster-discusses-making-of-crashlands/)).
- **Death penalty:** dying drops half your stuff, which can mean about 4,000 items after a two-hour session ([Game Rant](https://gamerant.com/crashlands-2-survival-game-genre-inventory-loot-crafting/)).
- **Base building:** the alpha build used a Minecraft/Terraria-style hotbar flow for placement. The team found it cumbersome and redesigned build mode ([Bscotch blog, Butterscotch Chronicle](https://blog.bscotch.net/post/butterscotch-chronicle-813-93/)).
- **Pets:** every creature can be tamed; you find eggs and craft pet items, and one pet follows you at a time ([App Store](https://apps.apple.com/us/app/crashlands/id808296431), [AppUnwrapper](https://www.appunwrapper.com/2016/01/22/crashlands-walkthrough-guide/)).
- **Juice Forge:** a CL1 gear upgrade and re-roll system, as implied by its "return" in CL2 1.3 ([TapTap dev post](https://www.taptap.cn/moment/721327067836187627)).
- **Pacing:** PC Gamer said pacing and progression were "tuned for a mobile experience, not the PC" ([PC Gamer](https://www.pcgamer.com/crashlands-review/)). Game Informer called the pace "relaxed, lackadaisical" ([Game Informer](https://gameinformer.com/games/crashlands/b/pc/archive/2016/02/09/game-informer-review-crashlands.aspx)).

### Crashlands 2
- **Structure:** gear is built from 56 visible pieces, which allows mix-and-match builds ([Game Rant](https://gamerant.com/crashlands-2-combat-builds-map-world-gear-items/)).
- **Home and base:** real buildings with walls, doors and roofs, decorated and tied into research and crafting ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)). Roommates, gardens and farming of rare resources ([App Store](https://apps.apple.com/us/app/crashlands-2/id1528199331)).
- **Pets:** find eggs, figure out how to hatch them and raise them as companions, for example an orphaned "Sluggababy" ([App Store](https://apps.apple.com/us/app/crashlands-2/id1528199331)).
- **Recipe gating:** recipes unlock through friendship and research ([Game Rant](https://gamerant.com/crashlands-2-interview-sequel-butterscotch-shenanigans/)).
- **Post-launch progression layers** ([Bscotch blog 1.1](https://blog.bscotch.net/post/crashlands-2-update-11-the-compendium/), [Bscotch blog 1.2](https://blog.bscotch.net/post/crashlands-2-patch-12/), [RPGamer](https://rpgamer.com/2025/06/crashlands-2-version-1-2-update-releasing-this-week/), [TapTap](https://www.taptap.cn/moment/721327067836187627)):
    - 1.1 "The Compendium": a collection log.
    - 1.2 "Hardcore Scramble", 24 June 2025: two difficulty modes.
    - 1.3 "The Overflow", September 2025: Juice Forge, random stats, juice shards from anomalous creatures.
- **Pacing complaint:** early progression is "slow", with "initial learning sluggishness" ([OpenCritic excerpts](https://opencritic.com/game/18373/-/reviews)).

---

## 9. Vehicles, mounts, movement and physics

- **Crashlands 1:**
    - No vehicles. In-world mounts are **unverified**.
    - Movement is tap-to-move or click-to-move on all platforms, with Flux walking to the tapped point and auto-acting on targets ([Gaming on Phone](https://gamingonphone.com/interviews/indie-spotlight-crashlands-2-butterscotch-shenanigans-returns-with-a-bigger-bolder-adventure/), [Minireview](https://minireview.io/role-playing/crashlands-2)).
    - Pets follow you and fight beside you, one at a time ([AppUnwrapper](https://www.appunwrapper.com/2016/01/22/crashlands-walkthrough-guide/)).
    - Physics is minimal: there is no rigid-body simulation, only knockback and stun effects ([GamingOnLinux](https://www.gamingonlinux.com/2018/05/story-driven-crafting-rpg-crashlands-has-a-huge-combat-overhaul/)).
    - Switch co-op let a second player control Juicebox ([RPGamer](https://rpgamer.com/2018/11/crashlands-now-available-on-switch/)).
- **Crashlands 2:**
    - Direct analog movement with a virtual stick on mobile ([Minireview](https://minireview.io/role-playing/crashlands-2)).
    - The **Juke** dodge roll is treated as core movement, not just a defensive tool ([Bscotch blog](https://blog.bscotch.net/post/crashlands-2-hand-to-pan-combat/)).
    - The dodge distinguishes a clean avoid from a partial hit that does reduced damage ([Hardcore Gamer](https://hardcoregamer.com/review-crashlands-2/)).
    - Pets are hatched and raised companions ([App Store](https://apps.apple.com/us/app/crashlands-2/id1528199331)).
    - Rideable mounts, vehicles and fast travel: no source found, so all are **unverified**.
- **Takeaway for Solvera:** neither game has vehicle physics, so Crashlands is not a reference for driving. It is a reference for responsive on-foot feel on touch screens: snap movement and a dodge with clear success feedback.

---

## 10. Things to do and activities

- **Crashlands 1:**
    - Harvesting, crafting, quests, boss hunts, taming and pet raising, base decoration, fishing (60 million fish caught by the first anniversary) and exploration of procedural biomes ([Bscotch blog anniversary](https://blog.bscotch.net/post/crashlands-anniversary/)).
    - Post-launch Hardcore and Creative modes ([GamingOnLinux](https://www.gamingonlinux.com/2018/05/story-driven-crafting-rpg-crashlands-has-a-huge-combat-overhaul/)) and Switch local co-op ([RPGamer](https://rpgamer.com/2018/11/crashlands-now-available-on-switch/)).
- **Crashlands 2:**
    - All of the above, plus:
        - Home building with roommates.
        - Farming.
        - Friendship hangouts.
        - Egg hatching.
        - Daily Strange Creature hunts.
        - Traps, elixirs and gadgets ([App Store](https://apps.apple.com/us/app/crashlands-2/id1528199331)).
    - Hidden secrets placed by hand ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
    - The Compendium collection log ([Bscotch blog](https://blog.bscotch.net/post/crashlands-2-update-11-the-compendium/)).
    - Hardcore modes ([Bscotch blog](https://blog.bscotch.net/post/crashlands-2-patch-12/)).
    - Side bosses and the Juice Forge ([TapTap](https://www.taptap.cn/moment/721327067836187627)).

---

## 11. Player hooks and retention

- **Always a next goal.** Quests, recipes and stations chain together, so the next craftable thing is always in view. Game Informer praised the "structured progression and ongoing story" ([OpenCritic, Game Informer excerpt](https://opencritic.com/game/2173/crashlands)). The extrapolated 6,000 player-years of playtime by the first anniversary shows strong engagement ([Bscotch blog](https://blog.bscotch.net/post/crashlands-anniversary/)).
- **Low friction.** There is no inventory to manage and tools are auto-equipped. TouchArcade said it "streamlines a lot of the more irritating elements typically found in games with crafting systems" ([TouchArcade review](https://toucharcade.com/2016/01/20/crashlands-review/)).
- **Humour as reward.** Every quest turn-in pays off with a joke.
- **Collection hooks:** taming every creature, 500+ items ([App Store](https://apps.apple.com/us/app/crashlands/id808296431)), and the CL2 Compendium.
- **One save across devices.** A single save moves between phone and PC, so players can continue on the couch or on the go ([Game Informer](https://gameinformer.com/games/crashlands/b/pc/archive/2016/02/09/game-informer-review-crashlands.aspx), [CL2 press release](https://gamespress.com/Open-World-Crafting-RPG-Sequel-Crashlands-2-Available-Now-on-PC-Mobile)).
- **CL2 daily rhythm:** Strange Creatures each in-game day and anomalous creatures, which create soft dailies with no real-time pressure ([App Store](https://apps.apple.com/us/app/crashlands-2/id1528199331), [TapTap](https://www.taptap.cn/moment/721327067836187627)).
- **Weakness:** retention after the story ends is thin. CL2's Steam players fell from a 5,881 peak to a 30-day peak of about 124 by 2026 ([SteamCharts](https://steamcharts.com/app/1401730)), which is normal for premium narrative games.

---

## 12. Monetization and mistakes

### Model
- **Both games** are premium, sold separately per platform, with free cross-save through a Bscotch account. There are no subscriptions or loot boxes.
- **CL1 pricing logic:**
    - A Steam community repost of a developer statement says Bscotch thinks of CL1 as a "$20 game" split into $5 mobile + $15 PC, "one copy" across devices, because stores won't bundle across platforms ([Steam discussion](https://steamcommunity.com/app/391730/discussions/0/1694914736011776350)). It is secondhand, so treat it as **unverified wording**.
    - Players must buy each platform version and link them with a free BscotchID ([Steam discussion](https://steamcommunity.com/app/391730/discussions/0/405692224239660874)).
- **CL2 pricing:** the same split at a higher tier, $24.99 Steam and $9.99 mobile ([Bscotch support](https://www.bscotch.net/support/crashlands-2)). Players questioned why Steam costs more ([Steam discussion](https://steamcommunity.com/app/1401730/discussions/0/550107551434349765/)).

### What the developers said cost them
1. **Cannibalisation warning:** before launch the team was warned that the $5 mobile version would cannibalise $15 Steam sales, and launched on both anyway ([Game Developer, Notes from an indie cross-platform launch](https://www.gamedeveloper.com/business/notes-from-an-indie-cross-platform-launch)). The results support the bet: mobile became most of the 500k units ([TouchArcade](https://toucharcade.com/2017/08/15/crashlands-sells-500k-copies-goes-on-sale-for-40-off-to-celebrate/)).
2. **PC bias against "mobile games":** many PC reviewers and players assumed the game had sacrificed "form and function just to fit on mobile". Bscotch said it underestimated that bias and might launch on Steam first in future ([TouchArcade](https://toucharcade.com/2016/03/09/crashlands-postmortem-hints-at-a-worrying-trend-regarding-mobile-game-development/)). PC Gamer's 73 and its "tuned for a mobile experience" line show the effect ([PC Gamer](https://www.pcgamer.com/crashlands-review/)).
3. **Rough visuals:** the postmortem admits the art was the wrong call from a business standpoint, even though it served the creative goals ([Game Developer postmortem](https://www.gamedeveloper.com/business/postmortem-butterscotch-shenanigans-i-crashlands-i-)).
4. **Piracy:** 6.6M installs against about 500k sales; "most from pirates" ([Bscotch blog](https://blog.bscotch.net/post/crashlands-anniversary/)). A pirated copy was also listed on the Amazon Appstore at launch ([TechRaptor](https://techraptor.net/gaming/news/updatedpirated-copy-of-crashlands-lands-on-amazon-app-store)). Their GDC slides cite a 97% piracy rate for one of the studio's games ([GDC 2017 slides](https://media.gdcvault.com/gdc2017/Presentations/Coster_Samuel_ButterscotchShenanigans.pdf)).
5. **Dependence on store featuring:** the GDC slides note that platform featuring multiplied downloads and revenue by about 10× ([GDC 2017 slides](https://media.gdcvault.com/gdc2017/Presentations/Coster_Samuel_ButterscotchShenanigans.pdf)). CL1 had no paid user acquisition ([Game Developer](https://www.gamedeveloper.com/business/notes-from-an-indie-cross-platform-launch)).
6. **Long tail depends on discounts:** CL1's 2024 spike came from "very aggressive discounting" ([Bscotch blog](https://blog.bscotch.net/post/2024-bscotch-wrapped/)), with Steam sales as deep as $1.49 ([Notebookcheck](https://www.notebookcheck.org/Steam-Uno-de-los-mejores-juegos-de-2016-tiene-un-90-de-descuento-en-la-plataforma.1159242.0.html)).
7. **Low revenue per platform:** Adam Coster said per-player revenue is low and some platforms bring in only about $20 a month, while every port has a fixed cost ([ShopTalk Show #632](https://shoptalkshow.com/632/)).
8. **CL2 Netflix detour:** about 16 months (June 2023 to late 2024) of a mobile-exclusive plan that was then cancelled. Mobile launched later than the 2024 Steam target and as a self-published premium app ([What's on Netflix](https://www.whats-on-netflix.com/news/why-crashlands-2-wont-be-coming-to-netflix-games/)). The revenue effect is **unverified**, but the mobile marketing story was reset late.
9. **CL2 commercial ceiling (inferred):** third-party trackers suggest Steam revenue under $1M ([gamesensor](https://gamesensor.info/app/1401730)) despite 240k wishlists. This is **unverified**, but it would mean a 4.5-year production with a reduced team earned modest Steam returns. Mobile figures are unknown.

### Player complaints with a commercial angle
- Price gap between Steam and mobile ([Steam discussion](https://steamcommunity.com/app/1401730/discussions/0/550107551434349765/)).
- Text-heavy, unvoiced writing ([Steam review](https://steamcommunity.com/profiles/76561198042198830/recommended/1401730/)).
- A "regression from first game" theme in aggregated Steam reviews ([Vaporlens](https://vaporlens.app/app/1401730/crashlands_2)).
- CL1 grew repetitive in its late game ([PC Gamer](https://www.pcgamer.com/crashlands-review/)).

---

## 13. Assets and production

- **CL1 team:** the three Coster brothers, plus an early studio burn rate of about $3,020 a month in the GDC slides ([GDC 2017 slides](https://media.gdcvault.com/gdc2017/Presentations/Coster_Samuel_ButterscotchShenanigans.pdf)). Development ran from late 2013 to January 2016 ([PocketGamer.biz](https://www.pocketgamer.biz/feature/62742/the-making-of-crashlands/)).
- **Process:**
    - "Bottom-up" design with no traditional design documents. Iconic characters and mechanics "were not premeditated" ([GDC Vault, Seth Coster 2018](https://gdcvault.com/play/1025089/-Crashlands-Design-by)).
    - A beta test was key, and building their own tools paid off ([TouchArcade on postmortem](https://toucharcade.com/2016/03/09/crashlands-postmortem-hints-at-a-worrying-trend-regarding-mobile-game-development/)).
- **CL1 tools and art:** GameMaker Studio, Inkscape vector art, a custom quest tool ("Crashlands Creator") that enabled 50k+ words in about three months, and procedural terrain with hand-authored outposts ([Game Developer](https://www.gamedeveloper.com/design/telling-stories-in-crashlands), [GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
- **CL2 team:** core content team of **two artists, one narrative designer/writer and one game programmer**, plus a small support team ([Bscotch how-made](https://www.bscotch.net/support/crashlands-2/how-made), [2024 Wrapped](https://blog.bscotch.net/post/2024-bscotch-wrapped/)). A second full-time artist, Anne Ballaran, was hired ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
- **CL2 pipeline:**
    - Clip Studio Paint for drawing, Spine for skeletal animation, GameMaker for the game, and custom tooling ([Bscotch](https://www.bscotch.net/support/crashlands-2/how-made)).
    - About 1 of 4.5 years went into tools ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-built-with-gamemaker)).
    - The first two years were spent on tools, systemic design tests and art-style experiments ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
- **CL2 bottleneck:** with **one programmer** implementing all content and systems, assets "backed up waiting their turn", and cycle times were "far too long" around year one. Adam built a new asset pipeline to fix it, and the GameMaker team was brought in to extend the engine ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-built-with-gamemaker)).
- **Asset reuse and economy:**
    - A modular 56-piece character rig means every armour piece is a layer, not a new full character sheet ([Game Rant](https://gamerant.com/crashlands-2-combat-builds-map-world-gear-items/)).
    - The telegraph system reuses one visual language for enemy attacks and player aiming ([Bscotch blog](https://blog.bscotch.net/post/crashlands-2-hand-to-pan-combat/)).
- **Audio:** **unverified**. No source covered composers or the audio pipeline.

---

## 14. Performance and smoothness on mobile

- **Controls:**
    - CL1's tap-to-move made it fully playable one-handed on phones and identical on PC. Its limits showed up in combat precision ([Gaming on Phone](https://gamingonphone.com/interviews/indie-spotlight-crashlands-2-butterscotch-shenanigans-returns-with-a-bigger-bolder-adventure/)).
    - CL2 uses a virtual stick plus buttons. Reviewers found it adequate but recommend a controller for precise dodges ([Minireview](https://minireview.io/role-playing/crashlands-2)).
    - CL2 merges attack, tools and interaction into one universal button ([Gaming on Phone](https://gamingonphone.com/reviews/crashlands-2-game-review/)).
    - CL2 has an input conflict: when you spam attack, the dodge can be ignored ([TapTap](https://www.taptap.io/app/33793848/review)).
- **Cross-save:**
    - CL1 synced saves through BscotchID, a free account ([Steam discussion](https://steamcommunity.com/app/391730/discussions/0/405692224239660874), [Game Informer](https://gameinformer.com/games/crashlands/b/pc/archive/2016/02/09/game-informer-review-crashlands.aspx)).
    - CL2 has "full cross-platform save syncing" ([press release](https://gamespress.com/Open-World-Crafting-RPG-Sequel-Crashlands-2-Available-Now-on-PC-Mobile)). Bscotch notes that save-file locations on mobile and console are "more complicated" ([Bscotch support](https://www.bscotch.net/support/crashlands-2)).
- **Visibility:** night scenes are hard to read on small screens ([TapTap](https://www.taptap.io/app/33793848/review)).
- **Device support, minimum OS, file size and frame-rate problems:** **unverified**. The store pages could not be fetched, and no source discussed performance.
- **Steam Deck:** listed as a launch platform for CL2 ([Bscotch support](https://www.bscotch.net/support/crashlands-2)).

---

## 15. Reception

### Crashlands 1
- **Praise:**
    - TouchArcade 5/5, "Holy Wompit, This Is Outstanding", praising the "incredibly compelling mixture of mechanics" and streamlined crafting ([TouchArcade](https://toucharcade.com/2016/01/20/crashlands-review/)).
    - iOS Metacritic 93 ([Wikipedia](https://en.wikipedia.org/wiki/Crashlands)).
    - TouchArcade Game of the Year 2016 ([Bscotch blog](https://blog.bscotch.net/post/crashlands-gets-toucharcades-2016-game-of-the-year-award/)).
- **Criticism:**
    - PC Gamer 73: fun but repetitive; pacing tuned for mobile ([PC Gamer](https://www.pcgamer.com/crashlands-review/)).
    - Game Informer 7.5 ([OpenCritic](https://opencritic.com/game/2173/crashlands)).
    - PC Metacritic 78, Switch 75 ([Wikipedia](https://en.wikipedia.org/wiki/Crashlands)).
- **Pattern:** a **15-point gap between mobile and PC scores** for the same game.

### Crashlands 2
- **Praise:**
    - Vice: "improves on the original in every conceivable way… a crafting/survival masterclass" ([Vice](https://www.vice.com/en/article/crashlands-2-improves-on-the-original-game-in-every-conceivable-way-and-is-a-crafting-survival-masterclass-review/)).
    - Kotaku: "a constant treat of progression and laughs" ([Kotaku](https://kotaku.com/crashlands-2-butterscotch-shenanigans-ios-android-steam-1851782672)).
    - Hardcore Gamer 4/5, Softpedia 9/10, Digital Chumps 8.3 ([OpenCritic](https://opencritic.com/game/18373/-/reviews)).
- **Criticism:**
    - GamingBolt 7/10. One OpenCritic excerpt (outlet unconfirmed) says it "doesn't particularly innovate, and some elements feel rough".
    - Combat is stat-checky, early progression is slow, and the writing is overlong ([OpenCritic](https://opencritic.com/game/18373/-/reviews), [Kotaku](https://kotaku.com/crashlands-2-butterscotch-shenanigans-ios-android-steam-1851782672)).
- **Scores:** Metacritic 82 and OpenCritic 81 ([Metacritic](https://www.metacritic.com/game/crashlands-2/), [OpenCritic](https://opencritic.com/game/18373/crashlands-2)).
- **Pattern:** the sequel narrowed the PC/mobile gap by building PC-grade art, controls and combat. Its commercial reach, however, appears smaller than the original's (estimates only; see section 1).

---

## 16. Lessons for Solvera

### Adopt
1. **Remove inventory friction completely.** Use unlimited, self-sorting storage that only surfaces relevant items, and auto-equip the right tool or weapon for the target. CL1 and CL2 both did this, and critics singled out the streamlining ([PC Gamer](https://www.pcgamer.com/how-a-terminal-cancer-diagnosis-inspired-comedy-crafting-game-crashlands/), [TouchArcade](https://toucharcade.com/2016/01/20/crashlands-review/)). For Solvera: no weapon-wheel juggling or stash micromanagement, and auto-select the weapon that fits the situation.
2. **Make one visual language serve both threat and aim.** CL2's ground telegraphs show enemy attacks and also act as the player's reticle ([Bscotch blog](https://blog.bscotch.net/post/crashlands-2-hand-to-pan-combat/)). In a 3/4 north-up crime game, project enemy gunfire cones and melee arcs on the ground with the same shape language as the player's own aim and throw arcs.
3. **Use heavy outlines and silhouette-first characters for readability on phones.** Keep CL's bold outlines and saturated palette, but author at 1080p so characters can have real proportions ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)).
4. **Make the dodge distinct and give it clear feedback.** The Juke separates a clean avoid from a reduced-damage hit ([Hardcore Gamer](https://hardcoregamer.com/review-crashlands-2/)). Give Solvera a dodge or roll with a clear success flash, and give it input priority over attack. CL2's attack-buffer conflict is a known complaint ([TapTap](https://www.taptap.io/app/33793848/review)).
5. **Cross-save from day one through a light first-party account.** It is a selling point and a retention driver ([Game Informer](https://gameinformer.com/games/crashlands/b/pc/archive/2016/02/09/game-informer-review-crashlands.aspx)).
6. **Build tools early to make content cheap.** The quest tool turned 50k words into a three-month job ([Game Developer](https://www.gamedeveloper.com/design/telling-stories-in-crashlands)). Solvera needs a mission and dialogue authoring tool in Godot before content production starts.
7. **Hand-place secrets and discoveries.** CL2 dropped procedural generation because authored discovery moments are what exploration needs ([Game Rant](https://gamerant.com/crashlands-2-combat-builds-map-world-gear-items/)). For a city, hand-place stashes, rooftop routes and hidden mission givers on a hand-built map.
8. **Use soft dailies without timers.** CL2's Strange Creatures respawn each in-game day per region ([App Store](https://apps.apple.com/us/app/crashlands-2/id1528199331)). Solvera could run daily bounty targets per district, marked on the map, with no real-time FOMO.

### Adapt
1. **Death-drop recovery runs.** CL drops half your stuff and you retrieve it ([Game Rant](https://gamerant.com/crashlands-2-survival-game-genre-inventory-loot-crafting/)). For a crime game: on "wasted", drop part of your cash or contraband at the scene as a recoverable package, and let rival gangs or police contest it.
2. **Modular character art.** CL2 uses 56 layered pieces ([Game Rant](https://gamerant.com/crashlands-2-combat-builds-map-world-gear-items/)). In Godot, use a layered 2D skeleton (Spine-like, or Godot's Skeleton2D) for the player, so outfits are cosmetic progression without new full sprite sheets. Keep the piece count lower than 56 to protect the production budget.
3. **Use the 3/4 view to support verticality.** CL1's top-down could only show knee-high walls; CL2's isometric view made roofs possible ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-game-design-interview)). Solvera's north-up 3/4 view needs roof fade-out or cutaway when the player enters buildings or passes behind tall structures. A Steam reviewer said CL2's fixed camera hides things ([Steam review](https://steamcommunity.com/profiles/76561198042198830/recommended/1401730/)).
4. **Friendship-gated unlocks.** CL2 gates recipes behind companion research ([Game Rant](https://gamerant.com/crashlands-2-interview-sequel-butterscotch-shenanigans/)). Map this to crew members who unlock weapons, vehicles or safehouse upgrades as loyalty grows.
5. **Split pricing across platforms.** Bscotch prices PC higher than mobile ([Bscotch support](https://www.bscotch.net/support/crashlands-2)). If Solvera stays premium on mobile, consider about $5–10 with free cross-save. Expect PC players to complain about the price gap ([Steam discussion](https://steamcommunity.com/app/1401730/discussions/0/550107551434349765/)), so explain it up front.
6. **Comedy writing.** Humour sold both games, but keep quest text short. CL2 was called "wildly overwritten" ([Kotaku](https://kotaku.com/crashlands-2-butterscotch-shenanigans-ios-android-steam-1851782672)). Use barks and short lines instead of walls of text on a phone screen.

### Avoid
1. **Tap-to-move or one-touch combat for action.** Bscotch abandoned it because it capped combat depth ([Gaming on Phone](https://gamingonphone.com/interviews/indie-spotlight-crashlands-2-butterscotch-shenanigans-returns-with-a-bigger-bolder-adventure/)). Use a dual-stick or stick-plus-buttons layout with aim assist, and support controllers.
2. **Procedural filler between authored points.** It made CL1 feel repetitive in its late game ([PC Gamer](https://www.pcgamer.com/crashlands-review/)).
3. **Combat that is mostly a gear check.** Both games drew "stat-checky" criticism ([OpenCritic](https://opencritic.com/game/18373/-/reviews), [GamingOnLinux](https://www.gamingonlinux.com/2018/05/story-driven-crafting-rpg-crashlands-has-a-huge-combat-overhaul/)). Give each weapon class a distinct job, as COMBOver eventually did with bleed on swords and stun on hammers.
4. **A single-programmer bottleneck.** CL2's content was blocked by one implementer ([GameMaker blog](https://gamemaker.io/en/blog/crashlands-2-built-with-gamemaker)). Make Solvera's missions data-driven so designers can add content without engineering.
5. **Depending on a platform-exclusive partner for your main market.** The CL2 Netflix plan cost about 16 months of mobile positioning ([What's on Netflix](https://www.whats-on-netflix.com/news/why-crashlands-2-wont-be-coming-to-netflix-games/)).
6. **Underestimating piracy and the long tail.** Expect the premium Android build to be pirated; CL1 had 6.6M installs against about 0.5M sales ([Bscotch blog](https://blog.bscotch.net/post/crashlands-anniversary/)). Plan server-side value tied to the account, such as cloud saves and events, rather than DRM. Plan a discount calendar too: CL1's 2024 sales came from deep discounts ([Bscotch blog](https://blog.bscotch.net/post/2024-bscotch-wrapped/)).
7. **Launching "mobile-first" art on PC without PC polish.** CL1 lost about 15 Metacritic points on PC because of the "mobile game" perception ([TouchArcade](https://toucharcade.com/2016/03/09/crashlands-postmortem-hints-at-a-worrying-trend-regarding-mobile-game-development/)).
8. **Unreadable night scenes on phones.** Clamp the minimum brightness of night and dark areas on mobile and keep threat outlines lit ([TapTap](https://www.taptap.io/app/33793848/review)).

### Gaps for a follow-up pass (could not verify)
- CL1 and CL2 quest counts, playtime and ending details.
- Audio team and pipeline.
- Mobile file sizes, minimum OS and device support.
- Official CL2 sales figures. The "week 1" blog post (17 Apr 2025) and *Coffee with Butterscotch* podcast ep. 515 ([bscotch.net/podcast/515](https://www.bscotch.net/podcast/515)) may contain them.
- The full contents of the GDC 2017 slide deck and the Game Developer postmortem, which could not be fetched.
