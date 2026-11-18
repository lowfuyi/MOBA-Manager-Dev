extends Node
## Alpha 0.8 A-05: the arena HUD (ArenaHud.Board and Feed) against the show script, headless. Ends with " N checks, M failures".
##   tie-out   at 75 s the board's kills are Report.kda's team kills, towers the ledger's, the gold leader the match winner (I2),
##             the objective owners the contest winners; the numbers never go down
##   feed      at each stamp the newest line is that contest with Report.feed's tick or cross and size; the end card from 75 s
##             says won or lost with the kill score
##   fit       row A at 720 and 626 px (large text): the longest club last word, the clock and the biggest gold lead of the
##             sample never overlap; the feed's longest contest name fits with its dots; no HUD text under 24 px
##   phase     Early before 24.0 s, Mid to 51.0 s, Late after

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ready() -> void:
	await get_tree().process_frame
	var w := World.load_default()
	var meta := w.make_meta("hud-test")
	var bad := {}
	var max_gold := 0
	var n := 40
	for i in n:
		var a: String = w.club_ids[i % w.club_ids.size()]
		var b: String = w.club_ids[(i * 7 + 1) % w.club_ids.size()]
		if a == b:
			b = w.club_ids[(i + 1) % w.club_ids.size()]
		var res := MatchRunner.auto(w, w.best_lineup(a), w.best_lineup(b), meta, 7700 + i, "hud:%d" % i, false, {"B": "ai", "R": "ai"})
		var me := "B" if i % 2 == 0 else "R"
		var s := ShowScript.build(res, me)
		var kd := Report.kda(res)
		var v := ArenaHud.board_values(s, 75.0)
		var them := ShowScript.other(me)
		if int(v["kills_you"]) != int(kd["team"][me]["k"]) or int(v["kills_them"]) != int(kd["team"][them]["k"]):
			bad["kills"] = true
		if int(v["towers_you"]) != int(s.tower_count[me]) or int(v["towers_them"]) != int(s.tower_count[them]):
			bad["towers"] = true
		if String(v["gold_leader"]) != ("you" if s.winner == me else "them"):
			bad["gold"] = true
		var stone_w := String(s.contests["obj_mid"]["win"])
		var moon_w := String(s.contests["obj_late"]["win"])
		if String(v["stone"]) != ("you" if stone_w == me else "them") or String(v["moon"]) != ("you" if moon_w == me else "them"):
			bad["objectives"] = true
		if String(ArenaHud.board_values(s, 33.0)["stone"]) != "":
			bad["objectives"] = true
		var prev := ArenaHud.board_values(s, 0.0)
		var t := 0.5
		while t <= 75.0:
			var cur := ArenaHud.board_values(s, t)
			for k in ["kills_you", "kills_them", "towers_you", "towers_them"]:
				if int(cur[k]) < int(prev[k]):
					bad["monotonic"] = true
			max_gold = maxi(max_gold, absi(int(cur["gold"])))
			prev = cur
			t += 0.5
		var fd := Report.feed(res, me)
		for ev in fd:
			var at := float(ev["t"]) * 75.0 + 0.01
			var l1: Dictionary = ArenaHud.feed_lines(s, at, "Club", s.winner == me)[0]
			if String(l1.get("key", "")) != String(ev["key"]) or bool(l1.get("mine", false)) != bool(ev["mine"]) or String(l1.get("size", "")) != String(ev["size"]):
				bad["feed"] = true
		var endl: Array = ArenaHud.feed_lines(s, 75.0, "Club", s.winner == me)
		var score := "%d–%d" % [int(kd["team"][me]["k"]), int(kd["team"][them]["k"])]
		if String(endl[0]["kind"]) != "end" or not String(endl[0]["text"]).contains(score) or bool(endl[0]["won"]) != (s.winner == me):
			bad["end"] = true
		if String(ArenaHud.feed_lines(s, 74.9, "Club", true)[0]["kind"]) == "end" or String(ArenaHud.feed_lines(s, 1.0, "Club", true)[0]["kind"]) != "start":
			bad["end"] = true
	for k2 in ["kills", "towers", "gold", "objectives", "monotonic", "feed", "end"]:
		ok(not bad.has(k2), "HUD %s ties out with the show script on %d results in both seats" % [k2, n])
	# phases
	ok(ArenaHud.phase_key(23.9) == "match.phase.early" and ArenaHud.phase_key(24.0) == "match.phase.mid" and ArenaHud.phase_key(50.9) == "match.phase.mid" and ArenaHud.phase_key(51.0) == "match.phase.late", "phase chip: Early to 24.0 s, Mid to 51.0 s, Late after (6.7.5)")
	# fit: row A with the longest last word in the league and the biggest gold lead seen
	var f26 := UI.font("SemiBold")
	var fnum := UI.font("SemiBold", true)
	var longest := ""
	for id in w.club_ids:
		var lw := ArenaHud.last_word(App.gs.club_name(id) if App.gs != null else String(w.clubs[id]["name"]))
		if CardKit.text_w(f26, UI.S_SMALL, lw) > CardKit.text_w(f26, UI.S_SMALL, longest):
			longest = lw
	var name_w := CardKit.text_w(f26, UI.S_SMALL, longest)
	var centre_w := CardKit.text_w(fnum, UI.S_BODY, "15:59") + 24.0 + 36.0 + CardKit.text_w(fnum, UI.S_BODY, "+" + ArenaHud.grouped(max_gold))
	for width in [720.0, 626.0]:
		var side_room := 24.0 + 40.0 + name_w + 8.0
		ok(side_room * 2.0 + centre_w <= width, "row A fits at %d px: \"%s\" (%.0f px) on each side and a centre of %.0f px (clock and gold %s)" % [int(width), longest, name_w, centre_w, ArenaHud.grouped(max_gold)])
	ok(name_w <= 150.0, "the longest club last word fits its 150 px banner room (%.0f px)" % name_w)
	var feed_longest := 0.0
	for key in ShowScript.ORDER:
		feed_longest = maxf(feed_longest, CardKit.text_w(UI.font("SemiBold"), UI.S_SMALL, Strings.t("feed.t." + key)))
	ok(42.0 + feed_longest + 18.0 + 16.0 * 3.0 + 5.0 <= 626.0 - 48.0, "the longest feed line with three dots fits the large-text strip (%.0f px)" % (42.0 + feed_longest + 71.0))
	var src := FileAccess.get_file_as_string("res://src/arena/arena_hud.gd")
	var rx := RegEx.new()
	rx.compile("q\\.text\\([^,]+, ([^,]+),")    # A-08: the HUD queues text through CardKit.Ops (q.text(font, size, ...))
	var used := {}
	for m in rx.search_all(src):
		used[m.get_string(1).strip_edges()] = true
	var floor := {"UI.S_CAPTION": UI.S_CAPTION, "UI.S_SMALL": UI.S_SMALL, "UI.S_BODY": UI.S_BODY}
	var sizes_ok := used.size() >= 3
	for k3 in used:
		sizes_ok = sizes_ok and floor.has(k3) and int(floor[k3]) >= 24
	ok(sizes_ok, "every HUD text call uses a scale size of 24 px or more %s" % str(used.keys()))
	print(" %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)
