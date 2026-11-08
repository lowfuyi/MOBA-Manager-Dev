#!/usr/bin/env python3
"""Calibration harness (GDD section 9) on the PCG32 reference simulator. P-002/P-003.

Usage: python3 -I tools/calibrate.py [n_matches] [--check] [--base=60]
  prints the report; with --check exits 1 if any measured value is outside its band.
Bands are the GDD section 9 targets: win-rate targets with +/-2.0 points; the
"other check" ranges as written there.
"""
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import sim_core as S
from pcg32 import match_seed

SAVE_SEED = 20261107
BASE = 60.0    # team rating the contests are measured around; --base=45 repeats them at the Phase 1 scale


def win_rate(a, b, n, tag, p=S.PARAMS):
    w = 0
    for i in range(n):
        w += S.simulate(a, b, match_seed(SAVE_SEED, "%s-%d" % (tag, i)), p)["a_won"]
    return w / n


def comeback_rate(n, threshold=0.2):
    p = dict(S.PARAMS, side_bonus=0.0)
    a, b = S.make_team(BASE), S.make_team(BASE)
    behind = total = 0
    for i in range(n):
        r = S.simulate(a, b, match_seed(SAVE_SEED, "cb-%d" % i), p)
        if abs(r["early"]) >= threshold:
            total += 1
            if r["a_won"] != (r["early"] > 0):
                behind += 1
    return behind / max(1, total)


def phase_adv(ph, n):
    a = S.make_team(BASE)
    for s in a["ratings"][ph]:
        a["ratings"][ph][s] += 10
    return win_rate(a, S.make_team(BASE), n, "ph-" + ph)


def run(n):
    """Returns list of (name, value, lo, hi). Values are fractions.
    Bands are exactly the GDD section 9 numbers. Win-rate rows get a sampling
    tolerance of 2 standard errors (2*sqrt(0.25/n)); the comeback row is a
    conditional rate and gets none."""
    tol = 2.0 * (0.25 / n) ** 0.5
    rows = []
    def add(name, v, lo, hi, slack=True):
        t = tol if slack else 0.0
        rows.append((name, v, lo - t, hi + t))
    ref = S.make_team(BASE)
    add("adv 0 (Blue)", win_rate(S.make_team(BASE), ref, n, "a0"), .50, .52)
    for diff, target in ((5, .60), (10, .70), (20, .84), (30, .93)):
        add("adv +%d" % diff, win_rate(S.make_team(BASE + diff), ref, n, "a%d" % diff), target - .02, target + .02)
    r = [win_rate(S.make_team(BASE + 10, c), S.make_team(BASE, c), n, "con%d" % c) for c in (20, 50, 80)]
    add("+10 at CON 20", r[0], .64, .66)
    add("+10 at CON 50", r[1], .67, .70)
    add("+10 at CON 80", r[2], .72, .76)
    add("CON effect (80 minus 20)", r[2] - r[0], .05, 1.0, slack=False)
    add("late-heavy vs early-heavy", win_rate(S.make_team(BASE, powers=(38, 50, 62)), S.make_team(BASE, powers=(62, 50, 38)), n, "pw"), .45, .55)
    for ph in ("early", "mid", "late"):
        add("+10 in %s only" % ph, phase_adv(ph, n), .55, .58)
    add("CompMod +10%", win_rate(S.make_team(BASE, comp_mod=.10), ref, n, "cm10"), .56, .59)
    add("CompMod +5%", win_rate(S.make_team(BASE, comp_mod=.05), ref, n, "cm5"), .53, .55)
    add("dive vs siege", win_rate(S.make_team(BASE, style="dive"), S.make_team(BASE, style="siege"), n, "sty"), .53, .56)
    add("lane counter +5% x3", win_rate(S.make_team(BASE, lane_mod={"top": .05, "mid": .05, "bot": .05}), ref, n, "lm"), .51, .53)
    add("comeback rate", comeback_rate(n), .25, .40, slack=False)
    return rows


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for a in sys.argv[1:]:
        if a.startswith("--base="):
            BASE = float(a.split("=", 1)[1])
    n = int(args[0]) if args else 40000
    rows = run(n)
    bad = 0
    print("Calibration (PCG32 reference), n=%d per row, base rating %.0f" % (n, BASE))
    for name, v, lo, hi in rows:
        ok = lo <= v <= hi
        bad += not ok
        print("  %-30s %6.3f   band %.3f-%.3f  %s" % (name, v, lo, hi, "ok" if ok else "OUT OF BAND"))
    print("out of band: %d" % bad)
    if "--check" in sys.argv:
        sys.exit(1 if bad else 0)
