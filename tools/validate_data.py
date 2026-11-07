"""Validate game data against the JSON schemas and the rules JSON Schema cannot express.

Usage: python3 tools/validate_data.py [data_dir]   (default: game/data)
Checks, for every *.json that is not a schema:
  heroes:  power_early + power_mid + power_late == 144 + 3*difficulty; ids unique;
           strong_vs refers to existing hero ids (within the file); no self-counter
  players: potential >= stat for all 8 stats and <= 99; ids unique
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

def validate_dir(data_dir):
    data_dir = pathlib.Path(data_dir)
    hs, ps = load(data_dir / "schema/hero.schema.json"), load(data_dir / "schema/player.schema.json")
    errs = []
    for f in sorted(data_dir.rglob("*.json")):
        if "schema" in f.parts: continue
        if f.name.startswith("heroes"): errs += [f"{f.name}: {e}" for e in check_heroes(load(f), hs)]
        elif f.name.startswith("players"): errs += [f"{f.name}: {e}" for e in check_players(load(f), ps)]
    return errs

if __name__ == "__main__":
    errs = validate_dir(sys.argv[1] if len(sys.argv) > 1 else ROOT / "game/data")
    print("\n".join(errs) if errs else "data OK")
    sys.exit(1 if errs else 0)
