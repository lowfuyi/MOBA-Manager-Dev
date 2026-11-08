extends SceneTree
## Stability soak (Alpha 0.6): plays many full seasons with random but legal manager behaviour (training changes,
## lineup swaps, Game Plans, practice series, signings, releases, renewals, save round trips) and checks the
## invariants after every season. Not part of the quick checks.
## Run from game/:  godot --headless --script res://tests/soak.gd -- <seasons per run> <runs> [first_seed]
## Exit code 1 if any invariant breaks, with the first few reports printed.

var failures: Array = []
var checks := 0


func _fail(msg: String) -> void:
	failures.append(msg)
	if failures.size() <= 25:
		print("BROKEN: ", msg)


func _ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		_fail(msg)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seasons := int(args[0]) if args.size() > 0 else 20
	var runs := int(args[1]) if args.size() > 1 else 3
	var first_seed := int(args[2]) if args.size() > 2 else 31000
	var w := World.load_default()
	var t_all := Time.get_ticks_msec()
	var season_ms: Array = []
	var dismissed := 0
	var seasons_played := 0
	var titles := 0
	var practice_games := 0
	var signings := 0
	var releases := 0
	for run in runs:
		var rng := RandomNumberGenerator.new()
		rng.seed = first_seed + run
		var club: String = w.club_ids[(first_seed + run * 3) % w.club_ids.size()]
		var gs := GameState.new_game(w, club, first_seed + run)
		gs._bind()
		var frating_total := _sum(gs.d["frating"])
		for s in seasons:
			var t0 := Time.get_ticks_msec()
			var tag := "run %d season %d" % [run, s + 1]
			_play_season(gs, w, rng, tag)
			practice_games += int(gs.d.get("exh_n", 0))
			_check_season(gs, w, tag, frating_total)
			if gs.d["champion"] == gs.club():
				titles += 1
			season_ms.append(Time.get_ticks_msec() - t0)
			seasons_played += 1
			if gs.is_dismissed():
				dismissed += 1
				# a dismissed manager starts again at another club, as the game over screen does
				club = w.club_ids[(w.club_ids.find(club) + 1) % w.club_ids.size()]
				gs = GameState.new_game(w, club, first_seed + run * 100 + s)
				gs._bind()
				frating_total = _sum(gs.d["frating"])
				continue
			var actions := _off_season(gs, w, rng)
			signings += actions[0]
			releases += actions[1]
			# a save in the middle of everything must come back exactly
			_check_roundtrip(gs, w, tag)
			gs = gs.next_season()
			gs._bind()
	var mx := 0
	var sm := 0
	for m in season_ms:
		mx = maxi(mx, m)
		sm += m
	print("soak: %d runs x %d seasons = %d seasons, %d checks, %d failures" % [runs, seasons, seasons_played, checks, failures.size()])
	print("      titles %d, dismissed %d, practice games %d, signings %d, releases %d" % [titles, dismissed, practice_games, signings, releases])
	print("      season time avg %d ms, max %d ms, total %.1f s" % [sm / maxi(1, season_ms.size()), mx, (Time.get_ticks_msec() - t_all) / 1000.0])
	quit(1 if failures.size() > 0 else 0)


func _sum(d: Dictionary) -> float:
	var t := 0.0
	for k in d:
		t += float(d[k])
	return t


## One league season with the human club's choices made at random.
func _play_season(gs: GameState, w: World, rng: RandomNumberGenerator, tag: String) -> void:
	var guard := 0
	var plan_roll := rng.randf()
	if plan_roll < 0.5:
		var p := GamePlan.neutral()
		for sl in GamePlan.SLIDERS:
			p[sl] = GamePlan.STEPS[rng.randi() % GamePlan.STEPS.size()]
		p["jf"] = GamePlan.JUNGLE_CHOICES[rng.randi() % GamePlan.JUNGLE_CHOICES.size()]
		gs.plan_set()["default"] = p
	while gs.d["phase"] != "done" and guard < 500:
		guard += 1
		var g := gs.next_game()
		if g.is_empty():
			gs.autoplay(true)
			continue
		var roll := rng.randf()
		if g["kind"] == "league":
			if roll < 0.15:
				_random_training(gs, w, rng)
			elif roll < 0.22:
				_random_lineup(gs, w, rng)
			elif roll < 0.30 and gs.practice_available():
				_practice(gs, rng, tag)
			elif roll < 0.33:
				gs.set_quick(not gs.is_quick())
		var before := Payoff.snapshot(gs)
		var res := gs.auto_game(g)
		gs.record_human_game(g, res)
		var pay := Payoff.compare(gs, before)
		_ok(pay["rows"].size() == 5, tag + ": payoff always has five rows")
		if guard % 7 == 0:
			gs.pace_add(rng.randf_range(60.0, 400.0), rng.randf_range(20.0, 75.0), rng.randf() < 0.3, rng.randf() < 0.3)
	_ok(gs.d["phase"] == "done", tag + ": season ends (guard %d)" % guard)


func _practice(gs: GameState, rng: RandomNumberGenerator, tag: String) -> void:
	var opps := gs.practice_opponents()
	var opp: String = opps[rng.randi() % opps.size()]["club"]
	var bo: int = [1, 3, 5][rng.randi() % 3]
	if rng.randf() < 0.3:
		opp = gs.quick_match_opponent()
		bo = 1
	_ok(gs.start_practice(opp, bo) == "", tag + ": practice series opens")
	var guard := 0
	while gs.practice_in_progress() and guard < 6:
		guard += 1
		var pg := gs.practice_game()
		gs.record_human_game(pg, gs.auto_game(pg))
		if rng.randf() < 0.15 and gs.practice_in_progress():
			gs.end_practice()
	_ok(not gs.practice_in_progress(), tag + ": practice series ends")


func _random_training(gs: GameState, w: World, rng: RandomNumberGenerator) -> void:
	var plist := gs.roster_players()
	var p: Dictionary = plist[rng.randi() % plist.size()]
	match rng.randi() % 5:
		0:
			gs.set_focus(p["id"], "stat", World.STATS[rng.randi() % World.STATS.size()])
		1:
			gs.set_focus(p["id"], "hero", w.hero_ids[rng.randi() % w.hero_ids.size()])
		2:
			gs.set_focus(p["id"], "rest")
		3:
			gs.set_focus(p["id"], "scrim")
		_:
			gs.coach_picks_all()


func _random_lineup(gs: GameState, w: World, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.4:
		gs.reset_lineup()
		return
	var roster: Array = gs.d["roster"]
	var slot: String = World.SLOTS[rng.randi() % World.SLOTS.size()]
	gs.assign(slot, roster[rng.randi() % roster.size()])


## Renew, sign and release the way a busy manager might. Returns [signings, releases].
func _off_season(gs: GameState, w: World, rng: RandomNumberGenerator) -> Array:
	var signed := 0
	var released := 0
	for p in gs.expiring():
		if rng.randf() < 0.8:
			var need := int(ceil(Economy.required_wage(w, p, 2))) + 1
			gs.offer(p["id"], need, 2, true)
	if rng.randf() < 0.7:
		var fas := gs.fa_players()
		fas.sort_custom(func(a, b): return Economy.best_slot_rating(w, a) > Economy.best_slot_rating(w, b))
		for f in fas.slice(0, 4):
			var wage := int(ceil(Economy.required_wage(w, f, 2))) + 1
			if gs.offer_block(f["id"], wage, false) == "" and gs.offer(f["id"], wage, 2)["code"] == "accepted":
				signed += 1
				break
	if rng.randf() < 0.4:
		var roster: Array = (gs.d["roster"] as Array).duplicate()
		for pid in roster:
			if gs.can_release(pid) == "" and gs.release(pid) == "":
				released += 1
				break
	gs.reset_lineup()
	return [signed, released]


func _check_season(gs: GameState, w: World, tag: String, frating_total: float) -> void:
	var st := gs.standings()
	var wins := 0
	var losses := 0
	var games := {}
	for r in st:
		wins += int(r["w"])
		losses += int(r["l"])
		games[int(r["w"]) + int(r["l"])] = true
	_ok(wins == losses, tag + ": league wins equal losses (%d vs %d)" % [wins, losses])
	_ok(games.size() == 1, tag + ": every club played the same number of games")
	_ok(gs.d["champion"] != "" and w.clubs.has(gs.d["champion"]), tag + ": a champion is crowned")
	_ok(is_finite(gs.cash()), tag + ": cash is a number")
	var roster: Array = gs.d["roster"]
	_ok(roster.size() >= 5 and roster.size() <= int(Economy.data()["max_roster"]), tag + ": roster size %d is legal" % roster.size())
	var seen := {}
	for slot in World.SLOTS:
		var pid: String = gs.d["lineup"][slot]
		_ok(roster.has(pid) and not seen.has(pid), tag + ": lineup %s is on the roster and unique" % slot)
		seen[pid] = true
	_ok(absf(_sum(gs.d["frating"]) - frating_total) < 1e-5, tag + ": Form Ratings still add up (%.4f vs %.4f)" % [_sum(gs.d["frating"]), frating_total])
	for pid in gs.career_all():
		var c: Dictionary = gs.career_all()[pid]
		_ok(int(c["g"]) >= int(c["w"]) and int(c["w"]) >= 0 and int(c["k"]) >= 0 and int(c["d"]) >= 0 and int(c["a"]) >= 0, tag + ": career numbers sane for " + pid)
		_ok((c["log"] as Array).size() <= Career.LOG_MAX, tag + ": career log is capped")
	for pid in w.players:
		var f := w.fatigue_of(pid)
		_ok(f >= 0.0 and f <= 100.0 and is_finite(f), tag + ": fatigue in range")
	_ok(gs.bond_mean() >= 0.0 and gs.bond_mean() <= 100.0, tag + ": bonds in range")
	_ok(not gs.practice_in_progress(), tag + ": no practice series left open")


func _check_roundtrip(gs: GameState, w: World, tag: String) -> void:
	var s1 := JSON.stringify(gs.d)
	var back := GameState.from_dict(w, JSON.parse_string(s1))
	var s2 := JSON.stringify(back.d)
	var s3 := JSON.stringify(GameState.from_dict(w, JSON.parse_string(s2)).d)
	_ok(s2 == s3, tag + ": saving and loading twice changes nothing")
	for k in gs.d:
		if not back.d.has(k):
			_fail(tag + ": save lost the key " + str(k))
	_ok(back.club() == gs.club() and int(back.d["season"]) == int(gs.d["season"]), tag + ": save keeps club and season")
