extends Node
## I-09 finger rows on the REAL HeroGrid (build plan I-09, SPIKE-RESULTS-0.7 S4 design C), in check_touch_gestures style:
##   a tap on a card gives that hero; a tap with 6 px of jitter still does; 11 px of travel is a tap and 14 px is a drag (12 px slop,
##   measured on the screen); a swipe that starts on a card scrolls the page and taps nothing; a tap on a banned or a picked card
##   (yours or theirs) does nothing; a tap in a gap or below the last row does nothing; a selected card can be tapped again; a
##   filtered grid taps the right hero (and a hidden hero's old place taps the one that moved there); a page scrolled by 400 px
##   still taps the right card; the role filter bar (a real Segmented) changes the grid with a tap and not with a swipe.
##   Then the PlayerCard: a tappable card takes a tap and not a swipe, a display-only card inside a real Carousel leaves the tap
##   and the swipe to the carousel.
## The same rows in large text (the card width, the gaps and the filter bar change; the 12 px slop does not).
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
var _grid: HeroGrid
var _taps: Array = []


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
	print("check_touch_cards: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _relaunch_with_touch_emulation() -> void:
	if "--touch-child" in OS.get_cmdline_user_args():
		print("FAIL touch emulation did not take effect in the child run")
		print("check_touch_cards: 1 checks, 1 failures")
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
	var rc := OS.execute(OS.get_executable_path(), ["--headless", "--path", proj, "res://tests/check_touch_cards.tscn", "--", "--touch-child"], out, true)
	if not existed:
		DirAccess.remove_absolute(cfg)
	var text := "\n".join(out)
	for line in text.split("\n"):
		if line.begins_with("ok ") or line.begins_with("FAIL") or line.begins_with("ROW|") or line.begins_with("check_touch_cards:"):
			print(line)
	if text.find("check_touch_cards:") == -1:
		print("FAIL the child run produced no result line (exit %d)" % rc)
		print("check_touch_cards: 1 checks, 1 failures")
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
		await _grid_rows(variant)
		await _filter_bar_rows(variant)
		await _player_rows(variant)
	App.apply_large_text(false)
	UI.animate = true


# ---- rigs ----------------------------------------------------------------------------------------------------------------

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


func _hero_rows() -> Array:
	var f := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _fresh_grid() -> void:
	await _clear()
	_grid = HeroGrid.new("tt")
	_grid.set_heroes(_hero_rows())
	_taps.clear()
	_grid.hero_tapped.connect(func(id: String) -> void: _taps.append(id))
	_page = _make_page(_grid)
	await frames(4)


func _centre(hero_id: String) -> Vector2:
	return _grid.global_card_rect(hero_id).get_center()


# ---- the HeroGrid ----------------------------------------------------------------------------------------------------------

func _grid_rows(variant: String) -> void:
	await _fresh_grid()
	var ids: Array = _grid.shown_ids()
	var first: String = ids[0]
	var r0 := _grid.global_card_rect(first)
	ok(_grid.hero_count() == 40 and _grid.size.x > 500.0 and r0.size.x >= 170.0, "%s: the real HeroGrid holds %d heroes, %.0f px wide, cards %.0f x %.0f" % [variant, _grid.hero_count(), _grid.size.x, r0.size.x, r0.size.y])
	ok(r0.end.y < 1280.0 and r0.position.y >= 0.0, "%s: the first card is on the screen (%s)" % [variant, str(r0)])
	var c := _centre(first)
	await sim.tap(c)
	ok(_taps == [first], "%s: a tap on the first card gives %s (got %s)" % [variant, first, str(_taps)])
	_taps.clear()
	var second: String = ids[4]    # a card in the middle column of the second row
	await sim.tap(_centre(second))
	ok(_taps == [second], "%s: a tap on a card of the second row gives %s (got %s)" % [variant, second, str(_taps)])
	# 6 px of jitter
	_taps.clear()
	sim.finger("down", c)
	await frames(1)
	sim.finger("move", c + Vector2(6, 2), Vector2(6, 2))
	await frames(1)
	sim.finger("up", c + Vector2(6, 2))
	await frames(3)
	ok(_taps == [first], "%s: a tap with 6 px of finger jitter still gives %s (got %s)" % [variant, first, str(_taps)])
	# the 12 px slop: 11 is a tap, 14 is a drag
	_taps.clear()
	sim.finger("down", c)
	await frames(1)
	sim.finger("move", c + Vector2(11, 0), Vector2(11, 0))
	await frames(1)
	sim.finger("up", c + Vector2(11, 0))
	await frames(3)
	var under: Array = _taps.duplicate()
	_taps.clear()
	sim.finger("down", c)
	await frames(1)
	sim.finger("move", c + Vector2(14, 0), Vector2(14, 0))
	await frames(1)
	sim.finger("up", c + Vector2(14, 0))
	await frames(3)
	ok(under == [first] and _taps.is_empty(), "%s: 11 px of travel is a tap, 14 px is a drag (the 12 px slop: %s / %s)" % [variant, str(under), str(_taps)])
	# a swipe that starts on a card scrolls the page and taps nothing (up and down, a straight and a slanted one)
	var swipes := 0
	for spec in [[0.0, true], [15.0, true], [0.0, false]]:
		_page.scroll_vertical = 400
		await frames(3)
		_taps.clear()
		var p0: int = _page.scroll_vertical
		var start := _centre(ids[3 * 3 + 1])    # a card in the fourth row, middle column
		await sim.swipe_angle(start, float(spec[0]), 220.0, bool(spec[1]), bool(spec[1]))
		await sim.frames(8)
		var moved := absf(float(_page.scroll_vertical - p0))
		var good := moved >= 100.0 and _taps.is_empty()
		if good:
			swipes += 1
		ok(good, "%s: a %d deg swipe %s that starts on a card scrolls the page by %.0f px and taps nothing (taps %s)" % [variant, int(spec[0]), "up" if spec[1] else "down", moved, str(_taps)])
	ok(swipes == 3, "%s: %d of 3 swipes that start on a card scroll the page" % [variant, swipes])
	# a swipe sideways (no scroll to take) taps nothing either
	_page.scroll_vertical = 0
	await frames(3)
	_taps.clear()
	await sim.swipe_angle(c, 90.0, 200.0, true, true)
	await sim.frames(6)
	ok(_taps.is_empty(), "%s: a sideways swipe over a card taps nothing (taps %s)" % [variant, str(_taps)])
	# banned, picked by you, picked by them: not tappable; a selected one still is
	_page.scroll_vertical = 0
	await frames(3)
	var banned: String = ids[1]
	var yours: String = ids[2]
	var theirs: String = ids[3]
	var sel: String = ids[5]
	_grid.set_states({banned: "banned", yours: "you", theirs: "them", sel: "selected"})
	await frames(3)
	_taps.clear()
	for id in [banned, yours, theirs]:
		await sim.tap(_centre(id))
	ok(_taps.is_empty(), "%s: a tap on a banned card, a card picked by you and a card picked by them gives nothing (got %s)" % [variant, str(_taps)])
	await sim.tap(_centre(sel))
	ok(_taps == [sel], "%s: a tap on the selected card gives it again (got %s)" % [variant, str(_taps)])
	ok(not _grid.is_tappable(banned) and not _grid.is_tappable(yours) and not _grid.is_tappable(theirs) and _grid.is_tappable(sel), "%s: is_tappable agrees (banned, you, them are not; selected is)" % variant)
	# a gap between two cards and below the last row
	_taps.clear()
	var a := _grid.global_card_rect(first)
	var b := _grid.global_card_rect(ids[1])
	var gap := Vector2((a.end.x + b.position.x) * 0.5, a.get_center().y)
	ok(_grid.hero_at(_grid.get_global_transform().affine_inverse() * gap) == "", "%s: the gap point (%.0f, %.0f) is between two cards (%.1f px wide)" % [variant, gap.x, gap.y, b.position.x - a.end.x])
	await sim.tap(gap)
	var row_gap := Vector2(a.get_center().x, a.end.y + HeroGrid.GAP * 0.5)
	await sim.tap(row_gap)
	ok(_taps.is_empty(), "%s: a tap in the gap between two cards and in the gap between two rows gives nothing (got %s)" % [variant, str(_taps)])
	# a page scrolled by 400 px: the card under the finger is the one that is tapped (screen space)
	_page.scroll_vertical = 400
	await frames(3)
	_taps.clear()
	var far: String = ids[12]
	var fr := _grid.global_card_rect(far)
	ok(fr.position.y >= 0.0 and fr.end.y <= 1280.0, "%s: card 12 is on the screen after a 400 px scroll (%s)" % [variant, str(fr)])
	await sim.tap(fr.get_center())
	ok(_taps == [far], "%s: a tap after a 400 px scroll gives card 12, %s (got %s)" % [variant, far, str(_taps)])
	# a tap during a page that is still moving is not a hole: press, page scrolls 30 px under a still finger, release: one tap
	_taps.clear()
	var pc := _grid.global_card_rect(ids[13]).get_center()
	sim.finger("down", pc)
	await frames(1)
	var still: Array = _taps.duplicate()
	sim.finger("up", pc)
	await frames(3)
	ok(still.is_empty() and _taps == [ids[13]], "%s: the tap is given on the release, not on the press (on press %s, after %s)" % [variant, str(still), str(_taps)])
	# the press look: a card is drawn pressed while the finger is down and back after
	_taps.clear()
	sim.finger("down", _centre(ids[13]))
	await frames(2)
	var was := int(_grid._pressed_idx)
	sim.finger("up", _centre(ids[13]))
	await frames(2)
	ok(was == 13 and int(_grid._pressed_idx) == -1, "%s: the card shows pressed while the finger is down (index %d) and not after (%d)" % [variant, was, int(_grid._pressed_idx)])
	# a filter: the right hero is tapped, the places of the hidden ones tap the heroes that moved there
	_page.scroll_vertical = 0
	_grid.set_filter("sup")
	await frames(4)
	var shown: Array = _grid.shown_ids()
	_taps.clear()
	await sim.tap(_centre(shown[0]))
	await sim.tap(_centre(shown[shown.size() - 1]))
	ok(_taps == [shown[0], shown[shown.size() - 1]], "%s: with the Support filter (%d heroes) a tap on the first and the last card gives them (got %s)" % [variant, shown.size(), str(_taps)])
	var hidden: String = ""
	for id in ids:
		if not shown.has(id):
			hidden = id
			break
	ok(hidden != "" and _grid.global_card_rect(hidden).size == Vector2.ZERO, "%s: a hero the filter hides has no card (%s)" % [variant, hidden])
	_taps.clear()
	var empty_slot := _grid.get_global_transform() * _grid.slot_rect(shown.size() + 1).get_center()
	await sim.tap(empty_slot)
	ok(_taps.is_empty(), "%s: a tap where a hidden hero's card used to be gives nothing (got %s)" % [variant, str(_taps)])
	_grid.set_filter("")
	await frames(3)
	# a press that leaves the page (the grid goes away under the finger): nothing stays pressed
	var g2 := _grid
	sim.finger("down", _centre(first))
	await frames(1)
	g2.visible = false
	await frames(2)
	sim.finger("up", _centre(first))
	await frames(2)
	g2.visible = true
	ok(int(g2._pressed_idx) == -1, "%s: a grid hidden while pressed shows nothing pressed" % variant)


# ---- the role filter bar (a real Segmented) ---------------------------------------------------------------------------------

func _filter_bar_rows(variant: String) -> void:
	await _clear()
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var changes: Array = []
	_grid = HeroGrid.new("tt")
	var bar := HeroGrid.role_filter(func(role: String) -> void:
		changes.append(role)
		_grid.set_filter(role), "tf")
	col.add_child(bar)
	_grid.set_heroes(_hero_rows())
	col.add_child(_grid)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page = _make_page(col)
	await frames(4)
	var b := bar.get_global_rect()
	ok(b.size.y >= 96.0 and b.size.x > 500.0, "%s: the role filter bar is %.0f x %.0f" % [variant, b.size.x, b.size.y])
	var jungle := bar.button_for("jg").get_global_rect().get_center()
	changes.clear()
	await sim.tap(jungle)
	ok(changes == ["jg"] and _grid.filter == "jg" and _grid.shown_count() < 40, "%s: a tap on the Jungle cell gives the role jg and the grid shows %d heroes (got %s, mode %s)" % [variant, _grid.shown_count(), str(changes), bar.mode])
	# a swipe that starts on the bar scrolls the page and picks nothing
	changes.clear()
	_page.scroll_vertical = 0
	await frames(2)
	var p0: int = _page.scroll_vertical
	await sim.swipe_angle(bar.button_for("sup").get_global_rect().get_center(), 0.0, 220.0, true, true)
	await sim.frames(8)
	ok(_page.scroll_vertical - p0 >= 100 and changes.is_empty() and _grid.filter == "jg", "%s: a swipe that starts on the filter bar scrolls the page by %d px and picks nothing (%s)" % [variant, _page.scroll_vertical - p0, str(changes)])


# ---- the PlayerCard --------------------------------------------------------------------------------------------------------

func _player_rows(variant: String) -> void:
	await _clear()
	var presses := [0]
	var card := PlayerCard.make("pt_touch", "row", {"name": "Marrowbrook", "role": "jg", "age": 24, "rating": 76, "tappable": true, "tut_id": "tp"})
	card.pressed.connect(func() -> void: presses[0] += 1)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(card)
	_page = _make_page(col)
	await frames(4)
	var c := card.get_global_rect().get_center()
	ok(card.get_global_rect().size.y >= 96.0, "%s: the tappable row card is %.0f x %.0f" % [variant, card.get_global_rect().size.x, card.get_global_rect().size.y])
	await sim.tap(c)
	ok(presses[0] == 1, "%s: a tap on a tappable PlayerCard presses it once (%d)" % [variant, presses[0]])
	sim.finger("down", c)
	await frames(1)
	sim.finger("move", c + Vector2(14, 0), Vector2(14, 0))
	await frames(1)
	sim.finger("up", c + Vector2(14, 0))
	await frames(3)
	ok(presses[0] == 1, "%s: 14 px of travel on a PlayerCard is a drag, not a tap (%d)" % [variant, presses[0]])
	var p0: int = _page.scroll_vertical
	await sim.swipe_angle(c, 0.0, 220.0, true, true)
	await sim.frames(8)
	ok(_page.scroll_vertical - p0 >= 100 and presses[0] == 1, "%s: a swipe that starts on a PlayerCard scrolls the page by %d px and does not press it (%d)" % [variant, _page.scroll_vertical - p0, presses[0]])
	card.set_disabled(true)
	await frames(2)
	_page.scroll_vertical = 0
	await frames(3)
	await sim.tap(card.get_global_rect().get_center())
	ok(presses[0] == 1, "%s: a disabled PlayerCard takes no tap (%d)" % [variant, presses[0]])
	# display-only cards in a real Carousel: the carousel takes the tap and the horizontal swipe, the page the vertical one
	await _clear()
	var cards: Array = []
	for i in 6:
		cards.append(PlayerCard.make("pc%d" % i, "tall", {"name": "Ashjin", "role": "top", "age": 19, "rating": 48 + i}))
	var car := Carousel.new(300.0, cards, Callable(), "tc")
	var got: Array = []
	car.card_tapped.connect(func(i: int) -> void: got.append(i))
	col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(car)
	_page = _make_page(col)
	await frames(4)
	var cb := car.get_global_rect()
	var ok_mouse := true
	for cd in cards:
		if (cd as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			ok_mouse = false
	ok(ok_mouse and cb.size.y >= 200.0, "%s: the display-only PlayerCards ignore the mouse inside the carousel (%.0f x %.0f)" % [variant, cb.size.x, cb.size.y])
	var slot0 := car.get_global_transform() * Vector2(float(car._xs[0]) - car.h_offset() + float(car._ws[0]) * 0.5, car.card_height() * 0.5)
	await sim.tap(slot0)
	ok(got == [0], "%s: a tap on a display-only PlayerCard in the carousel gives card 0 (got %s)" % [variant, str(got)])
	got.clear()
	var h0 := car.h_offset()
	await sim.swipe_angle(slot0, 90.0, 240.0, true, true)
	await sim.frames(10)
	ok(car.h_offset() - h0 >= 100.0 and got.is_empty(), "%s: a sideways swipe that starts on a PlayerCard moves the carousel by %.0f px and taps nothing (%s)" % [variant, car.h_offset() - h0, str(got)])
	got.clear()
	var s0: int = _page.scroll_vertical
	await sim.swipe_angle(slot0, 0.0, 220.0, true, true)
	await sim.frames(8)
	ok(_page.scroll_vertical - s0 >= 100 and got.is_empty(), "%s: a vertical swipe that starts on a PlayerCard scrolls the page by %d px and taps nothing (%s)" % [variant, _page.scroll_vertical - s0, str(got)])
	await _clear()
