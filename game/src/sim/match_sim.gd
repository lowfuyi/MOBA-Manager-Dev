class_name MatchSim
extends RefCounted
## Match simulator (GDD section 8). Port of tools/sim_core.py; must reproduce
## res://tests/golden/sim_vectors.json. Team A is Blue side.
## Every contest draws one Normal(0,1) from its own named PCG32 substream.
## Order of floating-point operations mirrors the Python reference on purpose.

const SLOTS := ["top", "jg", "mid", "bot", "sup"]


static func load_params(path: String = "res://data/sim_params.json") -> Dictionary:
	var p = DataLoader.load_json(path)
	return p if p is Dictionary else {}


static func noise_scale(avg_con: float) -> float:
	return 1.4 - 0.8 * (avg_con / 100.0)


static func style_edge_for_a(style_a: String, style_b: String, p: Dictionary) -> float:
	var beats: Dictionary = p["style_beats"]
	if beats.get(style_a, "") == style_b:
		return float(p["style_edge"])
	if beats.get(style_b, "") == style_a:
		return -float(p["style_edge"])
	return 0.0


static func _weighted(r: Dictionary, w: Dictionary) -> float:
	var total := 0.0
	for s in w:
		total += float(w[s]) * float(r[s])
	return total


static func _eff(team: Dictionary, phase: String, slot: String, lane_key: String = "") -> float:
	var r: float = float(team["ratings"][phase][slot]) * (1.0 + float(team["team_mod"]))
	if lane_key != "":
		r *= 1.0 + float(team["lane_mod"].get(lane_key, 0.0))
	return r


static func _team_ratings(team: Dictionary, phase: String, style_bonus: float, p: Dictionary) -> Array:
	var r := {}
	for s in SLOTS:
		r[s] = _eff(team, phase, s)
	var obj := _weighted(r, p["obj_w"]) * (1.0 + float(team["comp_mod"]))
	var fight := _weighted(r, p["fight_w"]) * (1.0 + float(team["comp_mod"]) + style_bonus)
	return [obj, fight]


static func _contest(name: String, a: float, b: float, carry: float, mseed: int, base_a: float, base_b: float,
		ta: Dictionary, tb: Dictionary, p: Dictionary, noise: Dictionary) -> float:
	a = a * (1.0 + float(ta.get("contest_mod", {}).get(name, 0.0)))
	b = b * (1.0 + float(tb.get("contest_mod", {}).get(name, 0.0)))
	var s_a: float = base_a * float(ta.get("contest_var", {}).get(name, 1.0))
	var s_b: float = base_b * float(tb.get("contest_var", {}).get(name, 1.0))
	var sigma_eff := sqrt((s_a * s_a + s_b * s_b) / 2.0)
	var z := 0.0
	if sigma_eff > 0.0:    # sigma 0 is the noise-free evaluation used by the Game Plan coach
		z = Pcg32.contest_stream(mseed, name).next_normal() * sigma_eff
	noise[name] = z
	return tanh((a - b) / float(p["D"]) + float(p["gamma"]) * carry + z)


static func _phase(ph: String, carry: float, w_obj: float, ta: Dictionary, tb: Dictionary, edge: float,
		mseed: int, base_a: float, base_b: float, p: Dictionary, noise: Dictionary, c: Dictionary) -> float:
	var ra := _team_ratings(ta, ph, edge, p)
	var rb := _team_ratings(tb, ph, -edge, p)
	var r_obj := _contest("obj_" + ph, ra[0], rb[0], carry, mseed, base_a, base_b, ta, tb, p, noise)
	var r_fight := _contest("fight_" + ph, ra[1], rb[1], carry, mseed, base_a, base_b, ta, tb, p, noise)
	c["obj_" + ph] = r_obj
	c["fight_" + ph] = r_fight
	return w_obj * r_obj + (1.0 - w_obj) * r_fight


static func simulate(ta: Dictionary, tb: Dictionary, mseed: int, p: Dictionary) -> Dictionary:
	var base_a: float = float(p["sigma"]) * noise_scale(float(ta["con"])) * float(ta.get("variance_mult", 1.0))
	var base_b: float = float(p["sigma"]) * noise_scale(float(tb["con"])) * float(tb.get("variance_mult", 1.0))
	var noise := {}
	var c := {}
	var carry0: float = float(p["side_bonus"])
	c["top"] = _contest("top", _eff(ta, "early", "top", "top"), _eff(tb, "early", "top", "top"), carry0, mseed, base_a, base_b, ta, tb, p, noise)
	c["mid_lane"] = _contest("mid_lane", _eff(ta, "early", "mid", "mid"), _eff(tb, "early", "mid", "mid"), carry0, mseed, base_a, base_b, ta, tb, p, noise)
	var duo_a := (_eff(ta, "early", "bot", "bot") + _eff(ta, "early", "sup", "bot")) / 2.0
	var duo_b := (_eff(tb, "early", "bot", "bot") + _eff(tb, "early", "sup", "bot")) / 2.0
	c["bot"] = _contest("bot", duo_a, duo_b, carry0, mseed, base_a, base_b, ta, tb, p, noise)
	c["jungle"] = _contest("jungle", _eff(ta, "early", "jg", "jg"), _eff(tb, "early", "jg", "jg"), carry0, mseed, base_a, base_b, ta, tb, p, noise)
	var a_early: float = float(p["w_lane"]) * (c["top"] + c["mid_lane"] + c["bot"]) + float(p["w_jungle"]) * c["jungle"]
	var edge := style_edge_for_a(String(ta["style"]), String(tb["style"]), p)
	var a_mid := _phase("mid", a_early, float(p["w_mid_obj"]), ta, tb, edge, mseed, base_a, base_b, p, noise, c)
	var carry2: float = float(p["carry_early"]) * a_early + (1.0 - float(p["carry_early"])) * a_mid
	var a_late := _phase("late", carry2, float(p["w_late_obj"]), ta, tb, edge, mseed, base_a, base_b, p, noise, c)
	var final: float = float(p["f_early"]) * a_early + float(p["f_mid"]) * a_mid + float(p["f_late"]) * a_late
	return {"a_won": final > 0.0, "final": final, "early": a_early, "mid": a_mid, "late": a_late,
			"contests": c, "noise": noise}
