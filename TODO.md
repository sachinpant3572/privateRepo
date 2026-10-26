# TODO

## Tuesday, Oct 27, 2026, 1:00 PM IST: Civilization Tech game idea

Status: **not started**. Research is on hold until the weekly usage limit resets on Tuesday.

### The idea (as described)

A 2D game where the player gives advanced technologies to a species or society
at different points in its history, then watches what happens.

- **Human mode**: give tech to human societies at different periods.
- **Species mode**: give tech to other species, such as Neanderthals, reptiles,
  dinosaurs, and later the creatures considered the next smartest after humans.
  The player decides what the species does with the tech.
- **Consequences**: every action has consequences, from very rewarding to
  catastrophic. They could be shown as cards (but better than plain cards) or as
  full 2D animation.
- **Tech tree and crafting**: players unlock new technologies, and some can be
  combined into completely new tech. All of it follows real, current science.
- **Create or destroy**: tech can be used to build or destroy things, people and
  buildings.
- **Scenarios**: the game sets scenarios for using the tech. The results of each
  scenario add up to the ending.
- **Progression**: runs up to a starfaring civilization. There are several
  starfaring endings, depending on which technologies were used. A civilization
  can also destroy itself well before that, by misusing tech or failing to use it
  properly.
- **References**: Age of Empires + a basic SimCity + Stickman Wars + TABS +
  Detroit: Become Human (for choices and consequences), all in 2D.
- **AI in the engine (optional)**: use the Claude API to generate results or
  new tech combinations only if its cost is very low compared with expected
  revenue. Otherwise build it without AI in the game engine.
- **Content rule**: no religious figures, to avoid controversy or bans.
- **Launch scope**: humans from different periods first, then other species.

### Agenda for Tuesday

1. [ ] **Originality check**: search thoroughly across Steam, Epic, itch.io,
   console stores, iOS/Android, and web/Poki/CrazyGames for any existing game
   with this concept. Look for anything close: tech-gifting, uplift,
   alternate-history or "what if" civilization sims, and tech-combination crafting
   (for example Doodle God/Little Alchemy-style games).
2. [ ] **TABS check**: does TABS (Totally Accurate Battle Simulator) allow or
   cover this concept, through its mechanics, mods/workshop, or IP/EULA? How is
   our idea the same as TABS, and how is it different?
3. [ ] **Assessment**: rate how valid, impressive, expansive, feasible,
   addictive and replayable the idea is, and how ambitious it is, with critical
   feedback.
4. [ ] **Claude can do it all?**: can Claude handle research, the feasibility
   study, implementation, testing, fixing, QA, and many high-quality animated 2D
   models, with the user making decisions from the options Claude gives? Be
   honest about what needs outside tools, assets or people (for example art and
   animation pipelines, and store publishing).
5. [ ] **AI cost model**: Claude API cost per player/session against projected
   revenue, to decide between using AI and no AI.
6. [ ] **Next steps**: choose engine/tech stack, MVP scope (human mode, a few
   eras), and art style.

## Tuesday, Oct 27, 2026, 1:30 PM IST: Casual Android game research

Status: **research done** (Oct 25, 2026). Report:
[docs/casual-android-game-research.md](docs/casual-android-game-research.md).
On Tuesday: review it and make the decisions in step 9 of the report.

### The idea (as described)

Research how to build simple but addictive, high-grossing casual games for
Android, thinking like an expert, highly successful solo or small-team
developer. The user calls these "casual platformers".

- **Reference games (all on Android)**: Rumble Beavers, The War for Survival,
  Supermarket Tycoon Empire, Last Human: Final Stand, Hero Wars: Alliance.
- **Why they work**: the concepts are simple to build but addictive to play.
- **Monetization**: players spend a lot on upgrades, mostly when they have to
  make a split-second decision.
- **User's view of the success factors**:
  - Smoothness: everything runs very smoothly.
  - Animations.
  - Surprise.
  - Fast decision-making.
  - Replayability.
  - Huge numbers of bullets and explosions on screen.
  - Lots of upgrades.
  - Upgrades that can be combined into new ones.

### Agenda for Tuesday

1. [x] **Check the reference games**: confirm each title, its developer and its
   real genre. Several may not be platformers (for example idle tycoon, RPG,
   or survivor-like shooter), so agree on which genre we are actually building.
   Collect public data on installs, revenue and ratings.
2. [x] **Break down each game**: core loop, session length, progression and meta
   progression, upgrade and merge/combination systems, surprise mechanics,
   monetization (IAP, rewarded ads, offers timed to decision points, passes),
   FTUE/onboarding, LiveOps, and how their ads compare with the real gameplay.
3. [x] **Test the success factors**: check the user's list above against
   evidence, and add what is missing (for example retention D1/D7/D30, ad
   creatives and CPI, meta progression, difficulty curve).
4. [x] **Store policy and ethics**: Google Play rules on random rewards and odds
   disclosure, and on misleading ads. Regional pricing (India included).
   Monetize without dark patterns that get games banned or refunded.
5. [x] **Tech for a solo developer**: engine choice (for example Unity, Godot,
   Defold), and how to keep hundreds of bullets and explosions at a steady 60 FPS
   on low-end Android phones (object pooling, batching/instancing). APK size.
6. [x] **Claude can do it all?**: what Claude can do (research, design,
   code, testing, balancing) and what needs outside tools, assets or people
   (art, animation, sound, ad creatives, store publishing, user acquisition).
7. [x] **Concepts**: 3 to 5 original game concepts that combine these factors,
   rated for addictiveness, replayability, revenue potential and build effort.
8. [x] **Next steps**: pick one concept, MVP scope, a short prototype, and a cheap
   test of the ad creatives (CPI) before committing to a full build.

Note: this starts 30 minutes after the Civilization Tech review above. Decide
whether to run them back to back or move one.
