class_name Choreo
extends RefCounted
## Where every token is at show time t (Alpha 0.8 A-03, ARENA-MAP 7 and 12.3, ACTION-VOCABULARY 2.3). Built ONCE from a ShowScript
## and the map: each hero gets a list of timed orders (go to a place at walk, rotate or rush speed), the ledger's deaths and
## respawns are inserted, and the orders are turned into path segments over the map graph. pos(), alpha() and sprites_at() are pure
## functions of t, so a frame, a skip or a scrub all show the same picture (A3). Positions are canonical (Blue south).
##   heroes   "B.top" .. "R.sup": segments [{t0, t1, pts (canonical), cum (map units)}] and deaths [{t, rise}]
##   pack     the match winner's reserve pack (held endings only), six dots on the variant's legs
##   minions  ambient waves of 4 dots per lane and side (arena_map.json waves), walking from the gate to the lane's clash point
## The ending: when the match winner also wins fight_late, the data's default_clean (clean_gate); otherwise the held staging
## `held_variant` (default: the data's default, held_island; the tester switch of A-06 passes another one).

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const LANE_OF := {"top": "top", "mid": "mid", "bot": "bot", "sup": "bot"}
const CONTEST_OF := {"top": "top", "mid": "mid_lane", "bot": "bot"}
const WALK := 1.0
const ROTATE := 1.5
const RUSH := 2.0
const DISSOLVE := 0.5
const DEAD_FOR := 1.8          # death to rise at the pad
const RISE := 0.6
const STANCE_PX := 22.0         # a laner stands this far from the clash point on its own side
const SUP_BEHIND_PX := 40.0
const BIG_FROM := 20.25         # tokens shrink from 40 to 36 px for the group beats
## the team-fight formation (the held_island shape, ARENA-MAP 7.1), offsets from the zone centre for Blue (south); Red mirrors y
const FORM := {"top": Vector2(-0.0556, 0.0263), "sup": Vector2(0.0, 0.0263), "jg": Vector2(0.0556, 0.0263),
		"mid": Vector2(-0.0278, 0.0711), "bot": Vector2(0.0278, 0.0711)}
const PACK_OFFS := [Vector2(0, 0), Vector2(10, 0), Vector2(-10, 0), Vector2(5, 9), Vector2(-5, 9), Vector2(0, -9)]

var script_: ShowScript
var variant := ""
var ending: Dictionary = {}
var heroes: Dictionary = {}
var pack: Array = []           # segments of the pack centre
var pack_from := INF
var _lanes: Dictionary = {}    # lane id -> {pts: canonical, cum: units, len: units, data}


static func build(s: ShowScript, held_variant: String = "") -> Choreo:
	var c := Choreo.new()
	c.script_ = s
	c._build(held_variant)
	return c


static func other(side: String) -> String:
	return "R" if side == "B" else "B"


func _build(held_variant: String) -> void:
	var d := ArenaData.data()
	for ln in d["lanes"]:
		var pts: Array = []
		for id in ln["nodes"]:
			pts.append(ArenaData.node(String(id)))
		var cum: Array = [0.0]
		for i in range(1, pts.size()):
			cum.append(float(cum[i - 1]) + ArenaData.dist_u(pts[i - 1], pts[i]))
		_lanes[String(ln["id"])] = {"pts": pts, "cum": cum, "len": float(cum[cum.size() - 1]), "data": ln}
	var lf: Dictionary = d["late_fight_variants"]
	if script_.held:
		variant = held_variant if held_variant != "" else String(lf["default"])
	else:
		variant = String(lf["default_clean"])
	for v in lf["variants"]:
		if String(v["id"]) == variant:
			ending = v
	if ending.is_empty():
		variant = String(lf["default"]) if script_.held else String(lf["default_clean"])
		for v2 in lf["variants"]:
			if String(v2["id"]) == variant:
				ending = v2
	for side in ["B", "R"]:
		for slot in SLOTS:
			heroes[side + "." + slot] = _hero(side, slot)
	_pack()


# ---- geometry helpers ----------------------------------------------------------------------------------------------------------

## The point at arc fraction s (0 = Blue gate, 1 = Red gate) along a lane, canonical.
func lane_point(lane: String, s: float) -> Vector2:
	var L: Dictionary = _lanes[lane]
	var want := clampf(s, 0.0, 1.0) * float(L["len"])
	var pts: Array = L["pts"]
	var cum: Array = L["cum"]
	for i in range(1, pts.size()):
		if want <= float(cum[i]) + 1e-12:
			var seg := float(cum[i]) - float(cum[i - 1])
			var f := 0.0 if seg <= 0.0 else (want - float(cum[i - 1])) / seg
			return (pts[i - 1] as Vector2).lerp(pts[i], f)
	return pts[pts.size() - 1]


func lane_len_px(lane: String) -> float:
	return float(_lanes[lane]["len"]) * ArenaData.H


## The lane's clash point (arc fraction) at the end of its build: the winner shifts it toward the loser by |c| * max_shift_s.
func clash_s(lane: String) -> float:
	var c := float(script_.contests[CONTEST_OF[lane]]["c"])
	var L: Dictionary = _lanes[lane]["data"]
	return float(L["clash"]["neutral_s"]) + signf(c) * absf(c) * float(L["clash"]["max_shift_s"])


## The clash point at show time t: neutral until 4.0 s, eased to its shifted place at the lane's resolve, then held.
func clash_s_at(lane: String, t: float) -> float:
	var n := float(_lanes[lane]["data"]["clash"]["neutral_s"])
	var rt := float(ShowScript.RESOLVE[CONTEST_OF[lane]])
	return n + (clash_s(lane) - n) * ShowScript.ease01((t - 4.0) / (rt - 4.0))


func _stance(side: String, slot: String, s_c: float) -> Vector2:
	var lane: String = LANE_OF[slot]
	var back := STANCE_PX + (SUP_BEHIND_PX if slot == "sup" else 0.0)
	var ds := back / lane_len_px(lane)
	return lane_point(lane, s_c - ds if side == "B" else s_c + ds)


func _form(side: String, slot: String, centre: Vector2) -> Vector2:
	var o: Vector2 = FORM[slot]
	return centre + Vector2(o.x, o.y if side == "B" else -o.y)


## A point of the ending's data: the data's frame has the match winner W in the south; mirror when W is Red.
func _w_frame(p: Vector2) -> Vector2:
	return p if script_.winner == "B" else Vector2(p.x, 1.0 - p.y)


func _w_node(id: String) -> String:
	if script_.winner == "B":
		return id
	if id.begins_with("B."):
		return "R." + id.substr(2)
	if id.begins_with("R."):
		return "B." + id.substr(2)
	return id


static func nearest_node(p: Vector2) -> String:
	var best := ""
	var bd := INF
	for id in ArenaData.node_ids():
		var dd := ArenaData.dist_u(p, ArenaData.node(String(id)))
		if dd < bd:
			bd = dd
			best = String(id)
	return best


## A walk from point a to point b over the graph: a, the nodes between the nearest nodes of a and b, b.
static func route(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array([a])
	if ArenaData.dist_u(a, b) < 0.06:
		out.append(b)
		return out
	var na := nearest_node(a)
	var nb := nearest_node(b)
	var ids := ArenaData.path(na, nb)
	for i in ids.size():
		var q := ArenaData.node(String(ids[i]))
		# skip a first node that lies behind the start, and a last node that lies past the end
		if i == 0 and ids.size() > 1 and ArenaData.dist_u(a, ArenaData.node(String(ids[1]))) < ArenaData.dist_u(q, ArenaData.node(String(ids[1]))):
			continue
		if i == ids.size() - 1 and ids.size() > 1 and ArenaData.dist_u(ArenaData.node(String(ids[i - 1])), b) < ArenaData.dist_u(ArenaData.node(String(ids[i - 1])), q):
			continue
		out.append(q)
	out.append(b)
	return out


static func _seg(t0: float, pts: PackedVector2Array, mult: float) -> Dictionary:
	var cum: Array = [0.0]
	for i in range(1, pts.size()):
		cum.append(float(cum[i - 1]) + ArenaData.dist_u(pts[i - 1], pts[i]))
	var v := float(ArenaData.data()["speeds"]["walk_u_s"]) * mult
	var total := float(cum[cum.size() - 1])
	return {"t0": t0, "t1": t0 + total / v, "pts": pts, "cum": cum, "v": v}


static func _at(seg: Dictionary, t: float) -> Vector2:
	var pts: PackedVector2Array = seg["pts"]
	if t >= float(seg["t1"]) or pts.size() == 1:
		return pts[pts.size() - 1]
	var want := maxf(0.0, t - float(seg["t0"])) * float(seg["v"])
	var cum: Array = seg["cum"]
	for i in range(1, pts.size()):
		if want <= float(cum[i]):
			var l := float(cum[i]) - float(cum[i - 1])
			return pts[i - 1].lerp(pts[i], 0.0 if l <= 0.0 else (want - float(cum[i - 1])) / l)
	return pts[pts.size() - 1]


static func _pos_in(segs: Array, t: float, start: Vector2) -> Vector2:
	var p := start
	for s in segs:
		if float(s["t0"]) > t:
			break
		p = _at(s, t)
	return p


# ---- the orders of one hero -----------------------------------------------------------------------------------------------------

func _orders(side: String, slot: String) -> Array:
	var o: Array = []    # [t, kind, target, mult]
	var w := script_.winner
	if slot == "jg":
		var own := side
		o.append([1.0, "go", ArenaData.node(own + ".w1"), WALK])
		o.append([6.5, "go", ArenaData.node(own + ".w2"), WALK])
		o.append([11.0, "go", ArenaData.node(own + ".w3"), WALK])
		var mb := ArenaData.node("N.mossback")
		var jwin := String(script_.contests["jungle"]["win"])
		var toward := Vector2(0, -0.035) if side == "B" else Vector2(0, 0.035)    # toward the enemy half
		var at := mb - toward if side != jwin else mb + toward * 0.6    # the winner crosses the centre line
		o.append([15.0, "go", at, WALK])
	else:
		var lane: String = LANE_OF[slot]
		o.append([1.0, "go", _stance(side, slot, float(_lanes[lane]["data"]["clash"]["neutral_s"])), WALK])
		o.append([8.0, "go", _stance(side, slot, clash_s(lane)), WALK])
	o.append([20.25, "go", _form(side, slot, ArenaData.node("N.stoneback")), ROTATE])
	o.append([34.5, "go", _form(side, slot, ArenaData.node("N.mossback")), ROTATE])
	o.append([51.0, "go", _form(side, slot, ArenaData.node("N.moonhulk")), ROTATE])
	# the ending, from the variant's data (W south in the data's frame)
	var role := "W" if side == w else "U"
	var f: Dictionary = ending.get("formation", {})
	var mine := Vector2.ZERO
	if f.has(role):
		var raw: Array = f[role][slot]
		mine = _w_frame(Vector2(float(raw[0]), float(raw[1])))
	match variant:
		"held_island":
			o.append([61.0, "go", mine, WALK])
		_:
			var legs: Array = ending.get("legs", [])
			var actor := role + "_heroes"
			var placed := mine
			var first := true
			for lg in legs:
				if String(lg["actor"]) != actor:
					continue
				var mult := _mult(String(lg["speed"]))
				if first:
					o.append([float(lg["start_s"]), "go", mine, mult])
					first = false
				else:
					# a later leg moves the whole formation by the leg's node step, so the line keeps its spacing
					var from := ArenaData.node(_w_node(String(lg["from"])))
					var to := ArenaData.node(_w_node(String(lg["to"])))
					var nxt := placed + (to - from)
					o.append([float(lg["start_s"]), "go", nxt, mult])
					placed = nxt
	# deaths from the ledger
	for e in script_.kill_events:
		if ShowScript.other(String(e["side"])) == side and String(e["victim"]) == slot:
			o.append([float(e["t"]), "die", Vector2.ZERO, 0.0])
	o.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and String(a[1]) == "die"))
	return o


func _mult(speed: String) -> float:
	match speed:
		"rotate":
			return ROTATE
		"rush":
			return RUSH
	return WALK


func _hero(side: String, slot: String) -> Dictionary:
	var pad := ArenaData.spawn(side, slot)
	var segs: Array = []
	var deaths: Array = []
	var dead_until := -INF
	var last_target := pad
	var last_mult := WALK
	var catching_until := -INF    # a hero that rose runs at rush speed until it has caught up with its team
	var events := _orders(side, slot)
	var i := 0
	# respawns are inserted as they happen, so walk the list with an explicit queue
	var queue: Array = events.duplicate()
	while i < queue.size():
		var ev: Array = queue[i]
		i += 1
		var t := float(ev[0])
		match String(ev[1]):
			"go":
				last_target = ev[2]
				last_mult = float(ev[3])
				if t < dead_until:
					continue
				var m := last_mult
				if t < catching_until:
					m = maxf(m, RUSH)
				_go(segs, pad, t, last_target, m)
				if t < catching_until:
					catching_until = float(segs[segs.size() - 1]["t1"])
			"die":
				if t < dead_until:
					continue    # already down (a second fall inside the respawn time shows as one)
				_stop(segs, pad, t)
				var rise := t + DEAD_FOR
				deaths.append({"t": t, "rise": rise, "at": _pos_in(segs, t, pad)})
				dead_until = rise
				var r := [rise, "rise", Vector2.ZERO, 0.0]
				var k := i
				while k < queue.size() and float(queue[k][0]) <= rise:
					k += 1
				queue.insert(k, r)
			"rise":
				# HF3: in held_island nobody walks, so a hero that falls there rises at its own formation point
				var at := last_target if variant == "held_island" and t >= 61.0 else pad
				segs.append({"t0": t, "t1": t, "pts": PackedVector2Array([at]), "cum": [0.0], "v": 1.0})
				_go(segs, pad, t, last_target, RUSH)
				catching_until = float(segs[segs.size() - 1]["t1"])
	return {"side": side, "slot": slot, "pad": pad, "segs": segs, "deaths": deaths}


## Cut the moving segment at t (the hero stops where it is).
func _stop(segs: Array, pad: Vector2, t: float) -> void:
	if segs.is_empty():
		return
	var s: Dictionary = segs[segs.size() - 1]
	if t < float(s["t1"]):
		var p := _at(s, t)
		var pts: PackedVector2Array = s["pts"]
		var keep := PackedVector2Array()
		var want := (t - float(s["t0"])) * float(s["v"])
		var cum: Array = s["cum"]
		for j in pts.size():
			if float(cum[j]) < want:
				keep.append(pts[j])
		keep.append(p)
		segs[segs.size() - 1] = _seg(float(s["t0"]), keep, float(s["v"]) / float(ArenaData.data()["speeds"]["walk_u_s"]))


func _go(segs: Array, pad: Vector2, t: float, target: Vector2, mult: float) -> void:
	_stop(segs, pad, t)
	var p := _pos_in(segs, t, pad)
	segs.append(_seg(t, route(p, target), mult))


# ---- the reserve pack ---------------------------------------------------------------------------------------------------------

func _pack() -> void:
	pack = []
	pack_from = INF
	if String(ending.get("kind", "")) != "held":
		return
	var cur := Vector2.ZERO
	for lg in ending.get("legs", []):
		if String(lg["actor"]) != "lead_pack":
			continue
		var a := ArenaData.node(_w_node(String(lg["from"])))
		var b := ArenaData.node(_w_node(String(lg["to"])))
		if pack.is_empty():
			cur = a
			pack_from = float(lg["start_s"])
		pack.append(_seg(float(lg["start_s"]), route(cur, b), _mult(String(lg["speed"]))))
		cur = b


# ---- queries --------------------------------------------------------------------------------------------------------------------

func pos(key: String, t: float) -> Vector2:
	var h: Dictionary = heroes[key]
	for d in h["deaths"]:
		if t >= float(d["t"]) and t < float(d["rise"]):
			return d["at"]
	return _pos_in(h["segs"], t, h["pad"])


## 0 to 1: rising from the pad at the start, dissolving at a death, hidden while down, rising again at the pad.
func alpha(key: String, t: float) -> float:
	if t < RISE:
		return clampf(t / RISE, 0.0, 1.0)
	for d in heroes[key]["deaths"]:
		var dt := float(d["t"])
		var rt := float(d["rise"])
		if t >= dt and t < dt + DISSOLVE:
			return 1.0 - (t - dt) / DISSOLVE
		if t >= dt + DISSOLVE and t < rt:
			return 0.0
		if t >= rt and t < rt + RISE:
			return (t - rt) / RISE
	return 1.0


func alive(key: String, t: float) -> bool:
	for d in heroes[key]["deaths"]:
		if t >= float(d["t"]) and t < float(d["rise"]):
			return false
	return true


func token_px(t: float) -> float:
	return 36.0 if t >= BIG_FROM else 40.0


func pack_pos(t: float) -> Vector2:
	if pack.is_empty() or t < pack_from:
		return Vector2(-1, -1)
	return _pos_in(pack, t, (pack[0]["pts"] as PackedVector2Array)[0])


func pack_visible(t: float) -> bool:
	return not pack.is_empty() and t >= pack_from and t < ShowScript.CAIRN_T


## Ambient minion dots: [[side, canonical point]]. Waves of `size` leave each gate every interval from first_spawn_s until 60 s
## and vanish when they reach the lane's clash point.
func minions_at(t: float) -> Array:
	var wv: Dictionary = ArenaData.data()["waves"]
	var out: Array = []
	var every := float(wv["interval_s"])
	var v := float(wv["speed_u_s"])
	var n := int(wv["size"])
	for lane in ["top", "mid", "bot"]:
		var L := float(_lanes[lane]["len"])
		var sc := clash_s_at(lane, t)
		var spawn := float(wv["first_spawn_s"])
		while spawn <= minf(t, 60.0):
			var run := (t - spawn) * v / L
			for side in ["B", "R"]:
				for k in n:
					var back := float(k) * (12.0 / ArenaData.H) / L
					var s := run - back
					if s < 0.0:
						continue
					var at_s := s if side == "B" else 1.0 - s
					if (side == "B" and at_s >= sc - 0.01) or (side == "R" and at_s <= sc + 0.01):
						continue
					out.append([side, lane_point(lane, at_s)])
			spawn += every
	return out


## Everything to draw at t: [cell key, canonical point, size px, alpha]; cells are ArenaMap.ICON keys.
## `offs`: hero key -> canonical offset (ArenaFx lunges, 0.8.1).
func sprites_at(t: float, my_side: String, offs: Dictionary = {}) -> Array:
	var out: Array = []
	for m in minions_at(t):
		out.append(["minion_" + ("you" if m[0] == my_side else "them"), m[1], 14.0, 0.85])
	if pack_visible(t):
		var c := pack_pos(t)
		var who := "minion_" + ("you" if script_.winner == my_side else "them")
		for off in PACK_OFFS:
			out.append([who, c + Vector2(off.x / ArenaData.W, off.y / ArenaData.H), 14.0, 1.0])
	var px := token_px(t)
	for key in heroes:
		var a := alpha(key, t)
		if a <= 0.0:
			continue
		var h: Dictionary = heroes[key]
		var who2 := "you" if String(h["side"]) == my_side else "them"
		out.append(["hero_%s_%s" % [who2, h["slot"]], pos(key, t) + (offs.get(key, Vector2.ZERO) as Vector2), px, a])
	return out
