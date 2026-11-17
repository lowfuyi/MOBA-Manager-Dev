extends RefCounted
## Matrix module "help" (I-22): one help sheet (Squad), a word opened in place, the Glossary list and a term sheet, measured against
## the hard limits (100 draw calls, 200 nodes; a sheet is measured with the screen under it):
##   HELP|<variant>|<state>|nodes=..|draw_calls=..
##   SHOT_DIR=<dir> SCREENS=help VARIANTS=normal,large,cb,tall xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 res://tests/shots_matrix.tscn

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
	print("HELP|%s|%s|nodes=%d|draw_calls=%d" % [ctx.variant, state, nodes, calls])
	if calls > 100 or nodes > 200:
		ctx.problems.append("help_%s_%s: %d draw calls and %d nodes (hard 100 / 200)" % [state, ctx.variant, calls, nodes])
	await ctx.shot(state)


static func run(ctx) -> void:
	await ctx.start_game(5)
	App.tutorial.device.help_reset()
	App.go(ScreenRoster.new("hub"))
	await ctx.settle()
	await _measure(ctx, "dot")
	HelpSheet.open("squad")
	await _measure(ctx, "sheet")
	(UI.find_tag("help.term.fatigue") as Button).pressed.emit()
	await _measure(ctx, "term")
	BottomSheet.current().close()
	await ctx.settle()
	App.go(ScreenGlossary.new())
	await ctx.settle()
	await _measure(ctx, "glossary")
	(ctx.cur() as ScreenGlossary).terms.press(0)
	await _measure(ctx, "glossary_term")
	BottomSheet.current().close()
	await ctx.settle()
	GameState.delete_save()
