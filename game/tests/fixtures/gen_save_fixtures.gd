extends SceneTree
## One-off generator for save_0_6_{a,b,c}.json. Run from game/:
##   godot --headless --script res://tests/fixtures/gen_save_fixtures.gd
## These files stand for REAL Alpha 0.6 saves (no "tutorial" key, GameState.VERSION 1). They were written by
## the 0.6 game code at the start of I-00. DO NOT regenerate them with later code: a newer GameState may add
## keys, and then the fixtures stop testing the 0.1 to 0.6 upgrade path.
##   a: new game, round 1, nothing played
##   b: mid-season (6 league games played), custom plan with a trigger, a released player and a hired free agent,
##      a training focus, a different lineup
##   c: season over (phase "done"), before next_season()

const CLUB := "ironquill_wolves"
const OUT := "res://tests/fixtures/"


func _initialize() -> void:
	var w := World.load_default()
	_write("save_0_6_a.json", _a(w))
	_write("save_0_6_b.json", _b(World.load_default()))
	_write("save_0_6_c.json", _c(World.load_default()))
	print("fixtures written")
	quit(0)


func _a(w: World) -> GameState:
	return GameState.new_game(w, CLUB, 60601)


func _play(gs: GameState, n: int) -> void:
	for i in n:
		var g := gs.next_game()
		if g.is_empty():
			break
		gs.record_human_game(g, gs.auto_game(g))


func _b(w: World) -> GameState:
	var gs := GameState.new_game(w, w.club_ids[5], 60602)
	var late := GamePlan.neutral()
	late["g"] = -60
	late["l"] = 80
	late["t"] = 40
	late["jf"] = "bot"
	var behind := GamePlan.neutral()
	behind["r"] = 100
	behind["a"] = 30
	gs.d["plan"] = {"default": late, "triggers": [{"when": "behind_early", "plan": behind}]}
	_play(gs, 3)
	# release the last bench player (by id), then hire the first free agent who accepts a generous offer
	var bench: Array = []
	for pid in gs.d["roster"]:
		if not (gs.d["lineup"] as Dictionary).values().has(pid):
			bench.append(pid)
	bench.sort()
	print("release ", bench[-1], ": '", gs.release(bench[-1]), "'")
	var hired := ""
	for pid in (gs.d["fa"] as Array).duplicate():
		var r := gs.offer(pid, int(gs.asking_wage(pid) * 1.3), 2)
		print("offer ", pid, " -> ", r["code"])
		if r["code"] == "accepted":
			hired = pid
			break
	assert(hired != "")
	var any_player: String = (gs.d["roster"] as Array)[0]
	gs.set_focus(any_player, "stat", "mec")
	_play(gs, 3)
	return gs


func _c(w: World) -> GameState:
	var gs := GameState.new_game(w, w.club_ids[2], 60603)
	gs.autoplay(true)
	print("c phase: ", gs.d["phase"])
	return gs


func _write(name: String, gs: GameState) -> void:
	var f := FileAccess.open(OUT + name, FileAccess.WRITE)
	f.store_string(JSON.stringify(gs.d))
	f.close()
	print(name, " phase=", gs.d["phase"], " round=", gs.d["round"], " roster=", (gs.d["roster"] as Array).size(), " bytes=", JSON.stringify(gs.d).length())
