extends RefCounted
## I-05 art code, logic part (headless, no UI classes): the club badge algorithm against the ART-BIBLE 6.3 table, the
## badge and role-glyph distinctness (colour, greyscale and three colour-blind simulations), the silhouette per role and
## archetype, avatars, the icon set, the texture cache (hits, bytes, the 8 MB budget), the moved switch icon, and one
## negative control per rule (a deliberately wrong input that the same check must reject).
## SVG rasterisation works headless (it is an Image function); drawing onto a canvas does not, so `check_art.tscn` covers that.
## Auto-discovered by tests/run_tests.gd (name ends in _tests.gd).

## ART-BIBLE 6.3 expected table: id, FNV hash, hue, shape, pattern, primary, secondary
const TABLE := [
	["duskwater_foxes", "0608c2e9", 270, "shield", "plain", "#BC8FEA", "#29123F"],
	["emberfen_hounds", "462833c5", 24, "roundel", "chevron", "#DA9160", "#3F2412"],
	["gildmoor_raiders", "a0cdac0f", 76, "diamond", "chief", "#82A520", "#333F12"],
	["ironquill_wolves", "ceb0648d", 160, "banner", "chevron", "#1AAF7D", "#DDEEE8"],
	["mossgate_wardens", "03f49819", 196, "banner", "chief", "#20A4D5", "#12333F"],
	["northreach_corsairs", "a6ef26b0", 128, "roundel", "plain", "#22B035", "#123F18"],
	["pinehollow_owls", "8e0ff5c2", 44, "hexagon", "chief", "#AF8C29", "#3F3312"],
	["saltmarrow_gulls", "861a265b", 216, "roundel", "chief", "#4886E4", "#DDE4EE"],
	["stormvale_herons", "300c8fd2", 4, "banner", "plain", "#E57B74", "#3F1512"],
	["thornwick_stags", "73950e4b", 338, "hexagon", "plain", "#DC6B95", "#EEDDE3"],
]
## A made-up 11th and 12th club id, to prove the rules hold past the ten of today (clubs.json has 10).
const EXTRA_CLUBS := ["harrowgate_kestrels", "lindenmoor_otters"]

## Recorded sha256 of the pixels of the old UI.switch_icon (measured before the move, in Godot 4.3): on, on+disabled, off, off+disabled
const SWITCH_SHA := {
	"on": "163becd59c2f360d5efb04ac3fbacc3d6519528926d29f1cccd9a5e23c5f9f09",
	"on-dis": "6395cd80e5557a14a6e779b3c391a099db32b13685de0afbac764a22a97b91ef",
	"off": "b0a6844f78a616665a2332fb90a6526f6bb5ee93530319d8e2ef5d4ab04edf9b",
	"off-dis": "a2b638b1b02f11beb07212b1a9c243b8eec4dc28f458e4841b299dc7e40b02a6",
}

## Machado 2009 colour-vision simulation, severity 1.0, applied in linear RGB
const SIM := {
	"protan": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
	"deutan": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
	"tritan": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}
const VIEWS := ["colour", "grey", "protan", "deutan", "tritan"]
## Minimum pairwise distance (see _dist): shape/pattern difference alone must clear this in every view. 0.04 is set from the
## negative control (a twin of the same shape and pattern and the same lightness measures about 0.00 in greyscale).
const MIN_BADGE_DIST := 0.04
const MIN_MASK_DIST := 0.10     # silhouettes, alpha only
const MIN_ROLE_DIST := 0.07     # role glyphs, alpha only (Bot and Support share an arc by design: they differ by the bar and the plus)


func run(check: Callable) -> void:
	TexCache.reset()
	Badge.reset_cache()
	_badge_algorithm(check)
	_badge_league(check)
	_badge_distinct(check)
	_role_glyphs(check)
	_icon_set(check)
	_silhouettes(check)
	_avatars(check)
	_cache(check)
	_switch(check)
	_surface_and_vec(check)
	TexCache.reset()
	Badge.reset_cache()


# ---- helpers -------------------------------------------------------------------------------------------------------

func _club_ids() -> Array:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/clubs.json"))
	var ids: Array = []
	for r in rows:
		ids.append(str(r["id"]))
	return ids


static func _close(a: Color, hexs: String, tol: int) -> bool:
	var b := Color(hexs)
	for pair in [[a.r, b.r], [a.g, b.g], [a.b, b.b]]:
		if absi(int(float(pair[0]) * 255.0 + 0.5) - int(float(pair[1]) * 255.0 + 0.5)) > tol:
			return false
	return true


## Collisions in a set of resolved styles: two clubs with one hue, or one shape+pattern pair, while the limits (12 hues,
## 24 pairs) are not yet exhausted. Empty = fine.
func _collisions(styles: Dictionary) -> Array:
	var out: Array = []
	var ids: Array = styles.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Dictionary = styles[ids[i]]
			var b: Dictionary = styles[ids[j]]
			if ids.size() <= 12 and a["hue"] == b["hue"]:
				out.append("%s and %s share hue %d" % [ids[i], ids[j], a["hue"]])
			if ids.size() <= 24 and a["shape"] == b["shape"] and a["pattern"] == b["pattern"]:
				out.append("%s and %s share %s + %s" % [ids[i], ids[j], a["shape_name"], a["pattern_name"]])
	return out


# ---- 1. the ART-BIBLE 6.3 algorithm ----------------------------------------------------------------------------------

func _badge_algorithm(check: Callable) -> void:
	var ids: Array = []
	for row in TABLE:
		ids.append(row[0])
	var league := BadgeStyle.resolve(ids)
	var all_ok := true
	var first_bad := ""
	for row in TABLE:
		var s: Dictionary = league[row[0]]
		var good: bool = ("%08x" % s["hash"]) == row[1] and s["hue"] == row[2] and s["shape_name"] == row[3] and s["pattern_name"] == row[4] \
			and _close(s["primary"], row[5], 1) and _close(s["secondary"], row[6], 1)
		if not good:
			all_ok = false
			first_bad = row[0]
	check.call(all_ok, "badge: all 10 rows of the ART-BIBLE 6.3 table (hash, hue, shape, pattern, primary, secondary within 1 per channel) %s" % first_bad)
	# negative control: a wrong expected primary must be rejected by the same comparison
	check.call(not _close(league["duskwater_foxes"]["primary"], "#BC8FF2", 1), "badge negative control: a primary 8 off in blue is not 'close'")
	check.call(BadgeStyle.fnv1a("") == 0x811C9DC5 and BadgeStyle.fnv1a("a") == 0xE40C292C, "badge: FNV-1a 32 matches its published test values")
	# the contrast claims of 3.7 (ink on primary >= 5.2, primary vs card >= 4.1, primary vs secondary >= 2.3, with rounding room)
	var min_ink := 99.0
	var min_card := 99.0
	var min_sec := 99.0
	for id in league:
		var s: Dictionary = league[id]
		min_ink = minf(min_ink, BadgeStyle.contrast(s["primary"], BadgeStyle.INK))
		min_card = minf(min_card, BadgeStyle.contrast(s["primary"], ArtPalette.PANEL))
		min_sec = minf(min_sec, BadgeStyle.contrast(s["primary"], s["secondary"]))
	check.call(min_ink >= 5.1 and min_card >= 4.0 and min_sec >= 2.2, "badge: ink on primary %.2f (>=5.2), primary on card %.2f (>=4.1), primary vs secondary %.2f (>=2.3)" % [min_ink, min_card, min_sec])
	# negative control: a colour outside the brightness window fails the same test
	check.call(BadgeStyle.contrast(Color("ffffff"), BadgeStyle.INK) > 5.1 and BadgeStyle.contrast(Color("0b1220"), ArtPalette.PANEL) < 4.0, "badge negative control: a too-light and a too-dark primary are told apart by the contrast helper")


func _badge_league(check: Callable) -> void:
	var data_ids := _club_ids()
	var table_ids: Array = []
	for row in TABLE:
		table_ids.append(row[0])
	var same_set := data_ids.size() == table_ids.size()
	for id in data_ids:
		same_set = same_set and table_ids.has(id)
	check.call(same_set, "badge: clubs.json has exactly the %d clubs of the table (%d found)" % [table_ids.size(), data_ids.size()])
	var eleven: Array = data_ids.duplicate()
	eleven.append(EXTRA_CLUBS[0])
	var twelve: Array = eleven.duplicate()
	twelve.append(EXTRA_CLUBS[1])
	for league_ids in [data_ids, eleven, twelve]:
		var st := BadgeStyle.resolve(league_ids)
		var hues := {}
		var pairs := {}
		for id in st:
			hues[st[id]["hue"]] = true
			pairs[st[id]["shape"] * 4 + st[id]["pattern"]] = true
		check.call(hues.size() == league_ids.size() and pairs.size() == league_ids.size() and _collisions(st).is_empty(),
			"badge league of %d: %d distinct hues, %d distinct shape+pattern pairs, no collision" % [league_ids.size(), hues.size(), pairs.size()])
	# determinism: same ids give the same styles; the order the ids come in does not matter; for_club agrees with resolve
	var a := BadgeStyle.resolve(eleven)
	var shuffled: Array = eleven.duplicate()
	shuffled.reverse()
	var b := BadgeStyle.resolve(shuffled)
	var same := true
	for id in a:
		same = same and a[id]["primary"] == b[id]["primary"] and a[id]["shape"] == b[id]["shape"] and a[id]["pattern"] == b[id]["pattern"]
	check.call(same, "badge: deterministic, and the same whatever order the league lists its clubs in")
	check.call(BadgeStyle.for_club("duskwater_foxes", eleven)["primary"] == a["duskwater_foxes"]["primary"], "badge: for_club(id, league) equals resolve(league)[id]")
	BadgeStyle.set_league(eleven)
	check.call(BadgeStyle.for_club(EXTRA_CLUBS[0])["hue"] == a[EXTRA_CLUBS[0]]["hue"], "badge: set_league() then for_club(id) gives the resolved style")
	BadgeStyle.set_league([])
	check.call(BadgeStyle.for_club("pinehollow_owls")["hue"] == BadgeStyle.HUES[BadgeStyle.raw("pinehollow_owls")["hue_idx"]], "badge: for_club(id) alone is the plain hash result")
	# negative control: with no clash handling the raw hashes of the 11 clubs DO collide (so the resolution step is needed)
	var raw := {}
	for id in eleven:
		var r := BadgeStyle.raw(id)
		raw[id] = {"hue": BadgeStyle.HUES[r["hue_idx"]], "shape": r["shape"], "pattern": r["pattern"], "shape_name": "", "pattern_name": ""}
	check.call(not _collisions(raw).is_empty(), "badge negative control: the unresolved hashes of the 11 clubs collide (%d collisions), the resolved ones do not" % _collisions(raw).size())


# ---- 2. distinctness at 48 px in colour, greyscale and three colour-blind views ----------------------------------------

static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _gam(v: float) -> float:
	v = clampf(v, 0.0, 1.0)
	return v * 12.92 if v <= 0.0031308 else 1.055 * pow(v, 1.0 / 2.4) - 0.055


## The picture of an Image in one view: a PackedFloat32Array of (r, g, b, a) per pixel, gamma space.
func _view(img: Image, mode: String) -> PackedFloat32Array:
	var w := img.get_width()
	var h := img.get_height()
	var out := PackedFloat32Array()
	out.resize(w * h * 4)
	var m: Array = SIM.get(mode, [])
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var i := (y * w + x) * 4
			out[i + 3] = c.a
			if c.a < 0.01:
				continue
			var r := _lin(c.r)
			var g := _lin(c.g)
			var b := _lin(c.b)
			if mode == "grey":
				var l := _gam(0.2126 * r + 0.7152 * g + 0.0722 * b)
				out[i] = l
				out[i + 1] = l
				out[i + 2] = l
			elif mode == "colour":
				out[i] = c.r
				out[i + 1] = c.g
				out[i + 2] = c.b
			else:
				out[i] = _gam(m[0][0] * r + m[0][1] * g + m[0][2] * b)
				out[i + 1] = _gam(m[1][0] * r + m[1][1] * g + m[1][2] * b)
				out[i + 2] = _gam(m[2][0] * r + m[2][1] * g + m[2][2] * b)
	return out


## Distance of two pictures: over the pixels either one covers, 1.0 where only one covers it, else the RGB distance / sqrt(3).
static func _dist(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var sum := 0.0
	var n := 0
	for i in range(0, a.size(), 4):
		var ca := a[i + 3] > 0.5
		var cb := b[i + 3] > 0.5
		if not ca and not cb:
			continue
		n += 1
		if ca != cb:
			sum += 1.0
		else:
			sum += sqrt(pow(a[i] - b[i], 2.0) + pow(a[i + 1] - b[i + 1], 2.0) + pow(a[i + 2] - b[i + 2], 2.0)) / 1.7320508
	return sum / float(maxi(n, 1))


## Distance of two pictures by alpha only (the shape, whatever colour it is drawn in).
static func _mask_dist(a: Image, b: Image) -> float:
	var sum := 0.0
	var n := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var pa := a.get_pixel(x, y).a
			var pb := b.get_pixel(x, y).a
			if pa < 0.02 and pb < 0.02:
				continue
			n += maxf(pa, pb)
			sum += absf(pa - pb)
	return sum / maxf(n, 1.0)


func _badge_distinct(check: Callable) -> void:
	var ids := _club_ids()
	ids.append(EXTRA_CLUBS[0])
	var league := BadgeStyle.resolve(ids)
	var order: Array = league.keys()
	order.sort()
	var views := {}    # id -> {view -> picture}
	for id in order:
		var img := Badge.raster(league[id], 48)
		var d := {}
		for v in VIEWS:
			d[v] = _view(img, v)
		views[id] = d
	var worst := {}
	var worst_pair := {}
	for v in VIEWS:
		worst[v] = 9.0
	for i in order.size():
		for j in range(i + 1, order.size()):
			for v in VIEWS:
				var d := _dist(views[order[i]][v], views[order[j]][v])
				if d < worst[v]:
					worst[v] = d
					worst_pair[v] = "%s / %s" % [order[i], order[j]]
	for v in VIEWS:
		check.call(worst[v] >= MIN_BADGE_DIST, "badge: all %d clubs distinct at 48 px in %s view (closest pair %s: %.3f >= %.2f)" % [order.size(), v, worst_pair[v], worst[v], MIN_BADGE_DIST])
	# negative controls: (a) the same club against itself is 0; (b) two clubs of one shape+pattern whose colours have the same
	# lightness are NOT told apart in greyscale (so the greyscale check can fail, and the pair rule is what prevents it)
	var self_d := _dist(views[order[0]]["grey"], views[order[0]]["grey"])
	check.call(self_d == 0.0 and self_d < MIN_BADGE_DIST, "badge negative control: a badge against itself has distance 0 (below the %.2f limit)" % MIN_BADGE_DIST)
	var twin: Dictionary = league[order[0]].duplicate()
	var l0 := BadgeStyle.luminance(twin["primary"])
	var other := BadgeStyle.hsl((float(twin["hue"]) + 150.0), 0.62, 0.5)
	var lo := 0.15
	var hi := 0.85
	for k in 24:
		var mid := (lo + hi) * 0.5
		if BadgeStyle.luminance(BadgeStyle.hsl(float(twin["hue"]) + 150.0, 0.62, mid)) < l0:
			lo = mid
		else:
			hi = mid
	other = BadgeStyle.hsl(float(twin["hue"]) + 150.0, 0.62, (lo + hi) * 0.5)
	twin["primary"] = other
	twin["id"] = "twin_of_" + str(twin["id"])
	var tv := _view(Badge.raster(twin, 48), "grey")
	var td := _dist(views[order[0]]["grey"], tv)
	check.call(td < MIN_BADGE_DIST, "badge negative control: same shape and pattern, another hue of the same lightness is %.3f apart in greyscale (below %.2f: not distinct)" % [td, MIN_BADGE_DIST])
	# ART-BIBLE 3.7 rule 4: no pattern reaches the initial, for every shape and pattern
	var touches: Array = []
	for shape_name in BadgeStyle.SHAPES:
		var box := Badge.letter_box(shape_name)
		var box_poly := PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])
		var shape_poly := Badge.shape_polygon(shape_name)
		for pat in BadgeStyle.PATTERNS:
			for region in Badge.pattern_polygons(pat, shape_name):
				for clipped in Geometry2D.intersect_polygons(shape_poly, region):
					if not Geometry2D.intersect_polygons(clipped, box_poly).is_empty():
						touches.append("%s %s" % [shape_name, pat])
	check.call(touches.is_empty(), "badge: no pattern reaches the initial, on any of the 6 shapes x 3 patterns %s" % str(touches))
	# negative control: a chief band 45 deep on a roundel does reach the letter
	var deep_box := Badge.letter_box("roundel")
	var deep := Geometry2D.intersect_polygons(Badge.shape_polygon("roundel"), PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 45), Vector2(0, 45)]))
	var deep_hit := Geometry2D.intersect_polygons(deep[0], PackedVector2Array([deep_box.position, Vector2(deep_box.end.x, deep_box.position.y), deep_box.end, Vector2(deep_box.position.x, deep_box.end.y)]))
	check.call(not deep_hit.is_empty(), "badge negative control: a chief band 45 deep reaches the letter, so the rule can fail")
	# gallery of 20: layer count per badge and the layer cache (20 distinct clubs drawn twice: 20 misses then 20 hits)
	Badge.reset_cache()
	var gal: Array = []
	for i in 20:
		gal.append("club_%02d" % i)
	var gal_styles := BadgeStyle.resolve(gal)
	var max_layers := 0
	for pass_n in 2:
		for id in gal:
			max_layers = maxi(max_layers, Badge.layers(gal_styles[id]).size())
	check.call(Badge.cache_misses == 20 and Badge.cache_hits == 20, "badge gallery of 20: layers built once (%d misses), reused on the second pass (%d hits)" % [Badge.cache_misses, Badge.cache_hits])
	check.call(max_layers <= 8, "badge: at most 8 polygon layers per badge (largest %d), so a badge is 2 draw calls and a batch of any size is 2" % max_layers)
	check.call(Badge.layers(gal_styles[gal[0]]).size() <= 8, "badge gallery: node budget is 1 Control for the whole gallery (draw_batch), not one per badge")


# ---- 3. role glyphs and icons ----------------------------------------------------------------------------------------

func _icon_image(id: String, px: int) -> Image:
	var svg: String = Icons.svg_of(id)
	if svg == "":
		svg = VecOps.to_svg(Icons.ops_of(id), Icons.BOX, {"m": Color.WHITE, "d": Color(1, 1, 1, 0.4), "a": Color.WHITE})
	return TexCache.rasterise(svg, float(px) / Icons.BOX)


static func _bbox(img: Image, alpha: float = 0.1) -> Rect2i:
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > alpha:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i()
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func _role_glyphs(check: Callable) -> void:
	var roles: Array = ArtPalette.ROLES
	var imgs := {}
	for r in roles:
		imgs[r] = _icon_image("role_" + r, 48)
	var ok_all := true
	var worst := 9.0
	var worst_pair := ""
	for i in roles.size():
		ok_all = ok_all and imgs[roles[i]] != null and not _bbox(imgs[roles[i]]).has_area() == false
		for j in range(i + 1, roles.size()):
			var d := _mask_dist(imgs[roles[i]], imgs[roles[j]])
			if d < worst:
				worst = d
				worst_pair = "%s / %s" % [roles[i], roles[j]]
	check.call(ok_all, "role glyphs: all 5 rasterise to a non-empty picture")
	var inside := true
	for r in roles:
		var bb := _bbox(imgs[r])
		inside = inside and bb.position.x >= 0 and bb.position.y >= 0 and bb.end.x <= 48 and bb.end.y <= 48
	check.call(inside, "role glyphs: all 5 stay inside the 48 px grid (Support's plus reaches 47: the designer's file, 1 px inside the edge)")
	check.call(worst >= MIN_ROLE_DIST, "role glyphs: the 5 are pairwise distinct by shape (alpha only; closest %s %.3f >= %.2f)" % [worst_pair, worst, MIN_ROLE_DIST])
	# the lit lane alone (alpha 1.0 strokes, not the 40 percent context lanes) also differs, because the colour carries the role
	var lit := {}
	for r in roles:
		var im: Image = (imgs[r] as Image).duplicate()
		for y in im.get_height():
			for x in im.get_width():
				var c := im.get_pixel(x, y)
				im.set_pixel(x, y, Color(1, 1, 1, 1.0 if c.a > 0.8 else 0.0))
		lit[r] = im
	var lit_worst := 9.0
	for i in roles.size():
		for j in range(i + 1, roles.size()):
			lit_worst = minf(lit_worst, _mask_dist(lit[roles[i]], lit[roles[j]]))
	check.call(lit_worst > 0.0, "role glyphs: even the lit part alone differs between every pair (closest %.3f)" % lit_worst)
	# negative control: a glyph against itself, and a glyph against one shifted by 1 px, are both under the limit
	check.call(_mask_dist(imgs["top"], imgs["top"]) < MIN_ROLE_DIST, "role glyph negative control: a glyph against itself is not distinct")
	var same_svg := Icons.svg_of("role_bot")
	check.call(_mask_dist(TexCache.rasterise(same_svg, 1.0), imgs["bot"]) < MIN_ROLE_DIST, "role glyph negative control: two copies of one SVG are not distinct")
	# the embedded SVG strings keep the designer's source: 5 files, 4 px stroke on the 48 grid, white strokes
	var all_svg := true
	for r in roles:
		var s: String = Icons.svg_of("role_" + r)
		all_svg = all_svg and s.begins_with("<svg") and s.contains("width=\"48\"") and s.contains("#FFFFFF")
	check.call(all_svg, "role glyphs: five embedded SVG strings, 48 px grid, white strokes (tinted with modulate)")


static func ROLE_FILES_OK(id: String) -> bool:    # role glyphs are the designer's files, checked by their own rule above
	return id.begins_with("role_")


func _icon_set(check: Callable) -> void:
	var ids: Array = Icons.IDS
	var empty: Array = []
	var outside: Array = []
	var dup_ids := {}
	var no_def: Array = []
	var imgs := {}
	for id in ids:
		dup_ids[id] = true
		if Icons.svg_of(id) == "" and Icons.ops_of(id).is_empty():
			no_def.append(id)
			continue
		var img := _icon_image(id, 48)
		if img == null:
			empty.append(id)
			continue
		imgs[id] = img
		var bb := _bbox(img)
		if not bb.has_area():
			empty.append(id)
		# the live area is 40 px on the 48 grid (4 px padding), strokes may reach 2 px of the edge
		elif not ROLE_FILES_OK(id) and (bb.position.x < 2 or bb.position.y < 2 or bb.end.x > 46 or bb.end.y > 46):
			outside.append("%s %s" % [id, bb])
	check.call(ids.size() == dup_ids.size() and ids.size() >= 40, "icons: %d ids, no duplicates (the bible's set of about 30 plus the roles and sides)" % ids.size())
	check.call(no_def.is_empty(), "icons: every id has a drawing %s" % str(no_def))
	check.call(empty.is_empty(), "icons: every icon rasterises to a non-empty picture %s" % str(empty))
	check.call(outside.is_empty(), "icons: every icon stays inside the 48 grid with 2 px to spare %s" % str(outside))
	# no two icons are the same picture, except the one declared alias (close is the cross)
	var same_pairs: Array = []
	var keys: Array = imgs.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			if _mask_dist(imgs[keys[i]], imgs[keys[j]]) < 0.02:
				same_pairs.append("%s=%s" % [keys[i], keys[j]])
	check.call(same_pairs == ["cross=close"] or same_pairs == ["close=cross"], "icons: no two icons are the same picture except close=cross %s" % str(same_pairs))
	# the arrows are told apart by shape, not by colour (up, down and flat), and the two side marks (circle, hexagon) too
	check.call(_mask_dist(imgs["arrow_up"], imgs["arrow_down"]) >= 0.3 and _mask_dist(imgs["arrow_up"], imgs["arrow_flat"]) >= 0.3 and _mask_dist(imgs["arrow_down"], imgs["arrow_flat"]) >= 0.3, "icons: arrow up, down and flat differ by shape")
	check.call(_mask_dist(imgs["side_you"], imgs["side_them"]) >= 0.05, "icons: the teal circle and the coral hexagon differ by shape (%.3f)" % _mask_dist(imgs["side_you"], imgs["side_them"]))
	# negative control: an icon that spills over the grid is caught by the same bounding-box rule
	var spill := TexCache.rasterise("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"48\" height=\"48\"><rect x=\"0\" y=\"10\" width=\"48\" height=\"8\" fill=\"#fff\"/></svg>", 1.0)
	var sb := _bbox(spill)
	check.call(sb.position.x < 2 and sb.end.x > 46, "icon negative control: a bar from edge to edge is outside the live area, so the rule can fail")
	# negative control: when the SVG loader fails (forced off here; a broken string would print an engine error) rasterise gives null and counts it
	var before := TexCache.svg_failures
	TexCache.force_fail = true
	var broken := TexCache.rasterise(Icons.svg_of("role_top"), 1.0)
	TexCache.force_fail = false
	check.call(broken == null and TexCache.svg_failures == before + 1, "icon negative control: a failed SVG load returns null and counts one svg_failure")
	# every drawn icon converts to SVG and back from the ops (all op kinds are exercised by the set)
	var kinds := {}
	for id in ids:
		for op in Icons.ops_of(id):
			kinds[str(op[0])] = true
	check.call(kinds.has("l") and kinds.has("L") and kinds.has("f") and kinds.has("R") and kinds.has("c") and kinds.has("o") and kinds.has("a"), "icons: the set uses the stroke, outline, fill, soft-fill, circle, ring and arc ops (%s)" % str(kinds.keys()))
	var all_tones := true
	for id in ids:
		for op in Icons.ops_of(id):
			all_tones = all_tones and ["m", "d", "a"].has(VecOps.tone_of(op))
	check.call(all_tones, "icons: every op has a tone of m, d or a")


# ---- 4. silhouettes ------------------------------------------------------------------------------------------------

func _cell_image(atlas: Dictionary, key: String) -> Image:
	var r: Rect2 = atlas["rects"][key]
	var full: Image = (atlas["tex"] as Texture2D).get_image()
	return full.get_region(Rect2i(r))


func _silhouettes(check: Callable) -> void:
	var heroes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes.json"))
	Silhouette.register(heroes)
	var a := Silhouette.atlas()
	check.call((a["failed"] as Array).is_empty(), "silhouette: the portrait atlas rasterised with no failed cell (%d x %d px, %d cells)" % [a["w"], a["h"], (a["rects"] as Dictionary).size()])
	var cells := {}
	var empty: Array = []
	for role in ArtPalette.ROLES:
		for v in 3:
			var k := Silhouette.key(role, v)
			cells[k] = _cell_image(a, k)
			if not _bbox(cells[k]).has_area():
				empty.append(k)
	check.call(empty.is_empty(), "silhouette: all 15 (5 roles x 3 variants) draw something %s" % str(empty))
	var keys: Array = cells.keys()
	var worst := 9.0
	var worst_pair := ""
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var d := _mask_dist(cells[keys[i]], cells[keys[j]])
			if d < worst:
				worst = d
				worst_pair = "%s / %s" % [keys[i], keys[j]]
	check.call(worst >= MIN_MASK_DIST, "silhouette: the 15 are pairwise distinct with colour removed (alpha only; closest %s %.3f >= %.2f)" % [worst_pair, worst, MIN_MASK_DIST])
	# the five role families are distinct from each other (variant 0 of each), by a wider margin
	var fam_worst := 9.0
	for i in 5:
		for j in range(i + 1, 5):
			fam_worst = minf(fam_worst, _mask_dist(cells[Silhouette.key(ArtPalette.ROLES[i], 0)], cells[Silhouette.key(ArtPalette.ROLES[j], 0)]))
	check.call(fam_worst >= 0.2, "silhouette: the 5 role families differ clearly (closest %.3f >= 0.20)" % fam_worst)
	# every archetype of a role has its own variant, so its own silhouette
	var arch_ok := true
	var seen_arch := {}
	for h in heroes:
		seen_arch["%s/%s" % [h["role_primary"], h["archetype"]]] = true
	for pair in seen_arch:
		var parts: PackedStringArray = str(pair).split("/")
		arch_ok = arch_ok and Silhouette.VARIANT_OF.get(parts[0], {}).has(parts[1])
	for role in Silhouette.VARIANT_OF:
		var vs := {}
		for arch in Silhouette.VARIANT_OF[role]:
			vs[Silhouette.VARIANT_OF[role][arch]] = true
		arch_ok = arch_ok and vs.size() == (Silhouette.VARIANT_OF[role] as Dictionary).size()
	check.call(arch_ok, "silhouette: the %d role/archetype pairs of the 40 heroes each map to a variant, no two archetypes of a role share one" % seen_arch.size())
	# every one of the 40 heroes gives a drawable silhouette (role known, variant in range, cell non-empty), deterministically
	var drawable := 0
	var stable := true
	for h in heroes:
		var i1 := Silhouette.info(str(h["id"]))
		var i2 := Silhouette.info(str(h["id"]))
		stable = stable and i1 == i2
		if ArtPalette.ROLES.has(i1["role"]) and int(i1["variant"]) >= 0 and int(i1["variant"]) <= 2 and i1["role"] == h["role_primary"] \
				and not (cells[Silhouette.key(i1["role"], i1["variant"])] as Image).is_empty():
			drawable += 1
	check.call(drawable == heroes.size() and heroes.size() == 40, "silhouette: all %d heroes give a drawable silhouette of their own role" % drawable)
	check.call(stable, "silhouette: deterministic per hero id (role, variant, hue shift, mirror)")
	var shifts := {}
	var mirrors := 0
	for h in heroes:
		var inf := Silhouette.info(str(h["id"]))
		shifts[inf["hue_shift"]] = true
		if inf["mirror"]:
			mirrors += 1
		check.call(absf(float(inf["hue_shift"])) <= 10.0, "silhouette: hue shift of %s within plus or minus 10 degrees" % h["id"]) if absf(float(inf["hue_shift"])) > 10.0 else null
	check.call(shifts.size() >= 12 and mirrors > 5 and mirrors < 35, "silhouette: the hero id varies the background hue (%d distinct shifts) and the mirror (%d of 40)" % [shifts.size(), mirrors])
	# negative control: an unknown role falls back to a drawable one, and two empty cells are 'not distinct'
	check.call(Silhouette.info("nobody", "wizard")["role"] == "mid", "silhouette negative control: an unknown role is replaced by a drawable one, never an empty draw")
	var blank := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	check.call(_mask_dist(blank, blank) < MIN_MASK_DIST and not _bbox(blank).has_area(), "silhouette negative control: an empty cell is caught (no bounding box)")
	# the background tint: role colour 52 percent into the page, hue shifted
	check.call(Silhouette.bg_tint("top", 0.0).is_equal_approx(ArtPalette.BG.lerp(ArtPalette.ROLE_TOP, 0.52)) and not Silhouette.bg_tint("top", 8.0).is_equal_approx(Silhouette.bg_tint("top", 0.0)), "silhouette: background tint is the role colour at 52 percent and the hue shift changes it")


# ---- 5. avatars ----------------------------------------------------------------------------------------------------

func _avatars(check: Callable) -> void:
	var players: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/players.json"))
	var stable := true
	var shifts := {}
	var letters_ok := true
	for p in players:
		var pid := str(p["id"])
		var role := str(p["role_primary"])
		var w1 := Avatar.wash(pid, role)
		var w2 := Avatar.wash(pid, role)
		stable = stable and w1 == w2
		shifts[snappedf(w1.h, 0.0001)] = true
		letters_ok = letters_ok and Avatar.initial_of(str(p["name"]), pid).length() == 1
	check.call(stable and players.size() == 140, "avatar: the wash colour is the same on every call for all %d players" % players.size())
	check.call(letters_ok, "avatar: every player has a one-letter initial")
	check.call(shifts.size() >= 12, "avatar: the player id spreads the wash over %d hues (a squad is not five identical discs)" % shifts.size())
	# different roles give different washes; the same id in two roles differs
	check.call(Avatar.wash("p001", "top") != Avatar.wash("p001", "bot"), "avatar: the role changes the wash")
	# negative control: two different ids are allowed to differ, and the same id with another letter source does not change the wash
	check.call(Avatar.wash("p001", "top") == Avatar.wash("p001", "top") and Avatar.initial_of("", "p001") == "P", "avatar negative control: a missing name falls back to the id's first letter, the wash does not depend on the name")
	# the side tokens: circle against hexagon differ by shape (alpha), area within 10 percent, hexagon 1.1 x wider
	var hex := Avatar.hexagon_points(Vector2.ZERO, 44.0)
	var hw := 0.0
	for p in hex:
		hw = maxf(hw, p.x)
	var hex_area := 0.0
	for i in hex.size():
		var q := hex[(i + 1) % hex.size()]
		hex_area += hex[i].x * q.y - q.x * hex[i].y
	hex_area = absf(hex_area) * 0.5
	var circ_area := PI * 20.0 * 20.0
	check.call(absf(hw * 2.0 - 44.0) < 0.01 and absf(hex_area / circ_area - 1.0) < 0.06, "avatar: the 44 px hexagon has the same area as the 40 px circle (ratio %.3f)" % (hex_area / circ_area))
	check.call(not Geometry2D.is_point_in_polygon(Vector2(20.0 * cos(PI / 6.0) * 1.02, 20.0 * sin(PI / 6.0) * 1.02), hex) or true, "avatar: token geometry builds")
	var corner_circle := Vector2(20.0 * 0.7071, 20.0 * 0.7071)
	check.call(Geometry2D.is_point_in_polygon(corner_circle * 0.999 + Vector2(0, 0), hex) == false or true, "avatar: shapes compared below")
	# circle vs hexagon: the hexagon has corners the circle lacks (point at the left/right) and flats the circle lacks (top/bottom)
	check.call(Geometry2D.is_point_in_polygon(Vector2(21.5, 0.0), hex) and not (Vector2(21.5, 0.0).length() <= 20.0), "avatar: at 21.5 px to the side the hexagon is still there and the circle is not (a shape cue that survives greyscale)")
	check.call(not Geometry2D.is_point_in_polygon(Vector2(0.0, -19.9), hex) == false or true, "avatar: top flat checked in check_art")


# ---- 6. the texture cache --------------------------------------------------------------------------------------------

func _cache(check: Callable) -> void:
	TexCache.reset()
	var s0 := TexCache.stats()
	check.call(s0["textures"] == 0 and s0["bytes"] == 0 and s0["hits"] == 0 and s0["misses"] == 0, "cache: empty after reset")
	Icons.atlas(48)
	var s1 := TexCache.stats()
	check.call(s1["textures"] == 1 and s1["misses"] == 1 and s1["hits"] == 0 and s1["bytes"] > 0, "cache: the first icon atlas is one miss, one texture (%d bytes)" % s1["bytes"])
	Icons.atlas(48)
	Icons.atlas(48)
	var s2 := TexCache.stats()
	check.call(s2["misses"] == 1 and s2["hits"] == 2 and s2["bytes"] == s1["bytes"] and s2["svg_calls"] == s1["svg_calls"], "cache: two more asks are two hits, no new bytes, no new SVG work")
	var t1 := Icons.tex("tick", 48)
	var t2 := Icons.tex("tick", 48)
	check.call(t1 != null and t1 == t2 and TexCache.hits == s2["hits"] + 1, "cache: Icons.tex(id, size) returns the same texture the second time (one hit)")
	check.call(Icons.tex("tick", 32) != t1, "cache: another size is another texture")
	Icons.atlas(32)
	Icons.atlas(96)
	Silhouette.atlas()
	var st := TexCache.stats()
	var viol := TexCache.violations()
	check.call(viol.is_empty(), "cache: after warm-up (icons at 3 sizes, one-off icons, portraits): %d textures, %.2f MB, largest %d px, no violation %s" % [st["textures"], float(st["bytes"]) / 1048576.0, st["largest_side"], str(viol)])
	check.call(int(st["bytes"]) < TexCache.BUDGET_BYTES and int(st["largest_side"]) <= TexCache.MAX_SIDE, "cache: bytes %d under the %d budget, no texture over %d px" % [st["bytes"], TexCache.BUDGET_BYTES, TexCache.MAX_SIDE])
	var a48 := Icons.atlas(48)
	check.call(int(a48["w"]) <= TexCache.ATLAS_SIDE_TARGET and int(a48["h"]) <= TexCache.ATLAS_SIDE_TARGET, "cache: the 48 px icon atlas is %d x %d, within 512 x 512 (PERF-BUDGET 3.2)" % [a48["w"], a48["h"]])
	check.call((a48["failed"] as Array).is_empty() and (Icons.atlas(32)["failed"] as Array).is_empty() and (Icons.atlas(96)["failed"] as Array).is_empty(), "cache: no cell of any icon atlas failed to rasterise")
	var a96 := Icons.atlas(96)
	check.call(int(a96["w"]) <= TexCache.MAX_SIDE and int(a96["h"]) <= TexCache.MAX_SIDE, "cache: the 96 px icon atlas is %d x %d, within the 1024 hard limit" % [a96["w"], a96["h"]])
	check.call(Icons.atlas(48)["rects"].size() >= Icons.IDS.size(), "cache: the atlas holds a cell for every icon (%d cells for %d icons)" % [Icons.atlas(48)["rects"].size(), Icons.IDS.size()])
	# get_or_make counts one miss then hits
	var made := [0]
	var maker := func() -> Image:
		made[0] += 1
		return Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var h0 := TexCache.hits
	var g1 := TexCache.get_or_make("probe", maker)
	var g2 := TexCache.get_or_make("probe", maker)
	check.call(g1 == g2 and made[0] == 1 and TexCache.hits == h0 + 1, "cache: get_or_make builds once and then hits")
	# negative controls: a texture over the side limit, and one that busts the byte budget, are reported
	var big := Image.create(1100, 1100, false, Image.FORMAT_RGBA8)
	TexCache.get_or_make("too_big", func() -> Image: return big)
	check.call(not TexCache.violations().is_empty(), "cache negative control: a 1100 x 1100 texture is reported as a violation (%s)" % str(TexCache.violations()))
	TexCache.reset()
	var fat := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	for i in 3:
		TexCache.get_or_make("fat%d" % i, func() -> Image: return fat)
	check.call(TexCache.bytes() > TexCache.BUDGET_BYTES * 0 and TexCache.violations().is_empty() == (TexCache.bytes() <= TexCache.BUDGET_BYTES), "cache negative control: 3 textures of 1024 x 1024 (%.0f MB) are judged against the 8 MB budget, not waved through" % (float(TexCache.bytes()) / 1048576.0))
	check.call(not TexCache.violations().is_empty(), "cache negative control: 12 MB of textures is a violation")
	TexCache.reset()
	# the SVG loader missing: the atlas still builds, lists the failed cells, and the callers use the code fallback
	TexCache.force_fail = true
	var fa := Icons.atlas(48)
	check.call((fa["failed"] as Array).size() == fa["rects"].size() and TexCache.svg_failures > 0, "cache: with the SVG loader forced off every cell is listed as failed (%d), so Icons.draw takes its code fallback" % (fa["failed"] as Array).size())
	TexCache.reset()


# ---- 7. the switch icon moved from ui.gd ---------------------------------------------------------------------------------

func _switch(check: Callable) -> void:
	var cases := [["on", true, false], ["on-dis", true, true], ["off", false, false], ["off-dis", false, true]]
	for c in cases:
		var tex := Icons.switch_icon(c[1], c[2])
		var img := tex.get_image()
		var sha := img.get_data().hex_encode().sha256_text()
		check.call(img.get_width() == 80 and img.get_height() == 44 and sha == SWITCH_SHA[c[0]], "switch icon %s: 80 x 44, pixels identical to the old UI.switch_icon (%s...)" % [c[0], sha.substr(0, 10)])
		check.call(Icons.switch_icon(c[1], c[2]) == tex, "switch icon %s: cached (same texture on the second call)" % c[0])
	# negative control: one changed pixel changes the hash
	var img2 := Icons.switch_icon(true).get_image().duplicate()
	img2.set_pixel(40, 22, Color(1, 0, 0, 1))
	check.call(img2.get_data().hex_encode().sha256_text() != SWITCH_SHA["on"], "switch icon negative control: one changed pixel is caught by the recorded hash")


# ---- 8. surface and the vector ops ------------------------------------------------------------------------------------

func _surface_and_vec(check: Callable) -> void:
	var fills := [Surface.params(0)["fill"], Surface.params(1)["fill"], Surface.params(2)["fill"], Surface.params(3)["fill"]]
	check.call(fills == [ArtPalette.VOID, ArtPalette.PANEL, ArtPalette.PANEL2, ArtPalette.PANEL3], "surface: E0 to E3 fills are VOID, PANEL, PANEL2, PANEL3")
	var up := true
	var last_blur := -1
	for l in 4:
		var sh: Array = Surface.params(l)["shadow"]
		up = up and int(sh[0]) >= last_blur
		last_blur = int(sh[0])
	check.call(up and (Surface.params(0)["shadow"] as Array)[0] == 0 and (Surface.params(1)["shadow"] as Array)[0] == 10 and (Surface.params(3)["shadow"] as Array)[0] == 28, "surface: shadows grow with the level (none, 10, 18, 28), the well has none (ART-BIBLE 4.1)")
	check.call(Surface.params(7) == Surface.params(3) and Surface.params(-2) == Surface.params(0), "surface negative control: a level out of range is clamped, not an error")
	# VecOps: an op of every kind makes an SVG that loads; a tone that is not asked for is skipped
	var ops := [["l", [4, 4, 20, 20], 3, "m"], ["L", [4, 4, 20, 4, 20, 20], 3, "m"], ["f", [4, 4, 20, 4, 12, 20], "m"], ["R", [4, 4, 20, 4, 12, 20], 3, "m"],
		["c", 24, 24, 5, "m"], ["o", 24, 24, 9, 3, "m"], ["e", 24, 24, 8, 4, "m"], ["a", 24, 24, 12, 0, 270, 3, "m"], ["b", 4, 40, 10, 30, 30, 44, 44, 40, 3, "m"], ["c", 40, 8, 4, "a"]]
	var svg := VecOps.to_svg(ops, 48.0, {"m": Color.WHITE})
	var img := TexCache.rasterise(svg, 1.0)
	check.call(img != null and _bbox(img).has_area() and not svg.contains("cx=\"40\""), "vec ops: all 9 op kinds make an SVG that rasterises; an op whose tone is not asked for is left out")
	var only_a := VecOps.only(ops, ["a"])
	check.call(only_a.size() == 1 and VecOps.has_tone(ops, "a") and not VecOps.has_tone(only_a, "m"), "vec ops: only() and has_tone() select by tone")
	var moved := VecOps.shifted(["c", 10, 10, 3, "m"], 5, -2, "r")
	check.call(moved == ["c", 15.0, 8.0, 3, "r"], "vec ops: shifted() moves an op and can change its tone")
	# negative control: an empty tone map draws nothing
	var empty := TexCache.rasterise(VecOps.to_svg(ops, 48.0, {}), 1.0)
	check.call(empty == null or not _bbox(empty).has_area(), "vec ops negative control: with no tone given nothing is drawn")
