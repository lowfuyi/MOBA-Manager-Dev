class_name UiPassTests
extends RefCounted
## Alpha 0.5 UI pass, logic part: the payoff bookkeeping (what a game changed), the tip rules, the pace log
## and the small formatting helpers the new screens rely on.

func run(check: Callable) -> void:
	var w := World.load_default()
	var club: String = w.club_ids[3]
	var gs := GameState.new_game(w, club, 5151)
	gs._bind()
	# ---- payoff: snapshot before, compare after a played game
	var snap := Payoff.snapshot(gs)
	var ids: Array = (gs.d["lineup"] as Dictionary).values()
	check.call(snap["lineup"].size() == 5 and snap["form"].size() == (gs.d["roster"] as Array).size(), "payoff snapshot covers the roster and the five starters")
	gs._after_game(club, ids, true, false, true)
	var po := Payoff.compare(gs, snap)
	check.call(po["rows"].size() == 5, "payoff has one row per starter")
	var all_up := true
	for r in po["rows"]:
		all_up = all_up and float(r["form_a"]) > float(r["form_b"]) and float(r["mor_a"]) > float(r["mor_b"])
	check.call(all_up, "after a win every starter gains Form and Morale")
	check.call(float(po["bond_a"]) > float(po["bond_b"]) and absf(float(po["bond_a"]) - float(po["bond_b"]) - 4.0) < 0.6, "the five starters' bonds average rises by about 4 (%.2f)" % (float(po["bond_a"]) - float(po["bond_b"])))
	check.call(float(po["chem_a"]) >= float(po["chem_b"]), "chemistry bonus does not fall after a game together")
	check.call(absf(float(po["cash_d"])) < 1e-9, "no cash moves inside _after_game alone")
	# a loss moves the numbers the other way for form
	var snap2 := Payoff.snapshot(gs)
	gs._after_game(club, ids, false, false, true)
	var po2 := Payoff.compare(gs, snap2)
	check.call(float(po2["rows"][0]["form_a"]) < float(po2["rows"][0]["form_b"]), "after a loss Form falls")
	# ---- tip rules, in priority order
	for pid in ids:
		w.fatigue[pid] = 80.0
	var t1 := Payoff.tip(gs)
	check.call(t1["key"] == "tip.rest" and int(t1["args"]["n"]) == 5, "tired starters give the rest tip first")
	w.fatigue.clear()
	for pid in ids:
		gs.d["morale"][pid] = 60.0
	gs.d["morale"][ids[0]] = 20.0
	var t2 := Payoff.tip(gs)
	check.call(t2["key"] == "tip.morale" and t2["args"]["name"] == w.players[ids[0]]["name"], "an unhappy starter gives the morale tip")
	gs.d["morale"][ids[0]] = 60.0
	var t3 := Payoff.tip(gs)
	check.call(["tip.contract", "tip.scrim", "tip.keep"].has(t3["key"]), "otherwise a contract, scrim or keep-going tip (%s)" % t3["key"])
	# ---- pace log
	var p0 := gs.pace()
	check.call(int(p0["n"]) == 0 and int(p0["quick"]) == 0, "pace log starts empty")
	gs.pace_add(200.0, 75.0, false, false)
	gs.pace_add(100.0, 30.0, true, true)
	gs.pace_quick()
	var p1 := gs.pace()
	check.call(int(p1["n"]) == 2 and absf(float(p1["total_s"]) - 300.0) < 1e-9 and absf(float(p1["watch_s"]) - 105.0) < 1e-9, "pace log adds totals")
	check.call(int(p1["skips"]) == 1 and int(p1["fast"]) == 1 and int(p1["quick"]) == 1 and absf(float(p1["max_total_s"]) - 200.0) < 1e-9, "pace log counts skips, speed-ups, auto-plays and the longest game")
	var back := GameState.from_dict(w, JSON.parse_string(JSON.stringify(gs.d)))
	check.call(int(back.pace()["n"]) == 2, "pace log survives save and load")
	# ---- the cosmetic game clock stays inside its 9-16 game-minute band (the watch window maps it to a fixed real time)
	var lo := 1e9
	var hi := 0.0
	for i in 200:
		var fake := {"sim": {"mid": 0.2 + 0.005 * i, "late": 0.9 - 0.004 * i}, "mseed": 1000 + i}
		var minutes := Report.game_minutes(fake)
		lo = minf(lo, minutes)
		hi = maxf(hi, minutes)
	check.call(lo >= 9.0 - 1e-9 and hi <= 16.0 + 1e-9, "game clock stays within 9-16 game minutes (%.1f-%.1f)" % [lo, hi])
