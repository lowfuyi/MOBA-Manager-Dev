extends Node
## I-02 checks: design tokens against the ART-BIBLE tables (a drifting constant fails), the font weights and tabular
## digits, the cached fonts and style boxes, the 96 px button clamp, the large-text hook, and the OFL licence step.
## Needs the autoloads (UI uses Strings), so it is a scene, not a *_tests.gd file. Ends with " N checks, M failures".

const BIBLE := "../docs/design/ART-BIBLE.md"

var checks := 0
var fails := 0
var _ui: GDScript


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _bible_lines() -> PackedStringArray:
	var f := FileAccess.open(ProjectSettings.globalize_path("res://").path_join(BIBLE), FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")


func _hexes(cell: String) -> Array:
	var rx := RegEx.new()
	rx.compile("#([0-9A-Fa-f]{6})")
	var out: Array = []
	for m in rx.search_all(cell):
		out.append(m.get_string(1).to_lower())
	return out


func _ready() -> void:
	await get_tree().process_frame
	_ui = load("res://src/ui/ui.gd")
	var consts: Dictionary = _ui.get_script_constant_map()
	var lines := _bible_lines()
	ok(lines.size() > 100, "ART-BIBLE.md is readable from the project (%d lines)" % lines.size())
	_type_scale(consts, lines)
	_colours(consts, lines)
	_spacing(consts)
	await _fonts()
	_caches()
	await _large_text()
	_licence()
	print("check_ui_tokens: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- 5.2 type scale

func _type_scale(consts: Dictionary, lines: PackedStringArray) -> void:
	var by_style := {"display": "S_DISPLAY", "title": "S_TITLE", "value": "S_BIG", "heading": "S_HEAD", "body": "S_BODY", "small": "S_SMALL", "caption": "S_CAPTION"}
	var rx := RegEx.new()
	rx.compile("`(S_[A-Z]+)`")
	var in_52 := false
	var rows := 0
	var scale: Dictionary = consts["TYPE_SCALE"]
	for line in lines:
		if line.begins_with("### 5.2"):
			in_52 = true
			continue
		if in_52 and line.begins_with("## "):
			break
		if not in_52 or not line.begins_with("| "):
			continue
		var cols := line.split("|")
		if cols.size() < 10:
			continue
		var first := String(cols[1]).strip_edges().split(" ")[0].to_lower()
		if not by_style.has(first):
			continue
		rows += 1
		var m := rx.search(String(cols[2]))
		var cname: String = m.get_string(1) if m != null else "?"
		var want_px := int(String(cols[3]).strip_edges())
		ok(cname == by_style[first], "5.2 %s: bible names the constant %s (code expects %s)" % [first, cname, by_style[first]])
		ok(consts.has(cname) and int(consts[cname]) == want_px, "5.2 %s: %s is %d px in the bible, %s in ui.gd" % [first, cname, want_px, str(consts.get(cname, "missing"))])
		var want_w := String(cols[6]).strip_edges().split(" ")[0]
		ok(String(scale[first]["weight"]) == want_w, "5.2 %s: weight %s in the bible, %s in TYPE_SCALE" % [first, want_w, scale[first]["weight"]])
		var want_lh := float(String(cols[7]).strip_edges())
		ok(absf(float(scale[first]["line"]) - want_lh) < 0.001, "5.2 %s: line height %.2f in the bible, %.2f in TYPE_SCALE" % [first, want_lh, float(scale[first]["line"])])
		ok(int(scale[first]["size"]) == want_px, "5.2 %s: TYPE_SCALE size %d equals the bible's %d" % [first, int(scale[first]["size"]), want_px])
	ok(rows == 7, "5.2: all seven style rows were found in the bible table (%d)" % rows)
	ok(UI.S_CAPTION == 24 and UI.S_CAPTION <= UI.S_SMALL, "the floor is 24 px (Caption)")
	# the pairs: 12 weight-and-size pairs (PERF-BUDGET 3.1a), hard limit 16 with the tnum variants of the number styles
	var seen := {}
	var weights_ok := true
	var sizes_ok := true
	for p in consts["TYPE_PAIRS"]:
		seen["%d/%s" % [int(p[0]), p[1]]] = true
		weights_ok = weights_ok and (p[1] in consts["WEIGHTS"])
		sizes_ok = sizes_ok and int(p[0]) >= 24
	ok(seen.size() == 12 and consts["TYPE_PAIRS"].size() == 12, "type scale uses exactly 12 distinct weight-and-size pairs (%d)" % seen.size())
	ok(weights_ok and sizes_ok, "every pair uses one of the five weights and a size of at least 24")
	var prim_ok := true
	for k in scale:
		prim_ok = prim_ok and seen.has("%d/%s" % [int(scale[k]["size"]), scale[k]["weight"]])
	ok(prim_ok, "every style's primary weight-and-size is one of the 12 pairs")
	var nw: Dictionary = consts["NUM_WEIGHT"]
	var nw_ok := true
	for sz in nw:
		nw_ok = nw_ok and seen.has("%d/%s" % [int(sz), nw[sz]])
	ok(nw_ok, "every number style is one of the 12 pairs (its tnum variant is the extra one)")
	ok(seen.size() + nw.size() <= 16, "12 pairs + %d tnum number styles = %d, at most the hard limit 16" % [nw.size(), seen.size() + nw.size()])
	# the weight a label gets from its size
	ok(UI.default_weight(48) == "Bold" and UI.default_weight(40) == "Bold" and UI.default_weight(36) == "SemiBold" and UI.default_weight(32) == "Regular" and UI.default_weight(26) == "Medium" and UI.default_weight(24) == "SemiBold" and UI.default_weight(64) == "ExtraBold", "default_weight follows the 5.2 table")
	ok(UI.default_weight(30) == "Regular", "a size off the scale stays Regular")


# ---------------------------------------------------------------- section 3 colours

func _colours(consts: Dictionary, lines: PackedStringArray) -> void:
	# bible row name -> constant in ui.gd
	var names := {"VOID": "VOID", "BG": "BG", "BG_GLOW": "BG_GLOW", "PANEL": "PANEL", "PANEL2": "PANEL2", "PANEL3": "PANEL3",
		"TEXT": "TEXT", "TEXT2": "TEXT2", "DIM": "DIM", "TEXT_OFF": "TEXT_OFF", "INK_TEAL": "INK_TEAL", "INK_CORAL": "INK_CORAL",
		"ACCENT": "ACCENT", "TEAL_HI": "TEAL_HI", "TEAL_LO": "TEAL_LO", "TEAL_DEEP": "TEAL_DEEP", "CORAL": "CORAL",
		"CORAL_HI": "CORAL_HI", "CORAL_LO": "CORAL_LO", "WARN": "WARN", "GOOD": "GOOD_DEFAULT", "BAD": "BAD_DEFAULT",
		"GOOD_CB": "GOOD_CB", "BAD_CB": "BAD_CB", "SIDE_BLUE": "SIDE_BLUE", "SIDE_RED": "SIDE_RED",
		"MAP_LAND": "MAP_LAND", "MAP_MERE": "MAP_MERE", "MAP_SHORE": "MAP_SHORE"}
	var roles := {"Top": "ROLE_TOP", "Jungle": "ROLE_JUNGLE", "Mid": "ROLE_MID", "Bot Carry": "ROLE_BOT", "Support": "ROLE_SUPPORT"}
	var rx := RegEx.new()
	rx.compile("^`([A-Z_0-9]+)`")
	var found := {}
	var in_3 := false
	var in_35 := false
	var top_ok := true
	for line in lines:
		if line.begins_with("## 3. Tokens"):
			in_3 = true
			continue
		if in_3 and line.begins_with("## 4."):
			break
		if not in_3:
			continue
		if line.begins_with("### 3.5"):
			in_35 = true
		elif line.begins_with("### 3.6"):
			in_35 = false
		if not line.begins_with("| "):
			continue
		var cols := line.split("|")
		if cols.size() < 4:
			continue
		var first := String(cols[1]).strip_edges()
		if in_35 and roles.has(first):
			var hx := _hexes(String(cols[2]))
			ok(not hx.is_empty() and consts.has(roles[first]) and (consts[roles[first]] as Color).to_html(false) == hx[0], "3.5 role %s: bible %s, ui.gd %s" % [first, hx, (consts.get(roles[first], Color.BLACK) as Color).to_html(false)])
			found[roles[first]] = true
			continue
		var m := rx.search(first)
		if m == null:
			continue
		var tok := m.get_string(1)
		if not names.has(tok) or found.has(tok):
			continue
		var hx := _hexes(String(cols[2]))
		if hx.is_empty():
			continue
		found[tok] = true
		var cname: String = names[tok]
		var got: Color = consts[cname]
		ok(got.to_html(false) == hx[0], "3 %s: bible #%s, ui.gd %s #%s" % [tok, hx[0], cname, got.to_html(false)])
		# surfaces also carry the top of their gradient: "`#162842` (top `#1D3354`)"
		if tok in ["PANEL", "PANEL2", "PANEL3"]:
			var tcol: Color = consts[cname + "_TOP"] if consts.has(cname + "_TOP") else Color.BLACK
			top_ok = top_ok and hx.size() >= 2 and tcol.to_html(false) == hx[1]
	ok(found.size() == names.size() + roles.size(), "3: every colour token and role colour was found in the bible tables (%d of %d)" % [found.size(), names.size() + roles.size()])
	ok(top_ok, "3.1: PANEL, PANEL2 and PANEL3 gradient tops match the bible")
	var lh := consts["LINE"] as Color
	ok(absf(lh.a - 0.06) < 0.001 and lh.r == 1.0, "3.1: LINE is white at 6 percent")
	ok(UI.SIDE_RED == UI.BAD_DEFAULT, "3.3: SIDE_RED has the value of BAD_DEFAULT")
	ok(UI.BLUE == UI.SIDE_BLUE and UI.RED == UI.SIDE_RED, "old names BLUE and RED are aliases of SIDE_BLUE and SIDE_RED")
	UI.set_colorblind(true)
	ok(UI.GOOD == UI.GOOD_CB and UI.BAD == UI.BAD_CB and UI.SIDE_RED == UI.BAD_DEFAULT, "colour-blind mode swaps GOOD and BAD, not SIDE_RED")
	UI.set_colorblind(false)
	ok(UI.GOOD == UI.GOOD_DEFAULT and UI.BAD == UI.BAD_DEFAULT, "colour-blind mode off restores GOOD and BAD")


func _spacing(consts: Dictionary) -> void:
	ok(UI.BTN_H == 96, "BTN_H is 96 (ART-BIBLE 5.2: minimum button height 96 px)")
	ok(UI.R_CARD == 24, "R_CARD is 24 (4.1)")
	ok(UI.GAP == 16, "GAP is 16 (4.1)")
	ok(UI.PAD_CARD == 24, "card padding is 24 (4.1)")
	ok(UI.TAB_H == 112 and UI.HEADER_H == 96, "TAB_H 112 and HEADER_H 96 (build plan I-02)")
	ok(is_equal_approx(UI.LARGE_SCALE, 1.15) and is_equal_approx(App.LARGE_SCALE, UI.LARGE_SCALE), "large text scale is 1.15 in UI and App")


# ---------------------------------------------------------------- fonts

func _fonts() -> void:
	for w in UI.WEIGHTS:
		var ttf: String = UI.FONT_PATH % w
		ok(ResourceLoader.exists(ttf), "%s resolves as a resource" % ttf)
		var imp := FileAccess.open(ttf + ".import", FileAccess.READ)
		var path := ""
		if imp != null:
			for ln in imp.get_as_text().split("\n"):
				if ln.begins_with("path="):
					path = ln.trim_prefix("path=").strip_edges().trim_prefix("\"").trim_suffix("\"")
		ok(path != "" and FileAccess.file_exists(path), "%s: imported .fontdata exists (%s)" % [w, path.get_file()])
		var f := load(ttf) as FontFile
		ok(f != null and f.get_font_name().begins_with("Barlow Semi Condensed") and f.get_font_style_name() == w, "%s loads as the Barlow Semi Condensed FontFile (%s / %s)" % [w, f.get_font_name() if f != null else "-", f.get_font_style_name() if f != null else "-"])
	# tabular digits: '1111' and '8888' the same width with tnum, different without (so the test can fail)
	for w in UI.WEIGHTS:
		var tn := UI.font(w, true)
		var pl := UI.font(w, false)
		var a: float = tn.get_string_size("1111", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		var b: float = tn.get_string_size("8888", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		var pa: float = pl.get_string_size("1111", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		var pb: float = pl.get_string_size("8888", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		ok(is_equal_approx(a, b) and a > 0.0, "%s tnum: '1111' is %.0f px, '8888' is %.0f px at 32 px" % [w, a, b])
		ok(not is_equal_approx(pa, pb), "%s without tnum: '1111' %.0f px differs from '8888' %.0f px (the feature is what makes them equal)" % [w, pa, pb])
	var sb_tn := UI.font("SemiBold", true)
	var m1: float = sb_tn.get_string_size("1,111", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var m9: float = sb_tn.get_string_size("9,999", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	ok(is_equal_approx(m1, m9), "SemiBold tnum 40: '1,111' and '9,999' are the same width (%.0f)" % m1)
	# the weights really differ
	var wr: float = UI.font("Regular").get_string_size("Northreach Corsairs", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var wx: float = UI.font("ExtraBold").get_string_size("Northreach Corsairs", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	ok(wx > wr, "ExtraBold is wider than Regular for the same text (%.0f against %.0f)" % [wx, wr])
	ok(absf(wr - 250.0) <= 2.0, "Regular 32 'Northreach Corsairs' is about 250 px (ART-BIBLE 5.1), got %.1f" % wr)
	# cache: one FontVariation per (weight, tnum)
	ok(UI.font("Bold") == UI.font("Bold") and UI.font("Bold", true) == UI.font("Bold", true) and UI.font("Bold") != UI.font("Bold", true), "UI.font returns the cached FontVariation for each (weight, tnum)")
	ok(UI.font_cache_size() <= 10, "at most 10 cached fonts (five weights, with and without tnum): %d" % UI.font_cache_size())
	ok(UI.font("Regular") is FontVariation and (UI.font("SemiBold", true) as FontVariation).opentype_features.has("tnum"), "fonts are FontVariations; the tnum ones set the tnum feature")
	ok((UI.font("Bold") as FontVariation).fallbacks.size() == 1, "each weight keeps the system-font fallback of the default font")
	# the theme gives buttons SemiBold; labels follow the type scale
	var th := UI.make_theme()
	ok(th.get_font("font", "Button") == UI.font("SemiBold"), "theme: buttons are SemiBold")
	ok(th.default_font_size == 32, "theme: default text is Body 32")
	var t := UI.label("Title", UI.S_BIG)
	ok(t.get_theme_font("font") == UI.font("Bold"), "label at 40 px is Bold")
	var bd := UI.label("Body", UI.S_BODY)
	ok(not bd.has_theme_font_override("font"), "label at 32 px is Regular (the default font, no override)")
	var cap := UI.label("Cap", UI.S_CAPTION)
	ok(cap.get_theme_font("font") == UI.font("SemiBold"), "label at 24 px is SemiBold")
	var nl := UI.num_label("12,345", UI.S_BIG, UI.TEXT)
	ok(nl.get_theme_font("font") == UI.font("SemiBold", true) and nl.autowrap_mode == TextServer.AUTOWRAP_OFF, "num_label at 40 px: SemiBold with tabular digits, no wrapping")
	var nl2 := UI.num_label("1111", UI.S_BODY, UI.TEXT)
	var nl3 := UI.num_label("8888", UI.S_BODY, UI.TEXT)
	add_child(nl2)
	add_child(nl3)
	await get_tree().process_frame
	ok(is_equal_approx(nl2.get_minimum_size().x, nl3.get_minimum_size().x), "two num_labels '1111' and '8888' are the same width in a real Label (%.0f)" % nl2.get_minimum_size().x)
	nl2.queue_free()
	nl3.queue_free()
	t.free()
	bd.free()
	cap.free()
	nl.free()


# ---------------------------------------------------------------- caches and the button clamp

func _caches() -> void:
	var n0 := UI.box_cache_size()
	var a := UI.box(Color("123456"), 22, 7, Color("abcdef"), 2)
	var b := UI.box(Color("123456"), 22, 7, Color("abcdef"), 2)
	ok(a == b and UI.box_cache_size() == n0 + 1, "UI.box: the same arguments give the same StyleBoxFlat (cache grew by 1)")
	var c := UI.box(Color("123456"), 23, 7, Color("abcdef"), 2)
	var d := UI.box(Color("123456"), 22, 7, Color("abcdef"), 2, 12, 4)
	ok(c != a and d != a and UI.box_cache_size() == n0 + 3, "UI.box: another radius or a shadow is a different cache entry")
	ok(a.bg_color == Color("123456") and a.corner_radius_top_left == 22 and a.content_margin_left == 7.0 and a.border_width_left == 2, "UI.box sets colour, radius, padding and border")
	ok(d.shadow_size == 12 and d.shadow_offset == Vector2(0, 4), "UI.box sets shadow size and offset")
	var p := PanelContainer.new()
	var p2 := PanelContainer.new()
	var inner := UI.card(p)
	var inner2 := UI.card(p2)
	ok(inner.get_parent().get_theme_stylebox("panel") == inner2.get_parent().get_theme_stylebox("panel"), "two default cards share one StyleBox")
	p.free()
	p2.free()
	# buttons: min height is raised to 96
	var heights := {}
	for h in [44, 64, 66, 70, 72, 76, 80, 84, 92, 96]:
		var bt := UI.button("x", func(): pass, "normal", h)
		heights[h] = bt.custom_minimum_size.y
		bt.free()
	var all96 := true
	for h in heights:
		all96 = all96 and heights[h] == 96.0
	ok(all96, "UI.button clamps min height to 96 for 44, 64, 66, 70, 72, 76, 80, 84, 92, 96 (%s)" % [heights.values()])
	var tall := UI.button("x", func(): pass, "normal", 190)
	ok(tall.custom_minimum_size.y == 190.0, "UI.button keeps a taller request (190)")
	tall.free()
	var dflt := UI.button("x", func(): pass)
	ok(dflt.custom_minimum_size.y == 96.0, "UI.button default is 96")
	dflt.free()


# ---------------------------------------------------------------- large-text hook

func _large_text() -> void:
	get_window().size = Vector2i(720, 1280)    # a headless window is 100 x 100 until told otherwise
	await get_tree().process_frame
	App.apply_large_text(true)
	ok(UI.large and absf(UI.canvas_w() - 626.09) < 0.1, "large text on: UI.large and canvas width %.1f" % UI.canvas_w())
	await get_tree().process_frame
	ok(absf(get_viewport().get_visible_rect().size.x - UI.canvas_w()) < 1.0, "large text on: the viewport really is %.1f px wide (%.1f)" % [UI.canvas_w(), get_viewport().get_visible_rect().size.x])
	App.apply_large_text(false)
	ok(not UI.large and UI.canvas_w() == 720.0, "large text off: canvas width 720")
	await get_tree().process_frame


# ---------------------------------------------------------------- OFL licence step (already done in commit d78038d)

func _licence() -> void:
	ok(FileAccess.file_exists("res://assets/fonts/OFL.txt"), "assets/fonts/OFL.txt exists")
	var f := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	var txt := f.get_as_text() if f != null else ""
	ok(txt.contains("assets/fonts/OFL.txt"), "export_presets.cfg include_filter still names assets/fonts/OFL.txt")
