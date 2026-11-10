extends Node
## I-03 frame and tutorial hooks (build plan I-03): the layers in Main, the tab bar (96 px buttons, TAB_H 112, labels on
## one line), the tag registry (UI.tag / UI.find_tag), the EventBus (emit, seen, bounded ring buffer), `screen:<help id>`
## events, Screen.help_id(), the empty "?" slot and Screen.scroll_to(). Headless; runs the real Main scene in normal
## and large text. Ends with " N checks, M failures".

const FitAudit = preload("res://tests/fit_audit.gd")
const SEED := 20261110
const TABS := ["home", "squad", "plan", "club", "more"]
## TUTORIAL 5.1 help ids, by screen class. Title, About and Game over have no sheet but still get an id.
const HELP_IDS := {
	"ScreenHub": "home", "ScreenRoster": "squad", "ScreenPlan": "plan", "ScreenTraining": "training",
	"ScreenChemistry": "chemistry", "ScreenPractice": "practice", "ScreenPreMatch": "prematch", "ScreenDraft": "draft",
	"ScreenGamePlan": "gameplan", "ScreenMatch": "match", "ScreenReport": "report", "ScreenClub": "club",
	"ScreenStandings": "standings", "ScreenFinance": "finance", "ScreenFreeAgents": "freeagents",
	"ScreenNegotiation": "negotiation", "ScreenSeasonEnd": "season", "ScreenSettings": "settings",
	"ScreenClubSelect": "clubselect", "ScreenTitle": "title", "ScreenAbout": "about", "ScreenGameOver": "gameover",
}

var checks := 0
var fails := 0
var _log: Array = []    # names of events seen by the listener in the "listener" tests


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func cur() -> Control:
	return App.main._current


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)    # a headless window is 100 x 100 until told otherwise
	await frames(1)
	_test_bus()
	_test_help_ids()
	for variant in ["normal", "large"]:
		await _test_frame(variant)
	App.apply_large_text(false)
	GameState.delete_save()
	print("check_frame: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


# ---- EventBus (pure) -----------------------------------------------------------------------------------------------

func _test_bus() -> void:
	var bus := EventBus.new()
	ok(not bus.seen("a"), "bus: nothing seen at the start")
	bus.emit("a")
	bus.emit("b", {"x": 1})
	ok(bus.seen("a") and bus.seen("b") and not bus.seen("c"), "bus: seen() finds raised events only")
	ok(bus.last_data("b").get("x", 0) == 1, "bus: the data of an event is kept")
	ok(bus.recent() == ["a", "b"], "bus: recent() lists oldest first")
	var mark := bus.sequence()
	ok(not bus.seen("a", mark) and not bus.seen("b", mark), "bus: seen(name, since) ignores older events")
	bus.emit("a")
	ok(bus.seen("a", mark) and not bus.seen("b", mark), "bus: seen(name, since) finds newer events")
	var got: Array = []
	bus.raised.connect(func(n: String, d: Dictionary) -> void: got.append([n, d.get("k", 0), bus.seen(n)]))
	bus.emit("c", {"k": 7})
	ok(got == [["c", 7, true]], "bus: the signal carries name and data, and the event is already seen inside the listener")
	# bounded: CAPACITY + 10 more events push the oldest out
	bus.clear()
	bus.emit("first")
	for i in EventBus.CAPACITY + 9:
		bus.emit("n%d" % i)
	ok(bus.recent().size() == EventBus.CAPACITY, "bus: the ring buffer holds at most %d events (holds %d)" % [EventBus.CAPACITY, bus.recent().size()])
	ok(not bus.seen("first"), "bus: the oldest event was forgotten once the buffer is full")
	ok(bus.seen("n%d" % (EventBus.CAPACITY + 8)) and bus.recent()[0] == "n9", "bus: the newest is kept and the order survives wrapping")
	ok(bus.sequence() >= EventBus.CAPACITY + 10, "bus: sequence() keeps counting past the buffer size")
	bus.clear()
	ok(bus.recent().is_empty() and not bus.seen("n70"), "bus: clear() empties the buffer")
	bus.free()


func _test_help_ids() -> void:
	var bad: Array = []
	var seen_classes := 0
	for entry in ProjectSettings.get_global_class_list():
		var cn: String = entry["class"]
		if cn == "Screen" or not cn.begins_with("Screen") or String(entry["base"]) != "Screen":
			continue
		seen_classes += 1
		if not HELP_IDS.has(cn):
			bad.append(cn + " (no expected id in the test)")
		elif Screen.help_id_of(cn) != HELP_IDS[cn]:
			bad.append("%s gives '%s', want '%s'" % [cn, Screen.help_id_of(cn), HELP_IDS[cn]])
	ok(bad.is_empty() and seen_classes == HELP_IDS.size(), "help_id: all %d screen classes give their TUTORIAL 5.1 id (%s)" % [seen_classes, ", ".join(bad)])
	var hub := ScreenHub.new()
	var roster := ScreenRoster.new("hub")
	ok(hub.help_id() == "home" and roster.help_id() == "squad", "help_id: an instance answers help_id() from its class (Hub -> home, Roster -> squad)")
	hub.free()
	roster.free()
	var base := Screen.new()
	ok(base.help_id() == "", "help_id: the bare Screen class has none")
	base.free()


# ---- the frame, tags, events -----------------------------------------------------------------------------------------

func _tap_at(pos: Vector2) -> void:
	for pressed in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = pressed
		m.position = pos
		m.global_position = pos
		m.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		get_viewport().push_input(m, true)
	await frames(2)


func _test_frame(variant: String) -> void:
	App.apply_large_text(variant == "large")
	await frames(1)
	var v := variant + ": "
	var cw := UI.canvas_w()
	ok(absf(get_viewport().get_visible_rect().size.x - cw) < 1.0, v + "the canvas is %.0f px wide" % get_viewport().get_visible_rect().size.x)
	GameState.delete_save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	UI.animate = false
	await frames(2)

	# layers: content first, then the sheet layer (20), the toast layer (30) and the overlay slot (100)
	ok(App.bus != null and App.bus == main.bus and main.bus.get_parent() == main, v + "Main creates the EventBus and App.bus points at it")
	var order_ok: bool = main.content.get_index() < main.sheet_layer.get_index() and main.sheet_layer.get_index() < main.toast_layer.get_index() and main.toast_layer.get_index() < main.overlay_layer.get_index()
	ok(order_ok, v + "layer instance order: content, sheet, toast, overlay")
	ok(main.sheet_layer.layer == 20 and main.toast_layer.layer == 30 and main.overlay_layer.layer == 100, v + "layer values are 20, 30 and 100 (%d, %d, %d)" % [main.sheet_layer.layer, main.toast_layer.layer, main.overlay_layer.layer])
	ok(main.content.is_ancestor_of(cur()) and main.content.is_ancestor_of(main._tabbar), v + "the screen and the tab bar live in the content layer")
	ok(main._toasts.get_parent() == main.toast_layer, v + "the toast line lives in the toast layer")
	ok(main.sheet_layer.get_child_count() == 0 and main.overlay_layer.get_child_count() == 0, v + "the sheet layer and the overlay slot are empty")
	App.toast("check frame")
	await frames(1)
	var toast_rect: Rect2 = (main._toasts.get_child(0) as Control).get_global_rect()
	ok(main._toasts.get_child_count() == 1 and toast_rect.end.y <= get_viewport().get_visible_rect().size.y and toast_rect.position.x >= 0.0 and toast_rect.end.x <= cw + 0.5, v + "a toast shows inside the frame from the toast layer (%s)" % str(toast_rect))

	# the title page has no tab bar, so no tab tag is found
	ok(cur() is ScreenTitle and not main._tabbar.visible, v + "the title page hides the tab bar")
	var none_found := true
	for id in ["tabbar", "tab.home", "tab.squad", "tab.plan", "tab.club", "tab.more"]:
		if UI.find_tag(id) != null:
			none_found = false
	ok(none_found, v + "no tab tag is found while the tab bar is hidden")

	# a game, then the Home tab: the tab bar is up and all six tags are found
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], SEED)
	App.autosave()
	var bus: EventBus = main.bus
	var mark := bus.sequence()
	App.go(ScreenHub.new())
	await frames(3)
	ok(bus.seen("screen:home", mark), v + "show_screen raises screen:home for the Home screen")
	ok(bus.last_data("screen:home").get("help_id", "") == "home" and bus.last_data("screen:home").get("tab", "") == "home", v + "the screen event carries help_id and tab")
	ok(main._tabbar.visible, v + "the tab bar shows on Home")
	ok(UI.find_tag("tabbar") == main._tabbar, v + "tag 'tabbar' finds the tab bar")
	for id in TABS:
		ok(UI.find_tag("tab." + id) == main._tab_buttons[id], v + "tag 'tab.%s' finds its tab button" % id)

	# tab bar geometry: 112 px bar, 96 px buttons, one line per label, no word split
	ok(is_equal_approx(main._tabbar.size.y, float(UI.TAB_H)) and UI.TAB_H == 112, v + "the tab bar is TAB_H = 112 px high (%.0f)" % main._tabbar.size.y)
	var btn_ok := true
	for id in TABS:
		var b: Button = main._tab_buttons[id]
		if b.size.y < 96.0 - 0.5 or b.size.x < 96.0:
			btn_ok = false
	ok(btn_ok, v + "every tab button is at least 96 x 96 px")
	var line_ok := true
	for id in TABS:
		var b: Button = main._tab_buttons[id]
		var f: Font = b.get_theme_font("font")
		var w := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.S_CAPTION).x
		var sb := b.get_theme_stylebox("normal")
		var room := b.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT)
		if b.autowrap_mode != TextServer.AUTOWRAP_OFF or w > room:
			line_ok = false
			print("     tab '%s': text %.0f px, room %.0f px" % [b.text, w, room])
	ok(line_ok, v + "every tab label is on one line and fits its button")
	var tab_probs := FitAudit.audit(main._tabbar, cw)
	ok(tab_probs.is_empty(), v + "fit audit of the tab bar is clean (%s)" % "; ".join(tab_probs))
	await _test_long_tab_label(main, v)

	# tap: events from a press (signal) and from a simulated tap (mouse events)
	mark = bus.sequence()
	(main._tab_buttons["squad"] as Button).pressed.emit()
	await frames(3)
	ok(bus.seen("tap:tab.squad", mark), v + "tap:tab.squad fires on a button press")
	ok(cur().tab_id() == "squad" and bus.seen("screen:squad", mark), v + "the press still opens Squad, and screen:squad was raised")
	mark = bus.sequence()
	await _tap_at((main._tab_buttons["plan"] as Button).get_global_rect().get_center())
	ok(bus.seen("tap:tab.plan", mark) and cur().tab_id() == "plan", v + "a simulated tap on the Plan tab raises tap:tab.plan and opens Plan")
	var plan_count := 0
	for n in bus.recent():
		if n == "tap:tab.plan":
			plan_count += 1
	ok(plan_count == 1, v + "one tap raises one event (%d)" % plan_count)

	# tag registry lifecycle on scratch controls
	await _test_tags(main, v)
	# header, help slot and scroll_to
	await _test_screen_frame(main, v)

	# Android back still works from a sub page
	App.go_tab("club")
	await frames(2)
	App.go(ScreenFinance.new())
	await frames(2)
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(2)
	ok(cur() is ScreenClub, v + "the Android back request still goes from Finance to the Club tab")

	main.queue_free()
	await frames(2)
	ok(App.bus == null, v + "App.bus is cleared when Main leaves the tree")


## A label the width of "Trophies" must not wrap or break inside the word: it is cut with "..." at the floor size.
func _test_long_tab_label(main: Control, v: String) -> void:
	var b: Button = main._tab_buttons["more"]
	var keep := b.text
	b.text = "Trophies"    # the Standings tab label that used to break as "Trophi/es" (test string, not shown to players)
	await frames(2)
	var f: Font = b.get_theme_font("font")
	var w := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.S_CAPTION).x
	var sb := b.get_theme_stylebox("normal")
	var room := b.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT)
	ok(b.autowrap_mode == TextServer.AUTOWRAP_OFF and b.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, v + "'Trophies' stays on one line in a tab button (no wrapping; a longer word would be cut with ...)")
	ok(w <= room, v + "'Trophies' fits a tab button at 24 px (%.0f of %.0f px)" % [w, room])
	var probs := FitAudit.audit(main._tabbar, UI.canvas_w())
	ok(probs.is_empty(), v + "fit audit is clean with 'Trophies' as a tab label (%s)" % "; ".join(probs))
	b.text = "Championships and more"    # far too long: cut with an ellipsis, never wrapped to a second line or widened
	await frames(2)
	ok(b.size.y <= 96.5 and is_equal_approx(main._tabbar.size.y, float(UI.TAB_H)) and b.size.x < 140.0, v + "a far too long tab label is cut, the bar keeps its height and the button its width (%s)" % str(b.size))
	b.text = keep


func _test_tags(main: Control, v: String) -> void:
	var host := Control.new()
	main.content.add_child(host)
	var b := Button.new()
	b.text = "x"
	host.add_child(b)
	await frames(1)
	var events: Array = []
	var on_raised := func(n: String, _d: Dictionary) -> void: events.append(n)
	main.bus.raised.connect(on_raised)
	UI.tag(b, "t.one")
	ok(UI.find_tag("t.one") == b and UI.tag_of(b) == "t.one", v + "tags: a tagged visible control is found by id")
	b.hide()
	ok(UI.find_tag("t.one") == null, v + "tags: a hidden control is not found")
	b.show()
	host.hide()
	ok(UI.find_tag("t.one") == null, v + "tags: a control under a hidden parent is not found")
	host.show()
	ok(UI.find_tag("t.one") == b, v + "tags: shown again, it is found again")
	b.pressed.emit()
	ok(events == ["tap:t.one"], v + "tags: a press raises tap:<id> (%s)" % str(events))
	UI.tag(b, "t.one")    # again: must not connect twice
	events.clear()
	b.pressed.emit()
	ok(events == ["tap:t.one"], v + "tags: tagging twice still raises one event per press")
	UI.tag(b, "t.two")
	events.clear()
	b.pressed.emit()
	ok(UI.find_tag("t.one") == null and UI.find_tag("t.two") == b and events == ["tap:t.two"], v + "tags: a second id replaces the first, events follow the new id")
	var quiet := Button.new()
	host.add_child(quiet)
	UI.tag(quiet, "t.quiet", false)
	events.clear()
	quiet.pressed.emit()
	ok(events.is_empty() and UI.find_tag("t.quiet") == quiet, v + "tags: tap_source false registers but raises nothing")
	var panel := PanelContainer.new()
	host.add_child(panel)
	UI.tag(panel, "t.panel")    # not a button: registers, no tap source, no error
	ok(UI.find_tag("t.panel") == panel, v + "tags: a non-button control can be tagged")
	# two controls with one id (a rebuilt screen while the old one waits to be freed): the newest visible wins
	var b2 := Button.new()
	host.add_child(b2)
	UI.tag(b2, "t.two")
	ok(UI.find_tag("t.two") == b2 and UI.tag_count("t.two") == 2, v + "tags: the newest visible control with an id wins")
	b2.hide()
	ok(UI.find_tag("t.two") == b, v + "tags: with the newest hidden, the older visible one is found")
	# freeing removes the entries
	b2.queue_free()
	b.queue_free()
	await frames(3)
	ok(UI.find_tag("t.two") == null and UI.tag_count("t.two") == 0, v + "tags: freeing the tagged nodes removes their entries")
	# leaving the tree (not freed) removes the entry after a frame; moving to another parent keeps it
	var mover := Button.new()
	host.add_child(mover)
	UI.tag(mover, "t.mover")
	var host2 := Control.new()
	main.content.add_child(host2)
	mover.reparent(host2)
	await frames(2)
	ok(UI.find_tag("t.mover") == mover, v + "tags: a control moved to another parent keeps its tag")
	host2.remove_child(mover)
	await frames(2)
	ok(UI.find_tag("t.mover") == null and UI.tag_count("t.mover") == 0, v + "tags: a control taken out of the tree loses its entry")
	mover.free()
	main.bus.raised.disconnect(on_raised)
	host.queue_free()
	host2.queue_free()
	await frames(2)
	ok(UI.tag_count("t.quiet") == 0 and UI.tag_count("t.panel") == 0, v + "tags: the registry is empty of the scratch ids after cleanup")


func _test_screen_frame(main: Control, v: String) -> void:
	# header and "?" slot on a page with a header; a free slot on a page without one
	App.go_tab("more")
	await frames(3)
	var hdr: Control = cur()._header
	ok(hdr != null and hdr.size.y >= 96.0 - 0.5, v + "the page header is at least 96 px high (%.0f)" % (hdr.size.y if hdr != null else -1.0))
	var slot: Control = cur().help_slot
	ok(slot != null and slot.get_parent() == hdr and slot.get_child_count() == 0 and not slot.visible, v + "a page with a header has an empty, hidden '?' slot at the right end of it")
	ok(hdr.get_child(hdr.get_child_count() - 1) == slot, v + "the slot is the last item in the header")
	App.go(ScreenHub.new())
	await frames(3)
	var hs: Control = cur().help_slot
	ok(hs != null and hs.get_parent() == cur() and hs.get_child_count() == 0, v + "the Home page (no header) has a free, empty '?' slot")
	var sr: Rect2 = cur().get_global_rect()
	var hr: Rect2 = hs.get_global_rect()
	ok(is_equal_approx(hr.end.x, sr.end.x) and is_equal_approx(hr.position.y, sr.position.y) and is_equal_approx(hr.size.x, 96.0) and is_equal_approx(hr.size.y, 96.0), v + "the free slot is the 96 x 96 top right corner of the page (%s in %s)" % [str(hr), str(sr)])
	# filling the slot (I-22 will do this with the real button)
	var scr := Screen.new()
	scr.setup("Slot", Callable(), true)
	App.go(scr)
	await frames(2)
	var title_before: float = (scr._header.get_child(0) as Control).size.x
	var q := Button.new()
	q.text = "?"
	scr.add_help_button(q)
	await frames(2)
	ok(scr.help_slot.visible and scr.help_slot.size.x >= 96.0 - 0.5 and q.get_parent() == scr.help_slot, v + "add_help_button fills the slot and gives it 96 px")
	ok((scr._header.get_child(0) as Control).size.x < title_before, v + "the title gives up room when the button goes in (%.0f -> %.0f)" % [title_before, (scr._header.get_child(0) as Control).size.x])
	await _test_scroll_to(v)
	# a page that does not scroll
	var fixed := Screen.new()
	fixed.setup("Fixed", Callable(), false)
	var lbl := UI.label("hello")
	fixed.body.add_child(lbl)
	App.go(fixed)
	await frames(2)
	ok(not fixed.scroll_to(lbl), v + "scroll_to answers false on a page with no scroll area")


func _test_scroll_to(v: String) -> void:
	var scr := Screen.new()
	scr.setup("Scroll", Callable(), true)
	var items: Array = []
	for i in 30:
		var l := UI.label("row %d" % i)
		l.custom_minimum_size = Vector2(0, 200)
		scr.body.add_child(l)
		items.append(l)
	App.go(scr)
	await frames(3)
	var sc: ScrollContainer = scr.body.get_parent()
	ok(sc.scroll_vertical == 0, v + "scroll_to test page starts at the top")
	ok(scr.scroll_to(items[20]), v + "scroll_to finds the scroll area")
	await frames(2)
	var r: Rect2 = (items[20] as Control).get_global_rect()
	var view: Rect2 = sc.get_global_rect()
	ok(sc.scroll_vertical > 0 and view.encloses(r), v + "scroll_to brings row 20 fully into view (scroll %d)" % sc.scroll_vertical)
	var frac := (r.get_center().y - view.position.y) / view.size.y
	ok(absf(frac - 0.4) < 0.02, v + "scroll_to puts the middle of the row at about 40 percent of the view (%.3f)" % frac)
	scr.scroll_to(items[29])
	await frames(2)
	ok(view.encloses((items[29] as Control).get_global_rect()), v + "scroll_to the last row clamps at the end and shows it")
	scr.scroll_to(items[0])
	await frames(2)
	ok(sc.scroll_vertical == 0 and view.encloses((items[0] as Control).get_global_rect()), v + "scroll_to the first row returns to the top")
	var outside := Control.new()
	add_child(outside)
	ok(not scr.scroll_to(outside), v + "scroll_to answers false for a control outside the page")
	outside.queue_free()
	var tall := UI.label("tall")
	tall.custom_minimum_size = Vector2(0, int(sc.size.y) + 300)
	scr.body.add_child(tall)
	await frames(3)
	scr.scroll_to(tall)
	await frames(2)
	var top_gap := tall.get_global_rect().position.y - sc.get_global_rect().position.y
	ok(absf(top_gap - 24.0) <= 1.0 or sc.scroll_vertical == int(sc.get_v_scroll_bar().max_value), v + "scroll_to a control taller than the view aligns its top 24 px below the top (%.0f)" % top_gap)
