extends RefCounted
## Matrix module "match" (Arena v2; views since 2026-11-22): the real Match screen (the tilted arena playing the v2 log) on the
## fixed-seed save's next game, in each view (Field, Action, All) at two points of the show, Action also at 10 and 85 percent,
## and the end, with the frame's numbers (PERF-BUDGET 3.1a: target 60 draw calls and 120 nodes, hard 100 and 200):
##   MATCH|<variant>|<state>|nodes=..|draw_calls=..
## States: p10, p35, p60, p85 (Action, percent of the show length), field_p35, field_p60, all_p35, all_p60, comment (the first commentary line, not in large text), end (Skip).

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
	m.set_view("action", false)
	for f in [0.10, 0.35, 0.60, 0.85]:
		m.show_t = f * m.show_len()
		m._apply(0.5)
		await _measure(ctx, m, "p%d" % int(f * 100.0))
	for vw in ["field", "all"]:
		m.set_view(vw, false)
		for f2 in [0.35, 0.60]:
			m.show_t = f2 * m.show_len()
			m._apply(0.5)
			await _measure(ctx, m, "%s_p%d" % [vw, int(f2 * 100.0)])
	m.set_view("action", false)
	# 0.12 Q4: the first commentary line on screen (none in large text)
	if m._notes.comments != null and not m._notes.comments.lines.is_empty():
		m.show_t = m.player.show_t(float(m._notes.comments.lines[0][0]) + 0.5)
		m._apply(0.5)
		await _measure(ctx, m, "comment")
	m._skip()
	await _measure(ctx, m, "end")
