class_name VecOps
extends RefCounted
## A tiny vector language for the art in code. One list of ops is drawn two ways: as an SVG string (rasterised once by
## TexCache, the normal route) and straight onto a CanvasItem (the fallback when the SVG loader is missing, and for tests).
## Coordinates are in a square "box" (48 for icons, 96 for portraits). Every op ends with a tone name; the caller maps a tone
## to a colour. Angles are degrees, 0 = +x, increasing clockwise on screen (y down), the same as SVG and draw_arc.
##
##   ["l", pts, w, tone]            open stroked line, round caps and joins; pts is a flat [x0, y0, x1, y1, ...]
##   ["L", pts, w, tone]            closed stroked outline
##   ["f", pts, tone]               filled polygon
##   ["R", pts, w, tone]            filled polygon with a round-joined stroke of the same colour (soft corners)
##   ["c", cx, cy, r, tone]         filled circle
##   ["o", cx, cy, r, w, tone]      circle outline
##   ["e", cx, cy, rx, ry, tone]    filled ellipse
##   ["a", cx, cy, r, a0, a1, w, tone]   arc stroke
##   ["b", x0, y0, x1, y1, x2, y2, x3, y3, w, tone]   cubic bezier stroke

static func tone_of(op: Array) -> String:
	return str(op[op.size() - 1])


## Does any op use this tone?
static func has_tone(ops: Array, tone: String) -> bool:
	for op in ops:
		if tone_of(op) == tone:
			return true
	return false


## The ops of one tone set only (e.g. everything but the accent).
static func only(ops: Array, tones: Array) -> Array:
	var out: Array = []
	for op in ops:
		if tones.has(tone_of(op)):
			out.append(op)
	return out


static func shifted(op: Array, dx: float, dy: float, tone: String = "") -> Array:
	var o: Array = op.duplicate(true)
	match str(o[0]):
		"l", "L", "f", "R":
			var pts: Array = o[1]
			for i in range(0, pts.size(), 2):
				pts[i] = float(pts[i]) + dx
				pts[i + 1] = float(pts[i + 1]) + dy
		"c", "o", "e", "a":
			o[1] = float(o[1]) + dx
			o[2] = float(o[2]) + dy
		"b":
			for i in range(1, 9, 2):
				o[i] = float(o[i]) + dx
				o[i + 1] = float(o[i + 1]) + dy
	if tone != "":
		o[o.size() - 1] = tone
	return o


# ---- SVG -----------------------------------------------------------------------------------------------------------

static func _f(v: float) -> String:
	return ("%.2f" % v).rstrip("0").rstrip(".")


static func _pts_d(pts: Array, close: bool) -> String:
	var d := ""
	for i in range(0, pts.size(), 2):
		d += ("M" if i == 0 else "L") + _f(float(pts[i])) + " " + _f(float(pts[i + 1])) + " "
	return d + ("Z" if close else "")


static func _paint(c: Color, stroke_w: float) -> String:
	var hexs := "#%02X%02X%02X" % [int(c.r * 255.0 + 0.5), int(c.g * 255.0 + 0.5), int(c.b * 255.0 + 0.5)]
	var a := "" if c.a >= 0.999 else (" stroke-opacity=\"%s\"" % _f(c.a) if stroke_w > 0.0 else " fill-opacity=\"%s\"" % _f(c.a))
	if stroke_w > 0.0:
		return "fill=\"none\" stroke=\"%s\"%s stroke-width=\"%s\" stroke-linecap=\"round\" stroke-linejoin=\"round\"" % [hexs, a, _f(stroke_w)]
	return "fill=\"%s\"%s" % [hexs, a]


## tones: tone name -> Color (alpha is used). Ops whose tone is not in `tones` are skipped. `clip_circle` clips everything
## to the circle inscribed in the box (portraits).
static func to_svg(ops: Array, box: float, tones: Dictionary, clip_circle: bool = false) -> String:
	var s := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%s\" height=\"%s\" viewBox=\"0 0 %s %s\">" % [_f(box), _f(box), _f(box), _f(box)]
	if clip_circle:
		s += "<defs><clipPath id=\"k\"><circle cx=\"%s\" cy=\"%s\" r=\"%s\"/></clipPath></defs><g clip-path=\"url(#k)\">" % [_f(box / 2), _f(box / 2), _f(box / 2)]
	for op in ops:
		var tone := tone_of(op)
		if not tones.has(tone):
			continue
		var col: Color = tones[tone]
		match str(op[0]):
			"l":
				s += "<path d=\"%s\" %s/>" % [_pts_d(op[1], false), _paint(col, float(op[2]))]
			"L":
				s += "<path d=\"%s\" %s/>" % [_pts_d(op[1], true), _paint(col, float(op[2]))]
			"f":
				s += "<path d=\"%s\" %s/>" % [_pts_d(op[1], true), _paint(col, 0.0)]
			"R":
				var p := _paint(col, float(op[2]))
				s += "<path d=\"%s\" %s/>" % [_pts_d(op[1], true), p.replace("fill=\"none\"", "fill=\"#%02X%02X%02X\"" % [int(col.r * 255.0 + 0.5), int(col.g * 255.0 + 0.5), int(col.b * 255.0 + 0.5)])]
			"c":
				s += "<circle cx=\"%s\" cy=\"%s\" r=\"%s\" %s/>" % [_f(float(op[1])), _f(float(op[2])), _f(float(op[3])), _paint(col, 0.0)]
			"o":
				s += "<circle cx=\"%s\" cy=\"%s\" r=\"%s\" %s/>" % [_f(float(op[1])), _f(float(op[2])), _f(float(op[3])), _paint(col, float(op[4]))]
			"e":
				s += "<ellipse cx=\"%s\" cy=\"%s\" rx=\"%s\" ry=\"%s\" %s/>" % [_f(float(op[1])), _f(float(op[2])), _f(float(op[3])), _f(float(op[4])), _paint(col, 0.0)]
			"a":
				var c := Vector2(float(op[1]), float(op[2]))
				var r := float(op[3])
				var a0 := deg_to_rad(float(op[4]))
				var a1 := deg_to_rad(float(op[5]))
				var p0 := c + Vector2(cos(a0), sin(a0)) * r
				var p1 := c + Vector2(cos(a1), sin(a1)) * r
				var large := 1 if absf(float(op[5]) - float(op[4])) > 180.0 else 0
				s += "<path d=\"M%s %s A%s %s 0 %d 1 %s %s\" %s/>" % [_f(p0.x), _f(p0.y), _f(r), _f(r), large, _f(p1.x), _f(p1.y), _paint(col, float(op[7]))]
			"b":
				s += "<path d=\"M%s %s C%s %s %s %s %s %s\" %s/>" % [_f(float(op[1])), _f(float(op[2])), _f(float(op[3])), _f(float(op[4])), _f(float(op[5])), _f(float(op[6])), _f(float(op[7])), _f(float(op[8])), _paint(col, float(op[9]))]
	if clip_circle:
		s += "</g>"
	return s + "</svg>"


# ---- direct drawing (fallback) -------------------------------------------------------------------------------------

static func _pts(flat: Array, origin: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		out.append(origin + Vector2(float(flat[i]), float(flat[i + 1])) * k)
	return out


static func _caps(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color, all_vertices: bool) -> void:
	if all_vertices:
		for p in pts:
			ci.draw_circle(p, w * 0.5, col)
	elif pts.size() > 0:
		ci.draw_circle(pts[0], w * 0.5, col)
		ci.draw_circle(pts[pts.size() - 1], w * 0.5, col)


## Draw the ops into `rect` (the box is scaled to the rect). Used as the fallback and by the no-SVG test.
static func draw(ci: CanvasItem, ops: Array, box: float, rect: Rect2, tones: Dictionary) -> void:
	var k := rect.size.x / box
	var o := rect.position
	for op in ops:
		var tone := tone_of(op)
		if not tones.has(tone):
			continue
		var col: Color = tones[tone]
		match str(op[0]):
			"l", "L":
				var pts := _pts(op[1], o, k)
				var w := float(op[2]) * k
				if str(op[0]) == "L":
					pts.append(pts[0])
				ci.draw_polyline(pts, col, w, true)
				_caps(ci, pts, w, col, true)
			"f":
				ci.draw_colored_polygon(_pts(op[1], o, k), col)
			"R":
				var pts := _pts(op[1], o, k)
				var w := float(op[2]) * k
				ci.draw_colored_polygon(pts, col)
				var closed := pts.duplicate()
				closed.append(pts[0])
				ci.draw_polyline(closed, col, w, true)
				_caps(ci, pts, w, col, true)
			"c":
				ci.draw_circle(o + Vector2(float(op[1]), float(op[2])) * k, float(op[3]) * k, col)
			"o":
				ci.draw_arc(o + Vector2(float(op[1]), float(op[2])) * k, float(op[3]) * k, 0.0, TAU, 40, col, float(op[4]) * k, true)
			"e":
				var pts := PackedVector2Array()
				for i in 28:
					var a := TAU * float(i) / 28.0
					pts.append(o + Vector2(float(op[1]) + cos(a) * float(op[3]), float(op[2]) + sin(a) * float(op[4])) * k)
				ci.draw_colored_polygon(pts, col)
			"a":
				var w := float(op[7]) * k
				var c := o + Vector2(float(op[1]), float(op[2])) * k
				var r := float(op[3]) * k
				ci.draw_arc(c, r, deg_to_rad(float(op[4])), deg_to_rad(float(op[5])), 24, col, w, true)
				for a in [float(op[4]), float(op[5])]:
					ci.draw_circle(c + Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * r, w * 0.5, col)
			"b":
				var w := float(op[9]) * k
				var p0 := o + Vector2(float(op[1]), float(op[2])) * k
				var p1 := o + Vector2(float(op[3]), float(op[4])) * k
				var p2 := o + Vector2(float(op[5]), float(op[6])) * k
				var p3 := o + Vector2(float(op[7]), float(op[8])) * k
				var pts := PackedVector2Array()
				for i in 17:
					var t := float(i) / 16.0
					var u := 1.0 - t
					pts.append(p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t))
				ci.draw_polyline(pts, col, w, true)
				_caps(ci, pts, w, col, false)
