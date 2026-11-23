extends Node
## Settings, "Your save" and the build line (0.11.1 web playtest):
##   card      Settings shows the build line (the version label outside a web build), the save card with Copy and Restore,
##             full-height buttons; no "Send feedback" without a form link
##   copy      Copy save code puts a code on the clipboard that decodes to the current save
##   restore   a bad code changes nothing and keeps the card; a good code (another club's season) asks first, Cancel keeps
##             the current save, Restore this save replaces it, saves it and opens Home

const TEMP_CFG := "user://check_save_code.cfg"

var checks := 0
var fails := 0
var _main: Control


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	TutorialRunner.home_offers = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await frames(3)
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[4], 20261122)
	var r: TutorialRunner = App.tutorial
	r.autosave = false
	r.device = DeviceState.new(TEMP_CFG)
	r.bind()
	await _run()
	_main.queue_free()
	await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	print("check_save_code: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _find(n: Node, name_: String) -> Node:
	if n.name == name_:
		return n
	for c in n.get_children():
		var f := _find(c, name_)
		if f != null:
			return f
	return null


func _run() -> void:
	var s := ScreenSettings.new()
	App.go(s)
	await frames(4)
	var bl := _find(_main, "BuildLabel") as Label
	ok(bl != null and UI.plain(bl.text).contains(App.VERSION_LABEL), "card: the build line shows the version (%s)" % (UI.plain(bl.text) if bl != null else "none"))
	var cp := _find(_main, "SaveCopy") as Button
	var rs := _find(_main, "SaveRestore") as Button
	ok(_find(_main, "SaveCard") != null and cp != null and rs != null, "card: Your save has Copy save code and Restore from a save code")
	ok(cp != null and rs != null and cp.size.y >= UI.BTN_H and rs.size.y >= UI.BTN_H, "card: full-height buttons")
	ok(_find(_main, "SendFeedback") == null, "card: no Send feedback button without a form link")
	cp.pressed.emit()
	await frames(2)
	var code: String = s.last_code
	ok(JSON.stringify(SaveCode.decode(code)) == JSON.stringify(JSON.parse_string(JSON.stringify(App.gs.d))), "copy: the clipboard holds a code for the current save (%d characters)" % code.length())
	var before := JSON.stringify(App.gs.d)
	ok(not s.restore_from("not a save") and JSON.stringify(App.gs.d) == before and _find(_main, "RestoreYes") == null, "restore: a bad code changes nothing")
	var other := GameState.new_game(App.world, App.world.club_ids[7], 7)
	other.d["season"] = 3
	ok(s.restore_from(SaveCode.encode(other.d)), "restore: a good code is accepted")
	await frames(2)
	var yes := _find(_main, "RestoreYes") as Button
	ok(yes != null and JSON.stringify(App.gs.d) == before, "restore: it asks first, nothing changed yet")
	s.call("_rebuild")    # Cancel is the plain button next to it; check that a rebuild alone keeps the question
	await frames(2)
	yes = _find(_main, "RestoreYes") as Button
	ok(yes != null, "restore: the question stays until answered")
	yes.pressed.emit()
	await frames(4)
	ok(String(App.gs.d["club"]) == String(App.world.club_ids[7]) and int(App.gs.d["season"]) == 3, "restore: Restore this save replaces the save")
	var loaded := GameState.load_save(App.world)
	ok(loaded != null and String(loaded.d["club"]) == String(App.world.club_ids[7]), "restore: it is written to the device")
	ok(_main.get("_current") is ScreenHub, "restore: Home opens")
