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
	for scr in [ScreenRoster.new("hub"), ScreenStandings.new(), ScreenSettings.new(), ScreenAbout.new()]:
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
	cur()._next()
	ok(cur() is ScreenHub and int(App.gs.d["season"]) == 2 and App.gs.club() == club, "next season starts")
	# quick mode skips the live feed
	App.gs.set_quick(true)
	var g2: Dictionary = App.gs.next_game()
	await _play_with_ui(g2, false)
	ok(cur() is ScreenHub or cur() is ScreenReport, "quick-mode game returns to a normal screen")
	# save / load round trip
	App.autosave()
	var loaded := GameState.load_save(App.world)
	ok(loaded != null and loaded.d["season"] == App.gs.d["season"] and loaded.d["round"] == App.gs.d["round"], "save/load round trip")
	GameState.delete_save()


## One game through PreMatch -> Draft -> Match -> Report -> back.
func _play_with_ui(g: Dictionary, manual: bool) -> void:
	App.go(ScreenHub.new())
	App.go(ScreenPreMatch.new(g))
	ok(cur() is ScreenPreMatch, "prematch")
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
