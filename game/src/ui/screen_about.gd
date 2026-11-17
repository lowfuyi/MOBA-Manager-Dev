class_name ScreenAbout
extends Screen


func tab_id() -> String:
	return "" if App.gs == null else "more"


func go_back() -> void:
	App.go(ScreenTitle.new() if App.gs == null else ScreenSettings.new())


func _ready() -> void:
	setup(Strings.t("about.title"), go_back)
	for sec in ["included", "test", "limits", "report"]:
		var c := UI.card(body)
		c.add_child(UI.label(Strings.t("about.%s.h" % sec), UI.S_HEAD, UI.ACCENT))
		c.add_child(UI.label(Strings.t("about.%s.b" % sec), UI.S_BODY, UI.TEXT))
	# Licences (I-24): the font credit, and the licence text itself from the file that ships in the APK (export filter)
	var lc := UI.card(body)
	lc.add_child(UI.label(Strings.t("about.licences.h"), UI.S_HEAD, UI.ACCENT))
	var fl := UI.label(Strings.t("about.licences.font"), UI.S_BODY, UI.TEXT)
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lc.add_child(fl)
	var rb := UI.button(Strings.t("about.licences.read"), _open_licence, "normal")
	UI.tag(rb, "about.licence")
	lc.add_child(rb)


const LICENCE_PATH := "res://assets/fonts/OFL.txt"


static func licence_text() -> String:
	return FileAccess.get_file_as_string(LICENCE_PATH) if FileAccess.file_exists(LICENCE_PATH) else ""


func _open_licence() -> void:
	BottomSheet.open(Strings.t("about.licences.h"), func(c: Control) -> void:
		var l := UI.label(licence_text(), UI.S_SMALL, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(l), Callable(), "L", "licence")
