class_name Carousel
extends Control
## A horizontal row of cards that lives inside a vertical page (UI-PASS-2 5.9, build plan I-08, SPIKE-RESULTS-0.7 S1).
## ONE Control that owns hit-testing. Its cards are display items: `mouse_filter` is forced to IGNORE on every card and on
## everything inside it (a Button inside a card is not tappable on its own; the card taps). With a Button or any other
## non-IGNORE child the engine keeps routing later drags to that child and the direction lock fails at 60 and 90 degrees (S1).
## Direction lock: after 12 px of finger travel it decides once per touch, horizontal if |dx| > |dy|, otherwise vertical.
##   horizontal: it moves its own content and swallows both the touch drag and the emulated mouse motion, then flings and
##               snaps to a card; vertical: it stops swallowing, so the page scrolls; until the decision it swallows (no twitch).
## Tap: it finds the card under the PRESS itself and emits `card_tapped(i)` on release if the finger has moved at most 12 px
## (screen distance). A press in the gap between cards, in the page dots, or any drag is not a tap.
## Items beyond MAX_CARDS (8) are not drawn; a "See all" tile ends the row and emits `see_all_tapped` (and runs `see_all`).
## A card is `card_w` wide (300 free agents, 560 upcoming games) but never wider than the row less a 48 px peek of the next
## card, so a 560 card at large text (578 px) still shows its neighbour. 3 or more slots show page dots (the current one is
## a wide pill, the others small discs: a shape cue). 0 items: `empty_text` is drawn in the row (the screen may use an
## EmptyState instead and hide the carousel). Cards are laid out by this control (no container), at the height of the
## tallest card; the control's minimum height follows it.
## Built once; set_items / set_card_w / set_see_all / set_empty_text change it in place (an equal value changes nothing).
## `tut_id` tags the row; a tap on card i raises `tap:<tut_id>.<i>` (the See all tile `tap:<tut_id>.see_all`) and every card
## is tagged `<tut_id>.<i>` so the coach overlay can point at one.

signal card_tapped(index: int)
signal see_all_tapped

const LOCK_PX := TouchTrack.SLOP
const MAX_CARDS := 8
const GAP := 16
const PEEK := 48
const DOTS_H := 40
const TILE_W := 240
const MIN_H := 120
const SNAP_TIME := 0.22
const FLING_S := 0.15           # how far ahead a fling projects: finger speed (px/s) times this
const FLING_MAX_CARDS := 2.0    # a fling never carries more than this many cards past where the finger let go

enum { IDLE, UNDECIDED, HORIZONTAL, VERTICAL }

var card_w := 300.0
var items: Array = []           # the cards, in order (all of them, also those beyond MAX_CARDS that are not shown)
var see_all: Callable = Callable()
var empty_text := ""
var tut_id := ""
var applied := 0
var draw_count := 0
var decisions: Array = []       # "h" / "v" per touch that reached the lock (tests read it)
var lock_state := IDLE
var _shown: Array = []          # the cards on the row (at most MAX_CARDS)
var _tile: _Tile
var _content: Control
var _xs: Array = []             # slot left edges in content coordinates (cards, then the See all tile)
var _ws: Array = []             # slot widths
var _card_h := 0.0
var _cw := 0.0
var _x := 0.0                   # scroll offset: content x that sits at the left edge
var _x0 := 0.0                  # offset at the start of the drag
var _tr := TouchTrack.new()
var _press_idx := -1
var _tween: Tween
var _samples: Array = []        # [msec, x] pairs of the last 120 ms of a horizontal drag
var _dot := -1                  # the dot (slot) last drawn as current
var _relayout_queued := false


## The "See all" tile at the end of the row (drawn, not a button).
class _Tile extends Control:
	var count := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(UI.box(UI.PANEL, UI.R_CARD, 0, UI.LINE_HI, 2), r)
		var font := UI.font("SemiBold")
		var label := Strings.t("home.see_all")
		var lw := CompKit.text_width(font, UI.S_BODY, label)
		var cy := r.size.y * 0.5
		draw_string(font, Vector2((r.size.x - lw) * 0.5, cy + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16.0, UI.S_BODY, UI.TEXT)
		var num := "+%d" % count
		var nf := UI.font("Medium")
		var nw := CompKit.text_width(nf, UI.S_SMALL, num)
		draw_string(nf, Vector2((r.size.x - nw) * 0.5, cy + 44.0), num, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16.0, UI.S_SMALL, UI.DIM)
		IconHook.draw(self, "chevron_right", Rect2(Vector2(r.size.x * 0.5 - 20.0, cy - 64.0), Vector2(40, 40)), UI.TEAL_HI)


func _init(p_card_w: float = 300.0, p_items: Array = [], p_see_all: Callable = Callable(), p_tut_id: String = "", p_empty_text: String = "") -> void:
	card_w = p_card_w
	see_all = p_see_all
	empty_text = p_empty_text
	tut_id = p_tut_id
	mouse_filter = Control.MOUSE_FILTER_PASS    # the page behind it still gets what it does not swallow
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_tile = _Tile.new()
	_tile.visible = false
	_content.add_child(_tile)
	CompKit.mark_stateful(self)
	set_meta("h_scroller", true)    # the fit audit lets cards extend sideways inside this clip
	CompKit.tag(self, tut_id)
	_set_items(p_items)
	resized.connect(_queue_relayout)
	visibility_changed.connect(_on_visibility)


func _exit_tree() -> void:
	_tr.reset()
	_kill_tween()


func _on_visibility() -> void:
	if not is_visible_in_tree():
		_tr.reset()
		lock_state = IDLE
		_set_pressed(-1)


# ---- items and layout ---------------------------------------------------------------------------------------------

func _set_items(p_items: Array) -> void:
	for c in _shown:
		if is_instance_valid(c):
			(c as Node).queue_free()
	for c in items:
		if is_instance_valid(c) and (c as Node).get_parent() == null:
			(c as Node).queue_free()    # a card given but not shown (beyond MAX_CARDS) is never in the tree
	items = p_items.duplicate()
	_shown.clear()
	for i in mini(items.size(), MAX_CARDS):
		var c := items[i] as Control
		_ignore_all(c)
		_content.add_child(c)
		c.minimum_size_changed.connect(_queue_relayout)
		if tut_id != "":
			UI.tag(c, "%s.%d" % [tut_id, i], false)
		_shown.append(c)
	_tile.count = maxi(0, items.size() - MAX_CARDS)
	_tile.visible = items.size() > MAX_CARDS
	_tile.queue_redraw()
	_x = 0.0
	_content.position.x = 0.0
	_relayout()


## Every control in the card ignores the pointer: this control hit-tests and taps for it (the S1 rule).
static func _ignore_all(n: Node) -> void:
	var c := n as Control
	if c != null:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.focus_mode = Control.FOCUS_NONE
	for ch in n.get_children():
		_ignore_all(ch)


func set_items(p_items: Array) -> void:
	if p_items.size() == items.size():
		var same := true
		for i in p_items.size():
			if p_items[i] != items[i]:
				same = false
				break
		if same:
			return
	applied += 1
	_set_items(p_items)


func set_card_w(v: float) -> void:
	if is_equal_approx(v, card_w):
		return
	card_w = v
	applied += 1
	_relayout()


func set_see_all(cb: Callable) -> void:
	if cb == see_all:
		return
	see_all = cb
	applied += 1


func set_empty_text(t: String) -> void:
	if t == empty_text:
		return
	empty_text = t
	applied += 1
	queue_redraw()


func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	_relayout.call_deferred()


func _slot_count() -> int:
	return _shown.size() + (1 if _tile.visible else 0)


## Card width from the room the row has now (never from 720): the asked width, less than the row minus the peek.
func _wanted_cw() -> float:
	if size.x <= 0.0:
		return card_w
	if _slot_count() <= 1:
		return minf(card_w, size.x)
	return minf(card_w, maxf(96.0, size.x - PEEK - GAP))


func _relayout() -> void:
	_relayout_queued = false
	_cw = _wanted_cw()
	var h := 0.0
	for c in _shown:
		var cc := c as Control
		cc.custom_minimum_size.x = _cw
		cc.size = Vector2(_cw, 0.0)
		h = maxf(h, cc.get_combined_minimum_size().y)
	_card_h = ceilf(h) if not _shown.is_empty() else 0.0
	var n := _slot_count()
	var x := 0.0
	_xs.clear()
	_ws.clear()
	for i in _shown.size():
		var cc := _shown[i] as Control
		cc.position = Vector2(x, 0.0)
		cc.size = Vector2(_cw, _card_h)
		_xs.append(x)
		_ws.append(_cw)
		x += _cw + GAP
	if _tile.visible:
		var tw := minf(float(TILE_W), _cw)
		_tile.position = Vector2(x, 0.0)
		_tile.size = Vector2(tw, _card_h)
		_xs.append(x)
		_ws.append(tw)
	var want_h := (_card_h if n > 0 else float(MIN_H)) + (float(DOTS_H) if n >= 3 else 0.0)
	if not is_equal_approx(custom_minimum_size.y, want_h):
		custom_minimum_size.y = want_h
	_x = clampf(_x, 0.0, max_offset())
	_content.position.x = -_x
	CompKit.set_cue(self, "dots" if dots_shown() else "")
	_note_dot()
	queue_redraw()


# ---- the scroll offset (also what the tests read) ----------------------------------------------------------------------

func h_offset() -> float:
	return _x


func content_width() -> float:
	return 0.0 if _xs.is_empty() else float(_xs[-1]) + float(_ws[-1])


func max_offset() -> float:
	return maxf(0.0, content_width() - size.x)


func set_h_offset(v: float) -> void:
	var nx := clampf(v, 0.0, max_offset())
	if is_equal_approx(nx, _x):
		return
	_x = nx
	_content.position.x = -_x
	_note_dot()


## The offsets the row can rest at: each slot's left edge, the last ones held at the right end.
func snap_points() -> Array:
	var out: Array = []
	var m := max_offset()
	for x in _xs:
		var p := minf(float(x), m)
		if out.is_empty() or not is_equal_approx(float(out[-1]), p):
			out.append(p)
	return out


func _nearest_snap(x: float) -> float:
	var best := 0.0
	var bd := INF
	for p in snap_points():
		var d := absf(float(p) - x)
		if d < bd:
			bd = d
			best = float(p)
	return best


## The slot the page dots mark as current.
func current_index() -> int:
	var pts := snap_points()
	var best := 0
	var bd := INF
	for i in pts.size():
		var d := absf(float(pts[i]) - _x)
		if d < bd:
			bd = d
			best = i
	return best


func _note_dot() -> void:
	var d := current_index() if dots_shown() else -1
	if d != _dot:
		_dot = d
		queue_redraw()


func scroll_to_index(i: int, animated: bool = true) -> void:
	var pts := snap_points()
	if pts.is_empty():
		return
	_move_to(float(pts[clampi(i, 0, pts.size() - 1)]), animated)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _move_to(target: float, animated: bool = true) -> void:
	_kill_tween()
	target = clampf(target, 0.0, max_offset())
	if not animated or not UI.animate or not is_inside_tree() or is_equal_approx(target, _x):
		set_h_offset(target)
		return
	_tween = create_tween()
	_tween.tween_method(set_h_offset, _x, target, SNAP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ---- reading the row --------------------------------------------------------------------------------------------------

func card_count() -> int:
	return _shown.size()


func card(i: int) -> Control:
	return _shown[i] as Control if i >= 0 and i < _shown.size() else null


func has_see_all_tile() -> bool:
	return _tile.visible


func see_all_tile() -> Control:
	return _tile


func dots_shown() -> bool:
	return _slot_count() >= 3


func card_height() -> float:
	return _card_h


func card_width() -> float:
	return _cw


## The slot (0 .. n-1; n-1 is the See all tile when it is shown) under a point in this control's coordinates, or -1 for the gap
## between cards, the dots, or outside.
func index_at(p: Vector2) -> int:
	if p.y < 0.0 or p.y > _card_h or p.x < 0.0 or p.x > size.x:
		return -1
	var cx := p.x + _x
	for i in _xs.size():
		if cx >= float(_xs[i]) and cx <= float(_xs[i]) + float(_ws[i]):
			return i
	return -1


func state_name() -> String:
	return "dots" if dots_shown() else ""


# ---- touch ------------------------------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var what := _tr.feed(event)
	match what:
		"down":
			_kill_tween()
			lock_state = UNDECIDED
			_x0 = _x
			_samples.clear()
			_press_idx = index_at(_tr.press_pos)
			_set_pressed(_press_idx)
			# not accepted: the page behind may note the press (the S1 spike behaves the same)
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
			if d.length() > LOCK_PX:
				if absf(d.x) > absf(d.y):
					lock_state = HORIZONTAL
					decisions.append("h")
					_samples.clear()
				else:
					lock_state = VERTICAL
					decisions.append("v")
				_set_pressed(-1)
				if lock_state == HORIZONTAL:
					_drag_to(d.x)
			accept_event()    # undecided: swallow, the page does not twitch
		HORIZONTAL:
			_drag_to((_tr.pos - _tr.press_pos).x)
			accept_event()
		# VERTICAL: not accepted, the parent ScrollContainer gets the drag and scrolls the page


func _drag_to(dx: float) -> void:
	set_h_offset(_x0 - dx)
	_samples.append([Time.get_ticks_msec(), _x])
	while _samples.size() > 1 and int(_samples[-1][0]) - int(_samples[0][0]) > 120:
		_samples.pop_front()


func _on_up() -> void:
	var st := lock_state
	lock_state = IDLE
	_set_pressed(-1)
	if st == UNDECIDED:
		if _tr.travel() <= TouchTrack.SLOP and _press_idx >= 0:
			_tapped(_press_idx)
	elif st == HORIZONTAL:
		_release_fling()
	_press_idx = -1


func _release_fling() -> void:
	var v := 0.0    # content speed, px per second
	if _samples.size() >= 2:
		var dt := float(int(_samples[-1][0]) - int(_samples[0][0])) / 1000.0
		if dt > 0.005:
			v = (float(_samples[-1][1]) - float(_samples[0][1])) / dt
	var travel := clampf(v * FLING_S, -FLING_MAX_CARDS * (card_w + GAP), FLING_MAX_CARDS * (card_w + GAP))
	_move_to(_nearest_snap(_x + travel), true)


func _tapped(i: int) -> void:
	if i >= _shown.size():
		if tut_id != "":
			CompKit.tap_event(tut_id + ".see_all")
		see_all_tapped.emit()
		if see_all.is_valid():
			see_all.call()
		return
	if tut_id != "":
		CompKit.tap_event("%s.%d" % [tut_id, i])
	card_tapped.emit(i)


func _set_pressed(i: int) -> void:
	for k in _shown.size():
		(_shown[k] as Control).modulate = Color(0.86, 0.9, 0.95) if k == i else Color(1, 1, 1)
	_tile.modulate = Color(0.86, 0.9, 0.95) if i == _shown.size() and _tile.visible else Color(1, 1, 1)


# ---- drawing: only the dots and the empty text; the cards draw themselves ------------------------------------------------

func _draw() -> void:
	draw_count += 1
	var n := _slot_count()
	if n == 0:
		if empty_text != "":
			draw_style_box(UI.box(Color(0, 0, 0, 0), UI.R_CARD, 0, UI.LINE_HI, 2), Rect2(Vector2.ZERO, size))
			draw_multiline_string(UI.font("Regular"), Vector2(24.0, size.y * 0.5 - 8.0), empty_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 48.0, UI.S_SMALL, 2, UI.DIM)
		return
	if n < 3:
		return
	var cur := current_index()
	var dot_n := snap_points().size()
	var pill := 28.0
	var disc := 10.0
	var gap := 12.0
	var total := pill + float(dot_n - 1) * (disc + gap)
	var x := (size.x - total) * 0.5
	var y := _card_h + float(DOTS_H) * 0.5
	for i in dot_n:
		if i == cur:
			draw_style_box(UI.box(UI.TEAL_HI, 5), Rect2(Vector2(x, y - 5.0), Vector2(pill, disc)))
			x += pill + gap
		else:
			draw_circle(Vector2(x + disc * 0.5, y), disc * 0.5, UI.DIM)
			x += disc + gap
