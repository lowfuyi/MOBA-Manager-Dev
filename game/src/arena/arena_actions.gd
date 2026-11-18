class_name ArenaActions
extends RefCounted
## The Fight pass table (Alpha 0.8.1, ACTION-VOCABULARY 11; data/arena_actions_v1.json): which action each archetype plays, the
## fight arc of each group beat, the health-bar rules and the decisive beat. Staging only (R7). Read by ShowScript, Choreo, ArenaFx.

static var _data: Dictionary = {}
static var _arch: Dictionary = {}     # hero id -> archetype (heroes.json)


static func data() -> Dictionary:
	if _data.is_empty():
		_data = DataLoader.load_json("res://data/arena_actions_v1.json")
		for h in DataLoader.load_json("res://data/heroes.json"):
			_arch[String(h["id"])] = String(h.get("archetype", ""))
	return _data


## The archetype of the hero a side played in a slot (res.picks), or the slot's fallback.
static func archetype(res: Dictionary, side: String, slot: String) -> String:
	var d := data()
	var picks: Dictionary = res.get("picks", {})
	var id := String((picks.get(side, {}) as Dictionary).get(slot, ""))
	if _arch.has(id) and (d["archetype_action"] as Dictionary).has(_arch[id]):
		return String(_arch[id])
	return String(d["slot_fallback"][slot])


## dash | shot | burst | tether | heal
static func action_of(res: Dictionary, side: String, slot: String) -> String:
	return String(data()["archetype_action"][archetype(res, side, slot)])


static func fight(beat: String) -> Dictionary:
	return data()["fights"].get(beat, {})
