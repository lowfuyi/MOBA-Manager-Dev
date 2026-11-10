class_name SectionHeader
extends PanelContainer
## The label above a group (UI-PASS-2 5.2): a Caption 24 px SemiBold upper-case label with +8 percent tracking in
## TEAL_HI, an optional count chip, an optional action on the right ("See all", hit area 96) and, when `expandable`, a
## drawn chevron that replaces the old "+ " and "- " text prefixes of UI.section (the whole row is the 96 px hit area).
## Height 56 px; 96 px when it has an action or opens something (a tap target is never shorter).
## Built once; set_text / set_count / set_open / set_action_text change it in place.
## Test helper for the migrated prefix tests: SectionHeader.find(root, needle) returns the header whose title contains
## the needle (the old tests looked for a Button whose text began with "+ ").

signal toggled(open: bool)
signal action_pressed

const H_PLAIN := 56
const H_TAP := 96

var title := ""
var expandable := false
var open := false
var content: Control             # shown only while open (optional)
var applied := 0
var tut_id := ""
var _label: Label
var _chev: _Chevron
var _count: Chip
var _action: Button
var _hit: Button
var _row: HBoxContainer


class _Chevron extends Control:
	var is_open := false

	func _init() -> void:
		custom_minimum_size = Vector2(32, 32)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		IconHook.draw(self, "chevron_down" if is_open else "chevron_right", Rect2(Vector2.ZERO, size), UI.TEAL_HI)


## `opts`: count (int, default none), action (String), on_action (Callable), expandable (bool), open (bool),
## content (Control the chevron shows and hides), tut_id (String).
func _init(p_title: String = "", opts: Dictionary = {}) -> void:
	title = p_title
	expandable = bool(opts.get("expandable", false))
	open = bool(opts.get("open", false))
	content = opts.get("content", null)
	tut_id = String(opts.get("tut_id", ""))
	var action_text := String(opts.get("action", ""))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", CompKit.empty_box())
	custom_minimum_size = Vector2(0, H_TAP if (expandable or action_text != "") else H_PLAIN)
	if expandable:
		_hit = Button.new()
		_hit.flat = true
		_hit.focus_mode = Control.FOCUS_NONE
		_hit.mouse_filter = Control.MOUSE_FILTER_PASS
		CompKit.hollow(_hit)
		_hit.pressed.connect(_on_toggle)
		add_child(_hit)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 12)
	add_child(_row)
	if expandable:
		_chev = _Chevron.new()
		_row.add_child(_chev)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", UI.S_CAPTION)
	_label.add_theme_color_override("font_color", UI.TEAL_HI)
	_label.add_theme_font_override("font", CompKit.tracked_font("SemiBold", UI.S_CAPTION * 0.08))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_label)
	_count = Chip.new("", "neutral", "none")
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_count.visible = false
	_row.add_child(_count)
	if action_text != "":
		_action = UI.button(action_text, _on_action.bind(opts.get("on_action", Callable())), "flat", H_TAP)
		_action.size_flags_horizontal = Control.SIZE_SHRINK_END
		_action.autowrap_mode = TextServer.AUTOWRAP_OFF
		_action.custom_minimum_size = Vector2(H_TAP, H_TAP)
		if tut_id != "":
			UI.tag(_action, tut_id + ".action")    # a Button: raises tap:<id>.action itself
		_action.add_theme_color_override("font_color", UI.ACCENT)
		_action.add_theme_font_size_override("font_size", UI.S_SMALL)
		_row.add_child(_action)
	if opts.has("count"):
		set_count(int(opts["count"]))
	_apply_text()
	_apply_open()
	CompKit.mark_stateful(self)
	CompKit.tag(self, tut_id)
	_update_cue()


static func find(root: Node, needle: String) -> SectionHeader:
	if root is SectionHeader and (root as SectionHeader).title.contains(needle):
		return root as SectionHeader
	for ch in root.get_children():
		var r := find(ch, needle)
		if r != null:
			return r
	return null


func set_text(v: String) -> void:
	if v == title:
		return
	title = v
	applied += 1
	_apply_text()


## A count chip beside the label; a negative number hides it.
func set_count(n: int) -> void:
	var want := n >= 0
	if want == _count.visible and (not want or _count.text == str(n)):
		return
	applied += 1
	_count.visible = want
	if want:
		_count.set_text(str(n))


func set_action_text(v: String) -> void:
	if _action == null or _action.text == UI.tidy(v):
		return
	applied += 1
	_action.text = UI.tidy(v)


func set_open(v: bool) -> void:
	if not expandable or v == open:
		return
	open = v
	applied += 1
	_apply_open()
	_update_cue()


func state_name() -> String:
	return ("open" if open else "closed") if expandable else ""


func action_button() -> Button:
	return _action


func hit_button() -> Button:
	return _hit


func _apply_text() -> void:
	_label.text = UI.tidy(title.to_upper())


func _apply_open() -> void:
	if _chev != null:
		_chev.is_open = open
		_chev.queue_redraw()
	if content != null:
		content.visible = open


func _update_cue() -> void:
	CompKit.set_cue(self, ("chevron_down" if open else "chevron_right") if expandable else "")


func _on_toggle() -> void:
	set_open(not open)    # the equality guard lives in set_open; the signal is raised once per change
	toggled.emit(open)
	CompKit.tap_event(tut_id)


func _on_action(cb: Callable) -> void:
	action_pressed.emit()
	if cb.is_valid():
		cb.call()
