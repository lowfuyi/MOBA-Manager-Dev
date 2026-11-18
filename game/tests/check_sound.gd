extends Node
## Alpha 0.8.2 sound and vibration (Sfx, App.sound, App.buzz, Settings > Sound and vibration):
##   sounds    the seven placeholder sounds exist, are 30 ms to 1 s long and peak at or under 0.5 of full scale
##   off       with Sound off nothing plays; with Vibration off nothing buzzes; both are device settings (a fresh read sees
##             them) and leave the save untouched (R6)
##   match     a whole show at 1/60 s per frame plays one kill sound and one buzz per ledger kill (a longer buzz on the decisive
##             kill), two objective sounds, hit sounds no closer than 0.25 s, and the result sound once; Skip plays only the result
##   buttons   a normal button taps, a primary or play button confirms
##   silent    the result and the board are the same with sound and vibration off (nothing depends on them, R7)

const TEMP_CFG := "user://check_sound.cfg"

var checks := 0
var fails := 0
var _main: Control


func ok(cond: bool, what: String) -> void:
	checks += 1
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	TutorialRunner.home_offers = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	get_window().size = Vector2i(720, 1280)
	await frames(2)
	_sounds()
	await _boot()
	await _setting()
	await _match()
	await _buttons()
	_main.queue_free()
	await frames(2)
	GameState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CFG))
	App.set_sound(true)
	App.set_haptics(true)
	print("check_sound: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _boot() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	UI.animate = true
	await frames(3)
	GameState.delete_save()
	App.gs = GameState.new_game(App.world, App.world.club_ids[4], 20261120)
	var r: TutorialRunner = App.tutorial
	r.autosave = false
	r.device = DeviceState.new(TEMP_CFG)
	r.bind()


func _sounds() -> void:
	var bad: Array = []
	for n in Sfx.NAMES:
		var f := Sfx.samples(n)
		var peak := 0.0
		for v in f:
			peak = maxf(peak, absf(v))
		var secs := float(f.size()) / float(Sfx.RATE)
		if secs < 0.03 or secs > 1.0 or peak > 0.5 or peak < 0.05:
			bad.append("%s %.2f s peak %.2f" % [n, secs, peak])
		var w := Sfx.make(n)
		if w.data.size() != f.size() * 2 or w.mix_rate != Sfx.RATE:
			bad.append(n + " stream")
	ok(bad.is_empty(), "sounds: seven placeholder sounds, 30 ms to 1 s, peaks 0.05 to 0.5 %s" % str(bad))
	ok(App.sfx != null and App.sfx.streams.size() == Sfx.NAMES.size(), "sounds: App made them once at start-up (%d)" % (App.sfx.streams.size() if App.sfx != null else 0))


func _find(n: Node, name_: String) -> Node:
	if n.name == name_:
		return n
	for c in n.get_children():
		var f := _find(c, name_)
		if f != null:
			return f
	return null


func _setting() -> void:
	var dev: DeviceState = App.tutorial.device
	ok(dev.sound() and dev.haptics(), "setting: sound and vibration are on when nothing is stored")
	App.go(ScreenSettings.new())
	await frames(4)
	var st := _find(_main, "SoundToggle") as CheckButton
	var ht := _find(_main, "HapticsToggle") as CheckButton
	ok(st != null and ht != null and st.button_pressed and ht.button_pressed, "setting: Settings shows both switches, on")
	ok(st != null and st.size.y >= UI.BTN_H, "setting: full-height switches")
	var save_before := JSON.stringify(App.gs.d)
	if st != null:
		st.button_pressed = false
	if ht != null:
		ht.button_pressed = false
	await frames(2)
	ok(not DeviceState.new(TEMP_CFG).sound() and not DeviceState.new(TEMP_CFG).haptics(), "setting: switching both off is stored on the device (a fresh read sees it)")
	App.sfx.played.clear()
	App.buzzed.clear()
	ok(not App.sound("kill") and not App.buzz(30) and App.sfx.played.is_empty() and App.buzzed.is_empty(), "off: nothing plays and nothing buzzes")
	ok(JSON.stringify(App.gs.d) == save_before, "setting: the switches leave the save untouched (device settings, R6)")
	ok(App.debug_info().contains("sound=off haptics=off"), "setting: the feedback note names both")
	App.set_sound(true)
	App.set_haptics(true)
	ok(DeviceState.new(TEMP_CFG).sound() and App.sound("tap"), "setting: back on, a sound plays")


func _play(g: Dictionary, res: Dictionary, skip: bool) -> ScreenMatch:
	var m := ScreenMatch.new(g, res)
	App.go(m)
	await frames(4)
	m.set_process(false)
	App.sfx.played.clear()
	App.buzzed.clear()
	if skip:
		m._skip()
	else:
		var steps := 0
		while not m._finished and steps < 10000:
			m._process(1.0 / 60.0)
			steps += 1
	return m


func _count(list: Array, v) -> int:
	var n := 0
	for x in list:
		n += 1 if x == v else 0
	return n


func _match() -> void:
	var g := App.gs.next_game()
	var res := App.gs.auto_game(g)
	var res_text := JSON.stringify(res)
	var m: ScreenMatch = await _play(g, res.duplicate(true), false)
	var kills := m.script_.kill_events.size()
	var won := m.script_.winner == m.my_side
	var played: Array = App.sfx.played.duplicate()
	var buzzed: Array = App.buzzed.duplicate()
	ok(_count(played, "kill") == kills, "match: one kill sound per ledger kill (%d of %d)" % [_count(played, "kill"), kills])
	var long := 1 if not m.script_.decisive.is_empty() else 0
	ok(buzzed.size() == kills + 1 and _count(buzzed, 60) == long, "match: one buzz per kill (%d), %d long on the decisive kill, plus the result" % [kills, long])
	ok(_count(played, "objective") == 2, "match: two objective sounds")
	ok(_count(played, "victory" if won else "defeat") == 1 and _count(played, "defeat" if won else "victory") == 0, "match: the result sound once (%s)" % ("victory" if won else "defeat"))
	ok(_count(played, "hit") > 5, "match: hit sounds during the fights (%d)" % _count(played, "hit"))
	var board := JSON.stringify(ArenaHud.board_values(m.script_, 75.0))
	ok(JSON.stringify(m.res) == res_text, "match: the result is unchanged (R7)")
	await _play(g, res.duplicate(true), true)
	ok(App.sfx.played == ["victory" if won else "defeat"], "match: Skip plays only the result %s" % str(App.sfx.played))
	App.set_sound(false)
	App.set_haptics(false)
	var m2: ScreenMatch = await _play(g, res.duplicate(true), false)
	ok(App.sfx.played.is_empty() and App.buzzed.is_empty(), "silent: with both off a whole match plays no sound and no buzz")
	ok(JSON.stringify(ArenaHud.board_values(m2.script_, 75.0)) == board and JSON.stringify(m2.res) == res_text, "silent: the same board and result with sound off")
	App.set_sound(true)
	App.set_haptics(true)


func _buttons() -> void:
	App.sfx.played.clear()
	var a := UI.button("A", func() -> void: pass)
	var b := UI.button("B", func() -> void: pass, "primary")
	var c := UI.button("C", func() -> void: pass, "play")
	a.pressed.emit()
	b.pressed.emit()
	c.pressed.emit()
	ok(App.sfx.played == ["tap", "confirm", "confirm"], "buttons: tap for a normal button, confirm for primary and play %s" % str(App.sfx.played))
	a.free()
	b.free()
	c.free()
