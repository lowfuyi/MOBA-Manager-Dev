extends Control
## S4 variant B2: one Control per card, but every shape comes from the shared atlas (hero_atlas.gd), so a card is
## two draw batches (atlas run, then text run) instead of five or six. Same API as hero_card_probe.gd.
signal tapped(hero_id: String)
const Atlas := preload("res://tests/spikes/hero_atlas.gd")
enum St { AVAILABLE, SELECTED, BANNED, YOU, THEM }
var hero_id := ""
var hero_name := ""
var tag := ""
var role := ""
var state: int = St.AVAILABLE
var _down := false
var _press_g := Vector2.ZERO
const TAP_SLOP := 12.0            # a press that moved more than this (screen px) is a drag, not a tap
var single_size := false          # name and tag at one font size and no initial letter: one text run per card


func setup(id: String, nm: String, tg: String, rl: String, w: float) -> void:
	hero_id = id
	hero_name = nm
	tag = tg
	role = rl
	custom_minimum_size = Vector2(w, 190)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_state(s: int) -> void:
	if s == state:
		return
	state = s
	queue_redraw()


func _draw() -> void:
	var t := Atlas.get_tex()
	var kind := "normal" if state != St.SELECTED and state != St.BANNED else ("selected" if state == St.SELECTED else "banned")
	draw_style_box(Atlas.card_box(kind), Rect2(Vector2.ZERO, size))
	var hue := Color.from_hsv(float(hero_id.hash() % 100) / 100.0, 0.45, 0.8, 0.3 if state == St.BANNED else 1.0)
	var c := Vector2(size.x * 0.5, 70)
	draw_texture_rect_region(t, Rect2(c - Vector2(44, 44), Vector2(88, 88)), Atlas.DISC, hue)
	match state:
		St.BANNED:
			draw_texture_rect_region(t, Rect2(c - Vector2(34, 34), Vector2(68, 68)), Atlas.XMARK, Color(0.9, 0.35, 0.35))
		St.YOU:
			draw_texture_rect_region(t, Rect2(size.x - 40, 10, 32, 32), Atlas.RING, Color(0.3, 0.7, 0.9))
		St.THEM:
			draw_texture_rect_region(t, Rect2(size.x - 40, 10, 32, 32), Atlas.HEX, Color(0.85, 0.4, 0.4))
	var font := get_theme_default_font()
	if not single_size:
		draw_string(font, c + Vector2(-12, 14), hero_name.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.05, 0.06, 0.09))
	draw_string(font, Vector2(8, 150), hero_name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 26, Color(0.92, 0.93, 0.96))
	draw_string(font, Vector2(8, 178), tag, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 26 if single_size else 22, Color(0.6, 0.64, 0.74))
	if state == St.BANNED:
		draw_string(font, Vector2(size.x - 62, 30), "BAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 26 if single_size else 22, Color(0.9, 0.35, 0.35))
	elif state == St.SELECTED:
		draw_string(font, Vector2(size.x - 62, 30), "OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 26 if single_size else 22, Color(0.95, 0.55, 0.4))


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_down = true
			_press_g = mb.global_position
		elif _down:
			_down = false
			if mb.global_position.distance_to(_press_g) <= TAP_SLOP:     # page scrolls move the card under the finger: use screen distance
				tapped.emit(hero_id)
