class_name Scout
extends RefCounted
## Scouting summary (0.12, ESMO Q4-2): a letter grade, a one-line note and up to two pros and two cons, all from values the
## game already has (Economy.best_slot_rating, Economy.potential_rating, the player's stats and age) and fixed templates.
## Compared with every player in the world, so a grade means the same on every screen. Display only.

const GRADES := ["A", "B", "C", "D"]
const GRADE_TOP := [0.10, 0.30, 0.60]    # share of all players at or above each grade's line
const PRO_TOP := 0.30                    # a stat in the best 30% of all players is a pro
const CON_BOTTOM := 0.30                 # a stat in the worst 30% is a con
const ROOM_GROWTH := 5.0                 # points of potential rating left to call him "still improving"
const ROOM_PROSPECT := 8.0
const ROOM_READY := 3.0
const AGE_YOUNG := 20


## Share of `vals` (sorted ascending) strictly below v: 0.0 = the lowest, near 1.0 = the highest.
static func _below(vals: Array, v: float) -> float:
	if vals.is_empty():
		return 0.5
	var lo := 0
	var hi := vals.size()
	while lo < hi:
		var mid := (lo + hi) / 2
		if float(vals[mid]) < v:
			lo = mid + 1
		else:
			hi = mid
	return float(lo) / float(vals.size())


## Sorted values of the whole world, built once per call site (pass the result to summary()).
static func table(w: World) -> Dictionary:
	var rat: Array = []
	var st := {}
	for s in World.STATS:
		st[s] = []
	for pid in w.players:
		var p: Dictionary = w.players[pid]
		rat.append(Economy.best_slot_rating(w, p))
		for s in World.STATS:
			(st[s] as Array).append(float(p["stats"][s]))
	rat.sort()
	for s in World.STATS:
		(st[s] as Array).sort()
	return {"rating": rat, "stats": st}


static func grade(w: World, p: Dictionary, t: Dictionary) -> String:
	var above := 1.0 - _below(t["rating"], Economy.best_slot_rating(w, p))    # share of players at or above him
	for i in GRADE_TOP.size():
		if above <= float(GRADE_TOP[i]) + 1e-9:
			return GRADES[i]
	return GRADES[3]


## {"grade", "note": [key, vars], "pros": [[key, vars]], "cons": [[key, vars]]}.
static func summary(w: World, p: Dictionary, t: Dictionary) -> Dictionary:
	var g := grade(w, p, t)
	var now := Economy.best_slot_rating(w, p)
	var room := Economy.potential_rating(w, p) - now
	var age := w.age_of(p)
	var role := String(p["role_primary"])
	var note: Array
	if g == "A" and room < ROOM_READY:
		note = ["scout.note.star", {"role": role}]
	elif age <= AGE_YOUNG and room >= ROOM_PROSPECT:
		note = ["scout.note.prospect", {}]
	elif room >= ROOM_GROWTH:
		note = ["scout.note.growth", {"n": int(round(room))}]
	elif room < ROOM_READY:
		note = ["scout.note.ready", {}]
	else:
		note = ["scout.note.solid", {"role": role}]
	# Pros and cons: the stats his main role weighs, heaviest first, compared with every player.
	var wts: Array = World.SLOT_W[role]
	var order: Array = []
	for i in wts.size():
		order.append([float(wts[i]), -i, String(World.STATS[i])])
	order.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	var pros: Array = []
	var cons: Array = []
	for o in order:
		var s: String = o[2]
		var v := float(p["stats"][s])
		var below := _below(t["stats"][s], v)
		if below >= 1.0 - PRO_TOP and pros.size() < 2:
			pros.append(["scout.pro", {"stat": s, "v": int(round(v)), "pct": int(floor(100.0 * below))}])
		elif below < CON_BOTTOM and cons.size() < 2:
			cons.append(["scout.con", {"stat": s, "v": int(round(v)), "pct": int(ceil(100.0 * (1.0 - below)))}])
	return {"grade": g, "note": note, "pros": pros, "cons": cons}
