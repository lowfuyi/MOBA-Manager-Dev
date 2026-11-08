class_name FormRating
extends RefCounted
## Club Form Rating (GDD 10.1): an Elo-style ranking aid shown in the league table and on the club page.
## It never feeds the simulator. Applied once per series: a league game is a series of one.
##   Expected = 1 / (1 + 10^(-(Fa - Fb) / 400)),  Fa += K * Importance * (Result - Expected),  Fb moves the other way.
## Exhibition and Quick Match have importance 0 (they are simply never rated).

const K := 24.0
const BASE := 1500.0
const PER_POINT := 13.0      # starting offset per Team Rating point above the league mean (a +10 gap is about 68 percent)
const SPREAD := 400.0


static func expected(fa: float, fb: float) -> float:
	return 1.0 / (1.0 + pow(10.0, -(fa - fb) / SPREAD))


## Series win probability from the per-game probability p (best of 1, 3 or 5).
static func series_expected(p: float, best_of: int) -> float:
	match best_of:
		3:
			return p * p * (3.0 - 2.0 * p)
		5:
			return p * p * p * (10.0 - 15.0 * p + 6.0 * p * p)
	return p


## stage: "league" 1.0, "semi" 1.25, "final" 1.5; times 1.0 / 1.2 / 1.4 for best of 1 / 3 / 5. Anything else 0.
static func importance(stage: String, best_of: int) -> float:
	var base := 0.0
	match stage:
		"league":
			base = 1.0
		"semi":
			base = 1.25
		"final":
			base = 1.5
	var mult := 1.0
	if best_of == 3:
		mult = 1.2
	elif best_of >= 5:
		mult = 1.4
	return base * mult


## Rating change for the winner side `a` (negative when the favourite loses); `a_won` is the series result.
static func delta(fa: float, fb: float, a_won: bool, stage: String, best_of: int) -> float:
	var p := expected(fa, fb)
	var e := series_expected(p, best_of)
	return K * importance(stage, best_of) * ((1.0 if a_won else 0.0) - e)


## Starting ratings for a new world: BASE plus PER_POINT per Team Rating point above the league mean.
static func initial(team_ratings: Dictionary) -> Dictionary:
	var mean := 0.0
	for c in team_ratings:
		mean += float(team_ratings[c])
	mean /= float(maxi(1, team_ratings.size()))
	var out := {}
	for c in team_ratings:
		out[c] = BASE + PER_POINT * (float(team_ratings[c]) - mean)
	return out
