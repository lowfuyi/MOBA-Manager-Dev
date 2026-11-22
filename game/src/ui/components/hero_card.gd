class_name HeroCard
extends RefCounted
## One hero card, as a STATIC DRAWING HELPER (no node): HeroCard.draw(ci, rect, hero, state, pass := -1). The HeroGrid draws
## all 40 cards with it, one pass at a time across every card (so each pass is one batch); the hero sheet preview and any
## single card draw all passes of one card with pass -1. One piece of code draws a hero everywhere (build plan I-09).
##
## Passes (ordered by texture and by draw command, not by card; the plan says three, this is the same idea counted the way the
## renderer batches: consecutive commands of one kind on one texture are one draw call, so nine-patches, plain quads, portrait
## quads, icon quads and each font size are runs of their own):
##   0 PASS_CARD     the card background (9-slice)                                                     (cards atlas)
##   1 PASS_OUTLINE  the selected / coach outline (9-slice) and the number pill (9-slice)              (cards atlas)
##   2 PASS_SHAPES   the side stripe and the corner badge, a disc or a hexagon (plain quads)           (cards atlas)
##   3 PASS_PORTRAIT the portrait of the hero                                                          (portrait atlas)
##   4 PASS_MARKS    star, patch arrow, tick in the badge, cross over a banned portrait                (icon atlas)
##   5 PASS_TEXT26   the name                                                                          (SemiBold 26)
##   6 PASS_TEXT24   the number, the patch delta, "Ban"                                                (SemiBold 24)
## `hero` is a heroes.json row (id, name, role_primary, archetype); prepare() makes the cheap form the grid keeps.
## `state` is a String (a state name) or a Dictionary: {s, rec, arrow, delta, num, pressed}.
##   s      "available" | "selected" | "banned" | "you" | "them"
##   rec    true = the coach's choice (a coral outline and a star)
##   arrow  "up" | "down" | "flat" | "": the patch arrow, with `delta` the text beside it ("+1.6")
##   num    the number chip at the bottom right (familiarity), "" = none
## State cues (never colour alone, ART-BIBLE 3.6 and 3.8): selected = accent outline + a tick in a disc; banned = grey portrait,
## a cross over it and the word "Banned" (card.banned); picked by you = a teal CIRCLE badge with a tick and a teal side stripe; picked by them = a
## coral HEXAGON badge with a tick and a coral stripe; recommended = a coral outline and a star. Banned and picked are not tappable.

const PASS_CARD := 0
const PASS_OUTLINE := 1
const PASS_SHAPES := 2
const PASS_PORTRAIT := 3
const PASS_MARKS := 4
const PASS_TEXT26 := 5
const PASS_TEXT24 := 6
const PASSES := 7

const H := 196.0
const PORTRAIT := 96.0
const STATES := ["available", "selected", "banned", "you", "them"]
## What a colour-blind player sees besides colour, per state ("" = the plain state).
const CUES := {"available": "", "selected": "ring+tick", "banned": "no-entry+word", "you": "circle+tick+stripe", "them": "hexagon+tick+stripe"}
const REC_CUE := "star+ring"


## The compact form a grid keeps per hero: id, name, roles and the silhouette info (variant, hue shift, mirror).
static func prepare(hero: Dictionary) -> Dictionary:
	if hero.has("sil"):
		return hero
	var role := str(hero.get("role_primary", hero.get("role", "mid")))
	var inf := Silhouette.info(str(hero["id"]), role, str(hero.get("archetype", "")))
	return {"id": str(hero["id"]), "name": str(hero.get("name", hero["id"])), "role": role,
		"role2": str(hero["role_secondary"]) if hero.get("role_secondary") != null else "", "arch": str(hero.get("archetype", "")), "sil": inf}


## A state name or a half-filled dictionary as the full dictionary draw() reads.
static func norm_state(state: Variant) -> Dictionary:
	var d := {"s": "available", "rec": false, "arrow": "", "delta": "", "num": "", "pressed": false}
	if state is String:
		d["s"] = state
	elif state is Dictionary:
		for k in (state as Dictionary):
			d[k] = state[k]
	if not STATES.has(String(d["s"])):
		d["s"] = "available"
	return d


static func state_of(state: Variant) -> String:
	if state is String:
		return state
	if state is Dictionary:
		return String((state as Dictionary).get("s", "available"))
	return "available"


## False for the states that cannot be tapped (banned, picked by you, picked by them).
static func tappable(state: Variant) -> bool:
	var s := state_of(state)
	return s == "available" or s == "selected"


## The cue of a state (see CUES), "" for the plain state. A recommended hero adds the star cue.
static func cue_of(state: Variant) -> String:
	var d := norm_state(state)
	var c := String(CUES.get(String(d["s"]), ""))
	if bool(d["rec"]):
		c = REC_CUE if c == "" else c + "+" + REC_CUE
	return c


static func _font26() -> Font:
	return UI.font("SemiBold")


## Draw one card into `rect` (rect.size.y is normally H). pass -1 = every pass in order (a single card).
static func draw(ci: CanvasItem, rect: Rect2, hero: Dictionary, state: Variant, pass_no: int = -1) -> void:
	var h := prepare(hero)
	var st := norm_state(state)
	if pass_no < 0:
		for p in PASSES:
			_pass(ci, rect, h, st, p)
	else:
		_pass(ci, rect, h, st, pass_no)


static func _pass(ci: CanvasItem, r: Rect2, h: Dictionary, st: Dictionary, p: int) -> void:
	var s := String(st["s"])
	match p:
		PASS_CARD:
			CardKit.bg(ci, "card", r, _bg_tint(st, s))
		PASS_OUTLINE:
			_outline(ci, r, st, s)
		PASS_SHAPES:
			_shapes(ci, r, s)
		PASS_PORTRAIT:
			var sil: Dictionary = h["sil"]
			CardKit.portrait(ci, Rect2(r.position + Vector2((r.size.x - PORTRAIT) * 0.5, 12.0), Vector2(PORTRAIT, PORTRAIT)), str(sil["role"]),
				int(sil["variant"]), float(sil["hue_shift"]), bool(sil["mirror"]), s == "banned")
		PASS_MARKS:
			_marks(ci, r, st, s)
		PASS_TEXT26:
			var col := UI.TEXT_OFF if s == "banned" else UI.TEXT
			CardKit.text(ci, _font26(), UI.S_SMALL, str(h["name"]), r.position.x + 8.0, r.position.y + 126.0, r.size.x - 16.0, col, 1)
		PASS_TEXT24:
			_text24(ci, r, st, s)


static func _bg_tint(st: Dictionary, s: String) -> Color:
	var c := UI.PANEL
	match s:
		"selected":
			c = UI.PANEL2
		"banned":
			c = UI.PANEL.darkened(0.38)
	if bool(st["pressed"]):
		c = c.darkened(0.10)
	return c


static func _badge_rect(r: Rect2) -> Rect2:
	return Rect2(r.end.x - 44.0, r.position.y + 8.0, 36.0, 36.0)


static func _pill_rect(r: Rect2, text_w: float) -> Rect2:
	var w := maxf(56.0, text_w + 28.0)
	return Rect2(r.end.x - 10.0 - w, r.position.y + 144.0, w, 44.0)


static func _outline(ci: CanvasItem, r: Rect2, st: Dictionary, s: String) -> void:
	if bool(st["rec"]):
		CardKit.bg(ci, "ring", r, UI.CORAL)
	if s == "selected":
		CardKit.bg(ci, "ring", r, UI.ACCENT)
	var num := String(st["num"])
	if num != "":
		CardKit.bg(ci, "pill", _pill_rect(r, CardKit.text_w(_font26(), UI.S_CAPTION, num)), UI.PANEL3 if s != "banned" else UI.PANEL2)


static func _shapes(ci: CanvasItem, r: Rect2, s: String) -> void:
	match s:
		"selected":
			CardKit.shape(ci, "disc", _badge_rect(r), UI.ACCENT)
		"you":
			CardKit.shape(ci, "solid", Rect2(r.position + Vector2(0, 22), Vector2(6, r.size.y - 44)), UI.ACCENT)
			CardKit.shape(ci, "disc", _badge_rect(r), UI.ACCENT)
		"them":
			CardKit.shape(ci, "solid", Rect2(r.position + Vector2(0, 22), Vector2(6, r.size.y - 44)), UI.CORAL)
			CardKit.shape(ci, "hex", _badge_rect(r), UI.CORAL)


static func _marks(ci: CanvasItem, r: Rect2, st: Dictionary, s: String) -> void:
	var b := _badge_rect(r)
	var tick := Rect2(b.get_center() - Vector2(12, 12), Vector2(24, 24))
	match s:
		"selected", "you":
			IconHook.draw(ci, "check", tick, UI.INK_TEAL)
		"them":
			IconHook.draw(ci, "check", tick, UI.INK_CORAL)
		"banned":
			var c := r.position + Vector2(r.size.x * 0.5, 12.0 + PORTRAIT * 0.5)
			IconHook.draw(ci, "ban", Rect2(c - Vector2(30, 30), Vector2(60, 60)), UI.BAN)
	if bool(st["rec"]):
		IconHook.draw(ci, "star", Rect2(r.position + Vector2(10, 10), Vector2(28, 28)), UI.CORAL)
	var arrow := String(st["arrow"]) if String(st["s"]) != "banned" else ""    # a banned hero shows the word "Banned" in that row
	if arrow != "":
		IconHook.draw(ci, "arrow_" + arrow, Rect2(r.position + Vector2(14, 148), Vector2(28, 36)), _arrow_colour(arrow))


static func _arrow_colour(arrow: String) -> Color:
	match arrow:
		"up":
			return UI.GOOD
		"down":
			return UI.BAD
	return UI.DIM


static func _text24(ci: CanvasItem, r: Rect2, st: Dictionary, s: String) -> void:
	var f := _font26()
	var num := String(st["num"])
	if num != "":
		var pr := _pill_rect(r, CardKit.text_w(f, UI.S_CAPTION, num))
		CardKit.text(ci, f, UI.S_CAPTION, num, pr.position.x, pr.get_center().y, pr.size.x, UI.TEXT if s != "banned" else UI.TEXT_OFF, 1)
	var delta := String(st["delta"])
	if delta != "" and String(st["arrow"]) != "" and s != "banned":
		CardKit.text(ci, f, UI.S_CAPTION, delta, r.position.x + 46.0, r.position.y + 166.0, 70.0, _arrow_colour(String(st["arrow"])), 0)
	if s == "banned":
		# the word sits in the bottom row on the left (where the patch arrow goes), clear of the portrait ring and the number chip
		var room := r.size.x - 28.0 - (_pill_rect(r, CardKit.text_w(f, UI.S_CAPTION, num)).size.x + 12.0 if num != "" else 0.0)
		CardKit.text(ci, f, UI.S_CAPTION, Strings.t("card.banned"), r.position.x + 16.0, r.position.y + 166.0, room, UI.TEXT2, 0)


## The width the name needs at 26 SemiBold (what a fit test compares with the card's text room).
static func name_width(hero: Dictionary) -> float:
	return CardKit.text_w(_font26(), UI.S_SMALL, str(hero.get("name", "")))


## The room a card of `card_w` gives the name.
static func name_room(card_w: float) -> float:
	return card_w - 16.0


## One hero portrait on its own (the lane tokens, the pick sheet preview, a Mini): the quads of the portrait atlas plus, at 56 px
## and below, the corner role chip of ART-BIBLE 6.2. 2 draw calls.
static func draw_portrait(ci: CanvasItem, rect: Rect2, hero: Dictionary, banned: bool = false) -> void:
	var h := prepare(hero)
	var sil: Dictionary = h["sil"]
	CardKit.portrait(ci, rect, str(sil["role"]), int(sil["variant"]), float(sil["hue_shift"]), bool(sil["mirror"]), banned)
	if rect.size.x <= 56.0:
		var d := clampf(rect.size.x * 0.46, 20.0, 26.0)
		CardKit.role_chip(ci, Rect2(rect.end - Vector2(d, d), Vector2(d, d)), str(sil["role"]))
