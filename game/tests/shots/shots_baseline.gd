extends RefCounted
## Matrix module "baseline": the existing 49-state tour of tests/ui_shots.gd as one module. Files are named
## baseline_<tour state>_<variant>.png (for example baseline_01_title_normal.png). The tour itself stays in
## ui_shots.gd (which still runs on its own through ui_shots.tscn); only the UI lane edits it.


static func run(ctx) -> void:
	var tour: Node = load("res://tests/ui_shots.gd").new()
	tour.as_module = true
	tour.dir = ctx.dir
	tour.prefix = "baseline_"
	tour.suffix = "_" + ctx.variant
	ctx.add_child(tour)
	await tour._tour()
	ctx.count += tour.shots_taken
	tour.queue_free()
	await ctx.get_tree().process_frame
