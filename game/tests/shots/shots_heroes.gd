extends RefCounted
## Matrix module "heroes" (Phase 5): the Heroes list, a hero page, the build editor sheet and the report's player lines with
## the post-match story, with each frame's numbers (PERF-BUDGET 3.1a: hard 100 draw calls and 200 nodes):
##   HEROES|<variant>|<state>|nodes=..|draw_calls=..

static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


static func _measure(ctx, state: String) -> void:
	await ctx.settle()
	await ctx.settle()
	var nodes := _count(ctx.cur())
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("HEROES|%s|%s|nodes=%d|draw_calls=%d" % [ctx.variant, state, nodes, calls])
	if calls > 100:
		ctx.problems.append("heroes_%s_%s: %d draw calls" % [state, ctx.variant, calls])
	await ctx.shot(state)


static func run(ctx) -> void:
	await ctx.start_game()
	App.go(ScreenHeroes.new())
	await _measure(ctx, "list")
	App.go(ScreenHero.new("harkin"))
	await _measure(ctx, "page")
	var gs := App.gs
	var pid := String(gs.lineup()["bot"]["id"])
	BuildSheet.open_for(pid, "harkin", "bot", [])
	await _measure(ctx, "build")
	BottomSheet.current().close()
	await ctx.settle()
	var g := gs.next_game()
	var res := gs.auto_game(g)
	var r := ScreenReport.new(g, res)
	App.go(r)
	await ctx.settle()
	r._toggle_dig()
	r._set_dig("players")
	await _measure(ctx, "story")
