class_name Alpha6Tests
extends RefCounted
## Alpha 0.6 logic: Form Rating (GDD 10.1), derived KDA and the career record (9.2 test 6, 4.2), Exhibition and
## Quick Match (7.9). Headless: no autoloads, so nothing here touches UI classes.


func _spearman(xs: Array, ys: Array) -> float:
	var rx := _ranks(xs)
	var ry := _ranks(ys)
	var n := float(xs.size())
	var d2 := 0.0
	for i in xs.size():
		d2 += (rx[i] - ry[i]) * (rx[i] - ry[i])
	return 1.0 - 6.0 * d2 / (n * (n * n - 1.0))


func _ranks(v: Array) -> Array:
	var idx: Array = range(v.size())
	idx.sort_custom(func(a, b): return v[a] < v[b])
	var r: Array = []
	r.resize(v.size())
	for k in idx.size():
		r[idx[k]] = float(k)
	return r


func _game(gs: GameState, a: String, b: String, id: String, kind: String = "league") -> Dictionary:
	return {"kind": kind, "id": id, "blue": a, "red": b, "full": false, "round": 0, "series": "", "game": 1}


func run(check: Callable) -> void:
	var w := World.load_default()
	_form_rating(check, w)
	_kda(check, w)
	_career_and_practice(check, w)


# ------------------------------------------------------------------ Form Rating
func _form_rating(check: Callable, w: World) -> void:
	check.call(absf(FormRating.expected(1500.0, 1500.0) - 0.5) < 1e-12, "equal ratings expect 50 percent")
	check.call(absf(FormRating.expected(1900.0, 1500.0) - 0.9091) < 0.001, "400 points up expects 90.9 percent")
	check.call(absf(FormRating.series_expected(0.5, 3) - 0.5) < 1e-12 and absf(FormRating.series_expected(0.5, 5) - 0.5) < 1e-12, "an even game is an even series")
	check.call(absf(FormRating.series_expected(0.7, 3) - 0.784) < 1e-9 and absf(FormRating.series_expected(0.7, 5) - 0.83692) < 1e-5, "series win probability for p = 0.7")
	check.call(FormRating.importance("league", 1) == 1.0 and absf(FormRating.importance("semi", 3) - 1.5) < 1e-12 and absf(FormRating.importance("final", 5) - 2.1) < 1e-12, "importance: league 1.0, semi bo3 1.5, final bo5 2.1")
	check.call(FormRating.importance("exhibition", 3) == 0.0 and FormRating.importance("quick", 1) == 0.0, "practice games have importance 0")
	var up := FormRating.delta(1500.0, 1500.0, true, "league", 1)
	check.call(absf(up - 12.0) < 1e-9, "an even league win moves 12 points (K 24 times 0.5)")
	check.call(FormRating.delta(1700.0, 1500.0, true, "league", 1) < up and FormRating.delta(1700.0, 1500.0, false, "league", 1) < -12.0, "favourites gain less and lose more")
	var init := FormRating.initial({"a": 50.0, "b": 60.0, "c": 40.0})
	check.call(absf(float(init["a"]) - 1500.0) < 1e-9 and absf(float(init["b"]) - 1630.0) < 1e-9, "start: 1500 plus 13 per rating point above the mean")
	# a whole split and playoffs: zero-sum, every club moved, rating follows strength
	var rhos: Array = []
	var moved_n := 0
	var zero_sum := true
	for sd in 3:
		var gs := GameState.new_game(w, w.club_ids[sd * 3], 8800 + sd)
		gs._bind()
		var start: Dictionary = gs.d["frating"].duplicate()
		var tr: Array = []
		var tot0 := 0.0
		for c in w.club_ids:
			tr.append(w.team_rating(gs.lineup_for(c)))
			tot0 += float(start[c])
		gs.autoplay(true)
		var fin: Array = []
		var tot1 := 0.0
		for c in w.club_ids:
			fin.append(float(gs.d["frating"][c]))
			tot1 += float(gs.d["frating"][c])
			if absf(float(gs.d["frating"][c]) - float(start[c])) > 5.0:
				moved_n += 1
		zero_sum = zero_sum and absf(tot1 - tot0) < 1e-6
		rhos.append(_spearman(tr, fin))
	check.call(zero_sum, "ratings are zero-sum over a whole season")
	check.call(moved_n >= 24, "ratings really move over a season (%d of 30 clubs by more than 5 points)" % moved_n)
	var rho: float = (float(rhos[0]) + float(rhos[1]) + float(rhos[2])) / 3.0
	check.call(rho > 0.6, "end-of-season Form Rating follows team strength (Spearman %.2f)" % rho)
	# saves from before Alpha 0.6
	var old := GameState.new_game(w, w.club_ids[0], 4141)
	old.d.erase("frating")
	var back := GameState.from_dict(w, JSON.parse_string(JSON.stringify(old.d)))
	check.call(back.d.has("frating") and (back.d["frating"] as Dictionary).size() == 10, "an old save gets Form Ratings on load")
	# a save from before Alpha 0.6 has none of the practice or career keys either
	var older := GameState.new_game(w, w.club_ids[2], 4242)
	for k in ["frating", "career", "exh", "exh_n", "exh_day", "exh_last", "exh_busy"]:
		older.d.erase(k)
	(older.d["seasons_done"] as Array).append({"season": 0, "rank": 3, "w": 10, "l": 8, "result": "lost", "champion": "x"})
	var loaded := GameState.from_dict(w, JSON.parse_string(JSON.stringify(older.d)))
	loaded._bind()
	check.call(loaded.practice_available() and not loaded.practice_in_progress() and loaded.career_all().is_empty(), "an old save opens with practice available and an empty career record")
	var g0 := loaded.next_game()
	loaded.record_human_game(g0, loaded.auto_game(g0))
	check.call(loaded.career_all().size() == 5, "an old save starts its career record with the next game")
	var rk := back.form_ranking()
	check.call(rk.size() == 10 and float(rk[0]["rating"]) >= float(rk[9]["rating"]) and int(rk[0]["rank"]) == 1, "form ranking is sorted best first")


# ------------------------------------------------------------------ derived KDA
func _kda(check: Callable, w: World) -> void:
	var gs := GameState.new_game(w, w.club_ids[1], 6001)
	gs._bind()
	var ok_ident := true
	var ok_win := true
	var ok_assist := true
	var ok_pos := true
	var ok_det := true
	var win_share := 0.0
	var total_k := 0.0
	var kills := {"top": 0.0, "jg": 0.0, "mid": 0.0, "bot": 0.0, "sup": 0.0}
	var n := 60
	var tmin := 99
	var tmax := 0
	for i in n:
		var a: String = w.club_ids[i % 10]
		var b: String = w.club_ids[(i * 7 + 3) % 10]
		if a == b:
			b = w.club_ids[(i + 1) % 10]
		var r := MatchRunner.auto(w, gs.lineup_for(a), gs.lineup_for(b), gs.meta_for(0), 6001, "kda-%d" % i, false, {})
		var k := Report.kda(r)
		ok_det = ok_det and JSON.stringify(k) == JSON.stringify(Report.kda(r))
		var sum := {"B": [0, 0, 0], "R": [0, 0, 0]}
		for side in ["B", "R"]:
			for s in Report.SLOTS:
				var l: Dictionary = k[side][s]
				sum[side][0] += l["k"]
				sum[side][1] += l["d"]
				sum[side][2] += l["a"]
				ok_pos = ok_pos and l["k"] >= 0 and l["d"] >= 0 and l["a"] >= 0
				ok_assist = ok_assist and int(l["a"]) + int(l["k"]) <= int(k["team"][side]["k"])
				kills[s] += float(l["k"])
		ok_ident = ok_ident and sum["B"][0] == sum["R"][1] and sum["R"][0] == sum["B"][1]
		ok_ident = ok_ident and sum["B"][0] == int(k["team"]["B"]["k"]) and sum["B"][2] == int(k["team"]["B"]["a"]) and sum["R"][2] == int(k["team"]["R"]["a"])
		var wk: int = int(k["team"]["B"]["k"]) if r["blue_won"] else int(k["team"]["R"]["k"])
		var lk: int = int(k["team"]["R"]["k"]) if r["blue_won"] else int(k["team"]["B"]["k"])
		ok_win = ok_win and wk > lk
		ok_assist = ok_assist and int(k["team"]["B"]["a"]) <= 4 * int(k["team"]["B"]["k"]) and int(k["team"]["R"]["a"]) <= 4 * int(k["team"]["R"]["k"])
		win_share += float(wk) / float(wk + lk)
		total_k += wk + lk
		tmin = mini(tmin, wk + lk)
		tmax = maxi(tmax, wk + lk)
	check.call(ok_det, "KDA lines are the same every time for the same game")
	check.call(ok_pos, "KDA numbers are never negative")
	check.call(ok_ident, "one side's kills are the other side's deaths and the player lines add up to the team totals")
	check.call(ok_win, "the winner always has more kills than the loser")
	check.call(ok_assist, "nobody assists his own kill and assists stay under four per kill")
	check.call(win_share / n > 0.55 and win_share / n < 0.85, "winners take 55 to 85 percent of kills on average (%.2f)" % (win_share / n))
	check.call(tmin >= 18 and tmax <= 44, "kills per game stay between 18 and 44 (%d-%d)" % [tmin, tmax])
	check.call(kills["bot"] > kills["sup"] * 1.5, "carries get more kills than supports (bot %.0f, sup %.0f)" % [kills["bot"], kills["sup"]])


# ------------------------------------------------------------------ career record and practice matches
func _career_and_practice(check: Callable, w: World) -> void:
	var me: String = w.club_ids[4]
	var gs := GameState.new_game(w, me, 7007)
	gs._bind()
	# a league game builds the career record
	var g := gs.next_game()
	var res := gs.auto_game(g)
	var side := "B" if g["blue"] == me else "R"
	var line := Report.kda(res)
	var f_before: Dictionary = gs.d["frating"].duplicate()
	gs.record_human_game(g, res)
	var starters: Array = (res["lineups"][side] as Dictionary).values()
	var okc := true
	for slot in Report.SLOTS:
		var pid: String = res["lineups"][side][slot]
		var c: Dictionary = gs.career_all()[pid]
		var won: bool = res["blue_won"] == (side == "B")
		okc = okc and int(c["g"]) == 1 and int(c["w"]) == (1 if won else 0) and int(c["k"]) == int(line[side][slot]["k"]) and int(c["d"]) == int(line[side][slot]["d"]) and int(c["a"]) == int(line[side][slot]["a"])
	check.call(okc, "a league game adds one game and its KDA to each starter's career")
	check.call(absf(gs.form_rating(g["blue"]) - float(f_before[g["blue"]])) > 1e-9, "the league game changed the Form Rating")
	# practice must change nothing that counts
	var pre := {"hist": (gs.d["history"] as Array).size(), "table": JSON.stringify(gs.standings()), "fr": JSON.stringify(gs.d["frating"]),
			"form": JSON.stringify(gs.d["form"]), "morale": JSON.stringify(gs.d["morale"]), "career": JSON.stringify(gs.career_all()), "cash": gs.cash()}
	check.call(gs.practice_available(), "practice is available at the start of a match day")
	var opp: String = gs.practice_opponents()[0]["club"]
	check.call(gs.start_practice(opp, 3) == "" and gs.practice_in_progress() and not gs.practice_available(), "a series opens and uses the day's slot")
	var lu_ids: Array = (gs.d["lineup"] as Dictionary).values()
	for pid in lu_ids:
		w.fatigue[pid] = 50.0
		(gs.d["train"] as Dictionary)[pid] = {"k": "rest", "v": ""}
	var bond_before := gs.bond_mean()
	var games := 0
	var ids_ok := true
	var last_blue := ""
	while gs.practice_in_progress() and games < 5:
		var pg := gs.practice_game()
		ids_ok = ids_ok and pg["kind"] == "exhibition" and pg["id"] == "exh:7007:%d" % (games + 1) and pg["blue"] != last_blue
		last_blue = pg["blue"]
		var r := gs.auto_game(pg)
		gs.record_human_game(pg, r)
		games += 1
	check.call(ids_ok, "practice games use their own seed streams and swap sides")
	check.call(games >= 2 and games <= 3 and not gs.practice_in_progress(), "a best of 3 ends after 2 or 3 games (%d)" % games)
	check.call(gs.d.has("exh_last") and int(gs.d["exh_last"]["best_of"]) == 3, "the series result is kept for the screen")
	check.call((gs.d["history"] as Array).size() == pre["hist"] and JSON.stringify(gs.standings()) == pre["table"], "practice leaves history and the table alone")
	check.call(JSON.stringify(gs.d["frating"]) == pre["fr"], "practice leaves the Form Rating alone")
	check.call(JSON.stringify(gs.d["form"]) == pre["form"] and JSON.stringify(gs.d["morale"]) == pre["morale"], "practice leaves Form and Morale alone")
	check.call(JSON.stringify(gs.career_all()) == pre["career"] and absf(gs.cash() - float(pre["cash"])) < 1e-9, "practice leaves the career record and cash alone")
	var fat_ok := true
	for pid in lu_ids:
		fat_ok = fat_ok and absf(w.fatigue_of(pid) - (50.0 + 5.0 * games)) < 1e-9
	check.call(fat_ok, "each practice game adds 5 fatigue to every starter")
	check.call(gs.bond_mean() > bond_before and gs.bond_mean() <= bond_before + 2.0 * games + 0.01, "practice builds a little bond (%.2f to %.2f)" % [bond_before, gs.bond_mean()])
	check.call(not gs.practice_available(), "only one practice series per match day")
	# the practice day replaces training and rest: busy starters get the match-day tiredness only
	var g2 := gs.next_game()
	gs.record_human_game(g2, gs.auto_game(g2))
	var busy_ok := true
	for pid in lu_ids:
		busy_ok = busy_ok and absf(w.fatigue_of(pid) - (50.0 + 5.0 * games + 15.0)) < 1e-9
	check.call(busy_ok, "after a practice day the starters neither rest nor train (fatigue %.1f)" % w.fatigue_of(lu_ids[0]))
	check.call(gs.practice_available() and (gs.d["exh_busy"] as Array).is_empty(), "the next match day offers practice again")
	# leaving a series half-way
	check.call(gs.start_practice(opp, 5) == "" and gs.practice_in_progress(), "a best of 5 opens")
	gs.end_practice()
	check.call(not gs.practice_in_progress() and gs.practice_available(), "ending a series early does not use the day")
	check.call(gs.start_practice(me, 1) != "" and gs.start_practice("nobody", 1) != "", "you cannot practise against yourself or a club that does not exist")
	# Quick Match: close in strength, deterministic, never yourself
	var mine := w.team_rating(gs.lineup_for(me))
	var qm := gs.quick_match_opponent()
	var gap := absf(w.team_rating(gs.lineup_for(qm)) - mine)
	var nearest := 1e9
	for r2 in gs.practice_opponents():
		nearest = minf(nearest, absf(float(r2["rating"]) - mine))
	check.call(qm != me and (gap <= GameState.QUICK_RANGE or absf(gap - nearest) < 1e-9) and qm == gs.quick_match_opponent(), "Quick Match picks a club within 5 points, or the nearest one")
	# practice is a league-season thing
	gs.autoplay(true)
	var last_done: Dictionary = (gs.d["seasons_done"] as Array).back()
	var led_prize := 0.0
	for e in gs.d["ledger"]:
		if int(e["s"]) == int(gs.d["season"]) and String(e["k"]).begins_with("prize"):
			led_prize += float(e["a"])
	check.call(last_done.has("prize") and absf(float(last_done["prize"]) - snappedf(led_prize, 0.1)) < 0.01, "the trophy cabinet records the season's prize money (%.1f)" % float(last_done.get("prize", -1.0)))
	check.call(not gs.practice_available(), "no practice once the split is over")
	# the save keeps everything and a new season keeps the logs
	var back := GameState.from_dict(w, JSON.parse_string(JSON.stringify(gs.d)))
	check.call(back.d["exh_last"]["won"] == gs.d["exh_last"]["won"] and (back.career_all() as Dictionary).size() == gs.career_all().size(), "practice result and career survive save and load")
	gs.pace_add(100.0, 70.0, false, false)
	var ns := gs.next_season()
	check.call(int(ns.pace()["n"]) == 1 and ns.career_all().size() == gs.career_all().size() and absf(ns.form_rating(me) - gs.form_rating(me)) < 1e-9, "pace log, career and Form Rating carry into the next season")
	check.call(ns.practice_available(), "practice opens again in the new season")
	var logk := false
	for pid in ns.career_all():
		for e in ns.career_all()[pid]["log"]:
			logk = logk or e["k"] == "birthday"
	check.call(logk, "a new season writes birthdays into the career log")
	# signing and releasing are logged (sign first: the club may be at its minimum squad size)
	var signed := ""
	for fid in ns.d["fa"]:
		var wage := int(ceil(ns.asking_wage(fid) * 1.3))
		if ns.offer_block(fid, wage, false) != "":
			continue
		var acc := ns.offer(fid, wage, 3)
		if acc["code"] == "accepted":
			signed = fid
			break
	check.call(signed != "" and ns.career_all()[signed]["log"].back()["k"] == "signed", "a signing is logged")
	var rel := ""
	for pid2 in ns.d["roster"]:
		if pid2 != signed and ns.can_release(pid2) == "":
			rel = pid2
			break
	check.call(rel != "" and ns.release(rel) == "" and ns.career_all()[rel]["log"].back()["k"] == "released", "a release is logged (%s)" % rel)
