"""Helpers: load street geometry, project, measure grid orientation, blocks, arterial spacing."""
import bz2, json, math, csv, glob, os
import xml.etree.ElementTree as ET
from collections import defaultdict
import numpy as np
from shapely.geometry import LineString, Polygon, MultiLineString
from shapely.ops import polygonize, unary_union

DL = '/tmp/claude-0/-home-user-privateRepo/179494e2-8a36-59e0-a621-53f1ca10d968/scratchpad/dl'
DRIVE = {'motorway','trunk','primary','secondary','tertiary','unclassified','residential',
         'living_street','motorway_link','trunk_link','primary_link','secondary_link','tertiary_link'}
WIDE = {'motorway','trunk','primary','secondary'}

class Proj:
    def __init__(self, lat0, lon0):
        self.lat0, self.lon0 = lat0, lon0
        self.kx = 111320.0 * math.cos(math.radians(lat0)); self.ky = 110540.0
    def __call__(self, lon, lat):
        return ((lon - self.lon0) * self.kx, (lat - self.lat0) * self.ky)

def load_osm_xml(path):
    op = bz2.open if path.endswith('.bz2') else open
    with op(path, 'rb') as f:
        root = ET.parse(f).getroot()
    nodes = {n.get('id'): (float(n.get('lon')), float(n.get('lat'))) for n in root.iter('node')}
    ways = []
    for w in root.iter('way'):
        tags = {t.get('k'): t.get('v') for t in w.findall('tag')}
        if 'highway' not in tags: continue
        pts = [nodes[nd.get('ref')] for nd in w.findall('nd') if nd.get('ref') in nodes]
        if len(pts) >= 2:
            ways.append({'id': w.get('id'), 'hw': tags['highway'], 'name': tags.get('name', ''), 'll': pts})
    return ways

def load_geojson_ways(path):
    d = json.load(open(path))
    feats = d['features'] if isinstance(d, dict) else d
    out = []
    for f in feats:
        g = f['geometry']; p = f.get('properties', {})
        if 'highway' not in p: continue
        if g['type'] == 'LineString':
            out.append({'hw': p['highway'], 'name': p.get('name', ''), 'll': g['coordinates']})
    return out

def load_gtfs_shapes(path, bbox=None):
    """bbox = (minlon,minlat,maxlon,maxlat). Returns list of lon/lat polylines."""
    shapes = defaultdict(list)
    with open(path, newline='', encoding='utf-8-sig') as f:
        r = csv.DictReader(f)
        for row in r:
            row = {k.strip(): v for k, v in row.items()}
            lat = float(row['shape_pt_lat']); lon = float(row['shape_pt_lon'])
            shapes[row['shape_id']].append((int(float(row['shape_pt_sequence'])), lon, lat))
    out = []
    for sid, pts in shapes.items():
        pts.sort(); ll = [(a, b) for _, a, b in pts]
        if bbox:
            ll = [p for p in ll if bbox[0] <= p[0] <= bbox[2] and bbox[1] <= p[1] <= bbox[3]]
        if len(ll) >= 2: out.append(ll)
    return out

def project_ways(ways, proj):
    for w in ways:
        w['xy'] = [proj(*p) for p in w['ll']]
    return ways

def seg_iter(xy):
    for (x1, y1), (x2, y2) in zip(xy[:-1], xy[1:]):
        L = math.hypot(x2 - x1, y2 - y1)
        if L > 0.5:
            b = math.degrees(math.atan2(x2 - x1, y2 - y1)) % 180.0  # compass bearing mod 180
            yield x1, y1, x2, y2, L, b

def bearing_hist(lines):
    """lines: list of xy polylines. returns length per 1-degree bin (0..179)."""
    h = np.zeros(180)
    for xy in lines:
        for *_, L, b in seg_iter(xy):
            h[int(b) % 180] += L
    return h

def grid_fit(h, tol=5):
    """Best grid angle theta in [0,90): maximise length within +-tol of theta or theta+90."""
    best = (0, -1)
    tot = h.sum()
    for t in range(90):
        s = 0.0
        for a in (t, t + 90):
            for d in range(-tol, tol + 1):
                s += h[(a + d) % 180]
        if s > best[1]: best = (t, s)
    return best[0], best[1] / tot if tot else 0

def two_grid_fit(h, tol=5):
    """Best pair of distinct grids (theta1, theta2) and their combined share."""
    tot = h.sum(); best = None
    def cover(t):
        m = np.zeros(180, bool)
        for a in (t, t + 90):
            for d in range(-tol, tol + 1): m[(a + d) % 180] = True
        return m
    t1, s1 = grid_fit(h, tol)
    m1 = cover(t1); bestt2, bests = None, 0
    for t in range(90):
        m = m1 | cover(t)
        s = h[m].sum() / tot
        if s > bests: bestt2, bests = t, s
    return t1, s1, bestt2, bests

def sample_dedupe(lines, step=25.0, cell=15.0):
    """Resample polylines every `step` m; drop duplicates (same 15 m cell + 10-deg bearing bin).
    Returns array of (x, y, bearing) samples, each standing for `step` metres of unique route."""
    seen = set(); out = []
    for xy in lines:
        carry = 0.0
        for x1, y1, x2, y2, L, b in seg_iter(xy):
            t = carry
            while t < L:
                x = x1 + (x2 - x1) * t / L; y = y1 + (y2 - y1) * t / L
                k = (int(round(x / cell)), int(round(y / cell)), int(b // 10) % 18)
                if k not in seen:
                    seen.add(k); out.append((x, y, b))
                t += step
            carry = t - L
    return np.array(out) if out else np.zeros((0, 3))

def hist_from_samples(s, step=25.0):
    h = np.zeros(180)
    for b in s[:, 2]: h[int(b) % 180] += step
    return h

def arterial_spacing(s, theta, win, res=20.0, tol=12, min_occ=0.30, merge=80.0, band=None):
    """s: deduped samples (x,y,b). theta: grid angle (deg from north). win: (cx,cy,half) square window.
    Rotates into grid frame. For each family (lines along theta / along theta+90) bins samples by their
    perpendicular position; occupancy of a position = share of the window length covered by samples within
    +-band metres of it (so a road a degree off-axis still counts). Positions whose occupancy >= min_occ are
    roads; runs of neighbouring hits are merged to their best column; returns offsets and gaps."""
    cx, cy, half = win
    band = band if band is not None else max(res, merge)
    th = math.radians(theta)
    ux, uy = math.sin(th), math.cos(th); vx, vy = math.sin(th + math.pi/2), math.cos(th + math.pi/2)
    n = int(2 * half / res)
    res_out = {}
    for fam, ang in (('A', theta), ('B', theta + 90)):
        occ = defaultdict(set)
        for x, y, b in s:
            d = abs(((b - ang) + 90) % 180 - 90)
            if d > tol: continue
            px, py = x - cx, y - cy
            a = px * ux + py * uy; c = px * vx + py * vy
            if abs(a) > half or abs(c) > half: continue
            pos, ext = (c, a) if fam == 'A' else (a, c)
            occ[int((pos + half) / res)].add(int((ext + half) / res))
        k_band = max(1, int(band / res))
        score = {}
        for k in range(n + 1):
            u = set()
            for kk in range(k - k_band, k + k_band + 1): u |= occ.get(kk, set())
            if u: score[k] = len(u) / n
        hits = sorted(k for k, v in score.items() if v >= min_occ)
        runs = []
        for k in hits:
            if runs and k - runs[-1][-1] <= 1: runs[-1].append(k)
            else: runs.append([k])
        offs = []
        for r in runs:
            best = max(r, key=lambda k: (len(occ.get(k, ())), score[k]))
            offs.append(best * res - half)
        gaps = np.diff(offs) if len(offs) > 1 else np.array([])
        res_out[fam] = {'offsets': [round(o) for o in offs], 'gaps': [round(g) for g in gaps],
                        'median_gap': float(np.median(gaps)) if len(gaps) else None}
    return res_out

def blocks(lines_xy, clip=None, amin=300.0, amax=400000.0):
    ls = [LineString(xy) for xy in lines_xy if len(xy) >= 2]
    u = unary_union(ls)
    polys = [p for p in polygonize(u)]
    if clip is not None:
        polys = [p for p in polys if clip.contains(p.representative_point())]
    good = [p for p in polys if amin <= p.area <= amax]
    dims = []
    for p in good:
        r = p.minimum_rotated_rectangle
        xs, ys = r.exterior.coords.xy
        e = sorted([math.hypot(xs[i+1]-xs[i], ys[i+1]-ys[i]) for i in range(2)])
        dims.append(e)
    return good, np.array(dims) if dims else np.zeros((0, 2))

def three_grid_fit(h, tol=5):
    """Greedy: best grid, then best second, then best third. Returns [(theta, cumulative_share)]."""
    tot = h.sum(); used = np.zeros(180, bool); out = []
    for _ in range(3):
        best = (None, -1, None)
        for t in range(90):
            m = used.copy()
            for a in (t, t + 90):
                for d in range(-tol, tol + 1): m[(a + d) % 180] = True
            s = h[m].sum()
            if s > best[1]: best = (t, s, m)
        used = best[2]; out.append((best[0], round(float(best[1] / tot), 3)))
    return out

def pooled_spacing(s, theta, half_region, res=25.0, min_occ=0.25, tol=8, band=75.0):
    r = arterial_spacing(s, theta, (0, 0, half_region), res=res, tol=tol, min_occ=min_occ, band=band)
    gaps = r['A']['gaps'] + r['B']['gaps']
    g = np.array(gaps, float)
    if not len(g): return None
    return {'n_gaps': int(len(g)), 'median': round(float(np.median(g))), 'p25': round(float(np.percentile(g, 25))),
            'p75': round(float(np.percentile(g, 75))),
            'share_350_450': round(float(((g >= 350) & (g <= 450)).mean()), 2),
            'share_700_900': round(float(((g >= 700) & (g <= 900)).mean()), 2),
            'share_1500_1700': round(float(((g >= 1500) & (g <= 1700)).mean()), 2),
            'gaps_along_grid': r['A']['gaps'], 'gaps_across': r['B']['gaps']}
