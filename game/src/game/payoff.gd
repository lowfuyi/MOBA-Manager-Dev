class_name Payoff
extends RefCounted
## What one finished game changed for the managed club (form, morale, bonds, chemistry, cash), for the
## payoff screen. Pure bookkeeping: a snapshot before the game is recorded and one after, then compared.


static func snapshot(gs: GameState) -> Dictionary:
	var form := {}
	var morale := {}
	for pid in gs.d["roster"]:
		form[pid] = gs.form_of(pid)
		morale[pid] = gs.morale_of(pid)
	return {"form": form, "morale": morale, "bond": gs.bond_mean(), "chem_bonus": gs.chem_bonus(), "cash": gs.cash(),
			"lineup": (gs.d["lineup"] as Dictionary).duplicate()}


## Returns {"rows": [{id, slot, form_b, form_a, mor_b, mor_a}], "bond_b", "bond_a", "chem_b", "chem_a", "cash_d"}.
## Rows follow the lineup order of the game that was played.
static func compare(gs: GameState, before: Dictionary) -> Dictionary:
	var rows: Array = []
	for s in GameState.SLOTS:
		var pid: String = before["lineup"][s]
		if not before["form"].has(pid):
			continue
		rows.append({"id": pid, "slot": s, "form_b": float(before["form"][pid]), "form_a": gs.form_of(pid),
				"mor_b": float(before["morale"][pid]), "mor_a": gs.morale_of(pid)})
	return {"rows": rows, "bond_b": float(before["bond"]), "bond_a": gs.bond_mean(), "chem_b": float(before["chem_bonus"]),
			"chem_a": gs.chem_bonus(), "cash_d": gs.cash() - float(before["cash"])}


## One piece of advice for the next game, from rules over the current state. Returns {"key", "args"}.
static func tip(gs: GameState) -> Dictionary:
	var has_next := not gs.next_game().is_empty()
	var tired := gs.tired_starters().size()
	if has_next and tired > 0:
		return {"key": "tip.rest", "args": {"n": tired}}
	var worst := ""
	var worst_m := 40.0
	for pid in (gs.d["lineup"] as Dictionary).values():
		var m := gs.morale_of(pid)
		if m < worst_m:
			worst_m = m
			worst = String(gs.world.players[pid]["name"])
	if worst != "":
		return {"key": "tip.morale", "args": {"name": worst}}
	if gs.expiring().size() > 0:
		return {"key": "tip.contract", "args": {"n": gs.expiring().size()}}
	if gs.chem_bonus() < 0.015:
		return {"key": "tip.scrim", "args": {}}
	return {"key": "tip.keep", "args": {}}
