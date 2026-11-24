class_name HeroMatchups
extends RefCounted
## Hero matchup hint (0.12, ESMO Q4-8): reads game/data/hero_matchups_v1.json (written by tools/q2_analysis.py from
## simulated games; its "_doc" states the definition and the minimum sample). Display only: nothing in the simulation reads it.

const PATH := "res://data/hero_matchups_v1.json"

static var _doc: Dictionary = {}


static func doc() -> Dictionary:
	if _doc.is_empty() and FileAccess.file_exists(PATH):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if v is Dictionary:
			_doc = v
	return _doc


## Up to three {"vs", "win_pct", "delta_pts", "games"} rows for `hid`, worst first; [] when there is no clear counter.
static func struggles(hid: String) -> Array:
	var h: Dictionary = (doc().get("heroes", {}) as Dictionary).get(hid, {})
	return h.get("struggles_against", [])


static func min_games() -> int:
	return int(doc().get("min_pair_games", 0))
