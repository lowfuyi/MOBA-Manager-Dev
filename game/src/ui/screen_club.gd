class_name ScreenClub
extends Screen
## Club tab: money, the league table, Form Rating and the transfer market, each a tile with a live value. I-21b: Home's drawn
## StatTiles in one TileGrid (one column); the I-21a tags move with them (club.tile.finance, club.tile.form, club.tile.fa).

var grid: HomeKit.TileGrid


func tab_id() -> String:
	return "club"


func is_tab_root() -> bool:
	return true


func go_back() -> void:
	App.go_tab("home")


func _ready() -> void:
	setup(Strings.t("club.title"), Callable())
	var gs := App.gs
	grid = HomeKit.TileGrid.new()
	grid.min_cell = 600.0
	body.add_child(grid)
	var net := int(round(gs.weekly_net()))
	var t_fin := HomeKit.StatTile.new(Strings.t("club.fin.h"), PlayerView.money(gs.cash()),
			Strings.f("club.fin.sub", {"net": "%+d" % net, "bill": PlayerView.money(gs.wage_bill()), "cap": PlayerView.money(gs.wage_cap())}), "cash",
			func(): App.go(ScreenFinance.new()))
	t_fin.set_value_color(UI.TEXT if gs.cash() >= 0.0 else UI.BAD).set_arrow("arrow_up" if net > 0 else ("arrow_down" if net < 0 else "arrow_flat"), UI.delta_color(float(net)))
	var row := {}
	for r in gs.standings():
		if r["club"] == gs.club():
			row = r
	var t_tab := HomeKit.StatTile.new(Strings.t("club.table.h"), Strings.f("home.rank_of", {"rank": row.get("rank", 0), "n": App.world.club_ids.size()}),
			Strings.f("club.table.sub", {"w": row.get("w", 0), "l": row.get("l", 0), "pts": row.get("pts", 0)}), "trophy", func(): App.go(ScreenStandings.new()))
	var frank := 0
	for f in gs.form_ranking():
		if f["club"] == gs.club():
			frank = int(f["rank"])
	var t_form := HomeKit.StatTile.new(Strings.t("club.form.h"), Strings.f("club.form.val", {"rank": frank, "rating": int(round(gs.form_rating(gs.club())))}),
			Strings.t("club.form.sub"), "form", func(): App.go(ScreenStandings.new("form")))
	var t_fa := HomeKit.StatTile.new(Strings.t("club.fa.h"), Strings.f("club.fa.count", {"n": gs.fa_players().size()}),
			Strings.f("club.fa.sub", {"n": gs.roster_slots_used(), "max": Economy.data()["max_roster"]}), "contract", func(): App.go(ScreenFreeAgents.new("hub")))
	t_fa.set_value_color(UI.TEAL_HI)
	for t in [[t_fin, "club.tile.finance"], [t_tab, "club.tile.table"], [t_form, "club.tile.form"], [t_fa, "club.tile.fa"]]:
		grid.add_child(t[0])
		UI.tag(t[0], String(t[1]))
