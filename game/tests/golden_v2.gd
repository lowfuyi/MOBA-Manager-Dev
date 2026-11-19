class_name GoldenV2
extends RefCounted
## Match Sim v2 golden vectors (MATCH-SIM-V2-DESIGN 9.2): 24 fixed cases from synthetic teams (no league data), each pinned by
## its winner, length, kills, gold, towers and the sha256 of the canonical event log. `tests/gen_golden_v2.tscn` writes
## tests/golden/sim_v2_vectors.json; sim_v2_tests checks the simulator reproduces every case exactly. Regenerate only in an
## increment that changes v2 behaviour on purpose, with the reason logged (check_fast.sh's golden hash changes with it).

const SLOTS := ["top", "jg", "mid", "bot", "sup"]
const PICKS := [
	{"top": "brannoch", "jg": "gravenstone", "mid": "ellowen", "bot": "harkin", "sup": "sunnivah"},
	{"top": "dunmarrow", "jg": "marrek", "mid": "cindrel", "bot": "pellam", "sup": "alderwyn"},
	{"top": "skarrow", "jg": "nimbrel", "mid": "dusken", "bot": "tamsel", "sup": "bastrel"},
	{"top": "ottomere", "jg": "quillith", "mid": "tessarine", "bot": "brixley", "sup": "corvane"},
]


static func team(r: float, con: float, comp: float, style: String, lm: float) -> Dictionary:
	var ratings := {}
	for ph in ["early", "mid", "late"]:
		var x := {}
		for s in SLOTS:
			x[s] = r
		ratings[ph] = x
	var lane_mod := {}
	if lm != 0.0:
		lane_mod = {"top": lm, "mid": lm, "bot": lm, "jg": lm}
	return {"ratings": ratings, "con": con, "team_mod": 0.0, "comp_mod": comp, "lane_mod": lane_mod, "style": style}


## The 24 cases: [id, team A args, team B args, picks A, picks B, plan control for A or "", value, build edit, seed]
static func cases() -> Array:
	var out: Array = []
	var ctl := ["", "g", "t", "m", "l", "a", "s", "r"]
	for i in 24:
		var gap: float = [0.0, 5.0, 10.0, 20.0][i % 4]
		var con: float = [50.0, 20.0, 80.0][i % 3]
		var comp := 0.08 if i % 5 == 0 else 0.0
		var style: String = ["skirmish", "dive", "siege", "protect"][i % 4]
		var style_b: String = ["skirmish", "siege", "protect", "dive"][(i / 4) % 4]
		var lm := 0.10 if i % 6 == 1 else 0.0
		var c: String = ctl[i % ctl.size()]
		var v := 100 if i % 2 == 0 else -100
		out.append({"id": "g%02d" % i, "a": [50.0 + gap, con, comp, style, lm], "b": [50.0, con, 0.0, style_b, 0.0],
				"pa": i % 4, "pb": (i + 1) % 4, "ctl": c, "val": v, "edit": i % 7 == 3, "seed": 424242 + 7919 * i})
	return out


static func run_case(c: Dictionary) -> Dictionary:
	var a: Array = c["a"]
	var b: Array = c["b"]
	var ta := team(a[0], a[1], a[2], a[3], a[4])
	var tb := team(b[0], b[1], b[2], b[3], b[4])
	var player := {"id": "p", "stats": {"mec": 62, "sen": 58, "lan": 61, "tft": 57, "mac": 60, "com": 55, "con": 60, "clu": 59}}
	var ctx := {"picks": {"B": PICKS[int(c["pa"])], "R": PICKS[int(c["pb"])]}, "players": {"B": {}, "R": {}}, "builds": {"B": {}, "R": {}}, "bonds": {"B": 55.0, "R": 50.0}}
	for s in SLOTS:
		ctx["players"]["B"][s] = player
		ctx["players"]["R"][s] = player
	if bool(c["edit"]):
		ctx["builds"]["B"]["bot"] = ["racing_spurs", "ninefold_quiver", "gloamcutter", "marrow_drinker", "shalehewer", "duskward_sabre"]
	var sets := {}
	if String(c["ctl"]) != "":
		var pl := GamePlan.neutral()
		pl[String(c["ctl"])] = int(c["val"])
		sets["B"] = {"default": pl, "triggers": []}
	var r := MatchSimV2.simulate(ta, tb, int(c["seed"]), sets, ctx)
	return {"id": c["id"], "blue_won": bool(r["a_won"]), "len_s": float(r["len_s"]), "kills": r["team_kills"], "gold": r["gold"],
			"towers": r["towers"], "log_sha256": JSON.stringify(r["log"]["ev"]).sha256_text(), "events": (r["log"]["ev"] as Array).size()}
