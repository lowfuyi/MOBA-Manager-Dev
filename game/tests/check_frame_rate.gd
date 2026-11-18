extends Node
## Alpha 0.8.1: the Frame rate setting (30 or 60). Ends with "check_frame_rate: N checks, M failures".
##   clock     ScreenMatch.advance at 1/30 and 1/60 s per frame reaches the same show time at the same real second, at x1 and x2;
##             the show ends within one 30 fps frame of the same real second (75 s, 37.5 s at x2)
##   same      on 40 results in both seats, a show stepped at 30 fps and one stepped at 60 fps (each built fresh, each queried
##             frame by frame in order) give the same scoreboard, sprites, effects and words at every shared moment; the final
##             kills equal Report.kda and the towers the ledger at both; the result itself is unchanged
##   screen    the real Match screen driven at 1/30 and 1/60 ends after the same real seconds with the same final board
##   setting   Settings shows "30 (saves battery)" and "60 (smoother)", 60 chosen by default; tapping 30 stores 30 on the device
##             (read back by a fresh DeviceState), sets Engine.max_fps; a bad value is refused; nothing is written to the save

const TEMP_CFG := "user://check_frame_rate.cfg"

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
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	_clock()
	_same()
	await _boot()
	await _screen()
	await _boot()
	await _setting()
	_main.queue_free()
	await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_frame_rate: %d checks, %d failures" % [checks, fails])
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
	App.gs = GameState.new_game(App.world, App.world.club_ids[4], 20261119)
	var r: TutorialRunner = App.tutorial
	r.autosave = false
	r.device = DeviceState.new(TEMP_CFG)
	r.bind()


## Real seconds until the show clock reaches the end, stepping `fps` frames a second.
static func _seconds_to_end(fps: int, fast: bool) -> float:
	var t := 0.0
	var n := 0
	while t < ShowScript.WATCH and n < 100000:
		t = ScreenMatch.advance(t, 1.0 / fps, fast)
		n += 1
	return float(n) / fps


func _clock() -> void:
	for fast in [false, true]:
		var a := 0.0
		var b := 0.0
		var worst := 0.0
		for k in 1000:
			a = ScreenMatch.advance(a, 1.0 / 30.0, fast)
			b = ScreenMatch.advance(ScreenMatch.advance(b, 1.0 / 60.0, fast), 1.0 / 60.0, fast)
			worst = maxf(worst, absf(a - b))
		ok(worst < 1e-4, "clock%s: after each 1/30 s of real time the show time is the same at 30 and 60 fps (worst gap %.6f s)" % [" x2" if fast else "", worst])
		var s30 := _seconds_to_end(30, fast)
		var s60 := _seconds_to_end(60, fast)
		var want := ShowScript.WATCH / (2.0 if fast else 1.0)
		ok(absf(s30 - want) <= 1.0 / 30.0 + 1e-6 and absf(s60 - want) <= 1.0 / 30.0 + 1e-6,
				"clock%s: the show ends after %.2f s at 30 fps and %.2f s at 60 fps (want %.1f s): 30 is not slower" % [" x2" if fast else "", s30, s60, want])


## One state of the show at time t: what each layer would draw.
static func _state(s: ShowScript, c: Choreo, fx: ArenaFx, l: ArenaLabels, me: String, t: float, fast: bool) -> String:
	return JSON.stringify([ArenaHud.board_values(s, t), fx.sprites_at(t), fx.bars_at(t), fx.under_at(t), fx.over_at(t), l.at(t, fast)])


func _same() -> void:
	var w := App.world
	var meta := w.make_meta("fps-test")
	var bad := {}
	var n := 40
	var compared := 0
	for i in n:
		var a: String = w.club_ids[i % w.club_ids.size()]
		var b: String = w.club_ids[(i * 3 + 2) % w.club_ids.size()]
		if a == b:
			b = w.club_ids[(i + 1) % w.club_ids.size()]
		var res := MatchRunner.auto(w, w.best_lineup(a), w.best_lineup(b), meta, 9100 + i, "fps:%d" % i, false, {"B": "ai", "R": "ai"})
		var res_text := JSON.stringify(res)
		var me := "B" if i % 2 == 0 else "R"
		var fast := i % 4 == 1
		var held := "held_gate" if i % 3 == 0 else ""
		var runs := []
		for fps in [30, 60]:
			var s := ShowScript.build(res, me)
			var c := Choreo.build(s, held)
			var fx := ArenaFx.build(s, c, me)
			var l := ArenaLabels.build(s, false)
			var seen := {}
			var t := 0.0
			var k := 0
			while t < ShowScript.WATCH:
				t = ScreenMatch.advance(t, 1.0 / fps, fast)
				k += 1
				if k % (fps / 30) == 0 and (k / (fps / 30)) % 6 == 0:    # every 0.2 s of real time, queried in frame order
					seen[k / (fps / 30)] = _state(s, c, fx, l, me, float(k / (fps / 30)) / 30.0 * (2.0 if fast else 1.0), fast)
			var kd := Report.kda(res)
			var end := ArenaHud.board_values(s, ShowScript.WATCH)
			if int(end["kills_you"]) != int(kd["team"][me]["k"]) or int(end["kills_them"]) != int(kd["team"][ShowScript.other(me)]["k"]):
				bad["kills"] = true
			if int(end["towers_you"]) != int(s.tower_count[me]) or int(end["towers_them"]) != int(s.tower_count[ShowScript.other(me)]):
				bad["towers"] = true
			runs.append(seen)
		for key in runs[0]:
			compared += 1
			if not runs[1].has(key) or String(runs[0][key]) != String(runs[1][key]):
				bad["state"] = int(bad.get("state", 0)) + 1
		if JSON.stringify(res) != res_text:
			bad["result"] = true
	ok(not bad.has("state") and compared > 0, "same: board, sprites, effects and words agree at 30 and 60 fps at %d shared moments on %d results (both seats, x1 and x2, both held stagings)" % [compared, n])
	ok(not bad.has("kills"), "same: final kills equal Report.kda at 30 and at 60 fps")
	ok(not bad.has("towers"), "same: final towers equal the ledger at 30 and at 60 fps")
	ok(not bad.has("result"), "same: playing the show at either rate leaves the result unchanged")


func _screen() -> void:
	var g := App.gs.next_game()
	var res := App.gs.auto_game(g)
	var res_text := JSON.stringify(res)
	var out := []
	for fps in [30, 60]:
		var m := ScreenMatch.new(g, res.duplicate(true))
		App.go(m)
		await frames(4)
		m.set_process(false)    # the test is the clock: exactly 1/fps per frame
		m.show_t = 0.0
		var steps := 0
		while not m._finished and steps < 10000:
			m._process(1.0 / fps)
			steps += 1
		out.append([float(steps) / fps, JSON.stringify(ArenaHud.board_values(m.script_, m.show_t)), JSON.stringify(m.res)])
	ok(absf(float(out[0][0]) - float(out[1][0])) <= 1.0 / 30.0 + 1e-6 and absf(float(out[0][0]) - 75.0) <= 1.0 / 30.0 + 1e-6,
			"screen: the Match screen ends after %.2f s at 30 fps and %.2f s at 60 fps" % [float(out[0][0]), float(out[1][0])])
	ok(out[0][1] == out[1][1], "screen: the final board is the same at both rates")
	ok(out[0][2] == res_text and out[1][2] == res_text, "screen: the result is unchanged at both rates (R7)")


func _find(n: Node, name_: String) -> Node:
	if n.name == name_:
		return n
	for c in n.get_children():
		var f := _find(c, name_)
		if f != null:
			return f
	return null


func _setting() -> void:
	var dev: DeviceState = App.tutorial.device
	ok(dev.fps() == 60, "setting: 60 when nothing is stored")
	App.go(ScreenSettings.new())
	await frames(4)
	var b30 := _find(_main, "Fps30") as Button
	var b60 := _find(_main, "Fps60") as Button
	ok(b30 != null and b60 != null and UI.plain(b30.text) == "30 (saves battery)" and UI.plain(b60.text) == "60 (smoother)", "setting: Settings shows \"30 (saves battery)\" and \"60 (smoother)\"")
	ok(b60 != null and b30 != null and b60.get_theme_stylebox("normal") != b30.get_theme_stylebox("normal"), "setting: the chosen rate (60) is marked")
	ok(b30 != null and b30.size.y >= UI.BTN_H, "setting: the choices are full-height buttons (%d px)" % (int(b30.size.y) if b30 != null else 0))
	var save_before := JSON.stringify(App.gs.d)    # after Settings opened (its pace card starts an empty pace log)
	var old_max := Engine.max_fps
	App.fps_cap_on = true
	if b30 != null:
		b30.pressed.emit()
	await frames(3)
	ok(dev.fps() == 30 and DeviceState.new(TEMP_CFG).fps() == 30, "setting: tapping 30 stores 30 on the device (a fresh read sees it)")
	ok(Engine.max_fps == 30, "setting: tapping 30 sets Engine.max_fps to 30")
	ok(App.set_fps(60) and Engine.max_fps == 60 and DeviceState.new(TEMP_CFG).fps() == 60, "setting: back to 60")
	ok(not App.set_fps(45) and DeviceState.new(TEMP_CFG).fps() == 60 and Engine.max_fps == 60, "setting: a rate other than 30 or 60 is refused")
	ok(JSON.stringify(App.gs.d) == save_before, "setting: tapping a rate leaves the save untouched (a device setting, R6)")
	ok(App.debug_info().contains("fps cap=60"), "setting: the feedback note names the cap")
	App.fps_cap_on = false
	Engine.max_fps = old_max
