extends Node
## Performance probe and gate (PERF-BUDGET.md 7, build plan 3.3 and 6). Visits the six main screens of the real
## game, waits until a frame is drawn, and prints one line per screen:
##   PERF|<state>|screen_nodes=N|visible=N|tree_nodes=N|draw_calls=N|objects=N|tex_mem=BYTES|vid_mem=BYTES|frame_ms=F
## It then FAILS (exit 1) when a screen is over a hard limit: nodes 200, draw calls 100, texture memory 48 MB.
## Needs a renderer, so run under Xvfb with software OpenGL, never in the headless loop (headless draws nothing,
## so the probe says SKIPPED there and exits 0):
##   xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 res://tests/perf_baseline.tscn
## Numbers are from this computer (llvmpipe). Node, draw-call and memory counts carry over to a phone; frame_ms does not.

const HARD_NODES := 200
const HARD_DRAWS := 100
const HARD_TEX_BYTES := 48 * 1024 * 1024
const TARGET_NODES := 120
const TARGET_DRAWS := 60
const TARGET_TEX_BYTES := 32 * 1024 * 1024

var rows: Array = []
var over: Array = []


func cur() -> Control:
	return App.main._current


func _count(n: Node) -> Array:
	var total := 1
	var vis := 1 if (n is CanvasItem and (n as CanvasItem).is_visible_in_tree()) else 0
	for c in n.get_children():
		var r := _count(c)
		total += r[0]
		vis += r[1]
	return [total, vis]


func probe(state: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var sc := _count(cur())
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var tex := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var t0 := Time.get_ticks_usec()
	for i in 10:
		await get_tree().process_frame
	var frame_ms := float(Time.get_ticks_usec() - t0) / 10000.0
	var row := {"state": state, "nodes": sc[0], "visible": sc[1], "tree": get_tree().get_node_count(), "draws": draws,
			"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), "tex": tex,
			"vid": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)), "frame_ms": frame_ms}
	rows.append(row)
	print("PERF|%s|screen_nodes=%d|visible=%d|tree_nodes=%d|draw_calls=%d|objects=%d|tex_mem=%d|vid_mem=%d|frame_ms=%.1f" % [
			state, row["nodes"], row["visible"], row["tree"], row["draws"], row["objects"], row["tex"], row["vid"], row["frame_ms"]])
	if int(row["nodes"]) > HARD_NODES:
		over.append("%s: %d nodes (hard limit %d)" % [state, row["nodes"], HARD_NODES])
	if draws > HARD_DRAWS:
		over.append("%s: %d draw calls (hard limit %d)" % [state, draws, HARD_DRAWS])
	if tex > HARD_TEX_BYTES:
		over.append("%s: %d bytes of texture memory (hard limit %d)" % [state, tex, HARD_TEX_BYTES])


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("PERF|SKIPPED|headless renderer draws nothing; run under xvfb-run with --rendering-driver opengl3")
		get_tree().quit(0)
		return
	await get_tree().process_frame
	await _run()
	var soft := 0
	for r in rows:
		if int(r["nodes"]) > TARGET_NODES or int(r["draws"]) > TARGET_DRAWS or int(r["tex"]) > TARGET_TEX_BYTES:
			soft += 1
	print("perf: %d screens, %d over a target (nodes %d, draw calls %d, texture %d MB), %d over a hard limit" % [
			rows.size(), soft, TARGET_NODES, TARGET_DRAWS, TARGET_TEX_BYTES / 1048576, over.size()])
	for o in over:
		print("PERF FAIL: ", o)
	GameState.delete_save()
	get_tree().quit(1 if (not over.is_empty() or rows.size() != 6) else 0)


## The six screens of UI-PASS-2: Home, Squad, Draft, Game plan, Match report, Standings (the Alpha 0.6 versions).
func _run() -> void:
	GameState.delete_save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	UI.animate = false
	await get_tree().process_frame
	# fixed seed (the club screen seeds from the clock) so every run measures the same game
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], 20261109)
	App.autosave()
	App.go(ScreenHub.new())
	await probe("home")
	var rs := ScreenRoster.new("hub")
	App.go(rs)
	await probe("squad")
	var g: Dictionary = App.gs.next_game()
	var d := ScreenDraft.new(g)
	App.go(d)
	# first turn of the managed club that is a ban (the "ban step" of PERF-BUDGET.md 2)
	var n := 0
	while not d.draft.is_done() and n < 100:
		n += 1
		var c: Dictionary = d.draft.current()
		if c["team"] == d.my_side and c["kind"] == "ban":
			break
		if c["team"] == d.my_side:
			d._on_hero(d.draft.avail[3], "pick")
			d._apply({"hero": d._sel_hero, "slot": d.draft.open_slots(d.my_side)[0]})
		else:
			d._process(5.0)
	await probe("draft")
	d._auto_rest()
	var gp := ScreenGamePlan.new(g, d.draft)
	App.go(gp)
	gp._coach()
	gp._set_tab("behind_early")
	gp._toggle_trigger()
	gp._set_value("r", 100)
	await probe("game_plan")
	gp.go_back()
	d = cur()
	d._start_match()
	var m: ScreenMatch = cur()
	m._skip()
	m._continue()
	await probe("report")
	cur()._leave()
	App.go(ScreenStandings.new())
	await probe("standings")
