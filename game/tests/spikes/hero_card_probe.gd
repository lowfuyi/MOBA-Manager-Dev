extends Control
## S4 candidate: HeroCard as ONE Control that draws itself (build plan 2.7 and I-09). Placeholder art: a coloured disc
## with the hero's initial stands in for the portrait. States: available, selected, banned (a drawn X plus the word
## BAN, not colour alone), picked by you (circle), picked by them (hexagon). No class_name (no --import needed).
signal tapped(hero_id: String)
enum St { AVAILABLE, SELECTED, BANNED, YOU, THEM }
var hero_id := ""
var hero_name := ""
var tag := ""
var role := ""
var state: int = St.AVAILABLE
var _down := false
static var _boxes: Dictionary = {}        # one StyleBoxFlat per state, shared by every card (the UI.box() cache idea)


func setup(id: String, nm: String, tg: String, rl: String, w: float) -> void:
	hero_id = id
	hero_name = nm
	tag = tg
	role = rl
	custom_minimum_size = Vector2(w, 190)
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE


## Ignores a value equal to the one it holds (the in-place rule); only a real change redraws.
func set_state(s: int) -> void:
	if s == state:
		return
	state = s
	queue_redraw()


static func _box(s: int) -> StyleBoxFlat:
	if not _boxes.has(s):
		var b := StyleBoxFlat.new()
		b.set_corner_radius_all(20)
		b.set_border_width_all(2 if s != St.SELECTED else 4)
		b.bg_color = Color(0.11, 0.13, 0.19) if s != St.BANNED else Color(0.08, 0.09, 0.12)
		b.border_color = [Color(0.2, 0.23, 0.32), Color(0.95, 0.55, 0.4), Color(0.3, 0.3, 0.35), Color(0.3, 0.7, 0.9), Color(0.85, 0.4, 0.4)][s]
		_boxes[s] = b
	return _boxes[s]


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(_box(state), r)
	var font := get_theme_default_font()
	var c := Vector2(size.x * 0.5, 70)
	draw_circle(c, 44, Color.from_hsv(float(hero_id.hash() % 100) / 100.0, 0.45, 0.8, 0.3 if state == St.BANNED else 1.0))
	draw_string(font, c + Vector2(-12, 14), hero_name.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.05, 0.06, 0.09))
	draw_string(font, Vector2(8, 150), hero_name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 26, Color(0.92, 0.93, 0.96))
	draw_string(font, Vector2(8, 178), tag, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 22, Color(0.6, 0.64, 0.74))
	match state:
		St.BANNED:
			draw_line(c + Vector2(-34, -34), c + Vector2(34, 34), Color(0.9, 0.35, 0.35), 6.0)
			draw_line(c + Vector2(34, -34), c + Vector2(-34, 34), Color(0.9, 0.35, 0.35), 6.0)
			draw_string(font, Vector2(size.x - 62, 30), "BAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.9, 0.35, 0.35))
		St.YOU:
			draw_arc(Vector2(size.x - 24, 26), 12, 0.0, TAU, 24, Color(0.3, 0.7, 0.9), 4.0)
		St.THEM:
			var pts := PackedVector2Array()
			for i in 7:
				pts.append(Vector2(size.x - 24, 26) + Vector2(13, 0).rotated(float(i) * TAU / 6.0))
			draw_polyline(pts, Color(0.85, 0.4, 0.4), 4.0)
		St.SELECTED:
			draw_string(font, Vector2(size.x - 62, 30), "OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.55, 0.4))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (e as InputEventMouseButton).pressed:
			_down = true
		elif _down:
			_down = false
			if Rect2(Vector2.ZERO, size).has_point((e as InputEventMouseButton).position):
				tapped.emit(hero_id)
