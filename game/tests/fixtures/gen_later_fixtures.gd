extends SceneTree
## Alpha 0.9: the save_0_7_* and save_0_8_* fixtures were written by this script run inside git worktrees of 239620d (0.7.0) and
## 5bb1b13 (0.8.0) with their own code (run from that checkout's game/: PREFIX=save_0_7 OUTDIR=<abs fixtures dir> godot --headless
## --script res://gen_later.gd). DO NOT regenerate them with later code.
## Writes three saves with the CODE OF THIS CHECKOUT (run inside an old worktree): <prefix>_a (new game, guide state "new"),
## <prefix>_b (6 games, a custom plan with a trigger, guide "done"), <prefix>_c (season over, guide "skipped").
func _initialize() -> void:
	var prefix := OS.get_environment("PREFIX")
	var out := OS.get_environment("OUTDIR")
	var w := World.load_default()
	var a := GameState.new_game(w, w.club_ids[1], 70701)
	_write(out, prefix + "_a.json", a)
	var b := GameState.new_game(World.load_default(), w.club_ids[5], 70702)
	var late := GamePlan.neutral()
	late["g"] = -60
	late["l"] = 80
	var behind := GamePlan.neutral()
	behind["r"] = 100
	b.d["plan"] = {"default": late, "triggers": [{"when": "behind_early", "plan": behind}]}
	b.d["tutorial"]["state"] = "done"
	for i in 6:
		var g := b.next_game()
		if g.is_empty():
			break
		b.record_human_game(g, b.auto_game(g))
	_write(out, prefix + "_b.json", b)
	var c := GameState.new_game(World.load_default(), w.club_ids[2], 70703)
	c.d["tutorial"]["state"] = "skipped"
	c.autoplay(true)
	_write(out, prefix + "_c.json", c)
	print("written ", prefix, " phase c ", c.d["phase"])
	quit(0)


func _write(out: String, name: String, gs: GameState) -> void:
	var f := FileAccess.open(out + "/" + name, FileAccess.WRITE)
	f.store_string(JSON.stringify(gs.d))
	f.close()
