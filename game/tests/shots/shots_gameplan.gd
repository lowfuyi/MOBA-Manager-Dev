extends RefCounted
## Matrix module "gameplan" (I-17): the Game Plan in the states of the build plan, measured with a renderer against PERF-BUDGET
## 3.1a (a redesigned screen: target 60 draw calls and 120 nodes, hard 100 and 200):
##   GAMEPLAN|<variant>|<state>|nodes=..|draw_calls=..
## States: overall, early, mid, late (the Default plan), behind (If behind on, Early page: the inert controls), behind_off (If behind
## switched off), coach (the Coach sheet open), plans (the plan sheet open). Over the hard limit, or a screen state (no sheet) over
## the target, is added to ctx.problems. (The I-10 gallery module "plan" is a different module.)
##   SHOT_DIR=<dir> SCREENS=gameplan VARIANTS=normal,large,cb,tall xvfb-run -a -s "-screen 0 720x1280x24" \
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
	var gp := ctx.cur() as ScreenGamePlan
	var nodes := _count(gp)
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("GAMEPLAN|%s|%s|nodes=%d|draw_calls=%d" % [ctx.variant, state, nodes, calls])
	if calls > HARD_CALLS or nodes > HARD_NODES:
		ctx.problems.append("gameplan_%s_%s: %d draw calls and %d nodes (hard limits %d and %d)" % [state, ctx.variant, calls, nodes, HARD_CALLS, HARD_NODES])
	if not BottomSheet.is_open() and calls > TARGET_CALLS:
		ctx.problems.append("gameplan_%s_%s: %d draw calls (target %d for the screen states)" % [state, ctx.variant, calls, TARGET_CALLS])
	await ctx.shot(state)


static func run(ctx) -> void:
	await ctx.start_game(5)
	var g: Dictionary = App.gs.next_game()
	var d := ScreenDraft.new(g)
	App.go(d)
	await ctx.settle()
	d._auto_rest()
	await ctx.settle()
	var ps: Dictionary = App.gs.plan_set()
	ps["triggers"].clear()
	var gp := ScreenGamePlan.new(g, d.draft)
	App.go(gp)
	await ctx.settle()
	await _measure(ctx, "overall")
	for ph in ["early", "mid", "late"]:
		gp._set_phase(ph)
		await _measure(ctx, ph)
		if ph == "early":
			gp.page_scroll.scroll_vertical = 100000
			await _measure(ctx, "early_lower")
	gp._set_tab("behind_early")
	await _measure(ctx, "behind_off")
	gp._toggle_trigger()
	gp._set_phase("early")
	await _measure(ctx, "behind")
	gp.page_scroll.scroll_vertical = 100000
	await _measure(ctx, "behind_lower")
	gp._set_tab("default")
	gp._set_phase("overall")
	gp._coach()
	await _measure(ctx, "coach")
	BottomSheet.current().close()
	await ctx.settle()
	gp._open_plans()
	await _measure(ctx, "plans")
	BottomSheet.current().close()
	await ctx.settle()
	ps["triggers"].clear()
	GameState.delete_save()
