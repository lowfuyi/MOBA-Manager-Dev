extends Node
## Spike S2 (build plan I-01, TUTORIAL B11): a tap inside the coach overlay's hole reaches a button inside a sheet
## on a lower CanvasLayer, with the other dim panels blocking. Scratch CanvasLayer pair until I-08 gives a real sheet.
## Run with touch emulation like the existing touch scenes (see spike_nested_scroll.gd).


func _ready() -> void:
	await get_tree().process_frame
	var m = load("res://tests/spikes/s2_measure.gd").new(self)
	var rows: Array = await m.run()
	for r in rows:
		print("S2|%s|%s|%s" % ["OK  " if r["ok"] else "FAIL", r["name"], r["detail"]])
	get_tree().quit(0)
