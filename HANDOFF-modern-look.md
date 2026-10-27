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

## Open questions
- (none yet)

## Traps
- Glow codes used to be matched with +-0.08; the new codes are 1/16 apart,
  so the shader decodes round(alpha * 16).
