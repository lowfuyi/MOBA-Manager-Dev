extends Node
## Arena v2 (Phase 4): the Match screen is the live arena, playing the Match Sim v2 log. Ends with "check_ui_match: N checks, M failures".
##   geometry  at 720 x 1280, large text and a tall phone (720 x 1560), Match Day M2: scoreboard (with View and Menu), arena,
##             commentary strip and line-up panel in order without overlap; the arena full width; buttons 96 px; "?" on the map;
##             all ten heroes in the panel with nothing cut
##   play      the intro holds the clock and a tap skips it; show time follows _process; Speed cycles x1, x2, x4 (chip);
##             Pause; the menu's buttons; View cycles; a help sheet pauses it; Back during the show is Skip and the
##             board shows the final numbers (kills = Report.kda); Back after it is See the report
##   R7        watching does not change the result or the save

const TEMP_CFG := "user://check_ui_match.cfg"

var checks := 0
var fails := 0
var _main: Control


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	TutorialRunner.home_offers = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	for v in [["normal", Vector2i(720, 1280), false], ["large", Vector2i(720, 1280), true], ["tall", Vector2i(720, 1560), false]]:
		get_window().size = v[1]
		App.apply_large_text(bool(v[2]))
		await frames(2)
		await _boot()
		await _geometry(String(v[0]))
	App.apply_large_text(false)
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	await _boot()
	await _play()
	_main.queue_free()
	await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_ui_match: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _boot() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(3)
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], 20261118)
	var r: TutorialRunner = App.tutorial
	r.autosave = false
	r.device = DeviceState.new(TEMP_CFG)
	r.bind()


func _match() -> ScreenMatch:
	var g := App.gs.next_game()
	var m := ScreenMatch.new(g, App.gs.auto_game(g))
	App.go(m)
	await frames(4)
	return m


func _geometry(v: String) -> void:
	var m := await _match()
	var view := get_viewport().get_visible_rect().size
	var b := m._board.get_global_rect()
	var a := m.view.get_global_rect()
	var n := m._notes.get_global_rect()
	var lp := m._lineup.get_global_rect()
	var vb := m._view_btn.get_global_rect()
	var mb := m._menu_btn.get_global_rect()
	var hs := m.help_slot.get_global_rect()
	var large := v == "large"
	var strip_end := m._feed.get_global_rect().end.y if m._feed.visible else n.end.y
	ok(absf(a.size.x - view.x) < 0.5 and absf(a.position.x) < 0.5 and a.size.y >= (480.0 if large else 560.0), "%s: the arena is full width and tall (560 px; 480 in large text, Founder's Match Day M2), %.0f x %.0f" % [v, a.size.x, a.size.y])
	ok(b.end.y <= a.position.y + 0.5 and a.end.y <= n.position.y + 0.5 and strip_end <= lp.position.y + 0.5, "%s: scoreboard, arena, commentary strip and line-up panel stack without overlap" % v)
	ok(absf(b.size.y - 150.0) < 0.5 and absf(b.position.y - 48.0) < 0.5, "%s: the scoreboard is 150 px under the 48 px safe area" % v)
	ok(absf(lp.end.y - (view.y - 24.0)) < 0.5 and lp.size.y >= 300.0 - 0.5, "%s: the line-up panel is %d px, 24 px above the bottom" % [v, int(lp.size.y)])
	ok(vb.size.y >= UI.BTN_H and mb.size.y >= UI.BTN_H and b.encloses(vb) and b.encloses(mb) and vb.position.x < view.x * 0.3 and mb.end.x > view.x * 0.7, "%s: View and Menu are 96 px buttons at the two ends of the scoreboard" % v)
	ok(UI.find_tag("match.controls") == m._menu_btn and UI.find_tag("match.views") == m._view_btn, "%s: tutorial tags: match.controls is Menu, match.views is View" % v)
	ok(m.help_slot.visible and a.encloses(hs), "%s: the \"?\" sits on the map" % v)
	m.skip_intro()
	m.show_t = m.show_len() * 0.5
	m._apply()
	await frames(2)
	var heroes := 0
	for sd in ["B", "R"]:
		for s in ["top", "jg", "mid", "bot", "sup"]:
			var hv := m._lineup.hero_view(sd + "." + s)
			if String(hv["name"]) != "":
				heroes += 1
	ok(heroes == 10 and m._lineup.clipped().is_empty() and m._lineup.draw_count > 0, "%s: all ten heroes in the panel, no name or number cut %s" % [v, str(m._lineup.clipped())])


func _play() -> void:
	var gs := App.gs
	var g := gs.next_game()
	var res := gs.auto_game(g)
	var res_text := JSON.stringify(res)
	var before := JSON.stringify(gs.d)
	var m := ScreenMatch.new(g, res)
	App.go(m)
	await frames(4)
	ok(Report.is_v2(res) and m.player != null and m.show_len() > 60.0, "play: a v2 game plays (show length %.0f s)" % m.show_len())
	# the intro: the show clock waits, the strip shows the intro, a tap on the strip skips it
	ok(m._intro_i == 0 and not m._notes.intro.is_empty(), "play: the Broadcast intro opens the show (%d lines)" % m._notes.cast.intro.size())
	var t_in := m.show_t
	m._process(1.0)
	ok(is_equal_approx(m.show_t, t_in), "play: the show clock waits during the intro")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	m._on_strip_input(tap)
	ok(m._intro_i == -1 and m._notes.intro.is_empty(), "play: a tap on the strip skips the intro")
	var t0 := m.show_t
	m._process(2.0)
	ok(is_equal_approx(m.show_t - t0, 2.0) and m.speed() == 1.0 and not m._chip.visible, "play: show time follows _process at x1, no speed chip (+%.2f)" % (m.show_t - t0))
	m._toggle_speed()
	var t1 := m.show_t
	m._process(2.0)
	ok(is_equal_approx(m.show_t - t1, 4.0) and m._chip.visible, "play: x2 doubles it and the chip shows (+%.2f)" % (m.show_t - t1))
	ok(m._chip.size.x > m._chip.size.y * 2.0, "play: the speed chip is one line (%.0f x %.0f)" % [m._chip.size.x, m._chip.size.y])
	m._toggle_speed()
	var t1b := m.show_t
	m._process(2.0)
	ok(is_equal_approx(m.show_t - t1b, 8.0) and UI.plain(m._chip.text) == UI.plain(Strings.t("match.speed4")), "play: x4 quadruples it (+%.2f)" % (m.show_t - t1b))
	m._toggle_speed()
	ok(m.speed() == 1.0 and not m._chip.visible, "play: Speed cycles back to x1")
	m._toggle_pause()
	var tp := m.show_t
	m._process(2.0)
	ok(is_equal_approx(m.show_t, tp) and m._chip.visible, "play: Pause stops the show and the chip says so")
	m._toggle_pause()
	# the menu holds speed, pause, skip, view and sound
	m._open_menu()
	await frames(4)
	var have := true
	for tg in ["match.menu.speed1", "match.menu.speed2", "match.menu.speed4", "match.menu.pause", "match.menu.skip", "match.view.field", "match.view.action", "match.view.all", "match.menu.sound"]:
		var c := UI.find_tag(tg)
		have = have and c is Button and (c as Button).size.y >= UI.BTN_H - 0.5
	ok(have, "play: the menu has Speed x1/x2/x4, Pause, Skip, the three views and Sound, all 96 px")
	(UI.find_tag("match.menu.speed2") as Button).pressed.emit()
	await frames(6)
	ok(m.speed() == 2.0 and not BottomSheet.is_open(), "play: Speed x2 in the menu sets x2 and closes it")
	m._set_speed(0)
	var v0 := m.view_mode
	m._cycle_view()
	ok(m.view_mode != v0, "play: View cycles to the next view (%s to %s)" % [v0, m.view_mode])
	HelpSheet.open("match")
	await frames(4)
	var t2 := m.show_t
	await frames(4)
	m._process(3.0)
	ok(is_equal_approx(m.show_t, t2), "play: a help sheet pauses the show (frames and a 3 s step add nothing)")
	for s in get_tree().root.find_children("*", "BottomSheet", true, false):
		(s as BottomSheet).close()
	await frames(6)
	m.go_back()    # Back during the show is Skip
	await frames(2)
	var kd := Report.kda(res)
	var me := m.my_side
	var them := "R" if me == "B" else "B"
	var v := ArenaHud2.board_values(m.player, m.player.game_t(m.show_t))
	ok(m._finished and is_equal_approx(m.show_t, m.show_len()), "play: Back during the show skips to the end")
	ok(int(v["kills_you"]) == int(kd["team"][me]["k"]) and int(v["kills_them"]) == int(kd["team"][them]["k"]), "play: after Skip the board shows the final kills %d-%d (Report.kda)" % [int(v["kills_you"]), int(v["kills_them"])])
	ok(m._go_btn.visible and not m._menu_btn.visible and m._lineup.visible, "play: See the report is the one action at the end; the line-ups stay")
	ok(JSON.stringify(m.res) == res_text and JSON.stringify(gs.d) == before, "play: watching changed neither the result nor the save (R7)")
	# Match Day M7: the replay with a timeline, after the end only
	ok(m._replay_btn.visible and not m._timeline.visible, "replay: Watch replay shows at the end; no timeline before it")
	m.start_replay()
	ok(m._replay and is_equal_approx(m.show_t, 0.0) and m._timeline.visible and m._play_btn.visible and m._done_btn.visible and not m._go_btn.visible and m._notes.visible, "replay: it starts at 0 with Play/Pause, the timeline and Done; the commentary is back")
	var tk := m._timeline.ticks()
	var kinds := {}
	for x in tk:
		kinds[String(x[1])] = true
	ok(tk.size() >= 10 and kinds.has("kill") and kinds.has("tower"), "replay: the timeline has %d ticks (kills, towers, objectives)" % tk.size())
	var tr0 := m.show_t
	m._process(3.0)
	ok(is_equal_approx(m.show_t - tr0, 3.0), "replay: it plays (+%.1f)" % (m.show_t - tr0))
	m.seek_frac(0.5)
	var vh := ArenaHud2.board_values(m.player, m.player.game_t(m.show_t))
	var vd := ArenaHud2.board_values(m.player, m.player.game_t(0.5 * m.show_len()))
	ok(is_equal_approx(m.show_t, 0.5 * m.show_len()) and vh["clock"] == vd["clock"] and int(vh["kills_you"]) == int(vd["kills_you"]), "replay: a seek to the middle shows the middle (clock %s)" % vh["clock"])
	m._toggle_replay_pause()
	var tpz := m.show_t
	m._process(2.0)
	ok(is_equal_approx(m.show_t, tpz), "replay: Pause stops it")
	m._toggle_replay_pause()
	m.seek_frac(0.999)
	m._process(5.0)
	ok(m._finished and is_equal_approx(m.show_t, m.show_len()) and m._paused, "replay: it waits at the end (no second result)")
	m.go_back()    # Back during the replay: back to the result
	await frames(2)
	ok(not m._replay and m._go_btn.visible and m._replay_btn.visible and not m._timeline.visible and m._feed.end_text != "", "replay: Back returns to the result card with See the report")
	ok(JSON.stringify(m.res) == res_text and JSON.stringify(gs.d) == before, "replay: the replay changed neither the result nor the save (R7)")
	m.go_back()    # Back after the show: See the report
	await frames(4)
	var cur: Node = null
	for c in _main.get_node("Content").get_child(0).get_child(0).get_children():
		if not c.is_queued_for_deletion():
			cur = c
	ok(cur is ScreenReport, "play: Back after the show opens the report")
