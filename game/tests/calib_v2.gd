extends Node
## Match Sim v2 calibration harness (offline, not part of the fast gate; MATCH-SIM-V2-DESIGN 6.3): synthetic teams with a uniform rating gap (GDD 9 table), random role-correct picks, sides alternated.
## Env: CAL_GAP (rating points), CAL_N (games), CAL_SEED, CAL_CON_A/CAL_CON_B, CAL_COMP (comp_mod for A), CAL_OUT (json path).

const SLOTS := ["top", "jg", "mid", "bot", "sup"]


func _team(r: float, con: float, comp: float) -> Dictionary:
	var ratings := {}
	for ph in ["early", "mid", "late"]:
		var x := {}
		for s in SLOTS:
			x[s] = r
		ratings[ph] = x
	return {"ratings": ratings, "con": con, "team_mod": 0.0, "comp_mod": comp, "lane_mod": {}, "style": "skirmish"}


func _env(k: String, d: float) -> float:
	return float(OS.get_environment(k)) if OS.get_environment(k) != "" else d


func _ready() -> void:
	var gap := _env("CAL_GAP", 10.0)
	var n := int(_env("CAL_N", 100.0))
	var seed0 := int(_env("CAL_SEED", 1.0))
	var base := _env("CAL_BASE", 50.0)
	var con_a := _env("CAL_CON_A", 50.0)
	var con_b := _env("CAL_CON_B", 50.0)
	var comp := _env("CAL_COMP", 0.0)
	var by_role := {}
	for h in SimData.heroes().values():
		var rp := String(h["role_primary"])
		if not by_role.has(rp):
			by_role[rp] = []
		by_role[rp].append(String(h["id"]))
	for rp in by_role:
		by_role[rp].sort()
	var player := {"id": "p", "stats": {"mec": 60, "sen": 60, "lan": 60, "tft": 60, "mac": 60, "com": 60, "con": 60, "clu": 60}}
	var fav_w := 0
	var lens := 0.0
	var kills := 0.0
	var t0 := Time.get_ticks_msec()
	for i in n:
		var rng := Pcg32.contest_stream(seed0 * 100003 + i, "cal")
		var picks := {"A": {}, "B": {}}
		for s in SLOTS:
			var pool: Array = by_role[s].duplicate()
			var a := int(rng.next_float() * pool.size())
			picks["A"][s] = pool[a]
			pool.remove_at(a)
			picks["B"][s] = pool[int(rng.next_float() * pool.size())]
		var fav_blue := i % 2 == 0
		var fav := _team(base + gap, con_a, comp)
		var dog := _team(base, con_b, 0.0)
		var ctx := {"picks": {"B": {}, "R": {}}, "players": {"B": {}, "R": {}}}
		for s in SLOTS:
			ctx["picks"]["B"][s] = picks["A" if fav_blue else "B"][s]
			ctx["picks"]["R"][s] = picks["B" if fav_blue else "A"][s]
			ctx["players"]["B"][s] = player
			ctx["players"]["R"][s] = player
		var r := MatchSimV2.simulate(fav if fav_blue else dog, dog if fav_blue else fav, seed0 * 7919 + i * 31, {}, ctx)
		if bool(r["a_won"]) == fav_blue:
			fav_w += 1
		lens += float(r["len_s"]) / 60.0
		kills += float(int(r["team_kills"]["B"]) + int(r["team_kills"]["R"]))
	var out := {"gap": gap, "n": n, "fav_wins": fav_w, "rate": float(fav_w) / float(n), "len": lens / n, "kills": kills / n, "ms": Time.get_ticks_msec() - t0}
	print("CAL ", JSON.stringify(out))
	if OS.get_environment("CAL_OUT") != "":
		var f := FileAccess.open(OS.get_environment("CAL_OUT"), FileAccess.WRITE)
		f.store_string(JSON.stringify(out))
	get_tree().quit()
