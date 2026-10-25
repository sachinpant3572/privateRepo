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

**Enemies**

| Enemy | Behavior |
|---|---|
| Trooper | Shoots slow bullets |
| Shield Trooper | Blocks 75% of damage from the front |
| Grenadier | Grenades land on a red warning circle |
| Battle Tank | A red aiming line, then a fast shell |
| Attack Helicopter | Circles and fires rocket salvos |
| Juggernaut (elite, at 2:00 and 4:00) | Fires a 9-bullet fan; drops a **Power Chest** |

**Weapons:** Pulse Rifle (you start with it), Scatter Cannon, Rocket Swarm,
Razor Halo, Tesla Coil, Airstrike Beacon.

**Powers:** Overclock, Titan Skin, Magnet Field, Adrenaline, Explosive
Rounds, Critical Targeting.

**Level-up cards**
- Pick 1 of 2.
- **Show 3rd card (ad):** free in this build, 3 per run. Real ads come later.
- **Reroll:** 1 per run.
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

- **Timed events:** Ambush (1:30), Shield Wall (2:30), Tank Column (3:15),
  Air Raid (4:30).
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
- **Enemy budgets per tier:** Low 150, Medium 250, High 400, Ultra 800.
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
