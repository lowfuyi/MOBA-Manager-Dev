extends Node
## I-17 finger rows on the REAL Game Plan (T-std touch_gameplan): a tap on a phase node changes the page and a swipe across the strip
## does not; every detent of a track is reachable by a tap and by dragging the thumb; a vertical swipe that starts on a track
## scrolls the page and changes nothing; a tap on a Jungle focus segment sets it; Coach opens its sheet and Apply applies; Reset
## resets; the plan chip opens the plan sheet, its switch turns a trigger plan on and its row opens that plan; in a trigger plan
## an inert track and the locked Jungle focus take no tap; Android back closes a sheet first; Start the match starts the match.
## Normal and large text. Needs override.cfg (touch emulation); the scene relaunches itself with it, like check_touch_draft.
## Touch is SIMULATED (tests/spikes/touch_sim.gd); nothing here ran on a phone. Ends with " N checks, M failures".

const TEMP_CFG := "user://gameplan_touch_test.cfg"

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
	print("check_touch_gameplan: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _relaunch_with_touch_emulation() -> void:
	if "--touch-child" in OS.get_cmdline_user_args():
		print("FAIL touch emulation did not take effect in the child run")
		print("check_touch_gameplan: 1 checks, 1 failures")
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
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", proj, "res://tests/check_touch_gameplan.tscn", "--", "--touch-child"], out, true)
	if not existed:
		DirAccess.remove_absolute(cfg)
	var text := "\n".join(out)
	for line in text.split("\n"):
		if line.begins_with("ok ") or line.begins_with("FAIL") or line.begins_with("check_touch_gameplan:"):
			print(line)
	if text.find("check_touch_gameplan:") == -1:
		print("FAIL the child run produced no result line (exit %d)" % rc)
		print("check_touch_gameplan: 1 checks, 1 failures")
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


func _detent(t: DetentTrack, i: int) -> Vector2:
	return _c(t, Vector2(t.detent_x(i), DetentTrack.HEAD_H + DetentTrack.TRACK_H * 0.5))


func _show(gp: ScreenGamePlan, ctl: Control) -> void:
	gp.scroll_to(ctl)
	await frames(3)


func _node(gp: ScreenGamePlan, id: String) -> Vector2:
	var i := gp.strip.index_of(id)
	return _c(gp.strip, gp.strip.cell_rect(i).get_center())


func _rows(v: String) -> void:
	await _boot()
	var g: Dictionary = App.gs.next_game()
	var d := ScreenDraft.new(g)
	App.go(d)
	await frames(4)
	d._auto_rest()
	await frames(2)
	var ps: Dictionary = App.gs.plan_set()
	ps["triggers"].clear()
	var gp := ScreenGamePlan.new(g, d.draft)
	App.go(gp)
	await frames(5)
	# the phase strip
	await sim.tap(_node(gp, "early"))
	ok(gp._phase == "early" and gp.strip.selected_id == "early" and gp.tracks["t"].is_visible_in_tree(), "touch_gameplan_%s: a tap on Early shows the Early page" % v)
	await sim.swipe_angle(_node(gp, "mid"), 90.0, 220.0, true, true)
	await frames(4)
	ok(gp._phase == "early", "touch_gameplan_%s: a sideways swipe across the strip changes nothing" % v)
	# every detent by tap
	var t: DetentTrack = gp.tracks["t"]
	await _show(gp, t)
	var got: Array = []
	for i in [0, 1, 3, 4, 2]:
		await sim.tap(_detent(t, i))
		got.append(int(ps["default"]["t"]))
	ok(got == [-100, -50, 50, 100, 0], "touch_gameplan_%s: a tap on each detent of Tempo sets that value (%s)" % [v, str(got)])
	# by drag
	await sim.drag(_detent(t, 2), _detent(t, 4) - _detent(t, 2), 10)
	var a1 := int(ps["default"]["t"])
	await sim.drag(_detent(t, 4), _detent(t, 0) - _detent(t, 4), 14)
	var a2 := int(ps["default"]["t"])
	await sim.drag(_detent(t, 0), _detent(t, 1) - _detent(t, 0) + Vector2(4, 0), 6)
	var a3 := int(ps["default"]["t"])
	ok(a1 == 100 and a2 == -100 and a3 == -50, "touch_gameplan_%s: dragging the thumb reaches +100, -100 and -50 (%d, %d, %d)" % [v, a1, a2, a3])
	# a vertical swipe on a track scrolls the page (Lane aggression: the middle of the Early page, so there is room both ways)
	var s: DetentTrack = gp.tracks["a"]
	await _show(gp, s)
	var before_s := int(ps["default"]["a"])
	var sc0 := gp.page_scroll.scroll_vertical
	await sim.swipe_angle(_detent(s, 1), 0.0, 200.0, true, true)
	await frames(10)
	ok(gp.page_scroll.scroll_vertical > sc0 and int(ps["default"]["a"]) == before_s, "touch_gameplan_%s: a swipe up that starts on Lane aggression scrolls the page and sets nothing (%d -> %d)" % [v, sc0, gp.page_scroll.scroll_vertical])
	# jungle focus
	await _show(gp, gp.jf_bar)
	var jp := _c(gp.jf_bar, gp.jf_bar.seg_rect(gp.jf_bar.index_of("top")).get_center())
	await sim.tap(jp)
	ok(String(ps["default"]["jf"]) == "top", "touch_gameplan_%s: a tap on Top sets Jungle focus" % v)
	# Coach and Apply
	await sim.tap(_mid(gp.coach_button))
	await frames(8)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "gp_coach", "touch_gameplan_%s: a tap on Coach opens the Coach sheet" % v)
	var sug := GamePlan.suggest(gp._ta, gp._tb, MatchRunner.sim_params(), gp.my_side)
	if gp.coach_apply != null:
		await sim.tap(_mid(gp.coach_apply))
		await frames(8)
	var same := true
	for k in sug:
		same = same and ps["default"][k] == sug[k]
	ok(same and not BottomSheet.is_open(), "touch_gameplan_%s: Apply applies the Coach's plan and closes the sheet" % v)
	await sim.tap(_mid(gp.reset_button))
	await frames(3)
	ok(GamePlan.is_neutral(ps["default"]), "touch_gameplan_%s: Reset makes the plan neutral" % v)
	# the plan sheet (the Undo toasts of Apply and Reset are cleared first: they sit over the bottom of a sheet for 4.5 s)
	for tc in App.main._toasts.get_children():
		tc.queue_free()
	await frames(2)
	await sim.tap(_mid(gp.plan_chip))
	await frames(8)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "gp_plans", "touch_gameplan_%s: a tap on the plan chip opens the plan sheet" % v)
	await sim.tap(_mid(UI.find_tag("gp.plans.behind_early.switch")))
	await frames(8)
	ok(gp._trigger_on("behind_early") and BottomSheet.is_open(), "touch_gameplan_%s: the If behind switch turns that plan on" % v)
	App.main.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(20)
	ok(not BottomSheet.is_open() and _cur() == gp, "touch_gameplan_%s: Android back closes the plan sheet first, the page stays" % v)
	await sim.tap(_mid(gp.plan_chip))
	await frames(8)
	await sim.tap(_mid(UI.find_tag("gp.plans.behind_early")))
	await frames(10)
	ok(gp._tab == "behind_early" and not BottomSheet.is_open(), "touch_gameplan_%s: a tap on the If behind row opens that plan" % v)
	# inert controls in the trigger plan
	await sim.tap(_node(gp, "early"))
	var behind: Dictionary = gp._cur_plan()
	var a: DetentTrack = gp.tracks["a"]
	await _show(gp, a)
	var a_before := int(behind["a"])
	await sim.tap(_detent(a, 4))
	await sim.drag(_detent(a, 2), _detent(a, 0) - _detent(a, 2), 8)
	ok(a.inert == "full" and int(behind["a"]) == a_before, "touch_gameplan_%s: Lane aggression in If behind is inert: taps and drags change nothing" % v)
	await _show(gp, gp.jf_bar)
	var jf_before := String(behind["jf"])
	await sim.tap(_c(gp.jf_bar, gp.jf_bar.seg_rect(gp.jf_bar.index_of("bot")).get_center()))
	ok(String(behind["jf"]) == jf_before, "touch_gameplan_%s: the locked Jungle focus in If behind takes no tap" % v)
	var tt: DetentTrack = gp.tracks["t"]
	await _show(gp, tt)
	await sim.tap(_detent(tt, 4))
	ok(int(behind["t"]) == 100 and tt.inert == "partial", "touch_gameplan_%s: Tempo still works in If behind (only part applies, and it says so)" % v)
	# start
	await sim.tap(_mid(gp.start_button))
	await frames(6)
	ok(_cur() is ScreenMatch, "touch_gameplan_%s: a tap on Start the match starts the match" % v)
