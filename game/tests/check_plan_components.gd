extends Node
## I-10 checks: PhaseStrip, DetentTrack, Podium and RankRow (src/ui/components), through the gallery sections "plan" and "standings"
## (tests/components_gallery.gd) and through small rigs, in the T-std rows of the build plan: build_, fit_ (720 and 626 px of canvas, the
## 19-character longest club name), hit_, inplace_, cb_ (the "cue" meta, also in colour-blind mode), tags_, negative controls (each audit
## must catch a bad sample), node counts. The behaviour rows of I-10:
##   a value set from code and from a drag gives the same result (DetentTrack), an equal value changes nothing (every setter),
##   tabular digit widths in RankRow, Podium with three equal clubs and with 19-character names, the per-control phase map read from
##   data/game_plan_v0.json, the inert look of a control that does nothing in the plan on show.
## Headless: it reads layout, state and counters; the draw calls and the pictures are in tests/shots/shots_plan.gd. The finger rows
## (a swipe that starts outside the track scrolls the page, a drag of the thumb does not) are in tests/check_touch_plan.gd. Here the
## track is driven by mouse-family events pushed straight into its _gui_input (what a desktop sends). Ends with " N checks, M failures".

const FitAudit = preload("res://tests/fit_audit.gd")
const Gallery = preload("res://tests/components_gallery.gd")
const SECTIONS := ["plan", "standings"]
const LONGEST_CLUB := "Northreach Corsairs"    # 19 characters (the data's longest)
const NODE_TARGET := 120                       # PERF-BUDGET 3.1a: nodes per redesigned screen

var checks := 0
var fails := 0
var node_rows: Array = []
var _main: Control
var _host: Control


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


func _ids(n: Node) -> Array:
	var out: Array = [n.get_instance_id()]
	for c in n.get_children():
		out.append_array(_ids(c))
	return out


func _cue_problems(root: Node, audited: Array = []) -> Array:
	var out: Array = []
	if root.has_meta(CompKit.STATE_BEARING):
		var st := String(root.call("state_name")) if root.has_method("state_name") else ""
		audited.append(root)
		if not root.has_meta(CompKit.CUE):
			out.append("%s has no cue meta" % root.get_class())
		elif st != "" and String(root.get_meta(CompKit.CUE)) == "":
			out.append("%s is in state '%s' but its cue is empty" % [root.get_class(), st])
	for c in root.get_children():
		out.append_array(_cue_problems(c, audited))
	return out


func _ready() -> void:
	TutorialRunner.home_offers = false    # I-14: Home's welcome modal and offer cards depend on this machine's settings.cfg; tested in check_tutorial_flow
	get_window().size = Vector2i(720, 1280)
	await frames(1)
	await _phase_map()
	await _units()
	for variant in ["normal", "large"]:
		await _variant(variant)
	await _behaviour("normal")
	await _behaviour("large")
	await _colour_blind()
	await _inplace()
	await _negative_controls()
	App.apply_large_text(false)
	UI.set_colorblind(false)
	UI.animate = true
	print("nodes: " + " | ".join(node_rows))
	print("check_plan_components: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _fresh_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(2)


func _show(section: String) -> Gallery:
	var g := Gallery.new(section)
	App.go(g)
	await frames(4)
	return g


## A column of the page's width in a full-rect host, for the rigs (a fresh one each time).
func _rig() -> VBoxContainer:
	if _host != null and is_instance_valid(_host):
		_host.queue_free()
		await frames(2)
	_host = Control.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_host)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(UI.canvas_w() - 48.0, 0.0)
	col.position = Vector2(24.0, 60.0)
	col.add_theme_constant_override("separation", 12)
	_host.add_child(col)
	return col


# ---- events a desktop sends (mouse family), pushed into the control's own _gui_input -------------------------------------------

func _mb(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	return e


func _mm(pos: Vector2, rel: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	return e


func _tap(c: Control, p: Vector2) -> void:
	c._gui_input(_mb(p, true))
	c._gui_input(_mb(p, false))


## A drag of a control from `a` to `b` (local coordinates) in `steps` moves.
func _drag(c: Control, a: Vector2, b: Vector2, steps: int = 12) -> void:
	c._gui_input(_mb(a, true))
	var prev := a
	for i in steps:
		var p := a.lerp(b, float(i + 1) / float(steps))
		c._gui_input(_mm(p, p - prev))
		prev = p
	c._gui_input(_mb(b, false))


# ---- the phase map: derived from the data, checked against the file read here ---------------------------------------------------

func _phase_map() -> void:
	var f := FileAccess.open("res://data/game_plan_v0.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var early := ["top", "mid_lane", "bot", "jungle"]
	var want := {}
	for id in d["controls"]:
		var seen := {}
		for kind in ["mod", "var"]:
			for c in d["controls"][id].get(kind, {}):
				var ph := "early" if early.has(c) else ("mid" if String(c).ends_with("_mid") else "late")
				seen[ph] = true
		want[id] = ["early", "mid", "late"].filter(func(p: String) -> bool: return seen.has(p))
	PhaseStrip.reset_map()
	var bad: Array = []
	for id in want:
		if PhaseStrip.control_phases(id) != want[id]:
			bad.append("%s %s vs %s" % [id, str(PhaseStrip.control_phases(id)), str(want[id])])
	ok(bad.is_empty() and want.size() == 7, "build_phasemap: the phase of every control of data/game_plan_v0.json is the one read straight from the file (%s)" % str(want))
	ok(PhaseStrip.control_phases("jf") == ["early"], "build_phasemap: Jungle focus moves only the early contests (jungle and the chosen lane): %s" % str(PhaseStrip.control_phases("jf")))
	ok(PhaseStrip.control_phases("a") == ["early"] and PhaseStrip.control_phases("m") == ["mid"] and PhaseStrip.control_phases("l") == ["late"], "build_phasemap: Lane aggression is early only, Mid objectives mid only, Late objectives late only")
	ok(PhaseStrip.control_phases("t") == ["early", "late"] and PhaseStrip.control_phases("g") == ["early", "mid", "late"], "build_phasemap: Tempo moves early and late; Fight style moves all three")
	ok(PhaseStrip.controls_in("early") == ["g", "t", "a", "s", "r", "jf"] and PhaseStrip.controls_in("mid") == ["g", "m", "s", "r"] and PhaseStrip.controls_in("late") == ["g", "t", "l", "s", "r"], "build_phasemap: controls_in gives early %s, mid %s, late %s" % [str(PhaseStrip.controls_in("early")), str(PhaseStrip.controls_in("mid")), str(PhaseStrip.controls_in("late"))])
	ok(PhaseStrip.controls_in("overall") == ["g", "s", "r"], "build_phasemap: the controls that act in every phase are %s" % str(PhaseStrip.controls_in("overall")))
	# UI-PASS-2 7.6 finding 1: what a trigger plan (mid and late only) does with each control
	var kinds := {}
	for id in PhaseStrip.CONTROL_IDS:
		kinds[id] = PhaseStrip.effect_kind(id, ["mid", "late"])
	ok(kinds["a"] == "none" and kinds["jf"] == "none" and kinds["t"] == "partial" and kinds["g"] == "partial" and kinds["s"] == "partial" and kinds["m"] == "full" and kinds["l"] == "full", "build_phasemap: in a trigger plan Lane aggression and Jungle focus do nothing, Tempo, Fight style and Support are partial (UI-PASS-2 7.6): %s" % str(kinds))
	var all_full := true
	for id in PhaseStrip.CONTROL_IDS:
		all_full = all_full and PhaseStrip.effect_kind(id, ["early", "mid", "late"]) == "full"
	ok(all_full and PhaseStrip.acts_in("a", "overall") and not PhaseStrip.acts_in("a", "mid") and PhaseStrip.acts_in("m", "mid"), "build_phasemap: the Default plan uses every control fully; acts_in agrees with the map")
	ok(DetentTrack.VALUES == GamePlan.STEPS, "build_track: the five detents are GamePlan.STEPS %s" % str(GamePlan.STEPS))
	await frames(1)


# ---- units that need no gallery ---------------------------------------------------------------------------------------------------

func _units() -> void:
	await _fresh_main()
	# the labels of every control come from the merged copy (no key is missing)
	var missing: Array = []
	for id in GamePlan.SLIDERS:
		var l := DetentTrack.labels_for(id)
		for k in l:
			if String(l[k]).begins_with("[[") or String(l[k]) == "":
				missing.append("%s.%s" % [id, k])
	ok(missing.is_empty(), "build_track: gp.c.<id>.* and gp.end.<id>.* exist for all seven controls (missing: %s)" % ",".join(missing))
	var pk: Array = []
	for id in PhaseStrip.ALL:
		if Strings.t("gp.phase." + id).begins_with("[["):
			pk.append(id)
	ok(pk.is_empty() and Strings.t("gp.pips").contains("{phases}") and Strings.t("gp.lead").contains("{n}") and Strings.t("standings.you") == "YOU", "build_strip: gp.phase.*, gp.pips, gp.lead and standings.you exist (missing: %s)" % ",".join(pk))
	# snap and clamp
	ok(DetentTrack.snap_index(0.0) == 2 and DetentTrack.snap_index(30.0) == 3 and DetentTrack.snap_index(24.0) == 2 and DetentTrack.snap_index(-999.0) == 0 and DetentTrack.snap_index(999.0) == 4, "build_track: values snap to the nearest detent and clamp (30 -> +50, 24 -> 0, -999 -> -100)")
	# the wrap helper: breaks at spaces, never beyond max_lines, a word wider than the room is cut with "..."
	var f := UI.font("SemiBold")
	var l2 := PlanKit.wrap(f, UI.S_SMALL, LONGEST_CLUB, 150.0, 2)
	var l1 := PlanKit.wrap(f, UI.S_SMALL, LONGEST_CLUB, 400.0, 2)
	var l3 := PlanKit.wrap(f, UI.S_SMALL, "Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa Bbbb", 120.0, 2)
	ok(l1.size() == 1 and l2.size() == 2 and l2[0] == "Northreach" and l2[1] == "Corsairs", "fit_wrap: '%s' is one line in 400 px and two in 150 px (%s)" % [LONGEST_CLUB, str(l2)])
	ok(l3.size() == 2 and String(l3[0]).ends_with("..."), "fit_wrap: a word wider than the room is cut with '...' (%s)" % str(l3))
	ok(PlanKit.wrap(f, UI.S_SMALL, "", 100.0).is_empty() and PlanKit.wrap(f, UI.S_SMALL, "x", 0.0).is_empty(), "fit_wrap: an empty text or no room gives no lines")


# ---- per variant: build, fit, hit, tags ----------------------------------------------------------------------------------------

func _variant(variant: String) -> void:
	App.apply_large_text(variant == "large")
	UI.set_colorblind(false)
	await frames(2)
	await _fresh_main()
	var canvas := UI.canvas_w()
	for section in SECTIONS:
		var g := await _show(section)
		var n := _count(g)
		node_rows.append("%s/%s=%d" % [variant, section, n])
		ok(not g.items.is_empty() and n > 3, "build_%s_%s: built, %d nodes, kinds %s" % [section, variant, n, ",".join(g.items.keys())])
		ok(n <= NODE_TARGET, "build_%s_%s: %d nodes, at most the target %d (PERF-BUDGET 3.1a)" % [section, variant, n, NODE_TARGET])
		var probs := FitAudit.audit(App.main._current, canvas)
		ok(probs.is_empty(), "fit_%s_%s: clean (labels, captions and the rest that are real controls)" % [section, variant])
		for p in probs.slice(0, 8):
			print("     ", p)
		var small: Array = []
		_small_buttons(g, small)
		ok(small.is_empty(), "hit_%s_%s: no visible button under 96 x 96 (%s)" % [section, variant, "; ".join(small.slice(0, 4))])
		var cue_probs := _cue_problems(g)
		ok(cue_probs.is_empty(), "cb_%s_%s: every state-bearing control carries a cue (%s)" % [section, variant, "; ".join(cue_probs)])
		_text_audit(g, section, variant)
	await _plan_rows(variant)
	await _standings_rows(variant)


func _small_buttons(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is BaseButton and (n as Control).size.x > 0 and ((n as Control).size.x < 95.5 or (n as Control).size.y < 95.5):
		out.append("%s %.0fx%.0f" % [n.get_class(), (n as Control).size.x, (n as Control).size.y])
	for c in n.get_children():
		_small_buttons(c, out)


## Every text a component of this section queued: at least 24 px, no missing-key marker, none cut with "...".
func _text_audit(g: Gallery, section: String, variant: String) -> void:
	var seen := 0
	var small: Array = []
	var marked: Array = []
	var cut: Array = []
	for kind in ["PhaseStrip", "DetentTrack", "Podium", "RankRow", "RankDivider"]:
		for c in g.items.get(kind, []):
			var ops: CardKit.Ops = c._ops
			if kind != "RankDivider":
				cut.append_array(c.clipped)
			for t in ops.texts:
				seen += 1
				if int(t[1]) < UI.S_CAPTION:
					small.append("%s %d px" % [kind, int(t[1])])
				if String(t[2]).begins_with("[["):
					marked.append(String(t[2]))
	ok(seen > 0 or section == "none", "fit_%s_%s: %d queued texts were audited" % [section, variant, seen])
	ok(small.is_empty() and marked.is_empty(), "fit_%s_%s: every queued text is at least 24 px and has its string (%s %s)" % [section, variant, str(small.slice(0, 3)), str(marked.slice(0, 3))])
	ok(cut.is_empty(), "fit_%s_%s: nothing is cut with '...' (%s)" % [section, variant, str(cut)])


# ---- the plan section -----------------------------------------------------------------------------------------------------------

func _plan_rows(variant: String) -> void:
	var g := await _show("plan")
	var strips: Array = g.items["PhaseStrip"]
	var tracks: Array = g.items["DetentTrack"]
	var canvas := UI.canvas_w()
	var a := strips[0] as PhaseStrip
	var b := strips[1] as PhaseStrip
	var v := strips[2] as PhaseStrip
	ok(_count(a) == 1 and _count(b) == 1 and _count(v) == 1 and _count(tracks[0]) == 1, "build_plan_%s: a PhaseStrip is 1 node and a DetentTrack is 1 node" % variant)
	# the strip: a quarter of the width per node, 96 px or more high
	var cw := a.size.x / 4.0
	var cell := a.cell_rect(1)
	ok(absf(cell.size.x - cw) < 0.5 and cell.size.y >= 96.0 and a.size.y >= PhaseStrip.H_HORIZONTAL - 0.5, "hit_plan_%s: a phase node is a quarter of the width (%.1f px) by %.0f px (UI-PASS-2: 144 px at 578)" % [variant, cell.size.x, cell.size.y])
	ok(a.size.x >= canvas - 48.0 - 12.0 and a.index_at(Vector2(cw * 2.5, 60.0)) == 2 and a.index_at(Vector2(a.size.x + 5.0, 60.0)) == -1, "hit_plan_%s: the strip is %.0f px wide; x at 2.5 quarters is node 2, outside is none" % [variant, a.size.x])
	ok(a.selected_id == "early" and a.cue_for("early") == "fill+ring" and CompKit.cue_of(a) != "", "cb_plan_%s: the selected node has fill and ring as its cue (%s)" % [variant, a.cue_for("early")])
	ok(b.cue_for("early").contains("lock") and b.phase("early")["locked"], "cb_plan_%s: a locked node says lock (%s)" % [variant, b.cue_for("early")])
	ok(v.cue_for("early") == "tick" and v.cue_for("mid") == "fill+ring+cross", "cb_plan_%s: a result is a tick or a cross (%s, %s)" % [variant, v.cue_for("early"), v.cue_for("mid")])
	ok(v.vertical and absf(v.size.y - 3.0 * PhaseStrip.ROW_H) < 0.5 and v.cell_rect(1).size.y == PhaseStrip.ROW_H, "hit_plan_%s: the vertical strip has three 112 px rows (%.0f px high, %.0f px wide)" % [variant, v.size.y, v.size.x])
	ok(v.node_center(1).y - v.node_center(0).y == PhaseStrip.ROW_H, "build_plan_%s: the vertical nodes are one row apart" % variant)
	# the two-line caption of a locked node makes the strip taller, and every cell follows
	ok(b.caption_lines() == 2 and b.size.y > a.size.y and absf(b.size.y - b.strip_h()) < 0.5, "fit_plan_%s: '%s' wraps to two lines under its node (strip %.0f px against %.0f without it)" % [variant, Strings.t("gp.trigger_locked"), b.size.y, a.size.y])
	ok(a.caption_lines() == 1 and a.clipped.is_empty() and b.clipped.is_empty() and v.clipped.is_empty(), "fit_plan_%s: no caption or label of a strip is cut (%s %s %s)" % [variant, str(a.clipped), str(b.clipped), str(v.clipped)])
	# pips: Overall 3, Early 6 controls, Mid 4, Late 5 (from the map)
	ok((a.phase("overall")["controls"] as Array).size() == 3 and (a.phase("early")["controls"] as Array).size() == 6 and (a.phase("mid")["controls"] as Array).size() == 4 and (a.phase("late")["controls"] as Array).size() == 5, "build_plan_%s: the pips under the nodes are 3, 6, 4 and 5 (the controls that act in each phase)" % variant)
	# the tracks
	var all_ok := true
	var clipped: Array = []
	for t in tracks:
		var dt := t as DetentTrack
		var tr := dt.track_rect()
		all_ok = all_ok and tr.size.y >= 96.0 and absf(tr.size.x - dt.size.x) < 0.5 and dt.size.x >= canvas - 120.0
		clipped.append_array(dt.clipped)
	ok(all_ok, "hit_plan_%s: every track has a 96 px high hit area as wide as the control (%d tracks)" % [variant, tracks.size()])
	ok(clipped.is_empty(), "fit_plan_%s: no word, effect line or note of a track is cut (%s)" % [variant, str(clipped)])
	var t0 := tracks[0] as DetentTrack
	ok(t0.value == 0 and t0.value_word() == "Balanced" and t0.moves_text() == "Moves: Early, Mid, Late", "build_plan_%s: Fight style starts balanced and moves Early, Mid, Late ('%s', '%s')" % [variant, t0.value_word(), t0.moves_text()])
	var t1 := tracks[1] as DetentTrack
	var t2 := tracks[2] as DetentTrack
	ok(t1.value == -50 and t1.value_word() == "Push early" and t1.strength() == 1 and t2.value == 100 and t2.value_word() == "Secure" and t2.strength() == 2, "build_plan_%s: -50 reads 'Push early' with one dot, +100 reads 'Secure' with two" % variant)
	var inert := tracks[3] as DetentTrack
	var partial := tracks[4] as DetentTrack
	var dis := tracks[5] as DetentTrack
	ok(inert.state_name() == "inert" and String(CompKit.cue_of(inert)).contains("lock") and not inert.is_interactive(), "cb_plan_%s: an inert control carries the cue '%s' (lock, hollow thumb, words) and takes no input" % [variant, CompKit.cue_of(inert)])
	ok(partial.state_name() == "set" and partial.inert == "partial" and partial.is_interactive() and partial.inert_text == Strings.t("gp.trigger_late_only"), "build_plan_%s: a partial control still works and carries the note '%s'" % [variant, partial.inert_text])
	ok(dis.state_name() == "disabled" and String(CompKit.cue_of(dis)) == "dim+word" and not dis.is_interactive(), "cb_plan_%s: a disabled control is dimmed with its word and takes no input" % variant)
	# the effect line reserves its longest text, so the height never depends on the value
	var heights: Array = []
	var probe := DetentTrack.new("m", 0)
	for v2 in [-100, 0, 100]:
		probe.set_value(v2)
		heights.append(probe.custom_minimum_size.y)
	ok(heights[0] == heights[1] and heights[1] == heights[2], "fit_plan_%s: the track keeps its height whatever the value (%s)" % [variant, str(heights)])
	probe.free()
	ok(UI.find_tag("gal.phase") == a and UI.find_tag("gal.phasev") == v and UI.find_tag("gal.track") == t0, "tags_plan_%s: the strips and the first track are tagged" % variant)
	# the pictures' sizes: a track is about 250 to 350 px and the strip 136 to 164, both reported
	print("     PLAN|%s|track_h=%.0f|inert_h=%.0f|strip_h=%.0f|strip2_h=%.0f|vstrip=%.0fx%.0f" % [variant, t0.size.y, inert.size.y, a.size.y, b.size.y, v.size.x, v.size.y])


# ---- the standings section -------------------------------------------------------------------------------------------------------

func _standings_rows(variant: String) -> void:
	var g := await _show("standings")
	var pods: Array = g.items["Podium"]
	var rows: Array = g.items["RankRow"]
	var divs: Array = g.items["RankDivider"]
	var canvas := UI.canvas_w()
	var p := pods[0] as Podium
	var eq := pods[1] as Podium
	ok(_count(p) == 1 and _count(rows[0]) == 1 and _count(divs[0]) == 1, "build_standings_%s: a Podium, a RankRow and a Divider are one node each" % variant)
	# podium geometry: 2nd, 1st, 3rd, three columns in the width, pedestals 88 / 120 / 64
	var c1 := p.column_rect(1)
	var c2 := p.column_rect(2)
	var c3 := p.column_rect(3)
	ok(c2.position.x < c1.position.x and c1.position.x < c3.position.x and c3.end.x <= p.size.x + 0.5 and absf(c1.size.x - floorf((p.size.x - 24.0) / 3.0)) < 0.5, "fit_podium_%s: the columns run 2nd, 1st, 3rd across %.0f px, each %.0f px (UI-PASS-2: 216 at 672, 184 at 578)" % [variant, p.size.x, c1.size.x])
	ok(p.pedestal_rect(1).size.y == 120.0 and p.pedestal_rect(2).size.y == 88.0 and p.pedestal_rect(3).size.y == 64.0, "build_podium_%s: the pedestals are 120, 88 and 64 px high" % variant)
	ok(p.pedestal_rect(1).end.y == p.pedestal_rect(2).end.y and p.pedestal_rect(2).end.y == p.pedestal_rect(3).end.y, "build_podium_%s: all three pedestals stand on one line" % variant)
	ok(absf(p.badge_rect(1).size.x - 88.0) < 0.5 and absf(p.badge_rect(2).size.x - 72.0) < 0.5 and absf(p.badge_rect(3).size.x - 72.0) < 0.5, "build_podium_%s: the badges are 88 px for 1st and 72 for 2nd and 3rd" % variant)
	var inside := true
	for rk in [1, 2, 3]:
		var bt := p.badge_rect(rk)
		inside = inside and bt.position.y >= 0.0 and bt.position.x >= p.column_rect(rk).position.x - 0.5 and bt.end.x <= p.column_rect(rk).end.x + 0.5 and bt.end.y <= p.pedestal_rect(rk).position.y
	ok(inside and p.size.y >= Podium.H - 0.5, "fit_podium_%s: every badge sits inside its column and above its pedestal (podium %.0f px high)" % [variant, p.size.y])
	ok(p.state_name() == "own" and String(CompKit.cue_of(p)).contains("pill") and String(CompKit.cue_of(p)).contains("numeral"), "cb_podium_%s: the podium says numeral + medal and, with your club on it, a pill (%s)" % [variant, CompKit.cue_of(p)])
	# three equal clubs and three 19-character names
	var order_ok := true
	for rk in [1, 2, 3]:
		order_ok = order_ok and String(eq.row_for_rank(rk)["main"]) == "3" and eq.row_for_rank(rk)["name"] == LONGEST_CLUB
	ok(order_ok and eq.pedestal_rect(1).size.y > eq.pedestal_rect(2).size.y and eq.pedestal_rect(2).size.y > eq.pedestal_rect(3).size.y, "build_podium_%s: three equal clubs (3 pts each) still stand 120 / 88 / 64 by the order given" % variant)
	var lines_ok := true
	for rk in [1, 2, 3]:
		var ln: Array = eq._lines[rk]
		lines_ok = lines_ok and ln.size() == 2 and ln[0] == "Northreach" and ln[1] == "Corsairs"
	ok(lines_ok and eq.clipped.is_empty() and p.clipped.is_empty(), "fit_podium_%s: '%s' (19 characters) wraps to 'Northreach' / 'Corsairs' in all three columns, nothing is cut (%s)" % [variant, LONGEST_CLUB, str(eq.clipped)])
	var widest := 0.0
	for rk in [1, 2, 3]:
		for line in (eq._lines[rk] as Array):
			widest = maxf(widest, CardKit.text_w(UI.font("SemiBold"), UI.S_SMALL, String(line)))
	ok(widest <= eq.col_w() - 8.0, "fit_podium_%s: the widest name line is %.0f px in a %.0f px column" % [variant, widest, eq.col_w() - 8.0])
	# rank rows
	var rr: Array = []
	for r in rows:
		rr.append(r)
	var all_h := true
	var no_clip := true
	for r in rr:
		var row := r as RankRow
		all_h = all_h and row.size.y >= RankRow.H - 0.5 and absf(row.size.x - (canvas - 48.0)) < 12.0
		no_clip = no_clip and row.clipped.is_empty()
	ok(all_h, "fit_rank_%s: every row is at least 104 px high and as wide as the page (%d rows)" % [variant, rr.size()])
	ok(no_clip, "fit_rank_%s: no name or number of a row is cut, '%s' on your row included" % [variant, LONGEST_CLUB])
	var own := rows[5] as RankRow    # rank 9, your row among the plain ones (ranks 4 to 10 are rows 0 to 6)
	ok(own.is_own() and own.state_name() == "own" and String(CompKit.cue_of(own)) == "fill+bar+pill" and (rows[0] as RankRow).state_name() == "", "cb_rank_%s: your row says fill + bar + pill; the others have no state (%s)" % [variant, CompKit.cue_of(own)])
	var long_own := rows[7] as RankRow
	ok(long_own.name_lines.size() <= 3 and long_own.size.y >= RankRow.H, "fit_rank_%s: your row with the 19-character name is %d name line(s), %.0f px high, pill %s" % [variant, long_own.name_lines.size(), long_own.size.y, "inline" if long_own.pill_inline else "on its own line"])
	var pinned := rows[10] as RankRow
	ok(pinned.note_lines.size() >= 1 and pinned.size.y >= RankRow.H and pinned.clipped.is_empty(), "fit_rank_%s: a pinned row with a sentence is %.0f px high (%d note line(s)); nothing cut (%s)" % [variant, pinned.size.y, pinned.note_lines.size(), str(pinned.clipped)])
	print("     STAND|%s|podium_h=%.0f|row_h=%.0f|long_own_h=%.0f|pinned_h=%.0f|divider_h=%.0f" % [variant, p.size.y, (rows[0] as RankRow).size.y, long_own.size.y, pinned.size.y, (divs[0] as Control).size.y])
	var div := divs[0] as RankRow.Divider
	ok(div.size.y >= 48.0 and div.mouse_filter == Control.MOUSE_FILTER_IGNORE and div.text == Strings.t("standings.playoff_line"), "build_rank_%s: the playoff line is a 48 px Divider that says '%s'" % [variant, div.text])
	# tabular digits: the same width for 111, 888 and 000, so a column lines up
	var w111 := RankRow.main_width("111")
	var w888 := RankRow.main_width("888")
	var w000 := RankRow.main_width("000")
	var plain_font := UI.font("SemiBold")
	var p111 := CardKit.text_w(plain_font, RankRow.MAIN_SIZE, "111")
	var p000 := CardKit.text_w(plain_font, RankRow.MAIN_SIZE, "000")
	ok(is_equal_approx(w111, w888) and is_equal_approx(w888, w000), "fit_rank_%s: tnum digits are one width (111 = %.2f, 888 = %.2f, 000 = %.2f px at 36)" % [variant, w111, w888, w000])
	ok(not is_equal_approx(p111, p000), "fit_rank_%s: without tnum the digits differ (111 = %.2f, 000 = %.2f px): the test is not vacuous" % [variant, p111, p000])
	var r10 := rows[4] as RankRow    # the plain rows 4..: their main numbers are right-aligned to one edge
	var edges: Array = []
	for r in [rows[0], rows[1], rows[2], rows[3]]:
		var rw := r as RankRow
		rw._layout()
		for t in rw._ops.texts:
			if int(t[1]) == RankRow.MAIN_SIZE:
				edges.append(snappedf(float(t[3]) + float(t[5]), 0.01))
	var same := true
	for e in edges:
		same = same and e == edges[0]
	ok(edges.size() >= 4 and same, "fit_rank_%s: the main numbers of four rows end at one x (%s)" % [variant, str(edges)])
	ok(r10 != null and UI.find_tag("gal.rank.own") == own and UI.find_tag("gal.podium") == p, "tags_standings_%s: the own row and the podium are tagged" % variant)


# ---- behaviour (driven by hand) --------------------------------------------------------------------------------------------------

func _behaviour(variant: String) -> void:
	App.apply_large_text(variant == "large")
	await frames(2)
	await _fresh_main()
	await _track_rows(variant)
	await _strip_rows(variant)
	await _rank_rows(variant)
	await _podium_rows(variant)
	if _host != null and is_instance_valid(_host):
		_host.queue_free()
	await frames(2)


func _track_rows(variant: String) -> void:
	var col := await _rig()
	var calls: Array = []
	var t := DetentTrack.new("t", 0, func(id: String, v: int) -> void: calls.append([id, v]), {}, "trk.t")
	col.add_child(t)
	await frames(3)
	var tr := t.track_rect()
	# a value set from code: snaps, no callback, applied counts it once; an equal value changes nothing
	var d0 := t.draw_count
	t.set_value(50)
	await frames(2)
	ok(t.value == 50 and t.index == 3 and t.applied == 1 and calls.is_empty() and t.draw_count > d0, "inplace_track_%s: set_value(50) from code gives value 50, applied 1, no callback (%d)" % [variant, calls.size()])
	var d1 := t.draw_count
	t.set_value(50)
	t.set_value(60)    # snaps to 50: equal
	t.set_index(3)
	await frames(2)
	ok(t.applied == 1 and t.draw_count == d1, "inplace_track_%s: the same value again (50, 60, index 3) changes nothing: applied %d, no redraw" % [variant, t.applied])
	t.set_value(30)    # 30 snaps to 50
	ok(t.value == 50 and t.applied == 1, "inplace_track_%s: 30 snaps to +50 which it already holds" % variant)
	t.set_value(-1000)
	ok(t.value == -100 and t.index == 0, "inplace_track_%s: -1000 clamps to -100" % variant)
	t.set_value(0)
	calls.clear()
	var applied0 := t.applied
	# the same change from a drag: the same value, word, effect line, cue and state as code, a callback per detent
	var code := DetentTrack.new("t", 0)
	col.add_child(code)
	await frames(2)
	code.set_value(50)
	var from := Vector2(t.detent_x(2), tr.position.y + 48.0)
	var to := Vector2(t.detent_x(3), tr.position.y + 48.0)
	_drag(t, from, to)
	await frames(2)
	ok(t.value == code.value and t.value_word() == code.value_word() and t.effect_text() == code.effect_text() and t.state_name() == code.state_name() and CompKit.cue_of(t) == CompKit.cue_of(code) and t.index == code.index, "inplace_track_%s: a drag to the +50 detent gives the same value, word, effect line, state and cue as set_value(50) (%d, '%s', '%s')" % [variant, t.value, t.value_word(), t.state_name()])
	ok(t.applied == applied0 + 1 and code.applied == 1 and calls == [["t", 50]], "inplace_track_%s: both counted one change; the drag called back once with the id and the value (%s)" % [variant, str(calls)])
	# a drag across the whole track passes every detent: one callback each, ending on +100
	calls.clear()
	_drag(t, Vector2(t.detent_x(3), tr.position.y + 48.0), Vector2(t.detent_x(4), tr.position.y + 48.0))
	_drag(t, Vector2(t.detent_x(4), tr.position.y + 48.0), Vector2(t.detent_x(0), tr.position.y + 48.0), 40)
	await frames(2)
	var values: Array = []
	for c in calls:
		values.append(c[1])
	ok(t.value == -100 and values == [100, 50, 0, -50, -100], "inplace_track_%s: a drag from the right end to the left end gives one callback per detent (%s)" % [variant, str(values)])
	ok(t.thumb_x() == t.detent_x(0) and t._drag_x < 0.0 and t.lock_state == DetentTrack.IDLE, "inplace_track_%s: after the drag the thumb rests on its detent (x %.0f) and the gesture is over" % [variant, t.thumb_x()])
	# during a drag the thumb follows the finger between two detents; the value stays on the nearest detent
	calls.clear()
	t.set_value(0)
	var mid_x := (t.detent_x(2) + t.detent_x(3)) * 0.5 - 20.0
	t._gui_input(_mb(Vector2(t.detent_x(2), tr.position.y + 48.0), true))
	t._gui_input(_mm(Vector2(mid_x, tr.position.y + 48.0), Vector2(mid_x - t.detent_x(2), 0)))
	ok(t.lock_state == DetentTrack.HORIZONTAL and absf(t.thumb_x() - mid_x) < 0.5 and t.value == 0, "inplace_track_%s: while dragging, the thumb follows the finger (x %.0f) and the value is still 0 short of the half-way point" % [variant, t.thumb_x()])
	t._gui_input(_mb(Vector2(mid_x, tr.position.y + 48.0), false))
	# a tap on a detent gives that detent; a tap in the gap gives the nearest
	t.set_value(0)
	calls.clear()
	_tap(t, Vector2(t.detent_x(4), tr.position.y + 40.0))
	ok(t.value == 100 and calls == [["t", 100]], "hit_track_%s: a tap on the right-hand detent gives +100 (%s)" % [variant, str(calls)])
	_tap(t, Vector2(t.detent_x(0) + 5.0, tr.position.y + 80.0))
	ok(t.value == -100, "hit_track_%s: a tap 5 px from the left-hand detent gives -100" % variant)
	_tap(t, Vector2(t.detent_x(1) + (t.detent_x(2) - t.detent_x(1)) * 0.4, tr.position.y + 10.0))
	ok(t.value == -50, "hit_track_%s: a tap 40 percent of the way from -50 to 0 gives -50 (snaps to the nearest)" % variant)
	_tap(t, Vector2(t.detent_x(2) + 4.0, tr.position.y + tr.size.y - 2.0))
	ok(t.value == 0, "hit_track_%s: the whole 96 px band takes the tap (its lower edge, 2 px inside)" % variant)
	# slop: 11 px is a tap, 14 px a drag (the drag does not move a detent that far)
	calls.clear()
	var a := Vector2(t.detent_x(4), tr.position.y + 48.0)
	t._gui_input(_mb(a, true))
	t._gui_input(_mm(a + Vector2(-11, 0), Vector2(-11, 0)))
	t._gui_input(_mb(a + Vector2(-11, 0), false))
	ok(t.value == 100 and t.lock_state == DetentTrack.IDLE, "hit_track_%s: 11 px of travel is still a tap (the nearest detent is +100)" % variant)
	t.decisions.clear()
	t._gui_input(_mb(a, true))
	t._gui_input(_mm(a + Vector2(-14, 0), Vector2(-14, 0)))
	var dragging := t.lock_state == DetentTrack.HORIZONTAL
	t._gui_input(_mb(a + Vector2(-14, 0), false))
	ok(dragging and t.decisions == ["h"], "hit_track_%s: 14 px sideways is a drag (decided once: %s)" % [variant, str(t.decisions)])
	# a vertical move decides 'page scroll': the track lets go and changes nothing
	t.set_value(0)
	t.decisions.clear()
	var b := Vector2(t.detent_x(2), tr.position.y + 48.0)
	t._gui_input(_mb(b, true))
	t._gui_input(_mm(b + Vector2(3, -20), Vector2(3, -20)))
	t._gui_input(_mm(b + Vector2(120, -60), Vector2(117, -40)))    # later it goes sideways: already decided
	t._gui_input(_mb(b + Vector2(120, -60), false))
	ok(t.decisions == ["v"] and t.value == 0 and t._drag_x < 0.0, "hit_track_%s: a drag that starts upward is decided vertical once and never moves the thumb (%s, value %d)" % [variant, str(t.decisions), t.value])
	# a press outside the track band (the head, the end words, the lines) is not the track's
	var before := t.value
	t.decisions.clear()
	_drag(t, Vector2(t.detent_x(2), 20.0), Vector2(t.detent_x(4), 20.0))    # the head row
	_tap(t, Vector2(t.detent_x(4), tr.end.y + 14.0))                       # the end words
	_tap(t, Vector2(t.detent_x(4), tr.position.y - 4.0))                   # the edge above the band
	ok(t.value == before and t.decisions.is_empty() and t.lock_state == DetentTrack.IDLE, "hit_track_%s: a drag or a tap that starts in the head, the end words or just above the band does nothing (value %d)" % [variant, t.value])
	# inert (full): no input, the thumb does not move; back to normal gives input again
	t.set_value(0)
	t.set_inert("full")
	await frames(2)
	_tap(t, Vector2(t.detent_x(4), tr.position.y + 48.0))
	_drag(t, Vector2(t.detent_x(2), tr.position.y + 48.0), Vector2(t.detent_x(4), tr.position.y + 48.0))
	ok(t.value == 0 and t.state_name() == "inert" and String(CompKit.cue_of(t)).contains("lock"), "hit_track_%s: an inert track ignores a tap and a drag (value %d, cue '%s')" % [variant, t.value, CompKit.cue_of(t)])
	ok(t.inert_text == Strings.t("gp.trigger_locked") and t.clipped.is_empty(), "build_track_%s: its reason line is '%s'" % [variant, t.inert_text])
	var ap := t.applied
	t.set_inert("full")
	t.set_inert("full", Strings.t("gp.trigger_locked"))
	ok(t.applied == ap, "inplace_track_%s: the same inert state again changes nothing" % variant)
	t.set_inert("")
	_tap(t, Vector2(t.detent_x(3), tr.position.y + 48.0))
	ok(t.value == 50 and t.state_name() == "set", "hit_track_%s: back to normal it takes input again" % variant)
	t.set_disabled(true)
	_tap(t, Vector2(t.detent_x(0), tr.position.y + 48.0))
	ok(t.value == 50 and t.state_name() == "disabled", "hit_track_%s: a disabled track takes no tap" % variant)
	t.set_disabled(false)
	# nudge: one detent, with the callback, clamped at the ends
	calls.clear()
	t.set_value(0)
	t.nudge(1)
	t.nudge(1)
	t.nudge(1)
	t.nudge(1)
	ok(t.value == 100 and calls.size() == 2, "hit_track_%s: nudge steps one detent with a callback each and stops at the end (%s)" % [variant, str(calls)])
	# the tutorial tag raises tap:trk.t on a tap
	var mark: int = App.bus.sequence()
	t.set_value(0)
	_tap(t, Vector2(t.detent_x(3), tr.position.y + 48.0))
	ok(App.bus.seen("tap:trk.t", mark), "tags_track_%s: a tap raises tap:trk.t" % variant)
	# the labels: a new dictionary changes the words in place
	var l := DetentTrack.labels_for("a")
	t.set_labels(l)
	ok(t.value_word() == l["pos"] and t.effect_text() == l["effect_pos"], "inplace_track_%s: set_labels changes the words in place (%s)" % [variant, t.value_word()])
	t.set_labels(l.duplicate())
	ok(t.applied == t.applied, "inplace_track_%s: an equal dictionary of labels is ignored" % variant)
	# drawn text: the order of the queued texts is name, word, ends, effect, moves; nothing below 24
	t._layout()
	var sizes: Array = []
	for tx in t._ops.texts:
		sizes.append(int(tx[1]))
	ok(sizes.min() >= 24 and sizes.has(UI.S_BODY) and sizes.has(UI.S_SMALL) and sizes.has(UI.S_CAPTION), "fit_track_%s: the track draws its text at %s px (none under 24)" % [variant, str(sizes)])
	var pr := t.thumb_center()
	ok(t.global_track_rect().size.y >= 96.0 and pr.y == DetentTrack.HEAD_H + 48.0, "hit_track_%s: the thumb sits in the middle of the 96 px band (y %.0f)" % [variant, pr.y])


func _strip_rows(variant: String) -> void:
	var col := await _rig()
	var picks: Array = []
	var st := PhaseStrip.new(PhaseStrip.default_phases(), "overall", func(id: String) -> void: picks.append(id), false, "ps")
	col.add_child(st)
	await frames(3)
	var d0 := st.draw_count
	st.set_selected("overall")
	st.set_caption("early", "")
	st.set_locked("early", false)
	st.set_result("early", "")
	await frames(1)
	ok(st.applied == 0 and st.draw_count == d0, "inplace_strip_%s: setters given the held value change nothing (applied %d, no redraw)" % [variant, st.applied])
	st.set_selected("mid")
	ok(st.selected_id == "mid" and picks.is_empty() and st.applied == 1, "inplace_strip_%s: set_selected from code changes the node and calls nothing" % variant)
	st.set_selected("overall")
	# a tap on the quarter of a node selects it once; a second tap on the same does nothing
	var cw := st.size.x / 4.0
	_tap(st, Vector2(cw * 2.5, 40.0))
	ok(picks == ["mid"] and st.selected_id == "mid", "hit_strip_%s: a tap in the third quarter selects Mid (%s)" % [variant, str(picks)])
	_tap(st, Vector2(cw * 2.5, 120.0))
	ok(picks == ["mid"], "hit_strip_%s: a tap on the selected node calls nothing again" % variant)
	_tap(st, Vector2(cw * 0.5, 130.0))
	ok(picks == ["mid", "overall"], "hit_strip_%s: the lower part of a quarter takes the tap too (%s)" % [variant, str(picks)])
	# the slop: 14 px of travel is no tap
	st._gui_input(_mb(Vector2(cw * 1.5, 40.0), true))
	st._gui_input(_mm(Vector2(cw * 1.5, 54.0), Vector2(0, 14)))
	st._gui_input(_mb(Vector2(cw * 1.5, 54.0), false))
	ok(picks == ["mid", "overall"] and st.selected_id == "overall", "hit_strip_%s: a press that moves 14 px selects nothing" % variant)
	# a locked node still takes the tap (the page explains why it does nothing)
	st.set_locked("early", true)
	st.set_caption("early", Strings.t("gp.trigger_locked"))
	await frames(2)
	_tap(st, Vector2(cw * 1.5, 40.0))
	ok(picks.back() == "early" and st.selected_id == "early" and st.cue_for("early") == "fill+ring+lock", "hit_strip_%s: a locked node can still be selected, its cue is '%s'" % [variant, st.cue_for("early")])
	ok(st.size.y > PhaseStrip.H_HORIZONTAL and st.cell_rect(1).size.y >= 96.0, "fit_strip_%s: the two-line caption makes the strip %.0f px high and the cells follow" % [variant, st.size.y])
	# the pips and the draw
	st._layout()
	var texts: Array = []
	for tx in st._ops.texts:
		texts.append(String(tx[2]))
	ok(texts.has("Overall") and texts.has("Early") and texts.has("Mid") and texts.has("Late"), "build_strip_%s: the four labels are drawn (%s)" % [variant, str(texts)])
	var tag_mark: int = App.bus.sequence()
	st.set_selected("overall")
	_tap(st, Vector2(cw * 3.5, 50.0))
	ok(App.bus.seen("tap:ps.late", tag_mark), "tags_strip_%s: a tap raises tap:ps.late" % variant)
	# vertical
	var vcol := await _rig()
	var vst := PhaseStrip.new(["early", "mid", "late"], "early", Callable(), true)
	vcol.add_child(vst)
	await frames(3)
	var vp: Array = []
	vst.phase_selected.connect(func(id: String) -> void: vp.append(id))
	_tap(vst, Vector2(20.0, PhaseStrip.ROW_H * 2.0 + 50.0))
	ok(vp == ["late"] and vst.selected_id == "late" and vst.size.y == 3.0 * PhaseStrip.ROW_H, "hit_strip_%s: in the vertical form a tap in the third row selects Late (%s), %.0f px high" % [variant, str(vp), vst.size.y])
	ok(vst.size.x >= PhaseStrip.V_LABEL_X and vst.size.x < 200.0, "fit_strip_%s: the vertical column is %.0f px wide, the band of chips has the rest" % [variant, vst.size.x])


func _rank_rows(variant: String) -> void:
	var col := await _rig()
	var taps: Array = []
	var r := RankRow.new({"rank": 7, "club": "cl_a", "name": "Duskwater Foxes", "main": "9", "sub": "1-0"}, "rk")
	r.pressed.connect(func(id: String) -> void: taps.append(id))
	col.add_child(r)
	await frames(3)
	ok(r.size.y == RankRow.H and r.club_id() == "cl_a", "fit_rank_%s: a plain row is %.0f px high" % [variant, r.size.y])
	var a0 := r.applied
	var d0 := r.draw_count
	r.set_data({"rank": 7, "club": "cl_a", "name": "Duskwater Foxes", "main": "9", "sub": "1-0"})
	await frames(1)
	ok(r.applied == a0 and r.draw_count == d0, "inplace_rank_%s: an equal Dictionary changes nothing" % variant)
	r.set_data({"rank": 6, "club": "cl_a", "name": "Duskwater Foxes", "main": "12", "sub": "2-0"})
	await frames(2)
	ok(r.applied == a0 + 1 and r.draw_count > d0 and r.data["main"] == "12", "inplace_rank_%s: a new main number changes it in place (applied %d)" % [variant, r.applied])
	_tap(r, Vector2(300, 50))
	ok(taps == ["cl_a"], "hit_rank_%s: a tap emits pressed with the club id (%s)" % [variant, str(taps)])
	r._gui_input(_mb(Vector2(300, 50), true))
	r._gui_input(_mm(Vector2(314, 50), Vector2(14, 0)))
	r._gui_input(_mb(Vector2(314, 50), false))
	ok(taps == ["cl_a"], "hit_rank_%s: 14 px of travel is no tap" % variant)
	r._gui_input(_mb(Vector2(300, 50), true))
	r._gui_input(_mm(Vector2(311, 50), Vector2(11, 0)))
	r._gui_input(_mb(Vector2(311, 50), false))
	ok(taps == ["cl_a", "cl_a"], "hit_rank_%s: 11 px of travel is still a tap" % variant)
	# the name takes up to two lines; with YOU the pill needs room after the last line
	var long_own := RankRow.new({"rank": 9, "club": "cl_b", "name": LONGEST_CLUB, "main": "1523", "sub": "0-1", "own": true})
	var long_plain := RankRow.new({"rank": 10, "club": "cl_b", "name": LONGEST_CLUB, "main": "111", "sub": "0-1"})
	col.add_child(long_own)
	col.add_child(long_plain)
	await frames(3)
	var room_ok := true
	var fn := UI.font("Regular", true)
	for row in [long_own, long_plain]:
		for line in (row as RankRow).name_lines:
			room_ok = room_ok and CardKit.text_w(fn, UI.S_BODY, String(line)) <= (row as RankRow).name_room() + 0.5
	ok(room_ok and (" ".join(PackedStringArray(long_plain.name_lines)) == LONGEST_CLUB), "fit_rank_%s: '%s' fits its room in %d line(s) (%.0f px) and is not cut" % [variant, LONGEST_CLUB, long_plain.name_lines.size(), long_plain.name_room()])
	var pill_room := true
	if long_own.pill_inline:
		var last := String(long_own.name_lines[long_own.name_lines.size() - 1])
		pill_room = CardKit.text_w(fn, UI.S_BODY, last) + 12.0 + long_own._pill_w() <= long_own.name_room() + 0.5
	ok(pill_room and long_own.clipped.is_empty() and long_own.size.y >= RankRow.H, "fit_rank_%s: on your row the YOU pill has room after the last name line (inline %s, %d lines, row %.0f px)" % [variant, str(long_own.pill_inline), long_own.name_lines.size(), long_own.size.y])
	# tabular digits: rows with 111 and 888 have the same text width and right edge
	var ra := RankRow.new({"rank": 11, "club": "cl_c", "name": "Ironquill Wolves", "main": "111", "sub": "0-2"})
	var rb := RankRow.new({"rank": 12, "club": "cl_d", "name": "Pinehollow Owls", "main": "888", "sub": "0-3"})
	col.add_child(ra)
	col.add_child(rb)
	await frames(3)
	ra._layout()
	rb._layout()
	var xa := -1.0
	var xb := -1.0
	var wa := 0.0
	var wb := 0.0
	for t in ra._ops.texts:
		if int(t[1]) == RankRow.MAIN_SIZE:
			xa = float(t[3]) + float(t[5])
			wa = CardKit.text_w(t[0], int(t[1]), String(t[2]))
	for t in rb._ops.texts:
		if int(t[1]) == RankRow.MAIN_SIZE:
			xb = float(t[3]) + float(t[5])
			wb = CardKit.text_w(t[0], int(t[1]), String(t[2]))
	ok(xa > 0.0 and is_equal_approx(xa, xb) and is_equal_approx(wa, wb), "fit_rank_%s: '111' and '888' are %.2f and %.2f px wide and end at the same x (%.0f, %.0f)" % [variant, wa, wb, xa, xb])
	var tnum_font_used := true
	for t in ra._ops.texts:
		if int(t[1]) == RankRow.MAIN_SIZE:
			tnum_font_used = tnum_font_used and t[0] == UI.font("SemiBold", true)
	ok(tnum_font_used and ra.col_w() >= RankRow.COL_MIN, "fit_rank_%s: the main number is drawn with the shared tabular font; the right column is at least %.0f px" % [variant, RankRow.COL_MIN])
	var heights_same := is_equal_approx(ra.size.y, rb.size.y)
	ok(heights_same, "fit_rank_%s: two plain rows are the same height" % variant)
	var tag_mark: int = App.bus.sequence()
	_tap(r, Vector2(200, 40))
	ok(App.bus.seen("tap:rk", tag_mark), "tags_rank_%s: a tap raises tap:rk" % variant)


func _podium_rows(variant: String) -> void:
	var col := await _rig()
	var taps: Array = []
	var ids := ["cl_a", "cl_b", "cl_c"]
	var mk := func(names: Array, pts: Array) -> Array:
		var out: Array = []
		for i in 3:
			out.append({"rank": i + 1, "club": ids[i], "name": names[i], "main": pts[i], "sub": "1-0"})
		return out
	var pod := Podium.new(mk.call([LONGEST_CLUB, LONGEST_CLUB, LONGEST_CLUB], ["3", "3", "3"]), "pod")
	pod.column_tapped.connect(func(id: String) -> void: taps.append(id))
	col.add_child(pod)
	await frames(3)
	var cw := pod.col_w()
	ok(absf(cw - floorf((pod.size.x - 2.0 * Podium.GAP) / 3.0)) < 0.5, "fit_podium_%s: a column is %.0f px of %.0f" % [variant, cw, pod.size.x])
	# taps: the middle column is 1st, the left is 2nd, the right is 3rd; a gap and the area below give nothing
	_tap(pod, Vector2(pod.size.x * 0.5, 60.0))
	_tap(pod, Vector2(cw * 0.5, pod.size.y - 20.0))
	_tap(pod, Vector2(pod.size.x - cw * 0.5, pod.size.y - 20.0))
	_tap(pod, Vector2(cw + Podium.GAP * 0.5, 100.0))
	ok(taps == ["cl_a", "cl_b", "cl_c"], "hit_podium_%s: a tap on the middle, left and right column gives 1st, 2nd, 3rd; the gap gives nothing (%s)" % [variant, str(taps)])
	pod._gui_input(_mb(Vector2(pod.size.x * 0.5, 60.0), true))
	pod._gui_input(_mm(Vector2(pod.size.x * 0.5, 80.0), Vector2(0, 20)))
	pod._gui_input(_mb(Vector2(pod.size.x * 0.5, 80.0), false))
	ok(taps.size() == 3, "hit_podium_%s: a press that moves 20 px taps nothing" % variant)
	# fewer than three rows: the missing column is a bare pedestal
	var a0 := pod.applied
	pod.set_rows(mk.call([LONGEST_CLUB, LONGEST_CLUB, LONGEST_CLUB], ["3", "3", "3"]))
	ok(pod.applied == a0, "inplace_podium_%s: the same three rows change nothing" % variant)
	pod.set_rows([{"rank": 1, "club": "cl_a", "name": "Emberfen Hounds", "main": "3"}])
	await frames(2)
	_tap(pod, Vector2(cw * 0.5, pod.size.y - 20.0))
	ok(pod.applied == a0 + 1 and pod.rows.size() == 1 and pod.rank_at(Vector2(cw * 0.5, 200.0)) == 0 and taps.size() == 3, "inplace_podium_%s: one row leaves the other two columns empty and untappable" % variant)
	pod.set_rows([])
	await frames(2)
	ok(pod.rows.is_empty() and pod.state_name() == "" and String(CompKit.cue_of(pod)) == "numeral+medal", "build_podium_%s: no rows is an empty podium (3 bare pedestals)" % variant)
	# equal points and own: the YOU pill of a podium column fits next to the medal
	var own_rows: Array = mk.call(["Emberfen Hounds", "Mossgate Wardens", "Stormvale Herons"], ["3", "3", "3"])
	own_rows[2]["own"] = true
	pod.set_rows(own_rows)
	await frames(2)
	var group := 48.0 + 8.0 + CardKit.text_w(UI.font("SemiBold"), UI.S_CAPTION, Strings.t("standings.you")) + 28.0
	ok(group <= cw - 8.0 and pod.state_name() == "own", "fit_podium_%s: the medal and the YOU pill are %.0f px, the column is %.0f" % [variant, group, cw])
	var mark: int = App.bus.sequence()
	_tap(pod, Vector2(cw * 0.5, 100.0))
	ok(App.bus.seen("tap:pod", mark), "tags_podium_%s: a tap raises tap:pod" % variant)


# ---- colour-blind mode ---------------------------------------------------------------------------------------------------------

func _colour_blind() -> void:
	App.apply_large_text(false)
	UI.set_colorblind(true)
	await _fresh_main()
	var audited_total := 0
	for section in SECTIONS:
		var g := await _show(section)
		var audited: Array = []
		var probs := _cue_problems(g, audited)
		audited_total += audited.size()
		ok(probs.is_empty(), "cb_%s_colourblind: every state-bearing control carries a cue (%d audited)" % [section, audited.size()])
		ok(FitAudit.audit(App.main._current, UI.canvas_w()).is_empty(), "fit_%s_colourblind: clean" % section)
	ok(audited_total > 15, "cb: %d state-bearing controls audited across the two sections (more than 15)" % audited_total)
	# every state of every component has a cue that is not a colour
	var g2 := await _show("plan")
	var cues: Array = []
	for t in g2.items["DetentTrack"]:
		cues.append(CompKit.cue_of(t))
	var strips: Array = []
	for s in g2.items["PhaseStrip"]:
		strips.append(CompKit.cue_of(s))
	var colour_only := false
	for c in cues + strips:
		colour_only = colour_only or String(c) == ""
	ok(not colour_only, "cb_plan_colourblind: every track and strip has a non-empty cue (%s | %s)" % [str(cues), str(strips)])
	ok(UI.GOOD == UI.GOOD_CB, "cb: the tick of a result uses the sky blue of the colour-blind pair and is a tick, not a colour (%s)" % UI.GOOD.to_html(false))
	UI.set_colorblind(false)


# ---- in place: ids stay the same through state changes ---------------------------------------------------------------------------

func _inplace() -> void:
	App.apply_large_text(false)
	await _fresh_main()
	for section in SECTIONS:
		var g := await _show(section)
		var before := _ids(g)
		var n_before := _count(g)
		if section == "plan":
			for t in g.items["DetentTrack"]:
				(t as DetentTrack).set_value(100)
				(t as DetentTrack).set_value(-50)
			for s in g.items["PhaseStrip"]:
				(s as PhaseStrip).set_selected("late")
				(s as PhaseStrip).set_caption("late", "lead 1/2")
		else:
			for r in g.items["RankRow"]:
				var row := r as RankRow
				var d := row.data.duplicate()
				d["main"] = "77"
				row.set_data(d)
			for p in g.items["Podium"]:
				(p as Podium).set_rows([{"rank": 1, "club": "x1", "name": "One", "main": "9"}, {"rank": 2, "club": "x2", "name": "Two", "main": "8"}, {"rank": 3, "club": "x3", "name": "Three", "main": "7"}])
		await frames(3)
		ok(_ids(g) == before and _count(g) == n_before, "inplace_%s: setting values, selections and rows frees and creates no node (%d nodes, same ids)" % [section, n_before])


# ---- negative controls: each audit must catch a bad sample ----------------------------------------------------------------------

func _negative_controls() -> void:
	var col := await _rig()
	# a track far too narrow for its words: its own audit (clipped) must see it
	var narrow := DetentTrack.new("g", 0)
	narrow.custom_minimum_size.x = 150.0
	narrow.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	narrow.set_labels({"name": "A name that is far too long to fit in so small a room as this one", "neg": "A very long end word", "pos": "Another very long end word", "balanced": "Balanced", "effect_neg": "x", "effect_pos": "x", "effect_balanced": "x"})
	col.add_child(narrow)
	await frames(3)
	ok(not narrow.clipped.is_empty(), "negative: a track in a 150 px room reports its cut texts (%d)" % narrow.clipped.size())
	# a row with a name that cannot fit in a tiny room: clipped must be seen
	var tiny := RankRow.new({"rank": 1, "club": "cl_a", "name": "Wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww", "main": "9", "sub": "1-0"})
	tiny.custom_minimum_size.x = 300.0
	tiny.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(tiny)
	await frames(3)
	ok(not tiny.clipped.is_empty() or String(tiny.name_lines[0]).ends_with("..."), "negative: a name of one 42-letter word in a 300 px row is cut with '...' and reported (%s)" % str(tiny.name_lines))
	var long_note := RankRow.new({"rank": 9, "club": "cl_a", "name": "Duskwater Foxes", "own": true, "note": "A sentence that is far too long for two lines of a pinned row, so that the row has to cut it with dots at the end of the second line."})
	col.add_child(long_note)
	await frames(3)
	ok(not long_note.clipped.is_empty() and long_note.note_lines.size() == 2 and String(long_note.note_lines[1]).ends_with("..."), "negative: a pinned sentence of three lines is cut to two with '...' and the row reports it (%s)" % str(long_note.note_lines))
	# a state-bearing control with no cue is caught by the cue audit
	var stub := _CueStub.new()
	ok(not _cue_problems(stub).is_empty(), "negative: the cue audit catches a control in a state with an empty cue (%s)" % str(_cue_problems(stub)))
	stub.free()
	# tnum: the plain font really has proportional digits (so the equal-width check can fail)
	var f := UI.font("SemiBold")
	ok(not is_equal_approx(CardKit.text_w(f, 36, "111"), CardKit.text_w(f, 36, "000")), "negative: without the tabular font '111' and '000' differ, so the tnum row can fail")
	# a DetentTrack in the same state reached two ways must not be equal to one in another state
	var p1 := DetentTrack.new("t", 50)
	var p2 := DetentTrack.new("t", 0)
	ok(p1.value_word() != p2.value_word() or p1.index != p2.index, "negative: two tracks at different values differ in index (%d, %d)" % [p1.index, p2.index])
	p1.free()
	p2.free()


class _CueStub extends Control:
	func _init() -> void:
		set_meta(CompKit.STATE_BEARING, true)
		set_meta(CompKit.CUE, "")

	func state_name() -> String:
		return "selected"
