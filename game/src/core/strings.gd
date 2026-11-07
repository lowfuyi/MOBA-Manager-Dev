extends Node
## Translatable string table (autoload "Strings"). All player-facing text goes
## through t() or f(); nothing is hard-coded in scenes or scripts.
## Files: res://i18n/<lang>.json (flat key -> text). English is the fallback.
## STATUS: written but NOT YET RUN in Godot (see company/TASKBOARD.md, P-001).

const FALLBACK_LANG := "en"

var _lang := FALLBACK_LANG
var _table: Dictionary = {}
var _fallback: Dictionary = {}


func _ready() -> void:
	load_language(FALLBACK_LANG)


func load_language(lang: String, dir: String = "res://i18n") -> bool:
	_fallback = _read(dir.path_join(FALLBACK_LANG + ".json"))
	_lang = lang
	_table = _fallback if lang == FALLBACK_LANG else _read(dir.path_join(lang + ".json"))
	return not _fallback.is_empty()


func t(key: String) -> String:
	if _table.has(key):
		return String(_table[key])
	if _fallback.has(key):
		return String(_fallback[key])
	push_warning("Missing string key: " + key)
	return "[[" + key + "]]"


func f(key: String, args: Dictionary) -> String:
	var text := t(key)
	for k in args:
		text = text.replace("{" + String(k) + "}", str(args[k]))
	return text


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
