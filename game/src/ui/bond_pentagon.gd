class_name BondPentagon
extends Control
## The five starters on a pentagon: line thickness shows the Bond of each pair, line colour how well the two
## understand each other (GDD 7.7). Drawn with flat shapes; art comes later.

var ids: Array = []       # five player ids in slot order
var names: Array = []     # their names
var tags: Array = []      # short role names
var bond_of: Callable     # (a, b) -> bond
var under_of: Callable    # (a, b) -> understanding of a hearing b, 0..100


func _init() -> void:
	custom_minimum_size = Vector2(480, 520)
	mouse_filter = Control.MOUSE_FILTER_PASS


## Red for poor understanding through amber to green.
static func understanding_color(u: float) -> Color:
	var t := clampf(u / 60.0, 0.0, 1.0)
	return UI.BAD.lerp(UI.WARN, t * 2.0) if t < 0.5 else UI.WARN.lerp(UI.GOOD, (t - 0.5) * 2.0)


func _point(i: int) -> Vector2:
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	var r := minf(size.x, size.y) * 0.5 - 70.0
	var a := -PI / 2.0 + TAU * float(i) / 5.0
	return c + Vector2(cos(a), sin(a)) * r


func _draw() -> void:
	if ids.size() != 5:
		return
	var font := ThemeDB.fallback_font
	for i in 5:
		for j in range(i + 1, 5):
			var b := float(bond_of.call(ids[i], ids[j]))
			var u := (float(under_of.call(ids[i], ids[j])) + float(under_of.call(ids[j], ids[i]))) * 0.5
			var p1 := _point(i)
			var p2 := _point(j)
			draw_line(p1, p2, understanding_color(u), 2.0 + b / 100.0 * 14.0, true)
	for i in 5:
		var p := _point(i)
		draw_circle(p, 58.0, UI.PANEL2)
		draw_arc(p, 58.0, 0.0, TAU, 40, UI.ACCENT, 3.0, true)
		draw_string(font, p + Vector2(-58.0, -4.0), String(tags[i]), HORIZONTAL_ALIGNMENT_CENTER, 116.0, 26, UI.ACCENT)
		draw_string(font, p + Vector2(-58.0, 24.0), String(names[i]), HORIZONTAL_ALIGNMENT_CENTER, 116.0, 20, UI.TEXT)
	for i in 5:
		for j in range(i + 1, 5):
			var mid := (_point(i) + _point(j)) * 0.5
			var txt := "%.0f" % float(bond_of.call(ids[i], ids[j]))
			var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_rect(Rect2(mid + Vector2(-tw * 0.5 - 6.0, -17.0), Vector2(tw + 12.0, 28.0)), Color(0.05, 0.08, 0.12, 0.85))
			draw_string(font, mid + Vector2(-tw * 0.5, 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.TEXT)
