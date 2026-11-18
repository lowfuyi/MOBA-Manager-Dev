class_name UnderstandingGrid
extends Control
## The 5 x 5 "who understands whom" grid of Team chemistry (GDD 7.7), drawn by ONE control through CardKit.Ops (Alpha 0.9.1):
## 36 tinted cells from the cards atlas and every number in one text run, instead of 36 PanelContainers with a label each
## (the old grid cost about 70 draw calls and kept the legacy Chemistry screen over the hard limit when scrolled).
## Row = the player who listens, column = the player who speaks; the diagonal is "-". Colours as BondPentagon.

const GAP := 2.0    # "Support" (76 px) needs 84 px of room in large text (check_fit_legacy, 8 px slack)
const ROW_H := 64.0
const VGAP := 6.0

var heads: Array = []       # five short role words
var values: Array = []      # 5 x 5 understanding (the diagonal ignored)
var _q := CardKit.Ops.new()


func _init() -> void:
	custom_minimum_size = Vector2(0, 6.0 * ROW_H + 5.0 * VGAP)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(queue_redraw)


func cell_w() -> float:
	return (size.x - 5.0 * GAP) / 6.0


## The width a cell gives its text (the fit check reads it): no padding inside a cell.
func cell_text_room() -> float:
	return cell_w()


func cell_rect(row: int, col: int) -> Rect2:
	return Rect2(Vector2(float(col) * (cell_w() + GAP), float(row) * (ROW_H + VGAP)), Vector2(cell_w(), ROW_H))


func _draw() -> void:
	if heads.size() != 5 or values.size() != 5:
		return
	_q.clear()
	var f := UI.font("SemiBold")    # Caption weight, the scale's own pair (as the old cells)
	for r in 6:
		for c in 6:
			var rect := cell_rect(r, c)
			var bg := UI.PANEL
			var txt := ""
			var col := UI.TEXT
			if r == 0 and c == 0:
				pass
			elif r == 0:
				txt = String(heads[c - 1])
				col = UI.ACCENT
			elif c == 0:
				txt = String(heads[r - 1])
				col = UI.ACCENT
			elif r == c:
				txt = "-"
				col = UI.DIM
			else:
				var u := float(values[r - 1][c - 1])
				bg = BondPentagon.understanding_color(u).darkened(0.55)
				txt = "%.0f" % u
			_q.bg("pill", rect, bg)
			if txt != "":
				_q.text(f, UI.S_CAPTION, txt, rect.position.x, rect.get_center().y, rect.size.x, col, 1)
	_q.flush(self)
