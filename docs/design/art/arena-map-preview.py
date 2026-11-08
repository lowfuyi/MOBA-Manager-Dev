#!/usr/bin/env python3
"""Draws docs/design/art/arena-map-preview.svg (and .focus.svg) from game/data/arena_map.json.

Usage:  python3 docs/design/art/arena-map-preview.py [--flip]
Writes arena-map-preview.svg (full view, zoom 1.0) and arena-map-preview.focus.svg (zoom 1.3 on the map centre, which is
where the place-name labels are shown). --flip draws the picture for a player on the Red side (y mirrored).
Colour values are READ from docs/design/ART-BIBLE.md (tokens of 3.1 to 3.9); nothing is typed twice. Render to PNG with
any browser or rsvg; for the Barlow Semi Condensed face load the font files (they are not in the repo, see ART-BIBLE 5.1).
Strips follow UI-PASS-2 6.7.2: scoreboard 0 to 190, arena 190 to 950, text strip 950 to 1148, controls 1148 to 1280.
The header, text strip and buttons are placeholders for layout only."""
import json, math, pathlib, random, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
D = json.loads((ROOT / "game/data/arena_map.json").read_text())
BIBLE = (ROOT / "docs/design/ART-BIBLE.md").read_text()
FLIP = "--flip" in sys.argv

# ---- tokens from the bible ---------------------------------------------------------------------------------------
TOK = {}
for line in BIBLE.splitlines():
    m = re.match(r"^\|\s*`(\w+)`[^|]*\|\s*`?(#[0-9A-Fa-f]{6})`?", line)
    if m and m.group(1) not in TOK:
        TOK[m.group(1)] = m.group(2).lower()
m = re.search(r"^\|\s*Jungle\s*\|\s*`(#[0-9A-Fa-f]{6})`", BIBLE, re.M)
TOK["JUNGLE_RING"] = m.group(1).lower() if m else None
NEED = sorted(set(D["look"]["tokens"].values()) | {"BG", "PANEL", "PANEL2", "PANEL3", "DIM"})
missing = [n for n in NEED if not TOK.get(n)]
if missing:
    sys.exit(f"tokens not found in ART-BIBLE.md: {missing}")
T = lambda role: TOK[D["look"]["tokens"][role]]

W, H, OY = 720, 760, 190
LAY = D["arena"]["layout_px"]
nodes = {n["id"]: n for n in D["nodes"]}
FONT = "'Barlow Semi Condensed', Inter, Arial, sans-serif"
YOU, THEM = ("B", "R") if not FLIP else ("R", "B")


def f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")


def P(p, zoom=1.0, focus=(360, 380)):
    y = p[1] if not FLIP else 1 - p[1]
    return (p[0] * W, y * H)


def side_col(side):
    return T("plate_rim_you") if side == YOU else T("plate_rim_them")


def path_through(pts):
    out = [f"M{f(pts[0][0])} {f(pts[0][1])}"]
    for i in range(len(pts) - 1):
        p0 = pts[i - 1] if i > 0 else pts[i]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[i + 2] if i + 2 < len(pts) else pts[i + 1]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f"C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(p2[0])} {f(p2[1])}")
    return " ".join(out)


def sample_curve(pts, n=24):
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[i - 1] if i > 0 else pts[i]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[i + 2] if i + 2 < len(pts) else pts[i + 1]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        for k in range(n):
            t = k / n
            u = 1 - t
            out.append((u**3 * p1[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t**3 * p2[0],
                        u**3 * p1[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t**3 * p2[1]))
    out.append(pts[-1])
    return out


def build(zoom):
    o = []
    add = o.append
    lane_px = {l["id"]: [P(nodes[i]["p"]) for i in l["nodes"]] for l in D["lanes"]}
    mc = P(D["terrain"]["mere"]["c"])
    mr, ir = D["terrain"]["mere"]["r_px"], D["terrain"]["island"]["r_px"]
    c_you, c_them = T("plate_rim_you"), T("plate_rim_them")
    focus = (360, 380)
    cam = ""
    if zoom != 1.0:
        tx, ty = 360 - focus[0] * zoom, 380 - focus[1] * zoom
        tx, ty = min(0, max(W - W * zoom, tx)), min(0, max(H - H * zoom, ty))
        cam = f' transform="translate({f(tx)} {f(ty)}) scale({zoom})"'
    else:
        tx = ty = 0
    add(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 1280" width="720" height="1280" font-family="{FONT}">
<title>Wrenfell arena map preview (720 x 1280 phone, arena 720 x 760, camera zoom {zoom:g})</title>
<desc>Drawn from game/data/arena_map.json by arena-map-preview.py; colours are the ART-BIBLE tokens. You are a teal circle, them a coral flat-top hexagon, Stoneback a gold rhombus (the hexagon means "them"). Guard towers are dimmer: scenery, never counted. Labels are 24 px Bold with a 5 px VOID outline. Header, text strip and buttons are placeholders for layout only.</desc>
<defs>
  <radialGradient id="glowYou" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="{c_you}" stop-opacity="0.30"/><stop offset="0.6" stop-color="{c_you}" stop-opacity="0.10"/><stop offset="1" stop-color="{c_you}" stop-opacity="0"/></radialGradient>
  <radialGradient id="glowThem" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="{c_them}" stop-opacity="0.30"/><stop offset="0.6" stop-color="{c_them}" stop-opacity="0.10"/><stop offset="1" stop-color="{c_them}" stop-opacity="0"/></radialGradient>
  <radialGradient id="glowMoon" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="{T('moonhulk_disc')}" stop-opacity="0.40"/><stop offset="1" stop-color="{T('moonhulk_disc')}" stop-opacity="0"/></radialGradient>
  <radialGradient id="glowWarn" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="{T('stoneback')}" stop-opacity="0.40"/><stop offset="1" stop-color="{T('stoneback')}" stop-opacity="0"/></radialGradient>
  <filter id="soft" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="9"/></filter>
  <filter id="drop" x="-40%" y="-40%" width="180%" height="180%"><feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000" flood-opacity="0.55"/></filter>
  <clipPath id="arenaClip"><rect x="0" y="0" width="{W}" height="{H}"/></clipPath>
</defs>
<rect width="720" height="1280" fill="{TOK['BG']}"/>
''')
    add(f'<g transform="translate(0 {OY})"><g clip-path="url(#arenaClip)"><g{cam}>')
    add(f'<rect width="{W}" height="{H}" fill="{T("land")}"/>')
    for side in "BR":
        cx, cy = P(D["bases"][side]["cairn"])
        r = D["bases"][side]["yard_r_u"] * D["arena"]["unit_px"]
        add(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="url(#{"glowYou" if side == YOU else "glowThem"})"/>')
        add(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r*0.93)}" fill="none" stroke="{side_col(side)}" stroke-opacity="0.22" stroke-width="2" stroke-dasharray="3 9"/>')
    # jungle pockets: a soft tint of the jungle colour (baked art, 7 percent), tufts at 28 percent
    jr = TOK["JUNGLE_RING"]
    blobs = [((0.222, 0.60), 78, 128), ((0.222, 0.40), 78, 128), ((0.745, 0.60), 70, 128), ((0.745, 0.40), 70, 128)]
    for (c, rx, ry) in blobs:
        cx, cy = P(c)
        add(f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{rx}" ry="{ry}" fill="{jr}" opacity="0.07" filter="url(#soft)"/>')
    rnd = random.Random(11)
    for (c, rx, ry) in blobs[::2]:
        cx, cy = P(c)
        for _ in range(60):
            a, rr = rnd.random() * 6.283, math.sqrt(rnd.random())
            x, y = cx + math.cos(a) * rx * 0.85 * rr, cy + math.sin(a) * ry * 0.85 * rr
            for yy in (y, H - y):
                add(f'<circle cx="{f(x)}" cy="{f(yy)}" r="{rnd.choice([1.4, 1.8, 2.2])}" fill="#5fae7a" opacity="0.28"/>')
    # the Mere
    add(f'<circle cx="{f(mc[0])}" cy="{f(mc[1])}" r="{mr}" fill="{T("lake")}" stroke="{T("shore_stroke")}" stroke-width="3"/>')
    for rr, op in ((mr - 10, 0.35), (mr - 24, 0.22), (ir + 24, 0.22), (ir + 10, 0.30)):
        add(f'<circle cx="{f(mc[0])}" cy="{f(mc[1])}" r="{rr}" fill="none" stroke="{T("shore_stroke")}" stroke-opacity="{op}" stroke-width="1.5" stroke-dasharray="14 10"/>')
    # lanes: one road colour, 2 px edge lines at white 18 percent (ART-BIBLE 3.9)
    for lane in D["lanes"]:
        pts = lane_px[lane["id"]]
        pd_, w = path_through(pts), lane["width_px"]
        add(f'<path d="{pd_}" fill="none" stroke="#ffffff" stroke-opacity="0.18" stroke-width="{w + 4}" stroke-linecap="round" stroke-linejoin="round"/>')
        add(f'<path d="{pd_}" fill="none" stroke="{T("lane")}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>')
        if lane["id"] != "mid":
            add(f'<path d="{pd_}" fill="none" stroke="#ffffff" stroke-opacity="0.12" stroke-width="2" stroke-dasharray="10 12"/>')
        cur = sample_curve(pts, 40)
        acc, nxt = 0.0, 20
        step = 40 if lane["id"] != "mid" else 11
        for i in range(len(cur) - 1):
            a, b = cur[i], cur[i + 1]
            acc += math.hypot(b[0] - a[0], b[1] - a[1])
            if acc >= nxt:
                nxt += step
                t = (b[0] - a[0], b[1] - a[1])
                L = math.hypot(*t) or 1
                nx, ny = -t[1] / L, t[0] / L
                idx = int(nxt / step)
                if lane["id"] == "mid":
                    add(f'<path d="M{f(b[0] - nx * w / 2)} {f(b[1] - ny * w / 2)} L{f(b[0] + nx * w / 2)} {f(b[1] + ny * w / 2)}" stroke="#ffffff" stroke-opacity="0.10" stroke-width="1.5"/>')
                    continue
                for sgn in (-1, 1):
                    x, y = b[0] + nx * sgn * (w / 2 + 6), b[1] + ny * sgn * (w / 2 + 6)
                    if lane["id"] == "bot":
                        if sgn == 1 and idx % 2 == 0:
                            continue
                        add(f'<circle cx="{f(x)}" cy="{f(y)}" r="3" fill="{T("label")}" opacity="0.30"/>')
                    elif (idx + (sgn > 0)) % 2 == 0:
                        add(f'<path d="M{f(x)} {f(y + 4)} l-3 -9 M{f(x)} {f(y + 4)} l0 -11 M{f(x)} {f(y + 4)} l3 -9" stroke="#7bb86f" stroke-width="2" stroke-linecap="round" fill="none" opacity="0.30"/>')
    # island over the causeway
    add(f'<circle cx="{f(mc[0])}" cy="{f(mc[1])}" r="{ir}" fill="{T("plaza")}" stroke="{T("shore_stroke")}" stroke-width="3"/>')
    add(f'<circle cx="{f(mc[0])}" cy="{f(mc[1])}" r="{ir - 12}" fill="none" stroke="{T("moonhulk_disc")}" stroke-opacity="0.30" stroke-width="1.5" stroke-dasharray="4 7"/>')
    for ang in range(0, 360, 45):
        add(f'<circle cx="{f(mc[0] + math.cos(math.radians(ang)) * (ir - 5))}" cy="{f(mc[1] + math.sin(math.radians(ang)) * (ir - 5))}" r="2.6" fill="{T("moonhulk_disc")}" opacity="0.45"/>')
    # plazas
    for side in "BR":
        cx, cy = P((0.5, 0.875 if side == "B" else 0.125))
        add(f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="196" ry="80" fill="{T("plaza")}" stroke="{side_col(side)}" stroke-opacity="0.45" stroke-width="3"/>')
        add(f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="182" ry="67" fill="none" stroke="#ffffff" stroke-opacity="0.07" stroke-width="2" stroke-dasharray="6 8"/>')
    # jungle trails
    lane_pairs = {frozenset(p) for l in D["lanes"] for p in zip(l["nodes"], l["nodes"][1:])}
    for e in D["edges"]:
        if frozenset((e["a"], e["b"])) in lane_pairs or "spawn" in e["a"] or "spawn" in e["b"] or e["a"].endswith("cairn") or e["b"].endswith("cairn"):
            continue
        a, b = P(nodes[e["a"]]["p"]), P(nodes[e["b"]]["p"])
        add(f'<path d="M{f(a[0])} {f(a[1])} L{f(b[0])} {f(b[1])}" stroke="#a8d8c0" stroke-opacity="0.30" stroke-width="3" stroke-dasharray="2 8" stroke-linecap="round"/>')
    # spawn pads
    for side in "BR":
        for slot, p in D["spawns"][side].items():
            if slot != "pad_r_px":
                x, y = P(p)
                add(f'<circle cx="{f(x)}" cy="{f(y)}" r="{D["spawns"]["pad_r_px"]}" fill="{side_col(side)}" fill-opacity="0.10" stroke="{side_col(side)}" stroke-opacity="0.55" stroke-width="2" stroke-dasharray="4 5"/>')

    plate, ink = T("plate"), T("label")

    def tower(x, y, side, guard):
        col = side_col(side)
        s = (f'<g opacity="{D["look"]["guard_tower_opacity"]}">' if guard else "<g>")
        s += f'<circle cx="{f(x)}" cy="{f(y)}" r="12.5" fill="{plate}" stroke="{col}" stroke-width="3" filter="url(#drop)"/>'
        s += (f'<g transform="translate({f(x)} {f(y + 1)})"><path d="M-4.5 8 L-3.4 -2 L3.4 -2 L4.5 8 Z" fill="{ink}"/>'
              f'<path d="M-6 -2 L-6 -9 L-3 -9 L-3 -6 L-1.2 -6 L-1.2 -9 L1.2 -9 L1.2 -6 L3 -6 L3 -9 L6 -9 L6 -2 Z" fill="{ink}"/>'
              f'<rect x="-1.4" y="1" width="2.8" height="4.2" rx="1.2" fill="{col}"/></g></g>')
        return s

    def cairn(x, y, side):
        col = side_col(side)
        s = f'<circle cx="{f(x)}" cy="{f(y)}" r="50" fill="url(#{"glowYou" if side == YOU else "glowThem"})"/>'
        s += f'<circle cx="{f(x)}" cy="{f(y)}" r="22.3" fill="{plate}" stroke="{col}" stroke-width="3.5" filter="url(#drop)"/>'
        s += (f'<g transform="translate({f(x)} {f(y)})"><ellipse cx="0" cy="10" rx="14" ry="5.6" fill="{T("moonhulk_disc")}"/><ellipse cx="0" cy="2" rx="10.5" ry="4.8" fill="{T("moonhulk_disc")}"/>'
              f'<ellipse cx="0" cy="-5.5" rx="7" ry="3.8" fill="{ink}"/><ellipse cx="0" cy="-11" rx="3.8" ry="2.8" fill="{ink}"/>'
              f'<circle cx="0" cy="-15.5" r="1.9" fill="{col}"/></g>')
        return s

    def stoneback(x, y):
        w = T("stoneback")
        pts = f"{f(x)},{f(y - 22.5)} {f(x + 20.5)},{f(y)} {f(x)},{f(y + 22.5)} {f(x - 20.5)},{f(y)}"
        s = f'<circle cx="{f(x)}" cy="{f(y)}" r="52" fill="url(#glowWarn)"/>'
        s += f'<polygon points="{pts}" fill="{plate}" stroke="{w}" stroke-width="3.5" stroke-linejoin="round" filter="url(#drop)"/>'
        # shell mark: a half-circle fan
        s += f'<g transform="translate({f(x)} {f(y + 7)})" stroke="{w}" stroke-width="2" stroke-linecap="round" fill="none"><path d="M-9 0 A9 9 0 0 1 9 0 Z" stroke-linejoin="round"/>'
        for a in (-60, -30, 0, 30, 60):
            s += f'<path d="M0 0 L{f(9 * math.sin(math.radians(a)))} {f(-9 * math.cos(math.radians(a)))}"/>'
        s += '</g>'
        return s

    def moonhulk(x, y):
        s = f'<circle cx="{f(x)}" cy="{f(y)}" r="70" fill="url(#glowMoon)"/>'
        s += f'<circle cx="{f(x)}" cy="{f(y)}" r="22.3" fill="{plate}" stroke="{T("moonhulk_disc")}" stroke-width="3.5" filter="url(#drop)"/>'
        s += (f'<g transform="translate({f(x)} {f(y)})"><circle cx="0" cy="0" r="13" fill="{T("moonhulk_crescent")}"/>'
              f'<circle cx="6.5" cy="-3.5" r="11.5" fill="{plate}"/></g>')
        return s

    def camp(x, y, kind):
        s = ""
        if kind == "moss":
            s = f'<circle cx="{f(x)}" cy="{f(y)}" r="11" fill="{plate}" stroke="{jr}" stroke-width="2" filter="url(#drop)"/>'
            s += f'<path d="M{f(x - 5)} {f(y + 4)} Q{f(x - 6)} {f(y - 6)} {f(x + 5)} {f(y - 6)} Q{f(x + 6)} {f(y + 5)} {f(x - 5)} {f(y + 4)} Z" fill="{jr}"/><path d="M{f(x - 5)} {f(y + 5)} L{f(x + 2)} {f(y - 2)}" stroke="{plate}" stroke-width="1.4"/>'
        elif kind == "bramble":
            s = f'<circle cx="{f(x)}" cy="{f(y)}" r="13" fill="{plate}" stroke="{jr}" stroke-width="2" filter="url(#drop)"/>'
            g = "".join(f'<path d="M{f(x - 8 * math.cos(math.radians(a)))} {f(y - 8 * math.sin(math.radians(a)))} L{f(x + 8 * math.cos(math.radians(a)))} {f(y + 8 * math.sin(math.radians(a)))}"/>' for a in range(0, 180, 45))
            s += f'<g stroke="{jr}" stroke-width="2.4" stroke-linecap="round">{g}</g><circle cx="{f(x)}" cy="{f(y)}" r="2.4" fill="{plate}" stroke="{jr}" stroke-width="1.5"/>'
        else:
            s = f'<circle cx="{f(x)}" cy="{f(y)}" r="16.5" fill="{plate}" stroke="{jr}" stroke-width="3" filter="url(#drop)"/>'
            s += (f'<g transform="translate({f(x)} {f(y + 2)})"><path d="M-10 6 Q-10 -9 0 -9 Q10 -9 10 6 Z" fill="{jr}"/>'
                  f'<path d="M-5 6 L-5 -1 M0 6 L0 -4 M5 6 L5 -1" stroke="{plate}" stroke-width="1.8" stroke-linecap="round"/></g>')
        return s

    def hero(x, y, side, letter):
        rim = T("hero_rim")
        if side == YOU:
            shape = f'<circle cx="{f(x)}" cy="{f(y)}" r="18.5" fill="{T("hero_you")}" stroke="{rim}" stroke-opacity="0.7" stroke-width="3"/>'
            colour = T("hero_ink_you") if False else TOK[D["look"]["tokens"]["hero_ink_you"]]
        else:
            hexa = " ".join(f"{f(x + 20.5 * math.cos(math.radians(a)))},{f(y + 20.5 * math.sin(math.radians(a)))}" for a in range(0, 360, 60))
            shape = f'<polygon points="{hexa}" fill="{T("hero_them")}" stroke="{rim}" stroke-opacity="0.7" stroke-width="3" stroke-linejoin="round"/>'
            colour = TOK[D["look"]["tokens"]["hero_ink_them"]]
        return f'<g filter="url(#drop)">{shape}</g><text x="{f(x)}" y="{f(y + 8.4)}" text-anchor="middle" font-size="24" font-weight="700" fill="{colour}">{letter}</text>'

    for t in D["towers"]:
        x, y = P(t["p"])
        add(tower(x, y, t["side"], t["tier"] == "guard"))
    for c in D["camps"]:
        x, y = P(c["p"])
        add(camp(x, y, c["kind"] if c["kind"] != "mossback" else "mossback"))
    for ob in D["objectives"]:
        x, y = P(ob["p"])
        add(stoneback(x, y) if ob["id"] == "N.stoneback" else moonhulk(x, y) if ob["id"] == "N.moonhulk" else cairn(x, y, ob["side"]))
    letters = {"top": "T", "jg": "J", "mid": "M", "bot": "B", "sup": "S"}
    for side in "BR":
        for slot in ("top", "jg", "mid", "bot", "sup"):
            x, y = P(D["spawns"][side][slot])
            add(hero(x, y, side, letters[slot]))
    add('</g>')   # end camera group

    # labels: screen space, 24 px Bold, +1.5 px tracking, TEXT with a 5 px VOID outline; the camera moves their anchor only
    lb = D["labels"]
    fnt = lb["font"]
    for lab in lb["items"]:
        if zoom not in lab.get("zooms", [1.0]) and not (zoom >= lb.get("place_show_from_zoom", 9) and lab["kind"] == "place"):
            continue
        cx, cy = P(lab["c"])
        sx, sy = cx * zoom + tx, cy * zoom + ty
        half_w = (lab["w_px"] + fnt["outline"]["px"]) / 2
        if sx - half_w < 4 or sx + half_w > W - 4:
            continue            # rule: a label that does not fit wholly inside the camera window is hidden
        add(f'<text x="{f(sx)}" y="{f(sy + 8.4)}" text-anchor="middle" font-size="{fnt["size_px"]}" font-weight="700" letter-spacing="{fnt["tracking_px"]}" '
            f'fill="{T("label")}" stroke="{T("label_outline")}" stroke-width="{fnt["outline"]["px"]}" paint-order="stroke" stroke-linejoin="round">{lab["text"]}</text>')
    add('</g>')
    add(f'<rect x="0.5" y="0.5" width="{W - 1}" height="{H - 1}" fill="none" stroke="#ffffff" stroke-opacity="0.08"/></g>')

    # ---- placeholder chrome (layout only)
    PA, PA2 = TOK["PANEL"], TOK["PANEL2"]
    tx_, dim, txt2 = T("label"), TOK["DIM"], TOK["TEXT2"]
    ty0, ty1 = LAY["feed_y"]
    cy0, cy1 = LAY["controls_y"]

    def glyph(x, y, side):
        if side == "you":
            return f'<circle cx="{x}" cy="{y}" r="8" fill="{c_you}"/>'
        hexa = " ".join(f"{f(x + 9 * math.cos(math.radians(a)))},{f(y + 9 * math.sin(math.radians(a)))}" for a in range(0, 360, 60))
        return f'<polygon points="{hexa}" fill="{c_them}"/>'

    add(f'''<g id="chrome-placeholder" font-family="{FONT}">
  <rect x="24" y="48" width="672" height="132" rx="20" fill="{PA2}" stroke="#ffffff" stroke-opacity="0.07"/>
  {glyph(52, 80, "you")}<text x="70" y="88" font-size="26" font-weight="600" fill="{tx_}">Corsairs</text>
  {glyph(668, 80, "them")}<text x="648" y="88" font-size="26" font-weight="600" fill="{tx_}" text-anchor="end">Wardens</text>
  <text x="360" y="92" font-size="32" font-weight="700" fill="{tx_}" text-anchor="middle">05:12</text>
  <text x="44" y="136" font-size="32" font-weight="600" fill="{tx_}">3</text><text x="676" y="136" font-size="32" font-weight="600" fill="{tx_}" text-anchor="end">2</text>
  <rect x="44" y="152" width="632" height="14" rx="7" fill="{plate}"/><rect x="44" y="152" width="372" height="14" rx="7" fill="{c_you}"/>
  <rect x="24" y="{ty0 + 8}" width="360" height="44" rx="22" fill="{TOK['PANEL3']}"/><text x="204" y="{ty0 + 38}" font-size="24" font-weight="600" fill="{tx_}" text-anchor="middle">Group up, Contest them</text>
  <rect x="396" y="{ty0 + 8}" width="150" height="44" rx="22" fill="{PA2}"/><text x="471" y="{ty0 + 38}" font-size="24" font-weight="600" fill="{txt2}" text-anchor="middle">If behind</text>
  {glyph(40, ty0 + 84, "you")}<text x="60" y="{ty0 + 92}" font-size="24" font-weight="600" fill="{tx_}">Going for Stoneback</text>
  {glyph(676, ty0 + 84, "them")}<text x="654" y="{ty0 + 92}" font-size="24" font-weight="600" fill="{tx_}" text-anchor="end">Chip from range</text>
  {glyph(40, ty0 + 128, "you")}<text x="60" y="{ty0 + 136}" font-size="26" font-weight="500" fill="{tx_}">Top lane: you win it</text>
  {glyph(40, ty0 + 166, "them")}<text x="60" y="{ty0 + 174}" font-size="26" font-weight="500" fill="{dim}">Mid lane: they win it</text>
  <text x="696" y="{ty1 - 14}" font-size="24" fill="{dim}" text-anchor="end" opacity="0">.</text>
  <rect x="24" y="{cy0 + 12}" width="250" height="96" rx="20" fill="{PA2}" stroke="#ffffff" stroke-opacity="0.07"/><text x="149" y="{cy0 + 72}" font-size="32" font-weight="600" fill="{tx_}" text-anchor="middle">Speed x1</text>
  <rect x="290" y="{cy0 + 12}" width="320" height="96" rx="20" fill="{PA2}" stroke="#ffffff" stroke-opacity="0.07"/><text x="450" y="{cy0 + 72}" font-size="32" font-weight="600" fill="{tx_}" text-anchor="middle">Skip to the end</text>
  <rect x="626" y="{cy0 + 12}" width="70" height="96" rx="20" fill="{PA2}" stroke="#ffffff" stroke-opacity="0.07"/><text x="661" y="{cy0 + 72}" font-size="32" font-weight="600" fill="{tx_}" text-anchor="middle">?</text>
  <path d="M0 {ty1}.5 H720 M0 {cy0}.5 H720" stroke="#ffffff" stroke-opacity="0.0"/>
</g>
</svg>''')
    return "\n".join(o)


out = pathlib.Path(__file__).resolve().parent
suffix = ".flipped" if FLIP else ""
(out / f"arena-map-preview{suffix}.svg").write_text(build(1.0))
(out / f"arena-map-preview{suffix}.focus.svg").write_text(build(1.3))
print("wrote", out / f"arena-map-preview{suffix}.svg", "and .focus.svg; tokens:", {k: TOK[k] for k in NEED})
