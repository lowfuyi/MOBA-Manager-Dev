extends RefCounted
## Matrix module "gallery" (I-07): the components gallery, one picture per section, and a PERF line per section (nodes,
## draw calls, canvas items, shadows, glows) so the gallery can be read against PERF-BUDGET 3.1. Pictures:
## gallery_<section>_<variant>.png (a second picture <section>b when the section scrolls). Run:
##   SHOT_DIR=<dir> SCREENS=gallery VARIANTS=normal,large,cb,tall xvfb-run -a -s "-screen 0 720x1280x24" \
##     godot --rendering-driver opengl3 res://tests/shots_matrix.tscn
## The toast picture is taken last (it needs the live toast layer).

const Gallery = preload("res://tests/components_gallery.gd")
const Gate = preload("res://tests/perf_gate.gd")


static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _count(c)
	return total


static func _measure(ctx, section: String) -> void:
	for i in 3:
		await ctx.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var cur: Control = ctx.cur()
	var sh: Dictionary = Gate.count_shadows(cur)
	print("GALLERY|%s|%s|nodes=%d|draw_calls=%d|objects=%d|shadows=%d|glows=%d|tex_mem=%d" % [
			ctx.variant, section, _count(cur), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), sh["shadows"], sh["glows"],
			int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))])


static func run(ctx) -> void:
	await ctx.start_game(5)
	for section in Gallery.SECTIONS:
		var g: Control = Gallery.new(section)
		App.go(g)
		await ctx.get_tree().process_frame
		await ctx.shot(section)
		await _measure(ctx, section)
		var sc := g.body.get_parent() as ScrollContainer
		await ctx.get_tree().process_frame
		var max_scroll := int(g.body.size.y - sc.size.y)
		if max_scroll > 8:
			sc.scroll_vertical = max_scroll
			await ctx.shot(section + "b")
			await _measure(ctx, section + "b")
	App.go(Gallery.new("data"))
	await ctx.settle()
	App.toast(Strings.t("squad.toast.auto"), UI.GOOD)
	App.toast(Strings.t("squad.toast.moved").format({"name": "Brikai", "role": Strings.t("role.mid")}), UI.TEXT, Strings.t("common.undo"), func() -> void: pass)
	await ctx.shot("toast")
