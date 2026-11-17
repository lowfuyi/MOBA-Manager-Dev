class_name HomeKit
extends RefCounted
## The drawn pieces of Home (UI-PASS-2 6.1, build plan I-15). Each is ONE Control that queues its drawing in a CardKit.Ops
## display list and flushes it in passes (atlas shapes, icons, text by font and size), so a piece costs a few draw calls
## however much it shows:
##   Hero          the club header: page gradient with a 10 percent club wash, VOID skyline, the badge, the club name (48, steps
##                 down to 40 and 36 before it is cut), the season line, rank and record, and five form pips (W or L in a disc: a
##                 letter, never colour alone). The top-right 120 x 120 stays clear for the "?" button (ART-BIBLE 3.7 rule 8).
##   AttentionCard one "needs you" item: PANEL card, 6 px WARN rail, warning icon, Body 32 label, chevron (ART-BIBLE 3.7 rule 9).
##                 Display only: the Carousel that holds it owns the tap.
##   UpNextCard    one coming game: round, opponent badge and name, side (word plus flag), and Favoured / Even / Underdog (word
##                 plus arrow). Display only (Carousel).
##   StatTile      a tile of the 2 x 2 grid: caption, a 32 px icon at the top right, the value (40, steps down), a line with an
##                 optional arrow. A flat Button (the whole tile taps; a drag that starts on it scrolls the page).
##   BadgeView     a club badge at any size (2 draw calls when the badge atlas is prepared).
## Nothing here reads or writes game state; the screen passes the values in. Every text comes from Strings.

const SKY_CLEAR := 120.0    # the top-right corner kept clear for the "?" button


static func large() -> bool:
	return UI.large    # the live state (App.apply_large_text sets it); App.large_text() is only the saved setting


# ------------------------------------------------------------------------------------------------------------------ Hero
class Hero extends Control:
	var club_id := ""
	var club_name := ""
	var season_line := ""
	var rank_line := ""
	var pips: Array = []            # newest first: "w", "l"; padded with "" up to five
	var wash := Color(0, 0, 0, 0)   # the club primary (10 percent of it is mixed into the gradient)
	var name_size := 0              # the size the club name was drawn at (tests)
	var draw_count := 0
	var _ops := CardKit.Ops.new()

	func _init(p_club_id: String = "", p_club_name: String = "", p_season: String = "", p_rank: String = "", p_pips: Array = []) -> void:
		club_id = p_club_id
		club_name = p_club_name
		season_line = p_season
		rank_line = p_rank
		pips = p_pips.duplicate()
		while pips.size() < 5:
			pips.append("")
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, height())
		var st: Dictionary = BadgeStyle.for_club(club_id) if club_id != "" else {}
		if st.has("primary"):
			wash = st["primary"]

	static func height() -> float:
		return 220.0 if HomeKit.large() else 248.0

	static func badge_px() -> float:
		return 88.0 if HomeKit.large() else 112.0

	## The rows' vertical centres: name, season line, rank row (all above the Next card, which overlaps the last 64 px).
	func rows() -> Array:
		return [50.0, 92.0, 132.0] if HomeKit.large() else [56.0, 104.0, 148.0]

	func badge_rect() -> Rect2:
		var b := badge_px()
		return Rect2(Vector2(20.0, 24.0), Vector2(b, b))

	func text_x() -> float:
		return badge_rect().end.x + 20.0

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		var s := size
		# 1. the gradient with the wash folded in: one polygon with vertex colours (one draw call)
		var top := UI.BG_GLOW.lerp(wash, 0.10) if wash.a > 0.0 else UI.BG_GLOW
		var bot := UI.BG.lerp(wash, 0.10) if wash.a > 0.0 else UI.BG
		var pts := HomeKit.round_rect(Rect2(Vector2.ZERO, s), float(UI.R_CARD))
		var cols := PackedColorArray()
		var uvs := PackedVector2Array()
		var tex: Texture2D = CardKit.atlas()["tex"] if CardKit.ok() else null
		var uv := Vector2.ZERO
		if tex != null:    # sample the white middle of the atlas's "solid" cell, so this polygon batches with the atlas shapes after it
			var reg := CardKit.region("solid")
			uv = reg.get_center() / Vector2(tex.get_size())
		for p in pts:
			cols.append(top.lerp(bot, clampf(p.y / maxf(1.0, s.y), 0.0, 1.0)))
			uvs.append(uv)
		draw_polygon(pts, cols, uvs if tex != null else PackedVector2Array(), tex)
		_ops.clear()
		# 2. the skyline: VOID towers along the bottom right, never in the top-right 120 x 120
		var x := s.x * 0.46
		var i := 0
		var hs := [70.0, 104.0, 54.0, 88.0, 112.0, 62.0, 96.0, 46.0, 80.0]
		var ws := [34.0, 26.0, 40.0, 22.0, 30.0, 44.0, 24.0, 36.0, 28.0]
		while x < s.x - 18.0:
			var w: float = ws[i % ws.size()]
			var h: float = minf(hs[i % hs.size()], s.y - HomeKit.SKY_CLEAR - 8.0)
			w = minf(w, s.x - 18.0 - x)
			_ops.shape("solid", Rect2(x, s.y - h, w, h), Color(UI.VOID, 0.55 + 0.05 * float(i % 3)))
			x += w + 6.0
			i += 1
		# 3. the pips (discs) on the rank row
		var r: Array = rows()
		var f_body := UI.font("SemiBold", true)
		var rank_w := CardKit.text_w(f_body, UI.S_BODY, rank_line)
		var d := 32.0 if HomeKit.large() else 36.0
		var px := text_x() + rank_w + 20.0
		var room_end := s.x - 16.0
		d = clampf((room_end - px) / 5.0 - 6.0, 26.0, d)    # all five pips fit: they shrink (to 26) before one is dropped
		for k in pips.size():
			var pr := Rect2(px + float(k) * (d + 6.0), float(r[2]) - d * 0.5, d, d)
			if pr.end.x > room_end:
				break
			var p := String(pips[k])
			_ops.shape("disc", pr, UI.GOOD if p == "w" else (UI.BAD if p == "l" else UI.PANEL3))
			if p != "":
				_ops.text(UI.font("Medium"), UI.S_SMALL, Strings.t("home.pip." + p), pr.position.x, pr.get_center().y, pr.size.x, UI.INK_TEAL, 1)    # one run with the season line
		# 4. texts: the name steps down 48, 40, 36 before it is cut; the name row stops short of the "?" corner
		var tx := text_x()
		var name_room := s.x - tx - HomeKit.SKY_CLEAR
		var fn := UI.font("SemiBold")
		name_size = UI.S_TITLE
		for sz in [UI.S_TITLE, UI.S_BIG, UI.S_HEAD]:
			name_size = sz
			if CardKit.text_w(fn, sz, club_name) <= name_room:
				break
		_ops.text(fn, name_size, club_name, tx, r[0], name_room, UI.TEXT)
		_ops.text(UI.font("Medium"), UI.S_SMALL, season_line, tx, r[1], s.x - tx - 16.0, UI.TEXT2)
		_ops.text(f_body, UI.S_BODY, rank_line, tx, r[2], rank_w + 1.0, UI.TEXT)
		_ops.flush(self)
		# 5. the badge (its own atlas: 2 calls)
		Badge.draw(self, club_id, club_name, badge_rect(), UI.font("Bold"))

	func clipped() -> Array:
		return _ops.clipped


## A rounded rectangle as a polygon (for draw_polygon with vertex colours).
static func round_rect(r: Rect2, rad: float, seg: int = 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
			Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var start := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for k in 4:
		for j in seg + 1:
			var a: float = float(start[k]) + PI * 0.5 * float(j) / float(seg)
			out.append((c[k] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	return out


# ------------------------------------------------------------------------------------------------------- AttentionCard
class AttentionCard extends Control:
	const H := 96.0
	var text := ""
	var draw_count := 0
	var _ops := CardKit.Ops.new()

	## The room the label has in a card `w` wide (rail, padding, icon and gap on the left; chevron and padding on the right).
	static func room_for(w: float) -> float:
		return w - 62.0 - 48.0

	func _init(p_text: String = "") -> void:
		text = p_text
		custom_minimum_size = Vector2(0, H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		CompKit.set_cue(self, "warning icon")

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		var s := size
		_ops.clear()
		_ops.bg("card", Rect2(Vector2.ZERO, s), UI.PANEL)
		_ops.shape("solid", Rect2(0.0, 14.0, 6.0, s.y - 28.0), UI.WARN)
		_ops.icon("warn", Rect2(22.0, s.y * 0.5 - 16.0, 32.0, 32.0), UI.WARN)
		_ops.icon("chevron_right", Rect2(s.x - 40.0, s.y * 0.5 - 12.0, 24.0, 24.0), UI.TEXT2)
		_ops.text(UI.font("Regular"), UI.S_BODY, text, 62.0, s.y * 0.5, AttentionCard.room_for(s.x), UI.TEXT)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped


# ---------------------------------------------------------------------------------------------------------- UpNextCard
class UpNextCard extends Control:
	const H := 200.0
	var item: Dictionary = {}       # GameState.upcoming() row
	var opp_name := ""
	var draw_count := 0
	var _ops := CardKit.Ops.new()

	func _init(p_item: Dictionary = {}, p_opp_name: String = "") -> void:
		item = p_item
		opp_name = p_opp_name
		custom_minimum_size = Vector2(0, H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		CompKit.set_cue(self, "word and arrow")

	func word_key() -> String:
		return {"favoured": "home.fav", "underdog": "home.underdog"}.get(String(item.get("word", "even")), "home.even")

	var name_size := 0              # the size the opponent's name was drawn at (tests)

	## Layout (200 high): the badge (56) with the round and the side beside it, then the name across the whole card (32, stepping
	## down to 26 and 24 before it is ever cut), then Favoured / Even / Underdog as a word with an arrow.
	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		var s := size
		_ops.clear()
		_ops.bg("card", Rect2(Vector2.ZERO, s), UI.PANEL)
		var pad := 20.0
		var b := 56.0
		var w := String(item.get("word", "even"))
		var wc: Color = UI.GOOD if w == "favoured" else (UI.BAD if w == "underdog" else UI.TEXT2)
		var arrow := "arrow_up" if w == "favoured" else ("arrow_down" if w == "underdog" else "arrow_flat")
		var blue := String(item.get("side", "B")) == "B"
		var tx := pad + b + 14.0
		_ops.text(UI.font("Regular"), UI.S_CAPTION, Strings.f("home.round", {"round": int(item.get("round", 0)) + 1}), tx, pad + 14.0, s.x - tx - pad, UI.DIM)
		_ops.icon("flag_blue" if blue else "flag_red", Rect2(tx, pad + 32.0, 24.0, 24.0), UI.SIDE_BLUE if blue else UI.SIDE_RED)
		_ops.text(UI.font("Regular"), UI.S_CAPTION, Strings.t("hub.side.blue" if blue else "hub.side.red"), tx + 30.0, pad + 44.0, s.x - tx - pad - 30.0, UI.TEXT2)
		var fn := UI.font("SemiBold")
		var room := s.x - pad * 2.0
		name_size = UI.S_BODY
		for sz in [UI.S_BODY, UI.S_SMALL, UI.S_CAPTION]:
			name_size = sz
			if CardKit.text_w(fn, sz, opp_name) <= room:
				break
		_ops.text(fn, name_size, opp_name, pad, 116.0, room, UI.TEXT)
		_ops.icon(arrow, Rect2(pad, 152.0, 24.0, 24.0), wc)
		_ops.text(UI.font("Regular"), UI.S_CAPTION, Strings.t(word_key()), pad + 30.0, 164.0, room - 30.0, wc)    # one font run with the round and side
		# the badge: its shape now (above the card, below the texts) and its initial in the name's own font and size, so the
		# initial and the name are one text run (one draw call less per card; I-15 perf)
		var br := Rect2(Vector2(pad, pad), Vector2(b, b))
		var opp := String(item.get("opp", ""))
		var st := BadgeStyle.for_club(opp)
		var lb := Badge.letter_box(String(st.get("shape_name", "roundel")))
		var k := b / Badge.BOX
		_ops.text(fn, name_size, Badge._initial(opp_name, opp), br.position.x + lb.position.x * k, br.position.y + lb.get_center().y * k, lb.size.x * k, st.get("ink", UI.VOID), 1)
		var bgs := _ops.bgs.duplicate()
		_ops.bgs.clear()
		for g in bgs:
			CardKit.bg(self, g[0], g[1], g[2])
		Badge.draw_shapes(self, opp, br)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped


# ------------------------------------------------------------------------------------------------------------ StatTile
class StatTile extends Button:
	const H := 168.0
	var caption := ""
	var value := ""
	var sub := ""
	var icon_id := ""
	var value_color := UI.TEXT
	var arrow := ""                 # "" or arrow_up / arrow_down / arrow_flat before the sub line
	var arrow_color := UI.TEXT2
	var value_size := 0
	var draw_count := 0

	func _init(p_caption: String = "", p_value: String = "", p_sub: String = "", p_icon: String = "", p_cb: Callable = Callable()) -> void:
		caption = p_caption
		value = p_value
		sub = p_sub
		icon_id = p_icon
		custom_minimum_size = Vector2(0, H)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS    # a swipe that starts on a tile scrolls the page
		CompKit.hollow(self)
		button_down.connect(_toggled_look)
		button_up.connect(_toggled_look)
		if p_cb.is_valid():
			pressed.connect(p_cb)

	func set_arrow(id: String, col: Color) -> StatTile:
		arrow = id
		arrow_color = col
		if id != "":
			CompKit.set_cue(self, id)
		return self

	func set_value_color(c: Color) -> StatTile:
		value_color = c
		return self

	## Queue this tile's drawing into `ops` at `r` (TileGrid draws all its tiles in one pass; the button itself draws nothing).
	func queue_into(ops: CardKit.Ops, r: Rect2) -> void:
		draw_count += 1
		var pad := 20.0
		var o := r.position
		var w := r.size.x
		ops.bg("card", r, UI.PANEL.darkened(0.12) if is_pressed() else UI.PANEL)
		if icon_id != "":
			ops.icon(icon_id, Rect2(o.x + w - pad - 32.0, o.y + pad, 32.0, 32.0), UI.TEAL_HI)
		ops.text(UI.font("Regular"), UI.S_CAPTION, caption.to_upper(), o.x + pad, o.y + pad + 16.0, w - pad * 2.0 - 40.0, UI.DIM)    # one run with the sub lines
		var fv := UI.font("SemiBold", true)
		var room := w - pad * 2.0
		value_size = UI.S_BIG
		for sz in [UI.S_BIG, UI.S_HEAD, UI.S_BODY]:
			value_size = sz
			if CardKit.text_w(fv, sz, value) <= room:
				break
		ops.text(fv, value_size, value, o.x + pad, o.y + 88.0, room, value_color)
		var sx := pad
		if arrow != "":
			ops.icon(arrow, Rect2(o.x + pad, o.y + 126.0, 24.0, 24.0), arrow_color)
			sx += 30.0
		ops.text(UI.font("Regular"), UI.S_CAPTION, sub, o.x + sx, o.y + 138.0, w - sx - pad, UI.TEXT2)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAW and get_parent() is TileGrid:
			return    # drawn by the grid
		if (what == NOTIFICATION_RESIZED or what == NOTIFICATION_MOVED_IN_PARENT) and get_parent() is TileGrid:
			(get_parent() as TileGrid).queue_redraw()

	func _toggled_look() -> void:
		if get_parent() is TileGrid:
			(get_parent() as TileGrid).queue_redraw()



# ----------------------------------------------------------------------------------------------------------- BadgeView
class BadgeView extends Control:
	var club_id := ""
	var club_name := ""

	func _init(p_club_id: String = "", p_club_name: String = "", px: float = 96.0) -> void:
		club_id = p_club_id
		club_name = p_club_name
		custom_minimum_size = Vector2(px, px)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		ArtWire.ensure()
		var b := minf(size.x, size.y)
		Badge.draw(self, club_id, club_name, Rect2(Vector2((size.x - b) * 0.5, 0.0), Vector2(b, b)), UI.font("Bold"))


## Up to two lines of `text` in `room` px (greedy by words); a second line that still does not fit is cut with "...".
static func wrap2(font: Font, size: int, text: String, room: float) -> Array:
	if CardKit.text_w(font, size, text) <= room:
		return [text]
	var words := text.split(" ", false)
	var first := ""
	var i := 0
	while i < words.size():
		var cand := words[i] if first == "" else first + " " + words[i]
		if first != "" and CardKit.text_w(font, size, cand) > room:
			break
		first = cand
		i += 1
	var rest := " ".join(words.slice(i))
	return [first] if rest == "" else [first, rest]


# -------------------------------------------------------------------------------------------------------- VersusPanel
## The middle of the Next card in one control: both badges (shapes in one run, letters in one run), both names (up to two lines,
## centred under the badge), "VS", the two ratings and the teal / coral bar. You on the left, them on the right, always.
class VersusPanel extends Control:
	var me_id := ""
	var me_name := ""
	var opp_id := ""
	var opp_name := ""
	var mine := 0.0
	var theirs := 0.0
	var draw_count := 0
	var _ops := CardKit.Ops.new()
	var _lines: Array = [[], []]

	func _init(p_me: String = "", p_me_name: String = "", p_opp: String = "", p_opp_name: String = "", p_mine: float = 0.0, p_theirs: float = 0.0) -> void:
		me_id = p_me
		me_name = p_me_name
		opp_id = p_opp
		opp_name = p_opp_name
		mine = p_mine
		theirs = p_theirs
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, _height(2))
		resized.connect(_relayout)
		CompKit.set_cue(self, "you left, them right")

	static func badge_px() -> float:
		return 80.0 if HomeKit.large() else 96.0

	func _col_w() -> float:
		return maxf(120.0, size.x * 0.40)

	static func _height(lines: int) -> float:
		return badge_px() + 10.0 + 40.0 * float(lines) + 18.0 + 40.0 + 12.0 + 18.0

	func _relayout() -> void:
		var f := UI.font("SemiBold")
		_lines = [HomeKit.wrap2(f, UI.S_BODY, me_name, _col_w()), HomeKit.wrap2(f, UI.S_BODY, opp_name, _col_w())]
		var n := maxi((_lines[0] as Array).size(), (_lines[1] as Array).size())
		var h := _height(n)
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size = Vector2(0, h)
		queue_redraw()

	func name_lines(side: int) -> Array:
		return _lines[side]

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		var s := size
		var b := badge_px()
		var cw := _col_w()
		var left_c := cw * 0.5
		var right_c := s.x - cw * 0.5
		var rects := [Rect2(Vector2(left_c - b * 0.5, 0.0), Vector2(b, b)), Rect2(Vector2(right_c - b * 0.5, 0.0), Vector2(b, b))]
		_ops.clear()
		var fn := UI.font("SemiBold")
		var nlines := maxi((_lines[0] as Array).size(), (_lines[1] as Array).size())
		for side in 2:
			var lines: Array = _lines[side]
			for k in lines.size():
				_ops.text(fn, UI.S_BODY, String(lines[k]), (left_c if side == 0 else right_c) - cw * 0.5, b + 10.0 + 20.0 + 40.0 * float(k), cw, UI.TEXT, 1)
		_ops.text(UI.font("Bold"), UI.S_HEAD, Strings.t("home.vs"), s.x * 0.5 - 40.0, b * 0.5, 80.0, UI.DIM, 1)
		var ry := b + 10.0 + 40.0 * float(nlines) + 18.0 + 20.0
		var fr := UI.font("Regular", true)
		_ops.text(fr, UI.S_BODY, Strings.f("hub.rating_you", {"v": "%.1f" % mine}), 0.0, ry, s.x * 0.5, UI.ACCENT)
		_ops.text(fr, UI.S_BODY, Strings.f("hub.rating_them", {"v": "%.1f" % theirs}), s.x * 0.5, ry, s.x * 0.5, UI.CORAL_HI, 2)
		# the bar: two rounded bars from the atlas (a solid middle and two disc ends each), 4 px apart
		var by := ry + 20.0 + 12.0
		var tot := maxf(0.001, mine + theirs)
		var wl := maxf(24.0, (s.x - 4.0) * clampf(mine / tot, 0.05, 0.95))
		_bar(Rect2(0.0, by, wl, 18.0), UI.ACCENT)
		_bar(Rect2(wl + 4.0, by, s.x - wl - 4.0, 18.0), UI.CORAL)
		_ops.flush(self)
		Badge.draw_shapes(self, me_id, rects[0])    # both badges' shapes in one atlas run, then both letters in one font run
		Badge.draw_shapes(self, opp_id, rects[1])
		Badge.draw_letter(self, me_id, me_name, rects[0], UI.font("Bold"))
		Badge.draw_letter(self, opp_id, opp_name, rects[1], UI.font("Bold"))

	func _bar(r: Rect2, c: Color) -> void:
		var h := r.size.y
		_ops.shape("disc", Rect2(r.position, Vector2(h, h)), c)
		_ops.shape("disc", Rect2(Vector2(r.end.x - h, r.position.y), Vector2(h, h)), c)
		_ops.shape("solid", Rect2(r.position.x + h * 0.5, r.position.y, maxf(0.0, r.size.x - h), h), c)

	func clipped() -> Array:
		return _ops.clipped


# ------------------------------------------------------------------------------------------------------------ ChipRow
## A row of chips (Chip's look: 44 high, a 16 percent tint with a 45 percent hairline, an icon, SemiBold 24) drawn as one control,
## wrapping to more lines when narrow. items: [[text, variant ("neutral"|"accent"|"warn"|"good"|"bad"), icon id or ""], ...].
class ChipRow extends Control:
	const H := 44.0
	const GAP := 8.0
	var items: Array = []
	var draw_count := 0
	var _ops := CardKit.Ops.new()
	var _rects: Array = []

	func _init(p_items: Array = []) -> void:
		items = p_items.duplicate(true)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, H)
		resized.connect(_relayout)
		var cues: Array = []
		for it in items:
			cues.append(_icon_of(it))
		CompKit.set_cue(self, ",".join(PackedStringArray(cues)))

	## Change the chips in place (an equal list changes nothing).
	func set_items(p_items: Array) -> void:
		if p_items == items:
			return
		items = p_items.duplicate(true)
		var cues: Array = []
		for it in items:
			cues.append(_icon_of(it))
		CompKit.set_cue(self, ",".join(PackedStringArray(cues)))
		_relayout()

	static func _icon_of(it: Array) -> String:
		return String(it[2]) if String(it[2]) != "" else String(Chip.ICONS.get(String(it[1]), "dot"))

	static func colour(variant: String) -> Color:
		match variant:
			"good":
				return UI.GOOD
			"bad":
				return UI.BAD
			"warn":
				return UI.WARN
			"accent":
				return UI.ACCENT
		return UI.DIM

	func chip_w(it: Array) -> float:
		return Chip.PAD * 2.0 + Chip.ICON + Chip.GAP + CardKit.text_w(UI.font("SemiBold"), Chip.SIZE_TEXT, String(it[0]))

	func _relayout() -> void:
		_rects.clear()
		var x := 0.0
		var y := 0.0
		for it in items:
			var w := minf(chip_w(it), size.x)
			if x > 0.0 and x + w > size.x:
				x = 0.0
				y += H + GAP
			_rects.append(Rect2(x, y, w, H))
			x += w + GAP
		var h := y + H
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size = Vector2(0, h)
		queue_redraw()

	func chip_rects() -> Array:
		return _rects

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		for i in mini(items.size(), _rects.size()):
			var it: Array = items[i]
			var r: Rect2 = _rects[i]
			var c := colour(String(it[1]))
			var tc := c.lerp(Color.WHITE, 0.25)
			_ops.bg("pill", r, Color(c.r, c.g, c.b, 0.16))
			_ops.bg("pillring", r, Color(c.r, c.g, c.b, 0.45))
			_ops.icon(_icon_of(it), Rect2(r.position.x + Chip.PAD, r.position.y + (H - Chip.ICON) * 0.5, Chip.ICON, Chip.ICON), tc)
			var tx := r.position.x + Chip.PAD + Chip.ICON + Chip.GAP
			_ops.text(UI.font("SemiBold"), Chip.SIZE_TEXT, String(it[0]), tx, r.get_center().y, r.end.x - tx - Chip.PAD + 1.0, tc)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped


# ------------------------------------------------------------------------------------------------------------ CardHead
## The Next card's first line in one control: the title (Caption, SemiBold, coral-light) on the left and the side chip (a flag icon
## plus "Blue side" / "Red side": the side is never colour alone) on the right; the title wraps to a second line when narrow.
class CardHead extends Control:
	var title := ""
	var side_text := ""
	var flag := ""
	var draw_count := 0
	var _ops := CardKit.Ops.new()
	var _lines: Array = []

	func _init(p_title: String = "", p_side: String = "", p_flag: String = "") -> void:
		title = p_title
		side_text = p_side
		flag = p_flag
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, ChipRow.H)
		resized.connect(_relayout)
		CompKit.set_cue(self, flag)

	func chip_w() -> float:
		return Chip.PAD * 2.0 + Chip.ICON + Chip.GAP + CardKit.text_w(UI.font("SemiBold"), Chip.SIZE_TEXT, side_text)

	func _relayout() -> void:
		_lines = HomeKit.wrap2(UI.font("SemiBold"), UI.S_CAPTION, title, maxf(80.0, size.x - chip_w() - 16.0))
		var h := maxf(ChipRow.H, 32.0 * float(_lines.size()) + 8.0)
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size = Vector2(0, h)
		queue_redraw()

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var cw := chip_w()
		var r := Rect2(size.x - cw, 0.0, cw, ChipRow.H)
		var c := UI.DIM
		var tc := c.lerp(Color.WHITE, 0.25)
		_ops.bg("pill", r, Color(c.r, c.g, c.b, 0.16))
		_ops.bg("pillring", r, Color(c.r, c.g, c.b, 0.45))
		_ops.icon(flag, Rect2(r.position.x + Chip.PAD, (ChipRow.H - Chip.ICON) * 0.5, Chip.ICON, Chip.ICON), tc)
		var tx := r.position.x + Chip.PAD + Chip.ICON + Chip.GAP
		_ops.text(UI.font("SemiBold"), Chip.SIZE_TEXT, side_text, tx, ChipRow.H * 0.5, r.end.x - tx - Chip.PAD + 1.0, tc)
		var room := size.x - cw - 16.0
		for k in _lines.size():
			_ops.text(UI.font("SemiBold"), UI.S_CAPTION, String(_lines[k]), 0.0, 20.0 + 32.0 * float(k), room, UI.CORAL_HI)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped


# ------------------------------------------------------------------------------------------------------------ TileGrid
## The 2 x 2 tiles of Home as ONE drawing: the grid lays out its StatTile children (hit areas that draw nothing, each tagged for the
## tutorial) and draws every tile in one display list, so four tiles cost about four draw calls, not sixteen (the HeroGrid idea,
## SPIKE-RESULTS-0.7 S4). Columns come from the width (UI-PASS-2 2.3 rule 2): floor((w + gap) / (min cell + gap)).
class TileGrid extends GridContainer:
	const MIN_CELL := 260.0
	var draw_count := 0
	var _ops := CardKit.Ops.new()

	func _init() -> void:
		columns = 2
		add_theme_constant_override("h_separation", UI.GAP)
		add_theme_constant_override("v_separation", UI.GAP)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS
		resized.connect(_on_resized)
		sort_children.connect(queue_redraw)

	func _on_resized() -> void:
		var n := maxi(1, int(floor((size.x + float(UI.GAP)) / (MIN_CELL + float(UI.GAP)))))
		if n != columns:
			columns = n
		queue_redraw()

	func tiles() -> Array:
		return get_children().filter(func(c: Node) -> bool: return c is StatTile)

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		for t in tiles():
			var st := t as StatTile
			if st.visible:
				st.queue_into(_ops, Rect2(st.position, st.size))
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped
