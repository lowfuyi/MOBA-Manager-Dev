extends RefCounted
## The ai_games_v2 switch (0.12, overnight Q7): prepared, NOT enabled. AI-vs-AI games (league fixtures without the player,
## playoff series without the player) use the v1 model while it is false; turned on, they use Match Sim v2 and the season
## code gets the same result shape. Cost measured in docs/design/AI-GAMES-V2-COST.md.


func run(check: Callable) -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sim_v2_params.json"))
	check.call(raw.has("ai_games_v2") and raw["ai_games_v2"] == false, "ai switch: ai_games_v2 is in the data and off")
	var w := World.load_default()
	var gs := GameState.new_game(w, w.club_ids[0], 5150)
	gs._bind()
	var was := bool(SimData.params().get("ai_games_v2", false))
	var shapes := {}
	for mode in [false, true]:
		SimData.params()["ai_games_v2"] = mode
		var ok := true
		for i in 2:
			var a: String = w.club_ids[1 + i]
			var b: String = w.club_ids[5 + i]
			var r := MatchRunner.auto_ai(w, gs.lineup_for(a), gs.lineup_for(b), gs.meta_for(0), 5150, "sw-%s-%d" % [str(mode), i], DraftFormat.bans_for("league"), {"B": "ai", "R": "ai"})
			# final is the signed margin for Blue (its sign is the winner) in both models
			ok = ok and r.has("final") and r.has("blue_won") and (float(r["final"]) > 0.0) == bool(r["blue_won"])
			ok = ok and (r.has("v") == mode)    # only Match Sim v2 results carry "v"
			if mode:
				ok = ok and (r["sim"] as Dictionary).has("log")
		shapes[mode] = ok
	SimData.params()["ai_games_v2"] = was
	check.call(shapes[false], "ai switch: off, AI games give final and blue_won (v1 model)")
	check.call(shapes[true], "ai switch: on, AI games run Match Sim v2 and give the same final and blue_won the season code reads")
	check.call(not bool(SimData.params().get("ai_games_v2", false)), "ai switch: the test leaves it off")
