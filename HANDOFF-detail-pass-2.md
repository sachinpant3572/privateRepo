# Detail pass 2: trees, clothes, props, vehicle roster

Task: Sachin, Oct 27: "do the next pass: trees, people's clothes, props.
And lets add more vehicles, different categories, several models with each
having a bit different vehicle physics."

Follows HANDOFF-modern-look.md (surface codes, shader, traps live there).

## Decisions
1. Split three ways, since the areas own separate files:
   - vehicles: background agent in a worktree (vehicle_kit.gd, vehicle.gd,
     population.gd, its gallery row and tests);
   - clothes: background agent in a worktree (character_kit.gd, the look
     tables in player.gd, cop.gd and missions/cast.gd, its gallery row);
   - trees and props: main session (prop_kit.gd, city_cells.gd placements,
     the shader's foliage).
   I merge, then run the gates and one review.
   Cost: about 2.5 h wall-clock, 2 agents of roughly 2-4M tokens each.
   Cheaper option: all three in one session one after another, about
   5-6 h and about a quarter fewer tokens.
2. Vehicle roster: categories compact, sedan, EV, luxury, SUV, sports,
   muscle, super, pickup, van, box truck, motorbike, scooter, plus taxi and
   police. Fictional names only, no real brands. Handling per model: mass,
   grip, drift grip, brakes, power curve, high-speed steering and
   durability, plus visual body roll and bike lean. Big vehicles (box truck)
   drive in traffic only; curb spots take only cars up to about 5.5 m.
3. People: present-day clothes (hoodies, puffers, bombers, joggers, jeans
   with sneakers, caps and beanies, backpacks, crossbody bags, headphones,
   phones in hand) and work wear (delivery rider, hi-vis, scrubs). Still
   rigid parts on bones, one skinned mesh per person. Named cast keep
   their identity.

## Open questions

## Traps
- Missions use the kinds "scooter" and "sports" and the outfits in
  missions/cast.gd; those keys must stay.
