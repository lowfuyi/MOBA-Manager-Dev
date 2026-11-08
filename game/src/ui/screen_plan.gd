class_name ScreenPlan
extends Screen
## Plan tab: the two things the manager prepares between games (training and team chemistry),
## each with a live status line, and where the Game Plan lives.


func tab_id() -> String:
	return "plan"


func is_tab_root() -> bool:
	return true


func go_back() -> void:
	App.go_tab("home")


func _ready() -> void:
	setup(Strings.t("plan.title"), Callable())
	var gs := App.gs
	var w := App.world
	var tired := 0
	var kinds := {"stat": 0, "hero": 0, "scrim": 0, "rest": 0}
	for p in w.club_players(gs.club()):
		var k: String = gs.focus_of(p)["k"]
		kinds[k] = int(kinds.get(k, 0)) + 1
		if w.fatigue_of(p["id"]) >= 50.0:
			tired += 1
	body.add_child(UI.tile(Strings.t("plan.train.h"), Strings.f("plan.train.tired", {"n": tired}) if tired > 0 else Strings.t("plan.train.fresh"),
			Strings.f("plan.train.sub", {"t": kinds["stat"], "h": kinds["hero"], "r": kinds["rest"], "s": kinds["scrim"]}),
			UI.WARN if tired > 0 else UI.GOOD, func(): App.go(ScreenTraining.new())))
	body.add_child(UI.tile(Strings.t("plan.chem.h"), UI.pct(gs.chem_bonus()), Strings.f("plan.chem.sub", {"avg": "%.0f" % gs.bond_mean()}),
			UI.ACCENT, func(): App.go(ScreenChemistry.new())))
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("plan.gp.h"), UI.S_BODY, UI.ACCENT))
	var custom := not GamePlan.is_neutral(gs.plan_set()["default"]) or not (gs.plan_set()["triggers"] as Array).is_empty()
	UI.chips(c, [[Strings.t("plan.gp.custom" if custom else "plan.gp.balanced"), UI.ACCENT if custom else UI.DIM]])
	c.add_child(UI.label(Strings.t("plan.gp.body"), UI.S_SMALL, UI.DIM))
