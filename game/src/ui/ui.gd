class_name UI
extends RefCounted
## Small widget toolkit for the portrait phone layout (720 x 1280 design size). Flat colours only:
## art comes in the last pre-launch phase. All visible text must come from Strings.

## Arena Dusk (UI direction approved 2026-11-08): deep navy, teal, one warm coral accent for "go".
const BG := Color("0a1120")
const PANEL := Color("132036")
const PANEL2 := Color("1d3150")
const PANEL3 := Color("27406a")
const LINE := Color(1, 1, 1, 0.07)       # hairline around cards
const ACCENT := Color("3fd0b8")
const CORAL := Color("ff8a5c")           # the one primary action on a screen (Play)
const GOOD := Color("5bd68a")
const BAD := Color("ef6b6b")
const WARN := Color("f2c14e")
const TEXT := Color("e8eef5")
const DIM := Color("9db0c6")
const BLUE := Color("5aa9ff")
const RED := Color("ff7a7a")

## Motion tokens (seconds). Animations can be switched off in Settings (UI.animate).
const T_PRESS := 0.12
const T_COUNT := 0.6
const T_FADE := 0.25

## Spacing and shape tokens.
const R_CARD := 20
const R_BTN := 18
const GAP := 14

static var animate := true

const S_BODY := 28
const S_SMALL := 22
const S_BIG := 38
const S_TITLE := 46
const BTN_H := 92


static func box(color: Color, radius: int = 14, pad: int = 0, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = S_BODY
	t.set_color("font_color", "Label", TEXT)
	for cls in ["Button", "CheckButton"]:
		t.set_font_size("font_size", cls, S_BODY)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, TEXT)
		t.set_color("font_pressed_color", cls, TEXT)
		t.set_color("font_disabled_color", cls, DIM)
		t.set_color("font_focus_color", cls, TEXT)
	t.set_stylebox("normal", "Button", box(PANEL2, R_BTN, 18, LINE, 1))
	t.set_stylebox("hover", "Button", box(PANEL2.lightened(0.08), R_BTN, 18, LINE, 1))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.35), R_BTN, 18))
	t.set_stylebox("disabled", "Button", box(PANEL, R_BTN, 18))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), R_BTN, 18, ACCENT, 3))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, R_CARD, 20, LINE, 1))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 8))
	t.set_stylebox("background", "ProgressBar", box(Color("0a1119"), 8))
	t.set_font_size("font_size", "ProgressBar", S_SMALL)
	t.set_constant("separation", "VBoxContainer", 14)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "GridContainer", 12)
	t.set_constant("v_separation", "GridContainer", 12)
	return t


static func label(text: String, size: int = S_BODY, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, cb: Callable, kind: String = "normal", min_h: int = BTN_H) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS    # lets a swipe that starts on a button scroll the page
	match kind:
		"primary":
			b.add_theme_stylebox_override("normal", box(ACCENT.darkened(0.15), R_BTN, 18))
			b.add_theme_stylebox_override("hover", box(ACCENT, R_BTN, 18))
			b.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.4), R_BTN, 18))
			b.add_theme_color_override("font_color", Color("04120f"))
			b.add_theme_color_override("font_hover_color", Color("04120f"))
			b.add_theme_color_override("font_pressed_color", Color("ffffff"))
		"play":
			# the single "go" action of a screen: coral, so nothing else competes with it
			b.add_theme_stylebox_override("normal", box(CORAL, R_BTN, 18))
			b.add_theme_stylebox_override("hover", box(CORAL.lightened(0.08), R_BTN, 18))
			b.add_theme_stylebox_override("pressed", box(CORAL.darkened(0.3), R_BTN, 18))
			b.add_theme_color_override("font_color", Color("1c0b04"))
			b.add_theme_color_override("font_hover_color", Color("1c0b04"))
			b.add_theme_color_override("font_pressed_color", Color("ffffff"))
		"danger":
			b.add_theme_stylebox_override("normal", box(BAD.darkened(0.45), R_BTN, 18))
		"flat":
			b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), 12, 12))
	b.button_down.connect(_pulse.bind(b))
	b.pressed.connect(cb)
	return b


## Quick "press" pulse: shrinks a touch and springs back on its own, so a swipe that steals the
## press can never leave a button stuck small. Off when UI.animate is false.
static func _pulse(c: Control) -> void:
	if not animate or not c.is_inside_tree():
		return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.97, 0.97), T_PRESS * 0.4)
	tw.tween_property(c, "scale", Vector2.ONE, T_PRESS)


static func hbox(children: Array = []) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in children:
		h.add_child(c)
	return h


static func vbox(children: Array = []) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in children:
		v.add_child(c)
	return v


## A rounded card. Returns the inner VBoxContainer; the card itself is `.get_parent()`.
static func card(parent: Control, color: Color = PANEL, pad: int = 20, border: Color = LINE, border_w: int = 1) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(color, R_CARD, pad, border, border_w))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.mouse_filter = Control.MOUSE_FILTER_PASS   # PanelContainer defaults to STOP, which blocks swipe-scrolling
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_child(v)
	parent.add_child(pc)
	return v


static func bar(value: float, max_value: float, color: Color = ACCENT, height: int = 22) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("fill", box(color, 8))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func spacer(h: int = 12) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func pct(x: float, digits: int = 1) -> String:
	return ("%+." + str(digits) + "f%%") % (x * 100.0)


## Fatigue as words, for roster rows: "" when fresh, else "  -  tired -3" (the number is the rating lost).
static func fatigue_tag(fat: float) -> String:
	if fat < 25.0:
		return ""
	var level := "worn" if fat < 50.0 else ("tired" if fat < 75.0 else "exhausted")
	var pen := Progression.fatigue_penalty(fat)
	var txt := Strings.t("fatigue." + level)
	return "  -  " + (txt + " -%.0f" % pen if pen >= 0.5 else txt)


## Form and morale as words for roster rows: "" when nothing stands out.
static func mood_tag(frm: float, mor: float) -> String:
	var parts := PackedStringArray()
	if frm >= 3.0:
		parts.append(Strings.t("mood.hot"))
	elif frm <= -3.0:
		parts.append(Strings.t("mood.cold"))
	if mor >= 75.0:
		parts.append(Strings.t("mood.happy"))
	elif mor < 40.0:
		parts.append(Strings.t("mood.unhappy"))
	return "" if parts.is_empty() else "  -  " + ", ".join(parts)


static func fatigue_color(fat: float) -> Color:
	return GOOD if fat < 25.0 else (WARN if fat < 50.0 else BAD)


# ---------------------------------------------------------------- shared components (Alpha 0.5)

## A small rounded tag: "Blue side", "2 tired", "+2.1% chem". Colour tints the background.
static func chip(text: String, color: Color = DIM) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.16)
	sb.border_color = Color(color.r, color.g, color.b, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var l := label(text, S_SMALL - 2, color)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	pc.add_child(l)
	return pc


## Chips that wrap onto a second line on a narrow phone.
static func chips(parent: Control, items: Array) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_theme_constant_override("h_separation", 10)
	f.add_theme_constant_override("v_separation", 10)
	f.mouse_filter = Control.MOUSE_FILTER_PASS
	for it in items:
		f.add_child(chip(String(it[0]), it[1]))
	parent.add_child(f)
	return f


## Two-colour bar for "you vs them": the split follows the two numbers.
static func versus_bar(mine: float, theirs: float, height: int = 18) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tot := maxf(0.001, mine + theirs)
	for pair in [[mine, ACCENT], [theirs, CORAL]]:
		var r := PanelContainer.new()
		r.add_theme_stylebox_override("panel", box(pair[1], 9))
		r.custom_minimum_size = Vector2(0, height)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.size_flags_stretch_ratio = maxf(0.05, float(pair[0]) / tot)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(r)
	return h


## A tappable summary tile: small title, big value, one line of context. The whole tile is the button.
static func tile(title: String, value: String, sub: String, color: Color, cb: Callable) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(PANEL, R_CARD, 18, LINE, 1))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	pc.custom_minimum_size = Vector2(0, 150)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	for spec in [[title, S_SMALL - 2, DIM], [value, S_BIG, color], [sub, S_SMALL - 2, DIM]]:
		var l := label(String(spec[0]), int(spec[1]), spec[2])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	pc.add_child(v)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.button_down.connect(_pulse.bind(pc))
	b.pressed.connect(cb)
	pc.add_child(b)
	return pc


## Colour and sign for a change: good_up false means a rise is bad (fatigue, cost).
static func delta_color(x: float, good_up: bool = true) -> Color:
	if absf(x) < 0.005:
		return DIM
	return GOOD if (x > 0.0) == good_up else BAD


## "+1.5" / "-0.5" / "0.0" with a fixed number of decimals.
static func signed(x: float, digits: int = 1) -> String:
	if absf(x) < pow(10.0, -digits) * 0.5:
		return ("%." + str(digits) + "f") % 0.0
	return ("%+." + str(digits) + "f") % x


## Label whose number counts up from `from` to `to`. The final text is set first, so with animations
## off (or in tests) it simply shows the answer. Call after the label is in the tree.
static func count_up(l: Label, to: float, fmt: String = "%.0f", from: float = 0.0, dur: float = T_COUNT) -> void:
	l.text = fmt % to
	if not animate or not l.is_inside_tree() or absf(to - from) < 0.0001:
		return
	var tw := l.create_tween()
	tw.tween_method(func(v: float): l.text = fmt % v, from, to, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Bar that fills from `from` to its value.
static func fill_in(b: ProgressBar, from: float = 0.0, dur: float = T_COUNT) -> void:
	var to := b.value
	if not animate or not b.is_inside_tree() or absf(to - from) < 0.0001:
		return
	b.value = from
	var tw := b.create_tween()
	tw.tween_property(b, "value", to, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## A section that opens and closes. Returns the content column.
static func section(parent: Control, title: String, open: bool = false) -> VBoxContainer:
	var outer := card(parent)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.visible = open
	var head := button(("- " if open else "+ ") + title, func(): pass, "flat", 70)
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_theme_color_override("font_color", ACCENT)
	head.pressed.connect(func():
		content.visible = not content.visible
		head.text = ("- " if content.visible else "+ ") + title)
	outer.add_child(head)
	outer.add_child(content)
	return content


## A row: left label, right value (value coloured).
static func kv_row(parent: Control, key: String, value: String, color: Color = TEXT, size: int = S_SMALL) -> HBoxContainer:
	var h := hbox()
	var k := label(key, size, DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	var v := label(value, size, color, HORIZONTAL_ALIGNMENT_RIGHT)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF    # a value never wraps letter by letter
	v.custom_minimum_size = Vector2(150, 0)
	v.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(v)
	parent.add_child(h)
	return h
