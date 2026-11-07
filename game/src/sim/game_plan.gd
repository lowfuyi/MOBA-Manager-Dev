class_name GamePlan
extends RefCounted
## Game Plan (GDD 7.8): the coach's second lever besides the draft. A plan is 8 controls; it acts on
## the simulator only through contest_mod / contest_var hooks, so MatchSim itself is unchanged.
## A "plan set" is {"default": plan, "triggers": [{"when": <trigger id>, "plan": plan}, ...]} in priority order.

const CONTESTS := ["top", "mid_lane", "bot", "jungle", "obj_mid", "fight_mid", "obj_late", "fight_late"]
const EARLY := ["top", "mid_lane", "bot", "jungle"]
const SLIDERS := ["g", "t", "m", "l", "a", "s", "r"]
const JUNGLE_CHOICES := ["none", "top", "mid_lane", "bot"]
const TRIGGERS := ["behind_early", "ahead_early", "vs_dive", "vs_siege", "vs_protect"]
const STEPS := [-100, -50, 0, 50, 100]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = DataLoader.load_json("res://data/game_plan_v0.json")
		_data = d if d is Dictionary else {}
	return _data


static func neutral() -> Dictionary:
	var p := {"jf": "none"}
	for s in SLIDERS:
		p[s] = 0
	return p


static func neutral_set() -> Dictionary:
	return {"default": neutral(), "triggers": []}


static func is_neutral(plan: Dictionary) -> bool:
	for s in SLIDERS:
		if int(plan.get(s, 0)) != 0:
			return false
	return String(plan.get("jf", "none")) == "none"


static func normalized(plan: Dictionary) -> Dictionary:
	var p := neutral()
	for s in SLIDERS:
		p[s] = clampi(int(plan.get(s, 0)), -100, 100)
	var jf := String(plan.get("jf", "none"))
	p["jf"] = jf if jf in JUNGLE_CHOICES else "none"
	return p


## contest_mod / contest_var dictionaries (all 8 contests present) for one plan.
static func hooks(plan: Dictionary) -> Dictionary:
	var mod := {}
	var vr := {}
	for c in CONTESTS:
		mod[c] = 0.0
		vr[c] = 1.0
	var controls: Dictionary = data()["controls"]
	for id in SLIDERS:
		var x := float(plan.get(id, 0)) / 100.0
		if x == 0.0:
			continue
		var spec: Dictionary = controls[id]
		for k in spec.get("mod", {}):
			mod[k] += float(spec["mod"][k]) * x
		for k in spec.get("var", {}):
			vr[k] *= 1.0 + float(spec["var"][k]) * x
	var jf := String(plan.get("jf", "none"))
	if jf != "none":
		var j: Dictionary = data()["jungle_focus"]
		mod["jungle"] += float(j["jungle"])
		mod[jf] += float(j["chosen"])
	return {"contest_mod": mod, "contest_var": vr}


## Sum over contests of final_weight * contest_mod: must be 0 for every control (zero-sum in rating).
static func weighted_mod_sum(plan: Dictionary) -> float:
	var h := hooks(plan)
	var w: Dictionary = data()["final_weights"]
	var total := 0.0
	for c in CONTESTS:
		total += float(w[c]) * float(h["contest_mod"][c])
	return total


## Which plan applies, given the early-game result from this team's point of view
## (early_for_me > 0 = this team leads) and the opponent's composition style.
static func choose(plan_set: Dictionary, early_for_me: float, opp_style: String) -> Dictionary:
	var thr := float(data()["trigger_threshold"])
	for t in plan_set.get("triggers", []):
		var hit := false
		match String(t["when"]):
			"behind_early":
				hit = early_for_me < -thr
			"ahead_early":
				hit = early_for_me > thr
			"vs_dive":
				hit = opp_style == "dive"
			"vs_siege":
				hit = opp_style == "siege"
			"vs_protect":
				hit = opp_style == "protect"
		if hit:
			return {"name": String(t["when"]), "plan": t["plan"]}
	return {"name": "default", "plan": plan_set["default"]}


static func _hooked(team: Dictionary, h_early: Dictionary, h_late: Dictionary) -> Dictionary:
	var t := team.duplicate()
	var mod := {}
	var vr := {}
	for c in CONTESTS:
		var src: Dictionary = h_early if c in EARLY else h_late
		mod[c] = src["contest_mod"][c]
		vr[c] = src["contest_var"][c]
	t["contest_mod"] = mod
	t["contest_var"] = vr
	return t


## Full match with plans. sets = {"B": plan_set, "R": plan_set} (Blue = simulator team A); a missing side
## plays neutral. Two passes (GDD 7.8): pass 1 with the default plans reads the early result, then the
## final pass uses the default plans' early hooks and the chosen plans' mid and late hooks.
static func simulate(ta: Dictionary, tb: Dictionary, mseed: int, p: Dictionary, sets: Dictionary = {}) -> Dictionary:
	var set_a: Dictionary = sets.get("B", neutral_set())
	var set_b: Dictionary = sets.get("R", neutral_set())
	var ha := hooks(set_a["default"])
	var hb := hooks(set_b["default"])
	var r1 := MatchSim.simulate(_hooked(ta, ha, ha), _hooked(tb, hb, hb), mseed, p)
	var early := float(r1["early"])
	var ca := choose(set_a, early, String(tb["style"]))
	var cb := choose(set_b, -early, String(ta["style"]))
	var r := r1
	if ca["name"] != "default" or cb["name"] != "default":
		var hca := hooks(ca["plan"])
		var hcb := hooks(cb["plan"])
		r = MatchSim.simulate(_hooked(ta, ha, hca), _hooked(tb, hb, hcb), mseed, p)
	r["plan_used"] = {"B": ca["name"], "R": cb["name"]}
	return r


## Noise-free evaluation (sigma 0): the deterministic part of the result, used by the coach and the edges view.
static func expected_final(ta: Dictionary, tb: Dictionary, p: Dictionary, sets: Dictionary = {}) -> float:
	var p0 := p.duplicate()
	p0["sigma"] = 0.0
	return float(simulate(ta, tb, 1, p0, sets)["final"])


## Rating of both teams in each contest, same formulas as MatchSim (for the "where you stand" view).
## Returns {contest: [rating_blue, rating_red]}.
static func contest_ratings(ta: Dictionary, tb: Dictionary, p: Dictionary) -> Dictionary:
	var out := {}
	out["top"] = [MatchSim._eff(ta, "early", "top", "top"), MatchSim._eff(tb, "early", "top", "top")]
	out["mid_lane"] = [MatchSim._eff(ta, "early", "mid", "mid"), MatchSim._eff(tb, "early", "mid", "mid")]
	out["bot"] = [(MatchSim._eff(ta, "early", "bot", "bot") + MatchSim._eff(ta, "early", "sup", "bot")) / 2.0,
			(MatchSim._eff(tb, "early", "bot", "bot") + MatchSim._eff(tb, "early", "sup", "bot")) / 2.0]
	out["jungle"] = [MatchSim._eff(ta, "early", "jg", "jg"), MatchSim._eff(tb, "early", "jg", "jg")]
	var edge := MatchSim.style_edge_for_a(String(ta["style"]), String(tb["style"]), p)
	for ph in ["mid", "late"]:
		var ra := MatchSim._team_ratings(ta, ph, edge, p)
		var rb := MatchSim._team_ratings(tb, ph, -edge, p)
		out["obj_" + ph] = [ra[0], rb[0]]
		out["fight_" + ph] = [ra[1], rb[1]]
	return out


## Coach's suggestion for `side` ("B" or "R"): coordinate ascent on the noise-free result against the
## opponent's neutral plan, then the variance controls by who is the favourite. Deterministic.
static func suggest(ta: Dictionary, tb: Dictionary, p: Dictionary, side: String) -> Dictionary:
	var sgn := 1.0 if side == "B" else -1.0
	var plan := neutral()
	var best := _score(ta, tb, p, plan, side, sgn)
	for _pass in 1:
		for id in ["g", "t", "m", "l", "s"]:
			for v in [-100, 0, 100]:
				var cand := plan.duplicate()
				cand[id] = v
				var sc := _score(ta, tb, p, cand, side, sgn)
				if sc > best + 1e-9:
					best = sc
					plan = cand
		for jf in JUNGLE_CHOICES:
			var cand2 := plan.duplicate()
			cand2["jf"] = jf
			var sc2 := _score(ta, tb, p, cand2, side, sgn)
			if sc2 > best + 1e-9:
				best = sc2
				plan = cand2
	var fav := sgn * expected_final(ta, tb, p, {side: {"default": plan, "triggers": []}})
	if fav > 0.08:
		plan["r"] = -50
		plan["a"] = -50
	elif fav < -0.08:
		plan["r"] = 50
		plan["a"] = 50
	return plan


static func _score(ta: Dictionary, tb: Dictionary, p: Dictionary, plan: Dictionary, side: String, sgn: float) -> float:
	return sgn * expected_final(ta, tb, p, {side: {"default": plan, "triggers": []}})


static func suggest_set(ta: Dictionary, tb: Dictionary, p: Dictionary, side: String) -> Dictionary:
	return {"default": suggest(ta, tb, p, side), "triggers": []}
