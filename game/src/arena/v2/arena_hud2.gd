class_name ArenaHud2
extends RefCounted
## The Arena v2 HUD (Phase 4): drawn controls that read an ArenaPlayer at game time t, so a frame, a speed-up or Skip all show
## the same numbers. Side marks are shape first, colour second (a circle for you, a hexagon for them; Founder rule).
##   Board  club names, the game clock, kills, towers destroyed, the gold lead and who holds Stoneback and Moonhulk
##   Feed   the two newest events of the log in words (kills, towers, objectives, the Cairn), then the end line
##   Notes  one line of what your team is doing now (a gank, a roam, a call to gather), from the log's intents and calls
## Text is never smaller than 24 px (the floor).

const SLOTS := ["top", "jg", "mid", "bot", "sup"]


static func mmss(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [s / 60, s % 60]


static func grouped(n: int) -> String:
	var a := str(absi(n))
	var out := ""
	while a.length() > 3:
		out = "," + a.substr(a.length() - 3) + out
		a = a.substr(0, a.length() - 3)
	return a + out


## The numbers on the board at t (tests read these; _draw shows exactly these).
static func board_values(pl: ArenaPlayer, t: float) -> Dictionary:
	var sc := pl.score(t)
	var me := pl.my_side
	var them := "R" if me == "B" else "B"
	var lead := int(sc["gold"][me]) - int(sc["gold"][them])
	var stone := ""
	var moon := ""
	for o in pl.objs:
		if float(o[0]) <= t:
			var who := "you" if String(o[2]) == me else "them"
			if String(o[1]) == "stoneback":
				stone = who
			elif String(o[1]) == "moonhulk":
				moon = who
	return {"clock": mmss(t), "kills_you": int(sc["kills"][me]), "kills_them": int(sc["kills"][them]),
			"towers_you": int(sc["towers"][me]), "towers_them": int(sc["towers"][them]), "gold": lead,
			"gold_text": "+" + grouped(lead), "gold_leader": "" if lead == 0 else ("you" if lead > 0 else "them"),
			"stone": stone, "moon": moon}


static func hero_name(pl: ArenaPlayer, key: String) -> String:
	return String(SimData.heroes()[pl.hero_of[key]]["name"])


static func team_word(pl: ArenaPlayer, side: String, mine: String, theirs: String) -> String:
	return mine if side == pl.my_side else theirs


## The feed at t: up to two lines, newest first: [{text, side ("" = neutral)}].
static func feed_lines(pl: ArenaPlayer, t: float, mine: String, theirs: String) -> Array:
	var ev: Array = []
	var first := true
	for k in pl.kills:
		var killer := String(k[1])
		if killer.begins_with("tower."):
			continue
		var key := "arena2.feed.first_blood" if first else "arena2.feed.kill"
		first = false
		ev.append([float(k[0]), Strings.f(key, {"killer": hero_name(pl, killer), "victim": hero_name(pl, String(k[2]))}), ArenaPlayer.side_of(killer)])
	for tw in pl.towers:
		var id := String(tw[1])
		var team := team_word(pl, String(tw[2]), mine, theirs)
		if id.ends_with("cairn"):
			ev.append([float(tw[0]), Strings.f("arena2.feed.cairn", {"team": team}), String(tw[2])])
		else:
			var lane := id.split(".")[1]
			var lane_word := Strings.t("arena.lane." + lane) if lane in ["top", "mid", "bot"] else Strings.t("arena2.base")
			ev.append([float(tw[0]), Strings.f("arena2.feed.tower", {"team": team, "lane": lane_word}), String(tw[2])])
	for o in pl.objs:
		ev.append([float(o[0]), Strings.f("arena2.feed.objective", {"team": team_word(pl, String(o[2]), mine, theirs), "place": Strings.t("arena2.place." + String(o[1]))}), String(o[2])])
	ev.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out: Array = []
	for e in ev:
		if float(e[0]) <= t:
			out.append({"text": String(e[1]), "side": String(e[2])})
			if out.size() == 2:
				break
	if out.is_empty():
		out.append({"text": Strings.t("arena2.feed.start"), "side": ""})
	return out


## One line of what your team is doing now ("" when nothing notable in the last few seconds).
static func notes_line(pl: ArenaPlayer, t: float) -> String:
	var best: Array = []
	for n in pl.notes(t):
		var who := String(n[1])
		var mine := who == "team." + pl.my_side or (not who.begins_with("team.") and ArenaPlayer.side_of(who) == pl.my_side)
		if not mine:
			continue
		if best.is_empty() or float(n[0]) >= float(best[0]):
			best = n
	if best.is_empty():
		return ""
	var kind := String(best[2])
	var tgt := String(best[3])
	var lane_word := Strings.t("arena.lane." + tgt) if tgt in ["top", "mid", "bot"] else tgt
	var v := 1 + int(float(best[0])) % 3
	match kind:
		"gank":
			return Strings.f(["arena.label.jg_gank.1", "arena.label.jg_gank.2", "arena.label.jg_gank.3"][v - 1], {"lane": lane_word})
		"roam":
			return Strings.f("arena2.note.roam", {"lane": lane_word})
		"call_group":
			return Strings.f(["arena.label.rot_late.1", "arena.label.rot_late.2", "arena.label.rot_late.3"][v - 1], {"place": Strings.t("arena2.place." + tgt)})
		"call_siege":
			return Strings.f("arena2.note.siege", {"lane": lane_word})
		"call_defend":
			return Strings.f("arena2.note.defend", {"lane": lane_word})
	return ""


class Board extends Control:
	var pl: ArenaPlayer
	var t := 0.0
	var mine := ""
	var theirs := ""
	var you := UI.ACCENT
	var them := UI.CORAL

	func _init(p: ArenaPlayer, p_mine: String, p_theirs: String) -> void:
		pl = p
		mine = p_mine
		theirs = p_theirs
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_at(p_t: float) -> void:
		t = p_t
		queue_redraw()

	## Match Day M2 layout (150 px): the two header buttons sit in the side columns (`side_w` each, placed by the screen); the
	## middle shows the club names and the clock, the kills and towers, and the gold-lead bar (ARENA-HUD-2 2.1): centred, teal
	## to the left with a circle end when you lead, coral to the right with a hexagon end when they lead, the difference
	## written on it; who holds Stoneback and Moonhulk at the bar's ends.
	var side_w := 0.0

	func _draw() -> void:
		var f := get_theme_default_font()
		var v := ArenaHud2.board_values(pl, t)
		draw_rect(Rect2(Vector2.ZERO, size), Color(UI.BG, 0.92))
		# row A, full width: the club names and the clock (the header buttons sit below it)
		var top := 26.0
		_text(f, mine, Vector2(16, top), UI.S_CAPTION, you, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.40)
		_text(f, theirs, Vector2(size.x - 16, top), UI.S_CAPTION, them, HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.40)
		_text(f, String(v["clock"]), Vector2(size.x * 0.5, top), UI.S_CAPTION, UI.TEXT2, HORIZONTAL_ALIGNMENT_CENTER, 90)
		# rows B and C, between the buttons
		var x0 := side_w + 6.0
		var x1 := size.x - side_w - 6.0
		var cx := (x0 + x1) * 0.5
		var mw := x1 - x0
		var blk := (mw - 120.0) * 0.5
		var mid := 72.0
		_text(f, str(v["kills_you"]), Vector2(cx - 20, mid + 14), UI.S_TITLE, you, HORIZONTAL_ALIGNMENT_RIGHT, 60)
		_text(f, "–", Vector2(cx, mid + 10), UI.S_HEAD, UI.TEXT2, HORIZONTAL_ALIGNMENT_CENTER, 40)
		_text(f, str(v["kills_them"]), Vector2(cx + 20, mid + 14), UI.S_TITLE, them, HORIZONTAL_ALIGNMENT_LEFT, 60)
		draw_circle(Vector2(x0 + 8, mid - 6), 8.0, you)
		_text(f, Strings.f("arena2.board.towers", {"n": v["towers_you"]}), Vector2(x0 + 22, mid + 2), UI.S_CAPTION, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, blk - 22.0)
		_hex(Vector2(x1 - 9, mid - 6), 9.0, them)
		_text(f, Strings.f("arena2.board.towers", {"n": v["towers_them"]}), Vector2(x1 - 22, mid + 2), UI.S_CAPTION, UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, blk - 22.0)
		for pair in [["stone", Strings.t("arena2.place.stoneback"), x0, HORIZONTAL_ALIGNMENT_LEFT], ["moon", Strings.t("arena2.place.moonhulk"), x1, HORIZONTAL_ALIGNMENT_RIGHT]]:
			var holder := String(v[pair[0]])
			var col := UI.TEXT2 if holder == "" else (you if holder == "you" else them)
			_text(f, String(pair[1]), Vector2(float(pair[2]), mid + 30.0), UI.S_CAPTION, col, int(pair[3]), blk)
		# the gold-lead bar (ARENA-HUD-2 2.1)
		var by := size.y - 14.0
		var bar := Rect2(x0, by - 5.0, mw, 10.0)
		draw_rect(bar, UI.PANEL3)
		var lead := int(v["gold"])
		var half := bar.size.x * 0.5
		var fill := clampf(absf(float(lead)) / 10000.0, 0.0, 1.0) * half
		var c := bar.position.x + half
		if lead > 0:
			draw_rect(Rect2(c - fill, bar.position.y, fill, bar.size.y), you)
			draw_circle(Vector2(c - fill, by), 8.0, you)
		elif lead < 0:
			draw_rect(Rect2(c, bar.position.y, fill, bar.size.y), them)
			_hex(Vector2(c + fill, by), 9.0, them)
		draw_rect(Rect2(c - 1.0, bar.position.y - 4.0, 2.0, bar.size.y + 8.0), UI.TEXT2)
		var lead_col := UI.TEXT2 if String(v["gold_leader"]) == "" else (you if String(v["gold_leader"]) == "you" else them)
		_text(f, Strings.f("arena2.board.gold", {"n": v["gold_text"]}), Vector2(cx, by - 14.0), UI.S_CAPTION, lead_col, HORIZONTAL_ALIGNMENT_CENTER, 200)

	func _text(f: Font, s: String, at: Vector2, fs: int, col: Color, align: int, w: float) -> void:
		var x := at.x
		if align == HORIZONTAL_ALIGNMENT_CENTER:
			x -= w / 2.0
		elif align == HORIZONTAL_ALIGNMENT_RIGHT:
			x -= w
		draw_string(f, Vector2(x, at.y), s, align, w, fs, col)

	func _hex(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 6:
			var a := TAU * float(i) / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, col)


class Feed extends Control:
	var max_lines := 2              # Match Day M2: one line under the commentary during the show (both at the end)
	var pl: ArenaPlayer
	var t := 0.0
	var mine := ""
	var theirs := ""
	var end_text := ""
	var decided := ""

	func _init(p: ArenaPlayer, p_mine: String, p_theirs: String) -> void:
		pl = p
		mine = p_mine
		theirs = p_theirs
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_at(p_t: float) -> void:
		t = p_t
		queue_redraw()

	func lines() -> Array:
		if end_text != "":
			return [{"text": end_text, "side": pl.winner}, {"text": decided, "side": ""}]
		return ArenaHud2.feed_lines(pl, t, mine, theirs)

	func _draw() -> void:
		var f := get_theme_default_font()
		var y := 30.0
		var i := 0
		for l in lines():
			if String(l["text"]) == "":
				continue
			var side := String(l["side"])
			var col := UI.TEXT if side == "" else (UI.ACCENT if side == pl.my_side else UI.CORAL)
			if i > 0 and end_text == "":
				col = Color(col, 0.6)
			if i >= max_lines and end_text == "":
				break
			draw_string(f, Vector2(0, y), String(l["text"]), HORIZONTAL_ALIGNMENT_LEFT, size.x, UI.S_SMALL if i == 0 else UI.S_CAPTION, col)
			y += 38.0
			i += 1


class Notes extends Control:
	## The commentary strip (Match Day M4, the Broadcast): the casters' line at the show time, wrapped to fit (3 lines, 2 in
	## large text, never under 26 px; a peak line at 32 px Bold), with the speaker's name and a mark by voice (a filled dot for
	## the play-by-play caster, a ring for the analyst: shape, not colour alone). Without a line: what your team is doing now.
	var pl: ArenaPlayer
	var t := 0.0
	var show_s := 0.0
	var speed := 1.0
	var cast: ArenaCast = null
	var intro: Dictionary = {}      # an intro line on screen before the show (the screen sets it), else {}
	var line_count := 0             # lines drawn last frame (tests)
	var cut_count := 0              # lines that did not fit and were cut (tests: must stay 0)
	var px := 0                     # type size used last frame (tests)

	func _init(p: ArenaPlayer) -> void:
		pl = p
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_at(p_t: float, p_show_s: float = -1.0, p_speed: float = 1.0) -> void:
		t = p_t
		show_s = p_show_s if p_show_s >= 0.0 else (pl.show_t(p_t) if pl != null else 0.0)
		speed = p_speed
		queue_redraw()

	## The Broadcast line on screen now, or {}.
	func line() -> Dictionary:
		if not intro.is_empty():
			return intro
		return cast.line_at(show_s, speed) if cast != null else {}

	func comment() -> String:
		return String(line().get("text", ""))

	func text() -> String:
		var c := comment()
		return c if c != "" else ArenaHud2.notes_line(pl, t)

	func max_lines() -> int:
		return 3

	func _draw() -> void:
		line_count = 0
		var l := line()
		if l.is_empty():
			var s0 := ArenaHud2.notes_line(pl, t)
			if s0 == "":
				return
			var f0 := get_theme_default_font()
			draw_circle(Vector2(10, 24), 7.0, UI.ACCENT)
			draw_string(f0, Vector2(26, 33), s0, HORIZONTAL_ALIGNMENT_LEFT, size.x - 26, UI.S_SMALL, UI.TEAL_HI)
			line_count = 1
			px = UI.S_SMALL
			return
		var peak := String(l["tier"]) == "peak"
		var f := UI.font("Bold") if peak else get_theme_default_font()
		px = 32 if peak else 26      # 26 px in both text sizes: three lines fit the strip (Match Day M2)
		var who := Strings.t("arena.cast.name." + String(l["voice"]))
		var full := "%s: %s" % [who, String(l["text"])]
		var rows := PlanKit.wrap(f, px, full, size.x - 26.0, max_lines())
		if PlanKit.was_cut(rows, full):
			cut_count += 1
		var lh := PlanKit.line_h(f, px)
		var y := 4.0
		if String(l["voice"]) == "p":
			draw_circle(Vector2(10, y + lh * 0.5), 7.0, UI.WARN)
		else:
			draw_arc(Vector2(10, y + lh * 0.5), 6.0, 0.0, TAU, 16, UI.WARN, 2.5)
		for r in rows:
			draw_string(f, Vector2(26, y + lh * 0.78), String(r), HORIZONTAL_ALIGNMENT_LEFT, size.x - 26, px, UI.TEXT)
			y += lh
		line_count = rows.size()
		if not intro.is_empty():
			var hint := Strings.t("match.intro.skip")
			var hf := get_theme_default_font()
			var hw := hf.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.S_CAPTION).x
			draw_style_box(UI.box(Color(UI.BG, 0.85), 14), Rect2(size.x - hw - 20.0, -42.0, hw + 20.0, 36.0))
			draw_string(hf, Vector2(size.x - hw - 10.0, -16.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.S_CAPTION, UI.TEXT2)
		return
