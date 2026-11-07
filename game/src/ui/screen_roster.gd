class_name ScreenRoster
extends Screen
## Lineup editor plus squad list with player detail.

var _from: String
var _game: Dictionary
var _pick_slot := ""
var _open_player := ""


func _init(from: String = "hub", game: Dictionary = {}) -> void:
	super._init()
	_from = from
	_game = game


func go_back() -> void:
	if _from == "prematch" and not _game.is_empty():
		App.go(ScreenPreMatch.new(_game))
	else:
		App.go(ScreenHub.new())


func _ready() -> void:
	setup(Strings.t("roster.title"), go_back)
	_rebuild()


func _rebuild() -> void:
	UI.clear(body)
	var gs := App.gs
	var w := App.world
	var lu := gs.lineup()
	var head := UI.card(body, UI.PANEL2)
	head.add_child(UI.label(Strings.f("roster.team_rating", {"rating": "%.1f" % w.team_rating(lu)}), UI.S_BIG, UI.TEXT))
	head.add_child(UI.label(Strings.t("roster.hint"), UI.S_SMALL, UI.DIM))
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("roster.lineup"), UI.S_BODY, UI.ACCENT))
	for s in GameState.SLOTS:
		var p: Dictionary = lu[s]
		var fit := w.player_fit(p, s)
		var tag := "" if fit >= 1.0 else ("  (" + Strings.t("roster.offrole") + ")")
		var txt := Strings.f("roster.slot_row", {"role": Strings.t("role." + s), "name": p["name"], "rating": "%.0f" % (w.base_rating(p, s) * fit)}) + tag
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
		var line := Strings.f("roster.player_row", {"name": p["name"], "role": Strings.t("role." + p["role_primary"]), "age": p["age"], "rating": "%.0f" % _best(w, p)})
		if starting:
			line += "  *"
		sq.add_child(UI.button(line, _toggle_player.bind(p["id"]), "flat" if _open_player != p["id"] else "normal", 70))
		if _open_player == p["id"]:
			_player_detail(sq, p)


func _best(w: World, p: Dictionary) -> float:
	var best := 0.0
	for s in GameState.SLOTS:
		best = maxf(best, w.base_rating(p, s) * w.player_fit(p, s))
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
	ps.sort_custom(func(a, b): return w.base_rating(a, slot) * w.player_fit(a, slot) > w.base_rating(b, slot) * w.player_fit(b, slot))
	for p in ps:
		var fit := w.player_fit(p, slot)
		var txt := Strings.f("roster.pick_row", {"name": p["name"], "role": Strings.t("role." + p["role_primary"]), "rating": "%.0f" % (w.base_rating(p, slot) * fit)})
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
	for st in World.STATS:
		var row := UI.hbox()
		var name_l := UI.label(Strings.t("stat." + st), UI.S_SMALL, UI.TEXT)
		name_l.custom_minimum_size = Vector2(230, 0)
		name_l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(name_l)
		var bar := UI.bar(float(p["stats"][st]), 100.0, UI.ACCENT, 20)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var val := UI.label("%d / %d" % [p["stats"][st], p["potential"][st]], UI.S_SMALL, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		val.custom_minimum_size = Vector2(120, 0)
		val.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(val)
		d.add_child(row)
	# best heroes
	var fams: Array = []
	for hid in w.hero_ids:
		fams.append([w.familiarity(p, hid), hid])
	fams.sort_custom(func(a, b): return a[0] > b[0])
	var names: Array = []
	for i in 3:
		names.append("%s %.0f" % [w.heroes[fams[i][1]]["name"], fams[i][0]])
	d.add_child(UI.label(Strings.f("roster.best_heroes", {"list": ", ".join(names)}), UI.S_SMALL, UI.GOOD))
