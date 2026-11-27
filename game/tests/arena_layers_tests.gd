extends RefCounted
## Match Day M5 map layers on real v2 games: objective countdowns (back at the log's next obj_up, none while up), the level
## shown on tokens (from the log's level events, never falling), team call words (group, siege, defend have words), and
## the line-up panel's numbers (K/D/A equal Report.kda at the end). Display only: nothing here reads the simulation.


func run(check: Callable) -> void:
	var w := World.load_default()
	var meta := w.make_meta("layers-test")
	var cd_ok := true
	var cd_n := 0
	var up_ok := true
	var lvl_ok := true
	var kda_ok := true
	for i in 4:
		var r := MatchRunner.auto(w, w.best_lineup(w.club_ids[i % 10]), w.best_lineup(w.club_ids[(i + 5) % 10]), meta, 7300 + i, "layers:%d" % i, 5, {"B": "ai", "R": "ai"})
		var pl := ArenaPlayer.build(r, "B")
		for o in pl.objs:
			var t := float(o[0]) + 1.0
			var cd := ArenaView.countdown(pl, String(o[1]), t)
			var nxt := INF
			for u in pl.obj_up:
				if String(u[1]) == String(o[1]) and float(u[0]) > t:
					nxt = minf(nxt, float(u[0]))
			if nxt <= pl.end_t:
				cd_n += 1
				cd_ok = cd_ok and not cd.is_empty() and is_equal_approx(float(cd["back"]), nxt) and is_equal_approx(float(cd["since"]), float(o[0]))
		for u in pl.obj_up:
			up_ok = up_ok and ArenaView.countdown(pl, String(u[1]), float(u[0]) + 0.01).is_empty()
		for key in pl.hero_of:
			var last := 1
			var g := 0.0
			while g <= pl.end_t:
				var lv := pl.level_of(String(key), g)
				lvl_ok = lvl_ok and lv >= last and lv >= 1 and lv <= 18
				last = lv
				g += 30.0
		var kd := Report.kda(r)
		for key in pl.hero_of:
			var a := pl.kda_of(String(key), pl.end_t)
			var per: Dictionary = kd[String(key).substr(0, 1)][String(key).substr(2)]
			kda_ok = kda_ok and int(a[0]) == int(per["k"]) and int(a[1]) == int(per["d"]) and int(a[2]) == int(per["a"])
	check.call(cd_ok and cd_n > 0, "layers: a taken objective counts down to its next appearance (%d countdowns checked)" % cd_n)
	check.call(up_ok, "layers: no countdown while an objective is up")
	check.call(lvl_ok, "layers: token levels come from the log and never fall")
	check.call(kda_ok, "layers: the panel's K/D/A at the end equal Report.kda")
	# (run_tests loads no string table, so the words are checked in en.json; intent_word maps a call to its key)
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/en.json"))
	for c in ["call_group", "call_siege", "call_defend", "gank"]:
		check.call(en.has("arena2.intent." + c) and String(en["arena2.intent." + c]) != "", "layers: intent word for %s in en.json" % c)
	var src_v := FileAccess.get_file_as_string("res://src/arena/v2/arena_view.gd")
	check.call(src_v.contains('"call_group", "call_siege", "call_defend"'), "layers: intent_word accepts the three team calls")
	var src := FileAccess.get_file_as_string("res://src/arena/v2/arena_view.gd") + FileAccess.get_file_as_string("res://src/arena/v2/arena_lineup.gd")
	check.call(not src.contains("MatchSim") and not src.contains("GamePlan.simulate") and not src.contains("Report.attribution"), "layers: display only (A1)")
