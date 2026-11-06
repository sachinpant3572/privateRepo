import sys, json, glob, math, os, pickle
sys.path.insert(0, os.path.dirname(__file__))
from calib import *
from draw import Canvas
OUT = '/home/user/privateRepo/reference/world/california'
os.makedirs(OUT, exist_ok=True)
CACHE = DL + '/../cache'; os.makedirs(CACHE, exist_ok=True)
METRICS = {}

def gj(name): return json.load(open(f'{DL}/{name}.geojson'))['features']
def rings(geom):
    if geom['type'] == 'Polygon': return [geom['coordinates'][0]]
    if geom['type'] == 'MultiPolygon': return [p[0] for p in geom['coordinates']]
    return []

AGENCIES = ['los-angeles-metro-bus', 'los-angeles-dot', 'santa-monica-big-blue-bus', 'long-beach-transit',
            'orange-county-transportation-authority', 'san-bernardino-omnitrans', 'riverside-transit-agency',
            'fresno-area-express', 'san-diego-metropolitan-transit-system', 'san-francisco-municipal-transportation-agency',
            'ac-transit', 'santa-clara-valley-transportation-authority', 'sacramento-regional-transit',
            'golden-empire-transit-district', 'visalia-transit', 'sunline-transit-agency', 'victor-valley-transit-authority']
def bus(agency):
    p = f'{CACHE}/{agency}.pkl'
    if os.path.exists(p): return pickle.load(open(p, 'rb'))
    v = load_gtfs_shapes(f'{DL}/gtfs/{agency}.txt'); pickle.dump(v, open(p, 'wb')); return v

ORI_COL = {'g1': (60, 60, 60), 'g2': (40, 110, 200), 'g3': (30, 150, 70), 'other': (230, 110, 20)}
def classify(b, g1, g2=None, tol=5, g3=None):
    def near(t):
        return min(abs(((b - t) + 90) % 180 - 90), abs(((b - t - 90) + 90) % 180 - 90)) <= tol
    if near(g1): return 'g1'
    if g2 is not None and near(g2): return 'g2'
    if g3 is not None and near(g3): return 'g3'
    return 'other'

def shares(h, g1, g2=None, tol=5, g3=None):
    tot = h.sum(); s = {'g1': 0.0, 'g2': 0.0, 'g3': 0.0, 'other': 0.0}
    for b in range(180): s[classify(b, g1, g2, tol, g3)] += h[b]
    return {k: round(v / tot, 3) for k, v in s.items()} if tot else s

def top_peaks(h, k=4, sep=8):
    hh = np.convolve(np.r_[h[-2:], h, h[:2]], np.ones(5), 'valid'); out = []
    for i in np.argsort(-hh):
        if all(min(abs(i - j), 180 - abs(i - j)) >= sep for j in out): out.append(int(i))
        if len(out) == k: break
    tot = h.sum()
    return [(a, round(float(hh[a]) / tot, 3)) for a in out]

# ---------------------------------------------------------------- 1. zoomed-out state
def state_map():
    P = Proj(37.2, -119.4)
    cnt = gj('california-counties')
    allxy = [P(*p) for f in cnt for r in rings(f['geometry']) for p in r]
    xs, ys = zip(*allxy)
    C = Canvas(min(xs) - 5000, min(ys) - 5000, max(xs) + 5000, max(ys) + 5000, W=1200)
    C.title('California, fully zoomed out: 58 counties, city neighbourhood outlines, bus-route arterials',
            'Grey: county lines. Red: every bus route of 17 agencies (traces the arterial grids). Purple: neighbourhood outlines (LA, SF, Oakland, San Diego).')
    for f in cnt:
        for r in rings(f['geometry']): C.poly([P(*p) for p in r], outline=(150, 150, 150), fill=(238, 236, 228))
    for a in AGENCIES:
        for ll in bus(a): C.line([P(*p) for p in ll], (205, 40, 40), 1)
    for city in ('los-angeles', 'san-francisco', 'oakland', 'san-diego'):
        for f in gj(city):
            for r in rings(f['geometry']): C.poly([P(*p) for p in r], outline=(120, 60, 160))
    for f in cnt:
        r = max(rings(f['geometry']), key=len)
        poly = Polygon([P(*p) for p in r])
        c = poly.representative_point()
        C.text(c.x, c.y, f['properties']['name'], sz=10, fill=(70, 70, 70))
    for lab, (lat, lon) in {'LA basin': (34.03, -118.30), 'SF / Bay': (37.77, -122.35), 'San Diego': (32.72, -117.15),
                            'Fresno (Central Valley)': (36.75, -119.78), 'Inland Empire': (34.06, -117.40),
                            'Coachella desert': (33.72, -116.30), 'Sacramento': (38.58, -121.49)}.items():
        x, y = P(lon, lat); C.text(x + 30000, y + 9000, lab, sz=13, bold=True, fill=(150, 20, 20), anchor='lm')
    C.scalebar(100000); C.save(f'{OUT}/01_california_zoomed_out.png')

# ---------------------------------------------------------------- 2. region maps
def region_map(fname, title, sub, city, agencies, center, half_km, labels=None, extra_labels=None):
    P = Proj(*center); h = half_km * 1000
    C = Canvas(-h, -h * 0.85, h, h * 0.85, W=1200)
    C.title(title, sub)
    feats = gj(city)
    for f in feats:
        for r in rings(f['geometry']): C.poly([P(*p) for p in r], outline=(140, 100, 170), fill=(240, 236, 246))
    for a in agencies:
        for ll in bus(a): C.line([P(*p) for p in ll], (200, 60, 50), 1)
    for f in feats:
        nm = f['properties']['name']
        if labels is not None and nm not in labels: continue
        r = max(rings(f['geometry']), key=len)
        try: c = Polygon([P(*p) for p in r]).representative_point()
        except Exception: continue
        if -h < c.x < h and -h < c.y < h: C.text(c.x, c.y, nm, sz=11, fill=(40, 20, 70))
    for nm, (lat, lon) in (extra_labels or {}).items():
        x, y = P(lon, lat); C.text(x, y, nm, sz=11, fill=(110, 110, 110))
    C.scalebar(); C.save(f'{OUT}/{fname}')

# ---------------------------------------------------------------- 3. bus-arterial zoom-ins
def bus_window(key, agencies, center, half_km, draw=None, grids=None):
    P = Proj(*center); h = half_km * 1000
    lines = []
    for a in agencies:
        for ll in bus(a):
            xy = [P(*p) for p in ll]
            if any(abs(x) < h and abs(y) < h for x, y in xy): lines.append(xy)
    s = sample_dedupe(lines)
    s = s[(np.abs(s[:, 0]) <= h) & (np.abs(s[:, 1]) <= h)] if len(s) else s
    hh = hist_from_samples(s)
    tg = three_grid_fit(hh)
    g1, g2, g3 = (grids if grids else tuple(t for t, _ in tg))
    sh = shares(hh, g1, g2, 5, g3)
    sp = pooled_spacing(s, g1, h)
    m = {'source': 'bus-route shapes: ' + ', '.join(agencies), 'window_km': 2 * half_km,
         'unique_route_km': round(len(s) * 25 / 1000, 1), 'grids_deg': [g1, g2, g3], 'shares_5deg': sh,
         'cumulative_share_1_2_3_grids': [c for _, c in tg], 'top_bearings': top_peaks(hh),
         'arterial_spacing_pooled_m': sp}
    METRICS[key] = m
    if draw:
        C = Canvas(-h, -h, h, h, W=1200)
        C.title(draw[0], draw[1])
        for xy in lines:
            for x1, y1, x2, y2, L, b in seg_iter(xy):
                if max(abs(x1), abs(y1)) > h * 1.05: continue
                C.line([(x1, y1), (x2, y2)], ORI_COL[classify(b, g1, g2, 5, g3)], 2)
        for nm, (lat, lon) in (draw[2] if len(draw) > 2 else {}).items():
            x, y = P(lon, lat); C.text(x, y, nm, sz=13, bold=True, fill=(120, 20, 120))
        C.legend([(ORI_COL['g1'], 3, f'main grid {g1}/{g1+90} deg (+-5): {sh["g1"]:.0%}'),
                  (ORI_COL['g2'], 3, f'2nd grid {g2}/{(g2+90)%180} deg: {sh["g2"]:.0%}'),
                  (ORI_COL['g3'], 3, f'3rd grid {g3}/{(g3+90)%180} deg: {sh["g3"]:.0%}'),
                  (ORI_COL['other'], 3, f'diagonal or curved: {sh["other"]:.0%}')])
        C.scalebar(); C.save(f'{OUT}/{key}.png')
    return m

# ---------------------------------------------------------------- 4. full street zoom-ins
CLASS_W = {'motorway': 6, 'trunk': 5, 'primary': 5, 'secondary': 4, 'tertiary': 3, 'motorway_link': 2,
           'trunk_link': 2, 'primary_link': 2, 'secondary_link': 2, 'tertiary_link': 2}
def street_window(key, ways, title, sub, labels=None, grids=None, win=None, spacing_windows=None, blockclip=None):
    drive = [w for w in ways if w['hw'] in DRIVE]
    hh = bearing_hist([w['xy'] for w in drive])
    tg = three_grid_fit(hh)
    g1, g2, g3 = grids if grids else tuple(t for t, _ in tg)
    sh = shares(hh, g1, g2, 5, g3)
    wide = [w for w in drive if w['hw'] in WIDE]
    hw_len = {}
    for w in drive:
        hw_len[w['hw']] = hw_len.get(w['hw'], 0) + sum(L for *_, L, b in seg_iter(w['xy']))
    tot = sum(hw_len.values())
    good, dims = blocks([w['xy'] for w in drive])
    areas = np.array([p.area for p in good])
    m = {'drive_km': round(tot / 1000, 1), 'grids_deg': [g1, g2, g3], 'shares_5deg': sh,
         'cumulative_share_1_2_3_grids': [c for _, c in tg],
         'top_bearings': top_peaks(hh),
         'class_share_of_length': {k: round(v / tot, 3) for k, v in sorted(hw_len.items(), key=lambda kv: -kv[1])},
         'blocks_n': int(len(good)),
         'block_area_m2_median': round(float(np.median(areas))) if len(areas) else None,
         'block_area_m2_p25_p75': [round(float(np.percentile(areas, 25))), round(float(np.percentile(areas, 75)))] if len(areas) else None,
         'block_short_x_long_m_median': [round(float(np.median(dims[:, 0]))), round(float(np.median(dims[:, 1])))] if len(dims) else None}
    if spacing_windows:
        m['wide_road_spacing'] = {}
        sw = sample_dedupe([w['xy'] for w in wide], step=10, cell=10)
        sa = sample_dedupe([w['xy'] for w in drive], step=10, cell=10)
        for nm, (cx, cy, half, g) in spacing_windows.items():
            spw = arterial_spacing(sw, g, (cx, cy, half), res=10, min_occ=0.5, band=30)
            spa = arterial_spacing(sa, g, (cx, cy, half), res=10, min_occ=0.5, band=20)
            m['wide_road_spacing'][nm] = {'grid_deg': g, 'window_m': 2 * half,
                'wide_gaps_A': spw['A']['gaps'], 'wide_gaps_B': spw['B']['gaps'],
                'all_street_gaps_A': spa['A']['gaps'], 'all_street_gaps_B': spa['B']['gaps']}
    METRICS[key] = m
    xs = [p[0] for w in ways for p in w['xy']]; ys = [p[1] for w in ways for p in w['xy']]
    x0, y0, x1, y1 = win if win else (min(xs) - 50, min(ys) - 50, max(xs) + 50, max(ys) + 50)
    C = Canvas(x0, y0, x1, y1, W=1200)
    C.title(title, sub)
    for p in good:
        C.poly(list(p.exterior.coords), outline=None, fill=(236, 232, 222))
    order = sorted(ways, key=lambda w: CLASS_W.get(w['hw'], 1))
    for w in order:
        if w['hw'] not in DRIVE:
            if w['hw'] == 'service': C.line(w['xy'], (190, 190, 190), 1)
            continue
        wd = max(1, int(CLASS_W.get(w['hw'], 1) * max(0.6, min(1.6, C.s * 2.0))))
        for x1_, y1_, x2_, y2_, L, b in seg_iter(w['xy']):
            C.line([(x1_, y1_), (x2_, y2_)], ORI_COL[classify(b, g1, g2, 5, g3)], wd)
    for nm, (x, y) in (labels or {}).items(): C.text(x, y, nm, sz=13, bold=True, fill=(120, 20, 120))
    C.legend([(ORI_COL['g1'], 4, f'grid {g1}/{(g1+90)%180} deg (+-5): {sh["g1"]:.0%} of length'),
              (ORI_COL['g2'], 4, f'grid {g2}/{(g2+90)%180} deg (+-5): {sh["g2"]:.0%}'),
              (ORI_COL['g3'], 4, f'grid {g3}/{(g3+90)%180} deg (+-5): {sh["g3"]:.0%}'),
              (ORI_COL['other'], 4, f'diagonal or curved: {sh["other"]:.0%}'),
              ((60, 60, 60), 6, 'thick = primary/secondary/trunk'),
              ((236, 232, 222), 10, 'filled = closed block')])
    C.scalebar(); C.save(f'{OUT}/{key}.png')
    return m

def main():
    state_map()
    region_map('02_la_basin_neighbourhoods.png', 'Los Angeles basin: city neighbourhoods + bus-route arterials',
               'Purple: City of LA neighbourhoods (LA Times Mapping L.A. via click_that_hood). Red: LA Metro, LADOT DASH, Big Blue Bus, Long Beach Transit routes (2017-18 GTFS). Grey labels: separate cities, label position only.',
               'los-angeles', ['los-angeles-metro-bus', 'los-angeles-dot', 'santa-monica-big-blue-bus', 'long-beach-transit'],
               (33.98, -118.33), 32,
               labels={'Downtown', 'Hollywood', 'Hollywood Hills', 'Bel-Air', 'Venice', 'Westwood', 'Century City', 'Koreatown',
                       'Boyle Heights', 'Watts', 'San Pedro', 'Wilmington', 'Van Nuys', 'North Hollywood', 'Encino',
                       'Pacific Palisades', 'Griffith Park', 'Silver Lake', 'Exposition Park', 'Westchester', 'Historic South-Central',
                       'Sherman Oaks', 'Elysian Park', 'Leimert Park', 'Harbor Gateway', 'Mid-City', 'Chinatown'},
               extra_labels={'Beverly Hills': (34.073, -118.400), 'Santa Monica': (34.020, -118.480), 'Culver City': (34.010, -118.396),
                             'Vernon (industrial)': (34.001, -118.215), 'Inglewood': (33.962, -118.353), 'Compton': (33.896, -118.220),
                             'Long Beach': (33.790, -118.170), 'Glendale': (34.150, -118.255), 'Pasadena': (34.150, -118.140),
                             'Burbank': (34.185, -118.315), 'Port (San Pedro Bay)': (33.745, -118.235), 'LAX': (33.943, -118.408)})
    region_map('03_san_francisco_neighbourhoods.png', 'San Francisco: neighbourhoods + Muni routes',
               'Purple: SF neighbourhoods (click_that_hood). Red: Muni route shapes (2017-18 GTFS).',
               'san-francisco', ['san-francisco-municipal-transportation-agency'], (37.758, -122.445), 7.0, labels=None)
    region_map('04_san_diego_neighbourhoods.png', 'San Diego: neighbourhoods + MTS routes',
               'Purple: San Diego neighbourhoods (click_that_hood). Red: MTS route shapes (2017-18 GTFS).',
               'san-diego', ['san-diego-metropolitan-transit-system'], (32.78, -117.12), 17,
               labels={'Downtown', 'Gaslamp Quarter', 'Balboa Park', 'La Jolla', 'Pacific Beach', 'Mission Beach', 'Ocean Beach', 'Point Loma Heights',
                       'Hillcrest', 'North Park', 'City Heights', 'Barrio Logan', 'Logan Heights', 'Mission Valley', 'Clairemont Mesa', 'Kearny Mesa',
                       'Southeastern San Diego', 'Encanto', 'Otay Mesa', 'San Ysidro', 'Tierrasanta', 'Mira Mesa', 'University City', 'Linda Vista',
                       'East Village', 'Little Italy', 'Midway District', 'Old Town', 'Coronado', 'Marina'})
    region_map('05_oakland_east_bay_neighbourhoods.png', 'Oakland / East Bay: neighbourhoods + AC Transit routes',
               'Purple: Oakland neighbourhoods (click_that_hood). Red: AC Transit route shapes (2017-18 GTFS).',
               'oakland', ['ac-transit'], (37.795, -122.225), 8.5,
               labels={'Downtown', 'West Oakland', 'Jack London Square', 'Lake Merritt', 'Fruitvale', 'East Oakland', 'Montclair',
                       'Rockridge', 'Temescal', 'Chinatown', 'Port of Oakland', 'Elmhurst', 'Oakland Hills', 'Piedmont', 'Coliseum',
                       'Adams Point', 'Prescott', 'Uptown', 'Old Oakland', 'Brookfield Village', 'Sobrante Park', 'Acorn'})
    LA = ['los-angeles-metro-bus', 'los-angeles-dot', 'santa-monica-big-blue-bus']
    bus_window('10_la_central_arterials', LA, (34.035, -118.33), 10,
               draw=('Central LA, 20 x 20 km: arterials (bus routes) by orientation',
                     'Unique bus-route length by angle. Dark: cardinal survey grid. Blue: downtown grid (32-38 deg). Green: Westside/Santa Monica grid. Orange: diagonal boulevards, hill roads, freeway runs.',
                     {'DTLA': (34.047, -118.252), 'Hollywood': (34.100, -118.330), 'Beverly Hills': (34.073, -118.400),
                      'Koreatown': (34.060, -118.300), 'South LA': (33.985, -118.290), 'Culver City': (34.010, -118.396)}))
    bus_window('la_dtla_core', LA, (34.045, -118.252), 1.6)
    bus_window('la_south', LA, (33.955, -118.285), 5)
    bus_window('la_westside', LA, (34.03, -118.44), 4)
    bus_window('11_la_san_fernando_valley_arterials', LA, (34.205, -118.48), 10,
               draw=('San Fernando Valley, 20 x 20 km: arterials (bus routes) by orientation',
                     'The half-mile/one-mile boulevard grid. Orange = the few diagonals (old roads, rail corridors) and hill roads.',
                     {'Van Nuys': (34.186, -118.449), 'Northridge': (34.228, -118.536), 'North Hollywood': (34.168, -118.378),
                      'Encino hills': (34.145, -118.50)}))
    bus_window('12_orange_county_irvine_arterials', ['orange-county-transportation-authority'], (33.685, -117.80), 7,
               draw=('Irvine (Orange County), 14 x 14 km: arterials (bus routes) by orientation',
                     'Master-planned: wide arterials around villages, curving parkways; grid rotated off north.',
                     {'Irvine Spectrum': (33.650, -117.743), 'UCI': (33.646, -117.842), 'Woodbridge': (33.680, -117.795)}))
    bus_window('oc_anaheim_santa_ana', ['orange-county-transportation-authority'], (33.80, -117.90), 7)
    bus_window('13_inland_empire_arterials', ['san-bernardino-omnitrans'], (34.07, -117.50), 10,
               draw=('Inland Empire (Ontario / Fontana), 20 x 20 km: arterials (bus routes)',
                     'Mile-section arterial grid across warehouse land; orange = old diagonal highways and rail-side roads.',
                     {'Ontario airport': (34.056, -117.600), 'Fontana': (34.092, -117.435), 'Rancho Cucamonga': (34.106, -117.593)}))
    bus_window('14_fresno_central_valley_arterials', ['fresno-area-express'], (36.79, -119.79), 10,
               draw=('Fresno (Central Valley), 20 x 20 km: arterials (bus routes)',
                     'Section-line avenues every mile, half-mile collectors; downtown on a rotated railroad grid (blue).',
                     {'Downtown (rail grid)': (36.737, -119.787)}))
    bus_window('15_coachella_desert_arterials', ['sunline-transit-agency'], (33.76, -116.36), 12,
               draw=('Coachella Valley desert, 24 x 24 km: arterials (bus routes)',
                     'Sparse mile grid of desert boulevards; one long diagonal highway follows the valley.',
                     {'Palm Springs': (33.830, -116.545), 'Palm Desert': (33.722, -116.375), 'Indio': (33.720, -116.216)}))
    bus_window('sd_midcity', ['san-diego-metropolitan-transit-system'], (32.75, -117.12), 6)
    bus_window('oakland_flats', ['ac-transit'], (37.80, -122.25), 5)
    bus_window('silicon_valley', ['santa-clara-valley-transportation-authority'], (37.37, -121.96), 10)
    bus_window('sacramento', ['sacramento-regional-transit'], (38.57, -121.45), 8)
    bus_window('bakersfield', ['golden-empire-transit-district'], (35.36, -119.03), 8)
    bus_window('high_desert_victorville', ['victor-valley-transit-authority'], (34.50, -117.33), 10)
    bus_window('riverside', ['riverside-transit-agency'], (33.95, -117.40), 8)

    # ---- SF streets (OSM via grand-tech-auto-sf, local metres; x east, -z north)
    sf = []
    seen = set()
    for f in sorted(glob.glob(DL + '/gta/*.json')):
        for r in json.load(open(f))['roads']:
            k = r['id']
            if k in seen: continue
            seen.add(k)
            sf.append({'hw': r['highway'], 'name': r.get('name', ''), 'xy': [(p[0], -p[2]) for p in r['points']]})
    def mean_of(name):
        pts = [p for w in sf if w['name'] == name for p in w['xy']]; return np.mean(pts, axis=0)
    lab = {nm: tuple(mean_of(st)) for nm, st in {'Market St (seam)': 'Market Street', 'Tenderloin': 'Jones Street',
           'SoMa': 'Folsom Street', 'Mission': 'Valencia Street', 'Van Ness': 'Van Ness Avenue'}.items()}
    def meet(a, b):
        A = np.array([p for w in sf if w['name'] == a for p in w['xy']]); B = np.array([p for w in sf if w['name'] == b for p in w['xy']])
        d = ((A[:, None, :] - B[None, :, :]) ** 2).sum(-1); i, j = np.unravel_index(np.argmin(d), d.shape); return (A[i] + B[j]) / 2
    tl = meet('Jones Street', 'Eddy Street'); so = meet('6th Street', 'Folsom Street'); mi = meet('Valencia Street', '20th Street')
    street_window('20_sf_downtown_soma_mission_streets', sf, 'San Francisco: Tenderloin, Civic Center, SoMa, Mission (OSM streets)',
                  'Two grids meet at Market St: north grid ~7 deg off north, SoMa grid 45 deg. Blank areas = cells missing in the source (OSM roads packaged by github.com/willgdjones/grand-tech-auto-sf).',
                  labels=lab,
                  spacing_windows={'north_of_market_tenderloin': (tl[0], tl[1], 600, 82),
                                   'soma': (so[0], so[1], 700, 45), 'mission': (mi[0], mi[1], 700, 86)})
    wo = load_osm_xml(DL + '/West-Oakland.osm.bz2'); project_ways(wo, Proj(37.811, -122.302))
    hh = bearing_hist([w['xy'] for w in wo if w['hw'] in DRIVE]); tg = three_grid_fit(hh)
    METRICS['west_oakland_osm'] = {'drive_km': round(hh.sum() / 1000, 1), 'grids_deg': [t for t, _ in tg],
                                   'cumulative_share_1_2_3_grids': [c for _, c in tg], 'top_bearings': top_peaks(hh)}
    bus_window('16_san_diego_arterials', ['san-diego-metropolitan-transit-system'], (32.74, -117.12), 9,
               draw=('San Diego, 18 x 18 km: arterials (bus routes) by orientation',
                     'Mesas and canyons break the grid: straight grids on the mesa tops, curving roads down canyons and along the bay.',
                     {'Downtown': (32.715, -117.160), 'City Heights': (32.748, -117.100), 'Mission Valley': (32.770, -117.150),
                      'Southeast SD': (32.700, -117.090)}))
    json.dump(METRICS, open(f'{DL}/../metrics.json', 'w'), indent=1)
    print(json.dumps(METRICS, indent=1)[:200])

if __name__ == '__main__':
    main()
