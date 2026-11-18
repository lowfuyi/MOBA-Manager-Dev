extends Node
## I-05 art code, scene part (needs the autoloads, and for the picture checks a renderer).
##   headless:  token and document cross-checks only (the picture checks print SKIPPED)
##   Xvfb:      xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 res://tests/check_art.tscn [-- sheets=<dir>]
##              draws badges, silhouettes, icons, avatars and side tokens into the real window and checks the pictures
##              (non-empty bounding box, colour dependence, the SVG-off fallback), counts draw calls and nodes of a 20-badge
##              gallery, and with sheets=<dir> saves the gallery sheets (normal, greyscale and deutan views).
## Ends with " N checks, M failures".

const BG := Color("0a1120")
const ART_DOCS := "../docs/design/art/"
const BIBLE := "../docs/design/ART-BIBLE.md"

class Sheet extends Control:
	var fn: Callable
	func _draw() -> void:
		fn.call(self)

var checks := 0
var fails := 0
var sheet_dir := ""
var rendering := false
var base_draws := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ready() -> void:
	OS.low_processor_usage_mode = false    # the game sleeps when idle (I-25); the picture checks wait for drawn frames
	get_window().size = Vector2i(720, 1280)    # a headless window is 100 x 100 until told otherwise
	for a in OS.get_cmdline_user_args():
		if a.begins_with("sheets="):
			sheet_dir = a.substr(7)
	rendering = DisplayServer.get_name() != "headless"
	await get_tree().process_frame
	_tokens()
	_docs()
	if rendering:
		await _render()
	else:
		print("SKIPPED: picture checks need a renderer (run under xvfb-run with --rendering-driver opengl3)")
	TexCache.reset()
	print("check_art: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


# ---- cross-checks that need no renderer -----------------------------------------------------------------------------------

func _tokens() -> void:
	var ui: GDScript = load("res://src/ui/ui.gd")
	var ui_c: Dictionary = ui.get_script_constant_map()
	var art_c: Dictionary = (load("res://src/ui/art/art_palette.gd") as GDScript).get_script_constant_map()
	var compared := 0
	var wrong: Array = []
	for k in art_c:
		if art_c[k] is Color:
			if not ui_c.has(k):
				wrong.append(str(k) + " (no such token in UI)")
				continue
			compared += 1
			if ui_c[k] != art_c[k]:
				wrong.append(str(k))
	ok(compared >= 20 and wrong.is_empty(), "ArtPalette: %d colours compared with the UI constants of the same name, all equal %s" % [compared, str(wrong)])
	ok(ui_c["TEXT"] != art_c["BG"], "ArtPalette negative control: the comparison tells two different tokens apart")
	var t := UI.make_theme()
	ok(t.get_icon("checked", "CheckButton") == Icons.switch_icon(true) and t.get_icon("unchecked", "CheckButton") == Icons.switch_icon(false), "switch icon: the theme's CheckButton icons are Icons.switch_icon (the move from ui.gd works)")
	var has_old := false
	for m in ui.get_script_method_list():
		if str(m["name"]) == "switch_icon" or str(m["name"]) == "_seg_dist":
			has_old = true
	ok(not has_old, "switch icon: ui.gd no longer carries switch_icon or its helpers")


func _read(rel: String) -> String:
	return FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join(rel))


func _docs() -> void:
	var same := 0
	for pair in [["top", "top"], ["jg", "jungle"], ["mid", "mid"], ["bot", "bot"], ["sup", "support"]]:
		var f := _read(ART_DOCS + "ic_role_%s.svg" % pair[1]).strip_edges()
		if f != "" and f == Icons.svg_of("role_" + pair[0]):
			same += 1
	ok(same == 5, "role glyphs: the 5 embedded SVG strings are byte-identical to docs/design/art/ic_role_*.svg (%d of 5)" % same)
	ok(_read(ART_DOCS + "ic_role_top.svg").strip_edges() != Icons.svg_of("role_bot"), "role glyphs negative control: a different glyph is not 'identical'")
	var rx := RegEx.new()
	rx.compile("^\\| ([a-z_]+) \\| ([0-9a-f]{8}) \\| (\\d+) \\| (\\w+) \\| (\\w+) \\| `#([0-9A-F]{6})` \\| `#([0-9A-F]{6})` \\|")
	var rows := 0
	var good := 0
	var ids: Array = []
	var table: Array = []
	for line in _read(BIBLE).split("\n"):
		var m := rx.search(line)
		if m:
			rows += 1
			ids.append(m.get_string(1))
			table.append(m)
	var st := BadgeStyle.resolve(ids)
	for m in table:
		var s: Dictionary = st[m.get_string(1)]
		var pri := Color("#" + m.get_string(6))
		var sec := Color("#" + m.get_string(7))
		var shape_ok: bool = s["shape_name"] == m.get_string(4) or (s["shape_name"] == "banner" and m.get_string(4) == "banner")
		var d: float = absf(s["primary"].r - pri.r) + absf(s["primary"].g - pri.g) + absf(s["primary"].b - pri.b)
		if ("%08x" % s["hash"]) == m.get_string(2) and s["hue"] == int(m.get_string(3)) and shape_ok and s["pattern_name"] == m.get_string(5) and d <= 3.0 / 255.0 and s["secondary"].is_equal_approx(sec):
			good += 1
	ok(rows == 10 and good == 10, "badge: the table is read from ART-BIBLE.md 6.3 itself (%d rows) and BadgeStyle reproduces %d of them" % [rows, good])


# ---- picture helpers -----------------------------------------------------------------------------------------------------

func _page(fn: Callable) -> Array:
	## Draw `fn(canvas)` full-window, return [Image, draw_calls_in_frame, canvas_objects].
	var s := Sheet.new()
	s.size = Vector2(720, 1280)
	s.fn = func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 720, 1280), BG)
		fn.call(c)
	add_child(s)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var img := get_viewport().get_texture().get_image()
	s.queue_free()
	await get_tree().process_frame
	return [img, draws, objs]


func _bbox(img: Image, rect: Rect2i, tol: float = 0.05) -> Rect2i:
	var x0 := 99999
	var y0 := 99999
	var x1 := -1
	var y1 := -1
	for y in range(maxi(rect.position.y, 0), mini(rect.end.y, img.get_height())):
		for x in range(maxi(rect.position.x, 0), mini(rect.end.x, img.get_width())):
			var c := img.get_pixel(x, y)
			if absf(c.r - BG.r) + absf(c.g - BG.g) + absf(c.b - BG.b) > tol:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i()
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func _count_near(img: Image, rect: Rect2i, col: Color, tol: float = 0.06) -> int:
	var n := 0
	for y in range(maxi(rect.position.y, 0), mini(rect.end.y, img.get_height())):
		for x in range(maxi(rect.position.x, 0), mini(rect.end.x, img.get_width())):
			var c := img.get_pixel(x, y)
			if absf(c.r - col.r) + absf(c.g - col.g) + absf(c.b - col.b) <= tol:
				n += 1
	return n


func _mean(img: Image, rect: Rect2i) -> Color:
	var sum := Vector3.ZERO
	var n := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y)
			if absf(c.r - BG.r) + absf(c.g - BG.g) + absf(c.b - BG.b) > 0.05:
				sum += Vector3(c.r, c.g, c.b)
				n += 1
	if n == 0:
		return Color(0, 0, 0)
	sum /= float(n)
	return Color(sum.x, sum.y, sum.z)


func _is_ink(c: Color) -> bool:
	return absf(c.r - 0.051) + absf(c.g - 0.082) + absf(c.b - 0.149) < 0.07 and c.a > 0.9


func _clubs() -> Array:
	var rows: Array = JSON.parse_string(_read("data/clubs.json"))
	return rows


func _league_ids() -> Array:
	var ids: Array = []
	for c in _clubs():
		ids.append(str(c["id"]))
	ids.append("harrowgate_kestrels")
	return ids


# ---- the picture checks -----------------------------------------------------------------------------------------------------

func _render() -> void:
	TexCache.reset()
	Badge.reset_cache()
	var empty: Array = await _page(func(_c: Control) -> void: pass)
	base_draws = empty[1]
	print("art|empty page|draw_calls=%d|objects=%d" % [empty[1], empty[2]])
	var ids := _league_ids()
	var styles := BadgeStyle.resolve(ids)
	var names := {}
	for c in _clubs():
		names[str(c["id"])] = str(c["name"])
	names["harrowgate_kestrels"] = "Harrowgate Kestrels"
	var font: Font = UI.font("ExtraBold")
	# texture memory of the whole art set, warmed up before anything is drawn: the cache's own count and the renderer's
	var tex_before := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	Badge.prepare(styles)
	Badge.atlas(48)
	Badge.atlas(72)
	Badge.atlas(112)
	Icons.atlas(32)
	Icons.atlas(48)
	Icons.atlas(96)
	Silhouette.atlas()
	for i in 3:
		await get_tree().process_frame
	var tex_warm := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var warm := TexCache.stats()
	print("art|warm-up of every atlas (icons x3 sizes, portraits, 11 badges x3 sizes)|cache %.2f MB in %d textures|renderer texture memory %d -> %d bytes (+%.2f MB)|svg_ms %.1f" % [float(warm["bytes"]) / 1048576.0, warm["textures"], tex_before, tex_warm, float(tex_warm - tex_before) / 1048576.0, warm["rasterise_ms"]])
	ok(TexCache.violations().is_empty() and float(tex_warm - tex_before) < 8.0 * 1048576.0, "texture memory after warm-up of the whole art set: cache %.2f MB, renderer +%.2f MB, both under the 8 MB budget, no texture over 1024 px (largest %d)" % [float(warm["bytes"]) / 1048576.0, float(tex_warm - tex_before) / 1048576.0, warm["largest_side"]])

	# --- badges: every club at 96 px: a picture inside its rect, the ink letter present, the primary colour present
	var page: Array = await _page(func(c: Control) -> void:
		for i in ids.size():
			Badge.draw(c, styles[ids[i]], names[ids[i]], Rect2(24 + (i % 5) * 136, 24 + (i / 5) * 136, 112, 112), font))
	var img: Image = page[0]
	var bad: Array = []
	for i in ids.size():
		var r := Rect2i(24 + (i % 5) * 136, 24 + (i / 5) * 136, 112, 112)
		var bb := _bbox(img, Rect2i(r.position - Vector2i(6, 6), r.size + Vector2i(12, 12)))
		var prim := _count_near(img, r, styles[ids[i]]["primary"], 0.05)
		var ink := _count_near(img, r, BadgeStyle.INK, 0.10)
		if not (bb.has_area() and bb.size.x >= 80 and bb.size.y >= 80 and prim > 1500 and ink > 60):
			bad.append("%s bbox %s primary px %d ink px %d" % [ids[i], bb, prim, ink])
	ok(bad.is_empty(), "badges: all %d draw a picture of at least 80 x 80 inside their 112 px box, with their primary colour and an ink letter %s" % [ids.size(), str(bad)])
	# negative control: an empty rect holds no picture
	ok(not _bbox(img, Rect2i(24, 700, 112, 112)).has_area(), "badge negative control: an area where nothing was drawn has no bounding box")
	# touch size and colour dependence (second look): at 40 px the badge is still a picture with a letter
	var small: Array = await _page(func(c: Control) -> void:
		for i in ids.size():
			Badge.draw(c, styles[ids[i]], names[ids[i]], Rect2(24 + i * 56, 24, 40, 40), font))
	var small_bad: Array = []
	for i in ids.size():
		var r := Rect2i(24 + i * 56, 24, 40, 40)
		var bb := _bbox(small[0], r)
		if not (bb.size.x >= 30 and bb.size.y >= 30 and _count_near(small[0], r, BadgeStyle.INK, 0.12) >= 8):
			small_bad.append("%s %s" % [ids[i], bb])
	ok(small_bad.is_empty(), "badges at 40 px (the smallest size): all %d still show a body of at least 30 px and a letter %s" % [ids.size(), str(small_bad)])

	# --- the 20-badge gallery: nodes and draw calls
	var gal_ids: Array = []
	for i in 20:
		gal_ids.append("club_%02d" % i)
	var gal := BadgeStyle.resolve(gal_ids)
	var items: Array = []
	var unprepared: Array = await _page(func(cv: Control) -> void:    # first the polygon fallback, before the gallery is prepared
		for i in 20:
			Badge.draw(cv, gal[gal_ids[i]], "Club %02d" % i, Rect2(24 + (i % 5) * 136, 24 + (i / 5) * 136, 112, 112), font))
	print("art|gallery of 20 badges|NOT prepared (polygon fallback)|nodes=1|draw_calls=%d|objects=%d" % [unprepared[1], unprepared[2]])
	Badge.prepare(gal)
	for i in 20:
		items.append({"club": gal[gal_ids[i]], "name": "Club %02d" % i, "rect": Rect2(24 + (i % 5) * 136, 24 + (i / 5) * 136, 112, 112)})
	var batch: Array = await _page(func(c: Control) -> void: Badge.draw_batch(c, items, font))
	var interleaved: Array = await _page(func(c: Control) -> void:
		for it in items:
			Badge.draw(c, it["club"], it["name"], it["rect"], font))
	# twenty Controls, one per badge
	var holders: Array = []
	var many := Control.new()
	add_child(many)
	var bg := Sheet.new()
	bg.size = Vector2(720, 1280)
	bg.fn = func(c: Control) -> void: c.draw_rect(Rect2(0, 0, 720, 1280), BG)
	many.add_child(bg)
	for it in items:
		var s := Sheet.new()
		s.position = (it["rect"] as Rect2).position
		s.size = Vector2(112, 112)
		var local: Dictionary = it
		s.fn = func(c: Control) -> void: Badge.draw(c, local["club"], local["name"], Rect2(Vector2.ZERO, Vector2(112, 112)), font)
		many.add_child(s)
		holders.append(s)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var per_node_draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var per_node_objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var per_node_nodes := 1 + many.get_child_count()
	many.queue_free()
	await get_tree().process_frame
	print("art|gallery of 20 badges|one Control, draw_batch|nodes=1|draw_calls=%d (page alone %d)|objects=%d" % [batch[1], base_draws, batch[2]])
	print("art|gallery of 20 badges|one Control, badge by badge|nodes=1|draw_calls=%d|objects=%d" % [interleaved[1], interleaved[2]])
	print("art|gallery of 20 badges|20 Controls (+1 page)|nodes=%d|draw_calls=%d|objects=%d" % [per_node_nodes, per_node_draws, per_node_objs])
	ok(batch[1] - base_draws <= 3, "gallery of 20 badges, one Control with draw_batch: %d draw calls over the %d of an empty page (limit 3), 1 node" % [batch[1] - base_draws, base_draws])
	ok(interleaved[1] - base_draws <= 45, "gallery of 20 badges drawn badge by badge: %d calls over the page (limit 2 per badge + 5)" % (interleaved[1] - base_draws))
	ok(per_node_nodes == 22 and per_node_draws - base_draws <= 45, "gallery of 20 badges as 20 Controls: %d nodes, %d calls over the page (limit 2 per badge + 5; 22 nodes against 1)" % [per_node_nodes, per_node_draws - base_draws])
	ok(batch[1] < interleaved[1], "negative control: the batched gallery needs fewer draw calls (%d) than the interleaved one (%d), so the batch is doing its job" % [batch[1], interleaved[1]])
	ok(unprepared[1] > 100, "negative control: the same gallery NOT prepared takes the polygon fallback and costs %d calls, which is why Badge.prepare() exists" % unprepared[1])
	var gal_img: Image = batch[0]
	var gal_bad: Array = []
	for i in 20:
		var r := Rect2i(24 + (i % 5) * 136, 24 + (i / 5) * 136, 112, 112)
		if not (_bbox(gal_img, r).size.x >= 80 and _count_near(gal_img, r, gal[gal_ids[i]]["primary"], 0.05) > 1500 and _count_near(gal_img, r, BadgeStyle.INK, 0.10) > 40):
			gal_bad.append(gal_ids[i])
	ok(gal_bad.is_empty(), "gallery of 20 (prepared, from the atlas): every badge has its body colour and its letter %s" % str(gal_bad))

	# --- the 40 heroes at 96, 64 and 48 px
	var heroes: Array = JSON.parse_string(_read("data/heroes.json"))
	Silhouette.register(heroes)
	var hero_page: Array = await _page(func(c: Control) -> void:
		for i in heroes.size():
			Silhouette.draw(c, str(heroes[i]["id"]), Rect2(12 + (i % 6) * 116, 12 + (i / 6) * 116, 96, 96)))
	var hbad: Array = []
	for i in heroes.size():
		var r := Rect2i(12 + (i % 6) * 116, 12 + (i / 6) * 116, 96, 96)
		var bb := _bbox(hero_page[0], r)
		var role_col := ArtPalette.role_color(str(heroes[i]["role_primary"]))
		if not (bb.size.x >= 90 and bb.size.y >= 90 and _count_near(hero_page[0], r, role_col, 0.06) >= 150):
			hbad.append("%s %s ring px %d" % [heroes[i]["id"], bb, _count_near(hero_page[0], r, role_col, 0.06)])
	ok(hbad.is_empty(), "portraits: all 40 heroes draw a 90 px picture with the ring and accents in their role colour %s" % str(hbad))
	print("art|40 portraits at 96 px, one Control|nodes=1|draw_calls=%d (page alone %d)|objects=%d" % [hero_page[1], base_draws, hero_page[2]])
	ok(hero_page[1] - base_draws <= 3, "portraits: 40 heroes are %d draw calls over the page (one atlas texture, limit 3)" % (hero_page[1] - base_draws))
	var p48: Array = await _page(func(c: Control) -> void:
		for i in heroes.size():
			Silhouette.draw(c, str(heroes[i]["id"]), Rect2(12 + (i % 10) * 70, 12 + (i / 10) * 70, 48, 48)))
	var p48_plain: Array = await _page(func(c: Control) -> void:
		for i in heroes.size():
			Silhouette.draw(c, str(heroes[i]["id"]), Rect2(12 + (i % 10) * 70, 12 + (i / 10) * 70, 48, 48), {"corner_glyph": false}))
	var gbad := 0
	for i in heroes.size():
		var r := Rect2i(12 + (i % 10) * 70, 12 + (i / 10) * 70, 48, 48)
		var box := Rect2i(r.end - Vector2i(26, 26), Vector2i(26, 26))
		var differ := 0
		for y in range(box.position.y, box.end.y):
			for x in range(box.position.x, box.end.x):
				if (p48[0] as Image).get_pixel(x, y).is_equal_approx((p48_plain[0] as Image).get_pixel(x, y)) == false:
					differ += 1
		if differ < 250 or _count_near(p48[0], box, ArtPalette.role_color(str(heroes[i]["role_primary"])), 0.08) < 15:
			gbad += 1
	ok(gbad == 0, "portraits at 48 px: all 40 carry the corner chip (a 26 px dark disc with the role-colour rim and glyph; %d missing)" % gbad)
	print("art|40 portraits at 48 px with corner chips|draw_calls=%d (page alone %d)|objects=%d" % [p48[1], base_draws, p48[2]])
	ok(p48[1] - base_draws <= 3, "portraits at 48 px with corner chips: 40 heroes are %d draw calls over the page (chips are cells of the same atlas, limit 3)" % (p48[1] - base_draws))
	# banned: ring turns TEXT_OFF, a BAD slash is added, the picture is dimmer
	var ban_page: Array = await _page(func(c: Control) -> void:
		Silhouette.draw(c, "brannoch", Rect2(24, 24, 96, 96))
		Silhouette.draw(c, "brannoch", Rect2(144, 24, 96, 96), {"banned": true}))
	var normal_ring := _count_near(ban_page[0], Rect2i(24, 24, 96, 96), ArtPalette.ROLE_TOP, 0.06)
	var banned_ring := _count_near(ban_page[0], Rect2i(144, 24, 96, 96), ArtPalette.TEXT_OFF, 0.06)
	var slash := _count_near(ban_page[0], Rect2i(144, 24, 96, 96), ArtPalette.BAD_DEFAULT, 0.06)
	ok(normal_ring > 300 and banned_ring > 300 and slash > 200 and _count_near(ban_page[0], Rect2i(144, 24, 96, 96), ArtPalette.ROLE_TOP, 0.04) < 60, "portrait banned state: role ring becomes TEXT_OFF (%d px), a BAD slash appears (%d px), the role ring colour is gone" % [banned_ring, slash])
	var mirror_page: Array = await _page(func(c: Control) -> void:
		Silhouette.draw_role(c, "bot", 0, Rect2(24, 24, 96, 96), 0.0, false)
		Silhouette.draw_role(c, "bot", 0, Rect2(144, 24, 96, 96), 0.0, true))
	var left_img: Image = (mirror_page[0] as Image).get_region(Rect2i(24, 24, 96, 96))
	var right_img: Image = (mirror_page[0] as Image).get_region(Rect2i(144, 24, 96, 96))
	left_img.flip_x()
	var mism := 0
	var ink_px := 0
	for y in 96:
		for x in 96:
			var li := _is_ink(left_img.get_pixel(x, y))
			var ri := _is_ink(right_img.get_pixel(x, y))
			if li:
				ink_px += 1
			if li != ri:
				mism += 1
	ok(ink_px > 1500 and float(mism) / float(ink_px) < 0.05, "portrait mirror: the ink bust of the mirrored portrait is the left-right image of the plain one (%d of %d ink pixels differ)" % [mism, ink_px])
	var unflipped: Image = (mirror_page[0] as Image).get_region(Rect2i(24, 24, 96, 96))
	var mism2 := 0
	for y in 96:
		for x in 96:
			if _is_ink(unflipped.get_pixel(x, y)) != _is_ink(right_img.get_pixel(x, y)):
				mism2 += 1
	ok(mism2 > 4 * mism and mism2 > 400, "portrait mirror negative control: the mirrored portrait is NOT the same as the plain one (%d pixels differ), so the comparison can fail" % mism2)

	# --- icons: every icon at 48 px in two colours: non-empty bounding box, colour follows the tint, the accent takes its own colour
	var icon_ids: Array = Icons.IDS
	var cols := 8
	var icon_page: Array = await _page(func(c: Control) -> void:
		for i in icon_ids.size():
			Icons.draw(c, icon_ids[i], Rect2(24 + (i % cols) * 84, 24 + (i / cols) * 84, 48, 48), ArtPalette.TEXT2, ArtPalette.TEAL_HI))
	var ibad: Array = []
	var acc_missing: Array = []
	for i in icon_ids.size():
		var r := Rect2i(24 + (i % cols) * 84, 24 + (i / cols) * 84, 48, 48)
		var bb := _bbox(icon_page[0], r)
		if not (bb.has_area() and maxi(bb.size.x, bb.size.y) >= 24 and mini(bb.size.x, bb.size.y) >= 6):
			ibad.append("%s %s" % [icon_ids[i], bb])
		if VecOps.has_tone(Icons.ops_of(icon_ids[i]), "a") and _count_near(icon_page[0], r, ArtPalette.TEAL_HI, 0.10) < 6:
			acc_missing.append(icon_ids[i])
	ok(ibad.is_empty(), "icons at 48 px: all %d draw a picture at least 24 px long and 6 px thick %s" % [icon_ids.size(), str(ibad)])
	ok(acc_missing.is_empty(), "icons: the accent fragment takes the accent colour (TEAL_HI) in every icon that has one %s" % str(acc_missing))
	print("art|icons at 48 px, one Control|nodes=1|draw_calls=%d (page alone %d)|objects=%d" % [icon_page[1], base_draws, icon_page[2]])
	ok(icon_page[1] - base_draws <= 3, "icons: %d icons at 48 px are %d draw calls over the page (one atlas, limit 3)" % [icon_ids.size(), icon_page[1] - base_draws])
	var blue_page: Array = await _page(func(c: Control) -> void:
		for i in icon_ids.size():
			Icons.draw(c, icon_ids[i], Rect2(24 + (i % cols) * 84, 24 + (i / cols) * 84, 48, 48), ArtPalette.ACCENT))
	var colour_bad: Array = []
	for i in icon_ids.size():
		var r := Rect2i(24 + (i % cols) * 84, 24 + (i / cols) * 84, 48, 48)
		var m1 := _mean(icon_page[0], r)
		var m2 := _mean(blue_page[0], r)
		# with the single tint ACCENT (teal) every pixel of the icon is teal: g > r by a wide margin
		if not (m2.g - m2.r > 0.25):
			colour_bad.append("%s %s" % [icon_ids[i], m2])
		var bb1 := _bbox(icon_page[0], r)
		var bb2 := _bbox(blue_page[0], r)
		if bb1 != bb2:
			colour_bad.append("%s bbox moved with colour %s %s" % [icon_ids[i], bb1, bb2])
	ok(colour_bad.is_empty(), "icons: the picture does not depend on the colour (same bounding box) and the tint colours all of it %s" % str(colour_bad))
	# sizes: 28 (chip), 32, 64, 96 pick the right atlas and stay inside their rect
	var size_page: Array = await _page(func(c: Control) -> void:
		var x := 12.0
		for s in [28.0, 32.0, 48.0, 64.0, 96.0]:
			Icons.draw(c, "tab_squad", Rect2(x, 24, s, s), ArtPalette.TEXT2, ArtPalette.TEAL_HI)
			Icons.draw(c, "role_mid", Rect2(x, 140, s, s), ArtPalette.ROLE_MID)
			x += s + 24.0)
	var sbad: Array = []
	var xx := 12.0
	for s in [28, 32, 48, 64, 96]:
		for row_y in [24, 140]:
			var bb := _bbox(size_page[0], Rect2i(int(xx) - 2, row_y - 2, s + 4, s + 4))
			if not (bb.has_area() and bb.size.x >= int(s * 0.6) and bb.position.x >= int(xx) - 1 and bb.end.x <= int(xx) + s + 1):
				sbad.append("%d px y%d %s" % [s, row_y, bb])
		xx += s + 24
	ok(sbad.is_empty(), "icons at 28, 32, 48, 64 and 96 px: each stays inside its rect and fills at least 60 percent of it %s" % str(sbad))
	# --- the SVG loader missing: every icon, portrait and avatar still draws something (the code fallback)
	TexCache.reset()
	TexCache.force_fail = true
	var fb_page: Array = await _page(func(c: Control) -> void:
		for i in icon_ids.size():
			Icons.draw(c, icon_ids[i], Rect2(24 + (i % cols) * 84, 24 + (i / cols) * 84, 48, 48), ArtPalette.TEXT2, ArtPalette.TEAL_HI)
		Silhouette.draw(c, "brannoch", Rect2(24, 900, 96, 96))
		Avatar.draw(c, "p001", Rect2(144, 900, 96, 96), {"name": "Ashjin", "role": "top", "font": font}))
	var fbad: Array = []
	for i in icon_ids.size():
		var r := Rect2i(24 + (i % cols) * 84, 24 + (i / cols) * 84, 48, 48)
		var bb := _bbox(fb_page[0], r)
		var bb0 := _bbox(icon_page[0], r)
		if not (bb.has_area() and float(bb.get_area()) >= 0.4 * float(bb0.get_area())):
			fbad.append("%s %s vs %s" % [icon_ids[i], bb, bb0])
	ok(fbad.is_empty(), "SVG loader forced off: all %d icons still draw (code fallback, at least 40 percent of the normal picture) %s" % [icon_ids.size(), str(fbad)])
	ok(_bbox(fb_page[0], Rect2i(24, 900, 96, 96)).has_area() and _bbox(fb_page[0], Rect2i(144, 900, 96, 96)).has_area(), "SVG loader forced off: a portrait and an avatar still draw")
	ok(TexCache.svg_failures > 0, "SVG loader forced off: the failures are counted (%d), so a build can report them" % TexCache.svg_failures)
	TexCache.reset()

	# --- avatars and the two side tokens
	var players: Array = JSON.parse_string(_read("data/players.json"))
	var av_page: Array = await _page(func(c: Control) -> void:
		for i in 15:
			var p: Dictionary = players[i]
			Avatar.draw(c, str(p["id"]), Rect2(24 + (i % 5) * 136, 24 + (i / 5) * 136, 96, 96), {"name": str(p["name"]), "role": str(p["role_primary"]), "font": font}))
	var av_page2: Array = await _page(func(c: Control) -> void:
		for i in 15:
			var p: Dictionary = players[i]
			Avatar.draw(c, str(p["id"]), Rect2(24 + (i % 5) * 136, 24 + (i / 5) * 136, 96, 96), {"name": str(p["name"]), "role": str(p["role_primary"]), "font": font}))
	var same := true
	for y in range(0, 500, 3):
		for x in range(0, 720, 3):
			same = same and av_page[0].get_pixel(x, y) == av_page2[0].get_pixel(x, y)
	ok(same, "avatars: two draws of the same 15 players give the same picture, pixel for pixel")
	var abad: Array = []
	for i in 15:
		var p: Dictionary = players[i]
		var r := Rect2i(24 + (i % 5) * 136, 24 + (i / 5) * 136, 96, 96)
		var bb := _bbox(av_page[0], r)
		var ring := _count_near(av_page[0], r, ArtPalette.role_color(str(p["role_primary"])), 0.06)
		var letter := _count_near(av_page[0], Rect2i(r.position + Vector2i(24, 24), Vector2i(48, 48)), ArtPalette.TEXT, 0.12)
		if not (bb.size.x >= 90 and ring > 200 and letter > 30):
			abad.append("%s %s ring %d letter %d" % [p["id"], bb, ring, letter])
	ok(abad.is_empty(), "avatars: 15 players draw a 90 px disc with the role ring and the initial in TEXT %s" % str(abad))
	var tok: Array = await _page(func(c: Control) -> void:
		Avatar.draw_token(c, true, Vector2(60, 60), 40.0, "M", font)
		Avatar.draw_token(c, false, Vector2(160, 60), 40.0, "M", font))
	var teal_px := _count_near(tok[0], Rect2i(30, 30, 60, 60), ArtPalette.ACCENT, 0.06)
	var coral_px := _count_near(tok[0], Rect2i(130, 30, 60, 60), ArtPalette.CORAL, 0.06)
	ok(teal_px > 400 and coral_px > 400, "side tokens: teal circle (%d px) and coral hexagon (%d px) both draw" % [teal_px, coral_px])
	# shape cue: in greyscale the two tokens are told apart by their outline (corner at the side for the hexagon, none for the circle)
	var cw := _bbox(tok[0], Rect2i(20, 20, 80, 80))
	var hw := _bbox(tok[0], Rect2i(120, 20, 80, 80))
	ok(hw.size.x > cw.size.x + 2 and hw.size.y <= cw.size.y + 2, "side tokens: the hexagon is wider than the circle (%d against %d px) and not taller (flat top and bottom): a shape difference that survives greyscale" % [hw.size.x, cw.size.x])
	# negative control: two circles have the same width (the shape check above can fail)
	var tok2: Array = await _page(func(c: Control) -> void:
		Avatar.draw_token(c, true, Vector2(60, 60), 40.0, "M", font)
		Avatar.draw_token(c, true, Vector2(160, 60), 40.0, "M", font))
	ok(_bbox(tok2[0], Rect2i(120, 20, 80, 80)).size.x == _bbox(tok2[0], Rect2i(20, 20, 80, 80)).size.x, "side token negative control: two circles have exactly the same width, so equal shapes are caught")

	# --- texture memory at the end (everything drawn above went through the cache)
	var st := TexCache.stats()
	print("art|texture cache at the end|%s" % str(st))

	if sheet_dir != "":
		await _sheets(styles, names, font, players, heroes)


# ---- gallery sheets ----------------------------------------------------------------------------------------------------------

func _view_image(img: Image, mode: String) -> Image:
	var out: Image = img.duplicate()
	var sim := {"grey": null,
		"deutan": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]}
	var m = sim[mode]
	for y in out.get_height():
		for x in out.get_width():
			var c: Color = out.get_pixel(x, y)
			var r: Color = c.srgb_to_linear()
			var o: Color
			if m == null:
				var l: float = 0.2126 * r.r + 0.7152 * r.g + 0.0722 * r.b
				o = Color(l, l, l).linear_to_srgb()
			else:
				o = Color(clampf(m[0][0] * r.r + m[0][1] * r.g + m[0][2] * r.b, 0, 1), clampf(m[1][0] * r.r + m[1][1] * r.g + m[1][2] * r.b, 0, 1), clampf(m[2][0] * r.r + m[2][1] * r.g + m[2][2] * r.b, 0, 1)).linear_to_srgb()
			out.set_pixel(x, y, o)
	return out


func _label(c: Control, text: String, pos: Vector2, size: int = 24, col: Color = ArtPalette.TEXT2) -> void:
	c.draw_string(UI.font("SemiBold"), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _save(name: String, img: Image) -> void:
	DirAccess.make_dir_recursive_absolute(sheet_dir)
	img.save_png("%s/%s.png" % [sheet_dir, name])
	print("art|sheet|%s/%s.png" % [sheet_dir, name])


func _sheets(styles: Dictionary, names: Dictionary, font: Font, players: Array, heroes: Array) -> void:
	var ids: Array = styles.keys()
	ids.sort()
	# badges: rows at 112, 64, 48 and 40 px on the page colour and on the card colour
	var grid_styles: Array = []
	for sh in 6:
		for pt in 4:
			var gst: Dictionary = BadgeStyle.resolve(["x"])["x"].duplicate()
			gst["shape"] = sh
			gst["shape_name"] = BadgeStyle.SHAPES[sh]
			gst["pattern"] = pt
			gst["pattern_name"] = BadgeStyle.PATTERNS[pt]
			gst["id"] = "grid_%d_%d" % [sh, pt]
			grid_styles.append(gst)
	Badge.prepare(grid_styles)
	Badge.prepare(styles)
	var bad_page: Array = await _page(func(c: Control) -> void:
		_label(c, "Club badges, 11 clubs (10 real, 1 made up), generated from the club id", Vector2(16, 28))
		for i in ids.size():    # 108 px, two rows
			Badge.draw(c, styles[ids[i]], names[ids[i]], Rect2(16 + (i % 6) * 116, 44 + (i / 6) * 118, 108, 108), font)
		_label(c, "64 px", Vector2(16, 292))
		for i in ids.size():
			Badge.draw(c, styles[ids[i]], names[ids[i]], Rect2(16 + i * 64, 302, 64, 64), font)
		_label(c, "48 px", Vector2(16, 392))
		for i in ids.size():
			Badge.draw(c, styles[ids[i]], names[ids[i]], Rect2(16 + i * 60, 402, 48, 48), font)
		_label(c, "40 px (the smallest size)", Vector2(16, 478))
		for i in ids.size():
			Badge.draw(c, styles[ids[i]], names[ids[i]], Rect2(16 + i * 56, 488, 40, 40), font)
		c.draw_rect(Rect2(0, 548, 720, 100), ArtPalette.PANEL)
		_label(c, "on the card colour: 56 px and 28 px", Vector2(16, 574))
		for i in ids.size():
			Badge.draw(c, styles[ids[i]], names[ids[i]], Rect2(16 + i * 62, 584, 56, 56), font)
		for i in ids.size():
			Badge.draw(c, styles[ids[i]], names[ids[i]], Rect2(16 + i * 62, 652, 28, 28), font)
		_label(c, "6 shapes x 4 patterns, one hue: what the generator can make", Vector2(16, 710))
		for sh in 6:
			for pt in 4:
				var st: Dictionary = BadgeStyle.resolve(["x"])["x"].duplicate()
				st["shape"] = sh
				st["shape_name"] = BadgeStyle.SHAPES[sh]
				st["pattern"] = pt
				st["pattern_name"] = BadgeStyle.PATTERNS[pt]
				st["id"] = "grid_%d_%d" % [sh, pt]
				Badge.draw(c, st, "Q", Rect2(16 + sh * 114, 726 + pt * 100, 92, 92), font))
	_save("badges_normal", bad_page[0])
	_save("badges_grey", _view_image(bad_page[0], "grey"))
	_save("badges_deutan", _view_image(bad_page[0], "deutan"))
	# silhouettes: 5 roles x 3 variants at 96, then 64 and 48
	var sil_page: Array = await _page(func(c: Control) -> void:
		_label(c, "Hero portraits: 5 roles x 3 variants; 64, 48 (chip) and banned", Vector2(16, 28), 22)
		for r in 5:
			_label(c, ArtPalette.ROLES[r], Vector2(8, 70 + r * 130), 22)
			for v in 3:
				Silhouette.draw_role(c, ArtPalette.ROLES[r], v, Rect2(70 + v * 112, 44 + r * 130, 96, 96), 0.0, false, false, false)
				Silhouette.draw_role(c, ArtPalette.ROLES[r], v, Rect2(70 + v * 112 + 4, 44 + r * 130 + 100, 24, 24), 0.0, false, false, false)
			Silhouette.draw_role(c, ArtPalette.ROLES[r], 0, Rect2(420, 44 + r * 130, 64, 64), 0.0, false, false, false)
			Silhouette.draw_role(c, ArtPalette.ROLES[r], 0, Rect2(500, 44 + r * 130, 48, 48), 0.0, false, false, true)
			Silhouette.draw_role(c, ArtPalette.ROLES[r], 1, Rect2(560, 44 + r * 130, 48, 48), 0.0, false, false, true)
			Silhouette.draw_role(c, ArtPalette.ROLES[r], 0, Rect2(620, 44 + r * 130, 64, 64), 0.0, false, true, false)
		_label(c, "far right: banned", Vector2(540, 40), 22))
	_save("silhouettes_normal", sil_page[0])
	_save("silhouettes_grey", _view_image(sil_page[0], "grey"))
	_save("silhouettes_deutan", _view_image(sil_page[0], "deutan"))
	var arche: Array = await _page(func(c: Control) -> void:
		_label(c, "The 40 heroes as the draft grid will show them (96 px), hue shift and mirror from the id", Vector2(16, 28), 22)
		for i in heroes.size():
			Silhouette.draw(c, str(heroes[i]["id"]), Rect2(12 + (i % 6) * 116, 44 + (i / 6) * 116, 96, 96)))
	_save("heroes_40", arche[0])
	# icons: all at 48 px with names, and a row at 32 and 28
	var icon_page: Array = await _page(func(c: Control) -> void:
		_label(c, "Icons at 48 px: stroke TEXT2, accent TEAL_HI (%d ids)" % Icons.IDS.size(), Vector2(16, 28))
		for i in Icons.IDS.size():
			var x := 16.0 + float(i % 6) * 116.0
			var y := 44.0 + float(i / 6) * 96.0
			Icons.draw(c, Icons.IDS[i], Rect2(x + 34, y, 48, 48), ArtPalette.TEXT2, ArtPalette.TEAL_HI)
			c.draw_string(UI.font("Medium"), Vector2(x, y + 74), Icons.IDS[i], HORIZONTAL_ALIGNMENT_CENTER, 116, 18, ArtPalette.DIM)
		var yy := 44.0 + 8.0 * 96.0 + 10.0
		_label(c, "32 px and 28 px, and tint colours (GOOD, BAD, WARN, ACCENT)", Vector2(16, yy))
		for i in 12:
			Icons.draw(c, Icons.IDS[5 + i], Rect2(16 + i * 44, yy + 12, 32, 32), ArtPalette.TEXT2, ArtPalette.TEAL_HI)
			Icons.draw(c, Icons.IDS[5 + i], Rect2(16 + i * 44, yy + 52, 28, 28), ArtPalette.TEXT2, ArtPalette.TEAL_HI)
		var tint_cols := [Color("5bd68a"), Color("f58080"), ArtPalette.WARN, ArtPalette.ACCENT]
		for i in tint_cols.size():
			Icons.draw(c, "arrow_up", Rect2(16 + i * 60, yy + 96, 48, 48), tint_cols[i])
			Icons.draw(c, "arrow_down", Rect2(16 + i * 60, yy + 150, 48, 48), tint_cols[i]))
	_save("icons_normal", icon_page[0])
	_save("icons_grey", _view_image(icon_page[0], "grey"))
	_save("icons_deutan", _view_image(icon_page[0], "deutan"))
	# avatars and tokens
	var av_page: Array = await _page(func(c: Control) -> void:
		_label(c, "Player avatars (initial on the role ring), 96 / 64 / 48 px, and the two side tokens", Vector2(16, 28), 22)
		for i in 20:
			var p: Dictionary = players[i * 7]
			Avatar.draw(c, str(p["id"]), Rect2(16 + (i % 5) * 136, 44 + (i / 5) * 116, 96, 96), {"name": str(p["name"]), "role": str(p["role_primary"]), "font": font})
		for i in 8:
			var p: Dictionary = players[i * 11]
			Avatar.draw(c, str(p["id"]), Rect2(16 + i * 78, 520, 64, 64), {"name": str(p["name"]), "role": str(p["role_primary"]), "font": font})
			Avatar.draw(c, str(p["id"]), Rect2(16 + i * 78, 600, 48, 48), {"name": str(p["name"]), "role": str(p["role_primary"]), "font": font})
		_label(c, "you: teal circle (40, 36)  |  them: coral hexagon (44, 40)", Vector2(16, 690), 22)
		for i in 5:
			Avatar.draw_token(c, true, Vector2(40 + i * 60, 740), 40.0 if i < 3 else 36.0, "TJMBS".substr(i, 1), font)
			Avatar.draw_token(c, false, Vector2(400 + i * 60, 740), 40.0 if i < 3 else 36.0, "TJMBS".substr(i, 1), font)
		c.draw_rect(Rect2(0, 790, 720, 110), ArtPalette.VOID)
		for i in 5:
			Avatar.draw_token(c, true, Vector2(40 + i * 60, 845), 40.0, "TJMBS".substr(i, 1), font)
			Avatar.draw_token(c, false, Vector2(400 + i * 60, 845), 40.0, "TJMBS".substr(i, 1), font))
	_save("avatars_normal", av_page[0])
	_save("avatars_grey", _view_image(av_page[0], "grey"))
	_save("avatars_deutan", _view_image(av_page[0], "deutan"))
