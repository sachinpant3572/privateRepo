# Which street-plan variation, and a summit that sees the city (2026-10-29)

Sachin, 2026-10-29: "Research thoroughly on which variation would be the best
for a top-down 3D isometric game like, in terms of driving, flying, riding a
bike, less but organic traffic, running errands, in terms of being scenic etc.
[...] And I want the mountain to be such that the whole city, or most of it can
be seen from the top [...] multiple ways to reach [...] a helipad, and a cable
car, and a restaurant + a telescope [...]"

Tags: [S] sourced (link below), [C] codebase fact (file:line), [M] my
calculation, [I] inference.

## Variations (reference/world/mix_options_sketch.png)

| Need | What the layout must give | Best |
|---|---|---|
| Errands, finding your way | Straight, connected main roads; grids score higher "intelligibility" than organic plans, and organic alleys hinder wayfinding [S1][S2] | 1, 2 |
| Light, varied traffic | Connected grids spread traffic; cul-de-sac hierarchies overload a few arterials [S3]. In this game the car count is a cap (8-18 by quality) times district level, hour and surges [C traffic.gd:63,624-630], so the layout sets where cars go, not how many | 1, 2 |
| Racing, bikes | Long flowing roads, hills, coast; field streets are short (70-80 m between junctions) | 2 (curved main roads outside downtown) |
| Flying | Landmarks and one tower knot to steer by; district patterns that read differently from above [I] | 2, 3 |
| Supermarkets, malls, showrooms | Big rectangular lots on main roads; malls at main-road crossings ("nodes"), corners worth most [S4] | 1, 2 |
| Scenic restaurants, buyable scenic buildings | Views: hill, river, coast, curved streets | 2 with 4's water pull |
| Weapon shops, shady houses, garages, secrets | Back streets, dead ends, odd corners; things that block the view and reveal gradually (BotW "triangle rule") [S5] | curved districts, the forest |
| Rich / middle / poor divide | Rich on hills and water with curving streets (LA: Bel Air, Hollywood Hills [S6]); poor on a flat tight grid near industry, rail, docks (South LA) [I from maps] | 2 with the Wards and docks kept straight |
| Towering skyline | One tower knot downtown; only downtown/midtown styles build towers [C city_cells.gd:154-155,1184] | all (downtown is the same) |
| Food and other stalls | Plazas, esplanade, beach, transit stops, wide sidewalks; wedge lots left by curves suit small plazas [I] | 2 |

**Recommendation: variation 2, adjusted.** Downtown grid kept; curves outside
it; but the poor and working districts (Wards, Ironwharf, docks) keep a tight
straight grid so the class divide shows in the street pattern itself; the rich
districts (Cable Hill contour streets, Florida coast, river edge) take the
curves and 4's stronger pull along the water; main-road crossings are kept
for malls and supermarkets. Cost as variation 2, ~28-40 h, plus ~1-2 h.

## The mountain today [C]

- Bellerive Hills: local (165..2210, -1840..-430), 8 m height grid, highest
  point 113.6 m at (1104, -1264) (tools/mountain.py:24-37; HANDOFF-roads-mountain
  says 114). Not ~72 m as an older note said.
- Roads up: Canyon Freeway, Crest Drive, Coyote Canyon Road, Observatory Road
  (hairpins), Summit Fire Road, Letters Trail (mountain.py:64-86). Grade caps:
  highway 7.5 %, road 13 %, track 25 %, trail 30 % (:58).
- Observatory at (1050, -909) with coin telescope props (mountain.py:48,
  skyline_kit.gd:1013,1085). Helipads are rooftop decoration only.
- No tunnels, overpasses or underpasses anywhere (INTERIORS_SERVICES_PLAN.md:38).
- Camera: perspective, FOV 35 degrees, pitch 40-90 (default 65); at most ~140 m
  back and ~160 m of ground deep; far plane = 4 x distance (top_down_camera.gd:42-49,
  75, 913-924). "Look up" is the only eye-level view (far 4000, fog 140-420 m).
- Streaming: city cells within 105 m (to ~211 m), country tiles 130 m (to
  ~261 m) (city.gd:45-46, country.gd:24-25, main.gd:175-186). No far LOD.
  **Today a summit sees terrain within ~260 m, then water and sky: no city.**

## Seeing the city from the top [M]

Angle below the horizon from the summit (1104, -1264):

| Height | North edge 834 m | Downtown 1.7 km | Far corners 3.2-3.5 km |
|---|---|---|---|
| 114 m (now) | 7.8 | 3.8 | 1.9-2.0 |
| 200 m | 13.5 | 6.7 | 3.3-3.5 |
| 300 m | 19.8 | 10.0 | 4.9-5.3 |
| 350 m | 22.8 | 11.6 | 5.7-6.2 |

- At 114 m the whole city sits in a 2-8 degree strip at the horizon: flat, no
  feeling of height. At ~300 m it fills a 5-20 degree band, which a 35 degree
  lens pitched ~12 degrees down frames whole, downtown in the middle and 150 m
  towers rising to half the summit's height.
- Real references: Griffith Observatory 346 m, downtown LA ~14 km off, public
  telescopes [S7]; Twin Peaks SF 282 m, a figure-eight road to a vista point
  [S8]; Mount Chiliad 798 m, cable car, summit deck with $1 telescopes [S9].
- A straight-down camera would need ~3.1 km of height to frame 3.5 km: the
  summit view must be an angled view, not the play camera zoomed out.

## What the summit needs

1. Raise the peak to ~300 m (mountain.py ridge heights, MAX_H 150 now); the
   generator re-grades the roads to the same caps. ~6-10 h with the country rerun.
2. Far view: a low-detail whole-city mesh per district (block boxes, roof
   colours, tower silhouettes, lit windows at night), a coarse terrain mesh,
   haze. Mobile budget: ~13 merged meshes. ~10-16 h.
3. Summit view mode at viewpoints (deck, restaurant terrace, helipad): camera
   rises and tilts to ~12-20 degrees toward the city. Telescope: narrow lens
   aimed by drag; streaming already loads around the view centre (city.gd:203),
   so the real cells load where it points. ~5-8 h.
4. Ways up: main road (switchbacks; 300 m at 10 % is ~3 km of road), forest
   trails and stairs for bikes and on foot, shortcuts, jumps; off-road grip.
   ~4-8 h.
5. Underpasses and tunnels: new grade-separation code (bridge decks, portals,
   see-through in tunnels for the top-down camera). ~12-20 h.
6. Cable car Cable Hill to summit (~1-1.3 km, ~300 m rise), stations, towers,
   rideable. ~6-10 h.
7. Summit restaurant (enterable, terrace) and helipad. ~4-6 h. Flying it needs
   helicopters (#82, estimated 1-2 sessions in HANDOFF-0.23-vehicles.md).

Mountain total ~50-80 h (aircraft extra). Risks: phone frame rate with the far
view; the play camera on steep slopes; country regeneration.

## Sources

- S1 Lisbon grid/organic/contemporary comparison: https://wctrs-society.com/wp-content/uploads/abstracts/rio/general/2536.pdf
- S2 Askarizad et al. 2024, organic alleyways: https://iris.unica.it/handle/11584/412063
- S3 Miami-Dade arterial grid study: https://www.miamidadetpo.org/library/archives/mdtpo-arterial-grid-analysis-study-presentation-2007-archived.pdf ; NJ Route 57: https://www.nj.gov/transportation/works/studies/rt57/pdf/StreetConnectivity..pdf
- S4 Durham UDO 4.4.3 nodes: https://durham.municipal.codes/UDO/4.4.3 ; corner lots: https://businessjournaldaily.com/corner-lots-command-top-commercial-dollars/
- S5 BotW CEDEC 2017 (translation): https://gist.github.com/idbrii/e39fe96279aa1670319bfa521d907399
- S6 LA "topography of wealth": https://googlemapsmania.blogspot.com/2024/08/the-money-mountains-of-los-angeles.html
- S7 Griffith Observatory: https://www.wikiwand.com/en/Griffith_Observatory
- S8 Twin Peaks: https://en.wikipedia.org/wiki/Twin_Peaks_(San_Francisco)
- S9 Mount Chiliad: https://gta.wiki/w/Mount_Chiliad_(HD_Universe) ; telescopes and deck: https://www.grandtheftwiki.com/Mount_Chiliad_in_GTA_V
