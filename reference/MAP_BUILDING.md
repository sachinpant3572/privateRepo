# Map building: research and the Bellerive street plan

Status: Oct 27, 2026. Why the first demo map read as a chessboard, what
city-building research and other games say about it, and the plan used to
overhaul the Bellerive demo map (`game/scripts/street_plan.gd`).

Sources are listed at the end. Some came from search summaries rather than
full pages (several sites could not be opened from the build environment),
and that is marked where it matters.

## 1. What was wrong

The first demo map was 25 x 22 identical cells:
- every block was the same 40 m square;
- every street was the same 12 m wide;
- every street was axis-aligned and continued unbroken from edge to edge;
- the river only removed squares.

From above, and on the minimap, that is a chessboard. The block layouts
(townhouse rings, shotgun rows, towers) varied the contents, but not the
pattern the eye reads first: the streets.

## 2. What the research says

### Legibility: Lynch's five elements
Kevin Lynch's *The Image of the City* (1960) describes how people picture a
city in five elements:
- **paths**: the channels people move along;
- **edges**: boundaries such as rivers, walls and rail lines;
- **districts**: areas with a recognisable character;
- **nodes**: junctions and squares where paths meet;
- **landmarks**: reference points seen from far away.

Game designers use the same five as a checklist for towns:
- paths should be unmistakable;
- edges such as rivers and level changes segment districts;
- a player dropped anywhere should still recognise the district;
- nodes create a hierarchy of attention, and landmarks orient.

A small wayfinding study of an open-world game found players lean on
game-specific cues (NPCs, visual clues) as well, so the five are a
checklist, not a guarantee. Playtest it. [1][2][3]

### A grid needs breaking up
Grids are criticised for monotony (Camillo Sitte). Even defenders of the
grid say it works best when broken by parks, plazas and diagonals:
- Chicago is cited as the city that missed out on Parisian boulevards.
- Barcelona's Eixample is a regular grid made varied by **hierarchy**:
  diagonal arterials over minor streets, which also produce a mix of block
  sizes.
- Superblocks group several blocks inside arterial roads. [4][5]

### Streets that follow the river: New Orleans
Most New Orleans streets either run **parallel to the Mississippi, bending
with its crescent**, or cut across the bend at right angles, like spokes of
a wheel. Locals give directions as upriver, downriver, lakeside and
riverside, not by the compass. [6]
- **Canal Street** separated the old French city from the American sector
  (now the CBD). A canal that was never dug left a 170 ft (52 m) wide
  strip: two roadways with a central reservation. [7]
- That reservation became the **neutral ground**, the local word for every
  median since. Medians carry streetcars and lines of live oaks. Esplanade
  and St. Charles are wide boulevards with park-like neutral grounds. [8][9]
- The **French Quarter** is a small, dense grid oriented to the river,
  about 6 by 13 blocks, laid out by Adrien de Pauger in 1721. [10][11]

### How other games did it
- **Vice City's art director, Aaron Garbut:**
  - the team moved roads and reshaped land whenever it helped play, because
    "real cities are not designed for tearing around at 150 miles an hour";
  - the map was based closely on Miami and packed densely with detail and
    variety. [12]
- **GTA: Chinatown Wars** used a similar 3/4 view. It kept GTA IV's road
  layout with small tweaks for the new gameplay (no split-level roads, for
  one) and leaned on a GPS that shows the fastest legal route. [13][14]
- **San Andreas** felt bigger than it was because of variety and density;
  GTA V was criticised for size over substance. [15]
- A 2025 interview on believable open-world cities (Mafia III's world
  designer) argues that paths, landmarks, districts, infrastructure and
  faction boundaries should be settled before environment art. Only the
  summary was available. [16]

### Procedural street generation
- **Parish and Müller (2001):** roads grow from L-systems steered by global
  goals and local constraints. Blocks are the faces between roads, and lots
  are split recursively along their longest side until small enough.
- **Chen et al. (2008):** streets follow a tensor field, so they curve and
  meet at sensible angles, and the field can be edited by hand. [17][18]

For a hand-directed demo map these are more machinery than needed. Their
useful ideas are:
- blocks are polygons between streets, not fixed squares;
- lots are subdivided to fit the block;
- the street directions come from a smooth field. Here that field is the
  river's crescent.

## 3. Rules for Bellerive

1. **Streets follow the river.**
   - The "parallel" streets are arcs concentric with the Morrow's crescent;
     the "spoke" streets radiate from it.
   - Nothing is axis-aligned except near the middle of the map.
   - Blocks widen away from the river, as in Uptown New Orleans.
2. **A road hierarchy that reads at a glance:**
   - boulevards with neutral grounds (oaks, the streetcar);
   - avenues;
   - ordinary streets;
   - narrow Quarter streets;
   - pedestrian lanes.

   Each has its own width, markings and street furniture.
3. **Uneven blocks.**
   - Spacing changes by district: the Quarter is tight, Gilt is big and the
     Wards are long.
   - Every junction is nudged a little so no two blocks are identical.
4. **Interruptions.**
   - Some Ward and dock streets stop at T-junctions.
   - Some Quarter streets are pedestrian lanes.
   - Some blocks are parks, plazas or parking lots instead of buildings.
5. **Edges.**
   - The river road curves along the bank; the boulevard divides districts.
   - The playable edge follows the street pattern, not a square.
6. **Nodes and landmarks.** Squares and plazas sit where boulevards meet.
   Landmarks face the street that leads to them.
7. **Blocks are built to their shape.**
   - Buildings line each side of the actual block polygon, facing its
     street, at whatever angle that street runs.
   - Corners are trimmed so rows don't collide.
8. **Fun before realism.** Boulevards are long, readable driving lines. Lanes
   and pedestrian streets are on-foot shortcuts for losing the police.

## 4. How it is built

`street_plan.gd` turns the 25 x 22 street grid into a warped, graded street
plan. The topology stays a grid, so traffic, streaming, the GPS and the
missions keep working. Each junction gets a real position:

- **Crescent frame:**
  - Columns map to an angle around a centre about 3.5 km south of the
    river; rows map to a radius.
  - Rows are therefore arcs, and columns are radial spokes.
- **Spacing:** column and row spacings vary by district (Quarter rows
  short, Gilt rows long), plus a small random nudge per junction.
- **Street classes per edge:**

  | Class | Width | Where |
  |---|---|---|
  | Boulevard | 22-24 m, with neutral ground | The Lantern Line spoke, and the arc between Gilt and the Quarter |
  | Avenue | 15 m | The spoke between the Quarter and the Wards |
  | River road | 14 m | Along the bank |
  | Street | 11 m | Most of the map |
  | Quarter street | 9 m | Inside the Lantern Quarter |
  | Lane | 7 m, paved, no cars | Pedestrian lanes |
  | (closed) | none | Removed streets, which make T-junctions |

- **Bank:** junctions next to the river are pulled onto a curve a fixed
  distance from the water, so the river road bends with the river.
- **Blocks:** each block's four corners are the junctions around it. Each
  side is pulled in by half that street's width, then by the sidewalk, to
  give the lot polygon the buildings stand on.

## 5. Result (Oct 27, 2026)

- **Street classes** in the window: about 860 streets, 250 narrow Quarter
  streets, 57 river road, 30 boulevard, 21 avenue, 27 pedestrian lane and
  46 closed segments.
- **Shape:** over 100 street segments are tilted more than 5° from the
  compass, and block sizes vary by more than 30% between the 10th and 90th
  percentile. `test_street_plan_is_not_a_grid` checks these, and that every
  junction north of the river can be driven to.
- **Liberty Green** sits where the Quarter meets the Wards.
- **The Morrow** in `world_map.json` was reshaped near Bellerive to follow
  the crescent, so the bank is one smooth curve. Across the river, a strip
  of the far bank shows inside the window; it can't be reached yet (no
  bridge).
- **Next steps:**
  - a diagonal avenue across the Wards (like Esplanade), which needs blocks
    split along it;
  - a bridge or ferry to the far bank;
  - reading GTA and Gangstar maps for how far apart shortcuts and alleys
    should be.

## Sources

1. Lynch, *The Image of the City* (1960), summarised at https://ecampusontario.pressbooks.pub/studioskills/?p=172 and https://kahell.notion.site/The-Image-of-the-City-ded7b485039f459f996844bef87f8084
2. "The 5 Ingredients of Game Town Design" (LinkedIn article series), via search summary.
3. Wellesley College poster on open-world wayfinding (Sable): https://cs.wellesley.edu/~pmwh/mvmap/posters/open_world_elements/IOOW_Poster.pdf
4. "The Return of the Grid", Governing: https://www.governing.com/topics/transportation-infrastructure/The-Return-The-Grid.html
5. MIT AgeLab, "Urban planning in Barcelona, from blocks to superblocks": https://agelab.mit.edu/blog/urban-planning-barcelona-blocks-superblocks
6. Downtown New Orleans (street layout): https://en.wikipedia.org/wiki/Downtown_New_Orleans
7. Canal Street, New Orleans: https://en.wikipedia.org/wiki/Canal_Street,_New_Orleans
8. "Why do we call the medians of divided streets neutral grounds?", The Advocate (Gambit): https://www.theadvocate.com/gambit/new_orleans/news/blake_pontchartrain/why-do-we-call-the-medians-of-divided-streets-neutral-grounds/article_426a64d9-4f17-5c70-881f-6cb0c13728b8.html
9. Esplanade Avenue: https://en.wikipedia.org/wiki/Esplanade_Avenue,_New_Orleans ; Esplanade Ridge historic district (City of New Orleans): https://nola.gov/nola/media/HDLC/Historic%20Districts/Esplanade-Ridge.pdf
10. Adrien de Pauger: https://en.wikipedia.org/wiki/Adrien_de_Pauger
11. "The French Quarter: three centuries, thirteen blocks", Dirty Coast: https://dirtycoast.com/blogs/the-dirt2/french-quarter-three-centuries-thirteen-blocks
12. GameSpot, *Grand Theft Auto: Vice City* level design Q&A: https://www.gamespot.com/ps2/adventure/gta_vc/preview_2885365.html
13. Engadget, NYCC 09 *Chinatown Wars* hands-on: https://www.engadget.com/2009-02-06-nycc-09-gta-chinatown-wars-hands-on.html
14. GameSpot, *Chinatown Wars* hands-on: https://www.gamespot.com/articles/grand-theft-auto-chinatown-wars-hands-on/1100-6203423/
15. FiveMX news piece on GTA map sizes (search summary): https://fivemx.com/pt/?p=175695
16. 80.lv, "Hidden design decisions behind believable open-world cities" (summary only; the page could not be opened): https://80.lv/articles/hidden-design-decisions-behind-believable-open-world-cities
17. Purdue / SIGGRAPH 2011 course notes on urban layouts (Parish and Müller 2001; Chen et al. 2008): https://www.cs.purdue.edu/cgvlab/urban/sg_2011_course/umc_SG11_02_urban_layouts.pdf
18. Larive, thesis on procedural cities (block and lot stages): https://otik.uk.zcu.cz/bitstream/11025/11197/1/Larive.pdf
