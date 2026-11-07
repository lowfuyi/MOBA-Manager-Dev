class_name ScreenSeasonEnd
extends Screen


func go_back() -> void:
	App.go(ScreenHub.new())


func _ready() -> void:
	var gs := App.gs
	setup("", Callable())
	var done: Array = gs.d["seasons_done"]
	var last: Dictionary = done[done.size() - 1] if not done.is_empty() else {}
	var c := UI.card(body, UI.PANEL2)
	c.add_child(UI.label(Strings.f("season.over", {"season": gs.d["season"]}), UI.S_TITLE, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if gs.d["champion"] != "":
		c.add_child(UI.label(Strings.f("season.champion", {"club": gs.club_name(gs.d["champion"])}), UI.S_BIG, UI.WARN, HORIZONTAL_ALIGNMENT_CENTER))
	var r: String = last.get("result", "missed")
	c.add_child(UI.label(Strings.t("season.result." + r), UI.S_BODY, UI.GOOD if r == "champion" else UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	c.add_child(UI.label(Strings.f("season.record", {"w": last.get("w", 0), "l": last.get("l", 0), "rank": last.get("rank", 0)}), UI.S_BODY, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var h := UI.card(body)
	h.add_child(UI.label(Strings.t("season.history"), UI.S_BODY, UI.ACCENT))
	for s in done:
		h.add_child(UI.label(Strings.f("season.history_row", {"season": s["season"], "rank": s["rank"], "w": s["w"], "l": s["l"], "result": Strings.t("season.result." + String(s["result"]))}), UI.S_SMALL, UI.TEXT))
	body.add_child(UI.button(Strings.t("season.next"), _next, "primary"))
	body.add_child(UI.button(Strings.t("season.standings"), func(): App.go(ScreenStandings.new())))
	body.add_child(UI.button(Strings.t("season.menu"), func(): App.autosave(); App.go(ScreenTitle.new())))


func _next() -> void:
	App.gs = App.gs.next_season()
	App.autosave()
	App.go(ScreenHub.new())
