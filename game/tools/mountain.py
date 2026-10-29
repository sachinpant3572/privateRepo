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
APRON = (620.0, 2700.0, 1.7)  # the gullies' floor: height at the summit, reach, power
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
      (40, -3470, 520), (-160, -3640, 590), (-450, -3880, 380), (-750, -4130, 210), (-950, -4380, 60)], 0.43),
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

GRADE = {"freeway": 0.06, "highway": 0.075, "road": 0.13, "street": 0.13, "lane": 0.14, "track": 0.25, "trail": 0.3}
BLEND = 22.0  # cut and fill fade out over this far beside a road's shoulder, or more:
MAX_BANK = 0.4  # no cut or fill bank steeper than this (the camera looks down at 60 degrees)
PAD_BLEND = 12.0


def roads(route_at):
    """The mountain's roads, in build order (a later road's junctions take
    an earlier one's height): [(points, class, name, tag, fillet radius)].
    route_at(name, near) gives the point on a map route nearest `near`."""
    freeway = [(690, -338), (696, -560), (722, -850), (752, -1080), (770, -1262), (800, -1420), (900, -1580),
               (1100, -1740), (1450, -1930), (1900, -1980), (2350, -1820), route_at("Route 1 Gulf Highway", (2700, -1600))]
    crest = [route_at("Route 9 River Road", (132, -1250)), (270, -1265), (400, -1255), (530, -1240), (650, -1250),
             (770, -1262), (880, -1322), (1010, -1362), (1110, -1388), (1230, -1342), (1370, -1300), (1520, -1270),
             (1660, -1225), (1760, -1132), (1840, -1010), (1990, -800), route_at("Route 1 Gulf Highway", (2300, -560))]
    coyote = [(452, -338), (470, -500), (540, -650), (590, -820), (600, -980), (612, -1120), (650, -1250)]
    observatory = [(1010, -338), (1015, -470), (1100, -560), (1180, -640), (1190, -700), (1110, -712),
                   (990, -760), (965, -820), (1000, -870), OBSERVATORY_ROAD_END]
    fire = [(1110, -1388), (1150, -1335), (1122, -1295), (1090, -1276), (1086, -1250)]
    trail = [(OBSERVATORY[0] + OBSERVATORY_SIZE[0] * 0.5 + 5.0, OBSERVATORY[1] + OBSERVATORY_SIZE[1] * 0.5 - 4.0), (1150, -930),
             (1230, -1010), (LETTERS[0] - LETTERS_SIZE[0] * 0.5 + 10.0, LETTERS[1] + LETTERS_SIZE[1] * 0.5 + 5.0)]
    return [
        (freeway, "highway", "Canyon Freeway", "freeway", 200.0),
        (crest, "road", "Crest Drive", "crest", 45.0),
        (coyote, "road", "Coyote Canyon Road", "canyon", 50.0),
        (observatory, "road", "Observatory Road", "observatory", 26.0),
        (fire, "track", "Summit Fire Road", "fire_road", 12.0),
        (trail, "trail", "Letters Trail", "letters_trail", 15.0),
    ]


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
        self._cone_k = (k, kp)
        self.profiles = []  # [LineString, s samples, z samples, half width, bank]
        self.poly = self._outline()
        self.boundary = self.poly.exterior

    # --- The ground's own shape -------------------------------------------------

    @staticmethod
    def _value(grid, xs, ys, wave):
        u, v = xs / wave, ys / wave
        i0, j0 = np.floor(u).astype(int), np.floor(v).astype(int)
        fu, fv = u - i0, v - j0
        fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
        g = lambda i, j: grid[i % 64, j % 64]
        a = g(i0, j0) * (1 - fu) + g(i0 + 1, j0) * fu
        b = g(i0, j0 + 1) * (1 - fu) + g(i0 + 1, j0 + 1) * fu
        return a * (1 - fv) + b * fv

    def _noise(self, xs, ys, h):
        out = np.zeros_like(xs)
        for grid, wave, amp, per_m in self.lattice:
            out += self._value(grid, xs, ys, wave) * (amp + per_m * h)
        for grid, wave, per_m in self.ridged:
            out += (0.5 - 2.0 * np.abs(self._value(grid, xs, ys, wave))) * per_m * h
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
        k, kp = self._cone_k
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
        ah, ar, ap = APRON
        apron = ah * np.clip(1.0 - np.hypot(xs - SUMMIT[0], ys - SUMMIT[1]) / ar, 0.0, 1.0) ** ap
        massif = _smax(massif, apron, SMAX)
        for pts, slope in CRESTS:
            d, hc = self._along(xs, ys, pts)
            # Steeper sides high up: deep gullies between the upper spurs,
            # gentler slopes into the flats.
            s = slope * (1.0 + CREST_STEEP * np.clip(hc / 1000.0, 0.0, 1.0))
            massif = _smax(massif, hc - s * (np.sqrt(d * d + CREST_ROUND ** 2) - CREST_ROUND), SMAX)
        kx, ky, kh = KNOB
        massif = massif + kh * np.exp(-((xs - kx) ** 2 + (ys - ky) ** 2) / (24.0 ** 2))
        du = shapely.distance(shapely.points(xs, ys), self.flat)
        massif = np.maximum(massif, 0.0) * _smooth(np.clip(du / CITY_FADE, 0.0, 1.0))
        foot = np.zeros_like(xs)
        for pts, width in RIDGES:
            d, hc = self._along(xs, ys, pts)
            foot = np.maximum(foot, hc * np.exp(-(d / width) ** 2))
        foot *= 1.0 + FOOT_RISE * _smooth(np.clip((-ys - 560.0) / 700.0, 0.0, 1.0))
        foot *= _smooth(np.clip(du / CITY_FADE, 0.0, 1.0))
        return _smax(massif, foot, SMAX)

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

    def trace(self, start, heading, grade, spine=None, half=300.0, goal=None, stop=None, avoid=None, others=(),
              step=8.0, turn=24.0, hairpin_r=15.0, sep=36.0, max_len=16000.0, top=None, pull=3.0):
        """A line up the ground at about `grade`, as a road builder lays one:
        each step takes the heading (within `turn` degrees of the last) whose
        ground rises closest to grade x step, keeping `sep` clear of its own
        earlier legs and of `others` (lines). With a `spine` (a line up a
        spur) it zigzags across it, turning in a hairpin of `hairpin_r` when
        it is `half` off to either side. It heads for `goal` once the goal is
        within its grade, and stops there, at height `top`, or when
        stop(point) says so. heading in degrees (0 = east, 90 = south)."""
        pts = [tuple(start)]
        h = math.radians(heading)
        z = float(self.ground([start[0]], [start[1]])[0])
        side = 0
        if spine is not None:
            side = 1 if self._offset(spine, start, h) >= 0.0 else -1
        length = 0.0
        own_gap = math.pi * hairpin_r + 60.0
        other_pts = np.array([q for ln in others for q in _dense(ln, 6.0)]) if others else np.zeros((0, 2))
        cand = np.radians(np.linspace(-turn, turn, 13))
        while length < max_len:
            p = pts[-1]
            if goal is not None:
                dg = math.dist(p, goal)
                if dg < step * 1.5:
                    pts.append(tuple(goal))
                    break
                reach = float(self.ground([goal[0]], [goal[1]])[0]) - z <= grade * 1.05 * dg
            else:
                reach = False
            th = h + cand
            qx, qy = p[0] + step * np.cos(th), p[1] + step * np.sin(th)
            rise = (self.ground(qx, qy) - z) / step
            over = np.maximum(rise - grade, 0.0)
            cost = ((rise - grade) / 0.03) ** 2 + (over / 0.01) ** 2 + 0.6 * (cand / math.radians(turn)) ** 2
            gb = math.atan2(goal[1] - p[1], goal[0] - p[0]) if goal is not None else h
            if goal is not None:
                # On a face this barely tilts a leg; on a saddle it picks the
                # way on rather than back up the knob behind.
                cost = cost + pull * (1.0 - np.cos(th - gb))
            if reach:
                cost = cost * 0.2 + 6.0 * (1.0 - np.cos(th - gb)) + (over / 0.01) ** 2
            elif rise.max() < grade * 0.9:
                # Gentler ground than the grade: on toward the goal, as steeply as it goes.
                cost = 3.0 * (1.0 - np.cos(th - gb)) + 0.3 * ((grade - rise) / 0.03) ** 2 + (over / 0.01) ** 2
            # Clear of its own earlier legs and of the other lines.
            n_old = 0
            s_acc = 0.0
            for k in range(len(pts) - 1, 0, -1):
                s_acc += math.dist(pts[k], pts[k - 1])
                if s_acc > own_gap:
                    n_old = k
                    break
            near = np.array(pts[:n_old]) if n_old > 0 else np.zeros((0, 2))
            if len(other_pts):
                near = np.vstack([near, other_pts]) if len(near) else other_pts
            if len(near):
                d = np.min(np.hypot(qx[:, None] - near[None, :, 0], qy[:, None] - near[None, :, 1]), axis=1)
                cost = cost + 40.0 * np.clip(1.0 - d / sep, 0.0, 1.0) ** 2 + np.where(d < sep * 0.6, 500.0, 0.0)
            if avoid is not None:
                cost = cost + np.where(shapely.contains_xy(avoid, qx, qy), 1000.0, 0.0)
            k = int(np.argmin(cost))
            q = (float(qx[k]), float(qy[k]))
            if spine is not None and not reach and side * self._offset(spine, q, th[k]) > half:
                # A hairpin, turning uphill.
                arc = self._hairpin(p, h, hairpin_r)
                pts += arc
                length += math.pi * hairpin_r
                h = h + math.pi
                side = -side
                z = float(self.ground([pts[-1][0]], [pts[-1][1]])[0])
                continue
            pts.append(q)
            length += step
            h = float(th[k])
            z = float(self.ground([q[0]], [q[1]])[0])
            if top is not None and z >= top:
                break
            if stop is not None and stop(q):
                break
        return pts

    @staticmethod
    def _offset(spine, p, h):
        """Signed distance of p from the spine line (+ to the spine's left)."""
        s = spine.project(Point(p))
        a = spine.interpolate(max(0.0, min(s, spine.length - 1.0))).coords[0]
        b = spine.interpolate(max(0.0, min(s, spine.length - 1.0)) + 1.0).coords[0]
        cross = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
        return math.copysign(spine.distance(Point(p)), cross)

    def _hairpin(self, p, h, r):
        """A half circle of radius r from p, heading h, turning to the higher side."""
        lx, ly = -math.sin(h), math.cos(h)  # left normal (y down: this is the right hand on the map)
        hl = float(self.ground([p[0] + lx * 2 * r], [p[1] + ly * 2 * r])[0])
        hr = float(self.ground([p[0] - lx * 2 * r], [p[1] - ly * 2 * r])[0])
        sgn = 1.0 if hl >= hr else -1.0
        cx, cy = p[0] + sgn * lx * r, p[1] + sgn * ly * r
        a0 = math.atan2(p[1] - cy, p[0] - cx)
        n = max(6, int(math.pi * r / 5.0))
        # Sweep the way that starts along the current heading.
        sweep = math.pi if (math.cos(h) * -math.sin(a0) + math.sin(h) * math.cos(a0)) > 0 else -math.pi
        return [(cx + r * math.cos(a0 + sweep * k / n), cy + r * math.sin(a0 + sweep * k / n)) for k in range(1, n + 1)]

    # --- Road profiles -------------------------------------------------------------

    def profile_at(self, p):
        """The height of the nearest graded road at p, or None off them."""
        best = None
        for line, s, z, hw, _bank in self.profiles:
            d = line.distance(Point(p))
            if d < hw + 3.0 and (best is None or d < best[0]):
                best = (d, float(np.interp(line.project(Point(p)), s, z)))
        return None if best is None else best[1]

    def profile_near(self, p, reach):
        """The height of the nearest graded road within `reach` of p (the
        road a lot fronts), or None."""
        best = None
        for line, s, z, _hw, _bank in self.profiles:
            d = line.distance(Point(p))
            if d < reach and (best is None or d < best[0]):
                best = (d, float(np.interp(line.project(Point(p)), s, z)))
        return None if best is None else best[1]

    def grade(self, line, cls, ends=None):
        """Grades a road: its height follows the ground, smoothed, no steeper
        than its class allows; ends on the flat or on an earlier road keep
        that height. Returns the max grade it reached."""
        if self.poly.distance(line) > 1.0:
            return 0.0
        n = max(2, math.ceil(line.length / 4.0))
        s = np.linspace(0.0, line.length, n + 1)
        pts = [line.interpolate(v).coords[0] for v in s]
        z = self.raw(np.array([p[0] for p in pts]), np.array([p[1] for p in pts]))
        k = 15
        if len(z) > k:
            z = np.convolve(np.pad(z, k // 2, mode="edge"), np.ones(k) / k, mode="valid")
        pins = {}
        for i in (0, len(pts) - 1):
            h = self.profile_at(pts[i])
            pins[i] = h if h is not None else self.raw_at(pts[i])
        if ends:
            for i, h in ends.items():
                pins[i if i >= 0 else len(pts) + i] = h
        # Where it crosses an earlier road, both share that height.
        for other, os, oz, _hw, _bank in self.profiles:
            for q in _points(line.intersection(other)):
                i = int(round(line.project(Point(q)) / (line.length / n)))
                pins[i] = float(np.interp(other.project(Point(q)), os, oz))
        g = GRADE[cls]
        ds = line.length / n
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
        # How far the cut or fill fades out: wide enough to keep its bank gentle.
        bank = np.maximum(BLEND, np.abs(self.raw(np.array([p[0] for p in pts]), np.array([p[1] for p in pts])) - z) / MAX_BANK)
        self.profiles.append([line, s, z, _HALF[cls], bank])
        return float(np.max(np.abs(np.diff(z))) / ds)

    # --- The height grid ------------------------------------------------------------

    def grid(self, pads):
        """The final heights: the ground, cut and filled to the roads and to
        each lot's pad ([polygon, height]). Returns the export dict."""
        x0, y0, x1, y1 = self.poly.bounds
        x0, y0 = math.floor(x0 / CELL) * CELL - CELL, math.floor(y0 / CELL) * CELL - CELL
        nx = int(math.ceil((x1 - x0) / CELL)) + 2
        ny = int(math.ceil((y1 - y0) / CELL)) + 2
        gx, gy = np.meshgrid(x0 + np.arange(nx) * CELL, y0 + np.arange(ny) * CELL)
        xs, ys = gx.ravel(), gy.ravel()
        h = self.raw(xs, ys)
        wsum = np.zeros_like(h)
        zsum = np.zeros_like(h)
        margin = np.zeros_like(h)
        reach = np.zeros_like(h)
        for line, s, z, hw, bank in self.profiles:
            coords = np.array(line.coords)
            seg_s = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(coords, axis=0).T))])
            dmin = np.full_like(h, np.inf)
            smin = np.zeros_like(h)
            for k in range(len(coords) - 1):
                (ax, ay), (bx, by) = coords[k], coords[k + 1]
                dx, dy = bx - ax, by - ay
                l2 = dx * dx + dy * dy
                if l2 < 1e-9:
                    continue
                t = np.clip(((xs - ax) * dx + (ys - ay) * dy) / l2, 0.0, 1.0)
                d = np.hypot(xs - (ax + dx * t), ys - (ay + dy * t))
                closer = d < dmin
                dmin = np.where(closer, d, dmin)
                smin = np.where(closer, seg_s[k] + t * math.sqrt(l2), smin)
            zr = np.interp(smin, s, z)
            blend = np.interp(smin, s, bank)
            edge = hw + 2.0
            w = 1.0 - _smooth(np.clip(dmin / (edge + blend), 0.0, 1.0))
            wsum += w * w
            zsum += w * w * zr
            margin = np.maximum(margin, 1.0 - _smooth(np.clip((dmin - hw - 1.0) / CELL, 0.0, 1.0)))
            reach = np.maximum(reach, 1.0 - _smooth(np.clip((dmin - edge) / blend, 0.0, 1.0)))
        zroad = np.where(wsum > 1e-9, zsum / np.maximum(wsum, 1e-9), h)
        h = h * (1.0 - reach) + zroad * reach
        pts = shapely.points(xs, ys)
        if pads:
            # Each node takes the height of the nearest pad, flat a cell past
            # the lot's edge (so the bilinear ground under the whole lot is
            # at its height) and fading out beyond; a road keeps its own
            # grading a cell past its edge.
            dbest = np.full_like(h, np.inf)
            hbest = np.zeros_like(h)
            for poly, ph in pads:
                d = shapely.distance(pts, poly)
                closer = d < dbest
                dbest = np.where(closer, d, dbest)
                hbest = np.where(closer, ph, hbest)
            w = (1.0 - _smooth(np.clip((dbest - CELL - 2.0) / PAD_BLEND, 0.0, 1.0))) * (1.0 - margin)
            w = np.where(dbest <= 0.0, 1.0, w)  # under the lot itself, the pad
            h = h * (1.0 - w) + hbest * w
        h = np.clip(h, 0.0, MAX_H)
        self.heights = h.reshape(ny, nx)
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


def _smax(a, b, k):
    """A max of a and b with the corner rounded over k (no wider than the
    lower of the two, so bare ground stays at 0)."""
    k = np.minimum(k, np.maximum(np.minimum(a, b), 1e-6))
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.maximum(a, b) + h * h * k * 0.25


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
