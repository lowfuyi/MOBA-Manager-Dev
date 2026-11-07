extends SceneTree
## Economy QA (Alpha 0.3). Plays N seasons for every club under two policies and reports whether money
## ever ruins a club (passive) or lets one run away (active recruiting).
## Copy to game/tests/_econ_qa.gd and run:  godot --headless --script res://tests/_econ_qa.gd -- 8 [policy] [first_club] [last_club]
## passive: never signs or releases, renews everybody the cap allows. steady sponsor.
## active:  every season swaps its weakest player for a clearly better free agent when it can pay, renews only
##          its best seven, takes the "wins" sponsor. active_steady: the same with the steady sponsor.

var seasons := 8


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		seasons = int(args[0])
	var policies := ["passive", "active", "active_steady"]
	if args.size() > 1:
		policies = [args[1]]
	var first := int(args[2]) if args.size() > 2 else 0
	var last := int(args[3]) if args.size() > 3 else 9
	var w := World.load_default()
	for policy in policies:
		print("=== policy: ", policy)
		var rank_sum: Array = []
		var rating_gap: Array = []
		var cash_end: Array = []
		var min_cash := 1.0e12
		var dismissed := 0
		var cap_block := 0
		var renew_lost := 0
		var champs := {}
		for s in seasons:
			rank_sum.append(0.0)
			rating_gap.append(0.0)
		for ci in range(first, last + 1):
			var club: String = w.club_ids[ci]
			var gs := GameState.new_game(w, club, 9000 + ci)
			var dis_season := 0
			var row := []
			for s in seasons:
				_manage(gs, policy)
				gs.autoplay(true)
				var rk := gs.rank_of(club)
				rank_sum[s] += float(rk)
				var mine := w.team_rating(gs.lineup())
				var avg := 0.0
				for c in w.club_ids:
					avg += w.team_rating(w.best_lineup(c))
				avg /= float(w.club_ids.size())
				rating_gap[s] += mine - avg
				min_cash = minf(min_cash, gs.cash())
				if gs.is_dismissed() and dis_season == 0:
					dis_season = s + 1
				if gs.d["champion"] == club:
					champs[club] = int(champs.get(club, 0)) + 1
				row.append("%d/%.0f" % [rk, gs.cash()])
				var before := gs.expiring().size()
				var lost := _renew(gs, policy)
				renew_lost += lost
				_manage(gs, policy)
				if s < seasons - 1:
					gs = gs.next_season()
			if dis_season > 0:
				dismissed += 1
			cash_end.append(gs.cash())
			print("  %-20s rank/cash by season: %s%s" % [club, " ".join(row), ("  DISMISSED in S%d" % dis_season) if dis_season > 0 else ""])
		var line := []
		for s in seasons:
			line.append("%.1f" % (rank_sum[s] / float(w.club_ids.size())))
		print("avg rank by season (mean is 5.5): ", " ".join(line))
		var gl := []
		for s in seasons:
			gl.append("%+.1f" % (rating_gap[s] / float(w.club_ids.size())))
		print("avg team rating gap to league by season: ", " ".join(gl))
		print("clubs dismissed: %d/10, lowest cash ever: %.0f, expiring players lost to cap/lockout: %d, titles: %s" % [dismissed, min_cash, renew_lost, str(champs)])
	quit()


func _renew(gs: GameState, policy: String) -> int:
	var w := gs.world
	var lost := 0
	var exp: Array = gs.expiring()
	exp.sort_custom(func(a, b): return Economy.best_slot_rating(w, a) > Economy.best_slot_rating(w, b))
	var keep_n := 99 if policy == "passive" else 7
	var idx := 0
	for p in exp:
		idx += 1
		if idx > keep_n and (gs.d["roster"] as Array).size() - (exp.size() - idx + 1) >= 6:
			continue
		var need := int(ceil(Economy.required_wage(w, p, 2))) + 1
		var r := gs.offer(p["id"], need, 2, true)
		if r["code"] != "accepted":
			lost += 1
	return lost


func _manage(gs: GameState, policy: String) -> void:
	var w := gs.world
	if gs.sponsor_changeable():
		gs.set_sponsor("wins" if policy == "active" else "steady")
	if policy.begins_with("active"):
		for _i in 3:
			var roster: Array = gs.roster_players()
			roster.sort_custom(func(a, b): return Economy.best_slot_rating(w, a) < Economy.best_slot_rating(w, b))
			var worst: Dictionary = roster[0]
			var fas: Array = gs.fa_players()
			fas.sort_custom(func(a, b): return Economy.best_slot_rating(w, a) > Economy.best_slot_rating(w, b))
			var pick: Dictionary = {}
			for f in fas:
				if gs.lockout_left(f["id"]) == 0:
					pick = f
					break
			if pick.is_empty() or Economy.best_slot_rating(w, pick) < Economy.best_slot_rating(w, worst) + 3.0:
				break
			if gs.roster_slots_used() >= int(Economy.data()["max_roster"]):
				if gs.release(worst["id"]) != "":
					break
			var need := int(ceil(Economy.required_wage(w, pick, 2))) + 1
			var r := gs.offer(pick["id"], need, 2)
			if r["code"] != "accepted":
				break
		gs.reset_lineup()
