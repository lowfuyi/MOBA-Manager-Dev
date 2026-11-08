extends Node
## Headless UI smoke test: runs the real Main scene and drives every screen through a full season
## using the same handlers a tap would call. Engine/script errors show up in the log (the runner
## script greps for them); logic failures are counted here.

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func cur() -> Control:
	return App.main._current


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("ui smoke: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _run() -> void:
	GameState.delete_save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	ok(App.main == main, "App.main set")
	ok(cur() is ScreenTitle, "title shown first")
	App.go(ScreenAbout.new())
	ok(cur() is ScreenAbout, "about screen")
	App.go(ScreenClubSelect.new())
	ok(cur() is ScreenClubSelect, "club select")
	cur()._choose(App.world.club_ids[5])
	ok(cur() is ScreenHub and App.gs != null, "hub after choosing a club")
	for scr in [ScreenRoster.new("hub"), ScreenStandings.new(), ScreenSettings.new(), ScreenAbout.new(), ScreenChemistry.new()]:
		App.go(scr)
		await get_tree().process_frame
		ok(cur() == scr, "screen opens: " + scr.get_class())
	# roster interactions
	var rs := ScreenRoster.new("hub")
	App.go(rs)
	rs._toggle_slot("mid")
	var pid: String = App.world.clubs[App.gs.club()]["player_ids"][0]
	rs._assign("mid", pid)
	ok(App.gs.d["lineup"]["mid"] == pid, "assign via roster")
	rs._toggle_player(pid)
	rs._auto()
	var st := ScreenStandings.new()
	App.go(st)
	for t in ["table", "playoffs", "results"]:
		st._set_tab(t)
	var se := ScreenSettings.new()
	App.go(se)
	se._confirm_reset = true
	se._rebuild()
	# training screen: open it, change a focus, hand everything back to the coach
	var tr := ScreenTraining.new()
	App.go(tr)
	await get_tree().process_frame
	ok(cur() is ScreenTraining, "training screen opens")
	var tp: Dictionary = App.world.club_players(App.gs.club())[0]
	tr._toggle(tp["id"])
	tr._choose(tp["id"], "stat", "mec")
	ok(App.gs.focus_of(tp)["k"] == "stat" and App.gs.focus_of(tp)["v"] == "mec", "training focus set from the screen")
	tr._toggle_heroes()
	var hero_id: String = App.world.hero_ids[0]
	tr._choose(tp["id"], "hero", hero_id)
	ok(App.gs.focus_of(tp)["k"] == "hero", "hero practice set from the screen")
	tr._choose(tp["id"], "rest", "")
	ok(App.gs.focus_of(tp)["k"] == "rest", "rest set from the screen")
	tr._choose(tp["id"], "scrim", "")
	ok(App.gs.focus_of(tp)["k"] == "scrim", "team scrim set from the screen")
	tr._auto_one(tp["id"])
	tr._coach_all()
	ok(not (App.gs.d["train"] as Dictionary).has(tp["id"]), "coach picks everything again")
	tr._toggle(tp["id"])
	tr._toggle(tp["id"])
	# money: finance screen, sponsor, free agents, release, signing through the negotiation screen
	var fin := ScreenFinance.new()
	App.go(fin)
	await get_tree().process_frame
	ok(cur() is ScreenFinance, "finance screen opens")
	fin._choose("playoffs")
	ok(App.gs.d["sponsor"] == "playoffs", "sponsor chosen from the screen")
	fin._choose("steady")
	fin._more = true
	fin._rebuild()
	var fa := ScreenFreeAgents.new("hub")
	App.go(fa)
	await get_tree().process_frame
	ok(cur() is ScreenFreeAgents, "free agents screen opens")
	for i in 6:
		fa._next_role()
	for i in 4:
		fa._next_sort()
	var rs2 := ScreenRoster.new("hub")
	App.go(rs2)
	await get_tree().process_frame
	var cut: String = App.gs.d["roster"][9]
	rs2._toggle_player(cut)
	rs2._confirm_release = cut
	rs2._rebuild()
	rs2._release(cut)
	ok((App.gs.d["roster"] as Array).size() == 9 and (App.gs.d["fa"] as Array).has(cut), "release from the roster screen")
	var cand := ""
	for fid in App.gs.d["fa"]:
		if fid != cut:
			cand = fid
			break
	var neg := ScreenNegotiation.new(cand, false, "fa:hub")
	App.go(neg)
	await get_tree().process_frame
	ok(cur() is ScreenNegotiation, "negotiation screen opens")
	neg._adj(5)
	neg._adj(-5)
	neg._set_len(3)
	neg._wage = 1
	neg._make_offer()
	ok(neg._msg != "" and not neg._done, "a low offer is answered and the talks go on")
	neg._wage = int(ceil(Economy.required_wage(App.world, App.world.players[cand], 3))) + 1
	neg._make_offer()
	ok(neg._done and (App.gs.d["roster"] as Array).has(cand), "a fair offer signs the player")
	neg.go_back()
	await get_tree().process_frame
	ok(cur() is ScreenFreeAgents, "negotiation returns to the free agent list")
	App.go(ScreenHub.new())
	# full-UI games, then fast ones, through the whole season
	var played := 0
	var full_ui := 0
	var guard := 0
	while App.gs.d["phase"] != "done" and guard < 200:
		guard += 1
		var g: Dictionary = App.gs.next_game()
		if g.is_empty():
			App.gs.autoplay(true)
			continue
		if played % 4 == 0 or g["kind"] == "playoff" and g["full"]:
			await _play_with_ui(g, full_ui % 2 == 0)
			full_ui += 1
		else:
			ScreenHub._finish_game(g, App.gs.auto_game(g))
			ok(cur() is ScreenReport, "report after auto game")
			cur()._leave()
		played += 1
	ok(App.gs.d["phase"] == "done", "season completes (%d games by me, %d via UI)" % [played, full_ui])
	ok(full_ui >= 4, "enough games through the full UI")
	App.go(ScreenHub.new())
	App.go(ScreenSeasonEnd.new())
	ok(cur() is ScreenSeasonEnd, "season end screen")
	var club := App.gs.club()
	var expiring: Array = App.gs.expiring()
	ok(expiring.size() > 0, "some contracts end after the first season (%d)" % expiring.size())
	if expiring.size() > 0:
		var rid: String = expiring[0]["id"]
		var rn := ScreenNegotiation.new(rid, true, "season")
		App.go(rn)
		await get_tree().process_frame
		rn._wage = int(ceil(Economy.required_wage(App.world, App.world.players[rid], 2))) + 1
		rn._set_len(2)
		rn._make_offer()
		ok(rn._done and App.gs.seasons_left(rid) >= 2, "renewal from the season end screen")
		rn.go_back()
		await get_tree().process_frame
		ok(cur() is ScreenSeasonEnd, "renewal returns to the season end screen")
	App.go(ScreenFreeAgents.new("season"))
	await get_tree().process_frame
	ok(cur() is ScreenFreeAgents, "free agents open from the season end")
	cur().go_back()
	await get_tree().process_frame
	ok(cur() is ScreenSeasonEnd, "back from free agents returns to the season end")
	cur()._next()
	ok(cur() is ScreenHub and int(App.gs.d["season"]) == 2 and App.gs.club() == club, "next season starts")
	# quick mode skips the live feed
	App.gs.set_quick(true)
	var g2: Dictionary = App.gs.next_game()
	await _play_with_ui(g2, false)
	ok(cur() is ScreenHub or cur() is ScreenReport, "quick-mode game returns to a normal screen")
	# dismissal sends the manager to the game over screen
	App.gs.d["dismissed"] = true
	App.go(ScreenHub.new())
	await get_tree().process_frame
	await get_tree().process_frame
	ok(cur() is ScreenGameOver, "a dismissed manager sees the game over screen")
	App.gs.d["dismissed"] = false
	App.go(ScreenHub.new())
	# save / load round trip
	App.autosave()
	var loaded := GameState.load_save(App.world)
	ok(loaded != null and loaded.d["season"] == App.gs.d["season"] and loaded.d["round"] == App.gs.d["round"], "save/load round trip")
	GameState.delete_save()


## One game through PreMatch -> Draft -> Match -> Report -> back.
func _play_with_ui(g: Dictionary, manual: bool) -> void:
	App.go(ScreenHub.new())
	if manual:
		for pid in (App.gs.d["lineup"] as Dictionary).values():
			App.world.fatigue[pid] = 80.0  # everyone tired: the match day shows the warning and the rotate button
	App.go(ScreenPreMatch.new(g))
	ok(cur() is ScreenPreMatch, "prematch")
	if manual:
		ok(App.gs.tired_starters().size() == 5, "tired starters are detected")
		cur()._rotate()
		await get_tree().process_frame
		ok(cur() is ScreenPreMatch, "rotating returns to match day")
		App.world.fatigue.clear()
	App.go(ScreenDraft.new(g))
	await get_tree().process_frame
	var d: ScreenDraft = cur()
	ok(d is ScreenDraft, "draft screen")
	var guard := 0
	while not d.draft.is_done() and guard < 400:
		guard += 1
		var c := d.draft.current()
		if manual and c["team"] == d.my_side and guard % 2 == 0:
			if c["kind"] == "ban":
				d._on_hero(d.draft.avail[0], "ban")
			else:
				d._on_hero(d.draft.avail[0], "pick")
				d._apply({"hero": d._sel_hero, "slot": d.draft.open_slots(d.my_side)[0]})
		else:
			d._process(20.0)
	ok(d.draft.is_done(), "draft finishes (timeouts and manual picks)")
	ok(d.draft.order.size() == (16 if g["full"] else 12), "draft profile matches game kind")
	if manual:
		d = await _exercise_game_plan(g, d)
	d._start_match()
	await get_tree().process_frame
	if App.gs.is_quick():
		await get_tree().process_frame
		ok(cur() is ScreenReport, "quick mode goes straight to the report")
		cur()._leave()
		return
	var m: ScreenMatch = cur()
	ok(m is ScreenMatch, "match feed screen")
	guard = 0
	while not m._finished and guard < 500:
		guard += 1
		m._process(0.5)
		await get_tree().process_frame
	ok(m._finished, "feed plays to the end")
	ok(m._shown == 8, "all eight feed events shown")
	m._continue()
	await get_tree().process_frame
	ok(cur() is ScreenReport, "report after the match")
	cur()._leave()


## Open the Game Plan screen from the finished draft and tap through everything on it.
func _exercise_game_plan(g: Dictionary, d: ScreenDraft) -> ScreenDraft:
	var gp := ScreenGamePlan.new(g, d.draft)
	App.go(gp)
	await get_tree().process_frame
	ok(cur() is ScreenGamePlan, "game plan screen opens")
	var ps: Dictionary = App.gs.plan_set()
	ps["triggers"].clear()  # plans persist from game to game; start this check from a clean set
	gp._set_value("r", 100)
	gp._set_value("g", -50)
	gp._set_jf("top")
	ok(ps["default"]["r"] == 100 and ps["default"]["g"] == -50 and ps["default"]["jf"] == "top", "plan values are stored in the save")
	gp._set_tab("behind_early")
	gp._toggle_trigger()
	ok(ps["triggers"].size() == 1 and ps["triggers"][0]["when"] == "behind_early", "behind plan switched on")
	gp._set_value("r", 100)
	gp._set_value("a", 100)
	gp._set_tab("ahead_early")
	gp._toggle_trigger()
	gp._coach()
	gp._set_tab("default")
	gp._coach()
	var tot := 0
	for k in GamePlan.SLIDERS:
		tot += int(ps["default"][k])
	ok(absi(tot) <= 600, "coach suggestion is a valid plan")
	gp._reset()
	ok(GamePlan.is_neutral(ps["default"]), "reset makes the plan neutral")
	gp._set_value("t", -50)
	gp._set_tab("ahead_early")
	gp._toggle_trigger()
	ok(ps["triggers"].size() == 1, "ahead plan switched off again")
	# the plan survives a save and the back button returns to the finished draft
	App.autosave()
	var loaded := GameState.load_save(App.world)
	ok(loaded != null and loaded.plan_set()["default"]["t"] == -50, "plan survives save/load")
	gp.go_back()
	await get_tree().process_frame
	ok(cur() is ScreenDraft and cur().draft.is_done(), "back from game plan returns to the finished draft")
	return cur()
