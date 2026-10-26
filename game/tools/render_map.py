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
    "island": "#e9dca8",
}
STYLE_FILL = {
    "quarter": "#f2a65a", "docks": "#9aa3ad", "downtown": "#7d8fa8", "heights": "#e9e4c9",
    "wards": "#e88b8b", "bayou": "#5f8a5a", "beach": "#f3dd8c", "hillside": "#d98a5f",
    "strip": "#e04f8a", "industrial": "#a08a75",
}
ROUTE_STYLE = {
    "highway": ("#fff7e0", 9, ""), "rail": ("#5b4636", 4, "14 6"), "streetcar": ("#b5462f", 4, "6 4"),
    "metro": ("#7b4fa0", 4, "6 4"), "ferry": ("#ffffff", 3, "10 8"), "air": ("#ffffff", 2, "3 9"),
}
LANDMARK_ICON = {"police": "#2c3e70", "hospital": "#d33", "airport": "#333", "legend": "#6a1b9a"}


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
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.0f} {h + 70:.0f}" width="{w:.0f}" height="{h + 70:.0f}">',
           f'<rect width="{w}" height="{h + 70}" fill="#cfe3c0"/>']
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
        if r["type"] == "highway":
            out.append(f'<polyline points="{pts(r["line"], s)}" fill="none" stroke="#8a7a5a" stroke-width="{width + 3}" stroke-linejoin="round"/>')
        dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
        out.append(f'<polyline points="{pts(r["line"], s)}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"{dash_attr}{tag("route", r["id"], r["phase"])}/>')
    for t in world["towns"]:
        x, y = t["pos"]
        out.append(f'<circle cx="{x * s}" cy="{y * s}" r="5" fill="#444"{tag("town", t["id"], t["phase"])}/>')
        out.append(text(x * s, y * s - 9, t["name"], 13))
    for lm in world["landmarks"]:
        if lm.get("city"):
            continue
        x, y = lm["pos"]
        color = LANDMARK_ICON.get(lm["type"], "#555")
        mark = "?" if lm.get("secret") else ""
        out.append(f'<circle cx="{x * s}" cy="{y * s}" r="6" fill="{color}" stroke="#fff" stroke-width="1.5"{tag("landmark", lm["id"], _phase_of(world, lm))}/>')
        if mark:
            out.append(f'<text x="{x * s}" y="{y * s + 4}" font-size="10" fill="#fff" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-weight="700">?</text>')
        out.append(text(x * s, y * s + 19, lm["name"], 11, "500"))
    for r in world["regions"]:
        xs = [p[0] for p in r["polygon"]]
        ys = [p[1] for p in r["polygon"]]
        out.append(text(sum(xs) / len(xs) * s, sum(ys) / len(ys) * s, r["name"].upper(), 15, "700", "#4a4a3a"))
    for c in world["cities"]:
        x, y, cw, ch = c["rect"]
        out.append(text((x + cw / 2) * s, (y - 30) * s, f'{c["name"]} (phase {c["phase"]})', 20, "800", "#1d1d1d"))
    out.append(text(5600 * s, 5850 * s, "GULF OF SOLVERA", 22, "700", "#2f5f86"))
    out.append(_legend(10, h + 12))
    out.append("</svg>")
    return "\n".join(out)


def _region(r, s):
    return f'<polygon points="{pts(r["polygon"], s)}" fill="{REGION_FILL.get(r["type"], "#ccc")}" stroke="#fff" stroke-width="1.5" stroke-opacity="0.6"{tag("region", r["id"], r["phase"])}/>'


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


def _legend(x, y):
    items = [("highway", "Highway"), ("rail", "Rail"), ("streetcar", "Streetcar"), ("metro", "Metro / monorail"),
             ("ferry", "Ferry / cruise"), ("air", "Air route")]
    parts = []
    for i, (kind, label) in enumerate(items):
        color, width, dash = ROUTE_STYLE[kind]
        lx = x + i * 260
        bg = '<rect x="{0}" y="{1}" width="50" height="16" fill="#6fa8d6"/>'.format(lx, y + 2) if kind in ("ferry", "air") else ""
        dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
        parts.append(f'{bg}<line x1="{lx}" y1="{y + 10}" x2="{lx + 50}" y2="{y + 10}" stroke="{color}" stroke-width="{width}"{dash_attr}/>')
        parts.append(text(lx + 58, y + 15, label, 14, "500", anchor="start"))
    parts.append(text(x, y + 48, "? = secret / legend. Phase = build order (1 = MVP).", 14, "500", anchor="start"))
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
