"""String-table lint (translation readiness, GDD section 1).

1. every Strings.t("key") / Strings.f("key", ...) in game/src and game/tests uses a key defined in game/i18n/en.json
2. en.json has no duplicate keys
3. every other language file has the same keys and the same {placeholders} as en.json
4. warns about keys defined but never used (informational, not a failure)
Usage: python3 tools/check_strings.py
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
USE = re.compile(r'Strings\.[tf]\(\s*"([^"]+)"|\bs\.[tf]\(\s*"([^"]+)"')
PLACE = re.compile(r"\{(\w+)\}")

def load_unique(path):
    def hook(pairs):
        keys = [k for k, _ in pairs]
        dups = {k for k in keys if keys.count(k) > 1}
        if dups: raise ValueError(f"{path.name}: duplicate keys {sorted(dups)}")
        return dict(pairs)
    return json.loads(path.read_text(), object_pairs_hook=hook)

def check(root=ROOT):
    errs, notes = [], []
    i18n = root / "game/i18n"
    en = load_unique(i18n / "en.json")
    used = set()
    for f in list((root / "game/src").rglob("*.gd")) + list((root / "game/tests").rglob("*.gd")):
        for m in USE.finditer(f.read_text()):
            key = m.group(1) or m.group(2)
            if key.endswith(".") or "%s" in key:       # dynamic family: Strings.t("role." + slot)
                prefix = key.split("%s")[0]
                fam = [k for k in en if k.startswith(prefix)]
                if not fam: errs.append(f"{f.relative_to(root)}: no keys in family {key}")
                used.update(fam)
                continue
            used.add(key)
            if key not in en and "no.such.key" not in key:
                errs.append(f"{f.relative_to(root)}: unknown string key {key}")
    # families that are built from game data must cover every value in the data
    data = root / "game/data"
    heroes = json.loads((data / "heroes.json").read_text())
    for h in heroes:
        for fam, val in [("arch.", h["archetype"]), ("dmg.", h["damage_type"])] + [("tag.", t) for t in h["tags"]]:
            if fam + val not in en: errs.append(f"missing {fam}{val} (hero {h['id']})")
    for pl in json.loads((data / "players.json").read_text()):
        if "personality." + pl["personality"] not in en: errs.append(f"missing personality.{pl['personality']}")
    for other in sorted(i18n.glob("*.json")):
        if other.name == "en.json": continue
        t = load_unique(other)
        for k in en:
            if k not in t: errs.append(f"{other.name}: missing key {k}")
            elif set(PLACE.findall(en[k])) != set(PLACE.findall(t[k])): errs.append(f"{other.name}: placeholders differ for {k}")
        for k in t:
            if k not in en: errs.append(f"{other.name}: extra key {k}")
    for k in en:
        if k not in used: notes.append(k)
    return errs, notes

if __name__ == "__main__":
    errs, unused = check()
    print("\n".join(errs) if errs else "strings OK")
    print(f"({len(unused)} keys not used by code yet)")
    sys.exit(1 if errs else 0)
