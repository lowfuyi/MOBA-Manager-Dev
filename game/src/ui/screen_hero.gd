class_name ScreenHero
extends Screen
## A hero page (Phase 5): title, archetype, role, tags and power over the game; the passive and the four abilities in the
## kit's own words; the coach's build for the hero's main role; and, for each player of your club who can play the hero, that
## player's build with an Edit button (BuildSheet). Read-only except the build edit, which only changes the saved builds.

var hid := ""


func _init(p_hid: String = "") -> void:
	super._init()
	hid = p_hid


func tab_id() -> String:
	return "plan"


func go_back() -> void:
	App.go(ScreenHeroes.new())


func _ready() -> void:
	var h: Dictionary = App.world.heroes[hid]
	var k := SimData.kit(hid)
	setup(String(h["name"]), go_back)
	var top := UI.card(body)
	top.add_child(UI.label(String(k["title"]), UI.S_HEAD, UI.ACCENT))
	var lore := UI.label(String(k["lore"]), UI.S_SMALL, UI.TEXT2)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(lore)
	var tags: Array = []
	for t in h["tags"]:
		tags.append(Strings.t("tag." + String(t)))
	top.add_child(UI.label(Strings.f("hero.line", {"arch": Strings.t("arch." + String(h["archetype"])), "role": Strings.t("role." + String(h["role_primary"])),
			"tags": ", ".join(tags)}), UI.S_SMALL, UI.TEXT))
	top.add_child(UI.label(Strings.f("hero.power", {"e": int(h["power_early"]), "m": int(h["power_mid"]), "l": int(h["power_late"])}), UI.S_SMALL, UI.TEXT2))
	top.add_child(matchup_label(hid))
	var kc := UI.card(body)
	UI.tag(kc, "hero.kit", false)
	kc.add_child(UI.label(Strings.t("hero.kit"), UI.S_HEAD, UI.ACCENT))
	_ability(kc, k["passive"], Strings.t("hero.slot.passive"))
	for a in k["abilities"]:
		_ability(kc, a, Strings.t("hero.slot." + String(a["slot"])))
	var bc := UI.card(body)
	bc.add_child(UI.label(Strings.t("hero.build"), UI.S_HEAD, UI.ACCENT))
	var role := String(h["role_primary"])
	bc.add_child(UI.label(Strings.f("hero.build.coach", {"role": Strings.t("role." + role)}), UI.S_SMALL, UI.TEXT2))
	bc.add_child(BuildSheet.items_view(Items.suggest(hid, role, [])))
	# your players who can play the hero (primary or secondary role)
	for p in App.world.club_players(App.gs.club()):
		var pr := String(p["role_primary"])
		var ps = p.get("role_secondary")
		var hs = h.get("role_secondary")
		if pr != role and (ps == null or String(ps) != role) and (hs == null or String(hs) != pr):
			continue
		var pid := String(p["id"])
		var cur: Array = App.gs.build_for(pid, hid)
		var edited: bool = not cur.is_empty()
		bc.add_child(UI.label(Strings.f("hero.build.player", {"player": String(p["name"]), "state": Strings.t("hero.build.edited" if edited else "hero.build.coach_state")}), UI.S_SMALL, UI.TEXT))
		if edited:
			bc.add_child(BuildSheet.items_view(cur))
		var eb := UI.button(Strings.t("hero.build.edit"), func(): BuildSheet.open_for(pid, hid, pr, [], func(): App.go(ScreenHero.new(hid))), "normal")
		UI.tag(eb, "hero.build.edit." + pid, false)
		bc.add_child(eb)


func _ability(c: VBoxContainer, a: Dictionary, slot_word: String) -> void:
	var head := "%s · %s" % [slot_word, String(a["name"])]
	if a.has("cd") and String(a.get("slot", "")) != "passive":
		head += "  " + Strings.f("hero.cd", {"s": "%.0f" % float(a["cd"])})
	c.add_child(UI.label(head, UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	var t := UI.label(String(a["text"]), UI.S_SMALL, UI.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(t)


## The hero's hardest opponents from game/data/hero_matchups_v1.json (ESMO Q4-8): up to three heroes this one wins clearly
## less often against, with the drop in points, or a "no clear counter" line. One label; display only.
static func matchup_label(p_hid: String) -> Label:
	var rows: Array = HeroMatchups.struggles(p_hid)
	var n := int(HeroMatchups.doc().get("games", 0))
	var text := ""
	if rows.is_empty():
		text = Strings.t("hero.vs.none")
	else:
		var parts: Array = []
		for r in rows:
			var vs := String(r["vs"])
			var nm := String((App.world.heroes.get(vs, {}) as Dictionary).get("name", vs))
			parts.append(Strings.f("hero.vs.item", {"name": nm, "d": "%.1f" % absf(float(r["delta_pts"]))}))
		text = Strings.t("hero.vs.h") + ": " + ", ".join(parts)
	text += "\n" + Strings.f("hero.vs.note", {"n": _grouped(n)})
	var l := UI.label(text, UI.S_SMALL, UI.TEXT2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.tag(l, "hero.matchups", false)
	return l


static func _grouped(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
