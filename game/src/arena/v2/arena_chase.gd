class_name ArenaChase
extends RefCounted
## The Action view's camera director (Founder decision 2026-11-22). Chooses what to look at from the event log through ArenaPlayer:
## a decisive play, an objective take (Stoneback, Moonhulk, a Cairn), a tower falling, a fight, a kill, else the team. Each has a
## priority (data/arena_view_v1.json "chase"); the camera stays on one event at least dwell_s real seconds so it does not jump,
## then moves to the best event still on. With fog, only events the team can see (ArenaVision) are chased; the feed still
## tells the rest. Display only (rules A1 and R7).
## "Decisive" is not a flag in the v2 log: a fight is decisive here when it has `decisive_kills` kills or more, and a Cairn
## falling is always decisive. Derived for the camera only.
##   candidates(t)       [{id, kind, prio, pos, zoom}], best first
##   update(t, real_dt)  the target to look at now: {id, kind, prio, pos, zoom}

var player: ArenaPlayer
var vision: ArenaVision          # null = everything is visible (no fog)
var prio: Dictionary = {}
var dwell_s := 2.5
var decisive_kills := 3
var target: Dictionary = {}
var held := 0.0                  # real seconds on the current target
var switches := 0
var _fight_kills: Dictionary = {}


static func build(p_player: ArenaPlayer, p_vision: ArenaVision, p_cfg: Dictionary = {}) -> ArenaChase:
	var c := ArenaChase.new()
	var cf := p_cfg if not p_cfg.is_empty() else ArenaVision.cfg()
	c.player = p_player
	c.vision = p_vision
	c.prio = cf["chase"]["priority"]
	c.dwell_s = float(cf["chase"]["dwell_s"])
	c.decisive_kills = int(cf["chase"]["decisive_kills"])
	for f in p_player.fights:
		var n := 0
		for k in p_player.kills:
			if float(k[0]) >= float(f["t0"]) - 0.5 and float(k[0]) <= float(f["t1"]) + 0.5:
				for key in f["keys"]:
					if String(key) == String(k[2]):
						n += 1
						break
		c._fight_kills[int(f["id"])] = n
	return c


func _p(kind: String) -> float:
	return float(prio.get(kind, 0.0))


func _visible(p: Vector2, t: float) -> bool:
	return vision == null or vision.sees(p, t)


func candidates(t: float) -> Array:
	var out: Array = []
	var map := SimData.map()
	for f in player.fights:
		if float(f["t0"]) - 1.0 <= t and t <= float(f["t1"]) + 1.0:
			var c := Vector2.ZERO
			var any_seen := false
			for k in f["keys"]:
				var p := player.pos(String(k), t)
				c += p
				any_seen = any_seen or _visible(p, t)
			c /= float(maxi(1, (f["keys"] as Array).size()))
			if not any_seen:
				continue
			var size := (f["keys"] as Array).size()
			var dec := int(_fight_kills.get(int(f["id"]), 0)) >= decisive_kills
			out.append({"id": "fight.%d" % int(f["id"]), "kind": "decisive" if dec else "fight",
					"prio": (_p("decisive") if dec else _p("fight") + 0.05 * float(size)), "pos": c, "zoom": 1.0 if size >= 6 else 0.8})
	for o in player.objs:
		if float(o[0]) - 6.0 <= t and t <= float(o[0]) + 1.5:
			var op: Vector2 = map["objectives"][String(o[1])]["pos"]
			if _visible(op, t):
				out.append({"id": "obj.%s.%d" % [String(o[1]), int(float(o[0]))], "kind": "objective", "prio": _p("objective"), "pos": op, "zoom": 0.7})
	for tw in player.towers:
		if float(tw[0]) - 5.0 <= t and t <= float(tw[0]) + 1.5:
			var id := String(tw[1])
			var tp := Vector2(-1, -1)
			if id.ends_with(".cairn"):
				tp = map["cairn"][id.substr(0, 1)]
			else:
				for x in map["towers"]:
					if String(x["id"]) == id:
						tp = x["pos"]
			if tp.x < 0.0 or not _visible(tp, t):
				continue
			var cairn := id.ends_with(".cairn")
			out.append({"id": "tower." + id, "kind": "decisive" if cairn else "tower",
					"prio": _p("decisive") if cairn else _p("tower"), "pos": tp, "zoom": 0.6})
	for k2 in player.kills:
		if float(k2[0]) - 1.0 <= t and t <= float(k2[0]) + 1.5:
			var kp := player.pos(String(k2[2]), minf(t, float(k2[0])))
			if _visible(kp, t):
				out.append({"id": "kill.%s.%d" % [String(k2[2]), int(float(k2[0]) * 10.0)], "kind": "kill", "prio": _p("kill"), "pos": kp, "zoom": 0.8})
	var team := player.focus_team(t)
	out.append({"id": "team", "kind": "team", "prio": _p("team"), "pos": team[0], "zoom": team[1]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["prio"]) > float(b["prio"]) or (float(a["prio"]) == float(b["prio"]) and String(a["id"]) < String(b["id"])))
	return out


## Advance by `real_dt` real seconds and return the target for game time t. The current target is kept while it is still on
## and either it has been watched less than dwell_s or nothing better is on; a target that ended is replaced at once only
## after dwell_s too (so a short kill does not snap the camera away and back).
func update(t: float, real_dt: float) -> Dictionary:
	held += maxf(0.0, real_dt)
	var cands := candidates(t)
	var best: Dictionary = cands[0]
	var cur: Dictionary = {}
	if not target.is_empty():
		for c in cands:
			if String(c["id"]) == String(target["id"]):
				cur = c
				break
	if target.is_empty():
		_switch(best)
	elif held < dwell_s:
		if not cur.is_empty():
			target = cur              # same event, fresh position
	elif cur.is_empty() or float(best["prio"]) > float(cur["prio"]):
		_switch(best)
	else:
		target = cur
	return target


func _switch(c: Dictionary) -> void:
	if not target.is_empty() and String(target["id"]) != String(c["id"]):
		switches += 1
	target = c
	held = 0.0


## Forget the current target (after a jump: Skip, a view change, the end of a drag).
func reset() -> void:
	target = {}
	held = 0.0
