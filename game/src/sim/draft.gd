class_name Draft
extends RefCounted
## Stateful draft (GDD 6 and 8.7). The AI decision rule is a port of tools/pipeline.py draft();
## a person can decide any step (the UI does for the managed club), the AI decides the rest.
## Each step draws from its own PCG32 stream "draft:<match id>:<n>", so asking the AI for a
## recommendation never disturbs later steps.

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const ORDER_FULL := [["B", "ban"], ["R", "ban"], ["B", "ban"], ["R", "ban"],
		["B", "pick"], ["R", "pick"], ["R", "pick"], ["B", "pick"], ["B", "pick"], ["R", "pick"],
		["R", "ban"], ["B", "ban"],
		["R", "pick"], ["B", "pick"], ["B", "pick"], ["R", "pick"]]
const ORDER_SHORT := [["B", "ban"], ["R", "ban"],
		["B", "pick"], ["R", "pick"], ["R", "pick"], ["B", "pick"], ["B", "pick"], ["R", "pick"],
		["R", "pick"], ["B", "pick"], ["B", "pick"], ["R", "pick"]]

var world: World
var lineups: Dictionary          # {"B": {slot: player}, "R": {...}}
var meta: Dictionary
var mseed: int
var match_id: String
var order: Array
var policies: Dictionary = {"B": {}, "R": {}}
var step: int = 0
var avail: Array = []
var picks := {"B": {}, "R": {}}  # slot -> hero dict
var bans := {"B": [], "R": []}
var log: Array = []              # {n, team, kind, slot, hero}


static func make(w: World, lu: Dictionary, meta_in: Dictionary, match_seed: int, id: String, full: bool) -> Draft:
	var d := Draft.new()
	d.world = w
	d.lineups = lu
	d.meta = meta_in
	d.mseed = match_seed
	d.match_id = id
	d.order = ORDER_FULL if full else ORDER_SHORT
	d.avail = w.hero_ids.duplicate()
	return d


func is_done() -> bool:
	return step >= order.size()


func current() -> Dictionary:
	if is_done():
		return {}
	return {"n": step, "team": order[step][0], "kind": order[step][1]}


func open_slots(team: String) -> Array:
	var out: Array = []
	for s in SLOTS:
		if not picks[team].has(s):
			out.append(s)
	return out


func apply_ban(hid: String) -> bool:
	var c := current()
	if c.is_empty() or c["kind"] != "ban" or not avail.has(hid):
		return false
	avail.erase(hid)
	bans[c["team"]].append(hid)
	log.append({"n": step, "team": c["team"], "kind": "ban", "slot": "", "hero": hid})
	step += 1
	return true


func apply_pick(slot: String, hid: String) -> bool:
	var c := current()
	if c.is_empty() or c["kind"] != "pick" or not avail.has(hid) or picks[c["team"]].has(slot) or not SLOTS.has(slot):
		return false
	avail.erase(hid)
	picks[c["team"]][slot] = world.heroes[hid]
	log.append({"n": step, "team": c["team"], "kind": "pick", "slot": slot, "hero": hid})
	step += 1
	return true


func apply(choice: Dictionary) -> bool:
	var c := current()
	if c.is_empty():
		return false
	return apply_ban(choice["hero"]) if c["kind"] == "ban" else apply_pick(choice["slot"], choice["hero"])


## The AI's decision for the current step, without applying it. {"hero": id, "slot": slot or ""}.
func ai_choice() -> Dictionary:
	var c := current()
	var team: String = c["team"]
	var other := "R" if team == "B" else "B"
	var stream := Pcg32.contest_stream(mseed, "draft:%s:%d" % [match_id, step])
	if c["kind"] == "ban":
		return {"hero": _ai_ban(other, stream), "slot": ""}
	return _ai_pick(team, other, stream)


func _ai_ban(other: String, stream: Pcg32) -> String:
	var by_meta_only := stream.next_float() < Params.f("ban_meta_only_p")
	var best := ""
	var best_v := 0.0
	var have := false
	for s in SLOTS:
		var p: Dictionary = lineups[other][s]
		for hid in avail:
			var h: Dictionary = world.heroes[hid]
			var v: float = float(meta[hid]) if by_meta_only else world.familiarity(p, hid) * float(meta[hid]) * world.hero_fit(h, s)
			if not have or v > best_v + 1e-12 or (absf(v - best_v) <= 1e-12 and hid < best):
				best = hid
				best_v = v
				have = true
	return best


static func _lane_group(slot: String) -> String:
	return "bot" if (slot == "bot" or slot == "sup") else slot


func _counter_score(h: Dictionary, slot: String, enemy_picks: Dictionary) -> float:
	var g := _lane_group(slot)
	var n := 0
	var v := 0
	for s in enemy_picks:
		if _lane_group(s) == g:
			n += 1
			var e: Dictionary = enemy_picks[s]
			v += int((h["strong_vs"] as Array).has(e["id"])) - int((e["strong_vs"] as Array).has(h["id"]))
	if n == 0:
		return 0.5
	return (float(maxi(-1, mini(1, v))) + 1.0) / 2.0


func _ai_pick(team: String, other: String, stream: Pcg32) -> Dictionary:
	var w: Dictionary = Params.all()["policy_default"].duplicate()
	w.merge(policies.get(team, {}), true)
	var syn_bonus := Params.f("syn_bonus")
	var cur: Array = picks[team].values()
	var base_prog := Comp.progress(cur) if not cur.is_empty() else 0.0
	stream.next_normal()    # reserved for AI-difficulty noise (v1 reference draws and discards it)
	var best_slot := ""
	var best_hid := ""
	var best_v := 0.0
	var have := false
	for s in SLOTS:
		if picks[team].has(s):
			continue
		var p: Dictionary = lineups[team][s]
		for hid in avail:
			var h: Dictionary = world.heroes[hid]
			var famf := world.familiarity(p, hid) / 100.0 * world.hero_fit(h, s)
			var metaf := (float(meta[hid]) - 0.97) / 0.06
			var with_h := cur.duplicate()
			with_h.append(h)
			var comp := maxf(0.0, minf(1.0, 0.5 + (0.1 / syn_bonus) * (Comp.progress(with_h) - base_prog)))
			var ctr := _counter_score(h, s, picks[other])
			var v: float = float(w["fam"]) * famf + float(w["meta"]) * metaf + float(w["comp"]) * comp + float(w["counter"]) * ctr
			var better := not have or v > best_v + 1e-12
			if not better and absf(v - best_v) <= 1e-12:
				better = hid < best_hid or (hid == best_hid and s < best_slot)
			if better:
				best_slot = s
				best_hid = hid
				best_v = v
				have = true
	return {"hero": best_hid, "slot": best_slot}


## Run every remaining step with the AI.
func finish_with_ai() -> void:
	while not is_done():
		apply(ai_choice())
