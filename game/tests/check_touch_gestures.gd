extends Node
## I-08 checks, part 2: the finger rows of SPIKE-RESULTS-0.7 re-run on the REAL components (build plan I-08, section 9.5).
##   S1  the 10 swipe rows (5 start angles, 2 directions) on the real Carousel inside a vertical page, in normal and large text,
##       with the taps (a tap, a 6 px jitter tap, a horizontal and a vertical swipe that start on a card), a vertical swipe that
##       starts in the gap between cards, the See all tile (items beyond 8), the Buttons inside the cards staying inert, and a fling
##       that ends on a snap point.
##   S2  the 8 hole-tap rows on the real BottomSheet, with the four dim panels and the info-step blocker on Main's overlay slot
##       (CanvasLayer 100; the real CoachOverlay is I-12), in normal and large text, plus a drag that starts in the hole and scrolls
##       a ScrollContainer inside the sheet (not in the spike).
##   Sheet fingers: a swipe down on the handle, a scroll inside tall content that does not dismiss, a drag that starts on the scrim.
## A scroll container only takes touch drags when a touchscreen exists, so this needs `override.cfg` with
## pointing/emulate_touch_from_mouse=true (as check_gestures does); the scene relaunches itself once with that file in place and
## relays the result. Touch is SIMULATED (events pushed into the viewport, tests/spikes/touch_sim.gd); nothing here ran on a phone.
## Ends with " N checks, M failures".

const Rigs = preload("res://tests/touch_rigs.gd")
const ANGLES := [0.0, 20.0, 40.0, 60.0, 90.0]
const DIST := 240.0

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
	TutorialRunner.home_offers = false    # I-14: Home's welcome modal and offer cards depend on this machine's settings.cfg; tested in check_tutorial_flow
	await get_tree().process_frame
	if not DisplayServer.is_touchscreen_available():
		_relaunch_with_touch_emulation()
		return
	await _run()
	print("check_touch_gestures: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _relaunch_with_touch_emulation() -> void:
	if "--touch-child" in OS.get_cmdline_user_args():
		print("FAIL touch emulation did not take effect in the child run")
		print("check_touch_gestures: 1 checks, 1 failures")
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
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", proj, "res://tests/check_touch_gestures.tscn", "--", "--touch-child"], out, true)
	if not existed:
		DirAccess.remove_absolute(cfg)
	var text := "\n".join(out)
	for line in text.split("\n"):
		if line.begins_with("ok ") or line.begins_with("FAIL") or line.begins_with("ROW|") or line.begins_with("check_touch_gestures:"):
			print(line)
	if text.find("check_touch_gestures:") == -1:
		print("FAIL the child run produced no result line (exit %d)" % rc)
		print("check_touch_gestures: 1 checks, 1 failures")
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
		await _fresh_main()
		await _s1(variant)
		await _s1_extras(variant)
		await _s2(variant)
		await _sheet_fingers(variant)
	await _fling()
	App.apply_large_text(false)
	UI.animate = true


func _fresh_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false    # tween-free: the offsets read after a gesture are the gesture's own
	await frames(3)


# ---- S1 ---------------------------------------------------------------------------------------------------------------

func _page(n_cards: int = 8) -> Rigs.NestedPage:
	var rig := Rigs.NestedPage.new()
	add_child(rig)
	rig.build(n_cards)
	await frames(4)
	return rig


func _s1(variant: String) -> void:
	var rig := await _page()
	var car := rig.carousel
	ok(car.get_parent() != null and car.size.x > 500.0 and car.size.y >= 200.0, "S1 %s: the real Carousel is %.0f x %.0f in the page, %d cards" % [variant, car.size.x, car.size.y, car.card_count()])
	var pass_n := 0
	for dir_up in [true, false]:
		for deg in ANGLES:
			rig.page.scroll_vertical = 360
			car.set_h_offset(300.0)
			await frames(3)
			var p0: int = rig.page.scroll_vertical
			var c0: float = car.h_offset()
			var start: Vector2 = car.get_global_rect().get_center()
			await sim.swipe_angle(start, deg, DIST, dir_up, dir_up)
			await sim.frames(10)
			var page_moved := absf(float(rig.page.scroll_vertical - p0))
			var car_moved := absf(car.h_offset() - c0)
			var dy_exp := absf(cos(deg_to_rad(deg))) * DIST
			var dx_exp := absf(sin(deg_to_rad(deg))) * DIST
			var vertical: bool = deg < 45.0
			var good := (page_moved >= 0.5 * dy_exp and car_moved <= 2.0) if vertical else (car_moved >= 0.5 * dx_exp and page_moved <= 3.0)
			if good:
				pass_n += 1
			ok(good, "S1 %s real carousel %2d deg %-10s page_moved=%5.1f carousel_moved=%5.1f -> expected %s" % [variant, int(deg), "up-left" if dir_up else "down-right", page_moved, car_moved, "page" if vertical else "carousel"])
	ok(pass_n == 10, "S1 %s: %d of 10 swipe rows pass" % [variant, pass_n])
	# the cards hold real Buttons: none was pressed by any of those swipes
	ok(rig.inner_presses == 0 and rig.tapped.is_empty(), "S1 %s: no swipe tapped a card or pressed a Button inside one (%d presses, taps %s)" % [variant, rig.inner_presses, str(rig.tapped)])
	# taps
	rig.page.scroll_vertical = 360
	car.set_h_offset(0.0)
	await frames(3)
	var c: Vector2 = rig.slot_center(1)
	rig.tapped.clear()
	await sim.tap(c)
	ok(rig.tapped == [1], "S1 %s: a tap on card 1 gives card 1 (got %s)" % [variant, str(rig.tapped)])
	rig.tapped.clear()
	sim.finger("down", c)
	await sim.frames(1)
	sim.finger("move", c + Vector2(4, 3), Vector2(4, 3))
	await sim.frames(1)
	sim.finger("move", c + Vector2(6, 0), Vector2(2, -3))
	await sim.frames(1)
	sim.finger("up", c + Vector2(6, 0))
	await sim.frames(3)
	ok(rig.tapped == [1], "S1 %s: a tap with 6 px of finger jitter still gives card 1 (got %s)" % [variant, str(rig.tapped)])
	rig.tapped.clear()
	await sim.swipe_angle(c, 90.0, 160.0, true, true)
	await sim.frames(8)
	ok(rig.tapped.is_empty() and car.h_offset() > 50.0, "S1 %s: a horizontal swipe that starts on a card taps nothing (taps %s, moved %.0f)" % [variant, str(rig.tapped), car.h_offset()])
	car.set_h_offset(0.0)
	rig.tapped.clear()
	await frames(2)
	var p1: int = rig.page.scroll_vertical
	await sim.swipe_angle(c, 0.0, 120.0, true, true)
	await sim.frames(8)
	ok(rig.tapped.is_empty() and rig.page.scroll_vertical > p1 + 40, "S1 %s: a vertical swipe that starts on a card taps nothing and scrolls the page (taps %s, page %+d)" % [variant, str(rig.tapped), rig.page.scroll_vertical - p1])
	# a press just over the slop is a drag, just under is a tap
	rig.tapped.clear()
	rig.page.scroll_vertical = 360
	car.set_h_offset(0.0)
	await frames(3)
	c = rig.slot_center(1)
	sim.finger("down", c)
	await sim.frames(1)
	sim.finger("move", c + Vector2(11, 0), Vector2(11, 0))
	await sim.frames(1)
	sim.finger("up", c + Vector2(11, 0))
	await sim.frames(3)
	var under := rig.tapped.duplicate()
	rig.tapped.clear()
	sim.finger("down", c)
	await sim.frames(1)
	sim.finger("move", c + Vector2(14, 0), Vector2(14, 0))
	await sim.frames(1)
	sim.finger("up", c + Vector2(14, 0))
	await sim.frames(3)
	ok(under == [1] and rig.tapped.is_empty(), "S1 %s: 11 px of travel is a tap, 14 px is a drag (the 12 px slop: %s / %s)" % [variant, str(under), str(rig.tapped)])
	rig.queue_free()
	await frames(2)


func _s1_extras(variant: String) -> void:
	var rig := await _page()
	var car := rig.carousel
	# a vertical swipe that starts in the gap between cards (not in the spike) scrolls the page; a horizontal one scrolls the row
	rig.page.scroll_vertical = 360
	car.set_h_offset(0.0)
	await frames(3)
	var g: Vector2 = rig.gap_point(0)
	ok(car.index_at(car.get_global_transform().affine_inverse() * g) == -1, "S1 %s: the probe point really is in the gap between cards" % variant)
	var p0: int = rig.page.scroll_vertical
	await sim.swipe_angle(g, 0.0, 200.0, true, true)
	await sim.frames(10)
	ok(rig.page.scroll_vertical >= p0 + 100 and car.h_offset() <= 2.0 and rig.tapped.is_empty(), "S1 %s: a vertical swipe that starts in the gap scrolls the page %+d and moves the row %.1f" % [variant, rig.page.scroll_vertical - p0, car.h_offset()])
	rig.page.scroll_vertical = 360
	await frames(3)
	var p1: int = rig.page.scroll_vertical
	await sim.swipe_angle(g, 90.0, 200.0, true, true)
	await sim.frames(10)
	ok(car.h_offset() >= 100.0 and absf(float(rig.page.scroll_vertical - p1)) <= 3.0, "S1 %s: a horizontal swipe that starts in the gap moves the row %.0f and the page %+d" % [variant, car.h_offset(), rig.page.scroll_vertical - p1])
	# a tap in the gap, a tap on the page dots: nothing
	rig.tapped.clear()
	car.set_h_offset(0.0)
	await frames(2)
	await sim.tap(rig.gap_point(0))
	await sim.tap(car.get_global_transform() * Vector2(car.size.x * 0.5, car.card_height() + 20.0))
	ok(rig.tapped.is_empty(), "S1 %s: a tap in the gap or on the dots taps nothing" % variant)
	# a drag on the page that does not start on the carousel scrolls the page and leaves the row alone
	car.set_h_offset(200.0)
	rig.page.scroll_vertical = 200
	await frames(3)
	await sim.swipe_angle(Vector2(360, 300), 0.0, 150.0, true, true)
	await sim.frames(8)
	ok(rig.page.scroll_vertical > 280 and absf(car.h_offset() - 200.0) < 1.0, "S1 %s: a swipe on the page (not on the row) scrolls the page to %d, the row stays" % [variant, rig.page.scroll_vertical])
	rig.queue_free()
	await frames(2)
	# items beyond 8: the See all tile
	var big := await _page(10)
	var bc := big.carousel
	ok(bc.card_count() == 8 and bc.has_see_all_tile(), "S1 %s: 10 items show 8 cards and the See all tile" % variant)
	big.page.scroll_vertical = 360
	bc.scroll_to_index(100, false)
	await frames(3)
	await sim.tap(bc.see_all_tile().get_global_rect().get_center())
	ok(big.see_all_taps == 1 and big.tapped.is_empty(), "S1 %s: a tap on the See all tile runs see_all once and taps no card (%d, %s)" % [variant, big.see_all_taps, str(big.tapped)])
	big.queue_free()
	await frames(2)


func _fling() -> void:
	# animation ON: a fling carries the row and it rests exactly on a snap point
	App.apply_large_text(false)
	await frames(3)
	await _fresh_main()
	UI.animate = true
	var rig := await _page()
	var car := rig.carousel
	rig.page.scroll_vertical = 360
	car.set_h_offset(0.0)
	await frames(3)
	var start: Vector2 = rig.slot_center(0)
	await sim.swipe_angle(start, 90.0, 150.0, true, true)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900:
		await get_tree().process_frame
	var on_snap := false
	for p in car.snap_points():
		on_snap = on_snap or absf(float(p) - car.h_offset()) < 0.6
	ok(car.h_offset() > 100.0 and on_snap, "S1 fling: with animation on the row ends on a snap point after a swipe (offset %.1f of %s)" % [car.h_offset(), str(car.snap_points().slice(0, 4))])
	rig.queue_free()
	UI.animate = false
	await frames(2)


# ---- S2 ---------------------------------------------------------------------------------------------------------------

func _hole(variant: String) -> Rigs.HoleRig:
	var s := BottomSheet.current()
	if s != null:
		s.close()
		await frames(3)
	var rig := Rigs.HoleRig.new()
	rig.build(App.main)
	await frames(5)
	rig.set_hole(rig.target_rect(rig.sheet_btn))
	await frames(2)
	return rig


func _s2(variant: String) -> void:
	var rig := await _hole(variant)
	var c: Vector2 = rig.sheet_btn.get_global_rect().get_center()
	ok(rig.sheet_open() and rig.sheet_btn.get_global_rect().size.y >= 103.0 and rig.screen.y > 1000.0, "S2 %s: the real sheet (M) is open with its footer button at %s" % [variant, str(rig.sheet_btn.get_global_rect())])
	# 0. control: without the dim panels the same taps DO reach the scrim and the sheet panel, so the swallow rows cannot pass by accident
	for d in rig.dims:
		d.visible = false
	await frames(2)
	var pr: Rect2 = rig.sheet.panel.get_global_rect()
	await sim.tap(pr.position + Vector2(pr.size.x * 0.5, 40))
	await sim.tap(Vector2(rig.screen.x * 0.5, 100))
	ok(rig.sheet_panel_taps == 1 and rig.scrim_taps == 1, "S2 %s: control: without the dim panels, taps reach the sheet panel and the scrim %s" % [variant, str(rig.counters())])
	await frames(4)
	ok(not rig.sheet_open(), "S2 %s: control: the leaked scrim tap closed the real sheet (the leak is detectable)" % variant)
	# fresh rig for the rows that need an open sheet
	rig.free_all()
	rig = await _hole(variant)
	c = rig.sheet_btn.get_global_rect().get_center()
	# 1. a tap in the middle of the hole reaches the sheet button; nothing else reacts
	await sim.tap(c)
	ok(rig.counters() == [1, 0, 0, 0, 0] and rig.sheet_open(), "S2 %s: a tap in the hole presses the sheet button; nothing else reacts %s" % [variant, str(rig.counters())])
	# 2. a tap on each dim panel (and over the scrim and over the page button) is swallowed
	var before: Array = rig.counters().duplicate()
	var h: Rect2 = rig.hole
	var probes := {"top": Vector2(rig.screen.x * 0.5, h.position.y - 100.0), "bottom": Vector2(rig.screen.x * 0.5, rig.screen.y - 3.0),
			"left": Vector2(h.position.x - 20.0, h.get_center().y), "right": Vector2(h.end.x + 4.0, h.get_center().y),
			"over the scrim": Vector2(rig.screen.x * 0.5, 100.0), "over the page button": rig.page_btn.get_global_rect().get_center()}
	for k in probes:
		await sim.tap(probes[k])
	await frames(3)
	ok(rig.counters() == before and rig.sheet_open(), "S2 %s: taps on the four dim panels (and over the scrim and the page button) are swallowed %s -> %s, sheet still open" % [variant, str(before), str(rig.counters())])
	# 3. precision at the hole edge
	before = rig.counters().duplicate()
	await sim.tap(h.position + Vector2(12, 12))
	var after_in: Array = rig.counters().duplicate()
	await sim.tap(h.position + Vector2(-2, 20))
	var after_out: Array = rig.counters().duplicate()
	ok(after_in[0] == before[0] + 1 and after_out == after_in, "S2 %s: edge: inside the hole presses, 2 px outside is swallowed %s %s %s" % [variant, str(before), str(after_in), str(after_out)])
	# 4. a tap in the 8 px margin of the hole reaches the sheet panel, not the scrim
	before = rig.counters().duplicate()
	await sim.tap(Vector2(h.position.x + 3, h.position.y + 3))
	ok(rig.sheet_panel_taps == before[4] + 1 and rig.scrim_taps == before[3] and rig.sheet_open(), "S2 %s: a tap in the 8 px margin of the hole reaches the sheet panel, not the scrim %s" % [variant, str(rig.counters())])
	# 5. info step: the blocker over the hole swallows the tap
	rig.blocker.visible = true
	before = rig.counters().duplicate()
	await sim.tap(c)
	ok(rig.counters() == before, "S2 %s: info step: the blocker over the hole swallows the tap %s" % [variant, str(rig.counters())])
	rig.blocker.visible = false
	# 6. the hole moves to a second target on the same sheet
	rig.set_hole(rig.target_rect(rig.sheet_btn2))
	await frames(2)
	before = rig.counters().duplicate()
	await sim.tap(rig.sheet_btn2.get_global_rect().get_center())
	await sim.tap(c)
	ok(rig.sheet_btn2_taps == 1 and rig.sheet_btn_taps == before[0], "S2 %s: the hole follows to a second target: it presses, the old target is blocked %s" % [variant, str(rig.counters())])
	# 7. a drag that starts in the hole and leaves it does not press the button
	rig.set_hole(rig.target_rect(rig.sheet_btn))
	await frames(2)
	before = rig.counters().duplicate()
	await sim.drag(c, Vector2(0, -90), 6)
	ok(rig.sheet_btn_taps == before[0] and rig.sheet_open(), "S2 %s: a drag that starts in the hole and leaves it does not press the button %s" % [variant, str(rig.counters())])
	# 8 (extra, not in the spike): a drag that starts in the hole scrolls a ScrollContainer inside the sheet and presses nothing
	var filler := Control.new()
	filler.custom_minimum_size = Vector2(0, 1500)
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rig.sheet.content.add_child(filler)
	await frames(4)
	rig.set_hole(rig.target_rect(rig.sheet_btn2))
	await frames(2)
	var sv0: int = rig.sheet._scroll.scroll_vertical
	var b2: int = rig.sheet_btn2_taps
	await sim.drag(rig.sheet_btn2.get_global_rect().get_center(), Vector2(0, -200), 10)
	await frames(4)
	ok(rig.sheet._scroll.scroll_vertical > sv0 + 50 and rig.sheet_btn2_taps == b2 and rig.sheet_open(), "S2 %s: a drag that starts in the hole scrolls the sheet's content (%+d) and presses nothing" % [variant, rig.sheet._scroll.scroll_vertical - sv0])
	rig.free_all()
	await frames(2)
	var s := BottomSheet.current()
	if s != null:
		s.close()
		await frames(4)


# ---- fingers on the sheet itself --------------------------------------------------------------------------------------

func _sheet_fingers(variant: String) -> void:
	var s := BottomSheet.open("Fingers", func(c: VBoxContainer) -> void:
		for i in 30:
			c.add_child(UI.label("Row %d" % i + " of tall content in the sheet", UI.S_BODY, UI.TEXT)), Callable(), "L", "fingers")
	await frames(5)
	var pr := s.panel.get_global_rect()
	var cx := UI.canvas_w() * 0.5
	# a scroll in the content scrolls it and does not dismiss; a drag down at the top of the content does not dismiss either
	var content_pt := Vector2(cx, pr.position.y + 300.0)
	var sv0: int = s._scroll.scroll_vertical
	await sim.drag(content_pt, Vector2(0, -250), 10)
	await frames(3)
	var sv1: int = s._scroll.scroll_vertical
	ok(BottomSheet.is_open() and sv1 > sv0 + 50, "sheet %s: a swipe up in the content scrolls it (%d to %d) and the sheet stays" % [variant, sv0, sv1])
	s._scroll.scroll_vertical = 0
	await frames(2)
	await sim.drag(content_pt, Vector2(0, 220), 10)
	await frames(4)
	ok(BottomSheet.is_open() and absf(s.panel.get_global_rect().position.y - pr.position.y) < 1.5, "sheet %s: a swipe down in the content (not the handle) does not drag or close the sheet" % variant)
	# a drag that starts on the scrim does not close it (a tap does)
	await sim.drag(Vector2(cx, 120), Vector2(0, 60), 6)
	await frames(3)
	ok(BottomSheet.is_open(), "sheet %s: a drag that starts on the scrim does not close it" % variant)
	# a swipe down on the handle: 80 springs back, 200 closes
	var grip := Vector2(cx, pr.position.y + 16.0)
	await sim.drag(grip, Vector2(0, 80), 8)
	await frames(3)
	ok(BottomSheet.is_open() and absf(s.panel.get_global_rect().position.y - pr.position.y) < 1.5, "sheet %s: a swipe down of 80 px on the handle springs back" % variant)
	var mark := App.bus.sequence()
	await sim.drag(grip, Vector2(0, 200), 10)
	await frames(4)
	ok(not BottomSheet.is_open() and App.bus.seen("close:fingers", mark), "sheet %s: a swipe down of 200 px on the handle closes it and raises close:fingers" % variant)
	var s2 := BottomSheet.open("Tap scrim", Callable(), Callable(), "S", "scrim")
	await frames(5)
	await sim.tap(Vector2(cx, 100))
	await frames(3)
	ok(not BottomSheet.is_open(), "sheet %s: a finger tap on the scrim closes it" % variant)
	ok(is_instance_valid(App.main.sheet_layer) and App.main.sheet_layer.get_child_count() == 0, "sheet %s: nothing is left in the sheet layer" % variant)
