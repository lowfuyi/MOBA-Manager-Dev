class_name GameState
extends RefCounted
## One save: the managed club, the split calendar, standings, playoffs and familiarity growth.
## Everything in `d` is JSON-safe so the whole save is one file (user://save.json).
## Alpha 0.3 scope: league (double round robin, one game per fixture) + playoffs (top 4,
## best of 3 semis, best of 5 final), Game Plan, training, fatigue and ageing, and now contracts,
## the free-agent market, a cash balance with a sponsor, and dismissal when the club stays in debt.
## Alpha 0.4 adds Team Bonds (pairs on the managed roster, one level per AI squad), Player Form and Morale.

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
		"seasons_done": carry.get("seasons_done", []), "plan": carry.get("plan", GamePlan.neutral_set()),
		"stat_gain": carry.get("stat_gain", {}), "fatigue": carry.get("fatigue", {}), "train": carry.get("train", {}),
		"train_last": [], "season_base": (carry.get("stat_gain", {}) as Dictionary).duplicate(true),
		"roster": (carry["roster"] as Array) if carry.has("roster") else w.orig_ids(club_id).duplicate(),
		"fa": (carry["fa"] as Array) if carry.has("fa") else w.orig_free_agents(),
		"form": carry.get("form", {}), "morale": carry.get("morale", {}), "bonds": carry.get("bonds", {}),
		"ai_bond": carry.get("ai_bond", {}), "miss": carry.get("miss", {}), "was_start": carry.get("was_start", {}),
	}
	w.fam_bonus = gs.d["fam_bonus"]
	gs._init_bonds(not carry.has("bonds"))
	gs._bind()
	gs._init_economy(carry)
	gs.reset_lineup()
	gs.d["frating"] = (carry["frating"] as Dictionary).duplicate() if carry.has("frating") else gs._initial_frating()
	for k in ["pace", "career", "exh_n"]:
		if carry.has(k):
			gs.d[k] = carry[k]
	return gs


static func from_dict(w: World, data: Dictionary) -> GameState:
	var gs := GameState.new()
	gs.world = w
	gs.d = data
	for k in ["stat_gain", "fatigue", "train", "season_base"]:  # saves from before Alpha 0.2
		if not gs.d.has(k):
			gs.d[k] = {}
	if not gs.d.has("train_last"):
		gs.d["train_last"] = []
	if not gs.d.has("roster"):  # saves from before Alpha 0.3: the club as the data files have it
		gs.d["roster"] = w.orig_ids(gs.d["club"]).duplicate()
		gs.d["fa"] = w.orig_free_agents()
	w.fam_bonus = gs.d["fam_bonus"]
	if not gs.d.has("bonds"):  # saves from before Alpha 0.4: the club starts as a new club with every pair at 30
		for k in ["form", "morale", "bonds", "ai_bond", "miss", "was_start"]:
			gs.d[k] = {}
		gs._init_bonds(true)
	gs._bind()
	if not gs.d.has("cash"):
		gs._init_economy({})
	if not gs.d.has("frating"):  # saves from before Alpha 0.6: ratings start from today's team ratings
		gs.d["frating"] = gs._initial_frating()
	return gs


## Make the shared World show this save's player growth, fatigue and ages.
func _bind() -> void:
	world.bind_roster(club(), d["roster"], d["fa"])
	world.bind_progress(d["stat_gain"], d["fatigue"], int(d["season"]) - 1)
	world.bind_condition(d["form"], d["morale"], d["bonds"], d["ai_bond"])


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
	world.refresh_lineup(club())
	var lu := world.rotated_lineup(club())
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
	return lineup() if club_id == club() else world.rotated_lineup(club_id)


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
	var r := MatchRunner.auto(world, lineup_for(f["blue"]), lineup_for(f["red"]), meta, int(d["save_seed"]), f["id"], false, {"B": "ai", "R": "ai"})
	f["played"] = true
	f["final"] = float(r["final"])
	f["winner"] = f["blue"] if r["blue_won"] else f["red"]
	_rate(f["blue"], f["red"], bool(r["blue_won"]), "league", 1)


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
	if game["kind"] == "exhibition":
		record_exhibition_game(game, result)
		return
	var winner: String = game["blue"] if result["blue_won"] else game["red"]
	_remember(game, result, winner)
	_grow_familiarity(game, result)
	var my_side := "B" if game["blue"] == club() else "R"
	Career.record_game(d, result, my_side, winner == club(), game["red"] if my_side == "B" else game["blue"])
	if game["kind"] == "league":
		for f in d["fixtures"]:
			if f["id"] == game["id"]:
				f["played"] = true
				f["final"] = float(result["final"])
				f["winner"] = winner
		_rate(game["blue"], game["red"], bool(result["blue_won"]), "league", 1)
		_finish_round_if_done()
	else:
		var side := "B" if game["blue"] == club() else "R"
		_after_game(club(), (result["lineups"][side] as Dictionary).values(), winner == club(), true, false)
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


## One match day passes for every club: fatigue moves and each player trains.
## The log of the managed club's training is kept for the screen that reports it.
func _tick_day() -> void:
	var mine: Array = []
	var won := {}
	for f in _round_fixtures(int(d["round"])):
		won[f["winner"]] = true
	for c in world.club_ids:
		var ids: Array = []
		if c == club():
			ids = (d["lineup"] as Dictionary).values()
		else:
			var lu := world.rotated_lineup(c)
			for s in SLOTS:
				ids.append(lu[s]["id"])
		var log := Progression.tick_club(world, d, c, ids, c == club())
		if c == club():
			mine = log
		_after_game(c, ids, won.has(c), false, true)
		if c == club():
			_scrim_bonds()
	d["train_last"] = mine
	d["exh_busy"] = []
	Progression.tick_players(world, d, world.free_agent_players(), [], false)
	world.fam_bonus = d["fam_bonus"]
	d["clock"] = int(d["clock"]) + 1
	_pay_round()


## Playoff games: only the managed club's roster ticks (the AI series are simulated without a calendar).
func _tick_human_playoff_day() -> void:
	d["train_last"] = Progression.tick_club(world, d, club(), (d["lineup"] as Dictionary).values(), true)
	d["clock"] = int(d["clock"]) + 1


# ---------------------------------------------------------------- Exhibition and Quick Match (GDD 7.9)
const EXH_FATIGUE := 5.0     # per game, instead of the +15 of a league match day
const EXH_BOND := 2.0        # per pair of starters, per game
const QUICK_RANGE := 5.0     # Quick Match opponent: Team Rating within this many points


## One practice series per match day, in the league phase only (the playoffs have no calendar days).
func practice_available() -> bool:
	return d["phase"] == "league" and not bool(d.get("dismissed", false)) and int(d.get("exh_day", -1)) != int(d["clock"]) and not practice_in_progress()


func practice_in_progress() -> bool:
	return d.has("exh") and not (d["exh"] as Dictionary).is_empty()


## Opponents for Exhibition: every other club in the league, with team rating, best first.
func practice_opponents() -> Array:
	var rows: Array = []
	for c in world.club_ids:
		if c != club():
			rows.append({"club": c, "rating": world.team_rating(lineup_for(c))})
	rows.sort_custom(func(x, y): return x["rating"] > y["rating"])
	return rows


## Quick Match opponent: drawn from the clubs within QUICK_RANGE of our Team Rating (the nearest one when none is).
func quick_match_opponent() -> String:
	var mine := world.team_rating(lineup_for(club()))
	var near: Array = []
	var best := ""
	var best_gap := 1e9
	for r in practice_opponents():
		var gap := absf(float(r["rating"]) - mine)
		if gap <= QUICK_RANGE:
			near.append(r["club"])
		if gap < best_gap:
			best_gap = gap
			best = r["club"]
	if near.is_empty():
		return best
	var rng := Pcg32.contest_stream(int(d["save_seed"]), "exh-pick:%d" % int(d.get("exh_n", 0)))
	return near[int(rng.next_float() * near.size()) % near.size()]


## Open a practice series against `opp` (best of 1, 3 or 5). Returns "" or a reason key.
func start_practice(opp: String, best_of: int) -> String:
	if not practice_available():
		return "practice.unavailable"
	if opp == club() or not world.clubs.has(opp):
		return "practice.bad_opponent"
	d["exh"] = {"opp": opp, "best_of": best_of if best_of in [3, 5] else 1, "me": 0, "them": 0, "games": 0}
	return ""


## Leave a series half-way. The games already played keep their small effects; the day is not used up.
func end_practice() -> void:
	d["exh"] = {}


## The next game of the series in progress, in the same shape as next_game(): {} when there is none.
func practice_game() -> Dictionary:
	if not practice_in_progress():
		return {}
	var x: Dictionary = d["exh"]
	var g: int = int(x["games"]) + 1
	var me_blue: bool = g % 2 == 1
	return {"kind": "exhibition", "id": "exh:%d:%d" % [int(d["save_seed"]), int(d.get("exh_n", 0)) + 1],
			"blue": club() if me_blue else x["opp"], "red": x["opp"] if me_blue else club(), "full": false,
			"round": int(d["round"]), "series": "X", "game": g, "best_of": int(x["best_of"])}


## A finished practice game. Never touches the table, Form Rating, Form, Morale, sponsor, history or career.
func record_exhibition_game(game: Dictionary, result: Dictionary) -> void:
	var my_side := "B" if game["blue"] == club() else "R"
	var starters: Array = (result["lineups"][my_side] as Dictionary).values()
	for pid in starters:
		world.fatigue[pid] = clampf(world.fatigue_of(pid) + EXH_FATIGUE, 0.0, 100.0)
	for i in starters.size():
		for j in range(i + 1, starters.size()):
			_raise_bond(starters[i], starters[j], EXH_BOND)
	d["exh_n"] = int(d.get("exh_n", 0)) + 1
	if not practice_in_progress():
		return
	var x: Dictionary = d["exh"]
	x["games"] = int(x["games"]) + 1
	var won: bool = result["blue_won"] == (my_side == "B")
	if won:
		x["me"] = int(x["me"]) + 1
	else:
		x["them"] = int(x["them"]) + 1
	var need: int = int(x["best_of"]) / 2 + 1
	if int(x["me"]) >= need or int(x["them"]) >= need:
		d["exh_last"] = {"opp": x["opp"], "best_of": int(x["best_of"]), "me": int(x["me"]), "them": int(x["them"]), "won": int(x["me"]) >= need}
		d["exh_day"] = int(d["clock"])
		d["exh_busy"] = starters.duplicate()   # they spent the day playing: no training and no rest today
		d["exh"] = {}


## True while a series is waiting for its next game.
func practice_series() -> Dictionary:
	return d["exh"] if practice_in_progress() else {}


# ---------------------------------------------------------------- Form Rating (GDD 10.1)
func _initial_frating() -> Dictionary:
	var tr := {}
	for c in world.club_ids:
		tr[c] = world.team_rating(lineup_for(c))
	return FormRating.initial(tr)


## One rated result (a league game, or a finished playoff series). Zero-sum between the two clubs.
func _rate(a: String, b: String, a_won: bool, stage: String, best_of: int) -> void:
	var fr: Dictionary = d["frating"]
	var delta := FormRating.delta(float(fr[a]), float(fr[b]), a_won, stage, best_of)
	fr[a] = float(fr[a]) + delta
	fr[b] = float(fr[b]) - delta


func career_all() -> Dictionary:
	return Career.all(d)


func form_rating(club_id: String) -> float:
	return float(d["frating"][club_id])


## Clubs sorted by Form Rating, best first: [{"club", "rating", "rank"}].
func form_ranking() -> Array:
	var rows: Array = []
	for c in world.club_ids:
		rows.append({"club": c, "rating": form_rating(c)})
	rows.sort_custom(func(x, y): return x["rating"] > y["rating"])
	for i in rows.size():
		rows[i]["rank"] = i + 1
	return rows


# ---------------------------------------------------------------- bonds, form and morale
## Pairs of a roster all start at 30 for a new club; whoever joins later starts at 20 with everybody.
func _init_bonds(new_club: bool) -> void:
	var b: Dictionary = d["bonds"]
	var roster: Array = d["roster"]
	if new_club:
		var start := float(Bonds.data()["bond"]["start_club"])
		for i in roster.size():
			for j in range(i + 1, roster.size()):
				b[Bonds.pair_key(roster[i], roster[j])] = start
	var ab: Dictionary = d["ai_bond"]
	for c in world.club_ids:
		if not ab.has(c):
			ab[c] = float(Bonds.data()["bond"]["start_club"])
	_sync_bonds()


## Every pair on the roster has a bond (a new signing starts at 20), and pairs with anyone who left are gone.
func _sync_bonds() -> void:
	var roster: Array = d["roster"]
	var b: Dictionary = d["bonds"]
	var fresh := float(Bonds.data()["bond"]["start_new_signing"])
	for i in roster.size():
		for j in range(i + 1, roster.size()):
			var k := Bonds.pair_key(roster[i], roster[j])
			if not b.has(k):
				b[k] = fresh
	for k in b.keys():
		var ids := String(k).split("|")
		if not roster.has(ids[0]) or not roster.has(ids[1]):
			b.erase(k)


## One game played by `club_id` with these five starters. `day` also lets the calendar day pass (league),
## which pulls Form back toward 0 and Morale toward 60. Playoff games have no calendar here.
func _after_game(club_id: String, starters: Array, won: bool, playoff: bool, day: bool) -> void:
	var days := Bonds.days_per_tick()
	for pid in world.clubs[club_id]["player_ids"]:
		var p: Dictionary = world.players[pid]
		var started := starters.has(pid)
		var frm := world.form_of(pid)
		var mor := world.morale_of(pid)
		if started:
			frm = Bonds.form_after_match(frm, won)
			d["miss"][pid] = 0
			d["was_start"][pid] = true
		else:
			d["miss"][pid] = int(d["miss"].get(pid, 0)) + 1
		mor = Bonds.morale_after_match(mor, p["personality"], started, won, playoff)
		if not started:
			mor = Bonds.clamp_morale(mor - Bonds.miss_loss(int(d["miss"][pid]), bool(d["was_start"].get(pid, false))))
			if int(d["miss"][pid]) > int(Bonds.data()["morale"]["miss_forget"]):
				d["was_start"][pid] = false
		if day:
			frm = Bonds.form_after_days(frm, days)
			mor = Bonds.morale_after_days(mor, days)
		d["form"][pid] = frm
		d["morale"][pid] = mor
	_play_together(club_id, starters)


## Bond +4 for each pair of starters who played together (the managed club keeps every pair, an AI squad one level).
func _play_together(club_id: String, starters: Array) -> void:
	var base := float(Bonds.data()["bond"]["game_gain"])
	if club_id == club():
		for i in starters.size():
			for j in range(i + 1, starters.size()):
				_raise_bond(starters[i], starters[j], base)
	else:
		var g := 0.0
		for pid in starters:
			g += Bonds.growth_of(world.players[pid]["personality"])
		d["ai_bond"][club_id] = Bonds.gain(float(d["ai_bond"][club_id]), base, g / float(maxi(1, starters.size())))


func _raise_bond(a: String, b: String, base: float) -> void:
	var k := Bonds.pair_key(a, b)
	var g := Bonds.pair_growth(world.players[a], world.players[b])
	d["bonds"][k] = Bonds.gain(float(d["bonds"].get(k, float(Bonds.data()["bond"]["start_new_signing"]))), base, g)


## A team-scrim week gives +1.5 to a pair when both have it as their focus; one tick is half a week.
func _scrim_bonds() -> void:
	var ids: Array = []
	for pid in d["roster"]:
		var f: Dictionary = (d["train"] as Dictionary).get(pid, {})
		if f.get("k", "") == "scrim":
			ids.append(pid)
	var b: Dictionary = Bonds.data()["bond"]
	var base := float(b["scrim_week_gain"]) / float(b["ticks_per_week"])
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			_raise_bond(ids[i], ids[j], base)


func bond(a: String, b: String) -> float:
	return world.bond_of(a, b)


func form_of(pid: String) -> float:
	return world.form_of(pid)


func morale_of(pid: String) -> float:
	return world.morale_of(pid)


## Average bond over the ten pairs of the five starters.
func bond_mean() -> float:
	var ids: Array = (d["lineup"] as Dictionary).values()
	var t := 0.0
	var n := 0
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			t += bond(ids[i], ids[j])
			n += 1
	return t / float(maxi(1, n))


## Chemistry of the managed club's lineup (0 to 100) and the rating bonus it gives.
func chem() -> float:
	return world.chem_of(lineup())


func chem_bonus() -> float:
	return Bonds.chem_bonus(chem())


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
		_tick_day()
		d["round"] = r + 1
		if int(d["round"]) % ROUNDS_PER_PATCH == 0:
			world.refresh_lineups()  # patch day: the AI managers re-pick their best lineups
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


## Plans for one of the managed club's games: the saved plan on the human side, the coach's suggestion for the AI.
func plans_for(g: Dictionary) -> Dictionary:
	var mine := "B" if g["blue"] == club() else "R"
	var out := {"B": "ai", "R": "ai"}
	out[mine] = plan_set()
	return out


## The managed club's plan set (older saves have none: neutral).
func plan_set() -> Dictionary:
	if not d.has("plan"):
		d["plan"] = GamePlan.neutral_set()
	return d["plan"]


func auto_game(g: Dictionary) -> Dictionary:
	var meta := meta_for(int(g["round"]))
	return MatchRunner.auto(world, lineup_for(g["blue"]), lineup_for(g["red"]), meta, int(d["save_seed"]), g["id"], bool(g["full"]), plans_for(g))


# ---------------------------------------------------------------- training
## The focus a player of the managed club follows: {"k": "stat"|"hero"|"rest", "v": stat or hero id}.
func focus_of(p: Dictionary) -> Dictionary:
	return Progression.focus_of(d, p, true)


func set_focus(player_id: String, kind: String, value: String = "") -> void:
	(d["train"] as Dictionary)[player_id] = {"k": kind, "v": value}


## Back to the coach's pick for everybody on the roster.
func coach_picks_all() -> void:
	for p in world.club_players(club()):
		(d["train"] as Dictionary).erase(p["id"])


## Stat points a player has gained (or lost) since this season began.
func season_gain(player_id: String, stat: String) -> float:
	var now := float((d["stat_gain"] as Dictionary).get(player_id, {}).get(stat, 0.0))
	var then := float((d["season_base"] as Dictionary).get(player_id, {}).get(stat, 0.0))
	return now - then


## Players of the managed club who start and are tired enough to cost rating.
func tired_starters(line: float = 40.0) -> Array:
	var out: Array = []
	for s in SLOTS:
		var p: Dictionary = world.players[d["lineup"][s]]
		if world.fatigue_of(p["id"]) >= line:
			out.append(p)
	return out


# ---------------------------------------------------------------- playoffs
func _start_playoffs() -> void:
	d["phase"] = "playoffs"
	_settle_league()
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
		_rate(s["a"], s["b"], s["winner"] == s["a"], "final" if s["id"] == "F" else "semi", int(s["best_of"]))


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
			var r := MatchRunner.auto(world, lineup_for(g["blue"]), lineup_for(g["red"]), meta_for(0), int(d["save_seed"]), g["id"], bool(g["full"]), {"B": "ai", "R": "ai"})
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
	_pay_playoff_prize(series_result)
	if series_result == "champion" or series_result == "runner_up":
		for pid in (d["lineup"] as Dictionary).values():
			Career.add_log(d, pid, "title" if series_result == "champion" else "runner_up")
	var prize := 0.0
	for e in d["ledger"]:
		if int(e["s"]) == int(d["season"]) and String(e["k"]).begins_with("prize"):
			prize += float(e["a"])
	(d["seasons_done"] as Array).append({"season": d["season"], "rank": mine.get("rank", 0), "w": mine.get("w", 0), "l": mine.get("l", 0),
			"result": series_result, "champion": d["champion"], "prize": snappedf(prize, 0.1)})


func playoff_label(s: Dictionary) -> String:
	return "playoff.stage." + ("final" if s["id"] == "F" else "semi")


func next_season() -> GameState:
	var left_club := _expire_contracts()
	for pid in left_club:
		Career.add_log(d, pid, "left")
	for pid in d["roster"]:
		if not left_club.has(pid):
			Career.add_log(d, pid, "birthday", {"age": world.age_of(world.players[pid]) + 1})
	Progression.age_everyone(world)
	var fa: Array = (d["fa"] as Array).duplicate()
	fa.append_array(left_club)
	var roster: Array = []
	for pid in d["roster"]:
		if not left_club.has(pid):
			roster.append(pid)
	var contracts := {}
	for pid in roster:
		var c: Dictionary = (d["contracts"] as Dictionary)[pid]
		contracts[pid] = {"wage": int(c["wage"]), "left": int(c["left"]) - 1 if not _kept_by_board(pid) else int(c["left"])}
	var days := float(Bonds.data()["offseason_days"])
	var form_c := {}
	for pid in d["form"]:
		form_c[pid] = Bonds.form_after_days(float(d["form"][pid]), days)
	var morale_c := {}
	for pid in d["morale"]:
		morale_c[pid] = Bonds.morale_after_days(float(d["morale"][pid]), days)
	var carry := {"form": form_c, "morale": morale_c, "bonds": (d["bonds"] as Dictionary).duplicate(), "ai_bond": (d["ai_bond"] as Dictionary).duplicate(),
			"miss": {}, "was_start": {}, "fam_bonus": d["fam_bonus"], "history": d["history"], "settings": d["settings"], "seasons_done": d["seasons_done"], "plan": plan_set(),
			"stat_gain": (d["stat_gain"] as Dictionary).duplicate(true), "fatigue": {}, "train": d["train"],
			"roster": roster, "fa": fa, "contracts": contracts, "cash": d["cash"], "r0": d["r0"], "ledger": d["ledger"],
			"clock": d["clock"], "lock": d["lock"], "frating": d["frating"], "pace": pace(), "career": career_all(), "exh_n": int(d.get("exh_n", 0))}
	var lu: Dictionary = d["lineup"]
	var gs := GameState.new_game(world, club(), int(d["save_seed"]) + 1000 * int(d["season"]), int(d["season"]) + 1, carry)
	gs.d["lineup"] = lu
	gs._fix_lineup()
	return gs


# ---------------------------------------------------------------- economy
func _init_economy(carry: Dictionary) -> void:
	var e := Economy.data()
	var season := int(d["season"])
	if carry.has("contracts"):
		d["contracts"] = carry["contracts"]
	else:
		d["contracts"] = {}
		for pid in d["roster"]:
			d["contracts"][pid] = Economy.initial_contract(world, world.players[pid])
	if carry.has("r0"):
		d["r0"] = float(carry["r0"]) * (1.0 + float(e["r0_inflation"]))
	else:
		d["r0"] = Economy.revenue_base(world, world.orig_ids(club()), season)
	d["ledger"] = carry.get("ledger", [])
	d["lock"] = carry.get("lock", {})
	d["clock"] = int(carry.get("clock", 0))
	d["neg"] = {}
	d["neg_rounds"] = 0
	d["dismissed"] = false
	d["sponsor"] = "steady"
	d["targets"] = _sponsor_targets()
	if carry.has("cash"):
		d["cash"] = float(carry["cash"])
	else:
		d["cash"] = float(e["start_balance_weeks"]) * wage_bill()
	_earn("sponsor_bonus", float(sponsor_offer("steady")["bonus_weeks"]) * float(d["r0"]))


func _earn(kind: String, amount: float) -> void:
	if absf(amount) < 0.05:
		return
	d["cash"] = float(d["cash"]) + amount
	var led: Array = d["ledger"]
	led.append({"s": int(d["season"]), "r": int(d["round"]), "k": kind, "a": snappedf(amount, 0.1)})
	while led.size() > 160:
		led.pop_front()


func cash() -> float:
	return float(d["cash"])


## Weekly wages of everybody under contract (the whole squad, starters or not).
func wage_bill() -> float:
	var total := 0.0
	for pid in d["roster"]:
		if (d["contracts"] as Dictionary).has(pid):
			total += float(d["contracts"][pid]["wage"])
		else:
			total += float(Economy.initial_contract(world, world.players[pid])["wage"])
	return total


func revenue_base() -> float:
	return float(d["r0"])


func wage_cap() -> float:
	return float(Economy.data()["wage_cap_r0"]) * revenue_base()


func sponsor_offer(id: String) -> Dictionary:
	for o in Economy.data()["sponsors"]:
		if o["id"] == id:
			return o
	return Economy.data()["sponsors"][0]


## 1 = strongest club by the rating of its best lineup right now (ties by club id).
func strength_rank() -> int:
	var mine := world.team_rating(world.best_lineup(club()))
	var rank := 1
	for c in world.club_ids:
		if c == club():
			continue
		var r := world.team_rating(world.best_lineup(c))
		if r > mine + 1.0e-9 or (absf(r - mine) <= 1.0e-9 and String(c) < String(club())):
			rank += 1
	return rank


## Sponsor objectives are set for the club's strength at the start of the season, so a weak club is asked for
## less than a strong one: wins = what a club of that strength is expected to win, plus one; rank = one place
## better than its strength rank (never better than 2nd or worse than 6th).
func _sponsor_targets() -> Dictionary:
	var e := Economy.data()
	var r := strength_rank()
	var n := world.club_ids.size()
	var p := float(e["target_win_rate_top"]) - (float(e["target_win_rate_top"]) - float(e["target_win_rate_bottom"])) * float(r - 1) / float(n - 1)
	return {"wins": clampi(int(round(float(total_rounds()) * p)) + int(e["target_wins_extra"]), 4, total_rounds() - 2),
			"rank": clampi(r - 1, int(e["target_rank_min"]), int(e["target_rank_max"]))}


## The number the sponsor asks for this season (wins or league rank).
func sponsor_target(offer: Dictionary) -> int:
	if offer["objective"] == "wins":
		return int(d["targets"]["wins"])
	if offer["objective"] == "playoffs":
		return int(d["targets"]["rank"])
	return 0


func sponsor_offers() -> Array:
	return Economy.data()["sponsors"]


## Weekly retainer the chosen sponsor pays.
func weekly_income() -> float:
	return float(sponsor_offer(d["sponsor"])["retainer"]) * revenue_base()


func weekly_net() -> float:
	return weekly_income() - wage_bill()


## The sponsor can still be swapped until the first game of the season is played.
func sponsor_changeable() -> bool:
	if d["phase"] != "league":
		return false
	for f in d["fixtures"]:
		if f["played"]:
			return false
	return true


func set_sponsor(id: String) -> bool:
	if not sponsor_changeable() or id == d["sponsor"]:
		return false
	var r0 := revenue_base()
	_earn("sponsor_bonus", (float(sponsor_offer(id)["bonus_weeks"]) - float(sponsor_offer(d["sponsor"])["bonus_weeks"])) * r0)
	d["sponsor"] = id
	return true


## Progress towards the sponsor's target: {"label_key", "have", "target", "reward", "met"}; empty without objective.
func sponsor_objective() -> Dictionary:
	var o := sponsor_offer(d["sponsor"])
	if o["objective"] == "none":
		return {}
	var have := 0
	if o["objective"] == "wins":
		for r in standings():
			if r["club"] == club():
				have = int(r["w"])
	else:
		have = rank_of(club())
	var target := sponsor_target(o)
	var met: bool = (have >= target) if o["objective"] == "wins" else (have <= target and _fixtures_played().size() > 0)
	return {"kind": o["objective"], "have": have, "target": target, "reward": float(o["reward_weeks"]) * revenue_base(), "met": met}


func _pay_round() -> void:
	var rpw := float(Economy.data()["rounds_per_week"])
	_earn("wages", -wage_bill() / rpw)
	_earn("retainer", weekly_income() / rpw)
	if float(d["cash"]) < 0.0:
		d["neg_rounds"] = int(d["neg_rounds"]) + 1
		if int(d["neg_rounds"]) >= int(Economy.data()["dismiss_rounds"]):
			d["dismissed"] = true
	else:
		d["neg_rounds"] = 0


func _settle_league() -> void:
	var e := Economy.data()
	var r0 := revenue_base()
	var rank := rank_of(club())
	var prizes: Array = e["league_prize_weeks"]
	if rank >= 1 and rank <= prizes.size():
		_earn("prize_league", float(prizes[rank - 1]) * r0)
	var ob := sponsor_objective()
	if not ob.is_empty() and bool(ob["met"]):
		_earn("sponsor_reward", float(ob["reward"]))


func _pay_playoff_prize(result: String) -> void:
	var e := Economy.data()
	if result == "champion":
		_earn("prize_playoff", float(e["champion_prize_weeks"]) * revenue_base())
	elif result == "runner_up":
		_earn("prize_playoff", float(e["runner_up_prize_weeks"]) * revenue_base())


func is_dismissed() -> bool:
	return bool(d.get("dismissed", false))


## Negative balance for a long time ends the job: rounds left before that happens (0 when not in debt).
func debt_rounds_left() -> int:
	if float(d["cash"]) >= 0.0:
		return 0
	return maxi(0, int(Economy.data()["dismiss_rounds"]) - int(d["neg_rounds"]))


# ---- contracts
func contract_of(pid: String) -> Dictionary:
	return (d["contracts"] as Dictionary).get(pid, {})


func roster_players() -> Array:
	return world.club_players(club())


func fa_players() -> Array:
	return world.free_agent_players()


func _week_rounds_left() -> int:
	return maxi(0, total_rounds() - int(d["round"])) if d["phase"] == "league" else 0


## What letting him go costs: half the wages still owed on the contract (the current season counts from today).
func release_cost(pid: String) -> float:
	var c := contract_of(pid)
	if c.is_empty():
		return 0.0
	var weeks := float(int(c["left"]) - 1) * float(total_rounds()) / float(Economy.data()["rounds_per_week"]) \
			+ float(_week_rounds_left()) / float(Economy.data()["rounds_per_week"])
	return float(Economy.data()["release_share"]) * float(c["wage"]) * weeks


func can_release(pid: String) -> String:
	if not (d["roster"] as Array).has(pid):
		return "unknown"
	if (d["roster"] as Array).size() <= int(Economy.data()["min_roster"]):
		return "min"
	if release_cost(pid) > cash():
		return "cash"
	return ""


func release(pid: String) -> String:
	var why := can_release(pid)
	if why != "":
		return why
	_earn("release", -release_cost(pid))
	Career.add_log(d, pid, "released")
	(d["roster"] as Array).erase(pid)
	(d["contracts"] as Dictionary).erase(pid)
	(d["fa"] as Array).append(pid)
	(d["lock"] as Dictionary)[pid] = int(d["clock"]) + int(Economy.data()["lockout_rounds"])
	_after_roster_change()
	return ""


func _after_roster_change() -> void:
	_sync_bonds()
	world.refresh_lineup(club())
	_fix_lineup()


## Any starting slot whose player has left is filled with the best rested player on the bench.
func _fix_lineup() -> void:
	var roster: Array = d["roster"]
	for s in SLOTS:
		if roster.has(d["lineup"][s]):
			continue
		var in_lineup := {}
		for t in SLOTS:
			in_lineup[d["lineup"][t]] = true
		var best := ""
		var best_score := -1.0e30
		for pid in roster:
			if in_lineup.has(pid):
				continue
			var sc := world.slot_score(world.players[pid], s)
			if sc > best_score:
				best_score = sc
				best = pid
		d["lineup"][s] = best


## Contracts that end with this season.
func expiring() -> Array:
	var out: Array = []
	for pid in d["roster"]:
		if int(contract_of(pid).get("left", 9)) <= 1:
			out.append(world.players[pid])
	return out


## Squad places taken: after the season is over the expiring players no longer count, so replacements can be signed.
func roster_slots_used() -> int:
	return (d["roster"] as Array).size() - (expiring().size() if d["phase"] == "done" else 0)


## Seasons still to play on a contract as the player should read it (zero once it has run out).
func seasons_left(pid: String) -> int:
	var c := contract_of(pid)
	if c.is_empty():
		return 0
	return int(c["left"]) - (1 if d["phase"] == "done" else 0)


## Players who would be left after the expiring contracts run out and nobody renews.
func roster_after_expiry() -> int:
	return (d["roster"] as Array).size() - expiring().size()


## Ids who leave at the season change; if that would leave too few players the board keeps the best ones.
func _expire_contracts() -> Array:
	var leaving: Array = []
	for p in expiring():
		leaving.append(p["id"])
	var min_n := int(Economy.data()["min_roster"])
	var need := min_n - ((d["roster"] as Array).size() - leaving.size())
	if need > 0:
		leaving.sort_custom(func(a, b): return Economy.best_slot_rating(world, world.players[a]) > Economy.best_slot_rating(world, world.players[b]))
		_board_kept = leaving.slice(0, need)
		leaving = leaving.slice(need)
	else:
		_board_kept = []
	return leaving


var _board_kept: Array = []


func _kept_by_board(pid: String) -> bool:
	return _board_kept.has(pid)


# ---- negotiation
## Why an offer cannot even be made: "" when it can.
func offer_block(pid: String, wage: int, renewal: bool) -> String:
	if int((d["lock"] as Dictionary).get(pid, -1)) > int(d["clock"]):
		return "locked"
	if not renewal:
		if roster_slots_used() >= int(Economy.data()["max_roster"]):
			return "full"
		if cash() < 0.0 or cash() < signing_fee(wage):
			return "cash"
	var cur := float(contract_of(pid).get("wage", 0.0)) if renewal else 0.0
	if wage_bill() - cur + float(wage) > wage_cap():
		return "cap"
	return ""


func signing_fee(wage: int) -> float:
	return float(wage) * float(Economy.data()["sign_fee_weeks"])


func asking_wage(pid: String) -> int:
	return Economy.asking_wage(world, world.players[pid])


func negotiation_rounds_used(pid: String) -> int:
	return int((d["neg"] as Dictionary).get(pid, 0))


func lockout_left(pid: String) -> int:
	return maxi(0, int((d["lock"] as Dictionary).get(pid, -1)) - int(d["clock"]))


## One offer. Returns {"code": "accepted"|"close"|"below"|"far"|"walked"|"locked"|"full"|"cash"|"cap"|"bad", "rounds_left": int}.
func offer(pid: String, wage: int, length: int, renewal: bool = false) -> Dictionary:
	var e := Economy.data()
	length = clampi(length, 1, int(e["max_length"]))
	if not world.players.has(pid) or (renewal and not (d["roster"] as Array).has(pid)) or (not renewal and not (d["fa"] as Array).has(pid)):
		return {"code": "bad", "rounds_left": 0}
	if renewal and int(contract_of(pid).get("left", 9)) > 1:
		return {"code": "bad", "rounds_left": 0}
	var block := offer_block(pid, wage, renewal)
	if block != "":
		return {"code": block, "rounds_left": maxi(0, int(e["negotiation_rounds"]) - negotiation_rounds_used(pid))}
	var p: Dictionary = world.players[pid]
	var res := Economy.response(world, p, wage, length)
	if res == "accept":
		(d["neg"] as Dictionary).erase(pid)
		if renewal:
			var c: Dictionary = d["contracts"][pid]
			c["wage"] = wage
			c["left"] = int(c["left"]) + length
			Career.add_log(d, pid, "renewed", {"len": length})
			_after_roster_change()
		else:
			_earn("signing", -signing_fee(wage))
			(d["fa"] as Array).erase(pid)
			(d["roster"] as Array).append(pid)
			(d["contracts"] as Dictionary)[pid] = {"wage": wage, "left": length + (1 if d["phase"] == "done" else 0)}
			Career.add_log(d, pid, "signed", {"wage": wage})
			_after_roster_change()
		return {"code": "accepted", "rounds_left": 0}
	var used := negotiation_rounds_used(pid) + 1
	(d["neg"] as Dictionary)[pid] = used
	var walks: bool = used >= int(e["negotiation_rounds"]) or (p["personality"] == "temperamental" and used >= int(e["temperamental_walks_after"]))
	if walks:
		(d["neg"] as Dictionary).erase(pid)
		(d["lock"] as Dictionary)[pid] = int(d["clock"]) + int(e["lockout_rounds"])
		return {"code": "walked", "rounds_left": 0}
	return {"code": res, "rounds_left": int(e["negotiation_rounds"]) - used}


# ---------------------------------------------------------------- persistence
# ---------------------------------------------------------------- pace log (local only)
## How long games really take for this manager: whole game from tapping Play to the report, the time spent
## watching the feed, and how often the feed is skipped or sped up. Kept in the save, never sent anywhere.
func pace() -> Dictionary:
	if not d.has("pace"):
		d["pace"] = {"n": 0, "total_s": 0.0, "watch_s": 0.0, "max_total_s": 0.0, "skips": 0, "fast": 0, "quick": 0}
	return d["pace"]


func pace_add(total_s: float, watch_s: float, skipped: bool, fast: bool) -> void:
	var p := pace()
	p["n"] = int(p["n"]) + 1
	p["total_s"] = float(p["total_s"]) + total_s
	p["watch_s"] = float(p["watch_s"]) + watch_s
	p["max_total_s"] = maxf(float(p["max_total_s"]), total_s)
	if skipped:
		p["skips"] = int(p["skips"]) + 1
	if fast:
		p["fast"] = int(p["fast"]) + 1


func pace_quick() -> void:
	var p := pace()
	p["quick"] = int(p["quick"]) + 1


func save() -> bool:
	if is_dismissed():
		return true  # the last autosave before the dismissal stays on disk
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
