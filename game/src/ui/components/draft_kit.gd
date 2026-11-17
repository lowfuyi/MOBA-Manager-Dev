class_name DraftKit
extends RefCounted
## Drawn pieces of the Draft (build plan I-16), one Control each, drawn through CardKit.Ops so they cost a few draw calls:
##   RoleBar   the role filter (All, Top, Jungle, Mid, Bot, Support): six equal stacked segments, an icon over a Caption 24 word,
##             the selected one a filled teal pill with a ring (shape, not colour alone). The same look and the same `changed`
##             signal as Segmented (HeroGrid.role_filter), drawn as one control: the six-button Segmented cost about 19 draw
##             calls, this costs about 4. Taps follow the S1 rule (a release within 12 px of the press, in screen space).
##             Tagged `tut_id`; a tap raises tap:<tut_id>.<id> ("all" for the empty id).
##             Also the sheet's "Plays as" control: RoleBar.new(cb, tut_id, options) with options {id, label, icon, sub, locked};
##             `sub` is a second line ("85%", "100% best"); a locked option is greyed with a lock icon and takes no tap.

class RoleBar extends Control:
	signal changed(id: Variant)

	const H := 96.0
	var options: Array = []          # [{id, label, icon}]
	var selected_id: Variant = ""
	var tut_id := ""
	var applied := 0
	var draw_count := 0
	var on_change: Callable
	var _tr := TouchTrack.new()
	var _press := -1
	var _press_g := Vector2.ZERO
	var _ops := CardKit.Ops.new()

	func _init(p_on_change: Callable = Callable(), p_tut_id: String = "", p_options: Array = [], p_selected: Variant = "") -> void:
		on_change = p_on_change
		tut_id = p_tut_id
		if p_options.is_empty():
			options = [{"id": "", "label": Strings.t("draft.filter.all"), "icon": "dot"}]
			for r in ArtPalette.ROLES:
				options.append({"id": r, "label": Strings.t("role.short." + r), "icon": Icons.role_id(r)})
		else:
			options = p_options.duplicate(true)
		selected_id = p_selected
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(_relayout)
		_relayout()
		CompKit.mark_stateful(self)
		CompKit.tag(self, tut_id)
		CompKit.set_cue(self, "pill+ring")

	## A label that does not fit its segment wraps to two lines (I-22: "Match and draft" at large text); the bar grows by a line.
	func label_lines(i: int) -> Array:
		var w := (size.x if size.x > 0.0 else UI.canvas_w() - 48.0) / float(maxi(1, options.size())) - 12.0
		return PlanKit.wrap(UI.font("SemiBold"), UI.S_CAPTION, String(options[i]["label"]), w, 2)

	func _relayout() -> void:
		var extra := 0.0
		for i in options.size():
			if String(options[i].get("sub", "")) != "" or label_lines(i).size() > 1:
				extra = 24.0
		var h := H + extra
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size = Vector2(0, h)
		queue_redraw()

	func seg_rect(i: int) -> Rect2:
		var w := size.x / float(maxi(1, options.size()))
		return Rect2(float(i) * w, 0.0, w, size.y)

	func index_at(p: Vector2) -> int:
		if p.y < 0.0 or p.y > size.y or p.x < 0.0 or p.x > size.x:
			return -1
		return clampi(int(p.x / (size.x / float(options.size()))), 0, options.size() - 1)

	func index_of(id: Variant) -> int:
		for i in options.size():
			if options[i]["id"] == id:
				return i
		return -1

	## Select without raising `changed` (an equal value changes nothing).
	func set_selected(id: Variant) -> void:
		if id == selected_id or index_of(id) < 0:
			return
		selected_id = id
		applied += 1
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		match _tr.feed(event):
			"down":
				_press = index_at(_tr.press_pos)
				_press_g = get_global_transform_with_canvas() * _tr.press_pos
				queue_redraw()
			"up":
				var g := get_global_transform_with_canvas() * _tr.pos
				var i := _press
				_press = -1
				queue_redraw()
				if i >= 0 and g.distance_to(_press_g) <= TouchTrack.SLOP and index_at(_tr.pos) == i:
					press(i)
				accept_event()

	## What a finger on segment `i` does (also the test hook).
	func press(i: int) -> void:
		if i < 0 or i >= options.size() or bool(options[i].get("locked", false)):
			return
		var id: Variant = options[i]["id"]
		if tut_id != "":
			CompKit.tap_event("%s.%s" % [tut_id, String(id) if String(id) != "" else "all"])
		if id == selected_id:
			return
		selected_id = id
		applied += 1
		queue_redraw()
		changed.emit(id)
		if on_change.is_valid():
			on_change.call(id)

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		_ops.bg("card", Rect2(Vector2.ZERO, size), UI.PANEL2)
		var sel := index_of(selected_id)
		for i in options.size():
			var r := seg_rect(i).grow(-4.0)
			var on := i == sel
			if on:
				_ops.bg("card", r, UI.ACCENT)
				_ops.bg("ring", r, UI.TEAL_HI)
			elif i == _press:
				_ops.bg("card", r, UI.PANEL3)
			var locked := bool(options[i].get("locked", false))
			var tc := UI.INK_TEAL if on else (UI.TEXT_OFF if locked else UI.TEXT)
			_ops.icon("lock" if locked else String(options[i]["icon"]), Rect2(r.get_center().x - 14.0, r.position.y + 12.0, 28.0, 28.0), tc)
			var ll := label_lines(i)
			for k in ll.size():
				_ops.text(UI.font("SemiBold"), UI.S_CAPTION, String(ll[k]), r.position.x + 2.0, r.position.y + 62.0 + 26.0 * float(k), r.size.x - 4.0, tc, 1)
			var sub := String(options[i].get("sub", ""))
			if sub != "":
				_ops.text(UI.font("SemiBold"), UI.S_CAPTION, sub, r.position.x + 2.0, r.position.y + 90.0, r.size.x - 4.0, tc, 1)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped
