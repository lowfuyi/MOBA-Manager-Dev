class_name Podium
extends Control
## The top three of the league table (UI-PASS-2 5.13, ART-BIBLE 8.2, build plan I-10): three columns in the order 2nd, 1st, 3rd.
## Each column stacks, from the bottom, a pedestal (88, 120 and 64 px high for 2nd, 1st and 3rd: the heights show the order), the
## points (Value 40, tabular digits), the club name (Small 26 SemiBold, up to two lines, cut with "..." only when two lines are not
## enough) and the club badge (88 px for 1st, 72 for the others). The pedestal carries a medal (a disc with the NUMERAL 1, 2 or 3,
## so the order is a number and a shape, not a colour) and, for your own club, the "YOU" pill beside it and an accent outline. The
## pedestal takes a wash of the club colour (ART-BIBLE 3.9: club colour is allowed on the podium base).
## ONE Control drawn in passes, so it is one node and about eight draw calls (cards atlas, badges, letters, four text sizes).
## Data: `rows` is the first three rows of the table IN RANK ORDER: [{rank, club, name, main, sub, own}, ...] (the keys of RankRow;
## `main` is the points text, or the Form Rating when the table shows Form). Fewer than three rows leave the missing column
## empty; equal points are fine (the order is the order given: the table has already broken the tie). set_rows() ignores an equal
## list. A tap on a column (12 px slop on the screen, the S1 rule, never accepted so a swipe scrolls the page) emits
## `column_tapped(club_id)`. Columns follow the width the control has now ((width - 2 gaps) / 3: 216 at 672, 184 at 578).

signal column_tapped(club_id: String)

const ORDER := [2, 1, 3]                       # the left-to-right order of the ranks
const PED := {1: 120.0, 2: 88.0, 3: 64.0}
const BADGE := {1: 88.0, 2: 72.0, 3: 72.0}
const GAP := 12.0
const NAME_LH := 30.0
const PTS_H := 46.0
const TOP_PAD := 4.0
const SLOP := TouchTrack.SLOP
const H := TOP_PAD + 88.0 + 4.0 + NAME_LH * 2.0 + 2.0 + PTS_H + 120.0

var rows: Array = []
var tut_id := ""
var applied := 0
var draw_count := 0
var clipped: Array = []
var _back := CardKit.Ops.new()
var _ops := CardKit.Ops.new()
var _badges: Array = []
var _lines: Dictionary = {}    # rank -> the name lines
var _lines_w := -1.0
var _tr := TouchTrack.new()
var _press_g := Vector2.ZERO
var _press_rank := 0
var _moved := false
var _look_rank := 0


static func _norm(d: Dictionary) -> Dictionary:
	return {
		"rank": int(d.get("rank", 0)),
		"club": d.get("club", ""),
		"name": String(d.get("name", "")),
		"main": String(d.get("main", "")),
		"sub": String(d.get("sub", "")),
		"own": bool(d.get("own", false)),
	}


func _init(p_rows: Array = [], p_tut_id: String = "") -> void:
	tut_id = p_tut_id
	for i in mini(3, p_rows.size()):
		var n := _norm(p_rows[i] as Dictionary)
		if n["rank"] <= 0:
			n["rank"] = i + 1
		rows.append(n)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0.0, H)
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


func _on_visibility() -> void:
	if not is_visible_in_tree():
		_tr.reset()
		_press_rank = 0
		_set_look(0)


# ---- data in -----------------------------------------------------------------------------------------------------------------

func set_rows(p_rows: Array) -> void:
	var n: Array = []
	for i in mini(3, p_rows.size()):
		var d := _norm(p_rows[i] as Dictionary)
		if d["rank"] <= 0:
			d["rank"] = i + 1
		n.append(d)
	if n == rows:
		return
	rows = n
	applied += 1
	_relayout()
	_note_cue()
	queue_redraw()


func row_for_rank(rank: int) -> Dictionary:
	for r in rows:
		if int(r["rank"]) == rank:
			return r
	return {}


func state_name() -> String:
	for r in rows:
		if bool(r["own"]):
			return "own"
	return ""


func _note_cue() -> void:
	CompKit.set_cue(self, "numeral+medal+pill" if state_name() == "own" else "numeral+medal")


# ---- geometry (this control's coordinates) -------------------------------------------------------------------------------

func _w() -> float:
	return size.x if size.x > 0.0 else maxf(custom_minimum_size.x, UI.canvas_w() - 48.0)


func col_w() -> float:
	return floorf((_w() - GAP * 2.0) / 3.0)


## The whole column of a rank (badge to the foot of the pedestal): the tap area.
func column_rect(rank: int) -> Rect2:
	var slot := ORDER.find(rank)
	if slot < 0:
		return Rect2()
	var cw := col_w()
	return Rect2(float(slot) * (cw + GAP), 0.0, cw, _h())


func pedestal_rect(rank: int) -> Rect2:
	var c := column_rect(rank)
	if c.size == Vector2.ZERO:
		return c
	return Rect2(c.position.x, c.end.y - float(PED[rank]), c.size.x, float(PED[rank]))


func badge_rect(rank: int) -> Rect2:
	var c := column_rect(rank)
	if c.size == Vector2.ZERO:
		return c
	var ped := pedestal_rect(rank)
	var nl := (_lines.get(rank, []) as Array).size()
	var bs := float(BADGE[rank])
	var name_top := ped.position.y - PTS_H - NAME_LH * float(maxi(1, nl)) - 2.0
	return Rect2(c.position.x + (c.size.x - bs) * 0.5, name_top - 4.0 - bs, bs, bs)


func global_column_rect(rank: int) -> Rect2:
	var r := column_rect(rank)
	var t := get_global_transform()
	return Rect2(t * r.position, r.size * t.get_scale())


func rank_at(p: Vector2) -> int:
	for rank in ORDER:
		if not row_for_rank(rank).is_empty() and column_rect(rank).has_point(p):
			return rank
	return 0


func _h() -> float:
	return size.y if size.y > 0.0 else H


func _fname() -> Font:
	return UI.font("SemiBold")


func _relayout() -> void:
	_lines.clear()
	_lines_w = _w()
	var room := col_w() - 8.0
	for r in rows:
		_lines[int(r["rank"])] = PlanKit.wrap(_fname(), UI.S_SMALL, String(r["name"]), room, 2)


func _on_resized() -> void:
	if not is_equal_approx(_lines_w, _w()):
		_relayout()
	queue_redraw()


# ---- drawing ------------------------------------------------------------------------------------------------------------------------

func _medal_col(rank: int) -> Color:
	match rank:
		1:
			return UI.WARN
		2:
			return UI.TEXT2
	return UI.WARN.darkened(0.45)


func _layout() -> void:
	_back.clear()
	_ops.clear()
	_badges.clear()
	var f := _fname()
	var fpts := UI.font("SemiBold", true)
	var cw := col_w()
	var you_w := CardKit.text_w(f, UI.S_CAPTION, Strings.t("standings.you")) + 28.0
	for rank in ORDER:
		var r := row_for_rank(rank)
		var ped := pedestal_rect(rank)
		var look := rank == _look_rank
		# the pedestal: a wash of the club colour over the surface; an accent outline when it is yours
		var wash := UI.PANEL3
		var club: Variant = r.get("club", "")
		if not r.is_empty() and (club is Dictionary or String(club) != ""):
			var st: Dictionary = club if club is Dictionary else BadgeStyle.for_club(String(club))
			wash = UI.PANEL3.lerp(st["primary"], 0.38)
		if look:
			wash = wash.lightened(0.10)
		_back.bg("card", ped, wash)
		if not r.is_empty() and bool(r["own"]):
			_back.bg("ring", ped, UI.ACCENT)
		# the medal and, for you, the pill beside it
		var own := not r.is_empty() and bool(r["own"])
		var group := 48.0 + (8.0 + you_w if own else 0.0)
		var mx := ped.position.x + (cw - group) * 0.5
		var my := ped.position.y + ped.size.y * 0.5
		_back.shape("disc", Rect2(mx, my - 24.0, 48.0, 48.0), _medal_col(rank))
		_ops.text(f, UI.S_BODY, str(rank), mx, my, 48.0, UI.INK_TEAL, 1)
		if own:
			_back.bg("pill", Rect2(mx + 56.0, my - 22.0, you_w, 44.0), UI.ACCENT)
			_ops.text(f, UI.S_CAPTION, Strings.t("standings.you"), mx + 56.0, my, you_w, UI.INK_TEAL, 1)
		if r.is_empty():
			continue
		# points, name lines, badge
		var x := ped.position.x
		_ops.text(fpts, UI.S_BIG, String(r["main"]), x, ped.position.y - PTS_H * 0.5 - 2.0, cw, UI.TEXT, 1)
		var lines: Array = _lines.get(rank, [])
		var n := lines.size()
		var name_bottom := ped.position.y - PTS_H - 2.0
		for k in n:
			_ops.text(f, UI.S_SMALL, String(lines[k]), x + 4.0, name_bottom - NAME_LH * float(n - k) + NAME_LH * 0.5, cw - 8.0, UI.TEXT, 1)
		if club is Dictionary or String(club) != "":
			_badges.append({"club": club, "name": String(r["name"]), "rect": badge_rect(rank)})


func _draw() -> void:
	draw_count += 1
	_layout()
	_back.flush(self)
	for b in _badges:
		Badge.draw_shapes(self, b["club"], b["rect"])
	for b in _badges:
		Badge.draw_letter(self, b["club"], String(b["name"]), b["rect"], UI.font("Bold"))
	_ops.flush(self)
	clipped = _ops.clipped.duplicate()


# ---- touch --------------------------------------------------------------------------------------------------------------------------------

func _global_of(local: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local


func _gui_input(event: InputEvent) -> void:
	var what := _tr.feed(event)
	match what:
		"down":
			_press_g = _global_of(_tr.press_pos)
			_moved = false
			_press_rank = rank_at(_tr.press_pos)
			_set_look(_press_rank)
			# not accepted: the page behind the podium scrolls from the drag
		"move":
			if not _moved and _global_of(_tr.pos).distance_to(_press_g) > SLOP:
				_moved = true
				_set_look(0)
		"up":
			var tap := _press_rank > 0 and not _moved and _global_of(_tr.pos).distance_to(_press_g) <= SLOP
			var rank := _press_rank
			_press_rank = 0
			_set_look(0)
			if tap:
				var r := row_for_rank(rank)
				CompKit.tap_event(tut_id)
				if not r.is_empty():
					var c: Variant = r["club"]
					column_tapped.emit(String(c["id"]) if c is Dictionary else String(c))


func _set_look(rank: int) -> void:
	if rank == _look_rank:
		return
	_look_rank = rank
	queue_redraw()
