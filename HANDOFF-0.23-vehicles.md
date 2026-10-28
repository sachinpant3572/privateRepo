# 0.23: vehicle classes, crash damage, blood, convertibles

Sachin, 2026-10-29: "Build vehicle collision, suspensions and damage physics
like GTA 4 too, for now we can have the physics same for all vehicle in
specified varieties, like scooters and bikes will come under one category,
cycles under one, hatchbacks under one, suvs under one, trucks and trailers
under one, muvs under one, sports cars/hypercars/luxury cars under one,
sedans under one, three wheelers under one, and so on. The planes, and boats,
helis and airships, cruise ships, or big titanic level water ships, these too
will have different physics according to their type and weights. Build
bloodwork when beating, or killing someone, either through melees, guns, or
vehicles. Build convertible cars too."

## Order (decided)

1. Ship 0.22 first: it carries the critical truck bug.
2. Then 0.23 builds the land classes, damage, blood and convertibles.
3. Boats and ships, then aircraft (planes, helis, airships), come after
   0.23. None exist in the game yet. Each needs new models, controls, a
   water or flight model, places to find them (docks, airfields, helipads)
   and camera work for altitude.
   - Rough cost: boats about one long session; aircraft one or two.
   - The class table below already reserves their rows, so the physics
     shape is set.

## Classes (`scripts/kits/vehicle_classes.gd`, keyed by the kit's category)

| class | kinds now | feel (GTA IV-like) |
|---|---|---|
| two_wheeler | motorbike, scooter | lean, rider thrown off over a crash speed |
| cycle | bicycle (new) | light, slow, rider thrown off easily |
| hatchback | compact, ev | light, bouncy, crumples easily |
| sedan | sedan, taxi, police | middle; soft roll, nose dive |
| suv | suv, crossover, pickup | tall, most roll, heavy |
| muv | van, muv (new) | tall and long, wallows |
| truck | box_truck, tipper, semi | very heavy, stiff, slow pitch, pushes cars |
| performance | sports, muscle, super, luxury, convertibles | stiff, low, little roll |
| three_wheeler | tuk_tuk, cargo_trike | tippy, light, bouncy |

Each class has:
- suspension spring frequency (Hz) and damping ratio, so the body bounces
  and overshoots;
- roll and pitch limits;
- a crumple factor (dent depth per unit of impact) and a damage
  multiplier;
- a mass scale on the kind's mass;
- for two-wheelers, the speed at which the rider is thrown off.

## Damage

- Dents: on an impact of 4 or more, the car copies its cached mesh on the
  first hit, then pushes the vertices near the contact point inward
  (falloff radius about 1.2 m, depth by impact x crumple, capped). The
  copy happens only on the first hit; later hits reuse it.
- A panel in body colour flies off on hard hits (debris; the parts are not
  separate meshes).
- Below 45% health the car smokes (as before); below 15% it burns, then explodes.
- Pushing: heavier vehicles shove lighter ones by mass. This is in from
  0.22's `shove`.

## Blood (agent package)

- `Fx.blood(pos, dir, amount)`: a spurt.
- Ground splats from a pooled MultiMesh, faded over time.
- A pool grows under the dead.
- Hooks:
  - `Humanoid.take_hit` (melee);
  - `hit_by_vehicle`;
  - a public `bleed()` for guns when guns land (there are no guns yet).
- Settings > Game "Blood" toggle, on by default.

## Models (agent package)

- Convertibles:
  - a roadster in the performance class;
  - a cabriolet in the luxury class;
  - roof up or down per spawn.
- A bicycle (cycle class).
- An MUV (seven-seat people mover).

## Packages

- Main session: classes, suspension, damage (vehicle.gd).
- Agent: blood.
- Agent: models.
- Each agent gets its own worktree from the 0.22 commit.

## Decisions (main package)

- The class owns the ride (suspension, roll and pitch limits), crumple,
  damage multiplier and rider-throw speed; the kind keeps engine, grip and
  mass. One table to tune per class, kinds keep their own pace.
- Suspension: a spring-damper per axis (roll, pitch, heave), semi-implicit
  Euler, `x'' = -w^2 (x - target) - 2 zeta w x'`. Cornering and braking set
  the target; impacts and slope changes kick the velocity. Two-wheelers
  keep their lean on top. First numbers below; renders tune them.
- Dents: a per-car copy of the cached mesh arrays on the first real hit,
  vertices within 1.2 m of the local contact point pushed toward the car's
  centre, depth capped per class. Mesh rebuilt at most every 0.1 s.
- Off-centre hits spin the car (`_spin`, decays). Hits of 12+ throw a
  body-colour panel (`scripts/car_debris.gd`, max 12 alive, 20 s).
- Fire below 15% (`scripts/car_fire.gd`, made only while burning): drains
  the car in about 7 s, then it explodes (wreck, big crash fx, shake,
  people within 6 m knocked down). Health <= 0 still wrecks at once.
- Two-wheelers and cycles throw their rider over the class throw speed.
- Boats, ships, planes, helis and airships have reserved rows (not used).

| class | Hz | zeta | roll max | crumple | cap m | dmg x | throw m/s |
|---|---|---|---|---|---|---|---|
| hatchback | 1.5 | 0.32 | 0.07 | 0.03 | 0.35 | 1.2 | |
| sedan | 1.3 | 0.35 | 0.09 | 0.025 | 0.3 | 1.0 | |
| suv | 1.1 | 0.3 | 0.12 | 0.02 | 0.3 | 0.85 | |
| muv | 1.1 | 0.33 | 0.11 | 0.022 | 0.3 | 0.95 | |
| truck | 1.2 | 0.5 | 0.06 | 0.008 | 0.15 | 0.5 | |
| performance | 2.0 | 0.55 | 0.035 | 0.028 | 0.3 | 1.1 | |
| three_wheeler | 1.8 | 0.3 | 0.14 | 0.04 | 0.4 | 1.4 | |
| two_wheeler | 2.2 | 0.5 | lean | 0 | 0 | 1.3 | 7 |
| cycle | 2.5 | 0.6 | lean | 0 | 0 | 1.5 | 5 |
