#!/usr/bin/env python3
"""Builds the country around Bellerive (phase 2) into data/country.json.

Everything outside the city's footprint (the street plan's edge loops
grown FRAME_IN) that the game streams in tiles (scripts/country.gd): the
play area, ground by zone, the road graph with its polylines and bridges,
walls along water and the play area's edge, storm barricades where roads
leave it, suburb and town lots, and links from the country roads to the
street plan's exits (the junctions where a cut street left the city).

Bellerive's suburbs fill its urban outline (world_map.json "urban") round
the footprint; the Beltway rings that outline.

Needs shapely, numpy and contourpy (pip install shapely numpy contourpy) and
a plan dump of the current street plan (the country's suburb streets carry on
from its exits):

    cd game
    godot --headless -s res://tests/plan_dump.gd -- /tmp/plan.json
    python3 tools/build_country.py /tmp/plan.json

After the core (world_map.json "core") changes, draft the urban outline
again first (it rewrites world_map.json's Bellerive "urban"):

    python3 tools/build_country.py --urban

All output is in local metres: world-map metres minus Bellerive's
demo_window origin (game x = local x, game z = local y), like the city.
"""

import collections
import json
import math
import random
import sys
from pathlib import Path

import shapely
from shapely import constrained_delaunay_triangles
from shapely.geometry import LineString, MultiLineString, Point, Polygon, box
from shapely.geometry.polygon import orient
from shapely.ops import linemerge, nearest_points, polygonize, split, substring, unary_union
from shapely.prepared import prep
from shapely.strtree import STRtree

sys.path.insert(0, str(Path(__file__).resolve().parent))
from road_classes import CLASSES, CITY_RANK  # noqa: E402
import farmland  # noqa: E402
import wealth  # noqa: E402
from mountain import Mountain, roads as mountain_roads, lines as mountain_lines, OBSERVATORY, OBSERVATORY_SIZE, OBSERVATORY_ROAD_END, LETTERS, LETTERS_SIZE, MASTS, MAST_SIZE  # noqa: E402
from mountain import GRADE, SUMMIT_SITES, PEAKS, CABLE, CABLE_MID_SIZE, CELL as MTN_CELL  # noqa: E402
from mountain import VIEWPOINTS, VIEW_SIZE, VIEW_FLAT  # noqa: E402
import numpy as np  # noqa: E402
from scipy import ndimage  # noqa: E402
import contourpy  # noqa: E402

# An avenue grades like a street.
GRADE.setdefault("avenue", GRADE["street"])

ROOT = Path(__file__).resolve().parent.parent
WORLD = ROOT / "data" / "world_map.json"
OUT = ROOT / "data" / "country.json"

TILE = 100.0
# The city's footprint: the plan's edge loops (the streets round its edge)
# grown this far; a link joins the country 4 m out from its exit junction.
FRAME_IN = 4.0
# The edge streets' width (street_plan.gd CLASSES street): 5 m of it lies
# beyond the footprint.
CITY_STREET_W = 18.0
# The Beltway: round the urban outline this far out, its bends no tighter
# than BELT_SMOOTH.
BELT_OFF = 80.0
BELT_SMOOTH = 220.0
BELT_STRAIGHT_MAX = 600.0   # self_check: no straight run longer than this
URBAN_BOX_MAX = 0.8         # self_check: the urban outline fills less of its bbox
LEAD_SHORT = 450.0          # a route ending this near the city is led on in to an exit
# The Bellerive Hills' road tags (tools/mountain.py).
MTN_TAGS = ("freeway", "crest", "canyon", "observatory", "fire_road", "letters_trail", "calder", "track", "trail", "hills")
HOME_TOP = 400.0  # no hillside homes higher than this (m)
# The fillet the range's planned ways get where a city exit joins them.
MTN_FILLET = {"highway": 200.0, "road": 45.0, "lane": 30.0, "track": 12.0, "trail": 15.0}
# Planned ways graded under their class cap: the 8 m height grid reads a road
# graded right at the cap up to ~0.02 steeper over 32 m (Crest Drive's hairpin
# at (1760,-1130) measured 0.144-0.151 as its centre line moved 0.2 m).
MTN_CAP = {"crest": 0.125}

# Ground beyond the play area, so the edge is a fence, not the end of the world.
BEYOND = 450.0

CLASS_NAMES = list(CLASSES)
RAIL_TYPES = {"rail": "rail", "metro": "metro", "mover": "metro", "streetcar": "streetcar"}

# Lot sizes (along the street, deep) by kind; country_kit.gd builds them.
LOT = {
    "farmhouse": (16, 14), "barn": (18, 24), "silos": (12, 12), "machine_shed": (20, 14),
    "trailer_home": (9, 18), "shack": (8, 9), "stilt_house": (11, 11), "water_tower": (10, 10),
    "windpump": (6, 6), "gas_station": (30, 26), "diner": (20, 16), "motel": (40, 26),
    "general_store": (16, 14), "truck_stop": (60, 45), "garage": (20, 18), "town_hall": (22, 18),
    "bar": (16, 14), "shopfront": (10, 14), "house": (14, 14), "mansion": (32, 28),
    "garden_apartments": (30, 18), "strip_mall": (50, 24), "deco_hotel": (30, 22),
    "condo_tower": (26, 26), "beach_bar": (12, 10), "lifeguard_tower": (4, 4),
    "grain_elevators": (40, 30), "hollis_farm": (60, 50), "larkspur_vineyard": (40, 34),
    "gator_farm": (46, 40), "moonshine_still": (16, 14), "bellerive_general": (70, 50),
    "bus_terminal": (60, 40), "seaplane_base": (34, 40), "cruise_terminal": (90, 40),
    "torque_tone": (34, 26), "aurum_hangar": (50, 40), "police_station": (22, 16),
    "county_hospital": (36, 26), "airboat_dock": (18, 24), "airstrip_hangar": (26, 22),
    # Bellerive v3 (HANDOFF-bellerive-v3.md B-4, B-5): kits/civic_kit.gd builds these.
    "fire_station": (26, 22), "post_office": (30, 24), "dmv_office": (40, 30), "sheriff_station": (30, 24),
    "public_school": (60, 40), "rowhouse_row": (36, 12), "cape_house": (11, 9), "pier_rides": (60, 140),
    "brownstone_row": (36, 14), "painted_lady_row": (36, 14),
    # The Bellerive Hills (tools/mountain.py), built from the skyline kit.
    "pump_house": (12, 9),
    # Farmhouses beside the plain one: big, small, ranch and adobe.
    "farmhouse_big": (26, 20), "farmhouse_small": (14, 12), "ranch_house": (22, 14),
    "adobe_farmhouse": (18, 15),
    "observatory": OBSERVATORY_SIZE, "hill_letters": LETTERS_SIZE, "radio_mast": MAST_SIZE,
    # Bellerive expand (HANDOFF-bellerive-expand.md BX-5): kits/homes_kit.gd
    # builds the homes and the gatehouse, kits/shady_kit.gd the rest. Only
    # upgrade_lots places them, on lots it resizes from these.
    "res_tower": (34, 34), "midrise_condo": (30, 22), "cheap_block": (34, 18), "exec_house": (24, 22),
    "gatehouse": (10, 8), "bungalow_barred": (12, 22), "burned_lot": (20, 20), "liquor_store": (22, 20),
    "pawn_shop": (14, 18), "check_cashing": (16, 16),
    # Hill country places (HANDOFF-hill-content.md): kits/hill_kit.gd.
    "research_lab": (90, 70), "lab_gate": (24, 16), "sawmill": (60, 44), "cult_compound": (80, 70),
    "ranger_post": (24, 20), "logging_camp": (40, 34), "mine_entrance": (30, 24), "stone_ring": (24, 24),
    "hot_spring": (16, 14), "cold_spring": (12, 10), "mountain_hotel": (60, 44), "lodge_hotel": (44, 32),
    "rave_clearing": (36, 30), "bungee_platform": (12, 10), "fairground": (70, 50), "hunting_store": (16, 20),
}
KINDS = list(LOT)

# Map landmarks built as country lots: landmark id -> kit kind.
LANDMARK_KIND = {
    "hollis_farm": "hollis_farm", "grain_elevators": "grain_elevators",
    "larkspur_vineyard": "larkspur_vineyard", "gator_farm": "gator_farm",
    "moonshine_still": "moonshine_still", "bellerive_general": "bellerive_general",
    "bellerive_bus_terminal": "bus_terminal", "seaplane_base": "seaplane_base",
    "cruise_terminal": "cruise_terminal", "torque_tone_bellerive": "torque_tone",
    "aurum_hangar": "aurum_hangar", "hale_estate": "mansion", "krewe_hall": "bar",
    "glades_airboats": "airboat_dock", "flats_airstrip": "airstrip_hangar",
    "ridley_diner": "diner", "county_hospital": "county_hospital",
    "state_police_flats": "police_station", "deco_row": "deco_hotel",
}

# Plots: road-square rectangles that hold grounds and lots (see HANDOFF-plots.md).
# Their parts are [kind, x, z, w, d, rot, variant] in the plot frame (x along
# the road, -z towards it); kits/grounds_kit.gd draws them. A rect part spans
# w across and d along its own z, turned by rot like a lot's yaw; a line part
# (wall, hedge, fence, trees) runs w along its own x.
PLOT_TYPES = ["estate", "cluster", "farmyard", "field",
              # Bellerive v3 outskirts: street trees along a kerb, a rowhouse
              # block's yards and H-alley, a tract house's parcel, and civic
              # grounds (village green, school, DMV, mini-mall forecourt).
              "verge", "block", "parcel", "civic",
              # Golden Flats: one span of a centre pivot's sprinkler arm.
              "pivot"]
PART_KINDS = ["lawn", "yard", "gravel", "drive", "track", "wall", "hedge", "fence", "gate", "trees",
              "court", "parterre", "tennis", "orchard", "crop", "vines", "boat", "woodpile", "garden",
              # Bellerive v3: asphalt parking with stalls (variant: rows along x
              # 0, along z 1), a paved rear alley, concrete paving (drives,
              # walks, a shop row's forecourt), a public pool, a playground, a
              # sports field (0 football, 1 baseball, 2 field in a running
              # track), a DMV drive-test course.
              "parking", "alley", "paving", "pool", "playground", "field", "course",
              # Golden Flats: a centre pivot's sprinkler span (variant 1 with
              # the pivot tower, 2 with the end overhang; see farmland.py).
              "sprinkler",
              # A footpath or a home's apron (variant 0 dirt, 1 gravel, 2 planks).
              "footpath"]
# Tree kinds for "trees" and "orchard" parts.
TREE_KINDS = ["oak", "palm", "cypress", "fruit", "magnolia", "jacaranda", "crepe_myrtle", "plane"]
# Dwellings that go into clusters rather than lots of their own.
DWELLINGS = ("house", "shack", "stilt_house", "trailer_home")
# Turn of cluster dwellings off the plot's axis (degrees) by style: small
# towns a little, the bayou edge of the city more, bayou camps most.
CLUSTER_JITTER = {"village": 8.0, "bayou_town": 16.0, "bayou_village": 26.0, "camp": 28.0, "trailers": 4.0}
# Homes in a cluster share its yard, so their lots are tighter than a street lot.
CLUSTER_LOT = {"house": (11, 12), "stilt_house": (10, 10), "shack": (8, 9)}
# Hill country places (HANDOFF-hill-content.md; positions from
# tools/hill_design_map.py). Villages: lots square to the nearest way, each
# as near the centre as there is room, in this order. Places: "front" the
# same, as near (x, y) as there is room; "site" at (x, y) or the nearest
# clear spot within `search` m, facing the nearest way (off-road places).
HILL_VILLAGES = [
    ("brackett", (2412.0, -2116.0), ["diner", "general_store", "gas_station", "bar", "garage", "house", "house",
                                     "house", "house"]),
    ("hollin", (1448.0, -4408.0), ["sawmill", "gas_station", "diner", "hunting_store", "general_store", "fairground",
                                   "garage", "house", "house", "house", "house"]),
]
HILL_PLACES = [
    ("truck_stop", 2790.0, -2310.0, "east_hills_truck_stop", "front", 160.0),
    ("motel", 2944.0, -2448.0, "copperback_motel", "front", 160.0),
    ("research_lab", 540.0, -4060.0, "kestrel_lab", "site", 140.0),
    ("lab_gate", 492.0, -4262.0, "kestrel_lab_gate", "front", 40.0),
    ("ranger_post", 584.0, -4200.0, "ranger_post", "front", 120.0),
    ("logging_camp", 250.0, -4110.0, "logging_camp", "site", 140.0),
    ("lodge_hotel", 2472.0, -3538.0, "whistler_lodge", "front", 160.0),
    ("cult_compound", 2316.0, -4024.0, "cult_compound", "site", 80.0),
    ("mountain_hotel", 905.0, -2800.0, "calder_summit_hotel", "site", 100.0),
    ("rave_clearing", 2664.0, -3104.0, "rave_copperback", "site", 80.0),
    ("rave_clearing", 2704.0, -2920.0, "rave_east", "site", 80.0),
    ("hot_spring", 256.0, -3256.0, "raven_hot_spring", "site", 60.0),
    ("cold_spring", 2620.0, -3800.0, "whistler_cold_spring", "site", 60.0),
    ("hot_spring", 2050.0, -4600.0, "fernmoor_hot_spring", "site", 60.0),
    ("cold_spring", 2440.0, -4040.0, "tallow_cold_spring", "site", 60.0),
    ("mine_entrance", 1573.0, -2917.0, "copper_mine", "site", 60.0),
    ("stone_ring", 1936.0, -4520.0, "stone_ring", "site", 60.0),
    ("bungee_platform", 732.0, -2723.0, "calder_bungee", "site", 40.0),
]
# The trailer town on East Hills Road: clusters of trailers (W x D).
HILL_TRAILERS = [((2720.0, -2900.0), (56.0, 44.0)), ((2740.0, -2840.0), (50.0, 40.0))]
VILLAGE_WALK = 20.0
VILLAGE_FRONTS = 3
VILLAGE_SHOULDER = 1.5
# Hiker loops: trails this long or longer, the two ways TRAIL_EDGE m in from
# the trail's sides (3.5 m wide: 1.7 m apart).
TRAIL_WALK_MIN = 150.0
TRAIL_EDGE = -0.9
HILL_SEED = 122  # the hill places draw from their own rng: no other lot moves
# Lakes fill their hollows up to a level under the rim (closed basins in
# the ground, tools/hill_design_map.py LAKES): (id, name, centre, level).
HILL_LAKES = [("tallow_lake", "Tallow Lake", (2248.0, -4144.0), 62.0),
              ("fernmoor_pond", "Fernmoor Pond", (1752.0, -4512.0), 42.0)]
LAKE_REACH = 260.0  # how far from its centre a lake's hollow may reach
LAKE_DEPTH = 3.0    # the bed sinks this far under the level, LAKE_SHELF m in from the shore
LAKE_SHELF = 24.0
LAKE_EDGE = 6.0     # the water reaches this far past the shore, under the rising ground
# Streams run down the ground from their sources until a lake, the plain
# or the water: (id, name, source).
HILL_STREAMS = [("raven_creek", "Raven Creek", (560.0, -3330.0)), ("hollin_creek", "Hollin Creek", (1180.0, -3720.0)),
                ("copperback_brook", "Copperback Brook", (2250.0, -3400.0)),
                ("whistler_brook", "Whistler Brook", (2620.0, -3800.0))]
STREAM_W = 2.4
WALL_SHORE = 3  # a lake's shore: an invisible wall (kinds 0-2: _wall_kind)
# Estate house lot (the mansion kit draws house, forecourt and pool in it).
ESTATE_HOUSE = 40.0
TENNIS_BACK = 21.0      # depth behind an estate house for a tennis court across the plot
# A straight-on estate's gatehouse lot (kits/homes_kit.gd): its front this far
# inside the wall, its centre this far right of the drive's axis so the
# kit's lane (the lot's left half) carries the drive. The drive starts behind it.
GATE_IN = 1.0
GATE_LANE = 1.5
# Field cells: 44 m wide on a 50 m pitch (the gaps are the field edges).
FIELD_CELL = 44.0
# Golden Flats farmsteads stand at least this far apart (m).
FLATS_FARM_GAP = 520.0
HOMESTEAD_GAP = 260.0  # a homestead from any other farm or homestead
FIELD_PITCH = 50.0
# Line parts: their w runs along their own x.
LINE_PARTS = ("wall", "hedge", "fence", "gate", "trees")
# Dwellings of the styles whose homes stand in clusters.
CLUSTER_HOMES = {"village": ["house", "house", "shack"], "bayou_village": ["stilt_house", "shack"],
                 "bayou_town": ["stilt_house", "shack", "house"]}
# In those styles a shop or bar stands at least this far from another of its
# kind. A 48-64 m cluster often fails to fit where a 16 m bar still does, and
# the frontage redraws every 4 m, so without it bars filled the gaps: 40 of
# the bayou town's 121 lots (HANDOFF-bellerive-expand BX-6).
CLUSTER_SHOP_GAP = 220.0
# Bellerive's suburbs to city grade (upgrade_lots, HANDOFF-bellerive-expand.md
# BX-5): house pairs merged by land value, poorest first (every 5th a liquor
# store) and richest last; the poorest single east side lots in this order.
UP_CHEAP_PAIRS = 30
UP_EXEC_PAIRS = {"eastside": 12, "heights": 12}
UP_SINGLES = ["bungalow_barred", "pawn_shop", "bungalow_barred", "burned_lot", "bungalow_barred",
              "check_cashing", "bungalow_barred"]
UP_SINGLE_COUNT = 35
UP_FIT = (0.75, 1.27)  # a refitted lot stays within these of its kind's size

# Suburb zones round the street plan (local metres) and what they hold.
SUBURB_STYLE = {
    "heights": {"house": 2, "mansion": 3},
    "bayou_town": {"stilt_house": 4, "shack": 2, "house": 2, "bar": 1},
    "fringe": {"rowhouse_row": 5, "garden_apartments": 1, "strip_mall": 1, "gas_station": 1},
    "eastside": {"house": 5, "garden_apartments": 2, "strip_mall": 1, "gas_station": 1, "diner": 1},
    "beach_town": {"deco_hotel": 5, "condo_tower": 2, "beach_bar": 1, "shopfront": 1},
    "shore": {"house": 5, "garden_apartments": 2, "beach_bar": 1, "diner": 1},
    "town": {"shopfront": 4, "house": 4, "diner": 1, "general_store": 1, "bar": 1, "gas_station": 1, "garage": 1},
    "village": {"house": 5, "general_store": 1, "bar": 1, "trailer_home": 2},
    "bayou_village": {"stilt_house": 4, "shack": 3, "bar": 1, "general_store": 1},
}

# Generic styles the outskirts patterns use for frontage they do not lay
# out themselves: estates along the Heights' winding roads, shops and
# apartments along the east side's arterials, beach trade on the shore.
SUBURB_STYLE.update({
    "estates": {"mansion": 1},
    "arterial": {"garden_apartments": 3, "strip_mall": 2, "diner": 1, "gas_station": 1},
    "beach": {"beach_bar": 3, "diner": 2, "garden_apartments": 2, "shopfront": 2},
    "mountain": {"house": 3, "mansion": 2},
    "hillside": {"house": 4, "exec_house": 2, "mansion": 1},  # by height band in street_lots
})
# The hill districts' homes by height (street_lots): rows and apartments
# low down, houses on the middle terraces, exec houses and mansions on top.
HILL_BANDS = ((40.0, {"rowhouse_row": 3, "painted_lady_row": 2, "garden_apartments": 2, "house": 3}),
              (90.0, {"house": 5, "exec_house": 2}),
              (1e9, {"exec_house": 3, "mansion": 2}))

# --- Bellerive v3 outskirts patterns (HANDOFF-bellerive-v3.md B-4; the
# numbers are reference/world/bellerive_patterns.md "Game use"). Every
# street, lot and plot is derived from the plan's frame junctions and the
# zone bounds, so the patterns follow the plan when its junctions move.
# Magnolia Heights: the Beverly Hills flats near the city (north-south
# streets, 15 x 37 m lots, one kind of street tree to a street, palms on the
# cross streets), then winding estate roads further out.
FLATS_FIRST = 50.0          # the first flats street, out from the plan's edge
FLATS_PITCH = 93.0          # two 37 m lots back to back, their setbacks and a street
FLATS_STREETS = 2
FLATS_LOT = (15.0, 37.0)
FLATS_NAMES = ["Camellia Drive", "Verbena Drive", "Oleander Drive"]
FLATS_TREES = ["magnolia", "jacaranda", "crepe_myrtle", "plane"]
PALM_STEP = 11.0            # palms 10-12 m apart on the showcase streets
VERGE_STEP = 13.0
ESTATE_PITCH = 197.0        # estate roads: a 90 m estate either side, setbacks, the road
ESTATE_WIND = 22.0          # how far an estate road winds off its line
BAYOU_DRIVE_SET = 24.0      # Bayou Drive's centreline back from the water
BAYOU_DRIVE_NAME = "Bayou Drive"
ESTATE_NAMES = ["Palisade Drive", "Corniche Way", "Ombrage Lane", "Belvedere Crest"]
# North fringe: Capitol Hill rowhouse blocks round an H-shaped rear alley.
FRINGE_PITCH = 120.0
FRINGE_ROW_NAME = "Courtland Row"
ROW_DEPTH = 12.0
ROW_TARGET = 36.0
ROW_GAP = 1.6
ALLEY = 9.0
ALLEY_NECK = 4.5
ALLEY_IN = 30.5             # an H alley's legs, in from the block's short ends
# East side: LA arterial superblocks.
ARTERIAL_GAP = 330.0        # least gap between two arterials' exits
ARTERIAL_NAMES = ["Mesquite Avenue", "Verdello Avenue", "Sandpiper Avenue", "Tierra Linda Avenue"]
SPINE_NAME = "Sunvale Boulevard"
ARTERIAL_DEPTH = 77.0       # first street off an arterial: shops 26 m deep, then houses
TRACT_LOT = (15.0, 30.0)
TRACT_PITCH = 79.0          # two 30 m lots back to back, their setbacks and a street
TRACT_PITCH_MIN = 52.0      # closest tract streets (one from each city street): shallower lots
TRACT_LOT_SHALLOW = (15.0, 20.0)
# Sidewalk loops for people (HANDOFF-bellerive-expand.md BX-1).
WALK_ZONES = ("heights", "bayou_town", "fringe", "eastside", "beach_town", "shore", "hillside")
WALK_CLASSES = ("street", "avenue")
WALK_MID = 1.25             # the middle of a 2.5 m sidewalk, out from the road's edge
WALK_BLOCK_MAX = 400000.0   # bigger faces are open country, not blocks
WALK_PART_MIN = 150.0
WALK_SHARE = 0.6            # of a ring that must run along sidewalks
CARRY_MAX = 400.0  # how far a city street carries on out to meet a road
TRACT_ARTERIAL_MIN = 45.0   # closest a tract street from the city runs beside an arterial
TRACT_BOW = 16.0
BULB_R = 13.0               # a cul-de-sac's turning circle (centreline radius)
MALL_LEG = (32.0, 24.0)     # each leg of a corner mini-mall's L
MALL_YARD = 24.0            # the corner square of its parking (all within the 77 m before the first street)
SCHOOL_PLOT = (150.0, 120.0)
DMV_PLOT = (110.0, 85.0)
# South shore: Levittown loops of identical capes, and a village green.
COLLECTOR_PITCH = 400.0
LOOP_PITCH = 80.0
LOOP_STAGGER = 40.0         # lanes either side of a collector are offset: T junctions only
LOOP_BOW = 8.0
LOOP_BEND = 40.0            # a loop's U bend (radius)
LOOP_NAMES = ["Dogwood Lane", "Hollyhock Lane", "Bayberry Lane", "Sweetgum Lane", "Primrose Lane", "Juniper Lane",
              "Foxglove Lane", "Thimble Lane", "Wren Lane", "Clover Lane", "Briar Lane", "Teasel Lane", "Aster Lane",
              "Linnet Lane", "Hazel Lane", "Quince Lane"]
CAPE_PARCEL = (18.0, 30.0)
CAPE_SETBACK = 8.0
# Lot routes (HANDOFF-routes R-1): how far ahead of a lot a road may lie
# for its drive to run out to it, and how far the drive tucks under the road.
REACH_MAX = 18.0
REACH_TUCK = 0.6
# The kinds people live in: every one needs a way in from the road.
HOME_KINDS = ("house", "cape_house", "rowhouse_row", "shack", "stilt_house", "mansion", "garden_apartments",
              "trailer_home", "farmhouse", "farmhouse_big", "farmhouse_small", "ranch_house", "adobe_farmhouse")
GREEN_PLOT = (150.0, 100.0)
SHORE_PITCH_MIN = 60.0      # closest two shore streets from the city run
# Pattern tags a road carries from its source into the graph (pc["tag"]).
PATTERN_WALKS = {"heights": ("flats",), "eastside": ("tract", "bulb"),
                 "shore": ("loop", "stub", "bulb", "collector", "beltway")}
# The hill districts (#116 stage C, HANDOFF-hill-districts): terraced
# streets along the contours of the range's lower slopes north of the city.
HILL_BOX = (120.0, -1260.0, 2320.0, -260.0)  # where they can lie (local m)
HILL_CELL = 8.0             # height grid they are planned on
HILL_BLUR = 4.0             # cells: the grid is smoothed so contours run easy
HILL_TOP = 180.0            # no hill street higher than this (smoothed m)
HILL_SLOPE = 0.35           # nor where the smoothed ground is steeper
HILL_PART_MIN = 40000.0     # smallest piece of land worth a district (m2)
HILL_PITCH = 76.0           # between two terraces (two lot depths)
HILL_RUN = 120.0            # shortest terrace
HILL_REACH = 70.0           # a terrace end carries on along its contour this far to meet a road
HILL_CONNECT = 0.10         # grade the climbs are traced at on the smoothed ground (street cap
                            # 0.13: each street is graded on its own ground, so they come out steeper)
HILL_GRADE = 0.12           # hill streets are graded to this (the 0.13 cap less the grid's excess)
HILL_RISE = 0.11            # most a climb may rise end to end over its length (its ends are pinned:
                            # the terrace on the ground, a mountain road at its graded height)
# A few short, steep climbs for variety, as real hill towns have: most of San
# Francisco's streets keep under ~10 %, a few blocks run 20-31 % (Filbert St,
# 22nd St); Los Angeles' Eldred St 33 %, Pittsburgh's Canton Ave 37 %. Ours
# stay at the mild end of those, a block or two long.
HILL_STEEP = 0.20           # their cap (graded to it less the grid's excess, as HILL_GRADE)
HILL_STEEP_RISE = 0.18      # most such a climb rises end to end
HILL_STEEP_LEN = 160.0      # longest such a climb (m)
HILL_STEEP_MAX = 6          # how many
HILL_STEEP_EVERY = 4        # every so many climb starts tries straight up the slope at HILL_STEEP_RISE
HILL_PAD_TOL = 0.2          # a hill home's pad: most its back and sides may lie off level (m)
HILL_GAP = 220.0            # between a terrace's climbs
HILL_NAMES = ["Toyon Terrace", "Sagewood Terrace", "Manzanita Crest", "Columbine Terrace", "Buckeye Drive",
              "Chamise Terrace", "Kestrel Crest", "Madrone Drive", "Yarrow Terrace", "Sumac Crest",
              "Ceanothus Drive", "Fennel Terrace", "Holly Crest", "Tanoak Drive", "Lupine Terrace",
              "Vista Point Drive", "Swift Crest", "Poppy Terrace", "Elderberry Drive", "Wildrye Terrace",
              "Thrasher Crest", "Bluff View Drive", "Corona Terrace", "Pinnacle Drive", "Saltbush Terrace",
              "Owlwood Crest", "Halo Drive", "Quail Run Terrace", "Starview Drive", "Brodiaea Terrace"]
HILL_CLIMB_NAMES = ["Talus Way", "Scree Rise", "Cobble Way", "Flint Rise", "Shale Way", "Quartz Rise", "Mica Way",
                    "Jasper Rise", "Agate Way", "Basalt Rise", "Chert Way", "Slate Rise", "Opal Way", "Garnet Rise",
                    "Topaz Way", "Beryl Rise", "Pumice Way", "Obsidian Rise", "Feldspar Way", "Onyx Rise",
                    "Tuff Way", "Gypsum Rise", "Arroyo Way", "Gully Rise", "Cliffrose Way", "Roadrunner Rise",
                    "Overlook Way", "Harrier Rise", "Lookout Way", "Tumble Rise", "Ember Way", "Scrub Jay Rise"]

# Ground zones, in drawing order; the game colours them (country_tiles.gd).
ZONES = ["land", "farmland", "bayou", "hills", "heights", "bayou_town", "fringe", "eastside",
         "beach_town", "shore", "town", "sand", "far_desert", "far_mountains", "far_forest",
         "far_lakeside", "far_parkland", "far_military", "far_land", "mountain"] + farmland.ZONES + ["hillside"]


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    if sys.argv[1] == "--urban":
        write_urban()
        return
    plan = json.loads(Path(sys.argv[1]).read_text())
    world = json.loads(WORLD.read_text())
    gen = Country(world, plan)
    gen.run()
    data = gen.export()
    OUT.write_text(json.dumps(data, separators=(",", ":")))
    print("country.json: %d KB, %d nodes, %d edges, %d roads, %d lots, %d tiles, %d walls, %d barricades, %d links"
          % (OUT.stat().st_size // 1024, len(data["nodes"]), len(data["edges"]), len(data["roads"]),
             len(data["lots"]), len(data["tiles"]), len(data["walls"]), len(data["barricades"]),
             len(data["links"])))
    gen.report()


# --- Geometry helpers ------------------------------------------------------------

def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def unit(v):
    n = math.hypot(v[0], v[1]) or 1.0
    return (v[0] / n, v[1] / n)


def densify(pts, step):
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        n = max(1, math.ceil(dist(a, b) / step))
        for k in range(1, n + 1):
            t = k / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def chaikin(pts, rounds):
    """Corner cutting: each round replaces every corner by two points a
    quarter and three quarters along its sides (the ends stay)."""
    for _ in range(rounds):
        out = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            out += [(a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25), (a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75)]
        pts = out + [pts[-1]]
    return pts


def fillet(pts, radius, step):
    """Rounds each corner of a polyline with a quadratic curve."""
    if len(pts) < 3:
        return densify(pts, step)
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, b, c = pts[i - 1], pts[i], pts[i + 1]
        la, lc = dist(a, b), dist(b, c)
        if la < 1e-6 or lc < 1e-6:
            continue
        d = min(radius, 0.45 * la, 0.45 * lc)
        p0 = (b[0] + (a[0] - b[0]) / la * d, b[1] + (a[1] - b[1]) / la * d)
        p1 = (b[0] + (c[0] - b[0]) / lc * d, b[1] + (c[1] - b[1]) / lc * d)
        n = max(2, int(d / 6))
        for k in range(n + 1):
            t = k / n
            out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * b[0] + t * t * p1[0],
                        (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * b[1] + t * t * p1[1]))
    out.append(pts[-1])
    return densify(out, step)


def resample(line: LineString, step: float):
    n = max(1, math.ceil(line.length / step))
    return [line.interpolate(line.length * k / n).coords[0] for k in range(n + 1)]


def min_radius(line: LineString):
    """The tightest bend of a line (m), its ends left out; inf when straight."""
    if line.length < 20.0:
        return math.inf
    pts = resample(line, 4.0)
    best = math.inf
    for i in range(3, len(pts) - 3):
        a, b, c = pts[i - 1], pts[i], pts[i + 1]
        t0 = math.atan2(b[1] - a[1], b[0] - a[0])
        t1 = math.atan2(c[1] - b[1], c[0] - b[0])
        turn = abs((t1 - t0 + math.pi) % math.tau - math.pi)
        if turn > 1e-4:
            best = min(best, dist(a, c) * 0.5 / turn)
    return best


def wavy(a, b, amp, halves=1, step=6.0):
    """Points from a to b bowed (halves 1) or snaking (2) off the straight
    line by up to amp metres; offset and slope are zero at both ends, so it
    meets the roads there square on."""
    L = dist(a, b)
    if L < 1e-6:
        return [a, b]
    u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
    v = (-u[1], u[0])
    n = max(2, math.ceil(L / step))
    pts = []
    for k in range(n + 1):
        t = k / n
        f = math.sin(math.pi * t) ** 2 if halves == 1 else math.sin(halves * math.pi * t) * math.sin(math.pi * t)
        pts.append((a[0] + u[0] * L * t + v[0] * amp * f, a[1] + u[1] * L * t + v[1] * amp * f))
    return pts


def bow_y(x, y, amp, xa, xb):
    """y bowed by amp sin^2 over [xa, xb] (zero slope at both ends)."""
    t = min(1.0, max(0.0, (x - xa) / (xb - xa)))
    return y + amp * math.sin(math.pi * t) ** 2


def bowed(x0, x1, y, amp, xa, xb, step=6.0):
    n = max(2, math.ceil(abs(x1 - x0) / step))
    return [(x0 + (x1 - x0) * k / n, bow_y(x0 + (x1 - x0) * k / n, y, amp, xa, xb)) for k in range(n + 1)]


def ring_arcs(c, r, a0, parts=3, step=4.0):
    """A circle round c as `parts` arcs from angle a0 on; the graph drops a
    closed piece (a loop on one junction), so it goes in as arcs."""
    out = []
    n = max(3, math.ceil(r * math.tau / parts / step))
    for k in range(parts):
        out.append([(c[0] + r * math.cos(a0 + math.tau * (k + i / n) / parts),
                     c[1] + r * math.sin(a0 + math.tau * (k + i / n) / parts)) for i in range(n + 1)])
    return out


def arc(c, r, a0, a1, step=4.0):
    n = max(3, math.ceil(r * abs(a1 - a0) / step))
    return [(c[0] + r * math.cos(a0 + (a1 - a0) * i / n), c[1] + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


def lines_of(geom):
    if geom.is_empty:
        return []
    if geom.geom_type == "LineString":
        return [geom]
    if hasattr(geom, "geoms"):
        out = []
        for g in geom.geoms:
            out.extend(lines_of(g))
        return out
    return []


def polys_of(geom):
    if geom.is_empty:
        return []
    if geom.geom_type == "Polygon":
        return [geom]
    if hasattr(geom, "geoms"):
        out = []
        for g in geom.geoms:
            out.extend(polys_of(g))
        return out
    return []


def bezier(p0, c0, c1, p1, step):
    pts = []
    n = max(4, int((dist(p0, c0) + dist(c0, c1) + dist(c1, p1)) / step))
    for k in range(n + 1):
        t = k / n
        u = 1 - t
        pts.append((u ** 3 * p0[0] + 3 * u * u * t * c0[0] + 3 * u * t * t * c1[0] + t ** 3 * p1[0],
                    u ** 3 * p0[1] + 3 * u * u * t * c0[1] + 3 * u * t * t * c1[1] + t ** 3 * p1[1]))
    return pts


def lot_poly(x, y, yaw, w, d):
    # Lot frame: x along the street, -z towards it. yaw as Godot's
    # Basis(UP, yaw): local x -> (cos, -sin), local z -> (sin, cos).
    c, s = math.cos(yaw), math.sin(yaw)
    pts = []
    for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)):
        pts.append((x + lx * c + lz * s, y - lx * s + lz * c))
    return Polygon(pts)


def yaw_facing(nx, ny):
    """Yaw of a lot whose street lies in direction -(nx, ny) from it... i.e.
    whose front (-Z) points along (-nx, -ny)."""
    return math.atan2(nx, ny)


def frame_point(c, yaw, lx, lz):
    """A point of a lot or plot frame in local metres."""
    cs, sn = math.cos(yaw), math.sin(yaw)
    return (c[0] + lx * cs + lz * sn, c[1] - lx * sn + lz * cs)


def part(kind, x, z, w, d, rot=0.0, variant=0):
    return [kind, x, z, w, d, rot, variant]


def seg_part(kind, a, b, thick, variant=0):
    """A line part from a to b (plot frame)."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    # Its own x runs along a -> b: Basis(UP, rot) takes x to (cos, -sin).
    return part(kind, (a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5, math.hypot(dx, dz), thick, math.atan2(-dz, dx), variant)


def rect_part_poly(p):
    """The footprint of a rect part in the plot frame."""
    return lot_poly(p[1], p[2], p[5], p[3], p[4])


class PolyGrid:
    """Polygons binned by every 50 m cell their bounds touch."""

    def __init__(self, cell=50.0):
        self.cell = cell
        self.cells = {}

    def _keys(self, poly):
        x0, y0, x1, y1 = poly.bounds
        c = self.cell
        return [(gx, gy) for gx in range(math.floor(x0 / c), math.floor(x1 / c) + 1)
                for gy in range(math.floor(y0 / c), math.floor(y1 / c) + 1)]

    def hits(self, poly):
        for k in self._keys(poly):
            for o in self.cells.get(k, ()):
                if o.intersects(poly):
                    return True
        return False

    def add(self, poly):
        for k in self._keys(poly):
            self.cells.setdefault(k, []).append(poly)


# --- The urban outline (--urban) ----------------------------------------------------

# How far the suburbs reach past the core by compass bearing (degrees; 0 is
# east, 90 south), times the scale write_urban settles on: furthest to the
# north-east along the Gulf Highway, least where the hills and the Gulf
# close in.
URBAN_REACH = [(0, 560), (30, 640), (60, 560), (90, 330), (120, 260), (150, 300), (180, 420), (210, 430),
               (240, 380), (270, 190), (300, 230), (330, 470), (360, 560)]
# Fingers of town out along roads: (route, bearing it leaves on, how far).
URBAN_FINGERS = [("Route 1 Gulf Highway", 325.0, 660.0)]


def _urban_reach(deg):
    deg %= 360.0
    for (a0, d0), (a1, d1) in zip(URBAN_REACH, URBAN_REACH[1:]):
        if a0 <= deg <= a1:
            t = (deg - a0) / (a1 - a0)
            t = t * t * (3.0 - 2.0 * t)
            return d0 + (d1 - d0) * t
    return URBAN_REACH[0][1]


def draft_urban(world):
    """Bellerive's urban outline (local metres): the core grown by a star of
    URBAN_REACH and URBAN_FINGERS, kept off the Gulf, the hills and the
    water, scaled so it covers the city rect's area (or the core alone if
    that is already bigger). Returns (polygon, scale, target area)."""
    city = next(c for c in world["cities"] if c["id"] == "bellerive")
    o = city["demo_window"]["origin"]

    def loc(pts):
        return [(x - o[0], y - o[1]) for x, y in pts]

    water = []
    for wt in world["water"]:
        if "polygon" in wt:
            water.append(Polygon(loc(wt["polygon"])))
        elif wt["type"] in ("river", "creek"):
            water.append(LineString(loc(wt["line"])).buffer(wt["width"] * 0.5, cap_style="flat", join_style="round"))
    water = unary_union(water)
    gulf = Polygon(loc(world["water"][0]["polygon"]))
    mtn = Mountain().poly
    core = Polygon(loc(city["core"])).buffer(0)
    c0 = core.centroid
    n = 240
    reach = []
    for k in range(n):
        a = math.tau * k / n
        far = LineString([(c0.x, c0.y), (c0.x + 8000.0 * math.cos(a), c0.y + 8000.0 * math.sin(a))]).intersection(core.exterior)
        reach.append(max((c0.distance(g) for g in getattr(far, "geoms", [far])), default=0.0) if not far.is_empty else 0.0)
    # The core's own edge is jagged: its reach averaged over +-15 degrees.
    reach = [max(reach[k], sum(reach[(k + j) % n] for j in range(-10, 11)) / 21.0) for k in range(n)]
    fingers = []
    for name, bearing, length in URBAN_FINGERS:
        line = LineString(loc(next(rt["line"] for rt in world["routes"] if rt["name"] == name)))
        for piece in lines_of(line.intersection(core.buffer(length)).difference(core)):
            m = piece.interpolate(0.5, normalized=True)
            b = math.degrees(math.atan2(m.y - c0.y, m.x - c0.x)) % 360.0
            if abs((b - bearing + 180.0) % 360.0 - 180.0) < 40.0:
                fingers.append(piece)
    fingers = unary_union(fingers)

    def outline(scale):
        pts = []
        for k in range(n):
            a = math.tau * k / n
            # A soft wobble so the edge is no even offset.
            r = reach[k] + scale * _urban_reach(math.degrees(a)) + scale * 40.0 * math.sin(3.0 * a + 0.7)
            pts.append((c0.x + r * math.cos(a), c0.y + r * math.sin(a)))
        s = Polygon(pts).buffer(0).union(core.buffer(40.0)).difference(gulf).difference(mtn)
        land = s.difference(water)
        u = unary_union([g for g in polys_of(land) if g.intersects(core.difference(water)) and g.area > 20000.0])
        u = u.buffer(130.0).buffer(-130.0).intersection(s)
        u = u.buffer(-130.0).buffer(130.0)  # spikes rounded off
        if not fingers.is_empty:
            f = fingers.buffer(110.0 + 60.0 * scale).difference(gulf).difference(mtn).difference(water)
            u = u.union(f).buffer(70.0).buffer(-70.0)
        u = unary_union([u, core.difference(gulf)])
        u = max(polys_of(u), key=lambda g: g.area)
        return Polygon(u.exterior).simplify(6.0)

    target = city["rect"][2] * city["rect"][3]
    lo, hi = 0.3, 2.5
    if outline(lo).area >= target:
        hi = lo
    else:
        for _ in range(18):
            mid = (lo + hi) * 0.5
            if outline(mid).area < target:
                lo = mid
            else:
                hi = mid
    scale = (lo + hi) * 0.5 if hi > lo else lo
    return outline(scale), scale, target


def write_urban():
    """Rewrites world_map.json's Bellerive "urban" (world metres) from
    draft_urban, leaving the rest of the file as it is."""
    text = WORLD.read_text()
    world = json.loads(text)
    u, scale, target = draft_urban(world)
    o = next(c for c in world["cities"] if c["id"] == "bellerive")["demo_window"]["origin"]
    urban = [[round(x + o[0]), round(y + o[1])] for x, y in u.exterior.coords[:-1]]
    lines = text.split("\n")
    k = next(i for i, l in enumerate(lines) if l.lstrip().startswith('{"id": "bellerive"'))
    line = lines[k]
    body = line.strip()
    comma = body.endswith(",")
    city = json.loads(body.rstrip(","))
    city["urban"] = urban
    indent = line[:len(line) - len(line.lstrip())]
    lines[k] = indent + json.dumps(city, ensure_ascii=False) + ("," if comma else "")
    WORLD.write_text("\n".join(lines))
    b = u.bounds
    print("urban: scale %.3f, %.2f km2 (target %.2f), %d points, fills %.3f of its bbox" % (
        scale, u.area / 1e6, target / 1e6, len(urban), u.area / ((b[2] - b[0]) * (b[3] - b[1]))))


class Country:
    def __init__(self, world, plan):
        self.world = world
        self.plan = plan
        city = next(c for c in world["cities"] if c["id"] == "bellerive")
        win = city["demo_window"]
        self.origin = (win["origin"][0], win["origin"][1])
        self.city = city
        r = city["rect"]
        self.city_rect = box(r[0] - self.origin[0], r[1] - self.origin[1], r[0] + r[2] - self.origin[0], r[1] + r[3] - self.origin[1])
        self.rng = random.Random(1234)
        self.house_decks = {}
        self.home_sizes = collections.Counter()  # farm homes built per kind (their sizes cycle)
        self.sources = []  # [LineString, cls, name, kind] drivable or trail
        self.render_only = []  # roads beyond the play area: [LineString, cls]
        self.rails = []  # [LineString, kind]
        self.lots = []  # dicts
        self.lot_polys = []
        self.barricades = []
        self.paths = []  # driveways (render only)
        self.zones = []  # (name, polygon)
        self.town_zones = []
        self.links = []
        self.bulbs = []  # cul-de-sac centres
        self.flat_bulbs = []  # [turning circle's arcs, street end]: a hill one is cut and filled level
        self.reserved = []  # civic plots kept clear of streets: dicts (school, DMV, green)
        self.pier = None
        self.arterials = []  # east side: [LineString, "h" or "v"]
        self.flats_rings = []  # the Heights' ring streets, inner first
        self.spine = None
        self.lead_fail = []  # roads that found no exit: (name, x, y)
        self.view_turns = 0  # estate houses turned to a view
        self.mtn = Mountain()
        self.terrain = None

    def L(self, pts):
        return [(x - self.origin[0], y - self.origin[1]) for x, y in pts]

    # --- Areas ------------------------------------------------------------------

    def areas(self):
        w = self.world
        world_box = box(-self.origin[0], -self.origin[1], w["size"][0] - self.origin[0], w["size"][1] - self.origin[1])
        water = []
        for wt in w["water"]:
            if "polygon" in wt:
                water.append(Polygon(self.L(wt["polygon"])))
            elif wt["type"] in ("river", "creek"):
                water.append(LineString(self.L(wt["line"])).buffer(wt["width"] * 0.5, cap_style="flat", join_style="round"))
        self.gulf = Polygon(self.L(w["water"][0]["polygon"]))
        self.water = unary_union(water)
        self.P = self._footprint()
        self.P_in = self.P.buffer(-3.0)
        self.urban = Polygon(self.L(self.city["urban"])).buffer(0)
        self._exits()
        regs = [Polygon(self.L(r["polygon"])) for r in w["regions"] if r.get("phase") == 2]
        rp = next((r for r in w["regions"] if r.get("id") == "red_pine"), None)
        self.red_pine_poly = Polygon(self.L(rp["polygon"])) if rp else Point(1e9, 1e9).buffer(1.0)
        self.red_pine = prep(self.red_pine_poly)
        # The city rect, grown to the footprint's box where the core reaches
        # past it; the shore between it and the Gulf belongs to the city.
        self.city_rect = box(*unary_union([self.city_rect, self.P.envelope]).bounds)
        cx0, cy0, cx1, cy1 = self.city_rect.bounds
        shore = box(cx0 - 100, cy1 - 100, cx1 + 200, cy1 + 700)
        # The whole range is played (Mount Calder and its ridges reach north
        # into Red Pine, phase 3: only the ground, roads, forest and summit).
        a = unary_union(regs + [self.city_rect, self.urban, self.P, shore, self.mtn.poly]).buffer(300).buffer(-300)
        a = Polygon(a.exterior)
        # One piece: a corner of the shore box past the Gulf is dropped.
        self.A = max(polys_of(a.difference(self.gulf)), key=lambda g: g.area)
        self.outer = self.A.buffer(BEYOND).intersection(world_box)
        self.land = self.outer.difference(self.water).difference(self.P)
        self.play_land = self.A.difference(self.water).difference(self.P)
        self.play_land_prep = prep(self.play_land.buffer(-0.5))
        self.water_prep = prep(self.water)
        self.A_prep = prep(self.A)
        self.coast = LineString(self.L(w["water"][0]["polygon"]))

    def _footprint(self):
        """The city's footprint: the plan's edge loops grown FRAME_IN (mitred,
        so its corners stay square to the streets), with the river reach
        between its banks and the slivers of bank between its edge streets
        and the water, so the country lays no ground or walls in the city."""
        loops = [Polygon(l).buffer(FRAME_IN, join_style="mitre") for l in self.plan["edge_loops"]]
        fp = unary_union(loops)
        core = Polygon(self.L(self.city["core"]))
        river = self.water.intersection(core).intersection(fp.buffer(100.0))
        g = unary_union([fp, river])
        closed = g.buffer(15.0).buffer(-15.0)
        banks = closed.difference(g).intersection(self.water.buffer(16.0))
        g = unary_union([g, banks]).buffer(0)
        g = max(polys_of(g), key=lambda q: q.area)
        return Polygon(g.exterior)

    def _exits(self):
        """The plan's exits a country road can join: each a kept junction on
        the edge whose cut street left the city along `d` (river exits, the
        quays, are left out). The country road meets it at `e`, FRAME_IN out."""
        nodes = self.plan["nodes"]
        self.exits = []
        for n, dx, dy, cls, road in self.plan["exits"]:
            if cls == "river" or CITY_RANK.get(cls, 0) == 0:
                continue
            p = tuple(nodes[n])
            e = (p[0] + dx * FRAME_IN, p[1] + dy * FRAME_IN)
            out = (p[0] + dx * 30.0, p[1] + dy * 30.0)
            self.exits.append({"n": n, "p": p, "d": (dx, dy), "e": e, "rank": CITY_RANK[cls], "cls": cls, "road": road,
                               "open": not self.water.contains(Point(out)) and not self.gulf.contains(Point(out)),
                               "used": False})

    def _link(self, ex):
        ex["used"] = True
        self.links.append({"pos": ex["e"], "plan_node": ex["n"]})

    def _exit_at(self, p, tol=2.0):
        return next((ex for ex in self.exits if dist(ex["e"], p) < tol), None)

    # --- Roads ------------------------------------------------------------------

    def add(self, pts, cls, name, kind="route"):
        if len(pts) < 2:
            return
        line = LineString(pts)
        if line.length < 1.0:
            return
        self.sources.append([line, cls, name, kind])

    def routes(self):
        clip = self.A.difference(self.P)
        for rt in self.world["routes"]:
            t = rt["type"]
            pts = self.L(rt["line"])
            if t in RAIL_TYPES:
                line = LineString(fillet(pts, 300.0, 20.0))
                for piece in lines_of(line.intersection(self.outer.difference(self.P))):
                    self.rails.append([piece, RAIL_TYPES[t], rt["name"], rt.get("phase", 1)])
                continue
            if t not in CLASSES:
                continue
            self._route(pts, t, rt["name"], clip)

    def _route(self, pts, t, name, clip):
        """A map route: driven inside the play area, drawn past it, with a
        storm barricade where it leaves. Where it reaches the city, or ends
        short of it, it is led in to an exit (_to_exit)."""
        c = CLASSES[t]
        line = LineString(fillet(pts, c["r"], 8.0))
        edge = self.P.exterior
        # The route's own ends that stop short of the city.
        loose = [q for q in (line.coords[0], line.coords[-1])
                 if not self.P.contains(Point(q)) and self.P.distance(Point(q)) < LEAD_SHORT]
        for piece in lines_of(line.intersection(clip)):
            on = [edge.distance(Point(piece.coords[k])) < 1.0 for k in (0, -1)]
            # A short cut across a corner of the city between two touches.
            if on[0] and on[1] and piece.length < 300.0:
                continue
            if on[0] or on[1] or loose:
                piece = self._to_exit(piece, t, name, loose)
            self.add(list(piece.coords), t, name)
        # Past the play area: drawn, not driven; a storm barricade where
        # the road leaves it.
        for piece in lines_of(line.intersection(self.outer.difference(self.A).difference(self.P))):
            if piece.length > 5.0:
                self.render_only.append([piece, t])
        for hit in self._points(line.intersection(self.A.exterior)):
            if self.water_prep.contains(Point(hit).buffer(2.0)) or self.gulf.distance(Point(hit)) < 30.0:
                continue
            self._barricade(line, hit, c["w"])

    def _to_exit(self, piece, cls, name, loose=()):
        """Each end of a road piece that stops on the footprint, or is one of
        the `loose` ends that stop short of it, is led in to an exit
        (_lead_in); one that finds none is noted in lead_fail."""
        edge = self.P.exterior
        pts = list(piece.coords)
        for end in (0, -1):
            on = edge.distance(Point(pts[end])) <= 1.0
            if not on and not any(dist(pts[end], q) < 1.0 for q in loose):
                continue
            line = LineString(pts if end == -1 else pts[::-1])
            new = self._lead_in(line, cls) if on else self._lead_in(line, cls, (0.0, 40.0, 80.0))
            if new is None:
                self.lead_fail.append((name, round(pts[end][0]), round(pts[end][1])))
                continue
            pts = new if end == -1 else new[::-1]
        return LineString(pts)

    def _lead_in(self, line, cls, reaches=(160.0, 240.0, 100.0, 320.0)):
        """A road that ends on the footprint, its last stretch swapped for a
        curve that arrives at the best free exit along the exit's outward
        direction: near the end, of a high rank (a highway takes an avenue
        or boulevard if it can), and turning little. The curve keeps out of
        the city and the water and bends no tighter than the class allows.
        Returns the new points (the exit linked), or None."""
        r_min = min(CLASSES[cls]["r"], 120.0) * 0.4
        end = line.coords[-1]
        L = line.length
        ranks = (15, 1) if cls in ("freeway", "highway") else (1,)
        for min_rank in ranks:
            for reach in reaches:
                keep = L - reach
                if keep <= 8.0:
                    head, keep = [line.coords[0]], 0.0
                else:
                    head = [line.interpolate(k).coords[0] for k in _steps(0.0, keep, 8.0)]
                    last = line.interpolate(keep).coords[0]
                    if dist(head[-1], last) > 0.5:
                        head.append(last)
                q, t = _along(line, keep)
                wet0 = self.water.intersection(substring(line, keep, L)).length
                cands = []
                for ex in self.exits:
                    if ex["used"] or not ex["open"] or ex["rank"] < min_rank:
                        continue
                    e, d = ex["e"], ex["d"]
                    de = dist(end, e)
                    if de > 400.0 or dist(q, e) < 10.0:
                        continue
                    v = (q[0] - e[0], q[1] - e[1])
                    if (d[0] * v[0] + d[1] * v[1]) / math.hypot(*v) <= 0.2:
                        continue
                    turn = math.acos(max(-1.0, min(1.0, -(t[0] * d[0] + t[1] * d[1]))))
                    cands.append((de - 3.0 * ex["rank"] + 60.0 * turn, ex["n"], ex["d"], ex))
                cands.sort(key=lambda c: c[:3])
                for _, _, _, ex in cands:
                    e, d = ex["e"], ex["d"]
                    span = max(30.0, 0.4 * dist(q, e))
                    tail = bezier(q, (q[0] + t[0] * span, q[1] + t[1] * span), (e[0] + d[0] * span, e[1] + d[1] * span), e, 6.0)
                    tl = LineString(tail)
                    if tl.intersects(self.P_in):
                        continue
                    if self.water.intersection(tl).length > wet0 + 5.0:
                        continue
                    if min_radius(tl) < r_min:
                        continue
                    self._link(ex)
                    return head[:-1] + tail
        return None

    @staticmethod
    def _points(geom):
        if geom.is_empty:
            return []
        if geom.geom_type == "Point":
            return [geom.coords[0]]
        out = []
        for g in getattr(geom, "geoms", []):
            if g.geom_type == "Point":
                out.append(g.coords[0])
        return out

    def _barricade(self, line, hit, width):
        s = line.project(Point(hit))
        a = line.interpolate(max(0.0, s - 2.0)).coords[0]
        b = line.interpolate(min(line.length, s + 2.0)).coords[0]
        d = (b[0] - a[0], b[1] - a[1])
        n = math.hypot(*d) or 1.0
        d = (d[0] / n, d[1] / n)
        # Step back inside the play area.
        for sgn in (1.0, -1.0):
            p = (hit[0] - d[0] * sgn * 8.0, hit[1] - d[1] * sgn * 8.0)
            if self.A_prep.contains(Point(p)):
                self.barricades.append([round(p[0], 2), round(p[1], 2), round(d[0], 4), round(d[1], 4), width])
                return

    # --- Exits and rings round the footprint ---------------------------------------

    def _ring(self, d, smooth=60.0):
        """The line d m out from the footprint all round, its inside corners
        rounded `smooth` m, so streets on it follow the city's shape."""
        g = self.P.buffer(d + smooth).buffer(-smooth)
        return LineString(max(polys_of(g), key=lambda q: q.area).exterior.coords)

    def _exits_into(self, zone, reach=20.0):
        """Free exits whose street leaves the city into zone."""
        zp = prep(zone)
        return [ex for ex in self.exits if ex["open"] and not ex["used"]
                and zp.contains(Point(ex["e"][0] + ex["d"][0] * reach, ex["e"][1] + ex["d"][1] * reach))]

    @staticmethod
    def _spread(exits, gap, gap_major):
        """Exits at least `gap` apart (an avenue or boulevard `gap_major`
        from those already chosen), the higher ranks chosen first."""
        chosen = []
        for ex in sorted(exits, key=lambda x: (-x["rank"], x["n"], x["d"])):
            g = gap_major if ex["rank"] >= 15 else gap
            if all(dist(ex["e"], c["e"]) >= g for c in chosen):
                chosen.append(ex)
        return chosen

    def _ray_to(self, e, d, stop, far=1500.0, skip=5.0):
        """The first point of `stop` straight out from e along d, or None."""
        if stop is None or stop.is_empty:
            return None
        return self._first_hit((e[0] + d[0] * skip, e[1] + d[1] * skip), (e[0] + d[0] * far, e[1] + d[1] * far), stop)

    def _outward(self, p, t):
        """The normal to t at p that points away from the footprint."""
        n = (-t[1], t[0])
        a = self.P.distance(Point(p[0] + n[0] * 5.0, p[1] + n[1] * 5.0))
        b = self.P.distance(Point(p[0] - n[0] * 5.0, p[1] - n[1] * 5.0))
        return n if a >= b else (-n[0], -n[1])

    def _pick_exit(self, orig, p1, min_rank):
        """The exit a road that used to start at orig and runs on to p1
        starts from: near orig, high rank, its street pointing at p1."""
        best = None
        for ex in self.exits:
            if ex["used"] or not ex["open"] or ex["rank"] < min_rank:
                continue
            e, d = ex["e"], ex["d"]
            v = (p1[0] - e[0], p1[1] - e[1])
            c = (d[0] * v[0] + d[1] * v[1]) / (math.hypot(*v) or 1.0)
            if c <= 0.3:
                continue
            key = (dist(e, orig) - 3.0 * ex["rank"] + 60.0 * math.acos(min(1.0, c)), ex["n"], ex["d"])
            if best is None or key < best[0]:
                best = (key, ex)
        return best[1] if best else None

    def suburbs(self):
        """Bellerive's suburbs fill the urban outline round the footprint,
        each zone a sector or band of it; the Beltway rings the outline
        BELT_OFF out, smoothed, from Seabreeze Drive in the west round the
        north to Seabreeze Drive in the east."""
        land = self.play_land
        core = Polygon(self.L(self.city["core"]))
        c0 = core.centroid.coords[0]
        self.c0 = c0
        S = self.urban.difference(self.P).intersection(land)
        U = unary_union([self.urban, self.P.buffer(10.0)])
        g = U.buffer(BELT_OFF + BELT_SMOOTH).buffer(-BELT_SMOOTH)
        belt_poly = Polygon(max(polys_of(g), key=lambda q: q.area).exterior)
        self.belt_poly = belt_poly
        belt_strip = belt_poly.difference(self.urban).difference(self.P).intersection(land)
        ring = list(belt_poly.exterior.coords)[:-1]
        k0 = max(range(len(ring)), key=lambda k: (ring[k][1], ring[k][0]))
        loop = ring[k0:] + ring[:k0] + [ring[k0]]

        def sector(a0, a1):
            pts = [c0] + [(c0[0] + 8000.0 * math.cos(math.radians(a)), c0[1] + 8000.0 * math.sin(math.radians(a)))
                          for a in range(int(a0), int(a1) + 1)]
            return Polygon(pts)

        # Brisa Beach: a band along the Gulf east of the river mouth.
        coast_e = LineString(self.L([[7600, 8650], [8400, 8000], [8900, 7300]]))
        beach = coast_e.buffer(400.0, cap_style="flat").intersection(box(1450.0, -3000.0, 5000.0, 5000.0))
        # The shore: south of the Morrow, from where it turns east to its mouth.
        morrow = self.L(next(wt for wt in self.world["water"] if wt.get("id") == "morrow")["line"])
        i0 = min(range(len(morrow)), key=lambda i: dist(morrow[i], (-750.0, 650.0)))
        riv = morrow[i0:]
        mouth = riv[-1]
        south = Polygon(riv + [(mouth[0], 4000.0), (-4000.0, 4000.0), (-4000.0, riv[0][1])]).buffer(0)
        west = sector(90, 235)
        # Magnolia Heights lies north of the Gulf Highway, Blackwater Bayou south.
        r1 = next(self.L(rt["line"]) for rt in self.world["routes"] if rt["name"] == "Route 1 Gulf Highway")
        r1w = sorted([p for p in r1 if p[0] < c0[0]])
        north_of = Polygon(r1w + [(c0[0], r1w[-1][1]), (c0[0], -8000.0), (r1w[0][0], -8000.0)]).buffer(0)
        shapes = [("mountain", self.mtn.poly), ("beach_town", beach), ("shore", south.difference(beach)),
                  ("eastside", sector(-55, 90)), ("fringe", sector(-125, -55)),
                  ("heights", west.intersection(north_of)), ("bayou_town", west.difference(north_of))]
        taken = Polygon()
        strip_taken = Polygon()
        self.zone_strip = {}
        for name, shape in shapes:
            poly = shape.intersection(land) if name == "mountain" else S.intersection(shape)
            poly = unary_union([q for q in polys_of(poly.difference(taken)) if q.area >= 500.0])
            taken = taken.union(poly)
            self.zones.append((name, poly))
            st = belt_strip.intersection(shape).difference(strip_taken)
            strip_taken = strip_taken.union(st)
            self.zone_strip[name] = st
        self.zone_poly = dict(self.zones)
        # Map landmarks out here: civic grounds keep clear of them.
        self.lm_pts = []
        for lm in self.world["landmarks"]:
            if lm["id"] in LANDMARK_KIND and lm.get("phase", 1) <= 2:
                q = self.L([lm["pos"]])[0]
                if not self.P.contains(Point(q)):
                    self.lm_pts.append(q)
        # Gulf Shore Drive and Seabreeze Drive: the coast 90 m inland, inside
        # the Beltway, over the river mouth.
        coast = LineString(self.L([[5000, 8590], [5600, 8650], [7600, 8650], [8400, 8000], [8780, 7470]]))
        # Whichever side of the coast is land.
        drive = coast.offset_curve(90.0, join_style="round")
        if self.gulf.contains(drive.interpolate(0.5, normalized=True)):
            drive = coast.offset_curve(-90.0, join_style="round")
        drive_full = LineString(fillet(list(drive.coords), 80.0, 8.0))
        drive = drive_full.intersection(belt_poly.buffer(0.5)).intersection(self.A).difference(self.P.buffer(60.0))
        kept = [piece for piece in lines_of(drive) if piece.length > 60.0]
        # The cross streets start on the drive as cut, not on its lead-ins
        # (one from a lead-in would run inland past Palmetto Row's end).
        drive_cut = unary_union(kept)
        for k, piece in enumerate(kept):
            # Where the city's south lobe cuts the drive, its ends (60 m
            # off the footprint) are led in to an exit, not left dead.
            loose = [q for q in (piece.coords[0], piece.coords[-1]) if self.P.distance(Point(q)) < 61.0]
            if loose:
                kept[k] = piece = self._to_exit(piece, "avenue", "Seabreeze Drive", loose)
            self.add(list(piece.coords), "avenue", "Seabreeze Drive", "seabreeze")
        self.ocean_drive = unary_union(kept)
        # Brisa Beach cross streets: square to the coast, every 95 m, from
        # Seabreeze Drive to Palmetto Row, the avenue behind the beach town,
        # so each one runs between two major roads.
        d = (800 / 1031.0, -650 / 1031.0)
        inland = (-d[1], d[0]) if (-d[1]) < 0 else (d[1], -d[0])
        start = self.L([[7600, 8650]])[0]
        bt = self.zone_poly["beach_town"].buffer(2.0)
        bt_prep = prep(bt)
        self.brisa_feet = []
        for k in range(0, 12):
            base = (start[0] + d[0] * (40 + 95 * k), start[1] + d[1] * (40 + 95 * k))
            a = (base[0] + inland[0] * 40, base[1] + inland[1] * 40)
            b = (base[0] + inland[0] * 300, base[1] + inland[1] * 300)
            if bt_prep.contains(Point(a)):
                self.brisa_feet.append((a, base))
            a = self._first_hit(a, b, drive_cut)
            # Past Seabreeze Drive's end a cross street would stop short.
            if a is not None and bt_prep.contains(Point(a)):
                self._clip_add([a, b], bt, "street", "", "brisa")
        back = [(start[0] + inland[0] * 300, start[1] + inland[1] * 300),
                (start[0] + inland[0] * 300 + d[0] * 1200, start[1] + inland[1] * 300 + d[1] * 1200)]
        self.palmetto = unary_union(self._clip_add(back, bt, "avenue", "Palmetto Row", "brisa"))
        self.brisa_dirs = (d, inland)
        # The Beltway: the loop less its stretch over the coast, ending on
        # Seabreeze Drive at both ends. Graded first through the hills'
        # foot, so the hill roads meet it at its height.
        parts = [g for g in lines_of(split(LineString(loop), drive_full))
                 if not self.gulf.contains(g.interpolate(0.5, normalized=True))]
        belt = max(parts, key=lambda g: g.length)
        geom = belt.intersection(self.A.difference(self.P))
        if geom.geom_type == "MultiLineString":
            geom = linemerge(geom)
        self.mtn_grades = []
        self.belt_pieces = []
        for piece in lines_of(geom):
            if piece.length < 30.0:
                continue
            gr = self.mtn.grade(piece, "freeway")
            if gr > 0.0:
                self.mtn_grades.append(("Bellerive Beltway", round(gr, 3)))
            self.add(list(piece.coords), "freeway", "Bellerive Beltway", "beltway")
            self.belt_pieces.append(self.sources[-1][0])
        self.belt_line = unary_union(self.belt_pieces)
        self._flats_expressway()
        self._mountain_roads()
        self.routes_geom = unary_union([s[0] for s in self.sources if s[3] == "route"])
        self.major_geom = unary_union([s[0] for s in self.sources if s[3] in ("route",) + MTN_TAGS])
        self._heights_roads()
        self._fringe_roads()
        self._eastside_roads()
        self._shore_roads()
        self._pier_site()
        self._hill_roads()
        self._settle()
        self._carry_on()
        self._grade_rest()
        self._rail_finish()
        self._planned_crossings()

    def _hill_roads(self):
        """The hill districts (#116 stage C): terraces along the contours of
        the range's lower, gentler slopes north of the city, HILL_PITCH apart,
        joined to each other and to the roads below by climbs traced at
        HILL_CONNECT across the fall line. A terrace no climb reaches goes.
        The land they serve leaves the mountain zone as "hillside"."""
        x0, y0, x1, y1 = HILL_BOX
        xs = np.arange(x0, x1 + HILL_CELL * 0.5, HILL_CELL)
        ys = np.arange(y0, y1 + HILL_CELL * 0.5, HILL_CELL)
        gx_, gy_ = np.meshgrid(xs, ys)
        zs = self.mtn.raw(gx_.ravel(), gy_.ravel()).reshape(gx_.shape)
        r = int(3 * HILL_BLUR)
        k = np.exp(-0.5 * (np.arange(-r, r + 1) / HILL_BLUR) ** 2)
        k /= k.sum()
        zs = np.pad(zs, r, mode="edge")
        zs = np.apply_along_axis(lambda v: np.convolve(v, k, "valid"), 0, zs)
        zs = np.apply_along_axis(lambda v: np.convolve(v, k, "valid"), 1, zs)
        gy, gx = np.gradient(zs, HILL_CELL)
        ok = ((zs >= 3.0) & (zs <= HILL_TOP) & (np.hypot(gx, gy) <= HILL_SLOPE)).astype(float)
        cells = []
        pts, offs = contourpy.contour_generator(xs, ys, ok, fill_type=contourpy.FillType.OuterOffset).filled(0.5, 1.5)
        for ring_pts, ring_offs in zip(pts, offs):
            rings = [ring_pts[ring_offs[i]:ring_offs[i + 1]] for i in range(len(ring_offs) - 1)]
            cells.append(Polygon(rings[0], rings[1:]).buffer(0))
        roads = [s for s in self.sources if CLASSES[s[1]]["graph"]]
        fast = [s for s in roads if s[1] in ("freeway", "highway")]
        cut = [s[0].buffer(CLASSES[s[1]]["w"] * 0.5 + 25.0) for s in fast]
        cut += [self.water.buffer(30.0), self.P.buffer(40.0), self.red_pine_poly]
        cut += [r_["poly"].buffer(20.0) for r_ in self.reserved]
        cut += [Point(q).buffer(80.0) for q in self.lm_pts]
        cut += [rl[0].buffer(30.0) for rl in self.rails]
        cut += [Point(q).buffer(120.0) for q in [OBSERVATORY, LETTERS] + list(MASTS)]
        region = unary_union(cells).intersection(self.zone_poly["mountain"]).difference(unary_union(cut))
        region = unary_union([q for q in polys_of(region.buffer(-10.0).buffer(10.0)) if q.area >= HILL_PART_MIN])
        if region.is_empty:
            return

        # Terraces: contours at 1 m steps from the bottom up; a run is kept
        # where it stays clear of the roads and of the terraces already laid.
        road_block = prep(unary_union([s[0].buffer(CLASSES[s[1]]["w"] * 0.5 + 30.0) for s in roads]))
        joinable = unary_union([s[0] for s in roads if s not in fast])
        terraces = []  # [line, end kinds ("road" or "bulb")]
        acc = None
        lines_gen = contourpy.contour_generator(xs, ys, zs, line_type=contourpy.LineType.Separate)
        for level in np.arange(4.0, HILL_TOP + 1.0, 1.0):
            for seg in lines_gen.lines(level):
                if len(seg) < 3:
                    continue
                full = LineString(seg)
                for piece in lines_of(full.intersection(region)):
                    if piece.length < HILL_RUN:
                        continue
                    n = max(2, int(piece.length / 8.0) + 1)
                    run_pts = [piece.interpolate(i / (n - 1), normalized=True).coords[0] for i in range(n)]
                    acc_p = prep(acc.buffer(HILL_PITCH)) if acc is not None else None
                    free = [not road_block.contains(Point(p)) and not (acc_p and acc_p.contains(Point(p))) for p in run_pts]
                    i = 0
                    while i < len(run_pts):
                        if not free[i]:
                            i += 1
                            continue
                        j = i
                        while j + 1 < len(run_pts) and free[j + 1]:
                            j += 1
                        run = run_pts[i:j + 1]
                        if len(run) >= 2 and LineString(run).length >= HILL_RUN:
                            new, kinds = self._hill_ends(full, run, joinable if acc is None else unary_union([joinable, acc]))
                            line = LineString(new)
                            terraces.append([line, kinds])
                            acc = line if acc is None else acc.union(line)
                            acc_p = prep(acc.buffer(HILL_PITCH))
                            for t in range(j + 1, len(run_pts)):
                                free[t] = free[t] and not acc_p.contains(Point(run_pts[t]))
                        i = j + 1

        # Climbs: every HILL_GAP along a terrace, down to the next way below;
        # then, for terraces still cut off, the shortest climb from anywhere
        # along them, up or down.
        st_lines = [t[0] for t in terraces]
        reach = prep(region.buffer(60.0))
        fast_p = prep(unary_union([s[0].buffer(CLASSES[s[1]]["w"] * 0.5 + 6.0) for s in fast]))
        base_lines = [s[0] for s in roads if s not in fast]
        climbs, starts = [], []

        def grad(p):
            i = int(round(min(max((p[1] - ys[0]) / HILL_CELL, 0), len(ys) - 1)))
            j = int(round(min(max((p[0] - xs[0]) / HILL_CELL, 0), len(xs) - 1)))
            return gx[i, j], gy[i, j]

        def rise(line):
            """How far a climb rises end to end over its length: its start on
            the terrace's ground, its end on the way it meets (at that way's
            graded height where it is a graded mountain road)."""
            end = line.coords[-1]
            z_end = self.mtn.profile_at(end)
            z_end = self.mtn.raw_at(end) if z_end is None else z_end
            return abs(self.mtn.raw_at(line.coords[0]) - z_end) / line.length

        steep = []  # the steep climbs (by identity)

        def allowed(c):
            """A climb that can be graded: under HILL_RISE end to end, or one
            of the few short steep ones while there is room for another."""
            r = rise(c)
            return r <= HILL_RISE or (r <= HILL_STEEP_RISE and c.length <= HILL_STEEP_LEN
                                      and len(steep) < HILL_STEEP_MAX)

        def trace(p0, own, side, up, g=HILL_CONNECT):
            """A climb from p0 on terrace `own` to the first other way it
            meets, at grade g where the ground is steeper, else straight
            down (or up) the fall line; None where it leaves the hills,
            nears a freeway, turns back onto its own terrace or meets a way
            too far above or below it to grade (allowed)."""
            tgt = unary_union([l for l in st_lines if l is not own] + base_lines + climbs)
            path = [p0]
            for step in range(80):
                p = path[-1]
                ax, ay = grad(p)
                m = math.hypot(ax, ay)
                if m < 1e-6:
                    return None
                dx, dy = (ax / m, ay / m) if up else (-ax / m, -ay / m)
                if m > g:
                    th = math.acos(g / m) * side
                    c, s_ = math.cos(th), math.sin(th)
                    dx, dy = dx * c - dy * s_, dx * s_ + dy * c
                q = (p[0] + dx * 4.0, p[1] + dy * 4.0)
                if step > 2:
                    hit = LineString([p, q]).intersection(tgt)
                    if not hit.is_empty:
                        hp = self._points(hit) or [c for g in lines_of(hit) for c in g.coords]
                        path.append(min(hp, key=lambda c: dist(c, p)))
                        out = LineString(path)
                        return out if out.length >= 20.0 and allowed(out) else None
                if not reach.contains(Point(q)) or fast_p.contains(Point(q)):
                    return None
                if step > 3 and own.distance(Point(q)) < 3.0:
                    return None
                path.append(q)
            return None

        for line in st_lines:
            n, s = 0, HILL_GAP * 0.5
            while s < line.length - 30.0:
                p0 = line.interpolate(s).coords[0]
                s += HILL_GAP
                n += 1
                if any(dist(p0, q) < 120.0 for q in starts):
                    continue
                # Now and then one straight up the slope, steep where it is.
                c = trace(p0, line, 1 if n % 2 else -1, False, HILL_STEEP_RISE - 0.03) if (
                    len(climbs) % HILL_STEEP_EVERY == HILL_STEEP_EVERY - 1) else None
                c = c or trace(p0, line, 1 if n % 2 else -1, False)
                if c is not None:
                    climbs.append(c)
                    starts.append(p0)
                    if rise(c) > HILL_RISE:
                        steep.append(c)
        base = unary_union(base_lines)

        def cut_off():
            """Terraces and climbs in a group of ways that reaches no road, by group."""
            every = st_lines + climbs
            root = list(range(len(every)))

            def find(a):
                while root[a] != a:
                    root[a] = root[root[a]]
                    a = root[a]
                return a
            tree = STRtree(every)
            for a in range(len(every)):
                for b in tree.query(every[a].buffer(1.0)):
                    if int(b) != a and every[a].distance(every[int(b)]) < 1.0:
                        root[find(a)] = find(int(b))
            good = {find(a) for a in range(len(every)) if every[a].distance(base) < 1.0}
            groups = {}
            for a in range(len(every)):
                if find(a) not in good:
                    groups.setdefault(find(a), []).append(a)
            return groups

        for _ in range(6):
            groups = cut_off()
            added = 0
            for members in groups.values():
                best = None
                for a in members:
                    if a >= len(st_lines):
                        continue
                    line = st_lines[a]
                    for s in np.arange(15.0, line.length - 15.0, 30.0):
                        p0 = line.interpolate(s).coords[0]
                        if any(dist(p0, q) < 60.0 for q in starts):
                            continue
                        for side in (1, -1):
                            for up in (False, True):
                                c = trace(p0, line, side, up)
                                if c is not None and (best is None or c.length < best[0].length):
                                    best = (c, p0)
                if best:
                    climbs.append(best[0])
                    starts.append(best[1])
                    if rise(best[0]) > HILL_RISE:
                        steep.append(best[0])
                    added += 1
            if not added:
                break
        # A cut-off group is dropped whole: its climbs too, or their loose
        # ends would get straight, ungraded join_ends links.
        lost = {a for members in cut_off().values() for a in members}
        kept = [t for a, t in enumerate(terraces) if a not in lost]
        climbs = [c for a, c in enumerate(climbs) if len(st_lines) + a not in lost]
        # Terraces first, so _grade_rest grades the climbs onto them.
        kept_src = []
        for a, (line, _kinds) in enumerate(kept):
            self.add(list(line.coords), "street", HILL_NAMES[a] if a < len(HILL_NAMES) else "", "hill")
            kept_src.append(self.sources[-1])
        for a, line in enumerate(climbs):
            tag = "steep" if any(line is q for q in steep) else "hill"
            self.add(list(line.coords), "street", HILL_CLIMB_NAMES[a] if a < len(HILL_CLIMB_NAMES) else "", tag)
        # A terrace that ends on nothing gets a turning circle; where none
        # fits it is cut back to its last climb (join_ends would tie it to
        # the terrace below with a straight, ungraded link).
        for src, (_line, kinds) in zip(kept_src, kept):
            for at_end in (False, True):
                if kinds[1 if at_end else 0] != "bulb":
                    continue
                cur = src[0]
                c = list(cur.coords)
                e, q = (c[-1], c[-2]) if at_end else (c[0], c[1])
                d = (e[0] - q[0], e[1] - q[1])
                dn = math.hypot(*d) or 1.0
                n0 = len(self.sources)
                if self._bulb(e, (d[0] / dn, d[1] / dn), "street", own=cur):
                    self.flat_bulbs.append(([t[0] for t in self.sources[n0:]], e))
                    continue
                marks = [cur.project(Point(pt)) for cl in climbs for pt in (cl.coords[0], cl.coords[-1])
                         if cur.distance(Point(pt)) < 1.0]
                if marks:
                    s_cut = max(marks) if at_end else min(marks)
                    if (s_cut if not at_end else cur.length - s_cut) > 1.0:
                        src[0] = substring(cur, 0.0, s_cut) if at_end else substring(cur, s_cut, cur.length)
        self.hill_region = region
        hz = region.buffer(40.0).intersection(self.zone_poly["mountain"])
        self.zones = [(z, p.difference(hz) if z == "mountain" else p) for z, p in self.zones] + [("hillside", hz)]
        self.zone_poly = dict(self.zones)
        self.zone_strip["hillside"] = Polygon()
        print("hill districts: %.2f km2, terraces %d (%.1f km, %d cut off), climbs %d (%.1f km), steep %s" % (
            region.area / 1e6, len(kept), sum(t[0].length for t in kept) / 1000.0,
            sum(1 for a in lost if a < len(st_lines)),
            len(climbs), sum(c.length for c in climbs) / 1000.0,
            ["%s %.0f m %.3f" % (HILL_CLIMB_NAMES[a] if a < len(HILL_CLIMB_NAMES) else "", c.length, rise(c))
             for a, c in enumerate(climbs) if any(c is q for q in steep)]))

    def _hill_ends(self, full, run, joinable):
        """A terrace run on its full contour, each end carried on along the
        contour (HILL_REACH at most) to the first road it meets: the points
        and each end's kind ("road" where it met one, else "bulb")."""
        new = list(run)
        kinds = ["bulb", "bulb"]
        for k, end in enumerate((run[0], run[-1])):
            sa = full.project(Point(end))
            sb = max(0.0, sa - HILL_REACH) if k == 0 else min(full.length, sa + HILL_REACH)
            if abs(sb - sa) < 1.0:
                continue
            hits = self._points(substring(full, min(sa, sb), max(sa, sb)).intersection(joinable))
            if not hits:
                continue
            q = min(hits, key=lambda c: dist(c, end))
            ext = list(substring(full, min(sa, full.project(Point(q))), max(sa, full.project(Point(q)))).coords)
            if k == 0:
                if dist(ext[0], end) < dist(ext[-1], end):
                    ext = ext[::-1]
                new = ext[:-1] + new
            else:
                if dist(ext[-1], end) < dist(ext[0], end):
                    ext = ext[::-1]
                new = new + ext[1:]
            kinds[k] = "road"
        return new, kinds

    def _settle(self):
        """A suburb street left stopping on nothing (cut short by a zone's
        edge, the water or civic grounds) is cut back to its last junction,
        unless join_ends can tie it to a road within 60 m; a piece left under
        20 m goes, and frees its exit. Repeated, as a cut can leave another
        street's end loose."""
        fixed = ("route", "beltway", "seabreeze", "brisa", "bulb") + MTN_TAGS
        for _ in range(8):
            drivable = [s for s in self.sources if CLASSES[s[1]]["graph"]]
            lines = [s[0] for s in drivable]
            tree = STRtree(lines)
            used_e = [ex["e"] for ex in self.exits if ex["used"]]
            changes = []
            for i, src in enumerate(drivable):
                if src[3] in fixed:
                    continue
                line = src[0]
                L = line.length

                def free(p):
                    q = Point(p)
                    if any(dist(p, e) < 2.0 for e in used_e):
                        return False
                    return not any(int(j) != i and lines[int(j)].distance(q) < 2.0 for j in tree.query(q.buffer(2.0)))

                def near(p):
                    q = Point(p)
                    if self.P.distance(q) < 3.0:
                        return False  # join_ends leaves ends at the city alone
                    return any(int(j) != i and lines[int(j)].distance(q) < 60.0 for j in tree.query(q.buffer(60.0)))

                loose = [free(line.coords[0]) and not near(line.coords[0]),
                         free(line.coords[-1]) and not near(line.coords[-1])]
                if not any(loose):
                    continue
                marks = []
                for j in tree.query(line.buffer(2.0)):
                    j = int(j)
                    if j == i:
                        continue
                    o = lines[j]
                    inter = line.intersection(o)
                    marks += [line.project(Point(q)) for q in self._points(inter)]
                    for g in lines_of(inter):
                        marks += [line.project(Point(g.coords[0])), line.project(Point(g.coords[-1]))]
                    for c in (o.coords[0], o.coords[-1]):
                        if line.distance(Point(c)) < 2.0:
                            marks.append(line.project(Point(c)))
                marks += [line.project(Point(e)) for e in used_e if line.distance(Point(e)) < 2.0]
                s0, s1 = 0.0, L
                if loose[0]:
                    s0 = min([m for m in marks if m > 0.5], default=L)
                if loose[1]:
                    s1 = max([m for m in marks if m < L - 0.5], default=0.0)
                if s1 - s0 < 20.0:
                    changes.append((src, None))
                else:
                    changes.append((src, substring(line, s0, s1)))
            if not changes:
                break
            remap = {}
            for src, new in changes:
                remap[tuple(src[0].coords)] = new
                if new is None:
                    self.sources.remove(src)
                else:
                    src[0] = new
            arts = []
            for a, o in self.arterials:
                k = tuple(a.coords)
                if k in remap:
                    a = remap[k]
                if a is not None:
                    arts.append([a, o])
            self.arterials = arts
            if self.spine is not None and tuple(self.spine.coords) in remap:
                self.spine = remap[tuple(self.spine.coords)]
            # An exit no road reaches any more is free again.
            lines = [s[0] for s in self.sources if CLASSES[s[1]]["graph"]]
            tree = STRtree(lines)
            for ex in self.exits:
                if not ex["used"]:
                    continue
                q = Point(ex["e"])
                if not any(lines[int(j)].distance(q) < 2.0 for j in tree.query(q.buffer(2.0))):
                    ex["used"] = False
                    self.links = [l for l in self.links if dist(l["pos"], ex["e"]) >= 0.5]

    def _carry_on(self):
        """Every exit still free carries its street on out, straight, to the
        first road it meets (CARRY_MAX at most). One that would cross water,
        the city, civic grounds or a landmark, run alongside another road or
        meet one at a glancing angle is left."""
        drivable = [s[0] for s in self.sources if CLASSES[s[1]]["graph"]]
        roads = unary_union(drivable)
        # A landmark takes a lot of its own: the street keeps off its middle.
        civic = unary_union([r["poly"].buffer(15.0) for r in self.reserved] + [Point(q).buffer(25.0) for q in self.lm_pts])
        tags = {"eastside": "tract", "shore": "stub", "fringe": "rowhouse", "beach_town": "brisa"}
        for ex in self.exits:
            if ex["used"] or not ex["open"]:
                continue
            e, o = ex["e"], ex["d"]
            ray = LineString([e, (e[0] + o[0] * CARRY_MAX, e[1] + o[1] * CARRY_MAX)])
            hits = [h for h in self._points(ray.intersection(roads)) if dist(e, h) > 5.0]
            if not hits:
                continue
            h = min(hits, key=lambda q: dist(e, q))
            seg = LineString([e, h])
            if (self.water_prep.intersects(seg.buffer(4.0)) or seg.intersects(civic)
                    or not self.A_prep.contains(seg) or seg.intersects(self.P_in)):
                continue
            if roads.intersection(seg.buffer(16.0, cap_style="flat")).length > 45.0:
                continue
            # The squarest of the roads met there (a junction may hold several).
            square = 1.0
            for g in drivable:
                if g.distance(Point(h)) < 0.5:
                    sh = g.project(Point(h))
                    a, b = g.interpolate(max(0.0, sh - 3.0)).coords[0], g.interpolate(min(g.length, sh + 3.0)).coords[0]
                    t = (b[0] - a[0], b[1] - a[1])
                    square = min(square, abs(t[0] * o[0] + t[1] * o[1]) / (math.hypot(*t) or 1.0))
            if square > 0.85:
                continue
            mid = seg.interpolate(0.5, normalized=True)
            zone = next((z for z, zp in self.zones if zp.contains(mid)), "")
            self.add([e, h], "avenue" if ex["rank"] >= 15 else "street", "", tags.get(zone, "carry"))
            self._link(ex)
            drivable.append(seg)
            roads = roads.union(seg)

    def _grade_rest(self):
        """Suburb streets that climb onto the hills' foot are graded too."""
        skip = ("route", "beltway") + MTN_TAGS
        for s in self.sources:
            if s[3] in skip or not CLASSES[s[1]]["graph"] or self.mtn.poly.distance(s[0]) > 1.0:
                continue
            # A hill turning circle lies level at its street's end (it spans the
            # slope across the contour; followed, it would climb up to 10 m).
            fb = next((e for arcs, e in self.flat_bulbs if any(s[0] is a for a in arcs)), None)
            h = self.mtn.profile_at(fb) if fb is not None else None
            if h is not None:
                gr = self.mtn.grade(s[0], s[1], ends={0: h, -1: h}, cap=0.0)
            else:
                gr = self.mtn.grade(s[0], s[1], cap={"hill": HILL_GRADE, "steep": HILL_STEEP - 0.01}.get(s[3]))
            if gr > 0.0:
                self.mtn_grades.append((s[2] or s[3], round(gr, 3)))

    @staticmethod
    def _first_hit(a, b, geom):
        """The first point of segment a-b on geom, or None."""
        seg = LineString([a, b])
        hits = Country._points(seg.intersection(geom))
        if not hits:
            hit = seg.intersection(geom)
            hits = [c for g in lines_of(hit) for c in (g.coords[0], g.coords[-1])]
        if not hits:
            return None
        return min(hits, key=lambda h: dist(a, h))

    def _drive_y(self, x):
        """Where Seabreeze Drive lies south of the footprint at x."""
        v = LineString([(x, -5000.0), (x, 5000.0)])
        top = max((c[1] for g in lines_of(v.intersection(self.P)) for c in g.coords), default=-5000.0)
        ys = [h[1] for h in self._points(v.intersection(self.ocean_drive)) if h[1] > top]
        return min(ys) if ys else None

    def _span_x(self, poly, x0, y, x1):
        """How far east along y from x0 poly reaches (to x1 at most)."""
        hit = LineString([(x0, y), (x1, y)]).intersection(poly)
        ends = [g for g in lines_of(hit) if g.distance(Point(x0, y)) < 1.0]
        if not ends:
            return x0
        return max(c[0] for c in ends[0].coords)

    def _bulb(self, end, d, cls, own=None):
        """A cul-de-sac's turning circle where a street ends (d: the street's
        direction there). Left out where it would not fit."""
        c = (end[0] + d[0] * BULB_R, end[1] + d[1] * BULB_R)
        hw = CLASSES[cls]["w"] * 0.5
        disc = Point(c).buffer(BULB_R + hw + 3.0)
        if not self.play_land_prep.contains(disc):
            return False
        for s in self.sources:
            if s[0] is own:
                continue
            if s[0].distance(Point(c)) < BULB_R + 14.0:
                return False
        if any(r["poly"].distance(Point(c)) < BULB_R + 20.0 for r in self.reserved):
            return False
        for pts in ring_arcs(c, BULB_R, math.atan2(-d[1], -d[0])):
            self.add(pts, cls, "", "bulb")
        self.bulbs.append(c)
        return True

    def _add_cut(self, pts, cls, name, tag, cut=None, keep=None, bulbs=(False, False), link=None, min_len=60.0):
        """A street, less what lies in `cut` and outside `keep`; an end flagged
        in `bulbs` gets a turning circle. An end left short by the cut is
        tied to the nearest road later (join_ends), so no street stops dead.
        link: the exit dict (_exits) when it starts at an exit."""
        line = LineString(pts)
        geom = line
        if keep is not None:
            geom = geom.intersection(keep)
        if cut is not None and not cut.is_empty:
            geom = geom.difference(cut)
        if geom.geom_type == "MultiLineString":
            geom = linemerge(geom)
        out = []
        for piece in lines_of(geom):
            if piece.length < min_len:
                continue
            coords = list(piece.coords)
            self.add(coords, cls, name, tag)
            own = self.sources[-1][0]
            out.append(piece)
            if link and dist(coords[0], link["e"]) < 2.0:
                self._link(link)
            for k, (e, q) in enumerate(((coords[0], coords[1]), (coords[-1], coords[-2]))):
                orig = pts[0] if k == 0 else pts[-1]
                flagged = bulbs[k] and dist(e, orig) < 1.0
                if flagged:
                    n = dist(e, q) or 1.0
                    self._bulb(e, ((e[0] - q[0]) / n, (e[1] - q[1]) / n), cls, own)
        return out

    def _reserve(self, line, sgn, size, area, kind):
        """Room for civic grounds (W x D) beside a road, square to it, searched
        from the road's middle outward; kept in self.reserved."""
        W, D = size
        hw = CLASSES["avenue"]["w"] * 0.5
        area_p = prep(area)
        L = line.length
        for k in range(0, int(L / 20.0)):
            s = L * 0.5 + (k + 1) // 2 * 20.0 * (1 if k % 2 else -1)
            if s < W * 0.5 + 30.0 or s > L - W * 0.5 - 30.0:
                continue
            p, t = _along(line, s)
            n = (-t[1] * sgn, t[0] * sgn)
            c = (p[0] + n[0] * (hw + 3.5 + D * 0.5), p[1] + n[1] * (hw + 3.5 + D * 0.5))
            yaw = yaw_facing(*n)
            poly = lot_poly(c[0], c[1], yaw, W, D)
            if not area_p.contains(poly.buffer(8.0)):
                continue
            # Where the road bends in towards the grounds.
            if line.distance(poly) < hw + 3.0:
                continue
            if any(rl[0].distance(poly) < 12.0 for rl in self.rails):
                continue
            if self.routes_geom.distance(poly) < 30.0:
                continue
            # Clear of the other arterials' corners, which hold the mini-malls.
            if any(a.distance(poly) < 90.0 for a, _ in self.arterials if a is not line):
                continue
            if any(Point(q).distance(poly) < 70.0 for q in self.lm_pts):
                continue
            if any(r["poly"].distance(poly) < 30.0 for r in self.reserved):
                continue
            self.reserved.append({"kind": kind, "c": c, "yaw": yaw, "W": W, "D": D, "poly": poly, "n": n})
            return self.reserved[-1]
        return None

    def _mountain_roads(self):
        """The range's ways (tools/mountain.py, laid by mountain_plan.py),
        each graded as it goes in so the ones after it meet it at its
        height: first the rail pass (its shelf at no more than 2.5%), then
        the map routes through the range with their bridges, then the
        range's own roads, tracks and trails. One that starts at the city
        starts from the exit that suits it (_pick_exit), along the exit's
        street. Tunnels, bridges, viaducts and the trails' underpasses go
        into self.structures."""
        self.structures = []
        self.rail_pass = None
        self._rail_state = None
        planned = mountain_lines()
        if "rail_pass" in planned:
            self._rail_pass(planned["rail_pass"])
        else:
            print("WARNING: mountain_lines.json has no rail_pass (run mountain_plan.py rail_pass)")
        order = [v["name"] for v in planned.values() if v["tag"] == "route"]
        by_name = {v["name"]: v for v in planned.values() if v["tag"] == "route"}
        routes = [s for s in self.sources if s[3] == "route" and self.mtn.poly.distance(s[0]) <= 1.0]
        routes.sort(key=lambda s: order.index(s[2]) if s[2] in order else len(order))
        for s in routes:
            v = by_name.get(s[2])
            spans = self._spans_on(s[0], self._span_ends(v["pts"], v["spans"])) if v else []
            spans = self._wet_only(s[0], spans)
            # Where it leaves the play area (barricaded) its end follows its grade.
            loose = tuple(k for k in (0, -1) if self.A.exterior.distance(Point(s[0].coords[k])) < 2.0)
            gr = self.mtn.grade(s[0], s[1], spans=spans, loose=loose)
            if gr > 0.0:
                self.mtn_grades.append((s[2], round(gr, 3)))
            self._note_structures(s[0], s[1], s[2], spans)

        # Ways laid so far that a later one may ride on (a shared carriageway).
        earlier = [(s[0], CLASSES[s[1]]["w"] * 0.5) for s in routes if CLASSES[s[1]]["graph"]]
        for ident, pts, cls, name, tag, spans in mountain_roads():
            ends = self._span_ends(pts, spans)
            pts = list(pts)
            if self.P.distance(Point(pts[0])) < 400.0:
                orig, rest = pts[0], pts[1:]
                while len(rest) > 2 and self.P.distance(Point(rest[0])) < 80.0:
                    rest.pop(0)
                p1 = rest[0]
                ex = (self._pick_exit(orig, p1, 15 if cls in ("highway", "freeway") else 1)
                      or self._pick_exit(orig, p1, 1))
                if ex is not None:
                    e, d = ex["e"], ex["d"]
                    k = min(40.0, 0.3 * dist(e, p1))
                    pts = [e, (e[0] + d[0] * k, e[1] + d[1] * k)] + rest
                    self._link(ex)
            line = LineString(fillet(pts, MTN_FILLET[cls], CLASSES[cls]["step"] * 0.5))
            spans = self._wet_only(line, self._spans_on(line, ends))
            if ident != "letters_trail":
                if cls == "trail":
                    spans = sorted(spans + self._underpasses(line, spans))
                # Mount Calder Road ends level in the summit car park, a
                # track up to a viewpoint in its pull-out.
                flat = 60.0 if ident == "calder" else VIEW_FLAT if any(ident in v[1] for v in VIEWPOINTS.values()) else 0.0
                self.mtn_grades.append((name, round(self.mtn.grade(line, cls, spans=spans, cap=MTN_CAP.get(ident),
                                                                   flat_end=flat), 3)))
            self._note_structures(line, cls, name, spans)
            # Where it rides on an earlier way, that way alone is laid (two
            # near-copies noded into a tangle of scraps and left dead ends).
            cuts = []
            if CLASSES[cls]["graph"]:
                cuts = self._shared_cuts(line, cls, spans, earlier)
                earlier.append((line, CLASSES[cls]["w"] * 0.5))
            # A tunnel's or underpass's stretch is not laid on the ground: the
            # way stops at its portals (a tunnel's with a barricade).
            s = 0.0
            for a, b, k in sorted([sp for sp in spans if sp[2] in "tu"] + cuts):
                if a - s > 1.0:
                    self.add(list(substring(line, s, a).coords), cls, name, tag)
                if k == "t":
                    for q, sg in ((a, -1.0), (b, 1.0)):
                        (x, y), (dx, dy) = _along(line, q)
                        bx, by = x + dx * sg * 6.0, y + dy * sg * 6.0
                        self.barricades.append([round(bx, 2), round(by, 2), round(dx, 4), round(dy, 4), CLASSES[cls]["w"]])
                s = b
            if line.length - s > 1.0:
                self.add(list(substring(line, s, line.length).coords), cls, name, tag)

    def _shared_cuts(self, line, cls, spans, earlier):
        """The stretches (a, b, "x") where line rides on an earlier way: a run
        of 16 m or more within half the two widths + 1 m of it, cut from the
        first to the last of its points within 2 m (so the ends left meet that
        way's side and snap to it as tees). Runs over a span are kept."""
        hw = CLASSES[cls]["w"] * 0.5
        n = max(1, math.ceil(line.length / 2.0))
        ss = np.linspace(0.0, line.length, n + 1)
        pts = shapely.points([line.interpolate(q).coords[0] for q in ss])
        cuts = []
        for other, ohw in earlier:
            near = 0.5 * (hw + ohw) + 1.0
            if other.distance(line) >= near:
                continue
            ds = shapely.distance(other, pts)
            k = 0
            while k < len(ss):
                if ds[k] >= near:
                    k += 1
                    continue
                j = k
                while j + 1 < len(ss) and ds[j + 1] < near:
                    j += 1
                close = [i for i in range(k, j + 1) if ds[i] < 2.0]
                if ss[j] - ss[k] >= 16.0 and close and ss[close[-1]] - ss[close[0]] >= 8.0:
                    a, b = float(ss[close[0]]), float(ss[close[-1]])
                    if not any(x < b + 4.0 and y > a - 4.0 for x, y, _k in spans):
                        cuts.append([a, b])
                k = j + 1
        cuts.sort()
        out = []
        for a, b in cuts:
            if out and a <= out[-1][1] + 4.0:
                out[-1][1] = max(out[-1][1], b)
            else:
                out.append([a, b])
        for a, b in out:
            p, q = line.interpolate(a).coords[0], line.interpolate(b).coords[0]
            print(f"shared: cut {b - a:.0f} m of a {cls} from ({p[0]:.0f},{p[1]:.0f}) to ({q[0]:.0f},{q[1]:.0f})")
        return [(a, b, "x") for a, b in out]

    def _rail_pass(self, plan):
        """The Morrow Freight Line over the range (world_map.json carries the
        planned line): graded at no more than 2.5% on its shelf, which is cut
        and filled into the ground like a road. The roads graded after it
        meet it at grade or pass over or under it (mountain.RAIL_CLEAR);
        _rail_finish then takes its tunnels, viaducts and those crossings out
        of the track as structures."""
        name = plan["name"]
        ends = self._span_ends(plan["pts"], plan["spans"])
        a, b = Point(plan["pts"][0]), Point(plan["pts"][-1])
        self._rail_state = None
        for i, rl in enumerate(self.rails):
            if rl[2] != name or self.mtn.poly.distance(rl[0]) > 1.0:
                continue
            line = rl[0]
            s0, s1 = sorted((line.project(a), line.project(b)))
            if s1 - s0 < 100.0:
                continue  # a scrap of the line by the range, not the pass
            spans = self._spans_on(line, ends)
            self.mtn.grade(line, "rail", spans=spans)
            self._rail_state = (i, line, s0, s1, self.mtn.profiles[-1])
        if self._rail_state is None:
            print("WARNING: the rail pass is not on the map")

    def _rail_finish(self):
        """Once every road is graded: the rail's spans (tunnels, viaducts, and
        a bridge over or a cover under each road that crosses it out of
        grade) leave its ground alone, go into structures and out of the
        track; rail_pass carries the line, its heights and spans."""
        self.rail_pass = None
        if self._rail_state is None:
            return
        i, line, s0, s1, prof = self._rail_state
        rl = self.rails[i]
        name = rl[2]
        spans = list(prof[5])
        for other, so, kind, hw, sin, hug in self.mtn.rail_cross:
            if other is not line:
                continue
            # Along the rail, a road crossing aslant needs a longer span, and
            # one running on beside the track the length it stays close.
            half = max(min((hw + (6.0 if kind == "b" else 10.0)) / max(sin, 0.3), 60.0), min(hug + hw, 60.0))
            if any(a - 4.0 < so < b + 4.0 for a, b, _k in spans):
                continue
            spans.append((so - half, so + half, kind))
        spans.sort()
        prof[5][:] = spans  # the grid leaves the ground under them to the road
        self._note_structures(line, "rail", name, spans, prof)
        n = math.ceil((s1 - s0) / 16.0)
        ss = [s0 + (s1 - s0) * k / max(1, n) for k in range(n + 1)]
        zs = [float(np.interp(q, prof[1], prof[2])) for q in ss]
        g = max(abs(z1 - z0) / max(q1 - q0, 0.1) for z0, z1, q0, q1 in zip(zs, zs[1:], ss, ss[1:]))
        self.rail_pass = {"name": name, "pts": [[round(line.interpolate(q).coords[0][0], 2), round(line.interpolate(q).coords[0][1], 2),
                                                 round(z, 2)] for q, z in zip(ss, zs)],
                          "spans": [[round(max(x, s0) - s0, 1), round(min(y, s1) - s0, 1), k] for x, y, k in spans if y > s0 and x < s1],
                          "grade": round(g, 4)}
        self.mtn_grades.append((name, round(g, 4)))
        out = []
        s = 0.0
        for x, y, _k in spans:
            if x - s > 5.0:
                out.append([substring(line, s, x), rl[1], rl[2], rl[3]])
            s = max(s, y)
        if line.length - s > 5.0:
            out.append([substring(line, s, line.length), rl[1], rl[2], rl[3]])
        self.rails = self.rails[:i] + out + self.rails[i + 1:]

    @staticmethod
    def _span_ends(pts, spans):
        """Spans [(s0, s1, kind)] along pts as their end points, to be found
        again on the line as built (_spans_on)."""
        raw = LineString(pts)
        return [(raw.interpolate(a).coords[0], raw.interpolate(b).coords[0], k) for a, b, k in spans]

    @staticmethod
    def _spans_on(line, ends):
        out = []
        for p, q, k in ends:
            if line.distance(Point(p)) > 8.0 or line.distance(Point(q)) > 8.0:
                continue
            a, b = sorted((line.project(Point(p)), line.project(Point(q))))
            if b - a > 2.0:
                out.append((a, b, k))
        return out

    def _wet_only(self, line, spans):
        """A road bridge keeps only its stretch over the water, 4 m either
        side: the game lays a road's deck at the water's level, so the road
        comes down its banks to it (the rail's viaducts stay whole)."""
        out = []
        for a, b, k in spans:
            if k != "b":
                out.append((a, b, k))
                continue
            seg = substring(line, a, b)
            for g in lines_of(seg.intersection(self.water)):
                q0, q1 = sorted((a + seg.project(Point(g.coords[0])), a + seg.project(Point(g.coords[-1]))))
                out.append((max(a, q0 - 4.0), min(b, q1 + 4.0), "b"))
        return out

    def _underpasses(self, line, spans):
        """Where a trail crosses a lane or bigger it passes under it
        (mountain.UNDER_DROP down), not across: a span ('u') round each
        crossing, its ends clear of the road's banks."""
        out = []
        for other, _s, _z, hw, _bank, _sp in self.mtn.profiles:
            if hw < 3.5:
                continue
            for q in self._points(line.intersection(other)):
                sq = line.project(Point(q))
                if sq < 30.0 or sq > line.length - 30.0 or any(a - 20 < sq < b + 20 for a, b, _k in spans + out):
                    continue
                half = hw + 12.0
                out.append((sq - half, sq + half, "u"))
        return out

    def _planned_crossings(self):
        """The Solvera Line's grade separations in the play area (world_map.json
        flyover / overpass / footbridge landmarks, tools/mountain_world_map.py)
        as planned structures for the grade-separation pass: the deck runs
        along the route on top, centred on the crossing. Until that pass the
        track and road stay at grade, so heights are not set (z 0)."""
        routes = {r["id"]: r for r in self.world["routes"]}
        deck = {"flyover": 120.0, "overpass": 48.0, "footbridge": 24.0}
        n = 0
        for lm in self.world["landmarks"]:
            if lm.get("type") not in deck or lm["over"] not in routes:
                continue
            p = Point(self.L([lm["pos"]])[0])
            if not self.A.contains(p):
                continue
            line = LineString(self.L(routes[lm["over"]]["line"]))
            s = line.project(p)
            a, b = max(0.0, s - deck[lm["type"]] * 0.5), min(line.length, s + deck[lm["type"]] * 0.5)
            k = max(1, math.ceil((b - a) / 8.0))
            pts = [[round(c, 2) for c in line.interpolate(a + (b - a) * i / k).coords[0]] + [0.0] for i in range(k + 1)]
            self.structures.append({"kind": lm["type"], "way": routes[lm["over"]]["name"],
                                    "crossing": routes[lm["under"]]["name"], "cls": "rail" if lm["type"] == "flyover" else "road",
                                    "length": round(b - a, 1), "pts": pts, "portals": [pts[0], pts[-1]],
                                    "bridge": True, "planned": True})
            n += 1
        print("planned grade separations in the play area:", n)

    def _note_structures(self, line, cls, name, spans, prof=None):
        """Each span of the line just graded (or of `prof`) as a structure:
        {kind, tunnel | under | bridge, way, cls, pts [[x, y, z]] every 8 m,
        portals}."""
        if prof is None:
            prof = self.mtn.profiles[-1] if self.mtn.profiles and self.mtn.profiles[-1][0] is line else None
        kinds = {"t": "tunnel", "u": "underpass", "b": "viaduct" if cls == "rail" else "bridge"}
        for a, b, k in spans:
            n = max(1, math.ceil((b - a) / 8.0))
            ss = [a + (b - a) * i / n for i in range(n + 1)]

            def at(q):
                x, y = line.interpolate(q).coords[0]
                z = float(np.interp(q, prof[1], prof[2])) if prof else 0.0
                return [round(x, 2), round(y, 2), round(z, 2)]
            pts = [at(q) for q in ss]
            rec = {"kind": kinds[k], "way": name, "cls": cls, "length": round(b - a, 1), "pts": pts,
                   "portals": [pts[0], pts[-1]]}
            if k == "t":
                rec["tunnel"] = True
            elif k == "u":
                rec["under"] = True
            else:
                rec["bridge"] = True
            self.structures.append(rec)

    def mountain_lots(self):
        """The observatory at the end of its road, the letters on the slope
        below Calder Peak facing the city, the masts on the summit."""
        def site(x, y, kind, ident, search=0.0):
            # Set where the design puts it, or (search) the nearest spot clear
            # of the roads, lots and water within that far of it, where the
            # range's re-laid ways cross it; not squared to a road (none
            # fronts the letters or the masts).
            spots = [(x, y)] + [(x + r * math.cos(a * math.pi / 8.0), y + r * math.sin(a * math.pi / 8.0))
                                for r in np.arange(10.0, search + 1.0, 10.0) for a in range(16)]
            for k, (x, y) in enumerate(spots):
                poly = lot_poly(x, y, south, *LOT[kind])
                if not (self.road_prep.intersects(poly.buffer(3.0) if k else poly) or self.lot_grid.hits(poly)
                        or self.water_prep.intersects(poly) or not self.A_prep.contains(poly)):
                    break
            else:
                print("  %s: no room within %.0f m" % (ident, search))
                return False
            self.lot_grid.add(poly.buffer(1.5))
            self.lots.append({"x": x, "y": y, "yaw": south, "w": LOT[kind][0], "d": LOT[kind][1], "kind": kind,
                              "id": ident, "zone": "mountain", "plot": -1})
            return True

        south = yaw_facing(0.0, -1.0)
        placed = [site(OBSERVATORY[0], OBSERVATORY[1], "observatory", "lumen_observatory"),
                  site(LETTERS[0], LETTERS[1], "hill_letters", "hill_letters", 160.0)]
        if placed[0]:
            # Observatory Road ends a road shoulder short of the lot: a drive
            # carries on from its end up to the forecourt.
            end = OBSERVATORY_ROAD_END
            front = (end[0], OBSERVATORY[1] + OBSERVATORY_SIZE[1] * 0.5 - 1.0)
            self.paths.append([[round(front[0], 2), round(front[1], 2)], [round(end[0], 2), round(end[1], 2)]])
        for i, m in enumerate(MASTS):
            placed.append(site(m[0], m[1], "radio_mast", "calder_mast_%d" % i, 120.0))
        if not all(placed):
            print("WARNING: mountain sites not all placed", placed)

    # --- Hill country (HANDOFF-hill-content.md) -------------------------------------

    def hill_lakes(self):
        """Tallow Lake and Fernmoor Pond: each fills its hollow in the ground
        up to its level (the shore is where the ground meets it), with an
        invisible wall along the shore and no lot in it. The terrain digs
        the bed (Mountain.lakes); the game lays the water at the level."""
        self.lakes = []
        step = 4.0
        for ident, name, c, level in HILL_LAKES:
            xs = np.arange(c[0] - LAKE_REACH, c[0] + LAKE_REACH + step, step)
            ys = np.arange(c[1] - LAKE_REACH, c[1] + LAKE_REACH + step, step)
            gx, gy = np.meshgrid(xs, ys)
            h = self.mtn.raw(gx.ravel(), gy.ravel()).reshape(gx.shape)
            lab, _n = ndimage.label(h < level)
            comp = lab == lab[len(ys) // 2, len(xs) // 2]
            if not lab[len(ys) // 2, len(xs) // 2] or comp[0].any() or comp[-1].any() or comp[:, 0].any() or comp[:, -1].any():
                print("WARNING: %s: no closed hollow under %.1f m" % (ident, level))
                continue
            cells = shapely.box(gx[comp] - step * 0.5, gy[comp] - step * 0.5, gx[comp] + step * 0.5, gy[comp] + step * 0.5)
            shore = shapely.union_all(cells).buffer(3.0).buffer(-3.0).simplify(1.0)
            shore = max(polys_of(shore), key=lambda q: q.area)
            shore = Polygon(shore.exterior)
            if self.road_prep.intersects(shore):
                print("WARNING: %s: a road runs into the lake" % ident)
            wet = [l for l in self.lots if shore.intersects(lot_poly(l["x"], l["y"], l["yaw"], l["w"], l["d"]))]
            if wet:
                print("WARNING: %s: lots in the lake: %s" % (ident, [l["kind"] for l in wet]))
            self.lot_grid.add(shore.buffer(4.0))
            self.plot_grid.add(shore.buffer(4.0))
            pts = list(shore.exterior.coords)
            for a, b in zip(pts, pts[1:]):
                for piece in _split(a, b, 30.0):
                    self.wall_list.append([round(piece[0][0], 2), round(piece[0][1], 2), round(piece[1][0], 2),
                                           round(piece[1][1], 2), WALL_SHORE])
            self.lakes.append({"id": ident, "name": name, "level": level, "shore": shore})
            print("lake %s: %.0f m2 at %.1f m" % (ident, shore.area, level))
        self.mtn.lakes = [(lk["shore"], lk["level"], LAKE_DEPTH, LAKE_SHELF) for lk in self.lakes]

    def _site(self, x, y, kind, ident, search, zone="mountain"):
        """A lot at (x, y) or the nearest clear spot within `search` m of it
        (every 10 m out, 16 ways round), its front to the nearest way."""
        w, d = LOT[kind]
        spots = [(x, y)] + [(x + r * math.cos(a * math.pi / 8.0), y + r * math.sin(a * math.pi / 8.0))
                            for r in np.arange(10.0, search + 1.0, 10.0) for a in range(16)]
        why = collections.Counter()
        for q in spots:
            near = nearest_points(self.road_area, Point(q))[0]
            nx, ny = q[0] - near.x, q[1] - near.y
            n = math.hypot(nx, ny) or 1.0
            yaw = yaw_facing(nx / n, ny / n)
            poly = lot_poly(q[0], q[1], yaw, w, d)
            hit = [k for k, bad in (("road", self.road_prep.intersects(poly.buffer(3.0))),
                                    ("lot", self.lot_grid.hits(poly)), ("plot", self.plot_grid.hits(poly)),
                                    ("water", self.water_prep.intersects(poly)),
                                    ("off play land", not self.play_land_prep.contains(poly))) if bad]
            if hit:
                why.update(hit)
                continue
            self.lot_grid.add(poly.buffer(1.5))
            self.lots.append({"x": q[0], "y": q[1], "yaw": yaw, "w": w, "d": d, "kind": kind, "id": ident,
                              "zone": zone, "plot": -1})
            return True
        print("  %s: no site within %d m (%s)" % (ident, search, dict(why)))
        return False

    def hill_places(self):
        """The hill country's villages, roadside stops, trailer town and
        off-road places (HILL_VILLAGES, HILL_PLACES, HILL_TRAILERS). Laid
        after every other lot, so none of those moves; a place whose spot
        is taken goes to the nearest free one."""
        missed = []
        self.village_lots = {}
        for name, c, kinds in HILL_VILLAGES:
            self.village_lots[name] = []
            for k, kind in enumerate(kinds):
                ident = "%s_%s" % (name, kind) if kind != "house" else ""
                if not self._place_near(c, kind, ident, "mountain", 260.0):
                    missed.append(ident or "%s house %d" % (name, k))
                else:
                    self.village_lots[name].append((self.lots[-1]["x"], self.lots[-1]["y"]))
        for kind, x, y, ident, how, reach in HILL_PLACES:
            ok = (self._place_near((x, y), kind, ident, "mountain", reach) if how == "front"
                  else self._site(x, y, kind, ident, reach))
            if not ok:
                missed.append(ident)
        saved, self.rng = self.rng, random.Random(HILL_SEED)
        for k, (q, (W, D)) in enumerate(HILL_TRAILERS):
            if not any(self.cluster_at(self._spiral_pt(q, r), W, D, ["trailer_home"], "trailers", "mountain")
                       for r in range(0, 120, 6)):
                missed.append("trailers %d" % k)
        self.rng = saved
        if missed:
            print("WARNING: hill places not placed:", missed)
        print("hill places: %d lots" % sum(1 for l in self.lots if l["zone"] == "mountain"))

    @staticmethod
    def _spiral_pt(q, r):
        a = r * 0.7
        return (q[0] + math.cos(a) * r, q[1] + math.sin(a) * r)

    def hill_streams(self):
        """Each stream from its source down the smoothed final ground until
        a lake, the plain (under 3 m) or the water; broken where it passes
        under a way (a culvert) and inside a lake."""
        self.streams = []
        h = ndimage.gaussian_filter(self.mtn.heights, 3)
        x0, y0 = self.mtn.origin
        ny, nx = h.shape
        lakes = unary_union([lk["shore"] for lk in self.lakes]) if self.lakes else Polygon()
        cut = unary_union([self.road_area.buffer(1.0), lakes])
        for ident, name, (sx, sy) in HILL_STREAMS:
            j, i = int(round((sx - x0) / MTN_CELL)), int(round((sy - y0) / MTN_CELL))
            path = [(sx, sy)]
            for _ in range(4000):
                win = h[max(i - 1, 0):i + 2, max(j - 1, 0):j + 2]
                a, b = np.unravel_index(np.argmin(win), win.shape)
                ni, nj = max(i - 1, 0) + a, max(j - 1, 0) + b
                if (ni, nj) == (i, j):
                    break
                i, j = ni, nj
                p = (x0 + j * MTN_CELL, y0 + i * MTN_CELL)
                path.append(p)
                if self.mtn.heights[i, j] < 3.0 or lakes.contains(Point(p)) or self.water_prep.contains(Point(p)):
                    break
            if len(path) < 3:
                continue
            line = LineString(path).simplify(2.0)
            line = LineString(chaikin(list(line.coords), 2))
            n = 0
            for g in lines_of(line.difference(cut)):
                if g.length >= 16.0:
                    self.streams.append({"id": ident, "name": name, "w": STREAM_W,
                                         "pts": [round(v, 1) for q in g.coords for v in q]})
                    n += 1
            print("stream %s: %.0f m, %d pieces" % (ident, line.length, n))

    def mountain_terrain(self):
        """The height grid: each mountain plot and lot sits on a flat pad at
        the height of the road it fronts (a lot in a plot on the plot's, the
        masts on one summit compound); the letters stand on the slope."""
        near = self.mtn.poly.buffer(40.0)

        def front_height(x, y, yaw, d):
            h = self.mtn.profile_near(frame_point((x, y), yaw, 0.0, -d * 0.5), 30.0)
            return h if h is not None else self.mtn.raw_at((x, y))

        pads = []
        plot_h = {}
        for i, p in enumerate(self.plots):
            if near.contains(Point(p["x"], p["y"])):
                plot_h[i] = front_height(p["x"], p["y"], p["yaw"], p["d"])
                pads.append((lot_poly(p["x"], p["y"], p["yaw"], p["w"], p["d"]), plot_h[i]))
        # The masts share one compound on the summit, level with the end of
        # the fire road (or the higher ground, if that is higher).
        summit = max([self.mtn.raw_at(m) for m in MASTS] + [self.mtn.profile_near(MASTS[0], 30.0) or 0.0])
        owners = [None] * len(pads)  # the lot each pad is for
        for l in self.lots:
            if l["kind"] == "hill_letters" or not near.contains(Point(l["x"], l["y"])):
                continue
            if l["kind"] == "radio_mast":
                h = summit
            elif l.get("plot", -1) in plot_h:
                h = plot_h[l["plot"]]
            else:
                h = front_height(l["x"], l["y"], l["yaw"], l["d"])
            pads.append((lot_poly(l["x"], l["y"], l["yaw"], l["w"], l["d"]), h))
            owners.append(l)
        # The summit's sites, each level at its own ground (the car park at
        # the end of Mount Calder Road), and the cable car's mid-station.
        self.mtn_sites = {}
        for k, (x, y, sw, sd) in SUMMIT_SITES.items():
            h = self.mtn.profile_near((x, y), 20.0) if k == "car_park" else None
            if k == "restaurant":  # beside the car park, on its level (one terrace)
                h = self.mtn_sites["car_park"]["z"]
            h = h if h is not None else self.mtn.raw_at((x, y))
            self.mtn_sites[k] = {"x": x, "y": y, "w": sw, "d": sd, "z": round(h, 2)}
        # The viewpoints' pull-outs: at the end of the tracks that climb to
        # them (on its level), or at their own ground beside the way.
        for k, ((x, y), roads) in VIEWPOINTS.items():
            h = self.mtn.profile_near((x, y), 20.0) if roads else None
            h = h if h is not None else self.mtn.raw_at((x, y))
            self.mtn_sites["view_" + k] = {"x": x, "y": y, "w": VIEW_SIZE[0], "d": VIEW_SIZE[1], "z": round(h, 2)}
        mx, my = CABLE["mid"]
        self.mtn_sites["cable_mid"] = {"x": mx, "y": my, "w": CABLE_MID_SIZE[0], "d": CABLE_MID_SIZE[1],
                                       "z": round(self.mtn.raw_at((mx, my)), 2)}
        for v in self.mtn_sites.values():
            pads.append((box(v["x"] - v["w"] * 0.5, v["y"] - v["d"] * 0.5, v["x"] + v["w"] * 0.5, v["y"] + v["d"] * 0.5), v["z"]))
        self.terrain = self.mtn.grid(pads)
        # A hill home whose pad cannot lie level at its back and sides goes:
        # a pad or road at another height within about a cell of it shares
        # the 8 m grid's cells with it. The worst goes first, one of each
        # close group a round, and the grid is made again. Its front meets
        # its road's grading, as on the mountain.
        dropped = 0
        for _round in range(4):
            tilted = sorted(((self._pad_tilt(l), k) for k, l in enumerate(owners)
                             if l is not None and l["zone"] == "hillside"), reverse=True)
            drop = []
            for t, k in tilted:
                if t > HILL_PAD_TOL and not any(pads[k][0].distance(pads[j][0]) < 3.0 * MTN_CELL for j in drop):
                    drop.append(k)
            if not drop:
                break
            gone = {id(owners[k]) for k in drop}
            self.lots = [l for l in self.lots if id(l) not in gone]
            pads = [pd for k, pd in enumerate(pads) if k not in drop]
            owners = [o for k, o in enumerate(owners) if k not in drop]
            dropped += len(drop)
            self.terrain = self.mtn.grid(pads)
        print("hill homes off level dropped: %d" % dropped)
        self.mtn_pads = pads

    def _pad_tilt(self, l):
        """How far a lot's ground lies off level 1 m inside its back and
        sides and at its middle (the final grid, as the game reads it)."""
        hs = [self.mtn.height(frame_point((l["x"], l["y"]), l["yaw"], u * (l["w"] * 0.5 - 1.0), v * (l["d"] * 0.5 - 1.0)))
              for u in (-1.0, 0.0, 1.0) for v in (0.0, 1.0)]
        return max(hs) - min(hs)

    def _heights_roads(self):
        """Magnolia Heights and Blackwater Bayou: the flats (drives round the
        city's edge, one kind of street tree each, palm-lined streets out
        from the city to them) and, further out, estate roads that wind out
        to the Beltway; the bayou's rings and streets run on to the Beltway."""
        z = self.zone_poly
        hz, bayou = z["heights"], z["bayou_town"]
        # Bayou Drive runs along both banks of the bayou through Blackwater
        # Bayou, so the streets that reach the water end on it. It stops
        # short where it would cross a rail line at under 30 degrees (the
        # docks spur's loop by the bank once the city edge drew back, #116).
        bank = self.water.buffer(BAYOU_DRIVE_SET).boundary.intersection(bayou.buffer(0.5))
        cuts = []
        for line in lines_of(bank):
            for rl in self.rails:
                x = line.intersection(rl[0])
                for p in [g for g in getattr(x, "geoms", [x]) if g.geom_type == "Point"]:
                    da = _along(line, line.project(p))[1]
                    db = _along(rl[0], rl[0].project(p))[1]
                    if abs(da[0] * db[0] + da[1] * db[1]) > math.cos(math.radians(30.0)):
                        cuts.append(p.buffer(40.0))
        if cuts:
            bank = bank.difference(unary_union(cuts))
        for piece in lines_of(bank):
            if piece.length > 60.0:
                # Where it reaches the city it is led in to an exit.
                piece = self._to_exit(piece, "avenue", BAYOU_DRIVE_NAME)
                self.add(list(piece.coords), "avenue", BAYOU_DRIVE_NAME, "suburb")
        dry = self.water.buffer(BAYOU_DRIVE_SET - 1.0)
        both = unary_union([hz, bayou]).buffer(1.0).difference(dry)
        bayou_keep = unary_union([bayou, self.zone_strip["bayou_town"]]).buffer(1.0).difference(dry)
        hz_keep = unary_union([hz, self.zone_strip["heights"]]).buffer(1.0)
        self.flats_rings = []
        for k in range(FLATS_STREETS):
            ring = self._ring(FLATS_FIRST + FLATS_PITCH * k)
            got = self._add_cut(list(ring.coords), "street", FLATS_NAMES[k], "flats:" + FLATS_TREES[k], keep=both)
            self.flats_rings.append(unary_union(got) if got else LineString())
        # Blackwater Bayou's rings carry on out on the same pitch.
        d = FLATS_FIRST + FLATS_PITCH * FLATS_STREETS
        while d < 620.0:
            self._add_cut(list(self._ring(d).coords), "street", "", "suburb", keep=bayou_keep, min_len=40.0)
            d += FLATS_PITCH
        # Showcase streets: from the city's exits out to the outer flats drive.
        outer = self.flats_rings[-1]
        hits = []
        for ex in self._spread(self._exits_into(hz), 140.0, 60.0):
            e, dd = ex["e"], ex["d"]
            hit = self._ray_to(e, dd, outer, far=400.0)
            if hit is None:
                continue
            cls = "avenue" if ex["rank"] >= 15 else "street"
            if self._add_cut([e, hit], cls, "", "showcase", keep=hz.buffer(1.0), link=ex, min_len=30.0):
                hits.append(hit)
        # Blackwater Bayou's streets from the city run on to the Beltway.
        chosen = []
        for ex in sorted(self._exits_into(bayou), key=lambda x: (-x["rank"], x["n"], x["d"])):
            e, dd = ex["e"], ex["d"]
            if ex["rank"] < 15 and any(dist(e, c) < 70.0 for c in chosen):
                continue
            hit = self._ray_to(e, dd, self.belt_line, far=900.0) or (e[0] + dd[0] * 900.0, e[1] + dd[1] * 900.0)
            cls = "avenue" if ex["rank"] >= 15 else "street"
            if self._add_cut([e, hit], cls, "", "suburb", keep=bayou_keep, link=ex, min_len=30.0):
                chosen.append(e)
        # Estate roads: a 90 m estate either side, winding out to the
        # Beltway. Each showcase street carries on as one, and more fill gaps
        # along the outer drive wider than ESTATE_PITCH.
        starts = list(hits)
        for piece in lines_of(outer.intersection(hz.buffer(1.0))):
            if piece.length < 60.0:
                continue
            marks = sorted(piece.project(Point(h)) for h in hits if piece.distance(Point(h)) < 2.0)
            marks = [0.0] + marks + [piece.length]
            for lo, hi in zip(marks, marks[1:]):
                n_gap = int((hi - lo) / ESTATE_PITCH + 0.35)
                starts += [piece.interpolate(lo + (hi - lo) * i / n_gap).coords[0] for i in range(1, n_gap)]
        routes84 = self.routes_geom.buffer(84.0)
        hz_in = prep(hz.buffer(1.0))
        drawn = []
        k = 0
        for p in sorted(starts, key=lambda q: (q[1], q[0])):
            if not hz_in.contains(Point(p)):
                continue
            q = nearest_points(self.P, Point(p))[0].coords[0]
            nl = dist(p, q) or 1.0
            n = ((p[0] - q[0]) / nl, (p[1] - q[1]) / nl)
            far = self._ray_to(p, n, self.belt_line, far=900.0) or (p[0] + n[0] * 900.0, p[1] + n[1] * 900.0)
            a = (p[0] + n[0] * 47.5, p[1] + n[1] * 47.5)
            if dist(a, far) < 60.0:
                continue
            # One long bow each, all the same way (like contour lines), so
            # the estates between two roads keep their depth.
            pts = [p] + wavy(a, far, -ESTATE_WIND)
            line = LineString(pts)
            if line.intersection(routes84).length > 120.0 or any(line.crosses(o) for o in drawn):
                continue
            if self._add_cut(pts, "street", ESTATE_NAMES[k % len(ESTATE_NAMES)], "estate_road",
                             cut=routes84, keep=hz_keep, min_len=120.0):
                k += 1
                drawn.append(line)

    def _fringe_roads(self):
        """The north fringe: Capitol Hill rowhouse blocks. Streets from the
        city's exits about 100 m apart out to the Beltway (or a hill road),
        and one row street round the city's edge."""
        fz = self.zone_poly["fringe"]
        foot = self.mtn.poly.intersection(self.belt_poly).intersection(self.play_land)
        keep = unary_union([fz, self.zone_strip["fringe"], foot]).buffer(1.0)
        major40 = self.major_geom.buffer(40.0)
        cands = []
        for ex in self._exits_into(fz):
            e, d = ex["e"], ex["d"]
            ray = LineString([e, (e[0] + d[0] * 300.0, e[1] + d[1] * 300.0)])
            if ray.intersection(major40).length <= 100.0:
                cands.append(ex)
        stop = unary_union([self.belt_line, self.major_geom])
        drawn = []
        for ex in sorted(self._spread(cands, 100.0, 60.0), key=lambda x: (x["e"][0], x["e"][1])):
            e, d = ex["e"], ex["d"]
            hit = self._ray_to(e, d, unary_union([stop] + drawn), far=900.0)
            if hit is None:
                continue
            cls = "avenue" if ex["rank"] >= 15 else "street"
            drawn += self._add_cut([e, hit], cls, "", "rowhouse", keep=keep, link=ex, min_len=30.0)
        row = self._ring(110.0, 150.0)
        self._add_cut(list(row.coords), "street", FRINGE_ROW_NAME, "rowhouse",
                      keep=fz.buffer(1.0).difference(self.mtn.poly), min_len=30.0)

    def _eastside_roads(self):
        """The east side: LA arterial superblocks (avenues on from the city's
        boulevards about ARTERIAL_GAP apart, a boulevard round the middle),
        curving tract streets inside them, cul-de-sacs where a street stops
        short."""
        ez, bt = self.zone_poly["eastside"], self.zone_poly["beach_town"]
        strip = self.zone_strip["eastside"]
        keep_all = unary_union([ez, strip]).buffer(1.0)
        stop = unary_union([self.belt_line, self.palmetto, self.ocean_drive])
        major40 = self.major_geom.buffer(40.0)
        picks = []
        for ex in sorted(self._exits_into(ez), key=lambda x: (-x["rank"], x["n"], x["d"])):
            if ex["rank"] < 15 or any(dist(ex["e"], p["e"]) < ARTERIAL_GAP for p in picks):
                continue
            e, d = ex["e"], ex["d"]
            ray = LineString([e, (e[0] + d[0] * 300.0, e[1] + d[1] * 300.0)])
            if ray.intersection(major40).length > 100.0:
                continue
            picks.append(ex)
        k = 0
        for ex in sorted(picks, key=lambda x: (x["e"][1], x["e"][0])):
            e, d = ex["e"], ex["d"]
            hit = self._ray_to(e, d, stop)
            if hit is None:
                continue
            got = self._add_cut([e, hit], "avenue", ARTERIAL_NAMES[k % len(ARTERIAL_NAMES)], "arterial",
                                keep=keep_all, link=ex, min_len=30.0)
            k += 1 if got else 0
            self.arterials += [[piece, "h"] for piece in got]
        # Sunvale Boulevard round the middle, north to south, to Brisa Beach.
        shore_line = unary_union([self.ocean_drive, self.palmetto])
        g = self._ring(200.0, 150.0).intersection(unary_union([ez, bt]).buffer(1.0))
        if g.geom_type == "MultiLineString":
            g = linemerge(g)
        if lines_of(g):
            sp = max(lines_of(g), key=lambda q: q.length)
            if sp.coords[0][1] > sp.coords[-1][1]:
                sp = LineString(list(sp.coords)[::-1])
            ends = [sp.project(Point(h)) for h in self._points(sp.intersection(shore_line))]
            ends = [s for s in ends if s > 30.0]
            if ends:
                sp = substring(sp, 0.0, min(ends))
            got = self._add_cut(list(sp.coords), "avenue", SPINE_NAME, "arterial", min_len=30.0)
            self.arterials += [[piece, "v"] for piece in got]
            if got:
                self.spine = max(got, key=lambda q: q.length)
        for g in self.belt_pieces:
            if g.distance(ez) < 200.0:
                self.arterials.append([g, "v"])
        # Civic grounds: the school on the boulevard, the DMV on an arterial,
        # both out past the boulevard, so every city street carries on out
        # to it unbroken.
        # Where the urban outline leaves no room out there, they come in to
        # 60 m off the city instead (the tract streets they block drop out).
        h_arts = [a for a, o in self.arterials if o == "h"]
        school = dmv = None
        for gap in (200.0, 60.0):
            beyond = ez.difference(self.P.buffer(gap))
            if school is None and self.spine is not None:
                school = next((r for sgn in (-1.0, 1.0)
                               if (r := self._reserve(self.spine, sgn, SCHOOL_PLOT, beyond, "school_e"))), None)
            if dmv is None:
                dmv = next((r for a in h_arts for sgn in (1.0, -1.0)
                            if (r := self._reserve(a, sgn, DMV_PLOT, beyond, "dmv"))), None)
        # Tract streets: one from each of the city's exits into the east
        # side (52 m or more apart), on to Sunvale Boulevard and the Beltway,
        # so every one runs end to end between major roads. A half that would
        # run into civic grounds is left out.
        civic = [r["poly"].buffer(15.0) for r in self.reserved]
        arts = unary_union(h_arts)
        spine = self.spine if self.spine is not None else LineString()
        inner_stop = unary_union([spine, stop, arts, self.major_geom])
        tail_keep = unary_union([ez, bt, strip]).buffer(1.0)
        rows = []
        for ex in sorted(self._exits_into(ez), key=lambda x: (x["e"][1], x["e"][0])):
            if not arts.is_empty and arts.distance(Point(ex["e"])) < TRACT_ARTERIAL_MIN:
                continue
            if any(dist(ex["e"], r["e"]) < TRACT_PITCH_MIN for r in rows):
                continue
            rows.append(ex)
        on_spine = []
        for i, ex in enumerate(rows):
            e, d = ex["e"], ex["d"]
            amp = TRACT_BOW if i % 2 == 0 else -TRACT_BOW
            hit = self._ray_to(e, d, inner_stop)
            if hit is None:
                continue
            pts = wavy(e, hit, amp)
            if any(c.intersects(LineString(pts)) for c in civic):
                continue
            if not self._add_cut(pts, "street", "", "tract", keep=ez.buffer(1.0), link=ex):
                continue
            if not spine.is_empty and spine.distance(Point(hit)) < 1.0:
                on_spine.append(spine.project(Point(hit)))
                far = self._ray_to(hit, d, stop, far=1200.0)
                if far is not None:
                    pts = wavy(hit, far, amp)
                    if not any(c.intersects(LineString(pts)) for c in civic):
                        self._add_cut(pts, "street", "", "tract", keep=tail_keep)
        # Where the rows from the city leave a long stretch of the boulevard
        # bare, more rows run from it out to the Beltway.
        if not spine.is_empty:
            marks = [0.0] + sorted(on_spine) + [spine.length]
            j = 0
            for lo, hi in zip(marks, marks[1:]):
                if hi - lo <= 2.0 * TRACT_PITCH:
                    continue
                n = int((hi - lo) / TRACT_PITCH)
                for m in range(1, n):
                    p, t = _along(spine, lo + (hi - lo) * m / n)
                    if not arts.is_empty and arts.distance(Point(p)) < ARTERIAL_DEPTH:
                        continue
                    o = self._outward(p, t)
                    far = self._ray_to(p, o, stop, far=1200.0)
                    if far is None:
                        continue
                    pts = wavy(p, far, TRACT_BOW if j % 2 == 0 else -TRACT_BOW)
                    j += 1
                    if not any(c.intersects(LineString(pts)) for c in civic):
                        self._add_cut(pts, "street", "", "tract", keep=tail_keep)

    def _shore_roads(self):
        """The south shore: a grid like the South Bay's. A street from each of
        the city's exits into it runs down to Seabreeze Drive; lanes follow
        the city's edge across it, LOOP_PITCH apart. The civic grounds on
        Seabreeze Drive take the pieces they would cross."""
        sz = self.zone_poly["shore"]
        if sz.is_empty:
            return
        keep = unary_union([sz, self.zone_strip["shore"]]).buffer(1.0)
        mid = sz.centroid.x
        yd = self._drive_y(mid)
        if yd is not None:
            self._civic_bay(mid - 170.0, mid + 170.0, yd)
        civic = unary_union([r["poly"].buffer(8.0) for r in self.reserved if r["kind"] in ("green", "school_s")])
        chosen = []
        for ex in sorted(self._exits_into(sz), key=lambda x: (-x["rank"], x["e"][0], x["e"][1])):
            e, d = ex["e"], ex["d"]
            if any(dist(e, c) < SHORE_PITCH_MIN for c in chosen):
                continue
            hit = self._ray_to(e, d, self.ocean_drive, far=700.0)
            if hit is None:
                continue
            if not civic.is_empty and LineString([e, hit]).intersects(civic):
                continue
            cls = "avenue" if ex["rank"] >= 15 else "street"
            if self._add_cut([e, hit], cls, "", "collector" if cls == "avenue" else "stub", keep=keep, link=ex, min_len=20.0):
                chosen.append(e)
        names = iter(LOOP_NAMES * 3)
        # The loops keep 20 m off the grounds, so none passes askew within
        # the 10 m the grounds' squareness check looks (_square_to_roads).
        cut = unary_union([civic.buffer(12.0), self.ocean_drive.buffer(49.5)])
        for k in range(6):
            self._add_cut(list(self._ring(41.0 + LOOP_PITCH * k).coords), "street", next(names), "loop",
                          cut=cut, keep=sz.buffer(1.0), min_len=40.0)

    def _civic_bay(self, xa, xb, yd):
        """The village green (shops, pool, playground) and the public school
        side by side on Seabreeze Drive."""
        sz = self.zone_poly["shore"]
        hw = CLASSES["avenue"]["w"] * 0.5
        # The spare width goes 30% to each end and 40% between the two, so
        # they never overlap in a bay that only just fits them.
        free = (xb - xa) - GREEN_PLOT[0] - SCHOOL_PLOT[0]
        left = xa + free * 0.3
        for kind, size in (("green", GREEN_PLOT), ("school_s", SCHOOL_PLOT)):
            W, D = size
            c = (left + W * 0.5, yd - hw - 3.5 - D * 0.5)
            left += W + free * 0.4
            poly = lot_poly(c[0], c[1], math.pi, W, D)
            if not sz.contains(poly.buffer(2.0)):
                continue
            self.reserved.append({"kind": kind, "c": c, "yaw": math.pi, "W": W, "D": D, "poly": poly, "n": (0.0, -1.0)})

    def _pier_site(self):
        """Brisa Beach's pier: out over the Gulf from the foot of the cross
        street nearest the promenade, square to the coast."""
        d, inland = self.brisa_dirs
        sea = (-inland[0], -inland[1])
        prom = next((self.L([lm["pos"]])[0] for lm in self.world["landmarks"] if lm["id"] == "brisa_promenade"), None)
        feet = sorted(self.brisa_feet, key=lambda f: dist(f[0], prom) if prom else 0.0)
        W, D = LOT["pier_rides"]
        for foot, base in feet:
            far = (foot[0] + sea[0] * 400.0, foot[1] + sea[1] * 400.0)
            hit = self._first_hit(foot, far, self.gulf.boundary)
            if hit is None:
                continue
            root = (hit[0] - sea[0] * 2.0, hit[1] - sea[1] * 2.0)
            c = (root[0] + sea[0] * D * 0.5, root[1] + sea[1] * D * 0.5)
            yaw = yaw_facing(*sea)
            poly = lot_poly(c[0], c[1], yaw, W, D)
            if poly.intersection(self.gulf).area < 0.95 * poly.area:
                continue
            if self.routes_geom.distance(poly) < 60.0:
                continue
            self.pier = {"c": c, "yaw": yaw, "poly": poly, "foot": foot, "root": root, "sea": sea}
            return

    def _pier_land(self):
        """The pier's deck joins the play area (it stands over the Gulf)."""
        if self.pier is None:
            return
        poly = self.pier["poly"]
        self.A = self.A.union(poly)
        self.play_land = self.play_land.union(poly)
        self.play_land_prep = prep(self.play_land.buffer(-0.5))
        self.A_prep = prep(self.A)

    def _clip_add(self, pts, poly, cls, name="", kind="suburb"):
        out = []
        for piece in lines_of(LineString(pts).intersection(poly)):
            if piece.length >= 30.0:
                self.add(list(piece.coords), cls, name, kind)
                out.append(piece)
        return out

    def towns(self):
        drivable = [s for s in self.sources if CLASSES[s[1]]["graph"]]
        tree = STRtree([s[0] for s in drivable])
        for t in self.world["towns"]:
            if t.get("phase", 1) > 2:
                continue
            c = self.L([t["pos"]])[0]
            i = tree.nearest(Point(c))
            main = drivable[i][0]
            s = main.project(Point(c))
            a = main.interpolate(max(0, s - 10)).coords[0]
            b = main.interpolate(min(main.length, s + 10)).coords[0]
            dx, dy = b[0] - a[0], b[1] - a[1]
            n = math.hypot(dx, dy) or 1.0
            u = (dx / n, dy / n)
            v = (-u[1], u[0])
            m = main.interpolate(s).coords[0]
            kind = t["kind"]
            region = t.get("region", "")
            if kind == "truck_stop":
                style = "truck_stop"
                streets, half, backs = [], 0, []
            elif kind == "town":
                style = "town"
                streets, half, backs = [-150, -75, 0, 75, 150], 160, [-110, 110]
            else:
                style = "bayou_village" if region == "saltgrass" else "village"
                streets, half, backs = [-70, 0, 70], 110, []
            for k in streets:
                p = (m[0] + u[0] * k, m[1] + u[1] * k)
                self._clip_add([(p[0] - v[0] * half, p[1] - v[1] * half), (p[0] + v[0] * half, p[1] + v[1] * half)],
                               self.play_land.buffer(1.0), "street", "", "town")
            for k in backs:
                p = (m[0] + v[0] * k, m[1] + v[1] * k)
                self._clip_add([(p[0] - u[0] * 190, p[1] - u[1] * 190), (p[0] + u[0] * 190, p[1] + u[1] * 190)],
                               self.play_land.buffer(1.0), "street", "", "town")
            r = 200 if kind == "town" else (130 if kind != "truck_stop" else 90)
            zone = Point(m).buffer(r).intersection(self.play_land)
            self.town_zones.append({"id": t["id"], "name": t["name"], "kind": kind, "style": style,
                                    "center": m, "u": u, "v": v, "zone": zone, "main": i})

    # --- Golden Flats farmland (farmland.py) ------------------------------------------

    def _flats_area(self):
        reg = next(r for r in self.world["regions"] if r["id"] == "golden_flats")
        poly = Polygon(self.L(reg["polygon"])).intersection(self.play_land)
        keep_out = [self.mtn.poly.buffer(40.0), self.P.buffer(40.0)]
        keep_out += [z[1].buffer(40.0) for z in self.zones]
        keep_out += [t["zone"].buffer(25.0) for t in self.town_zones]
        return poly.difference(unary_union(keep_out)).difference(self.water.buffer(14.0))

    def _flats_expressway(self):
        """The Golden Flats Expressway off the Beltway, laid before the
        suburb streets so it has first pick of the city's west exits."""
        belt = self.belt_line
        bp = prep(self.belt_poly)
        first = next((k for k, p in enumerate(farmland.EXPRESSWAY) if not bp.contains(Point(p))), 0)
        p0 = farmland.EXPRESSWAY[first]
        on = nearest_points(Point(p0), belt)[1].coords[0]
        u = unit((p0[0] - on[0], p0[1] - on[1]))
        # Start a few metres off the Beltway; join_ends ties it on.
        pts = [(on[0] + u[0] * 4.0, on[1] + u[1] * 4.0)] + farmland.EXPRESSWAY[first:]
        self._route(pts, "highway", farmland.EXPRESSWAY_NAME, self.A.difference(self.P))

    def farm_roads(self):
        """The section grid of paved roads and dirt tracks on the Golden
        Flats (the Expressway is laid with the Beltway, _flats_expressway)."""
        area = self._flats_area()
        drivable = [s[0] for s in self.sources if CLASSES[s[1]]["graph"]]
        # County Road 10 bridges the Cinder Lower, so the land west of it
        # (Ember Canyon Drive) is reached.
        y = farmland.BRIDGE_Y
        crossing = self.water.buffer(16.0).intersection(box(-2700.0, y - 30.0, -1900.0, y + 30.0))
        pieces = farmland.grid_roads(area, drivable, {y: crossing})
        # Only grid pieces that reach the road network (crossing it, or
        # within join_ends' reach of it without crossing water).
        net = unary_union(drivable)
        left = [(LineString(p[0]), p) for p in pieces]
        grown = True
        while grown:
            grown = False
            keep = []
            for line, pc in left:
                ok = line.distance(net) < 2.0
                if not ok:
                    for end in (line.coords[0], line.coords[-1]):
                        q = nearest_points(Point(end), net)[1]
                        seg = LineString([end, q.coords[0]])
                        if seg.length < 90.0 and not self.water_prep.intersects(seg.buffer(1.0)):
                            ok = True
                            break
                if ok:
                    self.add(pc[0], pc[1], pc[2], pc[3])
                    net = net.union(line)
                    grown = True
                else:
                    keep.append((line, pc))
            left = keep
        self.flats_area = area

    def farm_canals(self):
        """The irrigation canals beside two section roads: their ground (kept
        clear of lots) and a pump house at each one's river end."""
        lines = farmland.canal_lines(self.flats_area)
        water, banks = farmland.canal_zones(lines, self.road_area)
        self.farm_zones = {"canal": water, "canal_bank": banks}
        for poly in polys_of(unary_union([water, banks])):
            self.lot_grid.add(poly.buffer(2.0))
        self.canal_ends = [max(l.coords, key=lambda c: c[0]) for l in lines]
        self.canal_area = unary_union([water, banks])

    def farm_fields(self):
        """Pump houses at the canals' heads, then the fields: pivot circles
        and strip fields on the farmland left clear, and each pivot's
        sprinkler spans as plots of their own."""
        for e in self.canal_ends:
            if self._place_near((e[0] - 30.0, e[1] - 20.0), "pump_house", "", "golden_flats", reach=90.0):
                continue
            # No road near this canal's head: the pump house stands by the
            # canal on its own (its keeper comes along the bank).
            if not any(self.try_lot(q[0], q[1], 0.0, "pump_house", "", "golden_flats")
                       for q in self._spiral((e[0] - 20.0, e[1]), 60.0, 4.0)):
                print("WARNING: no room for a pump house at", e)
        taken = [self.road_area.buffer(farmland.CLEAR), self.canal_area.buffer(3.0)]
        taken += [lot_poly(l["x"], l["y"], l["yaw"], l["w"], l["d"]).buffer(farmland.CLEAR) for l in self.lots]
        taken += [lot_poly(q["x"], q["y"], q["yaw"], q["w"], q["d"]).buffer(farmland.CLEAR) for q in self.plots]
        for path in self.paths:
            taken.append(LineString(path).buffer(4.0))
        free = self.flats_area.difference(unary_union(taken))
        fields, arms, pivots = farmland.lay_fields(free)
        self.pivots = [[round(c[0], 1), round(c[1], 1), round(r, 1), crop] for c, r, crop in pivots]
        self.farm_zones.update(fields)
        for (x, y), a, span, variant in arms:
            yaw = math.atan2(-math.sin(a), math.cos(a))
            self.plots.append({"x": x, "y": y, "yaw": yaw, "w": span, "d": 6.0, "type": "pivot",
                               "parts": [part("sprinkler", 0.0, 0.0, span, 6.0, 0.0, variant)]})
        self.pivot_count = sum(1 for a in arms if a[3] & 1)

    def trim_route_stubs(self):
        """A route that starts on nothing (Serena Causeway on the river bank)
        is cut back to the first road it crosses, up to 250 m in."""
        drivable = [s for s in self.sources if CLASSES[s[1]]["graph"]]
        for src in drivable:
            if src[3] != "route":
                continue
            others = unary_union([o[0] for o in drivable if o is not src])
            for at_end in (False, True):
                line = src[0]
                end = Point(line.coords[-1] if at_end else line.coords[0])
                if self.P.distance(end) < 3.0 or self.A.exterior.distance(end) < 12.0 or others.distance(end) < 2.0:
                    continue
                cuts = [line.project(Point(h)) for h in self._points(line.intersection(others))]
                if not cuts:
                    continue
                s_cut = max(cuts) if at_end else min(cuts)
                if (line.length - s_cut if at_end else s_cut) <= 250.0:
                    src[0] = substring(line, 0.0, s_cut) if at_end else substring(line, s_cut, line.length)

    def join_ends(self):
        """Ends of roads that stop just short of another road are joined to it."""
        drivable = [s for s in self.sources if CLASSES[s[1]]["graph"]]
        lines = [s[0] for s in drivable]
        tree = STRtree(lines)
        link_pts = [Point(l["pos"]) for l in self.links]
        extra = []
        for i, (line, cls, name, kind) in enumerate(drivable):
            for end in (line.coords[0], line.coords[-1]):
                p = Point(end)
                if any(p.distance(q) < 3.0 for q in link_pts):
                    continue
                if self.P.distance(p) < 3.0:
                    continue
                if dist(end, OBSERVATORY_ROAD_END) < 3.0:
                    continue  # its drive carries on to the observatory
                if dist(end, SUMMIT_SITES["car_park"][:2]) < 3.0:
                    continue  # Mount Calder Road ends in the summit car park (a link from there ran 47% down the top)
                touching = [j for j in tree.query(p.buffer(2.0)) if j != i and lines[j].distance(p) < 2.0]
                if touching:
                    continue
                # At the play area's edge only a road just short is joined.
                best, best_d = None, (4.0 if self.A.exterior.distance(p) < 12.0 else 90.0)
                for j in tree.query(p.buffer(90.0)):
                    if j == i:
                        continue
                    d = lines[j].distance(p)
                    if d < best_d:
                        best, best_d = j, d
                if best is None or best_d < 0.5:
                    continue
                q = nearest_points(p, lines[best])[1]
                # A road that overshoots one it has just crossed or met (up
                # to 60 m) is cut back to there rather than tied back to it.
                cross = [line.project(Point(h)) for h in self._points(line.intersection(lines[best]))]
                if line.distance(q) < 1.0:
                    cross.append(line.project(q))
                cross = [s for s in cross if q.distance(line.interpolate(s)) < 30.0 and 1.0 < s < line.length - 1.0
                         and abs(line.project(p) - s) < 60.0]
                if cross:
                    at_end = end == line.coords[-1]
                    s_cut = max(cross) if at_end else min(cross)
                    drivable[i][0] = substring(line, 0.0, s_cut) if at_end else substring(line, s_cut, line.length)
                    line = drivable[i][0]
                    continue
                seg = LineString([end, q.coords[0]])
                if seg.crosses(self.P) or self.water_prep.intersects(seg.buffer(1.0)):
                    continue
                if seg.intersection(line.buffer(0.5)).length > 2.0:
                    continue  # it would run back along its own road
                extra.append([seg, cls if CLASSES[cls]["prio"] <= CLASSES[drivable[best][1]]["prio"] else drivable[best][1], name, kind])
        self.sources.extend(extra)

    def trim_farm_stubs(self):
        """A section road that runs out at the flats' edge onto nothing is cut
        back to the last road it crosses (or, crossing none, made a dirt
        track), so no paved road stops dead in a field; repeated, since a cut
        can take away another one's crossing."""
        cut = True
        while cut:
            cut = False
            drivable = [s for s in self.sources if CLASSES[s[1]]["graph"]]
            for src in drivable:
                if src[3] != "farm_grid":
                    continue
                others = unary_union([o[0] for o in drivable if o is not src])
                for at_end in (False, True):
                    line = src[0]
                    end = Point(line.coords[-1] if at_end else line.coords[0])
                    if self.A.exterior.distance(end) < 12.0 or others.distance(end) < 2.0:
                        continue
                    cuts = [line.project(Point(h)) for h in self._points(line.intersection(others))]
                    cuts = [c for c in cuts if 1.0 < c < line.length - 1.0]
                    if not cuts:
                        # Hung only from its far end: a dirt track to the field.
                        src[1], src[2], src[3] = "track", "", "farm_track"
                        cut = True
                        break
                    s_cut = max(cuts) if at_end else min(cuts)
                    src[0] = substring(line, 0.0, s_cut) if at_end else substring(line, s_cut, line.length)
                    cut = True

    # --- Graph --------------------------------------------------------------------

    def _snap_tees(self, drivable):
        """A road that ends on another one's side (within 2 m of it, but not
        at its end) is moved to end exactly on a new vertex of it, so the
        noding splits the other road there and the two meet at a junction."""
        tree = STRtree([s[0] for s in drivable])
        for i, src in enumerate(drivable):
            for k in (0, -1):
                p = Point(src[0].coords[k])
                for j in tree.query(p.buffer(2.0)):
                    j = int(j)
                    if j == i:
                        continue
                    other = drivable[j][0]
                    # One that ends on the side already is snapped too unless
                    # it ends on a vertex: a point "on" a line in floating
                    # point need not split it in the noding.
                    d = other.distance(p)
                    if d >= 2.0 or p.coords[0] in other.coords:
                        continue
                    if min(dist(p.coords[0], other.coords[0]), dist(p.coords[0], other.coords[-1])) < 3.0:
                        continue
                    s = other.project(p)
                    q = other.interpolate(s).coords[0]
                    drivable[j][0] = LineString(list(substring(other, 0.0, s).coords) + list(substring(other, s, other.length).coords)[1:])
                    pts = list(src[0].coords)
                    pts[k] = q
                    src[0] = LineString(pts)
                    tree = STRtree([s_[0] for s_ in drivable])
                    break

    def graph(self):
        drivable = [s for s in self.sources if CLASSES[s[1]]["graph"]]
        self._snap_tees(drivable)
        trails = [s for s in self.sources if not CLASSES[s[1]]["graph"]]
        noded = lines_of(unary_union([s[0] for s in drivable]))
        tree = STRtree([s[0] for s in drivable])
        pieces = []
        for g in noded:
            if g.length < 0.5:
                continue
            mid = g.interpolate(0.5, normalized=True)
            cands = [j for j in tree.query(mid.buffer(1.0)) if drivable[j][0].distance(mid) < 0.6]
            if not cands:
                cands = [int(tree.nearest(mid))]
            j = max(cands, key=lambda k: CLASSES[drivable[k][1]]["prio"])
            pieces.append({"pts": list(g.coords), "cls": drivable[j][1], "name": drivable[j][2], "tag": drivable[j][3]})
        # Junctions: snap ends together.
        node_pos = []
        grid = {}

        def node_at(p):
            key = (round(p[0] / 4.0), round(p[1] / 4.0))
            for kx in (key[0] - 1, key[0], key[0] + 1):
                for ky in (key[1] - 1, key[1], key[1] + 1):
                    for k in grid.get((kx, ky), []):
                        if dist(node_pos[k], p) < 3.0:
                            return k
            node_pos.append(p)
            grid.setdefault(key, []).append(len(node_pos) - 1)
            return len(node_pos) - 1

        for pc in pieces:
            pc["a"] = node_at(pc["pts"][0])
            pc["b"] = node_at(pc["pts"][-1])
        # Merge junctions joined by a very short piece.
        parent = list(range(len(node_pos)))

        def find(k):
            while parent[k] != k:
                parent[k] = parent[parent[k]]
                k = parent[k]
            return k

        for pc in pieces:
            if LineString(pc["pts"]).length < 12.0:
                ra, rb = find(pc["a"]), find(pc["b"])
                if ra != rb:
                    parent[rb] = ra
        groups = {}
        for k in range(len(node_pos)):
            groups.setdefault(find(k), []).append(k)
        # A merged junction stays on the city exit when it holds one: the
        # average can drift it past the test's 6 m from the plan junction.
        exit_pts = [l["pos"] for l in self.links]
        new_pos = {}
        for root, members in groups.items():
            at_exit = [node_pos[m] for m in members if any(dist(node_pos[m], q) < 3.0 for q in exit_pts)]
            if at_exit:
                new_pos[root] = tuple(at_exit[0])
                continue
            new_pos[root] = (sum(node_pos[m][0] for m in members) / len(members),
                             sum(node_pos[m][1] for m in members) / len(members))
        out = []
        seen = set()
        for pc in pieces:
            a, b = find(pc["a"]), find(pc["b"])
            if a == b:
                continue
            key = (min(a, b), max(a, b), round(LineString(pc["pts"]).length / 5.0))
            if key in seen:
                continue
            seen.add(key)
            pts = pc["pts"]
            pts[0] = new_pos[a]
            pts[-1] = new_pos[b]
            out.append({"pts": pts, "cls": pc["cls"], "name": pc["name"], "tag": pc["tag"], "a": a, "b": b})
        pieces = out
        # Drop short spurs (overshoots past a junction), twice.
        link_pts = [l["pos"] for l in self.links]
        for _ in range(3):
            deg = {}
            for pc in pieces:
                deg[pc["a"]] = deg.get(pc["a"], 0) + 1
                deg[pc["b"]] = deg.get(pc["b"], 0) + 1
            keep = []
            for pc in pieces:
                length = LineString(pc["pts"]).length
                dead = [n for n in (pc["a"], pc["b"]) if deg[n] == 1 and not any(dist(new_pos[n], q) < 3.0 for q in link_pts)]
                if dead and length < 25.0 and (deg[pc["a"]] > 1 or deg[pc["b"]] > 1):
                    continue
                keep.append(pc)
            pieces = keep
        self.pieces = pieces
        self.trails = trails
        self.junction_pos = new_pos

    def build_graph_arrays(self):
        """Each piece is cut into straight graph edges a traffic car can
        follow; shape nodes in between, junctions at the ends."""
        nodes = []
        index = {}

        def nid(root):
            if root not in index:
                index[root] = len(nodes)
                p = self.junction_pos[root]
                nodes.append([round(p[0], 2), round(p[1], 2)])
            return index[root]

        edges = []
        roads = []
        for pc in self.pieces:
            c = CLASSES[pc["cls"]]
            line = LineString(pc["pts"])
            step = c["step"]
            if pc["tag"] != "route":
                # Curving suburb streets: short enough edges to follow the bend.
                step = min(step, max(4.0, 0.35 * min_radius(line)))
            pts = resample(line, step)
            ids = [nid(pc["a"])]
            for p in pts[1:-1]:
                nodes.append([round(p[0], 2), round(p[1], 2)])
                ids.append(len(nodes) - 1)
            ids.append(nid(pc["b"]))
            first = len(edges)
            for k in range(len(ids) - 1):
                p, q = nodes[ids[k]], nodes[ids[k + 1]]
                mid = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
                bridge = 1 if self.water_prep.contains(Point(mid)) else 0
                edges.append([ids[k], ids[k + 1], CLASS_NAMES.index(pc["cls"]), len(roads), bridge])
            roads.append({"cls": CLASS_NAMES.index(pc["cls"]), "name": pc["name"], "nodes": ids, "e0": first})
        self.nodes = nodes
        self.edges = edges
        self.roads = roads
        # Links to the plan: the country node at each link point.
        links = []
        for l in self.links:
            best, best_d = -1, 4.0
            for root, k in index.items():
                d = dist(self.junction_pos[root], l["pos"])
                if d < best_d:
                    best, best_d = k, d
            if best >= 0 and [best, l["plan_node"]] not in links:
                links.append([best, l["plan_node"]])
        self.link_pairs = links

    # --- Walls and bridges --------------------------------------------------------

    def walls(self):
        gaps = []
        for e in self.edges:
            if e[4]:
                p, q = self.nodes[e[0]], self.nodes[e[1]]
                w = CLASSES[CLASS_NAMES[e[2]]]["w"]
                gaps.append(LineString([p, q]).buffer(w * 0.5 + 0.6, cap_style="flat"))
        # Bridges reach a little onto the banks so the gap is clean.
        bridge_runs = self._bridge_runs()
        for run in bridge_runs:
            gaps.append(LineString(run["pts"]).buffer(run["w"] * 0.5 + 0.6, cap_style="flat"))
        edge = self.play_land.boundary.difference(self.P.buffer(0.5))
        if gaps:
            edge = edge.difference(unary_union(gaps))
        walls = []
        for ln in lines_of(edge):
            pts = list(ln.simplify(0.8).coords)
            for a, b in zip(pts, pts[1:]):
                if dist(a, b) < 0.3:
                    continue
                for piece in _split(a, b, 30.0):
                    walls.append([round(piece[0][0], 2), round(piece[0][1], 2), round(piece[1][0], 2), round(piece[1][1], 2),
                                  self._wall_kind(piece[0], piece[1])])
        self.wall_list = walls
        # A rail that crosses a run's bank segment crosses the road there at
        # grade, on land: the deck stops short of it (the wall gap above keeps
        # the whole run).
        rails = [rl[0] for rl in self.rails]
        for run in bridge_runs:
            nodes = self.roads[run["road"]]["nodes"]
            for k, end in ((run["from"], "from"), (run["to"] - 1, "to")):
                if run[end] == run["water"][0 if end == "from" else 1] or run["to"] - run["from"] < 2:
                    continue
                seg = LineString([self.nodes[nodes[k]], self.nodes[nodes[k + 1]]])
                if any(seg.intersects(rl) for rl in rails):
                    run[end] += 1 if end == "from" else -1
        self.bridges = bridge_runs

    def _wall_kind(self, a, b):
        """0: a river or lake bank, 1: the Gulf coast, 2: the play area's
        edge on land."""
        m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1.0
        for sgn in (1.0, -1.0):
            q = Point(m[0] - dy / n * 4.0 * sgn, m[1] + dx / n * 4.0 * sgn)
            if self.gulf.contains(q):
                return 1
            if self.water_prep.contains(q):
                return 0
        return 2

    def _bridge_runs(self):
        runs = []
        for r, road in enumerate(self.roads):
            e0 = road["e0"]
            n = len(road["nodes"]) - 1
            k = 0
            while k < n:
                if not self.edges[e0 + k][4]:
                    k += 1
                    continue
                s = k
                while k < n and self.edges[e0 + k][4]:
                    k += 1
                # One more segment each side lands it on the bank.
                s0 = max(0, s - 1)
                s1 = min(n, k + 1)
                pts = [self.nodes[road["nodes"][i]] for i in range(s0, s1 + 1)]
                runs.append({"road": r, "from": s0, "to": s1, "water": (s, k), "pts": pts, "w": CLASSES[CLASS_NAMES[road["cls"]]]["w"]})
        return runs

    # --- Lots ---------------------------------------------------------------------

    def lot_setup(self):
        polys = []
        for pc in self.pieces:
            w = CLASSES[pc["cls"]]["w"]
            polys.append(LineString(pc["pts"]).buffer(w * 0.5 + 2.5, cap_style="round"))
        for t in self.trails:
            polys.append(t[0].buffer(CLASSES["trail"]["w"] * 0.5 + 1.0))
        for rl in self.rails:
            polys.append(rl[0].buffer(4.0))
        self.road_area = unary_union(polys)
        self.road_prep = prep(self.road_area)
        self.lot_grid = PolyGrid()
        self.plot_grid = PolyGrid()
        # Heliport aprons (data/heliports.json, scripts/heliports.gd) and
        # their margin stay clear: no lot, plot or tree on them.
        for hp in json.loads((ROOT / "data" / "heliports.json").read_text())["heliports"]:
            hx, hz = hp["size"][0] * 0.5 + 5.0, hp["size"][1] * 0.5 + 5.0
            cy, sy = math.cos(-hp["yaw"]), math.sin(-hp["yaw"])
            apron = Polygon([(hp["pos"][0] + x * cy - z * sy, hp["pos"][1] + x * sy + z * cy)
                             for x, z in ((-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz))])
            self.lot_grid.add(apron)
            self.plot_grid.add(apron)
        self.plots = []
        # The road pieces lots and plots front onto.
        self.front_lines = [LineString(pc["pts"]) for pc in self.pieces]
        self.front_half = [CLASSES[pc["cls"]]["w"] * 0.5 for pc in self.pieces]
        self.front_tree = STRtree(self.front_lines)
        # The graph edges as the game sees them, for the square-to-road
        # measure the tests use (tests/test_runner.gd _turn_off_road).
        self.edge_segs = [LineString([self.nodes[e[0]], self.nodes[e[1]]]) for e in self.edges]
        self.edge_tree = STRtree(self.edge_segs)
        self.node_edges = {}
        for i, e in enumerate(self.edges):
            self.node_edges.setdefault(e[0], []).append(i)
            self.node_edges.setdefault(e[1], []).append(i)

    def _node_tangent(self, n, e):
        a, b = self.nodes[self.edges[e][0]], self.nodes[self.edges[e][1]]
        L = dist(a, b) or 1.0
        t = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
        around = self.node_edges.get(n, [])
        if len(around) != 2:
            return t
        o = around[0] if around[1] == e else around[1]
        p, q = self.nodes[self.edges[o][0]], self.nodes[self.edges[o][1]]
        M = dist(p, q) or 1.0
        u = ((q[0] - p[0]) / M, (q[1] - p[1]) / M)
        if u[0] * t[0] + u[1] * t[1] < 0.0:
            u = (-u[0], -u[1])
        if u[0] * t[0] + u[1] * t[1] < 0.87:
            return t
        m = math.hypot(t[0] + u[0], t[1] + u[1]) or 1.0
        return ((t[0] + u[0]) / m, (t[1] + u[1]) / m)

    def _road_turn(self, f, yaw):
        """How far (deg) a frame of this yaw whose front centre is f turns off
        the road edge within 8 m of f, measured on the graph edges with their
        tangents blended at bends, as the tests measure it; -1 with none."""
        best, pick = math.inf, -1
        fp = Point(f)
        for j in self.edge_tree.query(fp.buffer(40.0)):
            j = int(j)
            seg = self.edge_segs[j]
            if seg.length <= 0.1:
                continue
            dd = seg.distance(fp) - CLASSES[CLASS_NAMES[self.edges[j][2]]]["w"] * 0.5
            if dd < best:
                best, pick = dd, j
        if pick < 0 or best > 8.0:
            return -1.0
        a, b = self.nodes[self.edges[pick][0]], self.nodes[self.edges[pick][1]]
        ab = (b[0] - a[0], b[1] - a[1])
        u = min(1.0, max(0.0, ((f[0] - a[0]) * ab[0] + (f[1] - a[1]) * ab[1]) / (ab[0] ** 2 + ab[1] ** 2)))
        ta = self._node_tangent(self.edges[pick][0], pick)
        tb = self._node_tangent(self.edges[pick][1], pick)
        dx, dy = ta[0] + (tb[0] - ta[0]) * u, ta[1] + (tb[1] - ta[1]) * u
        m = math.hypot(dx, dy) or 1.0
        ax = (math.cos(yaw), -math.sin(yaw))
        return math.degrees(math.asin(min(1.0, abs(ax[0] * dy / m - ax[1] * dx / m))))

    def _frontage(self, q):
        """The road piece nearest q: (point on its centreline, unit tangent,
        unit normal towards q, half width, piece index, distance along it)."""
        i = int(self.front_tree.nearest(Point(q)))
        line = self.front_lines[i]
        s = line.project(Point(q))
        p, t = _along(line, s)
        n = (-t[1], t[0])
        if (q[0] - p[0]) * n[0] + (q[1] - p[1]) * n[1] < 0:
            n = (-n[0], -n[1])
        return p, t, n, self.front_half[i], i, s

    def _front_spot(self, q, w, d, setback=3.5, tol=1.5):
        """A w x d rect square to the road nearest q, its front edge `setback`
        metres off the road's edge: (centre, yaw, normal, polygon) or None
        when it would not run alongside that road (past a road's end, or
        on a bend too tight for its width)."""
        p, t, n, hw, i, s = self._frontage(q)
        line = self.front_lines[i]
        if s < 2.0 or s > line.length - 2.0:
            return None
        off = hw + setback + d * 0.5
        c = (p[0] + n[0] * off, p[1] + n[1] * off)
        yaw = yaw_facing(n[0], n[1])
        poly = lot_poly(c[0], c[1], yaw, w, d)
        a, b = poly.exterior.coords[0], poly.exterior.coords[1]
        if abs(line.distance(Point(a)) - line.distance(Point(b))) > tol:
            return None
        return c, yaw, n, poly

    def _free(self, poly, yaw):
        if not self.play_land_prep.contains(poly.buffer(1.0)):
            return False
        if self.road_prep.intersects(poly):
            return False
        if self.lot_grid.hits(poly) or self.plot_grid.hits(poly):
            return False
        if not self._square_to_roads(poly, yaw):
            return False
        a, b = poly.exterior.coords[0], poly.exterior.coords[1]
        return self._road_turn(((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5), yaw) < 3.5

    def _square_to_roads(self, poly, yaw):
        """Whether every road within 10 m of poly runs along or across it
        (within 6 degrees): no lot ends up askew beside a second road."""
        ax = (math.cos(yaw), -math.sin(yaw))
        cen = poly.centroid
        for j in self.front_tree.query(poly.buffer(20.0)):
            line = self.front_lines[int(j)]
            if line.distance(poly) > self.front_half[int(j)] + 10.0:
                continue
            _, t = _along(line, line.project(cen))
            ang = math.degrees(math.asin(min(1.0, abs(ax[0] * t[1] - ax[1] * t[0]))))
            if 6.0 < ang < 84.0:
                return False
        return True

    def try_lot(self, x, y, yaw, kind, landmark="", zone="", size=None, plot=-1):
        """Adds a lot when it is free; a lot inside a plot (plot >= 0) was
        laid out with the plot and goes in as it is."""
        w, d = size if size else LOT[kind]
        if plot < 0:
            poly = lot_poly(x, y, yaw, w, d)
            if not self._free(poly, yaw):
                return False
            self.lot_grid.add(poly.buffer(1.5))
        self.lots.append({"x": x, "y": y, "yaw": yaw, "w": w, "d": d, "kind": kind, "id": landmark, "zone": zone,
                          "plot": plot})
        return True

    def add_plot(self, c, yaw, w, d, ptype, parts):
        self.plot_grid.add(lot_poly(c[0], c[1], yaw, w, d).buffer(1.5))
        self.plots.append({"x": c[0], "y": c[1], "yaw": yaw, "w": w, "d": d, "type": ptype, "parts": parts})
        return len(self.plots) - 1

    def _drive_to_road(self, f, n, gap):
        """A gravel drive from f straight back to the road's edge."""
        r = (f[0] - n[0] * gap, f[1] - n[1] * gap)
        self.paths.append([[round(f[0], 2), round(f[1], 2)], [round(r[0], 2), round(r[1], 2)]])

    def _spiral(self, p, reach, step=6.0):
        for r in _steps(0.0, reach, step):
            m = max(1, int(r / 4))
            for k in range(m):
                ang = k / m * math.tau
                yield (p[0] + math.cos(ang) * r, p[1] + math.sin(ang) * r)

    def landmark_lots(self):
        for lm in self.world["landmarks"]:
            kind = LANDMARK_KIND.get(lm["id"])
            if not kind or lm.get("phase", 1) > 2:
                continue
            p = self.L([lm["pos"]])[0]
            if self.P.contains(Point(p)) or not self.A.contains(Point(p)):
                print("skip landmark", lm["id"], "at", p)
                continue
            if kind == "mansion" and self._estate_near(p, lm["id"]):
                continue
            if not self._place_near(p, kind, lm["id"]):
                print("WARNING: no room for landmark", lm["id"])

    def _place_near(self, p, kind, ident, zone="", reach=160.0):
        """A lot as near p as there is room for, square to the road it fronts."""
        w, d = LOT[kind]
        tried = set()
        for q in self._spiral(p, reach):
            spot = self._front_spot(q, w, d)
            if spot is None:
                continue
            c, yaw, n, poly = spot
            key = (round(c[0] / 2.0), round(c[1] / 2.0))
            if key in tried or dist(c, p) > reach + 40.0:
                continue
            tried.add(key)
            if self.try_lot(c[0], c[1], yaw, kind, ident, zone):
                self._drive_to_road(frame_point(c, yaw, 0.0, -d * 0.5), n, 3.5)
                return True
        return False

    # --- Plots ----------------------------------------------------------------------

    def _estate_near(self, p, ident):
        tried = set()
        for q in self._spiral(p, 220.0, 8.0):
            for size in ((100.0, 100.0), (90.0, 90.0), (84.0, 84.0)):
                key = (round(q[0] / 4.0), round(q[1] / 4.0), size)
                if key in tried:
                    continue
                tried.add(key)
                # A grand estate's house turns its garden to the sun and the
                # view too (_view_turn): since the west lobe (#116) covers the
                # hillside estates that did, the Hale Estate is the one.
                if self.estate_at(q, size, ident, "", 0, grand=True, sun=True):
                    return True
        return False

    def estate_at(self, q, size, ident="", zone="", style=0, grand=False, sun=False, tol=1.5):
        """Walled (style 0) or hedged (1) grounds round a mansion, on a plot
        square to the road nearest q (tol: how far its front corners may sit
        unevenly off a winding road)."""
        W, D = size
        spot = self._front_spot(q, W, D, tol=tol)
        if spot is None:
            return False
        c, yaw, n, poly = spot
        if not self._free(poly, yaw):
            return False
        turn = self._view_turn(c, yaw, W, D, sun)
        if turn != 0.0:
            self.view_turns += 1
        parts, house, gate = estate_layout(W, D, turn, style, self.rng, grand)
        k = self.add_plot(c, yaw, W, D, "estate", parts)
        h = frame_point(c, yaw, house[0], house[1])
        self.try_lot(h[0], h[1], yaw + turn, "mansion", ident, zone, (house[2], house[2]), plot=k)
        if turn == 0.0:
            g = frame_point(c, yaw, GATE_LANE, -D * 0.5 + GATE_IN + LOT["gatehouse"][1] * 0.5)
            self.try_lot(g[0], g[1], yaw, "gatehouse", "", zone, plot=k)
        self._drive_to_road(frame_point(c, yaw, gate[0], gate[1]), n, gate[1] + D * 0.5 + 3.5)
        return True

    def _view_turn(self, c, yaw, W, D, sun=False):
        """The turn of an estate's house off its plot: 0, or 45 degrees either
        way on a square plot whose view (the nearest water, or with `sun` the
        south and the west) lies off to the back or side, so the garden side
        turns to it. A view straight behind keeps the house on the axis."""
        if min(W, D) < 80.0 or abs(W - D) > 8.0:
            return 0.0
        views = []
        if self.water.distance(Point(c)) < 350.0:
            w = nearest_points(Point(c), self.water)[1].coords[0]
            views.append((w[0] - c[0], w[1] - c[1]))
        if sun:
            views += [(0.0, 1.0), (-1.0, 0.0)]  # the midday and the evening sun
        cs, sn = math.cos(yaw), math.sin(yaw)
        for dx, dy in views:
            lx, lz = dx * cs - dy * sn, dx * sn + dy * cs
            a = math.atan2(lx, lz)
            if abs(a) < math.pi / 8:
                return 0.0
            if abs(a) < math.pi * 5 / 8:
                return math.copysign(math.pi / 4, lx)
        return 0.0

    def cluster_at(self, q, W, D, kinds, style, zone):
        """Dwellings scattered over a fenced yard on a plot square to the road
        nearest q (small towns, the bayou, trailer parks)."""
        spot = self._front_spot(q, W, D)
        if spot is None:
            return False
        c, yaw, n, poly = spot
        if not self._free(poly, yaw):
            return False
        parts, homes, gx = cluster_layout(W, D, kinds, style, self.rng)
        if len(homes) < 2:
            return False
        k = self.add_plot(c, yaw, W, D, "cluster", parts)
        for kind, x, z, rot in homes:
            h = frame_point(c, yaw, x, z)
            self.try_lot(h[0], h[1], yaw + rot, kind, "", zone, CLUSTER_LOT.get(kind), plot=k)
        self._drive_to_road(frame_point(c, yaw, gx, -D * 0.5), n, 3.5)
        return True

    def farmyard_at(self, q, template, zone):
        """A farmstead on a fenced yard: house nearest the road, barn, silos
        and sheds behind, a windbreak on the north and west sides."""
        deck = self.house_decks.setdefault(template, [])
        if not deck:
            deck.extend(k for k, cards in FARM_HOUSES[template] for _ in range(cards))
            self.rng.shuffle(deck)
        # Homes take the sizes in turn per kind (not from the rng, so no
        # other zone's lots shift and every plan turns up); a size is used
        # up only by a home that is built.
        sizes = collections.Counter(self.home_sizes)
        lots, parts, (W, D) = farmyard_layout(template, self.rng, deck[-1], sizes)
        spot = self._front_spot(q, W, D, 6.0)
        if spot is None:
            return False
        c, yaw, n, poly = spot
        if not self._free(poly, yaw):
            return False
        # Every home faces a road within reach of its front (lot_reach); on
        # a curve (the mountain roads) a home off the middle can face away.
        for _kind, x, z, size in lots:
            if size is not None and not self.road_prep.intersects(LineString(
                    [frame_point(c, yaw, x, z - size[1] * 0.5), frame_point(c, yaw, x, z - size[1] * 0.5 - REACH_MAX + 2.5)])):
                return False
        deck.pop()
        self.home_sizes = sizes
        # Windbreak rows along the sides (not the front) that face north (-y) or west (-x).
        x0, z0, x1, z1 = -W * 0.5, -D * 0.5, W * 0.5, D * 0.5
        sides = []
        for lx, lz, a, b in ((0, 1, (x0 + 3, z1 - 3), (x1 - 3, z1 - 3)), (-1, 0, (x0 + 3, z0 + 8), (x0 + 3, z1 - 3)),
                             (1, 0, (x1 - 3, z0 + 8), (x1 - 3, z1 - 3))):
            cs, sn = math.cos(yaw), math.sin(yaw)
            wx, wy = lx * cs + lz * sn, -lx * sn + lz * cs
            sides.append((max(-wy, -wx), a, b))
        sides.sort(key=lambda s: -s[0])
        # The rows keep 5 m off the homes' lots (their fences and yards).
        homes = unary_union([box(x - s[0] * 0.5 - 5.0, z - s[1] * 0.5 - 5.0, x + s[0] * 0.5 + 5.0, z + s[1] * 0.5 + 5.0)
                             for _, x, z, s in lots if s is not None] or [Point(0, 0).buffer(0.01)])
        for score, a, b in sides[:2]:
            if score > 0.3:
                for g in polys_of_lines(LineString([a, b]).difference(homes)):
                    if g.length >= 10.0:
                        parts.append(seg_part("trees", g.coords[0], g.coords[-1], 8.0, TREE_KINDS.index("oak")))
        k = self.add_plot(c, yaw, W, D, "farmyard", parts)
        for kind, x, z, size in lots:
            h = frame_point(c, yaw, x, z)
            self.try_lot(h[0], h[1], yaw, kind, "", zone, size=size, plot=k)
        gate = next(p for p in parts if p[0] == "drive")
        self._drive_to_road(frame_point(c, yaw, gate[1], -D * 0.5), n, 6.0)
        return True

    def street_lots(self):
        zone_of = {}
        for name, poly in self.zones:
            zone_of[name] = prep(poly)
        towns = [(t, prep(t["zone"])) for t in self.town_zones]
        shops = {}  # kind -> frontage points of shops placed in cluster styles
        towers = {}  # condo towers per tile: two at most keeps a tile's triangles down
        for pi, pc in enumerate(self.pieces):
            cls = pc["cls"]
            if cls not in ("street", "avenue", "road", "highway", "lane"):  # no lots front the freeway
                continue
            line = LineString(pc["pts"])
            w = CLASSES[cls]["w"]
            mid = line.interpolate(0.5, normalized=True)
            style = None
            zname = ""
            for t, tp in towns:
                if tp.contains(mid):
                    style = t["style"]
                    zname = t["id"]
            sides = (1.0, -1.0)
            if style is None:
                for name, zp in zone_of.items():
                    if zp.contains(mid):
                        style = name
                        zname = name
            if style is None:
                # A road along a zone's edge (the Beltway): the zone beside it.
                for sg in sides:
                    q = Point(self._side_point(line, line.length * 0.5, sg, w * 0.5 + 20.0))
                    for name, zp in zone_of.items():
                        if zp.contains(q):
                            style, zname, sides = name, name, (sg,)
            if style is None or style == "truck_stop":
                continue
            tag = pc["tag"]
            if style == "heights":
                if tag.startswith("flats") or tag in ("showcase", "estate_road", "beltway", "route"):
                    continue
                style = "estates"
            elif style == "eastside":
                if tag in ("tract", "bulb"):
                    continue
                if tag in ("arterial", "beltway", "route"):
                    style = "arterial"
            elif style in ("mountain", "hillside"):
                if cls in ("highway", "freeway", "track") or tag in ("observatory", "fire_road", "beltway", "route", "track"):
                    continue
            elif style == "shore":
                if tag == "seabreeze":
                    style = "beach"
                    by = {sg: Point(self._side_point(line, line.length * 0.5, sg, w * 0.5 + 20.0)) for sg in (1.0, -1.0)}
                    sides = (min(by, key=lambda sg: self.gulf.distance(by[sg])),)  # the sea side only
                elif tag in PATTERN_WALKS["shore"]:
                    continue
            table = SUBURB_STYLE[style]
            kinds = list(table)
            weights = [table[k] for k in kinds]
            homes = CLUSTER_HOMES.get(style)
            for sgn in sides:
                s = 14.0
                while s < line.length - 14.0:
                    kind = self.rng.choices(kinds, weights)[0]
                    if style == "estates":
                        # Square plot first until a house has turned to its
                        # view (see _heights_lots).
                        width = 84.0 if self.view_turns == 0 else float(round(self.rng.uniform(64.0, 84.0)))
                        if s + width > line.length - 14.0:
                            break
                        if any(self.estate_at(self._side_point(line, s + width * 0.5, sgn, w * 0.5 + 3.5 + depth * 0.5),
                                              (width, depth), "", zname, 0, sun=True)
                               for depth in ((width,) if width >= 80.0 else ()) + (88.0, 76.0, 64.0)):
                            s += width + self.rng.uniform(2.0, 6.0)
                        else:
                            s += 8.0
                        continue
                    elif homes and kind in DWELLINGS:
                        sub = "trailers" if kind == "trailer_home" else style
                        width = self.rng.uniform(62.0, 78.0) if sub == "trailers" else self.rng.uniform(48.0, 64.0)
                        depth = 46.0 if sub == "trailers" else self.rng.uniform(34.0, 44.0)
                        if s + width > line.length - 14.0:
                            break
                        q = self._side_point(line, s + width * 0.5, sgn, w * 0.5 + 3.5 + depth * 0.5)
                        if self.cluster_at(q, width, depth, ["trailer_home"] if sub == "trailers" else homes, sub, zname):
                            s += width + self.rng.uniform(3.0, 9.0)
                        else:
                            s += 4.0
                        continue
                    if style == "mountain" and self.rng.random() < 0.6:
                        # Hillside homes stand apart, with scrub between.
                        s += self.rng.uniform(25.0, 60.0)
                        continue
                    if style == "hillside":
                        # Rows and apartments low down, bigger homes higher up.
                        here = line.interpolate(s).coords[0]
                        band = next(t for top, t in HILL_BANDS if self.mtn.raw_at(here) < top)
                        kind = self.rng.choices(list(band), list(band.values()))[0]
                    if style in ("mountain", "hillside"):
                        # Homes only on the lower slopes (HOME_TOP), and none in
                        # Red Pine (phase 3: forest and the summit only).
                        here = line.interpolate(s).coords[0]
                        if self.mtn.raw_at(here) > HOME_TOP or self.red_pine.contains(Point(here)):
                            s += 20.0
                            continue
                        # Higher up, a mansion more often than a house.
                        if style == "mountain" and kind == "house" and self.rng.random() < min(0.8, self.mtn.raw_at(here) / 400.0):
                            kind = "mansion"
                        # Not where the road climbs steeply past the frontage:
                        # the lot's pad could not sit level with it.
                        ha = self.mtn.profile_near(line.interpolate(s).coords[0], 1.0)
                        hb = self.mtn.profile_near(line.interpolate(min(s + LOT[kind][0], line.length)).coords[0], 1.0)
                        if ha is not None and hb is not None and abs(hb - ha) > 0.09 * LOT[kind][0]:
                            s += 10.0
                            continue
                        # Nor between two legs of a switchback: another way
                        # near the lot at another height cuts its pad.
                        lw, ld = LOT[kind]
                        mid = self._side_point(line, min(s + lw * 0.5, line.length), sgn, w * 0.5 + ld * 0.5 + 3.0)
                        if ha is not None and any(
                                got and abs(got[1] - ha) > 3.0 for got in
                                (self.mtn._profile_z(pf, mid, lambda hw: hw + (lw + ld) * 0.5 + 12.0)
                                 for pf in self.mtn.profiles)):
                            s += 10.0
                            continue
                    if kind == "condo_tower":
                        tq = self._side_point(line, min(s + 13.0, line.length), sgn, w * 0.5 + 16.5)
                        tkey = (math.floor(tq[0] / TILE), math.floor(tq[1] / TILE))
                        if towers.get(tkey, 0) >= 2:
                            kind = "deco_hotel"
                        else:
                            towers[tkey] = towers.get(tkey, 0) + 1
                    lw, ld = LOT[kind]
                    if homes and kind not in DWELLINGS:
                        here = line.interpolate(s).coords[0]
                        if any(math.hypot(here[0] - o[0], here[1] - o[1]) < CLUSTER_SHOP_GAP for o in shops.get(kind, ())):
                            s += 4.0
                            continue
                    s += lw * 0.5
                    if s > line.length - 14.0:
                        break
                    p = line.interpolate(s).coords[0]
                    a = line.interpolate(max(0, s - 2)).coords[0]
                    b = line.interpolate(min(line.length, s + 2)).coords[0]
                    tx, ty = b[0] - a[0], b[1] - a[1]
                    tn = math.hypot(tx, ty) or 1.0
                    nx, ny = -ty / tn * sgn, tx / tn * sgn
                    off = w * 0.5 + 3.5 + ld * 0.5
                    q = (p[0] + nx * off, p[1] + ny * off)
                    if self.try_lot(q[0], q[1], yaw_facing(nx, ny), kind, "", zname):
                        if homes and kind not in DWELLINGS:
                            shops.setdefault(kind, []).append(p)
                        s += lw * 0.5 + self.rng.uniform(2.0, 6.0)
                    else:
                        s += 4.0 - lw * 0.5 + lw * 0.5
        # Lifeguard towers along the sand at Brisa Beach and the shore.
        d, inland = self.brisa_dirs
        coast = LineString(self.L([[5100, 8600], [5600, 8650], [7600, 8650], [8400, 8000], [8780, 7470]]))
        for s in _steps(80.0, coast.length - 40.0, 160.0):
            p = coast.interpolate(s)
            for off in (30.0, 36.0):
                a = coast.interpolate(max(0, s - 2)).coords[0]
                b = coast.interpolate(min(coast.length, s + 2)).coords[0]
                tx, ty = b[0] - a[0], b[1] - a[1]
                tn = math.hypot(tx, ty)
                # The Gulf is to the right of this line (south-east): land on the left.
                nx, ny = ty / tn, -tx / tn
                q = (p.x + nx * off, p.y + ny * off)
                if self.try_lot(q[0], q[1], yaw_facing(-nx, -ny), "lifeguard_tower", "", "sand"):
                    break

    @staticmethod
    def _side_point(line, s, sgn, off):
        """The point `off` metres to one side (sgn) of line at s."""
        p, t = _along(line, s)
        return (p[0] - t[1] * sgn * off, p[1] + t[0] * sgn * off)

    def town_lots(self):
        for t in self.town_zones:
            m, u, v = t["center"], t["u"], t["v"]
            if t["kind"] == "truck_stop":
                for kind, k in (("truck_stop", 0.0), ("motel", 80.0), ("gas_station", -70.0), ("diner", 140.0)):
                    p = (m[0] + u[0] * k, m[1] + u[1] * k)
                    self._place_near(p, kind, "", t["id"], reach=90.0)
                continue
            civic = ["town_hall", "gas_station"] if t["kind"] == "town" else ["general_store"]
            for kind in civic:
                self._place_near((m[0] + v[0] * 30, m[1] + v[1] * 30), kind, "", t["id"], reach=150.0)

    def farm_lots(self):
        """Farmsteads along the country roads, camps along the bayou tracks,
        villas and farms among the vines."""
        regions = {r["id"]: prep(Polygon(self.L(r["polygon"]))) for r in self.world["regions"] if r.get("phase") == 2}
        town_prep = [prep(t["zone"].buffer(60)) for t in self.town_zones]
        suburb = prep(unary_union([z[1] for z in self.zones]).buffer(60))
        flats_farms = []
        flats_homes = []
        for i, pc in enumerate(self.pieces):
            if pc["cls"] not in ("road", "lane", "track", "highway"):
                continue
            line = self.front_lines[i]
            s = self.rng.uniform(60, 300)
            while s < line.length - 40:
                p = line.interpolate(s)
                if suburb.contains(p) or any(tp.contains(p) for tp in town_prep):
                    s += 200
                    continue
                reg = next((rid for rid, rp in regions.items() if rp.contains(p)), None)
                sgn = 1.0 if self.rng.random() < 0.5 else -1.0
                q = self._side_point(line, s, sgn, self.front_half[i] + 30.0)
                if reg == "golden_flats":
                    # One farm to a few sections: the pivots need the room.
                    # Between them, a homestead here and there on its own.
                    placed = False
                    gap = self.rng.uniform(380, 700)
                    if all(dist(q, f) > FLATS_FARM_GAP for f in flats_farms):
                        placed = self.farmyard_at(q, "flats", reg)
                        if placed:
                            flats_farms.append(q)
                    if not placed and all(dist(q, f) > HOMESTEAD_GAP for f in flats_farms + flats_homes):
                        placed = self.farmyard_at(q, "homestead", reg)
                        if placed:
                            flats_homes.append(q)
                            gap = self.rng.uniform(200, 420)
                elif reg == "saltgrass":
                    placed = self.cluster_at(q, self.rng.uniform(40.0, 56.0), self.rng.uniform(34.0, 42.0),
                                             ["shack", "stilt_house", "trailer_home"], "camp", reg)
                    gap = self.rng.uniform(220, 450)
                elif reg == "verdant_hills":
                    # Until one house turns to its view, every hillside site
                    # tries an estate first (on the coin toss alone, a
                    # regeneration could leave none turned).
                    if self.view_turns == 0 or self.rng.random() < 0.5:
                        placed = self.estate_at(q, (84.0, 84.0), "", reg, 1, sun=True) or \
                            self.estate_at(q, (72.0, 80.0), "", reg, 1)
                    else:
                        placed = self.farmyard_at(q, "hills", reg)
                    gap = self.rng.uniform(450, 800)
                else:
                    s += 200
                    continue
                s += gap if placed else 60

    def field_plots(self):
        """Crop fields on the flats and vineyard blocks and orchards in the
        hills: cells square to the road they front, several deep, one crop
        to a run of cells."""
        regions = {r["id"]: Polygon(self.L(r["polygon"])) for r in self.world["regions"] if r.get("phase") == 2}
        block = unary_union([z[1] for z in self.zones] + [t["zone"] for t in self.town_zones]).buffer(20.0)
        areas = []
        # Golden Flats has its section fields (farm_fields) instead.
        for rid in ("verdant_hills",):
            if rid in regions:
                areas.append((rid, prep(regions[rid].intersection(self.play_land).difference(block))))
        choice = {}
        for i, line in enumerate(self.front_lines):
            hw = self.front_half[i]
            for sgn in (1.0, -1.0):
                for s0 in _steps(4.0, line.length - FIELD_PITCH + 4.0, FIELD_PITCH):
                    s = s0 + FIELD_PITCH * 0.5
                    p, t = _along(line, s)
                    nx, ny = -t[1] * sgn, t[0] * sgn
                    yaw = yaw_facing(nx, ny)
                    for k in range(7):
                        off = hw + 6.0 + FIELD_PITCH * k + FIELD_CELL * 0.5
                        c = (p[0] + nx * off, p[1] + ny * off)
                        poly = lot_poly(c[0], c[1], yaw, FIELD_CELL, FIELD_CELL)
                        rid = next((r for r, ap in areas if ap.contains(poly)), None)
                        if rid is None or not self._free(poly, yaw):
                            continue
                        key = (i, sgn, int(s0 // 150.0), k // 3)
                        if key not in choice:
                            roll = self.rng.random()
                            rot = 0.0 if self.rng.random() < 0.5 else math.pi / 2
                            if rid == "golden_flats":
                                pick = None if roll < 0.08 else ("crop", rot, self.rng.randrange(4))
                            else:
                                pick = ("vines", rot, 0) if roll < 0.6 else (
                                    ("orchard", 0.0, TREE_KINDS.index("fruit")) if roll < 0.75 else None)
                            choice[key] = pick
                        pick = choice[key]
                        if pick is None:
                            continue
                        self.add_plot(c, yaw, FIELD_CELL, FIELD_CELL, "field",
                                      [part(pick[0], 0.0, 0.0, FIELD_CELL - 2.0, FIELD_CELL - 2.0, pick[1], pick[2])])

    # --- Outskirts patterns: lots and grounds -------------------------------------

    def outskirts_lots(self):
        self.zone_prep = {name: prep(poly) for name, poly in self.zones}
        self._pier_lots()
        self._heights_lots()
        self._fringe_blocks()
        self._eastside_lots()
        self._shore_lots()

    def _zone_at(self, p):
        pt = Point(p)
        for name, zp in self.zone_prep.items():
            if zp.contains(pt):
                return name
        return ""

    def _pieces(self, tags, zone=None):
        """Road pieces whose tag starts with one of `tags`, their middle in zone."""
        out = []
        for i, pc in enumerate(self.pieces):
            if not pc["tag"].startswith(tuple(tags)):
                continue
            if zone and self._zone_at(self.front_lines[i].interpolate(0.5, normalized=True).coords[0]) != zone:
                continue
            out.append(i)
        return out

    def _walk_lots(self, pi, sgn, w, d, place, zone=None, gap=ROW_GAP, setback=3.5):
        """Rects w x d one after another along one side of road piece pi,
        square to it and set back from its kerb; place(c, yaw, n, poly) adds
        what stands there and says whether it fitted."""
        line = self.front_lines[pi]
        hw = self.front_half[pi]
        zp = self.zone_prep.get(zone) if zone else None
        s = 4.0 + w * 0.5
        count = 0
        while s <= line.length - 4.0 - w * 0.5:
            p, t = _along(line, s)
            n = (-t[1] * sgn, t[0] * sgn)
            off = hw + setback + d * 0.5
            c = (p[0] + n[0] * off, p[1] + n[1] * off)
            yaw = yaw_facing(*n)
            poly = lot_poly(c[0], c[1], yaw, w, d)
            a, b = poly.exterior.coords[0], poly.exterior.coords[1]
            ok = abs(line.distance(Point(a)) - line.distance(Point(b))) <= 1.5 and (zp is None or zp.contains(Point(c)))
            if ok and place(c, yaw, n, poly):
                count += 1
                _, t0 = _along(line, max(0.0, s - 4.0))
                _, t1 = _along(line, min(line.length, s + 4.0))
                bend = (t0[0] * t1[1] - t0[1] * t1[0]) / 8.0 * sgn  # > 0: bending towards the lot
                s += (w + gap) / max(0.3, 1.0 - bend * (hw + setback))
            else:
                s += 2.0
        return count

    def _plain(self, kind, zone, size=None):
        return lambda c, yaw, n, poly: self.try_lot(c[0], c[1], yaw, kind, "", zone, size)

    # The pier at Brisa Beach and its boardwalk.
    def _pier_lots(self):
        pr = self.pier
        if pr is None:
            return
        W, D = LOT["pier_rides"]
        c, yaw, sea = pr["c"], pr["yaw"], pr["sea"]
        self.lots.append({"x": c[0], "y": c[1], "yaw": yaw, "w": W, "d": D, "kind": "pier_rides", "id": "",
                          "zone": "beach_town", "plot": -1})
        self.lot_grid.add(pr["poly"].buffer(1.5))
        # A boardwalk from the end of the street over the sand to the pier.
        length = dist(pr["foot"], pr["root"]) - 15.0 - 1.0
        if length > 10.0:
            mid = 1.0 + length * 0.5
            q = (pr["root"][0] - sea[0] * mid, pr["root"][1] - sea[1] * mid)
            parts = [part("paving", 0.0, 0.0, 20.0, length, 0.0, 1)]
            for z in _steps(-length * 0.5 + 6.0, length * 0.5 - 3.0, 18.0):
                for x in (-11.5, 11.5):
                    parts.append(part("trees", x, z, 0.0, 0.0, 0.0, TREE_KINDS.index("palm")))
            self.add_plot(q, yaw, 20.0, length, "civic", parts)

    # Magnolia Heights: the flats.
    def _heights_lots(self):
        flats = self._pieces(("flats:",), "heights")
        if not flats:
            return
        hz = self.zone_poly["heights"]
        # The post office on the inner ring, the fire station on the outer.
        for ring, frac, toward, kind in ((self.flats_rings[:1], 0.5, 1.0, "post_office"),
                                         (self.flats_rings[-1:], 0.3, -1.0, "fire_station")):
            got = [g for r_ in ring for g in lines_of(r_.intersection(hz))]
            if not got:
                continue
            g = max(got, key=lambda q: q.length)
            p = g.interpolate(frac, normalized=True).coords[0]
            q = nearest_points(self.P, Point(p))[0].coords[0]
            u = unit((q[0] - p[0], q[1] - p[1]))
            self._place_near((p[0] + u[0] * 30.0 * toward, p[1] + u[1] * 30.0 * toward), kind, "", "heights", 200.0)
        for pi in flats:
            for sgn in (1.0, -1.0):
                self._walk_lots(pi, sgn, *FLATS_LOT, self._plain("house", "heights", FLATS_LOT), "heights")
        # Estates along the winding roads, the Beltway and the route out west.
        hp = self.zone_prep["heights"]
        for pi, pc in enumerate(self.pieces):
            if pc["tag"] not in ("estate_road", "beltway", "route"):
                continue
            line = self.front_lines[pi]
            if line.intersection(hz).length < 60.0:
                continue
            hw = self.front_half[pi]
            for sgn in (1.0, -1.0):
                s = 6.0
                while s < line.length - 40.0:
                    # Hillside houses turn their gardens to the sun and the
                    # view (_view_turn, square plots only): until one has,
                    # each site tries the full square plot first (phase 2's
                    # mountain zone took most of Verdant Hills' sites).
                    width = 84.0 if self.view_turns == 0 else float(round(self.rng.uniform(64.0, 84.0)))
                    if s + width > line.length - 6.0:
                        break
                    ok = False
                    for depth in ((width,) if width >= 80.0 else ()) + (88.0, 76.0, 64.0):
                        q = self._side_point(line, s + width * 0.5, sgn, hw + 3.5 + depth * 0.5)
                        if hp.contains(Point(q)) and self.estate_at(q, (width, depth), "", "heights", 0, sun=True, tol=4.0):
                            ok = True
                            break
                    s += width + self.rng.uniform(2.0, 6.0) if ok else 8.0

    # The north fringe: rowhouse blocks round an H alley.
    def _fringe_blocks(self):
        fz = self.zone_poly["fringe"]
        self.block_count = 0
        for b in polys_of(fz.difference(self.road_area)):
            if b.area < 3000.0:
                continue
            mrr = b.minimum_rotated_rectangle
            if b.area / mrr.area < 0.95:
                continue
            cs = list(mrr.exterior.coords)[:4]
            e0 = (cs[1][0] - cs[0][0], cs[1][1] - cs[0][1])
            e1 = (cs[2][0] - cs[1][0], cs[2][1] - cs[1][1])
            l0, l1 = math.hypot(*e0), math.hypot(*e1)
            lu = e0 if l0 >= l1 else e1
            U, V = max(l0, l1) * 0.5, min(l0, l1) * 0.5
            if U < 40.0 or V < 35.0:
                continue
            u = (lu[0] / max(l0, l1), lu[1] / max(l0, l1))
            yaw = math.atan2(-u[1], u[0])  # local x along u, local z along (-u.y, u.x)
            c = mrr.centroid.coords[0]
            inner = b.buffer(-13.0)
            if inner.is_empty or self.lot_grid.hits(inner) or self.plot_grid.hits(inner):
                continue
            self._h_block(c, yaw, U, V)

    def _face(self, c, yaw, lx, lz):
        """What lies 3 m past a block's face: 'road', 'frame' or None."""
        q = Point(frame_point(c, yaw, lx, lz))
        if self.road_prep.contains(q):
            return "road"
        if self.P.contains(q):
            return "frame"
        return None

    def _h_block(self, c, yaw, U, V):
        inset = {"road": 1.0, "frame": 5.0}
        fz = {sz: self._face(c, yaw, 0.0, sz * (V + 3.0)) for sz in (-1, 1)}
        fx = {sx: self._face(c, yaw, sx * (U + 3.0), 0.0) for sx in (-1, 1)}
        legs = [-(U - ALLEY_IN), U - ALLEY_IN] if U >= 46.0 else [0.0]
        rows = []  # (lx, lz, w, outward sign, along z?)
        for sz in (-1, 1):
            if fz[sz] is None:
                continue
            zc = sz * (V - inset[fz[sz]] - ROW_DEPTH * 0.5)
            ends = [-U + (inset[fx[-1]] if fx[-1] else 1.0)] + [v for g in legs for v in (g - 2.5, g + 2.5)] + \
                   [U - (inset[fx[1]] if fx[1] else 1.0)]
            for a, b in zip(ends[::2], ends[1::2]):
                rows += [(x, zc, w, sz, False) for x, w in self._row_split(a, b)]
        for sx in (-1, 1):
            if fx[sx] is None:
                continue
            xc = sx * (U - inset[fx[sx]] - ROW_DEPTH * 0.5)
            a = -V + ((inset[fz[-1]] + ROW_DEPTH + ROW_GAP) if fz[-1] else 1.0)
            b = V - ((inset[fz[1]] + ROW_DEPTH + ROW_GAP) if fz[1] else 1.0)
            rows += [(xc, z, w, sx, True) for z, w in self._row_split(a, b)]
        placed = 0
        for lx, lz, w, sgn, side in rows:
            q = frame_point(c, yaw, lx, lz)
            # The row faces out of the block (its front, -z, at the face).
            ry = yaw + (-math.pi * 0.5 * sgn if side else (0.0 if sgn < 0 else math.pi))
            if self.try_lot(q[0], q[1], ry, "rowhouse_row", "", "fringe", (round(w, 2), ROW_DEPTH)):
                placed += 1
        if placed < 2:
            return
        # The yards and the alley: a plot over the whole block.
        zb = {sz: (V - (inset[fz[sz]] + ROW_DEPTH) if fz[sz] else V - 1.0) for sz in (-1, 1)}
        # The frame street's outer 5 m lies inside the block: the lawn and
        # the alley necks stop at its edge, where the rows front.
        cz = {sz: inset["frame"] if fz[sz] == "frame" else 0.0 for sz in (-1, 1)}
        cx = {sx: inset["frame"] if fx[sx] == "frame" else 0.0 for sx in (-1, 1)}
        parts = [part("lawn", (cx[-1] - cx[1]) * 0.5, (cz[-1] - cz[1]) * 0.5,
                      2.0 * U - cx[-1] - cx[1], 2.0 * V - cz[-1] - cz[1])]
        for g in legs:
            parts.append(part("alley", g, (zb[1] - zb[-1]) * 0.5, ALLEY, zb[1] + zb[-1]))
            for sz in (-1, 1):
                if fz[sz] is not None:
                    parts.append(part("alley", g, sz * (zb[sz] + V - cz[sz]) * 0.5, ALLEY_NECK,
                                      V - cz[sz] - zb[sz], 0.0, 1))
        if len(legs) == 2:
            parts.append(part("alley", 0.0, 0.0, 2.0 * (U - ALLEY_IN) - ALLEY, ALLEY))
        tree = TREE_KINDS.index("plane")
        for sz in (-1, 1):
            z = sz * (ALLEY * 0.5 + (zb[sz] - ALLEY * 0.5) * 0.5)
            for x in ([g * 0.5 for g in legs] if len(legs) == 2 else [-U * 0.5, U * 0.5]):
                parts.append(part("trees", x, z, 0.0, 0.0, 0.0, tree))
        self.add_plot(c, yaw, 2.0 * U, 2.0 * V, "block", parts)
        self.block_count += 1

    @staticmethod
    def _row_split(a, b):
        """Equal rows filling a..b with ROW_GAP between: [(centre, width)]."""
        L = b - a
        if L < 12.0:
            return []
        n = max(1, round((L + ROW_GAP) / (ROW_TARGET + ROW_GAP)))
        w = (L - (n - 1) * ROW_GAP) / n
        return [(a + w * 0.5 + k * (w + ROW_GAP), w) for k in range(n)]

    # Civic grounds laid out as a plot with their building(s) as plot lots.
    def _civic_plot(self, r):
        c, yaw, W, D = r["c"], r["yaw"], r["W"], r["D"]
        poly = lot_poly(c[0], c[1], yaw, W, D)
        if not self._free(poly, yaw):
            print("WARNING: no room for", r["kind"])
            return False
        fz = -D * 0.5
        lots = []
        if r["kind"] in ("school_e", "school_s"):
            parts = [part("lawn", 0.0, 0.0, W, D),
                     part("parking", -W * 0.5 + 23.0, fz + 22.0, 40.0, 36.0, 0.0, 1),
                     part("playground", W * 0.5 - 21.0, fz + 19.0, 32.0, 26.0),
                     part("paving", 0.0, fz + 2.0, 24.0, 4.0),
                     part("field", -W * 0.25 + 3.0, fz + 46.0 + (D - 46.0) * 0.5, W * 0.5 - 8.0, D - 50.0, 0.0, 2),
                     part("field", W * 0.25 - 3.0, fz + 46.0 + (D - 46.0) * 0.5, W * 0.5 - 14.0, D - 50.0, 0.0, 1)]
            lots.append(("public_school", 0.0, fz + 4.0 + 20.0))
        elif r["kind"] == "dmv":
            parts = [part("lawn", 0.0, 0.0, W, D),
                     part("parking", W * 0.5 - 33.0, fz + 17.0, 56.0, 30.0, 0.0, 0),
                     part("course", 0.0, D * 0.5 - 20.0, W - 10.0, 36.0)]
            lots.append(("dmv_office", -W * 0.5 + 25.0, fz + 2.0 + 15.0))
        else:  # the village green
            parts = [part("lawn", 0.0, 0.0, W, D),
                     part("parking", -W * 0.5 + 36.0, fz + 15.0, 66.0, 26.0, 0.0, 0),
                     part("paving", -W * 0.5 + 36.0, fz + 35.0, 66.0, 6.0),
                     part("pool", W * 0.5 - 30.0, fz + 22.0, 34.0, 22.0),
                     part("playground", W * 0.5 - 30.0, D * 0.5 - 20.0, 26.0, 20.0),
                     part("paving", 8.0, 0.0, 4.0, D - 4.0)]
            for k in range(6):
                lots.append(("shopfront", -W * 0.5 + 8.0 + 10.6 * k + 5.0, fz + 38.0 + 7.0))
            for x in _steps(-W * 0.5 + 6.0, W * 0.5 - 6.0, 16.0):
                parts.append(part("trees", x, D * 0.5 - 4.0, 0.0, 0.0, 0.0, TREE_KINDS.index("plane")))
        k = self.add_plot(c, yaw, W, D, "civic", parts)
        for kind, x, z in lots:
            q = frame_point(c, yaw, x, z)
            self.try_lot(q[0], q[1], yaw, kind, "", self._zone_at(c), plot=k)
        self._drive_to_road(frame_point(c, yaw, 0.0, fz), r["n"], 3.5)
        return True

    # The east side: civic grounds, corner malls, tract houses.
    def _eastside_lots(self):
        for r in self.reserved:
            if r["kind"] in ("school_e", "dmv"):
                self._civic_plot(r)
        hs = [a for a, o in self.arterials if o == "h"]
        vs = [a for a, o in self.arterials if o == "v"]
        k = 0
        ezp = self.zone_prep["eastside"]
        for h in hs:
            for v in vs:
                if h is v:
                    continue
                for J in self._points(h.intersection(v)):
                    # The crossing's own axes: u along h, w across it on
                    # v's side. A shallow crossing gets no corner lots.
                    u = _along(h, h.project(Point(J)))[1]
                    vt = _along(v, v.project(Point(J)))[1]
                    if abs(u[0] * vt[0] + u[1] * vt[1]) > 0.5:
                        continue
                    w = (-u[1], u[0])
                    if w[0] * vt[0] + w[1] * vt[1] < 0.0:
                        w = (-w[0], -w[1])
                    # A mini-mall on one corner and gas stations on two
                    # others, turning round from one crossing to the next.
                    quads = [(1, 1), (-1, 1), (-1, -1), (1, -1)]
                    quads = [q for q in quads[k % 4:] + quads[:k % 4]
                             if ezp.contains(Point(J[0] + (q[0] * u[0] + q[1] * w[0]) * 40.0,
                                                   J[1] + (q[0] * u[1] + q[1] * w[1]) * 40.0))]
                    mall = next((q for q in quads if self._corner(J, q[0], q[1], "mall", u, w)), None)
                    gas = 0
                    for q in quads:
                        if q != mall and gas < 2 and self._corner(J, q[0], q[1], "gas", u, w):
                            gas += 1
                    k += 1
        ez = self.zone_poly["eastside"]
        if self.spine is not None:
            p, t = _along(self.spine, self.spine.length * 0.66)
            n = self._outward(p, t)
            self._place_near((p[0] + n[0] * 40.0, p[1] + n[1] * 40.0), "fire_station", "", "eastside", 220.0)
        got = list(lines_of(self._ring(60.0).intersection(ez)))
        if got:
            p = max(got, key=lambda q: q.length).interpolate(0.33, normalized=True).coords[0]
            self._place_near(p, "post_office", "", "eastside", 220.0)
        # Full-depth lots first, then shallow ones where the tract streets
        # run closer together.
        for size in (TRACT_LOT, TRACT_LOT_SHALLOW):
            for pi in self._pieces(("tract", "bulb"), "eastside"):
                for sgn in (1.0, -1.0):
                    self._walk_lots(pi, sgn, *size, self._plain("house", "eastside", size), "eastside")

    def _corner(self, J, sx, sy, role, u=(1.0, 0.0), w=(0.0, 1.0)):
        """A corner mini-mall (two strips in an L round a parking square) or
        a gas station on one corner of two arterials. u runs along the
        first arterial, w along the second (x, y below are in that frame)."""
        def at(x, y):
            return (J[0] + x * u[0] + y * w[0], J[1] + x * u[1] + y * w[1])

        o = CLASSES["avenue"]["w"] * 0.5 + 3.5
        yaw_h = yaw_facing(w[0] * sy, w[1] * sy)  # fronting the first arterial
        yaw_v = yaw_facing(u[0] * sx, u[1] * sx)  # fronting the second
        if role == "gas":
            gw, gd = LOT["gas_station"]
            c = at(sx * (o + gw * 0.5), sy * (o + gd * 0.5))
            if not self.zone_prep["eastside"].contains(Point(c)):
                return False
            return self.try_lot(c[0], c[1], yaw_h, "gas_station", "", "eastside")
        lw, ld = MALL_LEG
        yard = MALL_YARD
        pc = at(sx * (o + yard * 0.5), sy * (o + yard * 0.5))
        a = at(sx * (o + yard + 2.0 + lw * 0.5), sy * (o + ld * 0.5))
        b = at(sx * (o + ld * 0.5), sy * (o + yard + 2.0 + lw * 0.5))
        pp = lot_poly(pc[0], pc[1], yaw_h, yard, yard)
        pa = lot_poly(a[0], a[1], yaw_h, lw, ld)
        pb = lot_poly(b[0], b[1], yaw_v, lw, ld)
        ez = self.zone_prep["eastside"]
        if not all(ez.contains(q.centroid) for q in (pp, pa, pb)):
            return False
        if not (self._free(pp, yaw_h) and self._free(pa, yaw_h) and self._free(pb, yaw_v)):
            return False
        if pa.distance(pb) < 1.6 or pp.distance(pa) < 1.6 or pp.distance(pb) < 1.6:
            return False
        self.try_lot(a[0], a[1], yaw_h, "strip_mall", "", "eastside", MALL_LEG)
        self.try_lot(b[0], b[1], yaw_v, "strip_mall", "", "eastside", MALL_LEG)
        self.add_plot(pc, yaw_h, yard, yard, "civic", [part("parking", 0.0, 0.0, yard - 1.0, yard - 1.0, 0.0, 0),
                                                       part("trees", -yard * 0.5 + 2.0, yard * 0.5 - 2.0, 0.0, 0.0, 0.0,
                                                            TREE_KINDS.index("palm"))])
        return True

    # The south shore: the green, the school, Levittown parcels.
    def _shore_lots(self):
        for r in self.reserved:
            if r["kind"] in ("green", "school_s"):
                self._civic_plot(r)
        sz = self.zone_poly["shore"]
        x0, y0, x1, y1 = sz.bounds
        cols = self._pieces(("collector",), "shore")
        for kind, frac in (("sheriff_station", 0.2), ("fire_station", 0.55), ("post_office", 0.85)):
            x = x0 + (x1 - x0) * frac
            near = min(cols, key=lambda i: self.front_lines[i].distance(Point(x, y0 + 120.0)), default=None)
            q = self.front_lines[near].interpolate(0.5, normalized=True).coords[0] if near is not None else (x, y0 + 120.0)
            self._place_near(q, kind, "", "shore", 220.0)
        tree = TREE_KINDS.index("magnolia")
        W, D = CAPE_PARCEL

        def parcel(c, yaw, n, poly):
            if not self._free(poly, yaw):
                return False
            flip = 1.0 if self.rng.random() < 0.5 else -1.0
            parts = [part("lawn", 0.0, 0.0, W, D), part("paving", 6.0 * flip, -10.5, 3.0, 9.0)]
            if self.rng.random() < 0.6:
                parts.append(part("trees", -6.0 * flip, 9.0, 0.0, 0.0, 0.0, tree))
            k = self.add_plot(c, yaw, W, D, "parcel", parts)
            h = frame_point(c, yaw, -2.0 * flip, -D * 0.5 + CAPE_SETBACK + LOT["cape_house"][1] * 0.5)
            self.try_lot(h[0], h[1], yaw, "cape_house", "", "shore", plot=k)
            return True

        for pi in self._pieces(PATTERN_WALKS["shore"], "shore"):
            for sgn in (1.0, -1.0):
                self._walk_lots(pi, sgn, W, D, parcel, "shore", gap=1.6)

    # Street trees along the kerbs (plots of type "verge").
    def verges(self):
        lights = []
        for road in self.roads:
            n = len(road["nodes"]) - 1
            for k in range(0, n, 2):
                a, b = self.nodes[road["nodes"][k]], self.nodes[road["nodes"][k + 1]]
                L = dist(a, b)
                if L <= 8.0:
                    continue
                dx, dy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
                hw = CLASSES[CLASS_NAMES[road["cls"]]]["w"] * 0.5
                m = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
                for sd in (1.0, -1.0):  # either side: the tiles pick one
                    lights.append((m[0] - dy * sd * (hw + 0.6), m[1] + dx * sd * (hw + 0.6)))
        light_tree = STRtree([Point(q) for q in lights]) if lights else None
        plans = []
        for i, pc in enumerate(self.pieces):
            tag = pc["tag"]
            mid = self.front_lines[i].interpolate(0.5, normalized=True).coords[0]
            zone = self._zone_at(mid)
            if pc["cls"] not in ("street", "avenue"):
                continue
            if tag.startswith("flats:") and zone == "heights":
                plans.append((i, tag.split(":")[1], VERGE_STEP))
            elif tag == "showcase":
                plans.append((i, "palm", PALM_STEP))
            elif tag == "rowhouse" and zone == "fringe":
                plans.append((i, "plane", 14.0))
            elif tag == "arterial" and zone == "eastside":
                plans.append((i, "palm", 20.0))
        made = 0
        for i, kind, step in plans:
            line = self.front_lines[i]
            hw = self.front_half[i]
            off = hw + 1.2
            if min_radius(line) < 150.0:
                continue
            others = [int(j) for j in self.front_tree.query(line.buffer(30.0)) if int(j) != i]
            for sgn in (1.0, -1.0):
                spots = []
                for s in _steps(10.0, line.length - 10.0, step):
                    q = self._side_point(line, s, sgn, off)
                    pt = Point(q)
                    if light_tree is not None and any(Point(lights[int(j)]).distance(pt) < 6.0
                                                      for j in light_tree.query(pt.buffer(6.0))):
                        continue
                    if any(self.front_lines[j].distance(pt) < self.front_half[j] + 1.5 for j in others):
                        continue
                    if self.lot_grid.hits(pt.buffer(0.8)) or not self.play_land_prep.contains(pt):
                        continue
                    spots.append(s)
                # Runs of 50 m or less, each a plot square to the road.
                run = []
                for s in spots + [None]:
                    if run and (s is None or s - run[0] > 50.0 or s - run[-1] > step * 1.5):
                        a, b = run[0], run[-1]
                        sm = (a + b) * 0.5
                        p, t = _along(line, sm)
                        n = (-t[1] * sgn, t[0] * sgn)
                        c = (p[0] + n[0] * off, p[1] + n[1] * off)
                        yaw = yaw_facing(*n)
                        cs, sn = math.cos(yaw), math.sin(yaw)
                        parts = []
                        for r in run:
                            q = self._side_point(line, r, sgn, off)
                            dx, dy = q[0] - c[0], q[1] - c[1]
                            lx, lz = dx * cs - dy * sn, dx * sn + dy * cs
                            parts.append(part("trees", round(lx, 2), round(lz, 2), 0.0, 0.0, 0.0, TREE_KINDS.index(kind)))
                        self.plots.append({"x": c[0], "y": c[1], "yaw": yaw, "w": max(2.0, b - a + 2.0), "d": 1.5,
                                           "type": "verge", "parts": parts})
                        made += 1
                        run = []
                    if s is not None:
                        run.append(s)
        self.verge_count = made

    # --- Ground -------------------------------------------------------------------

    def ground_zones(self):
        zones = []
        taken = Polygon()
        for t in self.town_zones:
            z = t["zone"].difference(taken)
            zones.append(("town", z))
            taken = taken.union(z)
        # Sand along the Gulf, inside the play area.
        sand = self.coast.buffer(45.0).intersection(self.play_land).difference(taken)
        if self.pier is not None:
            sand = sand.difference(self.pier["poly"])
        zones.append(("sand", sand))
        taken = taken.union(sand)
        for name, poly in self.zones:
            z = poly.difference(taken)
            zones.append((name, z))
            taken = taken.union(z)
        for name in farmland.ZONES:
            if name in self.farm_zones:
                z = self.farm_zones[name].intersection(self.play_land).difference(taken)
                zones.append((name, z))
                taken = taken.union(z)
        for r in self.world["regions"]:
            poly = Polygon(self.L(r["polygon"]))
            if r.get("phase") == 2:
                name = {"farmland": "farmland", "bayou": "bayou", "hills": "hills"}[r["type"]]
                z = poly.intersection(self.play_land).difference(taken)
            else:
                name = "far_" + r["type"]
                if name not in ZONES:
                    name = "far_land"
                z = poly.intersection(self.land).difference(self.A).difference(taken)
            zones.append((name, z))
            taken = taken.union(z)
        rest = self.land.difference(taken)
        zones.append(("land", rest.intersection(self.A)))
        zones.append(("far_land", rest.difference(self.A)))
        self.ground = [(ZONES.index(n), z) for n, z in zones if not z.is_empty]

    # --- Tiles --------------------------------------------------------------------

    def tiles(self):
        x0, y0, x1, y1 = self.outer.bounds
        tiles = {}
        ground_tree = STRtree([g[1] for g in self.ground])
        for gx in range(math.floor(x0 / TILE), math.ceil(x1 / TILE)):
            for gy in range(math.floor(y0 / TILE), math.ceil(y1 / TILE)):
                cell = box(gx * TILE, gy * TILE, (gx + 1) * TILE, (gy + 1) * TILE)
                if cell.within(self.P):
                    continue
                parts = []
                for i in ground_tree.query(cell):
                    zi, zpoly = self.ground[i]
                    piece = zpoly.intersection(cell)
                    for poly in polys_of(piece):
                        if poly.area < 0.5:
                            continue
                        tris = constrained_delaunay_triangles(poly.simplify(0.05))
                        flat = []
                        for tri in polys_of(tris):
                            for c in list(tri.exterior.coords)[:3]:
                                flat.extend([round(c[0], 2), round(c[1], 2)])
                        if flat:
                            parts.append([zi, flat])
                if parts:
                    tiles[(gx, gy)] = {"g": parts, "r": [], "l": [], "w": [], "b": [], "p": [], "t": [], "x": [], "f": [], "q": []}

        def tile_of(p):
            return (math.floor(p[0] / TILE), math.floor(p[1] / TILE))

        def put(key, field, value):
            t = tiles.get(key)
            if t is None:
                t = tiles[key] = {"g": [], "r": [], "l": [], "w": [], "b": [], "p": [], "t": [], "x": [], "f": [], "q": []}
            t[field].append(value)

        for ei, e in enumerate(self.edges):
            p, q = self.nodes[e[0]], self.nodes[e[1]]
            put(tile_of(((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)), "r", ei)
        for li, lot in enumerate(self.lots):
            put(tile_of((lot["x"], lot["y"])), "l", li)
        for wi, w in enumerate(self.wall_list):
            put(tile_of(((w[0] + w[2]) / 2, (w[1] + w[3]) / 2)), "w", wi)
        for bi, b in enumerate(self.barricades):
            put(tile_of(b), "b", bi)
        for qi, pl in enumerate(self.plots):
            put(tile_of((pl["x"], pl["y"])), "q", qi)
        for pi, path in enumerate(self.paths):
            put(tile_of(path[0]), "p", pi)
        for ti, tr in enumerate(self.trail_out):
            for k in range(len(tr["pts"]) - 1):
                p, q = tr["pts"][k], tr["pts"][k + 1]
                put(tile_of(((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)), "t", [ti, k])
        for ri, rl in enumerate(self.rail_out):
            for k in range(len(rl["pts"]) - 1):
                p, q = rl["pts"][k], rl["pts"][k + 1]
                put(tile_of(((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)), "x", [ri, k])
        for fi, fr in enumerate(self.far_out):
            for k in range(len(fr["pts"]) - 1):
                p, q = fr["pts"][k], fr["pts"][k + 1]
                put(tile_of(((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)), "f", [fi, k])
        self.tile_data = tiles

    def polyline_outputs(self):
        self.trail_out = []
        for t in self.trails:
            pts = [[round(c[0], 2), round(c[1], 2)] for c in resample(t[0], 12.0)]
            self.trail_out.append({"name": t[2], "pts": pts})
        self.rail_out = []
        for line, kind, name, phase in self.rails:
            if line.length < 10:
                continue
            pts = [[round(c[0], 2), round(c[1], 2)] for c in resample(line, 16.0)]
            self.rail_out.append({"kind": kind, "name": name, "pts": pts, "phase": phase})
        self.far_out = []
        for line, cls in self.render_only:
            pts = [[round(c[0], 2), round(c[1], 2)] for c in resample(line, 24.0)]
            self.far_out.append({"cls": CLASS_NAMES.index(cls), "pts": pts})

    # --- Run and export -------------------------------------------------------------

    def run(self):
        self.areas()
        self.routes()
        self.suburbs()
        self.towns()
        self.farm_roads()
        self.trim_route_stubs()
        self.join_ends()
        self.trim_farm_stubs()
        self.graph()
        self.build_graph_arrays()
        self._pier_land()
        self.walls()
        self.lot_setup()
        self.farm_canals()
        self.landmark_lots()
        self.mountain_lots()
        self.town_lots()
        self.outskirts_lots()
        self.street_lots()
        self.verges()
        self.farm_lots()
        self.field_plots()
        self.farm_fields()
        self.hill_lakes()
        self.hill_places()
        self.ground_zones()
        self.mountain_terrain()
        self.hill_streams()
        self.upgrade_lots()
        self.lot_reach()
        self.wealth = wealth.Wealth(self)
        self.wealth.assign()
        self.walks_out()
        self.polyline_outputs()
        self.tiles()

    def walks_out(self):
        """Sidewalk loops for people in Bellerive's suburbs
        (HANDOFF-bellerive-expand.md BX-1): each block the roads close,
        less every road's half width and half a sidewalk, leaves a ring
        down the middle of the sidewalks round it. A ring is kept when
        most of it runs along streets and avenues (the classes with
        sidewalks); points every 6 m at most, anticlockwise."""
        self.walks = []
        keep = unary_union([p for z, p in self.zones if z in WALK_ZONES])
        # The city's edge streets (the plan's edge loops).
        frame = [LineString(list(lp) + [lp[0]]) for lp in self.plan["edge_loops"]]
        lines = [LineString(pc["pts"]) for pc in self.pieces] + frame
        # Roads linked to the city stop FRAME_IN short of its edge street:
        # carry each such end on to it, or the blocks along the city never
        # close.
        frames = unary_union(frame)
        link_pos = [l["pos"] for l in self.links]
        for pc in self.pieces:
            for q in (pc["pts"][0], pc["pts"][-1]):
                d = frames.distance(Point(q))
                # Only a linked end: a road that merely ends near the edge
                # street does not join it, and no sidewalk crosses the gap.
                if 1e-3 < d < FRAME_IN + 2.0 and any(dist(q, l) < 0.5 for l in link_pos):
                    n = nearest_points(frames, Point(q))[0]
                    t = (d + 0.5) / d  # a little past it, so the union nodes them
                    lines.append(LineString([q, (q[0] + (n.x - q[0]) * t, q[1] + (n.y - q[1]) * t)]))
        cut = unary_union([LineString(pc["pts"]).buffer(CLASSES[pc["cls"]]["w"] * 0.5 + WALK_MID, join_style=2)
                           for pc in self.pieces] +
                          [f.buffer(CITY_STREET_W * 0.5 + WALK_MID, join_style=2) for f in frame])
        walked = unary_union([LineString(pc["pts"]).buffer(CLASSES[pc["cls"]]["w"] * 0.5 + WALK_MID + 0.6)
                              for pc in self.pieces if pc["cls"] in WALK_CLASSES] +
                             [f.buffer(CITY_STREET_W * 0.5 + WALK_MID + 0.6) for f in frame])
        walked_prep = prep(walked)
        dropped = 0
        for face in polygonize(unary_union(lines)):
            if not keep.contains(face.representative_point()) or face.area > WALK_BLOCK_MAX:
                continue
            for part in polys_of(face.difference(cut)):
                if part.area < WALK_PART_MIN:
                    continue
                ring = LineString(orient(part.simplify(0.5), 1.0).exterior.coords)
                if not walked_prep.intersects(ring) or ring.intersection(walked).length < ring.length * WALK_SHARE:
                    dropped += 1
                    continue
                pts = []
                cs = list(ring.coords)[:-1]
                for k, a in enumerate(cs):
                    b = cs[(k + 1) % len(cs)]
                    steps = max(1, int(math.dist(a, b) / 6.0))
                    for s in range(steps):
                        t = s / steps
                        pts += [round(a[0] + (b[0] - a[0]) * t, 1), round(a[1] + (b[1] - a[1]) * t, 1)]
                self.walks.append(pts)
        print("walks: %d loops, %d points, %d rings dropped (mostly roads without sidewalks)"
              % (len(self.walks), sum(len(w) // 2 for w in self.walks), dropped))
        self.village_walks()
        self.trail_walks()

    def village_walks(self):
        """Loops for people in the hill villages (HILL_VILLAGES): along each
        road at least VILLAGE_FRONTS of a village's lots front, down one
        shoulder past them (VILLAGE_WALK m beyond the end ones) and back up
        the other, crossing at the ends. The hill roads have no sidewalks,
        so walks_out makes none there."""
        n = 0
        for name, _, _ in HILL_VILLAGES:
            fronts = collections.defaultdict(list)
            for q in self.village_lots.get(name, []):
                k = min(range(len(self.pieces)), key=lambda i: LineString(self.pieces[i]["pts"]).distance(Point(q)))
                if LineString(self.pieces[k]["pts"]).distance(Point(q)) < 80.0:
                    fronts[k].append(q)
            loops = 0
            for k, qs in fronts.items():
                if len(qs) < VILLAGE_FRONTS:
                    continue
                line = LineString(self.pieces[k]["pts"])
                ts = [line.project(Point(q)) for q in qs]
                self._village_loop(line, self.pieces[k]["cls"], min(ts) - VILLAGE_WALK, max(ts) + VILLAGE_WALK)
                loops += 1
            if not loops:
                print("WARNING: village %s has no road for a walk" % name)
            n += loops
        print("village walks: %d" % n)

    def trail_walks(self):
        """Loops for hikers, runners and hunters (TRAIL_WALK_MIN m or longer
        trails on Mount Calder and in the hill country): up one side of the
        trail and back down the other, on the trail itself. Their indices go
        out as `trail_walks`, so the game dresses the people on them for
        the hills."""
        self.trail_walk_ids = []
        for t in self.trails:
            # The trail as it goes out (polyline_outputs), which the game
            # draws and keeps undropped: at switchbacks the 12 m resample
            # cuts the bend by metres.
            line = LineString(resample(t[0], 12.0))
            if line.length < TRAIL_WALK_MIN:
                continue
            self.trail_walk_ids.append(len(self.walks))
            self.walks.append(self._trail_loop(line))
        print("trail walks: %d" % len(self.trail_walk_ids))

    def _trail_loop(self, line):
        """Up the trail's right side and back down its other, each point
        TRAIL_EDGE in from the way's edge square off the centre line, every
        6 m. Offsetting point by point keeps to the way even at switchbacks,
        where a buffer of the two legs merged and its ring cut across the
        bend, up to 5 m off the trail."""
        off = CLASSES["trail"]["w"] * 0.5 + TRAIL_EDGE
        n = max(2, int(line.length / 6.0))
        out, back = [], []
        for i in range(n + 1):
            d = line.length * i / n
            a = line.interpolate(max(0.0, d - 1.0))
            b = line.interpolate(min(line.length, d + 1.0))
            p = line.interpolate(d)
            tx, tz = b.x - a.x, b.y - a.y
            m = math.hypot(tx, tz) or 1.0
            nx, nz = -tz / m * off, tx / m * off
            out.append((p.x - nx, p.y - nz))
            back.append((p.x + nx, p.y + nz))
        pts = []
        for x, z in out + back[::-1]:
            pts += [round(x, 1), round(z, 1)]
        return pts

    def _village_loop(self, line, cls, t0, t1, edge=VILLAGE_SHOULDER):
        """One village loop: line from t0 to t1, both shoulders (edge m out
        from the road's side; a negative edge keeps it on the way)."""
        sub = substring(line, max(0.0, t0), min(line.length, t1))
        strip = sub.buffer(CLASSES[cls]["w"] * 0.5 + edge, cap_style=2, join_style=2)
        ring = list(orient(strip.simplify(0.5), 1.0).exterior.coords)[:-1]
        pts = []
        for k, a in enumerate(ring):
            b = ring[(k + 1) % len(ring)]
            steps = max(1, int(math.dist(a, b) / 6.0))
            for s_ in range(steps):
                f = s_ / steps
                pts += [round(a[0] + (b[0] - a[0]) * f, 1), round(a[1] + (b[1] - a[1]) * f, 1)]
        self.walks.append(pts)

    def upgrade_lots(self):
        """Bellerive's suburbs to city grade (HANDOFF-bellerive-expand.md
        BX-5), by land value: the poorest east side house pairs become
        walk-ups and liquor stores, its poorest single lots barred
        bungalows, pawn shops, check cashers and burned-out lots; the
        richest pairs on the east side and the Heights flats executive
        houses; the dearer half of Brisa Beach's condo towers residential
        towers; the best third of the garden apartments mid-rise condos
        and the worst four walk-ups; the cheaper third of the hill
        mansions executive houses. A refitted lot keeps its front line and
        never grows, so it stays clear of its neighbours. Runs before
        lot_reach; nothing before it holds lot indices."""
        w = wealth.Wealth(self)
        vals = {}

        def value(l):
            if id(l) not in vals:
                vals[id(l)] = w.value(l)
            return vals[id(l)]

        def put(l, kind, c, lw, ld):
            nw, nd = LOT[kind]
            w2, d2 = min(lw, nw * UP_FIT[1]), min(ld, nd * UP_FIT[1])
            if w2 < nw * UP_FIT[0] - 0.01 or d2 < nd * UP_FIT[0] - 0.01:
                return False
            c = frame_point(c, l["yaw"], 0.0, (d2 - ld) * 0.5)
            l.update(x=c[0], y=c[1], w=round(w2, 2), d=round(d2, 2), kind=kind)
            return True

        def pairs(zone):
            """Side by side house lots along a frontage, paired from each row's first."""
            homes = [l for l in self.lots if l["kind"] == "house" and l["zone"] == zone and l["plot"] < 0]
            right = {}
            for a in homes:
                cs, sn = math.cos(a["yaw"]), math.sin(a["yaw"])
                for b in homes:
                    if b is a or b["d"] != a["d"] or abs((b["yaw"] - a["yaw"] + math.pi) % math.tau - math.pi) > 0.02:
                        continue
                    ox, oy = b["x"] - a["x"], b["y"] - a["y"]
                    lx = ox * cs - oy * sn
                    if a["w"] < lx < a["w"] + 5.0 and abs(ox * sn + oy * cs) < 1.0:
                        right[id(a)] = b
            lefts = {id(b) for b in right.values()}
            out = []
            for a in homes:
                if id(a) in lefts:
                    continue
                while a is not None and id(a) in right:
                    b = right[id(a)]
                    out.append((a, b))
                    a = right.get(id(b))
            return sorted(out, key=lambda p: value(p[0]) + value(p[1]))

        drop = set()
        made = collections.Counter()
        # A merged lot is square to one lot of the pair: on a curving street
        # it may swing into the next lot, and then the pair stays as it is.
        lot_tree = STRtree([lot_poly(l["x"], l["y"], l["yaw"], l["w"], l["d"]) for l in self.lots])

        def merge(a, b, kind):
            mid = ((a["x"] + b["x"]) * 0.5, (a["y"] + b["y"]) * 0.5)
            was = dict(a)
            if not put(a, kind, mid, dist((a["x"], a["y"]), (b["x"], b["y"])) + a["w"], a["d"]):
                return
            pa = lot_poly(a["x"], a["y"], a["yaw"], a["w"], a["d"])
            for j in lot_tree.query(pa):
                o = self.lots[int(j)]
                if o is a or o is b or id(o) in drop:
                    continue
                if pa.intersection(lot_poly(o["x"], o["y"], o["yaw"], o["w"], o["d"])).area > 0.5:
                    a.update(was)
                    return
            drop.add(id(b))
            made[kind] += 1

        ps = pairs("eastside")
        for i, (a, b) in enumerate(ps[:UP_CHEAP_PAIRS]):
            merge(a, b, "liquor_store" if i % 5 == 4 else "cheap_block")
        for zone, n in UP_EXEC_PAIRS.items():
            for a, b in (ps if zone == "eastside" else pairs(zone))[-n:]:
                merge(a, b, "exec_house")
        singles = sorted((l for l in self.lots if l["kind"] == "house" and l["zone"] == "eastside" and l["plot"] < 0
                          and id(l) not in drop), key=value)
        for i, l in enumerate(singles[:UP_SINGLE_COUNT]):
            kind = UP_SINGLES[i % len(UP_SINGLES)]
            made[kind] += put(l, kind, (l["x"], l["y"]), l["w"], l["d"])

        def swap(ls, kind):
            for l in ls:
                made[kind] += put(l, kind, (l["x"], l["y"]), l["w"], l["d"])

        towers = sorted((l for l in self.lots if l["kind"] == "condo_tower" and l["zone"] == "beach_town"), key=value)
        swap(towers[len(towers) // 2:], "res_tower")
        gardens = sorted((l for l in self.lots if l["kind"] == "garden_apartments"
                          and l["zone"] in ("shore", "eastside", "fringe")), key=value)
        swap(gardens[len(gardens) - len(gardens) // 3:], "midrise_condo")
        swap(gardens[:4], "cheap_block")
        hills = sorted((l for l in self.lots if l["kind"] == "mansion" and l["zone"] == "mountain" and l["plot"] < 0),
                       key=value)
        swap(hills[:len(hills) // 3], "exec_house")
        self.lots = [l for l in self.lots if id(l) not in drop]
        print("upgrade_lots:", dict(sorted(made.items())), "merged away", len(drop))

    def lot_reach(self):
        """Each lot's `reach`: metres from its front edge (at x = -w/2, 0,
        w/2) straight out to the road surface, plus REACH_TUCK under it,
        where a road lies within REACH_MAX ahead with nothing between (its
        own farmyard or parcel aside); -1 at a side whose way out crosses a
        lot, plot, water or rails. The kit runs its drives and walks out
        that far (HANDOFF-routes R-1, R-2)."""
        lot_tree = STRtree([lot_poly(l["x"], l["y"], l["yaw"], l["w"], l["d"]) for l in self.lots])
        plot_polys = [lot_poly(q["x"], q["y"], q["yaw"], q["w"], q["d"]) for q in self.plots]
        plot_tree = STRtree(plot_polys)
        water = self.canal_area.union(self.water) if hasattr(self, "canal_area") else self.water
        # The road surfaces as drawn (road_area adds a 2.5 m keep-out), and
        # the trails; railways are in the way, not a way in.
        # The city's frame street counts too: town rows face it.
        frame = [LineString(list(lp) + [lp[0]]).buffer(CITY_STREET_W * 0.5) for lp in self.plan["edge_loops"]]
        surface = unary_union([LineString(pc["pts"]).buffer(CLASSES[pc["cls"]]["w"] * 0.5) for pc in self.pieces] +
                              [t[0].buffer(CLASSES["trail"]["w"] * 0.5) for t in self.trails] + frame)
        rails = unary_union([rl[0].buffer(2.5) for rl in self.rails]) if self.rails else Point(0, 0).buffer(0.0)
        water = water.union(rails)
        for i, l in enumerate(self.lots):
            l["reach"] = [0.0, 0.0, 0.0]
            own = l["plot"]
            if own >= 0 and self.plots[own]["type"] not in ("farmyard", "parcel"):
                continue
            c, yaw, w, d = (l["x"], l["y"]), l["yaw"], l["w"], l["d"]
            got = []
            for lx in (-w * 0.5 + 0.3, 0.0, w * 0.5 - 0.3):
                f = frame_point(c, yaw, lx, -d * 0.5)
                ray = LineString([f, frame_point(c, yaw, lx, -d * 0.5 - REACH_MAX)])
                hit = ray.intersection(surface)
                if hit.is_empty:
                    got.append(None)
                    continue
                r = Point(f).distance(hit)
                ahead = LineString([f, frame_point(c, yaw, lx, -d * 0.5 - r)])
                blocked = ahead.length > 0.05 and (
                    any(int(j) != i and ahead.crosses(lot_tree.geometries[int(j)]) for j in lot_tree.query(ahead))
                    or any(int(j) != own and self.plots[int(j)]["type"] not in ("verge", "block")
                           and ahead.intersects(plot_polys[int(j)]) for j in plot_tree.query(ahead))
                    or ahead.intersects(water))
                got.append(-1.0 if blocked else r)
            if got[1] is None or got[1] < 0.0:
                continue
            # A side with no road ahead takes the middle's reach; a blocked
            # side stays -1 (the kit draws no route there).
            l["reach"] = [-1.0 if g is not None and g < 0.0 else round((g if g is not None else got[1]) + REACH_TUCK, 2)
                          for g in got]

    def routed(self, l):
        """How a home lot is reached from the road: "reach", "cluster",
        "estate" or "" for not at all."""
        if any(r > 0.0 for r in l.get("reach", [])):
            return "reach"
        if l["plot"] >= 0:
            t = self.plots[l["plot"]]["type"]
            if t == "cluster" and any(q[0] == "footpath" for q in self.plots[l["plot"]]["parts"]):
                return "cluster"
            if t == "estate":
                return "estate"
        return ""

    def report(self):
        """Plot counts, and the worst turn of a lot or plot off the road it fronts."""
        counts = {}
        for p in self.plots:
            counts[p["type"]] = counts.get(p["type"], 0) + 1
        turned = sum(1 for l in self.lots if l["plot"] >= 0 and l["kind"] == "mansion"
                     and abs(l["yaw"] - self.plots[l["plot"]]["yaw"]) > 0.1)
        worst = (0.0, None)
        for item in [l for l in self.lots if l["plot"] < 0 and l["zone"] != "sand"] + self.plots:
            f = frame_point((item["x"], item["y"]), item["yaw"], 0.0, -item["d"] * 0.5)
            p, t, n, hw, i, sa = self._frontage(f)
            if dist(f, p) > hw + 8.0:
                continue  # a back field: it fronts the field before it
            yaw = item["yaw"]
            ax = (math.cos(yaw), -math.sin(yaw))
            off = math.degrees(math.asin(min(1.0, abs(ax[0] * t[1] - ax[1] * t[0]))))
            if off > worst[0]:
                worst = (off, item.get("kind", item.get("type")), round(item["x"]), round(item["y"]))
        print("plots:", counts, "turned estate houses:", turned, "worst turn off the fronting road (deg):", worst)
        ways = collections.Counter()
        lost = []
        for l in self.lots:
            if l["kind"] in HOME_KINDS:
                how = self.routed(l)
                ways[how or "none"] += 1
                if not how:
                    lost.append((l["kind"], round(l["x"]), round(l["y"])))
        print("home routes:", dict(ways), "homes with no way in:", len(lost), lost[:8])
        # Cluster footpaths keep off the homes (their aprons only touch
        # their own home's front).
        under = []
        for k, q in enumerate(self.plots):
            if q["type"] != "cluster":
                continue
            homes = [lot_poly(l["x"], l["y"], l["yaw"], l["w"], l["d"]).buffer(-0.3)
                     for l in self.lots if l["plot"] == k]
            for pt in q["parts"]:
                if pt[0] == "footpath":
                    c = frame_point((q["x"], q["y"]), q["yaw"], pt[1], pt[2])
                    poly = lot_poly(c[0], c[1], q["yaw"] + pt[5], pt[3], pt[4])
                    if any(poly.intersects(h) for h in homes):
                        under.append((round(c[0]), round(c[1])))
        print("cluster footpaths under a home:", len(under), under[:5])
        self.wealth.report()
        self.self_check()
        self.mountain_check()

    def mountain_check(self):
        """The hills: each road's steepest grade on the final grid, and how
        far the grid strays from its graded profile along the road."""
        names = {v["name"] for k, v in mountain_lines().items() if v["cls"] not in ("trail", "rail")}
        worst = {}
        for pc in self.pieces:
            if pc["name"] not in names:
                continue
            pts = resample(LineString(pc["pts"]), 4.0)
            hs = [self.mtn.height(q) for q in pts]
            # Only where the road lies on its graded profile: a bridge deck or
            # a tunnel has none, and the ground under it is not the road.
            zs = [self.mtn.profile_at(q) for q in pts]
            g = max([(abs(b - a) / max(dist(p, q), 0.1), p) for a, b, p, q, za, zb in zip(hs, hs[1:], pts, pts[1:], zs, zs[1:])
                     if za is not None and zb is not None] or [(0.0, None)], key=lambda t: t[0])
            off = max([(abs(h - z), q) for h, z, q in zip(hs, zs, pts) if z is not None] or [(0.0, None)], key=lambda t: t[0])
            w = worst.setdefault(pc["name"], [(0.0, None), (0.0, None), 0.0])
            worst[pc["name"]] = [max(w[0], g, key=lambda t: t[0]), max(w[1], off, key=lambda t: t[0]), max(w[2], max(hs))]
        # Each pad is flat under its whole lot (2 m samples).
        offs = []
        for poly, ph in self.mtn_pads:
            bx0, by0, bx1, by1 = poly.bounds
            off = 0.0
            for i in range(int((bx1 - bx0) / 2.0) + 1):
                for j in range(int((by1 - by0) / 2.0) + 1):
                    x, y = bx0 + i * 2.0, by0 + j * 2.0
                    if poly.contains(Point(x, y)):
                        off = max(off, abs(self.mtn.height((x, y)) - ph))
            offs.append((round(off, 2), tuple(round(c) for c in poly.centroid.coords[0])))
        offs.sort(reverse=True)
        print("mountain: graded", self.mtn_grades, "pads %d, worst off flat (m)" % len(offs), offs[:4],
              "peak %.0f m" % float(self.mtn.heights.max()))
        at = lambda q: "(%.0f, %.0f)" % tuple(q) if q is not None else "-"
        for name, ((g, gq), (off, oq), top) in sorted(worst.items()):
            print("  %-20s steepest %.1f%% at %s, off its profile %.2f m at %s, top %.0f m"
                  % (name, g * 100.0, at(gq), off, at(oq), top))

    def self_check(self):
        """Geometry checks with shapely: lots clear of each other, of the roads
        and of the water; plots off the roads and inside the play area; the
        road graph in one piece with the city; the test's own turn measure."""
        lot_polys = [lot_poly(l["x"], l["y"], l["yaw"], l["w"], l["d"]) for l in self.lots]
        tree = STRtree(lot_polys)
        overlap = []
        for i, pl in enumerate(lot_polys):
            for j in tree.query(pl):
                j = int(j)
                if j > i and pl.intersection(lot_polys[j]).area > 0.5:
                    overlap.append((self.lots[i]["kind"], self.lots[j]["kind"], round(pl.centroid.x), round(pl.centroid.y)))
        road_only = unary_union([LineString(pc["pts"]).buffer(CLASSES[pc["cls"]]["w"] * 0.5) for pc in self.pieces])
        road_p = prep(road_only)
        on_road = [(l["kind"], round(l["x"]), round(l["y"])) for l, pl in zip(self.lots, lot_polys)
                   if road_p.intersects(pl) and road_only.intersection(pl).area > 0.5]
        wet = [(l["kind"], round(l["x"]), round(l["y"])) for l, pl in zip(self.lots, lot_polys)
               if l["kind"] != "pier_rides" and self.water_prep.intersects(pl) and self.water.intersection(pl).area > 1.0]
        land = prep(self.play_land.buffer(1.0))
        p_road, p_wet, p_out = [], [], []
        for q in self.plots:
            pl = lot_poly(q["x"], q["y"], q["yaw"], q["w"], q["d"])
            tag = (q["type"], round(q["x"]), round(q["y"]))
            if q["type"] not in ("verge", "block") and road_p.intersects(pl) and road_only.intersection(pl).area > 0.5:
                p_road.append(tag)
            if self.water_prep.intersects(pl) and self.water.intersection(pl).area > 1.0:
                p_wet.append(tag)
            if not land.contains(pl):
                p_out.append(tag)
        # The graph: every node reached from the links to the city.
        adj = {}
        for e in self.edges:
            adj.setdefault(e[0], []).append(e[1])
            adj.setdefault(e[1], []).append(e[0])
        seen = set()
        stack = [l[0] for l in self.link_pairs]
        while stack:
            n = stack.pop()
            if n in seen:
                continue
            seen.add(n)
            stack.extend(adj.get(n, []))
        cut_off = len(self.nodes) - len(seen)
        worst_lot = max([self._road_turn(frame_point((l["x"], l["y"]), l["yaw"], 0.0, -l["d"] * 0.5), l["yaw"])
                         for l in self.lots if l["plot"] < 0 and l["zone"] != "sand"], default=0.0)
        fronting = sum(1 for l in self.lots if l["plot"] < 0 and l["zone"] != "sand"
                       and self._road_turn(frame_point((l["x"], l["y"]), l["yaw"], 0.0, -l["d"] * 0.5), l["yaw"]) >= 0.0)
        worst_plot = max([self._road_turn(frame_point((q["x"], q["y"]), q["yaw"], 0.0, -q["d"] * 0.5), q["yaw"])
                          for q in self.plots], default=0.0)
        print("self-check: lot overlaps %d %s, lots on roads %d %s, lots in water %d %s" % (
            len(overlap), overlap[:4], len(on_road), on_road[:4], len(wet), wet[:4]))
        print("self-check: plots on roads %d %s, in water %d %s, outside the play area %d %s" % (
            len(p_road), p_road[:4], len(p_wet), p_wet[:4], len(p_out), p_out[:4]))
        print("self-check: graph nodes not reached from the city %d of %d; test measure: %d fronting lots, worst lot %.2f deg, worst plot %.2f deg"
              % (cut_off, len(self.nodes), fronting, worst_lot, worst_plot))
        by_zone = {}
        for l in self.lots:
            z = l["zone"]
            by_zone.setdefault(z, [0, {}])[0] += 1
        for q in self.plots:
            z = self._zone_at((q["x"], q["y"])) or "-"
            types = by_zone.setdefault(z, [0, {}])[1]
            types[q["type"]] = types.get(q["type"], 0) + 1
        for z in ("heights", "bayou_town", "fringe", "eastside", "shore", "beach_town", "hillside"):
            if z in by_zone:
                kinds = {}
                for l in self.lots:
                    if l["zone"] == z:
                        kinds[l["kind"]] = kinds.get(l["kind"], 0) + 1
                print("  %-10s lots %4d %s plots %s" % (z, by_zone[z][0], dict(sorted(kinds.items(), key=lambda kv: -kv[1])), by_zone[z][1]))
        print("  blocks", getattr(self, "block_count", 0), "verges", getattr(self, "verge_count", 0), "bulbs", len(self.bulbs),
              "pier", bool(self.pier), "reserved", [r["kind"] for r in self.reserved])
        # The city's shape: the urban outline is no box, the Beltway no
        # straight-sided ring, and every highway reaching the city meets an exit.
        b = self.urban.bounds
        box_ratio = self.urban.area / ((b[2] - b[0]) * (b[3] - b[1]))
        straight = max((self._longest_straight(g) for g in self.belt_pieces), default=0.0)
        link_pos = [l["pos"] for l in self.links]
        loose = []
        for line, cls, name, kind in self.sources:
            if cls not in ("highway", "freeway") or kind == "beltway":
                continue
            for e in (line.coords[0], line.coords[-1]):
                if self.P.distance(Point(e)) < 5.0 and not any(dist(e, q) < 2.0 for q in link_pos):
                    loose.append((name, round(e[0]), round(e[1])))
        used = sum(1 for ex in self.exits if ex["used"])
        idle = sum(1 for ex in self.exits if ex["open"] and not ex["used"])
        print("self-check: urban %.2f km2 fills %.3f of its bbox (max %.2f) %s; Beltway longest straight %.0f m (max %.0f) %s"
              % (self.urban.area / 1e6, box_ratio, URBAN_BOX_MAX, "ok" if box_ratio < URBAN_BOX_MAX else "FAIL",
                 straight, BELT_STRAIGHT_MAX, "ok" if straight <= BELT_STRAIGHT_MAX else "FAIL"))
        print("self-check: highway ends at the city off an exit %d %s; exits used %d of %d, open and unused %d; no exit found %s"
              % (len(loose), loose[:4], used, len(self.exits), idle, self.lead_fail))

    @staticmethod
    def _longest_straight(line, step=10.0):
        """The longest run (m) of a line whose heading stays within 1 degree
        of the heading it started with."""
        pts = [line.interpolate(s).coords[0] for s in _steps(0.0, line.length, step)]
        best = run = 0.0
        h0 = None
        for a, b in zip(pts, pts[1:]):
            h = math.atan2(b[1] - a[1], b[0] - a[0])
            seg = dist(a, b)
            if h0 is not None and abs((h - h0 + math.pi) % math.tau - math.pi) <= math.radians(1.0):
                run += seg
            else:
                h0, run = h, seg
            best = max(best, run)
        return best

    def export(self):
        def ring(poly):
            return [[round(c[0], 1), round(c[1], 1)] for c in poly.exterior.coords]

        towns = []
        for t in self.town_zones:
            towns.append({"id": t["id"], "name": t["name"], "kind": t["kind"],
                          "pos": [round(t["center"][0], 1), round(t["center"][1], 1)]})
        zones = []
        for name, poly in self.zones:
            for p in polys_of(poly):
                zones.append({"zone": name, "poly": ring(p.simplify(2.0))})
        tiles = []
        for (gx, gy), t in sorted(self.tile_data.items()):
            t = dict(t)
            t["k"] = [gx, gy]
            tiles.append(t)
        lots = [[round(l["x"], 2), round(l["y"], 2), round(l["yaw"], 4), l["w"], l["d"], KINDS.index(l["kind"]),
                 l["id"], l["zone"], l["plot"], l.get("reach", [0.0, 0.0, 0.0]), l.get("tier", -1), l.get("value", 0.0)]
                for l in self.lots]
        plots = [[round(p["x"], 2), round(p["y"], 2), round(p["yaw"], 4), round(p["w"], 2), round(p["d"], 2),
                  PLOT_TYPES.index(p["type"]),
                  [[PART_KINDS.index(q[0]), round(q[1], 2), round(q[2], 2), round(q[3], 2), round(q[4], 2),
                    round(q[5], 4), q[6]] for q in p["parts"]]] for p in self.plots]
        return {
            "version": 1,
            "tile": TILE,
            "origin": list(self.origin),
            "plan_bounds": list(self.P.bounds),
            "city_footprint": ring(self.P),
            "urban": ring(self.urban),
            "classes": [{"id": k, "w": v["w"], "speed": v["speed"], "lanes": v["lanes"], "lane_w": v["lane_w"],
                         "middle": v["middle"], "park": v["park"]} for k, v in CLASSES.items()],
            "zones": ZONES,
            "kinds": KINDS,
            "area": [ring(p.simplify(4.0)) for p in polys_of(self.A)],
            "suburbs": zones,
            "towns": towns,
            "nodes": self.nodes,
            "edges": self.edges,
            "roads": self.roads,
            "links": self.link_pairs,
            "bridges": [{"road": b["road"], "from": b["from"], "to": b["to"]} for b in self.bridges],
            "walls": self.wall_list,
            "barricades": self.barricades,
            "terrain": self.terrain,
            "lots": lots,
            "plot_types": PLOT_TYPES,
            "part_kinds": PART_KINDS,
            "tree_kinds": TREE_KINDS,
            "plots": plots,
            "paths": self.paths,
            "trails": self.trail_out,
            "rails": self.rail_out,
            "far_roads": self.far_out,
            "pivots": self.pivots,
            "walks": self.walks,
            "trail_walks": self.trail_walk_ids,
            "tiles": tiles,
            # Mount Calder (tools/mountain.py): tunnels, bridges, viaducts and
            # underpasses with their heights; the rail pass; the peaks, the
            # summit's sites and the cable car.
            "structures": self.structures,
            "rail_pass": self.rail_pass,
            # The hill country's lakes (water at `level`, its edge a little
            # past the shore, under the ground) and streams (HANDOFF-hill-content.md).
            "lakes": [{"id": lk["id"], "name": lk["name"], "level": lk["level"],
                       "poly": [round(v, 1) for q in orient(lk["shore"].buffer(LAKE_EDGE).simplify(1.0), 1.0).exterior.coords[:-1] for v in q]}
                      for lk in self.lakes],
            "streams": self.streams,
            "mountain": {
                "peaks": {k: [p[0], p[1], round(self.mtn.height(p), 1)] for k, p in PEAKS.items()},
                "sites": self.mtn_sites,
                "cable": self.mtn.cable(),
            },
        }


def _along(line, s):
    """The point of line at s and its unit tangent there."""
    a = line.interpolate(max(0.0, s - 2.0)).coords[0]
    b = line.interpolate(min(line.length, s + 2.0)).coords[0]
    tx, ty = b[0] - a[0], b[1] - a[1]
    tn = math.hypot(tx, ty) or 1.0
    return line.interpolate(s).coords[0], (tx / tn, ty / tn)


def _boundary(kind, W, D, gap_at=None, gap=7.0, splay=None):
    """The four sides of a W x D plot as line parts, 0.5 m in, with a gate
    gap in the front centred on x = gap_at, or a gate across the front-left
    corner when splay is given (mirror the result for the right)."""
    e = 0.5
    x0, z0, x1, z1 = -W * 0.5 + e, -D * 0.5 + e, W * 0.5 - e, D * 0.5 - e
    out = [seg_part(kind, (x1, z0), (x1, z1), 0.6), seg_part(kind, (x0, z1), (x1, z1), 0.6)]
    if splay:
        out += [seg_part(kind, (x0 + splay, z0), (x1, z0), 0.6), seg_part(kind, (x0, z0 + splay), (x0, z1), 0.6),
                seg_part("gate", (x0, z0 + splay), (x0 + splay, z0), 0.6)]
    else:
        out.append(seg_part(kind, (x0, z0), (x0, z1), 0.6))
        if gap_at is None:
            out.append(seg_part(kind, (x0, z0), (x1, z0), 0.6))
        else:
            out += [seg_part(kind, (x0, z0), (gap_at - gap * 0.5, z0), 0.6),
                    seg_part(kind, (gap_at + gap * 0.5, z0), (x1, z0), 0.6),
                    seg_part("gate", (gap_at - gap * 0.5, z0), (gap_at + gap * 0.5, z0), 0.6)]
    return out


def _mirror(parts):
    """Parts mirrored across the plot's x = 0 axis."""
    out = []
    for p in parts:
        q = list(p)
        q[1] = -p[1]
        # A line keeps its run (pi - rot); a gate, symmetric along its run,
        # takes -rot instead so its leaves still swing inward.
        q[5] = math.pi - p[5] if p[0] in LINE_PARTS and p[0] != "gate" else -p[5]
        out.append(q)
    return out


def estate_layout(W, D, turn, style, rng, grand=False):
    """The grounds of an estate (research: HANDOFF-plots.md). Axial: gate,
    tree-lined drive and mirrored parterres in front, the house on the axis,
    a tennis court and an orchard of the same size either side behind, a
    parterre and a row of trees at the back. Turned (square plots, house at
    45 degrees): the gate across a front corner, the drive up the diagonal,
    square parterres either side of it and a round garden behind the house.
    Returns (parts, house (x, z, size), gate (x, z))."""
    m = 2.0
    bound = "wall" if style == 0 else "hedge"
    tree = TREE_KINDS.index("palm" if style == 0 and rng.random() < 0.6 else "oak")
    hs = ESTATE_HOUSE + (6.0 if grand else 0.0)
    x0, z0, x1, z1 = -W * 0.5, -D * 0.5, W * 0.5, D * 0.5
    parts = [part("lawn", 0.0, 0.0, W, D)]
    if turn == 0.0:
        hs = min(hs, D - m - 16.0)
        # Too shallow for a court behind the house and a little narrow for
        # one beside it: the house gives up to 8 m of width to fit it beside.
        fit = W - 2.0 * (m + 2.0 + 18.5)
        if fit < hs and fit >= hs - 8.0 and D - m - hs - TENNIS_BACK < 12.0:
            hs = fit
        front = min(max((D - hs) * 0.45, 12.0), 30.0)
        side = W * 0.5 - m - hs * 0.5 - 2.0
        # No room for a tennis court beside the house: shorten the front
        # garden, down to 12 m, to fit one behind it (court 18.3 m + margin).
        court_back = side < 18.5 and D - m - hs - TENNIS_BACK >= 12.0
        if court_back:
            front = min(front, D - m - hs - TENNIS_BACK)
        zf = z0 + front
        parts += _boundary(bound, W, D, 0.0)
        # The gatehouse (estate_at) holds the first metres of the drive.
        zg = z0 + GATE_IN + LOT["gatehouse"][1]
        parts.append(part("drive", 0.0, (zg + zf) * 0.5, 6.0, zf - zg))
        if zf - 3.0 > zg + 6.0:
            for s in (-1.0, 1.0):
                parts.append(seg_part("trees", (s * 6.5, zg + 2.0), (s * 6.5, zf - 3.0), 9.0, tree))
        pw, pd = W * 0.5 - 10.0 - m, front - m - 4.0
        if pw >= 10.0 and pd >= 8.0:
            for s in (-1.0, 1.0):
                parts.append(part("parterre", s * (9.5 + pw * 0.5), z0 + m + 2.0 + pd * 0.5, pw, pd))
        run = z1 - m - zf
        sx = hs * 0.5 + 2.0 + side * 0.5
        if side >= 18.5 and run >= 37.0:
            t = 1.0 if rng.random() < 0.5 else -1.0
            parts.append(part("tennis", t * sx, z1 - m - 18.5, 18.3, 36.6))
            parts.append(part("orchard", -t * sx, z1 - m - 18.5, 18.3, 36.6, 0.0, TREE_KINDS.index("fruit")))
        elif side >= 8.0:
            # Beside the house, in front of a rear tennis court if there is one.
            end = z1 - m - (TENNIS_BACK + 1.0 if court_back else 1.0)
            ol = min(end - zf - 1.0, 40.0)
            if ol >= 8.0:
                for s in (-1.0, 1.0):
                    parts.append(part("orchard", s * sx, end - ol * 0.5, side - 1.0, ol, 0.0, TREE_KINDS.index("fruit")))
        back = z1 - m - (zf + hs)
        if court_back:
            # Across the back of the plot: tennis in one rear corner and an
            # orchard of the same size in the other, or tennis on the axis.
            zc = z1 - m - 1.0 - 18.3 * 0.5
            cx = W * 0.5 - m - 2.0 - 36.6 * 0.5
            if cx >= 36.6 * 0.5 + 2.0:
                t = 1.0 if rng.random() < 0.5 else -1.0
                parts.append(part("tennis", t * cx, zc, 18.3, 36.6, math.pi * 0.5))
                parts.append(part("orchard", -t * cx, zc, 36.6, 18.3, 0.0, TREE_KINDS.index("fruit")))
            else:
                parts.append(part("tennis", 0.0, zc, 18.3, 36.6, math.pi * 0.5))
            return parts, (0.0, zf + hs * 0.5, hs), (0.0, z0 + 0.5)
        if back >= 16.0:
            parts.append(part("parterre", 0.0, zf + hs + back * 0.5, min(W - 2 * m - 12.0, 40.0), back - 6.0))
        if back >= 6.0:
            parts.append(seg_part("trees", (x0 + 5.0, z1 - 3.5), (x1 - 5.0, z1 - 3.5), 10.0, tree))
        return parts, (0.0, zf + hs * 0.5, hs), (0.0, z0 + 0.5)
    # Turned: laid out for +45 degrees (house front to the front-left corner),
    # mirrored for -45.
    S = min(W, D)
    h = hs / math.sqrt(2.0)
    splay = 12.0
    own = _boundary(bound, W, D, splay=splay)
    g = (x0 + 0.5 + splay * 0.5, z0 + 0.5 + splay * 0.5)
    f = (-hs * 0.5 / math.sqrt(2.0), -hs * 0.5 / math.sqrt(2.0))
    u = (f[0] - g[0], f[1] - g[1])
    ln = math.hypot(*u)
    u = (u[0] / ln, u[1] / ln)
    own.append(part("drive", (g[0] + f[0]) * 0.5, (g[1] + f[1]) * 0.5, 6.0, ln, math.atan2(u[0], u[1])))
    for s in (-1.0, 1.0):
        o = (u[1] * s * 6.5, -u[0] * s * 6.5)
        own.append(seg_part("trees", (g[0] + u[0] * 4 + o[0], g[1] + u[1] * 4 + o[1]),
                            (f[0] - u[0] * 3 + o[0], f[1] - u[1] * 3 + o[1]), 9.0, tree))
    a = min(24.0, (S - 2 * m - h - 3.0) * 0.5)
    if a >= 10.0:
        own.append(part("parterre", x1 - m - a * 0.5, z0 + m + a * 0.5, a, a))
        own.append(part("parterre", x0 + m + a * 0.5, z1 - m - a * 0.5, a, a))
    r = min(10.0, (S * 0.5 - m - (h + 2.0) * 0.7071) / 1.7071)
    if r >= 5.0:
        k = (h + 2.0 + r) * 0.7071
        own.append(part("court", k, k, r * 2.0, r * 2.0))
    # Tree rows along the two back walls, between the parterres and the round garden.
    ends = (m + max(a, 0.0) + 3.0, 2.0 * r + 8.0)
    own.append(seg_part("trees", (x0 + ends[0], z1 - 3.5), (x1 - ends[1], z1 - 3.5), 10.0, tree))
    own.append(seg_part("trees", (x1 - 3.5, z0 + ends[0]), (x1 - 3.5, z1 - ends[1]), 10.0, tree))
    if turn < 0:
        own = _mirror(own)
        g = (-g[0], g[1])
    return parts + own, (0.0, 0.0, hs), g


def cluster_layout(W, D, kinds, style, rng):
    """Dwellings scattered over a yard (trailers in loose rows either side
    of a track): (parts, [(kind, x, z, rot)], gate x)."""
    jit = math.radians(CLUSTER_JITTER[style])
    wet = style in ("bayou_village", "camp", "bayou_town")
    parts = [part("yard", 0.0, 0.0, W, D, 0.0, 1 if wet else 0)]
    homes = []
    taken = []
    inner = box(-W * 0.5 + 2.0, -D * 0.5 + 2.0, W * 0.5 - 2.0, D * 0.5 - 2.0)
    if style == "trailers":
        gx = 0.0
        parts.append(part("track", 0.0, 0.0, 5.0, D))
        taken.append(box(-3.5, -D * 0.5, 3.5, D * 0.5))
        for side in (-1.0, 1.0):
            z = -D * 0.5 + 8.0
            while z < D * 0.5 - 6.0:
                if rng.random() < 0.85:
                    homes.append(("trailer_home", side * (13.0 + rng.uniform(-1.0, 1.0)), z + rng.uniform(-0.8, 0.8),
                                  side * math.pi * 0.5 + rng.uniform(-jit, jit)))
                    taken.append(lot_poly(homes[-1][1], homes[-1][2], homes[-1][3], *LOT["trailer_home"]))
                z += 12.0
    else:
        gx = rng.uniform(-W * 0.22, W * 0.22)
        tl = D * rng.uniform(0.45, 0.7)
        parts.append(part("track", gx, -D * 0.5 + tl * 0.5, 3.5, tl))
        taken.append(box(gx - 3.0, -D * 0.5, gx + 3.0, -D * 0.5 + tl + 1.0))
        gap = {"village": 4.0, "bayou_town": 2.5, "bayou_village": 4.0, "camp": 7.0}[style]
        want = rng.randint(2, 4) if style == "camp" else rng.randint(3, 6)
        # Spots on a loose grid, each nudged and turned, tried in random order.
        cols, rows = max(2, int(W / 17.0)), max(1, int(D / 17.0))
        spots = [(-W * 0.5 + (i + 0.5) * W / cols, -D * 0.5 + (k + 0.5) * D / rows) for i in range(cols) for k in range(rows)]
        rng.shuffle(spots)
        for n in range(len(spots) * 4):
            if len(homes) >= want:
                break
            kind = rng.choice(kinds)
            w, d = CLUSTER_LOT.get(kind, LOT[kind])
            rot = rng.uniform(-jit, jit)
            if kind == "trailer_home" and rng.random() < 0.4:
                rot += math.pi * 0.5
            sx, sz = spots[n % len(spots)]
            x, z = sx + rng.uniform(-4.0, 4.0), sz + rng.uniform(-3.0, 3.0)
            poly = lot_poly(x, z, rot, w, d)
            if not inner.contains(poly) or any(poly.distance(t) < gap for t in taken):
                continue
            taken.append(poly)
            homes.append((kind, x, z, rot))
    track = LineString([(gx, -D * 0.5), (gx, D * 0.5 if style == "trailers" else -D * 0.5 + tl)])
    footprints = taken[1:1 + len(homes)]
    del taken[1:1 + len(homes)]
    # A home with no clear way to the track is left out (no rng is drawn).
    kept = []
    for i, (kind, x, z, rot) in enumerate(homes):
        variant = 2 if wet and kind == "stilt_house" else (1 if kind == "trailer_home" else 0)
        own = cluster_path(kind, x, z, rot, track, 2.5 if style == "trailers" else 1.75,
                           [t for j, t in enumerate(footprints) if j != i], variant)
        if own is None:
            continue
        kept.append(homes[i])
        parts += own
        taken += [footprints[i]] + [rect_part_poly(q) for q in own]
    homes = kept
    if style != "camp" or rng.random() < 0.5:
        parts += _boundary("fence", W, D, gx, 6.0)
    # Trees, boats, woodpiles and garden patches in the spaces left.
    extras = [("trees", 1.5, TREE_KINDS.index("cypress" if wet else "oak"))] * rng.randint(2, 5)
    if wet:
        extras += [("boat", 3.0, 0)] * rng.randint(1, 2)
    extras += [("woodpile", 2.0, 0)] * rng.randint(0, 1)
    if not wet and style != "trailers":
        extras += [("garden", 4.0, 0)]
    for kind, room, variant in extras:
        for _ in range(30):
            x, z = rng.uniform(-W * 0.5 + 4.0, W * 0.5 - 4.0), rng.uniform(-D * 0.5 + 4.0, D * 0.5 - 4.0)
            spot = Point(x, z).buffer(room)
            if any(spot.distance(t) < 1.0 for t in taken):
                continue
            taken.append(spot)
            if kind == "trees":
                parts.append(part("trees", x, z, 0.0, 8.0, 0.0, variant))
            elif kind == "garden":
                parts.append(part("garden", x, z, 6.0, 5.0, rng.uniform(-jit, jit)))
            else:
                parts.append(part(kind, x, z, 2.0 if kind == "boat" else 3.0, 5.0 if kind == "boat" else 1.6,
                                  rng.uniform(-math.pi, math.pi)))
            break
    return parts, homes, gx


def cluster_path(kind, x, z, rot, track, track_half, others, variant):
    """A cluster home's way to the yard's track: an apron along its front
    and a footpath from the apron's middle to the nearest point of the
    track, out of the front first when the straight way would cross a home
    (`others`: footprints to keep off). Parts in the plot frame, or None
    when every way crosses a home."""
    w, d = CLUSTER_LOT.get(kind, LOT[kind])
    width = 3.0 if kind == "trailer_home" else 1.6

    def at(lx, lz):
        return frame_point((x, z), rot, lx, lz)

    out = [part("footpath", *at(0.0, -d * 0.5 - 0.9), w, 1.8, rot, variant)]
    start = at(0.0, -d * 0.5 - 1.6)
    if track.distance(Point(start)) <= track_half:
        return out
    home = lot_poly(x, z, rot, w, d)
    best = None
    for out_len in (0.0, 3.0, 6.0, 9.0):
        p = at(0.0, -d * 0.5 - 1.6 - out_len)
        q = track.interpolate(track.project(Point(p))).coords[0]
        legs = ([(start, p)] if out_len > 0.0 else []) + [(p, q)]
        bad = False
        for a, b in legs:
            band = LineString([a, b]).buffer(width * 0.5 + 0.3)
            if band.intersects(home) or any(band.intersects(t) for t in others):
                bad = True
        if not bad:
            best = legs
            break
    if best is None:
        return None
    for a, b in best:
        if dist(a, b) > 0.3:
            # Run a little into the track and the apron so the joins close.
            u = ((b[0] - a[0]) / dist(a, b), (b[1] - a[1]) / dist(a, b))
            out.append(seg_part("footpath", (a[0] - u[0] * width * 0.5, a[1] - u[1] * width * 0.5),
                                (b[0] + u[0] * 0.5, b[1] + u[1] * 0.5), width, variant))
    return out


# The houses a kind of farmstead is dealt, a shuffled deck at a time so
# each turns up in its share: (kind, cards in the deck).
FARM_HOUSES = {
    "flats": [("farmhouse_big", 4), ("farmhouse", 2), ("adobe_farmhouse", 2), ("ranch_house", 2)],
    "homestead": [("farmhouse_small", 4), ("ranch_house", 3), ("farmhouse", 2), ("adobe_farmhouse", 2)],
    "hills": [("farmhouse", 2), ("adobe_farmhouse", 1), ("farmhouse_small", 1)],
}


# How much bigger or smaller than its usual lot a farm home is built: the
# kit draws a different plan on a small (x0.85) and a big (x1.3) lot.
HOME_SCALES = (0.85, 1.0, 1.3)


def _home(kind, cx, front, max_w, max_d, sizes):
    """A farm home's lot (kind, x, z, (w, d)): its usual size scaled by
    the next of HOME_SCALES for its kind (`sizes` counts the homes of each
    kind built so far), capped to the room it has (max_w x max_d), its x
    centre and front edge (z) fixed."""
    s = 1.0
    if sizes is not None:
        s = HOME_SCALES[(sizes[kind] + len(kind)) % len(HOME_SCALES)]
        sizes[kind] += 1
    w = round(min(LOT[kind][0] * s, max_w), 2)
    d = round(min(LOT[kind][1] * s, max_d), 2)
    return (kind, cx, front + d * 0.5, (w, d))


def farmyard_layout(template, rng, house="farmhouse", sizes=None):
    """A farmstead square to its road: ([(kind, x, z, size)], parts, (W, D)),
    size None for a kind's usual lot. House nearest the road beside the
    drive, the yard and its sheds behind; farmyard_at adds the windbreak.
    `sizes` (a Counter per kind) varies the homes' lot sizes."""
    if template == "flats":
        W, D = 90.0, 76.0
        # The house between the left fence and the drive (x -10 +- 2.5).
        lots = [_home(house, -27.75, -35.0, 28.5, 30.0, sizes), ("barn", 4.0, 8.0, None), ("silos", 28.0, 4.0, None)]
        if rng.random() < 0.6:
            lots.append(("machine_shed", -24.0, 22.0, None))
        if rng.random() < 0.45:
            # The hired hand's cottage, in front of the gravel yard.
            lots.append(_home("farmhouse_small", 31.0, -35.0, 22.0, 18.5, sizes))
        dx, yard = -10.0, (11.75, 6.0, 48.5, 44.0)
    elif template == "homestead":
        W, D = 44.0, 38.0
        lots = [_home(house, -4.75, -16.5, 24.5, 20.0, sizes)]
        extra = rng.random()
        if extra < 0.4:
            lots.append(("windpump", 15.0, 9.0, None))
        elif extra < 0.7:
            lots.append(("water_tower", 13.0, 8.0, None))
        dx, yard = 13.0, (13.0, 0.0, 10.0, 14.0)
    else:
        W, D = 64.0, 56.0
        lots = [_home(house, -15.75, -20.0, 22.5, 24.0, sizes), ("machine_shed", 16.0, 12.0, None)]
        dx, yard = 0.0, (13.0, 9.0, 34.0, 30.0)
    z0 = -D * 0.5
    yf = yard[1] - yard[3] * 0.5
    parts = [part("gravel", *yard), part("drive", dx, (z0 + yf) * 0.5, 5.0, yf - z0)]
    e = 0.5
    # The front fence leaves the drive open and stops at each home's lot,
    # jogging back to the home's own front fence (1.2 m in), so the home's
    # gates open on the strip to the road.
    gaps = [(dx - 3.0, dx + 3.0)]
    for kind, x, z, size in lots:
        if size is not None:
            gaps.append((x - size[0] * 0.5, x + size[0] * 0.5))
            for ex in gaps[-1]:
                if not any(a < ex < b for a, b in gaps[:1]):
                    parts.append(seg_part("fence", (ex, z0 + e), (ex, z - size[1] * 0.5 + 1.2), 0.2, 1))
    x = -W * 0.5 + e
    for a, b in sorted(gaps):
        if a > x + 0.3:
            parts.append(seg_part("fence", (x, z0 + e), (a, z0 + e), 0.2, 1))
        x = max(x, b)
    if x < W * 0.5 - e - 0.3:
        parts.append(seg_part("fence", (x, z0 + e), (W * 0.5 - e, z0 + e), 0.2, 1))
    parts += [seg_part("fence", (-W * 0.5 + e, z0 + e), (-W * 0.5 + e, D * 0.5 - e), 0.2, 1),
              seg_part("fence", (W * 0.5 - e, z0 + e), (W * 0.5 - e, D * 0.5 - e), 0.2, 1)]
    if rng.random() < 0.5:
        lots = [(k, -x, z, size) for k, x, z, size in lots]
        parts = _mirror(parts)
    return lots, parts, (W, D)


def polys_of_lines(g):
    """The LineStrings in a (multi)line geometry."""
    if g.is_empty:
        return []
    if g.geom_type == "LineString":
        return [g]
    return [h for h in getattr(g, "geoms", []) if h.geom_type == "LineString"]


def _steps(a, b, step):
    out = []
    v = a
    if step > 0:
        while v <= b + 1e-9:
            out.append(v)
            v += step
    else:
        while v >= b - 1e-9:
            out.append(v)
            v += step
    return out


def _split(a, b, max_len):
    n = max(1, math.ceil(dist(a, b) / max_len))
    pts = [(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n) for k in range(n + 1)]
    return list(zip(pts, pts[1:]))


if __name__ == "__main__":
    main()
