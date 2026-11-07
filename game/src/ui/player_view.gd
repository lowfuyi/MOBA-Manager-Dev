class_name PlayerView
extends RefCounted
## Shared pieces for showing one player: the stat bars and the hero line used by the roster and the market.


## Eight stat bars with "now / potential" and, when `gains` is set, this season's change in brackets.
static func stat_block(parent: VBoxContainer, p: Dictionary, gains: bool = false) -> void:
	for st in World.STATS:
		var row := UI.hbox()
		var name_l := UI.label(Strings.t("stat." + st), UI.S_SMALL, UI.TEXT)
		name_l.custom_minimum_size = Vector2(230, 0)
		name_l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(name_l)
		var bar := UI.bar(float(p["stats"][st]), 100.0, UI.ACCENT, 20)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var gain := App.gs.season_gain(p["id"], st) if gains else 0.0
		var gain_txt := "" if absf(gain) < 0.05 else " (%+.1f)" % gain
		var val := UI.label("%d / %d%s" % [int(round(float(p["stats"][st]))), p["potential"][st], gain_txt], UI.S_SMALL, UI.GOOD if gain >= 0.05 else UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		val.custom_minimum_size = Vector2(190, 0)
		val.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(val)
		parent.add_child(row)


static func best_heroes_line(parent: VBoxContainer, p: Dictionary) -> void:
	var w := App.world
	var fams: Array = []
	for hid in w.hero_ids:
		fams.append([w.familiarity(p, hid), hid])
	fams.sort_custom(func(a, b): return a[0] > b[0])
	var names: Array = []
	for i in 3:
		names.append("%s %.0f" % [w.heroes[fams[i][1]]["name"], fams[i][0]])
	parent.add_child(UI.label(Strings.f("roster.best_heroes", {"list": ", ".join(names)}), UI.S_SMALL, UI.GOOD))


## "52 a week, 2 seasons left" for a player under contract.
static func contract_text(pid: String) -> String:
	var gs := App.gs
	var c := gs.contract_of(pid)
	if c.is_empty():
		return ""
	var left := gs.seasons_left(pid)
	var tail := Strings.t("contract.expires") if left <= 0 else (Strings.t("contract.final") if left == 1 else Strings.f("contract.left", {"n": left}))
	return Strings.f("contract.line", {"wage": int(c["wage"]), "left": tail})


static func money(x: float) -> String:
	var n := int(round(absf(x)))
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if x < -0.5 else "") + s + out
