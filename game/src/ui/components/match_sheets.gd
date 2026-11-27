class_name MatchSheets
extends RefCounted
## Match Day M6: the sheets of the match screen. A hero sheet (tap a hero on the map) and a Teams sheet (tap the line-up
## panel): what a viewer could see on a broadcast at the current game time, from the ArenaPlayer (the finished game's log) and
## static data (heroes, kits, items). Any open sheet pauses the show (ScreenMatch). Display only: nothing here reads or
## changes the simulation (A1, R7). Gold and CS per hero join when the log carries them (M1).

const SLOTS := ["top", "jg", "mid", "bot", "sup"]


## What a hero is doing at game time t, in plain words, from the log only: [copy key, vars].
static func doing(pl: ArenaPlayer, key: String, t: float) -> Array:
	if not pl.alive(key, t):
		return ["match.doing.down", {"n": int(ceilf(pl.respawn_in(key, t)))}]
	if not pl.fight_of(key, t).is_empty():
		return ["match.doing.fight", {}]
	var latest := -INF
	var what := ""
	var target := ""
	for e in pl.log["ev"]:
		var et := float(e[0])
		if et > t:
			break
		if t - et > 20.0 or e.size() < 3 or str(e[2]) != key:    # str(): some events carry a number there
			continue
		match String(e[1]):
			"recall":
				if t - et <= 8.0 and et >= latest:
					latest = et
					what = "recall"
			"intent":
				if String(e[3]) in ["gank", "roam", "back_off"] and et >= latest:
					latest = et
					what = String(e[3])
					target = String(e[4]) if e.size() > 4 else ""
			"camp":
				if et >= latest:
					latest = et
					what = "camp"
			"ward":
				if t - et <= 5.0 and et >= latest:
					latest = et
					what = "ward"
	if what != "":
		var lane := target if target in ["top", "mid", "bot"] else ""
		return ["match.doing." + what, {"lane": Strings.t("role.short." + lane) if lane != "" else ""}]
	var side := ArenaPlayer.side_of(key)
	for c in pl.calls:
		if float(c[0]) <= t and t - float(c[0]) <= 20.0 and String(c[1]) == side and String(c[2]) in ["group", "siege", "defend"]:
			return ["match.doing." + String(c[2]), {}]
	var p := pl.pos(key, t)
	if p.x < 0.17 or p.x > 0.83 or absf(p.x - 0.5) < 0.06:
		return ["match.doing.lane", {"lane": Strings.t("role.short." + ("top" if p.x < 0.17 else ("bot" if p.x > 0.83 else "mid")))}]
	return ["match.doing.jungle", {}]


static func _text(c: Control, s: String, size: int, col: Color, weight: String = "") -> Label:
	var l := UI.label(s, size, col, HORIZONTAL_ALIGNMENT_LEFT, weight)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(l)
	return l


static func _team_name(names: Dictionary, side: String) -> String:
	return String(names.get(side, side))


## The hero sheet for `key` at game time t. `names` {side: club name}.
static func open_hero(pl: ArenaPlayer, key: String, t: float, names: Dictionary) -> BottomSheet:
	var hid := String(pl.hero_of[key])
	var h: Dictionary = SimData.heroes()[hid]
	return BottomSheet.open(String(h["name"]), func(c: Control) -> void: hero_body(c, pl, key, t, names), Callable(), "L", "match_hero")


static func hero_body(c: Control, pl: ArenaPlayer, key: String, t: float, names: Dictionary) -> void:
	var hid := String(pl.hero_of[key])
	var h: Dictionary = SimData.heroes()[hid]
	var k := SimData.kit(hid)
	var side := ArenaPlayer.side_of(key)
	var col := UI.ACCENT if side == pl.my_side else UI.CORAL
	_text(c, Strings.f("match.hero.line", {"arch": Strings.t("arch." + String(h["archetype"])), "role": Strings.t("role.short." + key.substr(2)),
			"team": _team_name(names, side)}), UI.S_SMALL, col, "SemiBold")
	var kda := pl.kda_of(key, t)
	var hp := int(roundf(pl.hp(key, t) * 100.0))
	_text(c, Strings.f("match.hero.stats", {"lv": pl.level_of(key, t), "hp": hp, "k": kda[0], "d": kda[1], "a": kda[2]}), UI.S_BODY, UI.TEXT)
	var dn := doing(pl, key, t)
	_text(c, Strings.f("match.hero.doing", {"what": Strings.f(String(dn[0]), dn[1])}), UI.S_SMALL, UI.TEXT2)
	_text(c, Strings.t("match.hero.items"), UI.S_BODY, UI.ACCENT)
	var inv := pl.items_of(key, t)
	if inv.is_empty():
		_text(c, Strings.t("match.hero.no_items"), UI.S_SMALL, UI.DIM)
	else:
		c.add_child(BuildSheet.items_view(inv))
	_text(c, Strings.t("match.hero.kit"), UI.S_BODY, UI.ACCENT)
	_ability(c, k["passive"], Strings.t("hero.slot.passive"))
	for a in k["abilities"]:
		_ability(c, a, Strings.t("hero.slot." + String(a["slot"])))


## One passive or ability in plain words (no ranks: our heroes have one level, not ability ranks).
static func _ability(c: Control, a: Dictionary, slot_word: String) -> void:
	var head := "%s · %s" % [slot_word, String(a["name"])]
	if a.has("cd") and String(a.get("slot", "")) != "passive":
		head += "  " + Strings.f("hero.cd", {"s": "%.0f" % float(a["cd"])})
	_text(c, head, UI.S_SMALL, UI.TEAL_HI, "SemiBold")
	_text(c, String(a["text"]), UI.S_SMALL, UI.TEXT)


## The Teams sheet: both line-ups at t, larger than the panel, with every item so far.
static func open_teams(pl: ArenaPlayer, t: float, names: Dictionary) -> BottomSheet:
	return BottomSheet.open(Strings.t("match.teams.h"), func(c: Control) -> void: teams_body(c, pl, t, names), Callable(), "L", "match_teams")


static func teams_body(c: Control, pl: ArenaPlayer, t: float, names: Dictionary) -> void:
	var them := "R" if pl.my_side == "B" else "B"
	for side in [pl.my_side, them]:
		var col := UI.ACCENT if side == pl.my_side else UI.CORAL
		_text(c, _team_name(names, side), UI.S_BODY, col, "SemiBold")
		for s in SLOTS:
			var key: String = side + "." + s
			var kda := pl.kda_of(key, t)
			var head := Strings.f("match.teams.row", {"lane": Strings.t("role.short." + s), "hero": ArenaHud2.hero_name(pl, key),
					"lv": pl.level_of(key, t), "k": kda[0], "d": kda[1], "a": kda[2]})
			if not pl.alive(key, t):    # words, not colour alone
				head += ", " + Strings.f("match.doing.down", {"n": int(ceilf(pl.respawn_in(key, t)))})
			_text(c, head, UI.S_SMALL, UI.TEXT if pl.alive(key, t) else UI.DIM)
			var inv := pl.items_of(key, t)
			if not inv.is_empty():
				c.add_child(ItemIcons.Row.new(inv))
