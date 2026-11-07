class_name Comp
extends RefCounted
## Draft composition scoring (GDD 5.3). Port of tools/comp.py; the golden file
## res://tests/golden/pipeline_vectors.json pins it.

const SYNERGY_PAIRS := [["engage", "pick"], ["protect", "scaling"], ["poke", "waveclear"], ["frontline", "engage"]]


static func _tags(heroes: Array) -> Array:
	var out: Array = []
	for h in heroes:
		var d := {}
		for t in h["tags"]:
			d[t] = true
		out.append(d)
	return out


static func _has(tags: Array, tag: String) -> bool:
	for d in tags:
		if d.has(tag):
			return true
	return false


static func _synergy_pairs_present(tags: Array) -> int:
	var n := 0
	for pair in SYNERGY_PAIRS:
		var found := false
		for i in tags.size():
			if not tags[i].has(pair[0]):
				continue
			for j in tags.size():
				if i != j and tags[j].has(pair[1]):
					found = true
					break
			if found:
				break
		if found:
			n += 1
	return n


static func _damage(heroes: Array) -> Vector2:
	var phys := 0.0
	var magic := 0.0
	for h in heroes:
		match h["damage_type"]:
			"physical":
				phys += 1.0
			"magic":
				magic += 1.0
			_:
				phys += 0.5
				magic += 0.5
	return Vector2(phys, magic)


## Returns {"mod": float, "style": String, "parts": {needs, balance, synergy, scores}}.
static func evaluate(heroes: Array) -> Dictionary:
	var need_pen := Params.f("need_pen")
	var bal_pen := Params.f("bal_pen")
	var syn_bonus := Params.f("syn_bonus")
	var cap := Params.f("cap")
	var tags := _tags(heroes)
	var needs := 0.0
	if not _has(tags, "frontline"):
		needs -= need_pen
	if not (_has(tags, "engage") or _has(tags, "pick")):
		needs -= need_pen
	if not _has(tags, "waveclear"):
		needs -= need_pen
	var dmg := _damage(heroes)
	var balance := -bal_pen if (dmg.x >= 3.5 or dmg.y >= 3.5) else 0.0
	var syn := 0.0
	for k in _synergy_pairs_present(tags):
		syn += syn_bonus
	var dive := 0
	var siege := 0
	var protect := 0
	for d in tags:
		dive += int(d.has("engage")) + int(d.has("pick"))
		siege += int(d.has("poke")) + int(d.has("waveclear"))
		protect += int(d.has("protect")) + int(d.has("scaling"))
	var names := ["dive", "siege", "protect"]
	var vals := [dive, siege, protect]
	var i0 := 0
	for i in 3:
		if vals[i] > vals[i0]:
			i0 = i
	var i1 := -1
	for i in 3:
		if i == i0:
			continue
		if i1 == -1 or vals[i] > vals[i1]:
			i1 = i
	var top: int = vals[i0]
	var second: int = vals[i1]
	var style: String = names[i0] if (top >= 4 and top >= second + 1) else "skirmish"
	var mod := maxf(-cap, minf(cap, needs + balance + syn))
	return {"mod": mod, "style": style,
			"parts": {"needs": needs, "balance": balance, "synergy": syn,
					"scores": {"dive": dive, "siege": siege, "protect": protect}}}


## Partial composition value used by the draft AI and the draft preview.
static func progress(heroes: Array) -> float:
	var need_pen := Params.f("need_pen")
	var bal_pen := Params.f("bal_pen")
	var syn_bonus := Params.f("syn_bonus")
	var tags := _tags(heroes)
	var n_needs := int(_has(tags, "frontline")) + int(_has(tags, "engage") or _has(tags, "pick")) + int(_has(tags, "waveclear"))
	var v := need_pen * n_needs
	for k in _synergy_pairs_present(tags):
		v += syn_bonus
	var dmg := _damage_strict(heroes)
	if dmg.x >= 3.5 or dmg.y >= 3.5:
		v -= bal_pen
	return v


## Same as _damage but unknown damage types count for neither (mirrors tools/pipeline.py _progress).
static func _damage_strict(heroes: Array) -> Vector2:
	var phys := 0.0
	var mag := 0.0
	for h in heroes:
		if h["damage_type"] == "physical":
			phys += 1.0
		elif h["damage_type"] == "mixed":
			phys += 0.5
		if h["damage_type"] == "magic":
			mag += 1.0
		elif h["damage_type"] == "mixed":
			mag += 0.5
	return Vector2(phys, mag)
