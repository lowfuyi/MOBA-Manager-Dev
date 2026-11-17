class_name ScreenGamePlan
extends Screen
## Game Plan editor (GDD 7.8, UI-PASS-2 6.4, build plan I-17). Opened from the finished draft. Built once (`_build()`), then
## refreshed in place on every change (`_refresh()`): no tap rebuilds the page (`rebuild_count` stays 0).
##   header   back, the title, the plan chip ("Plan: Default", "+1" when a trigger plan is on; tag gp.plan_chip) that opens the
##            plan sheet (Default, If behind, If ahead: pick the one to edit, switch the trigger plans on and off), the "?" slot
##   hero     (tag gp.edge) the expected edge as a big signed number with an arrow, a You | Them bar, "Balanced plan" and "This
##            plan" chips, the "before luck" line. It stays on screen while the controls change, and counts to the new number
##   strip    PhaseStrip Overall, Early, Mid, Late (tag gp.phases); "lead n/m" per phase; Early is locked in a trigger plan
##   page     one phase at a time, in its own scroll area: "Where you stand" (centre-zero meters per contest), then the controls
##            of that phase as DetentTracks (Overall: Fight style, Risk; Early: Tempo, Lane aggression, Support, Jungle focus;
##            Mid: Mid-game objectives; Late: Late objectives). Each track says which phases it moves.
##            In a trigger plan (used from the mid-game on) a control with no effect is INERT (lock, hollow thumb, takes no tap,
##            says why) and one with only part of its effect says so; a trigger plan that is off shows one card to switch it on
##   footer   Coach (tag gp.coach), Reset, Start the match (the one coral action; tag gp.start_match)
## Coach opens a sheet (id gp_coach) listing the changes and the edge before and after; Apply (tag gp.coach_apply) applies them
## with an Undo toast. Reset also has Undo. Every change is saved at once (App.autosave per tap, as before).
## Events (TUTORIAL 7.5): gp:coach_open when the Coach sheet opens, gp:coach_apply when the Coach's plan is applied (sheet or the
## tutorial card's shortcut "gp_coach_apply"), gp:coach_close when the sheet closes without applying.
## The old entry points stay as wrappers (tests and the tutorial use them): _set_tab, _set_value, _set_jf, _toggle_trigger,
## _coach (now opens the sheet), _coach_apply (what the old _coach did), _reset. Nothing here changes the simulation (R1, R7).

const TABS := ["default", "behind_early", "ahead_early"]
const TRIGGER_ACTIVE := ["mid", "late"]     # a trigger plan only acts from the mid-game on (GamePlan.simulate, _hooked)
## The controls on each phase page (UI-PASS-2 6.4 (b)).
const PAGE := {"overall": ["g", "r"], "early": ["t", "a", "s", "jf"], "mid": ["m"], "late": ["l"]}
const STAND := {"early": ["top", "mid_lane", "bot", "jungle"], "mid": ["obj_mid", "fight_mid"], "late": ["obj_late", "fight_late"]}
const JF_ICONS := {"none": "close", "top": "role_top", "mid_lane": "role_mid", "bot": "role_bot"}

var game: Dictionary
var draft: Draft
var my_side := "B"
var build_count := 0
var refresh_count := 0
var rebuild_count := 0
var _tab := "default"
var _phase := "overall"
var _ta: Dictionary
var _tb: Dictionary
var _edges: Dictionary = {}       # contest -> your rating edge (fraction)
var _undo: Dictionary = {}        # {tab, plan} saved before Apply or Reset
var _coach_applied := false
var _sug: Dictionary = {}

var header: HBoxContainer
var plan_chip: Button
var hero: _Hero
var strip: PhaseStrip
var page_scroll: ScrollContainer
var page: VBoxContainer
var note_label: Label
var stand: _Stand
var tracks: Dictionary = {}       # id -> DetentTrack
var jf_box: VBoxContainer
var jf_bar: DraftKit.RoleBar
var jf_note: Label
var off_card: DepthCard
var off_label: Label
var off_button: Button
var coach_button: Button
var reset_button: Button
var start_button: Button
var coach_apply: Button           # the Apply button of the open Coach sheet (null when none)


# ---- drawn pieces ---------------------------------------------------------------------------------------------------------------

## The expected-edge hero: one Control, drawn through CardKit.Ops.
class _Hero extends Control:
	var value := 0.0          # the edge with the plan (fraction, your side's sign)
	var balanced := 0.0
	var shown := 0.0          # the number on show (counts to `value`)
	var draw_count := 0
	var _ops := CardKit.Ops.new()
	var _tw: Tween
	var _note: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resized.connect(_relayout)
		CompKit.mark_stateful(self)
		CompKit.set_cue(self, "sign+arrow+word")
		_relayout()

	func set_values(v: float, b: float) -> void:
		if is_equal_approx(v, value) and is_equal_approx(b, balanced):
			return
		value = v
		balanced = b
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if UI.animate and is_inside_tree():
			_tw = create_tween()
			_tw.tween_method(_show, shown, value, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			shown = value
		queue_redraw()

	func _show(x: float) -> void:
		shown = x
		queue_redraw()

	func _w() -> float:
		return size.x if size.x > 0.0 else UI.canvas_w() - 48.0

	func _relayout() -> void:
		# large text: the "before luck" line gives its room to the controls (UI-PASS-2 6.4 (b) allows it in the "?" help instead)
		_note = [] if UI.large else PlanKit.wrap(UI.font(), UI.S_CAPTION, Strings.t("gp.pv.note"), _w() - 48.0, 2)
		var h := 24.0 + 56.0 + 10.0 + 14.0 + 14.0 + 44.0 + 8.0 + float(_note.size()) * 30.0 + 16.0
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size = Vector2(0, h)
		queue_redraw()

	func arrow_of(x: float) -> String:
		return "arrow_up" if x > 0.0005 else ("arrow_down" if x < -0.0005 else "arrow_flat")

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var w := size.x
		_ops.bg("card", Rect2(Vector2.ZERO, size), UI.PANEL2)
		var sb := UI.font("SemiBold")
		var x0 := 24.0
		var room := w - 48.0
		var y := 24.0
		_ops.text(sb, UI.S_SMALL, Strings.t("gp.pv.edge"), x0, y + 28.0, room * 0.5, UI.DIM)
		var col := UI.delta_color(value) if absf(value) > 0.0005 else UI.TEXT
		var num := UI.pct(shown)
		var nf := UI.font("Bold", true)
		var nw := CardKit.text_w(nf, UI.S_TITLE, num)
		_ops.text(nf, UI.S_TITLE, num, x0 + room - nw, y + 28.0, nw + 2.0, col)
		_ops.icon(arrow_of(value), Rect2(x0 + room - nw - 48.0, y + 8.0, 40.0, 40.0), col)
		y += 56.0 + 10.0
		# the You | Them bar: your share grows with the edge (a 30 percent edge fills most of it); the notch marks even
		var share := clampf(0.5 + value * 1.5, 0.06, 0.94)
		var bar := Rect2(x0 + 72.0, y, room - 144.0, 14.0)
		_ops.text(sb, UI.S_CAPTION, Strings.t("gp.you"), x0, y + 7.0, 68.0, UI.TEAL_HI)
		_ops.text(sb, UI.S_CAPTION, Strings.t("gp.them"), x0 + room - 68.0, y + 7.0, 68.0, UI.CORAL_HI, 2)
		_ops.bg("pill", bar, UI.CORAL)
		_ops.bg("pill", Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), UI.ACCENT)
		_ops.shape("solid", Rect2(bar.position.x + bar.size.x * 0.5 - 1.5, y - 4.0, 3.0, 22.0), UI.TEXT)
		y += 14.0 + 14.0
		var chips := [[Strings.f("gp.pv.balanced", {"v": UI.pct(balanced)}), UI.DIM, "dot"],
				[Strings.f("gp.pv.adds", {"v": UI.pct(value - balanced)}), UI.delta_color(value - balanced) if absf(value - balanced) > 0.0005 else UI.DIM, arrow_of(value - balanced)]]
		var cx := x0
		for c in chips:
			var cw := minf(Chip.PAD * 2.0 + Chip.ICON + Chip.GAP + CardKit.text_w(sb, Chip.SIZE_TEXT, String(c[0])), room - (cx - x0))
			var r := Rect2(cx, y, cw, 44.0)
			var cc: Color = c[1]
			_ops.bg("pill", r, Color(cc.r, cc.g, cc.b, 0.16))
			_ops.bg("pillring", r, Color(cc.r, cc.g, cc.b, 0.45))
			if String(c[2]) != "dot":
				_ops.icon(String(c[2]), Rect2(r.position.x + Chip.PAD, y + (44.0 - Chip.ICON) * 0.5, Chip.ICON, Chip.ICON), cc.lerp(Color.WHITE, 0.25))
			var tx: float = r.position.x + Chip.PAD + (Chip.ICON + Chip.GAP if String(c[2]) != "dot" else 0.0)
			_ops.text(sb, Chip.SIZE_TEXT, String(c[0]), tx, y + 22.0, r.end.x - Chip.PAD - tx + (Chip.ICON + Chip.GAP if String(c[2]) == "dot" else 0.0), cc.lerp(Color.WHITE, 0.25))
			cx += cw + 8.0
		y += 44.0 + 8.0
		for line in _note:
			_ops.text(UI.font(), UI.S_CAPTION, String(line), x0, y + 15.0, room, UI.DIM)
			y += 30.0
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped


## "Where you stand" for one phase: a centre-zero meter per contest (their half left, yours right, the signed number printed),
## two columns, one in large text. One Control.
class _Stand extends Control:
	var rows: Array = []      # [[label, edge], ...]
	var draw_count := 0
	var _ops := CardKit.Ops.new()
	const CELL_H := 76.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resized.connect(queue_redraw)
		CompKit.set_cue(self, "centre-zero+sign")

	func cols() -> int:
		return 1 if UI.large else 2

	func set_rows(r: Array) -> void:
		if r == rows:
			return
		rows = r.duplicate(true)
		var n := ceili(float(rows.size()) / float(cols()))
		custom_minimum_size = Vector2(0, 48.0 + float(n) * CELL_H if not rows.is_empty() else 0.0)
		queue_redraw()

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		if rows.is_empty():
			return
		var sb := UI.font("SemiBold")
		_ops.text(sb, UI.S_SMALL, Strings.t("gp.stand_h"), 0.0, 20.0, size.x, UI.TEAL_HI)
		var c := cols()
		var gap := 24.0
		var cw := (size.x - gap * float(c - 1)) / float(c)
		for i in rows.size():
			var x := float(i % c) * (cw + gap)
			var y := 48.0 + float(i / c) * CELL_H
			var e := float(rows[i][1])
			var num := UI.pct(e)
			var nf := UI.font("SemiBold", true)
			var nw := CardKit.text_w(nf, UI.S_SMALL, num)
			_ops.text(UI.font(), UI.S_SMALL, String(rows[i][0]), x, y + 18.0, cw - nw - 12.0, UI.TEXT)
			_ops.text(nf, UI.S_SMALL, num, x + cw - nw, y + 18.0, nw + 2.0, UI.delta_color(e) if absf(e) > 0.0005 else UI.DIM)
			var bar := Rect2(x, y + 42.0, cw, 10.0)
			_ops.shape("solid", bar, UI.PANEL3)
			var half := bar.size.x * 0.5
			var f := maxf(clampf(absf(e) / 0.20, 0.0, 1.0) * half, 3.0)
			if e >= 0.0:
				_ops.shape("solid", Rect2(bar.position.x + half, bar.position.y, f, bar.size.y), UI.ACCENT)
			else:
				_ops.shape("solid", Rect2(bar.position.x + half - f, bar.position.y, f, bar.size.y), UI.CORAL)
			_ops.shape("solid", Rect2(bar.position.x + half - 1.0, bar.position.y - 5.0, 2.0, bar.size.y + 10.0), UI.TEXT)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped


# ---- life -------------------------------------------------------------------------------------------------------------------------

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
	_edges = _contest_edges()
	setup("", Callable(), false)
	_build()
	if App.tutorial != null:
		App.tutorial.register_shortcut("gp_coach_apply", _coach_apply)
	_refresh()


func _exit_tree() -> void:
	if App.tutorial != null and is_instance_valid(App.tutorial):
		App.tutorial.unregister_shortcut("gp_coach_apply", _coach_apply)
	_drop_toasts()


func _raise(event_name: String, data: Dictionary = {}) -> void:
	if is_instance_valid(App.bus):
		App.bus.emit(event_name, data)


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


func _contest_edges() -> Dictionary:
	var rt := GamePlan.contest_ratings(_ta, _tb, MatchRunner.sim_params())
	var sgn := 1.0 if my_side == "B" else -1.0
	var out := {}
	for k in GamePlan.CONTESTS:
		var a: float = rt[k][0]
		var b: float = rt[k][1]
		out[k] = sgn * (a - b) / ((a + b) / 2.0)
	return out


## [with the plan set as it is, with a balanced plan], from your side (exactly the old _edge_preview).
func edge_values() -> Array:
	var p := MatchRunner.sim_params()
	var sgn := 1.0 if my_side == "B" else -1.0
	return [sgn * GamePlan.expected_final(_ta, _tb, p, {my_side: _plan_set()}), sgn * GamePlan.expected_final(_ta, _tb, p, {})]


# ---- building (once) ----------------------------------------------------------------------------------------------------------

func _build() -> void:
	build_count += 1
	ArtWire.prepare(App.world.club_ids, [])
	body.add_theme_constant_override("separation", 12)
	header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, UI.HEADER_H)
	header.add_theme_constant_override("separation", 8)
	var back := UI.button("<", go_back, "normal", UI.BTN_H)
	back.custom_minimum_size = Vector2(UI.BTN_H, UI.BTN_H)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back)
	var title := UI.label(Strings.t("gp.title"), UI.S_BIG, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)
	plan_chip = UI.button("", _open_plans, "normal", UI.BTN_H)
	plan_chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	plan_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plan_chip.autowrap_mode = TextServer.AUTOWRAP_OFF
	plan_chip.add_theme_font_size_override("font_size", UI.S_SMALL)
	UI.tag(plan_chip, "gp.plan_chip")
	header.add_child(plan_chip)
	if help_slot != null and help_slot.get_parent() == self:
		remove_child(help_slot)
		help_slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
		help_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
		header.add_child(help_slot)
	body.add_child(header)
	hero = _Hero.new()
	UI.tag(hero, "gp.edge", false)
	body.add_child(hero)
	var ph: Array = []
	for id in PhaseStrip.ALL:
		ph.append({"id": id, "label": PlanKit.name_of_phase(id), "caption": _lead_caption(id), "controls": PAGE[id]})
	strip = PhaseStrip.new(ph, _phase, _set_phase, false, "gp.phases")
	body.add_child(strip)
	page_scroll = ScrollContainer.new()
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(page_scroll)
	page = VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 20)
	page_scroll.add_child(page)
	UI.tag(page_scroll, "gp.sliders", false)    # lesson L5 (I-23): the controls of the page
	note_label = UI.label("", UI.S_SMALL, UI.WARN)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note_label)
	off_card = DepthCard.new()
	off_label = UI.label("", UI.S_BODY, UI.TEXT)
	off_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	off_card.content.add_child(off_label)
	off_button = UI.button(Strings.t("gp.trigger_off"), _toggle_trigger, "primary")
	UI.tag(off_button, "gp.trigger_on")
	off_card.content.add_child(off_button)
	page.add_child(off_card)
	stand = _Stand.new()
	UI.tag(stand, "gp.contests", false)    # lesson L5 (I-23)
	page.add_child(stand)
	for id in GamePlan.SLIDERS:
		var t := DetentTrack.new(id, 0, _on_track, {}, "gp.c." + id)
		tracks[id] = t
		page.add_child(t)
	jf_box = VBoxContainer.new()
	jf_box.add_theme_constant_override("separation", 8)
	jf_box.add_child(UI.label(Strings.t("gp.c.jf.name"), UI.S_BODY, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	jf_bar = DraftKit.RoleBar.new(_set_jf, "gp.c.jf", _jf_options(false), "none")
	jf_box.add_child(jf_bar)
	jf_note = UI.label("", UI.S_SMALL, UI.DIM)
	jf_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	jf_box.add_child(jf_note)
	page.add_child(jf_box)
	# the order on each page: the stand first, then the controls in the PAGE order
	for id in ["g", "r", "t", "a", "s"]:
		page.move_child(tracks[id], -1)
	page.move_child(jf_box, -1)
	page.move_child(tracks["m"], -1)
	page.move_child(tracks["l"], -1)
	var foot := HBoxContainer.new()
	foot.custom_minimum_size = Vector2(0, 112)
	foot.add_theme_constant_override("separation", 12)
	coach_button = UI.button(Strings.t("gp.coach"), _coach, "normal")
	coach_button.custom_minimum_size = Vector2(160, UI.BTN_H)
	coach_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	coach_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.tag(coach_button, "gp.coach")
	foot.add_child(coach_button)
	reset_button = UI.button(Strings.t("gp.reset_short"), _reset, "flat")
	reset_button.custom_minimum_size = Vector2(130, UI.BTN_H)
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for k in ["font_color", "font_hover_color"]:
		reset_button.add_theme_color_override(k, UI.TEAL_HI)
	foot.add_child(reset_button)
	start_button = UI.button(Strings.t("draft.start_match"), _start, "play")
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.tag(start_button, "gp.start_match")
	foot.add_child(start_button)
	body.add_child(foot)


func _jf_options(locked: bool) -> Array:
	var out: Array = []
	for jf in GamePlan.JUNGLE_CHOICES:
		out.append({"id": jf, "label": Strings.t("gp.jf." + jf), "icon": JF_ICONS[jf], "locked": locked})
	return out


func _lead_caption(ph: String) -> String:
	var ids: Array = GamePlan.CONTESTS if ph == "overall" else STAND[ph]
	var n := 0
	for k in ids:
		if float(_edges.get(k, 0.0)) > 0.0:
			n += 1
	return Strings.f("gp.lead", {"n": n, "m": ids.size()})


## The full rebuild (kept for completeness; no tap calls it: `rebuild_count` is the in-place audit).
func _rebuild() -> void:
	rebuild_count += 1
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	tracks.clear()
	_build()
	_refresh()


# ---- refreshing (every change) -------------------------------------------------------------------------------------------------

func _refresh() -> void:
	refresh_count += 1
	var plan: Variant = _cur_plan()
	var trig := _tab != "default"
	var on := plan != null
	var n_on := (_plan_set()["triggers"] as Array).filter(func(t: Dictionary) -> bool: return TABS.has(String(t["when"]))).size()
	var chip := Strings.f("gp.plan_chip", {"name": Strings.t("gp.tab." + _tab)})
	if _tab == "default" and n_on > 0:
		chip = Strings.f("gp.plan_chip_more", {"name": Strings.t("gp.tab." + _tab), "n": n_on})
	if plan_chip.text != chip:
		plan_chip.text = chip
	var ev := edge_values()
	hero.set_values(float(ev[0]), float(ev[1]))
	strip.set_locked("early", trig)
	strip.set_selected(_phase)
	# the page
	off_card.visible = trig and not on
	if trig and not on:
		off_label.text = Strings.t("gp.trigger_hint." + _tab)
	var note := ""
	if trig and on:
		note = Strings.t("gp.trigger_hint." + _tab)
		if _phase == "early":
			note = Strings.t("gp.trigger_locked") + ". " + note
	note_label.text = note
	note_label.visible = note != ""
	var rows: Array = []
	if STAND.has(_phase) and not (trig and not on):
		for k in STAND[_phase]:
			rows.append([_contest_name(k), _edges[k]])
	stand.set_rows(rows)
	stand.visible = not rows.is_empty()
	var ids: Array = PAGE[_phase]
	for id in GamePlan.SLIDERS:
		var t: DetentTrack = tracks[id]
		t.visible = on and ids.has(id)
		if on:
			t.set_value(int(plan.get(id, 0)))
			t.set_inert(_inert_kind(id))
	jf_box.visible = on and ids.has("jf")
	if on:
		var jf_inert := _inert_kind("jf") == "full"
		var opts := _jf_options(jf_inert)
		if opts != jf_bar.options:
			jf_bar.options = opts
			jf_bar.queue_redraw()
		jf_bar.set_selected(String(plan.get("jf", "none")))
		jf_note.text = Strings.t("gp.trigger_locked") if jf_inert else Strings.t("gp.c.jf.hint")
	coach_button.disabled = not on
	reset_button.disabled = not on


## "" normal, "partial" (only part of it applies in this plan), "full" (no effect in this plan: inert).
func _inert_kind(id: String) -> String:
	if _tab == "default":
		return ""
	match PhaseStrip.effect_kind(id, TRIGGER_ACTIVE):
		"none":
			return "full"
		"partial":
			return "partial"
	return ""


func _contest_name(k: String) -> String:
	match k:
		"mid_lane":
			return Strings.t("gp.contest.mid")
		"obj_mid", "obj_late":
			return Strings.t("gp.contest.obj")
		"fight_mid", "fight_late":
			return Strings.t("gp.contest.fight")
	return Strings.t("gp.contest." + k)


# ---- actions ------------------------------------------------------------------------------------------------------------------

func _set_phase(ph: String) -> void:
	if not PAGE.has(ph):
		return
	_phase = ph
	page_scroll.scroll_vertical = 0
	_refresh()


func _set_tab(t: String) -> void:
	if not TABS.has(t):
		return
	_tab = t
	_refresh()


func _on_track(id: String, v: int) -> void:
	_set_value(id, v)


func _set_value(id: String, v: int) -> void:
	var plan: Variant = _cur_plan()
	if plan != null:
		plan[id] = v
		App.autosave()
		_refresh()


func _set_jf(jf: Variant) -> void:
	var plan: Variant = _cur_plan()
	if plan != null:
		plan["jf"] = String(jf)
		App.autosave()
		_refresh()


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
	_refresh()


func _start() -> void:
	App.autosave()
	ScreenDraft.launch(game, draft)


## The word for a plan value: the end word, "(half)" for a half step, Balanced at 0.
static func value_word(id: String, v: int) -> String:
	var lb := DetentTrack.labels_for(id)
	var i := DetentTrack.snap_index(float(v))
	match i:
		0:
			return String(lb["neg"])
		1:
			return Strings.f("gp.half", {"word": lb["neg"]})
		3:
			return Strings.f("gp.half", {"word": lb["pos"]})
		4:
			return String(lb["pos"])
	return String(lb["balanced"])


## The Coach's changes to the plan on show: [[control name, from word, to word], ...] (controls that do nothing in this plan are
## applied but not listed: they change nothing).
func coach_changes(sug: Dictionary) -> Array:
	var plan: Variant = _cur_plan()
	var out: Array = []
	if plan == null:
		return out
	for id in GamePlan.SLIDERS + ["jf"]:
		if not sug.has(id) or _inert_kind(id) == "full":
			continue
		if id == "jf":
			if String(sug["jf"]) != String(plan.get("jf", "none")):
				out.append([Strings.t("gp.c.jf.name"), Strings.t("gp.jf." + String(plan.get("jf", "none"))), Strings.t("gp.jf." + String(sug["jf"]))])
		elif int(sug[id]) != int(plan.get(id, 0)):
			out.append([Strings.t("gp.c.%s.name" % id), value_word(id, int(plan.get(id, 0))), value_word(id, int(sug[id]))])
	return out


## Coach: a sheet with the changes and the edge before and after, Apply or Close (UI-PASS-2 6.4).
func _coach() -> void:
	var plan: Variant = _cur_plan()
	if plan == null:
		return
	_sug = GamePlan.suggest(_ta, _tb, MatchRunner.sim_params(), my_side)
	_coach_applied = false
	var sh := BottomSheet.open(Strings.t("gp.coach.h"), _coach_body, _coach_footer, "L" if coach_changes(_sug).size() > 4 or UI.large else "M", "gp_coach")
	sh.closed.connect(_on_coach_closed)
	_raise("gp:coach_open")


func _coach_body(c: Control) -> void:
	var ch := coach_changes(_sug)
	if ch.is_empty():
		var l := UI.label(Strings.t("gp.coach.none"), UI.S_BODY, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(l)
		return
	var before := float(edge_values()[0])
	var after := _edge_with(_sug)
	var e := UI.label(Strings.f("gp.coach.edge", {"from": UI.pct(before), "to": UI.pct(after)}), UI.S_BODY, UI.delta_color(after - before) if absf(after - before) > 0.0005 else UI.DIM, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold")
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(e)
	for row in ch:
		var l2 := UI.label(Strings.f("gp.coach.change", {"control": row[0], "from": row[1], "to": row[2]}), UI.S_SMALL, UI.TEXT)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(l2)


func _coach_footer(f: Control) -> void:
	if coach_changes(_sug).is_empty():
		coach_apply = null
		BottomSheet.footer_button(f, Strings.t("gp.coach.close"), _close_sheet, "primary")
		return
	coach_apply = BottomSheet.footer_button(f, Strings.t("gp.coach.apply"), _coach_apply, "primary", "gp.coach_apply")
	BottomSheet.footer_button(f, Strings.t("gp.coach.close"), _close_sheet, "normal")


## The edge with the Coach's suggestion applied to the plan on show (the plan itself untouched).
func _edge_with(sug: Dictionary) -> float:
	var ps: Dictionary = _plan_set().duplicate(true)
	var target: Dictionary = ps["default"]
	if _tab != "default":
		for t in ps["triggers"]:
			if t["when"] == _tab:
				target = t["plan"]
	for k in sug:
		target[k] = sug[k]
	var sgn := 1.0 if my_side == "B" else -1.0
	return sgn * GamePlan.expected_final(_ta, _tb, MatchRunner.sim_params(), {my_side: ps})


func _on_coach_closed() -> void:
	coach_apply = null
	if not _coach_applied:
		_raise("gp:coach_close")


func _close_sheet() -> void:
	if BottomSheet.is_open():
		BottomSheet.current().close()


func _remember() -> void:
	var plan: Variant = _cur_plan()
	_undo = {"tab": _tab, "plan": (plan as Dictionary).duplicate()} if plan != null else {}


## A toast with Undo, owned by this screen: it goes when the screen goes (an Undo on the match screen must not change the plan).
func _toast_undo(text: String) -> void:
	App.toast(text, UI.TEXT, Strings.t("common.undo"), _undo_last)
	var col: Node = App.main.get("_toasts") if App.main != null else null
	if col != null and col.get_child_count() > 0:
		col.get_child(col.get_child_count() - 1).set_meta("gp_undo", true)


func _drop_toasts() -> void:
	var col: Node = App.main.get("_toasts") if App.main != null else null
	if col == null:
		return
	for c in col.get_children():
		if c.has_meta("gp_undo"):
			col.remove_child(c)
			c.queue_free()


func _undo_last() -> void:
	if _undo.is_empty() or not is_inside_tree():
		return
	var keep := _tab
	_tab = String(_undo["tab"])
	var plan: Variant = _cur_plan()
	if plan != null:
		for k in _undo["plan"]:
			plan[k] = _undo["plan"][k]
		App.autosave()
	_tab = keep
	_undo = {}
	_refresh()


## Apply the Coach's plan to the plan on show (what the old Coach button did), with an Undo toast. Also the tutorial shortcut.
func _coach_apply() -> void:
	var plan: Variant = _cur_plan()
	if plan == null:
		return
	_remember()
	var sug := _sug if not _sug.is_empty() else GamePlan.suggest(_ta, _tb, MatchRunner.sim_params(), my_side)
	for k in sug:
		plan[k] = sug[k]
	_sug = {}
	_coach_applied = true
	App.autosave()
	_refresh()
	_close_sheet()
	_raise("gp:coach_apply")
	_toast_undo(Strings.t("gp.toast.applied"))


func _reset() -> void:
	var plan: Variant = _cur_plan()
	if plan == null:
		return
	_remember()
	var n := GamePlan.neutral()
	for k in n:
		plan[k] = n[k]
	App.autosave()
	_refresh()
	_toast_undo(Strings.t("gp.toast.reset"))


# ---- the plan sheet -------------------------------------------------------------------------------------------------------------

func _open_plans() -> void:
	BottomSheet.open(Strings.t("gp.plans.h"), _plans_body, Callable(), "M", "gp_plans")


func _trigger_on(t: String) -> bool:
	for tr in _plan_set()["triggers"]:
		if tr["when"] == t:
			return true
	return false


func _plans_body(c: Control) -> void:
	for t in TABS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var sel := UI.button(Strings.t("gp.tab." + t), _pick_tab.bind(t), "primary" if _tab == t else "normal")
		sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.tag(sel, "gp.plans." + t)
		row.add_child(sel)
		if t != "default":
			var on := _trigger_on(t)
			var sw := UI.button(Strings.t("gp.toggle.on" if on else "gp.toggle.off"), _sheet_toggle.bind(t), "normal")
			sw.custom_minimum_size = Vector2(150, UI.BTN_H)
			sw.size_flags_horizontal = Control.SIZE_SHRINK_END
			UI.tag(sw, "gp.plans.%s.switch" % t)
			row.add_child(sw)
		c.add_child(row)
		var hint := UI.label(Strings.t("gp.trigger_hint." + t) if t != "default" else Strings.t("gp.plans.default_hint"), UI.S_SMALL, UI.DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(hint)


func _pick_tab(t: String) -> void:
	_set_tab(t)
	_close_sheet()


func _sheet_toggle(t: String) -> void:
	var keep := _tab
	_tab = t
	_toggle_trigger()
	_tab = keep
	_refresh()
	# the sheet is small: open it again with the new switch words (replaces the open one in place)
	_open_plans()
