class_name DetentTrack
extends Control
## A big stepped slider with five detents (UI-PASS-2 5.11, build plan I-10): it replaces the "-- - 0 + ++" button row of the Game
## Plan. ONE Control, drawn in passes (shapes, icons, text), so seven of them on a page are seven nodes:
##   head     the control's name (Body 32) and the value as a WORD ("Balanced", "Push early") with two dots for a full step and one
##            for a half step, so the strength is a shape too (the thumb position and the filled part of the track say it a third way)
##   track    96 px high by the full width (the hit area); the track line 8 px, five detents, a notch at the centre, the thumb 56 px
##            with a notch of its own; the part between the centre and the thumb is filled
##   ends     the two short end words (Small 26), left = the negative end
##   effect   the live effect line (Small 26): what the current step does, from the existing gp.c.<id>.neg / pos / balanced strings;
##            the height reserves the longest of the three, so moving the thumb never moves the page
##   moves    "Moves: Early, Late" (Caption 24) with one pip per phase that the control moves (the per-control phase map of PhaseStrip)
## `value` is the plan value of the Game Plan (-100, -50, 0, 50, 100: GamePlan.STEPS); any number given is snapped to the nearest
## detent. `on_change(id, value)` and the `changed` signal fire when a TOUCH or a DRAG changes the value, once per detent crossed;
## set_value() from code changes the control the same way and fires neither (a screen that sets it would loop). So code and a drag
## end in the same state: value, word, effect line, cue, `applied` counted once per change.
## States: normal, set (value not 0), inert, disabled. INERT is the look for a control that does nothing in the plan on show
## (UI-PASS-2 7.6 finding 1): "full" = hollow thumb, no fill, a lock glyph beside the word and a reason line in place of the effect
## line, and it takes no input; "partial" = a note line under the effect line (the control still works, only part of it applies).
## Neither relies on colour: the lock, the hollow thumb and the words carry it. Disabled = dimmed, no lock.
## Touch (rule S1): only a press in the 96 px track band starts anything. After 12 px of finger travel the gesture is decided once:
## more sideways than vertical = a drag of the thumb (it follows the finger, the value snaps to the nearest detent, the events are
## swallowed), otherwise it is a page scroll and the track lets go (the event is not accepted). A release within 12 px is a tap: the
## nearest detent to the finger. A press outside the track band (the head, the end words, the lines) is not the track's.
## "Keyboard-free": there is no key handling; nudge(delta) steps one detent for a future screen-reader action.

signal changed(id: String, value: int)

const VALUES := [-100, -50, 0, 50, 100]
const HEAD_H := 44.0
const TRACK_H := 96.0
const ENDS_H := 34.0
const MOVES_H := 32.0
const BAR_H := 8.0
const THUMB := 56.0
const INSET := 28.0
const PAD_BOTTOM := 8.0
const SLOP := TouchTrack.SLOP
const IDLE := 0
const UNDECIDED := 1
const HORIZONTAL := 2
const VERTICAL := 3

var id := ""
var value := 0
var index := 2
var labels: Dictionary = {}
var inert := ""              # "", "partial" or "full"
var inert_text := ""         # the reason line of a full inert control; the note line of a partial one
var disabled := false
var on_change: Callable
var tut_id := ""
var applied := 0
var draw_count := 0
var clipped: Array = []
var decisions: Array = []    # "h" / "v" per gesture that reached the lock (tests read it)
var lock_state := IDLE
var _phases: Array = []
var _ops := CardKit.Ops.new()
var _tr := TouchTrack.new()
var _drag_x := -1.0          # the thumb follows the finger while dragging (-1 = on its detent)
var _pressed := false
var _lines_w := -1.0
var _eff_lines := 1
var _note_lines := 0
var _moved_idx := -1
var _cut: Array = []         # lines wrap() had to cut (a word wider than the control)


## The labels of a Game Plan control from the merged copy: gp.c.<id>.name / neg / pos / balanced (the effect lines and the word at
## balanced) and gp.end.<id>.neg / pos (the short end words). A screen may pass its own dictionary with the same keys:
## name, neg, pos, balanced, effect_neg, effect_pos, effect_balanced, and optionally half_neg, half_pos (the words for the
## half steps; without them the end word is used and the single dot says "half").
static func labels_for(control_id: String) -> Dictionary:
	return {
		"name": Strings.t("gp.c.%s.name" % control_id),
		"neg": Strings.t("gp.end.%s.neg" % control_id),
		"pos": Strings.t("gp.end.%s.pos" % control_id),
		"balanced": Strings.t("gp.c.%s.balanced" % control_id),
		"effect_neg": Strings.t("gp.c.%s.neg" % control_id),
		"effect_pos": Strings.t("gp.c.%s.pos" % control_id),
		"effect_balanced": Strings.t("gp.c.%s.balanced" % control_id),
	}


static func snap_index(v: float) -> int:
	var best := 0
	var bd := 1.0e9
	for i in VALUES.size():
		var d := absf(float(VALUES[i]) - v)
		if d < bd:
			bd = d
			best = i
	return best


func _init(p_id: String = "", p_value: int = 0, p_on_change: Callable = Callable(), p_labels: Dictionary = {}, p_tut_id: String = "") -> void:
	id = p_id
	on_change = p_on_change
	tut_id = p_tut_id
	labels = p_labels if not p_labels.is_empty() else labels_for(p_id)
	index = snap_index(float(p_value))
	value = int(VALUES[index])
	_phases = PhaseStrip.control_phases(p_id)
	mouse_filter = Control.MOUSE_FILTER_PASS    # a swipe that starts outside the track scrolls the page
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	CompKit.mark_stateful(self)
	CompKit.tag(self, tut_id)
	_relayout()
	_note_cue()
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility)


func _enter_tree() -> void:
	ArtWire.ensure()


func _exit_tree() -> void:
	_tr.reset()
	lock_state = IDLE


func _on_visibility() -> void:
	if not is_visible_in_tree():
		_cancel_gesture()


func _cancel_gesture() -> void:
	_tr.reset()
	lock_state = IDLE
	_drag_x = -1.0
	if _pressed:
		_pressed = false
	queue_redraw()


# ---- data in ----------------------------------------------------------------------------------------------------------------

## Sets the value from code: snapped to the nearest detent, clamped, an equal value does nothing, no callback.
func set_value(v: int) -> void:
	set_index(snap_index(float(v)))


func set_index(i: int) -> void:
	i = clampi(i, 0, VALUES.size() - 1)
	if i == index:
		return
	index = i
	value = int(VALUES[i])
	applied += 1
	_note_cue()
	queue_redraw()


func set_labels(d: Dictionary) -> void:
	if d == labels:
		return
	labels = d
	applied += 1
	_relayout()
	queue_redraw()


## `kind` "" (normal), "partial" (a note under the effect line) or "full" (inert: no input, hollow thumb, lock, reason line).
## `text` is the reason or the note; "" takes the copy keys gp.trigger_locked (full) and gp.trigger_late_only (partial).
func set_inert(kind: String, text: String = "") -> void:
	if not ["", "partial", "full"].has(kind):
		kind = ""
	if text == "" and kind == "full":
		text = Strings.t("gp.trigger_locked")
	elif text == "" and kind == "partial":
		text = Strings.t("gp.trigger_late_only")
	if kind == "":
		text = ""
	if kind == inert and text == inert_text:
		return
	inert = kind
	inert_text = text
	applied += 1
	if inert == "full":
		_cancel_gesture()
	_relayout()
	_note_cue()
	queue_redraw()


func set_disabled(v: bool) -> void:
	if v == disabled:
		return
	disabled = v
	applied += 1
	if disabled:
		_cancel_gesture()
	_note_cue()
	queue_redraw()


## The phases the control moves (the pips and the "Moves:" line). Default: the per-control phase map of the data.
func set_phases(p: Array) -> void:
	if p == _phases:
		return
	_phases = p.duplicate()
	applied += 1
	_relayout()
	queue_redraw()


func phases() -> Array:
	return _phases.duplicate()


func is_interactive() -> bool:
	return not disabled and inert != "full"


func state_name() -> String:
	if inert == "full":
		return "inert"
	if disabled:
		return "disabled"
	return "set" if value != 0 else ""


func _note_cue() -> void:
	var c := "word+thumb"
	if inert == "full":
		c = "lock+hollow+word"
	elif disabled:
		c = "dim+word"
	elif value != 0:
		c = "word+fill+thumb"
	CompKit.set_cue(self, c)


## One detent left or right (a future screen-reader action; not bound to any key). Fires the callback like a tap.
func nudge(delta: int) -> void:
	if not is_interactive():
		return
	_user_set(clampi(index + delta, 0, VALUES.size() - 1))


# ---- words ----------------------------------------------------------------------------------------------------------------------

func value_word() -> String:
	match index:
		0:
			return String(labels.get("neg", ""))
		1:
			return String(labels.get("half_neg", labels.get("neg", "")))
		3:
			return String(labels.get("half_pos", labels.get("pos", "")))
		4:
			return String(labels.get("pos", ""))
	return String(labels.get("balanced", ""))


func effect_text() -> String:
	match index:
		0, 1:
			return String(labels.get("effect_neg", ""))
		3, 4:
			return String(labels.get("effect_pos", ""))
	return String(labels.get("effect_balanced", ""))


## 0 at balanced, 1 for a half step, 2 for a full step: the dots after the word.
func strength() -> int:
	return absi(index - 2)


func moves_text() -> String:
	if _phases.is_empty():
		return ""
	return Strings.f("gp.pips", {"phases": ", ".join(PackedStringArray(PlanKit.phase_names(_phases)))})


# ---- geometry (this control's coordinates) ---------------------------------------------------------------------------------------

func _w() -> float:
	return size.x if size.x > 0.0 else maxf(custom_minimum_size.x, UI.canvas_w() - 48.0)


func track_rect() -> Rect2:
	return Rect2(0.0, HEAD_H, _w(), TRACK_H)


func global_track_rect() -> Rect2:
	var r := track_rect()
	var t := get_global_transform()
	return Rect2(t * r.position, r.size * t.get_scale())


func detent_x(i: int, w: float = -1.0) -> float:
	var ww := _w() if w < 0.0 else w
	return INSET + float(i) * (ww - INSET * 2.0) / float(VALUES.size() - 1)


func thumb_x() -> float:
	return detent_x(index) if _drag_x < 0.0 else clampf(_drag_x, INSET, _w() - INSET)


func thumb_center() -> Vector2:
	return Vector2(thumb_x(), HEAD_H + TRACK_H * 0.5)


## The detent nearest to an x in this control's coordinates.
func index_at_x(x: float) -> int:
	var best := 0
	var bd := 1.0e9
	for i in VALUES.size():
		var d := absf(detent_x(i) - x)
		if d < bd:
			bd = d
			best = i
	return best


func global_detent_pos(i: int) -> Vector2:
	return get_global_transform() * Vector2(detent_x(i), HEAD_H + TRACK_H * 0.5)


func _f_small() -> Font:
	return UI.font("Medium")


func _relayout() -> void:
	var w := _w()
	_lines_w = w
	var fs := _f_small()
	var most := 1
	for key in ["effect_neg", "effect_pos", "effect_balanced"]:
		most = maxi(most, PlanKit.wrap(fs, UI.S_SMALL, String(labels.get(key, "")), w).size())
	if inert == "full":
		most = maxi(most, PlanKit.wrap(fs, UI.S_SMALL, inert_text, w).size())
	_eff_lines = most
	_note_lines = PlanKit.wrap(fs, UI.S_SMALL, inert_text, w).size() if inert == "partial" else 0
	var lh := PlanKit.line_h(fs, UI.S_SMALL)
	var h := HEAD_H + TRACK_H + ENDS_H + lh * float(_eff_lines)
	if not _phases.is_empty():
		h += MOVES_H
	h += lh * float(_note_lines)
	h += PAD_BOTTOM
	if not is_equal_approx(custom_minimum_size.y, h):
		custom_minimum_size = Vector2(0.0, h)


func _on_resized() -> void:
	if not is_equal_approx(_lines_w, _w()):
		_relayout()
	queue_redraw()


# ---- drawing ------------------------------------------------------------------------------------------------------------------

func _layout() -> void:
	_ops.clear()
	_cut = []
	var w := _w()
	var fb := UI.font("SemiBold")
	var fs := _f_small()
	var lh := PlanKit.line_h(fs, UI.S_SMALL)
	var full := inert == "full"
	var off := full or disabled
	var name_col := UI.TEXT_OFF if off else UI.TEXT
	var word_col := UI.TEXT_OFF if off else UI.TEAL_HI
	# the head: name left, [lock] word and strength dots right
	var word := value_word()
	var ww := CardKit.text_w(fb, UI.S_BODY, word)
	var dots := strength()
	var dots_w := (float(dots) * 10.0 + float(maxi(0, dots - 1)) * 6.0 + 10.0) if dots > 0 else 0.0
	var lock_w := 32.0 if full else 0.0
	var group_w := lock_w + ww + dots_w
	var cy_head := HEAD_H * 0.5
	var name_room := maxf(40.0, w - group_w - 24.0)
	_ops.text(fb, UI.S_BODY, String(labels.get("name", "")), 0.0, cy_head, name_room, name_col, 0)
	var gx := w - group_w
	if full:
		_ops.icon("lock", Rect2(gx, cy_head - 14.0, 28.0, 28.0), UI.TEXT2)
	_ops.text(fb, UI.S_BODY, word, gx + lock_w, cy_head, ww + 2.0, word_col, 0)
	for k in dots:
		_ops.shape("disc", Rect2(w - float(dots) * 16.0 + 6.0 + float(k) * 16.0, cy_head - 5.0, 10.0, 10.0), UI.TEXT_OFF if off else UI.TEAL_HI)
	# the track
	var cy := HEAD_H + TRACK_H * 0.5
	var xl := detent_x(0, w)
	var xr := detent_x(VALUES.size() - 1, w)
	var track_col := Color(UI.TEXT_OFF.r, UI.TEXT_OFF.g, UI.TEXT_OFF.b, 0.45) if off else Color(UI.DIM.r, UI.DIM.g, UI.DIM.b, 0.38)
	_ops.shape("solid", Rect2(xl, cy - BAR_H * 0.5, xr - xl, BAR_H), track_col)
	_ops.shape("disc", Rect2(xl - BAR_H * 0.5, cy - BAR_H * 0.5, BAR_H, BAR_H), track_col)
	_ops.shape("disc", Rect2(xr - BAR_H * 0.5, cy - BAR_H * 0.5, BAR_H, BAR_H), track_col)
	var tx := thumb_x()
	var mid := detent_x(2, w)
	if not off and absf(tx - mid) >= 1.0:
		_ops.shape("solid", Rect2(minf(tx, mid), cy - BAR_H * 0.5, absf(tx - mid), BAR_H), UI.ACCENT)
	for i in VALUES.size():
		var dx := detent_x(i, w)
		if i == 2:
			_ops.shape("solid", Rect2(dx - 2.0, cy - 14.0, 4.0, 28.0), UI.TEXT_OFF if off else UI.TEXT)
			continue
		var between := (dx >= minf(tx, mid) - 1.0 and dx <= maxf(tx, mid) + 1.0) and not off
		_ops.shape("disc", Rect2(dx - 7.0, cy - 7.0, 14.0, 14.0), UI.TEAL_HI if between else (UI.TEXT_OFF if off else UI.DIM))
	# the thumb
	if _pressed and not off:
		_ops.shape("disc", Rect2(tx - 34.0, cy - 34.0, 68.0, 68.0), Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.28))
	if full:
		_ops.shape("disc", Rect2(tx - 28.0, cy - 28.0, 56.0, 56.0), UI.TEXT_OFF)
		_ops.shape("disc", Rect2(tx - 22.0, cy - 22.0, 44.0, 44.0), UI.PANEL)
	elif disabled:
		_ops.shape("disc", Rect2(tx - 28.0, cy - 28.0, 56.0, 56.0), UI.TEXT_OFF)
		_ops.shape("disc", Rect2(tx - 24.0, cy - 24.0, 48.0, 48.0), UI.PANEL3)
		_ops.shape("solid", Rect2(tx - 2.0, cy - 9.0, 4.0, 18.0), UI.TEXT_OFF)
	else:
		_ops.shape("disc", Rect2(tx - 28.0, cy - 28.0, 56.0, 56.0), UI.TEAL_HI)
		_ops.shape("disc", Rect2(tx - 24.0, cy - 24.0, 48.0, 48.0), UI.ACCENT)
		_ops.shape("solid", Rect2(tx - 2.0, cy - 9.0, 4.0, 18.0), UI.INK_TEAL)
	# the end words
	var y := HEAD_H + TRACK_H
	var end_col := UI.TEXT_OFF if off else UI.DIM
	var half := w * 0.5 - 8.0
	_ops.text(fs, UI.S_SMALL, String(labels.get("neg", "")), 0.0, y + ENDS_H * 0.5, half, end_col, 0)
	_ops.text(fs, UI.S_SMALL, String(labels.get("pos", "")), w - half, y + ENDS_H * 0.5, half, end_col, 2)
	y += ENDS_H
	# the effect line (or the reason, when inert)
	var eff := inert_text if full else effect_text()
	var eff_col := UI.TEXT_OFF if off else UI.TEXT2
	var lines := PlanKit.wrap(fs, UI.S_SMALL, eff, w)
	if PlanKit.was_cut(lines, eff):
		_cut.append(eff)
	for k in lines.size():
		_ops.text(fs, UI.S_SMALL, String(lines[k]), 0.0, y + lh * (float(k) + 0.5), w, eff_col, 0)
	y += lh * float(_eff_lines)
	# the phases it moves
	if not _phases.is_empty():
		var cy2 := y + MOVES_H * 0.5
		var px := 0.0
		for p in PhaseStrip.PHASES:
			var acts := _phases.has(p)
			_ops.shape("disc", Rect2(px, cy2 - 6.0, 12.0, 12.0), (UI.TEXT_OFF if off else UI.TEAL_HI) if acts else Color(UI.DIM.r, UI.DIM.g, UI.DIM.b, 0.35))
			px += 18.0
		_ops.text(fb, UI.S_CAPTION, moves_text(), px + 8.0, cy2, maxf(40.0, w - px - 8.0), UI.TEXT_OFF if off else UI.DIM, 0)
		y += MOVES_H
	# the partial note
	if inert == "partial":
		var nl := PlanKit.wrap(fs, UI.S_SMALL, inert_text, w - 36.0)
		if PlanKit.was_cut(nl, inert_text):
			_cut.append(inert_text)
		_ops.icon("warn", Rect2(0.0, y + lh * 0.5 - 12.0, 24.0, 24.0), UI.WARN)
		for k in nl.size():
			_ops.text(fs, UI.S_SMALL, String(nl[k]), 36.0, y + lh * (float(k) + 0.5), w - 36.0, UI.TEXT2, 0)


func _draw() -> void:
	draw_count += 1
	_layout()
	_ops.flush(self)
	clipped = _ops.clipped.duplicate()
	clipped.append_array(_cut)


# ---- touch ------------------------------------------------------------------------------------------------------------------

func _global_of(local: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local


func _gui_input(event: InputEvent) -> void:
	var what := _tr.feed(event)
	match what:
		"down":
			lock_state = IDLE
			if not is_interactive() or not track_rect().has_point(_tr.press_pos):
				return    # not ours (the head, the lines, an inert control): the lock stays IDLE and nothing below reacts
			lock_state = UNDECIDED
			_moved_idx = -1
			_pressed = true
			queue_redraw()
			# not accepted: the page behind may note the press
		"dup_motion":
			if lock_state == UNDECIDED or lock_state == HORIZONTAL:
				accept_event()    # the mouse motion a phone emulates from this drag must not scroll the page
		"move":
			_on_move()
		"up":
			_on_up()


func _on_move() -> void:
	match lock_state:
		UNDECIDED:
			var d := _tr.pos - _tr.press_pos
			if d.length() > SLOP:
				if absf(d.x) > absf(d.y):
					lock_state = HORIZONTAL
					decisions.append("h")
					_drag_to(_tr.pos.x)
				else:
					lock_state = VERTICAL
					decisions.append("v")
					_pressed = false
					queue_redraw()
			accept_event()    # undecided: swallow, the page does not twitch
		HORIZONTAL:
			_drag_to(_tr.pos.x)
			accept_event()
		# VERTICAL: not accepted, the parent ScrollContainer gets the drag and scrolls the page


func _drag_to(x: float) -> void:
	_drag_x = x
	var i := index_at_x(clampf(x, INSET, _w() - INSET))
	if i != index:
		_user_set(i)
	queue_redraw()


func _on_up() -> void:
	var st := lock_state
	lock_state = IDLE
	_pressed = false
	_drag_x = -1.0
	if st == UNDECIDED:
		if _global_of(_tr.pos).distance_to(_global_of(_tr.press_pos)) <= SLOP:
			_user_set(index_at_x(_tr.press_pos.x))
			CompKit.tap_event(tut_id)
	elif st == HORIZONTAL:
		CompKit.tap_event(tut_id)
	queue_redraw()


## A change by the player: the same state as set_index, plus the callback and the signal.
func _user_set(i: int) -> void:
	if i == index:
		return
	set_index(i)
	changed.emit(id, value)
	if on_change.is_valid():
		on_change.call(id, value)
