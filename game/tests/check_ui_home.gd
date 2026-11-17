extends Node
## I-15 checks on the REAL Home (screen_hub.gd), headless, the T-std rows of build plan 3.2:
##   build_home      every state builds (round 1, round 10 with contracts and debt, playoffs, eliminated, season over) with no error;
##                   Home stays under the node target (120) with both carousels
##   fit_home_<v>    normal and large: no control leaves the frame; no drawn text is cut (hero, Next card, chips, attention and
##                   up-next cards, tiles), with the 19-character club and 5-digit cash; buttons at least 96 px high
##   inplace_home    opening the preview, opponent and See all sheets and answering the offer card leave the same Home (no rebuild)
##   cb_home         colour-blind: every state-bearing piece carries a cue (word, arrow, letter, flag); the pips' colours swap
##   tags_home       home.next_card, home.play, home.attention, home.upnext.<i>, home.tile.standing / chem are there and visible;
##                   tutorial step 2 now finds home.next_card (no fallback)
##   paths_home      Play opens Match day for the same game; Auto-play reaches the Report; the card body, an up-next card and
##                   See all open their sheets; an attention card and each tile go to their place; Play is the only coral control;
##                   no old welcome tip; contracts show only from round 9 (D6)
## Ends with " N checks, M failures".

const TEMP_CFG := "user://home_test.cfg"

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
	await _build_and_fit("normal")
	await _boot()    # a fresh round-1 save: the normal pass played this one to the end of the split
	await _build_and_fit("large")
	App.apply_large_text(false)
	await _boot()
	await _inplace()
	await _boot()
	await _cb()
	await _boot()
	await _tags()
	await _boot()
	await _paths()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_ui_home: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ helpers
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
	GameState.delete_save()
	var nr := App.world.club_ids.find("northreach_corsairs")
	App.gs = GameState.new_game(App.world, App.world.club_ids[nr if nr >= 0 else 5], 20261117)
	var r: TutorialRunner = App.tutorial
	r.autosave = false
	r.device = DeviceState.new(TEMP_CFG)
	r.wait_s = 0.4
	r.missing_s = 0.3
	r.bind()


func _home() -> ScreenHub:
	var h := ScreenHub.new()
	App.go(h)
	await frames(4)
	return h


func _cur() -> Node:
	return App.main._current


func _count(n: Node) -> int:
	var t := 1
	for c in n.get_children():
		t += _count(c)
	return t


func _drawn(h: ScreenHub) -> Array:
	var out: Array = [h.hero]
	for n in h.find_children("*", "", true, false):
		if n.has_method("clipped") and not out.has(n):
			out.append(n)
	return out


func _clipped(h: ScreenHub) -> Array:
	var out: Array = []
	for n in _drawn(h):
		var c: Array = n.call("clipped")
		for t in c:
			out.append("%s: %s" % [n.get_class() if n.get_script() == null else String(n.name), t])
	return out


func _play_round(gs: GameState, to_round: int) -> void:
	while int(gs.d["round"]) < to_round and gs.d["phase"] == "league":
		var g := gs.next_game()
		gs.record_human_game(g, gs.auto_game(g))


## Make every drawn piece draw now (headless draws nothing by itself): force a redraw through the drawing calls' own data.
func _force_draw(h: ScreenHub) -> void:
	for n in _drawn(h):
		(n as CanvasItem).queue_redraw()
	await frames(2)


# ------------------------------------------------------------------ rows
func _build_and_fit(variant: String) -> void:
	App.apply_large_text(variant == "large")
	await frames(3)
	var vw := get_viewport().get_visible_rect().size.x
	var gs := App.gs
	var states := ["first", "mid", "debt", "playoffs", "waiting", "done"]
	var po: GameState = null    # a save in the playoffs with the strongest club (it always qualifies)
	for st in states:
		match st:
			"mid":
				_play_round(gs, 9)
				gs.d["cash"] = 48250.0
			"debt":
				gs.d["cash"] = -1200.0
			"playoffs":
				var best := ""
				var best_r := -1.0
				for cid in App.world.club_ids:
					var rt := App.world.team_rating(gs.lineup_for(cid))
					if rt > best_r:
						best_r = rt
						best = cid
				po = GameState.new_game(App.world, best, 4242)
				po.autoplay(false)
				App.gs = po
			"waiting":
				# the same playoffs seen by a club that is in no series: the playoffs go on without it
				var inside: Array = []
				for sr in po.d["playoffs"]["series"]:
					inside.append(sr["a"])
					inside.append(sr["b"])
				for cid in App.world.club_ids:
					if not inside.has(cid):
						po.d["club"] = cid
						break
			"done":
				App.gs = gs
				gs.d["cash"] = 48250.0    # out of debt, so the board does not dismiss the manager on the way
				gs.autoplay(true)
		var h := await _home()
		await _force_draw(h)
		ok(h != null and h.build_count == 1 and h.hero != null and h.next_card != null, "build_home_%s_%s: Home builds (hero and the main card)" % [variant, st])
		var want_play: bool = st in ["first", "mid", "debt", "playoffs"]
		ok((h.play_button != null) == want_play, "build_home_%s_%s: Play %s" % [variant, st, "is there" if want_play else "is not there (no game to play)"])
		if st == "playoffs":
			ok(App.gs.d["phase"] == "playoffs" and String(App.gs.next_game().get("kind", "")) == "playoff", "build_home_%s_playoffs: a real playoff game is next" % variant)
		if st == "waiting":
			ok(_labels(h).contains(UI.plain(Strings.t("hub.waiting"))) and _has_button(h, Strings.t("hub.skip_to_end")), "build_home_%s_waiting: the season-over line and Finish the season" % variant)
		if st == "done":
			ok(_has_button(h, Strings.t("hub.season_summary")), "build_home_%s_done: Season complete with the Season summary button" % variant)
		var nodes := _count(h)
		ok(nodes <= 120, "build_home_%s_%s: %d nodes (target 120)" % [variant, st, nodes])
		var outside: Array = []
		for c in h.find_children("*", "Control", true, false):
			var ctl := c as Control
			if ctl.is_visible_in_tree() and ctl.size.x > 0.0 and not (ctl.get_parent() is Carousel or _inside_carousel(ctl)):
				var r := ctl.get_global_rect()
				if r.position.x < -0.5 or r.end.x > vw + 0.5:
					outside.append("%s %s" % [ctl.name, str(r)])
		ok(outside.is_empty(), "fit_home_%s_%s: no control leaves the %d px frame %s" % [variant, st, int(vw), str(outside.slice(0, 3))])
		var undrawn: Array = []
		for n in _drawn(h):
			if int(n.get("draw_count")) <= 0 and (n as CanvasItem).is_visible_in_tree():
				undrawn.append(String(n.name))
		ok(undrawn.is_empty(), "fit_home_%s_%s: every drawn piece really drew, so the cut-text check means something %s" % [variant, st, str(undrawn)])
		var cut := _clipped(h)
		ok(cut.is_empty(), "fit_home_%s_%s: no drawn text is cut %s" % [variant, st, str(cut)])
		var short: Array = []
		for b in h.find_children("*", "BaseButton", true, false):
			var bb := b as BaseButton
			if bb.is_visible_in_tree() and bb.size.y < float(UI.BTN_H) - 0.5 and not _inside_carousel(bb):
				short.append("%s %.0f" % [bb.name, bb.size.y])
		ok(short.is_empty(), "fit_home_%s_%s: every button is at least 96 px high %s" % [variant, st, str(short)])
		if st == "first":
			ok(h.hero.name_size >= UI.S_HEAD, "fit_home_%s: the 19-character club name is drawn at %d px (steps 48, 40, 36 before a cut)" % [variant, h.hero.name_size])
			ok(h.play_button.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y - float(UI.TAB_H) - 12.0,
					"fit_home_%s: Play is above the fold without scrolling" % variant)
	App.apply_large_text(false)
	await frames(2)


func _labels(root: Node) -> String:
	var out := ""
	for n in root.find_children("*", "Label", true, false):
		out += UI.plain((n as Label).text) + "\n"
	return out


func _has_button(root: Node, text: String) -> bool:
	for b in root.find_children("*", "Button", true, false):
		if UI.plain((b as Button).text) == UI.plain(text) and (b as Button).is_visible_in_tree():
			return true
	return false


func _inside_carousel(c: Node) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is Carousel:
			return true
		p = p.get_parent()
	return false


func _inplace() -> void:
	var gs := App.gs
	_play_round(gs, 9)
	var h := await _home()
	var id0 := h.get_instance_id()
	var hero0 := h.hero.get_instance_id()
	h.next_card.pressed.emit()
	await frames(4)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "home_preview", "inplace_home: the card body opens the Match preview sheet")
	BottomSheet.current().close()
	await frames(20)
	h._open_opponent(0)
	await frames(4)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "home_opponent", "inplace_home: an up-next card opens the opponent sheet")
	BottomSheet.current().close()
	await frames(20)
	h._open_fixtures()
	await frames(4)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "home_fixtures", "inplace_home: See all opens the games-left sheet")
	BottomSheet.current().close()
	await frames(20)
	ok(_cur() == h and h.get_instance_id() == id0 and h.hero.get_instance_id() == hero0 and h.build_count == 1, "inplace_home: the same Home, built once, after three sheets")


func _cb() -> void:
	App.set_colorblind(true)
	var gs := App.gs
	_play_round(gs, 9)
	gs.d["cash"] = -500.0
	var h := await _home()
	await _force_draw(h)
	var missing: Array = []
	for n in h.find_children("*", "", true, false):
		if n is HomeKit.AttentionCard or n is HomeKit.UpNextCard or n is HomeKit.VersusPanel or n is HomeKit.ChipRow or n is HomeKit.CardHead:
			if CompKit.cue_of(n) == "":
				missing.append(String(n.name))
	ok(missing.is_empty(), "cb_home: every state-bearing piece carries a non-colour cue %s" % str(missing))
	var t: Array = h.tiles.tiles()
	ok(CompKit.cue_of(t[1]) != "" and CompKit.cue_of(t[3]) != "", "cb_home: the Cash and Squad mood tiles carry an arrow cue")
	ok(h.last_five().size() == 5 and h.last_five().all(func(x: String) -> bool: return x == "w" or x == "l"), "cb_home: the last five are W / L letters (%s)" % str(h.last_five()))
	ok(UI.GOOD == UI.GOOD_CB and UI.BAD == UI.BAD_CB, "cb_home: the pips draw with the swapped good / bad pair")
	var wds: Array = []
	for n in h.find_children("*", "", true, false):
		if n is HomeKit.UpNextCard:
			wds.append(Strings.t((n as HomeKit.UpNextCard).word_key()))
	ok(not wds.is_empty() and wds.all(func(w: String) -> bool: return w in [Strings.t("home.fav"), Strings.t("home.even"), Strings.t("home.underdog")]), "cb_home: each coming game says Favoured, Even or Underdog in words")
	App.set_colorblind(false)


func _tags() -> void:
	var gs := App.gs
	_play_round(gs, 9)
	var h := await _home()
	for id in ["home.next_card", "home.play", "home.attention", "home.upnext.0", "home.tile.standing", "home.tile.chem", "home.tile.cash", "home.tile.mood"]:
		var c := UI.find_tag(id)
		ok(c != null and c.is_visible_in_tree() and c.get_global_rect().size.x > 0.0, "tags_home: %s is there and visible" % id)
	ok(UI.find_tag("home.play") == h.play_button and UI.find_tag("home.next_card") == h.next_card, "tags_home: home.play is the Play button, home.next_card the raised card")
	# tutorial step 2 on the new Home
	gs.set_tutorial({"v": 1, "state": "running", "step": "home_card", "game": {"live": false, "n": 1, "plan": {}}})
	App.tutorial.bind()
	var shown := await until(func(): return App.tutorial.overlay != null and is_instance_valid(App.tutorial.overlay) and (App.tutorial.overlay.mode == "shown" or App.tutorial.overlay.mode == "fallback"))
	ok(shown and App.tutorial.overlay.mode == "shown" and App.tutorial.fallbacks == 0, "tags_home: tutorial step 2 finds home.next_card on the new Home (no fallback)")
	# large text: the card is taller than the room next to the coach card; the hole is clipped to the screen, never a fallback
	App.apply_large_text(true)
	await frames(3)
	gs.set_tutorial({"v": 1, "state": "running", "step": "home_card", "game": {"live": false, "n": 1, "plan": {}}})
	await _home()
	App.tutorial.bind()
	shown = await until(func(): return App.tutorial.overlay != null and is_instance_valid(App.tutorial.overlay) and (App.tutorial.overlay.mode == "shown" or App.tutorial.overlay.mode == "fallback"))
	var o := App.tutorial.overlay
	var vp := get_viewport().get_visible_rect()
	ok(shown and o.mode == "shown" and App.tutorial.fallbacks == 0, "tags_home: large text, step 2 still finds the card (no fallback)")
	ok(o != null and vp.encloses(o.hole_rect()) and not o.hole_rect().intersects(o.card_rect()), "tags_home: large text, the hole stays on screen and the coach card does not cover it")
	App.apply_large_text(false)
	await frames(3)
	gs.set_tutorial({"v": 1, "state": "done", "step": "finish", "game": {"live": false, "n": 1, "plan": {}}})
	App.tutorial.bind()
	await frames(2)


func _coral_buttons(root: Node) -> Array:
	var out: Array = []
	for b in root.find_children("*", "Button", true, false):
		var sb := (b as Button).get_theme_stylebox("normal")
		if sb is StyleBoxFlat and (sb as StyleBoxFlat).bg_color.is_equal_approx(UI.CORAL) and (b as Button).is_visible_in_tree():
			out.append(b)
	return out


func _paths() -> void:
	var gs := App.gs
	var h := await _home()
	var g := gs.next_game()
	ok(_coral_buttons(h).size() == 1 and _coral_buttons(h)[0] == h.play_button, "paths_home: Play is the only coral control")
	var txt := ""
	for n in h.find_children("*", "Label", true, false):
		txt += UI.plain((n as Label).text) + "\n"
	ok(not txt.contains(UI.plain(Strings.t("tip.hub"))), "paths_home: no old welcome tip on Home")
	ok(h.attention == null, "paths_home: round 1: no contracts card yet (D6: from round 9), nobody tired")
	h.play_button.pressed.emit()
	await frames(4)
	ok(_cur() is ScreenPreMatch and (_cur() as ScreenPreMatch).game.get("id", "") == g.get("id", "x"), "paths_home: Play opens Match day for the same game")
	h = await _home()
	var before_round := int(gs.d["round"])
	(UI.find_tag("home.autoplay") as Button).pressed.emit()
	await frames(4)
	ok(_cur() is ScreenReport and int(gs.d["round"]) == before_round + 1, "paths_home: Auto-play plays the game and opens the Report")
	_play_round(gs, 9)
	h = await _home()
	var att_texts: Array = []
	if h.attention != null:
		for it in h.attention.items:
			att_texts.append(UI.plain((it as HomeKit.AttentionCard).text))
	ok(att_texts.has(UI.plain(Strings.f("home.att.contracts", {"n": gs.expiring().size()}))), "paths_home: round 10: the contracts card shows %s" % str(att_texts))
	h.attention.card_tapped.emit(0)
	await frames(4)
	ok(_cur() is ScreenRoster, "paths_home: an attention card goes to the Squad")
	var want := [ScreenStandings, ScreenFinance, ScreenChemistry, ScreenRoster]
	for k in 4:
		h = await _home()
		var t: HomeKit.StatTile = h.tiles.tiles()[k]
		var cap := t.caption
		t.pressed.emit()
		await frames(4)
		ok(is_instance_of(_cur(), want[k]), "paths_home: tile %d (%s) opens its place" % [k, cap])
	h = await _home()
	var n_rows := gs.upcoming(gs.total_rounds()).size()
	h._open_fixtures()
	await frames(4)
	var sheet := BottomSheet.current()
	var labels := sheet.content.find_children("*", "Label", true, false) if sheet != null else []
	ok(sheet != null and labels.size() == n_rows, "paths_home: See all lists every league game left (%d rows)" % n_rows)
	if sheet != null:
		sheet.close()
	await frames(20)
	h._open_preview(gs.next_game())
	await frames(4)
	sheet = BottomSheet.current()
	labels = sheet.content.find_children("*", "Label", true, false) if sheet != null else []
	ok(sheet != null and labels.size() == GameState.SLOTS.size(), "paths_home: the Match preview lists the five lane matchups")
	if sheet != null:
		sheet.close()
	await frames(20)
