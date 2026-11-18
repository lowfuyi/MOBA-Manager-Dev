extends RefCounted
## Matrix module "fight" (Alpha 0.8.1 F-03 to F-06): one game's Mossback fight frame by frame (engage, trade, spaced kills,
## retreat and chase), Stoneback after its fight (the ring only then), and the decisive kill (shake and punch-in), with the frame's
## numbers (ARENA|<variant>|fight_<t>|nodes=..|draw_calls=..), then a contact sheet of the fight (fight_strip_<variant>.png).

const Arena := preload("res://tests/shots/shots_arena.gd")
const MID := [41.1, 41.5, 41.9, 42.4, 42.9, 43.4, 43.9, 44.4, 44.9, 45.3, 45.7, 46.2]


static func run(ctx) -> void:
	App.main.visible = false
	var w := App.world
	var res := {}
	var sc: ShowScript
	for i in 40:    # a clean game with a decisive kill and at least four Mossback kills
		res = MatchRunner.auto(w, w.best_lineup(w.club_ids[1]), w.best_lineup(w.club_ids[6]), w.make_meta("shots"), 900 + i, "shots:fight", false, {"B": "ai", "R": "ai"})
		sc = ShowScript.build(res, "B")
		var mid := 0
		for e in sc.kill_events:
			mid += 1 if String(e["beat"]) == "fight_mid" else 0
		if not sc.held and not sc.decisive.is_empty() and mid >= 4:
			break
	var ch := Choreo.build(sc)
	var fx := ArenaFx.build(sc, ch, "B")
	print("ARENA|fight|winner %s decisive %s kills %s actions %d" % [sc.winner, str(sc.decisive.get("t", -1.0)), str(sc.kill_count), fx.actions.size()])
	var frames: Array = []
	var times: Array = MID.duplicate()
	times.append_array([32.0, 32.9])
	if not sc.decisive.is_empty():
		var td := float(sc.decisive["t"])
		times.append_array([td - 0.12, td + 0.06, td + 0.25])
	for t in times:
		var m := Arena._full(ctx, sc, ch, fx, float(t))
		await Arena._measure(ctx, m, "fight_%s" % str(snappedf(float(t), 0.01)).replace(".", "_"))
		if MID.has(t):
			var img: Image = ctx.get_viewport().get_texture().get_image()
			var r := Rect2i(Vector2i(0, int(m.position.y)), Vector2i(int(m.size.x), int(m.size.y)))
			var part: Image = img.get_region(r)
			part.resize(int(m.size.x) / 3, int(m.size.y) / 3, Image.INTERPOLATE_BILINEAR)
			frames.append(part)
	if not frames.is_empty():
		var fw: int = frames[0].get_width()
		var fh: int = frames[0].get_height()
		var sheet := Image.create(fw * 4 + 12, fh * 3 + 8, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.05, 0.07, 0.12))
		for k in frames.size():
			sheet.blit_rect(frames[k], Rect2i(Vector2i.ZERO, Vector2i(fw, fh)), Vector2i((k % 4) * (fw + 4), (k / 4) * (fh + 4)))
		sheet.save_png("%s/fight_strip_%s.png" % [ctx.dir, ctx.variant])
	for c in ctx.get_children():
		if c.name == "ArenaStage":
			c.queue_free()
	App.main.visible = true
