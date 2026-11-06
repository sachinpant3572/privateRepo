# Map building: research and the Bellerive street plan

Status: Oct 27, 2026 (map v2). Why the first demo maps read as a grid,
what city-building research and other games (GTA, Watch Dogs) say about
it, and how the Bellerive demo map is built now
(`game/scripts/street_plan.gd`).

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

## 4. How it is built (map v2)

Map 0.3 bent a 25 x 22 grid into a crescent. From above it still read as a
grid: every block had four sides and every junction was a crossroads. Map
v2 (`street_plan.gd`, rewritten) builds a general street graph instead:
nodes and blocks have int ids, and blocks have any number of sides.

- **District patches.** The land is cut into regions by the seam roads.
  Each region gets its own street pattern:
  - its own angle and spacing;
  - a **bend** (the long streets curve with the river);
  - a **fan** (the cross streets splay like spokes round the crescent);
  - a **cross-bend** (the cross streets curve too);
  - **jogs**: a cross street between two long streets often steps
    sideways by a third of a block, so it meets them at offset
    T-junctions instead of crossing (old towns and New Orleans' faubourg
    seams do this).

  | Patch | Angle | Blocks |
  |---|---|---|
  | Gilt West | -9° | Big downtown blocks, fanned |
  | Gilt East | +6° | Big blocks, curved the other way |
  | Gilt South | +29° | One row of streets between Liberty and Crescent |
  | Lantern Quarter West / East | -12° / -6° | Tight blocks, strongly fanned and curved |
  | Floodline Wards south / north | -25° / +30° | Long shotgun blocks; the north half fanned and curved, split from the south by Bayou Road |
  | Ironwharf | +9° | Big yards on the wharves |
  | Morrow Point West / East | +16° / -20° | Far bank, fanned; the halves meet at a chevron on Point Avenue |

- **Seams and long roads:**
  - Crescent Boulevard (Gilt | Quarter), Rampart Avenue (west | east),
    Wharf Street (Wards | docks) and **Bayou Road**, curving east from
    Rampart across the Wards (north | south);
  - Lantern Boulevard, from Union Station to the river and over **Morrow
    Bridge** to Morrow Point;
  - **Liberty Avenue**, the diagonal from Aurum Tower through the
    Crescent/Rampart junction to Ironwharf (like Esplanade);
  - Magnolia Avenue, curving through Gilt West;
  - the River Road and the Levee Road along the banks.
- **Clean edges.** A district street that runs alongside its district's
  edge, grazes it, or runs into it at less than about 24° is cut back
  there (it would leave a sliver of a block).
- **Arrangement.** All lines are overlaid and split where they cross. Each
  block is a face of the graph, found by walking half-edges.
- **Thinning.** Minor streets are dropped at random per patch, so streets
  stop at T-junctions and sightlines break. A drop is kept only if:
  - the two ends of the dropped street are still joined by drivable
    streets (so every junction can still be driven to);
  - no dead end appears, and it is not the short step of a jogged street;
  - the joined block stays under the patch's size cap.

  A junction where five or more streets meet (district streets crossing
  a road right at another junction) then loses district streets,
  shortest first, until four are left.
- **Liberty Green** is designed, not left over: a 120 x 80 m park on the
  north side of Liberty Avenue, with a street round its other three sides.
- **Landmark blocks** that are too small are joined with the neighbour that
  best improves the fit for the landmark's lot. The fit is measured with
  the rectangle that best holds the lot, not the biggest one: an L-shaped
  block's biggest rectangle can be a long strip. The rectangle must also
  sit on a street side, centred within it, and that side becomes the
  block's front, so the landmark's door faces a real sidewalk.
- **Block geometry:**
  - inner = the face minus half of each street's width;
  - lot = inner minus the sidewalk;
  - buildings stand in the biggest rectangle that fits the lot, aligned
    with the front street, split into parcels by district;
  - the leftover corners get trees, planters or barrels;
  - blocks too small for a rectangle become small greens.
- **Docks** keep their wharves: their bank edges are a "quay" (a wall, not
  a road). Elsewhere the River Road runs along the bank.

## 5. Result (map v2, Oct 27, 2026)

Measured in the game's own build (seed 1234), inside the playable window.
`test_street_plan_is_not_a_grid` checks each of these.

| Measure | Map 0.3 | Map v2 |
|---|---|---|
| Blocks that are not plain rectangles | none | 44% (233 of 521): not four-cornered, a corner more than 12° off square, or bent sides |
| Junctions | all crossroads | 497 T-junctions, 233 crossroads, 1 with five streets (Crescent, Liberty and Rampart) |
| Drivable street length within 10° of the compass | most | 32% |
| Floodline Wards street length in its best 30° band (both street directions) | 100% | 52% |
| Block area (10th / 50th / 90th percentile) | one size | 1,580 / 3,090 / 5,910 m² |

- **Streets in the window:**
  - 745 ordinary street segments and 333 Quarter street segments;
  - 125 avenue, 49 boulevard and 50 river road segments;
  - 53 pedestrian lanes, 7 quay walls and the bridge.
- **No holes:** every street has a block on at least one side, except the
  bridge, and land sampled every 10 m across the window is all in blocks
  (the river banks run on to the map's edge); lots keep their corners.
- **Other seeds:** seeds 1, 2, 3, 7, 42, 99 and 2024 also place all 13
  landmarks on their streets, with no holes.
- **Build time:** 0.65-0.9 s on a desktop CPU (up to 1.1 s under load) (blocks about 0.2 s, the
  rest under 0.1 s each); it may be 2-4x slower on a phone.
- **Both of Sachin's asks:**
  - Morrow Bridge reaches Morrow Point, a new district on the far bank;
  - Liberty Avenue is the diagonal avenue.

## 6. How GTA and Watch Dogs built their cities

Researched Oct 27, 2026 for map v2. Most of these sources are press
interviews and fan analyses, not developer talks. Several pages could not
be opened from the build environment, so only a search summary was read;
those are marked *(summary only)*.

### Watch Dogs: Chicago, curved on purpose
- **Starting point.** A developer (named only as Arriola) says the team:
  - started from a top-down view of the real Chicago map in the editor;
  - laid roads by following the real streets and adjusting them, for
    example making Wacker follow the river.

  Neighbourhoods and landmarks came after the roads were set. [19]
  *(summary only)*
- **Not the real grid.** The team avoided Chicago's grid as "too straight,
  with too many right angles". Curving the streets keeps players from
  seeing far ahead, which works better for play. [19] *(summary only)*
- **Like GTA and Saints Row:**
  - roads wider than real ones, for driving;
  - buildings packed tighter, for moving over rooftops;
  - only the most distinctive neighbourhoods kept. [19][29]
  *(summary only)*
- **Density over scale.** Creative director Jonathan Morin wanted density
  more than size. He said understanding the limits was what let the team
  build a complex city well. [20][21] *(summary only)*

### Watch Dogs 2: San Francisco, compressed
- Director of level design Falko Poiker says the team listed over 200
  landmarks but could only build a fraction. They compressed distances to
  avoid dead time. [22] *(summary only)*
- Where a place went depended on its value for play as much as on its real
  distance from other places. Google Maps was the base reference. [22]
  *(summary only)*
- Concept work studied 33 districts and 36 architectural styles. [23]
  *(summary only)*

### GTA: real cities, redesigned for driving
- **Vice City:**
  - art director Aaron Garbut's team moved roads and reshaped land whenever
    it helped play;
  - the map was packed far more densely with detail and variety than GTA
    III. [12]
  - Late changes went both ways: the beta's curved bridge became straight,
    and the straight runway became curved. [24] *(summary only)*
- **Los Santos (GTA V):** fan analyses say Rockstar:
  - kept LA's major roads, highways and the rough relative positions of
    landmarks;
  - dropped many minor streets;
  - favoured gently sloping, winding roads over six-lane highways;
  - built Vinewood Hills with almost no cul-de-sacs or dead ends. [25]
  *(summary only)*
- **Garbut on process:** the team works from heavy Google and Street View
  research, then designs the city "like a sculpture", making sure the view
  down each street looks right. The city comes first, and missions are
  fitted to it. [26] *(summary only)*
- **GTA 6:** reports say Rockstar narrowed its roads to a more realistic
  scale (and added more buildings), with denser traffic. [27]
  *(summary only)*

### Open-world city design in general
- Nathan Cheever (Mafia III's New Bordeaux) plans pathways, landmarks,
  districts, infrastructure and faction boundaries before environment art.
  [16] *(summary only)*
- Landmarks are a choice of where to go next, not only an orientation
  aid: the Disneyland "weenie" that pulls the player forward. [28]
  *(summary only)*
- A road-network design paper produces downtown layouts with no dead ends,
  allowing them only on lower-level roads. [30]

### What Bellerive takes from this
1. **Curve the grid.** Watch Dogs' rule is the core of map v2: every
   district grid bends, fans or both, so straight sightlines end within a
   few blocks.
2. **Keep the real city's bones, drop the minor streets.** New Orleans gives
   the seams (Canal and Esplanade become Crescent Boulevard and Liberty
   Avenue). Minor streets are thinned per district.
3. **Few dead ends.** Thinning makes T-junctions, never dead ends, as GTA's
   hills do.
4. **Compress, and place by play value.** The demo window is 1.3 x 1.5 km.
   Landmarks get blocks sized for their layouts rather than real ones.
5. **Density over size.** Small blocks in the Quarter, parcels split by
   district, filler in leftover corners.
6. **Roads, then landmarks, then buildings.** The plan is built in that
   order (`street_plan.gd`, then the landmark grow step, then
   `city_cells.gd`).

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
19. "Designing Chicago to provide a better video game experience", Legally Sociable (2014), quoting a Watch Dogs developer (summary only; the site could not be reached): https://legallysociable.com/2014/05/15/designing-a-big-city-for-more-gaming-enjoyment/
20. IBTimes India, "Watch Dogs creative director compares the in-game map with GTA 5" (summary only): https://www.ibtimes.co.in/watch-dogs-creative-director-compares-the-in-game-map-with-gta-5-509714
21. Softpedia, "Ubisoft: Watch Dogs benefited from design restrictions" (summary only): https://games.softpedia.com/blog/Ubisoft-Watch-Dogs-Benefited-from-Design-Restrictions-354340.shtml
22. GameStar and GamePro, "Watch Dogs 2: so viel San Francisco steckt im Spiel", interview with Falko Poiker (summary only): https://www.gamestar.de/artikel/watch-dogs-2-so-viel-san-francisco-steckt-im-spiel,3303617.html and https://www.gamepro.de/artikel/watch_dogs_2,3303615.html
23. Vice, "Watch Dogs 2 turns San Francisco into a playground" (summary only): https://vice.com/en/article/watch-dogs-2-turns-san-francisco-into-a-playground
24. Sportskeeda, "5 noticeable differences between GTA Vice City's final and beta maps" (summary only): https://sportskeeda.com/gta/5-noticeable-differences-gta-vice-city-s-final-beta-maps
25. GTABoom, "How well does GTA V's map emulate Los Angeles?" (summary only): https://www.gtaboom.com/How_Well_Does_GTA_V's_Map_Emulate_Los_Angeles ; Southern Urbanism (summary only): https://www.southernurbanism.org/p/citybuilding-less-parking-more-living
26. MCV/Develop, "Art director Aaron Garbut tells us how the studio crafted the world of GTA" (summary only): https://mcvuk.com/?p=80936
27. GTABase, "How narrower roads in GTA 6 are going to affect driving", and IBTimes UK on GTA 6 map planning (summary only): https://www.gtabase.com/articles/gta-6/how-narrower-roads-in-gta-6-are-going-to-affect-driving and https://www.ibtimes.co.uk/gta-6-map-planning-began-11-years-ago-narrow-roads-forced-rockstar-add-more-buildings-1827014
28. "Level Design Basics, Part 3", DOU gamedev blog (summary only): https://gamedev.dou.ua/blogs/level-design-basics-part-3/?hl=en
29. Pcgamesn on Bus Simulator 18 and city building for games, as quoted in search results (summary only): https://pcgamesn.com/cities-skylines/bus-simulator-18
30. Peng et al., "Computational Network Design from Functional Specifications" (2016), arXiv:1510.09203 (summary only): https://arxiv.org/pdf/1510.09203
