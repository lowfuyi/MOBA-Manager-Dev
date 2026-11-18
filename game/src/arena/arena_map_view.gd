class_name ArenaMap
extends Control
## The Wrenfell arena on screen (Alpha 0.8 A-02, ARENA-MAP 4 to 9). Rule A4: the terrain and every map icon are drawn ONCE into
## a SubViewport (UPDATE_ONCE); each frame draws regions of that one texture (the map window, then towers and later tokens from
## the icon strip beside the map), so the map costs about one draw call however much is on it. Labels are drawn in screen space.
##   flip       the player is Red: y is mirrored so the player's base is at the bottom (a mirror, never a rotation)
##   camera     look_at_point(p, z): centre on an arena point (view frame, px of the 720 x 760 arena) at zoom z in [1.0, 1.3],
##              clamped to the map; window() is the part of the arena on screen; to_view(p) maps a canonical point to local px
##   fallen     tower ids that are down (drawn as rubble); guard towers are drawn at look.guard_tower_opacity
## Not interactive (UI-PASS-2 6.7: no taps on the map in 0.8).

const MAP := Vector2(720, 760)
const STRIP_X := 752.0          # the icon strip right of the map in the baked texture (nothing on the map reaches past x 720)
const CELL := 64.0
const BAKE := Vector2i(752 + 64 * 6, 768)
## icon strip cells (column, row; 6 columns by 12 rows): towers and rubble, minion dots (row 0), hero tokens with the slot letter
## (row 1 yours: teal circles; row 2 theirs: coral flat-top hexagons), effects (rows 3 to 6, A-04), the Fight pass actions and
## the health-bar pieces (rows 7 and 8, Alpha 0.8.1). Rows 9 and on are free.
const ICON := {"tower_you": Vector2i(0, 0), "tower_them": Vector2i(1, 0), "rubble_you": Vector2i(2, 0), "rubble_them": Vector2i(3, 0),
		"minion_you": Vector2i(4, 0), "minion_them": Vector2i(5, 0),
		"hero_you_top": Vector2i(0, 1), "hero_you_jg": Vector2i(1, 1), "hero_you_mid": Vector2i(2, 1), "hero_you_bot": Vector2i(3, 1), "hero_you_sup": Vector2i(4, 1),
		"hero_them_top": Vector2i(0, 2), "hero_them_jg": Vector2i(1, 2), "hero_them_mid": Vector2i(2, 2), "hero_them_bot": Vector2i(3, 2), "hero_them_sup": Vector2i(4, 2),
		"spark": Vector2i(0, 3), "ring_magic": Vector2i(1, 3), "skull": Vector2i(2, 3), "motes": Vector2i(3, 3), "flash": Vector2i(4, 3), "dust": Vector2i(5, 3),
		"aura_you": Vector2i(0, 4), "aura_them": Vector2i(1, 4), "ring_you": Vector2i(2, 4), "ring_them": Vector2i(3, 4), "arrow_up_you": Vector2i(4, 4), "arrow_down_you": Vector2i(5, 4),
		"arrow_up_them": Vector2i(0, 5), "arrow_down_them": Vector2i(1, 5), "burst_amber": Vector2i(2, 5), "burst_pale": Vector2i(3, 5), "glyph_you": Vector2i(4, 5), "glyph_them": Vector2i(5, 5),
		"ruin": Vector2i(0, 6), "crack": Vector2i(1, 6), "stone": Vector2i(2, 6), "moon": Vector2i(3, 6), "tower_plain": Vector2i(4, 6),
		"bolt": Vector2i(0, 7), "slash": Vector2i(1, 7), "burst_cast": Vector2i(2, 7), "charge": Vector2i(3, 7), "plus": Vector2i(4, 7), "tether_dot": Vector2i(5, 7),
		"trail": Vector2i(0, 8), "root": Vector2i(1, 8), "bar_bg": Vector2i(2, 8), "bar_fill": Vector2i(3, 8)}
## the size each kind is baked at (px); a sprite drawn at size px is scaled from it (effects: 56 px, rows 3 to 6)
const BAKED_PX := {"hero": 40.0, "minion": 14.0}
const FX_PX := 56.0
const LETTER := {"top": "T", "jg": "J", "mid": "M", "bot": "B", "sup": "S"}
const LABEL_SIZE := 24
const LABEL_OUTLINE := 5
const EDGE_LINE := Color(1, 1, 1, 0.18)    # ART-BIBLE 3.9; lanes use it pre-blended (EDGE_SOLID) so overlapping segments show no seams

var my_side := "B"
var flip := false
var zoom := 1.0
var focus := MAP / 2.0           # the camera centre, arena px of the view frame (already flipped)
var fallen: Dictionary = {}
var sprites: Array = []         # [ICON key, canonical point, size px, alpha], drawn after the towers (Choreo.sprites_at)
var sprites_under: Array = []   # drawn under the tokens (auras, winner rings; ArenaFx.under_at)
var sprites_over: Array = []    # drawn over the tokens (sparks, pings, towers falling; ArenaFx.over_at)
var arcs: Array = []            # [canonical centre, radius px, from, to, "you"/"them"] objective progress rings
var bars: Array = []            # [canonical point (the token), hp 0 to 1, "you"/"them", alpha] health bars (ArenaFx.bars_at)
var _vp: SubViewport
var _art: _Bake


func _init(p_my_side: String = "B") -> void:
	my_side = p_my_side
	flip = p_my_side == "R"
	size = MAP    # no minimum: in large text the arena is 626 x 661 (UI-PASS-2 6.7.7); the parent sets the size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true    # zoomed, tokens and towers near the edge must not spill over the scoreboard or the text strip
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_vp = SubViewport.new()
	_vp.size = BAKE
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_art = _Bake.new()
	_art.owner_map = self
	_vp.add_child(_art)
	add_child(_vp)


func texture() -> Texture2D:
	return _vp.get_texture()


## Draw the terrain again (after a change of side colours, e.g. colour-blind mode).
func rebake() -> void:
	_art.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func side_word(side: String) -> String:
	return "you" if side == my_side else "them"


func side_colour(side: String) -> Color:
	return UI.ACCENT if side == my_side else UI.CORAL


## Arena px of the view frame for a canonical point (flipped when the player is Red).
func arena_px(p: Vector2) -> Vector2:
	return ArenaData.screen(p, flip)


func look_at_point(p: Vector2, z: float) -> void:
	zoom = clampf(z, 1.0, float(ArenaData.data()["camera"]["focus"]["max_zoom"]))
	focus = p
	queue_redraw()


func reset_camera() -> void:
	look_at_point(MAP / 2.0, 1.0)


## The part of the arena (px of the view frame) that is on screen: centred on focus, clamped to the map.
func window() -> Rect2:
	var sz := MAP / zoom
	var pos := focus - sz / 2.0
	pos.x = clampf(pos.x, 0.0, MAP.x - sz.x)
	pos.y = clampf(pos.y, 0.0, MAP.y - sz.y)
	return Rect2(pos, sz)


func view_scale() -> Vector2:
	var w := window()
	var s := size if size.x > 0.0 and size.y > 0.0 else MAP
	return Vector2(s.x / w.size.x, s.y / w.size.y)


## Local px of this control for an arena px of the view frame.
func arena_to_local(q: Vector2) -> Vector2:
	return (q - window().position) * view_scale()


## Local px for a canonical point.
func to_view(p: Vector2) -> Vector2:
	return arena_to_local(arena_px(p))


## The strip cell of an ICON key (for other controls that draw from texture(), e.g. the HUD glyphs).
static func cell_rect(key: String) -> Rect2:
	var cell: Vector2i = ICON[key]
	return Rect2(Vector2(STRIP_X + float(cell.x) * CELL, float(cell.y) * CELL), Vector2(CELL, CELL))


func strip_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(STRIP_X + float(cell.x) * CELL, float(cell.y) * CELL), Vector2(CELL, CELL))


## The labels on screen now (ARENA-MAP 9.1): lane tags always, place names only at zoom 1.2 or more; a label that is not wholly
## inside the control is hidden. Each entry: {id, text, rect (local px)}.
func visible_labels() -> Array:
	var lab: Dictionary = ArenaData.data()["labels"]
	var from := float(lab.get("place_show_from_zoom", 1.2))
	var f := UI.font("Bold")
	var out: Array = []
	var box := Rect2(Vector2.ZERO, size if size.x > 0.0 else MAP)
	for it in lab["items"]:
		if String(it["kind"]) == "place" and zoom < from - 1e-6:
			continue
		var c := to_view(Vector2(float(it["c"][0]), float(it["c"][1])))
		var w := f.get_string_size(String(it["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x + float(LABEL_OUTLINE) * 2.0
		var r := Rect2(c - Vector2(w, float(LABEL_SIZE)) / 2.0, Vector2(w, float(LABEL_SIZE)))
		if box.encloses(r):
			out.append({"id": it["id"], "text": it["text"], "rect": r})
	return out


func _draw() -> void:
	var tex := texture()
	var s := size if size.x > 0.0 else MAP
	draw_texture_rect_region(tex, Rect2(Vector2.ZERO, s), window())
	var vs := view_scale()
	var opa := float(ArenaData.data()["look"].get("guard_tower_opacity", 0.55))
	var box := Rect2(Vector2.ZERO, s)
	for t in ArenaData.towers():
		var at := to_view(Vector2(float(t["p"][0]), float(t["p"][1])))
		var half := Vector2(CELL, CELL) * vs / 2.0
		if not box.grow(CELL).has_point(at):
			continue
		var who := side_word(String(t["side"]))
		var key := ("rubble_" if fallen.has(String(t["id"])) else "tower_") + who
		var guard := not bool(t.get("scoreboard", false))
		draw_texture_rect_region(tex, Rect2(at - half, half * 2.0), strip_rect(ICON[key]), Color(1, 1, 1, opa if guard else 1.0))
	_draw_sprites(tex, sprites_under, vs, box)
	_draw_sprites(tex, sprites, vs, box)
	_draw_bars(tex, vs, box)
	_draw_sprites(tex, sprites_over, vs, box)
	# the progress rings after every sprite (one texture run above stays unbroken; A-08): they circle the pit, outside the tokens
	for a in arcs:
		var ac := to_view(a[0])
		var col: Color = UI.ACCENT if String(a[4]) == "you" else UI.CORAL
		draw_arc(ac, float(a[1]) * vs.x, -PI / 2.0, -PI / 2.0 + TAU, 48, Color(UI.VOID, 0.6), 6.0 * vs.x, true)
		if float(a[3]) > 0.0:
			draw_arc(ac, float(a[1]) * vs.x, -PI / 2.0 + TAU * float(a[2]), -PI / 2.0 + TAU * float(a[3]), 48, col, 5.0 * vs.x, true)
	var f := UI.font("Bold")
	for l in visible_labels():
		var r: Rect2 = l["rect"]
		var base := Vector2(r.position.x + float(LABEL_OUTLINE), r.position.y + r.size.y / 2.0 + f.get_ascent(LABEL_SIZE) / 2.0 - 2.0)
		draw_string_outline(f, base, String(l["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LABEL_OUTLINE * 2, UI.VOID)
		draw_string(f, base, String(l["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, UI.TEXT)


func _draw_sprites(tex: Texture2D, list: Array, vs: Vector2, box: Rect2) -> void:
	for sp in list:
		var at := to_view(sp[1])
		var key := String(sp[0])
		var baked := FX_PX
		if key.begins_with("hero"):
			baked = float(BAKED_PX["hero"])
		elif key.begins_with("minion"):
			baked = float(BAKED_PX["minion"])
		var half := Vector2(CELL, CELL) * vs * (float(sp[2]) / baked) / 2.0
		if box.grow(half.x + CELL).has_point(at) and float(sp[3]) > 0.0:
			draw_texture_rect_region(tex, Rect2(at - half, half * 2.0), strip_rect(ICON[key]), Color(1, 1, 1, clampf(float(sp[3]), 0.0, 1.0)))


## Health bars above the tokens (ACTION-VOCABULARY 11.4): a dark back and a fill in the side colour, both regions of solid cells of
## the strip (sampled inside the cell, so no edge bleeds), so they batch with the tokens.
func _draw_bars(tex: Texture2D, vs: Vector2, box: Rect2) -> void:
	if bars.is_empty():
		return
	var hp: Dictionary = ArenaActions.data()["hp"]
	var bw := float(hp["bar_px"][0]) * vs.x
	var bh := float(hp["bar_px"][1]) * vs.y
	var up := float(hp["bar_above_px"]) * vs.y
	var back := strip_rect(ICON["bar_bg"]).grow(-20.0)
	var fill := strip_rect(ICON["bar_fill"]).grow(-20.0)
	for b in bars:
		var at := to_view(b[0]) - Vector2(0, up)
		if not box.grow(bw).has_point(at):
			continue
		var al := clampf(float(b[3]), 0.0, 1.0)
		var r := Rect2(at - Vector2(bw / 2.0 + 2.0, bh / 2.0 + 2.0), Vector2(bw + 4.0, bh + 4.0))
		draw_texture_rect_region(tex, r, back, Color(1, 1, 1, 0.85 * al))
		var w := bw * clampf(float(b[1]), 0.0, 1.0)
		if w > 0.5:
			var col: Color = UI.ACCENT if String(b[2]) == "you" else UI.CORAL
			draw_texture_rect_region(tex, Rect2(at - Vector2(bw / 2.0, bh / 2.0), Vector2(w, bh)), fill, Color(col, al))


## The one-time drawing of the terrain and the icon strip (inside the SubViewport).
class _Bake extends Node2D:
	var owner_map: ArenaMap

	func P(p: Array) -> Vector2:
		return owner_map.arena_px(Vector2(float(p[0]), float(p[1])))

	func ring(c: Vector2, r: float, w: float, col: Color) -> void:
		draw_arc(c, r, 0.0, TAU, 64, col, w, true)

	func _draw() -> void:
		var d := ArenaData.data()
		draw_rect(Rect2(Vector2.ZERO, Vector2(owner_map.BAKE)), Color(0, 0, 0, 0))
		draw_rect(Rect2(Vector2.ZERO, ArenaMap.MAP), UI.MAP_LAND)
		var zones: Array = d["zones"]
		# base yards (a faint side tint) and the jungle pockets (the jungle colour at 7 percent)
		for side in ["B", "R"]:
			var cairn := P(d["bases"][side]["cairn"])
			var yard := float(d["bases"][side]["yard_r_u"]) * ArenaData.H
			var tint := owner_map.side_colour(side)
			draw_circle(cairn, yard, Color(tint.r, tint.g, tint.b, 0.06))
		for z in zones:
			if String(z["kind"]) == "jungle":
				draw_circle(P(z["c"]), float(z["r_px"]), Color(UI.ROLE_JUNGLE.r, UI.ROLE_JUNGLE.g, UI.ROLE_JUNGLE.b, 0.07))
			elif String(z["kind"]) == "fight" and String(z["id"]) != "moonhulk_isle":
				draw_circle(P(z["c"]), float(z["r_px"]), Color(UI.PANEL2.r, UI.PANEL2.g, UI.PANEL2.b, 0.45))
		# the Mere and its shore
		var mere: Dictionary = d["terrain"]["mere"]
		var mc := P(mere["c"])
		draw_circle(mc, float(mere["r_px"]), UI.MAP_MERE)
		ring(mc, float(mere["r_px"]), 3.0, UI.MAP_SHORE)
		var rip := Color(UI.MAP_SHORE.r, UI.MAP_SHORE.g, UI.MAP_SHORE.b, 0.45)
		for a in [0.35, 2.4, 3.9, 5.3]:
			draw_arc(mc, float(mere["r_px"]) - 24.0, a, a + 0.5, 12, rip, 2.0, true)
		# trails: every edge that is not a step along a lane, dotted
		var lane_steps := {}
		for ln in d["lanes"]:
			var ns: Array = ln["nodes"]
			for i in range(1, ns.size()):
				lane_steps[String(ns[i - 1]) + "|" + String(ns[i])] = true
				lane_steps[String(ns[i]) + "|" + String(ns[i - 1])] = true
		var dot := Color(UI.TEXT2.r, UI.TEXT2.g, UI.TEXT2.b, 0.28)
		for e in d["edges"]:
			if lane_steps.has(String(e["a"]) + "|" + String(e["b"])):
				continue
			var a := owner_map.arena_px(ArenaData.node(String(e["a"])))
			var b := owner_map.arena_px(ArenaData.node(String(e["b"])))
			var n := int(a.distance_to(b) / 14.0)
			for k in range(1, n):
				draw_circle(a.lerp(b, float(k) / float(n)), 2.0, dot)
		# lanes: a 2 px white edge line each side, then the road
		for ln in d["lanes"]:
			var pts := PackedVector2Array()
			for id in ln["nodes"]:
				pts.append(owner_map.arena_px(ArenaData.node(String(id))))
			var w := float(ln["width_px"])
			var edge := UI.MAP_LAND.lerp(Color.WHITE, EDGE_LINE.a)
			draw_polyline(pts, edge, w + 4.0, false)
			for p in pts:
				draw_circle(p, (w + 4.0) / 2.0, edge)
		for ln in d["lanes"]:
			var pts2 := PackedVector2Array()
			for id in ln["nodes"]:
				pts2.append(owner_map.arena_px(ArenaData.node(String(id))))
			var w2 := float(ln["width_px"])
			draw_polyline(pts2, UI.PANEL3, w2, false)
			for p in pts2:
				draw_circle(p, w2 / 2.0, UI.PANEL3)
		# the island and the base plazas
		var isl: Dictionary = d["terrain"]["island"]
		draw_circle(P(isl["c"]), float(isl["r_px"]), UI.PANEL2)
		ring(P(isl["c"]), float(isl["r_px"]), 3.0, UI.MAP_SHORE)
		for z in zones:
			if String(z["kind"]) == "base":
				draw_circle(P(z["c"]), float(z["r_px"]), UI.PANEL2)
				ring(P(z["c"]), float(z["r_px"]), 2.0, EDGE_LINE)
		# spawn pads
		var pad := float(d["spawns"].get("pad_r_px", 26))
		for side in ["B", "R"]:
			for slot in ["top", "jg", "mid", "bot", "sup"]:
				var sp := P(d["spawns"][side][slot])
				draw_circle(sp, pad - 4.0, Color(UI.VOID, 0.45))
				ring(sp, pad - 5.0, 2.0, Color(owner_map.side_colour(side), 0.55))
		# camps
		var icons: Dictionary = d["icons_px"]
		for c in d["camps"]:
			var at := P(c["p"])
			var kind := String(c["kind"])
			var r := float(icons.get("camp_" + kind, icons.get("mossback", 36))) / 2.0
			draw_circle(at, r, UI.VOID)
			_camp_mark(at, r, kind)
		# objectives: Stoneback (rhombus), Moonhulk (disc and crescent), the two Cairns
		for o in d["objectives"]:
			var at2 := P(o["p"])
			var r2 := float(o.get("icon_px", 48)) / 2.0
			match String(o["shape"]):
				"rhombus":
					var rh := PackedVector2Array([at2 + Vector2(0, -r2), at2 + Vector2(r2, 0), at2 + Vector2(0, r2), at2 + Vector2(-r2, 0)])
					draw_colored_polygon(rh, UI.VOID)
					rh.append(rh[0])
					draw_polyline(rh, UI.WARN, 3.5, true)
					for k in 3:    # the shell mark, a fan of three strokes
						var ang := -PI / 2.0 + (float(k) - 1.0) * 0.5
						draw_line(at2 + Vector2(0, 8), at2 + Vector2(0, 8) + Vector2.from_angle(ang) * 15.0, UI.WARN, 3.0, true)
				"disc":
					draw_circle(at2, r2, UI.VOID)
					ring(at2, r2 - 1.75, 3.5, UI.TEXT2)
					draw_circle(at2 + Vector2(-3, 0), 12.0, UI.TEXT)
					draw_circle(at2 + Vector2(3, -3), 11.0, UI.VOID)
				_:
					var sd := String(o.get("side", "N"))
					draw_circle(at2, r2, UI.VOID)
					ring(at2, r2 - 1.75, 3.5, owner_map.side_colour(sd))
					for k2 in 3:    # stacked stones
						var y := 10.0 - 9.0 * float(k2)
						var hw := 14.0 - 3.0 * float(k2)
						draw_colored_polygon(_oval(at2 + Vector2(0, y), hw, 4.5), UI.TEXT2)
		# the icon strip: towers intact and rubble, for you and them
		for key in ["tower_you", "tower_them", "rubble_you", "rubble_them"]:
			var cell: Vector2i = ArenaMap.ICON[key]
			var c2 := owner_map.strip_rect(cell).get_center()
			var col := UI.ACCENT if key.ends_with("you") else UI.CORAL
			var tr := float(icons.get("tower", 28)) / 2.0
			draw_circle(c2, tr, UI.VOID)
			if key.begins_with("tower"):
				ring(c2, tr - 1.5, 3.0, col)
				draw_rect(Rect2(c2 + Vector2(-4, -6), Vector2(8, 13)), UI.TEXT)
				draw_rect(Rect2(c2 + Vector2(-6, -9), Vector2(12, 4)), UI.TEXT)
			else:
				ring(c2, tr - 1.5, 2.0, Color(col, 0.45))
				draw_rect(Rect2(c2 + Vector2(-6, 2), Vector2(5, 4)), UI.TEXT_OFF)
				draw_rect(Rect2(c2 + Vector2(1, 0), Vector2(5, 6)), UI.TEXT_OFF)
		# minion dots: a circle for you, a small hexagon for them (shape and colour, rule H6)
		var mc2 := owner_map.strip_rect(ArenaMap.ICON["minion_you"]).get_center()
		draw_circle(mc2, 7.0, UI.ACCENT)
		draw_colored_polygon(_hex(owner_map.strip_rect(ArenaMap.ICON["minion_them"]).get_center(), 7.5), UI.CORAL)
		# hero tokens (ARENA-MAP 9.2): you a solid teal circle, them a solid coral flat-top hexagon, a 3 px TEXT rim at 70 percent,
		# the slot letter in ink
		var lf := UI.font("Bold")
		var rim := Color(UI.TEXT, 0.7)
		for slot in ["top", "jg", "mid", "bot", "sup"]:
			for who in ["you", "them"]:
				var hc := owner_map.strip_rect(ArenaMap.ICON["hero_%s_%s" % [who, slot]]).get_center()
				if who == "you":
					draw_circle(hc, 20.0, UI.ACCENT)
					draw_arc(hc, 18.5, 0.0, TAU, 40, rim, 3.0, true)
				else:
					var hx := _hex(hc, 21.0)
					draw_colored_polygon(hx, UI.CORAL)
					hx.append(hx[0])
					draw_polyline(_hex(hc, 19.5) + PackedVector2Array([_hex(hc, 19.5)[0]]), rim, 3.0, true)
				var letter: String = ArenaMap.LETTER[slot]
				var ink := UI.INK_TEAL if who == "you" else UI.INK_CORAL
				var sz := lf.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
				draw_string(lf, hc + Vector2(-sz.x / 2.0, lf.get_ascent(24) / 2.0 - 3.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
		_bake_fx()

	func _cell(key: String) -> Vector2:
		return owner_map.strip_rect(ArenaMap.ICON[key]).get_center()

	## Effect art (A-04), each about 56 px in its 64 px cell. Hit colours per ACTION-VOCABULARY 3.1: physical = WARN mixed toward
	## TEXT (a sharp spark), magic = TEXT2 (a soft ring); never teal or coral, which mean the two sides.
	func _bake_fx() -> void:
		var phys := UI.WARN.lerp(UI.TEXT, 0.4)
		var c := _cell("spark")
		var star := PackedVector2Array()
		for i in 8:
			var a := TAU * float(i) / 8.0
			star.append(c + Vector2.from_angle(a) * (26.0 if i % 2 == 0 else 8.0))
		draw_colored_polygon(star, phys)
		c = _cell("ring_magic")
		draw_arc(c, 22.0, 0.0, TAU, 40, Color(UI.TEXT2, 0.9), 5.0, true)
		draw_arc(c, 14.0, 0.0, TAU, 32, Color(UI.TEXT2, 0.4), 3.0, true)
		c = _cell("skull")
		draw_circle(c + Vector2(0, -3), 14.0, UI.TEXT)
		draw_rect(Rect2(c + Vector2(-8, 6), Vector2(16, 9)), UI.TEXT)
		draw_circle(c + Vector2(-5, -4), 4.0, UI.VOID)
		draw_circle(c + Vector2(5, -4), 4.0, UI.VOID)
		draw_rect(Rect2(c + Vector2(-1, 9), Vector2(2, 6)), UI.VOID)
		c = _cell("motes")
		for m in [Vector2(-12, 8), Vector2(0, -6), Vector2(11, 4), Vector2(-4, -18), Vector2(8, -16)]:
			draw_circle(c + m, 3.5, Color(UI.TEXT, 0.85))
		c = _cell("flash")
		draw_circle(c, 26.0, Color(UI.TEXT, 0.25))
		draw_circle(c, 17.0, Color(UI.TEXT, 0.5))
		draw_circle(c, 9.0, Color(UI.TEXT, 0.9))
		c = _cell("dust")
		draw_arc(c, 20.0, 0.0, TAU, 32, Color(UI.TEXT_OFF, 0.8), 8.0, true)
		for side in ["you", "them"]:
			var col := UI.ACCENT if side == "you" else UI.CORAL
			c = _cell("aura_" + side)
			if side == "you":
				draw_circle(c, 26.0, Color(col, 0.18))
				draw_arc(c, 24.0, 0.0, TAU, 40, Color(col, 0.7), 4.0, true)
			else:
				draw_colored_polygon(_hex(c, 27.0), Color(col, 0.18))
				var hx := _hex(c, 25.0)
				hx.append(hx[0])
				draw_polyline(hx, Color(col, 0.7), 4.0, true)
			c = _cell("ring_" + side)
			if side == "you":
				draw_arc(c, 25.0, 0.0, TAU, 48, col, 4.0, true)
			else:
				var hx2 := _hex(c, 27.0)
				hx2.append(hx2[0])
				draw_polyline(hx2, col, 4.0, true)
			for dir in ["up", "down"]:
				c = _cell("arrow_%s_%s" % [dir, side])
				var sgn := -1.0 if dir == "up" else 1.0
				var tip := c + Vector2(0, 24.0 * sgn)
				draw_colored_polygon(PackedVector2Array([tip, c + Vector2(-16, 4.0 * sgn), c + Vector2(16, 4.0 * sgn)]), col)
				draw_rect(Rect2(c + Vector2(-6, -24.0 if dir == "down" else 4.0), Vector2(12, 20)), col)
			c = _cell("glyph_" + side)
			if side == "you":
				draw_circle(c, 24.0, UI.VOID)
				draw_circle(c, 18.0, col)
			else:
				draw_colored_polygon(_hex(c, 26.0), UI.VOID)
				draw_colored_polygon(_hex(c, 20.0), col)
		for b in [["burst_amber", UI.WARN], ["burst_pale", UI.TEXT2]]:
			c = _cell(String(b[0]))
			draw_arc(c, 22.0, 0.0, TAU, 40, b[1], 5.0, true)
			for i2 in 8:
				var a2 := TAU * float(i2) / 8.0
				draw_line(c + Vector2.from_angle(a2) * 24.0, c + Vector2.from_angle(a2) * 30.0, b[1], 3.0, true)
		c = _cell("ruin")
		draw_circle(c, 26.0, UI.VOID)
		for st in [[Vector2(-9, 6), 7.0], [Vector2(8, 8), 6.0], [Vector2(-2, -6), 5.0], [Vector2(12, -4), 4.0]]:
			draw_circle(c + st[0], st[1], UI.TEXT_OFF)
		# scoreboard glyphs (A-05): Stoneback, Moonhulk and a plain tower, in neutral colours (the owner's shape goes beside them)
		c = _cell("stone")
		var rh := PackedVector2Array([c + Vector2(0, -24), c + Vector2(24, 0), c + Vector2(0, 24), c + Vector2(-24, 0)])
		draw_colored_polygon(rh, UI.VOID)
		rh.append(rh[0])
		draw_polyline(rh, UI.WARN, 4.0, true)
		c = _cell("moon")
		draw_circle(c, 24.0, UI.VOID)
		draw_arc(c, 22.0, 0.0, TAU, 40, UI.TEXT2, 4.0, true)
		draw_circle(c + Vector2(-3, 0), 12.0, UI.TEXT)
		draw_circle(c + Vector2(3, -3), 11.0, UI.VOID)
		c = _cell("tower_plain")
		draw_rect(Rect2(c + Vector2(-8, -12), Vector2(16, 30)), UI.TEXT)
		draw_rect(Rect2(c + Vector2(-13, -20), Vector2(26, 10)), UI.TEXT)
		draw_rect(Rect2(c + Vector2(-3, 6), Vector2(6, 12)), UI.VOID)
		_bake_actions()
		c = _cell("crack")
		var zz := PackedVector2Array([c + Vector2(-4, -22), c + Vector2(4, -10), c + Vector2(-5, 0), c + Vector2(5, 10), c + Vector2(-2, 22)])
		draw_polyline(zz, UI.TEXT, 3.0, true)
		draw_line(c + Vector2(-5, 0), c + Vector2(-16, 6), UI.TEXT, 2.5, true)
		draw_line(c + Vector2(4, -10), c + Vector2(15, -14), UI.TEXT, 2.5, true)

	## The Fight pass cells (ACTION-VOCABULARY 11.2): neutral colours only (teal and coral mean the two sides), a shape each.
	func _bake_actions() -> void:
		var phys := UI.WARN.lerp(UI.TEXT, 0.4)
		var c := _cell("bolt")    # a glowing round bolt (no direction, so it never needs rotating)
		draw_circle(c, 13.0, Color(UI.TEXT, 0.25))
		draw_circle(c, 8.0, phys)
		draw_circle(c, 3.5, UI.TEXT)
		c = _cell("slash")    # a crescent swipe
		draw_arc(c, 20.0, -2.5, -0.6, 20, phys, 7.0, true)
		draw_arc(c, 13.0, -2.3, -0.8, 16, Color(UI.TEXT, 0.8), 3.0, true)
		c = _cell("burst_cast")    # a ring with eight sparks round it
		draw_arc(c, 20.0, 0.0, TAU, 40, UI.TEXT2, 6.0, true)
		for i in 8:
			var a := TAU * float(i) / 8.0 + 0.39
			draw_circle(c + Vector2.from_angle(a) * 27.0, 2.5, UI.TEXT)
		c = _cell("charge")    # a gathering glow
		draw_circle(c, 24.0, Color(UI.TEXT2, 0.2))
		draw_circle(c, 15.0, Color(UI.TEXT2, 0.45))
		draw_arc(c, 24.0, 0.0, TAU, 32, Color(UI.TEXT2, 0.8), 2.5, true)
		c = _cell("plus")    # a heal: a plus with a dark rim
		draw_rect(Rect2(c + Vector2(-6, -18), Vector2(12, 36)), UI.VOID)
		draw_rect(Rect2(c + Vector2(-18, -6), Vector2(36, 12)), UI.VOID)
		draw_rect(Rect2(c + Vector2(-4, -16), Vector2(8, 32)), UI.GOOD_DEFAULT)
		draw_rect(Rect2(c + Vector2(-16, -4), Vector2(32, 8)), UI.GOOD_DEFAULT)
		c = _cell("tether_dot")
		draw_circle(c, 9.0, Color(UI.TEXT2, 0.9))
		draw_circle(c, 4.0, UI.TEXT)
		c = _cell("trail")    # motion: dashes round the token
		for i2 in 8:
			var a2 := TAU * float(i2) / 8.0
			draw_arc(c, 26.0, a2, a2 + 0.45, 6, Color(UI.TEXT, 0.75), 3.0, true)
		c = _cell("root")    # a snare: a ring with thorns pointing in
		draw_arc(c, 22.0, 0.0, TAU, 40, UI.TEXT2, 3.5, true)
		for i3 in 6:
			var a3 := TAU * float(i3) / 6.0
			draw_line(c + Vector2.from_angle(a3) * 22.0, c + Vector2.from_angle(a3) * 13.0, UI.TEXT2, 3.0, true)
		c = _cell("bar_bg")
		draw_rect(Rect2(c - Vector2(26, 26), Vector2(52, 52)), UI.VOID)
		c = _cell("bar_fill")
		draw_rect(Rect2(c - Vector2(26, 26), Vector2(52, 52)), Color.WHITE)

	func _hex(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 6:
			var a := TAU * float(i) / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		return pts

	func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * float(i) / 16.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return pts

	func _camp_mark(at: Vector2, r: float, kind: String) -> void:
		var col := UI.ROLE_JUNGLE
		match kind:
			"moss":    # a leaf
				var leaf := PackedVector2Array()
				for i in 12:
					var t := float(i) / 11.0
					leaf.append(at + Vector2(lerpf(-r * 0.6, r * 0.6, t), -sin(t * PI) * r * 0.45))
				for i in range(10, 0, -1):
					var t2 := float(i) / 11.0
					leaf.append(at + Vector2(lerpf(-r * 0.6, r * 0.6, t2), sin(t2 * PI) * r * 0.45))
				draw_colored_polygon(leaf, col)
			"bramble":    # a wheel
				draw_arc(at, r * 0.55, 0.0, TAU, 24, col, 2.5, true)
				for k in 4:
					var a := PI / 4.0 * float(k)
					draw_line(at - Vector2.from_angle(a) * r * 0.55, at + Vector2.from_angle(a) * r * 0.55, col, 2.0, true)
			_:    # the Mossback dome
				var dome := PackedVector2Array()
				for i in 13:
					var a2 := PI + PI * float(i) / 12.0
					dome.append(at + Vector2(0, r * 0.3) + Vector2(cos(a2), sin(a2)) * r * 0.65)
				draw_colored_polygon(dome, col)
