class_name ScreenMatch
extends Screen
## The live arena (Alpha 0.8 A-06; UI-PASS-2 6.7, ARENA-MAP, ACTION-VOCABULARY). Pure playback of the already-decided result:
## the show script, the walks and the effects are built once from `res` before the first frame, and every frame is a function of
## the show time (H4), so Speed x2, Skip, a pause and the end all show the same truthful numbers. Nothing here feeds back (R7).
## Layout at 720 x 1280 (6.7.2): safe 48, scoreboard 142, arena 720 x 760, text strip 198 (plan and intent rows come with A-07,
## the feed block at its foot), controls 132 (Speed 200, Skip, "?"). Large text (626 x 1113, 6.7.7): scoreboard 122, arena
## 626 x 661, text strip 150 with one feed line. Quick mode skips the watch as before; the tutorial game always plays it.

const WATCH_SECONDS := 75.0   # real seconds of watching at normal speed, whatever the game length (Alpha 0.5)
const SAFE := 48.0

var game: Dictionary
var res: Dictionary
var my_side := "B"
var show_t := 0.0
var script_: ShowScript
var choreo: Choreo
var fx: ArenaFx
var labels: ArenaLabels
var decided := ""             # "Decided by: <factor>" for the end card (Report.attribution, once, at the end)
var _shown := 0               # results revealed so far (0 to 8), read by tests and the tutorial walk
var _fast := false
var _watch_t := 0.0           # real seconds spent watching (pace log)
var _skipped := false
var _used_fast := false
var _finished := false
var _stage: Control
var _map: ArenaMap
var _board: ArenaHud.Board
var _feed: ArenaHud.Feed
var _strip: ArenaHud.Strip
var _controls: Control
var _speed_btn: Button
var _skip_btn: Button
var _go_btn: Button


func _init(g: Dictionary = {}, r: Dictionary = {}) -> void:
	super._init()
	game = g
	res = r


func go_back() -> void:
	if _finished:
		_continue()    # Android Back after the show: See the report (6.7.6)
	else:
		_skip()


func _ready() -> void:
	my_side = "B" if game["blue"] == App.gs.club() else "R"
	if TutorialGame.quick_applies(App.gs, game):   # Quick mode is ignored in the tutorial game (I-13)
		call_deferred("_continue")
		return
	script_ = ShowScript.build(res, my_side)
	choreo = Choreo.build(script_, ScreenMatch.held_variant())
	fx = ArenaFx.build(script_, choreo, my_side)
	labels = ArenaLabels.build(script_, UI.large)
	setup("", Callable(), false)
	_stage = Control.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_stage)
	var opp_id: String = game["red"] if my_side == "B" else game["blue"]
	_map = ArenaMap.new(my_side)
	_stage.add_child(_map)
	_board = ArenaHud.Board.new(script_, _map.texture(), App.gs.club_name(App.gs.club()), App.gs.club_name(opp_id))
	_stage.add_child(_board)
	_feed = ArenaHud.Feed.new(script_, ArenaHud.last_word(App.gs.club_name(App.gs.club())))
	_stage.add_child(_feed)
	_board.labels = labels
	_feed.labels = labels
	_strip = ArenaHud.Strip.new(labels)
	_strip.plan_tapped.connect(_open_plan)
	_stage.add_child(_strip)
	_controls = Control.new()
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_controls)
	_speed_btn = UI.button(Strings.t("match.speed1"), _toggle_speed, "normal", UI.BTN_H)
	_skip_btn = UI.button(Strings.t("match.skip"), _skip, "normal", UI.BTN_H)
	_controls.add_child(_speed_btn)
	_controls.add_child(_skip_btn)
	UI.tag(_controls, "match.controls", false)    # tutorial step 19: Speed and Skip together (I-21a)
	_go_btn = UI.button(Strings.t("match.report"), _continue, "play", UI.BTN_H)    # the only coral on the screen (6.7.6)
	UI.tag(_go_btn, "match.report_btn")    # tutorial step 20
	_go_btn.visible = false
	_stage.add_child(_go_btn)
	# the "?" sits at the right end of the controls row (6.7.6), not top right: the scoreboard owns the top
	if help_slot != null and help_slot.get_parent() != null:
		help_slot.get_parent().remove_child(help_slot)
		help_slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_stage.add_child(help_slot)
	if App.tutorial != null:
		App.tutorial.set_variant("watch", "arena")    # "Your team is the circles..." (tut.watch.arena)
	_stage.resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_apply()


## The held-fight staging the tester switch asks for ("" = the data's default, held_island; ARENA-MAP 7.3).
static func held_variant() -> String:
	return HelpSheet.device().arena_held()


## Full bleed: the arena is the width of the window, so the layout is in window coordinates (the page margins of the app are
## stepped over by an offset). The stack is anchored to the bottom; on a tall phone the extra height is air above the
## scoreboard (6.7.7), and the controls stay at the thumb.
func _layout() -> void:
	if _stage == null or not is_inside_tree():
		return
	var view := get_viewport().get_visible_rect().size
	var o := -_stage.get_global_rect().position    # window origin in the stage's frame
	var w := view.x
	var h := view.y
	var large := UI.large
	var board_h := 122.0 if large else 142.0
	var ah := w * ArenaMap.MAP.y / ArenaMap.MAP.x
	var strip_h := 150.0 if large else 198.0
	var stack := SAFE + board_h + ah + strip_h + 132.0
	var top := o.y + maxf(0.0, h - stack)
	_board.position = Vector2(o.x, top + SAFE)
	_board.size = Vector2(w, board_h)
	_map.position = Vector2(o.x, top + SAFE + board_h)
	_map.size = Vector2(w, ah)
	var strip_y := top + SAFE + board_h + ah
	var ctrl_y := o.y + h - 24.0 - UI.BTN_H
	var feed_h := 38.0 if large else 80.0
	_strip.position = Vector2(o.x + 24.0, strip_y)    # plan row 44, gap 8, intent row 48 (6.7.2; the same in large text)
	_strip.size = Vector2(w - 48.0, 100.0)
	_feed.position = Vector2(o.x + 24.0, strip_y + 108.0)
	_feed.size = Vector2(w - 48.0, feed_h)
	var help_w := UI.BTN_H
	_controls.position = Vector2(o.x + 24.0, ctrl_y)
	_controls.size = Vector2(w - 48.0 - help_w - 12.0, UI.BTN_H)
	_speed_btn.position = Vector2.ZERO
	_speed_btn.size = Vector2(200, UI.BTN_H)
	_skip_btn.position = Vector2(212, 0)
	_skip_btn.size = Vector2(_controls.size.x - 212.0, UI.BTN_H)
	_go_btn.position = _controls.position
	_go_btn.size = _controls.size
	if help_slot != null:
		help_slot.position = Vector2(o.x + w - 24.0 - help_w, ctrl_y)
		help_slot.size = Vector2(help_w, UI.BTN_H)


func _process(delta: float) -> void:
	if _finished or script_ == null:
		return
	if BottomSheet.is_open() and not BottomSheet.current().is_closing:
		return    # any sheet (help, the plan) pauses the show (6.7.6); the result was decided before it, so nothing changes
	_watch_t += delta
	show_t = minf(ShowScript.WATCH, show_t + delta * (2.0 if _fast else 1.0))
	_apply()
	if show_t >= ShowScript.WATCH:
		_end()


## Every layer at the current show time: the map (towers, tokens, effects, camera), the scoreboard and the feed.
func _apply() -> void:
	fx.apply(_map, show_t, not UI.animate)
	_board.show_at(show_t)
	_feed.show_at(show_t)
	_strip.show_at(show_t, _fast)
	var n := 0
	for item in Report.FEED_ORDER:
		if float(item[1]) * ShowScript.WATCH <= show_t + 1e-9:
			n += 1
	_shown = n


static func _mmss(minutes: float) -> String:
	var s := int(minutes * 60.0)
	return "%02d:%02d" % [s / 60, s % 60]


func _end() -> void:
	if _finished:
		return
	_finished = true
	show_t = ShowScript.WATCH
	decided = ScreenMatch.decided_text(res, my_side)
	_feed.decided = decided
	_apply()
	_speed_btn.visible = false
	_skip_btn.visible = false
	_go_btn.visible = true
	_raise("match:end")


## "Decided by: <the biggest factor>", the same factor the Report leads with (UI-PASS-2 6.7.5).
static func decided_text(r: Dictionary, side: String) -> String:
	var att := Report.attribution(r, side)
	var best := {}
	for f in att["factors"]:
		if best.is_empty() or absf(float(f["share"])) > absf(float(best["share"])):
			best = f
	if best.is_empty():
		return ""
	return Strings.f("arena.end.decided", {"factor": Strings.t("factor." + String(best["id"]))})


## The plan row tapped: a read-only sheet with the plan in force and the "If behind" plan; the show pauses while it is open.
func _open_plan() -> void:
	BottomSheet.open(Strings.t("gp.title"), _plan_body, Callable(), "S", "match_plan")


func _plan_body(c: VBoxContainer) -> void:
	for part in labels.plan_parts(show_t):
		c.add_child(UI.label(String(part), UI.S_BODY, UI.TEXT))
	var ib := labels.if_behind()
	if bool(ib["has"]):
		var when := String(ib["when"])
		var hint := ("gp.trigger_hint." + when) if when == "behind_early" or when == "ahead_early" else ("gp.switch.short." + when)
		var l := UI.label(Strings.t(hint), UI.S_SMALL, UI.TEXT2)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(l)


func _toggle_speed() -> void:
	_fast = not _fast
	_used_fast = _used_fast or _fast
	_speed_btn.text = Strings.t("match.speed2" if _fast else "match.speed1")
	_raise("match:speed", {"fast": _fast})


## Skip to the end: one tap, no confirm; the scoreboard shows its final state in one frame (6.7.6).
func _skip() -> void:
	if _finished or script_ == null:
		return
	_skipped = true
	_raise("match:skip")
	show_t = ShowScript.WATCH
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
