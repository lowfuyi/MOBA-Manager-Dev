extends Node
## I-12 checks, part 1 (headless): the REAL CoachOverlay, TutorialRunner, Main and BottomSheet, with tests/tutorial_stub.gd supplying
## the tagged controls that the later screens (I-15 to I-21) will carry. The finger rows (the 8 S2 rows of SPIKE-RESULTS-0.7, drags,
## scrolling inside a sheet) are in tests/check_touch_tutorial.gd. Rows:
##   run_<variant>    all 27 steps walked by real taps at the hole centre (and the card buttons), in normal, large (626 px) and tall
##                    (720 x 1560) text: the hole is the target plus 8 px, the card is inside the safe area, never covers the hole,
##                    at most 45 percent (35 percent compact) of the height, buttons 96 px, text 24 px or more, unclipped
##   geometry         follows a moving target and does not recompute for a still one, waits 2 frames for layout, scrolls a target
##                    into view through nested scroll areas, clips the hole of a tall target, fallback card, one animation at a time
##   flow             survives Main.show_screen, Skip then Undo (and the 4.5 s expiry), Back key, step 27 Back, no overlay node left
##   cost             no process work while idle, few nodes, no per-frame allocations, per-frame time
## The window is set to 720 x 1280 first (a headless one is 100 x 100). Ends with " N checks, M failures".

const Stub = preload("res://tests/tutorial_stub.gd")
const TEMP_CFG := "user://tut_overlay_test.cfg"

var checks := 0
var fails := 0
var sim
var _main: Control
var _stub: Stub.Stub
var _worst := {}


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


## Wait until `cond` is true or `max_frames` frames passed. Returns whether it became true.
func until(cond: Callable, max_frames: int = 60) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


## Wait up to `secs` of real time for `cond` (headless frames run faster than 60 per second, tweens run on real time).
func until_s(cond: Callable, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < secs:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	sim = load("res://tests/spikes/touch_sim.gd").new(self)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	for variant in ["normal", "large", "tall", "anim"]:
		await _set_variant(variant)
		await _fresh_main()
		await _run_27(variant)
	await _set_variant("normal")
	await _fresh_main()
	await _geometry()
	await _fallback_run()
	await _flow()
	await _cost()
	App.apply_large_text(false)
	UI.animate = true
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("max card height: normal %s, large %s, tall %s" % [str(_worst.get("normal", 0)), str(_worst.get("large", 0)), str(_worst.get("tall", 0))])
	print("check_tutorial_overlay: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _set_variant(variant: String) -> void:
	# "anim" is the normal size with animations ON (the others run without tweens so every number is the final one)
	App.apply_large_text(variant == "large")
	get_window().size = Vector2i(720, 1560) if variant == "tall" else Vector2i(720, 1280)
	await frames(3)


## A fresh Main, a new save at Home, the runner pointed at a temp device file, no autosave, short waits.
func _fresh_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await frames(2)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(3)
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], 20261109)
	App.go(ScreenHub.new())
	await frames(3)
	var r: TutorialRunner = App.tutorial
	r.autosave = false
	r.device = DeviceState.new(TEMP_CFG)
	r.wait_s = 0.4
	r.missing_s = 0.3
	_stub = Stub.add_to(_main)
	await frames(2)


func _overlay() -> CoachOverlay:
	return App.tutorial.overlay if App.tutorial != null else null


func _shown() -> bool:
	var o := _overlay()
	return o != null and (o.mode == "shown" or o.mode == "fallback")


func _union(ids: Array) -> Rect2:
	var u := Rect2()
	var first := true
	for id in ids:
		var c := UI.find_tag(String(id))
		if c == null:
			return Rect2()
		u = c.get_global_rect() if first else u.merge(c.get_global_rect())
		first = false
	return u


func _count_nodes(n: Node) -> int:
	var t := 1
	for c in n.get_children():
		t += _count_nodes(c)
	return t


# ---- the 27 steps ----------------------------------------------------------------------------------------------------------------

func _run_27(variant: String) -> void:
	var r: TutorialRunner = App.tutorial
	var gs: GameState = App.gs
	var vp0 := _main.get_viewport_rect().size
	ok(absf(vp0.x - (UI.canvas_w())) < 1.0 and (vp0.y > 1500.0 if variant == "tall" else vp0.y < 1300.0), "run %s: the logical screen is %s (large text is 626 wide, tall is 720 x 1560)" % [variant, str(vp0)])
	ok(r.m != null and r.m.state() == "new" and r.overlay == null, "run %s: a new save is state new and no overlay exists yet (the overlay slot is empty)" % variant)
	ok(App.main.overlay_layer.get_child_count() == 0, "run %s: nothing is in the overlay slot before a step" % variant)
	var before: Dictionary = gs.d.duplicate(true)
	before.erase("tutorial")
	App.main._tabbar.visible = false    # the real tab buttons are hidden: the stub supplies tabbar and tab.* here
	r.wait_s = 3.0
	r.missing_s = 2.0
	r.presented.connect(func(sid: String, st: String) -> void:
		if st == "a":
			_stub.placement = TutorialState.step_index(sid) % 3
			_stub.tall_choices = (sid == "ban")
			_stub.build_for(sid))
	r.accept()
	await until(_shown, 30)
	var o := _overlay()
	ok(o != null and o.get_parent() == App.main.overlay_layer and o.theme == App.main.theme, "run %s: the overlay sits on the overlay slot (CanvasLayer 100) with Main's theme" % variant)
	ok(gs.d["tutorial"]["state"] == "running" and DeviceState.new(TEMP_CFG).tutorial_flag("welcome_seen"), "run %s: accept saved state running and the device flag welcome_seen" % variant)
	var order: Array = []
	var bad: Array = []
	var seen_nodes := 0
	for i in 27:
		var sid := r.m.step_id()
		order.append(sid)
		var def: Dictionary = TutorialState.step_def(sid)
		await until(_shown, 40)
		if UI.animate:
			await until_s(func() -> bool: return _overlay() == null or not _overlay().animating(), 1.5)
		o = _overlay()
		if o == null or not _shown():
			bad.append("%s: not shown (mode %s)" % [sid, o.mode if o != null else "no overlay"])
			break
		_check_step(variant, sid, def, bad)
		seen_nodes = maxi(seen_nodes, _count_nodes(o))
		await _do_step(sid)
		if r.m.step_id() == sid and r.m.state() == "running":
			bad.append("%s: did not advance" % sid)
			break
	var state := r.m.state()
	ok(bad.is_empty(), "run %s: every step showed, fit and advanced: %s" % [variant, "; ".join(bad) if not bad.is_empty() else "27 of 27"])
	ok(order.size() == 27 and order == TutorialState.STEP_IDS, "run %s: the 27 steps came in order" % variant)
	ok(state == "done" and r.fallbacks == 0 and r.passed.is_empty(), "run %s: state done, %d fallbacks, %d steps passed over" % [variant, r.fallbacks, r.passed.size()])
	ok(App.main.overlay_layer.get_child_count() == 0 and r.overlay == null, "run %s: no overlay node is left after the finish" % variant)
	ok(seen_nodes <= 24, "run %s: the overlay is few nodes (%d at most)" % [variant, seen_nodes])
	var after: Dictionary = gs.d.duplicate(true)
	after.erase("tutorial")
	ok(JSON.stringify(after) == JSON.stringify(before), "run %s: presentation changed nothing in the save but the tutorial key (R6)" % variant)
	ok(gs.d["tutorial"]["state"] == "done" and DeviceState.new(TEMP_CFG).tutorial_flag("finished_once"), "run %s: the save says done and the device flag finished_once is set" % variant)
	_stub.queue_free()
	await frames(2)


## One step on the screen: every geometry rule of TUTORIAL 7.3, from what the overlay really did.
func _check_step(variant: String, sid: String, def: Dictionary, bad: Array) -> void:
	var o := _overlay()
	var vp := o.get_viewport_rect().size
	var card: Dictionary = o.card_data()
	var cr := o.card_rect()
	var hole := o.hole_rect()
	var compact: bool = bool(card.get("compact", false))
	var frac := 0.35 if compact else 0.45
	if o.is_fallback():
		bad.append("%s: fallback card (a tag is missing)" % sid)
		return
	var key := String(card.get("key", ""))
	if o.body_text() != UI.plain(Strings.f(key, {"club": App.gs.club_name(App.gs.club())}) if sid == "welcome" else Strings.t(key)):
		bad.append("%s: text differs from %s" % [sid, key])
	if cr.position.y < 63.5 or cr.end.y > vp.y - 39.5 or cr.position.x < 15.5 or cr.end.x > vp.x - 15.5:
		bad.append("%s: card %s is outside the safe area of %s" % [sid, str(cr), str(vp)])
	if cr.size.y > vp.y * frac + 1.0:
		bad.append("%s: card is %.0f px, over %.0f percent of %.0f" % [sid, cr.size.y, frac * 100.0, vp.y])
	var worst: float = float(_worst.get(variant, 0.0))
	_worst[variant] = maxf(worst, cr.size.y)
	print("  card %s %s: %.0f px (%.0f percent), %d lines" % [variant, sid, cr.size.y, cr.size.y * 100.0 / vp.y, o._body.get_line_count()])
	var t: Array = def.get("target", [])
	if t.is_empty():
		if hole.size != Vector2.ZERO or not o.panels_on():
			bad.append("%s: a modal has no hole but dims everything" % sid)
	else:
		var want := _union(t).grow(8.0).intersection(Rect2(Vector2.ZERO, vp))
		if not (hole.position.distance_to(want.position) <= 1.5 and hole.end.distance_to(want.end) <= 1.5):
			if not (String(sid) == "ban"):    # the tall ban target may be clipped by the card
				bad.append("%s: hole %s is not the target plus 8 px %s" % [sid, str(hole), str(want)])
		if hole.intersects(cr):
			bad.append("%s: the card %s covers the hole %s" % [sid, str(cr), str(hole)])
		if hole.size.y < 40.0:
			bad.append("%s: the hole is only %.0f px high" % [sid, hole.size.y])
	var kind := String(card.get("kind", ""))
	if o.blocker_on() != (kind == "info" and not t.is_empty()):
		bad.append("%s: blocker %s for a %s step" % [sid, str(o.blocker_on()), kind])
	if o.panels_on() != (String(card.get("dim", "")) != "none"):
		bad.append("%s: dim panels %s for dim %s" % [sid, str(o.panels_on()), str(card.get("dim", ""))])
	for bid in o.button_ids():
		var b := o._buttons.get_node("Btn_" + String(bid)) as Button
		if b.size.y < 95.5 or not b.has_theme_font_size_override("font_size") or b.get_theme_font_size("font_size") < 24:
			bad.append("%s: button %s is %.0f px high or has no explicit 24+ font" % [sid, String(bid), b.size.y])
		if b.get_minimum_size().x > b.size.x + 1.0:
			bad.append("%s: button %s text is wider than the button" % [sid, String(bid)])
	var scroll_gap: float = o._body.get_combined_minimum_size().y - o._body_scroll.size.y
	if scroll_gap > 1.0:
		bad.append("%s: the body text is clipped by %.0f px" % [sid, scroll_gap])
	if o._body.get_theme_font_size("font_size") < 24 or o._chapter_lbl.get_theme_font_size("font_size") < 24:
		bad.append("%s: a line is under 24 px" % sid)
	var expect_buttons: Array = card.get("buttons", [])
	if o.button_ids() != expect_buttons:
		bad.append("%s: buttons %s, expected %s" % [sid, str(o.button_ids()), str(expect_buttons)])


func _do_step(sid: String) -> void:
	var r: TutorialRunner = App.tutorial
	var o := _overlay()
	for guard in 6:
		if r.m.state() != "running" or r.m.step_id() != sid:
			return
		o = _overlay()
		if o == null:
			return
		if UI.animate:
			await until_s(func() -> bool: return _overlay() == null or not _overlay().animating(), 1.5)
			o = _overlay()
			if o == null:
				return
		var stage_before := r.m.stage
		var ids := o.button_ids()
		if sid in ["welcome"]:
			o.press("start")
		elif sid == "finish":
			o.press("go_home")
		elif String(r.m.step().get("kind", "")) == "info" or (r.m.stage == "b" and ids.has("next")):
			o.press("next")
		elif sid == "role":
			await sim.tap(UI.find_tag("draft.sheet.confirm").get_global_rect().get_center())    # Pick; a tap on the lane row only chooses a lane
		else:
			await sim.tap(o.hole_rect().get_center())
		await until(func() -> bool: return r.m.step_id() != sid or r.m.state() != "running" or r.m.stage != stage_before, 12)
		await frames(2)


# ---- geometry and animation --------------------------------------------------------------------------------------------------------

func _card(id: String, targets: Array, kind: String = "tap", dim: String = "full", compact: bool = false, buttons: Array = ["skip"]) -> Dictionary:
	return {"id": id, "step_no": 5, "chapter": 2, "chapter_key": "tut.ch.2", "kind": kind, "dim": dim, "stage": "a", "target": targets,
			"key": "tut.tab_squad", "compact": compact, "buttons": buttons, "shortcut_key": "", "shortcut_does": "", "hold_armed": false,
			"passthrough": dim == "none", "skip": "A", "screen": "home", "screen_now": "home"}


func _plain_overlay() -> CoachOverlay:
	var o := CoachOverlay.new()
	o.theme = App.main.theme
	o.wait_s = 0.3
	o.missing_s = 0.2
	App.main.overlay_layer.add_child(o)
	return o


func _geometry() -> void:
	var vp := _main.get_viewport_rect().size
	# a tagged button that can move
	var b := UI.button("mover", func() -> void: pass, "normal", 96)
	b.size = Vector2(300, 96)
	b.position = Vector2(100, 500)
	UI.tag(b, "t.mover", false)
	_main.add_child(b)
	var o := _plain_overlay()
	o.show_step(_card("mover", ["t.mover"]), "Follow me.")
	await until(func() -> bool: return o.mode == "shown", 20)
	ok(o.mode == "shown" and o.hole_rect() == b.get_global_rect().grow(8.0), "geometry: the hole is the target grown by 8 px %s" % str(o.hole_rect()))
	var lc: int = o.layout_count
	await frames(40)
	ok(o.layout_count == lc, "geometry: a still target costs no layout work in 40 frames (%d)" % (o.layout_count - lc))
	b.position = Vector2(180, 700)
	await frames(2)
	ok(o.hole_rect() == b.get_global_rect().grow(8.0) and o.layout_count > lc, "geometry: the hole follows a moving target within 2 frames %s" % str(o.hole_rect()))
	ok(not o.card_rect().intersects(o.hole_rect()), "geometry: the card keeps off the moved hole")
	o.clear()
	ok(not o.is_processing() and not o.visible and o.mode == "idle", "geometry: clear() stops all processing and hides it")
	# waits for layout: a zero-size target is not shown, the first size is followed by 2 quiet frames
	var z := Control.new()
	z.position = Vector2(100, 300)
	UI.tag(z, "t.zero", false)
	_main.add_child(z)
	o.show_step(_card("zero", ["t.zero"]), "Wait for layout.")
	await frames(6)
	ok(o.mode == "wait" and not o.card.visible and not o.panels_on(), "geometry: a target with no size yet shows nothing (no dim, no card)")
	z.size = Vector2(300, 96)
	await frames(1)
	ok(o.mode != "shown", "geometry: the first frame with a size is not enough")
	await until(func() -> bool: return o.mode == "shown", 10)
	ok(o.mode == "shown" and o.hole_rect() == z.get_global_rect().grow(8.0), "geometry: shown after the layout settled")
	o.clear()
	# a tall target: the hole is clipped above the card, the card sits at the bottom
	var tall := Control.new()
	tall.position = Vector2(60, 100)
	tall.size = Vector2(vp.x - 120.0, vp.y - 160.0)
	UI.tag(tall, "t.tall", false)
	_main.add_child(tall)
	o.show_step(_card("tall", ["t.tall"]), "A very tall target needs a clipped hole.")
	await until(func() -> bool: return o.mode == "shown", 20)
	var tc := o.card_rect()
	var th := o.hole_rect()
	ok(o.mode == "shown" and th.size.y >= 40.0 and not th.intersects(tc) and tc.end.y <= vp.y - 39.5, "geometry: a tall target is clipped above the card (hole %s, card %s)" % [str(th), str(tc)])
	o.clear()
	tall.queue_free()
	# fallback: a missing tag
	var fell := []
	o.fell_back.connect(func(s: String) -> void: fell.append(s))
	o.show_step(_card("gone", ["t.not_there"], "tap", "full", false, ["skip"]), "Tap the thing.")
	await frames(8)
	ok(o.mode == "wait" and not o.card.visible, "fallback: still looking for a missing tag after 8 frames")
	await until(func() -> bool: return o.mode == "fallback", 90)
	var fc := o.card_rect()
	ok(o.mode == "fallback" and o.fallbacks == 1 and fell == ["gone"], "fallback: after the wait the fallback card shows, fallbacks == 1")
	ok(o.button_ids() == ["skip", "next"] and o.hole_rect().size == Vector2.ZERO and fc.end.y > vp.y - 80.0, "fallback: Skip and Next, no hole, the card at the bottom %s" % str(fc))
	ok(o.nudge_text() == UI.plain(Strings.t("tut.fallback")) and o.body_text() == "Tap the thing.", "fallback: the step's own text and the fallback line")
	ok(not o.is_processing(), "fallback: nothing runs while the fallback card is up")
	o.clear()
	# scroll into view through nested scroll areas
	var outer := ScrollContainer.new()
	outer.position = Vector2(20, 120)
	outer.size = Vector2(vp.x - 40.0, 700)
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var ov := VBoxContainer.new()
	ov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f1 := Control.new()
	f1.custom_minimum_size = Vector2(0, 900)
	ov.add_child(f1)
	var inner := ScrollContainer.new()
	inner.custom_minimum_size = Vector2(0, 400)
	inner.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ov.add_child(inner)
	var iv := VBoxContainer.new()
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f2 := Control.new()
	f2.custom_minimum_size = Vector2(0, 1000)
	iv.add_child(f2)
	var deep := UI.button("deep target", func() -> void: pass, "normal", 96)
	iv.add_child(deep)
	var f3 := Control.new()
	f3.custom_minimum_size = Vector2(0, 600)
	iv.add_child(f3)
	inner.add_child(iv)
	var f4 := Control.new()
	f4.custom_minimum_size = Vector2(0, 900)
	ov.add_child(f4)
	outer.add_child(ov)
	_main.add_child(outer)
	UI.tag(deep, "t.deep", false)
	await frames(4)
	var ir0 := inner.get_global_rect()
	ok(not ir0.encloses(deep.get_global_rect()) and not outer.get_global_rect().encloses(deep.get_global_rect()), "scroll: the deep target starts out of view in both scroll areas")
	o.show_step(_card("deep", ["t.deep"]), "Scroll me in.")
	await until(func() -> bool: return o.mode == "shown", 30)
	var dr := deep.get_global_rect()
	ok(o.mode == "shown" and inner.get_global_rect().encloses(dr) and outer.get_global_rect().encloses(dr), "scroll: both scroll areas moved, the target is on screen at %s (inner %d, outer %d)" % [str(dr), inner.scroll_vertical, outer.scroll_vertical])
	ok(o.hole_rect().encloses(dr) and Rect2(Vector2.ZERO, vp).encloses(o.hole_rect()), "scroll: the hole is on the target and inside the screen")
	o.clear()
	# with animation on: the scroll is one tween, ends, and the overlay settles; one animation at a time
	UI.animate = true
	inner.scroll_vertical = 0
	outer.scroll_vertical = 0
	await frames(3)
	o.show_step(_card("deep", ["t.deep"]), "Scroll me in, animated.")
	await frames(3)
	ok(o.animating() and o.mode == "scroll", "scroll: with animations on the scroll is a tween (mode %s)" % o.mode)
	await until(func() -> bool: return o.mode == "shown", 90)
	ok(o.mode == "shown" and inner.get_global_rect().encloses(deep.get_global_rect()), "scroll: animated scroll finished and the step is shown")
	await until_s(func() -> bool: return not o.animating(), 1.5)
	ok(not o.animating(), "animation: every tween ended within 1.5 s (none loops)")
	# a second step while the first animates: the first is finished (snapped), never two at once
	o.show_step(_card("mover", ["t.mover"]), "Second.")
	await frames(3)
	o.show_step(_card("mover2", ["t.mover"]), "Third.")
	await until(func() -> bool: return o.mode == "shown", 40)
	ok(o.mode == "shown" and o.step_id == "mover2", "animation: steps in quick succession end up showing the last one")
	await until_s(func() -> bool: return not o.animating(), 1.5)
	ok(not o.animating() and o.card.modulate.a >= 0.99 and o.hole_rect() == b.get_global_rect().grow(8.0), "animation: the end state is the final one (card opaque, hole on the target)")
	UI.animate = false
	o.show_step(_card("mover3", ["t.mover"]), "No animations.")
	await until(func() -> bool: return o.mode == "shown", 20)
	ok(not o.animating() and o.card.modulate.a >= 0.99, "animation: with UI.animate false nothing is animated")
	o.clear()
	o.queue_free()
	outer.queue_free()
	b.queue_free()
	z.queue_free()
	await frames(3)


# ---- all targets missing: the tutorial can still be finished ---------------------------------------------------------------------------

func _fallback_run() -> void:
	await _fresh_main()
	_stub.queue_free()
	var r: TutorialRunner = App.tutorial
	App.main._tabbar.visible = false    # the real tab buttons must not count as found targets
	r.accept()
	var steps := 0
	for i in 40:
		var o := _overlay()
		if o == null or r.m.state() != "running":
			break
		await until(_shown, 120)
		o = _overlay()
		if o == null:
			break
		var sid := r.m.step_id()
		var kind := String(r.m.step().get("kind", ""))
		if sid == "welcome":
			o.press("start")
		elif sid == "finish":
			o.press("go_home")
		else:
			if i < 3:
				ok(o.is_fallback() or kind == "modal", "fallback run: %s shows the fallback card when its target is missing" % sid)
			o.press("next")
		steps += 1
		await until(func() -> bool: return r.m.step_id() != sid or r.m.state() != "running", 12)
	ok(r.m.state() == "done" and steps >= 27, "fallback run: with no target anywhere the tutorial still finishes with Next (%d presses)" % steps)
	ok(r.fallbacks >= 20 and "fallbacks=%d" % r.fallbacks in r.debug_line(), "fallback run: the fallbacks are counted and shown in the debug line (%s)" % r.debug_line())
	ok(App.main.overlay_layer.get_child_count() == 0, "fallback run: no overlay node is left")


# ---- flow: screens, skip, undo, back --------------------------------------------------------------------------------------------------

class TagScreen extends Screen:
	func _init() -> void:
		super()

	func tab_id() -> String:
		return ""


## A running tutorial at `sid` (the save is edited the way a resumed save would be), the runner bound to it.
func _at_step(sid: String) -> void:
	var t: Dictionary = TutorialState.new_state()
	t["state"] = "running"
	t["step"] = sid
	App.gs.set_tutorial(t)
	App.tutorial.bind(false)
	await until(_shown, 40)


func _flow() -> void:
	await _fresh_main()
	var r: TutorialRunner = App.tutorial
	await _at_step("tabs")
	var o := _overlay()
	ok(r.m.step_id() == "tabs" and o.hole_rect().size.x > 0.0, "flow: step 3 (tabs) points at the real tab bar %s" % str(o.hole_rect()))
	o.press("next")
	await frames(3)
	await until(_shown, 30)
	o = _overlay()
	ok(r.m.step_id() == "tab_squad" and o.mode == "shown", "flow: step 4 (tab_squad) points at the real Squad tab")
	ok(o.hole_rect().encloses(UI.find_tag("tab.squad").get_global_rect()), "flow: the hole is on the real tab button %s" % str(o.hole_rect()))
	# the overlay survives Main.show_screen between steps
	var id0 := o.get_instance_id()
	App.go(TagScreen.new())
	await frames(4)
	ok(_overlay() != null and _overlay().get_instance_id() == id0 and _overlay().get_parent() == App.main.overlay_layer, "flow: the overlay node survives Main.show_screen")
	ok(_overlay().mode == "wait" and not _overlay().card.visible, "flow: while the real tab bar is hidden (a screen without tabs) nothing is dimmed and no card shows")
	App.go(ScreenHub.new())
	await until(_shown, 30)
	ok(_overlay().mode == "shown" and _overlay().get_instance_id() == id0, "flow: back on Home the same overlay finds the tab again and shows")
	# a real tap on the real tab button completes the step through the real EventBus
	await sim.tap(_overlay().hole_rect().get_center())
	await frames(4)
	ok(r.m.step_id() == "squad_bench" and r.m.state() == "running", "flow: a tap on the real Squad tab moved to step 5 (%s)" % r.m.step_id())
	# Skip, then Undo (toast button), on a step whose card is on screen
	await _at_step("tab_plan")
	var step_before := r.m.step_id()
	_overlay().press("skip")
	await frames(4)
	ok(r.m.state() == "skipped" and App.main.overlay_layer.get_child_count() == 0, "skip: state skipped and the overlay is gone")
	ok(App.gs.d["tutorial"]["state"] == "skipped" and DeviceState.new(TEMP_CFG).tutorial_flag("skipped_once"), "skip: saved in the save and on the device")
	var undo_btn: Button = null
	for t in App.main._toasts.get_children():
		for bt in t.find_children("*", "Button", true, false):
			undo_btn = bt
	ok(undo_btn != null and UI.plain(undo_btn.text) == Strings.t("common.undo"), "skip: a toast with an Undo button is up")
	if undo_btn != null:
		undo_btn.pressed.emit()
	await frames(4)
	await until(_shown, 40)
	ok(r.m.state() == "running" and r.m.step_id() == step_before and _overlay() != null, "undo: the same step is back (%s)" % r.m.step_id())
	# the 4.5 s expiry
	r.skip()
	await frames(2)
	ok(r.m.state() == "skipped" and r.m.undo_available(), "undo: available right after a skip")
	await get_tree().create_timer(4.7).timeout
	ok(not r.m.undo_available(), "undo: expired 4.5 s after the skip")
	r.undo()
	await frames(3)
	ok(r.m.state() == "skipped" and App.main.overlay_layer.get_child_count() == 0, "undo: after the toast is gone the tutorial stays skipped")
	# Back key
	await _at_step("tab_squad")
	var sc0: Control = App.main._current
	App.main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(3)
	ok(r.m.state() == "skipped" and App.main._current == sc0 and App.main.overlay_layer.get_child_count() == 0, "back: Back on a step is Skip tutorial; the page behind did not move")
	ok(App.main._toasts.get_child_count() >= 1, "back: with the Undo toast")
	# Back with a sheet open and a step up: the tutorial first, the sheet stays; then Back closes the sheet
	r.undo()
	await until(_shown, 40)
	ok(_overlay() != null and _overlay().is_showing(), "back: Undo brought the step back")
	BottomSheet.open("A sheet", Callable(), Callable(), "M", "t")
	await frames(5)
	App.main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(3)
	ok(r.m.state() == "skipped" and BottomSheet.is_open(), "back: with a sheet open the first Back skips the tutorial and the sheet stays")
	App.main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(6)
	ok(not BottomSheet.is_open(), "back: the second Back closes the sheet")
	ok(not r.handle_back(), "back: with no card on screen the runner does not take the press")
	# Back on the closing card acts as Go to Home
	await _fresh_main()
	r = App.tutorial
	var gs: GameState = App.gs
	await _at_step("finish")
	ok(r.m.step_id() == "finish" and _overlay().button_ids() == ["go_home"], "back: the closing card has Go to Home and no Skip")
	App.go(ScreenSettings.new())
	await frames(2)
	App.main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(5)
	ok(r.m.state() == "done" and App.main._current is ScreenHub and App.main.overlay_layer.get_child_count() == 0, "back: on the closing card Back acts as Go to Home (state done, Home shown, no overlay)")
	# the debug line
	var info := App.debug_info()
	ok(info.contains("tutorial=done step_skipped=none total_s=") and info.contains("fallbacks=0"), "debug: App.debug_info() carries the tutorial line (%s)" % r.debug_line())
	# stray taps on the dim: nudge, then the second line, never a step change
	await _fresh_main()
	r = App.tutorial
	await _at_step("tab_squad")
	o = _overlay()
	var hole := o.hole_rect()
	var far := Vector2(hole.get_center().x, 200.0)    # the top dim panel, above the card
	await sim.tap(far)
	ok(o.nudges == 1 and o.nudge_text() == "" and r.m.step_id() == "tab_squad", "stray: one tap on the dim is swallowed and counted, no line yet")
	await sim.tap(far + Vector2(30, 0))
	ok(o.nudges == 2 and o.nudge_text() == UI.plain(Strings.t("tut.nudge")), "stray: the second tap within 5 s shows the nudge line")
	await sim.tap(hole.get_center() + Vector2(0, -hole.size.y))
	ok(r.m.step_id() == "tab_squad" and App.main._current is ScreenHub, "stray: no stray tap changed the step or the page below")
	await sim.tap(hole.get_center())
	await frames(5)
	ok(r.m.step_id() != "tab_squad", "stray: the tap in the hole still works after strays")


# ---- cost ---------------------------------------------------------------------------------------------------------------------------

func _cost() -> void:
	await _fresh_main()
	var r: TutorialRunner = App.tutorial
	await _at_step("tab_squad")
	var o := _overlay()
	ok(o.is_processing(), "cost: the overlay polls while a step is up")
	await frames(10)
	var objs0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var res0 := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	await frames(120)
	var objs1 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var res1 := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	ok(objs1 <= objs0 + 2 and res1 <= res0 + 2, "cost: no objects or resources created in 120 still frames (objects %d to %d, resources %d to %d)" % [objs0, objs1, res0, res1])
	var t0 := Time.get_ticks_usec()
	for i in 2000:
		o._process(0.016)
	var per := float(Time.get_ticks_usec() - t0) / 2000.0
	ok(per < 300.0, "cost: one polling frame of a shown step takes %.1f microseconds (budget 1 ms)" % per)
	ok(_count_nodes(o) <= 24, "cost: the overlay is %d nodes" % _count_nodes(o))
	r.skip()
	await frames(3)
	ok(App.main.overlay_layer.get_child_count() == 0, "cost: after a skip no node and no process is left")
