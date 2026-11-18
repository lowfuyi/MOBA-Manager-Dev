class_name DeviceState
extends RefCounted
## What this device remembers about the guide, the lessons and the "?" help dots (build plan 0.7 section 5 item 6, I-11).
## Typed access to three sections of settings.cfg: [tutorial], [lessons], [help]. The old one-time tips of 0.6 live in
## [tips] (App.tip_seen / tip_mark / tips_reset, untouched until I-24); their keys read as help already seen.
## Pure logic over ConfigFile: no autoloads, so it runs in run_tests.gd. The path is a parameter so tests use a temp file.
## Every read opens the file again (it is tiny, and App writes the same file for the [ui] section); a missing or
## unreadable file reads as "nothing remembered". Writes never throw away sections this class does not own.

const SETTINGS_PATH := "user://settings.cfg"
## [tutorial] flags (all booleans, absent = false).
const TUTORIAL_FLAGS := ["welcome_seen", "finished_once", "skipped_once", "legacy_offer_done", "tips_mapped_off"]
## Old [tips] key -> help id it counts as seen for. Hub is the Home help sheet.
const TIP_TO_HELP := {"hub": "home", "prematch": "prematch", "report": "report"}
## After this many "Later" taps an offer is dismissed for good (TUTORIAL 4.1).
const MAX_SNOOZES := 3

var path: String


func _init(settings_path: String = SETTINGS_PATH) -> void:
	path = settings_path


# ------------------------------------------------------------------ file helpers
func _load() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(path)          # a missing file is fine: an empty ConfigFile
	return cf


func _write(section: String, key: String, v: Variant) -> void:
	var cf := _load()
	cf.set_value(section, key, v)
	cf.save(path)


static func _valid_key(k: String) -> bool:
	if k == "":
		return false
	for i in k.length():
		var c := k.unicode_at(i)
		var ok := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c == 46
		if not ok:
			return false
	return true


# ------------------------------------------------------------------ [tutorial]
func tutorial_flag(key: String) -> bool:
	var v = _load().get_value("tutorial", key, false)
	return v is bool and bool(v)


## False (and nothing written) for a name that is not one of TUTORIAL_FLAGS.
func set_tutorial_flag(key: String, value: bool = true) -> bool:
	if not TUTORIAL_FLAGS.has(key):
		return false
	_write("tutorial", key, value)
	return true


## Carry out a "device" effect from TutorialState ({"fx": "device", "section": "tutorial", "key": ..., "value": ...}).
func apply(effect: Dictionary) -> bool:
	if String(effect.get("fx", "")) != "device" or String(effect.get("section", "")) != "tutorial":
		return false
	return set_tutorial_flag(String(effect.get("key", "")), bool(effect.get("value", true)))


## What Home should show for this save on this device (TutorialState.offer_for with the device flags filled in).
func home_offer(tut, resume: bool = true) -> String:
	return TutorialState.offer_for(tut, tutorial_flag("welcome_seen"), tutorial_flag("legacy_offer_done"), resume)


# ------------------------------------------------------------------ [lessons]
## "" (never offered), "offered", "snoozed:<n>", "dismissed" or "done". A value written by hand that is none of these
## reads as "".
func lesson_status(id: String) -> String:
	var v = _load().get_value("lessons", id, "")
	return String(v) if v is String and valid_lesson_status(String(v)) else ""


static func valid_lesson_status(s: String) -> bool:
	if s in ["offered", "dismissed", "done"]:
		return true
	if s.begins_with("snoozed:"):
		var n := s.substr(8)
		return n.is_valid_int() and int(n) >= 1 and int(n) < MAX_SNOOZES
	return false


## False (nothing written) for a malformed id or status. "" clears the lesson back to "never offered".
func set_lesson_status(id: String, status: String) -> bool:
	if not _valid_key(id):
		return false
	if status == "":
		var cf := _load()
		if cf.has_section_key("lessons", id):
			cf.erase_section_key("lessons", id)
			cf.save(path)
		return true
	if not valid_lesson_status(status):
		return false
	_write("lessons", id, status)
	return true


## The player tapped Later: snoozed:1, snoozed:2, then dismissed (the third Later). A done or dismissed lesson stays as it is.
## Returns the new status. Which three match days the snooze lasts is the lesson offer logic's job (I-23).
func lesson_later(id: String) -> String:
	var cur := lesson_status(id)
	if cur == "done" or cur == "dismissed" or not _valid_key(id):
		return cur
	var n := int(cur.substr(8)) if cur.begins_with("snoozed:") else 0
	n += 1
	var nxt := "dismissed" if n >= MAX_SNOOZES else "snoozed:%d" % n
	_write("lessons", id, nxt)
	return nxt


func lesson_ids() -> Array:
	var cf := _load()
	return Array(cf.get_section_keys("lessons")) if cf.has_section("lessons") else []


## Lesson bookkeeping beside the statuses (I-23): "new_day" / "new_day_lesson" (the one new offer of a match day) and
## "until.<id>" (the match day a snooze ends). Section [lessons_meta]; "" when unset.
func lesson_meta(key: String) -> Variant:
	return _load().get_value("lessons_meta", key, "")


func set_lesson_meta(key: String, v: Variant) -> bool:
	if not _valid_key(key):
		return false
	_write("lessons_meta", key, v)
	return true


## Show help hints again, lesson half: snoozed and dismissed go back to offered; done keeps its tick. Returns how many changed.
func lessons_reset_offers() -> int:
	var cf := _load()
	var n := 0
	if cf.has_section("lessons"):
		for k in cf.get_section_keys("lessons"):
			var cur := lesson_status(k)
			if cur == "dismissed" or cur.begins_with("snoozed:"):
				cf.set_value("lessons", k, "offered")
				n += 1
		if n > 0:
			cf.save(path)
	return n


# ------------------------------------------------------------------ [help] ("?" dots)
## True once the sheet of this screen was opened on this device. Old 0.6 tips count (hub is Home) until help_reset().
func help_seen(id: String) -> bool:
	var cf := _load()
	var v = cf.get_value("help", id, false)
	if v is bool and bool(v):
		return true
	if bool(cf.get_value("tutorial", "tips_mapped_off", false)):
		return false
	for tip in TIP_TO_HELP:
		if TIP_TO_HELP[tip] == id:
			var o = cf.get_value("tips", tip, false)
			if o is bool and bool(o):
				return true
	return false


func help_mark(id: String) -> bool:
	if not _valid_key(id):
		return false
	_write("help", id, true)
	return true


func help_ids() -> Array:
	var cf := _load()
	return Array(cf.get_section_keys("help")) if cf.has_section("help") else []


## Clear every "?" dot (the old tips no longer count either; the [tips] section itself is left for App.tips_reset).
func help_reset() -> void:
	var cf := _load()
	if cf.has_section("help"):
		cf.erase_section("help")
	cf.set_value("tutorial", "tips_mapped_off", true)
	cf.save(path)


## Settings, "Show help hints again": dots and lesson offers (done lessons keep their tick).
func hints_reset() -> void:
	help_reset()
	lessons_reset_offers()


# ------------------------------------------------------------------ [arena] (Alpha 0.8 A-06)
## The held-fight staging for testers (ARENA-MAP 7.3): "" = the data's default (held_island), or "held_gate". A device setting,
## not part of the save: it changes only how a decided game is drawn.
const ARENA_HELD := ["", "held_island", "held_gate"]


func arena_held() -> String:
	var v = _load().get_value("arena", "held", "")
	return String(v) if v is String and ARENA_HELD.has(String(v)) else ""


func set_arena_held(id: String) -> bool:
	if not ARENA_HELD.has(id):
		return false
	_write("arena", "held", id)
	return true


# ------------------------------------------------------------------ [display] (Alpha 0.8.1)
## The frame-rate cap (Settings, "Frame rate"): 30 or 60 frames a second, 60 when unset or unreadable. A device setting, not
## part of the save (R6): it changes only how often the screen redraws, never what is shown at a given moment.
const FPS_CHOICES := [30, 60]
const FPS_DEFAULT := 60


func fps() -> int:
	var v = _load().get_value("display", "fps", FPS_DEFAULT)
	return int(v) if (v is int) and FPS_CHOICES.has(int(v)) else FPS_DEFAULT


## Sound and vibration (Alpha 0.8.2, section [audio]): both on unless switched off; anything that is not true or false reads as on.
func sound() -> bool:
	var v = _load().get_value("audio", "sound", true)
	return v if v is bool else true


func set_sound(on: bool) -> void:
	_write("audio", "sound", on)


func haptics() -> bool:
	var v = _load().get_value("audio", "haptics", true)
	return v if v is bool else true


func set_haptics(on: bool) -> void:
	_write("audio", "haptics", on)


func set_fps(n: int) -> bool:
	if not FPS_CHOICES.has(n):
		return false
	_write("display", "fps", n)
	return true
