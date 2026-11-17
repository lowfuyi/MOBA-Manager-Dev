extends RefCounted
## Matrix module "squad" (I-19): the Squad in the states of the build plan, measured with a renderer against PERF-BUDGET 3.1a
## (a redesigned screen: target 60 draw calls and 120 nodes, hard 100 and 200):
##   SQUAD|<variant>|<state>|nodes=..|draw_calls=..
## States: closed (the map and the top of the bench), lower (scrolled to the bench's end), picker (the lane picker open), card
## (the player sheet, Overview), card_stats, card_career, release (the confirm sheet), matchday (opened from Pre-match: Done).
## Over the hard limit, or a screen state (no sheet open) over the target, is added to ctx.problems.
##   SHOT_DIR=<dir> SCREENS=squad VARIANTS=normal,large,cb,tall xvfb-run -a -s "-screen 0 720x1280x24" \
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
	var r := ctx.cur() as ScreenRoster
	var nodes := _count(r)
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("SQUAD|%s|%s|nodes=%d|draw_calls=%d" % [ctx.variant, state, nodes, calls])
	if calls > HARD_CALLS or nodes > HARD_NODES:
		ctx.problems.append("squad_%s_%s: %d draw calls and %d nodes (hard limits %d and %d)" % [state, ctx.variant, calls, nodes, HARD_CALLS, HARD_NODES])
	if not BottomSheet.is_open() and calls > TARGET_CALLS:
		ctx.problems.append("squad_%s_%s: %d draw calls (target %d for the screen states)" % [state, ctx.variant, calls, TARGET_CALLS])
	await ctx.shot(state)


static func _close(ctx) -> void:
	if BottomSheet.is_open():
		BottomSheet.current().close()
	for i in 4:
		await ctx.settle()


static func run(ctx) -> void:
	await ctx.start_game(5)
	var rs := ScreenRoster.new("hub")
	App.go(rs)
	await ctx.settle()
	await _measure(ctx, "closed")
	rs.page_scroll.scroll_vertical = 100000
	await _measure(ctx, "lower")
	rs.page_scroll.scroll_vertical = 0
	rs._toggle_slot("mid")
	await _measure(ctx, "picker")
	await _close(ctx)
	var pid := String(rs.bench_ids()[0])
	rs._toggle_player(pid)
	await _measure(ctx, "card")
	rs._set_card_tab("stats")
	await _measure(ctx, "card_stats")
	rs._set_card_tab("career")
	await _measure(ctx, "card_career")
	rs._ask_release(pid)
	await _measure(ctx, "release")
	await _close(ctx)
	var g: Dictionary = App.gs.next_game()
	var md := ScreenRoster.new("prematch", g)
	App.go(md)
	await ctx.settle()
	await _measure(ctx, "matchday")
	GameState.delete_save()
