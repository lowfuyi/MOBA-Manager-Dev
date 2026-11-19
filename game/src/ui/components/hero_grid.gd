class_name HeroGrid
extends Control
## The hero grid of the Draft (build plan I-09, SPIKE-RESULTS-0.7 S4 design C): ONE Control that draws all 40 cards itself,
## pass by pass across every card (HeroCard.PASSES: backgrounds, portraits, marks, the 26 px text, the 24 px text), so the
## whole grid is 1 node and a handful of draw calls (the plan's ceiling is 15; one Control per card was 107). It OWNS
## hit-testing by the S1 rule: a release more than 12 px of finger travel from the press is a drag, not a tap, measured in
## screen space (the grid sits in a scrolling page and moves under the finger, so a position in its own coordinates would
## understate a scroll). A swipe that starts on a card scrolls the page and taps nothing.
## Costs of design C, accepted by the Producer log of 2026-11-10: no node per card (so no per-card focus; `cue_for(hero_id)`
## is what the colour-blind audit and the tests read), one redraw repaints all cards, off-screen cards share the canvas item.
##
## Data in, one redraw out: set_heroes(rows) / set_state(hero_id, state) / set_states(dict) / set_filter(role) /
## set_selected(hero_id) each ignore an equal value (`applied` and `draw_count` do not move) and end in one queue_redraw.
## `state` is a name or a dictionary, see HeroCard. A filter keeps the heroes who play the role as primary or secondary.
## Columns are 3; the card width follows the room the grid has now ((width - 2 gaps) / 3, 216 at 672 and 184 at 578), the
## minimum height follows the filtered row count. Names are cut with "..." if they ever do not fit, never wrapped.
## Signals: hero_tapped(hero_id) (also tap:<tut_id>.<hero_id> on the bus when tut_id is set; the grid itself is tagged tut_id).

signal hero_tapped(hero_id: String)

const COLS := 3
const GAP := 12.0
const SLOP := TouchTrack.SLOP

var heroes: Array = []            # prepared hero entries (HeroCard.prepare), in the order given
var filter := ""
var tut_id := ""
var applied := 0
var draw_count := 0
var _states: Array = []           # per hero: the normalised state dictionary
var _shown: Array = []            # indexes of the heroes the filter lets through, in order
var _index: Dictionary = {}       # hero id -> index in heroes
var _tr := TouchTrack.new()
var _press_slot := -1
var _press_g := Vector2.ZERO
var _last_g := Vector2.ZERO
var _moved := false
var _pressed_idx := -1            # hero index drawn pressed
var _last_cw := 0.0
var _has_cues := false
var _clip: ScrollContainer = null    # the scroll area the grid sits in (only its visible window is drawn)
var _last_window := Rect2()


func _init(p_tut_id: String = "") -> void:
	tut_id = p_tut_id
	mouse_filter = Control.MOUSE_FILTER_PASS    # the page behind still gets the drags the grid does not take (it takes none)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	CompKit.mark_stateful(self)
	CompKit.tag(self, tut_id)
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility)
	set_notify_transform(true)    # 0.9.3c: the grid moved on its page (something above it grew): the visible window moved too
	_relayout()


func _enter_tree() -> void:
	ArtWire.ensure()
	_clip = null
	var p := get_parent()
	while p != null:
		if p is ScrollContainer:
			_clip = p as ScrollContainer
			break
		p = p.get_parent()
	if _clip != null:
		var cb := Callable(self, "_on_clip_scrolled")
		if not _clip.get_v_scroll_bar().value_changed.is_connected(cb):
			_clip.get_v_scroll_bar().value_changed.connect(cb)
		var rc := Callable(self, "_on_clip_resized")
		if not _clip.resized.is_connected(rc):
			_clip.resized.connect(rc)


func _exit_tree() -> void:
	_tr.reset()
	if _clip != null and is_instance_valid(_clip):
		var cb := Callable(self, "_on_clip_scrolled")
		if _clip.get_v_scroll_bar().value_changed.is_connected(cb):
			_clip.get_v_scroll_bar().value_changed.disconnect(cb)
		var rc := Callable(self, "_on_clip_resized")
		if _clip.resized.is_connected(rc):
			_clip.resized.disconnect(rc)
	_clip = null


## The grid sits in a scroll area: only the cards in its visible window (plus one row each way) are drawn, so 40 cards do not
## cost 40 cards of canvas commands (PERF-BUDGET canvas limit; I-16). A scroll redraws, a still grid does not.
func _on_clip_scrolled(_v: float) -> void:
	var w := _window()
	if w != _last_window:
		queue_redraw()


## 0.9.3c: the window also moves when the grid moves on its page or the scroll area changes height (no scroll, no width change):
## before, the rows that came into view stayed blank until the next scroll.
func _on_clip_resized() -> void:
	_on_clip_scrolled(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():
		_on_clip_scrolled(0.0)


## The part of the grid that can be seen, in the grid's own coordinates (the whole grid when it is not in a scroll area).
func _window() -> Rect2:
	var whole := Rect2(Vector2.ZERO, size)
	if _clip == null or not is_instance_valid(_clip) or not _clip.is_inside_tree():
		return whole
	var inv := get_global_transform().affine_inverse()
	var cr := _clip.get_global_rect()
	var a := inv * cr.position
	var b := inv * cr.end
	var row := HeroCard.H + GAP
	return Rect2(Vector2(0.0, a.y - row), Vector2(size.x, (b.y - a.y) + row * 2.0)).intersection(whole)


func _on_visibility() -> void:
	if not is_visible_in_tree():
		_tr.reset()
		_set_pressed(-1)


# ---- data ------------------------------------------------------------------------------------------------------------------

## The heroes (heroes.json rows, or any dictionary with id and name and role_primary). An equal list changes nothing.
func set_heroes(rows: Array) -> void:
	var ids: Array = []
	for r in rows:
		ids.append(str((r as Dictionary)["id"]))
	var have: Array = []
	for h in heroes:
		have.append(h["id"])
	if ids == have:
		return
	var old_states: Dictionary = {}
	for i in heroes.size():
		old_states[heroes[i]["id"]] = _states[i]
	heroes.clear()
	_states.clear()
	_index.clear()
	for r in rows:
		var h := HeroCard.prepare(r)
		_index[h["id"]] = heroes.size()
		heroes.append(h)
		_states.append(old_states.get(h["id"], HeroCard.norm_state("available")))
	applied += 1
	_refilter(true)


func hero_count() -> int:
	return heroes.size()


func shown_ids() -> Array:
	var out: Array = []
	for i in _shown:
		out.append(heroes[i]["id"])
	return out


func shown_count() -> int:
	return _shown.size()


func has_hero(hero_id: String) -> bool:
	return _index.has(hero_id)


func set_filter(role: String) -> void:
	if role == filter:
		return
	filter = role
	applied += 1
	_refilter(false)


func _refilter(force: bool) -> void:
	var n: Array = []
	for i in heroes.size():
		var h: Dictionary = heroes[i]
		if filter == "" or h["role"] == filter or h["role2"] == filter:
			n.append(i)
	if n == _shown and not force:
		return
	_shown = n
	_press_slot = -1
	_pressed_idx = -1
	_relayout()
	_note_cue()
	queue_redraw()


func state_of(hero_id: String) -> Dictionary:
	return _states[_index[hero_id]] if _index.has(hero_id) else HeroCard.norm_state("available")


func state_name_of(hero_id: String) -> String:
	return String(state_of(hero_id)["s"])


## One hero's state: a name ("banned") or a dictionary. An equal state changes nothing.
func set_state(hero_id: String, state: Variant) -> void:
	if _apply_state(hero_id, state):
		applied += 1
		_note_cue()
		queue_redraw()


## Many at once (one redraw). `states` maps hero id -> state; a hero not named keeps its state.
func set_states(states: Dictionary) -> void:
	var changed := false
	for k in states:
		if _apply_state(str(k), states[k]):
			changed = true
	if changed:
		applied += 1
		_note_cue()
		queue_redraw()


func _apply_state(hero_id: String, state: Variant) -> bool:
	if not _index.has(hero_id):
		return false
	var i: int = _index[hero_id]
	var n := HeroCard.norm_state(state)
	n["pressed"] = false
	var o: Dictionary = (_states[i] as Dictionary).duplicate()
	o["pressed"] = false
	if o == n:
		return false
	_states[i] = n
	return true


## The one selected hero (the others go back to available unless banned or picked). "" clears the selection.
func set_selected(hero_id: String) -> void:
	var changes: Dictionary = {}
	for i in heroes.size():
		var id: String = heroes[i]["id"]
		var d: Dictionary = (_states[i] as Dictionary).duplicate()
		var s := String(d["s"])
		if id == hero_id and (s == "available" or s == "selected"):
			d["s"] = "selected"
			changes[id] = d
		elif s == "selected":
			d["s"] = "available"
			changes[id] = d
	set_states(changes)


## The cue of a hero's state (see HeroCard.CUES); "" for an available hero.
func cue_for(hero_id: String) -> String:
	return HeroCard.cue_of(state_of(hero_id))


func is_tappable(hero_id: String) -> bool:
	return _index.has(hero_id) and HeroCard.tappable(state_of(hero_id))


func _note_cue() -> void:
	var cues: Array = []
	for i in _shown:
		var c := HeroCard.cue_of(_states[i])
		if c != "" and not cues.has(c):
			cues.append(c)
	_has_cues = not cues.is_empty()
	CompKit.set_cue(self, ",".join(PackedStringArray(cues)))


## "states" while any card on show is in a marked state (then the cue meta lists their cues); "" when every card is plain.
func state_name() -> String:
	return "states" if _has_cues else ""


# ---- layout ----------------------------------------------------------------------------------------------------------------

func card_w() -> float:
	var w := size.x if size.x > 0.0 else 672.0
	return floorf((w - GAP * float(COLS - 1)) / float(COLS))


func rows() -> int:
	return int(ceil(float(_shown.size()) / float(COLS)))


func _relayout() -> void:
	var h := maxf(0.0, float(rows()) * (HeroCard.H + GAP) - GAP)
	if not is_equal_approx(custom_minimum_size.y, h):
		custom_minimum_size = Vector2(0.0, h)


func _on_resized() -> void:
	if not is_equal_approx(_last_cw, card_w()):
		_last_cw = card_w()
		queue_redraw()


## The card of slot `slot` (position in the filtered order), in this control's coordinates.
func slot_rect(slot: int) -> Rect2:
	var cw := card_w()
	return Rect2(Vector2(float(slot % COLS) * (cw + GAP), float(slot / COLS) * (HeroCard.H + GAP)), Vector2(cw, HeroCard.H))


## A hero's card in this control's coordinates, or an empty Rect2 when the filter hides it.
func card_rect(hero_id: String) -> Rect2:
	if not _index.has(hero_id):
		return Rect2()
	var slot := _shown.find(_index[hero_id])
	return slot_rect(slot) if slot >= 0 else Rect2()


func global_card_rect(hero_id: String) -> Rect2:
	var r := card_rect(hero_id)
	if r.size == Vector2.ZERO:
		return r
	return Rect2(get_global_transform() * r.position, r.size * get_global_transform().get_scale())


func slot_at(p: Vector2) -> int:
	if p.x < 0.0 or p.y < 0.0:
		return -1
	var cw := card_w()
	var col := int(p.x / (cw + GAP))
	var row := int(p.y / (HeroCard.H + GAP))
	if col >= COLS:
		return -1
	var slot := row * COLS + col
	if slot >= _shown.size():
		return -1
	return slot if slot_rect(slot).has_point(p) else -1


## The hero under a point (this control's coordinates), "" in a gap or outside.
func hero_at(p: Vector2) -> String:
	var s := slot_at(p)
	return String(heroes[_shown[s]]["id"]) if s >= 0 else ""


# ---- drawing: every card, pass by pass ------------------------------------------------------------------------------------

func _draw() -> void:
	draw_count += 1
	var win := _window()
	_last_window = win
	for p in HeroCard.PASSES:
		for slot in _shown.size():
			if not slot_rect(slot).intersects(win):
				continue
			var i: int = _shown[slot]
			var st: Dictionary = _states[i]
			if i == _pressed_idx:
				st = st.duplicate()
				st["pressed"] = true
			HeroCard.draw(self, slot_rect(slot), heroes[i], st, p)


# ---- touch: the grid owns the tap ------------------------------------------------------------------------------------------

func _global_of(local: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local


func _gui_input(event: InputEvent) -> void:
	var what := _tr.feed(event)
	match what:
		"down":
			_press_g = _global_of(_tr.press_pos)
			_last_g = _press_g
			_moved = false
			_press_slot = slot_at(_tr.press_pos)
			_set_pressed(_shown[_press_slot] if _press_slot >= 0 and HeroCard.tappable(_states[_shown[_press_slot]]) else -1)
			# not accepted: the page behind this grid scrolls from the drag (the S4 touch rows)
		"move":
			_last_g = _global_of(_tr.pos)
			if not _moved and _last_g.distance_to(_press_g) > SLOP:
				_moved = true
				_set_pressed(-1)
		"up":
			var g := _global_of(_tr.pos)
			var tap := _press_slot >= 0 and not _moved and g.distance_to(_press_g) <= SLOP
			var slot := _press_slot
			_press_slot = -1
			_set_pressed(-1)
			if tap and slot < _shown.size():
				_tapped(_shown[slot])


func _set_pressed(i: int) -> void:
	if i == _pressed_idx:
		return
	_pressed_idx = i
	queue_redraw()


func _tapped(i: int) -> void:
	var id: String = heroes[i]["id"]
	if not HeroCard.tappable(_states[i]):
		return
	if tut_id != "":
		CompKit.tap_event("%s.%s" % [tut_id, id])
	hero_tapped.emit(id)


# ---- the role filter bar ---------------------------------------------------------------------------------------------------

## The role filter of the Draft: All and the five roles as one Segmented of six stacked options (icon over a Caption 24
## word, full words "Jungle" and "Support": UI-PASS-2 11b). `on_change(role)` gets "" for All. Option ids are "" and the data role ids.
static func role_filter(on_change: Callable = Callable(), tut_id: String = "") -> Segmented:
	var opts: Array = [{"id": "", "label": Strings.t("draft.filter.all"), "icon": "dot"}]
	for r in ArtPalette.ROLES:
		opts.append({"id": r, "label": Strings.t("role.short." + r), "icon": Icons.role_id(r)})
	return Segmented.new(opts, "", on_change, "auto", tut_id)
