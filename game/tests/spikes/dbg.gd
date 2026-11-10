extends Node
func _ready() -> void:
	await get_tree().process_frame
	var m = load("res://tests/spikes/s1_measure.gd").new(self)
	var rig = await m.make_rig("locked")
	rig.page.scroll_vertical = 360
	rig.carousel.set_h_offset(300.0)
	await m.sim.frames(3)
	var start = rig.carousel.get_global_rect().get_center()
	print("start ", start, " carousel rect ", rig.carousel.get_global_rect())
	rig.carousel.dbg = true
	await m.sim.swipe_angle(start, 60.0, 240.0, true, true)
	print(rig.carousel.decisions, " ", rig.page.scroll_vertical, " ", rig.carousel.h_offset())
	get_tree().quit()
