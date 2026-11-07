#!/usr/bin/env python3
"""Golden vectors for the GDScript port of the rating, composition and draft pipeline.
Writes game/tests/golden/pipeline_vectors.json from the Python reference (tools/pipeline.py, tools/comp.py).
Usage: python3 -I tools/gen_golden_pipeline.py"""
import json, pathlib, random, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import pipeline as P, comp as C, sim_core as S
from pcg32 import match_seed

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "game/tests/golden/pipeline_vectors.json"
SLOTS = P.SLOTS
rnd = random.Random(20261107)
clubs = list(P.CLUBS)
players = sorted(P.PLAYERS)
heroes = sorted(P.HEROES)


def run_case(blue, red, save_seed, match_id, full, human):
    order = P.ORDER if full else P.ORDER_SHORT
    meta = P.make_meta("S1-P2")
    lineups = {"B": P.best_lineup(blue), "R": P.best_lineup(red)}
    ms = match_seed(save_seed, match_id)
    log = []
    picks = P.draft(lineups, meta, ms, match_id, order=order, human=human, log=log)
    for t in "BR":
        if len(picks[t]) != 5: raise ValueError("incomplete")
    slots_used = [(e[1], e[3]) for e in log if e[2] == "pick"]
    if len(set(slots_used)) != len(slots_used): raise ValueError("overwrite")
    a = P.build_team(lineups["B"], picks["B"], picks["R"], meta)
    b = P.build_team(lineups["R"], picks["R"], picks["B"], meta)
    r = S.simulate(a, b, ms)
    return {"blue": blue, "red": red, "save_seed": save_seed, "match_id": match_id, "full": full,
            "human": {str(k): v for k, v in human.items()},
            "log": [{"n": n, "team": t, "kind": k, "slot": s or "", "hero": h} for n, t, k, s, h in log],
            "final": r["final"], "a_won": r["a_won"], "comp_b": a["comp_mod"], "comp_r": b["comp_mod"],
            "style_b": a["style"], "style_r": b["style"], "lane_b": a["lane_mod"], "lane_r": b["lane_mod"],
            "early_b": a["ratings"]["early"], "late_r": b["ratings"]["late"], "con_b": a["con"],
            "lineup_b": {s: lineups["B"][s]["id"] for s in SLOTS}, "lineup_r": {s: lineups["R"][s]["id"] for s in SLOTS}}


def human_steps(full, side):
    order = P.ORDER if full else P.ORDER_SHORT
    for _ in range(60):
        h = {}
        slots = rnd.sample(SLOTS, 5)
        pool = rnd.sample(heroes, 12)
        i = 0
        for n, (team, kind) in enumerate(order):
            if team != side: continue
            if kind == "ban": h[n] = pool[i]
            else: h[n] = (slots.pop(), pool[i])
            i += 1
        yield h


def main():
    out = {"fam": [], "meta": {}, "lineups": {}, "comp": [], "progress": [], "drafts": []}
    for _ in range(60):
        p = P.PLAYERS[rnd.choice(players)]; hid = rnd.choice(heroes)
        out["fam"].append({"player": p["id"], "hero": hid, "value": P.familiarity(p, hid)})
    out["meta"] = {"seed": "S1-P2", "values": P.make_meta("S1-P2")}
    for c in clubs:
        lu = P.best_lineup(c)
        out["lineups"][c] = {"slots": {s: lu[s]["id"] for s in SLOTS}, "team_rating": P.team_rating(lu)}
    for _ in range(80):
        hs = rnd.sample(heroes, 5)
        m, st, parts = C.comp_eval([P.HEROES[h] for h in hs])
        out["comp"].append({"heroes": hs, "mod": m, "style": st, "needs": parts["needs"], "balance": parts["balance"], "synergy": parts["synergy"], "scores": parts["scores"]})
    for _ in range(40):
        hs = rnd.sample(heroes, rnd.randint(1, 5))
        out["progress"].append({"heroes": hs, "value": P._progress([P.HEROES[h] for h in hs])})
    n = 0
    for full in (False, True):
        for k in range(10):
            blue, red = rnd.sample(clubs, 2)
            seed = rnd.randint(1, 10**9)
            mid = "G-%d-%s-%s" % (k, blue[:4], red[:4])
            out["drafts"].append(run_case(blue, red, seed, mid, full, {})); n += 1
    for full in (False, True):
        for side in "BR":
            for k in range(3):
                blue, red = rnd.sample(clubs, 2)
                seed = rnd.randint(1, 10**9)
                mid = "H-%s-%d-%s-%s" % (side, k, blue[:4], red[:4])
                for h in human_steps(full, side):
                    try:
                        out["drafts"].append(run_case(blue, red, seed, mid, full, h)); n += 1
                        break
                    except (ValueError, KeyError):
                        continue
    OUT.write_text(json.dumps(out, indent=1) + "\n")
    print("wrote %s: %d draft cases" % (OUT.relative_to(ROOT), len(out["drafts"])))


if __name__ == "__main__":
    main()
