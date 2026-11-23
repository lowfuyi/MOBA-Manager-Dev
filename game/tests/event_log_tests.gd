extends RefCounted
## Event log (0.12, overnight Q3): every ward event carries the warder's exact spot, and the log flags decisive plays (a fight
## with decisive_kills kills or more, a Cairn falling) so the Action camera reads them instead of guessing. Additive.


func run(check: Callable) -> void:
	var w := World.load_default()
	var meta := w.make_meta("evlog-test")
	var wards := 0
	var ward_ok := true
	var dec_ok := true
	var dec_n := 0
	var missed := 0
	var cairn_ok := true
	var cairn_games := 0
	var chase_ok := true
	var need := int(SimData.params()["decisive_kills"])
	for i in 4:
		var r := MatchRunner.auto(w, w.best_lineup(w.club_ids[i]), w.best_lineup(w.club_ids[i + 5]), meta, 8300 + i, "evlog:%d" % i, 3, {"B": "ai", "R": "ai"})
		var ev: Array = r["sim"]["log"]["ev"]
		var cur := -1
		var kills := 0
		var flagged := {}
		var counted := {}
		for e in ev:
			match String(e[1]):
				"ward":
					wards += 1
					var ok: bool = e.size() > 4 and e[4] is Array and (e[4] as Array).size() == 2
					if ok:
						var x := float(e[4][0])
						var y := float(e[4][1])
						ok = x >= -0.1 and x <= 1.1 and y >= -0.1 and y <= 1.1
					ward_ok = ward_ok and ok
				"fight":
					cur = int(e[2])
					kills = 0
				"kill":
					if cur >= 0:
						kills += 1
				"fight_end":
					counted[int(e[2])] = kills
					cur = -1
				"decisive":
					if String(e[2]) == "fight":
						flagged[int(e[3])] = int(e[4])
						dec_n += 1
		for fid in counted:
			var want: bool = int(counted[fid]) >= need
			if want != flagged.has(fid):
				dec_ok = false
				missed += 1
			elif want and int(flagged[fid]) != int(counted[fid]):
				dec_ok = false
		var reason := ""
		for e3 in ev:
			if String(e3[1]) == "end":
				reason = String(e3[3])
		if reason == "cairn":
			cairn_games += 1
			var seen := false
			for e2 in ev:
				if String(e2[1]) == "decisive" and String(e2[2]) == "cairn":
					seen = true
			cairn_ok = cairn_ok and seen
		var pl := ArenaPlayer.build(r, "B")
		var ch := ArenaChase.build(pl, null)
		chase_ok = chase_ok and ch.from_flags == (dec_n > 0 or cairn_games > 0)
		for f in pl.fights:
			chase_ok = chase_ok and (int(ch._fight_kills.get(int(f["id"]), 0)) >= ch.decisive_kills) == flagged.has(int(f["id"]))
	check.call(wards > 0 and ward_ok, "event log: %d ward events each carry the warder's exact spot on the map" % wards)
	check.call(dec_n > 0 and dec_ok, "event log: a fight is flagged decisive exactly when it has %d kills or more (%d flagged, %d wrong)" % [need, dec_n, missed])
	check.call(cairn_games > 0 and cairn_ok, "event log: every game won on a Cairn logs it as decisive (%d games)" % cairn_games)
	check.call(chase_ok, "event log: the Action camera takes decisive fights from the log's flags")
