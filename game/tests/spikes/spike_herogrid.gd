extends Node
## Spike S4 (build plan I-01): the 40-hero Draft grid built two ways.
##   A "nodes": 40 PanelContainers, each with 5 children (portrait, name, tag, state mark, role chip), the obvious way.
##   B "draws": 40 single Controls that draw themselves (tests/spikes/hero_card_probe.gd).
## Prints node count of the grid and the cost of one filter change (role filter: hide the others; plus 8 state changes)
## measured as setters only and as setters plus the next frame (layout, and drawing when a renderer exists).
## Run headless for nodes and timing; run under Xvfb (--rendering-driver opengl3) for draw calls as well. Milliseconds
## are this computer's CPU, not a phone's; the node count and draw-call count carry over.
##   godot --headless res://tests/spikes/spike_herogrid.tscn
const CARD_W := 183.0           # the large-text card width of PERF-BUDGET.md 6 (626 px frame, 3 columns)
const COLS := 3
var heroes: Array = []
var root: Control


func _ready() -> void:
	await get_tree().process_frame
	var f := FileAccess.open("res://data/heroes.json", FileAccess.READ)       # read-only use of the data
	heroes = JSON.parse_string(f.get_as_text())
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	for kind in ["A nodes", "B draws", "B2 atlas", "B3 atlas one size", "C grid"]:
		var scroll := ScrollContainer.new()                        # the page: the grid is longer than the screen
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(scroll)
		var grid: Control = GridContainer.new()
		(grid as GridContainer).columns = COLS
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		scroll.add_child(grid)
		var cards: Array = []
		var gridc: Control = null
		if kind == "C grid":
			gridc = load("res://tests/spikes/hero_grid_probe.gd").new()
			gridc.setup(heroes, COLS, CARD_W)
			scroll.remove_child(grid)
			grid.queue_free()
			grid = gridc
			scroll.add_child(grid)
		else:
			for h in heroes:
				cards.append(_make(kind, h, grid))
		await get_tree().process_frame
		await get_tree().process_frame
		var n := _count(grid)
		var gh := int(grid.size.y)
		var cost: Array = await _filter_cost(cards, kind, grid)
		var draws := -1
		var draws_bottom := -1
		if DisplayServer.get_name() != "headless":
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			scroll.scroll_vertical = 100000
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			draws_bottom = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print("S4|%s|grid_nodes=%d|nodes_per_card=%.1f|setters_ms=%.3f|setters_plus_layout_ms=%.3f|force_draw_ms=%.1f|draw_calls_top=%d|draw_calls_bottom=%d|grid_height=%d" % [kind, n, float(n - 1) / 40.0, cost[0], cost[1], cost[2], draws, draws_bottom, gh])
		scroll.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)


func _make(kind: String, h: Dictionary, grid: Control) -> Control:
	var tag: String = (h["tags"][0] as String) if (h["tags"] as Array).size() > 0 else ""
	if kind == "B draws" or kind.begins_with("B2") or kind.begins_with("B3"):
		var c: Control = load("res://tests/spikes/hero_card_probe.gd" if kind == "B draws" else "res://tests/spikes/hero_card_atlas.gd").new()
		if kind.begins_with("B3"):
			c.single_size = true
		c.setup(h["id"], h["name"], tag, h["role_primary"], CARD_W)
		grid.add_child(c)
		return c
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(CARD_W, 190)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.13, 0.19)
	sb.set_corner_radius_all(20)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	p.add_child(v)
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(0, 88)
	portrait.color = Color.from_hsv(float((h["id"] as String).hash() % 100) / 100.0, 0.45, 0.8)
	v.add_child(portrait)
	var nm := Label.new()
	nm.text = h["name"]
	nm.add_theme_font_size_override("font_size", 26)
	v.add_child(nm)
	var tg := Label.new()
	tg.text = tag
	tg.add_theme_font_size_override("font_size", 22)
	v.add_child(tg)
	var mark := Label.new()
	mark.text = ""
	v.add_child(mark)
	var chip := Label.new()
	chip.text = h["role_primary"]
	v.add_child(chip)
	p.set_meta("mark", mark)
	grid.add_child(p)
	return p


## One filter change: show only role X (hide the rest) and set 8 cards to banned / picked states; then back to "all".
## Returns [setters ms, setters plus one frame ms minus an idle frame, idle frame ms].
func _filter_cost(cards: Array, kind: String, grid: Control) -> Array:
	var roles := ["top", "jg", "mid", "bot", "sup"]
	var idle := 0
	var draw_us := 0
	if DisplayServer.get_name() != "headless":
		for i in 5:
			var a := Time.get_ticks_usec()
			RenderingServer.force_draw(true, 0.0)
			draw_us += Time.get_ticks_usec() - a
	idle = draw_us * 6                                  # reported below as force_draw_ms (llvmpipe CPU, not a phone)
	var t_set := 0
	var t_frame := 0
	var runs := 30
	for i in runs:
		var role: String = roles[i % roles.size()]
		var on: bool = (i % 2 == 0)
		var t0 := Time.get_ticks_usec()
		if kind == "C grid":
			grid.set_filter(role)
			for j in 8:
				grid.set_state(j, (j % 5) if on else 0)
		else:
			for j in cards.size():
				var c: Control = cards[j]
				c.visible = (heroes[j]["role_primary"] == role) or (heroes[j]["role_secondary"] == role)
				var st := (j % 5) if (j < 8 and on) else 0
				if kind == "A nodes":
					(c.get_meta("mark") as Label).text = ["", "OK", "BAN", "you", "them"][st]
				else:
					c.set_state(st)
		var t1 := Time.get_ticks_usec()
		if kind != "C grid":
			grid.notification(Container.NOTIFICATION_SORT_CHILDREN)      # the layout the next frame would do, now
		var t2 := Time.get_ticks_usec()
		await get_tree().process_frame
		t_set += t1 - t0
		t_frame += t2 - t0
	if kind == "C grid":
		grid.set_filter("")
	for c in cards:
		c.visible = true
	return [float(t_set) / float(runs) / 1000.0, float(t_frame) / float(runs) / 1000.0, float(draw_us) / 5.0 / 1000.0]


func _count(n: Node) -> int:
	var t := 1
	for c in n.get_children():
		t += _count(c)
	return t
