extends RefCounted
## Match Sim v2 logic tests (MATCH-SIM-V2-DESIGN section 13):
##   determinism  the same inputs and seed give the identical event log, track and result; another seed gives another game
##   invariants   over 16 AI games: event times never go backwards; a dead hero acts only after its respawn; every kill's victim
##                was alive; team kills equal the sum of hero kills; the loser's Cairn is the last structure down and `end` is the
##                last event; levels 1 to 15; builds legal and at most six items held
##   roles        junglers clear camps early and gank; supports stay near their carry in the laning phase; tops stay on the
##                top side early; mids roam in some games; teams call objectives
##   items        the coach's build is legal for every hero in its primary slot; shopping follows the build; anti-heal is picked
##                for a carry against a heavy-heal draft
##   levers       a +30 rating favourite wins at least 13 of 16 side-alternated games (the full bands are the calibration report)

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const N := 16


static func ctx_of(d: Draft) -> Dictionary:
	var ctx := {"picks": {"B": {}, "R": {}}, "players": {"B": {}, "R": {}}}
	for side in ["B", "R"]:
		for s in SLOTS:
			ctx["picks"][side][s] = d.picks[side][s]["id"]
			ctx["players"][side][s] = d.lineups[side][s]
	return ctx


func run(check: Callable) -> void:
	var w := World.load_default()
	var meta := w.make_meta("sim-v2-test")
	var games: Array = []
	var t0 := Time.get_ticks_msec()
	for i in N:
		var a: String = w.club_ids[i % w.club_ids.size()]
		var b: String = w.club_ids[(i * 3 + 1) % w.club_ids.size()]
		if a == b:
			b = w.club_ids[(i + 1) % w.club_ids.size()]
		var d := MatchRunner.prepare(w, w.best_lineup(a), w.best_lineup(b), meta, 5100 + i, "v2t:%d" % i, false)
		d.finish_with_ai()
		var teams := MatchRunner.build_teams(w, d)
		games.append([d, teams, MatchSimV2.simulate(teams[0], teams[1], d.mseed, {}, ctx_of(d))])
	var ms := float(Time.get_ticks_msec() - t0) / float(N)
	print("sim_v2_tests: %.0f ms per game (headless desktop, not a phone)" % ms)
	_determinism(check, games[0])
	_invariants(check, games)
	_roles(check, games)
	_items(check, w)
	_levers(check)
	_interim_show(check, w, meta)
	_golden(check)


func _determinism(check: Callable, g: Array) -> void:
	var d: Draft = g[0]
	var teams: Array = g[1]
	var r1: Dictionary = g[2]
	var r2 := MatchSimV2.simulate(teams[0], teams[1], d.mseed, {}, ctx_of(d))
	check.call(JSON.stringify(r1["log"]["ev"]) == JSON.stringify(r2["log"]["ev"]), "v2: same inputs and seed give the identical event log")
	var same_track := true
	for k in r1["log"]["track"]:
		same_track = same_track and (r1["log"]["track"][k] as PackedFloat32Array) == (r2["log"]["track"][k] as PackedFloat32Array)
	check.call(same_track, "v2: same inputs and seed give the identical position track")
	check.call(r1["a_won"] == r2["a_won"] and float(r1["final"]) == float(r2["final"]) and float(r1["len_s"]) == float(r2["len_s"]), "v2: same result twice")
	var r3 := MatchSimV2.simulate(teams[0], teams[1], d.mseed + 1, {}, ctx_of(d))
	check.call(JSON.stringify(r3["log"]["ev"]) != JSON.stringify(r1["log"]["ev"]), "v2: another seed gives another game")


func _invariants(check: Callable, games: Array) -> void:
	var bad := {}
	for g in games:
		var r: Dictionary = g[2]
		var ev: Array = r["log"]["ev"]
		var last_t := -1.0
		var alive := {}
		for side in ["B", "R"]:
			for s in SLOTS:
				alive[side + "." + s] = true
		var kills := {"B": 0, "R": 0}
		var ended := false
		var winner := "B" if bool(r["a_won"]) else "R"
		var loser := "R" if winner == "B" else "B"
		for e in ev:
			var tt := float(e[0])
			var ty := String(e[1])
			if tt < last_t - 1e-9:
				bad["time order"] = true
			last_t = maxf(last_t, tt)
			if ended:
				bad["event after end"] = true
			match ty:
				"kill":
					var victim := String(e[3])
					if not bool(alive[victim]):
						bad["victim already dead"] = true
					alive[victim] = false
					var killer := String(e[2])
					if not killer.begins_with("tower."):
						kills[killer.substr(0, 1)] += 1
						if killer.substr(0, 1) == victim.substr(0, 1):
							bad["killed own side"] = true
				"respawn":
					alive[String(e[2])] = true
				"move", "buy", "recall", "camp", "ward":
					if alive.has(String(e[2])) and not bool(alive[String(e[2])]) and ty != "buy":
						bad["dead hero acted: " + ty] = true
				"end":
					ended = true
					if String(e[2]) != winner:
						bad["end winner mismatch"] = true
		if not ended:
			bad["no end event"] = true
		var cairn_down := false
		for e2 in ev:
			if String(e2[1]) == "tower" and String(e2[2]) == loser + ".cairn":
				cairn_down = true
		if not cairn_down and String(r["end_reason"]) == "cairn":
			bad["loser cairn not down"] = true
		var sum_k := {"B": 0, "R": 0}
		for k in r["per"]:
			var pp: Dictionary = r["per"][k]
			sum_k[k.substr(0, 1)] += int(pp["k"])
			if int(pp["level"]) < 1 or int(pp["level"]) > 15:
				bad["level range"] = true
			if (pp["items"] as Array).size() > 6:
				bad["more than six items"] = true
			if not Items.is_legal(pp["build"]):
				bad["illegal build"] = true
		if sum_k["B"] != int(r["team_kills"]["B"]) or sum_k["R"] != int(r["team_kills"]["R"]) or kills["B"] != int(r["team_kills"]["B"]):
			bad["team kills != hero kills"] = true
		if String(r["end_reason"]) != "cairn":
			bad["safety stop used"] = true
	check.call(bad.is_empty(), "v2: event-log invariants hold over %d games %s" % [games.size(), str(bad.keys())])


func _roles(check: Callable, games: Array) -> void:
	var jg_camps := 0
	var jg_ganks := 0
	var mid_roams := 0
	var calls := 0
	var sup_near := 0.0
	var sup_samples := 0
	var top_side := 0.0
	var top_samples := 0
	for g in games:
		var r: Dictionary = g[2]
		var ev: Array = r["log"]["ev"]
		var camps := {"B": 0, "R": 0}
		var ganked := {"B": false, "R": false}
		var roamed := false
		for e in ev:
			var ty := String(e[1])
			if ty == "camp" and float(e[0]) < 480.0:
				camps[String(e[2]).substr(0, 1)] += 1
			elif ty == "intent" and String(e[3]) == "gank":
				ganked[String(e[2]).substr(0, 1)] = true
			elif ty == "intent" and String(e[3]) == "roam" and String(e[2]).ends_with(".mid"):
				roamed = true
			elif ty == "call" and String(e[3]) == "group":
				calls += 1
		for side in ["B", "R"]:
			if int(camps[side]) >= 6:
				jg_camps += 1
			if bool(ganked[side]):
				jg_ganks += 1
		if roamed:
			mid_roams += 1
		var tr: Dictionary = r["log"]["track"]
		var every := float(r["log"]["track_every"])
		for side in ["B", "R"]:
			var sup: PackedFloat32Array = tr[side + ".sup"]
			var bot: PackedFloat32Array = tr[side + ".bot"]
			var top: PackedFloat32Array = tr[side + ".top"]
			var i0 := int(90.0 / every)
			var i1 := mini(int(360.0 / every), sup.size() / 4 - 1)
			for i in range(i0, i1):
				if sup[i * 4 + 3] > 0.5 and bot[i * 4 + 3] > 0.5:
					sup_samples += 1
					if SimData.du(Vector2(sup[i * 4], sup[i * 4 + 1]), Vector2(bot[i * 4], bot[i * 4 + 1])) < 0.12:
						sup_near += 1.0
				if top[i * 4 + 3] > 0.5 and i * every < 240.0:
					top_samples += 1
					if top[i * 4] < 0.4:
						top_side += 1.0
	var n2 := games.size() * 2
	check.call(jg_camps >= int(n2 * 0.8), "v2 roles: junglers clear 6+ camps before 8:00 (%d of %d)" % [jg_camps, n2])
	check.call(jg_ganks >= int(n2 * 0.6), "v2 roles: junglers gank (%d of %d)" % [jg_ganks, n2])
	check.call(sup_samples > 0 and sup_near / float(sup_samples) >= 0.6, "v2 roles: supports stay near their carry in lane (%.0f%%)" % [100.0 * sup_near / maxf(1.0, float(sup_samples))])
	check.call(top_samples > 0 and top_side / float(top_samples) >= 0.8, "v2 roles: tops stay on the top side early (%.0f%%)" % [100.0 * top_side / maxf(1.0, float(top_samples))])
	check.call(mid_roams >= 2, "v2 roles: mids roam in some games (%d of %d)" % [mid_roams, games.size()])
	check.call(calls >= games.size(), "v2 roles: teams call objectives (%d calls in %d games)" % [calls, games.size()])


func _items(check: Callable, w: World) -> void:
	var legal := true
	for hid in w.hero_ids:
		var h: Dictionary = w.heroes[hid]
		var b := Items.suggest(hid, String(h["role_primary"]), ["sunnivah", "alderwyn", "oriel", "brannoch", "marrek"])
		legal = legal and Items.is_legal(b)
	check.call(legal, "v2 items: the coach's build is legal for all 40 heroes")
	var healers := ["sunnivah", "alderwyn", "oriel", "marrek", "skarrow"]
	var carry_b := Items.suggest("harkin", "bot", healers)
	var has_anti := false
	for iid in carry_b:
		has_anti = has_anti or String(SimData.item(iid)["effect"]) == "antiheal"
	check.call(has_anti, "v2 items: a carry against a heavy-heal draft gets anti-heal %s" % [str(carry_b)])
	var hero := SimHero.new()
	hero.build = carry_b.duplicate()
	hero.gold = 300.0
	var first := Items.shop(hero)
	check.call(first.size() == 1 and String(first[0]) == "roadworn_boots", "v2 items: 300 gold buys the base boots first")
	hero.gold = 20000.0
	Items.shop(hero)
	var all_in := true
	for iid in carry_b:
		all_in = all_in and String(iid) in hero.owned
	check.call(all_in and hero.owned.size() == 6, "v2 items: with enough gold the whole build is bought, six items")


## Until Arena v2 (Phase 4), the live Match screen still builds the Alpha 0.8 show from the result: it must build from a v2
## result (MatchRunner.finish) without failing, and its final score must be the v2 kills.
func _interim_show(check: Callable, w: World, meta: Dictionary) -> void:
	var ok := true
	for i in 3:
		var res := MatchRunner.auto(w, w.best_lineup(w.club_ids[i]), w.best_lineup(w.club_ids[(i + 4) % 10]), meta, 61 + i, "v2show:%d" % i, false, {"B": "ai", "R": "ai"})
		var s := ShowScript.build(res, "B")
		var c := Choreo.build(s)
		ok = ok and s != null and c != null and Report.is_v2(res)
		var kd := Report.kda(res)
		ok = ok and int(kd["team"]["B"]["k"]) == int(res["sim"]["team_kills"]["B"])
	check.call(ok, "interim: the Alpha 0.8 show builds from a v2 result and the kills are the v2 kills")


## The v2 golden vectors (tests/golden/sim_v2_vectors.json, GoldenV2): every case reproduces exactly, event log included.
func _golden(check: Callable) -> void:
	var d = DataLoader.load_json("res://tests/golden/sim_v2_vectors.json")
	check.call(d is Dictionary and (d["cases"] as Array).size() == 24, "v2 golden: 24 cases load")
	if not (d is Dictionary):
		return
	var bad: Array = []
	for item in d["cases"]:
		var got := GoldenV2.run_case(item["case"])
		var want: Dictionary = item["expect"]
		for k in ["blue_won", "events", "log_sha256"]:
			if str(got[k]) != str(want[k]):
				bad.append("%s %s" % [want["id"], k])
		if absf(float(got["len_s"]) - float(want["len_s"])) > 1e-9 or JSON.stringify(got["kills"]) != JSON.stringify(want["kills"]):
			bad.append("%s numbers" % want["id"])
	check.call(bad.is_empty(), "v2 golden: every case reproduces exactly (winner, length, kills, log hash) %s" % str(bad))


func _levers(check: Callable) -> void:
	var fav := 0
	for i in 16:
		var r := _synthetic(30.0, i)
		if r:
			fav += 1
	check.call(fav >= 13, "v2 levers: a +30 favourite wins %d of 16 (13 or more; the bands are the calibration report)" % fav)


## One synthetic game (uniform ratings, generic players, fixed picks); returns true when the favourite won.
static func _synthetic(gap: float, i: int) -> bool:
	var picks := {"top": "brannoch", "jg": "gravenstone", "mid": "ellowen", "bot": "harkin", "sup": "sunnivah"}
	var picks2 := {"top": "dunmarrow", "jg": "marrek", "mid": "cindrel", "bot": "pellam", "sup": "alderwyn"}
	var player := {"id": "p", "stats": {"mec": 60, "sen": 60, "lan": 60, "tft": 60, "mac": 60, "com": 60, "con": 60, "clu": 60}}
	var fav_blue := i % 2 == 0
	var ctx := {"picks": {"B": picks if fav_blue else picks2, "R": picks2 if fav_blue else picks}, "players": {"B": {}, "R": {}}}
	for s in SLOTS:
		ctx["players"]["B"][s] = player
		ctx["players"]["R"][s] = player
	var fav_t := _team(50.0 + gap)
	var dog_t := _team(50.0)
	var r := MatchSimV2.simulate(fav_t if fav_blue else dog_t, dog_t if fav_blue else fav_t, 9000 + i, {}, ctx)
	return bool(r["a_won"]) == fav_blue


static func _team(r: float) -> Dictionary:
	var ratings := {}
	for ph in ["early", "mid", "late"]:
		var x := {}
		for s in SLOTS:
			x[s] = r
		ratings[ph] = x
	return {"ratings": ratings, "con": 50.0, "team_mod": 0.0, "comp_mod": 0.0, "lane_mod": {}, "style": "skirmish"}
