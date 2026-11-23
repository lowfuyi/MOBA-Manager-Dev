class_name SimHero
extends RefCounted
## One hero-agent of Match Sim v2 (MATCH-SIM-V2-DESIGN 5): who plays it (stats, phase ratings), the kit, the build, level,
## gold and items, position on the map and the current intent. Hot values are typed fields (not dictionary lookups): the
## player's stats (p_*), the summed level and item stats (s_*, refreshed when the level, the items or the stacks change), the
## item effects (e_*) and the kit as typed Ability objects.


## One ability of the kit, as typed fields (built once from kits_v2.json).
class Ability:
	var id := ""
	var slot := ""
	var dmg_k := false
	var cc_k := false
	var mob := false
	var shield_k := false
	var heal_k := false
	var buff_k := false
	var zone := false
	var execute := false
	var stealth := false
	var wave := false
	var target := 0              # 0 enemy, 1 ally, 2 self, 3 area, 4 line
	var cc := 0                  # 0 none, 1 stun/knockup/taunt, 2 root, 3 silence, 4 slow
	var cc_s := 0.0
	var dmg := 0.0
	var dmg_lvl := 0.0
	var ratio := 0.0
	var magic := false
	var shield := 0.0
	var heal := 0.0
	var ally_heal := 0.0         # 0.11.2: heals every ally when the ability lands (Fen Fog); optional in kits_v2.json
	var ratio_def := 0.0
	var radius := 0.0
	var cd := 1.0
	var cd_lvl := 0.0
	var hit := 1.0
	var dur := 0.0
	var buff: Dictionary = {}
	var exec_below := 0.0
	var unlock := 1

	static func from(a: Dictionary) -> Ability:
		var x := Ability.new()
		x.id = String(a["id"])
		x.slot = String(a["slot"])
		var k: Array = a["kind"]
		x.dmg_k = "damage" in k
		x.cc_k = "cc" in k
		x.mob = "mobility" in k
		x.shield_k = "shield" in k
		x.heal_k = "heal" in k
		x.buff_k = "buff" in k
		x.zone = "zone" in k
		x.execute = "execute" in k
		x.stealth = "stealth" in k
		x.wave = "wave" in k
		x.target = {"enemy": 0, "ally": 1, "self": 2, "area": 3, "line": 4}[String(a["target"])]
		x.cc = {"": 0, "stun": 1, "knockup": 1, "taunt": 1, "root": 2, "silence": 3, "slow": 4}[String(a["cc"])]
		x.cc_s = float(a["cc_s"])
		x.dmg = float(a["dmg"])
		x.dmg_lvl = float(a["dmg_lvl"])
		x.ratio = float(a["ratio"])
		x.magic = String(a["dtype"]) == "magic"
		x.shield = float(a["shield"])
		x.heal = float(a["heal"])
		x.ally_heal = float(a.get("ally_heal", 0.0))
		x.ratio_def = float(a["ratio_def"])
		x.radius = float(a["radius_u"])
		x.cd = float(a["cd"])
		x.cd_lvl = float(a["cd_lvl"])
		x.hit = float(a["hit"])
		x.dur = float(a["dur_s"])
		x.buff = a["buff"]
		x.exec_below = float(a["exec_below"])
		x.unlock = int(a["unlock"])
		return x


## The passive, as typed fields.
class Passive:
	var trigger := ""
	var every := 0
	var bonus_dmg := 0.0
	var ratio := 0.0
	var heal := 0.0
	var shield := 0.0
	var stat := ""
	var amount := 0.0
	var max_stacks := 0
	var cc := 0
	var cc_s := 0.0
	var cd := 0.0

	static func from(p: Dictionary) -> Passive:
		var x := Passive.new()
		x.trigger = String(p["trigger"])
		x.every = int(p["every"])
		x.bonus_dmg = float(p["bonus_dmg"])
		x.ratio = float(p["ratio"])
		x.heal = float(p["heal"])
		x.shield = float(p["shield"])
		x.stat = String(p["stat"])
		x.amount = float(p["amount"])
		x.max_stacks = int(p["max_stacks"])
		x.cc = {"": 0, "stun": 1, "knockup": 1, "taunt": 1, "root": 2, "silence": 3, "slow": 4}[String(p["cc"])]
		x.cc_s = float(p["cc_s"])
		x.cd = float(p["cd"])
		return x


var side := "B"
var slot := "top"
var key := "B.top"
var hid := ""
var hero: Dictionary = {}
var kit: Dictionary = {}
var arch := ""
var front := false               # bruiser or bulwark: the front row in fights
var ranged := false              # attack range above melee
var abil: Array = []             # Ability x4 (a1, a2, a3, ult)
var pas: Passive
var pstats: Dictionary = {}      # the player's visible stats (mec .. clu), 1 to 100
var p_mec := 50.0
var p_sen := 50.0
var p_lan := 50.0
var p_tft := 50.0
var p_mac := 50.0
var p_com := 50.0
var p_clu := 50.0
var q := {"early": 1.0, "mid": 1.0, "late": 1.0}   # effectiveness per phase, rating x (1 + TeamMod) / 50
var qe_early := 1.0
var qe_mid := 1.0
var qe_late := 1.0
var player_id := ""
var bal := 1.0                   # per-hero balance multiplier (hero_balance_v2.json)
var bal_dmg := 1.0               # its damage part ("dmg" entry, else bal)
var bal_hp := 1.0                # its health part ("hp" entry, else bal)
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
var path: Array = []             # remaining node ids (or points) to walk
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
# summed stats (level + items + passive), refreshed by _refresh()
var s_hp := 0.0
var s_atk := 0.0
var s_aspd := 0.0
var s_armor := 0.0
var s_resist := 0.0
var s_ap := 0.0
var s_crit := 0.0
var s_haste := 0.0
var s_ls := 0.0
var s_ov := 0.0
var s_move := 0.0
var s_move_base := 0.0
var s_pen_a := 0.0
var s_pen_r := 0.0
var s_shp := 0.0
var s_hlp := 0.0
var s_range := 0.0
var s_item_value := 0.0
var e_burn := false
var e_antiheal := false
var e_on_hit := false
var e_crit_amp := false
var e_spellblade := false
var e_guard := false
var e_revive := false
var e_slow_hit := false
var e_execute := false
var e_splash := false
var _dirty := true
var _stat_cache: Dictionary = {}


## Call once the kit, the player and the phase ratings are set.
func init_kit(p_kit: Dictionary) -> void:
	kit = p_kit
	abil = []
	for a in kit["abilities"]:
		abil.append(Ability.from(a))
	pas = Passive.from(kit["passive"])
	front = arch == "bruiser" or arch == "bulwark"
	ranged = float(kit["stats"]["range_u"]) > 0.02
	p_mec = float(pstats.get("mec", 50.0))
	p_sen = float(pstats.get("sen", 50.0))
	p_lan = float(pstats.get("lan", 50.0))
	p_tft = float(pstats.get("tft", 50.0))
	p_mac = float(pstats.get("mac", 50.0))
	p_com = float(pstats.get("com", 50.0))
	p_clu = float(pstats.get("clu", 50.0))
	if q_k < 0.0:
		q_k = SimData.f("q_k")
	bal = SimData.balance(hid)
	bal_dmg = SimData.balance_dmg(hid)
	bal_hp = SimData.balance_hp(hid)
	qe_early = 1.0 + q_k * (float(q["early"]) - 1.0)
	qe_mid = 1.0 + q_k * (float(q["mid"]) - 1.0)
	qe_late = 1.0 + q_k * (float(q["late"]) - 1.0)
	dirty()


func ability(i: int) -> Dictionary:
	return kit["abilities"][i]


func passive() -> Dictionary:
	return kit["passive"]


## Call after the level, the items or the passive stacks change.
func dirty() -> void:
	_dirty = true
	if not kit.is_empty():
		_refresh()


func stat(name: String) -> float:
	if _dirty:
		_refresh()
	return float(_stat_cache.get(name, 0.0))


func stats() -> Dictionary:
	if _dirty:
		_refresh()
	return _stat_cache


func _refresh() -> void:
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
	if pas != null:
		if (pas.trigger == "stacks_per_min" or pas.trigger == "on_kill") and s.has(pas.stat):
			s[pas.stat] = float(s[pas.stat]) + pas.amount * float(mini(stacks, pas.max_stacks))
		if pas.trigger == "aura" and pas.stat == "armor":
			s["armor"] = float(s["armor"]) + pas.amount * 0.5
	s["haste"] = minf(40.0, float(s["haste"]))
	s["hp"] = float(s["hp"]) * (0.5 + 0.5 * bal_hp)
	s["effects"] = effects
	s["item_value"] = iv
	_stat_cache = s
	s_hp = s["hp"]
	s_atk = s["atk"]
	s_aspd = s["aspd"]
	s_armor = s["armor"]
	s_resist = s["resist"]
	s_ap = s["ap"]
	s_crit = s["crit"]
	s_haste = s["haste"]
	s_ls = s["lifesteal"]
	s_ov = s["omnivamp"]
	s_move = s["move"]
	s_move_base = s["move_u_s"]
	s_pen_a = s["pen_armor"]
	s_pen_r = s["pen_resist"]
	s_shp = s["shield_power"]
	s_hlp = s["heal_power"]
	s_range = s["range_u"]
	s_item_value = iv
	e_burn = effects.has("burn")
	e_antiheal = effects.has("antiheal")
	e_on_hit = effects.has("on_hit")
	e_crit_amp = effects.has("crit_amp")
	e_spellblade = effects.has("spellblade")
	e_guard = effects.has("guard")
	e_revive = effects.has("revive_once")
	e_slow_hit = effects.has("slow_on_hit")
	e_execute = effects.has("execute")
	e_splash = effects.has("splash")
	_dirty = false


func has_effect(e: String) -> bool:
	if _dirty:
		_refresh()
	return (_stat_cache["effects"] as Dictionary).has(e)


## Total item value carried (for the gold lead and the buy logic).
func item_value() -> float:
	return s_item_value


func move_speed() -> float:
	return s_move_base * (1.0 + s_move)


func phase_q(t: float) -> float:
	if t < 600.0:
		return float(q["early"])
	if t < 1080.0:
		return float(q["mid"])
	return float(q["late"])


## Effectiveness used by fights and farming: 1 + q_k x (q - 1), linear on purpose (design Q1: no pow); q_k is calibrated.
static var q_k := -1.0


func qe(t: float) -> float:
	if t < 600.0:
		return qe_early
	if t < 1080.0:
		return qe_mid
	return qe_late


func st(name: String) -> float:
	return float(pstats.get(name, 50.0))
