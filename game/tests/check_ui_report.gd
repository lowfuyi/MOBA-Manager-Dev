extends Node
## I-18 checks on the REAL Match report (screen_report.gd), headless:
##   build_report / fit_report_<v>  a win, a loss, the tutorial game, the Why sheet, a phase sheet and the three More-detail parts
##                    build in normal and large text: built once; no control leaves the frame; no drawn text is cut (result, story
##                    chips, changes, factor bars, More-detail bar); buttons at least 96 px high; nodes under 120; Continue on screen
##   no_tips          no old Tips card on the Report (the "After every game" tip is retired), league game or tutorial game
##   score            the score line is Report.team_kills for every fixture (and the sum of the players' kills)
##   story            the story tag is the report.story key of the three phase signs in res["sim"]; the phase ticks and the eight
##                    chips follow the signs of res["sim"]["contests"]; the dots follow Report.margin_word (no new claims)
##   stat             the big number is the largest factor of Report.attribution; luck is said plainly when it is the largest
##   coral            Continue is the one coral action of the screen
##   fixtures         a narrow game (the closest of the games played: the sim has no draws), the longest game (its clock in
##                    the summary and the moments), a practice game (practice card, no payoff, no tip), the tutorial game
##                    (tutorial card, no payoff, no tip); Back leaves like Continue
##   events_report    a tap on the big number opens the Why sheet and raises open:report_why once; a tap on a phase opens its
##                    moments
##   tags_report      report.result, report.why, report.why_sheet, report.continue; tutorial steps 21 to 23 find their targets
##                    with no fallback and Continue goes to Practice
## Ends with " N checks, M failures".

const TEMP_CFG := "user://report_test.cfg"

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
	for v in ["normal", "large"]:
		await _boot()
		await _build_and_fit(v)
	App.apply_large_text(false)
	await _boot()
	await _fixtures()
	await _boot()
	await _events_report()
	await _boot()
	await _tags()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_ui_report: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ helpers
func _boot(seed_value: int = 20261117) -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	if BottomSheet.is_open():
		BottomSheet.current().close()
		await frames(2)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(3)
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], seed_value)
	var r: TutorialRunner = App.tutorial
	r.autosave = false
	r.device = DeviceState.new(TEMP_CFG)
	r.wait_s = 0.4
	r.missing_s = 0.3
	r.bind()
	_events.clear()
	App.bus.raised.connect(func(n: String, d: Dictionary) -> void: _events.append([n, d]))


func _cur() -> Node:
	return App.main._current


func _count(n: Node) -> int:
	var t := 1
	for c in n.get_children():
		t += _count(c)
	return t


func _ev(name: String) -> int:
	var n := 0
	for e in _events:
		if e[0] == name:
			n += 1
	return n


func _close_sheet() -> void:
	if BottomSheet.is_open():
		BottomSheet.current().close()
	await frames(20)


## Play a game (the next league game, or `g`) through the Draft and the Match to its Report.
func _play(g: Dictionary = {}, before_continue: Callable = Callable()) -> ScreenReport:
	var gg := g if not g.is_empty() else App.gs.next_game()
	var d := ScreenDraft.new(gg)
	App.go(d)
	await frames(3)
	d._auto_rest()
	d._start_match()
	await frames(3)
	var m: ScreenMatch = _cur()
	m._skip()
	if before_continue.is_valid():
		before_continue.call()
	m._continue()
	await frames(4)
	return _cur() as ScreenReport


func _labels(root: Node) -> String:
	var out := ""
	for n in root.find_children("*", "Label", true, false):
		out += UI.plain((n as Label).text) + "\n"
	for n in root.find_children("*", "Button", true, false):
		out += UI.plain((n as Button).text) + "\n"
	return out


func _cut(r: ScreenReport) -> Array:
	var out: Array = []
	for t in r.result.clipped():
		out.append("result: " + String(t))
	for t in r.bands.clipped():
		out.append("story: " + String(t))
	for t in r.strip.clipped:
		out.append("strip: " + String(t))
	if r.changes != null:
		for t in r.changes.clipped():
			out.append("changes: " + String(t))
	if r.why_bars != null and is_instance_valid(r.why_bars) and r.why_bars.is_visible_in_tree():
		for t in r.why_bars.clipped():
			out.append("why: " + String(t))
	if r.dig_bar.is_visible_in_tree():
		for t in r.dig_bar.clipped():
			out.append("more: " + String(t))
	return out


func _redraw_all(r: ScreenReport) -> void:
	for c in [r.result, r.bands, r.strip, r.changes, r.why_bars, r.dig_bar]:
		if c != null and is_instance_valid(c):
			(c as Control).queue_redraw()
	await frames(3)


func _fit_state(r: ScreenReport, v: String, st: String) -> void:
	await _redraw_all(r)
	var vp := get_viewport().get_visible_rect()
	var outside: Array = []
	var roots: Array = [r]
	if BottomSheet.is_open():
		roots.append(BottomSheet.current())
	for root in roots:
		for c in (root as Node).find_children("*", "Control", true, false):
			var ctl := c as Control
			if ctl.is_visible_in_tree() and ctl.size.x > 0.0 and not (ctl is ScrollBar):
				var gr := ctl.get_global_rect()
				if gr.position.x < -0.5 or gr.end.x > vp.size.x + 0.5:
					outside.append("%s %s" % [ctl.name, str(gr)])
	ok(outside.is_empty(), "fit_report_%s_%s: no control leaves the %d px frame %s" % [v, st, int(vp.size.x), str(outside.slice(0, 3))])
	var cut := _cut(r)
	ok(cut.is_empty(), "fit_report_%s_%s: no drawn text is cut %s" % [v, st, str(cut)])
	var short: Array = []
	for root in roots:
		for b in (root as Node).find_children("*", "BaseButton", true, false):
			var bb := b as BaseButton
			if bb.is_visible_in_tree() and bb.size.y < float(UI.BTN_H) - 0.5:
				short.append("%s %.0f" % [bb.name, bb.size.y])
	ok(short.is_empty(), "fit_report_%s_%s: every button is at least 96 px high %s" % [v, st, str(short)])
	ok(_count(r) <= 120, "build_report_%s_%s: %d nodes (target 120)" % [v, st, _count(r)])
	ok(vp.encloses(r.continue_button.get_global_rect()), "build_report_%s_%s: Continue is on screen" % [v, st])


func _coral(root: Node) -> int:
	var n := 0
	for b in root.find_children("*", "Button", true, false):
		var sb := (b as Button).get_theme_stylebox("normal") as StyleBoxFlat
		if (b as Button).is_visible_in_tree() and sb != null and sb.bg_color.is_equal_approx(UI.CORAL):
			n += 1
	return n


# ------------------------------------------------------------------ rows
func _build_and_fit(v: String) -> void:
	App.apply_large_text(v == "large")
	await frames(3)
	var seen := {}
	for i in 8:
		var r := await _play()
		var st := "win" if r.won else "loss"
		if seen.has(st):
			r._leave()
			await frames(2)
			continue
		seen[st] = true
		ok(r.build_count == 1, "build_report_%s_%s: the screen builds once" % [v, st])
		await _fit_state(r, v, st)
		if st == "win":
			r._open_why()
			await frames(6)
			await _fit_state(r, v, "why")
			await _close_sheet()
			r._open_phase("early")
			await frames(6)
			await _fit_state(r, v, "phase")
			await _close_sheet()
			r._toggle_dig()
			for part in ["players", "moments", "draft"]:
				r.dig_bar.press(r.dig_bar.index_of(part))
				await frames(3)
				ok(r._dig == part and r.dig_box.get_child_count() > 0, "build_report_%s_more_%s: More detail shows %s" % [v, part, part])
				await _fit_state(r, v, "more_" + part)
		r._leave()
		await frames(2)
		if seen.size() == 2:
			break
	ok(seen.size() == 2, "build_report_%s: a win and a loss were both seen (%s)" % [v, str(seen.keys())])
	var tg := TutorialGame.start(App.gs)
	var tr := await _play(tg)
	ok(tr != null and tr.is_tutorial() and tr.practice_card != null and tr.changes == null and tr.tip_card == null, "build_report_%s_tutorial: the tutorial card, no payoff, no tip" % v)
	if tr != null:
		await _fit_state(tr, v, "tutorial")


## Per-report truths: score, story, stat, no tips, one coral action.
func _truths(r: ScreenReport, label: String) -> void:
	var tk := Report.team_kills(r.res)
	var k := Report.kda(r.res)
	var sum_me := 0
	for s in GameState.SLOTS:
		sum_me += int(k[r.my_side][s]["k"])
	var opp := "R" if r.my_side == "B" else "B"
	ok(r.score() == [int(tk[r.my_side]), int(tk[opp])] and r.result.kills == r.score() and sum_me == int(tk[r.my_side]) and r.result.score_text() == "%d - %d" % [tk[r.my_side], tk[opp]],
			"score_%s: the score line is the team kills %s" % [label, r.result.score_text()])
	ok((r.score()[0] > r.score()[1]) == r.won, "score_%s: the side with more kills is the winner" % label)
	var sgn := 1.0 if r.my_side == "B" else -1.0
	var key := "report.story."
	for ph in ["early", "mid", "late"]:
		key += "p" if sgn * float(r.res["sim"][ph]) > 0.0 else "m"
	ok(UI.plain(r.story_label.text) == UI.plain(Strings.t(key)), "story_%s: the story tag is %s" % [label, key])
	var ticks := true
	for ph in ["early", "mid", "late"]:
		ticks = ticks and String(r.strip.phase(ph)["result"]) == ("win" if sgn * float(r.res["sim"][ph]) > 0.0 else "lose")
	var chips := 0
	var chips_ok := true
	for row in r.bands.rows:
		for it in row[1]:
			chips += 1
			var c := sgn * float(r.res["sim"]["contests"][String(it["key"])])
			chips_ok = chips_ok and bool(it["mine"]) == (c > 0.0) and String(it["size"]) == Report.margin_word(c)
	ok(ticks and chips == 8 and chips_ok, "story_%s: the phase ticks and the 8 chips follow res[\"sim\"] (no new claims)" % label)
	var top := {}
	for f in r.att["factors"]:
		if top.is_empty() or absf(float(f["share"])) > absf(float(top["share"])):
			top = f
	ok(is_equal_approx(r.stat.value, round(absf(float(top["share"])) * 100.0)), "stat_%s: the big number is the largest factor (%s, %.0f%%)" % [label, top["id"], r.stat.value])
	if String(top["id"]) == "luck":
		ok(UI.plain(r.stat_sentence()).contains(UI.plain(Strings.t("factor.luck")).to_lower().split(" ")[0]) or r.stat_sentence().begins_with("Luck"), "stat_%s: luck is said plainly" % label)
	var text := _labels(r)
	ok(not text.contains(UI.plain(Strings.t("help.got_it"))), "no_tips_%s: no old tip card (with Got it) on the Report" % label)
	ok(_coral(r) == 1 and _coral(r.continue_button.get_parent()) >= 1, "coral_%s: Continue is the one coral action (%d coral buttons)" % [label, _coral(r)])


func _fixtures() -> void:
	var closest := 9.0
	var closest_word := ""
	var longest := 0.0
	var long_text := ""
	var long_mmss := ""
	var labels := {}
	for i in 10:
		var r := await _play()
		var st := "win" if r.won else "loss"
		if not labels.has(st):
			labels[st] = true
			await _truths(r, st)
		var f := absf(float(r.res["final"]))
		if f < closest:
			closest = f
			closest_word = Report.result_word(float(r.res["final"]))
		var mins := Report.game_minutes(r.res)
		if mins > longest:
			longest = mins
			long_mmss = ScreenMatch._mmss(mins)
			long_text = r.result.line
		r._leave()
		await frames(2)
	ok(closest_word == "narrow", "fixtures: the closest of 10 games reads as a narrow game (|final| %.3f, %s)" % [closest, closest_word])
	ok(long_text.contains(long_mmss), "fixtures: the longest game (%s) shows its clock in the summary" % long_mmss)
	# a practice game: the practice card, no payoff, no tip
	var g := App.gs.next_game()
	var xg: Dictionary = g.duplicate()
	xg["kind"] = "exhibition"
	var pr := await _play_practice()
	if pr != null:
		ok(pr.is_practice() and not pr.is_tutorial() and pr.practice_card != null and pr.changes == null and pr.tip_card == null, "fixtures: a practice game shows the practice card, no payoff, no tip")
		await _truths(pr, "practice")
		pr.go_back()
		await frames(3)
		ok(_cur() is ScreenPractice, "fixtures: Back from a practice report goes to Practice, like Continue")
	# the tutorial game
	var tr := await _play(TutorialGame.start(App.gs))
	await _truths(tr, "tutorial")
	ok(_labels(tr).contains(UI.plain(Strings.t("tut.report_card.body"))), "fixtures: the tutorial report says nothing in the season changed")


## A Quick Match practice game through the real Practice screen path (Pre-match -> Draft).
func _play_practice() -> ScreenReport:
	var p := ScreenPractice.new()
	App.go(p)
	await frames(3)
	if not p.has_method("_quick_match"):
		ok(false, "fixtures: Practice has _quick_match")
		return null
	p._quick_match()
	await frames(3)
	var pm := _cur() as ScreenPreMatch
	if pm == null:
		ok(false, "fixtures: Quick Match opens Pre-match")
		return null
	return await _play(pm.game)


func _events_report() -> void:
	var r := await _play()
	_events.clear()
	var hit: Button = null
	for c in r.stat_tile.get_children():
		if c is Button:
			hit = c
	hit.pressed.emit()
	await frames(4)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "report_why" and _ev("open:report_why") == 1 and _ev("tap:report.why") == 1, "events_report: a tap on the big number opens the Why sheet (open:report_why once)")
	ok(r.why_bars != null and r.why_bars.factors.size() == (r.att["factors"] as Array).size(), "events_report: the sheet has a bar per factor (%d)" % (r.att["factors"] as Array).size())
	await _close_sheet()
	r.bands.press(1)
	await frames(4)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "report_phase" and BottomSheet.current().title == PlanKit.name_of_phase("mid"), "events_report: a tap on the Mid band opens the Mid moments")
	App.main.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(20)
	ok(not BottomSheet.is_open() and _cur() == r, "events_report: Android back closes the sheet first")
	r.continue_button.pressed.emit()
	await frames(3)
	ok(_cur() is ScreenHub and _ev("tap:report.continue") == 1, "events_report: Continue goes Home and raises tap:report.continue")


func _shown_ok(step: String) -> bool:
	var o := App.tutorial.overlay
	return o != null and is_instance_valid(o) and o.step_id == step and (o.mode == "shown" or o.mode == "fallback")


func _tags() -> void:
	var tg := TutorialGame.start(App.gs)
	App.gs.set_tutorial({"v": 1, "state": "running", "step": "see_report", "game": {"live": true, "n": 1, "plan": {}}})
	App.tutorial.bind()
	App.tutorial.set_game_live(true)
	var r := await _play(tg, func() -> void:
		App.gs.set_tutorial({"v": 1, "state": "running", "step": "result", "game": {"live": true, "n": 1, "plan": {}}})
		App.tutorial.bind())
	App.tutorial.bind()
	for id in ["report.result", "report.why", "report.continue"]:
		ok(UI.find_tag(id) != null and UI.find_tag(id).is_visible_in_tree(), "tags_report: %s is there" % id)
	ok(await until(func(): return _shown_ok("result")) and App.tutorial.overlay.mode == "shown", "tags_report: step 21 (result) finds report.result")
	App.tutorial._on_button("next")
	await frames(4)
	ok(await until(func(): return _shown_ok("why")) and App.tutorial.overlay.mode == "shown", "tags_report: step 22 finds report.why")
	r._open_why()
	await frames(6)
	ok(await until(func(): return App.tutorial.overlay.mode == "shown" and App.tutorial.m.stage == "b") and UI.find_tag("report.why_sheet") != null, "tags_report: step 22 stage B finds report.why_sheet in the sheet")
	App.tutorial._on_button("next")
	await frames(20)
	ok(not BottomSheet.is_open() and await until(func(): return _shown_ok("continue")) and App.tutorial.overlay.mode == "shown", "tags_report: Next closes the sheet; step 23 finds report.continue")
	ok(App.tutorial.fallbacks == 0, "tags_report: no fallback card in steps 21 to 23 (%d)" % App.tutorial.fallbacks)
	r.continue_button.pressed.emit()
	await frames(4)
	ok(_cur() is ScreenPractice and App.tutorial.m.step_id() == "tab_club", "tags_report: Continue goes to Practice and the guide moves on (%s)" % App.tutorial.m.step_id())
