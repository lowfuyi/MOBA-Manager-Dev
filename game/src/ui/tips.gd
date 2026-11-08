class_name Tips
extends RefCounted
## One-time hints for a new manager (Alpha 0.6): a small card that goes away for good once dismissed.
## Remembered on the device (App.tip_seen), so a second save does not nag. Settings can bring them back.

const KEYS := {
	"hub": ["tip.hub.h", "tip.hub"],
	"prematch": ["tip.prematch.h", "tip.prematch"],
	"report": ["tip.report.h", "tip.report"],
}


static func show(parent: Control, key: String) -> void:
	if App.tip_seen(key):
		return
	var card := UI.card(parent, UI.PANEL2, 18, Color(UI.ACCENT.r, UI.ACCENT.g, UI.ACCENT.b, 0.7), 2)
	card.add_child(UI.label(Strings.t(KEYS[key][0]), UI.S_BODY, UI.ACCENT))
	card.add_child(UI.label(Strings.t(KEYS[key][1]), UI.S_SMALL, UI.TEXT))
	var box: Control = card.get_parent()
	var dismiss := func():
		App.tip_mark(key)
		box.queue_free()
	card.add_child(UI.button(Strings.t("tip.got_it"), dismiss, "primary", 72))
