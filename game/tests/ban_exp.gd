extends Node
## Ban experiment harness (Founder decision 2026-11-22; docs/design/BAN-EXPERIMENT.md). Offline, not part of the fast gate.
## Every game is a real AI-vs-AI draft (the AI on both sides, the order for BX_BANS bans a side) between two clubs of the default
## world under a fresh patch every 40 games, then a Match Sim v2 game. The two teams keep everything the draft gave them
## (composition, style, lane counters, kits, items) but their ratings are moved, slot by slot and phase by phase by one
## constant, so that their means are 50 + gap and 50: the GDD 9 rating bands can be read with real drafts. Gap 0 games give
## the side balance (Blue vs Red) and the hero win rates. tools/ban_experiment.py runs chunks in parallel and writes the report.
## Env: BX_BANS (1, 3, 5), BX_N games, BX_SEED, BX_OUT (JSON path), BX_GAPS (optional comma list of rating gaps, e.g. "0"
## for the hero-balance rounds of 0.11.1; default the GAPS cycle).

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const GAPS := [0.0, 0.0, 5.0, 10.0, 20.0, 30.0]


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


func _ready() -> void:
	var nb := int(_env("BX_BANS", "1"))
	var n := int(_env("BX_N", "50"))
	var seed0 := int(_env("BX_SEED", "1"))
	var w := World.load_default()
	var nc := w.club_ids.size()
	var out := {"bans": nb, "n": 0, "rows": {}, "blue_wins0": 0, "n0": 0, "hero_g": {}, "hero_w": {}, "hero_pick": {}, "hero_ban": {},
			"comfort_lost": [], "comfort_lost_side": {"B": 0, "R": 0}, "famf": {"B": 0.0, "R": 0.0}, "raw_gap_won": [], "len": [], "kills": [],
			"ms": 0, "ms_draft": 0, "floor_binds": 0, "lost_win": {"lost": 0, "lost_won": 0}}
	var gaps: Array = GAPS
	if _env("BX_GAPS", "") != "":
		gaps = []
		for g in _env("BX_GAPS", "").split(","):
			gaps.append(float(g))
	var t0 := Time.get_ticks_msec()
	var meta := {}
	for i in n:
		var gi := seed0 * 100003 + i
		if i % 40 == 0:
			meta = w.make_meta("bx:%d:%d" % [seed0, i / 40])
		var rng := Pcg32.contest_stream(gi, "bx")
		var a := int(rng.next_u32() % nc)
		var b := int(rng.next_u32() % (nc - 1))
		if b >= a:
			b += 1
		var lu := {"B": w.best_lineup(w.club_ids[a]), "R": w.best_lineup(w.club_ids[b])}
		# comfort heroes: each starter's best hero for the slot (familiarity x fit) from the whole pool, before the draft
		var comfort := {"B": [], "R": []}
		for side in ["B", "R"]:
			for s in SLOTS:
				var best := ""
				var bv := -1.0
				for hid in w.hero_ids:
					var v := w.familiarity(lu[side][s], hid) * w.hero_fit(w.heroes[hid], s)
					if v > bv or (v == bv and hid < best):
						bv = v
						best = hid
				comfort[side].append(best)
		var td := Time.get_ticks_msec()
		var d := Draft.make(w, lu, meta, gi, "bx:%d" % gi, nb)
		while not d.is_done():
			var kind := String(d.current()["kind"])
			d.apply(d.ai_choice())
			for s3 in SLOTS:
				var need := int(not d.picks["B"].has(s3)) + int(not d.picks["R"].has(s3))
				if need == 0:
					continue
				var have := 0
				for h4 in d.avail:
					if String(w.heroes[h4]["role_primary"]) == s3:
						have += 1
				if have < need + (1 if kind == "ban" else 0):
					out["floor_binds"] += 1
		out["ms_draft"] += Time.get_ticks_msec() - td
		var teams := MatchRunner.build_teams(w, d)
		var raw_gap := 0.0
		for ph in ["early", "mid", "late"]:
			for s in SLOTS:
				raw_gap += (float(teams[0]["ratings"][ph][s]) - float(teams[1]["ratings"][ph][s])) / 15.0
		var gap: float = gaps[i % gaps.size()]
		var a_blue := (i / gaps.size()) % 2 == 0     # the stronger team (A) alternates sides
		var tb := _shift(teams[0], 50.0 + (gap if a_blue else 0.0))
		var tr := _shift(teams[1], 50.0 + (0.0 if a_blue else gap))
		var ctx := MatchRunner.context(w, d, {})
		var r := MatchSimV2.simulate(tb, tr, d.mseed, {}, ctx)
		var blue_won := bool(r["a_won"])
		var key := str(int(gap))
		if not out["rows"].has(key):
			out["rows"][key] = {"n": 0, "a_wins": 0}
		out["rows"][key]["n"] += 1
		if blue_won == a_blue:
			out["rows"][key]["a_wins"] += 1
		out["n"] += 1
		out["len"].append(float(r["len_s"]) / 60.0)
		out["kills"].append(int(r["team_kills"]["B"]) + int(r["team_kills"]["R"]))
		for side in ["B", "R"]:
			var other := "R" if side == "B" else "B"
			var lost := 0
			for hid in comfort[side]:
				if d.bans[other].has(hid):
					lost += 1
			out["comfort_lost"].append(lost)
			out["comfort_lost_side"][side] += lost
			var f := 0.0
			for s in SLOTS:
				f += w.familiarity(lu[side][s], String(d.picks[side][s]["id"])) / 5.0
			out["famf"][side] += f
			for hid2 in d.bans[side]:
				out["hero_ban"][hid2] = int(out["hero_ban"].get(hid2, 0)) + 1
			var won_side: bool = (side == "B") == blue_won
			if gap == 0.0:
				if lost >= 2:
					out["lost_win"]["lost"] += 1
					if won_side:
						out["lost_win"]["lost_won"] += 1
			for s2 in SLOTS:
				var hid3 := String(d.picks[side][s2]["id"])
				out["hero_pick"][hid3] = int(out["hero_pick"].get(hid3, 0)) + 1
				if gap == 0.0:
					out["hero_g"][hid3] = int(out["hero_g"].get(hid3, 0)) + 1
					if won_side:
						out["hero_w"][hid3] = int(out["hero_w"].get(hid3, 0)) + 1
		if gap == 0.0:
			out["n0"] += 1
			if blue_won:
				out["blue_wins0"] += 1
		out["raw_gap_won"].append([snappedf(raw_gap, 0.01), blue_won])
	out["ms"] = Time.get_ticks_msec() - t0
	print("BX ", JSON.stringify({"bans": nb, "n": n, "ms": out["ms"]}))
	if OS.get_environment("BX_OUT") != "":
		var fo := FileAccess.open(OS.get_environment("BX_OUT"), FileAccess.WRITE)
		fo.store_string(JSON.stringify(out))
	get_tree().quit()
