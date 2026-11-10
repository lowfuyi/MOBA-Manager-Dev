class_name BondPentagon
extends Control
## The five starters on a pentagon: line thickness shows the Bond of each pair, line colour how well the two
## understand each other (GDD 7.7). Drawn with flat shapes; art comes later.

## Drawn text (I-04): every size is at least the 24 px floor, every font is a Barlow weight from the type scale (these
## three sizes and weights are pairs of UI.TYPE_PAIRS). The circle is wide enough for the widest role word and the
## widest player name of the data (tests/check_fit_legacy.gd measures both against the *_ROOM widths).
const CIRCLE_R := 66.0
const TAG_SIZE := 26
const TAG_WEIGHT := "SemiBold"
const TAG_ROOM := 120.0     # the chord of the circle at the role word
const NAME_SIZE := 24
const NAME_WEIGHT := "SemiBold"
const NAME_ROOM := 108.0    # the chord at the name, lower in the circle
const NUM_SIZE := 24
const NUM_WEIGHT := "SemiBold"

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


## Width of one line of the pentagon's drawn text, in the font the pentagon draws it with.
static func text_width(text: String, font_size: int, weight: String) -> float:
	return UI.font(weight).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## `text` cut with ".." so it is at most `room` px wide (a name longer than the circle; none in the data today).
static func _fit(text: String, font_size: int, weight: String, room: float) -> String:
	if text_width(text, font_size, weight) <= room:
		return text
	var t := text
	while t.length() > 1 and text_width(t + "..", font_size, weight) > room:
		t = t.substr(0, t.length() - 1)
	return t + ".."


func _point(i: int) -> Vector2:
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	var r := minf(size.x, size.y) * 0.5 - (CIRCLE_R + 12.0)
	var a := -PI / 2.0 + TAU * float(i) / 5.0
	return c + Vector2(cos(a), sin(a)) * r


func _draw() -> void:
	if ids.size() != 5:
		return
	var tag_font := UI.font(TAG_WEIGHT)
	var name_font := UI.font(NAME_WEIGHT)
	var num_font := UI.font(NUM_WEIGHT)
	for i in 5:
		for j in range(i + 1, 5):
			var b := float(bond_of.call(ids[i], ids[j]))
			var u := (float(under_of.call(ids[i], ids[j])) + float(under_of.call(ids[j], ids[i]))) * 0.5
			var p1 := _point(i)
			var p2 := _point(j)
			draw_line(p1, p2, understanding_color(u), 2.0 + b / 100.0 * 14.0, true)
	for i in 5:
		var p := _point(i)
		draw_circle(p, CIRCLE_R, UI.PANEL2)
		draw_arc(p, CIRCLE_R, 0.0, TAU, 40, UI.ACCENT, 3.0, true)
		var tag := _fit(String(tags[i]), TAG_SIZE, TAG_WEIGHT, TAG_ROOM)
		var nm := _fit(String(names[i]), NAME_SIZE, NAME_WEIGHT, NAME_ROOM)
		draw_string(tag_font, p + Vector2(-TAG_ROOM * 0.5, -2.0), tag, HORIZONTAL_ALIGNMENT_CENTER, TAG_ROOM, TAG_SIZE, UI.ACCENT)
		draw_string(name_font, p + Vector2(-NAME_ROOM * 0.5, 26.0), nm, HORIZONTAL_ALIGNMENT_CENTER, NAME_ROOM, NAME_SIZE, UI.TEXT)
	for i in 5:
		for j in range(i + 1, 5):
			var mid := (_point(i) + _point(j)) * 0.5
			var txt := "%.0f" % float(bond_of.call(ids[i], ids[j]))
			var tw := text_width(txt, NUM_SIZE, NUM_WEIGHT)
			draw_rect(Rect2(mid + Vector2(-tw * 0.5 - 8.0, -20.0), Vector2(tw + 16.0, 34.0)), Color(0.05, 0.08, 0.12, 0.85))
			draw_string(num_font, mid + Vector2(-tw * 0.5, 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, NUM_SIZE, UI.TEXT)
