extends Node
## I-19 checks on the REAL Squad (screen_roster.gd), headless:
##   build_squad / fit_squad_<v>  the page, the bench end, the lane picker, the player sheet (Overview, Stats, Career), the release
##                    confirm and the Match-day variant build in normal and large text: built once; no control leaves the frame; no
##                    drawn text is cut (pills, tokens, bench cards, picker rows, sheet head, stats, status); buttons at least 96 px
##                    high; nodes under 120
##   tokens_<v>       the five tokens are 96 px at the ART-BIBLE 6.4 anchors, inside the map, apart from each other (all five
##                    reachable in large text too)
##   equivalence      20 random rosters: a sequence of picker taps and Auto lineup on the real screen leaves the same lineup as
##                    the same choices through the old methods (gs.assign, gs.reset_lineup)
##   preview          every picker row's "Team +x" equals the team rating after that swap, minus the rating before
##   undo             Undo after a pick and after Auto lineup puts the lineup back
##   inplace_squad    30 taps of every kind: no rebuild, the same tokens and bench cards
##   events_squad     a bench card opens the player sheet (open:player_card once), a token the picker (open:lane_picker once);
##                    the starter's own row in the picker opens his sheet; Put in lineup opens the picker of his best role
##   release          the confirm sheet says the cost, Release removes the player; a blocked release says why
##   matchday         Pre-match's Change lineup opens the Squad without the tab bar and Done goes back to Pre-match
##   cb_squad         tired and in-form tokens carry an arrow, picker deltas an arrow and a sign, off-role a word
##   tags_squad       squad.bench.0 and roster.card.head are there; tutorial steps 5 and 6 find their targets (no fallback)
## Ends with " N checks, M failures".

const TEMP_CFG := "user://squad_test.cfg"

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
	await _preview()
	await _boot()
	await _undo()
	await _boot()
	await _inplace()
	await _boot()
	await _events_squad()
	await _boot()
	await _release()
	await _boot()
	await _matchday()
	await _boot()
	await _cb()
	await _boot()
	await _tags()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_ui_squad: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ helpers
func _boot(seed_value: int = 20261117, club: int = 5) -> void:
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
	App.gs = GameState.new_game(App.world, App.world.club_ids[club], seed_value)
	var r: TutorialRunner = App.tutorial
	r.autosave = false
	r.device = DeviceState.new(TEMP_CFG)
	r.wait_s = 0.4
	r.missing_s = 0.3
	r.bind()
	_events.clear()
	App.bus.raised.connect(func(n: String, d: Dictionary) -> void: _events.append([n, d]))


func _squad(from: String = "hub", g: Dictionary = {}) -> ScreenRoster:
	var r := ScreenRoster.new(from, g)
	App.go(r)
	await frames(4)
	return r


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


func _cards(root: Node) -> Array:
	return root.find_children("*", "PlayerCard", true, false)


func _cut(r: ScreenRoster) -> Array:
	var out: Array = []
	for t in r.pills.clipped():
		out.append("pills: " + String(t))
	var roots: Array = [r]
	if BottomSheet.is_open():
		roots.append(BottomSheet.current())
	for root in roots:
		for c in _cards(root):
			var pc := c as PlayerCard
			if pc.is_visible_in_tree():
				for t in pc.clipped:
					out.append("%s: %s" % [pc.player_name(), String(t)])
	if r.card_stats != null and is_instance_valid(r.card_stats) and r.card_stats.is_visible_in_tree():
		for t in r.card_stats.clipped():
			out.append("stats: " + String(t))
	if BottomSheet.is_open():
		for st in BottomSheet.current().find_children("*", "Control", true, false):
			if st is SquadKit.Status:
				for t in (st as SquadKit.Status).clipped():
					out.append("status: " + String(t))
	return out


func _redraw_all(r: ScreenRoster) -> void:
	r.pills.queue_redraw()
	r.map.queue_redraw()
	r.bench.queue_redraw()
	if BottomSheet.is_open():
		for c in BottomSheet.current().find_children("*", "Control", true, false):
			(c as Control).queue_redraw()
	await frames(3)


func _fit_state(r: ScreenRoster, v: String, st: String) -> void:
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
	ok(outside.is_empty(), "fit_squad_%s_%s: no control leaves the %d px frame %s" % [v, st, int(vp.size.x), str(outside.slice(0, 3))])
	var cut := _cut(r)
	ok(cut.is_empty(), "fit_squad_%s_%s: no drawn text is cut %s" % [v, st, str(cut)])
	var short: Array = []
	for root in roots:
		for b in (root as Node).find_children("*", "BaseButton", true, false):
			var bb := b as BaseButton
			if bb.is_visible_in_tree() and bb.size.y < float(UI.BTN_H) - 0.5:
				short.append("%s %.0f" % [bb.name, bb.size.y])
	ok(short.is_empty(), "fit_squad_%s_%s: every button is at least 96 px high %s" % [v, st, str(short)])
	ok(_count(r) <= 120, "build_squad_%s_%s: %d nodes (target 120)" % [v, st, _count(r)])


# ------------------------------------------------------------------ rows
func _build_and_fit(v: String) -> void:
	App.apply_large_text(v == "large")
	await frames(3)
	var r := await _squad()
	ok(r.build_count == 1, "build_squad_%s: the screen builds once" % v)
	await _fit_state(r, v, "closed")
	# the tokens
	var rects: Array = []
	var in_map := true
	var at_anchor := true
	var mr := r.map.get_global_rect()
	for s in GameState.SLOTS:
		var t := r.map.tokens[s] as PlayerCard
		var gr := t.get_global_rect()
		rects.append(gr)
		in_map = in_map and mr.grow(0.5).encloses(gr)
		at_anchor = at_anchor and t.size == Vector2(96, 96) and (t.position + t.size * 0.5).distance_to(r.map.anchor(s)) < 0.6 and t.pid == String(App.gs.d["lineup"][s])
	var apart := true
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			apart = apart and not (rects[i] as Rect2).intersects(rects[j])
	ok(at_anchor and in_map and apart, "tokens_%s: five 96 px tokens at the ART-BIBLE anchors, inside the map, apart (map %s)" % [v, str(mr.size)])
	r.page_scroll.scroll_vertical = 100000
	await frames(3)
	ok(get_viewport().get_visible_rect().encloses(r.find_button.get_global_rect()), "build_squad_%s_lower: Find a player is at the end of the bench" % v)
	await _fit_state(r, v, "lower")
	r.page_scroll.scroll_vertical = 0
	r._toggle_slot("mid")
	await frames(6)
	ok(r.picker_rows != null and r.picker_rows.get_child_count() == App.world.club_players(App.gs.club()).size(), "build_squad_%s_picker: a row per player of the club" % v)
	await _fit_state(r, v, "picker")
	await _close_sheet()
	var pid := String(r.bench_ids()[0])
	r._toggle_player(pid)
	await frames(6)
	for tab in ["overview", "stats", "career"]:
		r._set_card_tab(tab)
		await frames(3)
		ok(r._card_tab == tab and r.card_box.get_child_count() > 0, "build_squad_%s_card_%s: the %s tab shows" % [v, tab, tab])
		await _fit_state(r, v, "card_" + tab)
	r._ask_release(pid)
	await frames(6)
	await _fit_state(r, v, "release")
	await _close_sheet()


## The same choices through the old methods, on a fresh game with the same seed, and compared.
func _equivalence() -> void:
	var same := 0
	var n := 20
	var rng := RandomNumberGenerator.new()
	for k in n:
		var seed_value := 5100 + k * 29
		var club := k % 10
		await _boot(seed_value, club)
		var r := await _squad()
		rng.seed = 777 + k
		var acts: Array = []
		for step in 8:
			if rng.randi_range(0, 5) == 0:
				acts.append(["auto"])
				r.auto_button.pressed.emit()
				await frames(1)
				continue
			var slot := String(GameState.SLOTS[rng.randi_range(0, 4)])
			r._toggle_slot(slot)
			await frames(2)
			var rows := r.picker_rows.get_children()
			var pick := rows[rng.randi_range(0, rows.size() - 1)] as PlayerCard
			acts.append(["assign", slot, pick.pid])
			pick.pressed.emit()
			await frames(2)
			if BottomSheet.is_open():
				await _close_sheet()    # the starter's own row opened his sheet: nothing changed
		var real: Dictionary = (App.gs.d["lineup"] as Dictionary).duplicate()
		await _clear_toasts()
		await _boot(seed_value, club)
		for a in acts:
			if a[0] == "auto":
				App.gs.reset_lineup()
			else:
				App.gs.assign(String(a[1]), String(a[2]))
		if JSON.stringify(real) == JSON.stringify(App.gs.d["lineup"]):
			same += 1
		else:
			print("  roster %d: real %s old %s" % [k, JSON.stringify(real), JSON.stringify(App.gs.d["lineup"])])
	ok(same == n, "equivalence: %d of %d rosters end with the same lineup as the old methods" % [same, n])


func _preview() -> void:
	var r := await _squad()
	var bad: Array = []
	var rows := 0
	for s in GameState.SLOTS:
		for row in r.picker_data(s):
			rows += 1
			var keep: Dictionary = (App.gs.d["lineup"] as Dictionary).duplicate()
			var before := r.team_rating()
			App.gs.assign(s, String(row["pid"]))
			var after := r.team_rating()
			App.gs.d["lineup"] = keep
			if absf((after - before) - float(row["delta"])) > 1e-6:
				bad.append("%s %s" % [s, row["pid"]])
	ok(bad.is_empty() and rows >= 50, "preview: every picker row's change in team rating equals the rating after the swap (%d rows) %s" % [rows, str(bad.slice(0, 3))])
	r._toggle_slot("top")
	await frames(4)
	var shown_ok := true
	for c in r.picker_rows.get_children():
		var pc := c as PlayerCard
		var chips: Array = pc.opts["chips"]
		var d := 0.0
		for row in r.picker_data("top"):
			if String(row["pid"]) == pc.pid:
				d = float(row["delta"])
		var want := "0.0" if absf(d) < 0.05 else "%+.1f" % d
		if String(App.gs.d["lineup"]["top"]) != pc.pid:
			shown_ok = shown_ok and UI.plain(String(chips[0]["text"])) == UI.plain(Strings.f("squad.delta", {"delta": want}))
	ok(shown_ok, "preview: each row shows that change as Team +x (never -0.0)")


func _undo() -> void:
	var r := await _squad()
	var before: Dictionary = (App.gs.d["lineup"] as Dictionary).duplicate()
	var pid := String(r.bench_ids()[0])
	r._assign("mid", pid)
	ok(App.gs.d["lineup"]["mid"] == pid and (r.map.tokens["mid"] as PlayerCard).pid == pid, "undo: a pick puts the player on the Mid token")
	r._undo_last()
	ok(App.gs.d["lineup"] == before and (r.map.tokens["mid"] as PlayerCard).pid == String(before["mid"]), "undo: Undo puts the lineup and the token back")
	r._assign("top", String(before["bot"]))
	var swapped: Dictionary = (App.gs.d["lineup"] as Dictionary).duplicate()
	ok(swapped["top"] == before["bot"] and swapped["bot"] == before["top"], "undo: picking a starter elsewhere swaps the two")
	r._auto()
	r._undo_last()
	ok(App.gs.d["lineup"] == swapped, "undo: Undo after Auto lineup puts the lineup back")
	var toast_ok := false
	for tc in App.main._toasts.get_children():
		toast_ok = toast_ok or tc.has_meta("squad_undo")
	ok(toast_ok, "undo: the toasts carry Undo")
	App.go_tab("home")
	await frames(3)
	var left := 0
	for tc in App.main._toasts.get_children():
		if tc.has_meta("squad_undo") and not tc.is_queued_for_deletion():
			left += 1
	ok(left == 0, "undo: leaving the Squad removes its Undo toasts")


func _inplace() -> void:
	var r := await _squad()
	var tokens: Array = []
	for s in GameState.SLOTS:
		tokens.append((r.map.tokens[s] as Object).get_instance_id())
	var bench_first := (r.bench.get_child(0) as Object).get_instance_id()
	for i in 30:
		match i % 5:
			0:
				r._toggle_slot(String(GameState.SLOTS[i % 5]))
			1:
				if r.picker_rows != null:
					(r.picker_rows.get_child(i % r.picker_rows.get_child_count()) as PlayerCard).pressed.emit()
			2:
				(r.bench.get_child(0) as PlayerCard).pressed.emit()
			3:
				r._set_card_tab(["overview", "stats", "career"][i % 3])
			4:
				r._auto()
		await frames(2)
		if i % 5 == 4 or i % 5 == 3:
			await _close_sheet()
	var tokens2: Array = []
	for s in GameState.SLOTS:
		tokens2.append((r.map.tokens[s] as Object).get_instance_id())
	ok(r.rebuild_count == 0 and r.build_count == 1 and tokens2 == tokens and (r.bench.get_child(0) as Object).get_instance_id() == bench_first,
			"inplace_squad: 30 taps, no rebuild, the same tokens and bench cards (refreshes %d)" % r.refresh_count)
	await _clear_toasts()


func _events_squad() -> void:
	var r := await _squad()
	_events.clear()
	(r.bench.get_child(0) as PlayerCard).pressed.emit()
	await frames(4)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "player_card" and _ev("open:player_card") == 1, "events_squad: a bench card opens the player sheet (open:player_card once)")
	await frames(4)
	ok(not r.bench.visible and r.occluded.has(r.bench), "events_squad: the bench under the open player sheet is not drawn (occlusion)")
	BottomSheet.current().panel.position.y += 2000.0    # as if dragged down: the page must show again before anything is uncovered
	await frames(2)
	ok(r.bench.visible and r.occluded.is_empty(), "events_squad: dragging the sheet down shows the page again at once")
	BottomSheet.current().panel.position.y -= 2000.0
	var pid := String(r._open_player)
	r._put_in(pid)
	await frames(4)
	var best := ScreenRoster.best_slot(App.world, App.world.players[pid])
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "lane_picker" and r._pick_slot == best, "events_squad: Put in lineup opens the picker of the player's best role (%s)" % best)
	await _close_sheet()
	_events.clear()
	(r.map.tokens["jg"] as PlayerCard).pressed.emit()
	await frames(4)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "lane_picker" and _ev("open:lane_picker") == 1 and (r.map.tokens["jg"] as PlayerCard).selected, "events_squad: a token opens the lane picker (open:lane_picker once) and is marked")
	var cur_row: PlayerCard = null
	for c in r.picker_rows.get_children():
		if (c as PlayerCard).pid == String(App.gs.d["lineup"]["jg"]):
			cur_row = c
	cur_row.pressed.emit()
	await frames(4)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "player_card" and r._open_player == String(App.gs.d["lineup"]["jg"]), "events_squad: the starter's own row opens his player sheet")
	App.main.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(20)
	ok(not BottomSheet.is_open() and _cur() == r and not (r.map.tokens["jg"] as PlayerCard).selected, "events_squad: Android back closes the sheet first")
	r.pills.press(1)
	await frames(3)
	ok(_cur() is ScreenChemistry, "events_squad: the chemistry pill opens Team chemistry")


func _release() -> void:
	var r := await _squad()
	var cut := ""
	for pid in r.bench_ids():
		if App.gs.can_release(String(pid)) == "":
			cut = String(pid)
	var size0 := (App.gs.d["roster"] as Array).size()
	r._toggle_player(cut)
	await frames(4)
	r._ask_release(cut)
	await frames(6)
	var text := ""
	for l in BottomSheet.current().find_children("*", "Label", true, false):
		text += UI.plain((l as Label).text)
	ok(text.contains(UI.plain(PlayerView.money(App.gs.release_cost(cut)))), "release: the confirm sheet says the cost")
	(UI.find_tag("release.yes") as Button).pressed.emit()
	await frames(20)
	ok((App.gs.d["roster"] as Array).size() == size0 - 1 and not r.bench_ids().has(cut) and not BottomSheet.is_open(), "release: Release removes the player from the squad and the bench")
	var start := String(App.gs.d["lineup"]["mid"])
	var why := App.gs.can_release(start)
	r._ask_release(start)
	await frames(6)
	var t2 := ""
	for l in BottomSheet.current().find_children("*", "Label", true, false):
		t2 += UI.plain((l as Label).text)
	ok(why == "" or (t2.contains(UI.plain(Strings.t("release.block." + why))) and UI.find_tag("release.yes") == null), "release: a blocked release says why and has no Yes (%s)" % why)
	await _close_sheet()


func _matchday() -> void:
	var g: Dictionary = App.gs.next_game()
	var pm := ScreenPreMatch.new(g)
	App.go(pm)
	await frames(4)
	var change: Button = null
	for b in pm.find_children("*", "Button", true, false):
		if UI.plain((b as Button).text) == UI.plain(Strings.t("pre.change_lineup")):
			change = b
	ok(change != null, "matchday: Pre-match has Change lineup")
	if change == null:
		return
	change.pressed.emit()
	await frames(4)
	var r := _cur() as ScreenRoster
	ok(r != null and r.tab_id() == "" and r.done_button != null and r.done_button.is_visible_in_tree(), "matchday: the Squad opens without the tab bar, with Done")
	r.done_button.pressed.emit()
	await frames(4)
	ok(_cur() is ScreenPreMatch, "matchday: Done goes back to Pre-match")


func _cb() -> void:
	var w := App.world
	var gs := App.gs
	var pid := String(gs.d["lineup"]["top"])
	w.fatigue[pid] = 60.0    # a tired starter (display only: the test reads the token, nothing is played)
	var r := await _squad()
	var t := r.map.tokens["top"] as PlayerCard
	ok(String(t.opts["status"]) == "down", "cb_squad: a tired starter's token carries the down arrow (fatigue %.0f)" % w.fatigue_of(pid))
	r._toggle_slot("sup")
	await frames(4)
	var arrows := true
	var offrole := false
	for c in r.picker_rows.get_children():
		var chips: Array = (c as PlayerCard).opts["chips"]
		if (c as PlayerCard).pid != String(gs.d["lineup"]["sup"]):
			arrows = arrows and String(chips[0]["icon"]).begins_with("arrow_")
		for ch in chips:
			offrole = offrole or String(ch["text"]) == Strings.t("roster.offrole")
	ok(arrows and offrole, "cb_squad: picker deltas carry an arrow and a sign; off-role players say so in words")
	await _close_sheet()


func _shown_ok(step: String) -> bool:
	var o := App.tutorial.overlay
	return o != null and is_instance_valid(o) and o.step_id == step and (o.mode == "shown" or o.mode == "fallback")


func _tags() -> void:
	App.gs.set_tutorial({"v": 1, "state": "running", "step": "squad_bench", "game": {"live": false, "n": 0, "plan": {}}})
	App.tutorial.bind()
	App.go_tab("squad")
	await frames(6)
	var r := _cur() as ScreenRoster
	ok(UI.find_tag("squad.bench.0") != null and UI.find_tag("squad.bench.0").is_visible_in_tree(), "tags_squad: squad.bench.0 is there")
	ok(await until(func(): return _shown_ok("squad_bench")) and App.tutorial.overlay.mode == "shown", "tags_squad: step 5 finds squad.bench.0")
	(r.bench.get_child(0) as PlayerCard).pressed.emit()
	await frames(6)
	ok(await until(func(): return _shown_ok("player_card")) and App.tutorial.overlay.mode == "shown" and UI.find_tag("roster.card.head") != null, "tags_squad: step 6 finds roster.card.head in the player sheet")
	App.tutorial._on_button("next")
	await frames(20)
	ok(not BottomSheet.is_open() and App.tutorial.m.step_id() == "tab_plan", "tags_squad: Next closes the sheet and the guide moves on (%s)" % App.tutorial.m.step_id())
	ok(App.tutorial.fallbacks == 0, "tags_squad: no fallback card in steps 5 and 6 (%d)" % App.tutorial.fallbacks)
