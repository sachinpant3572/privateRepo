# HANDOFF wardrobe: loose, varied clothing

Sachin, 10-29: "All clothings are too tight on every model, in real life there
are several kinds of clothings meant for both male and female genders, casual,
office, sportswear, luxury, cheap ones, undergarments, shoes, glasses, specs,
accessories, obscure fashion, abstract fashion, trendy clothes, different
hairstyles, stockings, shoes, slippers, skirts, pants, baggy pants, straight
fit, narrow fit, low waist, belts, suits, ethnic wear, watches, ties, shirts,
t shirts, etc." Then, on the options: "Go with your recommendation but please
ensure they are good" (option 5, garments built in code, with AI meshes for
rigid accessories; all three phases).

## Research (10-29, verified from this container)

- Shells: 0.25 clothes are body vertices tinted per region and pushed out a
  few mm (BodyKit regions + CharacterKit `_warp` extras), hence skin-tight.
- github.com/makehumancommunity/makehuman: code + base mesh, no clothes. Its
  downloader's github.com/makehumancommunity/makehuman-assets.git asks for a
  login (gone or private), the sboris369 fork too. mpfb2 is code only; its
  docs give the MHCLO idea used here: garment vertex = body anchor + offset,
  `delete_verts` hides the body under the garment.
- Blocked here (not retried): makehumancommunity.org, quaternius.com,
  itch.io, opengameart.org, kenney.nl, polyhaven.com (plus the people-v2 list).
- Quaternius outfits: CC0 but fantasy only, own body and skeleton.

## Decisions

- Order: 0.25 ships first (review, fixes, APK) with shell clothes; the
  wardrobe is 0.26. Reason: 0.25 is gated and Sachin can test bodies now.
- Accessories in code, not AI meshes (deviation from the option text):
  glasses, watches, ties are 2-6 px tall at the game camera; AI meshes are
  10-50k tris each and need retopology; code parts are 20-200 tris, fit every
  body from the fit tables and take any colour. AI generation stays possible
  for a hero-only item if close-ups show a need.
- Garments are separate meshes in a new `GarmentKit` (garment_kit.gd):
  1. Body-copy garments (tops, sleeves, trousers, shorts, leggings): the
     body triangles a garment covers, cut along its own border by the same
     edge-cut machinery as BodyKit regions (clean hems), each vertex moved
     out by a per-vertex field: ease (fit profile, cm by zone) + drape fill.
     Skinning copies the body's weights, so it moves with the body.
  2. Drape fill: torso in slice coordinates (height x 16 angle bins), limbs
     in limb frames (along x angle): per level a convex hull (cloth bridges
     the spine groove, between breasts, the crotch), then hang from above
     (radius may shrink downward only by slope k per metre: tight follows
     the body, loose falls straight); legs can round out and flare (bootcut,
     wide) or gather (joggers' cuff). The fill is smoothed over the mesh.
  3. Generated garments (skirts, dress skirts, coat tails, kurta and
     sherwani skirts, lungi, saree): rings from the waistband down, radius
     = max(hull of the hips-and-thighs slice + ease, hang + flare), pleats as
     a radial zigzag, slits and open fronts as angle gaps. Weights: hips at
     the top; lower down each side follows its thigh (shin below the knee),
     the centre splits between both, so legs don't pierce it walking.
  4. Layers inner to outer (under, shirt, sweater, jacket, coat): each
     layer's offset >= inner layer's + 3 mm where they overlap; a tucked
     top stays inside the bottoms' waistband. Body under any garment is
     HIDDEN (fewer tris, no poke-through).
  5. Openings: lips join a body-copy garment's border to the body (cuffs,
     neckline, hems), in a darker lining colour; generated hems get a turned
     band and a short inner band.
  6. Kit extras (prints, panels, collars, belts, hivis) warp onto the outer
     layer (the layer field), not the skin.
- Looks keep their keys; new optional keys: fit_top (tight, slim, regular,
  loose, oversized), fit_legs (skinny, slim, straight, relaxed, baggy, wide,
  bootcut), rise (low, mid, high), leg_len (shorts, knee, capri, full,
  stacked), skirt (pencil, aline, pleated, flared, wrap) + length, tuck,
  fabric. Defaults come from outfit/bottoms so old looks still work.
- Fabric shader for people (vertex alpha code + UVs round the garment):
  cotton, denim twill, knit rib, leather and silk sheen, wool fleck, stripes,
  checks/plaid, pinstripe, prints. Cheap vs luxury = fabric + palette + fit +
  accessories by wealth tier.

## Plan

- A: garment core, tops, bottoms (all fits/rises/lengths), skirts, dresses,
  layering, fabric shader; looks generation; tests; wardrobe shot page.
- B: footwear types (sneakers, runners, oxfords, loafers, boots, heels,
  sandals, slippers, flip-flops), accessories (glasses, sunglasses, watches,
  ties, bow ties, belts, jewellery, scarves), hair meshes (15-25 styles).
- C: ethnic wear (kurta, salwar, saree, sherwani, dhoti, lungi, more),
  cheap/mid/luxury tiers by land value, hero wardrobe (clothes shop, owned
  items, change at home), saved.
- Budget target: crowd near LOD <= about 5500 tris average, hero <= 14000.

## Open questions / traps

- (none yet)
