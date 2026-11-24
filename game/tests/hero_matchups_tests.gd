extends RefCounted
## Hero matchup hint (0.12, ESMO Q4-8): the data file is complete, every row names a real hero and meets the stated sample and
## threshold, and the definition is in the file.


func run(check: Callable) -> void:
	var w := World.load_default()
	var d := HeroMatchups.doc()
	check.call(not d.is_empty() and String(d.get("_doc", "")).length() > 100, "matchups: the file loads and states its definition")
	var heroes: Dictionary = d.get("heroes", {})
	var all_known := true
	for hid in w.heroes:
		all_known = all_known and heroes.has(hid)
	check.call(all_known, "matchups: every hero has an entry (%d of %d)" % [heroes.size(), w.heroes.size()])
	var rows_ok := true
	var n_rows := 0
	for hid in heroes:
		var rows: Array = HeroMatchups.struggles(hid)
		rows_ok = rows_ok and rows.size() <= 3
		var last := -INF
		for r in rows:
			n_rows += 1
			rows_ok = rows_ok and w.heroes.has(String(r["vs"])) and String(r["vs"]) != hid
			rows_ok = rows_ok and int(r["games"]) >= HeroMatchups.min_games() and float(r["delta_pts"]) <= -float(d["struggle_pts"])
			rows_ok = rows_ok and float(r["delta_pts"]) >= last
			last = float(r["delta_pts"])
	check.call(rows_ok, "matchups: rows are real heroes, meet the sample and threshold, worst first (%d rows)" % n_rows)
	check.call(HeroMatchups.min_games() >= 100, "matchups: the minimum sample is stated (%d games a pair)" % HeroMatchups.min_games())
