class_name ArenaData
extends RefCounted
## Wrenfell, read once from game/data/arena_map.json (the Level / World Designer's authority, ARENA-MAP.md). Positions are in the
## canonical frame: x 0..1 west to east (720 px), y 0..1 north to south (760 px), Blue (B) south, Red (R) north. `screen(p, flip)`
## gives arena pixels; the arena flips y when the player is Red, so the player's base is always at the bottom (ARENA-MAP 4: a mirror,
## never a rotation; top lane stays on the left).

const W := 720.0
const H := 760.0

static var _d: Dictionary = {}
static var _nodes: Dictionary = {}
static var _adj: Dictionary = {}


static func data() -> Dictionary:
	if _d.is_empty():
		var d = DataLoader.load_json("res://data/arena_map.json")
		_d = d if d is Dictionary else {}
		_nodes = {}
		for n in _d.get("nodes", []):
			_nodes[String(n["id"])] = Vector2(float(n["p"][0]), float(n["p"][1]))
		_adj = {}
		for e in _d.get("edges", []):
			var a := String(e["a"])
			var b := String(e["b"])
			if not _adj.has(a):
				_adj[a] = []
			if not _adj.has(b):
				_adj[b] = []
			(_adj[a] as Array).append(b)
			(_adj[b] as Array).append(a)
	return _d


static func node(id: String) -> Vector2:
	data()
	return _nodes.get(id, Vector2(0.5, 0.5))


static func has_node(id: String) -> bool:
	data()
	return _nodes.has(id)


static func node_ids() -> Array:
	data()
	return _nodes.keys()


static func neighbours(id: String) -> Array:
	data()
	return (_adj.get(id, []) as Array).duplicate()


## Arena pixels of a canonical point; `flip` mirrors y (the player is Red).
static func screen(p: Vector2, flip: bool) -> Vector2:
	return Vector2(p.x * W, (1.0 - p.y if flip else p.y) * H)


## Map distance in units between two canonical points (ARENA-MAP 5: dist = hypot(dx * 0.9474, dy)).
static func dist_u(a: Vector2, b: Vector2) -> float:
	return Vector2((b.x - a.x) * 0.9474, b.y - a.y).length()


## The shortest walk between two nodes over the edges (Dijkstra on map units): [node ids] from a to b, [] if none.
static func path(a: String, b: String) -> Array:
	data()
	if a == b:
		return [a]
	var dist := {a: 0.0}
	var prev := {}
	var todo := [a]
	while not todo.is_empty():
		var best := 0
		for i in todo.size():
			if float(dist[todo[i]]) < float(dist[todo[best]]):
				best = i
		var cur: String = todo[best]
		todo.remove_at(best)
		if cur == b:
			break
		for nb in neighbours(cur):
			var nd := float(dist[cur]) + dist_u(node(cur), node(nb))
			if not dist.has(nb) or nd < float(dist[nb]) - 1e-12:
				dist[nb] = nd
				prev[nb] = cur
				if not todo.has(nb):
					todo.append(nb)
	if not prev.has(b):
		return []
	var out: Array = [b]
	while out[0] != a:
		out.push_front(prev[out[0]])
	return out


static func path_len_u(ids: Array) -> float:
	var t := 0.0
	for i in range(1, ids.size()):
		t += dist_u(node(String(ids[i - 1])), node(String(ids[i])))
	return t


static func lanes() -> Array:
	return data().get("lanes", [])


static func towers() -> Array:
	return data().get("towers", [])


static func tower(id: String) -> Dictionary:
	for t in towers():
		if String(t["id"]) == id:
			return t
	return {}


static func camps() -> Array:
	return data().get("camps", [])


static func objectives() -> Array:
	return data().get("objectives", [])


static func spawn(side: String, slot: String) -> Vector2:
	var s: Array = data()["spawns"][side][slot]
	return Vector2(float(s[0]), float(s[1]))


static func zone(id: String) -> Dictionary:
	for z in data().get("zones", []):
		if String(z["id"]) == id:
			return z
	return {}


static func walk_px_s() -> float:
	return float(data()["speeds"]["walk_u_s"]) * H
