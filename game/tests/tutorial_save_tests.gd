extends RefCounted
## I-06 the tutorial save key (build plan 0.7 section 5, items 2 to 5, 9 and 10; v1.1 items 3 and 10):
##  - GameState.new_game() writes state "new" (step welcome, game.n 0, live false); a missing key is "legacy"
##  - the four 0.6 fixtures (a to d) read "legacy"; tutorial.v = 99 reads "legacy" and the save keeps it untouched
##  - a fresh save through a temporary save file, and through JSON.stringify(gs.d) then from_dict, stays "new"
##  - next_season() carries the key in all five states; Delete save and start over then new_game() gives "new" again
##  - TutorialState.migrate: the resume rule at every one of the 27 steps, malformed input, unknown steps
## Headless: no autoloads, nothing here touches UI classes. Auto-discovered by run_tests.gd (run(check)).

const CLUB := "ironquill_wolves"
const FIXTURES := ["save_0_6_a.json", "save_0_6_b.json", "save_0_6_c.json", "save_0_6_d.json"]
const LEGACY := {"v": 1, "state": "legacy"}


func run(check: Callable) -> void:
	var w := World.load_default()
	_new_game(check, w)
	_fresh_save_file(check, w)
	_fixtures(check)
	_future_v(check)
	_accessors(check, w)
	_migrate_resume(check)
	_migrate_edges(check)
	_next_season(check)


func _roundtrip(gs: GameState) -> GameState:
	var data = JSON.parse_string(JSON.stringify(gs.d))   # what GameState.save() writes; there is no to_dict
	return GameState.from_dict(World.load_default(), data) if data is Dictionary else null


func _fixture(name: String) -> Dictionary:
	var f := FileAccess.open("res://tests/fixtures/" + name, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


func _is_new_shape(t: Dictionary) -> bool:
	return int(t.get("v", 0)) == 1 and t.get("state") == "new" and t.get("step") == "welcome" \
			and t.get("game") is Dictionary and int(t["game"].get("n", -1)) == 0 and t["game"].get("live") == false \
			and (t["game"].get("plan") as Dictionary).is_empty()


# ------------------------------------------------------------------ a brand-new 0.7 save
func _new_game(check: Callable, w: World) -> void:
	var gs := GameState.new_game(w, CLUB, 80701)
	var t := gs.tutorial()
	check.call(gs.d.has("tutorial"), "new_game writes the tutorial key")
	check.call(_is_new_shape(t), "new_game: state new, step welcome, game.n 0, game.live false, empty plan")
	check.call(JSON.stringify(t) == JSON.stringify(TutorialState.new_state()), "new_game writes exactly TutorialState.new_state()")
	t["state"] = "done"
	check.call(gs.tutorial()["state"] == "new", "tutorial() returns a copy: changing it does not change the save")
	var again := GameState.new_game(w, CLUB, 80702)
	again.d["tutorial"]["game"]["n"] = 5
	check.call(int(GameState.new_game(w, CLUB, 80703).tutorial()["game"]["n"]) == 0, "each new_game gets its own tutorial dictionary (no shared default)")
	# a reload of a brand-new save never turns it into legacy
	var gs2 := _roundtrip(gs)
	check.call(gs2 != null and _is_new_shape(gs2.tutorial()), "JSON.stringify(gs.d), parse, from_dict: still new, game.n 0 (an int)")
	check.call(gs2 != null and typeof(gs2.d["tutorial"]["game"]["n"]) == TYPE_INT and typeof(gs2.d["tutorial"]["v"]) == TYPE_INT, "after a reload v and game.n are ints again")


# ------------------------------------------------------------------ fresh save through the real file
## GameState.SAVE_PATH is a constant (user://save.json), so the test keeps whatever is there, uses the path, and puts it back.
func _fresh_save_file(check: Callable, w: World) -> void:
	var had := FileAccess.file_exists(GameState.SAVE_PATH)
	var kept := PackedByteArray()
	if had:
		kept = FileAccess.get_file_as_bytes(GameState.SAVE_PATH)
	var gs := GameState.new_game(w, CLUB, 80704)
	check.call(gs.save(), "fresh save: save() writes the file")
	check.call(GameState.has_save(), "fresh save: has_save() is true")
	var loaded := GameState.load_save(World.load_default())
	check.call(loaded != null, "fresh save: load_save() reads it back")
	if loaded != null:
		var t := loaded.tutorial()
		check.call(t["state"] == "new" and t["step"] == "welcome", "fresh save: reads new at step welcome after save and load_save (not legacy)")
		check.call(int(t["game"]["n"]) == 0 and t["game"]["live"] == false, "fresh save: game.n 0 and game.live false after load_save")
		check.call(loaded.club() == CLUB and int(loaded.d["round"]) == 0, "fresh save: the club and round are kept")
	# a running tutorial is written with the autosave, with live cleared by the resume rule at load
	gs.set_tutorial({"v": 1, "state": "running", "step": "pick", "game": {"live": true, "n": 2, "plan": {"x": 1}}})
	gs.save()
	var l2 := GameState.load_save(World.load_default())
	var t2 := l2.tutorial() if l2 != null else {}
	check.call(t2.get("state") == "running" and t2.get("step") == "tab_plan" and t2["game"]["live"] == false and (t2["game"]["plan"] as Dictionary).is_empty() and int(t2["game"]["n"]) == 2,
			"killed mid-draft: a reload resumes at tab_plan, live false, plan emptied, game.n kept (2)")
	# Delete save and start over: the save is gone, the next new_game() writes new again
	GameState.delete_save()
	check.call(not GameState.has_save() and GameState.load_save(World.load_default()) == null, "delete save: nothing left to load")
	var gs3 := GameState.new_game(w, "duskwater_foxes", 80705)
	check.call(_is_new_shape(gs3.tutorial()), "delete save and start over, then new_game: new again")
	# put the tester's own file back
	if had:
		var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(kept)
	else:
		GameState.delete_save()


# ------------------------------------------------------------------ the four 0.6 fixtures
func _fixtures(check: Callable) -> void:
	for name in FIXTURES:
		var data := _fixture(name)
		check.call(not data.is_empty() and not data.has("tutorial"), name + ": a real 0.6 save, no tutorial key")
		if data.is_empty():
			continue
		var gs := GameState.from_dict(World.load_default(), data)
		check.call(gs.tutorial()["state"] == "legacy", name + ": reads legacy (including the 0.6 brand-new game)")
		check.call(JSON.stringify(gs.d["tutorial"]) == JSON.stringify(LEGACY), name + ": from_dict writes {v 1, state legacy} for the missing key")
		var gs2 := _roundtrip(gs)
		check.call(gs2 != null and gs2.tutorial()["state"] == "legacy", name + ": still legacy after save and reload")
		check.call(gs2 != null and gs2.club() == String(data["club"]) and gs2.roster_players().size() == 10, name + ": loads and keeps club and roster")


# ------------------------------------------------------------------ a save from a newer build
func _future_v(check: Callable) -> void:
	var data := _fixture("save_0_6_b.json")
	var future := {"v": 99, "state": "running", "step": "no_such_step", "game": {"live": true, "n": 3, "plan": {"k": "v"}}}
	data["tutorial"] = future.duplicate(true)
	var gs := GameState.from_dict(World.load_default(), data)
	check.call(gs.tutorial()["state"] == "legacy", "tutorial.v = 99 reads legacy")
	check.call(JSON.stringify(gs.d["tutorial"]) == JSON.stringify(future), "tutorial.v = 99: the save's own dictionary is left untouched by from_dict")
	var gs2 := _roundtrip(gs)
	check.call(gs2 != null and gs2.tutorial()["state"] == "legacy" and int(gs2.d["tutorial"]["v"]) == 99, "tutorial.v = 99: still legacy and still 99 after a save and reload (a newer build can read it back)")
	var m := TutorialState.migrate(future)
	check.call(m["state"] == "legacy" and int(future["v"]) == 99 and future["state"] == "running" and future["game"]["live"] == true, "migrate(v 99) returns legacy and does not modify its argument")
	check.call(TutorialState.migrate({"v": 2, "state": "done"})["state"] == "legacy", "migrate(v 2): any higher v is legacy")


# ------------------------------------------------------------------ tutorial() and set_tutorial()
func _accessors(check: Callable, w: World) -> void:
	var gs := GameState.new_game(w, CLUB, 80706)
	var run_t := {"v": 1, "state": "running", "step": "tab_plan", "game": {"live": false, "n": 1, "plan": {}}}
	check.call(gs.set_tutorial(run_t), "set_tutorial accepts a valid state")
	check.call(gs.tutorial()["state"] == "running" and gs.tutorial()["step"] == "tab_plan", "set_tutorial then tutorial() reads it back")
	run_t["step"] = "changed_later"
	check.call(gs.tutorial()["step"] == "tab_plan", "set_tutorial stores a copy")
	check.call(not gs.set_tutorial({"v": 1, "state": "bogus"}) and gs.tutorial()["state"] == "running", "set_tutorial refuses an invalid state and changes nothing")
	check.call(not gs.set_tutorial({}), "set_tutorial refuses an empty dictionary")
	# the live game's step is not rewound by reading: tutorial() never applies the resume rule
	gs.set_tutorial({"v": 1, "state": "running", "step": "pick", "game": {"live": true, "n": 1, "plan": {"a": 1}}})
	check.call(gs.tutorial()["step"] == "pick" and gs.tutorial()["game"]["live"] == true, "tutorial() in a live game does not rewind the step (resume applies on load only)")
	# a key that is not a dictionary (damaged save) reads legacy, and from_dict repairs it
	var data := _fixture("save_0_6_a.json")
	data["tutorial"] = "oops"
	check.call(GameState.from_dict(World.load_default(), data).tutorial()["state"] == "legacy", "a damaged tutorial key reads legacy")
	var data2 := _fixture("save_0_6_a.json")
	data2["tutorial"] = {"v": 1, "state": "weird"}
	check.call(GameState.from_dict(World.load_default(), data2).tutorial()["state"] == "legacy", "a malformed state in a save reads legacy")


# ------------------------------------------------------------------ migrate: the resume rule
func _migrate_resume(check: Callable) -> void:
	# TUTORIAL 3.1 and plan section 5 item 10: chapters 3 to 5 (steps 7 to 20) resume at tab_plan, chapter 6 (21 to 23) and
	# chapter 7 at tab_club, chapter 2 at tab_squad, chapter 1 at home_card. live is false afterwards and the plan is empty.
	check.call(TutorialState.STEP_IDS.size() == 27 and TutorialState.CHAPTER_OF.size() == 27, "27 steps, 27 chapter entries")
	var all_ok := true
	var n_ok := true
	var input_ok := true
	var idem_ok := true
	var bad := []
	for i in 27:
		var id: String = TutorialState.STEP_IDS[i]
		var step := i + 1
		for live in [false, true]:
			var t := {"v": 1, "state": "running", "step": id, "game": {"live": live, "n": 4, "plan": {"fights": 1}}}
			var before := JSON.stringify(t)
			var m := TutorialState.migrate(t)
			var want := ""
			if step >= 21:
				want = "tab_club"
			elif step >= 7 or live:
				want = "tab_plan"
			elif step >= 5:
				want = "tab_squad"
			else:
				want = "home_card"
			if m["step"] != want or m["state"] != "running" or m["game"]["live"] != false or not (m["game"]["plan"] as Dictionary).is_empty():
				all_ok = false
				bad.append("%s live=%s -> %s" % [id, live, m["step"]])
			n_ok = n_ok and int(m["game"]["n"]) == 4
			input_ok = input_ok and JSON.stringify(t) == before
			# loading twice without playing settles at once, except chapter 2: its resume step (tab_squad) is itself
			# a chapter 1 step, so a second load goes to home_card (TUTORIAL 3.1 as written); a third changes nothing
			var m2 := TutorialState.migrate(m)
			idem_ok = idem_ok and JSON.stringify(TutorialState.migrate(m2)) == JSON.stringify(m2)
	check.call(all_ok, "migrate: resume rule at all 27 steps, live true and false " + str(bad))
	check.call(n_ok, "migrate: game.n is never changed by a resume (same game, same seed id)")
	check.call(input_ok, "migrate does not modify its argument")
	check.call(idem_ok, "migrate settles: a third load of the same save changes nothing")
	# spot checks named in the plan: steps 12, 18 and 21
	var s12 := TutorialState.migrate({"v": 1, "state": "running", "step": "ban", "game": {"live": true, "n": 1, "plan": {}}})
	var s18 := TutorialState.migrate({"v": 1, "state": "running", "step": "start_match", "game": {"live": true, "n": 1, "plan": {"a": 1}}})
	var s21 := TutorialState.migrate({"v": 1, "state": "running", "step": "result", "game": {"live": true, "n": 1, "plan": {"a": 1}}})
	check.call(s12["step"] == "tab_plan" and s18["step"] == "tab_plan" and s21["step"] == "tab_club", "steps 12 and 18 resume at tab_plan, step 21 at tab_club")
	check.call(TutorialState.chapter_of("ban") == 4 and TutorialState.chapter_of("finish") == 7 and TutorialState.chapter_of("nope") == 0, "chapter_of")


# ------------------------------------------------------------------ migrate: edges
func _migrate_edges(check: Callable) -> void:
	var legacy := TutorialState.migrate({"v": 1, "state": "legacy"})
	check.call(legacy["state"] == "legacy" and int(legacy["v"]) == 1, "migrate keeps legacy")
	check.call(TutorialState.migrate(null)["state"] == "legacy" and TutorialState.migrate("x")["state"] == "legacy" and TutorialState.migrate([1])["state"] == "legacy", "migrate: not a dictionary is legacy")
	check.call(TutorialState.migrate({"v": 1, "state": "weird"})["state"] == "legacy", "migrate: malformed state is legacy")
	check.call(TutorialState.migrate({"v": 1})["state"] == "legacy" and TutorialState.migrate({"v": 1, "state": 7})["state"] == "legacy", "migrate: missing or non-text state is legacy")
	check.call(TutorialState.migrate({"v": "x", "state": "done"})["state"] == "legacy" and TutorialState.migrate({"v": 0, "state": "done"})["state"] == "legacy", "migrate: a v that is not a number of 1 or more is legacy")
	var no_v := TutorialState.migrate({"state": "skipped", "step": "tabs"})
	check.call(no_v["state"] == "skipped" and int(no_v["v"]) == 1 and no_v["step"] == "tabs", "migrate: v absent counts as 1, skipped is unchanged")
	var done := TutorialState.migrate({"v": 1.0, "state": "done", "step": "finish", "game": {"live": false, "n": 2.0, "plan": {}}})
	check.call(done["state"] == "done" and typeof(done["v"]) == TYPE_INT and int(done["game"]["n"]) == 2 and typeof(done["game"]["n"]) == TYPE_INT, "migrate: floats from JSON become ints, done stays done")
	var nw := TutorialState.migrate({"v": 1, "state": "new", "step": "welcome", "game": {"live": false, "n": 0, "plan": {}}})
	check.call(_is_new_shape(nw), "migrate keeps new as it is")
	var nw2 := TutorialState.migrate({"v": 1, "state": "new"})
	check.call(_is_new_shape(nw2), "migrate: a new state with parts missing is filled in as new")
	# a step id that is not in the step list (a data edit): running resumes at the start of chapter 1, never crashes
	var unk := TutorialState.migrate({"v": 1, "state": "running", "step": "renamed_step", "game": {"live": false, "n": 1, "plan": {}}})
	check.call(unk["state"] == "running" and unk["step"] == "home_card", "migrate: an unknown running step falls back to home_card")
	var unk2 := TutorialState.migrate({"v": 1, "state": "running", "step": "renamed_step", "game": {"live": true, "n": 1, "plan": {}}})
	check.call(unk2["step"] == "tab_plan" and unk2["game"]["live"] == false, "migrate: an unknown step with a live game still clears the sandbox (tab_plan)")
	var nogame := TutorialState.migrate({"v": 1, "state": "running", "step": "tabs"})
	check.call(nogame["step"] == "home_card" and nogame["game"]["live"] == false and int(nogame["game"]["n"]) == 0, "migrate: a running state without a game dictionary gets one")
	# Home never gets a modal for a resume: the state stays running (the card, not the modal, is I-14's job)
	check.call(TutorialState.migrate({"v": 1, "state": "running", "step": "ban", "game": {"live": true, "n": 1, "plan": {}}})["state"] == "running", "a resume keeps the state running")
	# done and skipped are not resumed
	var sk := TutorialState.migrate({"v": 1, "state": "skipped", "step": "ban", "game": {"live": true, "n": 1, "plan": {"a": 1}}})
	check.call(sk["state"] == "skipped" and sk["step"] == "ban", "migrate: skipped is not rewound")


# ------------------------------------------------------------------ next_season carries the key
func _next_season(check: Callable) -> void:
	var states := {
		"new": TutorialState.new_state(),
		"running": {"v": 1, "state": "running", "step": "tab_plan", "game": {"live": false, "n": 3, "plan": {}}},
		"done": {"v": 1, "state": "done", "step": "finish", "game": {"live": false, "n": 1, "plan": {}}},
		"skipped": {"v": 1, "state": "skipped", "step": "tabs", "game": {"live": false, "n": 0, "plan": {}}},
		"legacy": {"v": 1, "state": "legacy"},
	}
	for name in states:
		var gs := GameState.new_game(World.load_default(), CLUB, 80710)
		gs.set_tutorial(states[name])
		gs.autoplay(true)
		var want := JSON.stringify(gs.d["tutorial"])
		var nxt := gs.next_season()
		check.call(nxt != null and int(nxt.d["season"]) == 2, "next_season (%s): season 2 starts" % name)
		check.call(nxt != null and nxt.tutorial()["state"] == name, "next_season carries the tutorial state %s" % name)
		check.call(nxt != null and JSON.stringify(nxt.d["tutorial"]) == want, "next_season (%s): the whole tutorial dictionary is carried unchanged" % name)
		if nxt != null:
			check.call(not is_same(nxt.d["tutorial"], gs.d["tutorial"]), "next_season (%s): a copy, not the same dictionary" % name)
			var again := _roundtrip(nxt)
			check.call(again != null and again.tutorial()["state"] == name, "next_season (%s): the state survives a save and reload" % name)
	# a newer build's key is carried untouched as well (not turned into legacy, so a downgrade-upgrade loses nothing)
	var g2 := GameState.new_game(World.load_default(), CLUB, 80711)
	g2.d["tutorial"] = {"v": 99, "state": "running", "step": "x", "game": {"live": true, "n": 3, "plan": {}}}
	g2.autoplay(true)
	var n2 := g2.next_season()
	check.call(n2 != null and int(n2.d["tutorial"]["v"]) == 99 and n2.tutorial()["state"] == "legacy", "next_season: tutorial.v = 99 is carried as it is and still reads legacy")
	# a save with no key at all (a 0.6 save is repaired by from_dict, but a dictionary built by hand may lack it)
	var g3 := GameState.new_game(World.load_default(), CLUB, 80712)
	g3.d.erase("tutorial")
	g3.autoplay(true)
	var n3 := g3.next_season()
	check.call(n3 != null and n3.tutorial()["state"] == "legacy", "next_season: a save with no tutorial key carries legacy, never new")
