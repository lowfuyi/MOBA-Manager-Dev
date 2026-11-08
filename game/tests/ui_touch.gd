extends Node
## Touch behaviour on the real screens: injects touch press/drag/release events (the same events a
## phone sends) and checks that a swipe scrolls instead of tapping, from any starting point.

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func cur() -> Control:
	return App.main._current


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("ui touch: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func find_buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button and c.is_visible_in_tree():
			out.append(c)
		find_buttons(c, out)


## Send one finger event the way the engine does on a phone: the touch/drag event itself plus the
## mouse event emulated from it (buttons react to the mouse one, scroll containers to the touch one).
func finger(kind: String, pos: Vector2, rel: Vector2 = Vector2.ZERO) -> void:
	var vp := get_viewport()
	match kind:
		"down":
			var t := InputEventScreenTouch.new()
			t.index = 0
			t.position = pos
			t.pressed = true
			vp.push_input(t, true)
			var m := InputEventMouseButton.new()
			m.button_index = MOUSE_BUTTON_LEFT
			m.pressed = true
			m.position = pos
			m.global_position = pos
			m.button_mask = MOUSE_BUTTON_MASK_LEFT
			vp.push_input(m, true)
		"move":
			var d := InputEventScreenDrag.new()
			d.index = 0
			d.position = pos
			d.relative = rel
			vp.push_input(d, true)
			var mm := InputEventMouseMotion.new()
			mm.position = pos
			mm.global_position = pos
			mm.relative = rel
			mm.button_mask = MOUSE_BUTTON_MASK_LEFT
			vp.push_input(mm, true)
		"up":
			var t2 := InputEventScreenTouch.new()
			t2.index = 0
			t2.position = pos
			t2.pressed = false
			vp.push_input(t2, true)
			var m2 := InputEventMouseButton.new()
			m2.button_index = MOUSE_BUTTON_LEFT
			m2.pressed = false
			m2.position = pos
			m2.global_position = pos
			vp.push_input(m2, true)


## Swipe up by `dist` px starting at `from`.
func swipe(from: Vector2, dist: float, steps: int = 8) -> void:
	finger("down", from)
	await frames(1)
	var pos := from
	for i in steps:
		var step := Vector2(0, -dist / steps)
		pos += step
		finger("move", pos, step)
		await frames(1)
	finger("up", pos)
	await frames(3)


func tap(p: Vector2) -> void:
	finger("down", p)
	await frames(1)
	finger("up", p)
	await frames(3)


func scroller() -> ScrollContainer:
	return cur().body.get_parent() as ScrollContainer


func _run() -> void:
	print("touchscreen available: ", DisplayServer.is_touchscreen_available())
	GameState.delete_save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	get_window().size = Vector2i(720, 1280)
	await frames()
	App.go(ScreenClubSelect.new())
	await frames()
	# 1. club list: start the swipe on a button, on a card, and on empty background
	var sc := scroller()
	ok(sc.get_v_scroll_bar().max_value > sc.size.y, "club list is longer than the screen")
	var btns: Array = []
	find_buttons(cur(), btns)
	var b: Button = btns[1]
	await swipe(b.get_global_rect().get_center(), 300)
	ok(sc.scroll_vertical > 150, "swipe starting ON A BUTTON scrolls the list (scroll=%d)" % sc.scroll_vertical)
	ok(cur() is ScreenClubSelect, "swipe on a button did not tap it")
	sc.scroll_vertical = 0
	await frames()
	await swipe(Vector2(360, 200), 300)
	ok(sc.scroll_vertical > 150, "swipe starting on a card scrolls (scroll=%d)" % sc.scroll_vertical)
	sc.scroll_vertical = 0
	await frames()
	# short swipe that ends inside the same button must not tap it either
	btns.clear()
	find_buttons(cur(), btns)
	await swipe(btns[0].get_global_rect().get_center(), 60)
	ok(cur() is ScreenClubSelect, "short swipe on a button does not tap it")
	# a genuine tap still works
	btns.clear()
	find_buttons(cur(), btns)
	var target: Button = null
	for x in btns:
		if x.text == Strings.t("club.pick.choose"):
			target = x
			break
	await tap(target.get_global_rect().get_center())
	ok(cur() is ScreenHub, "a tap on a button still works")
	# 2. back handling
	for which in ["roster", "standings", "settings"]:
		match which:
			"roster":
				App.go(ScreenRoster.new("hub"))
			"standings":
				App.go(ScreenStandings.new())
			_:
				App.go(ScreenSettings.new())
		await frames()
		get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		await frames()
		ok(cur() is ScreenHub, "back request from %s returns to the hub" % which)
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames()
	ok(cur() is ScreenTitle, "back request from the hub goes to the title menu")
	ok(ProjectSettings.get_setting("application/config/quit_on_go_back") == false, "OS back button is handed to the game")
	# 3. draft: swipe over the hero grid
	cur()._continue()
	await frames()
	var g: Dictionary = App.gs.next_game()
	App.go(ScreenDraft.new(g))
	await frames()
	var d: ScreenDraft = cur()
	var n := 0
	while d.draft.current()["team"] != d.my_side and n < 20:
		n += 1
		d._ai_wait = 0.0
		d._process(0.01)
	await frames(4)
	sc = scroller()
	ok(sc.get_v_scroll_bar().max_value > sc.size.y, "hero list longer than the screen")
	btns.clear()
	find_buttons(cur(), btns)
	var hero_btn: Button = null
	for x in btns:
		if "their best" in x.text:
			hero_btn = x
			break
	var bans_before: int = d.draft.bans["B"].size() + d.draft.bans["R"].size()
	await swipe(hero_btn.get_global_rect().get_center(), 250)
	ok(sc.scroll_vertical > 100, "draft: swipe over a hero button scrolls (scroll=%d)" % sc.scroll_vertical)
	ok(d.draft.bans["B"].size() + d.draft.bans["R"].size() == bans_before, "draft: swipe did not ban a hero")
	# back from the draft returns to the pre-match screen
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames()
	ok(cur() is ScreenPreMatch, "back request in the draft returns to match day")
	# 4. training screen: a swipe that starts on a player row scrolls the list; the row still opens on a tap
	App.go(ScreenHub.new())
	await frames()
	App.go(ScreenTraining.new())
	await frames(4)
	var ts := scroller()
	ok(ts.get_v_scroll_bar().max_value > ts.size.y, "training list is longer than the screen")
	btns.clear()
	find_buttons(cur(), btns)
	var row_btn: Button = null
	for x in btns:
		if "trains" in x.text or "practises" in x.text or "rests" in x.text:
			row_btn = x
			break
	await swipe(row_btn.get_global_rect().get_center(), 300)
	ok(ts.scroll_vertical > 100, "training: swipe over a player row scrolls (scroll=%d)" % ts.scroll_vertical)
	ok(cur()._open == "", "training: swipe did not open the player")
	ts.scroll_vertical = 0
	await frames()
	btns.clear()
	find_buttons(cur(), btns)
	for x in btns:
		if "trains" in x.text or "practises" in x.text or "rests" in x.text:
			row_btn = x
			break
	await tap(row_btn.get_global_rect().get_center())
	ok(cur()._open != "", "training: a tap on a player row opens the focus picker")
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames()
	ok(cur() is ScreenHub, "back request in training returns to the hub")
	# 4b. team chemistry: the screen is longer than the phone, scrolls by swipe and the back request returns to the hub
	App.go(ScreenChemistry.new())
	await frames(4)
	var cs := scroller()
	ok(cs.get_v_scroll_bar().max_value > cs.size.y, "chemistry screen is longer than the screen")
	await swipe(Vector2(360, 700), 300)
	ok(cs.scroll_vertical > 100, "chemistry: a swipe over the pentagon scrolls (scroll=%d)" % cs.scroll_vertical)
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames()
	ok(cur() is ScreenHub, "back request in chemistry returns to the hub")
	# 5. free agents: a swipe that starts on a player row scrolls the market; a tap opens the talks; back returns
	App.go(ScreenFreeAgents.new("hub"))
	await frames(4)
	var fs := scroller()
	ok(fs.get_v_scroll_bar().max_value > fs.size.y, "free agent list is longer than the screen")
	btns.clear()
	find_buttons(cur(), btns)
	var fa_btn: Button = null
	for x in btns:
		if "asks" in x.text:
			fa_btn = x
			break
	await swipe(fa_btn.get_global_rect().get_center(), 300)
	ok(fs.scroll_vertical > 100, "free agents: swipe over a player row scrolls (scroll=%d)" % fs.scroll_vertical)
	ok(cur() is ScreenFreeAgents, "free agents: swipe did not open the player")
	fs.scroll_vertical = 0
	await frames()
	btns.clear()
	find_buttons(cur(), btns)
	for x in btns:
		if "asks" in x.text:
			fa_btn = x
			break
	await tap(fa_btn.get_global_rect().get_center())
	ok(cur() is ScreenNegotiation, "free agents: a tap on a player opens the negotiation")
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames()
	ok(cur() is ScreenFreeAgents, "back request in the negotiation returns to the free agents")
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames()
	ok(cur() is ScreenHub, "back request in the free agents returns to the hub")
