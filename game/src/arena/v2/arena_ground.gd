class_name ArenaGround
extends Node2D
## The Arena v2 ground, baked ONCE into a SubViewport texture (MATCH-SIM-V2-DESIGN 11): the floating island of the original
## "Wrenfell Rise" layout in the canonical top-down frame, drawn from procedural shapes (no image files, no reference pixels):
## three material zones (pale flagstone at the bases, on the Moonhulk isle and round the towers; packed dirt for lanes and
## jungle trails; dusk grass elsewhere), the Mere lake with its two streams, stone bridges, rock pits for camps and the two
## stream objectives, curved stairs and our own inscribed emblem (a ring with three crescents) at each base. The team glow is
## not baked: the arena draws it as sprites so it follows "you" and "them". Colours are desaturated dusk tones (ART-BIBLE).
## Also places the upright scenery (conifers, rocks, braziers) along lane edges: `scenery()`, deterministic.

const MARGIN := 0.06
const W := 1024
const H := 1081               # W / x scale, so a texel is square in ground units
const GRASS := Color("46553c")
const GRASS_D := Color("3c4a35")
const GRASS_L := Color("566447")
const DIRT := Color("75634d")
const DIRT_D := Color("5c4d3c")
const STONE := Color("a19e94")
const STONE_D := Color("8a877e")
const STONE_L := Color("b8b5aa")
const MOSS := Color("4f5e45")
const WATER := Color("2d5865")
const WATER_D := Color("234852")
const SHORE := Color("6c8b86")
const CLIFF := Color("34383d")
const UNDER := Color("15191f")
const PIT := Color("2b2f2a")

var map: Dictionary = {}
var _rng: Pcg32


## A SubViewport that renders the ground once; its texture is the ground texture.
static func make_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.disable_3d = true
	var g := ArenaGround.new()
	vp.add_child(g)
	return vp


func _ready() -> void:
	map = SimData.map()
	_rng = Pcg32.contest_stream(1, "arena-ground")


static func tex_px(p: Vector2) -> Vector2:
	return Vector2((p.x + MARGIN) / (1.0 + 2.0 * MARGIN) * float(W), (p.y + MARGIN) / (1.0 + 2.0 * MARGIN) * float(H))


## Ground-unit length -> texture px (x and y are the same scale by construction).
static func u_px(u: float) -> float:
	return u / (1.0 + 2.0 * MARGIN) * float(H)


func _r() -> float:
	return _rng.next_float()


func _draw() -> void:
	_island()
	_grass_variation()
	_trails()
	_water()
	_lanes()
	_plazas()
	_pits()
	_decals()


# ---------------------------------------------------------------- island
static func island_outline(jitter_seed: int = 7) -> PackedVector2Array:
	## a rounded rectangle, wider in data than tall in units, with a slightly irregular edge
	var r := Pcg32.contest_stream(jitter_seed, "island-edge")
	var pts := PackedVector2Array()
	var x0 := 0.035
	var x1 := 0.965
	var y0 := 0.02
	var y1 := 0.98
	var rad := 0.09
	var corners := [Vector2(x1 - rad, y0 + rad), Vector2(x1 - rad, y1 - rad), Vector2(x0 + rad, y1 - rad), Vector2(x0 + rad, y0 + rad)]
	var starts := [-PI / 2.0, 0.0, PI / 2.0, PI]
	for c in 4:
		for k in 9:
			var a: float = starts[c] + PI / 2.0 * float(k) / 8.0
			var j := 1.0 + 0.10 * (r.next_float() - 0.5)
			pts.append(corners[c] + Vector2(cos(a) * rad * j, sin(a) * rad * j))
		# a few points along the straight edge to the next corner
		var nxt: Vector2 = corners[(c + 1) % 4]
		var a2: float = starts[(c + 1) % 4]
		var edge_from: Vector2 = corners[c] + Vector2(cos(starts[c] + PI / 2.0), sin(starts[c] + PI / 2.0)) * rad
		var edge_to: Vector2 = nxt + Vector2(cos(a2), sin(a2)) * rad
		for k2 in range(1, 6):
			var e := edge_from.lerp(edge_to, float(k2) / 6.0)
			var n := Vector2(cos(starts[c] + PI / 2.0), sin(starts[c] + PI / 2.0))
			pts.append(e + n * 0.006 * (r.next_float() - 0.5))
	return pts


func _poly_px(pts: PackedVector2Array, off: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(tex_px(p + off))
	return out


func _island() -> void:
	var o := island_outline()
	draw_colored_polygon(_poly_px(o, Vector2(0.0, 0.03)), UNDER)       # the island's underside, seen at the near edge
	draw_colored_polygon(_poly_px(o, Vector2(0.0, 0.012)), CLIFF)      # the cliff band
	draw_colored_polygon(_poly_px(o), GRASS)


func _grass_variation() -> void:
	for i in 700:
		var p := Vector2(0.06 + 0.88 * _r(), 0.05 + 0.90 * _r())
		var c := GRASS_D if _r() < 0.5 else GRASS_L
		c.a = 0.35 + 0.3 * _r()
		draw_circle(tex_px(p), u_px(0.006 + 0.02 * _r()), c)


# ---------------------------------------------------------------- water
const MERE_C := Vector2(0.5, 0.5)
const MERE_R := 0.165        # ground units
const ISLE_R := 0.085


func _ellipse_px(c: Vector2, r_u: float, n: int = 40) -> PackedVector2Array:
	var xs := float(map["x_scale"])
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(tex_px(c + Vector2(cos(a) * r_u / xs, sin(a) * r_u)))
	return pts


func _stream_poly(x_from: float, x_to: float, width_u: float) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var x := lerpf(x_from, x_to, float(i) / float(steps))
		var wig := 0.012 * sin(x * 31.0) + 0.006 * sin(x * 73.0)
		var w := width_u * (0.8 + 0.4 * absf(sin(x * 11.0)))
		top.append(tex_px(Vector2(x, 0.5 + wig - w * 0.5)))
		bot.append(tex_px(Vector2(x, 0.5 + wig + w * 0.5)))
	bot.reverse()
	top.append_array(bot)
	return top


func _water() -> void:
	# shore first, a little larger, then the water
	for pair in [[SHORE, 0.012], [WATER, 0.0]]:
		var col: Color = pair[0]
		var grow: float = pair[1]
		draw_colored_polygon(_stream_poly(0.02, 0.37, 0.055 + grow * 2.0), col)
		draw_colored_polygon(_stream_poly(0.63, 0.98, 0.055 + grow * 2.0), col)
		draw_colored_polygon(_ellipse_px(MERE_C, MERE_R + grow), col)
	draw_colored_polygon(_ellipse_px(MERE_C, MERE_R * 0.7), WATER_D)
	# ripples
	for k in 3:
		draw_polyline(_close(_ellipse_px(MERE_C, MERE_R * (0.45 + 0.17 * float(k)), 48)), Color(1, 1, 1, 0.05), 2.0, true)
	# the Moonhulk isle (flagstone, drawn in _plazas) sits on a rocky rim
	draw_colored_polygon(_ellipse_px(MERE_C, ISLE_R + 0.012), CLIFF)


func _close(p: PackedVector2Array) -> PackedVector2Array:
	var q := p.duplicate()
	q.append(p[0])
	return q


# ---------------------------------------------------------------- lanes and trails
func _lane_pts(lane: String) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for id in map["lanes"][lane]["nodes"]:
		pts.append(SimData.node_pos(String(id)))
	return pts


func _strip(pts: PackedVector2Array, w_u: float, col: Color) -> void:
	var px := PackedVector2Array()
	for p in pts:
		px.append(tex_px(p))
	draw_polyline(px, col, u_px(w_u), true)
	for p2 in px:
		draw_circle(p2, u_px(w_u) * 0.5, col)


func _lanes() -> void:
	for lane in ["top", "mid", "bot"]:
		var pts := _lane_pts(lane)
		_strip(pts, 0.062, DIRT_D)
		_strip(pts, 0.050, DIRT)
		# ruts
		for side in [-1.0, 1.0]:
			var rut := PackedVector2Array()
			for i in pts.size():
				var a: Vector2 = pts[maxi(0, i - 1)]
				var b: Vector2 = pts[mini(pts.size() - 1, i + 1)]
				var n := Vector2(-(b - a).y, (b - a).x).normalized()
				rut.append(tex_px(pts[i] + n * 0.009 * side))
			draw_polyline(rut, Color(DIRT_D, 0.6), 2.0, true)
	# stone bridges where the side lanes cross the streams, and the causeways onto the Moonhulk isle
	for c in [Vector2(0.11, 0.5), Vector2(0.89, 0.5)]:
		_flagstones(c, 0.05, 0.018)
	for y in [0.5 - 0.125, 0.5 + 0.125]:
		_flagstones(Vector2(0.5, y), 0.045, 0.018)


func _trails() -> void:
	var lane_nodes := {}
	for lane in map["lanes"]:
		for id in map["lanes"][lane]["nodes"]:
			lane_nodes[String(id)] = true
	var d: Dictionary = DataLoader.load_json("res://data/arena_map.json")
	for e in d["edges"]:
		var a := String(e["a"])
		var b := String(e["b"])
		if lane_nodes.has(a) and lane_nodes.has(b):
			continue
		if a.ends_with("cairn") or b.ends_with("cairn"):
			continue
		_strip(PackedVector2Array([SimData.node_pos(a), SimData.node_pos(b)]), 0.020, Color(DIRT, 0.85))


# ---------------------------------------------------------------- stone
## Irregular flagstones inside a circle (ground radius r_u), with moss in the cracks.
func _flagstones(c: Vector2, r_u: float, step_u: float) -> void:
	var xs := float(map["x_scale"])
	draw_colored_polygon(_ellipse_px(c, r_u + 0.004), MOSS)
	var n := int(r_u / step_u) + 1
	for iy in range(-n, n + 1):
		for ix in range(-n, n + 1):
			var off := Vector2(float(ix) + 0.5 * float(iy % 2), float(iy)) * step_u
			if off.length() > r_u - step_u * 0.3:
				continue
			var q := PackedVector2Array()
			var cx := c + Vector2(off.x / xs, off.y)
			for k in 5:
				var a := TAU * float(k) / 5.0 + _r() * 0.6
				var rr := step_u * (0.42 + 0.12 * _r())
				q.append(tex_px(cx + Vector2(cos(a) * rr / xs, sin(a) * rr)))
			var tone := STONE.lerp(STONE_D if _r() < 0.5 else STONE_L, _r() * 0.7)
			draw_colored_polygon(q, tone)


func _plazas() -> void:
	for side in ["B", "R"]:
		var cairn: Vector2 = map["cairn"][side]
		_flagstones(cairn, 0.19, 0.022)
		_stairs(cairn, side)
		_emblem(cairn, 0.085)
	_flagstones(MERE_C, ISLE_R, 0.02)
	_emblem(MERE_C, 0.05)
	for tw in map["towers"]:
		_flagstones(tw["pos"], 0.03, 0.014)


## Three curved steps where the base plaza meets each lane.
func _stairs(cairn: Vector2, side: String) -> void:
	var xs := float(map["x_scale"])
	var dir := -1.0 if side == "B" else 1.0
	for k in 3:
		var r := 0.19 + 0.012 * float(k)
		var pts := PackedVector2Array()
		for i in 25:
			var a := PI / 2.0 * dir - 1.1 + 2.2 * float(i) / 24.0
			pts.append(tex_px(cairn + Vector2(cos(a) * r / xs, sin(a) * r)))
		draw_polyline(pts, Color(STONE_D, 0.9 - 0.2 * float(k)), u_px(0.006), true)


## Our inscribed emblem: a ring with three crescents turned inward (original; no existing game's sigil).
func _emblem(c: Vector2, r_u: float) -> void:
	var col := Color(0.82, 0.82, 0.76, 0.55)
	draw_polyline(_close(_ellipse_px(c, r_u, 56)), col, u_px(0.004), true)
	draw_polyline(_close(_ellipse_px(c, r_u * 0.82, 56)), Color(col, 0.35), u_px(0.002), true)
	var xs := float(map["x_scale"])
	for k in 3:
		var a := -PI / 2.0 + TAU * float(k) / 3.0
		var cc := c + Vector2(cos(a) * r_u * 0.5 / xs, sin(a) * r_u * 0.5)
		var arc := PackedVector2Array()
		for i in 13:
			var b := a + PI / 2.0 + PI * float(i) / 12.0
			arc.append(tex_px(cc + Vector2(cos(b) * r_u * 0.26 / xs, sin(b) * r_u * 0.26)))
		draw_polyline(arc, col, u_px(0.004), true)


# ---------------------------------------------------------------- pits and decals
func _pits() -> void:
	for c in map["camps"]:
		var p: Vector2 = c["pos"]
		draw_colored_polygon(_ellipse_px(p, 0.03), STONE_D)
		draw_colored_polygon(_ellipse_px(p, 0.024), PIT)
		for k in 7:
			var a := TAU * float(k) / 7.0 + _r()
			draw_circle(tex_px(p + Vector2(cos(a) * 0.028 / float(map["x_scale"]), sin(a) * 0.028)), u_px(0.004), STONE_L)
	for oid in ["stoneback", "mossback"]:
		var o: Vector2 = map["objectives"][oid]["pos"]
		draw_colored_polygon(_ellipse_px(o, 0.052), STONE_D)
		draw_colored_polygon(_ellipse_px(o, 0.044), PIT if oid == "stoneback" else Color("2f3a2a"))
		_emblem(o, 0.03)


func _decals() -> void:
	for i in 260:
		var p := Vector2(0.06 + 0.88 * _r(), 0.05 + 0.90 * _r())
		if _r() < 0.6:
			draw_circle(tex_px(p), u_px(0.002 + 0.003 * _r()), Color(STONE_L, 0.5))
		else:
			var flower: Color = [Color("c9b26a"), Color("b07f8f"), Color("d7d2c0")][int(_r() * 2.99)]
			draw_circle(tex_px(p), u_px(0.0018), Color(flower, 0.7))


# ---------------------------------------------------------------- upright scenery
## Conifers and rocks along the lane edges and in the jungle, braziers at the base gates: [{kind, p (canonical)}], far to near
## order is left to the arena (it sorts by depth). Deterministic. Never on a lane, a trail node, water or a plaza.
static func scenery() -> Array:
	var m := SimData.map()
	var r := Pcg32.contest_stream(3, "arena-scenery")
	var out: Array = []
	var lanes: Array = []
	for lane in m["lanes"]:
		var pts: Array = []
		for id in m["lanes"][lane]["nodes"]:
			pts.append(SimData.node_pos(String(id)))
		lanes.append(pts)
	var avoid: Array = []
	for side in ["B", "R"]:
		avoid.append([m["cairn"][side], 0.23])
	avoid.append([MERE_C, MERE_R + 0.03])
	for c in m["camps"]:
		avoid.append([c["pos"], 0.045])
	for oid in m["objectives"]:
		avoid.append([m["objectives"][oid]["pos"], 0.06])
	for tw in m["towers"]:
		avoid.append([tw["pos"], 0.04])
	var tries := 0
	while out.size() < 95 and tries < 4000:
		tries += 1
		var p := Vector2(0.07 + 0.86 * r.next_float(), 0.06 + 0.88 * r.next_float())
		if absf(p.y - 0.5) < 0.05:
			continue    # the streams
		var ok := true
		for a in avoid:
			if SimData.du(p, a[0]) < float(a[1]):
				ok = false
				break
		if not ok:
			continue
		var dl := INF
		for pts in lanes:
			dl = minf(dl, _dist_poly(p, pts))
		if dl < 0.06:
			continue
		var kind := "tree"
		if dl < 0.075:
			kind = "rock" if r.next_float() < 0.45 else "tree"
		elif r.next_float() < 0.15:
			kind = "rock"
		out.append({"kind": kind, "p": p, "v": int(r.next_float() * 2.99)})
	for side in ["B", "R"]:
		var c: Vector2 = m["cairn"][side]
		var dy := -0.2 if side == "B" else 0.2
		for dx in [-0.09, 0.09]:
			out.append({"kind": "brazier", "p": c + Vector2(dx, dy * 0.9), "v": 0})
	return out


static func _dist_poly(p: Vector2, pts: Array) -> float:
	var best := INF
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(1e-9, ab.dot(ab)), 0.0, 1.0)
		best = minf(best, SimData.du(p, a + ab * t))
	return best
