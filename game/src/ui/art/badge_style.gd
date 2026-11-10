class_name BadgeStyle
extends RefCounted
## Club badge look from the club id: ART-BIBLE 6.3, deterministic, pure logic (no UI classes, no drawing), so it is
## unit-tested headless. `Badge` (badge.gd) draws what this returns.
##
## for_club(id) gives the badge of that id alone (hash only, no clash handling). Two clubs in one league must never share a
## hue or a shape plus pattern pair (ART-BIBLE 3.7 rule 6); that needs the whole league, processed in sorted id order:
## `resolve(ids)`, or `set_league(ids)` once and then `for_club(id)` returns the resolved style.

const HUES := [4, 24, 44, 76, 128, 160, 196, 216, 242, 270, 304, 338]
const SHAPES := ["shield", "roundel", "hexagon", "diamond", "banner", "arch"]
const PATTERNS := ["plain", "chief", "base", "chevron"]
const INK := Color("0b1220")        # the initial letter
const LUM_BASE := 0.24              # relative luminance window of the primary: 0.24 + 0.04 * lt

static var _league: Array = []
static var _league_styles: Dictionary = {}


## FNV-1a, 32 bit, over the UTF-8 bytes.
static func fnv1a(s: String) -> int:
	var h := 0x811C9DC5
	for b in s.to_utf8_buffer():
		h = ((h ^ int(b)) * 0x01000193) & 0xFFFFFFFF
	return h


## The numbers the hash gives, before any clash handling.
static func raw(club_id: String) -> Dictionary:
	var h := fnv1a(club_id)
	var q := h / 12
	var d := {"hash": h, "hue_idx": h % 12}
	d["shape"] = q % 6
	q /= 6
	d["pattern"] = q % 4
	q /= 4
	d["sec_mode"] = q % 2
	q /= 2
	d["lt"] = q % 4
	q /= 4
	d["sat"] = q % 3
	return d


## Styles for a whole league: id -> style. Clubs are processed in sorted id order.
static func resolve(ids: Array) -> Dictionary:
	var sorted: Array = ids.duplicate()
	sorted.sort()
	var used_hues := {}
	var used_pairs := {}
	var out := {}
	for id in sorted:
		var r := raw(str(id))
		var hue_idx: int = r["hue_idx"]
		var shape: int = r["shape"]
		var pattern: int = r["pattern"]
		if used_hues.size() < 12:
			while used_hues.has(hue_idx):
				hue_idx = (hue_idx + 5) % 12
		if used_pairs.size() < 24:
			while used_pairs.has(shape * 4 + pattern):
				shape = (shape + 1) % 6
				if shape == 0 and used_pairs.has(shape * 4 + pattern):
					pattern = (pattern + 1) % 4
		used_hues[hue_idx] = true
		used_pairs[shape * 4 + pattern] = true
		out[str(id)] = _build(str(id), r, hue_idx, shape, pattern)
	return out


static func _build(id: String, r: Dictionary, hue_idx: int, shape: int, pattern: int) -> Dictionary:
	var hue: int = HUES[hue_idx]
	var sat: float = 0.62 + 0.06 * float(r["sat"])
	var target: float = LUM_BASE + 0.04 * float(r["lt"])
	var lo := 0.15
	var hi := 0.85
	for i in 24:
		var mid := (lo + hi) * 0.5
		if luminance(hsl(hue, sat, mid)) < target:
			lo = mid
		else:
			hi = mid
	var primary := hsl(hue, sat, (lo + hi) * 0.5)
	var secondary := hsl(hue, 0.35, 0.90) if int(r["sec_mode"]) == 0 else hsl(hue, 0.55, 0.16)
	return {"id": id, "hash": r["hash"], "hue_idx": hue_idx, "hue": hue, "shape": shape, "shape_name": SHAPES[shape],
		"pattern": pattern, "pattern_name": PATTERNS[pattern], "sec_mode": r["sec_mode"], "lt": r["lt"], "sat": r["sat"],
		"primary": primary, "secondary": secondary, "ink": INK}


static func set_league(ids: Array) -> void:
	_league = ids.duplicate()
	_league.sort()
	_league_styles = resolve(_league)


static func league() -> Array:
	return _league


## The badge style of one club. With a league set (or passed) the clash rules apply; without, it is the plain hash result.
static func for_club(club_id: String, league_ids: Array = []) -> Dictionary:
	if not league_ids.is_empty():
		var ids: Array = league_ids.duplicate()
		if not ids.has(club_id):
			ids.append(club_id)
		return resolve(ids)[club_id]
	if _league_styles.has(club_id):
		return _league_styles[club_id]
	return resolve([club_id])[club_id]


# ---- colour helpers (CSS HSL, not Godot's HSV) ---------------------------------------------------------------------

## CSS hsl(): h in degrees, s and l in 0..1. Channels are rounded half up to 8 bits (ART-BIBLE: int(v * 255 + 0.5)).
static func hsl(h: float, s: float, l: float) -> Color:
	var c := (1.0 - absf(2.0 * l - 1.0)) * s
	var hp := fposmod(h, 360.0) / 60.0
	var x := c * (1.0 - absf(fmod(hp, 2.0) - 1.0))
	var rgb := Vector3.ZERO
	if hp < 1.0: rgb = Vector3(c, x, 0)
	elif hp < 2.0: rgb = Vector3(x, c, 0)
	elif hp < 3.0: rgb = Vector3(0, c, x)
	elif hp < 4.0: rgb = Vector3(0, x, c)
	elif hp < 5.0: rgb = Vector3(x, 0, c)
	else: rgb = Vector3(c, 0, x)
	var m := l - c * 0.5
	return Color(floorf((rgb.x + m) * 255.0 + 0.5) / 255.0, floorf((rgb.y + m) * 255.0 + 0.5) / 255.0, floorf((rgb.z + m) * 255.0 + 0.5) / 255.0)


## WCAG relative luminance.
static func luminance(c: Color) -> float:
	var ch: Array = []
	for v in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func hex(c: Color) -> String:
	return "#%02X%02X%02X" % [int(c.r * 255.0 + 0.5), int(c.g * 255.0 + 0.5), int(c.b * 255.0 + 0.5)]
