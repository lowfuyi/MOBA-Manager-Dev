class_name StandKit
extends RefCounted
## Drawn pieces of Standings (build plan I-20, UI-PASS-2 6.5):
##   Rows     a VBoxContainer that draws its RankRow children in one pass (RankRow.draw_children): ten rows cost a few draw calls
##   Bracket  the playoff bracket as one Control: two semi-final cards over the grand final, joined by lines; wins as filled pips,
##            the winner ticked, your series with an accent bar and the YOU pill; before the playoffs a dashed "ghost" bracket
##            from the current top four ("If the season ended now")
##   Games    the recent games as one Control: a W or L pill (the letter, not colour alone), "vs <club>", the round and the margin
##            word, and three phase dots (filled = you won that phase; a plus or minus inside)
## Nothing here reads the save; the screen passes the data in.


class Rows extends VBoxContainer:
	var draw_count := 0

	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_constant_override("separation", 0)
		sort_children.connect(queue_redraw)

	func draws_rows() -> bool:
		return true

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		RankRow.draw_children(self)


## series: [{id, a, b, a_name, b_name, wins_a, wins_b, best_of, done, winner, seed_a, seed_b}] for SF1, SF2 and F (F may be {}).
class Bracket extends Control:
	const CARD_H := 168.0
	const GAP := 16.0
	const LINK := 48.0
	var series: Array = []
	var ghost := false
	var me := ""
	var draw_count := 0
	var _ops := CardKit.Ops.new()

	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, CARD_H * 3.0 + GAP + LINK + 8.0)
		resized.connect(queue_redraw)
		CompKit.set_cue(self, "pips+tick+YOU")

	func set_data(p_series: Array, p_ghost: bool, p_me: String) -> void:
		series = p_series.duplicate(true)
		ghost = p_ghost
		me = p_me
		queue_redraw()

	## The two semi-finals stacked full width (side by side they cut "Northreach Corsairs" next to the YOU pill), the final below,
	## indented on the right of the bracket line that joins them.
	func card_rect(i: int) -> Rect2:
		var w := size.x
		var ind := 32.0
		if i < 2:
			return Rect2(ind, float(i) * (CARD_H + GAP), w - ind, CARD_H)
		return Rect2(ind, 2.0 * CARD_H + GAP + LINK, w - ind, CARD_H)

	func _card(i: int, s: Dictionary) -> void:
		var r := card_rect(i)
		var mine := not s.is_empty() and (String(s.get("a", "")) == me or String(s.get("b", "")) == me)
		if ghost:
			CardKit.dashed_ops(_ops, r, Color(UI.DIM.r, UI.DIM.g, UI.DIM.b, 0.7))
		else:
			_ops.bg("card", r, UI.PANEL3 if mine else UI.PANEL2)
		if mine:
			_ops.shape("solid", Rect2(r.position.x, r.position.y + 16.0, 8.0, r.size.y - 32.0), UI.ACCENT)
		var sb := UI.font("SemiBold")
		var head := Strings.t("standings.bracket.final" if i == 2 else "standings.bracket.sf")
		if not s.is_empty():
			head += "  -  " + Strings.f("standings.bracket.bo", {"bo": int(s.get("best_of", 3))})
		_ops.text(sb, UI.S_CAPTION, head, r.position.x + 20.0, r.position.y + 24.0, r.size.x - 40.0, UI.DIM)
		for k in 2:
			var side := "a" if k == 0 else "b"
			var y := r.position.y + 64.0 + float(k) * 48.0
			var nm := String(s.get(side + "_name", ""))
			if nm == "":
				nm = Strings.f("standings.bracket.winner_of", {"id": "SF%d" % (k + 1)})
			var seed := int(s.get("seed_" + side, 0))
			var won := bool(s.get("done", false)) and String(s.get("winner", "")) == String(s.get(side, "~"))
			var x := r.position.x + 20.0
			if seed > 0:
				_ops.text(UI.font("SemiBold", true), UI.S_SMALL, str(seed), x, y, 28.0, UI.DIM)
				x += 32.0
			var wins := int(s.get("wins_" + side, 0))
			var need := int(s.get("best_of", 3)) / 2 + 1
			var pips_w := float(need) * 18.0
			var room := r.end.x - 20.0 - pips_w - 12.0 - x - (34.0 if won else 0.0)
			var is_me := String(s.get(side, "")) == me
			if is_me:
				var pw := CardKit.text_w(sb, UI.S_CAPTION, Strings.t("standings.you")) + 20.0
				room -= pw + 8.0
				_ops.bg("pill", Rect2(x + minf(CardKit.text_w(sb, UI.S_SMALL, nm), room) + 8.0, y - 18.0, pw, 36.0), UI.ACCENT)
				_ops.text(sb, UI.S_CAPTION, Strings.t("standings.you"), x + minf(CardKit.text_w(sb, UI.S_SMALL, nm), room) + 8.0, y, pw, UI.INK_TEAL, 1)
			_ops.text(sb, UI.S_SMALL, nm, x, y, room, UI.TEXT)
			if won:
				_ops.icon("tick", Rect2(r.end.x - 20.0 - pips_w - 12.0 - 30.0, y - 13.0, 26.0, 26.0), UI.GOOD)
			for p in need:
				var px := r.end.x - 20.0 - pips_w + float(p) * 18.0
				_ops.shape("disc", Rect2(px, y - 7.0, 14.0, 14.0), UI.TEAL_HI if p < wins else Color(UI.DIM.r, UI.DIM.g, UI.DIM.b, 0.35))

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var line := Color(UI.DIM.r, UI.DIM.g, UI.DIM.b, 0.6)
		var a := card_rect(0)
		var b := card_rect(1)
		var f := card_rect(2)
		var lx := 12.0
		_ops.shape("solid", Rect2(lx, a.get_center().y, 3.0, f.get_center().y - a.get_center().y), line)    # the bracket line
		for r in [a, b, f]:
			_ops.shape("solid", Rect2(lx, (r as Rect2).get_center().y - 1.5, (r as Rect2).position.x - lx, 3.0), line)
		for i in 3:
			_card(i, series[i] if i < series.size() else {})
		PlanKit.batch_order(_ops)    # 9-slices first, then quads (the lines sit beside the cards, never under one)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped


## games: [{won, opp, opp_name, round_text, word, phases: [+1/-1 x3]}] newest first.
class Games extends Control:
	const ROW_H := 88.0
	var games: Array = []
	var draw_count := 0
	var _ops := CardKit.Ops.new()

	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		CompKit.set_cue(self, "W/L letter+dots")

	func set_games(g: Array) -> void:
		games = g.duplicate(true)
		custom_minimum_size = Vector2(0, ROW_H * float(games.size()))
		queue_redraw()

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var sb := UI.font("SemiBold")
		for i in games.size():
			var g: Dictionary = games[i]
			var y := float(i) * ROW_H
			var r := Rect2(0.0, y + 4.0, size.x, ROW_H - 8.0)
			_ops.bg("card", r, UI.PANEL2)
			var won := bool(g["won"])
			var c := UI.GOOD if won else UI.BAD
			_ops.bg("pill", Rect2(16.0, y + ROW_H * 0.5 - 22.0, 44.0, 44.0), c)
			_ops.text(UI.font("Bold"), UI.S_BODY, "W" if won else "L", 16.0, y + ROW_H * 0.5, 44.0, UI.INK_TEAL, 1)
			var dots_w := 3.0 * 22.0
			var room := size.x - 76.0 - dots_w - 24.0
			_ops.text(sb, UI.S_SMALL, "%s %s" % [Strings.t("standings.vs"), String(g["opp_name"])], 76.0, y + 30.0, room, UI.TEXT)
			_ops.text(UI.font(), UI.S_CAPTION, "%s  -  %s" % [String(g["round_text"]), String(g["word"])], 76.0, y + 60.0, room, UI.DIM)
			var ph: Array = g["phases"]
			for k in ph.size():
				var x := size.x - 16.0 - dots_w + float(k) * 22.0
				var mine := int(ph[k]) > 0
				_ops.shape("disc", Rect2(x, y + ROW_H * 0.5 - 8.0, 16.0, 16.0), UI.TEAL_HI if mine else Color(UI.CORAL.r, UI.CORAL.g, UI.CORAL.b, 0.55))
				_ops.shape("solid", Rect2(x + 4.0, y + ROW_H * 0.5 - 1.0, 8.0, 2.0), UI.VOID)
				if mine:
					_ops.shape("solid", Rect2(x + 7.0, y + ROW_H * 0.5 - 4.0, 2.0, 8.0), UI.VOID)
		PlanKit.batch_order(_ops)    # 9-slices first, then the dots: one switch, not two per row
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped
