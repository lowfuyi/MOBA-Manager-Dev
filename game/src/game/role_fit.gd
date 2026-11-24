class_name RoleFit
extends RefCounted
## Role fit for the screens (0.12, ESMO Q4-1). Only values the game really uses: a player's rating in a lane is
## World.slot_score (the lane's stat weights x the player's fit, less fatigue), the fit is World.player_fit (main role 100%,
## second role 93%, off role 80%), and the stats that raise a lane rating most are that lane's heaviest weights (SLOT_W).
## Display only: nothing here changes a rating or a lineup.


## "main", "second" or "off".
static func kind(w: World, p: Dictionary, slot: String) -> String:
	if String(p["role_primary"]) == slot:
		return "main"
	if _sec(p) == slot:
		return "second"
	return "off"


static func pct(w: World, p: Dictionary, slot: String) -> int:
	return int(round(100.0 * w.player_fit(p, slot)))


static func rating(w: World, p: Dictionary, slot: String) -> float:
	return w.slot_score(p, slot)


## The two stats that raise the player's rating in `slot` most: the lane's heaviest weights among the stats that still
## have room below the player's potential (all weighted stats when fewer than two have room). Only the first five stats carry
## lane weights (World.base_rating). Ties keep World.STATS order.
static func train_for(p: Dictionary, slot: String) -> Array:
	var wts: Array = World.SLOT_W[slot]
	var cands: Array = []
	for i in wts.size():
		var st: String = World.STATS[i]
		if float(p["potential"][st]) - float(p["stats"][st]) >= 1.0:
			cands.append([float(wts[i]), -i, st])
	if cands.size() < 2:
		cands.clear()
		for i in wts.size():
			cands.append([float(wts[i]), -i, World.STATS[i]])
	cands.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	return [String(cands[0][2]), String(cands[1][2])]


## The lane a player would most likely move to: the second role if he has one, else his best lane that is not his main one.
static func move_target(w: World, p: Dictionary) -> String:
	var sec := _sec(p)
	if sec != "" and World.SLOTS.has(sec):
		return sec
	var best := ""
	var bv := -INF
	for s in World.SLOTS:
		if s == String(p["role_primary"]):
			continue
		var v := rating(w, p, s)
		if v > bv:
			bv = v
			best = s
	return best


## The second role, or "" (the field may be missing or null).
static func _sec(p: Dictionary) -> String:
	var v: Variant = p.get("role_secondary", "")
	return "" if v == null else String(v)
