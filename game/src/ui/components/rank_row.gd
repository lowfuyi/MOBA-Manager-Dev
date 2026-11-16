class_name RankRow
extends Control
## One row of the league table (UI-PASS-2 5.13, ART-BIBLE 8.2, build plan I-10): rank, a 56 px club badge, the club name (Body 32, one
## or two lines, never cut in the middle of a word), and a right column of two lines, the main number (Heading 36, tabular digits)
## over a small line (Small 26, tabular digits; the record "1-0"). 104 px high, taller only when a name or a note needs more lines.
## ONE Control drawn in passes (card and bar, badge, letter, text): about six draw calls per row, so a ten-row table is about 60.
## Data (a Dictionary; every key optional):
##   rank   int      the position (tabular digits in a 56 px column)
##   club   String   the club id (the badge style) or the badge style itself
##   name   String   the club name (wraps to two lines; with `own` the YOU pill needs room after the last line, else the name
##                   is wrapped narrower; a third line makes the row taller)
##   main   String   the big right-hand number: points, or the Form Rating when the Table shows Form
##   sub    String   the small line under it: the record "0-1". (Do not print "Form Rating" here: 123 px at 26, the column is 120.)
##   own    bool     your club: PANEL3 fill, an 8 px accent bar on the left and a "YOU" pill after the name (fill, bar and TEXT:
##                   the cue works without colour)
##   note   String   one sentence under the name (the pinned row: "1 win and 3 pts to the line"), Small 26, up to two lines
## Digits are TABULAR (UI.font(weight, true)): every digit has the same width, so a column of points lines up (`main_width()` is
## what a test measures). A tap (12 px slop on the screen, the S1 rule, the event never accepted so a swipe scrolls the page)
## emits `pressed(club_id)`; the page decides what that opens. set_data() ignores an equal Dictionary.
## Static helpers: RankRow.divider(text) is the dashed playoff line with its label ("Playoff line (top 4)").

signal pressed(club_id: String)

const H := 104.0
const RANK_X := 16.0
const RANK_W := 56.0
const BADGE := 56.0
const BADGE_X := 80.0
const NAME_X := 148.0
const COL_MIN := 96.0
const PAD_R := 16.0
const BAR_W := 8.0
const SLOP := TouchTrack.SLOP
const MAIN_SIZE := UI.S_HEAD    # points: Heading 36 (the bible's row; a fifth tnum size, see the I-10 handback)

var data: Dictionary = {}
var tut_id := ""
var applied := 0
var draw_count := 0
var clipped: Array = []
var name_lines: Array = []
var note_lines: Array = []
var pill_inline := true
var _cut: Array = []        # the name or the note, when wrap() had to cut it
var _back := CardKit.Ops.new()
var _ops := CardKit.Ops.new()
var _badge := {}
var _tr := TouchTrack.new()
var _press_g := Vector2.ZERO
var _moved := false
var _down := false
var _pressed_look := false
var _lines_w := -1.0


static func num_font(weight: String = "SemiBold") -> Font:
	return UI.font(weight, true)


## The width of a number as the row prints it (36 px, SemiBold, tabular).
static func main_width(text: String) -> float:
	return CardKit.text_w(num_font("SemiBold"), MAIN_SIZE, text)


static func _norm(d: Dictionary) -> Dictionary:
	return {
		"rank": int(d.get("rank", 0)),
		"club": d.get("club", ""),
		"name": String(d.get("name", "")),
		"main": String(d.get("main", "")),
		"sub": String(d.get("sub", "")),
		"own": bool(d.get("own", false)),
		"note": String(d.get("note", "")),
	}


func _init(p_data: Dictionary = {}, p_tut_id: String = "") -> void:
	data = _norm(p_data)
	tut_id = p_tut_id
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
		_down = false
		_set_look(false)


# ---- data in -----------------------------------------------------------------------------------------------------------------

func set_data(d: Dictionary) -> void:
	var n := _norm(d)
	if n == data:
		return
	data = n
	applied += 1
	_relayout()
	_note_cue()
	queue_redraw()


func club_id() -> String:
	var c: Variant = data["club"]
	return String(c["id"]) if c is Dictionary else String(c)


func is_own() -> bool:
	return bool(data["own"])


func state_name() -> String:
	return "own" if is_own() else ""


func _note_cue() -> void:
	CompKit.set_cue(self, "fill+bar+pill" if is_own() else "rank+badge+name")


# ---- layout ------------------------------------------------------------------------------------------------------------------------

func _w() -> float:
	return size.x if size.x > 0.0 else maxf(custom_minimum_size.x, UI.canvas_w() - 48.0)


func _fname() -> Font:
	return UI.font("Regular", true)


func _fsmall() -> Font:
	return UI.font("Medium", true)


func _pill_w() -> float:
	return CardKit.text_w(UI.font("SemiBold"), UI.S_CAPTION, Strings.t("standings.you")) + 28.0


func col_w() -> float:
	return maxf(COL_MIN, maxf(main_width(String(data["main"])), CardKit.text_w(_fsmall(), UI.S_SMALL, String(data["sub"]))))


func name_room() -> float:
	return maxf(60.0, _w() - NAME_X - col_w() - PAD_R - 12.0)


func row_h() -> float:
	var fn := _fname()
	var fs := _fsmall()
	var pad := 16.0
	var content := PlanKit.line_h(fn, UI.S_BODY) * float(name_lines.size()) + PlanKit.line_h(fs, UI.S_SMALL) * float(note_lines.size())
	return maxf(H, ceilf(content + pad))


func _relayout() -> void:
	var w := _w()
	_lines_w = w
	var fn := _fname()
	var room := name_room()
	var nm := String(data["name"])
	var lines: Array = PlanKit.wrap(fn, UI.S_BODY, nm, room, 3)
	pill_inline = true
	if is_own() and not lines.is_empty():
		var last_w := CardKit.text_w(fn, UI.S_BODY, String(lines[lines.size() - 1]))
		if last_w + 12.0 + _pill_w() > room:
			lines = PlanKit.wrap(fn, UI.S_BODY, nm, room - _pill_w() - 12.0, 3)    # narrower, so the last line leaves room for the pill
			pill_inline = false if lines.is_empty() else (CardKit.text_w(fn, UI.S_BODY, String(lines[lines.size() - 1])) + 12.0 + _pill_w() <= room)
	name_lines = lines
	note_lines = PlanKit.wrap(_fsmall(), UI.S_SMALL, String(data["note"]), room, 2)
	_cut = []
	if PlanKit.was_cut(name_lines, nm):
		_cut.append(nm)
	if PlanKit.was_cut(note_lines, String(data["note"])):
		_cut.append(String(data["note"]))
	var h := row_h()
	if not is_equal_approx(custom_minimum_size.y, h):
		custom_minimum_size = Vector2(0.0, h)


func _on_resized() -> void:
	if not is_equal_approx(_lines_w, _w()):
		_relayout()
	queue_redraw()


func badge_rect() -> Rect2:
	return Rect2(BADGE_X, (_h() - BADGE) * 0.5, BADGE, BADGE)


func _h() -> float:
	return size.y if size.y > 0.0 else row_h()


## The right edge of the main number (tests compare it between rows: tabular digits end at the same x).
func main_right() -> float:
	return _w() - PAD_R


# ---- drawing --------------------------------------------------------------------------------------------------------------------------

func _layout() -> void:
	_back.clear()
	_ops.clear()
	var w := _w()
	var h := _h()
	var own := is_own()
	var cy := h * 0.5
	var fn := _fname()
	var fs := _fsmall()
	# the card, the accent bar and the pill go to the back list (one run of the cards atlas)
	var card := Rect2(0.0, 4.0, w, h - 8.0)
	var fill := UI.PANEL3 if own else UI.PANEL
	if _pressed_look:
		fill = fill.lightened(0.10)
	_back.bg("card", card, fill)
	if own:
		_back.shape("solid", Rect2(0.0, 16.0, BAR_W, h - 32.0), UI.ACCENT)
	# rank
	var rank := int(data["rank"])
	if rank > 0:
		_ops.text(fn, UI.S_BODY, str(rank), RANK_X, cy, RANK_W, UI.TEXT, 1)
	# the name, one or two lines, then the pill
	var nlh := PlanKit.line_h(fn, UI.S_BODY)
	var slh := PlanKit.line_h(fs, UI.S_SMALL)
	var block := nlh * float(name_lines.size()) + slh * float(note_lines.size())
	var top := cy - block * 0.5
	var room := name_room()
	for k in name_lines.size():
		_ops.text(fn, UI.S_BODY, String(name_lines[k]), NAME_X, top + nlh * (float(k) + 0.5), room, UI.TEXT, 0)
	if own and not name_lines.is_empty():
		var last := String(name_lines[name_lines.size() - 1])
		var pw := _pill_w()
		var last_cy := top + nlh * (float(name_lines.size()) - 0.5)
		var px := NAME_X + CardKit.text_w(fn, UI.S_BODY, last) + 12.0
		var py := last_cy - 22.0
		if not pill_inline:
			px = NAME_X
			py = top + nlh * float(name_lines.size()) + 2.0
		_back.bg("pill", Rect2(px, py, pw, 44.0), UI.ACCENT)
		_ops.text(UI.font("SemiBold"), UI.S_CAPTION, Strings.t("standings.you"), px, py + 22.0, pw, UI.INK_TEAL, 1)
	for k in note_lines.size():
		_ops.text(fs, UI.S_SMALL, String(note_lines[k]), NAME_X, top + nlh * float(name_lines.size()) + slh * (float(k) + 0.5), room, UI.TEXT2, 0)
	# the right column: main over sub
	var rx := w - PAD_R - col_w()
	var main := String(data["main"])
	var sub := String(data["sub"])
	var main_h := PlanKit.line_h(num_font("SemiBold"), MAIN_SIZE)
	var two := main != "" and sub != ""
	var my := cy - (13.0 if two else 0.0)
	if main != "":
		_ops.text(num_font("SemiBold"), MAIN_SIZE, main, rx, my, col_w(), UI.TEXT, 2)
	if sub != "":
		_ops.text(fs, UI.S_SMALL, sub, rx, cy + (main_h * 0.5 + 2.0 if two else 0.0), col_w(), UI.TEXT2, 2)


func _draw() -> void:
	draw_count += 1
	_layout()
	PlanKit.batch_order(_back)
	_back.flush(self)
	var br := badge_rect()
	var c: Variant = data["club"]
	if c is Dictionary or String(c) != "":
		Badge.draw_shapes(self, c, br)
		Badge.draw_letter(self, c, String(data["name"]), br, UI.font("Bold"))
	_ops.flush(self)
	clipped = _ops.clipped.duplicate()
	clipped.append_array(_cut)


# ---- touch ------------------------------------------------------------------------------------------------------------------------------

func _global_of(local: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local


func _gui_input(event: InputEvent) -> void:
	var what := _tr.feed(event)
	match what:
		"down":
			_press_g = _global_of(_tr.press_pos)
			_moved = false
			_down = true
			_set_look(true)
			# not accepted: the page behind the row scrolls from the drag
		"move":
			if not _moved and _global_of(_tr.pos).distance_to(_press_g) > SLOP:
				_moved = true
				_set_look(false)
		"up":
			var tap := _down and not _moved and _global_of(_tr.pos).distance_to(_press_g) <= SLOP
			_down = false
			_set_look(false)
			if tap:
				CompKit.tap_event(tut_id)
				pressed.emit(club_id())


func _set_look(v: bool) -> void:
	if v == _pressed_look:
		return
	_pressed_look = v
	queue_redraw()


# ---- the playoff line -----------------------------------------------------------------------------------------------------------------

## A dashed divider with a label in the middle ("Playoff line (top 4)"): 48 px high, one Control. Dashes are quads of the cards
## atlas, the label is Caption 24 SemiBold, so it is a line AND words (colour is not what carries it).
class Divider extends Control:
	var text := ""
	var draw_count := 0
	var _ops := CardKit.Ops.new()

	func _init(p_text: String = "") -> void:
		text = p_text
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0.0, 48.0)
		resized.connect(queue_redraw)

	func set_text(t: String) -> void:
		if t == text:
			return
		text = t
		queue_redraw()

	func _draw() -> void:
		draw_count += 1
		_ops.clear()
		var w := size.x
		var f := UI.font("SemiBold")
		var cy := size.y * 0.5
		var tw := minf(CardKit.text_w(f, UI.S_CAPTION, text), w - 120.0)
		var x0 := (w - tw) * 0.5
		var col := Color(UI.DIM.r, UI.DIM.g, UI.DIM.b, 0.8)
		var x := 8.0
		while x + 10.0 < x0 - 12.0:
			_ops.shape("solid", Rect2(x, cy - 1.5, 10.0, 3.0), col)
			x += 17.0
		x = x0 + tw + 14.0
		while x + 10.0 < w - 8.0:
			_ops.shape("solid", Rect2(x, cy - 1.5, 10.0, 3.0), col)
			x += 17.0
		_ops.text(f, UI.S_CAPTION, text, x0, cy, tw + 2.0, UI.TEXT2, 0)
		_ops.flush(self)


static func divider(text: String) -> Divider:
	return Divider.new(text)
