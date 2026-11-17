extends Node
## I-14 checks (a scene, the real screens): how the player meets the guided first game in every row of TUTORIAL 6.2, and Replay,
## Reset and "Show help hints again" in Settings (TUTORIAL 6.3). REAL Main, Title, Home, Settings, TutorialRunner, CoachOverlay
## and BottomSheet; the device flags live in a temp file (runner.device), the save is the real user://save.json (deleted at the
## end). Rows:
##   fresh_     a brand-new save (state new) on a fresh device: the welcome modal on Home, no inline card; Start runs the guide,
##              Skip skips it; killing the app at the modal shows the modal again (TUTORIAL 9 test 9's opposite)
##   returning_ a brand-new save on a device that answered before: the inline card, never the modal; Show me / No thanks (test 9)
##   legacy_    0.6 fixtures a to d (d is a fresh 0.6 save and must not show the modal): one inline card, once per device (test 7)
##   resume_    kill and reload through the real save file at steps 12, 18 and 21 (section 5 item 10): steps 7, 7, 24, live false,
##              game.n unchanged, the resume card and never a modal; the guide waits until the card is answered (test 6)
##   quiet_     done and skipped saves: nothing on Home
##   replay_    Settings, Replay: the confirm sheet, Cancel, Replay it in the league, playoffs and done phases (test 8)
##   reset_     Delete save and start over clears the save's tutorial; device flags stay, so the next club gets the inline card
##   hints_     Show help hints again clears "?" dots, lesson snoozes and the old [tips]; the old tips button is gone
##   cb_        colour-blind and animations off: the same cards, no tween running, no colour word in the offer texts (test 5)
##   fallback_  the old Home has no home.next_card yet: the fallback card shows, `fallbacks` counts it, Next goes on (test 13)
##   tapper_    a scripted first run from the welcome modal to the closing card: counts steps, taps and fallbacks (not minutes)
## Ends with " N checks, M failures".

const TEMP_CFG := "user://tut_flow_test.cfg"
const COLOUR_WORDS := ["red", "green", "blue", "orange", "teal", "coral", "yellow", "purple"]

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


## Wait until `cond` holds, at most `max_ms` milliseconds of real time (the overlay's waits are in seconds, not frames).
func until(cond: Callable, max_ms: int = 3000) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	await _fresh_device()
	await _fresh()
	await _returning()
	await _legacy()
	await _resume()
	await _quiet()
	await _replay()
	await _reset()
	await _hints()
	await _cb_anim_off()
	await _fallback()
	await _tapper()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_tutorial_flow: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ helpers
func _fresh_device() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	await frames(1)


func _dev() -> DeviceState:
	return DeviceState.new(TEMP_CFG)


## A fresh Main (as at app start: the Title screen is up), the runner pointed at the temp device file, short waits.
func _boot() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	if BottomSheet.is_open():
		BottomSheet.current().close()
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(3)
	var r: TutorialRunner = App.tutorial
	r.autosave = true
	r.device = _dev()
	r.wait_s = 0.3
	r.missing_s = 0.2


func _r() -> TutorialRunner:
	return App.tutorial


func _overlay() -> CoachOverlay:
	return App.tutorial.overlay if App.tutorial != null and App.tutorial.overlay != null and is_instance_valid(App.tutorial.overlay) else null


func _overlay_up() -> bool:
	var o := _overlay()
	return o != null and o.is_up()


func _offer() -> OfferCard:
	return UI.find_tag("home.offer") as OfferCard


func _cur() -> Node:
	for c in _main.get_node("Content").get_child(0).get_child(0).get_children():
		if not c.is_queued_for_deletion():
			return c
	return null


## A new club through the real club-select path (bind, autosave, Home).
func _new_club(club_index: int = 4) -> void:
	await _boot()
	GameState.delete_save()
	var cs := ScreenClubSelect.new()
	App.go(cs)
	await frames(2)
	cs._choose(App.world.club_ids[club_index])
	await frames(4)


## Title, Continue: what a player does after the app was closed (the real button, the real load_save).
func _continue_from_title() -> void:
	await _boot()
	var b := _find_button(_main, Strings.t("title.continue"))
	ok(b != null, "title shows Continue for a saved game")
	if b != null:
		b.pressed.emit()
	await frames(4)


func _find_button(root: Node, text: String) -> Button:
	if root is Button and UI.plain((root as Button).text) == UI.plain(text) and (root as Button).is_visible_in_tree():
		return root as Button
	for c in root.get_children():
		var f := _find_button(c, text)
		if f != null:
			return f
	return null


func _home() -> void:
	App.go(ScreenHub.new())
	await frames(4)


func _load_fixture(name: String) -> GameState:
	var f := FileAccess.open("res://tests/fixtures/" + name, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	return GameState.from_dict(App.world, data)


## Write `gs` as the player's save file (the real path) and boot as a player coming back.
func _write_and_continue(gs: GameState) -> void:
	App.gs = gs
	ok(gs.save(), "the save file is written")
	await _continue_from_title()


# ------------------------------------------------------------------ rows
func _fresh() -> void:
	await _fresh_device()
	await _new_club()
	ok(App.gs.tutorial()["state"] == "new", "fresh: a brand-new save is state new")
	ok(_cur() is ScreenHub, "fresh: the club pick lands on Home")
	ok(_r().home_offer() == "welcome_modal", "fresh: the offer for a new save on a fresh device is the welcome modal")
	ok(await until(func(): return _overlay_up()), "fresh: the welcome modal is on the overlay")
	var o := _overlay()
	ok(o != null and o.step_id == "welcome" and String(o.card_data().get("kind", "")) == "modal", "fresh: it is step 1, a modal")
	ok(o != null and o.button_ids().has("start") and o.button_ids().has("skip"), "fresh: the modal has Start and Skip tutorial")
	ok(o != null and o.body_text().contains(UI.plain(App.gs.club_name(App.gs.club()))), "fresh: the welcome text names the club")
	ok(_offer() == null, "fresh: no inline card under the modal")
	ok(not _dev().tutorial_flag("welcome_seen"), "fresh: the device flag is not set before an answer")
	# killed at the modal: state stays new, the modal shows again
	await _continue_from_title()
	ok(App.gs.tutorial()["state"] == "new", "fresh: after a kill at the modal the save is still new")
	ok(await until(func(): return _overlay_up() and _overlay().step_id == "welcome"), "fresh: after a kill at the modal the modal shows again")
	# Start
	_overlay().press("start")
	await frames(4)
	ok(_r().m.state() == "running" and _r().m.step_id() == "home_card", "fresh: Start runs the guide at step 2")
	ok(_dev().tutorial_flag("welcome_seen"), "fresh: Start sets welcome_seen on the device")
	var saved := GameState.load_save(App.world)
	ok(saved != null and saved.d["tutorial"]["state"] == "running" and int(saved.d["tutorial"]["game"]["n"]) == 1, "fresh: Start is in the save file (running, game.n 1)")
	await _home()
	ok(_offer() == null and _r().home_offer() == "none", "fresh: a running guide on screen shows no card on Home")
	# Skip at the modal (another fresh device)
	await _fresh_device()
	await _new_club()
	ok(await until(func(): return _overlay_up()), "fresh skip: the modal is up")
	_overlay().press("skip")
	await frames(4)
	ok(_r().m.state() == "skipped" and not _overlay_up(), "fresh skip: Skip tutorial at the modal skips; no overlay left")
	ok(_dev().tutorial_flag("welcome_seen") and _dev().tutorial_flag("skipped_once"), "fresh skip: welcome_seen and skipped_once on the device")
	await _home()
	ok(_offer() == null and not _overlay_up(), "fresh skip: Home shows nothing afterwards")


func _returning() -> void:
	await _fresh_device()
	_dev().set_tutorial_flag("welcome_seen")
	_dev().set_tutorial_flag("finished_once")
	await _new_club()
	await frames(4)
	ok(_r().home_offer() == "returning_card", "returning: a new save on a device that answered before gets the inline card")
	ok(not _overlay_up(), "returning: no modal")
	var c := _offer()
	ok(c != null and c.kind == "returning_card" and c.text() == UI.plain(Strings.t("tut.offer.returning")), "returning: the card says the returning text")
	ok(c != null and UI.plain(c.yes_button.text) == UI.plain(Strings.t("tut.offer.yes")) and UI.plain(c.no_button.text) == UI.plain(Strings.t("tut.offer.no")), "returning: Show me and No thanks")
	ok(c != null and c.yes_button.size.y >= UI.BTN_H and c.no_button.size.y >= UI.BTN_H, "returning: both buttons are at least %d px high" % UI.BTN_H)
	var next_card_y := -1.0
	var hub := _cur() as ScreenHub
	if hub != null and c != null:
		for k in hub.body.get_children():
			if k == c:
				break
			if k is Control and _find_button(k, Strings.t("hub.play")) != null:
				next_card_y = (k as Control).get_global_rect().end.y
	ok(c != null and next_card_y > 0.0 and c.get_global_rect().position.y >= next_card_y, "returning: the card sits below the Next-match card and its Play button")
	# No thanks
	c.no_button.pressed.emit()
	await frames(4)
	ok(_r().m.state() == "skipped" and _offer() == null, "returning: No thanks skips and the card is gone")
	await _home()
	ok(_offer() == null, "returning: Home shows no card afterwards")
	# Show me on another new club
	await _new_club(7)
	c = _offer()
	ok(c != null and c.kind == "returning_card", "returning: the next new club gets the card again")
	if c != null:
		c.yes_button.pressed.emit()
	await frames(4)
	ok(_r().m.state() == "running" and int(_r().m.game()["n"]) == 1, "returning: Show me runs the guide (game.n 1)")
	ok(await until(func(): return _overlay_up() and _overlay().step_id == "welcome"), "returning: Show me starts at step 1 (the welcome card)")
	ok(_offer() == null, "returning: the card is gone")


func _legacy() -> void:
	for fx in ["save_0_6_a.json", "save_0_6_b.json", "save_0_6_c.json", "save_0_6_d.json"]:
		await _fresh_device()
		await _boot()
		await _write_and_continue(_load_fixture(fx))
		ok(App.gs != null and App.gs.tutorial()["state"] == "legacy", "legacy %s: loads as legacy" % fx)
		ok(_cur() is ScreenHub, "legacy %s: Continue lands on Home" % fx)
		var c := _offer()
		ok(c != null and c.kind == "legacy_card" and c.text() == UI.plain(Strings.t("tut.offer.legacy")), "legacy %s: one inline card with the legacy text" % fx)
		await frames(6)
		ok(not _overlay_up(), "legacy %s: no modal, nothing starts" % fx)
	# No thanks (fixture d still loaded): gone for good on this device
	_offer().no_button.pressed.emit()
	await frames(4)
	ok(_offer() == null and _r().m.state() == "legacy" and _dev().tutorial_flag("legacy_offer_done"), "legacy: No thanks removes the card, the save stays legacy, the device remembers")
	await _home()
	ok(_offer() == null, "legacy: Home shows no card afterwards")
	await _write_and_continue(_load_fixture("save_0_6_b.json"))
	ok(_offer() == null and not _overlay_up(), "legacy: another old save on this device: no card (once per device)")
	# Show me (a fresh device)
	await _fresh_device()
	await _write_and_continue(_load_fixture("save_0_6_b.json"))
	var round_before := int(App.gs.d["round"])
	_offer().yes_button.pressed.emit()
	await frames(4)
	ok(_r().m.state() == "running" and _dev().tutorial_flag("legacy_offer_done") and _dev().tutorial_flag("welcome_seen"), "legacy: Show me runs the guide; the offer is used up on the device")
	ok(await until(func(): return _overlay_up() and _overlay().step_id == "welcome"), "legacy: Show me starts step 1")
	ok(int(App.gs.d["round"]) == round_before, "legacy: the season is where it was")


func _resume() -> void:
	# step number (1-based) -> where it resumes
	var rows := [["ban", 12, true, "tab_plan"], ["start_match", 18, true, "tab_plan"], ["result", 21, false, "tab_club"]]
	for row in rows:
		var sid: String = row[0]
		var want: String = row[3]
		await _fresh_device()
		_dev().set_tutorial_flag("welcome_seen")
		await _boot()
		var gs := GameState.new_game(App.world, App.world.club_ids[2], 4242)
		ok(TutorialState.step_index(sid) + 1 == int(row[1]), "resume: %s is step %d" % [sid, row[1]])
		gs.set_tutorial({"v": 1, "state": "running", "step": sid, "game": {"live": bool(row[2]), "n": 3, "plan": {"focus": "early"}}})
		await _write_and_continue(gs)
		var t := App.gs.tutorial()
		ok(t["state"] == "running" and t["step"] == want, "resume %s: a reload resumes at %s" % [sid, want])
		ok(t["game"]["live"] == false and (t["game"]["plan"] as Dictionary).is_empty() and int(t["game"]["n"]) == 3, "resume %s: live false, plan emptied, game.n unchanged (3)" % sid)
		ok(_r().m.resume_pending, "resume %s: the resume card is pending" % sid)
		var c := _offer()
		ok(c != null and c.kind == "resume_card" and c.text() == UI.plain(Strings.t("tut.resume")), "resume %s: Home shows the resume card" % sid)
		ok(c != null and UI.plain(c.yes_button.text) == UI.plain(Strings.t("tut.resume.go")) and UI.plain(c.no_button.text) == UI.plain(Strings.t("tut.skip")), "resume %s: Continue and Skip tutorial" % sid)
		await frames(6)
		ok(not _overlay_up(), "resume %s: never a modal; no step on screen before an answer" % sid)
		# the guide waits for the card: the step's own event does not move it
		App.bus.emit("tap:" + ("tab.plan" if want == "tab_plan" else "tab.club"), {})
		await frames(2)
		ok(_r().m.step_id() == want and not _overlay_up(), "resume %s: tapping the step's tab before answering moves nothing" % sid)
		if sid == "result":
			c.no_button.pressed.emit()
			await frames(4)
			ok(_r().m.state() == "skipped" and _offer() == null and not _overlay_up(), "resume %s: Skip tutorial on the card skips" % sid)
			ok(_r().m.undo_available(), "resume %s: the skip can be undone from the toast" % sid)
		else:
			c.yes_button.pressed.emit()
			await frames(2)
			ok(not _r().m.resume_pending and _offer() == null, "resume %s: Continue answers the card" % sid)
			ok(await until(func(): return _overlay_up() and _overlay().step_id == want), "resume %s: Continue shows step %s" % [sid, want])
			ok(int(_r().m.game()["n"]) == 3, "resume %s: no new game (game.n still 3)" % sid)
		var back := GameState.load_save(App.world)
		ok(back != null and int(back.d["tutorial"]["game"]["n"]) == 3 and back.d["tutorial"]["game"]["live"] == false, "resume %s: the save file holds the resumed state" % sid)


func _quiet() -> void:
	for st in ["done", "skipped"]:
		await _fresh_device()
		await _boot()
		var gs := GameState.new_game(App.world, App.world.club_ids[1], 99)
		gs.set_tutorial({"v": 1, "state": st, "step": "finish" if st == "done" else "tabs", "game": {"live": false, "n": 1, "plan": {}}})
		await _write_and_continue(gs)
		await frames(6)
		ok(_offer() == null and not _overlay_up() and _r().home_offer() == "none", "quiet: a %s save shows nothing on Home" % st)


func _settings() -> ScreenSettings:
	var s := ScreenSettings.new()
	App.go(s)
	await frames(4)
	return s


func _replay() -> void:
	await _fresh_device()
	_dev().set_tutorial_flag("welcome_seen")
	_dev().set_tutorial_flag("finished_once")
	await _boot()
	var gs := GameState.new_game(App.world, App.world.club_ids[3], 5150)
	var best := ""
	var best_r := -1.0
	for cid in App.world.club_ids:    # the strongest club, so the playoffs row really plays in the playoffs
		var rt := App.world.team_rating(gs.lineup_for(cid))
		if rt > best_r:
			best_r = rt
			best = cid
	gs = GameState.new_game(App.world, best, 5150)
	gs.set_tutorial({"v": 1, "state": "done", "step": "finish", "game": {"live": false, "n": 1, "plan": {}}})
	await _write_and_continue(gs)
	var s: ScreenSettings = await _settings()
	var hc := UI.find_tag("settings.help_card")
	ok(hc is SettingsHelpCard and s.body.get_child(0) == hc, "replay: Help and learning is the first card in Settings")
	ok(UI.find_tag("settings.replay") != null, "replay: the Replay button is tagged settings.replay")
	(UI.find_tag("settings.replay") as Button).pressed.emit()
	await frames(4)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "replay_confirm", "replay: a confirm sheet opens")
	ok(_find_button(App.main.sheet_layer, Strings.t("settings.replay_yes")) != null and _find_button(App.main.sheet_layer, Strings.t("common.cancel")) != null, "replay: Replay it and Cancel")
	(UI.find_tag("settings.replay_no") as Button).pressed.emit()
	await frames(20)
	ok(not BottomSheet.is_open() and _r().m.state() == "done", "replay: Cancel closes the sheet, nothing changes")
	var d_before := _snap(App.gs)
	for phase in ["league", "playoffs", "done"]:
		if phase == "playoffs":
			App.gs.autoplay(false)    # the AI plays the rest of the league; stops when the playoffs open
			ok(App.gs.d["phase"] == "playoffs", "replay: the season reached the playoffs (phase %s, round %d)" % [App.gs.d["phase"], int(App.gs.d["round"])])
		elif phase == "done":
			App.gs.autoplay(true)    # the AI plays the playoffs to the end of the split
			ok(App.gs.d["phase"] == "done", "replay: the split is over (phase %s)" % App.gs.d["phase"])
		d_before = _snap(App.gs)
		var n0 := int(App.gs.tutorial()["game"]["n"])
		await _settings()
		(UI.find_tag("settings.replay") as Button).pressed.emit()
		await frames(4)
		(UI.find_tag("settings.replay_yes") as Button).pressed.emit()
		await frames(6)
		ok(_cur() is ScreenHub, "replay %s: Replay it goes to Home" % phase)
		ok(_r().m.state() == "running" and int(_r().m.game()["n"]) == n0 + 1, "replay %s: running again, game.n up by one (%d)" % [phase, n0 + 1])
		ok(await until(func(): return _overlay_up() and _overlay().step_id == "welcome"), "replay %s: the welcome card shows" % phase)
		ok(_offer() == null, "replay %s: no inline card under it" % phase)
		_overlay().press("start")
		await frames(4)
		var none_next := App.gs.next_game().is_empty()
		if none_next:
			ok(_r().passed.has("home_card") and _r().m.step_id() == "tabs", "replay %s: no next game, so step 2 is passed over" % phase)
		else:
			ok(_r().m.step_id() == "home_card", "replay %s: step 2 next" % phase)
		ok(_snap(App.gs) == d_before, "replay %s: nothing in the save changed but the tutorial key" % phase)
		# finish this run directly (the full run is the tapper row): the save says done, the runner takes it again
		App.gs.set_tutorial({"v": 1, "state": "done", "step": "finish", "game": {"live": false, "n": n0 + 1, "plan": {}}})
		_r().bind()
		await frames(2)
	ok(true, "replay: done")


func _snap(gs: GameState) -> String:
	var c: Dictionary = gs.d.duplicate(true)
	c.erase("tutorial")
	return JSON.stringify(c, "", true)


func _reset() -> void:
	await _fresh_device()
	await _new_club()
	ok(await until(func(): return _overlay_up()), "reset: a fresh club shows the modal")
	_overlay().press("start")
	await frames(4)
	var flags_before := [_dev().tutorial_flag("welcome_seen"), _dev().tutorial_flag("finished_once"), _dev().tutorial_flag("skipped_once")]
	var s: ScreenSettings = await _settings()
	s._confirm_reset = true
	s._rebuild()
	await frames(2)
	_find_button(s, Strings.t("settings.reset_yes")).pressed.emit()
	await frames(4)
	ok(not GameState.has_save() and App.gs == null, "reset: the save is gone")
	ok(_r().m == null and not _overlay_up(), "reset: the guide of the deleted save is gone (no overlay)")
	ok([_dev().tutorial_flag("welcome_seen"), _dev().tutorial_flag("finished_once"), _dev().tutorial_flag("skipped_once")] == flags_before, "reset: device flags stay")
	ok(_cur() is ScreenTitle, "reset: back on the title screen")
	var cs := ScreenClubSelect.new()
	App.go(cs)
	await frames(2)
	cs._choose(App.world.club_ids[6])
	await frames(6)
	ok(App.gs.tutorial()["state"] == "new", "reset: the next club is a new save")
	ok(_offer() != null and _offer().kind == "returning_card" and not _overlay_up(), "reset: the second club gets the inline card, not the modal")


func _hints() -> void:
	await _fresh_device()
	_dev().set_tutorial_flag("welcome_seen")
	await _new_club()
	var dv := _dev()
	dv.help_mark("home")
	dv.help_mark("draft")
	dv.set_lesson_status("l1", "snoozed:2")
	dv.set_lesson_status("l2", "dismissed")
	dv.set_lesson_status("l3", "done")
	App.tip_mark("hub")
	var s: ScreenSettings = await _settings()
	ok(_find_button(s, Strings.t("settings.tips_again")) == null, "hints: the old Show the welcome tips again button is gone")
	var hc := UI.find_tag("settings.help_card") as SettingsHelpCard
	ok(hc != null and UI.plain(hc.hints_button.text) == UI.plain(Strings.t("settings.help_reset")), "hints: Show help hints again is on the card")
	ok(_find_button(hc, Strings.t("settings.lessons")) == null and _find_button(hc, Strings.t("settings.glossary")) == null, "hints: Lessons and Glossary wait for their screens (I-22, I-23)")
	hc.hints_button.pressed.emit()
	await frames(2)
	dv = _dev()
	ok(dv.help_ids().is_empty() and not dv.help_seen("home"), "hints: the ? dots are cleared")
	ok(dv.lesson_status("l1") == "offered" and dv.lesson_status("l2") == "offered" and dv.lesson_status("l3") == "done", "hints: snoozed and dismissed lessons are offered again, done keeps its tick")
	ok(not App.tip_seen("hub"), "hints: the old tips come back too (until I-24)")
	ok(_find_button(App.main.toast_layer, Strings.t("settings.help_reset_done")) != null or _toast_text().contains(UI.plain(Strings.t("settings.help_reset_done"))), "hints: a toast confirms")
	# the card in large text: every button at least 96 px, nothing wider than the screen
	App.apply_large_text(true)
	s = await _settings()
	hc = UI.find_tag("settings.help_card") as SettingsHelpCard
	ok(hc != null and hc.replay_button.size.y >= UI.BTN_H and hc.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x + 0.5, "hints: large text, the card fits and its buttons are tall enough")
	App.apply_large_text(false)
	await frames(2)


func _toast_text() -> String:
	var out := ""
	for n in App.main.toast_layer.find_children("*", "Label", true, false):
		out += UI.plain((n as Label).text) + "\n"
	return out


func _cb_anim_off() -> void:
	App.set_colorblind(true)
	UI.animate = false
	await _fresh_device()
	await _new_club()
	ok(await until(func(): return _overlay_up()), "cb: the modal shows with colour-blind colours")
	ok(not _overlay().animating(), "cb: animations off, no tween running on the overlay")
	for key in ["tut.offer.legacy", "tut.offer.returning", "tut.resume", "tut.welcome"]:
		var words := UI.plain(Strings.t(key)).to_lower().replace(".", " ").replace(",", " ").replace("?", " ").split(" ", false)
		var bad := ""
		for w in COLOUR_WORDS:
			if words.has(w):
				bad = w
		ok(bad == "", "cb: %s has no colour word" % key)
	_overlay().press("skip")
	await frames(2)
	await _new_club(8)
	var c := _offer()
	ok(c != null and c.kind == "returning_card", "cb: the inline card shows the same")
	App.set_colorblind(false)
	await frames(2)


func _fallback() -> void:
	await _fresh_device()
	await _new_club()
	await until(func(): return _overlay_up())
	_overlay().wait_s = CoachOverlay.WAIT_S    # the real timeouts for this row (the others use short ones)
	_overlay().missing_s = CoachOverlay.MISSING_S
	var real_card := UI.find_tag("home.next_card")
	ok(real_card != null, "fallback: the redesigned Home carries home.next_card (I-15)")
	if real_card != null:
		real_card.get_parent().queue_free()    # TUTORIAL 9 test 13: remove one target (before step 2 starts); hidden would read as
		# "not on screen yet" (the 6 s wait of TUTORIAL 3.4), removed reads as "missing" (the 2 s fallback tested here)
	await frames(3)
	ok(UI.find_tag("home.next_card") == null, "fallback: with the card removed no control carries home.next_card")
	_overlay().press("start")
	await frames(2)
	var t0 := Time.get_ticks_msec()
	ok(await until(func(): return _overlay() != null and _overlay().is_fallback(), 8000), "fallback: the fallback card shows")
	var waited := Time.get_ticks_msec() - t0
	ok(waited < 2600, "fallback: about 2 seconds after the screen is up (%d ms; MISSING_S %.1f s)" % [waited, CoachOverlay.MISSING_S])
	ok(_r().fallbacks == 1, "fallback: fallbacks counts it (%d)" % _r().fallbacks)
	ok(_overlay().nudge_text() == UI.plain(Strings.t("tut.fallback")) and _overlay().body_text() == UI.plain(Strings.t("tut.home_card")), "fallback: the fallback line and the step's own text")
	_overlay().press("next")
	await frames(4)
	ok(_r().m.step_id() == "tabs", "fallback: Next goes on to step 3")
	ok(_r().debug_line().contains("fallbacks=1"), "fallback: the debug line shows it (%s)" % _r().debug_line())


## A scripted first run from the welcome modal to the closing card. Each step gets exactly one tap: the card button on modal and
## info steps and on fallback cards, the real control on a tap step whose target is on screen. Counts steps, taps and fallbacks;
## this is the time of the first game in taps, not minutes (K12).
func _tapper() -> void:
	await _fresh_device()
	await _new_club()
	var r := _r()
	var taps := 0
	var steps_seen: Array = []
	var real_taps := 0
	var fell: Array = []
	var guard := 0
	while guard < 400 and r.m != null and r.m.state() != "done":
		guard += 1
		if r.m.step_id() == "see_report" and _cur() is ScreenMatch:
			(_cur() as ScreenMatch)._skip()    # the player watches to the end or taps Skip: the Report button shows at the end
			await frames(3)
		var shown := await until(func(): return _overlay() != null and (_overlay().mode == "shown" or _overlay().mode == "fallback") and _overlay().step_id == r.m.step_id(), 8000)
		if not shown:
			print("     tapper: nothing shown at %s (mode %s)" % [r.m.step_id(), _overlay().mode if _overlay() != null else "no overlay"])
			break
		var o := _overlay()
		var sid := o.step_id
		if steps_seen.is_empty() or steps_seen[steps_seen.size() - 1] != sid + "/" + o.stage:
			steps_seen.append(sid + "/" + o.stage)
		var ids := o.button_ids()
		if o.is_fallback() and not fell.has(sid):
			fell.append(sid)
		var kind := String(o.card_data().get("kind", ""))
		var target: Control = null
		for tid in o.card_data().get("target", []):
			target = UI.find_tag(String(tid))
		var hero_grid: HeroGrid = null
		if target != null and not (target is BaseButton):
			for k in target.get_children():    # a tile (UI.tag_tile): its flat hit button takes the tap
				if k is BaseButton:
					target = k
					break
			var grids: Array = []
			if not (target is BaseButton):
				grids = Array(target.find_children("*", "HeroGrid", true, false))
			if not grids.is_empty():
				hero_grid = grids[0] as HeroGrid    # the draft's choices (I-16): a finger on the first hero card
		if hero_grid != null and not o.is_fallback():
			var dr := _cur() as ScreenDraft
			if dr != null and not dr.draft.is_done() and dr.draft.current()["team"] != dr.my_side:
				await frames(5)    # the other side is choosing: a player waits for their turn (no tap)
				continue
			var first := String(hero_grid.shown_ids()[0])
			hero_grid._tapped(hero_grid.heroes.find(hero_grid.heroes.filter(func(h: Dictionary) -> bool: return h["id"] == first)[0]))
			real_taps += 1
			taps += 1
			await frames(3)
			continue
		if target is PlayerCard and not o.is_fallback() and kind == "tap":
			(target as PlayerCard).pressed.emit()    # a drawn card (the Squad's bench, I-19) takes the tap itself
			real_taps += 1
			taps += 1
			await frames(4)
			continue
		var before := "%s/%s/%s" % [r.m.state(), r.m.step_id(), r.m.stage]
		if o.is_fallback() or kind == "modal" or kind == "info" or target == null or not (target is BaseButton):
			var which := "start" if ids.has("start") else ("go_home" if ids.has("go_home") else "next")
			if not o.press(which):
				print("     tapper: no %s button at %s (buttons %s)" % [which, sid, str(ids)])
				break
		else:
			(target as BaseButton).pressed.emit()
			real_taps += 1
		taps += 1
		await frames(3)
		var after := "%s/%s/%s" % [r.m.state(), r.m.step_id(), r.m.stage] if r.m != null else "none"
		if after == before:
			await frames(10)
			after = "%s/%s/%s" % [r.m.state(), r.m.step_id(), r.m.stage] if r.m != null else "none"
			if after == before:
				print("     tapper: no progress at ", before)
				break
	ok(r.m != null and r.m.state() == "done", "tapper: the scripted run reaches the end (state done)")
	var n_steps := TutorialState.steps().size()
	print("     tapper: %d cards (steps and stages), %d taps (%d on real controls), %d fallbacks %s, %d passed over" % [steps_seen.size(), taps, real_taps, r.fallbacks, str(fell), r.passed.size()])
	ok(fell == ["form_switch"], "tapper: after I-19 (build plan I-19 acceptance): the only fallback card is step 26 (%s)" % str(fell))
	ok(taps == steps_seen.size(), "tapper: exactly one tap per card (%d taps, %d cards)" % [taps, steps_seen.size()])
	ok(steps_seen.size() + r.passed.size() >= n_steps, "tapper: every one of the %d steps was shown or passed over" % n_steps)
	ok(_dev().tutorial_flag("finished_once"), "tapper: finished_once on the device")
	ok(not _overlay_up(), "tapper: no overlay left after the closing card")
