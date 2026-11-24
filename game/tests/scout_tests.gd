extends RefCounted
## Scouting summary (0.12, ESMO Q4-2): grades follow the world's rating spread, notes and pros/cons come from fixed keys
## that exist in the copy, at most two pros and two cons, and a pro is never also a con.


func run(check: Callable) -> void:
	var w := World.load_default()
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/en.json"))
	var t := Scout.table(w)
	var counts := {"A": 0, "B": 0, "C": 0, "D": 0}
	var keys_ok := true
	var caps_ok := true
	var apart_ok := true
	var order_ok := true
	var best_g := ""
	var best_r := -INF
	var worst_g := ""
	var worst_r := INF
	for pid in w.players:
		var p: Dictionary = w.players[pid]
		var s := Scout.summary(w, p, t)
		counts[s["grade"]] += 1
		var r := Economy.best_slot_rating(w, p)
		if r > best_r:
			best_r = r
			best_g = s["grade"]
		if r < worst_r:
			worst_r = r
			worst_g = s["grade"]
		keys_ok = keys_ok and en.has(String(s["note"][0]))
		caps_ok = caps_ok and (s["pros"] as Array).size() <= 2 and (s["cons"] as Array).size() <= 2
		var ps := {}
		for e in s["pros"]:
			keys_ok = keys_ok and en.has(String(e[0]))
			ps[e[1]["stat"]] = true
		for e in s["cons"]:
			keys_ok = keys_ok and en.has(String(e[0]))
			apart_ok = apart_ok and not ps.has(e[1]["stat"])
		order_ok = order_ok and ("ABCD".find(String(s["grade"])) >= 0)
	var n := float(w.players.size())
	check.call(best_g == "A" and worst_g == "D", "scout: the best-rated player is A and the worst D (%s, %s)" % [best_g, worst_g])
	check.call(float(counts["A"]) <= 0.10 * n + 1.0 and float(counts["A"] + counts["B"]) <= 0.30 * n + 1.0, "scout: A is the top tenth, A and B the top 30%% (%s of %d)" % [str(counts), int(n)])
	check.call(counts["D"] > 0 and counts["C"] > 0, "scout: every grade is used (%s)" % str(counts))
	check.call(keys_ok and en.has("scout.h") and en.has("scout.grade"), "scout: every key is in the copy")
	check.call(caps_ok, "scout: at most two pros and two cons")
	check.call(apart_ok and order_ok, "scout: a stat is never both a pro and a con")
