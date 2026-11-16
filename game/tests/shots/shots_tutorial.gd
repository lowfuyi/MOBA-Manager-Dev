extends RefCounted
## Matrix module "tutorial" (build plan I-12): one picture per card type of the real CoachOverlay, over the real Home screen and the
## real BottomSheet, in every variant the runner is given (the plan asks for normal and large):
##   info      step 3 (the tab bar, an info step: ring, pointer, Next and Skip, the hole is blocked)
##   tap       step 4 (the Squad tab, a tap step: Skip only, the hole is open)
##   sheet     step 6 (a compact card above a real BottomSheet, the hole on the sheet's header)
##   shortcut  step 15 (Auto-finish: Skip and the one-tap "Let the Coach finish")
##   fallback  step 2 on a Home that has no `home.next_card` yet: the fallback card at the bottom, no hole
##   modal     step 1 (the welcome card, no hole)
##   tall      step 12 with a target as tall as the screen: the hole is clipped above the card
## The screens behind are Home and stand-in controls from tests/tutorial_stub.gd (the later screens do not carry the tags yet), so the
## pictures show the overlay, not the final screens. Output: tutorial_<state>_<variant>.png. Run:
##   SHOT_DIR=<dir> SCREENS=tutorial VARIANTS=normal,large xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 res://tests/shots_matrix.tscn

const Stub = preload("res://tests/tutorial_stub.gd")
const TEMP_CFG := "user://tut_shots.cfg"


static func _at(ctx, sid: String) -> void:
	var t: Dictionary = TutorialState.new_state()
	t["state"] = "running"
	t["step"] = sid
	App.gs.set_tutorial(t)
	App.tutorial.bind(false)
	for i in 120:
		await ctx.get_tree().process_frame
		var o := App.tutorial.overlay
		if o != null and (o.mode == "shown" or o.mode == "fallback"):
			break
	await ctx.settle()


static func run(ctx) -> void:
	await ctx.start_game(5)
	var r: TutorialRunner = App.tutorial
	r.autosave = false
	r.device = DeviceState.new(TEMP_CFG)
	r.wait_s = 0.4
	r.missing_s = 0.3
	var stub: Stub.Stub = Stub.add_to(App.main)
	await ctx.settle()
	var vp: Vector2 = ctx.get_viewport().get_visible_rect().size
	await _at(ctx, "tabs")
	await ctx.shot("info")
	await _at(ctx, "tab_squad")
	await ctx.shot("tap")
	# sheet: a real BottomSheet with a player-card header tagged roster.card.head
	var s := BottomSheet.open("Player card", func(c: VBoxContainer) -> void:
		var head := PanelContainer.new()
		head.custom_minimum_size = Vector2(0, 120)
		var row := VBoxContainer.new()
		row.add_child(UI.label("Tiredness, form and morale", UI.S_BODY, UI.TEXT))
		head.add_child(row)
		c.add_child(head)
		UI.tag(head, "roster.card.head", false)
		for n in ["Tiredness", "Form", "Morale"]:
			c.add_child(UI.label(n, UI.S_SMALL, UI.TEXT2))
			c.add_child(UI.bar(55.0, 100.0, UI.ACCENT, 16)), Callable(), "M", "shots")
	await ctx.settle()
	await _at(ctx, "player_card")
	await ctx.shot("sheet")
	s.close()
	await ctx.settle()
	# shortcut: the Auto-finish button in the header
	var auto := stub.make_button("draft.auto_rest", 260.0)
	auto.text = UI.tidy("Auto-finish")
	auto.position = Vector2(vp.x - 300.0, 130.0)
	await _at(ctx, "coach_rest")
	await ctx.shot("shortcut")
	auto.queue_free()
	# fallback: Home has no `home.next_card` yet
	await _at(ctx, "home_card")
	await ctx.shot("fallback")
	# modal: the welcome card
	r.bind(false)
	r.accept()
	await ctx.settle()
	for i in 20:
		await ctx.get_tree().process_frame
	await ctx.shot("modal")
	# tall target: a block as tall as the screen, the hole is clipped above the card
	var tall := stub.make_button("draft.choices", vp.x - 120.0)
	tall.custom_minimum_size.y = vp.y - 260.0
	tall.size.y = vp.y - 260.0
	tall.position = Vector2(60.0, 120.0)
	await _at(ctx, "ban")
	await ctx.shot("tall")
	tall.queue_free()
	r.bind(false)
	stub.queue_free()
	await ctx.settle()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
