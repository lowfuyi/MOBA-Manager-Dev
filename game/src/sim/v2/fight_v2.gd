class_name FightV2
extends RefCounted
## The fight resolver of Match Sim v2 (MATCH-SIM-V2-DESIGN 5.4). Runs one fight in steps of fight_dt (0.25 s) of game time over
## the heroes in it and those who arrive: target choice by role and TFT, casts by kit (landing by MEC), damage after armour and
## resistance, crowd control, shields and heals, item effects, passives, retreats by SEN and kills with assists.
## Positions inside a fight are rows: front (bruisers, bulwarks) and back (everyone else). A melee hero reaches the back row
## only after a dash (a mobility ability) or once the enemy front row is gone. Towers in range shoot the side that dives them.
## Deterministic: every draw comes from the fight's own PCG32 stream; no libm calls.

const FRONT_ARCH := ["bruiser", "bulwark"]
const HARD := ["stun", "knockup", "taunt"]

var sim: MatchSimV2
var rng: Pcg32
var heroes: Array = []       # SimHero
var t := 0.0
var t0 := 0.0
var center := Vector2.ZERO
var fid := 0
var kind := ""               # skirmish | gank | objective | siege | teamfight
var st: Dictionary = {}      # hero key -> local state
var tower_side := ""         # the side whose tower covers the fight ("" = none)
var tower_dmg := 0.0
var team_k := {"B": 1.0, "R": 1.0}
var events: Array = []
var kills: Array = []        # [{t, killer, victim, assists}]
var last_damage_t := 0.0
var _act := {"B": [], "R": []}
var _act_dirty := true


static func row_of(h: SimHero) -> int:
	return 0 if h.arch in FRONT_ARCH else 1


func _state(h: SimHero, join_delay: float) -> Dictionary:
	return {"join": t0 + join_delay, "row": row_of(h), "cc": 0.0, "root": 0.0, "silence": 0.0, "slow": 0.0, "shield": 0.0,
			"untarget": 0.0, "next_atk": t0 + join_delay + 0.3 * rng.next_float(), "dived": false, "fled": false, "flee_at": -1.0,
			"hits": 0, "casts": 0, "buffs": [], "spellblade": false, "first_attack": true, "low_used": -999.0, "mark": false,
			"in_fight": false}


## participants: [[SimHero, join_delay_s], ...]
func run(p_sim: MatchSimV2, participants: Array, p_t0: float, p_center: Vector2, p_kind: String, p_fid: int) -> void:
	sim = p_sim
	t0 = p_t0
	t = p_t0
	center = p_center
	kind = p_kind
	fid = p_fid
	rng = Pcg32.contest_stream(int(sim.mseed), "v2:fight:%d" % fid)
	for pr in participants:
		var h: SimHero = pr[0]
		heroes.append(h)
		st[h.key] = _state(h, float(pr[1]))
	_tower_cover()
	_team_factors()
	var keys: Array = []
	for h in heroes:
		keys.append(h.key)
	events.append([t0, "fight", fid, kind, keys])
	var dt := SimData.f("fight_dt")
	var t_max := t0 + SimData.f("fight_max_s")
	last_damage_t = t0
	var guard := 0
	while t < t_max and guard < 200:
		guard += 1
		_step(dt)
		t += dt
		if guard % 2 == 0:
			_hp_sample()
		if _over():
			break
	for h in heroes:
		h.busy_until = maxf(h.busy_until, t)
	events.append([t, "fight_end", fid])


## Health of everyone in the fight, every 0.5 s (the arena's health bars): [t, "hp", fid, {key: fraction}].
func _hp_sample() -> void:
	var hp := {}
	for h in heroes:
		var hh: SimHero = h
		hp[hh.key] = snappedf(hh.hp / maxf(1.0, hh.max_hp), 0.01) if hh.alive and hh.hp > 0.0 else 0.0
	events.append([t, "hp", fid, hp])


func _tower_cover() -> void:
	var r := SimData.f("tower_range_u")
	for tw in sim.towers:
		if not tw["alive"] or String(tw["tier"]) == "cairn":
			continue
		if SimData.du(tw["pos"], center) <= r:
			tower_side = String(tw["side"])
			tower_dmg = float(tw["dmg"])
			return


func _team_factors() -> void:
	var n := heroes.size()
	for side in ["B", "R"]:
		team_k[side] = sim.fight_factor(side, kind, n, t0, rng)


func _active(h: SimHero) -> bool:
	var s: Dictionary = st[h.key]
	return h.alive and not s["fled"] and t >= float(s["join"])


func _side_active(side: String) -> Array:
	if _act_dirty:
		var b: Array = []
		var r: Array = []
		for h in heroes:
			var hh: SimHero = h
			if _active(hh):
				if hh.side == "B":
					b.append(hh)
				else:
					r.append(hh)
		_act = {"B": b, "R": r}
		_act_dirty = false
	return _act[side]


func _over() -> bool:
	var b := _side_active("B").size()
	var r := _side_active("R").size()
	var pending := false
	for h in heroes:
		if h.alive and t < float(st[h.key]["join"]):
			pending = true
	if (b == 0 or r == 0) and not pending:
		return true
	return t - last_damage_t > 2.5


func _strength(side: String) -> float:
	var v := 0.0
	for h in _side_active(side):
		v += h.hp / maxf(1.0, h.max_hp) * (0.6 + 0.4 * float(h.level) / 15.0) * float(team_k[side]) * h.qe(t)
	return v


func _step(dt: float) -> void:
	_act_dirty = true
	var order: Array = heroes.duplicate()
	# stable order: by side then slot index (deterministic), shuffled per step by the fight stream
	for i in range(order.size() - 1, 0, -1):
		var j := int(rng.next_float() * float(i + 1))
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for h in order:
		var hh: SimHero = h
		if not _active(hh):
			continue
		var s: Dictionary = st[hh.key]
		s["in_fight"] = true
		_expire(s)
		if t < float(s["cc"]):
			continue
		if _maybe_flee(hh, s):
			continue
		if not _cast(hh, s):
			_attack(hh, s)
	_tower_shot()


func _expire(s: Dictionary) -> void:
	var keep: Array = []
	for b in s["buffs"]:
		if float(b[0]) > t:
			keep.append(b)
	s["buffs"] = keep


func _buff(s: Dictionary, k: String) -> float:
	var v := 0.0
	for b in s["buffs"]:
		v += float((b[1] as Dictionary).get(k, 0.0))
	return v


func _reachable(att: SimHero, s: Dictionary, tgt: SimHero) -> bool:
	var ts: Dictionary = st[tgt.key]
	if t < float(ts["untarget"]):
		return false
	if int(ts["row"]) == 0 or row_of(att) == 1 or bool(s["dived"]):
		return true
	if att.stat("range_u") > 0.02:
		return true
	for e in _side_active(tgt.side):
		if int(st[e.key]["row"]) == 0:
			return false
	return true


func _pick_target(h: SimHero, s: Dictionary, prefer_back: bool) -> SimHero:
	var cand: Array = []
	for e in _side_active(SimData.other(h.side)):
		if _reachable(h, s, e):
			cand.append(e)
	if cand.is_empty():
		return null
	# taunted: the taunter if reachable
	var tft := h.st("tft") / 100.0
	if rng.next_float() < 0.35 + 0.55 * tft:
		var best: SimHero = null
		var bv := INF
		for e in cand:
			var ee: SimHero = e
			var v := ee.hp / maxf(1.0, ee.max_hp) * (1.0 + 0.15 * float(int(st[ee.key]["row"]) == 0 and prefer_back))
			v *= 1.0 + 0.002 * (ee.stat("armor") + ee.stat("resist"))
			if v < bv:
				bv = v
				best = ee
		return best
	return cand[int(rng.next_float() * cand.size())]


func _lowest_ally(h: SimHero, below: float) -> SimHero:
	var best: SimHero = null
	var bv := below
	for a in _side_active(h.side):
		var aa: SimHero = a
		var f := aa.hp / maxf(1.0, aa.max_hp)
		if f < bv:
			bv = f
			best = aa
	return best


func _ready_ab(h: SimHero, i: int) -> bool:
	var a := h.ability(i)
	return float(h.cds[i]) <= t and h.level >= int(a["unlock"])


func _cd_of(h: SimHero, a: Dictionary) -> float:
	var cd := float(a["cd"]) + float(a["cd_lvl"]) * float(h.level - 1)
	return maxf(1.0, cd * (1.0 - h.stat("haste") / 100.0))


## Try one ability; true when something was cast.
func _cast(h: SimHero, s: Dictionary) -> bool:
	if t < float(s["silence"]):
		return false
	var enemies := _side_active(SimData.other(h.side))
	if enemies.is_empty():
		return false
	for i in [3, 0, 1, 2]:
		if not _ready_ab(h, i):
			continue
		var a := h.ability(i)
		var kinds: Array = a["kind"]
		var tgt_kind := String(a["target"])
		# supports: heals and shields go to the most hurt ally
		if tgt_kind in ["ally", "self"] or (tgt_kind == "area" and ("heal" in kinds or "shield" in kinds) and not "damage" in kinds):
			if "heal" in kinds or "shield" in kinds or "buff" in kinds or "stealth" in kinds or "mobility" in kinds:
				var ally := h if tgt_kind == "self" else _lowest_ally(h, 0.75 if ("heal" in kinds) else 0.85)
				if tgt_kind == "self":
					if "mobility" in kinds and not ("shield" in kinds or "heal" in kinds or "buff" in kinds or "stealth" in kinds):
						# a pure dash: dive to the back row (melee) or keep for the escape
						if row_of(h) == 0 or h.arch == "shade":
							if not bool(s["dived"]):
								s["dived"] = true
								_put_cd(h, i, a, s)
								return true
						continue
					if ("shield" in kinds or "buff" in kinds) and h.hp / h.max_hp > 0.85 and not "stealth" in kinds:
						continue
				if ally == null:
					continue
				_apply_support(h, ally, a, s)
				_put_cd(h, i, a, s)
				return true
			continue
		if i == 3 and enemies.size() < 2 and not ("execute" in kinds):
			var only: SimHero = enemies[0]
			if only.hp / only.max_hp > 0.6:
				continue
		var tgt := _pick_target(h, s, h.arch == "shade")
		if tgt == null and "mobility" in kinds:
			s["dived"] = true
			tgt = _pick_target(h, s, true)
		if tgt == null:
			continue
		if "mobility" in kinds:
			s["dived"] = true
		_put_cd(h, i, a, s)
		_ability_hit(h, s, a, tgt, i)
		return true
	return false


func _put_cd(h: SimHero, i: int, a: Dictionary, s: Dictionary) -> void:
	h.cds[i] = t + _cd_of(h, a)
	s["casts"] = int(s["casts"]) + 1
	s["spellblade"] = h.has_effect("spellblade")
	_on_ability_passive(h, s)


func _hit_chance(h: SimHero, a: Dictionary, tgt: SimHero) -> float:
	var m := SimData.f("hit_mec")
	var p := float(a["hit"]) * (1.0 - m + m * h.st("mec") / 100.0)
	var ts: Dictionary = st[tgt.key]
	if t < float(ts["cc"]) or t < float(ts["root"]):
		return 1.0
	if t < float(ts["slow"]):
		p = minf(1.0, p + 0.08)
	return p


func _targets_for(h: SimHero, s: Dictionary, a: Dictionary, tgt: SimHero) -> Array:
	var out: Array = [tgt]
	var tk := String(a["target"])
	if tk == "area" or tk == "line" or "wave" in a["kind"]:
		var extra := 1 if tk == "line" else 2
		extra = int(float(extra) * clampf(float(a["radius_u"]) / 0.025, 0.6, 1.6) + rng.next_float() * 0.99)
		var row := int(st[tgt.key]["row"])
		for e in _side_active(tgt.side):
			if out.size() > extra:
				break
			var ee: SimHero = e
			if ee == tgt or not _reachable(h, s, ee):
				continue
			if int(st[ee.key]["row"]) == row or rng.next_float() < 0.35:
				out.append(ee)
	return out


func _ability_hit(h: SimHero, s: Dictionary, a: Dictionary, tgt: SimHero, i: int) -> void:
	var kinds: Array = a["kind"]
	var targets := _targets_for(h, s, a, tgt)
	var any_hit := false
	for e in targets:
		var ee: SimHero = e
		if rng.next_float() > _hit_chance(h, a, ee):
			continue
		any_hit = true
		if "damage" in kinds or "execute" in kinds:
			var dmg := _ability_damage(h, a, ee, i)
			_deal(h, ee, dmg, String(a["dtype"]), true)
		if String(a["cc"]) != "":
			_apply_cc(h, ee, String(a["cc"]), float(a["cc_s"]))
		if "shield" in kinds and String(a["target"]) == "area":
			_shield(h, h, a)
	if "shield" in kinds and String(a["target"]) != "area":
		_shield(h, h, a)
	if "heal" in kinds:
		var amt := _heal_amount(h, a)
		_heal(h, h, amt * 0.5)
	events.append([t, "cast", h.key, String(a["id"]), tgt.key, any_hit])
	if not (a["buff"] as Dictionary).is_empty():
		s["buffs"].append([t + maxf(1.0, float(a["dur_s"])), a["buff"]])


func _ability_damage(h: SimHero, a: Dictionary, tgt: SimHero, i: int) -> float:
	var lvl := float(h.level - 1)
	var dmg := float(a["dmg"]) + float(a["dmg_lvl"]) * lvl
	if String(a["dtype"]) == "magic":
		dmg += float(a["ratio"]) * h.stat("ap") * SimData.f("ap_ratio_scale")
	else:
		dmg += float(a["ratio"]) * h.stat("atk") * 0.5
	if "execute" in a["kind"]:
		var frac := tgt.hp / maxf(1.0, tgt.max_hp)
		dmg *= 1.0 + 0.6 * (1.0 - frac)
		if frac < float(a["exec_below"]):
			dmg *= 1.5
	if i == 3:
		dmg *= SimData.f("ult_scale")
	return dmg * SimData.f("dmg_scale")


func _mitigate(att: SimHero, tgt: SimHero, dmg: float, dtype: String) -> float:
	if dtype == "true":
		return dmg
	var ts: Dictionary = st.get(tgt.key, {})
	var arm: float
	if dtype == "magic":
		arm = (tgt.stat("resist") + (_buff(ts, "resist") if not ts.is_empty() else 0.0)) * (1.0 - att.stat("pen_resist"))
	else:
		arm = (tgt.stat("armor") + (_buff(ts, "armor") if not ts.is_empty() else 0.0)) * (1.0 - att.stat("pen_armor"))
	var k := SimData.f("armor_k")
	var dr := 0.0 if ts.is_empty() else _buff(ts, "dr")
	return dmg * k / (k + maxf(0.0, arm)) * (1.0 - clampf(dr, 0.0, 0.6))


func _deal(att: SimHero, tgt: SimHero, raw: float, dtype: String, from_ability: bool) -> void:
	var ts: Dictionary = st[tgt.key]
	if t < float(ts["untarget"]):
		return
	var dmg := raw * att.qe(t) * float(team_k[att.side])
	var p := tgt.passive()
	if String(p["trigger"]) == "low_hp" and String(p["stat"]) == "dr" and tgt.hp / tgt.max_hp > 0.5:
		dmg *= 1.0 - float(p["amount"])
	var ap := att.passive()
	if String(ap["trigger"]) == "low_hp" and String(ap["stat"]) == "dmg_amp" and tgt.hp / tgt.max_hp < 0.33:
		dmg *= 1.0 + float(ap["amount"])
	if String(ap["trigger"]) == "isolated" and _side_active(tgt.side).size() == 1:
		dmg *= 1.0 + float(ap["amount"])
	if bool(ts["mark"]) and att.slot != "":
		dmg *= 1.08
	if att.has_effect("execute") and tgt.hp / tgt.max_hp < 0.25:
		dmg *= 1.12
	dmg = _mitigate(att, tgt, dmg, dtype)
	if att.has_effect("burn") and from_ability:
		dmg += 12.0 + 0.04 * att.stat("ap") + 0.002 * att.stat("hp")
	var sh := float(ts["shield"])
	var absorbed := minf(sh, dmg)
	ts["shield"] = sh - absorbed
	var rest := dmg - absorbed
	tgt.hp -= rest
	tgt.dmg_taken += dmg
	att.dmg_heroes += dmg
	tgt.last_hit_by[att.key] = t
	last_damage_t = t
	var vamp := att.stat("omnivamp") + (att.stat("lifesteal") if not from_ability else 0.0) + _buff(st[att.key], "lifesteal")
	if vamp > 0.0:
		_heal(att, att, dmg * vamp * (0.6 if tgt.has_effect("antiheal") else 1.0))
	if att.has_effect("antiheal"):
		ts["antiheal"] = t + 3.0
	# low-health passives of the target
	if String(p["trigger"]) == "low_hp" and int(p["shield"]) > 0 and tgt.hp > 0.0 and tgt.hp / tgt.max_hp < 0.3 and t - float(ts["low_used"]) >= float(p["cd"]):
		ts["low_used"] = t
		ts["shield"] = float(ts["shield"]) + float(p["shield"]) * (1.0 + 0.08 * float(tgt.level))
	if tgt.has_effect("guard") and tgt.hp > 0.0 and tgt.hp / tgt.max_hp < 0.3 and t - float(ts["low_used"]) >= 45.0:
		ts["low_used"] = t
		ts["shield"] = float(ts["shield"]) + 120.0 + 12.0 * float(tgt.level)
	if tgt.hp <= 0.0:
		if tgt.has_effect("revive_once") and not tgt.revive_used:
			tgt.revive_used = true
			tgt.hp = 1.0
			ts["untarget"] = t + 2.0
			ts["cc"] = t + 2.0
			events.append([t, "stasis", tgt.key])
			return
		_kill(att, tgt)


func _kill(att: SimHero, tgt: SimHero) -> void:
	tgt.hp = 0.0
	_act_dirty = true
	var assists: Array = []
	for k in tgt.last_hit_by:
		if k != att.key and t - float(tgt.last_hit_by[k]) <= 10.0:
			assists.append(k)
	assists.sort()
	kills.append({"t": t, "killer": att.key, "victim": tgt.key, "assists": assists})
	sim.on_kill(att, tgt, assists, t)
	events.append([t, "kill", att.key, tgt.key, assists])
	var ap := att.passive()
	if String(ap["trigger"]) == "on_kill":
		att.stacks += 1


func _apply_cc(att: SimHero, tgt: SimHero, cc: String, dur: float) -> void:
	var ts: Dictionary = st[tgt.key]
	var amp := 1.0
	var ap := att.passive()
	if String(ap["stat"]) == "cc_amp" and t < float(ts["slow"]):
		amp += float(ap["amount"])
	dur *= amp
	tgt.last_hit_by[att.key] = t
	match cc:
		"stun", "knockup", "taunt":
			ts["cc"] = maxf(float(ts["cc"]), t + dur)
		"root":
			ts["root"] = maxf(float(ts["root"]), t + dur)
			if int(ts["row"]) == 0 and row_of(tgt) == 0:
				ts["cc"] = maxf(float(ts["cc"]), t + dur * 0.5)    # a rooted melee hero cannot reach anyone for a while
		"silence":
			ts["silence"] = maxf(float(ts["silence"]), t + dur)
		"slow":
			ts["slow"] = maxf(float(ts["slow"]), t + dur)
	if String(ap["stat"]) == "mark":
		ts["mark"] = true


func _heal_amount(h: SimHero, a: Dictionary) -> float:
	var base := float(a["heal"]) + 6.0 * float(h.level) + float(a["ratio_def"]) * h.stat("ap")
	var amp := 1.0 + h.stat("heal_power")
	var p := h.passive()
	if String(p["stat"]) == "heal_amp":
		amp += float(p["amount"]) * 0.5
	return base * amp * SimData.f("heal_scale")


func _apply_support(h: SimHero, ally: SimHero, a: Dictionary, s: Dictionary) -> void:
	var kinds: Array = a["kind"]
	if "heal" in kinds:
		var amt := _heal_amount(h, a)
		if String(a["target"]) == "area":
			for x in _side_active(h.side):
				_heal(h, x, amt * 0.7)
		else:
			_heal(h, ally, amt)
	if "shield" in kinds:
		_shield(h, ally, a)
		if String(a["target"]) == "area":
			for x in _side_active(h.side):
				if x != ally:
					_shield(h, x, a, 0.6)
	if "stealth" in kinds:
		s["untarget"] = t + 1.0
	if "mobility" in kinds and String(a["target"]) == "self":
		s["dived"] = true
	if not (a["buff"] as Dictionary).is_empty():
		var tgt_s: Dictionary = st[ally.key]
		tgt_s["buffs"].append([t + maxf(1.0, float(a["dur_s"])), a["buff"]])
		if (a["buff"] as Dictionary).has("untargetable"):
			tgt_s["untarget"] = t + float(a["buff"]["untargetable"])
	if String(a["cc"]) != "":
		var tgt := _pick_target(h, s, false)
		if tgt != null:
			_apply_cc(h, tgt, String(a["cc"]), float(a["cc_s"]))
	events.append([t, "cast", h.key, String(a["id"]), ally.key, true])


func _shield(h: SimHero, to: SimHero, a: Dictionary, mult: float = 1.0) -> void:
	var amt := float(a["shield"]) + 8.0 * float(h.level) + float(a["ratio_def"]) * (h.stat("hp") if h.arch in ["bulwark", "bruiser"] else h.stat("ap"))
	amt *= (1.0 + h.stat("shield_power")) * h.qe(t) * mult * SimData.f("heal_scale")
	var s2: Dictionary = st[to.key]
	s2["shield"] = float(s2["shield"]) + amt
	h.healed += amt * 0.5


func _heal(h: SimHero, to: SimHero, amt: float) -> void:
	if not to.alive:
		return
	var s2: Dictionary = st.get(to.key, {})
	if not s2.is_empty() and float(s2.get("antiheal", -1.0)) > t:
		amt *= 0.6
	amt *= h.qe(t)
	var before := to.hp
	to.hp = minf(to.max_hp, to.hp + amt)
	if h != to:
		h.healed += to.hp - before


func _on_ability_passive(h: SimHero, s: Dictionary) -> void:
	var p := h.passive()
	if String(p["trigger"]) != "on_ability":
		return
	var every := int(p["every"])
	if every > 0 and int(s["casts"]) % every != 0:
		return
	if int(p["shield"]) > 0:
		s["shield"] = float(s["shield"]) + float(p["shield"]) * (1.0 + 0.06 * float(h.level))
	if int(p["heal"]) > 0:
		_heal(h, h, float(p["heal"]) * (1.0 + 0.06 * float(h.level)))
	if String(p["stat"]) in ["aspd", "move"]:
		s["buffs"].append([t + 3.0, {String(p["stat"]): float(p["amount"])}])
	if int(p["bonus_dmg"]) > 0 or String(p["cc"]) != "":
		s["spellblade"] = true


func _attack(h: SimHero, s: Dictionary) -> void:
	if t < float(s["next_atk"]):
		return
	var tgt := _pick_target(h, s, h.arch == "shade")
	if tgt == null:
		return
	var aspd := clampf(h.stat("aspd") * (1.0 + _buff(s, "aspd")), 0.3, 2.5)
	if t < float(s["slow"]):
		aspd *= 0.85
	s["next_atk"] = t + 1.0 / aspd
	var dmg := h.stat("atk")
	var crit := h.stat("crit") + _buff(s, "crit")
	var p := h.passive()
	if String(p["trigger"]) == "out_of_combat" and bool(s["first_attack"]) and String(p["stat"]) == "crit":
		crit += float(p["amount"])
	if String(p["trigger"]) == "out_of_combat" and bool(s["first_attack"]) and int(p["shield"]) > 0:
		s["shield"] = float(s["shield"]) + float(p["shield"]) * (1.0 + 0.06 * float(h.level))
	s["first_attack"] = false
	if rng.next_float() < crit:
		dmg *= SimData.f("crit_mult") + (SimData.f("crit_amp") if h.has_effect("crit_amp") else 0.0)
	s["hits"] = int(s["hits"]) + 1
	var bonus := 0.0
	if String(p["trigger"]) == "on_hit_nth" and int(p["every"]) > 0 and int(s["hits"]) % int(p["every"]) == 0:
		bonus += float(p["bonus_dmg"]) + float(p["ratio"]) * (h.stat("atk") * 0.5 + h.stat("ap"))
		if int(p["heal"]) > 0:
			_heal(h, h, float(p["heal"]) * (1.0 + 0.06 * float(h.level)))
		if String(p["cc"]) != "":
			_apply_cc(h, tgt, String(p["cc"]), float(p["cc_s"]))
	if bool(s["spellblade"]):
		s["spellblade"] = false
		bonus += 0.6 * h.stat("atk") + 0.3 * h.stat("ap")
		if String(p["trigger"]) == "on_ability":
			bonus += float(p["bonus_dmg"]) + float(p["ratio"]) * (h.stat("atk") * 0.5 + h.stat("ap"))
			if String(p["cc"]) != "":
				_apply_cc(h, tgt, String(p["cc"]), float(p["cc_s"]))
	if h.has_effect("on_hit"):
		bonus += 15.0 + 0.1 * h.stat("ap") + 0.2 * float(h.level)
	_deal(h, tgt, dmg, "phys", false)
	if bonus > 0.0 and tgt.alive and tgt.hp > 0.0:
		_deal(h, tgt, bonus, "magic" if h.stat("ap") > h.stat("atk") else "phys", false)
	if h.has_effect("slow_on_hit") and tgt.hp > 0.0:
		st[tgt.key]["slow"] = maxf(float(st[tgt.key]["slow"]), t + 1.0)
	if h.has_effect("splash"):
		for e in _side_active(tgt.side):
			if e != tgt:
				_deal(h, e, dmg * 0.3, "phys", false)
				break


func _maybe_flee(h: SimHero, s: Dictionary) -> bool:
	if float(s["flee_at"]) >= 0.0:
		if t >= float(s["flee_at"]):
			s["fled"] = true
			_act_dirty = true
			events.append([t, "flee", h.key])
		return true
	var frac := h.hp / maxf(1.0, h.max_hp)
	var sen := h.st("sen") / 100.0
	var thr := SimData.f("retreat_hp_lo") + (SimData.f("retreat_hp_hi") - SimData.f("retreat_hp_lo")) * sen
	if frac >= thr:
		return false
	var mine := _strength(h.side)
	var theirs := _strength(SimData.other(h.side))
	if mine >= theirs * (0.85 + 0.3 * sen):
		return false
	# a dash shortens the time exposed while running
	var exposed := 1.2
	for i in 3:
		if "mobility" in h.ability(i)["kind"] and _ready_ab(h, i):
			exposed = 0.5
			h.cds[i] = t + _cd_of(h, h.ability(i))
			break
	if t < float(s["root"]) or t < float(s["slow"]):
		exposed += 0.6
	s["flee_at"] = t + exposed
	return true


func _tower_shot() -> void:
	if tower_side == "":
		return
	# one shot a second at the attacker nearest the tower (front row first) that has hit an enemy hero
	if int(t * 4.0) % 4 != 0:
		return
	var best: SimHero = null
	for h in _side_active(SimData.other(tower_side)):
		var hh: SimHero = h
		if hh.dmg_heroes <= 0.0:
			continue
		if best == null or int(st[hh.key]["row"]) < int(st[best.key]["row"]):
			best = hh
	if best == null:
		return
	var dmg := tower_dmg * (1.0 + 0.04 * float(sim.minute(t)))
	var k := SimData.f("armor_k")
	dmg = dmg * k / (k + best.stat("armor") * 0.5)
	best.hp -= dmg
	last_damage_t = t
	if best.hp <= 0.0:
		best.hp = 0.0
		_act_dirty = true
		var assists: Array = []
		for kk in best.last_hit_by:
			if t - float(best.last_hit_by[kk]) <= 10.0:
				assists.append(kk)
		assists.sort()
		var killer := ""
		var last_t := -INF
		for kk in assists:
			if float(best.last_hit_by[kk]) > last_t:
				last_t = float(best.last_hit_by[kk])
				killer = kk
		var kh: SimHero = sim.hero_by_key(killer) if killer != "" else null
		if kh != null:
			assists.erase(killer)
			kills.append({"t": t, "killer": killer, "victim": best.key, "assists": assists})
			sim.on_kill(kh, best, assists, t)
			events.append([t, "kill", killer, best.key, assists])
		else:
			sim.on_tower_kill(best, tower_side, t)    # logs the kill itself
