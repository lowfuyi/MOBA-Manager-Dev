extends RefCounted
## A stand-in for the screens the tutorial points at (tests only; no class_name, preload it). The real screens that carry the 27
## first-run ids arrive in I-15 to I-21, so the overlay and runner tests use REAL Main, REAL BottomSheet, REAL CoachOverlay and
## REAL TutorialRunner, with this stub supplying the tagged controls:
##   Stub.build_for(step_id)   one tagged Button per target id of that step (stage a), placed at the top, middle or bottom
##   a press of a tagged button raises the events the real screen would (open:player_card, draft:sheet, draft:ban ...), and the
##   sheet steps open a REAL BottomSheet holding the stage-B controls (draft.sheet.confirm, gp.coach_apply, report.why_sheet,
##   roster.card.head, draft.slot_list), so the hole is cut over a control inside a sheet on layer 20 (TUTORIAL B11).
## Every tagged Button also raises `tap:<id>` by itself (UI.tag). The stub never changes any game state.

const TOP := 0
const MID := 1
const BOTTOM := 2

class Stub extends Control:
	var placement := MID
	var tall_choices := false         # draft.choices as a 560 px block (a big target, TUTORIAL 3.4)
	var presses: Dictionary = {}      # id -> count
	var sheet_kind := ""              # "ban" or "pick" while the draft sheet is open
	var _made: Array = []

	func _init() -> void:
		name = "TutStub"
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func clear_targets() -> void:
		for b in _made:
			if is_instance_valid(b):
				b.hide()
				b.queue_free()
		_made.clear()

	## One tagged button per id, stacked from the placement's y, 96 px high (a tall block for draft.choices when asked).
	func build_for(step_id: String) -> void:
		clear_targets()
		var def: Dictionary = TutorialState.step_def(step_id)
		var vp := get_viewport_rect().size
		var y := 140.0 if placement == TOP else (vp.y * 0.45 if placement == MID else vp.y - 330.0)
		for id in def.get("target", []):
			if UI.find_tag(String(id)) != null:
				continue    # already supplied (a real control, or a sheet that is open)
			var b := make_button(String(id), vp.x - 120.0)
			if String(id) == "draft.choices" and tall_choices:
				b.custom_minimum_size.y = 560.0
				b.size.y = 560.0
			b.position = Vector2(60.0, y)
			y += b.size.y + 16.0

	func make_button(id: String, w: float) -> Button:
		var b := UI.button(id, _on_press.bind(id), "normal", 96)
		b.size = Vector2(w, 96.0)
		UI.tag(b, id)
		add_child(b)
		_made.append(b)
		return b

	func _on_press(id: String) -> void:
		presses[id] = int(presses.get(id, 0)) + 1
		var bus: EventBus = App.bus
		match id:
			"squad.bench.0":
				bus.emit("open:player_card")
				_sheet("Player card", "roster.card.head", "", "")
			"draft.choices":
				sheet_kind = "ban" if (App.tutorial != null and App.tutorial.m != null and App.tutorial.m.step_id() == "ban") else "pick"
				bus.emit("draft:sheet", {"kind": sheet_kind})
				_sheet("Hero", "draft.slot_list", "draft.sheet.confirm", "Ban" if sheet_kind == "ban" else "Pick")
			"draft.sheet.confirm":
				bus.emit("draft:" + sheet_kind, {})
				close_sheet()
			"draft.auto_rest":
				if int(presses[id]) >= 2:
					bus.emit("draft:done")
			"gp.coach":
				bus.emit("gp:coach_open")
				_sheet("Coach", "", "gp.coach_apply", "Apply")
			"gp.coach_apply":
				bus.emit("gp:coach_apply")
				close_sheet()
			"match.controls":
				bus.emit("match:speed")
			"report.why":
				bus.emit("open:report_why")
				_sheet("Why", "report.why_sheet", "", "")
			"stand.metric":
				bus.emit("stand:metric")

	## A real BottomSheet (size M) with an optional tagged panel in its content and an optional tagged footer button.
	func _sheet(title: String, content_id: String, footer_id: String, footer_text: String) -> void:
		var build_content := func(content: VBoxContainer) -> void:
			var p := PanelContainer.new()
			p.custom_minimum_size = Vector2(0, 120)
			p.add_child(UI.label(title + " (sheet content)", UI.S_BODY, UI.TEXT))
			content.add_child(p)
			if content_id != "":
				UI.tag(p, content_id, false)
		var build_footer := Callable()
		if footer_id != "":
			build_footer = func(footer: VBoxContainer) -> void:
				BottomSheet.footer_button(footer, footer_text, _on_press.bind(footer_id), "primary", footer_id)
		BottomSheet.open(title, build_content, build_footer, "M", "stub")

	func close_sheet() -> void:
		var s := BottomSheet.current()
		if s != null:
			s.close()

	func press_id(id: String) -> bool:
		var c := UI.find_tag(id)
		if c is BaseButton:
			(c as BaseButton).pressed.emit()
			return true
		return false


## Add a stub to Main (above the content, below the sheet layer) and return it.
static func add_to(main: Control) -> Stub:
	var s := Stub.new()
	main.add_child(s)
	return s
