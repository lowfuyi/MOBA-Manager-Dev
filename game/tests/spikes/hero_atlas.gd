extends RefCounted
## Shared placeholder atlas for the S4 variants B2 and C: every shape a hero card needs, as tiles of ONE texture, so
## drawing them does not switch textures (switching texture is what breaks a batch in the Compatibility renderer).
## Tiles (x, y, w, h): card_normal (0,0,64,64), card_selected (64,0,64,64), card_banned (128,0,64,64),
## disc (0,64,88,88), x_mark (96,64,40,40), ring (144,64,32,32), hex (184,64,32,32). Cards are 9-slice, margin 24.
## Generated in code; the real build would ship it as a PNG (Engine/Graphics lane).
static var tex: ImageTexture
const CARD := {"normal": Rect2(0, 0, 64, 64), "selected": Rect2(64, 0, 64, 64), "banned": Rect2(128, 0, 64, 64)}
const DISC := Rect2(0, 64, 88, 88)
const XMARK := Rect2(96, 64, 40, 40)
const RING := Rect2(144, 64, 32, 32)
const HEX := Rect2(184, 64, 32, 32)
static var boxes: Dictionary = {}


static func get_tex() -> ImageTexture:
	if tex != null:
		return tex
	var img := Image.create(256, 160, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fills := [Color(0.11, 0.13, 0.19), Color(0.11, 0.13, 0.19), Color(0.08, 0.09, 0.12)]
	var borders := [Color(0.2, 0.23, 0.32), Color(0.95, 0.55, 0.4), Color(0.3, 0.3, 0.35)]
	for t in 3:
		for y in 64:
			for x in 64:
				var q := (Vector2(x + 0.5, y + 0.5) - Vector2(32, 32)).abs() - Vector2(32, 32) + Vector2(20, 20)
				var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 20.0
				var bw := 4.0 if t == 1 else 2.0
				if d < -bw:
					img.set_pixel(t * 64 + x, y, fills[t])
				elif d < 0.0:
					img.set_pixel(t * 64 + x, y, borders[t])
	for y in 88:
		for x in 88:
			if Vector2(x - 43.5, y - 43.5).length() < 44.0:
				img.set_pixel(x, 64 + y, Color.WHITE)
	for i in 40:                                         # the X: two thick diagonals
		for w in 5:
			img.set_pixel(96 + i, 64 + clampi(i + w - 2, 0, 39), Color.WHITE)
			img.set_pixel(96 + i, 64 + clampi(39 - i + w - 2, 0, 39), Color.WHITE)
	for y in 32:                                         # ring
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length()
			if d < 15.0 and d > 11.0:
				img.set_pixel(144 + x, 64 + y, Color.WHITE)
	for y in 32:                                         # hexagon outline (a regular hexagon, flat top)
		for x in 32:
			var p := Vector2(x - 15.5, y - 15.5)
			var hx := maxf(absf(p.x) * 0.866 + absf(p.y) * 0.5, absf(p.y))
			if hx < 15.0 and hx > 11.0:
				img.set_pixel(184 + x, 64 + y, Color.WHITE)
	tex = ImageTexture.create_from_image(img)
	return tex


static func card_box(kind: String) -> StyleBoxTexture:
	if not boxes.has(kind):
		var s := StyleBoxTexture.new()
		s.texture = get_tex()
		s.region_rect = CARD[kind]
		s.set_texture_margin_all(24)
		boxes[kind] = s
	return boxes[kind]
