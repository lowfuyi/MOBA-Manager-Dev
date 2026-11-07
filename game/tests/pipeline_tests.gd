class_name PipelineTests
extends RefCounted
## Golden checks for the rating, composition and draft port (vectors from tools/gen_golden_pipeline.py).

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
var _check: Callable


func run(check: Callable) -> void:
	_check = check
	var g = DataLoader.load_json("res://tests/golden/pipeline_vectors.json")
	_check.call(g is Dictionary, "pipeline golden loads")
	if not (g is Dictionary):
		return
	var w := World.load_default()
	_fam(w, g)
	_meta(w, g)
	_lineups(w, g)
	_comp(w, g)
	_drafts(w, g)


func _near(a: float, b: float, tol: float = 1e-9) -> bool:
	return absf(a - b) <= tol * maxf(1.0, absf(b))


func _fam(w: World, g: Dictionary) -> void:
	for c in g["fam"]:
		var v: float = w.base_familiarity(w.players[c["player"]], c["hero"])
		_check.call(_near(v, float(c["value"])), "familiarity %s/%s" % [c["player"], c["hero"]])


func _meta(w: World, g: Dictionary) -> void:
	var m: Dictionary = w.make_meta(g["meta"]["seed"])
	for hid in g["meta"]["values"]:
		_check.call(_near(float(m[hid]), float(g["meta"]["values"][hid])), "meta " + hid)


func _lineups(w: World, g: Dictionary) -> void:
	for cid in g["lineups"]:
		var lu: Dictionary = w.best_lineup(cid)
		var exp: Dictionary = g["lineups"][cid]["slots"]
		var ok := true
		for s in SLOTS:
			ok = ok and lu[s]["id"] == exp[s]
		_check.call(ok, "best lineup " + cid)
		_check.call(_near(w.team_rating(lu), float(g["lineups"][cid]["team_rating"])), "team rating " + cid)


func _comp(w: World, g: Dictionary) -> void:
	var i := 0
	for c in g["comp"]:
		var hs: Array = []
		for hid in c["heroes"]:
			hs.append(w.heroes[hid])
		var r: Dictionary = Comp.evaluate(hs)
		_check.call(_near(float(r["mod"]), float(c["mod"])) and r["style"] == c["style"], "comp_eval #%d" % i)
		_check.call(_near(float(r["parts"]["synergy"]), float(c["synergy"])) and _near(float(r["parts"]["needs"]), float(c["needs"])), "comp parts #%d" % i)
		i += 1
	i = 0
	for c in g["progress"]:
		var hs: Array = []
		for hid in c["heroes"]:
			hs.append(w.heroes[hid])
		_check.call(_near(Comp.progress(hs), float(c["value"])), "progress #%d" % i)
		i += 1


func _drafts(w: World, g: Dictionary) -> void:
	var meta: Dictionary = w.make_meta(g["meta"]["seed"])
	var human_cases := 0
	for c in g["drafts"]:
		var id: String = c["match_id"]
		var d := MatchRunner.prepare(w, w.best_lineup(c["blue"]), w.best_lineup(c["red"]), meta, int(c["save_seed"]), id, bool(c["full"]))
		var human: Dictionary = c["human"]
		if not human.is_empty():
			human_cases += 1
		var guard := 0
		while not d.is_done() and guard < 40:
			guard += 1
			var cur: Dictionary = d.current()
			var key := str(cur["n"])
			var ok := false
			if human.has(key):
				ok = d.apply_ban(human[key]) if cur["kind"] == "ban" else d.apply_pick(human[key][0], human[key][1])
			else:
				ok = d.apply(d.ai_choice())
			if not ok:
				_check.call(false, "draft step %s refused in %s" % [key, id])
				break
		if not d.is_done():
			continue
		var same: bool = d.log.size() == (c["log"] as Array).size()
		if same:
			for i in d.log.size():
				var a: Dictionary = d.log[i]
				var b: Dictionary = c["log"][i]
				if a["team"] != b["team"] or a["kind"] != b["kind"] or a["hero"] != b["hero"] or a["slot"] != b["slot"]:
					same = false
					break
		_check.call(same, "draft log " + id)
		var r: Dictionary = MatchRunner.finish(w, d)
		_check.call(_near(float(r["final"]), float(c["final"]), 1e-9) and bool(r["blue_won"]) == bool(c["a_won"]), "play final " + id)
		_check.call(_near(float(r["comp"]["B"]), float(c["comp_b"])) and _near(float(r["comp"]["R"]), float(c["comp_r"])), "comp mods " + id)
		_check.call(r["style"]["B"] == c["style_b"] and r["style"]["R"] == c["style_r"], "styles " + id)
		var lane_ok: bool = (r["team_a"]["lane_mod"] as Dictionary).size() == (c["lane_b"] as Dictionary).size()
		for k in c["lane_b"]:
			lane_ok = lane_ok and r["team_a"]["lane_mod"].has(k)
		_check.call(lane_ok, "lane mods " + id)
		_check.call(_near(float(r["team_a"]["ratings"]["early"]["mid"]), float(c["early_b"]["mid"])) and _near(float(r["team_b"]["ratings"]["late"]["sup"]), float(c["late_r"]["sup"])), "ratings " + id)
	_check.call(human_cases >= 8, "enough human-step cases (%d)" % human_cases)
