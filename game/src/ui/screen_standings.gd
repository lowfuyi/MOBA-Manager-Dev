class_name ScreenStandings
extends Screen

var _tab := "table"


func _init(tab: String = "table") -> void:
	super._init()
	_tab = tab


func tab_id() -> String:
	return "club"


func go_back() -> void:
	App.go_tab("club")


func _ready() -> void:
	setup(Strings.t("standings.title"), go_back)
	_rebuild()


func _rebuild() -> void:
	UI.clear(body)
	var tabs := HFlowContainer.new()    # five tabs wrap onto a second line instead of pushing the page wider than the screen
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	for t in ["table", "form", "playoffs", "results", "trophies"]:
		tabs.add_child(UI.button(Strings.t("standings.tab." + t), _set_tab.bind(t), "primary" if _tab == t else "normal", 72))
	body.add_child(tabs)
	match _tab:
		"table":
			_table()
		"form":
			_form()
		"trophies":
			_trophies()
		"playoffs":
			_playoffs()
		_:
			_results()


func _set_tab(t: String) -> void:
	_tab = t
	_rebuild()


func _table() -> void:
	var gs := App.gs
	var c := UI.card(body)
	c.add_child(_row(["#", Strings.t("standings.club"), "W-L", Strings.t("standings.pts"), Strings.t("standings.form")], UI.DIM, UI.S_SMALL))
	var fr := {}
	for f in gs.form_ranking():
		fr[f["club"]] = f
	for r in gs.standings():
		var mine: bool = r["club"] == gs.club()
		c.add_child(_row([str(r["rank"]), gs.club_name(r["club"]), "%d-%d" % [r["w"], r["l"]], str(r["pts"]), "#%d" % int(fr[r["club"]]["rank"])], UI.ACCENT if mine else UI.TEXT, UI.S_BODY))
	body.add_child(UI.label(Strings.t("standings.tiebreak"), UI.S_SMALL - 2, UI.DIM))


func _row(cols: Array, color: Color, size: int) -> HBoxContainer:
	var h := UI.hbox()
	var widths := [52, 0, 100, 64, 76]
	for i in cols.size():
		var l := UI.label(cols[i], size, color)
		if widths[i] > 0:
			l.custom_minimum_size = Vector2(widths[i], 0)
			l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		h.add_child(l)
	return h


func _form() -> void:
	var gs := App.gs
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("standings.form_h"), UI.S_BODY, UI.ACCENT))
	c.add_child(UI.label(Strings.t("standings.form_note"), UI.S_SMALL, UI.DIM))
	c.add_child(_row(["#", Strings.t("standings.club"), Strings.t("standings.form")], UI.DIM, UI.S_SMALL))
	for f in gs.form_ranking():
		var mine: bool = f["club"] == gs.club()
		c.add_child(_row([str(f["rank"]), gs.club_name(f["club"]), str(int(round(f["rating"])))], UI.ACCENT if mine else UI.TEXT, UI.S_BODY))


const RESULT_KEYS := {"champion": "trophies.r.champion", "runner_up": "trophies.r.runner_up", "finalist": "trophies.r.finalist",
		"won": "trophies.r.won", "lost": "trophies.r.lost", "missed": "trophies.r.missed"}


func _trophies() -> void:
	var gs := App.gs
	var done: Array = gs.d["seasons_done"]
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("trophies.h"), UI.S_BODY, UI.ACCENT))
	if done.is_empty():
		c.add_child(UI.label(Strings.t("trophies.none"), UI.S_SMALL, UI.DIM))
		return
	var titles := 0
	var finals := 0
	var po := 0
	for e in done:
		titles += 1 if e["result"] == "champion" else 0
		finals += 1 if e["result"] == "champion" or e["result"] == "runner_up" or e["result"] == "finalist" else 0
		po += 0 if e["result"] == "missed" else 1
	c.add_child(UI.label(Strings.f("trophies.sum", {"t": titles, "f": finals, "p": po, "n": done.size()}), UI.S_SMALL, UI.TEXT))
	var prize_total := 0.0
	for e in done:
		prize_total += float(e.get("prize", 0.0))
	c.add_child(UI.label(Strings.f("trophies.prize_total", {"n": PlayerView.money(prize_total)}), UI.S_SMALL, UI.GOOD))
	for i in range(done.size() - 1, -1, -1):
		var e: Dictionary = done[i]
		var col: Color = UI.GOOD if e["result"] == "champion" else (UI.ACCENT if e["result"] == "runner_up" or e["result"] == "finalist" else UI.TEXT)
		var card := UI.card(body, UI.PANEL2, 14)
		card.add_child(UI.label(Strings.f("trophies.line", {"s": int(e["season"]), "rank": int(e["rank"]), "w": int(e["w"]), "l": int(e["l"])}), UI.S_SMALL, UI.DIM))
		card.add_child(UI.label(Strings.t(RESULT_KEYS[e["result"]]), UI.S_BODY, col))
		if float(e.get("prize", 0.0)) > 0.0:
			card.add_child(UI.label(Strings.f("trophies.prize", {"n": PlayerView.money(float(e["prize"]))}), UI.S_SMALL, UI.GOOD))


func _playoffs() -> void:
	var gs := App.gs
	if gs.d["phase"] == "league":
		var c := UI.card(body)
		c.add_child(UI.label(Strings.f("standings.po_pending", {"n": gs.total_rounds() - int(gs.d["round"])}), UI.S_BODY, UI.DIM))
		return
	for s in gs.d["playoffs"]["series"]:
		var c := UI.card(body)
		c.add_child(UI.label(Strings.f("standings.series", {"stage": Strings.t(gs.playoff_label(s)), "bo": s["best_of"]}), UI.S_SMALL, UI.DIM))
		c.add_child(UI.label("%s  %d - %d  %s" % [gs.club_name(s["a"]), s["wins_a"], s["wins_b"], gs.club_name(s["b"])], UI.S_BODY, UI.ACCENT if (s["a"] == gs.club() or s["b"] == gs.club()) else UI.TEXT))
		if s["done"]:
			c.add_child(UI.label(Strings.f("standings.winner", {"club": gs.club_name(s["winner"])}), UI.S_SMALL, UI.GOOD))


func _results() -> void:
	var gs := App.gs
	var c := UI.card(body)
	var hist: Array = gs.d["history"]
	if hist.is_empty():
		c.add_child(UI.label(Strings.t("standings.no_results"), UI.S_BODY, UI.DIM))
		return
	for i in range(hist.size() - 1, -1, -1):
		var h: Dictionary = hist[i]
		var opp: String = h["red"] if h["blue"] == gs.club() else h["blue"]
		var tag := "W" if h["won"] else "L"
		c.add_child(UI.label("%s  %s %s" % [tag, Strings.t("standings.vs"), gs.club_name(opp)], UI.S_BODY, UI.GOOD if h["won"] else UI.BAD))
