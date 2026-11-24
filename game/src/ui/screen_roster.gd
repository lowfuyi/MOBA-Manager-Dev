class_name ScreenRoster
extends Screen
## The Squad (GDD 7.2, UI-PASS-2 6.2, build plan I-19). Tab "squad"; also opened from Match day (Pre-match) with the tab bar hidden
## and a Done button. Built once (`_build()`), refreshed in place after every change (`_refresh()`):
##   header    the title and Auto lineup (with Undo)
##   pills     team rating, chemistry (tap: Team chemistry), squad count, wages a week
##   map       "Starting five": the five starters as tokens on the player's half of Wrenfell (SquadKit.LaneMap, ART-BIBLE 6.4).
##             A tap on a token opens the lane picker (sheet lane_picker): every player of the club as a row with the rating in that
##             role and the CHANGE IN TEAM RATING if you pick them (the preview equals the rating after the swap); the current
##             starter's row opens his player sheet instead. A tap on a row commits (gs.assign: a starter elsewhere swaps), with Undo
##   bench     the other players as avatar cards, two columns (the first is tagged squad.bench.0; the first with a contract
##             ending, squad.bench.expiring), and a "Find a player" card that opens the free-agent market
##   sheet     the player sheet (id player_card, size L): the card's head (tag roster.card.head), Overview | Stats | Career, and
##             Put in lineup, Renew (roster.card.renew), Release (roster.card.release, confirmed in a second sheet)
## Events: open:player_card and open:lane_picker come from BottomSheet (open:<id>). Kept entry points (tests and the old callers):
## _toggle_slot (opens or closes the picker), _assign, _toggle_player (opens or closes the player sheet), _auto, _release,
## _rebuild (a full rebuild; no tap calls it). Nothing here changes the simulation; every change goes through GameState as before.

var _from: String
var _game: Dictionary
var _pick_slot := ""
var _open_player := ""
var _confirm_release := ""
var _card_tab := "overview"
var _undo: Dictionary = {}
var build_count := 0
var refresh_count := 0
var rebuild_count := 0

var page_scroll: ScrollContainer
var auto_button: Button
var pills: SquadKit.Pills
var map: SquadKit.LaneMap
var bench_head: Label
var bench: SquadKit.CardGrid
var find_button: Button
var done_button: Button
var picker_rows: SquadKit.CardRows        # the open lane picker's rows (null when none)
var card_head: PlayerCard                 # the open player sheet's head (null when none)
var card_tabs: DraftKit.RoleBar
var card_box: VBoxContainer
var card_stats: SquadKit.Stats           # the Stats tab's rows (null when another tab shows)
var occluded: Array = []                 # page parts hidden because an open sheet covers them completely (perf; see _occlude)


func _init(from: String = "hub", game: Dictionary = {}) -> void:
	super._init()
	_from = from
	_game = game


func tab_id() -> String:
	return "" if _from == "prematch" else "squad"


func is_tab_root() -> bool:
	return _from != "prematch"


func go_back() -> void:
	if _from == "prematch" and not _game.is_empty():
		App.go(ScreenPreMatch.new(_game))
	else:
		App.go_tab("home")


func _ready() -> void:
	setup("", Callable(), false)
	_build()
	_refresh()


func _exit_tree() -> void:
	_drop_toasts()


## OCCLUSION (I-19 perf). The renderer draws what a sheet covers. Once a sheet has finished sliding in, the page parts that lie
## completely under its panel (the bench, often the map) are hidden; every frame the panel is checked again, and anything it no
## longer covers (the sheet dragged down, closing) shows at once, so the player never sees a gap. About 10 to 20 draw calls.
func _occlude_soon() -> void:
	await get_tree().create_timer(BottomSheet.T_OPEN + 0.05 if UI.animate else 0.0).timeout
	if is_inside_tree():
		_occlude()


func _occlude() -> void:
	if not BottomSheet.is_open() or BottomSheet.current().is_closing:
		return
	var top := BottomSheet.current().panel_rect().position.y
	for ctl in [pills, map, bench_head, bench, find_button]:
		var c := ctl as Control
		if c.visible and c.get_global_rect().position.y >= top + 1.0:
			c.visible = false
			occluded.append(c)


func _process(_delta: float) -> void:
	if occluded.is_empty():
		return
	var open := BottomSheet.is_open() and not BottomSheet.current().is_closing
	var top := BottomSheet.current().panel_rect().position.y if open else 1.0e9
	for i in range(occluded.size() - 1, -1, -1):
		var c := occluded[i] as Control
		if not is_instance_valid(c):
			occluded.remove_at(i)
		elif not open or c.get_global_rect().position.y < top + 1.0:
			c.visible = true
			occluded.remove_at(i)


func _unocclude() -> void:
	for c in occluded:
		if is_instance_valid(c):
			(c as Control).visible = true
	occluded.clear()


# ---- reading ----------------------------------------------------------------------------------------------------------------------

static func _best(w: World, p: Dictionary) -> float:
	var best := 0.0
	for s in GameState.SLOTS:
		best = maxf(best, w.slot_score(p, s))
	return best


static func best_slot(w: World, p: Dictionary) -> String:
	var best := -1.0
	var out := "mid"
	for s in GameState.SLOTS:
		var v := w.slot_score(p, s)
		if v > best:
			best = v
			out = s
	return out


func starters() -> Dictionary:
	return (App.gs.d["lineup"] as Dictionary).duplicate()


func bench_ids() -> Array:
	var w := App.world
	var gs := App.gs
	var lu: Array = (gs.d["lineup"] as Dictionary).values()
	var ps := w.club_players(gs.club()).filter(func(p: Dictionary) -> bool: return not lu.has(p["id"]))
	ps.sort_custom(func(a, b): return _best(w, a) > _best(w, b))
	return ps.map(func(p: Dictionary) -> String: return String(p["id"]))


## The team rating if `pid` played `slot` (gs.assign on a copy of the lineup: a starter elsewhere swaps), and now.
func rating_with(slot: String, pid: String) -> float:
	var gs := App.gs
	var keep: Dictionary = (gs.d["lineup"] as Dictionary).duplicate()
	gs.assign(slot, pid)
	var r := App.world.team_rating(gs.lineup())
	gs.d["lineup"] = keep
	return r


func team_rating() -> float:
	return App.world.team_rating(App.gs.lineup())


# ---- building (once) ----------------------------------------------------------------------------------------------------------

func _build() -> void:
	build_count += 1
	var gs := App.gs
	ArtWire.prepare(App.world.club_ids, [])
	body.add_theme_constant_override("separation", 12)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, UI.HEADER_H)
	header.add_theme_constant_override("separation", 8)
	if _from == "prematch":
		var back := UI.button("<", go_back, "normal", UI.BTN_H)
		back.custom_minimum_size = Vector2(UI.BTN_H, UI.BTN_H)
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(back)
	var title := UI.label(Strings.t("squad.title"), UI.S_BIG, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)
	auto_button = UI.button(Strings.t("squad.auto"), _auto, "flat")
	auto_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	auto_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	auto_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	for k in ["font_color", "font_hover_color"]:
		auto_button.add_theme_color_override(k, UI.TEAL_HI)
	UI.tag(auto_button, "squad.auto")
	header.add_child(auto_button)
	if help_slot != null and help_slot.get_parent() == self:
		remove_child(help_slot)
		help_slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
		help_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
		header.add_child(help_slot)
	body.add_child(header)
	page_scroll = ScrollContainer.new()
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(page_scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 16)
	page_scroll.add_child(page)
	pills = SquadKit.Pills.new([], _on_pill)
	UI.tag(pills, "squad.pills", false)
	page.add_child(pills)
	var sh := VBoxContainer.new()
	sh.add_theme_constant_override("separation", 2)
	sh.add_child(UI.label(Strings.t("squad.start_h"), UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	var hint := UI.label(Strings.t("squad.start_hint"), UI.S_CAPTION, UI.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sh.add_child(hint)
	page.add_child(sh)
	map = SquadKit.LaneMap.new()
	UI.tag(map, "squad.map", false)
	page.add_child(map)
	for s in GameState.SLOTS:
		var t := PlayerCard.new("", PlayerCard.TOKEN, {"tappable": true, "tut_id": "squad.token." + s})
		t.pressed.connect(_toggle_slot.bind(s))
		map.set_token(s, t)
	bench_head = UI.label("", UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold")
	page.add_child(bench_head)
	bench = SquadKit.CardGrid.new(2)
	page.add_child(bench)
	find_button = UI.button(Strings.t("squad.find"), func(): App.go(ScreenFreeAgents.new("roster")), "normal")
	find_button.custom_minimum_size = Vector2(0, UI.BTN_H)
	UI.tag(find_button, "squad.find")
	page.add_child(find_button)
	if _from == "prematch":
		done_button = UI.button(Strings.t("squad.done"), go_back, "primary")
		UI.tag(done_button, "squad.done")
		body.add_child(done_button)


## The full rebuild (kept for completeness; no tap calls it).
func _rebuild() -> void:
	rebuild_count += 1
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	_build()
	_refresh()


# ---- refreshing (every change) -------------------------------------------------------------------------------------------------

func _refresh() -> void:
	refresh_count += 1
	var gs := App.gs
	var w := App.world
	var lu := gs.lineup()
	pills.set_items([[Strings.t("squad.pill.rating"), "%.1f" % w.team_rating(lu), false],
			[Strings.t("squad.pill.chem"), UI.pct(gs.chem_bonus()), true],
			[Strings.t("squad.pill.squad"), "%d/%d" % [gs.roster_slots_used(), int(Economy.data()["max_roster"])], false],
			[Strings.t("squad.pill.wages"), PlayerView.money(gs.wage_bill()), false]])
	for s in GameState.SLOTS:
		var t := map.tokens[s] as PlayerCard
		var pid: String = gs.d["lineup"][s]
		var d := PlayerCard.data_for(w, gs, pid, s)
		if t.pid != pid:
			t.pid = pid
			t.queue_redraw()
		t.set_opt("name", d["name"])
		t.set_opt("role", s)
		t.set_opt("rating", d["rating"])
		t.set_opt("status", d["status"])
		t.set_opt("off", w.player_fit(w.players[pid], s) < 1.0)
		t.set_opt("selected", _pick_slot == s)
	map.queue_redraw()
	# the bench: one card per player, reused in place (cards are freed only when the bench shrinks)
	var ids := bench_ids()
	bench_head.text = "%s (%d)" % [Strings.t("squad.bench_h"), ids.size()]
	var cards := bench.get_children()
	var expiring := ""
	for i in ids.size():
		var pid2 := String(ids[i])
		var c: PlayerCard
		if i < cards.size():
			c = cards[i] as PlayerCard
		else:
			c = PlayerCard.new("", PlayerCard.TALL, {"tappable": true})
			c.custom_minimum_size = Vector2(0, PlayerCard.SIZES["tall"].y)
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.pressed.connect(_on_bench.bind(c))
			bench.add_child(c)
		var d2 := PlayerCard.data_for(w, gs, pid2)
		if c.pid != pid2:
			c.pid = pid2
			c.queue_redraw()
		for k in ["name", "role", "age", "rating", "chips"]:
			c.set_opt(k, d2[k])
		var tid := "squad.bench.0" if i == 0 else ""
		if expiring == "" and gs.contract_of(pid2).size() > 0 and gs.seasons_left(pid2) <= 1:
			expiring = pid2
			tid = "squad.bench.expiring" if i != 0 else tid
		c.tut_id = tid
		var old_tag := String(c.get_meta(UI.TAG_META, ""))
		if tid != "":
			UI.tag(c, tid, false)
		elif old_tag != "":
			UI._untag(c, old_tag)
			c.remove_meta(UI.TAG_META)
	for i in range(ids.size(), cards.size()):
		bench.remove_child(cards[i])
		(cards[i] as Node).queue_free()
	bench.queue_redraw()
	auto_button.disabled = false


func _on_bench(c: PlayerCard) -> void:
	_open_player = ""
	_toggle_player(c.pid)


func _on_pill(i: int) -> void:
	if i == 1:
		App.go(ScreenChemistry.new("roster"))


# ---- the lane picker ----------------------------------------------------------------------------------------------------------

## Open the lane picker for `s` (or close it when it is open for `s`).
func _toggle_slot(s: String) -> void:
	if _pick_slot == s and BottomSheet.is_open() and BottomSheet.current().sheet_id == "lane_picker":
		_close_sheet()
		return
	_pick_slot = s
	_refresh()
	var sh := BottomSheet.open(Strings.f("roster.choose_for", {"role": Strings.t("role." + s)}), _picker_body.bind(s), Callable(), "L" if UI.large else "M", "lane_picker")
	sh.closed.connect(_on_picker_closed)
	sh.closed.connect(_unocclude)
	_occlude_soon()


func _on_picker_closed() -> void:
	picker_rows = null
	if _pick_slot != "":
		_pick_slot = ""
		if is_inside_tree():
			_refresh()


## The rows of the picker: [{pid, rating here, delta in team rating, starter here}] best first (as the old picker sorted).
func picker_data(slot: String) -> Array:
	var w := App.world
	var gs := App.gs
	var now := team_rating()
	var ps := w.club_players(gs.club())
	ps.sort_custom(func(a, b): return w.slot_score(a, slot) > w.slot_score(b, slot))
	var out: Array = []
	for p in ps:
		var pid := String(p["id"])
		out.append({"pid": pid, "here": w.slot_score(p, slot), "delta": rating_with(slot, pid) - now, "current": gs.d["lineup"][slot] == pid})
	return out


func _picker_body(c: Control, slot: String) -> void:
	var w := App.world
	var gs := App.gs
	picker_rows = SquadKit.CardRows.new()
	UI.tag(picker_rows, "squad.picker.head", false)
	for r in picker_data(slot):
		var pid := String(r["pid"])
		var d := PlayerCard.data_for(w, gs, pid, slot)
		var chips: Array = []
		if bool(r["current"]):
			chips.append({"text": Strings.t("squad.now_playing"), "variant": "accent", "icon": "chevron_r"})
		else:
			var dl := float(r["delta"])
			var dtext := "0.0" if absf(dl) < 0.05 else "%+.1f" % dl    # never "-0.0"
			chips.append({"text": Strings.f("squad.delta", {"delta": dtext}), "variant": "good" if dl > 0.05 else ("bad" if dl < -0.05 else "neutral"),
					"icon": "arrow_up" if dl > 0.05 else ("arrow_down" if dl < -0.05 else "arrow_flat")})
		if w.player_fit(w.players[pid], slot) < 1.0:    # 0.12 Q4-1: the real fit (second role 93%, off role 80%)
			var fk := "squad.fit_chip_second" if RoleFit.kind(w, w.players[pid], slot) == "second" else "squad.fit_chip"
			chips.append({"text": Strings.f(fk, {"pct": RoleFit.pct(w, w.players[pid], slot)}), "variant": "warn", "icon": "none"})    # no icon: it fits beside the team delta
		for ch in d["chips"]:
			chips.append(ch)
		var row := PlayerCard.new(pid, PlayerCard.ROW, {"name": d["name"], "role": String(w.players[pid]["role_primary"]), "age": d["age"],
				"rating": int(round(float(r["here"]))), "chips": chips, "starter": false, "tappable": true,
				"tut_id": "squad.picker.card" if bool(r["current"]) else ""})
		row.custom_minimum_size = Vector2(0, PlayerCard.SIZES["row"].y)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(_on_pick_row.bind(slot, pid, bool(r["current"])))
		picker_rows.add_child(row)
	c.add_child(picker_rows)


func _on_pick_row(slot: String, pid: String, current: bool) -> void:
	if current:
		_toggle_player(pid)    # the current starter: nothing to change, so his player sheet (UI-PASS-2 6.2 (d))
		return
	_assign(slot, pid)


## Put `pid` in `slot` (a starter elsewhere swaps), with Undo.
func _assign(slot: String, pid: String) -> void:
	var gs := App.gs
	_remember()
	if not gs.assign(slot, pid):
		return
	_pick_slot = ""
	App.autosave()
	_close_sheet()
	_refresh()
	_toast_undo(Strings.f("squad.toast.moved", {"name": App.world.players[pid]["name"], "role": Strings.t("role." + slot)}))


## The best rested lineup (gs.reset_lineup), with Undo.
func _auto() -> void:
	_remember()
	App.gs.reset_lineup()
	_pick_slot = ""
	App.autosave()
	_close_sheet()
	_refresh()
	_toast_undo(Strings.t("squad.toast.auto"))


func _remember() -> void:
	_undo = (App.gs.d["lineup"] as Dictionary).duplicate()


func _undo_last() -> void:
	if _undo.is_empty() or not is_inside_tree():
		return
	App.gs.d["lineup"] = _undo
	_undo = {}
	App.autosave()
	_refresh()


func _toast_undo(text: String) -> void:
	App.toast(text, UI.TEXT, Strings.t("common.undo"), _undo_last)
	var col: Node = App.main.get("_toasts") if App.main != null else null
	if col != null and col.get_child_count() > 0:
		col.get_child(col.get_child_count() - 1).set_meta("squad_undo", true)


func _drop_toasts() -> void:
	var col: Node = App.main.get("_toasts") if App.main != null else null
	if col == null:
		return
	for c in col.get_children():
		if c.has_meta("squad_undo"):
			col.remove_child(c)
			c.queue_free()


func _close_sheet() -> void:
	if BottomSheet.is_open():
		BottomSheet.current().close()


# ---- the player sheet ---------------------------------------------------------------------------------------------------------

## Open the player sheet of `pid` (or close it when it is open for `pid`).
func _toggle_player(pid: String) -> void:
	if _open_player == pid and BottomSheet.is_open() and BottomSheet.current().sheet_id == "player_card":
		_close_sheet()
		return
	_open_player = pid
	_card_tab = "overview"
	_confirm_release = ""
	var sh := BottomSheet.open(String(App.world.players[pid]["name"]), _card_body.bind(pid), _card_footer.bind(pid), "L", "player_card")
	sh.closed.connect(_on_card_closed.bind(pid))
	sh.closed.connect(_unocclude)
	_occlude_soon()


func _on_card_closed(pid: String) -> void:
	if _open_player == pid:
		_open_player = ""
	card_head = null


func _card_body(c: Control, pid: String) -> void:
	var w := App.world
	var gs := App.gs
	var d := PlayerCard.data_for(w, gs, pid)
	var lu: Dictionary = gs.d["lineup"]
	card_head = PlayerCard.new(pid, PlayerCard.ROW, {"name": d["name"], "role": d["role"], "age": d["age"], "rating": d["rating"], "chips": d["chips"],
			"starter": (lu as Dictionary).values().has(pid)})
	card_head.custom_minimum_size = Vector2(0, PlayerCard.SIZES["row"].y)
	card_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hp := SquadKit.CardRows.new()    # the head is drawn by its container (batched); the container is the hole's edge
	hp.add_child(card_head)
	UI.tag(hp, "roster.card.head", false)
	c.add_child(hp)
	card_tabs = DraftKit.RoleBar.new(_set_card_tab.bind(pid), "squad.card.tabs", [
			{"id": "overview", "label": Strings.t("squad.card.overview"), "icon": "star"},
			{"id": "stats", "label": Strings.t("squad.card.stats"), "icon": "tab_plan"},
			{"id": "career", "label": Strings.t("squad.card.career"), "icon": "trophy"}], _card_tab)
	c.add_child(card_tabs)
	card_box = VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 10)
	c.add_child(card_box)
	_fill_card(pid)


func _set_card_tab(id: Variant, pid: String = "") -> void:
	_card_tab = String(id)
	if card_tabs != null and is_instance_valid(card_tabs):
		card_tabs.set_selected(_card_tab)
	_fill_card(pid if pid != "" else _open_player)


func _fill_card(pid: String) -> void:
	if card_box == null or not is_instance_valid(card_box) or pid == "":
		return
	for ch in card_box.get_children():
		card_box.remove_child(ch)
		ch.queue_free()
	var w := App.world
	var gs := App.gs
	var p: Dictionary = w.players[pid]
	var own: bool = gs.d["roster"].has(pid)
	match _card_tab:
		"stats":
			var tip := UI.label(Strings.t("stat.help.tip"), UI.S_CAPTION, UI.DIM)
			card_box.add_child(tip)
			var rows: Array = []
			for st in World.STATS:
				rows.append([st, Strings.t("stat." + st), float(p["stats"][st]), int(p["potential"][st]), gs.season_gain(pid, st) if own else 0.0])
			var help := UI.label("", UI.S_SMALL, UI.TEAL_HI)
			help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			help.visible = false
			card_stats = SquadKit.Stats.new(rows, func(st: String) -> void:
				help.text = Strings.t(PlayerView.STAT_HELP[st]) if st != "" else ""
				help.visible = st != "")
			card_box.add_child(card_stats)
			card_box.add_child(help)
			card_box.add_child(UI.label(Strings.t("stat.help.pot"), UI.S_CAPTION, UI.DIM))
			card_box.add_child(role_fit_label(p))
		"career":
			if own:
				PlayerView.career_section(card_box, pid, true)
			PlayerView.best_heroes_line(card_box, p)
		_:
			var fat := w.fatigue_of(pid)
			var frm := w.form_of(pid)
			var mor := w.morale_of(pid)
			card_box.add_child(SquadKit.Status.new([
					[Strings.t("squad.card.fatigue"), "%.0f" % fat, fat / 100.0, false, Strings.t("fatigue.tired") if fat >= 50.0 else "", UI.fatigue_color(fat)],
					[Strings.t("report.pay.form"), "%+.1f" % frm, frm / 10.0, true, Strings.t("mood.hot") if frm >= 3.0 else (Strings.t("mood.cold") if frm <= -3.0 else ""), UI.GOOD if frm >= 0.0 else UI.BAD],
					[Strings.t("report.pay.morale"), "%.0f" % mor, mor / 100.0, false, Strings.t("mood.word." + Bonds.mood_word(mor)), UI.ACCENT]]))
			var help := UI.label(Strings.t("roster.mood_help"), UI.S_CAPTION, UI.DIM)
			help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card_box.add_child(help)
			var ct := PlayerView.contract_text(pid)
			if ct != "":
				var cp := PanelContainer.new()
				cp.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, 16, 16))
				var cl := UI.label(ct, UI.S_SMALL, UI.TEAL_HI)
				cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				cp.add_child(cl)
				UI.tag(cp, "roster.card.contract", false)
				card_box.add_child(cp)
			# the bond line, personality and country, best heroes: one label (each label is a draw call of its own)
			var lines: Array = []
			var bl := _bond_text(p)
			if bl != "":
				lines.append(bl)
			lines.append(Strings.f("roster.detail", {"personality": Strings.t("personality." + p["personality"]), "country": p["country"]}))
			lines.append(_heroes_text(p))
			var det := UI.label("\n".join(PackedStringArray(lines)), UI.S_SMALL, UI.TEXT)
			det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card_box.add_child(det)


## Role fit (0.12, ESMO Q4-1): the rating in each lane with its fit, and the two stats that raise the likeliest other lane
## most. One label (RoleFit holds the numbers: World.slot_score, World.player_fit, SLOT_W).
static func role_fit_label(p: Dictionary) -> Label:
	var w := App.world
	var lines: Array = [Strings.t("squad.fit.h")]
	for s in World.SLOTS:
		var k := RoleFit.kind(w, p, s)
		var fit := Strings.t("squad.fit.main") if k == "main" else Strings.f("squad.fit." + k, {"pct": RoleFit.pct(w, p, s)})
		lines.append(Strings.f("squad.fit.line", {"lane": Strings.t("role." + s), "rating": "%.0f" % RoleFit.rating(w, p, s), "fit": fit}))
	var mt := RoleFit.move_target(w, p)
	if mt != "":
		var tr := RoleFit.train_for(p, mt)
		lines.append(Strings.f("squad.fit.train", {"lane": Strings.t("role." + mt), "a": Strings.t("stat." + String(tr[0])), "b": Strings.t("stat." + String(tr[1]))}))
	var l := UI.label("\n".join(PackedStringArray(lines)), UI.S_SMALL, UI.TEXT2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.tag(l, "squad.card.fit", false)
	return l


func _heroes_text(p: Dictionary) -> String:
	var w := App.world
	var fams: Array = []
	for hid in w.hero_ids:
		fams.append([w.familiarity(p, hid), hid])
	fams.sort_custom(func(a, b): return a[0] > b[0])
	var names: Array = []
	for i in 3:
		names.append("%s %.0f" % [w.heroes[fams[i][1]]["name"], fams[i][0]])
	return Strings.f("roster.best_heroes", {"list": ", ".join(names)})


func _bond_text(p: Dictionary) -> String:
	var gs := App.gs
	var total := 0.0
	var n := 0
	var best := -1.0
	var best_name := ""
	for sid in (gs.d["lineup"] as Dictionary).values():
		if sid == p["id"]:
			continue
		var b := gs.bond(p["id"], sid)
		total += b
		n += 1
		if b > best:
			best = b
			best_name = App.world.players[sid]["name"]
	if n == 0:
		return ""
	return Strings.f("roster.bond_line", {"avg": "%.0f" % (total / float(n)), "name": best_name, "best": "%.0f" % best})


func _bond_line(parent: VBoxContainer, p: Dictionary) -> void:
	var gs := App.gs
	var total := 0.0
	var n := 0
	var best := -1.0
	var best_name := ""
	for sid in (gs.d["lineup"] as Dictionary).values():
		if sid == p["id"]:
			continue
		var b := gs.bond(p["id"], sid)
		total += b
		n += 1
		if b > best:
			best = b
			best_name = App.world.players[sid]["name"]
	if n > 0:
		var l := UI.label(Strings.f("roster.bond_line", {"avg": "%.0f" % (total / float(n)), "name": best_name, "best": "%.0f" % best}), UI.S_SMALL, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(l)


func _card_footer(f: Control, pid: String) -> void:
	var gs := App.gs
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	f.add_child(row)
	var put := _foot_button(row, Strings.t("squad.card.put_in"), _put_in.bind(pid), "primary", "roster.card.put_in")
	put.visible = not (gs.d["lineup"] as Dictionary).values().has(pid)
	if gs.d["roster"].has(pid) and int(gs.contract_of(pid).get("left", 9)) <= 1:
		_foot_button(row, Strings.t("squad.card.renew"), func(): _close_sheet(); App.go(ScreenNegotiation.new(pid, true, "roster")), "normal", "roster.card.renew")
	if gs.d["roster"].has(pid):
		_foot_button(row, Strings.t("squad.card.release"), _ask_release.bind(pid), "normal", "roster.card.release")


## Put in lineup: the lane picker of the player's best role.
func _put_in(pid: String) -> void:
	_toggle_slot(best_slot(App.world, App.world.players[pid]))


func _foot_button(row: HBoxContainer, text: String, cb: Callable, kind: String, tut_id: String) -> Button:
	var b := UI.button(text, cb, kind, BottomSheet.FOOTER_H)
	b.add_theme_font_size_override("font_size", UI.S_BODY)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	UI.tag(b, tut_id)
	return b


## Release: a second sheet asks (with the cost, or why it cannot be done), exactly the old confirm text.
func _ask_release(pid: String) -> void:
	_confirm_release = pid
	var sh := BottomSheet.open(Strings.t("release.btn"), _release_body.bind(pid), _release_footer.bind(pid), "M", "release_confirm")
	sh.closed.connect(_unocclude)
	_occlude_soon()


func _release_body(c: Control, pid: String) -> void:
	var gs := App.gs
	var why := gs.can_release(pid)
	var text := Strings.t("release.block." + why) if why != "" else Strings.f("release.confirm", {"name": App.world.players[pid]["name"], "cost": PlayerView.money(gs.release_cost(pid))})
	var l := UI.label(text, UI.S_BODY, UI.WARN if why != "" else UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(l)


func _release_footer(f: Control, pid: String) -> void:
	if App.gs.can_release(pid) == "":
		BottomSheet.footer_button(f, Strings.t("release.yes"), _release.bind(pid), "danger", "release.yes")
	BottomSheet.footer_button(f, Strings.t("common.cancel"), func(): _confirm_release = ""; _close_sheet(), "normal")


func _release(pid: String) -> void:
	App.gs.release(pid)
	_confirm_release = ""
	_open_player = ""
	App.autosave()
	_close_sheet()
	_refresh()
