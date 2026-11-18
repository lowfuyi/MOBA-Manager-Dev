class_name ArenaLabels
extends RefCounted
## The arena's words (Alpha 0.8 A-07): intent labels (ACTION-VOCABULARY 4.1 to 4.3), status tags (2.4), the plan-switch and wipe
## banners, the feed lines, and the scheduler that admits them under the text budget of UI-PASS-2 6.7.4. Built ONCE from a
## ShowScript; everything is a function of show time.
##   items         every candidate: {kind ("feed"|"banner"|"tag"|"pair"), t, until, words, ...}; a pair carries both sides'
##                 labels {you: {id, text}, them: {id, text}} (either may be missing)
##   admitted      the schedule: the items that pass, in admission order (banner, feed, tag, pair, yours only), with "show":
##                 "both" or "you" for a pair; at most WORDS new words in any WINDOW seconds, feed lines never dropped
##   at(t)         what is on screen at t: {pair, tag, banner}; x2 hides the pairs (R3); large text keeps only yours
## Rules carried: R2 posture never a prediction (the catalogue's own text), R3 one label per side, 2.5 s, fixed windows,
## R4 variant streams `show:label:<intent>:<side>` with no repeat of the previous variant of that pair, R5 plan labels only
## when the control is non-zero, R8 precedence plan switch > plan control > objective role > style > lane or fallback.

const WINDOW := 2.5
const WORDS := 10
const LABEL_S := 2.5
const TAG_S := 2.0
const BANNER_S := 2.0
const FEED_S := 4.0
## label windows (show seconds)
const WINDOWS := {"open": 0.5, "lane_top": 5.0, "lane_mid": 7.5, "lane_bot": 10.0, "jungle": 12.5, "plan": 21.2, "rotate": 24.2,
		"stone": 31.0, "fight_mid": 37.0, "push": 46.0, "tempo": 51.5, "rot_late": 54.5, "moon": 57.0, "fight_late": 63.5, "close": 71.5}
const LANE_CONTEST := {"top": "top", "mid": "mid_lane", "bot": "bot"}

var s: ShowScript
var me := "B"
var large := false
var items: Array = []
var admitted: Array = []
var _last_variant: Dictionary = {}
var _streams: Dictionary = {}


static func build(p_s: ShowScript, p_large: bool = false) -> ArenaLabels:
	var l := ArenaLabels.new()
	l.s = p_s
	l.me = p_s.my_side
	l.large = p_large
	l._build()
	return l


static func word_count(text: String) -> int:
	return UI.plain(text).split(" ", false).size()


func _place(id: String) -> String:
	for o in ArenaData.objectives():
		if String(o["id"]) == id:
			return String(o["name"])
	return id


## Fill {lane} and {place}; a leading "The" is lower-cased when the fill is not at the start (4.1 R1).
func _fill(text: String, lane: String, place: String) -> String:
	var out := text
	if lane != "":
		out = out.replace("{lane}", Strings.t("arena.lane." + lane))
	if place != "":
		var p := place
		if not out.begins_with("{place}") and p.begins_with("The "):
			p = "the " + p.substr(4)
		out = out.replace("{place}", p)
	return out


func _variant(intent: String, side: String) -> int:
	var key := "%s:%s" % [intent, side]
	if not _streams.has(key):
		_streams[key] = Pcg32.contest_stream(int(s.res["mseed"]), "show:label:" + key)
	var v := int((_streams[key] as Pcg32).next_u32() % 3)
	if _last_variant.has(key) and int(_last_variant[key]) == v:
		v = (v + 1) % 3
	_last_variant[key] = v
	return v + 1


func _label(intent: String, side: String, lane: String = "", place: String = "") -> Dictionary:
	var prefix := "arena.tag." if intent.begins_with("tag_") else "arena.label."
	var text := _fill(Strings.t("%s%s.%d" % [prefix, intent, _variant(intent, side)]), lane, place)
	return {"id": intent, "text": text, "words": word_count(text)}


func plan_of(side: String, after_switch: bool) -> Dictionary:
	return s.chosen_plan(side) if after_switch else _default_plan(side)


func _default_plan(side: String) -> Dictionary:
	var sets: Dictionary = s.res.get("plans", {})
	var ps = sets.get(side, null)
	if ps is Dictionary and ps.get("default", null) is Dictionary:
		return ps["default"]
	return GamePlan.neutral()


func _style(side: String) -> String:
	return String((s.res.get("style", {}) as Dictionary).get(side, "skirmish"))


func _lane_mod(side: String, lane: String) -> float:
	var team: Dictionary = s.res.get("team_a" if side == "B" else "team_b", {})
	return float((team.get("lane_mod", {}) as Dictionary).get(lane, 0.0))


# ---- the label per window and side (R8 precedence) -----------------------------------------------------------------------------

func _pick(window: String, side: String) -> Dictionary:
	var early := plan_of(side, false)
	var plan := plan_of(side, true)
	var other := ShowScript.other(side)
	match window:
		"open":
			if side == me:
				return _label("open_free" if GamePlan.is_neutral(early) else "open_plan", side)
			return _label("style_" + _style(side), side)
		"lane_top", "lane_mid", "lane_bot":
			var lane := window.substr(5)
			var contest: String = LANE_CONTEST[lane]
			if String(early.get("jf", "")) == contest:
				return _label("jg_focus", side, lane)
			if lane == "bot" and int(early.get("s", 0)) != 0:
				return _label("lane_roam" if int(early["s"]) > 0 else "lane_stay", side)
			if int(early.get("a", 0)) != 0:
				return _label("lane_aggr" if int(early["a"]) > 0 else "lane_safe", side, lane)
			if _lane_mod(side, lane) > 0.0:
				return _label("lane_counter", side, lane)
			return _label("lane_calm", side)
		"jungle":
			if String(s.contests["jungle"]["win"]) != side:
				return _label("jg_farm", side)
			var best := ""
			var bm := 0.0
			for lane2 in ["top", "mid", "bot"]:
				var m := ShowScript.sgn(side) * float(s.contests[LANE_CONTEST[lane2]]["c"])
				if m > bm:
					bm = m
					best = lane2
			return _label("jg_gank", side, best) if best != "" else _label("jg_invade", side)
		"plan":
			var used := String(s.plan_used.get(side, "default"))
			var ids := {"default": "plan_hold", "behind_early": "plan_behind", "ahead_early": "plan_ahead", "vs_dive": "plan_vs_dive",
					"vs_siege": "plan_vs_siege", "vs_protect": "plan_vs_protect"}
			return _label(String(ids.get(used, "plan_hold")), side)
		"rotate":
			var g := int(plan.get("g", 0))
			if g > 0:
				return _label("rot_group", side)
			if g < 0:
				return _label("rot_split", side)
			return _label("rot_pit", side, "", _place("N.stoneback"))
		"stone", "moon":
			var ctl := "m" if window == "stone" else "l"
			var beat := "obj_mid" if window == "stone" else "obj_late"
			var place := _place("N.stoneback" if window == "stone" else "N.moonhulk")
			var v := int(plan.get(ctl, 0))
			if v != 0:
				return _label("obj_plan_pos" if v > 0 else "obj_plan_neg", side)
			var tail := "mid" if window == "stone" else "late"
			if String(s.initiators.get(beat, "")) == side:
				return _label("obj_start_" + tail, side, "", place)
			return _label("obj_cont_" + tail, side, "", place)
		"fight_mid", "fight_late":
			var r := int(plan.get("r", 0))
			if r != 0:
				return _label("fight_risk" if r > 0 else "fight_safe", side)
			if int(plan.get("g", 0)) > 0:
				return _label("fight_group", side)
			var st := _style(side)
			if ["dive", "siege", "protect", "skirmish"].has(st):
				return _label("fight_" + st, side)
			return _label("fight_hold", side)
		"push":
			var has_credit := false
			for tw in s.towers:
				has_credit = has_credit or (String(tw["beat"]) == "fight_mid" and String(tw["side"]) == side)
			if not has_credit:
				return {}
			var size := String(s.contests["fight_mid"]["size"])
			if _style(side) == "dive" and (size == "clear" or size == "decisive"):
				return _label("push_dive", side)
			return _label("push_tower", side)
		"tempo":
			var t := int(plan.get("t", 0))
			if t == 0:
				return {}
			return _label("tempo_scale" if t > 0 else "tempo_push", side)
		"rot_late":
			return _label("rot_late", side, "", _place("N.moonhulk"))
		"close":
			var cairn := _place(other + ".cairn") if side == s.winner else _place(side + ".cairn")
			if side == s.winner:
				return _label("push_lead" if s.held else "push_base", side, "", cairn)
			return _label("def_last", side, "", cairn)
	return {}


func _build() -> void:
	# feed lines: one per contest at its stamp, never dropped (the short form: tick or cross, the name, dots)
	for ev in Report.feed(s.res, me):
		var text := Strings.t("feed.t." + String(ev["key"]))
		items.append({"kind": "feed", "t": float(ev["t"]) * ShowScript.WATCH, "until": float(ev["t"]) * ShowScript.WATCH + FEED_S,
				"words": word_count(text), "key": ev["key"], "beat": ev["key"]})
	# banners: your plan switch at 21.0 s; a wipe (five different heroes of one side fall in one fight beat) at that fight's resolve
	var used := String(s.plan_used.get(me, "default"))
	if used != "default":
		var bt := Strings.t("gp.switch.short." + used)
		items.append({"kind": "banner", "t": 21.0, "until": 21.0 + BANNER_S, "words": word_count(bt), "text": bt, "id": "switch"})
	for f in ["fight_mid", "fight_late"]:
		for side in ["B", "R"]:
			var victims := {}
			for e in s.kill_events:
				if String(e["beat"]) == f and ShowScript.other(String(e["side"])) == side:
					victims[String(e["victim"])] = true
			var held_w: bool = f == "fight_late" and s.held and side == s.winner    # HF4: no wipe banner for W in the held fight
			if victims.size() == 5 and not held_w:
				var wt := Strings.t("arena.banner.wipe")
				var rt := float(ShowScript.RESOLVE[f])
				items.append({"kind": "banner", "t": rt, "until": rt + BANNER_S, "words": word_count(wt), "text": wt, "id": "wipe", "side": side, "replaces_feed": f})
	# status tags at their beat's resolve (2.4); one per moment, the upset first
	var tags_at := {}
	for u in s.upsets:
		var k := String(u["beat"])
		tags_at[k] = _label("tag_upset", String(u["side"]))
		tags_at[k]["side"] = String(u["side"])
	for fl in s.flips:
		var k2 := String(fl["beat"])
		if tags_at.has(k2):
			continue
		var comeback := s.arc == "comeback" and String(fl["to"]) == s.winner
		tags_at[k2] = _label("tag_back" if comeback else "tag_flip", String(fl["to"]))
		tags_at[k2]["side"] = String(fl["to"])
	if s.arc == "stomp" and not tags_at.has("fight_mid"):
		tags_at["fight_mid"] = _label("tag_snow", s.winner)
		tags_at["fight_mid"]["side"] = s.winner
	for k3 in tags_at:
		var rt2 := float(ShowScript.RESOLVE[k3])
		var tg: Dictionary = tags_at[k3]
		items.append({"kind": "tag", "t": rt2, "until": rt2 + TAG_S, "words": int(tg["words"]), "id": tg["id"], "text": tg["text"], "side": tg["side"]})
	# multi-kills (Fight pass, ACTION-VOCABULARY 11.3): two or more kills of one side in one group, at the group's last kill
	var multi := {}
	for e in s.kill_events:
		var gk := "%d:%s" % [int(e.get("g", -1)), String(e["side"])]
		if not multi.has(gk):
			multi[gk] = {"n": 0, "t": 0.0, "side": String(e["side"])}
		multi[gk]["n"] = int(multi[gk]["n"]) + 1
		multi[gk]["t"] = float(e["t"])
	for gk2 in multi:
		var mg: Dictionary = multi[gk2]
		if int(mg["n"]) < 2:
			continue
		var mid := "double" if int(mg["n"]) == 2 else ("triple" if int(mg["n"]) == 3 else "more")
		var mkey := {"double": "arena.tag.multi.double", "triple": "arena.tag.multi.triple", "more": "arena.tag.multi.more"}
		var mt := Strings.t(String(mkey[mid]))
		items.append({"kind": "tag", "t": float(mg["t"]), "until": float(mg["t"]) + TAG_S, "words": word_count(mt), "id": "multi_" + mid,
				"text": mt, "side": mg["side"]})
	if s.arc == "close":
		var tc := _label("tag_close", me)
		items.append({"kind": "tag", "t": 62.0, "until": 62.0 + TAG_S, "words": int(tc["words"]), "id": tc["id"], "text": tc["text"], "side": me})
	# label pairs
	for wname in WINDOWS:
		var t0 := float(WINDOWS[wname])
		var you := _pick(wname, me)
		var them := {} if large else _pick(wname, ShowScript.other(me))
		if you.is_empty() and them.is_empty():
			continue
		items.append({"kind": "pair", "t": t0, "until": t0 + LABEL_S, "window": wname, "you": you, "them": them,
				"words": int(you.get("words", 0)) + int(them.get("words", 0)), "words_you": int(you.get("words", 0))})
	_schedule()


## Admission (6.7.4): banner, feed, tag, pair, yours only; an item is admitted if no WINDOW-second span that contains its start
## then holds more than WORDS new words. A wipe banner replaces its fight's feed line (2 words for 5). Feed lines always pass.
func _schedule() -> void:
	admitted = []
	var replaced := {}
	for it in items:
		if String(it["kind"]) == "banner" and it.has("replaces_feed"):
			replaced[String(it["replaces_feed"])] = true
	var rank := {"banner": 0, "feed": 1, "tag": 2, "pair": 3}
	var order: Array = items.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if rank[a["kind"]] != rank[b["kind"]]:
			return int(rank[a["kind"]]) < int(rank[b["kind"]])
		return float(a["t"]) < float(b["t"]))
	for it2 in order:
		var kind := String(it2["kind"])
		if kind == "feed":
			if replaced.has(String(it2["beat"])):
				continue
			admitted.append(it2)
			continue
		if kind == "banner":
			admitted.append(it2)
			continue
		if kind == "pair" and _under_banner(float(it2["t"]), float(it2["until"])):
			continue
		var w := int(it2["words"])
		if _fits(float(it2["t"]), w):
			var a: Dictionary = it2.duplicate()
			if kind == "pair":
				a["show"] = "both" if not (it2["them"] as Dictionary).is_empty() else "you"
			admitted.append(a)
		elif kind == "pair" and int(it2["words_you"]) > 0 and _fits(float(it2["t"]), int(it2["words_you"])):
			var y: Dictionary = it2.duplicate()
			y["show"] = "you"
			y["words"] = int(it2["words_you"])
			admitted.append(y)
	admitted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


func _under_banner(t0: float, t1: float) -> bool:
	for a in admitted:
		if String(a["kind"]) == "banner" and float(a["t"]) < t1 and float(a["until"]) > t0:
			return true
	return false


## True when adding `w` words starting at t keeps every WINDOW span that contains t at WORDS or fewer.
func _fits(t: float, w: int) -> bool:
	var starts: Array = [t - WINDOW, t]
	for a in admitted:
		var at := float(a["t"])
		if at >= t - WINDOW and at <= t:
			starts.append(at)
	for s0 in starts:
		var lo := float(s0)
		if t < lo or t > lo + WINDOW:
			continue
		var sum := w
		for a2 in admitted:
			var at2 := float(a2["t"])
			if at2 >= lo and at2 <= lo + WINDOW:
				sum += int(a2["words"])
		if sum > WORDS:
			return false
	return true


## The most new words that start inside any WINDOW span of the schedule (the 6.7.10 test number).
func max_words() -> int:
	var best := 0
	for a in admitted:
		var lo := float(a["t"])
		var sum := 0
		for b in admitted:
			if float(b["t"]) >= lo and float(b["t"]) <= lo + WINDOW:
				sum += int(b["words"])
		best = maxi(best, sum)
	return best


## What shows at t: {pair: item or {}, tag: item or {}, banner: item or {}}; `fast` (x2) hides the pairs.
func at(t: float, fast: bool = false) -> Dictionary:
	var out := {"pair": {}, "tag": {}, "banner": {}}
	for a in admitted:
		if t < float(a["t"]) or t >= float(a["until"]):
			continue
		var kind := String(a["kind"])
		if kind == "pair" and not fast:
			out["pair"] = a
		elif kind == "tag":
			out["tag"] = a
		elif kind == "banner":
			out["banner"] = a
	return out


## The plan chip's parts for your plan in force at t (4.2): up to three, by |value| (ties g, t, m, l, a, s, r), then the jungle
## focus; "Plan: neutral" when nothing is set. The words are the Game Plan screen's own (gp.end.*, gp.jf.*).
func plan_parts(t: float) -> Array:
	var plan := plan_of(me, t >= 21.0)
	var order := ["g", "t", "m", "l", "a", "s", "r"]
	var ids: Array = []
	for id in order:
		if int(plan.get(id, 0)) != 0:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var va := absi(int(plan[a]))
		var vb := absi(int(plan[b]))
		return va > vb or (va == vb and order.find(a) < order.find(b)))
	var parts: Array = []
	for id2 in ids:
		if parts.size() >= 3:
			break
		parts.append(Strings.t("gp.end.%s.%s" % [id2, "pos" if int(plan[id2]) > 0 else "neg"]))
	var jf := String(plan.get("jf", ""))
	if parts.size() < 3 and jf != "" and jf != "none":
		parts.append(Strings.f("arena.plan.jungle", {"lane": Strings.t("gp.jf." + jf)}))
	if parts.is_empty():
		parts.append(Strings.t("arena.plan.neutral"))
	return parts


## Your set has a trigger plan ("If behind" chip), and whether it is lit (after the plan check, when it fired).
func if_behind() -> Dictionary:
	var sets: Dictionary = s.res.get("plans", {})
	var ps = sets.get(me, null)
	var trig: Array = ps.get("triggers", []) if ps is Dictionary else []
	var when := String(trig[0]["when"]) if not trig.is_empty() else ""
	return {"has": not trig.is_empty(), "when": when, "fired": String(s.plan_used.get(me, "default")) != "default"}
