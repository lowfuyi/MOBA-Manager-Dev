extends Node
## Autoload "App": shared game objects and screen navigation.

const VERSION_LABEL := "0.6.0 alpha"
const LARGE_SCALE := 1.15
const SETTINGS_PATH := "user://settings.cfg"

var world: World
var gs: GameState
var main: Control          # set by Main: shows one screen at a time
var last_result: Dictionary = {}    # most recent managed-club game (for the report)
var last_game: Dictionary = {}
var last_payoff: Dictionary = {}   # what the last game changed (Payoff.compare), for the payoff screen


var pace_t0 := 0          # msec when the manager tapped Play on the home page (0 = not timing a game)


var startup_ms := 0       # msec from process start to the first screen (0 until Main has shown it)


func _ready() -> void:
	world = World.load_default()
	UI.animate = bool(_read_setting("animate", true))
	UI.set_colorblind(bool(_read_setting("colorblind", false)))
	apply_large_text(bool(_read_setting("large_text", false)))


## Called by Main once the first screen is up.
func mark_started() -> void:
	if startup_ms == 0:
		startup_ms = Time.get_ticks_msec()


func large_text() -> bool:
	return bool(_read_setting("large_text", false))


func apply_large_text(v: bool) -> void:
	var win := get_window()
	if win != null:
		win.content_scale_factor = LARGE_SCALE if v else 1.0


func _write_setting(section: String, key: String, v: Variant) -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value(section, key, v)
	cf.save(SETTINGS_PATH)


func set_large_text(v: bool) -> void:
	_write_setting("ui", "large_text", v)
	apply_large_text(v)


func set_colorblind(v: bool) -> void:
	_write_setting("ui", "colorblind", v)
	UI.set_colorblind(v)


## One-time hints for a new manager: remembered on this device, not in the save.
func tip_seen(key: String) -> bool:
	var cf := ConfigFile.new()
	return cf.load(SETTINGS_PATH) == OK and bool(cf.get_value("tips", key, false))


func tip_mark(key: String) -> void:
	_write_setting("tips", key, true)


func tips_reset() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK and cf.has_section("tips"):
		cf.erase_section("tips")
		cf.save(SETTINGS_PATH)


## What a tester pastes into a message: a short template plus the debug lines.
func feedback_text() -> String:
	return Strings.f("feedback.template", {"info": debug_info()})


func _read_setting(key: String, default: Variant) -> Variant:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return default
	return cf.get_value("ui", key, default)


func set_animate(v: bool) -> void:
	UI.animate = v
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("ui", "animate", v)
	cf.save(SETTINGS_PATH)


## Tab roots: where each bottom tab leads.
func go_tab(id: String) -> void:
	match id:
		"home":
			go(ScreenHub.new())
		"squad":
			go(ScreenRoster.new("hub"))
		"plan":
			go(ScreenPlan.new())
		"club":
			go(ScreenClub.new())
		_:
			go(ScreenSettings.new())


## A short message above the tab bar; `action` adds one button (for example Undo).
func toast(text: String, color: Color = UI.TEXT, action: String = "", cb: Callable = Callable()) -> void:
	if main != null:
		main.call("toast", text, color, action, cb)


func go(screen: Control) -> void:
	if main != null:
		main.call("show_screen", screen)


func autosave() -> void:
	if gs != null:
		gs.save()


func debug_info() -> String:
	var lines: Array = ["MOBA Esports " + VERSION_LABEL, "godot " + Engine.get_version_info()["string"]]
	if gs != null:
		lines.append("club=%s season=%s phase=%s round=%s seed=%s" % [gs.d["club"], gs.d["season"], gs.d["phase"], int(gs.d["round"]) + 1, gs.d["save_seed"]])
		var ng := gs.next_game()
		if not ng.is_empty():
			lines.append("next=" + str(ng.get("id", "")))
	if gs != null:
		var pc: Dictionary = gs.pace()
		lines.append("pace n=%d total_s=%.0f watch_s=%.0f skips=%d fast=%d quick=%d" % [pc["n"], pc["total_s"], pc["watch_s"], pc["skips"], pc["fast"], pc["quick"]])
	lines.append("startup=%d ms  mem=%.0f MB  text=%s  colours=%s" % [startup_ms, float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
			"large" if large_text() else "normal", "colour-blind" if UI.colorblind else "default"])
	if not last_game.is_empty():
		lines.append("last=" + str(last_game.get("id", "")))
	return "\n".join(lines)
