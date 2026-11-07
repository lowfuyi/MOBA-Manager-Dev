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
## suggestion for that team. An empty dictionary reproduces the plain simulator exactly (golden vectors).
static func finish(world: World, d: Draft, plans: Dictionary = {}) -> Dictionary:
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
			"team_a": ta, "team_b": tb, "picks": pick_ids, "bans": d.bans.duplicate(true), "log": d.log.duplicate(true),
			"lineups": {"B": _ids(d.lineups["B"]), "R": _ids(d.lineups["R"])},
			"comp": {"B": ta["comp_mod"], "R": tb["comp_mod"]}, "style": {"B": ta["style"], "R": tb["style"]},
			"full_draft": d.order.size() == Draft.ORDER_FULL.size()}


static func _ids(lineup: Dictionary) -> Dictionary:
	var o := {}
	for s in SLOTS:
		o[s] = lineup[s]["id"]
	return o


## Whole game decided by the AI on both sides.
static func auto(world: World, blue_lineup: Dictionary, red_lineup: Dictionary, meta: Dictionary,
		save_seed: int, match_id: String, full_draft: bool, plans: Dictionary = {}) -> Dictionary:
	var d := prepare(world, blue_lineup, red_lineup, meta, save_seed, match_id, full_draft)
	d.finish_with_ai()
	return finish(world, d, plans)
