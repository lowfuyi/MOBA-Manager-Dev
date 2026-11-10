class_name IconHook
extends RefCounted
## PLACEHOLDER HOOK for icons (build plan I-07; I-09 wires it to src/ui/art/icons.gd, which I-05 builds).
## Every component draws its icons through IconHook.draw(canvas_item, id, rect, colour). Until art/ exists the
## simple line shapes below are drawn so the gallery shows real, non-empty marks. To wire the real icons, set
##   IconHook.draw_fn = func(ci, id, rect, colour): Icons.draw(ci, id, rect, colour)
## once at start-up. Icon ids the components use (the art helper must answer all of them):
##   chevron_down, chevron_right, chevron_up, check, cross, lock, arrow_up, arrow_down, arrow_flat, warn, dot, star.
## Any other id draws a ring. Icons are drawn shapes, never typed characters (the font has none, ART-BIBLE 5.1).

const IDS := ["chevron_down", "chevron_right", "chevron_up", "check", "cross", "lock", "arrow_up", "arrow_down",
		"arrow_flat", "warn", "dot", "star"]

## The ids of src/ui/art/icons.gd (I-05) where they differ from the ones above. I-09 wires it with
##   IconHook.draw_fn = func(ci, id, rect, colour): Icons.draw(ci, IconHook.art_id(id), rect, colour)
## ("dot" has no art icon yet: ask E for one, or keep the placeholder for that id).
const ART_IDS := {"chevron_down": "chevron_d", "chevron_up": "chevron_u", "chevron_right": "chevron_r", "check": "tick", "warn": "warning"}


static func art_id(id: String) -> String:
	return String(ART_IDS.get(id, id))


## Callable(ci: CanvasItem, id: String, rect: Rect2, colour: Color) -> void. Invalid = use the placeholder.
static var draw_fn: Callable = Callable()


static func draw(ci: CanvasItem, id: String, rect: Rect2, colour: Color) -> void:
	if draw_fn.is_valid():
		draw_fn.call(ci, id, rect, colour)
	else:
		placeholder(ci, id, rect, colour)


static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x * r.size.x, y * r.size.y)


static func placeholder(ci: CanvasItem, id: String, r: Rect2, c: Color) -> void:
	var w := maxf(2.0, minf(r.size.x, r.size.y) * 0.11)
	match id:
		"chevron_down":
			ci.draw_polyline(PackedVector2Array([_p(r, 0.24, 0.38), _p(r, 0.5, 0.64), _p(r, 0.76, 0.38)]), c, w, true)
		"chevron_up":
			ci.draw_polyline(PackedVector2Array([_p(r, 0.24, 0.62), _p(r, 0.5, 0.36), _p(r, 0.76, 0.62)]), c, w, true)
		"chevron_right":
			ci.draw_polyline(PackedVector2Array([_p(r, 0.38, 0.24), _p(r, 0.64, 0.5), _p(r, 0.38, 0.76)]), c, w, true)
		"check":
			ci.draw_polyline(PackedVector2Array([_p(r, 0.2, 0.54), _p(r, 0.42, 0.74), _p(r, 0.8, 0.3)]), c, w * 1.1, true)
		"cross":
			ci.draw_line(_p(r, 0.26, 0.26), _p(r, 0.74, 0.74), c, w, true)
			ci.draw_line(_p(r, 0.74, 0.26), _p(r, 0.26, 0.74), c, w, true)
		"lock":
			ci.draw_rect(Rect2(_p(r, 0.24, 0.46), Vector2(0.52 * r.size.x, 0.38 * r.size.y)), c)
			ci.draw_arc(_p(r, 0.5, 0.46), 0.17 * r.size.x, PI, TAU, 12, c, w, true)
		"arrow_up":
			ci.draw_line(_p(r, 0.5, 0.82), _p(r, 0.5, 0.2), c, w, true)
			ci.draw_polyline(PackedVector2Array([_p(r, 0.26, 0.44), _p(r, 0.5, 0.2), _p(r, 0.74, 0.44)]), c, w, true)
		"arrow_down":
			ci.draw_line(_p(r, 0.5, 0.18), _p(r, 0.5, 0.8), c, w, true)
			ci.draw_polyline(PackedVector2Array([_p(r, 0.26, 0.56), _p(r, 0.5, 0.8), _p(r, 0.74, 0.56)]), c, w, true)
		"arrow_flat":
			ci.draw_line(_p(r, 0.2, 0.5), _p(r, 0.8, 0.5), c, w, true)
		"warn":
			ci.draw_polyline(PackedVector2Array([_p(r, 0.5, 0.14), _p(r, 0.88, 0.8), _p(r, 0.12, 0.8), _p(r, 0.5, 0.14)]), c, w * 0.8, true)
			ci.draw_line(_p(r, 0.5, 0.4), _p(r, 0.5, 0.58), c, w * 0.8, true)
			ci.draw_circle(_p(r, 0.5, 0.7), w * 0.5, c)
		"dot":
			ci.draw_circle(r.get_center(), minf(r.size.x, r.size.y) * 0.18, c)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var rad := 0.4 if i % 2 == 0 else 0.17
				var a := -PI / 2.0 + float(i) * PI / 5.0
				pts.append(r.get_center() + Vector2(cos(a), sin(a)) * rad * minf(r.size.x, r.size.y))
			ci.draw_colored_polygon(pts, c)
		_:
			ci.draw_arc(r.get_center(), minf(r.size.x, r.size.y) * 0.3, 0.0, TAU, 20, c, w, true)
