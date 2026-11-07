"""One-off, reproducible tuner for hero tags and damage types (D-008).

Searches extra-tag and damage-type choices (archetype default tags and the slot/archetype/power/counter design are kept)
so that composition scoring (GDD 5.3) over all one-hero-per-slot lineups behaves sensibly. Writes tools/hero_overrides.json,
which gen_heroes.py applies. Targets are design intent, not a balance proof: P-003 tests real play.
Usage: python3 -I tools/tune_tags.py [iterations]
"""
import itertools, json, pathlib, random, sys
import numpy as np
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import gen_heroes as G
from comp import SYNERGY_PAIRS

TAGS = ["engage", "poke", "protect", "pick", "splitpush", "frontline", "waveclear", "scaling"]
TI = {t: i for i, t in enumerate(TAGS)}
OUT = pathlib.Path(__file__).resolve().parent / "hero_overrides.json"
ARCH_DAMAGE = {"spellcaster": ["magic", "mixed"], "mender": ["magic", "mixed"], "binder": ["magic", "mixed"],
               "gunner": ["physical", "magic", "mixed"], "bruiser": ["physical", "mixed"],
               "bulwark": ["physical", "mixed", "magic"], "shade": ["physical", "magic", "mixed"]}


def state_from_table():
    st = []
    for slot, rows in G.SLOTS.items():
        for (name, arch, sec, extra, dmg, rng, diff, shape) in rows:
            e, m, l = G.powers(diff, shape)
            st.append({"id": name.lower(), "slot": slot, "arch": arch, "extra": list(extra), "dmg": dmg,
                       "late_over_early": l > e, "ranged": rng != "melee"})
    return st


def allowed_extras(h):
    """Identity rules: Scaling only if late power beats early; Poke only for non-melee heroes."""
    out = [t for t in TAGS if t not in G.DEFAULT_TAGS[h["arch"]]]
    if not h["late_over_early"]: out = [t for t in out if t != "scaling"]
    if not h["ranged"]: out = [t for t in out if t != "poke"]
    return out


def arrays(st, combos):
    n = len(st)
    tag = np.zeros((n, 8), dtype=bool)
    for i, h in enumerate(st):
        for t in G.DEFAULT_TAGS[h["arch"]] + h["extra"]:
            tag[i, TI[t]] = True
    phys = np.array([1 if h["dmg"] == "physical" else 0.5 if h["dmg"] == "mixed" else 0 for h in st])
    magic = np.array([1 if h["dmg"] == "magic" else 0.5 if h["dmg"] == "mixed" else 0 for h in st])
    return tag, phys, magic


def evaluate(st, combos):
    tag, phys, magic = arrays(st, combos)
    T = tag[combos]                       # combos x 5 x 8
    cnt = T.sum(axis=1)                   # combos x 8
    has = cnt > 0
    needs = -0.03 * ((~has[:, TI["frontline"]]).astype(float) + (~(has[:, TI["engage"]] | has[:, TI["pick"]])).astype(float)
                     + (~has[:, TI["waveclear"]]).astype(float))
    ph, mg = phys[combos].sum(axis=1), magic[combos].sum(axis=1)
    bal = np.where((ph >= 3.5) | (mg >= 3.5), -0.04, 0.0)
    syn = np.zeros(len(combos))
    for a, b in SYNERGY_PAIRS:
        A, B = T[:, :, TI[a]], T[:, :, TI[b]]
        union = (A | B).sum(axis=1)
        syn += 0.025 * (A.any(axis=1) & B.any(axis=1) & (union >= 2))
    mod = np.clip(needs + bal + syn, -0.10, 0.10)
    dive = cnt[:, TI["engage"]] + cnt[:, TI["pick"]]
    siege = cnt[:, TI["poke"]] + cnt[:, TI["waveclear"]]
    prot = cnt[:, TI["protect"]] + cnt[:, TI["scaling"]]
    sc = np.stack([dive, siege, prot], axis=1)
    top = sc.max(axis=1)
    second = np.sort(sc, axis=1)[:, -2]
    win = (top >= 4) & (top >= second + 1)
    arg = sc.argmax(axis=1)
    freq = [float(((arg == k) & win).mean()) for k in range(3)]
    return {"mod": mod, "freq": freq, "skirm": float((~win).mean()), "dmg": float((bal < 0).mean()),
            "needs": float((needs < 0).mean()), "cap": float((mod >= 0.0999).mean()), "tagcount": tag.sum(axis=0)}


def loss(st, combos):
    r = evaluate(st, combos)
    q = lambda p: float(np.quantile(r["mod"], p))
    L = 0.0
    for f in r["freq"]:
        L += ((f - 0.22) / 0.04) ** 2
    L += ((r["skirm"] - 0.34) / 0.06) ** 2
    L += ((q(0.5) - 0.03) / 0.01) ** 2 + ((q(0.9) - 0.07) / 0.01) ** 2 + ((q(0.99) - 0.09) / 0.01) ** 2
    L += ((r["cap"] - 0.02) / 0.015) ** 2
    L += ((r["dmg"] - 0.18) / 0.05) ** 2 + ((r["needs"] - 0.15) / 0.05) ** 2
    for c in r["tagcount"]:
        if c < 6: L += (6 - c) ** 2
        if c > 14: L += (c - 14) ** 2
    if r["tagcount"][TI["splitpush"]] < 4: L += 4 * (4 - r["tagcount"][TI["splitpush"]]) ** 2
    return L, r


def main(iters):
    rnd = random.Random(7)
    st = state_from_table()
    for h in st:   # drop any initial extras that break the identity rules
        h["extra"] = [t for t in h["extra"] if t in allowed_extras(h)]
        if len(G.DEFAULT_TAGS[h["arch"]]) + len(h["extra"]) < 2:
            h["extra"] = allowed_extras(h)[:1]
    idx_by_slot = [[i for i, h in enumerate(st) if h["slot"] == s] for s in ("top", "jg", "mid", "bot", "sup")]
    all_combos = np.array(list(itertools.product(*idx_by_slot)))
    sample = all_combos[np.random.RandomState(3).choice(len(all_combos), 6000, replace=False)]
    cur, _ = loss(st, sample)
    temp = 2.0
    for it in range(iters):
        i = rnd.randrange(len(st))
        h = st[i]
        old = (list(h["extra"]), h["dmg"])
        if rnd.random() < 0.25:
            h["dmg"] = rnd.choice(ARCH_DAMAGE[h["arch"]])
        else:
            defaults = G.DEFAULT_TAGS[h["arch"]]
            pool = allowed_extras(h)
            k = rnd.choice([1, 1, 2]) if len(defaults) == 1 else rnd.choice([0, 1, 1, 2])
            k = min(k, 4 - len(defaults), len(pool))
            h["extra"] = rnd.sample(pool, k)
        if len(defaults := G.DEFAULT_TAGS[h["arch"]]) + len(h["extra"]) < 2:
            h["extra"], h["dmg"] = old
            continue
        new, _ = loss(st, sample)
        if new <= cur or rnd.random() < np.exp((cur - new) / temp):
            cur = new
        else:
            h["extra"], h["dmg"] = old
        temp = max(0.05, temp * 0.998)
    final, r = loss(st, all_combos)
    print("final loss %.2f on all lineups" % final)
    print("styles dive/siege/protect %s skirmish %.3f; dmg penalty %.3f needs %.3f cap %.3f; median %.3f p90 %.3f p99 %.3f"
          % ([round(f, 3) for f in r["freq"]], r["skirm"], r["dmg"], r["needs"], r["cap"],
             np.quantile(r["mod"], .5), np.quantile(r["mod"], .9), np.quantile(r["mod"], .99)))
    print("tag counts", dict(zip(TAGS, [int(c) for c in r["tagcount"]])))
    OUT.write_text(json.dumps({h["id"]: {"extra": h["extra"], "damage": h["dmg"]} for h in st}, indent=1) + "\n")


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 3000)
