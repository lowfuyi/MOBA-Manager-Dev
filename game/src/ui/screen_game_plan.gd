class_name ScreenGamePlan
extends Screen
## Game Plan editor (GDD 7.8): 7 five-step controls + jungle focus, a default plan and two triggered
## plans, a "where you stand" view and the coach's suggestion. Opened from the finished draft.

var game: Dictionary
var draft: Draft
var my_side := "B"
var _tab := "default"
var _ta: Dictionary
var _tb: Dictionary


func _init(g: Dictionary = {}, d: Draft = null) -> void:
	super._init()
	game = g
	draft = d


func go_back() -> void:
	App.autosave()
	App.go(ScreenDraft.new(game, draft))


func _ready() -> void:
	my_side = "B" if game["blue"] == App.gs.club() else "R"
	var teams := MatchRunner.build_teams(App.world, draft)
	_ta = teams[0]
	_tb = teams[1]
	setup(Strings.t("gp.title"), go_back)
	_rebuild()


func _plan_set() -> Dictionary:
	return App.gs.plan_set()


## The plan dictionary being edited on the current tab (null when that trigger is off).
func _cur_plan() -> Variant:
	var ps := _plan_set()
	if _tab == "default":
		return ps["default"]
	for t in ps["triggers"]:
		if t["when"] == _tab:
			return t["plan"]
	return null


func _rebuild() -> void:
	UI.clear(body)
	body.add_child(UI.label(Strings.t("gp.intro"), UI.S_SMALL, UI.DIM))
	_standing()
	var tabs := UI.hbox()
	for t in ["default", "behind_early", "ahead_early"]:
		tabs.add_child(UI.button(Strings.t("gp.tab." + t), _set_tab.bind(t), "primary" if _tab == t else "normal", 72))
	body.add_child(tabs)
	var plan: Variant = _cur_plan()
	if _tab != "default":
		var on: bool = plan != null
		body.add_child(UI.label(Strings.t("gp.trigger_hint." + _tab), UI.S_SMALL, UI.DIM))
		body.add_child(UI.button(Strings.t("gp.trigger_on" if on else "gp.trigger_off"), _toggle_trigger, "normal" if on else "primary", 76))
	if plan != null:
		for id in GamePlan.SLIDERS:
			_slider_row(id, plan)
		_jungle_row(plan)
	var row := UI.hbox()
	row.add_child(UI.button(Strings.t("gp.coach"), _coach, "normal", 76))
	row.add_child(UI.button(Strings.t("gp.reset"), _reset, "normal", 76))
	body.add_child(row)
	body.add_child(UI.button(Strings.t("draft.start_match"), func(): App.autosave(); ScreenDraft.launch(game, draft), "primary"))


func _standing() -> void:
	var c := UI.card(body, UI.PANEL2, 14)
	c.add_child(UI.label(Strings.t("gp.stand_h"), UI.S_BODY, UI.ACCENT))
	_edge_preview(c)
	var rt := GamePlan.contest_ratings(_ta, _tb, MatchRunner.sim_params())
	var sgn := 1.0 if my_side == "B" else -1.0
	for k in GamePlan.CONTESTS:
		var a: float = rt[k][0]
		var b: float = rt[k][1]
		var edge := sgn * (a - b) / ((a + b) / 2.0)
		var h := UI.hbox()
		var l := UI.label(Strings.t("feed.t." + k), UI.S_SMALL, UI.TEXT)
		l.custom_minimum_size = Vector2(300, 0)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		h.add_child(l)
		var v := UI.label(UI.pct(edge), UI.S_SMALL, UI.GOOD if edge >= 0.0 else UI.BAD, HORIZONTAL_ALIGNMENT_RIGHT)
		h.add_child(v)
		c.add_child(h)


## Live preview: the noise-free edge with the plan as it is now, against a balanced plan. Updates on every tap.
func _edge_preview(parent: VBoxContainer) -> void:
	var p := MatchRunner.sim_params()
	var sgn := 1.0 if my_side == "B" else -1.0
	var with_plan := sgn * GamePlan.expected_final(_ta, _tb, p, {my_side: _plan_set()})
	var balanced := sgn * GamePlan.expected_final(_ta, _tb, p, {})
	var add := with_plan - balanced
	var row := UI.hbox()
	var k := UI.label(Strings.t("gp.pv.edge"), UI.S_BODY, UI.TEXT)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v := UI.label(UI.pct(with_plan), UI.S_BIG, UI.delta_color(with_plan), HORIZONTAL_ALIGNMENT_RIGHT)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.custom_minimum_size = Vector2(150, 0)
	v.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(v)
	parent.add_child(row)
	UI.chips(parent, [[Strings.f("gp.pv.balanced", {"v": UI.pct(balanced)}), UI.DIM], [Strings.f("gp.pv.adds", {"v": UI.pct(add)}), UI.delta_color(add)]])
	parent.add_child(UI.label(Strings.t("gp.pv.note"), UI.S_SMALL - 2, UI.DIM))


func _slider_row(id: String, plan: Dictionary) -> void:
	var c := UI.card(body, UI.PANEL, 12)
	c.add_child(UI.label(Strings.t("gp.c.%s.name" % id), UI.S_BODY, UI.TEXT))
	var cur := int(plan.get(id, 0))
	var row := UI.hbox()
	for v in GamePlan.STEPS:
		var txt := "0" if v == 0 else ("%+d" % (v / 50)).replace("+1", "+").replace("-1", "-").replace("+2", "++").replace("-2", "--")
		var b := UI.button(txt, _set_value.bind(id, v), "primary" if cur == v else "normal", 64)
		row.add_child(b)
	c.add_child(row)
	var effect := Strings.t("gp.c.%s.balanced" % id)
	if cur < 0:
		effect = Strings.t("gp.c.%s.neg" % id)
	elif cur > 0:
		effect = Strings.t("gp.c.%s.pos" % id)
	c.add_child(UI.label(effect, UI.S_SMALL, UI.DIM if cur == 0 else UI.WARN))


func _jungle_row(plan: Dictionary) -> void:
	var c := UI.card(body, UI.PANEL, 12)
	c.add_child(UI.label(Strings.t("gp.c.jf.name"), UI.S_BODY, UI.TEXT))
	var row := UI.hbox()
	for jf in GamePlan.JUNGLE_CHOICES:
		row.add_child(UI.button(Strings.t("gp.jf." + jf), _set_jf.bind(jf), "primary" if plan.get("jf", "none") == jf else "normal", 64))
	c.add_child(row)
	c.add_child(UI.label(Strings.t("gp.c.jf.hint"), UI.S_SMALL, UI.DIM))


func _set_tab(t: String) -> void:
	_tab = t
	_rebuild()


func _set_value(id: String, v: int) -> void:
	var plan: Variant = _cur_plan()
	if plan != null:
		plan[id] = v
		App.autosave()
		_rebuild()


func _set_jf(jf: String) -> void:
	var plan: Variant = _cur_plan()
	if plan != null:
		plan["jf"] = jf
		App.autosave()
		_rebuild()


func _toggle_trigger() -> void:
	var ps := _plan_set()
	var found := -1
	for i in ps["triggers"].size():
		if ps["triggers"][i]["when"] == _tab:
			found = i
	if found >= 0:
		ps["triggers"].remove_at(found)
	else:
		ps["triggers"].append({"when": _tab, "plan": ps["default"].duplicate()})
	App.autosave()
	_rebuild()


func _coach() -> void:
	var plan: Variant = _cur_plan()
	if plan == null:
		return
	var sug := GamePlan.suggest(_ta, _tb, MatchRunner.sim_params(), my_side)
	for k in sug:
		plan[k] = sug[k]
	App.autosave()
	_rebuild()


func _reset() -> void:
	var plan: Variant = _cur_plan()
	if plan == null:
		return
	var n := GamePlan.neutral()
	for k in n:
		plan[k] = n[k]
	App.autosave()
	_rebuild()
