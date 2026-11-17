extends Node
## I-19 finger rows on the REAL Squad (T-std touch_squad): a tap on a token opens the lane picker and a tap on a row commits that
## player (the token shows him); a swipe that starts on a token or a bench card scrolls the page and opens nothing; a tap on a bench
## card opens the player sheet and a tap on Stats switches the tab; Android back closes the sheet first; a tap on the chemistry pill
## opens Team chemistry. Normal and large text. Needs override.cfg (touch emulation); relaunches itself with it.
## Touch is SIMULATED (tests/spikes/touch_sim.gd); nothing here ran on a phone. Ends with " N checks, M failures".

const TEMP_CFG := "user://squad_touch_test.cfg"

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
	print("check_touch_squad: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _relaunch_with_touch_emulation() -> void:
	if "--touch-child" in OS.get_cmdline_user_args():
		print("FAIL touch emulation did not take effect in the child run")
		print("check_touch_squad: 1 checks, 1 failures")
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
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", proj, "res://tests/check_touch_squad.tscn", "--", "--touch-child"], out, true)
	if not existed:
		DirAccess.remove_absolute(cfg)
	var text := "\n".join(out)
	for line in text.split("\n"):
		if line.begins_with("ok ") or line.begins_with("FAIL") or line.begins_with("check_touch_squad:"):
			print(line)
	if text.find("check_touch_squad:") == -1:
		print("FAIL the child run produced no result line (exit %d)" % rc)
		print("check_touch_squad: 1 checks, 1 failures")
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


func _rows(v: String) -> void:
	await _boot()
	var r := ScreenRoster.new("hub")
	App.go(r)
	await frames(5)
	var gs := App.gs
	# a tap on the Mid token opens the picker; a tap on a row commits
	await sim.tap(_mid(r.map.tokens["mid"]))
	await frames(8)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "lane_picker", "touch_squad_%s: a tap on the Mid token opens the lane picker" % v)
	var row: PlayerCard = null
	for c in r.picker_rows.get_children():
		if (c as PlayerCard).pid != String(gs.d["lineup"]["mid"]) and row == null:
			row = c
	var want := row.pid
	await sim.tap(_mid(row))
	await frames(10)
	ok(String(gs.d["lineup"]["mid"]) == want and (r.map.tokens["mid"] as PlayerCard).pid == want and not BottomSheet.is_open(), "touch_squad_%s: a tap on a picker row puts that player on Mid" % v)
	for tc in App.main._toasts.get_children():
		tc.queue_free()
	await frames(2)
	# swipes scroll, open nothing
	var before := r.page_scroll.scroll_vertical
	await sim.swipe_angle(_mid(r.map.tokens["sup"]), 0.0, 220.0, true, true)
	await frames(10)
	ok(r.page_scroll.scroll_vertical > before and not BottomSheet.is_open(), "touch_squad_%s: a swipe up from a token scrolls the page and opens nothing" % v)
	var card := r.bench.get_child(0) as PlayerCard
	r.scroll_to(card)
	await frames(3)
	var b2 := r.page_scroll.scroll_vertical
	await sim.swipe_angle(_mid(card), 0.0, 160.0, false, true)
	await frames(10)
	ok(r.page_scroll.scroll_vertical < b2 and not BottomSheet.is_open(), "touch_squad_%s: a swipe down from a bench card scrolls the page and opens nothing" % v)
	r.scroll_to(card)
	await frames(3)
	await sim.tap(_mid(card))
	await frames(8)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "player_card" and r._open_player == card.pid, "touch_squad_%s: a tap on a bench card opens the player sheet" % v)
	await sim.tap(_c(r.card_tabs, r.card_tabs.seg_rect(r.card_tabs.index_of("stats")).get_center()))
	await frames(4)
	ok(r._card_tab == "stats" and r.card_stats != null and r.card_stats.is_visible_in_tree(), "touch_squad_%s: a tap on Stats shows the stats" % v)
	await sim.tap(_c(r.card_stats, Vector2(r.card_stats.size.x * 0.5, SquadKit.Stats.ROW_H * 0.5)))
	await frames(3)
	ok(r.card_stats.selected == String(World.STATS[0]), "touch_squad_%s: a tap on a stat explains it" % v)
	App.main.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(20)
	ok(not BottomSheet.is_open() and _cur() == r, "touch_squad_%s: Android back closes the sheet first" % v)
	r.page_scroll.scroll_vertical = 0
	await frames(3)
	await sim.tap(_c(r.pills, r.pills.pill_rect(1).get_center()))
	await frames(4)
	ok(_cur() is ScreenChemistry, "touch_squad_%s: a tap on the chemistry pill opens Team chemistry" % v)
