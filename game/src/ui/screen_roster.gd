class_name ScreenRoster
extends Screen
## Lineup editor plus squad list with player detail.

var _from: String
var _game: Dictionary
var _pick_slot := ""
var _open_player := ""
var _confirm_release := ""


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
	setup(Strings.t("roster.title"), go_back if _from == "prematch" else Callable())
	_rebuild()


func _rebuild() -> void:
	UI.clear(body)
	var gs := App.gs
	var w := App.world
	var lu := gs.lineup()
	var head := UI.card(body, UI.PANEL2)
	head.add_child(UI.label(Strings.f("roster.team_rating", {"rating": "%.1f" % w.team_rating(lu)}), UI.S_BIG, UI.TEXT))
	head.add_child(UI.label(Strings.t("roster.hint"), UI.S_SMALL, UI.DIM))
	head.add_child(UI.label(Strings.f("roster.squad_count", {"n": gs.roster_slots_used(), "max": Economy.data()["max_roster"], "cash": PlayerView.money(gs.cash()), "bill": PlayerView.money(gs.wage_bill())}), UI.S_SMALL, UI.TEXT))
	head.add_child(UI.label(Strings.f("hub.chem", {"bonus": UI.pct(gs.chem_bonus())}), UI.S_SMALL, UI.ACCENT))
	head.add_child(UI.button(Strings.t("hub.chemistry"), func(): App.go(ScreenChemistry.new("roster")), "normal", 76))
	head.add_child(UI.button(Strings.t("hub.free_agents"), func(): App.go(ScreenFreeAgents.new("roster")), "normal", 76))
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("roster.lineup"), UI.S_BODY, UI.ACCENT))
	for s in GameState.SLOTS:
		var p: Dictionary = lu[s]
		var fit := w.player_fit(p, s)
		var tag := "" if fit >= 1.0 else ("  (" + Strings.t("roster.offrole") + ")")
		var txt := Strings.f("roster.slot_row", {"role": Strings.t("role." + s), "name": p["name"], "rating": "%.0f" % w.slot_score(p, s)}) + tag + UI.fatigue_tag(w.fatigue_of(p["id"])) + UI.mood_tag(w.form_of(p["id"]), w.morale_of(p["id"]))
		var b := UI.button(txt, _toggle_slot.bind(s), "primary" if _pick_slot == s else "normal", 76)
		c.add_child(b)
		if _pick_slot == s:
			_picker(c, s)
	c.add_child(UI.button(Strings.t("roster.auto"), _auto, "normal", 76))
	var sq := UI.card(body)
	sq.add_child(UI.label(Strings.t("roster.squad"), UI.S_BODY, UI.ACCENT))
	var ps := w.club_players(gs.club())
	ps.sort_custom(func(a, b): return _best(w, a) > _best(w, b))
	for p in ps:
		var starting := false
		for s in GameState.SLOTS:
			if lu[s]["id"] == p["id"]:
				starting = true
		var line := Strings.f("roster.player_row", {"name": p["name"], "role": Strings.t("role." + p["role_primary"]), "age": w.age_of(p), "rating": "%.0f" % _best(w, p)}) + UI.fatigue_tag(w.fatigue_of(p["id"])) + UI.mood_tag(w.form_of(p["id"]), w.morale_of(p["id"]))
		if starting:
			line += "  *"
		sq.add_child(UI.button(line, _toggle_player.bind(p["id"]), "flat" if _open_player != p["id"] else "normal", 70))
		if _open_player == p["id"]:
			_player_detail(sq, p)


func _best(w: World, p: Dictionary) -> float:
	var best := 0.0
	for s in GameState.SLOTS:
		best = maxf(best, w.slot_score(p, s))
	return best


func _toggle_slot(s: String) -> void:
	_pick_slot = "" if _pick_slot == s else s
	_rebuild()


func _toggle_player(id: String) -> void:
	_open_player = "" if _open_player == id else id
	_rebuild()


func _picker(parent: VBoxContainer, slot: String) -> void:
	var w := App.world
	var gs := App.gs
	var sub := UI.card(parent, UI.PANEL2, 12)
	sub.add_child(UI.label(Strings.f("roster.choose_for", {"role": Strings.t("role." + slot)}), UI.S_SMALL, UI.DIM))
	var ps := w.club_players(gs.club())
	ps.sort_custom(func(a, b): return w.slot_score(a, slot) > w.slot_score(b, slot))
	for p in ps:
		var txt := Strings.f("roster.pick_row", {"name": p["name"], "role": Strings.t("role." + p["role_primary"]), "rating": "%.0f" % w.slot_score(p, slot)}) + UI.fatigue_tag(w.fatigue_of(p["id"]))
		sub.add_child(UI.button(txt, _assign.bind(slot, p["id"]), "normal", 66))


func _assign(slot: String, pid: String) -> void:
	App.gs.assign(slot, pid)
	_pick_slot = ""
	App.autosave()
	_rebuild()


func _auto() -> void:
	App.gs.reset_lineup()
	_pick_slot = ""
	App.autosave()
	_rebuild()


func _player_detail(parent: VBoxContainer, p: Dictionary) -> void:
	var w := App.world
	var d := UI.card(parent, UI.PANEL2, 14)
	d.add_child(UI.label(Strings.f("roster.detail", {"personality": Strings.t("personality." + p["personality"]), "country": p["country"]}), UI.S_SMALL, UI.DIM))
	var fat := w.fatigue_of(p["id"])
	d.add_child(UI.label(Strings.f("roster.fatigue_line", {"fat": "%.0f" % fat}), UI.S_SMALL, UI.fatigue_color(fat)))
	var mor := w.morale_of(p["id"])
	d.add_child(UI.label(Strings.f("roster.mood_line", {"form": "%+.1f" % w.form_of(p["id"]), "morale": "%.0f" % mor, "word": Strings.t("mood.word." + Bonds.mood_word(mor))}), UI.S_SMALL, UI.TEXT))
	d.add_child(UI.label(Strings.t("roster.mood_help"), UI.S_SMALL - 2, UI.DIM))
	_bond_line(d, p)
	PlayerView.stat_block(d, p, App.gs.d["roster"].has(p["id"]))
	PlayerView.best_heroes_line(d, p)
	_contract_controls(d, p)


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
		parent.add_child(UI.label(Strings.f("roster.bond_line", {"avg": "%.0f" % (total / float(n)), "name": best_name, "best": "%.0f" % best}), UI.S_SMALL, UI.TEXT))


func _contract_controls(parent: VBoxContainer, p: Dictionary) -> void:
	var gs := App.gs
	var pid: String = p["id"]
	parent.add_child(UI.label(PlayerView.contract_text(pid), UI.S_SMALL, UI.ACCENT))
	if int(gs.contract_of(pid).get("left", 9)) <= 1:
		parent.add_child(UI.button(Strings.t("contract.renew"), func(): App.go(ScreenNegotiation.new(pid, true, "roster")), "primary", 70))
	if _confirm_release == pid:
		var why := gs.can_release(pid)
		if why != "":
			parent.add_child(UI.label(Strings.t("release.block." + why), UI.S_SMALL, UI.WARN))
		else:
			parent.add_child(UI.label(Strings.f("release.confirm", {"name": p["name"], "cost": PlayerView.money(gs.release_cost(pid))}), UI.S_SMALL, UI.WARN))
			parent.add_child(UI.button(Strings.t("release.yes"), _release.bind(pid), "danger", 70))
		parent.add_child(UI.button(Strings.t("common.cancel"), func(): _confirm_release = ""; _rebuild(), "normal", 70))
	else:
		parent.add_child(UI.button(Strings.t("release.btn"), func(): _confirm_release = pid; _rebuild(), "normal", 70))


func _release(pid: String) -> void:
	App.gs.release(pid)
	_confirm_release = ""
	_open_player = ""
	App.autosave()
	_rebuild()
