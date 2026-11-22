class_name ScreenPreMatch
extends Screen
## Match day (I-21b restyle): the versus card (both badges, names and the team-rating bar, as on Home), the side and the draft type,
## the lane matchups drawn as one control (role glyph, your player and rating, an ARROW AND A WORD for stronger, even or weaker,
## their player and rating; off-role is a warning glyph and the word: the I-21a debt "colour only" is paid here), chemistry, the
## tired-starters card with Rotate, then Start draft (the one coral action), Change lineup and Quick result.
## Tags (I-21a, kept): prematch.matchups (the matchups card), prematch.start_draft.

var game: Dictionary
var matchups: _Matchups


## The five lane rows: [{role, mine, rm, theirs, rt, edge ("up", "down", "even"), off}].
class _Matchups extends Control:
	const ROW_H := 72.0
	var rows: Array = []
	var draw_count := 0
	var _ops := CardKit.Ops.new()

	func _init(p_rows: Array) -> void:
		rows = p_rows
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, ROW_H * float(rows.size()) * (2.0 if UI.large else 1.0))
		resized.connect(queue_redraw)
		CompKit.set_cue(self, "arrow+word")

	static func edge_word(e: String) -> String:
		match e:
			"up":
				return Strings.t("pre.edge.up")
			"down":
				return Strings.t("pre.edge.down")
		return Strings.t("home.even")

	func _draw() -> void:
		draw_count += 1
		ArtWire.ensure()
		_ops.clear()
		var sb := UI.font("SemiBold")
		var nf := UI.font("SemiBold", true)
		var two := UI.large
		var rh := ROW_H * (2.0 if two else 1.0)
		var mid_w := 132.0
		for i in rows.size():
			var r: Dictionary = rows[i]
			var y := float(i) * rh
			if i > 0:
				_ops.shape("solid", Rect2(0.0, y, size.x, 1.0), UI.LINE)
			var e := String(r["edge"])
			var col := UI.GOOD if e == "up" else (UI.BAD if e == "down" else UI.TEXT2)
			_ops.icon(Icons.role_id(String(r["role"])), Rect2(0.0, y + ROW_H * 0.5 - 16.0, 32.0, 32.0), UI.TEXT2)
			var side_w := (size.x - 44.0 - mid_w) * 0.5 if not two else size.x - 44.0 - mid_w
			var mine := "%s %s" % [String(r["mine"]), String(r["rm"])]
			_ops.text(sb, UI.S_SMALL, mine, 44.0, y + ROW_H * 0.5 - (12.0 if bool(r["off"]) else 0.0), side_w - 8.0, UI.TEXT)
			if bool(r["off"]):
				_ops.icon("warning", Rect2(44.0, y + ROW_H * 0.5 + 4.0, 20.0, 20.0), UI.WARN)
				_ops.text(UI.font(), UI.S_CAPTION, Strings.t("roster.offrole"), 68.0, y + ROW_H * 0.5 + 14.0, side_w - 32.0, UI.WARN)
			var mx := 44.0 + side_w
			_ops.icon("arrow_up" if e == "up" else ("arrow_down" if e == "down" else "arrow_flat"), Rect2(mx, y + ROW_H * 0.5 - 14.0, 28.0, 28.0), col)
			_ops.text(sb, UI.S_CAPTION, edge_word(e), mx + 32.0, y + ROW_H * 0.5, mid_w - 36.0, col)
			var tx := mx + mid_w
			var ty := y + ROW_H * 0.5
			var tw := size.x - tx
			if two:
				tx = 44.0
				ty = y + ROW_H * 1.5
				tw = size.x - 44.0
			_ops.text(UI.font(), UI.S_SMALL, "%s %s" % [Strings.t("standings.vs"), String(r["theirs"])], tx, ty, tw - CardKit.text_w(nf, UI.S_SMALL, String(r["rt"])) - 12.0, UI.TEXT2)
			_ops.text(nf, UI.S_SMALL, String(r["rt"]), tx, ty, tw, UI.TEXT2, 2)
		_ops.flush(self)

	func clipped() -> Array:
		return _ops.clipped


func _init(g: Dictionary = {}) -> void:
	super._init()
	game = g


func go_back() -> void:
	if TutorialGame.is_tutorial(game):   # backing out of the tutorial game drops its sandbox (I-13)
		TutorialGame.leave(App.gs)
		if App.tutorial != null:
			App.tutorial.set_game_live(false)
	if game["kind"] == "exhibition":
		App.go(ScreenPractice.new())
	else:
		App.go(ScreenHub.new())


## The lane rows from the lineups (rating in role; stronger or weaker beyond 1.5 points, as before).
func matchup_rows() -> Array:
	var gs := App.gs
	var me := gs.club()
	var opp: String = game["red"] if game["blue"] == me else game["blue"]
	var mine := gs.lineup()
	var theirs := gs.lineup_for(opp)
	var out: Array = []
	for s in GameState.SLOTS:
		var a: Dictionary = mine[s]
		var b: Dictionary = theirs[s]
		var ra := App.world.slot_score(a, s)
		var rb := App.world.slot_score(b, s)
		out.append({"role": s, "mine": a["name"], "rm": "%.0f" % ra, "theirs": b["name"], "rt": "%.0f" % rb,
				"edge": "up" if ra > rb + 1.5 else ("down" if ra < rb - 1.5 else "even"), "off": App.world.player_fit(a, s) < 1.0})
	return out


func _ready() -> void:
	var gs := App.gs
	var me := gs.club()
	var my_side := "B" if game["blue"] == me else "R"
	var opp: String = game["red"] if my_side == "B" else game["blue"]
	setup(Strings.t("pre.title.practice" if game["kind"] == "exhibition" else "pre.title"), go_back)
	ArtWire.prepare(App.world.club_ids, [])
	body.add_theme_constant_override("separation", 16)
	# The old Pre-match tip is retired (I-21a): it would sit under tutorial steps 10 and 11. tip.prematch* stay in en.json until I-24.
	var c := DepthCard.new(1)
	if game["kind"] == "exhibition":
		var note: String = Strings.t("tut.practice.note") if TutorialGame.is_tutorial(game) else Strings.f("pre.practice_note", {"game": game["game"], "bo": game["best_of"]})
		var nl := UI.label(note, UI.S_SMALL, UI.WARN)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.content.add_child(nl)
	c.content.add_child(HomeKit.VersusPanel.new(me, gs.club_name(me), opp, gs.club_name(opp), App.world.team_rating(gs.lineup()), App.world.team_rating(gs.lineup_for(opp))))
	var nb := DraftFormat.of_game(game)
	var secs := int(DraftFormat.timer_s(nb))
	c.content.add_child(HomeKit.ChipRow.new([[Strings.f("pre.side", {"side": Strings.t("hub.side.blue" if my_side == "B" else "hub.side.red")}), "neutral", "flag_blue" if my_side == "B" else "flag_red"],
			[Strings.f("pre.draft_info", {"type": ScreenDraft.format_text(nb), "secs": secs}), "neutral", "clock"]]))
	body.add_child(c)
	# matchups
	var m := DepthCard.new()
	UI.tag(m, "prematch.matchups", false)    # tutorial step 10 (the card, so the hole has its edge)
	m.content.add_child(UI.label(Strings.t("pre.matchups"), UI.S_SMALL, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	matchups = _Matchups.new(matchup_rows())
	m.content.add_child(matchups)
	m.content.add_child(UI.label(Strings.f("pre.chem", {"bonus": UI.pct(gs.chem_bonus())}), UI.S_SMALL, UI.TEAL_HI))
	body.add_child(m)
	var tired := gs.tired_starters()
	if not tired.is_empty():
		var tc := DepthCard.new()
		var tl := UI.label(Strings.f("pre.tired_warn", {"n": tired.size()}), UI.S_SMALL, UI.WARN)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tc.content.add_child(tl)
		if not TutorialGame.is_tutorial(game):    # Rotate and Change lineup are real edits to the season: not in the tutorial game (I-13 ruling 5)
			tc.content.add_child(UI.button(Strings.t("pre.rotate"), _rotate, "normal"))
		body.add_child(tc)
	body.add_child(UI.tag(UI.button(Strings.t("pre.start_draft"), func(): App.go(ScreenDraft.new(game)), "play"), "prematch.start_draft"))
	if not TutorialGame.is_tutorial(game):
		body.add_child(UI.button(Strings.t("pre.change_lineup"), func(): App.go(ScreenRoster.new("prematch", game))))
	var q := UI.button(Strings.t("hub.quick"), _quick, "flat")
	for k in ["font_color", "font_hover_color"]:
		q.add_theme_color_override(k, UI.TEAL_HI)
	body.add_child(q)


func _quick() -> void:
	if TutorialGame.logs_pace(game):
		App.gs.pace_quick()
	ScreenHub._finish_game(game, App.gs.auto_game(game))


func _rotate() -> void:
	App.gs.reset_lineup()
	App.autosave()
	App.go(ScreenPreMatch.new(game))
