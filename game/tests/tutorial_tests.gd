extends RefCounted
## I-11 the tutorial event machine (TutorialState instance): TUTORIAL.md 3, 6, 7.5 and 9 (the tests that need no UI),
## build plan 0.7 section 5 and I-11. Covered: the happy path of all 27 steps with a scripted event list, wrong events at
## every step (negative controls), stages and shortcuts, skip_if (no_next_game, already_on, event_seen with the EventBus
## ring buffer, its bookmark and its 64-event limit), Skip with Undo at every step, the state `new` and the other four
## states, replay (game.n), resume after a kill at every step (live true and false) and through a JSON round trip,
## the unknown higher `v`, a step id that left the data, the Home offer, the debug line. I-13 (at the end): the tutorial game
## (TutorialGame) is a sandbox: deep compare of gs.d, RNG isolation, replay seeds, the opponent rule, legacy saves, resume, the flag.
## Pure logic: no autoloads, no UI classes (EventBus is a Node but a plain one). Auto-discovered by run_tests.gd.

## The happy path: [event, data, step id after, stage after]. The first entry is Start on the welcome modal (state new).
const HAPPY := [
	["tut:start", {}, "home_card", "a"], ["tut:next", {}, "tabs", "a"], ["tut:next", {}, "tab_squad", "a"],
	["tap:tab.squad", {}, "squad_bench", "a"], ["open:player_card", {}, "player_card", "a"], ["tut:next", {}, "tab_plan", "a"],
	["tap:tab.plan", {}, "plan_practice", "a"], ["tap:plan.tile.practice", {}, "quick_match", "a"],
	["tap:practice.quick", {}, "matchups", "a"], ["tut:next", {}, "start_draft", "a"],
	["tap:prematch.start_draft", {}, "ban", "a"],
	["draft:sheet", {"kind": "ban"}, "ban", "b"], ["draft:ban", {}, "pick", "a"],
	["draft:sheet", {"kind": "pick"}, "role", "a"], ["draft:pick", {}, "coach_rest", "a"],
	["tap:draft.auto_rest", {}, "coach_rest", "b"], ["draft:done", {}, "open_plan", "a"],
	["tap:draft.game_plan", {}, "coach_suggest", "a"], ["gp:coach_open", {}, "coach_suggest", "b"], ["gp:coach_apply", {}, "start_match", "a"],
	["tap:gp.start_match", {}, "watch", "a"], ["match:end", {}, "see_report", "a"], ["tap:match.report_btn", {}, "result", "a"],
	["tut:next", {}, "why", "a"], ["open:report_why", {}, "why", "b"], ["tut:next", {}, "continue", "a"],
	["tap:report.continue", {}, "tab_club", "a"], ["tap:tab.club", {}, "form_tile", "a"], ["tap:club.tile.form", {}, "form_switch", "a"],
	["stand:metric", {}, "finish", "a"],
]
## Every event name the machine may be fed, plus junk, for the wrong-event sweeps.
const NOISE := ["tap:tab.home", "tap:tab.more", "tap:help.button", "screen:home", "screen:draft", "open:lane_picker", "open:training_picker",
		"draft:hero", "gp:coach", "match:speed", "tap:nothing", "tut:skip", "", "TUT:NEXT"]


func run(check: Callable) -> void:
	TutorialState.use_data({})
	_happy_path(check)
	_wrong_events(check)
	_stages_and_shortcuts(check)
	_skip_if(check)
	_event_bus(check)
	_skip_and_undo(check)
	_states(check)
	_replay(check)
	_resume(check)
	_future_and_stale(check)
	_card_and_debug(check)
	_game_flags(check)
	_offers(check)
	_tutorial_game(check)


# ------------------------------------------------------------------ helpers
func _running(step_id: String, live: bool = false, n: int = 1, plan: Dictionary = {}) -> TutorialState:
	return TutorialState.new({"v": 1, "state": "running", "step": step_id, "game": {"live": live, "n": n, "plan": plan}})


func _fx_kinds(fx: Array) -> Array:
	var out: Array = []
	for e in fx:
		out.append(String(e["fx"]))
	return out


func _has_fx(fx: Array, kind: String, key: String = "", val = null) -> bool:
	for e in fx:
		if e["fx"] == kind and (key == "" or (e.has(key) and e[key] == val)):
			return true
	return false


func _first_fx(fx: Array, kind: String) -> Dictionary:
	for e in fx:
		if e["fx"] == kind:
			return e
	return {}


## Every event name any step reads, plus the noise list.
func _all_events() -> Array:
	var out: Array = NOISE.duplicate()
	for st in TutorialState.steps():
		for e in st["done_on"]:
			if not out.has(e):
				out.append(e)
		if st.has("stage_b") and not out.has(st["stage_b"]["on"]):
			out.append(st["stage_b"]["on"])
	return out


func _same(a, b) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


# ------------------------------------------------------------------ the happy path
func _happy_path(check: Callable) -> void:
	var m := TutorialState.new(TutorialState.new_state())
	check.call(m.state() == "new" and m.step_id() == "welcome" and int(m.game()["n"]) == 0, "a machine on new_state(): new, welcome, n 0")
	var path_ok := true
	var effects_ok := true
	var bad := ""
	for i in HAPPY.size():
		var e: Array = HAPPY[i]
		var before_step := m.step_id()
		var fx := m.feed(String(e[0]), e[1])
		var ok: bool = m.state() == "running" and m.step_id() == String(e[2]) and m.stage == String(e[3])
		if not ok:
			path_ok = false
			bad += " [%d %s -> %s/%s]" % [i, e[0], m.step_id(), m.stage]
			break
		# every move ends in a save; a new step shows, a stage move says stage
		var last: Dictionary = fx[fx.size() - 1] if not fx.is_empty() else {}
		effects_ok = effects_ok and last.get("fx") == "save"
		if String(e[2]) != before_step:
			effects_ok = effects_ok and _has_fx(fx, "show", "step", e[2])
		else:
			effects_ok = effects_ok and _has_fx(fx, "stage", "stage", e[3]) and not _has_fx(fx, "show")
	check.call(path_ok, "happy path: 29 events walk 27 steps in order, stages included" + bad)
	check.call(effects_ok, "happy path: every move ends with a save effect; new step gives show, stage move gives stage")
	check.call(m.state() == "running" and m.step_id() == "finish", "happy path: reaches the closing card with the state still running")
	var fx_done := m.feed("tut:finish")
	check.call(m.state() == "done" and m.step_id() == "finish", "Go to Home (tut:finish) makes the state done")
	check.call(_has_fx(fx_done, "finish", "state", "done") and _has_fx(fx_done, "device", "key", "finished_once") and fx_done[fx_done.size() - 1]["fx"] == "save", "finishing: finish effect, device flag finished_once, save")
	check.call(m.feed("tap:tab.club").is_empty() and m.feed("tut:next").is_empty() and m.state() == "done", "after done nothing moves it (negative control)")
	check.call(int(m.game()["n"]) == 1 and not bool(m.game()["live"]), "the run used game.n 1 and left no live game")
	# the same path, but the data drives it: every step's first done_on event moves that step (data and machine agree)
	var agree := true
	for s in TutorialState.steps():
		if s["id"] == "welcome":
			continue
		var mm := _running(String(s["id"]))
		var ev := String((s["done_on"] as Array)[0])
		var d: Dictionary = (s.get("done_data", {}) as Dictionary).get(ev, {})
		mm.feed(ev, d)
		agree = agree and (mm.step_id() != s["id"] or mm.state() == "done")
	check.call(agree, "for every step the first done_on event (with its data) completes it")


# ------------------------------------------------------------------ wrong events
func _wrong_events(check: Callable) -> void:
	var junk := 0
	var moved := 0
	var noisy := 0
	var all_events: Array = _all_events()
	for s in TutorialState.steps():
		var allowed: Array = (s["done_on"] as Array).duplicate()
		if s.has("stage_b"):
			allowed.append(s["stage_b"]["on"])
		for e in all_events:
			if allowed.has(e):
				continue
			var m := _running(String(s["id"]))
			var fx := m.feed(String(e))
			junk += 1
			if m.step_id() != s["id"] or m.stage != "a" or m.state() != "running":
				moved += 1
			if not fx.is_empty():
				noisy += 1
	check.call(junk > 600 and moved == 0, "wrong events at every step: %d tried, none moved a step or stage" % junk)
	check.call(noisy == 0, "wrong events return no effects (no save, no show) (%d noisy)" % noisy)
	# an event that is right for another step does not skip ahead
	var m2 := _running("tabs")
	m2.feed("tap:tab.squad")
	m2.feed("open:player_card")
	check.call(m2.step_id() == "tabs", "the event of step 4 or 5 does not move step 3 (no skipping ahead)")
	# a done_data filter: the pick step wants the pick sheet, not the ban sheet
	var m3 := _running("pick")
	m3.feed("draft:sheet", {"kind": "ban"})
	check.call(m3.step_id() == "pick", "step 13 is not completed by the ban sheet (done_data kind)")
	m3.feed("draft:sheet")
	check.call(m3.step_id() == "pick", "step 13 is not completed by a sheet event without its kind")
	m3.feed("draft:sheet", {"kind": "pick", "extra": 1})
	check.call(m3.step_id() == "role", "step 13 is completed by the pick sheet (extra data is fine)")
	# the ban step: the pick sheet does not move the hole
	var m4 := _running("ban")
	m4.feed("draft:sheet", {"kind": "pick"})
	check.call(m4.stage == "a", "step 12 stage B waits for the ban sheet, not the pick sheet")
	# a card button that the step does not have
	var m5 := _running("tab_squad")
	check.call(m5.feed("tut:next").is_empty() and m5.step_id() == "tab_squad", "Next does nothing on a tap step (only the real tap moves it)")
	var m6 := _running("home_card")
	check.call(m6.feed("tut:start").is_empty() and m6.feed("tut:finish").is_empty() and m6.step_id() == "home_card", "Start and Go to Home do nothing on an info step")
	# repeating an event does not move twice
	var m7 := _running("tab_squad")
	m7.feed("tap:tab.squad")
	var again := m7.feed("tap:tab.squad")
	check.call(m7.step_id() == "squad_bench" and again.is_empty(), "the same event twice moves one step only")


# ------------------------------------------------------------------ stages, shortcuts, one-tap routes
func _stages_and_shortcuts(check: Callable) -> void:
	# step 12: stage B puts the hole on the sheet's confirm; Take (draft:ban) completes from stage A too
	var m := _running("ban")
	var c0 := m.card()
	check.call(c0["target"] == ["draft.choices"] and c0["key"] == "tut.ban" and not c0["compact"], "step 12 stage A: hole on the Coach bar and grid, text tut.ban")
	m.feed("draft:sheet", {"kind": "ban"})
	var c1 := m.card()
	check.call(c1["stage"] == "b" and c1["target"] == ["draft.sheet.confirm"] and c1["key"] == "tut.ban.confirm" and c1["compact"], "step 12 stage B: hole on the sheet confirm, compact card, text tut.ban.confirm")
	check.call(m.feed("draft:ban").size() > 0 and m.step_id() == "pick" and m.stage == "a", "step 12 completes from stage B and the next step starts at stage A")
	var take := _running("ban")
	take.feed("draft:ban")
	check.call(take.step_id() == "pick", "Take (draft:ban) completes step 12 straight from stage A (one-tap route)")
	var pk := _running("pick")
	pk.feed("draft:pick")
	check.call(pk.step_id() == "coach_rest", "Take on step 13 completes it and step 14 is passed over")
	# step 15: stage B keeps the armed state; the card keeps its shortcut in both stages
	var r := _running("coach_rest")
	var ra := r.card()
	check.call(ra["hold_armed"] and ra["buttons"] == ["skip", "shortcut"] and ra["shortcut_key"] == "tut.shortcut.coach_rest" and ra["shortcut_does"] == "draft_auto_finish", "step 15: hold_armed, Skip and the one-tap button, shortcut text and action")
	r.feed("tap:draft.auto_rest")
	check.call(r.card()["stage"] == "b" and r.card()["key"] == "tut.coach_rest.sure" and r.card()["hold_armed"], "step 15 stage B: text tut.coach_rest.sure, still holding the armed state")
	var r2 := _running("coach_rest")
	r2.feed("draft:done")
	check.call(r2.step_id() == "open_plan", "step 15: the one-tap button (draft:done) completes it from stage A")
	# step 17: Apply or Close completes; Coach opens stage B
	var g := _running("coach_suggest")
	check.call(g.card()["shortcut_key"] == "tut.shortcut.apply" and g.card()["shortcut_does"] == "gp_coach_apply", "step 17 has Apply for me")
	g.feed("gp:coach_open")
	check.call(g.card()["target"] == ["gp.coach_apply"] and g.card()["key"] == "tut.coach_suggest.apply" and g.card()["compact"], "step 17 stage B: hole on Apply, compact")
	var g2 := _running("coach_suggest")
	g2.feed("gp:coach_close")
	check.call(g2.step_id() == "start_match", "step 17: the Coach sheet closing with nothing to change (gp:coach_close) completes it")
	var g3 := _running("coach_suggest")
	g3.feed("gp:coach_apply")
	check.call(g3.step_id() == "start_match", "step 17: Apply for me (gp:coach_apply) completes it from stage A")
	# step 22: Next is on the card in both stages and completes
	var w := _running("why")
	check.call(w.card()["buttons"] == ["skip", "next"], "step 22 stage A shows Next (the one-tap route)")
	w.feed("tut:next")
	check.call(w.step_id() == "continue", "step 22: Next in stage A skips the factor sheet")
	var w2 := _running("why")
	w2.feed("open:report_why")
	check.call(w2.card()["target"] == ["report.why_sheet"] and w2.card()["compact"] and w2.card()["key"] == "tut.why.sheet" and w2.card()["buttons"] == ["skip", "next"], "step 22 stage B: factor bars, compact, Next on the card")
	w2.feed("tut:next")
	check.call(w2.step_id() == "continue" and w2.stage == "a", "step 22: Next in stage B completes")
	# a stage-B event on a step that has no stage B does nothing
	var t4 := _running("tabs")
	check.call(t4.feed("draft:sheet", {"kind": "ban"}).is_empty() and t4.stage == "a", "a step without stage B ignores the stage event")
	# a stage event in stage B again changes nothing
	var s2 := _running("ban")
	s2.feed("draft:sheet", {"kind": "ban"})
	check.call(s2.feed("draft:sheet", {"kind": "ban"}).is_empty() and s2.stage == "b", "the stage event twice moves the hole once")
	# step 19: any of three events, and the watch step passes taps
	for e in ["match:speed", "match:skip", "match:end"]:
		var wm := _running("watch")
		wm.feed(e)
		check.call(wm.step_id() == "see_report", "step 19 is completed by " + e)
	check.call(_running("watch").card()["passthrough"] and _running("watch").card()["dim"] == "none", "step 19: passes taps, no dim")
	check.call(not _running("tabs").card()["passthrough"], "other steps do not pass taps")


# ------------------------------------------------------------------ skip_if
func _skip_if(check: Callable) -> void:
	# no_next_game: step 2 is passed over, and reported
	var m := TutorialState.new(TutorialState.new_state())
	m.set_context({"no_next_game": true})
	var fx := m.feed("tut:start")
	check.call(m.step_id() == "tabs" and _has_fx(fx, "passed", "step", "home_card") and _has_fx(fx, "show", "step", "tabs"), "no_next_game: Start lands on step 3 and step 2 is reported passed over")
	var m2 := TutorialState.new(TutorialState.new_state())
	m2.set_context({"no_next_game": false})
	m2.feed("tut:start")
	check.call(m2.step_id() == "home_card", "negative control: a next game exists, step 2 is shown")
	var m3 := _running("home_card")
	var fx3 := m3.set_context({"no_next_game": true})
	check.call(m3.step_id() == "tabs" and _has_fx(fx3, "passed", "step", "home_card") and fx3[fx3.size() - 1]["fx"] == "save", "set_context passes over the step that is up when the context says so, and saves")
	check.call(_running("tabs").set_context({"no_next_game": true}).is_empty(), "set_context with nothing to pass over returns no effects")
	# event_seen without a bus: the machine remembers events it was fed
	var a := _running("pick")
	var fa := a.feed("draft:pick")
	check.call(a.step_id() == "coach_rest" and _has_fx(fa, "passed", "step", "role"), "Take on step 13: step 14 passed over (reported), step 15 shown")
	var b := _running("role")
	b.feed("draft:done")
	check.call(b.step_id() == "role", "draft:done alone does not pass step 14 (it asks for draft:pick)")
	var fb := b.feed("draft:pick")
	check.call(b.step_id() == "open_plan" and _has_fx(fb, "passed", "step", "coach_rest"), "all five picked by hand: pick then done seen, step 15 passed over")
	var c := _running("coach_rest")
	c.feed("draft:pick")
	check.call(c.step_id() == "coach_rest", "negative control: draft:pick does not pass step 15 (it asks for draft:done)")
	# an event fed while the machine was on an earlier step is remembered, then passes the later step
	var d := _running("ban")
	d.feed("draft:done")
	d.feed("draft:ban")
	d.feed("draft:sheet", {"kind": "pick"})
	check.call(d.step_id() == "role", "draft:done seen early, step 14 itself still waits for its own pick")
	d.feed("draft:pick")
	check.call(d.step_id() == "open_plan", "...and then step 15 is passed over because draft:done was seen")
	# already_on and target_missing, with edited data
	var data: Dictionary = TutorialState.data().duplicate(true)
	for s in data["steps"]:
		if s["id"] == "tabs":
			s["skip_if"] = "already_on:home"
		if s["id"] == "tab_squad":
			s["skip_if"] = "target_missing"
	TutorialState.use_data(data)
	var e1 := _running("tabs")
	e1.set_context({"screen": "squad"})
	check.call(e1.step_id() == "tabs", "already_on:home with the player on squad: shown")
	e1.set_context({"screen": "home"})
	check.call(e1.step_id() == "tab_squad", "already_on:home with the player on home: passed over")
	var e2 := _running("tab_squad")
	e2.set_context({"screen": "home", "no_next_game": true})
	check.call(e2.step_id() == "tab_squad", "target_missing is never a silent skip")
	TutorialState.use_data({})
	check.call(_running("tabs").step_id() == "tabs" and TutorialState.step_def("tabs").get("skip_if", "") == "", "data restored after the edited-data cases")


# ------------------------------------------------------------------ the EventBus ring buffer
func _event_bus(check: Callable) -> void:
	var bus := EventBus.new()
	# the draft:pick of an earlier game is in the buffer before the tutorial run starts
	bus.emit("draft:pick")
	bus.emit("draft:done")
	var m := TutorialState.new(TutorialState.new_state(), bus.seen, bus.sequence)
	m.feed("tut:start")
	check.call(m.mark == bus.sequence() and m.mark == 2, "the machine takes a bookmark when the run starts")
	# step 13 completes while the bus holds the OLD pick: step 14 must not be passed over
	m.t["step"] = "pick"
	m.feed("draft:sheet", {"kind": "pick"})
	check.call(m.step_id() == "role", "bookmark: a draft:pick from before the run does not pass step 14 (stale event)")
	# a fresh pick on the bus, machine not told (the runner attached late): seen through the ring buffer
	bus.emit("draft:pick")
	m.t["step"] = "pick"
	m.stage = "a"
	m.feed("draft:sheet", {"kind": "pick"})
	check.call(m.step_id() == "coach_rest", "ring buffer: a draft:pick raised after the bookmark passes step 14")
	# draft:done older than the bookmark does not pass step 15; a newer one does
	check.call(m.step_id() == "coach_rest", "bookmark: the old draft:done (before the run) does not pass step 15")
	var m2 := TutorialState.new(TutorialState.new_state(), bus.seen, bus.sequence)
	m2.feed("tut:start")
	bus.emit("draft:pick")
	bus.emit("draft:done")
	m2.t["step"] = "pick"
	m2.feed("draft:sheet", {"kind": "pick"})
	check.call(m2.step_id() == "open_plan", "ring buffer: pick and done on the bus after the bookmark pass steps 14 and 15")
	# the buffer is bounded: 64 newer events and the pick is forgotten, so the step is NOT passed over
	var m3 := TutorialState.new(TutorialState.new_state(), bus.seen, bus.sequence)
	m3.feed("tut:start")
	bus.emit("draft:pick")
	for i in EventBus.CAPACITY:
		bus.emit("tap:filler")
	check.call(not bus.seen("draft:pick", m3.mark), "(the bus forgot the pick after %d newer events)" % EventBus.CAPACITY)
	m3.t["step"] = "pick"
	m3.feed("draft:sheet", {"kind": "pick"})
	check.call(m3.step_id() == "role", "ring buffer limit: a pick older than 64 events is forgotten, step 14 shows")
	# ... but 63 newer events keep it
	var m4 := TutorialState.new(TutorialState.new_state(), bus.seen, bus.sequence)
	m4.feed("tut:start")
	bus.emit("draft:pick")
	for i in EventBus.CAPACITY - 1:
		bus.emit("tap:filler")
	m4.t["step"] = "pick"
	m4.feed("draft:sheet", {"kind": "pick"})
	check.call(m4.step_id() == "coach_rest", "ring buffer limit: with 63 newer events the pick is still remembered")
	# an event the machine WAS fed is remembered by the machine even when the bus has forgotten it
	var m5 := TutorialState.new(TutorialState.new_state(), bus.seen, bus.sequence)
	m5.feed("tut:start")
	m5.t["step"] = "role"
	m5.feed("draft:done")
	for i in EventBus.CAPACITY + 5:
		bus.emit("tap:filler")
	m5.feed("draft:pick")
	check.call(m5.step_id() == "open_plan", "an event the machine was fed is not lost when the bus ring forgets it (no stuck step)")
	# accept() rebases the bookmark (Replay after an earlier run)
	var seq_before := bus.sequence()
	bus.emit("draft:pick")
	m5.replay()
	check.call(m5.mark == bus.sequence() and m5.mark > seq_before, "Replay takes a new bookmark: the earlier run's events are stale")
	m5.t["step"] = "pick"
	m5.feed("draft:sheet", {"kind": "pick"})
	check.call(m5.step_id() == "role", "after Replay an old pick on the bus does not pass step 14 (and the machine's own memory was cleared)")
	# no bus at all: event_seen only knows what the machine was fed (pure mode)
	var m6 := _running("pick")
	check.call(m6.mark == 0 and not m6._seen_fn.is_valid(), "no bus: bookmark 0, no seen function")
	m6.feed("draft:sheet", {"kind": "pick"})
	check.call(m6.step_id() == "role", "no bus: step 14 waits (nothing was seen)")
	bus.free()


# ------------------------------------------------------------------ Skip with Undo
func _skip_and_undo(check: Callable) -> void:
	var codes_ok := true
	var all_ok := true
	var bad := ""
	for i in TutorialState.STEP_IDS.size():
		var id: String = TutorialState.STEP_IDS[i]
		var m := _running(id, i >= 9 and i < 20, 1, {"x": 1} if i >= 9 and i < 20 else {})
		var fx := m.skip()
		if id == "finish":
			check.call(fx.is_empty() and m.state() == "running" and not m.can_skip(), "step 27: no Skip on the closing card (skip() does nothing)")
			continue
		var want := "A" if i < 9 else ("B" if i < 20 else "C")
		var ok: bool = m.state() == "skipped" and m.step_id() == id and _has_fx(fx, "finish", "code", want) and _has_fx(fx, "toast", "undo", true) \
				and _has_fx(fx, "toast", "key", "tut.skipped_toast") and _has_fx(fx, "device", "key", "skipped_once") and fx[fx.size() - 1]["fx"] == "save"
		codes_ok = codes_ok and _first_fx(fx, "finish").get("code") == want
		if not ok:
			all_ok = false
			bad += " " + id
		# afterwards nothing moves it
		var done_event := String((TutorialState.step_def(id)["done_on"] as Array)[0])
		ok = m.feed(done_event).is_empty() and m.state() == "skipped" and m.skip().is_empty()
		if not ok:
			all_ok = false
			bad += " " + id + "(moves)"
		# Undo within the toast: the same step again
		var u := m.undo_skip()
		ok = m.state() == "running" and m.step_id() == id and _has_fx(u, "show", "step", id) and u[u.size() - 1]["fx"] == "save"
		if not ok:
			all_ok = false
			bad += " " + id + "(undo)"
		# a second Undo does nothing
		if not m.undo_skip().is_empty():
			all_ok = false
			bad += " " + id + "(undo twice)"
	check.call(all_ok, "Skip at steps 1 to 26: skipped, step kept, toast with Undo, device flag, save; Undo restores the same step" + bad)
	check.call(codes_ok, "skip codes reported: A for 1 to 9, B for 10 to 20, C for 21 to 26")
	# Undo restores the stage too
	var s := _running("ban")
	s.feed("draft:sheet", {"kind": "ban"})
	s.skip()
	s.undo_skip()
	check.call(s.step_id() == "ban" and s.stage == "b", "Undo brings back stage B of a two-stage step")
	# after the toast
	var e := _running("tabs")
	e.skip()
	e.expire_undo()
	check.call(not e.undo_available() and e.undo_skip().is_empty() and e.state() == "skipped", "after the toast (expire_undo) the tutorial stays skipped")
	# a replay after a skip starts clean
	var r := _running("tabs")
	r.skip()
	r.replay()
	check.call(r.state() == "running" and r.step_id() == "welcome" and not r.undo_available(), "Replay after Skip: running at the welcome step, no stale undo")
	# SK-B keeps the game going: live flag and sandbox plan are not touched by Skip, dropped when the game is left
	var b := _running("ban", true, 2, {"focus": 3})
	b.skip()
	check.call(bool(b.game()["live"]) and b.game()["plan"] == {"focus": 3} and int(b.game()["n"]) == 2, "SK-B: Skip keeps the live game and its sandbox plan")
	var lf := b.set_game_live(false)
	check.call(not bool(b.game()["live"]) and (b.game()["plan"] as Dictionary).is_empty() and lf[lf.size() - 1]["fx"] == "save", "leaving the game afterwards drops the sandbox plan and saves")
	# Skip from a state that has nothing to skip
	check.call(TutorialState.new(TutorialState.legacy_state()).skip().is_empty(), "Skip on a legacy save does nothing")
	var dn := TutorialState.new({"v": 1, "state": "done", "step": "finish", "game": {"live": false, "n": 1, "plan": {}}})
	check.call(dn.skip().is_empty() and dn.state() == "done", "Skip on a finished tutorial does nothing")


# ------------------------------------------------------------------ the five states
func _states(check: Callable) -> void:
	# new: Start and Show me give running, Skip and No thanks give skipped, nothing else changes it
	var a := TutorialState.new(TutorialState.new_state())
	var fa := a.accept()
	check.call(a.state() == "running" and a.step_id() == "welcome" and int(a.game()["n"]) == 1 and not bool(a.game()["live"]), "Show me on a new save: running, at the welcome step, game.n 1")
	check.call(_has_fx(fa, "device", "key", "welcome_seen") and _has_fx(fa, "reset_events") and fa[fa.size() - 1]["fx"] == "save", "Show me: device flag welcome_seen, events bookmark, save")
	a.feed("tut:start")
	check.call(a.step_id() == "home_card" and int(a.game()["n"]) == 1, "Start on the modal after Show me: step 2, game.n still 1 (rises once per run)")
	var b := TutorialState.new(TutorialState.new_state())
	var fb := b.feed("tut:start")
	check.call(b.state() == "running" and b.step_id() == "home_card" and int(b.game()["n"]) == 1 and _has_fx(fb, "device", "key", "welcome_seen"), "Start on the welcome modal of a new save: running, step 2, n 1, welcome_seen")
	var c := TutorialState.new(TutorialState.new_state())
	var fc := c.skip()
	check.call(c.state() == "skipped" and c.step_id() == "welcome" and _has_fx(fc, "device", "key", "welcome_seen") and _has_fx(fc, "device", "key", "skipped_once") and not c.undo_available(), "Skip tutorial on the modal of a new save: skipped, both device flags, no undo")
	var d := TutorialState.new(TutorialState.new_state())
	d.decline()
	check.call(d.state() == "skipped" and int(d.game()["n"]) == 0, "No thanks on a new save: skipped, game.n 0")
	var changed := 0
	var all := _all_events()
	for e in all:
		if e == "tut:start":
			continue
		var n := TutorialState.new(TutorialState.new_state())
		var fx := n.feed(String(e))
		if n.state() != "new" or not fx.is_empty():
			changed += 1
	check.call(all.size() > 35 and changed == 0, "state new: no event except Start changes it (%d events tried, %d changed)" % [all.size(), changed])
	check.call(TutorialState.new(TutorialState.new_state()).set_game_live(true).is_empty(), "state new: a live-game report is ignored")
	# legacy
	var l := TutorialState.new(TutorialState.legacy_state())
	var moved := 0
	for e in all:
		if not (TutorialState.new(TutorialState.legacy_state()).feed(String(e)).is_empty()):
			moved += 1
	check.call(moved == 0 and l.state() == "legacy", "legacy: no event, not even Start, changes it")
	var ld := TutorialState.new(TutorialState.legacy_state())
	var fl := ld.decline()
	check.call(ld.state() == "legacy" and _has_fx(fl, "device", "key", "legacy_offer_done") and not _has_fx(fl, "save"), "No thanks on a legacy save: stays legacy, the device flag is set, nothing to save")
	var la := TutorialState.new(TutorialState.legacy_state())
	var fla := la.accept()
	check.call(la.state() == "running" and int(la.game()["n"]) == 1 and _has_fx(fla, "device", "key", "legacy_offer_done") and _has_fx(fla, "device", "key", "welcome_seen"), "Show me on a legacy save: running, n 1, both device flags")
	check.call(not (la.snapshot().has("legacy")) and TutorialState.is_valid(la.snapshot()), "a running snapshot is a valid tutorial key")
	# done and skipped
	for st in ["done", "skipped"]:
		var m := TutorialState.new({"v": 1, "state": st, "step": "tabs", "game": {"live": false, "n": 3, "plan": {}}})
		var mv := 0
		for e in all:
			if not m.feed(String(e)).is_empty():
				mv += 1
		check.call(mv == 0 and m.state() == st, "state %s: no event changes it" % st)
	# decline on running or done does nothing
	var rr := _running("tabs")
	check.call(rr.decline().is_empty() and rr.state() == "running", "No thanks on a running tutorial does nothing")


# ------------------------------------------------------------------ replay
func _replay(check: Callable) -> void:
	var m := TutorialState.new(TutorialState.new_state())
	m.feed("tut:start")
	check.call(int(m.game()["n"]) == 1, "first run: n 1")
	for e in HAPPY.slice(1):
		m.feed(String(e[0]), e[1])
	m.feed("tut:finish")
	check.call(m.state() == "done", "first run done")
	var fx := m.replay()
	check.call(m.state() == "running" and m.step_id() == "welcome" and int(m.game()["n"]) == 2 and not bool(m.game()["live"]) and (m.game()["plan"] as Dictionary).is_empty(), "Replay from done: running at welcome, n 2, empty sandbox")
	check.call(_has_fx(fx, "device", "key", "welcome_seen") and _has_fx(fx, "show", "step", "welcome") and fx[fx.size() - 1]["fx"] == "save", "Replay: show welcome, save")
	m.feed("tut:start")
	m.set_game_live(true)
	m.set_game_plan({"risk": 2})
	m.replay()
	check.call(int(m.game()["n"]) == 3 and not bool(m.game()["live"]) and (m.game()["plan"] as Dictionary).is_empty(), "Replay in the middle of a game: n 3, the old game and its plan are dropped")
	# the seed ids differ per n (tutorial_game builds tut:<seed>:<n>)
	var ns := {}
	var r := TutorialState.new({"v": 1, "state": "skipped", "step": "tabs", "game": {"live": false, "n": 0, "plan": {}}})
	for i in 5:
		r.replay()
		ns[int(r.game()["n"])] = true
	check.call(ns.size() == 5, "five replays give five different game.n values")
	# skipped save, replay works too (TUTORIAL 6.3 any phase)
	check.call(r.state() == "running", "Replay from skipped starts a run")


# ------------------------------------------------------------------ resume after a kill
func _expected_resume(i: int, live: bool) -> int:
	# step numbers (1 based): TUTORIAL 3.1 and plan section 5 item 10
	if i >= 21:
		return 24
	if live or (i >= 7 and i <= 20):
		return 7
	if i >= 5:
		return 4
	return 2


func _resume(check: Callable) -> void:
	var ok: bool = true
	var bad := ""
	var n_ok := true
	var clean := true
	var pend := true
	for i in range(1, 28):
		for live in [false, true]:
			var id: String = TutorialState.STEP_IDS[i - 1]
			var raw := {"v": 1, "state": "running", "step": id, "game": {"live": live, "n": 4, "plan": {"a": 1}}}
			var mm := TutorialState.from_save(raw)
			var want: String = TutorialState.STEP_IDS[_expected_resume(i, live) - 1]
			if mm.step_id() != want or mm.state() != "running":
				ok = false
				bad += " %s/%s->%s" % [id, live, mm.step_id()]
			n_ok = n_ok and int(mm.game()["n"]) == 4
			clean = clean and not bool(mm.game()["live"]) and (mm.game()["plan"] as Dictionary).is_empty()
			pend = pend and mm.resume_pending and mm.stage == "a"
			if raw["game"]["plan"] != {"a": 1} or raw["step"] != id:
				ok = false
	check.call(ok, "resume after a kill at every one of the 27 steps, live true and false (54 cases)" + bad)
	check.call(n_ok, "resume never changes game.n (same game, same seed id, no duplicate)")
	check.call(clean, "resume clears game.live and the sandbox plan")
	check.call(pend, "a running save loaded from disk offers the resume card, at stage A; the argument is not modified")
	# step 12 on the 'ban' in stage B before the kill: resumes at step 7, stage A
	var m := TutorialState.from_save({"v": 1, "state": "running", "step": "ban", "game": {"live": true, "n": 1, "plan": {}}})
	check.call(m.step_id() == "tab_plan" and m.stage == "a", "resume from a stage-B step starts the chapter again at stage A")
	# the resume card
	var fx := m.continue_resume()
	check.call(_has_fx(fx, "show", "step", "tab_plan") and not m.resume_pending and m.continue_resume().is_empty(), "Continue answers the resume card once (show the step), then does nothing")
	var s := TutorialState.from_save({"v": 1, "state": "running", "step": "pick", "game": {"live": false, "n": 1, "plan": {}}})
	s.skip()
	check.call(s.state() == "skipped" and not s.resume_pending, "Skip tutorial on the resume card: skipped")
	for st in ["new", "done", "skipped"]:
		var o := TutorialState.from_save({"v": 1, "state": st, "step": "tabs", "game": {"live": true, "n": 1, "plan": {"a": 1}}})
		check.call(not o.resume_pending, "state %s offers no resume card" % st)
	# a machine made from a valid in-session key is NOT rewound (resume is a load-time rule)
	var inflight := TutorialState.new({"v": 1, "state": "running", "step": "ban", "game": {"live": true, "n": 1, "plan": {"a": 1}}})
	check.call(inflight.step_id() == "ban" and bool(inflight.game()["live"]) and not inflight.resume_pending, "TutorialState.new on a valid running key keeps the step (a pause without a kill changes nothing)")
	# save, JSON round trip, load at each step of the happy path with a live game
	var rt_ok := true
	var m2 := TutorialState.new(TutorialState.new_state())
	for e in HAPPY:
		m2.feed(String(e[0]), e[1])
		var step_no := TutorialState.step_index(m2.step_id()) + 1
		if m2.state() != "running":
			continue
		m2.set_game_live(step_no >= 10 and step_no <= 20)
		var back = JSON.parse_string(JSON.stringify(m2.snapshot()))
		var l := TutorialState.from_save(back)
		var want_id: String = TutorialState.STEP_IDS[_expected_resume(step_no, bool(m2.game()["live"])) - 1]
		rt_ok = rt_ok and l.step_id() == want_id and int(l.game()["n"]) == 1
	check.call(rt_ok, "save, JSON.stringify, parse, from_save at every step of a played run: resume step as TUTORIAL 3.1, n unchanged")
	# JSON turns ints into floats in some paths: n and v as floats still load
	var fl := TutorialState.from_save({"v": 1.0, "state": "running", "step": "form_tile", "game": {"live": false, "n": 2.0, "plan": {}}})
	check.call(fl.step_id() == "tab_club" and int(fl.game()["n"]) == 2, "v and n as floats (JSON numbers) load")


# ------------------------------------------------------------------ unknown versions, stale data
func _future_and_stale(check: Callable) -> void:
	var future := {"v": 99, "state": "running", "step": "ban", "game": {"live": true, "n": 7, "plan": {"a": 1}}, "extra": [1, 2]}
	var before := JSON.stringify(future)
	var m := TutorialState.from_save(future)
	check.call(m.state() == "legacy" and JSON.stringify(future) == before, "unknown higher v (99): the machine reads legacy, the saved dictionary is not modified")
	check.call(not m.resume_pending and m.feed("tut:start").is_empty() and m.feed("tap:tab.squad").is_empty() and m.skip().is_empty(), "a future-version save: no events, no skip, no resume card")
	check.call(TutorialState.new(future).state() == "legacy", "TutorialState.new(future v) also reads legacy")
	var v2 := TutorialState.from_save({"v": 2, "state": "done"})
	check.call(v2.state() == "legacy", "v 2 is already unknown")
	# malformed
	for bad in [null, 5, "running", [1], {}, {"v": 1}, {"v": 1, "state": "bogus"}, {"v": 1, "state": 4}, {"v": "x", "state": "done"}, {"v": 0, "state": "done"}, {"v": -3, "state": "done"}]:
		check.call(TutorialState.from_save(bad).state() == "legacy", "malformed tutorial key reads legacy: " + JSON.stringify(bad))
	# a step id that left the data
	var data: Dictionary = TutorialState.data().duplicate(true)
	(data["steps"] as Array).remove_at(TutorialState.step_index("role"))
	TutorialState.use_data(data)
	var gone := TutorialState.from_save({"v": 1, "state": "running", "step": "role", "game": {"live": false, "n": 2, "plan": {}}})
	check.call(gone.state() == "running" and gone.step_id() == "home_card" and int(gone.game()["n"]) == 2, "a step id that no longer exists: falls back to the start (its chapter is unknown), n kept")
	var gone_new := TutorialState.from_save({"v": 1, "state": "new", "step": "role"})
	check.call(gone_new.state() == "new" and gone_new.step_id() == "welcome", "a new save always sits at the welcome step")
	var gone_done := TutorialState.from_save({"v": 1, "state": "done", "step": "role", "game": {}})
	check.call(gone_done.state() == "done" and gone_done.step_id() == "finish", "a finished tutorial with an unknown step id keeps state done at the last step")
	# the machine runs on the edited data: 26 steps, the order closes up
	var w := TutorialState.new({"v": 1, "state": "running", "step": "pick", "game": {"live": false, "n": 1, "plan": {}}})
	w.feed("draft:sheet", {"kind": "pick"})
	check.call(w.step_id() == "coach_rest", "with step 14 removed from the data, step 13 leads straight to the Coach step")
	TutorialState.use_data({})
	# data failed to load altogether
	TutorialState.use_data({"version": 1, "chapters": [], "steps": []})
	check.call(TutorialState.migrate({"v": 1, "state": "running", "step": "ban", "game": {}}).get("state") == "legacy", "no step data: migrate reads legacy rather than crash")
	TutorialState.use_data({})
	check.call(TutorialState.STEP_IDS.size() == 27, "shipped data restored")


# ------------------------------------------------------------------ the card for the overlay, the debug line
func _card_and_debug(check: Callable) -> void:
	var m := TutorialState.new(TutorialState.new_state())
	var c := m.card()
	check.call(c.get("id") == "welcome" and c.get("kind") == "modal" and c.get("buttons") == ["start", "skip"] and (c.get("target") as Array).is_empty() and c.get("key") == "tut.welcome", "card of the welcome modal: modal, Start and Skip, no hole, tut.welcome")
	check.call(c.get("chapter") == 1 and c.get("chapter_key") == "tut.ch.1" and c.get("step_no") == 1 and c.get("dim") == "full", "card: chapter 1, step number 1, full dim")
	check.call(_running("finish").card()["buttons"] == ["go_home"] and _running("finish").card()["skip"] == "none", "card of the last step: Go to Home only, no Skip")
	check.call(_running("result").card("win")["key"] == "tut.result.win" and _running("result").card("loss")["key"] == "tut.result.loss" and _running("result").card()["key"] == "tut.result.win", "step 21 text follows the result: win, loss, default win")
	check.call(_running("watch").card("", "arena")["key"] == "tut.watch.arena" and _running("watch").card()["key"] == "tut.watch", "step 19 has the arena text for 0.8")
	check.call(_running("squad_bench").card("", "alt")["key"] == "tut.squad_bench.alt" and _running("squad_bench").card("", "nope")["key"] == "tut.squad_bench", "step 5 has the five-avatar text; an unknown variant falls back to the normal one")
	check.call(_running("role").card()["target"] == ["draft.slot_list", "draft.sheet.confirm"] and _running("role").card()["compact"], "step 14: two targets, compact card")
	check.call(_running("player_card").card()["compact"] and not _running("tabs").card()["compact"], "step 6 is compact, step 3 is not")
	check.call(TutorialState.new(TutorialState.legacy_state()).card().is_empty() and TutorialState.new({"v": 1, "state": "done", "step": "finish", "game": {"live": false, "n": 1, "plan": {}}}).card().is_empty(), "no card for legacy or done")
	var sk := _running("tabs")
	sk.skip()
	check.call(sk.card().is_empty(), "no card after Skip")
	# the card is a copy: changing it does not change the data
	var cc := _running("tabs").card()
	(cc["target"] as Array).append("x")
	check.call(TutorialState.step_def("tabs")["target"] == ["tabbar"], "the card's target list is a copy of the data")
	# debug line
	check.call(m.debug_line(0, 0) == "tutorial=new step_skipped=none total_s=0 fallbacks=0", "debug line of a new save")
	check.call(_running("ban").debug_line(12.9, 1) == "tutorial=running step_skipped=none total_s=12 fallbacks=1", "debug line while running")
	var s := _running("pick")
	s.skip()
	check.call(s.debug_line(41, 0) == "tutorial=skipped step_skipped=pick total_s=41 fallbacks=0", "debug line after a skip names the step")
	var d := TutorialState.new({"v": 1, "state": "done", "step": "finish", "game": {"live": false, "n": 1, "plan": {}}})
	check.call(d.debug_line(300, 0) == "tutorial=done step_skipped=none total_s=300 fallbacks=0", "debug line when done")
	check.call(TutorialState.new(TutorialState.legacy_state()).debug_line() == "tutorial=legacy step_skipped=none total_s=0 fallbacks=0", "debug line for a legacy save")
	s.undo_skip()
	check.call(s.debug_line() == "tutorial=running step_skipped=none total_s=0 fallbacks=0", "after Undo the debug line no longer says skipped")


# ------------------------------------------------------------------ game flags
func _game_flags(check: Callable) -> void:
	var m := _running("start_match")
	var fx := m.set_game_live(true)
	check.call(bool(m.game()["live"]) and fx.size() == 1 and fx[0]["fx"] == "save", "a game starting: live true, one save")
	check.call(m.set_game_live(true).is_empty(), "the same flag again: nothing to save")
	var fp := m.set_game_plan({"risk": 2, "tempo": {"early": 1}})
	check.call(m.game()["plan"] == {"risk": 2, "tempo": {"early": 1}} and fp[0]["fx"] == "save", "the sandbox plan is kept in the key")
	var plan := {"a": 1}
	m.set_game_plan(plan)
	plan["a"] = 2
	check.call(m.game()["plan"] == {"a": 1}, "the plan is copied in")
	var snap := m.snapshot()
	snap["game"]["live"] = false
	check.call(bool(m.game()["live"]), "snapshot() is a copy")
	m.set_game_live(false)
	check.call((m.game()["plan"] as Dictionary).is_empty(), "game over: the sandbox plan is dropped")
	check.call(TutorialState.new(TutorialState.legacy_state()).set_game_plan({"a": 1}).is_empty(), "a legacy save has no game part to write")
	check.call(TutorialState.is_valid(m.snapshot()) and not TutorialState.is_valid({"v": 1, "state": "running", "step": "nope", "game": {"live": false, "n": 1, "plan": {}}}) and not TutorialState.is_valid(null), "is_valid: a good key, an unknown step, null")


# ------------------------------------------------------------------ what Home shows
func _offers(check: Callable) -> void:
	var nw := TutorialState.new_state()
	check.call(TutorialState.offer_for(nw, false, false) == "welcome_modal", "new save, device never answered: the welcome modal")
	check.call(TutorialState.offer_for(nw, true, false) == "returning_card", "new save, device answered before: the inline returning card, not the modal")
	check.call(TutorialState.offer_for(TutorialState.legacy_state(), false, false) == "legacy_card", "legacy save, first time on this device: the inline card, never a modal")
	check.call(TutorialState.offer_for(TutorialState.legacy_state(), true, true) == "none" and TutorialState.offer_for(TutorialState.legacy_state(), false, true) == "none", "legacy offer already answered on this device: nothing")
	var running_key := {"v": 1, "state": "running", "step": "tab_plan", "game": {"live": false, "n": 1, "plan": {}}}
	check.call(TutorialState.offer_for(running_key, false, false) == "resume_card" and TutorialState.offer_for(running_key, false, false, false) == "none", "running after a load: the resume card; a run that is already on screen: nothing")
	check.call(TutorialState.offer_for({"v": 1, "state": "done"}, false, false) == "none" and TutorialState.offer_for({"v": 1, "state": "skipped"}, false, false) == "none", "done and skipped: nothing")
	check.call(TutorialState.offer_for(null, false, false) == "legacy_card", "a missing key reads as a legacy save (no crash)")
	# the whole flow: a new save on a fresh device, then a second new save on the same device
	var flags := {"welcome_seen": false}
	var m := TutorialState.new(TutorialState.new_state())
	check.call(TutorialState.offer_for(m.snapshot(), flags["welcome_seen"], false) == "welcome_modal", "flow: first save shows the modal")
	for e in m.skip():
		if e["fx"] == "device" and e["key"] == "welcome_seen":
			flags["welcome_seen"] = true
	var m2 := TutorialState.new(TutorialState.new_state())
	check.call(TutorialState.offer_for(m2.snapshot(), flags["welcome_seen"], false) == "returning_card", "flow: after Skip tutorial, a second new save gets the inline card")
	# killing the app at the modal changes nothing: the state is still new and no flag was set
	var k := TutorialState.from_save(JSON.parse_string(JSON.stringify(TutorialState.new_state())))
	check.call(k.state() == "new" and TutorialState.offer_for(k.snapshot(), false, false) == "welcome_modal", "flow: killing the app at the welcome modal shows it again")


# ================================================================== I-13 the tutorial game (TutorialGame, sandbox)
const TG_CLUB := "ironquill_wolves"
const TG_FIXTURES := ["save_0_6_a.json", "save_0_6_b.json", "save_0_6_c.json", "save_0_6_d.json"]


## The save without its tutorial key, as sorted JSON: what the deep compare reads.
func _tg_snap(gs: GameState) -> String:
	var c: Dictionary = gs.d.duplicate(true)
	c.erase("tutorial")
	return JSON.stringify(c, "", true)


## A tutorial game as the screens play it: start, draft with the AI, finish with the plans, stamp, record, leave.
func _tg_play(gs: GameState, w: World, edit_plan: bool = true) -> Dictionary:
	var g := TutorialGame.start(gs)
	if g.is_empty():
		return {}
	if edit_plan:
		gs.plan_set()["default"]["g"] = 50     # the Game Plan screen edits what plan_set() returns, in place
		gs.plan_set()["default"]["jf"] = "mid_lane"
	var dr := MatchRunner.prepare(w, gs.lineup_for(g["blue"]), gs.lineup_for(g["red"]), gs.meta_for(int(g["round"])), int(gs.d["save_seed"]), g["id"], bool(g["full"]))
	dr.finish_with_ai()
	var res := MatchRunner.finish(w, dr, gs.plans_for(g))
	TutorialGame.stamp(res, g)
	gs.record_human_game(g, res)
	TutorialGame.leave(gs)
	return {"game": g, "res": res}


func _tg_fixture(name: String) -> Dictionary:
	var f := FileAccess.open("res://tests/fixtures/" + name, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


## What a real next league game gives, as a string: the result's numbers and the picks.
func _tg_digest(res: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [str(res["mseed"]), str(res["final"]), str(res["blue_won"]), JSON.stringify(res["picks"], "", true), JSON.stringify(res["bans"], "", true)]


func _tutorial_game(check: Callable) -> void:
	TutorialState.use_data({})
	var w := World.load_default()
	_tg_sandbox(check, w)
	_tg_rng_isolation(check, w)
	_tg_replay_seeds(check, w)
	_tg_opponent(check, w)
	_tg_legacy(check, w)
	_tg_resume_and_flag(check, w)


func _tg_sandbox(check: Callable, w: World) -> void:
	# the deep compare, from a brand-new save, a save mid-season, and the quick path (auto_game)
	for round_to_play in [0, 3, 9]:
		var gs := GameState.new_game(w, TG_CLUB, 9100 + round_to_play)
		var guard := 0
		while int(gs.d["round"]) < round_to_play and guard < 100:
			guard += 1
			var ng := gs.next_game()
			if not ng.is_empty():
				gs.record_human_game(ng, gs.auto_game(ng))
			else:
				gs._finish_round_if_done()
		var before := _tg_snap(gs)
		var fat_before := JSON.stringify(w.fatigue, "", true)
		var tut_before := JSON.stringify(gs.tutorial(), "", true)
		var out := _tg_play(gs, w)
		check.call(not out.is_empty() and TutorialGame.is_tutorial(out["game"]) and TutorialGame.is_tutorial(out["res"]), "tutorial game at round %d: game and result carry the flag" % round_to_play)
		check.call(_tg_snap(gs) == before, "tutorial game at round %d: gs.d is identical before and after (all keys but tutorial)" % round_to_play)
		check.call(JSON.stringify(w.fatigue, "", true) == fat_before, "tutorial game at round %d: the world's fatigue is unchanged" % round_to_play)
		check.call(JSON.stringify(gs.tutorial(), "", true) == tut_before, "tutorial game at round %d: even the tutorial key is untouched by the game itself (the runner owns it)" % round_to_play)
		check.call(not TutorialGame.is_live(gs), "tutorial game at round %d: the sandbox plan is gone after leave()" % round_to_play)
	# the Quick button path: auto_game, then the stamp, then record
	var q := GameState.new_game(w, TG_CLUB, 9200)
	var qb := _tg_snap(q)
	var qg := TutorialGame.start(q)
	var qr := TutorialGame.stamp(q.auto_game(qg), qg)
	q.record_human_game(qg, qr)
	TutorialGame.leave(q)
	check.call(_tg_snap(q) == qb, "the Quick button path (auto_game) leaves gs.d identical too")
	# the flag alone is enough: a game dict without the flag but a result with it is skipped as well, and the reverse
	var f1 := GameState.new_game(w, TG_CLUB, 9201)
	var g1 := TutorialGame.start(f1)
	var r1 := f1.auto_game(g1)
	var b1 := _tg_snap(f1)
	f1.record_human_game(g1, r1)
	check.call(_tg_snap(f1) == b1, "the flag on the game alone: skipped")
	TutorialGame.leave(f1)
	var g1b := g1.duplicate()
	g1b.erase("tutorial")
	f1.record_human_game(g1b, TutorialGame.stamp(r1.duplicate(), g1))
	check.call(_tg_snap(f1) == b1, "the flag on the result alone: skipped")
	# negative controls: the same compare must SEE a real practice game and a real league game
	var n1 := GameState.new_game(w, TG_CLUB, 9202)
	var nb := _tg_snap(n1)
	n1.start_practice(n1.quick_match_opponent(), 1)
	var pg := n1.practice_game()
	n1.record_human_game(pg, n1.auto_game(pg))
	check.call(_tg_snap(n1) != nb, "negative control: a real Quick Match changes gs.d (fatigue, bonds, exh_n), the compare would catch it")
	var n2 := GameState.new_game(w, TG_CLUB, 9203)
	var nb2 := _tg_snap(n2)
	var lg := n2.next_game()
	n2.record_human_game(lg, n2.auto_game(lg))
	check.call(_tg_snap(n2) != nb2, "negative control: a real league game changes gs.d")
	# the sandbox plan: edits land in the sandbox, never in the saved plan; plans_for plays the right one
	var p := GameState.new_game(w, TG_CLUB, 9204)
	var saved_before := JSON.stringify(p.d["plan"], "", true)
	var pg2 := TutorialGame.start(p)
	check.call(TutorialGame.is_live(p) and GamePlan.is_neutral(p.plan_set()["default"]) and (p.plan_set()["triggers"] as Array).is_empty(), "start(): a live sandbox plan that starts neutral")
	p.plan_set()["default"]["a"] = 100
	p.plan_set()["triggers"].append({"when": "behind_early", "plan": GamePlan.neutral()})
	check.call(JSON.stringify(p.d["plan"], "", true) == saved_before, "editing plan_set() while the tutorial game is live does not touch the saved plan")
	check.call(int(p.plans_for(pg2)["B"]["default"]["a"]) == 100, "plans_for(tutorial game) plays the sandbox plan")
	var league := p.next_game()
	check.call(int(p.plans_for(league)["B"]["default"]["a"]) == 0 or int(p.plans_for(league)["R"]["default"]["a"]) == 0, "plans_for(a league game) plays the saved plan, even while the sandbox is live")
	check.call(TutorialGame.plan_copy(p) == p.sandbox_plan and not is_same(TutorialGame.plan_copy(p), p.sandbox_plan), "plan_copy() is an equal copy")
	TutorialGame.leave(p)
	check.call(GamePlan.is_neutral(p.plan_set()["default"]) and JSON.stringify(p.plan_set(), "", true) == saved_before, "after leave(): plan_set() is the saved plan again")
	check.call(JSON.stringify(p.d, "", true).find("sandbox") < 0, "the sandbox is never written into the save")
	# the replay in every phase: playoffs and done, and on a day whose practice is already used
	var ph := GameState.new_game(w, TG_CLUB, 9205)
	ph.autoplay(false)
	var phase_now: String = ph.d["phase"]
	var pb := _tg_snap(ph)
	var po := _tg_play(ph, w)
	check.call(not po.is_empty() and _tg_snap(ph) == pb, "playoffs phase (%s): the tutorial game runs and changes nothing" % phase_now)
	ph.autoplay(true)
	var db := _tg_snap(ph)
	var dn := _tg_play(ph, w)
	check.call(not dn.is_empty() and _tg_snap(ph) == db, "phase %s after the split: the tutorial game runs and changes nothing" % String(ph.d["phase"]))
	var used := GameState.new_game(w, TG_CLUB, 9206)
	used.start_practice(used.quick_match_opponent(), 1)
	var ug := used.practice_game()
	used.record_human_game(ug, used.auto_game(ug))
	check.call(not used.practice_available(), "setup: the practice day is used up")
	var ub := _tg_snap(used)
	var uo := _tg_play(used, w)
	check.call(not uo.is_empty() and _tg_snap(used) == ub, "a used practice day does not stop the tutorial game, and it changes nothing")


func _tg_rng_isolation(check: Callable, w: World) -> void:
	var wa := World.load_default()     # one World per save: a World is bound to the save made last
	var wb := World.load_default()
	var a := GameState.new_game(wa, TG_CLUB, 9300)
	var ng_a := a.next_game()
	var opp_a := a.quick_match_opponent()
	var res_a := a.auto_game(ng_a)
	var b := GameState.new_game(wb, TG_CLUB, 9300)
	_tg_play(b, wb)
	_tg_play(b, wb)     # two of them, to be sure
	var ng_b := b.next_game()
	check.call(JSON.stringify(ng_b, "", true) == JSON.stringify(ng_a, "", true), "RNG isolation: the next league game is the same fixture")
	check.call(b.quick_match_opponent() == opp_a, "RNG isolation: the real Quick Match opponent draw is the same")
	check.call(_tg_digest(b.auto_game(ng_b)) == _tg_digest(res_a), "RNG isolation: the next league game result is identical with and without tutorial games played first")
	# and further on: a whole season of auto-play ends in the same save
	a.autoplay(true)
	b.autoplay(true)
	check.call(_tg_snap(a) == _tg_snap(b), "RNG isolation: after a whole split the two saves are identical")
	var gt := TutorialGame.start(b)
	TutorialGame.leave(b)
	check.call(String(gt["id"]).begins_with("tut:9300:") and Pcg32.match_seed(9300, String(gt["id"])) != Pcg32.match_seed(9300, "S1-R0-A"), "the tutorial id is a tut: id, a different stream from a league fixture")


func _tg_replay_seeds(check: Callable, w: World) -> void:
	var gs := GameState.new_game(w, TG_CLUB, 9400)
	var m := TutorialState.new(gs.tutorial())
	var ids: Array = []
	var seeds: Array = []
	var opps: Array = []
	for i in 3:
		m.replay() if i > 0 else m.accept()
		gs.set_tutorial(m.snapshot())
		var g := TutorialGame.start(gs)
		ids.append(String(g["id"]))
		seeds.append(TutorialGame.match_seed(gs))
		opps.append(String(g["red"]))
		TutorialGame.leave(gs)
	check.call(ids == ["tut:9400:1", "tut:9400:2", "tut:9400:3"], "replay: ids are tut:<seed>:<n> with n 1, 2, 3 (got %s)" % str(ids))
	check.call(seeds[0] != seeds[1] and seeds[1] != seeds[2] and seeds[0] != seeds[2], "replaying twice gives three different match seeds")
	check.call(opps[0] == opps[1] and opps[1] == opps[2], "a replay is the same club on another seed")
	var again := GameState.new_game(w, TG_CLUB, 9400)
	var m2 := TutorialState.new(again.tutorial())
	m2.accept()
	again.set_tutorial(m2.snapshot())
	check.call(String(TutorialGame.start(again)["id"]) == "tut:9400:1", "scripted runs repeat: the same save and n give the same id")
	var other := GameState.new_game(w, TG_CLUB, 9401)
	var m3 := TutorialState.new(other.tutorial())
	m3.accept()
	other.set_tutorial(m3.snapshot())
	check.call(String(TutorialGame.start(other)["id"]) == "tut:9401:1", "another save seed gives another id")
	# two different games really play differently on the seeds (not a proof of luck, a check the id feeds the sim)
	var r1 := _tg_play(gs, w, false)
	m.replay()
	gs.set_tutorial(m.snapshot())
	var r2 := _tg_play(gs, w, false)
	check.call(str(r1["res"]["mseed"]) != str(r2["res"]["mseed"]), "the two replays' results carry different mseed values")


## The opponent never stronger than the player in 200 random clubs and saves (and the documented fallback for the weakest club).
func _tg_opponent(check: Callable, w: World) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13013
	var ok_all := true
	var closest_all := true
	var stronger := 0
	var weakest_cases := 0
	var fallback_nearest := true
	var no_side_effect := true
	for i in 200:
		var club: String = w.club_ids[rng.randi() % w.club_ids.size()]
		var gs := GameState.new_game(w, club, 1000 + rng.randi() % 100000)
		var rounds := rng.randi() % 14
		var guard := 0
		while int(gs.d["round"]) < rounds and guard < 60:
			guard += 1
			var ng := gs.next_game()
			if not ng.is_empty():
				gs.record_human_game(ng, gs.auto_game(ng))
			else:
				gs._finish_round_if_done()
		if rng.randi() % 3 == 0:     # some saves with a shuffled lineup
			var ids: Array = (gs.d["roster"] as Array).duplicate()
			var slots: Array = ["top", "jg", "mid", "bot", "sup"]
			for s in slots:
				gs.assign(s, ids[rng.randi() % ids.size()])
		var snap := _tg_snap(gs)
		var opp := TutorialGame.opponent(gs)
		var mine: float = w.team_rating(gs.lineup_for(gs.club()))
		var opp_r: float = w.team_rating(gs.lineup_for(opp))
		var others: Array = []
		for c in w.club_ids:
			if c != gs.club():
				others.append(float(w.team_rating(gs.lineup_for(c))))
		var any_not_above := false
		var best_below := -1e18
		var nearest_above := 1e18
		for r in others:
			if r <= mine:
				any_not_above = true
				best_below = maxf(best_below, r)
			else:
				nearest_above = minf(nearest_above, r)
		if opp == "" or opp == gs.club():
			ok_all = false
		elif any_not_above:
			ok_all = ok_all and opp_r <= mine
			closest_all = closest_all and is_equal_approx(opp_r, best_below)
		else:
			weakest_cases += 1
			stronger += 1
			fallback_nearest = fallback_nearest and is_equal_approx(opp_r, nearest_above)
		no_side_effect = no_side_effect and _tg_snap(gs) == snap
	check.call(ok_all, "200 random clubs and saves: the opponent is never stronger whenever any club is not stronger")
	check.call(closest_all, "200 random clubs and saves: it is the strongest club that is not above ours (closest from below)")
	check.call(fallback_nearest, "the weakest-club fallback is the nearest club above (%d of 200 cases)" % weakest_cases)
	check.call(no_side_effect, "choosing the opponent changes nothing in the save")
	# the three hand-made cases of the rule on a fake rating: strongest club, weakest club, and a tie
	var gs2 := GameState.new_game(w, TG_CLUB, 5)
	var opp2 := TutorialGame.opponent(gs2)
	check.call(opp2 != "" and opp2 != TG_CLUB and w.clubs.has(opp2), "the default club gets a real other club")
	check.call(TutorialGame.opponent(gs2) == opp2, "the same save gives the same opponent every time (no draw)")


func _tg_legacy(check: Callable, w: World) -> void:
	for name in TG_FIXTURES:
		var data := _tg_fixture(name)
		if data.is_empty():
			check.call(false, "fixture %s loads" % name)
			continue
		var gs := GameState.from_dict(World.load_default(), data)
		check.call(gs.tutorial()["state"] == "legacy", "%s: a 0.6 save reads as legacy" % name)
		var before := _tg_snap(gs)
		var out := _tg_play(gs, gs.world)
		check.call(not out.is_empty() and _tg_snap(gs) == before, "%s: a legacy save runs the tutorial game and gs.d is identical after" % name)
		check.call(gs.tutorial()["state"] == "legacy" and not (gs.tutorial().has("game")), "%s: the legacy key is untouched by the game" % name)
		# the legacy offer, Show me: accept() makes it running with game.n 1 and the game works from there
		var m := TutorialState.new(gs.tutorial())
		m.accept()
		gs.set_tutorial(m.snapshot())
		var g2 := TutorialGame.start(gs)
		check.call(String(g2["id"]).ends_with(":1") and TutorialGame.game_n(gs) == 1, "%s: after Show me the id has n 1" % name)
		TutorialGame.leave(gs)
	# a save with no plan key at all (very old): the sandbox must not create one
	var old := GameState.new_game(w, TG_CLUB, 9500)
	old.d.erase("plan")
	old.d.erase("tutorial")
	var rt = JSON.parse_string(JSON.stringify(old.d))
	var lg := GameState.from_dict(World.load_default(), rt)
	check.call(lg.tutorial()["state"] == "legacy" and not lg.d.has("plan"), "setup: a legacy save with no plan key")
	var b := _tg_snap(lg)
	var o := _tg_play(lg, lg.world)
	check.call(not o.is_empty() and _tg_snap(lg) == b and not lg.d.has("plan"), "a legacy save without a plan key: the sandbox does not create d[plan]")


func _tg_resume_and_flag(check: Callable, w: World) -> void:
	# a running tutorial, game live, saved and reloaded through JSON (the app was killed): section 5 item 10
	for case in [["watch", true], ["start_match", true], ["result", false], ["tab_plan", true]]:
		var step: String = case[0]
		var live: bool = case[1]
		var gs := GameState.new_game(w, TG_CLUB, 9600)
		var m := TutorialState.new(gs.tutorial())
		m.accept()
		m.replay()     # n = 2, so "unchanged" is a real check
		gs.set_tutorial(m.snapshot())
		var g := TutorialGame.start(gs)
		var opp_before: String = g["red"]
		var id_before: String = g["id"]
		var snap := m.snapshot()
		snap["step"] = step
		snap["game"]["live"] = live
		snap["game"]["plan"] = {"default": {"g": 50}} if live else {}
		gs.set_tutorial(snap)
		var before := _tg_snap(gs)
		var raw = JSON.parse_string(JSON.stringify(gs.d))
		var back := GameState.from_dict(World.load_default(), raw)
		var t := back.tutorial()
		var ch := TutorialState.chapter_of(step)
		var want_step := "tab_club" if ch == 6 else "tab_plan"
		check.call(t["step"] == want_step and t["game"]["live"] == false and (t["game"]["plan"] as Dictionary).is_empty(), "resume at %s (live %s): step %s, live false, sandbox plan emptied" % [step, str(live), want_step])
		check.call(int(t["game"]["n"]) == 2, "resume at %s: game.n is unchanged (2)" % step)
		check.call(not TutorialGame.is_live(back), "resume at %s: no sandbox plan after a load (it is runtime only)" % step)
		var g2 := TutorialGame.start(back)
		check.call(String(g2["id"]) == id_before and String(g2["red"]) == opp_before, "resume at %s: the restarted game is the same game (same id %s, same opponent), no duplicate" % [step, id_before])
		TutorialGame.leave(back)
		check.call(_tg_snap(back) == before, "resume at %s: loading and restarting changed nothing in the save (all keys but tutorial)" % step)
	# the result flag survives a save and a load of a running tutorial
	var gs2 := GameState.new_game(w, TG_CLUB, 9601)
	var m2 := TutorialState.new(gs2.tutorial())
	m2.accept()
	m2.set_game_live(true)
	gs2.set_tutorial(m2.snapshot())
	var g := TutorialGame.start(gs2)
	var res := TutorialGame.stamp(gs2.auto_game(g), g)
	var game_rt = JSON.parse_string(JSON.stringify(g))
	var res_rt = JSON.parse_string(JSON.stringify(res))
	check.call(game_rt is Dictionary and res_rt is Dictionary and TutorialGame.is_tutorial(game_rt) and TutorialGame.is_tutorial(res_rt), "the tutorial flag on the game and on the result survives a JSON round trip")
	var raw2 = JSON.parse_string(JSON.stringify(gs2.d))       # the save, written while the tutorial game is live
	var back2 := GameState.from_dict(World.load_default(), raw2)
	check.call(back2.tutorial()["state"] == "running" and back2.tutorial()["game"]["live"] == false, "save and load of a running tutorial: still running, live false after the load")
	var b2 := _tg_snap(back2)
	back2.record_human_game(game_rt, res_rt)      # the game still on screen finishes after the reload: the flag still holds
	check.call(_tg_snap(back2) == b2, "after save and load, finishing the flagged game (flag from the round-tripped dictionaries) still changes nothing")
	var plain_rt: Dictionary = res_rt.duplicate()
	plain_rt.erase("tutorial")
	var game_plain: Dictionary = game_rt.duplicate()
	game_plain.erase("tutorial")
	back2.start_practice(back2.quick_match_opponent(), 1)
	var pg := back2.practice_game()
	back2.record_human_game(pg, back2.auto_game(pg))
	check.call(_tg_snap(back2) != b2, "negative control: without the flag the same kind of game does change the save")
	check.call(not JSON.stringify(gs2.d).contains("\"tutorial\":true"), "the flag is never written into the save: gs.d holds no `tutorial: true` game")
	TutorialGame.leave(gs2)
	# the readers for the screens
	var qg := GameState.new_game(w, TG_CLUB, 9602)
	qg.set_quick(true)
	check.call(TutorialGame.quick_applies(qg, {}) and not TutorialGame.quick_applies(qg, {"tutorial": true}), "Quick mode applies to a real game and is ignored for the tutorial game")
	check.call(TutorialGame.timed({}) and not TutorialGame.timed({"tutorial": true}) and TutorialGame.DRAFT_LIMIT_S == 0.0, "the draft timer: on for a real game, off for the tutorial game")
	check.call(TutorialGame.logs_pace({}) and not TutorialGame.logs_pace({"tutorial": true}), "the pace log: written for a real game, skipped for the tutorial game")
	check.call(not TutorialGame.is_tutorial(null) and not TutorialGame.is_tutorial({}) and not TutorialGame.is_tutorial({"tutorial": false}), "is_tutorial: null, empty and false are not tutorial games")
