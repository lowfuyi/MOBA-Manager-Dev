extends RefCounted
## Matrix module "match" (Arena v2, Phase 4): the real Match screen (the tilted arena playing the v2 log) on the fixed-seed
## save's next game, at four points of the show and the end, with the frame's numbers (PERF-BUDGET 3.1a: target 60 draw calls
## and 120 nodes, hard 100 and 200):
##   MATCH|<variant>|<state>|nodes=..|draw_calls=..
## States: p10, p35, p60, p85 (percent of the show length), end (Skip: end card and See the report).

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
	for f in [0.10, 0.35, 0.60, 0.85]:
		m.show_t = f * m.show_len()
		m._apply()
		await _measure(ctx, m, "p%d" % int(f * 100.0))
	m._skip()
	await _measure(ctx, m, "end")
