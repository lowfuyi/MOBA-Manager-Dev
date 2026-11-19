class_name ArenaView
extends Control
## The Arena v2 view (MATCH-SIM-V2-DESIGN 11.4): the tilted ground (one quad through arena_ground.gdshader over the baked
## ArenaGround texture), the upright sprites (one atlas, ArenaAtlas, drawn from one canvas item and sorted far to near), the
## labels in screen space, and the corner minimap. The camera follows ArenaPlayer.focus with easing. show(t) draws game time t.
## Presentation only (rule A1): reads an ArenaPlayer, never the simulator.

const MINI := Vector2(168, 177)
const HERO_H := 0.040          # an upright hero, ground units
const TOWER_H := 0.075
const CAIRN_H := 0.095
const TREE_H := 0.060
const ROCK_H := 0.022
const BAR_W := 0.034
const EASE := 2.6              # camera easing per second (higher = snappier)
const ZOOM_FAR := 1.45
const ZOOM_NEAR := 0.95

var player: ArenaPlayer
var cam := ArenaCam.new()
var my_side := "B"
var t := 0.0
var colour_you := UI.ACCENT
var colour_them := UI.CORAL
var reduced_motion := false
var _ground_vp: SubViewport
var _atlas_vp: SubViewport
var _ground: ColorRect
var _sprites: _Sprites
var _labels: _Labels
var _mini: _Mini
var _scenery: Array = []
var _cam_focus := Vector2(0.5, 0.8)
var _cam_zoom := 0.3
var _last_t := -1.0
var _font: Font


func _init(p_player: ArenaPlayer, p_my_side: String) -> void:
	player = p_player
	my_side = p_my_side
	cam.flip = p_my_side == "R"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground_vp = ArenaGround.make_viewport()
	add_child(_ground_vp)
	_atlas_vp = ArenaAtlas.make_viewport()
	add_child(_atlas_vp)
	_ground = ColorRect.new()
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/arena/v2/arena_ground.gdshader")
	mat.set_shader_parameter("ground_tex", _ground_vp.get_texture())
	mat.set_shader_parameter("margin", ArenaGround.MARGIN)
	_ground.material = mat
	add_child(_ground)
	_sprites = _Sprites.new()
	_sprites.view = self
	add_child(_sprites)
	_labels = _Labels.new()
	_labels.view = self
	add_child(_labels)
	_mini = _Mini.new()
	_mini.view = self
	add_child(_mini)
	_scenery = ArenaGround.scenery()
	_cam_focus = SimData.map()["cairn"][my_side]
	resized.connect(_layout)


func _ready() -> void:
	_font = get_theme_default_font()
	_layout()


func atlas() -> Texture2D:
	return _atlas_vp.get_texture()


func ground_texture() -> Texture2D:
	return _ground_vp.get_texture()


func _layout() -> void:
	_ground.position = Vector2.ZERO
	_ground.size = size
	_sprites.size = size
	_labels.size = size
	_mini.position = Vector2(size.x - MINI.x - 12.0, 12.0)
	_mini.size = MINI
	cam.view = size
	cam.update()


## Draw game time `game_t`. A jump of more than 4 s (Skip, the start) moves the camera at once; otherwise it eases.
func show_game(game_t: float) -> void:
	t = game_t
	var f := player.focus(t)
	var want: Vector2 = f[0]
	var want_zoom := float(f[1])
	var dt := clampf(t - _last_t, 0.0, 1.0) if _last_t >= 0.0 else 1.0
	if _last_t < 0.0 or absf(t - _last_t) > 4.0 or reduced_motion:
		_cam_focus = want
		_cam_zoom = want_zoom if not reduced_motion else 0.3
	else:
		var k := 1.0 - exp(-EASE * dt * 0.5)
		_cam_focus = _cam_focus.lerp(want, k)
		_cam_zoom = lerpf(_cam_zoom, want_zoom, k * 0.7)
	_last_t = t
	cam.focus = _cam_focus + Vector2(0.0, 0.05 * (-1.0 if cam.flip else 1.0) * 0.0)
	cam.dist = lerpf(ZOOM_FAR, ZOOM_NEAR, clampf(_cam_zoom, 0.0, 1.0))
	cam.clamp_focus()
	cam.update()
	var u := cam.uniforms()
	var mat := _ground.material as ShaderMaterial
	for k2 in u:
		mat.set_shader_parameter(k2, u[k2])
	_sprites.queue_redraw()
	_labels.queue_redraw()
	_mini.queue_redraw()


func team_colour(side: String) -> Color:
	return colour_you if side == my_side else colour_them


## Screen px of a canonical point (and the scale of one ground unit there).
func px(p: Vector2) -> Vector3:
	return cam.project(p)


class _Sprites extends Control:
	var view: ArenaView

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if view == null:
			return
		var tex := view.atlas()
		var t := view.t
		var pl := view.player
		var items: Array = []    # [depth (screen y), sprite, canonical point, height units, modulate, extra]
		for s in view._scenery:
			var kind := String(s["kind"])
			if kind == "tree":
				items.append([0.0, "tree%d" % int(s["v"]), s["p"], ArenaView.TREE_H, Color(1, 1, 1), null])
			elif kind == "rock":
				items.append([0.0, "rock%d" % int(s["v"]), s["p"], ArenaView.ROCK_H, Color(1, 1, 1), null])
			else:
				items.append([0.0, "brazier", s["p"], 0.04, Color(1, 1, 1), "flame"])
		var down := pl.towers_down(t)
		for tw in SimData.map()["towers"]:
			var id := String(tw["id"])
			var col := view.team_colour(String(tw["side"]))
			if down.has(id):
				items.append([0.0, "rubble", tw["pos"], 0.035, Color(1, 1, 1), null])
			else:
				items.append([0.0, "tower", tw["pos"], ArenaView.TOWER_H, Color(1, 1, 1), ["tower_gem", col]])
		for side in ["B", "R"]:
			var cp: Vector2 = SimData.map()["cairn"][side]
			if down.has(side + ".cairn"):
				items.append([0.0, "cairn_broken", cp, 0.05, Color(1, 1, 1), null])
			else:
				items.append([0.0, "cairn", cp, ArenaView.CAIRN_H, Color(1, 1, 1), ["cairn_gem", view.team_colour(side)]])
		for oid in ["stoneback", "moonhulk", "mossback"]:
			if pl.objective(oid, t) == "up":
				var hgt := 0.09 if oid == "moonhulk" else (0.06 if oid == "stoneback" else 0.03)
				items.append([0.0, oid, SimData.map()["objectives"][oid]["pos"], hgt, Color(1, 1, 1), null])
		# minions at each lane's front once the waves walk (from 0:45)
		if t >= 45.0:
			for lane in ["top", "mid", "bot"]:
				var fr := pl.front(lane, t)
				for side in ["B", "R"]:
					var sgn := -1.0 if side == "B" else 1.0
					for k in 3:
						var s2 := clampf(fr + sgn * (0.012 + 0.012 * float(k)), 0.01, 0.99)
						var p := SimData.lane_point(lane, s2) + Vector2(0.008 * float(k - 1), 0.0)
						items.append([0.0, "minion", p, 0.022, view.team_colour(side), null])
		for side in ["B", "R"]:
			for slot in ArenaPlayer.SLOTS:
				var key: String = side + "." + slot
				if not pl.alive(key, t):
					continue
				var p2 := pl.pos(key, t)
				var arch := String(SimData.heroes()[pl.hero_of[key]]["archetype"])
				items.append([0.0, "hero_" + arch, p2, ArenaView.HERO_H, Color(1, 1, 1), ["hero", key, side]])
		for it in items:
			it[0] = view.cam.project(it[2]).y
		items.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for it in items:
			_sprite(tex, it)
		# effects on top
		for e in pl.effects(t):
			var kind2 := String(e[0])
			var age := float(e[2])
			var col2 := view.team_colour(String(e[3]))
			if kind2 == "cast":
				var at: Vector2 = e[6] if bool(e[5]) else e[1]
				_flat(tex, "bolt" if age < 0.5 else "spark", at, 0.03 * (0.8 + 0.6 * age), Color(col2, 1.0 - age))
			else:
				_flat(tex, "burst", e[1], 0.06 * (0.5 + age), Color(1, 0.85, 0.6, 0.9 * (1.0 - age)))
				_flat(tex, "skull", e[1], 0.03, Color(1, 1, 1, 1.0 - age))

	## An upright sprite standing at a canonical point, `h` ground units tall.
	func _sprite(tex: Texture2D, it: Array) -> void:
		var name := String(it[1])
		var p: Vector2 = it[2]
		var h := float(it[3])
		var pr := view.cam.project(p)
		if pr.z <= 0.0:
			return
		var sc := view.cam.scale_at(p)
		var src := ArenaAtlas.rect(name)
		var hpx := h * sc
		var wpx := hpx * src.size.x / src.size.y
		var extra = it[5]
		if extra is Array and String(extra[0]) == "hero":
			var key := String(extra[1])
			var side := String(extra[2])
			var col := view.team_colour(side)
			var ring := "ring_you" if side == view.my_side else "ring_them"
			_flat(tex, "shadow", p, 0.026, Color(1, 1, 1, 0.9))
			_flat(tex, ring, p, 0.024, col)
			draw_texture_rect_region(tex, Rect2(pr.x - wpx / 2.0, pr.y - hpx, wpx, hpx), src, Color(1, 1, 1))
			_bar(tex, Vector2(pr.x, pr.y - hpx - 6.0), sc, view.player.hp(key, view.t), col)
			return
		draw_texture_rect_region(tex, Rect2(pr.x - wpx / 2.0, pr.y - hpx, wpx, hpx), src, it[4])
		if extra is Array:
			# a tinted gem (tower lantern or the Cairn's heart-stone) with a soft team glow
			var gname := String(extra[0])
			var gcol: Color = extra[1]
			var gs := wpx * (0.32 if gname == "tower_gem" else 0.34)
			var gy := pr.y - hpx * (0.93 if gname == "tower_gem" else 0.86)
			draw_texture_rect_region(tex, Rect2(pr.x - gs * 1.4, gy - gs * 1.4, gs * 2.8, gs * 2.8), ArenaAtlas.rect("glow"), Color(gcol, 0.55))
			draw_texture_rect_region(tex, Rect2(pr.x - gs / 2.0, gy - gs / 2.0, gs, gs), ArenaAtlas.rect(gname), gcol)
		elif extra is String:
			var fs := wpx * 0.7
			draw_texture_rect_region(tex, Rect2(pr.x - fs / 2.0, pr.y - hpx - fs * 0.6, fs, fs), ArenaAtlas.rect("flame"), Color(1, 1, 1))
			draw_texture_rect_region(tex, Rect2(pr.x - fs, pr.y - hpx - fs, fs * 2.0, fs * 2.0), ArenaAtlas.rect("glow"), Color(1.0, 0.7, 0.35, 0.35))

	## A sprite lying on the ground (rings, shadows, effects), `w` ground units wide, squashed by the tilt.
	func _flat(tex: Texture2D, name: String, p: Vector2, w: float, col: Color) -> void:
		var pr := view.cam.project(p)
		if pr.z <= 0.0:
			return
		var sc := view.cam.scale_at(p)
		var wpx := w * sc
		var hpx := wpx * sin(deg_to_rad(view.cam.pitch_deg))
		draw_texture_rect_region(tex, Rect2(pr.x - wpx / 2.0, pr.y - hpx / 2.0, wpx, hpx), ArenaAtlas.rect(name), col)

	## A thin segmented health bar (dark back, team fill, a notch every quarter).
	func _bar(tex: Texture2D, at: Vector2, sc: float, hp: float, col: Color) -> void:
		var w := maxf(26.0, ArenaView.BAR_W * sc)
		var h := 5.0
		var src := ArenaAtlas.rect("bar")
		draw_texture_rect_region(tex, Rect2(at.x - w / 2.0 - 1.0, at.y - 1.0, w + 2.0, h + 2.0), src, Color(0.05, 0.06, 0.08, 0.85))
		draw_texture_rect_region(tex, Rect2(at.x - w / 2.0, at.y, w * clampf(hp, 0.0, 1.0), h), src, col)
		for k in range(1, 4):
			draw_texture_rect_region(tex, Rect2(at.x - w / 2.0 + w * float(k) / 4.0 - 0.5, at.y, 1.0, h), src, Color(0.05, 0.06, 0.08, 0.9))


class _Labels extends Control:
	var view: ArenaView

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if view == null or view._font == null:
			return
		var pl := view.player
		var t := view.t
		var shown := {}
		for n in pl.notes(t):
			var who := String(n[1])
			if who.begins_with("team.") or shown.has(who) or not pl.alive(who, t):
				continue
			var text := ArenaView.intent_word(String(n[2]))
			if text == "":
				continue
			shown[who] = true
			var p := pl.pos(who, t)
			var pr := view.cam.project(p)
			var hpx := ArenaView.HERO_H * view.cam.scale_at(p)
			var fs := UI.S_CAPTION
			var w := view._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var at := Vector2(pr.x - w / 2.0, pr.y - hpx - 16.0)
			draw_string_outline(view._font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.85))
			draw_string(view._font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, view.team_colour(String(who.substr(0, 1))).lightened(0.35))


## The short word over a hero for a notable intent (copy keys arena2.intent.*); "" for none.
static func intent_word(intent: String) -> String:
	if intent in ["gank", "roam", "back_off", "ward"]:
		return Strings.t("arena2.intent." + intent)
	return ""


class _Mini extends Control:
	var view: ArenaView

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _to(p: Vector2) -> Vector2:
		var y := 1.0 - p.y if view.cam.flip else p.y
		var m := ArenaGround.MARGIN
		return Vector2((p.x + m) / (1.0 + 2.0 * m) * size.x, (y + m) / (1.0 + 2.0 * m) * size.y)

	func _draw() -> void:
		if view == null:
			return
		draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), Color(0.02, 0.03, 0.05, 0.75))
		var gt := view.ground_texture()
		if view.cam.flip:
			# mirror in y (the player's base at the bottom): a flipped transform, never a negative-size rect
			draw_set_transform(Vector2(0, size.y), 0.0, Vector2(1, -1))
			draw_texture_rect(gt, Rect2(Vector2.ZERO, size), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(gt, Rect2(Vector2.ZERO, size), false)
		var tex := view.atlas()
		var dot := ArenaAtlas.rect("dot")
		var down := view.player.towers_down(view.t)
		for tw in SimData.map()["towers"]:
			if down.has(String(tw["id"])):
				continue
			var q := _to(tw["pos"])
			draw_texture_rect_region(tex, Rect2(q - Vector2(3, 3), Vector2(6, 6)), ArenaAtlas.rect("bar"), view.team_colour(String(tw["side"])))
		for side in ["B", "R"]:
			for slot in ArenaPlayer.SLOTS:
				var key: String = side + "." + slot
				if not view.player.alive(key, view.t):
					continue
				var q2 := _to(view.player.pos(key, view.t))
				var col := view.team_colour(side)
				if side == view.my_side:
					draw_texture_rect_region(tex, Rect2(q2 - Vector2(5, 5), Vector2(10, 10)), dot, col)
				else:
					draw_texture_rect_region(tex, Rect2(q2 - Vector2(4.5, 4.5), Vector2(9, 9)), ArenaAtlas.rect("bar"), col)
		# the camera's footprint
		var corners := [Vector2(0, 0), Vector2(view.size.x, 0), Vector2(view.size.x, view.size.y), Vector2(0, view.size.y)]
		var poly := PackedVector2Array()
		for c in corners:
			var g := view.cam.unproject(c)
			if g.x < -0.5:
				g = view.cam.unproject(Vector2(c.x, c.y + view.size.y * 0.35))
			g = Vector2(clampf(g.x, -0.05, 1.05), clampf(g.y, -0.05, 1.05))
			poly.append(_to(g))
		poly.append(poly[0])
		draw_polyline(poly, Color(1, 1, 1, 0.7), 1.5)
