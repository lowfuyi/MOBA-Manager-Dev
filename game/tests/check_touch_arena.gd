extends Node
## Match views by simulated finger (Founder decision 2026-11-22): a new device starts in Action; a drag on the map pans the
## Action camera; 5 s after the last touch the camera chases again and eases back; Field and All are fixed whole-map views
## (a drag does nothing), All has no fog; the choice is remembered in the device setting [arena] camera.

const TEMP_CFG := "user://arena_touch_test.cfg"

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
	print("check_touch_arena: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _relaunch_with_touch_emulation() -> void:
	if "--touch-child" in OS.get_cmdline_user_args():
		print("FAIL touch emulation did not take effect in the child run")
		print("check_touch_arena: 1 checks, 1 failures")
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
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", proj, "res://tests/check_touch_arena.tscn", "--", "--touch-child"], out, true)
	if not existed:
		DirAccess.remove_absolute(cfg)
	var text := "\n".join(out)
	for line in text.split("\n"):
		if line.begins_with("ok ") or line.begins_with("FAIL") or line.begins_with("check_touch_arena:"):
			print(line)
	if text.find("check_touch_arena:") == -1:
		print("FAIL the child run produced no result line (exit %d)" % rc)
		print("check_touch_arena: 1 checks, 1 failures")
		get_tree().quit(1)
		return
	get_tree().quit(rc)


func _run() -> void:
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	sim = load("res://tests/spikes/touch_sim.gd").new(self)
	await _boot()
	var gs := App.gs
	var g := gs.next_game()
	var res := gs.auto_game(g)
	var m := ScreenMatch.new(g, res)
	App.go(m)
	await frames(4)
	var v := m.view
	ok(m.view_mode == "action" and v.mode == "action", "views: a new device starts in Action")
	m.show_t = 0.4 * m.show_len()
	m._apply(0.1)
	await frames(2)
	var before := v.cam.focus
	var c := v.get_global_rect().get_center()
	await sim.drag(c, Vector2(-220, 140), 10)
	await frames(2)
	ok(v.manual and v.cam.focus.distance_to(before) > 0.02, "views: a drag on the map pans the Action camera (%.3f)" % v.cam.focus.distance_to(before))
	var gt := m.player.game_t(m.show_t)
	v.show_game(gt, 4.0)
	ok(v.manual, "views: 4 s after the drag the camera still stays where you looked")
	v.show_game(gt, 1.5)
	ok(not v.manual, "views: 5 s after the last touch the camera chases again")
	var held := v.cam.focus
	for i in 30:
		v.show_game(gt, 0.1)
	var tgt: Vector2 = v.chase.target["pos"]
	ok(v.cam.focus.distance_to(tgt) < held.distance_to(tgt) + 1e-6, "views: it eases back toward the chased event")
	await sim.tap((m._view_btns["field"] as Button).get_global_rect().get_center())
	await frames(3)
	ok(v.mode == "field" and App.tutorial.device.arena_camera() == "field", "views: tapping Field shows Field and remembers it")
	var f0 := v.cam.focus
	var d0 := v.cam.dist
	await sim.drag(c, Vector2(-200, 100), 8)
	await frames(2)
	ok(not v.manual and v.cam.focus.distance_to(f0) < 1e-4 and absf(v.cam.dist - d0) < 1e-4, "views: Field is fixed (a drag does nothing)")
	await sim.tap((m._view_btns["all"] as Button).get_global_rect().get_center())
	await frames(3)
	ok(v.mode == "all" and not v.fog_on() and App.tutorial.device.arena_camera() == "all", "views: All has no fog and is remembered")
	var corners_in := true
	for p in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var pr := v.cam.project(p)
		corners_in = corners_in and pr.x >= 0.0 and pr.x <= v.size.x and pr.y >= 0.0 and pr.y <= v.size.y
	ok(corners_in, "views: All shows the whole island")
	await sim.tap((m._view_btns["action"] as Button).get_global_rect().get_center())
	await frames(3)
	ok(v.mode == "action" and v.fog_on(), "views: back to Action, fog on")
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))


func _boot() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(3)
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[3], 20261122)
	App.tutorial.autosave = false
	if FileAccess.file_exists(TEMP_CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	App.tutorial.device = DeviceState.new(TEMP_CFG)
	App.tutorial.bind()
	await frames(2)
