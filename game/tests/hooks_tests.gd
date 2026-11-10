extends RefCounted
## I-06 read-only helpers (build plan 0.7): GameState.upcoming and cut_gap, Draft.best_slot_for, Report.team_kills.
## Headless: no autoloads, nothing here touches UI classes. Auto-discovered by run_tests.gd (run(check)).
## Every helper is checked to leave the save untouched (JSON of gs.d identical before and after).

const CLUB := "ironquill_wolves"


func run(check: Callable) -> void:
	var w := World.load_default()
	_upcoming(check, w)
	_cut_gap(check, w)
	_best_slot_for(check, w)
	_team_kills(check, w)


## Replace the calendar with hand-made fixtures. `played`: [[winner, loser], ...] (one game each, played);
## `open`: [[blue, red], ...] (unplayed, round numbers continue after the played ones).
func _hand_fixtures(gs: GameState, played: Array, open: Array) -> void:
	var fx: Array = []
	var r := 0
	for p in played:
		fx.append({"id": "h:%d" % r, "round": r, "blue": p[0], "red": p[1], "played": true, "winner": p[0], "final": 0.3})
		r += 1
	for o in open:
		fx.append({"id": "h:%d" % r, "round": r, "blue": o[0], "red": o[1], "played": false, "winner": "", "final": 0.0})
		r += 1
	gs.d["fixtures"] = fx


# ------------------------------------------------------------------ upcoming
func _upcoming(check: Callable, w: World) -> void:
	var gs := GameState.new_game(w, CLUB, 70601)
	var ids: Array = w.club_ids.duplicate()
	var others: Array = ids.filter(func(c): return c != CLUB)
	var a: String = others[0]
	var b: String = others[1]
	var c: String = others[2]
	var e: String = others[3]
	# played: me v a. open: b (me blue), c (me red), not-me game, e (me red)
	_hand_fixtures(gs, [[CLUB, a]], [[CLUB, b], [c, CLUB], [a, b], [e, CLUB]])
	var before := JSON.stringify(gs.d)
	var up2 := gs.upcoming(2)
	check.call(up2.size() == 2, "upcoming(2) gives two games")
	check.call(up2.size() == 2 and up2[0]["opp"] == b and up2[1]["opp"] == c, "upcoming keeps calendar order and skips played and foreign games")
	check.call(up2.size() == 2 and up2[0]["side"] == "B" and up2[1]["side"] == "R", "upcoming: side B when the club is blue, R when red")
	check.call(up2.size() == 2 and up2[0]["round"] == 1 and up2[0]["id"] == "h:1", "upcoming: round and fixture id are the fixture's")
	check.call(gs.upcoming(99).size() == 3, "upcoming(99) is every unplayed game of the club (3), not more")
	check.call(gs.upcoming(0).is_empty() and gs.upcoming(-1).is_empty(), "upcoming(0) is empty")
	var mine := w.team_rating(gs.lineup())
	var words_ok := true
	var rating_ok := true
	for u in gs.upcoming(99):
		var theirs := w.team_rating(gs.lineup_for(u["opp"]))
		rating_ok = rating_ok and is_equal_approx(float(u["theirs"]), theirs) and is_equal_approx(float(u["mine"]), mine) and is_equal_approx(float(u["gap"]), mine - theirs)
		var want := "favoured" if mine - theirs > 2.0 else ("underdog" if mine - theirs < -2.0 else "even")
		words_ok = words_ok and u["word"] == want
	check.call(rating_ok, "upcoming: ratings are team_rating of both lineups, gap is mine minus theirs")
	check.call(words_ok, "upcoming: word follows the 2.0 point rule")
	# the word rule over every opponent of the league: all three words are legal, and the rule is a pure function of the gap
	for o in others:
		var g2 := GameState.new_game(w, CLUB, 70601)
		_hand_fixtures(g2, [], [[CLUB, o]])
		var u: Dictionary = g2.upcoming(1)[0]
		check.call(["favoured", "even", "underdog"].has(u["word"]), "upcoming: word is one of three (%s)" % o)
	check.call(JSON.stringify(gs.d) == before, "upcoming leaves the save untouched")
	# season over: the real calendar, every game played
	var gs2 := GameState.new_game(w, CLUB, 70602)
	check.call(gs2.upcoming(3).size() == 3 and gs2.upcoming(3)[0]["round"] == 0, "upcoming on a new save starts at round 0")
	check.call(gs2.upcoming(99).size() == 18, "upcoming on a new save: 18 league games")
	for f in gs2.d["fixtures"]:
		f["played"] = true
	check.call(gs2.upcoming(5).is_empty(), "upcoming is empty once every league game is played")


# ------------------------------------------------------------------ cut_gap
func _cut_gap(check: Callable, w: World) -> void:
	var gs := GameState.new_game(w, CLUB, 70603)
	var others: Array = w.club_ids.filter(func(c): return c != CLUB)
	var weak: Array = others.slice(0, 5)          # w0..w4
	var strong: Array = others.slice(5, 9)        # s0..s3
	# helper: n wins of `winner` over the rest of the clubs (loser rotates; no points for losers)
	var wins := func(winner: String, n: int) -> Array:
		var out: Array = []
		for i in n:
			var loser: String = others[i % others.size()] if others[i % others.size()] != winner else CLUB
			out.append([winner, loser])
		return out

	# A "in": me 4 wins (12), the 5th best has 2 wins (6), the line (4th) is me or a club with 3 wins
	var pl: Array = []
	pl.append_array(wins.call(CLUB, 4))
	for s in strong:
		pl.append_array(wins.call(s, 3))
	pl.append_array(wins.call(weak[0], 2))
	_hand_fixtures(gs, pl, [[CLUB, weak[1]], [weak[2], CLUB]])
	var before := JSON.stringify(gs.d)
	var cg := gs.cut_gap()
	var st := gs.standings()
	check.call(cg["state"] == "in" and cg["rank"] <= 4, "cut_gap A: rank %d is in the top 4 and clear of 5th (%s)" % [cg["rank"], cg["state"]])
	check.call(int(cg["gap"]) == int(cg["pts"]) - int(st[4]["pts"]) and int(cg["gap"]) > 0, "cut_gap A: gap is my points minus 5th's (%d)" % cg["gap"])
	check.call(int(cg["line_pts"]) == int(st[3]["pts"]) and int(cg["pts"]) == 12, "cut_gap A: line_pts is 4th's points, pts are mine (12)")
	check.call(int(cg["games_left"]) == 2, "cut_gap A: games_left counts my unplayed league games (2)")
	check.call(JSON.stringify(gs.d) == before, "cut_gap leaves the save untouched")

	# B "out": four clubs on 9, me on 0
	pl = []
	for s in strong:
		pl.append_array(wins.call(s, 3))
	_hand_fixtures(gs, pl, [])
	cg = gs.cut_gap()
	check.call(cg["state"] == "out" and cg["rank"] >= 5 and int(cg["gap"]) == 9, "cut_gap B: 9 points behind the line (%s, gap %d)" % [cg["state"], cg["gap"]])
	check.call(int(cg["games_left"]) == 0, "cut_gap B: games_left 0 with no open fixtures")

	# C "on": five clubs on 9 points (me and the four strong ones): level with the line whatever the tie-break says
	pl = []
	for s in strong:
		pl.append_array(wins.call(s, 3))
	pl.append_array(wins.call(CLUB, 3))
	_hand_fixtures(gs, pl, [])
	cg = gs.cut_gap()
	check.call(cg["state"] == "on" and int(cg["gap"]) == 0, "cut_gap C: level on points with the line (rank %d)" % cg["rank"])

	# E "out" by a little: me on 6, four clubs on 9
	pl = []
	for s in strong:
		pl.append_array(wins.call(s, 3))
	pl.append_array(wins.call(CLUB, 2))
	_hand_fixtures(gs, pl, [])
	cg = gs.cut_gap()
	check.call(cg["state"] == "out" and int(cg["gap"]) == 3 and cg["rank"] == 5, "cut_gap E: rank 5, 3 points behind (%s, %d)" % [cg["state"], cg["gap"]])

	# D "after": the league rounds are over
	gs.d["phase"] = "playoffs"
	check.call(gs.cut_gap()["state"] == "after", "cut_gap D: after the league rounds (phase playoffs)")
	gs.d["phase"] = "done"
	check.call(gs.cut_gap()["state"] == "after", "cut_gap D: after the league rounds (phase done)")
	check.call(int(gs.cut_gap()["gap"]) == 0, "cut_gap D: gap is 0 after the league")

	# F: a real calendar, game by game: gap never negative, state always legal, rank matches rank_of
	var g3 := GameState.new_game(w, CLUB, 70604)
	var legal := true
	var rank_ok := true
	while g3.d["phase"] == "league":
		var c := g3.cut_gap()
		legal = legal and ["in", "on", "out"].has(c["state"]) and int(c["gap"]) >= 0
		rank_ok = rank_ok and int(c["rank"]) == g3.rank_of(CLUB)
		var g := g3.next_game()
		if g.is_empty():
			break
		g3.record_human_game(g, g3.auto_game(g))
	check.call(legal, "cut_gap F: a whole league, every state legal and gap >= 0")
	check.call(rank_ok, "cut_gap F: rank is rank_of(club) at every step")


# ------------------------------------------------------------------ best_slot_for
## The inline logic of ScreenDraft._actions (alpha 0.6), copied verbatim for the comparison.
func _inline_best(d: Draft, team: String, hid: String) -> Array:
	var h: Dictionary = d.world.heroes[hid]
	var v := 0.0
	var best_slot := ""
	for s in d.open_slots(team):
		var f := d.world.familiarity(d.lineups[team][s], hid) * d.world.hero_fit(h, s)
		if f > v or best_slot == "":
			v = f
			best_slot = s
	return [best_slot, v]


func _best_slot_for(check: Callable, w: World) -> void:
	var gs := GameState.new_game(w, CLUB, 70605)
	var g := gs.next_game()
	var d := MatchRunner.prepare(w, gs.lineup_for(g["blue"]), gs.lineup_for(g["red"]), gs.meta_for(0), int(gs.d["save_seed"]), g["id"], true)
	var same := 0
	var diff := 0
	var empty_ok := true
	var steps := 0
	while not d.is_done():
		for team in ["B", "R"]:
			for hid in d.avail:
				var old := _inline_best(d, team, hid)
				var now := d.best_slot_for(team, hid)
				if now["slot"] == old[0] and is_equal_approx(float(now["score"]), float(old[1])):
					same += 1
				else:
					diff += 1
				empty_ok = empty_ok and (d.open_slots(team).is_empty() == (now["slot"] == ""))
				empty_ok = empty_ok and is_equal_approx(float(now["score"]), float(now["fam"]) * float(now["fit"]))
		d.apply(d.ai_choice())
		steps += 1
	check.call(steps == 16 and same > 1000 and diff == 0, "best_slot_for equals the old inline result for every hero, both teams, all 16 draft steps (%d same, %d different)" % [same, diff])
	check.call(empty_ok, "best_slot_for: slot is empty only when the team has no open slot; score = fam * fit")
	var done_team := d.best_slot_for("B", w.hero_ids[0])
	check.call(done_team["slot"] == "" and float(done_team["score"]) == 0.0, "best_slot_for after the draft: no open slot gives an empty answer")
	# a fresh draft: open slots are all five; the winner is the slot with the highest fam * fit, first one on ties
	var d2 := MatchRunner.prepare(w, gs.lineup_for(g["blue"]), gs.lineup_for(g["red"]), gs.meta_for(0), int(gs.d["save_seed"]), g["id"], true)
	var snapshot := JSON.stringify([d2.step, d2.avail, d2.log, d2.picks.size()])
	var n_ok := true
	for hid in d2.avail:
		var bs := d2.best_slot_for("B", hid)
		var top := -1.0
		for s in Draft.SLOTS:
			top = maxf(top, w.familiarity(d2.lineups["B"][s], hid) * w.hero_fit(w.heroes[hid], s))
		n_ok = n_ok and is_equal_approx(float(bs["score"]), top)
	check.call(n_ok, "best_slot_for on a fresh draft returns the maximum of fam * fit over the five slots")
	check.call(snapshot == JSON.stringify([d2.step, d2.avail, d2.log, d2.picks.size()]), "best_slot_for changes nothing in the draft")


# ------------------------------------------------------------------ team_kills
func _team_kills(check: Callable, w: World) -> void:
	var gs := GameState.new_game(w, CLUB, 70606)
	var sum_ok := true
	var team_ok := true
	var winner_ok := true
	var keys_ok := true
	var n := 0
	for i in 12:
		var a: String = w.club_ids[i % 10]
		var b: String = w.club_ids[(i * 3 + 1) % 10]
		if a == b:
			continue
		var r := MatchRunner.auto(w, gs.lineup_for(a), gs.lineup_for(b), gs.meta_for(0), 7100 + i, "tk-%d" % i, false, {})
		var tk := Report.team_kills(r)
		var k := Report.kda(r)
		keys_ok = keys_ok and tk.has("B") and tk.has("R") and tk.size() == 2
		for side in ["B", "R"]:
			var s := 0
			for slot in Report.SLOTS:
				s += int(k[side][slot]["k"])
			sum_ok = sum_ok and int(tk[side]) == s
			team_ok = team_ok and int(tk[side]) == int(k["team"][side]["k"])
		var blue_more := int(tk["B"]) > int(tk["R"])
		winner_ok = winner_ok and blue_more == bool(r["blue_won"])
		n += 1
	check.call(n >= 10 and keys_ok, "team_kills returns {B, R} (%d games)" % n)
	check.call(sum_ok, "team_kills equals the sum of the players' kills in Report.kda")
	check.call(team_ok, "team_kills equals kda()['team'][side]['k']")
	check.call(winner_ok, "team_kills: the winner always has more kills (score line agrees with the result)")
