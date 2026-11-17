extends Node
## I-16 checks on the REAL Draft (screen_draft.gd), headless:
##   build_draft / fit_draft_<v>  every state builds (their turn, your ban, your pick, both sheets, a role filter, done) in normal and
##                    large text; no control leaves the frame; no drawn text is cut (board rows, role bar, needs, Plays as); buttons
##                    at least 96 px high; nodes under the target (120)
##   arrows           draft.meta_hint speaks of arrows, and every available hero carries a drawn up, down or flat arrow (not colour)
##   equivalence      a full draft played through the real controls (grid tap -> sheet -> Plays as -> confirm, Take) ends in the
##                    same picks and bans as the same choices through the old methods (_on_hero / _apply), on 20 seeds
##   timing           the AI turn waits 0.9 s (0.45 in Quick mode) as before; a real game's timer runs out into the Coach's choice
##                    and a toast; the tutorial game has no timer
##   events           draft:sheet (with kind), draft:ban, draft:pick, draft:done fire once each for one act
##   auto             Auto-finish: one tap arms "Sure?", it reverts after 3 s; a second tap finishes; the tutorial step holds it
##   inplace_draft    six taps (filter, sheet, Plays as, confirm, Take, filter) leave the same screen, board and grid (built once)
##   back             a running draft asks before leaving; Leave goes to Match day; leaving the tutorial game drops its sandbox
##   cb_draft         banned, picked, recommended, selected and the urgent timer carry a shape or word
##   tags_draft       the TUTORIAL 8 draft ids are there in their states; tutorial steps 12 to 16 find their targets (no fallback)
## Ends with " N checks, M failures".

const TEMP_CFG := "user://draft_test.cfg"

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
	await _arrows()
	await _equivalence()
	await _boot()
	await _timing()
	await _boot()
	await _events_once()
	await _boot()
	await _auto()
	await _boot()
	await _inplace()
	await _boot()
	await _back()
	await _boot()
	await _cb()
	await _boot()
	await _tags()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_ui_draft: %d checks, %d failures" % [checks, fails])
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


func _draft(g: Dictionary = {}) -> ScreenDraft:
	var gg := g if not g.is_empty() else App.gs.next_game()
	var d := ScreenDraft.new(gg)
	App.go(d)
	await frames(4)
	return d


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


## Let the AI play until it is your turn of `kind` ("" = any of yours), or the draft is over.
func _until_mine(d: ScreenDraft, kind: String = "") -> void:
	var n := 0
	while not d.draft.is_done() and n < 40:
		n += 1
		var c := d.draft.current()
		if c["team"] == d.my_side and (kind == "" or c["kind"] == kind):
			return
		if c["team"] == d.my_side:
			d._take()
		else:
			d._ai_wait = 0.0
			d._process(0.01)
	await frames(1)


func _close_sheet() -> void:
	if BottomSheet.is_open():
		BottomSheet.current().close()
	await frames(20)


func _labels(root: Node) -> String:
	var out := ""
	for n in root.find_children("*", "Label", true, false):
		out += UI.plain((n as Label).text) + "\n"
	return out


func _cut(d: ScreenDraft) -> Array:
	var out: Array = []
	for r in d.board.rows.values():
		for t in (r as LaneRow).clipped:
			out.append("lane: " + String(t))
	for t in d.filter.clipped():
		out.append("filter: " + String(t))
	for t in d.needs.clipped():
		out.append("needs: " + String(t))
	if d.sheet_slot != null and is_instance_valid(d.sheet_slot):
		for t in d.sheet_slot.clipped():
			out.append("plays as: " + String(t))
	return out


func _redraw_all(d: ScreenDraft) -> void:
	d.board.queue_redraw()
	d.filter.queue_redraw()
	d.needs.queue_redraw()
	if d.sheet_slot != null and is_instance_valid(d.sheet_slot):
		d.sheet_slot.queue_redraw()
	await frames(3)


# ------------------------------------------------------------------ rows
func _fit_state(d: ScreenDraft, v: String, st: String) -> void:
	await _redraw_all(d)
	var vw := get_viewport().get_visible_rect().size.x
	var outside: Array = []
	var roots: Array = [d]
	if BottomSheet.is_open():
		roots.append(BottomSheet.current())
	for root in roots:
		for c in (root as Node).find_children("*", "Control", true, false):
			var ctl := c as Control
			if ctl.is_visible_in_tree() and ctl.size.x > 0.0 and not (ctl is ScrollBar):
				var r := ctl.get_global_rect()
				if r.position.x < -0.5 or r.end.x > vw + 0.5:
					outside.append("%s %s" % [ctl.name, str(r)])
	ok(outside.is_empty(), "fit_draft_%s_%s: no control leaves the %d px frame %s" % [v, st, int(vw), str(outside.slice(0, 3))])
	var cut := _cut(d)
	ok(cut.is_empty(), "fit_draft_%s_%s: no drawn text is cut %s" % [v, st, str(cut)])
	var short: Array = []
	for root in roots:
		for b in (root as Node).find_children("*", "BaseButton", true, false):
			var bb := b as BaseButton
			if bb.is_visible_in_tree() and bb.size.y < float(UI.BTN_H) - 0.5 and not (bb.get_parent() is Segmented or String(bb.name).begins_with("@")) and bb.get_parent() != null and not (bb.get_parent().get_parent() is Segmented):
				short.append("%s %.0f" % [bb.name, bb.size.y])
	ok(short.is_empty(), "fit_draft_%s_%s: every button is at least 96 px high %s" % [v, st, str(short)])
	ok(_count(d) <= 120, "build_draft_%s_%s: %d nodes (target 120)" % [v, st, _count(d)])


func _build_and_fit(v: String) -> void:
	App.apply_large_text(v == "large")
	await frames(3)
	var d := await _draft()
	ok(d.build_count == 1, "build_draft_%s: the screen builds once" % v)
	var c := d.draft.current()
	if c["team"] != d.my_side:
		ok(d.turn_label.visible and not d.coach_bar.visible and d.grid.modulate.a < 0.6, "build_draft_%s_theirs: their turn names who chooses, dims the grid, hides the Coach bar" % v)
		await _fit_state(d, v, "theirs")
	await _until_mine(d, "ban")
	ok(UI.plain(d.title_label.text) == UI.plain(Strings.t("draft.title.your_ban")), "build_draft_%s_ban: the title says Your ban" % v)
	await _fit_state(d, v, "ban")
	d._open_sheet(String(d.grid.shown_ids()[0]))
	await frames(6)
	await _fit_state(d, v, "sheet_ban")
	await _close_sheet()
	d._take()
	await _until_mine(d, "pick")
	await _fit_state(d, v, "pick")
	d._open_sheet(String(d.grid.shown_ids()[1]))
	await frames(6)
	ok(d.sheet_slot != null and d.sheet_confirm != null and d.sheet_slot.is_visible_in_tree() and d.sheet_confirm.is_visible_in_tree(), "build_draft_%s_sheet_pick: Plays as and the confirm button are both there" % v)
	var vp := get_viewport().get_visible_rect()
	ok(d.sheet_slot != null and vp.encloses(d.sheet_slot.get_global_rect()) and d.sheet_slot.get_global_rect().end.y <= d.sheet_confirm.get_global_rect().position.y + 0.5,
			"build_draft_%s_sheet_pick: Plays as is on screen above the confirm button, no scrolling needed" % v)
	await _fit_state(d, v, "sheet_pick")
	await _close_sheet()
	d.filter.press(d.filter.index_of("jg"))
	await frames(2)
	await _fit_state(d, v, "filter")
	d.filter.press(0)
	d._auto_rest()
	await frames(3)
	ok(d.done_box.visible and not d.grid_scroll.visible and UI.plain(d.title_label.text) == UI.plain(Strings.t("draft.done")), "build_draft_%s_done: Draft complete with the done card" % v)
	await _fit_state(d, v, "done")


func _arrows() -> void:
	var hint := UI.plain(Strings.t("draft.meta_hint")).to_lower()
	ok(hint.contains("up arrow") and hint.contains("down arrow") and not hint.contains("green") and not hint.contains("grey"), "arrows: draft.meta_hint speaks of arrows, not colours (released in I-16)")
	var d := await _draft()
	await _until_mine(d)
	var missing: Array = []
	var ups := 0
	for hid in d.draft.avail:
		var st := d.grid.state_of(String(hid))
		var a := String(st.get("arrow", ""))
		if not (a in ["up", "down", "flat"]):
			missing.append(hid)
		var m := float(d.draft.meta[hid])
		if (m > 1.015 and a != "up") or (m < 0.985 and a != "down"):
			missing.append("%s wrong" % hid)
		if a == "up":
			ups += 1
	ok(missing.is_empty() and ups > 0, "arrows: every available hero carries a drawn arrow matching its patch strength (%d up) %s" % [ups, str(missing.slice(0, 3))])
	ok(_labels(d).contains(UI.plain(Strings.t("draft.meta_hint"))), "arrows: the hint is shown on the Draft with the arrows")


## The same choices through the real controls and through the old methods give the same draft.
func _equivalence() -> void:
	var same := 0
	var n := 20
	for k in n:
		var seed_value := 9000 + k * 37
		await _boot(seed_value)
		var g: Dictionary = App.gs.next_game()
		var a := await _draft(g)
		var choices: Array = []
		var guard := 0
		while not a.draft.is_done() and guard < 40:
			guard += 1
			var c := a.draft.current()
			if c["team"] != a.my_side:
				a._ai_wait = 0.0
				a._process(0.01)
				continue
			var shown: Array = a.grid.shown_ids()
			var hid := String(shown[mini(guard % 3, shown.size() - 1)])
			if guard % 4 == 0:
				var rec := a.draft.ai_choice()
				choices.append(["take", rec])
				(a.take_button as Button).pressed.emit()
				await frames(1)
				continue
			a.grid._tapped(a.grid.heroes.find(a.grid.heroes.filter(func(h: Dictionary) -> bool: return h["id"] == hid)[0]))
			await frames(2)
			if c["kind"] == "pick":
				var open := a.draft.open_slots(a.my_side)
				var slot := String(open[guard % open.size()])
				a.sheet_slot.press(a.sheet_slot.index_of(slot))
				choices.append(["pick", hid, slot])
			else:
				choices.append(["ban", hid, ""])
			a.sheet_confirm.pressed.emit()
			await frames(2)
		await _close_sheet()
		var real := [a.draft.picks.duplicate(true), a.draft.bans.duplicate(true)]
		# the same choices through the old methods on a fresh screen
		await _boot(seed_value)
		var b := await _draft(g)
		var i := 0
		guard = 0
		while not b.draft.is_done() and guard < 60:
			guard += 1
			var c2 := b.draft.current()
			if c2["team"] != b.my_side:
				b._process(5.0)
				continue
			if i >= choices.size():
				break
			var ch: Array = choices[i]
			i += 1
			if ch[0] == "take":
				b._apply(b.draft.ai_choice())
			elif ch[0] == "ban":
				b._on_hero(ch[1], "ban")
			else:
				b._on_hero(ch[1], "pick")
				b._apply({"hero": b._sel_hero, "slot": ch[2]})
		if JSON.stringify(real) == JSON.stringify([b.draft.picks, b.draft.bans]):
			same += 1
	ok(same == n, "equivalence: %d of %d drafts through the real controls end as the old methods do" % [same, n])


func _timing() -> void:
	var d := await _draft()
	if d.draft.current()["team"] == d.my_side:
		d._take()
		await frames(1)
	if not d.draft.is_done() and d.draft.current()["team"] != d.my_side:
		d._begin_step()    # read the wait as the step begins (a frame of _process would already have counted it down)
		ok(absf(d._ai_wait - 0.9) < 0.001, "timing: the AI waits 0.9 s on its turn (unchanged)")
	App.gs.set_quick(true)
	d._begin_step()
	ok(absf(d._ai_wait - 0.45) < 0.001, "timing: 0.45 s in Quick mode (unchanged)")
	App.gs.set_quick(false)
	await _until_mine(d)
	var before := d.draft.step
	var rec := d.draft.ai_choice()
	d._process(d._limit + 0.5)
	await frames(2)
	var toast := ""
	for n in App.main.toast_layer.find_children("*", "Label", true, false):
		toast += UI.plain((n as Label).text)
	ok(d.draft.step == before + 1 or d.draft.is_done(), "timing: a real game's timer runs out into the next step")
	ok(toast.contains(UI.plain(App.world.heroes[rec["hero"]]["name"])), "timing: the toast names the Coach's choice")
	# the tutorial game: no timer
	var tg := TutorialGame.start(App.gs)
	App.tutorial.set_game_live(true)
	var t := await _draft(tg)
	await _until_mine(t)
	var step0 := t.draft.step
	t._process(60.0)
	await frames(2)
	ok(not t.timed() and not t.timer.visible and t.draft.step == step0, "timing: the tutorial game has no timer (60 s pass, nothing is chosen for you)")
	ok(_labels(t).contains(UI.plain(Strings.t("tut.draft.note"))), "timing: the tutorial game says there is no timer")
	TutorialGame.leave(App.gs)


func _events_once() -> void:
	var d := await _draft()
	await _until_mine(d, "ban")
	_events.clear()
	var hid := String(d.grid.shown_ids()[0])
	d._open_sheet(hid)
	await frames(3)
	ok(_ev("draft:sheet") == 1 and String(_events[_events.size() - 1][1].get("kind", "")) == "ban", "events: draft:sheet once, kind ban")
	d.sheet_confirm.pressed.emit()
	await frames(3)
	ok(_ev("draft:ban") == 1 and not BottomSheet.is_open(), "events: Ban raises draft:ban once and closes the sheet")
	await _until_mine(d, "pick")
	_events.clear()
	d._open_sheet(String(d.grid.shown_ids()[0]))
	await frames(3)
	d.sheet_confirm.pressed.emit()
	await frames(3)
	ok(_ev("draft:sheet") == 1 and _ev("draft:pick") == 1, "events: a pick through the sheet raises draft:sheet and draft:pick once each")
	await _until_mine(d, "pick")
	_events.clear()
	(d.take_button as Button).pressed.emit()
	await frames(2)
	ok(_ev("draft:pick") == 1 or _ev("draft:ban") == 1, "events: Take raises draft:pick (or draft:ban) once")
	_events.clear()
	d._auto_rest()
	await frames(2)
	d._refresh()
	await frames(2)
	ok(_ev("draft:done") == 1, "events: draft:done once, however often the done view refreshes")


func _auto() -> void:
	var d := await _draft()
	await _until_mine(d)
	(d.auto_button as Button).pressed.emit()
	await frames(1)
	ok(UI.plain(d.auto_button.text) == UI.plain(Strings.t("draft.auto_sure")) and not d.draft.is_done(), "auto: one tap arms Sure?, nothing is decided")
	d._process(ScreenDraft.SURE_S + 0.2)
	await frames(1)
	ok(UI.plain(d.auto_button.text) == UI.plain(Strings.t("draft.auto_rest")), "auto: Sure? goes back after 3 s")
	(d.auto_button as Button).pressed.emit()
	await frames(1)
	(d.auto_button as Button).pressed.emit()
	await frames(2)
	ok(d.draft.is_done(), "auto: a second tap within 3 s lets the Coach finish the draft")
	# the tutorial step holds Sure?
	await _boot()
	var d2 := await _draft()
	await _until_mine(d2)
	App.gs.set_tutorial({"v": 1, "state": "running", "step": "coach_rest", "game": {"live": false, "n": 1, "plan": {}}})
	App.tutorial.bind()
	await frames(2)
	(d2.auto_button as Button).pressed.emit()
	await frames(1)
	d2._process(10.0)
	await frames(1)
	ok(UI.plain(d2.auto_button.text) == UI.plain(Strings.t("draft.auto_sure")), "auto: while tutorial step 15 is up, Sure? holds past 3 s")
	var cb: Callable = App.tutorial._shortcuts.get("draft_auto_finish", Callable())
	ok(cb.is_valid(), "auto: the Draft registers the draft_auto_finish shortcut")
	if cb.is_valid():
		cb.call()
	await frames(2)
	ok(d2.draft.is_done(), "auto: the card's one-tap button finishes the draft through the same path")


func _inplace() -> void:
	var d := await _draft()
	await _until_mine(d, "pick")
	var ids := [d.get_instance_id(), d.board.get_instance_id(), d.grid.get_instance_id(), d.filter.get_instance_id(), d.coach_bar.get_instance_id()]
	var nodes0 := _count(d)
	d.filter.press(d.filter.index_of("mid"))
	d._open_sheet(String(d.grid.shown_ids()[0]))
	await frames(3)
	var open := d.draft.open_slots(d.my_side)
	d.sheet_slot.press(d.sheet_slot.index_of(String(open[open.size() - 1])))
	d.sheet_confirm.pressed.emit()
	await frames(3)
	await _until_mine(d, "pick")
	if not d.draft.is_done():
		(d.take_button as Button).pressed.emit()
	d.filter.press(0)
	await frames(3)
	var ids2 := [d.get_instance_id(), d.board.get_instance_id(), d.grid.get_instance_id(), d.filter.get_instance_id(), d.coach_bar.get_instance_id()]
	ok(_cur() == d and ids == ids2 and d.build_count == 1, "inplace_draft: six taps, the same screen, board, grid, filter and Coach bar (built once)")
	ok(absi(_count(d) - nodes0) <= 0, "inplace_draft: no node was built or freed by the taps (%d -> %d)" % [nodes0, _count(d)])


func _back() -> void:
	var d := await _draft()
	d.go_back()
	await frames(4)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "draft_leave" and _cur() == d, "back: a running draft asks first (Leave the draft?)")
	await _close_sheet()
	ok(_cur() == d, "back: Stay keeps the draft")
	d._leave()
	await frames(3)
	ok(_cur() is ScreenPreMatch, "back: Leave goes to Match day")
	var tg := TutorialGame.start(App.gs)
	App.gs.set_tutorial({"v": 1, "state": "running", "step": "ban", "game": {"live": true, "n": 1, "plan": {}}})
	App.tutorial.bind()
	App.tutorial.set_game_live(true)
	var t := await _draft(tg)
	t._leave()
	await frames(3)
	ok(not TutorialGame.is_live(App.gs) and App.tutorial.m.game()["live"] == false, "back: leaving the tutorial game's draft drops its sandbox")


func _cb() -> void:
	App.set_colorblind(true)
	var d := await _draft()
	await _until_mine(d, "pick")
	var cues := {}
	for hid in d.grid.heroes.map(func(h: Dictionary) -> String: return h["id"]):
		var c := d.grid.cue_for(hid)
		var s := d.grid.state_name_of(hid)
		if c != "":
			cues[s if not bool(d.grid.state_of(hid).get("rec", false)) else "rec"] = c
	ok(cues.has("banned") and String(cues["banned"]).contains("cross"), "cb_draft: banned heroes carry a cross and a word (%s)" % str(cues.get("banned", "")))
	ok(cues.has("rec") and String(cues["rec"]).contains("star"), "cb_draft: the Coach's choice carries a star")
	ok(cues.has("them") and String(cues["them"]).contains("hexagon"), "cb_draft: their picks carry the hexagon badge")
	d._time_left = 2.5
	d._last_second = -1
	d._show_time()
	ok(CompKit.cue_of(d.timer).contains("!"), "cb_draft: the urgent timer shows a ! mark, not only a colour")
	ok(CompKit.cue_of(d.filter) != "" and CompKit.cue_of(d.board) != "", "cb_draft: the filter and the board carry cues")
	App.set_colorblind(false)


func _shown_ok(step: String) -> bool:
	var o := App.tutorial.overlay
	return o != null and is_instance_valid(o) and o.step_id == step and (o.mode == "shown" or o.mode == "fallback")


func _tags() -> void:
	var tg := TutorialGame.start(App.gs)
	App.gs.set_tutorial({"v": 1, "state": "running", "step": "ban", "game": {"live": true, "n": 1, "plan": {}}})
	App.tutorial.bind()
	App.tutorial.set_game_live(true)
	var d := await _draft(tg)
	await _until_mine(d, "ban")
	App.tutorial.bind()
	for id in ["draft.choices", "draft.hero_grid", "draft.auto_rest", "draft.board", "draft.filter"]:
		ok(UI.find_tag(id) != null and UI.find_tag(id).is_visible_in_tree(), "tags_draft: %s is there" % id)
	ok(await until(func(): return _shown_ok("ban")) and App.tutorial.overlay.mode == "shown", "tags_draft: step 12 (ban) finds draft.choices")
	d._open_sheet(String(d.grid.shown_ids()[0]))
	await frames(4)
	ok(await until(func(): return App.tutorial.overlay.mode == "shown" and App.tutorial.m.stage == "b") and App.tutorial.overlay.mode == "shown", "tags_draft: step 12 stage B finds draft.sheet.confirm in the sheet")
	d.sheet_confirm.pressed.emit()
	await frames(4)
	await _until_mine(d, "pick")
	ok(await until(func(): return _shown_ok("pick")) and App.tutorial.overlay.mode == "shown", "tags_draft: step 13 (pick) finds draft.choices")
	d._open_sheet(String(d.grid.shown_ids()[0]))
	await frames(4)
	ok(await until(func(): return _shown_ok("role")) and App.tutorial.overlay.mode == "shown", "tags_draft: step 14 (role) finds draft.slot_list and draft.sheet.confirm")
	d.sheet_confirm.pressed.emit()
	await frames(4)
	ok(await until(func(): return _shown_ok("coach_rest")) and App.tutorial.overlay.mode == "shown", "tags_draft: step 15 (Auto-finish) finds draft.auto_rest")
	(d.auto_button as Button).pressed.emit()
	await frames(2)
	(d.auto_button as Button).pressed.emit()
	await frames(4)
	ok(d.draft.is_done() and await until(func(): return _shown_ok("open_plan")) and App.tutorial.overlay.mode == "shown", "tags_draft: step 16 finds draft.game_plan on the done view")
	ok(App.tutorial.fallbacks == 0, "tags_draft: no fallback card in steps 12 to 16 (%d)" % App.tutorial.fallbacks)
	TutorialGame.leave(App.gs)
