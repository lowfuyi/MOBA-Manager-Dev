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
	bc.add_child(BuildSheet.items_label(Items.suggest(hid, role, [])))
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
			bc.add_child(BuildSheet.items_label(cur))
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
