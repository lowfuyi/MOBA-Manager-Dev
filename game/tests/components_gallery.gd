extends Screen
## Components gallery (build plan I-07; tests only, never a player screen): every component of src/ui/components in every
## state, in sections that each fit about one phone screen, so one section is one screenshot and one perf measurement.
## Used by tests/check_ui_components.gd (build, fit, in-place, cue, tag checks) and tests/shots/shots_gallery.gd (pictures,
## node and draw-call numbers). Sample text comes from Strings keys (and the longest club name from the league data);
## the short state names printed above each sample are test annotations (ASCII), not game text.
## `items` maps a component kind to the nodes built, so a test can reach them: items["DepthCard"], items["Chip"], ...

const SECTIONS := ["cards", "headers", "chips", "icons", "segmented", "data", "list"]
const ROLES := ["top", "jg", "mid", "bot", "sup"]

var section := "cards"
var items: Dictionary = {}       # kind -> Array of nodes
var taps: Array = []             # what the samples reported (ids)
var long_club := "Northreach Corsairs"


func _init(p_section: String = "cards") -> void:
	super()    # Screen._init sets the full-rect anchors; a subclass _init with arguments does not run it by itself
	section = p_section


func _ready() -> void:
	if App.world != null:
		for id in App.world.club_ids:
			var nm: String = App.world.clubs[id]["name"]
			if nm.length() > long_club.length():
				long_club = nm
	setup("", Callable(), true)
	call("_build_" + section)


func _reg(kind: String, n: Node) -> Node:
	if not items.has(kind):
		items[kind] = []
	(items[kind] as Array).append(n)
	return n


func _cap(text: String) -> Label:
	return UI.label(text, UI.S_CAPTION, UI.DIM, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold")


func _note(id: Variant) -> void:
	taps.append(id)


# ---- cards ---------------------------------------------------------------------------------------------------

func _card_sample(grid: GridContainer, name: String, card: DepthCard) -> DepthCard:
	_reg("DepthCard", card)
	grid.add_child(card)
	card.content.add_child(UI.label(name, UI.S_HEAD, UI.TEXT))
	card.content.add_child(UI.label(Strings.t("squad.now_playing"), UI.S_SMALL, UI.TEXT2))
	return card


func _build_cards() -> void:
	body.add_child(_cap("DEPTH CARD: ELEVATION, SELECTED, INSET, DISABLED, PRESSED"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UI.GAP)
	grid.add_theme_constant_override("v_separation", UI.GAP)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	_card_sample(grid, "Flat", DepthCard.new(0, Color(0, 0, 0, 0), false, false, "gal.card.flat"))
	_card_sample(grid, "Flat, selected", DepthCard.new(0, Color(0, 0, 0, 0), true))
	_card_sample(grid, "Raised", DepthCard.new(1))
	_card_sample(grid, "Raised, selected", DepthCard.new(1, Color(0, 0, 0, 0), true))
	_card_sample(grid, "Overlay", DepthCard.new(2))
	_card_sample(grid, "Inset", DepthCard.new(0, Color(0, 0, 0, 0), false, false, "", UI.PAD_CARD, true))
	var dis := _card_sample(grid, "Disabled", DepthCard.new(0)) as DepthCard
	dis.set_disabled(true)
	var tap := _card_sample(grid, "Tappable", DepthCard.new(0, Color(0, 0, 0, 0), false, true, "gal.card.tap")) as DepthCard
	tap.pressed.connect(_note.bind("card"))
	var long_card := DepthCard.new(0)
	_reg("DepthCard", long_card)
	body.add_child(long_card)
	long_card.content.add_child(UI.label(long_club, UI.S_HEAD, UI.TEXT))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	long_card.content.add_child(row)
	row.add_child(_reg("Chip", Chip.new(Strings.t("fatigue.tired"), "warn")) as Chip)
	row.add_child(_reg("Chip", Chip.new(Strings.t("mood.hot"), "good")) as Chip)


# ---- headers ---------------------------------------------------------------------------------------------------

func _build_headers() -> void:
	var specs: Array = [
		["plain", Strings.t("squad.bench_h"), {}],
		["count", Strings.t("squad.bench_h"), {"count": 5}],
		["action", Strings.t("squad.bench_h"), {"count": 12, "action": Strings.t("home.see_all"), "tut_id": "gal.head.action"}],
		["long", Strings.t("standings.cut.after"), {"action": Strings.t("home.see_all")}],
	]
	for s in specs:
		body.add_child(_cap(String(s[0])))
		var h := SectionHeader.new(String(s[1]), s[2])
		h.action_pressed.connect(_note.bind("action"))
		body.add_child(_reg("SectionHeader", h) as SectionHeader)
	for open in [false, true]:
		body.add_child(_cap("expandable, " + ("open" if open else "closed")))
		var card := DepthCard.new(0)
		_reg("DepthCard", card)
		card.content.add_child(UI.label(Strings.t("help.home.see"), UI.S_BODY, UI.TEXT2))
		var h2 := SectionHeader.new(Strings.t("help.know"), {"expandable": true, "open": open, "content": card, "tut_id": "gal.head.open" if open else "gal.head.closed"})
		body.add_child(_reg("SectionHeader", h2) as SectionHeader)
		body.add_child(card)


# ---- chips and icon buttons ------------------------------------------------------------------------------------

func _build_chips() -> void:
	body.add_child(_cap("CHIP VARIANTS (EACH HAS ITS OWN ICON)"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	body.add_child(flow)
	var words := [["neutral", "role.short.mid"], ["good", "mood.hot"], ["bad", "fatigue.exhausted"], ["warn", "fatigue.tired"], ["accent", "squad.now_playing"]]
	for w in words:
		flow.add_child(_reg("Chip", Chip.new(Strings.t(String(w[1])), String(w[0]), "", "gal.chip." + String(w[0]))) as Chip)
	body.add_child(_cap("LONG TEXT, COUNT CHIP, ON A RAISED CARD"))
	var flow2 := HFlowContainer.new()
	flow2.add_theme_constant_override("h_separation", 10)
	flow2.add_theme_constant_override("v_separation", 10)
	body.add_child(flow2)
	flow2.add_child(_reg("Chip", Chip.new(long_club, "accent")) as Chip)
	flow2.add_child(_reg("Chip", Chip.new("12", "neutral", "none")) as Chip)
	var raised := DepthCard.new(1)
	_reg("DepthCard", raised)
	body.add_child(raised)
	var flow3 := HFlowContainer.new()
	flow3.add_theme_constant_override("h_separation", 10)
	raised.content.add_child(flow3)
	for w in words.slice(1, 4):
		flow3.add_child(_reg("Chip", Chip.new(Strings.t(String(w[1])), String(w[0]), "", "", true)) as Chip)
	body.add_child(_cap("ICON BUTTONS: NORMAL, ACTIVE, DISABLED"))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 16)
	row.add_theme_constant_override("v_separation", 8)
	body.add_child(row)
	var states := [["normal", "arrow_up", "common.back"], ["active", "star", "common.ok"], ["disabled", "lock", "common.cancel"], ["normal", "cross", "common.cancel"], ["normal", "chevron_right", "common.continue"], ["normal", "warn", "help.button"]]
	for i in states.size():
		var b := IconButton.new(String(states[i][1]), Strings.t(String(states[i][2])), _note.bind("icon%d" % i), "gal.icon.%d" % i)
		if i == 1:
			b.set_active(true)
		if i == 2:
			b.set_enabled(false)
		row.add_child(_reg("IconButton", b) as IconButton)


func _build_icons() -> void:
	body.add_child(_cap("ALL PLACEHOLDER ICONS"))
	var flow4 := HFlowContainer.new()
	flow4.add_theme_constant_override("h_separation", 12)
	flow4.add_theme_constant_override("v_separation", 12)
	body.add_child(flow4)
	for id in IconHook.IDS:
		var chip_like := _reg("DepthCard", DepthCard.new(0, Color(0, 0, 0, 0), false, false, "", 12)) as DepthCard
		chip_like.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var ic := _IconTile.new()
		ic.icon_id = id
		chip_like.content.add_child(ic)
		flow4.add_child(chip_like)


class _IconTile extends Control:
	var icon_id := ""

	func _init() -> void:
		custom_minimum_size = Vector2(48, 48)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		IconHook.draw(self, icon_id, Rect2(Vector2.ZERO, size), UI.TEXT)


# ---- segmented ----------------------------------------------------------------------------------------------------

func _build_segmented() -> void:
	body.add_child(_cap("THREE OPTIONS (EQUAL)"))
	var s3 := Segmented.new([Strings.t("standings.view.table"), Strings.t("standings.view.playoffs"), Strings.t("standings.view.history")], 0, func(_id: Variant) -> void: _note("seg3"), "auto", "gal.seg3")
	body.add_child(_reg("Segmented", s3) as Segmented)
	body.add_child(_cap("TWO OPTIONS, SECOND SELECTED"))
	var s2 := Segmented.new([Strings.t("standings.metric.points"), Strings.t("standings.metric.form")], 1)
	body.add_child(_reg("Segmented", s2) as Segmented)
	body.add_child(_cap("LABELS TOO LONG: STRIP, SELECTED SCROLLED IN VIEW"))
	var names: Array = [long_club, Strings.t("standings.metric.form"), Strings.t("standings.view.playoffs")]
	var s4 := Segmented.new(names, 2)
	body.add_child(_reg("Segmented", s4) as Segmented)
	body.add_child(_cap("FIVE STACKED (ICON OVER WORD), ONE LOCKED"))
	var opts: Array = []
	for i in ROLES.size():
		opts.append({"id": ROLES[i], "label": Strings.t("role.short." + ROLES[i]), "icon": ["chevron_up", "star", "dot", "arrow_down", "check"][i], "locked": i == 3})
	var s5 := Segmented.new(opts, "mid", func(_id: Variant) -> void: _note("roles"), "auto", "gal.seg5")
	body.add_child(_reg("Segmented", s5) as Segmented)
	body.add_child(_cap("FORCED STRIP (fit = scroll)"))
	var s6 := Segmented.new([Strings.t("standings.view.table"), Strings.t("standings.view.playoffs"), Strings.t("standings.view.history")], 0, Callable(), "scroll")
	body.add_child(_reg("Segmented", s6) as Segmented)


# ---- data: meters, hero stat, empty state -----------------------------------------------------------------------

func _build_data() -> void:
	body.add_child(_cap("EDGE METER: YOU RIGHT, THEM LEFT"))
	for v in [0.056, -0.123, 0.0, 0.20, -0.03]:
		body.add_child(_reg("EdgeMeter", EdgeMeter.new(v, 0.20, "gal.edge" if v == 0.056 else "")) as EdgeMeter)
	body.add_child(_cap("HERO STAT"))
	var hs := HeroStat.new(73.5, "%+.1f", Strings.t("help.home.see"), Strings.t("mood.hot"), Strings.t("fatigue.tired"), "gal.herostat")
	hs.set_value(73.5, false)
	body.add_child(_reg("HeroStat", hs) as HeroStat)
	body.add_child(_cap("EMPTY STATE"))
	var es := EmptyState.new(Strings.t("empty.history.h"), Strings.t("empty.history.b"), Strings.t("empty.history.btn"), _note.bind("empty"), "star", "gal.empty")
	body.add_child(_reg("EmptyState", es) as EmptyState)


# ---- list sync ----------------------------------------------------------------------------------------------------

func make_row(key: String) -> Control:
	var c := DepthCard.new(0, Color(0, 0, 0, 0), false, false, "", 16)
	c.content.add_child(UI.label(Strings.t("role.short." + key), UI.S_BODY, UI.TEXT))
	return c


func _build_list() -> void:
	body.add_child(_cap("LIST SYNC: ALL FIVE, THEN FILTERED TO MID AND BOT"))
	var all_box := VBoxContainer.new()
	all_box.add_theme_constant_override("separation", 8)
	body.add_child(all_box)
	ListSync.sync(all_box, ROLES, make_row)
	_reg("ListSync", all_box)
	body.add_child(_cap("FILTERED (THE OTHER THREE ARE HIDDEN, NOT FREED)"))
	var f_box := VBoxContainer.new()
	f_box.add_theme_constant_override("separation", 8)
	body.add_child(f_box)
	ListSync.sync(f_box, ROLES, make_row)
	ListSync.sync(f_box, ["bot", "mid"], make_row)
	_reg("ListSync", f_box)
