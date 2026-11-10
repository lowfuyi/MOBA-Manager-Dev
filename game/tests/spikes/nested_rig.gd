extends Control
## Test rig for S1: a vertical page (ScrollContainer) holding filler, one carousel and more filler, filling the
## 720 x 1280 window. The carousel sits at about y = 500 so swipes in every direction have room.
var page: ScrollContainer
var carousel: Control


func build(mode: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page = ScrollContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(page)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 720
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	page.add_child(v)
	var top := Panel.new()
	top.custom_minimum_size = Vector2(0, 500)
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(top)
	carousel = load("res://tests/spikes/spike_carousel.gd").new()
	carousel.setup(mode, 8, 200)
	v.add_child(carousel)
	var bottom := Panel.new()
	bottom.custom_minimum_size = Vector2(0, 2200)
	bottom.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(bottom)
