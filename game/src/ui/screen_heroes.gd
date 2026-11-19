class_name ScreenHeroes
extends Screen
## Heroes (Phase 5, Founder decisions of 2026-11-19): the 40 heroes by role, each a row that opens its hero page. Reached from
## the Plan tab. Read-only data (kits_v2.json); nothing here changes a game.

const ROLES := ["top", "jg", "mid", "bot", "sup"]


func tab_id() -> String:
	return "plan"


func go_back() -> void:
	App.go(ScreenPlan.new())


func _ready() -> void:
	setup(Strings.t("heroes.title"), go_back)
	for role in ROLES:
		var c := UI.card(body)
		c.add_child(UI.label(Strings.t("role." + role), UI.S_HEAD, UI.ACCENT))
		var ids: Array = []
		for hid in App.world.hero_ids:
			if String(App.world.heroes[hid]["role_primary"]) == role:
				ids.append(hid)
		for hid in ids:
			var h: Dictionary = App.world.heroes[hid]
			var k := SimData.kit(hid)
			var b := UI.button("%s · %s" % [String(h["name"]), String(k["title"])], func(): App.go(ScreenHero.new(hid)), "normal")
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			UI.tag(b, "heroes.row." + hid, false)
			c.add_child(b)
