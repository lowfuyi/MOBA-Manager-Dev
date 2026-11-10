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
	App.set_colorblind(false)
	gs.set_quick(false)
	App.go(ScreenFinance.new())
	await ctx.shot("finance")
	App.go(ScreenChemistry.new())
	await ctx.shot("chemistry_top")
	_scroll(ctx, 640)
	await ctx.shot("chemistry_grid")
	var cand: String = gs.d["fa"][0]
	App.go(ScreenNegotiation.new(cand, false, "fa:hub"))
	await ctx.shot("negotiation_top")
	_scroll(ctx, 1500)
	await ctx.shot("negotiation_stats")
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
