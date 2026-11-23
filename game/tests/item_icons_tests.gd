extends RefCounted
## Placeholder item icons (0.12, Q5): one SVG per item baked into one atlas within the texture budget; shape by tier, glyph by
## main stat; shown in the build editor, the draft's Builds sheet and the hero page. Per-archetype ability effects come from
## the arena atlas (ArenaFx2).


func run(check: Callable) -> void:
	TexCache.reset()
	var ids := ItemIcons.ids()
	var a := ItemIcons.atlas()
	var rects: Dictionary = a["rects"]
	var all_in := true
	for iid in ids:
		all_in = all_in and rects.has(iid)
	check.call(ids.size() == 51 and all_in, "item icons: every item (%d) has a cell in the atlas" % ids.size())
	check.call((a["failed"] as Array).is_empty(), "item icons: every icon bakes (%d failed)" % (a["failed"] as Array).size())
	check.call(int(a["w"]) <= 512 and int(a["h"]) <= 512, "item icons: one atlas of at most 512 x 512 (%d x %d)" % [int(a["w"]), int(a["h"])])
	check.call(TexCache.violations().is_empty(), "item icons: the texture budget holds (%s)" % str(TexCache.violations()))
	check.call(ItemIcons.main_stat(SimData.item("ironshod_treads")) == "move" and ItemIcons.main_stat(SimData.item("heartwood_stave")) == "ap"
			and ItemIcons.main_stat(SimData.item("rootbound_girdle")) == "hp", "item icons: the glyph shows the main stat (boots show speed)")
	check.call(ItemIcons.svg_of("iron_splint").contains("<circle cx='32' cy='32' r='27'") and ItemIcons.svg_of("gloamcutter").contains("<rect")
			and ItemIcons.svg_of("gloamcutter").contains("#F2C14E") and not ItemIcons.svg_of("heartwood_stave").contains("#F2C14E"),
			"item icons: a circle for a component, a square for a finished item, a gold pip only for an item with an effect")
	check.call(ItemIcons.tex("gloamcutter") is AtlasTexture and ItemIcons.tex("no_such_item") == null, "item icons: one icon as an atlas texture for a button")
	var row := ItemIcons.Row.new(["roadworn_boots", "gloamcutter", "iron_splint"])
	check.call(row.custom_minimum_size.x > 150.0 and row.items.size() == 3, "item icons: a row control lays out its icons")
	row.free()
	var v := BuildSheet.items_view(["roadworn_boots", "gloamcutter"])
	check.call(v.get_child(0) is ItemIcons.Row and v.get_child(1) is Label, "item icons: a build shows as icons with the names under them")
	v.free()
	var hero_src := FileAccess.get_file_as_string("res://src/ui/screen_hero.gd")
	var sheet_src := FileAccess.get_file_as_string("res://src/ui/components/build_sheet.gd")
	check.call(hero_src.contains("BuildSheet.items_view(") and sheet_src.contains("items_view(current(") and sheet_src.contains("b.icon = ItemIcons.tex(iid)"),
			"item icons: the hero page, the Builds sheet and the build editor show them")
	# per-archetype ability effects (arena atlas)
	var sprites_ok := true
	var heal_ok := true
	var shield_ok := true
	var dmg_sprites := {}
	for hid in SimData.kits():
		var arch := String(SimData.heroes()[hid]["archetype"])
		for ab in SimData.kit(hid)["abilities"]:
			var st := ArenaFx2.style(String(ab["id"]), arch)
			sprites_ok = sprites_ok and not st.is_empty()
			var names: Array = []
			for fx in st:
				names.append(String(fx[0]))
				sprites_ok = sprites_ok and ArenaAtlas.CELLS.has(String(fx[0]))
			if "heal" in ab["kind"]:
				heal_ok = heal_ok and "plus" in names
			if "shield" in ab["kind"]:
				shield_ok = shield_ok and "shield_fx" in names
			if "damage" in ab["kind"]:
				dmg_sprites[names[0]] = true
	check.call(sprites_ok, "ability effects: every ability of every hero has effects, all from the arena atlas")
	check.call(heal_ok and shield_ok, "ability effects: heals show a plus and shields an arc")
	check.call(dmg_sprites.size() >= 4, "ability effects: damage looks different by archetype (%s)" % str(dmg_sprites.keys()))
