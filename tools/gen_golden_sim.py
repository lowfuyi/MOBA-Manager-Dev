"""Generate game/tests/golden/sim_vectors.json from the reference simulator (sim_core.py).
Inputs are produced by a fixed PCG32 stream, so regenerating gives identical files."""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import sim_core as S
from pcg32 import Pcg32, match_seed

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "game/tests/golden/sim_vectors.json"
STYLES = ["dive", "siege", "protect", "skirmish"]


def split(x): return {"hi": x >> 32, "lo": x & 0xFFFFFFFF}


def rand_team(g):
    ratings = {ph: {s: round(40 + 50 * g.next_float(), 3) for s in S.SLOTS} for ph in ("early", "mid", "late")}
    return {"ratings": ratings, "con": round(20 + 70 * g.next_float(), 3),
            "team_mod": round(0.04 * g.next_float(), 4), "comp_mod": round(0.10 * g.next_float(), 4),
            "lane_mod": {k: round(0.05 * (g.next_float() - 0.5) * 2, 4) for k in ("top", "mid", "bot", "jg")},
            "style": STYLES[g.next_u32() % 4]}


def main():
    g = Pcg32(20261107, 99)
    save_seed = 0xDEADBEEF12345678
    cases = []
    for i in range(24):
        a, b = rand_team(g), rand_team(g)
        mid = "golden-%02d" % i
        r = S.simulate(a, b, match_seed(save_seed, mid))
        cases.append({"match_id": mid, "team_a": a, "team_b": b, "expect": r})
    # an exact counterfactual: same match id, one input changed, every noise value must be unchanged
    base = cases[0]
    changed = json.loads(json.dumps(base["team_a"]))
    changed["comp_mod"] = round(changed["comp_mod"] + 0.05, 4)
    r2 = S.simulate(changed, base["team_b"], match_seed(save_seed, base["match_id"]))
    assert r2["noise"] == base["expect"]["noise"]
    cases.append({"match_id": base["match_id"], "team_a": changed, "team_b": base["team_b"], "expect": r2})
    OUT.write_text(json.dumps({"version": 1, "generator": "tools/gen_golden_sim.py", "params": S.PARAMS["version"],
                               "save_seed": split(save_seed), "tolerance": 1e-9, "cases": cases}, indent=1))
    print("wrote", OUT.relative_to(ROOT), len(cases), "cases")

if __name__ == "__main__":
    main()
