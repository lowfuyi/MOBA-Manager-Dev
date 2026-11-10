class_name Screen
extends Control
## Base class for one full-screen page: optional header (title + back) over a scrolling column.

var body: VBoxContainer
var _header: HBoxContainer
## The empty corner reserved for the "?" help button (filled by I-22 with add_help_button). In the header at its right
## end when the page has a header; otherwise a free 96 x 96 spot at the top right of the page. Hidden and empty (no room,
## no gap) until a button goes in, so no title loses width today. Never null after setup().
var help_slot: Control

## Help ids whose name is not just the class name in lower case without "Screen" (TUTORIAL 5.1 list). Every other
## screen gets that derived id, for example ScreenGamePlan -> "gameplan". A screen may also override help_id().
const HELP_ID_EXCEPTIONS := {"hub": "home", "roster": "squad", "seasonend": "season"}


## Which bottom tab this page belongs to ("home", "squad", "plan", "club", "more"), or "" to hide the
## tab bar (match flow, contract talks, title). Pages override this.
func tab_id() -> String:
	return ""


## True on the first page of a tab (tapping the tab again does nothing there).
func is_tab_root() -> bool:
	return false


## The id of this screen's help sheet and of its `screen:<id>` event (Main.show_screen raises it).
func help_id() -> String:
	var sc := get_script() as Script
	return help_id_of(String(sc.get_global_name()) if sc != null else "")


## The help id for a screen class name ("ScreenGamePlan" -> "gameplan"; the exceptions above).
static func help_id_of(screen_class: String) -> String:
	var id := screen_class.to_lower()
	if id.begins_with("screen"):
		id = id.substr(6)
	return String(HELP_ID_EXCEPTIONS.get(id, id))


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
		help_slot = Control.new()    # hidden (takes no room, no gap) until a button goes in
		help_slot.name = "HelpSlot"
		help_slot.visible = false
		help_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		help_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
		_header.add_child(help_slot)
		root.add_child(_header)
	else:
		help_slot = Control.new()
		help_slot.name = "HelpSlot"
		help_slot.visible = false
		help_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		help_slot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		help_slot.offset_left = -UI.BTN_H
		help_slot.offset_bottom = UI.BTN_H
		help_slot.offset_right = 0
		help_slot.offset_top = 0
		add_child(help_slot)
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


## Put the "?" button in its slot (I-22). The slot becomes 96 x 96, so the title makes room for it.
func add_help_button(button: Control) -> void:
	if help_slot == null:
		return
	help_slot.custom_minimum_size = Vector2(UI.BTN_H, UI.BTN_H)
	help_slot.visible = true
	help_slot.add_child(button)


## Scroll the page so `control` is on screen: its middle sits about 40 percent down the visible area, or (a control
## taller than the view) its top edge 24 px below the top. Works through every ScrollContainer between the control and
## this page (nested scrolls); horizontal ones use ensure_control_visible. `seconds` above 0 animates the vertical move
## when UI.animate is on (the tutorial overlay uses 0.24). Returns false when the control is not inside a scroll area.
func scroll_to(control: Control, seconds: float = 0.0) -> bool:
	if control == null or not is_ancestor_of(control):
		return false
	var found := false
	var n: Node = control.get_parent()
	while n != null and n != self:
		var sc := n as ScrollContainer
		if sc != null:
			found = true
			if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				sc.ensure_control_visible(control)
			if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				_scroll_vertical_to(sc, control, seconds)
		n = n.get_parent()
	return found


func _scroll_vertical_to(sc: ScrollContainer, control: Control, seconds: float) -> void:
	var view_h := sc.size.y
	var top_in_content := control.global_position.y - sc.global_position.y + float(sc.scroll_vertical)
	var h := control.size.y
	var want := top_in_content + h * 0.5 - view_h * 0.4
	if h > view_h * 0.6:
		want = top_in_content - 24.0
	var content_h := 0.0
	for ch in sc.get_children():
		if ch is Control and (ch as Control).visible:
			content_h = maxf(content_h, (ch as Control).size.y)
	var target := int(clampf(want, 0.0, maxf(0.0, content_h - view_h)))
	if seconds > 0.0 and UI.animate and sc.is_inside_tree():
		var tw := sc.create_tween()
		tw.tween_property(sc, "scroll_vertical", target, seconds).set_ease(Tween.EASE_OUT)
	else:
		sc.scroll_vertical = target
