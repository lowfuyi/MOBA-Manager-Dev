extends RefCounted
## Matrix module "standings" (I-20): Standings in the states of the build plan, measured with a renderer against PERF-BUDGET 3.1a
## (a redesigned screen: target 60 draw calls and 120 nodes, hard 100 and 200):
##   STANDINGS|<variant>|<state>|nodes=..|draw_calls=..
## States: table (Points, four rounds in), table_lower (scrolled: the pinned row when your row is out of view), form (Form Rating),
## ghost (Playoffs view during the league), history, bracket (the playoffs under way), final (the season over: ticks and the
## champion), history_full. Over the target or the hard limit is added to ctx.problems.
##   SHOT_DIR=<dir> SCREENS=standings VARIANTS=normal,large,cb,tall xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 res://tests/shots_matrix.tscn

const HARD_CALLS := 100
const HARD_NODES := 200
const TARGET_CALLS := 60


static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


static func _measure(ctx, state: String) -> void:
	await ctx.settle()
	await ctx.settle()
	var r := ctx.cur() as ScreenStandings
	var nodes := _count(r)
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("STANDINGS|%s|%s|nodes=%d|draw_calls=%d" % [ctx.variant, state, nodes, calls])
	if calls > HARD_CALLS or nodes > HARD_NODES:
		ctx.problems.append("standings_%s_%s: %d draw calls and %d nodes (hard limits %d and %d)" % [state, ctx.variant, calls, nodes, HARD_CALLS, HARD_NODES])
	if calls > TARGET_CALLS:
		ctx.problems.append("standings_%s_%s: %d draw calls (target %d)" % [state, ctx.variant, calls, TARGET_CALLS])
	await ctx.shot(state)


static func play(gs: GameState, n: int) -> void:
	for i in n:
		var g := gs.next_game()
		if g.is_empty():
			break
		gs.record_human_game(g, gs.auto_game(g))


static func run(ctx) -> void:
	await ctx.start_game(5)
	play(App.gs, 4)
	var st := ScreenStandings.new()
	App.go(st)
	await ctx.settle()
	await _measure(ctx, "table")
	st.page_scroll.scroll_vertical = 100000
	await _measure(ctx, "table_lower")
	st.page_scroll.scroll_vertical = 0
	st._set_metric("form")
	await _measure(ctx, "form")
	st._set_tab("playoffs")
	await _measure(ctx, "ghost")
	st._set_tab("history")
	await _measure(ctx, "history")
	App.gs.autoplay(false)
	var st2 := ScreenStandings.new("playoffs")
	App.go(st2)
	await ctx.settle()
	await _measure(ctx, "bracket")
	App.gs.autoplay(true)
	var st3 := ScreenStandings.new("playoffs")
	App.go(st3)
	await ctx.settle()
	await _measure(ctx, "final")
	st3._set_tab("history")
	await _measure(ctx, "history_full")
	GameState.delete_save()
