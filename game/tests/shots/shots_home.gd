extends RefCounted
## Matrix module "home" (I-15): Home in the states of the build plan, plus its numbers measured with a renderer against PERF-BUDGET
## 3.1a for a redesigned screen (target 60 draw calls and 120 nodes, hard limit 100 and 200; the whole frame is counted, tab bar
## included):
##   HOME|<variant>|<state>|nodes=..|draw_calls=..|play_bottom=..|fold=..
## States: first (round 1, the 19-character club "Northreach Corsairs"), offer (a legacy save: the inline offer card, the worst case
## for "Play above the fold"), lower (scrolled to the tiles), mid (round 10: contracts and tired cards, 5-digit cash), debt,
## playoffs, done. The hard limit failing, or Play below the fold, is added to ctx.problems (the runner exits 1).
##   SHOT_DIR=<dir> SCREENS=home VARIANTS=normal,large,cb,tall xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 res://tests/shots_matrix.tscn

const HARD_CALLS := 100
const HARD_NODES := 200
const TEMP_CFG := "user://shots_home.cfg"


static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


static func _calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


static func _home(ctx) -> void:
	App.go(ScreenHub.new())
	for i in 4:
		await ctx.get_tree().process_frame
	await RenderingServer.frame_post_draw


static func _measure(ctx, state: String) -> void:
	await ctx.settle()
	await ctx.settle()    # the second frame: the first one after a screen change also counts one-off uploads
	var hub := ctx.cur() as ScreenHub
	var nodes := _count(hub)
	var calls := _calls()
	var fold: float = ctx.get_viewport().get_visible_rect().size.y - float(UI.TAB_H) - 12.0
	var pb: float = hub.play_button.get_global_rect().end.y if hub != null and hub.play_button != null and is_instance_valid(hub.play_button) else -1.0
	print("HOME|%s|%s|nodes=%d|draw_calls=%d|play_bottom=%.0f|fold=%.0f" % [ctx.variant, state, nodes, calls, pb, fold])
	if calls > HARD_CALLS or nodes > HARD_NODES:
		ctx.problems.append("home_%s_%s: %d draw calls and %d nodes (hard limits %d and %d)" % [state, ctx.variant, calls, nodes, HARD_CALLS, HARD_NODES])
	if pb > fold + 0.5:
		ctx.problems.append("home_%s_%s: Play ends at y %.0f, below the fold at %.0f" % [state, ctx.variant, pb, fold])
	await ctx.shot(state)


static func _scroll_bottom(ctx) -> void:
	var sc: ScrollContainer = (ctx.cur() as Node).find_children("*", "ScrollContainer", true, false)[0]
	sc.scroll_vertical = 100000
	await ctx.settle()


static func run(ctx) -> void:
	var nr := App.world.club_ids.find("northreach_corsairs")
	await ctx.start_game(nr if nr >= 0 else 5)
	await _home(ctx)
	await _measure(ctx, "first")
	await _scroll_bottom(ctx)
	await ctx.shot("lower")
	# the inline offer card (a legacy save on a device that has not answered): the worst case for Play above the fold
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	App.tutorial.device = DeviceState.new(TEMP_CFG)
	App.tutorial.autosave = false
	App.gs.d["tutorial"] = TutorialState.legacy_state()
	App.tutorial.bind()
	TutorialRunner.home_offers = true
	await _home(ctx)
	await _measure(ctx, "offer")
	TutorialRunner.home_offers = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	# mid-season: round 10, contracts end, 5-digit cash
	var gs: GameState = App.gs
	while int(gs.d["round"]) < 9 and gs.d["phase"] == "league":
		var g := gs.next_game()
		gs.record_human_game(g, gs.auto_game(g))
	gs.d["cash"] = 48250.0
	await _home(ctx)
	await _measure(ctx, "mid")
	# 0.12 Q4-7: Auto-play the rest of the league (the button, the confirm sheet, the results), on a copy of the save
	var keep := App.gs
	App.gs = GameState.from_dict(App.world, JSON.parse_string(JSON.stringify(keep.d)))
	await _home(ctx)
	var h7 := ctx.cur() as ScreenHub
	if h7 != null and h7.rest_button != null:
		h7._open_rest()
		await ctx.settle()
		await ctx.shot("rest_confirm")
		h7._play_rest()
		await ctx.settle()
		await ctx.shot("rest_done")
		if BottomSheet.is_open():
			BottomSheet.current().close()
			await ctx.settle()
	App.gs = keep
	await _home(ctx)
	await _scroll_bottom(ctx)
	await ctx.shot("mid_lower")
	gs.d["cash"] = -1200.0
	await _home(ctx)
	await _measure(ctx, "debt")
	gs.d["cash"] = 48250.0
	gs.autoplay(false)
	await _home(ctx)
	await _measure(ctx, "playoffs")
	gs.autoplay(true)
	await _home(ctx)
	await _measure(ctx, "done")
	GameState.delete_save()
