class_name Params
extends RefCounted
## Tunable draft and rating constants, shared with the Python reference
## (tools/comp.py and tools/pipeline.py read the same file): res://data/draft_params.json.

static var _d: Dictionary = {}


static func all() -> Dictionary:
	if _d.is_empty():
		var loaded = DataLoader.load_json("res://data/draft_params.json")
		_d = loaded if loaded is Dictionary else {}
	return _d


static func f(key: String) -> float:
	return float(all()[key])
