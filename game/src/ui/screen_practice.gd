class_name ScreenPractice
extends Screen
## Practice matches (GDD 7.9): Quick Match (one game against a club of about your strength) and Exhibition
## (any club, best of 1, 3 or 5). No effect on the table, Form Rating, Form, Morale, sponsor goals or career.

const LEN_KEYS := {1: "practice.len.1", 3: "practice.len.3", 5: "practice.len.5"}

var _len := 1


func tab_id() -> String:
	return "plan"


func go_back() -> void:
	App.go_tab("plan")


func _ready() -> void:
	setup(Strings.t("practice.title"), go_back)
	_rebuild()


func _rebuild() -> void:
	UI.clear(body)
	var gs := App.gs
	var intro := UI.card(body, UI.PANEL2)
	intro.add_child(UI.label(Strings.t("practice.intro"), UI.S_SMALL, UI.DIM))
	if tutorial_mode():
		_tutorial_card()
		return
	if gs.practice_in_progress():
		_series()
		return
	_last()
	if gs.d["phase"] != "league":
		body.add_child(UI.label(Strings.t("practice.phase"), UI.S_BODY, UI.DIM))
		return
	if not gs.practice_available():
		body.add_child(UI.label(Strings.t("practice.used"), UI.S_BODY, UI.WARN))
		return
	var q := UI.card(body)
	q.add_child(UI.label(Strings.t("practice.quick.h"), UI.S_BODY, UI.ACCENT))
	q.add_child(UI.label(Strings.t("practice.quick.body"), UI.S_SMALL, UI.DIM))
	q.add_child(UI.tag(UI.button(Strings.t("practice.quick.go"), _quick_match, "play"), "practice.quick"))
	var c := UI.card(body)
	c.add_child(UI.label(Strings.t("practice.choose.h"), UI.S_BODY, UI.ACCENT))
	var lens := UI.hbox()
	for n in [1, 3, 5]:
		lens.add_child(UI.button(Strings.t(LEN_KEYS[n]), _set_len.bind(n), "primary" if _len == n else "normal", 72))
	c.add_child(lens)
	for r in gs.practice_opponents():
		var txt := Strings.f("practice.opp", {"club": gs.club_name(r["club"]), "rating": "%.1f" % float(r["rating"]), "form": "%.0f" % gs.form_rating(r["club"])})
		c.add_child(UI.button(txt, _start.bind(r["club"], _len), "normal", 76))


const TUTORIAL_STEPS := ["plan_practice", "quick_match", "matchups", "start_draft"]


## True while the guided first game is at steps 8 to 11 and no tutorial game is in flight: Quick Match then starts the tutorial game,
## a sandbox that writes nothing to the save (I-13), whatever the phase or the practice day says. (Steps 10 and 11 count too: a
## player who backs out of the tutorial Pre-match gets the tutorial game again, never a real practice game.) Otherwise Practice is
## the real one.
static func tutorial_mode() -> bool:
	if App.tutorial == null or not App.tutorial.is_running() or App.gs == null:
		return false
	return TUTORIAL_STEPS.has(App.tutorial.m.step_id()) and not TutorialGame.is_live(App.gs)


func _tutorial_card() -> void:
	var q := UI.card(body)
	q.add_child(UI.label(Strings.t("practice.quick.h"), UI.S_BODY, UI.ACCENT))
	q.add_child(UI.label(Strings.t("tut.practice.note"), UI.S_SMALL, UI.WARN))
	q.add_child(UI.tag(UI.button(Strings.t("practice.quick.go"), _tutorial_quick, "play"), "practice.quick"))


## Quick Match in tutorial mode (the I-13 hand-off): the tutorial game, live in the runner, autosaved, then Pre-match.
func _tutorial_quick() -> void:
	var gs := App.gs
	var g := TutorialGame.start(gs)
	if g.is_empty():
		_quick_match()    # no opponent at all (cannot happen in a league of ten): the real Quick Match
		return
	App.tutorial.set_game_live(true)
	App.autosave()
	App.go(ScreenPreMatch.new(g))


func _set_len(n: int) -> void:
	_len = n
	_rebuild()


func _quick_match() -> void:
	_start(App.gs.quick_match_opponent(), 1)


func _start(opp: String, best_of: int) -> void:
	var gs := App.gs
	var why := gs.start_practice(opp, best_of)
	if why != "":
		App.toast(Strings.t(why), UI.WARN)
		_rebuild()
		return
	App.autosave()
	App.go(ScreenPreMatch.new(gs.practice_game()))


func _series() -> void:
	var gs := App.gs
	var x := gs.practice_series()
	var c := UI.card(body, UI.PANEL2)
	c.add_child(UI.label(Strings.f("practice.progress", {"club": gs.club_name(x["opp"]), "me": x["me"], "them": x["them"], "bo": x["best_of"]}), UI.S_BODY, UI.TEXT))
	c.add_child(UI.button(Strings.t("practice.next"), func(): App.go(ScreenPreMatch.new(gs.practice_game())), "play"))
	c.add_child(UI.button(Strings.t("practice.end"), func(): gs.end_practice(); App.autosave(); _rebuild(), "normal", 72))


func _last() -> void:
	var gs := App.gs
	if not gs.d.has("exh_last"):
		return
	var l: Dictionary = gs.d["exh_last"]
	body.add_child(UI.label(Strings.f("practice.last", {"result": Strings.t("practice.last.win" if l["won"] else "practice.last.loss"),
			"me": l["me"], "them": l["them"], "club": gs.club_name(l["opp"])}), UI.S_SMALL, UI.GOOD if l["won"] else UI.BAD))
