extends Node
## I-07 checks: the flat components of src/ui/components (DepthCard, SectionHeader, Chip, Segmented, IconButton,
## EmptyState, EdgeMeter, HeroStat, ListSync, Toast) through the components gallery (tests/components_gallery.gd).
## Rows (names are the check labels): build_<section>, fit_<section>_<variant>, hit_, inplace_<component>, cb_ (the "cue" meta,
## also in colour-blind mode), tags_ (tutorial ids), shadow gate, and negative controls (a bad sample must be caught by each audit).
## The window is set to 720 x 1280 first (a headless window is 100 x 100). Headless: it reads layout, state and counters;
## draw calls and pictures are in tests/shots/shots_gallery.gd. Ends with " N checks, M failures".

const FitAudit = preload("res://tests/fit_audit.gd")
const Gate = preload("res://tests/perf_gate.gd")
const Gallery = preload("res://tests/components_gallery.gd")

const TAGS := {
	"cards": ["gal.card.flat", "gal.card.tap"],
	"headers": ["gal.head.action", "gal.head.action.action", "gal.head.open", "gal.head.closed"],
	"chips": ["gal.chip.neutral", "gal.chip.good", "gal.chip.bad", "gal.chip.warn", "gal.chip.accent", "gal.icon.0", "gal.icon.1", "gal.icon.2", "gal.icon.5"],
	"segmented": ["gal.seg3", "gal.seg3.0", "gal.seg3.2", "gal.seg5", "gal.seg5.mid", "gal.seg5.jg"],
	"data": ["gal.edge", "gal.herostat", "gal.empty", "gal.empty.action"],
}

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


## Controls the cue audit looks at: every node with the "state_bearing" meta that is in a state ("state_name" not empty)
## must carry a non-empty "cue" meta. Returns a list of problems.
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
	get_window().size = Vector2i(720, 1280)    # a headless window is 100 x 100 until told otherwise
	await frames(1)
	_icon_hook()
	for variant in ["normal", "large"]:
		await _variant(variant)
	await _colour_blind()
	await _units()
	await _negative_controls()
	await _toast()
	App.apply_large_text(false)
	UI.set_colorblind(false)
	UI.animate = true
	print("nodes: " + " | ".join(node_rows))
	print("check_ui_components: %d checks, %d failures" % [checks, fails])
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
	await frames(3)
	return g


# ---- the icon hook ------------------------------------------------------------------------------------------------

func _icon_hook() -> void:
	ok(not IconHook.draw_fn.is_valid(), "icon hook: unwired by default (I-09 sets IconHook.draw_fn), the placeholder draws")
	var distinct := {}
	for k in Chip.ICONS:
		distinct[Chip.ICONS[k]] = true
	ok(distinct.size() == Chip.ICONS.size(), "chip variants each have their own icon (%d icons for %d variants)" % [distinct.size(), Chip.ICONS.size()])
	for id in IconHook.IDS:
		ok(id != "", "icon id '%s' is in the hook list" % id)


# ---- per variant: build, fit, hit, tags ----------------------------------------------------------------------------

func _variant(variant: String) -> void:
	App.apply_large_text(variant == "large")
	UI.set_colorblind(false)
	await frames(2)
	ok(absf(get_viewport().get_visible_rect().size.x - UI.canvas_w()) < 1.0, "%s: the canvas is %.0f px wide" % [variant, get_viewport().get_visible_rect().size.x])
	await _fresh_main()
	for section in Gallery.SECTIONS:
		var g := await _show(section)
		var n := _count(g)
		node_rows.append("%s/%s=%d" % [variant, section, n])
		ok(not g.items.is_empty() and n > 3, "build_%s_%s: built, %d nodes, kinds %s" % [section, variant, n, ",".join(g.items.keys())])
		ok(n <= 200, "build_%s_%s: %d nodes, at most the hard limit 200 (target 120: %s)" % [section, variant, n, "met" if n <= 120 else "over, a test page"])
		var probs := FitAudit.audit(App.main._current, UI.canvas_w())
		ok(probs.is_empty(), "fit_%s_%s: clean" % [section, variant])
		for p in probs.slice(0, 8):
			print("     ", p)
		_fit_extra(g, section, variant)
		_hit_areas(g, section, variant)
		var cue_probs := _cue_problems(g)
		ok(cue_probs.is_empty(), "cb_%s_%s: every state-bearing control carries a cue (%s)" % [section, variant, "; ".join(cue_probs)])
		if TAGS.has(section):
			var missing: Array = []
			for id in TAGS[section]:
				var c := UI.find_tag(id)
				if c == null:
					missing.append(id)
			ok(missing.is_empty(), "tags_%s_%s: tutorial ids found and visible (missing: %s)" % [section, variant, ",".join(missing)])
		var sh: Dictionary = Gate.count_shadows(g)
		ok(int(sh["shadows"]) <= 6 and int(sh["glows"]) <= 2, "shadow gate %s_%s: %d shadowed (max 6), %d glowing (max 2)" % [section, variant, sh["shadows"], sh["glows"]])
	await _inplace(variant)
	await _segmented_width(variant)


func _fit_extra(g: Gallery, section: String, variant: String) -> void:
	for c in g.items.get("Chip", []):
		var chip := c as Chip
		ok(not chip.is_clipped() and chip.size.x >= chip.needs_width() - 0.5 and chip.size.y >= Chip.H - 0.5, "fit_%s_%s: chip '%s' shows its whole text (%.0f of %.0f px, height %.0f)" % [section, variant, chip.plain_text(), chip.size.x, chip.needs_width(), chip.size.y])
	for h in g.items.get("SectionHeader", []):
		var sh := h as SectionHeader
		ok(sh.size.y >= SectionHeader.H_PLAIN - 0.5, "fit_%s_%s: section header '%s' is at least 56 px high (%.0f)" % [section, variant, sh.title.substr(0, 20), sh.size.y])
		if sh.action_button() != null:
			ok(sh.action_button().size.x >= 96.0 and sh.action_button().size.y >= 96.0, "hit_%s_%s: the header action is %.0f x %.0f" % [section, variant, sh.action_button().size.x, sh.action_button().size.y])
	for s in g.items.get("Segmented", []):
		var seg := s as Segmented
		var widths_ok := true
		for i in seg.options.size():
			var b := seg.button_at(i)
			widths_ok = widths_ok and b.size.y >= 95.5 and (b.size.x >= 95.5)
		ok(widths_ok, "hit_%s_%s: every option of a Segmented (%d, %s) is at least 96 x 96" % [section, variant, seg.options.size(), seg.mode])
	var seg_nodes: Array = g.items.get("Segmented", [])
	if seg_nodes.size() == 6:    # the gallery's order: 3 equal, 2 equal, long labels, 5 stacked, forced strip
		ok((seg_nodes[0] as Segmented).mode == "equal" and (seg_nodes[1] as Segmented).mode == "equal", "fit_%s_%s: three and two short options stay equal" % [section, variant])
		ok((seg_nodes[2] as Segmented).mode == "scroll", "fit_%s_%s: labels too long for their slot switch to the strip by themselves" % [section, variant])
		ok((seg_nodes[3] as Segmented).mode == "equal" and (seg_nodes[3] as Segmented).stacked, "fit_%s_%s: five stacked role options fit equal" % [section, variant])
		ok((seg_nodes[5] as Segmented).mode == "scroll", "fit_%s_%s: fit = scroll gives the strip" % [section, variant])


func _hit_areas(g: Gallery, section: String, variant: String) -> void:
	var small: Array = []
	_small_buttons(g, small)
	ok(small.is_empty(), "hit_%s_%s: every visible button is at least 96 x 96 (%s)" % [section, variant, "; ".join(small.slice(0, 4))])
	for b in g.items.get("IconButton", []):
		var ib := b as IconButton
		ok(ib.size.x >= 95.5 and ib.size.y >= 95.5 and String(ib.get_meta("accessible_name", "")) != "" and ib.tooltip_text != "", "hit_%s_%s: icon button %s is %.0f x %.0f with an accessible name" % [section, variant, ib.icon_id, ib.size.x, ib.size.y])


func _small_buttons(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is BaseButton and (n as Control).size.x > 0 and ((n as Control).size.x < 95.5 or (n as Control).size.y < 95.5):
		out.append("%s %.0fx%.0f" % [n.get_class(), (n as Control).size.x, (n as Control).size.y])
	for c in n.get_children():
		_small_buttons(c, out)


# ---- in place -----------------------------------------------------------------------------------------------------

func _inplace(variant: String) -> void:
	await _fresh_main()
	var g := await _show("cards")
	# DepthCard
	var card := g.items["DepthCard"][0] as DepthCard
	var ids := _ids(g)
	var a0 := card.applied
	card.set_selected(false)
	card.set_elevation(0)
	card.set_tint(Color(0, 0, 0, 0))
	await frames(2)
	var d0 := card.draw_count
	card.set_selected(false)
	await frames(2)
	ok(card.applied == a0 and card.draw_count == d0, "inplace_DepthCard_%s: an equal value changes nothing (applied %d, draws %d)" % [variant, card.applied, card.draw_count])
	card.set_selected(true)
	await frames(2)
	ok(card.applied == a0 + 1 and card.draw_count > d0 and card.get_theme_stylebox("panel") is StyleBoxFlat and (card.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left == 3, "inplace_DepthCard_%s: selecting restyles in place (3 px ring, redrawn)" % variant)
	for i in 20:
		card.set_selected(i % 2 == 0)
	card.set_selected(false)
	await frames(2)
	ok(_ids(g) == ids, "inplace_DepthCard_%s: 21 toggles keep every instance id (%d nodes)" % [variant, ids.size()])
	ok(CompKit.cue_of(card) == "" and card.state_name() == "", "cb_DepthCard_%s: the default state has no cue, selected has 'ring+check'" % variant)
	card.set_selected(true)
	ok(CompKit.cue_of(card) == "ring+check", "cb_DepthCard_%s: selected cue is '%s'" % [variant, CompKit.cue_of(card)])
	card.set_selected(false)
	var glow_probe := Gate.count_shadows(g.items["DepthCard"][1])
	ok(glow_probe["glows"] == 1 and glow_probe["shadows"] == 0, "shadow gate: a selected card is one glow, no shadow (%s)" % str(glow_probe))
	var raised_probe := Gate.count_shadows(g.items["DepthCard"][2])
	ok(raised_probe["shadows"] == 1 and raised_probe["glows"] == 0, "shadow gate: a raised card is one shadow (%s)" % str(raised_probe))
	var flat_probe := Gate.count_shadows(g.items["DepthCard"][0])
	ok(flat_probe["shadows"] == 0 and flat_probe["glows"] == 0, "shadow gate: a flat card has no shadow, no glow")
	# tappable card: pressed look and tap event
	var tap := g.items["DepthCard"][7] as DepthCard
	var hit := tap.get_child(0) as Button
	var before_col := (tap.get_theme_stylebox("panel") as StyleBoxFlat).bg_color
	hit.button_down.emit()
	var down_col := (tap.get_theme_stylebox("panel") as StyleBoxFlat).bg_color
	hit.button_up.emit()
	var up_col := (tap.get_theme_stylebox("panel") as StyleBoxFlat).bg_color
	ok(down_col.v < before_col.v and up_col == before_col, "inplace_DepthCard_%s: pressed darkens the body by 10 percent and releases back" % variant)
	var mark := App.bus.sequence()
	hit.pressed.emit()
	ok(g.taps.has("card") and App.bus.seen("tap:gal.card.tap", mark), "tags_cards_%s: a tappable card raises pressed and tap:gal.card.tap" % variant)
	var dis := g.items["DepthCard"][6] as DepthCard
	ok(dis.disabled and absf(dis.modulate.a - 0.6) < 0.01 and CompKit.cue_of(dis) == "faded", "cb_DepthCard_%s: disabled is 60 percent opacity with cue 'faded'" % variant)
	# Chip
	g = await _show("chips")
	ids = _ids(g)
	var chip := g.items["Chip"][1] as Chip
	var ac := chip.applied
	chip.set_text(chip.text)
	chip.set_variant(chip.variant)
	chip.set_icon(chip.icon_id)
	await frames(2)
	var cd := chip.draw_count
	chip.set_text(chip.text)
	await frames(2)
	ok(chip.applied == ac and chip.draw_count == cd, "inplace_Chip_%s: an equal text, variant and icon change nothing" % variant)
	var w0 := chip.needs_width()
	chip.set_text(chip.text + " and more")
	await frames(2)
	ok(chip.applied == ac + 1 and chip.needs_width() > w0 and chip.custom_minimum_size.x >= chip.needs_width() - 1.0 and chip.draw_count > cd, "inplace_Chip_%s: a new text widens it in place (%.0f to %.0f px)" % [variant, w0, chip.needs_width()])
	chip.set_text(Strings.t("mood.hot"))
	ok(_ids(g) == ids, "inplace_Chip_%s: instance ids unchanged" % variant)
	ok(CompKit.cue_of(chip) == "check" and CompKit.cue_of(g.items["Chip"][2]) == "cross", "cb_Chip_%s: cue is the icon (good = check, bad = cross)" % variant)
	var ib := g.items["IconButton"][0] as IconButton
	var ia := ib.applied
	ib.set_icon_id(ib.icon_id)
	ib.set_active(false)
	ib.set_enabled(true)
	ok(ib.applied == ia, "inplace_IconButton_%s: equal values change nothing" % variant)
	ib.set_active(true)
	ok(ib.applied == ia + 1 and CompKit.cue_of(ib) == "ring", "inplace_IconButton_%s: active sets the ring cue" % variant)
	ib.set_active(false)
	var dis_btn := g.items["IconButton"][2] as IconButton
	ok(dis_btn.disabled and CompKit.cue_of(dis_btn) == "faded", "cb_IconButton_%s: disabled cue is 'faded'" % variant)
	var mark2 := App.bus.sequence()
	(g.items["IconButton"][0] as IconButton).pressed.emit()
	ok(g.taps.has("icon0") and App.bus.seen("tap:gal.icon.0", mark2), "tags_chips_%s: pressing an icon button raises tap:gal.icon.0" % variant)
	# SectionHeader
	g = await _show("headers")
	ids = _ids(g)
	var closed := SectionHeader.find(g, Strings.t("help.know"))
	ok(closed != null and closed.expandable and not closed.open and not closed.content.visible, "build_headers_%s: SectionHeader.find locates the expander by its title (migrated prefix test); closed hides its content" % variant)
	var label := _first_label(closed)
	ok(label != null and UI.plain(label.text) == Strings.t("help.know").to_upper(), "build_headers_%s: the label is upper case, UI.plain gives the text back" % variant)
	var toggled: Array = []
	closed.toggled.connect(func(o: bool) -> void: toggled.append(o))
	var ah := closed.applied
	closed.set_open(false)
	ok(closed.applied == ah, "inplace_SectionHeader_%s: an equal open state changes nothing" % variant)
	var mark3 := App.bus.sequence()
	closed.hit_button().pressed.emit()
	await frames(2)
	ok(closed.open and closed.content.visible and toggled == [true] and CompKit.cue_of(closed) == "chevron_down" and App.bus.seen("tap:gal.head.closed", mark3), "inplace_SectionHeader_%s: a tap opens it (content shown, chevron_down cue, toggled once, tap event)" % variant)
	closed.hit_button().pressed.emit()
	ok(not closed.open and not closed.content.visible and CompKit.cue_of(closed) == "chevron_right", "inplace_SectionHeader_%s: a second tap closes it" % variant)
	ok(closed.hit_button().size.y >= 95.5 and closed.hit_button().size.x >= 95.5, "hit_headers_%s: the expander hit area is %.0f x %.0f" % [variant, closed.hit_button().size.x, closed.hit_button().size.y])
	ok(_ids(g) == ids, "inplace_SectionHeader_%s: instance ids unchanged after two taps" % variant)
	var counted := g.items["SectionHeader"][1] as SectionHeader
	var ac2 := counted.applied
	counted.set_count(5)
	counted.set_text(counted.title)
	ok(counted.applied == ac2, "inplace_SectionHeader_%s: the same count and text change nothing" % variant)
	counted.set_count(6)
	ok(counted.applied == ac2 + 1, "inplace_SectionHeader_%s: a new count changes it once" % variant)
	counted.set_count(5)
	# Segmented
	g = await _show("segmented")
	ids = _ids(g)
	var seg := g.items["Segmented"][0] as Segmented
	var got: Array = []
	seg.changed.connect(func(id: Variant) -> void: got.append(id))
	var as0 := seg.applied
	seg.set_selected(0)
	ok(seg.applied == as0 and got.is_empty(), "inplace_Segmented_%s: selecting the held option changes nothing" % variant)
	var mark4 := App.bus.sequence()
	seg.button_for(2).pressed.emit()
	await frames(2)
	ok(seg.selected_id == 2 and got == [2] and g.taps.has("seg3") and App.bus.seen("tap:gal.seg3.2", mark4), "inplace_Segmented_%s: a tap on option 2 selects it, fires changed, on_change and tap:gal.seg3.2" % variant)
	seg.button_for(2).pressed.emit()
	ok(got == [2], "inplace_Segmented_%s: tapping the selected option again fires nothing" % variant)
	seg.set_selected(0)
	ok(_ids(g) == ids, "inplace_Segmented_%s: instance ids unchanged by selection changes" % variant)
	ok(CompKit.cue_of(seg.button_for(0)) == "pill+ring" and CompKit.cue_of(seg.button_for(1)) == "" and CompKit.cue_of(seg) == "pill+ring", "cb_Segmented_%s: the selected option carries the cue 'pill+ring'" % variant)
	var roles := g.items["Segmented"][3] as Segmented
	ok(roles.button_for("bot").disabled and CompKit.cue_of(roles.button_for("bot")) == "lock", "cb_Segmented_%s: a locked option is disabled and carries the cue 'lock'" % variant)
	roles.set_locked("bot", false)
	ok(not roles.button_for("bot").disabled and CompKit.cue_of(roles.button_for("bot")) == "", "inplace_Segmented_%s: unlocking changes it in place" % variant)
	roles.set_locked("bot", true)
	var strip := g.items["Segmented"][2] as Segmented
	ok(strip.mode == "scroll", "inplace_Segmented_%s: the long-label strip is in scroll mode" % variant)
	# EdgeMeter, HeroStat, EmptyState
	g = await _show("data")
	ids = _ids(g)
	var em := g.items["EdgeMeter"][0] as EdgeMeter
	var ae := em.applied
	await frames(2)
	var de := em.draw_count
	em.set_value(0.056)
	await frames(2)
	ok(em.applied == ae and em.draw_count == de, "inplace_EdgeMeter_%s: an equal value changes nothing (draws %d)" % [variant, em.draw_count])
	em.set_value(-0.10)
	await frames(2)
	ok(em.applied == ae + 1 and em.draw_count > de and em.value_text() == "-10.0%" and CompKit.cue_of(em) == "sign+side", "inplace_EdgeMeter_%s: a new value redraws once and prints the sign (%s)" % [variant, em.value_text()])
	em.set_value(0.0)
	ok(em.value_text() == "0.0%" and CompKit.cue_of(em) == "zero" and em.state_name() == "zero", "cb_EdgeMeter_%s: zero prints 0.0%% and cue 'zero'" % variant)
	em.set_value(0.056)
	ok((g.items["EdgeMeter"][1] as EdgeMeter).value_text().begins_with("-") and (g.items["EdgeMeter"][0] as EdgeMeter).value_text().begins_with("+"), "cb_EdgeMeter_%s: the sign is in the text for both sides (%s, %s)" % [variant, (g.items["EdgeMeter"][0] as EdgeMeter).value_text(), (g.items["EdgeMeter"][1] as EdgeMeter).value_text()])
	var hs := g.items["HeroStat"][0] as HeroStat
	var ah2 := hs.applied
	hs.set_value(73.5)
	hs.set_sentence(hs.sentence)
	hs.set_best(hs.best_chip().text)
	ok(hs.applied == ah2, "inplace_HeroStat_%s: equal values change nothing" % variant)
	hs.set_value(80.0, false)
	ok(hs.applied == ah2 + 1 and hs.number_text() == "+80.0", "inplace_HeroStat_%s: a new value shows at once with count off (%s)" % [variant, hs.number_text()])
	hs.set_worst("")
	ok(not hs.worst_chip().visible, "inplace_HeroStat_%s: an empty chip text hides the chip" % variant)
	hs.set_worst(Strings.t("fatigue.tired"))
	var es := g.items["EmptyState"][0] as EmptyState
	var aes := es.applied
	es.set_title(es.title)
	es.set_helper(es.helper)
	es.set_action(UI.plain(es.action_button().text))
	ok(es.applied == aes, "inplace_EmptyState_%s: equal text changes nothing" % variant)
	ok(es.action_button().size.y >= 95.5 and es.action_button().visible, "hit_data_%s: the empty-state action is %.0f px high" % [variant, es.action_button().size.y])
	es.set_action("")
	ok(not es.action_button().visible, "inplace_EmptyState_%s: an empty action text hides the button" % variant)
	es.set_action(Strings.t("empty.history.btn"))
	var mark5 := App.bus.sequence()
	es.action_button().pressed.emit()
	ok(g.taps.has("empty") and App.bus.seen("tap:gal.empty.action", mark5), "tags_data_%s: the empty-state action fires and raises tap:gal.empty.action" % variant)
	ok(_ids(g) == ids, "inplace_data_%s: instance ids unchanged across all the data setters" % variant)
	# ListSync
	g = await _show("list")
	var all_box := g.items["ListSync"][0] as VBoxContainer
	var f_box := g.items["ListSync"][1] as VBoxContainer
	ok(ListSync.shown_keys(all_box) == Gallery.ROLES and ListSync.shown_keys(f_box) == ["bot", "mid"], "build_list_%s: five shown, then the filtered pair in the asked order (%s)" % [variant, str(ListSync.shown_keys(f_box))])
	var kids := all_box.get_children()
	var kid_ids: Array = []
	for k in kids:
		kid_ids.append(k.get_instance_id())
	var n_before := all_box.get_child_count()
	var map1 := ListSync.sync(all_box, ["mid", "top"], g.make_row)
	ok(ListSync.shown_keys(all_box) == ["mid", "top"] and all_box.get_child_count() == n_before, "inplace_ListSync_%s: a filter shows 2, hides 3, creates and frees nothing" % variant)
	var hidden_ok := true
	for k in ["jg", "bot", "sup"]:
		hidden_ok = hidden_ok and is_instance_valid(map1[k]) and not (map1[k] as Control).visible and not (map1[k] as Node).is_queued_for_deletion()
	ok(hidden_ok, "inplace_ListSync_%s: the hidden rows are kept, not freed" % variant)
	ListSync.sync(all_box, Gallery.ROLES, g.make_row)
	var ids_after: Array = []
	for k in all_box.get_children():
		ids_after.append(k.get_instance_id())
	ok(ids_after == kid_ids and ListSync.shown_keys(all_box) == Gallery.ROLES, "inplace_ListSync_%s: the filter back gives the same five instances in the first order" % variant)
	ListSync.sync(all_box, ["sup", "bot", "mid", "jg", "top"], g.make_row)
	var rev: Array = []
	for k in all_box.get_children():
		rev.append(k.get_instance_id())
	var rev_sorted := rev.duplicate()
	rev_sorted.sort()
	var kid_sorted := kid_ids.duplicate()
	kid_sorted.sort()
	ok(ListSync.shown_keys(all_box) == ["sup", "bot", "mid", "jg", "top"] and rev_sorted == kid_sorted and rev != kid_ids, "inplace_ListSync_%s: a new order moves the same instances" % variant)
	var made: Array = []
	var counting := func(k: String) -> Control:
		made.append(k)
		return g.make_row(k)
	ListSync.sync(all_box, ["top", "mid", "top"], counting)
	ok(made.is_empty() and ListSync.shown_keys(all_box) == ["top", "mid"], "inplace_ListSync_%s: a duplicate key is ignored and no row is made for known keys" % variant)
	ListSync.sync(all_box, ["top", "new"], counting)
	ok(made.size() == 1 and ListSync.shown_keys(all_box) == ["top", "new"], "inplace_ListSync_%s: an unknown key makes exactly one row" % variant)


func _first_label(n: Node) -> Label:
	if n is Label:
		return n as Label
	for c in n.get_children():
		var l := _first_label(c)
		if l != null:
			return l
	return null


# ---- Segmented against the width it is given -------------------------------------------------------------------

func _segmented_width(variant: String) -> void:
	await _fresh_main()
	var host := Control.new()
	host.size = Vector2(578, 120)
	App.main.add_child(host)
	var labels: Array = [Strings.t("standings.view.table"), Strings.t("standings.view.playoffs"), Strings.t("standings.view.history")]
	var seg := Segmented.new(labels, 0)
	seg.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(seg)
	await frames(3)
	var ids := _ids(seg)
	ok(seg.mode == "equal", "fit_Segmented_%s: three labels at 578 px are equal" % variant)
	host.size = Vector2(300, 120)
	await frames(3)
	ok(seg.mode == "scroll", "fit_Segmented_%s: the same three labels at 300 px switch to the strip" % variant)
	var all_ok := true
	for i in 3:
		all_ok = all_ok and seg.button_at(i).size.x >= 95.5
	ok(all_ok, "hit_Segmented_%s: strip options stay at least 96 px wide" % variant)
	host.size = Vector2(578, 120)
	await frames(3)
	ok(seg.mode == "equal" and _ids(seg) == ids, "inplace_Segmented_%s: widening again gives equal, same nodes (%d)" % [variant, ids.size()])
	var six: Array = []
	for r in Gallery.ROLES:
		six.append(Strings.t("role.short." + r))
	six.append(Strings.t("standings.view.table"))
	var seg6 := Segmented.new(six, 0)
	seg6.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(seg6)
	seg.visible = false
	await frames(3)
	var min_w := 9999.0
	for i in 6:
		min_w = minf(min_w, seg6.button_at(i).size.x)
	ok(seg6.mode == "equal" and seg6.stacked and min_w >= 95.5, "fit_Segmented_%s: six stacked options in 578 px are %.1f px wide each, equal mode (UI-PASS-2 11b: 96.3)" % [variant, min_w])
	host.queue_free()
	await frames(2)


# ---- colour-blind mode -----------------------------------------------------------------------------------------------

func _colour_blind() -> void:
	App.apply_large_text(false)
	UI.set_colorblind(true)
	await _fresh_main()
	var audited_total := 0
	for section in Gallery.SECTIONS:
		var g := await _show(section)
		var audited: Array = []
		var probs := _cue_problems(g, audited)
		audited_total += audited.size()
		ok(probs.is_empty(), "cb_%s_colourblind: every state-bearing control carries a cue (%d audited)" % [section, audited.size()])
		var fit := FitAudit.audit(App.main._current, UI.canvas_w())
		ok(fit.is_empty(), "fit_%s_colourblind: clean" % section)
	ok(audited_total > 40, "cb: %d state-bearing controls audited across the gallery (more than 40)" % audited_total)
	var g2 := await _show("chips")
	var good_chip: Chip = g2.items["Chip"][1]
	var bad_chip: Chip = g2.items["Chip"][2]
	ok(good_chip._colour() == UI.GOOD_CB and bad_chip._colour() == UI.BAD_CB, "cb: in colour-blind mode good and bad chips take the sky blue and orange pair")
	ok(good_chip.shown_icon() != bad_chip.shown_icon() and good_chip.plain_text() != bad_chip.plain_text(), "cb: good and bad chips differ by icon and by word, not only by colour")
	UI.set_colorblind(false)


# ---- toast --------------------------------------------------------------------------------------------------------

func _toast() -> void:
	App.apply_large_text(false)
	await _fresh_main()
	var plain := Toast.make("x", UI.TEXT)
	ok(plain is PanelContainer and CompKit.cue_of(plain) == "text", "toast: builds, text is its cue")
	plain.free()
	var cb_hits: Array = []
	var with_action := Toast.make("x", UI.TEXT, Strings.t("common.undo"), func() -> void: cb_hits.append(1))
	add_child(with_action)
	await frames(2)
	ok(with_action.size.y >= 95.5 and with_action.custom_minimum_size.y >= 96.0, "toast: with an action it is at least 96 px high (%.0f)" % with_action.size.y)
	var btn := _first_button(with_action)
	ok(btn != null and btn.size.y >= 95.5 and btn.size.x >= 149.5, "toast: the action button is %.0f x %.0f" % [btn.size.x, btn.size.y])
	btn.pressed.emit()
	await frames(3)
	ok(cb_hits.size() == 1 and not is_instance_valid(with_action), "toast: the action runs once and removes the toast")
	var before: int = App.main._toasts.get_child_count()
	App.toast(Strings.t("squad.toast.auto"))
	ok(App.main._toasts.get_child_count() == before + 1, "toast: App.toast still adds one toast to Main (API unchanged)")
	for i in 5:
		App.toast(Strings.t("squad.toast.auto"))
	await frames(2)
	ok(App.main._toasts.get_child_count() <= 3, "toast: Main keeps at most three (%d)" % App.main._toasts.get_child_count())
	var undo_hits: Array = []
	App.toast(Strings.t("squad.toast.auto"), UI.TEXT, Strings.t("common.undo"), func() -> void: undo_hits.append(1))
	await frames(2)
	var undo_btn := _first_button(App.main._toasts.get_child(App.main._toasts.get_child_count() - 1))
	undo_btn.pressed.emit()
	ok(undo_hits.size() == 1, "toast: App.toast with an Undo action still runs it")


func _first_button(n: Node) -> Button:
	if n is Button:
		return n as Button
	for c in n.get_children():
		var b := _first_button(c)
		if b != null:
			return b
	return null


# ---- units that need no gallery ---------------------------------------------------------------------------------------

func _units() -> void:
	# ListSync on a bare container, with ids kept across sync calls
	var box := VBoxContainer.new()
	add_child(box)
	var made: Array = []
	var maker := func(_k: int) -> Control:
		made.append(1)
		return Control.new()
	ListSync.sync(box, [1, 2, 3], maker)
	var first := box.get_child(0).get_instance_id()
	ListSync.sync(box, [1, 2, 3], maker)
	ok(made.size() == 3 and box.get_child(0).get_instance_id() == first, "inplace_ListSync: the same keys make nothing new")
	ListSync.sync(box, [], maker)
	ok(ListSync.shown(box).is_empty() and box.get_child_count() == 3, "inplace_ListSync: an empty key list hides all and frees none")
	box.queue_free()
	# surface hook and illustration hook are optional and unwired
	ok(not DepthCard.surface_hook.is_valid() and not EmptyState.illustration_hook.is_valid(), "hooks: DepthCard.surface_hook and EmptyState.illustration_hook are unwired placeholders for I-09")
	var card := DepthCard.new(1)
	add_child(card)
	DepthCard.surface_hook = func(_e: int, _t: Color, _s: bool, _i: bool, _p: bool) -> StyleBox: return StyleBoxEmpty.new()
	card.set_elevation(2)
	ok(card.get_theme_stylebox("panel") is StyleBoxEmpty, "hooks: a wired surface_hook supplies the card's StyleBox")
	DepthCard.surface_hook = Callable()
	card.set_elevation(0)
	ok(card.get_theme_stylebox("panel") is StyleBoxFlat, "hooks: unwiring gives the flat placeholder back")
	card.queue_free()
	await frames(1)


# ---- negative controls: each audit must catch a bad sample ---------------------------------------------------------

func _negative_controls() -> void:
	App.apply_large_text(false)
	await _fresh_main()
	var g := await _show("cards")
	# 1 fit: an unbreakable word wider than its room
	var narrow := Control.new()
	narrow.custom_minimum_size = Vector2(200, 60)
	var lab := UI.label("WWWWWWWWWWWWWWWWWWWWWWWWWWWWW", UI.S_BODY, UI.TEXT)
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	narrow.add_child(lab)
	g.body.add_child(narrow)
	# 2 hit area: a 60 x 60 button
	var tiny := Button.new()
	tiny.custom_minimum_size = Vector2(60, 60)
	tiny.text = "x"
	g.body.add_child(tiny)
	await frames(3)
	var probs := FitAudit.audit(g, UI.canvas_w())
	var has_clip := false
	var has_btn := false
	for p in probs:
		has_clip = has_clip or String(p).begins_with("clipped")
		has_btn = has_btn or String(p).begins_with("button")
	ok(has_clip, "negative control: the fit audit catches a word wider than its room")
	ok(has_btn, "negative control: the fit audit catches a 60 x 60 button")
	var small: Array = []
	_small_buttons(g, small)
	ok(not small.is_empty(), "negative control: the hit-area walk catches the 60 x 60 button")
	var wide := Control.new()
	wide.custom_minimum_size = Vector2(900, 40)
	g.body.add_child(wide)
	await frames(2)
	var over := false
	for p in FitAudit.audit(g, UI.canvas_w()):
		over = over or String(p).begins_with("overflow")
	ok(over, "negative control: the fit audit still catches a 900 px control on a page (the horizontal-scroller exemption is not blanket)")
	wide.queue_free()
	narrow.queue_free()
	tiny.queue_free()
	# 3 cue audit: a selected card with its cue erased
	var card := g.items["DepthCard"][1] as DepthCard
	ok(_cue_problems(g).is_empty(), "negative control: before the fault the cue audit is clean")
	card.set_meta(CompKit.CUE, "")
	ok(not _cue_problems(g).is_empty(), "negative control: the cue audit catches a selected card with no cue")
	card.set_meta(CompKit.CUE, "ring+check")
	var bare := Control.new()
	bare.set_meta(CompKit.STATE_BEARING, true)
	g.body.add_child(bare)
	ok(not _cue_problems(g).is_empty(), "negative control: the cue audit catches a state-bearing control that never set a cue")
	bare.queue_free()
	# 4 in-place detector: a rebuild changes instance ids
	var ids := _ids(g)
	var host: Node = g.items["DepthCard"][0].get_parent()
	var first: Node = host.get_child(0)
	host.remove_child(first)
	first.queue_free()
	var again := DepthCard.new(0)
	host.add_child(again)
	host.move_child(again, 0)
	ok(_ids(g) != ids, "negative control: the in-place check sees a deleted and rebuilt card (ids differ)")
	# 5 shadow gate: seven raised cards and three selected ones
	var pile := VBoxContainer.new()
	g.body.add_child(pile)
	for i in 7:
		pile.add_child(DepthCard.new(1))
	for i in 3:
		pile.add_child(DepthCard.new(0, Color(0, 0, 0, 0), true))
	var cnt: Dictionary = Gate.count_shadows(pile)
	ok(int(cnt["shadows"]) == 7 and int(cnt["glows"]) == 3, "negative control: the shadow count sees 7 shadows and 3 glows (%s), over the limits 6 and 2" % str(cnt))
	var verdict: Dictionary = Gate.judge("neg", {"nodes": 50, "draws": 30, "canvas": 100, "tex": 1, "vid": 1, "tree": 80, "shadows": cnt["shadows"], "glows": cnt["glows"]}, {"hard": {"shadows": 6, "glows": 2, "draws": 100, "nodes": 200}, "target": {}, "rows": {}})
	ok(not (verdict["fails"] as Array).is_empty(), "negative control: perf_gate.judge fails a state with 7 shadows and 3 glows (%d failures)" % (verdict["fails"] as Array).size())
	pile.queue_free()
	# 6 six-option strip is 96 px wide at 578, seven is not (the spec limit)
	var host2 := Control.new()
	host2.size = Vector2(578, 120)
	App.main.add_child(host2)
	var seven: Array = []
	for r in 7:
		seven.append("Mid")
	var seg := Segmented.new(seven, 0)
	seg.set_anchors_preset(Control.PRESET_FULL_RECT)
	host2.add_child(seg)
	await frames(3)
	ok(seg.button_at(0).size.x < 95.5 or seg.mode == "scroll", "negative control: seven stacked options are over the spec's limit of six (%.1f px, %s)" % [seg.button_at(0).size.x, seg.mode])
	host2.queue_free()
	# 7 counter control: a different value must move the counter (so 'equal changes nothing' is not vacuous)
	var chip := Chip.new("a")
	var a0 := chip.applied
	chip.set_text("b")
	ok(chip.applied == a0 + 1, "negative control: a changed text does move the applied counter")
	chip.free()
	await frames(1)
