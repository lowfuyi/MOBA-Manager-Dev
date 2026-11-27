class_name ArenaView
extends Control
## The Arena v2 view (MATCH-SIM-V2-DESIGN 11.4): the tilted ground (one quad through arena_ground.gdshader over the baked
## ArenaGround texture), the upright sprites (one atlas, ArenaAtlas, drawn from one canvas item and sorted far to near), the
## labels in screen space, and the corner minimap. show_game(t, real_dt) draws game time t.
## Three views (Founder decision 2026-11-22; data/arena_view_v1.json), chosen with set_mode():
##   "field"   the whole island from above, fixed (no pan, zoom or chase); fog of war: only what your team sees
##   "action"  the camera chases the action (ArenaChase: priorities, a minimum dwell, easing); fog of war; a drag pans, and
##             5 s after the last touch the camera eases back to the chase
##   "all"     the whole island, fixed, no fog
## Fog: ArenaVision's low-resolution mask on the ground quad (one texture, redrawn a few times a second); enemy heroes, minions,
## effects and labels outside your team's vision are not drawn (no extra draw calls). In Field and All the tokens, bars and
## labels are drawn bigger (overview token_scale). Presentation only (rule A1): reads an ArenaPlayer, never the simulator.

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
var mode := "action"
var vision: ArenaVision
var chase: ArenaChase
var cfg: Dictionary = {}
var token_k := 1.0
var bar_k := 1.0
var manual := false             # Action: the player dragged; the chase waits
var idle_s := 0.0               # real seconds since the last drag
var mask_updates := 0
var _fog_tex: ImageTexture
var _fog_real := 99.0
var _fog_t := -999.0
var _manual_focus := Vector2(0.5, 0.5)
var _dragging := false


func _init(p_player: ArenaPlayer, p_my_side: String) -> void:
	player = p_player
	my_side = p_my_side
	cam.flip = p_my_side == "R"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	cfg = ArenaVision.cfg()
	vision = ArenaVision.build(player, my_side, cfg)
	chase = ArenaChase.build(player, vision, cfg)
	_fog_tex = ImageTexture.create_from_image(vision.mask(0.0))
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
	mat.set_shader_parameter("fog_tex", _fog_tex)
	mat.set_shader_parameter("fog_alpha", float(ArenaVision.HIDDEN_A) / 255.0)
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


## Field, Action or All. A view change jumps the camera (no easing) and forgets the chase and any drag.
func set_mode(m: String) -> void:
	if not ["field", "action", "all"].has(m):
		m = "action"
	mode = m
	manual = false
	_dragging = false
	idle_s = 0.0
	chase.reset()
	_last_t = -1.0
	_fog_t = -999.0
	var ov: Dictionary = cfg["overview"]
	token_k = float(ov["token_scale"]) if m != "action" else 1.0
	bar_k = float(ov["bar_scale"]) if m != "action" else 1.0
	(_ground.material as ShaderMaterial).set_shader_parameter("fog_on", 0.0 if m == "all" else 1.0)
	if is_inside_tree():
		show_game(t)


func fog_on() -> bool:
	return mode != "all"


## Is a canonical point shown at game time t (always in All; in Field and Action, inside your team's vision).
func shows(p: Vector2, at_t: float = -1.0) -> bool:
	return not fog_on() or vision.sees(p, t if at_t < 0.0 else at_t)


## Draw game time `game_t`; `real_dt` is the real time since the last call (the chase's dwell, the drag's 5 s, the fog's
## refresh rate). A jump of more than 4 s (Skip, the start) moves the camera at once; otherwise it eases.
func show_game(game_t: float, real_dt: float = 0.0) -> void:
	t = game_t
	if mode == "action":
		_follow(real_dt)
	else:
		_overview()
	_last_t = t
	cam.update()
	_update_fog(real_dt)
	var u := cam.uniforms()
	var mat := _ground.material as ShaderMaterial
	for k2 in u:
		mat.set_shader_parameter(k2, u[k2])
	_sprites.queue_redraw()
	_labels.queue_redraw()
	_mini.queue_redraw()


func _follow(real_dt: float) -> void:
	var want: Vector2
	var want_zoom: float
	if manual:
		if not _dragging:
			idle_s += maxf(0.0, real_dt)
		if idle_s >= float(cfg["chase"]["return_s"]):
			manual = false
			chase.reset()
	if manual:
		want = _manual_focus
		want_zoom = _cam_zoom
	else:
		var f := chase.update(t, real_dt)
		want = f["pos"]
		want_zoom = float(f["zoom"])
	cam.pitch_deg = 56.0
	cam.fov_deg = 30.0
	var jump := _last_t < 0.0 or absf(t - _last_t) > 4.0
	if manual:
		_cam_focus = want    # a drag moves the camera with the finger
	elif jump or reduced_motion:
		_cam_focus = want
		_cam_zoom = want_zoom if not reduced_motion else 0.3
	else:
		var k := 1.0 - exp(-float(cfg["chase"]["ease"]) * maxf(real_dt, 0.0))
		_cam_focus = _cam_focus.lerp(want, k)
		_cam_zoom = lerpf(_cam_zoom, want_zoom, k * 0.7)
	cam.focus = _cam_focus
	cam.dist = lerpf(ZOOM_FAR, ZOOM_NEAR, clampf(_cam_zoom, 0.0, 1.0))
	cam.update()
	cam.clamp_focus()
	_cam_focus = cam.focus


## Field and All: the whole island, fixed. The distance is the smallest that keeps the four corners of the map inside the view.
## On a tall phone a tilted map fitted to the width leaves empty bands above and below it (0.12 Q6): the camera then looks
## more steeply down, up to overview.max_pitch, until the island fills overview.fill of the view's height.
var _ov_cache: Array = []    # [view size, flip, pitch, dist, focus]: the fit is computed once per view size (0.12)


func _overview() -> void:
	if not _ov_cache.is_empty() and _ov_cache[0] == size and _ov_cache[1] == cam.flip:
		cam.pitch_deg = float(_ov_cache[2])
		cam.fov_deg = float(cfg["overview"]["fov"])
		cam.dist = float(_ov_cache[3])
		cam.focus = _ov_cache[4]
		_cam_focus = cam.focus
		return
	var ov: Dictionary = cfg["overview"]
	var pitch := float(ov["pitch"])
	var top_pitch := float(ov.get("max_pitch", pitch))
	var want := float(ov.get("fill", 0.0))
	_fit_whole(pitch)
	while overview_fill() < want and pitch < top_pitch:
		pitch = minf(top_pitch, pitch + 2.0)
		_fit_whole(pitch)
	_ov_cache = [size, cam.flip, cam.pitch_deg, cam.dist, cam.focus]


## How much of the view's height the island takes in Field and All (0 to 1).
func overview_fill() -> float:
	cam.update()
	var top := cam.project(Vector2(0.5, 0.0 if not cam.flip else 1.0)).y
	var bot := cam.project(Vector2(0.5, 1.0 if not cam.flip else 0.0)).y
	return absf(bot - top) / maxf(1.0, size.y)


func _fit_whole(pitch: float) -> void:
	var ov: Dictionary = cfg["overview"]
	cam.pitch_deg = pitch
	cam.fov_deg = float(ov["fov"])
	cam.focus = Vector2(0.5, 0.5)
	var m := float(ov["fit_margin"])
	var corners := [Vector2(-m, -m), Vector2(1.0 + m, -m), Vector2(1.0 + m, 1.0 + m), Vector2(-m, 1.0 + m)]
	var lo := 0.5
	var hi := 6.0
	for i in 24:
		var mid := (lo + hi) * 0.5
		cam.dist = mid
		cam.update()
		var inside := true
		for c in corners:
			var pr := cam.project(c)
			if pr.z <= 0.0 or pr.x < 0.0 or pr.x > size.x or pr.y < 0.0 or pr.y > size.y:
				inside = false
				break
		if inside:
			hi = mid
		else:
			lo = mid
	cam.dist = hi
	# centre the island vertically: the far edge is drawn smaller, so move the focus until top and bottom margins match
	for j in 6:
		cam.update()
		var top := cam.project(Vector2(0.5, 0.0 if not cam.flip else 1.0)).y
		var bot := cam.project(Vector2(0.5, 1.0 if not cam.flip else 0.0)).y
		var off := ((size.y - bot) - top) * 0.5
		var g := cam.unproject(Vector2(size.x * 0.5, size.y * 0.5 - off))
		if g.x < 0.0:
			break
		cam.focus = g
	_cam_focus = cam.focus


## The fog mask, redrawn mask.hz times a real second at most (and at once after a jump).
func _update_fog(real_dt: float) -> void:
	if not fog_on():
		return
	_fog_real += maxf(0.0, real_dt)
	if _fog_real < 1.0 / float(cfg["mask"]["hz"]) and absf(t - _fog_t) < 4.0:
		return
	_fog_real = 0.0
	_fog_t = t
	_fog_tex.update(vision.mask(t))
	mask_updates += 1


func fog_texture() -> Texture2D:
	return _fog_tex


## Action: a drag pans the camera over the island; the chase waits until 5 s after the last touch.
## Match Day M6: a tap (press and release within 12 px) on a hero opens its sheet; the screen listens.
signal hero_tapped(key: String)
var _press_at := Vector2(-1, -1)


## The visible hero whose token is nearest to `at` (px of this control), within 96 px; "" if none.
func hero_at(at: Vector2) -> String:
	var best := ""
	var bd := 96.0
	for side in ["B", "R"]:
		for slot in ArenaPlayer.SLOTS:
			var key: String = side + "." + slot
			if not player.alive(key, t):
				continue
			var p := player.pos(key, t)
			if side != my_side and not shows(p):
				continue
			var pr := cam.project(p)
			var hpx := ArenaView.HERO_H * token_k * cam.scale_at(p)
			var d := Vector2(pr.x, pr.y - hpx * 0.5).distance_to(at)
			if d < bd:
				bd = d
				best = key
	return best


func _gui_input(ev: InputEvent) -> void:
	# a tap on a hero, in every view (a drag in Action is not a tap)
	if ev is InputEventScreenTouch or (ev is InputEventMouseButton and not DisplayServer.is_touchscreen_available() and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		var pr_ := (ev as InputEventScreenTouch).pressed if ev is InputEventScreenTouch else (ev as InputEventMouseButton).pressed
		var pos_: Vector2 = (ev as InputEventScreenTouch).position if ev is InputEventScreenTouch else (ev as InputEventMouseButton).position
		if pr_:
			_press_at = pos_
		elif _press_at.x >= 0.0 and _press_at.distance_to(pos_) <= 12.0:
			var key := hero_at(pos_)
			_press_at = Vector2(-1, -1)
			if key != "":
				_dragging = false
				hero_tapped.emit(key)
				accept_event()
				return
	if mode != "action":
		return
	var rel := Vector2.ZERO
	var at := Vector2.ZERO
	if ev is InputEventScreenDrag:
		rel = (ev as InputEventScreenDrag).relative
		at = (ev as InputEventScreenDrag).position
	elif ev is InputEventMouseMotion and ((ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and not DisplayServer.is_touchscreen_available():
		# a phone sends the drag and an emulated mouse move for it: only the drag counts there; a mouse counts on a desktop
		rel = (ev as InputEventMouseMotion).relative
		at = (ev as InputEventMouseMotion).position
	elif ev is InputEventScreenTouch or (ev is InputEventMouseButton and not DisplayServer.is_touchscreen_available()):
		var pressed := (ev as InputEventScreenTouch).pressed if ev is InputEventScreenTouch else (ev as InputEventMouseButton).pressed
		_dragging = pressed
		if pressed:
			idle_s = 0.0
		return
	else:
		return
	drag_by(at, rel)
	accept_event()


## Move the view so the ground point under `at - rel` comes under `at` (screen px of this control).
func drag_by(at: Vector2, rel: Vector2) -> void:
	if mode != "action" or rel == Vector2.ZERO:
		return
	var a := cam.unproject(at - rel)
	var b := cam.unproject(at)
	if a.x < -0.5 or b.x < -0.5:
		return
	if not manual:
		_manual_focus = _cam_focus
	manual = true
	idle_s = 0.0
	_manual_focus = Vector2(clampf(_manual_focus.x + (a.x - b.x), 0.22, 0.78), clampf(_manual_focus.y + (a.y - b.y), 0.18, 0.86))
	show_game(t, 0.0)


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
						if side != view.my_side and not view.shows(p):
							continue
						items.append([0.0, "minion", p, 0.022 * view.token_k, view.team_colour(side), null])
		for side in ["B", "R"]:
			for slot in ArenaPlayer.SLOTS:
				var key: String = side + "." + slot
				if not pl.alive(key, t):
					continue
				var p2 := pl.pos(key, t)
				if side != view.my_side and not view.shows(p2):
					continue
				var arch := String(SimData.heroes()[pl.hero_of[key]]["archetype"])
				items.append([0.0, "hero_" + arch, p2, ArenaView.HERO_H * view.token_k, Color(1, 1, 1), ["hero", key, side]])
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
			var k2 := view.token_k
			if kind2 == "cast":
				var at: Vector2 = e[6] if bool(e[5]) else e[1]
				if not (view.shows(e[1]) or view.shows(at)):
					continue
				# 0.12 Q5: the ability's own look (kind and the caster's archetype), all from the arena atlas
				var arch2 := String(SimData.heroes()[pl.hero_of[String(e[7])]]["archetype"]) if e.size() > 7 and pl.hero_of.has(String(e[7])) else ""
				for fx in ArenaFx2.style(String(e[4]), arch2):
					var where: Vector2 = at if String(fx[1]) == "target" else e[1]
					if bool(fx[5]):
						where = (e[1] as Vector2).lerp(at, minf(1.0, age * 1.6))
					var colfx := Color(ArenaFx2.tone_colour(String(fx[2]), col2), 1.0 - age)
					var wfx := float(fx[3]) * k2 * (0.8 + 0.6 * age)
					if float(fx[4]) > 0.0:
						_up(tex, String(fx[0]), where, wfx, float(fx[4]) * ArenaView.HERO_H * k2 * (1.0 + 0.4 * age), colfx)
					else:
						_flat(tex, String(fx[0]), where, wfx, colfx)
			else:
				if not view.shows(e[1]):
					continue    # a kill in the fog: the feed still says it, the map does not show where
				_flat(tex, "burst", e[1], 0.06 * k2 * (0.5 + age), Color(1, 0.85, 0.6, 0.9 * (1.0 - age)))
				_flat(tex, "skull", e[1], 0.03 * k2, Color(1, 1, 1, 1.0 - age))

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
			_flat(tex, "shadow", p, 0.026 * view.token_k, Color(1, 1, 1, 0.9))
			_flat(tex, ring, p, 0.024 * view.token_k, col)
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

	## A sprite standing upright `lift` ground units above a point (heals, shields, crowd control over a hero).
	func _up(tex: Texture2D, name: String, p: Vector2, w: float, lift: float, col: Color) -> void:
		var pr := view.cam.project(p)
		if pr.z <= 0.0:
			return
		var sc := view.cam.scale_at(p)
		var wpx := w * sc
		var ly := lift * sc
		draw_texture_rect_region(tex, Rect2(pr.x - wpx / 2.0, pr.y - ly - wpx / 2.0, wpx, wpx), ArenaAtlas.rect(name), col)

	## A thin segmented health bar (dark back, team fill, a notch every quarter).
	func _bar(tex: Texture2D, at: Vector2, sc: float, hp: float, col: Color) -> void:
		var w := maxf(26.0 * view.bar_k, ArenaView.BAR_W * sc * view.token_k)
		var h := 5.0 * view.bar_k
		var src := ArenaAtlas.rect("bar")
		draw_texture_rect_region(tex, Rect2(at.x - w / 2.0 - 1.0, at.y - 1.0, w + 2.0, h + 2.0), src, Color(0.05, 0.06, 0.08, 0.85))
		draw_texture_rect_region(tex, Rect2(at.x - w / 2.0, at.y, w * clampf(hp, 0.0, 1.0), h), src, col)
		for k in range(1, 4):
			draw_texture_rect_region(tex, Rect2(at.x - w / 2.0 + w * float(k) / 4.0 - 0.5, at.y, 1.0, h), src, Color(0.05, 0.06, 0.08, 0.9))


class _Labels extends Control:
	## Words and numbers over the map: intents over heroes, team calls, levels (Action), objective countdowns. Every text is
	## queued, then drawn in two passes (all outlines, then all fills), so they batch into a few draw calls instead of two per
	## label (Match Day M5: drawn one by one they cost about 20 more calls).
	var view: ArenaView
	var _q: Array = []        # [position, text, size, colour]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _put(at: Vector2, text: String, fs: int, col: Color) -> void:
		_q.append([at, text, fs, col])

	func _draw() -> void:
		if view == null or view._font == null:
			return
		_q.clear()
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
			var p := pl.pos(who, t)
			if String(who.substr(0, 1)) != view.my_side and not view.shows(p):
				continue
			shown[who] = true
			var pr := view.cam.project(p)
			var hpx := ArenaView.HERO_H * view.token_k * view.cam.scale_at(p)
			var fs := UI.S_CAPTION if view.mode == "action" else UI.S_SMALL
			var w := view._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_put(Vector2(pr.x - w / 2.0, pr.y - hpx - 16.0), text, fs, view.team_colour(String(who.substr(0, 1))).lightened(0.35))
		_calls(pl, t)
		_levels(pl, t)
		_countdowns(pl, t)
		for q in _q:
			draw_string_outline(view._font, q[0], q[1], HORIZONTAL_ALIGNMENT_LEFT, -1, q[2], 5, Color(0, 0, 0, 0.88))
		for q in _q:
			draw_string(view._font, q[0], q[1], HORIZONTAL_ALIGNMENT_LEFT, -1, q[2], q[3])

	## Match Day M5: a team call (group, siege, defend) as one word over the calling team's heroes (their centre), for 3 s.
	func _calls(pl: ArenaPlayer, t: float) -> void:
		for n in pl.notes(t):
			var who := String(n[1])
			if not who.begins_with("team."):
				continue
			var side := who.substr(5, 1)
			var text := ArenaView.intent_word(String(n[2]))
			if text == "":
				continue
			var c := Vector2.ZERO
			var k := 0
			for slot in ArenaPlayer.SLOTS:
				var key: String = side + "." + slot
				if pl.alive(key, t):
					c += pl.pos(key, t)
					k += 1
			if k == 0:
				continue
			c /= float(k)
			if side != view.my_side and not view.shows(c):
				continue
			var pr := view.cam.project(c)
			var w := view._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.S_SMALL).x
			_put(Vector2(pr.x - w / 2.0, pr.y - 70.0), text, UI.S_SMALL, view.team_colour(side).lightened(0.5))

	## Match Day M5 (ARENA-HUD-2 2.4): each visible hero's level beside its token, in Action only (the overview tokens are small).
	func _levels(pl: ArenaPlayer, t: float) -> void:
		if view.mode != "action":
			return
		for side in ["B", "R"]:
			for slot in ArenaPlayer.SLOTS:
				var key: String = side + "." + slot
				if not pl.alive(key, t):
					continue
				var p := pl.pos(key, t)
				if side != view.my_side and not view.shows(p):
					continue
				var pr := view.cam.project(p)
				var hpx := ArenaView.HERO_H * view.token_k * view.cam.scale_at(p)
				_put(Vector2(pr.x + hpx * 0.30, pr.y + 4.0), str(pl.level_of(key, t)), UI.S_CAPTION, view.team_colour(side).lightened(0.45))

	## Match Day M5 (ARENA-HUD-2 2.2): an objective that is down shows a ring that empties and the time until it is back (or
	## until it first appears). Positions come from the map data, so they move with any map change. Public: shown in fog too.
	func _countdowns(pl: ArenaPlayer, t: float) -> void:
		for oid in ["stoneback", "moonhulk", "mossback"]:
			var cd := ArenaView.countdown(pl, oid, t)
			if cd.is_empty():
				continue
			var nxt := float(cd["back"])
			var prev := float(cd["since"])
			var p: Vector2 = SimData.map()["objectives"][oid]["pos"]
			var pr := view.cam.project(p)
			if pr.x < -40.0 or pr.y < -40.0 or pr.x > size.x + 40.0 or pr.y > size.y + 40.0:
				continue
			var r := 22.0
			var left := nxt - t
			var whole := maxf(1.0, nxt - prev)
			var col := Color(1.0, 0.82, 0.35) if oid == "stoneback" else (Color(0.65, 0.8, 1.0) if oid == "moonhulk" else Color(0.55, 0.85, 0.55))
			var c2 := Vector2(pr.x, pr.y)
			draw_arc(c2, r, -PI / 2.0, -PI / 2.0 + TAU * clampf(left / whole, 0.0, 1.0), 32, col, 4.0)
			var txt := ArenaHud2.mmss(left)
			var w := view._font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.S_CAPTION).x
			_put(Vector2(pr.x - w / 2.0, pr.y + r + 26.0), txt, UI.S_CAPTION, Color(1, 1, 1))


## Match Day M5: for an objective that is down at t, {"back": game time it returns, "since": when it was taken (0 before its
## first appearance)}; {} while it is up or when it does not return before the game ends. Display only.
static func countdown(pl: ArenaPlayer, oid: String, t: float) -> Dictionary:
	if pl.objective(oid, t) == "up":
		return {}
	var nxt := INF
	var prev := 0.0
	for u in pl.obj_up:
		if String(u[1]) == oid and float(u[0]) > t:
			nxt = minf(nxt, float(u[0]))
	for o in pl.objs:
		if String(o[1]) == oid and float(o[0]) <= t:
			prev = maxf(prev, float(o[0]))
	if nxt == INF or nxt > pl.end_t:
		return {}
	return {"back": nxt, "since": prev}


## The short word over a hero for a notable intent (copy keys arena2.intent.*); "" for none.
static func intent_word(intent: String) -> String:
	if intent in ["gank", "roam", "back_off", "ward", "call_group", "call_siege", "call_defend"]:
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
			if view.fog_on():
				draw_texture_rect(view.fog_texture(), Rect2(Vector2.ZERO, size), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(gt, Rect2(Vector2.ZERO, size), false)
			if view.fog_on():
				draw_texture_rect(view.fog_texture(), Rect2(Vector2.ZERO, size), false)
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
				var gp := view.player.pos(key, view.t)
				if side != view.my_side and not view.shows(gp):
					continue
				var q2 := _to(gp)
				var col := view.team_colour(side)
				if side == view.my_side:
					draw_texture_rect_region(tex, Rect2(q2 - Vector2(5, 5), Vector2(10, 10)), dot, col)
				else:
					draw_texture_rect_region(tex, Rect2(q2 - Vector2(4.5, 4.5), Vector2(9, 9)), ArenaAtlas.rect("bar"), col)
		if view.mode == "all":
			return    # All shows everything and the whole island: no frame
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
