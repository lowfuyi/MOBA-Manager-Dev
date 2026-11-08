class_name ScreenStandings
extends Screen

var _tab := "table"


func tab_id() -> String:
	return "club"


func go_back() -> void:
	App.go_tab("club")


func _ready() -> void:
	setup(Strings.t("standings.title"), go_back)
	_rebuild()


func _rebuild() -> void:
	UI.clear(body)
	var tabs := UI.hbox()
	for t in ["table", "playoffs", "results"]:
		tabs.add_child(UI.button(Strings.t("standings.tab." + t), _set_tab.bind(t), "primary" if _tab == t else "normal", 72))
	body.add_child(tabs)
	match _tab:
		"table":
			_table()
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
	c.add_child(_row(["#", Strings.t("standings.club"), "W-L", Strings.t("standings.pts")], UI.DIM, UI.S_SMALL))
	for r in gs.standings():
		var mine: bool = r["club"] == gs.club()
		c.add_child(_row([str(r["rank"]), gs.club_name(r["club"]), "%d-%d" % [r["w"], r["l"]], str(r["pts"])], UI.ACCENT if mine else UI.TEXT, UI.S_BODY))
	body.add_child(UI.label(Strings.t("standings.tiebreak"), UI.S_SMALL - 2, UI.DIM))


func _row(cols: Array, color: Color, size: int) -> HBoxContainer:
	var h := UI.hbox()
	var widths := [60, 0, 120, 90]
	for i in cols.size():
		var l := UI.label(cols[i], size, color)
		if widths[i] > 0:
			l.custom_minimum_size = Vector2(widths[i], 0)
			l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		h.add_child(l)
	return h


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
