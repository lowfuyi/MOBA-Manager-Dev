class_name ScreenClub
extends Screen
## Club tab: money, the league table and the transfer market, each with a one-line status.


func tab_id() -> String:
	return "club"


func is_tab_root() -> bool:
	return true


func go_back() -> void:
	App.go_tab("home")


func _ready() -> void:
	setup(Strings.t("club.title"), Callable())
	var gs := App.gs
	var net := int(round(gs.weekly_net()))
	body.add_child(UI.tile(Strings.t("club.fin.h"), PlayerView.money(gs.cash()),
			Strings.f("club.fin.sub", {"net": "%+d" % net, "bill": PlayerView.money(gs.wage_bill()), "cap": PlayerView.money(gs.wage_cap())}),
			UI.GOOD if gs.cash() >= 0.0 else UI.BAD, func(): App.go(ScreenFinance.new())))
	var row := {}
	for r in gs.standings():
		if r["club"] == gs.club():
			row = r
	body.add_child(UI.tile(Strings.t("club.table.h"), Strings.f("hub.tile.rank", {"rank": row.get("rank", 0)}),
			Strings.f("club.table.sub", {"w": row.get("w", 0), "l": row.get("l", 0), "pts": row.get("pts", 0)}), UI.TEXT, func(): App.go(ScreenStandings.new())))
	var frank := 0
	for f in gs.form_ranking():
		if f["club"] == gs.club():
			frank = int(f["rank"])
	body.add_child(UI.tile(Strings.t("club.form.h"), Strings.f("club.form.val", {"rank": frank, "rating": int(round(gs.form_rating(gs.club())))}),
			Strings.t("club.form.sub"), UI.TEXT, func(): App.go(ScreenStandings.new("form"))))
	body.add_child(UI.tile(Strings.t("club.fa.h"), Strings.f("club.fa.count", {"n": gs.fa_players().size()}),
			Strings.f("club.fa.sub", {"n": gs.roster_slots_used(), "max": Economy.data()["max_roster"]}), UI.ACCENT, func(): App.go(ScreenFreeAgents.new("hub"))))
