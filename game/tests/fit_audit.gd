extends RefCounted
## Fit audit (build plan 3.2, test "fit_<screen>_<variant>"): looks at the controls of the screen on show and lists
## what does not fit. No class_name on purpose (use `const FitAudit = preload("res://tests/fit_audit.gd")`), so it
## needs no --import. It reads layout only (rects, text widths in Godot's own text server), so it runs headless.
##
## Rules, each a line of text in the returned Array (empty = clean):
##   1 overflow   a visible control reaches outside the frame (0 .. canvas width) or outside a clipping ancestor
##                (a ScrollContainer), horizontally. Vertical overflow is scrolling and is allowed.
##   2 clipped    a Label or Button whose text needs more width than it has: an unbreakable word wider than the
##                text room ("Playo-ffs", "Trophi/es"), a non-wrapping text wider than its room, or lines cut off.
##   3 button     a visible button lower than MIN_BTN (96) or narrower than MIN_BTN_W (96; the tap area).
##   4 text size  a Label or Button whose font is below the 24 px floor.
## `frame_w` is the logical canvas width: 720, or 626 in large-text mode (UI.canvas_w()).

const MIN_BTN := 96.0
const MIN_BTN_W := 96.0
const FLOOR_PX := 24
const EPS := 1.5


static func audit(root: Control, frame_w: float) -> Array:
	var out: Array = []
	_walk(root, frame_w, out, Rect2(-100000, -100000, 200000, 200000))
	return out


static func _name(c: Control) -> String:
	var t := ""
	if c is Label:
		t = (c as Label).text
	elif c is Button:
		t = (c as Button).text
	t = t.replace("\n", " ")
	if t.length() > 30:
		t = t.substr(0, 30) + "..."
	return "%s '%s'" % [c.get_class(), t] if t != "" else c.get_class()


static func _walk(n: Node, frame_w: float, out: Array, clip: Rect2) -> void:
	var c := n as Control
	if c != null:
		if not c.visible:
			return
		var r := c.get_global_rect()
		# 1 overflow
		if c.size.x > 0.0 and c.size.y > 0.0:
			var room := clip.intersection(Rect2(0, -100000, frame_w, 200000))
			if r.position.x < room.position.x - EPS or r.end.x > room.end.x + EPS:
				out.append("overflow: %s spans x %.0f..%.0f, room %.0f..%.0f" % [_name(c), r.position.x, r.end.x, room.position.x, room.end.x])
		if c is Label:
			_check_text(c, (c as Label).text, c.size.x, (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF, out)
			if (c as Label).get_line_count() > (c as Label).get_visible_line_count() and (c as Label).get_visible_line_count() > 0:
				out.append("clipped: %s shows %d of %d lines" % [_name(c), (c as Label).get_visible_line_count(), (c as Label).get_line_count()])
		elif c is Button:
			var b := c as Button
			var sb := b.get_theme_stylebox("normal")
			var room_w := c.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0)
			if b.text != "":
				_check_text(c, b.text, room_w, b.autowrap_mode != TextServer.AUTOWRAP_OFF, out)
			# 3 button size (the tile's invisible whole-card button and every real button alike)
			if c.size.y < MIN_BTN - 0.5 or c.size.x < MIN_BTN_W - 0.5:
				out.append("button: %s is %.0f x %.0f, minimum %.0f x %.0f" % [_name(c), c.size.x, c.size.y, MIN_BTN_W, MIN_BTN])
		if c.clip_contents or c is ScrollContainer:
			clip = clip.intersection(r)
	for ch in n.get_children():
		_walk(ch, frame_w, out, clip)


static func _check_text(c: Control, text: String, room: float, wraps: bool, out: Array) -> void:
	if text == "":
		return
	var font := c.get_theme_font("font")
	var size := c.get_theme_font_size("font_size")
	# 4 text size floor
	if size < FLOOR_PX:
		out.append("text size: %s is %d px, floor %d" % [_name(c), size, FLOOR_PX])
	# 2 clipped text
	if wraps:
		for line in text.split("\n"):
			for word in line.split(" ", false):
				var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				if w > room + EPS:
					out.append("clipped: %s word '%s' is %.0f px, room %.0f (breaks mid-word)" % [_name(c), word, w, room])
	else:
		var w := 0.0
		for line in text.split("\n"):
			w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		if w > room + EPS:
			out.append("clipped: %s needs %.0f px, room %.0f" % [_name(c), w, room])
