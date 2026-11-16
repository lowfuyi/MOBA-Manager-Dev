class_name PlanKit
extends RefCounted
## Small helpers shared by the I-10 components (PhaseStrip, DetentTrack, Podium, RankRow), all static and all about text:
## the components draw their own text (one Control each, in passes), so they need to wrap it themselves.
##   wrap(font, size, text, room, max_lines)  the lines a text takes in `room` px, broken at spaces; a single word wider than the
##                                            room, or more lines than `max_lines`, ends in "..." (never silently cut). Cached.
##   line_h(font, size)                       the height of one line of that font (rounded up, a little air).
##   name_of_phase(id) / phase_names(ids)     the Strings of gp.phase.<id>.
## Nothing here holds a node or touches game state.

static var _wrap: Dictionary = {}


static func line_h(font: Font, size: int) -> float:
	return ceilf(font.get_height(size) * 1.1)


static func wrap(font: Font, size: int, text: String, room: float, max_lines: int = 99) -> Array:
	if text == "" or room <= 0.0:
		return []
	var key := "%d|%d|%d|%d|%s" % [font.get_instance_id(), size, int(room), max_lines, text]
	if _wrap.has(key):
		return (_wrap[key] as Array).duplicate()
	var words: PackedStringArray = text.split(" ", false)
	var lines: Array = []
	var cur := ""
	for w in words:
		var trial := w if cur == "" else cur + " " + w
		if CardKit.text_w(font, size, trial) <= room + 0.5:
			cur = trial
			continue
		if cur != "":
			lines.append(cur)
		cur = w    # a word wider than the room is cut with "..." when the line is shown (CardKit.fit)
	if cur != "":
		lines.append(cur)
	if lines.size() > max_lines:
		var rest: Array = lines.slice(max_lines - 1)
		lines = lines.slice(0, max_lines - 1)
		lines.append(" ".join(PackedStringArray(rest)))
	for i in lines.size():
		lines[i] = CardKit.fit(font, size, String(lines[i]), room)
	_wrap[key] = lines.duplicate()
	return lines


static func name_of_phase(id: String) -> String:
	return Strings.t("gp.phase." + id)


static func phase_names(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		out.append(name_of_phase(String(id)))
	return out
