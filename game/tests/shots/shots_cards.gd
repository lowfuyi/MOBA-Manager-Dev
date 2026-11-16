extends RefCounted
## Matrix module "cards" (I-09): pictures of the gallery sections players, heroes and lanes, plus the numbers that need a renderer:
##   CARDS|<variant>|<section>|nodes=..|draw_calls=..|...   one line per picture (like the gallery module)
##   CARDS|<variant>|grid_only|top=N|bottom=N|empty_page=N|grid=N   the draw calls of ONE HeroGrid of 40 cards inside a scrolling
##                                                                 page at the top and the bottom of its scroll, against the same
##                                                                 page with no grid; the gate is grid <= 15 (build plan I-09)
##   CARDS|<variant>|pixels|...                                       HeroCard.draw with pass -1 against the seven passes in sequence,
##                                                                 rendered in a SubViewport, compared byte for byte
## A failed gate is added to ctx.problems, so the runner exits 1. Run (serially: renders share user:// settings):
##   SHOT_DIR=<dir> SCREENS=cards VARIANTS=normal,large,cb,tall xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 res://tests/shots_matrix.tscn

const Gallery = preload("res://tests/components_gallery.gd")
const GRID_CALL_CEILING := 15
const SECTIONS := ["players", "heroes", "lanes"]


class Canv extends Control:
	var fn: Callable

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


static func _calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


static func _frame(ctx) -> void:
	for i in 3:
		await ctx.get_tree().process_frame
	await RenderingServer.frame_post_draw


static func _measure(ctx, section: String) -> void:
	await _frame(ctx)
	var cur: Control = ctx.cur()
	print("CARDS|%s|%s|nodes=%d|draw_calls=%d|objects=%d|tex_mem=%d|cards_atlas_ok=%s" % [ctx.variant, section, _count(cur), _calls(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)), str(CardKit.ok())])


## A page (ScrollContainer, as every screen has) that holds a 40-hero grid, or nothing, and a filler so it can scroll.
static func _page(with_grid: bool, heroes: Array) -> Array:
	var page := ScrollContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(col)
	var grid: HeroGrid = null
	if with_grid:
		grid = HeroGrid.new()
		grid.set_heroes(heroes)
		var i := 0
		for h in heroes:    # all five states and the arrows and numbers, as in a real draft
			var st := {"s": ["available", "available", "banned", "you", "them", "selected"][i % 6], "arrow": ["up", "down", "flat", ""][i % 4], "delta": ["+1.6", "-1.6", "0.0", ""][i % 4], "num": "%d" % (40 + i), "rec": i == 7}
			grid.set_state(h["id"], st)
			i += 1
		col.add_child(grid)
	else:
		var filler := Control.new()
		filler.custom_minimum_size = Vector2(0, 2900)
		col.add_child(filler)
	return [page, grid]


static func run(ctx) -> void:
	await ctx.start_game(5)
	var heroes: Array = App.world.heroes.values()
	for section in SECTIONS:
		var g: Control = Gallery.new(section)
		App.go(g)
		await ctx.get_tree().process_frame
		await ctx.shot(section)
		await _measure(ctx, section)
		var sc := g.body.get_parent() as ScrollContainer
		await ctx.get_tree().process_frame
		var max_scroll := int(g.body.size.y - sc.size.y)
		var part := 1
		while max_scroll > 8 and part < 4:    # a second and a third picture when the section is taller than the window
			sc.scroll_vertical = mini(max_scroll, part * int(sc.size.y * 0.9))
			await ctx.shot("%s%s" % [section, "bcd"[part - 1]])
			part += 1
			if sc.scroll_vertical >= max_scroll:
				break
	# the draw calls of the grid alone
	var empty_scr := Control.new()
	var pe := _page(false, heroes)
	empty_scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	empty_scr.add_child(pe[0])
	App.go(empty_scr)
	await _frame(ctx)
	var empty_calls := _calls()
	var scr := Control.new()
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pg := _page(true, heroes)
	scr.add_child(pg[0])
	App.go(scr)
	await _frame(ctx)
	var page := pg[0] as ScrollContainer
	var grid := pg[1] as HeroGrid
	var top := _calls()
	await ctx.shot("grid_top")
	var max_scroll2 := int(grid.size.y - page.size.y)
	page.scroll_vertical = max_scroll2
	await _frame(ctx)
	var bottom := _calls()
	await ctx.shot("grid_bottom")
	var worst := maxi(top, bottom) - empty_calls
	print("CARDS|%s|grid_only|top=%d|bottom=%d|empty_page=%d|grid=%d|nodes=%d|ceiling=%d" % [ctx.variant, top, bottom, empty_calls, worst, _count(grid), GRID_CALL_CEILING])
	if worst > GRID_CALL_CEILING:
		ctx.problems.append("cards_%s: the HeroGrid costs %d draw calls (ceiling %d)" % [ctx.variant, worst, GRID_CALL_CEILING])
	# a filter change and state changes redraw the same count
	grid.set_filter("sup")
	await _frame(ctx)
	var filtered := _calls() - empty_calls
	print("CARDS|%s|grid_filtered_sup|draw_calls_over_page=%d|shown=%d" % [ctx.variant, filtered, grid.shown_count()])
	grid.set_filter("")
	# pixel equality: pass -1 against the seven passes in sequence
	var hero: Dictionary = App.world.heroes["gravenstone"]
	var imgs: Array = []
	for mode in ["one", "five"]:
		var vp := SubViewport.new()
		vp.size = Vector2i(260, 240)
		vp.transparent_bg = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var c := Canv.new()
		c.size = Vector2(260, 240)
		var st := {"s": "them", "arrow": "up", "delta": "+1.6", "num": "82", "rec": true}
		if mode == "one":
			c.fn = func(ci: CanvasItem) -> void: HeroCard.draw(ci, Rect2(20, 20, 216, 196), hero, st)
		else:
			c.fn = func(ci: CanvasItem) -> void:
				for p in HeroCard.PASSES:
					HeroCard.draw(ci, Rect2(20, 20, 216, 196), hero, st, p)
		vp.add_child(c)
		ctx.add_child(vp)
		await _frame(ctx)
		await _frame(ctx)
		imgs.append(vp.get_texture().get_image())
		if ctx.variant == "normal":
			imgs[-1].save_png("%s/cards_herocard_%s.png" % [ctx.dir, mode])
		vp.queue_free()
	var same: bool = (imgs[0] as Image).get_data() == (imgs[1] as Image).get_data() and (imgs[0] as Image).get_size() == Vector2i(260, 240)
	var nonblank := false
	var d: PackedByteArray = (imgs[0] as Image).get_data()
	for i in range(0, d.size(), 4):
		if d[i] != d[0] or d[i + 1] != d[1] or d[i + 2] != d[2]:
			nonblank = true
			break
	print("CARDS|%s|pixels|one_equals_five=%s|nonblank=%s" % [ctx.variant, str(same), str(nonblank)])
	if not same or not nonblank:
		ctx.problems.append("cards_%s: HeroCard.draw pass -1 does not equal the seven passes in sequence (same=%s, nonblank=%s)" % [ctx.variant, str(same), str(nonblank)])
