extends Node
## I-21b checks on the restyled Plan and Club tabs and Match day (screen_plan.gd, screen_club.gd, screen_prematch.gd), headless:
##   fit_tabs_<v>     each screen (and Match day with tired starters) in normal and large text: no control leaves the frame, no drawn
##                    text is cut (tiles, matchups), buttons at least 96 px high, nodes under 120
##   tiles            every tile opens its place (Training, Team chemistry, Practice; Finance, Standings, Form Rating on Form, Free agents)
##   matchups         each lane row says stronger, even or weaker by an arrow and a word, from the same 1.5-point rule as before, and
##                    off-role in words (the I-21a colour-only debt)
##   coral            Start draft is the one coral action of Match day; Rotate rests the tired starters; Change lineup opens the Squad
## Ends with " N checks, M failures".

const TEMP_CFG := "user://tabs_test.cfg"

var checks := 0
var fails := 0
var _main: Control


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	TutorialRunner.home_offers = false
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	for v in ["normal", "large"]:
		await _boot()
		await _fit_all(v)
	App.apply_large_text(false)
	await _boot()
	await _tiles()
	await _boot()
	await _matchups()
	await _boot()
	await _coral()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_ui_tabs: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _boot() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(3)
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], 20261117)
	App.tutorial.autosave = false
	App.tutorial.device = DeviceState.new(TEMP_CFG)
	App.tutorial.bind()


func _cur() -> Node:
	return App.main._current


func _count(n: Node) -> int:
	var t := 1
	for c in n.get_children():
		t += _count(c)
	return t


func _cut(root: Node) -> Array:
	var out: Array = []
	for g in root.find_children("*", "TileGrid", true, false):
		for t in (g as HomeKit.TileGrid).tiles():
			var st := t as HomeKit.StatTile
			for s in [st.caption.to_upper(), st.value, st.sub]:
				if String(s) != "" and (g as HomeKit.TileGrid)._ops.clipped.has(String(s)):
					out.append(String(s))
	if root is ScreenPreMatch and (root as ScreenPreMatch).matchups != null:
		out.append_array((root as ScreenPreMatch).matchups.clipped())
	return out


func _fit(v: String, st: String) -> void:
	await frames(4)
	var r: Node = _cur()
	for c in r.find_children("*", "Control", true, false):
		(c as Control).queue_redraw()
	await frames(3)
	var vw := get_viewport().get_visible_rect().size.x
	var outside: Array = []
	var short: Array = []
	for c in r.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.is_visible_in_tree() and ctl.size.x > 0.0 and not (ctl is ScrollBar):
			var gr := ctl.get_global_rect()
			if gr.position.x < -0.5 or gr.end.x > vw + 0.5:
				outside.append("%s %s" % [ctl.name, str(gr)])
			if ctl is BaseButton and gr.size.y < float(UI.BTN_H) - 0.5:
				short.append("%s %.0f" % [ctl.name, gr.size.y])
	ok(outside.is_empty(), "fit_tabs_%s_%s: no control leaves the frame %s" % [v, st, str(outside.slice(0, 3))])
	ok(short.is_empty(), "fit_tabs_%s_%s: buttons at least 96 px %s" % [v, st, str(short)])
	var cut := _cut(r)
	ok(cut.is_empty(), "fit_tabs_%s_%s: no drawn text is cut %s" % [v, st, str(cut)])
	ok(_count(r) <= 120, "fit_tabs_%s_%s: %d nodes (target 120)" % [v, st, _count(r)])


func _fit_all(v: String) -> void:
	App.apply_large_text(v == "large")
	await frames(3)
	App.go(ScreenPlan.new())
	await _fit(v, "plan")
	App.go(ScreenClub.new())
	await _fit(v, "club")
	var g: Dictionary = App.gs.next_game()
	App.go(ScreenPreMatch.new(g))
	await _fit(v, "prematch")
	for pid in (App.gs.d["lineup"] as Dictionary).values():
		App.world.fatigue[pid] = 80.0
	App.go(ScreenPreMatch.new(g))
	await _fit(v, "prematch_tired")
	App.world.fatigue.clear()


func _tiles() -> void:
	var want := {"plan.tile.training": ScreenTraining, "plan.tile.chem": ScreenChemistry, "plan.tile.practice": ScreenPractice}
	for id in want:
		App.go(ScreenPlan.new())
		await frames(3)
		(UI.find_tag(id) as BaseButton).pressed.emit()
		await frames(3)
		ok(is_instance_of(_cur(), want[id]), "tiles: %s opens its screen" % id)
	var want2 := {"club.tile.finance": ScreenFinance, "club.tile.table": ScreenStandings, "club.tile.form": ScreenStandings, "club.tile.fa": ScreenFreeAgents}
	for id in want2:
		App.go(ScreenClub.new())
		await frames(3)
		(UI.find_tag(id) as BaseButton).pressed.emit()
		await frames(3)
		ok(is_instance_of(_cur(), want2[id]), "tiles: %s opens its screen" % id)
		if id == "club.tile.form":
			ok((_cur() as ScreenStandings)._metric == "form", "tiles: Form Rating opens Standings on Form Rating")


func _matchups() -> void:
	var g: Dictionary = App.gs.next_game()
	# one starter off-role, so the word shows
	App.gs.assign("top", String(App.gs.d["lineup"]["sup"]))
	var pm := ScreenPreMatch.new(g)
	App.go(pm)
	await frames(4)
	var me := App.gs.club()
	var opp: String = g["red"] if g["blue"] == me else g["blue"]
	var good := true
	var off := false
	for r in pm.matchups.rows:
		var s := String(r["role"])
		var ra := App.world.slot_score(App.gs.lineup()[s], s)
		var rb := App.world.slot_score(App.gs.lineup_for(opp)[s], s)
		var want := "up" if ra > rb + 1.5 else ("down" if ra < rb - 1.5 else "even")
		good = good and String(r["edge"]) == want
		off = off or bool(r["off"])
	ok(good and pm.matchups.rows.size() == 5, "matchups: every lane says stronger, even or weaker by the 1.5-point rule")
	ok(off and CompKit.cue_of(pm.matchups).contains("word"), "matchups: off-role shows, and the rows carry an arrow and a word")
	ok(UI.plain(ScreenPreMatch._Matchups.edge_word("up")) == UI.plain(Strings.t("pre.edge.up")) and UI.plain(ScreenPreMatch._Matchups.edge_word("down")) == UI.plain(Strings.t("pre.edge.down")), "matchups: the words come from the copy")


func _coral() -> void:
	var g: Dictionary = App.gs.next_game()
	for pid in (App.gs.d["lineup"] as Dictionary).values():
		App.world.fatigue[pid] = 80.0
	var pm := ScreenPreMatch.new(g)
	App.go(pm)
	await frames(4)
	var coral := 0
	for b in pm.find_children("*", "Button", true, false):
		var sb := (b as Button).get_theme_stylebox("normal") as StyleBoxFlat
		if sb != null and sb.bg_color.is_equal_approx(UI.CORAL):
			coral += 1
	ok(coral == 1 and (UI.find_tag("prematch.start_draft") as Button).get_theme_stylebox("normal").bg_color.is_equal_approx(UI.CORAL), "coral: Start draft is the one coral action (%d)" % coral)
	pm._rotate()
	await frames(3)
	ok(App.gs.tired_starters().size() < 5, "coral: Rotate rests tired starters (%d still tired)" % App.gs.tired_starters().size())
	App.world.fatigue.clear()
	var pm2 := _cur() as ScreenPreMatch
	var change: Button = null
	for b in pm2.find_children("*", "Button", true, false):
		if UI.plain((b as Button).text) == UI.plain(Strings.t("pre.change_lineup")):
			change = b
	change.pressed.emit()
	await frames(3)
	ok(_cur() is ScreenRoster and (_cur() as ScreenRoster).tab_id() == "", "coral: Change lineup opens the Squad for Match day")
