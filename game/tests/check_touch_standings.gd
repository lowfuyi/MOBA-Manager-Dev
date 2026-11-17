extends Node
## I-20 finger rows on the REAL Standings (T-std touch_standings): a tap on a view switches it and a sideways swipe across the views
## does not; a tap on Form Rating and on Points switches the metric (stand:metric); a swipe on the table scrolls it and the pinned
## row appears when your row leaves the view. Normal and large text. Needs override.cfg (touch emulation); relaunches itself.
## Touch is SIMULATED (tests/spikes/touch_sim.gd); nothing here ran on a phone. Ends with " N checks, M failures".

const TEMP_CFG := "user://standings_touch_test.cfg"

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
	print("check_touch_standings: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _relaunch_with_touch_emulation() -> void:
	if "--touch-child" in OS.get_cmdline_user_args():
		print("FAIL touch emulation did not take effect in the child run")
		print("check_touch_standings: 1 checks, 1 failures")
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
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", proj, "res://tests/check_touch_standings.tscn", "--", "--touch-child"], out, true)
	if not existed:
		DirAccess.remove_absolute(cfg)
	var text := "\n".join(out)
	for line in text.split("\n"):
		if line.begins_with("ok ") or line.begins_with("FAIL") or line.begins_with("check_touch_standings:"):
			print(line)
	if text.find("check_touch_standings:") == -1:
		print("FAIL the child run produced no result line (exit %d)" % rc)
		print("check_touch_standings: 1 checks, 1 failures")
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


func _rows(v: String) -> void:
	await _boot()
	load("res://tests/shots/shots_standings.gd").play(App.gs, 6)
	var s := ScreenStandings.new()
	App.go(s)
	await frames(6)
	await sim.tap(_c(s.views, s.views.seg_rect(s.views.index_of("history")).get_center()))
	await frames(3)
	ok(s.view() == "history", "touch_stand_%s: a tap on History switches the view" % v)
	await sim.swipe_angle(_c(s.views, s.views.seg_rect(0).get_center()), 90.0, 220.0, true, false)
	await frames(6)
	ok(s.view() == "history", "touch_stand_%s: a sideways swipe across the views changes nothing" % v)
	await sim.tap(_c(s.views, s.views.seg_rect(s.views.index_of("table")).get_center()))
	await frames(3)
	var hits: Array = []    # a lambda captures locals by value: count in an Array
	App.bus.raised.connect(func(n: String, _d: Dictionary) -> void:
		if n == "stand:metric":
			hits.append(n))
	await sim.tap(_c(s.metric, s.metric.seg_rect(s.metric.index_of("form")).get_center()))
	await frames(3)
	ok(s._metric == "form" and hits.size() == 1, "touch_stand_%s: a tap on Form Rating switches the metric (stand:metric)" % v)
	await sim.tap(_c(s.metric, s.metric.seg_rect(s.metric.index_of("points")).get_center()))
	await frames(3)
	ok(s._metric == "points" and hits.size() == 2, "touch_stand_%s: a tap on Points switches back" % v)
	var before := s.page_scroll.scroll_vertical
	await sim.swipe_angle(_c(s.podium, s.podium.size * 0.5), 0.0, 260.0, true, true)
	await frames(10)
	ok(s.page_scroll.scroll_vertical > before, "touch_stand_%s: a swipe up on the podium scrolls the table (%d -> %d)" % [v, before, s.page_scroll.scroll_vertical])
	var own: Control = s.podium
	for r in s.rows.get_children():
		if r is RankRow and (r as RankRow).is_own():
			own = r
	var vis := s.page_scroll.get_global_rect().intersects(_core(own))
	ok(s.pinned.visible == not vis, "touch_stand_%s: after the swipe the pinned row matches whether your row is in view (%s / %s)" % [v, vis, s.pinned.visible])


func _core(c: Control) -> Rect2:
	var gr := c.get_global_rect().abs()
	return Rect2(gr.position.x, gr.position.y + gr.size.y * 0.25, gr.size.x, gr.size.y * 0.5)
