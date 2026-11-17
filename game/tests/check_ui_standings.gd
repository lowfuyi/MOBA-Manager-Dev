extends Node
## I-20 checks on the REAL Standings (screen_standings.gd), headless:
##   build_stand / fit_stand_<v>  Table (Points and Form Rating), the Playoffs view before and during the playoffs, History (empty and
##                    full) build in normal and large text: built once; no control leaves the frame; no drawn text is cut (views,
##                    metric, podium, rows, pinned row, bracket, games); nodes under 120
##   order            the table order equals gs.standings() (Points) and gs.form_ranking() (Form Rating) on 20 saves at different
##                    points of a season
##   own              your row is marked by the YOU pill and the bar (a shape and a word), in the podium too; the pinned row shows
##                    only while your row is out of view and carries the cut sentence
##   names            a 19-character club name is not cut in the table, the podium or the bracket
##   labels           Table, Playoffs, History and Points, Form Rating never break or cut (normal and large text)
##   line             the dashed playoff line sits after 4th in Points, not in Form Rating
##   old_tabs         "form", "results" and "trophies" open the right view (Club's Form Rating tile, older callers)
##   events_stand     switching the metric raises stand:metric once; the same metric again raises nothing
##   tags_stand       stand.metric is there; tutorial step 26 finds it and switching to Points completes it (no fallback)
## Ends with " N checks, M failures".

const TEMP_CFG := "user://standings_test.cfg"
const ShotsSt = preload("res://tests/shots/shots_standings.gd")

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
	await _order()
	await _boot()
	await _own()
	await _boot()
	await _names()
	await _boot()
	await _old_tabs()
	await _boot()
	await _events_stand()
	await _boot()
	await _tags()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_ui_standings: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _boot(seed_value: int = 20261117, club: int = 5) -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
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


func _stand(tab: String = "table") -> ScreenStandings:
	var s := ScreenStandings.new(tab)
	App.go(s)
	await frames(5)
	return s


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


func _rows(s: ScreenStandings) -> Array:
	return s.rows.get_children().filter(func(c: Node) -> bool: return c is RankRow and (c as RankRow).visible)


func _cut(s: ScreenStandings) -> Array:
	var out: Array = []
	for t in s.views.clipped():
		out.append("views: " + String(t))
	if s.metric.is_visible_in_tree():
		for t in s.metric.clipped():
			out.append("metric: " + String(t))
	if s.podium.is_visible_in_tree():
		for t in s.podium.clipped:
			out.append("podium: " + String(t))
	for r in _rows(s):
		if (r as RankRow).is_visible_in_tree():
			for t in (r as RankRow).clipped:
				out.append("row: " + String(t))
	if s.pinned.visible:
		for t in s.pinned.clipped:
			out.append("pinned: " + String(t))
	if s.bracket.is_visible_in_tree():
		for t in s.bracket.clipped():
			out.append("bracket: " + String(t))
	if s.games.is_visible_in_tree():
		for t in s.games.clipped():
			out.append("games: " + String(t))
	return out


func _redraw(s: ScreenStandings) -> void:
	for c in [s.views, s.metric, s.podium, s.rows, s.pinned, s.bracket, s.games]:
		(c as Control).queue_redraw()
	await frames(4)


func _fit(s: ScreenStandings, v: String, st: String) -> void:
	await _redraw(s)
	var vp := get_viewport().get_visible_rect()
	var outside: Array = []
	for c in s.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.is_visible_in_tree() and ctl.size.x > 0.0 and not (ctl is ScrollBar):
			var gr := ctl.get_global_rect()
			if gr.position.x < -0.5 or gr.end.x > vp.size.x + 0.5:
				outside.append("%s %s" % [ctl.name, str(gr)])
	ok(outside.is_empty(), "fit_stand_%s_%s: no control leaves the frame %s" % [v, st, str(outside.slice(0, 3))])
	var cut := _cut(s)
	ok(cut.is_empty(), "fit_stand_%s_%s: no drawn text is cut %s" % [v, st, str(cut)])
	ok(_count(s) <= 120, "build_stand_%s_%s: %d nodes (target 120)" % [v, st, _count(s)])


func _build_and_fit(v: String) -> void:
	App.apply_large_text(v == "large")
	await frames(3)
	var s := await _stand()
	ok(s.build_count == 1, "build_stand_%s: the screen builds once" % v)
	await _fit(s, v, "table_start")
	ok(s.table_box.visible and not s.po_box.visible and not s.hist_box.visible, "build_stand_%s: only the table view shows" % v)
	s._set_tab("history")
	await frames(3)
	ok(s.empty_label.is_visible_in_tree() and not s.games.is_visible_in_tree(), "build_stand_%s_history_empty: no games yet says so" % v)
	await _fit(s, v, "history_empty")
	ShotsSt.play(App.gs, 4)
	s._set_tab("table")
	await frames(3)
	await _fit(s, v, "table")
	s._set_metric("form")
	await frames(3)
	await _fit(s, v, "form")
	s._set_tab("playoffs")
	await frames(3)
	ok(s.bracket.ghost, "build_stand_%s_ghost: during the league the bracket is the dashed projection" % v)
	await _fit(s, v, "ghost")
	App.gs.autoplay(true)
	var s2 := await _stand("playoffs")
	ok(not s2.bracket.ghost and s2.bracket.series.size() == 3, "build_stand_%s_final: after the playoffs the bracket shows the three series" % v)
	await _fit(s2, v, "final")
	s2._set_tab("history")
	await frames(3)
	ok(s2.games.is_visible_in_tree() and s2.games.games.size() == (App.gs.d["history"] as Array).size(), "build_stand_%s_history: a row per stored game" % v)
	await _fit(s2, v, "history")


func _order() -> void:
	var same := 0
	var n := 20
	for k in n:
		await _boot(3300 + k * 17, k % 10)
		ShotsSt.play(App.gs, k * 2)
		var s := await _stand()
		var want: Array = App.gs.standings().map(func(r: Dictionary) -> String: return String(r["club"]))
		var got: Array = s.podium.rows.map(func(r: Dictionary) -> String: return String(r["club"]))
		for r in _rows(s):
			got.append((r as RankRow).club_id())
		var ok_pts := got == want
		s._set_metric("form")
		await frames(2)
		var want_f: Array = App.gs.form_ranking().map(func(r: Dictionary) -> String: return String(r["club"]))
		var got_f: Array = s.podium.rows.map(func(r: Dictionary) -> String: return String(r["club"]))
		for r in _rows(s):
			got_f.append((r as RankRow).club_id())
		if ok_pts and got_f == want_f:
			same += 1
		else:
			print("  save %d: %s / %s" % [k, str(got), str(want)])
	ok(same == n, "order: %d of %d saves show the table in gs.standings() order and the Form view in gs.form_ranking() order" % [same, n])


func _own() -> void:
	ShotsSt.play(App.gs, 6)
	var s := await _stand()
	var me := App.gs.club()
	var own_rows := 0
	for r in _rows(s):
		if (r as RankRow).is_own():
			own_rows += 1
			ok((r as RankRow).club_id() == me and CompKit.cue_of(r).contains("pill") and CompKit.cue_of(r).contains("bar"), "own: your row carries the YOU pill and the bar (%s)" % CompKit.cue_of(r))
	var in_podium := s.podium.rows.any(func(r: Dictionary) -> bool: return bool(r["own"]))
	ok(own_rows + (1 if in_podium else 0) == 1, "own: exactly one row is yours")
	s.page_scroll.scroll_vertical = 0
	await frames(4)
	var own_ctl: Control = s.podium
	for r in _rows(s):
		if (r as RankRow).is_own():
			own_ctl = r
	var visible := s.page_scroll.get_global_rect().intersects(_core(own_ctl))
	ok(s.pinned.visible == not visible, "own: the pinned row shows exactly when your row is out of view (visible %s, pinned %s)" % [visible, s.pinned.visible])
	s.page_scroll.scroll_vertical = 100000
	await frames(5)
	visible = s.page_scroll.get_global_rect().intersects(_core(own_ctl))
	ok(s.pinned.visible == not visible, "own: scrolled to the end, the pinned row follows (visible %s, pinned %s)" % [visible, s.pinned.visible])
	if s.pinned.visible:
		ok(UI.plain(String(s.pinned.data["note"])) == UI.plain(s.pin_text()), "own: the pinned row says the line sentence")
	var line_after_4 := false
	var kids := s.rows.get_children()
	for i in kids.size():
		if kids[i] is RankRow.Divider and (kids[i] as Control).visible:
			line_after_4 = i == 1 and kids[0] is RankRow and int((kids[0] as RankRow).data["rank"]) == 4
	ok(line_after_4, "line: the dashed playoff line follows 4th in Points")
	s._set_metric("form")
	await frames(2)
	var line_shown := false
	for c in s.rows.get_children():
		line_shown = line_shown or (c is RankRow.Divider and (c as Control).visible)
	ok(not line_shown, "line: no playoff line in Form Rating")


func _names() -> void:
	var long := "Abcdefghij Klmnopqr"    # 19 characters
	ok(long.length() == 19, "names: the test name is 19 characters")
	var keep := {}
	for c in App.world.club_ids:
		keep[c] = App.world.clubs[c]["name"]
		App.world.clubs[c]["name"] = long
	for v in ["normal", "large"]:
		App.apply_large_text(v == "large")
		await frames(3)
		var s := await _stand()
		await _redraw(s)
		ok(_cut(s).is_empty(), "names_%s: 19-character names are not cut in the podium and the table %s" % [v, str(_cut(s))])
		App.gs.autoplay(false)
		var s2 := await _stand("playoffs")
		await _redraw(s2)
		ok(_cut(s2).is_empty(), "names_%s: nor in the bracket %s" % [v, str(_cut(s2))])
		await _boot()
		for c in App.world.club_ids:
			App.world.clubs[c]["name"] = long
	for c in keep:
		App.world.clubs[c]["name"] = keep[c]
	App.apply_large_text(false)


func _old_tabs() -> void:
	var a := await _stand("form")
	ok(a.view() == "table" and a._metric == "form", "old_tabs: \"form\" opens the table on Form Rating")
	var b := await _stand("results")
	ok(b.view() == "history", "old_tabs: \"results\" opens History")
	var c := await _stand("trophies")
	ok(c.view() == "history", "old_tabs: \"trophies\" opens History")
	c._set_tab("form")
	await frames(2)
	ok(c.view() == "table" and c._metric == "form" and c.table_box.visible, "old_tabs: _set_tab(\"form\") still works")


func _events_stand() -> void:
	var s := await _stand()
	_events.clear()
	s.metric.press(s.metric.index_of("form"))
	await frames(2)
	s.metric.press(s.metric.index_of("form"))
	await frames(2)
	ok(_ev("stand:metric") == 1 and s._metric == "form", "events_stand: switching to Form Rating raises stand:metric once (again on the same: nothing)")
	s.views.press(s.views.index_of("history"))
	await frames(2)
	ok(s.view() == "history" and s.hist_box.visible and not s.table_box.visible, "events_stand: a tap on History switches the view in place")


func _shown_ok(step: String) -> bool:
	var o := App.tutorial.overlay
	return o != null and is_instance_valid(o) and o.step_id == step and (o.mode == "shown" or o.mode == "fallback")


func _tags() -> void:
	App.gs.set_tutorial({"v": 1, "state": "running", "step": "form_switch", "game": {"live": false, "n": 0, "plan": {}}})
	App.tutorial.bind()
	var s := await _stand("form")
	App.tutorial.bind()
	ok(UI.find_tag("stand.metric") != null and UI.find_tag("stand.metric").is_visible_in_tree(), "tags_stand: stand.metric is there")
	ok(await until(func(): return _shown_ok("form_switch")) and App.tutorial.overlay.mode == "shown", "tags_stand: step 26 finds stand.metric")
	s.metric.press(s.metric.index_of("points"))
	await frames(6)
	ok(App.tutorial.m.step_id() != "form_switch" and App.tutorial.fallbacks == 0, "tags_stand: switching to Points completes step 26 (now %s), no fallback" % App.tutorial.m.step_id())


func _core(c: Control) -> Rect2:
	var gr := c.get_global_rect().abs()
	return Rect2(gr.position.x, gr.position.y + gr.size.y * 0.25, gr.size.x, gr.size.y * 0.5)
