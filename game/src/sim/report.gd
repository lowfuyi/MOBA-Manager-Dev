class_name Report
extends RefCounted
## Match feed and report (GDD 8.5), built only from the signed contest results of the match,
## so a line can never contradict the outcome. Attribution is by counterfactual re-simulation
## with the same outcome seed.

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const PHASES := ["early", "mid", "late"]

## Contests in the order the feed shows them, with their moment as a fraction of the game clock.
const FEED_ORDER := [
	["top", 0.18], ["mid_lane", 0.21], ["bot", 0.24], ["jungle", 0.27],
	["obj_mid", 0.45], ["fight_mid", 0.60], ["obj_late", 0.80], ["fight_late", 0.95],
]


## True for a result played by Match Sim v2 (its "sim" carries the event log and the per-hero lines).
static func is_v2(result: Dictionary) -> bool:
	return int((result.get("sim", {}) as Dictionary).get("v", 1)) == 2


## Game clock in minutes. v2: the simulated length. v1 (old results): the cosmetic clock (GDD 8.5 / 8.7).
static func game_minutes(result: Dictionary) -> float:
	if is_v2(result):
		return float(result["sim"]["len_s"]) / 60.0
	var sim: Dictionary = result["sim"]
	var mean_lead := (absf(float(sim["mid"])) + absf(float(sim["late"]))) / 2.0
	var z := Pcg32.contest_stream(int(result["mseed"]), "length").next_normal()
	return clampf(11.0 + 6.0 * (1.0 - mean_lead) + z, 9.0, 16.0)


## Words for one contest. Contest values are tanh-saturated (median |c| about 0.9), so the cut points
## sit high: roughly 25% narrow, 45% clear, 30% decisive over simulated games.
static func margin_word(c: float) -> String:
	var a := absf(c)
	if a < 0.60:
		return "narrow"
	if a < 0.97:
		return "clear"
	return "decisive"


## Words for the whole game from the signed final (median |final| about 0.3): about 25% / 35% / 40%.
static func result_word(final_value: float) -> String:
	var a := absf(final_value)
	if a < 0.15:
		return "narrow"
	if a < 0.40:
		return "clear"
	return "decisive"


## Feed events from the point of view of `my_side` ("B" or "R"). Each event:
## {"t": fraction of the game, "key": contest id, "mine": bool (you won it), "size": narrow|clear|decisive, "value": signed for you}
static func feed(result: Dictionary, my_side: String) -> Array:
	var sign_for_me := 1.0 if my_side == "B" else -1.0
	var out: Array = []
	for item in FEED_ORDER:
		var c := float(result["sim"]["contests"][item[0]]) * sign_for_me
		out.append({"t": item[1], "key": item[0], "mine": c > 0.0, "size": margin_word(c), "value": c})
	return out


static func _dup_team(t: Dictionary) -> Dictionary:
	return t.duplicate(true)


static func _neutral(t: Dictionary) -> Dictionary:
	var n := _dup_team(t)
	n["comp_mod"] = 0.0
	n["lane_mod"] = {}
	n["style"] = "skirmish"
	return n


## Counterfactual attribution. Returns {"factors": [{"id", "value", "share"}], "luck_share", "draft_share"}
## where value is the change in Final (positive helps `my_side`) and share is value / sum(|value|).
static func attribution(result: Dictionary, my_side: String) -> Dictionary:
	if is_v2(result):
		return _attribution_v2(result, my_side)
	var ta: Dictionary = result["team_a"]
	var tb: Dictionary = result["team_b"]
	var p := MatchRunner.sim_params()
	var ms := int(result["mseed"])
	var actual := float(result["final"])
	var sgn := 1.0 if my_side == "B" else -1.0
	var plans: Dictionary = result.get("plans", {})
	var factors: Array = []
	for s in SLOTS:
		var cf := _dup_team(ta)
		for ph in PHASES:
			cf["ratings"][ph][s] = tb["ratings"][ph][s]
		var f: float = float(GamePlan.simulate(cf, tb, ms, p, plans)["final"])
		factors.append({"id": "slot." + s, "value": (actual - f) * sgn})
	var draft_f := float(GamePlan.simulate(_neutral(ta), _neutral(tb), ms, p, plans)["final"])
	factors.append({"id": "draft", "value": (actual - draft_f) * sgn})
	if plans.has(my_side) and not (plans[my_side]["triggers"].is_empty() and GamePlan.is_neutral(plans[my_side]["default"])):
		var without := plans.duplicate()
		without.erase(my_side)
		var plan_f := float(GamePlan.simulate(ta, tb, ms, p, without)["final"])
		factors.append({"id": "plan", "value": (actual - plan_f) * sgn})
	var eq_a := _neutral(tb)
	eq_a["style"] = "skirmish"
	var luck_f := float(MatchSim.simulate(eq_a, _neutral(tb), ms, p)["final"])
	factors.append({"id": "luck", "value": luck_f * sgn})
	var total := 0.0
	for f in factors:
		total += absf(f["value"])
	for f in factors:
		f["share"] = f["value"] / total if total > 0.0 else 0.0
	return {"factors": factors}

## v2 attribution (MATCH-SIM-V2-DESIGN 8.2): each factor is its EDGE GOING IN, the change in the noise-free analytic
## prediction (the v1 contest model at sigma 0) when that factor is removed; "luck" is how far the real result was from that
## prediction (the winner's side counts as +OUTCOME). Shares add to 100 percent; a factor's value is positive when it helped
## `my_side`. Nothing here re-runs the v2 game, so it costs a few noise-free evaluations.
const OUTCOME := 0.35


static func _attribution_v2(result: Dictionary, my_side: String) -> Dictionary:
	var ta: Dictionary = result["team_a"]
	var tb: Dictionary = result["team_b"]
	var p := MatchRunner.sim_params()
	var sgn := 1.0 if my_side == "B" else -1.0
	var plans: Dictionary = result.get("plans", {})
	var e_actual := GamePlan.expected_final(ta, tb, p, plans)
	var factors: Array = []
	for s in SLOTS:
		var cf := _dup_team(ta)
		for ph in PHASES:
			cf["ratings"][ph][s] = tb["ratings"][ph][s]
		factors.append({"id": "slot." + s, "value": (e_actual - GamePlan.expected_final(cf, tb, p, plans)) * sgn})
	factors.append({"id": "draft", "value": (e_actual - GamePlan.expected_final(_neutral(ta), _neutral(tb), p, plans)) * sgn})
	if plans.has(my_side) and not (plans[my_side]["triggers"].is_empty() and GamePlan.is_neutral(plans[my_side]["default"])):
		var without := plans.duplicate()
		without.erase(my_side)
		factors.append({"id": "plan", "value": (e_actual - GamePlan.expected_final(ta, tb, p, without)) * sgn})
	var outcome := OUTCOME if bool(result["blue_won"]) else -OUTCOME
	factors.append({"id": "luck", "value": (outcome - clampf(e_actual, -OUTCOME, OUTCOME)) * sgn})
	var total := 0.0
	for f in factors:
		total += absf(f["value"])
	for f in factors:
		f["share"] = f["value"] / total if total > 0.0 else 0.0
	return {"factors": factors, "expected": e_actual * sgn}


# ---------------------------------------------------------------- derived kills, deaths and assists (GDD 9.2 test 6)
## Display only, never fed back into any result. Drawn from their own stream ("kda") of the match seed, so the
## same game always shows the same lines. Rules: the winner always has more kills than the loser; one side's
## kills are the other side's deaths; nobody assists his own kill (assists + kills of a player <= team kills).
const KDA_KILL_W := {"top": 1.0, "jg": 1.1, "mid": 1.3, "bot": 1.4, "sup": 0.5}
const KDA_DEATH_W := {"top": 1.0, "jg": 1.0, "mid": 0.9, "bot": 0.9, "sup": 1.2}
const KDA_ASSIST_W := {"top": 0.8, "jg": 1.3, "mid": 1.0, "bot": 0.8, "sup": 1.6}
const KDA_LANE := {"top": "top", "jg": "jungle", "mid": "mid_lane", "bot": "bot", "sup": "bot"}


## Returns {"B": {slot: {"k","d","a"}}, "R": {...}, "team": {"B": {"k","d","a"}, "R": {...}}}.
## v2: counted from the event log's kills (a tower's execution of a hero nobody damaged is a death without a kill, so a
## side's deaths are the other side's kills plus such executions). v1: drawn as before (display only).
static func kda(result: Dictionary) -> Dictionary:
	if is_v2(result):
		return _kda_v2(result)
	var rng := Pcg32.contest_stream(int(result["mseed"]), "kda")
	var minutes := game_minutes(result)
	var total := clampi(int(round(minutes * 2.2 + rng.next_normal() * 2.0)), 18, 44)
	var dom := clampf(absf(float(result["final"])), 0.0, 1.0)
	var k_win := int(ceil(float(total) * (0.55 + 0.25 * dom)))
	var k_lose := total - k_win
	while k_win <= k_lose:
		k_win += 1
	var blue_won: bool = bool(result["blue_won"])
	var kills := {"B": k_win if blue_won else k_lose, "R": k_lose if blue_won else k_win}
	var out := {"team": {}}
	var contests: Dictionary = result["sim"]["contests"]
	var k_counts := {}
	for side in ["B", "R"]:
		var sgn := 1.0 if side == "B" else -1.0
		var kw: Array = []
		for s in SLOTS:
			kw.append(float(KDA_KILL_W[s]) * (1.0 + 0.35 * float(contests[KDA_LANE[s]]) * sgn) * (0.8 + 0.4 * rng.next_float()))
		k_counts[side] = _draw_units(int(kills[side]), kw, [], rng)
	for side in ["B", "R"]:
		var other := "R" if side == "B" else "B"
		var sgn2 := 1.0 if side == "B" else -1.0
		var dw: Array = []
		for s in SLOTS:
			dw.append(float(KDA_DEATH_W[s]) * (1.0 - 0.35 * float(contests[KDA_LANE[s]]) * sgn2) * (0.8 + 0.4 * rng.next_float()))
		var deaths := _draw_units(int(kills[other]), dw, [], rng)
		var team_k: int = int(kills[side])
		var a_total := mini(4 * team_k, int(round(float(team_k) * (1.5 + 0.5 * rng.next_float()))))
		var aw: Array = []
		var caps: Array = []
		for i in SLOTS.size():
			aw.append(float(KDA_ASSIST_W[SLOTS[i]]) * (0.8 + 0.4 * rng.next_float()))
			caps.append(team_k - int(k_counts[side][i]))
		var assists := _draw_units(a_total, aw, caps, rng)
		out[side] = {}
		var ta := 0
		for i in SLOTS.size():
			out[side][SLOTS[i]] = {"k": int(k_counts[side][i]), "d": int(deaths[i]), "a": int(assists[i])}
			ta += int(assists[i])
		out["team"][side] = {"k": team_k, "d": int(kills[other]), "a": ta}
	return out


static func _kda_v2(result: Dictionary) -> Dictionary:
	var per: Dictionary = result["sim"]["per"]
	var out := {"team": {}}
	for side in ["B", "R"]:
		out[side] = {}
		var tk := 0
		var td := 0
		var ta := 0
		for s in SLOTS:
			var x: Dictionary = per[side + "." + s]
			out[side][s] = {"k": int(x["k"]), "d": int(x["d"]), "a": int(x["a"])}
			tk += int(x["k"])
			td += int(x["d"])
			ta += int(x["a"])
		out["team"][side] = {"k": tk, "d": td, "a": ta}
	return out


## Read-only (0.7, I-06): team kills per side, {"B": int, "R": int}: the sum of the players' kills in `kda(result)`.
## It is also kda()["team"][side]["k"] by construction; this is the score line of the Report screen.
static func team_kills(result: Dictionary) -> Dictionary:
	var k := kda(result)
	var out := {"B": 0, "R": 0}
	for side in ["B", "R"]:
		for s in SLOTS:
			out[side] = int(out[side]) + int(k[side][s]["k"])
	return out


## Hand out `units` one at a time to indexes drawn by weight; `caps` (optional) limits each index.
static func _draw_units(units: int, weights: Array, caps: Array, rng: Pcg32) -> Array:
	var counts: Array = []
	for i in weights.size():
		counts.append(0)
	for u in units:
		var sum := 0.0
		for i in weights.size():
			if caps.is_empty() or int(counts[i]) < int(caps[i]):
				sum += float(weights[i])
		if sum <= 0.0:
			break
		var r := rng.next_float() * sum
		var pick := -1
		for i in weights.size():
			if caps.is_empty() or int(counts[i]) < int(caps[i]):
				pick = i
				r -= float(weights[i])
				if r <= 0.0:
					break
		counts[pick] = int(counts[pick]) + 1
	return counts
