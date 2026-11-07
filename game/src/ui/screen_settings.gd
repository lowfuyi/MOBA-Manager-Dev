class_name ScreenSettings
extends Screen

var _confirm_reset := false


func go_back() -> void:
	App.go(ScreenHub.new())


func _ready() -> void:
	setup(Strings.t("settings.title"), go_back)
	_rebuild()


func _rebuild() -> void:
	UI.clear(body)
	var c := UI.card(body)
	var cb := CheckButton.new()
	cb.text = Strings.t("settings.quick")
	cb.button_pressed = App.gs.is_quick()
	cb.custom_minimum_size = Vector2(0, 80)
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(func(v): App.gs.set_quick(v); App.autosave())
	c.add_child(cb)
	c.add_child(UI.label(Strings.t("settings.quick_hint"), UI.S_SMALL, UI.DIM))
	var d := UI.card(body)
	d.add_child(UI.label(Strings.t("settings.debug_h"), UI.S_BODY, UI.ACCENT))
	d.add_child(UI.label(App.debug_info(), UI.S_SMALL - 2, UI.DIM))
	d.add_child(UI.button(Strings.t("settings.copy_debug"), func(): DisplayServer.clipboard_set(App.debug_info()), "normal", 76))
	var r := UI.card(body)
	if _confirm_reset:
		r.add_child(UI.label(Strings.t("settings.reset_confirm"), UI.S_BODY, UI.WARN))
		r.add_child(UI.button(Strings.t("settings.reset_yes"), _reset, "danger"))
		r.add_child(UI.button(Strings.t("common.cancel"), func(): _confirm_reset = false; _rebuild()))
	else:
		r.add_child(UI.button(Strings.t("settings.reset"), func(): _confirm_reset = true; _rebuild(), "danger", 76))
	body.add_child(UI.button(Strings.t("hub.about"), func(): App.go(ScreenAbout.new())))


func _reset() -> void:
	GameState.delete_save()
	App.gs = null
	App.go(ScreenTitle.new())
