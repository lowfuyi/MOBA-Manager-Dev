extends RefCounted
## I-11 DeviceState: the device's memory of the guide, the lessons and the "?" dots in settings.cfg ([tutorial], [lessons],
## [help]; the old [tips] keys count as help seen). Uses a temporary file under user://, never the real settings.cfg.
## Headless: no autoloads, no UI classes. Auto-discovered by run_tests.gd (run(check)).

const PATH := "user://device_state_test.cfg"


func run(check: Callable) -> void:
	_clean()
	_tutorial_flags(check)
	_apply_effects(check)
	_lessons(check)
	_help_and_tips(check)
	_resets(check)
	_other_sections_survive(check)
	_garbage(check)
	_home_offer_flow(check)
	_clean()


func _clean() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _cf() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(PATH)
	return cf


func _tutorial_flags(check: Callable) -> void:
	_clean()
	var d := DeviceState.new(PATH)
	check.call(not FileAccess.file_exists(PATH), "a new DeviceState writes nothing")
	var all_false := true
	for k in DeviceState.TUTORIAL_FLAGS:
		all_false = all_false and not d.tutorial_flag(k)
	check.call(all_false, "no file: every tutorial flag reads false")
	check.call(not FileAccess.file_exists(PATH), "reading never creates the file")
	check.call(d.set_tutorial_flag("welcome_seen") and d.tutorial_flag("welcome_seen") and not d.tutorial_flag("finished_once"), "set welcome_seen: true, the others unchanged")
	check.call(DeviceState.new(PATH).tutorial_flag("welcome_seen"), "the flag survives a new DeviceState (it is in the file)")
	check.call(_cf().get_value("tutorial", "welcome_seen") == true, "it is stored in section [tutorial], key welcome_seen, as a bool")
	check.call(d.set_tutorial_flag("welcome_seen", false) and not d.tutorial_flag("welcome_seen"), "a flag can be cleared")
	var before := FileAccess.get_file_as_string(PATH)
	check.call(not d.set_tutorial_flag("made_up") and FileAccess.get_file_as_string(PATH) == before, "an unknown flag name is refused and nothing is written")
	check.call(not d.tutorial_flag("made_up"), "an unknown flag reads false")
	for k in DeviceState.TUTORIAL_FLAGS:
		d.set_tutorial_flag(k)
	var all_true := true
	for k in DeviceState.TUTORIAL_FLAGS:
		all_true = all_true and d.tutorial_flag(k)
	check.call(all_true, "all five flags can be set and read back")
	# a hand-edited value of the wrong type is not a yes
	var cf := _cf()
	cf.set_value("tutorial", "welcome_seen", "yes")
	cf.set_value("tutorial", "finished_once", 1)
	cf.save(PATH)
	check.call(not d.tutorial_flag("welcome_seen") and not d.tutorial_flag("finished_once"), "a flag holding a string or a number reads false (only a real bool counts)")


func _apply_effects(check: Callable) -> void:
	_clean()
	var d := DeviceState.new(PATH)
	var m := TutorialState.new(TutorialState.new_state())
	var n := 0
	for e in m.feed("tut:start"):
		if d.apply(e):
			n += 1
	check.call(n == 1 and d.tutorial_flag("welcome_seen"), "applying the effects of Start sets welcome_seen (and ignores show, save and the rest)")
	var m2 := TutorialState.new({"v": 1, "state": "running", "step": "tabs", "game": {"live": false, "n": 1, "plan": {}}})
	for e in m2.skip():
		d.apply(e)
	check.call(d.tutorial_flag("skipped_once") and not d.tutorial_flag("finished_once"), "Skip sets skipped_once only")
	var m3 := TutorialState.new({"v": 1, "state": "running", "step": "finish", "game": {"live": false, "n": 1, "plan": {}}})
	for e in m3.feed("tut:finish"):
		d.apply(e)
	check.call(d.tutorial_flag("finished_once"), "finishing sets finished_once")
	check.call(not d.apply({"fx": "save"}) and not d.apply({"fx": "device", "section": "lessons", "key": "welcome_seen"}) and not d.apply({"fx": "device", "section": "tutorial", "key": "bogus"}), "apply refuses other effects, other sections and unknown keys")
	var ml := TutorialState.new(TutorialState.legacy_state())
	for e in ml.decline():
		d.apply(e)
	check.call(d.tutorial_flag("legacy_offer_done"), "No thanks on a legacy save sets legacy_offer_done")


func _lessons(check: Callable) -> void:
	_clean()
	var d := DeviceState.new(PATH)
	check.call(d.lesson_status("l1") == "" and d.lesson_ids().is_empty(), "no file: a lesson has no status")
	for s in ["offered", "snoozed:1", "snoozed:2", "dismissed", "done"]:
		check.call(d.set_lesson_status("l1", s) and d.lesson_status("l1") == s and DeviceState.new(PATH).lesson_status("l1") == s, "lesson status round trip: " + s)
	check.call(_cf().get_value("lessons", "l1") == "done", "stored under [lessons] as a string")
	var before := FileAccess.get_file_as_string(PATH)
	for bad in ["snoozed:0", "snoozed:3", "snoozed:x", "snoozed:", "Done", "later", " done"]:
		check.call(not d.set_lesson_status("l1", bad), "invalid status refused: '%s'" % bad)
	check.call(FileAccess.get_file_as_string(PATH) == before and d.lesson_status("l1") == "done", "invalid statuses write nothing")
	check.call(not d.set_lesson_status("", "done") and not d.set_lesson_status("L 1", "done") and not d.set_lesson_status("a=b", "done"), "invalid lesson ids refused")
	check.call(d.set_lesson_status("l1", "") and d.lesson_status("l1") == "" and not d.lesson_ids().has("l1"), "an empty status clears the lesson")
	check.call(d.set_lesson_status("nope_never", "") and d.lesson_status("nope_never") == "", "clearing a lesson that was never set is fine")
	# Later: snoozed:1, snoozed:2, then dismissed for good (TUTORIAL 4.1)
	check.call(d.lesson_later("l2") == "snoozed:1" and d.lesson_status("l2") == "snoozed:1", "first Later: snoozed:1")
	check.call(d.lesson_later("l2") == "snoozed:2", "second Later: snoozed:2")
	check.call(d.lesson_later("l2") == "dismissed" and d.lesson_status("l2") == "dismissed", "third Later: dismissed for good")
	check.call(d.lesson_later("l2") == "dismissed", "Later on a dismissed lesson stays dismissed")
	d.set_lesson_status("l3", "done")
	check.call(d.lesson_later("l3") == "done" and d.lesson_status("l3") == "done", "Later on a done lesson does nothing (negative control)")
	d.set_lesson_status("l4", "offered")
	check.call(d.lesson_later("l4") == "snoozed:1", "Later on an offered lesson: snoozed:1")
	check.call(d.lesson_later("bad id") == "" and d.lesson_status("bad id") == "", "Later with an invalid id writes nothing")
	check.call(d.lesson_ids().size() == 3 and d.lesson_ids().has("l2") and d.lesson_ids().has("l3") and d.lesson_ids().has("l4"), "lesson_ids lists what was written")
	# a hand-edited garbage value reads as never offered
	var cf := _cf()
	cf.set_value("lessons", "l5", "banana")
	cf.set_value("lessons", "l6", 7)
	cf.save(PATH)
	check.call(d.lesson_status("l5") == "" and d.lesson_status("l6") == "", "a garbage lesson value reads as never offered")


func _help_and_tips(check: Callable) -> void:
	_clean()
	var d := DeviceState.new(PATH)
	check.call(not d.help_seen("home") and d.help_ids().is_empty(), "no file: no help dot is cleared")
	check.call(d.help_mark("home") and d.help_seen("home") and not d.help_seen("squad") and DeviceState.new(PATH).help_seen("home"), "help_mark clears one screen's dot, persists, leaves the others")
	check.call(_cf().get_value("help", "home") == true, "stored under [help] as a bool")
	check.call(not d.help_mark("") and not d.help_mark("a b"), "invalid help ids refused")
	# the old tips of 0.6 live in [tips] and count as help already seen
	_clean()
	var cf := ConfigFile.new()
	cf.set_value("tips", "hub", true)
	cf.set_value("tips", "report", true)
	cf.set_value("tips", "prematch", false)
	cf.save(PATH)
	check.call(d.help_seen("home"), "old tip hub dismissed: Home help counts as seen")
	check.call(d.help_seen("report"), "old tip report dismissed: Report help counts as seen")
	check.call(not d.help_seen("prematch"), "old tip prematch not dismissed: Pre-match help not seen")
	check.call(not d.help_seen("squad") and not d.help_seen("draft") and not d.help_seen("settings"), "the old tips do not clear any other screen's dot (negative control)")
	check.call(d.help_ids().is_empty(), "mapping is read-only: nothing was written into [help]")
	var tips_before: Variant = _cf().get_value("tips", "hub")
	d.help_mark("squad")
	check.call(_cf().get_value("tips", "hub") == tips_before, "the [tips] section is not touched by DeviceState")
	# App.tips_reset (old button) erases [tips]: the mapped dots come back, [help] marks stay
	var cf2 := _cf()
	cf2.erase_section("tips")
	cf2.save(PATH)
	check.call(not d.help_seen("home") and d.help_seen("squad"), "after the old tips are reset the mapped dot returns; real [help] marks stay")


func _resets(check: Callable) -> void:
	_clean()
	var d := DeviceState.new(PATH)
	var cf := ConfigFile.new()
	cf.set_value("tips", "hub", true)
	cf.save(PATH)
	d.help_mark("squad")
	d.help_mark("draft")
	d.set_lesson_status("l1", "done")
	d.set_lesson_status("l2", "dismissed")
	d.lesson_later("l3")
	d.set_lesson_status("l4", "offered")
	check.call(d.help_seen("home") and d.help_seen("squad"), "before the reset: the dots are cleared")
	d.help_reset()
	check.call(not d.help_seen("squad") and not d.help_seen("draft") and d.help_ids().is_empty(), "help_reset: every dot is back")
	check.call(not d.help_seen("home"), "help_reset: the old Home tip no longer counts either")
	check.call(d.lesson_status("l2") == "dismissed" and d.lesson_status("l1") == "done", "help_reset alone leaves lessons as they are")
	d.help_mark("plan")
	check.call(d.help_seen("plan") and not d.help_seen("home"), "after a reset a new mark works and the old tip stays ignored")
	d.hints_reset()
	check.call(d.lesson_status("l1") == "done", "Show help hints again: a done lesson keeps its tick")
	check.call(d.lesson_status("l2") == "offered" and d.lesson_status("l3") == "offered" and d.lesson_status("l4") == "offered", "...dismissed and snoozed lessons go back to offered")
	check.call(not d.help_seen("plan"), "...and the dots are cleared")
	check.call(d.lessons_reset_offers() == 0, "a second reset changes nothing")
	var ids_ok := d.lesson_ids().size() == 4
	check.call(ids_ok, "no lesson was lost by the reset")


func _other_sections_survive(check: Callable) -> void:
	_clean()
	# App writes [ui] settings to the same file; DeviceState must not lose them (and vice versa)
	var cf := ConfigFile.new()
	cf.set_value("ui", "large_text", true)
	cf.set_value("ui", "animate", false)
	cf.set_value("tips", "hub", true)
	cf.save(PATH)
	var d := DeviceState.new(PATH)
	d.set_tutorial_flag("welcome_seen")
	d.set_lesson_status("l1", "done")
	d.help_mark("home")
	d.lesson_later("l2")
	d.help_reset()
	d.hints_reset()
	var after := _cf()
	check.call(after.get_value("ui", "large_text") == true and after.get_value("ui", "animate") == false, "[ui] values survive every DeviceState write and reset")
	check.call(after.get_value("tips", "hub") == true, "[tips] survives every DeviceState write and reset")
	check.call(after.get_value("tutorial", "welcome_seen") == true and after.get_value("lessons", "l1") == "done", "tutorial flags and done lessons survive a hints reset")
	# and the other way round: App-style writes to [ui] keep our sections
	var cf2 := _cf()
	cf2.set_value("ui", "colorblind", true)
	cf2.save(PATH)
	check.call(d.tutorial_flag("welcome_seen") and d.lesson_status("l1") == "done", "a write to [ui] keeps [tutorial] and [lessons]")


func _garbage(check: Callable) -> void:
	_clean()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("this is [[[ not a config file\n= = =\n")
	f.close()
	var d := DeviceState.new(PATH)
	check.call(not d.tutorial_flag("welcome_seen") and d.lesson_status("l1") == "" and not d.help_seen("home"), "an unreadable settings file reads as nothing remembered (no crash)")
	check.call(d.lesson_ids().is_empty() and d.help_ids().is_empty(), "...and lists nothing")
	check.call(d.set_tutorial_flag("welcome_seen") and d.tutorial_flag("welcome_seen"), "a write replaces an unreadable file with a good one")
	# a section holding the wrong kind of thing
	var cf := ConfigFile.new()
	cf.set_value("help", "home", "yes")
	cf.set_value("help", "squad", 1)
	cf.save(PATH)
	check.call(not d.help_seen("home") and not d.help_seen("squad"), "a help value that is not a bool is not 'seen'")
	check.call(DeviceState.new("user://no_such_dir_xyz/settings.cfg").tutorial_flag("welcome_seen") == false, "a path that cannot be read reads as nothing remembered")


func _home_offer_flow(check: Callable) -> void:
	_clean()
	var d := DeviceState.new(PATH)
	var nw := TutorialState.new_state()
	check.call(d.home_offer(nw) == "welcome_modal", "fresh device, new save: welcome modal")
	check.call(d.home_offer(TutorialState.legacy_state()) == "legacy_card", "fresh device, legacy save: inline card")
	d.set_tutorial_flag("welcome_seen")
	check.call(d.home_offer(nw) == "returning_card", "welcome answered on this device: a new save gets the inline card, not the modal")
	check.call(d.home_offer(TutorialState.legacy_state()) == "legacy_card", "welcome_seen does not answer the legacy offer")
	d.set_tutorial_flag("legacy_offer_done")
	check.call(d.home_offer(TutorialState.legacy_state()) == "none", "legacy offer answered: nothing")
	check.call(d.home_offer({"v": 1, "state": "running", "step": "tab_plan", "game": {"live": false, "n": 1, "plan": {}}}) == "resume_card", "running save: resume card")
	check.call(d.home_offer({"v": 1, "state": "done"}) == "none", "done: nothing")
	# the 'Delete save and start over' path: device flags stay, so the second club gets the inline card
	var again := TutorialState.new_state()
	check.call(d.home_offer(again) == "returning_card", "Delete save and start over: device flags stay, the new club gets the inline card")
