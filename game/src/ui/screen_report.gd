class_name ScreenReport
extends Screen
## Post-game report: result, why it went that way (counterfactual attribution), draft recap.

var game: Dictionary
var res: Dictionary
var _quick := false


func _init(g: Dictionary = {}, r: Dictionary = {}, quick: bool = false) -> void:
	super._init()
	game = g
	res = r
	_quick = quick


func go_back() -> void:
	_leave()


func _leave() -> void:
	if App.gs.d["phase"] == "done":
		App.go(ScreenSeasonEnd.new())
	else:
		App.go(ScreenHub.new())


func _ready() -> void:
	var gs := App.gs
	var my_side := "B" if game["blue"] == gs.club() else "R"
	var opp_id: String = game["red"] if my_side == "B" else game["blue"]
	var won: bool = res["blue_won"] == (my_side == "B")
	setup("", Callable())
	# result banner
	var c := UI.card(body, UI.PANEL2)
	c.add_child(UI.label(Strings.t("report.victory" if won else "report.defeat"), UI.S_TITLE, UI.GOOD if won else UI.BAD, HORIZONTAL_ALIGNMENT_CENTER))
	c.add_child(UI.label("%s  vs  %s" % [gs.club_name(gs.club()), gs.club_name(opp_id)], UI.S_BODY, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var word := Report.result_word(float(res["final"]))
	c.add_child(UI.label(Strings.f("report.summary", {"margin": Strings.t("report.margin." + word), "len": ScreenMatch._mmss(Report.game_minutes(res))}), UI.S_SMALL, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if game["kind"] == "playoff":
		for s in gs.d["playoffs"]["series"]:
			if s["id"] == game["series"]:
				c.add_child(UI.label(Strings.f("report.series", {"stage": Strings.t(gs.playoff_label(s)), "a": gs.club_name(s["a"]), "wa": s["wins_a"], "b": gs.club_name(s["b"]), "wb": s["wins_b"]}), UI.S_BODY, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UI.button(Strings.t("common.continue"), _leave, "primary"))
	_why(my_side, won)
	_moments(my_side)
	_draft_recap(my_side)
	body.add_child(UI.button(Strings.t("common.continue"), _leave, "primary"))


func _why(my_side: String, won: bool) -> void:
	var att := Report.attribution(res, my_side)
	var factors: Array = att["factors"]
	factors.sort_custom(func(a, b): return absf(a["value"]) > absf(b["value"]))
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("report.why_h"), UI.S_BODY, UI.ACCENT))
	var best := {}
	var worst := {}
	for f in factors:
		if f["value"] > 0.0 and best.is_empty():
			best = f
		if f["value"] < 0.0 and worst.is_empty():
			worst = f
	if not best.is_empty():
		c.add_child(UI.label(Strings.f("report.helped", {"what": Strings.t("factor." + best["id"])}), UI.S_BODY, UI.GOOD))
	if not worst.is_empty():
		c.add_child(UI.label(Strings.f("report.hurt", {"what": Strings.t("factor." + worst["id"])}), UI.S_BODY, UI.BAD))
	for f in factors:
		var row := UI.hbox()
		var l := UI.label(Strings.t("factor." + f["id"]), UI.S_SMALL, UI.TEXT)
		l.custom_minimum_size = Vector2(300, 0)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(l)
		var good: bool = f["value"] >= 0.0
		var b := UI.bar(absf(float(f["share"])) * 100.0, 60.0, UI.GOOD if good else UI.BAD, 20)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		var v := UI.label(("+" if good else "-") + "%d%%" % int(round(absf(float(f["share"])) * 100.0)), UI.S_SMALL, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		v.custom_minimum_size = Vector2(90, 0)
		v.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(v)
		c.add_child(row)
	c.add_child(UI.label(Strings.t("report.why_note"), UI.S_SMALL - 2, UI.DIM))


func _moments(my_side: String) -> void:
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("report.moments_h"), UI.S_BODY, UI.ACCENT))
	var total := Report.game_minutes(res)
	for ev in Report.feed(res, my_side):
		var line := Strings.f("feed.line", {"t": ScreenMatch._mmss(float(ev["t"]) * total), "title": Strings.t("feed.t." + ev["key"]),
				"result": Strings.f("feed.win" if ev["mine"] else "feed.loss", {"size": Strings.t("feed.m." + ev["size"])})})
		c.add_child(UI.label(line, UI.S_SMALL, UI.GOOD if ev["mine"] else UI.BAD))


func _draft_recap(my_side: String) -> void:
	var w := App.world
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("report.draft_h"), UI.S_BODY, UI.ACCENT))
	var opp := "R" if my_side == "B" else "B"
	for t in [my_side, opp]:
		c.add_child(UI.label(Strings.t("draft.you") if t == my_side else Strings.t("draft.opponent"), UI.S_SMALL, UI.BLUE if t == "B" else UI.RED))
		for s in GameState.SLOTS:
			var p: Dictionary = w.players[res["lineups"][t][s]]
			var h: Dictionary = w.heroes[res["picks"][t][s]]
			c.add_child(UI.label("%s: %s  -  %s" % [Strings.t("role." + s), p["name"], h["name"]], UI.S_SMALL, UI.TEXT))
		c.add_child(UI.label(Strings.f("draft.comp_line", {"style": Strings.t("style." + String(res["style"][t])), "mod": UI.pct(float(res["comp"][t]))}), UI.S_SMALL, UI.DIM))
		var bans: Array = []
		for hid in res["bans"][t]:
			bans.append(w.heroes[hid]["name"])
		c.add_child(UI.label(Strings.f("draft.bans", {"list": ", ".join(bans)}), UI.S_SMALL - 2, UI.DIM))
