extends RefCounted
## S1 measurement: five swipe angles, both directions, starting on the middle of the carousel, against a carousel
## of mode "naive" or "locked". Returns an Array of row Dictionaries. Shared by spike_nested_scroll.gd (prints the
## table) and check_gestures.gd (asserts the locked rows).
const ANGLES := [0.0, 20.0, 40.0, 60.0, 90.0]     # degrees from the vertical axis; under 45 is a vertical swipe
const DIST := 240.0

var owner_node: Node
var sim


func _init(n: Node) -> void:
	owner_node = n
	sim = load("res://tests/spikes/touch_sim.gd").new(n)


func make_rig(mode: String) -> Control:
	var rig: Control = load("res://tests/spikes/nested_rig.gd").new()
	owner_node.add_child(rig)
	rig.build(mode)
	await sim.frames(3)
	return rig


func swipe_rows(mode: String) -> Array:
	var rig: Control = await make_rig(mode)
	var rows: Array = []
	for dir_up in [true, false]:
		for deg in ANGLES:
			rig.page.scroll_vertical = 360
			rig.carousel.set_h_offset(300.0)
			await sim.frames(3)
			var p0: int = rig.page.scroll_vertical
			var c0: float = rig.carousel.h_offset()
			var start: Vector2 = rig.carousel.get_global_rect().get_center()
			await sim.swipe_angle(start, deg, DIST, dir_up, dir_up)
			await sim.frames(10)                          # let any inertia finish
			var dy_exp: float = absf(cos(deg_to_rad(deg))) * DIST
			var dx_exp: float = absf(sin(deg_to_rad(deg))) * DIST
			rows.append({"mode": mode, "deg": deg, "dir": "up-left" if dir_up else "down-right",
					"page_moved": absf(float(rig.page.scroll_vertical - p0)),
					"car_moved": absf(rig.carousel.h_offset() - c0),
					"dy_exp": dy_exp, "dx_exp": dx_exp, "vertical": deg < 45.0})
	rig.queue_free()
	await sim.frames(2)
	return rows


## Pass rule for one row: a vertical swipe moves the page by at least half of its vertical travel and the carousel
## by no more than 2 px; a horizontal swipe moves the carousel by at least half of its horizontal travel and the
## page by no more than 3 px.
func row_ok(r: Dictionary) -> bool:
	if r["vertical"]:
		return r["page_moved"] >= 0.5 * r["dy_exp"] and r["car_moved"] <= 2.0
	return r["car_moved"] >= 0.5 * r["dx_exp"] and r["page_moved"] <= 3.0


func row_text(r: Dictionary) -> String:
	return "%-6s %2d deg %-10s page_moved=%5.1f (swipe dy %5.1f)  carousel_moved=%5.1f (swipe dx %5.1f)  expect=%s -> %s" % [
			r["mode"], int(r["deg"]), r["dir"], r["page_moved"], r["dy_exp"], r["car_moved"], r["dx_exp"],
			"page" if r["vertical"] else "carousel", "OK" if row_ok(r) else "FAIL"]


## Tap rules on the locked carousel: a plain tap, a tap with 6 px of finger jitter, and (not taps) a horizontal and
## a vertical swipe that start on a card. Returns {tap, jitter_tap, h_swipe, v_swipe} = list of pressed card ids.
func tap_rows(mode: String) -> Dictionary:
	var rig: Control = await make_rig(mode)
	var out := {}
	rig.page.scroll_vertical = 360
	rig.carousel.set_h_offset(0.0)
	await sim.frames(3)
	var card: Button = rig.carousel.cards[1]
	var c: Vector2 = card.get_global_rect().get_center()
	rig.carousel.log_pressed.clear()
	await sim.tap(c)
	out["tap"] = rig.carousel.log_pressed.duplicate()
	rig.carousel.log_pressed.clear()
	sim.finger("down", c)
	await sim.frames(1)
	sim.finger("move", c + Vector2(4, 3), Vector2(4, 3))
	await sim.frames(1)
	sim.finger("move", c + Vector2(6, 0), Vector2(2, -3))
	await sim.frames(1)
	sim.finger("up", c + Vector2(6, 0))
	await sim.frames(3)
	out["jitter_tap"] = rig.carousel.log_pressed.duplicate()
	rig.carousel.log_pressed.clear()
	await sim.swipe_angle(c, 90.0, 160.0, true, true)
	await sim.frames(8)
	out["h_swipe"] = rig.carousel.log_pressed.duplicate()
	rig.carousel.set_h_offset(0.0)
	rig.carousel.log_pressed.clear()
	await sim.frames(2)
	await sim.swipe_angle(c, 0.0, 120.0, true, true)
	await sim.frames(8)
	out["v_swipe"] = rig.carousel.log_pressed.duplicate()
	rig.queue_free()
	await sim.frames(2)
	return out
