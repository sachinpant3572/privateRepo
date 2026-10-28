"""Country road classes, shared by build_country.py and mountain.py.

w: width (m); speed: traffic cruise speed (m/s); graph: drivable by traffic;
r: corner radius for the world map's polylines; step: resample step; prio:
which class wins where two meet. Lanes (read by the game, city.gd
lane_offset): `lanes` each way, `lane_w` wide, starting `middle` out from the
centreline (a median, or the centre line), `park` a parking strip at the
edge. The freeway is 8 lanes, highways 6, avenues and streets 4; county
roads, mountain roads, lanes and tracks stay 2 lanes.
"""

CLASSES = {
    "freeway": {"w": 36.0, "speed": 26.0, "graph": True, "r": 300.0, "step": 24.0, "prio": 7,
                "lanes": 4, "lane_w": 3.6, "middle": 1.4, "park": 0.0},
    "highway": {"w": 27.0, "speed": 22.0, "graph": True, "r": 260.0, "step": 24.0, "prio": 6,
                "lanes": 3, "lane_w": 3.6, "middle": 1.0, "park": 0.0},
    "avenue": {"w": 16.0, "speed": 15.0, "graph": True, "r": 60.0, "step": 20.0, "prio": 5,
               "lanes": 2, "lane_w": 3.5, "middle": 0.2, "park": 0.0},
    "road": {"w": 10.0, "speed": 17.0, "graph": True, "r": 140.0, "step": 20.0, "prio": 4,
             "lanes": 1, "lane_w": 3.6, "middle": 0.6, "park": 0.0},
    "street": {"w": 15.0, "speed": 12.0, "graph": True, "r": 20.0, "step": 20.0, "prio": 3,
               "lanes": 2, "lane_w": 3.4, "middle": 0.2, "park": 0.0},
    "lane": {"w": 7.0, "speed": 12.0, "graph": True, "r": 60.0, "step": 14.0, "prio": 2,
             "lanes": 1, "lane_w": 3.2, "middle": 0.0, "park": 0.0},
    "track": {"w": 6.0, "speed": 9.0, "graph": True, "r": 40.0, "step": 14.0, "prio": 1,
              "lanes": 1, "lane_w": 2.8, "middle": 0.0, "park": 0.0},
    "trail": {"w": 3.5, "speed": 6.0, "graph": False, "r": 25.0, "step": 12.0, "prio": 0,
              "lanes": 0, "lane_w": 0.0, "middle": 0.0, "park": 0.0},
}

# The street plan's classes (street_plan.gd CLASSES) ranked for joining
# country roads to the city's frame: 15 and up is an avenue or boulevard.
CITY_RANK = {"boulevard": 24, "avenue": 15, "street": 11, "quay": 10, "quarter": 9, "lane": 7}
