extends Node
## Alpha 0.8 A-02: the arena map view and its data helper. Headless (the bake does not render here; the pictures and the
## draw-call count come from tests/shots/shots_arena.gd under Xvfb). Ends with " N checks, M failures".
##   data: every lane is a chain of edges; every node is reachable; shortest walks exist from each spawn to its zone
##   flip: your Cairn is at the bottom whichever side you are; Top stays left; a canonical point and its mirror swap places
##   camera: zoom 1.0 shows the whole map; zoom is clamped to 1.3; a focus near the edge never shows past the map; to_view of
##   the focus point is the centre when it is not clamped
##   labels: TOP, MID, BOT at zoom 1.0 and no place name; at 1.3 on Stoneback its name shows and every shown label is inside
##   the view; the bake is one SubViewport updated once; the icon strip does not overlap the map

var checks := 0
var fails := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ready() -> void:
	await get_tree().process_frame
	_data()
	_flip_and_camera()
	_labels_and_bake()
	_silhouettes()
	print(" %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _data() -> void:
	var d := ArenaData.data()
	ok(not d.is_empty() and ArenaData.node_ids().size() == 57, "arena_map.json loads with 57 nodes (%d)" % ArenaData.node_ids().size())
	var chained := true
	for ln in ArenaData.lanes():
		var ns: Array = ln["nodes"]
		for i in range(1, ns.size()):
			chained = chained and ArenaData.neighbours(String(ns[i - 1])).has(String(ns[i]))
	ok(chained, "every lane is a chain of edges from gate to gate")
	var all_reach := true
	for id in ArenaData.node_ids():
		all_reach = all_reach and not ArenaData.path("B.spawn.top", String(id)).is_empty()
	ok(all_reach, "every node can be walked to from a spawn pad")
	var to_zone := {"top": "N.top.mid", "mid": "N.moonhulk", "bot": "N.bot.mid", "sup": "N.bot.mid"}
	var walks_ok := true
	var report: Array = []
	for slot in to_zone:
		for side in ["B", "R"]:
			var p := ArenaData.path("%s.spawn.%s" % [side, slot], String(to_zone[slot]))
			var secs := ArenaData.path_len_u(p) / float(d["speeds"]["walk_u_s"])
			report.append("%s.%s %.1f s" % [side, slot, secs])
			walks_ok = walks_ok and not p.is_empty() and secs < 13.5
	ok(walks_ok, "each laner walks from its pad to its lane centre before the first resolve at 13.5 s (%s)" % ", ".join(report))
	var bt := ArenaData.path_len_u(ArenaData.path("B.spawn.top", "N.top.mid"))
	var rt := ArenaData.path_len_u(ArenaData.path("R.spawn.top", "N.top.mid"))
	ok(absf(bt - rt) < 1e-6, "the map is fair: both top laners walk the same distance (%.4f and %.4f u)" % [bt, rt])
	ok(ArenaData.tower("B.top.outer").get("scoreboard", false) == true and ArenaData.tower("B.guard.l").get("scoreboard", true) == false, "lane towers count, guard towers are scenery (C5)")


func _flip_and_camera() -> void:
	for side in ["B", "R"]:
		var m := ArenaMap.new(side)
		m.size = ArenaMap.MAP
		add_child(m)
		var mine := m.to_view(ArenaData.node(side + ".cairn"))
		var theirs := m.to_view(ArenaData.node(ShowScript.other(side) + ".cairn"))
		ok(mine.y > 650.0 and theirs.y < 110.0, "you are %s: your Cairn is at the bottom (y %.0f), theirs at the top (y %.0f)" % [side, mine.y, theirs.y])
		ok(m.to_view(ArenaData.node("N.top.mid")).x < 100.0 and m.to_view(ArenaData.node("N.bot.mid")).x > 620.0, "you are %s: Top lane on the left, Bot on the right (a mirror, not a turn)" % side)
		var w := m.window()
		ok(w.position == Vector2.ZERO and w.size == ArenaMap.MAP and m.view_scale() == Vector2.ONE, "zoom 1.0 shows the whole map")
		m.look_at_point(Vector2(360, 380), 3.0)
		ok(is_equal_approx(m.zoom, 1.3), "zoom is clamped to the map's max_zoom 1.3 (%.2f)" % m.zoom)
		ok(m.arena_to_local(Vector2(360, 380)).distance_to(ArenaMap.MAP / 2.0) < 0.01, "an unclamped focus is the centre of the view")
		m.look_at_point(Vector2(5, 5), 1.3)
		var w2 := m.window()
		ok(w2.position == Vector2.ZERO and Rect2(Vector2.ZERO, ArenaMap.MAP).encloses(w2), "a focus in a corner never shows past the map edge")
		m.look_at_point(Vector2(715, 755), 1.3)
		ok(Rect2(Vector2.ZERO, ArenaMap.MAP).encloses(m.window()) and is_equal_approx(m.window().end.x, 720.0), "nor in the other corner")
		m.queue_free()
	var mb := ArenaMap.new("B")
	var mr := ArenaMap.new("R")
	var p := Vector2(0.3, 0.2)
	ok(mb.arena_px(p).is_equal_approx(mr.arena_px(Vector2(p.x, 1.0 - p.y))), "a point and its mirror swap places between the two views")
	mb.free()
	mr.free()


func _labels_and_bake() -> void:
	var m := ArenaMap.new("B")
	m.size = ArenaMap.MAP
	add_child(m)
	var ids: Array = m.visible_labels().map(func(l: Dictionary) -> String: return String(l["id"]))
	ok(ids.has("lane_top") and ids.has("lane_mid") and ids.has("lane_bot") and not ids.any(func(i: String) -> bool: return i.begins_with("place_")), "zoom 1.0: TOP, MID and BOT show, no place name (%s)" % str(ids))
	m.look_at_point(m.arena_px(ArenaData.node("N.stoneback")), 1.3)
	var labs := m.visible_labels()
	var ids2: Array = labs.map(func(l: Dictionary) -> String: return String(l["id"]))
	var inside := labs.all(func(l: Dictionary) -> bool: return Rect2(Vector2.ZERO, m.size).encloses(l["rect"]))
	ok(ids2.has("place_stoneback") and inside, "zoom 1.3 on Stoneback: its name shows and every shown label is wholly in view (%s)" % str(ids2))
	m.look_at_point(m.arena_px(ArenaData.node("N.moonhulk")), 1.3)
	var ids3: Array = m.visible_labels().map(func(l: Dictionary) -> String: return String(l["id"]))
	ok(ids3.has("place_moonhulk") and not ids3.has("lane_top") and not ids3.has("lane_bot"), "zoom 1.3 on the island: MOONHULK shows; the edge tags that would be cut hide (%s)" % str(ids3))
	var vps := m.find_children("*", "SubViewport", true, false)
	ok(vps.size() == 1 and (vps[0] as SubViewport).render_target_update_mode == SubViewport.UPDATE_ONCE, "the terrain is one SubViewport drawn once (A4)")
	var strip_ok := true
	for k in ArenaMap.ICON:
		var r := m.strip_rect(ArenaMap.ICON[k])
		strip_ok = strip_ok and r.position.x >= ArenaMap.MAP.x and Rect2(Vector2.ZERO, Vector2(ArenaMap.BAKE)).encloses(r)
	ok(strip_ok, "the icon strip lies beside the map, inside the baked texture")
	ok(m.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the map is not interactive (UI-PASS-2 6.7)")
	var n := 1 + m.get_child_count() + m.get_child(0).get_child_count()
	ok(n <= 4, "the map costs %d nodes" % n)
	m.queue_free()


## Alpha 0.8.2: each token shows the archetype of the hero its side played (res.picks), in the player's frame (you / them);
## a slot without a pick falls back to the slot's archetype.
func _silhouettes() -> void:
	var w := World.load_default()
	var res := MatchRunner.auto(w, w.best_lineup(w.club_ids[0]), w.best_lineup(w.club_ids[3]), w.make_meta("sil"), 4040, "sil", false, {})
	var m := ArenaMap.new("R")
	m.set_heroes(res)
	var ok_all := true
	for slot in ArenaMap.LETTER:
		var want_you := String(w.heroes[res["picks"]["R"][slot]]["archetype"])
		var want_them := String(w.heroes[res["picks"]["B"][slot]]["archetype"])
		ok_all = ok_all and m.archetype_of("you", slot) == want_you and m.archetype_of("them", slot) == want_them
	ok(ok_all, "silhouettes: each token takes its own side's pick's archetype (seat Red)")
	var m2 := ArenaMap.new("B")
	ok(m2.archetype_of("you", "bot") == "gunner" and m2.archetype_of("them", "sup") == "mender", "silhouettes: no pick falls back to the slot's archetype")
	m.free()
	m2.free()
