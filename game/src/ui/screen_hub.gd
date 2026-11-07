class_name ScreenHub
extends Screen


func go_back() -> void:
	App.autosave()
	App.go(ScreenTitle.new())


func _ready() -> void:
	var gs := App.gs
	if gs.is_dismissed():
		App.go.call_deferred(ScreenGameOver.new())
		return
	setup(Strings.t("hub.menu_title"), go_back)
	var me := gs.club()
	var row := {}
	for r in gs.standings():
		if r["club"] == me:
			row = r
	var head := UI.card(body, UI.PANEL2)
	head.add_child(UI.label(gs.club_name(me), UI.S_TITLE, UI.TEXT))
	var when: String
	match gs.d["phase"]:
		"league":
			when = Strings.f("hub.when.league", {"season": gs.d["season"], "round": int(gs.d["round"]) + 1, "total": gs.total_rounds(), "patch": gs.patch_label()})
		"playoffs":
			when = Strings.f("hub.when.playoffs", {"season": gs.d["season"]})
		_:
			when = Strings.f("hub.when.done", {"season": gs.d["season"]})
	head.add_child(UI.label(when, UI.S_SMALL, UI.DIM))
	head.add_child(UI.label(Strings.f("hub.record", {"w": row.get("w", 0), "l": row.get("l", 0), "pts": row.get("pts", 0), "rank": row.get("rank", 0)}), UI.S_BODY, UI.ACCENT))
	head.add_child(UI.label(Strings.f("hub.cash", {"cash": PlayerView.money(gs.cash()), "net": "%+d" % int(round(gs.weekly_net()))}), UI.S_SMALL, UI.GOOD if gs.cash() >= 0.0 else UI.BAD))
	if gs.cash() < 0.0:
		head.add_child(UI.label(Strings.f("hub.debt_warn", {"n": gs.debt_rounds_left()}), UI.S_SMALL, UI.BAD))
	var g := gs.next_game()
	if gs.d["phase"] == "done":
		_done_card()
	elif g.is_empty():
		var c := UI.card(body)
		c.add_child(UI.label(Strings.t("hub.waiting"), UI.S_BODY, UI.DIM))
		c.add_child(UI.button(Strings.t("hub.skip_to_end"), _skip_to_end, "primary"))
	else:
		_next_card(g)
	body.add_child(UI.button(Strings.t("hub.roster"), func(): App.go(ScreenRoster.new("hub"))))
	body.add_child(UI.button(Strings.t("hub.training"), func(): App.go(ScreenTraining.new())))
	body.add_child(UI.button(Strings.t("hub.free_agents"), func(): App.go(ScreenFreeAgents.new("hub"))))
	body.add_child(UI.button(Strings.t("hub.finance"), func(): App.go(ScreenFinance.new())))
	body.add_child(UI.button(Strings.t("hub.standings"), func(): App.go(ScreenStandings.new())))
	body.add_child(UI.button(Strings.t("hub.settings"), func(): App.go(ScreenSettings.new())))


func _next_card(g: Dictionary) -> void:
	var gs := App.gs
	var me := gs.club()
	var opp: String = g["red"] if g["blue"] == me else g["blue"]
	var side := Strings.t("hub.side.blue") if g["blue"] == me else Strings.t("hub.side.red")
	var c := UI.card(body)
	var title_key := "hub.next.league"
	var extra := ""
	if g["kind"] == "playoff":
		title_key = "hub.next.playoff"
		for s in gs.d["playoffs"]["series"]:
			if s["id"] == g["series"]:
				extra = Strings.f("hub.series_state", {"stage": Strings.t(gs.playoff_label(s)), "bo": s["best_of"], "game": g["game"], "a": gs.club_name(s["a"]), "wa": s["wins_a"], "b": gs.club_name(s["b"]), "wb": s["wins_b"]})
	c.add_child(UI.label(Strings.t(title_key), UI.S_SMALL, UI.DIM))
	c.add_child(UI.label(gs.club_name(opp), UI.S_BIG, UI.TEXT))
	var mine := App.world.team_rating(gs.lineup())
	var theirs := App.world.team_rating(gs.lineup_for(opp))
	c.add_child(UI.label(Strings.f("hub.ratings", {"mine": "%.1f" % mine, "theirs": "%.1f" % theirs}), UI.S_BODY, UI.GOOD if mine >= theirs else UI.WARN))
	c.add_child(UI.label(Strings.f("hub.side_line", {"side": side, "draft": Strings.t("hub.draft.full" if g["full"] else "hub.draft.short")}), UI.S_SMALL, UI.DIM))
	if extra != "":
		c.add_child(UI.label(extra, UI.S_SMALL, UI.ACCENT))
	var tired := gs.tired_starters().size()
	if tired > 0:
		c.add_child(UI.label(Strings.f("hub.tired_warn", {"n": tired}), UI.S_SMALL, UI.WARN))
	c.add_child(UI.button(Strings.t("hub.play"), func(): App.go(ScreenPreMatch.new(g)), "primary"))
	c.add_child(UI.button(Strings.t("hub.quick"), func(): _quick(g), "normal", 76))


func _quick(g: Dictionary) -> void:
	var res := App.gs.auto_game(g)
	_finish_game(g, res)


static func _finish_game(g: Dictionary, res: Dictionary) -> void:
	App.last_game = g
	App.last_result = res
	App.gs.record_human_game(g, res)
	App.autosave()
	App.go(ScreenReport.new(g, res, false))


func _skip_to_end() -> void:
	App.gs.autoplay(true)
	App.autosave()
	App.go(ScreenHub.new())


func _done_card() -> void:
	var gs := App.gs
	var c := UI.card(body)
	c.add_child(UI.label(Strings.f("hub.champion", {"club": gs.club_name(gs.d["champion"])}), UI.S_BIG, UI.WARN))
	c.add_child(UI.button(Strings.t("hub.season_summary"), func(): App.go(ScreenSeasonEnd.new()), "primary"))
