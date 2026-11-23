extends RefCounted
## Tester timings (0.12, Q1): Timings records draft time, game start and arena frames per view, and the debug lines (and so
## the feedback note) carry them. Session only, nothing saved.


func run(check: Callable) -> void:
	var tm := Timings.new()
	check.call(tm.draft_done(1000) < 0.0 and tm.match_shown(1000) < 0, "timings: nothing is recorded before a draft or a match starts")
	tm.draft_opened(1000)
	check.call(absf(tm.draft_done(96000) - 95.0) < 1e-6, "timings: a draft open from 1 s to 96 s takes 95 s")
	check.call(tm.draft_done(99000) < 0.0, "timings: a draft is counted once")
	tm.launched(5000)
	check.call(tm.match_shown(6234) == 1234 and tm.match_shown(7000) == -1, "timings: game start is Start the match to the first arena frame, counted once")
	tm.frame("field", 0.016, 0.5)
	check.call(not tm.frames.has("field"), "timings: frames in the first second of the match screen are not counted")
	for i in 10:
		tm.frame("action", 0.016, 2.0)
	tm.frame("action", 0.050, 2.0)
	tm.frame("all", 0.020, 3.0)
	var a: Array = tm.frames["action"]
	check.call(int(a[0]) == 11 and absf(float(a[2]) - 50.0) < 1e-3 and int(a[3]) == 1, "timings: frames, worst and slow frames per view")
	var text := "\n".join(tm.lines())
	check.call(text.contains("device=") and text.contains("draft time s last=95") and text.contains("game start ms last=1234"),
			"timings: the lines carry the device, the draft time and the game start")
	check.call(text.contains("action avg=") and text.contains("worst=50") and text.contains("all avg=20.0") and not text.contains("field avg"),
			"timings: the lines carry average and worst frame time for each view that was watched")
	for i in 30:
		tm.draft_opened(0)
		tm.draft_done(1000)
	check.call(tm.drafts.size() == Timings.KEEP, "timings: only the last %d drafts are kept" % Timings.KEEP)
	# wired into the game: App owns one, the feedback note includes it, the screens report to it
	check.call(App.timings is Timings, "timings: App has one Timings for the session")
	# the feedback note is feedback.template around debug_info (ui_smoke checks it carries the debug lines)
	check.call(App.debug_info().contains("device=") and App.debug_info().contains("arena frame ms") == not App.timings.frames.is_empty(),
			"timings: the debug info (and so the feedback note) carries the device line and, once a match was watched, the frame times")
	check.call(App.debug_info().get_slice("\n", 0).contains("  build "), "timings: the first debug line carries a build id on every platform")
	var draft_src := FileAccess.get_file_as_string("res://src/ui/screen_draft.gd")
	var match_src := FileAccess.get_file_as_string("res://src/ui/screen_match.gd")
	check.call(draft_src.contains("App.timings.draft_opened(") and draft_src.contains("App.timings.draft_done(") and draft_src.contains("App.timings.launched("),
			"timings: the Draft screen reports the draft time and Start the match")
	check.call(match_src.contains("App.timings.match_shown(") and match_src.contains("App.timings.frame(view_mode"),
			"timings: the Match screen reports the first frame and every frame with its view")
