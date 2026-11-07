class_name ScreenAbout
extends Screen


func go_back() -> void:
	App.go(ScreenTitle.new() if App.gs == null else ScreenHub.new())


func _ready() -> void:
	setup(Strings.t("about.title"), go_back)
	for sec in ["included", "test", "limits", "report"]:
		var c := UI.card(body)
		c.add_child(UI.label(Strings.t("about.%s.h" % sec), UI.S_BODY + 4, UI.ACCENT))
		c.add_child(UI.label(Strings.t("about.%s.b" % sec), UI.S_BODY, UI.TEXT))
