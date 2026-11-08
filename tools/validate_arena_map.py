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
  variants       the 'held fight' stagings for the game winner losing fight_late: tokens fit and do not overlap,
                 walks fit their clock, the timeline ends with the Cairn falling

Standard library only. Distances use map units: 1 unit = arena.unit_px (760 px) and dx is scaled by x_scale.
"""
import heapq
import json
import math
import pathlib
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

REQUIRED = ["schema", "schema_version", "map_version", "arena", "view", "icons_px", "speeds", "watch_seconds", "camera",
            "terrain", "bases", "nodes", "edges", "lanes", "towers", "camps", "objectives", "spawns", "zones", "stages",
            "units", "tower_tally", "late_fight_variants"]


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
    if len(variants) < 2 or len(set(ids)) != len(ids):
        errs.append("late_fight_variants needs at least two variants with unique ids")
    if lv.get("default") not in ids:
        errs.append(f"late_fight_variants.default '{lv.get('default')}' is not one of {ids}")
    unproven = [v["id"] for v in variants if v.get("proven") is not False]
    if unproven:
        errs.append(f"variants {unproven}: must say proven false (nothing here has been prototyped)")
    resolve_t = by["fight_late"]["t_s"]
    obj_t = by["obj_late"]["t_s"]
    for v in variants:
        vid = v["id"]
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
        if v.get("kills_change") != 0:
            errs.append(f"{vid}: kills_change must be 0 (the ledger owns kills)")
        # timeline
        ev = v.get("events", [])
        times = [e["t_s"] for e in ev]
        names = {e["event"]: e["t_s"] for e in ev}
        if times != sorted(times) or len(set(times)) != len(times):
            errs.append(f"{vid}: events must be in strictly rising time order")
        for need_ev in ("formation", "clash", "resolve_held", "cairn_crack", "cairn_fall"):
            if need_ev not in names:
                errs.append(f"{vid}: event '{need_ev}' is missing")
        if "resolve_held" in names and abs(names["resolve_held"] - resolve_t) > 0.01:
            errs.append(f"{vid}: resolve_held at {names['resolve_held']} s but fight_late resolves at {resolve_t} s")
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
            if need_s > have_s - TRAVEL_MARGIN_S:
                errs.append(f"{tag}: takes {need_s:.1f} s at {leg['speed']} speed, only {have_s:.1f} s available (margin {TRAVEL_MARGIN_S:g} s)")
            if leg["actor"] == "lead_pack":
                pack_end = leg
        if not pack_end or pack_end["to"] != "R.cairn" or pack_end["arrive_by_s"] > t["guard_fall_window_s"][1]:
            errs.append(f"{vid}: the lead pack's last leg must end at the loser's Cairn (canonical R.cairn) before it falls")
        elif "cairn_crack" in names and pack_end["start_s"] > names["cairn_crack"]:
            errs.append(f"{vid}: the lead pack starts its last leg after the Cairn cracks")
    return errs


CHECKS = [("structure", check_structure), ("ids", check_ids), ("range", check_range), ("mirror", check_mirror),
          ("lanes", check_lanes), ("spawns", check_spawns), ("towers", check_towers), ("camps", check_camps),
          ("water", check_water), ("spacing", check_spacing), ("stages", check_stages),
          ("units", check_units), ("tally", check_tally), ("variants", check_variants)]


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
        print(f"  held fight '{v['id']}'{' (default)' if v['id'] == d['late_fight_variants']['default'] else ''}:")
        for leg in v["legs"]:
            dist = ctx.shortest(leg["from"]).get(leg["to"], float("nan"))
            need = dist / (d["speeds"]["walk_u_s"] * _speed_mult(d, leg["speed"]))
            slack = leg["arrive_by_s"] - leg["start_s"] - need
            print(f"    {leg['actor']:<9} {leg['from']:<11} -> {leg['to']:<10} {dist:.3f} u {need:4.1f} s ({leg['speed']}) leaves {leg['start_s']:5.2f}, due {leg['arrive_by_s']:5.2f}, spare {slack:.1f} s")
    counts = {k: len(d[k]) for k in ("nodes", "edges", "towers", "camps", "zones", "stages")}
    counts["scoreboard_towers_per_side"] = d["tower_tally"]["per_side"]
    print("  counts:", counts)


def main(argv):
    show_report = "--report" in argv
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
    if show_report and problems_total == 0:
        report(ctx)
    print("RESULT:", "OK" if problems_total == 0 else f"{problems_total} problem(s)")
    return 0 if problems_total == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
