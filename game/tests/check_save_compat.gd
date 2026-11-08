extends Node
## Save compatibility (build plan section 5, item 7). Loads real Alpha 0.6 saves (tests/fixtures/save_0_6_*.json,
## written by the 0.6 code, no "tutorial" key) through GameState.from_dict, then plays on: plans_for, next_game, a
## full game, a JSON round trip (what the real save and load do), the rest of the season, next_season, and a reload.
## Also runs a save that claims a newer tutorial schema (tutorial.v = 99), which must never crash a build.
## Headless: godot --headless res://tests/check_save_compat.tscn  (ends with " N checks, 0 failures")
##
## The "tutorial" key does not exist before I-06. Until then a missing key counts as {"state": "legacy"}; once
## GameState writes the key, the same checks require it to be "legacy" and to survive next_season().

const FIXTURES := ["save_0_6_a.json", "save_0_6_b.json", "save_0_6_c.json", "save_0_6_d.json"]
const TUTORIAL_STATE_SCRIPT := "res://src/tutorial/tutorial_state.gd"

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _ready() -> void:
	await get_tree().process_frame
	for f in FIXTURES:
		_one(f, false)
	_one("save_0_6_b.json", true)
	_future_tutorial_state()
	print("save compat: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _read(name: String) -> Dictionary:
	var f := FileAccess.open("res://tests/fixtures/" + name, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


## The tutorial state a build would act on: a missing key is a legacy save.
func _tutorial_state(gs: GameState) -> String:
	var t = gs.d.get("tutorial", {"v": 1, "state": "legacy"})
	return String((t as Dictionary).get("state", "legacy")) if t is Dictionary else "legacy"


func _one(name: String, future_v: bool) -> void:
	var label := name + (" (tutorial.v=99)" if future_v else "")
	var data := _read(name)
	ok(not data.is_empty(), label + ": fixture file reads")
	if data.is_empty():
		return
	ok(int(data.get("version", 0)) == GameState.VERSION, label + ": fixture version matches GameState.VERSION (no bump)")
	ok(not data.has("tutorial"), label + ": fixture is a real 0.6 save (no tutorial key)")
	if future_v:
		data["tutorial"] = {"v": 99, "state": "running", "step": "no_such_step", "game": {"live": true, "n": 3, "plan": {}}}
	var w := World.load_default()
	var gs := GameState.from_dict(w, data)
	ok(gs.club() == String(data["club"]), label + ": club kept")
	ok(gs.roster_players().size() == 10, label + ": roster of 10")
	if not future_v:
		ok(_tutorial_state(gs) == "legacy", label + ": tutorial state is legacy after load")
	var phase_in := String(gs.d["phase"])

	# a game, if one is due
	var g := gs.next_game()
	if phase_in == "done":
		ok(g.is_empty(), label + ": no game due at season end")
	else:
		ok(not g.is_empty(), label + ": a game is due")
		var plans := gs.plans_for(g)
		var mine := "B" if g["blue"] == gs.club() else "R"
		ok((plans[mine] as Dictionary).has("default"), label + ": plans_for gives the saved plan set")
		var played_before := _played(gs)
		var res := gs.auto_game(g)
		ok(res.has("final") and res.has("blue_won"), label + ": a full game plays")
		gs.record_human_game(g, res)
		ok(_played(gs) > played_before, label + ": the game is recorded")
		ok(gs.next_game().is_empty() or gs.next_game()["id"] != g["id"], label + ": the next game is a different one")

	# the real save path: stringify, parse, from_dict
	var gs2 := _roundtrip(gs)
	ok(gs2 != null and String(gs2.d["phase"]) == String(gs.d["phase"]) and int(gs2.d["round"]) == int(gs.d["round"]), label + ": round trip keeps phase and round")
	ok(gs2 != null and _played(gs2) == _played(gs), label + ": round trip keeps the results")
	if gs2 == null:
		return
	if not future_v:
		ok(_tutorial_state(gs2) == "legacy", label + ": tutorial state is legacy after a save and reload")
	gs = gs2

	# the rest of the season and into the next one
	gs.autoplay(true)
	ok(String(gs.d["phase"]) == "done", label + ": the season finishes (%s)" % gs.d["phase"])
	ok(String(gs.d["champion"]) != "", label + ": a champion is named")
	var prev_season := int(gs.d["season"])
	var done_seasons := (gs.d["seasons_done"] as Array).size()
	var tut_before := _tutorial_state(gs)
	var nxt := gs.next_season()
	ok(nxt != null and int(nxt.d["season"]) == prev_season + 1, label + ": next_season starts the next season")
	ok(done_seasons >= 1 and (nxt.d["seasons_done"] as Array).size() == done_seasons, label + ": season history carried (%d entries)" % done_seasons)
	ok(String(nxt.d["phase"]) == "league" and int(nxt.d["round"]) == 0, label + ": new season opens at round 0 of the league")
	ok(not nxt.next_game().is_empty(), label + ": the new season has a game")
	ok(nxt.roster_players().size() >= 1 and nxt.cash() > -1.0e9, label + ": roster and cash carried")
	if not future_v:
		ok(_tutorial_state(nxt) == "legacy", label + ": tutorial state is legacy after next_season (carried)")
	var gs3 := _roundtrip(nxt)
	ok(gs3 != null and int(gs3.d["season"]) == prev_season + 1, label + ": reload of the new season")
	if gs3 != null:
		var g3 := gs3.next_game()
		ok(not g3.is_empty() and gs3.auto_game(g3).has("final"), label + ": the reloaded new season plays a game")
		if not future_v:
			ok(_tutorial_state(gs3) == "legacy", label + ": still legacy after the second reload")
	if tut_before != "legacy" and not future_v:
		ok(false, label + ": unexpected tutorial state " + tut_before)


## What a save and load does: JSON text out, JSON text in, from_dict. A fresh World each time, as at app start.
func _roundtrip(gs: GameState) -> GameState:
	var text := JSON.stringify(gs.d)
	var data = JSON.parse_string(text)
	if not (data is Dictionary):
		return null
	ok(int((data as Dictionary).get("version", 0)) == GameState.VERSION, "round trip keeps the version field (load_save would accept it)")
	return GameState.from_dict(World.load_default(), data)


func _played(gs: GameState) -> int:
	var n := 0
	for f in gs.d["fixtures"]:
		if f["played"]:
			n += 1
	return n


## From I-11 on: TutorialState.migrate exists, and a future schema must come back as legacy. Before that, skipped.
func _future_tutorial_state() -> void:
	if not ResourceLoader.exists(TUTORIAL_STATE_SCRIPT):
		print("note: ", TUTORIAL_STATE_SCRIPT, " not present yet (I-11); migrate checks skipped")
		return
	var scr: Script = load(TUTORIAL_STATE_SCRIPT)
	ok(scr.has_method("migrate"), "TutorialState.migrate exists")
	if not scr.has_method("migrate"):
		return
	var future: Dictionary = {"v": 99, "state": "running", "step": "x"}
	var out: Dictionary = scr.call("migrate", future)
	ok(String(out.get("state", "")) == "legacy", "tutorial.v = 99 is treated as legacy")
	ok(int(future["v"]) == 99 and String(future["state"]) == "running", "the future save's tutorial dictionary is not modified")
	var bad: Dictionary = scr.call("migrate", {"v": 1, "state": "weird"})
	ok(String(bad.get("state", "")) == "legacy", "a malformed state falls back to legacy")
