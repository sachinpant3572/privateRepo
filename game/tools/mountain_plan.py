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

    def plan(self, start, goal, gmax, hairpin_r=0.0, hairpin_cost=150.0, allow=6.0, turn_pen=0.25, slope_pen=1.2,
             tunnel=None, bridge=None, start_heading=None, goal_r=12.0, weight=1.15, max_states=6_000_000,
             low=0.0):
        """Cells from start to goal: [(cell, kind)] where kind is 'n' (a
        step), 'h' (a hairpin onto this cell), 't' (a tunnel to it) or 'b' (a
        bridge to it). tunnel / bridge: (min, max, step) in cells, or None.
        low: extra cost per metre of height (keeps valley roads low)."""
        nx, ny, cell = self.nx, self.ny, self.cell
        H = self.H.ravel()
        block = self.block.ravel()
        pen = getattr(self, "pen", np.zeros_like(self.H)).ravel()
        slope = self.slope.ravel()
        s0 = self.cell_of(start)
        g0 = self.cell_of(goal)
        gx, gy = self.xy(g0)
        gh = H[g0]
        block = block.copy()
        block[s0] = False
        block[g0] = False
        cost_cell = cell * (1.0 + slope_pen * np.maximum(slope - 0.25, 0.0)) + pen * cell

        def heur(c):
            x, y = self.xy(c)
            d = math.hypot(x - gx, y - gy)
            return weight * max(d, abs(H[c] - gh) / gmax)

        best = {}
        parent = {}
        heap = []
        heads = range(16) if start_heading is None else [start_heading]
        for k in heads:
            st = s0 * 16 + k
            best[st] = 0.0
            parent[st] = (-1, "n")
            heapq.heappush(heap, (heur(s0), 0.0, st))
        # Hairpin offsets: 2r across, to either side, per heading.
        pins = []
        if hairpin_r > 0:
            for k in range(16):
                ux, uy = DUNIT[k]
                row = []
                for side in (1, -1):
                    px, py = -uy * side, ux * side
                    di = int(round(2 * hairpin_r * px / cell))
                    dj = int(round(2 * hairpin_r * py / cell))
                    row.append((di, dj))
                pins.append(row)
        arc = math.pi * hairpin_r
        done = None
        n = 0
        while heap:
            f, g, st = heapq.heappop(heap)
            if g > best.get(st, math.inf):
                continue
            c, k = divmod(st, 16)
            if c == g0 or (goal_r > 0 and math.dist(self.xy(c), (gx, gy)) <= goal_r):
                done = st
                break
            n += 1
            if n > max_states:
                break
            j, i = divmod(c, nx)
            h = H[c]

            def push(t, k2, cost, kind):
                ns = t * 16 + k2
                ng = g + cost
                if ng < best.get(ns, math.inf):
                    best[ns] = ng
                    parent[ns] = (st, kind)
                    heapq.heappush(heap, (ng + heur(t), ng, ns))

            for dk in (-1, 0, 1):
                k2 = (k + dk) % 16
                di, dj = DIRS[k2]
                i2, j2 = i + di, j + dj
                if not (0 <= i2 < nx and 0 <= j2 < ny):
                    continue
                t = j2 * nx + i2
                if block[t]:
                    continue
                L = DLEN[k2] * cell
                if abs(H[t] - h) > gmax * L:
                    continue
                push(t, k2, DLEN[k2] * cost_cell[t] * (1.0 + turn_pen * abs(dk)) + low * max(H[t] - h, 0.0), "n")
            if pins:
                for (di, dj) in pins[k]:
                    i2, j2 = i + di, j + dj
                    if not (0 <= i2 < nx and 0 <= j2 < ny):
                        continue
                    t = j2 * nx + i2
                    if block[t]:
                        continue
                    dz = abs(H[t] - h)
                    if dz > gmax * arc + allow:
                        continue
                    push(t, (k + 8) % 16, arc + hairpin_cost + 8.0 * max(dz - gmax * arc, 0.0), "h")
            for spec, kind in ((tunnel, "t"), (bridge, "b")):
                if not spec:
                    continue
                lo, hi, step, mult, fixed = spec
                di, dj = DIRS[k]
                for nn in range(lo, hi + 1, step):
                    i2, j2 = i + di * nn, j + dj * nn
                    if not (0 <= i2 < nx and 0 <= j2 < ny):
                        break
                    t = j2 * nx + i2
                    if block[t]:
                        continue
                    L = DLEN[k] * cell * nn
                    if abs(H[t] - h) > gmax * L:
                        continue
                    # The ground between, against the straight line.
                    ok = True
                    for q in range(1, nn):
                        z = h + (H[t] - h) * q / nn
                        gq = H[(j + dj * q) * nx + i + di * q]
                        if kind == "t" and gq - z < (8.0 if q in (1, nn - 1) else 15.0):
                            ok = False
                            break
                        if kind == "b" and z - gq < (2.0 if q in (1, nn - 1) else 6.0):
                            ok = False
                            break
                    if ok:
                        push(t, k, L * mult + fixed, kind)
        if done is None:
            raise RuntimeError("no path after %d states" % n)
        out = []
        st = done
        while st >= 0:
            p, kind = parent[st]
            out.append((st // 16, kind, st % 16))
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
        for c, kind, k in cells:
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
