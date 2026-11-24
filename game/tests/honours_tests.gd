extends RefCounted
## Player records and achievements (0.12, ESMO Q4-6): only from career data, highest tier only, ties share a record.


func run(check: Callable) -> void:
	var all := {
		"a": {"g": 60, "w": 30, "k": 120, "d": 40, "a": 200, "best_k": 11, "by_season": {}, "log": [{"s": 1, "k": "title", "a": {}}, {"s": 2, "k": "title", "a": {}}, {"s": 3, "k": "runner_up", "a": {}}]},
		"b": {"g": 60, "w": 20, "k": 30, "d": 50, "a": 60, "best_k": 4, "by_season": {}, "log": []},
		"c": {"g": 3, "w": 3, "k": 30, "d": 0, "a": 0, "best_k": 12, "by_season": {}, "log": []},
		"z": {"g": 0, "w": 0, "k": 0, "d": 0, "a": 0, "best_k": 0, "by_season": {}, "log": []}}
	var ach := Honours.achievements(all["a"])
	var keys: Array = []
	for e in ach:
		keys.append(e[0])
	check.call(keys == ["career.ach.games", "career.ach.wins", "career.ach.kills", "career.ach.titles", "career.ach.finals"], "honours: every kind once (%s)" % str(keys))
	check.call(int(ach[0][1]["n"]) == 50 and int(ach[1][1]["n"]) == 25 and int(ach[2][1]["n"]) == 10 and int(ach[3][1]["n"]) == 2, "honours: the highest tier reached (%s)" % str(ach))
	check.call(Honours.achievements(all["z"]).is_empty(), "honours: no games, no achievements")
	var ra := Honours.records(all, "a")
	var rk: Array = []
	for e in ra:
		rk.append(e[0])
	check.call(rk == ["career.rec.games", "career.rec.wins", "career.rec.ratio"], "honours: a holds games (tied), wins and ratio, not kills (%s)" % str(rk))
	var rb := Honours.records(all, "b")
	check.call(rb.size() == 1 and String(rb[0][0]) == "career.rec.games", "honours: a tie shares the record (%s)" % str(rb))
	var rc := Honours.records(all, "c")
	check.call(rc.size() == 1 and String(rc[0][0]) == "career.rec.kills", "honours: a short career holds kills but not the ratio (%s)" % str(rc))
	check.call(Honours.records(all, "z").is_empty() and Honours.records(all, "nobody").is_empty(), "honours: no games, no records")
