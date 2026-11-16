extends Screen
## Components gallery (build plan I-07; tests only, never a player screen): every component of src/ui/components in every
## state, in sections that each fit about one phone screen, so one section is one screenshot and one perf measurement.
## Used by tests/check_ui_components.gd (build, fit, in-place, cue, tag checks) and tests/shots/shots_gallery.gd (pictures,
## node and draw-call numbers). Sample text comes from Strings keys (and the longest club name from the league data);
## the short state names printed above each sample are test annotations (ASCII), not game text.
## `items` maps a component kind to the nodes built, so a test can reach them: items["DepthCard"], items["Chip"], ...

const SECTIONS := ["cards", "headers", "chips", "icons", "segmented", "data", "list", "carousel", "sheet", "players", "heroes", "lanes", "plan", "standings"]
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


# ---- carousel (I-08) ----------------------------------------------------------------------------------------------

const NAMES := ["Brikai", "Soldor", "Brammont", "Vexa", "Tolliver", "Quillan", "Marrow", "Jessamy", "Odrin", "Pell"]


## A display card for the carousel: name, a line, a chip, and (optionally) a real Button the carousel must make inert.
func car_card(idx: int, with_btn: bool = false, long_name: String = "") -> DepthCard:
	var c := DepthCard.new(0)
	var reg := idx < Carousel.MAX_CARDS    # a card beyond 8 is freed by the carousel, so the audits do not list it
	if reg:
		_reg("DepthCard", c)
	c.content.add_child(UI.label(long_name if long_name != "" else String(NAMES[idx % NAMES.size()]), UI.S_HEAD, UI.TEXT))
	c.content.add_child(UI.label(Strings.t("squad.now_playing"), UI.S_SMALL, UI.TEXT2))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	c.content.add_child(row)
	var chip := Chip.new(Strings.t("fatigue.tired") if idx % 2 == 0 else Strings.t("mood.hot"), "warn" if idx % 2 == 0 else "good")
	if reg:
		_reg("Chip", chip)
	row.add_child(chip)
	if with_btn:
		var b := UI.button(Strings.t("common.ok"), _note.bind("inner_button"))    # inert inside a carousel card: the card taps
		c.content.add_child(b)
	return c


func _car(p_cap: String, n: int, p_w: float, opts: Dictionary = {}) -> Carousel:
	body.add_child(_cap(p_cap))
	var cards: Array = []
	for i in n:
		cards.append(car_card(i, bool(opts.get("button", false)), String(opts.get("long", "")) if i == 0 else ""))
	var car := Carousel.new(p_w, cards, _note.bind("see_all"), String(opts.get("tut", "")), String(opts.get("empty", "")))
	car.card_tapped.connect(func(i: int) -> void: _note("card%d" % i))
	body.add_child(_reg("Carousel", car) as Carousel)
	return car


func _build_carousel() -> void:
	_car("CAROUSEL: 300 WIDE, 5 CARDS, DOTS, THE NEXT CARD PEEKS", 5, 300.0, {"tut": "gal.car", "button": true})
	_car("560 WIDE (UPCOMING GAMES), 2 CARDS, NO DOTS", 2, 560.0, {"long": long_club})
	_car("10 CARDS: THE ROW SHOWS 8 AND A SEE ALL TILE", 10, 300.0)
	var scrolled := _car("SCROLLED TO THE THIRD CARD", 6, 300.0)
	_scroll_later(scrolled, 2)
	_car("EMPTY", 0, 300.0, {"empty": Strings.t("empty.history.b")})


func _scroll_later(car: Carousel, i: int) -> void:
	for k in 3:
		await get_tree().process_frame
	if is_instance_valid(car):
		car.scroll_to_index(i, false)


# ---- sheet (I-08): a page with the buttons that open the real BottomSheet in each size ----------------------------------

func sheet_title(long: bool) -> String:
	if long:
		return Strings.t("draft.sheet.pick_for").format({"role": Strings.t("role.mid"), "name": long_club})
	return Strings.t("squad.bench_h")


## Opens the real sheet the way a screen would: `rows` cards of content, one primary action in the footer.
func open_sheet(sz: String, rows: int, long: bool = false) -> BottomSheet:
	var build := func(content: VBoxContainer) -> void:
		for i in rows:
			var c := DepthCard.new(0)
			c.content.add_child(UI.label(String(NAMES[i % NAMES.size()]), UI.S_BODY, UI.TEXT))
			c.content.add_child(UI.label(Strings.t("squad.now_playing"), UI.S_SMALL, UI.TEXT2))
			content.add_child(c)
	var foot := func(footer: VBoxContainer) -> void:
		BottomSheet.footer_button(footer, Strings.t("common.continue"), _note.bind("sheet_primary"), "primary", "gal.sheet.primary")
	return BottomSheet.open(sheet_title(long), build, foot, sz, "gal_" + sz.to_lower())


func _build_sheet() -> void:
	body.add_child(_cap("OPEN A SHEET: S FITS ITS CONTENT, M IS 60 PERCENT, L IS 85"))
	for spec in [["S", 1, false], ["M", 4, false], ["L", 9, false], ["M", 3, true]]:
		var label := "Sheet %s%s" % [spec[0], ", long title" if spec[2] else ""]
		var b := UI.button(label, func() -> void: open_sheet(String(spec[0]), int(spec[1]), bool(spec[2])), "normal")
		body.add_child(_reg("SheetButton", b) as Button)


# ---- cards (I-09): PlayerCard, HeroGrid, LaneBoard --------------------------------------------------------------------------

const LONG_PLAYER := "Marrowbrook"     # 11 characters, the longest name the cards must fit (the data's longest is 8)
const HERO_STATES := {"brannoch": "selected", "dunmarrow": "banned", "skarrow": "you", "hegwin": "them"}


func hero_rows() -> Array:
	var out: Array = []
	if App.world != null:
		out.append_array(App.world.heroes.values())    # the file order of heroes.json (brannoch first)
	return out


func _hero(id: String) -> Dictionary:
	return App.world.heroes[id] if App.world != null and App.world.heroes.has(id) else {"id": id, "name": id.capitalize(), "role_primary": "mid", "archetype": ""}


func _real_card(idx: int, variant: String, extra: Dictionary = {}) -> PlayerCard:
	var pid: String = App.world.club_players(App.world.club_ids[5])[idx]["id"]
	var o: Dictionary = PlayerCard.data_for(App.world, App.gs, pid)
	for k in extra:
		o[k] = extra[k]
	var c := PlayerCard.make(pid, variant, o)
	_reg("PlayerCard", c)
	return c


func _long_chips() -> Array:
	return [{"text": Strings.t("fatigue.tired"), "variant": "warn", "icon": "fatigue"}, {"text": Strings.t("contract.final"), "variant": "warn", "icon": "contract"},
		{"text": Strings.t("mood.cold"), "variant": "bad", "icon": "form"}, {"text": Strings.t("mood.happy"), "variant": "good", "icon": "morale"}]


func _build_players() -> void:
	body.add_child(_cap("TALL: REAL PLAYERS, STARTER, SELECTED, 11-LETTER NAME, DISABLED"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UI.GAP)
	grid.add_theme_constant_override("v_separation", UI.GAP)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	grid.add_child(_real_card(0, "tall", {"tut_id": "gal.player.tall"}))
	grid.add_child(_real_card(1, "tall", {"starter": true}))
	grid.add_child(_real_card(2, "tall", {"selected": true}))
	var long := PlayerCard.make("p900", "tall", {"name": LONG_PLAYER, "role": "sup", "age": 24, "rating": 83, "chips": _long_chips(), "starter": true})
	_reg("PlayerCard", long)
	grid.add_child(long)
	var dis := PlayerCard.make("p901", "tall", {"name": "Ashjin", "role": "top", "age": 19, "rating": 47, "disabled": true})
	_reg("PlayerCard", dis)
	grid.add_child(dis)
	grid.add_child(_real_card(3, "tall"))
	body.add_child(_cap("ROW: PICKER AND REPORT"))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	body.add_child(rows)
	rows.add_child(_real_card(4, "row"))
	var rlong := PlayerCard.make("p902", "row", {"name": LONG_PLAYER, "role": "jg", "age": 31, "rating": 76, "chips": _long_chips(), "selected": true})
	_reg("PlayerCard", rlong)
	rows.add_child(rlong)
	body.add_child(_cap("TOKEN (NAMES ABOVE FOR TOP AND BOT) AND MINI"))
	var map := Control.new()
	map.custom_minimum_size = Vector2(0, 420)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(map)
	var specs: Array = [["top", "Ashjin", 0.06, 0.0, "above", "down"], ["jg", "Brammont", 0.24, 1.0, "below", ""], ["mid", LONG_PLAYER, 0.5, 0.0, "below", "up"],
			["bot", "Soldor", 0.94, 0.0, "above", ""], ["sup", "Vexa", 0.76, 1.0, "below", ""]]
	for sp in specs:
		var t := PlayerCard.make("pt_" + String(sp[0]), "token", {"name": sp[1], "role": sp[0], "rating": 71, "name_side": sp[4], "status": sp[5], "tut_id": "gal.token." + String(sp[0]) if sp[0] == "mid" else ""})
		_reg("PlayerCard", t)
		map.add_child(t)
		t.set_meta("frac", Vector2(float(sp[2]), float(sp[3])))
	var place := func() -> void:    # the tokens stay inside the map whatever its width (never from 720)
		for t in map.get_children():
			var fr: Vector2 = t.get_meta("frac")
			t.position = Vector2(fr.x * (map.size.x - 96.0), 80.0 + fr.y * (map.size.y - 96.0 - 160.0))
	map.resized.connect(place)
	place.call()
	var minis := HBoxContainer.new()
	minis.add_theme_constant_override("separation", 12)
	body.add_child(minis)
	for r in ROLES:
		var m := PlayerCard.make("pm_" + r, "mini", {"name": "Quillan", "role": r})
		_reg("PlayerCard", m)
		minis.add_child(m)
	body.add_child(_cap("IN A CAROUSEL: DISPLAY CARDS, THE CAROUSEL TAPS"))
	var cards: Array = []
	for i in 4:
		var c := PlayerCard.make("pc%d" % i, "tall", {"name": String(NAMES[i]), "role": ROLES[i % 5], "age": 20 + i, "rating": 60 + i * 4, "chips": [] if i % 2 == 0 else _long_chips().slice(0, 1)})
		_reg("PlayerCard", c)
		cards.append(c)
	var car := Carousel.new(300.0, cards, Callable(), "gal.pcar")
	car.card_tapped.connect(func(i: int) -> void: _note("pcard%d" % i))
	body.add_child(_reg("Carousel", car) as Carousel)


class _HeroPreview extends Control:
	var hero: Dictionary
	var state: Variant

	func _init(h: Dictionary, st: Variant) -> void:
		hero = h
		state = st
		custom_minimum_size = Vector2(216, HeroCard.H)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		HeroCard.draw(self, Rect2(Vector2.ZERO, custom_minimum_size), hero, state)


func _build_heroes() -> void:
	body.add_child(_cap("ROLE FILTER (24 PX WORDS) AND THE 40-HERO GRID, ONE CONTROL"))
	var seg := HeroGrid.role_filter(Callable(), "gal.hero.filter")
	var fixed := Control.new()    # the filter sits in the fixed area above the grid, so it gets the whole 672 / 578 px, not the scrolled page's 664 / 570
	fixed.custom_minimum_size = Vector2(UI.canvas_w() - 48.0, UI.BTN_H)
	fixed.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	seg.set_anchors_preset(Control.PRESET_FULL_RECT)
	fixed.add_child(seg)
	body.add_child(fixed)
	_reg("Segmented", seg)
	var grid := HeroGrid.new("gal.hero.grid")
	grid.set_heroes(hero_rows())
	var i := 0
	for id in App.world.heroes.keys():
		var st := {"s": HERO_STATES.get(id, "available"), "arrow": ["up", "down", "flat", ""][i % 4], "delta": ["+1.6", "-1.6", "0.0", ""][i % 4], "num": "%d" % (46 + (i * 7) % 50), "rec": i == 5}
		grid.set_state(id, st)
		i += 1
	grid.hero_tapped.connect(func(id: String) -> void:
		_note("hero:" + id)
		grid.set_selected(id))
	seg.changed.connect(func(role: Variant) -> void: grid.set_filter(String(role)))
	body.add_child(_reg("HeroGrid", grid) as HeroGrid)
	body.add_child(_cap("ONE CARD, ALL PASSES (THE SHEET PREVIEW): AVAILABLE, BANNED, YOU, THEM"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	body.add_child(flow)
	for st in ["available", "banned", {"s": "you", "num": "82"}, {"s": "them", "arrow": "up", "delta": "+2.0", "num": "75"}]:
		var pv := _HeroPreview.new(_hero("gravenstone"), st)
		_reg("HeroPreview", pv)
		flow.add_child(pv)


func _build_lanes() -> void:
	body.add_child(_cap("LANE BOARD, COMPACT: TWO FILLED, ONE TARGET, TWO OPEN, TWO BANS EACH"))
	var board := LaneBoard.new(true, "gal.lane.board")
	_fill_board(board)
	body.add_child(_reg("LaneBoard", board) as LaneBoard)
	body.add_child(_cap("FULL ROWS, LONG NAMES (11 LETTERS), A BANNED SLOT"))
	var full := LaneBoard.new(false)
	_fill_board(full)
	full.set_slot("top", "them", {"state": "filled", "hero": _hero("gravenstone"), "player": LONG_PLAYER})
	full.set_slot("sup", "you", {"state": "banned", "hero": _hero("tanglewick"), "player": "Vexa"})
	body.add_child(_reg("LaneBoard", full) as LaneBoard)


func _fill_board(b: LaneBoard) -> void:
	b.set_slot("top", "you", {"state": "filled", "hero": _hero("brannoch"), "player": "Ashjin"})
	b.set_slot("top", "them", {"state": "filled", "hero": _hero("dunmarrow"), "player": "Brikai"})
	b.set_slot("jg", "you", {"state": "empty", "player": "Brammont"})
	b.set_slot("jg", "them", {"state": "empty", "player": "Tolliver"})
	b.set_slot("mid", "you", {"state": "empty", "player": LONG_PLAYER})
	b.set_slot("mid", "them", {"state": "empty", "player": "Quillan"})
	b.set_slot("bot", "you", {"state": "empty", "player": "Soldor"})
	b.set_slot("bot", "them", {"state": "empty", "player": "Marrow"})
	b.set_slot("sup", "you", {"state": "empty", "player": "Vexa"})
	b.set_slot("sup", "them", {"state": "empty", "player": "Pell"})
	b.set_target("mid", "you")
	b.set_bans("you", [_hero("skarrow"), _hero("hegwin")])
	b.set_bans("them", [_hero("ottomere"), _hero("gravenstone")])


# ---- plan (I-10): PhaseStrip and DetentTrack ----------------------------------------------------------------------------------

func _strip(p_cap: String, phases: Array, selected: String, vertical: bool = false, tut: String = "") -> PhaseStrip:
	body.add_child(_cap(p_cap))
	var st := PhaseStrip.new(phases, selected, func(id: String) -> void: _note("phase:" + id), vertical, tut)
	if vertical:
		var row := HBoxContainer.new()
		row.add_child(st)
		body.add_child(row)
	else:
		body.add_child(st)
	_reg("PhaseStrip", st)
	return st


func _track(control_id: String, v: int, tut: String = "") -> DetentTrack:
	var t := DetentTrack.new(control_id, v, func(cid: String, val: int) -> void: _note("track:%s:%d" % [cid, val]), {}, tut)
	_reg("DetentTrack", t)
	return t


func _build_plan() -> void:
	var lead := func(n: int, m: int) -> String: return Strings.f("gp.lead", {"n": n, "m": m})
	var a := _strip("PHASE STRIP: EARLY SELECTED, LEAD CAPTIONS, A PIP PER CONTROL THAT ACTS", PhaseStrip.default_phases(), "early", false, "gal.phase")
	a.set_caption("early", lead.call(2, 4))
	a.set_caption("mid", lead.call(0, 2))
	a.set_caption("late", lead.call(1, 2))
	var b := _strip("A TRIGGER PLAN: EARLY LOCKED (STILL TAPPABLE), OVERALL SELECTED", PhaseStrip.default_phases(), "overall")
	b.set_locked("early", true)
	b.set_caption("early", Strings.t("gp.trigger_locked"))
	b.set_caption("mid", lead.call(0, 2))
	b.set_caption("late", lead.call(1, 2))
	var v := _strip("VERTICAL (THE REPORT STORY): RESULTS AS A TICK OR A CROSS, MID SELECTED", ["early", "mid", "late"], "mid", true, "gal.phasev")
	v.set_result("early", "win")
	v.set_result("mid", "lose")
	v.set_result("late", "win")
	body.add_child(_cap("DETENT TRACK: BALANCED, A HALF STEP, A FULL STEP (EACH SHOWS ITS PHASES)"))
	var card := DepthCard.new(1)
	body.add_child(card)
	card.content.add_theme_constant_override("separation", 12)
	card.content.add_child(_track("g", 0, "gal.track"))
	card.content.add_child(_track("t", -50))
	card.content.add_child(_track("l", 100))
	body.add_child(_cap("INERT: NO EFFECT IN THIS PLAN (LOCK, HOLLOW THUMB, WORDS), PARTIAL NOTE, DISABLED"))
	var card2 := DepthCard.new(1)
	body.add_child(card2)
	card2.content.add_theme_constant_override("separation", 12)
	var inert := _track("a", 50)
	inert.set_inert("full")
	card2.content.add_child(inert)
	var partial := _track("s", -100)
	partial.set_inert("partial")
	card2.content.add_child(partial)
	var dis := _track("r", 50)
	dis.set_disabled(true)
	card2.content.add_child(dis)
	body.add_child(_cap("LONGEST EFFECT LINE AT THE FAR END"))
	var card3 := DepthCard.new(1)
	body.add_child(card3)
	card3.content.add_child(_track("m", -100))


# ---- standings (I-10): Podium and RankRow -------------------------------------------------------------------------------------

func _club_id_named(nm: String) -> String:
	if App.world != null:
		for id in App.world.club_ids:
			if String(App.world.clubs[id]["name"]) == nm:
				return String(id)
	return "club_long"


func _rows(n: int, first_rank: int = 1, own_rank: int = -1) -> Array:
	var out: Array = []
	var ids: Array = App.world.club_ids if App.world != null else []
	for i in n:
		var cid := String(ids[(i + first_rank - 1) % maxi(1, ids.size())]) if not ids.is_empty() else "club%d" % i
		var nm := String(App.world.clubs[cid]["name"]) if not ids.is_empty() else "Club %d" % i
		var rank := first_rank + i
		out.append({"rank": rank, "club": cid, "name": nm, "main": str(maxi(0, 30 - rank * 3)), "sub": "%d-%d" % [maxi(0, 10 - rank), rank - 1], "own": rank == own_rank})
	return out


func _build_standings() -> void:
	var longid := _club_id_named(long_club)
	body.add_child(_cap("PODIUM: 2ND, 1ST, 3RD (YOURS HAS THE PILL AND THE OUTLINE)"))
	var pod_rows := _rows(3, 1, 2)
	body.add_child(_reg("Podium", Podium.new(pod_rows, "gal.podium")) as Podium)
	body.add_child(_cap("THREE EQUAL CLUBS, ALL THREE NAMES 19 CHARACTERS"))
	var eq: Array = []
	for i in 3:
		eq.append({"rank": i + 1, "club": longid, "name": long_club, "main": "3", "sub": "1-0", "own": false})
	body.add_child(_reg("Podium", Podium.new(eq)) as Podium)
	body.add_child(_cap("RANK ROWS 4 TO 10: OWN ROW, THE PLAYOFF LINE AFTER 4"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	body.add_child(col)
	var rs := _rows(7, 4, 9)
	for i in rs.size():
		var row := RankRow.new(rs[i], "gal.rank.own" if bool(rs[i]["own"]) else "")
		_reg("RankRow", row)
		col.add_child(row)
		if i == 0:
			col.add_child(_reg("RankDivider", RankRow.divider(Strings.t("standings.playoff_line"))) as Control)
	body.add_child(_cap("19-CHARACTER NAME ON YOUR ROW, FORM RATING, 3 DIGITS, A PINNED ROW WITH A SENTENCE"))
	var col2 := VBoxContainer.new()
	body.add_child(col2)
	col2.add_child(_reg("RankRow", RankRow.new({"rank": 9, "club": longid, "name": long_club, "main": "1523", "sub": "0-1", "own": true})) as RankRow)
	col2.add_child(_reg("RankRow", RankRow.new({"rank": 10, "club": longid, "name": long_club, "main": "111", "sub": "0-1"})) as RankRow)
	col2.add_child(_reg("RankRow", RankRow.new({"rank": 11, "club": longid, "name": "Pinehollow Owls", "main": "888", "sub": "0-2"})) as RankRow)
	col2.add_child(_reg("RankRow", RankRow.new({"rank": 9, "club": longid, "name": long_club, "own": true, "note": Strings.f("standings.pin.out", {"n": 3}) + ". " + Strings.t("standings.cut.after")})) as RankRow)

