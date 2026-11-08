class_name Bonds
extends RefCounted
## Team Bonds (GDD 7.7) and the Form / Morale rules (GDD 4.2, 8.6). Pure functions over players and numbers:
## the save stores the numbers (GameState), the World reads them when it builds a team. Constants live in
## data/bonds_v0.json.

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = DataLoader.load_json("res://data/bonds_v0.json")
	return _data


# ---------------------------------------------------------------- bonds
static func pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


static func growth_of(personality: String) -> float:
	return float(data()["bond"]["growth"].get(personality, 1.0))


## Growth factor of a pair: the geometric mean of the two players' factors.
static func pair_growth(pa: Dictionary, pb: Dictionary) -> float:
	return sqrt(growth_of(pa["personality"]) * growth_of(pb["personality"]))


## New bond after one event worth `base` points: base x (100 - bond) / 70 x growth.
static func gain(bond: float, base: float, growth: float) -> float:
	return clampf(bond + base * (100.0 - bond) / 70.0 * growth, 0.0, 100.0)


## 1.0 when the two share a language both speak at the required fluency, else the mismatch factor.
static func lang(pa: Dictionary, pb: Dictionary) -> float:
	var need := float(data()["bond"]["lang_ok_fluency"])
	for la in pa.get("languages", [{"lang": "en", "fluency": 100}]):
		if float(la["fluency"]) < need:
			continue
		for lb in pb.get("languages", [{"lang": "en", "fluency": 100}]):
			if lb["lang"] == la["lang"] and float(lb["fluency"]) >= need:
				return 1.0
	return float(data()["bond"]["lang_mismatch"])


## How much of player j's COM comes across: 0.4 + 0.6 x COM / 100.
static func com_factor(com: float) -> float:
	var b: Dictionary = data()["bond"]
	return float(b["com_floor"]) + float(b["com_weight"]) * com / 100.0


## U(i <- j) = Lang x Bond x (0.4 + 0.6 COM_j / 100), 0 to 100.
static func understanding(pi: Dictionary, pj: Dictionary, bond: float) -> float:
	return lang(pi, pj) * bond * com_factor(float(pj["stats"]["com"]))


## Mean of the 20 directional values among five players. `bond_of` is a Callable(id_a, id_b) -> float.
static func chem(five: Array, bond_of: Callable) -> float:
	var total := 0.0
	var n := 0
	for i in five.size():
		for j in five.size():
			if i == j:
				continue
			total += understanding(five[i], five[j], float(bond_of.call(five[i]["id"], five[j]["id"])))
			n += 1
	return total / float(maxi(1, n))


## Chemistry of an AI club, which keeps one bond level for its whole squad: the same mean with every bond equal.
static func chem_flat(five: Array, bond: float) -> float:
	return chem(five, func(_a, _b): return bond)


static func chem_bonus(chem_value: float) -> float:
	return float(data()["bond"]["chem_bonus_max"]) * chem_value / 100.0


# ---------------------------------------------------------------- form and morale
static func days_per_tick() -> float:
	return float(data()["days_per_tick"])


static func clamp_form(f: float) -> float:
	var d: Dictionary = data()["form"]
	return clampf(f, float(d["min"]), float(d["max"]))


static func clamp_morale(m: float) -> float:
	var d: Dictionary = data()["morale"]
	return clampf(m, float(d["min"]), float(d["max"]))


## A starter's Form after a match: two points toward the result.
static func form_after_match(form: float, won: bool) -> float:
	var step := float(data()["form"]["per_match"])
	return clamp_form(form + (step if won else -step))


## Form after `days` calendar days: mean-reverts to 0 by 10 percent a day.
static func form_after_days(form: float, days: float) -> float:
	return form * pow(float(data()["form"]["daily_keep"]), days)


## Morale change from one match. Starters swing by the result, the bench a little; playoffs weigh more;
## the personality scales the swing (Professional 0.8 ... Temperamental 1.5).
static func morale_after_match(morale: float, personality: String, started: bool, won: bool, playoff: bool) -> float:
	var d: Dictionary = data()["morale"]
	var swing := float(d["starter_swing"]) if started else float(d["bench_swing"])
	if playoff:
		swing *= float(d["playoff_mult"])
	swing *= float(d["swing_mult"].get(personality, 1.0))
	return clamp_morale(morale + (swing if won else -swing))


## A starter's morale loss for the match he just missed, given how many he has now missed in a row.
static func miss_loss(missed_in_a_row: int, was_starter: bool) -> float:
	var d: Dictionary = data()["morale"]
	if was_starter and missed_in_a_row > int(d["miss_grace"]) and missed_in_a_row <= int(d["miss_forget"]):
		return float(d["miss_loss"])
	return 0.0


## Morale after `days` days: one point a day toward 60, never past it.
static func morale_after_days(morale: float, days: float) -> float:
	var d: Dictionary = data()["morale"]
	var neutral := float(d["neutral"])
	var step := float(d["drift_per_day"]) * days
	if morale > neutral:
		return maxf(neutral, morale - step)
	return minf(neutral, morale + step)


static func mood_word(morale: float) -> String:
	if morale >= 75.0:
		return "high"
	if morale >= 55.0:
		return "ok"
	if morale >= 40.0:
		return "low"
	return "poor"
