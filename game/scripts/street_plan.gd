extends RefCounted
## Bellerive's street plan, v5: a California grid (HANDOFF-bellerive-ca.md).
##
## The streets are a planar graph laid out like LA's or SF's:
## - Arterials run straight north-south and east-west across the city
##   (ART_X, ART_Y_NORTH, ART_Y_SOUTH), unevenly spaced as LA's are, so the
##   boulevards line up across districts. The seam roads (Lantern and
##   Rampart north-south, Crescent and Wharf east-west) are among them.
## - Each district splits its superblocks into blocks with local streets
##   (`grid` in PATCHES), also on the compass. Districts that split an
##   interval into the same number of blocks put their streets in the same
##   places, so a local street runs right through its district and on
##   across the boulevards, ending at a major road. The halfway street of
##   each superblock is an avenue (LA's half-mile collectors).
## - The old town round Lantern Square keeps its own grid, turned 30
##   degrees, and meets the city grid along the boulevards round it.
## - Only a few roads leave the grid:
##   - Liberty Avenue, the one long diagonal (an old road, like Broadway);
##   - Magnolia Avenue, from the west into the civic centre;
##   - the River Road and the quays, which follow the water;
##   - Morrow Bridge, to Morrow Point on the far bank.
## - Set pieces sit in the grid: Founders Circle, City Hall's grounds and
##   the Esplanade, Liberty Green, Moreau Square.
## - Some minor streets are dropped (longer blocks) or made pedestrian
##   lanes. Neither ever cuts the network apart.
##
## Blocks are the faces of the graph:
## - inner: the face minus its streets' half widths;
## - lot: the inner polygon minus the sidewalk.
## Positions are local metres: the window corner is the origin, and z is
## map y. Polygons are clockwise on screen (positive shoelace area with y
## pointing down).

const SIDEWALK := 3.0
## Junctions closer than this become one.
const MERGE := 8.0
## Curved roads are sampled this often before simplifying.
const STEP := 26.0
## The River Road and Levee Road run this far out from the water's edge.
const RIVER_ROAD := 10.0
## On the north bank the River Road stands this much further back, leaving a
## strip along the water for the freight line (world build phase 4: double
## track, ~4.5 m apart, with clearance each side).
const FREIGHT_STRIP := 16.0
const QUAY_SET := 6.0 # the quay's centreline back from the water
## Founders Circle's ring (centreline radius), the City Hall grounds (snapped
## to two rows of the Gilt grid; the Esplanade runs east from them between
## the same two streets), and Moreau Square (middle, half side).
const CIRCLE_R := 46.0
## The other traffic circles, where two arterials cross away from the
## landmarks (Washington's Dupont Circle where Liberty Avenue meets
## Crescent and Rampart): [road id, where, ring radius].
const ROUNDABOUTS := [
	["liberty_circle", Vector2(690, 500), 30.0],
	["aurum_circle", Vector2(1010, 140), 26.0],
	["cypress_circle", Vector2(1010, 500), 26.0],
	["harbor_circle", Vector2(690, 1400), 26.0],
]
const CIVIC_GROUNDS := Rect2(27, 203, 98, 117)
const MOREAU_AT := Vector2(1170, 300)
const MOREAU_HALF := 40.0
## Liberty Green's size (its middle is the park_at given to build()).
const PARK_SIZE := Vector2(204, 132)
## The unnamed or minor arterials (the seam roads are laid out by name).
const ARTERIALS := [
	{"x": -80.0, "bank": "north", "cls": "avenue", "road": "palmetto"},
	{"x": 1010.0, "bank": "north", "cls": "avenue", "road": "cypress"},
	{"x": 1460.0, "bank": "north", "cls": "avenue", "road": "hibiscus"},
	{"x": 1770.0, "bank": "north", "cls": "avenue", "road": "tamarind"},
	{"x": 2130.0, "bank": "north", "cls": "avenue", "road": "mangrove"},
	{"y": -220.0, "bank": "north", "cls": "avenue", "road": "presidio"},
	{"y": 140.0, "bank": "north", "cls": "boulevard", "road": "aurum"},
	{"y": 860.0, "bank": "north", "cls": "avenue", "road": "basin", "to": 330.0},
	{"x": -80.0, "bank": "south", "cls": "avenue", "road": "palmetto"},
	{"x": 690.0, "bank": "south", "cls": "avenue", "road": "harbor"},
	{"x": 1010.0, "bank": "south", "cls": "avenue", "road": "cypress"},
	{"y": 1400.0, "bank": "south", "cls": "boulevard", "road": "morrow"},
	{"y": 1610.0, "bank": "south", "cls": "avenue", "road": "gulfview"},
	{"y": 1760.0, "bank": "south", "cls": "avenue", "road": "pelican"},
]
## Lot rectangle (along the front, deep) each landmark needs; blocks too
## small for theirs are joined with a neighbour.
const LANDMARK_LOTS := {
	"union_station": Vector2(40, 32), "aurum_tower": Vector2(28, 27), "bpd_lantern": Vector2(30, 24),
	"floodline_clinic": Vector2(28, 24), "lantern_square": Vector2(34, 30), "wharfside_courts": Vector2(34, 30),
	"blue_lantern": Vector2(28, 22), "warehouse_9": Vector2(32, 26), "the_pit": Vector2(28, 30),
	"streetcar_depot": Vector2(32, 26), "drowned_streetcar": Vector2(24, 20),
	# Government buildings (kits/civic_kit.gd) and the waterfront set pieces.
	"city_hall": Vector2(70, 56), "county_courthouse": Vector2(50, 36), "federal_building": Vector2(47, 32),
	"public_library": Vector2(50, 36), "police_headquarters": Vector2(42, 32), "main_post_office": Vector2(64, 30),
	"fire_headquarters": Vector2(36, 30), "ferry_building": Vector2(90, 24), "liberty_square": Vector2(30, 24),
}
## Which way a landmark's door would rather face (outward from its block),
## when a side that way holds it as well as any other: the buildings along
## the Esplanade face the mall, City Hall faces down it.
const LANDMARK_FACING := {
	"city_hall": Vector2(1, 0), "county_courthouse": Vector2(0, -1), "federal_building": Vector2(0, 1),
	"public_library": Vector2(0, -1), "police_headquarters": Vector2(0, 1), "ferry_building": Vector2(0, -1),
	"liberty_square": Vector2(0, 1), "union_station": Vector2(0, -1),
}
const DEFAULT_LOT := Vector2(22, 22)

## Street classes. Each carries its lanes: `lanes` each way, `lane_w` wide,
## starting `middle` out from the centreline (a median or the centre line),
## and a `park` strip at the curb for parked cars. Streets, avenues and
## boulevards are 4 and 6 lanes (2 and 3 each way); the old town's quarter
## streets and the quay stay 2 lanes, the walking lanes none.
const CLASSES := {
	"boulevard": {"width": 28.0, "drive": true, "rank": 5, "lanes": 3, "lane_w": 3.5, "middle": 3.2, "park": 0.0},
	"bridge": {"width": 16.0, "drive": true, "rank": 5, "lanes": 2, "lane_w": 3.6, "middle": 0.2, "park": 0.0},
	"avenue": {"width": 20.0, "drive": true, "rank": 4, "lanes": 2, "lane_w": 3.6, "middle": 0.2, "park": 2.4},
	"river": {"width": 16.0, "drive": true, "rank": 4, "lanes": 2, "lane_w": 3.5, "middle": 0.2, "park": 0.0},
	"street": {"width": 18.0, "drive": true, "rank": 2, "lanes": 2, "lane_w": 3.3, "middle": 0.2, "park": 2.2},
	"quarter": {"width": 9.0, "drive": true, "rank": 1, "lanes": 1, "lane_w": 3.6, "middle": 0.6, "park": 0.0},
	"lane": {"width": 7.0, "drive": false, "rank": 0, "lanes": 0, "lane_w": 0.0, "middle": 0.0, "park": 0.0},
	"quay": {"width": 10.0, "drive": true, "rank": 3, "lanes": 1, "lane_w": 3.6, "middle": 0.6, "park": 0.0},
}
const ROAD_NAMES := {
	"lantern": "Lantern Boulevard", "crescent": "Crescent Boulevard", "rampart": "Rampart Avenue",
	"liberty": "Liberty Avenue", "magnolia": "Magnolia Avenue", "wharf": "Wharf Street", "river_road": "River Road",
	"levee": "Levee Road", "bridge": "Morrow Bridge", "point_ave": "Point Avenue", "quay": "Ironwharf Quay",
	"founders": "Founders Circle", "civic": "Capitol Drive", "esplanade": "Esplanade", "moreau": "Moreau Square",
	"palmetto": "Palmetto Avenue", "cypress": "Cypress Avenue", "aurum": "Aurum Boulevard", "basin": "Basin Street",
	"harbor": "Harbor Way", "morrow": "Morrow Boulevard", "liberty_circle": "Liberty Circle", "aurum_circle": "Aurum Circle",
	"cypress_circle": "Cypress Circle", "harbor_circle": "Harbor Circle",
	"hibiscus": "Hibiscus Avenue", "tamarind": "Tamarind Avenue", "mangrove": "Mangrove Avenue",
	"presidio": "Presidio Avenue", "gulfview": "Gulfview Avenue", "pelican": "Pelican Avenue",
	"seagrape": "Seagrape Avenue", "ocean": "Ocean Drive", "causeway": "Serena Causeway",
	"mirador": "Mirador Boulevard", "canyon": "Canyon Drive",
	"calle_sol": "Calle Sol", "calle_mar": "Calle Mar", "paseo_luna": "Paseo Luna", "coral_way": "Coral Way",
	"plaza_luna": "Plaza Luna", "plaza_sol": "Plaza del Sol", "dune_ave": "Dune Avenue", "sandpiper": "Sandpiper Drive",
	"palm_circle": "Palm Circle", "bayou_drive": "Bayou Drive", "willow_way": "Willow Way", "heron_circle": "Heron Circle",
	"shoreline": "Shoreline Drive", "cane_row": "Cane Row", "point_circle": "Point Circle",
}

## The citywide arterial grid (California: the boulevards run straight
## north-south and east-west and line up from one district to the next;
## their spacing is uneven, as LA's is, 400 to 875 m apart). Positions in
## local metres, beyond the bounds
## too, as the ends of the outer superblocks. North of the river the lines
## at y 140, 500 and 860 are arterials; south of it, y 1400.
const ART_X := [-390.0, -80.0, 330.0, 690.0, 1010.0, 1460.0, 1770.0, 2130.0]
const ART_Y_NORTH := [-580.0, -220.0, 140.0, 500.0, 860.0, 1220.0, 1580.0]
const ART_Y_SOUTH := [1040.0, 1240.0, 1400.0, 1610.0, 1760.0, 1990.0]
## Brisa Beach runs along the Gulf on the diagonal (local metres; the coast
## is world_map's, from (1450, 2000) north-east to (2250, 1350)). Ocean
## Drive is the city's sea edge, 75 m inland, the hotels on its inland
## side; Seagrape Avenue runs 330 m inland, where the city grid takes over.
const GULF_DIR := Vector2(0.776, -0.630)
const OCEAN_AT := Vector2(1402.8, 1941.8)
const SEAGRAPE_AT := Vector2(1242.0, 1744.0)
## Serena Causeway (world_map's `overseas` highway) heads out over the Gulf
## from (1586, 1400) to (2000, 1870), landing on a Brisa cross street's
## junction with Ocean Drive (the line is set to meet it).
const CAUSEWAY_FROM := Vector2(1586.0, 1400.0)
const CAUSEWAY_DIR := Vector2(0.6614, 0.7501)
## Curved roads through the grid (Sachin, 2026-10-29: "some curved roads
## too ... perfectly connecting straight to other roads, or stretching till
## the city outside area"): [road, class, Catmull-Rom control points]. Each
## starts on a grid road and runs out past the outline, so the trim makes it
## an exit the country carries on. The grid streets they cross are cut at
## them and meet them; those running alongside are trimmed back.
const CURVES := [
	# Mirador Boulevard: the Sunset of Bellerive, from Lantern Boulevard in an
	# S through Cable Hill up to the hills.
	["mirador", "boulevard", [Vector2(330, -280), Vector2(240, -300), Vector2(160, -350), Vector2(110, -420),
			Vector2(60, -500), Vector2(-30, -560), Vector2(-120, -640)]],
	# Canyon Drive: off Hibiscus Avenue, swinging north out of the north-east.
	["canyon", "avenue", [Vector2(1460, 100), Vector2(1540, 60), Vector2(1600, 0), Vector2(1640, -90),
			Vector2(1660, -180), Vector2(1665, -280)]],
]
## A point inside Brisa Beach (between Seagrape and Ocean Drive).
const BRISA_SEED := Vector2(1634, 1593)
## District streets fall up to this share of a block off an even split
## (so the grid isn't ruler-straight in its spacing).
const SPLIT_JITTER := 0.12

## District grids. `seed` is a point inside the patch's region (regions are
## the land cut apart by the seam roads). Lines of constant u run along V,
## lines of constant v along U.
## - `grid` [nu, nv]: a straight north-south/east-west grid that splits
##   each superblock of the arterial grid into nu by nv blocks, so every
##   district's streets stay parallel to the boulevards.
## - Without `grid`, the old warped grid: `su`/`sv` spacing, `angle`, and
##   `bend` curving the v-lines (v grows by bend * u^2).
## `cut` is the chance of dropping a u- or v-street between two junctions,
## `lane` the chance of making it a pedestrian lane. `jog` is the chance
## that a v-street, between two u-streets, steps sideways. `max` caps the
## blocks that dropping streets makes: length along U, along V, and area.
## `cls_u`/`cls_v` give the u- or v-lines their own class (Midtown's
## avenues).
const PATCHES := [
	# Gilt: downtown, blocks for towers round the civic centre. Its north-
	# south streets carry on through the Lantern Quarter West down to the
	# river, its cross streets east through Midtown.
	{"id": "gilt_w", "bank": "north", "seed": Vector2(150, 200), "grid": [4, 6], "angle": 0.0,
		"su": [90.0, 90.0], "sv": [60.0, 60.0], "fam": "uv", "cls": "street", "cut": [0.0, 0.0], "lane": 0.0, "max": [0.0, 0.0, 0.0]},
	# Midtown: a Manhattan grid, long thin blocks between avenues that run
	# north-south; Liberty Avenue cuts across it like Broadway. Its
	# cross streets carry on east through the Wards.
	{"id": "midtown", "bank": "north", "seed": Vector2(500, 150), "grid": [3, 6], "angle": 0.0,
		"su": [120.0, 120.0], "sv": [60.0, 60.0], "fam": "uv", "cls": "street", "cls_u": "avenue", "cut": [0.0, 0.0], "lane": 0.0, "max": [0.0, 0.0, 0.0]},
	# The Lantern Quarter. The west part is on the city grid, small blocks.
	{"id": "quarter_w", "bank": "north", "seed": Vector2(150, 800), "grid": [4, 5], "angle": 0.0,
		"su": [90.0, 90.0], "sv": [72.0, 72.0], "fam": "uv", "cls": "quarter", "cut": [0.0, 0.0], "lane": 0.06, "max": [0.0, 0.0, 0.0]},
	# The old town round Lantern Square keeps its own grid, turned 30
	# degrees (downtown LA's old plaza grid; SF's SoMa). It meets the city
	# grid along the boulevards round it, where its streets end.
	{"id": "quarter_e", "bank": "north", "seed": Vector2(520, 750), "angle": 30.0, "origin": Vector2(510, 880), "bend": 0.0,
		"su": [64.0, 78.0], "sv": [64.0, 78.0], "fam": "uv", "cls": "quarter", "cut": [0.0, 0.0], "lane": 0.06, "max": [0.0, 0.0, 0.0]},
	# The Wards: long east-west blocks (South LA's bungalow grid); the
	# streets run on through Crescent Boulevard.
	{"id": "wards", "bank": "north", "seed": Vector2(1000, 600), "grid": [4, 6], "angle": 0.0,
		"su": [90.0, 90.0], "sv": [60.0, 60.0], "fam": "uv", "cls": "street", "cut": [0.0, 0.0], "lane": 0.0, "max": [0.0, 0.0, 0.0]},
	{"id": "wards_n", "bank": "north", "seed": Vector2(1000, 150), "grid": [4, 6], "angle": 0.0,
		"su": [90.0, 90.0], "sv": [60.0, 60.0], "fam": "uv", "cls": "street", "cut": [0.0, 0.0], "lane": 0.0, "max": [0.0, 0.0, 0.0]},
	# Cable Hill (San Francisco's painted rows) and Jade Gate (its
	# Chinatown), north of Presidio Avenue at the foot of the hills. Their
	# streets carry on south through Gilt and Midtown.
	# Cable Hill is the rich hill: contour streets in rings round the crest
	# (wobbling, squashed north-south) and radials up it (Bel Air and SF's
	# Twin Peaks), instead of the grid. The crest inside the first ring is one
	# block of estates: a smaller ring would graze Mirador and be dropped.
	{"id": "hill_n", "bank": "north", "seed": Vector2(0, -350), "angle": 0.0,
		"contour": {"crest": Vector2(10, -430), "rings": [130.0, 200.0, 270.0], "squash": 0.85,
			"radials": [10.0, 55.0, 100.0, 145.0, 190.0, 235.0, 280.0, 325.0]},
		"su": [70.0, 70.0], "sv": [60.0, 60.0], "fam": "uv", "cls": "street", "cut": [0.0, 0.0], "lane": 0.0, "max": [0.0, 0.0, 0.0]},
	{"id": "china_n", "bank": "north", "seed": Vector2(500, -350), "grid": [3, 6], "angle": 0.0,
		"su": [120.0, 120.0], "sv": [60.0, 60.0], "fam": "uv", "cls": "street", "cut": [0.0, 0.0], "lane": 0.08, "max": [0.0, 0.0, 0.0]},
	# Calle Luna (Miami's Little Havana) and Brisa Beach (Miami Beach): the
	# Florida coast curves. Their streets follow the street field (the
	# coast, the river mouth, Liberty Avenue); the arterials that reach them
	# carry on along it, new ones fill in, and a roundabout sits where two
	# cross. Brisa's streets square up to Ocean Drive as the coast pulls.
	{"id": "havana_e", "bank": "north", "seed": Vector2(1700, 800), "angle": 0.0,
		"field": {"dsep": [270.0, 74.0], "roads": ["calle_sol", "calle_mar", "paseo_luna", "coral_way"], "circles": ["plaza_luna", "plaza_sol"]},
		"su": [74.0, 74.0], "sv": [74.0, 74.0], "fam": "uv", "cls": "street", "cut": [0.0, 0.0], "lane": 0.0, "max": [0.0, 0.0, 0.0]},
	{"id": "brisa_e", "bank": "north", "seed": BRISA_SEED, "angle": -39.0,
		"field": {"dsep": [270.0, 80.0], "roads": ["dune_ave", "sandpiper"], "circles": ["palm_circle"]},
		"su": [80.0, 80.0], "sv": [80.0, 80.0], "fam": "uv", "cls": "street", "cut": [0.0, 0.0], "lane": 0.0, "max": [0.0, 0.0, 0.0]},
	# Ironwharf: big industrial lots, a few streets dropped for yards.
	{"id": "docks", "bank": "north", "seed": Vector2(1000, 960), "grid": [4, 3], "angle": 0.0,
		"su": [90.0, 90.0], "sv": [120.0, 120.0], "fam": "uv", "cls": "street", "cut": [0.12, 0.1], "lane": 0.0, "max": [190.0, 250.0, 40000.0]},
	# Morrow Point: the suburbs over the bridge, on the river edge: its
	# streets follow the river's bend (the street field's water pull).
	{"id": "point_w", "bank": "south", "seed": Vector2(150, 1420), "angle": 0.0,
		"field": {"dsep": [270.0, 74.0], "roads": ["bayou_drive", "willow_way"], "circles": ["heron_circle"]},
		"su": [74.0, 74.0], "sv": [74.0, 74.0], "fam": "uv", "cls": "street", "cut": [0.0, 0.0], "lane": 0.0, "max": [0.0, 0.0, 0.0]},
	{"id": "point_e", "bank": "south", "seed": Vector2(800, 1400), "angle": 0.0,
		"field": {"dsep": [270.0, 74.0], "roads": ["shoreline", "cane_row"], "circles": ["point_circle"]},
		"su": [74.0, 74.0], "sv": [74.0, 74.0], "fam": "uv", "cls": "street", "cut": [0.0, 0.0], "lane": 0.0, "max": [0.0, 0.0, 0.0]},
]

var window := Rect2()
## The city's built-up edge (local metres, from world_map.json "core"):
## the plan is laid out over its bounding box, then the blocks whose middle
## lies outside it are dropped. Empty keeps every block.
var outline := PackedVector2Array()
## Junctions on the edge where a street went on out of the city:
## {node, dir (outward), cls, road}. The country's roads carry on from them.
var exits: Array[Dictionary] = []
## The plan's outer edge along the street centre lines, one loop per piece
## of the street graph.
var edge_loops: Array[PackedVector2Array] = []
## How far past the edge street's centreline the city reaches (its outer
## half, sidewalk and a verge).
const EDGE_PAD := 24.0
## The largest block the edge trim fills in as a notch (m²).
const NOTCH_MAX := 30000.0
## The window plus the margin ring of scenery.
var bounds := Rect2()
var seed_value := 0

var node_pos := PackedVector2Array()
var edge_a := PackedInt32Array()
var edge_b := PackedInt32Array()
var edge_cls: Array[String] = []
## Named road the edge belongs to ("" for district streets).
var edge_road: Array[String] = []
var edge_patch := PackedInt32Array()
## Faces either side: [0] seen going a -> b one way round, [1] the other;
## -1 is outside every block (the river, the edge of the map).
var edge_face: Array[Vector2i] = []
## Blocks: {nodes, edges, poly, kind ("land", "water", "sliver"), center,
## area, bbox, inner, sides (edge per inner side, -1 for none), lot, front}.
var faces: Array[Dictionary] = []
## Liberty Green, the park block (-1 if it couldn't be made).
var park_face := -1
## Designed pieces of the plan ({id, kind, at, face}): the civic centre's
## grounds and mall, Founders Circle, Moreau Square. `face` is the block at
## `at` (-1 when it didn't come out).
var set_pieces: Array[Dictionary] = []
## Founders Circle's middle (local metres).
var circle_at := Vector2.ZERO

## District regions: [polygon, patch index].
var _regions: Array = []
var _river := PackedVector2Array()
var _park_at := Vector2.ZERO
## Liberty Green's outline, roads included (empty when there's no park).
var _park_poly := PackedVector2Array()
## Outlines district streets stay out of: the park and the set pieces.
var _holes: Array[PackedVector2Array] = []
## Set pieces on grid lines (Liberty Green, Moreau Square), just inside
## them: district streets are clipped out of these but not trimmed back
## from them, so the streets round them stay.
var _voids: Array[PackedVector2Array] = []
## The district being laid out, shrunk by half its street gap.
var _inner: Array[PackedVector2Array] = []
var _river_half := 80.0
var _adj: Array = [] # node -> Array of edge ids, sorted by direction
var _dead := PackedByteArray()
var _node_grid := {}
var _face_grid := {}
const GRID := 50.0


## Builds the plan inside `win` plus `margin`. `river_line` is the river
## centreline in local metres, `landmarks` [id, local point] pairs whose
## blocks need room for the landmark, `park_at` where Liberty Green goes.
func build(win: Rect2, margin: float, seed_v: int, river_line: PackedVector2Array, river_half: float, landmarks: Array, park_at: Vector2, edge := PackedVector2Array()) -> void:
	window = win
	outline = edge
	bounds = win.grow(margin) if edge.is_empty() else _bbox(edge).grow(margin)
	seed_value = seed_v
	_park_at = park_at
	_river = river_line
	_river_half = river_half
	var src: Array = []
	var t := Time.get_ticks_usec()
	_layout(src)
	t = _lap("layout", t)
	_arrange(src)
	t = _lap("arrange", t)
	_merge_close()
	_prune()
	_simplify()
	_compact()
	_find_faces()
	t = _lap("graph", t)
	_thin()
	_ease_crowds()
	_simplify()
	_compact()
	_find_faces()
	t = _lap("thin", t)
	var wants: Array = []
	for lm in landmarks:
		wants.append([lm[1], LANDMARK_LOTS.get(lm[0], DEFAULT_LOT)])
	for pass_ in 6:
		if not _grow_blocks(wants):
			break
		_simplify()
		_compact()
		_find_faces()
	if _drop_orphans():
		_simplify()
		_compact()
		_find_faces()
	if not outline.is_empty():
		var pins: Array = [park_at]
		for w in wants:
			pins.append(w[0])
		_trim_to_outline(pins)
	t = _lap("grow", t)
	_make_blocks()
	_index()
	# Landmark blocks keep the rectangle that best holds the landmark, on
	# the street side it fronts.
	for i in wants.size():
		var w: Array = wants[i]
		var f := face_of(w[0])
		if f >= 0 and faces[f].kind == "land" and faces[f].lot.size() >= 3:
			var pick := _landmark_rect(f, w[1], LANDMARK_FACING.get(landmarks[i][0], Vector2.ZERO))
			faces[f].front = pick[0]
			faces[f].rect = pick[1]
	t = _lap("blocks", t)
	if not _park_poly.is_empty():
		park_face = face_of(interior_point(_park_poly))
	for sp in set_pieces:
		var f := face_of(sp.at)
		sp.face = f if f >= 0 and faces[f].kind == "land" and f != park_face else -1
	# The grid streets round the parks and the civic centre take their names.
	for named in [[park_face, "park"], [set_piece_face("moreau_square"), "moreau"], [set_piece_face("city_hall_grounds"), "civic"], [set_piece_face("esplanade"), "esplanade"]]:
		if named[0] >= 0:
			for e in faces[named[0]].edges:
				if edge_road[e] == "":
					edge_road[e] = named[1]


## Build time per step, in ms (for the tests and tuning).
var timings := {}


func _lap(step: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	timings[step] = (now - since) / 1000.0
	return now


# --- Queries -------------------------------------------------------------------

func pos(n: int) -> Vector2:
	return node_pos[n]


func node_count() -> int:
	return node_pos.size()


func edge_count() -> int:
	return edge_a.size()


## Edges at node n, sorted by direction.
func edges_of(n: int) -> Array:
	return _adj[n]


## The node at the other end of edge e from n.
func other(e: int, n: int) -> int:
	return edge_b[e] if edge_a[e] == n else edge_a[e]


func edge_between(a: int, b: int) -> int:
	for e in _adj[a]:
		if other(e, a) == b:
			return e
	return -1


func edge_class(e: int) -> String:
	return edge_cls[e]


func edge_width(e: int) -> float:
	return CLASSES[edge_cls[e]].width


func drivable(e: int) -> bool:
	return CLASSES[edge_cls[e]].drive


## Drivable streets at node n.
func degree(n: int) -> int:
	var k := 0
	for e in _adj[n]:
		if drivable(e):
			k += 1
	return k


## How far along edge e from node n its own markings must stop to clear
## the other streets crossing there (0 where the street just bends).
func clearance(n: int, e: int) -> float:
	var w := edge_width(e) * 0.5
	var d := (pos(other(e, n)) - pos(n)).normalized()
	var best := 0.0
	for e2 in _adj[n]:
		if e2 == e:
			continue
		var d2 := (pos(other(e2, n)) - pos(n)).normalized()
		var c := d.dot(d2)
		if c < -0.94: # straight on
			continue
		var s := maxf(sqrt(maxf(1.0 - c * c, 0.0)), 0.3)
		best = maxf(best, minf(edge_width(e2) * 0.5 / s + w * absf(c) / s, 30.0))
	return best


## Whether local point p is in the city: on a block, on a street round
## it (the edge street's outer half and sidewalk too, EDGE_PAD from its
## centreline) or on the river inside the core outline. Without an outline,
## the plan's bounds.
func in_city(p: Vector2) -> bool:
	if outline.is_empty():
		return bounds.has_point(p)
	if not bounds.has_point(p):
		return false
	if face_of(p) >= 0:
		return true
	for loop in edge_loops:
		for k in loop.size():
			if Geometry2D.get_closest_point_to_segment(p, loop[k], loop[(k + 1) % loop.size()]).distance_squared_to(p) < EDGE_PAD * EDGE_PAD:
				return true
	return is_water_point(p) and Geometry2D.is_point_in_polygon(p, outline)


## True on Brisa Beach's sea front: Ocean Drive and the strip past it to
## the sand (the edge there follows the straight Gulf shore).
func sea_front(p: Vector2) -> bool:
	var t := (p - OCEAN_AT).dot(GULF_DIR)
	var off := (p - OCEAN_AT).dot(Vector2(-GULF_DIR.y, GULF_DIR.x))
	return t > -80.0 and t < 1400.0 and off > -40.0 and off < 120.0


## Distance from local point p to the city's edge (the core outline; the
## river through the city is not an edge). INF without an outline. With
## `inland`, the sea front (sea_front) is not an edge either: the hotels
## on Ocean Drive face the beach at full height.
func edge_distance(p: Vector2, inland := false) -> float:
	var best := INF
	for k in outline.size():
		var a := outline[k]
		var b := outline[(k + 1) % outline.size()]
		if inland and sea_front((a + b) * 0.5):
			continue
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
	return best


## Block containing local point p, or -1 (river, edge of the map).
func face_of(p: Vector2) -> int:
	var key := Vector2i(floori(p.x / GRID), floori(p.y / GRID))
	for f in _face_grid.get(key, []):
		var face: Dictionary = faces[f]
		if face.bbox.has_point(p) and Geometry2D.is_point_in_polygon(p, face.poly):
			return f
	return -1


## Faces whose bounding boxes touch the grid cells within r of p.
func faces_near(p: Vector2, r: float) -> Array:
	var seen := {}
	for gx in range(floori((p.x - r) / GRID), floori((p.x + r) / GRID) + 1):
		for gy in range(floori((p.y - r) / GRID), floori((p.y + r) / GRID) + 1):
			for f in _face_grid.get(Vector2i(gx, gy), []):
				seen[f] = true
	return seen.keys()


## Nodes within r of p (from the grid; caller checks the distance).
func nodes_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	for gx in range(floori((p.x - r) / GRID), floori((p.x + r) / GRID) + 1):
		for gy in range(floori((p.y - r) / GRID), floori((p.y + r) / GRID) + 1):
			out.append_array(_node_grid.get(Vector2i(gx, gy), []))
	return out


func is_land(f: int) -> bool:
	return f >= 0 and faces[f].kind == "land"


func face_poly(f: int) -> PackedVector2Array:
	return faces[f].poly


## The block inside its streets (the sidewalk's outer edge).
func inner(f: int) -> PackedVector2Array:
	return faces[f].inner


## The lot inside the sidewalk, where buildings stand.
func lot(f: int) -> PackedVector2Array:
	return faces[f].lot


## Class of the street along inner side k of block f ("" for none).
func side_class(f: int, k: int) -> String:
	var e: int = faces[f].sides[k]
	return edge_cls[e] if e >= 0 else ""


func front_side(f: int) -> int:
	return faces[f].front


func is_park(f: int) -> bool:
	return f >= 0 and f == park_face


## Kind of the set piece block f is ("grounds", "esplanade", "circle",
## "square"), or "".
func set_piece(f: int) -> String:
	if f < 0:
		return ""
	for sp in set_pieces:
		if sp.face == f:
			return sp.kind
	return ""


## Id of the set piece block f is, or "".
func set_piece_id(f: int) -> String:
	if f < 0:
		return ""
	for sp in set_pieces:
		if sp.face == f:
			return sp.id
	return ""


## Block of set piece `id`, or -1.
func set_piece_face(id: String) -> int:
	for sp in set_pieces:
		if sp.id == id:
			return sp.face
	return -1


func is_water_point(p: Vector2) -> bool:
	return river_distance(p) < _river_half


func river_distance(p: Vector2) -> float:
	var best := INF
	for k in _river.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, _river[k], _river[k + 1]).distance_to(p))
	return best


# --- Layout ----------------------------------------------------------------------

## The major roads and the district grids, as polylines:
## {pts, cls, road, patch, fam}.
func _layout(src: Array) -> void:
	var box := _rect_poly(bounds)
	var band80 := _band(_river_half)
	var band89 := _band(_river_half + RIVER_ROAD)
	var road_line := _extend(_chain(_band(_river_half + RIVER_ROAD + FREIGHT_STRIP), box, true), 3.0)
	var levee := _extend(_chain(band89, box, false), 3.0)
	# The quay: a road along the water the docks streets end on, so none of
	# them stops dead at the wharf.
	var bank := _extend(_chain(_band(_river_half + QUAY_SET), box, true), 3.0)
	var north := _piece(Geometry2D.clip_polygons(box, band80), Vector2(300, 300))
	var south := _piece(Geometry2D.clip_polygons(box, band89), Vector2(300, bounds.end.y - 20.0))
	var top := bounds.position.y - 30.0
	var bottom := bounds.end.y + 30.0
	# The seam roads run straight on the arterial grid: Lantern Boulevard and
	# Rampart Avenue north-south down to the River Road, Crescent Boulevard
	# east-west right across, Wharf Street east-west along the docks.
	var b0 := _cross(PackedVector2Array([Vector2(ART_X[2], top), Vector2(ART_X[2], bottom)]), road_line)
	var p4 := _cross(PackedVector2Array([Vector2(ART_X[3], top), Vector2(ART_X[3], bottom)]), road_line)
	var lantern := PackedVector2Array([Vector2(ART_X[2], top), b0])
	var rampart := PackedVector2Array([Vector2(ART_X[3], top), p4])
	var west := bounds.position.x - 30.0
	var east := bounds.end.x + 30.0
	var crescent := PackedVector2Array([Vector2(west, ART_Y_NORTH[3]), Vector2(east, ART_Y_NORTH[3])])
	var wharf := PackedVector2Array([Vector2(ART_X[3] - 5.0, ART_Y_NORTH[4]), Vector2(ART_X[5], ART_Y_NORTH[4])])
	# Founders Circle sits on Lantern Boulevard where Liberty Avenue sets
	# off; the Esplanade runs west from it to City Hall, on the grounds'
	# axis.
	var grounds := _snap_to_grid(CIVIC_GROUNDS, "gilt_w")
	circle_at = Vector2(ART_X[2], grounds.get_center().y)
	# The few diagonals: Liberty Avenue, the old road out to the east (it
	# meets the grid at Rampart and Crescent), and Magnolia Avenue, out to
	# the hills in the west from the City Hall grounds' corner.
	var lib_at := Vector2(ART_X[3], ART_Y_NORTH[3])
	# Brisa Beach: Ocean Drive along the sea edge, Seagrape Avenue behind,
	# both parallel to the coast (clipped to the land as roads below).
	var ocean := PackedVector2Array([OCEAN_AT - GULF_DIR * 60.0, OCEAN_AT + GULF_DIR * 1400.0])
	var seagrape := PackedVector2Array([SEAGRAPE_AT - GULF_DIR * 60.0, SEAGRAPE_AT + GULF_DIR * 1800.0])
	# Liberty Avenue runs on south-east through Calle Luna to Seagrape.
	var lib_far := lib_at + (lib_at - circle_at).normalized() * 3000.0
	var liberty := PackedVector2Array([circle_at, lib_at, _cross(PackedVector2Array([lib_at, lib_far]), seagrape)])
	var magnolia := PackedVector2Array([Vector2(west, 40.0), grounds.position])
	# River Road: along the bank up to Rampart. Past it the wharves have the
	# water.
	var river_road := PackedVector2Array()
	for p in road_line:
		if p.x < p4.x - 6.0:
			river_road.append(p)
	river_road.append(p4)
	var quay := PackedVector2Array([p4])
	for p in bank:
		if p.x > p4.x + 40.0:
			quay.append(p)
	# Morrow Bridge carries Lantern Boulevard straight over the river; Point
	# Avenue goes on south.
	var b1 := _cross(PackedVector2Array([b0, Vector2(b0.x, bottom)]), levee)
	var point_ave := PackedVector2Array([b1, Vector2(b1.x, bottom)])
	_holes = []
	set_pieces = []
	# Liberty Green: a rectangular park filling a few blocks in the Wards
	# (Central Park and LA's MacArthur Park, scaled down), on grid lines, so
	# the streets round it are the grid's and run on past it.
	_voids = []
	_park_poly = _rect_poly(_snap_to_grid(Rect2(_park_at - PARK_SIZE * 0.5, PARK_SIZE), "wards_n"))
	_voids.append(Geometry2D.offset_polygon(_park_poly, -3.0)[0])
	var cut_out: Array[PackedVector2Array] = _civic_centre(src, grounds)
	for rb in ROUNDABOUTS:
		if bounds.grow(-60.0).has_point(rb[1]):
			cut_out.append(_roundabout(src, rb[0], rb[1], rb[2]))
	_moreau_square()
	# Districts: the land cut apart along the seams. Presidio Avenue splits
	# Cable Hill and Jade Gate off Gilt and Midtown; Hibiscus Avenue ends the
	# Wards and Ironwharf at Calle Luna.
	var road_cut := river_road.duplicate()
	road_cut.insert(0, river_road[0] + (river_road[0] - river_road[1]).normalized() * 60.0)
	road_cut.append(p4 + (p4 - river_road[river_road.size() - 2]).normalized() * 4.0)
	var presidio := PackedVector2Array([Vector2(west, ART_Y_NORTH[1]), Vector2(ART_X[3], ART_Y_NORTH[1])])
	var hib_end := _cross(PackedVector2Array([Vector2(ART_X[5], top), Vector2(ART_X[5], bottom)]), seagrape)
	var hibiscus := PackedVector2Array([Vector2(ART_X[5], ART_Y_NORTH[3]), hib_end + Vector2(0, 5)])
	var north_parts: Array = [north]
	for seam in [lantern, crescent, rampart, road_cut, wharf, presidio, hibiscus, seagrape, ocean]:
		north_parts = _cut(north_parts, seam)
	var beach := _piece(north_parts, OCEAN_AT + GULF_DIR * 500.0 + Vector2(-GULF_DIR.y, GULF_DIR.x) * 40.0)
	var south_parts := _cut([south], PackedVector2Array([b1 - Vector2(0, 5), Vector2(b1.x, bottom)]))
	# The field districts (their streets follow the street field): no
	# straight arterial runs through them; each one that reaches them
	# carries on there along the field (_field_lines), from where it
	# enters, or from a traffic circle it would have run through.
	var zones: Array = [] # [region, patch]
	_field_entries = {}
	_field_circles = []
	for k in PATCHES.size():
		if PATCHES[k].has("field"):
			var zone := _piece(north_parts if PATCHES[k].bank == "north" else south_parts, PATCHES[k].seed)
			if not zone.is_empty():
				zones.append([zone, k])
				_field_entries[k] = []
	var roads: Array = [[lantern, "boulevard", "lantern"], [crescent, "boulevard", "crescent"], [rampart, "avenue", "rampart"],
			[liberty, "avenue", "liberty"], [magnolia, "avenue", "magnolia"], [wharf, "avenue", "wharf"], [river_road, "river", "river_road"],
			[levee, "river", "levee"], [quay, "quay", "quay"], [PackedVector2Array([b0, b1]), "bridge", "bridge"],
			[point_ave, "avenue", "point_ave"]]
	# The curved roads: each is a thin strip in _holes too, so the district
	# streets crossing it are cut there (and meet it) and those running
	# alongside it are trimmed back.
	for c in CURVES:
		var line := _spline(c[2])
		_holes.append(Geometry2D.offset_polyline(line, 1.0)[0])
		for piece in Geometry2D.intersect_polyline_with_polygon(line, north):
			roads.append([piece, c[1], c[0]])
	for piece in Geometry2D.intersect_polyline_with_polygon(seagrape, north):
		roads.append([piece, "avenue", "seagrape"])
	for piece in Geometry2D.intersect_polyline_with_polygon(ocean, north):
		roads.append([piece, "avenue", "ocean"])
	# The other arterials, on the same grid: clipped to the land they cross
	# (and out of Brisa Beach, which has its own grid).
	for a in ARTERIALS:
		var line := PackedVector2Array([Vector2(a.x, top), Vector2(a.x, bottom)]) if a.has("x") else PackedVector2Array([Vector2(a.get("from", west), a.y), Vector2(a.get("to", east), a.y)])
		for piece in Geometry2D.intersect_polyline_with_polygon(line, north if a.bank == "north" else south):
			var parts: Array[PackedVector2Array] = [piece]
			for zone in [[beach, -1]] + zones:
				if zone[0].is_empty() or (zone[1] < 0 and a.bank != "north") or (zone[1] >= 0 and PATCHES[zone[1]].bank != a.bank):
					continue
				var next: Array[PackedVector2Array] = []
				for part in parts:
					next.append_array(Geometry2D.clip_polyline_with_polygon(part, zone[0]))
				parts = next
				if zone[1] >= 0:
					_add_entries(piece, zone, cut_out, a)
			for part in parts:
				roads.append([part, a.cls, a.road])
	for r in roads:
		# Roads through the circle and the City Hall grounds stop at their
		# rings (the stubs left inside are pruned).
		var pieces: Array[PackedVector2Array] = [r[0]]
		for hole in cut_out:
			var next: Array[PackedVector2Array] = []
			for piece in pieces:
				next.append_array(Geometry2D.clip_polyline_with_polygon(piece, hole))
			pieces = next
		for piece in pieces:
			if _length(piece) > 10.0:
				src.append({"pts": _resample(piece, STEP), "cls": r[1], "road": r[2], "patch": -1, "fam": -1})
	# A street round the edge of the scenery closes off the outermost blocks.
	var frame := _rect_poly(bounds.grow(-4.0))
	for k in 4:
		var a := frame[k]
		var b := frame[(k + 1) % 4]
		for land in [north, south]:
			for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), land):
				if _length(piece) > 20.0:
					src.append({"pts": _resample(_extend(piece, 2.0), STEP), "cls": "street", "road": "frame", "patch": -1, "fam": -1})
	_regions = []
	for k in PATCHES.size():
		var p: Dictionary = PATCHES[k]
		var region := _piece(north_parts if p.bank == "north" else south_parts, p.seed)
		if region.is_empty():
			push_warning("street plan: no region for %s" % p.id)
			continue
		_regions.append([region, k])
		_patch_lines(src, k, region)


## The civic centre (DC's Mall and SF's Civic Center, scaled down): City
## Hall on its grounds, the Esplanade (a lawn with a reflecting pool) east to
## Founders Circle, a traffic circle with the Founders Obelisk in the middle.
## The grounds and the mall are cut out of the Gilt grid like the parks, so
## the streets round them are the grid's own and run on past them; the
## district streets that would cross them meet them square. Magnolia
## Avenue, like DC's diagonals, ends at the grounds' corner.
## Returns the outlines the named roads stop at.
func _civic_centre(src: Array, grounds: Rect2) -> Array[PackedVector2Array]:
	var c := circle_at
	var cut_disk := _roundabout(src, "founders", c, CIRCLE_R)
	_voids.append(_rect_poly(grounds.grow(-3.0)))
	set_pieces.append({"id": "city_hall_grounds", "kind": "grounds", "at": grounds.get_center(), "face": -1})
	var mall := Rect2(grounds.end.x, grounds.position.y, c.x - grounds.end.x, grounds.size.y)
	_voids.append(_rect_poly(mall.grow(-3.0)))
	set_pieces.append({"id": "esplanade", "kind": "esplanade", "at": Vector2((mall.position.x + c.x - CIRCLE_R) * 0.5, c.y), "face": -1})
	# The cross streets west of the grounds would stop short at them: those
	# blocks run through to the next street instead.
	_voids.append(_rect_poly(Rect2(bounds.position.x - 60.0, grounds.position.y + 6.0, grounds.position.x - bounds.position.x + 57.0, grounds.size.y - 12.0)))
	return [cut_disk, _rect_poly(grounds.grow(-3.0))]


## A traffic circle: an avenue ring of radius r round a lawn at c (a set
## piece of kind "circle", id "<road>" or "founders_circle"). District
## streets keep clear of it; returns the disk the named roads stop in, a
## few metres inside the ring.
func _roundabout(src: Array, road: String, c: Vector2, r: float) -> PackedVector2Array:
	var ring := PackedVector2Array()
	for k in 21:
		var a := TAU * k / 20.0
		ring.append(c + Vector2(cos(a), sin(a)) * r)
	src.append({"pts": ring, "cls": "avenue", "road": road, "patch": -1, "fam": -1})
	_holes.append(ring.slice(0, 20))
	set_pieces.append({"id": "founders_circle" if road == "founders" else road, "kind": "circle", "at": c, "face": -1})
	var cut_disk := PackedVector2Array()
	for k in 20:
		var a := TAU * k / 20.0
		cut_disk.append(c + Vector2(cos(a), sin(a)) * (r - 3.0))
	return cut_disk


## Moreau Square: a park square in the Wards on one block of the grid
## (SF's Alamo Square; the painted rows face it). The grid's streets run
## round it.
func _moreau_square() -> void:
	var sq := _rect_poly(_snap_to_grid(Rect2(MOREAU_AT - Vector2.ONE * MOREAU_HALF, Vector2.ONE * MOREAU_HALF * 2.0), "wards_n"))
	_voids.append(Geometry2D.offset_polygon(sq, -3.0)[0])
	set_pieces.append({"id": "moreau_square", "kind": "square", "at": MOREAU_AT, "face": -1})


## Rect r with each side moved onto the nearest street line of district
## `patch`'s grid (each side to a different line), so a park's ring road
## is part of the grid's streets and they run on past it instead of
## stopping beside it.
func _snap_to_grid(r: Rect2, patch: String) -> Rect2:
	var p: Dictionary = {}
	for q in PATCHES:
		if q.id == patch:
			p = q
	var xs: Array = ART_X.duplicate()
	for sp in _splits(ART_X, p.grid[0], -INF, INF, "x" + p.bank):
		xs.append(sp[0])
	var ys: Array = (ART_Y_NORTH if p.bank == "north" else ART_Y_SOUTH).duplicate()
	for sp in _splits(ART_Y_NORTH if p.bank == "north" else ART_Y_SOUTH, p.grid[1], -INF, INF, "y" + p.bank):
		ys.append(sp[0])
	var x0 := _nearest(xs, r.position.x, INF)
	var x1 := _nearest(xs, r.end.x, x0)
	var y0 := _nearest(ys, r.position.y, INF)
	var y1 := _nearest(ys, r.end.y, y0)
	return Rect2(minf(x0, x1), minf(y0, y1), absf(x1 - x0), absf(y1 - y0))


## The value in `values` nearest v, other than `not`.
static func _nearest(values: Array, v: float, not_v: float) -> float:
	var best := INF
	for x in values:
		if x != not_v and absf(x - v) < absf(best - v):
			best = x
	return best


## The point of a north-south road at height y.
static func _point_at_y(line: PackedVector2Array, y: float) -> Vector2:
	for k in line.size() - 1:
		if (line[k].y - y) * (line[k + 1].y - y) <= 0.0 and line[k].y != line[k + 1].y:
			return line[k].lerp(line[k + 1], (y - line[k].y) / (line[k + 1].y - line[k].y))
	return line[0]


func _patch_lines(src: Array, k: int, region: PackedVector2Array) -> void:
	var p: Dictionary = PATCHES[k]
	if p.has("field"):
		_field_lines(src, k, region)
		return
	if p.has("contour"):
		_contour_lines(src, k, region)
		return
	if p.has("grid"):
		_grid_lines(src, k, region)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, p.id])
	var th := deg_to_rad(p.angle)
	var u_dir := Vector2(cos(th), sin(th))
	var v_dir := Vector2(-sin(th), cos(th))
	var o: Vector2 = p.origin
	var bend: float = p.bend
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in region:
		var d := q - o
		var u := d.dot(u_dir)
		var v := d.dot(v_dir) - bend * u * u
		lo = Vector2(minf(lo.x, u), minf(lo.y, v))
		hi = Vector2(maxf(hi.x, u), maxf(hi.y, v))
	lo -= Vector2(30, 30)
	hi += Vector2(30, 30)
	# The u-lines fan out from the middle of the patch (like spokes round
	# the crescent) and curve; the outer ones are spared so the fan still
	# covers the region.
	var fan: float = p.get("fan", 0.0)
	var bend_u: float = p.get("bend_u", 0.0)
	var mid := (lo + hi) * 0.5
	var spare := absf(fan) * (hi.x - lo.x) * (hi.y - lo.y) * 0.25 + absf(bend_u) * pow((hi.y - lo.y) * 0.5, 2)
	var gap: float = minf(p.su[0], p.sv[0]) * 0.55
	_inner = Geometry2D.offset_polygon(region, -gap * 0.5)
	var u_lines: Array = [] # [u, tilt] of the u-streets that made it
	if "u" in p.fam:
		for u in _positions(rng, lo.x - spare, hi.x + spare, p.su):
			var tilt: float = rng.randf_range(-0.012, 0.012) + fan * (u - mid.x)
			var pts := PackedVector2Array()
			var v := lo.y
			while true:
				var uu: float = u + tilt * (v - mid.y) + bend_u * pow(v - mid.y, 2)
				pts.append(o + u_dir * uu + v_dir * (v + bend * uu * uu))
				if v >= hi.y:
					break
				v = minf(v + STEP, hi.y)
			if _add_pieces(src, pts, region, gap, k, 0):
				u_lines.append([u, tilt])
	if "v" in p.fam:
		var jog: float = p.get("jog", 0.0)
		u_lines.sort_custom(func(x, y): return x[0] < y[0])
		var u_at := func(l: Array, vv: float) -> float:
			return l[0] + l[1] * (vv - mid.y) + bend_u * pow(vv - mid.y, 2)
		for v in _positions(rng, lo.y, hi.y, p.sv):
			var tilt := rng.randf_range(-0.012, 0.012)
			# A stepped piece spans one gap between two u-streets, both
			# ends inside the district; the run before it stops just past
			# its first u-street and the next starts just short of its
			# second (the stubs are pruned).
			var start := lo.x - spare
			for i in u_lines.size() - 1:
				if jog <= 0.0 or rng.randf() >= jog:
					continue
				var vj: float = v + rng.randf_range(0.28, 0.42) * p.sv[0] * (1.0 if rng.randf() < 0.5 else -1.0)
				var e0: float = u_at.call(u_lines[i], vj)
				var e1: float = u_at.call(u_lines[i + 1], vj)
				var inside := true
				for e in [e0, e1]:
					var q: Vector2 = o + u_dir * e + v_dir * (vj + tilt * e + bend * e * e)
					if not Geometry2D.is_point_in_polygon(q, region) or _in_hole(q):
						inside = false
				if not inside:
					continue
				_add_pieces(src, _v_line(o, u_dir, v_dir, bend, v, tilt, start, u_at.call(u_lines[i], v) + 3.0), region, gap, k, 1)
				_add_pieces(src, _v_line(o, u_dir, v_dir, bend, vj, tilt, e0 - 3.0, e1 + 3.0), region, gap, k, 1)
				start = u_at.call(u_lines[i + 1], v) - 3.0
			_add_pieces(src, _v_line(o, u_dir, v_dir, bend, v, tilt, start, hi.x + spare), region, gap, k, 1)


# --- The street field ------------------------------------------------------------

## The street field (data/street_field.json, from tools/street_field.py):
## the direction the curved districts' streets follow, as an angle 0..pi
## (0..255) per 20 m cell, summed from the downtown grid, the Gulf coast,
## the Morrow and the curved roads. Streets are traced along it (family 0)
## or across it (family 1).
const SF_PATH := "res://data/street_field.json"
static var _sf_angle := PackedByteArray()
static var _sf_origin := Vector2.ZERO
static var _sf_cell := 20.0
static var _sf_size := Vector2i.ZERO
## Tracing step, and the cell of the hash the traced lines are kept in.
const SF_STEP := 8.0
const SF_CELL := 40.0
## How far a traced arterial or street may turn from its first heading.
const ART_TURN := deg_to_rad(80.0)
## How near a traced arterial joins another (further apart, the join would
## be a long straight jump).
const ART_JOIN := 45.0
const STREET_TURN := deg_to_rad(100.0)
## Field district -> [where, inward direction, road, class] of each
## arterial that reaches it (set in _layout).
var _field_entries := {}
## The traffic circles the field arterials made (all districts).
var _field_circles: Array = []
## Per family, cell -> Array of Vector3(x, y, line id); id 0 is a fixed road.
var _sf_grid: Array = []


static func _load_field() -> void:
	if not _sf_angle.is_empty():
		return
	var f := FileAccess.open(SF_PATH, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	_sf_origin = Vector2(d.origin[0], d.origin[1])
	_sf_cell = d.cell
	_sf_size = Vector2i(int(d.size[0]), int(d.size[1]))
	_sf_angle = Marshalls.base64_to_raw(d.angle)


## The field's direction at q: along it (fam 0) or across it (fam 1). The
## sign is arbitrary; tracing keeps its own.
static func _field_dir(q: Vector2, fam: int) -> Vector2:
	var g := (q - _sf_origin) / _sf_cell
	var i := clampi(floori(g.x), 0, _sf_size.x - 2)
	var j := clampi(floori(g.y), 0, _sf_size.y - 2)
	var fx := clampf(g.x - i, 0.0, 1.0)
	var fy := clampf(g.y - j, 0.0, 1.0)
	var t := Vector2.ZERO
	for c in [[0, 0, (1.0 - fx) * (1.0 - fy)], [1, 0, fx * (1.0 - fy)], [0, 1, (1.0 - fx) * fy], [1, 1, fx * fy]]:
		# The cells hold the doubled angle's direction, so opposite signs
		# average instead of cancelling.
		var a: float = _sf_angle[(j + c[1]) * _sf_size.x + i + c[0]] * PI / 128.0
		t += Vector2(cos(a), sin(a)) * float(c[2])
	var th := 0.5 * atan2(t.y, t.x) + (PI * 0.5 if fam == 1 else 0.0)
	return Vector2(cos(th), sin(th))


## Records where each arterial reaching field district zone[1] meets it:
## the ends of its pieces inside, out of the traffic circles' disks.
func _add_entries(piece: PackedVector2Array, zone: Array, cut_out: Array, a: Dictionary) -> void:
	var parts: Array[PackedVector2Array] = []
	parts.assign(Geometry2D.intersect_polyline_with_polygon(piece, zone[0]))
	for disk in cut_out:
		var next: Array[PackedVector2Array] = []
		for part in parts:
			next.append_array(Geometry2D.clip_polyline_with_polygon(part, disk))
		parts = next
	for part in parts:
		if _length(part) < 40.0:
			continue
		var n := part.size()
		_field_entries[zone[1]].append([part[0], (part[1] - part[0]).normalized(), a.road, a.cls])
		_field_entries[zone[1]].append([part[n - 1], (part[n - 2] - part[n - 1]).normalized(), a.road, a.cls])


func _sf_stamp(pts: PackedVector2Array, fam: int, id: int) -> void:
	var line := _resample(pts, SF_STEP) if _length(pts) > SF_STEP else pts
	for q in line:
		var key := Vector2i(floori(q.x / SF_CELL), floori(q.y / SF_CELL))
		if not _sf_grid[fam].has(key):
			_sf_grid[fam][key] = []
		_sf_grid[fam][key].append(Vector3(q.x, q.y, id))


## A fixed road (or edge) as a line both families may meet: each stretch
## under the family it runs along (both when it is diagonal to the field).
func _sf_fix(pts: PackedVector2Array) -> void:
	if _length(pts) < 1.0:
		return
	var line := _resample(pts, SF_STEP)
	for k in line.size() - 1:
		var d := (line[k + 1] - line[k]).normalized()
		for fam in 2:
			if absf(d.dot(_field_dir(line[k], fam))) > 0.38:
				_sf_grid[fam].get_or_add(Vector2i(floori(line[k].x / SF_CELL), floori(line[k].y / SF_CELL)), []).append(Vector3(line[k].x, line[k].y, 0))


## The nearest point of a family-`fam` line within r of q (fixed roads
## left out if `traced_only`); Vector2.INF if none.
func _sf_near(q: Vector2, fam: int, r: float, traced_only := false) -> Vector2:
	var best := Vector2.INF
	var best_d := r * r
	var c := Vector2i(floori(q.x / SF_CELL), floori(q.y / SF_CELL))
	var reach := ceili(r / SF_CELL)
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			for p in _sf_grid[fam].get(c + Vector2i(dx, dy), []):
				if traced_only and p.z < 0.5:
					continue
				var d := Vector2(p.x, p.y).distance_squared_to(q)
				if d < best_d:
					best_d = d
					best = Vector2(p.x, p.y)
	return best


## Inside a set piece the traced streets stop at (a park, a traffic
## circle; not the thin strips of the curved roads, which they cross).
func _in_void(q: Vector2) -> bool:
	for poly in _voids:
		if Geometry2D.is_point_in_polygon(q, poly):
			return true
	for poly in _holes:
		var box := _bbox(poly)
		if box.size.x < 120.0 and box.size.y < 120.0 and box.has_point(q) and Geometry2D.is_point_in_polygon(q, poly):
			return true
	return false


## A street traced along family `fam` of the field from s, both ways (or
## only along `dir` when given), until it leaves `region`, runs into a set
## piece, or comes within `join` of a line of its own family: it joins that
## line when it lies ahead, stops short when it lies alongside and goes on
## when it lies behind. It also stops once it has turned `max_turn` from
## where it set off: near the field's knots (where the river's pull and the
## grid's balance) a line along it would swing round onto the other family.
func _sf_trace(s: Vector2, fam: int, region: PackedVector2Array, join: float, max_turn: float, dir := Vector2.ZERO) -> PackedVector2Array:
	var halves: Array[PackedVector2Array] = []
	for sgn in ([1.0] if dir != Vector2.ZERO else [1.0, -1.0]):
		var pts := PackedVector2Array()
		var q := s
		var d: Vector2 = dir if dir != Vector2.ZERO else _field_dir(s, fam) * sgn
		var d0 := d
		for step in 700:
			var f1 := _field_dir(q, fam)
			if f1.dot(d) < 0.0:
				f1 = -f1
			var f2 := _field_dir(q + f1 * SF_STEP * 0.5, fam)
			if f2.dot(f1) < 0.0:
				f2 = -f2
			var nq := q + f2 * SF_STEP
			d = f2
			pts.append(nq)
			if not Geometry2D.is_point_in_polygon(nq, region) or _in_void(nq) or d.dot(d0) < cos(max_turn):
				break
			if step >= 3:
				var near := _sf_near(nq, fam, join)
				if near != Vector2.INF:
					var ahead := (near - nq).dot(d) / maxf(near.distance_to(nq), 0.01)
					if ahead > 0.5:
						pts.append(near)
						break
					if ahead > -0.2:
						break
			q = nq
		halves.append(pts)
	var out := PackedVector2Array()
	if halves.size() == 2:
		out = halves[1].duplicate()
		out.reverse()
	out.append(s)
	out.append_array(halves[0])
	return out


## Seeds every sep/2 over the region, nearest downtown first.
static func _sf_seeds(region: PackedVector2Array, sep: float) -> Array:
	var box := _bbox(region)
	var out: Array = []
	var y := box.position.y + sep * 0.25
	while y < box.end.y:
		var x := box.position.x + sep * 0.25
		while x < box.end.x:
			var q := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(q, region):
				out.append(q)
			x += sep * 0.5
		y += sep * 0.5
	out.sort_custom(func(a, b): return a.distance_squared_to(Vector2(450, 300)) < b.distance_squared_to(Vector2(450, 300)))
	return out


## A field district (variation 2 of the mix, reference/world/
## mix_options_sketch.png): its streets are traced along the street field
## and across it, `dsep` [arterials, streets] apart. The arterials that
## reach it carry on along the field from where they enter (same name and
## class), new ones (named from `roads`) fill the gaps, and a traffic
## circle (named from `circles`) sits where two cross.
func _field_lines(src: Array, k: int, region: PackedVector2Array) -> void:
	_load_field()
	var p: Dictionary = PATCHES[k]
	var spec: Dictionary = p.field
	var art_sep: float = spec.dsep[0]
	var sep: float = spec.dsep[1]
	var gap := sep * 0.45
	_inner = Geometry2D.offset_polygon(region, -gap * 0.5)
	_sf_grid = [{}, {}]
	# Fixed: the district's edge, the set pieces by it and the named roads
	# inside it (Liberty Avenue through Calle Luna).
	var ring := region.duplicate()
	ring.append(region[0])
	_sf_fix(ring)
	var near_box := _bbox(region).grow(60.0)
	for poly in _holes + _voids:
		if near_box.intersects(_bbox(poly)):
			var closed := poly.duplicate()
			closed.append(poly[0])
			_sf_fix(closed)
	for e in src:
		if e.patch == -1 and near_box.intersects(_bbox(e.pts)):
			for piece in Geometry2D.intersect_polyline_with_polygon(e.pts, region):
				_sf_fix(piece)
	# Arterials: those entering carry on first, then new ones.
	var arts: Array = [] # [line, fam, road, cls]
	var names: Array = spec.get("roads", []).duplicate()
	for en in _field_entries.get(k, []):
		var at: Vector2 = en[0]
		var dir: Vector2 = en[1]
		var fam := 0 if absf(dir.dot(_field_dir(at, 0))) >= absf(dir.dot(_field_dir(at, 1))) else 1
		# Skip it when an arterial traced already runs where it would go
		# (the line in from the other end of the same road).
		if _sf_near(at + dir * art_sep * 0.3, fam, art_sep * 0.3, true) != Vector2.INF:
			continue
		var line := _sf_trace(at + dir * 2.0, fam, region, ART_JOIN, ART_TURN, dir)
		line[0] = at
		if _length(line) < art_sep * 0.3:
			continue
		arts.append([line, fam, en[2], en[3]])
		_sf_stamp(line, fam, arts.size())
	for fam in 2:
		for s in _sf_seeds(region, art_sep):
			if names.is_empty():
				break
			if _sf_near(s, fam, art_sep * 0.9) != Vector2.INF:
				continue
			var line := _sf_trace(s, fam, region, ART_JOIN, ART_TURN)
			if _length(line) < art_sep:
				continue
			arts.append([line, fam, names.pop_front(), "avenue"])
			_sf_stamp(line, fam, arts.size())
	# Traffic circles where two of them cross, well inside the district
	# and clear of the other circles.
	var cut: Array[PackedVector2Array] = []
	var circles: Array = spec.get("circles", []).duplicate()
	var deep := Geometry2D.offset_polygon(region, -70.0)
	var taken: Array = [circle_at]
	for rb in ROUNDABOUTS:
		taken.append(rb[1])
	taken.append_array(_field_circles)
	for i in arts.size():
		for j in range(i + 1, arts.size()):
			if arts[i][1] == arts[j][1] or circles.is_empty():
				continue
			var a: PackedVector2Array = arts[i][0]
			var b: PackedVector2Array = arts[j][0]
			for m in a.size() - 1:
				for n in b.size() - 1:
					var hit = Geometry2D.segment_intersects_segment(a[m], a[m + 1], b[n], b[n + 1])
					if hit == null or circles.is_empty():
						continue
					var inside := false
					for poly in deep:
						inside = inside or Geometry2D.is_point_in_polygon(hit, poly)
					var clear := true
					for t in taken:
						clear = clear and hit.distance_to(t) >= 220.0
					if inside and clear:
						cut.append(_roundabout(src, circles.pop_front(), hit, 26.0))
						taken.append(hit)
						_field_circles.append(hit)
	for art in arts:
		var pieces: Array[PackedVector2Array] = []
		pieces.assign(Geometry2D.intersect_polyline_with_polygon(art[0], region))
		for hole in cut + _voids:
			var next: Array[PackedVector2Array] = []
			for piece in pieces:
				next.append_array(Geometry2D.clip_polyline_with_polygon(piece, hole))
			pieces = next
		for piece in pieces:
			if _length(piece) > 20.0:
				src.append({"pts": _resample(_extend(piece, 1.5), STEP), "cls": art[3], "road": art[2], "patch": -1, "fam": -1})
	# Streets, along the field, then across it.
	for fam in 2:
		for s in _sf_seeds(region, sep):
			if _sf_near(s, fam, sep * 0.9) != Vector2.INF:
				continue
			var line := _sf_trace(s, fam, region, sep * 0.5, STREET_TURN)
			if line.size() < 4 or _length(line) < sep * 0.5:
				continue
			_sf_stamp(line, fam, 1000 + src.size())
			_add_pieces(src, _resample(line, STEP), region, gap, k, fam)


## Cable Hill (B of the mix): contour streets in rings round the crest,
## wobbling and squashed north-south, and radials up it (Bel Air, Twin
## Peaks). The curved roads crossing it cut the rings, which meet them.
## (No cul-de-sacs: the plan prunes dead ends.)
func _contour_lines(src: Array, k: int, region: PackedVector2Array) -> void:
	var p: Dictionary = PATCHES[k]
	var spec: Dictionary = p.contour
	var crest: Vector2 = spec.crest
	var squash: float = spec.squash
	var gap: float = p.su[0] * 0.45
	_inner = Geometry2D.offset_polygon(region, -gap * 0.5)
	for r0 in spec.rings:
		var rr: float = r0
		var ring := PackedVector2Array()
		for i in 91:
			var th := TAU * i / 90.0
			var r := rr * (1.0 + 0.10 * sin(3.0 * th + rr / 40.0) + 0.05 * sin(5.0 * th))
			ring.append(crest + Vector2(r * cos(th), squash * r * sin(th)))
		_add_pieces(src, ring, region, gap, k, 0)
	var r_in: float = spec.rings[0]
	for deg in spec.radials:
		var d := Vector2(cos(deg_to_rad(deg)), squash * sin(deg_to_rad(deg)))
		_add_pieces(src, _resample(PackedVector2Array([crest + d * r_in, crest + d * 420.0]), STEP), region, gap, k, 1)


## A straight grid: each superblock of the arterial grid split into
## p.grid[0] by p.grid[1] blocks. The arterials themselves are laid out
## citywide in _layout. Every street runs right across the district, and a
## split shared with the district over the seam (the same fraction of the
## same superblock) lands on the same line, so the street carries on
## through it. The splits are a few metres off even (the same few metres
## in both districts), and the one halfway between two arterials is an
## avenue, like LA's half-mile roads.
func _grid_lines(src: Array, k: int, region: PackedVector2Array) -> void:
	var p: Dictionary = PATCHES[k]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in region:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	lo -= Vector2(30, 30)
	hi += Vector2(30, 30)
	var gap: float = minf(p.su[0], p.sv[0]) * 0.55
	_inner = Geometry2D.offset_polygon(region, -gap * 0.5)
	var art_y: Array = ART_Y_NORTH if p.bank == "north" else ART_Y_SOUTH
	for s in _splits(ART_X, p.grid[0], lo.x, hi.x, "x" + p.bank):
		_add_pieces(src, PackedVector2Array([Vector2(s[0], lo.y), Vector2(s[0], hi.y)]), region, gap, k, 0, "avenue" if s[1] else "")
	for s in _splits(art_y, p.grid[1], lo.y, hi.y, "y" + p.bank):
		_add_pieces(src, PackedVector2Array([Vector2(lo.x, s[0]), Vector2(hi.x, s[0])]), region, gap, k, 1, "avenue" if s[1] else "")


## The points that split each interval of `arts` into n parts, between lo
## and hi (the arterials themselves left out): [at, halfway]. Each but the
## halfway one is nudged up to SPLIT_JITTER of a block off even, by a hash
## of where it falls, so two districts splitting the same interval into the
## same number of blocks agree.
func _splits(arts: Array, n: int, lo: float, hi: float, axis: String) -> Array:
	var out: Array = []
	for i in arts.size() - 1:
		for j in range(1, n):
			var f := float(j) / n
			var halfway := absf(f - 0.5) < 0.001
			# Keyed by the interval's place before the north grew a row
			# (-580), so the old streets keep their jitter.
			var key := hash([seed_value, axis, i - (1 if arts == ART_Y_NORTH else 0), n, j])
			var block: float = (arts[i + 1] - arts[i]) / n
			var nudge := 0.0 if halfway else (float(absi(key) % 1000) / 999.0 * 2.0 - 1.0) * SPLIT_JITTER * block
			var at: float = lerpf(arts[i], arts[i + 1], f) + nudge
			if at > lo and at < hi:
				out.append([at, halfway])
	return out


## Adds the parts of street line `pts` inside `region` (and outside the
## park) to src; false if none was kept.
func _add_pieces(src: Array, pts: PackedVector2Array, region: PackedVector2Array, gap: float, k: int, fam: int, cls_override := "") -> bool:
	if pts.size() < 2:
		return false
	var pieces := Geometry2D.intersect_polyline_with_polygon(pts, region)
	for hole in _holes + _voids:
		var outside: Array[PackedVector2Array] = []
		for piece in pieces:
			outside.append_array(Geometry2D.clip_polyline_with_polygon(piece, hole))
		pieces = outside
	var trimmed: Array[PackedVector2Array] = []
	for piece in pieces:
		trimmed.append_array(_trim_holes(piece, gap))
	pieces = trimmed
	var kept := false
	for piece in pieces:
		if piece.size() < 2 or _length(piece) < 12.0:
			continue
		# A street running alongside the district's edge, too close to
		# it, would leave a sliver of a block: leave it out.
		var hugs := _hugs(piece, region, gap)
		for hole in _holes:
			hugs = hugs or _hugs(piece, hole, gap)
		if hugs:
			continue
		# So would a stretch that grazes the edge, or an end that runs into
		# it at a shallow angle: cut those out (the stubs left are pruned).
		for part in _trim_close(piece, gap * 0.5):
			if _length(part) < 12.0:
				continue
			# Reach over the seam so the crossing is found.
			var n := part.size()
			part[0] += (part[0] - part[1]).normalized() * 1.5
			part[n - 1] += (part[n - 1] - part[n - 2]).normalized() * 1.5
			var cls: String = cls_override if cls_override != "" else PATCHES[k].get("cls_v" if fam == 1 else "cls_u", PATCHES[k].cls)
			src.append({"pts": part, "cls": cls, "road": "", "patch": k, "fam": fam})
			kept = true
	return kept


## A v-street (v = v0 + tilt * u, bent with the patch) from u0 to u1.
static func _v_line(o: Vector2, u_dir: Vector2, v_dir: Vector2, bend: float, v0: float, tilt: float, u0: float, u1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var u := u0
	while true:
		pts.append(o + u_dir * u + v_dir * (v0 + tilt * u + bend * u * u))
		if u >= u1:
			break
		u = minf(u + STEP, u1)
	return pts


## The parts of `line` worth keeping: its stretches within `near` of the
## edge of the district (outside `_inner`) are cut out, except at an end
## it reaches in less than 2.5 * near of line (it meets the edge at more
## than about 24 degrees).
func _trim_close(line: PackedVector2Array, near: float) -> Array[PackedVector2Array]:
	var total := _length(line)
	var spans: Array = [] # [from, to] along the line, inside _inner
	for poly in _inner:
		for part in Geometry2D.intersect_polyline_with_polygon(line, poly):
			spans.append([_arc_at(line, part[0]), _arc_at(line, part[part.size() - 1])])
	if spans.size() == 1 and spans[0][0] < 0.5 and spans[0][1] > total - 0.5:
		return [line]
	spans.sort_custom(func(x, y): return x[0] < y[0])
	var out: Array[PackedVector2Array] = []
	for i in spans.size():
		var from: float = spans[i][0]
		var to: float = spans[i][1]
		if i == 0 and from <= near * 2.5:
			from = 0.0
		if i == spans.size() - 1 and total - to <= near * 2.5:
			to = total
		if to - from > 1.0:
			out.append(_between(line, from, to))
	return out


## `line` without the stretches that run alongside a set piece within `gap`
## of it (they would leave a sliver of a block between the street and the
## piece's ring road). An end that meets the piece head-on stays.
func _trim_holes(line: PackedVector2Array, gap: float) -> Array[PackedVector2Array]:
	var total := _length(line)
	var cuts: Array = []
	for hole in _holes:
		var grown := Geometry2D.offset_polygon(hole, gap)
		if grown.is_empty():
			continue
		for part in Geometry2D.intersect_polyline_with_polygon(line, grown[0]):
			var from := _arc_at(line, part[0])
			var to := _arc_at(line, part[part.size() - 1])
			if from > to:
				var swap := from
				from = to
				to = swap
			var at_end := from < 0.5 or to > total - 0.5
			# Head-on ends and corners passed by are short stretches.
			if to - from <= gap * (1.6 if at_end else 2.2):
				continue
			cuts.append([from, to])
	if cuts.is_empty():
		return [line]
	cuts.sort_custom(func(x, y): return x[0] < y[0])
	var out: Array[PackedVector2Array] = []
	var at := 0.0
	for c in cuts:
		if c[0] - at > 1.0:
			out.append(_between(line, at, c[0]))
		at = maxf(at, c[1])
	if total - at > 1.0:
		out.append(_between(line, at, total))
	return out


## Distance along `line` to its point nearest q.
static func _arc_at(line: PackedVector2Array, q: Vector2) -> float:
	var best := INF
	var at := 0.0
	var t := 0.0
	for k in line.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(q, line[k], line[k + 1])
		var d := c.distance_squared_to(q)
		if d < best:
			best = d
			at = t + line[k].distance_to(c)
		t += line[k].distance_to(line[k + 1])
	return at


## The part of `line` from distance `from` to `to` along it.
static func _between(line: PackedVector2Array, from: float, to: float) -> PackedVector2Array:
	var out := PackedVector2Array([_point_at(line, from)])
	var t := 0.0
	for k in line.size() - 1:
		t += line[k].distance_to(line[k + 1])
		if t > from and t < to:
			out.append(line[k + 1])
	out.append(_point_at(line, to))
	return out


## True when the middle and both quarter points of a line lie within
## `gap` of the polygon's edge.
static func _hugs(line: PackedVector2Array, poly: PackedVector2Array, gap: float) -> bool:
	var total := _length(line)
	for f in [0.25, 0.5, 0.75]:
		var q := _point_at(line, total * f)
		var near := false
		for k in poly.size():
			if Geometry2D.get_closest_point_to_segment(q, poly[k], poly[(k + 1) % poly.size()]).distance_to(q) < gap:
				near = true
				break
		if not near:
			return false
	return true


static func _point_at(line: PackedVector2Array, at: float) -> Vector2:
	var t := 0.0
	for k in line.size() - 1:
		var l := line[k].distance_to(line[k + 1])
		if t + l >= at:
			return line[k].lerp(line[k + 1], (at - t) / maxf(l, 0.001))
		t += l
	return line[line.size() - 1]


static func _positions(rng: RandomNumberGenerator, lo: float, hi: float, spacing: Array) -> Array:
	var out: Array = [0.0]
	var t := 0.0
	while t < hi:
		t += rng.randf_range(spacing[0], spacing[1])
		out.append(t)
	t = 0.0
	while t > lo:
		t -= rng.randf_range(spacing[0], spacing[1])
		out.append(t)
	return out


## The river widened to `half` either side of its centreline.
func _band(half: float) -> PackedVector2Array:
	var polys := Geometry2D.offset_polyline(_river, half, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
	return _largest(polys)


## The north or south edge of a river band inside `box`, west to east.
func _chain(band: PackedVector2Array, box: PackedVector2Array, north: bool) -> PackedVector2Array:
	var n := band.size()
	var inside := PackedByteArray()
	inside.resize(n)
	var r := bounds.grow(-1.0)
	for k in n:
		inside[k] = 1 if r.has_point(band[k]) else 0
	var start := 0
	for k in n:
		if inside[k] == 0:
			start = k
			break
	# Each run of vertices inside runs on to where the band crosses the
	# box (the band's vertices can be 100 m or more apart).
	var rect := _rect_poly(r)
	var chains: Array = []
	var cur := PackedVector2Array()
	for i in n + 1:
		var k := (start + i) % n
		var prev := band[(k + n - 1) % n]
		if inside[k] == 1:
			if cur.is_empty() and i > 0:
				for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([prev, band[k]]), rect):
					cur.append(piece[0])
			cur.append(band[k])
		elif cur.size() > 0:
			for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([prev, band[k]]), rect):
				cur.append(piece[piece.size() - 1])
			chains.append(cur)
			cur = PackedVector2Array()
	if cur.size() > 0:
		chains.append(cur)
	var best := PackedVector2Array()
	var best_y := INF if north else -INF
	for c in chains:
		if _length(c) < 300.0:
			continue
		var y := 0.0
		for p in c:
			y += p.y
		y /= c.size()
		if (north and y < best_y) or (not north and y > best_y):
			best_y = y
			best = c
	if best.size() > 1 and best[0].x > best[best.size() - 1].x:
		best.reverse()
	return best


## Catmull-Rom curve through the points, sampled every few metres.
static func _spline(ctrl: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
		var steps := maxi(2, int(p1.distance_to(p2) / 5.0))
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[n - 1])
	return out


## Even spacing of about `step` along a polyline (ends kept).
static func _resample(line: PackedVector2Array, step: float) -> PackedVector2Array:
	var total := _length(line)
	var count := maxi(1, roundi(total / step))
	var out := PackedVector2Array([line[0]])
	var seg := 0
	var seg_start := 0.0
	for i in range(1, count):
		var want := total * i / count
		while seg < line.size() - 2 and seg_start + line[seg].distance_to(line[seg + 1]) < want:
			seg_start += line[seg].distance_to(line[seg + 1])
			seg += 1
		var l := line[seg].distance_to(line[seg + 1])
		out.append(line[seg].lerp(line[seg + 1], clampf((want - seg_start) / maxf(l, 0.001), 0.0, 1.0)))
	out.append(line[line.size() - 1])
	return out


## The line with both ends pushed out by `by` metres.
static func _extend(line: PackedVector2Array, by: float) -> PackedVector2Array:
	var out := line.duplicate()
	var n := out.size()
	if n >= 2:
		out[0] += (out[0] - out[1]).normalized() * by
		out[n - 1] += (out[n - 1] - out[n - 2]).normalized() * by
	return out


static func _length(line: PackedVector2Array) -> float:
	var s := 0.0
	for k in line.size() - 1:
		s += line[k].distance_to(line[k + 1])
	return s


## First crossing of two polylines (or the nearest approach).
static func _cross(a: PackedVector2Array, b: PackedVector2Array) -> Vector2:
	for i in a.size() - 1:
		for j in b.size() - 1:
			var hit = Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[j], b[j + 1])
			if hit != null:
				return hit
	push_warning("street plan: roads don't cross")
	return a[a.size() - 1]


## Direction of a polyline near point p.
static func _tangent(line: PackedVector2Array, p: Vector2) -> Vector2:
	var best := 0
	var best_d := INF
	for k in line.size() - 1:
		var d := Geometry2D.get_closest_point_to_segment(p, line[k], line[k + 1]).distance_to(p)
		if d < best_d:
			best_d = d
			best = k
	return (line[best + 1] - line[best]).normalized()


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _piece(polys: Array, p: Vector2) -> PackedVector2Array:
	for poly in polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return poly
	return PackedVector2Array()


## Splits every polygon along a line.
static func _cut(polys: Array, line: PackedVector2Array) -> Array:
	var strips := Geometry2D.offset_polyline(line, 0.4, Geometry2D.JOIN_MITER, Geometry2D.END_BUTT)
	var out := polys
	for strip in strips:
		var next: Array = []
		for poly in out:
			next.append_array(Geometry2D.clip_polygons(poly, strip))
		out = next
	return out


# --- Graph -----------------------------------------------------------------------

## Splits every polyline where it crosses another and joins them into one
## graph.
func _arrange(src: Array) -> void:
	var sa := PackedVector2Array()
	var sb := PackedVector2Array()
	var sk := PackedInt32Array()
	for i in src.size():
		var pts: PackedVector2Array = src[i].pts
		for j in pts.size() - 1:
			if pts[j].distance_squared_to(pts[j + 1]) > 0.01:
				sa.append(pts[j])
				sb.append(pts[j + 1])
				sk.append(i)
	var n := sa.size()
	var cuts: Array = []
	cuts.resize(n)
	for s in n:
		cuts[s] = [0.0, 1.0]
	var grid := {}
	for s in n:
		var lo := Vector2(minf(sa[s].x, sb[s].x), minf(sa[s].y, sb[s].y))
		var hi := Vector2(maxf(sa[s].x, sb[s].x), maxf(sa[s].y, sb[s].y))
		for gx in range(floori(lo.x / 64.0), floori(hi.x / 64.0) + 1):
			for gy in range(floori(lo.y / 64.0), floori(hi.y / 64.0) + 1):
				var key := Vector2i(gx, gy)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(s)
	var done := {}
	for key in grid:
		var list: Array = grid[key]
		for x in list.size():
			var s: int = list[x]
			for y in range(x + 1, list.size()):
				var t: int = list[y]
				if sk[s] == sk[t]:
					continue
				var pair := mini(s, t) * n + maxi(s, t)
				if done.has(pair):
					continue
				done[pair] = true
				var hit = Geometry2D.segment_intersects_segment(sa[s], sb[s], sa[t], sb[t])
				if hit != null:
					cuts[s].append(_param(sa[s], sb[s], hit))
					cuts[t].append(_param(sa[t], sb[t], hit))
	node_pos = PackedVector2Array()
	edge_a = PackedInt32Array()
	edge_b = PackedInt32Array()
	edge_cls = []
	edge_road = []
	edge_patch = PackedInt32Array()
	var fam := PackedInt32Array()
	var snap := {}
	var lookup := {}
	for s in n:
		var ts: Array = cuts[s]
		ts.sort()
		var prev := -1
		var info: Dictionary = src[sk[s]]
		for t in ts:
			var id := _node_at(sa[s].lerp(sb[s], t), snap)
			if prev >= 0 and id != prev:
				var key := Vector2i(mini(prev, id), maxi(prev, id))
				if lookup.has(key):
					var e: int = lookup[key]
					if CLASSES[info.cls].rank > CLASSES[edge_cls[e]].rank:
						edge_cls[e] = info.cls
						edge_road[e] = info.road
						edge_patch[e] = info.patch
				else:
					lookup[key] = edge_a.size()
					edge_a.append(prev)
					edge_b.append(id)
					edge_cls.append(info.cls)
					edge_road.append(info.road)
					edge_patch.append(info.patch)
					fam.append(info.fam)
			prev = id
	_fam = fam
	_rebuild_adj()


var _fam := PackedInt32Array()


static func _param(a: Vector2, b: Vector2, p: Vector2) -> float:
	var d := b - a
	return clampf((p - a).dot(d) / d.length_squared(), 0.0, 1.0)


func _node_at(p: Vector2, snap: Dictionary) -> int:
	var key := Vector2i(floori(p.x / 2.0), floori(p.y / 2.0))
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for id in snap.get(key + Vector2i(dx, dy), []):
				if node_pos[id].distance_squared_to(p) < 0.5:
					return id
	var id := node_pos.size()
	node_pos.append(p)
	if not snap.has(key):
		snap[key] = []
	snap[key].append(id)
	return id


func _rebuild_adj() -> void:
	_adj = []
	_adj.resize(node_pos.size())
	for k in node_pos.size():
		_adj[k] = []
	_dead = PackedByteArray()
	_dead.resize(edge_a.size())
	for e in edge_a.size():
		_adj[edge_a[e]].append(e)
		_adj[edge_b[e]].append(e)


## Rank of the biggest road class meeting at junction n.
func _node_rank(n: int) -> int:
	var r := 0
	for e in _adj[n]:
		r = maxi(r, CLASSES[edge_cls[e]].rank)
	return r


## Junctions closer than MERGE become one, at the position of the one on
## the biggest road (the busiest of those).
func _merge_close() -> void:
	var n := node_pos.size()
	var parent := PackedInt32Array()
	parent.resize(n)
	for k in n:
		parent[k] = k
	var grid := {}
	for k in n:
		var key := Vector2i(floori(node_pos[k].x / MERGE), floori(node_pos[k].y / MERGE))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(k)
	for k in n:
		var key := Vector2i(floori(node_pos[k].x / MERGE), floori(node_pos[k].y / MERGE))
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for m in grid.get(key + Vector2i(dx, dy), []):
					if m > k and node_pos[k].distance_to(node_pos[m]) < MERGE:
						var rk := _find(parent, k)
						var rm := _find(parent, m)
						if rk != rm:
							# The junction on the bigger road keeps its place
							# (so boulevards stay ruler-straight), then the
							# busier one.
							var wk := Vector2i(_node_rank(rk), _adj[rk].size())
							var wm := Vector2i(_node_rank(rm), _adj[rm].size())
							if wm > wk:
								parent[rk] = rm
							else:
								parent[rm] = rk
	var lookup := {}
	var keep := PackedByteArray()
	keep.resize(edge_a.size())
	for e in edge_a.size():
		var a := _find(parent, edge_a[e])
		var b := _find(parent, edge_b[e])
		edge_a[e] = a
		edge_b[e] = b
		if a == b:
			continue
		var key := Vector2i(mini(a, b), maxi(a, b))
		if lookup.has(key):
			var o: int = lookup[key]
			if CLASSES[edge_cls[e]].rank > CLASSES[edge_cls[o]].rank:
				keep[o] = 0
				keep[e] = 1
				lookup[key] = e
			continue
		lookup[key] = e
		keep[e] = 1
	_rebuild_adj()
	for e in edge_a.size():
		if keep[e] == 0:
			_kill(e)


static func _find(parent: PackedInt32Array, k: int) -> int:
	while parent[k] != k:
		parent[k] = parent[parent[k]]
		k = parent[k]
	return k


func _kill(e: int) -> void:
	if _dead[e] == 1:
		return
	_dead[e] = 1
	_adj[edge_a[e]].erase(e)
	_adj[edge_b[e]].erase(e)


## Drops dead ends until none are left.
func _prune() -> void:
	var todo: Array = []
	for k in node_pos.size():
		if _adj[k].size() == 1:
			todo.append(k)
	while not todo.is_empty():
		var k: int = todo.pop_back()
		if _adj[k].size() != 1:
			continue
		var e: int = _adj[k][0]
		var m := other(e, k)
		_kill(e)
		if _adj[m].size() == 1:
			todo.append(m)


## Joins the two edges at a node where a street just carries on, when the
## node is within half a metre of the joined edge.
func _simplify() -> void:
	var changed := true
	while changed:
		changed = false
		for v in node_pos.size():
			if _adj[v].size() != 2:
				continue
			var e1: int = _adj[v][0]
			var e2: int = _adj[v][1]
			if edge_cls[e1] != edge_cls[e2] or edge_road[e1] != edge_road[e2] or edge_patch[e1] != edge_patch[e2]:
				continue
			var u := other(e1, v)
			var w := other(e2, v)
			if u == w or edge_between(u, w) >= 0:
				continue
			# (A bridge is one straight span even when a merge nudged an end.)
			if edge_cls[e1] != "bridge" and Geometry2D.get_closest_point_to_segment(node_pos[v], node_pos[u], node_pos[w]).distance_to(node_pos[v]) > 0.5:
				continue
			# e1 now runs u -> w; e2 goes.
			_adj[v].clear()
			_adj[w].erase(e2)
			_dead[e2] = 1
			edge_a[e1] = u
			edge_b[e1] = w
			_adj[w].append(e1)
			changed = true
	_drop_overlaps()


## Drops a district street that runs on top of another street. A patch line
## nearly in line with the frame or a seam, straightened, leaves two ways
## between the same junctions along the same line, which breaks the block
## walk (the blocks either side go missing).
func _drop_overlaps() -> void:
	for e in edge_a.size():
		if _dead[e] == 1 or edge_road[e] != "":
			continue
		var a := node_pos[edge_a[e]]
		var b := node_pos[edge_b[e]]
		var length := a.distance_to(b)
		if length < 1.0:
			continue
		var dir := (b - a) / length
		var drive: bool = CLASSES[edge_cls[e]].drive
		# Walk from one end to the other along streets that stay on e
		# (drivable ones, if e is).
		var cur := edge_a[e]
		var prev := e
		var steps := 0
		while cur != edge_b[e] and steps < 8:
			var nxt := -1
			for f in _adj[cur]:
				if f == e or f == prev or (drive and not CLASSES[edge_cls[f]].drive):
					continue
				var q := node_pos[other(f, cur)]
				var t := (q - a).dot(dir)
				if t <= (node_pos[cur] - a).dot(dir) + 0.01 or t > length + 0.5:
					continue
				if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) > 1.0:
					continue
				nxt = f
				break
			if nxt < 0:
				break
			prev = nxt
			cur = other(nxt, cur)
			steps += 1
		if cur == edge_b[e] and steps > 0:
			_kill(e)


## Removes dead edges and lone nodes, renumbering both.
func _compact() -> void:
	var remap := PackedInt32Array()
	remap.resize(node_pos.size())
	remap.fill(-1)
	var pos2 := PackedVector2Array()
	for k in node_pos.size():
		if _adj[k].size() > 0:
			remap[k] = pos2.size()
			pos2.append(node_pos[k])
	var a2 := PackedInt32Array()
	var b2 := PackedInt32Array()
	var c2: Array[String] = []
	var r2: Array[String] = []
	var p2 := PackedInt32Array()
	var f2 := PackedInt32Array()
	for e in edge_a.size():
		if _dead[e] == 1:
			continue
		a2.append(remap[edge_a[e]])
		b2.append(remap[edge_b[e]])
		c2.append(edge_cls[e])
		r2.append(edge_road[e])
		p2.append(edge_patch[e])
		f2.append(_fam[e])
	node_pos = pos2
	edge_a = a2
	edge_b = b2
	edge_cls = c2
	edge_road = r2
	edge_patch = p2
	_fam = f2
	_rebuild_adj()
	_sort_adj()


func _sort_adj() -> void:
	for k in node_pos.size():
		var list: Array = _adj[k]
		var p := node_pos[k]
		list.sort_custom(func(x, y):
			var dx := node_pos[other(x, k)] - p
			var dy := node_pos[other(y, k)] - p
			return atan2(dx.y, dx.x) < atan2(dy.y, dy.x))


## The chain of edges through nodes that only bend, starting along edge e
## from node n: [edges, end node].
func _link(n: int, e: int) -> Array:
	var edges: Array = [e]
	var cur := other(e, n)
	var prev_e := e
	while _adj[cur].size() == 2 and cur != n:
		var nxt: int = _adj[cur][0] if _adj[cur][0] != prev_e else _adj[cur][1]
		edges.append(nxt)
		prev_e = nxt
		cur = other(nxt, cur)
	return [edges, cur]


## The whole run of edge e between real junctions: [edges, end, end].
func _full_link(e: int) -> Array:
	var edges: Array = [e]
	var ends: Array = []
	for start in [edge_a[e], edge_b[e]]:
		var cur: int = start
		var prev_e := e
		while _adj[cur].size() == 2:
			var nxt: int = _adj[cur][0] if _adj[cur][0] != prev_e else _adj[cur][1]
			if nxt == e:
				break
			edges.append(nxt)
			prev_e = nxt
			cur = other(nxt, cur)
		ends.append(cur)
	return [edges, ends[0], ends[1]]


## Drops some district streets and makes others pedestrian lanes, as each
## district's rules say. Dropping a street joins the blocks either side,
## within the district's size limits, and never cuts junctions off.
func _thin() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "thin"])
	var links: Array = []
	var seen := {}
	for n in node_pos.size():
		if _adj[n].size() == 2:
			continue
		for e in _adj[n]:
			if seen.has(e) or edge_patch[e] < 0:
				continue
			var l := _full_link(e)
			for x in l[0]:
				seen[x] = true
			links.append(l)
	# Blocks joined so far: union-find over faces.
	var group := PackedInt32Array()
	var pts: Array = []
	var areas := PackedFloat32Array()
	for f in faces.size():
		group.append(f)
		pts.append(faces[f].poly)
		areas.append(faces[f].area)
	for l in links:
		var e0: int = l[0][0]
		var p: Dictionary = PATCHES[edge_patch[e0]]
		var roll := rng.randf()
		var cut: float = p.cut[_fam[e0]] if _fam[e0] >= 0 else 0.0
		if roll < cut:
			if _adj[l[1]].size() < 3 or _adj[l[2]].size() < 3:
				continue
			# A short link (the step of a jogged street) would join two
			# blocks by a neck the streets eat away.
			if node_pos[l[1]].distance_to(node_pos[l[2]]) < 24.0:
				continue
			var slots := edge_face[e0]
			if slots.x < 0 or slots.y < 0 or faces[slots.x].kind != "land" or faces[slots.y].kind != "land":
				continue
			var gf := _find(group, slots.x)
			var gg := _find(group, slots.y)
			if gf == gg or areas[gf] + areas[gg] > p.max[2]:
				continue
			var joined: PackedVector2Array = pts[gf] + pts[gg]
			var th := deg_to_rad(p.angle)
			if _extent(joined, Vector2(cos(th), sin(th))) > p.max[0] or _extent(joined, Vector2(-sin(th), cos(th))) > p.max[1]:
				continue
			for e in l[0]:
				_kill(e)
			if not _joined(l[1], l[2]):
				for e in l[0]:
					_revive(e)
				continue
			group[gg] = gf
			pts[gf] = joined
			areas[gf] += areas[gg]
		elif roll < cut + p.lane:
			for e in l[0]:
				edge_cls[e] = "lane"
			if not _joined(l[1], l[2]):
				for e in l[0]:
					edge_cls[e] = p.cls


## A junction of five or more streets (where district streets happened to
## cross a road at another junction) loses district streets, shortest
## link first, down to four where the network allows.
func _ease_crowds() -> void:
	for n in node_pos.size():
		if _adj[n].size() < 5:
			continue
		var options: Array = [] # [length, edge]
		for e in _adj[n]:
			if edge_patch[e] >= 0:
				var l := _full_link(e)
				var length := 0.0
				for x in l[0]:
					length += node_pos[edge_a[x]].distance_to(node_pos[edge_b[x]])
				options.append([length, e])
		options.sort_custom(func(x, y): return x[0] < y[0])
		for o in options:
			if _adj[n].size() < 5:
				break
			if _dead[o[1]] == 0:
				_drop_links([o[1]])


func _in_hole(q: Vector2) -> bool:
	for hole in _holes:
		if Geometry2D.is_point_in_polygon(q, hole):
			return true
	return false


static func _extent(pts: PackedVector2Array, axis: Vector2) -> float:
	var lo := INF
	var hi := -INF
	for q in pts:
		var t := q.dot(axis)
		lo = minf(lo, t)
		hi = maxf(hi, t)
	return hi - lo


func _revive(e: int) -> void:
	_dead[e] = 0
	_adj[edge_a[e]].append(e)
	_adj[edge_b[e]].append(e)


## True when junctions a and b are still joined by drivable streets
## (breadth first, so it stops after a few blocks when they are). Taking
## a link out strands part of the map exactly when its two ends part.
## If either end is in the playable window the path must stay in it
## (traffic and the player can't use the margin).
func _joined(a: int, b: int) -> bool:
	if a == b:
		return true
	var play := window.grow(2.0)
	var inside := play.has_point(node_pos[a]) or play.has_point(node_pos[b])
	if not play.has_point(node_pos[a]):
		var x := a
		a = b
		b = x
	var seen := {a: true}
	var todo := PackedInt32Array([a])
	var i := 0
	while i < todo.size():
		var k := todo[i]
		i += 1
		for e in _adj[k]:
			if not CLASSES[edge_cls[e]].drive:
				continue
			var m := edge_b[e] if edge_a[e] == k else edge_a[e]
			if m == b:
				return true
			if inside and not play.has_point(node_pos[m]):
				continue
			if not seen.has(m):
				seen[m] = true
				todo.append(m)
	return false


func _drives(k: int) -> bool:
	for e in _adj[k]:
		if CLASSES[edge_cls[e]].drive:
			return true
	return false


# --- Blocks ------------------------------------------------------------------------

func _find_faces() -> void:
	faces = []
	edge_face = []
	edge_face.resize(edge_a.size())
	for e in edge_a.size():
		edge_face[e] = Vector2i(-1, -1)
	var used := PackedByteArray()
	used.resize(edge_a.size() * 2)
	var loops: Array = []
	for h in edge_a.size() * 2:
		if used[h] == 1:
			continue
		var halves := PackedInt32Array()
		var cur := h
		var guard := 0
		while used[cur] == 0 and guard < 4000:
			used[cur] = 1
			halves.append(cur)
			cur = _next_half(cur)
			guard += 1
		var poly := PackedVector2Array()
		for x in halves:
			poly.append(node_pos[edge_a[x >> 1]] if (x & 1) == 0 else node_pos[edge_b[x >> 1]])
		loops.append([halves, area(poly)])
	var pos_count := 0
	for l in loops:
		if l[1] > 0.0:
			pos_count += 1
	var sign := 1.0 if pos_count * 2 >= loops.size() else -1.0
	edge_loops = []
	for l in loops:
		if l[1] * sign <= 0.0:
			# Outside every block: the edge of a piece of the graph.
			var ring := PackedVector2Array()
			for x in l[0]:
				ring.append(node_pos[edge_a[x >> 1]] if (x & 1) == 0 else node_pos[edge_b[x >> 1]])
			edge_loops.append(ring)
			continue
		var halves: PackedInt32Array = l[0]
		var f := faces.size()
		var nodes := PackedInt32Array()
		var edges := PackedInt32Array()
		for x in halves:
			var e := x >> 1
			nodes.append(edge_a[e] if (x & 1) == 0 else edge_b[e])
			edges.append(e)
			var slot := edge_face[e]
			if (x & 1) == 0:
				slot.x = f
			else:
				slot.y = f
			edge_face[e] = slot
		if sign < 0.0:
			# Reverse to clockwise on screen: node k -> k + 1 along edge k.
			var n := nodes.size()
			var rn := PackedInt32Array()
			var re := PackedInt32Array()
			for i in n:
				rn.append(nodes[(n - i) % n])
				re.append(edges[(n - 1 - i + n) % n])
			nodes = rn
			edges = re
		var poly := PackedVector2Array()
		for k in nodes:
			poly.append(node_pos[k])
		var c := interior_point(poly)
		faces.append({
			"nodes": nodes, "edges": edges, "poly": poly, "area": absf(area(poly)), "center": c,
			"kind": "water" if is_water_point(c) else "land", "bbox": _bbox(poly),
			"inner": PackedVector2Array(), "sides": PackedInt32Array(), "lot": PackedVector2Array(), "front": 0,
		})


## Drops the blocks whose middle lies outside the outline and the streets
## that only served them, so the city ends block by block along its edge
## instead of on a frame street. Keeps the junctions where a street went on
## out as exits.
func _trim_to_outline(pins: Array) -> void:
	var keep := PackedByteArray()
	keep.resize(faces.size())
	var pinned := PackedByteArray()
	pinned.resize(faces.size())
	for f in faces.size():
		if faces[f].kind != "land":
			continue
		if Geometry2D.is_point_in_polygon(faces[f].center, outline):
			keep[f] = 1
		for q in pins:
			if Geometry2D.is_point_in_polygon(q, faces[f].poly):
				keep[f] = 1
				pinned[f] = 1
	# Smooth the block-by-block edge: a block held on by one neighbour is a
	# spur and goes; a land block of up to a few blocks' size with three
	# kept neighbours is a notch and stays (a long strip along the edge,
	# like the beach past Ocean Drive, is not). Water counts as a neighbour
	# for spurs, so bank blocks are not stripped.
	for pass_ in 3:
		var sides: Array[Vector2i] = []
		sides.resize(faces.size())
		var seen := {}
		for e in edge_a.size():
			var s := edge_face[e]
			if s.x < 0 or s.y < 0 or s.x == s.y:
				continue
			for pair in [[s.x, s.y], [s.y, s.x]]:
				var o: int = pair[1]
				var key := Vector2i(pair[0], o)
				if seen.has(key):
					continue
				seen[key] = true
				if keep[o] == 1:
					sides[pair[0]].x += 1
				elif faces[o].kind == "water":
					sides[pair[0]].y += 1
		var changed := false
		for f in faces.size():
			if faces[f].kind != "land":
				continue
			if keep[f] == 1 and pinned[f] == 0 and sides[f].x + sides[f].y <= 1:
				keep[f] = 0
				changed = true
			elif keep[f] == 0 and sides[f].x >= 3 and faces[f].area < NOTCH_MAX:
				keep[f] = 1
				changed = true
		if not changed:
			break
	var cut: Array = []
	for e in edge_a.size():
		if edge_cls[e] == "bridge": # borders no block; _prune drops it if a bank went
			continue
		var s := edge_face[e]
		if not ((s.x >= 0 and keep[s.x] == 1) or (s.y >= 0 and keep[s.y] == 1)):
			cut.append(e)
	for e in cut:
		_kill(e)
	# A bridge whose far bank lost its blocks goes too.
	_prune()
	var out: Array = []
	for e in cut:
		for n in [edge_a[e], edge_b[e]]:
			if _adj[n].size() > 0:
				out.append([node_pos[n], (node_pos[other(e, n)] - node_pos[n]).normalized(), edge_cls[e], edge_road[e]])
	_compact()
	_find_faces()
	exits = []
	for x in out:
		var n := -1
		for k in node_pos.size():
			if node_pos[k].is_equal_approx(x[0]):
				n = k
				break
		if n >= 0:
			exits.append({"node": n, "dir": x[1], "cls": x[2], "road": x[3]})
	# Serena Causeway lands on Ocean Drive across the beach, which is left
	# out of the city: the Drive's junction nearest the landing is its exit.
	var landing = Geometry2D.line_intersects_line(CAUSEWAY_FROM, CAUSEWAY_DIR, OCEAN_AT, GULF_DIR)
	if landing != null and not Geometry2D.is_point_in_polygon(landing + CAUSEWAY_DIR * 30.0, outline):
		var best := -1
		for k in node_pos.size():
			if node_pos[k].distance_to(landing) < 80.0 and _adj[k].any(func(e): return edge_road[e] == "ocean") \
					and (best < 0 or node_pos[k].distance_to(landing) < node_pos[best].distance_to(landing)):
				best = k
		if best >= 0 and not exits.any(func(x): return x.node == best):
			exits.append({"node": best, "dir": CAUSEWAY_DIR, "cls": "avenue", "road": "causeway"})


## Next half-edge round the same face. Half-edge 2e runs a -> b, 2e + 1
## runs b -> a.
func _next_half(h: int) -> int:
	var e := h >> 1
	var v := edge_b[e] if (h & 1) == 0 else edge_a[e]
	var list: Array = _adj[v]
	var i := list.find(e)
	var e2: int = list[(i + 1) % list.size()]
	return e2 * 2 if edge_a[e2] == v else e2 * 2 + 1


## Joins blocks too small for their landmark (or the park) with the
## neighbour that helps most, dropping the district street between them.
## `wants` holds [local point, lot size]. True if anything changed.
func _grow_blocks(wants: Array) -> bool:
	_index()
	var claimed := {}
	for w in wants:
		var f := face_of(w[0])
		if f >= 0:
			claimed[f] = true
	var changed := false
	for w in wants:
		var f := face_of(w[0])
		if f < 0 or faces[f].kind != "land":
			continue
		_block_geom(f)
		if faces[f].kind != "land" or faces[f].lot.size() < 3:
			continue
		var need: Vector2 = w[1]
		var to_frame := front_frame2d(f).affine_inverse()
		var fit: float = _landmark_rect(f, need)[2]
		if fit >= 1.0:
			continue
		# Options: [fit, edges to drop], one neighbour at a time; when none
		# helps, pairs (fanned blocks lean, so an L of three blocks may not
		# fit where the fourth block fills it out).
		var options: Array = []
		var singles := _merge_options(f, faces[f].poly, [f], claimed)
		for o in singles:
			var gfit := _merged_fit(o[2], to_frame, need)
			if gfit > fit + 0.02:
				options.append([gfit, [o[1]], [o[0]]])
		if _drop_best(options, claimed):
			changed = true
			continue
		options = []
		for o in singles:
			for o2 in _merge_options(f, o[2], [f, o[0]], claimed):
				var gfit := _merged_fit(o2[2], to_frame, need)
				if gfit > fit + 0.02:
					options.append([gfit, [o[1], o2[1]], [o[0], o2[0]]])
		if _drop_best(options, claimed):
			changed = true
	return changed


## Drops streets with no block on either side (one straightened to run a
## metre or two from another leaves only a sliver between them), unless
## that leaves a dead end or cuts the map.
func _drop_orphans() -> bool:
	var dropped := false
	for e in edge_a.size():
		if _dead[e] == 1 or edge_cls[e] == "bridge" or edge_face[e].x >= 0 or edge_face[e].y >= 0:
			continue
		if _drop_links([e]):
			dropped = true
	return dropped


## Drops the streets of the best option that can go ([fit, edges, faces]
## each) and claims the faces it joins, so a later landmark in the same
## pass (faces aren't rebuilt until the pass ends) can't take them too.
func _drop_best(options: Array, claimed: Dictionary) -> bool:
	options.sort_custom(func(x, y): return x[0] > y[0])
	for o in options:
		if _drop_links(o[1]):
			for g in o[2]:
				claimed[g] = true
			return true
	return false


## Neighbours of the blocks in `members` (around `poly`, their union) that a
## landmark block may join: [face, edge between, union polygon].
func _merge_options(f: int, poly: PackedVector2Array, members: Array, claimed: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	for m in members:
		for e in faces[m].edges:
			if edge_patch[e] < 0 or _dead[e] == 1:
				continue
			var slots := edge_face[e]
			var g := slots.y if slots.x == m else slots.x
			if g < 0 or members.has(g) or seen.has(g) or faces[g].kind != "land" or (claimed.has(g) and g != f):
				continue
			seen[g] = true
			var merged := _largest(Geometry2D.merge_polygons(poly, faces[g].poly))
			if merged.size() >= 3:
				out.append([g, e, merged])
	return out


## How well a joined block would hold `need`: its outline, pulled in by
## about a street half and a sidewalk.
func _merged_fit(merged: PackedVector2Array, to_frame: Transform2D, need: Vector2) -> float:
	var approx := _largest(Geometry2D.offset_polygon(merged, -(CLASSES.street.width * 0.5 + SIDEWALK)))
	if approx.size() < 3:
		return 0.0
	return _fit(largest_rect(to_frame * approx, need), need)


## Drops the streets through `edges` (each with the bends either side), or
## none of them if that would strand a junction.
func _drop_links(edges: Array) -> bool:
	# Find every link first: once one goes, a T-junction it shared looks
	# like a bend, and the next link would run on through it.
	var links: Array = []
	for e in edges:
		if _dead[e] == 0:
			links.append(_full_link(e))
	var killed: Array = []
	for l in links:
		for k in l[0]:
			if _dead[k] == 0:
				_kill(k)
				killed.append(k)
	# A stub left sticking into the joined block (two links met at a
	# T-junction) goes too.
	var i := 0
	while i < links.size() and i < 8:
		for n in [links[i][1], links[i][2]]:
			if _adj[n].size() == 1:
				# Named roads and the bridge stay; the dead end left fails
				# the check below.
				var stub := _full_link(_adj[n][0])
				if edge_road[stub[0][0]] != "":
					continue
				for k in stub[0]:
					_kill(k)
					killed.append(k)
				links.append(stub)
		i += 1
	# No dead ends, and every end of a drivable link that still has a
	# street to drive on joined to the others (a stub's far end too, when
	# the junction between them went with it).
	var cut := false
	var ends: Array[int] = []
	for l in links:
		for n in [l[1], l[2]]:
			cut = cut or _adj[n].size() == 1
			if CLASSES[edge_cls[l[0][0]]].drive and _drives(n) and not ends.has(n):
				ends.append(n)
	for n in ends:
		if cut:
			break
		cut = not _joined(n, ends[0])
	if cut:
		for k in killed:
			_revive(k)
		return false
	return not killed.is_empty()


static func _fit(r: Rect2, need: Vector2) -> float:
	return minf(r.size.x / need.x, r.size.y / need.y)


## Where a landmark goes in block f: [side, rect in that side's frame, fit]
## over the block's street sides, the rect centred on its side so the door
## (and the sidewalk spot in front) faces that street. Best fit wins, then
## the camera-facing front, then area.
func _landmark_rect(f: int, need: Vector2, facing := Vector2.ZERO) -> Array:
	var face: Dictionary = faces[f]
	var inner: PackedVector2Array = face.inner
	var best: Array = [face.front, Rect2(), -1.0]
	var best_a := 0.0
	var best_toward := false
	for k in inner.size():
		var e: int = face.sides[k]
		if e < 0 or not drivable(e) or edge_cls[e] == "bridge":
			continue
		var a0 := inner[k]
		var a1 := inner[(k + 1) % inner.size()]
		var half := a0.distance_to(a1) * 0.5
		if half < 8.0:
			continue
		var r := largest_rect(side_frame2d(f, k).affine_inverse() * face.lot, need, half - 3.0)
		var fit := minf(1.0, _fit(r, need))
		var a := r.get_area()
		var d := (a1 - a0).normalized()
		var toward := facing != Vector2.ZERO and Vector2(d.y, -d.x).dot(facing) > 0.7
		var better: bool = fit > best[2] + 0.001
		if not better and fit > best[2] - 0.001:
			if toward != best_toward:
				better = toward
			else:
				better = k == face.front or (best[0] != face.front and a > best_a)
		if better:
			best = [k, r, fit]
			best_a = a
			best_toward = toward
	if best[2] <= 0.0 or (best[1] as Rect2).get_area() <= 0.0:
		best = [face.front, largest_rect(front_frame2d(f).affine_inverse() * face.lot, need), 0.0]
		best[2] = minf(1.0, _fit(best[1], need))
	return best


func _make_blocks() -> void:
	for f in faces.size():
		var face: Dictionary = faces[f]
		face["rect"] = Rect2()
		face["patch"] = _patch_index(face.center)
		if face.kind == "land":
			_block_geom(f)
			if face.kind == "land" and face.lot.size() >= 3:
				face.rect = largest_rect(front_frame2d(f).affine_inverse() * face.lot)


## Inner polygon, lot, street sides and front of block f.
func _block_geom(f: int) -> void:
	var face: Dictionary = faces[f]
	var poly: PackedVector2Array = face.poly
	var n := poly.size()
	var pieces: Array = [poly]
	for k in n:
		var e: int = face.edges[k]
		var w := edge_width(e) * 0.5
		var a := poly[k]
		var b := poly[(k + 1) % n]
		var d := (b - a).normalized()
		var side := Vector2(-d.y, d.x) * w
		var strip := PackedVector2Array([a - d * w + side, b + d * w + side, b + d * w - side, a - d * w - side])
		var next: Array = []
		for piece in pieces:
			next.append_array(Geometry2D.clip_polygons(piece, strip))
		pieces = next
	var inner_poly := _tidy(_largest(pieces))
	if inner_poly.size() < 3 or absf(area(inner_poly)) < 40.0:
		face.kind = "sliver"
		face.inner = PackedVector2Array()
		face.lot = PackedVector2Array()
		return
	face.inner = inner_poly
	var lot_poly := _tidy(_largest(Geometry2D.offset_polygon(inner_poly, -SIDEWALK, Geometry2D.JOIN_MITER)))
	face.lot = lot_poly if lot_poly.size() >= 3 else PackedVector2Array()
	# Which street each inner side runs along.
	var m := inner_poly.size()
	var sides := PackedInt32Array()
	for k in m:
		var a := inner_poly[k]
		var b := inner_poly[(k + 1) % m]
		var mid := (a + b) * 0.5
		var d := (b - a).normalized()
		var best := -1
		var best_err := 1.6
		for j in n:
			var e: int = face.edges[j]
			var pa := poly[j]
			var pb := poly[(j + 1) % n]
			var ed := (pb - pa).normalized()
			if absf(ed.cross(d)) > 0.2:
				continue
			var err := absf(Geometry2D.get_closest_point_to_segment_uncapped(mid, pa, pb).distance_to(mid) - edge_width(e) * 0.5)
			var t := (mid - pa).dot(ed)
			if t < -edge_width(e) or t > pa.distance_to(pb) + edge_width(e):
				continue
			if err < best_err:
				best_err = err
				best = e
		sides.append(best)
	face.sides = sides
	# The front: the street side facing the camera most, preferring real
	# streets and longer sides.
	var front := 0
	var best_score := -INF
	for k in m:
		var e := sides[k]
		var a := inner_poly[k]
		var b := inner_poly[(k + 1) % m]
		var d := (b - a).normalized()
		var out := Vector2(d.y, -d.x)
		var score := out.y
		if e < 0 or not drivable(e) or edge_cls[e] == "bridge":
			score -= 2.0
		else:
			score += CLASSES[edge_cls[e]].rank * 0.03
		if a.distance_to(b) < 16.0:
			score -= 0.8
		if score > best_score:
			best_score = score
			front = k
	face.front = front


## The block frame for f: basis.x along the front street (left to right
## seen from it), basis.z out through it, origin at the front's middle on
## the inner polygon.
func front_frame2d(f: int) -> Transform2D:
	return side_frame2d(f, faces[f].front)


## The same frame on inner side k of block f.
func side_frame2d(f: int, k: int) -> Transform2D:
	var poly: PackedVector2Array = faces[f].inner
	var a := poly[k]
	var b := poly[(k + 1) % poly.size()]
	var along := (a - b).normalized()
	var out := Vector2(-along.y, along.x)
	return Transform2D(along, out, (a + b) * 0.5)


## The largest rectangle in f's lot aligned with its front frame, in frame
## coordinates (x along, y out through the front, so the lot is at y < 0).
func lot_rect(f: int) -> Rect2:
	var face: Dictionary = faces[f]
	if face.has("rect"):
		return face.rect
	if face.lot.size() < 3:
		return Rect2()
	return largest_rect(front_frame2d(f).affine_inverse() * face.lot)


## Id of the district patch block f belongs to ("" outside every patch).
func face_patch(f: int) -> String:
	var k: int = faces[f].get("patch", -1)
	return PATCHES[k].id if k >= 0 else ""


## Id of the district patch at local point p ("" outside every patch).
func patch_at(p: Vector2) -> String:
	var k := _patch_index(p)
	return PATCHES[k].id if k >= 0 else ""


func _patch_index(p: Vector2) -> int:
	for r in _regions:
		if Geometry2D.is_point_in_polygon(p, r[0]):
			return r[1]
	return -1


func _index() -> void:
	_node_grid = {}
	for k in node_pos.size():
		var key := Vector2i(floori(node_pos[k].x / GRID), floori(node_pos[k].y / GRID))
		if not _node_grid.has(key):
			_node_grid[key] = []
		_node_grid[key].append(k)
	_face_grid = {}
	for f in faces.size():
		var r: Rect2 = faces[f].bbox
		for gx in range(floori(r.position.x / GRID), floori(r.end.x / GRID) + 1):
			for gy in range(floori(r.position.y / GRID), floori(r.end.y / GRID) + 1):
				var key := Vector2i(gx, gy)
				if not _face_grid.has(key):
					_face_grid[key] = []
				_face_grid[key].append(f)


# --- Polygons ------------------------------------------------------------------------

## Shoelace area: positive for clockwise on screen (y down).
static func area(poly: PackedVector2Array) -> float:
	var s := 0.0
	var n := poly.size()
	for k in n:
		s += poly[k].cross(poly[(k + 1) % n])
	return s * 0.5


static func _bbox(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


static func _largest(polys: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_a := 0.0
	for p in polys:
		var a := absf(area(p))
		if a > best_a:
			best_a = a
			best = p
	return best


## Clockwise on screen, without repeated or straight-through points.
static func _tidy(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < 3:
		return poly
	if area(poly) < 0.0:
		poly.reverse()
	# Near-duplicate points first, then points on a straight run, each
	# tested against the points kept (testing against the original
	# neighbours dropped both copies of a doubled corner, cutting the
	# corner off).
	var out := PackedVector2Array()
	for b in poly:
		if out.is_empty() or b.distance_to(out[out.size() - 1]) >= 0.3:
			out.append(b)
	while out.size() > 3 and out[0].distance_to(out[out.size() - 1]) < 0.3:
		out.remove_at(out.size() - 1)
	var changed := true
	while changed:
		changed = false
		var k := 0
		while out.size() > 3 and k < out.size():
			var n := out.size()
			var a := out[(k - 1 + n) % n]
			var b := out[k]
			var c := out[(k + 1) % n]
			if absf((b - a).normalized().cross((c - b).normalized())) < 0.01 and (b - a).dot(c - b) > 0.0:
				out.remove_at(k)
				changed = true
			else:
				k += 1
	return out


## A point inside the polygon (its centroid when that is inside).
static func interior_point(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	var a := 0.0
	var n := poly.size()
	for k in n:
		var cr := poly[k].cross(poly[(k + 1) % n])
		a += cr
		c += (poly[k] + poly[(k + 1) % n]) * cr
	if absf(a) > 0.001:
		c /= 3.0 * a
		if Geometry2D.is_point_in_polygon(c, poly):
			return c
	var tris := Geometry2D.triangulate_polygon(poly)
	var best := poly[0]
	var best_a := -1.0
	for t in range(0, tris.size(), 3):
		var p0 := poly[tris[t]]
		var p1 := poly[tris[t + 1]]
		var p2 := poly[tris[t + 2]]
		var ta := absf((p1 - p0).cross(p2 - p0))
		if ta > best_a:
			best_a = ta
			best = (p0 + p1 + p2) / 3.0
	return best


## The largest axis-aligned rectangle inside a polygon (scanlines 1.5 m
## apart, so it can be a little generous between them; trimmed for that).
## With `need`, a rectangle that fits need (or comes closest) wins over a
## bigger one that doesn't: an L-shaped block's largest rectangle can be a
## long thin strip when a squarer one would hold a landmark. With `reach`,
## only rectangles on the front (top within a metre or so of the lot's
## front edge) whose middle is within reach of x = 0 count.
static func largest_rect(poly: PackedVector2Array, need := Vector2.ZERO, reach := -1.0) -> Rect2:
	var r := _bbox(poly)
	var step := maxf(1.5, r.size.x / 40.0)
	var xs := PackedFloat32Array()
	var lows := PackedFloat32Array()
	var highs := PackedFloat32Array()
	var n := poly.size()
	var x := r.position.x + step * 0.5
	while x < r.end.x:
		var zs: Array = []
		for k in n:
			var a := poly[k]
			var b := poly[(k + 1) % n]
			if (a.x <= x) != (b.x <= x):
				zs.append(a.y + (x - a.x) / (b.x - a.x) * (b.y - a.y))
		zs.sort()
		var lo := 0.0
		var hi := 0.0
		for i in range(0, zs.size() - 1, 2):
			if zs[i + 1] - zs[i] > hi - lo:
				lo = zs[i]
				hi = zs[i + 1]
		xs.append(x)
		lows.append(lo + 0.3)
		highs.append(hi - 0.3)
		x += step
	var best := Rect2()
	var best_a := 0.0
	var best_f := 0.0
	for i in xs.size():
		var top := -INF
		var bottom := INF
		for j in range(i, xs.size()):
			top = maxf(top, lows[j])
			bottom = minf(bottom, highs[j])
			if bottom <= top:
				break
			var w := xs[j] - xs[i]
			if reach >= 0.0 and (bottom < -SIDEWALK - 1.5 or absf(xs[i] + w * 0.5) > reach):
				continue
			var a := w * (bottom - top)
			var f := 0.0 if need == Vector2.ZERO else minf(1.0, _fit(Rect2(0, 0, w, bottom - top), need))
			if f > best_f + 0.001 or (f > best_f - 0.001 and a > best_a):
				best_f = f
				best_a = a
				best = Rect2(xs[i], top, w, bottom - top)
	return best
