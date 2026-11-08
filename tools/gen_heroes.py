"""Content Lead: the 40-hero set v0 (task D-008/D-005). Writes game/data/heroes.json and docs/design/HERO-SET-v0.md.

Names are PLACEHOLDERS (placeholder: true): invented, screened only against the reference-name block list,
not yet by the IP Checker or a store/trademark search. Rename by editing this table and re-running.
Tags and damage types are then tuned by tools/tune_tags.py (tools/hero_overrides.json) so composition scoring behaves (see test_content.py).
Counter graph (strong_vs): inside each slot, hero i counters hero i+1 and hero i+3 (mod 8), so nobody counters
anybody mutually and every hero is countered by exactly two others; every Support also counters the Gunner of the same
index (bot-lane links). Order inside each slot below is therefore a deliberate rock-paper-scissors cycle.
"""
import json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
# Display-name changes after the IP scan (2026-11-09). The id stays the ORIGINAL lower-case name on purpose: ids are
# stable keys in saves, golden vectors and overrides, so a rename changes only the shown name, never the id.
DISPLAY_RENAMES = {"orrick": "Orlund", "tuskal": "Tarskel"}
SHAPES = {  # (early, mid, late) offsets from the budget average, each sums to 0
    "steady": (0, 0, 0), "early": (6, 1, -7), "early_mid": (4, 3, -7), "mid": (-4, 8, -4),
    "mid_late": (-7, 3, 4), "late": (-8, 0, 8), "spike": (5, -9, 4),
}
# name, archetype, secondary role, extra tags, damage, range, difficulty, power shape
SLOTS = {
 "top": [
  ("Brannoch",   "bruiser", "jg",  ["splitpush", "waveclear"], "physical", "melee", 2, "early"),
  ("Dunmarrow",  "bulwark", None,  ["protect"],                "physical", "melee", 1, "steady"),
  ("Skarrow",    "bruiser", "jg",  ["pick"],                   "physical", "melee", 3, "early"),
  ("Hegwin",     "bruiser", "mid", ["poke"],                   "mixed",    "mid",   3, "mid"),
  ("Ottomere",   "bulwark", None,  ["scaling"],                "physical", "melee", 2, "late"),
  ("Orrick",     "bruiser", None,  ["splitpush", "scaling"],   "physical", "melee", 4, "late"),
  ("Vellgrim",   "bulwark", "sup", ["waveclear"],              "physical", "melee", 3, "steady"),
  ("Barrowick",  "bruiser", None,  ["engage"],                 "physical", "melee", 2, "early"),
 ],
 "jg": [
  ("Tuskal",     "bruiser", "top", ["pick"],                   "physical", "melee", 2, "early"),
  ("Gravenstone","bulwark", "top", [],                         "physical", "melee", 2, "mid"),
  ("Nimbrel",    "shade",   None,  ["splitpush"],              "physical", "melee", 4, "spike"),
  ("Marrek",     "bruiser", None,  ["waveclear", "scaling"],   "physical", "melee", 3, "late"),
  ("Quillith",   "shade",   "mid", ["poke"],                   "magic",    "mid",   3, "spike"),
  ("Wyldrim",    "bruiser", "top", ["engage"],                 "physical", "melee", 3, "early"),
  ("Sootwing",   "shade",   None,  ["scaling"],                "magic",    "mid",   5, "late"),
  ("Veshra",     "shade",   None,  ["engage"],                 "physical", "melee", 3, "early"),
 ],
 "mid": [
  ("Ellowen",    "spellcaster", None,  ["poke"],               "magic",    "long",  2, "early"),
  ("Cindrel",    "spellcaster", None,  ["scaling"],            "magic",    "long",  3, "late"),
  ("Dusken",     "shade",       "jg",  ["waveclear"],          "mixed",    "mid",   4, "spike"),
  ("Maurelle",   "spellcaster", None,  ["engage"],             "magic",    "mid",   3, "mid"),
  ("Orisande",   "binder",      "sup", ["poke"],               "magic",    "long",  4, "spike"),
  ("Tessarine",  "spellcaster", None,  ["scaling", "poke"],    "magic",    "long",  4, "late"),
  ("Lanthorn",   "binder",      "sup", ["engage"],             "magic",    "mid",   2, "late"),
  ("Embrel",     "spellcaster", "top", ["splitpush"],          "magic",    "mid",   1, "early"),
 ],
 "bot": [
  ("Harkin",     "gunner", None,  ["poke"],                    "physical", "long",  2, "late"),
  ("Pellam",     "gunner", None,  ["waveclear"],               "physical", "long",  1, "late"),
  ("Tamsel",     "gunner", None,  ["pick"],                    "mixed",    "long",  4, "late"),
  ("Jorreck",    "gunner", "mid", ["engage"],                  "physical", "mid",   3, "steady"),
  ("Brixley",    "gunner", None,  ["splitpush"],               "physical", "long",  3, "late"),
  ("Dovrin",     "gunner", "mid", ["poke", "waveclear"],       "magic",    "long",  2, "steady"),
  ("Ketterick",  "gunner", None,  ["pick"],                    "physical", "long",  5, "late"),
  ("Sparrowe",   "gunner", None,  ["waveclear", "poke"],       "physical", "long",  3, "early"),
 ],
 "sup": [
  ("Sunnivah",   "mender",  "mid", ["scaling"],                "magic",    "mid",   2, "late"),
  ("Bastrel",    "bulwark", "top", ["protect"],                "physical", "melee", 2, "early"),
  ("Tanglewick", "binder",  "mid", ["poke"],                   "magic",    "long",  3, "mid"),
  ("Alderwyn",   "mender",  None,  ["poke"],                   "magic",    "mid",   3, "steady"),
  ("Corvane",    "bulwark", "jg",  ["pick"],                   "physical", "melee", 3, "early"),
  ("Wyncote",    "binder",  None,  ["engage"],                 "magic",    "mid",   4, "early_mid"),
  ("Oriel",      "mender",  None,  ["waveclear"],              "magic",    "long",  1, "steady"),
  ("Fennimore",  "binder",  None,  ["protect"],                "magic",    "mid",   3, "late"),
 ],
}
DEFAULT_TAGS = {"bruiser": ["frontline"], "bulwark": ["frontline", "engage"], "spellcaster": ["waveclear"],
                "gunner": ["scaling"], "shade": ["pick"], "mender": ["protect"], "binder": ["pick"]}


def powers(difficulty, shape):
    total = 144 + 3 * difficulty
    base = total / 3.0
    raw = [base + o for o in SHAPES[shape]]
    vals = [int(round(v)) for v in raw]
    vals[1] += total - sum(vals)            # rounding fix goes to mid
    assert sum(vals) == total and all(38 <= v <= 62 for v in vals), (difficulty, shape, vals)
    return vals


def load_overrides():
    f = ROOT / "tools/hero_overrides.json"       # written by tools/tune_tags.py
    return json.loads(f.read_text()) if f.exists() else {}


def build():
    heroes = []
    ov = load_overrides()
    for slot, rows in SLOTS.items():
        ids = [r[0].lower() for r in rows]
        for i, (name, arch, sec, extra, dmg, rng, diff, shape) in enumerate(rows):
            o = ov.get(name.lower())
            if o:
                extra, dmg = o["extra"], o["damage"]
            tags = list(dict.fromkeys(DEFAULT_TAGS[arch] + extra))
            e, m, l = powers(diff, shape)
            counters = [ids[(i + 1) % 8], ids[(i + 3) % 8]]
            if slot == "sup":
                counters.append(SLOTS["bot"][i][0].lower())
            heroes.append({"id": name.lower(), "name": DISPLAY_RENAMES.get(name.lower(), name), "placeholder": True, "archetype": arch,
                           "role_primary": slot, "role_secondary": sec,
                           "power_early": e, "power_mid": m, "power_late": l,
                           "damage_type": dmg, "range": rng, "difficulty": diff,
                           "tags": tags, "strong_vs": counters})
    return heroes


def write_doc(heroes):
    lines = ["# Hero set v0 (generated by `tools/gen_heroes.py`; do not edit by hand)", "",
             "40 placeholder heroes (names are not final and not yet IP-screened). Power is early / mid / late. "
             "`Counters` are the heroes it is strong against.", ""]
    names = {h["id"]: h["name"] for h in heroes}
    for slot in ("top", "jg", "mid", "bot", "sup"):
        lines += ["## %s" % {"top": "Top", "jg": "Jungle", "mid": "Mid", "bot": "Bot Carry", "sup": "Support"}[slot], "",
                  "| Hero | Archetype | Tags | Damage / range | Diff | Power E/M/L | Counters |", "|---|---|---|---|---|---|---|"]
        for h in heroes:
            if h["role_primary"] != slot: continue
            lines.append("| %s | %s | %s | %s / %s | %d | %d/%d/%d | %s |" % (
                h["name"], h["archetype"].title(), ", ".join(t.title() for t in h["tags"]), h["damage_type"], h["range"],
                h["difficulty"], h["power_early"], h["power_mid"], h["power_late"],
                ", ".join(names[c] for c in h["strong_vs"])))
        lines.append("")
    (ROOT / "docs/design/HERO-SET-v0.md").write_text("\n".join(lines))


if __name__ == "__main__":
    hs = build()
    (ROOT / "game/data/heroes.json").write_text(json.dumps(hs, indent=1) + "\n")
    write_doc(hs)
    print("wrote", len(hs), "heroes")
