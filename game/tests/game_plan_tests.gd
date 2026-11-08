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
	_attribution_uses_played_plans(check, w, meta, p)
	_final_weights_match(check)


## S1 (wave 1 review): the result must carry the plan sets that were actually played, so the report's
## counterfactuals replay the same game. Before the fix `finish` returned no "plans" key and the "why" bars
## re-simulated both sides with neutral plans.
func _attribution_uses_played_plans(check: Callable, w: World, meta: Dictionary, p: Dictionary) -> void:
	var plan := GamePlan.neutral()
	plan["l"] = 100
	plan["g"] = -100
	plan["t"] = 100
	plan["jf"] = "bot"
	var my_set := {"default": plan, "triggers": []}
	var games := 0
	var with_plan_factor := 0
	var plan_nonzero := 0
	var replays := true
	var consistent := true
	var shares_ok := true
	var keyed := true
	for i in 8:
		var res := MatchRunner.auto(w, w.best_lineup(w.club_ids[i % 10]), w.best_lineup(w.club_ids[(i + 3) % 10]), meta, 321, "gp:attr-%d" % i, false, {"B": my_set, "R": "ai"})
		games += 1
		keyed = keyed and res.has("plans") and (res["plans"] as Dictionary).has("B") and (res["plans"] as Dictionary).has("R")
		# the sets that were played, rebuilt here without trusting the result
		var ta: Dictionary = res["team_a"]
		var tb: Dictionary = res["team_b"]
		var sets := {"B": my_set, "R": GamePlan.suggest_set(ta, tb, p, "R")}
		var ms := int(res["mseed"])
		var played := float(res["final"])
		replays = replays and GamePlan.simulate(ta, tb, ms, p, sets)["final"] == played
		replays = replays and res.get("plans", {}) == sets
		for side in ["B", "R"]:
			var sgn := 1.0 if side == "B" else -1.0
			var att := Report.attribution(res, side)
			var by_id := {}
			var abs_sum := 0.0
			var share_sum := 0.0
			for f in att["factors"]:
				by_id[f["id"]] = f
				abs_sum += absf(float(f["value"]))
				share_sum += absf(float(f["share"]))
			if abs_sum > 0.0:
				shares_ok = shares_ok and absf(share_sum - 1.0) < 1e-9
			# every counterfactual factor is "played final minus the replay without that change", with the played plans
			for s in Report.SLOTS:
				var cf := ta.duplicate(true)
				for ph in Report.PHASES:
					cf["ratings"][ph][s] = tb["ratings"][ph][s]
				var f_slot := float(GamePlan.simulate(cf, tb, ms, p, sets)["final"])
				consistent = consistent and absf(float(by_id["slot." + s]["value"]) - (played - f_slot) * sgn) < 1e-12
			var f_draft := float(GamePlan.simulate(Report._neutral(ta), Report._neutral(tb), ms, p, sets)["final"])
			consistent = consistent and absf(float(by_id["draft"]["value"]) - (played - f_draft) * sgn) < 1e-12
			if side == "B":
				if by_id.has("plan"):
					with_plan_factor += 1
					var f_plain := float(GamePlan.simulate(ta, tb, ms, p, {"R": sets["R"]})["final"])
					consistent = consistent and absf(float(by_id["plan"]["value"]) - (played - f_plain) * sgn) < 1e-12
					if absf(float(by_id["plan"]["value"])) > 1e-9:
						plan_nonzero += 1
			else:
				# the opponent plays the coach's plan set; its own bar appears only if that set is not neutral
				var r_set: Dictionary = sets["R"]
				var r_active: bool = not (r_set["triggers"].is_empty() and GamePlan.is_neutral(r_set["default"]))
				consistent = consistent and by_id.has("plan") == r_active
	check.call(keyed, "result carries the played plan sets for both sides (S1)")
	check.call(replays, "the played sets replay the played final, and the result carries exactly those sets (S1)")
	check.call(with_plan_factor == games, "attribution shows the plan factor when the player used a plan (%d of %d)" % [with_plan_factor, games])
	check.call(plan_nonzero >= games - 1, "the plan factor is not zero for a strong plan (%d of %d)" % [plan_nonzero, games])
	check.call(consistent, "attribution factors are (played final - counterfactual replay with the played plans)")
	check.call(shares_ok, "attribution shares sum to 1 in absolute value")
	# no plans given: the key is present and empty, and the result equals the plain simulator (golden path)
	var plain := MatchRunner.auto(w, w.best_lineup(w.club_ids[0]), w.best_lineup(w.club_ids[1]), meta, 321, "gp:attr-plain", false, {})
	check.call(plain.has("plans") and (plain["plans"] as Dictionary).is_empty(), "no plans given: result plans is empty")
	check.call(plain["final"] == MatchSim.simulate(plain["team_a"], plain["team_b"], plain["mseed"], p)["final"], "no plans given: result equals the plain simulator")
	# a neutral plan set shows no plan bar
	var neutral_res := MatchRunner.auto(w, w.best_lineup(w.club_ids[0]), w.best_lineup(w.club_ids[1]), meta, 321, "gp:attr-plain", false, {"B": GamePlan.neutral_set()})
	var no_plan := true
	for f in Report.attribution(neutral_res, "B")["factors"]:
		no_plan = no_plan and f["id"] != "plan"
	check.call(no_plan and neutral_res["final"] == plain["final"], "a neutral plan shows no plan bar and changes nothing")
	# the result owns its copy: editing the live plan afterwards cannot rewrite a finished game
	var live := {"default": GamePlan.neutral(), "triggers": []}
	live["default"]["l"] = 100
	var owned := MatchRunner.auto(w, w.best_lineup(w.club_ids[0]), w.best_lineup(w.club_ids[1]), meta, 321, "gp:attr-own", false, {"B": live})
	live["default"]["l"] = -100
	check.call(int(owned.get("plans", {}).get("B", {}).get("default", {}).get("l", 0)) == 100, "result keeps its own copy of the plan sets")


## S5: the final-weights table the Game Plan checks use equals the file, and equals f_phase * contest weight
## from sim_params.json, so the plan zero-sum test and the story ledger stay tied to the simulator.
func _final_weights_match(check: Callable) -> void:
	var raw = DataLoader.load_json("res://data/game_plan_v0.json")
	check.call(raw is Dictionary, "game_plan_v0.json loads")
	if not (raw is Dictionary):
		return
	var file_w: Dictionary = raw["final_weights"]
	var used: Dictionary = GamePlan.data()["final_weights"]
	check.call(used.size() == GamePlan.CONTESTS.size() and file_w.size() == GamePlan.CONTESTS.size(), "final_weights has all 8 contests")
	var p := MatchSim.load_params()
	var derived := {
		"top": float(p["f_early"]) * float(p["w_lane"]), "mid_lane": float(p["f_early"]) * float(p["w_lane"]),
		"bot": float(p["f_early"]) * float(p["w_lane"]), "jungle": float(p["f_early"]) * float(p["w_jungle"]),
		"obj_mid": float(p["f_mid"]) * float(p["w_mid_obj"]), "fight_mid": float(p["f_mid"]) * (1.0 - float(p["w_mid_obj"])),
		"obj_late": float(p["f_late"]) * float(p["w_late_obj"]), "fight_late": float(p["f_late"]) * (1.0 - float(p["w_late_obj"]))}
	var total := 0.0
	for c in GamePlan.CONTESTS:
		check.call(file_w.has(c) and used.has(c) and float(used[c]) == float(file_w[c]), "final_weights used by GamePlan equals the file: " + c)
		check.call(absf(float(file_w[c]) - float(derived[c])) < 1e-9, "final_weights %s equals f_phase * contest weight in sim_params.json (%.4f)" % [c, float(derived[c])])
		total += float(file_w[c])
	check.call(absf(total - 1.0) < 1e-9, "final_weights sum to 1 (%.6f)" % total)
