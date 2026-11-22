extends Node
## Arena v2 (Phase 4): the Match screen is the live arena, playing the Match Sim v2 log. Ends with "check_ui_match: N checks, M failures".
##   geometry  at 720 x 1280, large text and a tall phone (720 x 1560): scoreboard, arena, notes, feed and controls in their
##             order without overlap; the arena is full width and takes the rest; buttons 96 px; "?" at the right of the controls
##   play      show time follows _process; Speed cycles x1, x2, x4; a help sheet pauses it; Back during the show is Skip and the
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
	var f := m._feed.get_global_rect()
	var c := m._controls.get_global_rect()
	var hs := m.help_slot.get_global_rect()
	var large := v == "large"
	ok(absf(a.size.x - view.x) < 0.5 and absf(a.position.x) < 0.5 and a.size.y >= (560.0 if large else 600.0), "%s: the arena is full width and tall (600 px, 560 in large text under the view row), %.0f x %.0f" % [v, a.size.x, a.size.y])
	ok(b.end.y <= a.position.y + 0.5 and a.end.y <= n.position.y + 0.5 and n.end.y <= f.position.y + 0.5 and f.end.y <= c.position.y + 0.5, "%s: scoreboard, arena, notes, feed and controls stack without overlap" % v)
	ok(absf(b.size.y - (122.0 if large else 142.0)) < 0.5 and absf(b.position.y - 48.0) < 0.5, "%s: the scoreboard is %d px under the 48 px safe area" % [v, int(b.size.y)])
	ok(absf(c.end.y - (view.y - 24.0)) < 0.5 and m._speed_btn.size.y >= UI.BTN_H and m._skip_btn.size.y >= UI.BTN_H and absf(m._speed_btn.size.x - 200.0) < 0.5, "%s: Speed (200 px) and Skip are 96 px high, 24 px above the bottom" % v)
	ok(m.help_slot.visible and absf(hs.position.y - c.position.y) < 0.5 and hs.end.x <= view.x - 23.5 and hs.position.x >= c.end.x, "%s: the \"?\" is at the right end of the controls row" % v)
	ok(m._controls.get_global_rect().encloses(m._speed_btn.get_global_rect()) and m._controls.get_global_rect().encloses(m._skip_btn.get_global_rect()), "%s: match.controls covers Speed and Skip (tutorial step 19)" % v)


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
	var t0 := m.show_t
	m._process(2.0)
	ok(is_equal_approx(m.show_t - t0, 2.0), "play: show time follows _process (+%.2f)" % (m.show_t - t0))
	m._toggle_speed()
	var t1 := m.show_t
	m._process(2.0)
	ok(is_equal_approx(m.show_t - t1, 4.0), "play: x2 doubles it (+%.2f)" % (m.show_t - t1))
	m._toggle_speed()
	var t1b := m.show_t
	m._process(2.0)
	ok(is_equal_approx(m.show_t - t1b, 8.0) and m._speed_btn.text == Strings.t("match.speed4"), "play: x4 quadruples it (+%.2f)" % (m.show_t - t1b))
	m._toggle_speed()
	ok(m._speed_btn.text == Strings.t("match.speed1"), "play: Speed cycles back to x1")
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
	ok(m._go_btn.visible and not m._speed_btn.visible and not m._skip_btn.visible, "play: See the report replaces Speed and Skip")
	ok(JSON.stringify(m.res) == res_text and JSON.stringify(gs.d) == before, "play: watching changed neither the result nor the save (R7)")
	m.go_back()    # Back after the show: See the report
	await frames(4)
	var cur: Node = null
	for c in _main.get_node("Content").get_child(0).get_child(0).get_children():
		if not c.is_queued_for_deletion():
			cur = c
	ok(cur is ScreenReport, "play: Back after the show opens the report")
