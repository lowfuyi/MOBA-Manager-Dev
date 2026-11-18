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

const LANE_BEATS := ["top", "mid_lane", "bot"]
const GROUP := {"obj_mid": "N.stoneback", "fight_mid": "N.mossback", "obj_late": "N.moonhulk"}
const TAKE := {"obj_mid": [31.0, 33.75], "obj_late": [57.0, 60.0]}
const CLASH := {"obj_mid": [31.5, 33.75], "fight_mid": [41.2, 45.0], "obj_late": [57.0, 60.0], "fight_late": [66.0, 71.25]}
const HIT_RATIO := {"narrow": 0.55, "clear": 0.7, "decisive": 0.85}
const MAX_CUES := 12            # live short cues at once (3.2 suggests a cap of 12)
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


## [canonical focus, zoom] at t; `reduced` (reduced motion) keeps the whole map.
func camera_at(t: float, reduced: bool = false) -> Array:
	var centre := Vector2(0.5, 0.5)
	if reduced:
		return [centre, 1.0]
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
		out.append([ArenaData.node(String(GROUP[k])), 66.0, 0.0, frac, col])    # round the whole pit: the tokens stand inside it
	return out


## The whole frame for the map at t: towers, sprites, arcs and (unless reduced motion) the camera.
func apply(m: ArenaMap, t: float, reduced: bool = false) -> void:
	m.fallen = fallen_at(t)
	m.sprites_under = under_at(t)
	m.sprites = c.sprites_at(t, my_side)
	m.sprites_over = over_at(t)
	m.arcs = arcs_at(t)
	var cam := camera_at(t, reduced)
	m.look_at_point(m.arena_px(cam[0]), float(cam[1]))
