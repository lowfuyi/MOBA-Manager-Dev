class_name HelpSheet
extends RefCounted
## The "?" help of every screen (TUTORIAL 5.1, build plan I-22).
##   HelpSheet.HelpButton  the "?" in the Screen header slot: an 88 px circle in a 96 px hit area, drawn as one Control; a 14 px TEAL_HI dot
##                     with a page-colour ring while this screen's sheet was never opened on this device (DeviceState.help_seen).
##                     Screen.setup() adds it to every screen that has a help entry (data/help_v1.json); Title, About and Game over
##                     have none. Tag help.button.
##   open(id)          the sheet (BottomSheet id "help", size L: at M the words on the screen sat below the fold): What you see, What to do, Good to know, the words
##                     on this screen as buttons that open the term in place (with Back), Got it and "Open the glossary". Opening it
##                     marks the screen seen (the dot clears) and raises open:help.
##   paused()          true while a help sheet is open: the Draft timer and the Match playback stand still (the result is decided
##                     before the playback, so a pause never changes it).
## The text is in i18n/en.json: help.<id>.title/see/do/know/terms, gl.<id>.name/def/where, gl.group.<group>, help.* labels.

const SHEET_ID := "help"

static var _data: Dictionary = {}
static var _gloss: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = DataLoader.load_json("res://data/help_v1.json")
		_data = d if d is Dictionary else {"screens": []}
	return _data


static func glossary() -> Dictionary:
	if _gloss.is_empty():
		var d = DataLoader.load_json("res://data/glossary_v1.json")
		_gloss = d if d is Dictionary else {"groups": {}}
	return _gloss


static func ids() -> Array:
	return (data().get("screens", []) as Array).duplicate()


static func has_help(id: String) -> bool:
	return id != "" and ids().has(id)


static func terms_of(id: String) -> Array:
	var raw := Strings.t("help.%s.terms" % id)
	var out: Array = []
	if raw.begins_with("[["):
		return out    # no terms line (Settings has none): Strings marks a missing key with [[ ]]
	for t in raw.split(",", false):
		if String(t).strip_edges() != "":
			out.append(String(t).strip_edges())
	return out


static func term_ids() -> Array:
	var out: Array = []
	var g: Dictionary = glossary().get("groups", {})
	for k in g:
		out.append_array(g[k])
	return out


static func device() -> DeviceState:
	return App.tutorial.device if App.tutorial != null and App.tutorial.device != null else DeviceState.new()


static func is_open() -> bool:
	return BottomSheet.is_open() and BottomSheet.current().sheet_id == SHEET_ID and not BottomSheet.current().is_closing


## The Draft timer and the Match clock stand still while this is true.
static func paused() -> bool:
	return is_open()


## Open the help sheet of `id` (the dot clears).
static func open(id: String) -> BottomSheet:
	if not has_help(id):
		return null
	device().help_mark(id)
	var sh := BottomSheet.open(Strings.t("help.%s.title" % id), _body.bind(id), _footer.bind(id), "L", SHEET_ID)    # L: at M the words sat below the fold
	if App.main != null and App.main.is_inside_tree():
		App.main.get_tree().call_group("help_buttons", "queue_redraw")    # a group, not a static list of nodes (crashed at exit)
	return sh


static func _block(c: Control, head_key: String, text: String) -> void:
	c.add_child(UI.label(Strings.t(head_key), UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	var l := UI.label(text, UI.S_BODY, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(l)


static func _body(c: Control, id: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.name = "HelpBody"
	c.add_child(box)
	_fill(box, id)


## The three blocks and the words (or, when a word was tapped, that term with Back).
static func _fill(box: VBoxContainer, id: String, term: String = "") -> void:
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()
	if term != "":
		box.add_child(UI.label(Strings.t("gl.%s.name" % term), UI.S_BIG, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, "Bold"))
		var d := UI.label(Strings.t("gl.%s.def" % term), UI.S_BODY, UI.TEXT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(d)
		var back := UI.button(Strings.t("common.back"), func(): _fill(box, id), "normal")
		UI.tag(back, "help.term.back")
		box.add_child(back)
		return
	_block(box, "help.see", Strings.t("help.%s.see" % id))
	_block(box, "help.do", Strings.t("help.%s.do" % id))
	_block(box, "help.know", Strings.t("help.%s.know" % id))
	var terms := terms_of(id)
	if terms.is_empty():
		return
	box.add_child(UI.label(Strings.t("help.words"), UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	for t in terms:
		var b := UI.button(Strings.t("gl.%s.name" % t), _fill.bind(box, id, String(t)), "normal")
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.add_theme_font_size_override("font_size", UI.S_SMALL)
		UI.tag(b, "help.term." + String(t))
		flow.add_child(b)
	box.add_child(flow)


static func _footer(f: Control, id: String) -> void:
	BottomSheet.footer_button(f, Strings.t("help.got_it"), func(): BottomSheet.current().close(), "primary", "help.got_it")
	# the glossary opens as a sheet in place (a Draft or a Match in progress is never left)
	BottomSheet.footer_button(f, Strings.t("help.glossary"), func(): ScreenGlossary.open_sheet(), "flat", "help.open_glossary")


## The "?" of a screen.
class HelpButton extends Control:
	var help_id := ""
	var draw_count := 0
	var _tr := TouchTrack.new()
	var _press_g := Vector2.ZERO
	var _down := false
	var _ops := CardKit.Ops.new()

	func _init(p_id: String = "") -> void:
		help_id = p_id
		custom_minimum_size = Vector2(UI.BTN_H, UI.BTN_H)
		size_flags_horizontal = Control.SIZE_SHRINK_END
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		UI.tag(self, "help.button", false)
		CompKit.mark_stateful(self)
		visibility_changed.connect(queue_redraw)
		add_to_group("help_buttons")
		_note()

	func seen() -> bool:
		return HelpSheet.device().help_seen(help_id)

	func _note() -> void:
		CompKit.set_cue(self, "?" + ("" if seen() else "+dot"))

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var c := size * 0.5
		var r := 44.0
		_ops.shape("disc", Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), UI.TEAL_HI if _down else UI.PANEL3)
		_ops.shape("disc", Rect2(c - Vector2(r - 2.0, r - 2.0), Vector2(r - 2.0, r - 2.0) * 2.0), UI.PANEL3.lightened(0.08) if _down else UI.PANEL2)
		_ops.text(UI.font("Bold"), UI.S_BIG, "?", 0.0, c.y, size.x, UI.TEAL_HI, 1)
		if not seen():
			_ops.shape("disc", Rect2(c + Vector2(r * 0.55, -r * 0.95), Vector2(18, 18)), UI.BG)
			_ops.shape("disc", Rect2(c + Vector2(r * 0.55 + 2.0, -r * 0.95 + 2.0), Vector2(14, 14)), UI.TEAL_HI)
		_ops.flush(self)
		_note()

	func _gui_input(event: InputEvent) -> void:
		match _tr.feed(event):
			"down":
				_press_g = get_global_transform_with_canvas() * _tr.press_pos
				_down = true
				queue_redraw()
				accept_event()
			"up":
				var g := get_global_transform_with_canvas() * _tr.pos
				_down = false
				queue_redraw()
				if g.distance_to(_press_g) <= TouchTrack.SLOP and Rect2(Vector2.ZERO, size).has_point(_tr.pos):
					press()
				accept_event()

	func press() -> void:
		CompKit.tap_event("help.button")
		HelpSheet.open(help_id)
		queue_redraw()
