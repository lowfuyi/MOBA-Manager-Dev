extends Node
## Spike S1 (build plan I-01): nested horizontal carousel inside the vertical page, five swipe angles, naive
## ScrollContainer against the direction lock. Prints the table; the permanent assertions are in check_gestures.gd.
## Run (needs touch emulation, as the existing touch scenes):
##   printf '[input_devices]\n\npointing/emulate_touch_from_mouse=true\n' > override.cfg
##   godot --headless res://tests/spikes/spike_nested_scroll.tscn ; rm override.cfg


func _ready() -> void:
	await get_tree().process_frame
	print("touchscreen available: ", DisplayServer.is_touchscreen_available())
	var m = load("res://tests/spikes/s1_measure.gd").new(self)
	for mode in ["naive", "locked"]:
		var rows: Array = await m.swipe_rows(mode)
		for r in rows:
			print("S1|", m.row_text(r))
		var taps: Dictionary = await m.tap_rows(mode)
		print("S1|%s taps: %s" % [mode, str(taps)])
	get_tree().quit(0)
