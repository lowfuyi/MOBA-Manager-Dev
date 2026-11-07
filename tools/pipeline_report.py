#!/usr/bin/env python3
"""Section 9.1 full-pipeline calibration report (P-003).

Usage: python3 -I tools/pipeline_report.py [matches_per_scenario] [--write]
--write also writes docs/design/CALIBRATION-9.1.md. Seeds are fixed, so the report is reproducible.
"""
import math, multiprocessing as mp, sys, pathlib, itertools
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import pipeline as P

ROOT = pathlib.Path(__file__).resolve().parent.parent
SAVE = 20261107
FAM_HEAVY = {"fam": 0.70, "meta": 0.10, "comp": 0.10, "counter": 0.10}
COMP_HEAVY = {"fam": 0.10, "meta": 0.10, "comp": 0.50, "counter": 0.30}
_L = {}

FINDINGS = """## Findings and decisions (P-003, 2026-11-07)

**Problem found with the v0 constants.** Drafting for familiarity beat drafting for composition by 3 to 6 points, and the default AI draft only tied the familiarity-heavy one. A drafter that maximises the rating points each pick adds ("expert" probe, no noise) beat the default by 0.0 points. So with v0 constants the draft rewarded comfort picks and nothing above them.

**Sweep** (each cell 800 side-swapped mirror matches, standard error about 1.8 points; first policy's win rate; `tools/pipeline_experiment.py`):

| Constants | default v fam | comp v fam | expert v fam | expert v default |
|---|---|---|---|---|
| v0: familiarity weight .10, synergy 2.5%, penalties 3/4%, cap 10%, lane counter 5% | 48.5% | 45.9% | 51.4% | 50.0% |
| lane counter 10% | 48.8% | 46.5% | 51.5% | 49.6% |
| lane 10% + familiarity .06 | 49.6% | 48.1% | 53.6% | 49.9% |
| **lane 10% + familiarity .06 + synergy 4%, penalties 5/6%, cap 15% (adopted)** | 50.2% | 49.1% | 54.8% | 51.0% |
| lane 15% + familiarity .05 + synergy 5%, penalties 6/7%, cap 20% | 51.2% | 50.8% | 55.9% | 52.0% |

**Decision:** the adopted row. It stops familiarity dominating (familiarity-heavy and composition-heavy drafting now tie), gives a careful drafter about 5 points over a comfort drafter, and keeps the cap rare (3.3% of all 32,768 lineups). The last row gains about one more point and was rejected because a 20% cap is a very large swing on a single screen. Changed: `HeroFactor` familiarity weight 0.10 to 0.06, synergy +2.5% to +4%, missing-need penalty 3% to 5%, damage-imbalance penalty 4% to 6%, CompMod cap 10% to 15%, lane counter 5% to 10%. The simulator itself is unchanged, so the golden vectors still hold.

**What the draft is worth, stated plainly.** The draft is a margin lever, not a game-winner. The typical gap between two sensible drafts is about 3 win-rate points, so it flips the winner in about 3% of matches; squad strength still dominates (+10 rating gap wins about 71%). A strong draft against a poor one is worth about 10 points. If playtests show the draft feels too small, the next step is widening MetaMod, not more CompMod.

**Mirror check.** The first 900-match runs gave Blue 48.2% and 47.9%, which looked like a failure. A 4,000-match check gave **50.8%** (SE 0.8) at side bonus 0.02, and 51.0% at 0.04, so the earlier numbers were sampling noise and the side bonus stays at 0.02. The mirror sample in this report is now 3,600 matches.

**Consistency.** CON barely changes a strong favourite's win rate against a weak club (see the table below): a favourite at +30 rating is already near the ceiling of the tanh contest. CON matters between close teams; the paired lever test for it is part of the remaining P-003 work.

"""


def lineup(c):
    if c not in _L: _L[c] = P.best_lineup(c)
    return _L[c]


def job(args):
    kind, blue, red, mid, patch, pol, con, neutral = args
    meta = P.make_meta(patch)
    r = P.play(blue, red, SAVE, mid, meta, policies=pol, lineups={"B": lineup(blue), "R": lineup(red)}, con=con, neutral_draft=neutral)
    return (kind, blue, red, r)


def jobs(n):
    clubs = list(P.CLUBS)
    out = []
    k = max(1, n // 90)
    # S1: every ordered pair, default policies
    for i, (a, b) in enumerate(itertools.permutations(clubs, 2)):
        for j in range(k):
            out.append(("league", a, b, "L-%d-%d" % (i, j), j % 20, None, None, True))
    # S3/S4: mirror matches (same roster both sides)
    km = max(2, n // 10)
    for c in clubs:
        for j in range(max(4, n // 5)):          # larger sample: the side-bonus check needs SE under 1 point
            out.append(("mirror_same", c, c, "M-%s-%d" % (c, j), j % 20, None, None, False))
        for j in range(km):
            out.append(("comp_vs_fam_B", c, c, "CB-%s-%d" % (c, j), j % 20, {"B": COMP_HEAVY, "R": FAM_HEAVY}, None, False))
            out.append(("comp_vs_fam_R", c, c, "CR-%s-%d" % (c, j), j % 20, {"B": FAM_HEAVY, "R": COMP_HEAVY}, None, False))
            out.append(("def_vs_fam_B", c, c, "DB-%s-%d" % (c, j), j % 20, {"B": {}, "R": FAM_HEAVY}, None, False))
            out.append(("def_vs_fam_R", c, c, "DR-%s-%d" % (c, j), j % 20, {"B": FAM_HEAVY, "R": {}}, None, False))
            out.append(("def_vs_comp_B", c, c, "EB-%s-%d" % (c, j), j % 20, {"B": {}, "R": COMP_HEAVY}, None, False))
            out.append(("def_vs_comp_R", c, c, "ER-%s-%d" % (c, j), j % 20, {"B": COMP_HEAVY, "R": {}}, None, False))
    # S5: consistency: weak club vs favourite
    weak, strong = "pinehollow_owls", "thornwick_stags"
    kc = max(2, n // 3)
    for j in range(kc):
        for tag, (cw, cs) in {"con50": (50, 50), "con_weak20_strong80": (20, 80), "con_weak80_strong20": (80, 20)}.items():
            out.append((tag + "_B", strong, weak, "C1-%s-%d" % (tag, j), j % 20, None, {"B": cs, "R": cw}, False))
            out.append((tag + "_R", weak, strong, "C2-%s-%d" % (tag, j), j % 20, None, {"B": cw, "R": cs}, False))
    return out


def rate(rs, f):
    rs = list(rs)
    return sum(f(r) for r in rs) / len(rs), len(rs)


def run(n, procs):
    with mp.Pool(procs) as pool:
        res = pool.map(job, jobs(n), chunksize=20)
    by = {}
    for kind, a, b, r in res:
        by.setdefault(kind, []).append((a, b, r))
    return by


def logistic_slope(points):
    """max likelihood slope k in p = 1/(1+exp(-k*gap)), by Newton steps. points: [(gap, won)]"""
    k = 0.05
    for _ in range(50):
        g = h = 0.0
        for gap, w in points:
            p = 1 / (1 + math.exp(-k * gap))
            g += (w - p) * gap
            h -= p * (1 - p) * gap * gap
        k -= g / h
    return k


def report(by, n):
    lines = []
    out = lines.append
    L = by["league"]
    pts = [(P.team_rating(lineup(a)) - P.team_rating(lineup(b)), r["blue_won"]) for a, b, r in L]
    k = logistic_slope(pts)
    blue_all = sum(r["blue_won"] for _, _, r in L) / len(L)
    out("## Results (generated by `tools/pipeline_report.py %d`)" % n)
    out("")
    out("**League play, every ordered club pair, default AI drafts (%d matches).** Team rating gap = mean BaseRating of the five assigned starters.\n" % len(L))
    out("| Rating gap (Blue minus Red) | Matches | Blue win rate |\n|---|---|---|")
    bins = {}
    for gap, w in pts:
        b = int(round(gap / 10.0) * 10)
        bins.setdefault(b, []).append(w)
    for b in sorted(bins):
        out("| %+d | %d | %.1f%% |" % (b, len(bins[b]), 100 * sum(bins[b]) / len(bins[b])))
    out("")
    out("Logistic slope fitted to all matches: %.4f per rating point, so a +10 gap wins about **%.1f%%** and +20 about %.1f%% (the section 9 targets on pure ratings are 70 and 84%%; a figure near these confirms that HeroFactor, fit and noise cost the favourite little edge, so D does not need to move). Overall Blue win rate across all pairs: %.1f%% (unavoidably confounded with gap; see the mirror test)." %
        (k, 100 / (1 + math.exp(-10 * k)), 100 / (1 + math.exp(-20 * k)), 100 * blue_all))
    out("")
    flips = [r["blue_won"] != r["neutral_blue_won"] for a, b, r in L if abs(P.team_rating(lineup(a)) - P.team_rating(lineup(b))) < 8]
    allflips = [r["blue_won"] != r["neutral_blue_won"] for _, _, r in L]
    out("**Draft flips the winner** (same match seed, draft bonuses on versus off): %.1f%% of matches between clubs under 8 rating points apart (%d matches), %.1f%% across all pairs." %
        (100 * sum(flips) / len(flips), len(flips), 100 * sum(allflips) / len(allflips)))
    out("")
    # mirror
    ms = by["mirror_same"]
    out("**Blue versus Red, mirror matches (same roster both sides, same AI policy, %d matches):** Blue wins %.1f%% (the side bonus is 2%% carry; target 50 to 52%%, SE about %.1f points)." %
        (len(ms), 100 * sum(r["blue_won"] for _, _, r in ms) / len(ms), 100 * math.sqrt(0.25 / len(ms))))
    out("")
    def mirror_pair(kb, kr, label):
        wa = [r["blue_won"] for _, _, r in by[kb]] + [not r["blue_won"] for _, _, r in by[kr]]
        out("| %s | %d | %.1f%% |" % (label, len(wa), 100 * sum(wa) / len(wa)))
    out("**Draft policy versus draft policy on the same roster (side-swapped; first policy's win rate):**\n")
    out("| Policy A vs policy B | Matches | A win rate |\n|---|---|---|")
    mirror_pair("comp_vs_fam_B", "comp_vs_fam_R", "composition-heavy vs familiarity-heavy")
    mirror_pair("def_vs_fam_B", "def_vs_fam_R", "default vs familiarity-heavy")
    mirror_pair("def_vs_comp_B", "def_vs_comp_R", "default vs composition-heavy")
    out("")
    out("(Weights fam/meta/comp/counter: default .35/.20/.20/.25; familiarity-heavy .70/.10/.10/.10; composition-heavy .10/.10/.50/.30.)")
    out("")
    out("**Consistency (favourite Thornwick Stags vs weak Pinehollow Owls, side-swapped):**\n")
    out("| Case | Matches | Favourite win rate |\n|---|---|---|")
    for tag, label in (("con50", "both CON 50"), ("con_weak20_strong80", "weak CON 20, favourite CON 80"), ("con_weak80_strong20", "weak CON 80, favourite CON 20")):
        w = [r["blue_won"] for _, _, r in by[tag + "_B"]] + [not r["blue_won"] for _, _, r in by[tag + "_R"]]
        out("| %s | %d | %.1f%% |" % (label, len(w), 100 * sum(w) / len(w)))
    out("")
    return "\n".join(lines), k


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    n = int(args[0]) if args else 1800
    by = run(n, max(1, mp.cpu_count()))
    text, k = report(by, n)
    print(text)
    if "--write" in sys.argv:
        head = ("# Full-pipeline calibration (GDD section 9.1)\n\nReal rosters, hero fit, hash-derived familiarity, the AI lineup rule and the AI draft, "
                "then the simulator (`tools/pipeline.py`). Phase 1 simplifications: Form 0, Morale 60, Fatigue 0, TeamMod fixed at the new-club Bond value (0.96%), "
                "MetaMod drawn per patch (20 patches of +-3%), familiarity from a v0 hash rule (3 signature heroes at 50 to 85, everything else 0 to 30). "
                "Seeds are fixed, so the numbers reproduce.\n\n")
        (ROOT / "docs/design/CALIBRATION-9.1.md").write_text(head + FINDINGS + text + "\n")
