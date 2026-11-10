class_name Surface
extends RefCounted
## Card surfaces, decided by the S3 spike (build plan 9.5): keep `StyleBoxFlat` with the shared `UI.box()` cache. A baked
## 9-slice costs the same number of draw calls once text or icons sit on the cards, and wins only with a separate background
## layer. This file is therefore small: the four elevations of ART-BIBLE 4.1 as data, a way to get the box through the
## UI.box cache, and the 1.5 px top highlight as a line a card may draw on itself. `params()` is pure (headless-testable).
## Not done here: the vertical gradient (StyleBoxFlat has none); the cards stay flat colours plus edge, as UI.box gives.

const E0 := 0
const E1 := 1
const E2 := 2
const E3 := 3

## level -> fill, shadow (size is the blur, y the offset, alpha the black), edge (white alpha), highlight (white alpha)
const LEVELS := {
	0: {"name": "well", "fill": ArtPalette.VOID, "shadow": [0, 0, 0.0], "edge": 0.0, "highlight": 0.0},
	1: {"name": "card", "fill": ArtPalette.PANEL, "shadow": [10, 4, 0.38], "edge": 0.07, "highlight": 0.14},
	2: {"name": "raised", "fill": ArtPalette.PANEL2, "shadow": [18, 8, 0.45], "edge": 0.10, "highlight": 0.18},
	3: {"name": "overlay", "fill": ArtPalette.PANEL3, "shadow": [28, 14, 0.55], "edge": 0.16, "highlight": 0.20},
}
const RADIUS := {"card": 24, "button": 20, "small": 14}


static func params(level: int) -> Dictionary:
	return LEVELS[clampi(level, 0, 3)]


## The shared StyleBoxFlat for a level, through UI.box (never modify it). `shadow` false gives the flat variant used by rows
## inside a card (edge and no shadow). Loaded at call time so this file parses without the UI class.
static func box(level: int, radius: int = 24, shadow: bool = true) -> StyleBoxFlat:
	var p := params(level)
	var ui: GDScript = load("res://src/ui/ui.gd")
	var sh: Array = p["shadow"]
	var edge := Color(1, 1, 1, float(p["edge"]))
	if shadow and int(sh[0]) > 0:
		return ui.call("box", p["fill"], radius, 0, edge, 1, int(sh[0]), int(sh[1]), Color(0, 0, 0, float(sh[2])))
	return ui.call("box", p["fill"], radius, 0, edge, 1)


## The inner top highlight: a line 1.5 px thick along the top edge, inset 20 px from the corners (E1 rule), for a card's `_draw`.
static func draw_top_highlight(ci: CanvasItem, rect: Rect2, level: int, inset: float = 20.0) -> void:
	var a: float = float(params(level)["highlight"])
	if a <= 0.0:
		return
	ci.draw_line(rect.position + Vector2(inset, 1.0), Vector2(rect.end.x - inset, rect.position.y + 1.0), Color(1, 1, 1, a), 1.5)
