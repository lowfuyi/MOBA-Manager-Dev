extends Node
## Autoload "App": shared game objects and screen navigation.

const VERSION_LABEL := "0.1.0 alpha"

var world: World
var gs: GameState
var main: Control          # set by Main: shows one screen at a time
var last_result: Dictionary = {}    # most recent managed-club game (for the report)
var last_game: Dictionary = {}


func _ready() -> void:
	world = World.load_default()


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
	if not last_game.is_empty():
		lines.append("last=" + str(last_game.get("id", "")))
	return "\n".join(lines)
