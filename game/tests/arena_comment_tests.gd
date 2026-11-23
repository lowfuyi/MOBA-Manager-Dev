extends RefCounted
## Commentary for v2 games (0.12, Q4): at most two lines a game, only in calm moments, from real log events, every key in the
## copy, none in large text, the same lines every time for the same game.


func run(check: Callable) -> void:
	var w := World.load_default()
	var meta := w.make_meta("comment-test")
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/en.json"))
	var max_ok := true
	var calm_ok := true
	var keys_ok := true
	var det_ok := true
	var total := 0
	var games_with := 0
	var kinds := {}
	var shown_ok := true
	for i in 8:
		var r := MatchRunner.auto(w, w.best_lineup(w.club_ids[i % 10]), w.best_lineup(w.club_ids[(i + 3) % 10]), meta, 8400 + i, "comment:%d" % i, 3, {"B": "ai", "R": "ai"})
		var pl := ArenaPlayer.build(r, "B")
		var c := ArenaComment.build(pl)
		max_ok = max_ok and c.lines.size() <= ArenaComment.MAX_LINES
		total += c.lines.size()
		if not c.lines.is_empty():
			games_with += 1
		det_ok = det_ok and JSON.stringify(c.lines) == JSON.stringify(ArenaComment.build(pl).lines)
		for l in c.lines:
			calm_ok = calm_ok and ArenaComment.is_calm(pl, float(l[0]))
			keys_ok = keys_ok and en.has(String(l[2]))
			kinds[String(l[2]).get_slice(".", 2).get_slice("_", 0)] = true
			shown_ok = shown_ok and c.text_at(float(l[0]) + 0.1) != "" and c.text_at(float(l[1]) + 5.0) == ""
	check.call(max_ok, "commentary: at most %d lines a game" % ArenaComment.MAX_LINES)
	check.call(total > 0 and games_with >= 4, "commentary: most games get a line (%d lines in %d of 8 games)" % [total, games_with])
	check.call(calm_ok, "commentary: every line is shown in a calm moment (no fight, kill, tower or objective around it)")
	check.call(keys_ok, "commentary: every line is a key in en.json")
	check.call(det_ok, "commentary: the same game gives the same lines")
	check.call(shown_ok, "commentary: a line shows in its window and not after it")
	check.call(kinds.size() >= 2, "commentary: lines come from more than one kind of event (%s)" % str(kinds.keys()))
	# the Match screen: none in large text
	var src := FileAccess.get_file_as_string("res://src/ui/screen_match.gd")
	check.call(src.contains("_notes.comments = null if UI.large else ArenaComment.build(player)"), "commentary: the Match screen builds none in large text")
	var arena_src := FileAccess.get_file_as_string("res://src/arena/v2/arena_comment.gd")
	check.call(not arena_src.contains("MatchSim") and not arena_src.contains("GamePlan.simulate"), "commentary: reads the log only, never the simulation (rule A1)")
