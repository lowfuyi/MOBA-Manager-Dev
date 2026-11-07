class_name GameTests
extends RefCounted
## Season layer: schedule, standings, playoffs, determinism, familiarity growth, save/load.

var _check: Callable


func run(check: Callable) -> void:
	_check = check
	var w := World.load_default()
	_schedule(w)
	_lineup(w)
	_season(w)
	_save_load(w)


func _schedule(w: World) -> void:
	var gs := GameState.new_game(w, "ironquill_wolves", 4242)
	var fx: Array = gs.d["fixtures"]
	_check.call(fx.size() == 90, "schedule has 90 fixtures")
	var per_round := {}
	var pair_sides := {}
	var games := {}
	for f in fx:
		var r: int = f["round"]
		if not per_round.has(r):
			per_round[r] = {}
		for c in [f["blue"], f["red"]]:
			per_round[r][c] = int(per_round[r].get(c, 0)) + 1
			games[c] = int(games.get(c, 0)) + 1
		var key: String = f["blue"] + ">" + f["red"]
		pair_sides[key] = true
	var one_each := true
	for r in per_round:
		one_each = one_each and (per_round[r] as Dictionary).size() == 10
		for c in per_round[r]:
			one_each = one_each and per_round[r][c] == 1
	_check.call(one_each, "every club plays once per round")
	var eighteen := true
	for c in games:
		eighteen = eighteen and games[c] == 18
	_check.call(eighteen, "every club plays 18 games")
	_check.call(pair_sides.size() == 90, "every ordered pair appears exactly once (home and away)")


func _lineup(w: World) -> void:
	var gs := GameState.new_game(w, "ironquill_wolves", 1)
	var before: Dictionary = gs.d["lineup"].duplicate()
	var other: String = before["mid"]
	_check.call(gs.assign("top", other), "assign own player")
	_check.call(gs.d["lineup"]["top"] == other and gs.d["lineup"]["mid"] == before["top"], "assigning a starter swaps slots")
	_check.call(not gs.assign("top", "p999"), "foreign player refused")
	var ids := {}
	for s in GameState.SLOTS:
		ids[gs.d["lineup"][s]] = true
	_check.call(ids.size() == 5, "lineup keeps five distinct players")


func _play_season(w: World, club: String, seed_value: int) -> GameState:
	var gs := GameState.new_game(w, club, seed_value)
	gs.autoplay(true)
	return gs


func _table_key(gs: GameState) -> String:
	var parts: Array = []
	for r in gs.standings():
		parts.append("%s:%d:%d" % [r["club"], r["w"], r["pts"]])
	return ",".join(parts)


func _season(w: World) -> void:
	var gs := _play_season(w, "stormvale_herons", 777)
	_check.call(gs.d["phase"] == "done", "season ends in phase done")
	_check.call(gs.d["champion"] != "", "season has a champion")
	var st := gs.standings()
	var wins := 0
	var pts := 0
	var played_ok := true
	for r in st:
		wins += int(r["w"])
		pts += int(r["pts"])
		played_ok = played_ok and int(r["p"]) == 18 and int(r["w"]) + int(r["l"]) == 18
	_check.call(wins == 90 and pts == 270 and played_ok, "standings add up (90 wins, 270 points, 18 each)")
	var ranks_ok := true
	for i in st.size():
		ranks_ok = ranks_ok and int(st[i]["rank"]) == i + 1
	_check.call(ranks_ok, "ranks are 1..10")
	var series: Array = gs.d["playoffs"]["series"]
	_check.call(series.size() == 3, "two semis and a final")
	var sane := true
	for s in series:
		var need: int = int(s["best_of"]) / 2 + 1
		sane = sane and s["done"] and maxi(int(s["wins_a"]), int(s["wins_b"])) == need and (s["games"] as Array).size() <= int(s["best_of"])
	_check.call(sane, "series finished with the right win counts")
	_check.call(series[2]["best_of"] == 5 and series[0]["best_of"] == 3, "final is best of 5, semis best of 3")
	var seeds: Array = gs.d["playoffs"]["seeds"]
	_check.call(seeds[0] == st[0]["club"] and seeds[3] == st[3]["club"], "playoff seeds are the top four")
	_check.call(gs.d["champion"] == series[2]["winner"], "champion is the final's winner")
	_check.call((gs.d["seasons_done"] as Array).size() == 1, "season archived")
	_check.call((gs.d["history"] as Array).size() >= 18, "human games are in the history")
	var bonus_total := 0.0
	for k in gs.d["fam_bonus"]:
		bonus_total += float(gs.d["fam_bonus"][k])
	_check.call(bonus_total >= 18.0 * 5.0 * 3.0, "familiarity grows +3 per starter per game (got %.0f)" % bonus_total)
	# determinism and sensitivity
	var again := _play_season(w, "stormvale_herons", 777)
	_check.call(_table_key(again) == _table_key(gs) and again.d["champion"] == gs.d["champion"], "same seed gives the same season")
	var other := _play_season(w, "stormvale_herons", 778)
	_check.call(_table_key(other) != _table_key(gs), "different seed gives a different season")
	# strength shows up over a season: top-rated club should usually finish above bottom-rated
	var best := ""
	var worst := ""
	var hi := -1.0
	var lo := 1000.0
	for c in w.club_ids:
		var tr := w.team_rating(w.best_lineup(c))
		if tr > hi:
			hi = tr
			best = c
		if tr < lo:
			lo = tr
			worst = c
	_check.call(gs.rank_of(best) < gs.rank_of(worst), "strongest club finishes above the weakest (%s %d vs %s %d)" % [best, gs.rank_of(best), worst, gs.rank_of(worst)])
	# next season carries state
	var n := gs.next_season()
	_check.call(int(n.d["season"]) == 2 and n.d["phase"] == "league" and (n.d["fixtures"] as Array).size() == 90 and (n.d["seasons_done"] as Array).size() == 1, "next season starts fresh")
	_check.call(n.d["fixtures"][0]["id"] != gs.d["fixtures"][0]["id"], "next season uses new match ids")


func _save_load(w: World) -> void:
	var gs := GameState.new_game(w, "duskwater_foxes", 31337)
	for i in 5:
		var g := gs.next_game()
		gs.record_human_game(g, gs.auto_game(g))
	_check.call(gs.save(), "save writes")
	var back := GameState.load_save(w)
	_check.call(back != null, "save loads")
	if back == null:
		return
	var a := JSON.stringify(JSON.parse_string(JSON.stringify(gs.d)))
	var b := JSON.stringify(back.d)
	_check.call(a == b, "save round trip is lossless")
	var g1 := gs.next_game()
	var g2 := back.next_game()
	_check.call(g1["id"] == g2["id"] and int(back.d["round"]) == 5, "loaded save resumes at the same game")
	var r1 := gs.auto_game(g1)
	var r2 := back.auto_game(g2)
	_check.call(absf(float(r1["final"]) - float(r2["final"])) < 1e-12, "loaded save replays the same game")
	GameState.delete_save()
	_check.call(not GameState.has_save(), "save deleted")
