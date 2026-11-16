class_name TutorialState
extends RefCounted
## The tutorial's brain (build plan 0.7 section 5 and I-11, TUTORIAL.md 3, 6 and 7). Pure logic: no UI classes, no
## autoloads, so it runs in run_tests.gd. Two halves in one file:
##   - statics: the save key (new_state, legacy_state, migrate), the step data (data/tutorial_v1.json) and the Home offer rule
##   - an instance: the event machine. `feed(event)` advances the guided first game and returns EFFECTS for the runner
##     (I-12) to carry out; nothing here touches the screen, the save file or settings.cfg by itself.
##
## The key (gs.d["tutorial"]):
##   {"v": 1, "state": "new"|"running"|"done"|"skipped"|"legacy", "step": "<id>",
##    "game": {"live": bool, "n": int, "plan": {...}}}
## `legacy` = a save made before the guide existed (a missing key). `new` = written by GameState.new_game() in 0.7
## and later: the player has not answered the guide yet.
##
## Effects (Dictionaries, "fx" names the kind): show {step, stage, chapter, kind}, stage {step, stage} (the hole moves to
## the stage-B control), passed {step} (a step passed over by skip_if, never silently), finish {state, code}, toast
## {key, undo}, device {section, key, value} (for DeviceState.apply), reset_events (a new run starts: the machine took a
## new EventBus bookmark), save (the tutorial key changed: autosave it). The machine only ever reads event names and
## their data; nothing in the game reads the machine to decide a result (build plan R6).

const VERSION := 1
const STATES := ["new", "running", "done", "skipped", "legacy"]
const DATA_PATH := "res://data/tutorial_v1.json"

static var _data: Dictionary = {}
static var _index: Dictionary = {}
## Step ids in order, chapter of each step (1 based) and the step a killed app resumes at (chapter -> id). All three are
## read from data/tutorial_v1.json; they are kept as public names for the I-06 callers and tests.
static var STEP_IDS: Array = _load_default()
static var CHAPTER_OF: Array = _chapters_list()
static var RESUME_STEP: Dictionary = _resume_map()

# ------------------------------------------------------------------ the instance (event machine)
var t: Dictionary = {}                   # the tutorial key, owned by the machine; snapshot() returns a copy
var stage := "a"                         # "a" (the step's own hole) or "b" (the second hole of a two-stage step)
var context: Dictionary = {}             # {"no_next_game": bool, "screen": "<help id>"} for skip_if, set by the runner
var resume_pending := false              # true right after a load of a running save: Home shows the resume card
var mark := 0                            # EventBus bookmark: events up to this sequence number belong to an earlier run
var _seen_fn: Callable = Callable()      # EventBus.seen(name, since) -> bool
var _seq_fn: Callable = Callable()       # EventBus.sequence() -> int
var _local_seen: Dictionary = {}         # events this machine was fed that some skip_if asks about
var _undo: Dictionary = {}


## `tut` must already be a valid tutorial dictionary (from migrate(), GameState.tutorial() or new_state()); anything
## else is passed through migrate(). A valid dictionary is NOT migrated again: migrate() applies the kill-resume rule,
## which must run once at load and never in the middle of a session.
func _init(tut = null, seen: Callable = Callable(), sequence: Callable = Callable()) -> void:
	if tut is Dictionary and is_valid(tut):
		t = (tut as Dictionary).duplicate(true)
	else:
		t = migrate(tut)
	attach(seen, sequence)


## A machine for a save that was just loaded: applies migrate() (the resume rule) and offers the resume card.
static func from_save(raw, seen: Callable = Callable(), sequence: Callable = Callable()) -> TutorialState:
	var m := TutorialState.new(migrate(raw), seen, sequence)
	m.resume_pending = m.state() == "running"
	return m


## Connect the EventBus: `bus.seen` and `bus.sequence` (bound methods). The machine takes a bookmark now, so events from
## before this moment never pass a step over.
func attach(seen: Callable, sequence: Callable) -> void:
	_seen_fn = seen
	_seq_fn = sequence
	_rebase()


func _rebase() -> void:
	_local_seen.clear()
	mark = int(_seq_fn.call()) if _seq_fn.is_valid() else 0


# ------------------------------------------------------------------ data (statics)
static func data() -> Dictionary:
	if _data.is_empty():
		var d = DataLoader.load_json(DATA_PATH)
		_data = d if d is Dictionary else {}
		_rebuild_index()
	return _data


## Tests only: replace the step data (an edited copy), or pass {} to read the file again.
static func use_data(d: Dictionary) -> void:
	_data = d.duplicate(true)
	if _data.is_empty():
		var f = DataLoader.load_json(DATA_PATH)
		_data = f if f is Dictionary else {}
	_rebuild_index()
	STEP_IDS = _ids()
	CHAPTER_OF = _chapters_list()
	RESUME_STEP = _resume_map()


static func _load_default() -> Array:
	data()
	return _ids()


static func _rebuild_index() -> void:
	_index = {}
	var s: Array = _data.get("steps", []) if _data.get("steps") is Array else []
	for i in s.size():
		if s[i] is Dictionary:
			_index[String((s[i] as Dictionary).get("id", ""))] = i


static func _ids() -> Array:
	var out: Array = []
	for s in steps():
		out.append(String((s as Dictionary).get("id", "")))
	return out


static func _chapters_list() -> Array:
	var out: Array = []
	for s in steps():
		out.append(int((s as Dictionary).get("chapter", 0)))
	return out


static func _resume_map() -> Dictionary:
	var out := {}
	var cs = data().get("chapters", [])
	if cs is Array:
		for c in cs:
			if c is Dictionary:
				out[int(c.get("n", 0))] = String(c.get("resume", ""))
	return out


## The 27 step dictionaries in order (read-only: do not edit them).
static func steps() -> Array:
	var s = data().get("steps", [])
	return s if s is Array else []


static func step_def(step_id: String) -> Dictionary:
	data()
	if not _index.has(step_id):
		return {}
	return steps()[int(_index[step_id])]


static func step_index(step_id: String) -> int:
	data()
	return int(_index.get(step_id, -1))


## The first step of the guided game ("welcome"), or "" when the data did not load.
static func first_step_id() -> String:
	return String(STEP_IDS[0]) if not STEP_IDS.is_empty() else ""


## 1 to 7, or 0 for an id that does not exist.
static func chapter_of(step_id: String) -> int:
	var i := step_index(step_id)
	return 0 if i < 0 else int(CHAPTER_OF[i])


static func chapter_key(chapter: int) -> String:
	return "tut.ch.%d" % chapter


## What GameState.new_game() writes in 0.7: the player has not answered the guide yet.
static func new_state() -> Dictionary:
	return {"v": VERSION, "state": "new", "step": first_step_id(), "game": {"live": false, "n": 0, "plan": {}}}


## What a save made before the guide existed (missing key) reads as.
static func legacy_state() -> Dictionary:
	return {"v": VERSION, "state": "legacy"}


## True for a dictionary that migrate() would hand back unchanged apart from the resume rule: right version, a known
## state, and (except legacy) a game part and a known step id.
static func is_valid(tut) -> bool:
	if not (tut is Dictionary):
		return false
	var d: Dictionary = tut
	var v = d.get("v", 0)
	if not (v is int or v is float) or int(v) != VERSION:
		return false
	var st = d.get("state", "")
	if not (st is String) or not STATES.has(String(st)):
		return false
	if st == "legacy":
		return true
	var g = d.get("game")
	if not (g is Dictionary) or not (g.get("plan") is Dictionary) or not (g.get("live") is bool) or not (g.get("n") is int):
		return false
	return d.get("step") is String and step_index(String(d["step"])) >= 0


## Turn whatever a save holds under "tutorial" into a valid tutorial dictionary. A new dictionary is returned;
## the argument is never modified (an unknown higher `v`, from a future build, stays untouched in the save).
##   - not a dictionary: legacy
##   - `v` above VERSION (or not a number): legacy
##   - `state` missing or not one of STATES: legacy
##   - running: the resume rule of plan section 5 item 10 (a killed app cannot continue a game; steps 21 to 23
##     resume at tab_club, steps 7 to 20 or a live game at tab_plan, chapter 2 at tab_squad, chapter 1 at home_card);
##     `game.live` becomes false and `game.plan` is emptied; `game.n` is never changed
##   - a step id that no longer exists: its chapter is unknown, so the first step of the guide's chapter 1 (home_card)
##   - new / done / skipped: unchanged apart from missing parts being filled in
##   - the step data did not load: legacy (nothing can be resumed)
static func migrate(t) -> Dictionary:
	if not (t is Dictionary) or STEP_IDS.is_empty():
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
	if not (out.get("step") is String) or step_index(String(out["step"])) < 0:
		out["step"] = first_step_id() if state == "new" else (String(RESUME_STEP[1]) if state == "running" else String(STEP_IDS[STEP_IDS.size() - 1]))
	if state == "new":
		out["step"] = first_step_id()
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


## What Home shows for this save and device (TUTORIAL 6.2, build plan 5 item 3):
##   "welcome_modal"  state new, this device never answered the guide
##   "returning_card" state new, the device answered before (Show me / No thanks card, no modal)
##   "legacy_card"    a save from before the guide, offered once per device
##   "resume_card"    running after a load (Continue / Skip tutorial)
##   "none"           done, skipped, a running guide that is already on screen, or a legacy offer already answered
static func offer_for(tut, welcome_seen: bool, legacy_offer_done: bool, resume: bool = true) -> String:
	var st: String = String((tut as Dictionary).get("state", "legacy")) if tut is Dictionary else "legacy"
	match st:
		"new":
			return "returning_card" if welcome_seen else "welcome_modal"
		"legacy":
			return "none" if legacy_offer_done else "legacy_card"
		"running":
			return "resume_card" if resume else "none"
	return "none"


# ------------------------------------------------------------------ reading the machine
func state() -> String:
	return String(t.get("state", "legacy"))


func is_running() -> bool:
	return state() == "running"


func step_id() -> String:
	return String(t.get("step", ""))


func step() -> Dictionary:
	return step_def(step_id())


func game() -> Dictionary:
	return t.get("game", {}) if t.get("game") is Dictionary else {}


## A copy of the tutorial key, ready for GameState.set_tutorial().
func snapshot() -> Dictionary:
	return t.duplicate(true)


## "A", "B", "C" or "none" for the current step (TUTORIAL 3.2 skip codes).
func skip_code() -> String:
	return String(step().get("skip", "A"))


## Skip is on every card except the last (no Skip on the closing modal).
func can_skip() -> bool:
	var st := state()
	if st == "new":
		return true
	return st == "running" and skip_code() != "none"


## The text key for the current step and stage. `outcome` "win" or "loss" picks the report step's text (anything else
## reads as win); `variant` ("alt", "arena") picks an alternative text where the step has one.
func text_key(outcome: String = "", variant: String = "") -> String:
	var st := step()
	if st.is_empty():
		return ""
	if stage == "b" and st.get("stage_b") is Dictionary:
		return String(st["stage_b"].get("key", ""))
	if variant != "" and st.get("variants") is Dictionary and (st["variants"] as Dictionary).has(variant):
		return String(st["variants"][variant])
	if st.has("key_win") and st.has("key_loss"):
		return String(st["key_loss"] if outcome == "loss" else st["key_win"])
	return String(st.get("key", ""))


## Everything the overlay needs to draw the current step. Empty when no step is up.
func card(outcome: String = "", variant: String = "") -> Dictionary:
	var st := step()
	if st.is_empty() or not (state() == "running" or (state() == "new" and stage == "a")):
		return {}
	var b: Dictionary = st["stage_b"] if stage == "b" and st.get("stage_b") is Dictionary else {}
	var sc: Dictionary = st["shortcut"] if st.get("shortcut") is Dictionary else {}
	return {
		"id": String(st["id"]), "step_no": step_index(String(st["id"])) + 1, "chapter": int(st["chapter"]),
		"chapter_key": chapter_key(int(st["chapter"])), "kind": String(st["kind"]), "dim": String(st["dim"]),
		"stage": stage, "target": (b.get("target", st["target"]) as Array).duplicate(),
		"key": text_key(outcome, variant), "compact": bool(b.get("compact", false)) if not b.is_empty() else bool(st.get("compact", false)),
		"buttons": (b.get("buttons", st["buttons"]) as Array).duplicate(),
		"shortcut_key": String(sc.get("key", "")), "shortcut_does": String(sc.get("does", "")),
		"hold_armed": bool(st.get("hold_armed", false)), "passthrough": bool(st.get("passthrough", false)),
		"skip": String(st["skip"]),
	}


## The line testers paste with feedback (TUTORIAL 6.1; App.debug_info() gets it in I-12). `total_s` and `fallbacks` are
## counted by the overlay runner.
func debug_line(total_s: float = 0.0, fallbacks: int = 0) -> String:
	var skipped_at := step_id() if state() == "skipped" else "none"
	return "tutorial=%s step_skipped=%s total_s=%d fallbacks=%d" % [state(), skipped_at, int(total_s), fallbacks]


# ------------------------------------------------------------------ doing things
## Start (welcome modal), Show me (an offer card) and Replay (Settings) all begin a run: state running at the first
## step (the welcome modal), `game.n` up by one (so the tutorial game is a new seed), no live game, empty sandbox plan.
## The device remembers the answer. `n` rises only here (and never on a resume).
func accept() -> Array:
	var before := _snap()
	var fx: Array = []
	_begin(fx)
	return _close(fx, before)


## Replay is the same act as accept(); the name is for the Settings button.
func replay() -> Array:
	return accept()


## No thanks on an offer card. A new save becomes skipped (the device remembers the answer). A legacy save stays
## legacy (its one offer per device is used up). Anything else is ignored.
func decline() -> Array:
	var before := _snap()
	var fx: Array = []
	match state():
		"new":
			t["state"] = "skipped"
			fx.append(_dev("welcome_seen"))
			fx.append(_dev("skipped_once"))
			fx.append({"fx": "toast", "key": "tut.skipped_toast", "undo": false})
			fx.append({"fx": "finish", "state": "skipped", "code": "A"})
		"legacy":
			fx.append(_dev("legacy_offer_done"))
	return _close(fx, before)


## Continue on the resume card: nothing changes except that the card is answered.
func continue_resume() -> Array:
	if not (is_running() and resume_pending):
		return []
	resume_pending = false
	return [_show_fx()]


## The Skip button (and Android back, then Skip tutorial). One tap. Not on the closing card.
## A running skip can be undone while the toast is up (undo_skip, expire_undo).
func skip() -> Array:
	var before := _snap()
	var fx: Array = []
	var st := state()
	if st == "new":
		t["state"] = "skipped"
		fx.append(_dev("welcome_seen"))
		fx.append(_dev("skipped_once"))
		fx.append({"fx": "toast", "key": "tut.skipped_toast", "undo": false})
		fx.append({"fx": "finish", "state": "skipped", "code": "A"})
	elif st == "running":
		var code := skip_code()
		if code == "none":
			return []
		_undo = {"step": step_id(), "stage": stage}
		t["state"] = "skipped"
		resume_pending = false
		fx.append(_dev("skipped_once"))
		fx.append({"fx": "toast", "key": "tut.skipped_toast", "undo": true})
		fx.append({"fx": "finish", "state": "skipped", "code": code})
	else:
		return []
	return _close(fx, before)


func undo_available() -> bool:
	return state() == "skipped" and not _undo.is_empty()


## Undo on the skip toast: the same step and stage again, if the toast is still up (expire_undo not yet called).
func undo_skip() -> Array:
	if not undo_available():
		return []
	var before := _snap()
	t["state"] = "running"
	t["step"] = String(_undo["step"])
	stage = String(_undo["stage"])
	_undo = {}
	return _close([], before)


## The toast is gone: the tutorial stays skipped.
func expire_undo() -> void:
	_undo = {}


## The runner reports a tutorial game starting or being left. A game that is left drops its sandbox plan.
## Allowed while running or after a skip (SK-B: the game goes on); ignored for new and legacy.
func set_game_live(live: bool) -> Array:
	if state() in ["new", "legacy"]:
		return []
	var before := _snap()
	var g: Dictionary = game()
	g["live"] = live
	if not live:
		g["plan"] = {}
	t["game"] = g
	return _close([], before)


## The sandbox plan the tutorial game edits (a copy of it is saved so a kill can clear it).
func set_game_plan(plan: Dictionary) -> Array:
	if state() in ["new", "legacy"]:
		return []
	var g: Dictionary = game()
	g["plan"] = plan.duplicate(true)
	t["game"] = g
	return [{"fx": "save"}]


## The context skip_if reads ("no_next_game", "screen"). Re-checks the current step, so a step that is now to be
## passed over is passed over.
func set_context(c: Dictionary) -> Array:
	context = c.duplicate(true)
	var before := _snap()
	var fx: Array = []
	if is_running():
		_settle(fx)
	return _close(fx, before)


## One event from the EventBus (`bus.raised`), or a card button as an event: "tut:start" (Start), "tut:next" (Next),
## "tut:finish" (Go to Home). Returns the effects; [] when the event means nothing here. The event only ever moves the
## machine one step forward (or to stage B); it never skips ahead, and a step passed over by skip_if shows as "passed".
func feed(event: String, data: Dictionary = {}) -> Array:
	var before := _snap()
	var fx: Array = []
	var st := state()
	if st == "new":
		if event == "tut:start":
			_begin(fx)
			_complete(fx)
		return _close(fx, before)
	if st != "running":
		return []
	if _watched().has(event):
		_local_seen[event] = true
	var cur := step()
	if cur.is_empty():
		return []
	if _done_by(cur, event, data):
		_complete(fx)
	elif stage == "a" and cur.get("stage_b") is Dictionary and _matches(cur["stage_b"].get("on", ""), cur["stage_b"].get("on_data", {}), event, data):
		stage = "b"
		_settle(fx)
	else:
		_settle(fx)
	return _close(fx, before)


# ------------------------------------------------------------------ internals
func _snap() -> String:
	return "%s|%s|%s|%d|%s" % [state(), step_id(), stage, int(game().get("n", 0)), str(game().get("live", false))]


## Add what changed since `before` to the effects: show (a new step), stage (hole moved), save (always when anything moved).
func _close(fx: Array, before: String) -> Array:
	if _snap() != before:
		if is_running():
			var was: PackedStringArray = before.split("|")
			if was.size() < 3 or was[0] != "running" or was[1] != step_id():
				fx.append(_show_fx())
			elif was[2] != stage:
				fx.append({"fx": "stage", "step": step_id(), "stage": stage})
		fx.append({"fx": "save"})
	return fx


func _show_fx() -> Dictionary:
	var st := step()
	return {"fx": "show", "step": step_id(), "stage": stage, "chapter": int(st.get("chapter", 0)), "kind": String(st.get("kind", ""))}


func _dev(key: String) -> Dictionary:
	return {"fx": "device", "section": "tutorial", "key": key, "value": true}


func _begin(fx: Array) -> void:
	var was_legacy := state() == "legacy"
	var n := int(game().get("n", 0)) + 1
	t = {"v": VERSION, "state": "running", "step": first_step_id(), "game": {"live": false, "n": n, "plan": {}}}
	stage = "a"
	_undo = {}
	resume_pending = false
	_rebase()
	fx.append({"fx": "reset_events"})
	fx.append(_dev("welcome_seen"))
	if was_legacy:
		fx.append(_dev("legacy_offer_done"))
	_settle(fx)


## The current step is done: go to the next one (or finish the guide), then pass over any step skip_if says to.
func _complete(fx: Array) -> void:
	var i := step_index(step_id())
	stage = "a"
	if i + 1 >= STEP_IDS.size():
		t["state"] = "done"
		fx.append(_dev("finished_once"))
		fx.append({"fx": "finish", "state": "done", "code": ""})
		return
	t["step"] = String(STEP_IDS[i + 1])
	_settle(fx)


## Pass over every step whose skip_if holds, starting with the current one. Each is reported ("passed"), none silently.
func _settle(fx: Array) -> void:
	while is_running():
		var cur := step()
		if cur.is_empty():
			return
		var cond := String(cur.get("skip_if", ""))
		if cond == "" or not _cond(cond):
			return
		fx.append({"fx": "passed", "step": String(cur["id"])})
		var i := step_index(String(cur["id"]))
		if i + 1 >= STEP_IDS.size():
			return
		t["step"] = String(STEP_IDS[i + 1])
		stage = "a"


func _cond(cond: String) -> bool:
	if cond == "no_next_game":
		return bool(context.get("no_next_game", false))
	if cond.begins_with("already_on:"):
		return String(context.get("screen", "")) == cond.substr("already_on:".length())
	if cond.begins_with("event_seen:"):
		return _event_seen(cond.substr("event_seen:".length()))
	return false      # target_missing and anything unknown: never skip silently


## The event happened since this run began. The machine's own memory of what it was fed (only events some skip_if asks
## about) is checked first; then the EventBus ring buffer from the run's bookmark, which only holds the last 64 events.
func _event_seen(name: String) -> bool:
	if _local_seen.has(name):
		return true
	return _seen_fn.is_valid() and bool(_seen_fn.call(name, mark))


func _watched() -> Dictionary:
	var w := {}
	for s in steps():
		var c := String((s as Dictionary).get("skip_if", ""))
		if c.begins_with("event_seen:"):
			w[c.substr("event_seen:".length())] = true
	return w


func _done_by(cur: Dictionary, event: String, data: Dictionary) -> bool:
	var done: Array = cur.get("done_on", [])
	if not done.has(event):
		return false
	var filt = cur.get("done_data", {})
	return _data_ok(filt.get(event, {}) if filt is Dictionary else {}, data)


func _matches(want: String, filt, event: String, data: Dictionary) -> bool:
	return want != "" and want == event and _data_ok(filt if filt is Dictionary else {}, data)


static func _data_ok(filt: Dictionary, data: Dictionary) -> bool:
	for k in filt:
		if not data.has(k) or data[k] != filt[k]:
			return false
	return true
