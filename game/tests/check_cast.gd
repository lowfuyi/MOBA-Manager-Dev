extends Node
## The Broadcast (Match Day M4, docs/design/BROADCAST.md) on 60 real Match Sim v2 games (AI drafts, 1, 3 and 5 bans) and on
## synthetic logs:
##   silence     the longest gap with no line, by tier at the gap (6 s calm and aftermath, 3 s building, 2 s hot and peak)
##   coverage    share of show time with a line on screen
##   truth       every claim of every line is true in the log at the line's time (checked here independently of ArenaCast)
##   spoilers    no claim is about a moment after the line's game time; no result words before the end lines
##   repeats     no line twice within 120 s; never the same first word twice in a row
##   words       every line's template is inside its tier's word range
##   determinism the same game gives the same broadcast
##   tiers       a quiet game stays calm; a five-kill fight reaches peak; a lead flip raises e
##   display     the strip draws at 26 px or more (32 px Bold at peak), 3 lines at most
##   A1          nothing in src/arena calls the simulation, GamePlan.simulate or Report.attribution
## Nothing is measured on a phone.

var fails := 0
var checks := 0
const GAMES := 60


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
	print(("ok   " if cond else "FAIL ") + what)


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	var w := World.load_default()
	var meta := w.make_meta("cast-test")
	var P := ArenaCast.params()
	var silence_ok := true
	var worst_gap := ""
	var truth_bad: Array = []
	var spoil_bad: Array = []
	var rep_bad: Array = []
	var word_bad: Array = []
	var det_ok := true
	var cov_sum := 0.0
	var n_lines := 0
	var tiers := {}
	var keys := {}
	var games: Array = []
	for i in GAMES:
		var nb: int = [1, 3, 5][i % 3]
		var r := MatchRunner.auto(w, w.best_lineup(w.club_ids[i % 10]), w.best_lineup(w.club_ids[(i + 3) % 10]), meta, 9100 + i, "cast:%d" % i, nb, {"B": "ai", "R": "ai"})
		var pl := ArenaPlayer.build(r, "B" if i % 2 == 0 else "R")
		var c := ArenaCast.build(pl, "cast:%d" % i, {"B": "Blue Club", "R": "Red Club"})
		games.append([pl, c])
		if i < 6:
			det_ok = det_ok and c.transcript() == ArenaCast.build(pl, "cast:%d" % i, {"B": "Blue Club", "R": "Red Club"}).transcript()
		var end_s := pl.show_t(pl.end_t)
		var prev_end := 0.0
		var prev_tier := "calm"
		var covered := 0.0
		var last_first := ""
		var seen := {}
		for l in c.lines:
			n_lines += 1
			tiers[l["tier"]] = int(tiers.get(l["tier"], 0)) + 1
			keys[l["key"]] = true
			var gap := float(l["s0"]) - prev_end
			var lim := float(P["silence_s"][prev_tier]) + 0.01
			if gap > lim:
				silence_ok = false
				if worst_gap == "":
					worst_gap = "game %d: %.1f s silent after %.1f (%s)" % [i, gap, prev_end, prev_tier]
			covered += maxf(0.0, minf(float(l["s1"]), end_s) - float(l["s0"]))
			prev_end = float(l["s1"])
			prev_tier = c.tier_at(prev_end)
			# truth and spoilers
			for cl in l["claims"]:
				var res := _true(pl, cl as Array)
				if res != "":
					truth_bad.append("game %d %s: %s (%s)" % [i, l["key"], res, str(cl)])
				var ct := _claim_t(cl as Array)
				if ct > float(l["g"]) + 0.01:
					spoil_bad.append("game %d %s: claim at %.1f, line at %.1f" % [i, l["key"], ct, float(l["g"])])
			var lk := String(l["key"])
			if lk.begins_with("a.wrap") or lk.begins_with("p.final"):
				spoil_bad.append("game %d: an end line before the end (%s)" % [i, lk])
			# repeats and first words
			var tx := String(l["text"])
			if seen.has(tx) and float(l["s0"]) - float(seen[tx]) <= float(P["repeat_s"]):
				rep_bad.append("game %d: repeated within 120 s: %s" % [i, tx])
			seen[tx] = float(l["s0"])
			var fw := tx.split(" ", false)[0].to_lower()
			if fw == last_first:
				rep_bad.append("game %d: same first word twice: %s" % [i, tx])
			last_first = fw
			# word range of the template
			var tpl := _template(lk, tx)
			var rg: Array = P["words"][String(ArenaCast.KEY_TIER.get(lk, "calm"))]
			var nw := ArenaCast.words(tpl)
			if nw < int(rg[0]) or nw > int(rg[1]):
				word_bad.append("%s: %d words" % [lk, nw])
		if end_s - prev_end > float(P["silence_s"][prev_tier]) + 0.01:
			silence_ok = false
			if worst_gap == "":
				worst_gap = "game %d: %.1f s silent at the end" % [i, end_s - prev_end]
		cov_sum += covered / maxf(1.0, end_s)
		for l in c.end_lines:
			for cl in l["claims"]:
				var res2 := _true(pl, cl as Array)
				if res2 != "":
					truth_bad.append("game %d end %s: %s" % [i, l["key"], res2])
	ok(silence_ok, "silence: longest gap within the tier's limit in all %d games %s" % [GAMES, worst_gap])
	var cov := cov_sum / float(GAMES)
	ok(cov >= 0.90, "coverage: a line is on screen %.1f%% of show time (at least 90%%)" % (100.0 * cov))
	ok(truth_bad.is_empty(), "truth: every claim holds in the log (%d lines; %d bad) %s" % [n_lines, truth_bad.size(), str(truth_bad.slice(0, 3))])
	ok(spoil_bad.is_empty(), "spoilers: no claim after its line, no end line early %s" % str(spoil_bad.slice(0, 3)))
	ok(rep_bad.is_empty(), "repeats: none within 120 s, no first word twice in a row %s" % str(rep_bad.slice(0, 3)))
	ok(word_bad.is_empty(), "words: every template inside its tier's range %s" % str(word_bad.slice(0, 5)))
	ok(det_ok, "determinism: the same game gives the same broadcast")
	ok(tiers.has("calm") and tiers.has("hot") and tiers.has("peak") and tiers.has("aftermath"), "tiers: lines in calm, hot, peak and aftermath across games %s" % str(tiers))
	ok(keys.size() >= 40, "variety: %d different line kinds used across games" % keys.size())
	print("cast: %.1f lines a game; %s" % [float(n_lines) / float(GAMES), str(tiers)])
	_synthetic()
	await _display(games[0][0], games[0][1])
	_a1()
	print("check_cast: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


static func _template(key: String, text: String) -> String:
	return _match_template(key, text)


## The template a line came from (the one whose slots, filled any way, give the text), else the text.
static func _match_template(key: String, text: String) -> String:
	var i := 1
	while Strings.has_key("arena.cast.%s.%d" % [key, i]):
		var tpl := Strings.t("arena.cast.%s.%d" % [key, i])
		var rx := RegEx.new()
		var pat := "^"
		for part in tpl.split("{"):
			pat += ".+" + _escape(part.get_slice("}", 1)) if part.contains("}") else _escape(part)
		pat += "$"
		if rx.compile(pat) == OK and rx.search(text) != null:
			return tpl
		i += 1
	return text


static func _escape(s: String) -> String:
	var out := ""
	for ch in s:
		out += ("\\" + ch) if ch in ".^$*+?()[]{}|\\" else ch
	return out


# ---------------------------------------------------------------- truth: re-derived from the log, not from ArenaCast
func _lead(pl: ArenaPlayer, g: float) -> int:
	var sc := pl.score(g)
	return int(sc["gold"]["B"]) - int(sc["gold"]["R"])


static func _claim_t(cl: Array) -> float:
	match String(cl[0]):
		"fight_more", "draft", "matchup", "late_lean", "close", "end":
			return -INF
	var v: Variant = cl[-1]
	return float(v) if (v is float or v is int) else -INF


func _true(pl: ArenaPlayer, cl: Array) -> String:
	var kind := String(cl[0])
	match kind:
		"kill":
			for k in pl.kills:
				if absf(float(k[0]) - float(cl[3])) < 1e-4 and String(k[1]) == String(cl[1]) and String(k[2]) == String(cl[2]):
					return ""
			return "no such kill"
		"first_kill":
			for k in pl.kills:
				if float(k[0]) < float(cl[1]) - 1e-4 and not String(k[1]).begins_with("tower."):
					return "an earlier hero kill"
			return ""
		"multi":
			var n := 0
			var last := float(cl[3])
			for i in range(pl.kills.size() - 1, -1, -1):
				var k: Array = pl.kills[i]
				if float(k[0]) > float(cl[3]) + 1e-4 or String(k[1]) != String(cl[1]):
					continue
				if last - float(k[0]) > float(ArenaCast.params()["multi_kill_s"]) + 1e-4:
					break
				n += 1
				last = float(k[0])
			return "" if n >= int(cl[2]) else "only %d kills in the chain" % n
		"streak":
			var n2 := 0
			for k in pl.kills:
				if float(k[0]) > float(cl[3]) + 1e-4:
					break
				if String(k[2]) == String(cl[1]):
					n2 = 0
				elif String(k[1]) == String(cl[1]):
					n2 += 1
			return "" if n2 >= int(cl[2]) else "streak %d" % n2
		"wipe":
			for s in ["top", "jg", "mid", "bot", "sup"]:
				if pl.alive(String(cl[1]) + "." + s, float(cl[2]) + 0.01):
					return "not all dead"
			return ""
		"fight":
			for f in pl.fights:
				if int(f["id"]) == int(cl[1]) and absf(float(f["t0"]) - float(cl[2])) < 1e-4:
					return ""
			return "no such fight"
		"fight_more":
			for f in pl.fights:
				if int(f["id"]) == int(cl[1]):
					var n3 := {"B": 0, "R": 0}
					for k in f["keys"]:
						n3[ArenaPlayer.side_of(String(k))] += 1
					return "" if int(n3[String(cl[2])]) >= int(n3["R" if String(cl[2]) == "B" else "B"]) else "fewer heroes"
			return "no such fight"
		"fight_end":
			for f in pl.fights:
				if int(f["id"]) == int(cl[1]):
					var kd := {"B": 0, "R": 0}
					for k in pl.kills:
						if float(k[0]) >= float(f["t0"]) - 0.5 and float(k[0]) <= float(f["t1"]) + 0.5 and String(k[2]) in f["keys"] and not String(k[1]).begins_with("tower."):
							kd[ArenaPlayer.side_of(String(k[1]))] += 1
					var won := "B" if int(kd["B"]) > int(kd["R"]) else ("R" if int(kd["R"]) > int(kd["B"]) else "")
					return "" if won == String(cl[2]) and int(kd["B"]) == int(cl[3]) and int(kd["R"]) == int(cl[4]) else "outcome differs"
			return "no such fight"
		"obj":
			for o in pl.objs:
				if absf(float(o[0]) - float(cl[3])) < 1e-4 and String(o[1]) == String(cl[1]) and String(o[2]) == String(cl[2]):
					return ""
			return "no such take"
		"obj_up":
			return "" if pl.objective(String(cl[1]), float(cl[2]) + 0.01) == "up" else "not up"
		"call":
			for x in pl.calls:
				if absf(float(x[0]) - float(cl[3])) < 1e-4 and String(x[1]) == String(cl[1]) and String(x[2]) == "group" and String(x[3]) == String(cl[2]):
					return ""
			return "no such call"
		"tower":
			for x in pl.towers:
				if absf(float(x[0]) - float(cl[3])) < 1e-4 and String(x[1]) == String(cl[1]) and String(x[2]) == String(cl[2]):
					return ""
			return "no such tower"
		"base_race":
			return ""
		"lead":
			var l := _lead(pl, float(cl[3]))
			var v := l if String(cl[1]) == "B" else -l
			return "" if v >= int(cl[2]) else "lead %d" % v
		"led_before", "was_behind":
			var g := 0.0
			while g <= float(cl[3]):
				var l2 := _lead(pl, g)
				var v2 := l2 if String(cl[1]) == "B" else -l2
				if (kind == "led_before" and v2 >= int(cl[2])) or (kind == "was_behind" and -v2 >= int(cl[2])):
					return ""
				g += 5.0
			return "never"
		"swing":
			var d := _lead(pl, float(cl[3])) - _lead(pl, float(cl[3]) - float(ArenaCast.params()["swing_window_s"]))
			var dv := d if String(cl[1]) == "B" else -d
			return "" if absi(dv - int(cl[2])) <= 50 else "swing %d" % dv
		"gold_value":
			var l3 := _lead(pl, float(cl[3]))
			var v3 := l3 if String(cl[1]) == "B" else -l3
			return "" if v3 > 0 and absi(v3 - int(cl[2])) <= 1 else "lead %d" % v3
		"even":
			return "" if absi(_lead(pl, float(cl[2]))) < int(cl[1]) else "not even"
		"buy", "recall", "intent", "ward", "plan":
			var want: String = kind
			for e in pl.log["ev"]:
				if String(e[1]) == want and absf(float(e[0]) - float(cl[-1])) < 1e-4 and String(e[2]) == String(cl[1]):
					return ""
			return "no such %s" % kind
		"base_open":
			for x in pl.towers:
				var id := String(x[1])
				if float(x[0]) <= float(cl[2]) + 1e-4 and not id.ends_with("cairn") and id.get_slice(".", 2) != "outer":
					return ""
			return "base not open"
		"end":
			return "" if String(cl[1]) == pl.winner else "wrong winner"
		"close":
			return "" if absi(_lead(pl, float(cl[2]))) < int(cl[1]) else "not close"
		"draft", "matchup", "late_lean":
			return ""
	return "unknown claim " + kind


# ---------------------------------------------------------------- synthetic logs: the tiers follow the game
func _fake(ev: Array, gold_b: Array, gold_r: Array, len_s: float = 1200.0) -> ArenaPlayer:
	var heroes := SimData.heroes().keys()
	var per := {}
	var track := {}
	var i := 0
	for sd in ["B", "R"]:
		for s in ["top", "jg", "mid", "bot", "sup"]:
			var key: String = sd + "." + s
			per[key] = {"hero": String(heroes[i % heroes.size()])}
			var tr := PackedFloat32Array()
			for k in int(len_s / 2.0) + 1:
				tr.append_array([0.3 + 0.04 * float(i % 5), 0.5, 1.0, 1.0])
			track[key] = tr
			i += 1
	var gb := PackedFloat32Array(gold_b)
	var gr := PackedFloat32Array(gold_r)
	var res := {"blue_won": true, "sim": {"per": per, "log": {"v": 2, "len_s": len_s, "ev": ev + [[len_s, "end"]], "track": track,
			"fronts": {"top": PackedFloat32Array(), "mid": PackedFloat32Array(), "bot": PackedFloat32Array()},
			"gold": {"B": gb, "R": gr}, "track_every": 2.0}}}
	return ArenaPlayer.build(res, "B")


func _even_gold(len_s: float, lead_fn: Callable) -> Array:
	var b: Array = []
	var r: Array = []
	var g := 0.0
	while g <= len_s:
		var base := 20.0 * g
		b.append(base + float(lead_fn.call(g)) / 2.0)
		r.append(base - float(lead_fn.call(g)) / 2.0)
		g += 2.0
	return [b, r]


func _max_e(c: ArenaCast, s0: float = 0.0, s1: float = INF) -> float:
	var m := 0.0
	for i in c.e_grid.size():
		var s := float(i) * float(ArenaCast.params()["grid_s"])
		if s >= s0 and s <= s1:
			m = maxf(m, c.e_grid[i])
	return m


func _synthetic() -> void:
	var flat := _even_gold(1200.0, func(_g: float) -> float: return 0.0)
	var quiet := ArenaCast.build(_fake([], flat[0], flat[1]), "synthetic-quiet", {"B": "Blue", "R": "Red"})
	var all_calm := true
	for l in quiet.lines:
		all_calm = all_calm and quiet.tier_at(float(l["s0"])) == "calm"
	ok(_max_e(quiet) < 0.20 and all_calm, "tiers: a quiet game stays calm (e max %.2f, %d lines)" % [_max_e(quiet), quiet.lines.size()])
	var keys := ["B.top", "B.jg", "B.mid", "B.bot", "B.sup", "R.top", "R.jg", "R.mid", "R.bot", "R.sup"]
	var ev: Array = [[600.0, "fight", 1, "teamfight", keys]]
	for k in 5:
		ev.append([601.0 + float(k) * 0.8, "kill", "B.mid", ["R.top", "R.jg", "R.mid", "R.bot", "R.sup"][k], []])
	ev.append([606.0, "fight_end", 1])
	var big := ArenaCast.build(_fake(ev, flat[0], flat[1]), "synthetic-fight", {"B": "Blue", "R": "Red"})
	ok(_max_e(big) >= 0.75, "tiers: a five-kill fight reaches peak (e max %.2f)" % _max_e(big))
	var flip := _even_gold(1200.0, func(g: float) -> float: return 2500.0 if g < 600.0 else -2500.0)
	var fl := ArenaCast.build(_fake([], flip[0], flip[1]), "synthetic-flip", {"B": "Blue", "R": "Red"})
	var s_flip := fl.pl.show_t(600.0)
	ok(_max_e(fl, s_flip - 1.0, s_flip + 12.0) > _max_e(quiet) + 0.2, "tiers: a lead flip raises e (%.2f near the flip)" % _max_e(fl, s_flip - 1.0, s_flip + 12.0))


# ---------------------------------------------------------------- display: type size and lines
func _display(pl: ArenaPlayer, c: ArenaCast) -> void:
	for large in [false, true]:
		App.apply_large_text(large)
		var n := ArenaHud2.Notes.new(pl)
		n.cast = c
		n.size = Vector2(672, 110)
		add_child(n)
		var worst_px := 99
		var most := 0
		var peak_px := 0
		for l in c.intro + c.lines:
			if l in c.intro:
				n.intro = l
			else:
				n.intro = {}
			n.show_at(pl.game_t(float(l.get("s0", 0.0)) + 0.01), float(l.get("s0", 0.0)) + 0.01, 1.0)
			await get_tree().process_frame
			if n.line_count > 0:
				worst_px = mini(worst_px, n.px)
				most = maxi(most, n.line_count)
				if String(l["tier"]) == "peak":
					peak_px = maxi(peak_px, n.px)
		ok(worst_px >= 26 and most <= 3 and n.cut_count == 0, "display (%s): commentary at %d px or more, at most %d lines (3 allowed), %d cut" % ["large" if large else "normal", worst_px, most, n.cut_count])
		if not large:
			ok(peak_px == 0 or peak_px >= 32, "display: a peak line at 32 px (%d)" % peak_px)
		n.queue_free()
	App.apply_large_text(false)


func _a1() -> void:
	var bad: Array = []
	var dirs := ["res://src/arena", "res://src/arena/v2"]
	for d in dirs:
		var da := DirAccess.open(d)
		if da == null:
			continue
		for f in da.get_files():
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(d + "/" + f)
			for word in ["MatchSim.", "MatchSimV2.", "GamePlan.simulate", "Report.attribution"]:
				if src.contains(word):
					bad.append("%s: %s" % [f, word])
	ok(bad.is_empty(), "A1: nothing in src/arena calls the simulation %s" % str(bad))
