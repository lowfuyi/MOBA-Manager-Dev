class_name ScreenHub
extends Screen
## Home (UI-PASS-2 6.1, build plan I-15). Built once in `_build()`, top to bottom:
##   hero        HomeKit.Hero: badge, club name, season line, rank and record, last five games as W / L pips
##   next card   the only raised card (DepthCard elevation 1), overlapping the hero by 64 px: what the game is, side (word plus
##               flag), both badges, the rating bar, chips, Play (the one coral control) and Auto-play (a text button). The card
##               body taps: a "Match preview" sheet with the lane matchups. Playoffs: the series line. No game: the "season is
##               over" card (Finish the season) or, when the split is done, the Season complete card (Season summary).
##   offer       the guided first game's inline card (I-14), below Play, never above it
##   needs you   a Carousel of attention cards (tired starters before a game, contracts from round 9 on, debt)
##   up next     a section header with See all and a Carousel of the coming league games (Favoured / Even / Underdog)
##   tiles       2 x 2 StatTiles: Standing, Cash, Chemistry, Squad mood; each opens its place
## Tutorial ids: home.next_card, home.play, home.offer (OfferCard), home.attention, home.upnext, home.tile.standing / cash /
## chem / mood. Nothing here decides a result (R7); Play and Auto-play take the same paths as before.

const ATT_W := 324.0    # two cards and the 16 px gap fill the 664 px row (672 less the scrollbar reserve)
const UPNEXT_W := 300.0
const CARD_OVERLAP := 64

var build_count := 0
var hero: HomeKit.Hero
var next_card: DepthCard
var play_button: Button
var versus: HomeKit.VersusPanel
var chips: HomeKit.ChipRow
var attention: Carousel
var upnext: Carousel
var tiles: HomeKit.TileGrid
var _att_actions: Array = []
var rest_button: Button
static var rest_summary := ""    # 0.12 Q4-7: the results line shown once on the next Home (a String, never a node)
var _upnext_items: Array = []


func tab_id() -> String:
	return "home"


func is_tab_root() -> bool:
	return true


func go_back() -> void:
	App.autosave()
	App.go(ScreenTitle.new())


func _ready() -> void:
	var gs := App.gs
	if gs.is_dismissed():
		App.go.call_deferred(ScreenGameOver.new())
		return
	setup("", Callable())
	body.add_theme_constant_override("separation", UI.GAP)
	_build()
	if rest_summary != "":
		_show_rest_summary.call_deferred()


func _build() -> void:
	build_count += 1
	var gs := App.gs
	ArtWire.prepare(App.world.club_ids, App.world.heroes.values())
	_hero()
	var g := gs.next_game()
	if gs.d["phase"] == "done":
		_done_card()
	elif g.is_empty():
		_waiting_card()
	else:
		_next_card(g)
	_offer()
	_attention()
	_upnext()
	_tiles(_my_row())


func _my_row() -> Dictionary:
	for r in App.gs.standings():
		if r["club"] == App.gs.club():
			return r
	return {}


func _when() -> String:
	var gs := App.gs
	match gs.d["phase"]:
		"league":
			return Strings.f("hub.when.league", {"season": gs.d["season"], "round": int(gs.d["round"]) + 1, "total": gs.total_rounds(), "patch": gs.patch_label()})
		"playoffs":
			return Strings.f("hub.when.playoffs", {"season": gs.d["season"]})
	return Strings.f("hub.when.done", {"season": gs.d["season"]})


## The last five league and playoff games, newest first ("w" or "l"; practice games are not in the history).
func last_five() -> Array:
	var out: Array = []
	var h: Array = App.gs.d.get("history", [])
	var i := h.size() - 1
	while i >= 0 and out.size() < 5:
		var e: Dictionary = h[i]
		if String(e.get("kind", "")) in ["league", "playoff"]:
			out.append("w" if bool(e.get("won", false)) else "l")
		i -= 1
	return out


func _hero() -> void:
	var gs := App.gs
	var me := gs.club()
	var row := _my_row()
	var rank_line := "%s  %s" % [Strings.f("home.rank_of", {"rank": row.get("rank", 0), "n": App.world.club_ids.size()}),
			Strings.f("hub.tile.record", {"w": row.get("w", 0), "l": row.get("l", 0), "pts": row.get("pts", 0)}).get_slice(" ", 0)]
	hero = HomeKit.Hero.new(me, gs.club_name(me), _when(), rank_line, last_five())
	hero.name = "Hero"
	body.add_child(hero)
	# Home has no header: the "?" goes in the hero's top-right corner (kept clear for it, I-15 ruling 1) so it scrolls away with
	# the page. Floating over the page, it covered the game card when the page scrolled.
	if help_slot != null and help_slot.get_parent() == self:
		remove_child(help_slot)
		hero.add_child(help_slot)
		help_slot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		help_slot.offset_left = -UI.BTN_H
		help_slot.offset_right = 0
		help_slot.offset_top = 0
		help_slot.offset_bottom = UI.BTN_H


## The raised card, pulled up over the bottom 64 px of the hero.
func _raised(tut_id: String, tappable: bool) -> DepthCard:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", -CARD_OVERLAP - UI.GAP)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := DepthCard.new(1, Color(0, 0, 0, 0), false, tappable, tut_id)
	wrap.add_child(c)
	body.add_child(wrap)
	c.content.add_theme_constant_override("separation", 14)
	return c


func _next_card(g: Dictionary) -> void:
	var gs := App.gs
	var me := gs.club()
	var opp: String = g["red"] if g["blue"] == me else g["blue"]
	var blue: bool = g["blue"] == me
	next_card = _raised("home.next_card", true)
	next_card.pressed.connect(_open_preview.bind(g))
	var c := next_card.content
	var title := Strings.f("home.next.league_round", {"round": int(g["round"]) + 1}) if g["kind"] == "league" else Strings.t("hub.next.playoff")
	c.add_child(HomeKit.CardHead.new(title.to_upper(), Strings.t("hub.side.blue" if blue else "hub.side.red"), "flag_blue" if blue else "flag_red"))
	if g["kind"] == "playoff":
		for s in gs.d["playoffs"]["series"]:
			if s["id"] == g["series"]:
				c.add_child(UI.label(Strings.f("hub.series_state", {"stage": Strings.t(gs.playoff_label(s)), "bo": s["best_of"], "game": g["game"], "a": gs.club_name(s["a"]),
						"wa": s["wins_a"], "b": gs.club_name(s["b"]), "wb": s["wins_b"]}), UI.S_SMALL, UI.TEAL_HI))
	var mine := App.world.team_rating(gs.lineup())
	var theirs := App.world.team_rating(gs.lineup_for(opp))
	versus = HomeKit.VersusPanel.new(me, gs.club_name(me), opp, gs.club_name(opp), mine, theirs)
	c.add_child(versus)
	var items: Array = [[ScreenDraft.format_text(DraftFormat.of_game(g)), "neutral", ""],
			[Strings.f("hub.chip.chem", {"bonus": UI.pct(gs.chem_bonus())}), "accent", ""]]
	var tired := gs.tired_starters().size()
	if tired > 0:
		items.append([Strings.f("hub.chip.tired", {"n": tired}), "warn", ""])
	chips = HomeKit.ChipRow.new(items)
	c.add_child(chips)
	play_button = UI.button(Strings.t("hub.play"), func(): App.pace_t0 = Time.get_ticks_msec(); App.go(ScreenPreMatch.new(g)), "play", 104)
	play_button.add_theme_font_size_override("font_size", UI.S_HEAD)
	UI.tag(play_button, "home.play")
	c.add_child(play_button)
	var auto := UI.button(Strings.t("hub.quick"), func(): _quick(g), "flat")
	for k in ["font_color", "font_hover_color"]:
		auto.add_theme_color_override(k, UI.TEAL_HI)
	UI.tag(auto, "home.autoplay")
	c.add_child(auto)
	var left := league_games_left()
	var tstate := String((App.gs.d.get("tutorial", {}) as Dictionary).get("state", "legacy"))    # the guide offered or running
	var guided := tstate in ["new", "running"] or (App.lessons != null and App.lessons.running())
	# 0.12 Q4-7: play the rest of the league (not while the guide or a lesson runs: their cards point at this card's layout)
	if g["kind"] == "league" and left >= 2 and not TutorialGame.is_tutorial(g) and not guided:
		rest_button = UI.button(Strings.f("hub.rest.button", {"n": left}), _open_rest, "flat")
		for k in ["font_color", "font_hover_color"]:
			rest_button.add_theme_color_override(k, UI.TEAL_HI)
		UI.tag(rest_button, "home.rest_league", false)
		c.add_child(rest_button)


## The playoffs go on without the club (eliminated): one line and Finish the season.
func _waiting_card() -> void:
	next_card = _raised("home.next_card", false)
	var l := UI.label(Strings.t("hub.waiting"), UI.S_BODY, UI.TEXT2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_card.content.add_child(l)
	next_card.content.add_child(UI.button(Strings.t("hub.skip_to_end"), _skip_to_end, "primary"))


## The split is over: Season complete, the champion, and the Season summary.
func _done_card() -> void:
	var gs := App.gs
	next_card = _raised("home.next_card", false)
	var c := next_card.content
	c.add_child(UI.label(Strings.t("home.season_done").to_upper(), UI.S_CAPTION, UI.TEAL_HI, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold"))
	var champ := String(gs.d.get("champion", ""))
	if champ != "":
		var row := UI.hbox()
		row.add_theme_constant_override("separation", 16)
		row.add_child(HomeKit.BadgeView.new(champ, gs.club_name(champ), 72.0))
		var l := UI.label(Strings.f("hub.champion", {"club": gs.club_name(champ)}), UI.S_BIG, UI.WARN)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		c.add_child(row)
	c.add_child(UI.button(Strings.t("hub.season_summary"), func(): App.go(ScreenSeasonEnd.new()), "primary"))


## Things that need a decision, as attention cards (debt first); each tap goes where it is fixed. Contracts show from round 9 (D6).
func _attention() -> void:
	var gs := App.gs
	var items: Array = []
	_att_actions.clear()
	if gs.cash() < 0.0:    # first: debt can end the career (the board dismisses the manager)
		items.append(Strings.t("home.att.debt"))
		_att_actions.append(func(): App.go(ScreenFinance.new()))
	var tired := gs.tired_starters().size()
	if tired > 0 and not gs.next_game().is_empty():
		items.append(Strings.f("home.att.tired", {"n": tired}))
		_att_actions.append(func(): App.go(ScreenRoster.new("hub")))
	var ex := gs.expiring().size()
	if ex > 0 and (gs.d["phase"] != "league" or int(gs.d["round"]) + 1 >= 9):
		items.append(Strings.f("home.att.contracts", {"n": ex}))
		_att_actions.append(func(): App.go(ScreenRoster.new("hub")))
	if items.is_empty():
		return
	var cards: Array = []
	for t in items:
		cards.append(HomeKit.AttentionCard.new(String(t)))
	# half-width cards when every label fits one (UI-PASS-2 6.1: "Debt: cash below zero" does not and takes the full row);
	# one card, or any label too long, takes the whole row (the carousel caps it at the row width, with a peek of the next)
	var w := ATT_W
	for t in items:
		if CardKit.text_w(UI.font("Regular"), UI.S_BODY, String(t)) > HomeKit.AttentionCard.room_for(ATT_W):
			w = 2000.0
	if items.size() == 1:
		w = 2000.0
	attention = Carousel.new(w, cards, Callable(), "home.attention")
	attention.card_tapped.connect(_on_attention)
	body.add_child(attention)


func _on_attention(i: int) -> void:
	if i >= 0 and i < _att_actions.size():
		(_att_actions[i] as Callable).call()


## The coming league games (the next one is on the card above, so it is left out).
func _upnext() -> void:
	var gs := App.gs
	var nxt := gs.next_game()
	_upnext_items.clear()
	for u in gs.upcoming(Carousel.MAX_CARDS + 1):
		if not nxt.is_empty() and u["id"] == nxt.get("id", ""):
			continue
		_upnext_items.append(u)
	if _upnext_items.is_empty():
		return
	body.add_child(SectionHeader.new(Strings.t("home.up_next"), {"action": Strings.t("home.see_all"), "on_action": _open_fixtures, "tut_id": "home.upnext.head"}))
	var cards: Array = []
	for u in _upnext_items:
		cards.append(HomeKit.UpNextCard.new(u, gs.club_name(String(u["opp"]))))
	upnext = Carousel.new(UPNEXT_W, cards, Callable(), "home.upnext")
	upnext.card_tapped.connect(_open_opponent)
	body.add_child(upnext)


func _tiles(row: Dictionary) -> void:
	var gs := App.gs
	tiles = HomeKit.TileGrid.new()
	tiles.name = "Tiles"
	body.add_child(tiles)
	var t1 := HomeKit.StatTile.new(Strings.t("hub.tile.standing"), Strings.f("home.rank_of", {"rank": row.get("rank", 0), "n": App.world.club_ids.size()}),
			Strings.f("hub.tile.record", {"w": row.get("w", 0), "l": row.get("l", 0), "pts": row.get("pts", 0)}), "trophy", func(): App.go(ScreenStandings.new()))
	var net := int(round(gs.weekly_net()))
	var t2 := HomeKit.StatTile.new(Strings.t("hub.tile.cash"), PlayerView.money(gs.cash()), Strings.f("hub.tile.net", {"net": "%+d" % net}), "coin",
			func(): App.go(ScreenFinance.new()))
	t2.set_arrow("arrow_up" if net > 0 else ("arrow_down" if net < 0 else "arrow_flat"), UI.GOOD if net > 0 else (UI.BAD if net < 0 else UI.TEXT2))
	if gs.cash() < 0.0:
		t2.set_value_color(UI.BAD)
	var t3 := HomeKit.StatTile.new(Strings.t("hub.tile.chem"), UI.pct(gs.chem_bonus()), Strings.f("hub.tile.bonds", {"avg": "%.0f" % gs.bond_mean()}), "star",
			func(): App.go(ScreenChemistry.new()))
	var mor := 0.0
	var frm := 0.0
	var ids: Array = (gs.d["lineup"] as Dictionary).values()
	for pid in ids:
		mor += gs.morale_of(pid)
		frm += gs.form_of(pid)
	mor /= float(maxi(1, ids.size()))
	frm /= float(maxi(1, ids.size()))
	var word := Bonds.mood_word(mor)
	var t4 := HomeKit.StatTile.new(Strings.t("hub.tile.mood"), Strings.t("mood.word." + word), Strings.f("hub.tile.form", {"form": UI.signed(frm, 1)}), "morale",
			func(): App.go(ScreenRoster.new("hub")))
	t4.set_arrow("arrow_up" if frm > 0.05 else ("arrow_down" if frm < -0.05 else "arrow_flat"), UI.delta_color(frm))
	t4.set_value_color(UI.GOOD if word == "high" else (UI.WARN if word == "low" else (UI.BAD if word == "poor" else UI.TEXT)))    # colour follows the word
	var ids_t := ["home.tile.standing", "home.tile.cash", "home.tile.chem", "home.tile.mood"]
	var all := [t1, t2, t3, t4]
	for k in all.size():
		UI.tag(all[k], ids_t[k])
		tiles.add_child(all[k])


# ---- sheets (read-only) ----------------------------------------------------------------------------------------------------

## Match preview: the five lane matchups, and Change lineup / Rest tired starters.
func _open_preview(g: Dictionary) -> void:
	BottomSheet.open(Strings.t("home.preview_h"), _preview_body.bind(g), _preview_footer.bind(g), "M", "home_preview")


func _preview_body(c: Control, g: Dictionary) -> void:
	var gs := App.gs
	var me := gs.club()
	var opp: String = g["red"] if g["blue"] == me else g["blue"]
	var mine := gs.lineup()
	var theirs := gs.lineup_for(opp)
	for s in GameState.SLOTS:
		var a: Dictionary = mine[s]
		var b: Dictionary = theirs[s]
		var ra := App.world.slot_score(a, s)
		var rb := App.world.slot_score(b, s)
		var l := UI.label(Strings.f("pre.row", {"role": Strings.t("role." + s), "mine": a["name"], "rm": "%.0f" % ra, "theirs": b["name"], "rt": "%.0f" % rb}), UI.S_SMALL, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(l)


func _preview_footer(f: Control, g: Dictionary) -> void:
	var gs := App.gs
	if not gs.tired_starters().is_empty():
		BottomSheet.footer_button(f, Strings.t("pre.rotate"), func(): gs.reset_lineup(); App.autosave(); BottomSheet.current().close(); App.go(ScreenHub.new()), "normal")
	BottomSheet.footer_button(f, Strings.t("pre.change_lineup"), func(): BottomSheet.current().close(); App.go(ScreenRoster.new("hub")), "normal")


## One coming opponent: rating, table position, Form Rating rank and your last result against them.
func _open_opponent(i: int) -> void:
	if i < 0 or i >= _upnext_items.size():
		return
	var u: Dictionary = _upnext_items[i]
	BottomSheet.open(App.gs.club_name(String(u["opp"])), _opponent_body.bind(u), Callable(), "S", "home_opponent")


func _opponent_body(c: Control, u: Dictionary) -> void:
	var gs := App.gs
	var opp := String(u["opp"])
	var rank := 0
	for r in gs.standings():
		if r["club"] == opp:
			rank = int(r["rank"])
	var frank := 0
	for f in gs.form_ranking():
		if f["club"] == opp:
			frank = int(f["rank"])
	var last := ""
	var h: Array = gs.d.get("history", [])
	for i in range(h.size() - 1, -1, -1):
		var e: Dictionary = h[i]
		if e.get("blue", "") == opp or e.get("red", "") == opp:
			last = "home.opp.last_won" if bool(e.get("won", false)) else "home.opp.last_lost"
			break
	for line in [Strings.f("home.opp.rating", {"v": "%.1f" % float(u["theirs"])}), Strings.f("home.opp.table", {"rank": rank}),
			Strings.f("home.opp.form", {"rank": frank}), Strings.t(last if last != "" else "home.opp.last_none")]:
		var l := UI.label(line, UI.S_BODY, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(l)


## See all: every league game left this season.
func _open_fixtures() -> void:
	BottomSheet.open(Strings.t("home.fixtures_h"), _fixtures_body, Callable(), "L", "home_fixtures")


func _fixtures_body(c: Control) -> void:
	var gs := App.gs
	for u in gs.upcoming(gs.total_rounds()):
		var l := UI.label(Strings.f("home.fixture_row", {"round": int(u["round"]) + 1, "opp": gs.club_name(String(u["opp"])),
				"side": Strings.t("hub.side.blue" if u["side"] == "B" else "hub.side.red")}), UI.S_SMALL, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(l)


## The guided first game (I-14, TUTORIAL 6.2): an inline offer or resume card below the Next-match card and its Play button,
## never above them; or, for a brand-new save on a fresh device, the welcome modal on the overlay (after this screen is up).
func _offer() -> void:
	if App.tutorial == null:
		return
	var kind: String = App.tutorial.home_offer()
	var card := OfferCard.make_for(kind)
	if card != null:
		body.add_child(card)
	elif kind == "welcome_modal":
		App.tutorial.on_home.call_deferred()
	elif TutorialRunner.home_offers:
		var lo := LessonOffer.make("home")    # a lesson offer (I-23) only when the guide has nothing to offer here
		if lo != null:
			body.add_child(lo)


func _quick(g: Dictionary) -> void:
	var res := App.gs.auto_game(g)
	App.gs.pace_quick()
	_finish_game(g, res)


## Record the finished game and open the payoff screen. The numbers that changed (form, morale, bonds,
## cash, chemistry) are captured before and after, so the payoff screen can show what the game did.
static func _finish_game(g: Dictionary, res: Dictionary) -> void:
	var gs := App.gs
	var tut := TutorialGame.is_tutorial(g)   # the tutorial game (I-13): flag on the result, no Payoff, sandbox plan dropped
	var before := {} if tut else Payoff.snapshot(gs)
	App.last_game = g
	App.last_result = TutorialGame.stamp(res, g)
	gs.record_human_game(g, res)
	App.last_payoff = {} if tut else Payoff.compare(gs, before)
	if tut:
		TutorialGame.leave(gs)
		if App.tutorial != null:
			App.tutorial.set_game_live(false)
	App.autosave()
	App.go(ScreenReport.new(g, res, false))


## The managed club's league games not played yet.
static func league_games_left() -> int:
	var gs := App.gs
	var me := gs.club()
	var n := 0
	for f in gs.d["fixtures"]:
		if not bool(f.get("played", false)) and (f["blue"] == me or f["red"] == me):
			n += 1
	return n


## 0.12 Q4-7: confirm, then play every league game left without watching (GameState.autoplay, as Auto-play does one by
## one), then one line of results on Home.
func _open_rest() -> void:
	BottomSheet.open(Strings.t("hub.rest.h"), _rest_body, _rest_footer, "M", "home_rest")


func _rest_body(c: Control) -> void:
	var l := UI.label(Strings.f("hub.rest.body", {"n": league_games_left()}), UI.S_BODY, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(l)


func _rest_footer(f: Control) -> void:
	BottomSheet.footer_button(f, Strings.t("common.cancel"), func(): BottomSheet.current().close(), "normal")
	BottomSheet.footer_button(f, Strings.f("hub.rest.go", {"n": league_games_left()}), _play_rest, "primary", "home.rest_go")


func _play_rest() -> void:
	var gs := App.gs
	var me := gs.club()
	var before := {}
	for f in gs.d["fixtures"]:
		if bool(f.get("played", false)):
			before[String(f["id"])] = true
	gs.autoplay(false)
	var w := 0
	var l := 0
	for f in gs.d["fixtures"]:
		if before.has(String(f["id"])) or not bool(f.get("played", false)) or (f["blue"] != me and f["red"] != me):
			continue
		if f["winner"] == me:
			w += 1
		else:
			l += 1
	rest_summary = Strings.f("hub.rest.done", {"n": w + l, "w": w, "l": l, "rank": gs.rank_of(me), "clubs": App.world.club_ids.size()})
	App.autosave()
	if BottomSheet.is_open():
		BottomSheet.current().close()
	App.go(ScreenHub.new())


func _show_rest_summary() -> void:
	var text := rest_summary
	rest_summary = ""
	BottomSheet.open(Strings.t("hub.rest.done_h"), _rest_done_body.bind(text), Callable(), "S", "home_rest_done")


func _rest_done_body(c: Control, text: String) -> void:
	var l := UI.label(text, UI.S_BODY, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.tag(l, "home.rest_done", false)
	c.add_child(l)


func _skip_to_end() -> void:
	App.gs.autoplay(true)
	App.autosave()
	App.go(ScreenHub.new())
