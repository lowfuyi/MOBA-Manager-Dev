class_name ScreenTitle
extends Screen


func _ready() -> void:
	setup("", Callable(), false)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(UI.label(Strings.t("app.title"), UI.S_DISPLAY, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UI.label(Strings.t("app.edition.single_player") + " - " + Strings.f("title.alpha", {"version": App.VERSION_LABEL}), UI.S_BODY, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UI.spacer(40))
	if GameState.has_save():
		body.add_child(UI.button(Strings.t("title.continue"), _continue, "primary"))
	body.add_child(UI.button(Strings.t("title.new_game"), func(): App.go(ScreenClubSelect.new()), "primary" if not GameState.has_save() else "normal"))
	body.add_child(UI.button(Strings.t("title.about"), func(): App.go(ScreenAbout.new())))
	body.add_child(UI.spacer(30))
	body.add_child(UI.label(Strings.t("title.footer"), UI.S_SMALL, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _continue() -> void:
	var gs := GameState.load_save(App.world)
	if gs == null:
		App.go(ScreenClubSelect.new())
		return
	App.gs = gs
	App.go(ScreenHub.new())
