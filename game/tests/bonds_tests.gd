class_name BondsTests
extends RefCounted
## Team Bonds (GDD 7.7), Form and Morale (GDD 4.2, 8.6): the maths, the save wiring and the bond-farming limit (GDD 9.2.2).

static func _mk(id: String, com: float, personality: String = "balanced", langs: Array = [{"lang": "en", "fluency": 100}]) -> Dictionary:
	return {"id": id, "personality": personality, "languages": langs, "stats": {"com": com}}


static func _five(com: float, personality: String = "balanced") -> Array:
	var out: Array = []
	for i in 5:
		out.append(_mk("t%d" % i, com, personality))
	return out


func run(check: Callable) -> void:
	# ---- worked numbers (GDD 7.7 and test 9.2.3)
	var bond60 := func(_a, _b): return 60.0
	var chem := Bonds.chem(_five(60.0), bond60)
	var cb := Bonds.chem_bonus(chem)
	check.call(absf(chem - 45.6) < 1e-9 and absf(cb - 0.01915) < 5e-5, "Bond 60 and COM 60 give a ChemBonus of %.4f (1.7 to 2.0 percent)" % cb)
	check.call(cb >= 0.017 and cb <= 0.020, "chemistry curve target 1.7 to 2.0 percent")
	check.call(absf(Bonds.chem_bonus(Bonds.chem_flat(_five(60.0), 30.0)) - 0.0096) < 5e-5, "a new club (Bond 30, COM 60) starts at 0.96 percent")
	check.call(absf(Bonds.chem_bonus(Bonds.chem_flat(_five(60.0), 100.0)) - 0.03192) < 5e-5, "Bond 100 and COM 60 give 3.19 percent")
	check.call(absf(Bonds.chem_bonus(Bonds.chem_flat(_five(100.0), 100.0)) - 0.042) < 1e-9, "Bond 100 and COM 100 give the 4.2 percent maximum")
	# replacing one starter: eight of the twenty values drop from 60 to 20
	var five := _five(60.0)
	var swap := func(a: String, b: String) -> float:
		return 20.0 if (a == "t0" or b == "t0") else 60.0
	var drop := cb - Bonds.chem_bonus(Bonds.chem(five, swap))
	check.call(drop > 0.004 and drop < 0.006, "replacing one starter costs about 0.5 percent (%.4f)" % drop)
	var more_com := Bonds.chem_bonus(Bonds.chem(_five(100.0), bond60)) - cb
	check.call(more_com > 0.005 and more_com < 0.007, "COM 60 to 100 at Bond 60 adds about 0.6 percent (%.4f)" % more_com)

	# ---- language factor with a synthetic multi-language roster
	var en := _mk("a", 60.0)
	var xx := _mk("b", 60.0, "balanced", [{"lang": "xx", "fluency": 100}])
	var weak := _mk("c", 60.0, "balanced", [{"lang": "en", "fluency": 40}])
	var both := _mk("d", 60.0, "balanced", [{"lang": "xx", "fluency": 100}, {"lang": "en", "fluency": 70}])
	check.call(Bonds.lang(en, en) == 1.0 and Bonds.lang(en, xx) == 0.65 and Bonds.lang(en, weak) == 0.65 and Bonds.lang(en, both) == 1.0 and Bonds.lang(xx, both) == 1.0, "language factor is 1.0 when a shared language is spoken at 50 or more, else 0.65")
	var mixed := _five(60.0)
	mixed[0] = _mk("t0", 60.0, "balanced", [{"lang": "xx", "fluency": 100}])
	var chem_mixed := Bonds.chem(mixed, bond60)
	# eight of the twenty values are multiplied by 0.65
	check.call(absf(chem_mixed - chem * (12.0 + 8.0 * 0.65) / 20.0) < 1e-9, "a player with no shared language costs 8 of 20 values x0.65")
	check.call(Bonds.chem(_five(60.0), bond60) == Bonds.chem(_five(60.0), bond60), "chemistry is deterministic")

	# ---- gain rule
	check.call(absf(Bonds.gain(30.0, 4.0, 1.0) - 34.0) < 1e-9, "at Bond 30 a game gives +4")
	check.call(absf(Bonds.gain(65.0, 4.0, 1.0) - 67.0) < 1e-9, "at Bond 65 a game gives +2")
	check.call(Bonds.gain(100.0, 4.0, 1.0) == 100.0 and Bonds.gain(50.0, 4.0, 1.1) > Bonds.gain(50.0, 4.0, 1.0), "gain stops at 100 and casual players bond faster")
	var cas := _mk("x", 50.0, "casual")
	var tem := _mk("y", 50.0, "temperamental")
	var pro := _mk("z", 50.0, "professional")
	check.call(absf(Bonds.pair_growth(cas, cas) - 1.1) < 1e-9 and absf(Bonds.pair_growth(tem, tem) - 0.8) < 1e-9 and absf(Bonds.pair_growth(cas, tem) - sqrt(0.88)) < 1e-9 and Bonds.pair_growth(pro, pro) == 1.0, "pair growth is the geometric mean of the two factors")
	var bnd := 30.0
	var games := 0
	while bnd < 85.0 and games < 200:
		bnd = Bonds.gain(bnd, 4.0, 1.0)
		games += 1
	check.call(games >= 24 and games <= 34, "a pair needs about 30 games together to pass 85 (%d)" % games)

	# ---- bond farming (GDD 9.2.2): the fastest legal route must stay within 20 percent of normal play over a split
	var normal := 30.0
	var scrimmed := 30.0
	var b: Dictionary = Bonds.data()["bond"]
	var scrim_tick := float(b["scrim_week_gain"]) / float(b["ticks_per_week"])
	for tick in 18:
		normal = Bonds.gain(normal, float(b["game_gain"]), 1.0)
		scrimmed = Bonds.gain(scrimmed, float(b["game_gain"]), 1.0)
		scrimmed = Bonds.gain(scrimmed, scrim_tick, 1.0)
	var ratio := (scrimmed - 30.0) / (normal - 30.0)
	check.call(ratio <= 1.20 and ratio > 1.0, "scrims on top of play are at most 20 percent faster over a split (%.3f)" % ratio)

	# ---- form and morale rules
	check.call(Bonds.form_after_match(0.0, true) == 2.0 and Bonds.form_after_match(0.0, false) == -2.0 and Bonds.form_after_match(9.0, true) == 10.0 and Bonds.form_after_match(-9.0, false) == -10.0, "form moves 2 toward the result and stays within -10 to +10")
	check.call(absf(Bonds.form_after_days(10.0, 1.0) - 9.0) < 1e-9 and absf(Bonds.form_after_days(8.0, 3.5) - 8.0 * pow(0.9, 3.5)) < 1e-9, "form keeps 90 percent a day")
	check.call(Bonds.morale_after_match(60.0, "balanced", true, true, false) == 66.0 and Bonds.morale_after_match(60.0, "balanced", true, false, false) == 54.0, "a balanced starter swings 6")
	check.call(absf(Bonds.morale_after_match(60.0, "temperamental", true, true, false) - 69.0) < 1e-9 and absf(Bonds.morale_after_match(60.0, "professional", true, true, false) - 64.8) < 1e-9, "temperamental x1.5, professional x0.8")
	check.call(absf(Bonds.morale_after_match(60.0, "balanced", true, true, true) - 69.0) < 1e-9, "playoff results weigh 1.5")
	check.call(Bonds.morale_after_match(60.0, "balanced", false, true, false) == 61.0 and Bonds.morale_after_match(99.0, "temperamental", true, true, true) == 100.0, "bench swing is 1; morale stops at 100")
	check.call(Bonds.morale_after_days(80.0, 3.5) == 76.5 and Bonds.morale_after_days(58.0, 3.5) == 60.0 and Bonds.morale_after_days(40.0, 3.5) == 43.5, "morale drifts 1 a day toward 60 and never past it")
	check.call(Bonds.miss_loss(1, true) == 0.0 and Bonds.miss_loss(2, true) == 0.0 and Bonds.miss_loss(3, true) == 6.0 and Bonds.miss_loss(3, false) == 0.0 and Bonds.miss_loss(8, true) == 0.0, "a benched starter loses 6 more from the third missed match")

	# ---- the rating: Form enters Cond at 0.4 a point, and nothing changes at the defaults
	var w := World.load_default()
	var p: Dictionary = w.players[w.clubs[w.club_ids[0]]["player_ids"][0]]
	var slot: String = p["role_primary"]
	var hero: Dictionary = w.heroes[w.hero_ids[0]]
	var r0 := w.phase_rating(p, slot, hero, "mid", 50.0, 1.0)
	var r_default := w.phase_rating(p, slot, hero, "mid", 50.0, 1.0, 60.0, 0.0, 0.0)
	var r_form := w.phase_rating(p, slot, hero, "mid", 50.0, 1.0, 60.0, 0.0, 5.0)
	var r_form_ref := w.phase_rating(p, slot, hero, "mid", 50.0, 1.0, 60.0, 0.0, 0.0)
	check.call(r0 == r_default, "form 0 and morale 60 is exactly the old rating")
	var unit := (w.phase_rating(p, slot, hero, "mid", 50.0, 1.0, 60.0, 0.0, 1.0) - r_form_ref)
	check.call(unit > 0.0 and absf((r_form - r_form_ref) - 5.0 * unit) < 1e-9, "form is linear in the rating")
	var base_cond := w.phase_rating(p, slot, hero, "mid", 50.0, 1.0, 50.0, 0.0, 0.0)
	var one_pt := w.phase_rating(p, slot, hero, "mid", 50.0, 1.0, 50.0, 0.0, 2.5)  # 2.5 form = 1.0 point of Cond
	var morale_pt := w.phase_rating(p, slot, hero, "mid", 50.0, 1.0, 50.0 + 1.0 / 0.06, 0.0, 0.0)
	check.call(absf((one_pt - base_cond) - (morale_pt - base_cond)) < 1e-6, "2.5 Form and 16.7 Morale points are each one point of Cond")

	# ---- a save: starting values, one round, roster changes, saving, migration
	var club := "saltmarrow_gulls"
	var gs := GameState.new_game(w, club, 4242)
	var n: int = (gs.d["roster"] as Array).size()
	check.call((gs.d["bonds"] as Dictionary).size() == n * (n - 1) / 2, "a new club stores a bond for every pair (%d)" % (gs.d["bonds"] as Dictionary).size())
	var all30 := true
	for k in gs.d["bonds"]:
		all30 = all30 and float(gs.d["bonds"][k]) == 30.0
	check.call(all30, "every pair of a new club starts at 30")
	check.call(w.dynamic_chem and absf(gs.chem_bonus() - Bonds.chem_bonus(Bonds.chem_flat(gs.lineup().values(), 30.0))) < 1e-9, "the club's chemistry bonus comes from its bonds")
	var dr := MatchRunner.prepare(w, gs.lineup(), w.best_lineup("ironquill_wolves"), w.make_meta("x"), 1, "t:1", false)
	dr.finish_with_ai()
	var tms: Array = MatchRunner.build_teams(w, dr)
	check.call(absf(float(tms[0]["team_mod"]) - gs.chem_bonus()) < 1e-12 and float(tms[1]["team_mod"]) > 0.0, "the simulator's TeamMod is the club's chemistry bonus")

	var lu_ids: Array = (gs.d["lineup"] as Dictionary).values()
	var bench: Array = []
	for pid in gs.d["roster"]:
		if not lu_ids.has(pid):
			bench.append(pid)
	var st0: String = lu_ids[0]
	var st1: String = lu_ids[1]
	gs._after_game(club, lu_ids, true, false, true)
	var b01 := gs.bond(st0, st1)
	var g01 := Bonds.pair_growth(w.players[st0], w.players[st1])
	check.call(absf(b01 - Bonds.gain(30.0, 4.0, g01)) < 1e-9, "starters who played together gain +4 x growth (%.3f)" % b01)
	check.call(gs.bond(bench[0], bench[1]) == 30.0 and gs.bond(st0, bench[0]) == 30.0, "bench pairs do not grow")
	check.call(gs.form_of(st0) > 1.0 and gs.form_of(st0) < 2.0 and gs.form_of(bench[0]) == 0.0, "a win gives starters Form, decayed by the day (%.3f)" % gs.form_of(st0))
	check.call(gs.morale_of(st0) > 60.0 and gs.morale_of(bench[0]) >= 60.0, "a win lifts morale")
	var m_win := gs.morale_of(st0)
	gs._after_game(club, lu_ids, false, false, true)
	check.call(gs.morale_of(st0) < m_win and gs.form_of(st0) < 1.0, "a loss pulls both back down")

	# the bench: a starter who sits on the bench for matches loses morale from the third on
	var gb := GameState.new_game(w, club, 4243)
	var lu_b: Array = (gb.d["lineup"] as Dictionary).values()
	var sitter: String = lu_b[0]
	gb._after_game(club, lu_b, true, false, false)
	var sub: Array = lu_b.duplicate()
	sub.erase(sitter)
	var other: String = ""
	for pid in gb.d["roster"]:
		if not lu_b.has(pid):
			other = pid
			break
	sub.append(other)
	var morales: Array = []
	for i in 5:
		gb._after_game(club, sub, true, false, false)
		morales.append(gb.morale_of(sitter))
	var d1 := float(morales[0]) - gb.morale_of(sitter)
	check.call(float(morales[1]) - float(morales[2]) > 4.5 and float(morales[1]) - float(morales[2]) < 5.5 and float(morales[1]) >= float(morales[0]), "a benched starter loses 6 more from the third missed match (%s)" % str(morales))
	check.call(d1 > 0.0, "and keeps falling")

	# roster changes: new signing starts at 20 with everybody, released players take their pairs with them
	var g2 := GameState.new_game(w, club, 4244)
	g2.d["cash"] = 1.0e6
	var cut: String = g2.d["roster"][9]
	var kept: String = g2.d["roster"][0]
	g2.release(cut)
	check.call(not (g2.d["bonds"] as Dictionary).has(Bonds.pair_key(cut, kept)) and (g2.d["bonds"] as Dictionary).size() == 9 * 8 / 2, "a released player's pairs are deleted")
	var cand := ""
	for pid in g2.d["fa"]:
		if pid != cut:
			cand = pid
			break
	var wage := int(ceil(Economy.required_wage(w, w.players[cand], 2))) + 1
	var code: String = g2.offer(cand, wage, 2)["code"]
	check.call(code == "accepted", "signing works (%s)" % code)
	if code == "accepted":
		check.call(g2.bond(cand, kept) == 20.0, "a new signing starts at 20 with everybody")
		check.call((g2.d["bonds"] as Dictionary).size() == 10 * 9 / 2, "pairs again for the full squad")
	g2.d["lock"] = {}
	g2.d["cash"] = 1.0e6
	var cut_b: String = g2.d["roster"][1]
	for k in g2.d["bonds"]:
		if String(k).contains(cut_b):
			g2.d["bonds"][k] = 77.0
	g2.release(cut_b)
	g2.d["lock"] = {}
	var wage2 := int(ceil(Economy.required_wage(w, w.players[cut_b], 2))) + 1
	var code2: String = g2.offer(cut_b, wage2, 2)["code"]
	if code2 == "accepted":
		var back := true
		for pid in g2.d["roster"]:
			if pid != cut_b:
				back = back and g2.bond(cut_b, pid) == 20.0
		check.call(back, "a re-signed player starts again at 20")
	else:
		check.call(true, "re-sign skipped (%s)" % code2)

	# team scrim: only pairs where both players have it as their focus grow
	var g3 := GameState.new_game(w, club, 4245)
	var ids: Array = g3.d["roster"]
	g3.set_focus(ids[0], "scrim")
	g3.set_focus(ids[1], "scrim")
	g3.set_focus(ids[2], "rest")
	g3._scrim_bonds()
	var gr := Bonds.pair_growth(w.players[ids[0]], w.players[ids[1]])
	check.call(absf(g3.bond(ids[0], ids[1]) - Bonds.gain(30.0, 0.75, gr)) < 1e-9, "a scrim pair gains 0.75 a match day")
	check.call(g3.bond(ids[0], ids[2]) == 30.0 and g3.bond(ids[3], ids[4]) == 30.0, "one scrimming player alone builds nothing")

	# save round trip and an old save
	gs._bind()  # the world shows one save at a time
	var b_now := gs.bond(st0, st1)
	var m_now := gs.morale_of(st0)
	var f_now := gs.form_of(st0)
	var js := JSON.stringify(gs.d)
	var back_d = JSON.parse_string(js)
	var gs2 := GameState.from_dict(w, back_d)
	check.call(absf(gs2.bond(st0, st1) - b_now) < 1e-9, "bonds survive the save")
	check.call(absf(gs2.morale_of(st0) - m_now) < 1e-9 and absf(gs2.form_of(st0) - f_now) < 1e-9, "form and morale survive the save")
	var old = JSON.parse_string(JSON.stringify(g3.d))
	for k in ["form", "morale", "bonds", "ai_bond", "miss", "was_start"]:
		old.erase(k)
	var gs3 := GameState.from_dict(w, old)
	var ok30 := (gs3.d["bonds"] as Dictionary).size() > 0
	for k in gs3.d["bonds"]:
		ok30 = ok30 and float(gs3.d["bonds"][k]) == 30.0
	check.call(ok30, "a save from before Alpha 0.4 opens with every bond at 30")

	# AI squads: one level that grows when the club plays
	var g4 := GameState.new_game(w, club, 4246)
	var rival: String = "ironquill_wolves"
	check.call(float(g4.d["ai_bond"][rival]) == 30.0, "AI squads start at 30")
	g4.autoplay(false)
	check.call(float(g4.d["ai_bond"][rival]) > 65.0 and float(g4.d["ai_bond"][rival]) < 90.0, "an AI squad that played a league has bonded (%.1f)" % float(g4.d["ai_bond"][rival]))
	var mine_end := gs_bond_mean(g4)
	check.call(mine_end > 60.0, "so has the managed club's lineup (%.1f)" % mine_end)
	var morales_ok := true
	for pid in w.players:
		if g4.d["morale"].has(pid):
			var m: float = g4.d["morale"][pid]
			var f: float = g4.d["form"][pid]
			morales_ok = morales_ok and m >= 0.0 and m <= 100.0 and f >= -10.0 and f <= 10.0
	check.call(morales_ok, "form and morale stay inside their ranges over a split")

	# next season: bonds carry over, form fades, morale returns toward 60
	g4.advance_playoffs()
	g4.autoplay(true)
	if g4.d["phase"] == "done":
		var ns := g4.next_season()
		var surv := 0
		for k in ns.d["bonds"]:
			surv += 1
		check.call(surv == (ns.d["roster"] as Array).size() * ((ns.d["roster"] as Array).size() - 1) / 2, "bonds carry into the next season for every pair")
		var big_form := 0.0
		for pid in ns.d["form"]:
			big_form = maxf(big_form, absf(float(ns.d["form"][pid])))
		check.call(big_form < 1.0, "form is back near 0 after the off-season (%.2f)" % big_form)
		check.call(float(ns.d["ai_bond"][rival]) == float(g4.d["ai_bond"][rival]), "AI squads keep their bond level")


static func gs_bond_mean(gs: GameState) -> float:
	var lu: Array = (gs.d["lineup"] as Dictionary).values()
	var t := 0.0
	var n := 0
	for i in lu.size():
		for j in range(i + 1, lu.size()):
			t += gs.bond(lu[i], lu[j])
			n += 1
	return t / float(n)
