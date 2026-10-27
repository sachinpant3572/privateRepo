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
5. Metal (code 15) read near black because there are no reflection
   probes. The shader now fakes a sky-and-street reflection and metallic
   is 0.3, so every steel prop reads as light steel.
6. Props: three-stream bins (a solar compactor, recycling and compost),
   a solar pay station, a detailed hydrant, slatted benches, a domed
   litter bin and mailbox, and steel bollards. New props: a signal
   cabinet at every mast arm, district banners on half the downtown
   light runs, bike racks (downtown and the Quarter) and sidewalk works
   (downtown and the Wards). Works sit at the back of the sidewalk
   (frame z 1.7) and the bus shelter moved back to z 1.55.
   - People walk their loops in straight lines at frame z 0.75. A prop
     across that line held them there for good: the review found it at
     the works, and a sweep of every sidewalk segment found about 140
     such spots from earlier passes too.
   - Fix (pedestrian.gd): held up for 0.3 s, a pedestrian steps sideways
     (and a little back, out of pockets) for 0.8 s: building side first,
     the street side when that is blocked, never more than 0.6 m off the
     line toward the curb (1.2 m away). The first version picked a random
     side and walked a quarter of them into the road (second review).
   - `test_people_walk_past_sidewalk_props` walks two pedestrians past
     each downtown sidewalk prop in front of a building wall and checks
     they stay on the curb. Without the detour, 5 of its 10 checks fail:
     the roadworks and shelter rows only guard their placement.
7. Triangle cost, measured over all 655 cells:
   - mean 2.7k -> 3.5k per cell; p90 5.7k -> 7.1k; max 12k -> 17.1k (one
     120 x 205 m downtown block);
   - oaks were the biggest cost, then gas lamps and hydrants, which I
     slimmed;
   - about 70k triangles for a ~20-cell view.
8. Vehicles (agent, merged): 16 models, 224-408 triangles each.
   `VehicleKit.spec(kind)` lays a model's entry over the HANDLING
   defaults; `vehicle.gd` reads everything from it:
   - steering needs rolling wheels (`steer_low`) and fades at speed
     (`steer_fade`), so heavy models understeer;
   - power fades with speed (`power_fade`; the EV stays nearly flat);
   - own brake rate, reverse speed, grip, handbrake drift grip and
     throttle `slide` (the muscle car steps out);
   - vehicle-to-vehicle hits share speed loss, damage and shove by mass;
   - visual only: cars roll and pitch, bikes lean and the rider leans
     with them.
   Traffic list has no two-wheelers (no AI riders yet); curb spots take
   models up to 5.5 m. Traffic AI had to change for the big models: aim
   9 m ahead on the lane, slow near junctions, choose the turn on the
   approach, take sharp turns forward, back off after wall hits.

9. Review fixes: body roll, pitch and bike lean follow
   `get_real_velocity()`, so a vehicle pinned against a wall stays level.
   The bus stop sign stands at the curb, in front of the shelter. Green (sedum) roofs
   also get the leaf shading, since they are code 7 above 0.7 m; they read
   as planted roofs, so it stays.

## Open questions
- Player wall crashes still count over several frames (about 30 hp at
  10 m/s), as before; traffic counts each crash once.
- The traffic test needs 3 junctions in 30 s; the box truck sits right at
  3 on seed 11. A distance-based check would be sturdier if it flakes.
- Clothes, left as is for now: a tote bag swings with the arm when punching,
  the phone stays in the hand while riding, and no one wears a hood up.

## Traps
- Trees take more calls from the cell rng, so lots after them in a cell
  lay out differently from before (the Wards lookdev view changed). No
  test depends on it; landmarks and missions are fixed.
- Missions use the kinds "scooter" and "sports" and the outfits in
  missions/cast.gd; those keys must stay.
