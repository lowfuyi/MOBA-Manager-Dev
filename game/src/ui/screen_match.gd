class_name ScreenMatch
extends Screen
## The live arena, Arena v2 (Phase 4; MATCH-SIM-V2-DESIGN 10 and 11). Pure playback of the already-played game: Match Sim v2
## wrote an event log, ArenaPlayer reads it, ArenaView draws the tilted map with a follow camera and a minimap, ArenaHud2 the
## scoreboard, the feed and what your team is doing. Every frame is a function of the show time, so Speed, Skip, a pause and
## the end show the same truthful numbers. Nothing here feeds back (R7, A1).
## Show length: one tunable value (sim_v2_params.json show_seconds, real seconds for a median game at Speed x1); quiet
## stretches play faster (ArenaPlayer pacing). Speed x1, x2, x4 and Skip are always there.
## Views (Founder decision 2026-11-22): a three-part control "Field | Action | All" above Speed and Skip, switchable at any time,
## remembered in the device setting [arena] camera (default Action). See ArenaView.
## Layout at 720 x 1280 (Match Day M2): safe 48, scoreboard 150 with two header buttons (View cycles Field, Action and All;
## Menu holds speed, pause, skip, view and sound), the arena (the rest), the commentary strip 110 (the Broadcast, 3 lines at 26 px;
## the feed's two lines at the end), the line-up panel 300 with both teams' five heroes always visible, 24 px
## margin. After the end, See the report sits between the strip and the panel. Speed always starts at x1; a small chip on
## the map shows a speed above x1 or a pause. Before the show, the Broadcast intro (tap the strip to skip).
## Quick mode skips the watch as before; the tutorial game always plays it.

const SAFE := 48.0
const SPEEDS := [1.0, 2.0, 4.0]
const VIEWS := ["field", "action", "all"]
## The Broadcast intro before the show (Match Day M2). Screen tests that play a match straight to its end switch it off, the way
## they switch off TutorialRunner.home_offers; check_ui_match tests the intro itself.
static var intro_on := true

var game: Dictionary
var res: Dictionary
var my_side := "B"
var show_t := 0.0
var player: ArenaPlayer
var view: ArenaView
var decided := ""             # "Decided by: <factor>" for the end card (Report.attribution, once, at the end)
var _speed_i := 0
var _watch_t := 0.0           # real seconds spent watching (pace log)
var _skipped := false
var _used_fast := false
var _finished := false
var _stage: Control
var _board: ArenaHud2.Board
var _feed: ArenaHud2.Feed
var _notes: ArenaHud2.Notes
var _lineup: ArenaLineup
var _view_btn: Button
var _menu_btn: Button
var _chip: Label
var _go_btn: Button
var _paused := false
var _intro_i := -1          # the intro line on screen (-1: no intro or it is over)
var _intro_t := 0.0
var view_mode := "action"
var _frames_seen := 0      # tester timings (Q1): the first arena frame has been drawn once the second _process runs


func _init(g: Dictionary = {}, r: Dictionary = {}) -> void:
	super._init()
	game = g
	res = r


func go_back() -> void:
	if _finished:
		_continue()    # Android Back after the show: See the report
	else:
		_skip()


func _ready() -> void:
	my_side = "B" if game["blue"] == App.gs.club() else "R"
	if TutorialGame.quick_applies(App.gs, game):   # Quick mode is ignored in the tutorial game (I-13)
		call_deferred("_continue")
		return
	player = ArenaPlayer.build(res, my_side)
	setup("", Callable(), false)
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_stage)
	var opp_id: String = game["red"] if my_side == "B" else game["blue"]
	view = ArenaView.new(player, my_side)
	view.reduced_motion = not UI.animate
	_stage.add_child(view)
	_board = ArenaHud2.Board.new(player, App.gs.club_name(App.gs.club()), App.gs.club_name(opp_id))
	_stage.add_child(_board)
	_notes = ArenaHud2.Notes.new(player)
	# the Broadcast (Match Day M4): two casters for the whole match, in large text too (two lines)
	_notes.cast = ArenaCast.build(player, String(game.get("id", "")), {my_side: App.gs.club_name(App.gs.club()), ("R" if my_side == "B" else "B"): App.gs.club_name(opp_id)},
			{"tutorial": TutorialGame.is_tutorial(game)})
	_stage.add_child(_notes)
	_feed = ArenaHud2.Feed.new(player, App.gs.club_name(App.gs.club()), App.gs.club_name(opp_id))
	_stage.add_child(_feed)
	_lineup = ArenaLineup.new(player, my_side)
	_lineup.tapped.connect(open_teams)
	UI.tag(_lineup, "match.lineup", false)
	_stage.add_child(_lineup)
	view.hero_tapped.connect(open_hero)
	_view_btn = UI.button("", _cycle_view, "normal", UI.BTN_H)
	_view_btn.add_theme_font_size_override("font_size", UI.S_SMALL)
	UI.tag(_view_btn, "match.views", false)
	_stage.add_child(_view_btn)
	_menu_btn = UI.button(Strings.t("match.menu"), _open_menu, "normal", UI.BTN_H)
	_menu_btn.add_theme_font_size_override("font_size", UI.S_SMALL)
	UI.tag(_menu_btn, "match.controls", false)    # tutorial step 19: speed and skip live in the menu (Match Day M2)
	_stage.add_child(_menu_btn)
	_chip = UI.label("", UI.S_CAPTION, UI.TEXT)
	_chip.add_theme_stylebox_override("normal", UI.box(Color(UI.PANEL2, 0.92), 16, 10))
	_chip.autowrap_mode = TextServer.AUTOWRAP_OFF    # one short word on one line (the first render wrapped it letter by letter)
	_chip.visible = false
	_stage.add_child(_chip)
	_go_btn = UI.button(Strings.t("match.report"), _continue, "play", UI.BTN_H)    # the only coral on the screen
	UI.tag(_go_btn, "match.report_btn")    # tutorial step 20
	_go_btn.visible = false
	_stage.add_child(_go_btn)
	if help_slot != null and help_slot.get_parent() != null:
		help_slot.get_parent().remove_child(help_slot)
		help_slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_stage.add_child(help_slot)
	if App.tutorial != null:
		App.tutorial.set_variant("watch", "arena")    # "Your team is the circles..." (tut.watch.arena)
	_stage.resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_view(HelpSheet.device().arena_camera(), false)
	if intro_on and _notes.cast != null and not _notes.cast.intro.is_empty():
		_intro_i = 0
		_notes.mouse_filter = Control.MOUSE_FILTER_STOP
		_notes.gui_input.connect(_on_strip_input)
	_apply()


## Field, Action or All: the view changes at once, the choice is remembered on this device.
func set_view(id: String, remember: bool = true) -> void:
	if not VIEWS.has(id):
		id = "action"
	view_mode = id
	view.set_mode(id)
	_view_btn.text = Strings.t("match.view." + id)
	CompKit.set_cue(_view_btn, "word")
	if remember:
		HelpSheet.device().set_arena_camera(id)
		_raise("match:view", {"view": id})


## The View button: the next of Field, Action, All, with a short toast naming it.
func _cycle_view() -> void:
	var nx: String = VIEWS[(VIEWS.find(view_mode) + 1) % VIEWS.size()]
	set_view(nx)
	App.toast(Strings.f("match.view.toast", {"view": Strings.t("match.view." + nx)}))


## Match Day M6: the sheets (any open sheet pauses the show).
func names() -> Dictionary:
	var opp_id: String = game["red"] if my_side == "B" else game["blue"]
	return {my_side: App.gs.club_name(App.gs.club()), ("R" if my_side == "B" else "B"): App.gs.club_name(opp_id)}


func open_hero(key: String) -> void:
	if player == null or _intro_i >= 0:
		return
	MatchSheets.open_hero(player, key, player.game_t(show_t), names())
	_raise("match:hero", {"key": key})


func open_teams() -> void:
	if player == null or _intro_i >= 0:
		return
	MatchSheets.open_teams(player, player.game_t(show_t), names())
	_raise("match:teams")


func show_len() -> float:
	return player.show_len if player != null else 0.0


## Full bleed: the arena is the width of the window; the stack is anchored to the bottom, the controls stay at the thumb.
func _layout() -> void:
	if _stage == null or not is_inside_tree():
		return
	var vsz := get_viewport().get_visible_rect().size
	var o := -_stage.get_global_rect().position
	var w := vsz.x
	var h := vsz.y
	var large := UI.large
	var board_h := 150.0
	var notes_h := 110.0         # the Broadcast: 3 lines at 26 px in both text sizes (the queue's floor for commentary)
	var feed_h := 0.0            # the feed shows its two lines at the end only (the commentary calls every moment)
	var strip_h := notes_h + feed_h
	var panel_h := 300.0
	var go_h := (UI.BTN_H + 12.0) if _finished else 0.0
	var panel_y := o.y + h - 24.0 - panel_h
	var go_y := panel_y - go_h
	var strip_y := go_y - strip_h
	var arena_top := o.y + SAFE + board_h
	var pill_w := 110.0
	_board.position = Vector2(o.x, o.y + SAFE)
	_board.size = Vector2(w, board_h)
	_board.side_w = 12.0 + pill_w
	_view_btn.position = Vector2(o.x + 12.0, o.y + SAFE + 44.0)
	_view_btn.size = Vector2(pill_w, UI.BTN_H)
	_menu_btn.position = Vector2(o.x + w - 12.0 - pill_w, o.y + SAFE + 44.0)
	_menu_btn.size = Vector2(pill_w, UI.BTN_H)
	view.position = Vector2(o.x, arena_top)
	view.size = Vector2(w, maxf(200.0, strip_y - arena_top))
	_notes.position = Vector2(o.x + 24.0, strip_y)
	_notes.size = Vector2(w - 48.0, notes_h)
	_notes.visible = not _finished
	_feed.position = Vector2(o.x + 24.0, strip_y + (0.0 if _finished else notes_h))
	_feed.size = Vector2(w - 48.0, strip_h if _finished else feed_h)
	_feed.max_lines = 2 if _finished else 1
	_feed.visible = _finished or feed_h > 0.0
	_lineup.position = Vector2(o.x + 16.0, panel_y)
	_lineup.size = Vector2(w - 32.0, panel_h)
	_go_btn.position = Vector2(o.x + 24.0, go_y + 6.0)
	_go_btn.size = Vector2(w - 48.0, UI.BTN_H)
	if help_slot != null:
		help_slot.position = Vector2(o.x + 12.0, arena_top + 12.0)
		help_slot.size = Vector2(UI.BTN_H, UI.BTN_H)
	_chip.position = Vector2(o.x + 16.0, arena_top + 24.0 + UI.BTN_H)


func _process(delta: float) -> void:
	if _finished or player == null:
		return
	if BottomSheet.is_open() and not BottomSheet.current().is_closing:
		return    # any sheet pauses the show; the result was decided before it, so nothing changes
	_watch_t += delta
	_frames_seen += 1
	if _frames_seen == 2:
		App.timings.match_shown()
	App.timings.frame(view_mode, delta, _watch_t)
	if _intro_i >= 0:
		_intro_step(delta)    # the arena is drawn during the intro, so the frame timings above count it
		return
	if _paused:
		return
	var was := player.game_t(show_t)
	show_t = minf(player.show_len, show_t + delta * float(SPEEDS[_speed_i]))
	_apply(delta)
	_cues(was, player.game_t(show_t))
	if show_t >= player.show_len - 1e-6:
		_end()


## Every layer at the current show time (the map, the scoreboard, the notes and the feed read the same game time).
func _apply(real_dt: float = 0.0) -> void:
	var gt := player.game_t(show_t)
	view.show_game(gt, real_dt)
	_board.show_at(gt)
	_notes.show_at(gt, show_t, float(SPEEDS[_speed_i]))
	_notes.intro = (_notes.cast.intro[_intro_i] as Dictionary) if _intro_i >= 0 and _notes.cast != null else {}
	_lineup.show_at(gt)
	_chip.visible = (_speed_i > 0 or _paused) and not _finished
	_chip.text = Strings.t("match.chip.paused") if _paused else Strings.t(["match.speed1", "match.speed2", "match.speed4"][_speed_i])
	_chip.size = _chip.get_minimum_size()
	_feed.show_at(gt)


## Sounds and vibration for what happened between two game times: a kill, a tower, an objective. A jump (Skip) plays nothing
## of what it passed. All optional: the screen already shows every one of these moments.
func _cues(a: float, b: float) -> void:
	if b <= a or b - a > 12.0:
		return
	for k in player.kills:
		if float(k[0]) > a and float(k[0]) <= b:
			App.sound("kill")
			App.buzz(25)
	for o in player.objs:
		if float(o[0]) > a and float(o[0]) <= b:
			App.sound("objective")


static func _mmss(minutes: float) -> String:
	var s := int(minutes * 60.0)
	return "%02d:%02d" % [s / 60, s % 60]


func _end() -> void:
	if _finished:
		return
	_finished = true
	show_t = player.show_len
	decided = ScreenMatch.decided_text(res, my_side)
	var won := player.winner == my_side
	var sc := player.score(player.end_t)
	var me := my_side
	var them := "R" if me == "B" else "B"
	var score := "%d–%d" % [int(sc["kills"][me]), int(sc["kills"][them])]
	_feed.end_text = Strings.f("match.result.won" if won else "match.result.lost", {"team": App.gs.club_name(App.gs.club()), "score": score})
	_feed.decided = decided
	_apply()
	_intro_i = -1
	_paused = false
	_menu_btn.visible = false    # after the end, See the report is the one action
	_go_btn.visible = true
	_layout()
	App.sound("victory" if won else "defeat")
	App.buzz(150 if won else 90)
	_raise("match:end")


## "Decided by: <the biggest factor>", the same factor the Report leads with.
static func decided_text(r: Dictionary, side: String) -> String:
	var att := Report.attribution(r, side)
	var best := {}
	for f in att["factors"]:
		if best.is_empty() or absf(float(f["share"])) > absf(float(best["share"])):
			best = f
	if best.is_empty():
		return ""
	return Strings.f("arena.end.decided", {"factor": Strings.t("factor." + String(best["id"]))})


func _toggle_speed() -> void:
	_set_speed((_speed_i + 1) % SPEEDS.size())


func _set_speed(i: int) -> void:
	_speed_i = clampi(i, 0, SPEEDS.size() - 1)
	_used_fast = _used_fast or _speed_i > 0
	_raise("match:speed", {"fast": _speed_i > 0, "speed": float(SPEEDS[_speed_i])})
	_apply()


func speed() -> float:
	return float(SPEEDS[_speed_i])


## Pause or resume the show (the menu). The result is already decided; a pause changes nothing in it.
func _toggle_pause() -> void:
	_paused = not _paused
	_apply()


# ---- the intro (the Broadcast's welcome, line-ups and matchups; tap the strip to skip) -------------------------------------
func _intro_step(delta: float) -> void:
	_intro_t += delta
	var l: Dictionary = _notes.cast.intro[_intro_i]
	var p := ArenaCast.params()
	if _intro_t >= maxf(float(p["min_show_s"]) + 0.5, float(p["per_word_s"]) * float(ArenaCast.words(String(l["text"]))) + 0.5):
		_intro_t = 0.0
		_intro_i += 1
		if _intro_i >= _notes.cast.intro.size():
			skip_intro()
			return
	_apply()


func skip_intro() -> void:
	if _intro_i < 0:
		return
	_intro_i = -1
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raise("match:intro_end")
	_apply()


func _on_strip_input(ev: InputEvent) -> void:
	if _intro_i >= 0 and ((ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)):
		skip_intro()


# ---- the menu (Match Day M2): speed, pause, skip, view, sound --------------------------------------------------------------
func _open_menu() -> void:
	_raise("match:menu")    # the guide's watch step (19) finishes when the player opens the Menu (Match Day M2)
	BottomSheet.open(Strings.t("match.menu.h"), _menu_body, Callable(), "L", "match_menu")


func _close_menu() -> void:
	var cur := BottomSheet.current()
	if cur != null:
		cur.close()


func _menu_body(c: Control) -> void:
	c.add_child(UI.label(Strings.t("match.menu.speed"), UI.S_BODY, UI.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in SPEEDS.size():
		var b := UI.button(Strings.t(["match.speed1", "match.speed2", "match.speed4"][i]), func(): _set_speed(i); _close_menu(), "primary" if i == _speed_i else "normal", UI.BTN_H)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", UI.S_SMALL)
		UI.tag(b, "match.menu.speed%d" % int(SPEEDS[i]), false)
		row.add_child(b)
	c.add_child(row)
	var pb := UI.button(Strings.t("match.resume" if _paused else "match.pause"), func(): _toggle_pause(); _close_menu(), "normal", UI.BTN_H)
	UI.tag(pb, "match.menu.pause", false)
	c.add_child(pb)
	var sk := UI.button(Strings.t("match.skip"), func(): _close_menu(); _skip(), "normal", UI.BTN_H)
	UI.tag(sk, "match.menu.skip", false)
	c.add_child(sk)
	c.add_child(UI.label(Strings.t("match.menu.view"), UI.S_BODY, UI.ACCENT))
	var vr := HBoxContainer.new()
	vr.add_theme_constant_override("separation", 8)
	for id in VIEWS:
		var vb := UI.button(Strings.t("match.view." + id), func(): set_view(id); _close_menu(), "primary" if id == view_mode else "normal", UI.BTN_H)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_font_size_override("font_size", UI.S_SMALL)
		UI.tag(vb, "match.view." + id, false)
		vr.add_child(vb)
	c.add_child(vr)
	var on := HelpSheet.device().sound()
	var sb := UI.button(Strings.t("match.sound_on" if on else "match.sound_off"), func(): App.set_sound(not HelpSheet.device().sound()); _close_menu(), "normal", UI.BTN_H)
	UI.tag(sb, "match.menu.sound", false)
	c.add_child(sb)


## Skip to the end: one tap, no confirm; the scoreboard shows its final state in one frame.
func _skip() -> void:
	if _finished or player == null:
		return
	_skipped = true
	_raise("match:skip")
	show_t = player.show_len
	_end()


## TUTORIAL 7.5 events (I-21a). Observed only: nothing here changes the match or its result (R7).
func _raise(event_name: String, data: Dictionary = {}) -> void:
	if is_instance_valid(App.bus):
		App.bus.emit(event_name, data)


func _continue() -> void:
	var gs := App.gs
	if not TutorialGame.logs_pace(game):
		pass   # the tutorial game never writes the pace log (I-13)
	elif gs.is_quick():
		gs.pace_quick()
	else:
		var total := _watch_t
		if App.pace_t0 > 0:
			total = (Time.get_ticks_msec() - App.pace_t0) / 1000.0
		gs.pace_add(total, _watch_t, _skipped, _used_fast)
	App.pace_t0 = 0
	ScreenHub._finish_game(game, res)
