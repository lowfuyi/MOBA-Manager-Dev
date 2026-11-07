class_name ScreenPreMatch
extends Screen

var game: Dictionary


func _init(g: Dictionary = {}) -> void:
	super._init()
	game = g


func go_back() -> void:
	App.go(ScreenHub.new())


func _ready() -> void:
	var gs := App.gs
	var me := gs.club()
	var my_side := "B" if game["blue"] == me else "R"
	var opp: String = game["red"] if my_side == "B" else game["blue"]
	setup(Strings.t("pre.title"), go_back)
	var c := UI.card(body, UI.PANEL2)
	c.add_child(UI.label(Strings.f("pre.versus", {"me": gs.club_name(me), "opp": gs.club_name(opp)}), UI.S_BIG, UI.TEXT))
	c.add_child(UI.label(Strings.f("pre.side", {"side": Strings.t("hub.side.blue" if my_side == "B" else "hub.side.red")}), UI.S_SMALL, UI.DIM))
	var secs: int = 15 if game["full"] else 10
	c.add_child(UI.label(Strings.f("pre.draft_info", {"type": Strings.t("hub.draft.full" if game["full"] else "hub.draft.short"), "secs": secs}), UI.S_SMALL, UI.DIM))
	# matchups
	var mine := gs.lineup()
	var theirs := gs.lineup_for(opp)
	var m := UI.card(body)
	m.add_child(UI.label(Strings.t("pre.matchups"), UI.S_BODY, UI.ACCENT))
	for s in GameState.SLOTS:
		var a: Dictionary = mine[s]
		var b: Dictionary = theirs[s]
		var ra := App.world.slot_score(a, s)
		var rb := App.world.slot_score(b, s)
		var col := UI.GOOD if ra > rb + 1.5 else (UI.BAD if ra < rb - 1.5 else UI.TEXT)
		m.add_child(UI.label(Strings.f("pre.row", {"role": Strings.t("role." + s), "mine": a["name"], "rm": "%.0f" % ra, "theirs": b["name"], "rt": "%.0f" % rb}), UI.S_SMALL, col))
		if App.world.player_fit(a, s) < 1.0:
			m.add_child(UI.label(Strings.f("pre.offrole", {"name": a["name"]}), UI.S_SMALL - 2, UI.WARN))
	var tired := gs.tired_starters()
	if not tired.is_empty():
		var tc := UI.card(body, UI.PANEL2, 14)
		tc.add_child(UI.label(Strings.f("pre.tired_warn", {"n": tired.size()}), UI.S_SMALL, UI.WARN))
		tc.add_child(UI.button(Strings.t("pre.rotate"), _rotate, "normal", 76))
	body.add_child(UI.button(Strings.t("pre.change_lineup"), func(): App.go(ScreenRoster.new("prematch", game))))
	body.add_child(UI.button(Strings.t("pre.start_draft"), func(): App.go(ScreenDraft.new(game)), "primary"))
	body.add_child(UI.button(Strings.t("hub.quick"), _quick, "normal", 76))


func _quick() -> void:
	ScreenHub._finish_game(game, App.gs.auto_game(game))


func _rotate() -> void:
	App.gs.reset_lineup()
	App.autosave()
	App.go(ScreenPreMatch.new(game))
