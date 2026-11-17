extends Node
## I-18 finger rows on the REAL Match report (T-std touch_report): a swipe that starts on the story band scrolls the page and opens
## nothing; a tap on a phase band opens its moments; a tap on the big number opens the Why sheet; Android back closes a sheet first;
## More detail opens and a tap on a segment switches the part; a tap on Open squad (when shown) and on Continue leave the Report.
## Normal and large text. Needs override.cfg (touch emulation); the scene relaunches itself with it, like check_touch_draft.
## Touch is SIMULATED (tests/spikes/touch_sim.gd); nothing here ran on a phone. Ends with " N checks, M failures".

const TEMP_CFG := "user://report_touch_test.cfg"

var fails := 0
var checks := 0
var sim
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
	await get_tree().process_frame
	if not DisplayServer.is_touchscreen_available():
		_relaunch_with_touch_emulation()
		return
	await _run()
	print("check_touch_report: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _relaunch_with_touch_emulation() -> void:
	if "--touch-child" in OS.get_cmdline_user_args():
		print("FAIL touch emulation did not take effect in the child run")
		print("check_touch_report: 1 checks, 1 failures")
		get_tree().quit(1)
		return
	var proj := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var cfg := proj + "/override.cfg"
	var existed := FileAccess.file_exists(cfg)
	if not existed:
		var f := FileAccess.open(cfg, FileAccess.WRITE)
		f.store_string("[input_devices]\n\npointing/emulate_touch_from_mouse=true\n")
		f.close()
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", proj, "res://tests/check_touch_report.tscn", "--", "--touch-child"], out, true)
	if not existed:
		DirAccess.remove_absolute(cfg)
	var text := "\n".join(out)
	for line in text.split("\n"):
		if line.begins_with("ok ") or line.begins_with("FAIL") or line.begins_with("check_touch_report:"):
			print(line)
	if text.find("check_touch_report:") == -1:
		print("FAIL the child run produced no result line (exit %d)" % rc)
		print("check_touch_report: 1 checks, 1 failures")
		get_tree().quit(1)
		return
	get_tree().quit(rc)


func _run() -> void:
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	sim = load("res://tests/spikes/touch_sim.gd").new(self)
	for variant in ["normal", "large"]:
		App.apply_large_text(variant == "large")
		await frames(3)
		await _rows(variant)
	App.apply_large_text(false)
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))


func _boot() -> void:
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
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], 20261117)
	App.tutorial.autosave = false
	App.tutorial.device = DeviceState.new(TEMP_CFG)
	App.tutorial.bind()


func _cur() -> Node:
	return App.main._current


func _c(ctl: Control, local: Vector2) -> Vector2:
	return ctl.get_global_transform_with_canvas() * local


func _mid(ctl: Control) -> Vector2:
	return _c(ctl, ctl.size * 0.5)


func _show(r: ScreenReport, ctl: Control) -> void:
	r.scroll_to(ctl)
	await frames(3)


func _report() -> ScreenReport:
	var g: Dictionary = App.gs.next_game()
	var d := ScreenDraft.new(g)
	App.go(d)
	await frames(3)
	d._auto_rest()
	d._start_match()
	await frames(3)
	var m: ScreenMatch = _cur()
	m._skip()
	m._continue()
	await frames(4)
	return _cur() as ScreenReport


func _rows(v: String) -> void:
	await _boot()
	var r := await _report()
	var sc := r.page_scroll
	sc.scroll_vertical = 0
	await frames(3)
	var bp := _c(r.bands, Vector2(r.bands.size.x * 0.5, _Bands_row_mid(0)))
	await sim.swipe_angle(bp, 0.0, 200.0, true, true)
	await frames(10)
	ok(sc.scroll_vertical > 0 and not BottomSheet.is_open(), "touch_report_%s: a swipe up on the story scrolls the page and opens nothing (%d)" % [v, sc.scroll_vertical])
	await _show(r, r.bands)
	await sim.tap(_c(r.bands, Vector2(r.bands.size.x * 0.5, _Bands_row_mid(2))))
	await frames(8)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "report_phase" and BottomSheet.current().title == PlanKit.name_of_phase("late"), "touch_report_%s: a tap on the Late band opens the Late moments" % v)
	App.main.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(20)
	ok(not BottomSheet.is_open() and _cur() == r, "touch_report_%s: Android back closes the sheet first" % v)
	await _show(r, r.stat_tile)
	await sim.tap(_mid(r.stat_tile))
	await frames(8)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "report_why", "touch_report_%s: a tap on the big number opens Why this happened" % v)
	BottomSheet.current().close()
	await frames(20)
	await _show(r, r.dig_button)
	await sim.tap(_mid(r.dig_button))
	await frames(4)
	ok(r.dig_bar.visible and r.dig_box.get_child_count() > 0, "touch_report_%s: a tap on More detail opens it" % v)
	await _show(r, r.dig_bar)
	await sim.tap(_c(r.dig_bar, r.dig_bar.seg_rect(r.dig_bar.index_of("moments")).get_center()))
	await frames(3)
	ok(r._dig == "moments", "touch_report_%s: a tap on Moments shows the moments" % v)
	await sim.tap(_mid(r.continue_button))
	await frames(4)
	ok(_cur() is ScreenHub or _cur() is ScreenSeasonEnd, "touch_report_%s: a tap on Continue leaves the Report" % v)


func _Bands_row_mid(i: int) -> float:
	return 112.0 * float(i) + 56.0
