class_name Screen
extends Control
## Base class for one full-screen page: optional header (title + back) over a scrolling column.

var body: VBoxContainer
var _header: HBoxContainer


## Which bottom tab this page belongs to ("home", "squad", "plan", "club", "more"), or "" to hide the
## tab bar (match flow, contract talks, title). Pages override this.
func tab_id() -> String:
	return ""


## True on the first page of a tab (tapping the tab again does nothing there).
func is_tab_root() -> bool:
	return false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


## Build the page frame. `back` empty = no back button. `scroll` false = body is a plain column (for fixed layouts).
func setup(title: String, back: Callable = Callable(), scroll: bool = true) -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", UI.GAP)
	add_child(root)
	if title != "" or back.is_valid():
		_header = HBoxContainer.new()
		_header.custom_minimum_size = Vector2(0, UI.HEADER_H)
		if back.is_valid():
			var b := UI.button("<", back, "normal", UI.BTN_H)
			b.custom_minimum_size = Vector2(UI.BTN_H, UI.BTN_H)
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_header.add_child(b)
		_header.add_child(UI.label(title, UI.S_BIG, UI.TEXT))
		root.add_child(_header)
	if scroll:
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		root.add_child(sc)
		body = VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(body)
	else:
		body = VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(body)
