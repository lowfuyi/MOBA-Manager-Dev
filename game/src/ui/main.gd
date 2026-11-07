extends Control
## Root: dark background, safe-area margins, one screen at a time.

var _margin: MarginContainer
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
	_margin.add_theme_constant_override("margin_bottom", 32)
	add_child(_margin)
	App.main = self
	get_tree().set_auto_accept_quit(false)
	show_screen(ScreenTitle.new())


func show_screen(screen: Control) -> void:
	if _current != null:
		# Not remove_child(): a tap on a button swaps the screen from inside that button's own signal.
		_current.set_process(false)
		_current.hide()
		_current.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_current.queue_free()
	_current = screen
	_margin.add_child(screen)


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
