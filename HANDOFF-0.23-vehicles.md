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
- Below 35% health the car smokes; below 15% it burns, then wrecks.
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
