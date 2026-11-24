extends RefCounted
## "Why your Form Rating moved" (0.12, ESMO Q4-4): GameState keeps the real parts of the managed club's last rated change
## (additive key rate_last) and they rebuild the change exactly: K x importance x (result - expected).

const CLUB := "ironquill_wolves"


func _rebuilt(rl: Dictionary) -> float:
	return FormRating.K * float(rl["imp"]) * ((1.0 if bool(rl["won"]) else 0.0) - float(rl["e"]))


func run(check: Callable) -> void:
	var w := World.load_default()
	var gs := GameState.new_game(w, CLUB, 71201)
	check.call(not gs.d.has("rate_last"), "rate why: a new game has no last change yet")
	var g := gs.next_game()
	var before := gs.form_rating(CLUB)
	gs.record_human_game(g, gs.auto_game(g))
	var rl: Dictionary = gs.d.get("rate_last", {})
	check.call(not rl.is_empty() and String(rl["game"]) == String(g["id"]), "rate why: our league game is kept (%s)" % str(rl.get("game", "")))
	check.call(is_equal_approx(float(rl.get("before", -1.0)), before), "rate why: the rating before is the real one")
	check.call(absf(gs.form_rating(CLUB) - before - float(rl.get("delta", 0.0))) < 1e-6, "rate why: the stored change is the real change")
	check.call(absf(_rebuilt(rl) - float(rl.get("delta", 0.0))) < 1e-6, "rate why: the parts rebuild the change exactly")
	check.call(float(rl["imp"]) == 1.0 and int(rl["best_of"]) == 1 and String(rl["stage"]) == "league", "rate why: a league game has weight 1, best of 1")
	# a whole season with playoffs: the last kept change still rebuilds, and the key survives a save round trip
	gs.autoplay(true)
	var rl2: Dictionary = gs.d.get("rate_last", {})
	check.call(absf(_rebuilt(rl2) - float(rl2.get("delta", 0.0))) < 1e-6, "rate why: the season's last kept change rebuilds (%s)" % str(rl2.get("stage", "")))
	var gs2 := GameState.from_dict(w, JSON.parse_string(JSON.stringify(gs.d)))
	check.call(gs2 != null and (gs2.d.get("rate_last", {}) as Dictionary).has("delta"), "rate why: the key survives a save round trip")
