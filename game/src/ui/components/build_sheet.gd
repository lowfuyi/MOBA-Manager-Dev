class_name BuildSheet
extends RefCounted
## The build editor (Phase 5, Founder decision 3: builds are coach-suggested and editable by the manager). A bottom sheet with
## the six items of one player's build on one hero, boots first. Tap a slot to swap it for another legal item of the same kind
## (boots for boots, a finished item for a finished item, never a duplicate); Reset puts the coach's suggestion back. The
## build is saved per player and hero (GameState.set_build, the additive save key "builds") and is played from the next game.
## The draft's Builds sheet (`open_draft`) lists your five picks with the coach's build against the actual enemy draft.


static func item_name(iid: String) -> String:
	return String(SimData.item(iid)["name"])


static func items_label(build: Array) -> Label:
	var names: Array = []
	for iid in build:
		names.append(item_name(String(iid)))
	var l := UI.label(", ".join(names), UI.S_SMALL, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A build as a row of item icons (one draw call) with the names under it (0.12 Q5).
static func items_view(build: Array) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(ItemIcons.Row.new(build))
	v.add_child(items_label(build))
	return v


## The build a player plays on a hero: the saved edit, else the coach's suggestion against `enemy`.
static func current(pid: String, hid: String, slot: String, enemy: Array) -> Array:
	var b: Array = App.gs.build_for(pid, hid)
	return b if Items.is_legal(b) else Items.suggest(hid, slot, enemy)


static func open_for(pid: String, hid: String, slot: String, enemy: Array, on_close: Callable = Callable()) -> void:
	var title := Strings.f("build.title", {"hero": String(SimData.heroes()[hid]["name"])})
	BottomSheet.open(title, func(c: Control) -> void: _editor(c, pid, hid, slot, enemy, on_close), Callable(), "L", "build_editor")


static func _editor(c: Control, pid: String, hid: String, slot: String, enemy: Array, on_close: Callable) -> void:
	var build := current(pid, hid, slot, enemy)
	var hint := UI.label(Strings.t("build.hint"), UI.S_SMALL, UI.TEXT2)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(hint)
	for i in build.size():
		var iid := String(build[i])
		var it := SimData.item(iid)
		var b := UI.button("%d. %s" % [i + 1, String(it["name"])], func(): _choose(pid, hid, slot, enemy, i, on_close), "normal")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = ItemIcons.tex(iid)
		UI.tag(b, "build.slot.%d" % i, false)
		c.add_child(b)
		if String(it["text"]) != "":
			c.add_child(UI.label(String(it["text"]), UI.S_CAPTION, UI.TEXT2))
	var reset := UI.button(Strings.t("build.reset"), func():
		App.gs.set_build(pid, hid, [])
		BottomSheet.current().close()
		if on_close.is_valid():
			on_close.call(), "normal")
	UI.tag(reset, "build.reset", false)
	c.add_child(reset)


## The legal replacements for slot i: the same kind (boots or finished), not already in the build.
static func choices(build: Array, i: int) -> Array:
	var boots := String(SimData.item(String(build[i]))["tier"]) == "boots"
	var out: Array = []
	for iid in (Items.boots_ids() if boots else Items.finished_ids()):
		if not (iid in build):
			out.append(iid)
	out.sort()
	return out


static func _choose(pid: String, hid: String, slot: String, enemy: Array, i: int, on_close: Callable) -> void:
	var build := current(pid, hid, slot, enemy)
	var opts := choices(build, i)
	BottomSheet.open(Strings.t("build.choose"), func(c: Control) -> void:
		for iid in opts:
			var it := SimData.item(iid)
			var b := UI.button(String(it["name"]), func():
				var nb := build.duplicate()
				nb[i] = iid
				App.gs.set_build(pid, hid, nb)
				BottomSheet.current().close()
				if on_close.is_valid():
					on_close.call(), "normal")
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.icon = ItemIcons.tex(iid)
			c.add_child(b)
			if String(it["text"]) != "":
				c.add_child(UI.label(String(it["text"]), UI.S_CAPTION, UI.TEXT2)), Callable(), "L", "build_choose")


## The draft's Builds sheet: your five picks, each with the build it will play (the saved edit or the coach's against the
## enemy's actual picks) and an Edit button.
static func open_draft(d: Draft, my_side: String) -> void:
	var enemy: Array = []
	var other := "R" if my_side == "B" else "B"
	for s in Draft.SLOTS:
		if d.picks[other].has(s):
			enemy.append(String(d.picks[other][s]["id"]))
	BottomSheet.open(Strings.t("build.draft_title"), func(c: Control) -> void:
		for s in Draft.SLOTS:
			if not d.picks[my_side].has(s):
				continue
			var hid := String(d.picks[my_side][s]["id"])
			var pid := String(d.lineups[my_side][s]["id"])
			c.add_child(UI.label("%s · %s" % [Strings.t("role.short." + s), String(SimData.heroes()[hid]["name"])], UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
			c.add_child(items_view(current(pid, hid, s, enemy)))
			var eb := UI.button(Strings.t("hero.build.edit"), func():
				BottomSheet.current().close()
				open_for(pid, hid, s, enemy, func(): open_draft(d, my_side)), "normal")
			UI.tag(eb, "build.draft.edit." + s, false)
			c.add_child(eb), Callable(), "L", "build_draft")
