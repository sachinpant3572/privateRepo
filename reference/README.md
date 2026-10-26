# Top-down games reference bible

**What this is.** A study of five top-down mobile games: Stardew Valley,
Survival RPG, Crashlands, Crashlands 2 and Bad 2 Bad: Apocalypse. It covers
how they build worlds, stories, missions, combat, progression and vehicles;
how they hook players; how they use assets and stay smooth on phones; and
the mistakes that cost them players or money. Every chapter ends with what
it means for **Solvera**.

**Status:** research complete, Oct 26, 2026. Recommendations in Part C are
proposals; they change Solvera's design only once approved.

---

## Contents

**Start here**

- [How to use this bible](#how-to-use-this-bible)
- [Research method and limits](#research-method-and-limits)

**Part A. Quick reference**

- [A1. The five games at a glance](#a1-the-five-games-at-a-glance)
- [A2. The 25 most important lessons](#a2-the-25-most-important-lessons)
- [A3. Patterns all five games share](#a3-patterns-all-five-games-share)

**Part B. Topic by topic** (each compares all five games, then says what it means for Solvera)

- [B1. Overview, scale and business results](#b1-overview-scale-and-business-results)
- [B2. Camera and visual presentation](#b2-camera-and-visual-presentation)
- [B3. Core gameplay loops](#b3-core-gameplay-loops)
- [B4. World building and regions](#b4-world-building-and-regions)
- [B5. Story and narrative progression](#b5-story-and-narrative-progression)
- [B6. Missions and quests](#b6-missions-and-quests)
- [B7. Combat and weapons](#b7-combat-and-weapons)
- [B8. Progression and upgrades](#b8-progression-and-upgrades)
- [B9. Vehicles, movement and physics](#b9-vehicles-movement-and-physics)
- [B10. Things to do and explore](#b10-things-to-do-and-explore)
- [B11. Player hooks and retention](#b11-player-hooks-and-retention)
- [B12. Monetization and costly mistakes](#b12-monetization-and-costly-mistakes)
- [B13. Assets and production](#b13-assets-and-production)
- [B14. Performance and smoothness on mobile](#b14-performance-and-smoothness-on-mobile)
- [B15. Reception](#b15-reception)

**Part C. Solvera playbook**

- [C1. Decisions this research supports](#c1-decisions-this-research-supports)
- [C2. Proposed changes to Solvera's design](#c2-proposed-changes-to-solveras-design)
- [C3. Decisions for you](#c3-decisions-for-you)
- [C4. Gaps this research cannot fill](#c4-gaps-this-research-cannot-fill)

**Part D. Appendices**

- [D1. Topic finder](#d1-topic-finder)
- [D2. Glossary](#d2-glossary)
- [D3. Open questions to verify](#d3-open-questions-to-verify)

**Game dossiers** (full research, about 5,000-6,000 words each, every claim with its source)

- [Stardew Valley](games/stardew_valley.md)
- [Survival RPG (Bew Games)](games/survival_rpg.md)
- [Crashlands and Crashlands 2](games/crashlands.md)
- [Bad 2 Bad: Apocalypse](games/bad2bad_apocalypse.md)

---

## How to use this bible

- **Need an answer fast?** Read [A2](#a2-the-25-most-important-lessons), or
    look up the subject in the [topic finder](#d1-topic-finder).
- **Designing a system** (combat, missions, economy)? Read the matching Part B
    chapter. Each one has a comparison of all five games, the patterns, and a
    "For Solvera" section.
- **Need the evidence?** Every Part B chapter links to the same numbered
    section in each dossier. The dossiers hold the detail and the source links.
- **Making a decision?** Part C lists what the research supports, what it
    suggests changing, and what is your call.

Short names: **SV** = Stardew Valley, **SRPG** = Survival RPG (SRPG 1 = Lost
Treasure), **CL1 / CL2** = Crashlands / Crashlands 2, **B2B** = Bad 2 Bad:
Apocalypse.

## Research method and limits

- Four researchers each covered one dossier (Crashlands 1 and 2 together),
    using the same 16 headings, in about 170 web searches in total.
- **Full web pages could not be opened** from this environment (every page
    fetch failed), so facts come from search-engine summaries of the cited
    pages, not from reading the pages. Each fact has its source link.
- Claims the researchers could not tie to a source are marked
    **unverified** in the dossiers. This volume only repeats unverified points
    when it says so.
- Download, rating and revenue figures are snapshots; third-party estimates
    (AppBrain, SteamSpy-style trackers, data.ai) are labelled as estimates.
- Known gaps (engines, audio, file sizes, some revenue) are in
    [C4](#c4-gaps-this-research-cannot-fill) and
    [D3](#d3-open-questions-to-verify).

---

# Part A. Quick reference

## A1. The five games at a glance

| | Stardew Valley | Survival RPG 1 | Crashlands | Crashlands 2 | Bad 2 Bad: Apocalypse |
|---|---|---|---|---|---|
| Developer | Eric Barone, solo | Bew Games (credited to Eric Bouchard); size unpublished | Butterscotch Shenanigans, 3 brothers | Same studio; core content team of 4 | DAWINSTONE (Korea); size unpublished |
| Mobile release | iOS Oct 2018, Android Mar 2019 (PC 2016) | iOS May 2017 | Jan 2016, mobile and PC same day | Apr 2025, mobile and PC same day | Korea Nov 2022; global Feb 2023 |
| Engine | C#, XNA → MonoGame | Unknown | GameMaker | GameMaker + Spine | Unity |
| Mobile model | Premium $7.99, no IAP | Free: ads + diamond IAP | Premium ~$5 | Premium $9.99 | Free: rewarded ads + IAP |
| Scale | 41M+ copies, all platforms | ~9.6M installs (estimate); series ~20M | 500k+ units by 2017 | No official figures | 5M+ Google Play (~9.3M estimate) |
| Ratings | Metacritic 89; Steam ~98% | Google Play ~4.6 | iOS Metacritic 93; PC 78 | Metacritic 82 | Google Play 4.3; Steam 77% |
| View | 3/4 top-down, north up, 16 px tiles | Retro top-down pixel art | Top-down, slight tilt, 540p | Isometric 2D, 1080p | Top-down 2D |
| World | Handmade maps; procedural dungeons | Handmade islands, tool-gated | Procedural biomes + handmade outposts | Fully handmade | 60+ handmade, level-tagged zones |
| Vehicles | Horse, minecarts, bus, boat | Canoe, ship | None | None (pets) | Helicopter fast travel; one mech set piece |
| Biggest strength | Depth for the price, warmth, no timers | Satisfying crafting, offline, small size | No inventory friction, humour | Hand-built discovery, readable combat | Squad + guns + base loop, F2P-friendly |
| Biggest mistake | Mobile years behind PC | Selling fixes for designed-in grind | One-touch combat; procedural filler | Text walls; Netflix detour | Scarcity grind tuned for IAP |

Details: [B1](#b1-overview-scale-and-business-results) and each dossier's section 1.

## A2. The 25 most important lessons

Grouped by area. Each points to its chapter.

**Controls and feel**

1. **Never use tap-to-move or one-touch combat for action.** Stardew's mobile
   combat was its most criticised system, and Crashlands dropped one-touch
   combat because it capped depth. Use a floating stick plus buttons.
   ([B7](#b7-combat-and-weapons))
2. **One context action button** (attack, enter, talk, pick up) keeps the
   phone HUD small. Survival RPG, Stardew's auto-select tool and Crashlands 2
   all rely on it. Its responsiveness is the most noticed metric.
   ([B14](#b14-performance-and-smoothness-on-mobile))
3. **Auto-aim ring on touch, manual aim on gamepad and PC.** Bad 2 Bad's
   ring is praised; its PC version switched to manual aim. ([B7](#b7-combat-and-weapons))
4. **Give dodge priority over attack.** Crashlands 2 players lose dodges
   while spamming attack. ([B7](#b7-combat-and-weapons))
5. **Ship a control layout editor and controller support at launch.**
   Stardew added both after launch; Bad 2 Bad never added layout editing and
   players asked for it. ([B14](#b14-performance-and-smoothness-on-mobile))

**World and story**

6. **Build the world by hand.** Every game that tried procedural worlds moved
   away: Crashlands 2 went fully handmade, Bad 2 Bad dropped Extinction's random
   maps. Stardew keeps procedural only for repeatable dungeons. ([B4](#b4-world-building-and-regions))
7. **Unlock areas by repairing or taking over the world,** not by level:
   Stardew's bus, bridge and minecarts; Bad 2 Bad's helipads; Survival RPG's
   ladder, canoe and explosives. ([B4](#b4-world-building-and-regions))
8. **Fewer, denser areas beat many thin ones.** Bad 2 Bad's 60+ zones are
   criticised as recycled. ([B4](#b4-world-building-and-regions))
9. **Story pulled by the player** (relationship events when you arrive
   somewhere) is cheap in a top-down engine and loved in Stardew.
   ([B5](#b5-story-and-narrative-progression))
10. **Keep text short.** Crashlands 2 was called "wildly overwritten".
        ([B5](#b5-story-and-narrative-progression))
11. **Moral choices should change story, not access.** Stardew's
        Community Center vs Joja unlocks the same places. ([B5](#b5-story-and-narrative-progression))

**Missions and progression**

12. **Turn normal play into progress** with themed checklists (Stardew's
        bundles), so no activity is wasted. ([B6](#b6-missions-and-quests))
13. **Never allow a soft-lock.** Survival RPG's limited ore can make a run
        unfinishable. Story-critical items must respawn. ([B6](#b6-missions-and-quests))
14. **No inventory friction.** Crashlands' unlimited, self-sorting inventory
        was singled out by critics. ([B8](#b8-progression-and-upgrades))
15. **Give each weapon class a distinct job,** or combat becomes a gear check
        (both Crashlands games). ([B7](#b7-combat-and-weapons))
16. **Daily goals without real-time timers** (Stardew's job board,
        Crashlands 2's daily Strange Creatures). ([B11](#b11-player-hooks-and-retention))

**Retention and business**

17. **A short in-game day with a payout and save at the end** creates
        "one more day" sessions (Stardew ~14 min, Bad 2 Bad ~20 min).
        ([B3](#b3-core-gameplay-loops))
18. **Free content updates are the best marketing beats.** Each Stardew
        update set a player record; sales went from 30M to 41M in 2024.
        ([B11](#b11-player-hooks-and-retention))
19. **Never sell relief from pain you designed in** (Survival RPG's diamonds,
        Bad 2 Bad's paid storage). ([B12](#b12-monetization-and-costly-mistakes))
20. **No interstitial ads at area transitions;** rewarded ads only, after
        missions. ([B12](#b12-monetization-and-costly-mistakes))
21. **Free-to-play installs don't equal revenue.** Survival RPG's ~20M
        installs earn little (estimate: under $5K a month for SRPG 1 on the US
        App Store). ([B12](#b12-monetization-and-costly-mistakes))
22. **Premium Android gets pirated.** Crashlands had 6.6M installs against
        ~500k sales. Tie value to the account (cloud saves, events).
        ([B12](#b12-monetization-and-costly-mistakes))

**Production and tech**

23. **Build tools before content.** Crashlands' quest tool let two people
        write 50,000+ words in three months; Crashlands 2 spent a year on tools.
        ([B13](#b13-assets-and-production))
24. **Auto-save, cloud save and offline play at launch.** Stardew lacked
        iCloud at launch; Survival RPG added cloud saves in its ninth year.
        ([B14](#b14-performance-and-smoothness-on-mobile))
25. **Test on low-RAM Android and small phones,** not iPads. Stardew still
        crashes on 2 GB devices, and the iPad hid its touch problems.
        ([B14](#b14-performance-and-smoothness-on-mobile))

## A3. Patterns all five games share

- **Top-down readability first.** Bold outlines, chunky silhouettes, one
    consistent scale, clear night and danger states.
- **A safe home** to return to: Stardew's farm, Crashlands' base, Bad 2
    Bad's camp, Survival RPG's shelter.
- **Crafting or upgrading as the main progression,** with almost no XP
    grinding in Survival RPG and Crashlands.
- **Small teams,** one to four core people, with heavy reuse of systems.
- **Long tails from updates:** Stardew and Survival RPG 1 were still being
    updated 8-9 years after release; Bad 2 Bad three years after.
- **Weak spots in combat on touch** in every game except Bad 2 Bad, which
    designed its combat around touch from the start.
- **None of them has real driving.** For Solvera's core fantasy, this group
    gives no template ([B9](#b9-vehicles-movement-and-physics), [C4](#c4-gaps-this-research-cannot-fill)).

---

# Part B. Topic by topic

## B1. Overview, scale and business results

Deep dives: [Stardew](games/stardew_valley.md#1-overview-and-facts) ·
[Survival RPG](games/survival_rpg.md#1-overview-and-facts) ·
[Crashlands](games/crashlands.md#1-overview-and-facts) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#1-overview-and-facts)

| | Team | Dev time | Price (mobile) | Sales / installs | Revenue signal |
|---|---|---|---|---|---|
| SV | 1 | ~4.5 years | $7.99 premium | 41M+ copies all platforms (26M+ PC) | iOS >$1M in ~3 weeks (Sensor Tower) |
| SRPG | 1 credited | ~10-12 months per game | Free + IAP | ~20M installs across 6 apps (estimate) | SRPG 1 US App Store < $5K/month (estimate) |
| CL1 | 3 | ~2.3 years | ~$5 premium | 500k+ units by Aug 2017, mostly mobile | Paid 2 years' backpay, doubled team, 1 year runway |
| CL2 | ~4 core | ~4.5 years | $9.99 premium | Not published | Steam < $1M (third-party estimate) |
| B2B | Small | ~1-2 years (unverified) | Free + IAP | 5M+ Google Play (~9.3M estimate) | Not public |

**Patterns**

- **Premium can work on mobile** when depth is high and word of mouth is
    strong (Stardew, Crashlands 1). Crashlands 1 sold mostly on mobile.
- **Free-to-play gives reach, not necessarily money.** Both free games have
    millions of installs; neither shows strong revenue, and Survival RPG's
    estimate is small.
- **Launching mobile and PC together** worked for Crashlands, but PC critics
    scored it 15 points lower as a "mobile game".

**For Solvera**

- The business model is still open in `MVP_DESIGN.md` (proposed:
    free-to-play with cosmetics and rewarded ads). This research argues that
    whichever model is picked, the economy must be tuned for it from the start
    (see [B12](#b12-monetization-and-costly-mistakes) and
    [C3](#c3-decisions-for-you)).

## B2. Camera and visual presentation

Deep dives: [Stardew](games/stardew_valley.md#2-camera-and-visual-presentation) ·
[Survival RPG](games/survival_rpg.md#2-camera-and-visual-presentation) ·
[Crashlands](games/crashlands.md#2-camera-and-visual-presentation) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#2-camera-and-visual-presentation)

| | View | Scale and style | Readability tools | Problems |
|---|---|---|---|---|
| SV | 3/4 oblique, north up; ground flat, fronts visible | 16x16 px tiles; characters 16x32; portraits 64x64; seasonal recolours | The tile grid is the interaction unit; blocked paths shown red on mobile | Small text and tap targets on phones |
| SRPG | Retro top-down pixel art (exact angle unverified) | Pixel art, remastered in 2024 | Night tint plus night enemies; candle light radius in dungeons; fog-of-war map | Some dislike the retro look |
| CL1 | Top-down, slight tilt | 540p, so big-headed "mascot" characters | Heavy black outlines, saturated colour, silhouette-first creatures | Only knee-high walls possible; art "rough" |
| CL2 | Isometric 2D (still 2D in GameMaker) | 1080p; player built from 56 animated gear pieces | Ground telegraphs for enemy attacks, also the player's aim; map icons for minibosses | Fixed camera hides things; night too dark on phones |
| B2B | Top-down 2D | Cartoon animal soldiers; gear visible on sprites | Auto-aim ring; arrow to unfound squad; enemy health bars unlocked via a drone | Low-res textures on mobile, fixed for PC |

**Patterns**

- **3/4 top-down with north up** is the standard (Stardew directly; the
    others close to it). It supports Solvera's camera decision.
- **Readability beats detail on small screens:** outlines, silhouettes,
    one consistent pixel density. Stardew mods that mix resolutions look wrong.
- **Height is the top-down view's weak spot.** Crashlands 1 could only show
    knee-high walls; Crashlands 2 changed view largely to allow roofed buildings.
- **Night is a readability trap** on phones (Crashlands 2 complaints).

**For Solvera**

- Keep the 3/4 north-up view (already decided) and **one scale grid**:
    characters about 1x2 tiles, cars about 2x4, applied to all 3D models.
- **Bold outlines and silhouette-first designs**, authored at 1080p
    (Crashlands 2), so characters can have real proportions.
- The **cutaway and silhouettes** already in the prototype solve the height
    problem Crashlands 1 had; keep them.
- **Clamp night brightness** on mobile and keep threat outlines lit.
- Keep **danger indicators on from the start**; unlock extras (like a police
    scanner) as rewards, the way Bad 2 Bad unlocks enemy health bars.

## B3. Core gameplay loops

Deep dives: [Stardew](games/stardew_valley.md#3-core-gameplay-loops) ·
[Survival RPG](games/survival_rpg.md#3-core-gameplay-loops) ·
[Crashlands](games/crashlands.md#3-core-gameplay-loops) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#3-core-gameplay-loops)

| | Moment to moment | Session | Long term |
|---|---|---|---|
| SV | Pick a tool, act on a tile, watch energy and clock | One in-game day ≈ 14 real minutes; sleep = payout + save | Seasons (28 days), Community Center, Year-3 evaluation, Perfection |
| SRPG | Stick + one action button: gather, mine, fight | Gather → craft at shelter → new tool opens new area | Finite story goal over 7 chapters; replay ranks and hardcore |
| CL1 | Tap to harvest or attack; auto tool use | Quest needs recipe → recipe needs creature parts → craft gear that beats it | Three biomes, each a new crafting tier and boss |
| CL2 | Analog stick, telegraphs, dodge roll | Same chain, recipes now from friends' research; daily minibosses | Home, farming, pets, side bosses, Juice Forge |
| B2B | Move leader; auto-aim ring picks targets | Leave base → helipad → loot → home before night (~20 min days) | Recruit squad, 28 base upgrades, gun generations, World Missions |

**Patterns**

- **A day clock sets the session length.** Stardew (~14 min) and Bad 2 Bad
    (~20 min) both end sessions naturally with a return home.
- **The overnight payout and save** is the reward beat (Stardew).
- **Crafting chains keep the next goal visible** (Crashlands, Survival RPG).

**For Solvera**

- Adopt a **day/night cycle of about 10-15 minutes** where night changes
    gameplay (more police, different gangs, night-only jobs), not just
    difficulty, and never forces a return home.
- End each night with a **"night ledger"**: business income, fence sales,
    wanted level reset, auto-save. It is a natural phone session break.
- **No energy bar that ends play.** Stardew's energy works for farming; a
    crime game needs freedom.

## B4. World building and regions

Deep dives: [Stardew](games/stardew_valley.md#4-world-building-and-regions) ·
[Survival RPG](games/survival_rpg.md#4-world-building-and-regions) ·
[Crashlands](games/crashlands.md#4-world-building-and-regions) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#4-world-building-and-regions)

| | Structure | How areas unlock | Secrets | Criticism |
|---|---|---|---|---|
| SV | Small handmade maps joined at edges; 8 farm map choices | Repair the town: bus (Vault bundles or 40,000g to Joja), quarry bridge, minecarts; Skull Key; walnuts on Ginger Island | Golden walnuts, secret notes, hidden rewards | Few: dense and handmade |
| SRPG | Handmade islands, dungeons and caves; later games 30-50+ locations | Tools: ladders, canoe, compass, explosives, candle | Metal detector, treasure maps, puzzles | Opaque puzzle gates (lava crossing) |
| CL1 | Procedural biomes with handmade outposts on top | Story items per biome | Few | Procedural filler felt samey late on |
| CL2 | Fully handmade world in three regions | Story and friendship | Weapons, recipes and quests hidden on purpose | Fixed camera hides things |
| B2B | 60+ separate handmade zones on a grid, each level-tagged | Zone level (soft gate); helipads repaired for 50 scrap | Bunkers, gear cores, Battle Armor sites | Repetitive, "heavy asset recycling" |

**Patterns**

- **Handmade wins.** Crashlands 2 ("the most significant fundamental
    change") and Bad 2 Bad both moved from procedural to handmade.
- **Unlocks the player can see** (a repaired bridge, a working minecart, a
    claimed helipad) read as story and as progress at once.
- **Reuse a map in several states** for more content per tile set: Survival
    RPG 4 uses one map in two eras; Stardew recolours the world each season.
- **Too many thin zones** feel recycled (Bad 2 Bad).

**For Solvera** (already partly in place)

- The **handmade map** in `game/data/world_map.json` matches this lesson.
- Add **visible unlock infrastructure:** take a gang's turf to reopen a
    streetcar line, fund the Crescent Bridge repair, claim a garage as a fast
    travel point (like Bad 2 Bad's helipads).
- Show a **heat or level tag per district** on the map (Bad 2 Bad).
- Use **district states** to multiply content: day/night, gang-held vs
    liberated, before/after the storm (Floodline Wards already has a storm
    story in mission 9).
- Keep districts **few and dense**; give each a distinct palette, props and
    landmarks.

## B5. Story and narrative progression

Deep dives: [Stardew](games/stardew_valley.md#5-story-and-narrative-progression) ·
[Survival RPG](games/survival_rpg.md#5-story-and-narrative-progression) ·
[Crashlands](games/crashlands.md#5-story-and-narrative-progression) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#5-story-and-narrative-progression)

| | Premise | Delivery | Tone | Ending |
|---|---|---|---|---|
| SV | Inherit Grandpa's farm, escape a corporate job | Heart events triggered by friendship + location; daily dialogue; mail; festivals | Warm, with real themes | No end; Year-3 evaluation, Community Center, Perfection |
| SRPG | One-line mystery per game (lost treasure, artifact) | 7 chapters; NPC quests in later games | Light adventure | Finite; artifact thread links games 2-4 |
| CL1 | Space trucker stranded by a villain | Quest dialogue boxes; 50,000+ words | Absurd comedy | Story finale (details unverified) |
| CL2 | The trucker returns | Friends' research quests; full-time writer | "Goofy to gut-punching" | Unverified |
| B2B | Squad leader stranded after a crash in a zombie world | Recruit the scattered squad; linear story missions | Cute animals, grim war | Final boss fight |

**Patterns**

- **Stranded or returning hero** is the common opening (Survival RPG,
    Crashlands, Bad 2 Bad), like Jules returning to Bellerive.
- **Story pulled by the player** (Stardew's heart events) costs little in a
    top-down engine: sprites, emotes, portrait dialogue.
- **Text walls hurt on phones** (Crashlands 2).
- **A story that runs across games** helps sequels (Bad 2 Bad, Survival RPG).
- **Linear story in an open world** draws criticism (Bad 2 Bad).

**For Solvera** (act 1 already follows several of these)

- Act 1's **return-home premise and crew recruitment** match the strongest
    openings here.
- Add **relationship events** for Nia, Celeste, Pops and Teo, triggered by
    trust level and location, in the in-game camera with portraits.
- **Keep lines short;** use barks and short exchanges instead of text walls.
- The **Two Crowns** finale must change story and reputation, not lock the
    player out of districts (Stardew's Joja lesson).
- Let acts **branch by faction and district** so the open world matters.

## B6. Missions and quests

Deep dives: [Stardew](games/stardew_valley.md#6-missions-and-quests-design) ·
[Survival RPG](games/survival_rpg.md#6-missions-and-quests-design) ·
[Crashlands](games/crashlands.md#6-missions-and-quests-design) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#6-missions-and-quests-design)

| | Main types | Repeatable content | Weak points |
|---|---|---|---|
| SV | Short teaching chain; 30 bundles in 6 rooms; Special Orders | Daily Help Wanted board (no penalty for ignoring); kill-count goals | Few: quests are checklists over systems you already use |
| SRPG | "Find or build X to open Y"; NPC quests later; puzzles | Replay ranks, hardcore mode | Soft-locks (limited ore), unclear solutions, hints behind ads |
| CL1 | Main, side, menial and heroic quests from outposts | Hunts, taming | "Seemingly endless" fetch and kill quests |
| CL2 | Friends' research quests; hidden hand-placed quests | Daily Strange Creatures; side bosses | Slow early progression |
| B2B | Linear story; recruit quests; World Missions | Extermination missions, bunkers, Wilder pits | Long dungeons with weak rewards; a threat that blocks extraction |

**Patterns**

- **Checklists over existing systems** (Stardew bundles) make every
    activity count toward the main goal.
- **Soft dailies without real-time pressure** keep players returning.
- **Every optional clear needs a reward that matters** (Bad 2 Bad's tedious
    bunkers).
- **Never let progress depend on a finite resource** (Survival RPG).

**For Solvera**

- Add **district boards** (bundles): "Ironwharf job: deliver 3 stolen
    sports cars + 5 contraband crates" → cash plus a visible world change.
- Add **daily bounties per district**, marked on the map, with no real-time
    expiry.
- Mission markers and a **hint option** so no one needs a wiki.
- Story-critical items **respawn** or have a fallback source.
- Every bunker-style optional mission ends in a **guaranteed, useful
    reward**.

## B7. Combat and weapons

Deep dives: [Stardew](games/stardew_valley.md#7-combat-and-weapons) ·
[Survival RPG](games/survival_rpg.md#7-combat-and-weapons) ·
[Crashlands](games/crashlands.md#7-combat-and-weapons) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#7-combat-and-weapons)

| | Touch input | Weapons | Enemies and bosses | Criticism |
|---|---|---|---|---|
| SV | Tap-to-move + auto-attack by default; joystick + buttons added later | Swords, daggers, clubs, slingshot; forge and enchantments late | Depth-based dungeons; few bosses | Mobile combat the most criticised system |
| SRPG | D-pad + one action button | Crafted tiers (wood → metal); swords, spells, bows later | Night snakes; a few bosses per game | Action button lag; tough bosses |
| CL1 | One-touch: tap a target, walk and attack | Gear sets per biome; 2018 patch gave weapon types roles (bleed on swords, stun on hammers) | Story bosses, legendary creatures | "Fell flat over time"; gear check |
| CL2 | Analog stick; telegraphs double as aim; Juke dodge roll | Throwables, knuckles, gadgets, crushers, spears and daggers | Daily minibosses; side bosses | "Stat-checky"; attack spam swallows dodge |
| B2B | Stick + fire; auto-aim ring; auto-fire option | 8 gun classes × 5 generations; 7 attachment slots; crafted ammo | Zombies stronger at night; 10+ bosses | Some player DPS rankings show weak classes |

**Patterns**

- **Touch combat succeeds when designed for touch from day one** (Bad 2
    Bad's ring). It struggles when ported from mouse or tap-to-move (Stardew,
    Crashlands 1).
- **Distinct roles per weapon class** fix "gear check" combat.
- **One visual language** for threat and aim (Crashlands 2 telegraphs).
- **Proficiency that carries over** when upgrading a weapon keeps
    investment (Bad 2 Bad).

**For Solvera**

- **Floating stick + context action button + dodge**, with an auto-aim
    ring on touch and manual aim on gamepad. The prototype already has the
    stick and context buttons; aim ring and dodge are next.
- Draw **enemy gunfire cones and melee arcs on the ground** in the same
    shape language as the player's aim and throw arcs.
- **Dodge has input priority over attack,** with a clear success flash.
- Each weapon class gets **one job** (pistol: mobile; shotgun: crowd
    stagger; rifle: range; SMG: drive-by), with a small number of tiers.
- Crew followers with **formation presets**, capped at 3 for readability.

## B8. Progression and upgrades

Deep dives: [Stardew](games/stardew_valley.md#8-progression-and-upgrades) ·
[Survival RPG](games/survival_rpg.md#8-progression-and-upgrades) ·
[Crashlands](games/crashlands.md#8-progression-and-upgrades) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#8-progression-and-upgrades)

| | Player power | Gear and tools | Base | Economy | Gating |
|---|---|---|---|---|---|
| SV | 5 skills to level 10; profession picks at 5 and 10, respec possible | Tool tiers (2,000g → 25,000g), each upgrade takes 2 in-game days | Farm buildings | Crops → artisan goods → endgame crops | Season, time, world repair, depth, collections; never real-world time |
| SRPG | No XP; power from crafted gear | 40-85 recipes | Shelter, stations | Materials + premium diamonds | Items and tools; no timers |
| CL1 | Gear | 500+ craftable items; unlimited inventory | Floor-plan bases | Materials | Story biomes |
| CL2 | Gear from 56 visible pieces | Juice Forge re-roll and upgrade | Real buildings with roofs, roommates | Materials | Friendship research |
| B2B | Character stats; leader's speed sets squad speed | Gun generations; repairs cost scrap | 28 fixed facility upgrades | Scrap + materials; scarce | Zone levels, scrap, drop luck |

**Patterns**

- **Remove friction, keep choices:** unlimited inventory (Crashlands),
    auto tool selection (Stardew).
- **Downtime as opportunity cost** (Stardew's 2-day tool upgrade) nudges
    players to other activities without real-time timers.
- **Fixed facility upgrades** (Bad 2 Bad) are far cheaper to build and test
    than free-placement building.
- **Scarcity tuned for selling** backfires (Survival RPG, Bad 2 Bad).

**For Solvera**

- **No stash micromanagement;** auto-select the right weapon or tool.
- **Garage time instead of timers:** a car in the chop shop until next
    in-game morning.
- **Crime careers** with picks at milestones and paid respec (Driver:
    getaway or smuggler; Gunman: enforcer or marksman).
- **Safehouse facility upgrades** in fixed slots (garage, armory, bed,
    wardrobe), visible on the building.

## B9. Vehicles, movement and physics

Deep dives: [Stardew](games/stardew_valley.md#9-vehicles-mounts-movement-and-physics) ·
[Survival RPG](games/survival_rpg.md#9-vehicles-mounts-movement-and-physics) ·
[Crashlands](games/crashlands.md#9-vehicles-mounts-movement-and-physics) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#9-vehicles-mounts-movement-and-physics)

| | Vehicles | Fast travel | Physics |
|---|---|---|---|
| SV | Horse (+30% speed), bus, boat | Minecarts, totems (earned by repairs) | None simulated |
| SRPG | Canoe, ship (as range gates) | None found | Simple tile movement |
| CL1 | None; pets follow | Unverified | Knockback and stun only |
| CL2 | None; pets | Unverified | Same; dodge roll is core movement |
| B2B | No drivable vehicles; helicopter is a menu; one mech set piece | Repaired helipads | Simple collision |

**Patterns**

- **None of the five has real driving.** Movement upgrades are modest; most
    time saved comes from **earned shortcut networks** (minecarts, helipads).
- **Boats as gates** to new regions (Survival RPG) is a strong mid-game beat.

**For Solvera**

- Driving is Solvera's core fantasy and **its biggest gap in this
    research**. Take references from games that do top-down driving (for
    example GTA: Chinatown Wars and GTA 2) in a follow-up study
    ([C4](#c4-gaps-this-research-cannot-fill)).
- Keep the **earned shortcut** idea: claimed garages and the streetcar as
    fast travel.
- The **first boat** that opens the bayou and the river (act 1 mission 5)
    is the right kind of gate.
- **Set-piece vehicles** (a helicopter chase, a tank) at fixed story moments,
    like Bad 2 Bad's mech.

## B10. Things to do and explore

Deep dives: [Stardew](games/stardew_valley.md#10-things-to-do-and-activities) ·
[Survival RPG](games/survival_rpg.md#10-things-to-do-and-activities) ·
[Crashlands](games/crashlands.md#10-things-to-do-and-activities) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#10-things-to-do-and-activities)

| | Highlights |
|---|---|
| SV | 8+ fixed-date festivals with minigames and a token currency; two arcade games inside the world; museum, fish and recipe collections; romance and marriage; co-op |
| SRPG | Fishing, farming, treasure maps, puzzles, dungeons, time-era hopping; achievements and ranks |
| CL1 | Taming every creature, 500+ items, boss hunts, fishing, base decoration |
| CL2 | Home with roommates, farming, egg hatching, daily miniboss hunts, collection log |
| B2B | Looting, fishing and cooking, dungeons, boss hunts, squad and skin collecting |

**Patterns:** collections with a visible tracker (Stardew's Perfection,
Crashlands 2's Compendium); calendar events; small games inside the game.

**For Solvera**

- **City events on a calendar:** street race night, carnival, Mardi
    Gras-style parade, each with its own minigames and token currency.
- An **arcade cabinet** in the Blue Lantern (a top-down shooter reusing
    existing systems).
- A **collection log**: cars stolen, outfits, hidden packages, legends found.

## B11. Player hooks and retention

Deep dives: [Stardew](games/stardew_valley.md#11-player-hooks-and-retention) ·
[Survival RPG](games/survival_rpg.md#11-player-hooks-and-retention) ·
[Crashlands](games/crashlands.md#11-player-hooks-and-retention) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#11-player-hooks-and-retention)

| | First session | Daily reason to return | Long-term | Long tail |
|---|---|---|---|---|
| SV | Grandpa letter, arrival, 4-day parsnips for a fast payoff | "One more day"; no real-world timers | Community Center, marriage, Perfection | Free updates set player records |
| SRPG | One-line mystery, first tools | Constant small unlocks | Finish the story | Sequels; replay ranks; updates for 9 years |
| CL1 | Crash, first crafts | Next craftable always in view | Biomes and bosses | Discounts, Switch co-op |
| CL2 | Return to the planet | Daily minibosses | Home, pets, side bosses | Post-launch modes and forge |
| B2B | Crash; find your squad | Get home before night | Gear chase, 28 base upgrades | Updates 3 years on; series loyalty |

**Patterns**

- **A fast first payoff** (Stardew's 4-day crop) and a **clear first goal**
    (Bad 2 Bad's missing squad).
- **No real-world timers** is praised directly by reviewers (TouchArcade on
    Stardew).
- **Content updates as events** bring players back.
- **Cross-save** (Crashlands) lets players switch between phone and PC.

**For Solvera**

- First session: arrival, the bag-thief chase, a fight and a car within
    minutes (act 1 mission 1 already does this).
- Daily: district bounties, business income in the night ledger.
- Long term: crew loyalty, turf control, collections, then free district
    updates as events.

## B12. Monetization and costly mistakes

Deep dives: [Stardew](games/stardew_valley.md#12-monetization-and-mistakes) ·
[Survival RPG](games/survival_rpg.md#12-monetization-and-mistakes) ·
[Crashlands](games/crashlands.md#12-monetization-and-mistakes) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#12-monetization-and-mistakes)

**Models**

| | Model | What sold | Ads |
|---|---|---|---|
| SV | Premium, free updates forever | The game; Apple Arcade version | None found |
| SRPG | Free | Remove Ads ($0.99 → $2.99), diamond packs ($3.99-$9.99), bundle $12.99 | Interstitials at area transitions; rewarded hints |
| CL1/CL2 | Premium per platform, free cross-save | The game | None |
| B2B | Free on mobile; $19.99 premium on PC | Remove Ads $7.99, starter pack, material packs, storage, skins, characters | Mostly optional rewarded |

**The costly mistakes**

| Mistake | Who | Effect |
|---|---|---|
| Selling relief from designed-in grind | SRPG (diamonds replace resources; cost reportedly tripled), B2B (paid storage, material packs) | "Cash grab" complaints; years of rebalancing (B2B) |
| Keeping a free-to-play economy in a premium version | B2B on PC | Called a "relaunch of a F2P, pay-to-win mobile title" |
| Interstitial ads at transitions; ad crashes | SRPG; B2B | Resented; crashes and save loss |
| Mobile lagging PC by years | SV | Broke save transfer and multiplayer parity |
| Hidden or late features | SV mobile multiplayer behind a secret code | Low discoverability |
| One-touch combat, procedural filler | CL1 | Late-game repetition; 15-point lower PC score |
| Platform-exclusive deal | CL2 with Netflix (cancelled) | ~16 months of mobile plans reset |
| Fragmented store names | SRPG | Diluted brand and search |
| Thin monetization on a finite game | SRPG | ~20M installs, small revenue (estimate) |
| Piracy on premium Android | CL1 | 6.6M installs vs ~500k sales |

**For Solvera** (whatever model is chosen)

- **Tune the economy for the chosen model first;** never sell shortcuts to
    pain the design creates.
- **Rewarded ads only, after missions, capped;** a one-time "Remove ads +
    starter pack".
- **Cosmetics, vehicles and outfits** as the main paid items; a fair price
    for any premium story pack.
- **One brand word** in every store title ("Solvera: …").
- **Value tied to the account** (cloud save, events) to soften piracy.
- **No exclusive platform deals** for the main market.

## B13. Assets and production

Deep dives: [Stardew](games/stardew_valley.md#13-assets-and-production) ·
[Survival RPG](games/survival_rpg.md#13-assets-and-production) ·
[Crashlands](games/crashlands.md#13-assets-and-production) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#13-assets-and-production)

| | Team and tools | Reuse | Handmade vs procedural | Audio |
|---|---|---|---|---|
| SV | One person; redid art many times | Seasonal recolours; standard sprite sheets | Handmade world and events; procedural dungeons and daily jobs | ~70 original tracks, now concert tours |
| SRPG | One credited person; ~1 game a year | Same systems each game; one map in two eras | Handmade | Unknown |
| CL1 | 3 people; custom quest tool (50k+ words in 3 months) | Procedural terrain | Procedural biomes + handmade outposts | Unknown |
| CL2 | ~4 core; Clip Studio, Spine; a year on tools | 56-piece character rig; one telegraph language | Fully handmade | Unknown |
| B2B | Small team; Unity | Gear layers on one rig; shared tiles; heavy zone reuse | Handmade zones | Unknown |

**Patterns**

- **Tools first** pays back (Crashlands quest tool; a year of tools for CL2).
- **One programmer is a bottleneck** (CL2 content queued behind them).
- **Modular characters** multiply variety (CL2's 56 pieces, B2B's helmets).
- **Reuse is fine when it changes the experience** (seasons, eras); it hurts
    when players see the same zone again (B2B).

**For Solvera**

- Missions are already **data-driven** (`game/data/missions_act1.json`).
    Next: a simple **mission and dialogue editor** so content doesn't wait on
    code.
- Characters as **swappable 3D parts** (head, hair, top, bottom, shoes,
    hat) for outfits as cosmetic progression.
- AI-generated music per district (decided) plus a small set of
    hand-polished themes.

## B14. Performance and smoothness on mobile

Deep dives: [Stardew](games/stardew_valley.md#14-performance-and-smoothness-on-mobile) ·
[Survival RPG](games/survival_rpg.md#14-performance-and-smoothness-on-mobile) ·
[Crashlands](games/crashlands.md#14-performance-and-smoothness-on-mobile) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#14-performance-and-smoothness-on-mobile)

| | Controls | Saves | Known issues | Size |
|---|---|---|---|---|
| SV | 4 schemes + layout adjuster + controllers (added after launch) | Auto-save added after launch; no iCloud at launch | Crashes on 2 GB Android; mobile UI code lost in a merge | ~465 MB iOS |
| SRPG | D-pad + action button | Cloud save added in year 9 | D-pad too far in on iPad; action button lag | ~50-56 MB |
| CL1 | Tap-to-move, one-handed | Cross-save via a free account | Combat precision | Unverified |
| CL2 | Stick + one universal button | Full cross-platform save | Dodge lost while spamming attack; dark nights | Unverified |
| B2B | Stick + fire + auto-aim; fixed layout | Steam Cloud on PC; mobile unverified | Crashes when ads load; save loss | Unverified |

**For Solvera** (launch checklist)

- **Controls:** floating stick, context button, dodge, auto-aim ring;
    layout editor (size, opacity, position); controller support; touch
    targets at least 44-48 dp; scalable text.
- **Saves:** auto-save when the app goes to the background; cloud save
    (Google Play Games, iCloud); offline play.
- **Devices:** set a RAM floor; stream districts and unload on
    transitions; test on 2-3 GB Android phones and small phones in CI.
- **Ads (if used):** load off the main thread, never during combat; test
    online with ads enabled.
- **One release train** for all platforms; platform UI behind tested
    layers.
- **Small base install**, with optional packs downloaded later.

## B15. Reception

Deep dives: [Stardew](games/stardew_valley.md#15-reception) ·
[Survival RPG](games/survival_rpg.md#15-reception) ·
[Crashlands](games/crashlands.md#15-reception) ·
[Bad 2 Bad](games/bad2bad_apocalypse.md#15-reception)

| | Praised for | Criticised for |
|---|---|---|
| SV | Depth for the price, warmth, no timers or IAP, free updates | Shallow combat, fishing difficulty; on mobile: precision taps, small text, crashes |
| SRPG | Satisfying crafting, puzzles, offline, fair IAP | Grind, ads, controls, soft-locks, linearity; almost no press coverage |
| CL1 | Streamlined crafting, humour (TouchArcade 5/5, Game of the Year) | Repetition; "tuned for mobile" (PC Gamer 73) |
| CL2 | "Improves on the original in every conceivable way" (Vice) | Stat-checky combat, slow start, overwritten |
| B2B | Addictive loop, squad depth, no pressure to pay, offline | Grind, recycled world, scarce economy, ad crashes |

**For Solvera:** the most-praised traits (no timers, no pressure to pay,
offline play, depth, humour) cost little to keep. The most-criticised
(grind, ads, combat on touch, crashes) are all avoidable with the
decisions in Part C.

---

# Part C. Solvera playbook

## C1. Decisions this research supports

These match choices already made; the research gives them more evidence.

| Solvera decision | Evidence |
|---|---|
| 3/4 top-down view, north up | Stardew uses it; the others are close ([B2](#b2-camera-and-visual-presentation)) |
| Cutaway and silhouettes for tall buildings | Crashlands 1's knee-high-wall limit and CL2's "camera hides things" complaints ([B2](#b2-camera-and-visual-presentation)) |
| Handmade world from one map file | Crashlands 2 and Bad 2 Bad both left procedural worlds ([B4](#b4-world-building-and-regions)) |
| Return-home premise, crew to find | Strongest openings in the group ([B5](#b5-story-and-narrative-progression)) |
| Missions with stealth, loud and vehicle approaches | Avoids Bad 2 Bad's "linear" criticism ([B5](#b5-story-and-narrative-progression)) |
| Data-driven missions | Crashlands' quest tool and CL2's bottleneck ([B13](#b13-assets-and-production)) |
| Floating stick + context buttons | Survival RPG, Crashlands 2; no tap-to-move ([B7](#b7-combat-and-weapons)) |
| No energy timers, no pay-to-win (design pillar) | Stardew praised for it; SRPG and B2B hurt by the opposite ([B12](#b12-monetization-and-costly-mistakes)) |
| Offline-first | Praised for SRPG and B2B ([B14](#b14-performance-and-smoothness-on-mobile)) |

## C2. Proposed changes to Solvera's design

Each is a proposal. Approve, change or reject; approved ones go into
`MVP_DESIGN.md`, `ACT1_MISSIONS.md` or the prototype.

| # | Proposal | From | Where it lands | When |
|---|---|---|---|---|
| 1 | Auto-aim ring on touch, manual on gamepad | B2B | Prototype combat | Next prototype pass |
| 2 | Dodge roll with input priority and success flash | CL2 | Prototype combat | Next prototype pass |
| 3 | Ground telegraphs for enemy attacks and player aim | CL2 | Combat | Vertical slice |
| 4 | Layout editor and controller support at launch | SV, B2B | Controls | Vertical slice |
| 5 | Day/night of 10-15 min with a night ledger (payout + save) | SV, B2B | Core loop | Vertical slice |
| 6 | District boards (themed checklists with a world-change reward) | SV | Missions | Alpha |
| 7 | Daily district bounties with no real-time expiry | SV, CL2 | Missions | Alpha |
| 8 | Visible unlocks: streetcar lines, bridge repair, claimed garages as fast travel | SV, B2B | World map | Alpha |
| 9 | District heat or level tags on the map | B2B | Map, HUD | Vertical slice |
| 10 | District states (day/night, gang-held/liberated, storm) | SRPG, SV | World | Alpha |
| 11 | Relationship events for the act 1 cast | SV | Story | Alpha |
| 12 | Short lines and barks; no text walls | CL2 | Writing | All |
| 13 | Weapon classes with one job each, few tiers, proficiency carries over | CL, B2B | Combat | Vertical slice |
| 14 | Crew followers capped at 3 with formation presets | B2B | Combat | Alpha |
| 15 | No stash micromanagement; auto-select weapon or tool | CL, SV | Inventory | Vertical slice |
| 16 | Garage time instead of real-time timers for upgrades | SV | Progression | Alpha |
| 17 | Safehouse facility upgrades in fixed slots | B2B | Progression | Alpha |
| 18 | Calendar city events with minigames and tokens; arcade cabinet | SV | Activities | Post-MVP |
| 19 | Collection log (cars, outfits, packages, legends) | SV, CL2 | Activities | Alpha |
| 20 | Mission and dialogue editor | CL | Tools | Before content production |
| 21 | Swappable 3D character parts for outfits | CL2, B2B | Art | Vertical slice |
| 22 | Auto-save on background, cloud save, offline at launch | SV, SRPG | Tech | Beta |
| 23 | Low-RAM Android and small-phone testing in CI | SV | Tech | Prototype onwards |
| 24 | Night brightness clamp; danger outlines always on | CL2 | Visuals | Vertical slice |
| 25 | Respawning story items; hint option | SRPG | Missions | Alpha |

## C3. Decisions for you

1. **Business model.** **Decided Oct 26, 2026: free-to-play**, with the
   guardrails recorded in `MVP_DESIGN.md`. The evidence that informed it:
   - Premium worked for Stardew and Crashlands 1 (strong word of mouth,
     depth, no timers); Crashlands 1 sold mostly on mobile but was heavily
     pirated on Android.
   - Free-to-play gave Survival RPG and Bad 2 Bad millions of installs but
     weak or unknown revenue, and the grind-for-sale design hurt both.
   - A hybrid (free first act, one-time unlock for the full game, cosmetics
     on top) avoids both failure modes but was not used by any game here.

   `MVP_DESIGN.md` currently proposes free-to-play with cosmetics and
   rewarded ads. Choose before tuning the economy.
2. **Which of the 25 proposals in [C2](#c2-proposed-changes-to-solveras-design)
   to adopt.**
3. **A follow-up study of top-down driving games** (see [C4](#c4-gaps-this-research-cannot-fill)).

## C4. Gaps this research cannot fill

- **Driving.** None of the five has drivable vehicles. Solvera's core
    fantasy needs separate references, such as GTA: Chinatown Wars and GTA 2.
- **Crime-game specifics:** wanted systems, police AI, heists and
    turf wars are not covered by these games.
- **Engines and performance data** for Survival RPG and Bad 2 Bad's mobile
    build, audio pipelines, and most file sizes.
- **Revenue:** official figures exist only for Stardew and Crashlands 1.

---

# Part D. Appendices

## D1. Topic finder

| Looking for | Main volume | Strongest dossier |
|---|---|---|
| Auto-aim on touch | [B7](#b7-combat-and-weapons) | [Bad 2 Bad §7](games/bad2bad_apocalypse.md#7-combat-and-weapons) |
| Ads that players accept | [B12](#b12-monetization-and-costly-mistakes) | [Bad 2 Bad §12](games/bad2bad_apocalypse.md#12-monetization-and-mistakes) |
| Area unlocks by repairing the world | [B4](#b4-world-building-and-regions) | [Stardew §4](games/stardew_valley.md#4-world-building-and-regions) |
| Base or safehouse upgrades | [B8](#b8-progression-and-upgrades) | [Bad 2 Bad §8](games/bad2bad_apocalypse.md#8-progression-and-upgrades) |
| Bundles and checklists | [B6](#b6-missions-and-quests) | [Stardew §6](games/stardew_valley.md#6-missions-and-quests-design) |
| Business results and sales | [B1](#b1-overview-scale-and-business-results) | [Crashlands §1](games/crashlands.md#1-overview-and-facts) |
| Camera angle and tile scale | [B2](#b2-camera-and-visual-presentation) | [Stardew §2](games/stardew_valley.md#2-camera-and-visual-presentation) |
| Cloud and cross-save | [B14](#b14-performance-and-smoothness-on-mobile) | [Crashlands §14](games/crashlands.md#14-performance-and-smoothness-on-mobile) |
| Control schemes on touch | [B14](#b14-performance-and-smoothness-on-mobile) | [Stardew §14](games/stardew_valley.md#14-performance-and-smoothness-on-mobile) |
| Daily goals without timers | [B11](#b11-player-hooks-and-retention) | [Crashlands §11](games/crashlands.md#11-player-hooks-and-retention) |
| Day/night cycle | [B3](#b3-core-gameplay-loops) | [Stardew §3](games/stardew_valley.md#3-core-gameplay-loops) |
| Death penalty | [B8](#b8-progression-and-upgrades) | [Crashlands §3](games/crashlands.md#3-core-gameplay-loops) |
| Dodge and telegraphs | [B7](#b7-combat-and-weapons) | [Crashlands §7](games/crashlands.md#7-combat-and-weapons) |
| Dungeons and checkpoints | [B6](#b6-missions-and-quests) | [Stardew §7](games/stardew_valley.md#7-combat-and-weapons) |
| Festivals and events | [B10](#b10-things-to-do-and-explore) | [Stardew §10](games/stardew_valley.md#10-things-to-do-and-activities) |
| Free updates as marketing | [B11](#b11-player-hooks-and-retention) | [Stardew §11](games/stardew_valley.md#11-player-hooks-and-retention) |
| Grind and economy mistakes | [B12](#b12-monetization-and-costly-mistakes) | [Survival RPG §12](games/survival_rpg.md#12-monetization-and-mistakes) |
| Handmade vs procedural | [B4](#b4-world-building-and-regions) | [Crashlands §4](games/crashlands.md#4-world-building-and-regions) |
| Inventory design | [B8](#b8-progression-and-upgrades) | [Crashlands §8](games/crashlands.md#8-progression-and-upgrades) |
| Lighting as gameplay | [B2](#b2-camera-and-visual-presentation) | [Survival RPG §2](games/survival_rpg.md#2-camera-and-visual-presentation) |
| Low-RAM Android crashes | [B14](#b14-performance-and-smoothness-on-mobile) | [Stardew §14](games/stardew_valley.md#14-performance-and-smoothness-on-mobile) |
| Modular character art | [B13](#b13-assets-and-production) | [Crashlands §13](games/crashlands.md#13-assets-and-production) |
| Piracy | [B12](#b12-monetization-and-costly-mistakes) | [Crashlands §12](games/crashlands.md#12-monetization-and-mistakes) |
| Quest-writing tools | [B13](#b13-assets-and-production) | [Crashlands §13](games/crashlands.md#13-assets-and-production) |
| Relationship story events | [B5](#b5-story-and-narrative-progression) | [Stardew §5](games/stardew_valley.md#5-story-and-narrative-progression) |
| Replay modes (hardcore, ranks) | [B11](#b11-player-hooks-and-retention) | [Survival RPG §11](games/survival_rpg.md#11-player-hooks-and-retention) |
| Skill trees and professions | [B8](#b8-progression-and-upgrades) | [Stardew §8](games/stardew_valley.md#8-progression-and-upgrades) |
| Soft-locks | [B6](#b6-missions-and-quests) | [Survival RPG §6](games/survival_rpg.md#6-missions-and-quests-design) |
| Squad followers | [B7](#b7-combat-and-weapons) | [Bad 2 Bad §7](games/bad2bad_apocalypse.md#7-combat-and-weapons) |
| Tool-gated exploration | [B4](#b4-world-building-and-regions) | [Survival RPG §4](games/survival_rpg.md#4-world-building-and-regions) |
| Vehicles and fast travel | [B9](#b9-vehicles-movement-and-physics) | [Bad 2 Bad §9](games/bad2bad_apocalypse.md#9-vehicles-mounts-movement-and-physics) |
| Weapon classes and roles | [B7](#b7-combat-and-weapons) | [Crashlands §7](games/crashlands.md#7-combat-and-weapons) |

## D2. Glossary

- **3/4 view (oblique top-down):** the ground seen from above with the
    fronts of buildings and characters visible; north is up.
- **Bundle:** Stardew's themed item checklist; completing one gives a
    reward and repairs part of the town.
- **Context action button:** one button whose action depends on what is in
    front of the player.
- **Cross-save:** one save used across phone and PC.
- **Gear check:** combat decided mostly by equipment stats rather than play.
- **Interstitial ad:** a full-screen ad shown between screens; **rewarded ad:**
    an ad the player chooses to watch for a reward.
- **Procedural:** generated by code at runtime rather than placed by hand.
- **Soft-lock:** a state where the game can no longer be finished.
- **Telegraph:** a visible warning (often a shape on the ground) of where an
    attack will land.

## D3. Open questions to verify

From the dossiers' "unverified" items; worth checking before relying on them.

- Stardew: PC release date; weapon-type details; the tile-size constant.
- Survival RPG: engine; team size; audio; HUD layout; whether Open World is
    procedural; revenue.
- Crashlands: quest counts; endings; audio; mobile file sizes and minimum
    OS; official Crashlands 2 sales.
- Bad 2 Bad: exact camera angle; melee; mobile save behaviour; file size;
    revenue.

Best next steps: read the official wikis and store pages directly, watch
full-gameplay videos for camera and HUD details, and unpack APKs to confirm
engines.
