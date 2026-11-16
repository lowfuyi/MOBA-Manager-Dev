class_name TouchTrack
extends RefCounted
## One finger, one gesture, from whichever event family arrives (build plan I-08; the rule is the S1 finding, SPIKE-RESULTS-0.7).
## A phone sends a touch event and, next to it, the mouse event it emulates; a desktop sends only mouse events. A control that
## reads both would count a drag twice, so this reads ONE family per gesture: the touch events when a touch started it, the
## mouse events when a mouse press did. Feed it every event a control gets in `_gui_input`; it answers what happened:
##   "down"        a finger or the left mouse button went down (press_pos is set)
##   "move"        the finger or mouse moved while down (pos and rel are set)
##   "up"          it came up (pos is the last position)
##   "dup_motion"  the emulated mouse motion of a touch drag: a control that owns the drag swallows it (accept_event), because
##                 swallowing only the touch drag lets a parent ScrollContainer scroll from the mouse motion (S1)
##   ""            nothing for this gesture (a second finger, a duplicate press or release, a wheel, a right button)
## Positions are in the receiving control's coordinates, as given by the engine. `travel()` is the distance from the press in
## screen pixels: a release within SLOP of the press is a tap, past it a drag (the 12 px tap slop of the plan).

const SLOP := 12.0

var active := false
var via_touch := false
var press_pos := Vector2.ZERO
var pos := Vector2.ZERO
var rel := Vector2.ZERO


func reset() -> void:
	active = false
	via_touch = false
	rel = Vector2.ZERO


func travel() -> float:
	return pos.distance_to(press_pos)


func feed(e: InputEvent) -> String:
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.index != 0:
			return ""
		if st.pressed:
			if active:
				if not via_touch:    # the mouse press came first: from here the touch events drive the gesture
					via_touch = true
					pos = st.position
				return ""
			active = true
			via_touch = true
			press_pos = st.position
			pos = st.position
			rel = Vector2.ZERO
			return "down"
		if active and via_touch:
			pos = st.position
			active = false
			return "up"
		return ""
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return ""
		if mb.pressed:
			if active:
				return ""    # the emulated press of a touch that already started the gesture
			active = true
			via_touch = false
			press_pos = mb.position
			pos = mb.position
			rel = Vector2.ZERO
			return "down"
		if active and not via_touch:
			pos = mb.position
			active = false
			return "up"
		return ""
	if e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		if sd.index == 0 and active and via_touch:
			pos = sd.position
			rel = sd.relative
			return "move"
		return ""
	if e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if not active:
			return ""
		if via_touch:
			return "dup_motion"
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			pos = mm.position
			rel = mm.relative
			return "move"
	return ""
