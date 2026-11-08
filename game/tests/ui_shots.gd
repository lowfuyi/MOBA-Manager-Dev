extends Node
## Screenshot tour for layout QA (needs a display; run under Xvfb). Writes PNGs to the folder in
## env SHOT_DIR. Not part of the normal headless checks.

var dir := "/tmp/shots"
## Set by tests/shots/shots_baseline.gd (the screenshot matrix runs this tour as a module): no auto-start and no
## quit in _ready, picture names get prefix and suffix, and the matrix owns the large-text and colour-blind switches.
var as_module := false
var prefix := ""
var suffix := ""
var shots_taken := 0


func cur() -> Control:
	return App.main._current


func shot(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s%s%s.png" % [dir, prefix, name, suffix])
	shots_taken += 1


func _open_section(node: Node, needle: String) -> bool:
	if node is Button and (node as Button).text.begins_with("+ ") and (node as Button).text.contains(needle):
		(node as Button).pressed.emit()
		return true
	for ch in node.get_children():
		if _open_section(ch, needle):
			return true
	return false


func _tap_text(node: Node, needle: String) -> bool:
	if node is Button and (node as Button).text.contains(needle):
		(node as Button).pressed.emit()
		return true
	for ch in node.get_children():
		if _tap_text(ch, needle):
			return true
	return false


func _ready() -> void:
	if as_module:
		return
	var e := OS.get_environment("SHOT_DIR")
	if e != "":
		dir = e
	await get_tree().process_frame
	var big := OS.get_environment("LARGE") != ""
	var cb := OS.get_environment("COLORBLIND") != ""
	if big:
		App.set_large_text(true)
	if cb:
		App.set_colorblind(true)
	await _tour()
	App.set_large_text(false)
	App.set_colorblind(false)
	get_tree().quit(0)


func _tour() -> void:
	GameState.delete_save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	UI.animate = false
	await shot("01_title")
	App.go(ScreenAbout.new())
	await shot("02_about")
	App.go(ScreenClubSelect.new())
	await shot("03_clubselect")
	# the club screen's _choose seeds the save from the clock; a fixed seed keeps every run's pictures comparable
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], 20261109)
	App.autosave()
	App.go(ScreenHub.new())
	await shot("04_hub")
	(cur().body.get_parent() as ScrollContainer).scroll_vertical = 700
	await shot("04b_hub_lower")
	App.go(ScreenPractice.new())
	await shot("04d_practice")
	(cur().body.get_parent() as ScrollContainer).scroll_vertical = 0
	for tab in ["plan", "club", "more"]:
		App.go_tab(tab)
		await shot("04c_tab_" + tab)
	App.go_tab("home")
	var rs := ScreenRoster.new("hub")
	App.go(rs)
	await shot("05_roster")
	rs._toggle_slot("top")
	await shot("06_roster_picker")
	rs._toggle_slot("top")
	rs._toggle_player(App.gs.d["lineup"]["mid"])
	await shot("07_roster_detail")
	rs._confirm_release = App.gs.d["lineup"]["mid"]
	rs._rebuild()
	await shot("07b_roster_release")
	rs._confirm_release = ""
	App.go(ScreenFinance.new())
	await shot("07c_finance")
	var fa_scr := ScreenFreeAgents.new("hub")
	App.go(fa_scr)
	await shot("07d_free_agents")
	var cand: String = App.gs.d["fa"][0]
	var neg := ScreenNegotiation.new(cand, false, "fa:hub")
	App.go(neg)
	await shot("07e_negotiation_full")
	neg._wage = 1
	neg._make_offer()
	await shot("07f_negotiation_refused")
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
	var chs := ScreenChemistry.new()
	App.go(chs)
	await shot("08e_chemistry")
	(chs.body.get_parent() as ScrollContainer).scroll_vertical = 900
	await shot("08f_chemistry_lower")
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
	_open_section(cur(), "Player lines")
	await get_tree().process_frame
	sc.scroll_vertical = 1100
	await shot("15b_report_lines")
	cur()._leave()
	var st := ScreenStandings.new()
	App.go(st)
	await shot("16_standings")
	st._set_tab("form")
	await shot("16b_standings_form")
	st._set_tab("results")
	await shot("17_standings_results")
	App.go(ScreenSettings.new())
	await shot("18_settings")
	App.gs.autoplay(true)
	App.go(ScreenHub.new())
	await shot("19_hub_after")
	var tro := ScreenStandings.new("trophies")
	App.go(tro)
	await shot("19b_trophies")
	var rsc := ScreenRoster.new("hub")
	App.go(rsc)
	rsc._toggle_player(App.gs.d["lineup"]["mid"])
	await get_tree().process_frame
	_open_section(cur(), "Career with us")
	_tap_text(cur(), "Mechanics")
	await get_tree().process_frame
	var sc2: ScrollContainer = cur().body.get_parent()
	sc2.scroll_vertical = 500
	await shot("19c_roster_career")
	sc2.scroll_vertical = 1000
	await shot("19d_roster_career_lower")
	sc2.scroll_vertical = 1650
	await shot("19f_roster_career_bottom")
	sc2.scroll_vertical = 2400
	await shot("19g_roster_career_log")
	var prs := ScreenPractice.new()
	App.go(prs)
	await shot("19e_practice")
	App.go(ScreenSeasonEnd.new())
	await shot("20_season_end")
	GameState.delete_save()
