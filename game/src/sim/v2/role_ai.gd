class_name RoleAI
extends RefCounted
## Role behaviour of Match Sim v2 (MATCH-SIM-V2-DESIGN 5.3): each agent picks an intent at its decision points (farm a lane,
## follow the carry, clear a camp, gank, roam, ward, recall, group for an objective, siege, defend, split), the team's shot
## caller (highest MAC) makes calls that each player answers with a chance that rises with COM and the team's Bonds, lane
## partners trade, and encounters turn into fights only when one side wants it. Player stats steer the choices: SEN (danger,
## timing), MAC (rotations, objectives), LAN (trades), TFT and MEC (inside fights, FightV2). The Game Plan's controls tilt the
## thresholds (design 5.3 table). All randomness from the agent's own stream v2:<key>:dec.

const LANES := ["top", "mid", "bot"]
const FARMING := {"farm_lane": true, "follow": true}
const LEAVING := {"escape": true, "recall": true}


static func _r(sim: MatchSimV2, h: SimHero) -> Pcg32:
	return sim.rng(h.key + ":dec")


static func plan(sim: MatchSimV2, side: String, ctl: String) -> float:
	var set_: Dictionary = sim.plan_sets.get(side, GamePlan.neutral_set())
	var name := String(sim.plan_used[side])
	var pl: Dictionary = set_["default"]
	if name != "default":
		for tr in set_.get("triggers", []):
			if String(tr["when"]) == name:
				pl = tr["plan"]
	if ctl == "jf":
		return 0.0
	return float(pl.get(ctl, 0)) / 100.0


static func jungle_focus(sim: MatchSimV2, side: String) -> String:
	var set_: Dictionary = sim.plan_sets.get(side, GamePlan.neutral_set())
	var jf := String(set_["default"].get("jf", "none"))
	return {"none": "", "top": "top", "mid_lane": "mid", "bot": "bot"}.get(jf, "")


## How strong a hero is right now, for decisions (not for fights).
static func power(sim: MatchSimV2, h: SimHero) -> float:
	if not h.alive:
		return 0.0
	var frac := h.hp / maxf(1.0, h.max_hp)
	return (0.35 + 0.65 * frac) * (1.0 + 0.10 * float(h.level) + h.item_value() / 4000.0) * h.qe(sim.t)


static func group_power(sim: MatchSimV2, side: String, center: Vector2, radius: float) -> float:
	var v := 0.0
	for h in sim.side_heroes(side):
		var hh: SimHero = h
		if hh.alive and SimData.du(hh.pos, center) <= radius:
			v += power(sim, hh)
	return v


static func enemies_near(sim: MatchSimV2, h: SimHero, radius: float) -> int:
	var n := 0
	for e in sim.side_heroes(SimData.other(h.side)):
		var ee: SimHero = e
		if ee.alive and SimData.du(ee.pos, h.pos) <= radius:
			n += 1
	return n


# ---------------------------------------------------------------- team calls
static func team_calls(sim: MatchSimV2) -> void:
	var t: float = sim.t
	for side in ["B", "R"]:
		var call: Dictionary = sim.calls[side]
		if not call.is_empty() and t >= float(call["until"]):
			sim.calls[side] = {}
			call = {}
		if not call.is_empty():
			if String(call["kind"]) == "group" and not bool(sim.objs[String(call["target"])]["alive"]) and t > float(call["from"]) + 50.0:
				sim.calls[side] = {}
			continue
		var caller := _caller(sim, side)
		var mac := caller.p_mac / 100.0
		var lead := float(sim.call_lead_s()) * (0.6 + 0.8 * mac)
		var alive_me := _alive(sim, side)
		var alive_them := _alive(sim, SimData.other(side))
		# objectives
		for oid in ["moonhulk", "stoneback"]:
			var o: Dictionary = sim.objs[oid]
			var soon: bool = bool(o["alive"]) or float(o["respawn_at"]) - t <= lead
			if not soon:
				continue
			var want := 0.45 + 0.15 * float(alive_me - alive_them) + 0.25 * mac
			want += (plan(sim, side, "m") if oid == "stoneback" else plan(sim, side, "l")) * 0.35
			want += 0.15 * plan(sim, side, "g")
			if oid == "moonhulk" and t < float(sim.p["group_from_s"]):
				want -= 0.2
			if want >= 0.5 and _r(sim, caller).next_float() < 0.6:
				_make_call(sim, side, "group", oid, t + 70.0)
				break
		if not sim.calls[side].is_empty():
			continue
		# siege after an advantage
		if t >= 600.0 and alive_me - alive_them >= 2:
			var lane := _siege_lane(sim, side)
			if lane != "":
				_make_call(sim, side, "siege", lane, t + 45.0)
				continue
		if t >= float(sim.p["group_from_s"]) and alive_me >= alive_them and _r(sim, caller).next_float() < 0.04 + 0.04 * plan(sim, side, "g"):
			var lane2 := _siege_lane(sim, side)
			if lane2 != "":
				_make_call(sim, side, "siege", lane2, t + 45.0)
				continue
		# defend a lane where three or more enemies push a tower (checked every 4 s)
		if int(t) % 4 != 0:
			continue
		for lane3 in LANES:
			var tw: Dictionary = sim.first_tower(lane3, side)
			if tw.is_empty():
				continue
			var n := 0
			for e in sim.side_heroes(SimData.other(side)):
				if e.alive and SimData.du(e.pos, tw["pos"]) <= 0.12:
					n += 1
			if n >= 3:
				_make_call(sim, side, "defend", lane3, t + 35.0)
				break


static func _alive(sim: MatchSimV2, side: String) -> int:
	return int(sim.alive_n[side])


static func _alive_count(sim: MatchSimV2, side: String) -> int:
	var n := 0
	for h in sim.side_heroes(side):
		if h.alive:
			n += 1
	return n


static func _caller(sim: MatchSimV2, side: String) -> SimHero:
	if sim.caller.has(side):
		return sim.caller[side]
	var best: SimHero = null
	for h in sim.side_heroes(side):
		var hh: SimHero = h
		if best == null or hh.p_mac > best.p_mac:
			best = hh
	return best


static func _make_call(sim: MatchSimV2, side: String, kind: String, target: String, until: float) -> void:
	sim.calls[side] = {"kind": kind, "target": target, "until": until, "from": sim.t, "id": "%s:%s:%d" % [kind, target, int(sim.t)]}
	sim.log_ev([sim.t, "call", side, kind, target])
	for h in sim.side_heroes(side):
		h.next_decide = minf(h.next_decide, sim.t + 0.5)


static func _siege_lane(sim: MatchSimV2, side: String) -> String:
	var best := ""
	var bs := -INF
	var enemy := SimData.other(side)
	for lane in LANES:
		var tw: Dictionary = sim.first_tower(lane, enemy)
		if tw.is_empty():
			continue
		var front := float(sim.lanes[lane]["front"])
		var adv := front if side == "B" else 1.0 - front
		var sc := adv + 0.4 * (1.0 - float(tw["hp"]) / float(tw["max"]))
		if sc > bs:
			bs = sc
			best = lane
	return best


static func _member(call: Dictionary, h: SimHero, t: float) -> bool:
	var kind := String(call["kind"])
	if kind == "group" and String(call["target"]) == "stoneback" and t < 840.0:
		return h.slot in ["jg", "mid", "sup"] or (h.slot == "bot" and t >= 600.0)
	if kind == "defend" or kind == "siege":
		return true
	return true


# ---------------------------------------------------------------- decisions
static func decide(sim: MatchSimV2, h: SimHero) -> void:
	var t: float = sim.t
	var r := _r(sim, h)
	var sen := h.p_sen / 100.0
	var p: Dictionary = sim.p
	h.next_decide = t + lerpf(float(p["decide_max_s"]), float(p["decide_min_s"]), sen) * (0.8 + 0.4 * r.next_float())
	var frac := h.hp / maxf(1.0, h.max_hp)
	var danger := enemies_near(sim, h, 0.12)
	# escape and recall
	if h.intent == "escape":
		if danger == 0:
			sim.start_recall(h)
		else:
			_go_home(sim, h)
		return
	if frac < float(p["recall_hp"]) * (0.8 + 0.4 * sen) and not _committed(sim, h):
		if danger == 0:
			sim.start_recall(h)
		else:
			h.intent = "escape"
			_go_home(sim, h)
		return
	if h.intent == "back_off" and t < h.busy_until + 8.0:
		return
	if _shop_trip(sim, h) and danger == 0:
		sim.start_recall(h)
		return
	# team call
	var call: Dictionary = sim.calls[h.side]
	if not call.is_empty() and _member(call, h, t):
		var cid := String(call["id"])
		if not h.has_meta("call") or String(h.get_meta("call")) != cid:
			h.set_meta("call", cid)
			var bond := float(sim.bonds.get(h.side, 50.0)) / 100.0
			var pr := float(p["answer_base"]) + float(p["answer_com"]) * h.p_com / 100.0 + float(p["answer_bond"]) * bond + 0.2 * plan(sim, h.side, "g")
			if h.slot == "top" and t < 840.0:
				pr -= 0.25
			h.set_meta("answer", r.next_float() < pr)
		if bool(h.get_meta("answer", false)):
			_answer(sim, h, call)
			return
	match h.slot:
		"jg":
			_jungle(sim, h, r)
		"sup":
			_support(sim, h, r)
		"mid":
			_laner(sim, h, r, "mid")
		"top":
			_laner(sim, h, r, "top")
		"bot":
			_laner(sim, h, r, "bot")


static func _committed(sim: MatchSimV2, h: SimHero) -> bool:
	var call: Dictionary = sim.calls[h.side]
	return h.intent in ["group", "siege", "defend"] and not call.is_empty() and h.hp / h.max_hp > 0.22


static func _shop_trip(sim: MatchSimV2, h: SimHero) -> bool:
	if h.gold < 900.0:
		return false
	var t: float = sim.t
	if t - float(h.get_meta("home_t", 0.0)) < 100.0:
		return false
	if h.intent in ["group", "siege", "defend", "gank"]:
		return false
	var nxt := Items._next_purchase(h)
	if nxt.is_empty():
		return false
	var need := float(nxt["price"])
	var thr := 1100.0 if h.slot != "sup" else 900.0
	if h.gold >= maxf(need, thr) and h.gold >= 900.0:
		h.set_meta("home_t", t)
		return true
	return false


static func _go_home(sim: MatchSimV2, h: SimHero) -> void:
	sim.walk_to(h, String(sim.first_safe_node(h)))


static func _answer(sim: MatchSimV2, h: SimHero, call: Dictionary) -> void:
	var kind := String(call["kind"])
	var tgt := String(call["target"])
	if h.intent == kind and h.target == tgt and not h.path.is_empty():
		return
	h.intent = kind
	h.target = tgt
	if kind == "group":
		var o: Dictionary = sim.objs[tgt]
		if SimData.du(h.pos, o["pos"]) > 0.04:
			sim.walk_to(h, String(o["node"]))
	else:
		_to_lane(sim, h, tgt)


static func _to_lane(sim: MatchSimV2, h: SimHero, lane: String) -> void:
	var goal: Vector2 = sim.lane_stand(h, lane)
	if SimData.du(h.pos, goal) > 0.06:
		sim.walk_to_point(h, goal)


static func _laner(sim: MatchSimV2, h: SimHero, r: Pcg32, lane: String) -> void:
	var t: float = sim.t
	# the late game: group or split
	if t >= float(sim.p["split_from_s"]) and lane != "mid":
		var split: bool = ("splitpush" in h.hero["tags"]) or plan(sim, h.side, "g") < -0.3
		if split and r.next_float() < 0.7:
			h.intent = "split"
			h.target = _split_lane(sim, h)
			_to_lane(sim, h, h.target)
			return
		if r.next_float() < 0.35 + 0.3 * plan(sim, h.side, "g"):
			h.intent = "farm_lane"
			h.target = "mid"
			_to_lane(sim, h, "mid")
			return
	# mid roams after pushing
	if lane == "mid" and t >= 180.0 and h.intent == "farm_lane":
		var front := float(sim.lanes["mid"]["front"])
		var pushed := front > 0.55 if h.side == "B" else front < 0.45
		if pushed:
			var best := ""
			var bs := float(sim.p["roam_threshold"])
			for side_lane in ["top", "bot"]:
				var sc := gank_score(sim, h, side_lane) * (0.7 + 0.6 * h.p_mac / 100.0)
				if sc > bs:
					bs = sc
					best = side_lane
			if best != "" and r.next_float() < 0.6:
				h.intent = "roam"
				h.target = best
				h.set_meta("roam_until", t + 28.0)
				sim.walk_to_point(h, SimData.lane_point(best, float(sim.lanes[best]["front"])))
				sim.log_ev([t, "intent", h.key, "roam", best])
				return
	if h.intent == "roam" and t < float(h.get_meta("roam_until", 0.0)):
		if h.path.is_empty():
			_to_lane(sim, h, h.target)
		return
	if h.intent == "farm_lane" and h.target == lane:
		h.next_decide += 4.0
	h.intent = "farm_lane"
	h.target = lane
	_to_lane(sim, h, lane)


static func _split_lane(sim: MatchSimV2, h: SimHero) -> String:
	var best := "top"
	var bd := -1.0
	for lane in ["top", "bot"]:
		var fp := SimData.lane_point(lane, float(sim.lanes[lane]["front"]))
		var near := 99.0
		for e in sim.side_heroes(SimData.other(h.side)):
			if e.alive:
				near = minf(near, SimData.du(e.pos, fp))
		if near > bd:
			bd = near
			best = lane
	return best


static func _support(sim: MatchSimV2, h: SimHero, r: Pcg32) -> void:
	var t: float = sim.t
	var roam := plan(sim, h.side, "s")
	var carry: SimHero = sim.by_key[h.side + ".bot"]
	# ward the river now and then
	if t >= 120.0 and t - float(h.get_meta("ward_t", -999.0)) >= float(sim.p["vision_ward_s"]) * (1.3 - 0.6 * h.p_mac / 100.0):
		h.set_meta("ward_t", t)
		sim.ward(h.side, "bot")
		sim.ward(h.side, "river")
		h.vision += 2.0
		sim.log_ev([t, "ward", h.key, "river"])
	if t >= 210.0 and h.intent != "roam":
		var sc := gank_score(sim, h, "mid") * (0.6 + 0.5 * h.p_mac / 100.0) + 0.3 * roam
		if sc > float(sim.p["roam_threshold"]) and r.next_float() < 0.4 + 0.3 * roam:
			h.intent = "roam"
			h.target = "mid"
			h.set_meta("roam_until", t + 25.0)
			sim.walk_to_point(h, SimData.lane_point("mid", float(sim.lanes["mid"]["front"])))
			sim.log_ev([t, "intent", h.key, "roam", "mid"])
			return
	if h.intent == "roam" and t < float(h.get_meta("roam_until", 0.0)):
		if h.path.is_empty():
			_to_lane(sim, h, h.target)
		return
	if carry.alive and carry.intent in ["farm_lane"] and carry.target == "bot":
		h.intent = "follow"
		h.target = "bot"
		if SimData.du(h.pos, carry.pos) > 0.07:
			sim.walk_to_point(h, carry.pos)
		return
	if carry.alive and carry.intent in ["group", "siege", "defend", "farm_lane"]:
		h.intent = carry.intent
		h.target = carry.target
		if carry.intent == "group":
			sim.walk_to(h, String(sim.objs[carry.target]["node"]))
		else:
			_to_lane(sim, h, carry.target)
		return
	h.intent = "farm_lane"
	h.target = "bot"
	_to_lane(sim, h, "bot")


static func _jungle(sim: MatchSimV2, h: SimHero, r: Pcg32) -> void:
	var t: float = sim.t
	if h.intent == "gank" and t < float(h.get_meta("gank_until", 0.0)):
		if h.path.is_empty():
			_to_lane(sim, h, h.target)
		return
	if t >= float(sim.p["gank_from_s"]):
		var best := ""
		var bs := float(sim.p["gank_threshold"]) * (1.0 - 0.15 * plan(sim, h.side, "t"))
		for lane in LANES:
			var sc := gank_score(sim, h, lane) * (0.7 + 0.6 * h.p_mac / 100.0)
			if jungle_focus(sim, h.side) == lane:
				sc += 0.2
			if sc > bs:
				bs = sc
				best = lane
		if best != "" and r.next_float() < 0.75:
			h.intent = "gank"
			h.target = best
			h.ganks += 1
			h.set_meta("gank_until", t + 26.0)
			sim.walk_to_point(h, SimData.lane_point(best, float(sim.lanes[best]["front"])))
			sim.log_ev([t, "intent", h.key, "gank", best])
			return
	# the small west objective (Mossback) when it is up and nobody is near
	var mb: Dictionary = sim.objs["mossback"]
	if bool(mb["alive"]) and SimData.du(h.pos, mb["pos"]) < 0.35 and enemies_near(sim, h, 0.2) == 0:
		h.intent = "group"
		h.target = "mossback"
		sim.walk_to(h, String(mb["node"]))
		return
	# next camp: nearest live camp on our side, else the enemy's when their jungler is far
	var best_c: Dictionary = {}
	var bd := INF
	var start := SimData.nearest_node(h.pos)
	var enemy_jg: SimHero = sim.by_key[SimData.other(h.side) + ".jg"]
	for c in sim.camps:
		if not bool(c["alive"]):
			continue
		var mine := String(c["side"]) == h.side
		if not mine:
			if not enemy_jg.alive or SimData.du(enemy_jg.pos, c["pos"]) > 0.35:
				pass
			else:
				continue
		var d := SimData.path_len(start, String(c["node"])) * (1.0 if mine else 1.8)
		if d < bd:
			bd = d
			best_c = c
	if not best_c.is_empty():
		h.intent = "clear_camp"
		h.target = String(best_c["id"])
		if SimData.du(h.pos, best_c["pos"]) > 0.03:
			sim.walk_to(h, String(best_c["node"]))
		return
	# nothing up: sit in the river near the next objective
	h.intent = "farm_lane"
	h.target = "top" if r.next_float() < 0.5 else "bot"
	_to_lane(sim, h, h.target)


## How good a gank on `lane` looks to hero h (design 5.3, jungle).
static func gank_score(sim: MatchSimV2, h: SimHero, lane: String) -> float:
	var enemy := SimData.other(h.side)
	var front := float(sim.lanes[lane]["front"])
	var over := (0.5 - front) if enemy == "R" else (front - 0.5)    # > 0: the enemy wave is on our half
	var best := 0.0
	for e in sim.heroes_in_lane(lane, enemy):
		var ee: SimHero = e
		var sc := 0.3 + 0.9 * maxf(0.0, over) + 0.3 * (1.0 - ee.hp / maxf(1.0, ee.max_hp)) + 0.05 * float(h.level - ee.level)
		sc -= 0.25 * float(sim.has_vision(enemy, lane))
		var allies := sim.heroes_in_lane(lane, h.side)
		if not allies.is_empty():
			sc += 0.15
		var tw: Dictionary = sim.first_tower(lane, enemy)
		if not tw.is_empty() and SimData.du(tw["pos"], ee.pos) < float(sim.p["tower_range_u"]):
			sc -= 0.35
		var d := SimData.path_len(SimData.nearest_node(h.pos), SimData.lane_node_near(lane, front))
		sc -= 0.25 * d
		best = maxf(best, sc)
	return best


# ---------------------------------------------------------------- encounters
## Whether a meeting of a and b turns into a fight, and its kind ("" = no fight).
static func fight_wanted(sim: MatchSimV2, a: SimHero, b: SimHero) -> String:
	# lane partners trade instead of fighting (RoleAI.lane_trades); an all-in comes from there
	if FARMING.has(a.intent) and FARMING.has(b.intent) and a.target == b.target:
		return ""
	for x in [a, b]:
		if LEAVING.has(x.intent) or x.recall_at >= 0.0:
			if (x == a and power(sim, b) < 1.4 * power(sim, a)) or (x == b and power(sim, a) < 1.4 * power(sim, b)):
				return ""
	var center := (a.pos + b.pos) / 2.0
	var pa := group_power(sim, a.side, center, 0.14)
	var pb := group_power(sim, b.side, center, 0.14)
	for x in [a, b]:
		var xx: SimHero = x
		if xx.intent == "gank":
			var mine := pa if xx == a else pb
			var theirs := pb if xx == a else pa
			if mine >= 0.8 * theirs:
				return "gank"
	for x in [a, b]:
		var xx: SimHero = x
		if xx.intent == "group" and xx.target in sim.objs:
			var o: Dictionary = sim.objs[xx.target]
			if SimData.du(center, o["pos"]) < 0.15:
				return "objective"
		if xx.intent in ["siege", "defend"]:
			return "siege"
	var ratio := pa / maxf(0.01, pb)
	var risk := 1.18 - 0.1 * (plan(sim, a.side, "r") if ratio > 1.0 else plan(sim, b.side, "r"))
	if ratio >= risk or ratio <= 1.0 / risk:
		return "skirmish"
	return ""


## Whether hero h, close by, joins a fight at center.
static func joins(sim: MatchSimV2, h: SimHero, center: Vector2) -> bool:
	if h.intent in ["escape", "recall"]:
		return false
	var allies := 0
	for x in sim.side_heroes(h.side):
		var xx: SimHero = x
		if xx != h and xx.alive and SimData.du(xx.pos, center) <= float(sim.p["fight_center_u"]):
			allies += 1
	if allies == 0:
		return false
	var pr := 0.45 + 0.35 * h.p_com / 100.0 + 0.15 * h.p_sen / 100.0 + (0.15 if h.slot in ["jg", "sup"] else 0.0) + 0.15 * plan(sim, h.side, "g")
	return _r(sim, h).next_float() < pr


## Lane trades between lane opponents farming at the same front (design 5.3, top/mid/bot).
static func lane_trades(sim: MatchSimV2) -> void:
	var t: float = sim.t
	if not sim.waves_on():
		return
	for lane in LANES:
		var bs: Array = []
		var rs: Array = []
		for h in sim.heroes_in_lane(lane, "B", 0.09):
			if FARMING.has(h.intent):
				bs.append(h)
		for h in sim.heroes_in_lane(lane, "R", 0.09):
			if FARMING.has(h.intent):
				rs.append(h)
		if bs.is_empty() or rs.is_empty():
			continue
		var key: String = "trade_" + lane
		if t < float(sim.trade_next.get(key, 0.0)):
			continue
		var lr: Pcg32 = sim.rng("trade:" + lane)
		var aggr := 0.5 * (plan(sim, "B", "a") + plan(sim, "R", "a"))
		sim.trade_next[key] = t + float(sim.p["trade_every_s"]) * (0.7 + 0.6 * lr.next_float()) / (1.0 + 0.3 * maxf(0.0, aggr))
		var pw := {"B": _trade_power(sim, bs, lane, "B"), "R": _trade_power(sim, rs, lane, "R")}
		var ctx: String = {"top": "top", "mid": "mid_lane", "bot": "bot"}[lane]
		var var_k := 0.5 * (float(sim.hooks["B"]["contest_var"][ctx]) + float(sim.hooks["R"]["contest_var"][ctx]))
		var con := 0.5 * (float(sim.teams["B"].get("con", 50.0)) + float(sim.teams["R"].get("con", 50.0)))
		var z := SimData.ih_normal(lr) * 0.22 * MatchSim.noise_scale(con) * var_k
		var diff := (float(pw["B"]) - float(pw["R"])) / maxf(0.01, float(pw["B"]) + float(pw["R"])) * 2.0 + z
		var win := "B" if diff > 0.0 else "R"
		var mag := minf(1.0, absf(diff))
		var dmg := float(sim.p["trade_dmg"])
		var winners: Array = bs if win == "B" else rs
		var losers: Array = rs if win == "B" else bs
		for h in losers:
			var hh: SimHero = h
			hh.hp = maxf(hh.max_hp * 0.05, hh.hp - hh.max_hp * dmg * (0.6 + mag))
			for w in winners:
				hh.last_hit_by[w.key] = t
		for h in winners:
			var hh2: SimHero = h
			hh2.hp = maxf(hh2.max_hp * 0.1, hh2.hp - hh2.max_hp * dmg * maxf(0.1, 0.6 - mag))
			for l in losers:
				hh2.last_hit_by[l.key] = t
		sim.log_ev([t, "trade", lane, win, snappedf(mag, 0.01)])
		# all-in on a low enemy
		var low: SimHero = null
		for h in losers:
			if h.hp / h.max_hp < 0.32 and (low == null or h.hp < low.hp):
				low = h
		if low == null:
			continue
		var wf := 0.0
		for w in winners:
			wf += w.hp / w.max_hp
		wf /= float(winners.size())
		if wf < 0.5:
			continue
		var lead: SimHero = winners[0]
		var pr := 0.3 + 0.3 * lead.p_lan / 100.0 + 0.2 * plan(sim, win, "a") + 0.1 * plan(sim, win, "r") - 0.2 * float(sim.under_tower(low))
		if lr.next_float() < pr:
			var parts := sim._participants((lead.pos + low.pos) / 2.0)
			if parts.size() >= 2:
				sim.fight((lead.pos + low.pos) / 2.0, parts, "skirmish")


static func _trade_power(sim: MatchSimV2, hs: Array, lane: String, side: String) -> float:
	var v := 0.0
	var lm: Dictionary = sim.teams[side].get("lane_mod", {})
	for h in hs:
		var hh: SimHero = h
		var kit_early := 0.0
		for i in 3:
			var a: SimHero.Ability = hh.abil[i]
			if a.dmg_k and hh.level >= a.unlock:
				kit_early += a.dmg / maxf(3.0, a.cd)
		var w := 1.0 if hh.slot != "sup" else 0.6
		v += w * power(sim, hh) * (1.0 + 0.004 * kit_early) * (0.85 + 0.3 * hh.p_lan / 100.0)
	v *= 1.0 + float(lm.get(lane, 0.0)) * float(sim.p["lane_counter"])
	return v
