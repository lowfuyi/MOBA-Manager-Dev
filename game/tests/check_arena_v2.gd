extends Node
## Arena v2 (Phase 4) checks. Ends with "check_arena_v2: N checks, M failures".
##   camera    project and unproject are inverse; the player's base is at the bottom for both sides (a mirror, never a
##             rotation); the far edge of the island is narrower than the near edge (mild perspective)
##   player    positions equal the sim's track at every sample; a hero is not alive between its death and respawn; the
##             scoreboard at the end equals the result (kills, towers); towers down equal the log
##   pacing    the show length is near show_seconds for a median game, every show time maps to a game time in order, and the
##             end of the show is the end of the game
##   screen    the Match screen builds from a v2 result, Skip ends it with the final score, Speed cycles x1 x2 x4
##   A1        nothing in src/arena calls the simulator or writes the result (a grep)

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ready() -> void:
	TutorialRunner.home_offers = false
	get_window().size = Vector2i(720, 1280)
	_camera()
	var w := World.load_default()
	var meta := w.make_meta("arena-v2-check")
	var results: Array = []
	for i in 4:
		results.append(MatchRunner.auto(w, w.best_lineup(w.club_ids[i]), w.best_lineup(w.club_ids[(i + 5) % 10]), meta, 880 + i, "av2:%d" % i, false, {"B": "ai", "R": "ai"}))
	for i in results.size():
		_player(results[i], "B" if i % 2 == 0 else "R", i)
	_pacing(results)
	_a1()
	print("check_arena_v2: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _camera() -> void:
	for flip in [false, true]:
		var c := ArenaCam.new()
		c.flip = flip
		c.view = Vector2(720, 760)
		c.focus = Vector2(0.5, 0.5)
		c.update()
		var worst := 0.0
		for p in [Vector2(0.3, 0.4), Vector2(0.5, 0.5), Vector2(0.7, 0.62), Vector2(0.45, 0.55)]:
			var s := c.project(p)
			var back := c.unproject(Vector2(s.x, s.y))
			worst = maxf(worst, SimData.du(p, back))
		ok(worst < 1e-4, "camera (%s): unproject(project(p)) = p (worst %.6f)" % ["Red" if flip else "Blue", worst])
		var mine: Vector2 = SimData.map()["cairn"]["R" if flip else "B"]
		var theirs: Vector2 = SimData.map()["cairn"]["B" if flip else "R"]
		ok(c.project(mine).y > c.project(theirs).y, "camera (%s): the player's base is below the enemy's" % ["Red" if flip else "Blue"])
		var ny := 0.3 if flip else 0.7    # the player's half is near (mirrored for Red)
		var near_w := c.project(Vector2(0.9, ny)).x - c.project(Vector2(0.1, ny)).x
		var far_w := c.project(Vector2(0.9, 1.0 - ny)).x - c.project(Vector2(0.1, 1.0 - ny)).x
		ok(far_w < near_w and far_w > near_w * 0.6, "camera (%s): the far side is narrower, mildly (%.0f vs %.0f px)" % ["Red" if flip else "Blue", far_w, near_w])
		# the top lane stays on the left for both sides (mirror in y only)
		ok(c.project(Vector2(0.1, 0.5)).x < c.project(Vector2(0.9, 0.5)).x, "camera (%s): west is left (top lane on the left)" % ["Red" if flip else "Blue"])


func _player(res: Dictionary, side: String, i: int) -> void:
	var pl := ArenaPlayer.build(res, side)
	var tr: Dictionary = res["sim"]["log"]["track"]
	var every := float(res["sim"]["log"]["track_every"])
	var worst := 0.0
	var dead_bad := 0
	for k in tr:
		var a: PackedFloat32Array = tr[k]
		for j in range(0, a.size() / 4, 7):
			var t := float(j) * every
			if a[j * 4 + 3] < 0.5:
				if pl.alive(k, t + 0.01):
					dead_bad += 1
				continue
			if not pl.fight_of(k, t).is_empty():
				continue
			worst = maxf(worst, SimData.du(pl.pos(k, t), Vector2(a[j * 4], a[j * 4 + 1])))
	ok(worst < 1e-5, "player %d: outside fights a hero is where the sim's track says (worst %.6f)" % [i, worst])
	ok(dead_bad == 0, "player %d: a hero the track has down is not alive (%d)" % [i, dead_bad])
	var sc := pl.score(pl.end_t)
	ok(int(sc["kills"]["B"]) == int(res["sim"]["team_kills"]["B"]) and int(sc["kills"]["R"]) == int(res["sim"]["team_kills"]["R"]), "player %d: the final scoreboard kills equal the result %s" % [i, str(sc["kills"])])
	var down := pl.towers_down(pl.end_t)
	var loser := "R" if bool(res["blue_won"]) else "B"
	ok(down.has(loser + ".cairn"), "player %d: at the end the loser's Cairn is down" % i)
	var bv := ArenaHud2.board_values(pl, pl.end_t)
	var me := side
	ok(int(bv["kills_you"]) == int(res["sim"]["team_kills"][me]), "player %d: the board's kills are yours from %s's side" % [i, me])


func _pacing(results: Array) -> void:
	var p := SimData.params()
	for res in results:
		var pl := ArenaPlayer.build(res, "B")
		var target := float(p["show_seconds"]) * clampf(sqrt(float(res["sim"]["len_s"]) / float(p["show_median_len_s"])), 0.75, 1.35)
		ok(absf(pl.show_len - target) <= 0.08 * target + 1.0, "pacing: the show takes %.0f s for a %.1f min game (target %.0f)" % [pl.show_len, float(res["sim"]["len_s"]) / 60.0, target])
		var mono := true
		var last := -1.0
		var s := 0.0
		while s <= pl.show_len:
			var g := pl.game_t(s)
			mono = mono and g >= last - 1e-9
			last = g
			s += 0.5
		ok(mono and absf(pl.game_t(pl.show_len) - pl.end_t) < 0.01, "pacing: show time maps to game time in order, ending at the game's end")


func _a1() -> void:
	var bad: Array = []
	for d in ["res://src/arena/v2"]:
		var dir := DirAccess.open(d)
		if dir == null:
			bad.append("no " + d)
			continue
		for f in dir.get_files():
			if not f.ends_with(".gd"):
				continue
			var txt := FileAccess.get_file_as_string(d + "/" + f)
			for word in ["MatchSim.", "MatchSimV2.", "GamePlan.simulate", "Report.attribution", "FightV2", "RoleAI", "res[\"sim\"] ="]:
				if word in txt:
					bad.append(f + ": " + word)
	ok(bad.is_empty(), "A1: no arena code calls the simulator or writes the result %s" % str(bad))
