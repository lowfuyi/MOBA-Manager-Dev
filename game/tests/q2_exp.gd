extends Node
## Q2 analyses (Founder's queue of 2026-11-24, docs/design/ESMO-LESSONS.md). Offline, read-only use of the sim, not part of
## the fast gate; tools/q2_analysis.py runs chunks in parallel and writes the reports. Every game is a real AI-vs-AI draft
## between two clubs of the default world (a fresh patch every 40 games), then a Match Sim v2 game, as in ban_exp.gd.
## Env: Q2_MODE, Q2_BANS (1, 3, 5), Q2_N games, Q2_SEED, Q2_OUT (JSON path).
##   heroes  equal teams (both moved to a mean rating of 50, as BX_GAPS=0 in ban_exp.gd). Per hero and lane: games and wins.
##           Per pair of heroes on opposite teams ("x|y"): games and x's wins (any lanes), and lane opponents ("x|y|lane").
##   draft   natural ratings (no shift). Per game: the player gap and each side's draft score (definition below), and the winner.
##           Draft score of a side = (mean of the 15 phase ratings the sim is given) / (the same players' mean with a
##           "plain" hero: own lane, full familiarity, no difficulty, power 50, meta 1) x (1 + comp_mod x comp_fight).
##           So 1.00 is a draft that adds nothing; it holds hero fit, familiarity, hero power, the patch and the composition.
##           The lane matchup bonus is not in it. Player rating = that plain-hero mean.
##   plans   equal teams. Each base game is played with both plans neutral, then once per option with the option on side A
##           (A alternates Blue and Red by game), same draft and seed. Per option: games, A's wins, and the paired
##           counts (option won where neutral lost, and the reverse) for an honest error; A's wins with both neutral.

const SLOTS := ["top", "jg", "mid", "bot", "sup"]


func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.get_environment(k) != "" else d


static func _shift(team: Dictionary, to_mean: float) -> Dictionary:
	var t := team.duplicate(true)
	var sum := 0.0
	for ph in ["early", "mid", "late"]:
		for s in SLOTS:
			sum += float(t["ratings"][ph][s])
	var dlt := to_mean - sum / 15.0
	for ph in ["early", "mid", "late"]:
		for s in SLOTS:
			t["ratings"][ph][s] = float(t["ratings"][ph][s]) + dlt
	return t


static func _mean15(team: Dictionary) -> float:
	var sum := 0.0
	for ph in ["early", "mid", "late"]:
		for s in SLOTS:
			sum += float(team["ratings"][ph][s])
	return sum / 15.0


## The players' mean phase rating with a plain hero in every lane (see the header).
static func _plain(w: World, lineup: Dictionary) -> float:
	var sum := 0.0
	for s in SLOTS:
		var hero := {"id": "plain", "role_primary": s, "difficulty": 0.0001, "power_early": 50.0, "power_mid": 50.0, "power_late": 50.0}
		for ph in ["early", "mid", "late"]:
			sum += w.phase_rating(lineup[s], s, hero, ph, 100.0, 1.0, -1.0, w.fatigue_of(lineup[s]["id"]), 0.0)
	return sum / 15.0


## Every non-neutral value of every slider, every Jungle focus, and the obvious pairs.
static func options() -> Array:
	var out: Array = []
	for sl in GamePlan.SLIDERS:
		for v in GamePlan.STEPS:
			if int(v) != 0:
				out.append(["%s%+d" % [sl, int(v)], {sl: int(v)}])
	for jf in GamePlan.JUNGLE_CHOICES:
		if jf != "none":
			out.append(["jf=" + jf, {"jf": jf}])
	var pairs := [
		{"t": 100, "a": 100}, {"t": -100, "l": 100}, {"g": 100, "r": 100}, {"g": -100, "r": -100}, {"m": 100, "l": 100},
		{"t": 100, "m": 100}, {"a": 100, "jf": "top"}, {"a": 100, "jf": "bot"}, {"a": 100, "jf": "mid_lane"}, {"s": 100, "a": 100},
		{"r": 100, "l": 100}, {"g": 100, "t": 100}, {"t": 100, "a": 100, "m": 100, "l": 100, "g": 100, "r": 100},
	]
	for p in pairs:
		var name := ""
		for k in p:
			name += ("%s%+d " % [k, int(p[k])]) if k != "jf" else ("jf=%s " % String(p[k]))
		out.append([name.strip_edges(), p])
	return out


static func _set_of(change: Dictionary) -> Dictionary:
	var p := GamePlan.neutral()
	for k in change:
		p[k] = change[k]
	return {"default": p, "triggers": []}


func _ready() -> void:
	var mode := _env("Q2_MODE", "heroes")
	var nb := int(_env("Q2_BANS", "5"))
	var n := int(_env("Q2_N", "20"))
	var seed0 := int(_env("Q2_SEED", "1"))
	var w := World.load_default()
	var nc := w.club_ids.size()
	var comp_fight := float(SimData.params().get("comp_fight", 0.0))
	var out := {"mode": mode, "bans": nb, "n": 0, "ms": 0, "hr_g": {}, "hr_w": {}, "pair_g": {}, "pair_w": {}, "lane_g": {}, "lane_w": {},
			"rows": [], "opt_g": {}, "opt_w": {}, "opt_10": {}, "opt_01": {}, "base_g": 0, "base_w": 0}
	var opts := options() if mode == "plans" else []
	var t0 := Time.get_ticks_msec()
	var meta := {}
	for i in n:
		var gi := seed0 * 100003 + i
		if i % 40 == 0:
			meta = w.make_meta("q2:%d:%d" % [seed0, i / 40])
		var rng := Pcg32.contest_stream(gi, "q2")
		var a := int(rng.next_u32() % nc)
		var b := int(rng.next_u32() % (nc - 1))
		if b >= a:
			b += 1
		var lu := {"B": w.best_lineup(w.club_ids[a]), "R": w.best_lineup(w.club_ids[b])}
		var d := Draft.make(w, lu, meta, gi, "q2:%d" % gi, nb)
		while not d.is_done():
			d.apply(d.ai_choice())
		var teams := MatchRunner.build_teams(w, d)
		var ctx := MatchRunner.context(w, d, {})
		out["n"] += 1
		match mode:
			"draft":
				var pb := _plain(w, d.lineups["B"])
				var pr := _plain(w, d.lineups["R"])
				var db := _mean15(teams[0]) / pb * (1.0 + float(teams[0]["comp_mod"]) * comp_fight)
				var dr := _mean15(teams[1]) / pr * (1.0 + float(teams[1]["comp_mod"]) * comp_fight)
				var r := MatchSimV2.simulate(teams[0], teams[1], d.mseed, {}, ctx)
				out["rows"].append([snappedf(pb - pr, 0.01), snappedf(db, 0.0001), snappedf(dr, 0.0001), bool(r["a_won"])])
			"plans":
				var tb := _shift(teams[0], 50.0)
				var tr := _shift(teams[1], 50.0)
				var side_a := "B" if i % 2 == 0 else "R"
				var r0 := MatchSimV2.simulate(tb, tr, d.mseed, {}, ctx)
				var base_won := bool(r0["a_won"]) == (side_a == "B")
				out["base_g"] += 1
				if base_won:
					out["base_w"] += 1
				for o in opts:
					var sets := {side_a: _set_of(o[1])}
					var ro := MatchSimV2.simulate(tb, tr, d.mseed, sets, ctx)
					var key := String(o[0])
					out["opt_g"][key] = int(out["opt_g"].get(key, 0)) + 1
					var opt_won := bool(ro["a_won"]) == (side_a == "B")
					if opt_won:
						out["opt_w"][key] = int(out["opt_w"].get(key, 0)) + 1
					if opt_won and not base_won:
						out["opt_10"][key] = int(out["opt_10"].get(key, 0)) + 1
					elif base_won and not opt_won:
						out["opt_01"][key] = int(out["opt_01"].get(key, 0)) + 1
			_:
				var tb2 := _shift(teams[0], 50.0)
				var tr2 := _shift(teams[1], 50.0)
				var r2 := MatchSimV2.simulate(tb2, tr2, d.mseed, {}, ctx)
				var blue_won := bool(r2["a_won"])
				for side in ["B", "R"]:
					var other: String = "R" if side == "B" else "B"
					var won: bool = (side == "B") == blue_won
					for s in SLOTS:
						var x := String(d.picks[side][s]["id"])
						var k: String = x + "|" + s
						out["hr_g"][k] = int(out["hr_g"].get(k, 0)) + 1
						if won:
							out["hr_w"][k] = int(out["hr_w"].get(k, 0)) + 1
						for s2 in SLOTS:
							var y := String(d.picks[other][s2]["id"])
							var pk := x + "|" + y
							out["pair_g"][pk] = int(out["pair_g"].get(pk, 0)) + 1
							if won:
								out["pair_w"][pk] = int(out["pair_w"].get(pk, 0)) + 1
							if s2 == s:
								var lk: String = pk + "|" + s
								out["lane_g"][lk] = int(out["lane_g"].get(lk, 0)) + 1
								if won:
									out["lane_w"][lk] = int(out["lane_w"].get(lk, 0)) + 1
	out["ms"] = Time.get_ticks_msec() - t0
	print("Q2 ", JSON.stringify({"mode": mode, "bans": nb, "n": n, "ms": out["ms"]}))
	if _env("Q2_OUT", "") != "":
		var fo := FileAccess.open(_env("Q2_OUT", ""), FileAccess.WRITE)
		fo.store_string(JSON.stringify(out))
	get_tree().quit()
