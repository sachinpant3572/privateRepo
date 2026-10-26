# World 1 prototype (M1 + M1.5)

The first playable version of the game in
[docs/game-design.md](../../docs/game-design.md): one 5-minute stage of World 1,
The Iron Dominion, then a boss.
- **Art:** placeholder, drawn in code.
- **Engine:** the same as `games/stress-test/`, with the same Low, Medium,
  High and Ultra quality tiers.

## What's in it

**The stage**
- 5:00 of escalating waves, then the **Colossus Siege Tank** boss. It has
  three turrets and three attacks: a shell sweep, a minefield, and a charge.
  It attacks faster below 50% HP.

**Domination and escalation:** the stage swings between two phases, so it
feels like losing, then winning, again and again:
- **Domination** (the start, and after every escalation): the difficulty
  stops rising, and new enemies get weaker (down to half HP) and more
  numerous while you keep leveling; late in it most are faded Conscripts.
  It ends once you clearly overpower the horde (4+ levels gained and it
  melting faster than it arrives, after at least 20 s) or after 50 s.
- **Escalation** (30 s): a ring of fresh troops closes in, the next two
  stage events hit (Ambush and Shield Wall first, the Siege Colossus last),
  a Juggernaut joins the 2nd and 4th, and the difficulty climbs fast.
- Level-ups heal 5% of your HP.

**Enemy tiers:** enemies look tougher as the stage goes on, and pay more.

| Tier | When | Look | XP |
|---|---|---|---|
| Conscripts | Late in a domination | Faded | 60% |
| Regulars | Start, 1st escalation | Standard | 100% |
| Veterans | 2nd and 3rd escalation | Gold trim, extra plating | 125% |
| Elite Guard | 4th escalation, boss, final push | Black and crimson, a size bigger | 150% |

Each tier has its own skin: `sprites/<unit>_t2.png` (Veterans: gold trim,
extra plating) and `_t3.png` (Elite Guard: black and crimson, glowing lines,
spikes) for all ten enemy sprites, AI-generated with Higgsfield from the
base sprites and fitted to their size and pivot. A light tint stays on
top.

**Enemy animation (code):** infantry sway and waddle as they walk, everything
kicks back when it fires, pops when hit and drops in when it spawns; tanks
rumble and recoil their turrets, helicopters hover, drift and bank.

**Enemies**

| Enemy | Behavior |
|---|---|
| Trooper | Shoots slow bullets |
| Shield Trooper | Blocks 75% of damage from the front |
| Grenadier | Grenades land on a red warning circle |
| Battle Tank | A red aiming line, then a fast shell |
| Attack Helicopter | Circles and fires rocket salvos |
| Juggernaut (elite, at 2:00 and 4:00) | Fires a 9-bullet fan; drops a **Power Chest** |

**Weapons (12, up to 4 at once), each with an evolution:** Pulse Rifle (you
start with it), Scatter Cannon, Rail Lance, Rocket Swarm, Grenade Rain, Razor
Halo, Combat Drones, Tesla Coil, Flame Burst, Mine Layer, Sentry Turret,
Airstrike Beacon. The pairings are in `data.gd` (`EVOLUTIONS`).

**Powers (36): 4 slots, plus a 5th slot that only takes a defense power:**
- **Attack:** Overclock, Explosive Rounds, Critical Targeting, Firepower,
  Blast Radius, Multishot, Velocity Rounds, Armor Piercer, Ricochet Matrix,
  Concussive Rounds, Vampiric Rounds.
- **Defense:** Titan Skin, Nanite Regeneration, Evasion Matrix, Kinetic
  Shield, Reactive Plating, Second Wind (revives), and four that work on
  their own, with no button:
  - **Barrier Dome:** when you're hit, a dome blocks all damage and enemy
    bullets for 2 s or more and shoves infantry out. Recharges in 30 s or
    less.
  - **EMP Burst:** every few seconds, wipes the enemy bullets around you and
    stuns the enemies there (stunned enemies don't shoot).
  - **Repair Drone:** a drone that repairs HP, twice as fast below 40%.
  - **Fortify:** up to 32% less damage taken, 64% while standing still.
- **Elements:** Incendiary (burn), Cryo (slow, freeze), Shock (arcs), Toxin
  (clouds).
- **Actives:** Phase Dash (DASH button), Shockwave Stomp, Bullet Time, Last
  Stand, Blood Oath (harder enemies, more XP and gold).
- **Utility:** Magnet Field, Adrenaline, Long Fuse, Lucky Charm, Battle
  Instinct (XP), Scavenger (gold).

**The hero (`hero.gd`):** the forearms and fists are cut out of the costume
at load time and hold the weapon, so the hands aim, swing and recoil with
it. The hero turns to face its target, and the torso and helmet twist toward
the aim.
Weapon feel, all cosmetic (movement and fire rate don't change): a braced
stance under sustained fire, muzzle climb, brass casings from the rifle and
scatter, barrel heat glow, the scatter's pump, rail steam and a charge glow
on the rail and tesla, footstep dust on alternating feet, a body twist on
hits, a whip-around on sharp turns and a weapon check when standing still.

**Gear that grows with the build (`hero.gd`):**
- **Helmet** (3 tiers) from survival powers, **pauldrons** (3 tiers) from
  armor and damage powers.
- **Back item** from the strongest build family: jetpack (speed and
  actives), missile pod (explosives), drone dock (summons), energy wings
  (elements and blades).
- **Weapon in hand:** the highest-level weapon; a new main weapon swaps in
  with an animation, and an evolved one glows gold.
- **Element aura** and a **shield bubble** while Kinetic Shield is charged.

**Costumes:** 12, bought with gold on the menu (Costumes). Gear stacks on top
of any costume.

**Level-up cards**
- Pick 1 of 2.
- Every 3rd level, and whenever you're below half HP, one card is a defense
  power.
- **Show 3rd card (ad):** free in this build, 3 per run. Real ads come later.
- **Reroll:** 1 per run.
- **Banish:** 3 per run; the item never comes back that run.
- **Skip:** no card; +5 gold and +10% HP instead.
- Rarity rises over the stage:

| Rarity | Effect |
|---|---|
| Common | +1 level |
| Rare | +1 level, +4% damage |
| Epic | +2 levels |
| Legendary | +3 levels, or an instant evolution |

**Evolutions**
- A weapon at level 8 plus its paired power evolves at the next Power Chest,
  or from a Legendary card.

| Weapon + power | Evolution |
|---|---|
| Pulse Rifle + Overclock | Storm Rifle |
| Rocket Swarm + Critical Targeting | Hellfire Barrage |
| Razor Halo + Adrenaline | Buzzsaw Halo |
| Airstrike Beacon + Explosive Rounds | Carpet Bomber |

**Revive:** once per run, free.

**Meteor Slam (button, bottom left):** kills charge it (by their XP; the
first slam needs 250, each one after 100 more, up to 900). Tap it and the
hero leaps toward the camera (bigger, higher, a spin, the shadow shrinking
on the ground), hangs, then crashes down: everything within 330 px is
destroyed, Juggernauts, gunships and Siege Colossi lose about 40%, the boss
6%, enemy bullets nearby vanish and a crater stays on the ground. The hero
can't be hit in the air and can steer the landing.

**Run report (`report.gd`):** the results screen shows the summary; COPY
RESULTS copies the full report: damage dealt by each weapon and power (and to the boss), damage
taken by enemy type, hits blocked, bullets destroyed, healing by source, when
and by what you went down, kills by enemy, pickups, card use, a
minute-by-minute timeline (level, kills, enemies, lowest HP, damage taken,
FPS, logic time) and every pick.

**Watch auto-play:** a bot plays the stage, so you can see everything without
playing.

**Feel and rewards (M1.5)**
- **Feedback:** damage numbers (crits big and golden), knockback on infantry,
  outlined sprites, and bigger enemies.
- **Gems:** colored by value (blue 1, green 5, red 25+).
- **Gold coins:** from kills, tanks, helicopters, elites and the boss. Total
  gold, best run and stats are saved between runs.
- **Treasure chests:**
  - Juggernauts drop them.
  - A slot-machine roll gives 1, 3 or 5 rewards (70% / 25% / 5% odds), plus
    gold.
  - A ready evolution always comes first.
- **Kill combo:**
  - Kills within 2 s chain together, boosting XP by up to +50% at 1,000.
  - Milestones (Killing Spree 50 → Apocalypse 2,000) pay gold.
  - Getting hit halves the combo.
- **Screen-clear pickups:** rare drops, always one from a Juggernaut.

| Pickup | Effect |
|---|---|
| Nuke | Wipes normal enemies; elites lose 25%, the boss 5% |
| Freeze | Stops all enemies for 5 s |
| Vacuum | Pulls in every gem and coin |
| Medkit | +30% HP |
| Shield Cell | Blocks the next 2 hits (up to 4 stored) |

- **Explosions:** layered. A white flash, rolling fireballs, rising smoke,
  sparks, a shockwave ring, and scorch marks that stay on the ground. They
  scale with the blast: rockets small, airstrikes bigger, tanks and
  helicopters huge, the boss enormous.
- **Readable actions:**

| Who | What you see |
|---|---|
| Troopers | Muzzle flashes |
| Tanks | A muzzle blast with smoke |
| Helicopters | Rocket smoke |
| Grenadiers | Grenades arcing through the air onto their warning circle |
| Shield Troopers | Shields flash when they block |

- **Weapon looks:**

| Weapon | Look |
|---|---|
| Pulse Rifle | Cyan tracers |
| Storm Rifle | Pale electric tracers |
| Scatter Cannon | Golden pellets with a muzzle blast |
| Rocket Swarm | Smoke trails |

- **Power moments:**
  - Every card you pick sends a burst from the hero: a colored flash, a ring
    of energy, enemies knocked back, and a brief slow-down. It's sized by
    rarity and level, with the item's name shown in its rarity color.
  - Evolutions are a gold blast that damages everything within 420 px.
- **Stage events**, two per escalation, in order: Ambush, Shield Wall, Tank
  Column, Bombing Run, Gunships, Armored Assault, Air Raid, Siege Colossus.
- **Sound effects:** synthesized in code (`sfx.gd`), so there are no audio
  files.
- **End of run:** +100 gold for a win, and "Double your gold (watch ad)",
  free in this build.

## Real sprites

Put a PNG in `sprites/` with one of these names and it replaces the code-drawn
version. No code changes needed.

**Specs:**
- Top-down view, facing right (+x). The game rotates units to face where they
  are going or aiming.
- Transparent background.
- About 128×128 px (the boss 256×192).
- Bold silhouettes with a dark outline.
- Factions:
  - Enemies: crimson and steel-grey.
  - Hero and player effects: cyan.

**Sprites:**
- **Units:** `trooper`, `shield`, `grenadier`, `elite` (Juggernaut), `tank`
  (body only), `turret` (tank turret, centered on the same point), `heli`
  (body only), `rotor`.
- **Hero and boss:** `hero`, `boss`, `boss_turret`.
- **Pickups:** `nuke`, `freeze`, `vacuum`, `medkit`.
- **Ground:** `ground`, an opaque seamless tile (512×512) repeated every 512 world pixels.

**Now real:** all 16 above, AI-generated with Higgsfield (GPT Image 2.5), then cropped and resized (the ground made seamless); `hero` and the pickups are 64×64 because the game draws them at texture size.

**Also AI-generated with Higgsfield:** `costumes/<id>` (128×128, top-down,
facing right, ids in `Data.COSTUMES`), `gear/` (helmets, pauldrons, back
items, wings; 128×128), `hand/<weapon id>` (weapon in hand, pointing right),
`icons/<weapon or power id>` (card icons, 96×96), `drone` and `sentry`.

## Controls
- **Move:** drag anywhere. The joystick appears where you touch.
- **Weapons:** fire on their own.
- **Android Back:** ends the run.

## Tech notes
- **Units:** one MultiMesh per sprite (8 draw calls for every enemy on
  screen), sharing one buffer. The placeholder sprites are drawn into one atlas
  image in `art.gd`, then split into textures. (An earlier version drew every
  unit in one call using MultiMesh custom data, but the Compatibility renderer
  drew nothing.)
- **Dead enemies:** they are only marked during the frame and removed at the
  end, so grid lists stay valid while weapons hit.
- **Same difficulty on every tier:**
  - The enemy count follows the clock, peaking at 320 at 4:00.
  - A tier that draws fewer enemies (Low 150, Medium 250) spawns fewer,
    tougher ones worth more XP.
  - Tiers otherwise change only the look: glow, streaks, particle and scorch
    budgets.
  - This replaces the first build, where the tier's enemy budget also set the
    difficulty and Ultra faced about 5× the enemies of Low.
- **Enemy fire:** troopers share a fire budget, so a big crowd can't fill the
  screen with bullets.

## How it's built
`.github/workflows/android-apk.yml` builds this and the stress test:
1. **Smoke test:** a bot plays the whole stage, then a second run with every
   item maxed and evolved.
2. **Screenshots:** the menu, every quality tier, the level-up cards, a
   treasure chest and the boss.
3. **APK:** published to the `prototype-builds` branch with the screenshots
   and the smoke log.
