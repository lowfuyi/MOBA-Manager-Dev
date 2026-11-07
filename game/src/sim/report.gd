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


## Cosmetic game clock in minutes (GDD 8.5 / 8.7). Never feeds back into the result.
static func game_minutes(result: Dictionary) -> float:
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
