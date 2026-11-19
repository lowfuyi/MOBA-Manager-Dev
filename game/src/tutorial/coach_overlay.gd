class_name CoachOverlay
extends Control
## The visible half of the tutorial (build plan 0.7 I-12, TUTORIAL 3.4, 7.1 to 7.4). One full-rect Control that lives on the overlay
## slot (CanvasLayer 100, above sheets and toasts). It draws FOUR dim panels around a hole rectangle (no shader), an info-step
## blocker over the hole, a ring with a pointer, and a card (chapter row, text, Skip, Next or a one-tap shortcut). It does not know
## the tutorial's rules: `TutorialRunner` hands it a step card (`TutorialState.card()` plus the text) and listens for
## `button_pressed` ("skip", "next", "start", "go_home", "shortcut") and `fell_back`.
##
## How a step is shown (mode): wait (look for the tag(s) with UI.find_tag each frame; nothing is dimmed, except that the visuals of
## the step before stay for GRACE_S so the screen does not flash) -> scroll (every ScrollContainer above the target is moved so it is
## on screen, one 240 ms tween) -> settle (the hole rectangle has to be unchanged for 2 frames, the card text needs them to wrap)
## -> shown (the hole follows the target; the geometry is recomputed ONLY when its rectangle changes) or fallback (the tag stayed
## missing: a card at the bottom, no hole, with Next; counted in `fallbacks`). Nothing runs (`set_process(false)`) when no step is up.
## Touches: the four panels are STOP, the hole is empty space so a tap in it reaches the real control (even inside a BottomSheet on
## a lower layer, S2 of SPIKE-RESULTS-0.7). An info step puts a STOP blocker over the hole. A stray tap (a tap on a panel or the
## blocker) nudges the card and pulses the ring; two within 5 s show the nudge line; four make Skip pulse.
## Animations: one tween at a time, none longer than 250 ms, none loops, all skipped when UI.animate is false.
## Layer note: a CanvasLayer drops Main's theme, so the runner sets `theme` and every button here sets its font size itself.

signal button_pressed(button_id: String)
signal fell_back(step_id: String)

const DIM_FULL := 0.8
const DIM_LIGHT := 0.45
const PAD := 8.0                 # the hole is the target plus 8 px (S2 row: the 8 px margin reaches the sheet panel)
const SETTLE_FRAMES := 2
const WAIT_S := 6.0              # a step whose target exists but is not on screen yet (the draft waits for the AI)
const MISSING_S := 2.0           # no control carries the id at all although the step's screen is up
const GRACE_S := 0.3             # how long the visuals of the step before stay while the next target is being found
const SIDE := 16.0
const TOP_MIN := 64.0            # 48 existing top margin + 16
const BOTTOM_MIN := 40.0         # 24 + 16
const MAX_FRAC := 0.45
const MAX_FRAC_COMPACT := 0.35
const POINTER_W := 36.0
const POINTER_H := 18.0
const RING_W := 4.0
const GLOW_W := 10.0
const NUDGE_WINDOW_S := 5.0
const T_DIM := 0.16
const T_MOVE := 0.22
const T_CARD := 0.16
const T_PULSE := 0.12
const T_NUDGE := 0.12
const T_TICK := 0.18
const T_SCROLL := 0.24

## Tests (and nothing else) shorten these.
var wait_s := WAIT_S
var missing_s := MISSING_S
var grace_s := GRACE_S

var mode := "idle"               # idle | wait | scroll | settle | shown | fallback
var step_id := ""
var stage := "a"
var fallbacks := 0
var nudges := 0
var layout_count := 0            # how often the geometry was recomputed (a still target must not add to it)
var dims: Array[ColorRect] = []
var blocker: Control
var mark: _Mark
var card: PanelContainer
var skip_button: Button
var primary_button: Button
## Alpha 0.9.3: the "Leave the tutorial?" question (TUTORIAL 3.4) that Android Back raises over the step card. While it is up the
## step card stays as it was underneath; a scrim takes every tap; its buttons emit button_pressed("keep") or ("skip"). Its nodes are
## built when Back raises it and freed when it goes (the overlay's node budget is for the step card alone).
var asking := false
var ask_scrim: ColorRect
var ask_card: PanelContainer
var _ask_center: CenterContainer
var _ask_buttons: HBoxContainer

var _c: Dictionary = {}
var _text := ""
var _targets: Array[String] = []
var _ctrls: Array = []
var _rect := Rect2()             # the target (union of the targets), global
var _rect_prev := Rect2(-1, -1, -1, -1)
var _hole := Rect2()             # the final hole (padded, clipped), global
var _hole_vis := Rect2()         # the hole as drawn this frame (differs from _hole only while it moves)
var _from := Rect2()
var _has_hole := false
var _had_hole := false           # the step before had a hole on screen (the new hole slides from it)
var _vis := false                # the dim, hole and card are on screen
var _dim_a := 0.0
var _moving := false
var _move_t := 1.0
var _pulse := 0.0
var _card_dy := 0.0
var _nudge_dx := 0.0
var _card_pos := Vector2.ZERO
var _side := ""
var _show_ptr := false
var _ptr_dir := 1
var _wait_t := 0.0
var _stable := 0
var _last_cm := -1.0
var _last_label_h := -1.0
var _last_vp := Vector2.ZERO
var _tw: Tween
var _stray := TouchTrack.new()
var _stray_times: Array = []
var _chapter_row: VBoxContainer
var _chapter_lbl: Label
var _bar: ProgressBar
var _body_scroll: ScrollContainer
var _body: Label
var _nudge_lbl: Label
var _buttons: HBoxContainer
var _fb := false
var _fb_buttons: Array = []


## The ring and the pointer: one Control, drawn only when its rectangle or pulse changes (queue_redraw), never takes a tap.
class _Mark extends Control:
	var rect := Rect2()
	var on := false
	var pulse := 0.0
	var ptr := false
	var ptr_dir := 1
	var _ring := StyleBoxFlat.new()
	var _glow := StyleBoxFlat.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ring.bg_color = Color(0, 0, 0, 0)
		_ring.draw_center = false
		_ring.set_border_width_all(int(CoachOverlay.RING_W))
		_ring.border_color = UI.TEAL_HI
		_glow.bg_color = Color(0, 0, 0, 0)
		_glow.draw_center = false
		_glow.set_border_width_all(int(CoachOverlay.GLOW_W))
		_glow.border_color = Color(UI.TEAL_HI, 0.25)

	func _draw() -> void:
		if not on or rect.size.x < 1.0 or rect.size.y < 1.0:
			return
		var r := rect.grow(pulse * 0.03 * maxf(rect.size.x, rect.size.y))
		var rad := int(minf(28.0, minf(r.size.x, r.size.y) * 0.5))
		_glow.set_corner_radius_all(rad + int(CoachOverlay.GLOW_W))
		draw_style_box(_glow, r.grow(CoachOverlay.GLOW_W))
		_ring.set_corner_radius_all(rad)
		draw_style_box(_ring, r)
		if ptr:
			var cx := clampf(rect.get_center().x, rect.position.x + 24.0, rect.end.x - 24.0)
			var gap := CoachOverlay.GLOW_W + 2.0
			var h := CoachOverlay.POINTER_H
			var w := CoachOverlay.POINTER_W * 0.5
			if ptr_dir > 0:    # the card is below: the apex points up at the hole
				var y := r.end.y + gap
				draw_colored_polygon(PackedVector2Array([Vector2(cx, y), Vector2(cx - w, y + h), Vector2(cx + w, y + h)]), UI.TEAL_HI)
			else:
				var y2 := r.position.y - gap
				draw_colored_polygon(PackedVector2Array([Vector2(cx, y2), Vector2(cx - w, y2 - h), Vector2(cx + w, y2 - h)]), UI.TEAL_HI)


func _init() -> void:
	name = "CoachOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	for i in 4:
		var d := ColorRect.new()
		d.name = "Dim%d" % i
		d.color = Color(UI.BG, DIM_FULL)
		d.mouse_filter = Control.MOUSE_FILTER_STOP
		d.gui_input.connect(_on_dim_input)
		add_child(d)
		dims.append(d)
	blocker = Control.new()
	blocker.name = "Blocker"
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	blocker.gui_input.connect(_on_dim_input)
	add_child(blocker)
	mark = _Mark.new()
	mark.name = "Mark"
	add_child(mark)
	_build_card()
	set_process(false)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_on_viewport_changed)


func _exit_tree() -> void:
	_kill_tw()
	_stray.reset()


# ---- the card ----------------------------------------------------------------------------------------------------------

func _build_card() -> void:
	card = PanelContainer.new()
	card.name = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", UI.box(UI.PANEL3, UI.R_CARD, 24, Color(UI.ACCENT, 0.7), 2))
	card.visible = false
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	_chapter_row = VBoxContainer.new()
	_chapter_row.add_theme_constant_override("separation", 8)
	col.add_child(_chapter_row)
	_chapter_lbl = UI.label("", UI.S_SMALL, UI.TEXT2)
	_chapter_row.add_child(_chapter_lbl)
	_bar = UI.bar(0.0, 27.0, UI.ACCENT, 8)
	_chapter_row.add_child(_bar)
	_body_scroll = ScrollContainer.new()
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_body_scroll)
	_body = UI.label("", UI.S_BODY, UI.TEXT)
	_body_scroll.add_child(_body)
	_nudge_lbl = UI.label("", UI.S_SMALL, UI.TEAL_HI)
	_nudge_lbl.visible = false
	col.add_child(_nudge_lbl)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_buttons)


func _build_ask() -> void:
	if ask_scrim != null:
		return
	ask_scrim = ColorRect.new()
	ask_scrim.name = "AskScrim"
	ask_scrim.color = Color(0, 0, 0, 0.6)
	ask_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	ask_scrim.visible = false
	ask_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ask_scrim)
	_ask_center = CenterContainer.new()
	_ask_center.name = "Ask"
	_ask_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ask_center.visible = false
	_ask_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ask_center)
	ask_card = PanelContainer.new()
	ask_card.name = "AskCard"
	ask_card.mouse_filter = Control.MOUSE_FILTER_STOP
	ask_card.add_theme_stylebox_override("panel", UI.box(UI.PANEL3, UI.R_CARD, 24, Color(UI.ACCENT, 0.7), 2))
	_ask_center.add_child(ask_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	ask_card.add_child(col)
	var h := UI.label(Strings.t("tut.back.h"), UI.S_HEAD, UI.TEXT)
	h.name = "AskTitle"
	col.add_child(h)
	var body := UI.label(Strings.t("tut.back.body"), UI.S_BODY, UI.TEXT2)
	body.name = "AskBody"
	col.add_child(body)
	_ask_buttons = HBoxContainer.new()
	_ask_buttons.add_theme_constant_override("separation", 12)
	col.add_child(_ask_buttons)
	var skip := UI.button(Strings.t("tut.skip"), _on_button.bind("skip"), "flat", UI.BTN_H)
	skip.name = "AskBtn_skip"
	skip.add_theme_font_size_override("font_size", UI.S_BODY)    # explicit: a CanvasLayer drops Main's theme
	var sb := UI.box(Color(0, 0, 0, 0), 14, 10, Color(UI.TEXT2, 0.5), 2)
	for st in ["normal", "hover", "pressed"]:
		skip.add_theme_stylebox_override(st, sb)
	skip.add_theme_color_override("font_color", UI.TEXT)
	skip.size_flags_stretch_ratio = 40.0
	_ask_buttons.add_child(skip)
	var keep := UI.button(Strings.t("tut.back.keep"), _on_button.bind("keep"), "primary", UI.BTN_H)
	keep.name = "AskBtn_keep"
	keep.add_theme_font_size_override("font_size", UI.S_BODY)
	keep.size_flags_stretch_ratio = 60.0
	_ask_buttons.add_child(keep)


## Raise the "Leave the tutorial?" question over the step on screen (the step itself is not touched).
func ask_leave() -> void:
	_build_ask()
	asking = true
	ask_card.custom_minimum_size.x = minf(680.0, _vp().x - 2.0 * SIDE)
	ask_scrim.visible = true
	_ask_center.visible = true
	ask_scrim.move_to_front()
	_ask_center.move_to_front()


## Take the question away (Keep going, Back again, or a new step): the step card is as it was.
func end_ask() -> void:
	asking = false
	if ask_scrim != null:
		remove_child(ask_scrim)
		ask_scrim.queue_free()
		remove_child(_ask_center)
		_ask_center.queue_free()
	ask_scrim = null
	ask_card = null
	_ask_center = null
	_ask_buttons = null


func _fill_card() -> void:
	var total := maxi(1, TutorialState.STEP_IDS.size())
	var step_no := int(_c.get("step_no", 1))
	_chapter_lbl.text = UI.tidy(Strings.t(String(_c.get("chapter_key", ""))))
	_bar.max_value = float(total)
	_bar.value = float(maxi(0, step_no - 1)) if not UI.animate or not _vis else _bar.value
	_body.text = UI.tidy(_text)
	_chapter_row.visible = not bool(_c.get("compact", false))
	_nudge_lbl.visible = false
	_nudge_lbl.text = UI.tidy(Strings.t("tut.nudge"))
	_stray_times.clear()
	_body_scroll.custom_minimum_size.y = 0.0
	var cw := minf(680.0, _vp().x - 2.0 * SIDE)    # the card gets its width at once, so the text wraps before the first measurement
	card.custom_minimum_size.x = cw
	card.size.x = cw
	for ch in _buttons.get_children():
		_buttons.remove_child(ch)
		ch.queue_free()
	skip_button = null
	primary_button = null
	var ids: Array = (_c.get("buttons", []) as Array).duplicate()
	if _fb and not ids.has("next"):
		ids.append("next")
	for b in ids:
		_add_button(String(b), ids.size())


func _add_button(id: String, count: int) -> void:
	var text := ""
	var kind := "primary"
	match id:
		"skip":
			text = Strings.t(String(_c.get("skip_key", "tut.skip")))    # a lesson says "Skip lesson" (I-23)
			kind = "flat"
		"next":
			text = Strings.t("tut.next")
		"start":
			text = Strings.t("tut.start")
		"go_home":
			text = Strings.t("tut.go_home")
		"shortcut":
			text = Strings.t(String(_c.get("shortcut_key", "tut.next")))
		_:
			return
	var b := UI.button(text, _on_button.bind(id), kind, UI.BTN_H)
	b.add_theme_font_size_override("font_size", UI.S_BODY)    # explicit: a CanvasLayer drops Main's theme
	b.name = "Btn_" + id
	if id == "skip":
		var sb := UI.box(Color(0, 0, 0, 0), 14, 10, Color(UI.TEXT2, 0.5), 2)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_color", UI.TEXT)
		b.size_flags_stretch_ratio = 40.0
		skip_button = b
		if count == 1:
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			b.custom_minimum_size.x = 300.0
	else:
		b.size_flags_stretch_ratio = 60.0
		primary_button = b
	_buttons.add_child(b)


func _on_button(id: String) -> void:
	call_deferred("_emit_button", id)    # deferred: the handler may rebuild this card from inside the button's own signal


func _emit_button(id: String) -> void:
	button_pressed.emit(id)


## Test hook: the same as a finger on the button.
func press(id: String) -> bool:
	var b := (_ask_buttons.get_node_or_null("AskBtn_" + id) if asking else _buttons.get_node_or_null("Btn_" + id)) as Button
	if b == null or not b.is_visible_in_tree():
		return false
	b.pressed.emit()
	return true


func button_ids() -> Array:
	var out: Array = []
	for b in (_ask_buttons if asking else _buttons).get_children():
		out.append(String(b.name).trim_prefix("AskBtn_").trim_prefix("Btn_"))
	return out


func body_text() -> String:
	return UI.plain(_body.text)


func nudge_text() -> String:
	return UI.plain(_nudge_lbl.text) if _nudge_lbl.visible else ""


# ---- public state -------------------------------------------------------------------------------------------------------

func is_up() -> bool:
	return mode != "idle"


## True while something is on screen (a hole and a card, or the fallback card); false while the target is still being found.
func is_showing() -> bool:
	return mode == "shown" or mode == "fallback" or (_vis and mode != "idle")


func is_fallback() -> bool:
	return _fb


func card_data() -> Dictionary:
	return _c


func hole_rect() -> Rect2:
	return _hole if _has_hole and _vis else Rect2()


func target_rect() -> Rect2:
	return _rect


func card_rect() -> Rect2:
	return card.get_global_rect() if card.visible else Rect2()


func blocker_on() -> bool:
	return blocker.visible


func panels_on() -> bool:
	return dims[0].visible


func animating() -> bool:
	return _tw != null and _tw.is_valid() and _tw.is_running()


# ---- showing a step -----------------------------------------------------------------------------------------------------

## Show the step described by `c` (a TutorialState.card() dictionary, plus optional "screen" and "screen_now" for the
## missing-target timeout) with `text` as the coach line.
func show_step(c: Dictionary, text: String) -> void:
	end_ask()
	_snap_final()
	_c = c.duplicate(true)
	step_id = String(c.get("id", ""))
	stage = String(c.get("stage", "a"))
	_text = text
	_targets.clear()
	for t in c.get("target", []):
		_targets.append(String(t))
	_ctrls.clear()
	_had_hole = _has_hole and _vis
	_fb = false
	_wait_t = 0.0
	_stable = 0
	_rect_prev = Rect2(-1, -1, -1, -1)
	_has_hole = false
	_fill_card()
	visible = true
	set_process(true)
	if _targets.is_empty():
		_rect = Rect2()
		_enter("settle")
	else:
		_enter_wait()


## No step: nothing on screen, nothing running.
func clear() -> void:
	end_ask()
	_kill_tw()
	mode = "idle"
	step_id = ""
	_vis = false
	_has_hole = false
	_fb = false
	_ctrls.clear()
	_c = {}
	set_process(false)
	_hide_parts()
	visible = false


func _enter(m: String) -> void:
	mode = m
	_stable = 0
	if m == "settle" and not card.visible:
		# a hidden container is not laid out, so the text would not wrap: probe it invisibly (no touches, no alpha) while settling
		card.visible = true
		card.modulate.a = 0.0
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _enter_wait() -> void:
	_enter("wait")
	_wait_t = 0.0
	if _vis:
		# the step before is still drawn: keep its dim, hide its ring and card, and block taps until the new target is found
		card.visible = false
		mark.on = false
		mark.queue_redraw()
		_update_blocker()
	else:
		_hide_parts()


func _hide_parts() -> void:
	for d in dims:
		d.visible = false
	blocker.visible = false
	card.visible = false
	mark.on = false
	mark.queue_redraw()


func _process(delta: float) -> void:
	match mode:
		"wait":
			_tick_wait(delta)
		"scroll":
			_wait_t += delta
			if _wait_t > 1.0:    # a tween that died with its target must not hold the step forever
				_kill_tw()
				_enter("settle")
		"settle":
			_tick_settle()
		"shown":
			_tick_follow()
		_:
			set_process(false)


# ---- finding the target --------------------------------------------------------------------------------------------------

func _find_all() -> bool:
	_ctrls.clear()
	var first := true
	for id in _targets:
		var ctl := UI.find_tag(id)
		if ctl == null:
			return false
		var r := ctl.get_global_rect()
		if r.size.x < 1.0 or r.size.y < 1.0:
			return false
		_ctrls.append(ctl)
		if first:
			_rect = r
			first = false
		else:
			_rect = _rect.merge(r)
	return true


func _tick_wait(delta: float) -> void:
	_wait_t += delta
	if _find_all():
		var plan := _plan_scroll()
		if plan.is_empty():
			_enter("settle")
		else:
			_run_scroll(plan)
		return
	if _vis and _wait_t > grace_s:
		_vis = false
		_hide_parts()    # no dim and no card while the target is not on screen
	var missing := false
	for id in _targets:
		if UI.tag_count(id) == 0:
			missing = true
	var on_screen := String(_c.get("screen", "")) != "" and String(_c.get("screen", "")) == String(_c.get("screen_now", "-"))
	var limit := missing_s if (missing and on_screen) else wait_s
	if _wait_t >= limit:
		_enter_fallback()


func _tick_settle() -> void:
	if not _targets.is_empty() and not _fb and not _find_all():
		_enter_wait()
		return
	if _rect == _rect_prev:
		_stable += 1
	else:
		_stable = 0
		_rect_prev = _rect
	if _stable >= SETTLE_FRAMES:
		_reveal()


func _tick_follow() -> void:
	var vp := _vp()
	if vp != _last_vp:
		_relayout()
		return
	if not _targets.is_empty():
		var u := Rect2()
		var first := true
		for ctl in _ctrls:
			if not is_instance_valid(ctl) or not (ctl as Control).is_visible_in_tree():
				_enter_wait()    # the screen was rebuilt: find the new control
				return
			var r := (ctl as Control).get_global_rect()
			u = r if first else u.merge(r)
			first = false
		if u != _rect:
			_rect = u
			_relayout()
			return
	if absf(card.get_combined_minimum_size().y - _last_cm) > 0.5 or absf(_body.get_combined_minimum_size().y - _last_label_h) > 0.5:
		_relayout()


func _enter_fallback() -> void:
	_fb = true
	fallbacks += 1
	_rect = Rect2()
	_ctrls.clear()
	_fill_card()
	_nudge_lbl.text = UI.tidy(Strings.t("tut.fallback"))
	_nudge_lbl.visible = true
	fell_back.emit(step_id)
	_enter("settle")


# ---- scrolling the target into view --------------------------------------------------------------------------------------

## Walk the ancestors of the first target from the inside out; every ScrollContainer that does not show it gets a new scroll
## position (the target sits at about 40 percent of the view; one taller than the view lines its top up 24 px below the top).
func _plan_scroll() -> Array:
	var plan: Array = []
	if _ctrls.is_empty():
		return plan
	var t := _ctrls[0] as Control
	var r := t.get_global_rect()
	var node: Node = t.get_parent()
	while node != null:
		if node is ScrollContainer:
			var sc := node as ScrollContainer
			var view := sc.get_global_rect()
			var nv := sc.scroll_vertical
			var nh := sc.scroll_horizontal
			if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and (r.position.y < view.position.y or r.end.y > view.end.y):
				var want := view.position.y + 24.0 if r.size.y > view.size.y else view.position.y + (view.size.y - r.size.y) * 0.4
				var bar := sc.get_v_scroll_bar()
				nv = clampi(int(round(float(sc.scroll_vertical) + r.position.y - want)), 0, maxi(0, int(bar.max_value - bar.page)))
			if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and (r.position.x < view.position.x or r.end.x > view.end.x):
				var wantx := view.position.x + 24.0 if r.size.x > view.size.x else view.position.x + (view.size.x - r.size.x) * 0.5
				var hbar := sc.get_h_scroll_bar()
				nh = clampi(int(round(float(sc.scroll_horizontal) + r.position.x - wantx)), 0, maxi(0, int(hbar.max_value - hbar.page)))
			if nv != sc.scroll_vertical or nh != sc.scroll_horizontal:
				plan.append({"sc": sc, "v": nv, "h": nh})
				r.position.y -= float(nv - sc.scroll_vertical)
				r.position.x -= float(nh - sc.scroll_horizontal)
		node = node.get_parent()
	return plan


func _run_scroll(plan: Array) -> void:
	_enter("scroll")
	_wait_t = 0.0
	if not UI.animate or not is_inside_tree():
		for p in plan:
			(p["sc"] as ScrollContainer).scroll_vertical = int(p["v"])
			(p["sc"] as ScrollContainer).scroll_horizontal = int(p["h"])
		_enter("settle")
		return
	_kill_tw()
	_tw = create_tween().set_parallel(true)
	for p in plan:
		var sc := p["sc"] as ScrollContainer
		if int(p["v"]) != sc.scroll_vertical:
			_tw.tween_property(sc, "scroll_vertical", int(p["v"]), T_SCROLL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if int(p["h"]) != sc.scroll_horizontal:
			_tw.tween_property(sc, "scroll_horizontal", int(p["h"]), T_SCROLL).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.finished.connect(_on_scroll_done)


func _on_scroll_done() -> void:
	_tw = null
	if mode == "scroll":
		_enter("settle")


# ---- geometry ------------------------------------------------------------------------------------------------------------

func _vp() -> Vector2:
	return get_viewport_rect().size


func _kind_dim() -> float:
	match String(_c.get("dim", "full")):
		"none":
			return 0.0
		"light":
			return DIM_LIGHT
	return DIM_FULL


## Where the hole and the card go. Sets _hole, _has_hole, _card_pos, _show_ptr, _ptr_dir and sizes the card. Returns "ok", "pending"
## (a minimum size was just changed: a container's own minimum is only refreshed at the end of the frame, so measure again after two
## quiet frames) or "nofit" (a target is too tall to leave a usable hole next to the card: the caller falls back).
func _compute() -> String:
	var vp := _vp()
	var cw := minf(680.0, vp.x - 2.0 * SIDE)
	card.custom_minimum_size.x = cw
	var maxh := floorf(vp.y * (MAX_FRAC_COMPACT if bool(_c.get("compact", false)) else MAX_FRAC))
	var label_h := _body.get_combined_minimum_size().y
	var cm := card.get_combined_minimum_size().y
	var fixed := cm - _body_scroll.custom_minimum_size.y
	var body_h := label_h
	if fixed + body_h > maxh:
		if _chapter_row.visible and not _fb:
			_chapter_row.visible = false    # the chapter row goes first
			return "pending"
		body_h = maxf(86.0, maxh - fixed)    # then the body scrolls inside
	if not is_equal_approx(_body_scroll.custom_minimum_size.y, body_h):
		_body_scroll.custom_minimum_size.y = body_h
		return "pending"
	var ch := fixed + body_h
	_last_cm = cm
	_last_label_h = label_h
	card.size = Vector2(cw, ch)
	_last_vp = vp
	var cx := floorf((vp.x - cw) * 0.5)
	_has_hole = false
	_show_ptr = false
	if _targets.is_empty() or _fb:
		var y: float
		if _fb or String(_c.get("kind", "")) != "modal":
			y = vp.y - BOTTOM_MIN - ch
		else:
			y = floorf((vp.y - ch) * 0.5)
		_card_pos = Vector2(cx, y)
		return "ok"
	var hp := _rect.grow(PAD).intersection(Rect2(Vector2.ZERO, vp))
	if hp.size.x < 1.0 or hp.size.y < 1.0:
		_card_pos = Vector2(cx, vp.y - BOTTOM_MIN - ch)
		return "nofit"
	var p0 := Vector2(floorf(hp.position.x), floorf(hp.position.y))
	var p1 := Vector2(ceilf(hp.end.x), ceilf(hp.end.y))
	var hole := Rect2(p0, p1 - p0)
	_show_ptr = hole.get_area() <= 0.4 * vp.x * vp.y
	var gap := 16.0 + (POINTER_H + GLOW_W + 2.0 if _show_ptr else 0.0)
	var bot_max := vp.y - BOTTOM_MIN
	var room_below := bot_max - (hole.end.y + gap)
	var room_above := (hole.position.y - gap) - TOP_MIN
	var prefer_below := hole.get_center().y < vp.y * 0.5
	var side := _side
	if side == "below" and ch > room_below:
		side = ""
	elif side == "above" and ch > room_above:
		side = ""
	if side == "":
		if prefer_below and ch <= room_below:
			side = "below"
		elif not prefer_below and ch <= room_above:
			side = "above"
		elif ch <= room_below:
			side = "below"
		elif ch <= room_above:
			side = "above"
		else:
			side = "clip_bottom" if prefer_below else "clip_top"
	_side = side
	var y2 := 0.0
	match side:
		"below":
			y2 = hole.end.y + gap
			_ptr_dir = 1
		"above":
			y2 = hole.position.y - gap - ch
			_ptr_dir = -1
		"clip_bottom":
			y2 = bot_max - ch
			hole.size.y = minf(hole.end.y, y2 - 16.0) - hole.position.y
			_show_ptr = false
		_:
			y2 = TOP_MIN
			var ny := maxf(hole.position.y, y2 + ch + 16.0)
			hole.size.y = hole.end.y - ny
			hole.position.y = ny
			_show_ptr = false
	_card_pos = Vector2(cx, y2)
	if hole.size.y < 40.0:
		return "nofit"
	_hole = hole
	_has_hole = true
	return "ok"


func _reveal() -> void:
	var res := _compute()
	if res == "pending":
		_stable = 0
		return
	if res == "nofit" and not _fb:
		_enter_fallback()    # no room for a hole next to the card: the fallback card instead of a card over the target
		return
	var was_vis := _vis and _had_hole and _has_hole
	var from := _hole_vis
	_vis = true
	_enter("fallback" if _fb else "shown")
	if _fb:
		set_process(false)    # a fallback card needs no polling
	_snap_apply()
	if not UI.animate or not is_inside_tree():
		return
	_kill_tw()
	_tw = create_tween().set_parallel(true)
	if was_vis and from != _hole:
		_from = from
		_moving = true
		_move_t = 0.0
		_on_move(0.0)
		_tw.tween_method(_on_move, 0.0, 1.0, T_MOVE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_dim_a = 0.0
		_set_dim(_dim_a)
		_tw.tween_method(_on_dim, 0.0, _kind_dim(), T_DIM)
	_card_dy = 24.0
	card.modulate.a = 0.0
	_apply_card()
	_tw.tween_method(_on_card, 0.0, 1.0, T_CARD)
	if _chapter_row.visible:
		_tw.tween_property(_bar, "value", float(int(_c.get("step_no", 1))), T_TICK)
	if _has_hole:
		for i in 2:
			_tw.chain().tween_method(_on_pulse, 0.0, 1.0, T_PULSE)
			_tw.chain().tween_method(_on_pulse, 1.0, 0.0, T_PULSE)
	_tw.finished.connect(_on_anim_done)


## Instant geometry (a followed target, a resized viewport, no animation): everything lands on its final value.
func _relayout() -> void:
	var res := _compute()
	if res == "pending":
		_enter("settle")    # two quiet frames, then _reveal() lands on the final geometry
		_rect_prev = _rect
		return
	if res == "nofit" and not _fb:
		_enter_fallback()
		return
	_snap_apply()


func _snap_final() -> void:
	if _tw != null and _tw.is_valid():
		_kill_tw()
	if _vis and (_moving or card.modulate.a < 1.0 or _pulse != 0.0 or _nudge_dx != 0.0):
		_moving = false
		_move_t = 1.0
		_pulse = 0.0
		_nudge_dx = 0.0
		_card_dy = 0.0
		card.modulate.a = 1.0
		_dim_a = _kind_dim()
		_hole_vis = _hole
		_apply_all()


func _snap_apply() -> void:
	_moving = false
	_move_t = 1.0
	_pulse = 0.0
	_nudge_dx = 0.0
	_card_dy = 0.0
	card.modulate.a = 1.0
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim_a = _kind_dim()
	_hole_vis = _hole if _has_hole else Rect2()
	_apply_all()


func _apply_all() -> void:
	layout_count += 1
	_set_dim(_dim_a)
	_place_dims()
	_apply_card()
	card.visible = true
	_update_blocker()
	mark.on = _has_hole and not _fb
	mark.rect = _hole_vis
	mark.pulse = _pulse
	mark.ptr = _show_ptr and not _moving
	mark.ptr_dir = _ptr_dir
	mark.queue_redraw()


func _apply_card() -> void:
	card.position = _card_pos + Vector2(_nudge_dx, _card_dy)


func _set_dim(a: float) -> void:
	var col := Color(UI.BG, a)
	for d in dims:
		d.color = col


func _place_dims() -> void:
	var vp := _vp()
	var show_dims := _kind_dim() > 0.0
	for d in dims:
		d.visible = show_dims
	if not show_dims:
		return
	if not _has_hole:
		dims[0].position = Vector2.ZERO
		dims[0].size = vp
		for i in range(1, 4):
			dims[i].position = Vector2.ZERO
			dims[i].size = Vector2.ZERO
		return
	var h := _hole_vis
	dims[0].position = Vector2.ZERO
	dims[0].size = Vector2(vp.x, maxf(0.0, h.position.y))
	dims[1].position = Vector2(0.0, h.end.y)
	dims[1].size = Vector2(vp.x, maxf(0.0, vp.y - h.end.y))
	dims[2].position = Vector2(0.0, h.position.y)
	dims[2].size = Vector2(maxf(0.0, h.position.x), h.size.y)
	dims[3].position = Vector2(h.end.x, h.position.y)
	dims[3].size = Vector2(maxf(0.0, vp.x - h.end.x), h.size.y)


## An info step (and any moment the hole is moving, or the old hole is still drawn while the next target is found) puts a STOP
## blocker over the hole as drawn.
func _update_blocker() -> void:
	var hv := _hole_vis
	var want := _vis and _kind_dim() > 0.0 and hv.size.x > 0.0 and ((String(_c.get("kind", "")) == "info" and _has_hole) or _moving or mode == "wait")
	blocker.visible = want
	if want:
		blocker.position = hv.position
		blocker.size = hv.size


# ---- animation callbacks (one tween at a time) ---------------------------------------------------------------------------------

func _kill_tw() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null


func _on_dim(a: float) -> void:
	_dim_a = a
	_set_dim(a)


func _on_move(t: float) -> void:
	_move_t = t
	_hole_vis = Rect2(_from.position.lerp(_hole.position, t), _from.size.lerp(_hole.size, t))
	_place_dims()
	_update_blocker()
	mark.rect = _hole_vis
	mark.queue_redraw()


func _on_card(t: float) -> void:
	card.modulate.a = t
	_card_dy = 24.0 * (1.0 - t)
	_apply_card()


func _on_pulse(v: float) -> void:
	_pulse = v
	mark.pulse = v
	mark.queue_redraw()


func _on_nudge(v: float) -> void:
	_nudge_dx = v
	_apply_card()


func _on_anim_done() -> void:
	_tw = null
	_moving = false
	_hole_vis = _hole if _has_hole else Rect2()
	_pulse = 0.0
	_update_blocker()
	mark.ptr = _show_ptr
	mark.queue_redraw()


# ---- stray taps ----------------------------------------------------------------------------------------------------------------

func _on_dim_input(e: InputEvent) -> void:
	var what := _stray.feed(e)
	if what == "up" and _stray.travel() <= TouchTrack.SLOP:
		_on_stray()


func _on_stray() -> void:
	nudges += 1
	var now := float(Time.get_ticks_msec()) / 1000.0
	_stray_times.append(now)
	while not _stray_times.is_empty() and now - float(_stray_times[0]) > NUDGE_WINDOW_S:
		_stray_times.remove_at(0)
	if _stray_times.size() >= 2 and not _fb and not _nudge_lbl.visible:
		_nudge_lbl.text = UI.tidy(Strings.t("tut.nudge"))
		_nudge_lbl.visible = true
	if not UI.animate or not _vis or not is_inside_tree():
		return
	_snap_final()
	_kill_tw()
	_tw = create_tween().set_parallel(true)
	var dx := 10.0
	_tw.tween_method(_on_nudge, 0.0, dx, T_NUDGE * 0.25)
	_tw.chain().tween_method(_on_nudge, dx, -dx, T_NUDGE * 0.5)
	_tw.chain().tween_method(_on_nudge, -dx, 0.0, T_NUDGE * 0.25)
	if _has_hole:
		_tw.parallel().tween_method(_on_pulse, 0.0, 1.0, T_PULSE)
		_tw.chain().tween_method(_on_pulse, 1.0, 0.0, T_PULSE)
	if _stray_times.size() >= 4 and skip_button != null and is_instance_valid(skip_button):
		skip_button.pivot_offset = skip_button.size * 0.5
		_tw.chain().tween_property(skip_button, "scale", Vector2(1.06, 1.06), T_PULSE)
		_tw.chain().tween_property(skip_button, "scale", Vector2.ONE, T_PULSE)
	_tw.finished.connect(_on_anim_done)


func _on_viewport_changed() -> void:
	if mode == "shown" or mode == "fallback":
		_chapter_row.visible = not bool(_c.get("compact", false))
		_enter("settle")    # the card text wraps again: two quiet frames, then the geometry is rebuilt
		set_process(true)
		_rect_prev = Rect2(-1, -1, -1, -1)
