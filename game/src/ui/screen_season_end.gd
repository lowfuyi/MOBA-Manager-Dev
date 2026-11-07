class_name ScreenSeasonEnd
extends Screen


func go_back() -> void:
	App.go(ScreenHub.new())


func _ready() -> void:
	var gs := App.gs
	setup(Strings.t("season.title"), go_back)
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
	_growth()
	_contracts()
	body.add_child(UI.button(Strings.t("season.next"), _next, "primary"))
	body.add_child(UI.button(Strings.t("hub.free_agents"), func(): App.go(ScreenFreeAgents.new("season"))))
	body.add_child(UI.button(Strings.t("hub.finance"), func(): App.go(ScreenFinance.new())))
	body.add_child(UI.button(Strings.t("season.standings"), func(): App.go(ScreenStandings.new())))
	body.add_child(UI.button(Strings.t("season.menu"), func(): App.autosave(); App.go(ScreenTitle.new())))


func _next() -> void:
	App.gs = App.gs.next_season()
	App.autosave()
	App.go(ScreenHub.new())


## Everyone on the roster who gained or lost 0.5 stat points or more this season.
func _growth() -> void:
	var gs := App.gs
	var w := App.world
	var g := UI.card(body)
	g.add_child(UI.label(Strings.t("season.growth_h"), UI.S_BODY, UI.ACCENT))
	var any := false
	for p in w.club_players(gs.club()):
		var parts: Array = []
		for st in World.STATS:
			var gain := gs.season_gain(p["id"], st)
			if absf(gain) >= 0.5:
				parts.append("%+.1f %s" % [gain, Strings.t("stat." + st)])
		if not parts.is_empty():
			any = true
			g.add_child(UI.label(Strings.f("season.growth_row", {"name": p["name"], "list": ", ".join(parts)}), UI.S_SMALL, UI.TEXT))
	if not any:
		g.add_child(UI.label(Strings.t("season.growth_none"), UI.S_SMALL, UI.DIM))


## Final-year contracts: renew them now or the players leave when the new season starts.
func _contracts() -> void:
	var gs := App.gs
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("season.contracts_h"), UI.S_BODY, UI.ACCENT))
	c.add_child(UI.label(Strings.f("season.cash_line", {"cash": PlayerView.money(gs.cash())}), UI.S_SMALL, UI.TEXT))
	var exp := gs.expiring()
	if exp.is_empty():
		c.add_child(UI.label(Strings.t("season.contracts_none"), UI.S_SMALL, UI.DIM))
		return
	c.add_child(UI.label(Strings.t("season.contracts_hint"), UI.S_SMALL, UI.DIM))
	for p in exp:
		var line := Strings.f("season.contract_row", {"name": p["name"], "role": Strings.t("role." + p["role_primary"]), "wage": gs.contract_of(p["id"])["wage"], "ask": gs.asking_wage(p["id"])})
		c.add_child(UI.button(line, func(): App.go(ScreenNegotiation.new(p["id"], true, "season")), "normal", 84))
	if gs.roster_after_expiry() < int(Economy.data()["min_roster"]):
		c.add_child(UI.label(Strings.f("season.contracts_min", {"n": Economy.data()["min_roster"]}), UI.S_SMALL, UI.WARN))
