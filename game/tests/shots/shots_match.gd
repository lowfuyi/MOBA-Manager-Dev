extends RefCounted
## Matrix module "match" (Alpha 0.8 A-06): the real Match screen (the arena) on the fixed-seed save's next game, at four show
## times and the end, with the frame's numbers (PERF-BUDGET 3.1a: target 60 draw calls and 120 nodes, hard 100 and 200):
##   MATCH|<variant>|<state>|nodes=..|draw_calls=..
## States: t14 (lanes resolving), t33 (Stoneback, zoomed), t45 (the mid fight), t70 (the late fight), end (Skip: end card and
## See the report).

static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


static func _measure(ctx, m: ScreenMatch, state: String) -> void:
	await ctx.settle()
	await ctx.settle()
	var nodes := _count(m)
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("MATCH|%s|%s|nodes=%d|draw_calls=%d" % [ctx.variant, state, nodes, calls])
	if calls > 100 or nodes > 200:
		ctx.problems.append("match_%s_%s: %d draw calls and %d nodes" % [state, ctx.variant, calls, nodes])
	await ctx.shot(state)


static func run(ctx) -> void:
	await ctx.start_game()
	var gs := App.gs
	var g := gs.next_game()
	var res := gs.auto_game(g)
	var m := ScreenMatch.new(g, res)
	App.go(m)
	await ctx.settle()
	for t in [14.0, 33.0, 45.0, 70.0]:
		m.show_t = t
		m._apply()
		await _measure(ctx, m, "t%d" % int(t))
	m._skip()
	await _measure(ctx, m, "end")
