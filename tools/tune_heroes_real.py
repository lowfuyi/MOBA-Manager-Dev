#!/usr/bin/env python3
"""Hero balance from real drafts (0.11.1, Founder approval of 2026-11-22). Each round plays equal-team games (rating gap 0)
with real AI drafts for each ban count through game/tests/ban_exp.tscn in a COPY of game/ (--game-dir), pools the hero win
rates over the ban counts, and moves each hero's multiplier in <game-dir>/data/hero_balance_v2.json toward 50 percent:

    scale *= 1 - k * (win rate - 50)        (k per percentage point, each round's change clamped to +-max_step)

Heroes inside --hold (default 47.5 to 52.5) are left alone, so a round only touches heroes that need it. The multiplier is a
number on the hero's damage, healing, shields and half its health (Match Sim v2 S6-2): kits, roles and identities do not change.
Every round is appended to --log (JSON lines). Then copy the data file back into game/ by hand, after review.

    GODOT=... python3 tools/tune_heroes_real.py --game-dir /tmp/lab --rounds 3 --games 8000 --counts 1,3,5 --jobs 7
"""
import argparse, concurrent.futures as cf, json, os, pathlib, sys, time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from ban_experiment import run_chunk, merge  # noqa: E402


def play(godot, game_dir, counts, games, chunk, jobs, seed0):
    os.environ["BX_GAPS"] = "0"
    parts = {c: [] for c in counts}
    with cf.ThreadPoolExecutor(max_workers=jobs) as ex:
        futs = {}
        for c in counts:
            for i in range(max(1, games // chunk)):
                futs[ex.submit(run_chunk, godot, c, chunk, seed0 + 1000 * c + i, game_dir)] = c
        for f in cf.as_completed(futs):
            parts[futs[f]].append(f.result())
    del os.environ["BX_GAPS"]
    return {c: merge(p) for c, p in parts.items()}


def pooled(res):
    g, w = {}, {}
    for m in res.values():
        for h, n in m["hero_g"].items():
            g[h] = g.get(h, 0) + n
            w[h] = w.get(h, 0) + m["hero_w"].get(h, 0)
    return {h: (100.0 * w[h] / g[h], g[h]) for h in g}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--game-dir", required=True)
    ap.add_argument("--rounds", type=int, default=3)
    ap.add_argument("--games", type=int, default=8000, help="equal-team games per ban count per round")
    ap.add_argument("--counts", default="1,3,5")
    ap.add_argument("--chunk", type=int, default=400)
    ap.add_argument("--jobs", type=int, default=7)
    ap.add_argument("--k", type=float, default=0.008)
    ap.add_argument("--max-step", type=float, default=0.12)
    ap.add_argument("--hold", default="47.5,52.5")
    ap.add_argument("--seed", type=int, default=7000)
    ap.add_argument("--log", required=True)
    ap.add_argument("--measure-only", action="store_true")
    a = ap.parse_args()
    godot = os.environ["GODOT"]
    counts = [int(c) for c in a.counts.split(",")]
    lo, hi = (float(x) for x in a.hold.split(","))
    data_p = pathlib.Path(a.game_dir) / "data" / "hero_balance_v2.json"
    for r in range(a.rounds):
        t0 = time.time()
        res = play(godot, a.game_dir, counts, a.games, a.chunk, a.jobs, a.seed + 100000 * r)
        wr = pooled(res)
        per = {str(c): {h: round(100.0 * m["hero_w"].get(h, 0) / n, 2) for h, n in m["hero_g"].items()} for c, m in res.items()}
        data = json.loads(data_p.read_text())
        scale = data["scale"]
        moves = {}
        if not a.measure_only:
            for h, (v, n) in wr.items():
                if lo <= v <= hi:
                    continue
                step = max(-a.max_step, min(a.max_step, -a.k * (v - 50.0)))
                new = round(scale[h] * (1.0 + step), 3)
                moves[h] = [scale[h], new]
                scale[h] = new
            data_p.write_text(json.dumps(data, indent=1) + "\n")
        out = sorted(wr.items(), key=lambda kv: kv[1][0])
        rec = {"round": r, "s": round(time.time() - t0), "games": a.games, "counts": counts,
               "outside_45_55": [h for h, (v, _) in out if not 45.0 <= v <= 55.0],
               "range": [round(out[0][1][0], 1), round(out[-1][1][0], 1)],
               "blue0": {str(c): round(100.0 * m["blue_wins0"] / max(1, m["n0"]), 2) for c, m in res.items()},
               "pooled": {h: [round(v, 2), n] for h, (v, n) in wr.items()}, "per_count": per, "moves": moves}
        with open(a.log, "a") as f:
            f.write(json.dumps(rec) + "\n")
        print(f"round {r}: {rec['s']} s, range {rec['range']}, outside {len(rec['outside_45_55'])} {rec['outside_45_55']}, "
              f"moved {len(moves)}", flush=True)


if __name__ == "__main__":
    main()
