extends RefCounted
## Matrix module "draft" (I-16): the Draft in the states of the build plan, measured with a renderer against PERF-BUDGET 3.1a (a
## redesigned screen: target 60 draw calls and 120 nodes, hard 100 and 200; the HeroGrid alone at most 15, I-09):
##   DRAFT|<variant>|<state>|nodes=..|draw_calls=..
## States: ban (your ban), theirs (their turn: the grid dimmed), pick (your pick), pick_lower (the grid scrolled to the bottom),
## sheet_ban, sheet_pick (the hero sheet), filter (role filter on Jungle), done. The hard limit failing is added to ctx.problems.
##   SHOT_DIR=<dir> SCREENS=draft VARIANTS=normal,large,cb,tall xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 res://tests/shots_matrix.tscn

const HARD_CALLS := 100
const HARD_NODES := 200
const TARGET_CALLS := 60      # the screen states (not with a sheet open) must meet the target: build plan I-16 acceptance
const GRID_CALLS := 15        # the HeroGrid alone (I-09 gate), measured as the frame with it minus the frame without it


static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


static func _measure(ctx, state: String) -> void:
	await ctx.settle()
	await ctx.settle()
	var d := ctx.cur() as ScreenDraft
	var nodes := _count(d)
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("DRAFT|%s|%s|nodes=%d|draw_calls=%d" % [ctx.variant, state, nodes, calls])
	if calls > HARD_CALLS or nodes > HARD_NODES:
		ctx.problems.append("draft_%s_%s: %d draw calls and %d nodes (hard limits %d and %d)" % [state, ctx.variant, calls, nodes, HARD_CALLS, HARD_NODES])
	if not state.begins_with("sheet") and calls > TARGET_CALLS:
		ctx.problems.append("draft_%s_%s: %d draw calls (target %d for the screen states)" % [state, ctx.variant, calls, TARGET_CALLS])
	if state in ["ban", "pick", "pick_lower"] and d != null:
		d.grid.visible = false
		await ctx.settle()
		await ctx.settle()
		var without := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		d.grid.visible = true
		await ctx.settle()
		print("DRAFT|%s|%s|grid_calls=%d" % [ctx.variant, state, calls - without])
		if calls - without > GRID_CALLS:
			ctx.problems.append("draft_%s_%s: the HeroGrid costs %d draw calls (I-09 gate %d)" % [state, ctx.variant, calls - without, GRID_CALLS])
	await ctx.shot(state)


## Let the other side play until it is your turn of `kind` (or the draft is over).
static func _until_mine(d: ScreenDraft, kind: String) -> void:
	var n := 0
	while not d.draft.is_done() and n < 40:
		n += 1
		var c := d.draft.current()
		if c["team"] == d.my_side and c["kind"] == kind:
			return
		if c["team"] == d.my_side:
			d._take()
		else:
			d._ai_wait = 0.0
			d._process(0.01)


static func run(ctx) -> void:
	await ctx.start_game(5)
	var g: Dictionary = App.gs.next_game()
	var d := ScreenDraft.new(g)
	App.go(d)
	await ctx.settle()
	var c := d.draft.current()
	if c["team"] != d.my_side:
		await _measure(ctx, "theirs")
	_until_mine(d, "ban")
	d._time_left = 9.0
	await _measure(ctx, "ban")
	d._open_sheet(String(d.draft.avail[0]))
	await _measure(ctx, "sheet_ban")
	BottomSheet.current().close()
	await ctx.settle()
	d._take()
	_until_mine(d, "pick")
	await _measure(ctx, "pick")
	var sc := d.grid_scroll
	sc.scroll_vertical = 100000
	await _measure(ctx, "pick_lower")
	sc.scroll_vertical = 0
	d._open_sheet(String(d.draft.avail[2]))
	await _measure(ctx, "sheet_pick")
	BottomSheet.current().close()
	await ctx.settle()
	d.filter.set_selected("jg")
	d._on_filter("jg")
	await _measure(ctx, "filter")
	d._on_filter("")
	d.filter.set_selected("")
	d._auto_rest()
	await _measure(ctx, "done")
	GameState.delete_save()
