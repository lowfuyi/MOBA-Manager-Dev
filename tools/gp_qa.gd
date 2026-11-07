extends SceneTree
## QA 9.2 item 1: no dominant Game Plan. Run from game/:
##   godot --headless --script res://../tools/gp_qa.gd  (or copy next to tests/)  [args after --: n_train n_test]
## For each of several drafted matchups: sweep every control with the others neutral on paired seeds,
## pick its best setting on the TRAIN seeds and measure it on separate HELD-OUT seeds (removes the
## best-of-N selection bias); then coordinate ascent over all controls (joint test). Prints gains in
## win-rate points for the plan side against a neutral opponent.

var n_train := 600
var n_test := 1500


func win_rate(ta: Dictionary, tb: Dictionary, p: Dictionary, sets: Dictionary, seed0: int, n: int) -> float:
	var wins := 0
	for i in n:
		if GamePlan.simulate(ta, tb, seed0 + i, p, sets)["final"] > 0.0:
			wins += 1
	return float(wins) / n


func with_plan(plan: Dictionary) -> Dictionary:
	return {"B": {"default": plan, "triggers": []}}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		n_train = int(args[0])
		n_test = int(args[1])
	var w := World.load_default()
	var p := MatchRunner.sim_params()
	var pairs := [[0, 1], [2, 3], [4, 5], [6, 7], [8, 9], [1, 8]]
	var settings := {}
	for id in GamePlan.SLIDERS:
		settings[id] = [-100, -50, 50, 100]
	var per_control_gain := {}
	var joint_gains: Array = []
	var joint_plans: Array = []
	var coach_gains: Array = []
	for pi in pairs.size():
		var pr: Array = pairs[pi]
		var meta := w.make_meta("gpqa-%d" % pi)
		var d := MatchRunner.prepare(w, w.best_lineup(w.club_ids[pr[0]]), w.best_lineup(w.club_ids[pr[1]]), meta, 4242, "gpqa:%d" % pi, false)
		d.finish_with_ai()
		var teams := MatchRunner.build_teams(w, d)
		var ta: Dictionary = teams[0]
		var tb: Dictionary = teams[1]
		var base_train := win_rate(ta, tb, p, {}, 100000, n_train)
		var base_test := win_rate(ta, tb, p, {}, 500000, n_test)
		# (a) one control at a time
		for id in GamePlan.SLIDERS + ["jf"]:
			var cands: Array = []
			if id == "jf":
				for jf in ["top", "mid_lane", "bot"]:
					var pl := GamePlan.neutral()
					pl["jf"] = jf
					cands.append(pl)
			else:
				for v in settings[id]:
					var pl2 := GamePlan.neutral()
					pl2[id] = v
					cands.append(pl2)
			var best_plan: Dictionary = GamePlan.neutral()
			var best := base_train
			for pl3 in cands:
				var wr := win_rate(ta, tb, p, with_plan(pl3), 100000, n_train)
				if wr > best:
					best = wr
					best_plan = pl3
			var held := win_rate(ta, tb, p, with_plan(best_plan), 500000, n_test)
			per_control_gain[id] = per_control_gain.get(id, []) + [(held - base_test) * 100.0]
		# (b) joint: coordinate ascent from neutral on the train seeds
		var plan := GamePlan.neutral()
		var best_j := base_train
		for _pass in 3:
			for id in GamePlan.SLIDERS:
				for v in GamePlan.STEPS:
					var cand := plan.duplicate()
					cand[id] = v
					var wr2 := win_rate(ta, tb, p, with_plan(cand), 100000, n_train)
					if wr2 > best_j:
						best_j = wr2
						plan = cand
			for jf in GamePlan.JUNGLE_CHOICES:
				var cand2 := plan.duplicate()
				cand2["jf"] = jf
				var wr3 := win_rate(ta, tb, p, with_plan(cand2), 100000, n_train)
				if wr3 > best_j:
					best_j = wr3
					plan = cand2
		var held_j := win_rate(ta, tb, p, with_plan(plan), 500000, n_test)
		joint_gains.append((held_j - base_test) * 100.0)
		joint_plans.append(plan)
		var coach := GamePlan.suggest(ta, tb, p, "B")
		coach_gains.append((win_rate(ta, tb, p, with_plan(coach), 500000, n_test) - base_test) * 100.0)
		print("pair %d (%s vs %s): neutral %.1f%%, joint gain %+.2f, coach gain %+.2f" % [pi, w.club_ids[pr[0]], w.club_ids[pr[1]], base_test * 100.0, joint_gains[pi], coach_gains[pi]])
		print("   joint plan: ", plan)
	print("\n--- per-control gain on held-out seeds (win-rate points, mean over %d matchups; SE about %.2f per matchup) ---" % [pairs.size(), 100.0 * 0.5 / sqrt(n_test) * 1.0])
	for id in per_control_gain:
		var arr: Array = per_control_gain[id]
		var m := 0.0
		var mx := -99.0
		for g in arr:
			m += g / arr.size()
			mx = maxf(mx, g)
		print("%s: mean %+.2f  max %+.2f" % [id, m, mx])
	var mj := 0.0
	for g in joint_gains:
		mj += g / joint_gains.size()
	var mc := 0.0
	for g in coach_gains:
		mc += g / coach_gains.size()
	print("joint plan: mean %+.2f  max %+.2f  (limit 3.0)" % [mj, joint_gains.max()])
	print("coach suggestion: mean %+.2f" % mc)
	var differ := 0
	var total := 0
	for i in joint_plans.size():
		for j in range(i + 1, joint_plans.size()):
			total += 1
			var pi_: Dictionary = joint_plans[i]
			var pj: Dictionary = joint_plans[j]
			var diff: bool = pi_["jf"] != pj["jf"]
			for id in GamePlan.SLIDERS:
				if absi(int(pi_[id]) - int(pj[id])) >= 100:
					diff = true
			if diff:
				differ += 1
	print("joint plans differing between matchups: %d of %d" % [differ, total])
	quit()
