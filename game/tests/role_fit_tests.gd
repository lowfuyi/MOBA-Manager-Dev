extends RefCounted
## Role fit (0.12, ESMO Q4-1): the numbers shown are the game's own (World.slot_score, World.player_fit, SLOT_W).


func run(check: Callable) -> void:
	var w := World.load_default()
	var same := true
	var pct_ok := true
	var train_ok := true
	var target_ok := true
	var n := 0
	for pid in w.players:
		n += 1
		if n > 60:
			break
		var p: Dictionary = w.players[pid]
		for s in World.SLOTS:
			same = same and is_equal_approx(RoleFit.rating(w, p, s), w.slot_score(p, s))
			var k := RoleFit.kind(w, p, s)
			var want := 100 if k == "main" else (93 if k == "second" else 80)
			pct_ok = pct_ok and RoleFit.pct(w, p, s) == want
			var tr := RoleFit.train_for(p, s)
			train_ok = train_ok and tr.size() == 2 and tr[0] != tr[1] and World.STATS.has(tr[0]) and World.STATS.has(tr[1])
			# no stat with room outweighs the first pick
			var wts: Array = World.SLOT_W[s]
			var w0 := float(wts[World.STATS.find(tr[0])])
			for i in wts.size():
				var st: String = World.STATS[i]
				if float(p["potential"][st]) - float(p["stats"][st]) >= 1.0 and float(wts[i]) > w0 + 1e-9:
					train_ok = false
		var mt := RoleFit.move_target(w, p)
		target_ok = target_ok and mt != String(p["role_primary"]) and World.SLOTS.has(mt)
	check.call(same, "role fit: the lane rating is World.slot_score")
	check.call(pct_ok, "role fit: main 100%, second 93%, off 80% (World.player_fit)")
	check.call(train_ok, "role fit: the two stats to train are the lane's heaviest weights with room to grow")
	check.call(target_ok, "role fit: the move target is another lane (the second role first)")
