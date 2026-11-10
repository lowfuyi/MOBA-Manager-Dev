class_name Segmented
extends PanelContainer
## A segmented control (UI-PASS-2 5.4): 2 to 6 options of equal width, 96 px high, the selected one a filled accent pill
## with a ring and dark text (a shape and a luminance cue, never hue alone), never a word broken in the middle.
## `fit` "equal" = equal widths; "scroll" = a horizontal strip with the selected option scrolled into view; "auto" (default)
## = equal, switching to the strip by itself when a label does not fit its slot (large text). It decides from its own width
## on every `resized`, never from 720. 5 or more options are stacked: the icon over a Caption 24 word, 6 px side padding.
## Options: Strings (the id is the index) or Dictionaries {id, label, icon (IconHook id), locked}. `selected` is an id.
## A locked option is not tappable and shows a lock; `on_change(id)` and the `changed` signal fire once per change.
## Built once; set_selected / set_label / set_locked change it in place (a structure change, set_options, rebuilds buttons).
## Option buttons are tagged `<tut_id>.<option id>` so the tutorial can point at one option.

signal changed(id: Variant)

const PAD := 20
const PAD_STACKED := 6

var options: Array = []
var selected_id: Variant = null
var fit := "auto"
var mode := "equal"            # what it currently uses: "equal" or "scroll"
var stacked := false
var font_size := UI.S_BODY
var on_change: Callable
var tut_id := ""
var applied := 0
var _scroll: ScrollContainer
var _row: HBoxContainer
var _btns: Array = []
static var _boxes: Dictionary = {}    # (selected, pressed, top, left, right) -> StyleBoxFlat, shared by every Segmented


class _Seg extends Button:
	var icon_id := ""
	var is_stacked := false
	var locked := false
	var is_selected := false

	func _notification(what: int) -> void:
		if what != NOTIFICATION_DRAW:
			return
		var col := UI.INK_TEAL if is_selected else (UI.TEXT_OFF if locked else UI.TEXT)
		if icon_id != "":
			var sz := 32.0
			var r := Rect2(Vector2((size.x - sz) * 0.5, 8.0), Vector2(sz, sz)) if is_stacked else Rect2(Vector2(10.0, (size.y - sz) * 0.5), Vector2(sz, sz))
			IconHook.draw(self, icon_id, r, col)
		if locked:
			IconHook.draw(self, "lock", Rect2(Vector2(size.x - 30.0, 6.0), Vector2(24, 24)), UI.DIM)


func _init(p_options: Array = [], p_selected: Variant = null, p_on_change: Callable = Callable(), p_fit: String = "auto",
		p_tut_id: String = "", p_font_size: int = 0) -> void:
	fit = p_fit
	on_change = p_on_change
	tut_id = p_tut_id
	stacked = p_options.size() >= 5
	font_size = p_font_size if p_font_size > 0 else (UI.S_CAPTION if stacked else UI.S_BODY)
	custom_minimum_size = Vector2(0, UI.BTN_H)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.R_CARD, 0))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	var hbar := _scroll.get_h_scroll_bar()    # no scroll bar: the cut-off label of the next option is the hint that the strip scrolls
	hbar.modulate.a = 0.0
	hbar.custom_minimum_size = Vector2(0, 0)
	for st in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		hbar.add_theme_stylebox_override(st, CompKit.empty_box())
	add_child(_scroll)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 0)
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_row)
	CompKit.mark_stateful(self)
	CompKit.tag(self, tut_id)
	_set_options(p_options, p_selected)
	resized.connect(_recompute)


func _set_options(p_options: Array, p_selected: Variant) -> void:
	options = []
	for i in p_options.size():
		var o: Variant = p_options[i]
		if o is Dictionary:
			var d: Dictionary = (o as Dictionary).duplicate()
			if not d.has("id"):
				d["id"] = i
			options.append(d)
		else:
			options.append({"id": i, "label": String(o)})
	selected_id = p_selected
	for b in _btns:
		_row.remove_child(b)
		(b as Node).queue_free()
	_btns.clear()
	for o in options:
		var b := _Seg.new()
		b.text = String(o.get("label", ""))
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.custom_minimum_size = Vector2(0, UI.BTN_H)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size", font_size)
		b.add_theme_font_override("font", UI.font("SemiBold"))
		b.icon_id = String(o.get("icon", ""))
		b.is_stacked = stacked
		b.locked = bool(o.get("locked", false))
		b.disabled = b.locked
		b.button_down.connect(UI._pulse.bind(b))
		b.pressed.connect(_on_pressed.bind(o["id"]))
		_row.add_child(b)
		_btns.append(b)
		if tut_id != "":
			UI.tag(b, tut_id + "." + str(o["id"]))
	for i in _btns.size():
		_style(i)
	_recompute()


func set_options(p_options: Array, p_selected: Variant) -> void:
	if p_options == options and p_selected == selected_id:
		return
	applied += 1
	_set_options(p_options, p_selected)


func set_selected(id: Variant) -> void:
	if id == selected_id:
		return
	selected_id = id
	applied += 1
	for i in _btns.size():
		_style(i)
	_scroll_to_selected()


func set_label(id: Variant, text: String) -> void:
	var i := index_of(id)
	if i < 0 or (_btns[i] as Button).text == text:
		return
	applied += 1
	options[i]["label"] = text
	(_btns[i] as Button).text = text
	_recompute()


func set_locked(id: Variant, v: bool) -> void:
	var i := index_of(id)
	if i < 0 or bool(options[i].get("locked", false)) == v:
		return
	applied += 1
	options[i]["locked"] = v
	var b := _btns[i] as _Seg
	b.locked = v
	b.disabled = v
	_style(i)


func index_of(id: Variant) -> int:
	for i in options.size():
		if options[i]["id"] == id:
			return i
	return -1


func button_at(i: int) -> Button:
	return _btns[i] as Button


func button_for(id: Variant) -> Button:
	var i := index_of(id)
	return _btns[i] as Button if i >= 0 else null


func state_name() -> String:
	return "selected" if index_of(selected_id) >= 0 else ""


func _style(i: int) -> void:
	var b := _btns[i] as _Seg
	var sel: bool = options[i]["id"] == selected_id
	b.is_selected = sel
	var top_pad := 38 if stacked else 0
	var left_pad := 46 if b.icon_id != "" and not stacked else 0
	var l := (PAD_STACKED if stacked else PAD) + left_pad
	var r := PAD_STACKED if stacked else PAD
	var base := _box(sel, false, top_pad, l, r)
	var pressed_box := _box(sel, true, top_pad, l, r)
	for st in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, base)
	for st in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, pressed_box)
	var tc := UI.INK_TEAL if sel else UI.TEXT
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, tc)
	b.add_theme_color_override("font_disabled_color", UI.TEXT_OFF)
	CompKit.set_cue(b, "lock" if b.locked else ("pill+ring" if sel else ""))
	CompKit.mark_stateful(b)
	b.queue_redraw()
	CompKit.set_cue(self, "pill+ring" if index_of(selected_id) >= 0 else "")


func _needed(i: int) -> float:
	var b := _btns[i] as _Seg
	var pad := (PAD_STACKED if stacked else PAD) * 2 + (46 if b.icon_id != "" and not stacked else 0)
	return CompKit.text_width(UI.font("SemiBold"), font_size, b.text) + pad


## Chooses equal or strip from the room the control has now. Same nodes either way; only sizes and flags change.
func _recompute() -> void:
	if _btns.is_empty():
		return
	var want := "equal"
	if fit == "scroll":
		want = "scroll"
	elif fit == "auto" and size.x > 0.0:
		var slot := size.x / float(_btns.size())
		for i in _btns.size():
			if _needed(i) > slot + 0.5:
				want = "scroll"
				break
	if want == "equal" and size.x <= 0.0 and fit == "equal":
		pass
	mode = want
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if want == "scroll" else ScrollContainer.SCROLL_MODE_DISABLED
	for i in _btns.size():
		var b := _btns[i] as Button
		if want == "scroll":
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			b.clip_text = false
			b.custom_minimum_size = Vector2(maxf(float(UI.BTN_H), ceilf(_needed(i))), UI.BTN_H)
		else:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			b.custom_minimum_size = Vector2(0, UI.BTN_H)
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL if want == "equal" else Control.SIZE_SHRINK_BEGIN
	if want == "scroll":
		_scroll_to_selected()


func _scroll_to_selected() -> void:
	if mode != "scroll" or not is_inside_tree():
		return
	var i := index_of(selected_id)
	if i >= 0:
		_scroll.ensure_control_visible.call_deferred(_btns[i])


func _on_pressed(id: Variant) -> void:
	if id == selected_id:
		return
	set_selected(id)
	changed.emit(id)
	if on_change.is_valid():
		on_change.call(id)


static func _box(sel: bool, pressed_look: bool, top: int, left: int, right: int) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d|%d" % [sel, pressed_look, top, left, right]
	if _boxes.has(key):
		return _boxes[key]
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(UI.R_BTN)
	if sel:
		sb.bg_color = UI.ACCENT
		sb.border_color = UI.TEAL_HI
		sb.set_border_width_all(2)
	else:
		sb.bg_color = UI.PANEL3 if pressed_look else Color(0, 0, 0, 0)
	sb.content_margin_top = top
	sb.content_margin_bottom = 0
	sb.content_margin_left = left
	sb.content_margin_right = right
	_boxes[key] = sb
	return sb
