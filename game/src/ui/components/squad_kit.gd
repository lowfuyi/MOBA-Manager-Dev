class_name SquadKit
extends RefCounted
## Drawn pieces of the Squad (build plan I-19, UI-PASS-2 6.2, ART-BIBLE 6.4):
##   LaneMap   the player's half of Wrenfell as an inset card (672 x 440; 578 x 380 in large text), drawn in code from the cards atlas
##             (land pockets, lanes, the Mere and its island, the plaza) and the five starters as 96 px PlayerCard tokens at the
##             ART-BIBLE 6.4 anchors. The map draws its tokens in its own display list (PlayerCard.draw_children): a few draw calls.
##   CardGrid  a GridContainer that draws its PlayerCard children in one pass (the bench)
##   CardRows  a VBoxContainer that does the same (the lane picker rows)
##   Pills     the team strip: four stat pills (rating, chemistry, squad, wages) in one Control; the chemistry pill is tappable
##   Status    three centre-zero bars (tiredness, form, morale) with signed numbers and words, one Control (the player sheet)
## Nothing here reads or writes the save; the screen passes the numbers in.

## The anchors in arena units (ART-BIBLE 6.4 table). Card px = x * W, (y - 0.38) * 709.3 * W / 672.
const ANCHORS := {"top": Vector2(0.110, 0.540), "jg": Vector2(0.270, 0.700), "mid": Vector2(0.500, 0.720), "sup": Vector2(0.840, 0.742), "bot": Vector2(0.889, 0.540)}
const TOKEN := 96.0


class LaneMap extends Control:
	var tokens: Dictionary = {}       # slot -> PlayerCard (token variant)
	var draw_count := 0

	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS
		clip_contents = true    # the card's top edge cuts the Mere, on purpose (ART-BIBLE 6.4)
		resized.connect(_place)
		_fit_height()
		CompKit.set_cue(self, "map+tokens")

	func draws_cards() -> bool:
		return true

	func _w() -> float:
		return size.x if size.x > 0.0 else UI.canvas_w() - 48.0

	func _fit_height() -> void:
		var h := 380.0 if UI.large else 440.0
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size = Vector2(0, h)

	## Card px of an arena point (ART-BIBLE 6.4 mapping, scaled to the card's width).
	func at(p: Vector2) -> Vector2:
		var w := _w()
		return Vector2(p.x * w, (p.y - 0.38) * 709.3 * w / 672.0)

	func anchor(slot: String) -> Vector2:
		return at(ANCHORS[slot])

	func set_token(slot: String, card: PlayerCard) -> void:
		if tokens.has(slot) and is_instance_valid(tokens[slot]) and tokens[slot] != card:
			(tokens[slot] as Node).queue_free()
		tokens[slot] = card
		if card.get_parent() != self:
			add_child(card)
		_place()

	func _place() -> void:
		_fit_height()
		var w := _w()
		var h := size.y if size.y > 0.0 else custom_minimum_size.y
		for slot in tokens:
			var c := tokens[slot] as PlayerCard
			var a := anchor(slot)
			c.position = a - Vector2(TOKEN, TOKEN) * 0.5
			c.size = Vector2(TOKEN, TOKEN)
			c.set_opt("name_side", "above" if slot in ["top", "bot"] else "below")
			c.set_opt("label_clamp", Rect2(-c.position + Vector2(8, 8), Vector2(w - 16.0, h - 16.0)))
		queue_redraw()

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		var w := _w()
		var h := size.y
		var o := CardKit.Ops.new()
		o.bg("card", Rect2(Vector2.ZERO, size), UI.VOID)
		var land := Color(UI.MAP_LAND.r, UI.MAP_LAND.g, UI.MAP_LAND.b, 0.85)
		for c in [Vector2(0.22, 0.66), Vector2(0.78, 0.66)]:
			var pc := at(c)
			var rx := 0.13 * w
			var ry := 0.17 * 709.3 * w / 672.0
			o.shape("disc", Rect2(pc - Vector2(rx, ry), Vector2(rx, ry) * 2.0), land)
		# the three lanes (schematic: Top and Bot run down their arcs to the plaza row, Mid down the causeway)
		var lane := UI.PANEL3
		var line := Color(1, 1, 1, 0.12)
		var base_y := at(Vector2(0.0, 0.93)).y
		var lw := 40.0 * w / 720.0
		var mw := 56.0 * w / 720.0
		for x in [0.110, 0.889]:
			var px: float = float(x) * w
			o.shape("solid", Rect2(px - lw * 0.5, 0.0, lw, base_y), lane)
			var x0: float = minf(px, 0.5 * w)
			o.shape("solid", Rect2(x0, base_y - lw * 0.5, absf(0.5 * w - px), lw), lane)
			o.shape("disc", Rect2(px - lw * 0.5, base_y - lw * 0.5, lw, lw), lane)
		o.shape("solid", Rect2(0.5 * w - mw * 0.5, 0.0, mw, base_y), lane)
		for x in [0.110, 0.889]:
			o.shape("solid", Rect2(x * w - 1.0, 0.0, 2.0, base_y), line)
		o.shape("solid", Rect2(0.5 * w - 1.0, 0.0, 2.0, base_y), line)
		# the Mere (its lower half: the card cuts it on purpose) and the island
		var mc := at(Vector2(0.5, 0.5))
		var mr := 128.0 * w / 720.0
		o.shape("disc", Rect2(mc - Vector2(mr + 3.0, mr + 3.0), Vector2(mr + 3.0, mr + 3.0) * 2.0), UI.MAP_SHORE)
		o.shape("disc", Rect2(mc - Vector2(mr, mr), Vector2(mr, mr) * 2.0), UI.MAP_MERE)
		var ir := 38.0 * w / 720.0
		o.shape("disc", Rect2(mc - Vector2(ir, ir), Vector2(ir, ir) * 2.0), UI.PANEL2)
		# the plaza (your base, always at the bottom)
		var pz := Vector2(0.5 * w, base_y)
		var pw := 196.0 * w / 720.0 * 0.5
		var ph := 80.0 * w / 720.0 * 0.5
		o.shape("disc", Rect2(pz - Vector2(pw + 2.0, ph + 2.0), Vector2(pw + 2.0, ph + 2.0) * 2.0), Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.45))
		o.shape("disc", Rect2(pz - Vector2(pw, ph), Vector2(pw, ph) * 2.0), UI.PANEL2)
		if h <= 0.0:
			return
		PlayerCard.draw_children(self, o)


class CardGrid extends GridContainer:
	var draw_count := 0

	func _init(cols: int = 2) -> void:
		columns = cols
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_constant_override("h_separation", 12)
		add_theme_constant_override("v_separation", 12)
		sort_children.connect(queue_redraw)

	func draws_cards() -> bool:
		return true

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		PlayerCard.draw_children(self, null, true)


class CardRows extends VBoxContainer:
	var draw_count := 0

	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_constant_override("separation", 8)
		sort_children.connect(queue_redraw)

	func draws_cards() -> bool:
		return true

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		PlayerCard.draw_children(self, null, true)


## The team strip: [[label, value, tappable], ...] as pills, four in a row (2 x 2 in large text). A tap on a tappable pill calls
## `on_tap(index)` (S1 rule).
class Pills extends Control:
	const H := 96.0
	const GAP := 8.0
	var items: Array = []
	var on_tap: Callable
	var draw_count := 0
	var _ops := CardKit.Ops.new()
	var _tr := TouchTrack.new()
	var _press := -1
	var _press_g := Vector2.ZERO

	func _init(p_items: Array, p_on_tap: Callable) -> void:
		items = p_items
		on_tap = p_on_tap
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS
		resized.connect(_relayout)
		_relayout()
		CompKit.set_cue(self, "words+numbers")

	func cols() -> int:
		return 2 if UI.large else 4

	func set_items(p_items: Array) -> void:
		if p_items == items:
			return
		items = p_items.duplicate(true)
		queue_redraw()

	func _relayout() -> void:
		var rows := ceili(float(items.size()) / float(cols()))
		var h := float(rows) * H + float(rows - 1) * GAP
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size = Vector2(0, h)
		queue_redraw()

	func pill_rect(i: int) -> Rect2:
		var c := cols()
		var w := (size.x - GAP * float(c - 1)) / float(c)
		return Rect2(float(i % c) * (w + GAP), float(i / c) * (H + GAP), w, H)

	func index_at(p: Vector2) -> int:
		for i in items.size():
			if pill_rect(i).has_point(p):
				return i
		return -1

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var sb := UI.font("SemiBold")
		for i in items.size():
			var it: Array = items[i]
			var r := pill_rect(i)
			var tap := bool(it[2])
			_ops.bg("card", r, UI.PANEL3 if i == _press else UI.PANEL2)
			if tap:
				_ops.bg("ring", r, Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.5))
				_ops.icon("chevron_r", Rect2(r.end.x - 30.0, r.position.y + 34.0, 24.0, 24.0), UI.TEAL_HI)
			var room := r.size.x - 24.0 - (26.0 if tap else 0.0)
			_ops.text(sb, UI.S_CAPTION, String(it[0]), r.position.x + 12.0, r.position.y + 28.0, room, UI.DIM)
			_ops.text(UI.font("Bold", true), UI.S_BODY, String(it[1]), r.position.x + 12.0, r.position.y + 66.0, room, UI.TEXT)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped

	func _gui_input(event: InputEvent) -> void:
		match _tr.feed(event):
			"down":
				_press = index_at(_tr.press_pos)
				if _press >= 0 and not bool(items[_press][2]):
					_press = -1
				_press_g = get_global_transform_with_canvas() * _tr.press_pos
				queue_redraw()
			"up":
				var i := _press
				_press = -1
				queue_redraw()
				var g := get_global_transform_with_canvas() * _tr.pos
				if i >= 0 and g.distance_to(_press_g) <= TouchTrack.SLOP and index_at(_tr.pos) == i:
					press(i)

	func press(i: int) -> void:
		if i >= 0 and i < items.size() and bool(items[i][2]) and on_tap.is_valid():
			on_tap.call(i)


## Tiredness, form and morale for the player sheet: [[label, value text, fraction 0..1, signed (centre-zero) or not, word], ...].
class Status extends Control:
	const ROW_H := 72.0
	var rows: Array = []
	var draw_count := 0
	var _ops := CardKit.Ops.new()

	func _init(p_rows: Array) -> void:
		rows = p_rows
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, ROW_H * float(rows.size()))
		resized.connect(queue_redraw)
		CompKit.set_cue(self, "numbers+words")

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var sb := UI.font("SemiBold")
		var nf := UI.font("SemiBold", true)
		for i in rows.size():
			var r: Array = rows[i]
			var y := float(i) * ROW_H
			var val := String(r[1])
			var word := String(r[4])
			var right := val + ("  " + word if word != "" else "")
			var rw := CardKit.text_w(nf, UI.S_SMALL, right) + 4.0
			_ops.text(sb, UI.S_SMALL, String(r[0]), 0.0, y + 18.0, size.x - rw - 8.0, UI.TEXT)
			_ops.text(nf, UI.S_SMALL, right, size.x - rw, y + 18.0, rw, UI.TEXT)
			var bar := Rect2(0.0, y + 42.0, size.x, 14.0)
			_ops.shape("solid", bar, UI.PANEL3)
			var f := clampf(float(r[2]), -1.0, 1.0)
			var col: Color = r[5] if r.size() > 5 else UI.ACCENT
			if bool(r[3]):
				var half := bar.size.x * 0.5
				var len := maxf(3.0, absf(f) * half)
				_ops.shape("solid", Rect2(bar.position.x + (half if f >= 0.0 else half - len), bar.position.y, len, bar.size.y), col)
				_ops.shape("solid", Rect2(bar.position.x + half - 1.0, bar.position.y - 5.0, 2.0, bar.size.y + 10.0), UI.TEXT)
			else:
				_ops.shape("solid", Rect2(bar.position, Vector2(maxf(3.0, bar.size.x * clampf(f, 0.0, 1.0)), bar.size.y)), col)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped


## The eight stats of the player sheet as one drawn Control: name, a bar to 100 with the potential marked, "now / potential" and
## this season's change. A tap on a row calls `on_row(stat id)` (the screen shows what the stat does). Replaces
## PlayerView.stat_block in the sheet only (that block is about 45 nodes and 40 draw calls; Negotiation keeps it).
class Stats extends Control:
	const ROW_H := 64.0
	var rows: Array = []              # [[stat id, name, now, potential, gain]]
	var on_row: Callable
	var selected := ""
	var draw_count := 0
	var _ops := CardKit.Ops.new()
	var _tr := TouchTrack.new()
	var _press_g := Vector2.ZERO
	var _press := -1

	func _init(p_rows: Array, p_on_row: Callable) -> void:
		rows = p_rows
		on_row = p_on_row
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(0, ROW_H * float(rows.size()))
		resized.connect(queue_redraw)
		CompKit.set_cue(self, "numbers+bars")

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var sb := UI.font("SemiBold")
		var nf := UI.font("SemiBold", true)
		var cw := cols()
		var name_w: float = cw[0]
		var val_w: float = cw[1]
		for i in rows.size():
			var r: Array = rows[i]
			var y := float(i) * ROW_H
			if String(r[0]) == selected or i == _press:
				_ops.bg("card", Rect2(-8.0, y + 2.0, size.x + 16.0, ROW_H - 4.0), UI.PANEL3)
			_ops.text(sb, UI.S_SMALL, String(r[1]), 0.0, y + ROW_H * 0.5, name_w, UI.TEXT)
			var bar := Rect2(name_w, y + ROW_H * 0.5 - 8.0, size.x - name_w - val_w - 12.0, 16.0)
			_ops.shape("solid", bar, UI.VOID)
			_ops.shape("solid", Rect2(bar.position, Vector2(bar.size.x * clampf(float(r[2]) / 100.0, 0.0, 1.0), bar.size.y)), UI.ACCENT)
			_ops.shape("solid", Rect2(bar.position.x + bar.size.x * clampf(float(r[3]) / 100.0, 0.0, 1.0) - 1.5, bar.position.y - 4.0, 3.0, bar.size.y + 8.0), UI.TEAL_HI)
			_ops.text(nf, UI.S_SMALL, _val(r), size.x - val_w, y + ROW_H * 0.5, val_w, UI.GOOD if float(r[4]) >= 0.05 else UI.DIM, 2)
		_ops.flush(self)

	## [name column, value column] widths from the text (the widest of this player's rows), the bar takes the rest.
	func cols() -> Array:
		var sb := UI.font("SemiBold")
		var nf := UI.font("SemiBold", true)
		var val_w := 0.0
		var name_w := 0.0
		for r in rows:
			val_w = maxf(val_w, CardKit.text_w(nf, UI.S_SMALL, _val(r)))
			name_w = maxf(name_w, CardKit.text_w(sb, UI.S_SMALL, String(r[1])))
		return [minf(name_w + 12.0, size.x * 0.42), val_w + 6.0]

	## The width of a stat bar (the fit audit's floor is 96 px).
	func bar_width() -> float:
		var cw := cols()
		return size.x - float(cw[0]) - float(cw[1]) - 12.0

	static func _val(r: Array) -> String:
		var g := float(r[4])
		return "%d / %d%s" % [int(round(float(r[2]))), int(r[3]), "" if absf(g) < 0.05 else " (%+.1f)" % g]

	func clipped() -> Array:
		return _ops.clipped

	func row_at(p: Vector2) -> int:
		if p.x < 0.0 or p.x > size.x or p.y < 0.0:
			return -1
		var i := int(p.y / ROW_H)
		return i if i < rows.size() else -1

	func _gui_input(event: InputEvent) -> void:
		match _tr.feed(event):
			"down":
				_press = row_at(_tr.press_pos)
				_press_g = get_global_transform_with_canvas() * _tr.press_pos
				queue_redraw()
			"up":
				var i := _press
				_press = -1
				queue_redraw()
				var g := get_global_transform_with_canvas() * _tr.pos
				if i >= 0 and g.distance_to(_press_g) <= TouchTrack.SLOP and row_at(_tr.pos) == i:
					press(i)

	func press(i: int) -> void:
		if i < 0 or i >= rows.size():
			return
		selected = "" if selected == String(rows[i][0]) else String(rows[i][0])
		queue_redraw()
		if on_row.is_valid():
			on_row.call(selected)
