class_name ArenaVision
extends RefCounted
## What one team sees at game time t (Founder decision 2026-11-22, views Field and Action). Display only: built from the event
## log's positions through ArenaPlayer, never from the simulator, and nothing here feeds a result (rules A1 and R7).
## Sources (radii in data/arena_view_v1.json "vision"): the team's living heroes, its minion waves at each lane front (from
## 0:45), its standing towers and Cairn, and its wards (a "ward" event at the warder's position, for vision_ward_s seconds).
##   sources(t)        [[canonical point, radius in ground units], ...]
##   sees(p, t)        is canonical point p inside any source
##   mask(t)           an LA8 Image over the ground texture (same margin as ArenaGround): black, alpha 0 where seen and
##                     HIDDEN_A in fog, so the ground shader and the minimap read the same texture

const HIDDEN_A := 160

var player: ArenaPlayer
var side := "B"
var radii: Dictionary = {}
var cells := 64
var wards: Array = []          # [t0, t1, canonical point]
var xs := 0.9474
var _src_t := -1.0
var _src: Array = []


static func cfg() -> Dictionary:
	return DataLoader.load_json("res://data/arena_view_v1.json")


static func build(p_player: ArenaPlayer, p_side: String, p_cfg: Dictionary = {}) -> ArenaVision:
	var v := ArenaVision.new()
	var c := p_cfg if not p_cfg.is_empty() else cfg()
	v.player = p_player
	v.side = p_side
	v.radii = c["vision"]
	v.cells = int(c["mask"]["cells"])
	v.xs = float(SimData.map()["x_scale"])
	var dur := float(SimData.params().get("vision_ward_s", 90.0))
	for e in p_player.log["ev"]:
		if String(e[1]) == "ward" and ArenaPlayer.side_of(String(e[2])) == p_side:
			var t0 := float(e[0])
			v.wards.append([t0, t0 + dur, p_player.pos(String(e[2]), t0)])
	return v


func sources(t: float) -> Array:
	if absf(t - _src_t) < 1e-6:
		return _src
	var out: Array = []
	for s in ArenaPlayer.SLOTS:
		var key: String = side + "." + s
		if player.alive(key, t):
			out.append([player.pos(key, t), float(radii["hero"])])
	if t >= 45.0:
		var sgn := -1.0 if side == "B" else 1.0
		for lane in ["top", "mid", "bot"]:
			out.append([SimData.lane_point(lane, clampf(player.front(lane, t) + sgn * 0.02, 0.0, 1.0)), float(radii["minion"])])
	var down := player.towers_down(t)
	for tw in SimData.map()["towers"]:
		if String(tw["side"]) == side and not down.has(String(tw["id"])):
			out.append([tw["pos"], float(radii["tower"])])
	if not down.has(side + ".cairn"):
		out.append([SimData.map()["cairn"][side], float(radii["cairn"])])
	for w in wards:
		if float(w[0]) <= t and t < float(w[1]):
			out.append([w[2], float(radii["ward"])])
	_src_t = t
	_src = out
	return out


## Distance in ground units between two canonical points.
func _d2(a: Vector2, b: Vector2) -> float:
	var dx := (a.x - b.x) * xs
	var dy := a.y - b.y
	return dx * dx + dy * dy


func sees(p: Vector2, t: float) -> bool:
	for s in sources(t):
		var r := float(s[1])
		if _d2(p, s[0]) <= r * r:
			return true
	return false


## The fog mask over the ground texture: cell (i, j) covers canonical x in [(i / n) * (1 + 2m) - m, ...], the same mapping as
## the ground shader's tuv. Each source fills only the cells of its bounding box.
func mask(t: float) -> Image:
	var n := cells
	var m := ArenaGround.MARGIN
	var span := 1.0 + 2.0 * m
	var data := PackedByteArray()
	data.resize(n * n * 2)
	for k in n * n:
		data[k * 2 + 1] = HIDDEN_A
	var edge := 1.25 * span / float(n)    # a soft rim about one cell wide, so the linear filter shows no steps
	for s in sources(t):
		var c: Vector2 = s[0]
		var r := float(s[1])
		var inner := maxf(0.0, r - edge)
		var rx := r / xs
		var i0 := maxi(0, int(floor((c.x - rx + m) / span * n)))
		var i1 := mini(n - 1, int(ceil((c.x + rx + m) / span * n)))
		var j0 := maxi(0, int(floor((c.y - r + m) / span * n)))
		var j1 := mini(n - 1, int(ceil((c.y + r + m) / span * n)))
		for j in range(j0, j1 + 1):
			var py := (float(j) + 0.5) / n * span - m
			for i in range(i0, i1 + 1):
				var px := (float(i) + 0.5) / n * span - m
				var d2 := _d2(Vector2(px, py), c)
				if d2 > r * r:
					continue
				var k := (j * n + i) * 2 + 1
				var a := 0 if d2 <= inner * inner else int(round(HIDDEN_A * clampf((sqrt(d2) - inner) / (r - inner), 0.0, 1.0)))
				if a < data[k]:
					data[k] = a
	return Image.create_from_data(n, n, false, Image.FORMAT_LA8, data)
