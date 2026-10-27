# Modern look: more detail, set in the present day

Task: Sachin, Oct 27: "The graphics still seem primitive, I mean it is good
to show a vintage style but the game is set in the current modern times,
and we need to show more details."

This replaces the Oct 26 look decision in MVP_DESIGN.md ("low-poly 3D, toon
shading ... a readable cartoon, not realism"). The new target is stylised
but modern and detailed: still code-built and readable from the top-down
camera, but with modern materials, surfaces and street furniture.

## What reads as primitive (screenshots, Oct 27)
- Roofs fill most of the screen and are blank slabs.
- Ground is flat colour: plazas, sidewalks, asphalt with a centre line only.
- Cars are boxes; no glass, no shape.
- Toon shading (two flat tones) and linear tonemapping: no sheen on glass
  or paint, no soft falloff.
- Street furniture is 1990s: gas lamps, plain poles. Nothing says 2026
  (no EV chargers, bike lanes, bus shelters with screens, solar panels).

## Decisions
1. Do it procedurally in code (no credits, no asset imports). Cost: one
   long session, roughly 3-4 hours. Cheaper option: shading, roofs and road
   markings only (~1.5 h). Bigger option: AI-generated 3D models via
   Higgsfield (spends credits; Sachin said not to, so not taken).
2. Surface codes in vertex alpha, multiples of 1/16 (MeshBuilder):
   16 matte (default), 4 lit window, 8 lamp, 12 neon (as before),
   2 glass (sky reflection, sun glint, some panels lit at night),
   14 gloss (paint), 15 metal, 1 asphalt (grain, cracks, patches),
   3 concrete (slab grain, stains). The city shader reads them; one
   material and one draw call per cell stay.
3. Shading: burley diffuse + GGX specular instead of toon; filmic
   tonemapping. Vehicles and people keep StandardMaterial3D (stencil
   x-ray) but lose the toon ramp; car glass is a second mesh with a
   glossy material.
4. Work split: vehicles (vehicle_kit.gd, vehicle.gd glass) to one
   background agent in a worktree; everything else in the main session
   (shader, roofs, facades, streets, props).

5. More codes once the ground worked: 5 pavers, 6 roof membrane, 7 grass
   (mowing stripes), 9 solar cells, 10 lap siding / deck boards, 11
   standing-seam metal, 13 brick. Patterns run on UV = the point in the
   builder's local space (flat: x,z; walls: along-wall, y), so they line up
   with each building, street or parcel frame.
6. Code 4 (lit window) also renders as glass by day; dark windows are
   code 2 glass instead of matte black.
7. Tonemap: ACES at exposure 0.85, picked over linear, filmic (1.0, 1.25)
   and AgX (1.3) from side-by-side lookdev renders: richest colour and
   deepest shadows; filmic and AgX washed out the bright plazas.
8. Roofs: `_flat_roof` (parapet with coping, membrane or sedum, HVAC, vents,
   dish, stair hut on bigger roofs; the front half gets solar rows, a
   terrace, skylights or a condenser) on townhouses, ward apartments, the
   Blue Lantern and the precinct; towers get their own plant roof; gables
   are standing-seam metal with solar on some.
9. Streets: stop bars where traffic (right-hand) meets a junction, green
   bike boxes downtown and in the Quarter on wide streets, lane arrows on
   runs over 32 m, parking-lane lines on wide streets. No painted bike
   lanes: parked cars sit along every curb, so lanes would run under them.
10. Props: LED cobra-head lights, mast-arm signals (camera, street sign,
    ped signal), bus shelters with lit ads, bike-share docks, EV chargers,
    wayfinding totems, pay stations, bins, e-scooters. The Quarter keeps
    its gas lamps (historic district); it gains docks and scooters.
11. Cost: cells average 2.7k triangles (was 2.1k), the densest 12k (was
    7.3k); build p50 6 ms. Within budget for ~20 loaded cells on a phone.

## Open questions
- FPS on a real phone is unmeasured (the container has no GPU). The city
  shader does more per pixel now; Settings > Detail low skips the patterns.

## Traps
- Glow codes used to be matched with +-0.08; the new codes are 1/16 apart,
  so the shader decodes round(alpha * 16).
- Color.lerp() changes alpha (the code); darkened()/lightened() keep it.
- The gallery must set the cutaway `cut_radius` to 0, or it punches holes
  around the origin (there is no player).
- Shotgun-house blue rectangles on roofs are storm tarps (damaged houses),
  not solar panels; solar is dark navy.
- lookdev: `xvfb-run godot --rendering-driver opengl3 res://tests/lookdev.tscn
  -- <out_dir> [spots]`, about 11 s.
