extends Node
## Autoload "App": shared game objects and screen navigation.

const VERSION_LABEL := "0.5.0 alpha"
const SETTINGS_PATH := "user://settings.cfg"

var world: World
var gs: GameState
var main: Control          # set by Main: shows one screen at a time
var last_result: Dictionary = {}    # most recent managed-club game (for the report)
var last_game: Dictionary = {}
var last_payoff: Dictionary = {}   # what the last game changed (Payoff.compare), for the payoff screen


var pace_t0 := 0          # msec when the manager tapped Play on the home page (0 = not timing a game)


func _ready() -> void:
	world = World.load_default()
	UI.animate = bool(_read_setting("animate", true))


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
	if not last_game.is_empty():
		lines.append("last=" + str(last_game.get("id", "")))
	return "\n".join(lines)
