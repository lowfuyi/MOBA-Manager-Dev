extends RefCounted
## Finance summary (0.12, ESMO Q4-5): rounds and category totals come straight from the ledger.


func run(check: Callable) -> void:
	var led: Array = []
	for r in 12:
		led.append({"s": 1, "r": r, "k": "wages", "a": -30.0})
		led.append({"s": 1, "r": r, "k": "retainer", "a": 40.0})
	led.append({"s": 1, "r": 11, "k": "signing", "a": -50.0})
	led.append({"s": 2, "r": 0, "k": "wages", "a": -32.0})
	led.append({"s": 2, "r": 0, "k": "prize_league", "a": 500.0})
	var rs := FinFlow.rounds(led)
	check.call(rs.size() == FinFlow.ROUNDS, "fin flow: the last %d rounds (%d)" % [FinFlow.ROUNDS, rs.size()])
	var last: Dictionary = rs.back()
	check.call(int(last["s"]) == 2 and is_equal_approx(float(last["in"]), 500.0) and is_equal_approx(float(last["out"]), 32.0), "fin flow: the newest round is last, with its income and costs")
	var prev: Dictionary = rs[rs.size() - 2]
	check.call(is_equal_approx(float(prev["out"]), 80.0) and is_equal_approx(float(prev["in"]), 40.0), "fin flow: every entry of a round counts (wages and a signing fee)")
	var bk := FinFlow.by_kind(led, 1)
	check.call(String(bk["in"][0][0]) == "retainer" and is_equal_approx(float(bk["in"][0][1]), 480.0), "fin flow: season income by kind")
	check.call(String(bk["out"][0][0]) == "wages" and is_equal_approx(float(bk["out"][0][1]), 360.0) and String(bk["out"][1][0]) == "signing", "fin flow: season costs by kind, largest first")
	check.call((FinFlow.by_kind(led, 3)["in"] as Array).is_empty(), "fin flow: a season with no entries is empty")
