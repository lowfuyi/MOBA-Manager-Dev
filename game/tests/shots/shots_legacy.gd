extends RefCounted
## Matrix module "legacy": the screens that are not redesigned in 0.7 (I-04), in the states where text fit and the
## hidden problems of the fit audit show: Settings with the switches on, Finance with five digits, Chemistry grid and
## pentagon, the stat bars on the Negotiation page, Training picker, Pre-match, Practice, Season end, Game over, Match.
## Pictures: legacy_<state>_<variant>.png. Run: SCREENS=legacy VARIANTS=normal,large (see shots_matrix.gd).


static func _scroll(ctx, y: int) -> void:
	var sc := ctx.cur().body.get_parent() as ScrollContainer
	sc.scroll_vertical = y


static func run(ctx) -> void:
	await ctx.start_game(5)    # Northreach Corsairs: the longest club name (19 characters)
	App.gs.d["cash"] = 123456.0
	var gs := App.gs
	App.go(ScreenSettings.new())
	await ctx.shot("settings_off")
	gs.set_quick(true)
	App.set_colorblind(true)
	ctx.cur()._rebuild()
	await ctx.shot("settings_on")
	_scroll(ctx, 700)    # Alpha 0.8.1: the Frame rate card under Animations
	await ctx.shot("settings_fps")
	_scroll(ctx, 1000)    # Alpha 0.8.2: the Sound and vibration card under Frame rate
	await ctx.shot("settings_sound")
	App.set_colorblind(false)
	gs.set_quick(false)
	App.go(ScreenFinance.new())
	await ctx.shot("finance")
	# 0.12 Q4-5: the Last rounds chart with data: six games played on a copy of the save, then the real save is back
	var keep := App.gs
	App.gs = GameState.from_dict(App.world, JSON.parse_string(JSON.stringify(keep.d)))
	for i in 12:
		var g6 := App.gs.next_game()
		if g6.is_empty():
			break
		App.gs.record_human_game(g6, App.gs.auto_game(g6))
	App.go(ScreenFinance.new())
	await ctx.shot("finance_flow")
	# 0.12 Q4-6: achievements and club records on a starter's Career tab (same played copy)
	var rs := ScreenRoster.new("hub")
	App.go(rs)
	await ctx.settle()
	rs._toggle_player(String(App.gs.d["lineup"]["jg"]))
	await ctx.settle()
	rs._set_card_tab("career")
	await ctx.settle()
	await ctx.shot("career_honours")
	if BottomSheet.is_open():
		BottomSheet.current().close()
		await ctx.settle()
	App.gs = keep
	App.go(ScreenChemistry.new())
	await ctx.shot("chemistry_top")
	_scroll(ctx, 640)
	await ctx.shot("chemistry_grid")
	var cand: String = gs.d["fa"][0]
	var negs := ScreenNegotiation.new(cand, false, "fa:hub")
	App.go(negs)
	await ctx.shot("negotiation_top")
	_scroll(ctx, 1500)
	await ctx.shot("negotiation_stats")
	var starters: Array = gs.lineup().values().map(func(x): return String(x["id"]))
	for rid in (gs.d["roster"] as Array).duplicate():    # make room on a full squad so the offer can be made
		if gs.roster_slots_used() < int(Economy.data()["max_roster"]):
			break
		if not starters.has(String(rid)):
			gs.release(String(rid))
	negs._wage = maxi(1, int(round(float(gs.asking_wage(cand)) * 0.85)))
	negs._make_offer()    # a refusal with the factors it weighed (0.12, Q4-3)
	_scroll(ctx, 520)
	await ctx.shot("negotiation_refused")
	var trs := ScreenTraining.new()
	App.go(trs)
	trs._toggle(App.world.club_players(gs.club())[0]["id"])
	await ctx.shot("training_picker")
	App.go(ScreenFreeAgents.new("hub"))
	await ctx.shot("free_agents")
	var g: Dictionary = gs.next_game()
	App.go(ScreenPreMatch.new(g))
	await ctx.shot("prematch")
	var m := ScreenMatch.new(g, gs.auto_game(g))
	App.go(m)
	await ctx.get_tree().process_frame
	for i in 5:
		m._process(5.0)
	await ctx.shot("match_mid")
	m._skip()
	await ctx.shot("match_end")
	m._finished = true
	m.set_process(false)
	gs.autoplay(true)
	App.go(ScreenSeasonEnd.new())
	await ctx.shot("season_end")
	gs.d["dismissed"] = true
	App.go(ScreenGameOver.new())
	await ctx.shot("game_over")
	gs.d["dismissed"] = false
