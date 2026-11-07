#!/usr/bin/env python3
"""D-018: the 9.1 draft-lever checks again with the SHORT draft profile (1 ban + 5 picks per side)
next to the FULL profile. Usage: python3 -I tools/pipeline_short.py [matches_per_cell]"""
import multiprocessing as mp, sys, pathlib, math
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import pipeline as P, pipeline_report as R

SAVE = 20261108
CELLS = {
    "default vs familiarity-heavy": ({}, R.FAM_HEAVY),
    "composition-heavy vs familiarity-heavy": (R.COMP_HEAVY, R.FAM_HEAVY),
    "default vs composition-heavy": ({}, R.COMP_HEAVY),
}


def job(a):
    cell, side, club, mid, patch, pol, order_name = a
    order = P.ORDER_SHORT if order_name == "short" else P.ORDER
    r = P.play(club, club, SAVE, mid, P.make_meta(patch), policies=pol, lineups={"B": R.lineup(club), "R": R.lineup(club)}, order=order)
    return (order_name, cell, side, r["blue_won"])


def main(n):
    jobs = []
    for on in ("full", "short"):
        for club in P.CLUBS:
            for j in range(n):
                jobs.append((on, "B", club, "MS-%s-%s-%d" % (on, club, j), j % 20, {}, on))
        for cell, (pa, pb) in CELLS.items():
            for club in P.CLUBS:
                for j in range(n // 2):
                    jobs.append((on, cell + "|B", club, "S-%s-%s-%s-%d" % (on, cell, club, j), j % 20, {"B": pa, "R": pb}, on))
                    jobs.append((on, cell + "|R", club, "T-%s-%s-%s-%d" % (on, cell, club, j), j % 20, {"B": pb, "R": pa}, on))
    jobs = [(c[1], c[0], c[2], c[3], c[4], c[5], c[6]) if False else c for c in jobs]
    with mp.Pool(mp.cpu_count()) as pool:
        res = pool.map(job2, jobs, chunksize=20)
    out = {}
    for on, cell, blue_won in res:
        out.setdefault((on, cell), []).append(blue_won)
    print("| Check | Full draft | Short draft |\n|---|---|---|")
    def rate(on, key, first_is_blue_key=None):
        return out[(on, key)]
    def pct(xs):
        p = sum(xs) / len(xs)
        return "%.1f%% (n=%d, SE %.1f)" % (100 * p, len(xs), 100 * math.sqrt(p * (1 - p) / len(xs)))
    print("| Blue wins mirror (no policy edge) | %s | %s |" % (pct(out[("full", "mirror")]), pct(out[("short", "mirror")])))
    for cell in CELLS:
        row = []
        for on in ("full", "short"):
            w = out[(on, cell + "|B")] + [not x for x in out[(on, cell + "|R")]]
            row.append(pct(w))
        print("| %s (first policy wins) | %s | %s |" % (cell, row[0], row[1]))


def job2(a):
    on, cell, club, mid, patch, pol, order_name = a
    _, c, side, won = job((cell, "x", club, mid, patch, pol, order_name))
    return (on, "mirror" if cell == "B" else cell, won)


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 40)
