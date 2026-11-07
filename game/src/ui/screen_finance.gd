class_name ScreenFinance
extends Screen
## The club's money (GDD 7.6, lite): balance, weekly flow, the sponsor and a history of every payment.

var _more := false


func go_back() -> void:
	App.autosave()
	App.go(ScreenHub.new())


func _ready() -> void:
	setup(Strings.t("fin.title"), go_back)
	_rebuild()


func _rebuild() -> void:
	UI.clear(body)
	var gs := App.gs
	var o := UI.card(body, UI.PANEL2)
	o.add_child(UI.label(Strings.t("fin.balance"), UI.S_SMALL, UI.DIM))
	o.add_child(UI.label(PlayerView.money(gs.cash()), UI.S_TITLE, UI.GOOD if gs.cash() >= 0.0 else UI.BAD))
	o.add_child(UI.label(Strings.f("fin.weekly", {"income": PlayerView.money(gs.weekly_income()), "wages": PlayerView.money(gs.wage_bill()), "net": ("%+d" % int(round(gs.weekly_net())))}), UI.S_BODY, UI.TEXT))
	o.add_child(UI.label(Strings.f("fin.cap", {"bill": PlayerView.money(gs.wage_bill()), "cap": PlayerView.money(gs.wage_cap())}), UI.S_SMALL, UI.DIM))
	o.add_child(UI.label(Strings.f("fin.season_wages", {"n": PlayerView.money(gs.wage_bill() * float(gs.total_rounds()) / float(Economy.data()["rounds_per_week"]))}), UI.S_SMALL, UI.DIM))
	o.add_child(UI.label(Strings.t("fin.week_note"), UI.S_SMALL, UI.DIM))
	if gs.cash() < 0.0:
		o.add_child(UI.label(Strings.f("fin.debt", {"n": gs.debt_rounds_left()}), UI.S_BODY, UI.BAD))
	_sponsor_card()
	_history_card()


func _sponsor_line(offer: Dictionary) -> String:
	var gs := App.gs
	var r0 := gs.revenue_base()
	var goal := Strings.t("sponsor.goal.none")
	if offer["objective"] != "none":
		goal = Strings.f("sponsor.goal." + String(offer["objective"]), {"target": App.gs.sponsor_target(offer), "reward": PlayerView.money(float(offer["reward_weeks"]) * r0)})
	var weeks := float(gs.total_rounds()) / float(Economy.data()["rounds_per_week"])
	var low := (float(offer["retainer"]) * weeks + float(offer["bonus_weeks"])) * r0
	var season := Strings.f("sponsor.season", {"low": PlayerView.money(low)})
	if offer["objective"] != "none":
		season = Strings.f("sponsor.season_goal", {"low": PlayerView.money(low), "high": PlayerView.money(low + float(offer["reward_weeks"]) * r0)})
	return Strings.f("sponsor.line", {"name": Strings.t("sponsor.%s.name" % offer["id"]), "retainer": PlayerView.money(float(offer["retainer"]) * r0),
			"bonus": PlayerView.money(float(offer["bonus_weeks"]) * r0), "goal": goal, "season": season})


func _sponsor_card() -> void:
	var gs := App.gs
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("fin.sponsor_h"), UI.S_BODY, UI.ACCENT))
	if gs.sponsor_changeable():
		c.add_child(UI.label(Strings.t("fin.sponsor_pick"), UI.S_SMALL, UI.DIM))
		for offer in gs.sponsor_offers():
			c.add_child(UI.button(_sponsor_line(offer), _choose.bind(offer["id"]), "primary" if offer["id"] == gs.d["sponsor"] else "normal", 190))
		return
	c.add_child(UI.label(_sponsor_line(gs.sponsor_offer(gs.d["sponsor"])), UI.S_SMALL, UI.TEXT))
	var ob := gs.sponsor_objective()
	if not ob.is_empty():
		var key := "fin.obj.wins" if ob["kind"] == "wins" else "fin.obj.playoffs"
		c.add_child(UI.label(Strings.f(key, {"have": ob["have"], "target": ob["target"]}), UI.S_BODY, UI.GOOD if ob["met"] else UI.WARN))
	c.add_child(UI.label(Strings.t("fin.sponsor_locked"), UI.S_SMALL, UI.DIM))


func _choose(id: String) -> void:
	App.gs.set_sponsor(id)
	App.autosave()
	_rebuild()


func _history_card() -> void:
	var gs := App.gs
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("fin.history_h"), UI.S_BODY, UI.ACCENT))
	# wages and the retainer of one round share a row; everything else is its own row
	var rows: Array = []
	var by_round := {}
	for e in gs.d["ledger"]:
		var k: String = e["k"]
		if k == "wages" or k == "retainer":
			var key := "%d:%d" % [int(e["s"]), int(e["r"])]
			if not by_round.has(key):
				by_round[key] = {"s": e["s"], "r": e["r"], "net": 0.0}
				rows.append({"round": by_round[key]})
			by_round[key]["net"] += float(e["a"])
		else:
			rows.append({"e": e})
	rows.reverse()
	var shown := rows.size() if _more else mini(rows.size(), 12)
	if rows.is_empty():
		c.add_child(UI.label(Strings.t("fin.history_none"), UI.S_SMALL, UI.DIM))
	for i in shown:
		var row: Dictionary = rows[i]
		if row.has("round"):
			var r: Dictionary = row["round"]
			c.add_child(UI.label(Strings.f("fin.row_round", {"s": r["s"], "r": int(r["r"]) + 1, "net": "%+d" % int(round(float(r["net"])))}), UI.S_SMALL, UI.TEXT))
		else:
			var e: Dictionary = row["e"]
			var amt := float(e["a"])
			c.add_child(UI.label(Strings.f("fin.row", {"s": e["s"], "what": Strings.t("fin.k." + String(e["k"])), "amount": "%+d" % int(round(amt))}), UI.S_SMALL, UI.GOOD if amt >= 0.0 else UI.WARN))
	if rows.size() > 12:
		c.add_child(UI.button(Strings.t("fin.less" if _more else "fin.more"), func(): _more = not _more; _rebuild(), "normal", 70))
