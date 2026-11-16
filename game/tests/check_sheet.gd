extends Node
## I-08 checks, part 1 (no touch emulation needed): the BottomSheet and the Carousel of src/ui/components.
## Rows (the label starts with the kind): build_, fit_, hit_, inplace_, cb_ (the "cue" meta, also in colour-blind mode), theme_
## (the sheet layer drops Main's theme: the fix), route_ (every way to close a sheet), page_ (the page behind is untouched),
## and negative controls (each audit must catch a bad sample). The finger rows on the real components (S1 and S2 of
## SPIKE-RESULTS-0.7) are in tests/check_touch_gestures.gd. The window is set to 720 x 1280 first (a headless one is 100 x 100).
## Ends with " N checks, M failures".

const FitAudit = preload("res://tests/fit_audit.gd")
const Gallery = preload("res://tests/components_gallery.gd")
const Gate = preload("res://tests/perf_gate.gd")

var checks := 0
var fails := 0
var node_rows: Array = []
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


func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


func _ids(n: Node) -> Array:
	var out: Array = [n.get_instance_id()]
	for c in n.get_children():
		out.append_array(_ids(c))
	return out


func _cue_problems(root: Node, audited: Array = []) -> Array:
	var out: Array = []
	if root.has_meta(CompKit.STATE_BEARING):
		var st := String(root.call("state_name")) if root.has_method("state_name") else ""
		audited.append(root)
		if not root.has_meta(CompKit.CUE):
			out.append("%s has no cue meta" % root.get_class())
		elif st != "" and String(root.get_meta(CompKit.CUE)) == "":
			out.append("%s is in state '%s' but its cue is empty" % [root.get_class(), st])
	for c in root.get_children():
		out.append_array(_cue_problems(c, audited))
	return out


## Every control inside a carousel card must ignore the pointer (the S1 rule). Returns the offenders.
func _inert_problems(car: Carousel) -> Array:
	var out: Array = []
	for i in car.card_count():
		_inert_walk(car.card(i), out)
	return out


func _inert_walk(n: Node, out: Array) -> void:
	var c := n as Control
	if c != null and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		out.append("%s mouse_filter %d" % [c.get_class(), c.mouse_filter])
	for ch in n.get_children():
		_inert_walk(ch, out)


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	await frames(1)
	sim = load("res://tests/spikes/touch_sim.gd").new(self)
	for variant in ["normal", "large"]:
		await _variant(variant)
	await _colour_blind()
	await _negative_controls()
	App.apply_large_text(false)
	UI.set_colorblind(false)
	UI.animate = true
	print("nodes: " + " | ".join(node_rows))
	print("check_sheet: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _fresh_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(2)


func _show(section: String) -> Gallery:
	var g := Gallery.new(section)
	App.go(g)
	await frames(4)
	return g


func _sheet_layer() -> CanvasLayer:
	return App.main.sheet_layer


func _vh() -> float:
	return get_viewport().get_visible_rect().size.y


func _open(g: Gallery, sz: String, rows: int, long: bool = false) -> BottomSheet:
	var s := g.open_sheet(sz, rows, long)
	await frames(4)
	return s


## Closes whatever is open and waits until the layer is empty.
func _clear_sheets() -> void:
	var s := BottomSheet.current()
	if s != null:
		s.close()
	await frames(4)


func _scroll_of(g: Gallery) -> ScrollContainer:
	return g.body.get_parent() as ScrollContainer


# ---- per variant ----------------------------------------------------------------------------------------------------

func _variant(variant: String) -> void:
	App.apply_large_text(variant == "large")
	UI.set_colorblind(false)
	await frames(2)
	await _fresh_main()
	await _sheet_rows(variant)
	await _routes(variant)
	await _carousel_rows(variant)
	await _carousel_touchless(variant)


func _sheet_rows(variant: String) -> void:
	var g := await _show("sheet")
	var n_g := _count(g)
	ok(n_g > 3 and g.items.has("SheetButton") and (g.items["SheetButton"] as Array).size() == 4, "build_sheet_%s: the gallery page has its four open buttons (%d nodes)" % [variant, n_g])
	ok(FitAudit.audit(App.main._current, UI.canvas_w()).is_empty(), "fit_sheet_page_%s: the gallery page is clean" % variant)
	var canvas_w := UI.canvas_w()
	var vh := _vh()
	for spec in [["S", 2, false], ["M", 4, false], ["L", 9, false], ["M", 3, true]]:
		var sz: String = spec[0]
		var tag := "%s%s_%s" % [sz, "_long" if spec[2] else "", variant]
		var s := await _open(g, sz, int(spec[1]), bool(spec[2]))
		ok(s != null and BottomSheet.current() == s and s.get_parent() == _sheet_layer() and _sheet_layer().layer == 20, "build_sheet_%s: opened on the sheet layer (20) and it is the current sheet" % tag)
		var nodes := _count(s)
		node_rows.append("%s=%d" % [tag, nodes])
		ok(nodes <= 40, "build_sheet_%s: %d nodes (budget 40 for the sheet and two rows or more of content)" % [tag, nodes])
		var pr := s.panel.get_global_rect()
		ok(absf(pr.size.x - canvas_w) < 1.0 and absf(pr.end.y - vh) < 1.0, "build_sheet_%s: the panel is the full canvas width (%.0f) and rests on the bottom edge" % [tag, pr.size.x])
		match sz:
			"M":
				ok(absf(pr.size.y - ceilf(vh * 0.6)) <= 2.0, "build_sheet_%s: size M is 60 percent of the height (%.0f of %.0f)" % [tag, pr.size.y, vh])
			"L":
				ok(absf(pr.size.y - ceilf(vh * 0.85)) <= 2.0, "build_sheet_%s: size L is 85 percent of the height (%.0f of %.0f)" % [tag, pr.size.y, vh])
			"S":
				var fits := s._margin.size.y <= s._scroll.size.y + 1.0
				ok(pr.size.y <= vh * 0.4 + 1.0 and fits, "build_sheet_%s: size S fits its content (panel %.0f, at most 40 percent = %.0f; content %.0f in %.0f)" % [tag, pr.size.y, vh * 0.4, s._margin.size.y, s._scroll.size.y])
		if sz == "L":
			ok(s._margin.size.y > s._scroll.size.y, "build_sheet_%s: tall content scrolls inside the sheet (%.0f in %.0f)" % [tag, s._margin.size.y, s._scroll.size.y])
		ok(s.scrim.color.a > 0.59 and s.scrim.color.a < 0.61 and s.scrim.get_class() == "ColorRect" and s.scrim.get_rect().size.is_equal_approx(s.get_rect().size), "build_sheet_%s: the scrim is one 60 percent ColorRect over the whole canvas" % tag)
		var probs := FitAudit.audit(s, canvas_w)
		ok(probs.is_empty(), "fit_sheet_%s: clean (%s)" % [tag, "; ".join(probs.slice(0, 3))])
		var cb := s.close_button
		ok(cb.size.x >= 95.5 and cb.size.y >= 95.5 and String(cb.get_meta("accessible_name", "")) == Strings.t("sheet.close"), "hit_sheet_%s: the close button is %.0f x %.0f with its accessible name" % [tag, cb.size.x, cb.size.y])
		var foot := UI.find_tag("gal.sheet.primary")
		ok(foot != null and foot.size.y >= 103.5 and (foot as Button).has_theme_font_size_override("font_size"), "hit_sheet_%s: the footer action is %.0f px high with an explicit font size" % [tag, foot.size.y if foot != null else 0.0])
		if spec[2]:
			ok(s._title_label.get_line_count() <= 2 and s._title_label.get_line_count() >= 1 and s._head.size.y >= 95.5, "fit_sheet_%s: the title takes %d line(s) and is never clipped" % [tag, s._title_label.get_line_count()])
		ok(UI.find_tag("sheet.close") == cb and UI.find_tag("sheet.panel") == s.panel, "build_sheet_%s: tutorial ids sheet.close and sheet.panel are found" % tag)
		ok(CompKit.cue_of(s) == "scrim+handle" and s.state_name() == "open" and _cue_problems(s).is_empty(), "cb_sheet_%s: state open, cue '%s'" % [tag, CompKit.cue_of(s)])
		var sh := Gate.count_shadows(s)
		ok(int(sh["shadows"]) == 0 and int(sh["glows"]) == 0, "cb_sheet_%s: no shadow and no glow on the sheet (%s)" % [tag, str(sh)])
		# theme (the layer fix): the sheet root carries Main's theme; a plain Button inherits the 32 px font size
		var plain := Button.new()
		plain.text = "x"
		s.content.add_child(plain)
		ok(s.theme == App.main.theme and plain.get_theme_font_size("font_size") == UI.S_BODY, "theme_sheet_%s: the sheet root has Main's theme, a plain Button inside gets %d px" % [tag, plain.get_theme_font_size("font_size")])
		plain.queue_free()
		await _clear_sheets()
	ok(_sheet_layer().get_child_count() == 0 and not BottomSheet.is_open(), "route_sheet_%s: after four open and close cycles the sheet layer is empty (no leak)" % variant)


func _routes(variant: String) -> void:
	var g := await _show("sheet")
	var sc := _scroll_of(g)
	var filler := Control.new()
	filler.custom_minimum_size = Vector2(0, 2600)
	g.body.add_child(filler)
	await frames(3)
	sc.scroll_vertical = 300
	await frames(3)
	var page_ids := _ids(g)
	var scroll0 := sc.scroll_vertical
	# ---- the close button, with events
	var mark := App.bus.sequence()
	var s := await _open(g, "M", 3)
	ok(App.bus.seen("open:gal_m", mark) and String(App.bus.last_data("open:gal_m").get("size", "")) == "M" and String(App.bus.last_data("open:gal_m").get("id", "")) == "gal_m", "route_%s: open:gal_m is raised with its size and id" % variant)
	var mark2 := App.bus.sequence()
	s.close_button.pressed.emit()
	ok(BottomSheet.is_open(), "route_%s: close() is deferred: the sheet is still current in the same frame" % variant)
	await frames(4)
	ok(not BottomSheet.is_open() and not is_instance_valid(s) and _sheet_layer().get_child_count() == 0 and App.bus.seen("close:gal_m", mark2), "route_%s: the close button closes it, frees it and raises close:gal_m" % variant)
	# ---- close() twice raises one close event
	s = await _open(g, "S", 2)
	var mark3 := App.bus.sequence()
	s.close()
	s.close()
	await frames(4)
	var closes := 0
	for nm in App.bus.recent():
		if nm == "close:gal_s":
			closes += 1
	ok(closes == 1 and not is_instance_valid(s), "route_%s: close() called twice closes once" % variant)
	# ---- the scrim
	s = await _open(g, "M", 3)
	await sim.tap(Vector2(canvas_x() * 0.5, 100))
	await frames(3)
	ok(not BottomSheet.is_open() and not is_instance_valid(s), "route_%s: a tap on the scrim closes it" % variant)
	# a tap on the panel does not
	s = await _open(g, "M", 3)
	var pr := s.panel.get_global_rect()
	await sim.tap(pr.position + Vector2(pr.size.x * 0.5, 40))
	await frames(3)
	ok(BottomSheet.is_open() and BottomSheet.current() == s, "route_%s: a tap on the panel (the handle) leaves it open" % variant)
	# ---- Android back
	var screen_before := App.main._current
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(4)
	ok(not BottomSheet.is_open() and not is_instance_valid(s) and App.main._current == screen_before, "route_%s: Back closes the open sheet and the page behind stays" % variant)
	ok(not BottomSheet.handle_back(), "route_%s: with no sheet open handle_back() is false (Back goes on to the screen)" % variant)
	# ---- swipe down
	s = await _open(g, "M", 3)
	var grip := Vector2(canvas_x() * 0.5, s.panel.get_global_rect().position.y + 16)
	var rest_y := s.panel.get_global_rect().position.y
	await sim.drag(grip, Vector2(0, 80), 8)
	await frames(3)
	ok(BottomSheet.is_open() and absf(s.panel.get_global_rect().position.y - rest_y) < 1.5, "route_%s: a swipe down of 80 px springs back to rest (%.1f off)" % [variant, s.panel.get_global_rect().position.y - rest_y])
	await sim.drag(grip, Vector2(0, -150), 8)
	await frames(3)
	ok(BottomSheet.is_open() and absf(s.panel.get_global_rect().position.y - rest_y) < 1.5, "route_%s: a swipe UP on the handle does not move or close it" % variant)
	await sim.drag(grip, Vector2(0, 200), 10)
	await frames(4)
	ok(not BottomSheet.is_open() and not is_instance_valid(s), "route_%s: a swipe down of 200 px on the handle closes it" % variant)
	# a swipe down that starts in the title row (the header is part of the drag zone)
	s = await _open(g, "M", 3)
	var head_pt := Vector2(canvas_x() * 0.5, s.panel.get_global_rect().position.y + 32.0 + 40.0)
	await sim.drag(head_pt, Vector2(0, 220), 10)
	await frames(4)
	ok(not BottomSheet.is_open(), "route_%s: a swipe down that starts in the header closes it" % variant)
	# ---- only one at a time; a sheet opened from a sheet replaces it
	var first := await _open(g, "M", 3)
	var inner := Button.new()
	inner.text = "More"
	first.content.add_child(inner)
	var second_ref: Array = []
	inner.pressed.connect(func() -> void: second_ref.append(BottomSheet.open("Second", Callable(), Callable(), "S", "second")))
	var mark4 := App.bus.sequence()
	inner.pressed.emit()
	ok(BottomSheet.current() == second_ref[0] and not first.visible, "route_%s: opening from inside a sheet replaces it at once (the old one is hidden)" % variant)
	await frames(4)
	ok(_sheet_layer().get_child_count() == 1 and not is_instance_valid(first) and App.bus.seen("close:gal_m", mark4) and App.bus.seen("open:second", mark4), "route_%s: only one sheet in the layer, the first freed, close and open events raised" % variant)
	# a button inside the sheet may call close() from its own signal
	var closer := Button.new()
	closer.text = "Done"
	BottomSheet.current().content.add_child(closer)
	closer.pressed.connect(func() -> void: BottomSheet.current().close())
	closer.pressed.emit()
	await frames(4)
	ok(not BottomSheet.is_open() and _sheet_layer().get_child_count() == 0, "route_%s: a button inside the sheet closes it from its own signal, safely" % variant)
	# a real tap reaches buttons inside the sheet
	var hits: Array = []
	var s2 := BottomSheet.open("Tap", func(c: VBoxContainer) -> void:
		var b := UI.button("A", func() -> void: hits.append("content"))
		c.add_child(b), func(f: VBoxContainer) -> void: BottomSheet.footer_button(f, "B", func() -> void: hits.append("footer")), "M", "tap")
	await frames(4)
	var cbtn := s2.content.get_child(0) as Control
	await sim.tap(cbtn.get_global_rect().get_center())
	await sim.tap(s2.footer.get_child(0).get_global_rect().get_center())
	ok(hits == ["content", "footer"], "route_%s: a real tap reaches a button in the content and one in the footer (%s)" % [variant, str(hits)])
	await _clear_sheets()
	# ---- the page behind
	ok(sc.scroll_vertical == scroll0 and _ids(g) == page_ids and is_instance_valid(g), "page_%s: the page keeps its scroll position (%d) and every instance id (%d nodes) through all of that" % [variant, sc.scroll_vertical, page_ids.size()])
	# ---- in place
	var s3 := await _open(g, "M", 3)
	var sheet_ids := _ids(s3)
	var a0 := s3.applied
	s3.set_title(s3.title)
	ok(s3.applied == a0, "inplace_sheet_%s: the same title changes nothing" % variant)
	s3.set_title("Another title")
	await frames(2)
	ok(s3.applied == a0 + 1 and s3._title_label.text == "Another title" and _ids(s3) == sheet_ids, "inplace_sheet_%s: a new title changes it once, same nodes (%d)" % [variant, sheet_ids.size()])
	await _clear_sheets()
	filler.queue_free()


func canvas_x() -> float:
	return UI.canvas_w()


# ---- the carousel (no finger scrolling here: that is check_touch_gestures) --------------------------------------------

func _carousel_rows(variant: String) -> void:
	var g := await _show("carousel")
	var cars: Array = g.items["Carousel"]
	var n := _count(g)
	node_rows.append("carousel_%s=%d" % [variant, n])
	ok(cars.size() == 5 and n <= 200, "build_carousel_%s: five carousels, %d nodes (hard limit 200)" % [variant, n])
	var probs := FitAudit.audit(App.main._current, UI.canvas_w())
	ok(probs.is_empty(), "fit_carousel_%s: clean (%s)" % [variant, "; ".join(probs.slice(0, 3))])
	var c0 := cars[0] as Carousel
	var c1 := cars[1] as Carousel
	var c2 := cars[2] as Carousel
	var c3 := cars[3] as Carousel
	var c4 := cars[4] as Carousel
	for k in 4:
		var ip := _inert_problems(cars[k])
		ok(ip.is_empty(), "build_carousel_%s: every control in the cards of carousel %d ignores the pointer (%s)" % [variant, k, "; ".join(ip.slice(0, 2))])
	ok(c0.dots_shown() and not c1.dots_shown() and c2.dots_shown() and c3.dots_shown() and not c4.dots_shown(), "build_carousel_%s: dots show for 3 or more slots (5 cards yes, 2 no, 8 + tile yes, empty no)" % variant)
	ok(c2.card_count() == 8 and c2.has_see_all_tile() and c2.see_all_tile().count == 2 and c2.card(8) == null and c2.items.size() == 10, "build_carousel_%s: 10 items show 8 cards and a See all tile (+2)" % variant)
	ok(not c0.has_see_all_tile() and not c1.has_see_all_tile(), "build_carousel_%s: 5 and 2 items have no tile" % variant)
	var want_w := minf(560.0, UI.canvas_w() - 48.0 - Carousel.PEEK - Carousel.GAP)
	ok(absf(c1.card_width() - want_w) < 1.0, "fit_carousel_%s: a 560 card is %.0f wide in a %.0f px row (asked 560, row less peek less gap = %.0f)" % [variant, c1.card_width(), c1.size.x, want_w])
	var peek := c1.size.x - (c1.card_width() + Carousel.GAP)
	ok(peek >= Carousel.PEEK - 1.0, "fit_carousel_%s: the next card peeks %.0f px (at least 48)" % [variant, peek])
	ok(absf(c0.card_width() - 300.0) < 1.0 and absf(c0.size.x - c0.card_width() - Carousel.GAP) >= Carousel.PEEK, "fit_carousel_%s: a 300 card keeps its width and the next one peeks" % variant)
	var h_ok := true
	for k in 4:
		var c := cars[k] as Carousel
		h_ok = h_ok and absf(c.size.y - (c.card_height() + (Carousel.DOTS_H if c.dots_shown() else 0))) < 1.5 and c.card_height() >= 100.0
		for i in c.card_count():
			h_ok = h_ok and absf(c.card(i).size.y - c.card_height()) < 1.0
	ok(h_ok, "fit_carousel_%s: the row is as tall as its tallest card (and the dots), every card has that height" % variant)
	ok(c4.custom_minimum_size.y >= Carousel.MIN_H and c4.empty_text != "", "fit_carousel_%s: an empty carousel keeps %d px and draws its empty text" % [variant, Carousel.MIN_H])
	ok(c3.h_offset() > 100.0 and c3.current_index() == 2, "build_carousel_%s: the scrolled sample rests on its third card (offset %.0f, dot %d)" % [variant, c3.h_offset(), c3.current_index()])
	ok(UI.find_tag("gal.car") == c0 and UI.find_tag("gal.car.0") == c0.card(0) and UI.find_tag("gal.car.4") == c0.card(4), "build_carousel_%s: tutorial ids gal.car and gal.car.<i> found" % variant)
	ok(CompKit.cue_of(c0) == "dots" and CompKit.cue_of(c1) == "" and c0.state_name() == "dots" and _cue_problems(g).is_empty(), "cb_carousel_%s: dots are the cue when shown ('%s'), none when not" % [variant, CompKit.cue_of(c0)])
	var sh := Gate.count_shadows(g)
	ok(int(sh["shadows"]) <= 6 and int(sh["glows"]) <= 2, "build_carousel_%s: shadow gate %s" % [variant, str(sh)])
	# in place
	var ids := _ids(g)
	var a0 := c0.applied
	var d0 := c0.draw_count
	c0.set_items(c0.items.duplicate())
	c0.set_card_w(c0.card_w)
	c0.set_see_all(c0.see_all)
	c0.set_empty_text(c0.empty_text)
	c0.set_h_offset(c0.h_offset())
	await frames(3)
	ok(c0.applied == a0 and c0.draw_count == d0 and _ids(g) == ids, "inplace_carousel_%s: equal items, width, callback, text and offset change nothing (applied %d, draws %d)" % [variant, c0.applied, c0.draw_count])
	c0.set_card_w(320.0)
	await frames(3)
	ok(c0.applied == a0 + 1 and absf(c0.card_width() - 320.0) < 1.0 and _ids(g) == ids, "inplace_carousel_%s: a new card width relays out in place (%.0f), same nodes" % [variant, c0.card_width()])
	c0.set_card_w(300.0)
	await frames(2)
	# taps with the finger simulated (touch and mouse events together; a plain page, no emulation needed to tap)
	var sc := _scroll_of(g)
	sc.scroll_vertical = 0
	await frames(3)
	var taps: Array = []
	c0.card_tapped.connect(func(i: int) -> void: taps.append(i))
	var mark := App.bus.sequence()
	var p1: Vector2 = c0.get_global_transform() * Vector2(float(c0._xs[1]) - c0.h_offset() + 100.0, c0.card_height() * 0.5)
	await sim.tap(p1)
	ok(taps == [1] and App.bus.seen("tap:gal.car.1", mark), "build_carousel_%s: a tap on card 1 emits card_tapped(1) once and raises tap:gal.car.1 (%s)" % [variant, str(taps)])
	ok(not g.taps.has("inner_button"), "build_carousel_%s: the Button inside the card was not pressed (the card taps)" % variant)
	taps.clear()
	var gp: Vector2 = c0.get_global_transform() * Vector2(float(c0._xs[0]) + float(c0._ws[0]) + Carousel.GAP * 0.5 - c0.h_offset(), c0.card_height() * 0.5)
	await sim.tap(gp)
	var dp: Vector2 = c0.get_global_transform() * Vector2(c0.size.x * 0.5, c0.card_height() + 20.0)
	await sim.tap(dp)
	ok(taps.is_empty(), "build_carousel_%s: a tap in the gap between cards or on the dots taps nothing" % variant)
	# the finger families: touch only, mouse only and both give one tap, and the same drag distance (no double count)
	for mode in ["both", "touch only", "mouse only"]:
		sim.emit_touch = mode != "mouse only"
		sim.emit_mouse = mode != "touch only"
		taps.clear()
		await sim.tap(p1)
		var x0 := c0.h_offset()
		var start := Vector2(p1.x, p1.y)
		sim.finger("down", start)
		await sim.frames(1)
		var pos := start
		for k in 10:
			pos += Vector2(-10, 0)
			sim.finger("move", pos, Vector2(-10, 0))
			await sim.frames(1)
		var moved := c0.h_offset() - x0
		sim.finger("up", pos)
		await sim.frames(6)
		ok(taps == [1] and absf(moved - 100.0) < 1.5 and c0.decisions.back() == "h", "build_carousel_%s: %s: one tap, and a 100 px drag moved the row %.1f px (not doubled)" % [variant, mode, moved])
		c0.scroll_to_index(0, false)
		await frames(2)
	sim.emit_touch = true
	sim.emit_mouse = true
	# the See all tile
	sc.ensure_control_visible(c2)
	await frames(3)
	var see: Array = []
	c2.see_all_tapped.connect(func() -> void: see.append(1))
	c2.scroll_to_index(100, false)
	await frames(3)
	var tile_c: Vector2 = c2.see_all_tile().get_global_rect().get_center()
	await sim.tap(tile_c)
	ok(see == [1] and g.taps.has("see_all"), "build_carousel_%s: a tap on the See all tile emits see_all_tapped and runs the see_all callback" % variant)
	ok(c2.current_index() == c2.snap_points().size() - 1, "build_carousel_%s: scrolled to the end the last dot is current (%d of %d)" % [variant, c2.current_index(), c2.snap_points().size()])


func _carousel_touchless(variant: String) -> void:
	# a standalone carousel with an item replaced: old cards freed, new ones inert, tile appears and disappears with the count
	var host := Control.new()
	host.size = Vector2(578, 400)
	App.main.add_child(host)
	var mk := func(k: int) -> Array:
		var a: Array = []
		for i in k:
			var p := Panel.new()
			p.custom_minimum_size = Vector2(0, 120)
			var b := Button.new()
			b.text = "inner"
			p.add_child(b)
			a.append(p)
		return a
	var car := Carousel.new(300.0, mk.call(9))
	car.set_anchors_preset(Control.PRESET_TOP_WIDE)
	host.add_child(car)
	await frames(3)
	ok(car.card_count() == 8 and car.has_see_all_tile() and _inert_problems(car).is_empty(), "inplace_carousel_%s: 9 items: 8 cards and a +1 tile, buttons inside the cards made inert" % variant)
	var old := car.card(0)
	car.set_items(mk.call(8))
	await frames(3)
	ok(car.card_count() == 8 and not car.has_see_all_tile() and not is_instance_valid(old), "inplace_carousel_%s: 8 items: no tile, the old cards are freed" % variant)
	car.set_items(mk.call(0))
	await frames(3)
	ok(car.card_count() == 0 and car.custom_minimum_size.y >= Carousel.MIN_H and not car.dots_shown(), "inplace_carousel_%s: 0 items: no cards, no dots, the row keeps its height" % variant)
	car.set_items(mk.call(1))
	await frames(3)
	ok(car.card_count() == 1 and absf(car.card_width() - 300.0) < 1.0 and car.max_offset() == 0.0, "inplace_carousel_%s: one card stays at its width and cannot scroll" % variant)
	host.queue_free()
	await frames(2)


# ---- colour-blind ---------------------------------------------------------------------------------------------------------

func _colour_blind() -> void:
	App.apply_large_text(false)
	UI.set_colorblind(true)
	await _fresh_main()
	for section in ["carousel", "sheet"]:
		var g := await _show(section)
		var audited: Array = []
		ok(_cue_problems(g, audited).is_empty() and audited.size() > 0, "cb_%s_colourblind: every state-bearing control has its cue (%d audited)" % [section, audited.size()])
		ok(FitAudit.audit(App.main._current, UI.canvas_w()).is_empty(), "fit_%s_colourblind: clean" % section)
	var g2 := await _show("sheet")
	var s := await _open(g2, "M", 3)
	ok(CompKit.cue_of(s) == "scrim+handle" and _cue_problems(s).is_empty(), "cb_sheet_colourblind: scrim and handle are the cue, not a colour")
	await _clear_sheets()
	UI.set_colorblind(false)


# ---- negative controls -----------------------------------------------------------------------------------------------------

func _negative_controls() -> void:
	App.apply_large_text(false)
	await _fresh_main()
	# 1 the theme defect is detectable: a Button under a bare CanvasLayer has no theme
	var cl := CanvasLayer.new()
	var bare := Button.new()
	bare.text = "x"
	cl.add_child(bare)
	add_child(cl)
	await frames(2)
	ok(bare.get_theme_font_size("font_size") != UI.S_BODY, "negative control: a Button on a bare CanvasLayer gets %d px, not %d (the defect the sheet root fixes)" % [bare.get_theme_font_size("font_size"), UI.S_BODY])
	cl.queue_free()
	# 2 the inert walk catches a card with a live Button
	var g := await _show("carousel")
	var c0 := g.items["Carousel"][0] as Carousel
	var live := Button.new()
	live.text = "live"
	c0.card(0).add_child(live)
	ok(not _inert_problems(c0).is_empty(), "negative control: the inert walk catches a Button added to a card after the build")
	live.queue_free()
	# 3 the equal-value guard is not vacuous
	var a0 := c0.applied
	c0.set_card_w(c0.card_w + 10.0)
	ok(c0.applied == a0 + 1, "negative control: a changed width does move the applied counter")
	c0.set_card_w(c0.card_w - 10.0)
	# 4 the page-behind check sees a rebuilt page
	var ids := _ids(g)
	var first: Node = g.body.get_child(0)
	g.body.remove_child(first)
	first.queue_free()
	ok(_ids(g) != ids, "negative control: the instance-id comparison sees a deleted node")
	# 5 the fit audit still catches a card wider than the row where no h_scroller says so
	var wide := Control.new()
	wide.custom_minimum_size = Vector2(900, 40)
	g.body.add_child(wide)
	await frames(2)
	var over := false
	for p in FitAudit.audit(g, UI.canvas_w()):
		over = over or String(p).begins_with("overflow")
	ok(over, "negative control: the fit audit still catches a 900 px control (the Carousel exemption is not blanket)")
	wide.queue_free()
	# 6 a sheet left open is seen by the layer count
	var gs := await _show("sheet")
	var s := await _open(gs, "S", 1)
	ok(_sheet_layer().get_child_count() == 1 and BottomSheet.is_open(), "negative control: an open sheet shows in the layer count and in is_open()")
	await _clear_sheets()
