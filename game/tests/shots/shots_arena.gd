extends RefCounted
## Matrix module "arena" (Alpha 0.8 A-02): the baked map alone, placed where the Match screen puts it (y 190 to 950 at 720 x 1280),
## with the numbers of the frame (PERF-BUDGET 3.1a, hard limits 100 draw calls and 200 nodes for the whole frame):
##   ARENA|<variant>|<state>|nodes=..|draw_calls=..
## States: blue (you are Blue, zoom 1.0), red (you are Red: the picture is mirrored), focus (zoom 1.3 on Stoneback with four
## towers down: place names show), island (zoom 1.3 on the Moonhulk isle); then one real game (A-03) at t = 3, 13, 32.5, 44,
## 66 and 73.5 s: the tokens, minion waves, deaths and fallen towers of that moment (play_<t>).

const HARD_CALLS := 100
const HARD_NODES := 200


static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


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
	for t in [3.0, 13.0, 32.5, 44.0, 66.0, 73.5]:
		m = _stage(ctx, "B")
		for tw in sc.towers:
			if float(tw["t"]) <= t:
				m.fallen[String(tw["id"])] = true
		m.sprites = ch.sprites_at(t, "B")
		await _measure(ctx, m, "play_%s" % str(t).replace(".", "_"))
	for c in ctx.get_children():
		if c.name == "ArenaStage":
			c.queue_free()
	App.main.visible = true
