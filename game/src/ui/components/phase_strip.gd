class_name PhaseStrip
extends Control
## The phase strip (UI-PASS-2 5.12, build plan I-10): the nodes of the Game Plan timeline (Overall, Early, Mid, Late) joined by a
## line, or, in the vertical form, the three nodes (Early, Mid, Late) down the left edge of the Report story. ONE Control, drawn
## in passes (shapes, icons, text), so it costs a handful of draw calls whatever the node count.
## A phase is a Dictionary {id, label, caption, locked, result, controls} or just its id (then the label is Strings
## gp.phase.<id> and `controls` is the list the phase map gives):
##   id        "overall", "early", "mid", "late" (any id works; the label then has to be given)
##   label     26 px under the node (SemiBold)
##   caption   24 px under the label ("lead 2/4"); "" for none (horizontal form only)
##   locked    a lock glyph on the node and the dimmed look: the phase does nothing in this plan (it stays tappable, so the page
##             can say why; UI-PASS-2 6.4 "the Early node is locked")
##   result    "win" a tick, "lose" a cross (a shape and a glyph, never a tint alone), "" none
##   controls  control ids that act in this phase: one pip each under the caption (horizontal form only)
## Selected = a filled accent node with a ring. Tap a node (the whole quarter of the width, 96+ px high; in the vertical form the
## whole row of 112 px): `on_select(id)` and the `phase_selected` signal fire once per change; set_selected() from code fires
## neither. Touch follows the S1 rule (12 px slop measured on the screen, the event is never accepted, so a swipe that starts on
## the strip scrolls the page and selects nothing). Built once; every setter ignores an equal value.
##
## The PER-CONTROL PHASE MAP is derived from data/game_plan_v0.json at first use (GamePlan.data(): `controls.<id>.mod` and `.var`
## name the contests a control moves, and every contest belongs to Early (GamePlan.EARLY), Mid (`*_mid`) or Late (`*_late`);
## Jungle focus is read from `jungle_focus`). Statics: control_phases(id), acts_in(id, phase), controls_in(phase), effect_kind(id, active).

signal phase_selected(id: String)

const ALL := ["overall", "early", "mid", "late"]
const PHASES := ["early", "mid", "late"]
const CONTROL_IDS := ["g", "t", "m", "l", "a", "s", "r", "jf"]
const H_HORIZONTAL := 136.0
const ROW_H := 112.0
const NODE := 56.0
const CAP_LH := 28.0
const SLOP := TouchTrack.SLOP

static var _map: Dictionary = {}

var phases: Array = []
var selected_id := ""
var vertical := false
var on_select: Callable
var tut_id := ""
var applied := 0
var draw_count := 0
var clipped: Array = []
var _ops := CardKit.Ops.new()
var _tr := TouchTrack.new()
var _press_g := Vector2.ZERO
var _press_i := -1
var _moved := false
var _pressed_i := -1


# ---- the phase map (data -> phases) ---------------------------------------------------------------------------------------

## The phase a contest belongs to: "early" for the four lane contests, "mid" and "late" by the suffix of the other four.
static func phase_of_contest(contest: String) -> String:
	if GamePlan.EARLY.has(contest):
		return "early"
	if contest.ends_with("_mid"):
		return "mid"
	return "late"


## control id -> the phases it moves (in the order early, mid, late). Rebuilt only after reset_map().
static func phase_map() -> Dictionary:
	if _map.is_empty():
		var data: Dictionary = GamePlan.data()
		var controls: Dictionary = data.get("controls", {})
		for id in GamePlan.SLIDERS:
			var seen := {}
			var spec: Dictionary = controls.get(id, {})
			for kind in ["mod", "var"]:
				var m: Dictionary = spec.get(kind, {})
				for contest in m:
					if absf(float(m[contest])) > 0.0:
						seen[phase_of_contest(String(contest))] = true
			_map[id] = PHASES.filter(func(p: String) -> bool: return seen.has(p))
		var jf: Dictionary = data.get("jungle_focus", {})
		var jseen := {}
		if jf.has("jungle"):
			jseen[phase_of_contest("jungle")] = true
		if jf.has("chosen"):
			for lane in GamePlan.JUNGLE_CHOICES:    # the chosen lane is one of top, mid_lane, bot
				if lane != "none":
					jseen[phase_of_contest(String(lane))] = true
		_map["jf"] = PHASES.filter(func(p: String) -> bool: return jseen.has(p))
	return _map


static func reset_map() -> void:
	_map.clear()


static func control_phases(id: String) -> Array:
	return (phase_map().get(id, []) as Array).duplicate()


## True when the control moves that phase ("overall" is every phase, so every control acts in it).
static func acts_in(id: String, phase: String) -> bool:
	if phase == "overall":
		return true
	return (phase_map().get(id, []) as Array).has(phase)


## The control ids that act in a phase, in the order g t m l a s r jf. "overall" = the ones that act in every phase.
static func controls_in(phase: String) -> Array:
	var out: Array = []
	for id in CONTROL_IDS:
		var ph: Array = phase_map().get(id, [])
		if phase == "overall":
			if ph.size() == PHASES.size():
				out.append(id)
		elif ph.has(phase):
			out.append(id)
	return out


## What a plan that only uses the phases in `active` does with a control: "full" when every phase it moves is active, "partial" when
## only some are, "none" when none is. A trigger plan uses ["mid", "late"] (UI-PASS-2 7.6 finding 1); the Default plan all three.
static func effect_kind(id: String, active: Array) -> String:
	var ph: Array = phase_map().get(id, [])
	var hit := 0
	for p in ph:
		if active.has(p):
			hit += 1
	if hit == 0:
		return "none"
	return "full" if hit == ph.size() else "partial"


## The four default phases (Overall, Early, Mid, Late) with their pips from the map.
static func default_phases() -> Array:
	return ALL.duplicate()


# ---- build ------------------------------------------------------------------------------------------------------------------

func _init(p_phases: Array = [], p_selected: String = "", p_on_select: Callable = Callable(), p_vertical: bool = false, p_tut_id: String = "") -> void:
	vertical = p_vertical
	on_select = p_on_select
	tut_id = p_tut_id
	selected_id = p_selected
	mouse_filter = Control.MOUSE_FILTER_PASS    # the page behind still gets the drags (the strip takes none)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL if not vertical else Control.SIZE_SHRINK_BEGIN
	focus_mode = Control.FOCUS_NONE
	for p in (p_phases if not p_phases.is_empty() else default_phases()):
		phases.append(_norm(p))
	_apply_size()
	CompKit.mark_stateful(self)
	CompKit.tag(self, tut_id)
	_note_cue()
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility)


func _on_resized() -> void:
	_apply_size()
	queue_redraw()


func _exit_tree() -> void:
	_tr.reset()


func _on_visibility() -> void:
	if not is_visible_in_tree():
		_tr.reset()
		_set_pressed(-1)


static func _norm(p: Variant) -> Dictionary:
	var d: Dictionary = {}
	if p is Dictionary:
		d = (p as Dictionary).duplicate()
	else:
		d = {"id": str(p)}
	var id := String(d.get("id", ""))
	d["id"] = id
	if not d.has("label"):
		d["label"] = PlanKit.name_of_phase(id)
	d["caption"] = String(d.get("caption", ""))
	d["locked"] = bool(d.get("locked", false))
	d["result"] = String(d.get("result", "")) if ["", "win", "lose"].has(String(d.get("result", ""))) else ""
	if not d.has("controls"):
		d["controls"] = controls_in(id) if ALL.has(id) else []
	return d


func _label_w() -> float:
	var w := 0.0
	var f := UI.font("SemiBold")
	for p in phases:
		w = maxf(w, CardKit.text_w(f, UI.S_SMALL, String(p["label"])))
	return w


## The lines the longest caption needs in a node's width (0 when there is none; a caption wraps to two lines at most).
func caption_lines() -> int:
	var most := 0
	var room := _w() / float(maxi(1, phases.size())) - 8.0
	for p in phases:
		var cap := String(p["caption"])
		if cap != "":
			most = maxi(most, PlanKit.wrap(UI.font("SemiBold"), UI.S_CAPTION, cap, room, 2).size())
	return most


func strip_h() -> float:
	return H_HORIZONTAL + CAP_LH * float(maxi(0, caption_lines() - 1))


func _apply_size() -> void:
	if vertical:
		custom_minimum_size = Vector2(ceilf(NODE + 12.0 + _label_w()) + 4.0, ROW_H * float(phases.size()))
	else:
		var h := strip_h()
		if not is_equal_approx(custom_minimum_size.y, h):
			custom_minimum_size = Vector2(0.0, h)


# ---- data in ---------------------------------------------------------------------------------------------------------------

func index_of(id: String) -> int:
	for i in phases.size():
		if phases[i]["id"] == id:
			return i
	return -1


func phase(id: String) -> Dictionary:
	var i := index_of(id)
	return phases[i] if i >= 0 else {}


func set_selected(id: String) -> void:
	if id == selected_id:
		return
	selected_id = id
	applied += 1
	_note_cue()
	queue_redraw()


func _set_field(id: String, key: String, v: Variant) -> void:
	var i := index_of(id)
	if i < 0 or phases[i][key] == v:
		return
	phases[i][key] = v
	applied += 1
	_note_cue()
	if key == "label" or key == "caption":
		_apply_size()
	queue_redraw()


func set_caption(id: String, text: String) -> void:
	_set_field(id, "caption", text)


func set_locked(id: String, v: bool) -> void:
	_set_field(id, "locked", v)


func set_result(id: String, v: String) -> void:
	if ["", "win", "lose"].has(v):
		_set_field(id, "result", v)


func set_controls(id: String, ids: Array) -> void:
	_set_field(id, "controls", ids.duplicate())


func set_label(id: String, text: String) -> void:
	_set_field(id, "label", text)


func state_name() -> String:
	return "selected" if index_of(selected_id) >= 0 else ""


func cue_for(id: String) -> String:
	var p := phase(id)
	if p.is_empty():
		return ""
	var parts: Array = []
	if id == selected_id:
		parts.append("fill+ring")
	if p["locked"]:
		parts.append("lock")
	if p["result"] == "win":
		parts.append("tick")
	elif p["result"] == "lose":
		parts.append("cross")
	return "+".join(PackedStringArray(parts))


func _note_cue() -> void:
	var parts: Array = []
	for p in phases:
		var c := cue_for(String(p["id"]))
		if c != "" and not parts.has(c):
			parts.append(c)
	CompKit.set_cue(self, ",".join(PackedStringArray(parts)))


# ---- geometry (this control's coordinates) --------------------------------------------------------------------------------------

func _w() -> float:
	return size.x if size.x > 0.0 else maxf(custom_minimum_size.x, UI.canvas_w() - 48.0)


## The tap area of one phase (a quarter of the width by the whole height; in the vertical form the row).
func cell_rect(i: int) -> Rect2:
	var n := maxi(1, phases.size())
	if vertical:
		return Rect2(0.0, float(i) * ROW_H, _w(), ROW_H)
	var cw := _w() / float(n)
	return Rect2(float(i) * cw, 0.0, cw, strip_h())


func node_center(i: int) -> Vector2:
	var c := cell_rect(i)
	if vertical:
		return Vector2(NODE * 0.5, c.position.y + 36.0)
	return Vector2(c.position.x + c.size.x * 0.5, 32.0)


func global_cell_rect(i: int) -> Rect2:
	var r := cell_rect(i)
	var t := get_global_transform()
	return Rect2(t * r.position, r.size * t.get_scale())


func index_at(p: Vector2) -> int:
	for i in phases.size():
		if cell_rect(i).has_point(p):
			return i
	return -1


# ---- drawing ------------------------------------------------------------------------------------------------------------------

func _fill_count(id: String) -> int:
	match id:
		"early":
			return 1
		"mid":
			return 2
		"late":
			return 3
	return 0


func _layout() -> void:
	_ops.clear()
	var n := phases.size()
	if n == 0:
		return
	var f26 := UI.font("SemiBold")
	var dim := Color(UI.DIM.r, UI.DIM.g, UI.DIM.b, 0.45)
	# the line that joins the nodes (behind them)
	var c0 := node_center(0)
	var c1 := node_center(n - 1)
	if n > 1:
		if vertical:
			for i in n - 1:
				var a := node_center(i)
				var b := node_center(i + 1)
				_ops.shape("solid", Rect2(a.x - 2.0, a.y + NODE * 0.5 - 2.0, 4.0, b.y - a.y - NODE + 4.0), dim)
		else:
			_ops.shape("solid", Rect2(c0.x, c0.y - 2.0, c1.x - c0.x, 4.0), dim)
	for i in n:
		var p: Dictionary = phases[i]
		var id := String(p["id"])
		var c := node_center(i)
		var sel := id == selected_id
		var locked := bool(p["locked"])
		var pressed := i == _pressed_i
		var ink := UI.INK_TEAL if sel else (UI.TEXT_OFF if locked else UI.TEXT)
		# the node: rim, body
		if sel:
			_ops.shape("disc", Rect2(c - Vector2(30, 30), Vector2(60, 60)), UI.TEAL_HI)
			_ops.shape("disc", Rect2(c - Vector2(25, 25), Vector2(50, 50)), UI.ACCENT.lightened(0.12) if pressed else UI.ACCENT)
		else:
			_ops.shape("disc", Rect2(c - Vector2(28, 28), Vector2(56, 56)), Color(UI.DIM.r, UI.DIM.g, UI.DIM.b, 0.55 if not locked else 0.3))
			_ops.shape("disc", Rect2(c - Vector2(25, 25), Vector2(50, 50)), UI.PANEL3 if pressed else UI.PANEL2)
		# the glyph: rising bars for early, mid, late; a clock for the whole game
		var fill := _fill_count(id)
		if fill > 0:
			for k in 3:
				var h := 12.0 + 8.0 * float(k)
				var col := ink if k < fill else Color(ink.r, ink.g, ink.b, 0.3)
				_ops.shape("solid", Rect2(c.x - 15.5 + float(k) * 12.0, c.y + 14.0 - h, 7.0, h), col)
		else:
			_ops.icon("clock", Rect2(c - Vector2(16, 16), Vector2(32, 32)), ink)
		# a lock on the top right, a tick or a cross on the bottom right (small dark disc under each)
		if locked:
			_ops.shape("disc", Rect2(c + Vector2(10, -34), Vector2(28, 28)), UI.VOID)
			_ops.icon("lock", Rect2(c + Vector2(13, -31), Vector2(22, 22)), UI.TEXT2)
		var res := String(p["result"])
		if res != "":
			_ops.shape("disc", Rect2(c + Vector2(10, 8), Vector2(30, 30)), UI.VOID)
			_ops.icon("tick" if res == "win" else "cross", Rect2(c + Vector2(13, 11), Vector2(24, 24)), UI.GOOD if res == "win" else UI.BAD)
		var lab_col := UI.TEXT if sel else (UI.TEXT_OFF if locked else UI.TEXT2)
		if vertical:
			_ops.text(f26, UI.S_SMALL, String(p["label"]), NODE + 12.0, c.y, maxf(10.0, size.x - NODE - 12.0), lab_col, 0)
			continue
		var cell := cell_rect(i)
		var room := cell.size.x - 8.0
		_ops.text(f26, UI.S_SMALL, String(p["label"]), cell.position.x + 4.0, 80.0, room, lab_col, 1)
		var cap := String(p["caption"])
		if cap != "":
			var cl := PlanKit.wrap(f26, UI.S_CAPTION, cap, room, 2)
			for k in cl.size():
				_ops.text(f26, UI.S_CAPTION, String(cl[k]), cell.position.x + 4.0, 106.0 + CAP_LH * float(k), room, UI.DIM if not locked else UI.TEXT_OFF, 1)
		# pips: one per control that acts in this phase
		var ctl: Array = p["controls"]
		if not ctl.is_empty():
			var count := mini(ctl.size(), 8)
			var total := float(count) * 10.0 + float(count - 1) * 6.0
			for k in count:
				_ops.shape("disc", Rect2(c.x - total * 0.5 + float(k) * 16.0, 121.0 + CAP_LH * float(maxi(0, caption_lines() - 1)), 10.0, 10.0), UI.TEAL_HI if sel else UI.DIM)


func _draw() -> void:
	draw_count += 1
	_layout()
	_ops.flush(self)
	clipped = _ops.clipped.duplicate()


func _enter_tree() -> void:
	ArtWire.ensure()


# ---- touch: a tap selects, a swipe scrolls the page ---------------------------------------------------------------------------

func _global_of(local: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local


func _gui_input(event: InputEvent) -> void:
	var what := _tr.feed(event)
	match what:
		"down":
			_press_g = _global_of(_tr.press_pos)
			_moved = false
			_press_i = index_at(_tr.press_pos)
			_set_pressed(_press_i)
			# not accepted: the page behind the strip scrolls from the drag
		"move":
			if not _moved and _global_of(_tr.pos).distance_to(_press_g) > SLOP:
				_moved = true
				_set_pressed(-1)
		"up":
			var g := _global_of(_tr.pos)
			var tap := _press_i >= 0 and not _moved and g.distance_to(_press_g) <= SLOP
			var i := _press_i
			_press_i = -1
			_set_pressed(-1)
			if tap:
				_tapped(i)


func _set_pressed(i: int) -> void:
	if i == _pressed_i:
		return
	_pressed_i = i
	queue_redraw()


func _tapped(i: int) -> void:
	if i < 0 or i >= phases.size():
		return
	var id := String(phases[i]["id"])
	if id == selected_id:
		return
	set_selected(id)
	if tut_id != "":
		CompKit.tap_event("%s.%s" % [tut_id, id])
	phase_selected.emit(id)
	if on_select.is_valid():
		on_select.call(id)
