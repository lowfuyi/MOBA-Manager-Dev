class_name GameState
extends RefCounted
## One save: the managed club, the split calendar, standings, playoffs and familiarity growth.
## Everything in `d` is JSON-safe so the whole save is one file (user://save.json).
## Alpha 0.1 scope: league (double round robin, one game per fixture) + playoffs (top 4,
## best of 3 semis, best of 5 final). No training, recruitment, finance, Bonds or Game Plan yet.

const SAVE_PATH := "user://save.json"
const VERSION := 1
const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const ROUNDS_PER_PATCH := 4
const HISTORY_MAX := 40

var world: World
var d: Dictionary = {}


# ---------------------------------------------------------------- creation
static func new_game(w: World, club_id: String, save_seed: int, season: int = 1, carry: Dictionary = {}) -> GameState:
	var gs := GameState.new()
	gs.world = w
	gs.d = {
		"version": VERSION, "save_seed": save_seed, "club": club_id, "season": season,
		"phase": "league", "round": 0,
		"fixtures": _schedule(w.club_ids, "S%d" % season),
		"lineup": {}, "fam_bonus": carry.get("fam_bonus", {}), "history": carry.get("history", []),
		"playoffs": {}, "champion": "", "settings": carry.get("settings", {"quick": false}),
		"seasons_done": carry.get("seasons_done", []),
	}
	w.fam_bonus = gs.d["fam_bonus"]
	gs.reset_lineup()
	return gs


static func from_dict(w: World, data: Dictionary) -> GameState:
	var gs := GameState.new()
	gs.world = w
	gs.d = data
	w.fam_bonus = gs.d["fam_bonus"]
	return gs


static func _schedule(club_ids: Array, season_tag: String) -> Array:
	# circle method: 9 rounds, then the same rounds again with sides swapped
	var n := club_ids.size()
	var ring: Array = club_ids.duplicate()
	var rounds: Array = []
	for r in n - 1:
		var pairs: Array = []
		for i in n / 2:
			var a: String = ring[i]
			var b: String = ring[n - 1 - i]
			pairs.append([a, b] if (r + i) % 2 == 0 else [b, a])
		rounds.append(pairs)
		var last: String = ring.pop_back()
		ring.insert(1, last)
	var fixtures: Array = []
	for leg in 2:
		for r in rounds.size():
			var rr: int = leg * rounds.size() + r
			for pair in rounds[r]:
				var blue: String = pair[0] if leg == 0 else pair[1]
				var red: String = pair[1] if leg == 0 else pair[0]
				fixtures.append({"id": "%s:L:%d:%s-%s" % [season_tag, rr, blue, red], "round": rr, "blue": blue, "red": red,
						"played": false, "winner": "", "final": 0.0})
	return fixtures


# ---------------------------------------------------------------- basics
func club() -> String:
	return d["club"]


func club_name(id: String) -> String:
	return world.clubs[id]["name"]


func season_tag() -> String:
	return "S%d" % int(d["season"])


func total_rounds() -> int:
	return (world.club_ids.size() - 1) * 2


func meta_for(round_index: int) -> Dictionary:
	if d["phase"] != "league":
		return world.make_meta("%s-PO" % season_tag())
	return world.make_meta("%s-P%d" % [season_tag(), round_index / ROUNDS_PER_PATCH])


func patch_label() -> String:
	if d["phase"] != "league":
		return "PO"
	return "P%d" % (int(d["round"]) / ROUNDS_PER_PATCH + 1)


func is_quick() -> bool:
	return bool(d["settings"].get("quick", false))


func set_quick(v: bool) -> void:
	d["settings"]["quick"] = v


# ---------------------------------------------------------------- lineup
func reset_lineup() -> void:
	var lu := world.best_lineup(club())
	var m := {}
	for s in SLOTS:
		m[s] = lu[s]["id"]
	d["lineup"] = m


func lineup() -> Dictionary:
	var out := {}
	for s in SLOTS:
		out[s] = world.players[d["lineup"][s]]
	return out


## Put a player in a slot; if he already starts elsewhere the two swap. Returns false for foreign players.
func assign(slot: String, player_id: String) -> bool:
	if not (world.clubs[club()]["player_ids"] as Array).has(player_id):
		return false
	var prev: String = d["lineup"][slot]
	for s in SLOTS:
		if d["lineup"][s] == player_id:
			d["lineup"][s] = prev
	d["lineup"][slot] = player_id
	return true


func lineup_for(club_id: String) -> Dictionary:
	return lineup() if club_id == club() else world.best_lineup(club_id)


# ---------------------------------------------------------------- standings
func _fixtures_played() -> Array:
	var out: Array = []
	for f in d["fixtures"]:
		if f["played"]:
			out.append(f)
	return out


## Rows sorted by rank: club, played, wins, losses, points, margin, rank.
func standings() -> Array:
	var rows := {}
	for c in world.club_ids:
		rows[c] = {"club": c, "p": 0, "w": 0, "l": 0, "pts": 0, "margin": 0.0}
	var played := _fixtures_played()
	for f in played:
		var blue: String = f["blue"]
		var red: String = f["red"]
		var win: String = f["winner"]
		for c in [blue, red]:
			rows[c]["p"] += 1
			rows[c]["margin"] += float(f["final"]) if c == blue else -float(f["final"])
		rows[win]["w"] += 1
		rows[win]["pts"] += 3
		rows[red if win == blue else blue]["l"] += 1
	var draw := {}
	var stream := Pcg32.contest_stream(Pcg32.match_seed(int(d["save_seed"]), "sched:%s:tiebreak" % season_tag()), "tiebreak")
	for c in world.club_ids:
		draw[c] = stream.next_float()
	var list: Array = rows.values()
	# head-to-head wins among clubs level on points
	var h2h := {}
	for c in world.club_ids:
		h2h[c] = 0
	for f in played:
		if rows[f["blue"]]["pts"] == rows[f["red"]]["pts"]:
			h2h[f["winner"]] += 1
	list.sort_custom(func(a, b):
		if a["pts"] != b["pts"]:
			return a["pts"] > b["pts"]
		if h2h[a["club"]] != h2h[b["club"]]:
			return h2h[a["club"]] > h2h[b["club"]]
		if not is_equal_approx(a["margin"], b["margin"]):
			return a["margin"] > b["margin"]
		return draw[a["club"]] > draw[b["club"]])
	for i in list.size():
		list[i]["rank"] = i + 1
	return list


func rank_of(club_id: String) -> int:
	for r in standings():
		if r["club"] == club_id:
			return int(r["rank"])
	return 0


# ---------------------------------------------------------------- playing games
func _sim_fixture(f: Dictionary) -> void:
	var meta := meta_for(int(f["round"]))
	var r := MatchRunner.auto(world, lineup_for(f["blue"]), lineup_for(f["red"]), meta, int(d["save_seed"]), f["id"], false)
	f["played"] = true
	f["final"] = float(r["final"])
	f["winner"] = f["blue"] if r["blue_won"] else f["red"]


func _round_fixtures(round_index: int) -> Array:
	var out: Array = []
	for f in d["fixtures"]:
		if int(f["round"]) == round_index:
			out.append(f)
	return out


## The managed club's next game, or {} when there is none right now.
## {"kind": "league"|"playoff", "id", "blue", "red", "full": bool, "round", "series", "game"}
func next_game() -> Dictionary:
	match d["phase"]:
		"league":
			for f in _round_fixtures(int(d["round"])):
				if not f["played"] and (f["blue"] == club() or f["red"] == club()):
					return {"kind": "league", "id": f["id"], "blue": f["blue"], "red": f["red"], "full": false,
							"round": int(d["round"]), "series": "", "game": 1}
			return {}
		"playoffs":
			for s in d["playoffs"]["series"]:
				if not s["done"] and (s["a"] == club() or s["b"] == club()):
					return _series_game(s)
			return {}
	return {}


func _series_game(s: Dictionary) -> Dictionary:
	var g: int = (s["games"] as Array).size() + 1
	var higher_blue: bool = g % 2 == 1
	var blue: String = s["a"] if higher_blue else s["b"]
	var red: String = s["b"] if higher_blue else s["a"]
	return {"kind": "playoff", "id": "%s:%s:g%d" % [season_tag(), s["id"], g], "blue": blue, "red": red, "full": g == 1,
			"round": int(d["round"]), "series": s["id"], "game": g}


## Called after the managed club finished a game (result from MatchRunner.finish).
func record_human_game(game: Dictionary, result: Dictionary) -> void:
	var winner: String = game["blue"] if result["blue_won"] else game["red"]
	_remember(game, result, winner)
	_grow_familiarity(game, result)
	if game["kind"] == "league":
		for f in d["fixtures"]:
			if f["id"] == game["id"]:
				f["played"] = true
				f["final"] = float(result["final"])
				f["winner"] = winner
		_finish_round_if_done()
	else:
		for s in d["playoffs"]["series"]:
			if s["id"] == game["series"]:
				_add_series_game(s, game, winner, float(result["final"]))
		advance_playoffs()


func _remember(game: Dictionary, result: Dictionary, winner: String) -> void:
	var slim := {"id": game["id"], "kind": game["kind"], "blue": game["blue"], "red": game["red"], "winner": winner,
			"won": winner == club(), "final": float(result["final"]), "round": game["round"], "series": game["series"],
			"game": game["game"], "picks": result["picks"], "bans": result["bans"], "comp": result["comp"],
			"style": result["style"], "lineups": result["lineups"], "contests": result["sim"]["contests"],
			"phases": {"early": result["sim"]["early"], "mid": result["sim"]["mid"], "late": result["sim"]["late"]},
			"mseed": str(result["mseed"])}
	(d["history"] as Array).append(slim)
	while (d["history"] as Array).size() > HISTORY_MAX:
		(d["history"] as Array).pop_front()


func _grow_familiarity(game: Dictionary, result: Dictionary) -> void:
	var side := "B" if game["blue"] == club() else "R"
	for s in SLOTS:
		var pid: String = result["lineups"][side][s]
		var key: String = pid + "|" + result["picks"][side][s]
		d["fam_bonus"][key] = float(d["fam_bonus"].get(key, 0.0)) + 3.0
	world.fam_bonus = d["fam_bonus"]


func _finish_round_if_done() -> void:
	var r := int(d["round"])
	for f in _round_fixtures(r):
		if not f["played"]:
			if f["blue"] != club() and f["red"] != club():
				_sim_fixture(f)
	var all_done := true
	for f in _round_fixtures(r):
		all_done = all_done and f["played"]
	if all_done:
		d["round"] = r + 1
		if int(d["round"]) >= total_rounds():
			_start_playoffs()


## Let the AI draft and play every remaining game of the managed club until `until_phase` ends
## ("league" stops when the playoffs open, "all" plays to the end of the split).
func autoplay(until_all: bool = false) -> void:
	var guard := 0
	while guard < 400 and (d["phase"] == "league" or (until_all and d["phase"] == "playoffs")):
		guard += 1
		var g := next_game()
		if g.is_empty():
			if d["phase"] == "playoffs":
				advance_playoffs()
				if next_game().is_empty() and d["phase"] == "playoffs":
					break
			else:
				_finish_round_if_done()
			continue
		record_human_game(g, auto_game(g))


func auto_game(g: Dictionary) -> Dictionary:
	var meta := meta_for(int(g["round"]))
	return MatchRunner.auto(world, lineup_for(g["blue"]), lineup_for(g["red"]), meta, int(d["save_seed"]), g["id"], bool(g["full"]))


# ---------------------------------------------------------------- playoffs
func _start_playoffs() -> void:
	d["phase"] = "playoffs"
	var st := standings()
	var seeds: Array = []
	for i in 4:
		seeds.append(st[i]["club"])
	d["playoffs"] = {"stage": "semis", "seeds": seeds, "series": [
		_new_series("SF1", seeds[0], seeds[3], 3),
		_new_series("SF2", seeds[1], seeds[2], 3)]}
	advance_playoffs()


func _new_series(id: String, a: String, b: String, best_of: int) -> Dictionary:
	return {"id": id, "a": a, "b": b, "best_of": best_of, "wins_a": 0, "wins_b": 0, "games": [], "done": false, "winner": ""}


func _add_series_game(s: Dictionary, game: Dictionary, winner: String, final: float) -> void:
	(s["games"] as Array).append({"id": game["id"], "blue": game["blue"], "red": game["red"], "winner": winner, "final": final})
	if winner == s["a"]:
		s["wins_a"] += 1
	else:
		s["wins_b"] += 1
	var need: int = int(s["best_of"]) / 2 + 1
	if s["wins_a"] >= need or s["wins_b"] >= need:
		s["done"] = true
		s["winner"] = s["a"] if s["wins_a"] >= need else s["b"]


## Simulate every series the managed club is not part of (and everything once it is out),
## then open the next stage. Stops when the managed club has a game to play.
func advance_playoffs() -> void:
	if d["phase"] != "playoffs":
		return
	var po: Dictionary = d["playoffs"]
	var guard := 0
	while guard < 60:
		guard += 1
		var progressed := false
		for s in po["series"]:
			if s["done"] or s["a"] == club() or s["b"] == club():
				continue
			var g := _series_game(s)
			var r := MatchRunner.auto(world, lineup_for(g["blue"]), lineup_for(g["red"]), meta_for(0), int(d["save_seed"]), g["id"], bool(g["full"]))
			_add_series_game(s, g, g["blue"] if r["blue_won"] else g["red"], float(r["final"]))
			progressed = true
		var all_done := true
		for s in po["series"]:
			all_done = all_done and s["done"]
		if all_done:
			if po["stage"] == "semis":
				var w1: String = po["series"][0]["winner"]
				var w2: String = po["series"][1]["winner"]
				var a: String = w1 if po["seeds"].find(w1) < po["seeds"].find(w2) else w2
				var b: String = w2 if a == w1 else w1
				(po["series"] as Array).append(_new_series("F", a, b, 5))
				po["stage"] = "final"
				continue
			po["stage"] = "done"
			d["phase"] = "done"
			d["champion"] = po["series"][2]["winner"]
			_archive_season()
			return
		if not progressed:
			return


func _archive_season() -> void:
	var st := standings()
	var mine := {}
	for r in st:
		if r["club"] == club():
			mine = r
	var series_result := "missed"
	for s in d["playoffs"]["series"]:
		if s["a"] == club() or s["b"] == club():
			series_result = "won" if s["winner"] == club() else "lost"
			if s["id"] == "F":
				series_result = "champion" if s["winner"] == club() else "runner_up"
			elif s["winner"] == club() and s["id"] != "F":
				series_result = "finalist"
	(d["seasons_done"] as Array).append({"season": d["season"], "rank": mine.get("rank", 0), "w": mine.get("w", 0), "l": mine.get("l", 0),
			"result": series_result, "champion": d["champion"]})


func playoff_label(s: Dictionary) -> String:
	return "playoff.stage." + ("final" if s["id"] == "F" else "semi")


func next_season() -> GameState:
	var carry := {"fam_bonus": d["fam_bonus"], "history": d["history"], "settings": d["settings"], "seasons_done": d["seasons_done"]}
	var gs := GameState.new_game(world, club(), int(d["save_seed"]) + 1000 * int(d["season"]), int(d["season"]) + 1, carry)
	gs.d["lineup"] = d["lineup"]
	return gs


# ---------------------------------------------------------------- persistence
func save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	return true


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func load_save(w: World) -> GameState:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary) or int(data.get("version", 0)) != VERSION:
		return null
	return from_dict(w, data)


static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
