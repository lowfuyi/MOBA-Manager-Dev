extends Node
## I-12 checks, part 2 (finger rows): the 8 S2 rows of SPIKE-RESULTS-0.7 (build plan 9.5, TUTORIAL B11) re-run on the REAL CoachOverlay
## (on Main's overlay slot, CanvasLayer 100) and the REAL BottomSheet (layer 20), in normal and large text:
##   control   with the four dim panels hidden the same taps DO reach the sheet panel and the scrim (the leak is detectable)
##   hole      a tap in the middle of the hole presses the sheet button; nothing else reacts
##   dim       taps on the four dim panels, over the scrim and over the page button are swallowed
##   edge      the first pixel inside the hole presses, 2 px outside is swallowed
##   margin    a tap in the 8 px margin of the hole (outside the button) reaches the sheet panel, not the scrim
##   info      an info step's blocker over the hole swallows the tap
##   moves     the hole moves to a second target: it presses, the old target is blocked
##   drag      a drag that starts in the hole and leaves it does not press the button
## plus what the spike did not test: a drag that starts in the hole scrolls the sheet's content and presses nothing, the card buttons
## take a finger, a drag on the dim is not a stray tap, a tap-elsewhere run at every step of the real runner (nothing advances, nothing
## below changes, the nudge counts), the passthrough step 19 lets taps reach the page, and the 27 steps with real finger taps.
## A scroll container only takes touch drags when a touchscreen exists, so this needs `override.cfg` with
## pointing/emulate_touch_from_mouse=true (as check_touch_gestures does); the scene relaunches itself once with that file in place.
## Touch is SIMULATED (events pushed into the viewport, tests/spikes/touch_sim.gd); nothing here ran on a phone.
## Ends with " N checks, M failures".

const Stub = preload("res://tests/tutorial_stub.gd")
const TEMP_CFG := "user://tut_touch_test.cfg"

var fails := 0
var checks := 0
var sim
var _main: Control
var _overlay: CoachOverlay
var _page_btn: Button
var _sheet_btn: Button
var _sheet_btn2: Button
var _sheet: BottomSheet
var _counts := {"btn": 0, "btn2": 0, "page": 0, "scrim": 0, "panel": 0}


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func until(cond: Callable, max_frames: int = 60) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _ready() -> void:
	TutorialRunner.home_offers = false    # I-14: Home's welcome modal and offer cards depend on this machine's settings.cfg; tested in check_tutorial_flow
	await get_tree().process_frame
	if not DisplayServer.is_touchscreen_available():
		_relaunch_with_touch_emulation()
		return
	await _run()
	print("check_touch_tutorial: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _relaunch_with_touch_emulation() -> void:
	if "--touch-child" in OS.get_cmdline_user_args():
		print("FAIL touch emulation did not take effect in the child run")
		print("check_touch_tutorial: 1 checks, 1 failures")
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
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", proj, "res://tests/check_touch_tutorial.tscn", "--", "--touch-child"], out, true)
	if not existed:
		DirAccess.remove_absolute(cfg)
	var text := "\n".join(out)
	for line in text.split("\n"):
		if line.begins_with("ok ") or line.begins_with("FAIL") or line.begins_with("check_touch_tutorial:"):
			print(line)
	if text.find("check_touch_tutorial:") == -1:
		print("FAIL the child run produced no result line (exit %d)" % rc)
		print("check_touch_tutorial: 1 checks, 1 failures")
		get_tree().quit(1)
		return
	get_tree().quit(rc)


func _run() -> void:
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	sim = load("res://tests/spikes/touch_sim.gd").new(self)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	for variant in ["normal", "large"]:
		App.apply_large_text(variant == "large")
		await frames(3)
		await _fresh_main()
		await _s2(variant)
		await _extras(variant)
		await _tap_elsewhere_run(variant)
	await _full_run_with_fingers()
	App.apply_large_text(false)
	UI.animate = true
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))


func _fresh_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false    # tween-free: the numbers read after a gesture are the gesture's own
	await frames(3)
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], 20261109)
	App.go(ScreenHub.new())
	await frames(3)
	var real_card := UI.find_tag("home.next_card")
	if real_card != null:
		real_card.hide()    # I-15: Home now carries the real home.next_card; this suite tests the overlay on the stub's targets
	App.tutorial.autosave = false
	App.tutorial.device = DeviceState.new(TEMP_CFG)


func _card(id: String, targets: Array, kind: String = "tap", stage: String = "a") -> Dictionary:
	return {"id": id, "step_no": 12, "chapter": 4, "chapter_key": "tut.ch.4", "kind": kind, "dim": "full", "stage": stage, "target": targets,
			"key": "tut.ban", "compact": true, "buttons": ["skip", "next"] if kind == "info" else ["skip"], "shortcut_key": "", "shortcut_does": "",
			"hold_armed": false, "passthrough": false, "skip": "B", "screen": "draft", "screen_now": "draft"}


## The S2 rig on the real components: a page button (layer 0), a real sheet (size M, counting scrim and panel), the real overlay.
func _rig() -> void:
	for k in _counts:
		_counts[k] = 0
	var s := BottomSheet.current()
	if s != null:
		s.close()
		await frames(3)
	_page_btn = Button.new()
	_page_btn.text = "page"
	_page_btn.position = Vector2(100, 300)
	_page_btn.size = Vector2(300, 96)
	_page_btn.pressed.connect(func() -> void: _counts["page"] += 1)
	_main.add_child(_page_btn)
	var build_content := func(content: VBoxContainer) -> void:
		_sheet_btn2 = Button.new()
		_sheet_btn2.text = "Other"
		_sheet_btn2.custom_minimum_size = Vector2(300, 96)
		_sheet_btn2.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_sheet_btn2.mouse_filter = Control.MOUSE_FILTER_PASS
		_sheet_btn2.pressed.connect(func() -> void: _counts["btn2"] += 1)
		content.add_child(_sheet_btn2)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 200)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(spacer)
	var build_footer := func(footer: VBoxContainer) -> void:
		_sheet_btn = BottomSheet.footer_button(footer, "Pick", func() -> void: _counts["btn"] += 1)
		_sheet_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		_sheet_btn.custom_minimum_size.x = 260
	_sheet = BottomSheet.open("S2 sheet", build_content, build_footer, "M", "s2")
	_sheet.scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_counts["scrim"] += 1)
	_sheet.panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			var g: Vector2 = _sheet.panel.get_global_transform() * (e as InputEventMouseButton).position
			for b in [_sheet_btn, _sheet_btn2, _sheet.close_button]:
				if (b as Control).get_global_rect().has_point(g):
					return
			_counts["panel"] += 1)
	await frames(5)
	UI.tag(_sheet_btn, "s2.btn", false)
	UI.tag(_sheet_btn2, "s2.btn2", false)
	_overlay = CoachOverlay.new()
	_overlay.theme = _main.theme
	_main.overlay_layer.add_child(_overlay)


func _show(card: Dictionary) -> void:
	_overlay.show_step(card, "Touch me.")
	await until(func() -> bool: return _overlay.mode == "shown", 40)
	await frames(2)


func _c() -> Array:
	return [_counts["btn"], _counts["btn2"], _counts["page"], _counts["scrim"], _counts["panel"]]


func _free_rig() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.clear()
		_overlay.queue_free()
	if _page_btn != null and is_instance_valid(_page_btn):
		_page_btn.queue_free()
	var s := BottomSheet.current()
	if s != null:
		s.close()
	await frames(4)


func _s2(variant: String) -> void:
	await _rig()
	var screen := _main.get_viewport_rect().size
	await _show(_card("s2a", ["s2.btn"]))
	var c := _sheet_btn.get_global_rect().get_center()
	ok(_sheet != null and BottomSheet.current() == _sheet and _sheet_btn.get_global_rect().size.y >= 103.0 and _overlay.get_parent() == _main.overlay_layer, "S2 %s: the real sheet (M) is open with its footer button, the real overlay is on CanvasLayer 100 (%s)" % [variant, str(_sheet_btn.get_global_rect())])
	ok(_overlay.hole_rect() == _sheet_btn.get_global_rect().grow(8.0), "S2 %s: the overlay's hole is the footer button plus 8 px %s" % [variant, str(_overlay.hole_rect())])
	# 0. control: without the dim panels the same taps reach the sheet panel and the scrim
	for d in _overlay.dims:
		d.visible = false
	await frames(2)
	var pr := _sheet.panel.get_global_rect()
	await sim.tap(pr.position + Vector2(pr.size.x * 0.5, 40))
	await sim.tap(Vector2(screen.x * 0.5, 100))
	ok(_counts["panel"] == 1 and _counts["scrim"] == 1, "S2 %s: control: without the dim panels, taps reach the sheet panel and the scrim %s" % [variant, str(_c())])
	await frames(4)
	ok(not BottomSheet.is_open(), "S2 %s: control: the leaked scrim tap closed the real sheet (the leak is detectable)" % variant)
	await _free_rig()
	await _rig()
	await _show(_card("s2a", ["s2.btn"]))
	c = _sheet_btn.get_global_rect().get_center()
	# 1. a tap in the middle of the hole presses the sheet button; nothing else reacts
	await sim.tap(c)
	ok(_c() == [1, 0, 0, 0, 0] and BottomSheet.is_open(), "S2 %s: a tap in the hole presses the sheet button; nothing else reacts %s" % [variant, str(_c())])
	# 2. the four dim panels, the scrim and the page button are shielded
	var before: Array = _c().duplicate()
	var h := _overlay.hole_rect()
	var cr := _overlay.card_rect()
	var probes := {"top": Vector2(6.0, h.position.y - 100.0), "bottom": Vector2(6.0, screen.y - 3.0),
			"left": Vector2(h.position.x - 20.0, h.get_center().y), "right": Vector2(h.end.x + 4.0, h.get_center().y),
			"over the scrim": Vector2(6.0, 100.0), "over the page button": _page_btn.get_global_rect().get_center()}
	var covered: Array = []
	for k in probes:
		if cr.has_point(probes[k]):
			covered.append(k)    # a probe that lands on the card would test the card, not the panel
		await sim.tap(probes[k])
	await frames(3)
	ok(_c() == before and BottomSheet.is_open() and covered.is_empty(), "S2 %s: taps on the four dim panels, over the scrim and over the page button are swallowed %s -> %s (on the card: %s)" % [variant, str(before), str(_c()), str(covered)])
	# 3. edge
	before = _c().duplicate()
	await sim.tap(h.position + Vector2(12, 12))
	var after_in: Array = _c().duplicate()
	await sim.tap(h.position + Vector2(-2, 20))
	var after_out: Array = _c().duplicate()
	ok(after_in[0] == before[0] + 1 and after_out == after_in, "S2 %s: edge: the first pixel inside the hole presses, 2 px outside is swallowed %s %s %s" % [variant, str(before), str(after_in), str(after_out)])
	# 4. the 8 px margin reaches the sheet panel, not the scrim
	before = _c().duplicate()
	await sim.tap(Vector2(h.position.x + 3, h.position.y + 3))
	ok(_counts["panel"] == before[4] + 1 and _counts["scrim"] == before[3] and BottomSheet.is_open(), "S2 %s: a tap in the 8 px margin of the hole reaches the sheet panel, not the scrim %s" % [variant, str(_c())])
	# 5. an info step's blocker
	await _show(_card("s2info", ["s2.btn"], "info"))
	before = _c().duplicate()
	ok(_overlay.blocker_on(), "S2 %s: an info step puts the blocker over the hole" % variant)
	await sim.tap(c)
	ok(_c() == before, "S2 %s: info step: the blocker over the hole swallows the tap %s" % [variant, str(_c())])
	# 6. the hole moves to a second target
	await _show(_card("s2b", ["s2.btn2"]))
	before = _c().duplicate()
	await sim.tap(_sheet_btn2.get_global_rect().get_center())
	await sim.tap(c)
	ok(_counts["btn2"] == 1 and _counts["btn"] == before[0], "S2 %s: the hole follows to a second target: it presses, the old target is blocked %s" % [variant, str(_c())])
	# 7. a drag that starts in the hole and leaves it
	await _show(_card("s2a", ["s2.btn"]))
	before = _c().duplicate()
	await sim.drag(c, Vector2(0, -90), 6)
	ok(_counts["btn"] == before[0] and BottomSheet.is_open(), "S2 %s: a drag that starts in the hole and leaves it does not press the button %s" % [variant, str(_c())])
	# 8. (not in the spike) a drag that starts in the hole scrolls the sheet's content and presses nothing
	var filler := Control.new()
	filler.custom_minimum_size = Vector2(0, 1500)
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.content.add_child(filler)
	await frames(4)
	await _show(_card("s2b", ["s2.btn2"]))
	var sv0: int = _sheet._scroll.scroll_vertical
	var b2: int = _counts["btn2"]
	# the finger goes down in the hole, moves 120 px up and stays: the hole follows the target while the finger is held
	var start := _sheet_btn2.get_global_rect().get_center()
	sim.finger("down", start)
	await frames(1)
	var pos := start
	for i in 6:
		pos += Vector2(0, -20)
		sim.finger("move", pos, Vector2(0, -20))
		await frames(1)
	await frames(4)
	var want := _sheet_btn2.get_global_rect().grow(8.0).intersection(Rect2(Vector2.ZERO, screen))
	ok(_sheet._scroll.scroll_vertical > sv0 + 50 and _overlay.hole_rect() == want, "S2 %s: while the finger drags the sheet's content from inside the hole, the hole follows the target (%s vs %s)" % [variant, str(_overlay.hole_rect()), str(want)])
	sim.finger("up", pos)
	await frames(4)
	ok(_counts["btn2"] == b2 and BottomSheet.is_open(), "S2 %s: a drag that starts in the hole scrolls the sheet's content (%+d) and presses nothing" % [variant, _sheet._scroll.scroll_vertical - sv0])
	await _free_rig()


# ---- what the spike did not test ------------------------------------------------------------------------------------------------------

func _extras(variant: String) -> void:
	await _rig()
	await _show(_card("x1", ["s2.btn"], "info"))
	var pressed: Array = []
	_overlay.button_pressed.connect(func(id: String) -> void: pressed.append(id))
	# the card buttons take a finger
	var skip := _overlay.skip_button
	var next := _overlay.primary_button
	ok(skip != null and next != null and skip.size.y >= 95.5 and next.size.y >= 95.5, "card %s: Skip and Next are 96 px high (%.0f, %.0f)" % [variant, skip.size.y, next.size.y])
	await sim.tap(next.get_global_rect().get_center())
	await sim.tap(skip.get_global_rect().get_center())
	await frames(2)
	ok(pressed == ["next", "skip"], "card %s: a finger on Next and on Skip raises next and skip (%s)" % [variant, str(pressed)])
	ok(_c() == [0, 0, 0, 0, 0], "card %s: the finger on the card buttons reached nothing below %s" % [variant, str(_c())])
	# a drag on the dim is not a stray tap; a tap is
	var h := _overlay.hole_rect()
	var n0 := _overlay.nudges
	await sim.drag(Vector2(6, 200), Vector2(0, 80), 6)
	ok(_overlay.nudges == n0, "card %s: a drag on the dim is swallowed and is not a stray tap" % variant)
	await sim.tap(Vector2(6, 200))
	ok(_overlay.nudges == n0 + 1, "card %s: a tap on the dim is a stray tap" % variant)
	# the passthrough step (19): no dim, taps reach the page, the card still takes a finger
	await _show({"id": "watch", "step_no": 19, "chapter": 5, "chapter_key": "tut.ch.5", "kind": "event", "dim": "none", "stage": "a", "target": ["s2.btn"], "key": "tut.watch",
			"compact": false, "buttons": ["skip"], "shortcut_key": "", "shortcut_does": "", "hold_armed": false, "passthrough": true, "skip": "B", "screen": "match", "screen_now": "match"})
	var cr2 := _overlay.card_rect()
	ok(not _overlay.panels_on() and not _overlay.blocker_on() and _overlay.hole_rect().size.x > 0.0, "card %s: step 19 draws the ring only: no dim, no blocker" % variant)
	# a page button outside the ring and the card
	_page_btn.position = Vector2(100, 60)
	await frames(2)
	await sim.tap(_page_btn.get_global_rect().get_center())
	ok(_counts["scrim"] == 1 and not cr2.intersects(_page_btn.get_global_rect()), "card %s: with no dim a tap goes through the overlay to the layer below it (the sheet's scrim here: %s)" % [variant, str(_c())])
	await _free_rig()


## The finger action that moves the step on: Start / Next / Go to Home / Apply for me on the card, Pick in the sheet for the role
## step, otherwise a tap at the middle of the hole.
func _act(r: TutorialRunner, o: CoachOverlay) -> void:
	var sid := r.m.step_id()
	var ids := o.button_ids()
	if sid == "coach_rest" and r.m.stage == "a" and ids.has("shortcut"):
		await sim.tap(o.primary_button.get_global_rect().get_center())    # Let the Coach finish (one tap)
	elif sid == "coach_suggest" and r.m.stage == "b" and ids.has("shortcut"):
		await sim.tap(o.primary_button.get_global_rect().get_center())    # Apply for me (one tap)
	elif sid in ["welcome", "finish"] or String(r.m.step().get("kind", "")) == "info" or (r.m.stage == "b" and ids.has("next")):
		await sim.tap(o.primary_button.get_global_rect().get_center())
	elif sid == "role":
		await sim.tap(UI.find_tag("draft.sheet.confirm").get_global_rect().get_center())    # Pick; a tap on the lane row only chooses a lane
	else:
		await sim.tap(o.hole_rect().get_center())


var _calls: Array = []


func _stub_for(r: TutorialRunner) -> Stub.Stub:
	var stub: Stub.Stub = Stub.add_to(_main)
	_calls.clear()
	# the one-tap shortcuts: the registered code path runs and the step's event follows from it (what the real screens will do)
	r.register_shortcut("draft_auto_finish", func() -> void:
		_calls.append("draft_auto_finish")
		App.bus.emit("draft:done"))
	r.register_shortcut("gp_coach_apply", func() -> void:
		_calls.append("gp_coach_apply")
		App.bus.emit("gp:coach_apply")
		stub.close_sheet())    # the real Apply closes the Coach sheet by itself
	App.main._tabbar.visible = false    # the real tab buttons are hidden: the stub supplies tabbar and tab.* here
	r.wait_s = 3.0
	r.missing_s = 2.0
	r.presented.connect(func(sid: String, st: String) -> void:
		if st == "a":
			stub.placement = TutorialState.step_index(sid) % 3
			stub.build_for(sid))
	return stub


## TUTORIAL test 3: at every step of the real runner, finger taps at points outside the hole and the card change nothing, and the
## nudge counts them; the finger run still reaches done.
func _tap_elsewhere_run(variant: String) -> void:
	await _fresh_main()
	var r: TutorialRunner = App.tutorial
	var stub := _stub_for(r)
	var bad: Array = []
	var gs_before: Dictionary = App.gs.d.duplicate(true)
	gs_before.erase("tutorial")
	r.accept()
	var screen := _main.get_viewport_rect().size
	var strays := 0
	var last := ""
	var guard := 0
	while r.m.state() == "running" and guard < 80:
		guard += 1
		await until(func() -> bool: return r.overlay != null and r.overlay.mode == "shown", 40)
		var o := r.overlay
		if o == null or o.mode != "shown":
			bad.append("step %s not shown" % r.m.step_id())
			break
		var sid := r.m.step_id()
		var key := sid + "/" + r.m.stage
		if key != last and String(o.card_data().get("dim", "")) != "none":
			last = key
			var hole := o.hole_rect()
			var n0 := o.nudges
			var tapped := 0
			for p in [Vector2(6, 6), Vector2(screen.x - 6.0, 6), Vector2(6, screen.y - 6.0), Vector2(screen.x - 6.0, screen.y - 6.0), screen * 0.5]:
				await frames(2)    # the second line of the nudge makes the card taller: read its rectangle again for every probe
				if hole.grow(4.0).has_point(p) or o.card_rect().grow(4.0).has_point(p):
					continue
				await sim.tap(p)
				tapped += 1
			strays += tapped
			if o.nudges != n0 + tapped:
				bad.append("%s: %d stray taps counted %d" % [key, tapped, o.nudges - n0])
			if r.m.step_id() != sid or r.m.state() != "running":
				bad.append("%s: a stray tap changed the step" % key)
				break
		await _act(r, o)
		await frames(3)
	ok(bad.is_empty() and strays >= 40, "tap elsewhere %s: %d stray finger taps over the steps changed no step: %s" % [variant, strays, "; ".join(bad) if not bad.is_empty() else "none"])
	ok(r.m.state() == "done" and r.fallbacks == 0, "tap elsewhere %s: the finger run reached done with %d fallbacks (state %s at %s/%s)" % [variant, r.fallbacks, r.m.state(), r.m.step_id(), r.m.stage])
	var after: Dictionary = App.gs.d.duplicate(true)
	after.erase("tutorial")
	ok(JSON.stringify(after) == JSON.stringify(gs_before), "tap elsewhere %s: no stray tap changed the game state" % variant)
	ok(App.main.overlay_layer.get_child_count() == 0, "tap elsewhere %s: no overlay node is left" % variant)
	stub.queue_free()
	await frames(2)


## The 27 steps with finger taps on the hole (through a real sheet for the sheet steps), the one-tap shortcut buttons (15 and 17) and
## the step-19 passthrough with the stub's match button.
func _full_run_with_fingers() -> void:
	App.apply_large_text(false)
	await frames(3)
	await _fresh_main()
	var r: TutorialRunner = App.tutorial
	var stub := _stub_for(r)
	var seen: Array = []
	r.presented.connect(func(sid: String, st: String) -> void: seen.append("%s/%s" % [sid, st]))
	r.accept()
	var guard := 0
	while r.m.state() == "running" and guard < 80:
		guard += 1
		await until(func() -> bool: return r.overlay != null and r.overlay.mode == "shown", 40)
		var o := r.overlay
		if o == null:
			break
		await _act(r, o)
		await frames(3)
	ok(r.m.state() == "done" and r.fallbacks == 0, "fingers: 27 steps by finger taps end in done with %d fallbacks (state %s at %s/%s)" % [r.fallbacks, r.m.state(), r.m.step_id(), r.m.stage])
	ok(_calls == ["draft_auto_finish", "gp_coach_apply"], "fingers: the card's one-tap buttons ran the registered code paths (%s)" % str(_calls))
	ok(seen.size() >= 29, "fingers: every step and stage was presented (%d presentations)" % seen.size())
	ok(App.main.overlay_layer.get_child_count() == 0 and not BottomSheet.is_open(), "fingers: no overlay node and no sheet is left")
	stub.queue_free()
	await frames(2)
