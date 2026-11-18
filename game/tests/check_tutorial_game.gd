extends Node
## I-13 checks, part 2 (a scene, the real screens): the tutorial game flag as Prematch, Match and the finish path read it.
## The sandbox proof itself (deep compare of gs.d, RNG isolation, replay seeds, the opponent rule, legacy, resume) runs headless in
## tests/tutorial_tests.gd. Rows here: pre_ (Pre-match shows the tutorial note and its Quick button skips the pace log),
## match_ (Quick mode is ignored for the tutorial game and still works for a real one), fin_ (the finish path: flag on the result,
## no Payoff, sandbox dropped, gs.d identical, tutorial machine told the game is over), back_ (backing out drops the sandbox).
## Writes user://save.json through App.autosave and deletes it at the end. Ends with " N checks, M failures".

const TEMP_CFG := "user://tut_game_test.cfg"

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


func _snap(gs: GameState) -> String:
	var c: Dictionary = gs.d.duplicate(true)
	c.erase("tutorial")
	return JSON.stringify(c, "", true)


func _ready() -> void:
	TutorialRunner.home_offers = false    # I-14: Home's welcome modal and offer cards depend on this machine's settings.cfg; tested in check_tutorial_flow
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	await _fresh_main()
	await _prematch_and_finish()
	await _fresh_main()
	await _match_quick_mode()
	await _fresh_main()
	await _back_out()
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_tutorial_game: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _fresh_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(3)
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], 20261113)
	App.go(ScreenHub.new())
	await frames(3)
	var r: TutorialRunner = App.tutorial
	r.autosave = false
	r.device = DeviceState.new(TEMP_CFG)
	r.accept()      # Start/Show me: running, game.n 1
	await frames(2)


func _find_button(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text == UI.tidy(text):
		return root as Button
	for c in root.get_children():
		var f := _find_button(c, text)
		if f != null:
			return f
	return null


func _find_label(root: Node, text: String) -> Label:
	if root is Label and (root as Label).text == UI.tidy(text):
		return root as Label
	for c in root.get_children():
		var f := _find_label(c, text)
		if f != null:
			return f
	return null


func _screen() -> Control:
	return App.main.get("_current")


func _prematch_and_finish() -> void:
	var gs := App.gs
	var g := TutorialGame.start(gs)
	App.tutorial.set_game_live(true)
	ok(App.tutorial.m.game()["live"] == true, "setup: the runner knows the tutorial game is live")
	App.go(ScreenPreMatch.new(gs.next_game()))
	await frames(3)
	ok(_screen() != null and _find_button(_screen(), Strings.t("pre.change_lineup")) != null, "pre_: a real game's Pre-match still has Change lineup (control row)")
	var before := _snap(gs)
	var pace_before := JSON.stringify(gs.d.get("pace", {}), "", true)   # d.get: gs.pace() would create the key and the compare would see it
	App.go(ScreenPreMatch.new(g))
	await frames(3)
	var scr := _screen()
	ok(scr is ScreenPreMatch, "pre_: the Pre-match screen is up for the tutorial game")
	ok(scr != null and _find_label(scr, Strings.t("tut.practice.note")) != null, "pre_: it shows the tutorial note (nothing in it counts), not the series line")
	ok(scr != null and _find_label(scr, Strings.f("pre.practice_note", {"game": 1, "bo": 1})) == null, "pre_: the ordinary practice note is not shown for the tutorial game")
	ok(scr != null and _find_button(scr, Strings.t("pre.change_lineup")) == null and _find_button(scr, Strings.t("pre.rotate")) == null,
			"pre_: Change lineup and Rotate are hidden for the tutorial game (they edit the season; I-14)")
	var qb := _find_button(scr, Strings.t("hub.quick")) if scr != null else null
	ok(qb != null, "pre_: the Quick (auto-play) button exists, outside every tutorial hole by design")
	if qb != null:
		qb.pressed.emit()
	await frames(4)
	ok(_screen() is ScreenReport, "fin_: the Report opens after the game")
	ok(TutorialGame.is_tutorial(App.last_result) and TutorialGame.is_tutorial(App.last_game), "fin_: App.last_game and App.last_result carry the tutorial flag")
	ok(App.last_payoff.is_empty(), "fin_: no Payoff was computed for the tutorial game")
	ok(not TutorialGame.is_live(gs), "fin_: the sandbox plan is dropped when the game finishes")
	ok(App.tutorial.m.game()["live"] == false, "fin_: the tutorial machine was told the game is over (live false)")
	ok(_snap(gs) == before, "fin_: gs.d is identical before and after the whole screen path (all keys but tutorial)")
	ok(JSON.stringify(gs.d.get("pace", {}), "", true) == pace_before, "pre_: the pace log did not move (the Quick button skips pace_quick for the tutorial game)")


func _match_quick_mode() -> void:
	var gs := App.gs
	gs.set_quick(true)
	var g := TutorialGame.start(gs)
	var dr := MatchRunner.prepare(App.world, gs.lineup_for(g["blue"]), gs.lineup_for(g["red"]), gs.meta_for(int(g["round"])), int(gs.d["save_seed"]), g["id"], false)
	dr.finish_with_ai()
	var res := MatchRunner.finish(App.world, dr, gs.plans_for(g))
	var before := _snap(gs)
	var pace_before := JSON.stringify(gs.d.get("pace", {}), "", true)
	var m := ScreenMatch.new(g, res)
	App.go(m)
	await frames(4)
	ok(_screen() == m and m.script_ != null and not m._finished, "match_: Quick mode is ignored for the tutorial game: the watch screen (the arena) is up")
	m._skip()
	await frames(2)
	ok(m._finished and m._go_btn != null and m._go_btn.visible, "match_: skip reaches the end of the feed, the Continue button shows")
	m._continue()
	await frames(4)
	ok(_snap(gs) == before and JSON.stringify(gs.d.get("pace", {}), "", true) == pace_before, "match_: finishing the watched tutorial game leaves gs.d and the pace log identical")
	ok(TutorialGame.is_tutorial(App.last_result) and App.last_payoff.is_empty(), "match_: the result is flagged and has no Payoff")
	# control: a real practice game with Quick mode on goes straight through (and writes the pace log), so the switch is live
	gs.set_quick(true)
	gs.start_practice(gs.quick_match_opponent(), 1)
	var pg := gs.practice_game()
	var pres := gs.auto_game(pg)
	var quick_before := int(gs.pace()["quick"])
	var m2 := ScreenMatch.new(pg, pres)
	App.go(m2)
	await frames(4)
	ok(int(gs.pace()["quick"]) == quick_before + 1, "match_ control: with Quick mode on, a real game skips the watch and logs the pace (the tutorial game did not)")
	gs.set_quick(false)


func _back_out() -> void:
	var gs := App.gs
	var g := TutorialGame.start(gs)
	App.tutorial.set_game_live(true)
	var before := _snap(gs)
	var pre := ScreenPreMatch.new(g)
	App.go(pre)
	await frames(3)
	ok(TutorialGame.is_live(gs), "back_: setup: the sandbox is live on the Pre-match screen")
	pre.go_back()
	await frames(3)
	ok(not TutorialGame.is_live(gs) and App.tutorial.m.game()["live"] == false, "back_: backing out of Pre-match drops the sandbox plan and tells the machine")
	ok(_screen() is ScreenPractice, "back_: it returns to Practice")
	ok(_snap(gs) == before, "back_: nothing in the save changed")
