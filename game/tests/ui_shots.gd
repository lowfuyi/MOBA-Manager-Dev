extends Node
## Screenshot tour for layout QA (needs a display; run under Xvfb). Writes PNGs to the folder in
## env SHOT_DIR. Not part of the normal headless checks.

var dir := "/tmp/shots"


func cur() -> Control:
	return App.main._current


func shot(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])


func _ready() -> void:
	var e := OS.get_environment("SHOT_DIR")
	if e != "":
		dir = e
	await get_tree().process_frame
	await _tour()
	get_tree().quit(0)


func _tour() -> void:
	GameState.delete_save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await shot("01_title")
	App.go(ScreenAbout.new())
	await shot("02_about")
	App.go(ScreenClubSelect.new())
	await shot("03_clubselect")
	cur()._choose(App.world.club_ids[5])
	await shot("04_hub")
	var rs := ScreenRoster.new("hub")
	App.go(rs)
	await shot("05_roster")
	rs._toggle_slot("top")
	await shot("06_roster_picker")
	rs._toggle_slot("top")
	rs._toggle_player(App.gs.d["lineup"]["mid"])
	await shot("07_roster_detail")
	var g: Dictionary = App.gs.next_game()
	for pid in (App.gs.d["lineup"] as Dictionary).values():
		App.world.fatigue[pid] = 55.0
	App.go(ScreenPreMatch.new(g))
	await shot("08_prematch")
	App.world.fatigue.clear()
	var trs := ScreenTraining.new()
	App.go(trs)
	await shot("08b_training")
	trs._toggle(App.world.club_players(App.gs.club())[0]["id"])
	await shot("08c_training_picker")
	trs._toggle_heroes()
	await shot("08d_training_heroes")
	var d := ScreenDraft.new(g)
	App.go(d)
	await shot("09_draft_start")
	var n := 0
	while not d.draft.is_done() and n < 100:
		n += 1
		var c := d.draft.current()
		if c["team"] == d.my_side:
			if c["kind"] == "pick":
				d._on_hero(d.draft.avail[3], "pick")
				await shot("10_draft_slotpanel_%d" % n)
				d._apply({"hero": d._sel_hero, "slot": d.draft.open_slots(d.my_side)[0]})
			else:
				await shot("10_draft_ban_%d" % n)
				d._on_hero(d.draft.avail[0], "ban")
			if n > 8:
				break
		else:
			d._process(5.0)
	d._auto_rest()
	await shot("11_draft_done")
	var gp := ScreenGamePlan.new(g, d.draft)
	App.go(gp)
	await shot("11b_gameplan")
	gp._coach()
	gp._set_tab("behind_early")
	gp._toggle_trigger()
	gp._set_value("r", 100)
	await shot("11c_gameplan_trigger")
	gp.go_back()
	d = cur()
	d._start_match()
	var m: ScreenMatch = cur()
	for i in 6:
		m._process(4.0)
	await shot("12_match_mid")
	m._skip()
	await shot("13_match_end")
	m._continue()
	await shot("14_report_top")
	var sc: ScrollContainer = cur().body.get_parent()
	sc.scroll_vertical = 900
	await shot("15_report_mid")
	cur()._leave()
	var st := ScreenStandings.new()
	App.go(st)
	await shot("16_standings")
	st._set_tab("results")
	await shot("17_standings_results")
	App.go(ScreenSettings.new())
	await shot("18_settings")
	App.gs.autoplay(true)
	App.go(ScreenHub.new())
	await shot("19_hub_after")
	App.go(ScreenSeasonEnd.new())
	await shot("20_season_end")
	GameState.delete_save()
