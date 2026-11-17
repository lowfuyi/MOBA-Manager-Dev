class_name ScreenStandings
extends Screen
## Standings (GDD 7.4, UI-PASS-2 6.5, build plan I-20). Tab "club". Three views, built once and switched in place:
##   table     "League table" with the Points | Form Rating switch (tag stand.metric; a change raises stand:metric), the cut sentence
##             (GameState.cut_gap), the Podium for the top three, RankRows for 4 to 10 drawn by their container (StandKit.Rows) with
##             the dashed playoff line after 4th (Points only), your row marked by fill, bar and the YOU pill; a pinned row above the
##             tab bar with the line sentence while your own row is scrolled out of view
##   playoffs  the cut sentence and the bracket (StandKit.Bracket); before the playoffs a dashed "If the season ended now" bracket
##   history   the trophy totals and finished seasons, then the recent games (StandKit.Games: W or L, opponent, round, margin
##             word, three phase dots)
## Old tab names still open the right view: "form" = table with Form Rating, "results" and "trophies" = history (`_set_tab` kept).
## Read only: nothing here writes the save.

const VIEWS := ["table", "playoffs", "history"]
const RESULT_KEYS := {"champion": "trophies.r.champion", "runner_up": "trophies.r.runner_up", "finalist": "trophies.r.finalist",
		"won": "trophies.r.won", "lost": "trophies.r.lost", "missed": "trophies.r.missed"}

var _tab := "table"
var _metric := "points"
var build_count := 0
var refresh_count := 0

var views: DraftKit.RoleBar
var page_scroll: ScrollContainer
var table_box: VBoxContainer
var metric: DraftKit.RoleBar
var cut_label: Label
var podium: Podium
var rows: StandKit.Rows
var tiebreak: Label
var po_box: VBoxContainer
var po_label: Label
var bracket: StandKit.Bracket
var hist_box: VBoxContainer
var trophies: HomeKit.ChipRow
var seasons_label: Label
var games_head: Label
var games: StandKit.Games
var empty_label: Label
var pinned: RankRow
var _own_row: Dictionary = {}


func _init(tab: String = "table") -> void:
	super._init()
	_tab = tab


func tab_id() -> String:
	return "club"


func go_back() -> void:
	App.go_tab("club")


func _ready() -> void:
	setup("", Callable(), false)
	_apply_tab_name(_tab)
	_build()
	_refresh()


func _apply_tab_name(t: String) -> void:
	match t:
		"form":
			_tab = "table"
			_metric = "form"
		"results", "trophies":
			_tab = "history"
		_:
			_tab = t if VIEWS.has(t) else "table"


func view() -> String:
	return _tab


func _raise(event_name: String, data: Dictionary = {}) -> void:
	if is_instance_valid(App.bus):
		App.bus.emit(event_name, data)


# ---- data ---------------------------------------------------------------------------------------------------------------------

## The table rows in the order of the metric: [{rank, club, name, main, sub, own}] (the keys of Podium and RankRow).
func table_rows() -> Array:
	var gs := App.gs
	var st := gs.standings()
	var rec := {}
	for r in st:
		rec[r["club"]] = r
	var out: Array = []
	if _metric == "form":
		for f in gs.form_ranking():
			var r: Dictionary = rec[f["club"]]
			out.append({"rank": int(f["rank"]), "club": String(f["club"]), "name": gs.club_name(f["club"]), "main": str(int(round(float(f["rating"])))),
					"sub": "%d-%d" % [r["w"], r["l"]], "own": f["club"] == gs.club()})
	else:
		for r in st:
			out.append({"rank": int(r["rank"]), "club": String(r["club"]), "name": gs.club_name(r["club"]), "main": "%d %s" % [int(r["pts"]), Strings.t("standings.pts")],
					"sub": "%d-%d" % [r["w"], r["l"]], "own": r["club"] == gs.club()})
	return out


func cut_text() -> String:
	var c := App.gs.cut_gap()
	var st := String(c["state"])
	return Strings.f("standings.cut." + st, {"rank": int(c["rank"]), "n": absi(int(c["gap"]))})


func pin_text() -> String:
	var c := App.gs.cut_gap()
	var st := String(c["state"])
	if st == "after":
		return Strings.t("standings.cut.after")
	return Strings.f("standings.pin." + st, {"n": absi(int(c["gap"]))})


## SF1, SF2, F for the bracket; before the playoffs the projected pairs from the top four (ghost).
func bracket_data() -> Array:
	var gs := App.gs
	var out: Array = []
	if String(gs.d["phase"]) == "league":
		var st := gs.standings()
		var seeds: Array = []
		for i in mini(4, st.size()):
			seeds.append(String(st[i]["club"]))
		if seeds.size() == 4:
			out.append(_series_row({"id": "SF1", "a": seeds[0], "b": seeds[3], "best_of": 3, "wins_a": 0, "wins_b": 0, "done": false, "winner": ""}, seeds))
			out.append(_series_row({"id": "SF2", "a": seeds[1], "b": seeds[2], "best_of": 3, "wins_a": 0, "wins_b": 0, "done": false, "winner": ""}, seeds))
		out.append({"best_of": 5})
		return out
	var po: Dictionary = gs.d.get("playoffs", {})
	var seeds2: Array = po.get("seeds", [])
	var by := {}
	for s in po.get("series", []):
		by[String(s["id"])] = s
	for id in ["SF1", "SF2", "F"]:
		out.append(_series_row(by[id], seeds2) if by.has(id) else {"best_of": 5})
	return out


func _series_row(s: Dictionary, seeds: Array) -> Dictionary:
	var gs := App.gs
	var r := s.duplicate()
	r["a_name"] = gs.club_name(String(s["a"]))
	r["b_name"] = gs.club_name(String(s["b"]))
	r["seed_a"] = seeds.find(String(s["a"])) + 1
	r["seed_b"] = seeds.find(String(s["b"])) + 1
	return r


func games_data() -> Array:
	var gs := App.gs
	var hist: Array = gs.d["history"]
	var out: Array = []
	for i in range(hist.size() - 1, -1, -1):
		var h: Dictionary = hist[i]
		var mine_blue: bool = h["blue"] == gs.club()
		var opp: String = h["red"] if mine_blue else h["blue"]
		var sgn := 1.0 if mine_blue else -1.0
		var ph: Array = []
		var phs: Dictionary = h.get("phases", {})
		for k in ["early", "mid", "late"]:
			ph.append(1 if sgn * float(phs.get(k, 0.0)) > 0.0 else -1)
		var rt := Strings.f("home.round", {"round": int(h["round"]) + 1}) if String(h.get("kind", "league")) == "league" else Strings.t(gs.playoff_label({"id": h.get("series", "")}))
		out.append({"won": bool(h["won"]), "opp": opp, "opp_name": gs.club_name(opp), "round_text": rt,
				"word": Strings.t("report.margin." + Report.result_word(sgn * float(h["final"]))), "phases": ph})
	return out


# ---- building (once) ----------------------------------------------------------------------------------------------------------

func _build() -> void:
	build_count += 1
	ArtWire.prepare(App.world.club_ids, [])
	body.add_theme_constant_override("separation", 12)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, UI.HEADER_H)
	header.add_theme_constant_override("separation", 8)
	var back := UI.button("<", go_back, "normal", UI.BTN_H)
	back.custom_minimum_size = Vector2(UI.BTN_H, UI.BTN_H)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back)
	var title := UI.label(Strings.t("standings.title"), UI.S_BIG, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)
	if help_slot != null and help_slot.get_parent() == self:
		remove_child(help_slot)
		help_slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
		help_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
		header.add_child(help_slot)
	body.add_child(header)
	views = DraftKit.RoleBar.new(_set_tab, "stand.views", [
			{"id": "table", "label": Strings.t("standings.view.table"), "icon": "tab_club"},
			{"id": "playoffs", "label": Strings.t("standings.view.playoffs"), "icon": "trophy"},
			{"id": "history", "label": Strings.t("standings.view.history"), "icon": "clock"}], _tab)
	body.add_child(views)
	page_scroll = ScrollContainer.new()
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: call_deferred("_update_pin"))    # after the rows have moved
	page_scroll.resized.connect(func() -> void: call_deferred("_update_pin"))
	body.add_child(page_scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	page_scroll.add_child(page)
	# table
	table_box = VBoxContainer.new()
	table_box.add_theme_constant_override("separation", 12)
	page.add_child(table_box)
	table_box.add_child(UI.label(Strings.t("standings.table_h"), UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	metric = DraftKit.RoleBar.new(_set_metric, "stand.metric", [
			{"id": "points", "label": Strings.t("standings.metric.points"), "icon": "trophy"},
			{"id": "form", "label": Strings.t("standings.metric.form"), "icon": "form"}], _metric)
	table_box.add_child(metric)
	cut_label = UI.label("", UI.S_SMALL, UI.TEXT)
	cut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	table_box.add_child(cut_label)
	podium = Podium.new([], "stand.podium")
	table_box.add_child(podium)
	rows = StandKit.Rows.new()
	rows.sort_children.connect(func() -> void: call_deferred("_update_pin"))    # laid out (first frame, metric switch)
	table_box.add_child(rows)
	tiebreak = UI.label(Strings.t("standings.tiebreak"), UI.S_CAPTION, UI.DIM)
	tiebreak.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	table_box.add_child(tiebreak)
	# playoffs
	po_box = VBoxContainer.new()
	po_box.add_theme_constant_override("separation", 12)
	page.add_child(po_box)
	po_label = UI.label("", UI.S_SMALL, UI.TEXT)
	po_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	po_box.add_child(po_label)
	bracket = StandKit.Bracket.new()
	po_box.add_child(bracket)
	# history
	hist_box = VBoxContainer.new()
	hist_box.add_theme_constant_override("separation", 12)
	page.add_child(hist_box)
	hist_box.add_child(UI.label(Strings.t("trophies.h"), UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	trophies = HomeKit.ChipRow.new([])
	hist_box.add_child(trophies)
	seasons_label = UI.label("", UI.S_SMALL, UI.TEXT)
	seasons_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hist_box.add_child(seasons_label)
	games_head = UI.label(Strings.t("standings.tab.results"), UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold")
	hist_box.add_child(games_head)
	games = StandKit.Games.new()
	hist_box.add_child(games)
	empty_label = UI.label(Strings.t("standings.no_results"), UI.S_BODY, UI.DIM)
	hist_box.add_child(empty_label)
	# the pinned row (outside the scroll, above the tab bar)
	pinned = RankRow.new({}, "stand.pinned")
	pinned.visible = false
	body.add_child(pinned)


# ---- refreshing --------------------------------------------------------------------------------------------------------------

func _refresh() -> void:
	refresh_count += 1
	var gs := App.gs
	views.set_selected(_tab)
	metric.set_selected(_metric)
	table_box.visible = _tab == "table"
	po_box.visible = _tab == "playoffs"
	hist_box.visible = _tab == "history"
	if _tab == "table":
		cut_label.text = cut_text()
		var tr := table_rows()
		for r in tr:
			if bool(r["own"]):
				_own_row = r
		podium.set_rows(tr.slice(0, 3))
		var rest: Array = tr.slice(3)
		var kids := rows.get_children().filter(func(c: Node) -> bool: return c is RankRow)
		for i in rest.size():
			var rr: RankRow
			if i < kids.size():
				rr = kids[i]
			else:
				rr = RankRow.new({})
				rows.add_child(rr)
			rr.set_data(rest[i])
		for i in range(rest.size(), kids.size()):
			(kids[i] as Node).queue_free()
		_place_line()
		tiebreak.visible = _metric == "points"
		rows.queue_redraw()
	elif _tab == "playoffs":
		po_label.text = cut_text()
		var bd := bracket_data()
		bracket.set_data(bd, String(gs.d["phase"]) == "league", gs.club())
		if String(gs.d["phase"]) == "league":
			po_label.text = Strings.t("standings.bracket.ghost") + ". " + cut_text()
	else:
		var done: Array = gs.d["seasons_done"]
		var titles := 0
		var finals := 0
		var po := 0
		var prize := 0.0
		var lines: Array = []
		for i in range(done.size() - 1, -1, -1):
			var e: Dictionary = done[i]
			titles += 1 if e["result"] == "champion" else 0
			finals += 1 if e["result"] in ["champion", "runner_up", "finalist"] else 0
			po += 0 if e["result"] == "missed" else 1
			prize += float(e.get("prize", 0.0))
			lines.append("%s: %s" % [Strings.f("trophies.line", {"s": int(e["season"]), "rank": int(e["rank"]), "w": int(e["w"]), "l": int(e["l"])}), Strings.t(RESULT_KEYS[e["result"]])])
		trophies.set_items([[Strings.f("trophies.sum", {"t": titles, "f": finals, "p": po, "n": done.size()}), "accent", "trophy"],
				[Strings.f("trophies.prize_total", {"n": PlayerView.money(prize)}), "good", "coin"]])
		seasons_label.text = "\n".join(PackedStringArray(lines)) if not lines.is_empty() else Strings.t("trophies.none")
		var gd := games_data()
		games.set_games(gd)
		games.visible = not gd.is_empty()
		empty_label.visible = gd.is_empty()
	call_deferred("_update_pin")    # after the layout has placed the rows


## The dashed playoff line sits after 4th (the first row below the podium), for Points only.
func _place_line() -> void:
	var line: Node = null
	for c in rows.get_children():
		if c is RankRow.Divider:
			line = c
	if _metric != "points":
		if line != null:
			(line as Control).visible = false
		return
	if line == null:
		line = RankRow.divider(Strings.t("standings.playoff_line"))
		rows.add_child(line)
	(line as Control).visible = true
	rows.move_child(line, mini(1, rows.get_child_count() - 1))


## The pinned row shows while your own row is out of view (table view only; the podium counts as your row for the top three).
func _update_pin() -> void:
	if pinned == null:
		return
	var show := false
	if _tab == "table":
		var own: Control = null
		for c in rows.get_children():
			if c is RankRow and (c as RankRow).is_own():
				own = c
		var mine: Dictionary = _own_row
		if own == null:
			own = podium
		var vis := page_scroll.get_global_rect()
		var gr := own.get_global_rect()
		show = gr.size.y > 0.0 and not vis.intersects(gr.grow(-gr.size.y * 0.25))
		if show:
			var d := mine.duplicate()
			d["note"] = pin_text()
			pinned.set_data(d)
	pinned.visible = show


# ---- actions ------------------------------------------------------------------------------------------------------------------

func _set_tab(t: Variant) -> void:
	_apply_tab_name(String(t))
	page_scroll.scroll_vertical = 0
	_refresh()


func _set_metric(m: Variant) -> void:
	var v := String(m)
	if v == _metric or not ["points", "form"].has(v):
		return
	_metric = v
	_refresh()
	_raise("stand:metric", {"metric": v})
