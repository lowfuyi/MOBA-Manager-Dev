extends Control
## Root: dark background, safe-area margins, one screen at a time, a bottom tab bar for the five
## places of the club (Home, Squad, Plan, Club, More) and a small toast line for feedback.

const TABS := ["home", "squad", "plan", "club", "more"]
const TAB_H := 104

var _margin: MarginContainer
var _holder: Control
var _tabbar: PanelContainer
var _tab_buttons: Dictionary = {}
var _toasts: VBoxContainer
var _current: Control


func _ready() -> void:
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.add_theme_constant_override("margin_left", 24)
	_margin.add_theme_constant_override("margin_right", 24)
	_margin.add_theme_constant_override("margin_top", 48)
	_margin.add_theme_constant_override("margin_bottom", 24)
	add_child(_margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_margin.add_child(col)
	_holder = Control.new()
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_holder)
	_build_tabbar(col)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.offset_left = 40
	_toasts.offset_right = -40
	_toasts.offset_bottom = -(TAB_H + 60)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	App.main = self
	get_tree().set_auto_accept_quit(false)
	show_screen(ScreenTitle.new())
	App.mark_started()


func _build_tabbar(parent: Control) -> void:
	_tabbar = PanelContainer.new()
	_tabbar.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 26, 8, UI.LINE, 1))
	_tabbar.custom_minimum_size = Vector2(0, TAB_H)
	_tabbar.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_tabbar.add_child(row)
	for id in TABS:
		var b := Button.new()
		b.text = Strings.t("tab." + id)
		b.custom_minimum_size = Vector2(0, TAB_H - 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.add_theme_font_size_override("font_size", UI.S_SMALL)
		b.button_down.connect(UI._pulse.bind(b))
		b.pressed.connect(_on_tab.bind(id))
		row.add_child(b)
		_tab_buttons[id] = b
	parent.add_child(_tabbar)


func _on_tab(id: String) -> void:
	if _current != null and _current.has_method("tab_id") and _current.call("tab_id") == id and _current.has_method("is_tab_root") and _current.call("is_tab_root"):
		return    # already on this tab's first page
	App.go_tab(id)


func _style_tabs(active: String) -> void:
	for id in _tab_buttons:
		var b: Button = _tab_buttons[id]
		var on: bool = id == active
		var sb := UI.box(UI.PANEL3 if on else Color(0, 0, 0, 0), 20, 8)
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		var c := UI.ACCENT if on else UI.DIM
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, c)


func show_screen(screen: Control) -> void:
	if _current != null:
		# Not remove_child(): a tap on a button swaps the screen from inside that button's own signal.
		_current.set_process(false)
		_current.hide()
		_current.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_current.queue_free()
	_current = screen
	_holder.add_child(screen)
	var tab: String = screen.call("tab_id") if screen.has_method("tab_id") else ""
	_tabbar.visible = tab != ""
	if tab != "":
		_style_tabs(tab)


## A short message above the tab bar. `action` adds one tap button (for example Undo).
func toast(text: String, color: Color = UI.TEXT, action: String = "", cb: Callable = Callable()) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL3, 20, 16, color, 2))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_child(UI.label(text, UI.S_SMALL, UI.TEXT))
	if action != "" and cb.is_valid():
		var on_tap := func() -> void:
			cb.call()
			if is_instance_valid(pc):
				pc.queue_free()
		var b := UI.button(action, on_tap, "primary", 64)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.custom_minimum_size = Vector2(150, 64)
		row.add_child(b)
	pc.add_child(row)
	_toasts.add_child(pc)
	while _toasts.get_child_count() > 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := pc.create_tween()
	tw.tween_interval(4.5 if action != "" else 3.0)
	if UI.animate:
		tw.tween_property(pc, "modulate:a", 0.0, UI.T_FADE)
	tw.tween_callback(pc.queue_free)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _current != null and _current.has_method("go_back"):
			_current.call("go_back")
		else:
			App.autosave()
			get_tree().quit()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		App.autosave()
		get_tree().quit()
