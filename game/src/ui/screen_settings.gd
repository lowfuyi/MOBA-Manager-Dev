class_name ScreenSettings
extends Screen

var _confirm_reset := false


func tab_id() -> String:
	return "more"


func is_tab_root() -> bool:
	return true


func go_back() -> void:
	App.go_tab("home")


func _ready() -> void:
	setup(Strings.t("settings.title"), Callable())
	_rebuild()


func _rebuild() -> void:
	UI.clear(body)
	var c := UI.card(body)
	var cb := CheckButton.new()
	cb.text = Strings.t("settings.quick")
	cb.button_pressed = App.gs.is_quick()
	cb.custom_minimum_size = Vector2(0, UI.BTN_H)
	cb.focus_mode = Control.FOCUS_NONE
	cb.mouse_filter = Control.MOUSE_FILTER_PASS
	cb.toggled.connect(func(v): App.gs.set_quick(v); App.autosave())
	c.add_child(cb)
	c.add_child(UI.label(Strings.t("settings.quick_hint"), UI.S_SMALL, UI.DIM))
	var m := UI.card(body)
	var ab := CheckButton.new()
	ab.text = Strings.t("settings.animate")
	ab.button_pressed = UI.animate
	ab.custom_minimum_size = Vector2(0, UI.BTN_H)
	ab.focus_mode = Control.FOCUS_NONE
	ab.mouse_filter = Control.MOUSE_FILTER_PASS
	ab.toggled.connect(func(v): App.set_animate(v))
	m.add_child(ab)
	m.add_child(UI.label(Strings.t("settings.animate_hint"), UI.S_SMALL, UI.DIM))
	var acc := UI.card(body)
	acc.add_child(UI.label(Strings.t("settings.access_h"), UI.S_BODY, UI.ACCENT))
	acc.add_child(_toggle(Strings.t("settings.large_text"), App.large_text(), func(v): App.set_large_text(v)))
	acc.add_child(UI.label(Strings.t("settings.large_text_hint"), UI.S_SMALL, UI.DIM))
	acc.add_child(_toggle(Strings.t("settings.colorblind"), UI.colorblind, func(v): App.set_colorblind(v); _rebuild()))
	acc.add_child(UI.label(Strings.t("settings.colorblind_hint"), UI.S_SMALL, UI.DIM))
	acc.add_child(UI.button(Strings.t("settings.tips_again"), func(): App.tips_reset(); App.toast(Strings.t("settings.tips_done"), UI.GOOD), "normal", 76))
	_pace_card()
	var pv := UI.card(body)
	pv.add_child(UI.label(Strings.t("settings.privacy_h"), UI.S_BODY, UI.ACCENT))
	pv.add_child(UI.label(Strings.t("settings.privacy_body"), UI.S_SMALL, UI.DIM))
	var fb := UI.card(body)
	fb.add_child(UI.label(Strings.t("settings.feedback_h"), UI.S_BODY, UI.ACCENT))
	fb.add_child(UI.label(Strings.t("settings.feedback_body"), UI.S_SMALL, UI.DIM))
	fb.add_child(UI.button(Strings.t("settings.copy_feedback"), func(): DisplayServer.clipboard_set(App.feedback_text()); App.toast(Strings.t("settings.copied"), UI.GOOD), "primary", 76))
	var d := UI.card(body)
	d.add_child(UI.label(Strings.t("settings.debug_h"), UI.S_BODY, UI.ACCENT))
	d.add_child(UI.label(App.debug_info(), UI.S_SMALL - 2, UI.DIM))
	d.add_child(UI.button(Strings.t("settings.copy_debug"), func(): DisplayServer.clipboard_set(App.debug_info()); App.toast(Strings.t("settings.copied"), UI.GOOD), "normal", 76))
	var r := UI.card(body)
	if _confirm_reset:
		r.add_child(UI.label(Strings.t("settings.reset_confirm"), UI.S_BODY, UI.WARN))
		r.add_child(UI.button(Strings.t("settings.reset_yes"), _reset, "danger"))
		r.add_child(UI.button(Strings.t("common.cancel"), func(): _confirm_reset = false; _rebuild()))
	else:
		r.add_child(UI.button(Strings.t("settings.reset"), func(): _confirm_reset = true; _rebuild(), "danger", 76))
	body.add_child(UI.button(Strings.t("hub.about"), func(): App.go(ScreenAbout.new())))


func _toggle(text: String, on: bool, cb: Callable) -> CheckButton:
	var t := CheckButton.new()
	t.text = text
	t.button_pressed = on
	t.custom_minimum_size = Vector2(0, UI.BTN_H)
	t.focus_mode = Control.FOCUS_NONE
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	t.toggled.connect(cb)
	return t


static func _mmss(sec: float) -> String:
	var t := int(round(sec))
	return "%d:%02d" % [t / 60, t % 60]


## The pace log: lets the founder (and me) see from real play whether a game feels too long.
func _pace_card() -> void:
	var p := App.gs.pace()
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("pace.h"), UI.S_BODY, UI.ACCENT))
	var n := int(p["n"])
	if n == 0:
		c.add_child(UI.label(Strings.f("pace.none", {"q": p["quick"]}), UI.S_SMALL, UI.DIM))
		return
	UI.kv_row(c, Strings.t("pace.games"), str(n))
	UI.kv_row(c, Strings.t("pace.avg_total"), _mmss(float(p["total_s"]) / n))
	UI.kv_row(c, Strings.t("pace.max_total"), _mmss(float(p["max_total_s"])))
	UI.kv_row(c, Strings.t("pace.avg_watch"), _mmss(float(p["watch_s"]) / n))
	UI.kv_row(c, Strings.t("pace.skips"), "%d / %d" % [int(p["skips"]), n])
	UI.kv_row(c, Strings.t("pace.fast"), "%d / %d" % [int(p["fast"]), n])
	UI.kv_row(c, Strings.t("pace.quick"), str(int(p["quick"])))
	c.add_child(UI.label(Strings.t("pace.note"), UI.S_SMALL - 2, UI.DIM))


func _reset() -> void:
	GameState.delete_save()
	App.gs = null
	App.go(ScreenTitle.new())
