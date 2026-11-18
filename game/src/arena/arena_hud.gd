class_name ArenaHud
extends RefCounted
## The arena's HUD (Alpha 0.8 A-05, UI-PASS-2 6.7.2 to 6.7.7): drawn controls that read the show script at show time t, so a
## frame, x2 or Skip all show the same numbers (H4). Glyphs come from the arena's own icon texture (ArenaMap.texture()), so they
## batch with each other; the side marks are Icons side_you (circle) and side_them (hexagon): shape first, colour second.
##   Board  the scoreboard strip: row A banners, clock, gold lead; row B kills and towers per side, the phase chip; row C the
##          lead graph (gold lead F7 over show time, centre line = even, above = you), objective markers (stone at 45 percent,
##          moon at 80 percent: an outline before the beat, the owner's shape after it), phase ticks at 24.0 and 51.0 s
##   Feed   the feed block: the newest result (tick or cross, the contest's name, 1 to 3 size dots), the previous one dimmed;
##          "The game begins." before the first; the end card from 75 s (the result line and the closing sentence)
##   Strip  (A-07) the plan row (your plan chip, up to three parts, and the "If behind" chip: dim until the plan check, lit if it
##          fired) and the intent row (your label left with a circle, theirs right with a hexagon) from ArenaLabels
## The status tag replaces the phase chip for 2.0 s; a banner (plan switch, wipe) takes over the feed block. Text is never smaller
## than 24 px (the floor).

const PHASE_MID := 24.0
const PHASE_LATE := 51.0
const GOLD_SCALE := 6000.0      # gold that fills half the graph band
const SIZE_DOTS := {"narrow": 1, "clear": 2, "decisive": 3}


static func last_word(name: String) -> String:
	var parts := name.strip_edges().split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else name


static func grouped(n: int) -> String:
	var a := str(absi(n))
	var out := ""
	while a.length() > 3:
		out = "," + a.substr(a.length() - 3) + out
		a = a.substr(0, a.length() - 3)
	return a + out


static func mmss(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [s / 60, s % 60]


static func phase_key(t: float) -> String:
	if t >= PHASE_LATE:
		return "match.phase.late"
	if t >= PHASE_MID:
		return "match.phase.mid"
	return "match.phase.early"


## The texts and numbers of the board at t (what the tests read; _draw shows exactly these).
static func board_values(s: ShowScript, t: float) -> Dictionary:
	var sc := s.score_at(t)
	var me := s.my_side
	var them := ShowScript.other(me)
	var gold := int(sc["gold"])
	return {"clock": mmss(float(sc["clock_s"])), "gold": gold, "gold_text": "+" + grouped(gold),    # always "+": the glyph says who leads
			"gold_leader": "" if gold == 0 else ("you" if gold > 0 else "them"),
			"kills_you": int(sc["kills"][me]), "kills_them": int(sc["kills"][them]),
			"towers_you": int(sc["towers"][me]), "towers_them": int(sc["towers"][them]),
			"stone": "" if String(sc["objectives"]["stoneback"]) == "" else ("you" if sc["objectives"]["stoneback"] == me else "them"),
			"moon": "" if String(sc["objectives"]["moonhulk"]) == "" else ("you" if sc["objectives"]["moonhulk"] == me else "them"),
			"phase": phase_key(t)}


## The feed block at t: [line 1, line 2], each {kind: "start"|"result"|"end", key, mine, size, text} or {} when empty.
static func feed_lines(s: ShowScript, t: float, my_club: String, won: bool, decided: String = "") -> Array:
	if t >= ShowScript.WATCH:
		var k := s.score_at(ShowScript.WATCH)["kills"] as Dictionary
		var me := s.my_side
		var score := "%d–%d" % [int(k[me]), int(k[ShowScript.other(me)])]
		return [{"kind": "end", "won": won, "text": Strings.f("match.result.won" if won else "match.result.lost", {"team": my_club, "score": score})},
				{"kind": "end2", "won": won, "text": decided if decided != "" else Strings.t("match.end.win" if won else "match.end.loss")}]
	var shown: Array = []
	for ev in Report.feed(s.res, s.my_side):
		if float(ev["t"]) * ShowScript.WATCH <= t + 1e-9:
			shown.append(ev)
	var out: Array = []
	for i in range(shown.size() - 1, maxi(-1, shown.size() - 3), -1):
		var ev2: Dictionary = shown[i]
		out.append({"kind": "result", "key": ev2["key"], "mine": bool(ev2["mine"]), "size": String(ev2["size"]),
				"t": float(ev2["t"]) * ShowScript.WATCH, "text": Strings.t("feed.t." + String(ev2["key"]))})
	if out.is_empty():
		out.append({"kind": "start", "text": Strings.t("match.start")})
	while out.size() < 2:
		out.append({})
	return out


class Board extends Control:
	var s: ShowScript
	var labels: ArenaLabels
	var tex: Texture2D
	var names: Array = ["", ""]       # [yours, theirs], the last word of each club name
	var t := 0.0

	func _init(p_s: ShowScript, p_tex: Texture2D, mine: String, theirs: String) -> void:
		s = p_s
		tex = p_tex
		names = [ArenaHud.last_word(mine), ArenaHud.last_word(theirs)]
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(720, 142)    # no minimum: large text is 122 (6.7.7)

	func show_at(p_t: float) -> void:
		t = clampf(p_t, 0.0, ShowScript.WATCH)
		queue_redraw()

	func rows() -> Array:
		var h := size.y if size.y > 0.0 else 142.0
		if UI.large:    # 6.7.7: row A 40, row B 44, row C 34, gaps 2 + 2
			return [Rect2(0, 0, size.x, 40.0 * h / 122.0), Rect2(0, 42.0 * h / 122.0, size.x, 44.0 * h / 122.0), Rect2(0, 88.0 * h / 122.0, size.x, 34.0 * h / 122.0)]
		return [Rect2(0, 0, size.x, 44.0 * h / 142.0), Rect2(0, 48.0 * h / 142.0, size.x, 46.0 * h / 142.0), Rect2(0, 98.0 * h / 142.0, size.x, 44.0 * h / 142.0)]

	func graph_rect() -> Rect2:
		var c: Rect2 = rows()[2]
		var w := minf(672.0, size.x - 48.0)
		return Rect2((size.x - w) / 2.0, c.get_center().y - 10.0, w, 20.0)

	func _glyph(key: String, r: Rect2, a: float = 1.0) -> void:
		draw_texture_rect_region(tex, r, ArenaMap.cell_rect(key), Color(1, 1, 1, a))

	func _draw() -> void:
		if s == null:
			return
		var v := ArenaHud.board_values(s, t)
		var R: Array = rows()
		var f26 := UI.font("SemiBold")
		var fnum := UI.font("SemiBold", true)
		var pad := 24.0
		# row A: banners and the centre numbers
		var a: Rect2 = R[0]
		var cy := a.get_center().y
		Icons.draw(self, "side_you", Rect2(pad, cy - 16.0, 32, 32), UI.ACCENT)
		CardKit.text(self, f26, UI.S_SMALL, names[0], pad + 40.0, cy, 150.0, UI.TEXT)
		Icons.draw(self, "side_them", Rect2(size.x - pad - 32.0, cy - 16.0, 32, 32), UI.CORAL)
		CardKit.text(self, f26, UI.S_SMALL, names[1], size.x - pad - 40.0 - 150.0, cy, 150.0, UI.TEXT, 2)
		var clock := String(v["clock"])
		var gold_t := String(v["gold_text"])
		var cw := CardKit.text_w(fnum, UI.S_BODY, clock)
		var gw := CardKit.text_w(fnum, UI.S_BODY, gold_t) + (36.0 if v["gold_leader"] != "" else 0.0)
		var x0 := (size.x - (cw + 24.0 + gw)) / 2.0
		CardKit.text(self, fnum, UI.S_BODY, clock, x0, cy, cw + 4.0, UI.TEXT)
		var gx := x0 + cw + 24.0
		if v["gold_leader"] != "":
			var you := String(v["gold_leader"]) == "you"
			Icons.draw(self, "side_you" if you else "side_them", Rect2(gx, cy - 14.0, 28, 28), UI.ACCENT if you else UI.CORAL)
			gx += 36.0
		CardKit.text(self, fnum, UI.S_BODY, gold_t, gx, cy, 200.0, UI.WARN if _flash() else UI.TEXT)
		# row B: kills and towers per side, the phase chip in the centre
		var b: Rect2 = R[1]
		var by := b.get_center().y
		var k_you := str(v["kills_you"])
		var k_them := str(v["kills_them"])
		_glyph("skull", Rect2(pad, by - 16.0, 32, 32))
		CardKit.text(self, fnum, UI.S_BODY, k_you, pad + 38.0, by, 60.0, UI.TEXT)
		_glyph("tower_plain", Rect2(pad + 96.0, by - 16.0, 32, 32))
		CardKit.text(self, fnum, UI.S_BODY, str(v["towers_you"]), pad + 134.0, by, 40.0, UI.TEXT)
		_glyph("skull", Rect2(size.x - pad - 32.0, by - 16.0, 32, 32))
		CardKit.text(self, fnum, UI.S_BODY, k_them, size.x - pad - 38.0 - 60.0, by, 60.0, UI.TEXT, 2)
		_glyph("tower_plain", Rect2(size.x - pad - 128.0, by - 16.0, 32, 32))
		CardKit.text(self, fnum, UI.S_BODY, str(v["towers_them"]), size.x - pad - 134.0 - 40.0, by, 40.0, UI.TEXT, 2)
		var chip := Strings.t(String(v["phase"]))
		var tag: Dictionary = labels.at(t)["tag"] if labels != null else {}
		var is_tag := not tag.is_empty()
		if is_tag:
			chip = String(tag["text"])
		var glyph_w := 36.0 if is_tag else 0.0
		var chw := minf(CardKit.text_w(UI.font("SemiBold"), UI.S_CAPTION, chip) + 32.0 + glyph_w, size.x - 2.0 * 186.0)
		var chip_r := Rect2((size.x - chw) / 2.0, by - 18.0, chw, 36.0)
		draw_rect(chip_r, UI.PANEL3 if not is_tag else Color(UI.WARN, 0.22))
		if is_tag:
			var mine := String(tag["side"]) == s.my_side
			Icons.draw(self, "side_you" if mine else "side_them", Rect2(chip_r.position.x + 12.0, by - 13.0, 26, 26), UI.ACCENT if mine else UI.CORAL)
		CardKit.text(self, UI.font("SemiBold"), UI.S_CAPTION, chip, chip_r.position.x + 16.0 + glyph_w, by, chw - 24.0 - glyph_w, UI.TEXT)
		# row C: the lead graph
		var g := graph_rect()
		draw_rect(g, Color(UI.VOID, 0.7))
		draw_line(Vector2(g.position.x, g.get_center().y), Vector2(g.end.x, g.get_center().y), Color(UI.TEXT2, 0.5), 1.0)
		for tick in [ArenaHud.PHASE_MID, ArenaHud.PHASE_LATE]:
			var tx: float = g.position.x + g.size.x * float(tick) / ShowScript.WATCH
			draw_line(Vector2(tx, g.position.y - 4.0), Vector2(tx, g.end.y + 4.0), Color(UI.TEXT2, 0.6), 2.0)
		var pts := PackedVector2Array()
		var step := 0.5
		var tt := 0.0
		while tt <= t + 1e-6:
			pts.append(_graph_pt(g, tt))
			tt += step
		pts.append(_graph_pt(g, t))
		if pts.size() >= 2:
			draw_polyline(pts, UI.TEXT, 2.5, true)
		for fl in s.flips:    # a flip pops a diamond marker (F5)
			var ft := float(ShowScript.RESOLVE[fl["beat"]])
			if ft <= t:
				var p := _graph_pt(g, ft + 2.0)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)]), UI.WARN)
		for ob in [["stone", 0.45, "stone"], ["moon", 0.80, "moon"]]:
			var mx := g.position.x + g.size.x * float(ob[1])
			var owner := String(v[ob[2]])
			_glyph(String(ob[0]), Rect2(mx - 14.0, g.get_center().y - 14.0, 28, 28), 1.0 if owner != "" else 0.4)
			if owner != "":
				_glyph("glyph_" + owner, Rect2(mx + 6.0, g.get_center().y - 22.0, 18, 18))

	func _graph_pt(g: Rect2, at: float) -> Vector2:
		var gold := float(s.gold_at(at, s.my_side))
		var y := g.get_center().y - clampf(gold / ArenaHud.GOLD_SCALE, -1.0, 1.0) * g.size.y / 2.0
		return Vector2(g.position.x + g.size.x * at / ShowScript.WATCH, y)

	func _flash() -> bool:    # lead_flash: the gold number flashes for 0.6 s after a flip
		for fl in s.flips:
			var ft := float(ShowScript.RESOLVE[fl["beat"]])
			if t >= ft and t < ft + 0.6:
				return true
		return false


class Feed extends Control:
	var s: ShowScript
	var labels: ArenaLabels
	var decided := ""             # "Decided by: <factor>" (the screen passes it; the arena never computes attribution, A1)
	var my_club := ""
	var won := false
	var t := 0.0

	func _init(p_s: ShowScript, p_my_club: String) -> void:
		s = p_s
		my_club = p_my_club
		won = s.winner == s.my_side
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(672, 80)    # no minimum: large text is one 38 px line

	func show_at(p_t: float) -> void:
		t = clampf(p_t, 0.0, ShowScript.WATCH)
		queue_redraw()

	func lines() -> Array:
		var ls := ArenaHud.feed_lines(s, t, my_club, won, decided)
		if UI.large:    # 6.7.7: one feed line
			return [ls[0], {}]
		return ls

	func _draw() -> void:
		if s == null:
			return
		var h := size.y if size.y > 0.0 else 80.0
		var banner: Dictionary = labels.at(t)["banner"] if labels != null and t < ShowScript.WATCH else {}
		if not banner.is_empty():    # a banner takes over the block: a solid band, amber edge, TEXT words, 26 px
			draw_rect(Rect2(0, 0, size.x, h), UI.PANEL3)
			draw_rect(Rect2(0, 0, 8, h), UI.WARN)
			CardKit.text(self, UI.font("SemiBold"), UI.S_SMALL, String(banner["text"]), 24.0, h / 2.0, size.x - 40.0, UI.TEXT)
			return
		var ls := lines()
		var line_h := h / 2.0 if not UI.large else h
		for i in 2:
			var ln: Dictionary = ls[i]
			if ln.is_empty():
				continue
			var cy := line_h * (float(i) + 0.5)
			var kind := String(ln["kind"])
			if kind == "end":
				Icons.draw(self, "trophy" if bool(ln["won"]) else "flag_red", Rect2(0, cy - 18.0, 36, 36), UI.WARN if bool(ln["won"]) else UI.BAD)
				CardKit.text(self, UI.font("Bold"), UI.S_BODY, String(ln["text"]), 48.0, cy, size.x - 48.0, UI.TEXT)
			elif kind == "end2":
				CardKit.text(self, UI.font("Medium"), UI.S_SMALL, String(ln["text"]), 0.0, cy, size.x, UI.TEXT2)
			elif kind == "start":
				CardKit.text(self, UI.font("Medium"), UI.S_SMALL, String(ln["text"]), 0.0, cy, size.x, UI.TEXT2)
			else:
				var fresh := i == 0 and t - float(ln["t"]) < 4.0
				var col := UI.TEXT if fresh else Color(UI.TEXT2, 0.75)
				Icons.draw(self, "tick" if bool(ln["mine"]) else "cross", Rect2(0, cy - 15.0, 30, 30), col)
				var f := UI.font("SemiBold" if fresh else "Medium")
				var w := CardKit.text_w(f, UI.S_SMALL, String(ln["text"]))
				CardKit.text(self, f, UI.S_SMALL, String(ln["text"]), 42.0, cy, size.x - 120.0, col)
				for d in int(ArenaHud.SIZE_DOTS[String(ln["size"])]):
					draw_circle(Vector2(42.0 + w + 18.0 + 16.0 * float(d), cy), 5.0, col)


class Strip extends Control:
	signal plan_tapped
	var labels: ArenaLabels
	var t := 0.0
	var fast := false

	func _init(p_labels: ArenaLabels) -> void:
		labels = p_labels
		mouse_filter = Control.MOUSE_FILTER_STOP
		size = Vector2(672, 100)

	func show_at(p_t: float, p_fast: bool) -> void:
		t = clampf(p_t, 0.0, ShowScript.WATCH)
		fast = p_fast
		queue_redraw()

	func plan_rect() -> Rect2:
		return Rect2(0, 0, size.x, 44)

	## The plan chip's text: the parts joined, the last part dropped until it fits beside the "If behind" chip (never an ellipsis).
	func plan_text(room: float) -> String:
		var parts: Array = labels.plan_parts(t)
		var f := UI.font("SemiBold")
		while parts.size() > 1 and CardKit.text_w(f, UI.S_CAPTION, ", ".join(parts)) > room:
			parts.pop_back()
		return ", ".join(parts)

	func _gui_input(e: InputEvent) -> void:
		var up := (e is InputEventMouseButton and not (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and not (e as InputEventScreenTouch).pressed)
		if up and plan_rect().has_point((e as InputEventMouse).position if e is InputEventMouse else (e as InputEventScreenTouch).position) and t >= 3.0:
			accept_event()
			plan_tapped.emit()

	func _draw() -> void:
		if labels == null or t >= ShowScript.WATCH:
			return
		var f := UI.font("SemiBold")
		# plan row (from 3.0 s, after the opening labels)
		if t >= 3.0:
			var ib := labels.if_behind()
			var ib_w := 0.0
			if bool(ib["has"]):
				var ib_t := Strings.t("arena.plan.if_behind")
				ib_w = CardKit.text_w(f, UI.S_CAPTION, ib_t) + 32.0
				var lit := bool(ib["fired"]) and t >= 21.0
				var ib_r := Rect2(size.x - ib_w, 2, ib_w, 40)
				draw_rect(ib_r, Color(UI.WARN, 0.25) if lit else Color(UI.PANEL2, 0.6))
				CardKit.text(self, f, UI.S_CAPTION, ib_t, ib_r.position.x + 16.0, 22.0, ib_w, UI.TEXT if lit else UI.TEXT_OFF)
			var room := size.x - ib_w - 12.0 - 32.0
			var pt := plan_text(room)
			var pw := minf(CardKit.text_w(f, UI.S_CAPTION, pt) + 32.0, room + 32.0)
			draw_rect(Rect2(0, 2, pw, 40), UI.PANEL2)
			CardKit.text(self, f, UI.S_CAPTION, pt, 16.0, 22.0, pw - 24.0, UI.TEXT)
		# intent row
		var pair: Dictionary = labels.at(t, fast)["pair"]
		if pair.is_empty():
			return
		var cy := 52.0 + 24.0
		var you: Dictionary = pair["you"]
		if not you.is_empty():
			var yt := String(you["text"])
			var yw := CardKit.text_w(f, UI.S_CAPTION, yt) + 32.0 + 32.0
			draw_rect(Rect2(0, cy - 22.0, yw, 44), Color(UI.ACCENT, 0.16))
			Icons.draw(self, "side_you", Rect2(10, cy - 12.0, 24, 24), UI.ACCENT)
			CardKit.text(self, f, UI.S_CAPTION, yt, 42.0, cy, yw - 48.0, UI.TEXT)
		var them: Dictionary = pair["them"]
		if String(pair.get("show", "both")) == "both" and not them.is_empty():
			var tt := String(them["text"])
			var tw := CardKit.text_w(f, UI.S_CAPTION, tt) + 32.0 + 32.0
			var yw2 := (CardKit.text_w(f, UI.S_CAPTION, String(you.get("text", ""))) + 64.0) if not you.is_empty() else 0.0
			if yw2 + 12.0 + tw <= size.x:    # the pair must fit its row, else only yours shows (6.7.2)
				var r := Rect2(size.x - tw, cy - 22.0, tw, 44)
				draw_rect(r, Color(UI.CORAL, 0.16))
				CardKit.text(self, f, UI.S_CAPTION, tt, r.position.x + 16.0, cy, tw - 48.0, UI.TEXT)
				Icons.draw(self, "side_them", Rect2(r.end.x - 34.0, cy - 12.0, 24, 24), UI.CORAL)
