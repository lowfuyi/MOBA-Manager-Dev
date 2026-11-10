class_name DepthCard
extends PanelContainer
## A card with depth (UI-PASS-2 5.1, ART-BIBLE 4.1). Anatomy: shadow (raised and overlay only) > body > hairline >
## 1.5 px top highlight and 2 px bottom edge (drawn above the body, below the content) > selected ring + glow.
## Elevation 0 = flat (E1: lists, grids, cards inside cards; no shadow), 1 = raised (E2: hero cards; real soft shadow),
## 2 = overlay (E3: sheets, dialogs; real soft shadow). `inset` = the dark well (VOID) for maps and boards.
## Shadow and glow come from the "panel" StyleBoxFlat, so the perf gate (tests/perf_gate.gd count_shadows) sees them:
## the limits are 6 shadowed and 2 glowing surfaces on screen. Shadow size is capped at 18 px (PERF-BUDGET 3.2), so E3
## uses 18 where the bible says 28.
## Selected = 3 px accent ring + a check badge at the top right (the shape cue; reserve 44 px there) + glow.
## Disabled = 60 percent opacity, no press. Pressed (tappable cards) = body 10 percent darker + the 0.97 pulse.
## The body is flat colour for now: the baked gradient surface (E lane, art/surface.gd) plugs in through `surface_hook`.
## Add children to `content` (a VBoxContainer inside the padding). `UI.card`'s old callers keep working untouched.

signal pressed

## PLACEHOLDER HOOK for I-09 (art/surface.gd): Callable(elevation: int, tint: Color, selected: bool, inset: bool,
## pressed: bool) -> StyleBox. Invalid, or returning null = the flat StyleBoxFlat built here.
static var surface_hook: Callable = Callable()

var content: VBoxContainer
var elevation := 0
var tint := Color(0, 0, 0, 0)    # transparent = the elevation's own surface colour
var selected := false
var inset := false
var disabled := false
var tut_id := ""
var applied := 0
var draw_count := 0
var _hit: Button
var _pressed_look := false
var _margin: MarginContainer
var _last_style: StyleBox


func _init(p_elevation: int = 0, p_tint: Color = Color(0, 0, 0, 0), p_selected: bool = false, p_tappable: bool = false,
		p_tut_id: String = "", p_pad: int = UI.PAD_CARD, p_inset: bool = false) -> void:
	elevation = clampi(p_elevation, 0, 2)
	tint = p_tint
	selected = p_selected
	inset = p_inset
	tut_id = p_tut_id
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS    # PanelContainer defaults to STOP, which blocks swipe-scrolling
	if p_tappable:
		_hit = Button.new()
		_hit.flat = true
		_hit.focus_mode = Control.FOCUS_NONE
		_hit.mouse_filter = Control.MOUSE_FILTER_PASS
		CompKit.hollow(_hit)
		_hit.button_down.connect(_on_down)
		_hit.button_up.connect(_on_up)
		_hit.pressed.connect(_on_pressed)
		add_child(_hit)
	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE    # taps fall through to the hit button under the content
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, p_pad)
	add_child(_margin)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(content)
	CompKit.mark_stateful(self)
	CompKit.tag(self, tut_id)
	_restyle()


## `UI.card`-style factory: a card in `parent`, returns the content column.
static func make(parent: Control, p_elevation: int = 0, p_tint: Color = Color(0, 0, 0, 0), p_selected: bool = false) -> VBoxContainer:
	var c := DepthCard.new(p_elevation, p_tint, p_selected)
	parent.add_child(c)
	return c.content


func set_elevation(v: int) -> void:
	v = clampi(v, 0, 2)
	if v == elevation:
		return
	elevation = v
	applied += 1
	_restyle()


func set_tint(v: Color) -> void:
	if v == tint:
		return
	tint = v
	applied += 1
	_restyle()


func set_selected(v: bool) -> void:
	if v == selected:
		return
	selected = v
	applied += 1
	_restyle()


func set_inset(v: bool) -> void:
	if v == inset:
		return
	inset = v
	applied += 1
	_restyle()


func set_disabled(v: bool) -> void:
	if v == disabled:
		return
	disabled = v
	applied += 1
	modulate.a = 0.6 if v else 1.0
	if _hit != null:
		_hit.disabled = v
	_restyle()


func state_name() -> String:
	if disabled:
		return "disabled"
	return "selected" if selected else ""


func has_shadow() -> bool:
	return selected or (elevation >= 1 and not inset)


func _body_colour() -> Color:
	if inset:
		return UI.VOID
	if tint.a > 0.0:
		return tint
	return [UI.PANEL, UI.PANEL2, UI.PANEL3][elevation]


func _make_style(pressed_look: bool) -> StyleBox:
	if surface_hook.is_valid():
		var s: Variant = surface_hook.call(elevation, tint, selected, inset, pressed_look)
		if s is StyleBox:
			return s
	var col := _body_colour()
	if pressed_look:
		col = col.darkened(0.10)
	var border := UI.LINE
	var bw := 1
	var sh := 0
	var sy := 0
	var sc := Color(0, 0, 0, 0.38)
	if selected:
		border = UI.ACCENT
		bw = 3
		sh = 12    # the glow: accent at 35 percent, blur 10 to 12 (ART-BIBLE 4.2)
		sc = Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.35)
	elif inset:
		border = Color(0, 0, 0, 0.5)
	elif elevation == 1:
		sh = 18    # E2: 8 / 18 / 45 percent
		sy = 8
		sc = Color(0, 0, 0, 0.45)
	elif elevation == 2:
		sh = 18    # E3 is 14 / 28 / 55 percent in the bible; the size is capped at 18 (PERF-BUDGET 3.2)
		sy = 14
		sc = Color(0, 0, 0, 0.55)
	return UI.box(col, UI.R_CARD, 0, border, bw, sh, sy, sc)


func _restyle() -> void:
	_last_style = _make_style(_pressed_look)
	add_theme_stylebox_override("panel", _last_style)
	CompKit.set_cue(self, "ring+check" if selected else ("faded" if disabled else ""))
	queue_redraw()


func _on_down() -> void:
	if disabled:
		return
	_pressed_look = true
	_restyle()
	UI._pulse(self)


func _on_up() -> void:
	if _pressed_look:
		_pressed_look = false
		_restyle()


func _on_pressed() -> void:
	if disabled:
		return
	pressed.emit()
	CompKit.tap_event(tut_id)


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAW:
		return
	# Script notifications run after the native panel draw: this lands on top of the body, under the children.
	draw_count += 1
	var w := size.x
	var h := size.y
	var r := float(UI.R_CARD)
	if inset:
		draw_line(Vector2(r, 1.5), Vector2(w - r, 1.5), Color(0, 0, 0, 0.5), 2.0)
	else:
		var a := 0.20 if elevation > 0 else 0.14
		draw_line(Vector2(20.0, 1.5), Vector2(w - 20.0, 1.5), Color(1, 1, 1, a), 1.5)
		draw_line(Vector2(r, h - 1.0), Vector2(w - r, h - 1.0), Color(0, 0, 0, 0.30), 2.0)
	if selected:
		var c := Vector2(w - 30.0, 30.0)
		draw_circle(c, 17.0, UI.ACCENT)
		IconHook.draw(self, "check", Rect2(c - Vector2(12, 12), Vector2(24, 24)), UI.INK_TEAL)
