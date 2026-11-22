extends RefCounted
## Draft formats (Founder decision 2026-11-22; data/draft_formats_v1.json, DraftFormat). Auto-discovered by run_tests.gd.
##   orders     the 1- and 3-ban orders in data are exactly the old Draft.ORDER_SHORT / ORDER_FULL; the 5-ban order has 20 steps,
##              5 bans and 5 picks a side, Blue picks first, Red picks last, and ban phase 2 starts with Red
##   modes      standard: league 5, semi-final 5 in every game, final 5, quick 3, exhibition 3; classic: league 1, playoffs 3 then 1
##   legacy     a game dictionary with only "full" still reads (true = 3, false = 1); a bool draft argument still works
##   drafts     AI drafts with 1, 3 and 5 bans finish with every hero used once and five slots filled a side; phase_of
##   floor      random drafts (random bans, picks and lanes) in the 5-ban order never dead-end, and the GDD 6 role floor is counted
##   device     [draft] bans and [arena] camera: defaults, round trip, bad values

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const PATH := "user://draft_format_test.cfg"


func run(check: Callable) -> void:
	var keep := DraftFormat.mode
	_orders(check)
	_modes(check)
	_legacy(check)
	_drafts(check)
	_floor(check)
	_device(check)
	DraftFormat.mode = keep


func _orders(check: Callable) -> void:
	check.call(DraftFormat.order_for(1) == Draft.ORDER_SHORT, "orders: the 1-ban order in data is the old short order")
	check.call(DraftFormat.order_for(3) == Draft.ORDER_FULL, "orders: the 3-ban order in data is the old full order")
	var o := DraftFormat.order_for(5)
	var n := {"B.ban": 0, "R.ban": 0, "B.pick": 0, "R.pick": 0}
	for st in o:
		n["%s.%s" % [st[0], st[1]]] += 1
	check.call(o.size() == 20 and n["B.ban"] == 5 and n["R.ban"] == 5 and n["B.pick"] == 5 and n["R.pick"] == 5, "orders: 5-ban order has 20 steps, 5 bans and 5 picks a side %s" % str(n))
	var first_pick := -1
	var last_pick := -1
	for i in o.size():
		if o[i][1] == "pick":
			if first_pick < 0:
				first_pick = i
			last_pick = i
	check.call(o[first_pick][0] == "B" and o[last_pick][0] == "R", "orders: Blue picks first, Red picks last")
	check.call(o[12] == ["R", "ban"] and o[13] == ["B", "ban"] and o[6] == ["B", "pick"], "orders: ban phase 2 starts with Red after six picks")
	check.call(DraftFormat.order_for(7) == DraftFormat.order_for(1), "orders: an unknown count falls back to 1 ban")
	check.call(DraftFormat.timer_s(1) == 10.0 and DraftFormat.timer_s(3) >= 10.0 and DraftFormat.timer_s(5) >= 10.0, "orders: timers read from data")


func _modes(check: Callable) -> void:
	DraftFormat.mode = "standard"
	var ok_std := DraftFormat.bans_for("league") == 5 and DraftFormat.bans_for("quick") == 3 and DraftFormat.bans_for("exhibition", 2) == 3
	for g in [1, 2, 3]:
		ok_std = ok_std and DraftFormat.bans_for("playoff_semi", g) == 5
	for g2 in [1, 3, 5]:
		ok_std = ok_std and DraftFormat.bans_for("playoff_final", g2) == 5
	check.call(ok_std, "modes: standard is league 5, semi-final 5 and final 5 in every game, quick 3, exhibition 3")
	DraftFormat.mode = "classic"
	var ok_cl := DraftFormat.bans_for("league") == 1 and DraftFormat.bans_for("quick") == 1 and DraftFormat.bans_for("exhibition") == 1
	ok_cl = ok_cl and DraftFormat.bans_for("playoff_semi", 1) == 3 and DraftFormat.bans_for("playoff_semi", 2) == 1 and DraftFormat.bans_for("playoff_final", 4) == 1
	check.call(ok_cl, "modes: classic is the old 1, and 3 in game 1 of a playoff series")
	DraftFormat.mode = "nonsense"
	check.call(DraftFormat.current_mode() == "standard", "modes: an unknown mode reads as standard")
	check.call(DraftFormat.bans_for("league", 1, "classic") == 1, "modes: an explicit mode wins over the current one")
	DraftFormat.mode = "standard"


func _legacy(check: Callable) -> void:
	check.call(DraftFormat.of_game({"full": true}) == 3 and DraftFormat.of_game({"full": false}) == 1 and DraftFormat.of_game({}) == 1, "legacy: a game with only 'full' reads as 3 or 1 bans")
	check.call(DraftFormat.of_game({"full": false, "bans": 5}) == 5 and DraftFormat.of_game({"bans": 4}) == 1, "legacy: 'bans' wins; an unknown count reads as 1")
	check.call(DraftFormat.bans_of(true) == 3 and DraftFormat.bans_of(false) == 1 and DraftFormat.bans_of(5) == 5, "legacy: bool and int draft arguments")


func _drafts(check: Callable) -> void:
	var w := World.load_default()
	var meta := w.make_meta("fmt-test")
	for nb in [1, 3, 5]:
		var all_ok := true
		for i in 6:
			var a: String = w.club_ids[i % w.club_ids.size()]
			var b: String = w.club_ids[(i + 3) % w.club_ids.size()]
			var d := MatchRunner.prepare(w, w.best_lineup(a), w.best_lineup(b), meta, 7700 + i, "fmt:%d:%d" % [nb, i], nb)
			d.finish_with_ai()
			var used := {}
			for t in ["B", "R"]:
				all_ok = all_ok and d.bans[t].size() == nb and d.picks[t].size() == 5
				for hid in d.bans[t]:
					used[hid] = true
				for s in SLOTS:
					used[String(d.picks[t][s]["id"])] = true
			all_ok = all_ok and used.size() == 2 * nb + 10 and d.bans_per_side() == nb
		check.call(all_ok, "drafts: %d ban(s) a side: every hero used once, five slots filled a side" % nb)
	var d5 := Draft.make(w, {"B": w.best_lineup(w.club_ids[0]), "R": w.best_lineup(w.club_ids[1])}, meta, 1, "ph", 5)
	var p0 := d5.phase_of(0)
	var p7 := d5.phase_of(7)
	var p13 := d5.phase_of(13)
	var p19 := d5.phase_of(19)
	check.call(p0["kind"] == "ban" and p0["index"] == 1 and p0["first"] == 0 and p0["last"] == 5, "drafts: phase_of step 0 is ban phase 1 (steps 0 to 5)")
	check.call(p7["kind"] == "pick" and p7["index"] == 1 and p7["first"] == 6 and p7["last"] == 11, "drafts: phase_of step 7 is pick phase 1 (6 to 11)")
	check.call(p13["kind"] == "ban" and p13["index"] == 2 and p13["first"] == 12 and p13["last"] == 15, "drafts: phase_of step 13 is ban phase 2 (12 to 15)")
	check.call(p19["kind"] == "pick" and p19["index"] == 2 and p19["last"] == 19, "drafts: phase_of step 19 is pick phase 2")
	var res := MatchRunner.auto_v1(w, w.best_lineup(w.club_ids[0]), w.best_lineup(w.club_ids[1]), meta, 3, "fmt:res", 5)
	check.call(int(res["bans_per_side"]) == 5 and bool(res["full_draft"]), "drafts: a result records bans_per_side (and full_draft for older readers)")


## GDD 6 role floor: after a pick each slot keeps at least as many available primary-role heroes as teams still needing it;
## after a ban, that number plus 1. Random play (any hero, any open lane) must never dead-end; the floor itself is only counted
## (it is not enforced in code; off-role picks are always allowed). The 100,000-draft version is in docs/design/BAN-EXPERIMENT.md.
func _floor(check: Callable) -> void:
	var w := World.load_default()
	var roles := {}
	for hid in w.hero_ids:
		roles[hid] = String(w.heroes[hid]["role_primary"])
	var order := DraftFormat.order_for(5)
	var rng := Pcg32.contest_stream(42, "floor")
	var dead := 0
	var drafts := 2000
	var binds := 0
	for k in drafts:
		var avail: Array = w.hero_ids.duplicate()
		var open := {"B": SLOTS.duplicate(), "R": SLOTS.duplicate()}
		for st in order:
			if avail.is_empty():
				dead += 1
				break
			var hid: String = avail[int(rng.next_u32() % avail.size())]
			avail.erase(hid)
			if st[1] == "pick":
				var o: Array = open[st[0]]
				if o.is_empty():
					dead += 1
					break
				o.remove_at(int(rng.next_u32() % o.size()))
			for s in SLOTS:
				var need := int((open["B"] as Array).has(s)) + int((open["R"] as Array).has(s))
				var have := 0
				for h in avail:
					if roles[h] == s:
						have += 1
				if have < need + (1 if st[1] == "ban" else 0) and need > 0:
					binds += 1
		if (open["B"] as Array).size() + (open["R"] as Array).size() != 0:
			dead += 1
	check.call(dead == 0, "floor: %d random 5-ban drafts never dead-end (every team fills five lanes)" % drafts)
	print("draft_format_tests: role floor would have bound %d times in %d random 5-ban drafts" % [binds, drafts])


func _device(check: Callable) -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var d := DeviceState.new(PATH)
	check.call(d.draft_bans() == "standard" and d.arena_camera() == "action", "device: defaults are standard bans and the Action camera")
	check.call(d.set_draft_bans("classic") and DeviceState.new(PATH).draft_bans() == "classic", "device: classic is stored")
	check.call(not d.set_draft_bans("five") and d.draft_bans() == "classic", "device: an unknown bans mode is refused")
	check.call(d.set_arena_camera("field") and DeviceState.new(PATH).arena_camera() == "field" and d.draft_bans() == "classic", "device: camera stored, bans kept")
	check.call(not d.set_arena_camera("drone") and d.arena_camera() == "field", "device: an unknown camera is refused")
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("arena", "camera", 7)
	cf.set_value("draft", "bans", null)
	cf.save(PATH)
	check.call(d.arena_camera() == "action" and d.draft_bans() == "standard", "device: hand-written bad values read as the defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
