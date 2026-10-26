# Game design document (draft 1)

The design for the survivor-style action game from
[casual-android-game-research.md](casual-android-game-research.md) (Concept A,
"Fusion Survivor"), with the worlds and upgrade rules agreed on Oct 25, 2026.
Draft 1: every number here is a starting point for testing.

## Contents
1. [The game in one page](#1-the-game-in-one-page)
2. [Story and hero](#2-story-and-hero)
3. [Core loop](#3-core-loop)
4. [A run, minute by minute](#4-a-run-minute-by-minute)
5. [Upgrade system](#5-upgrade-system)
6. [World 1: The Iron Dominion](#6-world-1-the-iron-dominion)
7. [World 1 arsenal: 12 weapons and 12 powers](#7-world-1-arsenal-12-weapons-and-12-powers)
8. [Worlds roadmap](#8-worlds-roadmap)
9. [Convergence: all worlds at once](#9-convergence-all-worlds-at-once)
10. [Long-term progression (meta)](#10-long-term-progression-meta)
11. [Economy and monetization](#11-economy-and-monetization)
12. [Retention systems](#12-retention-systems)
13. [Difficulty and pacing](#13-difficulty-and-pacing)
14. [Graphics quality and performance budget](#14-graphics-quality-and-performance-budget)
15. [Art and audio list for World 1](#15-art-and-audio-list-for-world-1)
16. [Production plan](#16-production-plan)
17. [Open decisions](#17-open-decisions)
18. [Future plans (TODO)](#18-future-plans-todo)

---

## 1. The game in one page

| | |
|---|---|
| **Working title** | Options: *Shatterverse*, *Omniforce*, *Rift Sovereign*. Check stores and trademarks before choosing |
| **Genre** | Survivor-like action roguelite (auto-fire, one-thumb movement) with a deep long-term progression layer |
| **Platform** | Android first (Godot 4, see `games/stress-test/`), iOS later |
| **Session** | 5-minute stages plus a boss; an endless mode for high scores |
| **Audience** | 13+. Players of Survivor.io, Archero, Vampire Survivors, and war and strategy ads |
| **Rating target** | Teen / PEGI 12: stylized violence, no blood, fictional factions |
| **Business model** | Free to play: rewarded ads plus in-app purchases (starter pack, gems, battle pass, skins) |

**The pitch:** reality has shattered. Armies, monsters and alien fleets from
every world pour through the cracks. You are the one being who can absorb the
power of every world and fuse it into weapons no world has seen.

**Design pillars** (every feature must serve at least one):
1. **Overwhelming power fantasy.** Start as one hero against a handful of
   troopers; end as a walking apocalypse against hundreds of tanks and
   aircraft.
2. **A big decision every 15 seconds.** Fast pick-1-of-2 choices with growing
   stakes. Every pick changes the build.
3. **Mass destruction you can feel.** Screens full of bullets, explosions,
   shockwaves and wreckage, with hit-stop, shake and haptics.
4. **Endless discovery.** Hundreds of weapons, powers, evolutions and
   cross-world fusions to collect.
5. **Looks like a flagship game on a flagship phone.** Ultra graphics on
   phones like the S25 Ultra, with Low to High tiers so budget phones still run
   smoothly.

---

## 2. Story and hero

**Setting:**
- The Fracture split the multiverse.
- Each world's most dangerous powers spill into the others: a fascist war
  machine, a realm of dark magic, an alien armada, and more later.
- Light story, told in short comic-style panels between worlds, and in boss
  intros.

**The hero (working name: "The Anomaly"):**
- A superhuman born at the center of the Fracture, able to absorb any world's
  power.
- This is the in-story reason for the whole design:
  - Beating a world's final boss gives you that world's **Core**, which
    unlocks that world's weapons and powers everywhere.
  - Combining Cores from different worlds makes **cross-world fusions**.
- **Visible growth:** each equipped weapon or power adds something to the
  hero's look: shoulder cannons, orbiting blades, energy wings, a glowing core.
  By the end of a run the hero looks as powerful as they are.

**Recommended hero tech:** a real-time 3D model drawn inside the 2D game
(Godot SubViewport), so equipment attaches to the model. To be confirmed (see
[Open decisions](#17-open-decisions)).

**Content rules:**
- No real countries, flags, uniforms, insignia or conflicts.
- No religious figures or deities.
- No blood: enemies explode into scrap, sparks, smoke or energy.

---

## 3. Core loop

| Layer | Time | What the player does | What keeps them going |
|---|---|---|---|
| **Moment** | Seconds | Move with one thumb; weapons fire automatically; dodge telegraphed attacks | Juice: hits, explosions, shake, haptics |
| **Level-up** | Every 10–30 s | Pick 1 of 2 cards (new item or level-up) | Variable reward; build-crafting |
| **Stage** | 5–6 min | Survive escalating waves, beat elites and the boss | Near-misses; evolutions and fusions coming online |
| **Meta** | Days | Upgrade gear, weapon mastery, talents; unlock stages and worlds | Permanent power; collection; next world |
| **LiveOps** | Weeks | Events, Convergence weeks, battle pass seasons | New content; limited rewards |

---

## 4. A run, minute by minute

A stage lasts 5:00 of waves, then a boss fight.

| Time | What happens |
|---|---|
| 0:00 | Hero drops in with the stage's starting weapon. First enemies within 2 s. First level-up within about 8 s |
| 0:00–1:00 | **Wave 1–2:** infantry. Level-ups every 8–12 s. The build forms |
| 1:00–2:00 | **Wave 3–4:** shields and grenadiers; first vehicles (jeeps, bikes) |
| 2:00 | **Elite** (e.g. Juggernaut). Drops a **Power Chest**: a guaranteed Epic choice |
| 2:00–3:30 | **Wave 5–7:** tanks and helicopters join; enemy count climbs toward the tier's limit |
| 3:30 | **Airstrike event:** bomber runs with telegraphed lanes. Dodge them |
| 3:30–5:00 | **Wave 8–10:** everything at once; level-ups every 20–30 s; evolutions start |
| 4:00 | Second **elite**, with a Power Chest |
| 5:00 | **Boss**, with an intro panel. Waves stop; minions continue |
| Boss down | Stage clear: gold, gear drops, a chest. Double gold for a rewarded ad |

- **Death:** a revive offer appears once per run. It's free the first time
  each day, then costs a rewarded ad or gems.
- **Endless mode** (unlocks after World 1, stage 3): waves never stop. It's a
  score race with weekly leaderboards.

---

## 5. Upgrade system

### Slots
Each run has **6 weapon slots** and **6 power slots**, out of 12 of each per
world. Once a type's slots are full, cards only offer level-ups for items you
already have. Slots must stay well below the number of items, so no run can
take everything and each run is a different build. (The M1 prototype has 6 of
each and uses **4 slots**; the third playtest, at 6 of 6, ended with the same
maxed build as every other run.)

### Level-up cards: pick 1 of 2
- Each level-up pauses the game and shows **2 cards**. Each card is either a
  new item or a level-up for one you own.
- **Reveal a 3rd card:** watch a rewarded ad (up to 3 per run) or spend gems.
- **Reroll both cards:** once free per run, then an ad or gems.
- **A/B test:** plain pick-1-of-3 against 2 + paid 3rd, measuring retention
  and revenue.

### Choices grow over time ("incremental")
Card rarity rises as the run goes on. Higher rarity means a bigger jump:

| Card rarity | Effect | Chance at 0:00 | Chance at 4:00 |
|---|---|---|---|
| Common | +1 level | 80% | 40% |
| Rare | +1 level and a bonus stat | 18% | 40% |
| Epic | +2 levels, or a new item at level 2 | 2% | 17% |
| Legendary | Instant evolution if eligible, or +3 levels | 0% | 3% |

- **Power Chests** (from elites and bosses) always contain an Epic or better.
- **Luck** (the Lucky Charm power, gear, talents) shifts these odds upward.

### Levels, evolutions and fusions
- **Levels 1–8:** each level does something you can see: more projectiles,
  bigger area, faster fire, an added effect.
- **Evolution:**
  - A weapon at level 8 plus its paired power (any level) becomes an
    **evolved weapon**: a new look and much more power.
  - It triggers at the next Power Chest.
  - One per weapon. The pairings are in section 7.
- **Cross-world fusion:**
  - Two **evolved** weapons from **different worlds** can fuse into a new
    weapon.
  - The fusion frees one slot.
  - Discovered recipes go into the **Fusion Codex**, a collection screen;
    undiscovered ones show as silhouettes.
  - Fusions are possible from World 2 onwards (see section 8).

### Synergies
- Two specific items that both reach **level 4** unlock a **synergy**: a new
  behavior, not a stat. Examples from the prototype:
  - Pulse Rifle + Tesla Coil = **Arc Rounds** (hits fork lightning).
  - Scatter Cannon + Explosive Rounds = **Frag Shells** (pellets burst).
  - Rocket Swarm + Magnet Field = **Gravity Warheads** (blasts pull enemies in).
  - Razor Halo + Titan Skin = **Bulwark** (blades shred enemy bullets).
  - Airstrike Beacon + Critical Targeting = **Precision Payload** (every bomb
    crits).
  - Tesla Coil + Adrenaline = **Static Dash** (running charges a lightning
    nova).
- Cards name the synergies an item is part of, so players plan builds around
  them.
- Discovered synergies are counted on the menu ("Synergies found 3/6"). This
  collection is the main reason to try a different build next run.
- Target for the full game: about 20 synergies per world, so a player
  discovers new ones for weeks.

### Limit Break
- A maxed item keeps coming back as an uncapped **Limit Break** card (and as
  a chest reward): weapons gain +12% damage and +4% fire rate per stack, plus
  a projectile every 4th stack; powers gain a little more of their effect.
- Levelling slows past level 25, so late Limit Breaks stay an event.
- Enemies keep up with strong builds: the boss's HP grows with the build's
  power score (shown as THREAT on its banner) and its damage taken tapers
  past 2% of its HP per second; elites, tanks and helicopters, and more
  gently the horde, also gain HP against strong builds. The scaling is
  always slower than the build's growth, so upgrades still feel stronger.

### Offer rules (anti-frustration)
- Never offer two cards for the same item.
- Never offer a card that can't be used (e.g. a new weapon when the slots are
  full).
- If neither card would help, the second card is replaced by gold or healing.
- From level 3, an item's level-ups are weighted higher, so a build comes
  together.

---

## 6. World 1: The Iron Dominion

**Setting:**
- A fictional militarized empire, faceless armored troopers in steel grey and
  crimson.
- **Stages 1–10:** ruined city, highway, desert base, harbor, industrial
  zone, airfield, mountain fortress, rail yard, propaganda capital, and the
  Iron Citadel.

### Enemies (12) and elites (2)

| Enemy | Role | Behavior | Art notes |
|---|---|---|---|
| Trooper | Fodder | Walks in and fires slow shots | Walk cycle; most numerous |
| Shield Trooper | Blocker | Front shield blocks shots; flank or pierce it | Walk cycle, shield prop |
| Grenadier | Area | Lobs grenades at your position (telegraph circle) | Throw animation |
| Flame Trooper | Close range | Short flame cone; pushes into you | Flame VFX |
| Sniper | Precision | Red laser sight for 1 s, then a heavy shot | Static; laser line |
| K9 Drone | Fast | Armored robot dogs that dash in packs | Rigid sprite with a leg wobble |
| Bike Raider | Fast vehicle | Zig-zags at speed; explodes on death | Rigid sprite |
| Gun Jeep | Vehicle | Circles and strafes with a mounted gun | Rigid sprite with a turret |
| Battle Tank | Heavy | Slow; telegraphed cannon shot; leaves wreckage | Rigid sprite with a turret |
| Attack Helicopter | Air | Hovers at range and fires rocket salvos | Sprite with spinning rotor |
| Bomber Jet | Event | Crosses the screen, drops a bomb line (telegraphed) | Rigid sprite with shadow |
| Mortar Team | Artillery | Shells land on telegraphed circles | Static crew |
| **Elite: Juggernaut** | Mini-boss | Heavy armor, minigun spray, very high HP | Big walk cycle |
| **Elite: Commander** | Buffer | Makes nearby troops faster and tougher; kill first | Distinct cape and silhouette |

Vehicles need little animation: one image plus a rotating turret or rotor.
That makes World 1 the cheapest world to make.

### Bosses (3)
1. **Colossus Siege Tank** (stage 3):
   - A three-turret land fortress.
   - Phases: cannon sweeps, then mine fields, then a desperation charge.
2. **Leviathan Gunship** (stage 6):
   - A giant helicopter carrier that launches drones.
   - Its weak spots open during rocket salvos.
3. **The Iron General** (stage 10):
   - Rides an armored train across the arena.
   - Phases: rail artillery, Juggernaut reinforcements, then he steps out in a
     power suit.
   - Beating him gives the **Iron Core**.

The other stages end with a "boss-lite": a souped-up elite with one special
attack.

---

## 7. World 1 arsenal: 12 weapons and 12 powers

### Weapons
Each weapon is one behavior from the engine's behavior library (section 8),
tuned and given its own look.

| # | Weapon | Behavior | Levels 1→8 (summary) | Evolves with | Evolution |
|---|---|---|---|---|---|
| 1 | Pulse Rifle | Auto-fire at the nearest enemy | +1 shot per 2 levels, +fire rate, pierce at 6 | Overclock | **Storm Rifle:** a constant stream that pierces everything |
| 2 | Scatter Cannon | Close spread | +pellets, +knockback, wider cone | Nanite Regeneration | **Leech Cannon:** pellets heal you |
| 3 | Rail Lance | Piercing line shot | +damage, +width, ricochets off edges at 7 | Bullet Time | **Chrono Lance:** freezes everything it passes through |
| 4 | Rocket Swarm | Homing missiles | +missiles, +blast radius | Critical Targeting | **Hellfire Barrage:** a rain of crit missiles |
| 5 | Grenade Rain | Lobbed area-of-effect | +grenades, +radius, cluster bombs at 6 | Lucky Charm | **Cluster Jackpot:** each blast spawns more grenades |
| 6 | Razor Halo | Orbiting blades | +blades, +radius, +speed | Adrenaline | **Buzzsaw Halo:** blades orbit faster the faster you move |
| 7 | Combat Drones | Summons that shoot | +drones, +fire rate, homing at 6 | Magnet Field | **Drone Hive:** drones multiply as you collect XP |
| 8 | Tesla Coil | Chain lightning | +chains, +jumps, stun at 7 | Ricochet Matrix | **Storm Network:** lightning arcs between all enemies hit |
| 9 | Flame Burst | Cone of fire | +range, +burn, 360° at 8 | Titan Skin | **Inferno Walker:** a permanent ring of fire around you |
| 10 | Mine Layer | Mines left behind you | +mines, +radius, chain detonation | Shockwave Stomp | **Seismic Field:** mines trigger fault-line quakes |
| 11 | Sentry Turret | Deployable turrets | +turrets, +duration, rockets at 6 | Kinetic Shield | **Fortress:** shielded turrets that taunt enemies |
| 12 | Airstrike Beacon | Calls bombing runs across the screen | +runs, +bomb size, napalm at 7 | Explosive Rounds | **Carpet Bomber:** continuous screen-wide bombing |

### Powers
Powers are passives, or actives that trigger automatically on a cooldown.

| # | Power | Type | Levels 1→8 |
|---|---|---|---|
| 1 | Overclock | Passive | +8% fire rate per level |
| 2 | Titan Skin | Passive | +max HP, +armor |
| 3 | Kinetic Shield | Auto-active | Blocks 1 hit, recharges; more charges with level |
| 4 | Magnet Field | Passive | +pickup radius; pulls all XP at 8 |
| 5 | Adrenaline | Passive | +move speed; dash on taking damage at 6 |
| 6 | Explosive Rounds | Passive | Kills explode; bigger blast with level |
| 7 | Ricochet Matrix | Passive | Projectiles bounce +1 time per 2 levels |
| 8 | Critical Targeting | Passive | +crit chance and crit damage |
| 9 | Nanite Regeneration | Passive | HP regeneration; heal on kill at 6 |
| 10 | Shockwave Stomp | Auto-active | Periodic area knockback; shorter cooldown and bigger with level |
| 11 | Bullet Time | Auto-active | Slows enemies for 2 s every 20 s; longer with level |
| 12 | Lucky Charm | Passive | Better card rarity, more drops |

---

## 8. Worlds roadmap

Each world adds 10–12 enemy types, 3 bosses, 10 stages, 12 weapons, 12 powers,
12 evolutions, its own Core, and a music theme.

| # | World | Enemies | Weapon flavor (examples) | When |
|---|---|---|---|---|
| 1 | **The Iron Dominion** | Troopers, tanks, helicopters, jets | Rifles, rockets, drones, airstrikes | Launch |
| 2 | **Arcana** | Witches, wizards, vampires, werewolves, golems, wyverns | Fireball, frost nova, hex chains, summoned wolves, blood moon | Update 1 |
| 3 | **Xenoverse** | Aliens, hive drones, saucers, mothership | Plasma, gravity well, black hole, nanite swarm, orbital laser | Update 2 |
| 4 | **Dead Zone** | Zombie hordes, mutants, plague titan | Chainsaw arc, flare launcher, toxin spray | Update 3 |
| 5 | **Machine Uprising** | Killer robots, mechs, AI cores | EMP, hacking (turn enemies), magnetic rail | Update 4 |
| 6 | **Primal Earth** | Raptor packs, T-rex, cavemen, pterosaurs | Bone spears, stampede, meteor | Update 5 |
| Later | Kaiju City, Hive Swarm (insects), Ocean Depths, Nightmare Realm, Microscopic, Mythic Beasts (monsters only) | | | Seasonal |

**How players move between worlds:**
- **Unlocking:** beating World N's final boss gives its Core and unlocks World
  N+1.
- **Bringing earlier items:** from World 2 on, players can bring **2 items
  from earlier worlds** into a run. This lets cross-world fusions happen
  before Convergence.

**Cross-world fusion examples:**

| Evolved weapon + evolved weapon | Fusion |
|---|---|
| Hellfire Barrage (Iron) + Phoenix Storm (Arcana) | **Dragon Artillery:** missiles that hatch fire wyrms |
| Storm Network (Iron) + Void Hex (Arcana) | **Cursed Grid:** lightning that hexes and spreads |
| Drone Hive (Iron) + Nanite Swarm (Xeno) | **Grey Goo:** a self-replicating swarm |
| Chrono Lance (Iron) + Black Hole (Xeno) | **Event Horizon:** a frozen line that collapses into a singularity |
| Carpet Bomber (Iron) + Meteor Call (Primal) | **Extinction Event:** a screen-wide meteor bombardment |

With 3 worlds there are 36 evolved weapons and 432 possible cross-world pairs.
Hand-design about 40–60 fusions per world added. Pairs without a designed
fusion can't fuse, and the Codex shows them as "unstable".

---

## 9. Convergence: all worlds at once

**Unlocking:**
- Permanently after World 3.
- Also as a **weekly event** from World 1 onwards, using whatever the player
  has unlocked, so players get a taste early.

**Enemies:** mixed waves from every unlocked world. Tanks escort vampires, and
alien saucers drop zombie hordes.

**Loadout:**
- Before the run, pick **6 weapons and 6 powers** from everything unlocked.
- Level-up cards come only from the loadout.
- This keeps builds focused and the screen readable, and makes collecting and
  upgrading favorites matter.

**Fusion:** all fusions are available, and the bonus Power Chests come faster.

**Rewards:** weekly leaderboard tiers, Convergence-only skins, and fusion
recipe hints.

---

## 10. Long-term progression (meta)

| System | How it works | Why |
|---|---|---|
| **Gear** | 6 slots (Core, Armor, Gauntlets, Boots, Belt, Implant). Rarity Common → Rare → Epic → Legendary → Mythic. Merge 3 of the same item to rank up. Upgrade with gold and materials | Main long-term power and spending sink |
| **Weapon mastery** | Each weapon and power has permanent stars (1–5), from duplicate cards found in chests | Collecting favorites; gives loadouts depth |
| **Talents** | A tree that gains a node with each hero level (HP, damage, luck, gold gain) | Steady free progress |
| **Hero skins** | One per world, plus event and battle pass skins. Small stat bonus at most | Main cosmetic spending |
| **Codex** | Every enemy, weapon, evolution and fusion found; milestone rewards | Collection and discovery |
| **Stage stars** | 3 stars per stage (clear, no revive, under par time) | Replay value |

---

## 11. Economy and monetization

### Currencies

| Currency | Earned from | Spent on |
|---|---|---|
| **Gold** (soft) | Stages, daily missions, ads | Gear upgrades, talents |
| **Gems** (premium) | IAP, small amounts from events and achievements | Chests, 3rd card, rerolls, revives, skins, pass upgrade |
| **Materials** | Stages, by world | Gear rank-ups |
| **Core shards** | Bosses, events | Weapon mastery stars |

**No energy system at launch.** Reviews of Last Human single out "crippling"
fuel limits. Add one only if data shows it's needed.

### Where money and ads appear (always at a paused moment)

| Moment | Ad option | Gem / IAP option |
|---|---|---|
| Level-up | Reveal a 3rd card (up to 3 per run); reroll | Same, for gems |
| Death | Revive (once per run) | Revive for gems |
| Stage clear | Double gold | — |
| Main menu | Daily free chest | Chests (odds shown), gem packs |
| First real "almost" (lost a boss under 20% HP) | — | **Starter pack** offer, once |
| Season | — | Battle pass, about every 4–6 weeks, themed to the newest world |

### Prices
- Starter pack: $0.99–2.99, or ₹10–99 in India.
- Gem packs from about ₹99 / $0.99 up to $49.99, with first-purchase double
  bonus.
- Battle pass: about ₹299 / $4.99.
- Use Play Console regional pricing.
- A/B test the starter pack price, since research suggests packs are often
  priced too low.

### Guardrails (policy and fairness)
- Every random reward shows its odds before purchase (Google Play rule).
- Prices are shown in real money next to gems (EU virtual-currency
  principles).
- No offer ever interrupts action. Offers appear only at pauses.
- No countdown pressure tactics aimed at young players. Target 13+.
- Ads show real gameplay only (ASA rulings against Playrix and Evony).

---

## 12. Retention systems

| System | When | Notes |
|---|---|---|
| Daily missions (3) | Daily | "Kill 500 tanks", "Evolve 1 weapon" |
| Login calendar | 7 days, repeating | Day 7: Epic gear chest |
| Weekly Convergence | Weekly | Leaderboard tiers |
| Endless leaderboard | Weekly | Friends and global |
| Events | Every 2–3 weeks | Limited stages, event skins, double drops |
| Battle pass | Every 4–6 weeks | Free and paid tracks |
| Push notifications | Opt-in | "Your free chest is ready". Maximum one per day |
| Achievements | Always | Codex milestones |

---

## 13. Difficulty and pacing

**Targets for the first 10 minutes:**
- **FTUE (first-time experience):**
  - First kill within 3 s.
  - First level-up within 8 s.
  - First evolution in stage 1, helped along: the first Power Chest is
    rigged.
- **Stage 1:** almost everyone should clear it. Stage 2 is the first real
  test.
- **The first boss** (stage 3) should take 2–3 attempts without upgrades,
  which pushes players to try the meta layer.

**Scaling (starting formulas, to be tuned by bots):**
- Enemy HP: `base × (1 + 0.12 × stage) × (1 + 0.25 × minute)`.
- Enemies on screen: a ramp from 30 to the tier's budget (section 14) over 4
  minutes.
- XP per level: `5 + 4 × level^1.35`. That's about 20–25 level-ups per stage.
- **Power curve check:** a median build should clear a stage with 15–30% HP
  left. Bots simulate thousands of runs per change and flag any weapon or
  fusion that is more than 25% above or below the median clear rate.

**Readability rules:**
- Every enemy attack that does more than 10% HP is telegraphed for at least
  0.6 s.
- The player's projectiles are drawn below enemy projectiles.
- Enemy shots are always red or orange; the player's shots are cool colors.

---

## 14. Graphics quality and performance budget

Based on `games/stress-test/` and
[stress-test-results.md](stress-test-results.md).

| Tier | Effects (as in the stress test) | Target FPS | Enemies on screen (starting budget) |
|---|---|---|---|
| Low | No glow; dots for bullets; 4 sparks per kill | 30 | 150 |
| Medium | Light glow; 6 sparks | 60 | 250 |
| High | Glow, streaks, rings | 60 | 400 |
| Ultra | Full glow, streaks, 16 sparks, rings, screen effects | Screen rate (120 on S25 Ultra) | 800 |

**Where these budgets come from:**
- The S25 Ultra held 3,900 enemies + 7,800 bullets at 118 FPS with simple
  dots.
- The real game costs more per enemy: animation, AI, varied attacks.
- So the Ultra budget is set well under the measured limit, leaving headroom.

**Rules:**
- **Check the budgets:** confirm them with the stress test on a budget phone.
- **If the processor runs out:** move the enemy, bullet and hit-check loop to
  C++ (GDExtension), as noted in the results.
- **Auto-detect the tier:** pick it from a 3-second benchmark on first launch.
  The player can still change it.

---

## 15. Art and audio list for World 1

| Asset | Count | Notes |
|---|---|---|
| Hero | 1 model, rig, about 8 animations | Idle, run, hit, death, victory, plus attachments for 24 items |
| Infantry enemies | 7 | Walk, attack, death frames, 8 directions or mirrored |
| Vehicles | 5 | Rigid sprites plus turret or rotor parts, wreck version |
| Elites | 2 | Bigger, more frames |
| Bosses | 3 | Multi-part, phase changes |
| Weapon VFX | 12 + 12 evolved | Mostly shaders and particles. Claude can build these |
| Power VFX | 12 | Auras, shields, shockwaves |
| Icons | 24 + 12 evolved | Icon packs or AI-generated, with a consistent frame |
| Backgrounds | 10 stages | Tiled ground plus props (wreckage, craters, barriers) |
| UI | One kit | Cards, menus, shop, codex |
| Music | 3–4 tracks | Menu, stage, boss, victory |
| Sound | About 80 sounds | Weapons, explosions, hits, UI, vehicles |

Claude builds code, shaders, VFX, UI layout and balancing. Character, vehicle
and boss art, plus icons, come from asset packs, AI tools or a freelancer (see
section 17).

---

## 16. Production plan

| Milestone | Contents | Exit test |
|---|---|---|
| **M1: Playable prototype** | Placeholder art. Hero movement, 3 infantry types plus tank and helicopter, 6 weapons and 6 powers with levels, pick-1-of-2 cards, 1 evolution, a 5-minute stage, 1 boss, quality tiers | Fun in 5 minutes on the S25 Ultra; runs at Ultra |
| **M2: Vertical slice** | Final art for the hero plus 4 enemies, all 12 + 12 World 1 items, juice pass, sound | Shows the target quality; usable for ad creatives |
| **M3: Ad test (CPI)** | 3–5 video ads from real gameplay; about $100–300 on India and a small US sample | CPI and click-through healthy (research targets) |
| **M4: World 1 complete** | 10 stages, 3 bosses, meta (gear, talents, mastery), economy, ads, IAP, analytics | Internal play; bots balance |
| **M5: Closed test, then soft launch** | Play closed test (12 testers × 14 days), then soft launch in 1–2 countries | D1 ≥ 40%, D7 ≥ 15%, ROAS tracking |
| **M6: Global launch** | Then World 2 (Arcana) as the first update | |

Start the Play Console account and recruit testers during M1–M2, because the
14-day closed test takes time.

---

## 17. Open decisions

| Decision | Options | Recommendation |
|---|---|---|
| Title | *Shatterverse*, *Omniforce*, *Rift Sovereign*, others | Check stores and trademarks, then pick |
| Hero tech | Real-time 3D model in 2D, or pre-rendered | Real-time 3D (visible upgrades) |
| Art source | Asset packs, AI tools, freelancer, mix | Mix: freelancer for the hero and bosses; packs or AI for the rest |
| Art style | Stylized 3D-look, hand-painted 2D, neon | Stylized 3D-look sprites with the neon effects from the stress test |
| Card count | Pick 1 of 2 (+ paid 3rd), or pick 1 of 3 | Start with 2 + paid 3rd; A/B test against 3 |
| Stage length | 5 min + boss, or longer | 5 min + boss |
| Energy | None, or light | None at launch |

---

## 18. Future plans (TODO)

Not scheduled yet. Pick these up after all World 1 stages are built and tested.

### Storyline (proposal, to finalize later)

Builds on [Story and hero](#2-story-and-hero). Goal: players feel connected to
the lore, replay runs, and stay longer, which also supports purchases.

**Premise:** the Fracture shattered the multiverse; in every broken world a
tyrant seized the power leaking out. The Anomaly wakes in the rubble with no
memory, made of Fracture energy, able to absorb a world's Core.

**The mystery:** each Core absorbed restores one memory. Over the worlds the
player learns that the Anomaly is a fragment of whoever caused the Fracture,
and that the real enemy, **the Hollow**, is a parasite riding inside each
world's tyrant, collecting the Cores to remake reality. World 1 ends when the
Iron General falls and the Hollow leaves his body.

**Systems that carry the story (and retention):**

| System | Why players come back |
|---|---|
| **Costumes are alternate Anomalies** from other broken worlds (Frost Warden from a frozen timeline, etc.), each with a short backstory | Costumes become lore to collect, not just cosmetics |
| **Memory shards**: rare drops from elites, chests and secret stages; a full set per world unlocks a secret ending panel and a costume | Replays and build variety |
| **Two endings per world**: absorb the Core (power path, corrupted look) or free the world (hero path, radiant look), each with its own bonus and dialogue | Replay for the other path |
| **Haven**: a home base where rescued survivors open shops (gear smith, costume tailor, codex researcher) | Visible progress; shops live inside the story |
| **ECHO**: a broken robot companion who narrates in a few lines between stages | Character and humor without long cutscenes |
| **Lore codex**: entries for every enemy, boss and weapon, with completion rewards | Collecting |
| **Rift Events**: seasonal broken worlds that bleed in for a limited time, each with a story chapter | Events and battle-pass retention |

**Delivery:** 3–4 comic panels per boss and a few ECHO lines per stage, made in
one consistent style with Higgsfield (about 20 images, about 10 credits, per
world).

**Open questions:** tone (epic, or heroic with ECHO's humor); a silent,
player-named hero or a voiced, named one; whether the twist above stays.

### Code health

- Split `games/prototype/game.gd` (about 3,700 lines) into modules: weapons,
  enemies, pickups, progression, effects. Do it at a quiet moment, because it
  touches every line other work is changing.
- Long lines: the lint config does not enforce a limit yet; wrap lines over
  about 120 characters when touching them.
