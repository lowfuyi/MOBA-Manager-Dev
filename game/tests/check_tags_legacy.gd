extends Node
## I-21a checks: tutorial ids and events on the screens that stay as they are (Plan, Practice, Pre-match, Club, Match), REAL Main and
## screens. Rows:
##   tags_plan      plan.tile.training / chem / practice exist, are visible tiles, and a tap raises tap:<id> and opens the place
##   tags_practice  practice.quick on the real Practice; in tutorial mode (steps 8 to 11) Quick Match starts the tutorial game whatever
##                  the phase or the practice day says, and writes nothing to the save but the tutorial key
##   tags_prematch  prematch.matchups (the card) and prematch.start_draft; no old Pre-match tip card
##   tags_club      club.tile.form / finance / fa; Form Rating opens Standings on form
##   tags_match     match.controls (the Menu), match.report_btn; match:speed, match:skip, match:end fire from the menu; watching changes neither the result
##                  nor the save (R7): same seed, same result with the tags present
##   steps_         tutorial steps 8, 9, 10, 11, 19, 20 and 25 find their targets on the old screens (shown, never the fallback card),
##                  and the hole is the target plus 8 px
## Ends with " N checks, M failures".

const TEMP_CFG := "user://tut_tags_test.cfg"

var checks := 0
var fails := 0
var _main: Control
var _events: Array = []


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func until(cond: Callable, max_ms: int = 3000) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _ready() -> void:
	TutorialRunner.home_offers = false
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	await _boot()
	await _tags_plan()
	await _boot()
	await _tags_practice()
	await _boot()
	await _tags_prematch()
	await _boot()
	await _tags_club()
	await _boot()
	await _tags_match()
	for sid in ["plan_practice", "quick_match", "matchups", "start_draft", "watch", "see_report", "form_tile"]:
		await _boot()
		await _step(sid)
	_main.queue_free()
	await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_tags_legacy: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ helpers
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
	var r: TutorialRunner = App.tutorial
	r.autosave = false
	r.device = DeviceState.new(TEMP_CFG)
	r.wait_s = 0.4
	r.missing_s = 0.3
	r.bind()
	_events.clear()
	App.bus.raised.connect(func(n: String, _d: Dictionary) -> void: _events.append(n))


func _cur() -> Node:
	for c in _main.get_node("Content").get_child(0).get_child(0).get_children():
		if not c.is_queued_for_deletion():
			return c
	return null


func _go(s: Control) -> void:
	App.go(s)
	await frames(4)


func _visible_in_viewport(c: Control) -> bool:
	if c == null or not c.is_visible_in_tree():
		return false
	var r := c.get_global_rect()
	var vp := get_viewport().get_visible_rect()
	return r.size.x > 0.0 and r.size.y > 0.0 and vp.encloses(r)


func _hit(tile: Control) -> BaseButton:
	if tile is BaseButton:
		return tile as BaseButton    # I-21b: a drawn StatTile is its own hit button
	for c in tile.get_children():
		if c is BaseButton:
			return c as BaseButton
	return null


func _snap(gs: GameState) -> String:
	var c: Dictionary = gs.d.duplicate(true)
	c.erase("tutorial")
	return JSON.stringify(c, "", true)


func _find_text_button(root: Node, text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if UI.plain((n as Button).text) == UI.plain(text) and (n as Button).is_visible_in_tree():
			return n as Button
	return null


func _labels_text(root: Node) -> String:
	var out := ""
	for n in root.find_children("*", "Label", true, false):
		out += UI.plain((n as Label).text) + "\n"
	return out


# ------------------------------------------------------------------ rows
func _tags_plan() -> void:
	await _go(ScreenPlan.new())
	for id in ["plan.tile.training", "plan.tile.chem", "plan.tile.practice"]:
		var t := UI.find_tag(id)
		ok((t is PanelContainer or t is HomeKit.StatTile) and _visible_in_viewport(t) and _hit(t) != null, "tags_plan: %s is a visible tile on Plan" % id)
	_events.clear()
	_hit(UI.find_tag("plan.tile.practice")).pressed.emit()
	await frames(4)
	ok(_events.has("tap:plan.tile.practice") and _events.count("tap:plan.tile.practice") == 1, "tags_plan: one tap raises tap:plan.tile.practice once")
	ok(_cur() is ScreenPractice, "tags_plan: and opens Practice as before")
	await _go(ScreenPlan.new())
	_hit(UI.find_tag("plan.tile.training")).pressed.emit()
	await frames(4)
	ok(_cur() is ScreenTraining and _events.has("tap:plan.tile.training"), "tags_plan: Training tile still opens Training and raises its tap")


func _tags_practice() -> void:
	var gs := App.gs
	await _go(ScreenPractice.new())
	var q := UI.find_tag("practice.quick")
	ok(q is Button and _visible_in_viewport(q), "tags_practice: practice.quick is a visible button (real Practice, league, practice free)")
	ok(not ScreenPractice.tutorial_mode(), "tags_practice: not in tutorial mode while the guide is not running")
	_events.clear()
	(q as Button).pressed.emit()
	await frames(4)
	ok(_events.has("tap:practice.quick"), "tags_practice: the tap raises tap:practice.quick")
	ok(gs.practice_in_progress() and _cur() is ScreenPreMatch and not TutorialGame.is_tutorial((_cur() as ScreenPreMatch).game), "tags_practice: the real Quick Match starts a real practice game")
	# tutorial mode: the practice day already used and a real series in flight; Quick Match still starts the tutorial game
	gs.set_tutorial({"v": 1, "state": "running", "step": "quick_match", "game": {"live": false, "n": 1, "plan": {}}})
	App.tutorial.bind()
	await frames(2)
	var before := _snap(gs)
	await _go(ScreenPractice.new())
	ok(ScreenPractice.tutorial_mode(), "tags_practice: tutorial mode at step 9")
	q = UI.find_tag("practice.quick")
	ok(q is Button and _visible_in_viewport(q), "tags_practice: tutorial mode shows Quick Match although a real practice is in flight")
	ok(_labels_text(_cur()).contains(UI.plain(Strings.t("tut.practice.note"))), "tags_practice: tutorial mode says nothing in it counts")
	(q as Button).pressed.emit()
	await frames(4)
	var pm := _cur() as ScreenPreMatch
	ok(pm != null and TutorialGame.is_tutorial(pm.game), "tags_practice: Quick Match in tutorial mode opens Pre-match for the tutorial game")
	ok(TutorialGame.is_live(gs) and App.tutorial.m.game()["live"] == true, "tags_practice: the tutorial game is live (sandbox and runner)")
	ok(_snap(gs) == before, "tags_practice: nothing in the save changed but the tutorial key")
	ok(App.tutorial.m.step_id() == "matchups", "tags_practice: the guide moved on to step 10")
	# backing out: Practice offers the tutorial game again, never the real one
	pm.go_back()
	await frames(4)
	ok(_cur() is ScreenPractice and ScreenPractice.tutorial_mode() and UI.find_tag("practice.quick") != null, "tags_practice: after backing out at step 10 Practice offers the tutorial game again")
	ok(not TutorialGame.is_live(gs), "tags_practice: backing out dropped the sandbox")
	# outside the league phase, still there in tutorial mode
	gs.d["phase"] = "done"    # the real Practice shows only "not in this phase" now
	await _go(ScreenPractice.new())
	ok(UI.find_tag("practice.quick") != null, "tags_practice: tutorial mode works outside the league phase")
	gs.d["phase"] = "league"
	# after the Practice steps, Practice is the real one again
	gs.set_tutorial({"v": 1, "state": "running", "step": "tab_club", "game": {"live": false, "n": 1, "plan": {}}})
	App.tutorial.bind()
	await _go(ScreenPractice.new())
	ok(not ScreenPractice.tutorial_mode(), "tags_practice: at step 24 Practice is the real one again")


func _tags_prematch() -> void:
	var gs := App.gs
	var g := gs.next_game()
	await _go(ScreenPreMatch.new(g))
	var m := UI.find_tag("prematch.matchups")
	ok(m is PanelContainer and m.is_visible_in_tree() and m.get_global_rect().size.y > 100.0, "tags_prematch: prematch.matchups is the matchups card")
	ok(_labels_text(m).contains(UI.plain(Strings.t("pre.matchups"))), "tags_prematch: it holds the matchups heading")
	var sd := UI.find_tag("prematch.start_draft")
	ok(sd is Button and _visible_in_viewport(sd) and UI.plain((sd as Button).text) == UI.plain(Strings.t("pre.start_draft")), "tags_prematch: prematch.start_draft is the Start draft button, on screen")
	await _go(ScreenPreMatch.new(g))
	ok(_find_text_button(_cur(), Strings.t("help.got_it")) == null, "tags_prematch: no tip card with Got it (the old tips are retired, I-24)")
	_events.clear()
	(UI.find_tag("prematch.start_draft") as Button).pressed.emit()
	await frames(4)
	ok(_events.has("tap:prematch.start_draft") and _cur() is ScreenDraft, "tags_prematch: Start draft raises its tap and opens the draft")


func _tags_club() -> void:
	await _go(ScreenClub.new())
	for id in ["club.tile.form", "club.tile.finance", "club.tile.fa"]:
		var t := UI.find_tag(id)
		ok((t is PanelContainer or t is HomeKit.StatTile) and t.is_visible_in_tree() and _hit(t) != null, "tags_club: %s is a tile on Club" % id)
	ok(_visible_in_viewport(UI.find_tag("club.tile.form")), "tags_club: the Form Rating tile is on screen without scrolling")
	_events.clear()
	_hit(UI.find_tag("club.tile.form")).pressed.emit()
	await frames(4)
	ok(_events.has("tap:club.tile.form") and _cur() is ScreenStandings, "tags_club: Form Rating raises its tap and opens Standings")


func _match_pair() -> Array:
	var gs := App.gs
	var g := gs.next_game()
	return [g, gs.auto_game(g)]


func _tags_match() -> void:
	var gs := App.gs
	var pair := _match_pair()
	var g: Dictionary = pair[0]
	var res: Dictionary = pair[1]
	var res_text := JSON.stringify(res, "", true)
	var before := JSON.stringify(gs.d, "", true)
	var sm := ScreenMatch.new(g, res)
	await _go(sm)
	var mc := UI.find_tag("match.controls")
	ok(mc != null and _visible_in_viewport(mc), "tags_match: match.controls (the Menu with speed and skip, Match Day M2) is on screen")
	ok(mc == sm._menu_btn, "tags_match: it is the Menu button")
	ok(UI.find_tag("match.report_btn") == null, "tags_match: the report button is hidden while the match runs")
	_events.clear()
	sm._menu_btn.pressed.emit()
	await frames(4)
	(UI.find_tag("match.menu.speed2") as Button).pressed.emit()
	await frames(4)
	ok(_events.has("match:speed"), "tags_match: Speed x2 in the menu raises match:speed")
	sm._menu_btn.pressed.emit()
	await frames(4)
	(UI.find_tag("match.menu.skip") as Button).pressed.emit()
	await frames(4)
	ok(_events.has("match:skip") and _events.has("match:end"), "tags_match: Skip raises match:skip, then match:end")
	ok(_events.find("match:skip") < _events.find("match:end"), "tags_match: in that order")
	var rb := UI.find_tag("match.report_btn")
	ok(rb is Button and _visible_in_viewport(rb), "tags_match: match.report_btn shows at the end")
	ok(JSON.stringify(sm.res, "", true) == res_text, "tags_match: watching did not change the result")
	ok(JSON.stringify(gs.d, "", true) == before, "tags_match: watching did not change the save")
	# a match that runs to its end by itself raises match:end once
	var sm2 := ScreenMatch.new(g, res)
	await _go(sm2)
	_events.clear()
	for i in 400:
		if sm2._finished:
			break
		sm2._process(1.0)
	await frames(1)
	ok(sm2._finished and _events.count("match:end") == 1 and not _events.has("match:skip"), "tags_match: a match watched to the end raises match:end once, no skip")
	# R7: same seed, same result with the tags present: the result a fresh copy of the save computes equals the one shown
	var copy := GameState.from_dict(App.world, JSON.parse_string(before))
	ok(JSON.stringify(copy.auto_game(g), "", true) == res_text, "tags_match: same seed, same result (a copy of the save plays the game the same)")
	_events.clear()
	rb = UI.find_tag("match.report_btn")
	(rb as Button).pressed.emit()
	await frames(4)
	ok(_events.has("tap:match.report_btn"), "tags_match: the report button raises tap:match.report_btn")


## One tutorial step on its old screen: the runner at that step, the screen up; the overlay must find the target (shown, not fallback).
func _step(sid: String) -> void:
	var gs := App.gs
	var screen: Control = null
	var live := false
	match sid:
		"plan_practice":
			screen = ScreenPlan.new()
		"quick_match":
			screen = ScreenPractice.new()
		"matchups", "start_draft":
			screen = ScreenPreMatch.new(TutorialGame.start(gs))
			live = true
		"watch", "see_report":
			var g := TutorialGame.start(gs)
			screen = ScreenMatch.new(g, gs.auto_game(g))
			live = true
		"form_tile":
			screen = ScreenClub.new()
	gs.set_tutorial({"v": 1, "state": "running", "step": sid, "game": {"live": live, "n": 1, "plan": {}}})
	await _go(screen)
	if sid == "see_report":
		(screen as ScreenMatch)._skip()
		await frames(2)
	App.tutorial.bind()
	var shown := await until(func(): return App.tutorial.overlay != null and is_instance_valid(App.tutorial.overlay) and (App.tutorial.overlay.mode == "shown" or App.tutorial.overlay.mode == "fallback"))
	var o := App.tutorial.overlay
	ok(shown and o.mode == "shown" and not o.is_fallback(), "steps_%s: step %d finds its target on the old screen (mode %s)" % [sid, TutorialState.step_index(sid) + 1, o.mode if o != null else "none"])
	ok(App.tutorial.fallbacks == 0, "steps_%s: no fallback counted" % sid)
	var tid := String((TutorialState.step_def(sid)["target"] as Array)[0])
	var t := UI.find_tag(tid)
	if o != null and t != null and o.mode == "shown":
		var want := t.get_global_rect().grow(CoachOverlay.PAD).intersection(get_viewport().get_visible_rect())
		ok(o.hole_rect().is_equal_approx(want) or o.hole_rect().encloses(t.get_global_rect()), "steps_%s: the hole is the target plus %d px" % [sid, int(CoachOverlay.PAD)])
	TutorialGame.leave(gs)
