extends Node
## I-17 checks on the REAL Game Plan (screen_game_plan.gd), headless:
##   build_gp / fit_gp_<v>  every state builds (Overall, Early, Mid, Late, If behind off and on, the Coach sheet, the plan sheet) in
##                    normal and large text; no control leaves the frame; no drawn text is cut (hero, stand, tracks, strip, Jungle
##                    focus); buttons at least 96 px high; nodes under the target (120); the expected edge stays on screen; large text: the edge is
##                    one line and the Tempo slider is on screen on the Early page (0.12.1, DECISIONS Q6-2 (c))
##   equivalence      30 random sequences of taps on the real controls (plan sheet rows and switches, the off card, phase nodes,
##                    detents, Jungle focus, Coach and Apply, Reset) leave the same plan set in the save as the old screen's logic
##                    given the same actions (the old methods' bodies, copied below as the reference model)
##   inert            in the If behind plan Lane aggression and Jungle focus take no change and say why; Tempo, Fight style,
##                    Support and Risk say only part applies; and the claim is true: the simulation gives the same result for any
##                    value of an inert control (GamePlan.simulate with the trigger firing)
##   undo             Apply and Reset each have an Undo that puts the plan back
##   inplace_gp       50 taps of every kind: no rebuild (rebuild_count 0), built once, the same controls; the tap cost on this
##                    desktop against the 22 ms baseline (a desktop ratio only, not a phone number)
##   events           gp:coach_open, gp:coach_apply, gp:coach_close once each per act; the gp_coach_apply shortcut applies
##   cb_gp            the edge, the meters, inert controls and the selected plan carry a shape or word, not colour alone
##   tags_gp          gp.coach, gp.coach_apply, gp.start_match are there; tutorial steps 17 and 18 find their targets (no fallback)
## Ends with " N checks, M failures".

const TEMP_CFG := "user://gameplan_test.cfg"

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
	await _equivalence()
	await _boot()
	await _inert()
	await _boot()
	await _undo()
	await _boot()
	await _inplace()
	await _boot()
	await _events_once()
	await _boot()
	await _cb()
	await _boot()
	await _tags()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_ui_gameplan: %d checks, %d failures" % [checks, fails])
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


## A finished draft for the next game, then the Game Plan on it (the plan set starts neutral with no triggers).
func _gp(g: Dictionary = {}) -> ScreenGamePlan:
	var gg := g if not g.is_empty() else App.gs.next_game()
	var d := ScreenDraft.new(gg)
	App.go(d)
	await frames(3)
	d._auto_rest()
	await frames(2)
	var ps: Dictionary = App.gs.plan_set()
	ps["triggers"].clear()
	var n := GamePlan.neutral()
	for k in n:
		ps["default"][k] = n[k]
	var gp := ScreenGamePlan.new(gg, d.draft)
	App.go(gp)
	await frames(4)
	return gp


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


func _clear_toasts() -> void:
	for tc in App.main._toasts.get_children():
		tc.queue_free()
	await frames(2)


func _cut(gp: ScreenGamePlan) -> Array:
	var out: Array = []
	for t in gp.hero.clipped():
		out.append("hero: " + String(t))
	for t in gp.stand.clipped():
		out.append("stand: " + String(t))
	for id in gp.tracks:
		var tr: DetentTrack = gp.tracks[id]
		if tr.is_visible_in_tree():
			for t in tr.clipped:
				out.append("%s: %s" % [id, String(t)])
	for t in gp.strip.clipped:
		out.append("strip: " + String(t))
	if gp.jf_bar.is_visible_in_tree():
		for t in gp.jf_bar.clipped():
			out.append("jf: " + String(t))
	return out


func _redraw_all(gp: ScreenGamePlan) -> void:
	gp.hero.queue_redraw()
	gp.stand.queue_redraw()
	gp.strip.queue_redraw()
	gp.jf_bar.queue_redraw()
	for id in gp.tracks:
		(gp.tracks[id] as Control).queue_redraw()
	await frames(3)


# ------------------------------------------------------------------ rows
func _fit_state(gp: ScreenGamePlan, v: String, st: String) -> void:
	await _redraw_all(gp)
	var vp := get_viewport().get_visible_rect()
	var vw := vp.size.x
	var outside: Array = []
	var roots: Array = [gp]
	if BottomSheet.is_open():
		roots.append(BottomSheet.current())
	for root in roots:
		for c in (root as Node).find_children("*", "Control", true, false):
			var ctl := c as Control
			if ctl.is_visible_in_tree() and ctl.size.x > 0.0 and not (ctl is ScrollBar):
				var r := ctl.get_global_rect()
				if r.position.x < -0.5 or r.end.x > vw + 0.5:
					outside.append("%s %s" % [ctl.name, str(r)])
	ok(outside.is_empty(), "fit_gp_%s_%s: no control leaves the %d px frame %s" % [v, st, int(vw), str(outside.slice(0, 3))])
	var cut := _cut(gp)
	ok(cut.is_empty(), "fit_gp_%s_%s: no drawn text is cut %s" % [v, st, str(cut)])
	var short: Array = []
	for root in roots:
		for b in (root as Node).find_children("*", "BaseButton", true, false):
			var bb := b as BaseButton
			if bb.is_visible_in_tree() and bb.size.y < float(UI.BTN_H) - 0.5:
				short.append("%s %.0f" % [bb.name, bb.size.y])
	ok(short.is_empty(), "fit_gp_%s_%s: every button is at least 96 px high %s" % [v, st, str(short)])
	ok(_count(gp) <= 120, "build_gp_%s_%s: %d nodes (target 120)" % [v, st, _count(gp)])
	var hr := gp.hero.get_global_rect()
	ok(vp.encloses(hr) and vp.encloses(gp.start_button.get_global_rect()), "build_gp_%s_%s: the expected edge and Start the match are both on screen" % [v, st])


func _build_and_fit(v: String) -> void:
	App.apply_large_text(v == "large")
	await frames(3)
	var gp := await _gp()
	ok(gp.build_count == 1, "build_gp_%s: the screen builds once" % v)
	ok(gp.plan_chip.text == Strings.f("gp.plan_chip", {"name": Strings.t("gp.tab.default")}), "build_gp_%s: the plan chip reads Plan: Default" % v)
	for ph in ["overall", "early", "mid", "late"]:
		gp._set_phase(ph)
		await frames(2)
		var want: Array = ScreenGamePlan.PAGE[ph]
		var shown: Array = []
		for id in GamePlan.SLIDERS:
			if (gp.tracks[id] as Control).is_visible_in_tree():
				shown.append(id)
		if gp.jf_box.is_visible_in_tree():
			shown.append("jf")
		var w2 := want.duplicate()
		w2.sort()
		shown.sort()
		ok(shown == w2 and gp.stand.visible == (ph != "overall"), "build_gp_%s_%s: the page shows %s and its meters" % [v, ph, str(want)])
		await _fit_state(gp, v, ph)
		if ph == "early" and v == "large":    # DECISIONS Q6-2 (c), 0.12.1: the one-line edge card leaves Tempo's slider on screen
			var pr := gp.page_scroll.get_global_rect()
			var tr := (gp.tracks["t"] as Control).get_global_rect()
			var slider_end := tr.position.y + DetentTrack.HEAD_H + DetentTrack.TRACK_H
			ok(gp.hero.size.y <= 80.5 and slider_end <= pr.end.y + 0.5, "fit_gp_large_early: the edge is one line (%.0f px) and the Tempo slider is on screen (ends %.0f, page %.0f)" % [gp.hero.size.y, slider_end, pr.end.y])
	gp._set_tab("behind_early")
	await frames(2)
	ok(gp.off_card.visible and not gp.tracks["l"].visible and gp.coach_button.disabled, "build_gp_%s_behind_off: a trigger plan that is off shows the switch-on card, no controls" % v)
	await _fit_state(gp, v, "behind_off")
	gp._toggle_trigger()
	gp._set_phase("early")
	await frames(2)
	ok(not gp.off_card.visible and gp.note_label.visible and gp.strip.phase("early").get("locked", false), "build_gp_%s_behind: If behind on: the Early node is locked and the page says why" % v)
	await _fit_state(gp, v, "behind")
	gp._set_tab("default")
	gp._set_phase("overall")
	gp._coach()
	await frames(6)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "gp_coach", "build_gp_%s_coach: Coach opens its sheet" % v)
	if gp.coach_apply != null:
		ok(vp_has(gp.coach_apply), "build_gp_%s_coach: Apply is on screen" % v)
	await _fit_state(gp, v, "coach")
	await _close_sheet()
	gp._open_plans()
	await frames(6)
	ok(UI.find_tag("gp.plans.ahead_early.switch") != null and vp_has(UI.find_tag("gp.plans.ahead_early.switch")), "build_gp_%s_plans: the plan sheet shows all three plans with the switches" % v)
	await _fit_state(gp, v, "plans")
	await _close_sheet()


func vp_has(c: Control) -> bool:
	return c != null and get_viewport().get_visible_rect().encloses(c.get_global_rect())


# ---- equivalence: the old screen's logic (copied from the I-16 screen_game_plan.gd), on a plain dictionary
func _old_cur(ps: Dictionary, tab: String) -> Variant:
	if tab == "default":
		return ps["default"]
	for t in ps["triggers"]:
		if t["when"] == tab:
			return t["plan"]
	return null


func _old_do(ps: Dictionary, tab: String, act: Array, sug: Dictionary) -> String:
	var plan: Variant = _old_cur(ps, tab)
	match String(act[0]):
		"tab":
			return String(act[1])
		"value":
			if plan != null:
				plan[act[1]] = act[2]
		"jf":
			if plan != null:
				plan["jf"] = act[1]
		"toggle":
			var found := -1
			for i in ps["triggers"].size():
				if ps["triggers"][i]["when"] == tab:
					found = i
			if found >= 0:
				ps["triggers"].remove_at(found)
			else:
				ps["triggers"].append({"when": tab, "plan": ps["default"].duplicate()})
		"coach":
			if plan != null:
				for k in sug:
					plan[k] = sug[k]
		"reset":
			if plan != null:
				var n := GamePlan.neutral()
				for k in n:
					plan[k] = n[k]
	return tab


## One action through the REAL controls of the screen.
func _real_do(gp: ScreenGamePlan, act: Array) -> void:
	match String(act[0]):
		"tab":
			gp.plan_chip.pressed.emit()
			await frames(2)
			(UI.find_tag("gp.plans." + String(act[1])) as Button).pressed.emit()
			await frames(2)
		"value":
			var id := String(act[1])
			for ph in ScreenGamePlan.PAGE:
				if (ScreenGamePlan.PAGE[ph] as Array).has(id):
					gp.strip._tapped(gp.strip.index_of(ph))
					break
			var t: DetentTrack = gp.tracks[id]
			t._user_set(DetentTrack.snap_index(float(act[2])))
		"jf":
			gp.strip._tapped(gp.strip.index_of("early"))
			gp.jf_bar.press(gp.jf_bar.index_of(String(act[1])))
		"toggle":
			if gp.off_card.visible and int(act[1]) == 0:
				gp.off_button.pressed.emit()
			else:
				gp.plan_chip.pressed.emit()
				await frames(2)
				(UI.find_tag("gp.plans.%s.switch" % gp._tab) as Button).pressed.emit()
				await frames(2)
				await _close_sheet()
		"coach":
			gp.coach_button.pressed.emit()
			await frames(2)
			if gp.coach_apply != null:
				gp.coach_apply.pressed.emit()
			else:
				gp._close_sheet()
			await frames(2)
		"reset":
			gp.reset_button.pressed.emit()
	await frames(1)


func _equivalence() -> void:
	var same := 0
	var n := 30
	var rng := RandomNumberGenerator.new()
	var inert_skipped := 0
	for k in n:
		await _boot(7000 + k * 13)
		var gp := await _gp()
		rng.seed = 424242 + k
		var sug := GamePlan.suggest(gp._ta, gp._tb, MatchRunner.sim_params(), gp.my_side)
		var model: Dictionary = (App.gs.plan_set() as Dictionary).duplicate(true)
		var tab := "default"
		for step in 14:
			var plan: Variant = _old_cur(model, tab)
			var r := rng.randi_range(0, 9)
			var act: Array = []
			if r <= 1:
				act = ["tab", ScreenGamePlan.TABS[rng.randi_range(0, 2)]]
			elif r == 2 and tab != "default":
				act = ["toggle", rng.randi_range(0, 1)]
			elif r <= 6 and plan != null:
				var id := String(GamePlan.SLIDERS[rng.randi_range(0, GamePlan.SLIDERS.size() - 1)])
				act = ["value", id, GamePlan.STEPS[rng.randi_range(0, 4)]]
			elif r == 7 and plan != null:
				act = ["jf", GamePlan.JUNGLE_CHOICES[rng.randi_range(0, 3)]]
			elif r == 8 and plan != null:
				act = ["coach"]
			elif plan != null:
				act = ["reset"]
			else:
				act = ["tab", "default"]
			# a control that is inert in this plan takes no input on the new screen: the generator never picks it (old: no effect)
			if (act[0] == "value" or act[0] == "jf") and tab != "default" and PhaseStrip.effect_kind(String(act[1]) if act[0] == "value" else "jf", ScreenGamePlan.TRIGGER_ACTIVE) == "none":
				inert_skipped += 1
				continue
			tab = _old_do(model, tab, act, sug)
			await _real_do(gp, act)
		await _close_sheet()
		await _clear_toasts()
		if JSON.stringify(model) == JSON.stringify(App.gs.plan_set()) and gp._tab == tab:
			same += 1
		else:
			print("  seq %d: model %s\n          real  %s" % [k, JSON.stringify(model), JSON.stringify(App.gs.plan_set())])
	ok(same == n, "equivalence: %d of %d tap sequences leave the same plan set as the old screen's logic (%d inert picks skipped)" % [same, n, inert_skipped])


func _inert() -> void:
	var gp := await _gp()
	gp._set_tab("behind_early")
	gp._toggle_trigger()
	gp._set_phase("early")
	await frames(2)
	var plan: Dictionary = gp._cur_plan()
	var a: DetentTrack = gp.tracks["a"]
	var before := int(plan["a"])
	a.nudge(1)
	a._on_up()
	gp.jf_bar.press(gp.jf_bar.index_of("top"))
	ok(int(plan["a"]) == before and String(plan["jf"]) == "none" and not a.is_interactive(), "inert: Lane aggression and Jungle focus take no change in If behind")
	ok(a.inert == "full" and UI.plain(a.inert_text) == UI.plain(Strings.t("gp.trigger_locked")) and UI.plain(gp.jf_note.text) == UI.plain(Strings.t("gp.trigger_locked")), "inert: both say they use the Default plan")
	var parts := []
	for id in ["t", "g", "s", "r"]:
		parts.append((gp.tracks[id] as DetentTrack).inert)
	ok(parts == ["partial", "partial", "partial", "partial"] and UI.plain((gp.tracks["t"] as DetentTrack).inert_text) == UI.plain(Strings.t("gp.trigger_late_only")), "inert: Tempo, Fight style, Support and Risk say only part applies (%s)" % str(parts))
	ok((gp.tracks["m"] as DetentTrack).inert == "" and (gp.tracks["l"] as DetentTrack).inert == "", "inert: Mid-game and Late objectives work fully in If behind")
	# the claim is true: with the trigger firing, Lane aggression and Jungle focus in the trigger plan change nothing
	var p := MatchRunner.sim_params()
	var diff := 0
	var fired := 0
	for s in 12:
		var base_set := {"default": GamePlan.neutral(), "triggers": [{"when": "behind_early", "plan": GamePlan.neutral()}, {"when": "ahead_early", "plan": GamePlan.neutral()}]}
		var odd_set: Dictionary = base_set.duplicate(true)
		for t in odd_set["triggers"]:
			t["plan"]["a"] = 100 if s % 2 == 0 else -100
			t["plan"]["jf"] = ["top", "mid_lane", "bot"][s % 3]
		var r1 := GamePlan.simulate(gp._ta, gp._tb, 1000 + s, p, {gp.my_side: base_set})
		var r2 := GamePlan.simulate(gp._ta, gp._tb, 1000 + s, p, {gp.my_side: odd_set})
		if String(r1["plan_used"][gp.my_side]) != "default":
			fired += 1
		if JSON.stringify(r1) != JSON.stringify(r2):
			diff += 1
	ok(diff == 0, "inert: the simulation gives the same result whatever Lane aggression and Jungle focus say in a trigger plan (%d of 12 differ; a trigger fired in %d)" % [diff, fired])


func _undo() -> void:
	var gp := await _gp()
	var ps: Dictionary = App.gs.plan_set()
	gp._set_value("g", 50)
	var before: Dictionary = ps["default"].duplicate()
	gp._coach_apply()
	await frames(2)
	var after: Dictionary = ps["default"].duplicate()
	gp._undo_last()
	ok(after != before and ps["default"] == before, "undo: Undo after Apply puts the plan back")
	gp._set_value("t", -100)
	var b2: Dictionary = ps["default"].duplicate()
	gp._reset()
	ok(GamePlan.is_neutral(ps["default"]), "undo: Reset makes the plan neutral")
	gp._undo_last()
	ok(ps["default"] == b2 and int(gp.tracks["t"].value) == -100, "undo: Undo after Reset puts the plan and the track back")
	var toast_ok := false
	for tc in App.main._toasts.get_children():
		for b in (tc as Node).find_children("*", "Button", true, false):
			toast_ok = toast_ok or UI.plain((b as Button).text) == UI.plain(Strings.t("common.undo"))
	ok(toast_ok, "undo: the toast carries an Undo button")
	gp._coach_apply()
	var plan_now: Dictionary = ps["default"].duplicate()
	gp.go_back()
	await frames(3)
	var left := 0
	for tc in App.main._toasts.get_children():
		if tc.has_meta("gp_undo") and not tc.is_queued_for_deletion():
			left += 1
	ok(left == 0 and ps["default"] == plan_now and not is_instance_valid(gp), "undo: leaving the Game Plan removes its Undo toasts (no Undo can reach the plan from the next screen)")
	await _clear_toasts()


func _inplace() -> void:
	var gp := await _gp()
	var ids_before: Array = []
	for id in GamePlan.SLIDERS:
		ids_before.append((gp.tracks[id] as Object).get_instance_id())
	var hero_id := gp.hero.get_instance_id()
	var us := 0
	var taps := 0
	for i in 50:
		var t0 := Time.get_ticks_usec()
		match i % 7:
			0, 1, 2:
				var id := String(GamePlan.SLIDERS[i % GamePlan.SLIDERS.size()])
				(gp.tracks[id] as DetentTrack)._user_set((i * 3) % 5)
			3:
				gp.strip._tapped(i % 4)
			4:
				gp.jf_bar.press(i % 4)
			5:
				gp._set_tab(ScreenGamePlan.TABS[i % 3])
			6:
				if gp._cur_plan() == null:
					gp._toggle_trigger()
				else:
					gp._reset()
		us += Time.get_ticks_usec() - t0
		taps += 1
		await frames(1)
	var ids_after: Array = []
	for id in GamePlan.SLIDERS:
		ids_after.append((gp.tracks[id] as Object).get_instance_id())
	ok(gp.rebuild_count == 0 and gp.build_count == 1, "inplace_gp: 50 taps, no rebuild (rebuild_count %d, build_count %d, refreshes %d)" % [gp.rebuild_count, gp.build_count, gp.refresh_count])
	ok(ids_after == ids_before and gp.hero.get_instance_id() == hero_id, "inplace_gp: the same tracks and hero after 50 taps")
	var ms := float(us) / float(taps) / 1000.0
	print("  tap cost on this desktop: %.1f ms per tap (old screen baseline 22 ms; a desktop ratio, not a phone number)" % ms)
	ok(ms < 22.0, "inplace_gp: a tap costs %.1f ms here, under the old 22 ms rebuild" % ms)
	await _clear_toasts()


func _events_once() -> void:
	var gp := await _gp()
	_events.clear()
	gp.coach_button.pressed.emit()
	await frames(3)
	ok(_ev("gp:coach_open") == 1, "events: Coach raises gp:coach_open once")
	if gp.coach_apply != null:
		gp.coach_apply.pressed.emit()
		await frames(20)
	ok(_ev("gp:coach_apply") == 1 and _ev("gp:coach_close") == 0 and not BottomSheet.is_open(), "events: Apply raises gp:coach_apply once, no gp:coach_close")
	gp.coach_button.pressed.emit()
	await frames(3)
	await _close_sheet()
	ok(_ev("gp:coach_open") == 2 and _ev("gp:coach_close") == 1, "events: closing the sheet without Apply raises gp:coach_close once")
	ok(App.tutorial._shortcuts.has("gp_coach_apply"), "events: the gp_coach_apply shortcut is registered while the Game Plan is open")
	var ps: Dictionary = App.gs.plan_set()
	gp._reset()
	(App.tutorial._shortcuts["gp_coach_apply"] as Callable).call()
	await frames(2)
	var sug := GamePlan.suggest(gp._ta, gp._tb, MatchRunner.sim_params(), gp.my_side)
	var same := true
	for k in sug:
		same = same and ps["default"][k] == sug[k]
	ok(same and _ev("gp:coach_apply") == 2, "events: the shortcut applies the Coach's plan and raises gp:coach_apply")
	gp.go_back()
	await frames(3)
	ok(not App.tutorial._shortcuts.has("gp_coach_apply"), "events: the shortcut is gone after leaving the screen")
	await _clear_toasts()


func _cb() -> void:
	var gp := await _gp()
	ok(CompKit.cue_of(gp.hero).contains("arrow") and CompKit.cue_of(gp.stand).contains("sign"), "cb_gp: the edge has a sign and an arrow, the meters are centre-zero with signs")
	ok(gp.hero.arrow_of(0.05) == "arrow_up" and gp.hero.arrow_of(-0.05) == "arrow_down" and gp.hero.arrow_of(0.0) == "arrow_flat", "cb_gp: the edge arrow follows the sign")
	gp._set_tab("behind_early")
	gp._toggle_trigger()
	gp._set_phase("early")
	await frames(2)
	ok(CompKit.cue_of(gp.tracks["a"]).contains("lock"), "cb_gp: an inert track is marked by a lock and a hollow thumb (%s)" % CompKit.cue_of(gp.tracks["a"]))
	var locked := true
	for o in gp.jf_bar.options:
		locked = locked and bool(o.get("locked", false))
	ok(locked, "cb_gp: the inert Jungle focus shows a lock on every segment")
	ok(gp.plan_chip.text == Strings.f("gp.plan_chip", {"name": Strings.t("gp.tab.behind_early")}), "cb_gp: the plan on show is named in words on the chip")
	gp._set_tab("default")
	ok(UI.plain(gp.plan_chip.text) == UI.plain(Strings.f("gp.plan_chip_more", {"name": Strings.t("gp.tab.default"), "n": 1})), "cb_gp: a trigger plan that is on shows as +1 on the chip")


func _shown_ok(step: String) -> bool:
	var o := App.tutorial.overlay
	return o != null and is_instance_valid(o) and o.step_id == step and (o.mode == "shown" or o.mode == "fallback")


func _tags() -> void:
	var tg := TutorialGame.start(App.gs)
	App.gs.set_tutorial({"v": 1, "state": "running", "step": "coach_suggest", "game": {"live": true, "n": 1, "plan": {}}})
	App.tutorial.bind()
	App.tutorial.set_game_live(true)
	var gp := await _gp(tg)
	App.tutorial.bind()
	for id in ["gp.coach", "gp.start_match", "gp.edge", "gp.phases", "gp.plan_chip"]:
		ok(UI.find_tag(id) != null and UI.find_tag(id).is_visible_in_tree(), "tags_gp: %s is there" % id)
	ok(await until(func(): return _shown_ok("coach_suggest")) and App.tutorial.overlay.mode == "shown", "tags_gp: step 17 (Coach) finds gp.coach")
	gp.coach_button.pressed.emit()
	await frames(4)
	ok(await until(func(): return App.tutorial.overlay.mode == "shown" and App.tutorial.m.stage == "b") and UI.find_tag("gp.coach_apply") != null, "tags_gp: step 17 stage B finds gp.coach_apply in the sheet")
	if gp.coach_apply != null:
		gp.coach_apply.pressed.emit()
	else:
		gp._close_sheet()
	await frames(20)
	ok(await until(func(): return _shown_ok("start_match")) and App.tutorial.overlay.mode == "shown", "tags_gp: step 18 finds gp.start_match")
	ok(App.tutorial.fallbacks == 0, "tags_gp: no fallback card in steps 17 and 18 (%d)" % App.tutorial.fallbacks)
	gp.start_button.pressed.emit()
	await frames(6)
	ok(_cur() is ScreenMatch and App.tutorial.m.step_id() == "watch", "tags_gp: Start the match starts the tutorial game and moves to step 19")
	TutorialGame.leave(App.gs)
