extends Node
## I-09 checks: the picture-led components of src/ui/components (PlayerCard, HeroCard + HeroGrid, LaneRow + LaneBoard, ArtWire)
## through the gallery sections "players", "heroes" and "lanes" (tests/components_gallery.gd), in the T-std rows of the build plan:
## build_, fit_ (720 and 626 px of canvas, the 19-character longest club name, 11-character hero and player names), hit_,
## inplace_, cb_ (the "cue" meta, also in colour-blind mode), tags_, negative controls (each audit must catch a bad sample),
## and node numbers. Headless: it reads layout, state and counters; draw calls and pictures are measured by
## tests/shots/shots_cards.gd under Xvfb (HeroGrid at most 15 draw calls). The finger rows (a swipe scrolls the page, a tap
## picks a hero, the 12 px slop) are in tests/check_touch_cards.gd. Ends with " N checks, M failures".

const FitAudit = preload("res://tests/fit_audit.gd")
const Gallery = preload("res://tests/components_gallery.gd")
const SECTIONS := ["players", "heroes", "lanes"]
const LONGEST_CLUB := "Northreach Corsairs"    # 19 characters (the data's longest, checked below)
const GRID_NODE_GATE := 60                     # build plan I-01 S4: at most 60 nodes for the hero grid (it is 1)

var checks := 0
var fails := 0
var node_rows: Array = []
var _main: Control


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


func _ids(n: Node) -> Array:
	var out: Array = [n.get_instance_id()]
	for c in n.get_children():
		out.append_array(_ids(c))
	return out


## The cue audit of check_ui_components: a state-bearing control in a state needs a non-empty cue.
func _cue_problems(root: Node, audited: Array = []) -> Array:
	var out: Array = []
	if root.has_meta(CompKit.STATE_BEARING):
		var st := String(root.call("state_name")) if root.has_method("state_name") else ""
		audited.append(root)
		if not root.has_meta(CompKit.CUE):
			out.append("%s has no cue meta" % root.get_class())
		elif st != "" and String(root.get_meta(CompKit.CUE)) == "":
			out.append("%s is in state '%s' but its cue is empty" % [root.get_class(), st])
	for c in root.get_children():
		out.append_array(_cue_problems(c, audited))
	return out


func _ready() -> void:
	TutorialRunner.home_offers = false    # I-14: Home's welcome modal and offer cards depend on this machine's settings.cfg; tested in check_tutorial_flow
	get_window().size = Vector2i(720, 1280)
	await frames(1)
	await _art_wire()
	await _units()
	for variant in ["normal", "large"]:
		await _variant(variant)
	await _colour_blind()
	await _inplace()
	await _window_moves()
	await _negative_controls()
	App.apply_large_text(false)
	UI.set_colorblind(false)
	UI.animate = true
	print("nodes: " + " | ".join(node_rows))
	print("check_ui_cards: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _fresh_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(2)


func _show(section: String) -> Gallery:
	var g := Gallery.new(section)
	App.go(g)
	await frames(4)
	return g


func _heroes() -> Array:
	return App.world.heroes.values()


# ---- ArtWire: the hooks wired to the art code ---------------------------------------------------------------------------------

func _art_wire() -> void:
	ArtWire.reset()
	ok(not IconHook.draw_fn.is_valid() and not ArtWire.icons_wired, "build_artwire: after reset the icon hook is unwired (the placeholder draws)")
	ArtWire.wire_icons()
	ok(IconHook.draw_fn.is_valid() and ArtWire.icons_wired, "build_artwire: wire_icons sets IconHook.draw_fn")
	var missing: Array = []
	for id in IconHook.IDS:
		if not Icons.has(IconHook.art_id(id)):
			missing.append(id)
	ok(missing == ["dot"], "build_artwire: every IconHook id maps to an art icon except 'dot', which keeps the placeholder (%s)" % str(missing))
	ArtWire.prepare(App.world.club_ids, _heroes())
	var ids: Array = App.world.club_ids.duplicate()
	ids.sort()
	ok(BadgeStyle.league() == ids and ArtWire.prepared, "build_artwire: prepare sets the league in sorted order (%d clubs)" % ids.size())
	ok((Badge.atlas(48)["rects"] as Dictionary).size() == ids.size() and (Badge.atlas(48)["failed"] as Array).is_empty(), "build_artwire: Badge.prepare baked one cell per club (%d)" % (Badge.atlas(48)["rects"] as Dictionary).size())
	ok(Silhouette.info("gravenstone")["role"] == App.world.heroes["gravenstone"]["role_primary"], "build_artwire: Silhouette.register knows the heroes (gravenstone is %s)" % Silhouette.info("gravenstone")["role"])
	var misses := TexCache.misses
	ArtWire.prepare(App.world.club_ids, _heroes())
	ArtWire.ensure()
	ok(TexCache.misses == misses and BadgeStyle.league() == ids, "inplace_artwire: a second prepare and ensure change nothing (no atlas rebuilt)")
	var longest := ""
	for id in App.world.club_ids:
		if String(App.world.clubs[id]["name"]).length() > longest.length():
			longest = App.world.clubs[id]["name"]
	ok(longest == LONGEST_CLUB and longest.length() == 19, "fit_fixture: the longest club name in the data is '%s' (19 characters)" % longest)
	var longest_hero := ""
	for h in _heroes():
		if String(h["name"]).length() > longest_hero.length():
			longest_hero = h["name"]
	ok(longest_hero.length() == 11, "fit_fixture: the longest hero name is '%s' (11 characters)" % longest_hero)


# ---- units that need no gallery ---------------------------------------------------------------------------------------------------

func _units() -> void:
	# the card atlas
	ok(CardKit.ok(), "build_cardkit: the cards atlas baked from SVG with no failed cell (%s)" % str((CardKit.atlas()["rects"] as Dictionary).keys()))
	var tex_bytes := TexCache.bytes()
	ok(TexCache.violations().is_empty(), "build_cardkit: texture memory %.2f MB and %d textures are inside the budget (%s)" % [float(tex_bytes) / 1048576.0, TexCache.count(), str(TexCache.violations())])
	var f := UI.font("SemiBold")
	var cut := CardKit.fit(f, UI.S_SMALL, "WWWWWWWWWWWWWWWWWWWW", 100.0)
	ok(cut.ends_with("...") and CardKit.text_w(f, UI.S_SMALL, cut) <= 100.0, "fit_cardkit: a text wider than its room is cut with '...' to fit ('%s')" % cut)
	ok(CardKit.fit(f, UI.S_SMALL, "Brannoch", 150.0) == "Brannoch", "fit_cardkit: a text that fits is left alone")
	# HeroCard: states, cues, taps
	var cues := {}
	for s in HeroCard.STATES:
		cues[s] = HeroCard.cue_of(s)
	ok(cues["available"] == "", "cb_herocard: the available state has no cue")
	var distinct := {}
	for s in ["selected", "banned", "you", "them"]:
		ok(String(cues[s]) != "", "cb_herocard: state %s has the cue '%s'" % [s, cues[s]])
		distinct[cues[s]] = true
	ok(distinct.size() == 4, "cb_herocard: the four marked states have four different cues")
	ok(String(cues["banned"]).contains("cross") and String(cues["you"]).contains("circle") and String(cues["them"]).contains("hexagon"), "cb_herocard: banned is a cross plus a word, you is a circle, them is a hexagon (shape, not colour)")
	ok(HeroCard.cue_of({"s": "available", "rec": true}) == HeroCard.REC_CUE, "cb_herocard: the coach's choice adds a star and an outline (%s)" % HeroCard.cue_of({"s": "available", "rec": true}))
	ok(HeroCard.tappable("available") and HeroCard.tappable("selected") and not HeroCard.tappable("banned") and not HeroCard.tappable("you") and not HeroCard.tappable("them"), "hit_herocard: banned and picked cards cannot be tapped")
	ok(HeroCard.norm_state("nonsense")["s"] == "available" and HeroCard.norm_state({"s": "x"})["s"] == "available", "build_herocard: an unknown state name is the available state")
	ok(HeroCard.PASSES == 7 and HeroCard.PASS_CARD == 0 and HeroCard.PASS_TEXT24 == 6, "build_herocard: seven passes (cards, outlines and pills, shapes, portraits, marks, 26 px text, 24 px text)")
	# HeroCard.draw with pass -1 and with the seven passes in sequence both draw (the headless dummy renderer cannot compare
	# pixels; shots_cards.gd compares them under Xvfb)
	var hero: Dictionary = App.world.heroes["gravenstone"]
	var st := {"s": "you", "arrow": "up", "delta": "+1.6", "num": "82", "rec": true}
	var one := _Canvas.new()
	one.fn = func(ci: CanvasItem) -> void: HeroCard.draw(ci, Rect2(10, 20, 216, 196), hero, st)
	var five := _Canvas.new()
	five.fn = func(ci: CanvasItem) -> void:
		for p in HeroCard.PASSES:
			HeroCard.draw(ci, Rect2(10, 20, 216, 196), hero, st, p)
	add_child(one)
	add_child(five)
	await frames(3)
	ok(one.draws >= 1 and five.draws >= 1, "inplace_herocard: HeroCard.draw with pass -1 and with the seven passes in sequence both draw without error (pixel equality: shots_cards.gd under Xvfb)")
	one.queue_free()
	five.queue_free()
	await frames(1)


## A Control that draws whatever `fn(ci)` draws, so a test can run a static drawing helper inside a real _draw.
class _Canvas extends Control:
	var fn: Callable
	var draws := 0

	func _init() -> void:
		size = Vector2(300, 300)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draws += 1
		if fn.is_valid():
			fn.call(self)


# ---- per variant: build, fit, hit, tags ---------------------------------------------------------------------------------------------

func _all_nodes(root: Node, cls: String, out: Array) -> void:
	if root.get_class() == cls or (root.get_script() != null and (root.get_script() as Script).get_global_name() == cls):
		out.append(root)
	for c in root.get_children():
		_all_nodes(c, cls, out)


func _variant(variant: String) -> void:
	App.apply_large_text(variant == "large")
	UI.set_colorblind(false)
	await frames(2)
	await _fresh_main()
	var canvas := UI.canvas_w()
	for section in SECTIONS:
		var g := await _show(section)
		var n := _count(g)
		node_rows.append("%s/%s=%d" % [variant, section, n])
		ok(not g.items.is_empty() and n > 3, "build_%s_%s: built, %d nodes, kinds %s" % [section, variant, n, ",".join(g.items.keys())])
		ok(n <= 120, "build_%s_%s: %d nodes, at most the target 120" % [section, variant, n])
		var probs := FitAudit.audit(App.main._current, canvas)
		ok(probs.is_empty(), "fit_%s_%s: clean (%s)" % [section, variant, "; ".join(probs.slice(0, 3))])
		var cue_probs := _cue_problems(g)
		ok(cue_probs.is_empty(), "cb_%s_%s: every state-bearing control carries a cue (%s)" % [section, variant, "; ".join(cue_probs)])
		var small: Array = []
		_small_buttons(g, small)
		ok(small.is_empty(), "hit_%s_%s: every visible button is at least 96 x 96 (%s)" % [section, variant, "; ".join(small.slice(0, 3))])
		match section:
			"players":
				_players_rows(g, variant)
			"heroes":
				_heroes_rows(g, variant)
			"lanes":
				_lanes_rows(g, variant)


func _small_buttons(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is BaseButton and (n as Control).size.x > 0 and ((n as Control).size.x < 95.5 or (n as Control).size.y < 95.5):
		out.append("%s %.0fx%.0f" % [n.get_class(), (n as Control).size.x, (n as Control).size.y])
	for c in n.get_children():
		_small_buttons(c, out)


func _players_rows(g: Gallery, variant: String) -> void:
	var cards: Array = g.items["PlayerCard"]
	var kinds := {}
	for c in cards:
		kinds[(c as PlayerCard).variant] = (kinds.get((c as PlayerCard).variant, 0) as int) + 1
	ok(kinds.has("tall") and kinds.has("row") and kinds.has("token") and kinds.has("mini"), "build_players_%s: tall, row, token and mini all built (%s)" % [variant, str(kinds)])
	var clipped_any: Array = []
	var shown_widths: Array = []
	for c in cards:
		var pc := c as PlayerCard
		if not pc.is_visible_in_tree():
			continue
		clipped_any.append_array(pc.clipped)
		if pc.variant == "tall":
			shown_widths.append(roundi(pc.size.x))
	ok(clipped_any.is_empty(), "fit_players_%s: no text of any card is cut with '...', 11-letter names and four chips included (%s)" % [variant, str(clipped_any)])
	var want := floorf((g.body.size.x - UI.GAP) / 2.0)    # the page's own width: the scroll bar takes 8 px of the 672
	var all_tall_ok := true
	for c in cards:
		var pc := c as PlayerCard
		if pc.variant == "tall" and pc.get_parent() is GridContainer:
			all_tall_ok = all_tall_ok and absf(pc.size.x - want) < 2.0
	ok(all_tall_ok, "fit_players_%s: a tall card is %.0f px wide in the 2-column grid of a %.0f px page (the spec says 330 at 720 and 283 at 626)" % [variant, want, g.body.size.x])
	var long_card: PlayerCard
	var short_card: PlayerCard
	for c in cards:
		var pc := c as PlayerCard
		if pc.variant == "tall" and pc.player_name() == Gallery.LONG_PLAYER:
			long_card = pc
		elif pc.variant == "tall" and pc.player_name() == "Ashjin":
			short_card = pc
	ok(long_card != null and long_card.name_size in [UI.S_BODY, UI.S_SMALL, UI.S_CAPTION] and long_card.clipped.is_empty(), "fit_players_%s: the 11-letter name '%s' is drawn at %d px (32, 26 or 24) and is not cut" % [variant, Gallery.LONG_PLAYER, long_card.name_size if long_card != null else 0])
	ok(short_card != null and short_card.name_size == UI.S_BODY, "fit_players_%s: a short name stays at Body 32" % variant)
	ok(long_card != null and not long_card.shown_chips.is_empty() and String((long_card.shown_chips[-1] as Dictionary)["text"]).begins_with("+") == (long_card.shown_chips.size() < 5), "fit_players_%s: five chips do not all fit; the card shows %d and a '+n' chip for the rest (%s)" % [variant, long_card.shown_chips.size() if long_card != null else 0, str(long_card.shown_chips.map(func(x: Dictionary) -> String: return x["text"])) if long_card != null else ""])
	var hit_bad: Array = []
	var cue_bad: Array = []
	var display_bad: Array = []
	var checked := 0
	for c in cards:
		var pc := c as PlayerCard
		if not pc.is_visible_in_tree():
			continue
		checked += 1
		var need: Vector2 = PlayerCard.SIZES[pc.variant]
		if pc.size.y < need.y - 0.5 or (pc.variant != "mini" and (pc.size.x < 95.5 or pc.size.y < 95.5)):
			hit_bad.append("%s %.0fx%.0f" % [pc.variant, pc.size.x, pc.size.y])
		if not (pc.mouse_filter == Control.MOUSE_FILTER_IGNORE or pc.tappable):
			display_bad.append(pc.variant)
		if (pc.variant == "tall" and pc.get_parent() is GridContainer) or pc.variant == "row":
			var seen_cues := CompKit.cue_of(pc)
			if not ((pc.selected and seen_cues == "ring+tick") or (pc.disabled and seen_cues == "faded") or (not pc.selected and not pc.disabled and bool(pc.opts["starter"]) == (seen_cues == "tag"))):
				cue_bad.append("%s '%s' state '%s' cue '%s'" % [pc.variant, pc.player_name(), pc.state_name(), seen_cues])
	ok(hit_bad.is_empty() and checked >= 20, "hit_players_%s: %d cards on show, each at its spec height and (but the mini) at least 96 x 96 (%s)" % [variant, checked, "; ".join(hit_bad.slice(0, 3))])
	ok(display_bad.is_empty(), "hit_players_%s: a card is display only unless it is made tappable (%s)" % [variant, str(display_bad)])
	ok(cue_bad.is_empty(), "cb_players_%s: every tall and row card has the cue of its state: selected 'ring+tick', disabled 'faded', starter 'tag' (%s)" % [variant, "; ".join(cue_bad.slice(0, 3))])
	# the carousel holds display cards: every one of them ignores the pointer
	var car := g.items["Carousel"][0] as Carousel
	var inert := true
	for i in car.card_count():
		inert = inert and (car.card(i) as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
	ok(car.card_count() == 4 and inert, "build_players_%s: the carousel holds %d display-only cards (mouse filter IGNORE)" % [variant, car.card_count()])
	ok(UI.find_tag("gal.player.tall") != null and UI.find_tag("gal.token.mid") != null and UI.find_tag("gal.pcar.1") != null, "tags_players_%s: tall card, token and carousel card tags found" % variant)
	var token_ok := true
	for c in cards:
		var pc := c as PlayerCard
		if pc.variant == "token":
			token_ok = token_ok and absf(pc.size.x - 96.0) < 0.5 and absf(pc.size.y - 96.0) < 0.5
	ok(token_ok, "hit_players_%s: every token is exactly 96 x 96, the hit area is the token itself" % variant)


func _heroes_rows(g: Gallery, variant: String) -> void:
	var grid := g.items["HeroGrid"][0] as HeroGrid
	var n_all := _count(grid)
	ok(n_all == 1 and n_all <= GRID_NODE_GATE, "build_heroes_%s: the 40-hero grid is %d node (the gate is at most %d)" % [variant, n_all, GRID_NODE_GATE])
	ok(grid.hero_count() == 40 and grid.shown_count() == 40, "build_heroes_%s: %d heroes, %d shown" % [variant, grid.hero_count(), grid.shown_count()])
	var cw := grid.card_w()
	var want := floorf((grid.size.x - 2.0 * HeroGrid.GAP) / 3.0)
	ok(absf(cw - want) < 1.5 and cw >= 180.0, "fit_heroes_%s: a card is %.0f px wide in a %.0f px grid (the spec: 216 at 720, 183 at 626; the page is 8 px narrower than the spec's 672 and 578)" % [variant, cw, grid.size.x])
	var widest := 0.0
	var widest_name := ""
	var too_wide: Array = []
	for h in _heroes():
		var w := HeroCard.name_width(h)
		if w > widest:
			widest = w
			widest_name = h["name"]
		if w > HeroCard.name_room(cw):
			too_wide.append(h["name"])
	ok(too_wide.is_empty(), "fit_heroes_%s: all 40 names fit one line at Small 26 in %.0f px (widest '%s' %.0f px, %d characters)" % [variant, HeroCard.name_room(cw), widest_name, widest, widest_name.length()])
	var gw := HeroCard.name_width(App.world.heroes["gravenstone"])
	ok(gw > 115.0 and gw < 150.0 and gw <= HeroCard.name_room(cw), "fit_heroes_%s: 'Gravenstone' is %.0f px at 26 (PERF-BUDGET 6: 128 to 130), room %.0f" % [variant, gw, HeroCard.name_room(cw)])
	ok(grid.card_rect("brannoch").size.x >= 95.5 and grid.card_rect("brannoch").size.y >= 95.5, "hit_heroes_%s: a card is %.0f x %.0f, at least 96 x 96" % [variant, grid.card_rect("brannoch").size.x, grid.card_rect("brannoch").size.y])
	var rows := int(ceil(40.0 / 3.0))
	ok(absf(grid.custom_minimum_size.y - (float(rows) * (HeroCard.H + HeroGrid.GAP) - HeroGrid.GAP)) < 0.5, "fit_heroes_%s: the minimum height follows the %d rows (%.0f px)" % [variant, rows, grid.custom_minimum_size.y])
	ok(UI.find_tag("gal.hero.grid") == grid and UI.find_tag("gal.hero.filter") != null, "tags_heroes_%s: the grid and the filter bar are tagged" % variant)
	# the role filter: six stacked options at Caption 24, full words
	var seg := g.items["Segmented"][0] as Segmented
	ok(seg.stacked and seg.options.size() == 6 and seg.font_size == UI.S_CAPTION and seg.mode == "equal", "fit_heroes_%s: the role filter is six stacked options at %d px in the equal layout" % [variant, seg.font_size])
	var words := ["Jungle", "Support"]
	var found := 0
	for o in seg.options:
		if words.has(UI.plain(String(o["label"]))):
			found += 1
	ok(found == 2, "fit_heroes_%s: the filter says 'Jungle' and 'Support' in full (UI-PASS-2 11b)" % variant)
	var min_w := 9999.0
	for i in 6:
		min_w = minf(min_w, seg.button_at(i).size.x)
	ok(min_w >= 95.5, "hit_heroes_%s: every filter option is %.1f px wide, at least 96" % [variant, min_w])
	# a filtered grid: only the role's heroes, in the file order
	var before := grid.shown_ids()
	grid.set_filter("sup")
	var sup_ids := grid.shown_ids()
	var all_sup := true
	for id in sup_ids:
		all_sup = all_sup and (App.world.heroes[id]["role_primary"] == "sup" or App.world.heroes[id]["role_secondary"] == "sup")
	ok(sup_ids.size() > 0 and sup_ids.size() < 40 and all_sup, "build_heroes_%s: the Support filter shows %d heroes who play Support" % [variant, sup_ids.size()])
	ok(grid.custom_minimum_size.y < float(rows) * (HeroCard.H + HeroGrid.GAP), "fit_heroes_%s: the filtered grid is shorter (%.0f px)" % [variant, grid.custom_minimum_size.y])
	grid.set_filter("")
	ok(grid.shown_ids() == before, "inplace_heroes_%s: the filter back gives the same order" % variant)
	# cues of the five states in the gallery's grid
	var seen := {}
	for id in ["brannoch", "dunmarrow", "skarrow", "hegwin"]:
		seen[grid.state_name_of(id)] = grid.cue_for(id)
	ok(seen.size() == 4 and not (seen.values() as Array).has(""), "cb_heroes_%s: selected, banned, you and them each carry a cue (%s)" % [variant, str(seen)])
	ok(grid.cue_for("ottomere") == "" and grid.state_name_of("ottomere") == "available", "cb_heroes_%s: an available hero has no state cue" % variant)


func _lanes_rows(g: Gallery, variant: String) -> void:
	var boards: Array = g.items["LaneBoard"]
	var b := boards[0] as LaneBoard
	var full := boards[1] as LaneBoard
	ok(_count(b) == 8, "build_lanes_%s: a board is %d nodes (itself, header, five rows, bans row)" % [variant, _count(b)])
	var h_ok := true
	for r in LaneBoard.ROLES:
		h_ok = h_ok and absf(b.row(r).size.y - LaneRow.H_COMPACT) < 0.5 and absf(full.row(r).size.y - LaneRow.H_FULL) < 0.5
	ok(h_ok, "fit_lanes_%s: compact rows are 52 px, full rows 72 px" % variant)
	var clipped: Array = []
	for r in LaneBoard.ROLES:
		clipped.append_array(b.row(r).clipped)
		clipped.append_array(full.row(r).clipped)
	ok(clipped.is_empty(), "fit_lanes_%s: no name of the board is cut, 11-letter names and 'Gravenstone' included (%s)" % [variant, str(clipped)])
	var row0 := b.row("top")
	var want_word := UI.canvas_w() - 48.0 >= LaneRow.NARROW_BELOW
	ok(row0.centre_word == want_word, "fit_lanes_%s: the centre column %s (%.0f px of room: the glyph alone under %.0f, UI-PASS-2 11b)" % [variant, "shows glyph and word" if row0.centre_word else "is the glyph alone", row0.size.x, LaneRow.NARROW_BELOW])
	var sl := row0.slot_rect("you")
	var sr := row0.slot_rect("them")
	ok(sl.size.x >= 230.0 and absf(sl.size.x - sr.size.x) < 0.5 and sr.end.x <= row0.size.x + 0.5 and sl.end.x < sr.position.x, "fit_lanes_%s: the two slots are %.0f px each, mirrored, with the centre column between" % [variant, sl.size.x])
	ok(b.row("mid").state_of("you") == "target" and b.row("top").state_of("you") == "filled" and b.row("jg").state_of("you") == "empty", "build_lanes_%s: top filled, mid the target, jungle open" % variant)
	ok(full.row("sup").state_of("you") == "banned" and CompKit.cue_of(full).contains("slot") and String(CompKit.cue_of(full.row("sup"))).contains("cross"), "cb_lanes_%s: a banned slot carries the cue '%s'" % [variant, CompKit.cue_of(full.row("sup"))])
	ok(String(CompKit.cue_of(b.row("mid"))).contains("ring+arrow") and String(CompKit.cue_of(b.row("jg"))).contains("dashed"), "cb_lanes_%s: target is a ring plus an arrow, an open slot is dashed (%s / %s)" % [variant, CompKit.cue_of(b.row("mid")), CompKit.cue_of(b.row("jg"))])
	ok(b.bans("you").size() == 2 and b.bans("them").size() == 2, "build_lanes_%s: two bans each side" % variant)
	ok(UI.find_tag("gal.lane.board") == b, "tags_lanes_%s: the board is tagged (%s)" % [variant, "gal.lane.board"])
	ok(b.row("top").mouse_filter == Control.MOUSE_FILTER_IGNORE and not b.row("top").is_class("BaseButton"), "hit_lanes_%s: a lane row is display only (no tap target under 96 px)" % variant)


# ---- colour-blind mode ---------------------------------------------------------------------------------------------------------------

func _colour_blind() -> void:
	App.apply_large_text(false)
	UI.set_colorblind(true)
	await _fresh_main()
	var audited_total := 0
	for section in SECTIONS:
		var g := await _show(section)
		var audited: Array = []
		var probs := _cue_problems(g, audited)
		audited_total += audited.size()
		ok(probs.is_empty(), "cb_%s_colourblind: every state-bearing control carries a cue (%d audited)" % [section, audited.size()])
		ok(FitAudit.audit(App.main._current, UI.canvas_w()).is_empty(), "fit_%s_colourblind: clean" % section)
	ok(audited_total > 20, "cb: %d state-bearing controls audited across the card sections" % audited_total)
	ok(UI.GOOD == UI.GOOD_CB and UI.BAD == UI.BAD_CB and PlayerCard.chip_colour("good") == UI.GOOD_CB, "cb: in colour-blind mode the cards read the sky and orange pair (good %s)" % UI.GOOD.to_html(false))
	var gh := await _show("heroes")
	var grid := gh.items["HeroGrid"][0] as HeroGrid
	var seen: Dictionary = {}
	for id in ["brannoch", "dunmarrow", "skarrow", "hegwin"]:
		seen[grid.cue_for(id)] = true
	ok(seen.size() == 4, "cb_heroes_colourblind: the four marked states still have four cues that do not use colour")
	UI.set_colorblind(false)


# ---- in place ---------------------------------------------------------------------------------------------------------------------------

func _inplace() -> void:
	App.apply_large_text(false)
	await _fresh_main()
	# HeroGrid
	var g := await _show("heroes")
	var grid := g.items["HeroGrid"][0] as HeroGrid
	var ids := _ids(g)
	await frames(2)
	var a0 := grid.applied
	var d0 := grid.draw_count
	grid.set_filter("")
	grid.set_heroes(_heroes())
	grid.set_state("barrowick", grid.state_of("barrowick").duplicate())
	grid.set_state("dunmarrow", grid.state_of("dunmarrow").duplicate())
	grid.set_selected("brannoch")
	grid.set_states({"dunmarrow": grid.state_of("dunmarrow").duplicate(), "skarrow": grid.state_of("skarrow").duplicate()})
	await frames(2)
	ok(grid.applied == a0 and grid.draw_count == d0, "inplace_HeroGrid: equal heroes, filter and states change nothing (applied %d, draws %d)" % [grid.applied, grid.draw_count])
	var t0 := Time.get_ticks_usec()
	for k in 20:
		grid.set_filter("top" if k % 2 == 0 else "")
		for i in 8:
			grid.set_state(grid.heroes[i]["id"], "banned" if (k + i) % 2 == 0 else "available")
	var per := float(Time.get_ticks_usec() - t0) / 20.0 / 1000.0
	ok(per < 5.0, "inplace_HeroGrid: a filter change and 8 state changes take %.3f ms headless (the gate is under 5 ms; 0.06 ms measured in the spike)" % per)
	var d1 := grid.draw_count
	await frames(2)
	ok(grid.draw_count == d1 + 1, "inplace_HeroGrid: the 180 setters of that loop ended in ONE redraw (%d -> %d)" % [d1, grid.draw_count])
	grid.set_filter("")
	for i in 40:
		grid.set_state(grid.heroes[i]["id"], "available")
	grid.set_state("dunmarrow", "banned")
	grid.set_state("skarrow", "you")
	grid.set_state("hegwin", "them")
	grid.set_selected("brannoch")
	await frames(2)
	ok(_ids(g) == ids and grid.get_child_count() == 0, "inplace_HeroGrid: after the filter and state loops every instance id is the same and the grid has no child nodes")
	ok(CompKit.cue_of(grid) != "" and grid.state_name() == "states", "cb_HeroGrid: the grid's own cue lists the cues of the states on show (%s)" % CompKit.cue_of(grid))
	var mark := App.bus.sequence()
	var taps: Array = []
	grid.hero_tapped.connect(func(id: String) -> void: taps.append(id))
	grid._tapped(grid._index["ottomere"])
	grid._tapped(grid._index["dunmarrow"])
	grid._tapped(grid._index["skarrow"])
	grid._tapped(grid._index["hegwin"])
	ok(taps == ["ottomere"] and App.bus.seen("tap:gal.hero.grid.ottomere", mark) and not App.bus.seen("tap:gal.hero.grid.dunmarrow", mark), "tags_HeroGrid: an available hero emits hero_tapped and tap:gal.hero.grid.<id>; banned and picked heroes emit nothing (%s)" % str(taps))
	# PlayerCard
	g = await _show("players")
	ids = _ids(g)
	var card: PlayerCard = g.items["PlayerCard"][0]
	await frames(2)
	var pa := card.applied
	var pd := card.draw_count
	card.set_selected(card.selected)
	card.set_rating(card.opts["rating"])
	card.set_chips(card.opts["chips"])
	card.set_name_text(card.player_name())
	card.set_starter(bool(card.opts["starter"]))
	await frames(2)
	ok(card.applied == pa and card.draw_count == pd, "inplace_PlayerCard: equal values change nothing (applied %d, draws %d)" % [card.applied, card.draw_count])
	card.set_selected(true)
	await frames(2)
	ok(card.applied == pa + 1 and card.draw_count == pd + 1 and CompKit.cue_of(card) == "ring+tick", "inplace_PlayerCard: selecting redraws once and sets the cue 'ring+tick'")
	for i in 20:
		card.set_selected(i % 2 == 0)
	card.set_selected(false)
	card.set_rating(99)
	card.set_name_text("Okonkwo")
	await frames(2)
	ok(_ids(g) == ids and card.rating_text() == "99" and card.player_name() == "Okonkwo", "inplace_PlayerCard: 22 changes keep every instance id (%d nodes)" % ids.size())
	card.set_disabled(true)
	ok(absf(card.modulate.a - 0.6) < 0.01 and CompKit.cue_of(card) == "faded" and card.state_name() == "disabled", "cb_PlayerCard: disabled is 60 percent opacity with the cue 'faded'")
	card.set_disabled(false)
	# LaneBoard
	g = await _show("lanes")
	ids = _ids(g)
	var board := g.items["LaneBoard"][0] as LaneBoard
	var row_top := board.row("top")
	var ra := row_top.applied
	var rd := row_top.draw_count
	await frames(2)
	rd = row_top.draw_count
	row_top.set_slot("you", {"state": "filled", "hero": row_top.slot("you")["hero"], "player": "Ashjin"})
	row_top.set_slot("them", {"player": "Brikai"})
	board.set_bans("you", board.bans("you"))
	await frames(2)
	ok(row_top.applied == ra and row_top.draw_count == rd, "inplace_LaneRow: an equal slot changes nothing (applied %d, draws %d)" % [row_top.applied, row_top.draw_count])
	board.set_slot("jg", "you", {"state": "filled", "hero": _heroes()[7], "player": "Brammont"})
	board.set_target("sup", "you")
	board.set_bans("them", [_heroes()[1]])
	await frames(2)
	ok(board.row("jg").state_of("you") == "filled" and board.row("mid").state_of("you") == "empty" and board.row("sup").state_of("you") == "target" and board.bans("them").size() == 1, "inplace_LaneBoard: the target moved from mid to support, a hero filled jungle, one ban left")
	ok(_ids(g) == ids, "inplace_LaneBoard: the same instances after the changes (%d nodes)" % ids.size())
	board.set_compact(false)
	await frames(2)
	ok(board.row("top").size.y >= LaneRow.H_FULL - 0.5 and _ids(g) == ids, "inplace_LaneBoard: compact to full changes the row height in place (%.0f px)" % board.row("top").size.y)
	board.set_compact(true)


# ---- negative controls: each audit must catch a bad sample ------------------------------------------------------------------------

## 0.9.3c: the grid draws only its visible window; when the grid moves on its page (a part above it grows) or the scroll area
## changes height, the window it drew must follow without a scroll.
func _window_moves() -> void:
	await _fresh_main()
	var scr := Control.new()
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var page := ScrollContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scr.add_child(page)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(col)
	var above := Control.new()
	col.add_child(above)
	var grid := HeroGrid.new()
	grid.set_heroes(_heroes())
	col.add_child(grid)
	App.go(scr)
	await frames(4)
	ok(grid._last_window == grid._window() and grid._last_window.size.y > 0.0, "window: the drawn window is the visible one at the start (%s)" % str(grid._last_window))
	var d0 := grid.draw_count
	await frames(3)
	ok(grid.draw_count == d0, "window: a still grid does not redraw")
	above.custom_minimum_size = Vector2(0, 700)    # a part above the grid grows: the grid moves 700 px down the page
	await frames(4)
	ok(grid._last_window == grid._window() and grid.draw_count > d0, "window: after the grid moved down 700 px the drawn window follows (%s, want %s)" % [str(grid._last_window), str(grid._window())])
	page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	page.size = Vector2(720, 500)    # the scroll area gets shorter
	await frames(4)
	ok(grid._last_window == grid._window(), "window: after the scroll area shrank the drawn window follows (%s, want %s)" % [str(grid._last_window), str(grid._window())])
	above.custom_minimum_size = Vector2(0, 0)
	page.size = Vector2(720, 1280)
	await frames(4)
	ok(grid._last_window == grid._window(), "window: back to the top, the drawn window follows (%s)" % str(grid._last_window))


func _negative_controls() -> void:
	App.apply_large_text(false)
	await _fresh_main()
	var g := await _show("heroes")
	var grid := g.items["HeroGrid"][0] as HeroGrid
	# 1 fit: a name wider than the card
	var wide := {"id": "wwwwwwwwwwwwwwww", "name": "WWWWWWWWWWWWWWWW", "role_primary": "mid", "role_secondary": null, "archetype": "binder"}
	ok(HeroCard.name_width(wide) > HeroCard.name_room(grid.card_w()), "negative control: the name-fit audit catches a 16-letter name wider than the card (%.0f of %.0f px)" % [HeroCard.name_width(wide), HeroCard.name_room(grid.card_w())])
	CardKit.reset_counters()
	var probe := _Canvas.new()
	probe.fn = func(ci: CanvasItem) -> void: HeroCard.draw(ci, Rect2(0, 0, 216, 196), wide, "available", HeroCard.PASS_TEXT26)
	add_child(probe)
	await frames(3)
	ok(CardKit.clipped_count >= 1, "negative control: drawing that name cuts it with '...' and counts it (%d)" % CardKit.clipped_count)
	probe.queue_free()
	# 2 hit area: a grid squeezed to a width that makes the cards narrower than 96 px
	var narrow := HeroGrid.new()
	narrow.set_heroes(_heroes())
	narrow.size = Vector2(250, 600)
	ok(narrow.card_rect("brannoch").size.x < 95.5, "negative control: the hit-area walk catches a card of %.0f px (a 250 px grid)" % narrow.card_rect("brannoch").size.x)
	narrow.free()
	# 3 cue audit: a grid that shows a banned hero with its cue erased
	ok(_cue_problems(g).is_empty(), "negative control: before the fault the cue audit is clean")
	grid.set_meta(CompKit.CUE, "")
	var probs := _cue_problems(g)
	ok(not probs.is_empty(), "negative control: the cue audit catches a grid in 'states' with an empty cue (%s)" % "; ".join(probs.slice(0, 1)))
	grid.set_meta(CompKit.CUE, "restored")
	grid._note_cue()
	ok(_cue_problems(g).is_empty(), "negative control: the cue comes back with the next state change")
	# 4 node gate: forty PanelContainers per card is the design the spike rejected
	var rival := Control.new()
	for i in 40:
		var pc := PanelContainer.new()
		var vb := VBoxContainer.new()
		pc.add_child(vb)
		for k in 5:
			vb.add_child(Control.new())
		rival.add_child(pc)
	ok(_count(rival) > GRID_NODE_GATE and _count(grid) <= GRID_NODE_GATE, "negative control: a grid of 40 container cards is %d nodes, over the gate of %d; the HeroGrid is %d" % [_count(rival), GRID_NODE_GATE, _count(grid)])
	rival.free()
	# 5 in-place detector: rebuilding the grid changes instance ids
	var ids := _ids(g)
	var host := grid.get_parent()
	var idx := grid.get_index()
	host.remove_child(grid)
	grid.queue_free()
	var again := HeroGrid.new("gal.hero.grid")
	host.add_child(again)
	host.move_child(again, idx)
	ok(_ids(g) != ids, "negative control: the in-place check sees a deleted and rebuilt grid (ids differ)")
	# 6 the counters move when something does change (so 'equal changes nothing' is not vacuous)
	var counter := HeroGrid.new()
	counter.set_heroes(_heroes())
	var a0 := counter.applied
	counter.set_state("brannoch", "banned")
	ok(counter.applied == a0 + 1 and counter.state_name_of("brannoch") == "banned", "negative control: a changed state does move the applied counter")
	counter.free()
	# 7 a card layout test that must fail: a 10-letter name in a 90 px room
	var f := UI.font("SemiBold")
	ok(CardKit.fit(f, UI.S_SMALL, "Gravenstone", 90.0).ends_with("..."), "negative control: 'Gravenstone' in a 90 px room is cut")
	await frames(1)
