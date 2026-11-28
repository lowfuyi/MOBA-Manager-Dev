extends RefCounted
## Matrix module "report" (I-18): the Match report in the states of the build plan, measured with a renderer against PERF-BUDGET
## 3.1a (a redesigned screen: target 60 draw calls and 120 nodes, hard 100 and 200):
##   REPORT|<variant>|<state>|nodes=..|draw_calls=..
## States: win, win_lower (scrolled to the bottom with More detail open), loss, tutorial (the tutorial game's report), why (the
## factor sheet open), plan (Match Day M8: a game played with a set plan and two switch plans, scrolled to Your game plan). A screen state over the target, or any state over the hard limit, is added to ctx.problems.
##   SHOT_DIR=<dir> SCREENS=report VARIANTS=normal,large,cb,tall xvfb-run -a -s "-screen 0 720x1280x24" \
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
	var r := ctx.cur() as ScreenReport
	var nodes := _count(r)
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("REPORT|%s|%s|nodes=%d|draw_calls=%d" % [ctx.variant, state, nodes, calls])
	if calls > HARD_CALLS or nodes > HARD_NODES:
		ctx.problems.append("report_%s_%s: %d draw calls and %d nodes (hard limits %d and %d)" % [state, ctx.variant, calls, nodes, HARD_CALLS, HARD_NODES])
	if not BottomSheet.is_open() and calls > TARGET_CALLS:
		ctx.problems.append("report_%s_%s: %d draw calls (target %d for the screen states)" % [state, ctx.variant, calls, TARGET_CALLS])
	await ctx.shot(state)


## Play the next league game to its report (the Draft auto-finished, the match skipped). Returns the report screen.
static func _play(ctx) -> ScreenReport:
	var g: Dictionary = App.gs.next_game()
	var d := ScreenDraft.new(g)
	App.go(d)
	await ctx.settle()
	d._auto_rest()
	d._start_match()
	await ctx.settle()
	var m: ScreenMatch = ctx.cur()
	m._skip()
	m._continue()
	await ctx.settle()
	return ctx.cur() as ScreenReport


static func run(ctx) -> void:
	await ctx.start_game(5)
	var seen := {}
	var guard := 0
	while (not seen.has("win") or not seen.has("loss")) and guard < 8:
		guard += 1
		var r := await _play(ctx)
		var st := "win" if r.won else "loss"
		if not seen.has(st):
			seen[st] = true
			r.result.shown = 1.0
			await _measure(ctx, st)
			if st == "win":
				var rc := UI.find_tag("report.rate")    # 0.12 Q4-4: why the Form Rating moved
				if rc != null:
					r.page_scroll.ensure_control_visible(rc)
					await ctx.settle()
					await _measure(ctx, "rate")
					r.page_scroll.scroll_vertical = 0
					await ctx.settle()
				r._open_why()
				await _measure(ctx, "why")
				BottomSheet.current().close()
				await ctx.settle()
				r._toggle_dig()
				await ctx.settle()
				var sc := r.page_scroll
				sc.scroll_vertical = 100000
				await _measure(ctx, "win_lower")
		r._leave()
		await ctx.settle()
	# Match Day M8: a set plan with both switches, scrolled to the plan card
	var ps := App.gs.plan_set()
	ps["default"]["a"] = 100
	ps["default"]["t"] = -50
	ps["default"]["jf"] = "bot"
	var sw := GamePlan.neutral()
	sw["g"] = 100
	ps["triggers"] = [{"when": "behind_early", "plan": sw}, {"when": "ahead_early", "plan": sw.duplicate()}]
	var rp := await _play(ctx)
	rp.result.shown = 1.0
	rp.page_scroll.ensure_control_visible(rp.plan_card)
	await ctx.settle()
	await _measure(ctx, "plan")
	rp._leave()
	await ctx.settle()
	# the tutorial game's report
	var tg := TutorialGame.start(App.gs)
	var d2 := ScreenDraft.new(tg)
	App.go(d2)
	await ctx.settle()
	d2._auto_rest()
	d2._start_match()
	await ctx.settle()
	var m2: ScreenMatch = ctx.cur()
	m2._skip()
	m2._continue()
	await ctx.settle()
	(ctx.cur() as ScreenReport).result.shown = 1.0
	await _measure(ctx, "tutorial")
	TutorialGame.leave(App.gs)
	GameState.delete_save()
