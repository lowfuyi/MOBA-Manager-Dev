class_name ScreenGameOver
extends Screen
## The board has dismissed the manager after a long stretch in debt (GDD 7.6). The last autosave from before it is still on disk.


func _ready() -> void:
	setup("", Callable(), false)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	var gs := App.gs
	body.add_child(UI.label(Strings.t("over.title"), UI.S_TITLE, UI.BAD, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UI.label(Strings.f("over.body", {"club": gs.club_name(gs.club()), "season": gs.d["season"]}), UI.S_BODY, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UI.spacer(30))
	if GameState.has_save():
		body.add_child(UI.button(Strings.t("over.load"), _load, "primary"))
	body.add_child(UI.button(Strings.t("over.new"), func(): App.go(ScreenClubSelect.new())))
	body.add_child(UI.button(Strings.t("over.menu"), func(): App.go(ScreenTitle.new())))


func _load() -> void:
	var gs := GameState.load_save(App.world)
	if gs == null:
		App.go(ScreenTitle.new())
		return
	App.gs = gs
	App.go(ScreenHub.new())


func go_back() -> void:
	App.go(ScreenTitle.new())
