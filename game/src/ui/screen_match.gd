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
## Layout at 720 x 1280: safe 48, scoreboard 142, arena (the rest), commentary 112 (84 in large text), feed 80, views 96 + 12,
## controls 132.
## Quick mode skips the watch as before; the tutorial game always plays it.

const SAFE := 48.0
const SPEEDS := [1.0, 2.0, 4.0]

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
var _controls: Control
var _speed_btn: Button
var _skip_btn: Button
var _go_btn: Button
var _views: HBoxContainer
var _view_btns: Dictionary = {}
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
	_controls = Control.new()
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_controls)
	_speed_btn = UI.button(Strings.t("match.speed1"), _toggle_speed, "normal", UI.BTN_H)
	_skip_btn = UI.button(Strings.t("match.skip"), _skip, "normal", UI.BTN_H)
	_controls.add_child(_speed_btn)
	_controls.add_child(_skip_btn)
	UI.tag(_controls, "match.controls", false)    # tutorial step 19: Speed and Skip together (I-21a)
	_views = HBoxContainer.new()
	_views.add_theme_constant_override("separation", 8)
	_views.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in ["field", "action", "all"]:
		var vb := UI.button(Strings.t({"field": "match.view.field", "action": "match.view.action", "all": "match.view.all"}[id]), func(): set_view(id), "normal", UI.BTN_H)
		vb.add_theme_font_size_override("font_size", UI.S_SMALL)
		UI.tag(vb, "match.view." + id, false)
		_view_btns[id] = vb
		_views.add_child(vb)
	UI.tag(_views, "match.views", false)
	_stage.add_child(_views)
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
	_apply()


## Field, Action or All: the view changes at once, the choice is remembered on this device.
func set_view(id: String, remember: bool = true) -> void:
	if not _view_btns.has(id):
		id = "action"
	view_mode = id
	view.set_mode(id)
	for k in _view_btns:
		var b := _view_btns[k] as Button
		var on: bool = k == id
		b.add_theme_stylebox_override("normal", UI.box(UI.ACCENT.darkened(0.15) if on else UI.PANEL2, UI.R_BTN, 12))
		b.add_theme_stylebox_override("hover", UI.box(UI.ACCENT if on else UI.PANEL3, UI.R_BTN, 12))
		for c in ["font_color", "font_hover_color"]:
			b.add_theme_color_override(c, UI.INK_TEAL if on else UI.TEXT)
		CompKit.set_cue(b, "filled+word" if on else "word")
	if remember:
		HelpSheet.device().set_arena_camera(id)
		_raise("match:view", {"view": id})


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
	var board_h := 122.0 if large else 142.0
	var notes_h := 84.0 if large else 112.0    # the commentary strip: 3 lines (2 in large text)
	var feed_h := 80.0
	var ctrl_y := o.y + h - 24.0 - UI.BTN_H
	var views_y := ctrl_y - 12.0 - UI.BTN_H
	var arena_top := o.y + SAFE + board_h
	var arena_bot := views_y - 12.0 - feed_h - notes_h
	_board.position = Vector2(o.x, o.y + SAFE)
	_board.size = Vector2(w, board_h)
	view.position = Vector2(o.x, arena_top)
	view.size = Vector2(w, maxf(200.0, arena_bot - arena_top))
	_notes.position = Vector2(o.x + 24.0, arena_bot)
	_notes.size = Vector2(w - 48.0, notes_h)
	_feed.position = Vector2(o.x + 24.0, arena_bot + notes_h)
	_feed.size = Vector2(w - 48.0, feed_h)
	var help_w := UI.BTN_H
	_controls.position = Vector2(o.x + 24.0, ctrl_y)
	_controls.size = Vector2(w - 48.0 - help_w - 12.0, UI.BTN_H)
	_speed_btn.position = Vector2.ZERO
	_speed_btn.size = Vector2(200, UI.BTN_H)
	_skip_btn.position = Vector2(212, 0)
	_skip_btn.size = Vector2(_controls.size.x - 212.0, UI.BTN_H)
	_views.position = Vector2(o.x + 24.0, views_y)
	_views.size = Vector2(w - 48.0, UI.BTN_H)
	_go_btn.position = _controls.position
	_go_btn.size = _controls.size
	if help_slot != null:
		help_slot.position = Vector2(o.x + w - 24.0 - help_w, ctrl_y)
		help_slot.size = Vector2(help_w, UI.BTN_H)


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
	_speed_btn.visible = false
	_skip_btn.visible = false
	_go_btn.visible = true
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
	_speed_i = (_speed_i + 1) % SPEEDS.size()
	_used_fast = _used_fast or _speed_i > 0
	_speed_btn.text = Strings.t(["match.speed1", "match.speed2", "match.speed4"][_speed_i])
	_raise("match:speed", {"fast": _speed_i > 0, "speed": float(SPEEDS[_speed_i])})


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
