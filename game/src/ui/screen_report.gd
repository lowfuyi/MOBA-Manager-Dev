class_name ScreenReport
extends Screen
## Match report (GDD 8.5, UI-PASS-2 6.6, build plan I-18). The payoff after a game, one page that scrolls above a sticky Continue:
##   result   (tag report.result) the result word with a shape (a trophy for a win, a cross for a loss), both badges, the SCORE
##            LINE (team kills, Report.team_kills: display data the simulation keeps consistent; it counts up), the clubs, the
##            margin word and the game length, the series line in the playoffs
##   story    "How the game went": one story tag from the signs of the three phases (report.story.<p|m x3>), then the vertical
##            PhaseStrip (Early, Mid, Late with a tick or a cross) beside a band of contest chips per phase (tick or cross, one to
##            three dots for narrow, clear, decisive). Everything comes from res["sim"] through Report.feed: no new claims.
##            A tap on a phase opens its moments (sheet report_phase)
##   why      (tag report.why) the biggest factor of Report.attribution as one big number and one sentence (luck said plainly),
##            best and worst chips; a tap opens the factor bars (sheet report_why; the bars carry tag report.why_sheet)
##   changed  (tag report.payoff) the five starters with form and morale changes, then bonds, chemistry and cash; for a practice
##            game the practice card instead, for the tutorial game the tutorial card (tut.report_card.*)
##   tip      (tag report.tip) "Before the next game", with Open squad for the tired-players and contracts tips
##   more     "More detail": Players (kills, deaths, assists), Moments, Draft, one at a time
##   footer   Continue (tag report.continue), the one coral action, always on screen
## The old Report tip (Tips.show "report") is retired here (build plan v1.1); `tip.report*` stay in en.json until I-24.
## Nothing here changes a result (R7): the screen only reads `res`, `App.last_payoff` and the save.

var game: Dictionary
var res: Dictionary
var my_side := "B"
var opp_id := ""
var won := false
var att: Dictionary = {}
var build_count := 0
var _quick := false
var _dig := "players"

var result: _Result
var story_label: Label
var strip: PhaseStrip
var bands: _Bands
var stat_tile: PanelContainer
var stat: HeroStat
var why_bars: _Bars                   # the bars in the open Why sheet (null when none)
var changes: _Changes
var practice_card: DepthCard
var tip_card: DepthCard
var tip_button: Button
var dig_button: Button
var dig_bar: DraftKit.RoleBar
var dig_box: VBoxContainer
var continue_button: Button
var page_scroll: ScrollContainer


# ---- drawn pieces ---------------------------------------------------------------------------------------------------------------

## The result block: word and shape, badges, score line, clubs, margin and length (and the series in the playoffs). One Control.
class _Result extends Control:
	var won := false
	var kills: Array = [0, 0]          # [you, them]
	var me := ""
	var opp := ""
	var names := ""
	var line := ""
	var series := ""
	var shown := 1.0                   # the score's count-up (0 to 1)
	var draw_count := 0
	var _ops := CardKit.Ops.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resized.connect(_relayout)
		CompKit.mark_stateful(self)

	func setup(p_won: bool, p_kills: Array, p_me: String, p_opp: String, p_names: String, p_line: String, p_series: String) -> void:
		won = p_won
		kills = p_kills
		me = p_me
		opp = p_opp
		names = p_names
		line = p_line
		series = p_series
		CompKit.set_cue(self, "trophy+word" if won else "cross+word")
		_relayout()

	## The two club names on one line when they fit, else one name per line ("vs" starts the second).
	func name_lines() -> Array:
		var w := size.x if size.x > 0.0 else UI.canvas_w() - 48.0
		if CardKit.text_w(UI.font("SemiBold"), UI.S_BODY, names) <= w - 48.0:
			return [names]
		var i := names.find("  vs  ")
		return [names] if i < 0 else [names.substr(0, i), "vs  " + names.substr(i + 6)]

	func _relayout() -> void:
		var h := 300.0 + (40.0 if series != "" else 0.0) + 40.0 * float(name_lines().size() - 1)
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size = Vector2(0, h)
		queue_redraw()

	func count_up() -> void:
		if not UI.animate or not is_inside_tree():
			shown = 1.0
			queue_redraw()
			return
		shown = 0.0
		var tw := create_tween()
		tw.tween_method(func(x: float) -> void:
			shown = x
			queue_redraw(), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func score_text() -> String:
		return "%d - %d" % [int(round(float(kills[0]) * shown)), int(round(float(kills[1]) * shown))]

	func badge_rects() -> Array:
		var b := 96.0 if size.x > 560.0 else 80.0
		return [Rect2(24.0, 112.0, b, b), Rect2(size.x - 24.0 - b, 112.0, b, b)]

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var w := size.x
		var col := UI.GOOD if won else UI.BAD
		_ops.bg("card", Rect2(Vector2.ZERO, size), UI.PANEL2)
		_ops.bg("ring", Rect2(Vector2.ZERO, size), Color(col.r, col.g, col.b, 0.6))
		var bold := UI.font("Bold")
		var word := Strings.t("report.victory" if won else "report.defeat")
		var ww := CardKit.text_w(bold, UI.S_DISPLAY, word)
		var x0 := (w - ww - 56.0) * 0.5
		_ops.icon("trophy" if won else "cross", Rect2(x0, 34.0, 48.0, 48.0), col)
		_ops.text(bold, UI.S_DISPLAY, word, x0 + 56.0, 58.0, ww + 2.0, col)
		var br := badge_rects()
		var mid_room := (br[1] as Rect2).position.x - (br[0] as Rect2).end.x - 16.0
		_ops.text(UI.font("Bold", true), UI.S_DISPLAY, score_text(), (br[0] as Rect2).end.x + 8.0, 160.0, mid_room, UI.TEXT, 1)
		var nl := name_lines()
		for k in nl.size():
			_ops.text(UI.font("SemiBold"), UI.S_BODY, String(nl[k]), 24.0, 238.0 + 40.0 * float(k), w - 48.0, UI.TEXT, 1)
		var dy := 40.0 * float(nl.size() - 1)
		_ops.text(UI.font(), UI.S_SMALL, line, 24.0, 274.0 + dy, w - 48.0, UI.DIM, 1)
		if series != "":
			_ops.text(UI.font("SemiBold"), UI.S_SMALL, series, 24.0, 312.0 + dy, w - 48.0, UI.TEAL_HI, 1)
		_ops.flush(self)
		Badge.draw_shapes(self, me, br[0])
		Badge.draw_shapes(self, opp, br[1])
		var b := UI.font("Bold")
		Badge.draw_letter(self, me, App.gs.club_name(me) if App.gs != null else "", br[0], b)
		Badge.draw_letter(self, opp, App.gs.club_name(opp) if App.gs != null else "", br[1], b)

	func clipped() -> Array:
		return _ops.clipped


## The contest chips beside the story strip: one row of 112 px per phase (Early 4 chips, Mid 2, Late 2; in large text the four
## Early chips wrap to 2 x 2). A chip = a tick or a cross, the contest's name and one to three dots (narrow, clear, decisive).
## A tap on a row calls `on_row(phase id)` (rule S1: a release within 12 px of the press).
class _Bands extends Control:
	const ROW_H := 112.0
	const CHIP_H := 48.0
	var rows: Array = []               # [[phase id, [{key, mine, size}...]], ...]
	var on_row: Callable
	var draw_count := 0
	var _ops := CardKit.Ops.new()
	var _tr := TouchTrack.new()
	var _press_g := Vector2.ZERO
	var _press_row := -1

	func _init(p_rows: Array, p_on_row: Callable) -> void:
		rows = p_rows
		on_row = p_on_row
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, ROW_H * float(rows.size()))
		mouse_filter = Control.MOUSE_FILTER_PASS
		resized.connect(queue_redraw)
		CompKit.set_cue(self, "tick/cross+dots")

	static func chip_name(key: String) -> String:
		match key:
			"top", "bot", "jungle":
				return Strings.t("gp.contest." + key)
			"mid_lane":
				return Strings.t("feed.t.mid_lane")
			"obj_mid", "obj_late":
				return Strings.t("gp.contest.obj")
		return Strings.t("gp.contest.fight")

	static func dots(size_word: String) -> int:
		return {"narrow": 1, "clear": 2, "decisive": 3}.get(size_word, 1)

	func chip_rects(i: int) -> Array:
		var items: Array = rows[i][1]
		var n := items.size()
		var per_row := mini(n, 2)    # Early's four chips as 2 x 2: four in a row cut the names at 720 px
		var lines := ceili(float(n) / float(per_row))
		var gap := 8.0
		var cw := (size.x - gap * float(per_row - 1)) / float(per_row)
		var top := float(i) * ROW_H + (ROW_H - (CHIP_H * float(lines) + gap * float(lines - 1))) * 0.5
		var out: Array = []
		for k in n:
			out.append(Rect2(float(k % per_row) * (cw + gap), top + float(k / per_row) * (CHIP_H + gap), cw, CHIP_H))
		return out

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var sb := UI.font("SemiBold")
		for i in rows.size():
			var rects := chip_rects(i)
			var items: Array = rows[i][1]
			for k in items.size():
				var it: Dictionary = items[k]
				var r: Rect2 = rects[k]
				var c := UI.GOOD if bool(it["mine"]) else UI.BAD
				_ops.bg("pill", r, Color(c.r, c.g, c.b, 0.16 if _press_row != i else 0.3))
				_ops.bg("pillring", r, Color(c.r, c.g, c.b, 0.5))
				_ops.icon("tick" if bool(it["mine"]) else "cross", Rect2(r.position.x + 10.0, r.position.y + 12.0, 24.0, 24.0), c.lerp(Color.WHITE, 0.25))
				var nd := dots(String(it["size"]))
				var dots_w := float(nd) * 8.0 + float(nd - 1) * 4.0
				_ops.text(sb, UI.S_CAPTION, chip_name(String(it["key"])), r.position.x + 40.0, r.position.y + 24.0, r.size.x - 40.0 - dots_w - 18.0, UI.TEXT)
				for d in nd:
					_ops.shape("disc", Rect2(r.end.x - 12.0 - dots_w + float(d) * 12.0, r.position.y + 20.0, 8.0, 8.0), c.lerp(Color.WHITE, 0.25))
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped

	func row_at(p: Vector2) -> int:
		if p.x < 0.0 or p.x > size.x or p.y < 0.0:
			return -1
		var i := int(p.y / ROW_H)
		return i if i < rows.size() else -1

	func _gui_input(event: InputEvent) -> void:
		match _tr.feed(event):
			"down":
				_press_row = row_at(_tr.press_pos)
				_press_g = get_global_transform_with_canvas() * _tr.press_pos
				queue_redraw()
			"up":
				var i := _press_row
				_press_row = -1
				queue_redraw()
				var g := get_global_transform_with_canvas() * _tr.pos
				if i >= 0 and g.distance_to(_press_g) <= TouchTrack.SLOP and row_at(_tr.pos) == i:
					press(i)

	func press(i: int) -> void:
		if i >= 0 and i < rows.size() and on_row.is_valid():
			on_row.call(String(rows[i][0]))


## The factor bars of the Why sheet: one row per factor (name, a bar from the centre, the signed share). One Control.
class _Bars extends Control:
	const ROW_H := 64.0
	var factors: Array = []
	var draw_count := 0
	var _ops := CardKit.Ops.new()

	func _init(p_factors: Array) -> void:
		factors = p_factors
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, ROW_H * float(factors.size()))
		resized.connect(queue_redraw)
		CompKit.set_cue(self, "sign+side")

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var nf := UI.font("SemiBold", true)
		for i in factors.size():
			var f: Dictionary = factors[i]
			var y := float(i) * ROW_H
			var pv := int(round(absf(float(f["share"])) * 100.0))
			var good := float(f["value"]) >= 0.0
			var num := ("" if pv == 0 else ("+" if good else "-")) + "%d%%" % pv
			var nw := 84.0
			_ops.text(UI.font(), UI.S_SMALL, Strings.t("factor." + String(f["id"])), 0.0, y + 18.0, size.x - nw - 8.0, UI.TEXT)
			_ops.text(nf, UI.S_SMALL, num, size.x - nw, y + 18.0, nw, UI.TEXT, 2)
			var bar := Rect2(0.0, y + 40.0, size.x - nw - 8.0, 12.0)
			_ops.shape("solid", bar, UI.PANEL3)
			var half := bar.size.x * 0.5
			var len := maxf(3.0, clampf(absf(float(f["share"])) / 0.6, 0.0, 1.0) * half)
			var c := UI.GOOD if good else UI.BAD
			if good:
				_ops.shape("solid", Rect2(bar.position.x + half, bar.position.y, len, bar.size.y), c)
			else:
				_ops.shape("solid", Rect2(bar.position.x + half - len, bar.position.y, len, bar.size.y), c)
			_ops.shape("solid", Rect2(bar.position.x + half - 1.0, bar.position.y - 5.0, 2.0, bar.size.y + 10.0), UI.TEXT)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped


## What the game changed: the five starters (avatar, name, form and morale with arrows; the standout gets a star), then three
## tiles (Bonds, Chemistry, Cash). Three plus two starters per row at the narrow width. One Control.
class _Changes extends Control:
	const CHIP_H := 132.0
	const TILE_H := 124.0
	var people: Array = []             # [{pid, slot, name, form, morale, star}]
	var tiles: Array = []              # [[label, value text, delta]]
	var draw_count := 0
	var _ops := CardKit.Ops.new()

	func _init(p_people: Array, p_tiles: Array) -> void:
		people = p_people
		tiles = p_tiles
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resized.connect(_relayout)
		CompKit.set_cue(self, "sign+arrow")
		_relayout()

	func per_row() -> int:
		return 3    # three and two: five in a row cut the names and the numbers

	func tile_cols() -> int:
		return 1 if UI.large else 3

	func _relayout() -> void:
		var pr := per_row()
		var lines := ceili(float(people.size()) / float(pr))
		var tl := ceili(float(tiles.size()) / float(tile_cols()))
		var h := float(lines) * (CHIP_H + 8.0) + 8.0 + float(tl) * (TILE_H + 8.0)
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size = Vector2(0, h)
		queue_redraw()

	static func arrow(d: float) -> String:
		return "arrow_up" if d > 0.0005 else ("arrow_down" if d < -0.0005 else "arrow_flat")

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var pr := per_row()
		var gap := 8.0
		var cw := (size.x - gap * float(pr - 1)) / float(pr)
		var sb := UI.font("SemiBold")
		var nf := UI.font("SemiBold", true)
		for i in people.size():
			var p: Dictionary = people[i]
			var r := Rect2(float(i % pr) * (cw + gap), float(i / pr) * (CHIP_H + gap), cw, CHIP_H)
			_ops.bg("card", r, UI.PANEL)
			_ops.portraits.append(["avatar", Rect2(r.position.x + 8.0, r.position.y + 8.0, 44.0, 44.0), String(p["pid"]), String(p["slot"]), false])
			if bool(p["star"]):
				_ops.icon("star", Rect2(r.end.x - 34.0, r.position.y + 8.0, 26.0, 26.0), UI.WARN)
			_ops.text(sb, UI.S_CAPTION, String(p["name"]), r.position.x + 58.0, r.position.y + 30.0, r.size.x - 58.0 - (34.0 if bool(p["star"]) else 6.0), UI.TEXT)
			var df := float(p["form"])
			var dm := float(p["morale"])
			_ops.icon(arrow(df), Rect2(r.position.x + 8.0, r.position.y + 66.0, 22.0, 22.0), UI.delta_color(df) if absf(df) > 0.0005 else UI.DIM)
			_ops.text(nf, UI.S_CAPTION, "%s %s" % [Strings.t("report.pay.form"), UI.signed(df, 1)], r.position.x + 34.0, r.position.y + 77.0, r.size.x - 40.0, UI.TEXT)
			_ops.icon(arrow(dm), Rect2(r.position.x + 8.0, r.position.y + 98.0, 22.0, 22.0), UI.delta_color(dm) if absf(dm) > 0.0005 else UI.DIM)
			_ops.text(nf, UI.S_CAPTION, "%s %s" % [Strings.t("report.pay.morale"), UI.signed(dm, 0)], r.position.x + 34.0, r.position.y + 109.0, r.size.x - 40.0, UI.TEXT)
		var y0 := float(ceili(float(people.size()) / float(pr))) * (CHIP_H + gap) + 8.0
		var tc := tile_cols()
		var tw := (size.x - gap * float(tc - 1)) / float(tc)
		for i in tiles.size():
			var t: Array = tiles[i]
			var r := Rect2(float(i % tc) * (tw + gap), y0 + float(i / tc) * (TILE_H + gap), tw, TILE_H)
			_ops.bg("card", r, UI.PANEL)
			var tl := PlanKit.wrap(sb, UI.S_CAPTION, String(t[0]), r.size.x - 32.0, 2)
			for k in tl.size():
				_ops.text(sb, UI.S_CAPTION, String(tl[k]), r.position.x + 16.0, r.position.y + 24.0 + 26.0 * float(k), r.size.x - 32.0, UI.DIM)
			var d := float(t[2])
			_ops.icon(arrow(d), Rect2(r.position.x + 16.0, r.position.y + 74.0, 30.0, 30.0), UI.delta_color(d) if absf(d) > 0.0005 else UI.DIM)
			_ops.text(UI.font("Bold", true), UI.S_HEAD, String(t[1]), r.position.x + 54.0, r.position.y + 89.0, r.size.x - 70.0, UI.TEXT)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped


# ---- life -------------------------------------------------------------------------------------------------------------------------

func _init(g: Dictionary = {}, r: Dictionary = {}, quick: bool = false) -> void:
	super._init()
	game = g
	res = r
	_quick = quick


func go_back() -> void:
	_leave()


func _leave() -> void:
	if BottomSheet.is_open():
		BottomSheet.current().close()
	if game["kind"] == "exhibition":
		App.go(ScreenPractice.new())
	elif App.gs.d["phase"] == "done":
		App.go(ScreenSeasonEnd.new())
	else:
		App.go(ScreenHub.new())


func _ready() -> void:
	var gs := App.gs
	my_side = "B" if game["blue"] == gs.club() else "R"
	opp_id = game["red"] if my_side == "B" else game["blue"]
	won = res["blue_won"] == (my_side == "B")
	att = Report.attribution(res, my_side)
	setup("", Callable(), false)
	_build()
	result.count_up()
	stat.set_value(round(absf(float(_top_factor().get("share", 0.0))) * 100.0))


func is_practice() -> bool:
	return String(game.get("kind", "")) == "exhibition"


func is_tutorial() -> bool:
	return TutorialGame.is_tutorial(game) or TutorialGame.is_tutorial(res)


## Team kills, [you, them] (Report.team_kills: the score line).
func score() -> Array:
	var tk := Report.team_kills(res)
	var opp := "R" if my_side == "B" else "B"
	return [int(tk[my_side]), int(tk[opp])]


## The phase signs for you: {"early": +1 or -1, ...} from res["sim"] (Blue's sign), and the story key from the three.
func phase_signs() -> Dictionary:
	var sgn := 1.0 if my_side == "B" else -1.0
	var out := {}
	for ph in Report.PHASES:
		out[ph] = 1 if sgn * float(res["sim"][ph]) > 0.0 else -1
	return out


func story_key() -> String:
	var s := phase_signs()
	var k := ""
	for ph in Report.PHASES:
		k += "p" if int(s[ph]) > 0 else "m"
	return "report.story." + k


## The story rows: [[phase id, [feed events of that phase]], ...] (Report.feed grouped Early 4, Mid 2, Late 2).
func story_rows() -> Array:
	var ev := Report.feed(res, my_side)
	return [["early", ev.slice(0, 4)], ["mid", ev.slice(4, 6)], ["late", ev.slice(6, 8)]]


## The factor with the largest share by size (luck included).
func _top_factor() -> Dictionary:
	var best := {}
	for f in att["factors"]:
		if best.is_empty() or absf(float(f["share"])) > absf(float(best["share"])):
			best = f
	return best


func stat_sentence() -> String:
	var f := _top_factor()
	if f.is_empty():
		return ""
	var pct := "%d" % int(round(absf(float(f["share"])) * 100.0))
	if String(f["id"]) == "luck":
		return Strings.f("report.hero.luck_for" if float(f["value"]) >= 0.0 else "report.hero.luck_against", {"pct": pct})
	return Strings.f("report.hero.help" if float(f["value"]) >= 0.0 else "report.hero.hurt", {"what": Strings.t("factor." + String(f["id"])), "pct": pct})


func _factor_chip(kind: String) -> String:
	var pick := {}
	for f in att["factors"]:
		if String(f["id"]) == "luck":
			continue
		var v := float(f["value"])
		if kind == "best" and v > 0.0 and (pick.is_empty() or v > float(pick["value"])):
			pick = f
		if kind == "worst" and v < 0.0 and (pick.is_empty() or v < float(pick["value"])):
			pick = f
	if pick.is_empty():
		return ""
	var pv := int(round(absf(float(pick["share"])) * 100.0))
	return "%s: %s %s%d%%" % [Strings.t("report.best_factor" if kind == "best" else "report.worst_factor"), Strings.t("factor." + String(pick["id"])), "+" if kind == "best" else "-", pv]


func _raise(event_name: String, data: Dictionary = {}) -> void:
	if is_instance_valid(App.bus):
		App.bus.emit(event_name, data)


# ---- building (once) ----------------------------------------------------------------------------------------------------------

func _build() -> void:
	build_count += 1
	var gs := App.gs
	ArtWire.prepare(App.world.club_ids, [])
	body.add_theme_constant_override("separation", 12)
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, UI.HEADER_H)
	header.add_theme_constant_override("separation", 8)
	var back := UI.button("<", _leave, "normal", UI.BTN_H)
	back.custom_minimum_size = Vector2(UI.BTN_H, UI.BTN_H)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back)
	var title := UI.label(Strings.t("report.title"), UI.S_BIG, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, "Bold")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)
	if help_slot != null and help_slot.get_parent() == self:
		remove_child(help_slot)
		help_slot.set_anchors_preset(Control.PRESET_TOP_LEFT)
		help_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
		header.add_child(help_slot)
	body.add_child(header)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll = sc
	body.add_child(sc)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 20)
	sc.add_child(page)
	# 1. the result
	result = _Result.new()
	var word := Report.result_word(float(res["final"]))
	var series := ""
	if game["kind"] == "playoff":
		for ser in gs.d["playoffs"]["series"]:
			if ser["id"] == game["series"]:
				series = Strings.f("report.series", {"stage": Strings.t(gs.playoff_label(ser)), "a": gs.club_name(ser["a"]), "wa": ser["wins_a"], "b": gs.club_name(ser["b"]), "wb": ser["wins_b"]})
	result.setup(won, score(), gs.club(), opp_id, "%s  vs  %s" % [gs.club_name(gs.club()), gs.club_name(opp_id)],
			Strings.f("report.summary", {"margin": Strings.t("report.margin." + word), "len": ScreenMatch._mmss(Report.game_minutes(res))}), series)
	UI.tag(result, "report.result", false)
	page.add_child(result)
	# 2. the story
	var sbox := VBoxContainer.new()
	sbox.add_theme_constant_override("separation", 8)
	sbox.add_child(UI.label(Strings.t("report.story_h"), UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	story_label = UI.label(Strings.t(story_key()), UI.S_BODY, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold")
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sbox.add_child(story_label)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 12)
	var signs := phase_signs()
	var ph: Array = []
	for p in Report.PHASES:
		ph.append({"id": p, "label": PlanKit.name_of_phase(p), "result": "win" if int(signs[p]) > 0 else "lose", "controls": []})
	strip = PhaseStrip.new(ph, "", _on_strip, true, "report.story")
	srow.add_child(strip)
	bands = _Bands.new(story_rows(), _open_phase)
	srow.add_child(bands)
	sbox.add_child(srow)
	page.add_child(sbox)
	# 3. why: the hero stat (tap: the factor bars)
	stat_tile = PanelContainer.new()
	stat_tile.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, 20, 24))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	stat = HeroStat.new(0.0, "%.0f%%", stat_sentence(), _factor_chip("best"), _factor_chip("worst"))
	stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(stat)
	var more := UI.label(Strings.t("report.all_factors") + "  >", UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_RIGHT, "SemiBold")
	sv.add_child(more)
	stat_tile.add_child(sv)
	var hit := UI.button("", _open_why, "flat")
	hit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stat_tile.add_child(hit)
	UI.tag_tile(stat_tile, "report.why")
	page.add_child(stat_tile)
	# 4. what changed / the practice card / the tutorial card
	if is_tutorial():
		practice_card = _card(Strings.t("tut.report_card.h"), [Strings.t("tut.report_card.body")])
		UI.tag(practice_card, "report.payoff", false)
		page.add_child(practice_card)
	elif is_practice():
		practice_card = _practice_card()
		UI.tag(practice_card, "report.payoff", false)
		page.add_child(practice_card)
	else:
		var po: Dictionary = App.last_payoff
		if not po.is_empty():
			var cbox := VBoxContainer.new()
			cbox.add_theme_constant_override("separation", 8)
			cbox.add_child(UI.label(Strings.t("report.pay.h"), UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
			changes = _Changes.new(_people(po), _tiles(po))
			cbox.add_child(changes)
			UI.tag(cbox, "report.payoff", false)
			page.add_child(cbox)
		# 5. the tip
		var t := Payoff.tip(gs)
		tip_card = _card(Strings.t("report.tip_h"), [Strings.f(t["key"], t["args"])])
		if String(t["key"]) in ["tip.rest", "tip.contract"]:
			tip_button = UI.button(Strings.t("report.tip.open_squad"), _open_squad, "normal")
			tip_card.content.add_child(tip_button)
		UI.tag(tip_card, "report.tip", false)
		page.add_child(tip_card)
	# 6. more detail, one part at a time
	dig_button = UI.button(Strings.t("report.dig_h") + "  v", _toggle_dig, "flat")
	dig_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for k in ["font_color", "font_hover_color"]:
		dig_button.add_theme_color_override(k, UI.TEAL_HI)
	page.add_child(dig_button)
	dig_bar = DraftKit.RoleBar.new(_set_dig, "report.dig", [
			{"id": "players", "label": Strings.t("report.dig.players"), "icon": "star"},
			{"id": "moments", "label": Strings.t("report.dig.moments"), "icon": "clock"},
			{"id": "draft", "label": Strings.t("report.dig.draft"), "icon": "pick"}], _dig)
	dig_bar.visible = false
	page.add_child(dig_bar)
	dig_box = VBoxContainer.new()
	dig_box.add_theme_constant_override("separation", 6)
	dig_box.visible = false
	page.add_child(dig_box)
	# the sticky footer
	continue_button = UI.button(Strings.t("common.continue"), _leave, "play")
	continue_button.custom_minimum_size = Vector2(0, UI.BTN_H)
	UI.tag(continue_button, "report.continue")
	body.add_child(continue_button)
	if UI.animate:
		result.modulate.a = 0.0
		result.create_tween().tween_property(result, "modulate:a", 1.0, UI.T_FADE)


func _card(head: String, lines: Array) -> DepthCard:
	var c := DepthCard.new()
	c.content.add_child(UI.label(head, UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	for t in lines:
		var l := UI.label(String(t), UI.S_BODY, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.content.add_child(l)
	return c


## Practice games change only fatigue and bonds, and the series stands where it stands.
func _practice_card() -> DepthCard:
	var gs := App.gs
	var lines: Array = [Strings.t("report.practice.body")]
	var x := gs.practice_series()
	if not x.is_empty():
		lines.append(Strings.f("report.practice.series", {"me": x["me"], "them": x["them"], "bo": x["best_of"]}))
	elif gs.d.has("exh_last"):
		var l: Dictionary = gs.d["exh_last"]
		lines.append(Strings.f("report.practice.done", {"result": Strings.t("practice.last.win" if l["won"] else "practice.last.loss"), "me": l["me"], "them": l["them"], "bo": l["best_of"]}))
	return _card(Strings.t("report.practice.h"), lines)


## The starters' chips: the standout (the slot that moved the result most for you, as before) carries a star.
func _people(po: Dictionary) -> Array:
	var star := standout_slot()
	var out: Array = []
	for r in po["rows"]:
		out.append({"pid": String(r["id"]), "slot": String(r["slot"]), "name": String(App.world.players[r["id"]]["name"]),
				"form": float(r["form_a"]) - float(r["form_b"]), "morale": float(r["mor_a"]) - float(r["mor_b"]), "star": String(r["slot"]) == star})
	return out


func _tiles(po: Dictionary) -> Array:
	var out: Array = [[Strings.t("report.pay.bonds"), "%.0f" % float(po["bond_a"]), float(po["bond_a"]) - float(po["bond_b"])],
			[Strings.t("report.pay.chem"), UI.pct(float(po["chem_a"])), float(po["chem_a"]) - float(po["chem_b"])]]
	if absf(float(po["cash_d"])) >= 1.0:
		out.append([Strings.t("report.pay.cash"), "%+d" % int(round(float(po["cash_d"]))), float(po["cash_d"])])
	return out


## The slot whose players helped most (3 percent or more), "" when nobody really decided it (the old _standout rule, positive side).
func standout_slot() -> String:
	var best := {}
	for f in att["factors"]:
		if String(f["id"]).begins_with("slot.") and (best.is_empty() or float(f["value"]) > float(best["value"])):
			best = f
	if best.is_empty() or float(best["value"]) <= 0.0 or int(round(absf(float(best["share"])) * 100.0)) < 3:
		return ""
	return String(best["id"]).substr(5)


# ---- actions ------------------------------------------------------------------------------------------------------------------

func _on_strip(id: String) -> void:
	strip.set_selected("")
	_open_phase(id)


## A phase's moments with their clock times and margin words (sheet report_phase).
func _open_phase(ph: String) -> void:
	BottomSheet.open(PlanKit.name_of_phase(ph), _phase_body.bind(ph), Callable(), "M", "report_phase")


func _phase_body(c: Control, ph: String) -> void:
	var total := Report.game_minutes(res)
	for row in story_rows():
		if String(row[0]) != ph:
			continue
		for ev in row[1]:
			var line := Strings.f("feed.line", {"t": ScreenMatch._mmss(float(ev["t"]) * total), "title": Strings.t("feed.t." + ev["key"]),
					"result": Strings.f("feed.win" if ev["mine"] else "feed.loss", {"size": Strings.t("feed.m." + ev["size"])})})
			var l := UI.label(line, UI.S_BODY, UI.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c.add_child(l)


## Why this happened: every factor as a bar (sheet report_why, size L). Opening it raises open:report_why (BottomSheet).
func _open_why() -> void:
	BottomSheet.open(Strings.t("report.why_sheet_h"), _why_body, Callable(), "L", "report_why")


func _why_body(c: Control) -> void:
	var factors: Array = (att["factors"] as Array).duplicate()
	factors.sort_custom(func(a, b): return absf(a["value"]) > absf(b["value"]))
	why_bars = _Bars.new(factors)
	UI.tag(why_bars, "report.why_sheet", false)
	c.add_child(why_bars)
	var n := UI.label(Strings.t("report.why_note"), UI.S_SMALL, UI.DIM)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(n)
	var luck := UI.label(Strings.t("report.luck_note"), UI.S_SMALL, UI.DIM)
	luck.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(luck)


func _open_squad() -> void:
	App.go_tab("squad")


func _toggle_dig() -> void:
	var open := not dig_bar.visible
	dig_bar.visible = open
	dig_box.visible = open
	dig_button.text = Strings.t("report.dig_h") + ("  ^" if open else "  v")
	if open:
		_fill_dig()


func _set_dig(id: Variant) -> void:
	_dig = String(id)
	_fill_dig()


func _fill_dig() -> void:
	for ch in dig_box.get_children():
		dig_box.remove_child(ch)
		ch.queue_free()
	match _dig:
		"players":
			_lines()
		"moments":
			_moments()
		_:
			_draft_recap()


func _lines() -> void:
	var w := App.world
	var k := Report.kda(res)
	dig_box.add_child(UI.label(Strings.t("report.lines_head"), UI.S_SMALL, UI.DIM))
	for s in GameState.SLOTS:
		var l: Dictionary = k[my_side][s]
		var p: Dictionary = w.players[res["lineups"][my_side][s]]
		UI.kv_row(dig_box, "%s  %s" % [Strings.t("role.short." + s), p["name"]], "%d / %d / %d" % [int(l["k"]), int(l["d"]), int(l["a"])])
	var n := UI.label(Strings.t("report.lines_note"), UI.S_SMALL, UI.DIM)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dig_box.add_child(n)


func _moments() -> void:
	var total := Report.game_minutes(res)
	for ev in Report.feed(res, my_side):
		var line := Strings.f("feed.line", {"t": ScreenMatch._mmss(float(ev["t"]) * total), "title": Strings.t("feed.t." + ev["key"]),
				"result": Strings.f("feed.win" if ev["mine"] else "feed.loss", {"size": Strings.t("feed.m." + ev["size"])})})
		var l := UI.label(("+ " if ev["mine"] else "- ") + line, UI.S_SMALL, UI.GOOD if ev["mine"] else UI.BAD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dig_box.add_child(l)


func _draft_recap() -> void:
	var w := App.world
	var opp := "R" if my_side == "B" else "B"
	for t in [my_side, opp]:
		dig_box.add_child(UI.label(Strings.t("draft.you") if t == my_side else Strings.t("draft.opponent"), UI.S_SMALL, UI.TEAL_HI if t == my_side else UI.CORAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
		var picks: Array = []
		for s in GameState.SLOTS:
			picks.append("%s: %s - %s" % [Strings.t("role.short." + s), w.players[res["lineups"][t][s]]["name"], w.heroes[res["picks"][t][s]]["name"]])
		var pl := UI.label("\n".join(PackedStringArray(picks)), UI.S_SMALL, UI.TEXT)
		dig_box.add_child(pl)
		dig_box.add_child(UI.label(Strings.f("draft.comp_line", {"style": Strings.t("style." + String(res["style"][t])), "mod": UI.pct(float(res["comp"][t]))}), UI.S_SMALL, UI.DIM))
		var bans: Array = []
		for hid in res["bans"][t]:
			bans.append(w.heroes[hid]["name"])
		var bl := UI.label(Strings.f("draft.bans", {"list": ", ".join(bans)}), UI.S_SMALL, UI.DIM)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dig_box.add_child(bl)
