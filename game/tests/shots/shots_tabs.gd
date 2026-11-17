extends RefCounted
## Matrix module "tabs" (I-21b): the Plan and Club tabs and Match day restyled with the new components, measured against PERF-BUDGET
## 3.1a (target 60 draw calls and 120 nodes, hard 100 and 200):
##   TABS|<variant>|<state>|nodes=..|draw_calls=..
## States: plan, club, prematch, prematch_tired (every starter tired: the Rotate card), prematch_lower (scrolled to the buttons).
##   SHOT_DIR=<dir> SCREENS=tabs VARIANTS=normal,large,cb,tall xvfb-run -a -s "-screen 0 720x1280x24" \
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
	var r: Node = ctx.cur()
	var nodes := _count(r)
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("TABS|%s|%s|nodes=%d|draw_calls=%d" % [ctx.variant, state, nodes, calls])
	if calls > TARGET_CALLS or nodes > 120:
		ctx.problems.append("tabs_%s_%s: %d draw calls and %d nodes (target 60 / 120)" % [state, ctx.variant, calls, nodes])
	await ctx.shot(state)


static func run(ctx) -> void:
	await ctx.start_game(5)
	App.go(ScreenPlan.new())
	await _measure(ctx, "plan")
	App.go(ScreenClub.new())
	await _measure(ctx, "club")
	var g: Dictionary = App.gs.next_game()
	App.go(ScreenPreMatch.new(g))
	await _measure(ctx, "prematch")
	for pid in (App.gs.d["lineup"] as Dictionary).values():
		App.world.fatigue[pid] = 80.0
	App.go(ScreenPreMatch.new(g))
	await _measure(ctx, "prematch_tired")
	var sc := ctx.cur().body.get_parent() as ScrollContainer
	if sc != null:
		sc.scroll_vertical = 100000
	await _measure(ctx, "prematch_lower")
	App.world.fatigue.clear()
	GameState.delete_save()
