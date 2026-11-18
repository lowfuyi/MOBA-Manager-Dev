extends Node
## Alpha 0.8 A-06: the Match screen is the arena. Ends with "check_ui_match: N checks, M failures".
##   geometry  at 720 x 1280, large text (626 x 1113) and a tall phone (720 x 1560): scoreboard, arena, text strip and controls
##             in their order without overlap; the arena is full width (720 x 760, 626 x 661 large); buttons 96 px; "?" in
##             the controls row at the right; on a tall phone the air is above the scoreboard
##   play      show time advances with _process; x2 doubles it; a help sheet pauses it; Skip jumps to 75 s and the board shows
##             the final numbers (kills = Report.kda); Back during the show is Skip, after it is See the report
##   tester    the device switch held_gate reaches the choreography; default is the data's held_island
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
	await _boot()
	await _tester()
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
	var a := m._map.get_global_rect()
	var f := m._feed.get_global_rect()
	var c := m._controls.get_global_rect()
	var hs := m.help_slot.get_global_rect()
	var large := v == "large"
	var want_w := view.x
	ok(absf(a.size.x - want_w) < 0.5 and absf(a.size.y - want_w * 760.0 / 720.0) < 0.5 and absf(a.position.x) < 0.5, "%s: the arena is full width, %.0f x %.0f" % [v, a.size.x, a.size.y])
	ok(b.end.y <= a.position.y + 0.5 and a.end.y <= f.position.y + 0.5 and f.end.y <= c.position.y + 0.5, "%s: scoreboard, arena, feed and controls stack without overlap (%.0f / %.0f-%.0f / %.0f-%.0f / %.0f)" % [v, b.end.y, a.position.y, a.end.y, f.position.y, f.end.y, c.position.y])
	ok(absf(b.size.y - (122.0 if large else 142.0)) < 0.5, "%s: the scoreboard is %d px" % [v, int(b.size.y)])
	ok(absf(c.end.y - (view.y - 24.0)) < 0.5 and m._speed_btn.size.y >= UI.BTN_H and m._skip_btn.size.y >= UI.BTN_H and absf(m._speed_btn.size.x - 200.0) < 0.5, "%s: Speed (200 px) and Skip are 96 px high, 24 px above the bottom" % v)
	ok(m.help_slot.visible and absf(hs.position.y - c.position.y) < 0.5 and hs.end.x <= view.x - 23.5 and hs.position.x >= c.end.x, "%s: the \"?\" is at the right end of the controls row" % v)
	ok(m._controls.get_global_rect().encloses(m._speed_btn.get_global_rect()) and m._controls.get_global_rect().encloses(m._skip_btn.get_global_rect()), "%s: match.controls covers Speed and Skip (tutorial step 19)" % v)
	if v == "tall":
		ok(b.position.y >= 48.0 + 279.5, "tall: the extra 280 px is air above the scoreboard (board at y %.0f)" % b.position.y)
	else:
		ok(absf(b.position.y - 48.0) < 0.5 and absf(a.end.y + (150.0 if large else 198.0) + 132.0 - view.y) < 0.5, "%s: the stack fills the screen exactly (safe 48 at the top)" % v)


func _play() -> void:
	var gs := App.gs
	var g := gs.next_game()
	var res := gs.auto_game(g)
	var res_text := JSON.stringify(res)
	var before := JSON.stringify(gs.d)
	var m := ScreenMatch.new(g, res)
	App.go(m)
	await frames(4)
	var t0 := m.show_t    # the screen's own _process also runs between frames, so compare steps with no wait between
	m._process(2.0)
	ok(is_equal_approx(m.show_t - t0, 2.0), "play: show time follows _process (+%.2f)" % (m.show_t - t0))
	m._toggle_speed()
	var t1 := m.show_t
	m._process(2.0)
	ok(is_equal_approx(m.show_t - t1, 4.0), "play: x2 doubles it (+%.2f)" % (m.show_t - t1))
	m._toggle_speed()
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
	var v := ArenaHud.board_values(m.script_, m.show_t)
	ok(m._finished and m.show_t == 75.0 and m._shown == 8, "play: Back during the show skips to the end (all 8 results shown)")
	ok(int(v["kills_you"]) == int(kd["team"][me]["k"]) and int(v["kills_them"]) == int(kd["team"][ShowScript.other(me)]["k"]), "play: after Skip the board shows the final kills %d-%d (Report.kda)" % [int(v["kills_you"]), int(v["kills_them"])])
	ok(m._go_btn.visible and not m._speed_btn.visible and not m._skip_btn.visible, "play: See the report replaces Speed and Skip")
	ok(JSON.stringify(m.res) == res_text and JSON.stringify(gs.d) == before, "play: watching changed neither the result nor the save (R7)")
	m.go_back()    # Back after the show: See the report
	await frames(4)
	var cur: Node = null
	for c in _main.get_node("Content").get_child(0).get_child(0).get_children():
		if not c.is_queued_for_deletion():
			cur = c
	ok(cur is ScreenReport, "play: Back after the show opens the report")


func _tester() -> void:
	var dev: DeviceState = App.tutorial.device
	ok(dev.arena_held() == "" and ScreenMatch.held_variant() == "", "tester: no switch set means the data's default")
	ok(not dev.set_arena_held("held_nowhere") and dev.arena_held() == "", "tester: an unknown staging is refused")
	ok(dev.set_arena_held("held_gate") and ScreenMatch.held_variant() == "held_gate", "tester: the switch stores held_gate on the device")
	# a held game: find one, then check both stagings reach the choreography
	var w := App.world
	var meta := w.make_meta("ui-match")
	var found := false
	for i in 80:
		var res := MatchRunner.auto(w, w.best_lineup(w.club_ids[i % 10]), w.best_lineup(w.club_ids[(i + 3) % 10]), meta, 3100 + i, "uim:%d" % i, false, {"B": "ai", "R": "ai"})
		var s := ShowScript.build(res, "B")
		if s.held:
			found = true
			ok(Choreo.build(s, ScreenMatch.held_variant()).variant == "held_gate" and Choreo.build(s, "").variant == "held_island", "tester: a held game plays held_gate with the switch on, held_island without")
			break
	ok(found, "tester: the sample has a held game")
	dev.set_arena_held("")
