extends Node
## I-10 finger rows on the REAL DetentTrack, PhaseStrip, RankRow and Podium (build plan I-10, S1 rule of SPIKE-RESULTS-0.7), in
## check_touch_cards style:
##   DetentTrack: a tap on a detent gives it; a tap with 6 px of jitter still does; 11 px of travel is a tap and 14 px is a drag (12 px
##   slop, measured on the screen); a drag of the thumb moves it and the page does NOT scroll; a swipe that starts on the track and goes
##   up or down (straight, or slanted 20 degrees) scrolls the page and leaves the value alone; a swipe that starts OUTSIDE the track (the
##   head, the end words, the effect line) scrolls the page; a sideways swipe that starts outside it does nothing; an inert track takes
##   neither a tap nor a drag and lets the page scroll; a drag to a detent ends in the same state as set_value() from code.
##   PhaseStrip, RankRow, Podium: a tap selects / presses / emits, 14 px of travel does not, a swipe that starts on them scrolls the page.
## The same rows in large text (widths change; the 12 px slop does not).
## A scroll container only takes touch drags when a touchscreen exists, so this needs `override.cfg` with
## pointing/emulate_touch_from_mouse=true; the scene relaunches itself once with that file in place and relays the result.
## Touch is SIMULATED (events pushed into the viewport, tests/spikes/touch_sim.gd); nothing here ran on a phone.
## Ends with " N checks, M failures".

const FILLER_TOP := 200.0

var fails := 0
var checks := 0
var sim
var _rig: Control
var _page: ScrollContainer


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame
	if not DisplayServer.is_touchscreen_available():
		_relaunch_with_touch_emulation()
		return
	await _run()
	print("check_touch_plan: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _relaunch_with_touch_emulation() -> void:
	if "--touch-child" in OS.get_cmdline_user_args():
		print("FAIL touch emulation did not take effect in the child run")
		print("check_touch_plan: 1 checks, 1 failures")
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
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", proj, "res://tests/check_touch_plan.tscn", "--", "--touch-child"], out, true)
	if not existed:
		DirAccess.remove_absolute(cfg)
	var text := "\n".join(out)
	for line in text.split("\n"):
		if line.begins_with("ok ") or line.begins_with("FAIL") or line.begins_with("ROW|") or line.begins_with("check_touch_plan:"):
			print(line)
	if text.find("check_touch_plan:") == -1:
		print("FAIL the child run produced no result line (exit %d)" % rc)
		print("check_touch_plan: 1 checks, 1 failures")
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
		UI.animate = false
		await _track_rows(variant)
		await _strip_rows(variant)
		await _standings_rows(variant)
	App.apply_large_text(false)
	UI.animate = true


# ---- rigs ------------------------------------------------------------------------------------------------------------------

func _clear() -> void:
	if _rig != null and is_instance_valid(_rig):
		_rig.queue_free()
		await frames(2)
	_rig = null


## A scrolling page (as every screen has): a filler, then `content`, then a long filler.
func _make_page(content: Control, below: float = 2400.0) -> ScrollContainer:
	_rig = Control.new()
	_rig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rig)
	var page := ScrollContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rig.add_child(page)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(v)
	var top := Panel.new()
	top.custom_minimum_size = Vector2(0, FILLER_TOP)
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(top)
	v.add_child(content)
	var bottom := Panel.new()
	bottom.custom_minimum_size = Vector2(0, below)
	bottom.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(bottom)
	return page


func _column(children: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	for c in children:
		col.add_child(c)
	return col


func _jitter_tap(c: Vector2, d: Vector2) -> void:
	sim.finger("down", c)
	await frames(1)
	sim.finger("move", c + d, d)
	await frames(1)
	sim.finger("up", c + d)
	await frames(3)


# ---- the DetentTrack -----------------------------------------------------------------------------------------------------------

func _track_rows(variant: String) -> void:
	await _clear()
	var calls: Array = []
	var t := DetentTrack.new("t", 0, func(id: String, v: int) -> void: calls.append([id, v]), {}, "tt")
	var inert := DetentTrack.new("a", 50)
	inert.set_inert("full")
	var code := DetentTrack.new("t", 0)
	_page = _make_page(_column([t, inert, code]))
	await frames(4)
	var tr := t.global_track_rect()
	ok(tr.size.y >= 96.0 and tr.size.x > 500.0 and tr.end.y < 1280.0 and tr.position.y >= 0.0, "%s: the real track is %.0f x %.0f on the screen (%s)" % [variant, tr.size.x, tr.size.y, str(tr)])
	# taps
	await sim.tap(t.global_detent_pos(4))
	ok(t.value == 100 and calls == [["t", 100]], "%s: a tap on the right-hand detent gives +100 (%s)" % [variant, str(calls)])
	calls.clear()
	await sim.tap(t.global_detent_pos(0))
	ok(t.value == -100 and calls == [["t", -100]], "%s: a tap on the left-hand detent gives -100 (%s)" % [variant, str(calls)])
	t.set_value(0)
	calls.clear()
	var c2 := t.global_detent_pos(3)
	await _jitter_tap(c2, Vector2(6, 2))
	ok(t.value == 50 and calls == [["t", 50]], "%s: a tap with 6 px of finger jitter still gives +50 (%s)" % [variant, str(calls)])
	t.set_value(0)
	calls.clear()
	var c0 := t.global_detent_pos(2)
	await _jitter_tap(c0, Vector2(11, 0))
	var under: Array = t.decisions.duplicate()
	ok(under.is_empty() and t.value == 0, "%s: 11 px of travel is a tap (decisions %s, value %d)" % [variant, str(under), t.value])
	await _jitter_tap(c0, Vector2(14, 0))
	ok(t.decisions == ["h"] and t.value == 0 and calls.is_empty(), "%s: 14 px is a drag, decided horizontal; the thumb ends on the detent it started on (value %d)" % [variant, t.value])
	# a drag of the thumb: it moves, the page does not scroll
	t.decisions.clear()
	var s0: int = _page.scroll_vertical
	var tpos := t.global_detent_pos(2)
	var dx := t.global_detent_pos(4).x - tpos.x
	await sim.drag(tpos, Vector2(dx, 0.0), 16)
	await sim.frames(4)
	var values: Array = []
	for c in calls:
		values.append(c[1])
	ok(t.value == 100 and values == [50, 100] and _page.scroll_vertical == s0 and t.decisions == ["h"], "%s: a drag of the thumb from the middle to the right end gives +50 then +100 and the page does not scroll (%s, scroll %d -> %d)" % [variant, str(values), s0, _page.scroll_vertical])
	# code and drag end in the same place
	code.set_value(100)
	await frames(2)
	ok(t.value == code.value and t.value_word() == code.value_word() and t.effect_text() == code.effect_text() and t.state_name() == code.state_name() and CompKit.cue_of(t) == CompKit.cue_of(code), "%s: the drag and set_value(100) end in the same value, word, effect, state and cue ('%s', %s)" % [variant, t.value_word(), t.state_name()])
	# a drag back across to the left end passes every detent
	calls.clear()
	await sim.drag(t.global_detent_pos(4), Vector2(t.global_detent_pos(0).x - t.global_detent_pos(4).x, 0.0), 32)
	await sim.frames(3)
	values.clear()
	for c in calls:
		values.append(c[1])
	ok(t.value == -100 and values == [50, 0, -50, -100], "%s: a drag from end to end calls back once per detent (%s)" % [variant, str(values)])
	# swipes that start on the track scroll the page and leave the value alone (straight up, slanted, down)
	t.set_value(50)
	calls.clear()
	var good := 0
	for spec in [[0.0, true], [20.0, true], [0.0, false]]:
		_page.scroll_vertical = 0
		await frames(3)
		t.decisions.clear()
		var p0: int = _page.scroll_vertical
		var start := t.global_detent_pos(2) + Vector2(30, 0)
		if not bool(spec[1]):
			_page.scroll_vertical = 120
			await frames(3)
			p0 = _page.scroll_vertical
			start = t.global_detent_pos(2) + Vector2(30, 0)
		await sim.swipe_angle(start, float(spec[0]), 220.0, bool(spec[1]), true)
		await sim.frames(8)
		var moved := absf(float(_page.scroll_vertical - p0))
		var good_one := moved >= 100.0 and t.value == 50 and calls.is_empty() and t.decisions == ["v"]
		if good_one:
			good += 1
		ok(good_one, "%s: a %d deg swipe %s that starts on the track scrolls the page by %.0f px and leaves the value alone (value %d, decisions %s)" % [variant, int(spec[0]), "up" if spec[1] else "down", moved, t.value, str(t.decisions)])
	ok(good == 3, "%s: %d of 3 swipes that start on the track scroll the page" % [variant, good])
	# a swipe that starts outside the track (the head, the end words, the effect line) scrolls the page
	var outs := 0
	for k in 3:
		_page.scroll_vertical = 0
		await frames(3)
		var org := t.get_global_transform().origin
		var spot := Vector2.ZERO
		if k == 0:
			spot = Vector2(org.x + t.size.x * 0.4, org.y + DetentTrack.HEAD_H * 0.5)    # the head
		elif k == 1:
			spot = Vector2(t.global_detent_pos(2).x, org.y + DetentTrack.HEAD_H + DetentTrack.TRACK_H + 12.0)    # the end words row
		else:
			spot = Vector2(t.global_detent_pos(1).x, org.y + DetentTrack.HEAD_H + DetentTrack.TRACK_H + DetentTrack.ENDS_H + 10.0)    # the effect line
		var p1: int = _page.scroll_vertical
		await sim.swipe_angle(spot, 0.0, 220.0, true, true)
		await sim.frames(8)
		var moved2 := absf(float(_page.scroll_vertical - p1))
		if moved2 >= 100.0 and t.value == 50 and calls.is_empty():
			outs += 1
		ok(moved2 >= 100.0 and t.value == 50 and calls.is_empty(), "%s: a swipe that starts in the %s scrolls the page by %.0f px and changes nothing (value %d)" % [variant, ["head", "end words", "effect line"][k], moved2, t.value])
	# a sideways swipe that starts outside the track changes nothing (and a page that cannot scroll sideways stays)
	_page.scroll_vertical = 0
	await frames(3)
	var s2: int = _page.scroll_vertical
	var head_c := t.get_global_transform() * Vector2(t.size.x * 0.4, DetentTrack.HEAD_H * 0.5)
	var ends_y := t.get_global_transform().origin.y + DetentTrack.HEAD_H + DetentTrack.TRACK_H + 12.0
	await sim.swipe_angle(head_c, 90.0, 240.0, true, false)
	await sim.frames(6)
	ok(t.value == 50 and calls.is_empty() and _page.scroll_vertical == s2, "%s: a sideways swipe that starts in the head changes nothing (value %d)" % [variant, t.value])
	# a tap that starts in the head or in the end words is not a tap on the track
	await sim.tap(Vector2(t.global_detent_pos(4).x, head_c.y))
	await sim.tap(Vector2(t.global_detent_pos(4).x, ends_y))
	ok(t.value == 50 and calls.is_empty(), "%s: a tap in the head or on the end words does not change the value" % variant)
	# the inert track
	var ig := inert.global_track_rect()
	_page.scroll_vertical = 0
	await frames(3)
	var iv: int = inert.value
	await sim.tap(inert.global_detent_pos(0))
	await sim.drag(inert.global_detent_pos(2), Vector2(inert.global_detent_pos(4).x - inert.global_detent_pos(2).x, 0.0), 12)
	ok(inert.value == iv and ig.size.y >= 96.0, "%s: an inert track ignores a tap and a drag (value %d)" % [variant, inert.value])
	var p3: int = _page.scroll_vertical
	await sim.swipe_angle(inert.global_detent_pos(2), 0.0, 220.0, true, true)
	await sim.frames(8)
	ok(_page.scroll_vertical - p3 >= 100 and inert.value == iv, "%s: a swipe that starts on an inert track scrolls the page by %d px" % [variant, _page.scroll_vertical - p3])
	await _clear()


# ---- the PhaseStrip ---------------------------------------------------------------------------------------------------------------

func _strip_rows(variant: String) -> void:
	await _clear()
	var picks: Array = []
	var st := PhaseStrip.new(PhaseStrip.default_phases(), "overall", func(id: String) -> void: picks.append(id), false, "ts")
	_page = _make_page(_column([st]))
	await frames(4)
	var r2 := st.global_cell_rect(2)
	ok(r2.size.x > 130.0 and r2.size.y >= 96.0 and r2.end.y < 1280.0, "%s: the third node's cell is %.0f x %.0f on the screen" % [variant, r2.size.x, r2.size.y])
	await sim.tap(r2.get_center())
	ok(picks == ["mid"] and st.selected_id == "mid", "%s: a tap on the third node selects Mid (%s)" % [variant, str(picks)])
	await _jitter_tap(st.global_cell_rect(3).get_center(), Vector2(6, 2))
	ok(picks == ["mid", "late"], "%s: a tap with 6 px of jitter still selects (%s)" % [variant, str(picks)])
	await _jitter_tap(st.global_cell_rect(1).get_center(), Vector2(14, 0))
	ok(picks == ["mid", "late"], "%s: 14 px of travel selects nothing" % variant)
	var p0: int = _page.scroll_vertical
	await sim.swipe_angle(st.global_cell_rect(1).get_center(), 0.0, 220.0, true, true)
	await sim.frames(8)
	ok(_page.scroll_vertical - p0 >= 100 and picks == ["mid", "late"], "%s: a swipe that starts on a node scrolls the page by %d px and selects nothing" % [variant, _page.scroll_vertical - p0])
	await _clear()
	# the vertical form
	var vp: Array = []
	var vs := PhaseStrip.new(["early", "mid", "late"], "early", func(id: String) -> void: vp.append(id), true)
	_page = _make_page(_column([vs]))
	await frames(4)
	await sim.tap(vs.global_cell_rect(2).get_center() - Vector2(vs.global_cell_rect(2).size.x * 0.5 - 20.0, 0.0))
	ok(vp == ["late"], "%s: in the vertical form a tap in the third row selects Late (%s)" % [variant, str(vp)])
	await _clear()


# ---- RankRow and Podium -------------------------------------------------------------------------------------------------------------

func _standings_rows(variant: String) -> void:
	await _clear()
	var taps: Array = []
	var row := RankRow.new({"rank": 7, "club": "cl_a", "name": "Duskwater Foxes", "main": "9", "sub": "1-0"}, "tr")
	row.pressed.connect(func(id: String) -> void: taps.append(id))
	var pod_taps: Array = []
	var pod := Podium.new([{"rank": 1, "club": "cl_a", "name": "Emberfen Hounds", "main": "3"}, {"rank": 2, "club": "cl_b", "name": "Northreach Corsairs", "main": "3"}, {"rank": 3, "club": "cl_c", "name": "Stormvale Herons", "main": "3"}])
	pod.column_tapped.connect(func(id: String) -> void: pod_taps.append(id))
	_page = _make_page(_column([pod, row]))
	await frames(4)
	var rc := row.get_global_rect().get_center()
	await sim.tap(rc)
	ok(taps == ["cl_a"], "%s: a tap on a RankRow emits pressed (%s)" % [variant, str(taps)])
	await _jitter_tap(rc, Vector2(14, 0))
	ok(taps == ["cl_a"], "%s: 14 px of travel on a RankRow is no tap" % variant)
	_page.scroll_vertical = 0
	await frames(2)
	var p0: int = _page.scroll_vertical
	await sim.swipe_angle(row.get_global_rect().get_center(), 0.0, 220.0, true, true)
	await sim.frames(8)
	ok(_page.scroll_vertical - p0 >= 100 and taps == ["cl_a"], "%s: a swipe that starts on a RankRow scrolls the page by %d px and presses nothing" % [variant, _page.scroll_vertical - p0])
	_page.scroll_vertical = 0
	await frames(3)
	await sim.tap(pod.global_column_rect(2).get_center() + Vector2(0, 90.0))
	await sim.tap(pod.global_column_rect(1).get_center() + Vector2(0, 90.0))
	ok(pod_taps == ["cl_b", "cl_a"], "%s: a tap on the left and the middle column gives 2nd and 1st (%s)" % [variant, str(pod_taps)])
	await _jitter_tap(pod.global_column_rect(3).get_center(), Vector2(0, 14))
	ok(pod_taps == ["cl_b", "cl_a"], "%s: 14 px of travel on a podium column is no tap" % variant)
	var p1: int = _page.scroll_vertical
	await sim.swipe_angle(pod.global_column_rect(1).get_center(), 0.0, 220.0, true, true)
	await sim.frames(8)
	ok(_page.scroll_vertical - p1 >= 100 and pod_taps == ["cl_b", "cl_a"], "%s: a swipe that starts on the podium scrolls the page by %d px and taps nothing" % [variant, _page.scroll_vertical - p1])
	await _clear()
