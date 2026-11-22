class_name DraftFormat
extends RefCounted
## Draft formats in one place (Founder decision 2026-11-22; data/draft_formats_v1.json): the step order for 1, 3 or 5 bans per
## side, the human timer, and how many bans each match type uses in each mode. The mode is the device setting [draft] bans
## ("standard" or "classic"), handed in by App at start and when Settings changes it (`mode`); pure code otherwise, so it
## runs without autoloads. A game dictionary carries its count as "bans" (GameState); older dictionaries only have the
## bool "full" (3 bans when true, else 1), which `bans_of` still reads.

const PATH := "res://data/draft_formats_v1.json"
const MODES := ["standard", "classic"]
const COUNTS := [1, 3, 5]

static var mode := "standard"
static var _d: Dictionary = {}


static func data() -> Dictionary:
	if _d.is_empty():
		var loaded = DataLoader.load_json(PATH)
		_d = loaded if loaded is Dictionary else {}
	return _d


## The step order ([team, kind] pairs) for `bans` per side; an unknown count falls back to 1.
static func order_for(bans: int) -> Array:
	var o: Dictionary = data().get("orders", {})
	return (o.get(str(bans), o.get("1", [])) as Array).duplicate(true)


## Seconds per human decision for `bans` per side.
static func timer_s(bans: int) -> float:
	return float((data().get("timer_s", {}) as Dictionary).get(str(bans), 10))


## The current mode, or "standard" when the setting holds something else.
static func current_mode() -> String:
	return mode if MODES.has(mode) else String(data().get("default_mode", "standard"))


## Bans per side for a match type ("league", "playoff_semi", "playoff_final", "quick", "exhibition") and game number of its
## series, in `m` (the current mode when empty).
static func bans_for(kind: String, game_no: int = 1, m: String = "") -> int:
	var mm := m if MODES.has(m) else current_mode()
	var e = (data().get("modes", {}) as Dictionary).get(mm, {}).get(kind, 1)
	if e is Dictionary:
		return int(e.get("game1", 1)) if game_no <= 1 else int(e.get("later", 1))
	return int(e)


## The bans per side of a draft argument: an int count, or the old bool (true = 3, false = 1).
static func bans_of(fmt: Variant) -> int:
	if fmt is bool:
		return 3 if fmt else 1
	var n := int(fmt)
	return n if COUNTS.has(n) else 1


## The bans per side of a game dictionary ("bans" when present, else the old "full").
static func of_game(g: Dictionary) -> int:
	if g.has("bans"):
		return bans_of(int(g["bans"]))
	return bans_of(bool(g.get("full", false)))
