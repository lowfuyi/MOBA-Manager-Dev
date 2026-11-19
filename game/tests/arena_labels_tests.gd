extends RefCounted
## Match Sim v2 interim (2026-11-19): this tests the Alpha 0.8 show, so its results come from MatchRunner.auto_v1 (the v1 contest
## model the show was built for) until Arena v2 replaces the show with event-log playback (Phase 4).
## Alpha 0.8 A-07: the arena's words (ArenaLabels) on real results, both seats, normal and large text (UI-PASS-2 6.7.10, ACTION-
## VOCABULARY 4.1):
##   budget   at most 10 new words in any 2.5 s span; at most 3 transient items at once (pair, tag, feed block; 1 under a banner);
##            no feed line dropped except the one a wipe banner replaces
##   R1       every label is 28 characters or fewer after its fills, every tag 24 or fewer; no "{" left
##   R3/large one label per side per window; large text never shows theirs
##   R4       the same result gives the same words; a pair never repeats its previous variant
##   R5       a plan label shows only when its control is non-zero in the plan in force
##   HF5      in a held fight the winner shows push_lead, never push_base; no flip tag at fight_late
##   chip     the plan chip has 1 to 3 parts, "Plan: neutral" only for a neutral plan

const N := 300
const PLAN_LABELS := {"lane_aggr": "a", "lane_safe": "a", "lane_roam": "s", "lane_stay": "s", "rot_group": "g", "rot_split": "g",
		"tempo_scale": "t", "tempo_push": "t", "fight_risk": "r", "fight_safe": "r", "fight_group": "g"}


func run(check: Callable) -> void:
	Strings.load_language("en")    # a --script run has not run the autoload's _ready yet: without this every key is missing
	var w := World.load_default()
	var meta := w.make_meta("labels-test")
	var fails := {}
	var worst_words := 0
	var shown_both := 0
	var windows := 0
	var held_seen := 0
	var comments_total := 0
	for i in N:
		var a: String = w.club_ids[i % w.club_ids.size()]
		var b: String = w.club_ids[(i * 5 + 3) % w.club_ids.size()]
		if a == b:
			b = w.club_ids[(i + 1) % w.club_ids.size()]
		var plans := {"B": "ai", "R": "ai"}
		if i % 3 == 1:    # a set with a trigger plan and some sliders, so plan labels and switches occur
			var dflt := GamePlan.neutral()
			dflt["a"] = 60
			dflt["g"] = -40
			var behind := GamePlan.neutral()
			behind["r"] = 80
			plans = {"B": {"default": dflt, "triggers": [{"when": "behind_early", "plan": behind}]}, "R": "ai"}
		var res := MatchRunner.auto_v1(w, w.best_lineup(a), w.best_lineup(b), meta, 6100 + i, "labels:%d" % i, false, plans)
		for large in [false, true]:
			var me := "B" if (i + int(large)) % 2 == 0 else "R"
			var s := ShowScript.build(res, me)
			var l := ArenaLabels.build(s, large)
			held_seen += 1 if s.held and not large else 0
			worst_words = maxi(worst_words, l.max_words())
			if l.max_words() > ArenaLabels.WORDS:
				fails["budget"] = int(fails.get("budget", 0)) + 1
			var feeds := 0
			var wipes := 0
			for it in l.admitted:
				feeds += 1 if String(it["kind"]) == "feed" else 0
				wipes += 1 if String(it["kind"]) == "banner" and String(it.get("id", "")) == "wipe" else 0
			if feeds + wipes < 8:
				fails["feed kept"] = int(fails.get("feed kept", 0)) + 1
			# commentary (Alpha 0.8.2): at most 2 a game, none in large text, 8 words or fewer, in its slot, never under a banner
			var said := 0
			for it3 in l.admitted:
				if String(it3["kind"]) != "comment":
					continue
				said += 1
				var okc := ArenaLabels.word_count(String(it3["text"])) <= 8 and [26.75, 39.5, 47.5, 66.0, 71.6].has(float(it3["t"]))
				okc = okc and not l._under_banner(float(it3["t"]), float(it3["until"])) and not String(it3["text"]).begins_with("arena.")
				if String(it3["id"]).begins_with("held") and not s.held:
					okc = false
				if not okc:
					fails["comment"] = int(fails.get("comment", 0)) + 1
			comments_total += said
			if said > ArenaLabels.COMMENTS or (large and said > 0):
				fails["comment"] = int(fails.get("comment", 0)) + 1
			var t := 0.0
			while t < 75.0:
				var now := l.at(t)
				var n := 1 + (1 if not (now["pair"] as Dictionary).is_empty() else 0) + (1 if not (now["tag"] as Dictionary).is_empty() else 0)
				if n > 3 or (not (now["banner"] as Dictionary).is_empty() and not (now["pair"] as Dictionary).is_empty()):
					fails["items at once"] = int(fails.get("items at once", 0)) + 1
					break
				t += 0.25
			for it2 in l.items:
				if String(it2["kind"]) == "pair":
					for side in ["you", "them"]:
						var lab: Dictionary = it2[side]
						if lab.is_empty():
							continue
						var tx := String(lab["text"])
						if UI.plain(tx).length() > 28 or tx.contains("{"):
							fails["R1"] = int(fails.get("R1", 0)) + 1
						if PLAN_LABELS.has(String(lab["id"])):
							var who := me if side == "you" else ShowScript.other(me)
							var after := float(it2["t"]) >= 21.0
							var plan := l.plan_of(who, after)
							if int(plan.get(PLAN_LABELS[lab["id"]], 0)) == 0:
								fails["R5"] = int(fails.get("R5", 0)) + 1
					if large and not (it2["them"] as Dictionary).is_empty():
						fails["large"] = int(fails.get("large", 0)) + 1
				elif String(it2["kind"]) == "tag" and (UI.plain(String(it2["text"])).length() > 24 or String(it2["text"]).contains("{")):
					fails["R1"] = int(fails.get("R1", 0)) + 1
			for ad in l.admitted:
				if String(ad["kind"]) == "pair" and not large:
					windows += 1
					shown_both += 1 if String(ad["show"]) == "both" else 0
			if s.held:
				for it3 in l.items:
					if String(it3["kind"]) == "pair" and String(it3["window"]) == "close":
						var wl: Dictionary = it3["you"] if s.winner == me else it3["them"]
						if not wl.is_empty() and String(wl["id"]) != "push_lead":
							fails["HF5"] = int(fails.get("HF5", 0)) + 1
					if String(it3["kind"]) == "tag" and float(it3["t"]) == float(ShowScript.RESOLVE["fight_late"]) and (String(it3["id"]) == "tag_flip" or String(it3["id"]) == "tag_back"):
						fails["HF5"] = int(fails.get("HF5", 0)) + 1
			var parts := l.plan_parts(10.0)
			if parts.is_empty() or parts.size() > 3 or (parts[0] == Strings.t("arena.plan.neutral") and not GamePlan.is_neutral(l.plan_of(me, false))):
				fails["chip"] = int(fails.get("chip", 0)) + 1
			if i < 20:
				var l2 := ArenaLabels.build(ShowScript.build(res, me), large)
				if JSON.stringify(l2.admitted) != JSON.stringify(l.admitted):
					fails["R4"] = int(fails.get("R4", 0)) + 1
	print("     arena labels: %d results x 2; worst %d new words in 2.5 s; both labels in %d of %d admitted windows; held games %d" % [N, worst_words, shown_both, windows, held_seen])
	for name in ["budget", "feed kept", "items at once", "R1", "R5", "large", "HF5", "chip", "R4", "comment"]:
		check.call(not fails.has(name), "arena labels %s holds (%d failures)" % [name, int(fails.get(name, 0))])
	check.call(windows > 0 and float(shown_both) / float(windows) >= 0.4, "the budget still leaves both labels in a fair share of windows (%d of %d)" % [shown_both, windows])
	check.call(held_seen > 0, "the sample has held fights (%d)" % held_seen)
	check.call(comments_total >= N / 2, "commentary lines are admitted in the normal layout (%d over %d shows)" % [comments_total, N])
	_variants(check)


## R4: the k-th use of a pair draws the k-th value and never repeats the previous variant of that pair.
func _variants(check: Callable) -> void:
	var w := World.load_default()
	var res := MatchRunner.auto_v1(w, w.best_lineup(w.club_ids[0]), w.best_lineup(w.club_ids[1]), w.make_meta("v"), 11, "v:1", false, {"B": "ai", "R": "ai"})
	var l := ArenaLabels.new()
	l.s = ShowScript.build(res, "B")
	var prev := -1
	var ok := true
	for k in 40:
		var v := l._variant("rot_late", "B")
		ok = ok and v >= 1 and v <= 3 and v != prev
		prev = v
	check.call(ok, "R4: a pair's variants are 1 to 3 and never the same twice in a row")
