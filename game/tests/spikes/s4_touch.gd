extends RefCounted
## S4 touch rows: a 40-hero grid inside a vertical page, for the two designs that pass the draw-call gate: "C" (one
## HeroGrid Control, owns hit-testing) and "B3" (one self-drawing Control per card, PASS filter). Per design: a swipe
## that starts on a card scrolls the page and taps nothing; a tap taps that hero. Returns {design: {tap, swipe_scroll, swipe_taps}}.
var owner_node: Node
var sim


func _init(n: Node) -> void:
	owner_node = n
	sim = load("res://tests/spikes/touch_sim.gd").new(n)


func run() -> Dictionary:
	var f := FileAccess.open("res://data/heroes.json", FileAccess.READ)
	var heroes: Array = JSON.parse_string(f.get_as_text())
	var out := {}
	for design in ["C", "B3"]:
		var rig := Control.new()
		rig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		owner_node.add_child(rig)
		var page := ScrollContainer.new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		rig.add_child(page)
		var taps: Array = []
		var first_card: Control
		if design == "C":
			var g: Control = load("res://tests/spikes/hero_grid_probe.gd").new()
			g.setup(heroes, 3, 183.0)
			g.tapped.connect(func(id: String) -> void: taps.append(id))
			page.add_child(g)
			first_card = g
		else:
			var grid := GridContainer.new()
			grid.columns = 3
			page.add_child(grid)
			for h in heroes:
				var c: Control = load("res://tests/spikes/hero_card_atlas.gd").new()
				c.setup(h["id"], h["name"], "", h["role_primary"], 183.0)
				c.single_size = true
				c.tapped.connect(func(id: String) -> void: taps.append(id))
				grid.add_child(c)
				if first_card == null:
					first_card = c
		await sim.frames(4)
		var p0 := Vector2(0, 0)
		var centre := Vector2(91, 95)                       # centre of the first card (top left), same for both designs
		page.scroll_vertical = 0
		await sim.tap(centre)
		var tap_ids: Array = taps.duplicate()
		taps.clear()
		await sim.swipe_angle(centre + Vector2(0, 150), 15.0, 220.0, true, true)
		await sim.frames(8)
		out[design] = {"tap": tap_ids, "expected_id": heroes[0]["id"], "swipe_scroll": page.scroll_vertical, "swipe_taps": taps.duplicate()}
		rig.queue_free()
		await sim.frames(2)
	return out
