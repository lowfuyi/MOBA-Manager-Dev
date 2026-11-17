class_name LessonOffer
extends RefCounted
## The lesson offer card (TUTORIAL 4.1, build plan I-23): "New lesson: <title> (about a minute)" with Show me and Later, shown where the
## lesson belongs (Home, Club, Report, Draft complete). `make(place, context)` returns the card, or null when no lesson is due there
## (LessonRunner.offer_for decides). Tags: lesson.offer (the card), lesson.offer.yes, lesson.offer.no.


static func make(place: String, context: String = "") -> DepthCard:
	if App.lessons == null or not TutorialRunner.home_offers:
		return null    # screen tests turn offers off (they depend on the device's settings.cfg), as for the guide's Home offers
	var id: String = App.lessons.offer_for(place, context)
	if id == "":
		return null
	var c := DepthCard.new(1)
	c.set_meta("lesson_id", id)
	var l := UI.label(Strings.f("lesson.offer", {"title": Strings.t("lesson.title." + id)}), UI.S_BODY, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.content.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var yes := UI.button(Strings.t("lesson.show"), func():
		c.queue_free()
		App.lessons.start(id), "primary")
	UI.tag(yes, "lesson.offer.yes")
	row.add_child(yes)
	var no := UI.button(Strings.t("lesson.later"), func():
		App.lessons.later(id)
		c.queue_free(), "normal")
	UI.tag(no, "lesson.offer.no")
	row.add_child(no)
	c.content.add_child(row)
	UI.tag(c, "lesson.offer", false)
	return c
