class_name ArenaTimeline
extends Control
## The replay timeline (Match Day M7): a track over the whole show with a tick for each kill (in the killer's side colour,
## short; yours above the track, theirs below), tower (taller, light) and objective take (tallest, gold), and a knob at the show time. Press or drag anywhere on it
## to jump: `seek` is called with the fraction 0..1. Only after the match has ended (the live watch has no timeline, so it
## stays free of spoilers). Display only: reads the ArenaPlayer (A1, R7). One control, one display list.

signal seek(frac: float)

var pl: ArenaPlayer
var frac := 0.0
var draw_count := 0
var _ops := CardKit.Ops.new()
var _held := false
var _ticks: Array = []        # [fraction, kind ("kill", "tower", "objective"), side]


func _init(p: ArenaPlayer) -> void:
	pl = p
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	var len_s := maxf(1.0, pl.show_len)
	for k in pl.kills:
		if not String(k[1]).begins_with("tower."):
			_ticks.append([pl.show_t(float(k[0])) / len_s, "kill", ArenaPlayer.side_of(String(k[1]))])
	for tw in pl.towers:
		_ticks.append([pl.show_t(float(tw[0])) / len_s, "tower", String(tw[2])])
	for o in pl.objs:
		_ticks.append([pl.show_t(float(o[0])) / len_s, "objective", String(o[2])])


## The ticks (tests read them): [fraction, kind, side].
func ticks() -> Array:
	return _ticks


func set_frac(f: float) -> void:
	frac = clampf(f, 0.0, 1.0)
	queue_redraw()


func _track() -> Rect2:
	return Rect2(12.0, size.y * 0.5 - 5.0, size.x - 24.0, 10.0)


func _gui_input(ev: InputEvent) -> void:
	var at := Vector2(-1, -1)
	if ev is InputEventScreenTouch:
		_held = (ev as InputEventScreenTouch).pressed
		at = (ev as InputEventScreenTouch).position
	elif ev is InputEventScreenDrag:
		at = (ev as InputEventScreenDrag).position
	elif ev is InputEventMouseButton and not DisplayServer.is_touchscreen_available() and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_held = (ev as InputEventMouseButton).pressed
		at = (ev as InputEventMouseButton).position
	elif ev is InputEventMouseMotion and _held and not DisplayServer.is_touchscreen_available():
		at = (ev as InputEventMouseMotion).position
	if at.x < 0.0 or not (_held or ev is InputEventScreenDrag):
		return
	var tr := _track()
	var f := clampf((at.x - tr.position.x) / maxf(1.0, tr.size.x), 0.0, 1.0)
	set_frac(f)
	seek.emit(f)
	accept_event()


func _draw() -> void:
	draw_count += 1
	ArtWire.ensure()
	_ops.clear()
	var tr := _track()
	_ops.shape("solid", tr, UI.PANEL3)
	_ops.shape("solid", Rect2(tr.position, Vector2(tr.size.x * frac, tr.size.y)), Color(UI.TEXT2, 0.55))
	for tk in _ticks:
		var x := tr.position.x + tr.size.x * float(tk[0])
		var h := 16.0 if tk[1] == "kill" else (26.0 if tk[1] == "tower" else 34.0)
		var col := UI.WARN if tk[1] == "objective" else (UI.TEXT if tk[1] == "tower" else (UI.ACCENT if String(tk[2]) == pl.my_side else UI.CORAL))
		var y0 := tr.get_center().y - h * 0.5
		if tk[1] == "kill":    # your kills above the track, theirs below: position, not colour alone
			y0 = tr.get_center().y - h if String(tk[2]) == pl.my_side else tr.get_center().y
		_ops.shape("solid", Rect2(x - 1.5, y0, 3.0, h), col)
	var kx := tr.position.x + tr.size.x * frac
	_ops.shape("disc", Rect2(kx - 14.0, tr.get_center().y - 14.0, 28.0, 28.0), UI.TEXT)
	_ops.flush(self)
