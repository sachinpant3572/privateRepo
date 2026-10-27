#!/usr/bin/env python3
"""Renders game/data/world_map.json to SVG: the whole world and a Bellerive close-up.

Usage: python3 game/tools/render_map.py [out_dir]   (default: repo root)
"""
import json
import sys
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "game" / "data" / "world_map.json"
MISSIONS = ROOT / "game" / "data" / "missions_act1.json"

REGION_FILL = {
    "desert": "#e8d3a2", "military": "#b9b39a", "mountains": "#b7a99a", "forest": "#8fb27a",
    "lakeside": "#a9c98f", "hills": "#9cc488", "farmland": "#d9d79a", "bayou": "#7fa37a",
    "island": "#e9dca8", "rustbelt": "#b8b59a", "parkland": "#a6cf8f",
}
STYLE_FILL = {
    "quarter": "#f2a65a", "docks": "#9aa3ad", "downtown": "#7d8fa8", "heights": "#e9e4c9",
    "wards": "#e88b8b", "bayou": "#5f8a5a", "beach": "#f3dd8c", "hillside": "#d98a5f",
    "strip": "#e04f8a", "industrial": "#a08a75", "civic": "#f4f1e6", "midtown": "#8796ad",
    "financial": "#6d7f99", "waterfront": "#b9c4cf", "oldtown": "#d9a066", "park": "#7fbf6a",
    "rowhouse": "#d7b8a0", "market": "#c9a46b", "revival": "#9fb5c9", "prairie": "#bcc48f",
    "enclave": "#d39b74", "suburb": "#dfe6c8",
}
ROUTE_STYLE = {
    "highway": ("#fff7e0", 9, ""), "rail": ("#5b4636", 4, "14 6"), "streetcar": ("#b5462f", 4, "6 4"),
    "metro": ("#7b4fa0", 4, "6 4"), "ferry": ("#ffffff", 3, "10 8"), "air": ("#ffffff", 2, "3 9"),
    "road": ("#f3ead2", 4, ""), "mover": ("#2a9d8f", 3, "4 3"), "cable": ("#c0392b", 3, "2 3"),
    "bus": ("#e67e22", 3, "8 4"), "airship": ("#5dade2", 2, "6 6"),
    "lane": ("#f3ead2", 2.5, ""), "track": ("#8b5a2b", 2, "7 4"), "trail": ("#6b3e1e", 1.6, "2 3"),
}
# Paved roads get a dark edge under them.
CASED = ("highway", "road", "lane")
LANDMARK_ICON = {"police": "#2c3e70", "hospital": "#d33", "airport": "#333", "legend": "#6a1b9a",
                 "military": "#4d5656", "monument": "#b7950b", "cult": "#5dade2", "garage": "#e67e22",
                 "dam": "#2874a6", "station": "#1e8449", "rental": "#16a085", "ruin": "#7b6d5d",
                 "union": "#1f618d", "mafia": "#7b241c", "casino": "#c2185b", "gas": "#f39c12",
                 "camp": "#27ae60", "farm": "#a17a2b", "lookout": "#784212", "lighthouse": "#d4ac0d",
                 "mine": "#6e5a48", "motel": "#8e44ad", "tunnel": "#555", "pass": "#7f8c8d",
                 "bus": "#e67e22", "ford": "#5d6d7e", "bridge": "#b03a2e", "peak": "#5b4a3a"}
# Terrain texture drawn over each region: SVG pattern bodies, 1 unit = 1 px.
TERRAIN = {
    "forest": (18, '<circle cx="5" cy="6" r="2.6" fill="#5f8a4f"/><circle cx="14" cy="14" r="2.2" fill="#6b9659"/>'),
    "mountains": (26, '<path d="M3 18 L9 9 L15 18 M14 24 L20 15 L26 24" fill="none" stroke="#8a7c6e" stroke-width="1.3"/>'),
    "desert": (16, '<circle cx="4" cy="4" r="0.9" fill="#c9b07a"/><circle cx="12" cy="11" r="0.7" fill="#c9b07a"/>'),
    "farmland": (40, '<rect x="1" y="1" width="18" height="18" fill="#cfcd86"/><rect x="21" y="21" width="18" height="18" fill="#e3e1aa"/>'
                     '<path d="M21 3 H39 M21 7 H39 M21 11 H39 M21 15 H39" stroke="#c4c27c" stroke-width="0.8"/>'),
    "bayou": (20, '<path d="M4 12 L6 7 M6 12 L6 6 M8 12 L7 7" stroke="#5c8455" stroke-width="1"/><path d="M12 17 h6" stroke="#6fa8d6" stroke-width="1.6"/>'),
    "hills": (30, '<path d="M2 20 Q9 12 16 20" fill="none" stroke="#86b072" stroke-width="1.2"/>'),
    "lakeside": (20, '<circle cx="6" cy="6" r="2" fill="#86ad6f"/>'),
    "parkland": (24, '<circle cx="6" cy="6" r="2.4" fill="#86b876"/><path d="M14 18 Q18 14 22 18" fill="none" stroke="#8cbf78" stroke-width="1"/>'),
    "rustbelt": (22, '<path d="M2 2 L8 8" stroke="#a6a288" stroke-width="1"/><circle cx="15" cy="15" r="1.6" fill="#a29e84"/>'),
    "military": (24, '<path d="M0 24 L24 0" stroke="#a7a189" stroke-width="1.2"/>'),
}
TOWN_FILL = {"ghost": "#9b8f80", "truck_stop": "#b9770e", "village": "#555", "town": "#333"}


def tag(kind, item_id, phase=1):
    """Data attributes that let the atlas page make map elements tappable."""
    return f' data-kind="{kind}" data-id="{item_id}" data-phase="{phase}"'


def pts(points, s, ox=0, oy=0):
    return " ".join(f"{(x - ox) * s:.1f},{(y - oy) * s:.1f}" for x, y in points)


def text(x, y, label, size, weight="600", fill="#222", anchor="middle"):
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" font-weight="{weight}" fill="{fill}" '
            f'text-anchor="{anchor}" font-family="Helvetica, Arial, sans-serif" '
            f'paint-order="stroke" stroke="#fff" stroke-width="{size / 4:.1f}" stroke-opacity="0.8">'
            f'{escape(label)}</text>')


def faction_colors(world):
    return {f["id"]: f["color"] for f in world["factions"]}


def world_svg(world):
    s = 0.2
    w, h = world["size"][0] * s, world["size"][1] * s
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.0f} {h + 100:.0f}" width="{w:.0f}" height="{h + 100:.0f}">',
           f'<rect width="{w}" height="{h + 100}" fill="#cfe3c0"/>', "<defs>"]
    for kind, (size, body) in TERRAIN.items():
        out.append(f'<pattern id="t-{kind}" width="{size}" height="{size}" patternUnits="userSpaceOnUse">{body}</pattern>')
    out.append("</defs>")
    # Islands sit on top of the sea, so they are drawn after the water.
    land = [r for r in world["regions"] if r["type"] != "island"]
    islands = [r for r in world["regions"] if r["type"] == "island"]
    for r in land:
        out.append(_region(r, s))
    for wtr in world["water"]:
        if "polygon" in wtr:
            out.append(f'<polygon points="{pts(wtr["polygon"], s)}" fill="#6fa8d6"/>')
        else:
            out.append(f'<polyline points="{pts(wtr["line"], s)}" fill="none" stroke="#6fa8d6" stroke-width="{wtr["width"] * s:.1f}" stroke-linejoin="round" stroke-linecap="round"/>')
    for r in islands:
        out.append(_region(r, s))
    for c in world["cities"]:
        x, y, cw, ch = c["rect"]
        out.append(f'<rect x="{x * s}" y="{y * s}" width="{cw * s}" height="{ch * s}" fill="#ffffff" fill-opacity="0.35" rx="6"{tag("city", c["id"], c["phase"])}/>')
        for d in c["districts"]:
            dx, dy, dw, dh = d["rect"]
            out.append(f'<rect x="{dx * s}" y="{dy * s}" width="{dw * s}" height="{dh * s}" fill="{STYLE_FILL.get(d["style"], "#ddd")}" stroke="#fff" stroke-width="1"{tag("district", d["id"], c["phase"])}/>')
    for r in world["routes"]:
        color, width, dash = ROUTE_STYLE[r["type"]]
        if r["type"] in CASED:
            out.append(f'<polyline points="{pts(r["line"], s)}" fill="none" stroke="#8a7a5a" stroke-width="{width + (3 if r["type"] != "lane" else 1.6)}" stroke-linejoin="round"/>')
        dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
        out.append(f'<polyline points="{pts(r["line"], s)}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"{dash_attr}{tag("route", r["id"], r["phase"])}/>')
    for t in world["towns"]:
        x, y = t["pos"]
        kind = t.get("kind", "town")
        out.append(f'<circle cx="{x * s}" cy="{y * s}" r="{6 if kind == "town" else 5}" fill="{TOWN_FILL.get(kind, "#444")}" stroke="#fff" stroke-width="1"{tag("town", t["id"], t["phase"])}/>')
        out.append(text(x * s, y * s - 9, t["name"] + (" (ghost town)" if kind == "ghost" else ""), 13))
    for lm in world["landmarks"]:
        if lm.get("city"):
            continue
        x, y = lm["pos"]
        color = LANDMARK_ICON.get(lm["type"], "#555")
        mark = "?" if lm.get("secret") else ""
        if lm["type"] == "peak":
            cx, cy = x * s, y * s
            out.append(f'<polygon points="{cx - 8:.1f},{cy + 6:.1f} {cx:.1f},{cy - 8:.1f} {cx + 8:.1f},{cy + 6:.1f}" fill="{color}" stroke="#fff" stroke-width="1.5"{tag("landmark", lm["id"], lm.get("phase", 3))}/>')
            out.append(text(cx, cy + 19, f'{lm["name"]} {lm["elev"]:,} m', 11, "600"))
            continue
        if lm["type"] == "ford" or lm.get("minor"):
            out.append(f'<circle cx="{x * s}" cy="{y * s}" r="3.5" fill="{color}" stroke="#fff" stroke-width="1"{tag("landmark", lm["id"], lm.get("phase", 3))}/>')
            continue
        radius = 9 if lm.get("size") == "large" else (5 if lm.get("detail") else 6)
        out.append(f'<circle cx="{x * s}" cy="{y * s}" r="{radius}" fill="{color}" stroke="#fff" stroke-width="1.5"{tag("landmark", lm["id"], _phase_of(world, lm))}/>')
        if mark:
            out.append(f'<text x="{x * s}" y="{y * s + 4}" font-size="10" fill="#fff" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-weight="700">?</text>')
        out.append(text(x * s, y * s + 19, lm["name"], 11, "500"))
    for r in world["regions"]:
        xs = [p[0] for p in r["polygon"]]
        ys = [p[1] for p in r["polygon"]]
        lx, ly = r.get("label_pos", (sum(xs) / len(xs), sum(ys) / len(ys)))
        out.append(text(lx * s, ly * s, r["name"].upper(), 15, "700", "#4a4a3a"))
    for c in world["cities"]:
        x, y, cw, ch = c["rect"]
        out.append(text((x + cw / 2) * s, (y - 30) * s, f'{c["name"]} (phase {c["phase"]})', 20, "800", "#1d1d1d"))
        out.append(text((x + cw / 2) * s, (y - 30) * s + 18, f'{c.get("inspired_by", "")} · {c.get("condition", "")}', 12, "600", "#333"))
    for wtr in world["water"]:
        if "polygon" in wtr and wtr["type"] != "ocean":
            xs = [p[0] for p in wtr["polygon"]]
            ys = [p[1] for p in wtr["polygon"]]
            out.append(text(sum(xs) / len(xs) * s, sum(ys) / len(ys) * s, wtr["name"], 14, "700", "#2f5f86"))
        elif "line" in wtr and wtr.get("type") in ("river", "creek"):
            # Between the two middle points, beside the stream.
            line = wtr["line"]
            k = max(len(line) // 2 - 1, 0)
            mx = (line[k][0] + line[k + 1][0]) / 2
            my = (line[k][1] + line[k + 1][1]) / 2
            out.append(text(mx * s + 8, my * s, wtr["name"], 11, "600", "#2f5f86", anchor="start"))
    out.append(text(world["size"][0] * 0.3 * s, (world["size"][1] - 300) * s, "GULF OF SOLVERA", 22, "700", "#2f5f86"))
    out.append(_legend(10, h + 12))
    out.append("</svg>")
    return "\n".join(out)


def _region(r, s):
    shape = f'<polygon points="{pts(r["polygon"], s)}" fill="{REGION_FILL.get(r["type"], "#ccc")}" stroke="#fff" stroke-width="1.5" stroke-opacity="0.6"{tag("region", r["id"], r["phase"])}/>'
    if r["type"] in TERRAIN:
        shape += f'<polygon points="{pts(r["polygon"], s)}" fill="url(#t-{r["type"]})" pointer-events="none"/>'
    return shape


def _phase_of(world, landmark):
    """A landmark is built with its city, or with the region it sits in."""
    if landmark.get("city"):
        return next(c["phase"] for c in world["cities"] if c["id"] == landmark["city"])
    for r in world["regions"]:
        if _in_polygon(landmark["pos"], r["polygon"]):
            return r["phase"]
    return 3


def _in_polygon(p, poly):
    x, y = p
    inside = False
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[i - 1]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside


def _legend(x, y0):
    items = [("highway", "Highway"), ("road", "Road"), ("lane", "County lane"), ("track", "Dirt track (unpaved)"),
             ("trail", "Trail / 4x4"), ("rail", "Rail"), ("streetcar", "Streetcar"), ("metro", "Metro / monorail"),
             ("mover", "People mover"), ("ferry", "Ferry / cruise"), ("air", "Flights")]
    parts = []
    for i, (kind, label) in enumerate(items):
        color, width, dash = ROUTE_STYLE[kind]
        lx = x + (i % 6) * 330
        y = y0 + (i // 6) * 26
        bg = '<rect x="{0}" y="{1}" width="50" height="16" fill="#6fa8d6"/>'.format(lx, y + 2) if kind in ("ferry", "air", "road", "lane") else ""
        dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
        parts.append(f'{bg}<line x1="{lx}" y1="{y + 10}" x2="{lx + 50}" y2="{y + 10}" stroke="{color}" stroke-width="{width}"{dash_attr}/>')
        parts.append(text(lx + 58, y + 15, label, 14, "500", anchor="start"))
    parts.append(text(x, y0 + 72, "? = secret / legend. Big grey dot = the large military base. Triangle = peak. Small grey dot = ford, small red dot = bridge. Phase = build order (1 = playable now).", 14, "500", anchor="start"))
    return "".join(parts)


def stop_pos(world, stop):
    """A mission stop is a landmark id or a {pos, label} point."""
    if isinstance(stop, str):
        return next(lm["pos"] for lm in world["landmarks"] if lm["id"] == stop)
    return stop["pos"]


def mission_points(world, mission):
    points = [stop_pos(world, st) for st in mission["stops"]]
    points += [stop_pos(world, b["stop"]) for b in mission.get("branches", [])]
    return points


def city_svg(world, city_id, missions=()):
    city = next(c for c in world["cities"] if c["id"] == city_id)
    colors = faction_colors(world)
    pad = 150
    x0, y0, cw, ch = city["rect"]
    xs, ys = [x0, x0 + cw], [y0, y0 + ch]
    for m in missions:
        for px, py in mission_points(world, m):
            xs.append(px)
            ys.append(py)
    ox, oy = min(xs) - pad, min(ys) - pad
    vw, vh = max(xs) - min(xs) + pad * 2, max(ys) - min(ys) + pad * 2
    s = 0.6
    w, h = vw * s, vh * s
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.0f} {h + 60:.0f}" width="{w:.0f}" height="{h + 60:.0f}">',
           f'<rect width="{w}" height="{h + 60}" fill="#cfe3c0"/>']
    for wtr in world["water"]:
        if "polygon" in wtr:
            out.append(f'<polygon points="{pts(wtr["polygon"], s, ox, oy)}" fill="#6fa8d6"/>')
        else:
            out.append(f'<polyline points="{pts(wtr["line"], s, ox, oy)}" fill="none" stroke="#6fa8d6" stroke-width="{wtr["width"] * s:.1f}" stroke-linejoin="round"/>')
    for d in city["districts"]:
        dx, dy, dw, dh = d["rect"]
        rx, ry = (dx - ox) * s, (dy - oy) * s
        out.append(f'<rect x="{rx:.1f}" y="{ry:.1f}" width="{dw * s:.1f}" height="{dh * s:.1f}" fill="{STYLE_FILL.get(d["style"], "#ddd")}" stroke="{colors.get(d["faction"], "#999")}" stroke-width="6"{tag("district", d["id"], city["phase"])}/>')
        out.append(text(rx + 12, ry + 30, d["name"], 22, "800", anchor="start"))
        out.append(text(rx + 12, ry + 52, f'{d["style"]} · {_faction_name(world, d["faction"])}', 15, "500", "#333", anchor="start"))
    for r in world["routes"]:
        color, width, dash = ROUTE_STYLE[r["type"]]
        if r["type"] == "air":
            continue
        dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
        out.append(f'<polyline points="{pts(r["line"], s, ox, oy)}" fill="none" stroke="{color}" stroke-width="{width * 1.5}" stroke-linejoin="round"{dash_attr}/>')
    win = city.get("demo_window")
    if win:
        sw, sh = (b * win["pitch"] for b in win["blocks"])
        wx, wy = win["origin"]
        out.append(f'<rect x="{(wx - ox) * s:.1f}" y="{(wy - oy) * s:.1f}" width="{sw * s:.1f}" height="{sh * s:.1f}" fill="none" stroke="#111" stroke-width="3" stroke-dasharray="8 5"/>')
        out.append(text((wx - ox) * s, (wy - oy) * s - 8, "demo area", 14, "700", anchor="start"))
    for lm in world["landmarks"]:
        if lm.get("city") != city_id and not _inside(lm["pos"], (ox, oy, vw, vh)):
            continue
        x, y = (lm["pos"][0] - ox) * s, (lm["pos"][1] - oy) * s
        color = LANDMARK_ICON.get(lm["type"], "#555")
        out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="7" fill="{color}" stroke="#fff" stroke-width="2"{tag("landmark", lm["id"], city["phase"])}/>')
        label = lm["name"] + (" (secret)" if lm.get("secret") else "")
        out.append(text(x, y - 12, label, 13, "600"))
    out.extend(_missions(world, missions, s, ox, oy))
    note = " Numbered circles = act 1 missions." if missions else ""
    out.append(text(14, h + 36, f'{city["name"]}: district fill = style, border = controlling faction. 1 px = {1 / s:.1f} m.{note}', 16, "500", anchor="start"))
    out.append("</svg>")
    return "\n".join(out)


def _missions(world, missions, s, ox, oy):
    """Mission routes as faint dashed lines, then a numbered marker at each
    mission's main location (its last stop; the finale also marks its branches)."""
    lines, markers, used = [], [], {}

    def marker(pos, label, mission):
        key = (round(pos[0] / 40), round(pos[1] / 40))
        nudge = used.get(key, 0)
        used[key] = nudge + 1
        x, y = (pos[0] - ox) * s + 20 + nudge * 28, (pos[1] - oy) * s + 4
        markers.append(f'<g{tag("mission", mission["id"], 1)}><circle cx="{x:.1f}" cy="{y:.1f}" r="13" fill="#1f2a2e" stroke="#fff" stroke-width="2"/>'
                       f'<text x="{x:.1f}" y="{y + 5:.1f}" font-size="13" font-weight="700" fill="#fff" text-anchor="middle" '
                       f'font-family="Helvetica, Arial, sans-serif">{label}</text></g>')

    for m in missions:
        route = [stop_pos(world, st) for st in m["stops"]]
        if len(route) > 1:
            lines.append(f'<polyline points="{pts(route, s, ox, oy)}" fill="none" stroke="#1f2a2e" stroke-opacity="0.3" stroke-width="2.5" stroke-dasharray="2 5" stroke-linecap="round"/>')
        branches = m.get("branches", [])
        marker(route[-1] if not branches else route[0], str(m["order"]), m)
        for i, b in enumerate(branches):
            end = stop_pos(world, b["stop"])
            lines.append(f'<polyline points="{pts([route[0], end], s, ox, oy)}" fill="none" stroke="#b5462f" stroke-opacity="0.6" stroke-width="2.5" stroke-dasharray="6 5"/>')
            marker(end, f'{m["order"]}{"abc"[i]}', m)
    return lines + markers


def _faction_name(world, fid):
    return next((f["name"] for f in world["factions"] if f["id"] == fid), fid)


def _inside(p, rect):
    x, y, w, h = rect
    return x <= p[0] <= x + w and y <= p[1] <= y + h


def main():
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT
    world = json.loads(DATA.read_text())
    (out_dir / "world_map.svg").write_text(world_svg(world))
    missions = json.loads(MISSIONS.read_text())["missions"]
    (out_dir / "bellerive_map.svg").write_text(city_svg(world, "bellerive", missions))
    print("wrote", out_dir / "world_map.svg", "and", out_dir / "bellerive_map.svg")


if __name__ == "__main__":
    main()
