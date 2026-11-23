extends SceneTree
## iPhone launch images for the web playtest when opened from the Home Screen (0.12, Q2): the dusk page colour with the
## game's motif (teal circle, coral hexagon) in the middle, at the four common iPhone sizes. Written straight into the web
## build folder by tools/build_web.sh (never committed, never in the APK).
##   $GODOT --headless --path game --script "$PWD/tools/gen_pwa_splash.gd" -- <out dir>

const SIZES := [[1179, 2556], [1290, 2796], [1170, 2532], [750, 1334]]
const BG_TOP := Color("14284a")
const BG_BOT := Color("0a1120")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else "."
	var motif := _motif(384)
	for sz in SIZES:
		var w: int = sz[0]
		var h: int = sz[1]
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			img.fill_rect(Rect2i(0, y, w, 1), BG_TOP.lerp(BG_BOT, clampf(float(y) / (0.6 * h), 0.0, 1.0)))
		var m := motif.duplicate() as Image
		var side := int(w * 0.36)
		m.resize(side, side, Image.INTERPOLATE_LANCZOS)
		img.blend_rect(m, Rect2i(0, 0, side, side), Vector2i((w - side) / 2, int(h * 0.42) - side / 2))
		img.save_png("%s/splash_%dx%d.png" % [out, w, h])
		print("splash ", w, "x", h)
	quit()


## The motif alone on a transparent ground, 4x4 supersampled (the same shapes as the home-screen icon).
static func _motif(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var teal := Color("3fd0b8")
	var coral := Color("ff8a5c")
	for y in n:
		for x in n:
			var acc := Color(0, 0, 0, 0)
			for sy in 4:
				for sx in 4:
					var p := Vector2((float(x) + (float(sx) + 0.5) / 4.0) / n, (float(y) + (float(sy) + 0.5) / 4.0) / n)
					var c := Color(0, 0, 0, 0)
					if _hex(Vector2(p.x - 0.62, p.y - 0.40).rotated(PI / 6.0), 0.25) < 0.0:
						c = coral
					var dc := p.distance_to(Vector2(0.40, 0.60))
					if dc < 0.25:
						c = Color("0a1120").lerp(teal, 0.25) if dc < 0.17 else teal
					acc += c
			img.set_pixel(x, y, acc / 16.0)
	return img


static func _hex(p: Vector2, r: float) -> float:
	var q := Vector2(absf(p.x), absf(p.y))
	var k := Vector3(-0.866025404, 0.5, 0.577350269)
	var qq := q
	var d := minf(k.x * qq.x + k.y * qq.y, 0.0)
	qq -= 2.0 * d * Vector2(k.x, k.y)
	qq -= Vector2(clampf(qq.x, -k.z * r * 0.866, k.z * r * 0.866), r * 0.866)
	return qq.length() * signf(qq.y)
