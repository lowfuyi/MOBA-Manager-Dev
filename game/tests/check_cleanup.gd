extends Node
## I-24 checks (build plan I-24), headless:
##   tips        no `Tips.show(` call and no tips.gd remain in src (a grep as a test); the retired keys are gone from en.json and
##               nothing asks for them; the Payoff tips (tip.rest, tip.morale, tip.contract, tip.scrim, tip.keep) stay
##   about       About shows the released "What is in this build" and "What to test" texts (guided first game, help, lessons,
##               glossary), not the older chemistry text; the Licences card credits Barlow and its button shows the OFL text from
##               the file that ships in the APK (export filter)
##   settings    Settings has no "Show the welcome tips again" (retired); Show help hints again stays
## Ends with " N checks, M failures".

const RETIRED := ["tip.hub.h", "tip.hub", "tip.prematch.h", "tip.prematch", "tip.report.h", "tip.report", "tip.got_it",
		"settings.tips_again", "settings.tips_done"]

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
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	_tips()
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = false
	await frames(3)
	App.gs = GameState.new_game(App.world, App.world.club_ids[5], 20261117)
	await _about()
	await _settings()
	_main.queue_free()
	await frames(2)
	GameState.delete_save()
	print("check_cleanup: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _gd_files(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_gd_files(dir.path_join(sub), out)


func _tips() -> void:
	var files: Array = []
	_gd_files("res://src", files)
	var calls: Array = []
	for f in files:
		if FileAccess.get_file_as_string(String(f)).contains("Tips.show("):
			calls.append(f)
	ok(files.size() > 50 and calls.is_empty(), "tips: no Tips.show( call in %d source files %s" % [files.size(), str(calls)])
	ok(not FileAccess.file_exists("res://src/ui/tips.gd"), "tips: tips.gd is gone")
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/en.json"))
	var left := RETIRED.filter(func(k: String) -> bool: return table.has(k))
	ok(left.is_empty(), "tips: the retired keys are gone from en.json %s" % str(left))
	var payoff := ["tip.rest", "tip.morale", "tip.contract", "tip.scrim", "tip.keep"].filter(func(k: String) -> bool: return table.has(k))
	ok(payoff.size() == 5, "tips: the Payoff tips stay (%d of 5)" % payoff.size())


func _labels(root: Node) -> String:
	var out := ""
	for n in root.find_children("*", "Label", true, false):
		out += UI.plain((n as Label).text) + "\n"
	return out


func _about() -> void:
	App.go(ScreenAbout.new())
	await frames(4)
	var t := _labels(App.main._current)
	ok(t.contains(UI.plain(Strings.t("about.included.b"))) and Strings.t("about.test.b").contains("guided first game") and t.contains(UI.plain(Strings.t("about.test.b"))),
			"about: What is in this build and What to test show the released texts (the guided first game, help, lessons, glossary)")
	ok(not Strings.t("about.test.b").contains("Team chemistry (club office)"), "about: not the older text that names chemistry as the new feature")
	ok(t.contains(UI.plain(Strings.t("about.licences.font"))) and t.contains("Barlow"), "about: the Licences card credits Barlow Semi Condensed")
	(UI.find_tag("about.licence") as Button).pressed.emit()
	await frames(6)
	var sh := BottomSheet.current()
	var lt := _labels(sh) if sh != null else ""
	ok(sh != null and sh.sheet_id == "licence" and lt.contains("SIL OPEN FONT LICENSE") and ScreenAbout.licence_text().length() > 2000,
			"about: the licence button shows the OFL text read from res://assets/fonts/OFL.txt")
	var cfg := FileAccess.get_file_as_string("res://export_presets.cfg")
	ok(cfg.contains("assets/fonts/OFL.txt"), "about: the licence file is in the export filter, so it ships in the APK")
	sh.close()
	await frames(20)


func _settings() -> void:
	App.go(ScreenSettings.new())
	await frames(4)
	var has_old := false
	var has_new := false
	for b in App.main._current.find_children("*", "Button", true, false):
		var tx := UI.plain((b as Button).text)
		has_old = has_old or tx.contains("welcome tips")
		has_new = has_new or tx == UI.plain(Strings.t("settings.help_reset"))
	ok(not has_old and has_new, "settings: no Show the welcome tips again; Show help hints again stays")
