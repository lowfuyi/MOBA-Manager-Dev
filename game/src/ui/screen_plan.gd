class_name ScreenPlan
extends Screen
## Plan tab: the things the manager prepares between games (training, team chemistry, practice matches), each a tile with a live
## value, plus where the Game Plan lives. I-21b: the tiles are Home's drawn StatTiles in one TileGrid (one column: the sub lines
## are long), the I-21a tutorial tags move with them (plan.tile.training, plan.tile.chem, plan.tile.practice).

var grid: HomeKit.TileGrid


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
	grid = HomeKit.TileGrid.new()
	grid.min_cell = 600.0
	body.add_child(grid)
	var t1 := HomeKit.StatTile.new(Strings.t("plan.train.h"), Strings.f("plan.train.tired", {"n": tired}) if tired > 0 else Strings.t("plan.train.fresh"),
			Strings.f("plan.train.sub", {"t": kinds["stat"], "h": kinds["hero"], "r": kinds["rest"], "s": kinds["scrim"]}), "fatigue", func(): App.go(ScreenTraining.new()))
	t1.set_value_color(UI.WARN if tired > 0 else UI.GOOD).set_arrow("arrow_down" if tired > 0 else "arrow_flat", UI.WARN if tired > 0 else UI.TEXT2)
	var t2 := HomeKit.StatTile.new(Strings.t("plan.chem.h"), UI.pct(gs.chem_bonus()), Strings.f("plan.chem.sub", {"avg": "%.0f" % gs.bond_mean()}), "star",
			func(): App.go(ScreenChemistry.new()))
	t2.set_value_color(UI.TEAL_HI)
	var live := gs.practice_available() or gs.practice_in_progress()
	var pv: String = Strings.t("plan.practice.busy") if gs.practice_in_progress() else Strings.t("plan.practice.ready" if gs.practice_available() else "plan.practice.used")
	var t3 := HomeKit.StatTile.new(Strings.t("plan.practice.h"), pv, Strings.t("plan.practice.sub"), "play", func(): App.go(ScreenPractice.new()))
	t3.set_value_color(UI.TEAL_HI if live else UI.DIM)
	var t4 := HomeKit.StatTile.new(Strings.t("plan.heroes.h"), Strings.t("plan.heroes.v"), Strings.t("plan.heroes.sub"), "star", func(): App.go(ScreenHeroes.new()))
	var tiles := [t1, t2, t3, t4]
	for i in tiles.size():
		grid.add_child(tiles[i])
		UI.tag(tiles[i], ["plan.tile.training", "plan.tile.chem", "plan.tile.practice", "plan.tile.heroes"][i])
	var c := DepthCard.new()
	c.content.add_child(UI.label(Strings.t("plan.gp.h"), UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	var custom := not GamePlan.is_neutral(gs.plan_set()["default"]) or not (gs.plan_set()["triggers"] as Array).is_empty()
	c.content.add_child(HomeKit.ChipRow.new([[Strings.t("plan.gp.custom" if custom else "plan.gp.balanced"), "accent" if custom else "neutral", "tab_plan"]]))
	var b := UI.label(Strings.t("plan.gp.body"), UI.S_SMALL, UI.DIM)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.content.add_child(b)
	body.add_child(c)
