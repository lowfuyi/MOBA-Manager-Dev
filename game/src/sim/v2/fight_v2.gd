class_name FightV2
extends RefCounted
## The fight resolver of Match Sim v2 (MATCH-SIM-V2-DESIGN 5.4). Runs one fight in steps of fight_dt (0.25 s) of game time over
## the heroes in it and those who arrive: target choice by role and TFT, casts by kit (landing by MEC), damage after armour and
## resistance, crowd control, shields and heals, item effects, passives, retreats by SEN and kills with assists.
## Positions inside a fight are rows: front (bruisers, bulwarks) and back (everyone else). A melee hero reaches the back row
## only after a dash (a mobility ability) or once the enemy front row is gone. Towers in range shoot the side that dives them.
## Deterministic: every draw comes from the fight's own PCG32 stream; no libm calls. Per-hero fight state is a typed FS object.

const T_ENEMY := 0
const T_ALLY := 1
const T_SELF := 2
const T_AREA := 3
const T_LINE := 4
const CC_HARD := 1
const CC_ROOT := 2
const CC_SILENCE := 3
const CC_SLOW := 4


## A hero's state inside one fight.
class FS:
	var h: SimHero
	var join := 0.0
	var row := 0
	var cc := 0.0
	var root := 0.0
	var silence := 0.0
	var slow := 0.0
	var shield := 0.0
	var untarget := 0.0
	var next_atk := 0.0
	var dived := false
	var fled := false
	var flee_at := -1.0
	var hits := 0
	var casts := 0
	var buffs: Array = []        # [[until, {stat: amount}], ...]
	var b_dr := 0.0
	var b_armor := 0.0
	var b_resist := 0.0
	var b_aspd := 0.0
	var b_ls := 0.0
	var b_crit := 0.0
	var spellblade := false
	var first_attack := true
	var low_used := -999.0
	var mark := false
	var antiheal := -1.0

	func add_buff(until: float, b: Dictionary) -> void:
		buffs.append([until, b])
		_sum()

	func expire(t: float) -> void:
		if buffs.is_empty():
			return
		var keep: Array = []
		for b in buffs:
			if float(b[0]) > t:
				keep.append(b)
		if keep.size() != buffs.size():
			buffs = keep
			_sum()

	func _sum() -> void:
		b_dr = 0.0
		b_armor = 0.0
		b_resist = 0.0
		b_aspd = 0.0
		b_ls = 0.0
		b_crit = 0.0
		for b in buffs:
			var d: Dictionary = b[1]
			b_dr += float(d.get("dr", 0.0))
			b_armor += float(d.get("armor", 0.0))
			b_resist += float(d.get("resist", 0.0))
			b_aspd += float(d.get("aspd", 0.0))
			b_ls += float(d.get("lifesteal", 0.0))
			b_crit += float(d.get("crit", 0.0))


var sim: MatchSimV2
var rng: Pcg32
var heroes: Array = []       # SimHero
var t := 0.0
var t0 := 0.0
var center := Vector2.ZERO
var fid := 0
var kind := ""               # skirmish | gank | objective | siege | teamfight
var st: Dictionary = {}      # hero key -> FS
var tower_side := ""         # the side whose tower covers the fight ("" = none)
var tower_dmg := 0.0
var k_b := 1.0               # team factors (CompMod, style, plan, noise)
var k_r := 1.0
var events: Array = []
var kills: Array = []        # [{t, killer, victim, assists}]
var last_damage_t := 0.0
var _act_b: Array = []
var _act_r: Array = []
var _act_dirty := true
var _str_b := -1.0
var _str_r := -1.0
var _armor_k := 100.0
var _crit_mult := 1.75
var _crit_amp := 0.35
var _hit_mec := 0.25
var _dmg_scale := 1.0
var _ult_scale := 1.0
var _heal_scale := 1.0
var _ap_scale := 1.0
var _ret_lo := 0.22
var _ret_hi := 0.4


static func row_of(h: SimHero) -> int:
	return 0 if h.front else 1


func team_k(side: String) -> float:
	return k_b if side == "B" else k_r


## participants: [[SimHero, join_delay_s], ...]
func run(p_sim: MatchSimV2, participants: Array, p_t0: float, p_center: Vector2, p_kind: String, p_fid: int) -> void:
	sim = p_sim
	t0 = p_t0
	t = p_t0
	center = p_center
	kind = p_kind
	fid = p_fid
	rng = Pcg32.contest_stream(int(sim.mseed), "v2:fight:%d" % fid)
	_armor_k = SimData.f("armor_k")
	_crit_mult = SimData.f("crit_mult")
	_crit_amp = SimData.f("crit_amp")
	_hit_mec = SimData.f("hit_mec")
	_dmg_scale = SimData.f("dmg_scale")
	_ult_scale = SimData.f("ult_scale")
	_heal_scale = SimData.f("heal_scale")
	_ap_scale = SimData.f("ap_ratio_scale")
	_ret_lo = SimData.f("retreat_hp_lo")
	_ret_hi = SimData.f("retreat_hp_hi")
	for pr in participants:
		var h: SimHero = pr[0]
		heroes.append(h)
		var fs := FS.new()
		fs.h = h
		fs.join = t0 + float(pr[1])
		fs.row = row_of(h)
		fs.next_atk = fs.join + 0.3 * rng.next_float()
		st[h.key] = fs
	_tower_cover()
	k_b = sim.fight_factor("B", kind, heroes.size(), t0, rng)
	k_r = sim.fight_factor("R", kind, heroes.size(), t0, rng)
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
		_step()
		t += dt
		_hp_sample()
		if _over():
			break
	for h in heroes:
		h.busy_until = maxf(h.busy_until, t)
	events.append([t, "fight_end", fid])
	# 0.12: the log says which fights decided games (the camera used to guess): decisive_kills kills or more in this fight
	var nk := 0
	for e in events:
		if String(e[1]) == "kill":
			nk += 1
	if nk >= int(SimData.params().get("decisive_kills", 3)):
		events.append([t, "decisive", "fight", fid, nk])


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


func _active(h: SimHero) -> bool:
	var s: FS = st[h.key]
	return h.alive and not s.fled and t >= s.join


func _side_active(side: String) -> Array:
	if _act_dirty:
		_act_b = []
		_act_r = []
		for h in heroes:
			var hh: SimHero = h
			if _active(hh):
				if hh.side == "B":
					_act_b.append(hh)
				else:
					_act_r.append(hh)
		_act_dirty = false
	return _act_b if side == "B" else _act_r


func _over() -> bool:
	_act_dirty = true
	var b := _side_active("B").size()
	var r := _side_active("R").size()
	var pending := false
	for h in heroes:
		var hh: SimHero = h
		if hh.alive and t < (st[hh.key] as FS).join:
			pending = true
	if (b == 0 or r == 0) and not pending:
		return true
	return t - last_damage_t > 2.5


func _strength(side: String) -> float:
	var c := _str_b if side == "B" else _str_r
	if c >= 0.0:
		return c
	var v := 0.0
	var k := team_k(side)
	for h in _side_active(side):
		var hh: SimHero = h
		v += hh.hp / maxf(1.0, hh.max_hp) * (0.6 + 0.4 * float(hh.level) / 15.0) * k * hh.qe(t)
	if side == "B":
		_str_b = v
	else:
		_str_r = v
	return v


func _step() -> void:
	_act_dirty = true
	_str_b = -1.0
	_str_r = -1.0
	var order: Array = heroes.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := int(rng.next_float() * float(i + 1))
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for h in order:
		var hh: SimHero = h
		if not _active(hh):
			continue
		var s: FS = st[hh.key]
		s.expire(t)
		if t < s.cc:
			continue
		if _maybe_flee(hh, s):
			continue
		if not _cast(hh, s):
			_attack(hh, s)
	_tower_shot()


func _reachable(att: SimHero, s: FS, tgt: SimHero) -> bool:
	var ts: FS = st[tgt.key]
	if t < ts.untarget:
		return false
	if ts.row == 0 or not att.front or s.dived or att.ranged:
		return true
	for e in _side_active(tgt.side):
		if (st[(e as SimHero).key] as FS).row == 0:
			return false
	return true


func _pick_target(h: SimHero, s: FS, prefer_back: bool) -> SimHero:
	var cand: Array = []
	for e in _side_active(SimData.other(h.side)):
		if _reachable(h, s, e):
			cand.append(e)
	if cand.is_empty():
		return null
	if rng.next_float() < 0.35 + 0.55 * h.p_tft / 100.0:
		var best: SimHero = null
		var bv := INF
		for e in cand:
			var ee: SimHero = e
			var v := ee.hp / maxf(1.0, ee.max_hp) * (1.15 if prefer_back and (st[ee.key] as FS).row == 0 else 1.0)
			v *= 1.0 + 0.002 * (ee.s_armor + ee.s_resist)
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


func _cd_of(h: SimHero, a: SimHero.Ability) -> float:
	var cd := a.cd + a.cd_lvl * float(h.level - 1)
	return maxf(1.0, cd * (1.0 - h.s_haste / 100.0))


const CAST_ORDER := [3, 0, 1, 2]


## Try one ability; true when something was cast.
func _cast(h: SimHero, s: FS) -> bool:
	if t < s.silence:
		return false
	var enemies := _side_active(SimData.other(h.side))
	if enemies.is_empty():
		return false
	for i in CAST_ORDER:
		if float(h.cds[i]) > t:
			continue
		var a: SimHero.Ability = h.abil[i]
		if h.level < a.unlock:
			continue
		var support_area := a.target == T_AREA and (a.heal_k or a.shield_k) and not a.dmg_k
		if a.target == T_ALLY or a.target == T_SELF or support_area:
			if not (a.heal_k or a.shield_k or a.buff_k or a.stealth or a.mob):
				continue
			var ally: SimHero = h
			if a.target == T_SELF:
				if a.mob and not (a.shield_k or a.heal_k or a.buff_k or a.stealth):
					# a pure dash: dive to the back row (melee and shades) or keep it for the escape
					if (h.front or h.arch == "shade") and not s.dived:
						s.dived = true
						_put_cd(h, i, a, s)
						return true
					continue
				if (a.shield_k or a.buff_k) and h.hp / h.max_hp > 0.85 and not a.stealth:
					continue
			else:
				ally = _lowest_ally(h, 0.75 if a.heal_k else 0.85)
			if ally == null:
				continue
			_apply_support(h, ally, a, s)
			_put_cd(h, i, a, s)
			return true
		if i == 3 and enemies.size() < 2 and not a.execute:
			var only: SimHero = enemies[0]
			if only.hp / only.max_hp > 0.6:
				continue
		var tgt := _pick_target(h, s, h.arch == "shade")
		if tgt == null and a.mob:
			s.dived = true
			tgt = _pick_target(h, s, true)
		if tgt == null:
			continue
		if a.mob:
			s.dived = true
		_put_cd(h, i, a, s)
		_ability_hit(h, s, a, tgt, i)
		return true
	return false


func _put_cd(h: SimHero, i: int, a: SimHero.Ability, s: FS) -> void:
	h.cds[i] = t + _cd_of(h, a)
	s.casts += 1
	s.spellblade = h.e_spellblade
	_on_ability_passive(h, s)


func _hit_chance(h: SimHero, a: SimHero.Ability, tgt: SimHero) -> float:
	var p := a.hit * (1.0 - _hit_mec + _hit_mec * h.p_mec / 100.0)
	var ts: FS = st[tgt.key]
	if t < ts.cc or t < ts.root:
		return 1.0
	if t < ts.slow:
		p = minf(1.0, p + 0.08)
	return p


func _targets_for(h: SimHero, s: FS, a: SimHero.Ability, tgt: SimHero) -> Array:
	var out: Array = [tgt]
	if a.target == T_AREA or a.target == T_LINE or a.wave:
		var extra := 1 if a.target == T_LINE else 2
		extra = int(float(extra) * clampf(a.radius / 0.025, 0.6, 1.6) + rng.next_float() * 0.99)
		var row := (st[tgt.key] as FS).row
		for e in _side_active(tgt.side):
			if out.size() > extra:
				break
			var ee: SimHero = e
			if ee == tgt or not _reachable(h, s, ee):
				continue
			if (st[ee.key] as FS).row == row or rng.next_float() < 0.35:
				out.append(ee)
	return out


func _ability_hit(h: SimHero, s: FS, a: SimHero.Ability, tgt: SimHero, i: int) -> void:
	var targets := _targets_for(h, s, a, tgt)
	var any_hit := false
	for e in targets:
		var ee: SimHero = e
		if rng.next_float() > _hit_chance(h, a, ee):
			continue
		any_hit = true
		if a.dmg_k or a.execute:
			_deal(h, ee, _ability_damage(h, a, ee, i), 1 if a.magic else 0, true)
		if a.cc != 0 and ee.alive:
			_apply_cc(h, ee, a.cc, a.cc_s)
		if a.shield_k and a.target == T_AREA:
			_shield(h, h, a)
	if a.shield_k and a.target != T_AREA:
		_shield(h, h, a)
	if a.heal_k:
		_heal(h, h, _heal_amount(h, a) * 0.5)
	if a.ally_heal > 0.0 and any_hit:
		# 0.11.2: an enemy-side ability that also mends the caster's team a little (Fen Fog)
		var amt := (a.ally_heal + 4.0 * float(h.level)) * _heal_scale
		for x in _side_active(h.side):
			_heal(h, x, amt)
	events.append([t, "cast", h.key, a.id, tgt.key, any_hit])
	if not a.buff.is_empty():
		s.add_buff(t + maxf(1.0, a.dur), a.buff)


func _ability_damage(h: SimHero, a: SimHero.Ability, tgt: SimHero, i: int) -> float:
	var dmg := a.dmg + a.dmg_lvl * float(h.level - 1)
	if a.magic:
		dmg += a.ratio * h.s_ap * _ap_scale
	else:
		dmg += a.ratio * h.s_atk * 0.5
	if a.execute:
		var frac := tgt.hp / maxf(1.0, tgt.max_hp)
		dmg *= 1.0 + 0.6 * (1.0 - frac)
		if frac < a.exec_below:
			dmg *= 1.5
	if i == 3:
		dmg *= _ult_scale
	return dmg * _dmg_scale


## dtype: 0 physical, 1 magic, 2 true
func _mitigate(att: SimHero, tgt: SimHero, dmg: float, dtype: int) -> float:
	if dtype == 2:
		return dmg
	var ts: FS = st[tgt.key]
	var arm: float
	if dtype == 1:
		arm = (tgt.s_resist + ts.b_resist) * (1.0 - att.s_pen_r)
	else:
		arm = (tgt.s_armor + ts.b_armor) * (1.0 - att.s_pen_a)
	return dmg * _armor_k / (_armor_k + maxf(0.0, arm)) * (1.0 - clampf(ts.b_dr, 0.0, 0.6))


func _deal(att: SimHero, tgt: SimHero, raw: float, dtype: int, from_ability: bool) -> void:
	var ts: FS = st[tgt.key]
	if t < ts.untarget:
		return
	var dmg := raw * att.qe(t) * team_k(att.side) * att.bal_dmg
	var p := tgt.pas
	var frac := tgt.hp / maxf(1.0, tgt.max_hp)
	if p.trigger == "low_hp" and p.stat == "dr" and frac > 0.5:
		dmg *= 1.0 - p.amount
	var ap := att.pas
	if ap.trigger == "low_hp" and ap.stat == "dmg_amp" and frac < 0.33:
		dmg *= 1.0 + ap.amount
	if ap.trigger == "isolated" and _side_active(tgt.side).size() == 1:
		dmg *= 1.0 + ap.amount
	if ts.mark:
		dmg *= 1.08
	if att.e_execute and frac < 0.25:
		dmg *= 1.12
	dmg = _mitigate(att, tgt, dmg, dtype)
	if att.e_burn and from_ability:
		dmg += 12.0 + 0.04 * att.s_ap + 0.002 * att.s_hp
	var absorbed := minf(ts.shield, dmg)
	ts.shield -= absorbed
	tgt.hp -= dmg - absorbed
	tgt.dmg_taken += dmg
	att.dmg_heroes += dmg
	tgt.last_hit_by[att.key] = t
	last_damage_t = t
	var vamp := att.s_ov + (att.s_ls if not from_ability else 0.0) + (st[att.key] as FS).b_ls
	if vamp > 0.0:
		_heal(att, att, dmg * vamp * (0.6 if tgt.e_antiheal else 1.0))
	if att.e_antiheal:
		ts.antiheal = t + 3.0
	if tgt.hp > 0.0 and tgt.hp / tgt.max_hp < 0.3:
		if p.trigger == "low_hp" and p.shield > 0.0 and t - ts.low_used >= p.cd:
			ts.low_used = t
			ts.shield += p.shield * (1.0 + 0.08 * float(tgt.level))
		elif tgt.e_guard and t - ts.low_used >= 45.0:
			ts.low_used = t
			ts.shield += 120.0 + 12.0 * float(tgt.level)
	if tgt.hp <= 0.0:
		if tgt.e_revive and not tgt.revive_used:
			tgt.revive_used = true
			tgt.hp = 1.0
			ts.untarget = t + 2.0
			ts.cc = t + 2.0
			_act_dirty = true
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
	if att.pas.trigger == "on_kill":
		att.stacks += 1
		att.dirty()


func _apply_cc(att: SimHero, tgt: SimHero, cc: int, dur: float) -> void:
	var ts: FS = st[tgt.key]
	var ap := att.pas
	if ap.stat == "cc_amp" and t < ts.slow:
		dur *= 1.0 + ap.amount
	tgt.last_hit_by[att.key] = t
	match cc:
		CC_HARD:
			ts.cc = maxf(ts.cc, t + dur)
		CC_ROOT:
			ts.root = maxf(ts.root, t + dur)
			if tgt.front:
				ts.cc = maxf(ts.cc, t + dur * 0.5)    # a rooted melee hero cannot reach anyone for a while
		CC_SILENCE:
			ts.silence = maxf(ts.silence, t + dur)
		CC_SLOW:
			ts.slow = maxf(ts.slow, t + dur)
	if ap.stat == "mark":
		ts.mark = true


func _heal_amount(h: SimHero, a: SimHero.Ability) -> float:
	var base := a.heal + 6.0 * float(h.level) + a.ratio_def * h.s_ap
	var amp := 1.0 + h.s_hlp
	if h.pas.stat == "heal_amp":
		amp += h.pas.amount * 0.5
	return base * amp * _heal_scale


func _apply_support(h: SimHero, ally: SimHero, a: SimHero.Ability, s: FS) -> void:
	if a.heal_k:
		var amt := _heal_amount(h, a)
		if a.target == T_AREA:
			for x in _side_active(h.side):
				_heal(h, x, amt * 0.7)
		else:
			_heal(h, ally, amt)
	if a.shield_k:
		_shield(h, ally, a)
		if a.target == T_AREA:
			for x in _side_active(h.side):
				if x != ally:
					_shield(h, x, a, 0.6)
	if a.stealth:
		s.untarget = t + 1.0
		_act_dirty = true
	if a.mob and a.target == T_SELF:
		s.dived = true
	if not a.buff.is_empty():
		var tgt_s: FS = st[ally.key]
		tgt_s.add_buff(t + maxf(1.0, a.dur), a.buff)
		if a.buff.has("untargetable"):
			tgt_s.untarget = t + float(a.buff["untargetable"])
			_act_dirty = true
	if a.cc != 0:
		var tgt := _pick_target(h, s, false)
		if tgt != null:
			_apply_cc(h, tgt, a.cc, a.cc_s)
	events.append([t, "cast", h.key, a.id, ally.key, true])


func _shield(h: SimHero, to: SimHero, a: SimHero.Ability, mult: float = 1.0) -> void:
	var amt := a.shield + 8.0 * float(h.level) + a.ratio_def * (h.s_hp if h.front else h.s_ap)
	amt *= (1.0 + h.s_shp) * h.qe(t) * mult * _heal_scale * h.bal
	(st[to.key] as FS).shield += amt
	h.healed += amt * 0.5


func _heal(h: SimHero, to: SimHero, amt: float) -> void:
	if not to.alive:
		return
	if st.has(to.key) and (st[to.key] as FS).antiheal > t:
		amt *= 0.6
	amt *= h.qe(t) * h.bal
	var before := to.hp
	to.hp = minf(to.max_hp, to.hp + amt)
	if h != to:
		h.healed += to.hp - before


func _on_ability_passive(h: SimHero, s: FS) -> void:
	var p := h.pas
	if p.trigger != "on_ability":
		return
	if p.every > 0 and s.casts % p.every != 0:
		return
	if p.shield > 0.0:
		s.shield += p.shield * (1.0 + 0.06 * float(h.level))
	if p.heal > 0.0:
		_heal(h, h, p.heal * (1.0 + 0.06 * float(h.level)))
	if p.stat == "aspd" or p.stat == "move":
		s.add_buff(t + 3.0, {p.stat: p.amount})
	if p.bonus_dmg > 0.0 or p.cc != 0:
		s.spellblade = true


func _attack(h: SimHero, s: FS) -> void:
	if t < s.next_atk:
		return
	var tgt := _pick_target(h, s, h.arch == "shade")
	if tgt == null:
		return
	var aspd := clampf(h.s_aspd * (1.0 + s.b_aspd), 0.3, 2.5)
	if t < s.slow:
		aspd *= 0.85
	s.next_atk = t + 1.0 / aspd
	var dmg := h.s_atk
	var crit := h.s_crit + s.b_crit
	var p := h.pas
	if p.trigger == "out_of_combat" and s.first_attack:
		if p.stat == "crit":
			crit += p.amount
		if p.shield > 0.0:
			s.shield += p.shield * (1.0 + 0.06 * float(h.level))
	s.first_attack = false
	if rng.next_float() < crit:
		dmg *= _crit_mult + (_crit_amp if h.e_crit_amp else 0.0)
	s.hits += 1
	var bonus := 0.0
	if p.trigger == "on_hit_nth" and p.every > 0 and s.hits % p.every == 0:
		bonus += p.bonus_dmg + p.ratio * (h.s_atk * 0.5 + h.s_ap)
		if p.heal > 0.0:
			_heal(h, h, p.heal * (1.0 + 0.06 * float(h.level)))
		if p.cc != 0:
			_apply_cc(h, tgt, p.cc, p.cc_s)
	if s.spellblade:
		s.spellblade = false
		bonus += 0.6 * h.s_atk + 0.3 * h.s_ap
		if p.trigger == "on_ability":
			bonus += p.bonus_dmg + p.ratio * (h.s_atk * 0.5 + h.s_ap)
			if p.cc != 0:
				_apply_cc(h, tgt, p.cc, p.cc_s)
	if h.e_on_hit:
		bonus += 15.0 + 0.1 * h.s_ap + 0.2 * float(h.level)
	_deal(h, tgt, dmg, 0, false)
	if bonus > 0.0 and tgt.alive and tgt.hp > 0.0:
		_deal(h, tgt, bonus, 1 if h.s_ap > h.s_atk else 0, false)
	if h.e_slow_hit and tgt.hp > 0.0:
		var ts: FS = st[tgt.key]
		ts.slow = maxf(ts.slow, t + 1.0)
	if h.e_splash:
		for e in _side_active(tgt.side):
			if e != tgt:
				_deal(h, e, dmg * 0.3, 0, false)
				break


func _maybe_flee(h: SimHero, s: FS) -> bool:
	if s.flee_at >= 0.0:
		if t >= s.flee_at:
			s.fled = true
			_act_dirty = true
			events.append([t, "flee", h.key])
		return true
	var frac := h.hp / maxf(1.0, h.max_hp)
	var sen := h.p_sen / 100.0
	if frac >= _ret_lo + (_ret_hi - _ret_lo) * sen:
		return false
	if _strength(h.side) >= _strength(SimData.other(h.side)) * (0.85 + 0.3 * sen):
		return false
	# a dash shortens the time exposed while running
	var exposed := 1.2
	for i in 3:
		var a: SimHero.Ability = h.abil[i]
		if a.mob and float(h.cds[i]) <= t and h.level >= a.unlock:
			exposed = 0.5
			h.cds[i] = t + _cd_of(h, a)
			break
	if t < s.root or t < s.slow:
		exposed += 0.6
	s.flee_at = t + exposed
	return true


func _tower_shot() -> void:
	if tower_side == "":
		return
	# one shot a second at the attacker nearest the tower (front row first) that has hit an enemy hero
	if int(t * 2.0 + 0.001) % 2 != 0:
		return
	var best: SimHero = null
	for h in _side_active(SimData.other(tower_side)):
		var hh: SimHero = h
		if hh.dmg_heroes <= 0.0:
			continue
		if best == null or (st[hh.key] as FS).row < (st[best.key] as FS).row:
			best = hh
	if best == null:
		return
	var dmg := tower_dmg * (1.0 + 0.04 * float(sim.minute(t)))
	dmg = dmg * _armor_k / (_armor_k + best.s_armor * 0.5)
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
