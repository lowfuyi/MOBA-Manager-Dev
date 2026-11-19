class_name Items
extends RefCounted
## Items and builds of Match Sim v2 (MATCH-SIM-V2-DESIGN 4.2 and 4.3). The coach's suggestion is computed from the hero's
## archetype and kit and the enemy draft (rules in items_v2.json coach_rules), never written per hero. A build is six item ids
## in buy order: boots first, then five finished items. Buying happens at the base, in build order, component by component.

const BUILD_SIZE := 6
const SLOTS_MAX := 6
## stat weights per archetype for the coach's score (the value of an item's stats to this kind of hero)
const W := {
	"bruiser": {"atk": 1.0, "hp": 0.8, "armor": 0.6, "resist": 0.5, "haste": 0.6, "omnivamp": 0.7, "pen_armor": 0.6, "lifesteal": 0.3},
	"bulwark": {"hp": 1.0, "armor": 0.9, "resist": 0.9, "haste": 0.5},
	"spellcaster": {"ap": 1.0, "haste": 0.7, "pen_resist": 0.8, "hp": 0.3, "move": 0.3},
	"gunner": {"atk": 0.9, "aspd": 1.0, "crit": 1.0, "lifesteal": 0.5, "pen_armor": 0.6, "move": 0.3},
	"shade": {"atk": 0.8, "ap": 0.5, "pen_armor": 0.8, "pen_resist": 0.5, "haste": 0.5, "move": 0.4, "omnivamp": 0.4},
	"mender": {"heal_power": 1.0, "shield_power": 0.9, "haste": 0.8, "ap": 0.5, "hp": 0.4, "move": 0.4},
	"binder": {"haste": 0.8, "hp": 0.6, "ap": 0.6, "resist": 0.5, "armor": 0.5, "shield_power": 0.5, "move": 0.4},
}


static func finished_ids() -> Array:
	var out: Array = []
	for it in SimData.items_doc()["items"]:
		if String(it["tier"]) == "finished":
			out.append(String(it["id"]))
	return out


static func boots_ids() -> Array:
	var out: Array = []
	for it in SimData.items_doc()["items"]:
		if String(it["tier"]) == "boots":
			out.append(String(it["id"]))
	return out


## A build is legal when it has six distinct ids: one upgraded boots item and five finished items.
static func is_legal(build: Array) -> bool:
	if build.size() != BUILD_SIZE:
		return false
	var seen := {}
	var boots := 0
	for iid in build:
		var s := String(iid)
		if seen.has(s) or not SimData.items().has(s):
			return false
		seen[s] = true
		var tier := String(SimData.item(s)["tier"])
		if tier == "boots":
			boots += 1
		elif tier != "finished":
			return false
	return boots == 1


## Enemy draft summary for the coach rules: damage shares, heal sources, dive score.
static func enemy_profile(enemy_hids: Array) -> Dictionary:
	var phys := 0.0
	var magic := 0.0
	var heals := 0
	var dive := 0
	for hid in enemy_hids:
		var h: Dictionary = SimData.heroes()[hid]
		match String(h["damage_type"]):
			"physical":
				phys += 1.0
			"magic":
				magic += 1.0
			_:
				phys += 0.5
				magic += 0.5
		var k := SimData.kit(hid)
		var heals_here := String(k["passive"]["trigger"]) != "" and int(k["passive"]["heal"]) > 0
		for a in k["abilities"]:
			if "heal" in a["kind"]:
				heals_here = true
		if heals_here:
			heals += 1
		for t in h["tags"]:
			if t in ["engage", "pick"]:
				dive += 1
	var tot := maxf(1.0, phys + magic)
	return {"phys": phys / tot, "magic": magic / tot, "heals": heals, "dive": dive}


static func _score(it: Dictionary, arch: String, classes: Array, prof: Dictionary, frontline: bool, carry: bool) -> float:
	var rules: Dictionary = SimData.items_doc()["coach_rules"]
	var wts: Dictionary = rules["weights"]
	var sg: Dictionary = SimData.items_doc()["stat_gold"]
	var w: Dictionary = W[arch].duplicate()
	if float(prof["phys"]) >= float(rules["heavy_damage_share"]) and frontline:
		w["armor"] = float(w.get("armor", 0.0)) + float(wts["enemy_physical_armor"])
	if float(prof["magic"]) >= float(rules["heavy_damage_share"]) and frontline:
		w["resist"] = float(w.get("resist", 0.0)) + float(wts["enemy_magic_resist"])
	var v := 0.0
	for k in it["stats"]:
		v += float(w.get(k, 0.0)) * float(sg[k]) * float(it["stats"][k])
	var sc := float(wts["stat_match"]) * v / float(it["cost"])
	if not (String(it["class"]) in classes):
		sc *= 0.6
	var eff := String(it["effect"])
	if eff == "antiheal" and int(prof["heals"]) >= int(rules["antiheal_from_heals"]):
		sc += float(wts["enemy_heals_antiheal"])
	if eff in ["guard", "revive_once"] and carry and int(prof["dive"]) >= int(rules["dive_from_engage_pick"]):
		sc += float(wts["enemy_dive_guard"])
	return sc


## The coach's build for hero `hid` played in `slot` against the enemy heroes. Deterministic; ties by ascending id.
static func suggest(hid: String, slot: String, enemy_hids: Array) -> Array:
	var h: Dictionary = SimData.heroes()[hid]
	var arch := String(h["archetype"])
	var rules: Dictionary = SimData.items_doc()["coach_rules"]
	var classes: Array = rules["class_by_archetype"][arch]
	var prof := enemy_profile(enemy_hids)
	var frontline: bool = "frontline" in h["tags"]
	var carry: bool = arch in ["gunner", "spellcaster", "shade"]
	var boots := String(rules["boots_by_archetype"][arch])
	if frontline and float(prof["magic"]) >= float(rules["heavy_damage_share"]):
		boots = String(rules["boots_vs_magic_heavy"])
	var cand: Array = []
	for iid in finished_ids():
		cand.append([_score(SimData.item(iid), arch, classes, prof, frontline, carry), iid])
	var out: Array = [boots]
	var used_eff := {}
	var dup := float(rules["weights"]["duplicate_effect"])
	while out.size() < BUILD_SIZE:
		var best := -INF
		var best_id := ""
		for c in cand:
			var iid := String(c[1])
			if iid in out:
				continue
			var sc := float(c[0])
			var eff := String(SimData.item(iid)["effect"])
			if eff != "" and used_eff.has(eff):
				sc += dup
			if sc > best or (sc == best and iid < best_id):
				best = sc
				best_id = iid
		out.append(best_id)
		var e2 := String(SimData.item(best_id)["effect"])
		if e2 != "":
			used_eff[e2] = true
	return out


## Buy at the base: spends `hero.gold` along the build (boots base, boots, then each finished item through its components).
## Returns the ids bought, in order (the log's buy events).
static func shop(hero: SimHero) -> Array:
	var bought: Array = []
	var guard := 0
	while guard < 20:
		guard += 1
		var nxt := _next_purchase(hero)
		if nxt.is_empty():
			break
		var iid := String(nxt["id"])
		var price := float(nxt["price"])
		if price > hero.gold:
			break
		hero.gold -= price
		for c in nxt["consumes"]:
			hero.owned.erase(c)
		hero.owned.append(iid)
		hero.dirty()
		bought.append(iid)
	return bought


## The next thing to buy: {"id", "price" (gold to pay now), "consumes" (owned components it uses up)} or {} when done.
static func _next_purchase(hero: SimHero) -> Dictionary:
	for iid in hero.build:
		var id := String(iid)
		if id in hero.owned:
			continue
		var it := SimData.item(id)
		var have: Array = []
		var missing: Array = []
		var pool: Array = hero.owned.duplicate()
		for c in it["components"]:
			if String(c) in pool:
				pool.erase(String(c))
				have.append(String(c))
			else:
				missing.append(String(c))
		var have_value := 0.0
		for c in have:
			have_value += float(SimData.item(c)["cost"])
		var full := float(it["cost"]) - have_value
		var slots_after := hero.owned.size() - have.size() + 1
		if hero.gold >= full and slots_after <= SLOTS_MAX:
			return {"id": id, "price": full, "consumes": have}
		if missing.is_empty():
			return {"id": id, "price": full, "consumes": have}   # only the recipe fee is missing: wait for it
		if hero.owned.size() >= SLOTS_MAX:
			return {}
		var cheapest := ""
		for c in missing:
			if cheapest == "" or float(SimData.item(c)["cost"]) < float(SimData.item(cheapest)["cost"]):
				cheapest = c
		return {"id": cheapest, "price": float(SimData.item(cheapest)["cost"]), "consumes": []}
	return {}
