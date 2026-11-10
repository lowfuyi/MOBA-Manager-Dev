class_name CompKit
extends RefCounted
## Shared helpers of the components (build plan I-07). Every component follows the same rules:
##  - built once, updated in place: setters take a value, return at once when it equals the held value, and bump
##    `applied` when something really changed (tests read it);
##  - `tut_id` (optional) names the control for the tutorial (UI.tag);
##  - state-bearing components set the meta "cue" (what a colour-blind player sees besides colour; "" = no state to tell)
##    and the meta "state_bearing" = true, and answer state_name() ("" in the default state);
##  - recompute from `size`, never from 720.

const CUE := "cue"
const STATE_BEARING := "state_bearing"

static var _tracked: Dictionary = {}


static func set_cue(c: Object, cue_text: String) -> void:
	c.set_meta(CUE, cue_text)


static func cue_of(c: Object) -> String:
	return String(c.get_meta(CUE, ""))


static func mark_stateful(c: Object) -> void:
	c.set_meta(STATE_BEARING, true)
	if not c.has_meta(CUE):
		c.set_meta(CUE, "")


## Names a control for the tutorial. `tap_source` makes a BaseButton raise `tap:<id>` (UI.tag does it); other controls
## raise it through tap_event() when they are tapped.
static func tag(c: Control, id: String, tap_source: bool = false) -> void:
	if id != "":
		UI.tag(c, id, tap_source)


static func tap_event(id: String) -> void:
	if id != "" and is_instance_valid(App.bus):
		App.bus.emit("tap:" + id)


## SemiBold with letter spacing (a section label: +8 percent tracking, ART-BIBLE 5.2). One shared variation per
## (weight, spacing in px). Note for the font-pair gate: it is a FontVariation of the cached SemiBold, so it adds one
## variation that UI.font_cache_size() does not count (see the I-07 handback).
static func tracked_font(weight: String, spacing_px: float) -> Font:
	var key := "%s|%.2f" % [weight, spacing_px]
	if _tracked.has(key):
		return _tracked[key]
	var fv := FontVariation.new()
	fv.base_font = UI.font(weight)
	fv.spacing_glyph = int(round(spacing_px))
	_tracked[key] = fv
	return fv


static func text_width(font: Font, size: int, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## A StyleBox that draws nothing (the "panel" of a container that only lays out).
static func empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## Strip every state box of a Button (the Button only takes taps, the parent draws the look).
static func hollow(b: Button) -> void:
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
