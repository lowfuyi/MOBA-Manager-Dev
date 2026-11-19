class_name MatchRunner
extends RefCounted
## Glue between draft, team building and the simulator. Used for AI-vs-AI games (whole draft by the AI)
## and for the managed club's games (the UI drives the draft, then calls finish()).

const SLOTS := ["top", "jg", "mid", "bot", "sup"]

static var _sim_params: Dictionary = {}


static func sim_params() -> Dictionary:
	if _sim_params.is_empty():
		_sim_params = MatchSim.load_params()
	return _sim_params


static func prepare(world: World, blue_lineup: Dictionary, red_lineup: Dictionary, meta: Dictionary,
		save_seed: int, match_id: String, full_draft: bool) -> Draft:
	var ms := Pcg32.match_seed(save_seed, match_id)
	return Draft.make(world, {"B": blue_lineup, "R": red_lineup}, meta, ms, match_id, full_draft)


## Build both teams from a finished draft and simulate. Returns everything the report needs.
static func build_teams(world: World, d: Draft) -> Array:
	assert(d.is_done())
	return [world.build_team(d.lineups["B"], d.picks["B"], d.picks["R"], d.meta),
			world.build_team(d.lineups["R"], d.picks["R"], d.picks["B"], d.meta)]


## plans: {"B": plan_set | "ai", "R": plan_set | "ai"}; a missing side plays neutral, "ai" is the coach's
## suggestion for that team. The result's "plans" key holds the resolved sets that were played (a missing side
## stays missing = neutral). builds: {player id: {hero id: [six item ids]}} edited by the manager (Phase 5); any hero
## without a legal edited build plays the coach's suggestion.
## Since Match Sim v2 (2026-11-19) the game is played by MatchSimV2 (ten role-driven agents; the result's "sim" holds the v2
## result with its event log, and fills the v1 keys contests, early, mid, late and plan_used for older readers). The v1
## contest model (MatchSim, GamePlan.simulate) stays as the analytic predictor: Game Plan preview, coach and "edges going in".
static func finish(world: World, d: Draft, plans: Dictionary = {}, builds: Dictionary = {}) -> Dictionary:
	var teams := build_teams(world, d)
	var ta: Dictionary = teams[0]
	var tb: Dictionary = teams[1]
	var sets := {}
	for side in ["B", "R"]:
		if not plans.has(side):
			continue
		if plans[side] is String:
			sets[side] = GamePlan.suggest_set(ta, tb, sim_params(), side)
		else:
			sets[side] = plans[side]
	var ctx := context(world, d, builds)
	var r := MatchSimV2.simulate(ta, tb, d.mseed, sets, ctx)
	var pick_ids := {"B": {}, "R": {}}
	for t in ["B", "R"]:
		for s in SLOTS:
			pick_ids[t][s] = d.picks[t][s]["id"]
	var used := {"B": {}, "R": {}}
	for t2 in ["B", "R"]:
		for s2 in SLOTS:
			used[t2][s2] = (r["per"][t2 + "." + s2]["build"] as Array).duplicate()
	return {"match_id": d.match_id, "mseed": d.mseed, "blue_won": r["a_won"], "final": r["final"], "sim": r, "v": 2, "builds": used,
			"team_a": ta, "team_b": tb, "plans": sets.duplicate(true), "picks": pick_ids, "bans": d.bans.duplicate(true), "log": d.log.duplicate(true),
			"lineups": {"B": _ids(d.lineups["B"]), "R": _ids(d.lineups["R"])},
			"comp": {"B": ta["comp_mod"], "R": tb["comp_mod"]}, "style": {"B": ta["style"], "R": tb["style"]},
			"full_draft": d.order.size() == Draft.ORDER_FULL.size()}


## The v1 contest model's game for a finished draft, exactly as MatchRunner.finish played it before Match Sim v2 (the analytic
## predictor with its noise). Kept for the pipeline golden vectors and for the Alpha 0.8 arena's tests until Arena v2 replaces
## that show; never used for a real game since 2026-11-19.
static func finish_v1(world: World, d: Draft, plans: Dictionary = {}) -> Dictionary:
	var teams := build_teams(world, d)
	var ta: Dictionary = teams[0]
	var tb: Dictionary = teams[1]
	var sets := {}
	for side in ["B", "R"]:
		if not plans.has(side):
			continue
		if plans[side] is String:
			sets[side] = GamePlan.suggest_set(ta, tb, sim_params(), side)
		else:
			sets[side] = plans[side]
	var r := GamePlan.simulate(ta, tb, d.mseed, sim_params(), sets)
	var pick_ids := {"B": {}, "R": {}}
	for t in ["B", "R"]:
		for s in SLOTS:
			pick_ids[t][s] = d.picks[t][s]["id"]
	return {"match_id": d.match_id, "mseed": d.mseed, "blue_won": r["a_won"], "final": r["final"], "sim": r,
			"team_a": ta, "team_b": tb, "plans": sets.duplicate(true), "picks": pick_ids, "bans": d.bans.duplicate(true), "log": d.log.duplicate(true),
			"lineups": {"B": _ids(d.lineups["B"]), "R": _ids(d.lineups["R"])},
			"comp": {"B": ta["comp_mod"], "R": tb["comp_mod"]}, "style": {"B": ta["style"], "R": tb["style"]},
			"full_draft": d.order.size() == Draft.ORDER_FULL.size()}


static func auto_v1(world: World, blue_lineup: Dictionary, red_lineup: Dictionary, meta: Dictionary,
		save_seed: int, match_id: String, full_draft: bool, plans: Dictionary = {}) -> Dictionary:
	var d := prepare(world, blue_lineup, red_lineup, meta, save_seed, match_id, full_draft)
	d.finish_with_ai()
	return finish_v1(world, d, plans)


## A game between two AI clubs that the player does not play or watch (the league's other fixtures, AI playoff series).
## Since 2026-11-19 these are resolved by the v1 contest model (auto_v1), calibrated to the same GDD 9 bands as Match Sim
## v2, because a full v2 game costs about 0.2 s on desktop (more on a phone) and a match day has four of them. The data
## switch `ai_games_v2` in sim_v2_params.json plays them with Match Sim v2 instead (MATCH-SIM-V2-DESIGN 16, ruling S-B-2).
static func auto_ai(world: World, blue_lineup: Dictionary, red_lineup: Dictionary, meta: Dictionary,
		save_seed: int, match_id: String, full_draft: bool, plans: Dictionary = {}) -> Dictionary:
	if bool(SimData.params().get("ai_games_v2", false)):
		return auto(world, blue_lineup, red_lineup, meta, save_seed, match_id, full_draft, plans)
	return auto_v1(world, blue_lineup, red_lineup, meta, save_seed, match_id, full_draft, plans)


## The v2 simulation context of a finished draft: hero ids, the players (stats), the builds and the starters' Bond.
static func context(world: World, d: Draft, builds: Dictionary = {}) -> Dictionary:
	var ctx := {"picks": {"B": {}, "R": {}}, "players": {"B": {}, "R": {}}, "builds": {"B": {}, "R": {}}, "bonds": {}}
	for side in ["B", "R"]:
		var lu: Dictionary = d.lineups[side]
		for s in SLOTS:
			var hid: String = d.picks[side][s]["id"]
			var pl: Dictionary = lu[s]
			ctx["picks"][side][s] = hid
			ctx["players"][side][s] = pl
			var b: Array = builds.get(String(pl.get("id", "")), {}).get(hid, [])
			if Items.is_legal(b):
				ctx["builds"][side][s] = b.duplicate()
		var total := 0.0
		var n := 0
		for i in SLOTS.size():
			for j in range(i + 1, SLOTS.size()):
				total += world.bond_of(String(lu[SLOTS[i]]["id"]), String(lu[SLOTS[j]]["id"]))
				n += 1
		ctx["bonds"][side] = total / float(maxi(1, n))
	return ctx


static func _ids(lineup: Dictionary) -> Dictionary:
	var o := {}
	for s in SLOTS:
		o[s] = lineup[s]["id"]
	return o


## Whole game decided by the AI on both sides.
static func auto(world: World, blue_lineup: Dictionary, red_lineup: Dictionary, meta: Dictionary,
		save_seed: int, match_id: String, full_draft: bool, plans: Dictionary = {}, builds: Dictionary = {}) -> Dictionary:
	var d := prepare(world, blue_lineup, red_lineup, meta, save_seed, match_id, full_draft)
	d.finish_with_ai()
	return finish(world, d, plans, builds)
