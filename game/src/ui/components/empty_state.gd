class_name EmptyState
extends VBoxContainer
## Never a blank screen (UI-PASS-2 pattern 7): an illustration slot (384 x 288), one line of what is empty (32 px), one
## line of why or what to do (26 px) and one action button (96 px high). All text is passed in (Strings.t at the caller).
## PLACEHOLDER HOOK for I-09: `illustration_hook` = Callable(ci: CanvasItem, rect: Rect2, icon_id: String) draws the
## picture into the slot; without it a dashed-corner frame and the IconHook icon are drawn.
## Built once; set_title / set_helper / set_action / set_icon change it in place (an action text of "" hides the button).

signal action_pressed

const ART_W := 384
const ART_H := 288

static var illustration_hook: Callable = Callable()

var title := ""
var helper := ""
var icon_id := ""
var applied := 0
var _art: _Art
var _title: Label
var _helper: Label
var _btn: Button
var _on_action: Callable
var _tut := ""


class _Art extends Control:
	var icon_id := ""

	func _init() -> void:
		custom_minimum_size = Vector2(ART_W, ART_H)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if EmptyState.illustration_hook.is_valid():
			EmptyState.illustration_hook.call(self, r, icon_id)
			return
		draw_style_box(UI.box(Color(0, 0, 0, 0), UI.R_CARD, 0, UI.LINE_HI, 2), r)
		IconHook.draw(self, icon_id if icon_id != "" else "dot", Rect2(r.get_center() - Vector2(48, 48), Vector2(96, 96)), UI.DIM)


func _init(p_title: String = "", p_helper: String = "", p_action: String = "", p_on_action: Callable = Callable(), p_icon: String = "", p_tut_id: String = "") -> void:
	title = p_title
	helper = p_helper
	icon_id = p_icon
	_on_action = p_on_action
	_tut = p_tut_id
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", 12)
	_art = _Art.new()
	_art.icon_id = icon_id
	add_child(_art)
	_title = UI.label(title, UI.S_BODY, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, "SemiBold")
	add_child(_title)
	_helper = UI.label(helper, UI.S_SMALL, UI.TEXT2, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_helper)
	_btn = UI.button(p_action, _on_pressed, "primary", UI.BTN_H)
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn.custom_minimum_size = Vector2(320, UI.BTN_H)
	_btn.add_theme_font_size_override("font_size", UI.S_BODY)    # explicit: the size does not depend on the theme being installed
	_btn.visible = p_action != ""
	add_child(_btn)
	CompKit.tag(self, p_tut_id)
	if p_tut_id != "":
		UI.tag(_btn, p_tut_id + ".action")


func set_title(v: String) -> void:
	if v == title:
		return
	title = v
	applied += 1
	_title.text = UI.tidy(v)


func set_helper(v: String) -> void:
	if v == helper:
		return
	helper = v
	applied += 1
	_helper.text = UI.tidy(v)


func set_action(v: String) -> void:
	var shown := v != ""
	if v == UI.plain(_btn.text) and shown == _btn.visible:
		return
	applied += 1
	_btn.visible = shown
	_btn.text = UI.tidy(v)


func set_icon(v: String) -> void:
	if v == icon_id:
		return
	icon_id = v
	applied += 1
	_art.icon_id = v
	_art.queue_redraw()


func action_button() -> Button:
	return _btn


func _on_pressed() -> void:
	action_pressed.emit()
	if _on_action.is_valid():
		_on_action.call()
