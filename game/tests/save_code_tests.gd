extends RefCounted
## Save codes and the web build helpers (0.11.1 web playtest; SaveCode, WebBuild). Auto-discovered by run_tests.gd.
##   roundtrip  a played save -> code -> save gives the same dictionary; the code is one line of text
##   reject     empty, garbage, a cut code, a wrong prefix, a wrong length and another save version give {}
##   web        outside a browser is_web() is false; without build_info.json the build id is the version label, no form;
##              fit() keeps 9:16 with bars on a wide window and expands on a tall one


func run(check: Callable) -> void:
	var w := World.load_default()
	var gs := GameState.new_game(w, w.club_ids[3], 4242)
	for i in 3:
		var g := gs.next_game()
		if g.is_empty():
			break
		gs.auto_game(g)
	var code := SaveCode.encode(gs.d)
	check.call(code.begins_with(SaveCode.PREFIX) and not code.contains("\n") and not code.contains(" "), "roundtrip: the code is one line (%d characters)" % code.length())
	var back := SaveCode.decode(code)
	check.call(JSON.stringify(back) == JSON.stringify(JSON.parse_string(JSON.stringify(gs.d))), "roundtrip: the code gives back the same save")
	var st := SaveCode.state(code, w)
	check.call(st != null and st.d["club"] == gs.d["club"] and int(st.d["season"]) == int(gs.d["season"]), "roundtrip: the code loads as a game")
	check.call(not SaveCode.decode("  " + code.substr(0, 40) + "\n" + code.substr(40, 50) + " " + code.substr(90) + "\r\n").is_empty(), "roundtrip: spaces and line breaks from a messenger app are ignored")
	check.call(SaveCode.decode("").is_empty() and SaveCode.decode("hello").is_empty() and SaveCode.state("hello", w) == null, "reject: empty and garbage")
	check.call(SaveCode.decode(code.substr(0, code.length() / 2)).is_empty(), "reject: a cut code")
	check.call(SaveCode.decode("XX" + code.substr(2)).is_empty(), "reject: a wrong prefix")
	var k := code.find(":", SaveCode.PREFIX.length())
	check.call(SaveCode.decode(SaveCode.PREFIX + "12:" + code.substr(k + 1)).is_empty(), "reject: a wrong length")
	var other := gs.d.duplicate(true)
	other["version"] = GameState.VERSION + 1
	check.call(SaveCode.decode(SaveCode.encode(other)).is_empty(), "reject: another save version")
	check.call(not WebBuild.is_web(), "web: is_web() is false outside a browser")
	check.call(WebBuild.info().is_empty() and WebBuild.build_id("0.0 test") == "0.0 test" and WebBuild.feedback_url() == "", "web: without build_info.json the build id is the version label and there is no form link")
	var win := Window.new()
	win.size = Vector2i(1600, 900)
	check.call(WebBuild.fit(win) == Window.CONTENT_SCALE_ASPECT_KEEP, "web: a wide window keeps 9:16 with bars")
	win.size = Vector2i(390, 844)
	check.call(WebBuild.fit(win) == Window.CONTENT_SCALE_ASPECT_EXPAND, "web: a tall phone window uses the full height")
	win.free()
