extends SceneTree
## QA 9.2 "no training or fatigue schedule is strictly dominant" (GDD 7.3, 9 targets).
## Plays every club through two league seasons under several manager policies and prints the strength
## each policy delivers. Results do not feed back into training yet (no Form/Morale), so one run per
## club and policy is exact. Copy to game/tests/_train_qa.gd and run:
##   godot --headless --script res://tests/_train_qa.gd -- [seasons]
## Policies (lineup / training):
##   keep+auto     fixed starting lineup, coach picks training (the default a player gets)
##   rotate+auto   best rested lineup every match day, coach picks training
##   keep+rest     fixed lineup, nobody trains
##   keep+hero     fixed lineup, everybody practises his best hero
##   keep+bench    fixed lineup, starters rest, the bench trains (coach's pick)
##   keep+early    fixed lineup, coach's training for the first 9 match days, then everybody rests
## "eff" is the mean over match days of the five starters' mid-game rating with their best hero at neutral
## meta, fatigue included (so growth, familiarity and fatigue all count); "base" is the plain Team Rating.

const POLICIES := ["keep+auto", "rotate+auto", "keep+rest", "keep+hero", "keep+bench", "keep+early"]


func _initialize() -> void:
	var seasons := 2
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		seasons = int(args[0])
	var w := World.load_default()
	# result[policy][season] = list of [mean effective rating, end base rating, wins]
	var res := {}
	for pol in POLICIES:
		res[pol] = []
		for s in seasons:
			res[pol].append([])
	for club in w.club_ids:
		print("club ", club)
		for pol in POLICIES:
			var w2 := World.load_default()
			var gs := GameState.new_game(w2, club, 2026)
			for season in seasons:
				_apply_training(gs, pol)
				var eff := 0.0
				var n := 0
				var guard := 0
				while gs.d["phase"] == "league" and guard < 100:
					guard += 1
					if pol.begins_with("rotate"):
						gs.reset_lineup()
					var lu := gs.lineup()
					var sum := 0.0
					for sl in World.SLOTS:
						sum += _best_hero_rating(w2, lu[sl], sl)
					eff += sum / 5.0
					if pol == "keep+early" and n == 9:
						for pp in w2.club_players(club):
							gs.set_focus(pp["id"], "rest")
					n += 1
					var g := gs.next_game()
					gs.record_human_game(g, gs.auto_game(g))
				var base := w2.team_rating(gs.lineup())
				var wins := 0
				for r in gs.standings():
					if r["club"] == club:
						wins = int(r["w"])
				res[pol][season].append([eff / maxf(1.0, float(n)), base, wins])
				if season < seasons - 1:
					gs.autoplay(true)
					gs = gs.next_season()
	for season in seasons:
		print("--- season %d: mean over 10 clubs ---" % (season + 1))
		print("%-13s %10s %10s %8s" % ["policy", "eff.rating", "end.base", "wins"])
		for pol in POLICIES:
			var a := 0.0
			var b := 0.0
			var c := 0.0
			for row in res[pol][season]:
				a += row[0]
				b += row[1]
				c += row[2]
			var k := float(res[pol][season].size())
			print("%-13s %10.2f %10.2f %8.2f" % [pol, a / k, b / k, c / k])
	# is any schedule better for every club? (strictly dominant)
	for season in seasons:
		for pair in [["keep+auto", "rotate+auto"], ["keep+auto", "keep+rest"], ["keep+auto", "keep+hero"], ["keep+auto", "keep+bench"], ["keep+auto", "keep+early"], ["keep+bench", "keep+rest"]]:
			var x_better := 0
			var y_better := 0
			for i in w.club_ids.size():
				var dx: float = res[pair[0]][season][i][0] - res[pair[1]][season][i][0]
				if dx > 0.005:
					x_better += 1
				elif dx < -0.005:
					y_better += 1
			print("season %d, effective rating: %s better for %d clubs, %s better for %d clubs" % [season + 1, pair[0], x_better, pair[1], y_better])
	quit()


func _best_hero_rating(w: World, p: Dictionary, slot: String) -> float:
	var best := 0.0
	for hid in w.hero_ids:
		var h: Dictionary = w.heroes[hid]
		if h["role_primary"] != slot and h.get("role_secondary", "") != slot:
			continue
		best = maxf(best, w.phase_rating(p, slot, h, "mid", w.familiarity(p, hid), 1.0, -1.0, w.fatigue_of(p["id"])))
	return best


func _apply_training(gs: GameState, pol: String) -> void:
	var w := gs.world
	for p in w.club_players(gs.club()):
		var kind := pol.split("+")[1]
		if kind == "early" and gs.d["round"] == 0:
			kind = "auto"
		match kind:
			"rest":
				gs.set_focus(p["id"], "rest")
			"hero":
				var best := ""
				var bf := -1.0
				for hid in w.hero_ids:
					var h: Dictionary = w.heroes[hid]
					if h["role_primary"] != p["role_primary"] and h.get("role_secondary", "") != p["role_primary"]:
						continue
					if w.familiarity(p, hid) > bf:
						bf = w.familiarity(p, hid)
						best = hid
				gs.set_focus(p["id"], "hero", best)
			"bench":
				if (gs.d["lineup"] as Dictionary).values().has(p["id"]):
					gs.set_focus(p["id"], "rest")
				else:
					(gs.d["train"] as Dictionary).erase(p["id"])
			_:
				(gs.d["train"] as Dictionary).erase(p["id"])
