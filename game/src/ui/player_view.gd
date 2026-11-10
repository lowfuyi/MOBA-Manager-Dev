class_name PlayerView
extends RefCounted
## Shared pieces for showing one player: the stat bars and the hero line used by the roster and the market.


const STAT_HELP := {"mec": "stat.help.mec", "sen": "stat.help.sen", "lan": "stat.help.lan", "tft": "stat.help.tft",
		"mac": "stat.help.mac", "com": "stat.help.com", "con": "stat.help.con", "clu": "stat.help.clu"}
const LOG_KEYS := {"signed": "career.log.signed", "released": "career.log.released", "renewed": "career.log.renewed", "birthday": "career.log.birthday",
		"title": "career.log.title", "runner_up": "career.log.runner_up", "left": "career.log.left", "best_game": "career.log.best_game"}


## Eight stat bars with "now / potential" and, when `gains` is set, this season's change in brackets.
## Tap a row to read what the stat does.
static func stat_block(parent: VBoxContainer, p: Dictionary, gains: bool = false) -> void:
	var tip := UI.label(Strings.t("stat.help.tip"), UI.S_CAPTION, UI.DIM)
	parent.add_child(tip)
	# Column widths come from the text, not from a fixed number: the longest stat name with its "?" and the widest
	# "now / potential (gain)" the row can show. What is left is the bar, so it keeps at least 120 px at large text (it was 30).
	var btn_font := UI.font("SemiBold")
	var name_w := 0.0
	for st0 in World.STATS:
		name_w = maxf(name_w, btn_font.get_string_size(Strings.t("stat." + st0) + "  ?", HORIZONTAL_ALIGNMENT_LEFT, -1, UI.S_BODY).x)
	name_w = ceilf(name_w) + 8.0 + 6.0    # the button's 4 px side margins, and a little air
	var val_font := UI.font("Medium")
	var val_w := ceilf(val_font.get_string_size("100 / 100 (+9.9)" if gains else "100 / 100", HORIZONTAL_ALIGNMENT_LEFT, -1, UI.S_SMALL).x) + 4.0
	for st in World.STATS:
		var row := UI.hbox()
		var help := UI.label(Strings.t(STAT_HELP[st]), UI.S_CAPTION, UI.ACCENT)
		help.visible = false
		var name_b := UI.button(Strings.t("stat." + st) + "  ?", func(): help.visible = not help.visible, "flat", 44)
		name_b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for sn in ["normal", "hover", "pressed", "focus"]:    # slim padding so a long stat name fits the column
			var sb: StyleBox = name_b.get_theme_stylebox(sn).duplicate()
			sb.content_margin_left = 4.0
			sb.content_margin_right = 4.0
			name_b.add_theme_stylebox_override(sn, sb)
		name_b.clip_text = true
		name_b.custom_minimum_size = Vector2(name_w, UI.BTN_H)
		name_b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(name_b)
		var bar := UI.bar(float(p["stats"][st]), 100.0, UI.ACCENT, 20)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var gain := App.gs.season_gain(p["id"], st) if gains else 0.0
		var gain_txt := "" if absf(gain) < 0.05 else " (%+.1f)" % gain
		var val := UI.num_label("%d / %d%s" % [int(round(float(p["stats"][st]))), p["potential"][st], gain_txt], UI.S_SMALL, UI.GOOD if gain >= 0.05 else UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		val.custom_minimum_size = Vector2(val_w, 0)
		val.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(val)
		parent.add_child(row)
		parent.add_child(help)
	parent.add_child(UI.label(Strings.t("stat.help.pot"), UI.S_CAPTION, UI.DIM))


## "Career with us": games, wins, kills/deaths/assists, best game and milestones (GDD 4.2). Collapsed by default.
static func career_section(parent: VBoxContainer, pid: String) -> void:
	var gs := App.gs
	var c: Dictionary = gs.career_all().get(pid, {})
	var box := UI.section(parent, Strings.t("career.h"), false)
	if c.is_empty() or int(c.get("g", 0)) == 0 and (c.get("log", []) as Array).is_empty():
		box.add_child(UI.label(Strings.t("career.none"), UI.S_SMALL, UI.DIM))
		return
	var g := int(c["g"])
	if g > 0:
		UI.kv_row(box, Strings.t("career.games"), Strings.f("career.games_v", {"g": g, "w": int(c["w"])}))
		UI.kv_row(box, Strings.t("career.winrate"), "%d%%" % int(round(100.0 * float(c["w"]) / float(g))))
		UI.kv_row(box, Strings.t("career.kda"), "%d / %d / %d" % [int(c["k"]), int(c["d"]), int(c["a"])])
		UI.kv_row(box, Strings.t("career.ratio"), "%.1f" % Career.kda_ratio(int(c["k"]), int(c["d"]), int(c["a"])), UI.ACCENT)
		if int(c["best_k"]) > 0:
			UI.kv_row(box, Strings.t("career.best"), Strings.f("career.best_v", {"k": int(c["best_k"]), "opp": gs.club_name(String(c.get("best_vs", gs.club())))}), UI.GOOD)
		var se: Dictionary = (c["by_season"] as Dictionary).get(str(int(gs.d["season"])), {})
		if not se.is_empty():
			UI.kv_row(box, Strings.t("career.season"), "%d / %d / %d  (%dg)" % [int(se["k"]), int(se["d"]), int(se["a"]), int(se["g"])])
	var log: Array = c["log"]
	if not log.is_empty():
		box.add_child(UI.label(Strings.t("career.log_h"), UI.S_SMALL, UI.TEXT))
		for i in range(log.size() - 1, maxi(-1, log.size() - 9), -1):
			var e: Dictionary = log[i]
			var a: Dictionary = (e["a"] as Dictionary).duplicate()
			if a.has("opp"):
				a["opp"] = gs.club_name(String(a["opp"]))
			var text := Strings.f(LOG_KEYS[e["k"]], a)
			box.add_child(UI.label(Strings.f("career.log_line", {"s": int(e["s"]), "text": text}), UI.S_CAPTION, UI.DIM))
	box.add_child(UI.label(Strings.t("career.note"), UI.S_CAPTION, UI.DIM))


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
