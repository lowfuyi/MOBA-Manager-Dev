class_name Honours
extends RefCounted
## Player records and achievements (0.12, ESMO Q4-6), derived only from the career data the save already keeps (Career:
## games, wins, kills, deaths, assists, best game, the log of titles). No save change. Display only.

const GAMES := [100, 50, 25, 10]
const WINS := [50, 25, 10, 5]
const KILLS := [10, 5]
const RATIO_MIN_GAMES := 10


## Achievements of one career entry: [[key, vars]], highest tier of each kind only.
static func achievements(c: Dictionary) -> Array:
	var out: Array = []
	if c.is_empty():
		return out
	for n in GAMES:
		if int(c.get("g", 0)) >= n:
			out.append(["career.ach.games", {"n": n}])
			break
	for n in WINS:
		if int(c.get("w", 0)) >= n:
			out.append(["career.ach.wins", {"n": n}])
			break
	for n in KILLS:
		if int(c.get("best_k", 0)) >= n:
			out.append(["career.ach.kills", {"n": n}])
			break
	var titles := 0
	var finals := 0
	for e in c.get("log", []):
		if String(e["k"]) == "title":
			titles += 1
		elif String(e["k"]) == "runner_up":
			finals += 1
	if titles > 0:
		out.append(["career.ach.titles", {"n": titles}])
	if finals > 0:
		out.append(["career.ach.finals", {"n": finals}])
	return out


## Club records (everyone who has played for us) that `pid` holds: [[key, vars]]. Ties share the record.
static func records(all: Dictionary, pid: String) -> Array:
	var out: Array = []
	if not all.has(pid) or int((all[pid] as Dictionary).get("g", 0)) == 0:
		return out
	var best := {"g": 0.0, "w": 0.0, "best_k": 0.0, "ratio": 0.0}
	for id in all:
		var c: Dictionary = all[id]
		best["g"] = maxf(best["g"], float(c.get("g", 0)))
		best["w"] = maxf(best["w"], float(c.get("w", 0)))
		best["best_k"] = maxf(best["best_k"], float(c.get("best_k", 0)))
		if int(c.get("g", 0)) >= RATIO_MIN_GAMES:
			best["ratio"] = maxf(best["ratio"], Career.kda_ratio(int(c["k"]), int(c["d"]), int(c["a"])))
	var me: Dictionary = all[pid]
	if float(me["g"]) >= best["g"]:
		out.append(["career.rec.games", {"n": int(me["g"])}])
	if int(me["w"]) > 0 and float(me["w"]) >= best["w"]:
		out.append(["career.rec.wins", {"n": int(me["w"])}])
	if int(me["best_k"]) > 0 and float(me["best_k"]) >= best["best_k"]:
		out.append(["career.rec.kills", {"n": int(me["best_k"])}])
	if int(me["g"]) >= RATIO_MIN_GAMES:
		var r := Career.kda_ratio(int(me["k"]), int(me["d"]), int(me["a"]))
		if r >= best["ratio"] and r > 0.0:
			out.append(["career.rec.ratio", {"r": "%.1f" % r, "n": RATIO_MIN_GAMES}])
	return out
