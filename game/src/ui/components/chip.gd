class_name Chip
extends Control
## A passive status tag (UI-PASS-2 5.3, ART-BIBLE 3.4): 44 px high, full pill, icon 28 + text 24 SemiBold, padding 16 / 8.
## One node, drawn in _draw (the tint, the border, the icon and the text), so a row of ten chips is ten nodes.
## Variants: neutral, good, bad, warn, accent. Each has its own icon, so colour is never the only cue (the text is the
## other). A tappable thing is a Segmented option or a button, not a chip. The colour is read from UI when drawn, so a
## chip made before the colour-blind switch changes needs a redraw (queue_redraw) to follow it.

const H := 44
const ICON := 28
const PAD := 16
const GAP := 8
const SIZE_TEXT := UI.S_CAPTION
## variant -> default icon id (IconHook ids)
const ICONS := {"neutral": "dot", "good": "check", "bad": "cross", "warn": "warn", "accent": "star"}

var text := ""
var variant := "neutral"
var icon_id := ""             # "" = the variant's icon, "none" = no icon (a count chip)
var on_raised := false        # the lift rule of ART-BIBLE 3.4: text 25 percent towards white on a raised surface
var applied := 0              # changes that really happened (tests)
var draw_count := 0           # times _draw ran (tests)
var _line := TextLine.new()
var _natural_w := 0.0


func _init(p_text: String = "", p_variant: String = "neutral", p_icon: String = "", p_tut_id: String = "", p_on_raised: bool = false) -> void:
	text = p_text
	variant = p_variant
	icon_id = p_icon
	on_raised = p_on_raised
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_PASS
	CompKit.mark_stateful(self)
	CompKit.tag(self, p_tut_id)
	_measure()


func set_text(v: String) -> void:
	if v == text:
		return
	text = v
	applied += 1
	_measure()


func set_variant(v: String) -> void:
	if v == variant:
		return
	variant = v
	applied += 1
	_measure()


func set_icon(v: String) -> void:
	if v == icon_id:
		return
	icon_id = v
	applied += 1
	_measure()


func set_on_raised(v: bool) -> void:
	if v == on_raised:
		return
	on_raised = v
	applied += 1
	queue_redraw()


## The icon id drawn ("" when none).
func shown_icon() -> String:
	if icon_id == "none":
		return ""
	return icon_id if icon_id != "" else String(ICONS.get(variant, "dot"))


func state_name() -> String:
	return variant


func plain_text() -> String:
	return UI.plain(text)


## Width the chip needs to show its text in full.
func needs_width() -> float:
	return _natural_w


## True when the room it was given is smaller than it needs (the text is cut with "...").
func is_clipped() -> bool:
	return size.x > 0.0 and size.x < _natural_w - 0.5


func _colour() -> Color:
	var c: Color
	match variant:
		"good":
			c = UI.GOOD
		"bad":
			c = UI.BAD
		"warn":
			c = UI.WARN
		"accent":
			c = UI.ACCENT
		_:
			c = UI.DIM
	return c


func _measure() -> void:
	_line = TextLine.new()
	_line.add_string(text, UI.font("SemiBold"), SIZE_TEXT)
	_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var ic := shown_icon()
	_natural_w = PAD * 2.0 + _line.get_line_width() + (ICON + GAP if ic != "" else 0.0)
	custom_minimum_size = Vector2(ceilf(_natural_w), H)
	CompKit.set_cue(self, ic if ic != "" else "text")
	tooltip_text = ""
	queue_redraw()


func _draw() -> void:
	draw_count += 1
	var col := _colour()
	var w := size.x
	draw_style_box(UI.box(Color(col.r, col.g, col.b, 0.16), 22, 0, Color(col.r, col.g, col.b, 0.45), 1), Rect2(0, 0, w, size.y))
	var tcol := col.lerp(Color.WHITE, 0.25) if on_raised else col
	var x := float(PAD)
	var ic := shown_icon()
	if ic != "":
		IconHook.draw(self, ic, Rect2(x, (size.y - ICON) * 0.5, ICON, ICON), tcol)
		x += ICON + GAP
	_line.width = maxf(0.0, w - x - PAD)
	_line.draw(get_canvas_item(), Vector2(x, (size.y - _line.get_size().y) * 0.5), tcol)
