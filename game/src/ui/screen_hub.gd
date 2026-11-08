class_name ScreenHub
extends Screen
## Home: one big "next match day" card with the single Play action, what needs attention, and four
## summary tiles that open the places behind them.


func tab_id() -> String:
	return "home"


func is_tab_root() -> bool:
	return true


func go_back() -> void:
	App.autosave()
	App.go(ScreenTitle.new())


func _ready() -> void:
	var gs := App.gs
	if gs.is_dismissed():
		App.go.call_deferred(ScreenGameOver.new())
		return
	setup("", Callable())
	var me := gs.club()
	var row := {}
	for r in gs.standings():
		if r["club"] == me:
			row = r
	var top := UI.vbox()
	top.add_child(UI.label(gs.club_name(me), UI.S_TITLE, UI.TEXT))
	var when: String
	match gs.d["phase"]:
		"league":
			when = Strings.f("hub.when.league", {"season": gs.d["season"], "round": int(gs.d["round"]) + 1, "total": gs.total_rounds(), "patch": gs.patch_label()})
		"playoffs":
			when = Strings.f("hub.when.playoffs", {"season": gs.d["season"]})
		_:
			when = Strings.f("hub.when.done", {"season": gs.d["season"]})
	top.add_child(UI.label(when, UI.S_SMALL, UI.DIM))
	body.add_child(top)
	Tips.show(body, "hub")
	var g := gs.next_game()
	if gs.d["phase"] == "done":
		_done_card()
	elif g.is_empty():
		var c := UI.card(body)
		c.add_child(UI.label(Strings.t("hub.waiting"), UI.S_BODY, UI.DIM))
		c.add_child(UI.button(Strings.t("hub.skip_to_end"), _skip_to_end, "primary"))
	else:
		_next_card(g)
	_attention()
	_tiles(row)


func _next_card(g: Dictionary) -> void:
	var gs := App.gs
	var me := gs.club()
	var opp: String = g["red"] if g["blue"] == me else g["blue"]
	var side := Strings.t("hub.side.blue") if g["blue"] == me else Strings.t("hub.side.red")
	var c := UI.card(body, UI.PANEL2, 24, Color(UI.CORAL.r, UI.CORAL.g, UI.CORAL.b, 0.6), 2)
	var title_key := "hub.next.league"
	var extra := ""
	if g["kind"] == "playoff":
		title_key = "hub.next.playoff"
		for s in gs.d["playoffs"]["series"]:
			if s["id"] == g["series"]:
				extra = Strings.f("hub.series_state", {"stage": Strings.t(gs.playoff_label(s)), "bo": s["best_of"], "game": g["game"], "a": gs.club_name(s["a"]), "wa": s["wins_a"], "b": gs.club_name(s["b"]), "wb": s["wins_b"]})
	c.add_child(UI.label(Strings.t(title_key), UI.S_SMALL, UI.CORAL))
	c.add_child(UI.label(gs.club_name(opp), UI.S_TITLE, UI.TEXT))
	if extra != "":
		c.add_child(UI.label(extra, UI.S_SMALL, UI.ACCENT))
	var mine := App.world.team_rating(gs.lineup())
	var theirs := App.world.team_rating(gs.lineup_for(opp))
	var nums := UI.hbox()
	nums.add_child(UI.label(Strings.f("hub.rating_you", {"v": "%.1f" % mine}), UI.S_BODY, UI.ACCENT))
	var rt := UI.label(Strings.f("hub.rating_them", {"v": "%.1f" % theirs}), UI.S_BODY, UI.CORAL, HORIZONTAL_ALIGNMENT_RIGHT)
	nums.add_child(rt)
	c.add_child(nums)
	c.add_child(UI.versus_bar(mine, theirs))
	var chips: Array = [[side, UI.BLUE if g["blue"] == me else UI.RED], [Strings.t("hub.draft.full" if g["full"] else "hub.draft.short"), UI.DIM],
			[Strings.f("hub.chip.chem", {"bonus": UI.pct(gs.chem_bonus())}), UI.ACCENT]]
	var tired := gs.tired_starters().size()
	if tired > 0:
		chips.append([Strings.f("hub.chip.tired", {"n": tired}), UI.WARN])
	UI.chips(c, chips)
	c.add_child(UI.button(Strings.t("hub.play"), func(): App.pace_t0 = Time.get_ticks_msec(); App.go(ScreenPreMatch.new(g)), "play"))
	c.add_child(UI.button(Strings.t("hub.quick"), func(): _quick(g), "normal", 76))


## Things that need a decision from the manager, each one a tap to the place where it is fixed.
func _attention() -> void:
	var gs := App.gs
	var items: Array = []
	var tired := gs.tired_starters().size()
	if tired > 0 and not gs.next_game().is_empty():
		items.append([Strings.f("hub.att.tired", {"n": tired}), func(): App.go(ScreenRoster.new("hub"))])
	var ex := gs.expiring().size()
	if ex > 0:
		items.append([Strings.f("hub.att.contracts", {"n": ex}), func(): App.go(ScreenRoster.new("hub"))])
	if gs.cash() < 0.0:
		items.append([Strings.f("hub.debt_warn", {"n": gs.debt_rounds_left()}), func(): App.go(ScreenFinance.new())])
	if items.is_empty():
		return
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("hub.att.h"), UI.S_BODY, UI.WARN))
	for it in items:
		var b := UI.button(it[0], it[1], "normal", 76)
		b.add_theme_color_override("font_color", UI.WARN)
		c.add_child(b)


func _tiles(row: Dictionary) -> void:
	var gs := App.gs
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(grid)
	var net := int(round(gs.weekly_net()))
	grid.add_child(UI.tile(Strings.t("hub.tile.standing"), Strings.f("hub.tile.rank", {"rank": row.get("rank", 0)}),
			Strings.f("hub.tile.record", {"w": row.get("w", 0), "l": row.get("l", 0), "pts": row.get("pts", 0)}), UI.TEXT, func(): App.go(ScreenStandings.new())))
	grid.add_child(UI.tile(Strings.t("hub.tile.cash"), PlayerView.money(gs.cash()), Strings.f("hub.tile.net", {"net": "%+d" % net}),
			UI.GOOD if gs.cash() >= 0.0 else UI.BAD, func(): App.go(ScreenFinance.new())))
	grid.add_child(UI.tile(Strings.t("hub.tile.chem"), UI.pct(gs.chem_bonus()), Strings.f("hub.tile.bonds", {"avg": "%.0f" % gs.bond_mean()}),
			UI.ACCENT, func(): App.go(ScreenChemistry.new())))
	var mor := 0.0
	var frm := 0.0
	var ids: Array = (gs.d["lineup"] as Dictionary).values()
	for pid in ids:
		mor += gs.morale_of(pid)
		frm += gs.form_of(pid)
	mor /= float(maxi(1, ids.size()))
	frm /= float(maxi(1, ids.size()))
	grid.add_child(UI.tile(Strings.t("hub.tile.mood"), Strings.t("mood.word." + Bonds.mood_word(mor)), Strings.f("hub.tile.form", {"form": UI.signed(frm, 1)}),
			UI.delta_color(frm), func(): App.go(ScreenRoster.new("hub"))))


func _quick(g: Dictionary) -> void:
	var res := App.gs.auto_game(g)
	App.gs.pace_quick()
	_finish_game(g, res)


## Record the finished game and open the payoff screen. The numbers that changed (form, morale, bonds,
## cash, chemistry) are captured before and after, so the payoff screen can show what the game did.
static func _finish_game(g: Dictionary, res: Dictionary) -> void:
	var gs := App.gs
	var before := Payoff.snapshot(gs)
	App.last_game = g
	App.last_result = res
	gs.record_human_game(g, res)
	App.last_payoff = Payoff.compare(gs, before)
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
