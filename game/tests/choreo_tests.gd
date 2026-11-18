extends RefCounted
## Alpha 0.8 A-03: the tokens' walks (Choreo) on real results, both held stagings and the clean ending:
##   arrival   at each group beat's resolve, every hero that has not died since the order is inside the beat's zone; laners stand
##             at their clash point at their resolve
##   spacing   heroes standing still on the same ground are at least 30 px apart (36 px bodies)
##   motion    no token moves faster than rush speed between two samples (respawns excepted); every token stays on the map
##   deaths    a victim is hidden 0.6 s after each death of the ledger and back in view after its rise; a hero that rose runs at
##             rush speed until it has caught up
##   ending    clean_gate: the match winner's living heroes stand at the loser's Cairn at 73.5 s (the line spacing kept); held: the pack reaches the
##             loser's Cairn by 74.0 s and the heroes do not leave the isle (held_island)
##   A3        the same result gives the same positions

const N := 120


func run(check: Callable) -> void:
	var w := World.load_default()
	var meta := w.make_meta("choreo-test")
	var fails := {}
	var worst := {"arrive_px": 0.0, "gap_px": INF, "speed": 0.0}
	var endings := {}
	var t0 := Time.get_ticks_msec()
	for i in N:
		var a: String = w.club_ids[i % w.club_ids.size()]
		var b: String = w.club_ids[(i * 5 + 2) % w.club_ids.size()]
		if a == b:
			b = w.club_ids[(i + 1) % w.club_ids.size()]
		var res := MatchRunner.auto(w, w.best_lineup(a), w.best_lineup(b), meta, 9100 + i, "choreo:%d" % i, false, {"B": "ai", "R": "ai"})
		var s := ShowScript.build(res, "B" if i % 2 == 0 else "R")
		var variants := ["held_island", "held_gate"] if s.held else [""]
		for v in variants:
			var c := Choreo.build(s, v)
			endings[c.variant] = int(endings.get(c.variant, 0)) + 1
			for bad in _check_one(c, s, worst):
				fails[bad] = int(fails.get(bad, 0)) + 1
		if i < 10:
			var c1 := Choreo.build(s)
			var c2 := Choreo.build(s)
			var same := true
			for k in c1.heroes:
				for tt in [3.3, 17.7, 40.1, 66.6]:
					same = same and c1.pos(k, tt) == c2.pos(k, tt)
			if not same:
				fails["A3"] = int(fails.get("A3", 0)) + 1
	print("     choreo: %d results in %d ms; endings %s; worst arrival %.1f px off, closest still pair %.1f px, fastest %.2f u/s" % [N, Time.get_ticks_msec() - t0, str(endings), worst["arrive_px"], worst["gap_px"], worst["speed"]])
	for name in ["arrival", "lanes", "spacing", "motion", "on map", "deaths", "ending", "A3"]:
		check.call(not fails.has(name), "choreo %s holds (%d failures)" % [name, int(fails.get(name, 0))])
	check.call(endings.has("clean_gate") and endings.has("held_island") and endings.has("held_gate"), "the sample plays all three endings %s" % str(endings))


func _px(a: Vector2, b: Vector2) -> float:
	return Vector2((a.x - b.x) * ArenaData.W, (a.y - b.y) * ArenaData.H).length()


func _died_between(c: Choreo, key: String, t0: float, t1: float) -> bool:
	for d in c.heroes[key]["deaths"]:
		if float(d["rise"]) + 0.0 > t0 and float(d["t"]) <= t1:
			return true
	return false


func _check_one(c: Choreo, s: ShowScript, worst: Dictionary) -> Array:
	var bad: Array = []
	# group beats: [order time, check time, centre node, radius px]
	var beats := [[20.25, 33.0, "N.stoneback", 70.0], [34.5, 44.0, "N.mossback", 78.0], [51.0, 59.5, "N.moonhulk", 76.0]]
	var objective := {"N.stoneback": "obj_mid", "N.mossback": "fight_mid", "N.moonhulk": "obj_late"}
	for bt in beats:
		var centre := ArenaData.node(String(bt[2]))
		# Fight pass (0.8.1): the beat's losers run back after its last kill, so they are checked as that run starts
		var beat: String = objective[bt[2]]
		var tr := float(ArenaActions.fight(beat)["fight_to"])
		var last := -1.0
		for e in s.kill_events:
			if String(e["beat"]) == beat:
				last = maxf(last, float(e["t"]))
		if last >= 0.0:
			tr = minf(tr, last + 0.2)
		var lose := ShowScript.other(String(s.contests[beat]["win"]))
		for k in c.heroes:
			var at_t := float(bt[1])
			if String(k).begins_with(lose) or beat == "fight_mid":
				at_t = minf(at_t, tr - 0.01)
			if _died_between(c, k, float(bt[0]) - 2.0, at_t):
				continue
			var off := _px(c.pos(k, at_t), centre)
			if off > float(bt[3]):
				worst["arrive_px"] = maxf(float(worst["arrive_px"]), off - float(bt[3]))
				if not bad.has("arrival"):
					bad.append("arrival")
	for slot in ["top", "mid", "bot"]:
		var lane: String = Choreo.LANE_OF[slot]
		var rt := float(ShowScript.RESOLVE[Choreo.CONTEST_OF[lane]])
		var cp := c.lane_point(lane, c.clash_s(lane))
		for side in ["B", "R"]:
			var k2: String = side + "." + slot
			if _died_between(c, k2, 0.0, rt):
				continue
			if _px(c.pos(k2, rt), cp) > 30.0:
				if not bad.has("lanes"):
					bad.append("lanes")
	# spacing of still heroes at rest moments
	for tt in [12.9, 32.5, 43.5, 59.0, 65.5]:
		var still: Array = []
		for k3 in c.heroes:
			if c.alive(k3, tt) and c.alpha(k3, tt) >= 1.0 and c.pos(k3, tt) == c.pos(k3, tt - 0.4):
				still.append(c.pos(k3, tt))
		for i in still.size():
			for j in range(i + 1, still.size()):
				var g := _px(still[i], still[j])
				worst["gap_px"] = minf(float(worst["gap_px"]), g)
				if g < 30.0 and not bad.has("spacing"):
					bad.append("spacing")
	# motion and bounds
	var vmax := float(ArenaData.data()["speeds"]["walk_u_s"]) * Choreo.RUSH * 1.02
	for k4 in c.heroes:
		var prev := c.pos(k4, 0.0)
		var tt2 := 0.1
		while tt2 <= 75.0:
			var p := c.pos(k4, tt2)
			if p.x < 0.0 or p.x > 1.0 or p.y < 0.0 or p.y > 1.0:
				if not bad.has("on map"):
					bad.append("on map")
			var near_rise := false
			for d in c.heroes[k4]["deaths"]:
				near_rise = near_rise or absf(tt2 - float(d["rise"])) < 0.11
			var sp := ArenaData.dist_u(prev, p) / 0.1
			if not near_rise and c.alive(k4, tt2):
				worst["speed"] = maxf(float(worst["speed"]), sp)
				if sp > vmax and not bad.has("motion"):
					bad.append("motion")
			prev = p
			tt2 += 0.1
		var ds: Array = c.heroes[k4]["deaths"]
		for di in ds.size():
			var d2: Dictionary = ds[di]
			var next_t := float(ds[di + 1]["t"]) if di + 1 < ds.size() else INF    # a second death soon after a rise hides it again
			if c.alpha(k4, float(d2["t"]) + 0.6) != 0.0 or (next_t > float(d2["rise"]) + 0.7 and c.alpha(k4, float(d2["rise"]) + 0.7) != 1.0):
				if not bad.has("deaths"):
					bad.append("deaths")
	# victims of the ledger match the deaths list
	var n_deaths := 0
	for k5 in c.heroes:
		n_deaths += (c.heroes[k5]["deaths"] as Array).size()
	if n_deaths == 0 and not s.kill_events.is_empty():
		bad.append("deaths")
	# the ending
	var u := ShowScript.other(s.winner)
	var cairn := ArenaData.node(u + ".cairn")
	if c.variant == "clean_gate":
		for slot2 in Choreo.SLOTS:
			var k6: String = s.winner + "." + slot2
			if _died_between(c, k6, 66.0, 73.5):    # a hero that rose before 66 s catches up at rush speed
				continue
			if _px(c.pos(k6, 73.5), cairn) > 130.0 and not bad.has("ending"):    # the line is 190 px wide, centred on the Cairn
				bad.append("ending")
	else:
		if _px(c.pack_pos(73.99), cairn) > 2.0 or not c.pack_visible(70.0):
			bad.append("ending")
		if c.variant == "held_island":
			for k7 in c.heroes:
				if not _died_between(c, k7, 55.0, 72.0) and _px(c.pos(k7, 72.0), ArenaData.node("N.moonhulk")) > 76.0 and not bad.has("ending"):
					bad.append("ending")
	return bad
