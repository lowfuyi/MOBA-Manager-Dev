class_name UI
extends RefCounted
## Small widget toolkit for the portrait phone layout (720 x 1280 design size). Flat colours only:
## art comes in the last pre-launch phase. All visible text must come from Strings.

const BG := Color("0e1620")
const PANEL := Color("172433")
const PANEL2 := Color("22364c")
const ACCENT := Color("3fb9a6")
const GOOD := Color("5bd68a")
const BAD := Color("ef6b6b")
const WARN := Color("f2c14e")
const TEXT := Color("e8eef5")
const DIM := Color("8fa3b8")
const BLUE := Color("5aa9ff")
const RED := Color("ff7a7a")

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
	t.set_stylebox("normal", "Button", box(PANEL2, 16, 18))
	t.set_stylebox("hover", "Button", box(PANEL2.lightened(0.08), 16, 18))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.35), 16, 18))
	t.set_stylebox("disabled", "Button", box(PANEL, 16, 18))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 16, 18, ACCENT, 3))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 18, 20))
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
	match kind:
		"primary":
			b.add_theme_stylebox_override("normal", box(ACCENT.darkened(0.15), 16, 18))
			b.add_theme_stylebox_override("hover", box(ACCENT, 16, 18))
			b.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.4), 16, 18))
			b.add_theme_color_override("font_color", Color("04120f"))
			b.add_theme_color_override("font_hover_color", Color("04120f"))
			b.add_theme_color_override("font_pressed_color", Color("ffffff"))
		"danger":
			b.add_theme_stylebox_override("normal", box(BAD.darkened(0.45), 16, 18))
		"flat":
			b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), 12, 12))
	b.pressed.connect(cb)
	return b


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
static func card(parent: Control, color: Color = PANEL, pad: int = 20) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(color, 18, pad))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
