extends Node
## I-23 checks (TUTORIAL 9 test 10), headless, on the real screens:
##   data           8 lessons, 32 steps (33 texts with the locked sponsor line), every text key exists
##   run_<id>       each lesson runs from its start to the end on the redesigned screens: tap steps by the real control, info steps by
##                  Next; no fallback card; it ends "done"; and the save is the same before and after (lessons never change the club)
##   skip           Skip ends a lesson where the player is, not done
##   status         Later snoozes (snoozed:1, snoozed:2), the third Later dismisses; "Show help hints again" brings it back as offered
##                  and keeps done
##   offers         no offer while the guide runs or before the first real game; at most one NEW offer per match day; a snoozed
##                  lesson waits its 3 match days; the unlock rules follow the data (round numbers)
##   list           Settings shows Lessons; the list has the eight lessons with New or Done, and Start runs one
## Ends with " N checks, M failures".

const TEMP_CFG := "user://lessons_test.cfg"
const ShotsSt = preload("res://tests/shots/shots_standings.gd")

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


func until(cond: Callable, max_ms: int = 4000) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _ready() -> void:
	TutorialRunner.home_offers = false
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	_data()
	for id in ["l1", "l2", "l3", "l4", "l6", "l7"]:
		await _boot(10)
		await _run(id)
	await _boot(10)
	await _run_l5()
	await _boot(10)
	await _run_l8()
	await _boot(10)
	await _skip()
	await _boot(10)
	_status()
	await _boot(0)
	await _offers()
	await _boot(2)
	await _list()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_lessons: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


## A save `games` games into the season (round numbers unlock lessons), a fresh device file, the guide not running.
func _boot(games: int) -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	if BottomSheet.is_open():
		BottomSheet.current().close()
		await frames(20)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(3)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], 20261117)
	App.tutorial.autosave = false
	App.tutorial.device = DeviceState.new(TEMP_CFG)
	App.gs.set_tutorial({"v": 1, "state": "done", "step": "finish", "game": {"live": false, "n": 1, "plan": {}}})
	App.tutorial.bind()
	App.lessons.wait_s = 1.0
	App.lessons.missing_s = 1.0
	ShotsSt.play(App.gs, games)


func _cur() -> Node:
	return App.main._current


func _snap() -> String:
	return JSON.stringify(App.gs.d)


func _data() -> void:
	var ids := LessonRunner.ids()
	var steps := 0
	var missing: Array = []
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/en.json"))
	for id in ids:
		for s in LessonRunner.lesson(String(id))["steps"]:
			steps += 1
			if not table.has("les." + String(s["id"])):
				missing.append(String(s["id"]))
			if s.has("key_locked") and not table.has(String(s["key_locked"])):
				missing.append(String(s["key_locked"]))
		if not table.has("lesson.title." + String(id)):
			missing.append("title " + String(id))
	ok(ids.size() == 8 and steps == 32, "data: 8 lessons, 32 steps (%d, %d)" % [ids.size(), steps])
	ok(missing.is_empty(), "data: every lesson text exists %s" % str(missing))


## Drive the running lesson to its end the way a player does: a tap step taps its real control, an info step presses Next.
func _drive(id: String) -> void:
	var lr := App.lessons
	var guard := 0
	while lr.running() and lr.lesson_id == id and guard < 40:
		guard += 1
		var shown := await until(func(): return lr.overlay != null and (lr.overlay.mode == "shown" or lr.overlay.mode == "fallback"))
		if not shown:
			print("     lesson %s: nothing shown at %s (%s)" % [id, lr.step().get("id", "?"), lr.overlay.mode if lr.overlay != null else "-"])
			break
		var s := lr.step()
		var sid := String(s["id"])
		if String(s["kind"]) == "info" or lr.overlay.is_fallback():
			lr.overlay.press("next")
		else:
			var t := UI.find_tag(String(lr.overlay.card_data()["target"][0]))
			if t is BaseButton:
				(t as BaseButton).pressed.emit()
			elif t is PlayerCard:
				(t as PlayerCard).pressed.emit()
			else:
				print("     lesson %s: no tap control at %s" % [id, sid])
				break
		await frames(5)
		if lr.running() and String(lr.step().get("id", "")) == sid:
			await frames(10)


func _run(id: String) -> void:
	var before := _snap()
	ok(App.lessons.start(id), "run_%s: the lesson starts" % id)
	await _drive(id)
	await frames(4)
	var dev := App.lessons.device()
	ok(not App.lessons.running() and dev.lesson_status(id) == "done" and App.lessons.fallbacks == 0,
			"run_%s: it runs to the end on the real screens, done, no fallback card (%d)" % [id, App.lessons.fallbacks])
	ok(_snap() == before, "run_%s: the save is unchanged (lessons never change the club)" % id)
	if BottomSheet.is_open():
		BottomSheet.current().close()
		await frames(20)


func _run_l5() -> void:
	var g: Dictionary = App.gs.next_game()
	var d := ScreenDraft.new(g)
	App.go(d)
	await frames(3)
	d._auto_rest()
	await frames(3)
	var before := _snap()
	ok(App.lessons.start("l5"), "run_l5: the lesson starts on Draft complete")
	await _drive("l5")
	await frames(4)
	ok(App.lessons.device().lesson_status("l5") == "done" and App.lessons.fallbacks == 0 and _cur() is ScreenGamePlan, "run_l5: it ends on the Game Plan, done, no fallback (%d)" % App.lessons.fallbacks)
	ok(_snap() == before, "run_l5: the plan and the save are unchanged")
	App.go(ScreenHub.new())
	await frames(3)
	ok(not App.lessons.start("l5"), "run_l5: off Draft complete it does not start")


func _run_l8() -> void:
	var g: Dictionary = App.gs.next_game()
	var d := ScreenDraft.new(g)
	App.go(d)
	await frames(3)
	d._auto_rest()
	d._start_match()
	await frames(3)
	(_cur() as ScreenMatch)._skip()
	(_cur() as ScreenMatch)._continue()
	await frames(4)
	var before := _snap()
	ok(App.lessons.start("l8"), "run_l8: the lesson starts on a real report")
	await _drive("l8")
	ok(App.lessons.device().lesson_status("l8") == "done" and App.lessons.fallbacks == 0 and _snap() == before, "run_l8: done, no fallback, nothing changed")


func _skip() -> void:
	App.lessons.start("l4")
	await until(func(): return App.lessons.overlay != null and App.lessons.overlay.mode == "shown")
	ok(UI.plain(App.lessons.overlay.skip_button.text) == UI.plain(Strings.t("lesson.skip")), "skip: a lesson card says Skip lesson, not Skip tutorial")
	App.lessons.overlay.press("skip")
	await frames(3)
	ok(not App.lessons.running() and App.lessons.device().lesson_status("l4") != "done" and App.lessons.overlay == null and _cur() is ScreenPlan, "skip: Skip ends the lesson where the player is, not done")


func _status() -> void:
	var lr := App.lessons
	var dev := lr.device()
	var a := lr.later("l1")
	var b := lr.later("l1")
	var c := lr.later("l1")
	ok(a == "snoozed:1" and b == "snoozed:2" and c == "dismissed", "status: Later, Later, Later: snoozed:1, snoozed:2, dismissed (%s %s %s)" % [a, b, c])
	dev.set_lesson_status("l2", "done")
	dev.hints_reset()
	ok(dev.lesson_status("l1") == "offered" and dev.lesson_status("l2") == "done", "status: Show help hints again brings l1 back as offered and keeps l2 done")


func _offers() -> void:
	var lr := App.lessons
	ok(lr.offer_for("home") == "", "offers: none before the first real game")
	ShotsSt.play(App.gs, 3)
	App.gs.set_tutorial({"v": 1, "state": "running", "step": "home_card", "game": {"live": false, "n": 0, "plan": {}}})
	App.tutorial.bind()
	ok(lr.offer_for("home") == "", "offers: none while the guided first game runs")
	App.gs.set_tutorial({"v": 1, "state": "done", "step": "finish", "game": {"live": false, "n": 1, "plan": {}}})
	App.tutorial.bind()
	var first := lr.offer_for("home")
	ok(first == "l1", "offers: after the first real game, Home offers L1 (%s)" % first)
	ok(lr.offer_for("home") == first, "offers: the same offer stays until it is answered")
	lr.later(first)
	var second := lr.offer_for("home")
	ok(second == "", "offers: at most one NEW offer per match day (got %s)" % second)
	ShotsSt.play(App.gs, 1)
	var third := lr.offer_for("home")
	ok(third != "" and third != first, "offers: the next match day offers another lesson (%s); the snoozed one waits" % third)
	ShotsSt.play(App.gs, 3)
	var dev := lr.device()
	dev.set_lesson_status(third, "done")
	var back := lr.offer_for("home")
	ok(back == first, "offers: after 3 match days the snoozed lesson is offered again (%s)" % back)
	ok(LessonRunner.unlocked("l6", App.gs) == (int(App.gs.d["round"]) >= 4) and not LessonRunner.unlocked("l5", App.gs) and LessonRunner.unlocked("l5", App.gs, "draftdone"),
			"offers: unlock rules follow the data (L6 from round 4; L5 only on Draft complete)")


func _list() -> void:
	App.go(ScreenSettings.new())
	await frames(4)
	var lb: Button = null
	for b in _cur().find_children("*", "Button", true, false):
		if UI.plain((b as Button).text) == UI.plain(Strings.t("settings.lessons")):
			lb = b
	ok(lb != null, "list: Settings shows Lessons")
	lb.pressed.emit()
	await frames(4)
	var s := _cur() as ScreenLessons
	ok(s != null and s.cards.size() == 8 and s.cards["l5"] == null and s.cards["l1"] != null, "list: eight lessons; L5 opens during a draft, L1 has Start")
	(s.cards["l1"] as Button).pressed.emit()
	await frames(4)
	ok(App.lessons.running() and App.lessons.lesson_id == "l1" and _cur() is ScreenHub, "list: Start runs L1 from Home")
	App.lessons.stop(false)
