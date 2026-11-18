class_name ArenaFx
extends RefCounted
## The beats on screen (Alpha 0.8 A-04, ACTION-VOCABULARY 2.2 to 2.4 and 3.2): every effect cue as a pure function of show time,
## built ONCE from a ShowScript and its Choreo. Effects are sprites of the map's icon strip (one texture: they batch with the map
## and the tokens), plus the objective progress rings (two arcs). Nothing here changes a count: kills, deaths and towers are the
## ledger's (H5); a cue that marks a kill is placed only at a kill event of the ledger.
##   under_at(t)   auras under the winners of an objective, the winner ring at each resolve (circle for you, hexagon for them)
##   over_at(t)    hit sparks and rings, kill pings (killer flash, skull at the victim), death motes, respawn rings, tower cracks
##                 and dust, objective bursts, pressure arrows after the lane beats, owner glyphs on taken objectives, the Cairn
##   arcs_at(t)    the objective progress ring (initiator's colour; a steal flips to the winner's in the last 10 percent)
##   fallen_at(t)  towers that are down at t (the ledger's towers 0.6 s after their crack, the guard towers of the close push)
##   camera_at(t)  [canonical focus, zoom]: focus windows on the group beats (ARENA-MAP 8); wide in the held fight (HF4)
##   resolves      [{beat, t, win}] the winner marker of every contest, at its stamp (the A-04 test reads it)
## Sprite entries: [ICON key, canonical point, size px, alpha]. Arc entries: [canonical centre, radius px, from, to, colour key].
## Fight pass (Alpha 0.8.1, ACTION-VOCABULARY 11.2): every hit cue and every ledger kill is an action of its attacker by archetype
## (dash, shot, burst, tether; menders heal), plus the engage of each group beat. hero_pos(key, t) is the token with its lunge;
## bars_at(t) the health bars (ShowScript.hp_at). An action is kept only when its attacker is up at its start and its hit and the
## target is up just before the hit.

const LANE_BEATS := ["top", "mid_lane", "bot"]
const GROUP := {"obj_mid": "N.stoneback", "fight_mid": "N.mossback", "obj_late": "N.moonhulk"}
## Fight pass (11.3): the objective ring only after the objective fight (arena_actions_v1.json fights.*.take); the hit cues of a
## group beat fill its fight (from to fight_to); teamfights have no ring. A test keeps these equal to the data.
const TAKE := {"obj_mid": [32.25, 33.75], "obj_late": [58.5, 60.0]}
const CLASH := {"obj_mid": [31.0, 32.25], "fight_mid": [41.2, 45.0], "obj_late": [57.0, 58.5], "fight_late": [66.0, 71.25]}
const HIT_RATIO := {"narrow": 0.55, "clear": 0.7, "decisive": 0.85}
const MAX_CUES := 24            # live short cues at once (12 in 0.8; the Fight pass raises it to 24, arena_actions_v1.json)
const FOCUS_IN := 0.45
const FOCUS_OUT := 0.6
const GUARD_FALL := [72.0, 72.4]
const CRACK := 0.6

var s: ShowScript
var c: Choreo
var my_side := "B"
var sparks: Array = []          # [{t, hero key (the one hit), magic}]
var resolves: Array = []
var guard_ids: Array = []
var fight_late_at := Vector2(0.5, 0.5)
var focus: Array = []           # [{from, to, at (canonical)}]
var actions: Array = []         # [{kind, a (attacker key), b (target key), t0, th (the hit), t1, kill, reach}] sorted by t0
var _lunges: Dictionary = {}    # attacker key -> its dash and engage actions (the token moves)


static func build(p_s: ShowScript, p_c: Choreo, p_my_side: String) -> ArenaFx:
	var f := ArenaFx.new()
	f.s = p_s
	f.c = p_c
	f.my_side = p_my_side
	f._build()
	return f


func who(side: String) -> String:
	return "you" if side == my_side else "them"


func _build() -> void:
	var u := ShowScript.other(s.winner)
	guard_ids = [u + ".guard.l", u + ".guard.r"]
	# where the late fight stands: the loser's gate (clean) or the variant's ground (held)
	if c.variant == "held_island":
		fight_late_at = ArenaData.node("N.moonhulk")
	else:
		fight_late_at = ArenaData.node(u + ".mid.gate")
	for k in ShowScript.ORDER:
		var at: Vector2
		if LANE_BEATS.has(k):
			var lane: String = {"top": "top", "mid_lane": "mid", "bot": "bot"}[k]
			at = c.lane_point(lane, c.clash_s(lane))
		elif k == "jungle":
			at = ArenaData.node("N.mossback")
		elif k == "fight_late":
			at = fight_late_at
		else:
			at = ArenaData.node(String(GROUP[k]))
		resolves.append({"beat": k, "t": float(ShowScript.RESOLVE[k]), "win": String(s.contests[k]["win"]), "at": at,
				"size": String(s.contests[k]["size"])})
	_sparks()
	_actions()
	focus = [{"from": 31.0, "to": 36.0, "at": ArenaData.node("N.stoneback")},
			{"from": 41.0, "to": 46.5, "at": ArenaData.node("N.mossback")},
			{"from": 57.0, "to": 61.5, "at": ArenaData.node("N.moonhulk")}]
	if not s.held:    # HF4: the held fight keeps the camera wide
		focus.append({"from": 66.0, "to": 75.0, "at": (fight_late_at + ArenaData.node(u + ".cairn")) / 2.0})


## Hit cues: the lanes trade from 5.0 s to their resolve (W lands HIT_RATIO of the hits), the group beats every 0.3 s in their clash.
## Who is hit and when comes from the `show:fx` stream (A2); the cue is drawn on that hero's token at that time.
func _sparks() -> void:
	var rng := Pcg32.contest_stream(int(s.res["mseed"]), "show:fx")
	var pairs := {"top": [["top", "top"]], "mid_lane": [["mid", "mid"]], "bot": [["bot", "bot"], ["sup", "sup"]]}
	for k in LANE_BEATS:
		var w := String(s.contests[k]["win"])
		var ratio := float(HIT_RATIO[String(s.contests[k]["size"])])
		var t := 5.0 + 0.4 * float(LANE_BEATS.find(k))
		var i := 0
		while t < float(ShowScript.RESOLVE[k]):
			var pr: Array = pairs[k][i % (pairs[k] as Array).size()]
			var hit_side := ShowScript.other(w) if rng.next_float() < ratio else w
			var slot: String = pr[0]
			sparks.append({"t": t, "key": hit_side + "." + slot, "magic": slot == "mid" or slot == "sup"})
			t += 1.0 + 0.5 * rng.next_float()
			i += 1
	for k2 in CLASH:
		var w2 := String(s.contests[k2]["win"])
		var ratio2 := float(HIT_RATIO[String(s.contests[k2]["size"])])
		var t2 := float(CLASH[k2][0])
		while t2 < float(CLASH[k2][1]):
			var hit := ShowScript.other(w2) if rng.next_float() < ratio2 else w2
			var slot2: String = Choreo.SLOTS[int(rng.next_float() * 5.0) % 5]
			sparks.append({"t": t2, "key": hit + "." + slot2, "magic": rng.next_float() < 0.5})
			t2 += 0.3
	sparks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


func _add_action(att: String, tgt: String, th: float, kill: bool) -> void:
	var A: Dictionary = ArenaActions.data()["actions"]
	var kind := ArenaActions.action_of(s.res, att.substr(0, 1), att.substr(2))
	if kind == "heal":
		kind = "shot"    # a mender's own hit is a light bolt
	var t0 := th - float(A[kind]["lead_s"])
	var t1 := th
	match kind:
		"dash":
			t1 = th + float(A["dash"]["recoil_s"])
		"burst":
			t1 = th + float(A["burst"]["burst_s"])
		"tether":
			t1 = th if kill else th + float(A["tether"]["hold_s"])
	if not (c.alive(att, t0) and c.alive(att, t1) and c.alpha(att, t0) >= 1.0 and c.alive(tgt, th - 0.01)):
		return
	if not kill and not c.alive(tgt, t1):
		return
	actions.append({"kind": kind, "a": att, "b": tgt, "t0": t0, "th": th, "t1": t1, "kill": kill, "reach": float(A["dash"]["reach_px"])})


## 11.2 and 11.3: the attacker of every hit cue (the lane opponent; in a group beat a living foe of the `show:act` stream), the
## killer's action on every ledger kill, the engage of each group beat and the menders' heals.
func _actions() -> void:
	var rng := Pcg32.contest_stream(int(s.res["mseed"]), "show:act")
	for sp in sparks:
		var tgt := String(sp["key"])
		var t := float(sp["t"])
		var foe := ShowScript.other(tgt.substr(0, 1))
		var att := ""
		if t < 20.25:
			att = foe + "." + tgt.substr(2)
		else:
			var cands: Array = []
			for slot in Choreo.SLOTS:
				var k: String = foe + "." + slot
				if c.alive(k, t - 0.35) and c.alive(k, t):
					cands.append(k)
			if cands.is_empty():
				continue
			att = cands[int(rng.next_float() * float(cands.size())) % cands.size()]
		_add_action(att, tgt, t, false)
	for e in s.kill_events:
		_add_action(String(e["side"]) + "." + String(e["killer"]), ShowScript.other(String(e["side"])) + "." + String(e["victim"]), float(e["t"]), true)
	var eng: Dictionary = ArenaActions.data()["engage"]
	var fights: Dictionary = ArenaActions.data()["fights"]
	for k2 in fights:
		var t0 := float(fights[k2]["from"])
		var t1 := t0 + float(eng["length_s"])
		var side := String(s.initiators.get(k2, s.contests[k2]["win"]))
		var front := ""
		for want in ["bulwark", "bruiser"]:
			for slot2 in Choreo.SLOTS:
				if front == "" and ArenaActions.archetype(s.res, side, slot2) == want and c.alive(side + "." + slot2, t0) and c.alive(side + "." + slot2, t1):
					front = side + "." + slot2
		if front == "":
			for slot3 in Choreo.SLOTS:
				if front == "" and c.alive(side + "." + slot3, t0) and c.alive(side + "." + slot3, t1):
					front = side + "." + slot3
		if front == "":
			continue
		var best := ""
		var bd := INF
		for slot4 in Choreo.SLOTS:
			var fk: String = ShowScript.other(side) + "." + slot4
			if not (c.alive(fk, t0) and c.alive(fk, t0 + 0.3)):
				continue
			var dd := c.pos(front, t0).distance_to(c.pos(fk, t0))
			if dd < bd:
				bd = dd
				best = fk
		if best != "":
			actions.append({"kind": "engage", "a": front, "b": best, "t0": t0, "th": t0 + 0.3, "t1": t1, "kill": false, "reach": float(eng["reach_px"])})
	var pulse := float(ArenaActions.data()["actions"]["heal"]["pulse_s"])
	for h in s.heals:
		actions.append({"kind": "heal", "a": String(h["by"]), "b": String(h["ally"]), "t0": float(h["t"]), "th": float(h["t"]), "t1": float(h["t"]) + pulse, "kill": false, "reach": 0.0})
	actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t0"]) < float(b["t0"]))
	for a2 in actions:
		if String(a2["kind"]) == "dash" or String(a2["kind"]) == "engage":
			if not _lunges.has(a2["a"]):
				_lunges[a2["a"]] = []
			_lunges[a2["a"]].append(a2)


## How far into its lunge an attacker is (0 to 1): a dash eases in to the hit and recoils after it; an engage charges, holds, returns.
func _lunge_k(a: Dictionary, t: float) -> float:
	var t0 := float(a["t0"])
	var th := float(a["th"])
	var t1 := float(a["t1"])
	if t < t0 or t >= t1:
		return 0.0
	if String(a["kind"]) == "engage":
		if t < th:
			return _ease((t - t0) / (th - t0))
		if t < th + 0.3:
			return 1.0
		return 1.0 - _ease((t - th - 0.3) / maxf(0.01, t1 - th - 0.3))
	if t < th:
		return _ease((t - t0) / maxf(0.01, th - t0))
	return 1.0 - _ease((t - th) / maxf(0.01, t1 - th))


## The token's offset at t (canonical units): toward its target by the action's reach (never more than 0.6 of the gap).
func nudge(key: String, t: float) -> Vector2:
	var off := Vector2.ZERO
	for a in _lunges.get(key, []):
		if float(a["t0"]) > t:
			break
		var k := _lunge_k(a, t)
		if k <= 0.0:
			continue
		var pa := c.pos(key, t)
		var pb := c.pos(String(a["b"]), t)
		var d := Vector2((pb.x - pa.x) * ArenaData.W, (pb.y - pa.y) * ArenaData.H)
		var dist := d.length()
		if dist < 1.0:
			continue
		var v := d / dist * minf(float(a["reach"]), 0.6 * dist) * k
		off += v
	var cap := float(ArenaActions.data()["engage"]["reach_px"])    # two lunges at once never carry a token further than an engage
	if off.length() > cap:
		off = off.normalized() * cap
	return Vector2(off.x / ArenaData.W, off.y / ArenaData.H)


func hero_pos(key: String, t: float) -> Vector2:
	return c.pos(key, t) + nudge(key, t)


## Tokens (Choreo.sprites_at) with their lunges.
func sprites_at(t: float) -> Array:
	var offs := {}
	for key in _lunges:
		var o := nudge(String(key), t)
		if o != Vector2.ZERO:
			offs[key] = o
	return c.sprites_at(t, my_side, offs)


## Health bars: [canonical point (the token), hp 0 to 1, "you"/"them", alpha], only while a bar is below full (11.4).
func bars_at(t: float) -> Array:
	var out: Array = []
	for key in c.heroes:
		var al := c.alpha(String(key), t)
		if al <= 0.0 or not c.alive(String(key), t):
			continue
		var h := s.hp_at(String(key), t)
		if h < 0.999:
			out.append([hero_pos(String(key), t), h, who(String(key).substr(0, 1)), al])
	return out


## The cues of the actions live at t (11.2), at most `room` of them.
func _action_cues(t: float, room: int) -> Array:
	var out: Array = []
	var px := Vector2(1.0 / ArenaData.W, 1.0 / ArenaData.H)
	for a in actions:
		if out.size() >= room:
			break
		var t0 := float(a["t0"])
		if t0 > t:
			break
		var th := float(a["th"])
		var t1 := float(a["t1"])
		if t >= t1 + 0.6:
			continue
		var ak := String(a["a"])
		var bk := String(a["b"])
		match String(a["kind"]):
			"dash":
				if t < th:
					out.append(["trail", hero_pos(ak, t), 44.0, 0.7 * _lunge_k(a, t)])
				elif t - th < 0.25:
					out.append(["slash", c.pos(bk, t), 36.0, 1.0 - (t - th) / 0.25])
			"engage":
				if t < th + 0.3:
					out.append(["trail", hero_pos(ak, t), 52.0, 0.9])
			"shot":
				if t < th:
					var x := (t - t0) / maxf(0.01, th - t0)
					var pa := hero_pos(ak, t)
					var pb := c.pos(bk, t)
					out.append(["bolt", pa.lerp(pb, x), 22.0, 1.0])
					for j in 2:
						var xb := x - 0.12 * float(j + 1)
						if xb > 0.0:
							out.append(["bolt", pa.lerp(pb, xb), 14.0 - 4.0 * float(j), 0.55 - 0.2 * float(j)])
			"burst":
				if t < th:
					out.append(["charge", hero_pos(ak, t), 24.0 + 14.0 * (t - t0) / maxf(0.01, th - t0), 0.9])
				elif t < t1:
					var y := (t - th) / maxf(0.01, t1 - th)
					out.append(["burst_cast", c.pos(bk, t), 34.0 + 40.0 * y, 1.0 - y])
			"tether":
				if t < t1 or (t == th and t1 == th):
					var pa2 := hero_pos(ak, t)
					var pb2 := c.pos(bk, t)
					for j2 in 5:
						out.append(["tether_dot", pa2.lerp(pb2, (float(j2) + 1.0) / 6.0), 12.0, 0.9])
				if t >= th and t - th < 0.6:
					out.append(["root", c.pos(bk, t), 40.0, 1.0 - (t - th) / 0.6])
			"heal":
				if t < t1:
					var z := (t - th) / maxf(0.01, t1 - th)
					out.append(["plus", c.pos(bk, t) + Vector2(0, -(12.0 + 20.0 * z)) * px, 26.0, 1.0 - z])
	return out


func _ease(x: float) -> float:
	return ShowScript.ease01(x)


func fallen_at(t: float) -> Dictionary:
	var out := {}
	for tw in s.towers:
		if float(tw["t"]) + CRACK <= t:
			out[String(tw["id"])] = true
	for i in guard_ids.size():
		if float(GUARD_FALL[i]) + CRACK <= t:
			out[String(guard_ids[i])] = true
	return out


func cairn_down(t: float) -> bool:
	return t >= ShowScript.CAIRN_T


## [canonical focus, zoom, punch] at t; `reduced` (reduced motion) keeps the whole map, with no shake and no punch.
## The decisive kill (ACTION-VOCABULARY 11.5) adds a shake (decaying) and a punch-in on top of the focus zoom.
func camera_at(t: float, reduced: bool = false) -> Array:
	var centre := Vector2(0.5, 0.5)
	if reduced:
		return [centre, 1.0, 0.0]
	var cam := _focus_at(t)
	if s.decisive.is_empty():
		cam.append(0.0)
		return cam
	var d: Dictionary = ArenaActions.data()["decisive"]
	var dt := t - float(s.decisive["t"])
	var punch := 0.0
	var at: Vector2 = cam[0]
	if dt >= 0.0 and dt < float(d["punch_s"]):
		var k := minf(1.0, dt / 0.08) * (1.0 - _ease(dt / float(d["punch_s"])))
		punch = float(d["punch_zoom"]) * k
		var victim := ShowScript.other(String(s.decisive["side"])) + "." + String(s.decisive["victim"])
		at = at.lerp(c.pos(victim, float(s.decisive["t"])), 0.5 * k)
	if dt >= 0.0 and dt < float(d["shake_s"]):
		var amp := float(d["shake_px"]) * (1.0 - dt / float(d["shake_s"]))
		at += Vector2(sin(dt * 55.0) * amp / ArenaData.W, cos(dt * 47.0) * amp / ArenaData.H)
	return [at, cam[1], punch]


func _focus_at(t: float) -> Array:
	var centre := Vector2(0.5, 0.5)
	var zmax := float(ArenaData.data()["camera"]["focus"]["max_zoom"])
	for f in focus:
		var a := float(f["from"])
		var b := float(f["to"])
		if t >= a and t <= b + FOCUS_OUT:
			var k := 1.0
			if t < a + FOCUS_IN:
				k = _ease((t - a) / FOCUS_IN)
			elif t > b:
				k = 1.0 - _ease((t - b) / FOCUS_OUT)
			return [centre.lerp(f["at"], k), lerpf(1.0, zmax, k)]
	return [centre, 1.0]


func under_at(t: float) -> Array:
	var out: Array = []
	# auras: Stoneback's winner for 15 s, Moonhulk's to the end (HF4: no aura for the held fight's winner; none is added there)
	var auras := [["obj_mid", 33.75, 48.75], ["obj_late", 60.0, 75.0]]
	for a in auras:
		if t >= float(a[1]) and t < float(a[2]):
			var side := String(s.contests[a[0]]["win"])
			var fade := minf(1.0, (t - float(a[1])) / 0.5) * minf(1.0, (float(a[2]) - t) / 0.5)
			for slot in Choreo.SLOTS:
				var key: String = side + "." + slot
				var al := c.alpha(key, t)
				if al > 0.0:
					out.append(["aura_" + who(side), c.pos(key, t), 54.0, 0.55 * fade * al])
	# the winner ring at each resolve (1.5 s, grows a little)
	for r in resolves:
		var dt := t - float(r["t"])
		if dt >= 0.0 and dt < 1.5:
			var big := 1.0 if LANE_BEATS.has(r["beat"]) or r["beat"] == "jungle" else 1.6
			out.append(["ring_" + who(String(r["win"])), r["at"], (72.0 + 24.0 * dt) * big, 1.0 - dt / 1.5])
	return out


func over_at(t: float) -> Array:
	var out: Array = []
	var live := 0
	# sparks
	for sp in sparks:
		var dt := t - float(sp["t"])
		if dt < 0.0:
			break
		if dt < 0.2 and live < MAX_CUES and c.alpha(String(sp["key"]), t) >= 1.0:
			out.append(["spark" if not bool(sp["magic"]) else "ring_magic", c.pos(String(sp["key"]), t), 30.0, 1.0 - dt / 0.2])
			live += 1
	# the decisive kill (11.5): a still flash on the victim (also with Animations off)
	if not s.decisive.is_empty():
		var dd := t - float(s.decisive["t"])
		if dd >= 0.0 and dd < 0.5:
			var vk := ShowScript.other(String(s.decisive["side"])) + "." + String(s.decisive["victim"])
			out.append(["flash", c.pos(vk, t), 84.0, 0.9 * (1.0 - dd / 0.5)])
	# the actions (Fight pass): the rest of the live-cue budget
	out.append_array(_action_cues(t, MAX_CUES - live))
	# kills: killer flash 0.3 s, skull 0.6 s and motes 0.5 s at the victim
	for e in s.kill_events:
		var dk := t - float(e["t"])
		if dk < 0.0 or dk >= 0.6:
			continue
		var killer: String = String(e["side"]) + "." + String(e["killer"])
		var victim: String = ShowScript.other(String(e["side"])) + "." + String(e["victim"])
		if dk < 0.3 and c.alpha(killer, t) > 0.0:
			out.append(["flash", c.pos(killer, t), 44.0, 0.8 * (1.0 - dk / 0.3)])
		out.append(["skull", c.pos(victim, t) + Vector2(0, -26.0 / ArenaData.H), 24.0, 1.0 - dk / 0.6])
		if dk < 0.5:
			out.append(["motes", c.pos(victim, t) + Vector2(0, -dk * 30.0 / ArenaData.H), 30.0, 1.0 - dk / 0.5])
	# respawn rings at the pads
	for key2 in c.heroes:
		for d in c.heroes[key2]["deaths"]:
			var dr := t - float(d["rise"])
			if dr >= 0.0 and dr < 0.6:
				out.append(["ring_magic", c.pos(key2, t), 40.0 + 20.0 * dr, 1.0 - dr / 0.6])
	# towers: crack (0.6 s) then dust (0.9 s)
	var falls: Array = []
	for tw in s.towers:
		falls.append([String(tw["id"]), float(tw["t"])])
	for i in guard_ids.size():
		falls.append([String(guard_ids[i]), float(GUARD_FALL[i])])
	for fl in falls:
		var dtw := t - float(fl[1])
		if dtw < 0.0 or dtw >= CRACK + 0.9:
			continue
		var tp: Array = ArenaData.tower(String(fl[0]))["p"]
		var at := Vector2(float(tp[0]), float(tp[1]))
		if dtw < CRACK:
			out.append(["crack", at, 30.0, 1.0])
		else:
			var k := (dtw - CRACK) / 0.9
			out.append(["dust", at, 32.0 + 24.0 * k, 1.0 - k])
	# objective bursts at the resolve (0.8 s) and the owner glyph after it
	for ob in [["obj_mid", "N.stoneback", "burst_amber"], ["obj_late", "N.moonhulk", "burst_pale"]]:
		var rt := float(ShowScript.RESOLVE[ob[0]])
		var pos := ArenaData.node(String(ob[1]))
		var db := t - rt
		if db >= 0.0 and db < 0.8:
			out.append([ob[2], pos, 56.0 + 60.0 * db, 1.0 - db / 0.8])
		if db >= 0.0:
			out.append(["glyph_" + who(String(s.contests[ob[0]]["win"])), pos + Vector2(20.0 / ArenaData.W, -20.0 / ArenaData.H), 22.0, minf(1.0, db / 0.3)])
	# pressure arrows: 2.5 s after each lane resolve, at the clash point, pointing at the loser's outer tower (up = toward them)
	for r in resolves:
		if not LANE_BEATS.has(r["beat"]):
			continue
		var da := t - float(r["t"])
		if da >= 0.0 and da < 2.5:
			var w := String(r["win"])
			var up := w == my_side
			out.append(["arrow_%s_%s" % ["up" if up else "down", who(w)], r["at"], 36.0, minf(1.0, (2.5 - da) / 0.4)])
	# the Cairn: cracks from 72.5 s, falls at 74.0 s into a ruin
	var cairn := ArenaData.node(ShowScript.other(s.winner) + ".cairn")
	if t >= 72.5 and t < ShowScript.CAIRN_T:
		out.append(["crack", cairn, 44.0, 0.6 + 0.4 * sin((t - 72.5) * 12.0)])
	if t >= ShowScript.CAIRN_T:
		out.append(["ruin", cairn, 52.0, 1.0])
		var dc := t - ShowScript.CAIRN_T
		if dc < 1.0:
			out.append(["flash", cairn, 60.0 + 80.0 * dc, 1.0 - dc])
	return out


func arcs_at(t: float) -> Array:
	var out: Array = []
	for k in TAKE:
		var a := float(TAKE[k][0])
		var b := float(TAKE[k][1])
		if t < a or t >= b + 0.4:
			continue
		var frac := clampf((t - a) / (b - a), 0.0, 1.0)
		var w := String(s.contests[k]["win"])
		var init := String(s.initiators.get(k, w))
		var col := who(init)
		if init != w and frac >= 0.9:    # a steal: the ring flips to the winner in its last 10 percent
			col = who(w)
		out.append([ArenaData.node(String(GROUP[k])), 76.0, 0.0, frac, col])    # round the whole pit, clear of the two ranks (54 px + a token)
	return out


## The whole frame for the map at t: towers, sprites, arcs and (unless reduced motion) the camera.
func apply(m: ArenaMap, t: float, reduced: bool = false) -> void:
	m.fallen = fallen_at(t)
	m.sprites_under = under_at(t)
	m.sprites = sprites_at(t)
	m.bars = bars_at(t)
	m.sprites_over = over_at(t)
	m.arcs = arcs_at(t)
	var cam := camera_at(t, reduced)
	m.punch = float(cam[2])
	m.look_at_point(m.arena_px(cam[0]), float(cam[1]))
