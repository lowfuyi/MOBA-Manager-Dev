extends Control
## S4 variant C: ONE Control draws the whole 40-hero grid in three passes (all card backgrounds, then all discs and
## marks, then all text), so the atlas shapes batch into one run and the text into another. It owns hit-testing, the
## same rule S1 found for the Carousel. Variant C trades the "one HeroCard node per hero" of the plan for the lowest
## draw-call and node count; per-hero state is plain data (set_state), only a change redraws.
signal tapped(hero_id: String)
const Atlas := preload("res://tests/spikes/hero_atlas.gd")
var heroes: Array = []                   # {id, name, tag, role, role2}
var states: Array = []
var shown: Array = []                    # indexes currently visible (the role filter)
var columns := 3
var card := Vector2(183, 190)
var gap := 10.0
var _press_g := Vector2.ZERO
var _press_slot := -1
const TAP_SLOP := 12.0            # a press that moved more than this (screen px) is a drag, not a tap


func setup(list: Array, cols: int, w: float) -> void:
	for h in list:
		heroes.append({"id": h["id"], "name": h["name"], "tag": (h["tags"][0] as String) if (h["tags"] as Array).size() > 0 else "",
				"role": h["role_primary"], "role2": h["role_secondary"]})
		states.append(0)
	columns = cols
	card = Vector2(w, 190)
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_filter("")


func set_filter(role: String) -> void:
	var n: Array = []
	for i in heroes.size():
		if role == "" or heroes[i]["role"] == role or heroes[i]["role2"] == role:
			n.append(i)
	if n == shown:
		return
	shown = n
	var rows := int(ceil(float(shown.size()) / float(columns)))
	custom_minimum_size = Vector2(columns * (card.x + gap) - gap, maxf(0.0, rows * (card.y + gap) - gap))
	queue_redraw()


func set_state(i: int, s: int) -> void:
	if states[i] == s:
		return
	states[i] = s
	queue_redraw()


func _cell(slot: int) -> Rect2:
	return Rect2(Vector2((slot % columns) * (card.x + gap), (slot / columns) * (card.y + gap)), card)


func _draw() -> void:
	var t := Atlas.get_tex()
	var font := get_theme_default_font()
	for slot in shown.size():                                            # pass 1: backgrounds (one 9-slice atlas run)
		var st: int = states[shown[slot]]
		var kind := "selected" if st == 1 else ("banned" if st == 2 else "normal")
		draw_style_box(Atlas.card_box(kind), _cell(slot))
	for slot in shown.size():                                            # pass 2: discs and marks (same atlas)
		var h: Dictionary = heroes[shown[slot]]
		var st: int = states[shown[slot]]
		var r := _cell(slot)
		var c := r.position + Vector2(r.size.x * 0.5, 70)
		var hue := Color.from_hsv(float((h["id"] as String).hash() % 100) / 100.0, 0.45, 0.8, 0.3 if st == 2 else 1.0)
		draw_texture_rect_region(t, Rect2(c - Vector2(44, 44), Vector2(88, 88)), Atlas.DISC, hue)
		match st:
			2:
				draw_texture_rect_region(t, Rect2(c - Vector2(34, 34), Vector2(68, 68)), Atlas.XMARK, Color(0.9, 0.35, 0.35))
			3:
				draw_texture_rect_region(t, Rect2(r.end.x - 40, r.position.y + 10, 32, 32), Atlas.RING, Color(0.3, 0.7, 0.9))
			4:
				draw_texture_rect_region(t, Rect2(r.end.x - 40, r.position.y + 10, 32, 32), Atlas.HEX, Color(0.85, 0.4, 0.4))
	# pass 3: text, grouped by font size (one glyph texture per size, so one run per size instead of one per card)
	for slot in shown.size():
		var r := _cell(slot)
		var c := r.position + Vector2(r.size.x * 0.5, 70)
		draw_string(font, c + Vector2(-12, 14), (heroes[shown[slot]]["name"] as String).substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.05, 0.06, 0.09))
	for slot in shown.size():
		var r := _cell(slot)
		draw_string(font, r.position + Vector2(8, 150), heroes[shown[slot]]["name"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16, 26, Color(0.92, 0.93, 0.96))
	for slot in shown.size():
		var r := _cell(slot)
		draw_string(font, r.position + Vector2(8, 178), heroes[shown[slot]]["tag"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16, 22, Color(0.6, 0.64, 0.74))
		var st: int = states[shown[slot]]
		if st == 2:
			draw_string(font, r.position + Vector2(r.size.x - 62, 30), "BAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.9, 0.35, 0.35))
		elif st == 1:
			draw_string(font, r.position + Vector2(r.size.x - 62, 30), "OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.95, 0.55, 0.4))


func _slot_at(p: Vector2) -> int:
	for slot in shown.size():
		if _cell(slot).has_point(p):
			return slot
	return -1


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_press_g = mb.global_position
			_press_slot = _slot_at(mb.position)               # the card under the finger at the moment of the press
		else:
			if _press_slot >= 0 and mb.global_position.distance_to(_press_g) <= TAP_SLOP:
				tapped.emit(heroes[shown[_press_slot]]["id"])
			_press_slot = -1
