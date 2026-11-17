class_name ScreenLessons
extends Screen
## The Lessons list (TUTORIAL 4.3, build plan I-23), from Settings: one card per lesson with its title, "About a minute", a New tag
## until it was started, a tick when done, and Start. L5 starts only during a draft ("Opens during a draft"), L8 only on a real
## report ("Not available right now" here). Start runs the lesson from its start route (LessonRunner.start).

var cards: Dictionary = {}    # lesson id -> the Start button (null when it cannot start here)


func tab_id() -> String:
	return "more"


func go_back() -> void:
	App.go(ScreenSettings.new())


static func open_screen() -> void:
	App.go(ScreenLessons.new())


func _ready() -> void:
	setup(Strings.t("lessons.title"), go_back)
	body.add_theme_constant_override("separation", 12)
	var dev: DeviceState = App.lessons.device() if App.lessons != null else DeviceState.new()
	for id in LessonRunner.ids():
		var st := dev.lesson_status(String(id))
		var l := LessonRunner.lesson(String(id))
		var c := DepthCard.new()
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		var t := UI.label(Strings.t("lesson.title." + String(id)), UI.S_BODY, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, "SemiBold")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_child(t)
		var chips: Array = []
		if st == "done":
			chips.append([Strings.t("lesson.done"), "good", "tick"])
		elif st == "" or st == "offered":
			chips.append([Strings.t("lesson.new"), "accent", "star"])
		if not chips.is_empty():
			var cr := HomeKit.ChipRow.new(chips)
			cr.custom_minimum_size.x = 150
			cr.size_flags_horizontal = Control.SIZE_SHRINK_END
			head.add_child(cr)
		c.content.add_child(head)
		c.content.add_child(UI.label(Strings.t("lessons.time"), UI.S_SMALL, UI.DIM))
		var where := String(l.get("start", "home"))
		if where == "draftdone" or where == "report":
			c.content.add_child(UI.label(Strings.t("lessons.opens_in_draft") if where == "draftdone" else Strings.t("lesson.na"), UI.S_SMALL, UI.TEXT2))
			cards[id] = null
		else:
			var b := UI.button(Strings.t("lessons.start"), func(): App.lessons.start(String(id)), "normal")
			UI.tag(b, "lessons.start." + String(id))
			c.content.add_child(b)
			cards[id] = b
		body.add_child(c)
