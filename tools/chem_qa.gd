extends SceneTree
## Chemistry / form / morale QA (Alpha 0.4, GDD 9.1 "re-run with bonds in the loop").
## Plays whole league splits with the new model and with the old fixed-TeamMod model and compares how well
## strength predicts results. Copy to game/tests/_chem_qa.gd and run:
##   godot --headless --script res://tests/_chem_qa.gd -- <seeds per club> [first_club] [last_club]
## Output per mode: Spearman(team rating, league points), win rate of the 3 strongest vs the 3 weakest clubs,
## spread of points, plus how far chemistry bonuses and form values range.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 3
	var first := int(args[1]) if args.size() > 1 else 0
	var last := int(args[2]) if args.size() > 2 else 9
	var w := World.load_default()
	for mode in ["static", "dynamic"]:
		w.qa_static = mode == "static"
		var rho_sum := 0.0
		var top_w := 0.0
		var bot_w := 0.0
		var n := 0
		var pts_sd := 0.0
		var chem_min := 1.0
		var chem_max := 0.0
		var form_max := 0.0
		var champ_top3 := 0
		for ci in range(first, last + 1):
			for sd in seeds:
				var gs := GameState.new_game(w, w.club_ids[ci], 31000 + 97 * ci + sd)
				gs.autoplay(false)
				var st := gs.standings()
				var rating := {}
				for c in w.club_ids:
					rating[c] = w.team_rating(w.best_lineup(c))
				var order: Array = w.club_ids.duplicate()
				order.sort_custom(func(a, b): return rating[a] > rating[b])
				var pts := {}
				var wins := {}
				for r in st:
					pts[r["club"]] = float(r["pts"])
					wins[r["club"]] = float(r["w"])
				rho_sum += _spearman(order, pts)
				for i in 3:
					top_w += wins[order[i]] / 18.0
					bot_w += wins[order[9 - i]] / 18.0
				var mean := 0.0
				for c in w.club_ids:
					mean += pts[c]
				mean /= 10.0
				var v := 0.0
				for c in w.club_ids:
					v += (pts[c] - mean) * (pts[c] - mean)
				pts_sd += sqrt(v / 10.0)
				for c in w.club_ids:
					chem_min = minf(chem_min, w.team_mod_of(w.best_lineup(c)))
					chem_max = maxf(chem_max, w.team_mod_of(w.best_lineup(c)))
				for pid in gs.d["form"]:
					form_max = maxf(form_max, absf(float(gs.d["form"][pid])))
				n += 1
		print("%-8s splits %d  Spearman %.3f  win rate top3 %.3f bottom3 %.3f  points sd %.2f  chem bonus %.4f..%.4f  max |form| %.1f" % [mode, n, rho_sum / n, top_w / (3.0 * n), bot_w / (3.0 * n), pts_sd / n, chem_min, chem_max, form_max])
	quit()


func _spearman(order: Array, pts: Dictionary) -> float:
	# rank by rating (order[0] = 1) against rank by points
	var by_pts: Array = order.duplicate()
	by_pts.sort_custom(func(a, b): return pts[a] > pts[b])
	var rp := {}
	var i := 0
	while i < by_pts.size():
		var j := i
		while j + 1 < by_pts.size() and pts[by_pts[j + 1]] == pts[by_pts[i]]:
			j += 1
		var avg := (float(i) + float(j)) / 2.0 + 1.0
		for k in range(i, j + 1):
			rp[by_pts[k]] = avg
		i = j + 1
	var n := float(order.size())
	var d2 := 0.0
	for k in order.size():
		var d: float = float(k + 1) - float(rp[order[k]])
		d2 += d * d
	return 1.0 - 6.0 * d2 / (n * (n * n - 1.0))
