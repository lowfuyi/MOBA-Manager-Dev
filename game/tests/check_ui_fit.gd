extends Node
## I-02 fit audit on the six main screens (Home, Squad, Draft, Game plan, Match report, Standings), at normal size
## (720 px canvas) and large text (626 px), headless. Same fixed-seed flow as tests/perf_baseline.gd, so the node
## counts can be compared with the I-00 baseline (within 10 percent). The rules are in tests/fit_audit.gd:
## no overflow, no clipped or mid-word-broken text, every button at least 96 x 96 px, text at least 24 px.
## Ends with " N checks, M failures".

const FitAudit = preload("res://tests/fit_audit.gd")
const BASELINE_NODES := {"home": 60, "squad": 36, "draft": 81, "game_plan": 133, "report": 151, "standings": 82}   # I-00, fixed seed
const SEED := 20261109

var checks := 0
var fails := 0
var node_rows: Array = []


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func cur() -> Control:
	return App.main._current


func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


func look(state: String, variant: String) -> void:
	for i in 3:
		await get_tree().process_frame
	var probs := FitAudit.audit(App.main, UI.canvas_w())
	var n := _count(cur())
	node_rows.append("%s %s nodes=%d" % [state, variant, n])
	if probs.is_empty():
		ok(true, "fit_%s_%s: clean (%d nodes)" % [state, variant, n])
	else:
		ok(false, "fit_%s_%s: %d problems" % [state, variant, probs.size()])
		for p in probs.slice(0, 12):
			print("     ", p)
	if variant == "normal":
		var base: int = BASELINE_NODES[state]
		ok(absi(n - base) <= int(ceil(base * 0.1)), "nodes_%s: %d against baseline %d (within 10 percent)" % [state, n, base])


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)    # a headless window is 100 x 100 until told otherwise
	await get_tree().process_frame
	for variant in ["normal", "large"]:
		await _flow(variant)
	App.apply_large_text(false)
	GameState.delete_save()
	print("nodes: " + " | ".join(node_rows))
	print("check_ui_fit: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _flow(variant: String) -> void:
	App.apply_large_text(variant == "large")
	await get_tree().process_frame
	ok(absf(get_viewport().get_visible_rect().size.x - UI.canvas_w()) < 1.0, "%s: the canvas is %.0f px wide" % [variant, get_viewport().get_visible_rect().size.x])
	GameState.delete_save()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	UI.animate = false
	await get_tree().process_frame
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], SEED)
	App.autosave()
	App.go(ScreenHub.new())
	await look("home", variant)
	App.go(ScreenRoster.new("hub"))
	await look("squad", variant)
	var g: Dictionary = App.gs.next_game()
	var d := ScreenDraft.new(g)
	App.go(d)
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
	await look("draft", variant)
	d._auto_rest()
	var gp := ScreenGamePlan.new(g, d.draft)
	App.go(gp)
	gp._coach()
	gp._set_tab("behind_early")
	gp._toggle_trigger()
	gp._set_value("r", 100)
	await look("game_plan", variant)
	gp.go_back()
	d = cur()
	d._start_match()
	var m: ScreenMatch = cur()
	m._skip()
	m._continue()
	await look("report", variant)
	cur()._leave()
	App.go(ScreenStandings.new())
	await look("standings", variant)
	main.queue_free()
	await get_tree().process_frame
