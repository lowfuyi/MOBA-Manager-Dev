extends Node
## Match Sim v2 calibration harness (offline, not part of the fast gate; MATCH-SIM-V2-DESIGN 6.3). Synthetic teams: uniform
## ratings, generic players (all stats 60), random role-correct picks, sides alternated game by game. One process per row;
## tools/calibrate_v2.py runs the rows in parallel and writes docs/design/MATCH-SIM-V2-CALIBRATION.md.
## Env: CAL_MODE gap | con | comp | style | counter | plan | heroes; CAL_N games; CAL_SEED; CAL_GAP rating points for A;
## CAL_CON_A / CAL_CON_B; CAL_COMP (A's CompMod); CAL_STYLE_A / CAL_STYLE_B; CAL_LM (A's lane counter, all three lanes);
## CAL_CTL / CAL_VAL (one Game Plan control for A); CAL_OUT (JSON path). Every row also records the game statistics.

const SLOTS := ["top", "jg", "mid", "bot", "sup"]


func _team(r: float, con: float, comp: float, style: String, lm: float) -> Dictionary:
	var ratings := {}
	for ph in ["early", "mid", "late"]:
		var x := {}
		for s in SLOTS:
			x[s] = r
		ratings[ph] = x
	var lane_mod := {}
	if lm != 0.0:
		lane_mod = {"top": lm, "mid": lm, "bot": lm, "jg": lm}
	return {"ratings": ratings, "con": con, "team_mod": 0.0, "comp_mod": comp, "lane_mod": lane_mod, "style": style}


func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.get_environment(k) != "" else d


func _ready() -> void:
	var mode := _env("CAL_MODE", "gap")
	var n := int(_env("CAL_N", "100"))
	var seed0 := int(_env("CAL_SEED", "1"))
	var gap := float(_env("CAL_GAP", "0"))
	var base := float(_env("CAL_BASE", "50"))
	var con_a := float(_env("CAL_CON_A", "50"))
	var con_b := float(_env("CAL_CON_B", "50"))
	var comp := float(_env("CAL_COMP", "0"))
	var st_a := _env("CAL_STYLE_A", "skirmish")
	var st_b := _env("CAL_STYLE_B", "skirmish")
	var lm := float(_env("CAL_LM", "0"))
	var ctl := _env("CAL_CTL", "")
	var val := int(_env("CAL_VAL", "0"))
	var by_role := {}
	for h in SimData.heroes().values():
		var rp := String(h["role_primary"])
		if not by_role.has(rp):
			by_role[rp] = []
		by_role[rp].append(String(h["id"]))
	for rp in by_role:
		by_role[rp].sort()
	var player := {"id": "p", "stats": {"mec": 60, "sen": 60, "lan": 60, "tft": 60, "mac": 60, "com": 60, "con": 60, "clu": 60}}
	var a_wins := 0
	var stats := {"len": [], "kills": [], "final": [], "more_kills_won": 0, "ahead8_won": 0, "ahead8_n": 0, "behind_trig": 0, "ahead_trig": 0, "safety": 0}
	var hero_g := {}
	var hero_w := {}
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
		var a_blue := i % 2 == 0
		var ta := _team(base + gap, con_a, comp, st_a, lm)
		var tb := _team(base, con_b, 0.0, st_b, 0.0)
		var ctx := {"picks": {"B": {}, "R": {}}, "players": {"B": {}, "R": {}}}
		for s in SLOTS:
			ctx["picks"]["B"][s] = picks["A" if a_blue else "B"][s]
			ctx["picks"]["R"][s] = picks["B" if a_blue else "A"][s]
			ctx["players"]["B"][s] = player
			ctx["players"]["R"][s] = player
		var sets := {}
		if ctl != "":
			var pl := GamePlan.neutral()
			if ctl == "jf":
				pl["jf"] = ["top", "mid_lane", "bot"][absi(val) % 3]
			else:
				pl[ctl] = val
			sets["B" if a_blue else "R"] = {"default": pl, "triggers": []}
		var r := MatchSimV2.simulate(ta if a_blue else tb, tb if a_blue else ta, seed0 * 7919 + i * 31, sets, ctx)
		var a_won: bool = bool(r["a_won"]) == a_blue
		if a_won:
			a_wins += 1
		var sgn := 1.0 if a_blue else -1.0
		stats["len"].append(float(r["len_s"]) / 60.0)
		stats["kills"].append(int(r["team_kills"]["B"]) + int(r["team_kills"]["R"]))
		stats["final"].append(absf(float(r["final"])))
		var kb := int(r["team_kills"]["B"])
		var kr := int(r["team_kills"]["R"])
		if (kb > kr and bool(r["a_won"])) or (kr > kb and not bool(r["a_won"])):
			stats["more_kills_won"] += 1
		var em := float(r["early"])
		if absf(em) >= float(GamePlan.data()["trigger_threshold"]):
			stats["ahead8_n"] += 1
			if (em > 0.0) == bool(r["a_won"]):
				stats["ahead8_won"] += 1
		if em < -float(GamePlan.data()["trigger_threshold"]):
			stats["behind_trig"] += 1
		if em > float(GamePlan.data()["trigger_threshold"]):
			stats["ahead_trig"] += 1
		if String(r["end_reason"]) != "cairn":
			stats["safety"] += 1
		if mode == "heroes":
			for side in ["B", "R"]:
				var won_side: bool = (side == "B") == bool(r["a_won"])
				for s in SLOTS:
					var hid := String(ctx["picks"][side][s])
					hero_g[hid] = int(hero_g.get(hid, 0)) + 1
					if won_side:
						hero_w[hid] = int(hero_w.get(hid, 0)) + 1
	var out := {"mode": mode, "gap": gap, "n": n, "a_wins": a_wins, "rate": float(a_wins) / float(n), "con_a": con_a, "con_b": con_b,
			"comp": comp, "style_a": st_a, "style_b": st_b, "lm": lm, "ctl": ctl, "val": val, "stats": stats,
			"hero_g": hero_g, "hero_w": hero_w, "ms": Time.get_ticks_msec() - t0}
	print("CAL ", JSON.stringify({"mode": mode, "gap": gap, "ctl": ctl, "val": val, "rate": out["rate"], "n": n}))
	if OS.get_environment("CAL_OUT") != "":
		var f := FileAccess.open(OS.get_environment("CAL_OUT"), FileAccess.WRITE)
		f.store_string(JSON.stringify(out))
	get_tree().quit()
