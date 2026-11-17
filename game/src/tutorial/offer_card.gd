class_name OfferCard
extends DepthCard
## The inline card on Home that offers the guided first game (build plan 0.7 I-14, TUTORIAL 6.2 and 3.1). Never a modal:
##   returning_card  a new save on a device that answered the guide before  "Welcome back, Manager..."  Show me / No thanks
##   legacy_card     a save from before the guide, once per device          "New: a guided first game..."  Show me / No thanks
##   resume_card     a running guide after a load (the app was closed)      "Welcome back. Continue..."   Continue / Skip tutorial
## The welcome modal of a brand-new save on a fresh device is not this card: TutorialRunner.on_home() shows it on the overlay.
## A tap calls the runner (accept, decline, continue_resume, skip) and the card removes itself at once, so nothing of it can be
## tapped twice. Tagged `home.offer`; its buttons `home.offer.yes` / `home.offer.no`. It decides nothing about a game (R7).

const KINDS := ["returning_card", "legacy_card", "resume_card"]

var kind := ""
var yes_button: Button
var no_button: Button


## Home's card for `kind` (TutorialRunner.home_offer()), or null when the kind has no inline card ("none", "welcome_modal").
static func make_for(p_kind: String) -> OfferCard:
	if not KINDS.has(p_kind):
		return null
	return OfferCard.new(p_kind)


func _init(p_kind: String = "returning_card") -> void:
	super(1, Color(0, 0, 0, 0), false, false, "home.offer")
	kind = p_kind if KINDS.has(p_kind) else "returning_card"
	name = "OfferCard"
	var text_key := "tut.offer.returning"
	var yes_key := "tut.offer.yes"
	var no_key := "tut.offer.no"
	match kind:
		"legacy_card":
			text_key = "tut.offer.legacy"
		"resume_card":
			text_key = "tut.resume"
			yes_key = "tut.resume.go"
			no_key = "tut.skip"
	content.add_theme_constant_override("separation", 16)
	var l := UI.label(Strings.t(text_key), UI.S_BODY, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(l)
	var row := UI.hbox()
	row.add_theme_constant_override("separation", 16)
	no_button = UI.button(Strings.t(no_key), _on_no, "normal")
	yes_button = UI.button(Strings.t(yes_key), _on_yes, "primary")
	for b in [no_button, yes_button]:
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(b as Button).add_theme_font_size_override("font_size", UI.S_BODY)
		row.add_child(b)
	UI.tag(yes_button, "home.offer.yes")
	UI.tag(no_button, "home.offer.no")
	content.add_child(row)


func text() -> String:
	return UI.plain((content.get_child(0) as Label).text)


func _gone() -> void:
	hide()
	yes_button.disabled = true
	no_button.disabled = true
	queue_free()


func _on_yes() -> void:
	var r: TutorialRunner = App.tutorial
	_gone()
	if r == null:
		return
	if kind == "resume_card":
		r.continue_resume()
	else:
		r.accept()


func _on_no() -> void:
	var r: TutorialRunner = App.tutorial
	_gone()
	if r == null:
		return
	if kind == "resume_card":
		r.skip()
	else:
		r.decline()
