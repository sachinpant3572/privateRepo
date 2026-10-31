#!/usr/bin/env python3
"""Lays Mount Calder's roads, trails, tunnels, the rail pass and the cable car
on the ground of tools/mountain.py, offline, and writes them to
tools/mountain_lines.json, which build_country.py reads (so the builder stays
fast and the lines stay put between builds).

A road is laid as a road builder would: an A* search over (cell, heading)
whose steps keep to the road's design grade on the smoothed ground, with
hairpin bends (a half turn onto the next leg up, a little cut and fill
allowed) and, where a spec allows them, tunnels (straight, level-through
under 15 m of ground or more) and bridges (straight, over a valley or the
river). The cells it finds are smoothed into a polyline, the hairpins drawn
as arcs. See HANDOFF-world-mountain.md (W-3).

Usage: python3 game/tools/mountain_plan.py [name ...]   (default: all)
       python3 game/tools/mountain_plan.py --separate name ...   (re-run separate() on stored lines)
"""

import heapq
import json
import math
import sys
from pathlib import Path

import numpy as np
import shapely
from scipy import ndimage
from shapely.geometry import LineString, Point

import mountain as M

OUT = Path(__file__).resolve().parent / "mountain_lines.json"

# 16 headings as whole-cell steps (0 = +x, turning toward +y).
DIRS = [(1, 0), (2, 1), (1, 1), (1, 2), (0, 1), (-1, 2), (-1, 1), (-2, 1), (-1, 0), (-2, -1), (-1, -1), (-1, -2),
        (0, -1), (1, -2), (1, -1), (2, -1)]
DLEN = [math.hypot(*d) for d in DIRS]
DUNIT = [(d[0] / l, d[1] / l) for d, l in zip(DIRS, DLEN)]


class Planner:
    def __init__(self, mtn, bbox, cell=10.0, smooth=1.5):
        self.m = mtn
        self.cell = cell
        x0, y0, x1, y1 = bbox
        self.x0, self.y0 = x0, y0
        self.nx = int((x1 - x0) / cell) + 1
        self.ny = int((y1 - y0) / cell) + 1
        gx, gy = np.meshgrid(x0 + np.arange(self.nx) * cell, y0 + np.arange(self.ny) * cell)
        raw = mtn.raw(gx.ravel(), gy.ravel()).reshape(self.ny, self.nx)
        self.raw = raw
        self.H = ndimage.gaussian_filter(raw, smooth)
        pts = shapely.points(gx.ravel(), gy.ravel())
        self.wet = shapely.distance(mtn.water_geom, pts).reshape(self.ny, self.nx) < 12.0
        # Steep ground costs more (more cut and fill, longer banks).
        gyy, gxx = np.gradient(self.H, cell)
        self.slope = np.hypot(gxx, gyy)
        self.block = self.wet.copy()

    def box(self):
        from shapely.geometry import box
        return box(self.x0 - self.cell, self.y0 - self.cell, self.x0 + self.nx * self.cell, self.y0 + self.ny * self.cell)

    def xy(self, c):
        j, i = divmod(c, self.nx)
        return (self.x0 + i * self.cell, self.y0 + j * self.cell)

    def cell_of(self, p):
        i = int(round((p[0] - self.x0) / self.cell))
        j = int(round((p[1] - self.y0) / self.cell))
        return j * self.nx + i

    def mark(self, geom, extra=None, reach=0.0):
        """Blocks (extra None) or adds `extra` cost per metre to cells within
        reach of geom."""
        gx, gy = np.meshgrid(self.x0 + np.arange(self.nx) * self.cell, self.y0 + np.arange(self.ny) * self.cell)
        d = shapely.distance(geom, shapely.points(gx.ravel(), gy.ravel())).reshape(self.ny, self.nx)
        if extra is None:
            self.block |= d <= reach
        else:
            self.pen = getattr(self, "pen", np.zeros_like(self.H))
            self.pen += np.where(d <= reach, extra, 0.0)

    def plan(self, start, goal, gmax, hairpin_r=0.0, hairpin_cost=400.0, cut=4.0, pin_cut=8.0, cut_pen=2.0,
             turn_pen=0.25, slope_pen=1.2, tunnel=None, bridge=None, start_heading=None, goal_r=12.0, weight=1.15,
             max_states=8_000_000, low=0.0, dry_bridges=False, wet_bridges=True, low_bridges=False):
        """Cells from start to goal: [(cell, kind, heading, road height)]
        where kind is 'n' (a step), 'h' (a hairpin onto this cell), 't' (a
        tunnel to it) or 'b' (a bridge to it).

        The road carries its own height: each step it climbs or drops toward
        the ground by at most gmax, and may stand up to `cut` metres above or
        below the ground (fill and cut; `pin_cut` coming out of a hairpin,
        after which it must close back in). tunnel / bridge: (min, max, step,
        cost per metre, fixed cost) in cells, or None. low: extra cost per
        metre climbed (keeps valley roads low). low_bridges: a bridge runs
        at the water's level (LOW_DECK at most at either end), as the game
        lays a road's deck over the water (the road comes down to it)."""
        nx, ny, cell = self.nx, self.ny, self.cell
        H = self.H.ravel()
        block = self.block.ravel().copy()
        wet = self.wet.ravel()
        pen = getattr(self, "pen", np.zeros_like(self.H)).ravel()
        slope = self.slope.ravel()
        s0 = self.cell_of(start)
        g0 = self.cell_of(goal)
        gx, gy = self.xy(g0)
        gh = H[g0]
        block[s0] = False
        block[g0] = False
        cost_cell = cell * (1.0 + slope_pen * np.maximum(slope - 0.25, 0.0)) + pen * cell
        Q = 0.5
        top = max(cut, pin_cut)
        nb = int(round(2 * top / Q)) + 1

        def key(c, k, off):
            return (c * 16 + k) * nb + int(round((off + top) / Q))

        def heur(c, z):
            x, y = self.xy(c)
            return weight * max(math.hypot(x - gx, y - gy), abs(z - gh) / gmax)

        best = {}
        info = {}  # key -> (parent key, kind, cell, heading, z)
        heap = []
        heads = range(16) if start_heading is None else [start_heading]
        for k in heads:
            st = key(s0, k, 0.0)
            best[st] = 0.0
            info[st] = (-1, "n", s0, k, H[s0])
            heapq.heappush(heap, (heur(s0, H[s0]), 0.0, st))
        pins = []
        if hairpin_r > 0:
            for k in range(16):
                ux, uy = DUNIT[k]
                pins.append([(int(round(2 * hairpin_r * -uy * sd / cell)), int(round(2 * hairpin_r * ux * sd / cell)))
                             for sd in (1, -1)])
        arc = math.pi * hairpin_r
        done = None
        n = 0
        while heap:
            f, g, st = heapq.heappop(heap)
            if g > best.get(st, math.inf):
                continue
            _p, _kind, c, k, z = info[st]
            if c == g0 or (goal_r > 0 and math.dist(self.xy(c), (gx, gy)) <= goal_r):
                done = st
                break
            n += 1
            if n > max_states:
                break
            j, i = divmod(c, nx)
            off0 = abs(z - H[c])

            def push(t, k2, z2, cost, kind, lim):
                off = z2 - H[t]
                if abs(off) > lim:
                    return
                ns = key(t, k2, off)
                ng = g + cost + low * max(z2 - z, 0.0)
                if ng < best.get(ns, math.inf):
                    best[ns] = ng
                    info[ns] = (st, kind, t, k2, z2)
                    heapq.heappush(heap, (ng + heur(t, z2), ng, ns))

            lim = max(cut, off0 - 0.05)
            for dk in (-1, 0, 1):
                k2 = (k + dk) % 16
                di, dj = DIRS[k2]
                i2, j2 = i + di, j + dj
                if not (0 <= i2 < nx and 0 <= j2 < ny):
                    continue
                t = j2 * nx + i2
                if block[t]:
                    continue
                rise = gmax * DLEN[k2] * cell
                z2 = min(max(H[t], z - rise), z + rise)
                push(t, k2, z2, DLEN[k2] * (cost_cell[t] * (1.0 + turn_pen * abs(dk)) + cut_pen * abs(z2 - H[t])),
                     "n", lim)
            if pins:
                for (di, dj) in pins[k]:
                    i2, j2 = i + di, j + dj
                    if not (0 <= i2 < nx and 0 <= j2 < ny):
                        continue
                    t = j2 * nx + i2
                    if block[t]:
                        continue
                    rise = gmax * arc
                    z2 = min(max(H[t], z - rise), z + rise)
                    push(t, (k + 8) % 16, z2, arc + hairpin_cost + cut_pen * 4.0 * abs(z2 - H[t]) * arc / cell, "h",
                         pin_cut)
            for spec, kind in ((tunnel, "t"), (bridge, "b")):
                if not spec:
                    continue
                lo, hi, step, mult, fixed = spec
                di, dj = DIRS[k]
                # Only where the way ahead is blocked: ground rising into a
                # hillside (tunnel), or water or a drop (bridge).
                ia, ja = i + 2 * di, j + 2 * dj
                if not (0 <= ia < nx and 0 <= ja < ny):
                    continue
                a = ja * nx + ia
                if kind == "t" and H[a] - z < 10.0:
                    continue
                if kind == "b" and not wet[a] and (not dry_bridges or z - H[a] < 4.0):
                    continue
                if kind == "b" and low_bridges and z > LOW_DECK:
                    continue
                for nn in range(lo, hi + 1, step):
                    i2, j2 = i + di * nn, j + dj * nn
                    if not (0 <= i2 < nx and 0 <= j2 < ny):
                        break
                    t = j2 * nx + i2
                    if block[t]:
                        continue
                    L = DLEN[k] * cell * nn
                    z2 = min(max(H[t], z - gmax * L), z + gmax * L)
                    if kind == "b" and low_bridges and z2 > LOW_DECK:
                        continue
                    ok = True
                    for q in range(1, nn):
                        zq = z + (z2 - z) * q / nn
                        gq = H[(j + dj * q) * nx + i + di * q]
                        if kind == "t" and gq - zq < (8.0 if q in (1, nn - 1) else 15.0):
                            ok = False
                            break
                        if kind == "b" and zq - gq < ((-1.0 if low_bridges else 2.0) if q in (1, nn - 1) else
                                                      (-1.0 if low_bridges else 6.0)):
                            ok = False
                            break
                        if kind == "b" and not wet_bridges and wet[(j + dj * q) * nx + i + di * q]:
                            ok = False
                            break
                    if ok:
                        push(t, k, z2, L * mult + fixed, kind, cut)
        if done is None:
            raise RuntimeError("no path after %d states" % n)
        out = []
        st = done
        while st >= 0:
            p, kind, c, k, z = info[st]
            out.append((c, kind, k, float(z)))
            st = p
        out.reverse()
        return out, n

    def polyline(self, cells, hairpin_r=0.0, chaikin=3):
        """Smooth points and the spans [(s0, s1, kind)] of tunnels and bridges."""
        pts = []
        spans = []
        run = []

        def flush():
            if len(run) >= 2:
                q = [np.array(p, dtype=float) for p in run]
                for _ in range(chaikin):
                    nq = [q[0]]
                    for a, b in zip(q, q[1:]):
                        nq += [0.75 * a + 0.25 * b, 0.25 * a + 0.75 * b]
                    nq.append(q[-1])
                    q = nq
                seg = [tuple(p) for p in q]
            else:
                seg = list(run)
            if pts and seg and math.dist(pts[-1], seg[0]) < 1e-6:
                seg = seg[1:]
            pts.extend(seg)

        prev_k = None
        for c, kind, k, *_ in cells:
            p = self.xy(c)
            if kind == "n" or not run:
                run.append(p)
            else:
                flush()
                a = np.array(run[-1])
                b = np.array(p)
                if kind == "h":
                    f = np.array(DUNIT[prev_k])
                    ctr = (a + b) * 0.5
                    r = np.linalg.norm(b - a) * 0.5
                    u = (b - a) / max(2 * r, 1e-9)
                    for q in range(1, 13):
                        th = math.pi * q / 12
                        pts.append(tuple(ctr - r * u * math.cos(th) + r * f * math.sin(th)))
                else:
                    s0 = LineString(pts).length if len(pts) > 1 else 0.0
                    pts.append(tuple(b))
                    spans.append([s0, LineString(pts).length, kind])
                run = [tuple(b)]
            prev_k = k
        flush()
        clean = [pts[0]]
        for p in pts[1:]:
            if math.dist(p, clean[-1]) > 0.5:
                clean.append(p)
        return clean, spans


def check(mtn, pts, cls, spans=()):
    """Grades a line on a scratch copy of the profiles: (max grade, max cut or
    fill, length)."""
    keep = list(mtn.profiles)
    line = LineString(pts)
    g = mtn.grade(line, cls, spans=spans)
    _line, s, z, _hw, _bank, _sp = mtn.profiles[-1]
    raw = mtn.raw(*np.array([line.interpolate(v).coords[0] for v in s]).T)
    open_ = np.ones_like(s, dtype=bool)
    for a, b, _k in spans:
        open_ &= ~((s > a) & (s < b))
    cut = float(np.max(np.abs(raw - z)[open_])) if open_.any() else 0.0
    mtn.profiles[:] = keep
    return g, cut, line.length


def separate(pts, cls, hairpin_r, apart=(), gap=10.0, keep=40.0, joint=12.0, iters=120, max_move=12.0, log=print):
    """Pushes a line's own converging legs apart, returning the moved points.

    The A* has no memory of its own path, so after a hairpin a leg can drift
    back to within 9-14 m of the leg below (W-20). Two road cores that close,
    at different heights, leave the 8 m height grid no node between them to
    grade the bank on, so each leg's edge takes the other's height and the
    road's grade spikes. Every near-parallel pair of points (|cos| > 0.6)
    more than a hairpin's bend apart along the line and closer than the
    width plus `gap` (at most the hairpin's own 2r) is pushed apart, the push
    smoothed along the line so the bends stay round. The ends (`keep` m) stay
    put and no point moves more than `max_move` m. Runs beside other ways are
    left alone (the grading pins a shared stretch to one height, W-19) except
    the ways in `apart` ([(points, class)]), which this line alone is pushed
    off, to the two half widths plus `gap`, but for `joint` m round where it
    joins or crosses them (so a shallow crossing is opened out)."""
    from scipy.spatial import cKDTree
    P0 = np.asarray(pts, dtype=float)
    n = len(P0)
    s = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(P0, axis=0), axis=1))])
    w = np.clip((np.minimum(s, s[-1] - s) - keep) / 30.0, 0.0, 1.0)
    sep = 2.0 * M._HALF[cls] + gap
    if hairpin_r > 0:
        sep = min(sep, 2.0 * hairpin_r - 1.0)
    win = math.pi * hairpin_r + 2.0 * sep  # a hairpin's own two legs, round its bend
    me = LineString(P0)
    obst = []
    for opts, ocls in apart:
        q = np.array(shapely.segmentize(LineString(opts), 2.0).coords)
        touch = shapely.distance(shapely.points(q[:, 0], q[:, 1]), me) < 2.0
        if touch.any():
            tree = cKDTree(q[touch])
            w[tree.query(P0, distance_upper_bound=joint)[0] < joint] = 0.0
            q = q[tree.query(q, distance_upper_bound=joint)[0] >= joint]
        if len(q) > 2:
            qt = np.gradient(q, axis=0)
            qt /= np.maximum(np.linalg.norm(qt, axis=1), 1e-9)[:, None]
            obst.append((cKDTree(q), q, qt, M._HALF[cls] + M._HALF[ocls] + gap))
    D = np.zeros_like(P0)
    for it in range(iters):
        P = P0 + D
        t = np.gradient(P, axis=0)
        t /= np.maximum(np.linalg.norm(t, axis=1), 1e-9)[:, None]
        pairs = cKDTree(P).query_pairs(sep, output_type="ndarray")
        worst = 0.0
        if len(pairs):
            i, j = pairs[:, 0], pairs[:, 1]
            ok = (np.abs(s[i] - s[j]) > win) & (np.abs(np.sum(t[i] * t[j], axis=1)) > 0.6) & ((w[i] > 0) | (w[j] > 0))
            pairs = pairs[ok]
        F = np.zeros_like(P)
        cnt = np.zeros(n)
        if len(pairs):
            i, j = pairs[:, 0], pairs[:, 1]
            v = P[i] - P[j]
            d = np.maximum(np.linalg.norm(v, axis=1), 1e-6)
            worst = float(np.max(sep - d))
            push = (v / d[:, None]) * ((sep - d) * 0.5)[:, None]
            np.add.at(F, i, push)
            np.add.at(F, j, -push)
            np.add.at(cnt, i, 1.0)
            np.add.at(cnt, j, 1.0)
        for tree, q, qt, osep in obst:
            d, k = tree.query(P, distance_upper_bound=osep)
            hit = np.nonzero((k < len(q)) & (w > 0))[0]
            hit = hit[np.abs(np.sum(t[hit] * qt[k[hit]], axis=1)) > 0.6]
            if len(hit):
                dd = np.maximum(d[hit], 1e-6)
                worst = max(worst, float(np.max(osep - dd)))
                F[hit] += ((P[hit] - q[k[hit]]) / dd[:, None]) * (0.5 * (osep - dd))[:, None]
                cnt[hit] += 1.0
        if worst < 0.2:
            break
        F /= np.maximum(cnt, 1.0)[:, None]
        F = ndimage.gaussian_filter1d(F, 6.0, axis=0, mode="nearest") * 1.5
        D += F * w[:, None]
        mag = np.linalg.norm(D, axis=1)
        D *= np.minimum(1.0, max_move / np.maximum(mag, 1e-9))[:, None]
    log("  separate: %d rounds, moved up to %.1f m, still %.1f m short (of %.1f m)" % (
        it + 1, float(np.max(np.linalg.norm(D, axis=1))), worst, sep))
    return [tuple(p) for p in P0 + D]


# --- The lines -------------------------------------------------------------------
# Each: id, class, name, tag, way (points (x, y), or ("on", id, (x, y)) for
# the point of an earlier line nearest (x, y)), head / tail (fixed points
# before and after the planned legs, e.g. out of the city), keep_head (a map
# route's own points kept before it), gmax and the plan's other settings.
# Planned in this order; HANDOFF-world-mountain.md (W-3) says why each goes
# where it does.
TUN = (6, 110, 2, 3.0, 300.0)  # tunnels up to 1.1 km
BRIDGE = (3, 40, 1, 2.0, 80.0)  # bridges up to 400 m
LOW_DECK = 4.0  # a low bridge's ends stand no higher than this (the water is at 0)
SPECS = [
    # Route 9 River Road: along the Morrow's east bank under the range's
    # west wall, round its north foot to Route 7 (2100, -4050).
    # Kept just clear of the rail pass where it can (the rail's rigid shelf
    # owns the ground within ~15 m of it and the road would drape over its
    # edge), but no further: 30 m off put it 15-20 m up the gorge wall, above
    # where Wheaton and Dam roads come over the rail to it (no room on the
    # wall to climb). 26 m: the height grid blends the shelf into the ground
    # about one more cell out. The rail is planned without the roads, so the route
    # reads it from the last plan.
    dict(id="route_9", cls="highway", name="Route 9 River Road", tag="route", keep_head=[(200, -100)],
         way=[(100, -1150), (-480, -1950), (-704, -3250), (-400, -3850), (300, -4250), (900, -4300),
              (2100, -4050)], gmax=0.055, low=4.0, bridge=BRIDGE, avoid=(("rail_pass", 26.0, 30.0),)),
    # Wheaton and Dam roads now end on Route 9, over the river. They (and
    # Pinecrest) cross the rail square, not along it: a road that runs within
    # its shelf's ~15 m (plus a grid cell of blending) drapes over the shelf's edge. Wheaton's
    # bridge is in the play area, so it is a low one (the game lays a deck
    # at the water's level); Dam Road's and Pinecrest's cross outside it
    # (drawn, not driven).
    dict(id="wheaton_road", cls="road", name="Wheaton Road", tag="route", keep_head=[(-2250, -550), (-1550, -1750)],
         way=[(-950, -2350), ("on", "route_9", (-700, -2350))], gmax=0.08, bridge=BRIDGE, low_bridges=True,
         avoid=(("rail_pass", 26.0, 30.0),),
         hairpin_r=12.0),
    dict(id="dam_road", cls="road", name="Dam Road", tag="route",
         keep_head=[(-2750, -3350), (-2250, -3230), (-1850, -3270), (-1450, -3230), (-1150, -3400)],
         way=[(-950, -3650), ("on", "route_9", (-650, -3550))], gmax=0.08, bridge=BRIDGE,
         avoid=(("rail_pass", 26.0, 30.0),)),
    # Firebreak Road: off Route 9 to the Greenhold commune, the campground
    # and the fire lookout.
    dict(id="firebreak_road", cls="track", name="Firebreak Road", tag="route",
         way=[("on", "route_9", (-650, -3700)), (-250, -3650), (-220, -3950), (150, -4030)], gmax=0.16, hairpin_r=8.0,
         bridge=BRIDGE),
    # Pinecrest Logging Road: Dellwood's logging road over the Morrow to Fernmoor.
    dict(id="pinecrest_logging", cls="track", name="Pinecrest Logging Road", tag="route",
         way=[(250, -4900), (750, -4720), (1800, -4300)], gmax=0.16, hairpin_r=8.0, bridge=BRIDGE,
         avoid=(("rail_pass", 26.0, 30.0),)),
    # Old Post Road: round the range's east foot from Larkspur.
    dict(id="old_post_road", cls="lane", name="Old Post Road", tag="route",
         way=[(2350, -950), (2450, -1500), (2650, -1950), (2850, -2050)], gmax=0.10, hairpin_r=12.0),
    # The foothills (the old Bellerive Hills).
    dict(id="crest", cls="road", name="Crest Drive", tag="crest", tail=[(2330, -530)],
         way=[("on", "route_9", (132, -1250)), (650, -1250), (1110, -1388), (1760, -1132), (2150, -800)], gmax=0.10,
         hairpin_r=15.0),
    dict(id="freeway", cls="highway", name="Canyon Freeway", tag="freeway", head=[(690, -338)],
         way=[(696, -560), (2744, -1590)], gmax=0.055, tunnel=TUN, bridge=BRIDGE),
    dict(id="canyon", cls="road", name="Coyote Canyon Road", tag="canyon", head=[(452, -338), (470, -500)],
         way=[(540, -650), ("on", "crest", (650, -1250))], gmax=0.10, hairpin_r=15.0),
    dict(id="observatory", cls="road", name="Observatory Road", tag="observatory", head=[(1010, -338)],
         way=[(1015, -470), M.OBSERVATORY_ROAD_END], gmax=0.10, hairpin_r=15.0),
    dict(id="fire_road", cls="track", name="Summit Fire Road", tag="fire_road",
         way=[("on", "crest", (1110, -1388)), (1086, -1250)], gmax=0.18, hairpin_r=8.0),
    # Mount Calder Road: the main way up, off Observatory Road, to the
    # summit car park.
    dict(id="calder", separate=True, cls="road", name="Mount Calder Road", tag="calder",
         way=[("on", "observatory", (1015, -470)), M.SUMMIT_SITES["car_park"][:2]], gmax=0.10, hairpin_r=17.0,
         bbox=(300, -3000, 2000, -300)),  # the south face only: a wider box runs out of states
    # The 4x4 shortcuts: up the West Ridge from the fire lookout to the main
    # road's upper loops, and up the east foot from Old Post Road to its lower
    # loops (run on to the upper loops it crossed Calder 8 times and shadowed
    # Summit Fire Road 8 m off; W-20).
    dict(id="west_ridge_track", separate=True, apart=("calder",), cls="track", name="West Ridge Track", tag="track",
         way=[("on", "firebreak_road", (150, -4030)), (400, -3180), ("on", "calder", (731, -2539))], gmax=0.20,
         hairpin_r=8.0, hairpin_cost=150.0),
    dict(id="larkspur_track", separate=True, cls="track", name="Larkspur Track", tag="track",
         way=[("on", "old_post_road", (2450, -1500)), ("on", "calder", (1340, -1343))], gmax=0.20, hairpin_r=8.0,
         hairpin_cost=150.0),
    # Forest trails: from the observatory up the south face to the summit
    # deck, and from Route 9 up past Hawk and Raven peaks.
    dict(id="calder_trail", cls="trail", name="Calder Trail", tag="trail",
         # Out past the observatory's back corner before it turns up the
         # face, so it does not cut across the lot.
         way=[(M.OBSERVATORY[0] + 40.0, M.OBSERVATORY[1] - 10.0),
              (M.OBSERVATORY[0] + 46.0, M.OBSERVATORY[1] - M.OBSERVATORY_SIZE[1] * 0.5 - 14.0),
              (1080, -1600), M.SUMMIT_SITES["deck"][:2]],
         gmax=0.24, hairpin_r=5.0, hairpin_cost=60.0, cut=2.0, pin_cut=4.0),
    dict(id="raven_trail", cls="trail", name="Raven Trail", tag="trail",
         way=[("on", "route_9", (-700, -2700)), (60, -2470), (400, -3180), M.SUMMIT_SITES["deck"][:2]], gmax=0.24,
         hairpin_r=5.0, hairpin_cost=60.0, cut=2.0, pin_cut=4.0),
    # The East Hills (HANDOFF-hill-country.md): East Hills Road from Old Post
    # Road north up the hills' east side to Route 9's end, a dirt track up
    # each knob, two 4x4 shortcuts (Whistler to Copperback along the crest,
    # Tallow up the north-east spur to East Peak) and a crest trail.
    dict(id="east_hills_road", cls="lane", name="East Hills Road", tag="hills",
         way=[("on", "old_post_road", (2750, -2010)), (2790, -2650), (2790, -3250), (2700, -3700),
              ("on", "route_9", (2100, -4050))], gmax=0.10, hairpin_r=12.0),
    dict(id="copperback_track", cls="track", name="Copperback Track", tag="hills",
         way=[("on", "east_hills_road", (2790, -2650)), (2600, -2720)], gmax=0.18, hairpin_r=8.0),
    dict(id="whistler_track", cls="track", name="Whistler Track", tag="hills",
         way=[("on", "east_hills_road", (2790, -3250)), (2560, -3330)], gmax=0.18, hairpin_r=8.0),
    dict(id="tallow_track", cls="track", name="Tallow Track", tag="hills",
         way=[("on", "east_hills_road", (2700, -3700)), (2420, -3990)], gmax=0.18, hairpin_r=8.0),
    dict(id="fernmoor_track", cls="track", name="Fernmoor Track", tag="hills",
         way=[("on", "route_9", (1950, -4100)), (2080, -4560), (1944, -4704)], gmax=0.18, hairpin_r=8.0),
    dict(id="copperback_cut", separate=True, apart=("east_hills_road",), cls="track", name="Copperback Cut",
         tag="track", way=[("on", "whistler_track", (2560, -3330)), (2640, -3000), ("on", "copperback_track", (2600, -2720))],
         gmax=0.20, hairpin_r=8.0, hairpin_cost=150.0),
    dict(id="spur_track", separate=True, cls="track", name="Spur Track", tag="track",
         way=[("on", "tallow_track", (2420, -3990)), (1950, -3750), (1760, -2880)], gmax=0.20, hairpin_r=8.0,
         hairpin_cost=150.0),
    dict(id="tallow_trail", cls="trail", name="Tallow Trail", tag="trail",
         way=[("on", "whistler_track", (2560, -3330)), (2640, -3640), ("on", "tallow_track", (2420, -3990))],
         gmax=0.24, hairpin_r=5.0, hairpin_cost=60.0, cut=2.0, pin_cut=4.0),
    # Up to Tallow's and Whistler's true tops (the clearance cap round the
    # highways and the rail pulled them off the knob points above), each
    # ending in its viewpoint's pull-out.
    dict(id="tallow_top", cls="track", name="Tallow Top Track", tag="hills",
         way=[("on", "tallow_track", (2508, -3831)), (2576, -3968)], gmax=0.18, hairpin_r=8.0),
    dict(id="whistler_top", cls="track", name="Whistler Top Track", tag="hills",
         way=[("on", "east_hills_road", (2640, -3760)), (2536, -3656)], gmax=0.18, hairpin_r=8.0),
    # Into the hills' back country: a track along the low north ridge from
    # Tallow round to Fernmoor, a trail from Route 9 up the west flank
    # (a dead end: joined to Spur Track it wound round through a hairpin and
    # broke its grade), a trail from Fernmoor west to the logging road, and a
    # dead-end track west into the south hills off East Hills Road.
    dict(id="fernmoor_ridge", cls="track", name="Fernmoor Ridge Track", tag="hills",
         way=[("on", "tallow_track", (2440, -3960)), (2700, -4100), (2600, -4300), (2264, -4360), (2136, -4420),
              ("on", "fernmoor_track", (2066, -4536))], gmax=0.18, hairpin_r=8.0, hairpin_cost=150.0),
    dict(id="hollin_trail", cls="trail", name="Hollin Trail", tag="trail",
         way=[("on", "route_9", (1394, -4273)), (1522, -4028), (1700, -3850)],
         gmax=0.24, hairpin_r=5.0, hairpin_cost=60.0, cut=2.0, pin_cut=4.0),
    dict(id="moor_trail", cls="trail", name="Moor Trail", tag="trail",
         way=[("on", "fernmoor_track", (2066, -4536)), (1800, -4720), ("on", "pinecrest_logging", (1558, -4446))],
         gmax=0.24, hairpin_r=5.0, hairpin_cost=60.0, cut=2.0, pin_cut=4.0),
    dict(id="brackett_track", cls="track", name="Brackett Track", tag="hills",
         way=[("on", "east_hills_road", (2770, -2234)), (2430, -2160), (2120, -2230)], gmax=0.18, hairpin_r=8.0),
]
# The rail pass (Morrow Freight Line round the range): a shelf on the
# Morrow gorge's inner wall round the range's west and north foot (the river
# loops round it; W-2), never steeper than 2.5 %, tunnelling through the
# spurs and on viaducts over the gullies; planned on 30 m cells so its
# curves stay wide, kept off the valley floor (shelf: extra cost below 25 m).
# One leg: a waypoint fixes the line's height there (each leg starts on the
# ground), which a 2.2 % line cannot keep to on the gorge wall.
SPECS.append(dict(id="rail_pass", cls="rail", name="Morrow Freight Line", tag="rail",
                  way=[(-50, -850), (1500, -4930)], bbox=(-1000, -5400, 1900, -500), gmax=0.022, cell=30.0,
                  tunnel=(3, 40, 1, 1.5, 60.0), bridge=(2, 14, 1, 1.5, 60.0), turn_pen=1.5, shelf=25.0, dry_bridges=True,
                  inside=250.0, wet_bridges=False))
PLAN_KEYS = ("gmax", "hairpin_r", "hairpin_cost", "cut", "pin_cut", "low", "tunnel", "bridge", "turn_pen", "dry_bridges",
             "wet_bridges", "low_bridges")


def _point(p, done):
    if isinstance(p, tuple) and len(p) == 3 and p[0] == "on":
        line = LineString(done[p[1]]["pts"])
        return line.interpolate(line.project(Point(p[2]))).coords[0]
    return (float(p[0]), float(p[1]))


def plan_line(mtn, spec, done, log=print):
    """Plans one SPECS line leg by leg: {cls, name, tag, keep_head, pts, spans}."""
    way = [_point(p, done) for p in spec["way"]]
    kw = {k: spec[k] for k in PLAN_KEYS if k in spec}
    r = spec.get("hairpin_r", 0.0)
    pts = [tuple(map(float, p)) for p in spec.get("head", [])]
    spans = []
    heading = None
    for a, b in zip(way, way[1:]):
        pad = 900.0 if r > 0 else 600.0
        bbox = spec.get("bbox") or (min(a[0], b[0]) - pad, min(a[1], b[1]) - pad, max(a[0], b[0]) + pad, max(a[1], b[1]) + pad)
        P = Planner(mtn, bbox, cell=spec.get("cell", 10.0))
        P.mark(mtn.flat, reach=0.0)
        if spec.get("inside"):
            # Kept to the range's side of the river (and to its ends' ground).
            keep = mtn.poly.union(shapely.union_all([Point(q).buffer(spec["inside"]) for q in (a, b)]))
            P.mark(P.box().difference(keep), reach=0.0)
        if spec.get("shelf"):
            P.pen = np.where(P.H < spec["shelf"], 1.0, 0.0)
        for other, reach, extra in spec.get("avoid", ()):
            # Extra cost near another line (one already planned).
            P.mark(LineString(done[other]["pts"]), extra=extra, reach=reach)
        for p in (a, b):
            if P.block.ravel()[P.cell_of(p)]:
                raise RuntimeError("waypoint %s is in the water or the city" % (tuple(round(v) for v in p),))
        cells, n = P.plan(a, b, start_heading=heading, **kw)
        heading = cells[-1][2]
        leg, lspans = P.polyline(cells, r)
        leg[0], leg[-1] = tuple(a), tuple(b)
        base = LineString(pts).length if len(pts) > 1 else 0.0
        if pts and math.dist(pts[-1], leg[0]) < 1e-6:
            leg = leg[1:]
        elif pts:
            base += math.dist(pts[-1], leg[0])
        pts.extend(leg)
        spans += [[s0 + base, s1 + base, k] for s0, s1, k in lspans]
        log("  leg %s -> %s: %d states, %d cells, %d hairpins, spans %s" % (
            tuple(round(v) for v in a), tuple(round(v) for v in b), n, len(cells), sum(c[1] == "h" for c in cells),
            "".join(c[1] for c in cells if c[1] in "tb")))
    pts += [tuple(map(float, p)) for p in spec.get("tail", [])]
    if spec.get("separate"):
        pts = _separate(spec, pts, spans, done, log)
    g, cut, length = check(mtn, pts, spec["cls"], spans)
    log("%s: grade %.3f, cut/fill %.1f m, %.0f m, spans %s" % (
        spec["id"], g, cut, length, [(round(a), round(b), k) for a, b, k in spans]), flush=True)
    return {"cls": spec["cls"], "name": spec["name"], "tag": spec["tag"],
            "keep_head": [list(p) for p in spec.get("keep_head", [])],
            "pts": [[round(x, 1), round(y, 1)] for x, y in pts], "spans": [[round(a, 1), round(b, 1), k] for a, b, k in spans]}


def _separate(spec, pts, spans, done, log=print):
    """separate() for a spec (no spans: their arc lengths would shift)."""
    if spans:
        raise RuntimeError("separate: a line with tunnels or bridges is not moved")
    apart = [(done[k]["pts"], done[k]["cls"]) for k in spec.get("apart", ())]
    return separate(pts, spec["cls"], spec.get("hairpin_r", 0.0), apart, log=log)


def _resnap(spec, pts, done):
    """Moves an end that joins an earlier line ("on" in `way`) back onto it,
    tapered over 40 m, after that line was moved by separate()."""
    P = np.asarray(pts, dtype=float)
    s = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))])
    for end, idx in ((spec["way"][0], 0), (spec["way"][-1], -1)):
        if not (isinstance(end, tuple) and len(end) == 3 and end[0] == "on"):
            continue
        line = LineString(done[end[1]]["pts"])
        q = np.array(line.interpolate(line.project(Point(P[idx]))).coords[0])
        off = q - P[idx]
        far = s if idx == 0 else s[-1] - s
        P += off[None, :] * np.clip(1.0 - far / 40.0, 0.0, 1.0)[:, None]
    return [tuple(p) for p in P]


def resep(names):
    """Re-runs separate() on stored lines (no new A* search), for specs with
    `separate`, then snaps the ends of lines that join them back on."""
    mtn = M.Mountain()
    done = json.loads(OUT.read_text())
    moved = set()
    for spec in SPECS:
        sid = spec["id"]
        if sid not in done:
            continue
        pts = [tuple(p) for p in done[sid]["pts"]]
        joins = {e[1] for e in (spec["way"][0], spec["way"][-1]) if isinstance(e, tuple) and len(e) == 3 and e[0] == "on"}
        if joins & moved:
            pts = _resnap(spec, pts, done)
        if sid in names and spec.get("separate"):
            print(sid, flush=True)
            pts = _separate(spec, pts, done[sid]["spans"], done)
            g, cut, length = check(mtn, pts, spec["cls"], done[sid]["spans"])
            print("%s: grade %.3f, cut/fill %.1f m, %.0f m" % (sid, g, cut, length), flush=True)
            moved.add(sid)
        elif not joins & moved:
            continue
        done[sid]["pts"] = [[round(x, 1), round(y, 1)] for x, y in pts]
    OUT.write_text(json.dumps(done, separators=(",", ":")) + "\n")


def main(names):
    mtn = M.Mountain()
    done = json.loads(OUT.read_text()) if OUT.exists() else {}
    failed = []
    for spec in SPECS:
        if names and spec["id"] not in names:
            continue
        try:
            done[spec["id"]] = plan_line(mtn, spec, done)
        except (RuntimeError, KeyError) as err:
            print("%s: FAILED %s" % (spec["id"], err), flush=True)
            failed.append(spec["id"])
            continue
        OUT.write_text(json.dumps(done, separators=(",", ":")) + "\n")
    if failed:
        print("FAILED:", failed)
        sys.exit(1)


if __name__ == "__main__":
    if sys.argv[1:2] == ["--separate"]:
        resep(sys.argv[2:])
    else:
        main(sys.argv[1:])
