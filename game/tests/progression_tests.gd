class_name ProgressionTests
extends RefCounted
## Training, fatigue and ageing (GDD 7.3). Fast structural tests; the "no schedule is dominant" test is
## statistical and lives in tools/train_qa.gd.

func run(check: Callable) -> void:
	# ---- formulas
	check.call(Progression.age_factor(18) == 1.3 and Progression.age_factor(22) == 1.1 and Progression.age_factor(25) == 0.8
			and Progression.age_factor(28) == 0.5 and Progression.age_factor(33) == 0.25, "age factors match GDD 7.3")
	# Coach 2, Facility 2: bracket 1 + 0.2 + 0.1 = 1.3. 20-year-old, 50/70, no fatigue, balanced
	var g := Progression.stat_gain_week(50.0, 70.0, 20, 0.0, "balanced")
	check.call(absf(g - float(Progression.data()["base"]) * 1.3 * (1.0 - 50.0 / 70.0) * 1.3) < 1e-9, "weekly stat gain follows the GDD formula (%.4f)" % g)
	check.call(Progression.stat_gain_week(70.0, 70.0, 20, 0.0, "balanced") == 0.0, "no growth at Potential")
	check.call(Progression.stat_gain_week(80.0, 70.0, 20, 0.0, "balanced") == 0.0, "no growth above Potential")
	check.call(Progression.stat_gain_week(50.0, 70.0, 20, 60.0, "balanced") < g, "fatigue slows growth")
	check.call(absf(Progression.stat_gain_week(50.0, 70.0, 20, 0.0, "casual") / g - 0.9) < 1e-9, "casual players train at 0.90")
	check.call(absf(Progression.stat_gain_week(50.0, 70.0, 20, 0.0, "professional") / g - 1.05) < 1e-9, "professionals train at 1.05")
	check.call(Progression.fatigue_penalty(25.0) == 0.0 and absf(Progression.fatigue_penalty(65.0) - 6.0) < 1e-9, "fatigue penalty is 0.15 per point above 25")
	# one match day: a starter nets +2.5 (half of the GDD's +5 per week at Facility 2), a benched trainee recovers, resting recovers faster
	check.call(absf(Progression.fatigue_delta(true, true) - 2.5) < 1e-9, "starter who trains nets +2.5 a match day")
	check.call(Progression.fatigue_delta(false, true) < 0.0 and Progression.fatigue_delta(false, false) < Progression.fatigue_delta(false, true), "bench recovers; resting recovers faster")

	# ---- fatigue lowers match rating, and only through the overlay
	var w := World.load_default()
	var club: String = w.club_ids[3]
	var lu := w.best_lineup(club)
	var opp := w.best_lineup(w.club_ids[4])
	var meta := w.make_meta("prog-test")
	var d0 := MatchRunner.prepare(w, lu, opp, meta, 5, "prog:0", false)
	d0.finish_with_ai()
	var t_fresh: Array = MatchRunner.build_teams(w, d0)
	for s in World.SLOTS:
		w.fatigue[lu[s]["id"]] = 65.0
	var t_tired: Array = MatchRunner.build_teams(w, d0)
	check.call(t_tired[0]["ratings"]["mid"]["top"] < t_fresh[0]["ratings"]["mid"]["top"] - 3.0, "a fatigue-65 starter rates clearly lower")
	check.call(t_tired[1]["ratings"]["mid"]["top"] == t_fresh[1]["ratings"]["mid"]["top"], "the rival is unaffected")
	w.fatigue.clear()

	# ---- rotation: identical to best_lineup when fresh, swaps in a rested sub when a starter is exhausted
	var all_same := true
	for c in w.club_ids:
		var a := w.best_lineup(c)
		var b := w.rotated_lineup(c)
		for s in World.SLOTS:
			all_same = all_same and a[s]["id"] == b[s]["id"]
	check.call(all_same, "with no fatigue the rotated lineup is the best lineup")
	var rot_club := ""
	var swapped := false
	for c in w.club_ids:
		var base := w.best_lineup(c)
		for s in World.SLOTS:
			w.fatigue[base[s]["id"]] = 100.0
		var r := w.rotated_lineup(c)
		var changed := 0
		for s in World.SLOTS:
			if r[s]["id"] != base[s]["id"]:
				changed += 1
		swapped = swapped or changed > 0
		var again := w.rotated_lineup(c)
		var same := true
		for s in World.SLOTS:
			same = same and again[s]["id"] == r[s]["id"]
		check.call(same, "rotation is deterministic (%s)" % c)
		w.fatigue.clear()
	check.call(swapped, "exhausted starters get replaced by rested players somewhere")

	# ---- a game state: ticking, saving, isolation
	var gs := GameState.new_game(w, club, 777)
	var base_mec := {}
	for p in w.club_players(club):
		base_mec[p["id"]] = p["stats"].duplicate()
	var guard := 0
	while int(gs.d["round"]) < 6 and guard < 80:
		guard += 1
		var gm := gs.next_game()
		gs.record_human_game(gm, gs.auto_game(gm))
	check.call(int(gs.d["round"]) == 6, "six rounds were played")
	var starters: Array = (gs.d["lineup"] as Dictionary).values()
	var fat_ok := true
	for pid in starters:
		fat_ok = fat_ok and absf(w.fatigue_of(pid) - 6.0 * 2.5) < 1e-6
	check.call(fat_ok, "starters carry +2.5 fatigue per match day (%.2f)" % w.fatigue_of(starters[0]))
	var bench_fresh := true
	for p in w.club_players(club):
		if not starters.has(p["id"]):
			bench_fresh = bench_fresh and w.fatigue_of(p["id"]) == 0.0
	check.call(bench_fresh, "benched players stay fresh")
	var grew := 0
	var within_pot := true
	for p in w.club_players(club):
		for st in World.STATS:
			if float(p["stats"][st]) > float(base_mec[p["id"]][st]) + 1e-9:
				grew += 1
			within_pot = within_pot and float(p["stats"][st]) <= float(p["potential"][st]) + 1e-9
	check.call(grew >= 8, "players improved by training (%d stats grew)" % grew)
	check.call(within_pot, "no stat passes its Potential")
	var rival: String = w.club_ids[0] if w.club_ids[0] != club else w.club_ids[1]
	var ai_grew := false
	for pid in (w.clubs[rival]["player_ids"] as Array):
		ai_grew = ai_grew or (gs.d["stat_gain"] as Dictionary).has(pid)
	check.call(ai_grew, "AI clubs train too")
	# manager's choice beats nothing: a player set to rest gains nothing
	var rest_p: Dictionary = w.club_players(club)[0]
	gs.set_focus(rest_p["id"], "rest")
	var before := float(rest_p["stats"]["mec"]) + float(rest_p["stats"]["lan"])
	var sum_before := 0.0
	for st in World.STATS:
		sum_before += float(rest_p["stats"][st])
	var gm2 := gs.next_game()
	gs.record_human_game(gm2, gs.auto_game(gm2))
	var sum_after := 0.0
	for st in World.STATS:
		sum_after += float(rest_p["stats"][st])
	check.call(absf(sum_after - sum_before) < 1e-9, "a player told to rest does not train")
	gs.set_focus(rest_p["id"], "hero", "nonexistent_hero")
	gs.coach_picks_all()
	check.call(not (gs.d["train"] as Dictionary).has(rest_p["id"]), "coach picks clears manual focus")
	# save round trip into a brand new World
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(gs.d))
	var w2 := World.load_default()
	var gs2 := GameState.from_dict(w2, snapshot)
	var same_stats := true
	for p in w.club_players(club):
		for st in World.STATS:
			same_stats = same_stats and absf(float(w2.players[p["id"]]["stats"][st]) - float(p["stats"][st])) < 1e-9
	check.call(same_stats, "growth survives save and load into a fresh World")
	check.call(absf(w2.fatigue_of(starters[0]) - w.fatigue_of(starters[0])) < 1e-9, "fatigue survives save and load")
	check.call(gs2.club() == club, "loaded state is the same club")
	# a new game must not inherit the old save's growth
	var gs3 := GameState.new_game(w, club, 31)
	var clean := true
	var orig := World.load_default()
	for p in w.club_players(club):
		for st in World.STATS:
			clean = clean and float(p["stats"][st]) == float(orig.players[p["id"]]["stats"][st])
	check.call(clean and w.fatigue.is_empty(), "new game starts from the data files' stats and zero fatigue")
	check.call(gs3.d["round"] == 0, "new game starts at round 0")

	# ---- a whole season, then the off-season
	var w4 := World.load_default()
	var gs4 := GameState.new_game(w4, club, 4)
	gs4.autoplay(true)
	check.call(gs4.d["phase"] == "done", "season finishes with training running")
	var vet: Dictionary = {}
	for pid in w4.players:
		var pl: Dictionary = w4.players[pid]
		if w4.age_of(pl) >= 31:
			vet = pl
			break
	var mec_before := float(vet["stats"]["mec"]) if not vet.is_empty() else 0.0
	var age_before := w4.age_of(vet) if not vet.is_empty() else 0
	var gs5 := gs4.next_season()
	check.call(int(gs5.d["season"]) == 2 and w4.season_offset == 1, "next season: everyone is a year older")
	check.call(gs5.d["fatigue"].is_empty() and w4.fatigue.is_empty(), "off-season resets fatigue")
	if not vet.is_empty():
		check.call(w4.age_of(vet) == age_before + 1 and float(vet["stats"]["mec"]) < mec_before + 1e-9, "veterans decline in the off-season")
	var start_gain := 0.0
	for pid in (w4.clubs[club]["player_ids"] as Array):
		for st in World.STATS:
			start_gain += absf(gs5.season_gain(pid, st))
	check.call(start_gain < 1e-9, "season gains start at zero in the new season")
	# older saves without growth keys still load
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(gs5.d))
	for k in ["stat_gain", "fatigue", "train", "season_base", "train_last"]:
		legacy.erase(k)
	var gs6 := GameState.from_dict(World.load_default(), legacy)
	check.call(gs6.d.has("stat_gain") and gs6.d["train"] is Dictionary, "a save from before Alpha 0.2 still loads")
