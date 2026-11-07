class_name ScreenMatch
extends Screen
## Live text feed of the managed club's game (GDD 8.5 / 8.7). Pure playback of the already-decided
## result: the clock and the lines are cosmetic and never feed back into the outcome.

const SPEED_BASE := 8.0       # game seconds per real second (about 1.5 min of watching per game)

var game: Dictionary
var res: Dictionary
var my_side := "B"
var _events: Array = []
var _shown := 0
var _total_min := 12.0
var _elapsed := 0.0           # game minutes
var _fast := false
var _finished := false
var _clock: Label
var _edge: Label
var _bar: ProgressBar
var _feed_box: VBoxContainer
var _scroll: ScrollContainer
var _speed_btn: Button
var _go_btn: Button
var _skip_btn: Button
var _lead := 0.0
var _phase_vals: Dictionary = {}


func _init(g: Dictionary = {}, r: Dictionary = {}) -> void:
	super._init()
	game = g
	res = r


func go_back() -> void:
	_skip()


func _ready() -> void:
	my_side = "B" if game["blue"] == App.gs.club() else "R"
	if App.gs.is_quick():
		call_deferred("_continue")
		return
	_events = Report.feed(res, my_side)
	_total_min = Report.game_minutes(res)
	var sgn := 1.0 if my_side == "B" else -1.0
	_phase_vals = {"early": float(res["sim"]["early"]) * sgn, "mid": float(res["sim"]["mid"]) * sgn, "late": float(res["sim"]["late"]) * sgn}
	setup("", Callable(), false)
	var me := App.gs.club_name(App.gs.club())
	var opp_id: String = game["red"] if my_side == "B" else game["blue"]
	var head := UI.card(body, UI.PANEL2)
	head.add_child(UI.label(Strings.f("match.versus", {"me": me, "opp": App.gs.club_name(opp_id)}), UI.S_BODY, UI.TEXT))
	_clock = UI.label("00:00", UI.S_TITLE, UI.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	head.add_child(_clock)
	_bar = UI.bar(50.0, 100.0, UI.ACCENT, 26)
	head.add_child(_bar)
	_edge = UI.label(Strings.t("match.even"), UI.S_SMALL, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	head.add_child(_edge)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_feed_box = UI.vbox()
	_scroll.add_child(_feed_box)
	var bottom := UI.hbox()
	_speed_btn = UI.button(Strings.t("match.speed1"), _toggle_speed, "normal", 84)
	_skip_btn = UI.button(Strings.t("match.skip"), _skip, "normal", 84)
	bottom.add_child(_speed_btn)
	bottom.add_child(_skip_btn)
	body.add_child(bottom)
	_go_btn = UI.button(Strings.t("match.report"), _continue, "primary")
	_go_btn.visible = false
	body.add_child(_go_btn)
	_add_line(Strings.t("match.start"), UI.DIM)


func _process(delta: float) -> void:
	if _finished or _events.is_empty():
		return
	_elapsed += delta * SPEED_BASE * (2.0 if _fast else 1.0) / 60.0
	_clock.text = _mmss(minf(_elapsed, _total_min))
	while _shown < _events.size() and _events[_shown]["t"] * _total_min <= _elapsed:
		_reveal(_events[_shown])
		_shown += 1
	if _shown >= _events.size() and _elapsed >= _total_min:
		_end()


static func _mmss(minutes: float) -> String:
	var s := int(minutes * 60.0)
	return "%02d:%02d" % [s / 60, s % 60]


func _reveal(ev: Dictionary) -> void:
	var title := Strings.t("feed.t." + ev["key"])
	var size_w := Strings.t("feed.m." + ev["size"])
	var t := _mmss(float(ev["t"]) * _total_min)
	var line := Strings.f("feed.line", {"t": t, "title": title, "result": Strings.f("feed.win" if ev["mine"] else "feed.loss", {"size": size_w})})
	_add_line(line, UI.GOOD if ev["mine"] else UI.BAD)
	match ev["key"]:
		"jungle":
			_lead = 0.30 * _phase_vals["early"]
			_set_edge()
		"fight_mid":
			_lead = 0.30 * _phase_vals["early"] + 0.30 * _phase_vals["mid"]
			_set_edge()
		"fight_late":
			_lead = float(res["final"]) * (1.0 if my_side == "B" else -1.0)
			_set_edge()


func _set_edge() -> void:
	_bar.value = clampf(50.0 + _lead * 100.0, 3.0, 97.0)
	if absf(_lead) < 0.03:
		_edge.text = Strings.t("match.even")
		_edge.add_theme_color_override("font_color", UI.DIM)
	elif _lead > 0.0:
		_edge.text = Strings.t("match.edge_you")
		_edge.add_theme_color_override("font_color", UI.GOOD)
	else:
		_edge.text = Strings.t("match.edge_them")
		_edge.add_theme_color_override("font_color", UI.BAD)


func _add_line(text: String, color: Color) -> void:
	_feed_box.add_child(UI.label(text, UI.S_BODY, color))
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _end() -> void:
	if _finished:
		return
	_finished = true
	var won: bool = res["blue_won"] == (my_side == "B")
	_clock.text = _mmss(_total_min)
	_add_line(Strings.t("match.end.win" if won else "match.end.loss"), UI.GOOD if won else UI.BAD)
	_speed_btn.visible = false
	_skip_btn.visible = false
	_go_btn.visible = true


func _toggle_speed() -> void:
	_fast = not _fast
	_speed_btn.text = Strings.t("match.speed2" if _fast else "match.speed1")


func _skip() -> void:
	if _finished or _events.is_empty():
		return
	while _shown < _events.size():
		_reveal(_events[_shown])
		_shown += 1
	_elapsed = _total_min
	_end()


func _continue() -> void:
	ScreenHub._finish_game(game, res)
