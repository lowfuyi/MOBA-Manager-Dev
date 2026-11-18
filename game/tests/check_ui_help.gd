extends Node
## I-22 checks (TUTORIAL 9 tests 11, 12 and 14), headless, on the real screens:
##   help_ids       every help id of data/help_v1.json has its title, three lines and terms; every term exists; lines at most 20
##                  words, definitions at most 22
##   buttons        the 19 screens with a sheet show the "?" (96 px, in the header slot or the free top-right corner); Title and About
##                  have none
##   sheet          a tap on "?" opens the sheet (open:help), with the screen's title, the three blocks and a word per term; a word
##                  opens its term in place and Back returns; Got it, a tap on the dim and Android back each close it
##   dot            the dot shows until the sheet is opened, clears, and stays cleared after a reload of the device file
##   pause          the Draft timer and the Match playback stand still while the sheet is open and run again after; the match result
##                  is the same whether help was opened or not
##   glossary       49 terms in 4 groups, each with name, definition and a "where" that is a help id; Settings shows Glossary; a
##                  term opens its sheet and "Where to see it" goes to that screen; from a help sheet the glossary opens as a sheet
##                  with the term in place and Back
## Ends with " N checks, M failures".

const TEMP_CFG := "user://help_test.cfg"

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


func _ready() -> void:
	TutorialRunner.home_offers = false
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	_help_ids()
	await _boot()
	await _buttons()
	await _boot()
	await _sheet()
	await _boot()
	await _dot()
	await _boot()
	await _pause()
	await _boot()
	await _glossary()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_ui_help: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _boot() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	if BottomSheet.is_open():
		BottomSheet.current().close()
		await frames(20)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(3)
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], 20261117)
	App.tutorial.autosave = false
	App.tutorial.device = DeviceState.new(TEMP_CFG)
	App.tutorial.bind()
	_events.clear()
	App.bus.raised.connect(func(n: String, d: Dictionary) -> void: _events.append([n, d]))


func _cur() -> Node:
	return App.main._current


func _ev(name: String) -> int:
	var n := 0
	for e in _events:
		if e[0] == name:
			n += 1
	return n


func _close() -> void:
	if BottomSheet.is_open():
		BottomSheet.current().close()
	await frames(20)


func _words(s: String) -> int:
	return s.split(" ", false).size()


func _help_ids() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/en.json"))
	var ids := HelpSheet.ids()
	ok(ids.size() == 20, "help_ids: 20 help sheets (%d)" % ids.size())
	var missing: Array = []
	var long: Array = []
	for id in ids:
		for part in ["title", "see", "do", "know"]:    # terms are optional (Settings has none)
			if not table.has("help.%s.%s" % [id, part]):
				missing.append("%s.%s" % [id, part])
		for part in ["see", "do", "know"]:
			if _words(Strings.t("help.%s.%s" % [id, part])) > 20:
				long.append("%s.%s" % [id, part])
		for t in HelpSheet.terms_of(String(id)):
			if not HelpSheet.term_ids().has(t):
				missing.append("term %s in %s" % [t, id])
	ok(missing.is_empty(), "help_ids: every sheet has its title, lines and terms, every term exists %s" % str(missing))
	ok(long.is_empty(), "help_ids: no help line is over 20 words %s" % str(long))
	var defs_long: Array = []
	for t in HelpSheet.term_ids():
		if _words(Strings.t("gl.%s.def" % t)) > 22:
			defs_long.append(t)
	ok(defs_long.is_empty(), "help_ids: no definition is over 22 words %s" % str(defs_long))


## The screens a player can reach (with the arguments they need) and their help ids.
func _screens() -> Array:
	var gs := App.gs
	var g: Dictionary = gs.next_game()
	var pid := String((gs.d["fa"] as Array)[0])
	return [[ScreenHub.new(), "home"], [ScreenRoster.new("hub"), "squad"], [ScreenPlan.new(), "plan"], [ScreenTraining.new(), "training"],
			[ScreenChemistry.new(), "chemistry"], [ScreenPractice.new(), "practice"], [ScreenPreMatch.new(g), "prematch"],
			[ScreenDraft.new(g), "draft"], [ScreenClub.new(), "club"], [ScreenStandings.new(), "standings"], [ScreenFinance.new(), "finance"],
			[ScreenFreeAgents.new("hub"), "freeagents"], [ScreenNegotiation.new(pid, false, "fa:hub"), "negotiation"], [ScreenSettings.new(), "settings"]]


func _button_of(scr: Node) -> HelpSheet.HelpButton:
	var bs := scr.find_children("*", "Control", true, false).filter(func(c: Node) -> bool: return c is HelpSheet.HelpButton)
	return bs[0] if not bs.is_empty() else null


func _buttons() -> void:
	var bad: Array = []
	for pair in _screens():
		App.go(pair[0])
		await frames(4)
		var b := _button_of(_cur())
		var vp := get_viewport().get_visible_rect()
		if b == null or b.help_id != String(pair[1]) or not b.is_visible_in_tree() or not vp.encloses(b.get_global_rect()) or b.size.x < 95.5:
			bad.append(String(pair[1]))
	ok(bad.is_empty(), "buttons: every screen with a sheet shows its 96 px \"?\" on screen %s" % str(bad))
	# the rest of the flow screens: Game plan, Match, Report (through a played game)
	var g: Dictionary = App.gs.next_game()
	var d := ScreenDraft.new(g)
	App.go(d)
	await frames(3)
	d._auto_rest()
	App.go(ScreenGamePlan.new(g, d.draft))
	await frames(4)
	var gp_ok := _button_of(_cur()) != null and _button_of(_cur()).help_id == "gameplan"
	(_cur() as ScreenGamePlan).go_back()
	await frames(3)
	(_cur() as ScreenDraft)._start_match()
	await frames(4)
	var m_ok := _button_of(_cur()) != null and _button_of(_cur()).help_id == "match"
	(_cur() as ScreenMatch)._skip()
	(_cur() as ScreenMatch)._continue()
	await frames(4)
	var r_ok := _button_of(_cur()) != null and _button_of(_cur()).help_id == "report"
	ok(gp_ok and m_ok and r_ok, "buttons: Game plan, Match and Report show their \"?\" (%s %s %s)" % [gp_ok, m_ok, r_ok])
	App.go(ScreenAbout.new())
	await frames(3)
	ok(_button_of(_cur()) == null, "buttons: About has no \"?\" (no sheet)")


func _sheet() -> void:
	App.go(ScreenRoster.new("hub"))
	await frames(4)
	var b := _button_of(_cur())
	_events.clear()
	b.press()
	await frames(6)
	var sh := BottomSheet.current()
	ok(sh != null and sh.sheet_id == "help" and _ev("open:help") == 1 and UI.plain(sh.title) == UI.plain(Strings.t("help.squad.title")), "sheet: a tap on \"?\" opens the Squad sheet (open:help once)")
	var text := ""
	for l in sh.find_children("*", "Label", true, false):
		text += UI.plain((l as Label).text) + "\n"
	ok(text.contains(UI.plain(Strings.t("help.squad.see"))) and text.contains(UI.plain(Strings.t("help.squad.do"))) and text.contains(UI.plain(Strings.t("help.squad.know"))), "sheet: What you see, What to do and Good to know are there")
	var terms := HelpSheet.terms_of("squad")
	var tb := UI.find_tag("help.term." + String(terms[0])) as Button
	ok(tb != null and UI.find_tag("help.term." + String(terms[terms.size() - 1])) != null, "sheet: a word button per term (%d)" % terms.size())
	tb.pressed.emit()
	await frames(3)
	var t2 := ""
	for l in sh.find_children("*", "Label", true, false):
		t2 += UI.plain((l as Label).text) + "\n"
	ok(t2.contains(UI.plain(Strings.t("gl.%s.def" % terms[0]))) and UI.find_tag("help.term.back") != null, "sheet: a word opens its term in place, with Back")
	(UI.find_tag("help.term.back") as Button).pressed.emit()
	await frames(3)
	ok(UI.find_tag("help.term." + String(terms[0])) != null, "sheet: Back returns to the sheet's words")
	(UI.find_tag("help.got_it") as Button).pressed.emit()
	await frames(20)
	ok(not BottomSheet.is_open(), "sheet: Got it closes it")
	b.press()
	await frames(6)
	BottomSheet.current()._on_scrim_input(_tap_event(true))
	BottomSheet.current()._on_scrim_input(_tap_event(false))
	await frames(20)
	ok(not BottomSheet.is_open() or BottomSheet.current().is_closing, "sheet: a tap on the dim closes it")
	await _close()
	b.press()
	await frames(6)
	App.main.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(20)
	ok(not BottomSheet.is_open() and _cur() is ScreenRoster, "sheet: Android back closes it, the screen stays")


func _tap_event(pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = Vector2(300, 100)
	e.global_position = Vector2(300, 100)
	return e


func _dot() -> void:
	App.tutorial.device.help_reset()
	App.go(ScreenClub.new())
	await frames(4)
	var b := _button_of(_cur())
	ok(not b.seen() and CompKit.cue_of(b).contains("dot"), "dot: a never-opened sheet shows the dot")
	b.press()
	await frames(4)
	await _close()
	b.queue_redraw()
	await frames(2)
	ok(b.seen() and not CompKit.cue_of(b).contains("dot"), "dot: opening the sheet clears it")
	var again := DeviceState.new(TEMP_CFG)
	ok(again.help_seen("club"), "dot: it stays cleared after a reload of the device file")
	ok(not again.help_seen("finance"), "dot: other screens keep theirs")


func _pause() -> void:
	var g: Dictionary = App.gs.next_game()
	var d := ScreenDraft.new(g)
	App.go(d)
	await frames(3)
	var n := 0
	while d.draft.current()["team"] != d.my_side and n < 20:
		n += 1
		d._ai_wait = 0.0
		d._process(0.01)
	d._time_left = 9.0
	HelpSheet.open("draft")
	await frames(4)
	d._process(2.0)
	var held := d._time_left
	await _close()
	d._process(2.0)
	ok(is_equal_approx(held, 9.0) and d._time_left < 8.0, "pause: the draft timer stands still while help is open (%.1f), and runs after (%.1f)" % [held, d._time_left])
	d._auto_rest()
	d._start_match()
	await frames(4)
	var m := _cur() as ScreenMatch
	var res_before := JSON.stringify(m.res)
	var e0: float = m.show_t
	HelpSheet.open("match")
	await frames(4)
	m._process(3.0)
	var e1: float = m.show_t
	await _close()
	m._process(3.0)
	ok(is_equal_approx(e0, e1) and m.show_t > e1, "pause: the match playback stands still while help is open and runs after")
	ok(JSON.stringify(m.res) == res_before, "pause: the result is the same with help opened")


func _glossary() -> void:
	var ids := HelpSheet.term_ids()
	ok(ids.size() == 49 and ScreenGlossary.groups().size() == 4, "glossary: 49 terms in 4 groups (%d, %d)" % [ids.size(), ScreenGlossary.groups().size()])
	var bad: Array = []
	for t in ids:
		var w := Strings.t("gl.%s.where" % t)
		if Strings.t("gl.%s.name" % t) == "" or Strings.t("gl.%s.def" % t) == "" or not HelpSheet.has_help(w):
			bad.append(t)
	ok(bad.is_empty(), "glossary: every term has a name, a definition and a where that is a help id %s" % str(bad))
	App.go(ScreenSettings.new())
	await frames(4)
	var gb: Button = null
	for b in _cur().find_children("*", "Button", true, false):
		if UI.plain((b as Button).text) == UI.plain(Strings.t("settings.glossary")):
			gb = b
	ok(gb != null, "glossary: Settings shows Glossary")
	if gb != null:
		gb.pressed.emit()
		await frames(4)
	var gs := _cur() as ScreenGlossary
	ok(gs != null and gs.terms.ids.size() == ScreenGlossary.ids_in("players").size(), "glossary: the Glossary opens on Players")
	gs.groups_bar.press(gs.groups_bar.index_of("club"))
	await frames(2)
	ok(gs.terms.ids == ScreenGlossary.ids_in("club"), "glossary: a group switches the list")
	gs.terms.press(gs.terms.ids.find("wage_cap"))
	await frames(6)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "glossary_term" and UI.plain(BottomSheet.current().title) == UI.plain(Strings.t("gl.wage_cap.name")), "glossary: a term opens its sheet")
	(UI.find_tag("gloss.where") as Button).pressed.emit()
	await frames(20)
	ok(_cur() is ScreenFinance, "glossary: Where to see it goes to the term's screen (wage cap: Finance)")
	App.go(ScreenRoster.new("hub"))
	await frames(4)
	HelpSheet.open("squad")
	await frames(4)
	(UI.find_tag("help.open_glossary") as Button).pressed.emit()
	await frames(6)
	ok(BottomSheet.is_open() and BottomSheet.current().sheet_id == "glossary" and _cur() is ScreenRoster, "glossary: from a help sheet it opens as a sheet, the screen stays")
	var tl: ScreenGlossary.TermList = null
	for c in BottomSheet.current().find_children("*", "Control", true, false):
		if c is ScreenGlossary.TermList:
			tl = c
	tl.press(0)
	await frames(3)
	ok(UI.find_tag("gloss.back") != null, "glossary: a term shows in place with Back")
	(UI.find_tag("gloss.back") as Button).pressed.emit()
	await frames(3)
	var back_list := false
	for c in BottomSheet.current().find_children("*", "Control", true, false):
		back_list = back_list or c is ScreenGlossary.TermList
	ok(back_list, "glossary: Back returns to the list")
	await _close()
