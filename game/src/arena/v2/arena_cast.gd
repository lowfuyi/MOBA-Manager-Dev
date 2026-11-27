class_name ArenaCast
extends RefCounted
## The Broadcast (Match Day M4, docs/design/BROADCAST.md): two casters' lines for a whole Match Sim v2 game, built once from
## the finished game's log (an ArenaPlayer). A play-by-play voice ("p") calls what happens; an analyst ("a") explains why.
## An excitement signal e(show time) built from the log's moments sets the emotion tier (calm, building, hot, peak,
## aftermath), which sets how long lines are, how fast they come and which fill lines are used.
## Display only (rules A1 and R7): reads the ArenaPlayer, never the simulation. Deterministic: variants are chosen by a hash
## of the game id, the key and the time. Spoiler rule: a line at show time s only uses log events at or before game_t(s).
## Truth rule: every line carries its claims ([kind, ...], with the game time they refer to) for tests/check_cast.
## Replaces ArenaComment (0.12, at most two lines a game).

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const OBJ := ["mossback", "stoneback", "moonhulk"]
const PRIO_EVENT := 3
const PRIO_EMOTION := 2
const PRIO_ANALYSIS := 1
const PRIO_FILLER := 0

## The tier each key is written for (catalogue, BROADCAST.md 5): it sets the line's type size and its word range.
const KEY_TIER := {
	"p.intro.welcome": "calm", "p.intro.lane": "calm", "p.calm.scene": "calm", "p.calm.farm": "calm", "p.recall": "calm",
	"p.gank": "building", "p.ward": "building", "p.spike": "building", "p.obj.up": "building", "p.obj.start": "building",
	"p.obj.take": "hot", "p.obj.steal": "peak", "p.fight.start": "building", "p.fight.big": "hot", "p.fight.end.clean": "hot",
	"p.fight.end.narrow": "hot", "p.fight.end.even": "building", "p.first_blood": "peak", "p.kill.solo": "hot",
	"p.kill.trade": "hot", "p.kill.double": "hot", "p.kill.triple": "peak", "p.kill.quadra": "peak", "p.kill.wipe": "peak",
	"p.kill.streak": "hot", "p.kill.shutdown": "hot", "p.tower.fall": "hot", "p.tower.inner": "hot", "p.base.race": "peak",
	"p.gold.swing": "hot", "p.lead.flip": "peak", "p.comeback": "peak", "p.late.tension": "building", "p.final.blow": "peak",
	"p.ex.hot.good": "hot", "p.ex.hot.bad": "hot", "p.ex.hot.neutral": "hot",
	"p.ex.peak.good": "peak", "p.ex.peak.bad": "peak", "p.ex.peak.neutral": "peak",
	"a.intro.welcome": "calm", "a.intro.pick": "calm", "a.intro.matchup": "calm", "a.intro.late": "calm", "a.intro.early": "calm",
	"a.lanes.lead": "calm", "a.lanes.even": "calm", "a.gold.lead": "calm", "a.gold.even": "calm", "a.spike": "calm",
	"a.after.fight.numbers": "aftermath", "a.after.fight.gold": "aftermath", "a.after.fight.even": "aftermath",
	"a.after.kill": "aftermath", "a.after.wipe": "aftermath", "a.after.obj.stoneback": "aftermath",
	"a.after.obj.moonhulk": "aftermath", "a.after.obj.mossback": "aftermath", "a.after.tower": "aftermath",
	"a.after.flip": "aftermath", "a.plan.switch": "building", "a.plan.read": "calm", "a.comp.read": "calm",
	"a.late.tension": "aftermath", "a.wrap.win": "aftermath", "a.wrap.close": "aftermath", "a.calm.filler": "calm",
}

var pl: ArenaPlayer
var game_id := ""
var names := {}               # side -> club name
var opts := {}
var e_grid := PackedFloat32Array()
var aftermath := PackedByteArray()
var lines: Array = []         # {s0, s1, g, voice, tier, key, text, claims, prio, keyline}; s1 = when it leaves the screen
var intro: Array = []         # {voice, key, text, claims}: before the show starts
var end_lines: Array = []     # the final blow and the wrap-up, for the end card
var on_line: Callable = Callable()    # optional hook for a later voice or text-to-speech (no audio is built)
var _cands: Array = []
var _recent: Array = []       # [s, text]
var _last_first := ""
var _last_voice := ""
var _impulses: Array = []     # [show s, size]
var _lead_cache := {}
var _base_open_g := INF
var _filler_turn := 0

static var _params: Dictionary = {}
static var _counts: Dictionary = {}


static func params() -> Dictionary:
	if _params.is_empty():
		var fa := FileAccess.open("res://data/cast_params_v1.json", FileAccess.READ)
		var d: Variant = JSON.parse_string(fa.get_as_text()) if fa != null else null
		_params = d if d is Dictionary else {}
	return _params


## How many variants a key base has in the string table (keys base.1 .. base.n with no gaps).
static func variants(base: String) -> int:
	if not _counts.has(base):
		var n := 0
		while Strings.has_key("arena.cast.%s.%d" % [base, n + 1]):
			n += 1
		_counts[base] = n
	return int(_counts[base])


static func words(text: String) -> int:
	return text.strip_edges().split(" ", false).size()


## `p_names` {"B": club name, "R": club name}; `p_opts` {"tutorial": bool}.
static func build(p_pl: ArenaPlayer, p_game_id: String, p_names: Dictionary, p_opts: Dictionary = {}) -> ArenaCast:
	var c := ArenaCast.new()
	c.pl = p_pl
	c.game_id = p_game_id
	c.names = p_names
	c.opts = p_opts
	c._collect()
	c._excitement()
	c._intro()
	c._schedule()
	c._end()
	return c


# ---------------------------------------------------------------- helpers
func hero(key: String) -> String:
	return ArenaHud2.hero_name(pl, key)


func team(side: String) -> String:
	return String(names.get(side, side))


static func other(side: String) -> String:
	return "R" if side == "B" else "B"


## Blue's gold minus Red's at game time g (the log's team gold samples).
func lead_b(g: float) -> int:
	var k := int(g * 2.0)
	if not _lead_cache.has(k):
		var sc := pl.score(g)
		_lead_cache[k] = int(sc["gold"]["B"]) - int(sc["gold"]["R"])
	return int(_lead_cache[k])


static func gold_text(n: int) -> String:
	return ArenaHud2.grouped(int(roundf(float(absi(n)) / 100.0)) * 100)


func lane_word(lane: String) -> String:
	return Strings.t("role.short." + lane)


func place_word(oid: String) -> String:
	return Strings.t("arena2.place." + oid)


## A place name for a point of the map: an objective's name when near one, else the lane or the jungle.
func place_at(p: Vector2) -> String:
	var best := ""
	var bd := 0.13
	for oid in OBJ:
		var op: Variant = _obj_pos(oid)
		if op is Vector2 and SimData.du(p, op as Vector2) < bd:
			bd = SimData.du(p, op as Vector2)
			best = place_word(oid)
	if best != "":
		return best
	if p.x < 0.17:
		return Strings.t("arena.cast.place.top")
	if p.x > 0.83:
		return Strings.t("arena.cast.place.bot")
	if absf(p.x - 0.5) < 0.08:
		return Strings.t("arena.cast.place.mid")
	if p.y > 0.86 or p.y < 0.14:
		return Strings.t("arena.cast.place.base")
	return Strings.t("arena.cast.place.jungle")


static var _obj_p: Dictionary = {}


static func _obj_pos(oid: String) -> Variant:
	if _obj_p.is_empty():
		var fa := FileAccess.open("res://data/arena_map.json", FileAccess.READ)
		var d: Variant = JSON.parse_string(fa.get_as_text()) if fa != null else null
		if d is Dictionary:
			for o in d["objectives"]:
				var id := String(o["id"]).get_slice(".", 1)
				_obj_p[id] = Vector2(float(o["p"][0]), float(o["p"][1]))
	return _obj_p.get(oid, null)


func _centre(keys: Array, g: float) -> Vector2:
	var c := Vector2.ZERO
	for k in keys:
		c += pl._sample(String(k), g)[0] as Vector2
	return c / float(maxi(1, keys.size()))


func _imp(g: float, size: float) -> void:
	_impulses.append([pl.show_t(g), size])


## A candidate line. `g` is the game time of the moment it is about (claims refer to it); it can be shown from show_t(g).
func _cand(g: float, prio: int, key: String, vars: Dictionary, claims: Array, stale: float = -1.0, side: String = "", keyline: bool = false) -> void:
	var P := params()
	var st := stale
	if st < 0.0:
		st = float(P["stale_s"]["default"])
	_cands.append({"g": g, "s": pl.show_t(g), "prio": prio, "key": key, "vars": vars, "claims": claims, "stale": st,
			"side": side, "keyline": keyline, "used": false})


# ---------------------------------------------------------------- moments from the log
func _collect() -> void:
	var P := params()
	var imp: Dictionary = P["impulse"]
	# --- kills
	var since_death := {}
	var chain := {}           # killer -> [last t, count]
	var first_done := false
	var wiped := {}           # side -> game t of the last wipe line
	var last_kill: Array = []
	for k in pl.kills:
		var t := float(k[0])
		var killer := String(k[1])
		var victim := String(k[2])
		_imp(t, float(imp["kill"]))
		var vstreak := int(since_death.get(victim, 0))
		since_death[victim] = 0
		if killer.begins_with("tower."):
			last_kill = []
			continue
		since_death[killer] = int(since_death.get(killer, 0)) + 1
		var ch: Array = chain.get(killer, [-INF, 0])
		var n := int(ch[1]) + 1 if t - float(ch[0]) <= float(P["multi_kill_s"]) else 1
		chain[killer] = [t, n]
		var ks := ArenaPlayer.side_of(killer)
		var vars := {"hero": hero(killer), "hero2": hero(victim)}
		var claim := ["kill", killer, victim, t]
		# a team wipe: all five of the victim's side dead
		var vs := ArenaPlayer.side_of(victim)
		var dead := 0
		for s in SLOTS:
			if not pl.alive(vs + "." + s, t + 0.01):
				dead += 1
		if not first_done:
			first_done = true
			_imp(t, float(imp["first_blood"]))
			_cand(t, PRIO_EVENT, "p.first_blood", vars, [claim, ["first_kill", t]], float(P["stale_s"]["kill"]), ks, true)
			_cand(t + 1.0, PRIO_EMOTION, "p.ex.peak." + _val(ks), {}, [claim], 4.0, ks)
			_cand(t + 4.0, PRIO_ANALYSIS, "a.after.kill", {"hero": hero(killer)}, [claim], 10.0, ks)
		elif dead >= 5 and t - float(wiped.get(vs, -INF)) > 30.0:
			wiped[vs] = t
			_imp(t, float(imp["wipe"]))
			_cand(t, PRIO_EVENT + 1, "p.kill.wipe", {"team": team(ks)}, [["wipe", vs, t]], float(P["stale_s"]["kill"]), ks, true)
			_cand(t + 1.0, PRIO_EMOTION, "p.ex.peak." + _val(ks), {}, [["wipe", vs, t]], 4.0, ks)
			_cand(t + 5.0, PRIO_ANALYSIS, "a.after.wipe", {"team": team(ks)}, [["wipe", vs, t]], 12.0, ks)
		elif n >= 4:
			_imp(t, float(imp["quadra"]))
			_cand(t, PRIO_EVENT + 1, "p.kill.quadra", {"hero": hero(killer)}, [["multi", killer, n, t]], float(P["stale_s"]["kill"]), ks, true)
			_cand(t + 4.0, PRIO_ANALYSIS, "a.after.kill", {"hero": hero(killer)}, [claim], 10.0, ks)
		elif n == 3:
			_imp(t, float(imp["triple"]))
			_cand(t, PRIO_EVENT + 1, "p.kill.triple", {"hero": hero(killer)}, [["multi", killer, 3, t]], float(P["stale_s"]["kill"]), ks, true)
			_cand(t + 4.0, PRIO_ANALYSIS, "a.after.kill", {"hero": hero(killer)}, [claim], 10.0, ks)
		elif n == 2:
			_imp(t, float(imp["double"]))
			_cand(t, PRIO_EVENT, "p.kill.double", {"hero": hero(killer)}, [["multi", killer, 2, t]], float(P["stale_s"]["kill"]), ks, true)
		elif vstreak >= int(P["streak"]):
			_cand(t, PRIO_EVENT, "p.kill.shutdown", vars, [claim, ["streak", victim, vstreak, t - 0.01]], float(P["stale_s"]["kill"]), ks)
		elif int(since_death[killer]) >= int(P["streak"]):
			_cand(t, PRIO_EVENT, "p.kill.streak", {"hero": hero(killer), "n": int(since_death[killer])}, [claim, ["streak", killer, int(since_death[killer]), t]], float(P["stale_s"]["kill"]), ks)
			_cand(t + 4.0, PRIO_ANALYSIS, "a.after.kill", {"hero": hero(killer)}, [claim], 10.0, ks)
		elif not last_kill.is_empty() and t - float(last_kill[0]) <= float(P["trade_s"]) and ArenaPlayer.side_of(String(last_kill[1])) == vs:
			_cand(t, PRIO_EVENT, "p.kill.trade", {"hero": hero(String(last_kill[2])), "hero2": hero(victim)},
					[["kill", String(last_kill[1]), String(last_kill[2]), float(last_kill[0])], claim], float(P["stale_s"]["kill"]), ks)
		else:
			_cand(t, PRIO_EVENT, "p.kill.solo", vars, [claim], float(P["stale_s"]["kill"]), ks)
		last_kill = [t, killer, victim]
	# --- fights
	var sizes: Array = P["fight_sizes"]
	for f in pl.fights:
		var n2: int = (f["keys"] as Array).size()
		var t0 := float(f["t0"])
		var t1 := float(f["t1"])
		_imp(t0, float(imp["fight_small"] if n2 < int(sizes[0]) else (imp["fight_mid"] if n2 < int(sizes[1]) else imp["fight_big"])))
		if n2 < int(sizes[0]):
			continue
		var cnt := {"B": 0, "R": 0}
		for k in f["keys"]:
			cnt[ArenaPlayer.side_of(String(k))] += 1
		var lead_side := "B" if int(cnt["B"]) > int(cnt["R"]) else ("R" if int(cnt["R"]) > int(cnt["B"]) else ArenaPlayer.side_of(String(f["keys"][0])))
		var place := place_at(_centre(f["keys"], t0))
		if n2 >= int(sizes[1]):
			_cand(t0, PRIO_EVENT, "p.fight.big", {"place": place}, [["fight", int(f["id"]), t0]], 5.0, "", true)
		else:
			_cand(t0, PRIO_EVENT, "p.fight.start", {"team": team(lead_side), "place": place}, [["fight", int(f["id"]), t0], ["fight_more", int(f["id"]), lead_side]], 5.0)
		var kd := {"B": 0, "R": 0}
		for k in pl.kills:
			if float(k[0]) >= t0 - 0.5 and float(k[0]) <= t1 + 0.5 and String(k[2]) in f["keys"] and not String(k[1]).begins_with("tower."):
				kd[ArenaPlayer.side_of(String(k[1]))] += 1
		var kb := int(kd["B"])
		var kr := int(kd["R"])
		if kb == 0 and kr == 0:
			continue
		if kb > 0 and kr > 0:
			_imp(t1, float(imp["close_fight"]))
		var won := "B" if kb > kr else ("R" if kr > kb else "")
		var fc := ["fight_end", int(f["id"]), won, kb, kr, t1]
		if won == "":
			_cand(t1 + 0.5, PRIO_EVENT, "p.fight.end.even", {}, [fc], 6.0)
			_cand(t1 + 3.0, PRIO_ANALYSIS, "a.after.fight.even", {}, [fc], 12.0)
		else:
			var lost := kr if won == "B" else kb
			var kind := "p.fight.end.clean" if lost == 0 else "p.fight.end.narrow"
			_cand(t1 + 0.5, PRIO_EVENT, kind, {"team": team(won)}, [fc], 6.0, won)
			var why := "a.after.fight.numbers" if int(cnt[won]) > int(cnt[other(won)]) else "a.after.fight.gold"
			var wc: Array = [fc, ["fight_more", int(f["id"]), won]] if why == "a.after.fight.numbers" else [fc, ["lead", won, 1, t1]]
			if why == "a.after.fight.gold" and (lead_b(t1) > 0) != (won == "B"):
				why = "a.after.fight.even"
				wc = [fc]
			_cand(t1 + 3.0, PRIO_ANALYSIS, why, {"team": team(won)}, wc, 12.0, won)
	# --- objectives
	for o in pl.obj_up:
		var oid := String(o[1])
		if oid in OBJ:
			_cand(float(o[0]), PRIO_ANALYSIS, "p.obj.up", {"place": place_word(oid)}, [["obj_up", oid, float(o[0])]], 8.0)
	var started := {}
	for cl in pl.calls:
		var tgt := String(cl[3])
		if String(cl[2]) == "group" and tgt in OBJ and pl.objective(tgt, float(cl[0])) == "up":
			var sk := String(cl[1]) + tgt
			if float(cl[0]) - float(started.get(sk, -INF)) > 60.0:
				started[sk] = float(cl[0])
				_cand(float(cl[0]), PRIO_EVENT - 1, "p.obj.start", {"team": team(String(cl[1])), "place": place_word(tgt)},
						[["call", String(cl[1]), tgt, float(cl[0])], ["obj_up", tgt, float(cl[0])]], 6.0, String(cl[1]))
	for o in pl.objs:
		var t := float(o[0])
		var oid := String(o[1])
		var side := String(o[2])
		if not oid in OBJ:
			continue
		_imp(t, float(imp["obj_" + oid]))
		var steal := false
		for cl in pl.calls:
			if String(cl[2]) == "group" and String(cl[3]) == oid and float(cl[0]) <= t and t - float(cl[0]) <= float(P["steal_window_s"]):
				if String(cl[1]) != side:
					steal = true
				elif String(cl[1]) == side:
					steal = false
		var oc := ["obj", oid, side, t]
		if steal:
			_imp(t, float(imp["steal"]))
			_cand(t, PRIO_EVENT + 1, "p.obj.steal", {"team": team(side), "place": place_word(oid)}, [oc], 5.0, side, true)
			_cand(t + 1.0, PRIO_EMOTION, "p.ex.peak." + _val(side), {}, [oc], 4.0, side)
		else:
			_cand(t, PRIO_EVENT, "p.obj.take", {"team": team(side), "place": place_word(oid)}, [oc], 6.0, side, true)
		_cand(t + 4.0, PRIO_ANALYSIS, "a.after.obj." + oid, {"team": team(side)}, [oc], 12.0, side)
	# --- towers, the base race and the Cairn
	var inner_falls: Array = []
	for tw in pl.towers:
		var t := float(tw[0])
		var id := String(tw[1])
		var by := String(tw[2])
		var parts := id.split(".")
		if id.ends_with("cairn"):
			_imp(t, float(imp["cairn"]))
			continue
		var tier := parts[2] if parts.size() > 2 else "outer"
		var lane := parts[1]
		var tc := ["tower", id, by, t]
		if tier == "outer":
			_imp(t, float(imp["tower_outer"]))
			_cand(t, PRIO_EVENT, "p.tower.fall", {"team": team(by), "lane": lane_word(lane)}, [tc], 6.0, by, true)
		else:
			_imp(t, float(imp["tower_inner"]))
			_base_open_g = minf(_base_open_g, t)
			inner_falls.append([t, by])
			if lane in ["top", "mid", "bot"]:
				_cand(t, PRIO_EVENT, "p.tower.inner", {"team": team(by), "lane": lane_word(lane)}, [tc], 6.0, by, true)
				_cand(t + 4.0, PRIO_ANALYSIS, "a.after.tower", {"team": team(by), "lane": lane_word(lane)}, [tc], 12.0, by)
	for i in inner_falls.size():
		for j in range(i + 1, inner_falls.size()):
			if String(inner_falls[i][1]) != String(inner_falls[j][1]) and float(inner_falls[j][0]) - float(inner_falls[i][0]) <= 40.0:
				var tb := float(inner_falls[j][0])
				_cand(tb, PRIO_EVENT + 1, "p.base.race", {}, [["base_race", float(inner_falls[i][0]), tb]], 6.0, "", true)
				break
	# --- gold: lead flips, comebacks, swings, the lanes
	var state := ""
	var worst := {"B": 0, "R": 0}          # the biggest deficit each side has had
	var last_swing := -INF
	var g := 10.0
	while g < pl.end_t:
		var l := lead_b(g)
		worst["B"] = maxi(int(worst["B"]), -l)
		worst["R"] = maxi(int(worst["R"]), l)
		var now := "B" if l >= int(P["lead_flip_gold"]) else ("R" if l <= -int(P["lead_flip_gold"]) else "")
		if now != "" and state != "" and now != state:
			if int(worst[now]) >= int(P["comeback_gold"]):
				_imp(g, float(imp["comeback"]))
				_cand(g, PRIO_EVENT, "p.comeback", {"team": team(now)}, [["lead", now, int(P["lead_flip_gold"]), g], ["was_behind", now, int(P["comeback_gold"]), g]], 8.0, now, true)
			else:
				_imp(g, float(imp["lead_flip"]))
				_cand(g, PRIO_EVENT, "p.lead.flip", {"team": team(now)}, [["lead", now, int(P["lead_flip_gold"]), g], ["led_before", other(now), int(P["lead_flip_gold"]), g]], 8.0, now, true)
			_cand(g + 4.0, PRIO_ANALYSIS, "a.after.flip", {"team": team(now)}, [["lead", now, 1, g]], 12.0, now)
		if now != "":
			state = now
		if g >= float(P["swing_window_s"]):
			var dl := l - lead_b(g - float(P["swing_window_s"]))
			if absi(dl) >= int(P["swing_gold"]) and g - last_swing > 60.0:
				last_swing = g
				var gainer := "B" if dl > 0 else "R"
				_imp(g, minf(float(imp["swing_max"]), float(imp["swing_per_1000"]) * float(absi(dl)) / 1000.0))
				var amt := int(roundf(float(absi(dl)) / 100.0)) * 100
				_cand(g, PRIO_EVENT - 1, "p.gold.swing", {"team": team(gainer), "gold": ArenaHud2.grouped(amt)}, [["swing", gainer, amt, g]], 6.0, gainer)
		g += 5.0
	for lc in P["lanes_check_s"]:
		var gl := float(lc)
		if gl < pl.end_t - 30.0:
			var l2 := lead_b(gl)
			if absi(l2) >= int(P["lanes_lead_gold"]):
				var s2 := "B" if l2 > 0 else "R"
				_cand(gl, PRIO_ANALYSIS, "a.lanes.lead", {"team": team(s2), "gold": gold_text(l2)}, [["gold_value", s2, absi(l2), gl]], 20.0, s2)
			else:
				_cand(gl, PRIO_ANALYSIS, "a.lanes.even", {}, [["even", int(P["lanes_lead_gold"]), gl]], 20.0)
	# --- the log's other events: buys (power spikes), recalls, ganks, wards, plan switches
	var spike_at := {}
	var recall_at := -INF
	var gank_at := -INF
	var ward_at := {}
	for e in pl.log["ev"]:
		var t := float(e[0])
		match String(e[1]):
			"buy":
				var key := String(e[2])
				var it := SimData.item(String(e[3]))
				if not it.is_empty() and String(it.get("tier", "")) in P["spike_tiers"] and t - float(spike_at.get(key, -INF)) > 180.0:
					spike_at[key] = t
					var bc := ["buy", key, String(e[3]), t]
					_cand(t, PRIO_ANALYSIS, "p.spike", {"hero": hero(key), "item": String(it["name"])}, [bc], 10.0, ArenaPlayer.side_of(key))
			"recall":
				if t - recall_at > 90.0:
					recall_at = t
					_cand(t, PRIO_FILLER, "p.recall", {"hero": hero(String(e[2]))}, [["recall", String(e[2]), t]], 8.0)
			"intent":
				if String(e[3]) == "gank" and String(e[2]).ends_with(".jg") and t - gank_at > float(P["gank_gap_s"]):
					gank_at = t
					_cand(t, PRIO_EVENT - 1, "p.gank", {"hero": hero(String(e[2])), "lane": lane_word(String(e[4]))}, [["intent", String(e[2]), "gank", String(e[4]), t]], 5.0, ArenaPlayer.side_of(String(e[2])))
			"ward":
				var ws := ArenaPlayer.side_of(String(e[2]))
				if t - float(ward_at.get(ws, -INF)) > 150.0 and e.size() > 4 and e[4] is Array:
					ward_at[ws] = t
					var wp := Vector2(float(e[4][0]), float(e[4][1]))
					_cand(t, PRIO_FILLER, "p.ward", {"team": team(ws), "place": place_at(wp)}, [["ward", String(e[2]), t]], 6.0, ws)
			"plan":
				_cand(t, PRIO_ANALYSIS, "a.plan.switch", {"team": team(String(e[2]))}, [["plan", String(e[2]), t]], 10.0, String(e[2]))


func _val(side: String) -> String:
	if side == "":
		return "neutral"
	return "good" if side == pl.my_side else "bad"


# ---------------------------------------------------------------- excitement and tiers
func _excitement() -> void:
	var P := params()
	var dt := float(P["grid_s"])
	var n := int(ceilf(pl.show_len / dt)) + 2
	e_grid.resize(n)
	aftermath.resize(n)
	var att := float(P["attack_s"])
	var hl := float(P["half_life_s"])
	var floor_s := pl.show_t(_base_open_g) if _base_open_g < INF else INF
	for i in n:
		var s := float(i) * dt
		var v := 0.0
		for im in _impulses:
			var d := s - float(im[0])
			if d < 0.0 or d > hl * 6.0:
				continue
			var rise := minf(1.0, d / att)
			v += float(im[1]) * rise * pow(0.5, maxf(0.0, d - att) / hl)
		if s >= floor_s:
			v = maxf(v, float(P["base_open_floor"]))
		e_grid[i] = minf(1.0, v)
	# aftermath: after e reached the peak line, while it falls below the hot line, for at most max_s
	var am: Dictionary = P["aftermath"]
	var peak_seen := -INF
	for i in n:
		var s := float(i) * dt
		if e_grid[i] >= float(am["from_e"]):
			peak_seen = s
		aftermath[i] = 1 if (e_grid[i] < float(am["below_e"]) and s - peak_seen <= float(am["max_s"])) else 0


func e_at(s: float) -> float:
	var i := clampi(int(s / float(params()["grid_s"])), 0, e_grid.size() - 1)
	return e_grid[i] if not e_grid.is_empty() else 0.0


func tier_at(s: float) -> String:
	var t: Dictionary = params()["tiers"]
	var i := clampi(int(s / float(params()["grid_s"])), 0, maxi(0, aftermath.size() - 1))
	if not aftermath.is_empty() and aftermath[i] == 1:
		return "aftermath"
	var e := e_at(s)
	if e >= float(t["peak"]):
		return "peak"
	if e >= float(t["hot"]):
		return "hot"
	if e >= float(t["building"]):
		return "building"
	return "calm"


# ---------------------------------------------------------------- intro
func _intro() -> void:
	var b := team("B")
	var r := team("R")
	_intro_add("p.intro.welcome", {"team": b, "team2": r}, [])
	if bool(opts.get("tutorial", false)):
		return
	_intro_add("a.intro.welcome", {"team": b, "team2": r}, [])
	for lane in ["top", "mid", "bot"]:
		_intro_add("p.intro.lane", {"lane": lane_word(lane), "hero": hero("B." + lane), "hero2": hero("R." + lane)}, [["draft", "B." + lane], ["draft", "R." + lane]])
	# a signature pick: the hero of either side whose power peaks highest (static hero data), side chosen by the hash
	var side := "B" if _hash("pick") % 2 == 0 else "R"
	var best := ""
	var bv := -INF
	for s in SLOTS:
		var h: Dictionary = SimData.heroes()[pl.hero_of[side + "." + s]]
		var v := maxf(float(h.get("power_early", 50)), maxf(float(h.get("power_mid", 50)), float(h.get("power_late", 50))))
		if v > bv:
			bv = v
			best = s
	_intro_add("a.intro.pick", {"team": team(side), "hero": hero(side + "." + best), "lane": lane_word(best)}, [["draft", side + "." + best]])
	# a lane matchup from hero_matchups_v1.json (Q2d): a hero facing one it finds harder
	for s in SLOTS:
		for sd in ["B", "R"]:
			var x := pl.hero_of[sd + "." + s] as String
			var y := pl.hero_of[other(sd) + "." + s] as String
			if _struggles(x, y):
				_intro_add("a.intro.matchup", {"hero": hero(sd + "." + s), "hero2": hero(other(sd) + "." + s)}, [["matchup", x, y]])
				_intro_scaling()
				return
	_intro_scaling()


static func _struggles(x: String, y: String) -> bool:
	for row in HeroMatchups.struggles(x):
		if String((row as Dictionary).get("vs", "")) == y:
			return true
	return false


func _intro_scaling() -> void:
	var lean := {}
	for sd in ["B", "R"]:
		var v := 0.0
		for s in SLOTS:
			var h: Dictionary = SimData.heroes()[pl.hero_of[sd + "." + s]]
			v += float(h.get("power_late", 50)) - float(h.get("power_early", 50))
		lean[sd] = v / 5.0
	var late := "B" if float(lean["B"]) >= float(lean["R"]) else "R"
	if absf(float(lean["B"]) - float(lean["R"])) >= 2.0:
		_intro_add("a.intro.late", {"team": team(late)}, [["late_lean", late]])
		_intro_add("a.intro.early", {"team": team(other(late))}, [["late_lean", late]])


func _intro_add(key: String, vars: Dictionary, claims: Array) -> void:
	var tx := _text(key, vars, 0.0 - float(intro.size()))
	if tx == "":
		return
	intro.append({"voice": key.substr(0, 1), "key": key, "text": tx, "claims": claims, "tier": "calm"})


# ---------------------------------------------------------------- scheduling (show time)
func _schedule() -> void:
	var P := params()
	_cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["s"]) < float(b["s"]))
	var s := 0.0
	var end_s := pl.show_t(pl.end_t)
	var guard := 0
	while s < end_s - 1.0 and guard < 4000:
		guard += 1
		var c := _best(s)
		if not c.is_empty():
			if _emit(s, c):
				s = float(lines[-1]["s1_min"])
				continue
			c["used"] = true
			continue
		# nothing due now: the next due moment, or a fill line when the gap is long
		var nx := INF
		for x in _cands:
			if not bool(x["used"]) and float(x["s"]) > s:
				nx = float(x["s"])
				break
		var tier := tier_at(s)
		var hold := float(P["hold_s"])
		var shown_until := s + (hold if not lines.is_empty() else 0.0)
		if nx <= shown_until + float(P["silence_s"][tier]) * 0.5:
			s = minf(nx, end_s)
			continue
		var fs := shown_until
		var f := _filler(fs, minf(nx, end_s) - fs)
		if f.is_empty():
			s = minf(nx, fs + float(P["silence_s"][tier]))
			continue
		if not _emit(fs, f):
			s = fs + 0.5
		else:
			s = float(lines[-1]["s1_min"])
	# each line stays on screen until the next one starts, at most hold_s after its minimum time
	for i in lines.size():
		var l: Dictionary = lines[i]
		var until := float(l["s1_min"]) + float(P["hold_s"])
		if i + 1 < lines.size():
			until = minf(until, float(lines[i + 1]["s0"]))
		l["s1"] = maxf(float(l["s1_min"]), until)


## The best candidate due at s (not stale), or {}.
func _best(s: float) -> Dictionary:
	var best := {}
	for c in _cands:
		if bool(c["used"]) or float(c["s"]) > s:
			continue
		if s - float(c["s"]) > float(c["stale"]):
			c["used"] = true
			continue
		if best.is_empty() or int(c["prio"]) > int(best["prio"]) or (int(c["prio"]) == int(best["prio"]) and float(c["s"]) > float(best["s"])):
			best = c
	# turn taking: after three play-by-play lines in a row, a due analyst line goes first
	if not best.is_empty() and String(best["key"]).begins_with("p.") and _p_run() >= 3:
		for c in _cands:
			if not bool(c["used"]) and float(c["s"]) <= s and String(c["key"]).begins_with("a.") and s - float(c["s"]) <= float(c["stale"]):
				return c
	return best


## How many play-by-play lines in a row ended the list.
func _p_run() -> int:
	var n := 0
	for i in range(lines.size() - 1, -1, -1):
		if String(lines[i]["voice"]) != "p":
			break
		n += 1
	return n


## A fill line for show time s that fits in `room` seconds before the next moment, or {}.
func _filler(s: float, room: float) -> Dictionary:
	var g := pl.game_t(s)
	var tier := tier_at(s)
	var opts_: Array = []
	# a fill line must not hold up the next moment: hot and peak bursts need about 2 s, the rest about 3.5 s
	if room < (2.0 if tier == "hot" or tier == "peak" else 3.5):
		return {}
	if tier == "hot" or tier == "peak":
		# a reaction to the latest moment with a side (within 10 s): awe or a groan for the club you manage, else neutral
		var val := "neutral"
		for i in range(lines.size() - 1, -1, -1):
			if s - float(lines[i]["s0"]) > 10.0:
				break
			if String(lines[i]["side"]) != "":
				val = _val(String(lines[i]["side"]))
				break
		opts_.append(["p.ex.%s.%s" % [tier, val], {}, [], PRIO_EMOTION])
	else:
		var l := lead_b(g)
		var P := params()
		if g >= _base_open_g:
			opts_.append(["p.late.tension", {}, [["base_open", _base_open_g, g]], PRIO_FILLER])
			opts_.append(["a.late.tension", {}, [["base_open", _base_open_g, g]], PRIO_FILLER])
		if g < 120.0:
			pass    # no gold talk in the first two minutes: there is nothing to read yet
		elif absi(l) >= int(P["gold_lead_gold"]):
			var sd := "B" if l > 0 else "R"
			opts_.append(["a.gold.lead", {"team": team(sd), "gold": gold_text(l)}, [["gold_value", sd, absi(l), g]], PRIO_ANALYSIS])
		else:
			opts_.append(["a.gold.even", {}, [["even", int(P["gold_lead_gold"]), g]], PRIO_ANALYSIS])
		var sd2 := "B" if _hash("plan%d" % int(s)) % 2 == 0 else "R"
		opts_.append(["a.plan.read", {"team": team(sd2)}, [], PRIO_FILLER])
		opts_.append(["a.comp.read", {"team": team(other(sd2))}, [], PRIO_FILLER])
		opts_.append(["p.calm.scene", {"team": team("B"), "team2": team("R")}, [], PRIO_FILLER])
		if g < 600.0:
			var ln: String = ["top", "mid", "bot"][_hash("farm%d" % int(s)) % 3]
			opts_.append(["p.calm.farm", {"lane": lane_word(ln)}, [], PRIO_FILLER])
		opts_.append(["a.calm.filler", {}, [], PRIO_FILLER])
	# rotate through the options, preferring the other voice than the last line
	var n := opts_.size()
	for k in n:
		var o: Array = opts_[(_filler_turn + k) % n]
		var voice := String(o[0]).substr(0, 1)
		if voice == _last_voice and k < n - 1 and n > 1 and not (tier == "hot" or tier == "peak"):
			continue
		_filler_turn += 1
		var c := {"g": g, "s": s, "prio": int(o[3]), "key": o[0], "vars": o[1], "claims": o[2], "stale": 1.0, "side": "",
				"keyline": false, "used": false, "room": room}
		return c
	return {}


## Places the line at s if a variant passes the repeat and first-word rules. Returns false if none does.
func _emit(s: float, c: Dictionary) -> bool:
	var P := params()
	var key := String(c["key"])
	var text := _text(key, c["vars"], s)
	if text == "":
		return false
	c["used"] = true
	var w := words(text)
	var dur := maxf(float(P["min_show_s"]), float(P["per_word_s"]) * float(w))
	var line := {"s0": s, "s1_min": s + dur, "s1": s + dur, "g": pl.game_t(s), "voice": key.substr(0, 1),
			"tier": String(KEY_TIER.get(key, "calm")), "key": key, "text": text, "claims": c["claims"], "prio": int(c["prio"]),
			"keyline": bool(c["keyline"]), "side": String(c["side"])}
	lines.append(line)
	_recent.append([s, text])
	_last_first = text.split(" ", false)[0].to_lower() if w > 0 else ""
	_last_voice = String(line["voice"])
	if on_line.is_valid():
		on_line.call(line)
	return true


func _hash(tag: String) -> int:
	return absi(Pcg32.fnv1a64("%s|%s" % [game_id, tag]))


## A variant of `key` for time s that is not on the recent list and does not start with the last first word; "" if none.
func _text(key: String, vars: Dictionary, s: float) -> String:
	var n := variants(key)
	if n == 0:
		return ""
	var start := _hash("%s|%d" % [key, int(s * 10.0)]) % n
	var rep := float(params()["repeat_s"])
	for i in n:
		var tx := Strings.f("arena.cast.%s.%d" % [key, (start + i) % n + 1], vars)
		var first := tx.split(" ", false)[0].to_lower() if words(tx) > 0 else ""
		if first == _last_first:
			continue
		var seen := false
		for r in _recent:
			if s - float(r[0]) <= rep and String(r[1]) == tx:
				seen = true
				break
		if not seen:
			return tx
	return ""


# ---------------------------------------------------------------- the end
func _end() -> void:
	var won := pl.winner
	var g := pl.end_t
	var ec := ["end", won, g]
	var tx := _text("p.final.blow", {"team": team(won)}, pl.show_len + 1.0)
	if tx != "":
		end_lines.append({"voice": "p", "key": "p.final.blow", "text": tx, "claims": [ec], "tier": "peak", "g": g})
	var close := absi(lead_b(g)) < int(params()["close_end_gold"])
	var key := "a.wrap.close" if close else "a.wrap.win"
	var tx2 := _text(key, {"team": team(won)}, pl.show_len + 3.0)
	if tx2 != "":
		end_lines.append({"voice": "a", "key": key, "text": tx2, "claims": [ec] + ([["close", int(params()["close_end_gold"]), g]] if close else []), "tier": "aftermath", "g": g})


# ---------------------------------------------------------------- reading
## The line on screen at show time s, or {}. Above x1 only key lines show (`speed` > 1).
func line_at(s: float, speed: float = 1.0) -> Dictionary:
	for i in range(lines.size() - 1, -1, -1):
		var l: Dictionary = lines[i]
		if float(l["s0"]) <= s:
			if s <= float(l["s1"]) and (speed <= 1.0 or bool(l["keyline"])):
				return l
			return {}
	return {}


## Plain text of the whole broadcast with show time, game clock, voice and tier (tools/dump_broadcast).
func transcript() -> String:
	var out: Array = []
	var nm := {"p": Strings.t("arena.cast.name.p"), "a": Strings.t("arena.cast.name.a")}
	for l in intro:
		out.append("  intro      [%-9s] %s: %s" % [l["tier"], nm[l["voice"]], l["text"]])
	for l in lines:
		out.append("%6.1f %s [%-9s] e=%.2f %s: %s" % [float(l["s0"]), ArenaHud2.mmss(float(l["g"])), l["tier"], e_at(float(l["s0"])), nm[l["voice"]], l["text"]])
	for l in end_lines:
		out.append("   end %s [%-9s] %s: %s" % [ArenaHud2.mmss(float(l["g"])), l["tier"], nm[l["voice"]], l["text"]])
	return "\n".join(out)
