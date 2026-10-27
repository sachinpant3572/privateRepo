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
4. Trees: foliage is `MeshBuilder.clump()`, a lumpy blob with shared
   vertices and smooth normals, darker underneath. Code 7 (GRASS) above
   0.7 m becomes leaf clusters in the city shader. Live oaks fork into
   four limbs with eight clumps and moss. Palms have a ringed, leaning
   trunk (the siding code) and nine folded fronds plus dead ones.
   Crepe myrtles have three stems and bloom clumps. Downtown sidewalks
   got street trees in grates, halfway between the street lights.
   Live oaks have six clumps; clumps are open underneath and branches
   have no end caps, since the camera never sees them.
7. Triangle cost, measured over all 655 cells:
   - mean 2.7k -> 3.5k per cell; p90 5.7k -> 7.1k; max 12k -> 17.1k (one
     120 x 205 m downtown block);
   - oaks were the biggest cost, then gas lamps and hydrants, which I
     slimmed;
   - about 70k triangles for a ~20-cell view.
5. Metal (code 15) read near black because there are no reflection
   probes. The shader now fakes a sky-and-street reflection and metallic
   is 0.3, so every steel prop reads as light steel.
6. Props: three-stream bins (a solar compactor, recycling and compost),
   a solar pay station, a detailed hydrant, slatted benches, a domed
   litter bin and mailbox, and steel bollards. New props: a signal
   cabinet at every mast arm, district banners on half the downtown
   light runs, bike racks, and sidewalk works (downtown, the Quarter and
   the Wards).

## Open questions

## Traps
- Trees take more calls from the cell rng, so lots after them in a cell
  lay out differently from before (the Wards lookdev view changed). No
  test depends on it; landmarks and missions are fixed.
- Missions use the kinds "scooter" and "sports" and the outfits in
  missions/cast.gd; those keys must stay.
