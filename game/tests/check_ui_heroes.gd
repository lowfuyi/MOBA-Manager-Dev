extends Node
## Phase 5 (manager layer): hero pages, the build editor and the post-match story. Ends with "check_ui_heroes: N checks, M failures".
##   heroes   the Heroes screen lists 40 heroes by role; every hero page shows the passive and four abilities in the kit's words
##   builds   an edited build is saved per player and hero, is legal, reaches the next game's context and is the build played;
##            Reset puts the coach's build back; the draft's Builds sheet opens with your five picks
##   story    a v2 report gives every one of your players one or two lines, naming the hero, with numbers from the result

var checks := 0
var fails := 0
var _main: Control


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	TutorialRunner.home_offers = false
	get_window().size = Vector2i(720, 1280)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(3)
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[2], 991)
	App.tutorial.autosave = false
	App.tutorial.bind()
	await _heroes()
	await _builds()
	_story()
	_main.queue_free()
	await frames(2)
	GameState.delete_save()
	print("check_ui_heroes: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _heroes() -> void:
	App.go(ScreenHeroes.new())
	await frames(4)
	var rows := 0
	for hid in App.world.hero_ids:
		if UI.find_tag("heroes.row." + hid) != null:
			rows += 1
	ok(rows == 40, "heroes: the list has all 40 heroes (%d)" % rows)
	var bad: Array = []
	for hid in App.world.hero_ids:
		var s := ScreenHero.new(hid)
		App.go(s)
		await frames(2)
		var text := ""
		for l in s.find_children("*", "Label", true, false):
			text += (l as Label).text + "\n"
		var k := SimData.kit(hid)
		for a in [k["passive"]] + (k["abilities"] as Array):
			if not UI.plain(text).contains(UI.plain(String(a["name"]))):
				bad.append(hid + ":" + String(a["name"]))
	ok(bad.is_empty(), "heroes: every page shows the passive and the four ability names %s" % str(bad.slice(0, 5)))


func _builds() -> void:
	var gs := App.gs
	var lu := gs.lineup()
	var pid := String(lu["bot"]["id"])
	var hid := "harkin"
	var coach := Items.suggest(hid, "bot", [])
	var edit: Array = coach.duplicate()
	var alt := BuildSheet.choices(edit, 1)
	edit[1] = alt[0]
	gs.set_build(pid, hid, edit)
	ok(gs.build_for(pid, hid) == edit and Items.is_legal(edit), "builds: an edited build is saved for the player and hero")
	gs.set_build(pid, hid, ["nonsense"])
	ok(gs.build_for(pid, hid).is_empty(), "builds: an illegal build is refused (the coach's build plays)")
	gs.set_build(pid, hid, edit)
	# the edit reaches the game: a draft with that player on that hero plays the edited build
	var g := gs.next_game()
	var d := MatchRunner.prepare(App.world, gs.lineup_for(g["blue"]), gs.lineup_for(g["red"]), gs.meta_for(0), int(gs.d["save_seed"]), g["id"], false)
	var side := "B" if g["blue"] == gs.club() else "R"
	d.finish_with_ai()
	d.picks[side]["bot"] = App.world.heroes[hid]
	var ctx := MatchRunner.context(App.world, d, gs.builds())
	ok(ctx["builds"][side].get("bot", []) == edit, "builds: the next game's context carries the edited build")
	var res := MatchRunner.finish(App.world, d, {}, gs.builds())
	ok(res["builds"][side]["bot"] == edit, "builds: the game plays the edited build")
	gs.set_build(pid, hid, [])
	ok(gs.build_for(pid, hid).is_empty() and not gs.d.get("builds", {}).has(pid), "builds: Reset puts the coach's build back")
	BuildSheet.open_draft(d, side)
	await frames(4)
	ok(BottomSheet.is_open() and UI.find_tag("build.draft.edit.bot") != null, "builds: the draft's Builds sheet lists your picks with Edit")
	BottomSheet.current().close()
	await frames(4)


func _story() -> void:
	var w := App.world
	var res := MatchRunner.auto(w, w.best_lineup(w.club_ids[0]), w.best_lineup(w.club_ids[1]), w.make_meta("story"), 5, "story:1", false, {"B": "ai", "R": "ai"})
	var st := Report.story(res, "B")
	var ok_all := st.size() == 5
	for s in ["top", "jg", "mid", "bot", "sup"]:
		var lines: Array = st.get(s, [])
		var name := String(SimData.heroes()[String(res["sim"]["per"]["B." + s]["hero"])]["name"])
		ok_all = ok_all and lines.size() >= 1 and lines.size() <= 2 and Report.story_text(lines[0], Strings).contains(name)
	ok(ok_all, "story: each of your players has one or two lines naming the hero %s" % str(st))
	var v1 := MatchRunner.auto_v1(w, w.best_lineup(w.club_ids[0]), w.best_lineup(w.club_ids[1]), w.make_meta("story"), 5, "story:1", false, {})
	ok(Report.story(v1, "B").is_empty(), "story: an old (v1) result has no story")
