extends RefCounted
## Matrix module "lessons" (I-23): the lesson offer on Home, a lesson step on Team chemistry (L4), and the Lessons list.
##   LESSONS|<variant>|<state>|nodes=..|draw_calls=..   (hard limits 100 / 200)
##   SHOT_DIR=<dir> SCREENS=lessons VARIANTS=normal,large,cb,tall xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 res://tests/shots_matrix.tscn

static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


static func _measure(ctx, state: String) -> void:
	for i in 3:
		await ctx.settle()
	var nodes := _count(ctx.cur())
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("LESSONS|%s|%s|nodes=%d|draw_calls=%d" % [ctx.variant, state, nodes, calls])
	if calls > 100 or nodes > 200:
		ctx.problems.append("lessons_%s_%s: %d draw calls and %d nodes" % [state, ctx.variant, calls, nodes])
	await ctx.shot(state)


static func run(ctx) -> void:
	await ctx.start_game(5)
	App.gs.set_tutorial({"v": 1, "state": "done", "step": "finish", "game": {"live": false, "n": 1, "plan": {}}})
	App.tutorial.bind()
	App.tutorial.device.set_lesson_status("l1", "")
	load("res://tests/shots/shots_standings.gd").play(App.gs, 4)
	var keep := TutorialRunner.home_offers
	TutorialRunner.home_offers = true
	App.go(ScreenHub.new())
	await _measure(ctx, "home_offer")
	TutorialRunner.home_offers = keep
	App.lessons.start("l4")
	await _measure(ctx, "l4_open")
	(UI.find_tag("plan.tile.chem") as BaseButton).pressed.emit()
	await _measure(ctx, "l4_summary")
	App.lessons.stop(false)
	App.go(ScreenLessons.new())
	await _measure(ctx, "list")
	for id in LessonRunner.ids():
		App.tutorial.device.set_lesson_status(String(id), "")
	GameState.delete_save()
