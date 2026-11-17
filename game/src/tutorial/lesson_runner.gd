class_name LessonRunner
extends Node
## The optional lessons (TUTORIAL 4, build plan I-23). A Node on Main (App.lessons) that plays one lesson at a time with its own
## CoachOverlay on the overlay slot, the same cards, Skip and ids as the guided first game:
##   start(id)     goes to the lesson's start route (Home, Plan or Club; L5 only on Draft complete, L8 only on a real report) and
##                 shows step 1. Never while the guided first game is running.
##   steps         data/lessons_v1.json: a "tap" step completes on its event (tap:<id>, open:<sheet>), an "info" step on Next. A step
##                 may "prep" by navigating only (gp_phase:<phase>: the Game Plan page). Lessons NEVER change the club: every step
##                 that points at a control that would change data is an info step (its hole is covered by the overlay's blocker).
##   end           Skip ends it where the player is, not done. Next on the last step marks it done on the device (a tick in the list).
## Offers (`offer_for(place)`, the cards on Home, Club, Report, Draft complete): unlock rules from the data; never during the guide or
## before the first real game; at most one NEW offer per match day; Later snoozes for 3 match days, the third Later dismisses it
## (DeviceState.lesson_later); "Show help hints again" brings snoozed and dismissed back (DeviceState.lessons_reset_offers).

signal finished(lesson_id: String, done: bool)

static var _data: Dictionary = {}

var lesson_id := ""
var step_i := -1
var overlay: CoachOverlay
var fallbacks := 0
var wait_s := CoachOverlay.WAIT_S
var missing_s := CoachOverlay.MISSING_S


static func data() -> Dictionary:
	if _data.is_empty():
		var d = DataLoader.load_json("res://data/lessons_v1.json")
		_data = d if d is Dictionary else {"lessons": []}
	return _data


static func ids() -> Array:
	return (data()["lessons"] as Array).map(func(l: Dictionary) -> String: return String(l["id"]))


static func lesson(id: String) -> Dictionary:
	for l in data()["lessons"]:
		if String(l["id"]) == id:
			return l
	return {}


func _ready() -> void:
	if is_instance_valid(App.bus):
		App.bus.raised.connect(_on_event)


func device() -> DeviceState:
	return App.tutorial.device if App.tutorial != null and App.tutorial.device != null else DeviceState.new()


func running() -> bool:
	return lesson_id != ""


static func guide_running() -> bool:
	return App.tutorial != null and App.tutorial.m != null and App.tutorial.m.state() == "running"


# ---- unlock and offers ------------------------------------------------------------------------------------------------------------

## True when the lesson's unlock rule holds for this save (the data's numbers; `context` names the screen: "draftdone", "report").
static func unlocked(id: String, gs: GameState, context: String = "") -> bool:
	if gs == null:
		return false
	var u: Dictionary = (data().get("unlock", {}) as Dictionary).get(id, {})
	var rnd := int(gs.d.get("round", 0)) + (99 if String(gs.d.get("phase", "league")) != "league" else 0)
	var played := (gs.d.get("history", []) as Array).size()
	if u.has("games") and played < int(u["games"]):
		return false
	if u.has("real_draft_done"):
		return context == "draftdone"
	if u.has("real_report"):
		return context == "report"
	if u.has("fatigue"):
		var tired := false
		for pid in (gs.d["lineup"] as Dictionary).values():
			tired = tired or App.world.fatigue_of(String(pid)) >= float(u["fatigue"])
		return tired or rnd >= int(u.get("round", 99))
	if u.has("contract_ending"):
		var ending := false
		for pid in gs.d["roster"]:
			ending = ending or (gs.contract_of(String(pid)).size() > 0 and gs.seasons_left(String(pid)) <= 1)
		return (ending and rnd >= int(u.get("round", 99))) or String(gs.d.get("phase", "")) == "done"
	if u.has("round"):
		return rnd >= int(u["round"])
	return true


func _day_key(gs: GameState) -> String:
	return "%d-%d" % [int(gs.d.get("season", 1)), int(gs.d.get("round", 0))]


## The one lesson to offer at `place` now, or "" (TUTORIAL 4.1 offer rules).
func offer_for(place: String, context: String = "") -> String:
	var gs := App.gs
	if gs == null or guide_running() or running():
		return ""
	if (gs.d.get("history", []) as Array).is_empty():
		return ""    # never before the first real game is over
	var dev := device()
	var today := _day_key(gs)
	var new_today := String(dev.lesson_meta("new_day_lesson")) if dev.lesson_meta("new_day") == today else ""
	for l in data()["lessons"]:
		var id := String(l["id"])
		if String(l["place"]) != place:
			continue
		if not unlocked(id, gs, context):
			continue
		var st := dev.lesson_status(id)
		if st == "done" or st == "dismissed":
			continue
		if st.begins_with("snoozed"):
			if _round_index(gs) < int(dev.lesson_meta("until." + id)):
				continue
		var is_new := st == ""
		if is_new and new_today != "" and new_today != id:
			continue    # one new offer per match day
		if is_new:
			dev.set_lesson_status(id, "offered")
			dev.set_lesson_meta("new_day", today)
			dev.set_lesson_meta("new_day_lesson", id)
		return id
	return ""


static func _round_index(gs: GameState) -> int:
	return int(gs.d.get("season", 1)) * 1000 + int(gs.d.get("round", 0))


## Later: snooze for 3 match days (the third Later dismisses it).
func later(id: String) -> String:
	var dev := device()
	var st := dev.lesson_later(id)
	if App.gs != null:
		dev.set_lesson_meta("until." + id, _round_index(App.gs) + int(data().get("snooze_days", 3)))
	return st


# ---- running ------------------------------------------------------------------------------------------------------------------

## Start a lesson. False when it cannot start here (the guide is running, or L5 / L8 off their screen).
func start(id: String) -> bool:
	var l := lesson(id)
	if l.is_empty() or guide_running() or App.main == null:
		return false
	if running():
		stop(false)
	match String(l["start"]):
		"home":
			App.go_tab("home")
		"plan":
			App.go_tab("plan")
		"club":
			App.go_tab("club")
		"draftdone":
			var d := App.main.get("_current") as ScreenDraft
			if d == null or d.draft == null or not d.draft.is_done():
				return false
		"report":
			if not (App.main.get("_current") is ScreenReport):
				return false
	lesson_id = id
	step_i = -1
	fallbacks = 0
	_next()
	return true


func steps() -> Array:
	return lesson(lesson_id).get("steps", [])


func step() -> Dictionary:
	var s := steps()
	return s[step_i] if step_i >= 0 and step_i < s.size() else {}


func _next() -> void:
	step_i += 1
	if step_i >= steps().size():
		stop(true)
		return
	_present()


func _present() -> void:
	var s := step()
	var prep := String(s.get("prep", ""))
	if prep.begins_with("gp_phase:"):
		var gp := App.main.get("_current") as ScreenGamePlan
		if gp != null:
			gp._set_phase(prep.substr(9))    # navigation only: which page of the Game Plan shows
	_make_overlay()
	var info := String(s["kind"]) == "info"
	var c := {"id": String(s["id"]), "stage": "a", "target": (s["target"] as Array).slice(0, 1), "kind": String(s["kind"]), "dim": "full",
			"buttons": ["skip", "next"] if info else ["skip"], "compact": true, "step_no": step_i + 1, "chapter_key": "lesson.title." + lesson_id, "skip_key": "lesson.skip"}
	# a step with a fallback target (L3: the expiring bench card, else the first one) takes the first that exists
	for t in s["target"]:
		if UI.find_tag(String(t)) != null:
			c["target"] = [String(t)]
			break
	overlay.show_step(c, text_of(s))


func text_of(s: Dictionary) -> String:
	if s.has("key_locked") and App.gs != null and not App.gs.sponsor_changeable():
		return Strings.t(String(s["key_locked"]))
	return Strings.t("les." + String(s["id"]))


func _make_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		return
	overlay = CoachOverlay.new()
	overlay.theme = App.main.theme
	overlay.wait_s = wait_s
	overlay.missing_s = missing_s
	App.main.overlay_layer.add_child(overlay)
	overlay.button_pressed.connect(_on_button)
	overlay.fell_back.connect(func(_s: String) -> void: fallbacks += 1)


func _on_button(id: String) -> void:
	match id:
		"skip":
			stop(false)
		"next":
			if BottomSheet.is_open() and step_i == steps().size() - 1:
				BottomSheet.current().close()    # the last Next closes a sheet the lesson pointed into (L3)
			_next()


func _on_event(event_name: String, _d: Dictionary) -> void:
	if not running():
		return
	var s := step()
	if s.is_empty() or String(s["kind"]) != "tap":
		return
	if (s["done_on"] as Array).has(event_name):
		_next.call_deferred()


## End the lesson: done marks it on the device (a tick in the list); not done leaves the player where they are.
func stop(done: bool) -> void:
	var id := lesson_id
	lesson_id = ""
	step_i = -1
	if overlay != null and is_instance_valid(overlay):
		overlay.clear()
		overlay.get_parent().remove_child(overlay)
		overlay.queue_free()
	overlay = null
	if id != "":
		if done:
			device().set_lesson_status(id, "done")
		finished.emit(id, done)
