class_name SimHero
extends RefCounted
## One hero-agent of Match Sim v2 (MATCH-SIM-V2-DESIGN 5): who plays it (stats, phase ratings), the kit, the build, level,
## gold and items, position on the map and the current intent. Plain data plus the stat sums the fight resolver needs.

var side := "B"
var slot := "top"
var key := "B.top"
var hid := ""
var hero: Dictionary = {}
var kit: Dictionary = {}
var arch := ""
var pstats: Dictionary = {}       # the player's visible stats (mec .. clu), 1 to 100
var q := {"early": 1.0, "mid": 1.0, "late": 1.0}   # effectiveness per phase, rating x (1 + TeamMod) / 50
var player_id := ""
var build: Array = []            # six finished item ids (boots first)
var owned: Array = []            # item ids held (components and finished)
var gold := 0.0                  # unspent
var gold_total := 0.0            # earned in the game
var xp := 0.0
var level := 1
var alive := true
var respawn_at := 0.0
var hp := 1.0
var max_hp := 1.0
var pos := Vector2.ZERO
var path: Array = []             # remaining node ids to walk
var intent := "spawn"
var target := ""                 # lane, camp, objective or hero key
var busy_until := 0.0            # in a fight, recalling or clearing a camp until this time
var next_decide := 0.0
var recall_at := -1.0            # arrives home at this time (recall channel)
var last_hit_by: Dictionary = {} # hero key -> last time it damaged or controlled this hero (assists)
var streak := 0
var kills := 0
var deaths := 0
var assists := 0
var dmg_heroes := 0.0
var dmg_taken := 0.0
var healed := 0.0
var cs_gold := 0.0
var ganks := 0
var objectives := 0
var towers := 0
var stacks := 0                  # passive stacks (on_kill, stacks_per_min)
var revive_used := false
var vision := 0.0                # wards placed (support, jungler)
var cds := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])   # absolute time each ability is ready again
var _stat_cache: Dictionary = {}
var _dirty := true


func ability(i: int) -> Dictionary:
	return kit["abilities"][i]


func passive() -> Dictionary:
	return kit["passive"]


func stat(name: String) -> float:
	if _dirty:
		stats()
	return float(_stat_cache.get(name, 0.0))


## Call after the level, the items or the passive stacks change.
func dirty() -> void:
	_dirty = true


## Level and item stats summed (cached until level or items change).
func stats() -> Dictionary:
	if not _dirty:
		return _stat_cache
	var b: Dictionary = kit["stats"]
	var l := float(level - 1)
	var s := {"hp": float(b["hp"]) + float(b["hp_lvl"]) * l, "atk": float(b["atk"]) + float(b["atk_lvl"]) * l,
			"aspd": float(b["aspd"]), "armor": float(b["armor"]) + float(b["armor_lvl"]) * l,
			"resist": float(b["resist"]) + float(b["resist_lvl"]) * l, "range_u": float(b["range_u"]),
			"move_u_s": float(b["move_u_s"]), "ap": 0.0, "crit": 0.0, "haste": 0.0, "lifesteal": 0.0, "omnivamp": 0.0,
			"move": 0.0, "pen_armor": 0.0, "pen_resist": 0.0, "shield_power": 0.0, "heal_power": 0.0}
	var effects := {}
	var iv := 0.0
	for iid in owned:
		var it: Dictionary = SimData.item(iid)
		iv += float(it["cost"])
		for k in it["stats"]:
			s[k] = float(s.get(k, 0.0)) + float(it["stats"][k])
		if String(it["effect"]) != "":
			effects[String(it["effect"])] = true
	var p := passive()
	if String(p["trigger"]) in ["stacks_per_min", "on_kill"] and String(p["stat"]) in s:
		s[String(p["stat"])] = float(s[String(p["stat"])]) + float(p["amount"]) * float(mini(stacks, int(p["max_stacks"])))
	if String(p["trigger"]) == "aura" and String(p["stat"]) == "armor":
		s["armor"] = float(s["armor"]) + float(p["amount"]) * 0.5
	s["haste"] = minf(40.0, float(s["haste"]))
	s["aspd"] = float(s["aspd"]) * (1.0 + float(s.get("aspd_bonus", 0.0))) + 0.0
	s["effects"] = effects
	s["item_value"] = iv
	_stat_cache = s
	_dirty = false
	return s


func has_effect(e: String) -> bool:
	if _dirty:
		stats()
	return (_stat_cache["effects"] as Dictionary).has(e)


## Total item value carried (for the gold lead and the buy logic).
func item_value() -> float:
	if _dirty:
		stats()
	return float(_stat_cache["item_value"])


func move_speed() -> float:
	return stat("move_u_s") * (1.0 + stat("move"))


func phase_q(t: float) -> float:
	if t < 600.0:
		return float(q["early"])
	if t < 1080.0:
		return float(q["mid"])
	return float(q["late"])


## Effectiveness used by fights and farming: 1 + q_k x (q - 1), linear on purpose (design Q1: no pow); q_k is calibrated.
static var q_k := -1.0


func qe(t: float) -> float:
	if q_k < 0.0:
		q_k = SimData.f("q_k")
	return 1.0 + q_k * (phase_q(t) - 1.0)


func st(name: String) -> float:
	return float(pstats.get(name, 50.0))
