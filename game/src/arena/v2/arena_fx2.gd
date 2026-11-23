class_name ArenaFx2
extends RefCounted
## Per-archetype ability effects in the v2 arena (0.12, overnight Q5). Every cast in the log gets a small set of sprites from
## the arena atlas (ArenaAtlas, baked once: no new texture, so the effects stay in the same draw batch as the tokens):
## heals rise as a plus over the target, shields arc around it, crowd control circles over it, and damage looks different
## per archetype (bruiser and bulwark slash, shade cuts, gunner fires a bolt that travels, spellcaster and binder burst in a
## ring, mender sparks). Ultimates are bigger and add a burst. Display only (rules A1 and R7).
##   style(ability_id, archetype) -> [[sprite, at, tone, size, rise, travel], ...]
##     at: "target" or "caster"; tone: "team", "heal", "shield", "cc", "hot"; size in ground units at token scale 1;
##     rise: lift above the ground in token heights (0 = lying on the ground); travel: true = moves caster to target

const DAMAGE := {
	"bruiser": "slash", "bulwark": "slash", "shade": "slash", "gunner": "bolt",
	"spellcaster": "ring_fx", "binder": "ring_fx", "mender": "spark",
}

static var _cache: Dictionary = {}


static func style(ability_id: String, archetype: String) -> Array:
	var key := ability_id + "|" + archetype
	if _cache.has(key):
		return _cache[key]
	var out: Array = []
	var a := _ability(ability_id)
	var kinds: Array = a.get("kind", [])
	var ult := String(a.get("slot", "")) == "ult"
	var k := 1.5 if ult else 1.0
	if "damage" in kinds or "execute" in kinds:
		var spr := String(DAMAGE.get(archetype, "spark"))
		var travel := spr == "bolt"
		out.append([spr, "target", "team", 0.03 * k, 0.0, travel])
		if travel:
			out.append(["spark", "target", "team", 0.025 * k, 0.0, false])
	if "heal" in kinds or float(a.get("ally_heal", 0.0)) > 0.0:
		out.append(["plus", "target" if String(a.get("target", "")) in ["ally", "area"] else "caster", "heal", 0.022 * k, 0.9, false])
	if "shield" in kinds:
		out.append(["shield_fx", "target" if String(a.get("target", "")) == "ally" else "caster", "shield", 0.035 * k, 0.5, false])
	if "cc" in kinds or String(a.get("cc", "")) != "":
		out.append(["cc", "target", "cc", 0.022 * k, 1.1, false])
	if ult:
		out.append(["burst", "target", "hot", 0.05, 0.0, false])
	if out.is_empty():
		out.append(["spark", "caster", "team", 0.025, 0.0, false])    # mobility, buffs, stealth: a small flash where the hero is
	_cache[key] = out
	return out


static func _ability(ability_id: String) -> Dictionary:
	var hid := ability_id.get_slice(".", 0)
	var kit := SimData.kit(hid)
	for a in kit.get("abilities", []):
		if String(a["id"]) == ability_id:
			return a
	return {}


static func tone_colour(tone: String, team: Color) -> Color:
	match tone:
		"heal":
			return UI.GOOD
		"shield":
			return UI.TEAL_HI
		"cc":
			return UI.WARN
		"hot":
			return Color(1, 0.85, 0.6)
	return team
