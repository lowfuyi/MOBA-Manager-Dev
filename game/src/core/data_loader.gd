class_name DataLoader
extends RefCounted
## Loads game data from JSON and validates it with the same rules as
## tools/validate_data.py (the Python checker is what runs in CI here).
## STATUS: written but NOT YET RUN in Godot (see company/TASKBOARD.md, P-001).

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const STATS := ["mec", "sen", "lan", "tft", "mac", "com", "con", "clu"]
const PERSONALITIES := ["professional", "balanced", "casual", "temperamental"]


static func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


static func hero_errors(h: Dictionary) -> Array:
	var errs: Array = []
	var d := int(h.get("difficulty", 0))
	if d < 1 or d > 5:
		errs.append("difficulty must be 1 to 5")
	var total := 0
	for k in ["power_early", "power_mid", "power_late"]:
		var v := int(h.get(k, 0))
		total += v
		if v < 38 or v > 62:
			errs.append(k + " must be 38 to 62")
	if total != 144 + 3 * d:
		errs.append("power sum must be 144 + 3*difficulty")
	if not SLOTS.has(h.get("role_primary", "")):
		errs.append("bad role_primary")
	var tags: Array = h.get("tags", [])
	if tags.size() < 2 or tags.size() > 4:
		errs.append("tags must have 2 to 4 entries")
	if Array(h.get("strong_vs", [])).size() > 3:
		errs.append("strong_vs has at most 3 entries")
	return errs


static func player_errors(p: Dictionary) -> Array:
	var errs: Array = []
	var stats: Dictionary = p.get("stats", {})
	var pot: Dictionary = p.get("potential", {})
	for s in STATS:
		var v := int(stats.get(s, -1))
		var c := int(pot.get(s, -1))
		if v < 1 or v > 100:
			errs.append("stat out of range: " + s)
		if c < v or c > 99:
			errs.append("potential must be >= stat and <= 99: " + s)
	if not PERSONALITIES.has(p.get("personality", "")):
		errs.append("bad personality")
	return errs
