class_name ArenaPlayer
extends RefCounted
## Arena v2 playback (MATCH-SIM-V2-DESIGN 7 and 10): reads a Match Sim v2 result's event log and answers "what is on the map at
## game time t" as pure functions of t, so a frame, a skip or a pause all show the same truthful picture. It never calls the
## simulator and never writes the result (rule A1). It also maps show time to game time (the tunable show length, quiet
## stretches faster) and tells the follow camera where the action is.
##   pos(key, t)       a hero's canonical position: the sim's sampled track interpolated; inside a fight, spread into rows
##   alive(key, t)     from the kill and respawn events
##   hp(key, t)        fight health samples inside fights, the track's health elsewhere
##   towers_down(t)    the structure ids that have fallen by t
##   objective(oid,t)  "up", "down" or the taking side
##   score(t)          kills, towers and the gold lead by t (the scoreboard; equals the result at the end)
##   effects(t)        casts and kills within their short display windows
##   focus(t)          the follow camera's target: a fight, then an objective take, then a siege, then the player's team

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const CAST_S := 0.6
const KILL_S := 1.4

var res: Dictionary
var my_side := "B"
var log: Dictionary
var len_s := 0.0
var every := 2.0
var track: Dictionary = {}
var fronts: Dictionary = {}
var kills: Array = []          # [t, killer, victim, assists]
var respawns: Dictionary = {}  # key -> [t, ...]
var deaths: Dictionary = {}    # key -> [t, ...]
var fights: Array = []         # {id, t0, t1, kind, keys, hp: [[t, {key: f}]]}
var casts: Array = []          # [t, key, ability_id, target_key, hit]
var towers: Array = []         # [t, id, by_side]
var objs: Array = []           # [t, oid, side]
var obj_up: Array = []         # [t, oid]
var calls: Array = []          # [t, side, kind, target]
var intents: Array = []        # [t, key, intent, target]
var plan_ev: Array = []        # [t, side, name]
var end_t := 0.0
var winner := "B"
var hero_of: Dictionary = {}   # key -> hero id
var levels: Dictionary = {}    # key -> [[t, level], ...] from the log's level events
var buys: Dictionary = {}      # key -> [[t, item id], ...] from the log's buy events
var _pace: Array = []          # [[show_t0, game_t0, rate], ...] rate = game seconds per show second
var show_len := 180.0


static func build(p_res: Dictionary, p_my_side: String) -> ArenaPlayer:
	var a := ArenaPlayer.new()
	a.res = p_res
	a.my_side = p_my_side
	a._build()
	return a


func _build() -> void:
	var sim: Dictionary = res["sim"]
	log = sim["log"]
	len_s = float(log["len_s"])
	every = float(log["track_every"])
	track = log["track"]
	fronts = log["fronts"]
	winner = "B" if bool(res["blue_won"]) else "R"
	for k in sim["per"]:
		hero_of[k] = String(sim["per"][k]["hero"])
	var open_fights := {}
	for e in log["ev"]:
		var t := float(e[0])
		match String(e[1]):
			"kill":
				kills.append([t, String(e[2]), String(e[3]), e[4]])
				_add(deaths, String(e[3]), t)
			"respawn":
				_add(respawns, String(e[2]), t)
			"fight":
				var f := {"id": int(e[2]), "t0": t, "t1": t, "kind": String(e[3]), "keys": e[4], "hp": []}
				open_fights[int(e[2])] = f
				fights.append(f)
			"fight_end":
				if open_fights.has(int(e[2])):
					open_fights[int(e[2])]["t1"] = t
			"hp":
				if open_fights.has(int(e[2])):
					(open_fights[int(e[2])]["hp"] as Array).append([t, e[3]])
			"cast":
				casts.append([t, String(e[2]), String(e[3]), String(e[4]), bool(e[5])])
			"tower":
				towers.append([t, String(e[2]), String(e[3])])
			"objective":
				objs.append([t, String(e[2]), String(e[3])])
			"obj_up":
				obj_up.append([t, String(e[2])])
			"call":
				calls.append([t, String(e[2]), String(e[3]), String(e[4])])
			"intent":
				intents.append([t, String(e[2]), String(e[3]), String(e[4])])
			"plan":
				plan_ev.append([t, String(e[2]), String(e[3])])
			"level":
				if not levels.has(String(e[2])):
					levels[String(e[2])] = []
				(levels[String(e[2])] as Array).append([t, int(e[3])])
			"buy":
				if not buys.has(String(e[2])):
					buys[String(e[2])] = []
				(buys[String(e[2])] as Array).append([t, String(e[3])])
			"end":
				end_t = t
	if end_t <= 0.0:
		end_t = len_s
	_build_pace()


func _add(d: Dictionary, k: String, t: float) -> void:
	if not d.has(k):
		d[k] = []
	(d[k] as Array).append(t)


static func side_of(key: String) -> String:
	return key.substr(0, 1)


# ---------------------------------------------------------------- pacing (the tunable show length)
## Real seconds for this game at normal speed: show_seconds (data) scaled gently by the game's length (a long game takes
## somewhat longer to watch, not proportionally), quiet stretches up to show_quiet_max times faster (design 10).
func _build_pace() -> void:
	var p := SimData.params()
	var median := float(p["show_median_len_s"])
	var target := float(p["show_seconds"]) * clampf(sqrt(len_s / median), 0.75, 1.35)
	var quiet_k := float(p["show_quiet_max"])
	# busy windows: fights (from 2 s before), objectives and towers (4 s before, 2 s after)
	var busy: Array = []
	for f in fights:
		busy.append([maxf(0.0, float(f["t0"]) - 2.0), float(f["t1"]) + 1.5])
	for o in objs:
		busy.append([maxf(0.0, float(o[0]) - 4.0), float(o[0]) + 2.0])
	for tw in towers:
		busy.append([maxf(0.0, float(tw[0]) - 4.0), float(tw[0]) + 2.0])
	busy.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var merged: Array = []
	for b in busy:
		if not merged.is_empty() and float(b[0]) <= float(merged[merged.size() - 1][1]):
			merged[merged.size() - 1][1] = maxf(float(merged[merged.size() - 1][1]), float(b[1]))
		else:
			merged.append([float(b[0]), minf(float(b[1]), end_t)])
	var busy_len := 0.0
	for m in merged:
		busy_len += maxf(0.0, float(m[1]) - float(m[0]))
	var quiet_len := maxf(0.0, end_t - busy_len)
	# base rate r (game s per show s) in busy time, r * quiet_k in quiet time: busy/r + quiet/(r k) = target
	var r := (busy_len + quiet_len / quiet_k) / maxf(1.0, target)
	r = maxf(r, 0.5)
	_pace = []
	var st := 0.0
	var gt := 0.0
	for m in merged:
		if float(m[0]) > gt:
			_pace.append([st, gt, r * quiet_k])
			st += (float(m[0]) - gt) / (r * quiet_k)
			gt = float(m[0])
		_pace.append([st, gt, r])
		st += (float(m[1]) - gt) / r
		gt = float(m[1])
	if gt < end_t:
		_pace.append([st, gt, r * quiet_k])
		st += (end_t - gt) / (r * quiet_k)
	show_len = st


## Game time at show time s (s from 0 to show_len).
func game_t(s: float) -> float:
	if _pace.is_empty():
		return clampf(s, 0.0, end_t)
	var seg: Array = _pace[0]
	for x in _pace:
		if float(x[0]) <= s:
			seg = x
		else:
			break
	return clampf(float(seg[1]) + (s - float(seg[0])) * float(seg[2]), 0.0, end_t)


## Show time at game time g (inverse of game_t).
func show_t(g: float) -> float:
	var seg: Array = _pace[0] if not _pace.is_empty() else [0.0, 0.0, 1.0]
	for x in _pace:
		if float(x[1]) <= g:
			seg = x
		else:
			break
	return float(seg[0]) + (g - float(seg[1])) / float(seg[2])


# ---------------------------------------------------------------- state at t
func _sample(key: String, t: float) -> Array:
	var tr: PackedFloat32Array = track[key]
	var n := tr.size() / 4
	if n == 0:
		return [Vector2(0.5, 0.5), 1.0, 1.0]
	var x := clampf(t / every, 0.0, float(n - 1))
	var i := int(x)
	var j := mini(n - 1, i + 1)
	var k := x - float(i)
	var a := Vector2(tr[i * 4], tr[i * 4 + 1])
	var b := Vector2(tr[j * 4], tr[j * 4 + 1])
	# a respawn (dead -> alive) or a recall jump is not walked: snap
	if tr[i * 4 + 3] < 0.5 or SimData.du(a, b) > 0.12:
		return [b if k > 0.5 else a, lerpf(tr[i * 4 + 2], tr[j * 4 + 2], k), tr[i * 4 + 3]]
	return [a.lerp(b, k), lerpf(tr[i * 4 + 2], tr[j * 4 + 2], k), tr[i * 4 + 3]]


func alive(key: String, t: float) -> bool:
	var last_d := -INF
	for d in deaths.get(key, []):
		if float(d) <= t:
			last_d = float(d)
	if last_d == -INF:
		return true
	for r in respawns.get(key, []):
		if float(r) > last_d and float(r) <= t:
			return true
	return false


## The fight a hero is in at t, or {}.
func fight_of(key: String, t: float) -> Dictionary:
	for f in fights:
		if float(f["t0"]) <= t and t <= float(f["t1"]) and key in f["keys"]:
			return f
	return {}


func pos(key: String, t: float) -> Vector2:
	var smp := _sample(key, t)
	var p: Vector2 = smp[0]
	var f := fight_of(key, t)
	if not f.is_empty():
		# spread the fighters so the clash reads: the two sides a little apart, front rows forward
		var c := Vector2.ZERO
		var n := 0
		for k in f["keys"]:
			c += (_sample(String(k), float(f["t0"]))[0] as Vector2)
			n += 1
		c /= float(maxi(1, n))
		var sgn := -1.0 if side_of(key) == "R" else 1.0
		var arch := String(SimData.heroes()[hero_of[key]]["archetype"])
		var back := 0.02 if arch in ["bruiser", "bulwark"] else 0.045
		var idx := SLOTS.find(key.substr(2))
		var lateral := (float(idx) - 2.0) * 0.022
		var wob := 0.004 * sin(t * 3.1 + float(idx))
		p = c + Vector2(lateral + wob, sgn * back)
	return p


func hp(key: String, t: float) -> float:
	if not alive(key, t):
		return 0.0
	var f := fight_of(key, t)
	if not f.is_empty():
		var last := -1.0
		for s in f["hp"]:
			if float(s[0]) <= t and (s[1] as Dictionary).has(key):
				last = float(s[1][key])
		if last >= 0.0:
			return last
	return clampf(float(_sample(key, t)[1]), 0.0, 1.0)


## A hero's level at t (1 before any level event). Display only (Match Day M2).
func level_of(key: String, t: float) -> int:
	var lv := 1
	for x in levels.get(key, []):
		if float(x[0]) <= t:
			lv = int(x[1])
		else:
			break
	return lv


## A hero's items at t, in buying order: a finished item takes the place of the parts it was built from (items_v2 components).
func items_of(key: String, t: float) -> Array:
	var inv: Array = []
	for x in buys.get(key, []):
		if float(x[0]) > t:
			break
		var iid := String(x[1])
		for part in SimData.item(iid).get("components", []):
			var i := inv.find(String(part))
			if i >= 0:
				inv.remove_at(i)
		inv.append(iid)
	return inv


## [kills, deaths, assists] of a hero at t (kills by towers count as deaths only).
func kda_of(key: String, t: float) -> Array:
	var k := 0
	var d := 0
	var a := 0
	for x in kills:
		if float(x[0]) > t:
			continue
		if String(x[1]) == key:
			k += 1
		if String(x[2]) == key:
			d += 1
		if x[3] is Array and (x[3] as Array).has(key):
			a += 1
	return [k, d, a]


## Seconds of game time until a dead hero is back (0 when alive).
func respawn_in(key: String, t: float) -> float:
	if alive(key, t):
		return 0.0
	for r in respawns.get(key, []):
		if float(r) > t:
			return float(r) - t
	return 0.0


func towers_down(t: float) -> Dictionary:
	var out := {}
	for tw in towers:
		if float(tw[0]) <= t:
			out[String(tw[1])] = String(tw[2])
	return out


## "up", "down" (taken and not back yet) for an objective at t.
func objective(oid: String, t: float) -> String:
	var state := "down"
	var ev: Array = []
	for u in obj_up:
		if String(u[1]) == oid:
			ev.append([float(u[0]), "up"])
	for o in objs:
		if String(o[1]) == oid:
			ev.append([float(o[0]), "down"])
	ev.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for x in ev:
		if float(x[0]) <= t:
			state = String(x[1])
	return state


## The lane front (0 = Blue gate, 1 = Red gate) at t.
func front(lane: String, t: float) -> float:
	var fr: PackedFloat32Array = fronts[lane]
	if fr.is_empty():
		return 0.5
	var x := clampf(t / every, 0.0, float(fr.size() - 1))
	var i := int(x)
	var j := mini(fr.size() - 1, i + 1)
	return lerpf(fr[i], fr[j], x - float(i))


## {"kills": {B, R}, "towers": {B, R} (structures destroyed by each side), "gold": {B, R} (estimate), "clock": t}
func score(t: float) -> Dictionary:
	var k := {"B": 0, "R": 0}
	for x in kills:
		if float(x[0]) <= t and not String(x[1]).begins_with("tower."):
			k[side_of(String(x[1]))] += 1
	var tw := {"B": 0, "R": 0}
	for x in towers:
		if float(x[0]) <= t and not String(x[1]).ends_with("cairn"):
			tw[String(x[2])] += 1
	# gold earned so far, from the log's team-gold samples
	var g := {}
	var gt: Dictionary = log.get("gold", {})
	for side in ["B", "R"]:
		var arr: PackedFloat32Array = gt.get(side, PackedFloat32Array())
		if arr.is_empty():
			g[side] = 0
			continue
		var x := clampf(t / every, 0.0, float(arr.size() - 1))
		var i := int(x)
		var j := mini(arr.size() - 1, i + 1)
		g[side] = int(round(lerpf(arr[i], arr[j], x - float(i))))
	return {"kills": k, "towers": tw, "gold": g, "clock": t}


## Effects to draw at t: [[kind, canonical point, age 0..1, side]] for casts and kills.
func effects(t: float) -> Array:
	var out: Array = []
	for c in casts:
		var age := (t - float(c[0])) / CAST_S
		if age < 0.0 or age > 1.0:
			continue
		var who := String(c[1])
		out.append(["cast", pos(who, t), age, side_of(who), String(c[2]), bool(c[4]), pos(String(c[3]), t) if track.has(String(c[3])) else pos(who, t), who])
	for k in kills:
		var age2 := (t - float(k[0])) / KILL_S
		if age2 < 0.0 or age2 > 1.0:
			continue
		out.append(["kill", _sample(String(k[2]), float(k[0]))[0], age2, side_of(String(k[2]))])
	return out


## The follow camera's target at t and how close to be (zoom 0 = wide .. 1 = close).
func focus(t: float) -> Array:
	var best: Dictionary = {}
	for f in fights:
		if float(f["t0"]) - 1.0 <= t and t <= float(f["t1"]) + 1.0:
			if best.is_empty() or (f["keys"] as Array).size() > (best["keys"] as Array).size():
				best = f
	if not best.is_empty():
		var c := Vector2.ZERO
		for k in best["keys"]:
			c += pos(String(k), t)
		return [c / float((best["keys"] as Array).size()), 1.0 if (best["keys"] as Array).size() >= 6 else 0.8]
	for o in objs:
		if float(o[0]) - 6.0 <= t and t <= float(o[0]) + 1.0:
			return [SimData.map()["objectives"][String(o[1])]["pos"], 0.7]
	for tw in towers:
		if float(tw[0]) - 5.0 <= t and t <= float(tw[0]) + 1.5:
			for x in SimData.map()["towers"]:
				if String(x["id"]) == String(tw[1]):
					return [x["pos"], 0.6]
	return focus_team(t)


## Where the player's team is (its living heroes' centre), or its Cairn when all are down: [point, zoom].
func focus_team(t: float) -> Array:
	var c2 := Vector2.ZERO
	var n := 0
	for s in SLOTS:
		var key: String = my_side + "." + s
		if alive(key, t):
			c2 += pos(key, t)
			n += 1
	if n == 0:
		return [SimData.map()["cairn"][my_side], 0.2]
	return [c2 / float(n), 0.3]


## Notable intents and calls at t for the labels: [[t, key or side, text key, target]] within the last 3 s.
func notes(t: float) -> Array:
	var out: Array = []
	for x in intents:
		if float(x[0]) <= t and t - float(x[0]) <= 3.0:
			out.append(x)
	for c in calls:
		if float(c[0]) <= t and t - float(c[0]) <= 3.0:
			out.append([c[0], "team." + String(c[1]), "call_" + String(c[2]), String(c[3])])
	return out
