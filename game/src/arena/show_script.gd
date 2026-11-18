class_name ShowScript
extends RefCounted
## The show script of the live arena (Alpha 0.8 A-01, ACTION-VOCABULARY sections 1 to 6). Built ONCE from a finished result before
## the first frame; playback only reads it. It never calls MatchSim, GamePlan.simulate or Report.attribution and never writes `res`
## (rule A1); its only randomness is the `show` stream family seeded from res.mseed (A2), so the same result is the same show (A3).
##   contests   per contest: c, noise z, the edge going in x (F1), size word (F2), winner side, resolve time
##   ladder     the lead ladder L_k (F4, Blue's view; L_8 = final), flips (F5), the arc (F6), upsets (2.4)
##   towers     T per side (F8, with the ordering repair), each tower placed on a beat with an id, a lane, a tier and a time (F9)
##   kills      K per side = Report.kda team kills (F10), placed on nine beats (F11, the fight rule), then paired event by event
##              (P1 to P4: time, killer slot, victim slot) so per-hero kills and deaths equal Report.kda
##   objectives Stoneback and Moonhulk to the signs of obj_mid and obj_late (F12); the Cairn falls at 74.0 s (F13)
##   score_at(t) the scoreboard as a pure function of show time: clock, kills, towers, objectives, gold lead (F7)
## Sides are "B" (Blue = simulator team A) and "R". s_X = +1 for Blue, -1 for Red.

const WATCH := 75.0
const ORDER := ["top", "mid_lane", "bot", "jungle", "obj_mid", "fight_mid", "obj_late", "fight_late"]
const KILL_BEATS := ["top", "mid_lane", "bot", "jungle", "obj_mid", "fight_mid", "obj_late", "fight_late", "base_push"]
const RESOLVE := {"top": 13.5, "mid_lane": 15.75, "bot": 18.0, "jungle": 20.25, "obj_mid": 33.75, "fight_mid": 45.0,
		"obj_late": 60.0, "fight_late": 71.25, "base_push": 74.0}
const KILL_WINDOW := {"top": [8.0, 13.5], "mid_lane": [9.5, 15.75], "bot": [11.0, 18.0], "jungle": [13.0, 20.25],
		"obj_mid": [31.5, 33.75], "fight_mid": [41.2, 45.0], "obj_late": [57.0, 60.0], "fight_late": [66.0, 71.25], "base_push": [71.5, 74.0]}
const KP := {"top": 0.6, "mid_lane": 0.6, "bot": 0.9, "jungle": 0.7, "obj_mid": 1.0, "fight_mid": 3.0, "obj_late": 1.2, "fight_late": 4.0, "base_push": 0.5}
const FRONT_G := {"narrow": 1.0, "clear": 0.8, "decisive": 0.6}
const LANE_OF := {"top": "top", "mid_lane": "mid", "bot": "bot"}         # sim contest -> map lane id
const BEAT_SLOTS := {"top": ["top"], "mid_lane": ["mid"], "bot": ["bot", "sup"], "jungle": ["jg"]}
const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const TOWER_BREAK := {"top": 25.0, "mid_lane": 26.5, "bot": 28.0}
const FIGHT_PAYOFF_END := {"fight_mid": 51.0, "fight_late": 73.8}
const REPAIR_T := 73.0
const CAIRN_T := 74.0
const GUARD_T := [72.0, 72.4]
const FLIP_BAND := 0.03

var res: Dictionary
var my_side := "B"
var winner := "B"              # the game winner W
var fw: Dictionary = {}
var contests: Dictionary = {}   # key -> {c, z, x, size, win ("B"/"R"), t}
var ladder: Array = []          # L_k after each of the 8 contests (Blue's view)
var flips: Array = []           # [{beat, to}] where the lead state changed side (F5)
var arc := "steady"             # close | comeback | stomp | steady
var upsets: Array = []          # beats where the edge going in (x) lost: [{beat, side}] (side = the winner of the upset)
var pressure: Dictionary = {}   # P_X
var tower_count: Dictionary = {}
var towers: Array = []          # [{side (who destroyed it), id, lane, tier, beat, t}]
var kill_count: Dictionary = {}
var kills_per_beat: Dictionary = {}   # side -> {beat: n}
var kill_events: Array = []     # [{t, beat, side (killer), killer, victim}] sorted by t; killer/victim are slots
var objectives: Dictionary = {}       # {"stoneback": side, "moonhulk": side}
var plan_used: Dictionary = {}        # {"B": id, "R": id}
var held := false                     # the game winner lost fight_late (the held fight, I9)
var initiators: Dictionary = {}       # beat -> side that starts it (staging only)
var kda: Dictionary = {}
var minutes := 12.0


static func sgn(side: String) -> float:
	return 1.0 if side == "B" else -1.0


static func other(side: String) -> String:
	return "R" if side == "B" else "B"


static func ease01(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Hamilton's method: `n` units over `weights` (floors first, the rest to the largest fractional parts, ties to the earlier index).
static func hamilton(n: int, weights: Array) -> Array:
	var out: Array = []
	for i in weights.size():
		out.append(0)
	if n <= 0 or weights.is_empty():
		return out
	var total := 0.0
	for w in weights:
		total += maxf(0.0, float(w))
	if total <= 0.0:
		out[0] = n
		return out
	var rest: Array = []
	var given := 0
	for i in weights.size():
		var q := float(n) * maxf(0.0, float(weights[i])) / total
		out[i] = int(floor(q))
		given += int(out[i])
		rest.append([q - floor(q), i])
	rest.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (is_equal_approx(a[0], b[0]) and a[1] < b[1]))
	for k in n - given:
		out[int(rest[k % rest.size()][1])] += 1
	return out


static func build(p_res: Dictionary, p_my_side: String) -> ShowScript:
	var s := ShowScript.new()
	s.res = p_res
	s.my_side = p_my_side
	s._build()
	return s


func _build() -> void:
	var sim: Dictionary = res["sim"]
	winner = "B" if bool(res["blue_won"]) else "R"
	fw = (GamePlan.data()["final_weights"] as Dictionary).duplicate()
	plan_used = (sim.get("plan_used", {"B": "default", "R": "default"}) as Dictionary).duplicate()
	minutes = Report.game_minutes(res)
	kda = Report.kda(res)
	var lead := 0.0
	for k in ORDER:
		var c := float(sim["contests"][k])
		var z := float((sim.get("noise", {}) as Dictionary).get(k, 0.0))
		var x := atanh(clampf(c, -(1.0 - 1e-9), 1.0 - 1e-9)) - z
		contests[k] = {"c": c, "z": z, "x": x, "size": Report.margin_word(c), "win": "B" if c > 0.0 else "R", "t": float(RESOLVE[k])}
		lead += float(fw[k]) * c
		ladder.append(lead)
		if absf(x) >= 0.8 and signf(x) != signf(c):
			upsets.append({"beat": k, "side": contests[k]["win"]})
	_flips_and_arc()
	held = String(contests["fight_late"]["win"]) != winner
	objectives = {"stoneback": contests["obj_mid"]["win"], "moonhulk": contests["obj_late"]["win"]}
	var rng := Pcg32.contest_stream(int(res["mseed"]), "show")
	_initiators(rng)
	_towers()
	_kills()


func _flips_and_arc() -> void:
	var sw := sgn(winner)
	var state := 0
	var lowest := 0.0
	for i in ORDER.size():
		var l := sw * float(ladder[i])
		lowest = minf(lowest, l)
		var nstate := state
		if l >= FLIP_BAND:
			nstate = 1
		elif l <= -FLIP_BAND:
			nstate = -1
		if nstate != state and state != 0:
			flips.append({"beat": ORDER[i], "to": winner if nstate > 0 else other(winner)})
		state = nstate
	var word := Report.result_word(float(res["final"]))
	if word == "narrow":
		arc = "close"
	elif lowest <= -0.12:
		arc = "comeback"
	elif flips.is_empty() and lowest >= -FLIP_BAND and word == "decisive":
		arc = "stomp"
	else:
		arc = "steady"


## The plan a side played after the plan check (the default, or the trigger plan that fired).
func chosen_plan(side: String) -> Dictionary:
	var sets: Dictionary = res.get("plans", {})
	var ps = sets.get(side, null)
	if not (ps is Dictionary):
		return GamePlan.neutral()
	var used := String(plan_used.get(side, "default"))
	if used != "default":
		for t in ps.get("triggers", []):
			if String(t["when"]) == used:
				return t["plan"]
	return ps.get("default", GamePlan.neutral())


## Who starts each objective and fight (staging only, 2.3): plan, then style, then a coin of the `show` stream.
func _initiators(rng: Pcg32) -> void:
	var style: Dictionary = res.get("style", {})
	for pair in [["obj_mid", "m"], ["obj_late", "l"]]:
		var key: String = pair[1]
		var bm := int(chosen_plan("B").get(key, 0)) > 0
		var rm := int(chosen_plan("R").get(key, 0)) > 0
		var coin := rng.next_float() < 0.5
		if bm != rm:
			initiators[pair[0]] = "B" if bm else "R"
		elif (String(style.get("B", "")) == "dive") != (String(style.get("R", "")) == "dive"):
			initiators[pair[0]] = "B" if String(style.get("B", "")) == "dive" else "R"
		else:
			initiators[pair[0]] = "B" if coin else "R"
	for f in ["fight_mid", "fight_late"]:
		var coin2 := rng.next_float() < 0.5
		var bd := String(style.get("B", "")) == "dive"
		var rd := String(style.get("R", "")) == "dive"
		var bg := int(chosen_plan("B").get("g", 0))
		var rg := int(chosen_plan("R").get("g", 0))
		if bd != rd:
			initiators[f] = "B" if bd else "R"
		elif bg != rg:
			initiators[f] = "B" if bg > rg else "R"
		else:
			initiators[f] = "B" if coin2 else "R"


# ---- towers (F8, F9) -----------------------------------------------------------------------------------------------------------

func _towers() -> void:
	for side in ["B", "R"]:
		var p := 0.0
		for k in ORDER:
			p += float(fw[k]) * maxf(0.0, sgn(side) * float(contests[k]["c"]))
		pressure[side] = p
		tower_count[side] = mini(6, int(round(8.0 * p)))
	var w := winner
	var u := other(winner)
	var repair := {"B": 0, "R": 0}
	if int(tower_count[w]) <= int(tower_count[u]):
		tower_count[w] = int(tower_count[u]) + 1
		repair[w] = 1
		if int(tower_count[w]) > 6:
			tower_count[w] = 6
			tower_count[u] = 5
	for side in ["B", "R"]:
		var s := sgn(side)
		var owner := other(side)
		var down := {"top": 0, "mid": 0, "bot": 0}    # tiers already fallen per lane of the owner
		var weights: Array = []
		for k in ORDER:
			weights.append(0.0 if k == "jungle" else float(fw[k]) * maxf(0.0, s * float(contests[k]["c"])))
		var n := int(tower_count[side]) - int(repair[side])
		var per := hamilton(n, weights)
		# the lanes in X's lane-margin order (descending), rotating as towers fall
		var lane_order: Array = ["top", "mid_lane", "bot"]
		lane_order.sort_custom(func(a: String, b: String) -> bool: return s * float(contests[a]["c"]) > s * float(contests[b]["c"]))
		for i in ORDER.size():
			var k: String = ORDER[i]
			var cnt := int(per[i])
			if cnt == 0:
				continue
			var times := _tower_times(k, cnt)
			for j in cnt:
				var lane := ""
				if LANE_OF.has(k) and int(down[LANE_OF[k]]) < 2:
					lane = LANE_OF[k]
				else:
					for lk in lane_order:
						if int(down[LANE_OF[lk]]) < 2:
							lane = LANE_OF[lk]
							break
				if lane == "":
					continue
				var tier := "outer" if int(down[lane]) == 0 else "inner"
				down[lane] = int(down[lane]) + 1
				towers.append({"side": side, "id": "%s.%s.%s" % [owner, lane, tier], "lane": lane, "tier": tier, "beat": k, "t": float(times[j])})
				# the lane goes to the back of the order
				for lk in lane_order:
					if LANE_OF[lk] == lane:
						lane_order.erase(lk)
						lane_order.append(lk)
						break
		if int(repair[side]) > 0:
			for lane in ["top", "mid", "bot"]:
				if int(down[lane]) < 2:
					var tier2 := "outer" if int(down[lane]) == 0 else "inner"
					down[lane] = int(down[lane]) + 1
					towers.append({"side": side, "id": "%s.%s.%s" % [owner, lane, tier2], "lane": lane, "tier": tier2, "beat": "close_push", "t": REPAIR_T, "repair": true})
					break
	towers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


func _tower_times(k: String, n: int) -> Array:
	var out: Array = []
	if TOWER_BREAK.has(k):
		for j in n:
			out.append(float(TOWER_BREAK[k]) + 0.4 * float(j))
	elif k == "obj_mid" or k == "obj_late":
		for j in n:
			out.append(float(RESOLVE[k]) + 2.0 + 1.2 * float(j))
	else:
		var a := float(RESOLVE[k]) + 1.0
		var b := float(FIGHT_PAYOFF_END[k])
		for j in n:
			out.append(a + (b - a) * float(j + 1) / float(n + 1))
	return out


# ---- kills (F10, F11, P1 to P4) -------------------------------------------------------------------------------------------------

func _kills() -> void:
	var w := winner
	for side in ["B", "R"]:
		kill_count[side] = int(kda["team"][side]["k"])
		var s := sgn(side)
		var weights: Array = []
		for k in KILL_BEATS:
			var m := (0.5 if side == w else -0.5) if k == "base_push" else s * float(contests[k]["c"])
			weights.append(float(KP[k]) * (1.0 + 0.8 * m))
		var per := hamilton(int(kill_count[side]), weights)
		var d := {}
		for i in KILL_BEATS.size():
			d[KILL_BEATS[i]] = int(per[i])
		kills_per_beat[side] = d
	_fight_rule()
	_pair()


## In both fights the fight's winner has at least as many kills as its loser (F11).
func _fight_rule() -> void:
	for f in ["fight_mid", "fight_late"]:
		var fwin := String(contests[f]["win"])
		var flose := other(fwin)
		var guard := 0
		while int(kills_per_beat[fwin][f]) < int(kills_per_beat[flose][f]) and guard < 40:
			guard += 1
			var best := ""
			for k in KILL_BEATS:
				if k == "fight_mid" or k == "fight_late":
					continue
				if int(kills_per_beat[fwin][k]) > 0 and (best == "" or int(kills_per_beat[fwin][k]) > int(kills_per_beat[fwin][best])):
					best = k
			if best != "":
				kills_per_beat[fwin][best] = int(kills_per_beat[fwin][best]) - 1
				kills_per_beat[fwin][f] = int(kills_per_beat[fwin][f]) + 1
			else:
				var to := "base_push" if f == "fight_late" else "obj_mid"
				kills_per_beat[flose][f] = int(kills_per_beat[flose][f]) - 1
				kills_per_beat[flose][to] = int(kills_per_beat[flose][to]) + 1


## Event times inside each beat's window (front-loaded by size), then killer and victim per event from the ledger's counts.
func _pair() -> void:
	var timing := Pcg32.contest_stream(int(res["mseed"]), "show:timing")
	var pair := Pcg32.contest_stream(int(res["mseed"]), "show:pair")
	var left_k := {}
	var left_d := {}
	for side in ["B", "R"]:
		left_k[side] = {}
		left_d[side] = {}
		for s in SLOTS:
			left_k[side][s] = int(kda[side][s]["k"])
			left_d[side][s] = int(kda[side][s]["d"])
	var last_death := {"B": {}, "R": {}}
	for k in KILL_BEATS:
		var win: Array = KILL_WINDOW[k]
		var size := "clear" if k == "base_push" else String(contests[k]["size"])
		var g := float(FRONT_G[size])
		var slots: Array = []
		for side in ["B", "R"]:
			for j in int(kills_per_beat[side][k]):
				slots.append(side)
		var n := slots.size()
		if n == 0:
			continue
		var u := timing.next_float()
		var times: Array = []
		for j in n:
			times.append(float(win[0]) + (float(win[1]) - float(win[0])) * pow((float(j) + u) / float(n), g))
		times.sort()
		for i in range(n - 1, 0, -1):    # Fisher-Yates: which side takes which time slot
			var r := int(timing.next_float() * float(i + 1)) % (i + 1)
			var tmp: String = slots[i]
			slots[i] = slots[r]
			slots[r] = tmp
		var died_here := {"B": {}, "R": {}}
		for j in n:
			var side: String = slots[j]
			var foe := other(side)
			var t := float(times[j])
			var killer := _pick(left_k[side], BEAT_SLOTS.get(k, []), pair, {}, -1.0, {})
			var victim := _pick(left_d[foe], BEAT_SLOTS.get(k, []), pair, last_death[foe], t, died_here[foe])
			left_k[side][killer] = int(left_k[side][killer]) - 1
			left_d[foe][victim] = int(left_d[foe][victim]) - 1
			last_death[foe][victim] = t
			died_here[foe][victim] = int(died_here[foe].get(victim, 0)) + 1
			kill_events.append({"t": t, "beat": k, "side": side, "killer": killer, "victim": victim})
	kill_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


## A slot with counts left: the beat's own slots first, weighted by what is left (P2); a victim who died under 2 s ago or twice in
## this beat is avoided while another has deaths left (P3).
func _pick(left: Dictionary, prefer: Array, rng: Pcg32, recent: Dictionary, t: float, here: Dictionary) -> String:
	var pools: Array = []
	if not prefer.is_empty():
		pools.append(prefer)
	pools.append(SLOTS)
	for pool in pools:
		for strict in [true, false]:
			var cands: Array = []
			var wsum := 0.0
			for s in pool:
				var n := int(left[s])
				if n <= 0:
					continue
				if strict and t >= 0.0 and ((recent.has(s) and t - float(recent[s]) < 2.0) or int(here.get(s, 0)) >= 2):
					continue
				cands.append(s)
				wsum += float(n)
			if cands.is_empty():
				continue
			var r := rng.next_float() * wsum
			for s in cands:
				r -= float(left[s])
				if r <= 0.0:
					return s
			return cands[cands.size() - 1]
	return "top"    # unreachable while kills and deaths add up (P4)


# ---- the scoreboard as a function of show time --------------------------------------------------------------------------------

## Gold lead for `side` at show time t (F7): the ladder in gold, each step eased over the 2 s after its resolve; sign guard at 75.
func gold_at(t: float, side: String) -> int:
	var s := sgn(side)
	var prev := 0.0
	var g := 0.0
	for i in ORDER.size():
		var k: String = ORDER[i]
		var tgt: float = 100.0 * roundf(200.0 * s * float(ladder[i]))
		var rt := float(RESOLVE[k])
		if t >= rt + 2.0:
			g = tgt
		elif t > rt:
			g = prev + (tgt - prev) * ease01((t - rt) / 2.0)
		prev = tgt
		if t < rt:
			break
	if t >= WATCH - 1e-6 and int(round(g)) == 0 and float(res["final"]) != 0.0:
		g = 100.0 if side == winner else -100.0
	return int(round(g))


## The game clock in seconds at show time t (the scoreboard's clock reads like the report's stamps).
func clock_at(t: float) -> float:
	return clampf(t, 0.0, WATCH) / WATCH * minutes * 60.0


func score_at(t: float) -> Dictionary:
	var k := {"B": 0, "R": 0}
	for e in kill_events:
		if float(e["t"]) <= t:
			k[e["side"]] = int(k[e["side"]]) + 1
	var tw := {"B": 0, "R": 0}
	for e in towers:
		if float(e["t"]) <= t:
			tw[e["side"]] = int(tw[e["side"]]) + 1
	var ob := {"stoneback": "", "moonhulk": ""}
	if t >= float(RESOLVE["obj_mid"]):
		ob["stoneback"] = objectives["stoneback"]
	if t >= float(RESOLVE["obj_late"]):
		ob["moonhulk"] = objectives["moonhulk"]
	return {"clock_s": clock_at(t), "kills": k, "towers": tw, "objectives": ob, "gold": gold_at(t, my_side), "over": t >= CAIRN_T}


## Per hero kills and deaths played by the events (P4: equal to Report.kda).
func hero_totals() -> Dictionary:
	var out := {"B": {}, "R": {}}
	for side in ["B", "R"]:
		for s in SLOTS:
			out[side][s] = {"k": 0, "d": 0}
	for e in kill_events:
		out[e["side"]][e["killer"]]["k"] = int(out[e["side"]][e["killer"]]["k"]) + 1
		out[other(e["side"])][e["victim"]]["d"] = int(out[other(e["side"])][e["victim"]]["d"]) + 1
	return out


## The beat that helped the game winner most ("Play of the game", 5.3): argmax of s_W * fw[k] * c[k].
func play_of_the_game() -> String:
	var best := ""
	var bv := -INF
	for k in ORDER:
		var v := sgn(winner) * float(fw[k]) * float(contests[k]["c"])
		if v > bv:
			bv = v
			best = k
	return best
