extends RefCounted
## Matrix module "arena" (Alpha 0.8 A-02): the baked map alone, placed where the Match screen puts it (y 190 to 950 at 720 x 1280),
## with the numbers of the frame (PERF-BUDGET 3.1a, hard limits 100 draw calls and 200 nodes for the whole frame):
##   ARENA|<variant>|<state>|nodes=..|draw_calls=..
## States: blue (you are Blue, zoom 1.0), red (you are Red: the picture is mirrored), focus (zoom 1.3 on Stoneback with four
## towers down: place names show), island (zoom 1.3 on the Moonhulk isle); then one real game with every layer (A-03
## tokens, A-04 effects and camera) at t = 3, 13.8, 32.9, 34.1, 44, 45.3, 66, 72.8 and 74.3 s (play_<t>).

const HARD_CALLS := 100
const HARD_NODES := 200


static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


## The whole match layout (UI-PASS-2 6.7.2; 6.7.7 in large text) with a board and a feed at show time t (A-05).
static func _full(ctx, sc: ShowScript, ch: Choreo, fx: ArenaFx, t: float) -> ArenaMap:
	var m := _stage(ctx, sc.my_side)
	var vw: float = ctx.get_viewport().get_visible_rect().size.x
	var large := UI.large
	var safe := 48.0
	var board_h := 122.0 if large else 142.0
	m.size = Vector2(vw, vw * 760.0 / 720.0)
	m.position = Vector2(0, safe + board_h)
	var board := ArenaHud.Board.new(sc, m.texture(), "Northreach Corsairs", "Ironvale Wardens")
	board.position = Vector2(0, safe)
	board.size = Vector2(vw, board_h)
	m.get_parent().add_child(board)
	var feed := ArenaHud.Feed.new(sc, "Corsairs")
	var strip_y := m.position.y + m.size.y
	feed.position = Vector2(24, strip_y + (8.0 if large else 108.0))
	feed.size = Vector2(vw - 48.0, 38.0 if large else 80.0)
	m.get_parent().add_child(feed)
	m.set_heroes(sc.res)
	fx.apply(m, t)
	board.show_at(t)
	feed.show_at(t)
	return m


static func _stage(ctx, side: String) -> ArenaMap:
	for c in ctx.get_children():
		if c.name == "ArenaStage":
			c.free()
	var root := Control.new()
	root.name = "ArenaStage"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var m := ArenaMap.new(side)
	m.position = Vector2(0, 190)
	m.size = ArenaMap.MAP
	root.add_child(m)
	ctx.add_child(root)
	return m


static func _measure(ctx, m: ArenaMap, state: String) -> void:
	await ctx.settle()
	await ctx.settle()
	var nodes := _count(m.get_parent())
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("ARENA|%s|%s|nodes=%d|draw_calls=%d" % [ctx.variant, state, nodes, calls])
	if calls > HARD_CALLS or nodes > HARD_NODES:
		ctx.problems.append("arena_%s_%s: %d draw calls and %d nodes" % [state, ctx.variant, calls, nodes])
	await ctx.shot(state)


static func run(ctx) -> void:
	App.main.visible = false
	var m := _stage(ctx, "B")
	await _measure(ctx, m, "blue")
	m = _stage(ctx, "R")
	await _measure(ctx, m, "red")
	m = _stage(ctx, "B")
	for id in ["R.bot.outer", "R.bot.inner", "R.mid.outer", "B.top.outer"]:
		m.fallen[id] = true
	m.look_at_point(m.arena_px(ArenaData.node("N.stoneback")), 1.3)
	await _measure(ctx, m, "focus")
	m.look_at_point(m.arena_px(ArenaData.node("N.moonhulk")), 1.3)
	await _measure(ctx, m, "island")
	var w := App.world
	var res := MatchRunner.auto(w, w.best_lineup(w.club_ids[1]), w.best_lineup(w.club_ids[6]), w.make_meta("shots"), 777, "shots:arena", false, {"B": "ai", "R": "ai"})
	var sc := ShowScript.build(res, "B")
	var ch := Choreo.build(sc)
	print("ARENA|game|winner %s held %s variant %s kills %s" % [sc.winner, sc.held, ch.variant, str(sc.kill_count)])
	var fx := ArenaFx.build(sc, ch, "B")
	for t in [3.0, 13.8, 32.9, 34.1, 44.0, 45.3, 66.0, 72.8, 74.3, 75.0]:
		m = _full(ctx, sc, ch, fx, t)
		await _measure(ctx, m, "play_%s" % str(t).replace(".", "_"))
	# the other seat: the same game seen from Red (the loser here or the winner), mid-game
	var sc_r := ShowScript.build(res, "R")
	var ch_r := Choreo.build(sc_r)
	m = _full(ctx, sc_r, ch_r, ArenaFx.build(sc_r, ch_r, "R"), 46.0)
	await _measure(ctx, m, "seat_red_46")
	for c in ctx.get_children():
		if c.name == "ArenaStage":
			c.queue_free()
	App.main.visible = true
