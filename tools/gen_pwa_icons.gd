extends SceneTree
## Home-screen icons for the web playtest (0.11.1 web): the game's own motif, a teal circle (you) and a coral hexagon
## (them) on the dusk page colour. Drawn with signed distances, 4x4 supersampled. Original shapes, no text.
##   cd game && $GODOT --headless --script "$PWD/../tools/gen_pwa_icons.gd"     (writes assets/icon/pwa_{144,180,512}.png)

const BG_TOP := Color("162842")
const BG_BOT := Color("0a1120")
const TEAL := Color("3fd0b8")
const CORAL := Color("ff8a5c")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icon"))
	for n in [144, 180, 512]:
		var img := _draw(n)
		img.save_png("res://assets/icon/pwa_%d.png" % n)
		print("icon ", n)
	quit()


static func _hex(p: Vector2, r: float) -> float:
	# distance to a flat-sided regular hexagon of circumradius r (pointy top), negative inside
	var q := Vector2(absf(p.x), absf(p.y))
	var k := Vector3(-0.866025404, 0.5, 0.577350269)
	var qq := q
	var d := minf(k.x * qq.x + k.y * qq.y, 0.0)
	qq -= 2.0 * d * Vector2(k.x, k.y)
	qq -= Vector2(clampf(qq.x, -k.z * r * 0.866, k.z * r * 0.866), r * 0.866)
	return qq.length() * signf(qq.y)


static func _draw(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ss := 4
	for y in n:
		for x in n:
			var acc := Color(0, 0, 0, 0)
			for sy in ss:
				for sx in ss:
					var u := (float(x) + (float(sx) + 0.5) / ss) / n
					var v := (float(y) + (float(sy) + 0.5) / ss) / n
					var c := BG_TOP.lerp(BG_BOT, v)
					var p := Vector2(u, v)
					# coral hexagon behind, upper right; teal ring in front, lower left
					var dh := _hex(Vector2(p.x - 0.62, p.y - 0.40).rotated(PI / 6.0), 0.25)
					if dh < 0.0:
						c = CORAL
					var dc := p.distance_to(Vector2(0.40, 0.60))
					if dc < 0.25:
						c = BG_BOT.lerp(TEAL, 0.25) if dc < 0.17 else TEAL
					acc += c
			img.set_pixel(x, y, acc / float(ss * ss))
	return img
