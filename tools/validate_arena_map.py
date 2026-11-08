#!/usr/bin/env python3
"""Validate game/data/arena_map.json (the live-match arena, docs/design/ARENA-MAP.md).

Usage:  python3 tools/validate_arena_map.py [path-to-arena_map.json] [--report]
Exit code 0 when every check passes, 1 when any check fails, 2 when the file cannot be read.

What it checks (each line of output is one check):
  structure      required keys, schema version, icon and layout sizes
  ids            ids are unique and every reference (edge, lane, tower, camp, zone, stage) resolves
  range          every coordinate is in 0..1, icons keep the safe margin, zones stay on the arena
  mirror         every Blue (B) object has a Red (R) twin at (x, 1 - y); neutral (N) objects sit on y = 0.5
  lanes          each lane runs from the Blue base yard to the Red base yard, one step at a time along real
                 edges, never backwards, and the whole graph is connected
  spawns         all five slots (top, jg, mid, bot, sup) have a spawn on each side, inside the base yard
  towers         two lane towers per lane per side plus two gate towers, on their lane, on land
  camps          jungle camps per pocket and side, off the lanes and off the water
  water          nothing is placed in the lake except on the island; only bridge edges cross the lake
  spacing        no two icons overlap at the real pixel size (720 x 760 arena)
  stages         every simulated contest has a place and a time, and the walk fits in the time before it
  units          body width (hero range unit) agrees with the pixel and map-unit conversions in the doc
  tally          the scoreboard counts 6 towers per side; the 2 guard towers are scenery and fall only in the closing push
  variants       the 'held fight' stagings for the game winner losing fight_late, plus the clean_gate formation for
                 the 81 percent case (game winner also wins it): tokens fit and do not overlap, walks fit their clock,
                 the timeline ends with the Cairn falling
  look           ART-BIBLE token names only (no ARENA_* placeholders), the side shapes (circle you, hexagon them,
                 never a hexagon for an objective), Stoneback is a rhombus
  labels         map labels are 24 px; no label touches a lane (other than its own), camp, tower, objective, pad,
                 another label or the arena edge; labels crossing the lake or island rim are reported
  walks          walks that start in the lanes and at the tower sites (lane position at the largest clash shift),
                 with the legs that must pass and the legs that are asserted to fail

Also lints docs/design/ARENA-MAP.md (no ARENA_* placeholders, rhombus, 198 and 132 px strips).
Other modes:  --selftest   builds broken copies in memory and checks each one trips the check it targets
              --doc PATH   the ARENA-MAP.md to lint (default docs/design/ARENA-MAP.md)

Standard library only. Distances use map units: 1 unit = arena.unit_px (760 px) and dx is scaled by x_scale.
"""
import heapq
import json
import math
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT = ROOT / "game/data/arena_map.json"
SLOTS = ["top", "jg", "mid", "bot", "sup"]
SIM_CONTESTS = ["top", "mid_lane", "bot", "jungle", "obj_mid", "fight_mid", "obj_late", "fight_late"]
TOL = 0.001            # mirror tolerance in normalised units (0.7 px)
TRAVEL_MARGIN_S = 1.0  # a group must arrive at least this long before its contest is shown
SAMPLE_PX = 4.0
RANGE_BODY_WIDTHS = {"melee": 1, "mid": 3, "long": 5}   # ACTION-VOCABULARY 3.1
SCOREBOARD_TOWERS_PER_SIDE = 6                           # ACTION-VOCABULARY 5.1 F8 (C5 ruling)
LEG_ACTORS = ("W_heroes", "U_heroes", "lead_pack")

EXPECTED_STRIPS = {"scoreboard_y": [0, 190], "arena_y": [190, 950], "feed_y": [950, 1148], "controls_y": [1148, 1280]}
# UI-PASS-2 6.7.2 (P1 ruling): text strip 44 + 8 + 48 + 8 + 80 + 10 = 198; controls 12 + 96 + 24 = 132
MIN_TEXT_STRIP_H, MIN_CONTROLS_H = 198, 132
LABEL_MIN_PX = 24                                        # ART-BIBLE 5.2: the floor
LABEL_OUTLINE_PX = 5                                     # ART-BIBLE 3.9: 5 px VOID outline
LABEL_GAP_PX = 2                                         # clear space between a label box and anything else
DOC_DEFAULT = ROOT / "docs/design/ARENA-MAP.md"
# token names of ART-BIBLE 3.1 to 3.9 (values are owned by the bible, never copied here)
BIBLE_TOKENS = {"VOID", "BG", "BG_GLOW", "PANEL", "PANEL2", "PANEL3", "LINE", "LINE_HI", "TEXT", "TEXT2", "DIM", "TEXT_OFF",
                "INK_TEAL", "INK_CORAL", "ACCENT", "TEAL_HI", "TEAL_LO", "TEAL_DEEP", "CORAL", "CORAL_HI", "CORAL_LO", "WARN",
                "GOOD", "BAD", "GOOD_CB", "BAD_CB", "SIDE_BLUE", "SIDE_RED", "MAP_LAND", "MAP_MERE", "MAP_SHORE"}
UNNAMED_IN_BIBLE = {"JUNGLE_RING"}                       # the Jungle role ring colour (bible 3.5) has no constant name yet
NEVER_ON_MAP = {"BAD", "BAD_CB", "GOOD", "GOOD_CB", "SIDE_BLUE", "SIDE_RED", "BLUE", "RED"}
EXPECTED_TOKENS = {"land": "MAP_LAND", "lake": "MAP_MERE", "shore_stroke": "MAP_SHORE", "lane": "PANEL3", "plaza": "PANEL2",
                   "plate": "VOID", "plate_rim_you": "ACCENT", "plate_rim_them": "CORAL", "camp": "JUNGLE_RING",
                   "moonhulk_disc": "TEXT2", "moonhulk_crescent": "TEXT", "stoneback": "WARN", "label": "TEXT",
                   "label_outline": "VOID", "hero_you": "ACCENT", "hero_them": "CORAL", "hero_rim": "TEXT",
                   "hero_ink_you": "INK_TEAL", "hero_ink_them": "INK_CORAL"}

REQUIRED = ["schema", "schema_version", "map_version", "arena", "view", "icons_px", "speeds", "watch_seconds", "camera",
            "terrain", "bases", "nodes", "edges", "lanes", "towers", "camps", "objectives", "spawns", "zones", "stages",
            "units", "tower_tally", "late_fight_variants", "look", "labels", "walk_legs", "clash_rule"]


class Ctx:
    def __init__(self, d):
        self.d = d
        a = d["arena"]
        self.w, self.h = float(a["px"][0]), float(a["px"][1])
        self.xs = float(a["x_scale"])
        self.unit = float(a["unit_px"])
        self.nodes = {n["id"]: n for n in d["nodes"]}
        self.mere = d["terrain"]["mere"]
        self.island = d["terrain"]["island"]

    def px(self, p):
        return (p[0] * self.w, p[1] * self.h)

    def dist_u(self, a, b):
        return math.hypot((a[0] - b[0]) * self.xs, a[1] - b[1])

    def dist_px(self, a, b):
        return math.hypot((a[0] - b[0]) * self.w, (a[1] - b[1]) * self.h)

    def in_water(self, p, margin_px=0.0):
        """inside the Mere but outside the island (margin_px grows the water, shrinks the island)"""
        c = self.px(self.mere["c"])
        q = self.px(p)
        in_mere = math.hypot(q[0] - c[0], q[1] - c[1]) <= float(self.mere["r_px"]) + margin_px
        ci = self.px(self.island["c"])
        on_island = math.hypot(q[0] - ci[0], q[1] - ci[1]) <= float(self.island["r_px"]) - margin_px
        return in_mere and not on_island

    def graph(self):
        adj = {n: [] for n in self.nodes}
        for e in self.d["edges"]:
            if e["a"] in self.nodes and e["b"] in self.nodes:
                w = self.dist_u(self.nodes[e["a"]]["p"], self.nodes[e["b"]]["p"])
                adj[e["a"]].append((e["b"], w))
                adj[e["b"]].append((e["a"], w))
        return adj

    def shortest(self, src):
        adj = self.graph()
        dist = {src: 0.0}
        pq = [(0.0, src)]
        while pq:
            c, u = heapq.heappop(pq)
            if c > dist.get(u, 1e18):
                continue
            for v, w in adj.get(u, []):
                if c + w < dist.get(v, 1e18):
                    dist[v] = c + w
                    heapq.heappush(pq, (c + w, v))
        return dist


def side_of(entity_id):
    """('B', key) for 'B.top.outer' or 'thicket.B'; ('N', key) for neutral"""
    if entity_id[:2] in ("B.", "R.", "N."):
        return entity_id[0], entity_id[2:]
    if entity_id[-2:] in (".B", ".R"):
        return entity_id[-1], entity_id[:-2]
    return "N", entity_id


def swap_id(entity_id):
    if entity_id[:2] in ("B.", "R."):
        return ("R" if entity_id[0] == "B" else "B") + entity_id[1:]
    if entity_id[-2:] in (".B", ".R"):
        return entity_id[:-1] + ("R" if entity_id[-1] == "B" else "B")
    return entity_id


def seg_dist_px(ctx, p, a, b):
    px, py = ctx.px(p)
    ax, ay = ctx.px(a)
    bx, by = ctx.px(b)
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def poly_dist_px(ctx, p, poly):
    return min(seg_dist_px(ctx, p, poly[i], poly[i + 1]) for i in range(len(poly) - 1))


def lane_poly(ctx, lane):
    return [ctx.nodes[i]["p"] for i in lane["nodes"]]


def arc_fraction_point(ctx, poly, s):
    seg = [ctx.dist_u(poly[i], poly[i + 1]) for i in range(len(poly) - 1)]
    total = sum(seg)
    target = s * total
    acc = 0.0
    for i, d in enumerate(seg):
        if acc + d >= target - 1e-12:
            t = (target - acc) / d if d else 0.0
            return [poly[i][0] + (poly[i + 1][0] - poly[i][0]) * t, poly[i][1] + (poly[i + 1][1] - poly[i][1]) * t]
        acc += d
    return poly[-1]


def icon_px_for(d, kind, entity=None):
    ic = d["icons_px"]
    if kind == "tower":
        return ic["tower"]
    if kind == "camp":
        return ic.get("camp_" + entity.get("kind", ""), ic.get("mossback") if entity.get("kind") == "mossback" else ic["camp_moss"])
    if kind == "objective":
        return entity.get("icon_px", 48)
    if kind == "spawn":
        return ic["hero"]
    return 24


# --------------------------------------------------------------------------- checks
# each check returns a list of problem strings; an empty list is a pass

def check_structure(ctx):
    d, errs = ctx.d, []
    for k in REQUIRED:
        if k not in d:
            errs.append(f"missing key '{k}'")
    if errs:
        return errs
    if d["schema"] != "moba-manager/arena-map":
        errs.append(f"schema is '{d['schema']}', expected 'moba-manager/arena-map'")
    if d["schema_version"] != 1:
        errs.append(f"schema_version {d['schema_version']} is not supported by this validator (1)")
    if [ctx.w, ctx.h] != [720.0, 760.0]:
        errs.append(f"arena.px is {d['arena']['px']}, the design size is [720, 760]")
    if abs(ctx.xs - ctx.w / ctx.h) > 0.001:
        errs.append(f"x_scale {ctx.xs} should equal px width / height = {ctx.w / ctx.h:.4f}")
    lay = d["arena"].get("layout_px", {})
    try:
        if lay["arena_y"][1] - lay["arena_y"][0] != int(ctx.h):
            errs.append("layout_px.arena_y is not as tall as the arena")
        if not (lay["scoreboard_y"][1] <= lay["arena_y"][0] and lay["arena_y"][1] <= lay["feed_y"][0]
                and lay["feed_y"][1] <= lay["controls_y"][0] and lay["controls_y"][1] <= lay["screen"][1]):
            errs.append("layout strips overlap or run off the 1280 px screen")
        for k, want in EXPECTED_STRIPS.items():
            if lay[k] != want:
                errs.append(f"layout_px.{k} is {lay[k]}, UI-PASS-2 6.7.2 (ruling P1) has {want}")
        if lay["feed_y"][1] - lay["feed_y"][0] < MIN_TEXT_STRIP_H:
            errs.append(f"text strip is {lay['feed_y'][1] - lay['feed_y'][0]} px, it needs {MIN_TEXT_STRIP_H} (44 + 8 + 48 + 8 + 80 + 10)")
        if lay["controls_y"][1] - lay["controls_y"][0] < MIN_CONTROLS_H:
            errs.append(f"controls strip is {lay['controls_y'][1] - lay['controls_y'][0]} px, it needs {MIN_CONTROLS_H} (12 + 96 + 24)")
        if lay["feed_y"][1] != lay["controls_y"][0] or lay["arena_y"][1] != lay["feed_y"][0] or lay["controls_y"][1] != lay["screen"][1]:
            errs.append("layout strips must touch: arena, text strip and controls fill the screen with no gap")
    except (KeyError, TypeError, IndexError):
        errs.append("arena.layout_px is incomplete")
    for name, v in d["icons_px"].items():
        if not 24 <= v <= 48:
            errs.append(f"icon '{name}' is {v} px, the readable range is 24 to 48")
    sp = d["speeds"]
    if not (0.01 <= sp.get("walk_u_s", 0) <= 0.2):
        errs.append("speeds.walk_u_s must be between 0.01 and 0.2 map units per second")
    if sp.get("rotate_mult", 0) < 1 or sp.get("rush_mult", 0) < sp.get("rotate_mult", 1):
        errs.append("speeds: rotate_mult must be >= 1 and rush_mult >= rotate_mult")
    if d["watch_seconds"] != 75:
        errs.append(f"watch_seconds is {d['watch_seconds']}, the Founder decision is 75")
    cam = d["camera"]
    z = cam.get("focus", {}).get("max_zoom", 0)
    if not 1.0 <= z <= 1.5:
        errs.append(f"camera.focus.max_zoom {z} must be between 1.0 and 1.5")
    if cam.get("default", {}).get("zoom") != 1.0 or cam.get("default", {}).get("pan"):
        errs.append("camera.default must be zoom 1.0 without pan (the whole map is always visible)")
    if not d["view"].get("player_team_at_bottom") or d["view"].get("flip") != "y" or not d["view"].get("keep_x"):
        errs.append("view must put the player's team at the bottom by a y flip that keeps x")
    return errs


def check_ids(ctx):
    d, errs = ctx.d, []
    for coll in ("nodes", "towers", "camps", "zones", "objectives"):
        seen = set()
        for e in d[coll]:
            if e["id"] in seen:
                errs.append(f"{coll}: duplicate id {e['id']}")
            seen.add(e["id"])
    zone_ids = {z["id"] for z in d["zones"]}
    for e in d["edges"]:
        for end in ("a", "b"):
            if e[end] not in ctx.nodes:
                errs.append(f"edge {e['a']} - {e['b']}: unknown node {e[end]}")
    for lane in d["lanes"]:
        for n in lane["nodes"]:
            if n not in ctx.nodes:
                errs.append(f"lane {lane['id']}: unknown node {n}")
    lane_ids = {l["id"] for l in d["lanes"]}
    for t in d["towers"]:
        if t["lane"] not in lane_ids and t["lane"] != "base":
            errs.append(f"tower {t['id']}: unknown lane {t['lane']}")
    for c in d["camps"]:
        if c["node"] not in ctx.nodes:
            errs.append(f"camp {c['id']}: unknown node {c['node']}")
    for o in d["objectives"]:
        if o["node"] not in ctx.nodes:
            errs.append(f"objective {o['id']}: unknown node {o['node']}")
        if o["zone"] not in zone_ids:
            errs.append(f"objective {o['id']}: unknown zone {o['zone']}")
    for s in d["stages"]:
        for zref in (s["zone"] if isinstance(s["zone"], list) else [s["zone"]]):
            names = [zref[:-2] + ".B", zref[:-2] + ".R"] if zref.endswith(".*") else [zref]
            for zn in names:
                if zn not in zone_ids:
                    errs.append(f"stage {s['contest']}: unknown zone {zn}")
        for tr in s.get("travel", []):
            for k in ("from", "to"):
                if tr[k] not in ctx.nodes:
                    errs.append(f"stage {s['contest']}: travel {k} node {tr[k]} unknown")
    for side in "BR":
        if d["bases"][side]["gate_node"] not in ctx.nodes:
            errs.append(f"bases.{side}.gate_node unknown")
    return errs


def _all_points(d):
    for n in d["nodes"]:
        yield f"node {n['id']}", n["p"]
    for k in ("towers", "camps", "objectives"):
        for e in d[k]:
            yield f"{k[:-1]} {e['id']}", e["p"]
    for side in "BR":
        for slot, p in d["spawns"][side].items():
            yield f"spawn {side}.{slot}", p
        yield f"cairn {side}", d["bases"][side]["cairn"]
    for z in d["zones"]:
        yield f"zone {z['id']}", z["c"]
    for a in d.get("areas", []):
        yield f"area {a['id']}", a["p"]
    yield "mere", d["terrain"]["mere"]["c"]
    yield "island", d["terrain"]["island"]["c"]


def check_range(ctx):
    d, errs = ctx.d, []
    mx, my = d["arena"]["safe_margin"]
    for label, p in _all_points(d):
        if len(p) != 2 or not all(isinstance(v, (int, float)) and math.isfinite(v) for v in p):
            errs.append(f"{label}: not a coordinate pair: {p}")
            continue
        if not (0.0 <= p[0] <= 1.0 and 0.0 <= p[1] <= 1.0):
            errs.append(f"{label}: {p} is outside 0..1")
        elif not label.startswith(("area", "zone")) and not (mx <= p[0] <= 1 - mx and my <= p[1] <= 1 - my):
            errs.append(f"{label}: {p} is inside the safe margin {mx}/{my} (icon would touch the arena edge)")
    for z in d["zones"]:
        cx, cy = ctx.px(z["c"])
        r = z["r_px"]
        if cx - r < 0 or cx + r > ctx.w or cy - r < 0 or cy + r > ctx.h:
            errs.append(f"zone {z['id']}: circle leaves the arena")
    return errs


def _mirror_ok(a, b):
    return abs(a[0] - b[0]) <= TOL and abs(a[1] - (1.0 - b[1])) <= TOL


def check_mirror(ctx):
    d, errs = ctx.d, []

    def pair_up(coll, items, posf=lambda e: e["p"], extra=()):
        by = {}
        for e in items:
            s, k = side_of(e["id"])
            by.setdefault(k, {})[s] = e
        for k, sides in by.items():
            if "N" in sides:
                if len(sides) > 1:
                    errs.append(f"{coll}: '{k}' is neutral and also has a side twin")
                if abs(posf(sides["N"])[1] - 0.5) > TOL:
                    errs.append(f"{coll}: neutral '{k}' is at y={posf(sides['N'])[1]}, must be 0.5")
                continue
            if "B" not in sides or "R" not in sides:
                errs.append(f"{coll}: '{k}' has no {'R' if 'B' in sides else 'B'} twin")
                continue
            if not _mirror_ok(posf(sides["B"]), posf(sides["R"])):
                errs.append(f"{coll}: {sides['B']['id']} {posf(sides['B'])} and {sides['R']['id']} {posf(sides['R'])} are not mirrors")
            for f in extra:
                if sides["B"].get(f) != sides["R"].get(f):
                    errs.append(f"{coll}: '{k}' differs between sides in '{f}'")

    pair_up("nodes", d["nodes"], extra=("kind",))
    pair_up("towers", d["towers"], extra=("lane", "tier"))
    pair_up("camps", d["camps"], extra=("kind", "pocket"))
    pair_up("zones", d["zones"], posf=lambda e: e["c"], extra=("r_px", "kind"))
    pair_up("objectives", d["objectives"], extra=("kind",))
    for t in d["towers"]:
        if t.get("s") is not None:
            twin = next((x for x in d["towers"] if x["id"] == swap_id(t["id"])), None)
            if twin and twin.get("s") is not None and abs(t["s"] + twin["s"] - 1.0) > 0.0005:
                errs.append(f"tower {t['id']}: s {t['s']} and twin s {twin['s']} do not add to 1")
    for slot in SLOTS:
        pb, pr = d["spawns"]["B"].get(slot), d["spawns"]["R"].get(slot)
        if pb and pr and not _mirror_ok(pb, pr):
            errs.append(f"spawn {slot}: B {pb} and R {pr} are not mirrors")
    if not _mirror_ok(d["bases"]["B"]["cairn"], d["bases"]["R"]["cairn"]):
        errs.append("bases: the two Cairns are not mirrors")
    for k in ("mere", "island"):
        if abs(d["terrain"][k]["c"][0] - 0.5) > TOL or abs(d["terrain"][k]["c"][1] - 0.5) > TOL:
            errs.append(f"terrain.{k} must be centred at (0.5, 0.5)")
    # edges: the set of edges must map onto itself when B and R are swapped
    es = {frozenset((e["a"], e["b"])) for e in d["edges"]}
    for e in d["edges"]:
        twin = frozenset((swap_id(e["a"]), swap_id(e["b"])))
        if twin not in es:
            errs.append(f"edge {e['a']} - {e['b']} has no mirrored twin edge")
    # lanes: node list read backwards with sides swapped is the same list
    for lane in d["lanes"]:
        ns = lane["nodes"]
        if [swap_id(n) for n in reversed(ns)] != ns:
            errs.append(f"lane {lane['id']}: node list is not mirror-symmetric")
    for e in d["edges"]:
        if bool(e.get("bridge")) != bool(next((x for x in d["edges"] if frozenset((x["a"], x["b"])) == frozenset((swap_id(e["a"]), swap_id(e["b"]))) ), {}).get("bridge")):
            errs.append(f"edge {e['a']} - {e['b']}: bridge flag differs from its twin")
    return errs


def check_lanes(ctx):
    d, errs = ctx.d, []
    edges = {frozenset((e["a"], e["b"])) for e in d["edges"]}
    yard = {s: d["bases"][s]["yard_r_u"] for s in "BR"}
    ids = {l["id"] for l in d["lanes"]}
    if ids != {"top", "mid", "bot"}:
        errs.append(f"lanes must be top, mid and bot, found {sorted(ids)}")
    for lane in d["lanes"]:
        ns = lane["nodes"]
        if len(ns) < 5:
            errs.append(f"lane {lane['id']}: too few waypoints")
            continue
        if not ns[0].startswith("B.") or not ns[-1].startswith("R."):
            errs.append(f"lane {lane['id']}: must start at a B node and end at an R node")
        if ctx.dist_u(ctx.nodes[ns[0]]["p"], d["bases"]["B"]["cairn"]) > yard["B"]:
            errs.append(f"lane {lane['id']}: start {ns[0]} is outside the Blue base yard")
        if ctx.dist_u(ctx.nodes[ns[-1]]["p"], d["bases"]["R"]["cairn"]) > yard["R"]:
            errs.append(f"lane {lane['id']}: end {ns[-1]} is outside the Red base yard")
        total = 0.0
        for a, b in zip(ns, ns[1:]):
            if frozenset((a, b)) not in edges:
                errs.append(f"lane {lane['id']}: {a} to {b} is not an edge")
            pa, pb = ctx.nodes[a]["p"], ctx.nodes[b]["p"]
            if pb[1] > pa[1] + 1e-9:
                errs.append(f"lane {lane['id']}: {a} to {b} walks back towards Blue (y grows)")
            total += ctx.dist_u(pa, pb)
        if abs(total - lane.get("length_u", -1)) > 0.002:
            errs.append(f"lane {lane['id']}: length_u {lane.get('length_u')} but the waypoints measure {total:.4f}")
        if not 0.5 <= lane.get("width_px", 0) <= 80:
            errs.append(f"lane {lane['id']}: width_px {lane.get('width_px')} out of range")
        cl = lane.get("clash", {})
        outer = [t for t in d["towers"] if t["lane"] == lane["id"] and t["tier"] == "outer" and t["side"] == "B"]
        if cl.get("neutral_s") != 0.5:
            errs.append(f"lane {lane['id']}: clash.neutral_s must be 0.5")
        if outer and not (0 < cl.get("max_shift_s", 0) < 0.5 - outer[0]["s"]):
            errs.append(f"lane {lane['id']}: clash.max_shift_s must stay in front of the enemy outer tower")
    # whole graph connected, and a walk exists from one Cairn to the other
    dist = ctx.shortest("B.cairn") if "B.cairn" in ctx.nodes else {}
    for n in ctx.nodes:
        if n not in dist:
            errs.append(f"node {n} cannot be reached from the Blue Cairn")
    if "R.cairn" in dist:
        # each lane on its own must also join the two bases: remove all other lanes' private nodes and walk again
        for lane in d["lanes"]:
            keep = set(lane["nodes"]) | {n for n in ctx.nodes if n.split(".")[1] == "spawn" or n.endswith(".cairn")}
            adj = {}
            for e in d["edges"]:
                if e["a"] in keep and e["b"] in keep:
                    adj.setdefault(e["a"], []).append(e["b"])
                    adj.setdefault(e["b"], []).append(e["a"])
            seen, stack = {"B.cairn"}, ["B.cairn"]
            while stack:
                u = stack.pop()
                for v in adj.get(u, []):
                    if v not in seen:
                        seen.add(v)
                        stack.append(v)
            if "R.cairn" not in seen:
                errs.append(f"lane {lane['id']}: Blue Cairn and Red Cairn are not joined through this lane alone")
    else:
        errs.append("no walk from the Blue Cairn to the Red Cairn")
    return errs


def check_spawns(ctx):
    d, errs = ctx.d, []
    for side in "BR":
        sp = d["spawns"].get(side, {})
        cairn = d["bases"][side]["cairn"]
        for slot in SLOTS:
            if slot not in sp:
                errs.append(f"side {side}: slot '{slot}' has no spawn")
                continue
            p = sp[slot]
            if ctx.dist_u(p, cairn) > d["bases"][side]["yard_r_u"]:
                errs.append(f"spawn {side}.{slot}: outside the base yard")
            if (side == "B") != (p[1] > 0.5):
                errs.append(f"spawn {side}.{slot}: on the wrong half of the map")
            node = ctx.nodes.get(f"{side}.spawn.{slot}")
            if not node:
                errs.append(f"spawn {side}.{slot}: no graph node '{side}.spawn.{slot}'")
            elif abs(node["p"][0] - p[0]) > 1e-6 or abs(node["p"][1] - p[1]) > 1e-6:
                errs.append(f"spawn {side}.{slot}: node and spawn disagree")
            if ctx.dist_px(p, cairn) < 48:
                errs.append(f"spawn {side}.{slot}: too close to the Cairn icon")
        extra = set(sp) - set(SLOTS) - {"pad_r_px"}
        if extra:
            errs.append(f"side {side}: unknown spawn slots {sorted(extra)}")
        keys = [s for s in SLOTS if s in sp]
        for i in range(len(keys)):
            for j in range(i + 1, len(keys)):
                dpx = ctx.dist_px(sp[keys[i]], sp[keys[j]])
                if dpx < d["icons_px"]["hero"] + 12:
                    errs.append(f"spawns {side}.{keys[i]} and {side}.{keys[j]}: {dpx:.0f} px apart, tokens (40 px) would touch")
    for slot, home in d.get("slots", {}).items():
        if slot not in SLOTS:
            errs.append(f"slots: unknown slot {slot}")
    for s in SLOTS:
        if s not in d.get("slots", {}):
            errs.append(f"slots: '{s}' has no home lane or zone")
    return errs


def check_towers(ctx):
    d, errs = ctx.d, []
    lanes = {l["id"]: l for l in d["lanes"]}
    for side in "BR":
        for lane_id, lane in lanes.items():
            ts = [t for t in d["towers"] if t["side"] == side and t["lane"] == lane_id]
            tiers = sorted(t["tier"] for t in ts)
            if tiers != ["inner", "outer"]:
                errs.append(f"{side} {lane_id}: expected one inner and one outer tower, found {tiers}")
                continue
            inner = next(t for t in ts if t["tier"] == "inner")
            outer = next(t for t in ts if t["tier"] == "outer")
            sb = (lambda t: t["s"]) if side == "B" else (lambda t: 1 - t["s"])
            if not 0 < sb(inner) < sb(outer) < 0.5:
                errs.append(f"{side} {lane_id}: tower order must be Cairn, inner, outer, centre (s {sb(inner)}, {sb(outer)})")
            poly = lane_poly(ctx, lane)
            for t in ts:
                off = poly_dist_px(ctx, t["p"], poly)
                if off > lane["width_px"] / 2:
                    errs.append(f"tower {t['id']}: {off:.0f} px off its lane (limit {lane['width_px'] / 2:.0f})")
                want = arc_fraction_point(ctx, poly, t["s"])
                if ctx.dist_px(want, t["p"]) > 4:
                    errs.append(f"tower {t['id']}: not at arc fraction s={t['s']} of its lane")
        guards = [t for t in d["towers"] if t["side"] == side and t["lane"] == "base"]
        if len(guards) != 2:
            errs.append(f"{side}: expected 2 gate towers, found {len(guards)}")
        for g in guards:
            if ctx.dist_u(g["p"], d["bases"][side]["cairn"]) > d["bases"][side]["yard_r_u"]:
                errs.append(f"tower {g['id']}: outside the base yard")
    return errs


def check_camps(ctx):
    d, errs = ctx.d, []
    lanes = [(l, lane_poly(ctx, l)) for l in d["lanes"]]
    for side in "BR":
        mine = [c for c in d["camps"] if c["side"] == side]
        for pocket in ("thicket", "shallows"):
            n = len([c for c in mine if c["pocket"] == pocket])
            if n != 3:
                errs.append(f"{side} {pocket}: expected 3 camps, found {n}")
        for c in mine:
            if (side == "B") != (c["p"][1] > 0.5):
                errs.append(f"camp {c['id']}: on the wrong half")
    neutral = [c for c in d["camps"] if c["side"] == "N"]
    if len(neutral) != 1 or neutral[0]["kind"] != "mossback":
        errs.append("expected exactly one shared big camp (kind 'mossback') on the centre line")
    for c in d["camps"]:
        r = icon_px_for(d, "camp", c) / 2
        for lane, poly in lanes:
            off = poly_dist_px(ctx, c["p"], poly)
            if off < lane["width_px"] / 2 + r + 4:
                errs.append(f"camp {c['id']}: {off:.0f} px from lane {lane['id']}, needs {lane['width_px'] / 2 + r + 4:.0f}")
    return errs


def check_water(ctx):
    d, errs = ctx.d, []
    for coll, kind in (("towers", "tower"), ("camps", "camp"), ("objectives", "objective")):
        for e in d[coll]:
            if e["id"] == "N.moonhulk":
                continue
            r = icon_px_for(d, kind, e) / 2
            if ctx.in_water(e["p"], margin_px=r):
                errs.append(f"{kind} {e['id']}: icon touches the lake")
    for side in "BR":
        for slot, p in d["spawns"][side].items():
            if slot != "pad_r_px" and ctx.in_water(p, margin_px=20):
                errs.append(f"spawn {side}.{slot}: in the lake")
    for n in d["nodes"]:
        if n["kind"] in ("camp", "spawn", "base") and ctx.in_water(n["p"]):
            errs.append(f"node {n['id']}: in the lake")
    moon = next((o for o in d["objectives"] if o["id"] == "N.moonhulk"), None)
    if not moon or ctx.in_water(moon["p"]):
        errs.append("Moonhulk must stand on the island")
    if ctx.island["r_px"] >= ctx.mere["r_px"]:
        errs.append("island must be smaller than the lake")
    if ctx.island["r_px"] < 64:
        errs.append("island too small for ten fighters (needs r >= 64 px)")
    # fight zones on land may not sit in the lake
    for z in d["zones"]:
        if z["kind"] == "fight" and z["id"] != "moonhulk_isle":
            gap = ctx.dist_px(z["c"], d["terrain"]["mere"]["c"]) - z["r_px"] - ctx.mere["r_px"]
            if gap < -4:
                errs.append(f"zone {z['id']}: overlaps the lake by {-gap:.0f} px")
    # edges: sample along each edge
    for e in d["edges"]:
        a, b = ctx.nodes[e["a"]]["p"], ctx.nodes[e["b"]]["p"]
        n = max(2, int(ctx.dist_px(a, b) / SAMPLE_PX))
        wet = any(ctx.in_water([a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n]) for i in range(n + 1))
        if wet and not e.get("bridge"):
            errs.append(f"edge {e['a']} - {e['b']}: walks through the lake but is not flagged as a bridge")
        if e.get("bridge") and not wet:
            errs.append(f"edge {e['a']} - {e['b']}: flagged as bridge but never crosses water")
        want = ctx.dist_u(a, b)
        if abs(want - e.get("len_u", -1)) > 0.0015:
            errs.append(f"edge {e['a']} - {e['b']}: len_u {e.get('len_u')} but measures {want:.4f}")
    return errs


def check_spacing(ctx):
    d, errs = ctx.d, []
    items = []
    for t in d["towers"]:
        items.append((t["id"], t["p"], d["icons_px"]["tower"] / 2))
    for c in d["camps"]:
        items.append((c["id"], c["p"], icon_px_for(d, "camp", c) / 2))
    for o in d["objectives"]:
        items.append((o["id"], o["p"], o["icon_px"] / 2))
    for side in "BR":
        for slot in SLOTS:
            if slot in d["spawns"][side]:
                items.append((f"spawn.{side}.{slot}", d["spawns"][side][slot], d["icons_px"]["hero"] / 2))
    for i in range(len(items)):
        for j in range(i + 1, len(items)):
            a, b = items[i], items[j]
            need = a[2] + b[2] + 4
            got = ctx.dist_px(a[1], b[1])
            if got < need:
                errs.append(f"{a[0]} and {b[0]}: {got:.0f} px apart, icons need {need:.0f}")
    return errs


def check_stages(ctx):
    d, errs = ctx.d, []
    stages = d["stages"]
    have = [s["contest"] for s in stages]
    for c in SIM_CONTESTS + ["siege"]:
        if c not in have:
            errs.append(f"contest '{c}' has no stage (no place on the map)")
    if len(set(have)) != len(have):
        errs.append("a contest appears twice in stages")
    ws = float(d["watch_seconds"])
    last_t = -1.0
    by = {s["contest"]: s for s in stages}
    zones = {z["id"]: z for z in d["zones"]}
    base_speed = float(d["speeds"]["walk_u_s"])
    for s in sorted(stages, key=lambda x: x["order"]):
        want = s["t_frac"] * ws
        if abs(want - s["t_s"]) > 0.01:
            errs.append(f"stage {s['contest']}: t_s {s['t_s']} but t_frac x {ws:g} s = {want:.2f}")
        if s["t_s"] <= last_t:
            errs.append(f"stage {s['contest']}: not later than the stage before it")
        last_t = s["t_s"]
        if s["t_s"] > ws + 1e-9:
            errs.append(f"stage {s['contest']}: after the end of the watch window")
        first_zone = (s["zone"] if isinstance(s["zone"], list) else [s["zone"]])[0]
        zn = first_zone[:-2] + ".B" if first_zone.endswith(".*") else first_zone
        if s["contest"] != "siege" and len(s.get("actors", [])) == 5 and zones[zn]["r_px"] < 60:
            errs.append(f"stage {s['contest']}: zone {zn} (r {zones[zn]['r_px']} px) is too small for a 5 v 5")
        for a in s.get("actors", []):
            if a not in SLOTS:
                errs.append(f"stage {s['contest']}: unknown actor slot {a}")
        since = s.get("since")
        for tr in s.get("travel", []):
            dist = ctx.shortest(tr["from"]).get(tr["to"])
            if dist is None:
                errs.append(f"stage {s['contest']}: no walk from {tr['from']} to {tr['to']}")
                continue
            mult = {"walk": 1.0, "rotate": d["speeds"]["rotate_mult"], "rush": d["speeds"]["rush_mult"]}.get(tr["speed"])
            if mult is None:
                errs.append(f"stage {s['contest']}: unknown speed '{tr['speed']}'")
                continue
            t_need = dist / (base_speed * mult)
            t_have = s["t_s"] - (0.0 if since in (None, "start") else by[since]["t_s"])
            if t_need > t_have - TRAVEL_MARGIN_S:
                errs.append(f"stage {s['contest']}: walk {tr['from']} to {tr['to']} takes {t_need:.1f} s at {tr['speed']} speed, only {t_have:.1f} s available (margin {TRAVEL_MARGIN_S:g} s)")
    for c in d["camera"]["focus"].get("contests", []):
        if c not in have:
            errs.append(f"camera.focus.contests: unknown contest {c}")
    return errs


def _speed_mult(d, name):
    return {"walk": 1.0, "rotate": d["speeds"]["rotate_mult"], "rush": d["speeds"]["rush_mult"]}.get(name)


def check_units(ctx):
    d, errs = ctx.d, []
    u = d["units"]
    body = u["body_width_px"]
    if not 24 <= body <= d["icons_px"]["hero"]:
        errs.append(f"units.body_width_px {body} must be between 24 and the hero token ({d['icons_px']['hero']} px)")
    if abs(u["body_width_u"] * ctx.unit - body) > 0.5:
        errs.append(f"units.body_width_u {u['body_width_u']} x {ctx.unit:g} px is {u['body_width_u'] * ctx.unit:.1f} px, not {body}")
    if u.get("range_body_widths") != RANGE_BODY_WIDTHS:
        errs.append(f"units.range_body_widths must be {RANGE_BODY_WIDTHS} (the action vocabulary's numbers)")
    for k, mult in RANGE_BODY_WIDTHS.items():
        if abs(u.get("range_px", {}).get(k, -1) - body * mult) > 0.5:
            errs.append(f"units.range_px.{k} is {u.get('range_px', {}).get(k)}, expected {body * mult}")
        if abs(u.get("range_u", {}).get(k, -1) - body * mult / ctx.unit) > 0.0006:
            errs.append(f"units.range_u.{k} is {u.get('range_u', {}).get(k)}, expected {body * mult / ctx.unit:.4f}")
    if u.get("step_px") != body:
        errs.append("units.step_px must equal the body width (one step = one body width)")
    return errs


def check_tally(ctx):
    d, errs = ctx.d, []
    t = d["tower_tally"]
    lanes = {l["id"] for l in d["lanes"]}
    if t.get("per_side") != SCOREBOARD_TOWERS_PER_SIDE:
        errs.append(f"tower_tally.per_side is {t.get('per_side')}, the scoreboard tally is {SCOREBOARD_TOWERS_PER_SIDE} per side")
    for side in "BR":
        mine = [x for x in d["towers"] if x["side"] == side]
        for x in mine:
            if not isinstance(x.get("scoreboard"), bool):
                errs.append(f"tower {x['id']}: missing boolean 'scoreboard' flag")
        counted = [x for x in mine if x.get("scoreboard") is True]
        if len(counted) != SCOREBOARD_TOWERS_PER_SIDE:
            errs.append(f"side {side}: {len(counted)} towers are counted on the scoreboard, expected {SCOREBOARD_TOWERS_PER_SIDE}")
        for x in counted:
            if x["tier"] not in ("inner", "outer") or x["lane"] not in lanes:
                errs.append(f"tower {x['id']}: only lane towers (inner, outer) may count on the scoreboard")
        for x in mine:
            if x["tier"] == "guard" and x.get("scoreboard") is not False:
                errs.append(f"tower {x['id']}: a guard tower is scenery and must have scoreboard false")
    win = t.get("guard_fall_window_s", [0, 0])
    fl = next((s for s in d["stages"] if s["contest"] == "fight_late"), None)
    if not fl or abs(win[0] - fl["t_s"]) > 0.01:
        errs.append(f"tower_tally.guard_fall_window_s must open when fight_late resolves ({fl['t_s'] if fl else '?'} s), got {win[0]}")
    if not (win[0] < win[1] <= d["watch_seconds"]):
        errs.append(f"tower_tally.guard_fall_window_s {win} must end inside the watch window")
    falls = t.get("guard_fall_s", [])
    guards = len([x for x in d["towers"] if x["side"] == "B" and x["tier"] == "guard"])
    if len(falls) != guards:
        errs.append(f"tower_tally.guard_fall_s has {len(falls)} times for {guards} guard towers per side")
    if falls != sorted(falls):
        errs.append("tower_tally.guard_fall_s must be in time order")
    for f in falls:
        if not win[0] < f < win[1]:
            errs.append(f"guard tower fall at {f} s is outside the closing push {win}")
    return errs


def check_variants(ctx):
    d, errs = ctx.d, []
    lv = d["late_fight_variants"]
    t = d["tower_tally"]
    by = {s["contest"]: s for s in d["stages"]}
    body = d["units"]["body_width_px"]
    ws = float(d["watch_seconds"])
    zones = {z["id"]: z for z in d["zones"]}
    variants = lv.get("variants", [])
    ids = [v["id"] for v in variants]
    kind_of = {v["id"]: v.get("kind", "held") for v in variants}
    held_ids = [i for i in ids if kind_of[i] == "held"]
    clean_ids = [i for i in ids if kind_of[i] == "clean"]
    if len(held_ids) < 2 or len(set(ids)) != len(ids):
        errs.append("late_fight_variants needs at least two held variants with unique ids")
    if not clean_ids:
        errs.append("late_fight_variants needs a clean variant (the 81 percent case: the game winner also wins fight_late)")
    for i in ids:
        if kind_of[i] not in ("held", "clean"):
            errs.append(f"{i}: kind must be 'held' or 'clean'")
    if lv.get("default") not in held_ids:
        errs.append(f"late_fight_variants.default '{lv.get('default')}' is not one of the held variants {held_ids}")
    if lv.get("default_clean") not in clean_ids:
        errs.append(f"late_fight_variants.default_clean '{lv.get('default_clean')}' is not one of the clean variants {clean_ids}")
    pr = lv.get("prototype", {})
    for k in ("build", "measure", "decision_rule", "status"):
        if not pr.get(k):
            errs.append(f"late_fight_variants.prototype.{k} is missing (what the Technical Designer builds and what decides)")
    unproven = [v["id"] for v in variants if v.get("proven") is not False]
    if unproven:
        errs.append(f"variants {unproven}: must say proven false (nothing here has been prototyped)")
    resolve_t = by["fight_late"]["t_s"]
    obj_t = by["obj_late"]["t_s"]
    for v in variants:
        vid = v["id"]
        kind = v.get("kind", "held")
        resolve_ev = "resolve_held" if kind == "held" else "resolve_clean"
        form = v.get("formation", {})
        pts = []
        for team in ("W", "U"):
            for slot in SLOTS:
                p = form.get(team, {}).get(slot)
                if not p or len(p) != 2 or not all(isinstance(c, (int, float)) and 0.04 <= c <= 0.96 for c in p):
                    errs.append(f"{vid}: formation {team}.{slot} missing or outside the safe margin")
                else:
                    pts.append((f"{team}.{slot}", p))
        if len(pts) != 10:
            continue
        if v.get("u_mirrors_w"):
            for slot in SLOTS:
                if not _mirror_ok(form["W"][slot], form["U"][slot]):
                    errs.append(f"{vid}: U.{slot} should mirror W.{slot}")
        for i in range(len(pts)):
            for j in range(i + 1, len(pts)):
                gap = ctx.dist_px(pts[i][1], pts[j][1])
                if gap < body:
                    errs.append(f"{vid}: tokens {pts[i][0]} and {pts[j][0]} are {gap:.0f} px apart, bodies are {body} px")
        ground = v.get("ground")
        for label, p in pts:
            if ground == "island":
                off = ctx.dist_px(p, d["terrain"]["island"]["c"])
                if off > ctx.island["r_px"] - body / 2:
                    errs.append(f"{vid}: {label} is {off:.0f} px from the island centre, limit {ctx.island['r_px'] - body / 2:.0f}")
            elif ground == "land":
                if ctx.in_water(p, margin_px=body / 2):
                    errs.append(f"{vid}: {label} touches the lake")
            else:
                errs.append(f"{vid}: ground must be 'island' or 'land'")
                break
            for tw in d["towers"]:
                need = body / 2 + d["icons_px"]["tower"] / 2
                if ctx.dist_px(p, tw["p"]) < need:
                    errs.append(f"{vid}: {label} sits on tower {tw['id']} ({ctx.dist_px(p, tw['p']):.0f} px, needs {need:.0f})")
        for zkey, team in (("zone_W", "W"), ("zone_U", "U")):
            zid = v.get(zkey)
            if zid is None:
                continue
            if zid not in zones:
                errs.append(f"{vid}: {zkey} '{zid}' is not a zone")
                continue
            z = zones[zid]
            for slot in SLOTS:
                off = ctx.dist_px(form[team][slot], z["c"])
                if off > z["r_px"] - body / 2:
                    errs.append(f"{vid}: {team}.{slot} is {off:.0f} px from the centre of {zid}, limit {z['r_px'] - body / 2:.0f}")
        if kind == "held" and v.get("kills_change") != 0:
            errs.append(f"{vid}: kills_change must be 0 (the ledger owns kills)")
        if kind == "clean" and v.get("kills_change") != "ledger":
            errs.append(f"{vid}: kills_change must be 'ledger' (the clean case shows the ledger's kills, nothing added)")
        if kind == "clean" and not v.get("applies_when"):
            errs.append(f"{vid}: applies_when is missing")
        # no zone may be asked to hold more bodies than half its area
        for zkey, team in (("zone_W", "W"), ("zone_U", "U")):
            zid = v.get(zkey)
            if zid in zones:
                fill = 5 * (body / 2) ** 2 / zones[zid]["r_px"] ** 2
                if fill > 0.5:
                    errs.append(f"{vid}: five {body} px bodies fill {fill:.0%} of zone {zid}, the limit is 50 percent")

        # timeline
        ev = v.get("events", [])
        times = [e["t_s"] for e in ev]
        names = {e["event"]: e["t_s"] for e in ev}
        if times != sorted(times) or len(set(times)) != len(times):
            errs.append(f"{vid}: events must be in strictly rising time order")
        for need_ev in ("formation", "clash", resolve_ev, "cairn_crack", "cairn_fall"):
            if need_ev not in names:
                errs.append(f"{vid}: event '{need_ev}' is missing")
        if resolve_ev in names and abs(names[resolve_ev] - resolve_t) > 0.01:
            errs.append(f"{vid}: {resolve_ev} at {names[resolve_ev]} s but fight_late resolves at {resolve_t} s")
        if "cairn_fall" in names and abs(names["cairn_fall"] - t["guard_fall_window_s"][1]) > 0.01:
            errs.append(f"{vid}: cairn_fall at {names['cairn_fall']} s must close the guard-tower window ({t['guard_fall_window_s'][1]} s)")
        if times and (times[0] < obj_t or times[-1] > ws):
            errs.append(f"{vid}: events must lie between obj_late ({obj_t} s) and the end of the watch ({ws:g} s)")
        if all(k in names for k in ("cairn_crack", "cairn_fall")) and not names["cairn_crack"] < names["cairn_fall"]:
            errs.append(f"{vid}: cairn_crack must come before cairn_fall")
        for f in t["guard_fall_s"]:
            if "cairn_crack" in names and f > names["cairn_crack"]:
                errs.append(f"{vid}: guard tower falls at {f} s, after the Cairn cracks ({names['cairn_crack']} s)")
        # walks
        legs = v.get("legs", [])
        pack_end = None
        for leg in legs:
            tag = f"{vid}: {leg.get('actor')} {leg.get('from')} to {leg.get('to')}"
            if leg.get("actor") not in LEG_ACTORS:
                errs.append(f"{tag}: unknown actor")
                continue
            dist = ctx.shortest(leg["from"]).get(leg["to"]) if leg["from"] in ctx.nodes and leg["to"] in ctx.nodes else None
            mult = _speed_mult(d, leg.get("speed"))
            if dist is None or mult is None:
                errs.append(f"{tag}: unknown node, no walk, or unknown speed")
                continue
            need_s = dist / (float(d["speeds"]["walk_u_s"]) * mult)
            have_s = leg["arrive_by_s"] - leg["start_s"]
            if leg["start_s"] < obj_t:
                errs.append(f"{tag}: starts at {leg['start_s']} s, before the Moonhulk is taken ({obj_t} s)")
            if leg["arrive_by_s"] > ws:
                errs.append(f"{tag}: must arrive by {leg['arrive_by_s']} s, after the watch ends")
            margin = float(leg.get("margin_s", TRAVEL_MARGIN_S))
            if need_s > have_s - margin:
                errs.append(f"{tag}: takes {need_s:.1f} s at {leg['speed']} speed, only {have_s:.1f} s available (margin {margin:g} s)")
            if leg["actor"] == ("lead_pack" if kind == "held" else "W_heroes") and leg["to"] == "R.cairn":
                pack_end = leg
        who = "lead pack" if kind == "held" else "winning heroes"
        if not pack_end or pack_end["to"] != "R.cairn" or pack_end["arrive_by_s"] > t["guard_fall_window_s"][1]:
            errs.append(f"{vid}: the {who}' last leg must end at the loser's Cairn (canonical R.cairn) before it falls")
        elif "cairn_crack" in names and pack_end["start_s"] > names["cairn_crack"]:
            errs.append(f"{vid}: the {who} start their last leg after the Cairn cracks")
        elif kind == "clean" and "cairn_crack" in names and pack_end["arrive_by_s"] > names["cairn_crack"] + 1e-9:
            errs.append(f"{vid}: the winning heroes must reach the Cairn by the crack ({names['cairn_crack']} s), leg is due {pack_end['arrive_by_s']} s")
    return errs


# --------------------------------------------------------------------------- look, labels, walks (pass 1c)

def check_look(ctx):
    d, errs = ctx.d, []
    lk = d["look"]
    tk = lk.get("tokens", {})
    for role, want in EXPECTED_TOKENS.items():
        if tk.get(role) != want:
            errs.append(f"look.tokens.{role} is {tk.get(role)!r}, ART-BIBLE 3.8/3.9 maps it to {want}")
    used_unnamed = set()
    for role, name in tk.items():
        if not isinstance(name, str) or name.startswith("ARENA_"):
            errs.append(f"look.tokens.{role}: {name!r} is a placeholder, only ART-BIBLE token names are allowed")
        elif name in NEVER_ON_MAP:
            errs.append(f"look.tokens.{role}: {name} is never a map colour (ART-BIBLE 3.8)")
        elif name in UNNAMED_IN_BIBLE:
            used_unnamed.add(name)
        elif name not in BIBLE_TOKENS:
            errs.append(f"look.tokens.{role}: {name} is not a token of ART-BIBLE 3.1 to 3.9")
    listed = set(lk.get("tokens_not_in_bible", []))
    if listed != used_unnamed:
        errs.append(f"look.tokens_not_in_bible {sorted(listed)} must list exactly the tokens the bible has no constant for: {sorted(used_unnamed)}")
    sh = lk.get("shapes", {})
    if sh.get("hero_you") != "circle" or sh.get("hero_them") != "hexagon_flat_top":
        errs.append("look.shapes: you are a circle and them a flat-top hexagon (ART-BIBLE 3.8)")
    if sh.get("stoneback") != "rhombus":
        errs.append(f"look.shapes.stoneback is {sh.get('stoneback')!r}: Stoneback is a rhombus (the hexagon means 'them')")
    for k, v in sh.items():
        if "hex" in str(v) and k != "hero_them":
            errs.append(f"look.shapes.{k} is {v!r}: only the 'them' hero token may be a hexagon")
    for o in d["objectives"]:
        want = {"N.stoneback": sh.get("stoneback"), "N.moonhulk": sh.get("moonhulk")}.get(o["id"], sh.get("cairn"))
        if o.get("shape") != want:
            errs.append(f"objective {o['id']}: shape {o.get('shape')!r} but look.shapes says {want!r}")
    if not 0.3 <= lk.get("guard_tower_opacity", 0) <= 0.7:
        errs.append("look.guard_tower_opacity must be between 0.3 and 0.7 (scenery, dimmer than counted towers)")
    return errs


def rect_dist(a, b):
    dx = max(a[0] - b[2], b[0] - a[2], 0.0)
    dy = max(a[1] - b[3], b[1] - a[3], 0.0)
    return math.hypot(dx, dy)


def rect_point_dist(r, p):
    return math.hypot(max(r[0] - p[0], 0.0, p[0] - r[2]), max(r[1] - p[1], 0.0, p[1] - r[3]))


def rect_far_dist(r, p):
    return max(math.hypot(x - p[0], y - p[1]) for x in (r[0], r[2]) for y in (r[1], r[3]))


def label_box(ctx, lab, zoom=1.0):
    """box in map pixels. Labels are drawn in screen space at a fixed size, so at camera zoom z a label covers 1/z as
    much of the map: (text width + outline) / z by box height / z, centred on the label point."""
    cx, cy = ctx.px(lab["c"])
    w = (lab["w_px"] + LABEL_OUTLINE_PX) / zoom
    h = ctx.d["labels"].get("box_h_px", 24) / zoom
    return (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)


def lane_poly_px(ctx, lane):
    return [ctx.px(ctx.nodes[n]["p"]) for n in lane["nodes"]]


def poly_gap_px(p, poly):
    best = 1e9
    for a, b in zip(poly, poly[1:]):
        dx, dy = b[0] - a[0], b[1] - a[1]
        L2 = dx * dx + dy * dy
        t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L2))
        best = min(best, math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy)))
    return best


def lane_touch_px(ctx, box, lane, grid=2.0):
    """smallest gap (px) between a label box and the drawn road of a lane: the road is its centre line with the lane's
    half width plus the 2 px edge line; the stretch under the island is hidden by the island, so it does not count.
    Returns a negative number when the box overlaps the road."""
    poly = lane_poly_px(ctx, lane)
    half = lane["width_px"] / 2 + 2
    ic = ctx.px(ctx.island["c"])
    ir = float(ctx.island["r_px"])
    best = 1e9
    nx = max(1, int((box[2] - box[0]) / grid))
    ny = max(1, int((box[3] - box[1]) / grid))
    # gap = distance from the road to the box = min over box sample points of (distance to centre line - half)
    for i in range(nx + 1):
        x = box[0] + (box[2] - box[0]) * i / nx
        for j in range(ny + 1):
            y = box[1] + (box[3] - box[1]) * j / ny
            if math.hypot(x - ic[0], y - ic[1]) < ir:
                continue                      # that part of the box is on the island, where the road is hidden
            best = min(best, poly_gap_px((x, y), poly) - half)
    return best


def label_findings(ctx, labs=None):
    """returns (hard problems, lake or island rim crossings); one pass over every label"""
    d = ctx.d
    labs = d["labels"]["items"] if labs is None else labs
    lanes = {l["id"]: l for l in d["lanes"]}
    pairs = [(lab, z) for lab in labs for z in lab.get("zooms", [1.0])]
    circles = []
    for c in d["camps"]:
        circles.append((f"camp {c['id']}", ctx.px(c["p"]), icon_px_for(d, "camp", c) / 2))
    for t in d["towers"]:
        circles.append((f"tower {t['id']}", ctx.px(t["p"]), d["icons_px"]["tower"] / 2))
    for o in d["objectives"]:
        circles.append((f"objective {o['id']}", ctx.px(o["p"]), o["icon_px"] / 2))
    for side in "BR":
        for slot, p in d["spawns"][side].items():
            if slot != "pad_r_px":
                circles.append((f"spawn pad {side}.{slot}", ctx.px(p), d["spawns"]["pad_r_px"]))
    hard, crossings = [], []
    mc = ctx.px(ctx.mere["c"])
    for lab, z in pairs:
        box = label_box(ctx, lab, z)
        lid = lab["id"] if z == 1.0 else f"{lab['id']}@x{z:g}"
        if box[0] < 4 or box[1] < 4 or box[2] > ctx.w - 4 or box[3] > ctx.h - 4:
            hard.append(f"label {lid}: box leaves the arena (4 px margin)")
        own = lab.get("lane") if lab.get("kind") == "lane" else None
        for lid2, lane in lanes.items():
            if lid2 == own:
                cx, cy = ctx.px(lab["c"])
                if poly_gap_px((cx, cy), lane_poly_px(ctx, lane)) > lane["width_px"] / 2:
                    hard.append(f"label {lid}: lane tag is not on its own lane {lid2}")
                continue
            gap = lane_touch_px(ctx, box, lane)
            if gap < LABEL_GAP_PX:
                hard.append(f"label {lid}: {'crosses' if gap < 0 else 'is %.1f px from' % gap} lane {lid2} (needs {LABEL_GAP_PX} px clear)")
        for name, c, r in circles:
            gap = rect_point_dist(box, c) - r
            if gap < LABEL_GAP_PX:
                hard.append(f"label {lid}: {'overlaps' if gap < 0 else 'is %.1f px from' % gap} {name} (needs {LABEL_GAP_PX} px clear)")
        for lab2, z2 in pairs:
            if z2 == z and lab2["id"] > lab["id"] and rect_dist(box, label_box(ctx, lab2, z2)) < LABEL_GAP_PX:
                hard.append(f"labels {lid} and {lab2['id']}: closer than {LABEL_GAP_PX} px")
        for what, r_px in (("the lake shore", float(ctx.mere["r_px"])), ("the island rim", float(ctx.island["r_px"]))):
            inside = (r_px + 1.5 + LABEL_GAP_PX) - rect_point_dist(box, mc)    # how far the box reaches inside the ring
            outside = rect_far_dist(box, mc) - (r_px - 1.5 - LABEL_GAP_PX)     # how far it reaches outside it
            if inside > 0 and outside > 0:
                crossings.append({"label": lid, "what": what, "spill_px": round(min(inside, outside), 1)})
    return hard, crossings


def check_labels(ctx):
    d, errs = ctx.d, []
    lb = d["labels"]
    f = lb.get("font", {})
    if f.get("size_px", 0) < LABEL_MIN_PX:
        errs.append(f"labels.font.size_px {f.get('size_px')} is under the {LABEL_MIN_PX} px floor (ART-BIBLE 5.2)")
    if f.get("tracking_px") != 1.5 or f.get("weight") != "Bold":
        errs.append("labels.font must be Bold with +1.5 px tracking (ART-BIBLE 5.2, 313)")
    if f.get("colour") != "TEXT" or f.get("outline", {}).get("colour") != "VOID" or f.get("outline", {}).get("px") != LABEL_OUTLINE_PX:
        errs.append(f"labels.font: colour TEXT with a {LABEL_OUTLINE_PX} px VOID outline (ART-BIBLE 3.9)")
    items = lb.get("items", [])
    if len({i["id"] for i in items}) != len(items):
        errs.append("labels.items: duplicate id")
    want_text = {"lane_top": "TOP", "lane_mid": "MID", "lane_bot": "BOT", "place_stoneback": "STONEBACK",
                 "place_moonhulk": "MOONHULK", "place_mossback": "MOSSBACK"}
    have = {i["id"]: i for i in items}
    for k, txt in want_text.items():
        if k not in have:
            errs.append(f"labels.items: '{k}' is missing")
        elif have[k].get("text") != txt:
            errs.append(f"labels.items.{k}: text is {have[k].get('text')!r}, expected {txt!r}")
    for i in items:
        if not 20 <= i.get("w_px", 0) <= 200:
            errs.append(f"label {i['id']}: w_px {i.get('w_px')} out of range")
        elif i["w_px"] < len(i.get("text", "")) * 9:
            errs.append(f"label {i['id']}: w_px {i['w_px']} is narrower than 9 px a letter, the 24 px Bold face is wider than that")
        if i.get("kind") == "lane" and i.get("lane") not in {l["id"] for l in d["lanes"]}:
            errs.append(f"label {i['id']}: unknown lane {i.get('lane')}")
        if i.get("kind") == "place":
            icon = next((o for o in d["objectives"] if o["id"] == i.get("anchor")), None) or next((c for c in d["camps"] if c["id"] == i.get("anchor")), None)
            if not icon:
                errs.append(f"label {i['id']}: unknown anchor {i.get('anchor')}")
            else:
                near = rect_dist(label_box(ctx, i), (ctx.px(icon["p"])[0], ctx.px(icon["p"])[1]) * 2)
                if near > 40:
                    errs.append(f"label {i['id']}: {near:.0f} px from its icon, the viewer cannot tell what it names (limit 40)")
    hard, crossings = label_findings(ctx, items)
    errs += hard
    waived = lb.get("rim_crossing_waived", {})
    for c in crossings:
        w = waived.get(c["label"].split("@")[0])
        if not w or c["what"] not in w.get("what", []):
            errs.append(f"label {c['label']} crosses {c['what']} by {c['spill_px']} px (ART-BIBLE 3.3: nothing sits on the shore); "
                        f"allowed only through labels.rim_crossing_waived with a ruling")
        elif c["spill_px"] > w.get("max_spill_px", 0):
            errs.append(f"label {c['label']} crosses {c['what']} by {c['spill_px']} px, the waiver allows {w.get('max_spill_px')} px")
    for k, w in waived.items():
        if not w.get("ruling_needed_from") or not w.get("max_spill_px"):
            errs.append(f"labels.rim_crossing_waived.{k}: a waiver names who must rule and the largest spill allowed")
    return errs


def lane_point_need_u(ctx, lane_id, s, target, cache):
    lane = next(l for l in ctx.d["lanes"] if l["id"] == lane_id)
    ns = lane["nodes"]
    seg = [ctx.dist_u(ctx.nodes[ns[i]]["p"], ctx.nodes[ns[i + 1]]["p"]) for i in range(len(ns) - 1)]
    t, acc = s * sum(seg), 0.0
    for i, sl in enumerate(seg):
        if acc + sl >= t - 1e-12:
            f = (t - acc) / sl if sl else 0.0
            da, db = [cache.setdefault(n, ctx.shortest(n)).get(target) for n in (ns[i], ns[i + 1])]
            return None if da is None or db is None else min(f * sl + da, (1 - f) * sl + db)
        acc += sl
    return None


def leg_origins(ctx, leg):
    """[(label, distance in u)] for every origin a leg covers; worst case is what must fit"""
    out, cache = [], {}
    target = leg["to"]
    if "from_lane" in leg:
        fl = leg["from_lane"]
        for s in fl["s"]:
            out.append((f"{fl['lane']} lane at s={s:g}", lane_point_need_u(ctx, fl["lane"], s, target, cache)))
    else:
        for side in leg.get("sides", [None]):
            node = leg["from"].replace("{S}", side) if side else leg["from"]
            out.append((node, ctx.shortest(node).get(target) if node in ctx.nodes else None))
    return out


def walk_leg_result(ctx, leg, default_margin):
    """(worst need s, have s, margin, worst label) or None when the leg cannot be evaluated"""
    d = ctx.d
    mult = _speed_mult(d, leg.get("speed"))
    origins = leg_origins(ctx, leg)
    if mult is None or any(u is None for _, u in origins) or leg["to"] not in ctx.nodes:
        return None
    worst = max(origins, key=lambda x: x[1])
    need = worst[1] / (float(d["speeds"]["walk_u_s"]) * mult)
    return need, leg["due_s"] - leg["leave_s"], float(leg.get("margin_s", default_margin)), worst[0]


def check_walks(ctx):
    d, errs = ctx.d, []
    wl = d["walk_legs"]
    margin = float(wl.get("margin_s", TRAVEL_MARGIN_S))
    by = {s["contest"]: s for s in d["stages"]}
    lanes = {l["id"]: l for l in d["lanes"]}
    seen = set()
    for group in ("required", "rejected"):
        for leg in wl.get(group, []):
            lid = leg.get("id", "?")
            if lid in seen:
                errs.append(f"walk leg {lid}: duplicate id")
            seen.add(lid)
            for k in ("id", "to", "speed", "leave_s", "due_s", "source"):
                if k not in leg:
                    errs.append(f"walk leg {lid}: missing '{k}'")
            if "from" not in leg and "from_lane" not in leg:
                errs.append(f"walk leg {lid}: needs 'from' or 'from_lane'")
            if group == "rejected" and not leg.get("why"):
                errs.append(f"walk leg {lid}: a rejected leg needs a 'why'")
            if errs and any(e.startswith(f"walk leg {lid}") for e in errs):
                continue
            if "from_lane" in leg:
                fl = leg["from_lane"]
                lane = lanes.get(fl.get("lane"))
                if not lane:
                    errs.append(f"walk leg {lid}: unknown lane {fl.get('lane')}")
                    continue
                ms = lane["clash"]["max_shift_s"]
                lo, hi = 0.5 - ms, 0.5 + ms
                if any(not (lo - 1e-9 <= x <= hi + 1e-9) for x in fl["s"]):
                    errs.append(f"walk leg {lid}: s values {fl['s']} leave the clash range {lo:.2f} to {hi:.2f}")
                if not (min(fl["s"]) <= lo + 1e-9 and max(fl["s"]) >= hi - 1e-9):
                    errs.append(f"walk leg {lid}: s values must include both ends of the clash range ({lo:.2f} and {hi:.2f}), the worst case")
            if leg["due_s"] <= leg["leave_s"]:
                errs.append(f"walk leg {lid}: due {leg['due_s']} is not after leave {leg['leave_s']}")
            if leg.get("contest") in by and group == "required" and leg["due_s"] > by[leg["contest"]]["t_s"] + 1e-9:
                errs.append(f"walk leg {lid}: due {leg['due_s']} s is after its contest {leg['contest']} ({by[leg['contest']]['t_s']} s)")
            res = walk_leg_result(ctx, leg, margin)
            if res is None:
                errs.append(f"walk leg {lid}: unknown node, no walk, or unknown speed")
                continue
            need, have, mg, where = res
            fits = need <= have - mg
            if group == "required" and not fits:
                errs.append(f"walk leg {lid}: from {where} takes {need:.1f} s at {leg['speed']} speed, only {have:.2f} s available (margin {mg:g} s)")
            if group == "rejected" and fits:
                errs.append(f"rejected walk leg {lid} now fits ({need:.1f} s of {have:.2f} s): the finding is stale, move it to 'required' or delete it")
    for need_id in ("stone_top", "stone_mid", "stone_bot", "stone_jungle"):
        if need_id not in seen:
            errs.append(f"walk_legs.required needs the lane-origin leg '{need_id}' (ACTION-VOCABULARY rotate_stone)")
    if not any(l.get("id", "").startswith("reset_") for l in wl.get("required", [])):
        errs.append("walk_legs.required needs the tower-site to island legs (ACTION-VOCABULARY reset)")
    return errs


def check_clash_rule(ctx):
    d, errs = ctx.d, []
    cr = d["clash_rule"]
    if cr.get("front_max") != 0.60:
        errs.append("clash_rule.front_max must be 0.60 (ACTION-VOCABULARY 2.2)")
    if cr.get("formula") != "shift_s = (front / 0.60) * max_shift_s":
        errs.append("clash_rule.formula must be 'shift_s = (front / 0.60) * max_shift_s' (the vocabulary's wave-front formula)")
    if cr.get("direction") != "from neutral_s towards the loser":
        errs.append("clash_rule.direction must be 'from neutral_s towards the loser'")
    for lane in d["lanes"]:
        outer = [t for t in d["towers"] if t["lane"] == lane["id"] and t["tier"] == "outer" and t["side"] == "B"][0]
        if 0.5 - lane["clash"]["max_shift_s"] <= outer["s"]:
            errs.append(f"lane {lane['id']}: the clash at front_max would pass the outer tower")
    return errs


CHECKS = [("structure", check_structure), ("ids", check_ids), ("range", check_range), ("mirror", check_mirror),
          ("lanes", check_lanes), ("spawns", check_spawns), ("towers", check_towers), ("camps", check_camps),
          ("water", check_water), ("spacing", check_spacing), ("stages", check_stages),
          ("units", check_units), ("tally", check_tally), ("variants", check_variants),
          ("look", check_look), ("labels", check_labels), ("walks", check_walks), ("clash", check_clash_rule)]


def label_report(ctx):
    """prints the collision check for every label: the smallest clear gap to each kind of obstacle"""
    d = ctx.d
    print(f"  labels ({d['labels']['font']['size_px']} px Bold, +{d['labels']['font']['tracking_px']} px tracking, {LABEL_OUTLINE_PX} px outline; gap needed {LABEL_GAP_PX} px):")
    print(f"    {'label':<17}{'w px':>5}  {'lane':>7} {'camp':>6} {'tower':>6} {'object':>7} {'pad':>6} {'label':>6} {'edge':>6}  rim crossings")
    mc = ctx.px(ctx.mere["c"])
    for lab in d["labels"]["items"]:
        for z in lab.get("zooms", [1.0]):
            box = label_box(ctx, lab, z)
            own = lab.get("lane") if lab.get("kind") == "lane" else None
            lane_gap = min([lane_touch_px(ctx, box, l) for l in d["lanes"] if l["id"] != own] or [999])
            def circ(items):
                return min([rect_point_dist(box, ctx.px(i["p"])) - r for i, r in items] or [999])
            camp = circ([(c, icon_px_for(d, "camp", c) / 2) for c in d["camps"]])
            tower = circ([(t, d["icons_px"]["tower"] / 2) for t in d["towers"]])
            obj = circ([(o, o["icon_px"] / 2) for o in d["objectives"]])
            pad = min([rect_point_dist(box, ctx.px(p)) - d["spawns"]["pad_r_px"] for sd in "BR" for k, p in d["spawns"][sd].items() if k != "pad_r_px"])
            other = min([rect_dist(box, label_box(ctx, l2, z2)) for l2 in d["labels"]["items"] if l2["id"] != lab["id"] for z2 in l2.get("zooms", [1.0]) if z2 == z] or [999])
            edge = min(box[0], box[1], ctx.w - box[2], ctx.h - box[3])
            _, cr = label_findings(ctx, [lab])
            cr = [f"{c['what'].split()[-1]} {c['spill_px']}" for c in cr if c["label"].endswith(f"@x{z:g}") or z == 1.0]
            tag = lab["id"] + ("" if z == 1.0 else f"@x{z:g}")
            lane_txt = "island" if lane_gap > 1e8 else f"{lane_gap:.1f}"
            print(f"    {tag:<17}{lab['w_px']:>5}  {lane_txt:>7} {camp:6.1f} {tower:6.1f} {obj:7.1f} {pad:6.1f} {other:6.1f} {edge:6.1f}  {', '.join(cr) or 'none'}")


def report(ctx):
    d = ctx.d
    print("\nGeometry report (u = 760 px, walk speed %.3f u/s = %.1f px/s)" % (d["speeds"]["walk_u_s"], d["speeds"]["walk_u_s"] * ctx.unit))
    for lane in d["lanes"]:
        print(f"  lane {lane['id']:<4} {lane['name']:<14} length {lane['length_u']:.3f} u = {lane['length_u'] * ctx.unit:4.0f} px = {lane['length_u'] / d['speeds']['walk_u_s']:4.1f} s end to end")
    print("  travel (walk speed):")
    for s in sorted(d["stages"], key=lambda x: x["order"]):
        for tr in s.get("travel", []):
            dist = ctx.shortest(tr["from"]).get(tr["to"], float("nan"))
            mult = {"walk": 1.0, "rotate": d["speeds"]["rotate_mult"], "rush": d["speeds"]["rush_mult"]}[tr["speed"]]
            print(f"    {s['contest']:<10} at {s['t_s']:5.2f} s  {tr['from']:<14} -> {tr['to']:<12} {dist:.3f} u  {dist / d['speeds']['walk_u_s'] / mult:4.1f} s ({tr['speed']})")
    u = d["units"]
    print(f"  units: body width {u['body_width_px']} px = {u['body_width_u']:.4f} u; range melee/mid/long = {u['range_px']['melee']}/{u['range_px']['mid']}/{u['range_px']['long']} px")
    for v in d["late_fight_variants"]["variants"]:
        lv = d["late_fight_variants"]
        tag = " (default)" if v["id"] in (lv["default"], lv["default_clean"]) else ""
        print(f"  {v.get('kind', 'held')} fight '{v['id']}'{tag}:")
        for leg in v["legs"]:
            dist = ctx.shortest(leg["from"]).get(leg["to"], float("nan"))
            need = dist / (d["speeds"]["walk_u_s"] * _speed_mult(d, leg["speed"]))
            slack = leg["arrive_by_s"] - leg["start_s"] - need
            print(f"    {leg['actor']:<9} {leg['from']:<11} -> {leg['to']:<10} {dist:.3f} u {need:4.1f} s ({leg['speed']}) leaves {leg['start_s']:5.2f}, due {leg['arrive_by_s']:5.2f}, spare {slack:.1f} s")
    print("  walk legs from the lanes and tower sites (worst origin; rule: need <= window - margin):")
    wl = d["walk_legs"]
    for group in ("required", "rejected"):
        for leg in wl[group]:
            res = walk_leg_result(ctx, leg, float(wl.get("margin_s", TRAVEL_MARGIN_S)))
            need, have, mg, where = res
            ok = need <= have - mg
            verdict = ("PASS" if ok else "FAIL") if group == "required" else ("fits?!" if ok else "FAILS (asserted)")
            print(f"    {group[:3]} {leg['id']:<24} {where:<22} -> {leg['to']:<12} {need:5.1f} s of {have:5.2f} s ({leg['speed']}, margin {mg:g}) {verdict}")
    label_report(ctx)
    counts = {k: len(d[k]) for k in ("nodes", "edges", "towers", "camps", "zones", "stages")}
    counts["scoreboard_towers_per_side"] = d["tower_tally"]["per_side"]
    print("  counts:", counts)


def check_doc(text):
    """lint of ARENA-MAP.md against the pass 1c rulings (a text check, not a proof the document is right)"""
    errs = []
    if re.search(r"ARENA_[A-Z]", text):
        errs.append("the document still names ARENA_* colour placeholders (ART-BIBLE 3.9 replaced them)")
    low = text.lower()
    for bad in ("hexagon with a shell", "gold hexagon", "20 px bold", "(my assumption, for ui/ux to confirm)"):
        if bad in low:
            errs.append(f"the document still says '{bad}'")
    for need in ("rhombus", "1148", "198", "132"):
        if need not in text:
            errs.append(f"the document does not mention '{need}'")
    return errs


def selftest(base):
    """broken copies, built in memory: each must make exactly the check it targets fail"""
    import copy
    def T(d, i): return next(t for t in d["towers"] if t["id"] == i)
    def V(d, i): return next(v for v in d["late_fight_variants"]["variants"] if v["id"] == i)
    def Lb(d, i): return next(x for x in d["labels"]["items"] if x["id"] == i)
    def Wl(d, i): return next(x for g in ("required", "rejected") for x in d["walk_legs"][g] if x["id"] == i)
    def set_(d, path, val):
        o = d
        for k in path[:-1]:
            o = o[k]
        o[path[-1]] = val
    muts = [
      ("controls strip left at 180 px (old layout)", "structure", lambda d: (set_(d, ["arena", "layout_px", "feed_y"], [950, 1100]), set_(d, ["arena", "layout_px", "controls_y"], [1100, 1280]))),
      ("text strip 150 px, controls 132 px, gap left", "structure", lambda d: set_(d, ["arena", "layout_px", "feed_y"], [950, 1100])),
      ("icon larger than 48 px", "structure", lambda d: set_(d, ["icons_px", "tower"], 60)),
      ("Stoneback shape is a hexagon", "look", lambda d: set_(d, ["look", "shapes", "stoneback"], "hexagon")),
      ("Stoneback objective shape differs from look", "look", lambda d: next(o for o in d["objectives"] if o["id"] == "N.stoneback").__setitem__("shape", "hexagon")),
      ("an ARENA_ placeholder token", "look", lambda d: set_(d, ["look", "tokens", "lake"], "ARENA_LAKE_DEEP")),
      ("BAD used as a map token", "look", lambda d: set_(d, ["look", "tokens", "hero_them"], "BAD")),
      ("token not in the bible", "look", lambda d: set_(d, ["look", "tokens", "land"], "MAP_GRASS")),
      ("JUNGLE_RING not reported as missing", "look", lambda d: set_(d, ["look", "tokens_not_in_bible"], [])),
      ("them is a circle", "look", lambda d: set_(d, ["look", "shapes", "hero_them"], "circle")),
      ("labels 20 px", "labels", lambda d: set_(d, ["labels", "font", "size_px"], 20)),
      ("label outline 3 px", "labels", lambda d: set_(d, ["labels", "font", "outline", "px"], 3)),
      ("STONEBACK label on the Bot lane", "labels", lambda d: Lb(d, "place_stoneback").__setitem__("c", [0.8869, 0.5])),
      ("STONEBACK label at zoom 1.0 (crosses the shore and the lane)", "labels", lambda d: Lb(d, "place_stoneback").__setitem__("zooms", [1.0])),
      ("MOSSBACK label on a camp", "labels", lambda d: Lb(d, "place_mossback").__setitem__("c", [0.2306, 0.5849])),
      ("MOSSBACK label on the Top lane", "labels", lambda d: Lb(d, "place_mossback").__setitem__("c", [0.14, 0.5421])),
      ("two labels overlap", "labels", lambda d: Lb(d, "place_moonhulk").__setitem__("c", [0.5, 0.6395])),
      ("a label on a tower", "labels", lambda d: Lb(d, "lane_mid").__setitem__("c", [0.5, 0.691])),
      ("a label off the arena", "labels", lambda d: Lb(d, "lane_top").__setitem__("c", [0.02, 0.58])),
      ("lane tag off its own lane", "labels", lambda d: Lb(d, "lane_bot").__setitem__("c", [0.74, 0.5799])),
      ("label width narrower than the font", "labels", lambda d: Lb(d, "place_stoneback").__setitem__("w_px", 60)),
      ("label far from its icon", "labels", lambda d: Lb(d, "place_mossback").__setitem__("c", [0.2222, 0.80])),
      ("lane tag deleted", "labels", lambda d: d["labels"]["items"].remove(Lb(d, "lane_top"))),
      ("lane leg at walk speed", "walks", lambda d: Wl(d, "stone_top").__setitem__("speed", "walk")),
      ("lane leg leaves at 24 s", "walks", lambda d: Wl(d, "stone_top").__setitem__("leave_s", 24.0)),
      ("lane leg checked only at the neutral point", "walks", lambda d: Wl(d, "stone_top").__setitem__("from_lane", {"lane": "top", "s": [0.5]})),
      ("lane leg beyond the clash range", "walks", lambda d: Wl(d, "stone_top").__setitem__("from_lane", {"lane": "top", "s": [0.2, 0.5, 0.8]})),
      ("tower-site leg too late", "walks", lambda d: Wl(d, "reset_top2").__setitem__("leave_s", 54.0)),
      ("rejected leg now fits", "walks", lambda d: Wl(d, "stone_top_walk_from_24").__setitem__("leave_s", 5.0)),
      ("a lane-origin leg removed", "walks", lambda d: d["walk_legs"]["required"].remove(Wl(d, "stone_mid"))),
      ("clash rule formula changed", "clash", lambda d: set_(d, ["clash_rule", "formula"], "shift_s = front * max_shift_s")),
      ("clean_gate removed", "variants", lambda d: d["late_fight_variants"]["variants"].remove(V(d, "clean_gate"))),
      ("clean_gate winner on a Mid tower", "variants", lambda d: V(d, "clean_gate")["formation"]["W"].__setitem__("mid", [0.5, 0.2837])),
      ("clean_gate winners arrive after the crack", "variants", lambda d: V(d, "clean_gate")["legs"][-1].__setitem__("arrive_by_s", 73.0)),
      ("clean_gate leg too slow", "variants", lambda d: V(d, "clean_gate")["legs"][0].__setitem__("speed", "walk") or V(d, "clean_gate")["legs"][0].__setitem__("arrive_by_s", 64.0)),
      ("clean_gate changes the kills", "variants", lambda d: V(d, "clean_gate").__setitem__("kills_change", 0)),
      ("clean_gate marked proven", "variants", lambda d: V(d, "clean_gate").__setitem__("proven", True)),
      ("prototype brief deleted", "variants", lambda d: d["late_fight_variants"].pop("prototype")),
      ("default held variant is the clean one", "variants", lambda d: set_(d, ["late_fight_variants", "default"], "clean_gate")),
      ("held pack starts before the take", "variants", lambda d: V(d, "held_island")["legs"][0].__setitem__("start_s", 58.0)),
      ("held token on the island rim", "variants", lambda d: V(d, "held_island")["formation"]["W"].__setitem__("bot", [0.56, 0.5711])),
      ("a guard tower counted", "tally", lambda d: T(d, "B.guard.l").__setitem__("scoreboard", True)),
      ("guard tower falls after the Cairn", "tally", lambda d: set_(d, ["tower_tally", "guard_fall_s"], [72.0, 74.5])),
      ("tower moved off its lane", "towers", lambda d: T(d, "B.top.outer").__setitem__("p", [0.3, 0.6])),
      ("tower in the lake", "water", lambda d: T(d, "B.top.outer").__setitem__("p", [0.5, 0.6316])),
      ("coordinate outside 0..1", "range", lambda d: d["nodes"][0].__setitem__("p", [1.2, 0.5])),
      ("a spawn deleted", "spawns", lambda d: d["spawns"]["R"].pop("sup")),
      ("a mirror shifted", "mirror", lambda d: T(d, "R.bot.inner").__setitem__("p", [0.80, 0.2237])),
      ("a stage walk too slow", "stages", lambda d: next(x for x in d["stages"] if x["contest"] == "obj_mid")["travel"][0].__setitem__("speed", "walk") or set_(d, ["speeds", "walk_u_s"], 0.03)),
      ("range unit wrong", "units", lambda d: set_(d, ["units", "range_px", "long"], 150)),
    ]
    docs = [("document still has ARENA_ placeholders", "doc", "ARENA_LAKE_DEEP rhombus 1148 198 132"),
            ("document draws a Stoneback hexagon", "doc", "hexagon with a shell rhombus 1148 198 132"),
            ("document says labels 20 px bold", "doc", "20 px bold rhombus 1148 198 132"),
            ("document keeps the 150 px strip", "doc", "rhombus 1100 150")]
    bad = 0
    print(f"selftest: {len(muts) + len(docs)} broken copies, each must trip the check it targets (some also trip a neighbour)")
    for name, want, fn in muts:
        d = copy.deepcopy(base)
        fn(d)
        ctx = Ctx(d)
        failed = []
        for cname, cfn in CHECKS:
            try:
                e = cfn(ctx)
            except (KeyError, TypeError, ValueError, IndexError, StopIteration) as ex:
                e = [f"crashed {type(ex).__name__}"]
            if e:
                failed.append(cname)
        ok = want in failed
        bad += 0 if ok else 1
        print(f"  {'ok  ' if ok else 'BAD '} {name:<62} wants {want:<9} got {failed or 'nothing (still passes)'}{'  (also trips others)' if ok and len(failed) > 1 else ''}")
    for name, want, text in docs:
        ok = bool(check_doc(text))
        bad += 0 if ok else 1
        print(f"  {'ok  ' if ok else 'BAD '} {name:<62} wants {want:<9} got {'doc' if ok else 'nothing'}")
    print("SELFTEST:", "OK" if bad == 0 else f"{bad} problem(s)")
    return 0 if bad == 0 else 1


def main(argv):
    show_report = "--report" in argv
    doc_path = DOC_DEFAULT
    if "--doc" in argv:
        i = argv.index("--doc")
        doc_path = pathlib.Path(argv[i + 1])
        argv = argv[:i] + argv[i + 2:]
    args = [a for a in argv if not a.startswith("--")]
    path = pathlib.Path(args[0]) if args else DEFAULT
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as ex:
        print(f"FAIL cannot read {path}: {ex}")
        return 2
    problems_total = 0
    # structure first: nothing else can run on a file without the basic keys
    missing = [k for k in REQUIRED if k not in data]
    if missing:
        print(f"FAIL structure: missing keys {missing}")
        return 1
    ctx = Ctx(data)
    print(f"arena map {path.name}  (map {data['map_version']}, schema {data['schema_version']})")
    for name, fn in CHECKS:
        try:
            errs = fn(ctx)
        except (KeyError, TypeError, ValueError, IndexError) as ex:
            errs = [f"check crashed on malformed data: {type(ex).__name__}: {ex}"]
        if errs:
            problems_total += len(errs)
            print(f"FAIL {name} ({len(errs)})")
            for e in errs[:12]:
                print(f"     - {e}")
            if len(errs) > 12:
                print(f"     ... {len(errs) - 12} more")
        else:
            print(f"PASS {name}")
    if doc_path.exists():
        derrs = check_doc(doc_path.read_text(encoding="utf-8"))
        if derrs:
            problems_total += len(derrs)
            print(f"FAIL doc ({len(derrs)}) {doc_path.name}")
            for e in derrs:
                print(f"     - {e}")
        else:
            print(f"PASS doc ({doc_path.name})")
    if "--selftest" in argv:
        rc = selftest(data)
        problems_total += rc
    if show_report and problems_total == 0:
        report(ctx)
    print("RESULT:", "OK" if problems_total == 0 else f"{problems_total} problem(s)")
    return 0 if problems_total == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
