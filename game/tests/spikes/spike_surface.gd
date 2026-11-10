extends Node
## Spike S3 (build plan I-01): Surface = StyleBoxFlat cards against a baked 9-slice StyleBoxTexture cards from one
## shared atlas, on a Draft-like screen of 8 cards. Counts draw calls per frame. Needs a renderer, so run under Xvfb
## with software OpenGL (headless draws nothing and every number is 0):
##   xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 res://tests/spikes/spike_surface.tscn
## Draw-call and node counts carry over to a phone; milliseconds (frame_ms) do not: they are llvmpipe CPU time.
## Configs = background (flat, flat with shadow, baked 9-slice, baked 9-slice on a separate layer behind the text)
##           x content (none, a label, an icon and two labels).
## Prints "S3|<bg>|<content>|draw_calls=..|objects=..|nodes=..|frame_ms=..|tex_mem=..".

const CARDS := 8
const CARD_H := 120
const R := 20

var root: Control
var atlas: ImageTexture
var icon_tex: ImageTexture
var rows: Array = []
var empty_draws := 0


func _ready() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		print("S3|SKIPPED|headless draws nothing; run under xvfb-run with --rendering-driver opengl3")
		get_tree().quit(0)
		return
	print("S3|adapter=%s|%s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])
	atlas = _make_atlas()
	icon_tex = _make_icon()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()                       # the page background, as Main has
	bg.color = Color(0.05, 0.06, 0.09)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	empty_draws = await _measure("empty page", "none")
	for content in ["none", "label", "icon+2 labels"]:
		for kind in ["flat", "flat+shadow", "baked9", "baked9 layered"]:
			await _build(kind, content)
			await _measure(kind, content)
	get_tree().quit(0)


func _measure(kind: String, content: String) -> int:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var t0 := Time.get_ticks_usec()
	for i in 10:
		await get_tree().process_frame
	var ms := float(Time.get_ticks_usec() - t0) / 10000.0
	var nodes := _count(root)
	var shot_dir := OS.get_environment("SHOT_DIR")
	if shot_dir != "":
		get_viewport().get_texture().get_image().save_png("%s/s3_%s_%s.png" % [shot_dir, kind.replace("+", "_").replace(" ", "_"), content.replace("+", "_").replace(" ", "_")])
	print("S3|%s|%s|draw_calls=%d|objects=%d|nodes=%d|frame_ms=%.1f|tex_mem=%d" % [kind, content, draws, objs, nodes, ms,
			int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))])
	return draws


func _count(n: Node) -> int:
	var t := 1
	for c in n.get_children():
		t += _count(c)
	return t


func _clear() -> void:
	for c in root.get_children():
		if c is ColorRect:
			continue
		root.remove_child(c)
		c.queue_free()


func _flat(shadow: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.11, 0.13, 0.19)
	s.set_corner_radius_all(R)
	s.set_border_width_all(2)
	s.border_color = Color(0.2, 0.23, 0.32)
	if shadow:
		s.shadow_size = 12
		s.shadow_offset = Vector2(0, 6)
		s.shadow_color = Color(0, 0, 0, 0.45)
	return s


func _baked(tile: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = atlas                       # one shared texture for every card (three elevations side by side)
	s.region_rect = Rect2(tile * 64, 0, 64, 64)
	s.set_texture_margin_all(24)
	s.set_content_margin_all(16)
	return s


func _card_content(i: int, content: String) -> Control:
	if content == "none":
		return null
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	if content == "icon+2 labels":
		var t := TextureRect.new()
		t.texture = icon_tex
		t.custom_minimum_size = Vector2(56, 56)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(t)
	var l := Label.new()
	l.text = "Hero card %d" % i
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	if content == "icon+2 labels":
		var l2 := Label.new()
		l2.text = "Fit 87"
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l2)
	return h


func _build(kind: String, content: String) -> void:
	_clear()
	await get_tree().process_frame
	var col := VBoxContainer.new()
	col.position = Vector2(40, 120)
	col.size = Vector2(640, CARDS * (CARD_H + 12))
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	var head := Label.new()                            # a title and a timer, as the Draft has
	head.text = "Ban phase  0:25"
	head.position = Vector2(40, 40)
	root.add_child(head)
	if kind == "baked9 layered":
		# backgrounds are one sibling container behind, content a second container in front: the backgrounds are
		# adjacent in draw order, so they can batch into one call
		for i in CARDS:
			var p := Panel.new()
			p.custom_minimum_size = Vector2(0, CARD_H)
			p.add_theme_stylebox_override("panel", _baked(0))
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(p)
		var col2 := VBoxContainer.new()
		col2.position = col.position
		col2.size = col.size
		col2.add_theme_constant_override("separation", 12)
		col2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(col2)
		for i in CARDS:
			var m := MarginContainer.new()
			m.custom_minimum_size = Vector2(0, CARD_H)
			m.add_theme_constant_override("margin_left", 16)
			m.add_theme_constant_override("margin_top", 16)
			m.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var c := _card_content(i, content)
			if c != null:
				m.add_child(c)
			col2.add_child(m)
		return
	for i in CARDS:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(0, CARD_H)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb: StyleBox
		match kind:
			"flat":
				sb = _flat(false)
			"flat+shadow":
				sb = _flat(true)
			_:
				sb = _baked(0)
		p.add_theme_stylebox_override("panel", sb)
		var c := _card_content(i, content)
		if c != null:
			p.add_child(c)
		col.add_child(p)


## A 192 x 64 atlas: three 64 x 64 tiles, rounded rectangle radius 20 with the border in the tile; tile 1 and 2 add a
## soft shadow halo (elevation). Generated in code so the spike needs no asset.
func _make_atlas() -> ImageTexture:
	var img := Image.create(192, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for tile in 3:
		var halo: float = [0.0, 6.0, 12.0][tile]
		var inset := 12.0 if tile > 0 else 2.0
		var lo := Vector2(inset, inset)
		var hi := Vector2(64 - inset, 64 - inset - halo * 0.3)
		for y in 64:
			for x in 64:
				var p := Vector2(x + 0.5, y + 0.5)
				var c := (lo + hi) * 0.5
				var half := (hi - lo) * 0.5
				var q := (p - c).abs() - half + Vector2(R, R)
				var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - R
				var col := Color(0, 0, 0, 0)
				if d < -2.0:
					col = Color(0.11, 0.13, 0.19, 1)
				elif d < 0.0:
					col = Color(0.2, 0.23, 0.32, 1)
				elif halo > 0.0 and d < halo:
					col = Color(0, 0, 0, 0.45 * (1.0 - d / halo))
				img.set_pixel(tile * 64 + x, y, col)
	return ImageTexture.create_from_image(img)


func _make_icon() -> ImageTexture:
	var img := Image.create(56, 56, false, Image.FORMAT_RGBA8)
	for y in 56:
		for x in 56:
			var d := Vector2(x - 27.5, y - 27.5).length()
			img.set_pixel(x, y, Color(0.9, 0.5, 0.35, 1) if d < 26 else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
