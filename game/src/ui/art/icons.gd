class_name Icons
extends RefCounted
## Every icon the screens draw that is not a font (the font has no arrow, tick, cross or star: ART-BIBLE 5.1).
##
##   Icons.draw(ci, id, rect, colour, accent)   draws one icon into `rect` of a CanvasItem, tinted. Normal route: one or two
##                                              quads of a shared atlas (one draw call for any number of icons per size).
##   Icons.tex(id, size)                        one white texture of the icon, for a TextureRect, Button icon or Theme icon
##   Icons.switch_icon(on, disabled)            the Settings switch (moved here from ui.gd, same pixels)
##
## Style (ART-BIBLE 6.1): 48 px grid, 4 px stroke, round caps and joins, one accent fragment. Tones: "m" the main stroke,
## "d" a dimmed context stroke (40 percent), "a" the accent fragment. `colour` tints m and d, `accent` tints a (when it is
## transparent, a takes `colour`). The five role glyphs are the SVG files of docs/design/art (ic_role_*.svg) embedded as
## strings (a raw .svg in res:// is not in the exported package, only its import), so a test compares them with the files.
## Shapes are original: generic geometric marks, no letter forms and no mark of any other game.

const BOX := 48.0
const IDS := ["role_top", "role_jg", "role_mid", "role_bot", "role_sup",
	"tab_home", "tab_squad", "tab_plan", "tab_club", "tab_more",
	"fatigue", "form", "morale", "contract", "cash",
	"ban", "pick", "lock", "play", "skip", "speed", "help", "back", "close",
	"trophy", "star", "arrow_up", "arrow_down", "arrow_flat", "tick", "cross", "coin", "clock",
	"flag_blue", "flag_red", "warning", "chevron_r", "chevron_l", "chevron_u", "chevron_d", "side_you", "side_them"]
const SIZES := [32, 48, 96]            # atlas cell sizes; an icon is drawn from the smallest cell that is not smaller (up to 56 from 48)

const ROLE_SVG := {
	"role_top": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"48\" height=\"48\" viewBox=\"0 0 48 48\"><title>Role glyph top (Lane Bows, from the Wrenfell lanes)</title><g transform=\"translate(24 24) scale(0.92) translate(-24 -24)\"><path d=\"M24 6 V42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-opacity=\"0.4\" stroke-width=\"4.0\"/><path d=\"M32 6 C45 17 45 31 32 42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-opacity=\"0.4\" stroke-width=\"4.0\"/><path d=\"M16 6 C3 17 3 31 16 42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-width=\"5.0\"/></g></svg>",
	"role_jg": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"48\" height=\"48\" viewBox=\"0 0 48 48\"><title>Role glyph jungle (Lane Bows, from the Wrenfell lanes)</title><g transform=\"translate(24 24) scale(0.92) translate(-24 -24)\"><path d=\"M16 6 C3 17 3 31 16 42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-opacity=\"0.4\" stroke-width=\"4.0\"/><path d=\"M24 6 V42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-opacity=\"0.4\" stroke-width=\"4.0\"/><path d=\"M32 6 C45 17 45 31 32 42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-opacity=\"0.4\" stroke-width=\"4.0\"/><path d=\"M15 15.5 L20.5 24 L15 32.5 L9.5 24 Z\" fill=\"#FFFFFF\" stroke=\"#FFFFFF\" stroke-width=\"2\" stroke-linejoin=\"round\"/><path d=\"M33 17.5 L37 24 L33 30.5 L29 24 Z\" fill=\"#FFFFFF\" stroke=\"#FFFFFF\" stroke-width=\"2\" stroke-linejoin=\"round\"/></g></svg>",
	"role_mid": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"48\" height=\"48\" viewBox=\"0 0 48 48\"><title>Role glyph mid (Lane Bows, from the Wrenfell lanes)</title><g transform=\"translate(24 24) scale(0.92) translate(-24 -24)\"><path d=\"M16 6 C3 17 3 31 16 42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-opacity=\"0.4\" stroke-width=\"4.0\"/><path d=\"M32 6 C45 17 45 31 32 42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-opacity=\"0.4\" stroke-width=\"4.0\"/><path d=\"M24 6 V17 M24 31 V42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-width=\"5.0\"/><circle cx=\"24\" cy=\"24\" r=\"6.5\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-width=\"4.0\"/></g></svg>",
	"role_bot": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"48\" height=\"48\" viewBox=\"0 0 48 48\"><title>Role glyph bot (Lane Bows, from the Wrenfell lanes)</title><g transform=\"translate(24 24) scale(0.92) translate(-24 -24)\"><path d=\"M16 6 C3 17 3 31 16 42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-opacity=\"0.4\" stroke-width=\"4.0\"/><path d=\"M24 6 V42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-opacity=\"0.4\" stroke-width=\"4.0\"/><path d=\"M32 6 C45 17 45 31 32 42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-width=\"5.0\"/><circle cx=\"41.5\" cy=\"24\" r=\"5.2\" fill=\"#FFFFFF\" stroke=\"none\"/></g></svg>",
	"role_sup": "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"48\" height=\"48\" viewBox=\"0 0 48 48\"><title>Role glyph support (Lane Bows, from the Wrenfell lanes)</title><g transform=\"translate(24 24) scale(0.92) translate(-24 -24)\"><path d=\"M16 6 C3 17 3 31 16 42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-opacity=\"0.4\" stroke-width=\"4.0\"/><path d=\"M24 6 V42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-opacity=\"0.4\" stroke-width=\"4.0\"/><path d=\"M32 6 C45 17 45 31 32 42\" fill=\"none\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke=\"#FFFFFF\" stroke-width=\"5.0\"/><path d=\"M35 24 H47 M41.5 18 V30\" fill=\"none\" stroke=\"#FFFFFF\" stroke-width=\"4.2\" stroke-linecap=\"round\"/></g></svg>",
}

static var _ops: Dictionary = {}


static func has(id: String) -> bool:
	return IDS.has(id)


static func role_id(role: String) -> String:
	return "role_" + role


## The ops of a drawn icon ({} for a role glyph, which is an SVG string).
static func ops_of(id: String) -> Array:
	if _ops.is_empty():
		_ops = _build_ops()
	return _ops.get(id, [])


static func svg_of(id: String) -> String:
	return ROLE_SVG.get(id, "")


static func _cell_for(px: float) -> int:
	if px <= 40.0:
		return 32
	if px <= 56.0:
		return 48
	return 96


## The atlas of one cell size (built on first use; cached in TexCache). Cells: "<id>#m" (m and d tones, white) and "<id>#a"
## (accent only, white) for icons that have an accent fragment. Role glyphs have "#m" only.
static func atlas(cell: int) -> Dictionary:
	if TexCache.has("icons@%d" % cell):
		return TexCache.atlas("icons@%d" % cell, [], BOX, cell, 8)    # a hit; the cells are not rebuilt
	var white := {"m": Color.WHITE, "d": Color(1, 1, 1, 0.4)}
	var acc := {"a": Color.WHITE}
	var cells: Array = []
	for id in IDS:
		if ROLE_SVG.has(id):
			cells.append({"key": id + "#m", "svg": ROLE_SVG[id]})
			continue
		var ops := ops_of(id)
		cells.append({"key": id + "#m", "svg": VecOps.to_svg(ops, BOX, white)})
		if VecOps.has_tone(ops, "a"):
			cells.append({"key": id + "#a", "svg": VecOps.to_svg(ops, BOX, acc)})
	return TexCache.atlas("icons@%d" % cell, cells, BOX, cell, 8)


static func draw(ci: CanvasItem, id: String, rect: Rect2, colour: Color = Color.WHITE, accent: Color = Color(0, 0, 0, 0)) -> void:
	if not IDS.has(id):
		return
	var acc := accent if accent.a > 0.0 else colour
	var a := atlas(_cell_for(minf(rect.size.x, rect.size.y)))
	var rects: Dictionary = a["rects"]
	var failed: Array = a["failed"]
	if failed.has(id + "#m"):
		_draw_fallback(ci, id, rect, colour, acc)
		return
	ci.draw_texture_rect_region(a["tex"], rect, rects[id + "#m"], colour)
	if rects.has(id + "#a") and not failed.has(id + "#a"):
		ci.draw_texture_rect_region(a["tex"], rect, rects[id + "#a"], acc)


static func _draw_fallback(ci: CanvasItem, id: String, rect: Rect2, colour: Color, acc: Color) -> void:
	var ops := ops_of(id)
	if ops.is_empty():    # a role glyph: three bows as lines, enough to show something
		ops = ops_of("fallback_" + id)
	VecOps.draw(ci, ops, BOX, rect, {"m": colour, "d": Color(colour.r, colour.g, colour.b, colour.a * 0.4), "a": acc})


## One white texture of the icon at `size` px (a TextureRect or Button tints it with modulate). Cached per id and size.
static func tex(id: String, size: int) -> Texture2D:
	var key := "icon:%s@%d" % [id, size]
	if ROLE_SVG.has(id):
		return TexCache.svg_tex(key, ROLE_SVG[id], BOX, size)
	var tones := {"m": Color.WHITE, "d": Color(1, 1, 1, 0.4), "a": Color.WHITE}
	return TexCache.svg_tex(key, VecOps.to_svg(ops_of(id), BOX, tones), BOX, size)


# ---- the drawn icons -----------------------------------------------------------------------------------------------

static func _star(cx: float, cy: float, ro: float, ri: float) -> Array:
	var pts: Array = []
	for i in 10:
		var a := -PI / 2.0 + PI * float(i) / 5.0
		var r := ro if i % 2 == 0 else ri
		pts.append(cx + cos(a) * r)
		pts.append(cy + sin(a) * r)
	return pts


static func _hex(cx: float, cy: float, r: float) -> Array:    # flat-top hexagon, point to point 2 r
	var pts: Array = []
	for i in 6:
		var a := PI / 3.0 * float(i)
		pts.append(cx + cos(a) * r)
		pts.append(cy + sin(a) * r)
	return pts


static func _build_ops() -> Dictionary:
	var o := {}
	# arrows and marks: the three cues next to a number are sign, arrow and word (ART-BIBLE 3.6)
	o["arrow_up"] = [["R", [24, 13, 38, 35, 10, 35], 4, "m"]]
	o["arrow_down"] = [["R", [24, 35, 38, 13, 10, 13], 4, "m"]]
	o["arrow_flat"] = [["l", [9, 24, 39, 24], 7, "m"]]
	o["tick"] = [["l", [10, 25, 20, 35, 38, 13], 5, "m"]]
	o["cross"] = [["l", [13, 13, 35, 35], 5, "m"], ["l", [35, 13, 13, 35], 5, "m"]]
	o["close"] = o["cross"]
	o["star"] = [["R", _star(24, 25, 17, 7.5), 3, "a"]]
	o["chevron_r"] = [["l", [17, 10, 31, 24, 17, 38], 5, "m"]]
	o["chevron_l"] = [["l", [31, 10, 17, 24, 31, 38], 5, "m"]]
	o["chevron_u"] = [["l", [10, 31, 24, 17, 38, 31], 5, "m"]]
	o["chevron_d"] = [["l", [10, 17, 24, 31, 38, 17], 5, "m"]]
	o["warning"] = [["L", [24, 9, 41, 39, 7, 39], 4, "m"], ["l", [24, 20, 24, 29], 4, "a"], ["c", 24, 34.5, 2.4, "a"]]
	o["side_you"] = [["c", 24, 24, 16, "m"]]
	o["side_them"] = [["f", _hex(24, 24, 17.6), "m"]]
	o["flag_blue"] = [["l", [12, 8, 12, 41], 4, "m"], ["R", [16, 11, 39, 18.5, 16, 26], 3, "a"]]
	o["flag_red"] = [["l", [12, 8, 12, 41], 4, "m"], ["R", [16, 11, 39, 11, 31, 18.5, 39, 26, 16, 26], 3, "a"]]
	# actions
	o["ban"] = [["o", 24, 24, 17, 4, "m"], ["l", [12, 36, 36, 12], 4, "a"]]
	o["pick"] = [["o", 24, 24, 17, 4, "m"], ["c", 24, 24, 6.5, "a"]]
	o["lock"] = [["R", [13, 23, 35, 23, 35, 40, 13, 40], 3, "m"], ["a", 24, 22, 8.5, 180, 360, 4, "m"], ["c", 24, 31.5, 2.6, "a"]]
	o["play"] = [["R", [15, 10, 39, 24, 15, 38], 4, "m"]]
	o["skip"] = [["R", [9, 12, 30, 24, 9, 36], 3.5, "m"], ["l", [38, 11, 38, 37], 5, "a"]]
	o["speed"] = [["R", [7, 14, 22, 24, 7, 34], 3, "m"], ["R", [25, 14, 40, 24, 25, 34], 3, "a"]]
	o["help"] = [["a", 24, 18, 8.5, 180, 390, 4.5, "m"], ["l", [31.3, 22.3, 24, 28, 24, 31], 4.5, "m"], ["c", 24, 39, 2.8, "a"]]
	o["back"] = [["l", [39, 24, 10, 24], 4.5, "m"], ["l", [20, 14, 10, 24, 20, 34], 4.5, "a"]]
	# misc
	o["coin"] = [["o", 24, 24, 17, 4, "m"], ["o", 24, 24, 8, 3, "a"]]
	o["clock"] = [["o", 24, 24, 17, 4, "m"], ["l", [24, 13, 24, 24, 31, 28], 4, "a"]]
	o["trophy"] = [["R", [14, 9, 34, 9, 34, 18, 24, 29, 14, 18], 3, "m"], ["l", [14, 13, 8, 13, 8, 19, 15, 25], 3.5, "m"],
		["l", [34, 13, 40, 13, 40, 19, 33, 25], 3.5, "m"], ["l", [24, 29, 24, 36], 4, "m"], ["l", [15, 40, 33, 40], 5, "a"]]
	# tabs
	o["tab_home"] = [["l", [7, 23, 24, 8, 41, 23], 4, "m"], ["l", [12, 20, 12, 39, 36, 39, 36, 20], 4, "m"], ["l", [21, 39, 21, 30, 27, 30, 27, 39], 3.5, "a"]]
	o["tab_squad"] = [["o", 24, 17, 6.5, 4, "m"], ["a", 24, 41, 13, 200, 340, 4, "m"], ["o", 9.5, 21, 4, 3.2, "d"], ["o", 38.5, 21, 4, 3.2, "d"],
		["a", 9.5, 40, 7, 215, 325, 3.2, "d"], ["a", 38.5, 40, 7, 215, 325, 3.2, "d"], ["c", 24, 17, 2.6, "a"]]
	o["tab_plan"] = [["L", [11, 9, 37, 9, 37, 41, 11, 41], 4, "m"], ["l", [18, 19, 30, 19], 4, "m"], ["l", [18, 27, 30, 27], 4, "m"], ["l", [18, 35, 25, 35], 4, "a"]]
	o["tab_club"] = [["L", [10, 9, 38, 9, 38, 26, 24, 41, 10, 26], 4, "m"], ["c", 24, 22, 4.5, "a"]]
	o["tab_more"] = [["c", 10, 24, 3.8, "m"], ["c", 24, 24, 3.8, "m"], ["c", 38, 24, 3.8, "a"]]
	# status
	o["fatigue"] = [["L", [7, 15, 36, 15, 36, 33, 7, 33], 4, "m"], ["l", [41, 21, 41, 27], 4, "m"], ["f", [12, 20, 19, 20, 19, 28, 12, 28], "a"]]
	o["form"] = [["l", [7, 35, 18, 24, 26, 30, 38, 15], 4.5, "m"], ["c", 40, 12, 4, "a"]]
	o["morale"] = [["o", 24, 24, 17, 4, "m"], ["c", 18, 20, 2.4, "m"], ["c", 30, 20, 2.4, "m"], ["a", 24, 26, 8, 25, 155, 4, "a"]]
	o["contract"] = [["L", [12, 7, 30, 7, 37, 14, 37, 41, 12, 41], 4, "m"], ["l", [18, 22, 31, 22], 3.5, "m"], ["l", [18, 29, 26, 29], 3.5, "m"], ["c", 29, 35, 3.6, "a"]]
	o["cash"] = [["L", [6, 14, 42, 14, 42, 34, 6, 34], 4, "m"], ["o", 24, 24, 5, 3.5, "a"]]
	# the role glyph fallback when the SVG loader is missing: the three bows of the Lane Bows set (not the exact glyphs)
	for r in ["top", "jg", "mid", "bot", "sup"]:
		var lit: int = {"top": 0, "jg": 1, "mid": 1, "bot": 2, "sup": 2}[r]
		var bows: Array = [["b", 16, 6, 3, 17, 3, 31, 16, 42, 4, "d"], ["l", [24, 6, 24, 42], 4, "d"], ["b", 32, 6, 45, 17, 45, 31, 32, 42, 4, "d"]]
		bows[lit][bows[lit].size() - 1] = "m"
		if r == "jg":
			bows.append(["c", 24, 24, 3.5, "a"])
		o["fallback_role_" + r] = bows
	return o


# ---- the Settings switch (moved from ui.gd by I-05; the pixels are the same) -----------------------------------------
const SWITCH_W := 80
const SWITCH_H := 44
static var _switch_icons: Dictionary = {}


## The icon of a CheckButton drawn as a switch (80 x 44 px, cached; ART-BIBLE 7: a white knob, a 2 px edge, teal when on,
## the raised panel colour when off, which the old 1.06:1 track was not). On: teal track, the knob at the right with a
## tick in it. Off: the knob at the left, plain, and a visible edge. The state reads from the knob's place and the tick,
## not from colour alone. `disabled` fades it.
static func switch_icon(on: bool, disabled: bool = false) -> Texture2D:
	var key := "%s%s" % ["on" if on else "off", "-dis" if disabled else ""]
	if _switch_icons.has(key):
		return _switch_icons[key]
	var img := Image.create(SWITCH_W, SWITCH_H, false, Image.FORMAT_RGBA8)
	var half := Vector2(SWITCH_W, SWITCH_H) * 0.5
	var track_r := SWITCH_H * 0.5 - 1.0
	var knob_r := 15.0
	var knob_c := Vector2(SWITCH_W - SWITCH_H * 0.5 if on else SWITCH_H * 0.5, SWITCH_H * 0.5)
	var track_col := ArtPalette.ACCENT if on else ArtPalette.PANEL3
	var knob_col := ArtPalette.TEXT
	var fade := 0.45 if disabled else 1.0
	var tick: Array = [knob_c + Vector2(-6.0, 0.5), knob_c + Vector2(-1.5, 5.0), knob_c + Vector2(6.5, -5.5)]
	for y in SWITCH_H:
		for x in SWITCH_W:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, 0)
			# track: a pill, its outline when off
			var q := (p - half).abs() - (half - Vector2(track_r + 1.0, track_r + 1.0))
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - track_r
			col = _over(col, track_col, clampf(0.5 - d, 0.0, 1.0))
			if not on:    # the 2 px edge of the off state
				col = _over(col, ArtPalette.DIM, clampf(1.5 - absf(d + 1.0), 0.0, 1.0))
			col = _over(col, knob_col, clampf(0.5 - ((p - knob_c).length() - knob_r), 0.0, 1.0))
			if on:
				var dt := minf(_seg_dist(p, tick[0], tick[1]), _seg_dist(p, tick[1], tick[2])) - 2.0
				col = _over(col, ArtPalette.INK_TEAL, clampf(0.5 - dt, 0.0, 1.0))
			col.a *= fade
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_switch_icons[key] = tex
	return tex


static func _over(dst: Color, src: Color, a: float) -> Color:
	var sa := a * src.a
	var out_a := sa + dst.a * (1.0 - sa)
	if out_a <= 0.0:
		return Color(0, 0, 0, 0)
	var rgb := (Vector3(src.r, src.g, src.b) * sa + Vector3(dst.r, dst.g, dst.b) * dst.a * (1.0 - sa)) / out_a
	return Color(rgb.x, rgb.y, rgb.z, out_a)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - (a + ab * t)).length()
