extends SceneTree
## Alpha 0.7 font spike (Engine / Graphics Programmer). Measures real Barlow Semi Condensed widths
## in Godot's own text server, checks tnum, and checks the project default font reaches
## Label and Button. Not part of run_all_checks.sh. Needs no autoloads.
##   godot --headless --path game --script res://tests/font_spike.gd
## Optional picture of the tnum check (needs a display): add `-- render=/some/dir`.

const F := "res://assets/fonts/BarlowSemiCondensed-%s.ttf"
const LANES := ["Top", "Mid", "Bot"]
const PLACES := ["Stoneback", "Moonhulk", "The Cairn", "Wrenfell"]

var _fails := 0
var _w: Dictionary = {}


func _font(weight: String, tnum: bool = false) -> Font:
	var base: FontFile = load(F % weight)
	if not tnum:
		return base
	var fv := FontVariation.new()
	fv.base_font = base
	fv.opentype_features = {"tnum": 1}
	return fv


func _width(font: Font, text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _check(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _labels() -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../docs/design/ACTION-VOCABULARY.md"), FileAccess.READ)
	if f == null:
		print("  cannot open ACTION-VOCABULARY.md")
		return out
	var in_catalogue := false
	for line in f.get_as_text().split("\n"):
		if line.begins_with("### 4.3"):
			in_catalogue = true
			continue
		if in_catalogue and line.begins_with("## "):
			break
		if in_catalogue and line.begins_with("| `"):
			var cols := line.split("|")
			# cols: "", id, shown when, v1, v2, v3, ""
			if cols.size() >= 7:
				for i in [3, 4, 5]:
					out.append(String(cols[i]).strip_edges())
	return out


func _initialize() -> void:
	print("== Font spike, Godot %s ==" % Engine.get_version_info().string)
	var args := OS.get_cmdline_user_args()
	_intent_labels()
	_titles_and_cards()
	_tnum()
	_theme_default()
	var render := ""
	for a in args:
		if a.begins_with("render="):
			render = a.substr(7)
	if render != "":
		await _render(render)
	print("== font spike: %s ==" % ("ALL OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _intent_labels() -> void:
	print("-- 1. Intent labels (ACTION-VOCABULARY 4.3), 24 px")
	var labels := _labels()
	_check(labels.size() == 156, "label count %d (spec: 156)" % labels.size())
	for weight in ["Regular", "Medium", "SemiBold", "Bold"]:
		var font := _font(weight)
		var best := 0.0
		var best_text := ""
		var best_fill := ""
		var total := 0.0
		var n := 0
		for raw in labels:
			# Substitute every fill option and keep the widest realisation of the line.
			var variants: Array[String] = [raw]
			for key in ["{lane}", "{place}", "{hero}"]:
				var next: Array[String] = []
				for v in variants:
					if not v.contains(key):
						next.append(v)
						continue
					var opts: Array = LANES if key == "{lane}" else (PLACES if key == "{place}" else ["Gravenstone", "Tanglewick", "Tessarine"])
					for o in opts:
						next.append(v.replace(key, o))
				variants = next
			var line_best := 0.0
			var line_text := ""
			for v in variants:
				var wv := _width(font, v, 24)
				if wv > line_best:
					line_best = wv
					line_text = v
			total += line_best
			n += 1
			if line_best > best:
				best = line_best
				best_text = line_text
		print("  %-9s 24 px: longest %.1f px (\"%s\"), mean %.1f px over %d lines" % [weight, best, best_text, total / n, n])
		_w["intent_" + weight] = best
	var sb: float = _w["intent_SemiBold"]
	print("  spec claims 239 px at SemiBold; measured %.1f px (difference %+.1f)" % [sb, sb - 239.0])
	_check(absf(sb - 239.0) <= 5.0, "SemiBold longest within 5 px of the spec's 239")


func _titles_and_cards() -> void:
	print("-- 2. Draft titles at Bold 40 and hero names")
	var bold := _font("Bold")
	var claims := {"Your ban": 141.0, "Your pick": 150.0, "Their ban": 152.0, "Their pick": 161.0}
	for t in claims:
		var wv := _width(bold, t, 40)
		print("  \"%s\" Bold 40: %.1f px (spec %.0f, difference %+.1f)" % [t, wv, claims[t], wv - claims[t]])
		_check(absf(wv - claims[t]) <= 3.0, "%s within 3 px" % t)
	print("  large-text room 106 px: \"Their\" %.1f, \"pick\" %.1f, \"Your\" %.1f (each must be <= 106)" % [_width(bold, "Their", 40), _width(bold, "pick", 40), _width(bold, "Your", 40)])
	_check(_width(bold, "Their", 40) <= 106.0 and _width(bold, "pick", 40) <= 106.0, "large-text two-line split fits 106 px")
	print("  header room beside back button/ring/help at normal size: 200 px")
	for t in claims:
		_check(_width(bold, t, 40) <= 200.0, "%s fits 200 px" % t)
	for pair in [["Medium", 26], ["SemiBold", 26], ["SemiBold", 36], ["Bold", 36]]:
		var wv := _width(_font(pair[0]), "Gravenstone", pair[1])
		print("  \"Gravenstone\" %s %d: %.1f px (large-text card 183 wide, about 160 px text room; 40 px padding assumed by the spec)" % [pair[0], pair[1], wv])
		_w["grav_%s_%d" % [pair[0], pair[1]]] = wv
	_check(_w["grav_SemiBold_26"] <= 160.0, "Gravenstone SemiBold 26 fits the 160 px text room")
	print("  Gravenstone at Heading 36 SemiBold %.1f px against the whole 183 px card: %s" % [_w["grav_SemiBold_36"], "fits only with <= %.0f px total side padding" % (183.0 - _w["grav_SemiBold_36"])])
	# All 40 hero names at 26 SemiBold.
	var f := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	var heroes: Array = JSON.parse_string(f.get_as_text())
	var widest := 0.0
	var widest_n := ""
	for h in heroes:
		var wv := _width(_font("SemiBold"), String(h["name"]), 26)
		if wv > widest:
			widest = wv
			widest_n = h["name"]
	print("  all %d hero names, SemiBold 26: widest \"%s\" %.1f px" % [heroes.size(), widest_n, widest])
	var long_club := _width(_font("Regular"), "Northreach Corsairs", 32)
	print("  \"Northreach Corsairs\" Regular 32: %.1f px (art bible 250); Bold 48: %.1f (art bible 391)" % [long_club, _width(_font("Bold"), "Northreach Corsairs", 48)])
	print("  \"Season complete\" ExtraBold 64: %.1f (art bible 450)" % _width(_font("ExtraBold"), "Season complete", 64))


func _tnum() -> void:
	print("-- 3. Tabular numerals (FontVariation.opentype_features = tnum)")
	for weight in ["Regular", "SemiBold", "Bold"]:
		var plain := _font(weight)
		var tab := _font(weight, true)
		var p1 := _width(plain, "1111111", 32)
		var p0 := _width(plain, "0000000", 32)
		var t1 := _width(tab, "1111111", 32)
		var t0 := _width(tab, "0000000", 32)
		var t8 := _width(tab, "8888888", 32)
		print("  %-8s 32 px, 7 digits: proportional 1s %.1f / 0s %.1f ; tnum 1s %.1f / 0s %.1f / 8s %.1f" % [weight, p1, p0, t1, t0, t8])
		_check(absf(p1 - p0) > 10.0, "%s default digits are proportional (1 narrower than 0)" % weight)
		_check(absf(t1 - t0) < 0.5 and absf(t0 - t8) < 0.5, "%s with tnum: all digits equal width" % weight)
	var tab_r := _font("Regular", true)
	_check(absf(_width(tab_r, "1,111", 32) - _width(tab_r, "9,999", 32)) < 0.5, "tnum: money strings 1,111 and 9,999 the same width")
	_check(absf(_width(tab_r, "-12", 32) - _width(tab_r, "-88", 32)) < 0.5, "tnum: -12 and -88 the same width")
	print("  tnum off for a plain FontVariation without features equals base: %.1f vs %.1f" % [_width(_font("Regular"), "1234", 32), _width(_font("Regular", false), "1234", 32)])


func _theme_default() -> void:
	print("-- 4. Project default font and fallbacks")
	var custom := String(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	print("  gui/theme/custom_font = %s" % custom)
	_check(custom != "", "project setting is present")
	var root_ctrl := Control.new()
	# Same shape as UI.make_theme(): a Theme with sizes and colours but NO default_font.
	var th := Theme.new()
	th.default_font_size = 32
	th.set_font_size("font_size", "Button", 32)
	root_ctrl.theme = th
	var label := Label.new()
	label.text = "Your pick"
	var button := Button.new()
	button.text = "Your pick"
	root_ctrl.add_child(label)
	root_ctrl.add_child(button)
	get_root().add_child(root_ctrl)
	for ctl in [label, button]:
		var fnt: Font = ctl.get_theme_font("font")
		var res := ""
		if fnt is FontVariation:
			res = "FontVariation over " + String((fnt as FontVariation).base_font.resource_path.get_file())
		else:
			res = fnt.resource_path
		print("  %s font: %s" % [ctl.get_class(), res])
		_check(res.contains("BarlowSemiCondensed-Regular"), "%s resolves to Barlow Regular through a theme with no default_font" % ctl.get_class())
	var fb: Array = (label.get_theme_font("font") as FontVariation).fallbacks
	_check(fb.size() == 1 and fb[0] is SystemFont, "default font has the SystemFont fallback")
	var base: FontFile = load(F % "Regular")
	_check(base.has_char("e".unicode_at(0)) and base.has_char(0x2212) and not base.has_char(0x2713), "Regular has Latin and minus (U+2212) and lacks the tick (U+2713), as the art bible says")
	root_ctrl.queue_free()


func _render(dir: String) -> void:
	print("-- 5. Render the tnum picture to %s" % dir)
	var panel := ColorRect.new()
	panel.color = Color("0d141c")
	panel.size = Vector2(720, 520)
	get_root().add_child(panel)
	var y := 10
	for pair in [["Regular (proportional)", false], ["Regular tnum", true]]:
		for s in ["1,111  0,000  8,888", "12  88  -77  1:11  100"]:
			var l := Label.new()
			l.text = "%s  %s" % [s, pair[0]]
			l.add_theme_font_override("font", _font("Regular", pair[1]))
			l.add_theme_font_size_override("font_size", 32)
			l.position = Vector2(10, y)
			panel.add_child(l)
			y += 48
	for pair in [["Bold", 40, "Their pick"], ["SemiBold", 24, "Fight now, objective later"], ["ExtraBold", 64, "Victory"]]:
		var l := Label.new()
		l.text = pair[2]
		l.add_theme_font_override("font", _font(pair[0]))
		l.add_theme_font_size_override("font_size", pair[1])
		l.position = Vector2(10, y)
		panel.add_child(l)
		y += pair[1] + 14
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png(dir.path_join("font_spike_tnum.png"))
