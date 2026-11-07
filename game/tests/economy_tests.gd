class_name EconomyTests
extends RefCounted
## Contracts, wages, negotiation, cash and sponsors (GDD 7.2, 7.6). The long-run "nobody goes bankrupt,
## nobody snowballs" check is statistical and lives in tools/econ_qa.gd.

func run(check: Callable) -> void:
	var w := World.load_default()
	var e := Economy.data()

	# ---- asking wage
	var fa: Array = w.orig_free_agents()
	check.call(fa.size() == 40, "forty free agents at the start")
	var lo := 1.0e9
	var hi := 0.0
	for pid in fa:
		var a := Economy.asking_wage(w, w.players[pid])
		lo = minf(lo, a)
		hi = maxf(hi, a)
	check.call(lo >= 20.0 and hi <= 80.0, "free agents ask 20 to 80 a week (%d..%d)" % [lo, hi])
	var strong_ask := 0
	for pid in w.orig_ids("saltmarrow_gulls"):
		strong_ask = maxi(strong_ask, Economy.asking_wage(w, w.players[pid]))
	check.call(strong_ask > hi, "a club's best player asks more than any free agent (%d vs %d)" % [strong_ask, hi])

	# ---- the response ladder: more money never makes it worse, and the hidden threshold is stable
	var p: Dictionary = w.players[fa[0]]
	var order := {"far": 0, "below": 1, "close": 2, "accept": 3}
	var last := -1
	var monotone := true
	for wage in range(5, 200, 3):
		var r: int = order[Economy.response(w, p, wage, 2)]
		monotone = monotone and r >= last
		last = r
	check.call(monotone and last == 3, "a higher offer never gets a worse answer; a big one is accepted")
	check.call(Economy.required_wage(w, p, 2) == Economy.required_wage(w, p, 2), "the hidden threshold does not change between asks")
	check.call(Economy.required_wage(w, p, 4) < Economy.required_wage(w, p, 1), "a longer deal is slightly cheaper")
	var req2 := Economy.required_wage(w, p, 2)
	check.call(Economy.response(w, p, int(ceil(req2)), 2) == "accept" and Economy.response(w, p, int(req2 * 0.5), 2) == "far", "accept at the threshold, far when half of it")

	# ---- a new game: contracts, cash, sponsor
	var club: String = w.club_ids[4]
	var gs := GameState.new_game(w, club, 777)
	check.call((gs.d["roster"] as Array).size() == 10 and (gs.d["contracts"] as Dictionary).size() == 10, "ten players, ten contracts")
	var all_len := true
	for pid in gs.d["roster"]:
		var l := int(gs.contract_of(pid)["left"])
		all_len = all_len and l >= 1 and l <= 3
	check.call(all_len, "starting contracts run one to three seasons")
	check.call(absf(gs.cash() - (float(e["start_balance_weeks"]) * gs.wage_bill() + float(gs.sponsor_offer("steady")["bonus_weeks"]) * gs.revenue_base())) < 0.5, "start cash is eight weeks of wages plus the sponsor bonus")
	check.call(gs.wage_bill() <= gs.wage_cap(), "the default roster is under the wage cap")
	check.call(gs.weekly_net() > -0.01, "the default sponsor covers the default wage bill")

	# every club's economy has the same shape
	for c in w.club_ids:
		var g2 := GameState.new_game(w, c, 5)
		check.call(g2.weekly_net() > -0.01 and g2.wage_bill() <= g2.wage_cap(), "balanced economy for " + c)
	gs = GameState.new_game(w, club, 777)

	# ---- signing a free agent
	var target := ""
	for pid in gs.d["fa"]:
		target = pid
		break
	var ask := gs.asking_wage(target)
	# the roster is full: no signing
	check.call(gs.offer(target, 300, 2)["code"] == "full", "a full roster cannot sign anybody")
	# release one, then sign
	var cut: String = gs.d["roster"][9]
	var cash0 := gs.cash()
	var cost := gs.release_cost(cut)
	check.call(cost > 0.0 and gs.release(cut) == "", "release works and costs money (%.0f)" % cost)
	check.call(absf(gs.cash() - (cash0 - cost)) < 0.01, "release cost leaves the cash")
	check.call((gs.d["fa"] as Array).has(cut) and not (gs.d["roster"] as Array).has(cut), "released player is a free agent")
	check.call(gs.offer(cut, 300, 2)["code"] == "locked", "a released player will not talk straight away")
	var wage_bill0 := gs.wage_bill()
	var res := gs.offer(target, 1, 2)
	check.call(res["code"] == "far" and res["rounds_left"] == 2, "a silly offer is 'far' and uses a round")
	var big := int(ceil(Economy.required_wage(w, w.players[target], 2))) + 1
	var cash1 := gs.cash()
	res = gs.offer(target, big, 2)
	check.call(res["code"] == "accepted", "an offer over the threshold is accepted (%s)" % res["code"])
	check.call((gs.d["roster"] as Array).has(target) and int(gs.contract_of(target)["left"]) == 2 and int(gs.contract_of(target)["wage"]) == big, "contract recorded")
	check.call(absf(gs.cash() - (cash1 - 2.0 * big)) < 0.01, "signing fee is two weeks of wages")
	check.call(absf(gs.wage_bill() - (wage_bill0 + big)) < 0.01, "wage bill grows by the new wage")
	check.call(not (gs.d["fa"] as Array).has(target) and w.fa_ids.has(target) == false, "he left the free-agent pool (also in the world)")
	check.call(w.clubs[club]["player_ids"].has(target), "world roster follows")
	# lineup stays valid when a starter is released
	var starter: String = gs.d["lineup"]["mid"]
	var sc := gs.release(starter)
	if sc == "":
		var valid := true
		for s in GameState.SLOTS:
			valid = valid and (gs.d["roster"] as Array).has(gs.d["lineup"][s])
		var uniq := {}
		for s in GameState.SLOTS:
			uniq[gs.d["lineup"][s]] = true
		check.call(valid and uniq.size() == 5, "lineup repaired after releasing a starter")
	else:
		check.call(sc == "cash", "release refused only for cash (%s)" % sc)

	# ---- negotiation limits: three rounds, then a lockout; temperamental walks after two
	var g3 := GameState.new_game(w, club, 778)
	var cut2: String = g3.d["roster"][9]
	g3.d["cash"] = 1.0e6
	g3.release(cut2)
	var rounds_ok := true
	var code := ""
	var cand := ""
	var temper := ""
	var calm := ""
	for pid in g3.d["fa"]:
		if pid == cut2:
			continue
		if w.players[pid]["personality"] == "temperamental" and temper == "":
			temper = pid
		elif w.players[pid]["personality"] != "temperamental" and calm == "":
			calm = pid
	if calm != "":
		for i in 3:
			code = g3.offer(calm, 1, 2)["code"]
		check.call(code == "walked" and g3.lockout_left(calm) > 0, "three bad offers end the talks")
		check.call(g3.offer(calm, 500, 2)["code"] == "locked", "locked out even for a big offer")
		for i in int(e["lockout_rounds"]):
			g3.d["clock"] = int(g3.d["clock"]) + 1
		var fair := int(ceil(Economy.required_wage(w, w.players[calm], 2))) + 1
		check.call(g3.offer(calm, fair, 2)["code"] == "accepted", "talks resume after the lockout")
	if temper != "":
		g3.release(g3.d["roster"][8])
		g3.offer(temper, 1, 2)
		var r2 := g3.offer(temper, 1, 2)
		check.call(r2["code"] == "walked", "a temperamental player walks after the second refusal")
	else:
		check.call(true, "no temperamental free agent in this pool")

	# ---- cap and cash blocks
	var g4 := GameState.new_game(w, club, 779)
	g4.release(g4.d["roster"][9])
	var tgt: String = ""
	for pid in g4.d["fa"]:
		if pid != g4.d["roster"][0]:
			tgt = pid
	g4.d["lock"] = {}
	g4.d["cash"] = 5.0
	check.call(g4.offer(tgt, 400, 2)["code"] == "cash", "not enough cash for the signing fee blocks the offer")
	g4.d["cash"] = 1.0e6
	check.call(g4.offer(tgt, int(g4.wage_cap()), 2)["code"] == "cap", "an offer over the wage cap is blocked")
	g4.d["cash"] = -10.0
	check.call(g4.offer(tgt, 30, 2)["code"] == "cash", "a negative balance blocks signings")
	# minimum squad
	var g5 := GameState.new_game(w, club, 780)
	g5.d["cash"] = 1.0e7
	var released := 0
	for i in 8:
		var pid: String = g5.d["roster"][g5.d["roster"].size() - 1]
		if g5.release(pid) == "":
			released += 1
	check.call((g5.d["roster"] as Array).size() == int(e["min_roster"]) and released == 10 - int(e["min_roster"]), "the squad cannot shrink below six")

	# ---- a season of cash: wages and retainer every round, prizes at the end
	var g6 := GameState.new_game(w, club, 781)
	var c0 := g6.cash()
	var wb := g6.wage_bill()
	g6.autoplay(false)  # whole league
	var rounds := g6.total_rounds()
	var wages_paid := 0.0
	var retainer := 0.0
	var prize := 0.0
	for row in g6.d["ledger"]:
		match row["k"]:
			"wages": wages_paid += float(row["a"])
			"retainer": retainer += float(row["a"])
			"prize_league": prize += float(row["a"])
	check.call(absf(wages_paid + wb * float(rounds) / float(e["rounds_per_week"])) < 5.0, "wages paid every round (%.0f)" % wages_paid)
	check.call(absf(retainer - g6.weekly_income() * float(rounds) / float(e["rounds_per_week"])) < 5.0, "retainer paid every round")
	var rank := g6.rank_of(club)
	var expect_prize := 0.0
	if rank <= (e["league_prize_weeks"] as Array).size():
		expect_prize = float(e["league_prize_weeks"][rank - 1]) * g6.revenue_base()
	check.call(absf(prize - expect_prize) < 1.0, "league prize for rank %d" % rank)
	check.call(absf(g6.cash() - (c0 + wages_paid + retainer + prize + _sum(g6, "sponsor_reward"))) < 2.0, "cash equals the ledger")

	# ---- sponsor choice
	var g7 := GameState.new_game(w, club, 782)
	var before := g7.cash()
	check.call(g7.sponsor_changeable() and g7.set_sponsor("wins"), "sponsor can be swapped before the first game")
	check.call(absf(g7.cash() - (before - 1.5 * g7.revenue_base())) < 0.5, "the signing bonus changes with the offer")
	check.call(g7.weekly_income() < g7.wage_bill() and g7.weekly_net() < 0.0, "the wins sponsor pays less every week")
	g7.autoplay(false)
	check.call(not g7.sponsor_changeable(), "no swapping once games are played")
	# reward is paid exactly when the target is met
	var ob := g7.sponsor_objective()
	check.call(not ob.is_empty() and bool(ob["met"]) == (int(ob["have"]) >= int(ob["target"])), "objective met iff the win target is reached")
	check.call((_sum(g7, "sponsor_reward") > 0.0) == bool(ob["met"]), "reward paid iff met")

	# targets follow club strength: the strongest club is asked for more wins than the weakest
	var strong := GameState.new_game(w, "saltmarrow_gulls", 6)
	var weak := GameState.new_game(w, "duskwater_foxes", 6)
	check.call(strong.strength_rank() == 1 and weak.strength_rank() >= 8, "strength ranks run from strongest to weakest (%d, %d)" % [strong.strength_rank(), weak.strength_rank()])
	check.call(int(strong.d["targets"]["wins"]) >= int(weak.d["targets"]["wins"]) + 5, "win target scales with strength (%d vs %d)" % [strong.d["targets"]["wins"], weak.d["targets"]["wins"]])
	check.call(int(strong.d["targets"]["rank"]) == 2 and int(weak.d["targets"]["rank"]) <= 6 and int(weak.d["targets"]["rank"]) >= 2, "rank target stays between 2nd and 6th")

	# ---- dismissal
	var g8 := GameState.new_game(w, club, 783)
	g8.d["cash"] = -1.0e6
	for i in int(e["dismiss_rounds"]):
		check.call(not g8.is_dismissed(), "not yet dismissed after %d rounds in debt" % i)
		g8._pay_round()
	check.call(g8.is_dismissed(), "dismissed after eight rounds in debt")
	var g9 := GameState.new_game(w, club, 784)
	g9.d["cash"] = -10.0
	for i in 5:
		g9._pay_round()
	g9.d["cash"] = 1.0e6
	g9._pay_round()
	check.call(int(g9.d["neg_rounds"]) == 0 and not g9.is_dismissed(), "being back in credit resets the count")

	# ---- renewal and expiry
	var g10 := GameState.new_game(w, club, 785)
	var exp_ids: Array = []
	for pl in g10.expiring():
		exp_ids.append(pl["id"])
	var keep := ""
	for pid in g10.d["roster"]:
		if int(g10.contract_of(pid)["left"]) > 1:
			keep = pid
	if keep != "":
		check.call(g10.offer(keep, 999, 2, true)["code"] == "bad", "only final-year contracts can be renewed")
	if exp_ids.size() > 0:
		var rid: String = exp_ids[0]
		var need := int(ceil(Economy.required_wage(w, w.players[rid], 3))) + 1
		g10.d["cash"] = 1.0e6
		var old_left := int(g10.contract_of(rid)["left"])
		check.call(g10.offer(rid, need, 3, true)["code"] == "accepted", "renewal accepted at the threshold")
		check.call(int(g10.contract_of(rid)["left"]) == old_left + 3 and int(g10.contract_of(rid)["wage"]) == need, "renewal adds seasons and sets the wage")
		check.call(g10.expiring().size() == exp_ids.size() - 1, "renewed player no longer expires")
	# play the year out; next season drops the expiring and ages the rest
	var g11 := GameState.new_game(w, club, 786)
	var sizes_before := (g11.d["roster"] as Array).size()
	var leaving: Array = []
	for pl in g11.expiring():
		leaving.append(pl["id"])
	var stay := {}
	for pid in g11.d["roster"]:
		stay[pid] = int(g11.contract_of(pid)["left"])
	g11.autoplay(true)
	var cash_end := g11.cash()
	var n := g11.next_season()
	var expected := maxi(int(e["min_roster"]), sizes_before - leaving.size())
	check.call((n.d["roster"] as Array).size() == expected, "expired contracts leave (%d -> %d)" % [sizes_before, (n.d["roster"] as Array).size()])
	var dec_ok := true
	for pid in n.d["roster"]:
		if stay[pid] > 1:
			dec_ok = dec_ok and int(n.contract_of(pid)["left"]) == stay[pid] - 1
	check.call(dec_ok, "contract years count down")
	check.call(n.d["fa"].size() >= 40 - 0 and (n.d["fa"] as Array).size() == 40 + sizes_before - (n.d["roster"] as Array).size(), "leavers join the free-agent pool")
	check.call(absf(n.cash() - (cash_end + 1.5 * n.revenue_base())) < 1.0, "cash carries over plus the new sponsor bonus")
	check.call(absf(n.revenue_base() - g11.revenue_base() * 1.03) < 0.01, "revenue base grows 3 percent a season")
	for s in GameState.SLOTS:
		check.call((n.d["roster"] as Array).has(n.d["lineup"][s]), "lineup valid in the new season: " + s)
	# the world follows the save: bind another game and the first club's roster is the data file's again
	var other: String = w.club_ids[5]
	GameState.new_game(w, other, 1)
	check.call(w.clubs[club]["player_ids"] == w.orig_ids(club), "switching club restores the old roster")

	# ---- saves: JSON round trip keeps the economy; old saves get one
	var g12 := GameState.new_game(w, club, 787)
	g12.release(g12.d["roster"][9])
	var json := JSON.stringify(g12.d)
	var back = JSON.parse_string(json)
	var g13 := GameState.from_dict(w, back)
	check.call(absf(g13.cash() - g12.cash()) < 0.01 and (g13.d["roster"] as Array).size() == 9 and g13.d["contracts"].size() == 9, "round trip keeps cash, roster and contracts")
	var old = JSON.parse_string(JSON.stringify(GameState.new_game(w, club, 788).d))
	for k in ["roster", "fa", "contracts", "cash", "r0", "sponsor", "ledger", "lock", "clock", "neg", "neg_rounds", "dismissed"]:
		old.erase(k)
	var g14 := GameState.from_dict(w, old)
	check.call((g14.d["roster"] as Array).size() == 10 and g14.d["fa"].size() == 40 and g14.cash() > 0.0 and g14.d["contracts"].size() == 10, "an Alpha 0.2 save gets contracts and a balance")


func _sum(g: GameState, kind: String) -> float:
	var t := 0.0
	for row in g.d["ledger"]:
		if row["k"] == kind:
			t += float(row["a"])
	return t
