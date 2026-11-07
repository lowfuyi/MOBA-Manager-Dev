class_name GamePlanTests
extends RefCounted
## Game Plan checks (GDD 7.8, QA 9.2 items 1 and 9). The statistical "no dominant plan" test is slow
## and lives in tools/gp_qa.gd; this file holds the fast structural tests.

func run(check: Callable) -> void:
	var p := MatchRunner.sim_params()
	# 9.2.9: every control is zero-sum in rating (final-weighted contest_mod sums to 0)
	for id in GamePlan.SLIDERS:
		for sign in [-1, 1]:
			var plan := GamePlan.neutral()
			plan[id] = 100 * sign
			check.call(absf(GamePlan.weighted_mod_sum(plan)) < 0.0005, "control %s %+d is zero-sum (%.5f)" % [id, 100 * sign, GamePlan.weighted_mod_sum(plan)])
	for jf in ["top", "mid_lane", "bot"]:
		var plan2 := GamePlan.neutral()
		plan2["jf"] = jf
		check.call(absf(GamePlan.weighted_mod_sum(plan2)) < 0.0005, "jungle focus %s is zero-sum" % jf)
	var everything := GamePlan.neutral()
	for id in ["g", "t", "m", "l", "s"]:
		everything[id] = 100
	everything["jf"] = "bot"
	check.call(absf(GamePlan.weighted_mod_sum(everything)) < 0.0025, "combined plan stays near zero-sum")
	# hooks
	var h := GamePlan.hooks(GamePlan.neutral())
	var all_one := true
	for c in GamePlan.CONTESTS:
		all_one = all_one and h["contest_mod"][c] == 0.0 and h["contest_var"][c] == 1.0
	check.call(all_one, "neutral plan has no effect on any contest")
	var pa := GamePlan.neutral()
	pa["a"] = 100
	pa["r"] = -100
	var hv := GamePlan.hooks(pa)
	check.call(absf(hv["contest_var"]["top"] - 1.25 * 0.8) < 1e-9 and absf(hv["contest_var"]["fight_late"] - 0.8) < 1e-9, "variance controls multiply")
	check.call(hv["contest_mod"]["top"] == 0.0, "variance controls do not change ratings")
	# a draft + teams to test against
	var w := World.load_default()
	var meta := w.make_meta("gp-test")
	var d := MatchRunner.prepare(w, w.best_lineup(w.club_ids[0]), w.best_lineup(w.club_ids[1]), meta, 99, "gp:test", false)
	d.finish_with_ai()
	var teams := MatchRunner.build_teams(w, d)
	var ta: Dictionary = teams[0]
	var tb: Dictionary = teams[1]
	# neutral plans reproduce the plain simulator exactly
	var plain := MatchSim.simulate(ta, tb, d.mseed, p)
	var nsim := GamePlan.simulate(ta, tb, d.mseed, p, {"B": GamePlan.neutral_set(), "R": GamePlan.neutral_set()})
	check.call(plain["final"] == nsim["final"] and plain["contests"] == nsim["contests"], "neutral plans equal the plain simulator")
	check.call(GamePlan.simulate(ta, tb, d.mseed, p)["final"] == plain["final"], "no plans equal the plain simulator")
	# early contests never depend on the chosen (mid/late) plan, and the trigger fires on the early result
	var trig_plan := GamePlan.neutral()
	trig_plan["l"] = 100
	trig_plan["r"] = 100
	var fired := 0
	var early_same := true
	var changed := 0
	for i in 300:
		var seed_i := 1000 + i
		var base := GamePlan.simulate(ta, tb, seed_i, p, {})
		var both := {"B": {"default": GamePlan.neutral(), "triggers": [{"when": "behind_early", "plan": trig_plan}, {"when": "ahead_early", "plan": trig_plan}]}}
		var r := GamePlan.simulate(ta, tb, seed_i, p, both)
		for c in GamePlan.EARLY:
			early_same = early_same and base["contests"][c] == r["contests"][c]
		var e: float = base["early"]
		var should: bool = absf(e) > 0.40
		var did: bool = r["plan_used"]["B"] != "default"
		if should != did:
			early_same = false
		if did:
			fired += 1
			if r["final"] != base["final"]:
				changed += 1
	check.call(early_same, "early contests identical with a triggered plan; trigger fires exactly when |A_early| > 0.40")
	check.call(fired > 10 and fired < 200, "trigger fires in a sensible share of matches (%d of 300)" % fired)
	check.call(changed > fired / 2, "a fired plan changes the late game")
	# trigger by opponent style
	var style_set := {"default": GamePlan.neutral(), "triggers": [{"when": "vs_" + String(tb["style"]), "plan": trig_plan}]}
	check.call(GamePlan.simulate(ta, tb, 5, p, {"B": style_set})["plan_used"]["B"] == "vs_" + String(tb["style"]), "style trigger matches the opponent's composition")
	# the coach never makes things worse on the noise-free result, and is deterministic
	for side in ["B", "R"]:
		var sug := GamePlan.suggest(ta, tb, p, side)
		var sug2 := GamePlan.suggest(ta, tb, p, side)
		check.call(sug == sug2, "coach suggestion is deterministic (%s)" % side)
		var sgn := 1.0 if side == "B" else -1.0
		var neutral_v := sgn * GamePlan.expected_final(ta, tb, p, {})
		var plan_v := sgn * GamePlan.expected_final(ta, tb, p, {side: {"default": sug, "triggers": []}})
		check.call(plan_v >= neutral_v - 1e-9, "coach suggestion is not worse than neutral (%s): %.4f vs %.4f" % [side, plan_v, neutral_v])
	# runner: "ai" plans work and are deterministic
	var r1 := MatchRunner.auto(w, w.best_lineup(w.club_ids[2]), w.best_lineup(w.club_ids[3]), meta, 7, "gp:auto", false, {"B": "ai", "R": "ai"})
	var r2 := MatchRunner.auto(w, w.best_lineup(w.club_ids[2]), w.best_lineup(w.club_ids[3]), meta, 7, "gp:auto", false, {"B": "ai", "R": "ai"})
	check.call(r1["final"] == r2["final"], "auto games with AI plans are deterministic")
	# normalisation of saved plans
	var junk := GamePlan.normalized({"g": 500, "jf": "nonsense", "a": "x"})
	check.call(junk["g"] == 100 and junk["jf"] == "none" and junk["a"] == 0, "saved plans are clamped and sanitised")
