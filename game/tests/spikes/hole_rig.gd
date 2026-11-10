extends Control
## Test rig for S2 (build plan I-01, TUTORIAL B11): a scratch stand-in for the real BottomSheet (I-08) and the real
## CoachOverlay (I-12), built exactly the way the plan describes them:
##   page            : a Control in the scene root with a button "page_btn" low on the screen (layer 0)
##   sheet layer 20  : a scrim ColorRect (STOP, closes the sheet on tap) and a sheet Panel holding "sheet_btn"
##   overlay layer 100: FOUR dim ColorRects (STOP) around a hole rectangle, no shader, and optionally an info-step
##                      blocker (STOP) over the hole. The hole itself is empty space: nothing of the overlay covers it.
## Counters: sheet_btn_taps, page_btn_taps, scrim_taps, sheet_panel_taps.
## Replace with the real BottomSheet when I-08 exists (the check keeps working: set `sheet_btn` and `hole_target`).
var sheet_layer: CanvasLayer
var overlay_layer: CanvasLayer
var page_btn: Button
var sheet_btn: Button
var sheet_btn2: Button
var scrim: ColorRect
var sheet_panel: Panel
var dims: Array[ColorRect] = []
var blocker: ColorRect
var hole := Rect2()
var sheet_btn_taps := 0
var sheet_btn2_taps := 0
var page_btn_taps := 0
var scrim_taps := 0
var sheet_panel_taps := 0
const SCREEN := Vector2(720, 1280)


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_btn = Button.new()
	page_btn.text = "page"
	page_btn.position = Vector2(100, 1100)
	page_btn.size = Vector2(300, 96)
	page_btn.pressed.connect(func() -> void: page_btn_taps += 1)
	add_child(page_btn)
	sheet_layer = CanvasLayer.new()
	sheet_layer.layer = 20
	add_child(sheet_layer)
	scrim = ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.5)
	scrim.position = Vector2.ZERO
	scrim.size = SCREEN
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			scrim_taps += 1)
	sheet_layer.add_child(scrim)
	sheet_panel = Panel.new()
	sheet_panel.position = Vector2(0, 600)           # a size M sheet: lower 60 percent of 1280 is 768 px, here 680
	sheet_panel.size = Vector2(720, 680)
	sheet_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet_panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			sheet_panel_taps += 1)
	sheet_layer.add_child(sheet_panel)
	sheet_btn = Button.new()
	sheet_btn.text = "Pick"
	sheet_btn.position = Vector2(400, 1120)           # footer button, lower right of the sheet
	sheet_btn.size = Vector2(260, 96)
	sheet_btn.pressed.connect(func() -> void: sheet_btn_taps += 1)
	sheet_layer.add_child(sheet_btn)
	sheet_btn2 = Button.new()
	sheet_btn2.text = "Other"
	sheet_btn2.position = Vector2(60, 760)            # a second target higher up, for "the hole moves"
	sheet_btn2.size = Vector2(300, 96)
	sheet_btn2.pressed.connect(func() -> void: sheet_btn2_taps += 1)
	sheet_layer.add_child(sheet_btn2)
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 100
	add_child(overlay_layer)
	for i in 4:
		var d := ColorRect.new()
		d.color = Color(0, 0, 0, 0.8)
		d.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay_layer.add_child(d)
		dims.append(d)
	blocker = ColorRect.new()
	blocker.color = Color(0, 0, 0, 0)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	overlay_layer.add_child(blocker)
	set_hole(sheet_btn.get_rect().grow(8))


## The four dim panels: top, bottom, left and right of the hole (clipped to the screen).
func set_hole(r: Rect2) -> void:
	hole = r
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	dims[0].position = Vector2(0, 0)
	dims[0].size = Vector2(SCREEN.x, y0)
	dims[1].position = Vector2(0, y1)
	dims[1].size = Vector2(SCREEN.x, SCREEN.y - y1)
	dims[2].position = Vector2(0, y0)
	dims[2].size = Vector2(x0, y1 - y0)
	dims[3].position = Vector2(x1, y0)
	dims[3].size = Vector2(SCREEN.x - x1, y1 - y0)
	blocker.position = r.position
	blocker.size = r.size


func counters() -> Array:
	return [sheet_btn_taps, sheet_btn2_taps, page_btn_taps, scrim_taps, sheet_panel_taps]
