class_name Toast
extends RefCounted
## One toast (moved out of main.gd in I-07; `App.toast` and `Main.toast` keep their signature and call this).
## Toast.make(text, color, action, cb) returns a PanelContainer that fades out and frees itself (3 s, or 4.5 s with an
## action). With an action it has one primary button (96 px high, at least 150 wide) and the toast is at least 96 px
## high (UI-PASS-2 5.15); tapping the button runs `cb` and removes the toast. The border colour is reinforcement: the
## text says what happened. Main adds the toast to its toast column and keeps at most three.

const LIFE := 3.0
const LIFE_ACTION := 4.5


static func make(text: String, color: Color = UI.TEXT, action: String = "", cb: Callable = Callable()) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL3, 20, 16, color, 2))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var has_action := action != "" and cb.is_valid()
	if has_action:
		pc.custom_minimum_size = Vector2(0, UI.BTN_H)
	var row := HBoxContainer.new()
	row.add_child(UI.label(text, UI.S_SMALL, UI.TEXT))
	if has_action:
		var on_tap := func() -> void:
			cb.call()
			if is_instance_valid(pc):
				pc.queue_free()
		var b := UI.button(action, on_tap, "primary", UI.BTN_H)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.custom_minimum_size = Vector2(150, UI.BTN_H)
		b.add_theme_font_size_override("font_size", UI.S_BODY)    # explicit: a CanvasLayer between the toast and Main drops Main's theme
		row.add_child(b)
	pc.add_child(row)
	CompKit.mark_stateful(pc)
	CompKit.set_cue(pc, "text")
	pc.set_meta("toast", true)
	return pc


## Starts the life of a toast that is already in the tree: waits, fades (when UI.animate) and frees it.
static func start_life(pc: Control, has_action: bool) -> void:
	var tw := pc.create_tween()
	tw.tween_interval(LIFE_ACTION if has_action else LIFE)
	if UI.animate:
		tw.tween_property(pc, "modulate:a", 0.0, UI.T_FADE)
	tw.tween_callback(pc.queue_free)
