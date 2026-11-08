class_name ScreenTraining
extends Screen
## Training focus for every player of the managed club (GDD 7.3): one of the eight stats, a hero to practise, or rest.

var _open := ""
var _hero_list := false


func tab_id() -> String:
	return "plan"


func go_back() -> void:
	App.autosave()
	App.go_tab("plan")


func _ready() -> void:
	setup(Strings.t("train.title"), go_back)
	_rebuild()


func _focus_text(p: Dictionary) -> String:
	var f := App.gs.focus_of(p)
	match f["k"]:
		"stat":
			return Strings.f("train.f.stat", {"stat": Strings.t("stat." + String(f["v"]))})
		"hero":
			return Strings.f("train.f.hero", {"hero": App.world.heroes[f["v"]]["name"]})
		"scrim":
			return Strings.t("train.f.scrim")
	return Strings.t("train.f.rest")


func _rebuild() -> void:
	UI.clear(body)
	var gs := App.gs
	var w := App.world
	var head := UI.card(body, UI.PANEL2)
	head.add_child(UI.label(Strings.t("train.intro"), UI.S_SMALL, UI.DIM))
	_preview(head)
	head.add_child(UI.button(Strings.t("train.coach_all"), _coach_all, "normal", 76))
	var last := UI.card(body)
	last.add_child(UI.label(Strings.t("train.last_h"), UI.S_BODY, UI.ACCENT))
	var log: Array = gs.d["train_last"]
	if log.is_empty():
		last.add_child(UI.label(Strings.t("train.last_none"), UI.S_SMALL, UI.DIM))
	for e in log:
		var p: Dictionary = w.players[e[0]]
		var parts := String(e[1]).split(":")
		var what: String = Strings.t("stat." + parts[1]) if parts[0] == "stat" else String(w.heroes[parts[1]]["name"])
		last.add_child(UI.label(Strings.f("train.last_row", {"name": p["name"], "amount": "%.2f" % float(e[2]), "what": what}), UI.S_SMALL, UI.TEXT))
	var sq := UI.card(body)
	sq.add_child(UI.label(Strings.t("train.squad_h"), UI.S_BODY, UI.ACCENT))
	var ps := w.club_players(gs.club())
	var starters: Array = (gs.d["lineup"] as Dictionary).values()
	ps.sort_custom(func(a, b):
		var sa: int = 0 if starters.has(a["id"]) else 1
		var sb: int = 0 if starters.has(b["id"]) else 1
		return sa < sb or (sa == sb and String(a["id"]) < String(b["id"])))
	for p in ps:
		var line := Strings.f("train.row", {"name": p["name"], "role": Strings.t("role." + p["role_primary"]), "focus": _focus_text(p)}) + UI.fatigue_tag(w.fatigue_of(p["id"]))
		sq.add_child(UI.button(line, _toggle.bind(p["id"]), "primary" if _open == p["id"] else "normal", 76))
		if _open == p["id"]:
			_picker(sq, p)


func _picker(parent: VBoxContainer, p: Dictionary) -> void:
	var w := App.world
	var box := UI.card(parent, UI.PANEL2, 12)
	box.add_child(UI.label(Strings.f("train.pick_h", {"name": p["name"]}), UI.S_SMALL, UI.DIM))
	var fat := w.fatigue_of(p["id"])
	var cur := App.gs.focus_of(p)
	for st in World.STATS:
		var now := float(p["stats"][st])
		var pot := float(p["potential"][st])
		var wk := Progression.stat_gain_week(now, pot, w.age_of(p), fat, p["personality"])
		var txt := Strings.f("train.stat_btn", {"stat": Strings.t("stat." + st), "now": "%.0f" % now, "pot": "%.0f" % pot, "week": "%.2f" % wk})
		box.add_child(UI.button(txt, _choose.bind(p["id"], "stat", st), "primary" if cur["k"] == "stat" and cur["v"] == st else "normal", 66))
	box.add_child(UI.button(Strings.t("train.hero_open"), _toggle_heroes, "primary" if cur["k"] == "hero" else "normal", 66))
	if _hero_list:
		var elig: Array = []
		for hid in w.hero_ids:
			var h: Dictionary = w.heroes[hid]
			var roles := [p["role_primary"], p.get("role_secondary", "")]
			if roles.has(h["role_primary"]) or roles.has(h.get("role_secondary", "-")):
				elig.append([w.familiarity(p, hid), hid])
		elig.sort_custom(func(a, b): return a[0] > b[0])
		for e in elig:
			var txt2 := Strings.f("train.hero_btn", {"hero": w.heroes[e[1]]["name"], "fam": "%.0f" % float(e[0])})
			box.add_child(UI.button(txt2, _choose.bind(p["id"], "hero", e[1]), "primary" if cur["k"] == "hero" and cur["v"] == e[1] else "normal", 60))
	box.add_child(UI.button(Strings.t("train.scrim_btn"), _choose.bind(p["id"], "scrim", ""), "primary" if cur["k"] == "scrim" else "normal", 66))
	box.add_child(UI.button(Strings.t("train.rest_btn"), _choose.bind(p["id"], "rest", ""), "primary" if cur["k"] == "rest" else "normal", 66))
	box.add_child(UI.button(Strings.t("train.auto_btn"), _auto_one.bind(p["id"]), "normal", 66))


func _toggle(pid: String) -> void:
	_open = "" if _open == pid else pid
	_hero_list = false
	_rebuild()


func _toggle_heroes() -> void:
	_hero_list = not _hero_list
	_rebuild()


func _choose(pid: String, kind: String, value: String) -> void:
	var gs := App.gs
	var prev: Variant = (gs.d["train"] as Dictionary).get(pid)
	if prev != null:
		prev = (prev as Dictionary).duplicate()
	gs.set_focus(pid, kind, value)
	_hero_list = false
	App.autosave()
	_rebuild()
	var p: Dictionary = App.world.players[pid]
	# a reversible change applies at once and can be taken back from the toast
	App.toast(Strings.f("train.toast", {"name": p["name"], "what": _focus_text(p)}), UI.ACCENT, Strings.t("common.undo"), _undo.bind(pid, prev))


func _undo(pid: String, prev: Variant) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if prev == null:
		(App.gs.d["train"] as Dictionary).erase(pid)
	else:
		App.gs.d["train"][pid] = prev
	App.autosave()
	_rebuild()


## What this week's choices lead to, before the next game: how many starters will be tired after it.
func _preview(parent: VBoxContainer) -> void:
	var gs := App.gs
	var w := App.world
	var now_tired := gs.tired_starters().size()
	var after_tired := 0
	var rest := 0
	for pid in (gs.d["lineup"] as Dictionary).values():
		var p: Dictionary = w.players[pid]
		var training: bool = gs.focus_of(p)["k"] != "rest"
		if not training:
			rest += 1
		var fat := clampf(w.fatigue_of(pid) + Progression.fatigue_delta(true, training), 0.0, 100.0)
		if fat >= 40.0:
			after_tired += 1
	var col := UI.WARN if after_tired > 0 else UI.GOOD
	UI.chips(parent, [[Strings.f("train.pv.now", {"n": now_tired}), UI.delta_color(-float(now_tired))],
			[Strings.f("train.pv.after", {"n": after_tired}), col],
			[Strings.f("train.pv.rest", {"n": rest}), UI.DIM]])
	parent.add_child(UI.label(Strings.f("train.pv.rates", {"train": UI.signed(Progression.fatigue_delta(true, true), 1), "rest": UI.signed(Progression.fatigue_delta(true, false), 1)}), UI.S_SMALL - 2, UI.DIM))


func _auto_one(pid: String) -> void:
	(App.gs.d["train"] as Dictionary).erase(pid)
	_hero_list = false
	App.autosave()
	_rebuild()


func _coach_all() -> void:
	App.gs.coach_picks_all()
	App.autosave()
	_rebuild()
