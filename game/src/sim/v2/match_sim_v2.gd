class_name MatchSimV2
extends RefCounted
## Match Sim v2 (MATCH-SIM-V2-DESIGN; Founder decisions of 2026-11-19). Ten role-driven agents on the map graph play the
## game: waves push lanes, laners farm and trade, junglers clear and gank, teams group for objectives, fights are resolved by
## FightV2, towers and the Cairn fall, and the first Cairn down ends the game. The world advances in macro steps of `dt`
## (1 s); agents re-decide only at decision points (RoleAI). Everything is written to an event log that the arena plays back
## and the report reads; positions and health are also sampled every second ("track").
## Inputs: the v1 team dictionaries (World.build_team: phase ratings with every management lever, CON, TeamMod, CompMod, lane
## counters, style), the Game Plan sets and a context with the picks, the players, the builds and the bonds.
## Deterministic (design Q1): PCG32 streams named v2:<...>; only + - * / sqrt and comparisons in the decision path.

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const LANE_OF := {"top": "top", "mid": "mid", "bot": "bot", "sup": "bot", "jg": ""}
const TRACK_EVERY := 2.0   # = dt: one sample per macro step
const LANE_INTENTS := {"farm_lane": true, "siege": true, "defend": true, "split": true}
const RANGED_ARCH := {"gunner": true, "spellcaster": true, "mender": true, "binder": true}

var mseed := 0
var t := 0.0
var p: Dictionary = {}
var teams := {}                  # "B"/"R" -> v1 team dictionary (plus "plan_hooks")
var heroes: Array = []           # SimHero, B.top .. R.sup
var by_key: Dictionary = {}
var towers: Array = []           # {id, side, lane, tier, pos, s, hp, max, alive, dmg}
var lanes: Dictionary = {}       # lane -> {"front": s, "push": {"B", "R"}}
var camps: Array = []            # {id, side, kind, node, pos, alive, respawn_at}
var objs: Dictionary = {}        # id -> {alive, respawn_at, hp, max, node, pos, taker}
var buffs: Dictionary = {"B": {}, "R": {}}   # buff id -> until
var calls: Dictionary = {"B": {}, "R": {}}   # the team's current call {kind, target, until}
var plan_used := {"B": "default", "R": "default"}
var plan_sets: Dictionary = {}
var hooks: Dictionary = {}       # side -> {"contest_mod", "contest_var"} currently applied
var var_mult := {"B": 1.0, "R": 1.0}
var ev: Array = []               # [t, type, ...]
var track: Dictionary = {}       # key -> PackedFloat32Array [x, y, hp_frac, alive] per second
var fronts: Dictionary = {}      # lane -> PackedFloat32Array front s per second
var gold_track := {"B": PackedFloat32Array(), "R": PackedFloat32Array()}   # team gold earned, per sample
var winner := ""
var end_reason := ""
var fight_n := 0
var gold_at_8: Dictionary = {}
var early_metric := 0.0
var team_kills := {"B": 0, "R": 0}
var first_blood := ""
var rngs: Dictionary = {}
var bonds := {"B": 50.0, "R": 50.0}
var form := {"B": 1.0, "R": 1.0}  # each team's form on the day (CON: a reliable team varies less; design 5.1)
var trade_next: Dictionary = {}
var vision := {"B": {}, "R": {}}  # zone -> until
var _next_track := 0.0
var caller: Dictionary = {}        # side -> the shot caller (highest MAC; fixed for the game)
var alive_n := {"B": 5, "R": 5}    # heroes alive per side, this step
var c_sb_move := 0.0
var _front_pt: Dictionary = {}     # lane -> Vector2 (this tick)
var _present: Dictionary = {}      # lane + side -> heroes at the front (radius 0.09, this tick)
var _ft: Dictionary = {}           # lane + side -> first tower (cleared when a structure falls)
var _wave_lvl: Dictionary = {}     # hero key -> level from which it has a wave-clearing ability
var c_wave_g := 0.0
var c_wave_x := 0.0
var c_push_rate := 0.0
var c_floor := 0.0
var c_sup_share := 0.0
var c_plan_k := 1.0
var c_tower_r := 0.06
static var prof: Dictionary = {}
static var profiling := false
var _wave_n := 0
var _next_wave := 0.0
var _next_min := 60.0


static func simulate(ta: Dictionary, tb: Dictionary, p_mseed: int, sets: Dictionary, ctx: Dictionary) -> Dictionary:
	var s := MatchSimV2.new()
	s._setup(ta, tb, p_mseed, sets, ctx)
	s._run()
	return s._result()


func rng(name: String) -> Pcg32:
	if not rngs.has(name):
		rngs[name] = Pcg32.contest_stream(mseed, "v2:" + name)
	return rngs[name]


func minute(tt: float) -> int:
	return int(tt / 60.0)


func hero_by_key(k: String) -> SimHero:
	return by_key.get(k, null)


func side_heroes(side: String) -> Array:
	var out: Array = []
	for h in heroes:
		if h.side == side:
			out.append(h)
	return out


func log_ev(e: Array) -> void:
	ev.append(e)


# ---------------------------------------------------------------- setup
func _setup(ta: Dictionary, tb: Dictionary, p_mseed: int, sets: Dictionary, ctx: Dictionary) -> void:
	mseed = p_mseed
	p = SimData.params()
	teams = {"B": ta, "R": tb}
	plan_sets = sets
	bonds = ctx.get("bonds", {"B": 50.0, "R": 50.0})
	for side in ["B", "R"]:
		var set_: Dictionary = sets.get(side, GamePlan.neutral_set())
		hooks[side] = GamePlan.hooks(set_["default"])
		var r := float(set_["default"].get("r", 0)) / 100.0
		var_mult[side] = float(teams[side].get("variance_mult", 1.0)) * (1.0 + 0.20 * r)
		var con0 := float(teams[side].get("con", 50.0))
		form[side] = maxf(0.6, 1.0 + float(p["noise_game"]) * MatchSim.noise_scale(con0) * float(var_mult[side]) * SimData.ih_normal(rng("form:" + side)))
	var m := SimData.map()
	for side in ["B", "R"]:
		var team: Dictionary = teams[side]
		for slot in SLOTS:
			var h := SimHero.new()
			h.side = side
			h.slot = slot
			h.key = side + "." + slot
			h.hid = String(ctx["picks"][side][slot])
			h.hero = SimData.heroes()[h.hid]
			h.kit = SimData.kit(h.hid)
			h.arch = String(h.hero["archetype"])
			var pl: Dictionary = ctx["players"][side][slot]
			h.player_id = String(pl.get("id", ""))
			h.pstats = pl.get("stats", {})
			var tm := float(team.get("team_mod", 0.0))
			for ph in ["early", "mid", "late"]:
				h.q[ph] = float(team["ratings"][ph][slot]) * (1.0 + tm) / float(p["q_ref"])
			h.init_kit(h.kit)
			h.qe_early *= float(form[side])
			h.qe_mid *= float(form[side])
			h.qe_late *= float(form[side])
			var b: Array = ctx.get("builds", {}).get(side, {}).get(slot, [])
			if not Items.is_legal(b):
				var enemy: Array = []
				for s2 in SLOTS:
					enemy.append(String(ctx["picks"][SimData.other(side)][s2]))
				b = Items.suggest(h.hid, slot, enemy)
			h.build = b.duplicate()
			h.gold = float(p["start_gold"])
			h.pos = m["spawn"][side][slot]
			h.max_hp = h.stat("hp")
			h.hp = h.max_hp
			h.next_decide = 0.5 + 0.1 * float(SLOTS.find(slot))
			heroes.append(h)
			by_key[h.key] = h
			track[h.key] = PackedFloat32Array()
			for iid in Items.shop(h):
				log_ev([0.0, "buy", h.key, iid])
	for tw in m["towers"]:
		var tier := String(tw["tier"])
		var spec: Dictionary = p["towers"][tier]
		towers.append({"id": tw["id"], "side": tw["side"], "lane": tw["lane"], "tier": tier, "pos": tw["pos"], "s": tw["s"],
				"hp": float(spec["hp"]), "max": float(spec["hp"]), "alive": true, "dmg": float(spec["dmg"])})
	for side in ["B", "R"]:
		var spec2: Dictionary = p["towers"]["cairn"]
		towers.append({"id": side + ".cairn", "side": side, "lane": "", "tier": "cairn", "pos": m["cairn"][side], "s": 0.0 if side == "B" else 1.0,
				"hp": float(spec2["hp"]), "max": float(spec2["hp"]), "alive": true, "dmg": 0.0})
	for ln in m["lanes"]:
		lanes[ln] = {"front": 0.5, "push": {"B": 0.0, "R": 0.0}}
		fronts[ln] = PackedFloat32Array()
	for c in m["camps"]:
		if String(c["kind"]) == "mossback":
			continue
		camps.append({"id": c["id"], "side": c["side"], "kind": c["kind"], "node": c["node"], "pos": c["pos"], "alive": false,
				"respawn_at": float(p["camp_first"])})
	for oid in ["stoneback", "moonhulk", "mossback"]:
		var o: Dictionary = p["objectives"][oid]
		objs[oid] = {"alive": false, "respawn_at": float(o["first"]), "hp": float(o["hp"]), "max": float(o["hp"]),
				"node": m["objectives"][oid]["node"], "pos": m["objectives"][oid]["pos"], "taker": ""}
	log_ev([0.0, "start", {"B": _picks_of("B"), "R": _picks_of("R")}])
	c_wave_g = float(p["wave_gold"]) / float(p["wave_every"])
	c_wave_x = float(p["wave_xp"]) / float(p["wave_every"])
	c_push_rate = float(p["push_rate"])
	c_floor = float(p["lasthit_floor"])
	c_sup_share = float(p["lane_share_sup"])
	c_plan_k = float(p["plan_k"])
	c_tower_r = float(p["tower_range_u"])
	c_sb_move = float(p["buffs"]["stoneback"]["move"])
	for side in ["B", "R"]:
		caller[side] = RoleAI._caller(self, side)
	for h in heroes:
		var lv := 99
		for a in h.abil:
			if (a as SimHero.Ability).wave:
				lv = mini(lv, (a as SimHero.Ability).unlock)
		_wave_lvl[h.key] = lv


func _picks_of(side: String) -> Dictionary:
	var o := {}
	for h in side_heroes(side):
		o[h.slot] = h.hid
	return o


# ---------------------------------------------------------------- main loop
func _run() -> void:
	var dt := float(p["dt"])
	var stop := float(p["safety_stop_s"])
	while winner == "" and t < stop:
		var u0 := Time.get_ticks_usec() if profiling else 0
		_spawns()
		_economy(dt)
		RoleAI.team_calls(self)
		var u1 := Time.get_ticks_usec() if profiling else 0
		_shuffle_order()
		for h in _order:
			var hh: SimHero = h
			if not hh.alive:
				if t >= hh.respawn_at:
					_respawn(hh)
				continue
			if hh.recall_at >= 0.0 and t >= hh.recall_at:
				_arrive_home(hh)
			if t >= hh.next_decide and t >= hh.busy_until and hh.recall_at < 0.0:
				if profiling:
					prof["n_decide"] = int(prof.get("n_decide", 0)) + 1
					prof["d_" + hh.slot] = int(prof.get("d_" + hh.slot, 0)) + 1
				RoleAI.decide(self, hh)
		var u2 := Time.get_ticks_usec() if profiling else 0
		_move(dt)
		_tick_cache()
		var u3 := Time.get_ticks_usec() if profiling else 0
		_lanes(dt)
		var u4 := Time.get_ticks_usec() if profiling else 0
		_gank_watch()
		RoleAI.lane_trades(self)
		var u5 := Time.get_ticks_usec() if profiling else 0
		_encounters()
		var u6 := Time.get_ticks_usec() if profiling else 0
		_objectives(dt)
		_camps_clear(dt)
		_plan_trigger()
		_sample()
		if profiling:
			var u7 := Time.get_ticks_usec()
			prof["ticks"] = int(prof.get("ticks", 0)) + 1
			for pr in [["calls", u1 - u0], ["decide", u2 - u1], ["move", u3 - u2], ["lanes", u4 - u3], ["trades", u5 - u4], ["encounters", u6 - u5], ["rest", u7 - u6]]:
				prof[pr[0]] = int(prof.get(pr[0], 0)) + int(pr[1])
		t += dt
	if winner == "":
		_safety_winner()


var _order: Array = []


## A fresh acting order every step (stream v2:order), so neither side always moves or decides first.
func _shuffle_order() -> void:
	if _order.is_empty():
		_order = heroes.duplicate()
	var r := rng("order")
	for i in range(_order.size() - 1, 0, -1):
		var j := int(r.next_float() * float(i + 1))
		var tmp = _order[i]
		_order[i] = _order[j]
		_order[j] = tmp


func _sample() -> void:
	if t < _next_track:
		return
	_next_track += TRACK_EVERY
	for h in heroes:
		var hh: SimHero = h
		var tr: PackedFloat32Array = track[hh.key]
		tr.append(hh.pos.x)
		tr.append(hh.pos.y)
		tr.append(hh.hp / maxf(1.0, hh.max_hp) if hh.alive else 0.0)
		tr.append(1.0 if hh.alive else 0.0)
		track[hh.key] = tr
	for ln in lanes:
		var fr: PackedFloat32Array = fronts[ln]
		fr.append(float(lanes[ln]["front"]))
		fronts[ln] = fr
	for side in ["B", "R"]:
		var gt: PackedFloat32Array = gold_track[side]
		gt.append(_team_gold(side))
		gold_track[side] = gt


func call_lead_s() -> float:
	return float(p["call_lead_s"])


func ward(side: String, zone: String) -> void:
	vision[side][zone] = t + float(p["vision_ward_s"])


func has_vision(side: String, zone: String) -> bool:
	return float(vision[side].get(zone, -1.0)) > t or (zone in ["top", "bot"] and float(vision[side].get("river", -1.0)) > t and zone == "bot")


func under_tower(h: SimHero) -> bool:
	for tw in towers:
		if tw["alive"] and String(tw["side"]) == h.side and String(tw["tier"]) != "cairn" and SimData.du(tw["pos"], h.pos) <= float(p["tower_range_u"]):
			return true
	return false


## The node a hero runs to when escaping: its spawn pad.
func first_safe_node(h: SimHero) -> String:
	return SimData.nearest_node(SimData.map()["spawn"][h.side][h.slot])


## A laner may see a gank coming (SEN, vision) and back off toward its tower (design 5.3, jungle).
func _gank_watch() -> void:
	for g in heroes:
		var gg: SimHero = g
		if not gg.alive or (gg.intent != "gank" and gg.intent != "roam"):
			continue
		for e in heroes_in_lane(gg.target, SimData.other(gg.side), 0.12):
			var ee: SimHero = e
			if ee.intent == "back_off" or SimData.du(gg.pos, ee.pos) > 0.20:
				continue
			var tag := "seen_%s_%d" % [gg.key.replace(".", "_"), int(gg.get_meta("gank_until", 0.0))]
			if ee.has_meta(tag):
				continue
			ee.set_meta(tag, true)
			var pr := 0.10 + 0.35 * ee.p_sen / 100.0 + 0.25 * float(has_vision(ee.side, gg.target))
			if rng(ee.key + ":dec").next_float() < pr:
				ee.intent = "back_off"
				var tw := first_tower(gg.target, ee.side)
				if not tw.is_empty():
					walk_to_point(ee, tw["pos"])
				ee.next_decide = t + 8.0
				log_ev([t, "intent", ee.key, "back_off", gg.key])


# ---------------------------------------------------------------- economy and levels
func _economy(dt: float) -> void:
	if t >= float(p["gold_passive_from"]):
		var lead_b := _team_gold("B") - _team_gold("R")
		for h in heroes:
			var hh: SimHero = h
			var g := float(p["gold_passive"]) + (float(p["gold_passive_sup"]) if hh.slot == "sup" else 0.0)
			var behind := -lead_b if hh.side == "B" else lead_b
			if behind > float(p["catchup_gold_from"]):
				g += float(p["catchup_gold"])
			give_gold(hh, g * dt)
	for side in ["B", "R"]:
		for b in buffs[side].keys():
			if t >= float(buffs[side][b]):
				buffs[side].erase(b)
	if t >= 480.0 and gold_at_8.is_empty():
		gold_at_8 = {"B": _team_gold("B"), "R": _team_gold("R")}
		for h in heroes:
			gold_at_8[h.key] = h.gold_total
	# per-minute passive stacks
	if t >= _next_min:
		_next_min += 60.0
		for h in heroes:
			var hh: SimHero = h
			if hh.pas.trigger == "stacks_per_min":
				hh.stacks += 1
				hh.dirty()
				_refresh_hp(hh)


func _team_gold(side: String) -> float:
	var g := 0.0
	for h in side_heroes(side):
		g += h.gold_total
	return g


func give_gold(h: SimHero, g: float) -> void:
	h.gold += g
	h.gold_total += g


func give_xp(h: SimHero, x: float) -> void:
	if h.level >= int(p["max_level"]):
		return
	# catch-up: a hero below the enemy's average level learns faster (up to +75 percent)
	var lv := 0.0
	for e in side_heroes(SimData.other(h.side)):
		lv += float(e.level)
	var behind := lv / 5.0 - float(h.level)
	if behind > 0.0:
		x *= 1.0 + minf(0.75, float(p["xp_catchup"]) * behind)
	h.xp += x
	while h.level < int(p["max_level"]):
		var need := float(p["xp_base"]) + float(p["xp_step"]) * float(h.level)
		if h.xp < need:
			break
		h.xp -= need
		h.level += 1
		h.dirty()
		_refresh_hp(h)
		log_ev([t, "level", h.key, h.level])


func _refresh_hp(h: SimHero) -> void:
	var frac := h.hp / maxf(1.0, h.max_hp)
	h.max_hp = h.stat("hp")
	h.hp = frac * h.max_hp


# ---------------------------------------------------------------- movement
func walk_to(h: SimHero, node: String) -> void:
	var start := SimData.nearest_node(h.pos)
	var pth := SimData.path(start, node)
	h.path = pth
	log_ev([t, "move", h.key, pth.duplicate(), h.intent, h.target])


func walk_to_point(h: SimHero, pt: Vector2) -> void:
	walk_to(h, SimData.nearest_node(pt))
	h.path.append(pt)


func _move(dt: float) -> void:
	for h in _order:
		var hh: SimHero = h
		if not hh.alive or t < hh.busy_until or hh.recall_at >= 0.0:
			continue
		var budget := hh.move_speed() * dt * (1.0 + (c_sb_move if buffs[hh.side].has("stoneback") else 0.0))
		# lane farming: follow the wave front
		if LANE_INTENTS.has(hh.intent) and hh.path.is_empty() and lanes.has(hh.target):
			var goal := lane_stand(hh, hh.target)
			hh.pos = _step_toward(hh.pos, goal, budget)
			continue
		if hh.intent == "follow" and hh.path.is_empty():
			var mate: SimHero = by_key[hh.side + ".bot"]
			var goal2: Vector2 = mate.pos if mate.alive else lane_stand(hh, "bot")
			hh.pos = _step_toward(hh.pos, goal2 + Vector2(0.0, 0.02 if hh.side == "B" else -0.02), budget)
			continue
		while budget > 0.0 and not hh.path.is_empty():
			var nxt = hh.path[0]
			var goal3: Vector2 = SimData.node_pos(String(nxt)) if nxt is String else nxt
			var d := SimData.du(hh.pos, goal3)
			if d <= budget:
				hh.pos = goal3
				budget -= d
				hh.path.pop_front()
				if hh.path.is_empty():
					hh.next_decide = minf(hh.next_decide, t + dt)
			else:
				hh.pos = _step_toward(hh.pos, goal3, budget)
				budget = 0.0


func _step_toward(a: Vector2, b: Vector2, budget: float) -> Vector2:
	var d := SimData.du(a, b)
	if d <= budget or d <= 0.0:
		return b
	return a + (b - a) * (budget / d)


## Where a hero stands in a lane: just on its own side of the front, the carry and support a little apart.
var _stand: Dictionary = {}


func lane_stand(h: SimHero, lane: String) -> Vector2:
	var back := 0.05 if h.slot == "sup" or h.slot == "jg" else 0.035
	if RANGED_ARCH.has(h.arch):
		back += 0.015
	var ck := (0 if lane == "top" else (1 if lane == "mid" else 2)) * 1000 + (0 if h.side == "B" else 100) + int(back * 1000.0)
	if _stand.has(ck):
		return _stand[ck]
	var s := float(lanes[lane]["front"])
	s += -back if h.side == "B" else back
	var pt := SimData.lane_point(lane, clampf(s, 0.02, 0.98))
	_stand[ck] = pt
	return pt


func dist_hero(a: SimHero, b: SimHero) -> float:
	return SimData.du(a.pos, b.pos)


# ---------------------------------------------------------------- spawns, camps, objectives
func _spawns() -> void:
	if _next_wave <= 0.0:
		_next_wave = float(p["wave_first"])
	if t >= _next_wave:
		_next_wave += float(p["wave_every"])
		_wave_n += 1
		log_ev([t, "wave", _wave_n])
	for c in camps:
		if not c["alive"] and t >= float(c["respawn_at"]):
			c["alive"] = true
	for oid in objs:
		var o: Dictionary = objs[oid]
		if not o["alive"] and t >= float(o["respawn_at"]):
			o["alive"] = true
			o["hp"] = float(o["max"])
			log_ev([t, "obj_up", oid])


func waves_on() -> bool:
	return t >= float(p["wave_first"])


func camp_by_id(cid: String) -> Dictionary:
	for c in camps:
		if String(c["id"]) == cid:
			return c
	return {}


## Jungle clearing: a jungler standing at a live camp with intent clear_camp takes it over a few seconds.
func _camps_clear(dt: float) -> void:
	for h in heroes:
		var hh: SimHero = h
		if not hh.alive or hh.intent != "clear_camp" or not hh.path.is_empty() or t < hh.busy_until:
			continue
		var c := camp_by_id(hh.target)
		if c.is_empty() or not c["alive"]:
			hh.next_decide = t
			continue
		if SimData.du(hh.pos, c["pos"]) > 0.03:
			continue
		var spec: Dictionary = p["camps"][String(c["kind"])]
		var dur := float(spec["hp"]) / maxf(30.0, monster_dps(hh))
		c["alive"] = false
		c["respawn_at"] = t + dur + float(p["camp_respawn"])
		hh.busy_until = t + dur
		hh.next_decide = t + dur
		give_gold(hh, float(spec["gold"]))
		hh.cs_gold += float(spec["gold"])
		give_xp(hh, float(spec["xp"]))
		var loss := 0.07 * (1.0 - 0.4 * minf(1.0, hh.s_ls + hh.s_ov + 0.1 * float(hh.pas.heal > 0.0)))
		hh.hp = maxf(hh.max_hp * 0.15, hh.hp - hh.max_hp * loss * (1.0 - 0.03 * float(hh.level)))
		log_ev([t, "camp", hh.key, String(c["id"]), t + dur])


## Damage per second against monsters and structures (no armour), used for camps, objectives and sieges.
func monster_dps(h: SimHero) -> float:
	var d := h.s_atk * h.s_aspd * (1.0 + 0.5 * h.s_crit)
	for x in h.abil:
		var a: SimHero.Ability = x
		if h.level >= a.unlock and a.dmg_k:
			var dmg := a.dmg + a.dmg_lvl * float(h.level - 1) + a.ratio * (h.s_ap if a.magic else h.s_atk * 0.5)
			d += dmg / maxf(2.0, a.cd)
	if h.pas.trigger == "vs_structure":
		d *= 1.0 + h.pas.amount
	if h.slot == "jg":
		d *= 1.35     # the jungler's monster bonus (no Smite spell, design 5.3)
	return d * h.qe(t) * (1.0 + float(hooks[h.side]["contest_mod"]["jungle"]) * float(p["plan_k"]) * (1.0 if h.slot == "jg" else 0.0))


## Neutral objectives: a team standing at a live objective with nobody contesting takes it over time.
func _objectives(dt: float) -> void:
	for oid in objs:
		var o: Dictionary = objs[oid]
		if not o["alive"]:
			continue
		var at := {"B": [], "R": []}
		for h in heroes:
			var hh: SimHero = h
			if hh.alive and t >= hh.busy_until and SimData.du(hh.pos, o["pos"]) <= 0.05:
				at[hh.side].append(hh)
		for side in ["B", "R"]:
			if at[side].is_empty() or not at[SimData.other(side)].is_empty():
				continue
			var dps := 0.0
			for hh2 in at[side]:
				dps += monster_dps(hh2)
			var ctx := "obj_mid" if oid != "moonhulk" else "obj_late"
			dps *= 1.0 + float(hooks[side]["contest_mod"][ctx]) * float(p["plan_k"])
			o["hp"] = float(o["hp"]) - dps * dt
			for hh3 in at[side]:
				hh3.hp = maxf(hh3.max_hp * 0.2, hh3.hp - hh3.max_hp * 0.004 * dt)
			if float(o["hp"]) <= 0.0:
				_take_objective(oid, side, at[side])
				break


func _take_objective(oid: String, side: String, takers: Array) -> void:
	var o: Dictionary = objs[oid]
	var spec: Dictionary = p["objectives"][oid]
	o["alive"] = false
	o["respawn_at"] = t + float(spec["respawn"])
	o["taker"] = side
	var best: SimHero = takers[0]
	for h in takers:
		var hh: SimHero = h
		if hh.slot == "jg":
			best = hh
	best.objectives += 1
	for h in side_heroes(side):
		give_gold(h, float(spec["gold_each"]))
		give_xp(h, float(spec["xp_each"]) * (1.0 if h in takers else 0.5))
	if oid == "mossback":
		for h in takers:
			give_gold(h, 120.0 / float(takers.size()))
	if String(spec["buff"]) != "":
		buffs[side][String(spec["buff"])] = t + float(spec["buff_s"])
	log_ev([t, "objective", oid, side, best.key])
	for h in takers:
		h.next_decide = t


# ---------------------------------------------------------------- lanes, waves and towers
func _tick_cache() -> void:
	_present.clear()
	_stand.clear()
	alive_n = {"B": 0, "R": 0}
	for h in heroes:
		if h.alive:
			alive_n[h.side] += 1
	for lane in lanes:
		_front_pt[lane] = SimData.lane_point(lane, float(lanes[lane]["front"]))
	var r2 := 0.09 * 0.09
	for lane in lanes:
		var fp: Vector2 = _front_pt[lane]
		var lb: Array = []
		var lr: Array = []
		for h in heroes:
			var hh: SimHero = h
			if hh.alive and t >= hh.busy_until and hh.recall_at < 0.0 and SimData.du2(hh.pos, fp) <= r2:
				if hh.side == "B":
					lb.append(hh)
				else:
					lr.append(hh)
		_present[lane + "B"] = lb
		_present[lane + "R"] = lr


func first_tower(lane: String, side: String) -> Dictionary:
	var ck := lane + side
	if _ft.has(ck):
		return _ft[ck]
	var tw := _first_tower(lane, side)
	_ft[ck] = tw
	return tw


## the next alive structure of `side` that the enemy meets coming down `lane` (lane towers, then guards, then the Cairn)
func _first_tower(lane: String, side: String) -> Dictionary:
	var best: Dictionary = {}
	for tw in towers:
		if not tw["alive"] or String(tw["side"]) != side:
			continue
		if String(tw["tier"]) in ["outer", "inner"] and String(tw["lane"]) == lane:
			if best.is_empty() or (side == "B" and float(tw["s"]) > float(best["s"])) or (side == "R" and float(tw["s"]) < float(best["s"])):
				best = tw
	if not best.is_empty():
		return best
	for tw in towers:
		if tw["alive"] and String(tw["side"]) == side and String(tw["tier"]) == "guard":
			return tw
	for tw in towers:
		if tw["alive"] and String(tw["side"]) == side and String(tw["tier"]) == "cairn":
			return tw
	return {}


func _tower_s(tw: Dictionary, side: String) -> float:
	if String(tw["tier"]) in ["guard", "cairn"]:
		return 0.03 if side == "B" else 0.97
	return float(tw["s"])


func heroes_in_lane(lane: String, side: String, radius: float = 0.09) -> Array:
	if radius == 0.09 and _present.has(lane + side):
		return _present[lane + side]
	var out: Array = []
	var fp: Vector2 = _front_pt[lane] if _front_pt.has(lane) else SimData.lane_point(lane, float(lanes[lane]["front"]))
	for h in side_heroes(side):
		var hh: SimHero = h
		if hh.alive and t >= hh.busy_until and hh.recall_at < 0.0 and SimData.du(hh.pos, fp) <= radius:
			out.append(hh)
	return out


func _lanes(dt: float) -> void:
	if not waves_on():
		return
	var wave_g := c_wave_g
	var wave_x := c_wave_x
	for lane in lanes:
		var L: Dictionary = lanes[lane]
		var push := {"B": 1.0, "R": 1.0}
		var present := {"B": heroes_in_lane(lane, "B"), "R": heroes_in_lane(lane, "R")}
		for side in ["B", "R"]:
			if buffs[side].has("moonhulk"):
				push[side] *= float(p["buffs"]["moonhulk"]["wave_mult"])
			for h in present[side]:
				var hh: SimHero = h
				push[side] += wave_power(hh)
		# a tower at the front kills the attackers' minions
		for side in ["B", "R"]:
			var tw := first_tower(lane, side)
			if not tw.is_empty() and absf(float(L["front"]) - _tower_s(tw, side)) <= 0.04:
				push[side] += 0.9
		L["push"] = push
		var ds := c_push_rate * (float(push["B"]) - float(push["R"])) * dt
		var front := float(L["front"]) + ds
		var tb := first_tower(lane, "R")
		var tbb := first_tower(lane, "B")
		var lim_hi := _tower_s(tb, "R") if not tb.is_empty() else 1.0
		var lim_lo := _tower_s(tbb, "B") if not tbb.is_empty() else 0.0
		L["front"] = clampf(front, lim_lo, lim_hi)
		# farming at the front
		for side in ["B", "R"]:
			var mine: Array = present[side]
			if mine.is_empty():
				continue
			var opp: Array = present[SimData.other(side)]
			var share_x := wave_x * dt / float(mine.size())
			for h in mine:
				var hh: SimHero = h
				if hh.slot == "jg" and hh.intent != "farm_lane":
					continue
				var eff := c_floor + (1.0 - c_floor) * (0.5 * hh.p_lan + 0.5 * hh.p_mec) / 100.0
				var pressure := 1.0
				if not opp.is_empty():
					var mine_hp := hh.hp / maxf(1.0, hh.max_hp)
					var their_hp := 0.0
					for o in opp:
						their_hp += o.hp / maxf(1.0, o.max_hp)
					their_hp /= float(opp.size())
					pressure = clampf(1.0 + 0.3 * (mine_hp - their_hp), 0.7, 1.1)
				var share := 1.0
				if lane == "bot" and mine.size() > 1:
					share = c_sup_share if hh.slot == "sup" else 1.0 - c_sup_share
				elif mine.size() > 1:
					share = 1.0 / float(mine.size())
				var lane_ctx: String = {"top": "top", "mid": "mid_lane", "bot": "bot"}[lane]
				var g := wave_g * eff * pressure * share * hh.qe(t) * (1.0 + float(hooks[side]["contest_mod"][lane_ctx]) * c_plan_k) * dt
				give_gold(hh, g)
				hh.cs_gold += g
				give_xp(hh, share_x)
		# sieges: the front at a structure hurts it
		for side in ["B", "R"]:
			var enemy := SimData.other(side)
			var tw2 := first_tower(lane, enemy)
			if tw2.is_empty():
				continue
			if absf(float(L["front"]) - _tower_s(tw2, enemy)) > 0.045:
				continue
			if float(push[side]) <= float(push[enemy]) - 0.9 + 0.3:
				continue
			var dps := float(p["wave_tower_dps"]) * (float(push[side]) / 2.0) * (float(p["buffs"]["moonhulk"]["wave_mult"]) if buffs[side].has("moonhulk") else 1.0)
			for h in present[side]:
				var hh: SimHero = h
				if not hh.alive:
					continue
				dps += monster_dps(hh) * 0.7 * float(p["hero_struct_mult"]) * (1.0 + (float(p["buffs"]["moonhulk"]["struct_dmg"]) if buffs[side].has("moonhulk") else 0.0))
				if present[enemy].is_empty() and String(tw2["tier"]) != "cairn" and float(push[side]) < 1.6:
					hh.hp -= float(tw2["dmg"]) * 0.25 * dt * float(p["armor_k"]) / (float(p["armor_k"]) + hh.s_armor)
					if hh.hp <= 0.0:
						hh.hp = 0.0
						on_tower_kill(hh, enemy, t)
			if String(tw2["tier"]) == "cairn":
				var guards_up := false
				for g2 in towers:
					if g2["alive"] and String(g2["side"]) == enemy and String(g2["tier"]) == "guard":
						guards_up = true
				if guards_up:
					continue
			if t < float(p["fortify_s"]):
				dps *= float(p["fortify_mult"])
			tw2["hp"] = float(tw2["hp"]) - dps * dt
			if float(tw2["hp"]) <= 0.0:
				_tower_falls(tw2, side, present[side])


func wave_power(h: SimHero) -> float:
	var w := 0.35 + 0.03 * float(h.level) + h.item_value() / 9000.0
	if h.level >= int(_wave_lvl[h.key]):
		w += 0.35
	if h.slot == "sup":
		w *= 0.4
	return w


func _tower_falls(tw: Dictionary, by_side: String, present: Array) -> void:
	tw["alive"] = false
	_ft.clear()
	tw["hp"] = 0.0
	var tier := String(tw["tier"])
	if tier == "cairn":
		winner = by_side
		end_reason = "cairn"
		log_ev([t, "tower", String(tw["id"]), by_side, ""])
		log_ev([t, "end", winner, end_reason])
		return
	var spec: Dictionary = p["towers"][tier]
	for h in side_heroes(by_side):
		give_gold(h, float(spec["gold_team"]) / 5.0)
	var by := ""
	if not present.is_empty():
		var hh: SimHero = present[0]
		for x in present:
			if x.slot < hh.slot:
				hh = x
		by = hh.key
		hh.towers += 1
		for x in present:
			give_gold(x, float(spec["gold_local"]) / float(present.size()))
			give_xp(x, 100.0 / float(present.size()))
	log_ev([t, "tower", String(tw["id"]), by_side, by])


# ---------------------------------------------------------------- encounters and fights
func _encounters() -> void:
	var r := float(p["engage_u"])
	var r2 := r * r
	var done := {}
	var bl: Array = []
	var rl: Array = []
	for h in heroes:
		var hh: SimHero = h
		if hh.alive and t >= hh.busy_until:
			if hh.side == "B":
				bl.append(hh)
			else:
				rl.append(hh)
	var first: Array = bl if int(t / float(p["dt"])) % 2 == 0 else rl
	var second: Array = rl if int(t / float(p["dt"])) % 2 == 0 else bl
	for a in first:
		var ha: SimHero = a
		if done.has(ha.key):
			continue
		for b in second:
			var hb: SimHero = b
			if done.has(hb.key):
				continue
			if SimData.du2(ha.pos, hb.pos) > r2:
				continue
			var kind: String = RoleAI.fight_wanted(self, ha, hb)
			if kind == "":
				continue
			var parts := _participants((ha.pos + hb.pos) / 2.0)
			if parts.size() < 2:
				continue
			for pr in parts:
				done[(pr[0] as SimHero).key] = true
			fight((ha.pos + hb.pos) / 2.0, parts, kind)
			break


## Everyone close enough to join: [[hero, join delay s], ...]. Heroes already in the area join at once.
func _participants(center: Vector2) -> Array:
	var out: Array = []
	var near := float(p["fight_center_u"])
	var join := float(p["join_u"])
	for h in heroes:
		var hh: SimHero = h
		if not hh.alive or t < hh.busy_until or hh.recall_at >= 0.0:
			continue
		var d := SimData.du(hh.pos, center)
		if d <= near:
			out.append([hh, 0.0])
		elif d <= join and RoleAI.joins(self, hh, center):
			out.append([hh, (d - near) / maxf(0.01, hh.move_speed())])
	return out


func fight(center: Vector2, parts: Array, kind: String) -> FightV2:
	fight_n += 1
	var sides := {"B": 0, "R": 0}
	for pr in parts:
		sides[(pr[0] as SimHero).side] += 1
	if int(sides["B"]) + int(sides["R"]) >= 6:
		kind = "teamfight"
	var f := FightV2.new()
	var uf := Time.get_ticks_usec() if profiling else 0
	f.run(self, parts, t, center, kind, fight_n)
	if profiling:
		prof["fight"] = int(prof.get("fight", 0)) + Time.get_ticks_usec() - uf
		prof["fights"] = int(prof.get("fights", 0)) + 1
	for e in f.events:
		ev.append(e)
	for pr in parts:
		var hh: SimHero = pr[0]
		hh.path = []
		hh.next_decide = f.t
		if hh.alive and bool(f.st[hh.key]["fled"]):
			hh.intent = "escape"
			hh.target = ""
	return f


## Kill bookkeeping (called by FightV2): gold, experience, streaks, respawn timer, first blood.
func on_kill(killer: SimHero, victim: SimHero, assists: Array, at_t: float) -> void:
	victim.alive = false
	victim.hp = 0.0
	victim.deaths += 1
	victim.path = []
	victim.recall_at = -1.0
	victim.respawn_at = at_t + float(p["respawn_base"]) + float(p["respawn_lvl"]) * float(victim.level)
	var bounty := minf(float(p["kill_gold_max"]), float(p["kill_gold"]) + float(p["kill_streak_step"]) * float(maxi(0, victim.streak - 1)))
	if victim.streak == 0 and victim.deaths > 2:
		bounty *= 0.7
	# a kill on the team that leads in gold pays more (comeback bounty)
	var lead := _team_gold(victim.side) - _team_gold(killer.side)
	if lead > 0.0:
		bounty *= 1.0 + clampf(lead / float(p["comeback_lead"]), 0.0, float(p["comeback_max"]))
	victim.streak = 0
	killer.kills += 1
	killer.streak += 1
	give_gold(killer, bounty)
	var xp := float(p["kill_xp_base"]) + float(p["kill_xp_lvl"]) * float(victim.level)
	give_xp(killer, xp * (0.6 if not assists.is_empty() else 1.0))
	team_kills[killer.side] = int(team_kills[killer.side]) + 1
	if first_blood == "":
		first_blood = killer.side
	for k in assists:
		var a: SimHero = by_key[k]
		if a.side == killer.side:
			a.assists += 1
			give_gold(a, bounty * float(p["assist_share"]) / float(assists.size()))
			give_xp(a, xp * 0.4 / float(assists.size()))


func on_tower_kill(victim: SimHero, tower_side: String, at_t: float) -> void:
	# a hero an enemy damaged in the last 10 s is that enemy's kill (assists as usual); otherwise a death without a kill
	var killer: SimHero = null
	var last_t := -INF
	var assists: Array = []
	for k in victim.last_hit_by:
		if at_t - float(victim.last_hit_by[k]) <= 10.0 and by_key.has(k) and (by_key[k] as SimHero).side != victim.side:
			assists.append(k)
			if float(victim.last_hit_by[k]) > last_t:
				last_t = float(victim.last_hit_by[k])
				killer = by_key[k]
	if killer != null:
		assists.erase(killer.key)
		assists.sort()
		on_kill(killer, victim, assists, at_t)
		log_ev([at_t, "kill", killer.key, victim.key, assists])
		return
	victim.alive = false
	victim.hp = 0.0
	victim.deaths += 1
	victim.path = []
	victim.recall_at = -1.0
	victim.streak = 0
	victim.respawn_at = at_t + float(p["respawn_base"]) + float(p["respawn_lvl"]) * float(victim.level)
	log_ev([at_t, "kill", "tower." + tower_side, victim.key, []])


func _respawn(h: SimHero) -> void:
	h.alive = true
	h.pos = SimData.map()["spawn"][h.side][h.slot]
	h.max_hp = h.stat("hp")
	h.hp = h.max_hp
	h.last_hit_by = {}
	h.revive_used = false
	h.next_decide = t
	h.intent = "spawn"
	log_ev([t, "respawn", h.key])
	for iid in Items.shop(h):
		log_ev([t, "buy", h.key, iid])
	_refresh_hp(h)
	h.hp = h.max_hp


func start_recall(h: SimHero) -> void:
	h.intent = "recall"
	h.target = ""
	h.path = []
	h.recall_at = t + float(p["recall_s"])
	log_ev([t, "recall", h.key])


func _arrive_home(h: SimHero) -> void:
	h.recall_at = -1.0
	h.pos = SimData.map()["spawn"][h.side][h.slot]
	for iid in Items.shop(h):
		log_ev([t, "buy", h.key, iid])
	_refresh_hp(h)
	h.hp = h.max_hp
	h.next_decide = t
	log_ev([t, "home", h.key])


## Team factor in a fight (CompMod, style edge in team fights, Game Plan, consistency noise; design 5.1).
func fight_factor(side: String, kind: String, n: int, at_t: float, frng: Pcg32) -> float:
	var team: Dictionary = teams[side]
	var k := 1.0 + float(team.get("comp_mod", 0.0)) * float(p["comp_fight"])
	if n >= 6:
		var edge := MatchSim.style_edge_for_a(String(team["style"]), String(teams[SimData.other(side)]["style"]), MatchRunner.sim_params())
		k *= 1.0 + edge * float(p["style_fight"])
	var late := at_t >= 1080.0
	var ctx := ("fight_late" if late else "fight_mid") if kind in ["teamfight", "objective"] else ("obj_late" if late else "obj_mid")
	if at_t < 480.0 and kind in ["skirmish", "gank"]:
		ctx = "jungle" if kind == "gank" else "top"
	k *= 1.0 + float(hooks[side]["contest_mod"][ctx]) * float(p["plan_k"])
	if buffs[side].has("stoneback"):
		k *= 1.0 + float(p["buffs"]["stoneback"].get("dmg", 0.0))
	var con := float(team.get("con", 50.0))
	var sigma := float(p["noise_base"]) * MatchSim.noise_scale(con) * float(var_mult[side]) * float(hooks[side]["contest_var"][ctx])
	k *= 1.0 + sigma * SimData.ih_normal(frng) * float(p["noise_con"])
	return maxf(0.5, k)


# ---------------------------------------------------------------- game plan trigger and end
func _plan_trigger() -> void:
	if t < float(p["early_end_s"]) or t >= float(p["early_end_s"]) + float(p["dt"]):
		return
	var lead := _team_gold("B") - _team_gold("R")
	var thr := float(GamePlan.data()["trigger_threshold"])
	early_metric = clampf(lead / float(p["trigger_lead_gold"]) * thr, -1.0, 1.0)
	for side in ["B", "R"]:
		var set_: Dictionary = plan_sets.get(side, GamePlan.neutral_set())
		var mine := early_metric if side == "B" else -early_metric
		var ch := GamePlan.choose(set_, mine, String(teams[SimData.other(side)]["style"]))
		plan_used[side] = String(ch["name"])
		if String(ch["name"]) != "default":
			var h_late := GamePlan.hooks(ch["plan"])
			var h_early: Dictionary = hooks[side]
			# early contests keep the default plan's hooks (GDD 7.8)
			for c in GamePlan.EARLY:
				h_late["contest_mod"][c] = h_early["contest_mod"][c]
				h_late["contest_var"][c] = h_early["contest_var"][c]
			hooks[side] = h_late
			log_ev([t, "plan", side, String(ch["name"])])


func _safety_winner() -> void:
	var score := {"B": 0.0, "R": 0.0}
	for tw in towers:
		if not tw["alive"]:
			score[SimData.other(String(tw["side"]))] += 1000.0
	score["B"] += _team_gold("B")
	score["R"] += _team_gold("R")
	winner = "B" if float(score["B"]) > float(score["R"]) else "R"
	end_reason = "safety"
	log_ev([t, "end", winner, end_reason])


# ---------------------------------------------------------------- result
## Fight events carry their own (later) times, so the log is sorted at the end; ties keep the order they were written in.
func _sort_log() -> void:
	var keyed: Array = []
	for i in ev.size():
		keyed.append([float(ev[i][0]), i])
	keyed.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	var out: Array = []
	for k in keyed:
		out.append(ev[int(k[1])])
	ev = out


## The track samples a hero's state when the macro step resolves a fight, but a kill inside the fight happens later; rewrite
## the alive flag (and zero the health) from the kill and respawn times so the track agrees with the log.
func _fix_track() -> void:
	var dead: Dictionary = {}     # key -> [[from, to], ...]
	var open: Dictionary = {}
	for e in ev:
		if String(e[1]) == "kill":
			open[String(e[3])] = float(e[0])
		elif String(e[1]) == "respawn" and open.has(String(e[2])):
			if not dead.has(String(e[2])):
				dead[String(e[2])] = []
			dead[String(e[2])].append([float(open[String(e[2])]), float(e[0])])
			open.erase(String(e[2]))
	for k in open:
		if not dead.has(k):
			dead[k] = []
		dead[k].append([float(open[k]), INF])
	for k in track:
		var tr: PackedFloat32Array = track[k]
		var spans: Array = dead.get(k, [])
		for i in tr.size() / 4:
			var ti := float(i) * TRACK_EVERY
			var is_dead := false
			for sp in spans:
				if ti >= float(sp[0]) and ti < float(sp[1]):
					is_dead = true
			tr[i * 4 + 3] = 0.0 if is_dead else 1.0
			if is_dead:
				tr[i * 4 + 2] = 0.0
			elif tr[i * 4 + 2] <= 0.0:
				tr[i * 4 + 2] = 1.0
		track[k] = tr


## The game ends when the Cairn falls; fights resolved ahead of time may have written later events. Drop them and recount
## kills, deaths and assists from the log that remains (the scoreboard and the report read these).
func _cut_after_end() -> void:
	var t_end := t
	for e in ev:
		if String(e[1]) == "end":
			t_end = float(e[0])
	var kept: Array = []
	var end_ev: Array = []
	for e in ev:
		if String(e[1]) == "end":
			end_ev = e
		elif float(e[0]) <= t_end:
			kept.append(e)
	if not end_ev.is_empty():
		kept.append(end_ev)
	ev = kept
	t = t_end
	team_kills = {"B": 0, "R": 0}
	for h in heroes:
		h.kills = 0
		h.deaths = 0
		h.assists = 0
	for e in ev:
		if String(e[1]) != "kill":
			continue
		var victim: SimHero = by_key[String(e[3])]
		victim.deaths += 1
		if String(e[2]).begins_with("tower."):
			continue
		var killer: SimHero = by_key[String(e[2])]
		killer.kills += 1
		team_kills[killer.side] = int(team_kills[killer.side]) + 1
		for k in e[4]:
			if by_key.has(String(k)) and (by_key[String(k)] as SimHero).side == killer.side:
				(by_key[String(k)] as SimHero).assists += 1


func _result() -> Dictionary:
	_sort_log()
	_cut_after_end()
	_fix_track()
	var a_won := winner == "B"
	# the end margin, signed for Blue, on the v1 scale (|final| median about 0.34; narrow, clear, decisive about 25 / 40 / 35
	# percent, so Report.result_word, the Form Rating and the standings margin keep their meaning; design 9.1)
	var gl := (_team_gold("B") - _team_gold("R")) / float(p["final_gold"])
	var structs := 0.0
	for tw in towers:
		if not tw["alive"]:
			structs += -1.0 if String(tw["side"]) == "B" else 1.0
	var final := clampf(structs * float(p["final_struct"]) + gl, -0.99, 0.99)
	if a_won and final <= 0.0:
		final = 0.01
	if not a_won and final >= 0.0:
		final = -0.01
	var contests := _contests()
	var per := {}
	for h in heroes:
		var hh: SimHero = h
		per[hh.key] = {"hero": hh.hid, "player": hh.player_id, "k": hh.kills, "d": hh.deaths, "a": hh.assists, "gold": int(hh.gold_total),
				"cs_gold": int(hh.cs_gold), "level": hh.level, "dmg": int(hh.dmg_heroes), "taken": int(hh.dmg_taken), "healed": int(hh.healed),
				"objectives": hh.objectives, "towers": hh.towers, "items": hh.owned.duplicate(), "build": hh.build.duplicate(),
				"gold_8": int(gold_at_8.get(hh.key, 0)), "ganks": hh.ganks, "wards": int(hh.vision)}
	var towers_down := {"B": 0, "R": 0}
	for tw in towers:
		if not tw["alive"] and String(tw["tier"]) in ["outer", "inner"]:
			towers_down[SimData.other(String(tw["side"]))] += 1
	return {"a_won": a_won, "final": final, "early": early_metric, "mid": float(contests["fight_mid"]), "late": float(contests["fight_late"]),
			"contests": contests, "noise": {}, "plan_used": plan_used.duplicate(), "v": 2, "len_s": t, "end_reason": end_reason,
			"team_kills": team_kills.duplicate(), "towers": towers_down, "per": per, "first_blood": first_blood,
			"gold": {"B": int(_team_gold("B")), "R": int(_team_gold("R"))},
			"log": {"v": 2, "len_s": t, "ev": ev, "track": track, "fronts": fronts, "gold": gold_track, "track_every": TRACK_EVERY}}


## v1-shaped contest values (signed for Blue, -1 to 1) read from the game, so readers of the v1 keys keep working.
func _contests() -> Dictionary:
	var c := {}
	var g8: Dictionary = gold_at_8 if not gold_at_8.is_empty() else {}
	for pair in [["top", ["top"]], ["mid_lane", ["mid"]], ["bot", ["bot", "sup"]], ["jungle", ["jg"]]]:
		var lead := 0.0
		for s in pair[1]:
			lead += float(g8.get("B." + s, 0.0)) - float(g8.get("R." + s, 0.0))
		c[pair[0]] = clampf(lead / 900.0, -1.0, 1.0)
	var k_mid := 0.0
	var k_late := 0.0
	var obj_mid := 0.0
	var obj_late := 0.0
	for e in ev:
		if String(e[1]) == "kill":
			var ks := String(e[2])
			var sgn := 1.0 if ks.begins_with("B") or ks == "tower.B" else -1.0
			if float(e[0]) >= 480.0 and float(e[0]) < 1080.0:
				k_mid += sgn
			elif float(e[0]) >= 1080.0:
				k_late += sgn
		elif String(e[1]) == "objective":
			var sg2 := 1.0 if String(e[3]) == "B" else -1.0
			if String(e[2]) == "moonhulk":
				obj_late += sg2
			elif String(e[2]) == "stoneback":
				obj_mid += sg2
	c["obj_mid"] = clampf(obj_mid * 0.6, -1.0, 1.0)
	c["fight_mid"] = clampf(k_mid / 5.0, -1.0, 1.0)
	c["obj_late"] = clampf(obj_late * 0.6, -1.0, 1.0)
	var end_sign := 1.0 if winner == "B" else -1.0
	c["fight_late"] = clampf(k_late / 5.0 + 0.3 * end_sign, -1.0, 1.0)
	return c
