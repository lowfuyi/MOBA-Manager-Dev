class_name ScreenReport
extends Screen
## Payoff screen after a game: the result, who stood out, what the game did to form, morale, bonds and
## cash, one tip for the next game; the full explanation (why, key moments, draft) is one tap below.

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
	setup(Strings.t("report.title"), _leave)
	# 1. the result, big
	var edge := UI.GOOD if won else UI.BAD
	var c := UI.card(body, UI.PANEL2, 24, Color(edge.r, edge.g, edge.b, 0.6), 2)
	c.add_child(UI.label(Strings.t("report.victory" if won else "report.defeat"), 64, edge, HORIZONTAL_ALIGNMENT_CENTER))
	c.add_child(UI.label("%s  vs  %s" % [gs.club_name(gs.club()), gs.club_name(opp_id)], UI.S_BODY, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var word := Report.result_word(float(res["final"]))
	c.add_child(UI.label(Strings.f("report.summary", {"margin": Strings.t("report.margin." + word), "len": ScreenMatch._mmss(Report.game_minutes(res))}), UI.S_SMALL, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if game["kind"] == "playoff":
		for ser in gs.d["playoffs"]["series"]:
			if ser["id"] == game["series"]:
				c.add_child(UI.label(Strings.f("report.series", {"stage": Strings.t(gs.playoff_label(ser)), "a": gs.club_name(ser["a"]), "wa": ser["wins_a"], "b": gs.club_name(ser["b"]), "wb": ser["wins_b"]}), UI.S_BODY, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	if UI.animate:
		var card: Control = c.get_parent()
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, UI.T_FADE)
	var att := Report.attribution(res, my_side)
	_standout(my_side, att)
	_payoff()
	_tip()
	body.add_child(UI.button(Strings.t("common.continue"), _leave, "play"))
	# 2. the details, one tap away
	_why(att)
	_moments(my_side)
	_draft_recap(my_side)
	body.add_child(UI.button(Strings.t("common.continue"), _leave, "primary"))


## The player whose slot moved the result most for you (after a loss with no positive slot: the weakest).
func _standout(my_side: String, att: Dictionary) -> void:
	var best := {}
	var worst := {}
	for f in att["factors"]:
		if not String(f["id"]).begins_with("slot."):
			continue
		if best.is_empty() or f["value"] > best["value"]:
			best = f
		if worst.is_empty() or f["value"] < worst["value"]:
			worst = f
	if best.is_empty():
		return
	var good: bool = float(best["value"]) > 0.0
	var pick: Dictionary = best if good else worst
	if int(round(absf(float(pick["share"])) * 100.0)) < 3:
		return    # nobody really decided it: no standout line rather than "0% of the result"
	var slot := String(pick["id"]).substr(5)
	var pid: String = res["lineups"][my_side][slot]
	var hero: String = App.world.heroes[res["picks"][my_side][slot]]["name"]
	var c := UI.card(body)
	c.add_child(UI.label(Strings.f("report.standout" if good else "report.weak", {"name": App.world.players[pid]["name"], "role": Strings.t("role." + slot),
			"hero": hero, "pct": "%d" % int(round(absf(float(pick["share"])) * 100.0))}), UI.S_BODY, UI.GOOD if good else UI.WARN))


func _col_label(text: String, color: Color, size: int) -> Label:
	var l := UI.label(text, size, color, HORIZONTAL_ALIGNMENT_RIGHT)
	l.custom_minimum_size = Vector2(170, 0)
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	return l


## What the game did to the squad: form and morale of the five starters, bonds, chemistry, money.
func _payoff() -> void:
	var po: Dictionary = App.last_payoff
	if po.is_empty():
		return
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("report.pay.h"), UI.S_BODY, UI.ACCENT))
	var head := UI.hbox()
	head.add_child(UI.label("", UI.S_SMALL - 2, UI.DIM))
	head.add_child(_col_label(Strings.t("report.pay.form"), UI.DIM, UI.S_SMALL - 2))
	head.add_child(_col_label(Strings.t("report.pay.morale"), UI.DIM, UI.S_SMALL - 2))
	c.add_child(head)
	for r in po["rows"]:
		var h := UI.hbox()
		h.add_child(UI.label("%s  %s" % [Strings.t("role.short." + r["slot"]), App.world.players[r["id"]]["name"]], UI.S_SMALL, UI.TEXT))
		var df: float = float(r["form_a"]) - float(r["form_b"])
		var dm: float = float(r["mor_a"]) - float(r["mor_b"])
		h.add_child(_col_label(UI.signed(df, 1), UI.delta_color(df), UI.S_SMALL))
		h.add_child(_col_label(UI.signed(dm, 0), UI.delta_color(dm), UI.S_SMALL))
		c.add_child(h)
	var db: float = float(po["bond_a"]) - float(po["bond_b"])
	var bl := _pay_line(c, Strings.t("report.pay.bonds"), "%.0f" % float(po["bond_a"]), UI.delta_color(db))
	UI.count_up(bl, float(po["bond_a"]), "%.0f", float(po["bond_b"]))
	_pay_line(c, Strings.t("report.pay.chem"), UI.pct(float(po["chem_a"])), UI.delta_color(float(po["chem_a"]) - float(po["chem_b"])))
	if absf(float(po["cash_d"])) >= 1.0:
		_pay_line(c, Strings.t("report.pay.cash"), "%+d" % int(round(float(po["cash_d"]))), UI.delta_color(float(po["cash_d"])))


## "Key ........ value": returns the value label so a number can count up in it.
func _pay_line(parent: VBoxContainer, key: String, value: String, color: Color) -> Label:
	var h := UI.hbox()
	h.add_child(UI.label(key, UI.S_SMALL, UI.DIM))
	var v := _col_label(value, color, UI.S_SMALL)
	h.add_child(v)
	parent.add_child(h)
	return v


func _tip() -> void:
	var t := Payoff.tip(App.gs)
	var c := UI.card(body, UI.PANEL2)
	c.add_child(UI.label(Strings.t("report.tip_h"), UI.S_SMALL, UI.CORAL))
	c.add_child(UI.label(Strings.f(t["key"], t["args"]), UI.S_BODY, UI.TEXT))


func _why(att: Dictionary) -> void:
	var factors: Array = att["factors"]
	factors.sort_custom(func(a, b): return absf(a["value"]) > absf(b["value"]))
	var c := UI.section(body, Strings.t("report.why_h"), true)
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
	var c := UI.section(body, Strings.t("report.moments_h"), false)
	var total := Report.game_minutes(res)
	for ev in Report.feed(res, my_side):
		var line := Strings.f("feed.line", {"t": ScreenMatch._mmss(float(ev["t"]) * total), "title": Strings.t("feed.t." + ev["key"]),
				"result": Strings.f("feed.win" if ev["mine"] else "feed.loss", {"size": Strings.t("feed.m." + ev["size"])})})
		c.add_child(UI.label(line, UI.S_SMALL, UI.GOOD if ev["mine"] else UI.BAD))


func _draft_recap(my_side: String) -> void:
	var w := App.world
	var c := UI.section(body, Strings.t("report.draft_h"), false)
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
