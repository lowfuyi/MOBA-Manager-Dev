class_name ScreenChemistry
extends Screen
## Team Bonds screen (GDD 7.7): the pentagon of the five starters, the 5x5 Understanding grid, languages and the bench.


var _from := "plan"


func _init(from: String = "plan") -> void:
	super._init()
	_from = from


func tab_id() -> String:
	return "squad" if _from == "roster" else "plan"


func go_back() -> void:
	if _from == "roster":
		App.go(ScreenRoster.new("hub"))
	else:
		App.go_tab("plan")


func _ready() -> void:
	setup(Strings.t("chem.title"), go_back)
	var gs := App.gs
	var w := App.world
	var lu := gs.lineup()
	var five: Array = []
	for s in GameState.SLOTS:
		five.append(lu[s])
	var head := UI.card(body, UI.PANEL2)
	head.add_child(UI.label(Strings.f("chem.summary", {"chem": "%.0f" % gs.chem(), "bonus": UI.pct(gs.chem_bonus())}), UI.S_BIG, UI.TEXT))
	head.add_child(UI.label(Strings.t("chem.hint"), UI.S_SMALL, UI.DIM))

	var pc := UI.card(body)
	pc.add_child(UI.label(Strings.t("chem.pentagon_h"), UI.S_BODY, UI.ACCENT))
	var pent := BondPentagon.new()
	for s in GameState.SLOTS:
		pent.ids.append(lu[s]["id"])
		pent.names.append(lu[s]["name"])
		pent.tags.append(Strings.t("role.short." + s))
	pent.bond_of = func(a, b): return gs.bond(a, b)
	pent.under_of = func(a, b): return Bonds.understanding(w.players[a], w.players[b], gs.bond(a, b))
	pc.add_child(pent)
	pc.add_child(UI.label(Strings.t("chem.pentagon_hint"), UI.S_SMALL, UI.DIM))

	var gc := UI.card(body)
	gc.add_child(UI.label(Strings.t("chem.grid_h"), UI.S_BODY, UI.ACCENT))
	gc.add_child(UI.label(Strings.t("chem.grid_hint"), UI.S_SMALL, UI.DIM))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)    # six columns, "Support" (76 px) must fit a cell at large text: 85 px
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	gc.add_child(grid)
	grid.add_child(_cell("", UI.PANEL, UI.TEXT))
	for s in GameState.SLOTS:
		grid.add_child(_cell(Strings.t("role.short." + s), UI.PANEL, UI.ACCENT))
	for i in 5:
		grid.add_child(_cell(Strings.t("role.short." + GameState.SLOTS[i]), UI.PANEL, UI.ACCENT))
		for j in 5:
			if i == j:
				grid.add_child(_cell("-", UI.PANEL, UI.DIM))
				continue
			var u := Bonds.understanding(five[i], five[j], gs.bond(five[i]["id"], five[j]["id"]))
			var col := BondPentagon.understanding_color(u)
			grid.add_child(_cell("%.0f" % u, col.darkened(0.55), UI.TEXT))

	var lc := UI.card(body)
	lc.add_child(UI.label(Strings.t("chem.langs_h"), UI.S_BODY, UI.ACCENT))
	for p in five:
		var parts: Array = []
		for l in p.get("languages", []):
			parts.append(Strings.f("chem.lang_one", {"lang": Strings.t("lang." + String(l["lang"])), "fluency": int(l["fluency"])}))
		lc.add_child(UI.label(Strings.f("chem.lang_row", {"name": p["name"], "list": ", ".join(PackedStringArray(parts))}), UI.S_SMALL, UI.TEXT))

	var starters: Array = (gs.d["lineup"] as Dictionary).values()
	var bench: Array = []
	for p in w.club_players(gs.club()):
		if not starters.has(p["id"]):
			bench.append(p)
	if not bench.is_empty():
		var bc := UI.card(body)
		bc.add_child(UI.label(Strings.t("chem.bench_h"), UI.S_BODY, UI.ACCENT))
		for p in bench:
			var t := 0.0
			for sid in starters:
				t += gs.bond(p["id"], sid)
			bc.add_child(UI.label(Strings.f("chem.bench_row", {"name": p["name"], "avg": "%.0f" % (t / float(starters.size()))}), UI.S_SMALL, UI.TEXT))
		bc.add_child(UI.label(Strings.t("chem.bench_hint"), UI.S_SMALL, UI.DIM))
	var tc := UI.card(body, UI.PANEL2)
	tc.add_child(UI.label(Strings.t("chem.scrim_hint"), UI.S_SMALL, UI.DIM))
	tc.add_child(UI.button(Strings.t("chem.training"), func(): App.go(ScreenTraining.new()), "normal", 76))


func _cell(text: String, bg: Color, fg: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(72, 64)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	pc.add_theme_stylebox_override("panel", UI.box(bg, 8, 0))    # no padding: "Support" is 76 px (Caption 24 SemiBold), a cell is 85 px at large text
	var l := UI.label(text, UI.S_CAPTION, fg)    # Caption weight (SemiBold), the scale's own pair
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pc.add_child(l)
	return pc
