extends RefCounted
## Matrix module "idle" (I-25, PERF-BUDGET idle-redraw check): on each of the six rebuilt screens, after it has settled, 90 frames of
## doing nothing must not redraw any drawn control (the sum of every `draw_count` in the screen stays the same). A screen that redraws
## while idle costs battery on a phone for nothing. Prints IDLE|<variant>|<screen>|redraws=N; any redraw is a problem.
##   SHOT_DIR=<dir> SCREENS=idle VARIANTS=normal xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 res://tests/shots_matrix.tscn

static func _sum(n: Node) -> int:
	var t := 0
	if "draw_count" in n:
		t += int(n.get("draw_count"))
	for c in n.get_children():
		t += _sum(c)
	return t


static func _idle(ctx, name: String) -> void:
	for i in 6:
		await ctx.settle()
	var a := _sum(ctx.cur())
	for i in 90:
		await ctx.get_tree().process_frame
	var b := _sum(ctx.cur())
	print("IDLE|%s|%s|redraws=%d|counted=%d" % [ctx.variant, name, b - a, a])
	if b != a:
		ctx.problems.append("idle_%s_%s: %d redraws in 90 idle frames" % [name, ctx.variant, b - a])


static func run(ctx) -> void:
	await ctx.start_game(5)
	App.go(ScreenHub.new())
	await _idle(ctx, "home")
	App.go(ScreenRoster.new("hub"))
	await _idle(ctx, "squad")
	App.go(ScreenStandings.new())
	await _idle(ctx, "standings")
	var g: Dictionary = App.gs.next_game()
	var d := ScreenDraft.new(g)
	App.go(d)
	await ctx.settle()
	d._auto_rest()
	await _idle(ctx, "draft_done")
	App.go(ScreenGamePlan.new(g, d.draft))
	await _idle(ctx, "gameplan")
	(ctx.cur() as ScreenGamePlan).go_back()    # a new Draft screen on the finished draft (the old one was freed)
	await ctx.settle()
	(ctx.cur() as ScreenDraft)._start_match()
	await ctx.settle()
	(ctx.cur() as ScreenMatch)._skip()
	(ctx.cur() as ScreenMatch)._continue()
	await _idle(ctx, "report")
	GameState.delete_save()
