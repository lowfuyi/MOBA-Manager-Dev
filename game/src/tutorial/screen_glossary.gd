class_name ScreenGlossary
extends Screen
## The glossary (TUTORIAL 5.3, build plan I-22): 49 terms in four groups (Players, Match and draft, League, Club and money), from
## data/glossary_v1.json and gl.<id>.name/def/where. A full screen from Settings (More tab): the group switch (tag gloss.groups)
## and the terms as one drawn list (tag gloss.terms); a tap on a term opens a sheet (id glossary_term) with its line, "Where to see
## it" (goes to that screen) and Back. From a help sheet the glossary opens as a SHEET instead (open_sheet: id glossary), with the
## term shown in place and Back, so a Draft or a Match in progress is never left.

const GROUP_ICONS := {"players": "tab_squad", "match": "pick", "league": "trophy", "club": "cash"}

var _group := "players"
var groups_bar: DraftKit.RoleBar
var terms: TermList


## The terms of a group as one drawn list: a row per term (name, a chevron). `on_term(id)` on a tap (S1 rule).
class TermList extends Control:
	const ROW_H := 96.0
	var ids: Array = []
	var on_term: Callable
	var draw_count := 0
	var _ops := CardKit.Ops.new()
	var _tr := TouchTrack.new()
	var _press := -1
	var _press_g := Vector2.ZERO

	func _init(p_on_term: Callable) -> void:
		on_term = p_on_term
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS
		resized.connect(queue_redraw)
		CompKit.set_cue(self, "words")

	func set_ids(p: Array) -> void:
		ids = p.duplicate()
		custom_minimum_size = Vector2(0, ROW_H * float(ids.size()))
		queue_redraw()

	func row_at(p: Vector2) -> int:
		if p.x < 0.0 or p.x > size.x or p.y < 0.0:
			return -1
		var i := int(p.y / ROW_H)
		return i if i < ids.size() else -1

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		for i in ids.size():
			var r := Rect2(0.0, float(i) * ROW_H + 4.0, size.x, ROW_H - 8.0)
			_ops.bg("card", r, UI.PANEL3 if i == _press else UI.PANEL2)
			_ops.text(UI.font("SemiBold"), UI.S_BODY, Strings.t("gl.%s.name" % String(ids[i])), 24.0, r.get_center().y, size.x - 80.0, UI.TEXT)
			_ops.icon("chevron_r", Rect2(size.x - 48.0, r.get_center().y - 14.0, 28.0, 28.0), UI.TEAL_HI)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped

	func _gui_input(event: InputEvent) -> void:
		match _tr.feed(event):
			"down":
				_press = row_at(_tr.press_pos)
				_press_g = get_global_transform_with_canvas() * _tr.press_pos
				queue_redraw()
			"up":
				var i := _press
				_press = -1
				queue_redraw()
				var g := get_global_transform_with_canvas() * _tr.pos
				if i >= 0 and g.distance_to(_press_g) <= TouchTrack.SLOP and row_at(_tr.pos) == i:
					press(i)

	func press(i: int) -> void:
		if i >= 0 and i < ids.size() and on_term.is_valid():
			on_term.call(String(ids[i]))


func _init(_from: String = "") -> void:
	super._init()


func tab_id() -> String:
	return "more"


func go_back() -> void:
	App.go(ScreenSettings.new())


func _ready() -> void:
	setup(Strings.t("gl.title"), go_back)
	body.add_theme_constant_override("separation", 12)
	groups_bar = group_bar(_set_group, _group)
	body.add_child(groups_bar)
	terms = TermList.new(_open_term)
	UI.tag(terms, "gloss.terms", false)
	body.add_child(terms)
	_set_group(_group)


static func open_screen() -> void:
	App.go(ScreenGlossary.new())


static func groups() -> Array:
	return (HelpSheet.glossary().get("groups", {}) as Dictionary).keys()


static func group_bar(cb: Callable, sel: String) -> DraftKit.RoleBar:
	var opts: Array = []
	for g in groups():
		opts.append({"id": g, "label": Strings.t("gl.group." + String(g)), "icon": GROUP_ICONS.get(g, "star")})
	return DraftKit.RoleBar.new(cb, "gloss.groups", opts, sel)


static func ids_in(group: String) -> Array:
	return ((HelpSheet.glossary().get("groups", {}) as Dictionary).get(group, []) as Array).duplicate()


func _set_group(g: Variant) -> void:
	_group = String(g)
	groups_bar.set_selected(_group)
	terms.set_ids(ids_in(_group))


func _open_term(id: String) -> void:
	BottomSheet.open(Strings.t("gl.%s.name" % id), _term_body.bind(id), _term_footer.bind(id), "S" if not UI.large else "M", "glossary_term")


func _term_body(c: Control, id: String) -> void:
	var l := UI.label(Strings.t("gl.%s.def" % id), UI.S_BODY, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(l)


func _term_footer(f: Control, id: String) -> void:
	var where := Strings.t("gl.%s.where" % id)
	BottomSheet.footer_button(f, Strings.t("gl.where"), func():
		BottomSheet.current().close()
		App.go(screen_for(where)), "primary", "gloss.where")
	BottomSheet.footer_button(f, Strings.t("common.back"), func(): BottomSheet.current().close(), "normal", "gloss.back")


## The screen a help id names ("Where to see it"). Screens that need a game in progress (Match day, Draft, Game Plan, Match,
## Report) send the player Home, where the next game starts.
static func screen_for(help_id: String) -> Control:
	match help_id:
		"squad", "player":
			return ScreenRoster.new("hub")
		"plan":
			return ScreenPlan.new()
		"training":
			return ScreenTraining.new()
		"chemistry":
			return ScreenChemistry.new()
		"practice":
			return ScreenPractice.new()
		"club":
			return ScreenClub.new()
		"standings":
			return ScreenStandings.new()
		"finance":
			return ScreenFinance.new()
		"freeagents", "negotiation":
			return ScreenFreeAgents.new("hub")
		"season":
			return ScreenStandings.new("history")
		"settings":
			return ScreenSettings.new()
	return ScreenHub.new()


# ---- the glossary as a sheet (from a help sheet) ----------------------------------------------------------------------------------

static func open_sheet() -> BottomSheet:
	return BottomSheet.open(Strings.t("gl.title"), _sheet_body, Callable(), "L", "glossary")


static func _sheet_body(c: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	c.add_child(box)
	_sheet_fill(box, "players", "")


static func _sheet_fill(box: VBoxContainer, group: String, term: String) -> void:
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()
	if term != "":
		box.add_child(UI.label(Strings.t("gl.%s.name" % term), UI.S_BIG, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, "Bold"))
		var d := UI.label(Strings.t("gl.%s.def" % term), UI.S_BODY, UI.TEXT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(d)
		box.add_child(UI.tag(UI.button(Strings.t("common.back"), func(): _sheet_fill(box, group, ""), "normal"), "gloss.back"))
		return
	box.add_child(group_bar(func(g: Variant): _sheet_fill(box, String(g), ""), group))
	var tl := TermList.new(func(id: String): _sheet_fill(box, group, id))
	tl.set_ids(ids_in(group))
	UI.tag(tl, "gloss.terms", false)
	box.add_child(tl)
