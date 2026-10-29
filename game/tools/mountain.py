"""The Bellerive Hills: a drivable mountain north of the city, like the Santa
Monica Mountains above Los Angeles (HANDOFF-roads-mountain.md M-6).

build_country.py takes from here the zone outline, the roads (a freeway
through the saddle, Crest Drive along the ridge, a canyon road, the
observatory road with its hairpins, a fire road to the masts), the
monument sites, and at the end the height grid the game reads
(scripts/terrain.gd): the ground's own shape, cut and filled to each road's
graded profile and to a flat pad under each lot.

All in local metres (game x = local x, game z = local y; north is -y).
"""

import base64
import json
import math
from pathlib import Path

import numpy as np
import shapely
from shapely.geometry import LineString, Point, Polygon
from shapely.ops import unary_union

from road_classes import CLASSES

WORLD = Path(__file__).resolve().parent.parent / "data" / "world_map.json"

# The foothills (the old Bellerive Hills, M-6): from 90 m north of the
# Beltway (y -330) to the ridge's back; their crests rise toward the massif.
FOOTHILLS = [(270, -430), (235, -800), (200, -1110), (165, -1260), (230, -1400), (400, -1580), (680, -1790), (1100, -1840),
             (1500, -1770), (1770, -1520), (1930, -1220), (2090, -950), (2210, -720), (2130, -600),
             (1900, -560), (1640, -430)]
FALLOFF = 220.0  # the foothills fade in over this far inside their outline
CELL = 8.0
MAX_H = 1100.0
GRID_PAD = 7  # cells round the range's outline (its city and east sides reach ~0 within 6)
GRID_TAPER = 6.0  # outer cells easing what is left down to 0 at the grid's edge

# Mount Calder (HANDOFF-world-mountain.md W-1): the massif north of the city,
# its summit 2.2 km from the city's north edge. A cone with a rounded summit
# plateau, its foot this far out by compass bearing (0 = north, local -y),
# concave (CONE_P) so the lower slopes ease off into the foothills and flats.
SUMMIT = (950.0, -2750.0)
PEAK_H = 995.0
PLATEAU_R = 85.0
CONE_R = [1650, 1600, 1600, 1600, 1600, 1750, 1700, 1600]  # N, NE, E, SE, S, SW, W, NW
CONE_P = [1.2, 1.25, 1.3, 1.3, 1.3, 1.3, 1.3, 1.25]
KNOB = (978.0, -2788.0, 12.0)  # the summit's rock knob: x, y, height over the plateau
# The gullies' floor: height at the summit, reach by bearing (as CONE_R), power.
APRON = (620.0, [2350, 2550, 2500, 2450, 2600, 2300, 2050, 2050], 1.7)
# Water (W-2): the range stops at the Morrow, which runs round its west and
# north foot in a gorge (the West Ridge ends in it; Cinder Ridge rises past
# it). Ground near water is held under WALL x (distance past BANK); past the
# river (the FAR side) the range fades out over FAR_FADE.
WALL = 0.55
BANK = 10.0
FAR_FADE = 260.0
CITY_FADE = 260.0  # the range rises from 0 over this far from the city and its Beltway (self.flat)

# Crests the ground falls away from: [(x, y, height)...], width (m).
RIDGES = [
    # The spine, west to east: Coyote Peak, the saddle the freeway takes,
    # Calder Peak (the masts), the eastern summit.
    ([(170, -1240, 0), (300, -1232, 14), (420, -1215, 32), (530, -1195, 48), (650, -1215, 50), (770, -1245, 40),
      (880, -1270, 58), (1010, -1270, 80), (1100, -1255, 112), (1230, -1230, 92), (1370, -1210, 84),
      (1520, -1190, 98), (1660, -1160, 72), (1800, -1060, 52), (1950, -880, 30), (2080, -720, 8)], 230.0),
    # Spurs toward the city: the observatory's, the west and east ones.
    ([(1100, -1255, 112), (1062, -1050, 88), (1050, -880, 70), (1040, -700, 32), (1030, -560, 8)], 140.0),
    ([(530, -1195, 48), (470, -1000, 40), (400, -760, 22), (380, -600, 8)], 130.0),
    ([(1520, -1190, 98), (1480, -950, 70), (1450, -700, 28)], 150.0),
    # Back spurs, falling north.
    ([(1010, -1270, 80), (1050, -1560, 40)], 150.0),
    ([(530, -1195, 48), (560, -1500, 26)], 150.0),
]
# The foothills rise toward the massif: x1 at the city side, FOOT_RISE more
# by the ridge's back.
FOOT_RISE = 0.9

# The range's crests (sharp-topped "tents"): [(x, y, height)...], side slope.
CRESTS = [
    # West Ridge: Raven Peak, on toward Cinder Ridge past Pine Knob.
    ([(950, -2750, 990), (790, -2880, 810), (580, -3030, 700), (400, -3180, 790), (200, -3330, 610),
      (40, -3470, 520), (-160, -3640, 590), (-450, -3880, 300), (-750, -4130, 190), (-950, -4380, 60)], 0.43),
    # East Ridge: East Peak, falling into the Verdant Hills.
    ([(950, -2750, 990), (1200, -2840, 790), (1450, -2900, 640), (1760, -2880, 780), (2050, -2760, 560),
      (2300, -2590, 400), (2550, -2430, 190), (2750, -2300, 30)], 0.43),
    # North spur: North Knob above Dellwood.
    ([(950, -2750, 990), (1000, -3050, 800), (1040, -3300, 640), (1090, -3580, 700), (1140, -3880, 420),
      (1190, -4150, 120)], 0.45),
    # South spur: down past Calder Knob to Mast Hill on the foothills.
    ([(950, -2750, 990), (960, -2420, 820), (1010, -2050, 610), (1050, -1820, 450), (1080, -1600, 480),
      (1100, -1420, 330), (1106, -1255, 280)], 0.42),
    # South-west spur: the cable car's shoulder, then on down.
    ([(950, -2750, 990), (720, -2440, 780), (560, -2120, 600), (470, -1800, 450), (440, -1600, 420),
      (360, -1380, 260), (260, -1120, 90)], 0.43),
    # West spur: Hawk Peak.
    ([(720, -2700, 850), (420, -2620, 560), (60, -2470, 600), (-250, -2330, 320), (-520, -2180, 60)], 0.44),
    # South-east spur: Larkspur Knob.
    ([(950, -2750, 990), (1250, -2480, 760), (1530, -2200, 520), (1780, -1920, 450), (2020, -1620, 200),
      (2200, -1360, 30)], 0.43),
    # North-east spur.
    ([(950, -2750, 990), (1350, -3150, 720), (1650, -3450, 560), (1950, -3750, 280), (2150, -3950, 60)], 0.45),
]
# The range's named tops (x, y): for the map and the tests.
PEAKS = {"mount_calder": SUMMIT, "raven_peak": (400, -3180), "east_peak": (1760, -2880), "north_knob": (1090, -3580),
         "hawk_peak": (60, -2470), "pine_knob": (-160, -3640), "calder_knob": (1080, -1600),
         "larkspur_knob": (1780, -1920)}
# The summit plateau's sites (x, y, w, d): the car park Mount Calder Road
# ends in, the restaurant, the helipad, the viewing deck the trails end at
# and the cable car's top station, each on a flat pad round the summit's rim.
# Each is at least the road's half width + 15 m clear of every road and track
# (so a road's shoulder keeps its own grading); the summit loop of Mount
# Calder Road leaves room inside it for the restaurant and between its
# turns for the cable top and the helipad.
SUMMIT_SITES = {"car_park": (930.0, -2735.0, 36.0, 24.0), "restaurant": (955.0, -2770.0, 40.0, 30.0),
                "helipad": (1035.0, -2740.0, 30.0, 30.0), "deck": (985.0, -2668.0, 24.0, 14.0),
                "cable_top": (950.0, -2690.0, 26.0, 16.0)}
CREST_ROUND = 35.0  # crests are rounded over this far
CREST_STEEP = 0.6  # a crest's sides are this much steeper at 1000 m than at the foot
SMAX = 40.0  # crests and cone blend over this height difference

# Sites (x, y): the observatory's forecourt end, the letters' middle, the masts.
OBSERVATORY = (1050.0, -909.0)
OBSERVATORY_SIZE = (64.0, 44.0)
# Where Observatory Road ends, a road shoulder short of the lot (a drive
# carries on to the forecourt).
OBSERVATORY_ROAD_END = (OBSERVATORY[0] - 20.0, OBSERVATORY[1] + OBSERVATORY_SIZE[1] * 0.5 + 8.5)
LETTERS = (1330.0, -1085.0)
LETTERS_SIZE = (150.0, 26.0)
MASTS = [(1106.0, -1250.0), (1132.0, -1232.0)]
MAST_SIZE = (18.0, 18.0)

GRADE = {"freeway": 0.06, "highway": 0.075, "road": 0.13, "street": 0.13, "lane": 0.14, "track": 0.25, "trail": 0.3,
         "rail": 0.025}
BLEND = 22.0  # cut and fill fade out over this far beside a road's shoulder, or more:
MAX_BANK = 0.4  # no cut or fill bank steeper than this (the camera looks down at 60 degrees)
PAD_BLEND = 12.0
UNDER_DROP = 6.5  # a trail's underpass runs this far below the road over it
# A road meets the rail at grade when its own ground there is within half of
# this of the rail; otherwise it passes under a rail bridge or over the rail
# (in its cutting), this far apart (5.5 m clearance and the deck).
RAIL_CLEAR = 7.0


LINES = Path(__file__).resolve().parent / "mountain_lines.json"
# The range's own roads (mountain_lines.json, laid by mountain_plan.py), in
# build order: a later road's junctions take an earlier one's height. The
# map routes it re-laid (tag "route") go back into world_map.json.
ROAD_ORDER = ["freeway", "crest", "canyon", "observatory", "fire_road", "calder", "west_ridge_track",
              "larkspur_track", "calder_trail", "raven_trail"]
# The cable car: from Cable Hill at the city's edge, by a mid-station on the
# south-west spur, to the summit's rim.
CABLE = {"bottom": (0.0, -430.0), "mid": (475.0, -1590.0), "top": SUMMIT_SITES["cable_top"][:2]}
CABLE_MID_SIZE = (26.0, 16.0)
CABLE_CLEAR = 18.0  # the cable keeps this far over the ground; a tower goes in where it would not
CABLE_SPAN = 400.0  # and no span between towers is longer than this


def lines():
    """The planned lines: {id: {cls, name, tag, keep_head, pts, spans}}."""
    return json.loads(LINES.read_text())


def roads():
    """The range's roads in build order: [(id, points, class, name, tag,
    spans)], spans [(s0, s1, kind)] along the points ('t' tunnel, 'b'
    bridge). The Letters Trail from the observatory is laid by hand."""
    ls = lines()
    out = [(k, [tuple(q) for q in ls[k]["pts"]], ls[k]["cls"], ls[k]["name"], ls[k]["tag"],
            [tuple(sp) for sp in ls[k]["spans"]]) for k in ROAD_ORDER if k in ls]
    trail = [(OBSERVATORY[0] + OBSERVATORY_SIZE[0] * 0.5 + 5.0, OBSERVATORY[1] + OBSERVATORY_SIZE[1] * 0.5 - 4.0), (1150, -930),
             (1230, -1010), (LETTERS[0] - LETTERS_SIZE[0] * 0.5 + 10.0, LETTERS[1] + LETTERS_SIZE[1] * 0.5 + 5.0)]
    out.append(("letters_trail", trail, "trail", "Letters Trail", "letters_trail", []))
    return out


class Mountain:
    def __init__(self, seed=1234, world=None):
        if world is None:
            world = json.loads(WORLD.read_text())
        city = next(c for c in world["cities"] if c["id"] == "bellerive")
        o = city["demo_window"]["origin"]
        self.urban = Polygon([(x - o[0], y - o[1]) for x, y in city["urban"]]).buffer(0)
        # Flat: the city and the Beltway ringing it (BELT_OFF 80 m out), with
        # 60 m to spare past the Beltway.
        self.flat = self.urban.buffer(360.0).buffer(-220.0)
        self.foothills = Polygon(FOOTHILLS)
        self.foot_edge = self.foothills.exterior
        rng = np.random.default_rng(seed)
        # Value noise: (lattice, wavelength, amplitude at the foot, more per metre up).
        self.lattice = [(rng.uniform(-1.0, 1.0, (64, 64)), 150.0, 7.0, 0.02),
                        (rng.uniform(-1.0, 1.0, (64, 64)), 55.0, 2.5, 0.006),
                        (rng.uniform(-1.0, 1.0, (64, 64)), 430.0, 0.0, 0.05)]
        # Ridged noise: sharp little spurs and gullies down the flanks.
        self.ridged = [(rng.uniform(-1.0, 1.0, (64, 64)), 260.0, 0.07), (rng.uniform(-1.0, 1.0, (64, 64)), 110.0, 0.03)]
        k = np.fft.rfft(np.array(CONE_R, dtype=float))
        kp = np.fft.rfft(np.array(CONE_P, dtype=float))
        ka = np.fft.rfft(np.array(APRON[1], dtype=float))
        self._cone_k = (k, kp, ka)
        self._water(world)
        self.profiles = []  # [LineString, s samples, z samples, half width, bank, spans]
        self.rail_lines = []  # the graded rails' lines (profiles that are rails)
        # Grade separations on the rails: (rail line, s on it, 'b' rail over the
        # road | 't' road over the rail, the road's half width).
        self.rail_cross = []
        self.poly = self._outline()
        self.boundary = self.poly.exterior

    def _water(self, world):
        """The water near the range (local), and the far side of the Morrow."""
        o = next(c for c in world["cities"] if c["id"] == "bellerive")["demo_window"]["origin"]
        near = shapely.box(-2500.0, -6000.0, 4500.0, 500.0)
        parts = []
        for wt in world["water"]:
            if "polygon" in wt:
                g = Polygon([(x - o[0], y - o[1]) for x, y in wt["polygon"]]).buffer(0)
            elif wt["type"] in ("river", "creek"):
                g = LineString([(x - o[0], y - o[1]) for x, y in wt["line"]]).buffer(wt["width"] * 0.5)
            else:
                continue
            if g.intersects(near):
                parts.append(g.intersection(near))
            if wt.get("id") == "morrow":
                riv = [(x - o[0], y - o[1]) for x, y in wt["line"]]
        self.water_geom = unary_union(parts)
        shapely.prepare(self.water_geom)
        # The far side: west and north of the river from where it leaves the
        # flats (-450, -1350) to where it turns north (1150, -5150).
        i0 = riv.index((1150, -5150))
        i1 = riv.index((-450, -1350))
        arc = riv[i0:i1 + 1]
        self.river_arc = LineString(arc)
        self.far = Polygon(arc + [(-3500.0, arc[-1][1]), (-3500.0, -7000.0), (arc[0][0], -7000.0)]).buffer(0)
        shapely.prepare(self.far)

    # --- The ground's own shape -------------------------------------------------

    @staticmethod
    def _value(grid, xs, ys, wave, ang=0.0):
        # Each octave's lattice is turned by its own angle, so no octave lines
        # up with the map's axes (no straight bands across the range).
        c, s = math.cos(ang), math.sin(ang)
        u, v = (xs * c - ys * s) / wave, (xs * s + ys * c) / wave
        i0, j0 = np.floor(u).astype(int), np.floor(v).astype(int)
        fu, fv = u - i0, v - j0
        fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
        g = lambda i, j: grid[i % 64, j % 64]
        a = g(i0, j0) * (1 - fu) + g(i0 + 1, j0) * fu
        b = g(i0, j0 + 1) * (1 - fu) + g(i0 + 1, j0 + 1) * fu
        return a * (1 - fv) + b * fv

    def _noise(self, xs, ys, h):
        out = np.zeros_like(xs)
        for n, (grid, wave, amp, per_m) in enumerate(self.lattice):
            out += self._value(grid, xs, ys, wave, 0.47 + 0.71 * n) * (amp + per_m * h)
        for n, (grid, wave, per_m) in enumerate(self.ridged):
            out += (0.5 - 2.0 * np.abs(self._value(grid, xs, ys, wave, 0.23 + 0.83 * n))) * per_m * h
        return out

    @staticmethod
    def _trig(k, b, n=8):
        """The periodic curve through n values at even bearings, at bearing b (rad)."""
        out = np.full_like(b, k[0].real / n)
        for m in range(1, len(k)):
            f = 1.0 if m == n // 2 else 2.0
            out += f * (k[m].real * np.cos(m * b) - k[m].imag * np.sin(m * b)) / n
        return out

    def _cone(self, xs, ys):
        dx, dy = xs - SUMMIT[0], ys - SUMMIT[1]
        r = np.hypot(dx, dy)
        b = np.arctan2(dx, -dy)
        k, kp, _ka = self._cone_k
        # Spurs and gullies all round: the foot wanders in and out.
        R = self._trig(k, b) * (1.0 + 0.1 * np.sin(7.0 * b + 1.3) + 0.06 * np.sin(12.0 * b + 0.4))
        p = self._trig(kp, b)
        x = r - PLATEAU_R
        rr = 0.5 * (x + np.sqrt(x * x + 40.0 * 40.0))  # the plateau's rim rounded off
        return PEAK_H * np.clip(1.0 - rr / (R - PLATEAU_R), 0.0, 1.0) ** p

    @staticmethod
    def _along(xs, ys, pts):
        """Distance from each point to a polyline [(x, y, h)...] and the
        polyline's height at the nearest point."""
        dmin = np.full_like(xs, np.inf)
        hmin = np.zeros_like(xs)
        for (x0, y0, h0), (x1, y1, h1) in zip(pts, pts[1:]):
            dx, dy = x1 - x0, y1 - y0
            t = np.clip(((xs - x0) * dx + (ys - y0) * dy) / (dx * dx + dy * dy), 0.0, 1.0)
            d = np.hypot(xs - (x0 + dx * t), ys - (y0 + dy * t))
            closer = d < dmin
            dmin = np.where(closer, d, dmin)
            hmin = np.where(closer, h0 + (h1 - h0) * t, hmin)
        return dmin, hmin

    def _base(self, xs, ys):
        """The smooth shape, before noise."""
        massif = self._cone(xs, ys)
        ah, _ar, ap = APRON
        b = np.arctan2(xs - SUMMIT[0], -(ys - SUMMIT[1]))
        ar = self._trig(self._cone_k[2], b)
        apron = ah * np.clip(1.0 - np.hypot(xs - SUMMIT[0], ys - SUMMIT[1]) / ar, 0.0, 1.0) ** ap
        massif = _smax(massif, apron, SMAX)
        pts_ = shapely.points(xs, ys)
        far = shapely.contains(self.far, pts_)
        dfar = np.where(far, shapely.distance(self.river_arc, pts_), 0.0)
        keep = 1.0 - _smooth(np.clip(dfar / FAR_FADE, 0.0, 1.0))
        for pts, slope in CRESTS:
            d, hc = self._along(xs, ys, pts)
            # Steeper sides high up: deep gullies between the upper spurs,
            # gentler slopes into the flats.
            s = slope * (1.0 + CREST_STEEP * np.clip(hc / 1000.0, 0.0, 1.0))
            massif = _smax(massif, hc - s * (np.sqrt(d * d + CREST_ROUND ** 2) - CREST_ROUND), SMAX)
        massif = np.maximum(massif, 0.0) * keep
        kx, ky, kh = KNOB
        massif = massif + kh * np.exp(-((xs - kx) ** 2 + (ys - ky) ** 2) / (24.0 ** 2))
        du = shapely.distance(pts_, self.flat)
        massif = np.maximum(massif, 0.0) * _smooth(np.clip(du / CITY_FADE, 0.0, 1.0))
        foot = np.zeros_like(xs)
        for pts, width in RIDGES:
            d, hc = self._along(xs, ys, pts)
            foot = np.maximum(foot, hc * np.exp(-(d / width) ** 2))
        foot *= 1.0 + FOOT_RISE * _smooth(np.clip((-ys - 560.0) / 700.0, 0.0, 1.0))
        foot *= _smooth(np.clip(du / CITY_FADE, 0.0, 1.0)) * keep
        h = _smax(massif, foot, SMAX)
        # Down to the water: a gorge wall, rounded at its foot and its lip.
        dw = shapely.distance(self.water_geom, pts_)
        wall = WALL * (dw - BANK) + 2.0 * np.maximum(dw - 500.0, 0.0)  # a gorge, not the whole range
        return np.maximum(_smin(h, wall, 30.0), 0.0)

    def raw(self, xs, ys):
        """Height of the untouched ground at arrays of points (0 off the range)."""
        xs = np.asarray(xs, dtype=float)
        ys = np.asarray(ys, dtype=float)
        base = self._base(xs, ys)
        # No noise on the summit plateau (the pads stand there), more and
        # more of it from its rim down, none on the flats.
        rim = _smooth(np.clip((np.hypot(xs - SUMMIT[0], ys - SUMMIT[1]) - PLATEAU_R) / 220.0, 0.0, 1.0))
        return np.clip(base + self._noise(xs, ys, base) * np.clip(base / 40.0, 0.0, 1.0) * rim, 0.0, MAX_H)

    def _outline(self):
        """The range's zone: where its ground stands over a metre, with the
        foothills' own outline."""
        step = 16.0
        x0, y0, x1, y1 = -1600.0, -4800.0, 3400.0, -200.0
        gx, gy = np.meshgrid(np.arange(x0, x1, step), np.arange(y0, y1, step))
        xs, ys = gx.ravel(), gy.ravel()
        up = self.raw(xs, ys) > 1.0
        cells = shapely.box(xs[up] - step * 0.5, ys[up] - step * 0.5, xs[up] + step * 0.5, ys[up] + step * 0.5)
        g = shapely.union_all(cells).buffer(step).buffer(-step)
        g = unary_union([g, self.foothills])
        g = max(getattr(g, "geoms", [g]), key=lambda q: q.area)
        return Polygon(g.exterior).simplify(6.0)

    def raw_at(self, p):
        return float(self.raw(np.array([p[0]]), np.array([p[1]]))[0])

    # --- Laying lines on the ground -------------------------------------------------

    def ground(self, xs, ys):
        """The untouched ground, bilinear from a 4 m cache (for tracing)."""
        if getattr(self, "_cache", None) is None:
            x0, y0, x1, y1 = self.poly.bounds
            x0, y0 = math.floor(x0 / 4.0) * 4.0 - 8.0, math.floor(y0 / 4.0) * 4.0 - 8.0
            nx, ny = int((x1 - x0) / 4.0) + 4, int((y1 - y0) / 4.0) + 4
            gx, gy = np.meshgrid(x0 + np.arange(nx) * 4.0, y0 + np.arange(ny) * 4.0)
            self._cache = (x0, y0, self.raw(gx.ravel(), gy.ravel()).reshape(ny, nx))
        x0, y0, hh = self._cache
        ny, nx = hh.shape
        u = np.clip((np.asarray(xs, dtype=float) - x0) / 4.0, 0.0, nx - 1.001)
        v = np.clip((np.asarray(ys, dtype=float) - y0) / 4.0, 0.0, ny - 1.001)
        i, j = u.astype(int), v.astype(int)
        fu, fv = u - i, v - j
        a = hh[j, i] * (1 - fu) + hh[j, i + 1] * fu
        b = hh[j + 1, i] * (1 - fu) + hh[j + 1, i + 1] * fu
        return a * (1 - fv) + b * fv

    # --- Road profiles -------------------------------------------------------------

    def _profile_z(self, prof, p, reach):
        line, s, z, hw, _bank, spans = prof
        d = line.distance(Point(p))
        if d >= reach(hw):
            return None
        sp = line.project(Point(p))
        if any(a < sp < b for a, b, _k in spans):
            return None
        return d, float(np.interp(sp, s, z))

    def profile_at(self, p, skip=()):
        """The height of the nearest graded road at p, or None off them (or
        over a tunnel or under a bridge); `skip` lines are left out."""
        best = None
        for prof in self.profiles:
            if any(prof[0] is q for q in skip):
                continue
            got = self._profile_z(prof, p, lambda hw: hw + 3.0)
            if got and (best is None or got[0] < best[0]):
                best = got
        return None if best is None else best[1]

    def profile_near(self, p, reach):
        """The height of the nearest graded road within `reach` of p (the
        road a lot fronts), or None."""
        best = None
        for prof in self.profiles:
            got = self._profile_z(prof, p, lambda _hw: reach)
            if got and (best is None or got[0] < best[0]):
                best = got
        return None if best is None else best[1]

    def grade(self, line, cls, ends=None, spans=(), cap=None, loose=(), flat_end=0.0):
        """Grades a road: its height follows the ground, smoothed, no steeper
        than its class allows (or `cap`); ends on the flat or on an earlier
        road keep that height. spans [(s0, s1, kind)]: tunnels ('t') and
        bridges ('b') run straight between their ends, the ground left
        alone; loose ends (0, -1) on no road are not held to the ground
        (where a map route leaves the play area, barricaded); an underpass ('u') passes UNDER_DROP below the road it
        crosses there; the last `flat_end` metres are level (into a car park). Returns the max grade it reached."""
        if self.poly.distance(line) > 1.0:
            return 0.0
        n = max(2, math.ceil(line.length / 4.0))
        s = np.linspace(0.0, line.length, n + 1)
        pts = np.array([line.interpolate(v).coords[0] for v in s])
        ground = self.raw(pts[:, 0], pts[:, 1])
        z = ground.copy()
        inside = np.zeros(len(s), dtype=bool)
        for a, b, _k in spans:
            inside |= (s > a) & (s < b)
        # Over a span the "ground" is the straight line between its ends.
        for a, b, _k in spans:
            if _k == "u":
                continue
            ia, ib = int(np.searchsorted(s, a)), int(np.searchsorted(s, b))
            ia, ib = max(ia - 1, 0), min(ib, len(s) - 1)
            z[ia:ib + 1] = np.linspace(z[ia], z[ib], ib - ia + 1)
        k = 15
        if len(z) > k:
            z = np.convolve(np.pad(z, k // 2, mode="edge"), np.ones(k) / k, mode="valid")
        own = z.copy()
        # A road does not end on the rail (it ends at the river or a road by it).
        rails = self.rail_lines if cls != "rail" else ()
        pins = {}
        for e, i in ((0, 0), (-1, len(s) - 1)):
            h = self.profile_at(tuple(pts[i]), rails)
            if h is None and e in loose:
                continue
            pins[i] = h if h is not None else float(ground[i])
        if ends:
            for i, h in ends.items():
                pins[i if i >= 0 else len(s) + i] = h
        # Where it crosses an earlier road at grade, both share that height.
        rail_x = []
        src = {}  # pin index -> the road it meets there
        for other, os_, oz, _hw, _bank, ospans in self.profiles:
            for q in _points(line.intersection(other)):
                sq = line.project(Point(q))
                so = other.project(Point(q))
                if any(a < so < b for a, b, _k in ospans):
                    continue
                under = any(a < sq < b and k == "u" for a, b, k in spans)
                if any(a < sq < b for a, b, _k in spans) and not under:
                    continue
                i = int(round(sq / (line.length / n)))
                h = float(np.interp(so, os_, oz))
                if not under and any(other is r for r in rails):
                    rail_x.append((i, h, other, so))
                    continue
                pins[i] = h - (UNDER_DROP if under else 0.0)
                src[i] = id(other)
        g = cap if cap is not None else GRADE[cls]
        ds = line.length / n
        # Where it runs alongside an earlier road (within about a 45 degree
        # angle of it) so close that their graded ground would meet in a
        # crease under one of them, it takes that road's height: the two
        # read as one wider road there, merging and parting. Only where that
        # height is in reach of its other pins at its grade (else a kink).
        if cls not in ("trail", "rail"):
            share = {}
            P = shapely.points(pts[:, 0], pts[:, 1])
            tan = np.gradient(pts, axis=0)
            tan /= np.maximum(np.linalg.norm(tan, axis=1), 1e-9)[:, None]
            for other, os_, oz, ohw, _bank, ospans in self.profiles:
                reach = _HALF[cls] + ohw + 2.0 * CELL
                if ohw <= _HALF["trail"] or any(other is r for r in self.rail_lines) or other.distance(line) >= reach:
                    continue
                for i in np.nonzero(shapely.distance(other, P) < reach)[0]:
                    if i in pins or inside[i]:
                        continue
                    so = other.project(Point(pts[i]))
                    if any(a < so < b for a, b, _k in ospans):
                        continue
                    qa = other.interpolate(max(so - 2.0, 0.0)).coords[0]
                    qb = other.interpolate(min(so + 2.0, other.length)).coords[0]
                    ot = np.subtract(qb, qa)
                    if abs(float(np.dot(tan[i], ot))) < 0.7 * float(np.linalg.norm(ot)):
                        continue
                    share.setdefault(int(i), (float(np.interp(so, os_, oz)), id(other)))
            for i, (v, who) in sorted(share.items()):
                if all(abs(v - hj) <= g * ds * abs(i - j) + 0.05 for j, hj in pins.items()):
                    pins[i] = v
                    src[i] = who
        if flat_end > 0.0 and len(s) - 1 in pins:
            for i in np.nonzero(s >= s[-1] - flat_end)[0]:
                pins[int(i)] = pins[len(s) - 1]
        # Where it crosses the rail: at grade, under a rail bridge or over the
        # rail, whichever its other pins can reach at its grade and its own
        # ground is nearest (at grade a little preferred). The crossings are
        # chosen together, in order along the road (a road and rail sharing
        # a gorge cross several times): each choice must be reachable at the
        # grade from the one before.
        free = []
        for i, h, other, so in sorted(rail_x, key=lambda q: q[0]):
            o = float(own[i])
            if abs(o - h) >= RAIL_CLEAR:
                self.rail_cross.append((other, so, "b" if h > o else "t", _HALF.get(cls, 4.0)))
            else:
                free.append((i, h, other, so, o))

        def miss(v, i, j, hj):
            return max(0.0, abs(v - hj) - g * ds * abs(i - j))
        best = []  # per crossing, per option: (total cost, option, back pointer)
        for c, (i, h, _other, _so, o) in enumerate(free):
            row = []
            for v, kind, extra in ((h, None, 0.0), (h - RAIL_CLEAR, "b", 2.0), (h + RAIL_CLEAR, "t", 2.0)):
                cost = 10.0 * sum(miss(v, i, j, hj) for j, hj in pins.items()) + abs(v - o) + extra
                back = None
                if c:
                    pi = free[c - 1][0]
                    back, prev = min(((k, t[0] + 10.0 * miss(v, i, pi, t[1][0])) for k, t in enumerate(best[-1])),
                                     key=lambda q: q[1])
                    cost += prev
                row.append((cost, (v, kind), back))
            best.append(row)
        if free:
            k = min(range(3), key=lambda q: best[-1][q][0])
            for c in range(len(free) - 1, -1, -1):
                (v, kind), back = best[c][k][1], best[c][k][2]
                i, _h, other, so, _o = free[c]
                pins[i] = v
                if kind:
                    self.rail_cross.append((other, so, kind, _HALF.get(cls, 4.0)))
                k = back
        for i, h in pins.items():
            z[i] = h
        # Pinned heights stay; the rest is pulled within the grade of them.
        for _ in range(4):
            for i in range(1, len(z)):
                if i not in pins:
                    z[i] = min(max(z[i], z[i - 1] - g * ds), z[i - 1] + g * ds)
            for i in range(len(z) - 2, -1, -1):
                if i not in pins:
                    z[i] = min(max(z[i], z[i + 1] - g * ds), z[i + 1] + g * ds)
        # Spans stay straight between their (graded) ends.
        for a, b, _k in spans:
            if _k == "u":
                continue
            ia, ib = max(int(np.searchsorted(s, a)) - 1, 0), min(int(np.searchsorted(s, b)), len(s) - 1)
            z[ia:ib + 1] = np.linspace(z[ia], z[ib], ib - ia + 1)
        # How far the cut or fill fades out: wide enough to keep its bank gentle.
        bank = np.maximum(BLEND, np.abs(ground - z) / MAX_BANK)
        bank[inside] = BLEND
        self.profiles.append([line, s, z, _HALF[cls], bank, [tuple(sp) for sp in spans]])
        if cls == "rail":
            self.rail_lines.append(line)
        # The way inside an underpass is not laid (it stops at the portals).
        _dz = np.abs(np.diff(z)) / ds
        mid = (s[:-1] + s[1:]) * 0.5
        for a, b, kk in spans:
            if kk == "u":
                _dz[(mid > a) & (mid < b)] = 0.0
        # Where it runs on an earlier road (pins on that road one after
        # another) the grade is that road's, reported for it.
        for i in range(len(_dz)):
            if src.get(i) is not None and src.get(i) == src.get(i + 1):
                _dz[i] = 0.0
        return float(np.max(_dz))

    def cable(self):
        """The cable car: {stations: [{id, x, y, z}], towers: [{x, y, z, h}]}.
        A station's z is its ground (its pad's height); between two
        stations the cable runs straight from 12 m over each, and a tower
        stands wherever the ground comes within CABLE_CLEAR of it."""
        names = ("bottom", "mid", "top")
        st = [{"id": k, "x": CABLE[k][0], "y": CABLE[k][1], "z": round(max(0.0, self.raw_at(CABLE[k])), 1)} for k in names]
        towers = []

        def span(a, b, depth=0):
            n = max(8, int(math.dist(a[:2], b[:2]) / 8.0))
            u = np.linspace(0.0, 1.0, n + 1)[1:-1]
            # Clear of the station or tower at each end (it holds the cable up there).
            L = math.dist(a[:2], b[:2])
            u = u[(u * L > 60.0) & ((1.0 - u) * L > 60.0)]
            if len(u) == 0:
                return
            xs, ys = a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u
            g = np.maximum(self.raw(xs, ys), 0.0)
            clear = a[2] + (b[2] - a[2]) * u - g
            i = int(np.argmin(clear))
            if depth > 6:
                return
            if clear[i] >= CABLE_CLEAR:
                if L <= CABLE_SPAN:
                    return
                # Clear all the way, but too long a span: a tower halfway, as tall as the cable is high there.
                i = len(u) // 2
                top = (float(xs[i]), float(ys[i]), float(g[i]) + min(max(float(clear[i]), CABLE_CLEAR + 12.0), 45.0))
            else:
                top = (float(xs[i]), float(ys[i]), float(g[i]) + CABLE_CLEAR + 12.0)
            span(a, top, depth + 1)
            towers.append({"x": round(top[0], 1), "y": round(top[1], 1), "z": round(float(g[i]), 1),
                           "h": round(top[2] - float(g[i]), 1)})
            span(top, b, depth + 1)

        for s0, s1 in zip(st, st[1:]):
            span((s0["x"], s0["y"], s0["z"] + 12.0), (s1["x"], s1["y"], s1["z"] + 12.0))
        return {"stations": st, "towers": towers}

    # --- The height grid ------------------------------------------------------------

    def grid(self, pads):
        """The final heights: the ground, cut and filled to the roads and to
        each lot's pad ([polygon, height]). Returns the export dict.

        Each road owns the ground within its shoulder and a cell more (the
        nearest road's height, so no road's surface is mixed with another's);
        past that its cut or fill fades into the ground over its bank, the
        roads' heights blended where banks overlap. Over a tunnel or under a
        bridge the ground is left alone."""
        x0, y0, x1, y1 = self.poly.bounds
        pad = GRID_PAD * CELL
        x0, y0 = math.floor(x0 / CELL) * CELL - pad, math.floor(y0 / CELL) * CELL - pad
        nx = int(math.ceil((x1 + pad - x0) / CELL)) + 1
        ny = int(math.ceil((y1 + pad - y0) / CELL)) + 1
        gx, gy = np.meshgrid(x0 + np.arange(nx) * CELL, y0 + np.arange(ny) * CELL)
        h = self.raw(gx.ravel(), gy.ravel()).reshape(ny, nx)
        wsum = np.zeros_like(h)
        zsum = np.zeros_like(h)
        margin = np.zeros_like(h)
        reach = np.zeros_like(h)
        dcore = np.full_like(h, np.inf)
        zcore = np.zeros_like(h)

        def window(geom, pad):
            bx0, by0, bx1, by1 = geom.bounds
            i0 = max(int(math.floor((bx0 - pad - x0) / CELL)), 0)
            i1 = min(int(math.ceil((bx1 + pad - x0) / CELL)) + 1, nx)
            j0 = max(int(math.floor((by0 - pad - y0) / CELL)), 0)
            j1 = min(int(math.ceil((by1 + pad - y0) / CELL)) + 1, ny)
            return slice(j0, j1), slice(i0, i1)

        for line, s, z, hw, bank, spans in self.profiles:
            edge = hw + 2.0
            far = edge + float(np.max(bank))
            win = window(line, far)
            pts = shapely.points(gx[win].ravel(), gy[win].ravel())
            d = shapely.distance(line, pts).reshape(gx[win].shape)
            sp = shapely.line_locate_point(line, pts).reshape(d.shape)
            ok = d < far
            for a, b, _k in spans:
                ok &= ~((sp > a) & (sp < b))
            zr = np.interp(sp, s, z)
            blend = np.interp(sp, s, bank)
            w = np.where(ok, 1.0 - _smooth(np.clip(d / (edge + blend), 0.0, 1.0)), 0.0)
            wsum[win] += w * w
            zsum[win] += w * w * zr
            if hw > _HALF["trail"]:  # a trail runs onto a pad (the deck) at its height
                margin[win] = np.maximum(margin[win], np.where(ok, 1.0 - _smooth(np.clip((d - hw - 1.0) / CELL, 0.0, 1.0)), 0.0))
            reach[win] = np.maximum(reach[win], np.where(ok, 1.0 - _smooth(np.clip((d - edge) / blend, 0.0, 1.0)), 0.0))
            # The rail's shelf is rigid (laid at its own heights): within its
            # reach it owns the ground over any road (roads drape over it);
            # a trail owns only ground no road reaches (it drapes on theirs).
            dk = d - 1000.0 if any(line is r for r in self.rail_lines) else d + 1000.0 if hw <= _HALF["trail"] else d
            core = ok & (d <= edge + CELL) & (dk < dcore[win])
            dcore[win] = np.where(core, dk, dcore[win])
            zcore[win] = np.where(core, zr, zcore[win])
        zroad = np.where(wsum > 1e-9, zsum / np.maximum(wsum, 1e-9), h)
        zroad = np.where(np.isfinite(dcore), zcore, zroad)
        h = h * (1.0 - reach) + zroad * reach
        h = np.where(np.isfinite(dcore), zcore, h)
        if pads:
            # Each node takes the height of the nearest pad, flat a cell past
            # the lot's edge (so the bilinear ground under the whole lot is
            # at its height) and fading out beyond; a road keeps its own
            # grading a cell past its edge.
            dbest = np.full_like(h, np.inf)
            hbest = np.zeros_like(h)
            for poly, ph in pads:
                win = window(poly, CELL + 2.0 + PAD_BLEND)
                d = shapely.distance(poly, shapely.points(gx[win].ravel(), gy[win].ravel())).reshape(gx[win].shape)
                closer = d < dbest[win]
                dbest[win] = np.where(closer, d, dbest[win])
                hbest[win] = np.where(closer, ph, hbest[win])
            w = (1.0 - _smooth(np.clip((dbest - CELL - 2.0) / PAD_BLEND, 0.0, 1.0))) * (1.0 - margin)
            w = np.where(dbest <= 0.0, 1.0, w)  # under the lot itself, the pad
            h = h * (1.0 - w) + hbest * w
        h = np.clip(h, 0.0, MAX_H)
        # Past the grid the game reads 0: the outer GRID_TAPER cells ease the
        # ground down to it (the range's outline leaves up to ~5 m there).
        ramp = _smooth(np.clip(np.arange(max(nx, ny)) / GRID_TAPER, 0.0, 1.0))
        h = h * np.minimum(ramp[np.minimum(np.arange(nx), np.arange(nx)[::-1])][None, :],
                           ramp[np.minimum(np.arange(ny), np.arange(ny)[::-1])][:, None])
        self.heights = h
        self.origin = (x0, y0)
        raw = np.round(self.heights * 10.0).astype("<u2").tobytes()
        return {"origin": [x0, y0], "cell": CELL, "size": [nx, ny], "dm": base64.b64encode(raw).decode("ascii")}

    def height(self, p):
        """Bilinear height from the final grid (as the game reads it)."""
        x0, y0 = self.origin
        ny, nx = self.heights.shape
        u, v = (p[0] - x0) / CELL, (p[1] - y0) / CELL
        i, j = int(math.floor(u)), int(math.floor(v))
        if i < 0 or j < 0 or i >= nx - 1 or j >= ny - 1:
            return 0.0
        fu, fv = u - i, v - j
        hh = self.heights
        a = hh[j, i] * (1 - fu) + hh[j, i + 1] * fu
        b = hh[j + 1, i] * (1 - fu) + hh[j + 1, i + 1] * fu
        return float(a * (1 - fv) + b * fv)


_HALF = {k: c["w"] * 0.5 for k, c in CLASSES.items()}
_HALF["rail"] = 5.0  # a single track on its ballast shelf


def _smax(a, b, k):
    """A max of a and b with the corner rounded over k (no wider than the
    lower of the two, so bare ground stays at 0)."""
    k = np.minimum(k, np.maximum(np.minimum(a, b), 1e-6))
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.maximum(a, b) + h * h * k * 0.25


def _smin(a, b, k):
    """A min of a and b with the corner rounded over k."""
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def _smooth(t):
    return t * t * (3.0 - 2.0 * t)


def _dense(line, step):
    """Points along a line (a LineString or a point list) every `step` m or less."""
    ln = line if isinstance(line, LineString) else LineString(line)
    n = max(1, math.ceil(ln.length / step))
    return [ln.interpolate(ln.length * k / n).coords[0] for k in range(n + 1)]


def _points(geom):
    if geom.is_empty:
        return []
    if geom.geom_type == "Point":
        return [geom.coords[0]]
    if hasattr(geom, "geoms"):
        out = []
        for g in geom.geoms:
            out += _points(g)
        return out
    return [geom.coords[0], geom.coords[-1]]
