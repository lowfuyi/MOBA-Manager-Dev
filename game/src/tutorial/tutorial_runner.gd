class_name TutorialRunner
extends Node
## The only object `Main` talks to for the guided first game (build plan 0.7 I-12). It owns the event machine (`TutorialState`, I-11),
## the overlay (`CoachOverlay`) and the EventBus subscription, and carries out every effect the machine returns:
##   show / stage  -> present the card of the current step (the overlay finds the target itself)
##   passed        -> remembered in `passed` (a step passed over by skip_if, never silently)
##   finish        -> the overlay is freed (no overlay node is left after a finish)
##   toast         -> App.toast; the skip toast has an Undo button, and `expire_undo()` runs 4.5 s later
##   device        -> DeviceState.apply (settings.cfg, [tutorial])
##   reset_events  -> the bus buffer is cleared and the run's clock and fallback count restart
##   save          -> gs.set_tutorial(snapshot) and an autosave
## Every EventBus event is fed to the machine. Card buttons raise "tut:start", "tut:next", "tut:finish" (through the machine, as
## events); Skip is `skip()`. Nothing here decides a result (R6): it reads App.last_game / App.last_result only to choose the win or
## loss text of the report step, and the shortcut buttons call code that the screens register.
## The machine is bound to App.gs the first time an event arrives after the save object changed (`bind()`); I-14 calls
## `bind(true)` right after loading a save, which also raises the resume card flag.
## The welcome modal of a new save is shown by `show_welcome()` (I-14 decides when); steps run once the machine is `running`.

## A step (or its second stage) is about to be handed to the overlay. For tests and scripted runs (QA): a listener can prepare the
## screen before the overlay starts looking for the target.
signal presented(step_id: String, stage: String)

const UNDO_S := 4.5

## Home's offers (welcome modal, offer and resume cards; I-14). Screen tests that are not about the guide turn this off so no
## modal covers what they tap; it changes nothing in the save or on the device.
static var home_offers := true

var m: TutorialState
var overlay: CoachOverlay
var device: DeviceState = DeviceState.new()    # tests point it at a temp file
var autosave := true                            # tests turn it off (App.autosave writes the real save file)
var fallbacks := 0
var passed: Array = []
var shortcut_fallbacks := 0
var screen_id := ""
## Tests shorten the overlay's wait before the fallback card (CoachOverlay.WAIT_S / MISSING_S).
var wait_s := CoachOverlay.WAIT_S
var missing_s := CoachOverlay.MISSING_S
var _gs: GameState
var _t0_ms := -1
var _t_end_ms := -1
var _outcome_override := ""
var _variants: Dictionary = {}
var _shortcuts: Dictionary = {}
var _undo_serial := 0


func _ready() -> void:
	if is_instance_valid(App.bus):
		App.bus.raised.connect(_on_event)


func _exit_tree() -> void:
	if is_instance_valid(App.bus) and App.bus.raised.is_connected(_on_event):
		App.bus.raised.disconnect(_on_event)


# ---- binding to the save --------------------------------------------------------------------------------------------------

## Take the tutorial state of App.gs. `from_load` true applies the kill-resume rule and sets `resume_pending` (the resume card).
func bind(from_load: bool = false) -> void:
	_close_overlay()
	_gs = App.gs
	m = null
	fallbacks = 0
	passed.clear()
	_t0_ms = -1
	_t_end_ms = -1
	if _gs == null or not is_instance_valid(App.bus):
		return
	var bus: EventBus = App.bus
	m = TutorialState.from_save(_gs.tutorial(), bus.seen, bus.sequence) if from_load else TutorialState.new(_gs.tutorial(), bus.seen, bus.sequence)
	_carry(m.set_context(_context()))
	if from_load and m.is_running():
		_gs.set_tutorial(m.snapshot())    # the resumed step (live false, plan empty) is what the next autosave writes
	if m.is_running() and not m.resume_pending:
		_present()


func _sync() -> void:
	if App.gs != _gs or (m == null and App.gs != null):
		bind(false)


func _context() -> Dictionary:
	var none := true
	if _gs != null:
		none = _gs.next_game().is_empty()
	return {"no_next_game": none, "screen": screen_id}


# ---- events --------------------------------------------------------------------------------------------------------------

func _on_event(event_name: String, data: Dictionary) -> void:
	_sync()
	if m == null:
		return
	if event_name.begins_with("screen:"):
		screen_id = String(data.get("help_id", event_name.substr(7)))
		_carry(m.set_context(_context()))
	if m.resume_pending:
		return    # the resume card on Home is not answered yet: the guide waits, nothing the player does moves it
	_carry(m.feed(event_name, data))


## Carry out the effects the machine returned, in order.
func _carry(fx: Array) -> void:
	for e in fx:
		var d: Dictionary = e
		match String(d.get("fx", "")):
			"show", "stage":
				_present()
			"passed":
				passed.append(String(d.get("step", "")))
			"finish":
				_t_end_ms = Time.get_ticks_msec()
				_close_overlay()
			"toast":
				_toast(d)
			"device":
				device.apply(d)
			"reset_events":
				if is_instance_valid(App.bus):
					App.bus.clear()
				fallbacks = 0
				_t0_ms = Time.get_ticks_msec()
				_t_end_ms = -1
			"save":
				_save()


func _save() -> void:
	if _gs == null or m == null:
		return
	_gs.set_tutorial(m.snapshot())
	if autosave:
		App.autosave()


func _toast(d: Dictionary) -> void:
	var undo := bool(d.get("undo", false))
	App.toast(Strings.t(String(d.get("key", ""))), UI.TEXT, Strings.t("common.undo") if undo else "", Callable(self, "undo") if undo else Callable())
	if undo and is_inside_tree():
		_undo_serial += 1
		var serial := _undo_serial
		get_tree().create_timer(UNDO_S).timeout.connect(_on_undo_timeout.bind(serial))


func _on_undo_timeout(serial: int) -> void:
	if serial == _undo_serial:
		expire_undo()


# ---- showing a step --------------------------------------------------------------------------------------------------------

func _make_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		return
	overlay = CoachOverlay.new()
	overlay.theme = App.main.theme if App.main != null else null    # a CanvasLayer drops Main's theme
	overlay.wait_s = wait_s
	overlay.missing_s = missing_s
	App.main.overlay_layer.add_child(overlay)
	overlay.button_pressed.connect(_on_button)
	overlay.fell_back.connect(_on_fell_back)


func _close_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.clear()
		overlay.get_parent().remove_child(overlay)    # at once: nothing of it can be tapped, and "no overlay node left" is true now
		overlay.queue_free()
	overlay = null


func _present() -> void:
	if m == null or App.main == null or App.main.overlay_layer == null:
		return
	var c := m.card(_outcome(), String(_variants.get(m.step_id(), "")))
	if c.is_empty():
		_close_overlay()
		return
	_make_overlay()
	c["screen"] = String(m.step().get("screen", ""))
	c["screen_now"] = screen_id
	if _t0_ms < 0:
		_t0_ms = Time.get_ticks_msec()
	presented.emit(String(c.get("id", "")), String(c.get("stage", "a")))
	overlay.show_step(c, _text_for(c))


func _text_for(c: Dictionary) -> String:
	var key := String(c.get("key", ""))
	if String(c.get("id", "")) == "welcome" and _gs != null:
		return Strings.f(key, {"club": _gs.club_name(_gs.club())})
	return Strings.t(key)


## "win" or "loss" for the report step. Read from the finished game; never written.
func _outcome() -> String:
	if _outcome_override != "":
		return _outcome_override
	var g: Dictionary = App.last_game
	var r: Dictionary = App.last_result
	if _gs == null or g.is_empty() or r.is_empty():
		return "win"
	var winner := String(g.get("blue", "")) if bool(r.get("blue_won", false)) else String(g.get("red", ""))
	return "win" if winner == _gs.club() else "loss"


func set_outcome(o: String) -> void:
	_outcome_override = o


## A screen with an alternative text for a step says so (the five-avatar Squad: "alt"; the arena: "arena").
func set_variant(step_id: String, variant: String) -> void:
	_variants[step_id] = variant


func _on_fell_back(_step: String) -> void:
	fallbacks += 1


# ---- buttons -----------------------------------------------------------------------------------------------------------------

func _on_button(id: String) -> void:
	if m == null:
		return
	match id:
		"skip":
			_carry(m.skip())
		"next":
			if overlay != null and is_instance_valid(overlay) and bool(overlay.card_data().get("compact", false)) and BottomSheet.is_open():
				BottomSheet.current().close()    # Next on a sheet step (6 and 22) closes the sheet it was pointing into
			if overlay != null and is_instance_valid(overlay) and overlay.is_fallback():
				force_next()
			else:
				_carry(m.feed("tut:next"))
		"start":
			_carry(m.feed("tut:start"))
		"go_home":
			_carry(m.feed("tut:finish"))
			if m.state() == "done":
				App.go_tab("home")
		"shortcut":
			_run_shortcut()


## The step's own completing event, as if the player had done what it asks. Used by Next on a fallback card: a tutorial must never
## get stuck on a missing control. (It does not perform the action, so a later step may need its own fallback.)
func force_next() -> void:
	if m == null:
		return
	var st := m.step()
	var done: Array = st.get("done_on", [])
	if done.is_empty():
		return
	var ev := String(done[0])
	var filt = st.get("done_data", {})
	var data: Dictionary = (filt as Dictionary).get(ev, {}) if filt is Dictionary else {}
	_carry(m.feed(ev, data))


## A screen registers what a card's one-tap button does (`shortcut.does` in data/tutorial_v1.json: "draft_auto_finish",
## "gp_coach_apply"): the same code path as the real control, which then raises the completing event. Unregister on exit.
func register_shortcut(does: String, cb: Callable) -> void:
	_shortcuts[does] = cb


func unregister_shortcut(does: String, cb: Callable = Callable()) -> void:
	if _shortcuts.has(does) and (not cb.is_valid() or _shortcuts[does] == cb):
		_shortcuts.erase(does)


func _run_shortcut() -> void:
	var does := String(overlay.card_data().get("shortcut_does", "")) if overlay != null and is_instance_valid(overlay) else ""
	var cb: Callable = _shortcuts.get(does, Callable())
	if cb.is_valid():
		cb.call()
	else:
		shortcut_fallbacks += 1    # no screen answered: move on with the step's event so the player is not stuck
		force_next()


# ---- what the rest of the game calls ------------------------------------------------------------------------------------------

## The welcome modal of a save in state `new` (step 1 as a card with Start and Skip tutorial). I-14 calls it from Home.
func show_welcome() -> void:
	_sync()
	if m != null and m.state() == "new":
		_present()


## What Home shows for this save on this device (TUTORIAL 6.2): "welcome_modal", "returning_card", "legacy_card",
## "resume_card" or "none" (DeviceState.home_offer with this runner's machine, so a step taken this session counts).
func home_offer() -> String:
	_sync()
	if m == null or not home_offers:
		return "none"
	return device.home_offer(m.snapshot(), m.resume_pending)


## Home calls this once it is built. A brand-new save on a device that never answered the guide gets the welcome modal here;
## every other offer is an inline card that Home places itself (OfferCard). Returns the offer kind.
func on_home() -> String:
	var k := home_offer()
	if k == "welcome_modal":
		show_welcome()
	return k


## Show me / Replay: begin a run at step 1 (the welcome card).
func accept() -> void:
	_sync()
	if m != null:
		_carry(m.accept())


func replay() -> void:
	accept()


func decline() -> void:
	if m != null:
		_carry(m.decline())


func continue_resume() -> void:
	if m != null:
		_carry(m.continue_resume())


func skip() -> void:
	if m != null:
		_carry(m.skip())


## Undo on the skip toast (also what the toast button calls).
func undo() -> void:
	if m == null:
		return
	_undo_serial += 1
	_carry(m.undo_skip())


func expire_undo() -> void:
	if m != null:
		m.expire_undo()


## The tutorial game starts or is left (I-13). Allowed while running or after a skip.
func set_game_live(live: bool) -> void:
	if m != null:
		_carry(m.set_game_live(live))


func set_game_plan(plan: Dictionary) -> void:
	if m != null:
		_carry(m.set_game_plan(plan))


## Android back (Main asks this BEFORE BottomSheet.handle_back). True when the press was used. While a card is on screen: on any
## step with a Skip it is Skip tutorial with Undo (a sheet the player opened stays open); on the closing card, which has no Skip, it
## acts as Go to Home. While nothing is on screen (the target is still being found) the press goes on to the page as usual.
func handle_back() -> bool:
	if m == null or overlay == null or not is_instance_valid(overlay) or not overlay.is_showing():
		return false
	if m.can_skip():
		_carry(m.skip())
	else:
		_on_button("go_home")
	return true


## True while the guided game is running (a step is current, whether or not its card is on screen yet).
func is_running() -> bool:
	return m != null and m.is_running()


## True while the current step asks the Draft screen to hold the armed "Sure?" state of Auto-finish (TUTORIAL 3.2a rule 1,
## `hold_armed` in data/tutorial_v1.json): the 3 second revert is suspended until the player taps Sure? or the step ends.
func holds_armed() -> bool:
	return is_running() and bool(m.step().get("hold_armed", false))


## The line for App.debug_info(): "tutorial=<state> step_skipped=<id|none> total_s=<n> fallbacks=<n>". "" when no save is loaded.
func debug_line() -> String:
	if m == null:
		return ""
	var total := 0.0
	if _t0_ms >= 0:
		total = float((_t_end_ms if _t_end_ms >= 0 else Time.get_ticks_msec()) - _t0_ms) / 1000.0
	return m.debug_line(total, fallbacks)
