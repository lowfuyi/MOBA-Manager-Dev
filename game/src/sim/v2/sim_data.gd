class_name SimData
extends RefCounted
## Match Sim v2 static data (MATCH-SIM-V2-DESIGN sections 3, 4, 5.2 and 11): parameters, kits, items and the map graph with
## all-pairs shortest paths, loaded once and cached. Nothing here holds nodes (no scene objects in static vars).
## Deterministic helpers: `ih_normal` draws a standard normal from four uniforms (Irwin-Hall), so no libm function is
## used anywhere in the v2 decision path (design Q1).

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const SIDES := ["B", "R"]
const SQRT3 := 1.7320508075688772

static var _p: Dictionary = {}
static var _kits: Dictionary = {}
static var _items: Dictionary = {}
static var _items_doc: Dictionary = {}
static var _heroes: Dictionary = {}
static var _map: Dictionary = {}
static var XS := 0.9474


static func params() -> Dictionary:
	if _p.is_empty():
		var d = DataLoader.load_json("res://data/sim_v2_params.json")
		_p = d if d is Dictionary else {}
	return _p


static func f(key: String) -> float:
	return float(params()[key])


static func kits() -> Dictionary:
	if _kits.is_empty():
		var d = DataLoader.load_json("res://data/kits_v2.json")
		for k in d["kits"]:
			_kits[String(k["id"])] = k
	return _kits


static func kit(hid: String) -> Dictionary:
	return kits()[hid]


static func items_doc() -> Dictionary:
	if _items_doc.is_empty():
		var d = DataLoader.load_json("res://data/items_v2.json")
		_items_doc = d if d is Dictionary else {}
		for it in _items_doc["items"]:
			_items[String(it["id"])] = it
	return _items_doc


static func items() -> Dictionary:
	items_doc()
	return _items


static func item(iid: String) -> Dictionary:
	return items()[iid]


static func heroes() -> Dictionary:
	if _heroes.is_empty():
		for h in DataLoader.load_json("res://data/heroes.json"):
			_heroes[String(h["id"])] = h
	return _heroes


static func ih_normal(rng: Pcg32) -> float:
	return (rng.next_float() + rng.next_float() + rng.next_float() + rng.next_float() - 2.0) * SQRT3


static func other(side: String) -> String:
	return "R" if side == "B" else "B"


# ---------------------------------------------------------------- map graph
## {"pos": {id: Vector2}, "idx": {id: i}, "ids": [id], "dist": PackedFloat64Array n*n, "next": PackedInt32Array n*n,
##  "lanes": {lane: {"nodes": [ids], "s": [s per node], "len": u}}, "towers": [...], "camps": [...], "objectives": {...},
##  "spawn": {"B": {slot: Vector2}}, "cairn": {"B": Vector2}, "base_node": {"B": id}, "x_scale": float}
static func map() -> Dictionary:
	if not _map.is_empty():
		return _map
	var d: Dictionary = DataLoader.load_json("res://data/arena_map.json")
	var xs := float(d["arena"]["x_scale"])
	var pos := {}
	var ids: Array = []
	for n in d["nodes"]:
		var id := String(n["id"])
		pos[id] = Vector2(float(n["p"][0]), float(n["p"][1]))
		ids.append(id)
	var idx := {}
	for i in ids.size():
		idx[ids[i]] = i
	var n_ := ids.size()
	var dist := PackedFloat64Array()
	dist.resize(n_ * n_)
	var nxt := PackedInt32Array()
	nxt.resize(n_ * n_)
	for i in n_:
		for j in n_:
			dist[i * n_ + j] = 0.0 if i == j else INF
			nxt[i * n_ + j] = j if i == j else -1
	for e in d["edges"]:
		var a: int = idx[String(e["a"])]
		var b: int = idx[String(e["b"])]
		var w := du(pos[ids[a]], pos[ids[b]], xs)
		if w < dist[a * n_ + b]:
			dist[a * n_ + b] = w
			dist[b * n_ + a] = w
			nxt[a * n_ + b] = b
			nxt[b * n_ + a] = a
	for k in n_:
		for i in n_:
			var dik := dist[i * n_ + k]
			if dik == INF:
				continue
			for j in n_:
				var alt := dik + dist[k * n_ + j]
				if alt < dist[i * n_ + j]:
					dist[i * n_ + j] = alt
					nxt[i * n_ + j] = nxt[i * n_ + k]
	var lanes := {}
	for ln in d["lanes"]:
		var nodes: Array = ln["nodes"]
		var cum := [0.0]
		for i in range(1, nodes.size()):
			cum.append(float(cum[i - 1]) + du(pos[String(nodes[i - 1])], pos[String(nodes[i])], xs))
		var total: float = cum[cum.size() - 1]
		var s: Array = []
		for c in cum:
			s.append(float(c) / total)
		lanes[String(ln["id"])] = {"nodes": nodes, "s": s, "len": total}
	var towers: Array = []
	for t in d["towers"]:
		var tw := {"id": String(t["id"]), "side": String(t["side"]), "lane": String(t.get("lane", "")), "tier": String(t["tier"]),
				"pos": Vector2(float(t["p"][0]), float(t["p"][1]))}
		# s along the lane from Blue's gate (0) to Red's gate (1), as the data already gives it for both sides
		if t.get("s") != null:
			tw["s"] = float(t["s"])
		else:
			tw["s"] = 0.0 if tw["side"] == "B" else 1.0
		towers.append(tw)
	var camps: Array = []
	for c in d["camps"]:
		camps.append({"id": String(c["id"]), "side": String(c["side"]), "kind": String(c["kind"]), "node": String(c["node"]),
				"pos": Vector2(float(c["p"][0]), float(c["p"][1]))})
	var objs := {}
	for o in d["objectives"]:
		if String(o["kind"]) in ["early_objective", "late_objective"]:
			var oid := String(o["id"]).trim_prefix("N.")
			objs[oid] = {"node": String(o["node"]), "pos": Vector2(float(o["p"][0]), float(o["p"][1]))}
	objs["mossback"] = {"node": "N.mossback", "pos": pos["N.mossback"]}
	var spawn := {}
	var cairn := {}
	for side in SIDES:
		spawn[side] = {}
		for s2 in SLOTS:
			var sp: Array = d["spawns"][side][s2]
			spawn[side][s2] = Vector2(float(sp[0]), float(sp[1]))
		var cp: Array = d["bases"][side]["cairn"]
		cairn[side] = Vector2(float(cp[0]), float(cp[1]))
	XS = xs
	_map = {"pos": pos, "idx": idx, "ids": ids, "n": n_, "dist": dist, "next": nxt, "lanes": lanes, "towers": towers,
			"camps": camps, "objectives": objs, "spawn": spawn, "cairn": cairn, "x_scale": xs,
			"base_node": {"B": "B.cairn", "R": "R.cairn"}}
	return _map


## Distance in map units between two canonical points (x is scaled: the arena is wider in data than in units).
static func du(a: Vector2, b: Vector2, xs: float = -1.0) -> float:
	if xs < 0.0:
		xs = XS
	var dx := (a.x - b.x) * xs
	var dy := a.y - b.y
	return sqrt(dx * dx + dy * dy)


static func du2(a: Vector2, b: Vector2) -> float:
	var dx := (a.x - b.x) * XS
	var dy := a.y - b.y
	return dx * dx + dy * dy


static func node_pos(id: String) -> Vector2:
	return _map["pos"][id] if not _map.is_empty() else map()["pos"][id]


static func path_len(a: String, b: String) -> float:
	var m := map()
	return float(m["dist"][int(m["idx"][a]) * int(m["n"]) + int(m["idx"][b])])


## Node ids from a to b inclusive (shortest path).
static func path(a: String, b: String) -> Array:
	var m := map()
	var n_: int = m["n"]
	var ids: Array = m["ids"]
	var i: int = m["idx"][a]
	var j: int = m["idx"][b]
	var out: Array = [a]
	var guard := 0
	while i != j and guard < 200:
		i = m["next"][i * n_ + j]
		if i < 0:
			break
		out.append(ids[i])
		guard += 1
	return out


## The lane node closest to lane position s (0 = Blue gate, 1 = Red gate) and the point itself.
static func lane_point(lane: String, s: float) -> Vector2:
	var ln: Dictionary = map()["lanes"][lane]
	var nodes: Array = ln["nodes"]
	var ss: Array = ln["s"]
	s = clampf(s, 0.0, 1.0)
	for i in range(1, nodes.size()):
		if s <= float(ss[i]) or i == nodes.size() - 1:
			var s0 := float(ss[i - 1])
			var s1 := float(ss[i])
			var k := 0.0 if s1 <= s0 else (s - s0) / (s1 - s0)
			return node_pos(String(nodes[i - 1])).lerp(node_pos(String(nodes[i])), clampf(k, 0.0, 1.0))
	return node_pos(String(nodes[nodes.size() - 1]))


static func lane_node_near(lane: String, s: float) -> String:
	var ln: Dictionary = map()["lanes"][lane]
	var best := ""
	var bd := INF
	for i in (ln["nodes"] as Array).size():
		var dd := absf(float(ln["s"][i]) - s)
		if dd < bd:
			bd = dd
			best = String(ln["nodes"][i])
	return best


static var _nn_cache: Dictionary = {}


## Nearest graph node to a canonical point (cached on a 0.005 grid; the answer for a cell is computed from the cell's
## first point exactly, so the cache never changes a result already computed for that point).
static func nearest_node(p: Vector2) -> String:
	var ck := int(p.x * 2000.0) * 100000 + int(p.y * 2000.0)
	if _nn_cache.has(ck):
		return _nn_cache[ck]
	var id := _nearest_node(p)
	_nn_cache[ck] = id
	return id


static func _nearest_node(p: Vector2) -> String:
	var m := map()
	var best := ""
	var bd := INF
	for id in m["ids"]:
		var dd := du(p, m["pos"][id])
		if dd < bd:
			bd = dd
			best = id
	return best
