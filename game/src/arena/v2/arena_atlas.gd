class_name ArenaAtlas
extends Node2D
## The Arena v2 sprite atlas, baked ONCE into a SubViewport (MATCH-SIM-V2-DESIGN 11.4): upright units and props drawn in code
## (placeholder art in the Arena Dusk style until the Founder chooses an art route), so the whole arena draws from one texture
## and its sprites batch. Every sprite is neutral light stone or ink; team colour comes from the modulate colour at draw time
## (teal = you, coral = them), and team shape from the base ring: a circle for you, a hexagon for them (Founder rule; never
## colour alone). Shapes are our own: the archetype glyphs of Alpha 0.8.2 on simple cloaked figures, a lantern-topped tower,
## a standing-stone Cairn, conifers, rocks and braziers. No shape of an existing game's units, turrets or crystals.

const CELL := 64
const COLS := 12
const SIZE := Vector2i(CELL * COLS, CELL * 8)
## cell (column, row, width in cells, height in cells) per sprite; the anchor (feet) is the bottom centre of the rect
const CELLS := {
	"tree0": [0, 0, 1, 2], "tree1": [1, 0, 1, 2], "tree2": [2, 0, 1, 2],
	"rock0": [3, 0, 1, 1], "rock1": [4, 0, 1, 1], "rock2": [5, 0, 1, 1],
	"brazier": [3, 1, 1, 1], "flame": [4, 1, 1, 1], "glow": [5, 1, 1, 1],
	"tower": [6, 0, 1, 2], "tower_gem": [7, 0, 1, 1], "rubble": [7, 1, 1, 1],
	"cairn": [8, 0, 2, 2], "cairn_gem": [10, 0, 1, 1], "cairn_broken": [10, 1, 2, 1],
	"hero_bruiser": [0, 2, 1, 1], "hero_bulwark": [1, 2, 1, 1], "hero_shade": [2, 2, 1, 1], "hero_spellcaster": [3, 2, 1, 1],
	"hero_binder": [4, 2, 1, 1], "hero_gunner": [5, 2, 1, 1], "hero_mender": [6, 2, 1, 1],
	"ring_you": [7, 2, 1, 1], "ring_them": [8, 2, 1, 1], "shadow": [9, 2, 1, 1], "minion": [10, 2, 1, 1], "minion_big": [11, 2, 1, 1],
	"camp": [0, 3, 1, 1], "camp_big": [1, 3, 1, 1], "stoneback": [2, 3, 2, 2], "moonhulk": [4, 3, 2, 2], "mossback": [6, 3, 2, 1],
	"bar": [8, 3, 1, 1], "spark": [9, 3, 1, 1], "burst": [10, 3, 1, 1], "ring_fx": [11, 3, 1, 1],
	"slash": [6, 4, 1, 1], "bolt": [7, 4, 1, 1], "plus": [8, 4, 1, 1], "skull": [9, 4, 1, 1], "shield_fx": [10, 4, 1, 1],
	"dot": [11, 4, 1, 1], "arrow": [0, 5, 1, 1], "cc": [1, 5, 1, 1],
}
const INK := Color("1b1f26")
const STONE := Color("cfcabb")
const STONE_D := Color("9b968a")
const PINE := Color("2f4a35")
const PINE_D := Color("223828")
const PINE_L := Color("3e5c42")
const BARK := Color("4a3a2c")
const ROCK := Color("858a8e")
const ROCK_D := Color("62676b")
const EMBER := Color("ffb35c")


static func make_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.disable_3d = true
	vp.add_child(ArenaAtlas.new())
	return vp


static func rect(name: String) -> Rect2:
	var c: Array = CELLS[name]
	return Rect2(float(c[0]) * CELL, float(c[1]) * CELL, float(c[2]) * CELL, float(c[3]) * CELL)


func _o(name: String) -> Vector2:
	return rect(name).position


func _sz(name: String) -> Vector2:
	return rect(name).size


func _draw() -> void:
	for v in 3:
		_tree("tree%d" % v, v)
		_rock("rock%d" % v, v)
	_brazier()
	_tower()
	_cairn()
	for arch in ["bruiser", "bulwark", "shade", "spellcaster", "binder", "gunner", "mender"]:
		_hero(arch)
	_rings()
	_units()
	_monsters()
	_fx()


func _tree(name: String, v: int) -> void:
	var o := _o(name)
	var w := float(CELL)
	var h := float(CELL * 2)
	var cx := o.x + w / 2.0
	draw_rect(Rect2(cx - 3, o.y + h - 18, 6, 16), BARK)
	var tiers := 3 + v % 2
	for k in tiers:
		var y0 := o.y + h - 16 - float(k) * (h - 30) / float(tiers)
		var half := (w * 0.44) * (1.0 - 0.18 * float(k)) * (0.9 + 0.1 * float(v))
		draw_colored_polygon(PackedVector2Array([Vector2(cx - half, y0), Vector2(cx + half, y0), Vector2(cx, y0 - (h - 30) / float(tiers) * 1.5)]), PINE if k % 2 == 0 else PINE_L)
		draw_colored_polygon(PackedVector2Array([Vector2(cx, y0), Vector2(cx + half, y0), Vector2(cx, y0 - (h - 30) / float(tiers) * 1.5)]), PINE_D)


func _rock(name: String, v: int) -> void:
	var o := _o(name)
	var c := o + Vector2(CELL / 2.0, CELL - 10)
	var pts := PackedVector2Array()
	var n := 7
	for i in n:
		var a := PI + PI * float(i) / float(n - 1)
		var r := 22.0 - 4.0 * float(v) + 4.0 * sin(float(i) * 2.3 + float(v))
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * (0.8 + 0.1 * float(v))))
	draw_colored_polygon(pts, ROCK)
	draw_colored_polygon(PackedVector2Array([pts[3], pts[4], pts[5], pts[6], c]), ROCK_D)


func _brazier() -> void:
	var o := _o("brazier")
	var c := o + Vector2(CELL / 2.0, CELL)
	draw_rect(Rect2(c.x - 5, c.y - 30, 10, 28), STONE_D)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -38), c + Vector2(16, -38), c + Vector2(10, -28), c + Vector2(-10, -28)]), STONE)
	var f := _o("flame") + Vector2(CELL / 2.0, CELL)
	draw_colored_polygon(PackedVector2Array([f + Vector2(-12, -6), f + Vector2(12, -6), f + Vector2(4, -30), f + Vector2(0, -44), f + Vector2(-5, -28)]), EMBER)
	draw_colored_polygon(PackedVector2Array([f + Vector2(-6, -8), f + Vector2(6, -8), f + Vector2(0, -28)]), Color("fff0c8"))
	var g := _o("glow") + Vector2(CELL / 2.0, CELL / 2.0)
	for k in 8:
		draw_circle(g, 30.0 - 3.5 * float(k), Color(1, 1, 1, 0.07 + 0.02 * float(k)))


func _tower() -> void:
	# a squat stone column with a lantern cage on top; the lantern gem is a separate sprite tinted by the team
	var o := _o("tower")
	var c := o + Vector2(CELL / 2.0, CELL * 2)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-22, -4), c + Vector2(22, -4), c + Vector2(16, -16), c + Vector2(-16, -16)]), STONE_D)
	draw_rect(Rect2(c.x - 13, c.y - 86, 26, 72), STONE)
	draw_rect(Rect2(c.x - 13, c.y - 86, 8, 72), Color(STONE_D, 0.8))
	for k in 4:
		draw_line(Vector2(c.x - 13, c.y - 30 - 16 * k), Vector2(c.x + 13, c.y - 30 - 16 * k), STONE_D, 1.5)
	draw_rect(Rect2(c.x - 17, c.y - 92, 34, 8), STONE_D)
	draw_line(Vector2(c.x - 12, c.y - 92), Vector2(c.x - 8, c.y - 118), INK, 3)
	draw_line(Vector2(c.x + 12, c.y - 92), Vector2(c.x + 8, c.y - 118), INK, 3)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - 12, c.y - 118), Vector2(c.x + 12, c.y - 118), Vector2(c.x, c.y - 127)]), INK)
	var gm := _o("tower_gem") + Vector2(CELL / 2.0, CELL / 2.0)
	draw_colored_polygon(PackedVector2Array([gm + Vector2(0, -14), gm + Vector2(9, 0), gm + Vector2(0, 14), gm + Vector2(-9, 0)]), Color(1, 1, 1))
	draw_colored_polygon(PackedVector2Array([gm + Vector2(0, -14), gm + Vector2(9, 0), gm + Vector2(0, 0)]), Color(1, 1, 1, 0.7))
	var rb := _o("rubble") + Vector2(CELL / 2.0, CELL - 6)
	for k in 6:
		draw_circle(rb + Vector2(-18 + 7 * k, -4 - 6 * (k % 2)), 7.0 - float(k % 3), STONE_D if k % 2 == 0 else STONE)


func _cairn() -> void:
	# a ring of three standing stones round a raised plinth; the hovering heart-stone is a separate tinted sprite
	var o := _o("cairn")
	var c := o + Vector2(CELL, CELL * 2)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-56, -6), c + Vector2(56, -6), c + Vector2(44, -26), c + Vector2(-44, -26)]), STONE_D)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-40, -26), c + Vector2(40, -26), c + Vector2(32, -40), c + Vector2(-32, -40)]), STONE)
	for x in [-42.0, 0.0, 42.0]:
		var hgt: float = 80.0 if float(x) == 0.0 else 64.0
		var bx: float = c.x + float(x)
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 9, c.y - 30), Vector2(bx + 9, c.y - 30), Vector2(bx + 6, c.y - 30 - hgt), Vector2(bx - 5, c.y - 34 - hgt)]), STONE)
		draw_line(Vector2(bx - 3, c.y - 36), Vector2(bx - 2, c.y - 20 - hgt), STONE_D, 2)
	var g := _o("cairn_gem") + Vector2(CELL / 2.0, CELL / 2.0)
	var pts := PackedVector2Array()
	for i in 6:
		var a := -PI / 2.0 + TAU * float(i) / 6.0
		pts.append(g + Vector2(cos(a) * 14.0, sin(a) * 22.0))
	draw_colored_polygon(pts, Color(1, 1, 1))
	var br := _o("cairn_broken") + Vector2(CELL, CELL - 4)
	for k in 9:
		draw_colored_polygon(PackedVector2Array([br + Vector2(-50 + 12 * k, 0), br + Vector2(-42 + 12 * k, -10 - 6 * (k % 3)), br + Vector2(-36 + 12 * k, 0)]), STONE_D if k % 2 == 0 else STONE)


func _hero(arch: String) -> void:
	# a standing cloaked figure about 52 px tall; the archetype glyph in ink on the chest
	var name := "hero_" + arch
	var o := _o(name)
	var c := o + Vector2(CELL / 2.0, CELL - 2)
	var wide := 16.0 if arch in ["bruiser", "bulwark"] else 13.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(-wide, 0), c + Vector2(wide, 0), c + Vector2(wide * 0.6, -34), c + Vector2(-wide * 0.6, -34)]), STONE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(wide * 0.1, 0), c + Vector2(wide, 0), c + Vector2(wide * 0.6, -34), c + Vector2(wide * 0.1, -34)]), Color(STONE_D, 0.6))
	draw_circle(c + Vector2(0, -42), 9.0, STONE)
	draw_circle(c + Vector2(2, -43), 6.0, Color(STONE_D, 0.25))
	_glyph(c + Vector2(0, -18), arch, INK, 0.55)


func _glyph(c: Vector2, arch: String, ink: Color, k: float) -> void:
	match arch:
		"bruiser":
			draw_rect(Rect2(c + Vector2(-9, -11) * k, Vector2(18, 9) * k), ink)
			draw_rect(Rect2(c + Vector2(-2, -3) * k, Vector2(4, 15) * k), ink)
		"bulwark":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -11) * k, c + Vector2(10, -11) * k, c + Vector2(10, 1) * k, c + Vector2(0, 12) * k, c + Vector2(-10, 1) * k]), ink)
		"shade":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13) * k, c + Vector2(4, 2) * k, c + Vector2(0, 7) * k, c + Vector2(-4, 2) * k]), ink)
			draw_rect(Rect2(c + Vector2(-7, 6) * k, Vector2(14, 3) * k), ink)
		"spellcaster":
			var st := PackedVector2Array()
			for i in 8:
				st.append(c + Vector2.from_angle(-PI / 2.0 + TAU * float(i) / 8.0) * (12.0 if i % 2 == 0 else 4.5) * k)
			draw_colored_polygon(st, ink)
		"binder":
			draw_arc(c + Vector2(-4.5, 0) * k, 6.5 * k, 0.0, TAU, 20, ink, 2.5, true)
			draw_arc(c + Vector2(4.5, 0) * k, 6.5 * k, 0.0, TAU, 20, ink, 2.5, true)
		"gunner":
			draw_arc(c, 8.5 * k, 0.0, TAU, 24, ink, 2.0, true)
			for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
				draw_line(c + d * 6.0 * k, c + d * 13.0 * k, ink, 2.0, true)
		_:
			draw_rect(Rect2(c + Vector2(-1.5, -2) * k, Vector2(3, 14) * k), ink)
			draw_circle(c + Vector2(-5, -4) * k, 4.0 * k, ink)
			draw_circle(c + Vector2(5, -7) * k, 4.0 * k, ink)


func _rings() -> void:
	var a := _o("ring_you") + Vector2(CELL / 2.0, CELL / 2.0)
	draw_arc(a, 24.0, 0.0, TAU, 40, Color(1, 1, 1), 5.0, true)
	var b := _o("ring_them") + Vector2(CELL / 2.0, CELL / 2.0)
	var hx := PackedVector2Array()
	for i in 7:
		var ang := TAU * float(i) / 6.0
		hx.append(b + Vector2(cos(ang), sin(ang)) * 25.0)
	draw_polyline(hx, Color(1, 1, 1), 5.0, true)
	var s := _o("shadow") + Vector2(CELL / 2.0, CELL / 2.0)
	for k in 6:
		draw_colored_polygon(_oval(s, 26.0 - 3.0 * float(k), 12.0 - 1.4 * float(k)), Color(0, 0, 0, 0.09))


func _units() -> void:
	var m := _o("minion") + Vector2(CELL / 2.0, CELL - 4)
	draw_colored_polygon(_oval(m + Vector2(0, -10), 9.0, 10.0), Color(1, 1, 1))
	draw_circle(m + Vector2(0, -24), 6.0, Color(1, 1, 1))
	var mb := _o("minion_big") + Vector2(CELL / 2.0, CELL - 4)
	draw_colored_polygon(_oval(mb + Vector2(0, -14), 14.0, 14.0), Color(1, 1, 1))
	draw_rect(Rect2(mb.x - 16, mb.y - 34, 32, 8), Color(1, 1, 1))
	var bar := _o("bar")
	draw_rect(Rect2(bar.x + 2, bar.y + 2, CELL - 4, 12), Color(1, 1, 1))
	var dot := _o("dot") + Vector2(CELL / 2.0, CELL / 2.0)
	draw_circle(dot, 12.0, Color(1, 1, 1))


func _monsters() -> void:
	var c := _o("camp") + Vector2(CELL / 2.0, CELL - 4)
	draw_colored_polygon(_oval(c + Vector2(0, -14), 18.0, 14.0), Color("6f7d5a"))
	draw_circle(c + Vector2(-6, -18), 2.5, INK)
	draw_circle(c + Vector2(6, -18), 2.5, INK)
	var cb := _o("camp_big") + Vector2(CELL / 2.0, CELL - 4)
	draw_colored_polygon(_oval(cb + Vector2(0, -20), 24.0, 20.0), Color("7b6a52"))
	draw_colored_polygon(PackedVector2Array([cb + Vector2(-16, -34), cb + Vector2(-8, -48), cb + Vector2(-4, -34)]), STONE_D)
	draw_colored_polygon(PackedVector2Array([cb + Vector2(16, -34), cb + Vector2(8, -48), cb + Vector2(4, -34)]), STONE_D)
	# Stoneback: a low beast carrying a slab of stone on its back
	var sb := _o("stoneback") + Vector2(CELL, CELL * 2 - 6)
	draw_colored_polygon(_oval(sb + Vector2(0, -26), 50.0, 24.0), Color("5f6655"))
	draw_colored_polygon(PackedVector2Array([sb + Vector2(-40, -36), sb + Vector2(36, -44), sb + Vector2(30, -70), sb + Vector2(-28, -76)]), STONE_D)
	draw_line(sb + Vector2(-20, -60), sb + Vector2(16, -64), STONE, 3)
	draw_circle(sb + Vector2(44, -24), 10.0, Color("5f6655"))
	draw_circle(sb + Vector2(48, -26), 2.5, Color(EMBER))
	# Moonhulk: a tall pale hunched giant with a lantern of moonlight in its chest
	var mh := _o("moonhulk") + Vector2(CELL, CELL * 2 - 4)
	draw_colored_polygon(PackedVector2Array([mh + Vector2(-44, 0), mh + Vector2(44, 0), mh + Vector2(34, -70), mh + Vector2(0, -98), mh + Vector2(-34, -70)]), Color("b9c0c9"))
	draw_colored_polygon(PackedVector2Array([mh + Vector2(10, 0), mh + Vector2(44, 0), mh + Vector2(34, -70), mh + Vector2(10, -86)]), Color("98a0aa"))
	draw_circle(mh + Vector2(0, -56), 12.0, Color("eaf2ff"))
	draw_circle(mh + Vector2(-12, -84), 3.0, INK)
	draw_circle(mh + Vector2(10, -84), 3.0, INK)
	# Mossback: a mound of moss with two eyes
	var mo := _o("mossback") + Vector2(CELL, CELL - 4)
	draw_colored_polygon(_oval(mo + Vector2(0, -18), 50.0, 18.0), Color("4b6a3e"))
	draw_circle(mo + Vector2(-10, -24), 3.0, INK)
	draw_circle(mo + Vector2(10, -24), 3.0, INK)


func _fx() -> void:
	var sp := _o("spark") + Vector2(CELL / 2.0, CELL / 2.0)
	for i in 8:
		var a := TAU * float(i) / 8.0
		draw_line(sp + Vector2.from_angle(a) * 6.0, sp + Vector2.from_angle(a) * (22.0 if i % 2 == 0 else 14.0), Color(1, 1, 1), 3.0, true)
	var bu := _o("burst") + Vector2(CELL / 2.0, CELL / 2.0)
	for k in 6:
		draw_circle(bu, 28.0 - 4.0 * float(k), Color(1, 1, 1, 0.12 + 0.05 * float(k)))
	var rf := _o("ring_fx") + Vector2(CELL / 2.0, CELL / 2.0)
	draw_arc(rf, 26.0, 0.0, TAU, 40, Color(1, 1, 1), 3.0, true)
	var sl := _o("slash") + Vector2(CELL / 2.0, CELL / 2.0)
	draw_colored_polygon(PackedVector2Array([sl + Vector2(-24, 14), sl + Vector2(18, -22), sl + Vector2(24, -18), sl + Vector2(-16, 20)]), Color(1, 1, 1))
	var bo := _o("bolt") + Vector2(CELL / 2.0, CELL / 2.0)
	draw_colored_polygon(_oval(bo, 22.0, 7.0), Color(1, 1, 1))
	draw_colored_polygon(_oval(bo + Vector2(8, 0), 10.0, 4.0), Color(1, 1, 1, 0.6))
	var pl := _o("plus") + Vector2(CELL / 2.0, CELL / 2.0)
	draw_rect(Rect2(pl.x - 5, pl.y - 18, 10, 36), Color(1, 1, 1))
	draw_rect(Rect2(pl.x - 18, pl.y - 5, 36, 10), Color(1, 1, 1))
	var sk := _o("skull") + Vector2(CELL / 2.0, CELL / 2.0)
	draw_circle(sk + Vector2(0, -4), 15.0, Color(1, 1, 1))
	draw_rect(Rect2(sk.x - 8, sk.y + 6, 16, 10), Color(1, 1, 1))
	draw_circle(sk + Vector2(-6, -4), 4.0, INK)
	draw_circle(sk + Vector2(6, -4), 4.0, INK)
	var shf := _o("shield_fx") + Vector2(CELL / 2.0, CELL / 2.0)
	draw_arc(shf, 24.0, -PI * 0.9, -PI * 0.1, 24, Color(1, 1, 1), 5.0, true)
	var ar := _o("arrow") + Vector2(CELL / 2.0, CELL / 2.0)
	draw_colored_polygon(PackedVector2Array([ar + Vector2(0, -20), ar + Vector2(14, 0), ar + Vector2(5, 0), ar + Vector2(5, 18), ar + Vector2(-5, 18), ar + Vector2(-5, 0), ar + Vector2(-14, 0)]), Color(1, 1, 1))
	var cc := _o("cc") + Vector2(CELL / 2.0, CELL / 2.0)
	for i in 3:
		var a2 := TAU * float(i) / 3.0
		draw_circle(cc + Vector2.from_angle(a2) * 12.0, 5.0, Color(1, 1, 1))


func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
