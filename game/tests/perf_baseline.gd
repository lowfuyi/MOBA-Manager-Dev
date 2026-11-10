extends "res://tests/ui_shots.gd"
## Performance probe and gate (PERF-BUDGET.md 3.1a and 7, build plan 3.3, 6 and I-00c). It IS the screenshot tour
## (tests/ui_shots.gd, every state of the real game on a fixed-seed save: new states added to the tour appear here
## by themselves), with shot() replaced by a measurement. It prints one line per state:
##   PERF|<state>|screen_nodes=N|visible=N|tree_nodes=N|draw_calls=N|objects=N|tex_mem=B|vid_mem=B|shadows=N|glows=N|frame_ms=F
## and judges each against tests/perf_allowances.json through tests/perf_gate.gd (the judging logic, tested headless
## in tests/perf_gate_tests.gd): legacy rows are limits (ratchet), redesigned screens meet the target or a waiver,
## a state with no row is held to the hard limits and printed NO ROW, "tighten to N" is printed when a row is 10 percent
## or more above what the state now needs. Exit 1 on any failure.
## Needs a renderer, so run under Xvfb with software OpenGL; headless draws nothing, so the probe says SKIPPED there:
##   xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 res://tests/perf_baseline.tscn
## Env PERF_ALLOWANCES=<path> reads another allowance file (used for negative controls). Env PERF_TABLE=1 also prints
## ready-to-paste JSON rows at the measured values (for a re-baseline).
## Numbers are from this computer (llvmpipe). Node, draw-call and memory counts carry over to a phone; frame_ms does not.

const Gate = preload("res://tests/perf_gate.gd")
const ALLOWANCES := "res://tests/perf_allowances.json"

var data: Dictionary = {}
var table_ok := false
var table_problems: Array = []
var rows: Array = []
var fails: Array = []
var visited: Array = []
var no_row := 0
var over_target := 0
var tighten := 0


func _count(n: Node) -> Array:
	var total := 1
	var vis := 1 if (n is CanvasItem and (n as CanvasItem).is_visible_in_tree()) else 0
	for c in n.get_children():
		var r := _count(c)
		total += r[0]
		vis += r[1]
	return [total, vis]


func shot(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var sc := _count(cur())
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var tex := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var vid := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var sh := Gate.count_shadows(cur())
	var t0 := Time.get_ticks_usec()
	for i in 10:
		await get_tree().process_frame
	var frame_ms := float(Time.get_ticks_usec() - t0) / 10000.0
	var m := {"nodes": sc[0], "draws": draws, "canvas": objs, "tex": tex, "vid": vid, "tree": get_tree().get_node_count(),
			"shadows": sh["shadows"], "glows": sh["glows"]}
	var j: Dictionary = Gate.judge(name, m, data)
	visited.append(name)
	rows.append(m)
	print("PERF|%s|screen_nodes=%d|visible=%d|tree_nodes=%d|draw_calls=%d|objects=%d|tex_mem=%d|vid_mem=%d|shadows=%d|glows=%d|frame_ms=%.1f" % [
			name, sc[0], sc[1], m["tree"], draws, objs, tex, vid, sh["shadows"], sh["glows"], frame_ms])
	for note in j["notes"]:
		print("PERF NOTE|%s|%s" % [name, note])
		if String(note).begins_with("NO ROW"):
			no_row += 1
		elif String(note).begins_with("tighten"):
			tighten += 1
	if j["over_target"]:
		over_target += 1
	for f in j["fails"]:
		fails.append(f)
	if OS.get_environment("PERF_TABLE") != "":
		print("ROW|\"%s\": {\"status\": \"legacy\", \"measured\": {\"draws\": %d, \"nodes\": %d}, \"draws\": %d, \"nodes\": %d}" % [
				name, draws, sc[0], Gate.allowance_for(draws), Gate.allowance_for(sc[0])])


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("PERF|SKIPPED|headless renderer draws nothing; run under xvfb-run with --rendering-driver opengl3")
		get_tree().quit(0)
		return
	as_module = true
	var path := OS.get_environment("PERF_ALLOWANCES")
	if path == "":
		path = ALLOWANCES
	var loaded: Dictionary = Gate.load_file(path)
	data = loaded["data"]
	table_ok = loaded["ok"]
	table_problems = loaded["problems"]
	for p in table_problems:
		print("PERF TABLE|", p)
		fails.append("allowance table: " + String(p))
	await get_tree().process_frame
	await _tour()
	var min_states := int(data.get("min_states", 6))
	if rows.size() < min_states:
		fails.append("only %d states visited, the allowance file expects at least %d (did the tour stop early?)" % [rows.size(), min_states])
	for s in Gate.stale_rows(data, visited):
		print("PERF NOTE|%s|STALE ROW (the tour no longer visits this state; delete the row or fix the name)" % s)
	var fc := UI.font_cache_size()
	var fj: Dictionary = Gate.judge_font_cache(fc, data)
	print("PERF|font_cache|variations=%d" % fc)
	if fj["fail"] != "":
		fails.append(fj["fail"])
	if fj["over_target"]:
		over_target += 1
	print("perf: %d states, %d over a target, %d without a row, %d rows to tighten, %d failures" % [
			rows.size(), over_target, no_row, tighten, fails.size()])
	for f in fails:
		print("PERF FAIL: ", f)
	App.set_large_text(false)
	App.set_colorblind(false)
	GameState.delete_save()
	get_tree().quit(1 if not fails.is_empty() else 0)
