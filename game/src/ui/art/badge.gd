class_name Badge
extends RefCounted
## Draws a club badge (ART-BIBLE 6.3) from a BadgeStyle: shadow, body in the club primary, a pattern in the secondary, a
## soft gloss, a 3 px white 35 percent rim and the ink initial. All code, no texture: the layers are polygons in a 100 x 100
## box, computed once per club and cached. `layers()` is pure geometry (headless-testable, and `raster()` turns it into an
## Image for the distinctness tests); `draw()` and `draw_batch()` put it on a CanvasItem.
##
## Draw calls: the shapes of any number of badges are untextured and batch into one call; the letters are glyphs of one font
## atlas and are one more. `draw_batch()` therefore draws all shapes first and all letters second (2 calls for a whole
## gallery); `draw()` for a single badge is 2 calls (shapes, letter).

const BOX := 100.0
## letter size (fraction of the box), centre y of the capital letter, per shape (diamond and banner have less room)
const LETTER := {"shield": [0.58, 44.0], "roundel": [0.64, 50.0], "hexagon": [0.60, 50.0], "diamond": [0.46, 50.0], "banner": [0.50, 38.0], "arch": [0.60, 54.0]}
const CAP_H := 0.70     # capital height of the badge font as a fraction of its size (Barlow Semi Condensed: 0.70)

static var _cache: Dictionary = {}
static var cache_hits := 0
static var cache_misses := 0


static func reset_cache() -> void:
	_cache.clear()
	cache_hits = 0
	cache_misses = 0


# ---- geometry (100 x 100 box) --------------------------------------------------------------------------------------

static func _quad(p0: Vector2, c: Vector2, p1: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var u := 1.0 - t
		out.append(p0 * (u * u) + c * (2.0 * u * t) + p1 * (t * t))
	return out


static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 40) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func shape_polygon(shape_name: String) -> PackedVector2Array:
	match shape_name:
		"shield":
			var p := PackedVector2Array([Vector2(10, 8), Vector2(90, 8), Vector2(90, 48)])
			p.append_array(_quad(Vector2(90, 48), Vector2(88, 78), Vector2(50, 95), 10))
			p.append_array(_quad(Vector2(50, 95), Vector2(12, 78), Vector2(10, 48), 10))
			return p
		"roundel":
			return _ellipse(Vector2(50, 50), 44.0, 44.0, 48)
		"hexagon":
			return PackedVector2Array([Vector2(50, 4), Vector2(90, 27), Vector2(90, 73), Vector2(50, 96), Vector2(10, 73), Vector2(10, 27)])
		"diamond":
			return PackedVector2Array([Vector2(50, 3), Vector2(95, 50), Vector2(50, 97), Vector2(5, 50)])
		"banner":
			return PackedVector2Array([Vector2(12, 5), Vector2(88, 5), Vector2(88, 95), Vector2(50, 79), Vector2(12, 95)])
		"arch":
			var p := PackedVector2Array([Vector2(10, 95), Vector2(10, 46)])
			for i in range(1, 24):
				var a := PI + PI * float(i) / 24.0
				p.append(Vector2(50, 46) + Vector2(cos(a), sin(a)) * 40.0)
			p.append(Vector2(90, 46))
			p.append(Vector2(90, 95))
			return p
	return _ellipse(Vector2(50, 50), 44.0, 44.0, 48)


## Pattern band sizes per shape (box units): the chief reaches down to CHIEF_H, the base starts at BASE_Y. Each is chosen so
## that no pattern touches the initial (ART-BIBLE 3.7 rule 4) but is as large as the shape allows: a band on a pointed top
## (hexagon, diamond) is a small triangle, so it must be deep to show in greyscale.
const CHIEF_H := {"shield": 22.0, "roundel": 27.0, "hexagon": 27.0, "diamond": 30.0, "banner": 19.0, "arch": 30.0}
const BASE_Y := {"shield": 68.0, "roundel": 73.0, "hexagon": 71.0, "diamond": 69.0, "banner": 74.0, "arch": 75.0}


## Pattern regions (before clipping to the shape).
static func pattern_polygons(pattern_name: String, shape_name: String = "roundel") -> Array:
	match pattern_name:
		"chief":
			var h: float = CHIEF_H.get(shape_name, 22.0)
			return [PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, h), Vector2(0, h)])]
		"base":
			var y: float = BASE_Y.get(shape_name, 75.0)
			return [PackedVector2Array([Vector2(0, y), Vector2(100, y), Vector2(100, 100), Vector2(0, 100)])]
		"chevron":
			if shape_name == "banner":    # a V that follows the swallowtail notch (a downward V would be cut away by it)
				return [PackedVector2Array([Vector2(0, 75), Vector2(50, 59), Vector2(100, 75), Vector2(100, 89), Vector2(50, 73), Vector2(0, 89)])]
			return [PackedVector2Array([Vector2(0, 71), Vector2(50, 89), Vector2(100, 71), Vector2(100, 85), Vector2(50, 103), Vector2(0, 85)])]
	return []


## The box of the initial (centre line, capital height) per shape, for the "no pattern reaches the letter" rule.
static func letter_box(shape_name: String) -> Rect2:
	var spec: Array = LETTER[shape_name]
	var cap := CAP_H * float(spec[0]) * BOX
	var half_w := 0.36 * float(spec[0]) * BOX      # a wide capital is about 0.72 em
	return Rect2(Vector2(50.0 - half_w, float(spec[1]) - cap * 0.5), Vector2(half_w * 2.0, cap))


## The layers of one badge, back to front: [{"poly": PackedVector2Array, "color": Color, "kind": String}], plus "rim"
## (a closed outline, width 3 in box units) last. Cached per style.
static func layers(style: Dictionary) -> Array:
	var ck := "%s|%s|%s" % [style["id"], style["shape_name"], style["pattern_name"]]
	if _cache.has(ck):
		cache_hits += 1
		return _cache[ck]
	cache_misses += 1
	var shape := shape_polygon(style["shape_name"])
	var out: Array = []
	var sh := PackedVector2Array()
	for p in shape:
		sh.append(p + Vector2(0, 3))
	out.append({"poly": sh, "color": Color(0, 0, 0, 0.35), "kind": "shadow"})
	out.append({"poly": shape, "color": style["primary"], "kind": "body"})
	for region in pattern_polygons(style["pattern_name"], style["shape_name"]):
		for clipped in Geometry2D.intersect_polygons(shape, region):
			out.append({"poly": clipped, "color": style["secondary"], "kind": "pattern"})
	# the gloss: the part of the shape inside a soft ellipse at the upper left
	for g in Geometry2D.intersect_polygons(shape, _ellipse(Vector2(34, 22), 34.0, 20.0, 24)):
		out.append({"poly": g, "color": Color(1, 1, 1, 0.14), "kind": "gloss"})
	out.append({"poly": shape, "color": Color(1, 1, 1, 0.35), "kind": "rim"})
	_cache[ck] = out
	return out


## A tiny CPU render of the shape layers (no letter, no shadow) for headless tests: px x px RGBA on a transparent ground.
static func raster(style: Dictionary, px: int) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var k := BOX / float(px)
	var lay := layers(style)
	for y in px:
		for x in px:
			var p := Vector2((x + 0.5) * k, (y + 0.5) * k)
			var c := Color(0, 0, 0, 0)
			for l in lay:
				var kind: String = l["kind"]
				if kind == "shadow" or kind == "gloss":
					continue
				if kind == "rim":
					continue
				if Geometry2D.is_point_in_polygon(p, l["poly"]):
					c = l["color"]
			img.set_pixel(x, y, c)
	return img


# ---- drawing -------------------------------------------------------------------------------------------------------

static func _style_of(club: Variant) -> Dictionary:
	if club is Dictionary:
		return club
	return BadgeStyle.for_club(str(club))


static func _initial(club_name: String, club_id: String) -> String:
	var s := club_name.strip_edges()
	if s == "":
		s = club_id
	return s.substr(0, 1).to_upper()


static func _scaled(poly: PackedVector2Array, o: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i in poly.size():
		out[i] = o + poly[i] * k
	return out


## Pass 1: the shapes (untextured).
static func draw_shapes(ci: CanvasItem, club: Variant, rect: Rect2) -> void:
	var style := _style_of(club)
	var k := minf(rect.size.x, rect.size.y) / BOX
	var o := rect.position
	for l in layers(style):
		var poly := _scaled(l["poly"], o, k)
		if l["kind"] == "rim":
			var closed := poly.duplicate()
			closed.append(poly[0])
			ci.draw_polyline(closed, l["color"], maxf(1.5, 3.0 * k), true)
		else:
			ci.draw_colored_polygon(poly, l["color"])


## Pass 2: the initial (glyphs).
static func draw_letter(ci: CanvasItem, club: Variant, club_name: String, rect: Rect2, font: Font = null) -> void:
	var style := _style_of(club)
	var f: Font = font if font != null else ThemeDB.fallback_font
	var spec: Array = LETTER[style["shape_name"]]
	var k := minf(rect.size.x, rect.size.y) / BOX
	var size := float(spec[0]) * BOX * k
	var base := rect.position.y + (float(spec[1]) + CAP_H * float(spec[0]) * BOX * 0.5) * k
	ci.draw_string(f, Vector2(rect.position.x, base), _initial(club_name, str(style["id"])), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, int(roundf(size)), style["ink"])


## One badge: its shapes, then its letter (2 draw calls).
static func draw(ci: CanvasItem, club: Variant, club_name: String, rect: Rect2, font: Font = null) -> void:
	draw_shapes(ci, club, rect)
	draw_letter(ci, club, club_name, rect, font)


## Many badges in two passes (all shapes, then all letters): items = [{"club": id or style, "name": String, "rect": Rect2}].
static func draw_batch(ci: CanvasItem, items: Array, font: Font = null) -> void:
	for it in items:
		draw_shapes(ci, it["club"], it["rect"])
	for it in items:
		draw_letter(ci, it["club"], str(it["name"]), it["rect"], font)
