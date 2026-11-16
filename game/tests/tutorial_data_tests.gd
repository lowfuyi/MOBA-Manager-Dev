extends RefCounted
## I-11 the tutorial data (data/tutorial_v1.json) as TutorialState reads it: 27 steps in the TUTORIAL.md 3.2 order, chapters,
## resume targets, every text key in en.json, vocabulary of events and tags, counts of kinds. The same rules run in
## tools/validate_data.py (and its pytest negative controls); this is the Godot side, so a bad edit fails in both places.
## Headless: no autoloads, no UI classes. Auto-discovered by run_tests.gd (run(check)).

const IDS := ["welcome", "home_card", "tabs", "tab_squad", "squad_bench", "player_card",
		"tab_plan", "plan_practice", "quick_match", "matchups", "start_draft",
		"ban", "pick", "role", "coach_rest",
		"open_plan", "coach_suggest", "start_match", "watch", "see_report",
		"result", "why", "continue",
		"tab_club", "form_tile", "form_switch", "finish"]
## First step number of each chapter (TUTORIAL 3.1).
const CHAPTER_STARTS := [1, 5, 7, 12, 16, 21, 24]
## TUTORIAL 7.5 (the three tut: events are the card buttons).
const EVENTS := ["open:player_card", "open:lane_picker", "open:training_picker", "draft:sheet", "draft:ban", "draft:pick",
		"draft:done", "gp:coach_open", "gp:coach_apply", "gp:coach_close", "open:report_why", "stand:metric",
		"match:speed", "match:skip", "match:end", "tut:start", "tut:next", "tut:finish"]
## The first-run tags of TUTORIAL 8 (the stars).
const TAGS := ["tabbar", "tab.squad", "tab.plan", "tab.club", "home.next_card", "squad.bench.0", "roster.card.head",
		"plan.tile.practice", "practice.quick", "prematch.matchups", "prematch.start_draft", "draft.choices", "draft.slot_list",
		"draft.sheet.confirm", "draft.auto_rest", "draft.game_plan", "gp.coach", "gp.coach_apply", "gp.start_match",
		"match.controls", "match.report_btn", "report.result", "report.why", "report.why_sheet", "report.continue",
		"club.tile.form", "stand.metric"]


func run(check: Callable) -> void:
	TutorialState.use_data({})      # the file as shipped, whatever an earlier test file left
	var strings = DataLoader.load_json("res://i18n/en.json")
	check.call(strings is Dictionary and (strings as Dictionary).size() > 100, "en.json loads")
	var steps := TutorialState.steps()
	_shape(check, steps)
	_vocabulary(check, steps)
	_keys(check, steps, strings if strings is Dictionary else {})
	_resume_targets(check, steps)
	_kinds(check, steps)
	_accessors(check)


func _shape(check: Callable, steps: Array) -> void:
	check.call(steps.size() == 27, "tutorial_v1.json has 27 steps")
	var ids: Array = []
	for s in steps:
		ids.append(String(s.get("id", "")))
	check.call(JSON.stringify(ids) == JSON.stringify(IDS), "step ids are the 27 of TUTORIAL 3.2, in order")
	var seen := {}
	var uniq := true
	for id in ids:
		uniq = uniq and not seen.has(id)
		seen[id] = true
	check.call(uniq, "step ids are unique")
	var ch_ok := true
	var prev := 0
	for i in steps.size():
		var c := int(steps[i]["chapter"])
		var want := 1
		for k in CHAPTER_STARTS.size():
			if i + 1 >= int(CHAPTER_STARTS[k]):
				want = k + 1
		ch_ok = ch_ok and c == want and c >= prev
		prev = c
	check.call(ch_ok, "chapters 1 to 7 hold steps 1-4, 5-6, 7-11, 12-15, 16-20, 21-23, 24-27, never going back")
	check.call(JSON.stringify(TutorialState.STEP_IDS) == JSON.stringify(IDS), "TutorialState.STEP_IDS comes from the data")
	check.call(TutorialState.CHAPTER_OF.size() == 27 and TutorialState.CHAPTER_OF[0] == 1 and TutorialState.CHAPTER_OF[26] == 7, "CHAPTER_OF comes from the data")
	check.call(TutorialState.first_step_id() == "welcome", "first step is welcome")
	var order_ok := true
	for i in IDS.size():
		order_ok = order_ok and TutorialState.step_index(IDS[i]) == i
	check.call(order_ok and TutorialState.step_index("nope") == -1, "step_index matches the order; unknown id is -1")
	check.call(TutorialState.step_def("ban").get("id") == "ban" and TutorialState.step_def("nope").is_empty(), "step_def finds a step or gives {}")


func _vocabulary(check: Callable, steps: Array) -> void:
	var tags_ok := true
	var events_ok := true
	var taps_ok := true
	var bad := []
	for s in steps:
		var own: Array = (s["target"] as Array).duplicate()
		var sb: Dictionary = s.get("stage_b", {})
		if not sb.is_empty():
			own.append_array(sb["target"])
		for t in own:
			if not TAGS.has(t):
				tags_ok = false
				bad.append(str(s["id"]) + ":" + str(t))
		var evs: Array = (s["done_on"] as Array).duplicate()
		if not sb.is_empty():
			evs.append(sb["on"])
		if String(s.get("skip_if", "")).begins_with("event_seen:"):
			evs.append(String(s["skip_if"]).substr("event_seen:".length()))
		for e in evs:
			var es := String(e)
			var ok := EVENTS.has(es) or (es.begins_with("tap:") and TAGS.has(es.substr(4)))
			if not ok:
				events_ok = false
				bad.append(str(s["id"]) + ":" + es)
			if es.begins_with("tap:") and not own.has(es.substr(4)):
				taps_ok = false
		var done_data: Dictionary = s.get("done_data", {})
		for k in done_data:
			events_ok = events_ok and (s["done_on"] as Array).has(k)
	check.call(tags_ok, "every target tag is in the TUTORIAL 8 first-run list " + str(bad))
	check.call(events_ok, "every event a step waits for is in the TUTORIAL 7.5 list " + str(bad))
	check.call(taps_ok, "a step that waits for tap:<id> highlights that id")
	# the one skip_if event_seen of the table: step 14 and 15
	check.call(TutorialState.step_def("role").get("skip_if") == "event_seen:draft:pick" and TutorialState.step_def("coach_rest").get("skip_if") == "event_seen:draft:done" and TutorialState.step_def("home_card").get("skip_if") == "no_next_game", "skip_if of steps 2, 14 and 15 as in TUTORIAL 3.2")
	var with_skip_if := 0
	for s in steps:
		if s.has("skip_if"):
			with_skip_if += 1
	check.call(with_skip_if == 3, "exactly three steps carry a skip_if")
	check.call(TutorialState.step_def("role")["target"].size() == 2 and TutorialState.step_def("ban")["stage_b"]["target"] == ["draft.sheet.confirm"], "step 14 has two targets (one bounding hole); step 12 stage B is the sheet confirm")


func _keys(check: Callable, steps: Array, strings: Dictionary) -> void:
	var missing := []
	var n := 0
	for s in steps:
		var keys: Array = []
		for k in ["key", "key_win", "key_loss"]:
			if s.has(k):
				keys.append(s[k])
		for v in (s.get("variants", {}) as Dictionary).values():
			keys.append(v)
		if s.has("stage_b"):
			keys.append(s["stage_b"]["key"])
		if s.has("shortcut"):
			keys.append(s["shortcut"]["key"])
		for k in keys:
			n += 1
			if not strings.has(k) or String(strings[k]) == "":
				missing.append(k)
	check.call(missing.is_empty() and n >= 33, "every text key of every step exists in en.json (%d keys) %s" % [n, str(missing)])
	var ch_ok := true
	for c in range(1, 8):
		ch_ok = ch_ok and strings.has(TutorialState.chapter_key(c))
	check.call(ch_ok, "tut.ch.1 to tut.ch.7 exist")
	# a step's text is the helper's: no "advisor"
	var adv := false
	for k in strings:
		if String(k).begins_with("tut.") and String(strings[k]).to_lower().contains("advisor"):
			adv = true
	check.call(not adv, "no tut.* text says advisor (the helper is Coach)")
	# negative control: the check itself notices a missing key
	var probe := TutorialState.step_def("tabs").duplicate()
	probe["key"] = "tut.no.such.key"
	check.call(not strings.has(probe["key"]), "negative control: a made-up key is not in en.json")


func _resume_targets(check: Callable, steps: Array) -> void:
	var cs: Array = TutorialState.data().get("chapters", [])
	check.call(cs.size() == 7, "seven chapters")
	var ok := true
	for i in cs.size():
		ok = ok and int(cs[i]["n"]) == i + 1 and TutorialState.step_index(String(cs[i]["resume"])) >= 0
	check.call(ok, "every chapter's resume step exists")
	var want := {1: "home_card", 2: "tab_squad", 3: "tab_plan", 4: "tab_plan", 5: "tab_plan", 6: "tab_club", 7: "tab_club"}
	var same := true
	for k in want:
		same = same and String(TutorialState.RESUME_STEP.get(k, "")) == String(want[k])
	check.call(same, "resume steps are TUTORIAL 3.1: ch1 step 2, ch2 step 4, ch3 to 5 step 7, ch6 and 7 step 24")


func _kinds(check: Callable, steps: Array) -> void:
	var modal := 0
	var info := 0
	var do := 0
	var skip_ok := true
	var codes := {"A": 0, "B": 0, "C": 0, "none": 0}
	for i in steps.size():
		var s: Dictionary = steps[i]
		match String(s["kind"]):
			"modal":
				modal += 1
			"info":
				info += 1
			_:
				do += 1
		codes[String(s["skip"])] += 1
		skip_ok = skip_ok and ((s["buttons"] as Array).has("skip") == (s["skip"] != "none"))
		var want_code := "A" if i < 9 else ("B" if i < 20 else ("C" if i < 26 else "none"))
		skip_ok = skip_ok and String(s["skip"]) == want_code
	check.call(modal == 2 and info == 5 and do == 20, "2 modal, 5 info, 20 do-steps (TUTORIAL 3.2 counts)")
	check.call(skip_ok and codes["A"] == 9 and codes["B"] == 11 and codes["C"] == 6 and codes["none"] == 1, "skip codes: A for steps 1-9, B for 10-20, C for 21-26, none on the last card")
	var info_ids := []
	for s in steps:
		if s["kind"] == "info":
			info_ids.append(s["id"])
	check.call(info_ids == ["home_card", "tabs", "player_card", "matchups", "result"], "the five info steps are 2, 3, 6, 10, 21")
	check.call(TutorialState.step_def("watch")["dim"] == "none" and TutorialState.step_def("see_report")["dim"] == "light" and TutorialState.step_def("watch").get("passthrough") == true, "step 19 has no dim and passes taps through; step 20 is a light dim")
	check.call(TutorialState.step_def("coach_rest").get("hold_armed") == true and TutorialState.step_def("coach_suggest")["shortcut"]["does"] == "gp_coach_apply", "step 15 holds the armed state; step 17 has the Apply shortcut")


func _accessors(check: Callable) -> void:
	check.call(TutorialState.chapter_of("welcome") == 1 and TutorialState.chapter_of("pick") == 4 and TutorialState.chapter_of("form_switch") == 7 and TutorialState.chapter_of("") == 0, "chapter_of reads the data")
	check.call(TutorialState.chapter_key(4) == "tut.ch.4", "chapter_key")
	# edited data: use_data swaps the steps and the derived lists follow, and {} brings the file back
	var d: Dictionary = TutorialState.data().duplicate(true)
	(d["steps"] as Array).remove_at(13)       # drop "role"
	TutorialState.use_data(d)
	check.call(TutorialState.STEP_IDS.size() == 26 and TutorialState.step_index("role") == -1 and TutorialState.step_index("coach_rest") == 13, "use_data: a step removed from the data is gone and the order closes up")
	TutorialState.use_data({})
	check.call(TutorialState.STEP_IDS.size() == 27 and TutorialState.step_index("role") == 13, "use_data({}) restores the shipped file")
