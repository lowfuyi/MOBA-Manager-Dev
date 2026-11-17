extends Node
## I-16 finger rows on the REAL Draft (T-std touch_draft): a swipe that starts on a hero card scrolls the grid and opens nothing; a
## tap on a card opens its sheet; a tap on a role segment filters and a swipe across the role bar does not; a tap on a "Plays as"
## lane chooses it and a tap on a locked lane does nothing; a tap on the confirm button picks; Take takes; Auto-finish needs two
## taps; Android back closes an open sheet first, then asks before leaving.
## Normal and large text. Needs override.cfg (touch emulation); the scene relaunches itself with it, like check_touch_cards.
## Touch is SIMULATED (tests/spikes/touch_sim.gd); nothing here ran on a phone. Ends with " N checks, M failures".

const TEMP_CFG := "user://draft_touch_test.cfg"

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
	print("check_touch_draft: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _relaunch_with_touch_emulation() -> void:
	if "--touch-child" in OS.get_cmdline_user_args():
		print("FAIL touch emulation did not take effect in the child run")
		print("check_touch_draft: 1 checks, 1 failures")
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
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", proj, "res://tests/check_touch_draft.tscn", "--", "--touch-child"], out, true)
	if not existed:
		DirAccess.remove_absolute(cfg)
	var text := "\n".join(out)
	for line in text.split("\n"):
		if line.begins_with("ok ") or line.begins_with("FAIL") or line.begins_with("check_touch_draft:"):
			print(line)
	if text.find("check_touch_draft:") == -1:
		print("FAIL the child run produced no result line (exit %d)" % rc)
		print("check_touch_draft: 1 checks, 1 failures")
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


func _until_mine(d: ScreenDraft, kind: String) -> void:
	var n := 0
	while not d.draft.is_done() and n < 40:
		n += 1
		var c := d.draft.current()
		if c["team"] == d.my_side and c["kind"] == kind:
			break
		if c["team"] == d.my_side:
			d._take()
		else:
			d._ai_wait = 0.0
			d._process(0.01)
	d._time_left = 9.0
	await frames(3)


func _rows(v: String) -> void:
	await _boot()
	var d := ScreenDraft.new(App.gs.next_game())
	App.go(d)
	await frames(5)
	await _until_mine(d, "ban")
	# a swipe on a card scrolls the grid, opens nothing
	var hid := String(d.grid.shown_ids()[0])
	var p := d.grid.global_card_rect(hid).get_center()
	var before := d.grid_scroll.scroll_vertical
	await sim.swipe_angle(p, 0.0, 240.0, true, true)
	await frames(10)
	ok(d.grid_scroll.scroll_vertical > before and not BottomSheet.is_open(), "touch_draft_%s: a swipe that starts on a hero card scrolls the grid and opens nothing (%d -> %d)" % [v, before, d.grid_scroll.scroll_vertical])
	d.grid_scroll.scroll_vertical = 0
	await frames(4)
	# a tap on a card opens its sheet; back closes it
	p = d.grid.global_card_rect(hid).get_center()
	await sim.tap(p)
	await frames(6)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "draft_hero" and d._sel_hero == hid, "touch_draft_%s: a tap on a hero card opens its sheet" % v)
	App.main.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(20)
	ok(not BottomSheet.is_open() and _cur() == d, "touch_draft_%s: Android back closes the sheet first, the draft stays" % v)
	# the role bar: a tap filters, a sideways swipe does not
	var seg := d.filter.seg_rect(d.filter.index_of("mid"))
	var sp := d.filter.get_global_transform_with_canvas() * seg.get_center()
	await sim.tap(sp)
	await frames(3)
	ok(d.filter.selected_id == "mid" and d.grid.filter == "mid", "touch_draft_%s: a tap on Mid filters the grid" % v)
	var allp := d.filter.get_global_transform_with_canvas() * d.filter.seg_rect(0).get_center()
	await sim.swipe_angle(allp, 90.0, 200.0, true, false)
	await frames(6)
	ok(d.filter.selected_id == "mid", "touch_draft_%s: a swipe across the role bar changes nothing" % v)
	await sim.tap(allp)
	await frames(3)
	ok(d.filter.selected_id == "" and d.grid.filter == "", "touch_draft_%s: a tap on All shows every hero again" % v)
	# ban through the sheet by finger
	hid = String(d.grid.shown_ids()[0])
	await sim.tap(d.grid.global_card_rect(hid).get_center())
	await frames(6)
	await sim.tap(d.sheet_confirm.get_global_rect().get_center())
	await frames(8)
	ok(d.draft.bans[d.my_side].has(hid) and not BottomSheet.is_open(), "touch_draft_%s: a tap on Ban bans the hero and closes the sheet" % v)
	# pick: choose a lane by finger, a locked lane does nothing, confirm
	await _until_mine(d, "pick")
	d._take()
	await _until_mine(d, "pick")
	hid = String(d.grid.shown_ids()[0])
	await sim.tap(d.grid.global_card_rect(hid).get_center())
	await frames(6)
	var open: Array = d.draft.open_slots(d.my_side)
	var locked := ""
	for s in GameState.SLOTS:
		if not open.has(s):
			locked = s
	var lane := String(open[open.size() - 1])
	var lp := d.sheet_slot.get_global_transform_with_canvas() * d.sheet_slot.seg_rect(d.sheet_slot.index_of(lane)).get_center()
	await sim.tap(lp)
	await frames(3)
	ok(d.sheet_slot.selected_id == lane and d._sheet_target == lane, "touch_draft_%s: a tap on %s in Plays as chooses that lane" % [v, lane])
	if locked != "":
		var kp := d.sheet_slot.get_global_transform_with_canvas() * d.sheet_slot.seg_rect(d.sheet_slot.index_of(locked)).get_center()
		await sim.tap(kp)
		await frames(3)
		ok(d.sheet_slot.selected_id == lane, "touch_draft_%s: a tap on a filled (locked) lane does nothing" % v)
	await sim.tap(d.sheet_confirm.get_global_rect().get_center())
	await frames(8)
	ok(d.draft.picks[d.my_side].has(lane) and String(d.draft.picks[d.my_side][lane]["id"]) == hid, "touch_draft_%s: the confirm button picks the hero for that lane" % v)
	# Take by finger
	await _until_mine(d, "pick")
	if not d.draft.is_done():
		var rec := d.draft.ai_choice()
		await sim.tap(d.take_button.get_global_rect().get_center())
		await frames(4)
		ok(d.draft.picks[d.my_side].has(String(rec["slot"])), "touch_draft_%s: a tap on Take applies the Coach's choice" % v)
	# Auto-finish: two taps
	await sim.tap(d.auto_button.get_global_rect().get_center())
	await frames(2)
	ok(not d.draft.is_done(), "touch_draft_%s: one tap on Auto-finish decides nothing" % v)
	await sim.tap(d.auto_button.get_global_rect().get_center())
	await frames(4)
	ok(d.draft.is_done(), "touch_draft_%s: the second tap lets the Coach finish" % v)
