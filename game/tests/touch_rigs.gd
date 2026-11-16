extends RefCounted
## Rigs for tests/check_touch_gestures.gd (build plan I-08): the REAL Carousel inside a vertical page (the S1 rig of
## tests/spikes/nested_rig.gd with the real component) and the REAL BottomSheet with a hole overlay on Main's overlay slot
## (the S2 rig of tests/spikes/hole_rig.gd). No class_name on purpose (preload it).
##
## NestedPage: a vertical ScrollContainer page (filler 500 px, the carousel, filler 2200 px) filling the window. The carousel
## has 8 display cards of 220 x 200, each holding a real Button (it must be inert: the carousel owns the touch).
## HoleRig: a page button on layer 0, a real sheet (size M) with `sheet_btn` in its footer and `sheet_btn2` high in its content,
## four dim panels (STOP, no shader) on `App.main.overlay_layer` around a hole, and an info-step blocker over the hole. Counters
## are counted from the real controls' own signals (the buttons' `pressed`, the panel's and the scrim's `gui_input`).

const CARD_W := 220.0
const CARD_H := 200.0


class NestedPage extends Control:
	var page: ScrollContainer
	var carousel: Carousel
	var tapped: Array = []                 # card indexes of card_tapped
	var inner_presses := 0                 # presses of the Buttons inside the cards (must stay 0)
	var see_all_taps := 0

	func build(n_cards: int = 8, card_w: float = 220.0) -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page = ScrollContainer.new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(page)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_PASS
		page.add_child(v)
		var top := Panel.new()
		top.custom_minimum_size = Vector2(0, 500)
		top.mouse_filter = Control.MOUSE_FILTER_PASS
		v.add_child(top)
		var cards: Array = []
		for i in n_cards:
			cards.append(make_card(i))
		carousel = Carousel.new(card_w, cards, func() -> void: see_all_taps += 1)
		carousel.card_tapped.connect(func(i: int) -> void: tapped.append(i))
		v.add_child(carousel)
		var bottom := Panel.new()
		bottom.custom_minimum_size = Vector2(0, 2200)
		bottom.mouse_filter = Control.MOUSE_FILTER_PASS
		v.add_child(bottom)

	func make_card(i: int) -> DepthCard:
		var c := DepthCard.new(0)
		c.custom_minimum_size.y = CARD_H
		c.content.add_child(UI.label("Card %d" % i, UI.S_HEAD, UI.TEXT))
		var b := UI.button("Inner", func() -> void: inner_presses += 1)    # a real Button: it is made inert by the carousel
		c.content.add_child(b)
		return c

	func slot_center(i: int) -> Vector2:
		return carousel.get_global_transform() * Vector2(float(carousel._xs[i]) - carousel.h_offset() + float(carousel._ws[i]) * 0.5, carousel.card_height() * 0.5)

	func gap_point(i: int) -> Vector2:    # the middle of the gap after slot i
		return carousel.get_global_transform() * Vector2(float(carousel._xs[i]) + float(carousel._ws[i]) + Carousel.GAP * 0.5 - carousel.h_offset(), carousel.card_height() * 0.5)


class HoleRig extends RefCounted:
	const GAP := 8.0
	var main: Control
	var sheet: BottomSheet
	var page_btn: Button
	var sheet_btn: Button
	var sheet_btn2: Button
	var dims: Array = []
	var blocker: ColorRect
	var hole := Rect2()
	var screen := Vector2.ZERO
	var sheet_btn_taps := 0
	var sheet_btn2_taps := 0
	var page_btn_taps := 0
	var scrim_taps := 0
	var sheet_panel_taps := 0

	func build(p_main: Control) -> void:
		main = p_main
		screen = main.get_viewport_rect().size
		page_btn = Button.new()
		page_btn.text = "page"
		page_btn.position = Vector2(100, 300)
		page_btn.size = Vector2(300, 96)
		page_btn.pressed.connect(func() -> void: page_btn_taps += 1)
		main.add_child(page_btn)    # layer 0, above Main's content: the button the scrim and the dim panels must shield
		var build_content := func(content: VBoxContainer) -> void:
			sheet_btn2 = Button.new()
			sheet_btn2.text = "Other"
			sheet_btn2.custom_minimum_size = Vector2(300, 96)
			sheet_btn2.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			sheet_btn2.mouse_filter = Control.MOUSE_FILTER_PASS    # as UI.button: a drag that starts on it scrolls the sheet
			sheet_btn2.pressed.connect(func() -> void: sheet_btn2_taps += 1)
			content.add_child(sheet_btn2)
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 200)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE    # a tap on it falls to the sheet panel
			content.add_child(spacer)
		var build_footer := func(footer: VBoxContainer) -> void:
			sheet_btn = BottomSheet.footer_button(footer, "Pick", func() -> void: sheet_btn_taps += 1)
			sheet_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
			sheet_btn.custom_minimum_size.x = 260
		sheet = BottomSheet.open("S2 sheet", build_content, build_footer, "M", "s2")
		sheet.scrim.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				scrim_taps += 1)
		sheet.panel.gui_input.connect(func(e: InputEvent) -> void:
			# a press that a button handled bubbles up through the panel too; count only presses on bare panel (no button under it)
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				var g: Vector2 = sheet.panel.get_global_transform() * (e as InputEventMouseButton).position
				for b in [sheet_btn, sheet_btn2, sheet.close_button]:
					if (b as Control).get_global_rect().has_point(g):
						return
				sheet_panel_taps += 1)
		var layer: CanvasLayer = main.overlay_layer
		for i in 4:
			var d := ColorRect.new()
			d.color = Color(0, 0, 0, 0.8)
			d.mouse_filter = Control.MOUSE_FILTER_STOP
			layer.add_child(d)
			dims.append(d)
		blocker = ColorRect.new()
		blocker.color = Color(0, 0, 0, 0)
		blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		blocker.visible = false
		layer.add_child(blocker)

	func target_rect(b: Control) -> Rect2:
		return b.get_global_rect().grow(GAP)

	func set_hole(r: Rect2) -> void:
		hole = r
		var x0 := r.position.x
		var y0 := r.position.y
		var x1 := r.end.x
		var y1 := r.end.y
		dims[0].position = Vector2(0, 0)
		dims[0].size = Vector2(screen.x, y0)
		dims[1].position = Vector2(0, y1)
		dims[1].size = Vector2(screen.x, screen.y - y1)
		dims[2].position = Vector2(0, y0)
		dims[2].size = Vector2(x0, y1 - y0)
		dims[3].position = Vector2(x1, y0)
		dims[3].size = Vector2(screen.x - x1, y1 - y0)
		blocker.position = r.position
		blocker.size = r.size

	func counters() -> Array:
		return [sheet_btn_taps, sheet_btn2_taps, page_btn_taps, scrim_taps, sheet_panel_taps]

	func sheet_open() -> bool:
		return is_instance_valid(sheet) and BottomSheet.current() == sheet

	func free_all() -> void:
		for d in dims:
			(d as Node).queue_free()
		blocker.queue_free()
		page_btn.queue_free()
		dims.clear()
