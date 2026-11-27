class_name ArenaLineup
extends Control
## Both teams' line-ups, always on screen (Match Day M2, Founder decision D3): five rows, each facing its lane opponent; your
## hero on the left with a circle mark, theirs on the right with a hexagon mark (shape first, colour second). Per hero: the
## level on its mark, the name (26 px), K/D/A, a health bar and up to three item icons (dropped in large text first); a dead
## hero dims and shows its respawn seconds instead of the health bar. The middle column names the lane; the gold difference
## of the pair (an arrow towards the leader) joins it when the log carries per-player gold (M1).
## Drawn by one control: shapes and text through one CardKit display list, item icons from the items atlas in one run.
## A display, not a row of buttons: the whole panel is one tap target that opens the Teams sheet (M6). Reads the ArenaPlayer at game
## time t; never the simulation (A1, R7).

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const MID_W := 96.0
const PAD := 10.0

var pl: ArenaPlayer
var t := 0.0
var my_side := "B"
var gold_diff: Callable = Callable()   # (slot, t) -> int, mine minus theirs; set when the log has per-player gold (M1)
var draw_count := 0
var _ops := CardKit.Ops.new()


## Match Day M6: one tap anywhere on the panel (press and release within 12 px) opens the Teams sheet; the screen listens.
signal tapped
var _press_at := Vector2(-1, -1)


func _init(p: ArenaPlayer, side: String) -> void:
	pl = p
	my_side = side
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or (ev is InputEventMouseButton and not DisplayServer.is_touchscreen_available() and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		var pr := (ev as InputEventScreenTouch).pressed if ev is InputEventScreenTouch else (ev as InputEventMouseButton).pressed
		var at: Vector2 = (ev as InputEventScreenTouch).position if ev is InputEventScreenTouch else (ev as InputEventMouseButton).position
		if pr:
			_press_at = at
		elif _press_at.x >= 0.0 and _press_at.distance_to(at) <= 12.0:
			_press_at = Vector2(-1, -1)
			tapped.emit()
			accept_event()


func show_at(p_t: float) -> void:
	t = p_t
	queue_redraw()


func row_h() -> float:
	return size.y / 5.0


## What one hero's half-row shows at t (tests read this; _draw shows exactly this).
func hero_view(key: String) -> Dictionary:
	var kda := pl.kda_of(key, t)
	return {"name": ArenaHud2.hero_name(pl, key), "level": pl.level_of(key, t), "kda": "%d/%d/%d" % [kda[0], kda[1], kda[2]],
			"hp": pl.hp(key, t), "alive": pl.alive(key, t), "respawn": int(ceilf(pl.respawn_in(key, t))),
			"items": _key_items(pl.items_of(key, t))}


## Finished items and boots first, newest first, at most three.
static func _key_items(inv: Array) -> Array:
	var out: Array = []
	for i in range(inv.size() - 1, -1, -1):
		var tier := String(SimData.item(String(inv[i])).get("tier", ""))
		if tier == "finished" or tier == "boots":
			out.append(inv[i])
	for i in range(inv.size() - 1, -1, -1):
		if out.size() >= 3:
			break
		if not out.has(inv[i]):
			out.append(inv[i])
	return out.slice(0, 3)


func _draw() -> void:
	draw_count += 1
	ArtWire.ensure()
	_ops.clear()
	var rh := row_h()
	var side_w := (size.x - MID_W) * 0.5
	var them := "R" if my_side == "B" else "B"
	var large := UI.large
	var f := UI.font()
	var fb := UI.font("Bold")
	var fs := UI.S_SMALL
	var fc := UI.S_CAPTION
	var icons: Array = []    # [item id, rect, alpha]
	draw_style_box(UI.box(Color(UI.PANEL, 0.92), 18), Rect2(Vector2.ZERO, size))
	for i in SLOTS.size():
		var s: String = SLOTS[i]
		var y := float(i) * rh
		if i > 0:
			_ops.shape("solid", Rect2(PAD, y, size.x - 2.0 * PAD, 1.0), Color(UI.TEXT, 0.08))
		_ops.text(f, fc, Strings.t("role.short." + s), side_w, y + rh * (0.30 if gold_diff.is_valid() else 0.5), MID_W, UI.DIM, 1)
		if gold_diff.is_valid():
			var gd := int(gold_diff.call(s, t))
			var arrow := "<" if gd > 0 else (">" if gd < 0 else "=")
			var txt := ArenaHud2.grouped(int(roundf(float(absi(gd)) / 10.0)) * 10)
			var gtxt := ("%s %s" % [arrow, txt]) if gd > 0 else (("%s %s" % [txt, arrow]) if gd < 0 else "=")
			_ops.text(fb, fc, gtxt, side_w, y + rh * 0.72, MID_W, UI.ACCENT if gd > 0 else (UI.CORAL if gd < 0 else UI.DIM), 1)
		for sd in [my_side, them]:
			var mine: bool = sd == my_side
			var v := hero_view(sd + "." + s)
			var a := 1.0 if bool(v["alive"]) else 0.42
			var col := UI.ACCENT if mine else UI.CORAL
			var mark := 34.0
			var x0 := PAD if mine else size.x - PAD - mark
			var l1 := y + rh * (0.32 if not large else 0.36)
			var mr := Rect2(x0, l1 - mark * 0.5, mark, mark)
			_ops.shape("disc" if mine else "hex", mr, Color(col, a))
			_ops.text(fb, fc, str(int(v["level"])), mr.position.x, l1, mark, Color(UI.BG, a), 1)
			var name_x := x0 + mark + 8.0 if mine else size.x - PAD - mark - 8.0
			var kda_w := 86.0
			var name_room := side_w - PAD - mark - 8.0 - kda_w - 6.0
			if mine:
				_ops.text(f, fs, String(v["name"]), name_x, l1, name_room, Color(UI.TEXT, a), 0)
				_ops.text(f, fc, String(v["kda"]), side_w - kda_w - 4.0, l1, kda_w, Color(UI.TEXT2, a), 2)
			else:
				_ops.text(f, fs, String(v["name"]), name_x - name_room, l1, name_room, Color(UI.TEXT, a), 2)
				_ops.text(f, fc, String(v["kda"]), side_w + MID_W + 4.0, l1, kda_w, Color(UI.TEXT2, a), 0)
			var l2 := y + rh * (0.76 if not large else 0.78)
			var bar_w := side_w * (0.42 if not large else 0.62)
			var bx := x0 + mark + 8.0 if mine else size.x - PAD - mark - 8.0 - bar_w
			if bool(v["alive"]):
				_ops.shape("solid", Rect2(bx, l2 - 4.0, bar_w, 8.0), Color(UI.PANEL3, 1.0))
				var fill := clampf(float(v["hp"]), 0.0, 1.0) * bar_w
				_ops.shape("solid", Rect2(bx if mine else bx + bar_w - fill, l2 - 4.0, fill, 8.0), col)
			elif int(v["respawn"]) > 0:
				_ops.text(fb, fc, Strings.f("match.panel.respawn", {"n": int(v["respawn"])}), bx, l2, bar_w, UI.TEXT2, 0 if mine else 2)
			if not large:
				var ic := 26.0
				for j in (v["items"] as Array).size():
					var ix := bx + bar_w + 8.0 + float(j) * (ic + 4.0) if mine else bx - 8.0 - ic - float(j) * (ic + 4.0)
					icons.append([String(v["items"][j]), Rect2(ix, l2 - ic * 0.5, ic, ic), a])
	_ops.flush(self)
	if icons.is_empty():
		return
	var at := ItemIcons.atlas()
	var rects: Dictionary = at["rects"]
	for ic in icons:
		if rects.has(ic[0]) and not (at["failed"] as Array).has(ic[0]):
			draw_texture_rect_region(at["tex"], ic[1], rects[ic[0]], Color(1, 1, 1, float(ic[2])))


func clipped() -> Array:
	return _ops.clipped
