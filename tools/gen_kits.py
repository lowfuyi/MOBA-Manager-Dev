"""Gameplay / Champion Designer: the 40 hero kits of Match Sim v2 (Founder decision 2026-11-19, MATCH-SIM-V2-DESIGN section 3).

Writes game/data/kits_v2.json. The names, texts and effect kinds below are hand-written and original (screened by
tools/ip_names.py and docs/design/IP-REVIEW-KITS-ITEMS.md); the NUMBERS come from archetype templates and the hero's power
curve (power_early / power_late in heroes.json), so 200 abilities stay balanced against each other and calibration has
few knobs (game/data/sim_v2_params.json scales them all). Re-run after editing: python3 tools/gen_kits.py
The file is named kits_v2.json, not heroes_v2.json, because validate_data.py reads every heroes*.json with the v1 schema.
"""
import json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
HEROES = {h["id"]: h for h in json.loads((ROOT / "game/data/heroes.json").read_text())}

# ---- base stats per archetype (level 1, per-level growth). Map units: the arena is about 1 unit tall (ARENA-MAP 2).
ARCH = {
    #              hp  hp_l  atk atk_l aspd  arm arm_l res res_l  move
    "bruiser":    (650, 96, 64, 3.6, 0.68, 34, 3.8, 32, 1.6, 0.0290),
    "bulwark":    (700, 106, 56, 3.0, 0.64, 38, 4.2, 34, 2.0, 0.0285),
    "spellcaster": (560, 80, 50, 2.8, 0.64, 24, 3.4, 30, 1.2, 0.0280),
    "gunner":     (580, 84, 60, 3.4, 0.70, 26, 3.4, 30, 1.0, 0.0280),
    "shade":      (590, 88, 64, 3.4, 0.68, 30, 3.6, 30, 1.4, 0.0295),
    "mender":     (560, 78, 50, 2.6, 0.62, 26, 3.6, 30, 1.2, 0.0285),
    "binder":     (580, 82, 52, 2.8, 0.64, 28, 3.6, 30, 1.2, 0.0285),
}
RANGE_U = {"melee": 0.010, "mid": 0.024, "long": 0.036}
BASE_DMG = {"bruiser": 70, "bulwark": 52, "spellcaster": 82, "gunner": 62, "shade": 76, "mender": 48, "binder": 60}
CC_S = {"stun": 1.0, "root": 1.25, "slow": 1.5, "knockup": 0.75, "silence": 1.25, "taunt": 1.0, "": 0.0}
SLOT_CD = {"a1": 7.0, "a2": 11.0, "a3": 13.0, "ult": 55.0}
SLOT_DMG = {"a1": 1.0, "a2": 0.75, "a3": 0.55, "ult": 2.4}
UNLOCK = {"a1": 1, "a2": 1, "a3": 3, "ult": 6}
KINDS = {"damage", "cc", "mobility", "shield", "heal", "buff", "zone", "execute", "stealth", "summon", "wave"}
TARGETS = {"enemy", "ally", "self", "area", "line"}
TRIGGERS = {"on_hit_nth", "low_hp", "on_kill", "on_ability", "aura", "stacks_per_min", "out_of_combat", "vs_structure", "isolated"}


def A(name, text, kinds, target, cc="", **kw):
    return dict(name=name, text=text, kinds=kinds, target=target, cc=cc, kw=kw)


def P(name, text, trigger, **kw):
    return dict(name=name, text=text, trigger=trigger, kw=kw)


def dtype_for(h, i):
    d = h["damage_type"]
    if d == "physical": return "phys"
    if d == "magic": return "magic"
    return "phys" if i % 2 == 0 else "magic"   # mixed: a1 and a3 physical, a2 and ult magic


def ability(hid, slot, i, a):
    h = HEROES[hid]
    arch = h["archetype"]
    curve = (h["power_late"] - h["power_early"]) / 20.0          # -0.7 (early hero) .. +0.9 (late hero)
    kinds, target, cc, kw = a["kinds"], a["target"], a["cc"], a["kw"]
    assert set(kinds) <= KINDS, (hid, slot, kinds)
    assert target in TARGETS, (hid, slot, target)
    out = {"id": f"{hid}.{slot}", "slot": slot, "name": a["name"], "text": a["text"], "kind": kinds, "target": target}
    dmg = 0.0
    if "damage" in kinds or "execute" in kinds:
        dmg = BASE_DMG[arch] * SLOT_DMG[slot] * (1.0 - 0.10 * curve)
        if "cc" in kinds: dmg *= 0.8
        if target == "area" or "zone" in kinds: dmg *= 0.85
        dmg *= kw.pop("dmg_x", 1.0)
    out["dmg"] = round(dmg)
    out["dmg_lvl"] = round(dmg * (0.30 if slot != "ult" else 0.22), 1)
    ratio = (0.0 if dmg == 0 else (1.0 if slot == "ult" else 0.6) * (1.0 + 0.20 * curve))
    out["ratio"] = round(ratio * kw.pop("ratio_x", 1.0), 2)
    out["dtype"] = kw.pop("dtype", dtype_for(h, i))
    assert cc in CC_S, (hid, slot, cc)
    out["cc"] = cc
    out["cc_s"] = round(CC_S[cc] * (1.3 if slot == "ult" else 1.0) * kw.pop("cc_x", 1.0), 2) if cc else 0.0
    shield = heal = 0.0
    if "shield" in kinds:
        shield = (60 if arch not in ("bulwark", "mender") else 80) * (1.6 if slot == "ult" else 1.0) * kw.pop("shield_x", 1.0)
    if "heal" in kinds:
        heal = (45 if arch != "mender" else 60) * (1.8 if slot == "ult" else 1.0) * kw.pop("heal_x", 1.0)
    out["shield"] = round(shield)
    out["heal"] = round(heal)
    out["ratio_def"] = round(0.08 if (shield and arch in ("bulwark", "bruiser")) else (0.35 if (shield or heal) else 0.0), 2)
    rng = {"line": 0.045, "enemy": 0.035 if h["range"] != "melee" else 0.020, "area": 0.040, "ally": 0.040, "self": 0.0}[target]
    out["range_u"] = round(rng * kw.pop("range_x", 1.0), 3)
    out["radius_u"] = round(kw.pop("radius_u", 0.025 if (target == "area" or "zone" in kinds or "wave" in kinds) else 0.0), 3)
    cd = SLOT_CD[slot] * kw.pop("cd_x", 1.0)
    out["cd"] = round(cd, 1)
    out["cd_lvl"] = round(-cd * (0.03 if slot != "ult" else 0.025), 2)
    out["cast_s"] = kw.pop("cast_s", 0.25 if slot != "ult" else 0.4)
    out["hit"] = kw.pop("hit", 0.75 if target == "line" else (0.85 if target == "area" else 1.0))
    out["dash_u"] = round(kw.pop("dash_u", 0.030 if "mobility" in kinds else 0.0), 3)
    out["dur_s"] = kw.pop("dur_s", 3.0 if ("zone" in kinds or "buff" in kinds or "stealth" in kinds) else 0.0)
    out["buff"] = kw.pop("buff", {})
    out["exec_below"] = kw.pop("exec_below", 0.25 if "execute" in kinds else 0.0)
    out["unlock"] = UNLOCK[slot]
    assert not kw, (hid, slot, kw)
    return out


def passive(hid, p):
    kw = dict(p["kw"])
    assert p["trigger"] in TRIGGERS, (hid, p["trigger"])
    out = {"id": f"{hid}.passive", "slot": "passive", "name": p["name"], "text": p["text"], "trigger": p["trigger"]}
    out["every"] = kw.pop("every", 0)
    out["bonus_dmg"] = kw.pop("bonus_dmg", 0)
    out["ratio"] = kw.pop("ratio", 0.0)
    out["dtype"] = kw.pop("dtype", "magic" if HEROES[hid]["damage_type"] == "magic" else "phys")
    out["heal"] = kw.pop("heal", 0)
    out["shield"] = kw.pop("shield", 0)
    out["stat"] = kw.pop("stat", "")
    out["amount"] = kw.pop("amount", 0.0)
    out["max_stacks"] = kw.pop("max_stacks", 0)
    out["cc"] = kw.pop("cc", "")
    out["cc_s"] = kw.pop("cc_s", 0.0)
    out["cd"] = kw.pop("cd", 0.0)
    assert not kw, (hid, kw)
    return out


def stats(hid):
    h = HEROES[hid]
    hp, hpl, atk, atkl, aspd, arm, arml, res, resl, mv = ARCH[h["archetype"]]
    return {"hp": hp, "hp_lvl": hpl, "atk": atk, "atk_lvl": atkl, "aspd": aspd, "armor": arm, "armor_lvl": arml,
            "resist": res, "resist_lvl": resl, "range_u": RANGE_U[h["range"]], "move_u_s": mv}


K = {}

# =========================================================================================== TOP
K["brannoch"] = ("Quarry Foreman", "Runs the old stone pits and settles disputes with a chain flail.",
    P("Grit Under Nails", "Every third attack hits harder and mends a little health.", "on_hit_nth", every=3, bonus_dmg=30, ratio=0.3, heal=20),
    A("Rubble Sweep", "Swings the flail in a full circle, hurting everyone nearby; clears waves quickly.", ["damage", "wave"], "area", range_x=0.0),
    A("Shoulder Into It", "Barges forward and slows the first enemy hit.", ["damage", "mobility", "cc"], "line", cc="slow"),
    A("Stand the Ground", "Braces behind the flail for a shield that grows with bonus health.", ["shield"], "self"),
    A("Quarry Collapse", "Slams the ground; a moment later a ring of stone throws enemies in the area into the air.", ["damage", "cc"], "area", cc="knockup"))
K["dunmarrow"] = ("Bog Warden", "Keeps the drowned bells of the mere and rings them for whoever is lost.",
    P("Sunken Bell", "After each ability their next attack rings out, hurting enemies around them.", "on_ability", bonus_dmg=35, ratio=0.25),
    A("Toll", "Strikes an enemy with a bell-clap that hurts and slows.", ["damage", "cc"], "enemy", cc="slow"),
    A("Mire Tether", "Ties a chain of bog-weed to an enemy; if it holds, the enemy is rooted.", ["cc"], "enemy", cc="root", range_x=1.6),
    A("Peat Hide", "Takes less damage for a few seconds, as though wrapped in wet earth.", ["buff", "shield"], "self", buff={"dr": 0.20}),
    A("Drowning Chime", "Charges ahead with the great bell; every enemy in the line is stunned.", ["damage", "mobility", "cc"], "line", cc="stun", dash_u=0.05))
K["skarrow"] = ("Pit Scavenger", "A duelist who learned their trade picking over battlefields.",
    P("Carrion Instinct", "Deals more damage to towers and to enemies with no ally nearby.", "isolated", stat="dmg_amp", amount=0.10),
    A("Gutting Hook", "Flings a hooked knife in a line, hurting the first enemy hit.", ["damage"], "line"),
    A("Scatter Step", "Darts a short way and gains a burst of speed.", ["mobility", "buff"], "self", buff={"move": 0.25}, dur_s=1.5),
    A("Picked Clean", "A cruel cut that heals them for part of the damage.", ["damage", "heal"], "enemy"),
    A("Last One Standing", "For a few seconds attacks faster and heals from their hits; a kill extends it.", ["buff"], "self", buff={"aspd": 0.45, "lifesteal": 0.15}, dur_s=6.0))
K["hegwin"] = ("Chain Ranger", "Hunts the reed beds with a weighted chain and the patience of a heron.",
    P("Long Reach", "Attacks from near the end of their range deal extra damage.", "on_hit_nth", every=1, bonus_dmg=10, ratio=0.1),
    A("Chainlash", "Whips the chain in a line, hurting and slowing.", ["damage", "cc"], "line", cc="slow"),
    A("Snare Coil", "Throws a loop of chain that roots the first enemy caught.", ["cc"], "line", cc="root"),
    A("Recoil", "Springs backwards and gains a small shield.", ["mobility", "shield"], "self"),
    A("Drag Under", "Hooks an enemy, hauls them close and stuns them briefly.", ["damage", "cc"], "enemy", cc="stun", range_x=1.5))
K["ottomere"] = ("Light Keeper", "Kept the lighthouse for forty winters; now they keep their team.",
    P("Salt-Cured", "Gains maximum health slowly over the game, up to a cap.", "stacks_per_min", stat="hp", amount=25.0, max_stacks=12),
    A("Anchor Swing", "Swings their old anchor in an arc, hurting and slowing.", ["damage", "cc"], "area", cc="slow"),
    A("Beacon Pulse", "Lights the beacon on their back: nearby enemies are drawn to attack them.", ["cc"], "area", cc="taunt", range_x=0.0),
    A("Kept Watch", "Braces against the storm for a shield and extra armour.", ["shield", "buff"], "self", buff={"armor": 20}),
    A("Lighthouse Charge", "Charges a long way to an area and knocks the enemies there into the air.", ["damage", "mobility", "cc"], "area", cc="knockup", dash_u=0.07, range_x=1.8))
K["orrick"] = ("Fen Swordsman", "Lost their sight to marsh fever and trusts only the sound of the reeds.",
    P("Listening Blade", "After a few seconds without being hit, their next attack is a sure critical.", "out_of_combat", stat="crit", amount=1.0, cd=6.0),
    A("Reed Cut", "Dashes through an enemy, cutting as they pass.", ["damage", "mobility"], "line"),
    A("Wading Sweep", "Sweeps the shallows around them, hurting and slowing enemies.", ["damage", "cc"], "area", cc="slow", range_x=0.0),
    A("Mire Guard", "A shield that is larger for every enemy close to them.", ["shield"], "self"),
    A("Thousandth Stroke", "Leaps to an enemy and strikes again and again; it hurts more the lower their health.", ["damage", "mobility", "execute"], "enemy", range_x=1.5))
K["vellgrim"] = ("Ice Ferryman", "Poles the frozen channels and charges a toll no one wants to pay.",
    P("Cold Wake", "Enemies hurt by their abilities are briefly slowed.", "on_ability", cc="slow", cc_s=1.0),
    A("Pole Vault", "Vaults to a spot and hurts enemies where they land.", ["damage", "mobility"], "area"),
    A("Black Ice", "Freezes the ground: enemies inside are slowed, then rooted.", ["zone", "cc"], "area", cc="root", cc_x=0.8),
    A("Rime Coat", "Coats themselves in frost for a shield.", ["shield"], "self"),
    A("Crossing Toll", "Poles across to an area; after a short pause every enemy around them is stunned.", ["damage", "mobility", "cc"], "area", cc="stun", dash_u=0.05, radius_u=0.035))
K["barrowick"] = ("Gravedigger", "Digs the barrow-fields and never forgets who owes them a burial.",
    P("Earthen Debt", "Each takedown permanently adds a little attack damage.", "on_kill", stat="atk", amount=3.0, max_stacks=10),
    A("Spade Toss", "Hurls the spade in a line; it hurts and slows the first enemy hit.", ["damage", "cc"], "line", cc="slow"),
    A("Grave Rush", "Dashes to an enemy and stuns them on arrival.", ["damage", "mobility", "cc"], "enemy", cc="stun", range_x=1.6),
    A("Turned Soil", "Recovers health over a few seconds.", ["heal"], "self", dur_s=3.0),
    A("Unearthing", "Throws an enemy into the air and buries them in heavy damage.", ["damage", "cc"], "enemy", cc="knockup", range_x=1.3))

# =========================================================================================== JUNGLE
K["tuskal"] = ("Boar Hunter", "Wears the tusks of the first boar they ever brought down.",
    P("Rootsnout", "Deals more damage to monsters and towers.", "vs_structure", stat="dmg_amp", amount=0.20),
    A("Tusk Gore", "Rams an enemy, hurting them and knocking them up.", ["damage", "mobility", "cc"], "enemy", cc="knockup", cc_x=0.6, range_x=1.4),
    A("Hide Bristle", "Raises their bristles for a shield and hurts enemies around them.", ["damage", "shield"], "area", range_x=0.0),
    A("Trample", "Stamps the ground, hurting everything nearby; good on camps and waves.", ["damage", "wave"], "area", range_x=0.0),
    A("Tuskline Run", "Charges a long way in a line, hurting and slowing all enemies they pass.", ["damage", "mobility", "cc"], "line", cc="slow", dash_u=0.08, range_x=1.8))
K["gravenstone"] = ("Walking Menhir", "A standing stone that woke when the island was young.",
    P("Weathered", "Takes less damage while above half health.", "low_hp", stat="dr", amount=0.08),
    A("Tumbling Slab", "Tips a slab in a line that knocks the first enemy into the air.", ["damage", "cc"], "line", cc="knockup"),
    A("Rooted Sentinel", "Plants itself: nearby enemies are forced to attack it.", ["cc", "buff"], "area", cc="taunt", range_x=0.0, buff={"armor": 20}),
    A("Slate Skin", "Hardens for extra armour and resistance.", ["buff"], "self", buff={"armor": 30, "resist": 30}),
    A("Standing Circle", "Raises a ring of stones round an area; after a moment every enemy inside is stunned.", ["damage", "zone", "cc"], "area", cc="stun", radius_u=0.04, range_x=1.4, cast_s=0.6))
K["nimbrel"] = ("Moth Trickster", "Flits between lantern and lantern, laughing.",
    P("Wingdust", "After a few seconds out of combat, fades from sight until they attack.", "out_of_combat", stat="stealth", amount=1.0, cd=8.0),
    A("Flutter Strike", "Darts to an enemy and strikes.", ["damage", "mobility"], "enemy", range_x=1.5),
    A("Pollen Haze", "Bursts a cloud that hurts and slows enemies inside.", ["damage", "zone", "cc"], "area", cc="slow"),
    A("Moult", "Sheds their wings and dashes away, untouchable for a moment.", ["mobility", "buff"], "self", buff={"untargetable": 0.5}, dur_s=0.5),
    A("Nightmoth Swarm", "Sends a swarm at an enemy that bursts after a moment; finishes off weakened targets.", ["damage", "execute"], "enemy", range_x=1.4, exec_below=0.30))
K["marrek"] = ("Peat Cutter", "Cuts the bog for fuel and has never once been cold.",
    P("Harvest Rhythm", "Each enemy hit by their abilities heals them a little.", "on_ability", heal=18),
    A("Wide Swathe", "Sweeps the scythe in a wide arc; clears waves and camps.", ["damage", "wave"], "area", range_x=0.5),
    A("Hook the Sheaf", "Hooks an enemy, slowing them heavily.", ["damage", "cc"], "enemy", cc="slow", cc_x=1.3),
    A("Bale Guard", "Raises a shield of bound straw.", ["shield"], "self"),
    A("Reaping Season", "Spins for three seconds, hurting everything near them; attacks faster afterwards.", ["damage", "buff"], "area", range_x=0.0, buff={"aspd": 0.30}, dur_s=3.0, radius_u=0.03))
K["quillith"] = ("Quill Archer", "Grows their own arrows and is very particular about who gets them.",
    P("Barbed", "Every third hit on the same enemy roots them for a moment.", "on_hit_nth", every=3, cc="root", cc_s=0.6),
    A("Quill Volley", "Looses a fan of quills, hurting enemies in front; clears waves.", ["damage", "wave"], "area"),
    A("Burrow", "Dives into the ground and resurfaces a short way off.", ["mobility"], "self"),
    A("Bristle Snare", "Leaves a snare that roots the first enemy to step on it.", ["cc", "zone"], "area", cc="root", dur_s=20.0),
    A("Hedgerow Storm", "Fires a long line of quills, hurting and slowing all enemies in it.", ["damage", "cc"], "line", cc="slow", range_x=2.2))
K["wyldrim"] = ("Hart Warden", "Leads the herds of the high meadow and defends them with their crown.",
    P("Herd Sense", "Allies near them gain a little armour.", "aura", stat="armor", amount=8.0),
    A("Antler Rush", "Rushes an enemy and gores them.", ["damage", "mobility"], "enemy", range_x=1.5),
    A("Bellow", "Roars: enemies around are slowed, allies around move faster.", ["cc", "buff"], "area", cc="slow", range_x=0.0, buff={"ally_move": 0.20}),
    A("Spring Leap", "Leaps to an ally and shields them both.", ["mobility", "shield"], "ally"),
    A("Stag Guard", "Plants their crown: allies nearby gain a large shield and enemies are thrown back.", ["shield", "cc"], "area", cc="knockup", range_x=0.0, radius_u=0.035))
K["sootwing"] = ("Chimney Crow", "Nests in the smokestacks of the old forges and strikes from the soot.",
    P("Ash Brand", "Their abilities brand an enemy; their next attack on a branded enemy burns for extra damage.", "on_ability", bonus_dmg=40, ratio=0.4),
    A("Cinder Feather", "Throws a burning feather in a line.", ["damage"], "line"),
    A("Flue Dive", "Blinks a short distance through the smoke.", ["mobility"], "self", dash_u=0.035),
    A("Sootcloak", "Vanishes in smoke for a few seconds.", ["stealth", "buff"], "self", buff={"move": 0.15}),
    A("Chimney Fall", "Drops on an enemy from above; heavy damage that finishes off weakened targets.", ["damage", "mobility", "execute"], "enemy", range_x=1.6))
K["veshra"] = ("Mere Dancer", "Dances the eel-blades across the lake at night; few see the dance and walk away.",
    P("Slick", "After a dash their next attack deals extra damage.", "on_ability", bonus_dmg=35, ratio=0.35),
    A("Eelcoil Lash", "Spins the blades around them, hurting everyone near; clears waves.", ["damage", "wave"], "area", range_x=0.0),
    A("Eelslip Dash", "Slips through enemies in a line, hurting them.", ["damage", "mobility"], "line"),
    A("Brackish Veil", "A thin veil of water blocks the next enemy ability.", ["shield"], "self", shield_x=0.7),
    A("Tide Severance", "Becomes a rush of water down a line, cutting every enemy in it; finishes off the weakened.", ["damage", "mobility", "execute"], "line", range_x=1.4, dash_u=0.06))

# =========================================================================================== MID
K["ellowen"] = ("Willow Singer", "Sings to the will-o'-lights and they sing back.",
    P("Lilt", "Each ability they land shortens their other cooldowns a little.", "on_ability", stat="cd_cut", amount=0.5),
    A("Wisp Arc", "Sends a wisp in a long arc that hurts the first enemy hit.", ["damage"], "line", range_x=1.2),
    A("Hush Ring", "A ring of silence: enemies inside cannot cast for a moment.", ["damage", "cc"], "area", cc="silence"),
    A("Drift", "Floats away faster with a small shield.", ["mobility", "shield"], "self", shield_x=0.6),
    A("Willow Chorus", "After a short song, a wide area of light hurts every enemy in it; clears waves.", ["damage", "wave"], "area", radius_u=0.04, range_x=1.4))
K["cindrel"] = ("Kiln Mage", "Fired pots for the hill villages until the kiln began to answer.",
    P("Fired Clay", "Each ability they cast hardens their skin with a small shield.", "on_ability", shield=22),
    A("Firebrick", "Throws a glowing brick in a line.", ["damage"], "line", range_x=1.2),
    A("Slag Pool", "Pours molten slag: enemies in it are burned and slowed; clears waves.", ["damage", "zone", "cc", "wave"], "area", cc="slow"),
    A("Kiln Door", "Steps back through a door of heat, leaving the ground behind them burning.", ["mobility", "damage", "zone"], "area", range_x=0.0),
    A("Furnace Breath", "Breathes a long cone of fire for heavy damage.", ["damage", "wave"], "line", range_x=1.1, radius_u=0.03))
K["dusken"] = ("Lamp Snuffer", "Walks the streets at dusk putting out the lamps, and anyone else.",
    P("Snuffed", "Deals extra damage to enemies below a third of their health.", "low_hp", stat="dmg_amp", amount=0.15),
    A("Wick Snip", "Dashes to an enemy and cuts.", ["damage", "mobility"], "enemy", range_x=1.5),
    A("Gloomstep", "Fades from sight for a few seconds.", ["stealth"], "self"),
    A("Ash Ward", "Blocks the next enemy ability.", ["shield"], "self", shield_x=0.7),
    A("Lights Out", "Darkens an area: enemies inside are silenced and hurt; finishes the weakened.", ["damage", "cc", "execute"], "area", cc="silence"))
K["maurelle"] = ("Tidepool Sorceress", "Reads the rock pools at low water and knows what the sea intends.",
    P("Rockpool", "Allies near them slowly regain health.", "aura", heal=4),
    A("Brine Burst", "Bursts a ball of brine in an area; clears waves.", ["damage", "wave"], "area"),
    A("Kelp Snare", "Wraps an enemy in kelp, rooting them.", ["cc"], "line", cc="root"),
    A("Tidecup", "Shields an ally with a cup of seawater.", ["shield"], "ally"),
    A("Rising Pool", "Floods an area: allies inside are shielded, enemies inside are slowed and hurt.", ["damage", "zone", "cc", "shield"], "area", cc="slow", radius_u=0.04, dur_s=4.0))
K["orisande"] = ("Star Cartographer", "Draws the maps by night and plots a course straight through their enemies.",
    P("Plotted Course", "Moves faster toward an enemy they have marked.", "on_ability", stat="move", amount=0.15),
    A("Compass Needle", "Throws a needle in a long line that hurts and marks the first enemy.", ["damage"], "line", range_x=1.4),
    A("Meridian Bind", "Roots a marked enemy where they stand.", ["cc"], "enemy", cc="root", range_x=1.6),
    A("Waypoint", "Blinks to a point they have charted.", ["mobility"], "self", dash_u=0.04),
    A("Fixed Star", "Calls down a star on a distant enemy: heavy damage and a stun.", ["damage", "cc"], "enemy", cc="stun", range_x=2.5))
K["tessarine"] = ("Mosaic Glazier", "Builds windows from broken glass, and the light comes out sharper.",
    P("Tesserae", "Each ability adds a tile; with every tile their abilities hit harder.", "on_ability", stat="ap", amount=4.0, max_stacks=10),
    A("Shard Fan", "Throws a fan of glass shards in front of them; clears waves.", ["damage", "wave"], "area"),
    A("Leaded Pane", "Raises a pane of glass that slows enemies who cross it.", ["zone", "cc"], "area", cc="slow"),
    A("Refract", "Bends the next enemy ability away.", ["shield"], "self", shield_x=0.7),
    A("Rose Window", "A great round window of light forms over an area; enemies inside are stunned and hurt.", ["damage", "cc"], "area", cc="stun", radius_u=0.04, cast_s=0.8))
K["lanthorn"] = ("Lantern Spirit", "The spirit of a ship's lantern that never went out.",
    P("Kept Flame", "When badly hurt, gains a shield (once a minute).", "low_hp", shield=120, cd=60.0),
    A("Moth Light", "Sends a light in a line that hurts and slows.", ["damage", "cc"], "line", cc="slow"),
    A("Lantern Leash", "Leashes an enemy to the lantern; if they stay close, they are rooted.", ["cc"], "enemy", cc="root", range_x=1.4),
    A("Flicker", "Flickers out and reappears a short way off.", ["mobility"], "self", dash_u=0.035),
    A("Shuttered Glow", "Opens the lantern wide: every enemy around is stunned.", ["damage", "cc"], "area", cc="stun", range_x=0.0, radius_u=0.035))
K["embrel"] = ("Ember Apprentice", "Burns most of what they touch and is learning to choose.",
    P("Cinderdrift", "Their attacks splash sparks on nearby minions.", "on_hit_nth", every=1, bonus_dmg=8, ratio=0.1, dtype="magic"),
    A("Ember Toss", "Tosses an ember that hurts an enemy from a distance.", ["damage"], "enemy", range_x=1.4),
    A("Smoulder", "Sets the ground smouldering, hurting enemies over time; clears waves.", ["damage", "zone", "wave"], "area"),
    A("Bellows Kick", "Blasts a nearby enemy back with a gust.", ["cc"], "enemy", cc="knockup", cc_x=0.5),
    A("Wildfire Seed", "Plants a seed of fire that bursts over a wide area.", ["damage", "wave"], "area", radius_u=0.04))

# =========================================================================================== BOT
K["harkin"] = ("Harpoon Gunner", "Hunted the whales of the grey sea; now they hunt in lanes.",
    P("Steady Aim", "Standing still raises their critical chance.", "out_of_combat", stat="crit", amount=0.15),
    A("Harpoon Shot", "Fires a harpoon in a line that hurts and slows.", ["damage", "cc"], "line", cc="slow", range_x=1.2),
    A("Chain Volley", "Sprays shot over an area; clears waves.", ["damage", "wave"], "area"),
    A("Kick Back", "Fires and leaps backward.", ["mobility"], "self"),
    A("Whaler's Mark", "A long, slow shot that hits the first enemy for heavy damage.", ["damage"], "line", range_x=3.0, hit=0.7))
K["pellam"] = ("Shepherd Slinger", "Kept a hillside flock and never lost a sheep to wolves.",
    P("Shepherd's Count", "Every fourth attack heals them a little.", "on_hit_nth", every=4, heal=30),
    A("Sling Stone", "Slings a stone that hurts and slows an enemy.", ["damage", "cc"], "enemy", cc="slow", range_x=1.1),
    A("Crook Pull", "Hooks an ally out of danger and shields them.", ["shield", "mobility"], "ally"),
    A("Hedge Hop", "Hops a short way.", ["mobility"], "self"),
    A("Flock Volley", "Rains stones over an area.", ["damage", "wave"], "area", radius_u=0.035))
K["tamsel"] = ("Belfry Marksman", "Rings the hours from the old tower, each one precisely.",
    P("Resonance", "Every third attack rings on to a second enemy.", "on_hit_nth", every=3, bonus_dmg=30, ratio=0.3, dtype="magic"),
    A("Peal", "A ringing shot in a line.", ["damage"], "line", range_x=1.2),
    A("Muffle", "Silences an enemy for a moment.", ["cc"], "enemy", cc="silence", range_x=1.2),
    A("Tolling Step", "Steps aside and shields themselves and a nearby ally.", ["mobility", "shield"], "ally"),
    A("Carillon", "Rings a peal of bells over an area for heavy damage.", ["damage", "wave"], "area", radius_u=0.035, cast_s=0.6))
K["jorreck"] = ("Dock Brawler", "Loads cargo by day and settles debts with a crossbow by night.",
    P("Ratchet", "Attacks the same enemy faster with each hit.", "on_hit_nth", every=1, stat="aspd", amount=0.06, max_stacks=5),
    A("Bolt Burst", "Fires a spread of bolts in front.", ["damage", "wave"], "area"),
    A("Dockhook", "Swings on a hook to a nearby spot.", ["mobility"], "self", dash_u=0.035),
    A("Tarpaulin", "Throws a tarp over themselves or an ally for a shield.", ["shield"], "ally"),
    A("Broadside", "Fires everything at once down a line.", ["damage"], "line", range_x=1.5))
K["brixley"] = ("Mortar Mason", "Lays bricks in peacetime; in war they lay them on people.",
    P("Mortar Splash", "Attacks splash a little and deal extra damage to towers.", "vs_structure", stat="dmg_amp", amount=0.20),
    A("Lob", "Lobs a shell into an area.", ["damage", "wave"], "area", range_x=1.2),
    A("Scaffold", "Jumps up and over to a nearby spot.", ["mobility"], "self"),
    A("Brick Cover", "Puts up a low wall for a shield.", ["shield"], "self"),
    A("Demolition", "Shells a long strip of ground for heavy damage.", ["damage", "wave"], "line", range_x=2.0, radius_u=0.03))
K["dovrin"] = ("Dove Magus", "Fires a wand-gun charged with feathers and old blessings.",
    P("Feathered Shot", "Hitting an enemy gives a short burst of speed.", "on_hit_nth", every=1, stat="move", amount=0.10),
    A("Quill Ray", "A beam of light in a line.", ["damage"], "line", range_x=1.2),
    A("Coo", "A soft call slows enemies in an area.", ["cc"], "area", cc="slow"),
    A("Wing Step", "Steps on the wind a short way.", ["mobility"], "self"),
    A("Flight of Doves", "Releases a flight of glowing doves over an area.", ["damage", "wave"], "area", radius_u=0.035))
K["ketterick"] = ("Steam Gunner", "Built their own boiler-rifle and only sometimes scalds themselves.",
    P("Pressure", "Abilities build pressure; at full pressure their next attack stuns.", "on_ability", every=3, cc="stun", cc_s=0.75),
    A("Steam Jet", "A scalding jet in a line.", ["damage"], "line", range_x=1.2),
    A("Scald Trap", "Sets a trap that roots the first enemy to trip it.", ["cc", "zone"], "area", cc="root", dur_s=20.0),
    A("Vent", "Vents steam to dash, slowing enemies behind.", ["mobility", "cc"], "self", cc="slow"),
    A("Boiling Point", "Overloads the boiler on one enemy: heavy damage and a stun.", ["damage", "cc"], "enemy", cc="stun", range_x=1.5))
K["sparrowe"] = ("Hedge Archer", "Quick as a sparrow and twice as cheeky.",
    P("Flitting", "After a dash they attack faster for a few seconds.", "on_ability", stat="aspd", amount=0.30),
    A("Pinfeather Arrow", "A swift arrow in a line.", ["damage"], "line", range_x=1.2),
    A("Scatter Shot", "Looses a scatter of arrows in front; clears waves.", ["damage", "wave"], "area"),
    A("Hop", "Hops a short way.", ["mobility"], "self"),
    A("Daybreak Flurry", "A rapid barrage over an area.", ["damage", "wave"], "area", radius_u=0.035))

# =========================================================================================== SUPPORT
K["sunnivah"] = ("Dial Priestess", "Tends the great sundial and its slow, warm shadow.",
    P("Noon Mark", "Their heals are stronger on badly hurt allies.", "low_hp", stat="heal_amp", amount=0.30),
    A("Gnomon Ray", "A ray of light in a line that hurts and slows.", ["damage", "cc"], "line", cc="slow"),
    A("Warm Hands", "Heals an ally.", ["heal"], "ally"),
    A("Shade Shift", "Shields an ally in a cool shadow.", ["shield"], "ally"),
    A("Solstice Halo", "A halo of light over an area heals every ally inside.", ["heal"], "area", radius_u=0.04, range_x=0.0))
K["bastrel"] = ("Shell Knight", "A hermit crab who found a helmet and never gave it back.",
    P("Shell Guard", "When first hit after a rest, gains a shield.", "out_of_combat", shield=90, cd=12.0),
    A("Claw Snap", "Snaps at an enemy, hurting and slowing them.", ["damage", "cc"], "enemy", cc="slow"),
    A("Pincer Grip", "Grips an enemy in their claw and holds them still.", ["damage", "cc"], "enemy", cc="stun", range_x=1.2),
    A("Shell Up", "Pulls into their shell, taking much less damage.", ["buff"], "self", buff={"dr": 0.35}, dur_s=2.0),
    A("Sidelong Surge", "Rushes sideways down a line like a breaking wave, throwing up every enemy in it.", ["damage", "mobility", "cc"], "line", cc="knockup", dash_u=0.06, range_x=1.4))
K["tanglewick"] = ("Root Witch", "Lives in a hollow willow and knows every root on the island.",
    P("Tangled", "Roots last longer on slowed enemies.", "on_ability", stat="cc_amp", amount=0.30),
    A("Root Lance", "Sends a root along the ground that roots the first enemy hit.", ["damage", "cc"], "line", cc="root", range_x=1.2),
    A("Wick Burn", "Burns an enemy from a distance.", ["damage"], "enemy", range_x=1.3),
    A("Twine", "Twines a vine to an ally, shielding them.", ["shield"], "ally"),
    A("Thicket Snare", "Thick roots burst from an area, rooting every enemy in it.", ["damage", "cc"], "area", cc="root", radius_u=0.035))
K["alderwyn"] = ("Alder Healer", "An alder tree that walked down to the river to help.",
    P("Sap", "Healing they give leaves a small shield.", "on_ability", shield=25),
    A("Catkin Burst", "Bursts catkins in an area, hurting enemies and healing allies; clears waves.", ["damage", "heal", "wave"], "area"),
    A("Bark Ward", "Shields an ally with bark.", ["shield"], "ally"),
    A("Root Mend", "Heals an ally over a few seconds.", ["heal"], "ally", dur_s=3.0),
    A("Grove Rising", "Raises a grove: allies inside heal, enemies inside are slowed.", ["heal", "zone", "cc"], "area", cc="slow", radius_u=0.04, dur_s=4.0))
K["corvane"] = ("Raven Shield", "Carries a shield painted with the eye of a raven that never blinks.",
    P("Raven's Eye", "Their first hit on an enemy marks them; allies deal extra damage to the marked.", "on_hit_nth", every=1, stat="mark", amount=0.08),
    A("Wingbeat", "Leaps at an enemy, knocking them up.", ["damage", "mobility", "cc"], "enemy", cc="knockup", range_x=1.4),
    A("Caw", "A harsh cry: nearby enemies are forced to turn on them.", ["cc"], "area", cc="taunt", range_x=0.0),
    A("Feather Mantle", "Shields themselves and an ally.", ["shield"], "ally"),
    A("Black Pinions", "Dives from above into an area, stunning every enemy there.", ["damage", "mobility", "cc"], "area", cc="stun", dash_u=0.06, range_x=1.5))
K["wyncote"] = ("Mill Binder", "Built the windmills on the ridge and taught them to fight.",
    P("Vane Wake", "Their dashes leave a gust that slows enemies.", "on_ability", cc="slow", cc_s=1.0),
    A("Sail Slash", "Cuts a line with a sail-blade.", ["damage"], "line"),
    A("Millstone Bind", "Drops a millstone on an enemy, rooting them.", ["cc"], "enemy", cc="root", range_x=1.3),
    A("Draft", "Rides a draft of wind a short way.", ["mobility"], "self"),
    A("Whirling Vane", "A whirlwind draws enemies in an area together and stuns them.", ["damage", "cc"], "area", cc="stun", radius_u=0.035))
K["oriel"] = ("Window Spirit", "The light that falls through the chapel window, given a will.",
    P("Dappled", "Their heals leave a small shield behind.", "on_ability", shield=20),
    A("Prism Bolt", "A bolt of split light hurts an enemy; clears waves.", ["damage", "wave"], "enemy", range_x=1.3),
    A("Lumen", "Heals an ally.", ["heal"], "ally"),
    A("Glasswall", "Shields an ally behind coloured glass.", ["shield"], "ally"),
    A("Clerestory", "Floods a wide area with light, healing every ally inside.", ["heal"], "area", radius_u=0.045, range_x=0.0))
K["fennimore"] = ("Fen Elder", "A very old frog who has been right about everything for a very long time.",
    P("Croak", "Every third ability also slows the enemies it hits.", "on_ability", every=3, cc="slow", cc_s=1.0),
    A("Lily Lob", "Lobs a lily pad that bursts in an area, hurting and slowing; clears waves.", ["damage", "cc", "wave"], "area", cc="slow"),
    A("Bog Bind", "Binds an enemy in bog-weed, rooting them.", ["cc"], "line", cc="root"),
    A("Leap Frog", "Leaps a short way.", ["mobility"], "self"),
    A("Fen Fog", "A thick fog over an area: enemies inside are silenced and slowed.", ["cc", "zone"], "area", cc="silence", radius_u=0.04, dur_s=3.0))


def main():
    assert set(K) == set(HEROES), set(HEROES) ^ set(K)
    out = []
    for hid in HEROES:   # heroes.json order
        title, lore, pas, a1, a2, a3, ult = K[hid]
        abil = [ability(hid, s, i, a) for i, (s, a) in enumerate(zip(["a1", "a2", "a3", "ult"], [a1, a2, a3, ult]))]
        out.append({"id": hid, "kit_version": 1, "title": title, "lore": lore, "stats": stats(hid),
                    "passive": passive(hid, pas), "abilities": abil})
    doc = {"schema": "gloamline/kits", "version": 1, "note": "Generated by tools/gen_kits.py; do not edit by hand. Numbers are v0 placeholders scaled by sim_v2_params.json.", "kits": out}
    (ROOT / "game/data/kits_v2.json").write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
    print(f"kits_v2.json: {len(out)} heroes, {sum(len(k['abilities']) + 1 for k in out)} abilities")


if __name__ == "__main__":
    main()
