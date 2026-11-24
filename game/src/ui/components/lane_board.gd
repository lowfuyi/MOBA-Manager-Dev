class_name LaneBoard
extends VBoxContainer
## The draft board (UI-PASS-2 5.8, ART-BIBLE 3.8, build plan I-09): a header, five LaneRows (Top, Jungle, Mid, Bot, Support),
## and a bans row. You are on the left, headed by the teal circle glyph; they are on the right, headed by the coral hexagon
## glyph (shape carries the side, so it holds in greyscale). 7 nodes: the board, the header, five rows, the bans row.
## Built once, then only data: set_slot(role, side, data) (the slot dictionary of LaneRow), set_target(role, side) (the one lane
## being picked for), set_bans(side, hero rows), set_compact(bool). Every setter ignores an equal value.
## Rows are tagged `<tut_id>.<role>`, the board `<tut_id>`.

const ROLES := ["top", "jg", "mid", "bot", "sup"]
const HEADER_H := 56.0
const HEADER_LINE_H := 44.0        # one-line rows (large text): a shorter header and 6 px between rows
const SEP := 8
const SEP_LINE := 6
const BANS_H := 60.0
const MAX_BANS := 5

var compact := true
var one_line := false              # large text: one-line 40 px rows (LaneRow.one_line, DECISIONS Q6-2 (a))
var tut_id := ""
var applied := 0
var rows: Dictionary = {}          # role -> LaneRow
var header: Control
var bans_row: Control
var _bans := {"you": [], "them": []}
var ban_slots := 1                 # slots per side under "Bans" (the draft's bans per side, 1 to 5)


## The header: the circle glyph and "Your team" on the left, the hexagon glyph and "Opponent" on the right.
class _Header extends Control:
	var draw_count := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0.0, LaneBoard.HEADER_H)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_count += 1
		var ops := CardKit.Ops.new()
		var f := UI.font("SemiBold")
		var cy := size.y * 0.5
		ops.icon("side_you", Rect2(8.0, cy - 14.0, 28.0, 28.0), UI.ACCENT)
		ops.text(f, UI.S_SMALL, Strings.t("draft.you"), 44.0, cy, size.x * 0.5 - 52.0, UI.TEXT, 0)
		ops.icon("side_them", Rect2(size.x - 36.0, cy - 14.0, 28.0, 28.0), UI.CORAL)
		ops.text(f, UI.S_SMALL, Strings.t("draft.opponent"), size.x * 0.5 + 8.0, cy, size.x * 0.5 - 52.0, UI.TEXT, 2)
		ops.flush(self)


## The bans row: the no-entry glyph and the word "Bans" in the middle; each team's row of `ban_slots` slots in its own column
## (yours left, theirs right, like the lanes above). An empty slot is a faint violet well; a ban fills it with the hero's greyed
## portrait struck through (one violet line, drawn for all slots in one call).
class _Bans extends Control:
	var board: LaneBoard
	var draw_count := 0

	func _init(p_board: LaneBoard) -> void:
		board = p_board
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0.0, LaneBoard.BANS_H)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_count += 1
		var ops := CardKit.Ops.new()
		var f := UI.font("SemiBold")
		var cy := size.y * 0.5
		var m := 40.0
		var word := Strings.t("draft.bans_short")
		var ww := CardKit.text_w(f, UI.S_CAPTION, word)
		var gw := 24.0 + 4.0 + ww
		ops.icon("ban", Rect2(size.x * 0.5 - gw * 0.5, cy - 12.0, 24.0, 24.0), UI.BAN)
		ops.text(f, UI.S_CAPTION, word, size.x * 0.5 - gw * 0.5 + 28.0, cy, ww + 2.0, UI.TEXT2, 0)
		var strikes := PackedVector2Array()
		var n := clampi(board.ban_slots, 1, LaneBoard.MAX_BANS)
		var half := size.x * 0.5 - gw * 0.5 - 8.0
		m = minf(m, (half - 4.0 - 6.0 * float(n - 1)) / float(n))
		for side in ["you", "them"]:
			var list: Array = board._bans[side]
			for i in n:
				var x := 4.0 + float(i) * (m + 6.0) if side == "you" else size.x - 4.0 - m - float(i) * (m + 6.0)
				var r := Rect2(x, cy - m * 0.5, m, m)
				if i >= list.size():
					ops.shape("solid", r, Color(UI.BAN, 0.16))
					continue
				var hp := HeroCard.prepare(list[i])
				var sil: Dictionary = hp["sil"]
				ops.portraits.append(["hero", r, str(sil["role"]), int(sil["variant"]), float(sil["hue_shift"]), bool(sil["mirror"]), true])
				strikes.append(r.position + Vector2(3, m - 3))
				strikes.append(r.position + Vector2(m - 3, 3))
		ops.flush(self)
		if not strikes.is_empty():
			draw_multiline(strikes, UI.BAN, 4.0)


func _init(p_compact: bool = true, p_tut_id: String = "", p_one_line: bool = false) -> void:
	compact = p_compact
	one_line = p_one_line
	tut_id = p_tut_id
	add_theme_constant_override("separation", SEP_LINE if one_line else SEP)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	header = _Header.new()
	if one_line:
		header.custom_minimum_size = Vector2(0.0, HEADER_LINE_H)
	add_child(header)
	for r in ROLES:
		var row := LaneRow.new(r, compact, "%s.%s" % [tut_id, r] if tut_id != "" else "", one_line)
		rows[r] = row
		add_child(row)
	bans_row = _Bans.new(self)
	add_child(bans_row)
	CompKit.mark_stateful(self)
	CompKit.tag(self, tut_id)
	_note_cue()
	sort_children.connect(queue_redraw)    # rows moved (compact / full, large text): the board redraws them where they are now


## The five rows in one display list (each LaneRow lays itself out, the board flushes them together): a few draw calls in all.
func _draw() -> void:
	var ops := CardKit.Ops.new()
	var spans: Array = []
	for r in ROLES:
		var lr := rows[r] as LaneRow
		if not lr.visible:
			continue
		var t0 := ops.texts.size()
		ops.append_shifted(lr.queue_for_board(), lr.position)
		spans.append([lr, t0, ops.texts.size()])
	ops.flush(self)
	for sp in spans:    # hand each row the texts of its own that were cut
		var lr := sp[0] as LaneRow
		var cut: Array = []
		for k in range(int(sp[1]), int(sp[2])):
			if ops.clipped.has(String((ops.texts[k] as Array)[2])):
				cut.append(String((ops.texts[k] as Array)[2]))
		lr.note_clipped(cut)


func row(role: String) -> LaneRow:
	return rows[role] as LaneRow


func set_compact(v: bool) -> void:
	if v == compact:
		return
	compact = v
	applied += 1
	for r in ROLES:
		(rows[r] as LaneRow).set_compact(v)


func set_one_line(v: bool) -> void:
	if v == one_line:
		return
	one_line = v
	applied += 1
	add_theme_constant_override("separation", SEP_LINE if one_line else SEP)
	header.custom_minimum_size = Vector2(0.0, HEADER_LINE_H if one_line else HEADER_H)
	for r in ROLES:
		(rows[r] as LaneRow).set_one_line(v)


func set_slot(role: String, side: String, data: Dictionary) -> void:
	if not rows.has(role):
		return
	var before := (rows[role] as LaneRow).applied
	(rows[role] as LaneRow).set_slot(side, data)
	if (rows[role] as LaneRow).applied != before:
		applied += 1
		_note_cue()


## Mark the one slot being picked for (`role`, `side`); a slot that was the target goes back to empty. role "" clears.
func set_target(role: String, side: String = "you") -> void:
	for r in ROLES:
		for s in LaneRow.SIDES:
			var lr := rows[r] as LaneRow
			if r == role and s == side:
				if lr.state_of(s) != "filled":
					lr.set_slot(s, {"state": "target"})
			elif lr.state_of(s) == "target":
				lr.set_slot(s, {"state": "empty"})
	applied += 1
	_note_cue()


func set_bans(side: String, heroes: Array) -> void:
	if not _bans.has(side):
		return
	var ids_a: Array = []
	for h in _bans[side]:
		ids_a.append(str((h as Dictionary)["id"]))
	var ids_b: Array = []
	for h in heroes:
		ids_b.append(str((h as Dictionary)["id"]))
	if ids_a == ids_b:
		return
	_bans[side] = heroes.duplicate()
	applied += 1
	bans_row.queue_redraw()


## The number of ban slots per side (the draft's bans per side).
func set_ban_slots(n: int) -> void:
	n = clampi(n, 1, MAX_BANS)
	if n == ban_slots:
		return
	ban_slots = n
	applied += 1
	bans_row.queue_redraw()


func bans(side: String) -> Array:
	return _bans[side]


func state_name() -> String:
	for r in ROLES:
		if (rows[r] as LaneRow).state_name() != "":
			return "slots"
	return ""


func _note_cue() -> void:
	var any := state_name() != ""
	CompKit.set_cue(self, "slot cues on each row" if any else "")
