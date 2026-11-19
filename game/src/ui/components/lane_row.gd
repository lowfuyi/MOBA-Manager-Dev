class_name LaneRow
extends Control
## One lane of the draft board (UI-PASS-2 5.8, build plan I-09): your slot on the left, the role glyph and word in the middle,
## their slot on the right (the right slot mirrored). 72 px full or 52 px compact; ONE Control, drawn in passes (backgrounds,
## portraits, icons, text by size), display only (it never takes a tap; the board is read, the hero sheet is where you choose).
## A slot is a Dictionary {state, hero, player}:
##   state "empty"   a dashed outline, the word "Open" and the name of the player who would play here (so you see who plays what)
##         "target"  the lane being picked for: a solid accent outline, an arrow towards the slot and a slow pulse of the outline
##                   (the pulse only runs while UI.animate is on; the outline and the arrow are the cue when it is off)
##         "filled"  the hero's portrait (Mini, with the corner role chip), the hero name and the player name
##         "banned"  the hero greyed with a cross and the word "Ban" (a hero that cannot be played here)
##   hero    a heroes.json row (id, name, role_primary, archetype) for "filled" and "banned"
##   player  the player's name (shown under the hero name; for "empty" it is the name of the player who plays this role)
## Mid column: the role glyph (32 px, role colour) and the role word (Caption 24); at large text, when the room is under 620 px,
## the column shrinks to the glyph alone (UI-PASS-2 11b). Names are cut with "..." and never wrap.
## Built once; set_slot / set_compact change it in place (an equal value changes nothing). Colour-blind cue: shape and word
## (dashed, solid ring plus arrow, portrait, cross plus "Ban"), never colour alone.

const SIDES := ["you", "them"]
const H_FULL := 72.0
const H_COMPACT := 52.0
const CENTER_FULL := 128.0
const CENTER_NARROW := 76.0
const GAP := 8.0
const NARROW_BELOW := 620.0

var lane := "top"
var compact := false
var tut_id := ""
var applied := 0
var draw_count := 0
var clipped: Array = []
var _slots := {"you": {"state": "empty", "hero": {}, "player": ""}, "them": {"state": "empty", "hero": {}, "player": ""}}
var _ops := CardKit.Ops.new()
var _pulse := 1.0
var _tween: Tween
var centre_word := true    # false when the centre column is the glyph alone (set during layout, tests read it)


func _init(p_lane: String = "top", p_compact: bool = false, p_tut_id: String = "") -> void:
	lane = p_lane if ArtPalette.ROLES.has(p_lane) else "top"
	compact = p_compact
	tut_id = p_tut_id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0.0, H_COMPACT if compact else H_FULL)
	CompKit.mark_stateful(self)
	CompKit.tag(self, tut_id)
	_note_cue()
	resized.connect(queue_redraw)


func _enter_tree() -> void:
	ArtWire.ensure()
	_sync_pulse()


func _exit_tree() -> void:
	_kill_tween()


func slot(side: String) -> Dictionary:
	return _slots[side]


func state_of(side: String) -> String:
	return String(_slots[side]["state"])


func set_compact(v: bool) -> void:
	if v == compact:
		return
	compact = v
	applied += 1
	custom_minimum_size = Vector2(0.0, H_COMPACT if compact else H_FULL)
	queue_redraw()


## Set one slot. `data` keys not given keep their value; an equal slot changes nothing.
func set_slot(side: String, data: Dictionary) -> void:
	if not _slots.has(side):
		return
	var n: Dictionary = (_slots[side] as Dictionary).duplicate()
	for k in data:
		n[k] = data[k]
	if not ["empty", "target", "filled", "banned"].has(String(n["state"])):
		n["state"] = "empty"
	if _same(n, _slots[side]):
		return
	_slots[side] = n
	applied += 1
	_note_cue()
	_sync_pulse()
	queue_redraw()


static func _same(a: Dictionary, b: Dictionary) -> bool:
	var ha: Dictionary = a["hero"]
	var hb: Dictionary = b["hero"]
	return a["state"] == b["state"] and a["player"] == b["player"] and str(ha.get("id", "")) == str(hb.get("id", ""))


func state_name() -> String:
	for s in SIDES:
		if state_of(s) != "empty":
			return state_of(s)
	return ""


func cue_for(side: String) -> String:
	match state_of(side):
		"empty":
			return "dashed+word"
		"target":
			return "ring+arrow"
		"banned":
			return "cross+word"
	return "portrait"


func _note_cue() -> void:
	var parts: Array = []
	for s in SIDES:
		parts.append(cue_for(s))
	CompKit.set_cue(self, ",".join(PackedStringArray(parts)))


# ---- the pulse ---------------------------------------------------------------------------------------------------------------

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_pulse = 1.0


func _sync_pulse() -> void:
	var want := (state_of("you") == "target" or state_of("them") == "target") and UI.animate and is_inside_tree()
	if want and _tween == null:
		_tween = create_tween().set_loops()
		_tween.tween_method(_set_pulse, 1.0, 0.45, 0.7).set_trans(Tween.TRANS_SINE)
		_tween.tween_method(_set_pulse, 0.45, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	elif not want and _tween != null:
		_kill_tween()
		queue_redraw()


func _set_pulse(v: float) -> void:
	_pulse = v
	queue_redraw()


# ---- layout -> drawing -------------------------------------------------------------------------------------------------------

func centre_w(w: float) -> float:
	return CENTER_FULL if w >= NARROW_BELOW else CENTER_NARROW


## The rectangle of one side's slot in this control's coordinates (size.x is the room it has now).
func slot_rect(side: String, w: float = -1.0) -> Rect2:
	var ww := size.x if w < 0.0 else w
	var cw := centre_w(ww)
	var sw := (ww - cw - GAP * 2.0) * 0.5
	var h := H_COMPACT if compact else H_FULL
	return Rect2(Vector2(0.0, 0.0) if side == "you" else Vector2(ww - sw, 0.0), Vector2(sw, h))


func _layout() -> void:
	_ops.clear()
	var w := size.x if size.x > 0.0 else 672.0
	var h := H_COMPACT if compact else H_FULL
	var cw := centre_w(w)
	# the centre column
	var gx := w * 0.5
	var f24 := UI.font("SemiBold")
	var word := Strings.t("role.short." + lane)
	var ww := CardKit.text_w(f24, UI.S_CAPTION, word)
	centre_word = 32.0 + 8.0 + ww <= cw - 8.0
	if centre_word:
		var total := 32.0 + 8.0 + ww
		_ops.icon(Icons.role_id(lane), Rect2(gx - total * 0.5, h * 0.5 - 16.0, 32.0, 32.0), ArtPalette.role_color(lane))
		_ops.text(f24, UI.S_CAPTION, word, gx - total * 0.5 + 40.0, h * 0.5, ww + 2.0, UI.TEXT2, 0)
	else:
		_ops.icon(Icons.role_id(lane), Rect2(gx - 16.0, h * 0.5 - 16.0, 32.0, 32.0), ArtPalette.role_color(lane))
	for side in SIDES:
		_slot(side, slot_rect(side, w))


func _slot(side: String, r: Rect2) -> void:
	var d: Dictionary = _slots[side]
	var st := String(d["state"])
	var hero: Dictionary = d["hero"]
	var mirror := side == "them"
	var f := UI.font("SemiBold")
	var ph := 40.0 if compact else 52.0
	var px := r.position.x + (r.size.x - ph - 6.0 if mirror else 6.0)
	var pr := Rect2(px, r.position.y + (r.size.y - ph) * 0.5, ph, ph)
	var tx := (r.position.x + 10.0) if mirror else (px + ph + 10.0)
	var room := r.size.x - ph - 6.0 - 10.0 - 10.0
	var align := 2 if mirror else 0
	var player := String(d["player"])
	var line1_cy := r.position.y + (r.size.y * 0.5 - 12.0 if player != "" or st == "banned" else r.size.y * 0.5)
	var line2_cy := r.position.y + r.size.y * 0.5 + 13.0
	# background
	match st:
		"filled":
			_ops.bg("card", r, UI.PANEL)
		"banned":
			_ops.bg("card", r, UI.PANEL.darkened(0.38))
		"target":
			_ops.bg("card", r, Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.10))
			_ops.bg("ring", r, Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, _pulse))
		_:
			CardKit.dashed_ops(_ops, r, Color(UI.DIM.r, UI.DIM.g, UI.DIM.b, 0.6))
	# the picture, the lines of text
	var empty_look := st == "empty" or st == "target"
	if empty_look:
		_ops.shape("disc", pr.grow(-2.0), Color(UI.PANEL3.r, UI.PANEL3.g, UI.PANEL3.b, 0.5))
		_ops.text(f, UI.S_SMALL, Strings.t("draft.slot_open"), tx, line1_cy, room, UI.DIM, align)
		if player != "":
			_ops.text(f, UI.S_CAPTION, player, tx, line2_cy, room, UI.TEXT2, align)
		if st == "target":
			var ax := r.end.x - 34.0 if not mirror else r.position.x + 6.0
			_ops.icon("chevron_l" if mirror else "chevron_r", Rect2(ax, r.position.y + r.size.y * 0.5 - 14.0, 28.0, 28.0), UI.ACCENT)
	else:
		var banned := st == "banned"
		if not hero.is_empty():
			var hp := HeroCard.prepare(hero)
			var sil: Dictionary = hp["sil"]
			_ops.portraits.append(["hero", pr, str(sil["role"]), int(sil["variant"]), float(sil["hue_shift"]), bool(sil["mirror"]), banned])
			if ph <= 56.0:
				var dd := clampf(ph * 0.46, 20.0, 26.0)
				_ops.portraits.append(["chip", Rect2(pr.end - Vector2(dd, dd), Vector2(dd, dd)), str(sil["role"])])
			_ops.text(f, UI.S_SMALL, str(hp["name"]), tx, line1_cy, room, UI.TEXT_OFF if banned else UI.TEXT, align)
		if banned:
			_ops.icon("cross", Rect2(pr.get_center() - Vector2(14, 14), Vector2(28, 28)), UI.BAD)
			_ops.text(f, UI.S_CAPTION, Strings.t("card.banned"), tx, line2_cy, room, UI.TEXT2, align)
		elif player != "":
			_ops.text(f, UI.S_CAPTION, player, tx, line2_cy, room, UI.TEXT2, align)


func _draw() -> void:
	if batched():
		get_parent().queue_redraw()    # the board draws every row in one pass (I-16 perf); this row's own canvas item stays empty
		return
	draw_count += 1
	_layout()
	_ops.flush(self)
	clipped = _ops.clipped.duplicate()


## True inside a LaneBoard: the board draws this row (LaneBoard._draw), so five rows cost a few draw calls, not five times as many.
func batched() -> bool:
	return get_parent() is LaneBoard


## The board's half of the batched draw: lay this row out and hand over its display list (in this row's coordinates).
func queue_for_board() -> CardKit.Ops:
	draw_count += 1
	_layout()
	return _ops


## After the board flushed: what was cut in this row (the board's flush records it for every row).
func note_clipped(cut: Array) -> void:
	clipped = cut
