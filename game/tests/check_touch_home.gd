extends Node
## I-15 finger rows on the REAL Home (T-std touch_home): a vertical swipe that starts on the Next card, on Play, on an up-next card
## and on a tile scrolls the page and taps nothing; a sideways swipe on the up-next row moves the row, not the page; a tap on Play,
## on an up-next card, on a tile and on an attention card does what it says; Android back on Home goes to the title screen.
## Normal and large text. Needs override.cfg (touch emulation); the scene relaunches itself with it, like check_touch_cards.
## Touch is SIMULATED (tests/spikes/touch_sim.gd); nothing here ran on a phone. Ends with " N checks, M failures".

const TEMP_CFG := "user://home_touch_test.cfg"

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
	print("check_touch_home: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _relaunch_with_touch_emulation() -> void:
	if "--touch-child" in OS.get_cmdline_user_args():
		print("FAIL touch emulation did not take effect in the child run")
		print("check_touch_home: 1 checks, 1 failures")
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
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", proj, "res://tests/check_touch_home.tscn", "--", "--touch-child"], out, true)
	if not existed:
		DirAccess.remove_absolute(cfg)
	var text := "\n".join(out)
	for line in text.split("\n"):
		if line.begins_with("ok ") or line.begins_with("FAIL") or line.begins_with("check_touch_home:"):
			print(line)
	if text.find("check_touch_home:") == -1:
		print("FAIL the child run produced no result line (exit %d)" % rc)
		print("check_touch_home: 1 checks, 1 failures")
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
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(3)
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], 20261117)
	var gs := App.gs
	while int(gs.d["round"]) < 9:    # round 10: contracts card, up-next row, everything on the page
		var g := gs.next_game()
		gs.record_human_game(g, gs.auto_game(g))
	App.tutorial.autosave = false
	App.tutorial.device = DeviceState.new(TEMP_CFG)
	App.tutorial.bind()


func _home() -> ScreenHub:
	var h := ScreenHub.new()
	App.go(h)
	await frames(5)
	return h


func _page(h: ScreenHub) -> ScrollContainer:
	return h.find_children("*", "ScrollContainer", true, false)[0]


func _cur() -> Node:
	return App.main._current


## Scroll so `c` is in the middle of the page, then return its centre.
func _bring(h: ScreenHub, c: Control) -> Vector2:
	h.scroll_to(c)
	await frames(4)
	return c.get_global_rect().get_center()


func _rows(v: String) -> void:
	await _boot()
	var h := await _home()
	var targets := {"the Next card": h.next_card, "Play": h.play_button, "an up-next card": h.upnext, "a tile": h.tiles}
	for what in targets:
		var c: Control = targets[what]
		var p := await _bring(h, c)
		if what == "the Next card":
			p = h.next_card.get_global_rect().position + Vector2(h.next_card.size.x * 0.5, 60.0)    # the title line, not a button
		var page := _page(h)
		var before := page.scroll_vertical
		var up := before < 200
		await sim.swipe_angle(p, 0.0, 260.0, up, true)
		await frames(10)
		ok(_cur() == h and not BottomSheet.is_open(), "touch_home_%s: a swipe that starts on %s taps nothing" % [v, what])
		ok(page.scroll_vertical != before, "touch_home_%s: a swipe that starts on %s scrolls the page (%d -> %d)" % [v, what, before, page.scroll_vertical])
	# sideways on the up-next row: the row moves, the page does not
	var pr := await _bring(h, h.upnext)
	var page2 := _page(h)
	var sv := page2.scroll_vertical
	var cur0 := h.upnext.current_index()
	await sim.swipe_angle(pr, 90.0, 260.0, true, true)
	await frames(20)
	ok(h.upnext.current_index() != cur0 and absi(page2.scroll_vertical - sv) <= 2, "touch_home_%s: a sideways swipe moves the up-next row (%d -> %d), not the page" % [v, cur0, h.upnext.current_index()])
	# taps
	h = await _home()
	var pp := await _bring(h, h.upnext)
	await sim.tap(h.upnext.get_global_rect().position + Vector2(80.0, 80.0))
	await frames(4)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "home_opponent", "touch_home_%s: a tap on an up-next card opens the opponent sheet" % v)
	if BottomSheet.is_open():
		BottomSheet.current().close()
	await frames(20)
	var ap := await _bring(h, h.attention)
	await sim.tap(h.attention.get_global_rect().position + Vector2(100.0, 48.0))
	await frames(5)
	ok(_cur() is ScreenRoster, "touch_home_%s: a tap on the contracts card goes to the Squad" % v)
	h = await _home()
	var t: HomeKit.StatTile = h.tiles.tiles()[2]
	var tp := await _bring(h, t)
	await sim.tap(tp)
	await frames(5)
	ok(_cur() is ScreenChemistry, "touch_home_%s: a tap on the Chemistry tile opens Team chemistry" % v)
	h = await _home()
	var g := App.gs.next_game()
	var bp := await _bring(h, h.play_button)
	await sim.tap(bp)
	await frames(5)
	ok(_cur() is ScreenPreMatch and (_cur() as ScreenPreMatch).game.get("id", "") == g.get("id", "x"), "touch_home_%s: a tap on Play opens Match day for the next game" % v)
	h = await _home()
	App.main.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(5)
	ok(_cur() is ScreenTitle, "touch_home_%s: Android back on Home goes to the title screen" % v)
