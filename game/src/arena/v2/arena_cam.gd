class_name ArenaCam
extends RefCounted
## The Arena v2 camera (MATCH-SIM-V2-DESIGN 11.4): a tilted pinhole camera over the ground plane, no 3D. One projection is
## shared by the ground shader (as uniforms) and by GDScript (sprites, bars, labels), so sprites sit exactly on the ground.
## Ground frame: canonical map point (x 0..1 west to east, y 0..1 north to south) -> ground units G = ((x - 0.5) * XS, y - 0.5)
## with XS the map's x scale; the player's base is always at the bottom: when the player is Red the map is mirrored in y
## (never rotated). The camera looks north, pitched `pitch` degrees below the horizon, from `dist` units, focal length from
## the vertical field of view. Presentation only (rule A1): nothing here reads or changes the result.

var pitch_deg := 56.0
var fov_deg := 30.0
var dist := 1.05               # distance from the focus point (ground units); smaller = closer
var focus := Vector2(0.5, 0.8) # canonical point the camera looks at
var flip := false              # the player is Red: mirror y
var view := Vector2(720, 760)  # the arena's size on screen (px)
var xs := 0.9474
# derived each update()
var _c := Vector3.ZERO
var _f := Vector3.ZERO
var _u := Vector3.ZERO
var _r := Vector3(1, 0, 0)
var _focal := 1.0


func update() -> void:
	var ph := deg_to_rad(pitch_deg)
	var g := ground(focus)
	# world: X east, Y up, Z south; ground is Y = 0
	_f = Vector3(0.0, -sin(ph), -cos(ph))
	_u = Vector3(0.0, cos(ph), -sin(ph))
	_r = Vector3(1.0, 0.0, 0.0)
	_c = Vector3(g.x, 0.0, g.y) - _f * dist
	_focal = (view.y * 0.5) / tan(deg_to_rad(fov_deg) * 0.5)


## Canonical map point -> ground units (mirrored for a Red player).
func ground(p: Vector2) -> Vector2:
	var y := 1.0 - p.y if flip else p.y
	return Vector2((p.x - 0.5) * xs, y - 0.5)


## Ground units -> canonical map point (inverse of ground()).
func canon(g: Vector2) -> Vector2:
	var y := g.y + 0.5
	return Vector2(g.x / xs + 0.5, 1.0 - y if flip else y)


## Canonical point -> screen px (and depth in units; depth <= 0 means behind the camera). Returns Vector3(sx, sy, depth).
func project(p: Vector2, height: float = 0.0) -> Vector3:
	var g := ground(p)
	var v := Vector3(g.x, height, g.y) - _c
	var z := v.dot(_f)
	if z <= 0.0001:
		return Vector3(-9999, -9999, z)
	var x := v.dot(_r)
	var y := v.dot(_u)
	return Vector3(view.x * 0.5 + _focal * x / z, view.y * 0.5 - _focal * y / z, z)


## Screen px -> canonical point on the ground (the shader does the same per pixel). null-safe: returns (-1, -1) above the horizon.
func unproject(s: Vector2) -> Vector2:
	var d := _f + _r * ((s.x - view.x * 0.5) / _focal) + _u * (-(s.y - view.y * 0.5) / _focal)
	if d.y >= -0.000001:
		return Vector2(-1, -1)
	var t := -_c.y / d.y
	var w := _c + d * t
	return canon(Vector2(w.x, w.z))


## Screen scale of one ground unit at a canonical point (sprites and bars are sized by it).
func scale_at(p: Vector2) -> float:
	var z := project(p).z
	return _focal / maxf(0.0001, z)


## Uniforms for the ground shader (arena_ground.gdshader).
func uniforms() -> Dictionary:
	return {"cam_c": _c, "cam_f": _f, "cam_u": _u, "cam_r": _r, "focal": _focal, "view": view, "xs": xs, "flip": 1.0 if flip else 0.0}


## Keep the focus so the view stays over the island (no empty fog beyond the far edge when zoomed out).
func clamp_focus() -> void:
	focus.x = clampf(focus.x, 0.22, 0.78)
	var lo := 0.18
	var hi := 0.86
	focus.y = clampf(focus.y, lo, hi)
