class_name SettingsHelpCard
extends DepthCard
## "Help and learning", the first card in Settings (build plan 0.7 I-14, TUTORIAL 6.3). One tap each:
##   Replay the guided first game  -> a confirm sheet (Replay it / Cancel); Replay it starts the guide at step 1 (state running,
##                                    game.n up by one, a new practice game) and goes to Home. Works in any phase.
##   Lessons, Glossary             -> shown only once their screens exist (I-23, I-22 set `lessons_open` / `glossary_open`)
##   Show help hints again         -> clears the "?" dots, sets snoozed and dismissed lessons back to offered, and (until I-24
##                                    retires the old tips) also clears the old [tips] flags so those tips come back. Toast.
## It replaces the old "Show the welcome tips again" button. Tagged `settings.help_card`; Replay is `settings.replay`.

## Set by I-23 and I-22 when the Lessons list and the Glossary exist; invalid = the button is not shown.
static var lessons_open: Callable = Callable()
static var glossary_open: Callable = Callable()

var replay_button: Button
var hints_button: Button


func _init() -> void:
	super(0, Color(0, 0, 0, 0), false, false, "settings.help_card")
	name = "SettingsHelpCard"
	content.add_theme_constant_override("separation", 12)
	content.add_child(UI.label(Strings.t("settings.help_h"), UI.S_BODY, UI.ACCENT))
	replay_button = _button("settings.replay", open_replay_sheet)
	UI.tag(replay_button, "settings.replay")
	if lessons_open.is_valid():
		_button("settings.lessons", func(): lessons_open.call())
	if glossary_open.is_valid():
		_button("settings.glossary", func(): glossary_open.call())
	hints_button = _button("settings.help_reset", hints_reset)


func _button(key: String, cb: Callable) -> Button:
	var b := UI.button(Strings.t(key), cb, "normal")
	b.add_theme_font_size_override("font_size", UI.S_BODY)
	content.add_child(b)
	return b


## The confirm sheet of Replay (a real BottomSheet, so Back and a tap on the scrim cancel it).
static func open_replay_sheet() -> BottomSheet:
	return BottomSheet.open(Strings.t("settings.replay"), _sheet_body, _sheet_footer, "M", "replay_confirm")


static func _sheet_body(c: Control) -> void:
	var l := UI.label(Strings.t("settings.replay_confirm"), UI.S_BODY, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(l)


static func _sheet_footer(f: Control) -> void:
	BottomSheet.footer_button(f, Strings.t("settings.replay_yes"), replay_now, "primary", "settings.replay_yes")
	BottomSheet.footer_button(f, Strings.t("common.cancel"), _cancel, "normal", "settings.replay_no")


static func _cancel() -> void:
	if BottomSheet.is_open():
		BottomSheet.current().close()


## Replay it: close the sheet, start the guide again, go to Home.
static func replay_now() -> void:
	if BottomSheet.is_open():
		BottomSheet.current().close()
	if App.tutorial == null or App.gs == null:
		return
	App.tutorial.replay()
	App.go_tab("home")


static func hints_reset() -> void:
	var dev: DeviceState = App.tutorial.device if App.tutorial != null else DeviceState.new()
	dev.hints_reset()
	App.tips_reset()    # the old tips still on screen come back too (until I-24 retires them)
	App.toast(Strings.t("settings.help_reset_done"), UI.GOOD)
