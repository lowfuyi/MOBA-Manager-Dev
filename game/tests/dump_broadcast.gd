extends Node
## tools/dump_broadcast.sh: prints a whole game's broadcast (intro, every line with show time, game clock, tier, excitement and
## the caster, the end lines). Games are made as in check_cast (AI drafts, real clubs). Env: DB_GAMES (how many to make,
## default 12), DB_PICK ("calm": the lowest mean excitement, "thriller": the highest, or a game index).


func _ready() -> void:
	var w := World.load_default()
	var meta := w.make_meta("cast-test")
	var n := int(OS.get_environment("DB_GAMES")) if OS.get_environment("DB_GAMES") != "" else 12
	var pick := OS.get_environment("DB_PICK") if OS.get_environment("DB_PICK") != "" else "thriller"
	var best: ArenaCast = null
	var best_v := 0.0
	for i in n:
		var r := MatchRunner.auto(w, w.best_lineup(w.club_ids[i % 10]), w.best_lineup(w.club_ids[(i + 3) % 10]), meta, 9100 + i, "cast:%d" % i, [1, 3, 5][i % 3], {"B": "ai", "R": "ai"})
		var pl := ArenaPlayer.build(r, "B" if i % 2 == 0 else "R")
		var c := ArenaCast.build(pl, "cast:%d" % i, {"B": w.clubs[w.club_ids[i % 10]]["name"], "R": w.clubs[w.club_ids[(i + 3) % 10]]["name"]})
		var mean := 0.0
		for v in c.e_grid:
			mean += v
		mean /= float(maxi(1, c.e_grid.size()))
		var v2 := -mean if pick == "calm" else (mean if pick == "thriller" else (1.0 if str(i) == pick else 0.0))
		if best == null or v2 > best_v:
			best = c
			best_v = v2
	print("BROADCAST game %s, %d lines, show %.0f s, game %s" % [best.game_id, best.lines.size(), best.pl.show_len, ArenaHud2.mmss(best.pl.end_t)])
	print(best.transcript())
	get_tree().quit()
