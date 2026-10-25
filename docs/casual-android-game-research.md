# Casual Android game research

Research for the TODO item "Tuesday, Oct 27, 2026, 1:30 PM IST: Casual Android
game research". Done on Oct 25, 2026.

**About the data.** The sandbox could not open web pages directly, so every
figure here comes from search-engine summaries of the sources listed at the end.
Many are secondary write-ups of the primary reports. Items marked **[unverified]**
are weakly sourced. Check the primary source before putting any number in a
business plan.

## Summary

1. **None of the five reference games is a platformer.** They fall into three
   groups: a merge/idle auto-shooter (Rumble Beavers), an idle tycoon (Supermarket
   Tycoon Empire), and zombie strategy or RPG games whose ads show a simple
   shooter or puzzle that is not the main game (The War for Survival, Last Human:
   Final Stand, Hero Wars: Alliance).
2. **Most of your success factors describe the ads, not the games.** Juice,
   bullet spam and fast choices are what sell the install. The money comes from
   slow systems underneath: gear, heroes, VIP levels, events and a small number of
   big spenders.
3. **Most of your list holds up, with two corrections.**
   - Surprise, combinable upgrades, fast choices and juice are backed by evidence.
   - Juice works only up to a point: extreme juice makes games worse.
   - Spending "at split-second decisions" is wrong as stated. Offers work at
     *paused* moments: death, level-up drafts, end of a run. Interrupting action
     with an offer hurts, and EU regulators are now targeting pressure timers.
4. **What actually wins for solo developers:** survivor-like and arena
   roguelites with pick-1-of-3 upgrades and weapon combinations (Vampire
   Survivors, Brotato, Magic Survival, the first Archero demo). The
   billion-dollar games in the list (Hero Wars, Last War, Kingshot) are big-team
   strategy and RPG games bought into the charts with huge ad budgets. A solo
   developer can't copy that model.
5. **Recommended stack:** Godot 4 with GDScript and the Compatibility (GLES3)
   renderer. Claude can build and export it headless, and every file is plain
   text. Defold is second if download size matters most.
6. **Recommended first game:** Concept A below, a survivor-like with 3-minute
   runs and a fusion recipe book. Build a stress-test APK first, then a 4-week
   prototype, then a cheap ad test (CPI test) before committing to a full build.

---

## 1. The reference games

| Game | Developer | Real genre | Scale | Platformer? |
|---|---|---|---|---|
| Rumble Beavers | NEPTUNE / Treeplla (South Korea) | Idle auto-shooter: merge weapons, prestige | Released Sep 17, 2026; no numbers yet | No |
| The War for Survival | Cosmos game Limited / ARK GAME LIMITED (origin unconfirmed) | Zombie 4X strategy (SLG): base building, heroes, alliances | Live since early 2026; APK about 1.1 GB | No |
| Supermarket Tycoon Empire | Sopot Studios (Android) / Celestial Roads LLC (iOS) | Idle tycoon with a Monopoly GO-style dice board | 100K+ installs, 4.7–4.8 stars | No |
| Last Human: Final Stand | Iterflor Pte Ltd (Singapore) | Zombie shooter on top of base-building strategy | Launched Aug 2026; 500K+ installs, about 20K/day | No |
| Hero Wars: Alliance | Nexters (GDEV, Cyprus) | Squad RPG: collectible heroes, random pulls | $1.7B lifetime revenue, 185M installs (June 2025) | No |

### Rumble Beavers
- **Core loop:**
  - Beavers with guns fire automatically at falling boulders.
  - You swipe to merge weapons (60+ types) and recruit beaver agents (40+).
  - Earnings build up while you're offline.
  - "Prestige" resets progress for permanent buffs, which is how you get past
    boss walls.
- **Monetization:** rewarded ads for boosts, IAP, a VIP tier.
- **Takeaway:** the closest match to "simple to build". It has one screen, no
  movement and one merge mechanic. It comes from a Korean hybrid-casual team
  (Cat Snack Bar, Office Cat, Lumbercat) reusing a template it had already
  proven: Office Cat reportedly made about $130K/day within 4 months.

### The War for Survival
- **Core loop:**
  - Timed building upgrades.
  - Collecting and levelling heroes.
  - PvE stages.
  - Alliance PvP.
  - A recent update added a dating-style "affinity" system for heroes.
- **Complaints:** reviewers say the ads misrepresent the game and object to
  sexualized ad imagery.
- **Takeaway:** a strategy (SLG) game that needs a big team and live operations.
  It is not a solo template.

### Supermarket Tycoon Empire
- **Core loop:**
  - Tap and upgrade stations, expand the store, earn offline.
  - Roll dice on a board game for rewards.
  - Clubs can "attack" your store, Coin Master-style.
  - The listing says it contains random-reward loot boxes.
- **Complaints:** "turned into a money grab" as the game gets slower.
- **Note:** a small game. If you meant the big one in this niche, that is
  probably Codigames' *Idle Supermarket Tycoon – Shop*.

### Last Human: Final Stand
- **Core loop:**
  - Shoot hordes and bosses.
  - Build and upgrade a shelter.
  - Recruit and gear heroes.
  - Join alliances.
- **Monetization:** random-item IAP and an energy-style fuel limit. Reviews call
  the fuel costs "crippling".
- **Takeaway:** praised for its shooting and graphics, and criticized because
  "what u see in the ads IS WAYY DIFFERENT".

### Hero Wars: Alliance
- **Upgrades:** many layers stacked on each hero: levels, stars from soul
  stones, gear and promotion colors, skins, artifacts, talismans, titans and pets.
- **Monetization:**
  - Premium currency packs with x2–x5 bonus sales.
  - VIP levels earned only with real money.
  - A $2.29 subscription.
  - One-time offers that change with VIP level.
  - Rewarded ads.
- **Ads and regulators:**
  - Famous for pin-pull puzzle ads. The puzzles do exist in the game, but only
    as a side feature.
  - On Nov 19, 2025, the UK Advertising Standards Authority (ASA) upheld a
    complaint because its App Store listing didn't disclose loot boxes.
  - Reviews: "nothing like the adverts" and a pay wall after about 2 weeks.

### Comparable games worth studying

| Game | Team | Scale | Why it worked |
|---|---|---|---|
| Vampire Survivors | Started solo | Highest-rated Steam game of 2022; free on mobile with optional ads | Pick-1-of-3 upgrades, weapon "evolutions" (weapon + matching passive), screen-filling bullets |
| Brotato | Solo (France) | 2M+ Steam copies by June 2023 | Short wave-based runs, items that stack and combine |
| Magic Survival | Very small, possibly solo [unverified] | 5M+ on Google Play | The mobile auto-shooter that inspired Vampire Survivors |
| Archero | 2-person demo; Habby had about 12 staff in 2019 | About $181–200M lifetime [unverified] | One-thumb controls, pick-1-of-3 skills, gear meta |
| Survivor.io | Habby | $75M in 2 months; $500M+ lifetime IAP | Vampire Survivors rebuilt for free-to-play: 15-minute runs, skill evolutions, gear merging, battle pass, TikTok ads |
| Capybara Go | Habby | $100M player spending in about 3 months | Near-zero input "auto roguelike": random events, pick a skill |
| Last War: Survival | FirstFun (China) | #1 grossing mobile game in 2025 | Ads show a gate/army shooter in front of a strategy game; the mini-games are the hook |

---

## 2. How these games make money (the loops)

| Layer | What the player does | Where the money is |
|---|---|---|
| Moment to moment (seconds) | Move with one thumb, auto-fire, dodge, watch numbers fly | Nothing. This layer must feel great and never be interrupted |
| In-run choices (every 20–60 s) | Pick 1 of 3 upgrades on level-up; combine two maxed items into an evolution | Rerolls, extra choices, banishes (rewarded ads) |
| End of run (every 3–15 min) | Die or win, collect gold and chests | Revive offer, double-reward ad, "you were this close" offer |
| Meta (days) | Gear, talents, heroes/pets, chapter unlocks, merging duplicates | Starter pack, gem packs, chests (odds disclosed), battle pass, VIP |
| LiveOps (weeks) | Events, limited modes, seasonal passes | Event bundles, pass upgrades |

Capybara Go was described at GDC 2025 as "an ornate set of armour with nothing
inside". The meta matters more than the core loop for revenue. The core loop is
what gets players in and keeps them retained.

---

## 3. Your success factors against the evidence

| Your factor | Verdict | Evidence |
|---|---|---|
| Smoothness | **Required** | Android is about 95% of India's market, and most phones there are low-end. Stutter kills retention and reviews. It's a baseline, not a growth driver |
| Animations / juice | **Yes, with a limit** | Kao et al. 2020: medium and high juice beat both none and extreme. CHI 2024 (n=1,699): juice that rewards what the player did raises motivation; juice that just amplifies everything lowers it |
| Surprise | **Strongly backed** | Variable rewards produce very persistent behavior. Vampire Survivors' designer drew on his gambling-industry background. This is also exactly what regulators are watching |
| Fast decisions | **Yes** | The survivor loop is a constant stream of small choices. Keep each choice to 1–3 seconds, with the game paused |
| Replayability | **Yes, if there's a meta** | Varied runs alone don't retain players on mobile. Permanent progress between runs ("one more run") does |
| Mass bullets / explosions | **Partly** | Delivers the power fantasy and sells best in ads. But it has the same over-juice limit and is the biggest performance risk on cheap phones |
| Many upgrades | **Yes** | Build-crafting is the core of Survivor.io and Vampire Survivors |
| Combinable upgrades | **Strongly backed** | Weapon + passive = evolution creates a goal ("I need the Spinach"), which pulls players through each run |
| Spending at split-second decisions | **Wrong as stated** | No evidence supports interrupting action to sell. Offers work at paused moments: death, the level-up draft, end of run. The EU's Star Stable case (2025) singled out time-limited purchase pressure |

### Factors missing from your list
- **The first 60 seconds (first-time user experience, FTUE).** Day-1 retention
  is decided here. Put the player in the power fantasy within seconds and track
  every tutorial step as a funnel.
- **Meta progression.** This is where hybrid-casual earns its money.
- **A difficulty curve with soft walls.** Progress should stall unless the
  player upgrades. That stall is what the meta sells.
- **Collection.** Recipe books, heroes, pets, skins.
- **LiveOps.** Events in top free-to-play games rose 35% between May 2023 and
  January 2025.
- **Near-miss.** Ending a run just before an evolution is the strongest moment
  for a revive or retry offer.
- **Ad creatives.** For hybrid-casual, the ad is part of the product. You test
  the ad before you build the full game.

---

## 4. Benchmarks to aim for

| Metric | Median game | Top 10% | What publishers want (hybrid-casual) |
|---|---|---|---|
| Day-1 retention | 22% | about 40% | 45%+ (Voodoo) |
| Day-7 retention | about 4% | 11–12% | 15% (Voodoo) |
| Day-30 retention | 0.7% | about 4% | 10% (Voodoo) |
| Sessions per day | about 4 | about 9.6 [unverified] | — |
| Session length | 5–6 min | 8–9 min (top 25%) | — |
| Daily payer conversion | about 0.4% | about 1.2% (85th percentile) | — |

Sources: GameAnalytics 2025 and 2026 reports; Voodoo, 2023.

- **Ad cost per install (CPI), Android casual:**
  - Global: about $0.14 (Liftoff, 2024–25).
  - India: about $0.08–0.14.
  - US: about $1.20–3.00 [unverified].
  - So 1,000 test installs in India cost about $100–150.
- **Homa's targets for hybrid-casual tests:** CPI under $1.00, about 5,000
  seconds of total playtime by day 3, and 20% of players finishing the game.
- **Market:**
  - Hybrid-casual IAP grew 20% to $4.2B in 2025, the only segment with real
    growth.
  - Downloads fell 10.6% while time spent rose 7.4%: fewer players, earning
    more each.
  - In action and strategy hybrids, about 82% of revenue is IAP and 18% is ads.

---

## 5. Monetization plan, and staying inside the rules

### Where to put offers (all at paused moments)
- **Revive after death:** the strongest rewarded-ad placement, plus an IAP
  "continue" offer.
- **Level-up draft:** an ad for a reroll or a 4th choice.
- **End of run:** double the gold for watching an ad.
- **Starter pack:** priced at $0.99–2.99 (₹10–₹99 in India), shown after the
  first real "almost". A/B test the price; packs are often priced too low.
- **After soft launch:** add a battle pass, events, chests, and gem packs with
  x2 sales.

### India specifics
- **Ad income is low.** Rewarded-video ads pay about $0.70–3.96 per 1,000 views
  in India, against $14–22 in the US. An Indian player's ad views are worth 5–25
  times less.
- **Player spending is small.** Average spend per paying casual player is
  about $3 [unverified].
- **The strategy:** acquire Indian players cheaply to tune retention, and earn
  from US and other high-paying (Tier-1) players.
- **Payments:** the minimum price is ₹10, and UPI works in Play Billing.

### Rules to follow

**Google Play**
- **Random items:** any random item bought with money, or with currency bought
  with money, must show its odds before purchase.
- **Payments:** digital goods must use Play Billing v8 or later. New apps and
  updates have needed it since Aug 31, 2026.
- **Target API:** new apps and updates must target API 36 (Android 16) since
  Aug 31, 2026.
- **New personal developer accounts:** must run a closed test with **12
  testers, opted in continuously for 14 days**, before you can publish.
  **Start this early.**
- **Data safety form:** declare everything your ad and analytics SDKs collect.
  Saying "no data collected" while running ads is the most common rejection.
- **Kids:** target 13+ to stay out of the Families policy.

**Ads and app-store listings**
- Ads must show real gameplay. The ASA ruled against Playrix's pin-pull ads
  (2020) and Evony (2024).
- A disclaimer saying "not all images represent actual gameplay" was ruled not
  good enough.

**EU**
- Rules adopted in March 2025 on virtual currencies: show real-money prices, no
  forced currency surplus, protect children.
- On Sep 30, 2026 it opened action against nine game companies, including
  Supercell, King and Playrix.
- A Digital Fairness Act proposal is expected around November 2026.
- What this means for your design: show real prices, keep currency bundles
  simple, and keep pressure timers mild.

---

## 6. Tech for a solo developer working with Claude

### Engine choice

| Engine | Builds without the editor (headless) | Text files Claude can edit | Ads / IAP | Download size | Fit |
|---|---|---|---|---|---|
| **Godot 4.x (GDScript)** | Yes (`godot --headless --export-release`) | Yes (`.tscn`, `.gd`) | Official AppLovin MAX plugin, first-party Play Billing plugin, AdMob via community plugins | about 20 MB+ | **Recommended** |
| **Defold (Lua)** | Yes (`bob.jar`) | Yes | Official AppLovin MAX extension, IAP and AdMob extensions (check Billing v8) | about 2–4 MB | Second choice: smallest download |
| Unity 6 | Yes, but Personal licenses are hard to activate headless; new Unity CLI in beta | Partly (YAML scenes; the editor is central) | Best of all (LevelPlay, MAX, Firebase, IAP 5) | about 30 MB+ | Pick it if monetization depth matters more than Claude working alone |
| Flutter + Flame | Yes | Yes (code only) | Strong (official AdMob, MAX, LevelPlay) | medium | Fine for idle/tycoon; weaker for bullet hells |
| libGDX / Kotlin / Bevy / raylib | Yes | Yes | You'd build the ads and IAP glue yourself | varies | Not worth it |

**Godot caveats**
- Use the **Compatibility (GLES3)** renderer. The Vulkan Mobile renderer has
  open crash reports on budget phones, e.g. PowerVR GE8320 and Galaxy A04 class.
- Avoid C# on Android: it's still experimental.
- Never make each bullet its own node.

### Keeping 60 FPS with hundreds of bullets on cheap phones
- **Draw each bullet and enemy type in one draw call** (MultiMesh in Godot).
  Forum reports:
  - About 160 bullets with one Area2D node each.
  - About 300–400 with pooled Sprite2D nodes.
  - 3,000+ with plain distance checks.
- **Collision:** a spatial hash with circle-vs-circle checks on squared
  distances, not the physics engine.
- **Memory:** pool everything (bullets, enemies, effects, damage numbers) and
  allocate nothing each frame.
- **Loop:** use a fixed timestep with render interpolation.
- **Fill rate:** low-end Mali and PowerVR GPUs are limited by how much they draw
  on screen. Use cheap unlit shaders, tight sprite meshes and few large
  transparent quads (full-screen flashes, big smoke).
- **Effects:** set a hard global particle cap that scales with quality settings.
- **Heat:** read the Android thermal API (ADPF) and step down effects, then to
  30 FPS, before the phone throttles. Use Android's frame pacing library
  (Swappy).
- **Download size:** aim for under 30–40 MB for India. Google found each extra
  6 MB cuts install conversion by about 1%.

### Cheap juice
- **Screen shake:** a "trauma" value that decays; shake = trauma² or trauma³,
  driven by Perlin noise, with a cap.
- **Hit-stop:** freeze a few frames on impact, but only on big hits, or a horde
  game stalls.
- **Small effects:** a white flash on hit, pooled damage numbers, eased tweens,
  squash and stretch, small particle bursts, layered sounds with random pitch.
- **Haptics:** Android's built-in TICK, CLICK and HEAVY_CLICK.
- **Watch:** *Juice it or lose it* (2012) and *The Art of Screenshake*
  (Vlambeer).

### Art and sound without an artist
- **Kenney:** free to use commercially (CC0). Stick to one artist family so the
  style stays consistent.
- **AI art tools:** PixelLab (about $12/month, skeleton-based animation),
  Retro Diffusion, Scenario.
  - Keeping a character consistent across frames is still the weak point.
  - Google Play has no AI-art disclosure rule for games. Steam does.
  - Prompt-only AI art may not be protected by copyright.
- **Animation:** for hordes, use sprite-sheet frames or shader wobble rather
  than skeletal animation. Spine (from $69) is for hero characters.
- **Sound:** jfxr output is free to use. On Freesound, use only CC0 or CC-BY
  files, never CC-BY-NC.

### SDKs
- **Ads:** AppLovin MAX for mediation.
- **IAP:** the Play Billing plugin.
- **Analytics, remote config and A/B tests:** GameAnalytics (free).
- **Crash reporting:** Crashlytics or GameAnalytics.

---

## 7. Can Claude do it all?

### What Claude can do in this setup

**Building the game**
- Game design documents, economy spreadsheets and balancing.
- All the code, written in Godot's text formats.
- Headless Android builds (APK/AAB), unit tests and simulation tests.
- Automated bots that play thousands of runs to tune the difficulty curve and
  the drop rates.

**Effects and placeholder art**
- Procedural visual effects, shaders, screen shake and hit-stop.
- Geometric placeholder art.

**Store and launch paperwork**
- Analytics events and dashboards.
- Store listing text, odds-disclosure screens, a privacy policy draft and the
  data safety answers.

**Planning and checks**
- Research, competitor tracking, and checklists for ad-test results.

### What needs you, or outside tools and people

| Need | Why | Options |
|---|---|---|
| Testing on a real phone | Claude can't hold a phone: feel, FPS and heat need a device | You install each build on a cheap 2–3 GB phone |
| Final art and animation | Claude can't paint consistent, polished character art | Kenney CC0, a single itch.io artist's packs, AI art tools you run (PixelLab, Scenario), or a freelancer for hero art and the icon |
| Music | Same reason | Licensed packs, or a freelancer |
| Play Console account | Needs your identity, the $25 fee and verification | You |
| 12 testers for 14 days | Must be real people | Friends, family, Discord or Reddit communities |
| Ad spend for tests | Real money | You: about $100–300 for the first test |
| Ad creatives | Claude can script and capture gameplay footage; final editing needs a video tool | Claude scripts the captures; you edit, or use a video AI tool |
| Signing key | Must stay in your control | You keep the upload key; Claude never stores it in the repo |
| Final decisions | Concept, art style, prices | You choose from options Claude gives |

---

## 8. Original game concepts

All four use your success factors in ways a solo developer can build. None
copies a reference game's assets or names.

Scores are out of 5. For "Build effort", lower means less work; the other
columns are better when higher.

| Concept | Addictive | Replayable | Revenue potential | Build effort | Ad appeal | Notes |
|---|---|---|---|---|---|---|
| **A. Fusion Survivor** | 5 | 5 | 4 | 3 | 4 | **Recommended**: closest to proven solo hits |
| B. Merge Wall Defense | 4 | 3 | 4 | **2** | 4 | Smallest build; Rumble Beavers template |
| C. Gate Army Runner | 4 | 3 | 3 | 3 | **5** | Last War's ad fantasy as the real game; crowded (Mob Control) |
| D. Shop by Day, Siege by Night | 4 | 4 | 4 | 4 | 3 | Two loops, so more work; best long-term meta |

### A. Fusion Survivor (recommended)

**In-run**
- Survivor-like with **3-minute runs** (Vampire Survivors runs are 30 minutes),
  sized for mobile sessions.
- One-thumb movement with auto-fire.
- Pick 1 of 3 on each level-up, about every 15–20 seconds.
- **Fusion:** any two maxed skills combine into a new skill. Recipes are found
  by trying combinations, like Little Alchemy inside a shooter.
- Recipes found are kept in a **recipe book**. That gives a collection meta and
  a reason to experiment.
- **Surprise:** rare "golden drafts" with 5 choices, fusion jackpots, and
  elite enemies that drop chests.
- **Bosses:** at 1:30 and 3:00.

**Meta**
- Gear, talents and chapters.
- Undiscovered recipes appear as silhouettes, so players can see what is still
  to find.

**Monetization**
- Rewarded ads for a reroll or a 4th choice in the draft, and for a revive.
- A starter pack.
- Later: a battle pass and gem packs.

**Why it fits:** it covers every one of your factors (bullets, combining,
fast choices, surprise, replayability) and follows the pattern that worked for
Vampire Survivors and Brotato.

**Main risk:** the genre is crowded. The fusion recipe book and the 3-minute
runs are the differentiators, so test them in ads early.

### B. Merge Wall Defense
- Fixed turret wall at the bottom of the screen; waves come down from the top.
- Merge identical weapons on a 4×3 grid to upgrade them.
- Mid-wave, pick 1 of 3 mods, such as "ricochet" or "split shot".
- Offline earnings, plus prestige for permanent buffs.
- **Why:** the simplest to build (no movement, one screen) and a proven
  template.
- **Risk:** less depth. Retention depends on the meta.

### C. Gate Army Runner
- Run your army through math gates (+10, ×2, −5), then fight a crowd battle.
- Between runs, combine unit types into hybrids, e.g. archer + knight =
  lancer.
- **Why:** it makes Last War's best-selling ad fantasy into the actual game, so
  your ads can show it honestly.
- **Risk:** Mob Control and many clones already exist. Differentiating it is
  hard.

### D. Shop by Day, Siege by Night
- **Day:** an idle tycoon. Run a shop at the edge of an apocalypse.
- **Night:** a 2-minute survivor wave defending the shop.
- Shop income buys weapons and traps, and the night's loot unlocks new shop
  products.
- **Why:** it combines tycoon retention (offline earnings, expansion) with
  shooter excitement.
- **Risk:** two loops means roughly double the build and balancing work.
  Better as a second game.

---

## 9. Next steps

1. **Decide:**
   - Pick the concept (A recommended, B as the fallback).
   - Pick the engine (Godot recommended).
   - Pick an art direction, e.g. Kenney-style flat, pixel art, or neon
     geometric. Neon geometric is the cheapest and suits shader effects.
2. **Start the Play Console paperwork now:** create the developer account and
   line up 12 testers. The 14-day closed test can run while the game is being
   built.
3. **Week 1, stress test:** Claude builds a Godot APK with 500 enemies, 1,000
   bullets and particles, plus an on-screen FPS and heat counter. You run it on
   your cheapest phone. This confirms the engine before any game work.
4. **Weeks 2–4, prototype:**
   - 3-minute run, 12 base skills, 6 fusions, 3 enemy types, 1 boss.
   - Gold and one meta upgrade screen.
   - Analytics events.
   - Claude's bots tune the difficulty curve.
5. **Week 5, ad test (CPI):**
   - Make 3–5 short video ads from real gameplay.
   - Spend $100–300 on cheap Indian traffic, plus a small US sample to read ad
     cost and click-through rate.
   - Go on only if roughly: day-1 retention ≥ 35–40%, a healthy first-day
     playtime, and CPI in line with Homa's or Voodoo's thresholds.
6. **If it passes:**
   - Build the full meta (gear, talents, chapters, recipe book).
   - Add monetization (rewarded ads, starter pack, odds-disclosed chests), then
     soft launch.
   - Add a battle pass and events after soft launch.
   - Pitch a publisher (Homa, Voodoo, SayGames, Kwalee) with real metrics, or
     self-publish.
7. **If it fails:** try concept B with the same tech. The stress-test code,
   juice, analytics and SDK setup all carry over.

---

## Sources (main ones)

**Reference games**
- Rumble Beavers: https://play.google.com/store/apps/details?id=com.nep.tr.hybrid.cg.rock ,
  https://www.mt.co.kr/tech/2026/01/27/2026012717140458528
- The War for Survival: https://play.google.com/store/apps/details?id=com.thewar.global
- Supermarket Tycoon Empire: https://play.google.com/store/apps/details?id=com.supermarkettycoon.idle
- Last Human: Final Stand: https://www.appbrain.com/app/last-human-final-stand/com.avenue.zombie.gp
- Hero Wars: Alliance:
  - https://www.gamedeveloper.com/press-release/hero-wars-alliance-continues-it-s-ascent-with-over-1-7bn-revenue-185m-installs/
  - https://www.asa.org.uk/rulings/nexters-global-ltd-a25-1295789-nexters-global-ltd.html
  - https://gamedevreports.substack.com/p/nexters-misleading-ads-survey-2023

**Comparable games and the hybrid-casual market**
- https://mobilegamer.biz/two-months-in-survivor-io-passes-75m-from-37m-downloads/
- https://www.pocketgamer.biz/habbys-capybara-go-surpasses-100m-in-gross-player-spending
- https://www.deconstructoroffun.com/blog/2025/7/31/habbys-hybridcasual-empire-the-template-that-built-a-powerhouse
- https://appgrowing.net/blog/en/how-last-war-uses-proxy-minigames-to-package-strategy-gameplay/
- https://mobilegamer.biz/gdc-2025-what-we-can-learn-from-royal-kingdom-capybara-go-hexa-sort-match-mastersand-duolingo/
- https://gameworldobserver.com/2026/01/21/in-2025-the-revenue-of-the-mobile-gaming-market-grew-but-only-slightly-analysis

**Benchmarks and ad testing**
- https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks
- https://liftoff.ai/blog/highlights-2025-casual-gaming-apps-report/
- https://support.homagames.com/knowledge/games-overview
- https://wnhub.io/news/podcasts/item-41308

**Game design**
- https://theconversation.com/vampire-survivors-how-developers-used-gambling-psychology-to-create-a-bafta-winning-game-203613
- https://spiral.imperial.ac.uk/entities/publication/253c32f5-d124-4a23-88b5-9aaaf114608d

**Play Store policy**
- https://support.google.com/googleplay/android-developer/answer/9858738 (random items / odds)
- https://support.google.com/googleplay/android-developer/answer/14151465 (12 testers / 14 days)
- https://developer.android.com/google/play/requirements/target-sdk

**EU regulation**
- https://www.lewissilkin.com/insights/2026/10/15/eu-consumer-protection-network-launches-action-involving-nine-video-games-compani-102o5do

**Tech**
- https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_android.html
- https://forum.godotengine.org/t/bullet-hell-optimization/129732
- https://github.com/godotengine/godot/issues/115435 (Vulkan crashes on budget phones)
- https://developers.applovin.com/en/max/godot/overview/integration
- https://defold.com/manuals/bob
- https://developer.android.com/games/optimize/adpf/thermal
- https://medium.com/googleplaydev/shrinking-apks-growing-installs-5d3fcba23ce2
