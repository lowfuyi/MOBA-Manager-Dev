class_name UI
extends RefCounted
## Small widget toolkit for the portrait phone layout (720 x 1280 design size). Flat colours only:
## art comes in the last pre-launch phase. All visible text must come from Strings.

## Arena Dusk (UI direction approved 2026-11-08): deep navy, teal, one warm coral accent for "go".
## Token values follow docs/design/ART-BIBLE.md section 3 (colours) and 5.2 (type scale); tests/check_ui_tokens.gd
## reads those tables and fails when a constant drifts. Old names stay as aliases so unredesigned screens keep working.

# ---- surfaces (3.1). The "top" values are the lighter end of the gradient a later increment will draw.
const VOID := Color("070d1a")            # wells, progress tracks, switch tracks, pressed
const BG := Color("0a1120")              # page base
const BG_GLOW := Color("14284a")         # top of the page gradient only
const PANEL := Color("162842")           # surface 1: card
const PANEL_TOP := Color("1d3354")
const PANEL2 := Color("223a5e")          # surface 2: raised
const PANEL2_TOP := Color("2c4a78")
const PANEL3 := Color("30507f")          # surface 3: overlay, selected tab pill
const PANEL3_TOP := Color("3c629c")
const LINE := Color(1, 1, 1, 0.06)       # hairline around cards
const LINE_HI := Color(1, 1, 1, 0.16)    # inner highlight along a top edge (14 to 18 percent)

# ---- text (3.2)
const TEXT := Color("eaf0f7")
const TEXT2 := Color("b9c8da")           # secondary lines
const DIM := Color("96aac4")             # captions, hints (never on overlay)
const TEXT_OFF := Color("62748c")        # disabled only
const INK_TEAL := Color("04120f")        # text on teal fills
const INK_CORAL := Color("1c0b04")       # text on coral fills

# ---- accent, status, sides (3.3)
const ACCENT := Color("3fd0b8")          # teal: selection, progress, links, confirm
const TEAL_HI := Color("7be3d2")         # section titles, selected tab text, focus ring
const TEAL_LO := Color("1f8e80")         # fills and gradient ends only, never text
const TEAL_DEEP := Color("0f4a4a")       # tints and wells
const CORAL := Color("ff8a5c")           # the one primary action on a screen (Play); "them" in the match
const CORAL_HI := Color("ffb594")        # coral text on overlay
const CORAL_LO := Color("e4602f")        # pressed
const WARN := Color("f2c14e")
const GOOD_DEFAULT := Color("5bd68a")
const BAD_DEFAULT := Color("f58080")
const GOOD_CB := Color("7fd0ff")         # colour-blind friendly pair: sky and orange
const BAD_CB := Color("f2924a")
const SIDE_BLUE := Color("5aa9ff")       # the cloth of the Blue-side flag, nothing else
const SIDE_RED := Color("f58080")        # = BAD_DEFAULT; the colour-blind switch does not swap it
const MAP_LAND := Color("173629")
const MAP_MERE := Color("0e3550")
const MAP_SHORE := Color("2f7f8f")       # strokes only

# ---- role colours (3.5): rings and glyphs only, never text, never button fills
const ROLE_TOP := Color("9797f7")
const ROLE_JUNGLE := Color("b7f797")
const ROLE_MID := Color("68dcf3")
const ROLE_BOT := Color("efd139")
const ROLE_SUPPORT := Color("f36896")

## Old names (aliases, so unredesigned screens keep compiling).
const BLUE := SIDE_BLUE
const RED := SIDE_RED

static var GOOD := GOOD_DEFAULT
static var BAD := BAD_DEFAULT
static var colorblind := false


static func set_colorblind(v: bool) -> void:
	colorblind = v
	GOOD = GOOD_CB if v else GOOD_DEFAULT
	BAD = BAD_CB if v else BAD_DEFAULT


## Motion tokens (seconds). Animations can be switched off in Settings (UI.animate).
const T_PRESS := 0.12
const T_COUNT := 0.6
const T_FADE := 0.25

## Spacing and shape tokens (ART-BIBLE 4.1: card radius 24, button radius 20, gap 16, card padding 24).
const R_CARD := 24
const R_BTN := 20
const GAP := 16
const PAD_CARD := 24

static var animate := true

## Type scale (ART-BIBLE 5.2). Pixels on the 720 px design canvas; nothing in the game is below S_CAPTION.
const S_DISPLAY := 64
const S_TITLE := 48
const S_BIG := 40          # "Value": screen and sheet titles, numbers the player acts on
const S_HEAD := 36
const S_BODY := 32
const S_SMALL := 26
const S_CAPTION := 24      # the floor

## Heights and frame (96 px = 48 dp touch target).
const BTN_H := 96
const TAB_H := 112
const HEADER_H := 96

## Design canvas and large text (content scale 1.15: the logical canvas is 626 x 1113).
const DESIGN_W := 720.0
const LARGE_SCALE := 1.15
static var large := false

## The type scale as data: style -> primary weight, line-height factor. The size is the S_ constant of the same style.
## Pairs are every (size, weight) the scale uses (12; 11 before the arena's Caption Bold map labels). Plain data so the
## token check can compare it with the ART-BIBLE table and count the font-memory pairs.
const TYPE_SCALE := {
	"display": {"size": S_DISPLAY, "weight": "ExtraBold", "line": 1.05},
	"title": {"size": S_TITLE, "weight": "Bold", "line": 1.1},
	"value": {"size": S_BIG, "weight": "Bold", "line": 1.15},
	"heading": {"size": S_HEAD, "weight": "SemiBold", "line": 1.2},
	"body": {"size": S_BODY, "weight": "Regular", "line": 1.35},
	"small": {"size": S_SMALL, "weight": "Medium", "line": 1.3},
	"caption": {"size": S_CAPTION, "weight": "SemiBold", "line": 1.25},
}
const TYPE_PAIRS := [
	[S_DISPLAY, "ExtraBold"], [S_TITLE, "Bold"], [S_BIG, "Bold"], [S_BIG, "SemiBold"], [S_HEAD, "SemiBold"],
	[S_HEAD, "Bold"], [S_BODY, "Regular"], [S_BODY, "SemiBold"], [S_SMALL, "Medium"], [S_SMALL, "SemiBold"],
	[S_CAPTION, "SemiBold"], [S_CAPTION, "Bold"],
]
## The four number styles (score line, value, row number, small number) and their weight. Each also exists as a `tnum`
## variant, counted separately: 12 pairs + 4 = 16, the hard limit of PERF-BUDGET 3.1a. A fifth number style needs a bible edit.
const NUM_WEIGHT := {64: "ExtraBold", 40: "SemiBold", 32: "Regular", 26: "Medium"}

const WEIGHTS := ["Regular", "Medium", "SemiBold", "Bold", "ExtraBold"]
const FONT_PATH := "res://assets/fonts/BarlowSemiCondensed-%s.ttf"
const DEFAULT_FONT_PATH := "res://assets/fonts/default_font.tres"

static var _fonts: Dictionary = {}
static var _system_fallback: SystemFont
static var _boxes: Dictionary = {}


## Large-text hook: App.apply_large_text() tells UI, so code that measures the frame knows its width.
static func set_large(v: bool) -> void:
	large = v


## Logical canvas width in px: 720, or 626 in large-text mode.
static func canvas_w() -> float:
	return DESIGN_W / (LARGE_SCALE if large else 1.0)


## The weight the type scale gives a text size ("Regular" when the size is not on the scale).
static func default_weight(size: int) -> String:
	for st in TYPE_SCALE.values():
		if int(st["size"]) == size:
			return String(st["weight"])
	return "Regular"


## A cached font of one weight (Regular, Medium, SemiBold, Bold, ExtraBold), same system fallback as the default
## font. `tnum` switches on tabular digits (every digit the same width, so columns of numbers line up). One
## FontVariation per (weight, tnum), shared by every control.
static func font(weight: String = "Regular", tnum: bool = false) -> Font:
	var key := weight + ("+tnum" if tnum else "")
	if _fonts.has(key):
		return _fonts[key]
	var fv: FontVariation
	if weight == "Regular" and not tnum:
		fv = load(DEFAULT_FONT_PATH) as FontVariation
	else:
		fv = FontVariation.new()
		fv.base_font = load(FONT_PATH % weight) as FontFile
		if _system_fallback == null:
			_system_fallback = SystemFont.new()
			_system_fallback.font_names = PackedStringArray(["sans-serif"])
		fv.fallbacks = [_system_fallback]
		if tnum:
			fv.opentype_features = {"tnum": 1}
	_fonts[key] = fv
	return fv


## How many FontVariations exist (the font-memory gate counts these; at most 10: five weights, with and without tnum).
static func font_cache_size() -> int:
	return _fonts.size()


## Style boxes are cached by (colour, radius, padding, border colour, border width, shadow) and SHARED between
## controls: never change a box you got from UI.box (build your own StyleBoxFlat if you need to).
static func box(color: Color, radius: int = 14, pad: int = 0, border: Color = Color(0, 0, 0, 0), border_w: int = 0,
		shadow_size: int = 0, shadow_y: int = 0, shadow_color: Color = Color(0, 0, 0, 0.38)) -> StyleBoxFlat:
	var key := "%s|%d|%d|%s|%d|%d|%d|%s" % [color.to_html(true), radius, pad, border.to_html(true), border_w, shadow_size, shadow_y, shadow_color.to_html(true)]
	if _boxes.has(key):
		return _boxes[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	if shadow_size > 0:
		sb.shadow_size = shadow_size
		sb.shadow_offset = Vector2(0, shadow_y)
		sb.shadow_color = shadow_color
	_boxes[key] = sb
	return sb


static func box_cache_size() -> int:
	return _boxes.size()


# ---- tutorial tags (build plan I-03, TUTORIAL 7.2 and 8) ------------------------------------------------------
## id -> Array of WeakRef (controls). Weak, so a screen that is freed leaves nothing behind; entries are also removed
## when the control leaves the tree. Several controls may carry one id for a frame (a screen rebuilt while the old one
## is still waiting to be freed): find_tag() returns the newest one that is visible.
static var _tags: Dictionary = {}
const TAG_META := "tag_id"


## Name a control for the tutorial and the help system. `tap_source` (default true) makes a button raise
## `tap:<id>` on App.bus when it is pressed (after its own handler, because the tag is applied after the button is wired).
## Safe to call again after a rebuild, and to call twice on one control (the second id replaces the first).
## Never tag a bare Label: the highlight needs a visible edge (TUTORIAL 8, contract item 3). Returns the control.
static func tag(control: Control, id: String, tap_source: bool = true) -> Control:
	if control == null or id == "":
		return control
	var old: String = String(control.get_meta(TAG_META, ""))
	if old == id:
		return control
	if old != "":
		_untag(control, old)
	control.set_meta(TAG_META, id)
	if not _tags.has(id):
		_tags[id] = []
	(_tags[id] as Array).append(weakref(control))
	var gone := _on_tag_exit.bind(id, control.get_instance_id())
	if not control.tree_exited.is_connected(gone):
		control.tree_exited.connect(gone, CONNECT_DEFERRED)
	if tap_source and control is BaseButton:
		var tap := _on_tag_tap.bind(id)
		if not (control as BaseButton).pressed.is_connected(tap):
			(control as BaseButton).pressed.connect(tap)
	return control


## The live, visible control that carries `id`, or null. "Live" = valid and in the tree; "visible" = shown on screen
## (a hidden page or a closed sheet does not count).
static func find_tag(id: String) -> Control:
	if not _tags.has(id):
		return null
	var arr: Array = _tags[id]
	var found: Control = null
	var i := arr.size() - 1
	while i >= 0:
		var c := (arr[i] as WeakRef).get_ref() as Control
		if c == null or not is_instance_valid(c):
			arr.remove_at(i)
		elif found == null and c.is_inside_tree() and c.is_visible_in_tree():
			found = c
		i -= 1
	if arr.is_empty():
		_tags.erase(id)
	return found


## The id a control was tagged with ("" if none).
static func tag_of(control: Control) -> String:
	return String(control.get_meta(TAG_META, "")) if control != null else ""


## How many live controls carry `id` (visible or not). For tests.
static func tag_count(id: String) -> int:
	if not _tags.has(id):
		return 0
	var n := 0
	for w in _tags[id]:
		var c := (w as WeakRef).get_ref() as Control
		if c != null and is_instance_valid(c):
			n += 1
	return n


static func _untag(control: Control, id: String) -> void:
	if _tags.has(id):
		var arr: Array = _tags[id]
		for i in range(arr.size() - 1, -1, -1):
			var c := (arr[i] as WeakRef).get_ref() as Control
			if c == null or c == control:
				arr.remove_at(i)
		if arr.is_empty():
			_tags.erase(id)
	var gone := _on_tag_exit.bind(id, control.get_instance_id())
	if control.tree_exited.is_connected(gone):
		control.tree_exited.disconnect(gone)
	var tap := _on_tag_tap.bind(id)
	if control is BaseButton and (control as BaseButton).pressed.is_connected(tap):
		(control as BaseButton).pressed.disconnect(tap)


static func _on_tag_exit(id: String, instance_id: int) -> void:
	# Runs deferred: a control that left the tree and came back in the same frame (moved to another parent) keeps its tag.
	if not _tags.has(id):
		return
	var arr: Array = _tags[id]
	for i in range(arr.size() - 1, -1, -1):
		var c := (arr[i] as WeakRef).get_ref() as Control
		if c == null or (c.get_instance_id() == instance_id and not c.is_inside_tree()):
			arr.remove_at(i)
	if arr.is_empty():
		_tags.erase(id)


static func _on_tag_tap(id: String) -> void:
	if is_instance_valid(App.bus):
		App.bus.emit("tap:" + id)


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = S_BODY
	t.set_color("font_color", "Label", TEXT)
	for cls in ["Button", "CheckButton"]:
		t.set_font("font", cls, font("SemiBold"))    # button labels are SemiBold (ART-BIBLE 5.2)
		t.set_font_size("font_size", cls, S_BODY)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, TEXT)
		t.set_color("font_pressed_color", cls, TEXT)
		t.set_color("font_disabled_color", cls, TEXT_OFF)
		t.set_color("font_focus_color", cls, TEXT)
	t.set_stylebox("normal", "Button", box(PANEL2, R_BTN, 18, LINE, 1))
	t.set_stylebox("hover", "Button", box(PANEL2.lightened(0.08), R_BTN, 18, LINE, 1))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.35), R_BTN, 18))
	t.set_stylebox("disabled", "Button", box(PANEL, R_BTN, 18))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), R_BTN, 18, TEAL_HI, 3))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, R_CARD, PAD_CARD, LINE, 1))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 8))
	t.set_stylebox("background", "ProgressBar", box(VOID, 8))
	t.set_font_size("font_size", "ProgressBar", S_CAPTION)
	t.set_constant("separation", "VBoxContainer", GAP)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "GridContainer", 12)
	t.set_constant("v_separation", "GridContainer", 12)
	return t


## A label. `weight` "" takes the weight the type scale gives that size (Bold at 48 and 40, SemiBold at 36 and 24,
## Medium at 26, Regular at 32); a size off the scale stays Regular.
static func label(text: String, size: int = S_BODY, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT, weight: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var w := weight if weight != "" else default_weight(size)
	if w != "Regular":
		l.add_theme_font_override("font", font(w))
	l.horizontal_alignment = align as HorizontalAlignment
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## A label for a number the player reads or compares (money, rating, score, time): tabular digits, so a column of
## numbers lines up, and never wrapping. `weight` "" takes the number weight of that size (SemiBold at 40 and 36).
static func num_label(text: String, size: int = S_BODY, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_RIGHT, weight: String = "") -> Label:
	var l := label(text, size, color, align)
	var w := weight if weight != "" else String(NUM_WEIGHT.get(size, default_weight(size)))
	l.add_theme_font_override("font", font(w, true))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


## `min_h` is raised to BTN_H (96 px, 48 dp): no button is shorter, whatever a screen asks for.
static func button(text: String, cb: Callable, kind: String = "normal", min_h: int = BTN_H) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, maxi(min_h, BTN_H))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART    # a long caption wraps instead of widening the page (large text)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS    # lets a swipe that starts on a button scroll the page
	match kind:
		"primary":
			b.add_theme_stylebox_override("normal", box(ACCENT.darkened(0.15), R_BTN, 18))
			b.add_theme_stylebox_override("hover", box(ACCENT, R_BTN, 18))
			b.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.4), R_BTN, 18))
			b.add_theme_color_override("font_color", INK_TEAL)
			b.add_theme_color_override("font_hover_color", INK_TEAL)
			b.add_theme_color_override("font_pressed_color", Color("ffffff"))
		"play":
			# the single "go" action of a screen: coral, so nothing else competes with it
			b.add_theme_stylebox_override("normal", box(CORAL, R_BTN, 18))
			b.add_theme_stylebox_override("hover", box(CORAL.lightened(0.08), R_BTN, 18))
			b.add_theme_stylebox_override("pressed", box(CORAL_LO, R_BTN, 18))
			b.add_theme_color_override("font_color", INK_CORAL)
			b.add_theme_color_override("font_hover_color", INK_CORAL)
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
static func card(parent: Control, color: Color = PANEL, pad: int = PAD_CARD, border: Color = LINE, border_w: int = 1) -> VBoxContainer:
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
	var l := label(text, S_CAPTION, color)
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
	for spec in [[title, S_CAPTION, DIM], [value, S_BIG, color], [sub, S_CAPTION, DIM]]:
		var l: Label
		if int(spec[1]) == S_BIG:
			l = num_label(String(spec[0]), S_BIG, spec[2], HORIZONTAL_ALIGNMENT_LEFT)    # the value is a number the player acts on
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			l = label(String(spec[0]), int(spec[1]), spec[2])
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
	var v := num_label(value, size, color, HORIZONTAL_ALIGNMENT_RIGHT, default_weight(size))    # a value never wraps letter by letter; digits line up
	v.custom_minimum_size = Vector2(150, 0)
	v.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(v)
	parent.add_child(h)
	return h
