class_name Silhouette
extends RefCounted
## Hero portraits in code (ART-BIBLE 6.2): a circle, a role-colour ring, a lit background and a dark bust per role family
## (5 roles x 3 variants = 15 silhouettes) with its accents (visor, eyes, orb, halo, lantern) in the role colour. Original
## shapes: generic fantasy archetypes in flat navy, no face, no signature item of any existing hero.
##
## The 15 busts, the background disc and the rings are baked once into ONE atlas (20 cells of 96 px, 480 x 384 px,
## 0.74 MB), so a portrait is four quads of one texture and a whole grid of portraits is one draw call per pass.
## Which variant a hero gets: by its ARCHETYPE inside its role (VARIANT_OF), so every archetype of a role has its own
## silhouette; an unknown archetype falls back to the hero-id hash. The hero id also gives a small hue shift (plus or minus
## 10 degrees) on the background and a left/right mirror, so eight gunners are related but not identical.

const CELL := 96
const BOX := 96.0
const INK := Color("0d1526")
const RIM_SHIFT := Vector2(-2.4, -2.4)
const SIZE_FULL_DETAIL := 96

## archetype -> variant slot, per role (heroes.json: 7 archetypes; a role never has more than 3 of them)
const VARIANT_OF := {
	"top": {"bruiser": 0, "bulwark": 1},
	"jg": {"shade": 0, "bruiser": 1, "bulwark": 2},
	"mid": {"spellcaster": 0, "binder": 1, "shade": 2},
	"bot": {"gunner": 0},
	"sup": {"mender": 0, "binder": 1, "bulwark": 2},
}

static var _heroes: Dictionary = {}     # hero id -> {"role", "archetype"}
static var _ops: Dictionary = {}


## Give the hero table (heroes.json rows: id, role_primary, archetype) so draw(ci, hero_id, rect) can look a hero up.
static func register(heroes: Array) -> void:
	_heroes.clear()
	for h in heroes:
		_heroes[str(h["id"])] = {"role": str(h["role_primary"]), "archetype": str(h.get("archetype", ""))}


static func variant_for(role: String, archetype: String, hero_id: String) -> int:
	var m: Dictionary = VARIANT_OF.get(role, {})
	if m.has(archetype):
		return int(m[archetype])
	return (BadgeStyle.fnv1a(hero_id) >> 3) % 3


## Everything the drawing needs for one hero.
static func info(hero_id: String, role: String = "", archetype: String = "") -> Dictionary:
	if role == "" and _heroes.has(hero_id):
		role = _heroes[hero_id]["role"]
		archetype = _heroes[hero_id]["archetype"]
	if not ArtPalette.ROLES.has(role):
		role = "mid"
	var h := BadgeStyle.fnv1a(hero_id)
	return {"role": role, "archetype": archetype, "variant": variant_for(role, archetype, hero_id),
		"hue_shift": float((h >> 4) % 21) - 10.0, "mirror": ((h >> 9) & 1) == 1}


static func key(role: String, variant: int) -> String:
	return "sil:%s:%d" % [role, variant]


# ---- the busts -----------------------------------------------------------------------------------------------------

static func _mx(op: Array) -> Array:    # mirror an op left to right inside the 96 box
	var o: Array = op.duplicate(true)
	match str(o[0]):
		"l", "L", "f", "R":
			var p: Array = o[1]
			for i in range(0, p.size(), 2):
				p[i] = BOX - float(p[i])
		"c", "o", "e", "a":
			o[1] = BOX - float(o[1])
		"b":
			for i in range(1, 9, 2):
				o[i] = BOX - float(o[i])
	return o


## The ops of one silhouette: rim light, ink parts, then the extras and accents. Tones: "r" rim (role colour), "k" ink,
## "a" accent (role colour).
static func ops_for(role: String, variant: int) -> Array:
	var ck := key(role, variant)
	if _ops.has(ck):
		return _ops[ck]
	var ink: Array = []
	var extra: Array = []
	var v := clampi(variant, 0, 2)
	match role:
		"top":    # broad square shoulders, two rounded pauldrons, a crested helmet, a visor slit
			var pr: float = [13.0, 17.0, 10.0][v]    # pauldron radius: bulwark is the heaviest
			var px: float = [20.0, 16.0, 24.0][v]
			ink = [["f", [6, 96, 8, 80, 18, 68, 34, 62, 62, 62, 78, 68, 88, 80, 90, 96], "k"], ["c", px, 72, pr, "k"], ["c", 96.0 - px, 72, pr, "k"],
				["f", [40, 54, 56, 54, 58, 66, 38, 66], "k"], ["e", 48, 38, 17, 20, "k"]]
			ink.append([["f", [48, 4, 57, 22, 39, 22], "k"], ["f", [30, 26, 22, 4, 38, 20, 58, 20, 74, 4, 66, 26], "k"], ["f", [30, 22, 36, 12, 60, 12, 66, 22, 70, 14, 78, 22, 72, 28, 24, 28, 18, 22, 26, 14], "k"]][v])
			extra = [["l", [38, 42, 58, 42], 4, "a"]]
		"jg":     # a pointed hood and a hooked horn, two slanted eyes
			var torso: Array = [[14, 96, 16, 78, 30, 66, 66, 66, 80, 78, 82, 96], [4, 96, 8, 76, 26, 66, 70, 66, 88, 76, 92, 96], [14, 96, 16, 78, 30, 66, 66, 66, 80, 78, 82, 96]][v]
			var hood: Array = [[48, 4, 66, 34, 69, 58, 60, 68, 36, 68, 27, 58, 30, 34], [48, 4, 66, 34, 69, 58, 60, 68, 36, 68, 27, 58, 30, 34], [48, 6, 72, 32, 80, 58, 66, 68, 30, 68, 16, 58, 24, 32]][v]
			ink = [["f", torso, "k"], ["f", hood, "k"]]
			var horn: Array = ["R", [64, 28, 74, 12, 86, 14, 88, 20, 80, 20, 72, 38], 2, "k"]
			ink.append(horn if v != 1 else _mx(horn))
			if v == 2:
				ink.append(_mx(horn))
			extra = [["l", [37, 40, 46, 45], 4, "a"], ["l", [59, 40, 50, 45], 4, "a"]]
		"mid":    # a tall narrow bust, a high collar, a round head, a floating orb
			ink = [["f", [26, 96, 28, 76, 38, 68, 58, 68, 68, 76, 70, 96], "k"], ["f", [26, 54, 38, 70, 48, 76, 58, 70, 70, 54, 68, 82, 28, 82], "k"], ["c", 48, 42, 14, "k"]]
			ink.append([["e", 48, 30, 15, 6, "k"], ["f", [33, 32, 48, 4, 63, 32], "k"], ["c", 48, 26, 7, "k"]][v])
			var orb: Array = [[76, 28], [20, 30], [72, 12]][v]
			extra = [["c", orb[0], orb[1], 7, "a"], ["o", orb[0], orb[1], 11, 2.5, "a"]]
		"bot":    # a leaning bust, a cap and brim, a long diagonal weapon held low
			ink = [["f", [12, 96, 20, 78, 38, 66, 62, 64, 80, 72, 88, 96], "k"], ["c", 46, 42, 14, "k"]]
			if v == 0:
				ink.append(["f", [31, 38, 35, 24, 56, 22, 62, 38], "k"])
				ink.append(["f", [52, 33, 80, 36, 80, 42, 52, 42], "k"])
			elif v == 1:
				ink.append(["f", [31, 38, 35, 24, 56, 22, 62, 38], "k"])
				ink.append(["f", [42, 33, 14, 36, 14, 42, 42, 42], "k"])
			else:
				ink.append(["f", [31, 32, 62, 32, 63, 40, 30, 40], "k"])
				ink.append(["f", [60, 32, 74, 22, 72, 36], "k"])
			extra = [["l", [10, 86, 88, 54], 7.5, "k"], ["l", [10, 86, 88, 54], 3, "r"], ["l", [41, 47, 52, 47], 3.5, "a"]]
		"sup":    # round soft shoulders, a hood, a halo, a lantern
			ink = [["e", 48, 98, 38, 30, "k"], [["c", 48, 48, 21, "k"], ["c", 48, 48, 21, "k"], ["e", 48, 50, 25, 23, "k"]][v]]
			if v == 1:
				ink.append(["f", [38, 34, 48, 16, 58, 34], "k"])
			var hr: float = [11.0, 13.0, 9.0][v]
			var lx: float = [66.0, 14.0, 62.0][v]
			var ly: float = [72.0, 72.0, 64.0][v]
			extra = [["o", 48, 17 if v != 1 else 12, hr, 3.5, "a"], ["f", [lx, ly, lx + 12, ly, lx + 12, ly + 16, lx, ly + 16], "a"],
				["l", [lx + 2, ly, lx + 6, ly - 6, lx + 10, ly], 2.5, "a"], ["c", 42, 50, 2.2, "a"], ["c", 54, 50, 2.2, "a"]]
	var flat: Array = []
	for p in ink:    # ink may hold a nested op list from the variant pick; flatten one level
		if p.size() > 0 and p[0] is Array:
			for q in p:
				flat.append(q)
		else:
			flat.append(p)
	var out: Array = []
	for p in flat:    # the rim light: the same parts, shifted up and left, in the role colour, underneath
		out.append(VecOps.shifted(p, RIM_SHIFT.x, RIM_SHIFT.y, "r"))
	out.append_array(flat)
	out.append_array(extra)
	_ops[ck] = out
	return out


# ---- the atlas -----------------------------------------------------------------------------------------------------

static func _cells() -> Array:
	var cells: Array = []
	for role in ArtPalette.ROLES:
		var col := ArtPalette.role_color(role)
		for v in 3:
			cells.append({"key": key(role, v), "svg": VecOps.to_svg(ops_for(role, v), BOX, {"k": INK, "r": col, "a": col}, true)})
	var g := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"96\" height=\"96\" viewBox=\"0 0 96 96\">"
	cells.append({"key": "bg", "svg": g + "<defs><radialGradient id=\"g\" cx=\"0.3\" cy=\"0.26\" r=\"0.85\"><stop offset=\"0\" stop-color=\"#FFFFFF\"/><stop offset=\"1\" stop-color=\"#737373\"/></radialGradient></defs><circle cx=\"48\" cy=\"48\" r=\"48\" fill=\"url(#g)\"/></svg>"})
	cells.append({"key": "ring5", "svg": g + "<circle cx=\"48\" cy=\"48\" r=\"43.5\" fill=\"none\" stroke=\"#FFFFFF\" stroke-width=\"5\"/></svg>"})
	cells.append({"key": "ring7", "svg": g + "<circle cx=\"48\" cy=\"48\" r=\"42.5\" fill=\"none\" stroke=\"#FFFFFF\" stroke-width=\"7\"/></svg>"})
	cells.append({"key": "dark", "svg": g + "<circle cx=\"48\" cy=\"48\" r=\"47\" fill=\"none\" stroke=\"#FFFFFF\" stroke-width=\"2\"/></svg>"})
	cells.append({"key": "disc", "svg": g + "<circle cx=\"48\" cy=\"48\" r=\"48\" fill=\"#FFFFFF\"/></svg>"})
	return cells


static func atlas() -> Dictionary:
	if TexCache.has("portraits@96"):
		return TexCache.atlas("portraits@96", [], BOX, CELL, 5)    # a hit; the cells are not rebuilt
	return TexCache.atlas("portraits@96", _cells(), BOX, CELL, 5)


static func ok() -> bool:
	return (atlas()["failed"] as Array).is_empty()


# ---- drawing -------------------------------------------------------------------------------------------------------

## The background tint of a portrait: the role colour mixed 52 percent into the page colour, hue shifted a little.
static func bg_tint(role: String, hue_shift: float = 0.0) -> Color:
	var c := ArtPalette.BG.lerp(ArtPalette.role_color(role), 0.52)
	if hue_shift != 0.0:
		c.h = fposmod(c.h + hue_shift / 360.0, 1.0)
	return c


## Draw a hero portrait into `rect` (square). opts: role, archetype (when the hero was not register()ed), banned (bool),
## mirror (default from the id), corner_glyph (default: yes at 56 px and below, ART-BIBLE 6.2).
static func draw(ci: CanvasItem, hero_id: String, rect: Rect2, opts: Dictionary = {}) -> void:
	var inf := info(hero_id, str(opts.get("role", "")), str(opts.get("archetype", "")))
	draw_role(ci, inf["role"], inf["variant"], rect, inf["hue_shift"], bool(opts.get("mirror", inf["mirror"])), bool(opts.get("banned", false)),
		bool(opts.get("corner_glyph", rect.size.x <= 56.0)))


static func draw_role(ci: CanvasItem, role: String, variant: int, rect: Rect2, hue_shift: float = 0.0, mirror: bool = false,
		banned: bool = false, corner_glyph: bool = false) -> void:
	var a := atlas()
	var rects: Dictionary = a["rects"]
	var failed: Array = a["failed"]
	var ring_col := ArtPalette.TEXT_OFF if banned else ArtPalette.role_color(role)
	var dim := Color(0.5, 0.5, 0.55, 1.0) if banned else Color.WHITE
	var small := rect.size.x <= 64.0
	var tint := bg_tint(role, hue_shift)
	if failed.is_empty():
		var tex: Texture2D = a["tex"]
		ci.draw_texture_rect_region(tex, rect, rects["bg"], tint * dim)
		var r := rect
		if mirror:
			r = Rect2(Vector2(rect.end.x, rect.position.y), Vector2(-rect.size.x, rect.size.y))
		ci.draw_texture_rect_region(tex, r, rects[key(role, clampi(variant, 0, 2))], dim)
		ci.draw_texture_rect_region(tex, rect, rects["ring7" if small else "ring5"], ring_col)
		ci.draw_texture_rect_region(tex, rect, rects["dark"], ArtPalette.VOID)
	else:    # the SVG loader failed: a flat disc, a ring and the plain bust from the same ops
		var c := rect.get_center()
		var rad := rect.size.x * 0.5
		ci.draw_circle(c, rad, tint * dim)
		VecOps.draw(ci, ops_for(role, variant), BOX, rect, {"k": INK, "r": ring_col, "a": ring_col})
		ci.draw_arc(c, rad * 0.9, 0.0, TAU, 40, ring_col, rect.size.x * (0.07 if small else 0.052), true)
	if banned:
		var m := rect.size.x * 0.5 * 0.7071
		ci.draw_line(rect.get_center() + Vector2(-m, -m), rect.get_center() + Vector2(m, m), ArtPalette.BAD_DEFAULT, maxf(3.0, rect.size.x * 0.07), true)
	if corner_glyph:
		var d := clampf(rect.size.x * 0.46, 20.0, 26.0)
		var cc := rect.end - Vector2(d * 0.5, d * 0.5)
		ci.draw_circle(cc, d * 0.5, ArtPalette.VOID)
		ci.draw_arc(cc, d * 0.5 - 0.75, 0.0, TAU, 24, ArtPalette.role_color(role), 1.5, true)
		var g := d * 0.77
		Icons.draw(ci, Icons.role_id(role), Rect2(cc - Vector2(g, g) * 0.5, Vector2(g, g)), ArtPalette.role_color(role))
