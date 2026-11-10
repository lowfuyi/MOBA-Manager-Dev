class_name Avatar
extends RefCounted
## Players are people, not heroes: until a human artist paints them, an initial avatar (ART-BIBLE 6.2). A circle with the role
## ring, a role-colour wash (55 percent into the page colour, a small hue shift from the player id so a squad is not five
## identical discs), the first letter of the name in TEXT, and the role glyph in a dark chip at the lower right.
## No faces. Built from the portrait atlas (Silhouette), so an avatar is three quads of one texture plus the letter.
##
## The two side tokens of the match are here too (ART-BIBLE 3.8): `draw_token`: you are a TEAL CIRCLE, they are a CORAL
## HEXAGON, a letter inside; shape carries the side, so it still reads in greyscale and for colour-blind players.

const WASH_MIX := 0.55


## The wash colour of a player: the role colour mixed 55 percent into the page colour, hue shifted by up to 8 degrees from the id.
static func wash(player_id: String, role: String) -> Color:
	var h := BadgeStyle.fnv1a(player_id)
	var shift := float((h >> 5) % 17) - 8.0
	var c := ArtPalette.BG.lerp(ArtPalette.role_color(role), WASH_MIX)
	c.h = fposmod(c.h + shift / 360.0, 1.0)
	return c


static func initial_of(player_name: String, player_id: String) -> String:
	var s := player_name.strip_edges()
	if s == "":
		s = player_id
	return s.substr(0, 1).to_upper()


## opts: name (String), role ("top".."sup"), glyph (bool, default true: the role glyph at the lower right), font (Font),
## banned/off (bool: dim, ring TEXT_OFF).
static func draw(ci: CanvasItem, player_id: String, rect: Rect2, opts: Dictionary = {}) -> void:
	var role := str(opts.get("role", "mid"))
	if not ArtPalette.ROLES.has(role):
		role = "mid"
	var off := bool(opts.get("off", false))
	var ring_col := ArtPalette.TEXT_OFF if off else ArtPalette.role_color(role)
	var tint := wash(player_id, role) * (Color(0.6, 0.6, 0.65, 1.0) if off else Color.WHITE)
	var small := rect.size.x <= 64.0
	var a := Silhouette.atlas()
	var rects: Dictionary = a["rects"]
	var c := rect.get_center()
	var rad := rect.size.x * 0.5
	if (a["failed"] as Array).is_empty():
		var tex: Texture2D = a["tex"]
		ci.draw_texture_rect_region(tex, rect, rects["disc"], tint)
		ci.draw_texture_rect_region(tex, rect, rects["ring7" if small else "ring5"], ring_col)
		ci.draw_texture_rect_region(tex, rect, rects["dark"], ArtPalette.VOID)
	else:
		ci.draw_circle(c, rad, tint)
		ci.draw_arc(c, rad * 0.9, 0.0, TAU, 40, ring_col, rect.size.x * (0.07 if small else 0.052), true)
	var font: Font = opts["font"] if opts.has("font") else ThemeDB.fallback_font
	var size := int(roundf(rect.size.x * 0.46))
	var letter := initial_of(str(opts.get("name", "")), player_id)
	ci.draw_string(font, Vector2(rect.position.x, c.y + float(size) * 0.36), letter, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, ArtPalette.TEXT)
	if bool(opts.get("glyph", true)):
		var d := clampf(rect.size.x * 0.34, 20.0, 30.0)
		var cc := rect.end - Vector2(d * 0.5, d * 0.5) - Vector2(rect.size.x * 0.04, rect.size.x * 0.04)
		ci.draw_circle(cc, d * 0.5, ArtPalette.VOID)
		ci.draw_arc(cc, d * 0.5 - 0.75, 0.0, TAU, 24, ring_col, 1.5, true)
		var g := d * 0.77
		Icons.draw(ci, Icons.role_id(role), Rect2(cc - Vector2(g, g) * 0.5, Vector2(g, g)), ring_col)


## The points of a flat-top hexagon with point-to-point width `w` around `c`.
static func hexagon_points(c: Vector2, w: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 6:
		var a := PI / 3.0 * float(i)
		out.append(c + Vector2(cos(a), sin(a)) * (w * 0.5))
	return out


## A side token at `c`. `d` is the circle's diameter (40, or 36 in big fights); the hexagon is 1.1 x wider (same area).
## mine = teal circle, INK_TEAL letter; theirs = coral flat-top hexagon, INK_CORAL letter. 3 px TEXT rim at 70 percent.
static func draw_token(ci: CanvasItem, mine: bool, c: Vector2, d: float, letter: String, font: Font = null) -> void:
	var rim := Color(ArtPalette.TEXT.r, ArtPalette.TEXT.g, ArtPalette.TEXT.b, 0.7)
	var f: Font = font if font != null else ThemeDB.fallback_font
	if mine:
		ci.draw_circle(c, d * 0.5, ArtPalette.ACCENT)
		ci.draw_arc(c, d * 0.5 - 1.5, 0.0, TAU, 32, rim, 3.0, true)
	else:
		var pts := hexagon_points(c, d * 1.1)
		ci.draw_colored_polygon(pts, ArtPalette.CORAL)
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, rim, 3.0, true)
	var size := int(roundf(d * 0.6))
	ci.draw_string(f, Vector2(c.x - d * 0.5, c.y + float(size) * 0.36), letter, HORIZONTAL_ALIGNMENT_CENTER, d, size, ArtPalette.INK_TEAL if mine else ArtPalette.INK_CORAL)
