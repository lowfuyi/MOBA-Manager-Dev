class_name Progression
extends RefCounted
## Training, fatigue and ageing (GDD 7.3). Pure functions over World + the save dictionary.
## Everything the UI or tests need to know about growth lives here; constants are in data/training_v0.json.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = DataLoader.load_json("res://data/training_v0.json")
	return _data


## Rating points lost to fatigue (GDD 4.4): 0.15 per fatigue point above 25.
static func fatigue_penalty(fatigue: float) -> float:
	var d := data()
	return float(d["fatigue_penalty"]) * maxf(0.0, fatigue - float(d["fatigue_line"]))


static func age_factor(age: int) -> float:
	for row in data()["age_factor"]:
		if age <= int(row[0]):
			return float(row[1])
	return 0.25


static func _bracket() -> float:
	var d := data()
	return 1.0 + float(d["coach_gain"]) * float(d["coach"]) + float(d["facility_gain"]) * float(d["facility"])


## Stat points gained in one full training week (GDD 7.3 formula). Zero at or above Potential.
static func stat_gain_week(stat: float, pot: float, age: int, fatigue: float, personality: String) -> float:
	if pot <= 0.0 or stat >= pot:
		return 0.0
	var d := data()
	var g := float(d["base"]) * _bracket() * (1.0 - stat / pot) * age_factor(age) * (1.0 - fatigue / 200.0)
	return maxf(0.0, g * float(d["personality_gain"].get(personality, 1.0)))


## Hero familiarity points gained in one full week of focused practice.
static func fam_gain_week(personality: String) -> float:
	var d := data()
	return float(d["fam_train_week"]) * (1.0 + float(d["fam_coach"]) * float(d["coach"])) * float(d["personality_gain"].get(personality, 1.0))


## Fatigue change for one match day (one tick).
static func fatigue_delta(played: bool, training: bool) -> float:
	var d := data()
	var tpw := float(d["ticks_per_week"])
	var delta := 0.0
	if played:
		delta += float(d["fat_match"])
	if training:
		delta += float(d["fat_train_week"]) / tpw
	delta -= float(d["rest_days_per_week"]) / tpw * (float(d["rest_day"]) + float(d["rest_day_facility"]) * float(d["facility"]))
	return delta


## The coach's default focus: the stat with the most weight in the player's main role times room left to grow.
static func auto_focus(p: Dictionary) -> Dictionary:
	var wts: Array = World.SLOT_W[p["role_primary"]]
	var extra: Dictionary = data()["auto_weights"]
	var best_stat := ""
	var best := 0.0
	for i in World.STATS.size():
		var st: String = World.STATS[i]
		var wt: float = float(wts[i]) if i < 5 else float(extra.get(st, 0.0))
		var room := float(p["potential"][st]) - float(p["stats"][st])
		var score := wt * room
		if score > best:
			best = score
			best_stat = st
	if best_stat == "":
		return {"k": "rest", "v": ""}
	return {"k": "stat", "v": best_stat}


## The focus a player really follows: the manager's choice for his own club, the coach's pick otherwise.
static func focus_of(d: Dictionary, p: Dictionary, human: bool) -> Dictionary:
	if human and (d["train"] as Dictionary).has(p["id"]):
		return d["train"][p["id"]]
	return auto_focus(p)


## Roster of `club_id` ticks one match day. `played` are the ids that played. Returns the training log
## [[player_id, "stat:lan" or "hero:<id>", amount], ...] (only entries with a gain).
static func tick_club(w: World, d: Dictionary, club_id: String, played: Array, human: bool) -> Array:
	return tick_players(w, d, w.club_players(club_id), played, human)


## The same for any list of players (the free agents train on their own, on the coach's plan, and rest).
static func tick_players(w: World, d: Dictionary, plist: Array, played: Array, human: bool) -> Array:
	var log: Array = []
	var tpw := float(data()["ticks_per_week"])
	for p in plist:
		var pid: String = p["id"]
		var fat := w.fatigue_of(pid)
		var f := focus_of(d, p, human)
		var training: bool = f["k"] != "rest"
		if f["k"] == "stat":
			var st: String = f["v"]
			var g := stat_gain_week(float(p["stats"][st]), float(p["potential"][st]), w.age_of(p), fat, p["personality"]) / tpw
			if g > 0.0:
				w.add_progress(pid, st, g)
				log.append([pid, "stat:" + st, g])
		elif f["k"] == "hero":
			var hid: String = f["v"]
			var room := 100.0 - w.familiarity(p, hid)
			var g2 := minf(room, fam_gain_week(p["personality"]) / tpw)
			if g2 > 0.0:
				var key: String = pid + "|" + hid
				d["fam_bonus"][key] = float(d["fam_bonus"].get(key, 0.0)) + g2
				log.append([pid, "hero:" + hid, g2])
		w.fatigue[pid] = clampf(fat + fatigue_delta(played.has(pid), training), 0.0, 100.0)
	return log


## End of season: everybody gets a year older and the veterans lose a little (GDD 7.3). Call before the
## season counter moves on, so ages are those of the season that just ended.
static func age_everyone(w: World) -> void:
	for pid in w.players:
		var p: Dictionary = w.players[pid]
		var age := w.age_of(p)
		for rule in data()["decline"]:
			if age >= int(rule["age"]):
				w.add_progress(pid, rule["stat"], -float(rule["amount"]))
	w.refresh_lineups()
