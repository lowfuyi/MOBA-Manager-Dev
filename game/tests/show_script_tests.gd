extends RefCounted
## Alpha 0.8 A-01: the arena's show script (ACTION-VOCABULARY 5.4 invariants and section 8), on real results of auto games
## between the league's clubs with AI plans (so plan switches and held fights occur):
##   I1 the ladder ends at final; pressure B - R = final      I2 the winner's gold lead at 75 s is positive
##   I3 kills per side = Report.kda, the winner has more       I4 per-hero kills and deaths from the events = Report.kda
##   I5 T_W > T_U, both <= 6, placed = counted, only the 12 scored tower ids, no tower twice
##   I6 objectives = signs of obj_mid and obj_late            I7 each fight's winner has at least the loser's kills
##   I8 size words are Report.margin_word                     I9 the held fight: l_7 > l_8 > 0, the step is 0.30 |c|, no flip there
##   plus: resolve stamps = Report.FEED_ORDER on the 75 s clock; every kill inside its beat's window; score_at is monotonic;
##   the same result builds the same show (A3); the arena code calls no simulation (A1, a grep).
## Fight pass (Alpha 0.8.1, ACTION-VOCABULARY 11), on the first 60 results:
##   spacing   kills of a beat are 0.4 s apart or in one group (a double or triple kill, steps of at most 0.12 s)
##   arc       the group beats' kill windows equal arena_actions_v1.json; kills lie after the engage and before the fight ends
##   hp        hp_at is 0 exactly while the map has the hero down (Choreo.alive), full just after each rise, never above 1
##   heal      a mender's lift never lands on a hero who is down
##   decisive  empty, or a kill of the game winner from 41.0 to 71.25 s (the late fight's when the winner won it)
##   beat      beat_t is monotonic, equals t outside the 1.8 s after the decisive kill, lands the kill on its moment, ends at 75

const N := 400


func run(check: Callable) -> void:
	var w := World.load_default()
	var meta := w.make_meta("show-test")
	var fails := {}
	var held := 0
	var switched := 0
	var arcs := {}
	var t0 := Time.get_ticks_msec()
	for i in N:
		var a: String = w.club_ids[i % w.club_ids.size()]
		var b: String = w.club_ids[(i * 7 + 3) % w.club_ids.size()]
		if a == b:
			b = w.club_ids[(i + 1) % w.club_ids.size()]
		var plans := {"B": "ai", "R": "ai"}
		if i % 4 == 1:    # a real trigger plan, so plan switches (the plan check) occur in the sample
			var behind := GamePlan.neutral()
			behind["g"] = 100
			plans = {"B": {"default": GamePlan.neutral(), "triggers": [{"when": "behind_early", "plan": behind}, {"when": "ahead_early", "plan": behind}]}, "R": "ai"}
		var res := MatchRunner.auto(w, w.best_lineup(a), w.best_lineup(b), meta, 4242 + i, "show:%d" % i, i % 3 == 0, plans)
		var side := "B" if i % 2 == 0 else "R"
		var s := ShowScript.build(res, side)
		for bad in _invariants(s, res):
			fails[bad] = int(fails.get(bad, 0)) + 1
		if i < 60:
			for bad2 in _fight_pass(s):
				fails[bad2] = int(fails.get(bad2, 0)) + 1
		held += 1 if s.held else 0
		switched += 1 if String(s.plan_used.get("B", "default")) != "default" or String(s.plan_used.get("R", "default")) != "default" else 0
		arcs[s.arc] = int(arcs.get(s.arc, 0)) + 1
		if i < 40:
			var again := ShowScript.build(res, side)
			if JSON.stringify(again.kill_events) != JSON.stringify(s.kill_events) or JSON.stringify(again.towers) != JSON.stringify(s.towers):
				fails["A3 determinism"] = int(fails.get("A3 determinism", 0)) + 1
	print("     show script: %d results in %d ms; held fights %d, plan switches %d, arcs %s" % [N, Time.get_ticks_msec() - t0, held, switched, str(arcs)])
	for name in ["I1", "I2", "I3", "I4", "I5", "I6", "I7", "I8", "I9", "stamps", "windows", "monotonic", "A3 determinism",
			"spacing", "arc", "hp", "heal", "decisive", "beat"]:
		check.call(not fails.has(name), "show script %s holds on %d results (%d failures)" % [name, N, int(fails.get(name, 0))])
	check.call(held > 0 and switched > 0 and arcs.size() >= 3, "the sample has held fights (%d), plan switches (%d) and at least three arcs %s" % [held, switched, str(arcs.keys())])
	_grep(check)
	_worked_example(check)


func _invariants(s: ShowScript, res: Dictionary) -> Array:
	var bad: Array = []
	var final := float(res["final"])
	var w := s.winner
	var u := ShowScript.other(w)
	if absf(float(s.ladder[7]) - final) > 1e-9 or absf(float(s.pressure["B"]) - float(s.pressure["R"]) - final) > 1e-9:
		bad.append("I1")
	if s.gold_at(75.0, w) <= 0:
		bad.append("I2")
	var kd := Report.kda(res)
	var sc := s.score_at(75.0)
	if int(sc["kills"]["B"]) != int(kd["team"]["B"]["k"]) or int(sc["kills"]["R"]) != int(kd["team"]["R"]["k"]) or int(sc["kills"][w]) <= int(sc["kills"][u]):
		bad.append("I3")
	var ht := s.hero_totals()
	for side in ["B", "R"]:
		for slot in ShowScript.SLOTS:
			if int(ht[side][slot]["k"]) != int(kd[side][slot]["k"]) or int(ht[side][slot]["d"]) != int(kd[side][slot]["d"]):
				if not bad.has("I4"):
					bad.append("I4")
	var ids := {}
	var placed := {"B": 0, "R": 0}
	var ok_ids := true
	for t in s.towers:
		placed[t["side"]] = int(placed[t["side"]]) + 1
		var id := String(t["id"])
		ok_ids = ok_ids and not ids.has(id) and not id.contains("guard") and id.split(".").size() == 3 and String(id.split(".")[0]) != String(t["side"])
		ids[id] = true
	if not (int(s.tower_count[w]) > int(s.tower_count[u]) and int(s.tower_count[w]) <= 6 and int(s.tower_count[u]) <= 6 and placed == s.tower_count and ok_ids):
		bad.append("I5")
	if s.objectives["stoneback"] != ("B" if float(res["sim"]["contests"]["obj_mid"]) > 0.0 else "R") or s.objectives["moonhulk"] != ("B" if float(res["sim"]["contests"]["obj_late"]) > 0.0 else "R"):
		bad.append("I6")
	for f in ["fight_mid", "fight_late"]:
		var fwin := String(s.contests[f]["win"])
		if int(s.kills_per_beat[fwin][f]) < int(s.kills_per_beat[ShowScript.other(fwin)][f]):
			if not bad.has("I7"):
				bad.append("I7")
	for k in ShowScript.ORDER:
		if String(s.contests[k]["size"]) != Report.margin_word(float(res["sim"]["contests"][k])):
			if not bad.has("I8"):
				bad.append("I8")
	if s.held:
		var sw := ShowScript.sgn(w)
		var l7 := sw * float(s.ladder[6])
		var l8 := sw * float(s.ladder[7])
		var step := 0.30 * absf(float(res["sim"]["contests"]["fight_late"]))
		var flip_late := s.flips.any(func(f: Dictionary) -> bool: return f["beat"] == "fight_late")
		if not (l7 > l8 and l8 > 0.0 and absf((l7 - l8) - step) < 1e-9 and not flip_late and s.gold_at(70.0, w) > 0):
			bad.append("I9")
	var stamps := [0.18, 0.21, 0.24, 0.27, 0.45, 0.60, 0.80, 0.95]
	for i in ShowScript.ORDER.size():
		if absf(float(s.contests[ShowScript.ORDER[i]]["t"]) - float(stamps[i]) * 75.0) > 1e-6:
			if not bad.has("stamps"):
				bad.append("stamps")
	for e in s.kill_events:
		var win: Array = ShowScript.KILL_WINDOW[e["beat"]]
		if float(e["t"]) < float(win[0]) - 1e-9 or float(e["t"]) > float(win[1]) + 1e-9:
			if not bad.has("windows"):
				bad.append("windows")
	var prev := s.score_at(0.0)
	for k in 76:
		var cur := s.score_at(float(k))
		for side in ["B", "R"]:
			if int(cur["kills"][side]) < int(prev["kills"][side]) or int(cur["towers"][side]) < int(prev["towers"][side]):
				if not bad.has("monotonic"):
					bad.append("monotonic")
		prev = cur
	return bad


func _fight_pass(s: ShowScript) -> Array:
	var bad: Array = []
	var sp: Dictionary = ArenaActions.data()["spacing"]
	var by_beat := {}
	for e in s.kill_events:
		if not by_beat.has(e["beat"]):
			by_beat[e["beat"]] = []
		by_beat[e["beat"]].append(e)
	for k in by_beat:
		var ev: Array = by_beat[k]
		for j in range(1, ev.size()):
			var dt := float(ev[j]["t"]) - float(ev[j - 1]["t"])
			var same := int(ev[j]["g"]) == int(ev[j - 1]["g"])
			if not ((not same and dt >= float(sp["min_gap_s"]) - 1e-6) or (same and dt <= float(sp["multi_step_s"]) + 1e-6 and dt >= 0.0)):
				if not bad.has("spacing"):
					bad.append("spacing")
	var fights: Dictionary = ArenaActions.data()["fights"]
	for k2 in fights:
		var kw: Array = fights[k2]["kills"]
		var ok := absf(float(ShowScript.KILL_WINDOW[k2][0]) - float(kw[0])) < 1e-9 and absf(float(ShowScript.KILL_WINDOW[k2][1]) - float(kw[1])) < 1e-9
		ok = ok and float(kw[0]) >= float(fights[k2]["engage_to"]) and float(kw[1]) <= float(fights[k2]["fight_to"])
		if not ok and not bad.has("arc"):
			bad.append("arc")
	var c := Choreo.build(s)
	for key in c.heroes:
		var t := 0.0
		while t < 75.0:
			var h := s.hp_at(key, t)
			if (h <= 0.0) == c.alive(key, t) or h > 1.0 + 1e-9:
				if not bad.has("hp"):
					bad.append("hp")
			t += 0.1
		for d in c.heroes[key]["deaths"]:
			var up_after := c.alive(key, float(d["rise"]) + 0.01)    # a hero can fall again at once after rising (the ledger's pairing)
			if (up_after and s.hp_at(key, float(d["rise"]) + 0.01) < 0.999) or s.hp_at(key, float(d["t"])) != 0.0:
				if not bad.has("hp"):
					bad.append("hp")
	for e2 in s.heals:
		if not c.alive(String(e2["ally"]), float(e2["t"])) or not c.alive(String(e2["by"]), float(e2["t"])):
			if not bad.has("heal"):
				bad.append("heal")
	var dk := s.decisive
	if not dk.is_empty():
		var okd := String(dk["side"]) == s.winner and float(dk["t"]) >= 41.0 and float(dk["t"]) <= 71.25 and s.kill_events.has(dk)
		if not s.held and s.kill_events.any(func(e3: Dictionary) -> bool: return String(e3["side"]) == s.winner and String(e3["beat"]) == "fight_late"):
			okd = okd and String(dk["beat"]) == "fight_late"
		if not okd:
			bad.append("decisive")
		var prev := -1.0
		var t2 := 0.0
		while t2 <= 75.0:
			var b := s.beat_t(t2)
			if b < prev - 1e-9 or (absf(b - t2) > 1e-9 and (t2 < float(dk["t"]) or t2 > float(dk["t"]) + 1.8)):
				if not bad.has("beat"):
					bad.append("beat")
			prev = b
			t2 += 0.01
		if absf(s.beat_t(float(dk["t"])) - float(dk["t"])) > 1e-9 or absf(s.beat_t(75.0) - 75.0) > 1e-9 or s.beat_t(50.0, false) != 50.0:
			if not bad.has("beat"):
				bad.append("beat")
	return bad


## A1: the arena never asks the simulation for an outcome and never writes the result.
func _grep(check: Callable) -> void:
	var d := DirAccess.open("res://src/arena")
	var bad: Array = []
	var n := 0
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		n += 1
		var text := ""
		for line in FileAccess.get_file_as_string("res://src/arena/" + f).split("\n"):
			if not line.strip_edges().begins_with("#"):
				text += line.split("#")[0] + "\n"    # code only: comments may name what the arena must not call
		for needle in ["MatchSim.", "GamePlan.simulate", "Report.attribution", "res[\"final\"] =", "res[\"sim\"] =", "randf(", "randi(", "randomize("]:
			if text.contains(needle):
				bad.append("%s: %s" % [f, needle])
	check.call(n >= 1 and bad.is_empty(), "A1/A2: the arena code calls no simulation, writes no result and uses no engine random (%d files) %s" % [n, str(bad)])


## Hamilton and the gold easing on fixed numbers.
func _worked_example(check: Callable) -> void:
	check.call(ShowScript.hamilton(5, [0.2, 0.0, 0.5, 0.3]) == [1, 0, 3, 1] or ShowScript.hamilton(5, [0.2, 0.0, 0.5, 0.3]) == [1, 0, 2, 2], "Hamilton gives 5 units by largest remainders (%s)" % str(ShowScript.hamilton(5, [0.2, 0.0, 0.5, 0.3])))
	check.call(ShowScript.hamilton(3, [0.0, 0.0]) == [3, 0], "Hamilton with no weight gives everything to the first beat")
	check.call(is_equal_approx(ShowScript.ease01(0.5), 0.5) and ShowScript.ease01(-1.0) == 0.0 and ShowScript.ease01(2.0) == 1.0, "ease01 eases from 0 to 1")
