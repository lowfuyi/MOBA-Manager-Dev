class_name BottomSheet
extends Control
## A bottom sheet (UI-PASS-2 5.5, build plan I-08). `BottomSheet.open(title, build_content, build_footer, size, id)` adds one to
## `App.main.sheet_layer` (CanvasLayer 20) and returns it: a scrim (one ColorRect, 60 percent black, no blur) and a panel with a
## grab handle (64 x 8), a header (title Value 40, wraps to two lines; a 96 px close button), a scrolling content column and an
## optional pinned footer (primary action 104 px). Sizes: "S" fits its content up to 40 percent of the screen height, "M" is
## 60 percent, "L" 85 percent. It slides up in 220 ms (instant when UI.animate is false).
## Ways to close it: the close button, a tap on the scrim, Android Back (Main asks `BottomSheet.handle_back()` first), a drag
## down on the handle or the header of more than 120 px, `close()`. `close()` ALWAYS runs deferred, so a button inside the sheet
## can call it from its own signal. Only one sheet at a time: opening a sheet replaces the open one (the old one is hidden and
## freed at once, so open() is safe to call from a button inside the old sheet). The page behind keeps updating and keeps its
## scroll position; the sheet never touches it.
## Callbacks: `build_content.call(content: VBoxContainer)` and `build_footer.call(footer: VBoxContainer)` (an invalid Callable =
## no footer). Use `BottomSheet.footer_button(footer, text, cb)` for the footer action (explicit font size, 104 px high).
## Events on App.bus: `open:<id>` after the sheet is built and in the tree, `close:<id>` when it starts closing (data: id, size,
## title). `id` defaults to "sheet". Tutorial ids: the close button is `sheet.close`, the panel `sheet.panel`.
## Layer note (I-07 hand-off): a CanvasLayer is not a Control, so its children do not inherit Main's theme; this root takes the
## theme from Main itself, and the buttons made here set their font size explicitly.

signal closed

const SIZES := {"S": 0.40, "M": 0.60, "L": 0.85}
const RADIUS := 28
const GRIP_H := 32
const HEADER_H := 96
const FOOTER_H := 104
const PAD := 24
const DISMISS_PX := 120.0
const T_OPEN := 0.22
const T_CLOSE := 0.18
const SCRIM_ALPHA := 0.6

static var _current: BottomSheet = null
static var _closing: BottomSheet = null    # the sheet that is sliding out: Back is still used up by it

var title := ""
var size_name := "M"
var sheet_id := "sheet"
var scrim: ColorRect
var panel: PanelContainer
var content: VBoxContainer
var footer: VBoxContainer
var close_button: IconButton
var is_closing := false
var applied := 0
var draw_count := 0
var _title_label: Label
var _grip: _Grip
var _head: HBoxContainer
var _line: ColorRect
var _scroll: ScrollContainer
var _margin: MarginContainer
var _foot_wrap: MarginContainer
var _build_content: Callable
var _build_footer: Callable
var _scrim_tr := TouchTrack.new()
var _drag_tr := TouchTrack.new()
var _drag_from_chrome := false
var _dragging := false
var _shift := 0.0
var _tween: Tween
var _layout_queued := false
var _shown_once := false


class _Grip extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, BottomSheet.GRIP_H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_style_box(UI.box(UI.TEXT_OFF, 4), Rect2(Vector2((size.x - 64.0) * 0.5, 12.0), Vector2(64, 8)))


# ---- the static door ----------------------------------------------------------------------------------------------------

static func open(p_title: String, p_build_content: Callable = Callable(), p_build_footer: Callable = Callable(), p_size: String = "M", p_id: String = "") -> BottomSheet:
	if App.main == null or App.main.sheet_layer == null:
		return null
	if _current != null and is_instance_valid(_current):
		_current._close_now(true)    # replaced: gone at once, so nothing of it can be tapped
	var s := BottomSheet.new()
	s.title = p_title
	s.size_name = p_size if SIZES.has(p_size) else "M"
	s.sheet_id = p_id if p_id != "" else "sheet"
	s._build_content = p_build_content
	s._build_footer = p_build_footer
	s.theme = App.main.theme if App.main.theme != null else UI.make_theme()
	_current = s
	App.main.sheet_layer.add_child(s)
	s._raise("open")
	return s


static func current() -> BottomSheet:
	return _current if _current != null and is_instance_valid(_current) and not _current.is_closing else null


static func is_open() -> bool:
	return current() != null


## Android Back: closes the open sheet and returns true (the press is used up); false when no sheet is open.
static func handle_back() -> bool:
	if _current != null and is_instance_valid(_current):
		_current.close()
		return true
	return _closing != null and is_instance_valid(_closing) and _closing.is_closing


## The footer's primary action: a Button 104 px high with an explicit font size (a CanvasLayer drops Main's theme).
static func footer_button(p_footer: Control, text: String, cb: Callable, kind: String = "primary", tut_id: String = "") -> Button:
	var b := UI.button(text, cb, kind, FOOTER_H)
	b.add_theme_font_size_override("font_size", UI.S_BODY)
	p_footer.add_child(b)
	if tut_id != "":
		UI.tag(b, tut_id)
	return b


# ---- building -----------------------------------------------------------------------------------------------------------

func _ready() -> void:
	name = "BottomSheet"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim = ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0, 0, 0, SCRIM_ALPHA)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()    # own box (top corners only): UI.box() is shared and rounds all four
	sb.bg_color = UI.PANEL2
	sb.corner_radius_top_left = RADIUS
	sb.corner_radius_top_right = RADIUS
	sb.border_color = UI.LINE_HI
	sb.border_width_top = 2
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.gui_input.connect(_on_panel_input)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(col)
	_grip = _Grip.new()
	col.add_child(_grip)
	_head = HBoxContainer.new()
	_head.add_theme_constant_override("separation", 0)
	_head.mouse_filter = Control.MOUSE_FILTER_PASS
	_head.custom_minimum_size = Vector2(0, HEADER_H)
	col.add_child(_head)
	var lead := Control.new()
	lead.custom_minimum_size = Vector2(PAD, 0)
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(lead)
	_title_label = UI.label(title, UI.S_BIG, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head.add_child(_title_label)
	close_button = IconButton.new("cross", Strings.t("sheet.close"), close, "sheet.close")
	_head.add_child(close_button)
	_line = ColorRect.new()
	_line.color = UI.LINE_HI
	_line.custom_minimum_size = Vector2(0, 2)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_line)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin.add_theme_constant_override("margin_left", PAD)
	_margin.add_theme_constant_override("margin_right", PAD)
	_margin.add_theme_constant_override("margin_top", UI.GAP)
	_margin.add_theme_constant_override("margin_bottom", UI.GAP)
	_scroll.add_child(_margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", UI.GAP)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin.add_child(content)
	_foot_wrap = MarginContainer.new()
	_foot_wrap.add_theme_constant_override("margin_left", PAD)
	_foot_wrap.add_theme_constant_override("margin_right", PAD)
	_foot_wrap.add_theme_constant_override("margin_top", 12)
	_foot_wrap.add_theme_constant_override("margin_bottom", PAD)
	_foot_wrap.visible = false
	col.add_child(_foot_wrap)
	footer = VBoxContainer.new()
	footer.add_theme_constant_override("separation", UI.GAP)
	_foot_wrap.add_child(footer)
	if _build_content.is_valid():
		_build_content.call(content)
	if _build_footer.is_valid():
		_build_footer.call(footer)
		_foot_wrap.visible = footer.get_child_count() > 0
	UI.tag(panel, "sheet.panel", false)
	CompKit.mark_stateful(self)
	CompKit.set_cue(self, "scrim+handle")
	panel.modulate.a = 0.0    # shown after the first layout, so it never flashes at the wrong height
	scrim.modulate.a = 0.0
	resized.connect(_queue_layout)
	_margin.minimum_size_changed.connect(_queue_layout)
	_layout()
	_start_in()


func _exit_tree() -> void:
	if _current == self:
		_current = null
	if _closing == self:
		_closing = null
	_kill_tween()
	_scrim_tr.reset()
	_drag_tr.reset()


func state_name() -> String:
	return "closing" if is_closing else "open"


func set_title(t: String) -> void:
	if t == title:
		return
	title = t
	applied += 1
	_title_label.text = UI.tidy(t)
	_queue_layout()


func _queue_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	_layout.call_deferred()


## Sizes from the viewport now (never from 720): M and L are fixed fractions of the height; S fits its content up to 40 percent.
func _layout() -> void:
	_layout_queued = false
	if panel == null or not is_inside_tree():
		return
	var vh := get_viewport_rect().size.y
	var max_h := vh * float(SIZES[size_name])
	var chrome := float(GRIP_H) + maxf(float(HEADER_H), _head.get_combined_minimum_size().y) + 2.0
	if _foot_wrap.visible:
		chrome += _foot_wrap.get_combined_minimum_size().y
	if size_name == "S":
		panel.custom_minimum_size.y = 0.0
		var want := minf(_margin.get_combined_minimum_size().y, maxf(0.0, max_h - chrome))
		_scroll.custom_minimum_size.y = ceilf(want)
	else:
		panel.custom_minimum_size.y = ceilf(max_h)
		_scroll.custom_minimum_size.y = 0.0


func chrome_height() -> float:
	return float(GRIP_H) + maxf(float(HEADER_H), _head.get_combined_minimum_size().y) + 2.0


func _rest_y() -> float:
	return get_viewport_rect().size.y - panel.size.y


# ---- opening ------------------------------------------------------------------------------------------------------------

func _start_in() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_closing or not is_inside_tree():
		return
	_layout()
	_shown_once = true
	panel.modulate.a = 1.0
	if not UI.animate:
		scrim.modulate.a = 1.0
		return
	var rest := _rest_y()
	panel.position.y = rest + panel.size.y
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(panel, "position:y", rest, T_OPEN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(scrim, "modulate:a", 1.0, T_OPEN)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


# ---- closing ------------------------------------------------------------------------------------------------------------

## Always deferred: safe from a signal of a control inside the sheet.
func close() -> void:
	call_deferred("_close_now", false)


func _close_now(replaced: bool) -> void:
	if is_closing:
		return
	is_closing = true
	if _current == self:
		_current = null
	_closing = self
	_dragging = false
	_kill_tween()
	_raise("close")
	closed.emit()
	if replaced or not UI.animate or not _shown_once or not is_inside_tree():
		hide()
		queue_free()
		return
	var vh := get_viewport_rect().size.y
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(panel, "position:y", vh, T_CLOSE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(scrim, "modulate:a", 0.0, T_CLOSE)
	_tween.chain().tween_callback(queue_free)


func _raise(kind: String) -> void:
	if is_instance_valid(App.bus):
		App.bus.emit("%s:%s" % [kind, sheet_id], {"id": sheet_id, "size": size_name, "title": title})


# ---- touch --------------------------------------------------------------------------------------------------------------

func _on_scrim_input(e: InputEvent) -> void:
	var what := _scrim_tr.feed(e)
	if what == "up" and not is_closing and _scrim_tr.travel() <= TouchTrack.SLOP:
		close()


## Drag down on the handle or the header: the panel follows the finger; past 120 px it closes, otherwise it springs back.
func _on_panel_input(e: InputEvent) -> void:
	var what := _drag_tr.feed(e)
	match what:
		"down":
			_drag_from_chrome = _drag_tr.press_pos.y <= chrome_height() and not is_closing
			_dragging = false
			_shift = 0.0
		"move":
			if not _drag_from_chrome or is_closing:
				return
			var d := _drag_tr.pos - _drag_tr.press_pos
			if not _dragging:
				if d.length() > TouchTrack.SLOP and d.y > 0.0 and absf(d.y) > absf(d.x):
					_dragging = true
					_kill_tween()
				else:
					return
			_shift = maxf(0.0, d.y)
			panel.position.y = _rest_y() + _shift
			scrim.modulate.a = clampf(1.0 - _shift / maxf(1.0, panel.size.y), 0.2, 1.0)
		"up":
			if _dragging:
				_dragging = false
				if _shift > DISMISS_PX:
					close()
				else:
					_spring_back()
			_drag_from_chrome = false


func _spring_back() -> void:
	_shift = 0.0
	if not UI.animate:
		panel.position.y = _rest_y()
		scrim.modulate.a = 1.0
		return
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(panel, "position:y", _rest_y(), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(scrim, "modulate:a", 1.0, 0.12)


## Where the panel rests (global rect), for tests and the tutorial overlay.
func panel_rect() -> Rect2:
	return panel.get_global_rect()
