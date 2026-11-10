class_name EdgeMeter
extends HBoxContainer
## A centre-zero bar (UI-PASS-2 5.10): 20 px high, the left half is them (coral), the right half is you (teal); the fill
## grows from the centre by the size of the edge. The value is also printed as signed text (+5.6%, 32 px, tabular digits),
## so colour is reinforcement only: the sign, the side of the centre and the printed number carry the meaning.
## `value` is a fraction (0.056 = +5.6 percent); `max_edge` is the edge that fills a half (default 0.20).
## Built once; set_value changes it in place, an equal value does nothing.

const BAR_H := 20

var value := 0.0
var max_edge := 0.20
var applied := 0
var draw_count := 0
var _bar: _Bar
var _text: Label


class _Bar extends Control:
	var meter: EdgeMeter

	func _init() -> void:
		custom_minimum_size = Vector2(96, EdgeMeter.BAR_H)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		meter.draw_count += 1
		var w := size.x
		var h := size.y
		draw_style_box(UI.box(UI.VOID, 10, 0, Color(0, 0, 0, 0.5), 1), Rect2(0, 0, w, h))
		var half := w * 0.5
		var frac := clampf(absf(meter.value) / maxf(0.0001, meter.max_edge), 0.0, 1.0)
		var len_px := half * frac
		if len_px >= 1.0:
			if meter.value > 0.0:
				draw_style_box(UI.box(UI.ACCENT, 10), Rect2(half, 0, len_px, h))
			else:
				draw_style_box(UI.box(UI.CORAL, 10), Rect2(half - len_px, 0, len_px, h))
		draw_line(Vector2(half, -3), Vector2(half, h + 3), UI.TEXT, 2.0)    # the centre notch


func _init(p_value: float = 0.0, p_max_edge: float = 0.20, p_tut_id: String = "") -> void:
	value = p_value
	max_edge = p_max_edge
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", 16)
	_bar = _Bar.new()
	_bar.meter = self
	add_child(_bar)
	_text = UI.num_label("", UI.S_BODY, UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_text.custom_minimum_size = Vector2(132, 0)
	_text.size_flags_horizontal = Control.SIZE_SHRINK_END
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_text)
	CompKit.mark_stateful(self)
	CompKit.tag(self, p_tut_id)
	_apply()


func set_value(v: float) -> void:
	if is_equal_approx(v, value):
		return
	value = v
	applied += 1
	_apply()


func value_text() -> String:
	return _text.text


func is_zero() -> bool:
	return absf(value) < 0.0005


func state_name() -> String:
	return "zero" if is_zero() else ("you" if value > 0.0 else "them")


func _apply() -> void:
	_text.text = "0.0%" if is_zero() else UI.pct(value, 1)
	_text.add_theme_color_override("font_color", UI.TEXT if is_zero() else UI.delta_color(value))
	CompKit.set_cue(self, "sign+side" if not is_zero() else "zero")
	_bar.queue_redraw()
