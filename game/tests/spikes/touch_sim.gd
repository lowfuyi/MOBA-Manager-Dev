extends RefCounted
## Simulated finger for the gesture spikes and checks (build plan I-01). Sends the events a phone sends: the
## touch / drag event itself plus the emulated mouse event next to it (buttons react to the mouse one, scroll
## containers to the touch one), the same way tests/ui_touch.gd does. Needs `pointing/emulate_touch_from_mouse`
## (override.cfg) only so that DisplayServer.is_touchscreen_available() is true and ScrollContainer takes drags.
##
## Usage: var sim = load("res://tests/spikes/touch_sim.gd").new(self)   # self = any node in the tree

var node: Node
var vp: Viewport
var emit_touch := true      # send the touch / drag events
var emit_mouse := true      # send the emulated mouse events


func _init(n: Node) -> void:
	node = n
	vp = n.get_viewport()


func frames(n: int = 2) -> void:
	for i in n:
		await node.get_tree().process_frame


func finger(kind: String, pos: Vector2, rel: Vector2 = Vector2.ZERO) -> void:
	match kind:
		"down":
			var t := InputEventScreenTouch.new()
			t.index = 0
			t.position = pos
			t.pressed = true
			if emit_touch:
				vp.push_input(t, true)
			var m := InputEventMouseButton.new()
			m.button_index = MOUSE_BUTTON_LEFT
			m.pressed = true
			m.position = pos
			m.global_position = pos
			m.button_mask = MOUSE_BUTTON_MASK_LEFT
			if emit_mouse:
				vp.push_input(m, true)
		"move":
			var d := InputEventScreenDrag.new()
			d.index = 0
			d.position = pos
			d.relative = rel
			if emit_touch:
				vp.push_input(d, true)
			var mm := InputEventMouseMotion.new()
			mm.position = pos
			mm.global_position = pos
			mm.relative = rel
			mm.button_mask = MOUSE_BUTTON_MASK_LEFT
			if emit_mouse:
				vp.push_input(mm, true)
		"up":
			var t2 := InputEventScreenTouch.new()
			t2.index = 0
			t2.position = pos
			t2.pressed = false
			if emit_touch:
				vp.push_input(t2, true)
			var m2 := InputEventMouseButton.new()
			m2.button_index = MOUSE_BUTTON_LEFT
			m2.pressed = false
			m2.position = pos
			m2.global_position = pos
			if emit_mouse:
				vp.push_input(m2, true)


## One drag of `delta` (total travel) from `from`, in `steps` equal moves, one frame per move, then lift.
func drag(from: Vector2, delta: Vector2, steps: int = 12) -> void:
	finger("down", from)
	await frames(1)
	var pos := from
	var step := delta / float(steps)
	for i in steps:
		pos += step
		finger("move", pos, step)
		await frames(1)
	finger("up", pos)
	await frames(3)


## A drag whose direction makes `deg` degrees with the vertical axis (0 = straight up, 90 = straight left),
## `dist` px long. `up` false swipes downward, `left` false swipes to the right.
func swipe_angle(from: Vector2, deg: float, dist: float, up: bool = true, left: bool = true) -> void:
	var dy := cos(deg_to_rad(deg)) * dist * (-1.0 if up else 1.0)
	var dx := sin(deg_to_rad(deg)) * dist * (-1.0 if left else 1.0)
	await drag(from, Vector2(dx, dy))


func tap(p: Vector2) -> void:
	finger("down", p)
	await frames(1)
	finger("up", p)
	await frames(3)
