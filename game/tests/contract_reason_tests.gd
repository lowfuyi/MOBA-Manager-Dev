extends RefCounted
## Contract refusal reasons (0.12, ESMO Q4-3): Economy.refusal_factors names only what Economy.response weighs (the offer
## against market value, the personality's threshold, the contract length), and every key it gives exists in the copy.


func run(check: Callable) -> void:
	var w := World.load_default()
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/en.json"))
	var want := {"professional": "neg.why.fair", "balanced": "neg.why.discount", "casual": "neg.why.discount", "temperamental": "neg.why.premium"}
	var seen := {}
	var keys_ok := true
	var pct_ok := true
	var len_ok := true
	for pid in w.players:
		var p: Dictionary = w.players[pid]
		var pers := String(p["personality"])
		if seen.has(pers):
			continue
		seen[pers] = true
		var ask := Economy.asking_wage(w, p)
		var wage := maxi(1, int(round(float(ask) * 0.8)))
		var f := Economy.refusal_factors(w, p, wage, 2)
		check.call(f.size() == 3 and String(f[1][0]) == String(want[pers]), "contract why: a %s player is named with %s (%s)" % [pers, want[pers], str(f)])
		pct_ok = pct_ok and String(f[0][0]) == "neg.why.value" and int(f[0][1]["pct"]) == int(round(100.0 * float(wage) / float(ask)))
		var f4 := Economy.refusal_factors(w, p, wage, int(Economy.data()["max_length"]))
		len_ok = len_ok and f4.size() == 2 and String(f.back()[0]) == "neg.why.length"
		for e in f:
			keys_ok = keys_ok and en.has(String(e[0]))
	check.call(seen.size() == 4, "contract why: all four personalities were checked (%s)" % str(seen.keys()))
	check.call(pct_ok, "contract why: the value line is the offer as a percent of the market value")
	check.call(len_ok, "contract why: the length line shows only below the longest contract")
	check.call(keys_ok and en.has("neg.why.h"), "contract why: every key is in the copy")
