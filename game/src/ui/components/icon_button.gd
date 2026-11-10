class_name IconButton
extends Button
## An icon-only button (UI-PASS-2 5.15): the hit area is 96 x 96, the visible disc is 64 and the icon 32, so the control is
## easy to hit and light to look at. The icon comes from IconHook (placeholder until I-09 wires art/icons).
## Never an icon alone for a decision (pattern 14): `accessible_name` is required, kept in the meta "accessible_name"
## and in tooltip_text (a long press shows it where the platform supports tooltips). Pass Strings.t(...) for it.
## States: normal, pressed (the 0.97 pulse), active (a toggle that is on: accent disc + ring), disabled (faded).
## Built once; set_icon_id / set_active / set_enabled change it in place.

const VISUAL := 64
const ICON := 32

var icon_id := ""
var accessible_name := ""
var active := false
var applied := 0
var draw_count := 0


func _init(p_icon_id: String = "", p_accessible_name: String = "", p_on_tap: Callable = Callable(), p_tut_id: String = "") -> void:
	icon_id = p_icon_id
	accessible_name = p_accessible_name
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_PASS    # a swipe that starts on it scrolls the page
	custom_minimum_size = Vector2(UI.BTN_H, UI.BTN_H)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	CompKit.hollow(self)
	tooltip_text = accessible_name
	set_meta("accessible_name", accessible_name)
	button_down.connect(UI._pulse.bind(self))
	if p_on_tap.is_valid():
		pressed.connect(p_on_tap)
	CompKit.mark_stateful(self)
	_update_cue()
	UI.tag(self, p_tut_id)    # a Button: raises tap:<id> when pressed


func set_icon_id(v: String) -> void:
	if v == icon_id:
		return
	icon_id = v
	applied += 1
	queue_redraw()


func set_active(v: bool) -> void:
	if v == active:
		return
	active = v
	applied += 1
	_update_cue()
	queue_redraw()


func set_enabled(v: bool) -> void:
	if v == (not disabled):
		return
	disabled = not v
	applied += 1
	_update_cue()
	queue_redraw()


func state_name() -> String:
	if disabled:
		return "disabled"
	return "active" if active else ""


func _update_cue() -> void:
	CompKit.set_cue(self, "faded" if disabled else ("ring" if active else ""))


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAW:
		return
	draw_count += 1
	var c := size * 0.5
	var disc := Rect2(c - Vector2(VISUAL, VISUAL) * 0.5, Vector2(VISUAL, VISUAL))
	var fill := UI.ACCENT if active else UI.PANEL2
	var ink := UI.INK_TEAL if active else UI.TEXT
	if disabled:
		fill = UI.PANEL
		ink = UI.TEXT_OFF
	draw_style_box(UI.box(fill, VISUAL / 2, 0, UI.TEAL_HI if active else UI.LINE, 3 if active else 1), disc)
	IconHook.draw(self, icon_id, Rect2(c - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON)), ink)
