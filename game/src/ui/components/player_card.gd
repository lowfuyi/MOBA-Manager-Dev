class_name PlayerCard
extends Control
## The avatar card of a player (UI-PASS-2 5.6, ART-BIBLE 6.2 and 6.4, build plan I-09). ONE Control that draws itself in passes
## (backgrounds, avatar quads, icons, text by font size), so a card is a node and about eight draw calls however many chips it has.
## Variants (design px):
##   tall   330 x 264 grid cell (283 wide at 626 px of canvas): avatar 120 (104 when narrow), name 32 (26 when 32 does not fit),
##          role pill, age, the number with its caption, status chips (as many as fit, then "+n"), an 8 px role-colour bar on the left
##          (the name steps down 32, 26, 24 before it is ever cut)
##   row    672 x 112 (picker and report rows): avatar 80, name, role pill and chips, the number on the right
##   token  96 x 96 (the Squad lane map, ART-BIBLE 6.4): the avatar is the 96 px hit area; a 36 px rating disc at the upper right,
##          a status chip (down arrow = tired, up arrow = in form) at the lower right, the name outside the token, below it
##          (opts name_side "above" for Top and Bot, UI-PASS-2 11e), cut to opts label_clamp (a Rect2 in the token's own
##          coordinates, "stay 8 px inside the card"). No role glyph on the map: the lane is the role
##   mini   56 x 56 (the draft board): avatar with the corner role chip, display only
## States: normal, selected (3 px outline + a tick in a disc: a shape cue), starter (an accent "Playing now" chip), disabled
## (60 percent opacity, no tap), pressed (darker body). Role colour is the bar, the ring and the glyph, never text.
## A card is DISPLAY by default (mouse_filter IGNORE): put it in a Carousel (which owns the tap) or in a list the screen taps.
## `tappable` makes it take its own tap with the S1 rule (a release within 12 px of the press, in screen space; a drag that starts
## on it scrolls the page) and emit `pressed`; tap:<tut_id> goes on the bus. Built once, `set_*` change it in place
## (an equal value changes nothing: `applied` and `draw_count` do not move). The width comes from `size`, never from 720.
## Strings: only existing keys (role.short.*, fa.sort.age, gl.rating.name, squad.now_playing, fatigue.*, mood.*, contract.*).

signal pressed

const TALL := "tall"
const ROW := "row"
const TOKEN := "token"
const MINI := "mini"
const SIZES := {"tall": Vector2(330, 264), "row": Vector2(672, 112), "token": Vector2(96, 96), "mini": Vector2(56, 56)}
const TALL_MIN_W := 240.0
const CHIP_PAD := 16.0
const CHIP_ICON := 28.0
const CHIP_GAP := 8.0
const BAR_W := 8.0

var pid := ""
var variant := TALL
var opts: Dictionary = {}
var tut_id := ""
var applied := 0
var draw_count := 0
var tappable := false
var selected := false
var disabled := false
var clipped: Array = []           # texts cut with "..." in the last draw (tests)
var shown_chips: Array = []       # the chips drawn in the last draw (texts, with "+n" last when some did not fit)
var name_size := 0                # the font size the name was drawn at in the last draw
var _ops := CardKit.Ops.new()
var _tr := TouchTrack.new()
var _press_g := Vector2.ZERO
var _moved := false
var _down := false
var _pressed_look := false

const DEFAULTS := {"name": "", "role": "mid", "age": 0, "rating": "", "chips": [], "starter": false, "selected": false,
		"disabled": false, "off": false, "name_side": "below", "label_clamp": Rect2(), "status": "", "tut_id": ""}


## pid: the player id (it picks the avatar wash). opts: name, role ("top".."sup", the role shown), age, rating (number or text),
## chips (Array of {text, variant ("good","bad","warn","accent","neutral"), icon}), starter, selected, disabled, off (grey avatar),
## name_side (token), label_clamp (token), status ("up", "down" or "": token status chip), tut_id, tappable.
static func make(p_pid: String, p_variant: String = TALL, p_opts: Dictionary = {}) -> PlayerCard:
	return PlayerCard.new(p_pid, p_variant, p_opts)


func _init(p_pid: String = "", p_variant: String = TALL, p_opts: Dictionary = {}) -> void:
	pid = p_pid
	variant = p_variant if SIZES.has(p_variant) else TALL
	opts = DEFAULTS.duplicate()
	for k in p_opts:
		opts[k] = p_opts[k]
	tut_id = String(opts["tut_id"])
	tappable = bool(p_opts.get("tappable", false)) and variant != MINI
	selected = bool(opts["selected"])
	disabled = bool(opts["disabled"])
	mouse_filter = Control.MOUSE_FILTER_PASS if tappable else Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	if variant == TOKEN or variant == MINI:
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(TALL_MIN_W if variant == TALL else (96.0 if variant == ROW else SIZES[variant].x), SIZES[variant].y)
	modulate.a = 0.6 if disabled else 1.0
	CompKit.mark_stateful(self)
	CompKit.tag(self, tut_id)
	_note_cue()
	_note_access()
	resized.connect(queue_redraw)


func _enter_tree() -> void:
	ArtWire.ensure()


func _exit_tree() -> void:
	_tr.reset()


# ---- reading ------------------------------------------------------------------------------------------------------------------

func role() -> String:
	return String(opts["role"])


func player_name() -> String:
	return String(opts["name"])


func rating_text() -> String:
	var r: Variant = opts["rating"]
	if r is float:
		return str(int(roundf(r)))
	return str(r)


func state_name() -> String:
	if disabled:
		return "disabled"
	if selected:
		return "selected"
	return "starter" if bool(opts["starter"]) else ""


func cue_text() -> String:
	if disabled:
		return "faded"
	if selected:
		return "ring+tick"
	if bool(opts["starter"]):
		return "tag"
	return ""


func _note_cue() -> void:
	CompKit.set_cue(self, cue_text())


func _note_access() -> void:
	var parts: Array = [player_name(), Strings.t("role.short." + role())]
	if rating_text() != "":
		parts.append(rating_text())
	set_meta("accessible_name", ", ".join(PackedStringArray(parts)))


# ---- setters (in place; an equal value changes nothing) -----------------------------------------------------------------------

func set_opt(key: String, value: Variant) -> void:
	var cur: Variant = opts.get(key)
	if typeof(cur) == typeof(value) and cur == value:    # a value of another type (an int rating over the "" default) is a change
		return
	opts[key] = value
	applied += 1
	if key == "selected":
		selected = bool(value)
	elif key == "disabled":
		disabled = bool(value)
		modulate.a = 0.6 if disabled else 1.0
	_note_cue()
	_note_access()
	queue_redraw()


func set_name_text(v: String) -> void:
	set_opt("name", v)


func set_rating(v: Variant) -> void:
	set_opt("rating", v)


func set_chips(v: Array) -> void:
	set_opt("chips", v)


func set_selected(v: bool) -> void:
	set_opt("selected", v)


func set_starter(v: bool) -> void:
	set_opt("starter", v)


func set_disabled(v: bool) -> void:
	set_opt("disabled", v)


# ---- text helpers --------------------------------------------------------------------------------------------------------------

static func _sb() -> Font:
	return UI.font("SemiBold")


static func chip_colour(variant_name: String) -> Color:
	match variant_name:
		"good":
			return UI.GOOD
		"bad":
			return UI.BAD
		"warn":
			return UI.WARN
		"accent":
			return UI.ACCENT
	return UI.DIM


static func chip_icon(c: Dictionary) -> String:
	var ic := String(c.get("icon", ""))
	if ic != "":
		return ic
	return String(Chip.ICONS.get(String(c.get("variant", "neutral")), "dot"))


static func chip_width(c: Dictionary) -> float:
	var ic := chip_icon(c) if String(c.get("icon", "")) != "none" else ""
	return CHIP_PAD * 2.0 + CardKit.text_w(_sb(), UI.S_CAPTION, String(c["text"])) + (CHIP_ICON + CHIP_GAP if ic != "" else 0.0)


## The chips that fit `room` px in order, then a "+n" chip for the rest (n counted in; the "+n" chip's own width is kept free).
func fit_chips(room: float) -> Array:
	var all: Array = []
	if bool(opts["starter"]):
		all.append({"text": Strings.t("squad.now_playing"), "variant": "accent", "icon": "star"})
	for c in opts["chips"]:
		all.append(c)
	var out: Array = []
	var used := 0.0
	for i in all.size():
		var left := all.size() - i - 1
		var w := chip_width(all[i])
		var reserve := 0.0 if left == 0 else chip_width({"text": "+%d" % left, "icon": "none"}) + CHIP_GAP
		if used + w + reserve <= room + 0.5:
			out.append(all[i])
			used += w + CHIP_GAP
		else:
			var more := all.size() - out.size()
			var plus := {"text": "+%d" % more, "variant": "neutral", "icon": "none"}
			if used + chip_width(plus) > room + 0.5 and not out.is_empty():
				out.pop_back()
				more += 1
				plus = {"text": "+%d" % more, "variant": "neutral", "icon": "none"}
			out.append(plus)
			break
	return out


func _chip_ops(c: Dictionary, x: float, cy: float) -> float:
	var col := chip_colour(String(c.get("variant", "neutral")))
	var w := chip_width(c)
	var r := Rect2(x, cy - CardKit.PILL_H * 0.5, w, CardKit.PILL_H)
	_ops.bg("pill", r, Color(col.r, col.g, col.b, 0.16))
	_ops.bg("pillring", r, Color(col.r, col.g, col.b, 0.45))
	var tx := x + CHIP_PAD
	var ic := chip_icon(c) if String(c.get("icon", "")) != "none" else ""
	if ic != "":
		_ops.icon(ic, Rect2(tx, cy - CHIP_ICON * 0.5, CHIP_ICON, CHIP_ICON), col)
		tx += CHIP_ICON + CHIP_GAP
	_ops.text(_sb(), UI.S_CAPTION, String(c["text"]), tx, cy, w - (tx - x) - CHIP_PAD + 0.5, col, 0)
	return w


func _role_pill(x: float, cy: float) -> float:
	var word := Strings.t("role.short." + role())
	var w := 12.0 + CHIP_ICON + 6.0 + CardKit.text_w(_sb(), UI.S_CAPTION, word) + 12.0
	var r := Rect2(x, cy - CardKit.PILL_H * 0.5, w, CardKit.PILL_H)
	_ops.bg("pill", r, UI.PANEL3)
	_ops.icon(Icons.role_id(role()), Rect2(x + 12.0, cy - CHIP_ICON * 0.5, CHIP_ICON, CHIP_ICON), ArtPalette.role_color(role()))
	_ops.text(_sb(), UI.S_CAPTION, word, x + 12.0 + CHIP_ICON + 6.0, cy, w - 12.0 - CHIP_ICON - 6.0 - 12.0 + 0.5, UI.TEXT, 0)
	return w


func _age_text() -> String:
	return "%s %d" % [Strings.t("fa.sort.age"), int(opts["age"])] if int(opts["age"]) > 0 else ""


## The size the name is drawn at: Body 32, else Small 26, else Caption 24 (the floor) when the room is short; only after that is
## it cut with "...". The longest name in the data is 8 letters (fits at 32); the fixtures use 11.
func _name_size_for(room: float) -> int:
	for sz in [UI.S_BODY, UI.S_SMALL]:
		if CardKit.text_w(_sb(), sz, player_name()) <= room + 0.5:
			return sz
	return UI.S_CAPTION


# ---- layout -> ops -------------------------------------------------------------------------------------------------------------

func _layout() -> void:
	_ops.clear()
	shown_chips = []
	var s := size if size.x > 0.0 and size.y > 0.0 else Vector2(custom_minimum_size.x, SIZES[variant].y)
	match variant:
		TALL:
			_layout_tall(s)
		ROW:
			_layout_row(s)
		TOKEN:
			_layout_token(s)
		MINI:
			_layout_mini(s)


func _bg_card(s: Vector2) -> void:
	var tint := UI.PANEL2 if selected else UI.PANEL
	if _pressed_look:
		tint = tint.darkened(0.10)
	_ops.bg("card", Rect2(Vector2.ZERO, s), tint)
	if selected:
		_ops.bg("ring", Rect2(Vector2.ZERO, s), UI.ACCENT)
		_ops.shape("disc", Rect2(s.x - 44.0, 8.0, 36.0, 36.0), UI.ACCENT)
		_ops.icon("check", Rect2(s.x - 38.0, 14.0, 24.0, 24.0), UI.INK_TEAL)
	_ops.shape("solid", Rect2(0.0, 24.0, BAR_W, s.y - 48.0), ArtPalette.role_color(role()))


func _avatar(rect: Rect2, letter_size: int, letter_weight: String, corner: bool) -> void:
	_ops.portraits.append(["avatar", rect, pid, role(), bool(opts["off"])])
	if corner:
		var d := clampf(rect.size.x * 0.34, 20.0, 30.0)
		_ops.portraits.append(["chip", Rect2(rect.end - Vector2(d + rect.size.x * 0.04, d + rect.size.x * 0.04), Vector2(d, d)), role()])
	var letter := Avatar.initial_of(player_name(), pid)
	_ops.text(UI.font(letter_weight), letter_size, letter, rect.position.x, rect.get_center().y, rect.size.x, UI.TEXT, 1)


func _layout_tall(s: Vector2) -> void:
	_bg_card(s)
	var av := 120.0 if s.x >= 320.0 else 104.0
	_avatar(Rect2(20.0, 16.0, av, av), UI.S_DISPLAY if av >= 120.0 else UI.S_BIG, "ExtraBold" if av >= 120.0 else "SemiBold", true)
	var cx := 20.0 + av + 10.0
	var room := s.x - 12.0 - cx
	var name_room := room - (40.0 if selected else 0.0)
	name_size = _name_size_for(name_room)
	_ops.text(_sb(), name_size, player_name(), cx, 34.0, name_room, UI.TEXT, 0)
	_role_pill(cx, 80.0)
	if _age_text() != "":
		_ops.text(_sb(), UI.S_CAPTION, _age_text(), cx, 122.0, room, UI.TEXT2, 0)
	var rating := rating_text()
	if rating != "":
		var f40 := UI.font("SemiBold")
		var rw := CardKit.text_w(f40, UI.S_BIG, rating)
		_ops.text(f40, UI.S_BIG, rating, 20.0, 168.0, rw + 2.0, UI.TEXT, 0)
		_ops.text(_sb(), UI.S_CAPTION, Strings.t("gl.rating.name"), 20.0 + rw + 8.0, 170.0, s.x - 20.0 - rw - 8.0 - 12.0, UI.TEXT2, 0)
	shown_chips = fit_chips(s.x - 32.0)
	var x := 16.0
	for c in shown_chips:
		x += _chip_ops(c, x, 220.0) + CHIP_GAP


func _layout_row(s: Vector2) -> void:
	_bg_card(s)
	_avatar(Rect2(20.0, 16.0, 80.0, 80.0), UI.S_BIG, "SemiBold", false)
	var cx := 112.0
	var rating := rating_text()
	var num_w := 0.0
	if rating != "":
		var f40 := UI.font("SemiBold")
		num_w = maxf(CardKit.text_w(f40, UI.S_BIG, rating), CardKit.text_w(_sb(), UI.S_CAPTION, Strings.t("gl.rating.name")))
		_ops.text(f40, UI.S_BIG, rating, s.x - 16.0 - num_w, 62.0, num_w, UI.TEXT, 2)
		_ops.text(_sb(), UI.S_CAPTION, Strings.t("gl.rating.name"), s.x - 16.0 - num_w, 92.0, num_w, UI.TEXT2, 2)
	var right := s.x - 16.0 - (num_w + 16.0 if rating != "" else 0.0)
	var name_room := right - cx - (40.0 if selected else 0.0)
	name_size = _name_size_for(name_room)
	_ops.text(_sb(), name_size, player_name(), cx, 32.0, name_room, UI.TEXT, 0)
	var x := cx
	x += _role_pill(x, 80.0) + CHIP_GAP
	shown_chips = fit_chips(maxf(0.0, right - x))
	for c in shown_chips:
		x += _chip_ops(c, x, 80.0) + CHIP_GAP


func _layout_mini(s: Vector2) -> void:
	_ops.portraits.append(["avatar", Rect2(Vector2.ZERO, s), pid, role(), bool(opts["off"])])
	_ops.portraits.append(["chip", Rect2(s - Vector2(26, 26), Vector2(26, 26)), role()])
	_ops.text(UI.font("SemiBold"), UI.S_BODY, Avatar.initial_of(player_name(), pid), 0.0, s.y * 0.5, s.x, UI.TEXT, 1)


func _layout_token(s: Vector2) -> void:
	_ops.portraits.append(["avatar", Rect2(Vector2.ZERO, s), pid, role(), bool(opts["off"])])
	_ops.text(UI.font("SemiBold"), UI.S_BIG, Avatar.initial_of(player_name(), pid), 0.0, s.y * 0.5, s.x, UI.TEXT, 1)
	if selected:
		_ops.bg("ring", Rect2(-6.0, -6.0, s.x + 12.0, s.y + 12.0), UI.ACCENT)
	var rating := rating_text()
	if rating != "":
		_ops.shape("disc", Rect2(s.x - 40.0, -2.0, 36.0, 36.0), UI.PANEL3)
		_ops.text(UI.font("Bold"), UI.S_CAPTION, rating, s.x - 40.0, 16.0, 36.0, UI.TEXT, 1)
	var st := String(opts["status"])
	if st != "":
		var col := UI.WARN if st == "down" else UI.GOOD
		_ops.shape("disc", Rect2(s.x - 34.0, s.y - 34.0, 32.0, 32.0), col)
		_ops.shape("disc", Rect2(s.x - 32.0, s.y - 32.0, 28.0, 28.0), UI.VOID)
		_ops.icon("arrow_" + st, Rect2(s.x - 28.0, s.y - 28.0, 20.0, 20.0), col)
	# the name outside the token
	var f := UI.font("Medium")
	var nm := player_name()
	if nm != "":
		var cy := s.y * 0.5 + (76.0 if String(opts["name_side"]) != "above" else -69.0)
		var room := 200.0
		var x0 := s.x * 0.5 - room * 0.5
		var clamp_r: Rect2 = opts["label_clamp"]
		var w := minf(CardKit.text_w(f, UI.S_SMALL, nm) + 4.0, room)
		var lx := s.x * 0.5 - w * 0.5
		if clamp_r.size.x > 0.0:
			lx = clampf(lx, clamp_r.position.x, maxf(clamp_r.position.x, clamp_r.end.x - w))
			w = minf(w, clamp_r.size.x)
		else:
			lx = maxf(lx, x0)
		_ops.text(f, UI.S_SMALL, nm, lx, cy, w, UI.TEXT, 1, UI.VOID)


# ---- drawing -----------------------------------------------------------------------------------------------------------------------

func _draw() -> void:
	if batched():
		get_parent().queue_redraw()    # the parent draws its cards in one pass (I-19 perf); this card's own canvas item stays empty
		return
	draw_count += 1
	_layout()
	_ops.flush(self)
	clipped = _ops.clipped.duplicate()


## True when the parent draws this card (a parent with `draws_cards()`, I-19: the Squad map, bench and picker rows), so ten cards
## cost a few draw calls in all instead of about eight each, the way LaneBoard draws its LaneRows (I-16).
func batched() -> bool:
	var p := get_parent()
	return p != null and p.has_method("draws_cards")


## The parent's half of the batched draw: lay this card out and hand over its display list (in this card's coordinates).
func queue_for_batch() -> CardKit.Ops:
	draw_count += 1
	_layout()
	return _ops


## Draw every visible PlayerCard child of `ci` in one display list (call from the parent's _draw, after its own background).
## `under` (optional) is the parent's own display list, drawn in the same passes, under the cards.
static func draw_children(ci: Control, under: CardKit.Ops = null, reorder: bool = false) -> void:
	var ops := under if under != null else CardKit.Ops.new()
	var spans: Array = []
	for c in ci.get_children():
		var pc := c as PlayerCard
		if pc == null or not pc.visible:
			continue
		var t0 := ops.texts.size()
		var cop := pc.queue_for_batch()
		if pc.modulate.a < 0.99 or pc._pressed_look:
			cop = _tinted(cop, pc.modulate.a, pc._pressed_look)
		ops.append_shifted(cop, pc.position)
		spans.append([pc, t0, ops.texts.size()])
	if reorder:
		PlanKit.batch_order(ops)    # every 9-slice first, then the quads: fewer texture switches (safe for cards side by side)
	ops.flush(ci)
	for sp in spans:
		var cut: Array = []
		for k in range(int(sp[1]), int(sp[2])):
			if ops.clipped.has(String((ops.texts[k] as Array)[2])):
				cut.append(String((ops.texts[k] as Array)[2]))
		(sp[0] as PlayerCard).clipped = cut


## A copy of a card's display list with its alpha applied (a disabled card is drawn at 60 percent) and darker when pressed.
static func _tinted(src: CardKit.Ops, a: float, pressed_look: bool) -> CardKit.Ops:
	var o := CardKit.Ops.new()
	var k := 0.85 if pressed_look else 1.0
	for b in src.bgs:
		var c: Color = b[2]
		o.bgs.append([b[0], b[1], Color(c.r * k, c.g * k, c.b * k, c.a * a), b[3]])
	o.portraits = src.portraits.duplicate(true)
	for ic in src.icons:
		var c2: Color = ic[2]
		o.icons.append([ic[0], ic[1], Color(c2.r, c2.g, c2.b, c2.a * a)])
	for t in src.texts:
		var u: Array = (t as Array).duplicate()
		var c3: Color = u[6]
		u[6] = Color(c3.r, c3.g, c3.b, c3.a * a)
		o.texts.append(u)
	return o


# ---- touch (only when tappable) -----------------------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not tappable or disabled:
		return
	match _tr.feed(event):
		"down":
			_press_g = get_global_transform_with_canvas() * _tr.press_pos
			_moved = false
			_down = true
			_set_look(true)
		"move":
			if not _moved and (get_global_transform_with_canvas() * _tr.pos).distance_to(_press_g) > TouchTrack.SLOP:
				_moved = true
				_set_look(false)
		"up":
			var tap := _down and not _moved and (get_global_transform_with_canvas() * _tr.pos).distance_to(_press_g) <= TouchTrack.SLOP
			_down = false
			_set_look(false)
			if tap:
				CompKit.tap_event(tut_id)
				pressed.emit()


func _set_look(v: bool) -> void:
	if v == _pressed_look:
		return
	_pressed_look = v
	queue_redraw()
	if batched():
		get_parent().queue_redraw()


# ---- from the game --------------------------------------------------------------------------------------------------------------------

## The opts of a card from the game state, read only: name, the role it is shown in (`slot`, or the player's own role), age,
## the rating in that role, and the status chips in the priority of UI-PASS-2 5.3: tired or exhausted, contract ends, out of
## form, in form, unhappy, happy. `gs` may be null (a data-only look); contract chips then are left out.
static func data_for(world: World, gs: GameState, p_pid: String, slot: String = "") -> Dictionary:
	var p: Dictionary = world.players[p_pid]
	var r := slot if slot != "" else str(p["role_primary"])
	var chips: Array = []
	var fat := world.fatigue_of(p_pid)
	if fat >= 75.0:
		chips.append({"text": Strings.t("fatigue.exhausted"), "variant": "bad", "icon": "fatigue"})
	elif fat >= 50.0:
		chips.append({"text": Strings.t("fatigue.tired"), "variant": "warn", "icon": "fatigue"})
	if gs != null:
		var left := gs.seasons_left(p_pid)
		if gs.contract_of(p_pid).size() > 0 and left <= 1:
			chips.append({"text": Strings.t("contract.final" if left == 1 else "contract.expires"), "variant": "warn", "icon": "contract"})
	var frm := world.form_of(p_pid)
	var mor := world.morale_of(p_pid)
	if frm <= -3.0:
		chips.append({"text": Strings.t("mood.cold"), "variant": "bad", "icon": "form"})
	elif frm >= 3.0:
		chips.append({"text": Strings.t("mood.hot"), "variant": "good", "icon": "form"})
	if mor < 40.0:
		chips.append({"text": Strings.t("mood.unhappy"), "variant": "bad", "icon": "morale"})
	elif mor >= 75.0:
		chips.append({"text": Strings.t("mood.happy"), "variant": "good", "icon": "morale"})
	var status := ""
	if fat >= 50.0:
		status = "down"
	elif frm >= 3.0:
		status = "up"
	return {"name": str(p["name"]), "role": r, "age": world.age_of(p), "rating": int(roundf(world.slot_score(p, r))), "chips": chips, "status": status}
