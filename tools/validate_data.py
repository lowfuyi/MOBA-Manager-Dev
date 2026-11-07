"""Validate game data against the JSON schemas and the rules JSON Schema cannot express.

Usage: python3 tools/validate_data.py [data_dir]   (default: game/data)
Checks, for every *.json that is not a schema:
  heroes:  power_early + power_mid + power_late == 144 + 3*difficulty; ids unique;
           strong_vs refers to existing hero ids (within the file); no self-counter
  players: potential >= stat for all 8 stats and <= 99; ids unique
  clubs + world: rosters exist, role guarantee, unique names, block list, hero/club name collisions
Files named heroes*.json and players*.json are picked by name.
"""
import json, pathlib, sys
from jsonschema import Draft202012Validator

ROOT = pathlib.Path(__file__).resolve().parent.parent
STATS = ["mec", "sen", "lan", "tft", "mac", "com", "con", "clu"]

def load(p): return json.loads(pathlib.Path(p).read_text())

def check_heroes(items, schema):
    errs, ids = [], set()
    v = Draft202012Validator(schema)
    for h in items:
        hid = h.get("id", "?")
        errs += [f"hero {hid}: {e.message}" for e in v.iter_errors(h)]
        if hid in ids: errs.append(f"hero {hid}: duplicate id")
        ids.add(hid)
        try:
            if h["power_early"] + h["power_mid"] + h["power_late"] != 144 + 3 * h["difficulty"]:
                errs.append(f"hero {hid}: power sum must be 144 + 3*difficulty")
        except KeyError:
            pass
    for h in items:
        for t in h.get("strong_vs", []):
            if t not in ids: errs.append(f"hero {h.get('id')}: strong_vs unknown id {t}")
            if t == h.get("id"): errs.append(f"hero {h.get('id')}: counters itself")
    return errs

def check_players(items, schema):
    errs, ids = [], set()
    v = Draft202012Validator(schema)
    for p in items:
        pid = p.get("id", "?")
        errs += [f"player {pid}: {e.message}" for e in v.iter_errors(p)]
        if pid in ids: errs.append(f"player {pid}: duplicate id")
        ids.add(pid)
        for s in STATS:
            try:
                if not (p["stats"][s] <= p["potential"][s] <= 99):
                    errs.append(f"player {pid}: potential must be >= stat and <= 99 ({s})")
            except KeyError:
                pass
    return errs

def check_clubs(items, schema):
    errs, ids = [], set()
    v = Draft202012Validator(schema)
    for c in items:
        cid = c.get("id", "?")
        errs += [f"club {cid}: {e.message}" for e in v.iter_errors(c)]
        if cid in ids: errs.append(f"club {cid}: duplicate id")
        ids.add(cid)
    return errs


def check_world(heroes, players, clubs, block):
    """Cross-file rules for the generated league (GDD section 12)."""
    errs = []
    pid = {p["id"]: p for p in players}
    seen = {}
    for c in clubs:
        roster = [pid.get(i) for i in c["player_ids"]]
        if None in roster:
            errs.append(f"club {c['id']}: unknown player id"); continue
        for p in roster:
            if p["club"] != c["id"]: errs.append(f"player {p['id']}: club field is {p['club']}, roster says {c['id']}")
            if p["id"] in seen: errs.append(f"player {p['id']}: on two rosters")
            seen[p["id"]] = c["id"]
        for slot in ("top", "jg", "mid", "bot", "sup"):
            prim = [p for p in roster if p["role_primary"] == slot]
            able = [p for p in roster if slot in (p["role_primary"], p.get("role_secondary"))]
            if len(prim) < 1 or len(able) < 2: errs.append(f"club {c['id']}: role guarantee broken for {slot}")
    for p in players:
        if p["club"] is not None and p["id"] not in seen: errs.append(f"player {p['id']}: has club {p['club']} but is on no roster")
    names = [p["name"].lower() for p in players]
    if len(set(names)) != len(names): errs.append("duplicate player names")
    forbidden = {h["name"].lower() for h in heroes} | {c["name"].lower() for c in clubs}
    for n in names:
        if n in forbidden: errs.append(f"player name {n} collides with a hero or club name")
        if any(n == b or (len(b) >= 5 and b in n) for b in block): errs.append(f"player name {n} is on the block list")
    return errs


def validate_dir(data_dir):
    data_dir = pathlib.Path(data_dir)
    hs, ps = load(data_dir / "schema/hero.schema.json"), load(data_dir / "schema/player.schema.json")
    cs = load(data_dir / "schema/club.schema.json")
    errs = []
    for f in sorted(data_dir.rglob("*.json")):
        if "schema" in f.parts or "names" in f.parts: continue
        if f.name.startswith("heroes"): errs += [f"{f.name}: {e}" for e in check_heroes(load(f), hs)]
        elif f.name.startswith("players"): errs += [f"{f.name}: {e}" for e in check_players(load(f), ps)]
        elif f.name.startswith("clubs"): errs += [f"{f.name}: {e}" for e in check_clubs(load(f), cs)]
    top = {n: data_dir / f"{n}.json" for n in ("heroes", "players", "clubs")}
    if all(f.exists() for f in top.values()):
        b = load(data_dir / "names/block_list.json")
        block = [x.lower() for x in b["handles"] + b["orgs"] + b["reference_hero_names"]]
        errs += check_world(load(top["heroes"]), load(top["players"]), load(top["clubs"]), block)
    return errs

if __name__ == "__main__":
    errs = validate_dir(sys.argv[1] if len(sys.argv) > 1 else ROOT / "game/data")
    print("\n".join(errs) if errs else "data OK")
    sys.exit(1 if errs else 0)
