#!/usr/bin/env python3
"""Parameter experiments for the draft levers (P-003). Not part of the test suite.
Usage: python3 -I tools/pipeline_experiment.py   (prints a table; edit GRID below)
Measures, for each parameter set, on mirror matches (same roster both sides, side-swapped):
  default-vs-fam-heavy, comp-heavy-vs-fam-heavy, default-vs-comp-heavy win rates of the first policy,
  and mean CompMod / familiarity of each policy's picks.
"""
import multiprocessing as mp, statistics as S, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import pipeline as P, pipeline_report as R, comp as COMP

KM = 40
EXPERT = {"value": True, "value_comp": 40.0, "value_ctr": 1.0, "noise": 0.0}


def mirror_jobs():
    out = []
    for c in P.CLUBS:
        for j in range(KM):
            for tag, (pb, pr) in {"def_fam": ({}, R.FAM_HEAVY), "comp_fam": (R.COMP_HEAVY, R.FAM_HEAVY), "def_comp": ({}, R.COMP_HEAVY), "exp_fam": (EXPERT, R.FAM_HEAVY), "exp_def": (EXPERT, {}), "exp_comp": (EXPERT, R.COMP_HEAVY)}.items():
                out.append((tag + "_B", c, c, "XB-%s-%s-%d" % (tag, c, j), j % 20, {"B": pb, "R": pr}, None, False))
                out.append((tag + "_R", c, c, "XR-%s-%s-%d" % (tag, c, j), j % 20, {"B": pr, "R": pb}, None, False))
    return out


def run_set(label, fam_w, syn, need, bal, cap, lane=0.05):
    P.LANE_MOD = lane; P.FAM_W = fam_w; COMP.SYN_BONUS = syn; COMP.NEED_PEN = need; COMP.BAL_PEN = bal; COMP.CAP = cap
    with mp.Pool(mp.cpu_count()) as pool:
        res = pool.map(R.job, mirror_jobs(), chunksize=20)
    by = {}
    for kind, a, b, r in res:
        by.setdefault(kind, []).append(r)
    def wr(tag):
        w = [r["blue_won"] for r in by[tag + "_B"]] + [not r["blue_won"] for r in by[tag + "_R"]]
        return 100 * sum(w) / len(w)
    return label, wr("def_fam"), wr("comp_fam"), wr("def_comp"), wr("exp_fam"), wr("exp_def"), wr("exp_comp")


GRID = [
    ("v0", 0.10, 0.025, 0.03, 0.04, 0.10, 0.05),
    ("lane .10", 0.10, 0.025, 0.03, 0.04, 0.10, 0.10),
    ("lane .10 + fam .06", 0.06, 0.025, 0.03, 0.04, 0.10, 0.10),
    ("lane .10 + syn 4 pen 5/6 cap 15", 0.10, 0.040, 0.05, 0.06, 0.15, 0.10),
    ("lane .10 + fam .06 + syn 4 pen 5/6 cap 15", 0.06, 0.040, 0.05, 0.06, 0.15, 0.10),
    ("lane .15 + fam .05 + syn 5 pen 6/7 cap 20", 0.05, 0.050, 0.06, 0.07, 0.20, 0.15),
]
if __name__ == "__main__":
    print("%-44s %8s %8s %8s %8s %8s %8s" % ("parameters", "def>fam", "comp>fam", "def>comp", "exp>fam", "exp>def", "exp>comp"))
    for g in GRID:
        r = run_set(*g)
        print("%-44s " % r[0] + " ".join("%7.1f%%" % v for v in r[1:]))
