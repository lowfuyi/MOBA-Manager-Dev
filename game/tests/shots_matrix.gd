extends Node
## Screenshot matrix (build plan 3.2). Needs a renderer: run under Xvfb with software OpenGL, never headless.
##   SHOT_DIR=/tmp/shots SCREENS=home,draft VARIANTS=normal,large,cb,tall \
##     xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 res://tests/shots_matrix.tscn
## SCREENS: names of the modules res://tests/shots/shots_<screen>.gd (default: all). Each module has
##   static func run(ctx)   (it may await; ctx is this node) and takes the shots of its own screen.
## VARIANTS (default: all four): normal (720 x 1280), large (content scale 1.15), cb (colour-blind mode),
##   tall (720 x 1560). Output: <SHOT_DIR>/<screen>_<state>_<variant>.png. Nothing is written to settings.cfg.
## The tall variant resizes the window to 720 x 1560, which works on a 720 x 1280 Xvfb screen (checked); the runner
## reports a size mismatch instead of silently writing a wrong picture if some setup clips it.
##
## What a module can use on ctx: ctx.shot(state), ctx.cur() (the screen shown), ctx.start_game(club_index)
## (new save, club chosen, Home shown), ctx.settle() (a few frames), ctx.variant, ctx.screen, ctx.count.

const VARIANTS := {
	"normal": Vector2i(720, 1280),
	"large": Vector2i(720, 1280),
	"cb": Vector2i(720, 1280),
	"tall": Vector2i(720, 1560),
}
const MODULE_DIR := "res://tests/shots"
const FIXED_SEED := 20261109

var dir := "/tmp/shots"
var screen := ""
var variant := ""
var count := 0
var problems: Array = []


func cur() -> Control:
	return App.main._current


func settle() -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func shot(state: String) -> void:
	await settle()
	var img := get_viewport().get_texture().get_image()
	var want: Vector2i = VARIANTS[variant]
	if img.get_size() != want:
		problems.append("%s_%s_%s: picture is %s, wanted %s (the window could not be resized?)" % [screen, state, variant, img.get_size(), want])
	img.save_png("%s/%s_%s_%s.png" % [dir, screen, state, variant])
	count += 1


## A new save for the club at `club_index` of the league, then the Home screen. The save seed is fixed (the club
## select screen uses the clock), so the opponent, ranks and drafts are the same in every run and every variant, and
## pictures can be compared before and after a change.
func start_game(club_index: int = 5) -> void:
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[club_index], FIXED_SEED)
	App.autosave()
	App.go(ScreenHub.new())
	await get_tree().process_frame


func _modules() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(MODULE_DIR):
		var name: String = f
		if name.begins_with("shots_") and name.ends_with(".gd"):
			out[name.trim_prefix("shots_").trim_suffix(".gd")] = MODULE_DIR + "/" + name
	return out


func _list(env: String, all: Array) -> Array:
	var e := OS.get_environment(env).strip_edges()
	if e == "":
		return all
	var out: Array = []
	for part in e.split(","):
		var p := part.strip_edges()
		if p != "":
			out.append(p)
	return out


func _apply_variant(v: String) -> void:
	get_window().size = VARIANTS[v]
	App.apply_large_text(v == "large")
	UI.set_colorblind(v == "cb")
	await get_tree().process_frame


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOTS: needs a renderer; run under xvfb-run with --rendering-driver opengl3")
		get_tree().quit(2)
		return
	var e := OS.get_environment("SHOT_DIR")
	if e != "":
		dir = e
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().process_frame
	var mods := _modules()
	var names: Array = mods.keys()
	names.sort()
	var screens := _list("SCREENS", names)
	var variants := _list("VARIANTS", VARIANTS.keys())
	for s in screens:
		if not mods.has(s):
			problems.append("unknown screen '%s' (modules: %s)" % [s, ", ".join(names)])
	for v in variants:
		if not VARIANTS.has(v):
			problems.append("unknown variant '%s' (variants: %s)" % [v, ", ".join(VARIANTS.keys())])
	if problems.is_empty():
		for v in variants:
			variant = v
			await _apply_variant(v)
			for s in screens:
				screen = s
				var main: Control = load("res://scenes/main.tscn").instantiate()
				add_child(main)
				UI.animate = false
				await get_tree().process_frame
				var scr: Script = load(mods[s])
				await scr.call("run", self)
				main.queue_free()
				await get_tree().process_frame
	await _apply_variant("normal")
	App.apply_large_text(false)
	UI.set_colorblind(false)
	GameState.delete_save()
	for p in problems:
		print("SHOTS PROBLEM: ", p)
	print("shots: %d images in %s (screens %s, variants %s), %d problems" % [count, dir, ",".join(screens), ",".join(variants), problems.size()])
	get_tree().quit(1 if not problems.is_empty() else 0)
