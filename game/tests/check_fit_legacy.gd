extends Node
## I-04 fit audit of the screens that are not redesigned in 0.7 (Finance, Training, Chemistry, Free agents, Negotiation,
## Practice, Pre-match, Settings, Club select, Title, About, Season end, Game over, Match; also the Plan and Club tab
## pages that lead to them), in normal, large-text and tall variants, headless. The rules are in tests/fit_audit.gd:
## no overflow, no clipped or mid-word-broken text, every button at least 96 x 96 px, text at least 24 px, and (I-04) no
## wrap at '/' and no orphan last line. Several states per screen, with the longest club name (19 characters) and five to
## six digit cash. Ends with " N checks, M failures".
##
## Also here: the negative controls of the two new audit rules (each must flag its bad case and stay quiet on a good
## one), and a fidelity check that the audit's re-wrapping gives the same line count as the real Labels.
## Env for debugging: FIT_ONLY=<part of a state name>, FIT_VARIANTS=normal,large,tall.

const FitAudit = preload("res://tests/fit_audit.gd")
const SEED := 20261109
const LONGEST_CLUB := 5    # Northreach Corsairs, 19 characters
const VARIANTS := {"normal": Vector2i(720, 1280), "large": Vector2i(720, 1280), "tall": Vector2i(720, 1560)}

var checks := 0
var fails := 0
var states := 0
var variant := ""
var only_state := ""


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func cur() -> Control:
	return App.main._current


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func look(state: String) -> void:
	if only_state != "" and not state.contains(only_state):
		return
	await frames(3)
	var probs := FitAudit.audit(App.main, UI.canvas_w())
	states += 1
	if probs.is_empty():
		ok(true, "fit_%s_%s: clean" % [state, variant])
	else:
		ok(false, "fit_%s_%s: %d problems" % [state, variant, probs.size()])
		for p in probs.slice(0, 14):
			print("     ", p)


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)    # a headless window is 100 x 100 until told otherwise
	await frames(1)
	only_state = OS.get_environment("FIT_ONLY")
	if only_state == "":
		await _controls()
	var which := OS.get_environment("FIT_VARIANTS")
	for v in VARIANTS:
		if which != "" and not which.split(",").has(v):
			continue
		await _flow(v)
	App.apply_large_text(false)
	GameState.delete_save()
	print("check_fit_legacy: %d checks, %d failures (%d screen states)" % [checks, fails, states])
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- negative controls for the new rules

func _audit_of(c: Control) -> Array:
	var holder := Control.new()
	holder.theme = UI.make_theme()    # buttons and labels as they are in the game (24 px floor, Barlow)
	holder.size = Vector2(720, 400)
	add_child(holder)
	holder.add_child(c)
	await frames(2)
	var res := FitAudit.audit(holder, 720.0)
	holder.queue_free()
	return res


func _hit(probs: Array, rule: String) -> bool:
	for p in probs:
		if String(p).begins_with(rule):
			return true
	return false


func _label_in(text: String, room: float, size: int = UI.S_BODY, weight: String = "", tidy_text: bool = false) -> Label:
	var l := UI.label(text, size, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, weight, tidy_text)
	l.size_flags_horizontal = Control.SIZE_FILL
	l.custom_minimum_size = Vector2(room, 0)
	l.size = Vector2(room, 200)
	return l


func _controls() -> void:
	var font := UI.font("Regular")
	var w := func(t: String) -> float: return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.S_BODY).x
	# pure re-wrapping: "+17/wk" in a room that fits "+17/" but not all of it breaks after the slash
	var room_slash: float = float(w.call("+17/")) + 6.0
	var lines := FitAudit.wrapped_lines(font, UI.S_BODY, "+17/wk", room_slash, TextServer.AUTOWRAP_WORD_SMART)
	ok(lines.size() == 2 and lines[0] == "+17/" and lines[1] == "wk", "controls: '+17/wk' wraps as %s" % [lines])
	ok(FitAudit.wrapped_lines(font, UI.S_BODY, "+17/wk", 400.0, TextServer.AUTOWRAP_WORD_SMART).size() == 1, "controls: '+17/wk' in a wide room is one line")
	ok(FitAudit.wrapped_lines(font, UI.S_BODY, "a b", 5.0, TextServer.AUTOWRAP_OFF).size() == 1, "controls: no wrap mode, one line")
	# rule 6 negative control: a Label that breaks after '/' is flagged (and also as an orphan: 'wk' is 2 characters)
	var p1 := await _audit_of(_label_in("+17/wk", room_slash))
	ok(_hit(p1, "wrap at /"), "rule 6 flags '+17/wk' broken after the slash: %s" % [p1])
	ok(_hit(p1, "orphan"), "rule 5 flags the lone 'wk' that the slash break leaves")
	# rule 6 negative control: a Button breaks after '/' too
	var b := UI.button("Pay +17/wk", func(): pass)
	b.text = "Pay +17/wk"    # verbatim: UI.button's tidy() would put a joiner after the slash, which is the repair under test elsewhere
	b.size_flags_horizontal = Control.SIZE_FILL
	var sbn: StyleBox = b.get_theme_stylebox("normal")
	var bfont := UI.font("SemiBold")
	var bw: float = bfont.get_string_size("Pay +17/", HORIZONTAL_ALIGNMENT_LEFT, -1, UI.S_BODY).x + sbn.get_margin(SIDE_LEFT) + sbn.get_margin(SIDE_RIGHT) + 6.0
	b.custom_minimum_size = Vector2(bw, 96)
	b.size = Vector2(bw, 200)
	var p2 := await _audit_of(b)
	ok(_hit(p2, "wrap at /"), "rule 6 flags a Button that breaks after the slash: %s" % [p2])
	# rule 6 good case: a slash that does not end a line
	var p3 := await _audit_of(_label_in("Wins +17/wk now", 600.0))
	ok(p3.is_empty(), "rule 6 stays quiet on a slash in the middle of a line: %s" % [p3])
	# rule 5 negative control: an orphan number ("85%") and an orphan word ("ab")
	var room_pct: float = float(w.call("Chance to win ")) + 4.0
	var p4 := await _audit_of(_label_in("Chance to win 85%", room_pct))
	ok(_hit(p4, "orphan"), "rule 5 flags '85%%' alone on the last line: %s" % [p4])
	var room_ab: float = float(w.call("Income this week ")) + 4.0
	var p5 := await _audit_of(_label_in("Income this week ab", room_ab))
	ok(_hit(p5, "orphan"), "rule 5 flags 'ab' alone on the last line: %s" % [p5])
	# rule 5 good cases: a last line of 4 or more characters, and a one-line text of 2 characters
	var p6 := await _audit_of(_label_in("Chance to win 85% today", room_pct))
	ok(not _hit(p6, "orphan"), "rule 5 stays quiet on a last line of 5 characters: %s" % [p6])
	var p7 := await _audit_of(_label_in("OK", 300.0))
	ok(p7.is_empty(), "rule 5 stays quiet on a short text that is one line: %s" % [p7])
	var p8 := await _audit_of(_label_in("Chance to win 85% and more words after it to fill two lines nicely", 400.0))
	ok(p8.is_empty(), "rules 5 and 6 stay quiet on an ordinary two-line paragraph: %s" % [p8])
	# rule 7 negative control: a stat bar squeezed to a stub is flagged, a normal one is not
	var stub := UI.bar(50.0, 100.0, UI.ACCENT, 20)
	stub.custom_minimum_size = Vector2(60, 20)
	stub.size = Vector2(60, 20)
	var p13 := await _audit_of(stub)
	ok(_hit(p13, "bar"), "rule 7 flags a 60 px bar: %s" % [p13])
	var fat := UI.bar(50.0, 100.0, UI.ACCENT, 20)
	fat.custom_minimum_size = Vector2(200, 20)
	fat.size = Vector2(200, 20)
	var p14 := await _audit_of(fat)
	ok(p14.is_empty(), "rule 7 stays quiet on a 200 px bar: %s" % [p14])
	# UI.tidy repairs both cases: the real Finance line (it broke as '+17/' and 'wk' at large text) and an orphan '0.'
	var fin := "Sponsor 282/wk  -  Wages 265/wk  =  +17/wk"
	var room_fin: float = float(w.call("Sponsor 282/wk  -  Wages 265/wk  =  +17/")) + 3.0
	var small := UI.font("Medium")
	var p9 := await _audit_of(_label_in(fin, room_fin))
	ok(_hit(p9, "wrap at /"), "tidy control: the raw Finance line is flagged: %s" % [p9])
	var p10 := await _audit_of(_label_in(fin, room_fin, UI.S_BODY, "", true))
	ok(p10.is_empty(), "tidy: the same line through UI.tidy is clean: %s" % [p10])
	var pace := "No full game has been timed yet. Auto-played games so far: 0."
	var room_pace: float = small.get_string_size("No full game has been timed yet. Auto-played games so far:", HORIZONTAL_ALIGNMENT_LEFT, -1, UI.S_SMALL).x + 20.0
	var p11 := await _audit_of(_label_in(pace, room_pace, UI.S_SMALL))
	ok(_hit(p11, "orphan"), "tidy control: the raw pace note leaves a lone '0.': %s" % [p11])
	var p12 := await _audit_of(_label_in(pace, room_pace, UI.S_SMALL, "", true))
	ok(p12.is_empty(), "tidy: the same note through UI.tidy is clean: %s" % [p12])
	ok(UI.tidy("Wins") == "Wins" and UI.tidy("Top lane") == "Top lane", "tidy: one or two words are left alone")
	ok(UI.tidy("a b c").contains(UI.NBSP) and UI.tidy("+17/wk") == "+17/" + UI.WORD_JOINER + "wk", "tidy: three words bind the last two; a slash before letters gets a joiner")
	var spaced := UI.tidy("Ratio 88 / 91 now")
	ok(spaced.begins_with("Ratio 88 ") and not spaced.contains(UI.WORD_JOINER) and spaced.replace(UI.NBSP, " ") == "Ratio 88 / 91 now", "tidy: a spaced slash gets no joiner, and only spaces change (to no-break spaces)")
	ok(UI.tidy("Gravenstone Bulwark  their best 77").replace(UI.NBSP, " ") == "Gravenstone Bulwark  their best 77" and UI.tidy("Gravenstone Bulwark  their best 77").contains("best" + UI.NBSP + "77"), "tidy: 'best 77' is bound so the 77 cannot stand alone")
	ok(UI.tidy("Soldor  -  Top  -  tired -3  *").contains("-3" + UI.NBSP + UI.NBSP + "*"), "tidy: '-3  *' is bound as one tail, double space included")
	ok(UI.tidy("line one is here\nlast words") == "line one is here\nlast words", "tidy: a last line of two words is not bound to the line before")


# ---------------------------------------------------------------- fidelity: audit lines == real Label lines

func _fidelity(state: String) -> void:
	if only_state != "":
		return
	await frames(3)
	var n := 0
	var bad: Array = []
	var stack: Array = [App.main]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for ch in node.get_children():
			stack.append(ch)
		var l := node as Label
		if l == null or not l.is_visible_in_tree() or l.autowrap_mode == TextServer.AUTOWRAP_OFF or l.text == "" or l.size.x <= 0.0:
			continue
		n += 1
		var lines := FitAudit.wrapped_lines(l.get_theme_font("font"), l.get_theme_font_size("font_size"), l.text, l.size.x, l.autowrap_mode)
		if lines.size() != l.get_line_count():
			bad.append("'%s' audit %d lines, label %d" % [l.text.substr(0, 24), lines.size(), l.get_line_count()])
	ok(bad.is_empty() and n > 0, "fidelity_%s_%s: the audit wraps %d labels like the engine does %s" % [state, variant, n, bad.slice(0, 4)])


# ---------------------------------------------------------------- the screens

func _flow(v: String) -> void:
	variant = v
	get_window().size = VARIANTS[v]
	App.apply_large_text(v == "large")
	await frames(2)
	ok(absf(get_viewport().get_visible_rect().size.x - UI.canvas_w()) < 1.0, "%s: the canvas is %.0f px wide (%.0f wanted)" % [v, get_viewport().get_visible_rect().size.x, UI.canvas_w()])
	GameState.delete_save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	UI.animate = false
	await frames(1)
	# Title and About before a game exists, Club select, then the same with a save
	await look("title_nosave")
	App.go(ScreenAbout.new())
	await look("about_nosave")
	App.go(ScreenClubSelect.new())
	await look("clubselect")
	App.world.bind_progress({}, {}, 0)
	App.gs = GameState.new_game(App.world, App.world.club_ids[LONGEST_CLUB], SEED)
	App.autosave()
	App.go(ScreenTitle.new())
	await look("title_save")
	await _fidelity("title")
	App.go(ScreenAbout.new())
	await look("about_save")
	App.go(ScreenHub.new())
	await frames(2)
	App.go_tab("plan")
	await look("tab_plan")
	App.go_tab("club")
	await look("tab_club")
	App.go(ScreenSettings.new())
	await look("settings")
	cur()._confirm_reset = true
	cur()._rebuild()
	await look("settings_reset")
	cur()._confirm_reset = false
	UI.set_colorblind(true)
	cur()._rebuild()
	await look("settings_cb")
	UI.set_colorblind(false)
	App.gs.d["cash"] = 123456.0
	await _finance()
	await _training()
	await _chemistry()
	await _market()
	await _standings_tabs()
	var g: Dictionary = App.gs.next_game()
	await _practice_and_prematch(g)
	await _match(g)
	await _season_end()
	await _roster_detail()    # after the season: the stat rows then carry their "(+1.2)" gains, the widest they get
	await _settings_with_pace()
	main.queue_free()
	await frames(1)
	GameState.delete_save()


func _finance() -> void:
	App.go(ScreenFinance.new())
	await look("finance")
	await _fidelity("finance")
	cur()._more = true
	cur()._rebuild()
	await look("finance_more")
	App.gs.d["cash"] = -23456.0
	App.go(ScreenFinance.new())
	await look("finance_debt")
	App.gs.d["cash"] = 123456.0


func _training() -> void:
	var trs := ScreenTraining.new()
	App.go(trs)
	await look("training")
	var pid: String = App.world.club_players(App.gs.club())[0]["id"]
	trs._toggle(pid)
	await look("training_picker")
	trs._toggle_heroes()
	await look("training_heroes")
	trs._toggle(pid)
	trs._hero_list = false
	trs._coach_all()
	await look("training_coach_all")


func _chemistry() -> void:
	App.go(ScreenChemistry.new())
	await look("chemistry")
	(cur().body.get_parent() as ScrollContainer).scroll_vertical = 900
	await look("chemistry_lower")
	# the 5 x 5 grid header cells and the pentagon: the widest role words ("Support", "Jungle") fit with 8 px to spare
	var f := UI.font("Medium")
	var cell_room := _grid_cell_text_room(cur())
	for s in GameState.SLOTS:
		var t := Strings.t("role.short." + s)
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.S_CAPTION).x
		ok(tw <= cell_room - 8.0 or cell_room <= 0.0, "chemistry_%s: grid header '%s' is %.1f px in %.1f (8 px slack)" % [variant, t, tw, cell_room])
	for s in GameState.SLOTS:
		var t2 := Strings.t("role.short." + s)
		var tw2 := BondPentagon.text_width(t2, BondPentagon.TAG_SIZE, BondPentagon.TAG_WEIGHT)
		ok(tw2 <= BondPentagon.TAG_ROOM - 8.0, "chemistry_%s: pentagon tag '%s' is %.1f px in %.0f (8 px slack)" % [variant, t2, tw2, BondPentagon.TAG_ROOM])
	var worst := 0.0
	var worst_name := ""
	for pid2 in App.world.players:
		var nm: String = App.world.players[pid2]["name"]
		var nw := BondPentagon.text_width(nm, BondPentagon.NAME_SIZE, BondPentagon.NAME_WEIGHT)
		if nw > worst:
			worst = nw
			worst_name = nm
	ok(worst <= BondPentagon.NAME_ROOM, "chemistry_%s: the widest of %d player names ('%s') is %.1f px in a %.0f px circle" % [variant, App.world.players.size(), worst_name, worst, BondPentagon.NAME_ROOM])
	ok(BondPentagon.TAG_SIZE >= UI.S_CAPTION and BondPentagon.NAME_SIZE >= UI.S_CAPTION and BondPentagon.NUM_SIZE >= UI.S_CAPTION, "chemistry_%s: every pentagon text is at least the 24 px floor" % variant)


## The width the first role-word cell of the grid gives its text (cell width minus its padding), from the live layout.
func _grid_cell_text_room(n: Node) -> float:
	if n is GridContainer:
		var cell := (n as GridContainer).get_child(1) as PanelContainer
		if cell != null:
			var sb: StyleBox = cell.get_theme_stylebox("panel")
			return cell.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT)
	for ch in n.get_children():
		var r := _grid_cell_text_room(ch)
		if r > 0.0:
			return r
	return 0.0


func _market() -> void:
	var fa := ScreenFreeAgents.new("hub")
	App.go(fa)
	await look("free_agents")
	for i in 5:
		fa._next_role()
		await look("free_agents_role%d" % (i + 1))
	fa._next_role()
	for i in 3:
		fa._next_sort()
		await look("free_agents_sort%d" % (i + 1))
	var cand: String = App.gs.d["fa"][0]
	var neg := ScreenNegotiation.new(cand, false, "fa:hub")
	App.go(neg)
	await look("negotiation_sign")
	await _fidelity("negotiation")
	neg._wage = 99999
	neg._rebuild()
	await look("negotiation_bigwage")
	neg._wage = 1
	neg._make_offer()
	await look("negotiation_refused")
	neg._wage = maxi(App.gs.asking_wage(cand) + 10, 100)
	neg._make_offer()
	await look("negotiation_after")
	# a renewal (final-year contract)
	var exp: Array = App.gs.expiring()
	if not exp.is_empty():
		var rn := ScreenNegotiation.new(exp[0]["id"], true, "roster")
		App.go(rn)
		await look("negotiation_renew")


## Standings is redesigned later (I-20); only its tab row and pages are looked at here, so a tab word never breaks.
func _standings_tabs() -> void:
	for t in ["table", "form", "playoffs", "results", "trophies"]:
		App.go(ScreenStandings.new(t))
		await look("standings_" + t)


## The Squad screen is redesigned later (I-19); its player card shares PlayerView.stat_block with Negotiation, whose bars
## were squeezed to a stub at large text, so the bars of that card are checked here (audit rule 7).
func _roster_detail() -> void:
	var rs := ScreenRoster.new("hub")
	App.go(rs)
	rs._toggle_player(App.gs.d["lineup"]["mid"])
	await look("roster_detail")
	_open_section_text(cur(), "Career with us")
	await look("roster_detail_career")
	var bars: Array = []
	_collect_bars(cur(), bars)
	var narrow := 100000.0
	for b in bars:
		narrow = minf(narrow, (b as ProgressBar).size.x)
	ok(bars.size() >= 8 and narrow >= 96.0, "roster_%s: %d stat bars, the narrowest is %.0f px (it was about 30 at large text before I-04)" % [variant, bars.size(), narrow])


func _collect_bars(n: Node, out: Array) -> void:
	if n is ProgressBar and (n as ProgressBar).is_visible_in_tree():
		out.append(n)
	for ch in n.get_children():
		_collect_bars(ch, out)


func _open_section_text(node: Node, needle: String) -> bool:
	if node is Button and UI.plain((node as Button).text).begins_with("+ ") and UI.plain((node as Button).text).contains(needle):
		(node as Button).pressed.emit()
		return true
	for ch in node.get_children():
		if _open_section_text(ch, needle):
			return true
	return false


func _practice_and_prematch(g: Dictionary) -> void:
	App.go(ScreenPractice.new())
	await look("practice")
	var pr := cur() as ScreenPractice
	pr._set_len(5)
	await look("practice_bo5")
	for pid in (App.gs.d["lineup"] as Dictionary).values():
		App.world.fatigue[pid] = 55.0
	App.go(ScreenPreMatch.new(g))
	await look("prematch_tired")
	App.world.fatigue.clear()
	App.go(ScreenPreMatch.new(g))
	await look("prematch")
	# a practice series: an exhibition best-of-5 shows the series card and the practice pre-match page
	var opp: String = App.gs.quick_match_opponent()
	var why := App.gs.start_practice(opp, 5)
	ok(why == "", "practice_%s: a best-of-5 series opens" % variant)
	if why == "":
		App.go(ScreenPractice.new())
		await look("practice_series")
		App.go(ScreenPreMatch.new(App.gs.practice_game()))
		await look("prematch_practice")
		App.gs.end_practice()


func _match(g: Dictionary) -> void:
	var res: Dictionary = App.gs.auto_game(g)
	var m := ScreenMatch.new(g, res)
	App.go(m)
	await frames(2)
	for i in 5:
		m._process(5.0)
	await look("match_mid")
	m._skip()
	await look("match_end")
	m._finished = true
	m.set_process(false)


func _season_end() -> void:
	App.gs.autoplay(true)
	App.go(ScreenSeasonEnd.new())
	await look("season_end")
	await _fidelity("season_end")
	var done: Array = App.gs.d["seasons_done"]
	if not done.is_empty():
		for i in 4:
			done.append((done[0] as Dictionary).duplicate())
		App.go(ScreenSeasonEnd.new())
		await look("season_end_history")
	App.gs.d["dismissed"] = true
	App.go(ScreenGameOver.new())
	await look("game_over")
	App.gs.d["dismissed"] = false


func _settings_with_pace() -> void:
	App.gs.pace_add(312.0, 140.0, true, false)
	App.gs.pace_add(402.0, 150.0, false, true)
	App.gs.pace_quick()
	App.go(ScreenSettings.new())
	await look("settings_pace")
	(cur().body.get_parent() as ScrollContainer).scroll_vertical = 1200
	await look("settings_pace_lower")
