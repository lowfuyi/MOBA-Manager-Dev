class_name ScreenDraft
extends Screen
## Interactive draft for the managed club's game (GDD 8.7, UI-PASS-2 6.3, build plan I-16). The AI plays the other side and, on a
## timeout, also the managed side (the Coach's choice). The finished draft goes to the simulator through MatchRunner.finish().
## Built once (`_build()`), then refreshed in place on every step (`_refresh()`):
##   header      back, the phase ("Ban phase" on a violet tint with the no-entry glyph, or "Pick phase") over whose turn it is
##               ("Your ban 2 of 5"), the timer ring (digits, "!" at 3 s), Auto-finish (a second tap
##               within 3 s, "Sure?", lets the Coach finish), the "?" slot
##   steps       the order grouped by phase (a gap between phases): ban steps short and violet, picks tall; a done step carries
##               its side's mark (circle you, hexagon them; picks also in the side's colour); the current one outlined. 20 steps
##               with 5 bans a side stay legible at 720 px.
##   board       LaneBoard: you on the left, them on the right; open lanes show who would play there; bans under the lanes
##   needs       Frontline / Initiator / Wave clear as ticked or open chips; with three picks or more, the composition style
##   filter      All, Top, Jg, Mid, Bot, Sup (HeroGrid.role_filter): data plus one redraw, nothing built or freed
##   choices     (tag draft.choices) the line saying what the other team just did ("Ironquill Wolves ban X"), the Coach bar
##               ("Coach suggests banning: X" with a violet Ban button, or "Coach suggests: X" with Pick) and the HeroGrid (one Control, 40 cards), in
##               their own scroll area; on the other side's turn the grid dims and one line says who is choosing
##   sheet       a tap on a hero opens a BottomSheet: details, patch arrow, power, strong against, "Plays as" (best lane
##               preselected, filled lanes locked; tag draft.slot_list) and the confirm button (tag draft.sheet.confirm): Pick
##               is the coral go button, Ban an outlined warning button
##   done        the board stays; a card with both compositions and one number (the net edge for you), Game plan
##               (tag draft.game_plan) and Start the match
## Events (TUTORIAL 7.5): draft:sheet {kind} when the sheet opens, draft:ban / draft:pick when your side bans or picks (by the sheet,
## Take or a timeout), draft:done once when the draft is complete. The tutorial game has no timer (TutorialGame.timed) and its
## Auto-finish "Sure?" holds while tutorial step 15 asks (App.tutorial.holds_armed()); the card's one-tap button runs the same
## Auto-finish (register_shortcut "draft_auto_finish"). Nothing here changes a result (R7): every choice is Draft.apply().

const SURE_S := 3.0

var game: Dictionary
var draft: Draft
var my_side := "B"
var build_count := 0
var refresh_count := 0
var _limit := 10.0
var _time_left := 10.0
var _ai_wait := 0.0
var _sel_hero := ""
var _sure_t := 0.0
var _done_sent := false
var _last_second := -1

var header: HBoxContainer
var header_panel: PanelContainer
var phase_label: Label
var last_label: Label
var _last_seen := 0
var _take_look := {}
var title_label: Label
var timer: _Timer
var auto_button: Button
var steps: _Steps
var board: LaneBoard
var needs: HomeKit.ChipRow
var filter: DraftKit.RoleBar
var choices: VBoxContainer
var coach_bar: DepthCard
var coach_label: Label
var take_button: Button
var turn_label: Label
var grid: HeroGrid
var hint_label: Label
var grid_scroll: ScrollContainer
var done_box: VBoxContainer
var plan_button: Button
var start_button: Button
var sheet_slot: DraftKit.RoleBar          # the "Plays as" control of the open sheet (null when none)
var sheet_confirm: Button
var _sheet_target := ""


# ---- small drawn pieces -----------------------------------------------------------------------------------------------------

## The timer: a 72 px ring that drains, the seconds inside, a "!" mark at 3 s or less (never colour alone).
class _Timer extends Control:
	var frac := 1.0
	var secs := 0
	var urgent := false
	var draw_count := 0

	func _init() -> void:
		custom_minimum_size = Vector2(72, 72)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_time(p_frac: float, p_secs: int) -> void:
		var u := p_secs <= 3
		if p_secs == secs and u == urgent and absf(p_frac - frac) < 0.02:
			return
		frac = p_frac
		secs = p_secs
		urgent = u
		CompKit.set_cue(self, "ring+digits" + ("+!" if urgent else ""))
		queue_redraw()

	func _draw() -> void:
		draw_count += 1
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 5.0
		var col := UI.WARN if urgent else UI.ACCENT
		draw_arc(c, r, 0.0, TAU, 48, Color(UI.VOID, 0.9), 6.0, true)
		if frac > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(frac, 0.0, 1.0), 48, col, 6.0, true)
		var ops := CardKit.Ops.new()
		ops.text(UI.font("SemiBold", true), UI.S_HEAD, str(secs), 0.0, c.y + (0.0 if not urgent else 4.0), size.x, UI.TEXT, 1)
		if urgent:
			ops.icon("warn", Rect2(c.x - 10.0, 2.0, 20.0, 20.0), UI.WARN)
		ops.flush(self)


## One bar per step: bans short, picks tall; done = filled in the side's colour (a circle mark for you, a hexagon for them);
## the current step has an outline. One control, a few draw calls.
class _Steps extends Control:
	var order: Array = []
	var step := 0
	var mine := "B"
	var draw_count := 0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 28)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		CompKit.set_cue(self, "height+mark+phase gap")

	func set_state(p_order: Array, p_step: int, p_mine: String) -> void:
		if p_order == order and p_step == step and p_mine == mine:
			return
		order = p_order
		step = p_step
		mine = p_mine
		queue_redraw()

	func _draw() -> void:
		draw_count += 1
		var n := order.size()
		if n == 0:
			return
		var gap := 3.0
		var pgap := 14.0
		var phases := 1
		for i in range(1, n):
			if String(order[i][1]) != String(order[i - 1][1]):
				phases += 1
		var w := (size.x - gap * float(n - phases) - pgap * float(phases - 1)) / float(n)
		var ops := CardKit.Ops.new()
		var x := 0.0
		var band_x := 0.0
		for i in n:
			var o: Array = order[i]
			var pick := String(o[1]) == "pick"
			if i > 0 and String(order[i - 1][1]) != String(o[1]):
				x += pgap - gap
			if not pick and (i == 0 or String(order[i - 1][1]) == "pick"):
				band_x = x
			var h := 24.0 if pick else 14.0
			var r := Rect2(x, size.y - h, w, h)
			var you := String(o[0]) == mine
			var col: Color
			if pick:
				col = (UI.ACCENT if you else UI.CORAL) if i < step else Color(UI.PANEL3, 1.0)
			else:
				col = UI.BAN if i < step else Color(UI.BAN, 0.32)
			ops.shape("solid", r, col)
			if not pick and (i == n - 1 or String(order[i + 1][1]) == "pick"):
				ops.shape("solid", Rect2(band_x - 2.0, size.y - 2.0, x + w - band_x + 4.0, 2.0), UI.BAN)    # the ban phase's underline
			if i == step:
				ops.shape("solid", Rect2(r.position.x, r.position.y - 5.0, w, 3.0), UI.TEXT)
			if i < step:
				ops.shape("disc" if you else "hex", Rect2(r.get_center() - Vector2(5, 5), Vector2(10, 10)), UI.BG if pick else UI.INK_BAN)
			x += w + gap
		ops.flush(self)


## A hero's portrait (the silhouette of the sheet), 120 px.
class _Portrait extends Control:
	var hero: Dictionary = {}

	func _init(p_hero: Dictionary = {}) -> void:
		hero = HeroCard.prepare(p_hero)
		custom_minimum_size = Vector2(120, 120)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		ArtWire.ensure()
		var sil: Dictionary = hero["sil"]
		CardKit.bg(self, "card", Rect2(Vector2.ZERO, size), UI.PANEL3)
		CardKit.portrait(self, Rect2(Vector2(8, 8), size - Vector2(16, 16)), str(sil["role"]), int(sil["variant"]), float(sil["hue_shift"]), bool(sil["mirror"]), false)


# ---- life ---------------------------------------------------------------------------------------------------------------------

func _init(g: Dictionary = {}, finished: Draft = null) -> void:
	super._init()
	game = g
	draft = finished     # set when coming back from the Game Plan screen


## Back (and Android back with no sheet open): a draft in progress asks first; a finished draft goes back to Match day.
func go_back() -> void:
	if draft != null and not draft.is_done():
		BottomSheet.open(Strings.t("draft.leave.h"), _leave_body, _leave_footer, "S", "draft_leave")
		return
	_leave()


func _leave() -> void:
	if BottomSheet.is_open():
		BottomSheet.current().close()
	if TutorialGame.is_tutorial(game):   # leaving the tutorial game drops its sandbox (I-13)
		TutorialGame.leave(App.gs)
		if App.tutorial != null:
			App.tutorial.set_game_live(false)
	App.go(ScreenPreMatch.new(game))


func _close_sheet() -> void:
	if BottomSheet.is_open():
		BottomSheet.current().close()


func _leave_body(c: Control) -> void:
	var l := UI.label(Strings.t("draft.leave.body"), UI.S_BODY, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(l)


func _leave_footer(f: Control) -> void:
	BottomSheet.footer_button(f, Strings.t("draft.leave.stay"), _close_sheet, "primary")
	BottomSheet.footer_button(f, Strings.t("draft.leave.go"), _leave, "normal")


func _ready() -> void:
	var gs := App.gs
	my_side = "B" if game["blue"] == gs.club() else "R"
	if draft == null:
		App.timings.draft_opened()    # a fresh draft (tester timings, Q1)
		draft = MatchRunner.prepare(App.world, gs.lineup_for(game["blue"]), gs.lineup_for(game["red"]),
				gs.meta_for(int(game["round"])), int(gs.d["save_seed"]), game["id"], DraftFormat.of_game(game))
	_limit = DraftFormat.timer_s(draft.bans_per_side())
	setup("", Callable(), false)
	_build()
	if App.tutorial != null:
		App.tutorial.register_shortcut("draft_auto_finish", _auto_rest)
	_done_sent = draft.is_done()    # back from the Game Plan with a finished draft: draft:done was raised already
	_begin_step()


func _exit_tree() -> void:
	if App.tutorial != null and is_instance_valid(App.tutorial):
		App.tutorial.unregister_shortcut("draft_auto_finish", _auto_rest)


## "1 ban each", "3 bans each", "5 bans each" (Home and Pre-match chips).
static func format_text(bans: int) -> String:
	return Strings.t({1: "draft.format.b1", 3: "draft.format.b3", 5: "draft.format.b5"}.get(bans, "draft.format.b1"))


func timed() -> bool:
	return TutorialGame.timed(game)


func _begin_step() -> void:
	_time_left = _limit
	_ai_wait = 0.45 if App.gs.is_quick() else 0.9
	_sel_hero = ""
	_last_second = -1
	_refresh()


func _process(delta: float) -> void:
	if _sure_t > 0.0:
		var hold := App.tutorial != null and App.tutorial.holds_armed()
		if not hold:
			_sure_t -= delta
			if _sure_t <= 0.0:
				_disarm()
	if draft == null or draft.is_done():
		return
	if HelpSheet.paused():
		return    # a help sheet is open: the timer and the other side wait (I-22)
	var cur := draft.current()
	if cur["team"] == my_side:
		if not timed():
			return
		_time_left -= delta
		_show_time()
		if _time_left <= 0.0:
			var c := draft.ai_choice()
			var key := "draft.timeout_toast_ban" if String(cur["kind"]) == "ban" else "draft.timeout_toast"
			App.toast(Strings.f(key, {"hero": App.world.heroes[c["hero"]]["name"]}), UI.WARN)
			_apply(c)
	else:
		_ai_wait -= delta
		if _ai_wait <= 0.0:
			_apply(draft.ai_choice())


func _show_time() -> void:
	var s := maxi(0, ceili(_time_left))
	if s != _last_second:
		_last_second = s
		timer.set_time(clampf(_time_left / _limit, 0.0, 1.0), s)


## Every choice goes through here (the sheet, Take, a timeout, the AI, the old test path). Your side's ban or pick raises its event.
func _apply(choice: Dictionary) -> void:
	if draft.is_done():
		return
	var cur := draft.current()
	if draft.apply(choice):
		if BottomSheet.is_open() and BottomSheet.current().sheet_id == "draft_hero":
			BottomSheet.current().close()
		if cur["team"] == my_side:
			_raise("draft:" + String(cur["kind"]), {"hero": String(choice.get("hero", "")), "slot": String(choice.get("slot", ""))})
		_begin_step()


func _raise(event_name: String, data: Dictionary = {}) -> void:
	if is_instance_valid(App.bus):
		App.bus.emit(event_name, data)


# ---- building (once) ----------------------------------------------------------------------------------------------------------

func _build() -> void:
	build_count += 1
	ArtWire.prepare(App.world.club_ids, App.world.heroes.values())
	body.add_theme_constant_override("separation", 10)
	header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 104)
	header_panel = PanelContainer.new()
	header_panel.name = "HeaderPanel"
	header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_panel.add_child(header)
	header.add_theme_constant_override("separation", 8)
	var back := UI.button("<", go_back, "normal", UI.BTN_H)
	back.custom_minimum_size = Vector2(UI.BTN_H, UI.BTN_H)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back)
	title_label = UI.label("", UI.S_BIG, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phase_label = UI.label("", UI.S_SMALL, UI.TEXT2, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold")
	phase_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var titles := UI.vbox()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if UI.large:
		# large text: back, timer, Auto-finish and "?" leave the title about 106 px, so "Your ban" broke into two lines with a
		# lone word (I-22 fit audit); the title gets its own row under the header instead, and the header keeps a spacer
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(sp)
	else:
		titles.add_child(title_label)
		titles.add_child(phase_label)
		header.add_child(titles)
	timer = _Timer.new()
	header.add_child(timer)
	auto_button = UI.button(Strings.t("draft.auto_rest"), _on_auto, "flat")
	auto_button.custom_minimum_size = Vector2(176, UI.BTN_H)
	auto_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	auto_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	auto_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	auto_button.add_theme_font_size_override("font_size", UI.S_SMALL)
	for k in ["font_color", "font_hover_color"]:
		auto_button.add_theme_color_override(k, UI.TEAL_HI)
	UI.tag(auto_button, "draft.auto_rest")
	header.add_child(auto_button)
	if help_slot != null and help_slot.get_parent() == self:    # the "?" slot goes to the right end of this header
		remove_child(help_slot)
		help_slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
		help_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
		header.add_child(help_slot)
	body.add_child(header_panel)
	if UI.large:
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		titles.add_child(title_label)
		titles.add_child(phase_label)
		phase_label.visible = false    # large text: the grid needs the room; the Coach bar and the turn line say whose turn it is
		body.add_child(titles)
	steps = _Steps.new()
	body.add_child(steps)
	board = LaneBoard.new(_compact_board(), "draft.board")
	body.add_child(board)
	needs = HomeKit.ChipRow.new([])
	needs.name = "Needs"
	body.add_child(needs)
	filter = DraftKit.RoleBar.new(_on_filter, "draft.filter")
	body.add_child(filter)
	grid_scroll = ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(grid_scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 12)
	grid_scroll.add_child(inner)
	choices = VBoxContainer.new()
	choices.name = "Choices"
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 12)
	UI.tag(choices, "draft.choices", false)
	inner.add_child(choices)
	coach_bar = DepthCard.new(0, UI.PANEL2, false, false, "draft.coach", 8)    # 8 px, not 24: in large text the grid below needs the room (0.9.4c)
	var row := UI.hbox()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := Control.new()    # the text keeps a 24 px inset (8 + 16) while the button sits close to the edge
	inset.custom_minimum_size = Vector2(16, 0)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(inset)
	coach_label = UI.label("", UI.S_BODY, UI.TEXT)
	coach_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coach_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coach_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(coach_label)
	take_button = UI.button(Strings.t("draft.coach_take"), _take, "primary")
	take_button.custom_minimum_size = Vector2(140, UI.BTN_H)
	take_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	UI.tag(take_button, "draft.coach_take")
	for k in ["normal", "hover", "pressed", "focus"]:    # the Pick look, put back after a ban step
		if take_button.has_theme_stylebox_override(k):
			_take_look["sb:" + k] = take_button.get_theme_stylebox(k)
	for k2 in ["font_color", "font_hover_color", "font_pressed_color"]:
		if take_button.has_theme_color_override(k2):
			_take_look["c:" + k2] = take_button.get_theme_color(k2)
	row.add_child(take_button)
	coach_bar.content.add_child(row)
	choices.add_child(coach_bar)
	last_label = UI.label("", UI.S_SMALL, UI.TEXT2, HORIZONTAL_ALIGNMENT_CENTER)
	last_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	last_label.visible = false
	UI.tag(last_label, "draft.last_move", false)
	choices.add_child(last_label)
	choices.move_child(last_label, 0)
	turn_label = UI.label("", UI.S_BODY, UI.WARN, HORIZONTAL_ALIGNMENT_CENTER)
	turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices.add_child(turn_label)
	grid = HeroGrid.new("draft.hero_grid")
	grid.hero_tapped.connect(_open_sheet)
	choices.add_child(grid)
	hint_label = UI.label(Strings.t("draft.meta_hint"), UI.S_CAPTION, UI.DIM)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(hint_label)
	if TutorialGame.is_tutorial(game):
		var note := UI.label(Strings.t("tut.draft.note"), UI.S_CAPTION, UI.TEXT2)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(note)
	_build_done()


## UI-PASS-2 6.3 board rule: the full board only when the grid area keeps 560 px; never in large text.
func _compact_board() -> bool:
	if UI.large:
		return true
	var h := get_viewport().get_visible_rect().size.y if is_inside_tree() else 1280.0
	return h - 48.0 - 24.0 - (104.0 + 56.0 + 96.0 + 400.0 + 48.0) < 560.0


func _build_done() -> void:
	done_box = VBoxContainer.new()
	done_box.name = "Done"
	done_box.add_theme_constant_override("separation", 12)
	done_box.visible = false
	var card := DepthCard.new(0, Color(0, 0, 0, 0), false, false, "draft.done_card")
	card.name = "DoneCard"
	card.content.add_theme_constant_override("separation", 8)
	done_box.add_child(card)
	plan_button = UI.button("", func(): App.go(ScreenGamePlan.new(game, draft)), "normal")
	UI.tag(plan_button, "draft.game_plan")
	done_box.add_child(plan_button)
	var builds_button := UI.button(Strings.t("draft.builds"), func(): BuildSheet.open_draft(draft, "B" if game["blue"] == App.gs.club() else "R"), "normal")
	UI.tag(builds_button, "draft.builds")
	done_box.add_child(builds_button)
	start_button = UI.button(Strings.t("draft.start_match"), _start_match, "play", 112)
	start_button.add_theme_font_size_override("font_size", UI.S_HEAD)
	UI.tag(start_button, "draft.start_match")
	done_box.add_child(start_button)
	body.add_child(done_box)


# ---- refreshing (every step, in place) ----------------------------------------------------------------------------------------

## Kept for the old tests (R4): the whole view follows the draft.
func _rebuild() -> void:
	_refresh()


func _refresh() -> void:
	refresh_count += 1
	var w := App.world
	var them := "R" if my_side == "B" else "B"
	steps.set_state(draft.order, draft.step, my_side)
	for s in GameState.SLOTS:
		for t in [my_side, them]:
			var side := "you" if t == my_side else "them"
			if draft.picks[t].has(s):
				board.set_slot(s, side, {"state": "filled", "hero": draft.picks[t][s], "player": String(draft.lineups[t][s]["name"])})
			else:
				board.set_slot(s, side, {"state": "empty", "hero": {}, "player": String(draft.lineups[t][s]["name"])})
	_mark_target("")
	var ban_rows := {"you": [], "them": []}
	for t in [my_side, them]:
		for hid in draft.bans[t]:
			(ban_rows["you" if t == my_side else "them"] as Array).append(w.heroes[hid])
	board.set_bans("you", ban_rows["you"])
	board.set_bans("them", ban_rows["them"])
	board.set_ban_slots(draft.bans_per_side())
	_show_last_move()
	_refresh_needs()
	if draft.is_done():
		_show_done()
		return
	var cur := draft.current()
	var mine: bool = cur["team"] == my_side
	var kind := String(cur["kind"])
	title_label.text = Strings.t("draft.phase.ban" if kind == "ban" else "draft.phase.pick")
	var done_n := 0
	var total := 0
	for i in draft.order.size():
		if draft.order[i][0] == cur["team"] and draft.order[i][1] == kind:
			total += 1
			if i < draft.step:
				done_n += 1
	phase_label.text = UI.tidy(Strings.f("draft.turn.%s_%s" % ["your" if mine else "their", kind], {"n": done_n + 1, "total": total}))
	_phase_look(kind)
	timer.visible = mine and timed()
	if timer.visible:
		_show_time()
	auto_button.visible = true
	filter.visible = true
	grid_scroll.visible = true
	done_box.visible = false
	# the Coach bar on your turn; on theirs, one line saying who is choosing, and the grid dimmed
	coach_bar.visible = mine
	turn_label.visible = not mine
	grid.modulate.a = 1.0 if mine else 0.5
	if mine:
		var rec := draft.ai_choice()
		coach_label.text = UI.tidy(Strings.f("draft.coach_suggests_ban" if kind == "ban" else "draft.coach_suggests", {"hero": w.heroes[rec["hero"]]["name"]}))
	else:
		var team_club: String = game["blue"] if cur["team"] == "B" else game["red"]
		turn_label.text = UI.tidy(Strings.f("draft.club_turn", {"club": App.gs.club_name(team_club), "what": Strings.t("draft.kind." + kind)}))
	_refresh_grid(cur)


## The lane being picked for: its slot shows the target outline and arrow (with the player's name); every other open slot of
## yours is "Open" with its player. Built from the draft each time (LaneBoard.set_target would drop the player names).
func _mark_target(role: String) -> void:
	for s in GameState.SLOTS:
		if draft.picks[my_side].has(s):
			continue
		var who := String(draft.lineups[my_side][s]["name"])
		board.set_slot(s, "you", {"state": "target" if s == role else "empty", "hero": {}, "player": who})


func _refresh_needs() -> void:
	var heroes: Array = draft.picks[my_side].values()
	var n := _needs_of(heroes)
	var items: Array = []
	for k in ["frontline", "initiate", "waveclear"]:
		items.append([Strings.t("draft.need." + k), "good" if n[k] else "neutral", "check" if n[k] else "dot"])
	if heroes.size() >= 3:
		var ev := Comp.evaluate(heroes)
		items.append([Strings.f("draft.comp_line", {"style": Strings.t("style." + ev["style"]), "mod": UI.pct(ev["mod"])}), "accent", "star"])
	needs.set_items(items)
	needs.visible = not draft.is_done() and not UI.large    # large text: the grid needs the room (UI-PASS-2 6.3 (e))


## The hero grid in the order of today's list: best candidate first (familiarity times fit for a pick, their best for a ban).
func _scored(cur: Dictionary) -> Array:
	var opp := "R" if my_side == "B" else "B"
	var team := String(cur["team"])
	var scored: Array = []
	for hid in draft.avail:
		var h: Dictionary = App.world.heroes[hid]
		var v := 0.0
		if cur["kind"] == "ban":
			var against := opp if team == my_side else my_side
			for s in GameState.SLOTS:
				v = maxf(v, App.world.familiarity(draft.lineups[against][s], hid) * App.world.hero_fit(h, s))
		else:
			v = float(draft.best_slot_for(team, hid)["score"])
		scored.append([v, hid])
	scored.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	return scored


func _refresh_grid(cur: Dictionary) -> void:
	var w := App.world
	var scored := _scored(cur)
	var rows: Array = []
	var nums: Dictionary = {}
	for e in scored:
		rows.append(w.heroes[e[1]])
		nums[e[1]] = "%.0f" % float(e[0])
	# heroes no longer available stay on the grid after the available ones, in their state (banned, yours, theirs)
	var them := "R" if my_side == "B" else "B"
	var gone: Array = []
	for t in [my_side, them]:
		for hid in draft.bans[t]:
			gone.append([hid, "banned"])
		for s in GameState.SLOTS:
			if draft.picks[t].has(s):
				gone.append([String(draft.picks[t][s]["id"]), "you" if t == my_side else "them"])
	for gv in gone:
		rows.append(w.heroes[gv[0]])
	grid.set_heroes(rows)
	var rec := String(draft.ai_choice()["hero"]) if cur["team"] == my_side else ""
	var states: Dictionary = {}
	for e in scored:
		var hid: String = e[1]
		var m := float(draft.meta[hid])
		var arrow := "up" if m > 1.015 else ("down" if m < 0.985 else "flat")
		states[hid] = {"s": "available", "rec": hid == rec, "arrow": arrow, "delta": "%+.1f" % ((m - 1.0) * 100.0), "num": nums[hid]}
	for gv in gone:
		states[gv[0]] = {"s": gv[1]}
	grid.set_states(states)


# ---- the hero sheet ----------------------------------------------------------------------------------------------------------

func _open_sheet(hid: String) -> void:
	if draft.is_done():
		return
	var cur := draft.current()
	if cur["team"] != my_side or not draft.avail.has(hid):
		return
	_sel_hero = hid
	grid.set_selected(hid)
	var kind := String(cur["kind"])
	var size := "L" if UI.large else "M"
	BottomSheet.open(App.world.heroes[hid]["name"], _sheet_body.bind(hid, kind), _sheet_footer.bind(hid, kind), size, "draft_hero")
	var s := BottomSheet.current()
	if s != null:
		s.closed.connect(_on_sheet_closed)
	_raise("draft:sheet", {"kind": kind, "hero": hid})


func _on_sheet_closed() -> void:
	sheet_slot = null
	sheet_confirm = null
	_sheet_target = ""
	if is_inside_tree() and not draft.is_done():
		grid.set_selected("")
		_mark_target("")


func _sheet_body(c: Control, hid: String, kind: String) -> void:
	var w := App.world
	var h: Dictionary = w.heroes[hid]
	c.add_theme_constant_override("separation", 12)
	var top := UI.hbox()
	top.add_theme_constant_override("separation", 16)
	top.add_child(_Portrait.new(h))
	var info := UI.vbox()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tags: Array = []
	for tg in h["tags"]:
		tags.append(Strings.t("tag." + tg))
	var l1 := UI.label("%s  -  %s" % [Strings.t("arch." + h["archetype"]), Strings.t("dmg." + h["damage_type"])], UI.S_SMALL, UI.TEXT2)
	l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(l1)
	var l2 := UI.label(", ".join(tags), UI.S_SMALL, UI.TEXT2)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(l2)
	var m := float(draft.meta[hid])
	var arrow := "arrow_up" if m > 1.015 else ("arrow_down" if m < 0.985 else "arrow_flat")
	var patch := UI.hbox()
	patch.add_theme_constant_override("separation", 6)
	patch.add_child(Chip.new(Strings.f("draft.meta_line", {"meta": "%+.1f%%" % ((m - 1.0) * 100.0)}), "good" if m > 1.015 else ("bad" if m < 0.985 else "neutral"), arrow))
	info.add_child(patch)
	top.add_child(info)
	c.add_child(top)
	# the decision first (UI-PASS-2 6.3 (e): the lane control and the confirm button must both show, large text included)
	if kind == "pick":
		c.add_child(UI.label(Strings.t("draft.sheet.plays_as").to_upper(), UI.S_CAPTION, UI.DIM, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
		var best := String(draft.best_slot_for(my_side, hid)["slot"])
		var open := draft.open_slots(my_side)
		var opts: Array = []
		for s in GameState.SLOTS:
			var fit := w.hero_fit(h, s)
			var sub := "%d%%" % int(round(fit * 100.0))
			if s == best:
				sub += " " + Strings.t("draft.sheet.best")
			opts.append({"id": s, "label": Strings.t("role.short." + s), "icon": Icons.role_id(s), "sub": sub, "locked": not open.has(s)})
		sheet_slot = DraftKit.RoleBar.new(_on_slot.bind(hid), "draft.slot_list", opts, best)
		c.add_child(sheet_slot)
		_sheet_target = best
		_mark_target(best)
	c.add_child(UI.label(Strings.t("draft.sheet.power").to_upper(), UI.S_CAPTION, UI.DIM, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	c.add_child(UI.label(Strings.f("draft.power", {"e": h["power_early"], "m": h["power_mid"], "l": h["power_late"], "d": h["difficulty"]}), UI.S_SMALL, UI.TEXT))
	var strong: Array = []
	for sid in h["strong_vs"]:
		strong.append(w.heroes[sid]["name"])
	if not strong.is_empty():
		c.add_child(UI.label(Strings.t("draft.sheet.strong_vs").to_upper(), UI.S_CAPTION, UI.DIM, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
		var sv := UI.label(", ".join(strong), UI.S_SMALL, UI.TEXT)
		sv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(sv)


func _sheet_footer(f: Control, hid: String, kind: String) -> void:
	var w := App.world
	if kind == "ban":
		sheet_confirm = BottomSheet.footer_button(f, Strings.f("draft.sheet.ban", {"hero": w.heroes[hid]["name"]}), _confirm.bind(hid), "normal", "draft.sheet.confirm")
		ScreenDraft.ban_style(sheet_confirm)
	else:
		var s := String(draft.best_slot_for(my_side, hid)["slot"])
		sheet_confirm = BottomSheet.footer_button(f, _pick_text(hid, s), _confirm.bind(hid), "play", "draft.sheet.confirm")


func _pick_text(hid: String, s: String) -> String:
	if s == "":
		return Strings.f("draft.sheet.ban", {"hero": App.world.heroes[hid]["name"]})
	return Strings.f("draft.sheet.pick_for", {"role": Strings.t("role." + s), "name": String(draft.lineups[my_side][s]["name"])})


func _on_slot(id: Variant, hid: String) -> void:
	_sheet_target = String(id)
	_mark_target(_sheet_target)
	if sheet_confirm != null and is_instance_valid(sheet_confirm):
		sheet_confirm.text = UI.tidy(_pick_text(hid, _sheet_target))


func _confirm(hid: String) -> void:
	var cur := draft.current()
	if cur["kind"] == "ban":
		_apply({"hero": hid, "slot": ""})
	else:
		var s := _sheet_target if _sheet_target != "" else String(draft.best_slot_for(my_side, hid)["slot"])
		_apply({"hero": hid, "slot": s})


# ---- the phase look, the other team's last move ------------------------------------------------------------------------------

## Ban steps: a violet-tinted header with a violet rim and the no-entry glyph by the phase line; the Coach button reads "Ban"
## in violet. Pick steps: the plain header and a "Pick" button. Never colour alone: the word and the glyph change too.
func _phase_look(kind: String) -> void:
	var ban := kind == "ban"
	header_panel.add_theme_stylebox_override("panel", UI.box(UI.BAN_DEEP if ban else Color(0, 0, 0, 0), 14, 0, UI.BAN if ban else Color(0, 0, 0, 0), 2 if ban else 0))
	phase_label.add_theme_color_override("font_color", UI.BAN if ban else UI.TEXT2)
	title_label.add_theme_color_override("font_color", UI.BAN.lightened(0.45) if ban else UI.TEXT)
	CompKit.set_cue(header_panel, "ban tint+rim+word" if ban else "pick word")
	if ban:
		take_button.text = Strings.t("draft.do_ban")
		ScreenDraft.ban_style(take_button)
	else:
		take_button.text = Strings.t("draft.do_pick")
		take_button.icon = null
		for k0 in ["normal", "hover", "pressed", "focus"]:
			take_button.remove_theme_stylebox_override(k0)
		for k1 in ["font_color", "font_hover_color", "font_pressed_color"]:
			take_button.remove_theme_color_override(k1)
		for k in _take_look:
			if String(k).begins_with("sb:"):
				take_button.add_theme_stylebox_override(String(k).substr(3), _take_look[k])
			else:
				take_button.add_theme_color_override(String(k).substr(2), _take_look[k])
		CompKit.set_cue(take_button, "")


## A ban button: violet fill, dark ink, the no-entry glyph (the Coach's Ban and the hero sheet's "Ban X").
static func ban_style(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UI.box(UI.BAN, UI.R_BTN, 18))
	b.add_theme_stylebox_override("hover", UI.box(UI.BAN.lightened(0.08), UI.R_BTN, 18))
	b.add_theme_stylebox_override("pressed", UI.box(UI.BAN.darkened(0.15), UI.R_BTN, 18))
	b.add_theme_stylebox_override("focus", UI.box(Color(0, 0, 0, 0), UI.R_BTN, 18, UI.TEAL_HI, 3))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, UI.INK_BAN)
	b.icon = Icons.tex("ban", 32) if Icons.has("ban") else null
	b.add_theme_color_override("icon_normal_color", UI.INK_BAN)
	b.add_theme_color_override("icon_hover_color", UI.INK_BAN)
	b.add_theme_color_override("icon_pressed_color", UI.INK_BAN)
	CompKit.set_cue(b, "no-entry icon+word")


## One line under the board for what the other team just did: "Ironquill Wolves ban X" or "... pick X (Mid)". It stays until
## their next move, and is hidden before their first one.
func _show_last_move() -> void:
	var them := "R" if my_side == "B" else "B"
	var last: Dictionary = {}
	for e in draft.log:
		if String(e["team"]) == them:
			last = e
	if last.is_empty():
		last_label.visible = false
		return
	var club: String = game["blue"] if them == "B" else game["red"]
	var hero := String(App.world.heroes[String(last["hero"])]["name"])
	if String(last["kind"]) == "ban":
		last_label.text = UI.tidy(Strings.f("draft.opp_ban", {"club": App.gs.club_name(club), "hero": hero}))
		last_label.add_theme_color_override("font_color", UI.BAN.lightened(0.3))
	else:
		last_label.text = UI.tidy(Strings.f("draft.opp_pick", {"club": App.gs.club_name(club), "hero": hero, "role": Strings.t("role." + String(last["slot"]))}))
		last_label.add_theme_color_override("font_color", UI.CORAL_HI)
	last_label.visible = not draft.is_done()
	_last_seen = draft.log.size()


# ---- the Coach, the filter, Auto-finish --------------------------------------------------------------------------------------

func _take() -> void:
	if not draft.is_done() and draft.current()["team"] == my_side:
		_apply(draft.ai_choice())


func _on_filter(id: Variant) -> void:
	grid.set_filter(String(id))


func _on_auto() -> void:
	if _sure_t > 0.0:
		_disarm()
		_auto_rest()
		return
	_sure_t = SURE_S
	auto_button.text = Strings.t("draft.auto_sure")
	for k in ["font_color", "font_hover_color"]:
		auto_button.add_theme_color_override(k, UI.WARN)


func _disarm() -> void:
	_sure_t = 0.0
	if is_instance_valid(auto_button):
		auto_button.text = Strings.t("draft.auto_rest")
		for k in ["font_color", "font_hover_color"]:
			auto_button.add_theme_color_override(k, UI.TEAL_HI)


## The Coach finishes the draft (Auto-finish confirmed, or the tutorial card's one-tap button).
func _auto_rest() -> void:
	if BottomSheet.is_open() and BottomSheet.current().sheet_id == "draft_hero":
		BottomSheet.current().close()
	draft.finish_with_ai()
	_disarm()
	_refresh()


# ---- done ---------------------------------------------------------------------------------------------------------------------

func _show_done() -> void:
	title_label.text = Strings.t("draft.done")
	timer.visible = false
	auto_button.visible = false
	filter.visible = false
	grid_scroll.visible = false
	done_box.visible = true
	if not TutorialGame.is_tutorial(game) and not done_box.has_meta("lesson_checked"):
		done_box.set_meta("lesson_checked", true)
		var offer := LessonOffer.make("draftdone", "draftdone")    # lesson L5 (I-23) on a real game's Draft complete
		if offer != null:
			done_box.add_child(offer)
			done_box.move_child(offer, 1)
	var card := done_box.get_node("DoneCard") as DepthCard
	if card.content.get_child_count() == 0:
		var mine_ev := Comp.evaluate(draft.picks[my_side].values())
		var them := "R" if my_side == "B" else "B"
		var their_ev := Comp.evaluate(draft.picks[them].values())
		card.content.add_child(UI.label(Strings.t("draft.done").to_upper(), UI.S_CAPTION, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
		for pair in [["draft.you", mine_ev], ["draft.opponent", their_ev]]:
			var ev: Dictionary = pair[1]
			var l := UI.label("%s: %s" % [Strings.t(pair[0]), Strings.f("draft.comp_line", {"style": Strings.t("style." + ev["style"]), "mod": UI.pct(ev["mod"])})], UI.S_SMALL, UI.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.content.add_child(l)
		var net := float(mine_ev["mod"]) - float(their_ev["mod"])
		var row := UI.hbox()
		row.add_theme_constant_override("separation", 8)
		row.add_child(Chip.new(Strings.f("draft.net_edge", {"v": UI.pct(net)}), "good" if net > 0.0005 else ("bad" if net < -0.0005 else "neutral"),
				"arrow_up" if net > 0.0005 else ("arrow_down" if net < -0.0005 else "arrow_flat")))
		card.content.add_child(row)
	var neutral := GamePlan.is_neutral(App.gs.plan_set()["default"]) and (App.gs.plan_set()["triggers"] as Array).is_empty()
	plan_button.text = UI.tidy(Strings.f("draft.game_plan", {"state": Strings.t("gp.state.neutral" if neutral else "gp.state.set")}))
	if not _done_sent:
		_done_sent = true
		App.timings.draft_done()
		_raise("draft:done", {})


func _start_match() -> void:
	ScreenDraft.launch(game, draft)


static func launch(g: Dictionary, d: Draft) -> void:
	App.timings.launched()    # game start after the draft is timed from here to the first arena frame (Q1)
	var res := MatchRunner.finish(App.world, d, App.gs.plans_for(g), App.gs.builds())
	App.last_game = g
	App.last_result = res
	App.go(ScreenMatch.new(g, res))


# ---- kept for the old tests and the shots tour (R4) -----------------------------------------------------------------------------

## The old one-tap path: a ban is applied at once; a pick selects the hero (then `_apply` with a slot, as before).
func _on_hero(hid: String, kind: String) -> void:
	if kind == "ban":
		_apply({"hero": hid, "slot": ""})
	else:
		_sel_hero = hid


func _needs_of(heroes: Array) -> Dictionary:
	var out := {"frontline": false, "initiate": false, "waveclear": false}
	for h in heroes:
		for tg in h["tags"]:
			if tg == "frontline":
				out["frontline"] = true
			elif tg == "engage" or tg == "pick":
				out["initiate"] = true
			elif tg == "waveclear":
				out["waveclear"] = true
	return out
