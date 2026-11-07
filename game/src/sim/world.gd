class_name World
extends RefCounted
## Static game data plus the rating model (GDD 4.4): heroes, players, clubs,
## familiarity, phase ratings, AI lineups, team building. Port of the first part
## of tools/pipeline.py; pinned by res://tests/golden/pipeline_vectors.json.

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const STATS := ["mec", "sen", "lan", "tft", "mac", "com", "con", "clu"]
const SLOT_W := {
	"top": [0.25, 0.15, 0.30, 0.20, 0.10],
	"jg": [0.15, 0.25, 0.05, 0.20, 0.35],
	"mid": [0.30, 0.20, 0.25, 0.15, 0.10],
	"bot": [0.35, 0.10, 0.25, 0.25, 0.05],
	"sup": [0.10, 0.30, 0.10, 0.20, 0.30],
}
const EARLY_STAT := {"top": "lan", "mid": "lan", "bot": "lan", "jg": "mac", "sup": "sen"}
const TWO53 := 9007199254740992.0

var heroes: Dictionary = {}       # id -> hero dict
var hero_ids: Array = []          # sorted ids
var players: Dictionary = {}      # id -> player dict
var clubs: Dictionary = {}        # id -> club dict
var club_ids: Array = []          # file order
var fam_bonus: Dictionary = {}    # "player|hero" -> trained familiarity points (saved)
var fatigue: Dictionary = {}      # player id -> 0..100 (saved; missing = fresh)
var progress: Dictionary = {}     # player id -> {stat: points gained or lost since the start} (saved)
var season_offset := 0            # seasons played so far: everybody is this many years older

var fa_ids: Array = []            # free agents right now (saved by the game; starts as the players without a club)

var _orig_stats: Dictionary = {}  # player id -> the stats the data files gave him
var _orig_ids: Dictionary = {}    # club id -> the roster the data files gave it
var _orig_fa: Array = []
var _roster_club := ""            # the one club whose roster the save may have changed

var _fam_cache: Dictionary = {}
var _sig_cache: Dictionary = {}
var _lineup_cache: Dictionary = {}


static func load_default() -> World:
	var w := World.new()
	var hs = DataLoader.load_json("res://data/heroes.json")
	var ps = DataLoader.load_json("res://data/players.json")
	var cs = DataLoader.load_json("res://data/clubs.json")
	for h in hs:
		w.heroes[h["id"]] = h
	w.hero_ids = w.heroes.keys()
	w.hero_ids.sort()
	for p in ps:
		w.players[p["id"]] = p
	for c in cs:
		w.clubs[c["id"]] = c
		w.club_ids.append(c["id"])
		w._orig_ids[c["id"]] = (c["player_ids"] as Array).duplicate()
	for p in ps:
		if p["club"] == null:
			w._orig_fa.append(p["id"])
	w.fa_ids = w._orig_fa.duplicate()
	return w


# ---------------------------------------------------------------- roster overlay
func orig_ids(club_id: String) -> Array:
	return _orig_ids[club_id]


func orig_free_agents() -> Array:
	return _orig_fa.duplicate()


## Point the world at one save's roster for the managed club and its free-agent pool. The other clubs keep
## the rosters of the data files.
func bind_roster(club_id: String, roster: Array, fa: Array) -> void:
	if _roster_club != "" and _roster_club != club_id:
		clubs[_roster_club]["player_ids"] = (_orig_ids[_roster_club] as Array).duplicate()
		_lineup_cache.erase(_roster_club)
	_roster_club = club_id
	clubs[club_id]["player_ids"] = roster
	fa_ids = fa
	_lineup_cache.erase(club_id)


func free_agent_players() -> Array:
	var out: Array = []
	for pid in fa_ids:
		out.append(players[pid])
	return out


# ---------------------------------------------------------------- progress overlay
## Point the world at one save's growth state. Players' stat dictionaries are rewritten in place
## (original value + saved change), so every rating function keeps reading p["stats"].
func bind_progress(prog: Dictionary, fat: Dictionary, offset: int) -> void:
	if _orig_stats.is_empty():
		for pid in players:
			_orig_stats[pid] = (players[pid]["stats"] as Dictionary).duplicate()
	for pid in progress:
		if not prog.has(pid):
			_restore(pid)
	progress = prog
	fatigue = fat
	season_offset = offset
	for pid in progress:
		_apply_one(pid)
	_lineup_cache.clear()


func _restore(pid: String) -> void:
	var st: Dictionary = players[pid]["stats"]
	for k in _orig_stats[pid]:
		st[k] = _orig_stats[pid][k]


func _apply_one(pid: String) -> void:
	var st: Dictionary = players[pid]["stats"]
	var ch: Dictionary = progress.get(pid, {})
	for k in _orig_stats[pid]:
		var v := float(_orig_stats[pid][k]) + float(ch.get(k, 0.0))
		st[k] = clampf(v, 1.0, 99.0) if ch.has(k) else _orig_stats[pid][k]


func add_progress(pid: String, stat: String, amount: float) -> void:
	if not progress.has(pid):
		progress[pid] = {}
	progress[pid][stat] = float(progress[pid].get(stat, 0.0)) + amount
	_apply_one(pid)


## Forget the cached best lineups so the next call sees today's stats (the search is the expensive part of
## a season, so growth does not trigger it by itself; the game calls this on patch days and after ageing).
func refresh_lineups() -> void:
	_lineup_cache.clear()


## Same for one club (the manager asking for "best lineup" must not make nine AI clubs recompute).
func refresh_lineup(club_id: String) -> void:
	_lineup_cache.erase(club_id)


func fatigue_of(pid: String) -> float:
	return float(fatigue.get(pid, 0.0))


func age_of(p: Dictionary) -> int:
	return int(p["age"]) + season_offset


## Rating a player brings to a slot right now: BaseRating x fit, less the fatigue penalty.
func slot_score(p: Dictionary, slot: String) -> float:
	return base_rating(p, slot) * player_fit(p, slot) - Progression.fatigue_penalty(fatigue_of(p["id"]))


## The AI's lineup with rotation: the best rested lineup, then any bench player who is worth more than a
## tired starter takes his slot. With nobody tired this is exactly best_lineup.
func rotated_lineup(club_id: String) -> Dictionary:
	var lu := best_lineup(club_id)
	var ps := club_players(club_id)
	for _pass in 2:
		for s in SLOTS:
			var in_lineup := {}
			for t in SLOTS:
				in_lineup[lu[t]["id"]] = true
			var cur: Dictionary = lu[s]
			var best_gain := 0.0
			var pick: Dictionary = {}
			var cur_score := slot_score(cur, s)
			for p in ps:
				if in_lineup.has(p["id"]):
					continue
				var gain := slot_score(p, s) - cur_score
				if gain > best_gain + 1.0e-9:
					best_gain = gain
					pick = p
			if not pick.is_empty():
				lu[s] = pick
	return lu


# ---------------------------------------------------------------- ratings
func base_rating(p: Dictionary, slot: String) -> float:
	var wts: Array = SLOT_W[slot]
	var total := 0.0
	for i in 5:
		total += float(wts[i]) * float(p["stats"][STATS[i]])
	return total


func player_fit(p: Dictionary, slot: String) -> float:
	if p["role_primary"] == slot:
		return 1.0
	if p.get("role_secondary", "") == slot:
		return 0.93
	return 0.80


func hero_fit(h: Dictionary, slot: String) -> float:
	if h["role_primary"] == slot:
		return 1.0
	if h.get("role_secondary", "") == slot:
		return 0.95
	return 0.85


static func _u(text: String) -> float:
	return float(Pcg32.lsr(Pcg32.fnv1a64(text), 11)) / TWO53


func _signature(p: Dictionary) -> Dictionary:
	var pid: String = p["id"]
	if not _sig_cache.has(pid):
		var elig: Array = []
		for hid in hero_ids:
			var h: Dictionary = heroes[hid]
			if h["role_primary"] == p["role_primary"] or h.get("role_secondary", "") == p["role_primary"]:
				elig.append([_u("sig:%s:%s" % [pid, hid]), hid])
		elig.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		var s := {}
		for i in 3:
			s[elig[i][1]] = true
		_sig_cache[pid] = s
	return _sig_cache[pid]


func base_familiarity(p: Dictionary, hid: String) -> float:
	var key: String = p["id"] + "|" + hid
	if _fam_cache.has(key):
		return _fam_cache[key]
	var v: float
	if _signature(p).has(hid):
		v = 50.0 + 35.0 * _u("famsig:%s:%s" % [p["id"], hid])
	else:
		v = 30.0 * _u("fam:%s:%s" % [p["id"], hid])
	_fam_cache[key] = v
	return v


func familiarity(p: Dictionary, hid: String) -> float:
	var b := base_familiarity(p, hid)
	var extra: float = float(fam_bonus.get(p["id"] + "|" + hid, 0.0))
	return minf(100.0, b + extra)


func phase_rating(p: Dictionary, slot: String, hero: Dictionary, phase: String, fam: float, meta: float,
		morale: float = -1.0, fat: float = 0.0) -> float:
	if morale < 0.0:
		morale = Params.f("cal_morale")
	var fam_w := Params.f("fam_w")
	var base := base_rating(p, slot)
	var pb: float
	match phase:
		"early":
			pb = 0.7 * base + 0.3 * float(p["stats"][EARLY_STAT[slot]])
		"mid":
			pb = base
		_:
			pb = 0.8 * base + 0.2 * float(p["stats"]["clu"])
	var cond := (morale - 50.0) * 0.06 - Progression.fatigue_penalty(fat)
	var hf := ((1.0 - fam_w) + fam_w * fam / 100.0) * (0.90 + 0.10 * minf(1.0, float(p["stats"]["mec"]) / (15.0 * float(hero["difficulty"]))))
	var fit := player_fit(p, slot) * hero_fit(hero, slot)
	return (pb + cond) * hf * fit * (1.0 + (float(hero["power_" + phase]) - 50.0) / 200.0) * meta


func make_meta(seed_text: String) -> Dictionary:
	var spread := Params.f("meta_spread")
	var m := {}
	for hid in hero_ids:
		m[hid] = 1.0 + spread * (2.0 * _u("meta:%s:%s" % [seed_text, hid]) - 1.0)
	return m


# ---------------------------------------------------------------- lineups
func club_players(club_id: String) -> Array:
	var out: Array = []
	for pid in clubs[club_id]["player_ids"]:
		out.append(players[pid])
	return out


## AI lineup rule: maximise the sum of BaseRating * PlayerFit over assignments of 5 of the club's players.
func best_lineup(club_id: String) -> Dictionary:
	if _lineup_cache.has(club_id):
		return _lineup_cache[club_id].duplicate()
	var ps := club_players(club_id)
	var n := ps.size()
	var tab: Array = []
	var prim: Array = []
	for i in n:
		var row: Array = []
		var prow: Array = []
		for s in SLOTS:
			row.append(base_rating(ps[i], s) * player_fit(ps[i], s))
			prow.append(1 if ps[i]["role_primary"] == s else 0)
		tab.append(row)
		prim.append(prow)
	var best_combo: Array = []
	var best_key_total := -1.0e30
	var best_key_prim := -1
	var combo := [0, 0, 0, 0, 0]
	for a in n:
		for b in n:
			if b == a:
				continue
			for c in n:
				if c == a or c == b:
					continue
				for d in n:
					if d == a or d == b or d == c:
						continue
					for e in n:
						if e == a or e == b or e == c or e == d:
							continue
						var total: float = tab[a][0] + tab[b][1] + tab[c][2] + tab[d][3] + tab[e][4]
						var pr: int = prim[a][0] + prim[b][1] + prim[c][2] + prim[d][3] + prim[e][4]
						var tkey := roundf(total * 1.0e9) / 1.0e9
						if best_combo.is_empty() or tkey > best_key_total or (tkey == best_key_total and pr > best_key_prim):
							best_combo = [a, b, c, d, e]
							best_key_total = tkey
							best_key_prim = pr
	var out := {}
	for i in 5:
		out[SLOTS[i]] = ps[best_combo[i]]
	_lineup_cache[club_id] = out
	return out.duplicate()


func team_rating(lineup: Dictionary) -> float:
	var t := 0.0
	for s in SLOTS:
		t += base_rating(lineup[s], s)
	return t / 5.0


# ---------------------------------------------------------------- team building
func lane_mods(mine: Dictionary, theirs: Dictionary) -> Dictionary:
	var lm := Params.f("lane_mod")
	var out := {}
	for lane in ["top", "mid", "jg"]:
		if (mine[lane]["strong_vs"] as Array).has(theirs[lane]["id"]):
			out[lane] = lm
	var links := false
	for m in [mine["bot"], mine["sup"]]:
		for t in [theirs["bot"], theirs["sup"]]:
			if (m["strong_vs"] as Array).has(t["id"]):
				links = true
	if links:
		out["bot"] = lm
	return out


func build_team(lineup: Dictionary, picks_mine: Dictionary, picks_theirs: Dictionary, meta: Dictionary,
		con_override: float = -1.0, neutral_draft: bool = false, team_mod: float = -1.0) -> Dictionary:
	if team_mod < 0.0:
		team_mod = Params.f("team_mod_default")
	var ratings := {}
	for ph in ["early", "mid", "late"]:
		var r := {}
		for s in SLOTS:
			var hero: Dictionary = picks_mine[s]
			r[s] = phase_rating(lineup[s], s, hero, ph, familiarity(lineup[s], hero["id"]), float(meta[hero["id"]]), -1.0, fatigue_of(lineup[s]["id"]))
		ratings[ph] = r
	var mine_list: Array = []
	for s in SLOTS:
		mine_list.append(picks_mine[s])
	var ev := Comp.evaluate(mine_list)
	var con: float
	if con_override >= 0.0:
		con = con_override
	else:
		con = 0.0
		for s in SLOTS:
			con += float(lineup[s]["stats"]["con"])
		con /= 5.0
	return {"ratings": ratings, "con": con, "team_mod": team_mod,
			"comp_mod": 0.0 if neutral_draft else ev["mod"],
			"lane_mod": {} if neutral_draft else lane_mods(picks_mine, picks_theirs),
			"style": "skirmish" if neutral_draft else ev["style"]}
