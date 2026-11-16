extends RefCounted
## Matrix module "plan" (I-10): pictures of the gallery sections plan (PhaseStrip, DetentTrack) and standings (Podium, RankRow), plus the
## numbers that need a renderer, measured against PERF-BUDGET 3.1a (redesigned screen: target 60 draw calls and 120 nodes, hard limit
## 100 and 200):
##   PLAN|<variant>|<section>|nodes=..|draw_calls=..|objects=..|tex_mem=..      one line per picture (like the gallery and cards modules)
##   PLAN|<variant>|rig_<name>|calls=..|over_empty=..|nodes=..                   a rig on a scrolling page, against the same page with
##                                                                              nothing on it: one strip, one track, seven tracks, the
##                                                                              podium, ten rows, a whole Standings table, a whole Game Plan
##                                                                              page (strip + edge hero + three tracks + jungle focus + footer)
## The hard limit (100 draw calls, 200 nodes) failing is added to ctx.problems, so the runner exits 1; the target (60 / 120) is only
## reported. Run (serially: renders share user:// settings):
##   SHOT_DIR=<dir> SCREENS=plan VARIANTS=normal,large,cb,tall xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 res://tests/shots_matrix.tscn

const Gallery = preload("res://tests/components_gallery.gd")
const SECTIONS := ["plan", "standings"]
const HARD_CALLS := 100
const HARD_NODES := 200


static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


static func _calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


static func _frame(ctx) -> void:
	for i in 3:
		await ctx.get_tree().process_frame
	await RenderingServer.frame_post_draw


static func _measure(ctx, section: String) -> void:
	await _frame(ctx)
	var cur: Control = ctx.cur()
	print("PLAN|%s|%s|nodes=%d|draw_calls=%d|objects=%d|tex_mem=%d" % [ctx.variant, section, _count(cur), _calls(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))])


## A screen-like page (a ScrollContainer in a full-rect Control) with `content` in its column, or a filler when there is none.
static func _screen(content: Array) -> Control:
	var scr := Control.new()
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var page := ScrollContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scr.add_child(page)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	page.add_child(col)
	if content.is_empty():
		var filler := Control.new()
		filler.custom_minimum_size = Vector2(0, 2900)
		col.add_child(filler)
	for c in content:
		col.add_child(c)
	return scr


static func _rig(ctx, name: String, content: Array, empty_calls: int) -> void:
	var scr := _screen(content)
	App.go(scr)
	await _frame(ctx)
	var calls := _calls()
	var nodes := _count(scr)
	print("PLAN|%s|rig_%s|calls=%d|over_empty=%d|nodes=%d" % [ctx.variant, name, calls, calls - empty_calls, nodes])
	if calls > HARD_CALLS or nodes > HARD_NODES:
		ctx.problems.append("plan_%s: rig %s is %d draw calls and %d nodes (hard limits %d and %d)" % [ctx.variant, name, calls, nodes, HARD_CALLS, HARD_NODES])
	await ctx.shot("rig_" + name)


static func _track(id: String, v: int) -> DetentTrack:
	return DetentTrack.new(id, v)


static func _rows(n: int, first_rank: int, own_rank: int) -> Array:
	var st: Array = App.gs.standings()
	var out: Array = []
	for i in n:
		var r: Dictionary = st[(first_rank - 1 + i) % st.size()]
		out.append({"rank": first_rank + i, "club": r["club"], "name": App.gs.club_name(r["club"]), "main": str(r["pts"]), "sub": "%d-%d" % [r["w"], r["l"]], "own": r["club"] == App.gs.club() or first_rank + i == own_rank})
	return out


static func run(ctx) -> void:
	await ctx.start_game(5)
	for section in SECTIONS:
		var g: Control = Gallery.new(section)
		App.go(g)
		await ctx.get_tree().process_frame
		await ctx.shot(section)
		await _measure(ctx, section)
		var sc := g.body.get_parent() as ScrollContainer
		await ctx.get_tree().process_frame
		var max_scroll := int(g.body.size.y - sc.size.y)
		var part := 1
		while max_scroll > 8 and part < 5:    # more pictures while the section is taller than the window
			sc.scroll_vertical = mini(max_scroll, part * int(sc.size.y * 0.9))
			await ctx.shot("%s%s" % [section, "bcde"[part - 1]])
			part += 1
			if sc.scroll_vertical >= max_scroll:
				break
	# the rigs
	var empty_scr := _screen([])
	App.go(empty_scr)
	await _frame(ctx)
	var empty_calls := _calls()
	print("PLAN|%s|rig_empty|calls=%d|nodes=%d" % [ctx.variant, empty_calls, _count(empty_scr)])
	await _rig(ctx, "strip", [PhaseStrip.new(PhaseStrip.default_phases(), "early", Callable(), false)], empty_calls)
	await _rig(ctx, "track", [_track("t", 50)], empty_calls)
	await _rig(ctx, "tracks7", [_track("g", 0), _track("t", -50), _track("m", 50), _track("l", 100), _track("a", -100), _track("s", 0), _track("r", 50)], empty_calls)
	var rows3 := _rows(3, 1, -1)
	await _rig(ctx, "podium", [Podium.new(rows3)], empty_calls)
	var ten: Array = []
	for r in _rows(10, 1, -1):
		ten.append(RankRow.new(r))
	await _rig(ctx, "rows10", ten, empty_calls)
	# a whole Standings table (Table view): the view switch, the header, the podium, the divider and rows 4 to 10, then the pinned row
	var seg := Segmented.new([Strings.t("standings.view.table"), Strings.t("standings.view.playoffs"), Strings.t("standings.view.history")], 0)
	var seg2 := Segmented.new([Strings.t("standings.metric.points"), Strings.t("standings.metric.form")], 0)
	var table: Array = [seg, SectionHeader.new(Strings.t("standings.table_h")), seg2, Podium.new(_rows(3, 1, -1))]
	var rest := _rows(7, 4, -1)
	for i in rest.size():
		table.append(RankRow.new(rest[i]))
		if i == 0:
			table.append(RankRow.divider(Strings.t("standings.playoff_line")))
	await _rig(ctx, "standings_table", table, empty_calls)
	# a whole Game Plan page for the Early phase: edge hero, strip, three tracks, jungle focus, footer
	var hero := DepthCard.new(1)
	hero.content.add_child(EdgeMeter.new(-0.315))
	hero.content.add_child(UI.label(Strings.f("gp.pv.adds", {"v": UI.pct(0.051)}), UI.S_SMALL, UI.TEXT2))
	var strip := PhaseStrip.new(PhaseStrip.default_phases(), "early", Callable(), false)
	strip.set_caption("early", Strings.f("gp.lead", {"n": 2, "m": 4}))
	strip.set_caption("mid", Strings.f("gp.lead", {"n": 0, "m": 2}))
	strip.set_caption("late", Strings.f("gp.lead", {"n": 0, "m": 2}))
	var card := DepthCard.new(1)
	card.content.add_theme_constant_override("separation", 12)
	for id in ["t", "a", "s"]:
		card.content.add_child(_track(id, 0))
	var jf_opts: Array = []
	for jf in GamePlan.JUNGLE_CHOICES:
		jf_opts.append(Strings.t("gp.jf." + jf))
	card.content.add_child(Segmented.new(jf_opts, 0))
	var foot := HBoxContainer.new()
	foot.add_child(UI.button(Strings.t("gp.coach"), func() -> void: pass, "normal"))
	foot.add_child(IconButton.new("cross", Strings.t("gp.reset")))
	foot.add_child(UI.button(Strings.t("draft.start_match"), func() -> void: pass, "primary"))
	await _rig(ctx, "gameplan_early", [hero, strip, card, foot], empty_calls)
