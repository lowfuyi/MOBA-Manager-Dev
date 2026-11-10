class_name TutorialState
extends RefCounted
## The tutorial's save key and its migration (build plan 0.7 section 5, TUTORIAL.md 3.1 and 6.1). Pure logic:
## no UI classes, no autoloads, so it runs in run_tests.gd. I-06 holds the save key, the factories and migrate();
## I-11 adds the event machine (feed, stages, skip with Undo) to this same file.
##
## The key (gs.d["tutorial"]):
##   {"v": 1, "state": "new"|"running"|"done"|"skipped"|"legacy", "step": "<id>",
##    "game": {"live": bool, "n": int, "plan": {...}}}
## `legacy` = a save made before the guide existed (a missing key). `new` = written by GameState.new_game() in 0.7
## and later: the player has not answered the guide yet.

const VERSION := 1
const STATES := ["new", "running", "done", "skipped", "legacy"]

## The 27 steps of TUTORIAL 3.2, in order. I-11 reads data/tutorial_v1.json; until then this list is the source of
## the ids that migrate() needs (a step id that is not here counts as unknown).
const STEP_IDS := ["welcome", "home_card", "tabs", "tab_squad", "squad_bench", "player_card",
		"tab_plan", "plan_practice", "quick_match", "matchups", "start_draft",
		"ban", "pick", "role", "coach_rest",
		"open_plan", "coach_suggest", "start_match", "watch", "see_report",
		"result", "why", "continue",
		"tab_club", "form_tile", "form_switch", "finish"]
## Chapter of each step (1 based) and the step a killed app resumes at (TUTORIAL 3.1 "Resume at", plan 5 item 10).
const CHAPTER_OF := [1, 1, 1, 1, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5, 6, 6, 6, 7, 7, 7, 7]
const RESUME_STEP := {1: "home_card", 2: "tab_squad", 3: "tab_plan", 4: "tab_plan", 5: "tab_plan", 6: "tab_club", 7: "tab_club"}


## What GameState.new_game() writes in 0.7: the player has not answered the guide yet.
static func new_state() -> Dictionary:
	return {"v": VERSION, "state": "new", "step": "welcome", "game": {"live": false, "n": 0, "plan": {}}}


## What a save made before the guide existed (missing key) reads as.
static func legacy_state() -> Dictionary:
	return {"v": VERSION, "state": "legacy"}


static func step_index(step_id: String) -> int:
	return STEP_IDS.find(step_id)


## 1 to 7, or 0 for an id that does not exist.
static func chapter_of(step_id: String) -> int:
	var i := STEP_IDS.find(step_id)
	return 0 if i < 0 else int(CHAPTER_OF[i])


## Turn whatever a save holds under "tutorial" into a valid tutorial dictionary. A new dictionary is returned;
## the argument is never modified (an unknown higher `v`, from a future build, stays untouched in the save).
##   - not a dictionary: legacy
##   - `v` above VERSION (or not a number): legacy
##   - `state` missing or not one of STATES: legacy
##   - running: the resume rule of plan section 5 item 10 (a killed app cannot continue a game; steps 21 to 23
##     resume at tab_club, steps 7 to 20 or a live game at tab_plan, chapter 2 at tab_squad, chapter 1 at home_card);
##     `game.live` becomes false and `game.plan` is emptied; `game.n` is never changed
##   - a step id that no longer exists: the first step of chapter 1 (home_card), since its chapter is unknown
##   - new / done / skipped: unchanged apart from missing parts being filled in
static func migrate(t) -> Dictionary:
	if not (t is Dictionary):
		return legacy_state()
	var src: Dictionary = t
	var v = src.get("v", VERSION)
	if not (v is int or v is float) or int(v) > VERSION or int(v) < 1:
		return legacy_state()
	var state: String = String(src.get("state", "")) if src.get("state", "") is String else ""
	if not STATES.has(state):
		return legacy_state()
	var out: Dictionary = src.duplicate(true)
	out["v"] = VERSION
	out["state"] = state
	if state == "legacy":
		return out
	var g: Dictionary = out["game"] if out.get("game") is Dictionary else {}
	g["live"] = bool(g.get("live", false))
	g["n"] = int(g.get("n", 0))
	if not (g.get("plan") is Dictionary):
		g["plan"] = {}
	out["game"] = g
	if not (out.get("step") is String) or not STEP_IDS.has(String(out["step"])):
		out["step"] = "welcome" if state == "new" else ("home_card" if state == "running" else "finish")
	if state == "new":
		out["step"] = "welcome"
	elif state == "running":
		_resume(out)
	return out


## The resume rule, applied in place to a running tutorial that was just loaded (nothing can be live after a load).
static func _resume(t: Dictionary) -> void:
	var g: Dictionary = t["game"]
	var ch := chapter_of(String(t["step"]))
	var to := ""
	if ch >= 6:
		to = String(RESUME_STEP[6] if ch == 6 else RESUME_STEP[7])
	elif bool(g["live"]) or ch == 3 or ch == 4 or ch == 5:
		to = String(RESUME_STEP[3])
	else:
		to = String(RESUME_STEP[ch])
	t["step"] = to
	g["live"] = false
	g["plan"] = {}
