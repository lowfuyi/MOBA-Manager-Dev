class_name ScreenClubSelect
extends Screen


func go_back() -> void:
	App.go(ScreenTitle.new())


func _ready() -> void:
	setup(Strings.t("club.pick.title"), go_back)
	body.add_child(UI.label(Strings.t("club.pick.hint"), UI.S_SMALL, UI.DIM))
	var rows: Array = []
	for cid in App.world.club_ids:
		rows.append([cid, App.world.team_rating(App.world.best_lineup(cid))])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	for i in rows.size():
		var cid: String = rows[i][0]
		var tr: float = rows[i][1]
		var club: Dictionary = App.world.clubs[cid]
		var c := UI.card(body)
		var tier := "club.tier.contender" if i < 3 else ("club.tier.midtable" if i < 7 else "club.tier.underdog")
		c.add_child(UI.label(club["name"], UI.S_BODY + 4, UI.TEXT))
		c.add_child(UI.label(Strings.f("club.pick.line", {"rating": "%.1f" % tr, "tier": Strings.t(tier), "rank": i + 1}), UI.S_SMALL, UI.DIM))
		c.add_child(UI.button(Strings.t("club.pick.choose"), _choose.bind(cid), "primary" if i == 3 else "normal", 76))


func _choose(cid: String) -> void:
	var seed_value: int = int(Time.get_unix_time_from_system()) % 1000000007
	App.gs = GameState.new_game(App.world, cid, seed_value)
	App.autosave()
	App.go(ScreenHub.new())
