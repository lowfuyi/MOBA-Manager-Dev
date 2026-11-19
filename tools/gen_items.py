"""Gameplay / Champion Designer and Economy Designer: the item catalogue of Match Sim v2 (MATCH-SIM-V2-DESIGN 4.2 and 4.3).

Writes game/data/items_v2.json: components, boots and finished items with original names (screened by tools/ip_names.py),
their stats, at most one unique effect from the simulator's fixed vocabulary, and the coach's build rules.
Prices are v0 placeholders; a finished item costs its components plus a recipe fee. Re-run: python3 tools/gen_items.py
"""
import json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

STATS = ["atk", "ap", "hp", "armor", "resist", "aspd", "crit", "haste", "lifesteal", "omnivamp", "move", "pen_armor",
         "pen_resist", "shield_power", "heal_power"]
EFFECTS = ["", "burn", "antiheal", "on_hit", "crit_amp", "spellblade", "guard", "revive_once", "slow_on_hit", "aura_armor",
           "aura_haste", "execute", "splash"]
# Gold value of one point of each stat (used by a test: an item's stats are worth 85 to 125 percent of its price,
# finished items get a little more for their effect). v0, from the component prices below.
STAT_GOLD = {"atk": 35, "ap": 21, "hp": 2.7, "armor": 20, "resist": 18, "aspd": 2500, "crit": 2000, "haste": 27,
             "lifesteal": 3000, "omnivamp": 3500, "move": 4000, "pen_armor": 3000, "pen_resist": 3000,
             "shield_power": 2000, "heal_power": 2000}

# id, name, cost, stats, (no components)
COMPONENTS = [
    ("iron_splint", "Iron Splint", 350, {"atk": 10}),
    ("warm_coal", "Warm Coal", 435, {"ap": 20}),
    ("fletch_cord", "Fletch Cord", 300, {"aspd": 0.12}),
    ("moss_knot", "Moss Knot", 400, {"hp": 150}),
    ("waxed_jerkin", "Waxed Jerkin", 300, {"armor": 15}),
    ("felted_cowl", "Felted Cowl", 270, {"resist": 15}),
    ("cinder_rod", "Cinder Rod", 850, {"ap": 40}),
    ("hewing_bar", "Hewing Bar", 875, {"atk": 25}),
    ("copper_lens", "Copper Lens", 400, {"haste": 10, "ap": 5}),
    ("leech_tooth", "Leech Tooth", 450, {"lifesteal": 0.08, "atk": 5}),
    ("flint_spur", "Flint Spur", 500, {"crit": 0.15, "aspd": 0.05}),
    ("thistle_mail", "Thistle Mail", 800, {"armor": 30, "hp": 75}),
    ("quarry_girdle", "Quarry Girdle", 900, {"hp": 350}),
    ("lantern_wick", "Lantern Wick", 550, {"haste": 10, "ap": 15}),
]
BOOTS_BASE = ("roadworn_boots", "Roadworn Boots", 300, {"move": 0.06})
# upgraded boots: id, name, recipe fee (on top of trail boots), stats, effect
BOOTS = [
    ("ironshod_treads", "Ironshod Treads", 800, {"move": 0.10, "armor": 20}, ""),
    ("wayfarer_soles", "Wayfarer Soles", 700, {"move": 0.10, "haste": 15}, ""),
    ("racing_spurs", "Racing Spurs", 750, {"move": 0.10, "aspd": 0.25}, ""),
    ("scholar_slippers", "Scholar Slippers", 800, {"move": 0.10, "pen_resist": 0.15}, ""),
    ("mire_waders", "Mire Waders", 800, {"move": 0.10, "resist": 22}, ""),
]
# finished: id, name, class, components, recipe fee, stats, effect, short text
FINISHED = [
    # --- physical carry
    ("gloamcutter", "Gloamcutter", "carry", ["hewing_bar", "flint_spur", "iron_splint"], 700, {"atk": 60, "crit": 0.20}, "crit_amp",
     "Critical hits deal much more damage."),
    ("thrumming_longbow", "Thrumming Longbow", "carry", ["fletch_cord", "flint_spur", "fletch_cord"], 1000, {"aspd": 0.40, "crit": 0.20, "move": 0.05}, "on_hit",
     "Attacks deal a little extra magic damage."),
    ("ninefold_quiver", "Ninefold Quiver", "carry", ["fletch_cord", "flint_spur", "fletch_cord"], 900, {"aspd": 0.40, "crit": 0.25}, "splash",
     "Attacks also strike two enemies near the target."),
    ("marrow_drinker", "Marrow Drinker", "carry", ["hewing_bar", "leech_tooth", "iron_splint"], 850, {"atk": 55, "lifesteal": 0.18}, "guard",
     "Lifesteal; overflow healing becomes a shield when hurt badly."),
    ("shalehewer", "Shalehewer", "carry", ["hewing_bar", "iron_splint"], 1100, {"atk": 45, "pen_armor": 0.30}, "",
     "Ignores part of the target's armour."),
    ("starveling_blade", "Starveling Blade", "carry", ["hewing_bar", "leech_tooth"], 650, {"atk": 40, "aspd": 0.15}, "antiheal",
     "Attacks reduce the target's healing."),
    ("lastlight_spear", "Lastlight Spear", "fighter", ["hewing_bar", "copper_lens", "iron_splint"], 750, {"atk": 45, "haste": 20}, "execute",
     "Hits harder against badly hurt enemies."),
    ("duskward_sabre", "Duskward Sabre", "carry", ["hewing_bar", "felted_cowl", "iron_splint"], 900, {"atk": 40, "resist": 35}, "guard",
     "A shield against magic when badly hurt."),
    # --- fighter (bruiser) damage
    ("splitstone_maul", "Splitstone Maul", "fighter", ["hewing_bar", "moss_knot", "iron_splint"], 900, {"atk": 40, "hp": 300}, "splash",
     "Attacks crack the ground, hitting enemies around the target."),
    ("rimefang_glaive", "Rimefang Glaive", "fighter", ["iron_splint", "quarry_girdle", "fletch_cord"], 900, {"atk": 30, "hp": 300, "aspd": 0.15}, "slow_on_hit",
     "Attacks slow the target briefly."),
    ("gravelgrip_mace", "Gravelgrip Mace", "fighter", ["iron_splint", "copper_lens", "moss_knot"], 1050, {"atk": 35, "hp": 300, "haste": 15}, "spellblade",
     "After an ability, the next attack deals bonus damage."),
    ("gloam_hunger", "Gloam Hunger", "fighter", ["hewing_bar", "leech_tooth", "moss_knot"], 800, {"atk": 40, "omnivamp": 0.12, "hp": 200}, "",
     "Heals from all damage dealt."),
    ("ironroot_hatchet", "Ironroot Hatchet", "fighter", ["hewing_bar", "moss_knot"], 1150, {"atk": 40, "hp": 300, "pen_armor": 0.15}, "",
     "Ignores some armour."),
    # --- magic
    ("lamplighters_ledger", "Lamplighter's Ledger", "mage", ["cinder_rod", "lantern_wick", "copper_lens"], 900, {"ap": 90, "haste": 20}, "",
     "Abilities come back sooner."),
    ("ember_diadem", "Ember Diadem", "mage", ["cinder_rod", "moss_knot", "warm_coal"], 800, {"ap": 75, "hp": 250}, "burn",
     "Abilities set enemies burning."),
    ("heartwood_stave", "Heartwood Stave", "mage", ["cinder_rod", "cinder_rod"], 1400, {"ap": 120}, "",
     "Raw ability power."),
    ("sootglass_orb", "Sootglass Orb", "mage", ["cinder_rod", "warm_coal"], 1150, {"ap": 70, "pen_resist": 0.35}, "",
     "Ignores much of the target's resistance."),
    ("stillwater_phial", "Stillwater Phial", "mage", ["cinder_rod", "waxed_jerkin", "warm_coal"], 1100, {"ap": 65, "armor": 45}, "revive_once",
     "Once a game, freezes the wearer in still water instead of a lethal blow."),
    ("nettle_brazier", "Nettle Brazier", "mage", ["warm_coal", "moss_knot", "warm_coal"], 1000, {"ap": 60, "hp": 200}, "antiheal",
     "Ability damage reduces healing."),
    ("runnel_bracer", "Runnel Bracer", "mage", ["cinder_rod", "lantern_wick"], 1050, {"ap": 75, "move": 0.05}, "spellblade",
     "After an ability, the next attack deals bonus magic damage."),
    # --- tank
    ("tidewall_rampart", "Tidewall Rampart", "tank", ["thistle_mail", "moss_knot"], 1100, {"hp": 400, "armor": 40}, "aura_armor",
     "Allies nearby gain armour."),
    ("cairnstone_plate", "Cairnstone Plate", "tank", ["thistle_mail", "waxed_jerkin", "moss_knot"], 1050, {"armor": 70, "hp": 250}, "",
     "Heavy armour."),
    ("mosscloak", "Mosscloak", "tank", ["felted_cowl", "quarry_girdle", "felted_cowl"], 1050, {"resist": 60, "hp": 350}, "",
     "Heavy magic resistance."),
    ("burrbark_hauberk", "Burrbark Hauberk", "tank", ["thistle_mail", "waxed_jerkin"], 1100, {"armor": 60, "hp": 150}, "antiheal",
     "Attackers have their healing reduced."),
    ("kiln_heart", "Kiln Heart", "tank", ["quarry_girdle", "waxed_jerkin"], 1300, {"hp": 500, "armor": 30}, "burn",
     "Burns enemies standing close."),
    ("bellwether_mantle", "Bellwether Mantle", "tank", ["felted_cowl", "quarry_girdle"], 1300, {"hp": 400, "resist": 45}, "aura_haste",
     "Allies nearby recover abilities faster."),
    ("rootbound_girdle", "Rootbound Girdle", "tank", ["quarry_girdle", "moss_knot"], 1150, {"hp": 700}, "slow_on_hit",
     "Hits slow enemies."),
    # --- support
    ("lantern_of_kinship", "Lantern of Kinship", "support", ["moss_knot", "lantern_wick"], 1250, {"hp": 300, "heal_power": 0.20, "haste": 15}, "aura_haste",
     "Heals and shields are stronger; allies nearby recover abilities faster."),
    ("wayfinder_charm", "Wayfinder Charm", "support", ["lantern_wick", "moss_knot"], 1200, {"move": 0.08, "haste": 20, "shield_power": 0.15, "hp": 200}, "",
     "Moves faster; shields are stronger."),
    ("gossamer_veil", "Gossamer Veil", "support", ["felted_cowl", "moss_knot"], 1300, {"resist": 40, "hp": 250}, "guard",
     "A shield when badly hurt."),
    ("menders_thurible", "Mender's Thurible", "support", ["warm_coal", "lantern_wick"], 1250, {"ap": 40, "heal_power": 0.20, "haste": 15}, "",
     "Heals and shields are much stronger."),
]

# Coach rules (4.3): scores added to an item for one hero against one enemy draft. Evaluated by Items.suggest().
COACH_RULES = {
    "class_by_archetype": {"bruiser": ["fighter", "tank"], "bulwark": ["tank", "support"], "spellcaster": ["mage"],
                           "gunner": ["carry"], "shade": ["fighter", "carry", "mage"], "mender": ["support", "mage"],
                           "binder": ["support", "mage", "tank"]},
    "boots_by_archetype": {"bruiser": "ironshod_treads", "bulwark": "ironshod_treads", "spellcaster": "scholar_slippers",
                           "gunner": "racing_spurs", "shade": "wayfarer_soles", "mender": "wayfarer_soles", "binder": "wayfarer_soles"},
    "boots_vs_magic_heavy": "mire_waders",
    "weights": {
        "stat_match": 1.0,
        "enemy_heals_antiheal": 0.8,
        "enemy_physical_armor": 0.5,
        "enemy_magic_resist": 0.5,
        "enemy_dive_guard": 0.6,
        "duplicate_effect": -2.0,
        "second_of_class_penalty": 0.0
    },
    "antiheal_from_heals": 2,
    "heavy_damage_share": 0.6,
    "dive_from_engage_pick": 4,
    "note": "Scores per finished item: stat_match = how well its stats fit the hero's damage type and archetype; then the enemy rules; the best six (boots first) in order. Tunable; never hand-written per hero."
}


def value(stats):
    return sum(STAT_GOLD[k] * v for k, v in stats.items())


def main():
    items = []
    comp_cost = {}
    for cid, name, cost, st in COMPONENTS:
        items.append({"id": cid, "name": name, "tier": "component", "class": "", "cost": cost, "components": [], "stats": st, "effect": "", "text": ""})
        comp_cost[cid] = cost
    bid, bname, bcost, bst = BOOTS_BASE
    items.append({"id": bid, "name": bname, "tier": "boots_base", "class": "boots", "cost": bcost, "components": [], "stats": bst, "effect": "", "text": "Faster on the move."})
    comp_cost[bid] = bcost
    for iid, name, fee, st, eff in BOOTS:
        items.append({"id": iid, "name": name, "tier": "boots", "class": "boots", "cost": bcost + fee, "components": [bid], "stats": st, "effect": eff, "text": ""})
    for iid, name, cls, comps, fee, st, eff, text in FINISHED:
        assert all(c in comp_cost for c in comps), (iid, comps)
        assert eff in EFFECTS, (iid, eff)
        assert set(st) <= set(STATS), (iid, st)
        items.append({"id": iid, "name": name, "tier": "finished", "class": cls, "cost": sum(comp_cost[c] for c in comps) + fee,
                      "components": comps, "stats": st, "effect": eff, "text": text})
    doc = {"schema": "gloamline/items", "version": 1,
           "note": "Generated by tools/gen_items.py; do not edit by hand. Prices and stats are v0 placeholders.",
           "stats": STATS, "effects": EFFECTS, "stat_gold": STAT_GOLD, "coach_rules": COACH_RULES, "items": items}
    (ROOT / "game/data/items_v2.json").write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
    fin = [i for i in items if i["tier"] == "finished"]
    print(f"items_v2.json: {len(items)} items ({len(COMPONENTS)} components, {len(BOOTS) + 1} boots, {len(fin)} finished)")
    for i in items:
        v = value(i["stats"]) / i["cost"]
        if not (0.70 <= v <= 1.35):
            print(f"  value check: {i['id']} {v:.2f}")


if __name__ == "__main__":
    main()
