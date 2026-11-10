extends Node
## Permanent gesture checks (build plan I-01; the S1 and S2 spikes kept as tests, plus the touch rows of S4):
##   S1  nested scroll: a horizontal carousel with a direction lock inside the vertical page, five swipe angles in both
##       directions, taps and jitter taps, plus a control that the naive carousel DOES steal the swipe (so the check cannot
##       pass because the simulation is too gentle).
##   S2  B11 hole tap: a tap inside the coach overlay's hole reaches a button in a sheet on a lower layer; the dim panels,
##       the info-step blocker and the 2 px edge hold.
## Stand-ins for the components still to be built (Carousel and BottomSheet, I-08; CoachOverlay, I-12) live in
## tests/spikes/. When those exist, point `spike_carousel.gd` / `hole_rig.gd` at them and keep these checks.
##
## A scroll container only takes touch drags when a touchscreen exists, so this needs `override.cfg` with
## pointing/emulate_touch_from_mouse=true (as tools/check_fast.sh does for the touch scenes). To be safe in the
## headless (non-touch) loop too, the scene relaunches itself once with that file in place and relays the result.
## Ends with " N checks, M failures".

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ready() -> void:
	await get_tree().process_frame
	if not DisplayServer.is_touchscreen_available():
		_relaunch_with_touch_emulation()
		return
	await _run()
	print("gestures: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _relaunch_with_touch_emulation() -> void:
	if "--gestures-child" in OS.get_cmdline_user_args():
		print("FAIL touch emulation did not take effect in the child run")
		print("gestures: 1 checks, 1 failures")
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
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", proj, "res://tests/check_gestures.tscn", "--", "--gestures-child"], out, true)
	if not existed:
		DirAccess.remove_absolute(cfg)
	var text := "\n".join(out)
	for line in text.split("\n"):
		if line.begins_with("ok ") or line.begins_with("FAIL") or line.begins_with("S1|") or line.begins_with("S2|") or line.begins_with("gestures:"):
			print(line)
	if text.find("gestures:") == -1:
		print("FAIL the child run produced no result line (exit %d)" % rc)
		print("gestures: 1 checks, 1 failures")
		get_tree().quit(1)
		return
	get_tree().quit(rc)


func _run() -> void:
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame
	# ---- S1 -------------------------------------------------------------------------------------------------------------
	var m = load("res://tests/spikes/s1_measure.gd").new(self)
	var naive: Array = await m.swipe_rows("naive", true)
	var naive_fail := 0
	for r in naive:
		if not m.row_ok(r):
			naive_fail += 1
	ok(naive_fail >= 2, "S1 control: a plain horizontal ScrollContainer steals the mostly vertical swipes (%d of 10 rows fail)" % naive_fail)
	var rows: Array = await m.swipe_rows("locked", false)
	for r in rows:
		ok(m.row_ok(r), "S1 locked carousel %2d deg %-10s page_moved=%5.1f carousel_moved=%5.1f -> expected %s" % [int(r["deg"]), r["dir"], r["page_moved"], r["car_moved"], "page" if r["vertical"] else "carousel"])
	var taps: Dictionary = await m.tap_rows("locked", false)
	ok(taps["tap"] == [1], "S1 a tap on card 1 taps card 1 (got %s)" % str(taps["tap"]))
	ok(taps["jitter_tap"] == [1], "S1 a tap with 6 px of finger jitter still taps (got %s)" % str(taps["jitter_tap"]))
	ok(taps["h_swipe"] == [], "S1 a horizontal swipe that starts on a card does not tap it (got %s)" % str(taps["h_swipe"]))
	ok(taps["v_swipe"] == [], "S1 a vertical swipe that starts on a card does not tap it (got %s)" % str(taps["v_swipe"]))
	# ---- S2 -------------------------------------------------------------------------------------------------------------
	var m2 = load("res://tests/spikes/s2_measure.gd").new(self)
	var srows: Array = await m2.run()
	for r in srows:
		ok(r["ok"], "S2 " + str(r["name"]) + " " + str(r["detail"]))
	# ---- S4 touch (the two hero-grid designs that pass the draw-call gate) -----------------------------------------------
	var m4 = load("res://tests/spikes/s4_touch.gd").new(self)
	var s4: Dictionary = await m4.run()
	for d in ["C", "B3"]:
		var r4: Dictionary = s4[d]
		ok(r4["tap"] == [r4["expected_id"]], "S4 hero grid %s: a tap on the first card taps that hero (got %s)" % [d, str(r4["tap"])])
		ok(int(r4["swipe_scroll"]) > 100 and r4["swipe_taps"] == [], "S4 hero grid %s: a swipe that starts on a card scrolls the page (%d px) and taps nothing (%s)" % [d, int(r4["swipe_scroll"]), str(r4["swipe_taps"])])
