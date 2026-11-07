extends SceneTree
## Headless test runner. Run from the game/ folder:
##   godot --headless --script res://tests/run_tests.gd
## Exit code 0 = all passed, 1 = at least one failure.
## STATUS: written but NOT YET RUN in Godot (see company/TASKBOARD.md, P-001).

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_rng_golden()
	_test_sim_golden()
	_test_strings()
	_test_data()
	PipelineTests.new().run(_check)
	GameTests.new().run(_check)
	print("checks: %d, failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FAIL: " + label)


func _join(h: Dictionary) -> int:
	return (int(h["hi"]) << 32) | int(h["lo"])


func _test_rng_golden() -> void:
	var golden = DataLoader.load_json("res://tests/golden/rng_vectors.json")
	_check(golden is Dictionary, "golden file loads")
	if not (golden is Dictionary):
		return
	for c in golden["cases"]:
		var name: String = c["name"]
		match c["kind"]:
			"u32":
				var g := Pcg32.new().seed_rng(_join(c["initstate"]), _join(c["initseq"]))
				for i in c["u32"].size():
					_check(g.next_u32() == int(c["u32"][i]), name + " u32 #%d" % i)
			"float":
				var g := Pcg32.new().seed_rng(_join(c["initstate"]), _join(c["initseq"]))
				for i in c["floats"].size():
					_check(is_equal_approx(g.next_float(), float(c["floats"][i])), name + " float #%d" % i)
			"normal":
				var g := Pcg32.new().seed_rng(_join(c["initstate"]), _join(c["initseq"]))
				for i in c["normals"].size():
					_check(absf(g.next_normal() - float(c["normals"][i])) < float(c["tolerance"]), name + " normal #%d" % i)
			"hash":
				_check(Pcg32.fnv1a64(c["text"]) == _join(c["fnv1a64"]), name + " fnv")
				_check(Pcg32.splitmix64(Pcg32.fnv1a64(c["text"])) == _join(c["splitmix64_of_fnv"]), name + " splitmix")
			"match_seed":
				_check(Pcg32.match_seed(_join(c["save_seed"]), c["match_id"]) == _join(c["match_seed"]), name)
			"contest":
				var g := Pcg32.contest_stream(_join(c["match_seed"]), c["contest_id"])
				for i in c["u32"].size():
					_check(g.next_u32() == int(c["u32"][i]), name + " u32 #%d" % i)


func _close(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _test_sim_golden() -> void:
	var golden = DataLoader.load_json("res://tests/golden/sim_vectors.json")
	_check(golden is Dictionary, "sim golden loads")
	if not (golden is Dictionary):
		return
	var p := MatchSim.load_params()
	_check(not p.is_empty(), "sim params load")
	var save_seed := _join(golden["save_seed"])
	var tol := float(golden["tolerance"])
	var i := 0
	for c in golden["cases"]:
		var label := "sim case %d (%s)" % [i, c["match_id"]]
		i += 1
		var r := MatchSim.simulate(c["team_a"], c["team_b"], Pcg32.match_seed(save_seed, c["match_id"]), p)
		var e: Dictionary = c["expect"]
		_check(r["a_won"] == e["a_won"], label + " winner")
		for k in ["final", "early", "mid", "late"]:
			_check(_close(r[k], float(e[k]), tol), label + " " + k)
		for k in e["contests"]:
			_check(_close(r["contests"][k], float(e["contests"][k]), tol), label + " contest " + k)
		for k in e["noise"]:
			_check(_close(r["noise"][k], float(e["noise"][k]), tol), label + " noise " + k)


func _test_strings() -> void:
	var s = load("res://src/core/strings.gd").new()
	_check(s.load_language("en"), "english table loads")
	_check(s.t("common.ok") == "OK", "known key")
	_check(s.t("no.such.key") == "[[no.such.key]]", "missing key is visible")
	_check(s.f("match.result.won", {"team": "A", "score": "2-1"}) == "A won 2-1", "placeholder fill")
	s.free()


func _test_data() -> void:
	var heroes = DataLoader.load_json("res://data/samples/heroes.sample.json")
	_check(heroes is Array and heroes.size() > 0, "sample heroes load")
	for h in heroes:
		_check(DataLoader.hero_errors(h).is_empty(), "hero valid: " + str(h.get("id")))
	var players = DataLoader.load_json("res://data/samples/players.sample.json")
	_check(players is Array and players.size() > 0, "sample players load")
	for p in players:
		_check(DataLoader.player_errors(p).is_empty(), "player valid: " + str(p.get("id")))

	# the real generated league (tools/gen_heroes.py, tools/gen_players.py)
	var all_heroes = DataLoader.load_json("res://data/heroes.json")
	_check(all_heroes is Array and all_heroes.size() == 40, "40 heroes load")
	var by_id := {}
	for h in all_heroes:
		by_id[h["id"]] = h
		_check(DataLoader.hero_errors(h).is_empty(), "hero valid: " + str(h.get("id")))
	for h in all_heroes:
		for t in h["strong_vs"]:
			_check(by_id.has(t), "counter target exists: " + str(t))
	var all_players = DataLoader.load_json("res://data/players.json")
	_check(all_players is Array and all_players.size() == 140, "140 players load")
	var pid := {}
	for p in all_players:
		pid[p["id"]] = p
		_check(DataLoader.player_errors(p).is_empty(), "player valid: " + str(p.get("id")))
	var clubs = DataLoader.load_json("res://data/clubs.json")
	_check(clubs is Array and clubs.size() == 10, "10 clubs load")
	for c in clubs:
		_check(c["player_ids"].size() == 10, "club roster size: " + str(c["id"]))
		for i in c["player_ids"]:
			_check(pid.has(i) and pid[i]["club"] == c["id"], "roster link: " + str(i))
