class_name Economy
extends RefCounted
## Contracts, wages, negotiation and sponsors (GDD 7.2 and 7.6). Pure functions; the cash ledger and the
## rosters live in GameState. Constants: data/economy_v0.json.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = DataLoader.load_json("res://data/economy_v0.json")
	return _data


## Best rating the player has in any slot (BaseRating x fit), the basis of his value.
static func best_slot_rating(w: World, p: Dictionary) -> float:
	var best := 0.0
	for s in World.SLOTS:
		best = maxf(best, w.base_rating(p, s) * w.player_fit(p, s))
	return best


## What he could be at his Potential: the same rating with every stat at its ceiling, in his main role.
static func potential_rating(w: World, p: Dictionary) -> float:
	var wts: Array = World.SLOT_W[p["role_primary"]]
	var total := 0.0
	for i in 5:
		total += float(wts[i]) * maxf(float(p["potential"][World.STATS[i]]), float(p["stats"][World.STATS[i]]))
	return total


## Weekly wage he asks for (GDD 7.2): max(20, 2 x (BestSlotRating - 40)) x PotentialFactor, rounded.
static func asking_wage(w: World, p: Dictionary) -> int:
	var a: Dictionary = data()["ask"]
	var mean_stat := 0.0
	var mean_pot := 0.0
	for st in World.STATS:
		mean_stat += float(p["stats"][st])
		mean_pot += float(p["potential"][st])
	var pf := clampf(1.0 + 0.01 * (mean_pot - mean_stat) / 8.0, 1.0, float(a["potential_cap"]))
	var raw := maxf(float(a["floor"]), float(a["mult"]) * (best_slot_rating(w, p) - float(a["offset"]))) * pf
	return int(round(raw))


## Wage the player would really accept for a contract of `length` seasons: personality threshold x asking
## wage x his own hidden +-5 percent, with a small discount for longer deals.
static func required_wage(w: World, p: Dictionary, length: int) -> float:
	var d := data()
	var noise := (World._u("neg:" + String(p["id"])) * 2.0 - 1.0) * float(d["accept_noise"])
	var thr := float(d["personality_accept"][p["personality"]])
	var adj := 1.0 + float(d["length_adjust"]) * float(2 - length)
	return float(asking_wage(w, p)) * thr * (1.0 + noise) * adj


## "accept", "close", "below" or "far": the only thing a player ever says about a refused offer.
static func response(w: World, p: Dictionary, wage: int, length: int) -> String:
	var req := required_wage(w, p, length)
	if float(wage) >= req:
		return "accept"
	var ratio := float(wage) / req
	if ratio < 0.80:
		return "far"
	if ratio < 0.95:
		return "below"
	return "close"


## The contract an existing player starts the game with: close to his asking wage, 1 to 3 seasons left.
static func initial_contract(w: World, p: Dictionary) -> Dictionary:
	var jitter := 0.92 + 0.16 * World._u("wage0:" + String(p["id"]))
	var left := 1 + int(World._u("len0:" + String(p["id"])) * 3.0)
	return {"wage": maxi(15, int(round(float(asking_wage(w, p)) * jitter))), "left": left}


## Weekly revenue base of a club: the wage bill of its starting roster plus a margin, growing a little each season.
## Every sponsor offer and prize is a share of it, so all ten clubs have the same shape of economy.
static func revenue_base(w: World, roster_ids: Array, season: int) -> float:
	var total := 0.0
	for pid in roster_ids:
		total += float(initial_contract(w, w.players[pid])["wage"])
	return total * float(data()["r0_margin"]) * pow(1.0 + float(data()["r0_inflation"]), float(season - 1))
