extends RefCounted
## Arena match views (Founder decision 2026-11-22): ArenaVision (what a team sees) and ArenaChase (what the Action camera looks
## at). Pure logic over real Match Sim v2 results. Auto-discovered by run_tests.gd.
##   vision   own living heroes are always seen; an enemy far from every source is not; the mask matches sees(); a ward gives
##            vision for its duration only; same t, same mask
##   chase    never leaves a target before the minimum dwell; prefers an objective or decisive play over a kill; with fog it
##            only chases what the team sees; without fog (All) every event counts

const SLOTS := ["top", "jg", "mid", "bot", "sup"]


func run(check: Callable) -> void:
	var w := World.load_default()
	var meta := w.make_meta("views-test")
	var results: Array = []
	for i in 3:
		results.append(MatchRunner.auto(w, w.best_lineup(w.club_ids[i]), w.best_lineup(w.club_ids[i + 4]), meta, 8100 + i, "views:%d" % i, 3, {"B": "ai", "R": "ai"}))
	_vision(check, results)
	_chase(check, results)


func _vision(check: Callable, results: Array) -> void:
	var own_ok := true
	var enemy_hidden := 0
	var enemy_seen := 0
	var mask_ok := true
	var frac: Array = []
	for r in results:
		for side in ["B", "R"]:
			var pl := ArenaPlayer.build(r, side)
			var v := ArenaVision.build(pl, side)
			var other := "R" if side == "B" else "B"
			var t := 30.0
			while t < pl.end_t:
				for s in SLOTS:
					var key: String = side + "." + s
					if pl.alive(key, t) and not v.sees(pl.pos(key, t), t):
						own_ok = false
					var ek: String = other + "." + s
					if pl.alive(ek, t):
						if v.sees(pl.pos(ek, t), t):
							enemy_seen += 1
						else:
							enemy_hidden += 1
				t += 37.0
			var tm := pl.end_t * 0.5
			var img := v.mask(tm)
			var n := v.cells
			var seen := 0
			for j in n:
				for i in n:
					if img.get_pixel(i, j).a < 0.5:
						seen += 1
			frac.append(float(seen) / float(n * n))
			# a cell centre well inside a source is seen in the mask
			for src in v.sources(tm):
				var c: Vector2 = src[0]
				var m := ArenaGround.MARGIN
				var ci := int((c.x + m) / (1.0 + 2.0 * m) * n)
				var cj := int((c.y + m) / (1.0 + 2.0 * m) * n)
				if ci >= 0 and ci < n and cj >= 0 and cj < n and img.get_pixel(ci, cj).a > 0.5:
					mask_ok = false
			mask_ok = mask_ok and v.mask(tm).get_data() == img.get_data()
	check.call(own_ok, "vision: a team always sees its own living heroes")
	check.call(enemy_hidden > 0 and enemy_seen > 0, "vision: enemies are sometimes seen and sometimes hidden (%d seen, %d hidden)" % [enemy_seen, enemy_hidden])
	check.call(mask_ok, "vision: the mask is clear under every source and the same for the same t")
	var fmin: float = frac.min()
	var fmax: float = frac.max()
	check.call(fmin > 0.04 and fmax < 0.75, "vision: mid-game a team sees part of the map, not all of it (%.2f to %.2f of the mask)" % [fmin, fmax])
	# wards
	var ward_ok := true
	var wards := 0
	for r2 in results:
		var pl2 := ArenaPlayer.build(r2, "B")
		var v2 := ArenaVision.build(pl2, "B")
		for wd in v2.wards:
			wards += 1
			var during := false
			for s2 in v2.sources(float(wd[0]) + 1.0):
				if (s2[0] as Vector2).distance_to(wd[2]) < 1e-6:
					during = true
			var after := false
			# a new ward on the same spot (placed again before this one ran out) is not this ward outliving its time
			var t_after := float(wd[1]) + 1.0
			var replaced := false
			for o in v2.wards:
				if o != wd and (o[2] as Vector2).distance_to(wd[2]) < 1e-6 and float(o[0]) <= t_after and t_after <= float(o[1]):
					replaced = true
			for s3 in ([] if replaced else v2.sources(t_after)):
				if (s3[0] as Vector2).distance_to(wd[2]) < 1e-6 and absf(float(s3[1]) - float(v2.radii["ward"])) < 1e-9:
					after = true
			ward_ok = ward_ok and during and not after
	check.call(wards > 0 and ward_ok, "vision: %d wards each give vision for their duration only" % wards)


func _chase(check: Callable, results: Array) -> void:
	var dwell_ok := true
	var switches := 0
	var prio_ok := true
	var prio_seen := 0
	var fog_ok := true
	for r in results:
		var pl := ArenaPlayer.build(r, "B")
		var v := ArenaVision.build(pl, "B")
		var ch := ArenaChase.build(pl, v)
		var real := 0.0
		var last_switch := -100.0
		var cur_id := ""
		var t := 0.0
		while t < pl.end_t:
			var tg := ch.update(t, 0.1)
			real += 0.1
			if String(tg["id"]) != cur_id:
				if cur_id != "" and real - last_switch < ch.dwell_s - 1e-6:
					dwell_ok = false
				last_switch = real
				cur_id = String(tg["id"])
				switches += 1
			var cands := ch.candidates(t)
			var kinds: Array = []
			for c in cands:
				kinds.append(String(c["kind"]))
				if not v.sees(c["pos"], t) and String(c["kind"]) != "team":
					# a fight is chased when any of its heroes is seen; its centre may be in fog
					if not String(c["id"]).begins_with("fight."):
						fog_ok = false
			if kinds.has("kill") and (kinds.has("objective") or kinds.has("decisive")):
				prio_seen += 1
				prio_ok = prio_ok and String(cands[0]["kind"]) in ["objective", "decisive"]
			t += 0.25
	check.call(dwell_ok and switches > 3, "chase: %d target changes, none before the %.1f s minimum dwell" % [switches, 2.5])
	check.call(prio_ok, "chase: an objective or decisive play beats a kill (%d moments compared)" % prio_seen)
	check.call(fog_ok, "chase: with fog, only events the team sees are chased")
	var pl2 := ArenaPlayer.build(results[0], "B")
	var all := ArenaChase.build(pl2, null)
	var fog := ArenaChase.build(pl2, ArenaVision.build(pl2, "B"))
	var more := 0
	var t2 := 0.0
	while t2 < pl2.end_t:
		if all.candidates(t2).size() > fog.candidates(t2).size():
			more += 1
		t2 += 3.0
	check.call(more > 0, "chase: without fog the camera has more to chase than with it (%d moments)" % more)

