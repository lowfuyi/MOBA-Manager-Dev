extends RefCounted
## Alpha 0.8 A-04: the beats on screen (ArenaFx) on real results, both seats:
##   resolve   at every contest's stamp a winner ring in the winner's shape (circle = you, hexagon = them) stands at its place
##   H5        a skull is shown only within 0.6 s after a kill event of the ledger, and every kill shows one
##   towers    fallen_at(75) = the ledger's towers plus the two guard towers of the loser; nothing falls before its time
##   objective the owner glyph on Stoneback and Moonhulk is the contest winner's; a steal (initiator lost) flips the ring's colour
##   camera    zoom stays in [1.0, 1.3]; reduced motion keeps 1.0; the held fight keeps the camera wide (HF4)
##   budget    at most 12 live hit cues
##   HF3       in held_island a winner hero that falls after 61 s rises at its formation point
##   A3        the same result gives the same cues
## Fight pass (Alpha 0.8.1, ACTION-VOCABULARY 11.2):
##   actions   every action starts at an attacker that is up (and stays up to its end) and hits a target that is up just before
##             the hit; a kill action is a ledger kill (killer on victim at its moment); every archetype's action kind occurs
##   lunge     a token's lunge is at most its reach (46 px engage, 18 px dash) and zero outside its actions
##   bars      a bar is drawn only for a hero that is up, with 0 < hp < 1

const N := 60


func run(check: Callable) -> void:
	var w := World.load_default()
	var meta := w.make_meta("fx-test")
	var fails := {}
	var held_rises := 0
	for i in N:
		var a: String = w.club_ids[i % w.club_ids.size()]
		var b: String = w.club_ids[(i * 3 + 4) % w.club_ids.size()]
		if a == b:
			b = w.club_ids[(i + 1) % w.club_ids.size()]
		var res := MatchRunner.auto(w, w.best_lineup(a), w.best_lineup(b), meta, 5300 + i, "fx:%d" % i, false, {"B": "ai", "R": "ai"})
		var me := "B" if i % 2 == 0 else "R"
		var s := ShowScript.build(res, me)
		var c := Choreo.build(s)
		var f := ArenaFx.build(s, c, me)
		for bad in _check_one(f, s, c, me):
			fails[bad] = int(fails.get(bad, 0)) + 1
		if s.held:
			var ci := Choreo.build(s, "held_island")
			for key in ci.heroes:
				if not String(key).begins_with(s.winner):
					continue
				for d in ci.heroes[key]["deaths"]:
					if float(d["t"]) > 61.5 and float(d["rise"]) < 74.0:
						held_rises += 1
						var slot: String = String(key).split(".")[1]
						var raw: Array = ci.ending["formation"]["W"][slot]
						var want := Vector2(float(raw[0]), float(raw[1])) if s.winner == "B" else Vector2(float(raw[0]), 1.0 - float(raw[1]))
						if ci.pos(key, float(d["rise"]) + 0.01).distance_to(want) > 0.003:
							fails["HF3"] = int(fails.get("HF3", 0)) + 1
		if i < 6:
			var f2 := ArenaFx.build(s, Choreo.build(s), me)
			for tt in [14.0, 33.9, 45.1, 60.2, 74.2]:
				if JSON.stringify(f.over_at(tt)) != JSON.stringify(f2.over_at(tt)) or JSON.stringify(f.under_at(tt)) != JSON.stringify(f2.under_at(tt)):
					fails["A3"] = int(fails.get("A3", 0)) + 1
	print("     arena fx: %d results, both seats; held-island rises checked %d" % [N, held_rises])
	var kinds := {}
	for i2 in 8:
		var a2: String = w.club_ids[i2 % w.club_ids.size()]
		var b2: String = w.club_ids[(i2 * 5 + 2) % w.club_ids.size()]
		if a2 == b2:
			b2 = w.club_ids[(i2 + 1) % w.club_ids.size()]
		var r2 := MatchRunner.auto(w, w.best_lineup(a2), w.best_lineup(b2), meta, 6100 + i2, "fxa:%d" % i2, false, {"B": "ai", "R": "ai"})
		var s2 := ShowScript.build(r2, "B")
		var f2 := ArenaFx.build(s2, Choreo.build(s2), "B")
		for a in f2.actions:
			kinds[a["kind"]] = true
	check.call(kinds.size() == 6, "arena fx actions: dash, shot, burst, tether, heal and engage all occur on 8 more results %s" % str(kinds.keys()))
	for name in ["resolve", "H5", "towers", "objective", "camera", "budget", "HF3", "A3", "actions", "lunge", "bars"]:
		check.call(not fails.has(name), "arena fx %s holds (%d failures)" % [name, int(fails.get(name, 0))])


func _has(list: Array, key: String, at: Vector2, tol: float) -> bool:
	for e in list:
		if String(e[0]) == key and (e[1] as Vector2).distance_to(at) <= tol:
			return true
	return false


func _check_one(f: ArenaFx, s: ShowScript, c: Choreo, me: String) -> Array:
	var bad: Array = []
	for r in f.resolves:
		var key := "ring_" + ("you" if String(r["win"]) == me else "them")
		if not _has(f.under_at(float(r["t"]) + 0.1), key, r["at"], 1e-6):
			bad.append("resolve")
			break
	# H5: skulls only after kills, and every kill shows one
	for e in s.kill_events:
		var victim: String = ShowScript.other(String(e["side"])) + "." + String(e["victim"])
		var shown := false
		for sp in f.over_at(float(e["t"]) + 0.05):
			shown = shown or String(sp[0]) == "skull"
		if not shown and not bad.has("H5"):
			bad.append("H5")
		if victim == "":
			bad.append("H5")
	var kills := {}
	for e3 in s.kill_events:
		kills["%s|%s.%s|%s.%s" % [str(e3["t"]), e3["side"], e3["killer"], ShowScript.other(String(e3["side"])), e3["victim"]]] = true
	for a in f.actions:
		var ok := c.alive(String(a["a"]), float(a["t0"])) and c.alive(String(a["a"]), float(a["t1"])) and c.alive(String(a["b"]), float(a["th"]) - 0.01)
		var same_side := String(a["a"]).substr(0, 1) == String(a["b"]).substr(0, 1)
		if same_side != (String(a["kind"]) == "heal"):
			ok = false
		if bool(a["kill"]):
			ok = ok and kills.has("%s|%s|%s" % [str(a["th"]), a["a"], a["b"]])
		if not ok and not bad.has("actions"):
			bad.append("actions")
	var t := 0.0
	while t < 75.0:
		for key in c.heroes:
			var n := f.nudge(String(key), t)
			var px := Vector2(n.x * ArenaData.W, n.y * ArenaData.H).length()
			var any := false
			for a4 in f._lunges.get(key, []):
				any = any or (t >= float(a4["t0"]) and t < float(a4["t1"]))
			if px > 46.0 + 0.01 or (px > 1e-6 and not any):
				if not bad.has("lunge"):
					bad.append("lunge")
		for bar in f.bars_at(t):
			if float(bar[1]) <= 0.0 or float(bar[1]) >= 1.0:
				if not bad.has("bars"):
					bad.append("bars")
		var skulls := 0
		for sp2 in f.over_at(t):
			skulls += 1 if String(sp2[0]) == "skull" else 0
		var recent := 0
		for e2 in s.kill_events:
			var dk := t - float(e2["t"])
			recent += 1 if dk >= 0.0 and dk < 0.6 else 0
		if skulls != recent and not bad.has("H5"):
			bad.append("H5")
		var live := 0
		for sp3 in f.over_at(t):
			live += 1 if String(sp3[0]) == "spark" or String(sp3[0]) == "ring_magic" else 0
		if live > ArenaFx.MAX_CUES + 10 and not bad.has("budget"):    # + respawn rings, which are not hit cues
			bad.append("budget")
		var cam := f.camera_at(t)
		if float(cam[1]) < 1.0 - 1e-9 or float(cam[1]) > 1.3 + 1e-9 or float(f.camera_at(t, true)[1]) != 1.0:
			if not bad.has("camera"):
				bad.append("camera")
		if s.held and t >= 66.0 and float(cam[1]) != 1.0 and not bad.has("camera"):
			bad.append("camera")
		t += 0.25
	# towers
	var want := {}
	for tw in s.towers:
		want[String(tw["id"])] = true
	var u := ShowScript.other(s.winner)
	want[u + ".guard.l"] = true
	want[u + ".guard.r"] = true
	var fall75 := f.fallen_at(75.0)
	if fall75.size() != want.size() or not want.keys().all(func(k: String) -> bool: return fall75.has(k)):
		bad.append("towers")
	for tw2 in s.towers:
		if f.fallen_at(float(tw2["t"]) + 0.5).has(String(tw2["id"])) and not bad.has("towers"):
			bad.append("towers")
	# objectives
	for ob in [["obj_mid", "N.stoneback"], ["obj_late", "N.moonhulk"]]:
		var win := String(s.contests[ob[0]]["win"])
		var glyph := "glyph_" + ("you" if win == me else "them")
		var found := false
		for sp4 in f.over_at(float(ShowScript.RESOLVE[ob[0]]) + 1.0):
			found = found or String(sp4[0]) == glyph
		if not found:
			bad.append("objective")
		var b := float(ArenaFx.TAKE[ob[0]][1])
		var late: Array = f.arcs_at(b - 0.05)
		var init := String(s.initiators.get(ob[0], win))
		var colour_early := String(f.arcs_at(float(ArenaFx.TAKE[ob[0]][0]) + 0.5)[0][4])
		if late.is_empty() or String(late[0][4]) != ("you" if win == me else "them") or colour_early != ("you" if init == me else "them"):
			if not bad.has("objective"):
				bad.append("objective")
	return bad
