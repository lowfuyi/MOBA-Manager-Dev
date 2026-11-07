class_name ScreenDraft
extends Screen
## Interactive draft for the managed club's game (GDD 8.7). The AI plays the other side and, on a
## timeout, also the managed side (its recommendation). The finished draft goes to the simulator
## through MatchRunner.finish().

var game: Dictionary
var draft: Draft
var my_side := "B"
var _limit := 10.0
var _time_left := 10.0
var _ai_wait := 0.0
var _sel_hero := ""
var _timer_label: Label


func _init(g: Dictionary = {}, finished: Draft = null) -> void:
	super._init()
	game = g
	draft = finished     # set when coming back from the Game Plan screen


func go_back() -> void:
	# Leaving abandons this draft; nothing is recorded, the game is still waiting on match day.
	App.go(ScreenPreMatch.new(game))


func _ready() -> void:
	var gs := App.gs
	my_side = "B" if game["blue"] == gs.club() else "R"
	if draft == null:
		draft = MatchRunner.prepare(App.world, gs.lineup_for(game["blue"]), gs.lineup_for(game["red"]),
				gs.meta_for(int(game["round"])), int(gs.d["save_seed"]), game["id"], bool(game["full"]))
	_limit = 15.0 if game["full"] else 10.0
	setup("", Callable())
	_begin_step()


func _begin_step() -> void:
	_time_left = _limit
	_ai_wait = 0.45 if App.gs.is_quick() else 0.9
	_sel_hero = ""
	_rebuild()


func _process(delta: float) -> void:
	if draft == null or draft.is_done():
		return
	var cur := draft.current()
	if cur["team"] == my_side:
		_time_left -= delta
		if _timer_label != null:
			_timer_label.text = Strings.f("draft.time", {"s": maxi(0, ceili(_time_left))})
			_timer_label.add_theme_color_override("font_color", UI.BAD if _time_left <= 3.0 else UI.TEXT)
		if _time_left <= 0.0:
			_apply(draft.ai_choice())
	else:
		_ai_wait -= delta
		if _ai_wait <= 0.0:
			_apply(draft.ai_choice())


func _apply(choice: Dictionary) -> void:
	if draft.apply(choice):
		_begin_step()


# ---------------------------------------------------------------- view
func _rebuild() -> void:
	UI.clear(body)
	_timer_label = null
	if draft.is_done():
		_show_done()
		return
	var cur := draft.current()
	var mine: bool = cur["team"] == my_side
	var head := UI.card(body, UI.PANEL2, 14)
	var side_name := Strings.t("hub.side.blue" if cur["team"] == "B" else "hub.side.red")
	var what := Strings.t("draft.kind." + cur["kind"])
	var row := UI.hbox()
	var back := UI.button("<", go_back, "normal", 64)
	back.custom_minimum_size = Vector2(80, 64)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(back)
	if mine:
		row.add_child(UI.label(Strings.f("draft.your_turn", {"what": what}), UI.S_BIG, UI.GOOD))
		_timer_label = UI.label(Strings.f("draft.time", {"s": ceili(_time_left)}), UI.S_BIG, UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		_timer_label.custom_minimum_size = Vector2(140, 0)
		_timer_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(_timer_label)
	else:
		row.add_child(UI.label(Strings.f("draft.their_turn", {"side": side_name, "what": what}), UI.S_BODY, UI.WARN))
	head.add_child(row)
	head.add_child(UI.label(Strings.f("draft.step", {"n": int(cur["n"]) + 1, "total": draft.order.size()}), UI.S_SMALL - 2, UI.DIM))
	if mine and cur["kind"] == "pick" and _sel_hero != "":
		_slot_panel()
	else:
		_board()
		_needs_card()
		if mine:
			_actions(cur)
	body.add_child(UI.button(Strings.t("draft.auto_rest"), _auto_rest, "flat", 64))


## One compact grid: role | blue | red.
func _board() -> void:
	var c := UI.card(body, UI.PANEL, 12)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 4)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(g)
	g.add_child(_cell("", UI.DIM, 150))
	for t in ["B", "R"]:
		var title := Strings.t("hub.side.blue" if t == "B" else "hub.side.red") + (" *" if t == my_side else "")
		g.add_child(_cell(title, UI.BLUE if t == "B" else UI.RED, 0))
	g.add_child(_cell(Strings.t("draft.bans_short"), UI.DIM, 150))
	for t in ["B", "R"]:
		var names: Array = []
		for hid in draft.bans[t]:
			names.append(App.world.heroes[hid]["name"])
		g.add_child(_cell(", ".join(names) if not names.is_empty() else "-", UI.DIM, 0))
	for s in GameState.SLOTS:
		g.add_child(_cell(Strings.t("role." + s), UI.DIM, 150))
		for t in ["B", "R"]:
			if draft.picks[t].has(s):
				g.add_child(_cell(draft.picks[t][s]["name"], UI.TEXT, 0))
			else:
				g.add_child(_cell("-", UI.DIM, 0))


func _cell(text: String, color: Color, min_w: int) -> Label:
	var l := UI.label(text, UI.S_SMALL, color)
	if min_w > 0:
		l.custom_minimum_size = Vector2(min_w, 0)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l


func _needs_of(heroes: Array) -> Dictionary:
	var out := {"frontline": false, "initiate": false, "waveclear": false}
	for h in heroes:
		for tg in h["tags"]:
			if tg == "frontline":
				out["frontline"] = true
			elif tg == "engage" or tg == "pick":
				out["initiate"] = true
			elif tg == "waveclear":
				out["waveclear"] = true
	return out


func _needs_card() -> void:
	var heroes: Array = draft.picks[my_side].values()
	if heroes.is_empty():
		return
	var n := _needs_of(heroes)
	var c := UI.card(body, UI.PANEL, 14)
	var parts: Array = []
	for k in ["frontline", "initiate", "waveclear"]:
		parts.append(("[x] " if n[k] else "[ ] ") + Strings.t("draft.need." + k))
	c.add_child(UI.label(Strings.t("draft.need_h") + "  " + "   ".join(parts), UI.S_SMALL, UI.TEXT))


func _actions(cur: Dictionary) -> void:
	if cur["kind"] == "pick" and _sel_hero != "":
		_slot_panel()
		return
	var rec := draft.ai_choice()
	var recn: String = App.world.heroes[rec["hero"]]["name"]
	body.add_child(UI.button(Strings.f("draft.recommended", {"hero": recn}), func(): _apply(rec), "primary", 68))
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("draft.choose_ban" if cur["kind"] == "ban" else "draft.choose_pick"), UI.S_BODY, UI.ACCENT))
	var opp := "R" if my_side == "B" else "B"
	var scored: Array = []
	for hid in draft.avail:
		var h: Dictionary = App.world.heroes[hid]
		var v := 0.0
		var note := ""
		if cur["kind"] == "ban":
			for s in GameState.SLOTS:
				var f := App.world.familiarity(draft.lineups[opp][s], hid) * App.world.hero_fit(h, s)
				v = maxf(v, f)
			note = Strings.f("draft.their_fam", {"fam": "%.0f" % v})
		else:
			var best_slot := ""
			for s in draft.open_slots(my_side):
				var f := App.world.familiarity(draft.lineups[my_side][s], hid) * App.world.hero_fit(h, s)
				if f > v or best_slot == "":
					v = f
					best_slot = s
			note = Strings.f("draft.my_fam", {"fam": "%.0f" % v, "role": Strings.t("role." + best_slot)})
		scored.append([v, hid, note])
	scored.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e in scored:
		var h: Dictionary = App.world.heroes[e[1]]
		var m: float = float(draft.meta[e[1]])
		var txt := "%s\n%s  %s" % [h["name"], Strings.t("arch." + h["archetype"]), e[2]]
		var b := UI.button(txt, _on_hero.bind(e[1], cur["kind"]), "normal", 96)
		b.add_theme_font_size_override("font_size", UI.S_SMALL)
		if m > 1.015:
			b.add_theme_color_override("font_color", UI.GOOD)
		elif m < 0.985:
			b.add_theme_color_override("font_color", UI.DIM)
		grid.add_child(b)
	c.add_child(grid)
	c.add_child(UI.label(Strings.t("draft.meta_hint"), UI.S_SMALL - 2, UI.DIM))


func _on_hero(hid: String, kind: String) -> void:
	if kind == "ban":
		_apply({"hero": hid, "slot": ""})
	else:
		_sel_hero = hid
		_rebuild()


func _slot_panel() -> void:
	var w := App.world
	var h: Dictionary = w.heroes[_sel_hero]
	var c := UI.card(body, UI.PANEL2)
	c.add_child(UI.label(h["name"], UI.S_BIG, UI.TEXT))
	var tags: Array = []
	for tg in h["tags"]:
		tags.append(Strings.t("tag." + tg))
	c.add_child(UI.label("%s  |  %s  |  %s" % [Strings.t("arch." + h["archetype"]), ", ".join(tags), Strings.t("dmg." + h["damage_type"])], UI.S_SMALL, UI.DIM))
	c.add_child(UI.label(Strings.f("draft.power", {"e": h["power_early"], "m": h["power_mid"], "l": h["power_late"], "d": h["difficulty"]}), UI.S_SMALL, UI.TEXT))
	c.add_child(UI.label(Strings.f("draft.meta_line", {"meta": "%+.1f%%" % ((float(draft.meta[_sel_hero]) - 1.0) * 100.0)}), UI.S_SMALL, UI.DIM))
	var strong: Array = []
	for sid in h["strong_vs"]:
		strong.append(w.heroes[sid]["name"])
	c.add_child(UI.label(Strings.f("draft.strong_vs", {"list": ", ".join(strong)}), UI.S_SMALL, UI.DIM))
	c.add_child(UI.label(Strings.t("draft.assign_h"), UI.S_BODY, UI.ACCENT))
	for s in draft.open_slots(my_side):
		var p: Dictionary = draft.lineups[my_side][s]
		var fit := w.hero_fit(h, s)
		var fam := w.familiarity(p, _sel_hero)
		var txt := Strings.f("draft.slot_row", {"role": Strings.t("role." + s), "name": p["name"], "fam": "%.0f" % fam, "fit": "%.0f" % (fit * 100.0)})
		c.add_child(UI.button(txt, func(): _apply({"hero": _sel_hero, "slot": s}), "normal", 76))
	c.add_child(UI.button(Strings.t("common.back"), func(): _sel_hero = ""; _rebuild(), "flat", 70))


func _auto_rest() -> void:
	draft.finish_with_ai()
	_rebuild()


func _show_done() -> void:
	var c := UI.card(body, UI.PANEL2)
	c.add_child(UI.label(Strings.t("draft.done"), UI.S_BIG, UI.GOOD))
	for t in [my_side, "R" if my_side == "B" else "B"]:
		var heroes: Array = draft.picks[t].values()
		var ev := Comp.evaluate(heroes)
		var cc := UI.card(body)
		var who := Strings.t("draft.you") if t == my_side else Strings.t("draft.opponent")
		cc.add_child(UI.label(who, UI.S_BODY, UI.ACCENT))
		var names: Array = []
		for s in GameState.SLOTS:
			names.append("%s %s" % [Strings.t("role." + s), draft.picks[t][s]["name"]])
		cc.add_child(UI.label("\n".join(names), UI.S_SMALL, UI.TEXT))
		cc.add_child(UI.label(Strings.f("draft.comp_line", {"style": Strings.t("style." + ev["style"]), "mod": UI.pct(ev["mod"])}), UI.S_SMALL, UI.GOOD if ev["mod"] >= 0.0 else UI.WARN))
	var plan_state := Strings.t("gp.state.neutral") if GamePlan.is_neutral(App.gs.plan_set()["default"]) and App.gs.plan_set()["triggers"].is_empty() else Strings.t("gp.state.set")
	body.add_child(UI.button(Strings.f("draft.game_plan", {"state": plan_state}), func(): App.go(ScreenGamePlan.new(game, draft)), "normal", 84))
	body.add_child(UI.button(Strings.t("draft.start_match"), _start_match, "primary"))


func _start_match() -> void:
	ScreenDraft.launch(game, draft)


static func launch(g: Dictionary, d: Draft) -> void:
	var res := MatchRunner.finish(App.world, d, App.gs.plans_for(g))
	App.last_game = g
	App.last_result = res
	App.go(ScreenMatch.new(g, res))
