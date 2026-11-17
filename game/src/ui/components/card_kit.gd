class_name CardKit
extends RefCounted
## Drawing kit shared by the picture-led cards (build plan I-09: PlayerCard, HeroCard/HeroGrid, LaneRow/LaneBoard).
## A card is drawn in PASSES by texture, never card by card, because in the Compatibility renderer every texture switch
## is one more draw call (SPIKE-RESULTS-0.7 S4): all the 9-slice backgrounds and shape cells come from ONE small atlas
## of this kit ("cards@1": card, ring, pill, pill ring, disc, hexagon, solid; baked from SVG strings through TexCache), the
## portraits and avatars from the portrait atlas of Silhouette (I-05), the icons from the icon atlas of Icons (I-05), and
## text is grouped by font and size. Every quad of one pass is one batch.
## Everything here is static and draws into a CanvasItem; nothing holds a node. If the SVG loader fails (never seen on the
## desktop, unverified on a phone) every call falls back to plain StyleBoxFlat / draw_circle shapes: correct, more draw calls.

const ATLAS := "cards@1"
const PAD := 2                    # transparent border round every cell, so a scaled quad never samples a neighbour cell
const WIDTH := 512
const CARD_MARGIN := 24           # = UI.R_CARD
const PILL_H := 44

static var _a: Dictionary = {}
static var _boxes: Dictionary = {}
static var _box_tex: Texture2D = null
static var _fit: Dictionary = {}
## How many texts were cut with "..." since reset_counters() (tests read it; a card never cuts a hero or player name in the fixtures).
static var clipped_count := 0


static func reset_counters() -> void:
	clipped_count = 0


# ---- the atlas ----------------------------------------------------------------------------------------------------------

static func _svg(w: int, body: String) -> String:
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">%s</svg>" % [w, w, w, w, body]


static func _hex_points(cx: float, cy: float, r: float) -> String:
	var s := ""
	for i in 6:
		var a := PI / 3.0 * float(i)
		s += "%.2f,%.2f " % [cx + cos(a) * r, cy + sin(a) * r]
	return s


static func cells() -> Array:
	var p := float(PAD)
	var out: Array = []
	out.append({"key": "card", "box": 68.0, "w": 68, "svg": _svg(68, "<rect x=\"%.1f\" y=\"%.1f\" width=\"64\" height=\"64\" rx=\"24\" fill=\"#FFFFFF\"/>" % [p, p])})
	out.append({"key": "ring", "box": 68.0, "w": 68, "svg": _svg(68, "<rect x=\"%.1f\" y=\"%.1f\" width=\"61\" height=\"61\" rx=\"22.5\" fill=\"none\" stroke=\"#FFFFFF\" stroke-width=\"3\"/>" % [p + 1.5, p + 1.5])})
	out.append({"key": "pill", "box": 48.0, "w": 48, "svg": _svg(48, "<rect x=\"%.1f\" y=\"%.1f\" width=\"44\" height=\"44\" rx=\"22\" fill=\"#FFFFFF\"/>" % [p, p])})
	out.append({"key": "pillring", "box": 48.0, "w": 48, "svg": _svg(48, "<rect x=\"%.2f\" y=\"%.2f\" width=\"42.5\" height=\"42.5\" rx=\"21.25\" fill=\"none\" stroke=\"#FFFFFF\" stroke-width=\"1.5\"/>" % [p + 0.75, p + 0.75])})
	out.append({"key": "disc", "box": 44.0, "w": 44, "svg": _svg(44, "<circle cx=\"22\" cy=\"22\" r=\"20\" fill=\"#FFFFFF\"/>")})
	out.append({"key": "hex", "box": 48.0, "w": 48, "svg": _svg(48, "<polygon points=\"%s\" fill=\"#FFFFFF\" stroke=\"#FFFFFF\" stroke-width=\"2\" stroke-linejoin=\"round\"/>" % _hex_points(24.0, 24.0, 20.0))})
	out.append({"key": "solid", "box": 12.0, "w": 12, "svg": _svg(12, "<rect x=\"2\" y=\"2\" width=\"8\" height=\"8\" fill=\"#FFFFFF\"/>")})
	return out


static func atlas() -> Dictionary:
	if _a.is_empty() or not TexCache.has(ATLAS):
		_a = TexCache.atlas(ATLAS, [] if TexCache.has(ATLAS) else cells(), WIDTH)
	return _a


static func ok() -> bool:
	return (atlas()["failed"] as Array).is_empty()


## The drawable part of a cell (without its transparent padding).
static func region(key: String) -> Rect2:
	var r: Rect2 = atlas()["rects"][key]
	if key == "solid":
		return Rect2(r.position + Vector2(4, 4), Vector2(4, 4))    # the middle of the square only: pure white, no edge to blur
	return r.grow(-float(PAD))


static func _box(key: String, margin: int, tint: Color) -> StyleBoxTexture:
	var a := atlas()
	if _box_tex != a["tex"]:
		_boxes.clear()
		_box_tex = a["tex"]
	var k := "%s|%s" % [key, tint.to_html(true)]
	if _boxes.has(k):
		return _boxes[k]
	var sb := StyleBoxTexture.new()
	sb.texture = a["tex"]
	sb.region_rect = region(key)
	sb.set_texture_margin_all(margin)
	sb.modulate_color = tint
	_boxes[k] = sb
	return sb


# ---- shapes (pass 0: one run of the cards atlas) --------------------------------------------------------------------------

## A 9-slice background: kind "card" (radius 24), "ring" (3 px outline, radius 24), "pill" (radius 22, 44 high),
## "pillring" (1.5 px outline). `tint` colours it (white cells).
static func bg(ci: CanvasItem, kind: String, rect: Rect2, tint: Color) -> void:
	if tint.a <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if ok():
		ci.draw_style_box(_box(kind, CARD_MARGIN if kind == "card" or kind == "ring" else 22, tint), rect)
		return
	match kind:
		"ring":
			ci.draw_style_box(UI.box(Color(0, 0, 0, 0), UI.R_CARD, 0, tint, 3), rect)
		"pillring":
			ci.draw_style_box(UI.box(Color(0, 0, 0, 0), 22, 0, tint, 2), rect)
		"pill":
			ci.draw_style_box(UI.box(tint, 22), rect)
		_:
			ci.draw_style_box(UI.box(tint, UI.R_CARD), rect)


## A disc, a flat-top hexagon (width = rect width) or a solid rectangle, tinted.
static func shape(ci: CanvasItem, kind: String, rect: Rect2, tint: Color) -> void:
	if tint.a <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	if ok():
		ci.draw_texture_rect_region(atlas()["tex"], rect, region(kind), tint)
		return
	match kind:
		"disc":
			ci.draw_circle(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.5, tint)
		"hex":
			ci.draw_colored_polygon(Avatar.hexagon_points(rect.get_center(), rect.size.x), tint)
		_:
			ci.draw_rect(rect, tint)


## A dashed outline (the empty slot) from small solid quads, so it batches with the other shapes (draw_dashed_line is one call
## per edge). Straight edges only; the four corners are left open on purpose.
static func dashed(ci: CanvasItem, rect: Rect2, tint: Color, width: float = 2.0, dash: float = 10.0, gap: float = 7.0, corner: float = 14.0) -> void:
	var x0 := rect.position.x + corner
	var x1 := rect.end.x - corner
	var y0 := rect.position.y + corner
	var y1 := rect.end.y - corner
	var x := x0
	while x < x1:
		var l := minf(dash, x1 - x)
		shape(ci, "solid", Rect2(x, rect.position.y, l, width), tint)
		shape(ci, "solid", Rect2(x, rect.end.y - width, l, width), tint)
		x += dash + gap
	var y := y0
	while y < y1:
		var l2 := minf(dash, y1 - y)
		shape(ci, "solid", Rect2(rect.position.x, y, width, l2), tint)
		shape(ci, "solid", Rect2(rect.end.x - width, y, width, l2), tint)
		y += dash + gap


## The same dashed outline, queued on a display list (Ops) instead of drawn.
static func dashed_ops(ops: Ops, rect: Rect2, tint: Color, width: float = 2.0, dash: float = 10.0, gap: float = 7.0, corner: float = 14.0) -> void:
	var x := rect.position.x + corner
	while x < rect.end.x - corner:
		var l := minf(dash, rect.end.x - corner - x)
		ops.shape("solid", Rect2(x, rect.position.y, l, width), tint)
		ops.shape("solid", Rect2(x, rect.end.y - width, l, width), tint)
		x += dash + gap
	var y := rect.position.y + corner
	while y < rect.end.y - corner:
		var l2 := minf(dash, rect.end.y - corner - y)
		ops.shape("solid", Rect2(rect.position.x, y, width, l2), tint)
		ops.shape("solid", Rect2(rect.end.x - width, y, width, l2), tint)
		y += dash + gap


# ---- portraits and avatars (pass 1: one run of the portrait atlas) ----------------------------------------------------------

## A hero portrait: lit background, role-colour rim light bust, ring, dark outer ring: four quads of the portrait atlas
## (Silhouette.draw_role draws the same picture with a transform and a line; this one only emits quads so it batches).
## `mirror` flips the bust left to right (by transform). `banned` dims it and drops the ring to TEXT_OFF.
static func portrait(ci: CanvasItem, rect: Rect2, role: String, variant: int, hue_shift: float = 0.0, mirror: bool = false, banned: bool = false) -> void:
	var a := Silhouette.atlas()
	if not (a["failed"] as Array).is_empty():
		Silhouette.draw_role(ci, role, variant, rect, hue_shift, mirror, banned, false)
		return
	var rects: Dictionary = a["rects"]
	var tex: Texture2D = a["tex"]
	var dim := Color(0.5, 0.5, 0.55, 1.0) if banned else Color.WHITE
	var ring_col := ArtPalette.TEXT_OFF if banned else ArtPalette.role_color(role)
	ci.draw_texture_rect_region(tex, rect, rects["bg"], Silhouette.bg_tint(role, hue_shift) * dim)
	var bust: Rect2 = rects[Silhouette.key(role, clampi(variant, 0, 2))]
	if mirror:
		# a flip by transform: a negative source width draws NOTHING for a cell that touches the right edge of the atlas (the
		# engine samples at u = 1.0; seen with jungle variant 1 and bot variant 0), so the mirror is a transform instead
		ci.draw_set_transform(Vector2(rect.end.x, rect.position.y), 0.0, Vector2(-1.0, 1.0))
		ci.draw_texture_rect_region(tex, Rect2(Vector2.ZERO, rect.size), bust, dim)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_texture_rect_region(tex, rect, bust, dim)
	ci.draw_texture_rect_region(tex, rect, rects["ring7" if rect.size.x <= 64.0 else "ring5"], ring_col)
	ci.draw_texture_rect_region(tex, rect, rects["dark"], ArtPalette.VOID)


## The initial avatar of a player without its letter: disc, ring, dark ring (the letter is text, drawn in the text pass).
static func avatar(ci: CanvasItem, rect: Rect2, pid: String, role: String, off: bool = false) -> void:
	if not ArtPalette.ROLES.has(role):
		role = "mid"
	var a := Silhouette.atlas()
	var tint := Avatar.wash(pid, role) * (Color(0.6, 0.6, 0.65, 1.0) if off else Color.WHITE)
	var ring_col := ArtPalette.TEXT_OFF if off else ArtPalette.role_color(role)
	if not (a["failed"] as Array).is_empty():
		ci.draw_circle(rect.get_center(), rect.size.x * 0.5, tint)
		ci.draw_arc(rect.get_center(), rect.size.x * 0.45, 0.0, TAU, 40, ring_col, rect.size.x * 0.052, true)
		return
	var rects: Dictionary = a["rects"]
	var tex: Texture2D = a["tex"]
	ci.draw_texture_rect_region(tex, rect, rects["disc"], tint)
	ci.draw_texture_rect_region(tex, rect, rects["ring7" if rect.size.x <= 64.0 else "ring5"], ring_col)
	ci.draw_texture_rect_region(tex, rect, rects["dark"], ArtPalette.VOID)


## The 32 px corner role chip (dark disc, role rim, role glyph) of ART-BIBLE 6.2, into `rect` (20 to 30 px).
static func role_chip(ci: CanvasItem, rect: Rect2, role: String) -> void:
	Silhouette.draw_chip(ci, role, rect)


# ---- text ---------------------------------------------------------------------------------------------------------------

static func text_w(font: Font, size: int, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## `text` cut with "..." until it fits `room` px (never wraps). Cached.
static func fit(font: Font, size: int, text: String, room: float) -> String:
	if text == "" or room <= 0.0:
		return ""
	var key := "%d|%d|%d|%s" % [font.get_instance_id(), size, int(room), text]
	if _fit.has(key):
		return _fit[key]
	var out := text
	if text_w(font, size, text) > room + 0.5:
		var n := text.length()
		while n > 1 and text_w(font, size, text.substr(0, n) + "...") > room:
			n -= 1
		out = text.substr(0, maxi(1, n)) + "..."
	_fit[key] = out
	return out


## The baseline that puts a line of `size` px text with its middle at `cy`.
static func baseline(font: Font, size: int, cy: float) -> float:
	return cy + (font.get_ascent(size) - font.get_descent(size)) * 0.5


## One line of text in a room: align 0 left of `x`, 1 centred on the room that starts at x, 2 right-aligned to x + room.
## Returns true when it had to be cut.
static func text(ci: CanvasItem, font: Font, size: int, s: String, x: float, cy: float, room: float, col: Color, align: int = 0) -> bool:
	var shown := fit(font, size, s, room)
	var w := text_w(font, size, shown)
	var px := x
	if align == 1:
		px = x + (room - w) * 0.5
	elif align == 2:
		px = x + room - w
	ci.draw_string(font, Vector2(px, baseline(font, size, cy)), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	var cut := shown != s
	if cut:
		clipped_count += 1
	return cut


# ---- the display list: a card queues what it draws, then flushes it in passes ------------------------------------------------

class Ops extends RefCounted:
	var bgs: Array = []          # [kind, rect, tint, is_shape]
	var portraits: Array = []    # ["avatar", rect, pid, role, off] | ["hero", rect, role, variant, hue, mirror, banned] | ["chip", rect, role]
	var icons: Array = []        # [id, rect, colour]
	var texts: Array = []        # [font, size, text, x, cy, room, colour, align, outline_colour or null]
	var clipped: Array = []      # the texts that were cut

	func clear() -> void:
		bgs.clear()
		portraits.clear()
		icons.clear()
		texts.clear()
		clipped.clear()

	func bg(kind: String, rect: Rect2, tint: Color) -> void:
		bgs.append([kind, rect, tint, false])

	func shape(kind: String, rect: Rect2, tint: Color) -> void:
		bgs.append([kind, rect, tint, true])

	func icon(id: String, rect: Rect2, col: Color) -> void:
		icons.append([id, rect, col])

	func text(font: Font, size: int, s: String, x: float, cy: float, room: float, col: Color, align: int = 0, outline: Variant = null) -> void:
		texts.append([font, size, s, x, cy, room, col, align, outline])

	## Add everything `other` queued, moved by `d` (a child's display list drawn by its parent in one pass).
	func append_shifted(other: Ops, d: Vector2) -> void:
		for b in other.bgs:
			bgs.append([b[0], Rect2((b[1] as Rect2).position + d, (b[1] as Rect2).size), b[2], b[3]])
		for p in other.portraits:
			var q: Array = (p as Array).duplicate()
			q[1] = Rect2((p[1] as Rect2).position + d, (p[1] as Rect2).size)
			portraits.append(q)
		for ic in other.icons:
			icons.append([ic[0], Rect2((ic[1] as Rect2).position + d, (ic[1] as Rect2).size), ic[2]])
		for t in other.texts:
			var u: Array = (t as Array).duplicate()
			u[3] = float(t[3]) + d.x
			u[4] = float(t[4]) + d.y
			texts.append(u)

	func flush(ci: CanvasItem) -> void:
		for b in bgs:
			if b[3]:
				CardKit.shape(ci, b[0], b[1], b[2])
			else:
				CardKit.bg(ci, b[0], b[1], b[2])
		for p in portraits:
			match String(p[0]):
				"avatar":
					CardKit.avatar(ci, p[1], p[2], p[3], p[4])
				"hero":
					CardKit.portrait(ci, p[1], p[2], p[3], p[4], p[5], p[6])
				"chip":
					CardKit.role_chip(ci, p[1], p[2])
		for ic in icons:
			IconHook.draw(ci, ic[0], ic[1], ic[2])
		var order: Array = []    # (font, size) groups in first-seen order: one glyph texture, one run
		var groups: Dictionary = {}
		for t in texts:
			var k := "%d|%d|%s" % [(t[0] as Font).get_instance_id(), t[1], "o" if t[8] != null else ""]
			if not groups.has(k):
				groups[k] = []
				order.append(k)
			(groups[k] as Array).append(t)
		for k in order:
			for t in groups[k]:
				if t[8] != null:
					var f: Font = t[0]
					var shown := CardKit.fit(f, t[1], t[2], t[5])
					var w := CardKit.text_w(f, t[1], shown)
					var px: float = t[3] + (t[5] - w) * 0.5 if t[7] == 1 else (t[3] + t[5] - w if t[7] == 2 else t[3])
					ci.draw_string_outline(f, Vector2(px, CardKit.baseline(f, t[1], t[4])), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, t[1], 5, t[8])
		for k in order:
			for t in groups[k]:
				if CardKit.text(ci, t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7]):
					clipped.append(t[2])
