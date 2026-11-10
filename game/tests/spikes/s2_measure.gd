extends RefCounted
## S2 measurement: tap through the coach overlay's hole to a button inside a sheet on a lower layer, with the dim
## panels around it blocking. Returns Array of {name, ok, detail}. Shared by spike_hole_tap.gd and check_gestures.gd.
var owner_node: Node
var sim


func _init(n: Node) -> void:
	owner_node = n
	sim = load("res://tests/spikes/touch_sim.gd").new(n)


func run() -> Array:
	var out: Array = []
	var rig: Control = load("res://tests/spikes/hole_rig.gd").new()
	owner_node.add_child(rig)
	rig.build()
	await sim.frames(3)
	var c: Vector2 = rig.sheet_btn.get_global_rect().get_center()
	# 0. control: with the dim panels hidden the same taps DO leak (scrim and sheet panel react), so the swallow checks below
	# cannot pass by accident
	for d in rig.dims:
		d.visible = false
	await sim.frames(2)
	await sim.tap(Vector2(360, 300))
	await sim.tap(Vector2(360, 700))
	out.append(_row("control: without the dim panels, taps reach the scrim and the sheet panel", rig.scrim_taps == 1 and rig.sheet_panel_taps == 1, str(rig.counters())))
	for d in rig.dims:
		d.visible = true
	rig.scrim_taps = 0
	rig.sheet_panel_taps = 0
	await sim.frames(2)
	# 1. a tap in the middle of the hole reaches the sheet button; nothing else reacts
	await sim.tap(c)
	out.append(_row("tap in the hole presses the sheet button", rig.counters() == [1, 0, 0, 0, 0], str(rig.counters())))
	# 2. a tap on each dim panel is swallowed: no counter moves
	var before: Array = rig.counters().duplicate()
	var probes := {"top": Vector2(360, 300), "bottom": Vector2(360, 1270), "left": Vector2(20, 1168),
			"right": Vector2(712, 1168), "over the scrim": Vector2(360, 100), "over the page button": Vector2(200, 1148)}
	for k in probes:
		await sim.tap(probes[k])
	out.append(_row("taps on the four dim panels (and over the scrim and the page button) are swallowed",
			rig.counters() == before, "%s -> %s" % [str(before), str(rig.counters())]))
	# 3. precision at the hole edge: the first pixel inside is a hit, the first pixel outside is a dim panel
	var h: Rect2 = rig.hole
	before = rig.counters().duplicate()
	await sim.tap(h.position + Vector2(12, 12))           # inside the hole, on the button (the hole is the button grown by 8)
	var after_in: Array = rig.counters().duplicate()
	await sim.tap(h.position + Vector2(-2, 20))           # 2 px outside to the left
	var after_out: Array = rig.counters().duplicate()
	out.append(_row("edge: inside the hole presses, 2 px outside is swallowed",
			after_in[0] == before[0] + 1 and after_out == after_in, "%s %s %s" % [str(before), str(after_in), str(after_out)]))
	# 4. a tap in the hole margin (hole is 8 px bigger than the button): reaches the sheet panel under it, not the scrim
	before = rig.counters().duplicate()
	await sim.tap(Vector2(h.position.x + 3, h.position.y + 3))
	out.append(_row("tap in the 8 px margin of the hole reaches the sheet panel, not the scrim",
			rig.sheet_panel_taps == before[4] + 1 and rig.scrim_taps == before[3], str(rig.counters())))
	# 5. info step: the blocker over the hole makes the same tap do nothing
	rig.blocker.visible = true
	before = rig.counters().duplicate()
	await sim.tap(c)
	out.append(_row("info step: the blocker over the hole swallows the tap", rig.counters() == before, str(rig.counters())))
	rig.blocker.visible = false
	# 6. the hole moves to another target on the same sheet: the new target is live, the old one is now blocked
	rig.set_hole(rig.sheet_btn2.get_rect().grow(8))
	await sim.frames(2)
	before = rig.counters().duplicate()
	await sim.tap(rig.sheet_btn2.get_global_rect().get_center())
	await sim.tap(c)
	out.append(_row("hole follows to a second target: it presses, the old target is blocked",
			rig.sheet_btn2_taps == 1 and rig.sheet_btn_taps == before[0], str(rig.counters())))
	# 7. a swipe that starts inside the hole must not press the button (it is a drag, not a tap)
	rig.set_hole(rig.sheet_btn.get_rect().grow(8))
	await sim.frames(2)
	before = rig.counters().duplicate()
	await sim.drag(c, Vector2(0, -90), 6)
	out.append(_row("a drag that starts in the hole and leaves it does not press the button", rig.sheet_btn_taps == before[0], str(rig.counters())))
	rig.queue_free()
	await sim.frames(2)
	return out


func _row(n: String, ok: bool, detail: String) -> Dictionary:
	return {"name": n, "ok": ok, "detail": detail}
