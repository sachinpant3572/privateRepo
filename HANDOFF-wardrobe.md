# Wardrobe (loose, varied clothing): research note

Status: research only (2026-10-29). Nothing is built; it waits on Sachin's word.
Question: "All clothings are too tight on every model ... Can the MakeHumans
model do all these accurately or can you check other repos or models ...?"

## Findings (verified from this container)
- Today's clothes are shells: body vertices tinted per region and pushed out by
  a few mm (BodyKit regions + CharacterKit `_warp` extras). That is why
  everything is skin-tight; skirts, baggy fits and coats can't come from shells.
- github.com/makehumancommunity/makehuman: code + base mesh only, no clothes.
  Its downloader points at github.com/makehumancommunity/makehuman-assets.git,
  which now asks for a login (gone or private); the sboris369 fork too.
- github.com/makehumancommunity/mpfb2: code only. Clothes come from asset packs
  on makehumancommunity.org (blocked here). Its docs describe MHCLO: each
  garment vertex = 3 base-mesh vertices with barycentric weights + an offset,
  plus `delete_verts` to hide the body under the garment. Our bodies are hm08,
  so MHCLO garments would map onto them.
- Blocked hosts: makehumancommunity.org (all), quaternius.com, itch.io,
  opengameart.org, kenney.nl, polyhaven.com.
- Quaternius Universal Base Characters + Modular Outfits: CC0, but the outfits
  are fantasy only, on their own body and 65-joint skeleton (web search).

## Recommended approach (if approved)
Separate garment meshes, built in code with the MHCLO method (anchor + ease
offset, hide covered body triangles), parameters for fit (skinny..oversized),
rise, length, flare and layer; skirts/dresses/sarees bridge both legs. Rigid
accessories (glasses, watches, ties, hats, bags, jewellery) ride one bone.
Hair as separate meshes. Cheap vs luxury = materials + detail by wealth tier.
