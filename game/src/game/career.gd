class_name Career
extends RefCounted
## Career record of the managed club's players (GDD 4.2 career log): games, wins and derived kills, deaths and
## assists with us (league and playoff games only: Exhibition and Quick Match earn nothing, GDD 7.9), the best
## game, and a short log of signings, departures, birthdays and titles. Lives in the save under "career".

const LOG_MAX := 40
const NOTABLE_KILLS := 8


static func all(d: Dictionary) -> Dictionary:
	if not d.has("career"):
		d["career"] = {}
	return d["career"]


static func of(d: Dictionary, pid: String) -> Dictionary:
	var a := all(d)
	if not a.has(pid):
		a[pid] = {"g": 0, "w": 0, "k": 0, "d": 0, "a": 0, "best_k": 0, "by_season": {}, "log": []}
	return a[pid]


static func add_log(d: Dictionary, pid: String, key: String, args: Dictionary = {}) -> void:
	var c := of(d, pid)
	var log: Array = c["log"]
	log.append({"s": int(d["season"]), "k": key, "a": args})
	while log.size() > LOG_MAX:
		log.pop_front()


## One finished league or playoff game of the managed club. `side` is "B" or "R" for the managed club.
static func record_game(d: Dictionary, result: Dictionary, side: String, won: bool, opp_club: String) -> void:
	var line := Report.kda(result)
	var season := str(int(d["season"]))
	for slot in Report.SLOTS:
		var pid: String = result["lineups"][side][slot]
		var l: Dictionary = line[side][slot]
		var c := of(d, pid)
		c["g"] = int(c["g"]) + 1
		c["w"] = int(c["w"]) + (1 if won else 0)
		c["k"] = int(c["k"]) + int(l["k"])
		c["d"] = int(c["d"]) + int(l["d"])
		c["a"] = int(c["a"]) + int(l["a"])
		var bs: Dictionary = c["by_season"]
		if not bs.has(season):
			bs[season] = {"g": 0, "w": 0, "k": 0, "d": 0, "a": 0}
		var e: Dictionary = bs[season]
		e["g"] = int(e["g"]) + 1
		e["w"] = int(e["w"]) + (1 if won else 0)
		e["k"] = int(e["k"]) + int(l["k"])
		e["d"] = int(e["d"]) + int(l["d"])
		e["a"] = int(e["a"]) + int(l["a"])
		if int(l["k"]) > int(c["best_k"]):
			c["best_k"] = int(l["k"])
			c["best_vs"] = opp_club
			if int(l["k"]) >= NOTABLE_KILLS:
				add_log(d, pid, "best_game", {"k": int(l["k"]), "opp": opp_club})


## "3.4" style ratio, never divides by zero.
static func kda_ratio(k: int, dd: int, a: int) -> float:
	return float(k + a) / float(maxi(1, dd))
