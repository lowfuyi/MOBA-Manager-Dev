#!/usr/bin/env python3
"""Q2 analyses of the Founder's queue of 2026-11-24 (docs/design/ESMO-LESSONS.md). Read-only use of the sim: runs
game/tests/q2_exp.tscn in parallel low-priority Godot processes from a COPY of game/ (so gates in game/ are not starved),
merges the chunks and writes:
  docs/design/Q2-ANALYSIS.md          a) hero win rate by lane, b) Game Plan sweep, c) does the draft decide too much
  game/data/hero_matchups_v1.json     d) "struggles against" per hero (display only)

    GODOT=/path/to/godot python3 tools/q2_analysis.py run --game-dir <copy of game/> --raw <dir> [--jobs 6]
    python3 tools/q2_analysis.py report --raw <dir>

Not part of the fast gate (several hours of CPU). Defaults: heroes 40,000 games per format (1, 3, 5 bans), draft 5,000 per
format, plans 2,000 base games in the 5-ban format with every option (45 games each).
"""
import argparse, concurrent.futures as cf, json, math, os, pathlib, subprocess, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SLOTS = ["top", "jg", "mid", "bot", "sup"]
LANE = {"top": "Top", "jg": "Jungle", "mid": "Mid", "bot": "Bot", "sup": "Support"}
HERO_BAND = (45.0, 55.0)
ROLE_MIN = 300          # games a hero needs in a lane to count as "used" there
PAIR_MIN = 400          # games a pair needs before a matchup is read
STRUGGLE_PTS = 3.0      # points below the hero's own win rate
STRUGGLE_Z = 2.5
FLAG_PTS = 3.0          # Game Plan option flag


def run_chunk(godot, game_dir, mode, nb, n, seed):
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tf:
        out = tf.name
    env = dict(os.environ, Q2_MODE=mode, Q2_BANS=str(nb), Q2_N=str(n), Q2_SEED=str(seed), Q2_OUT=out)
    subprocess.run(["nice", "-n", "19", "timeout", "36000", godot, "--headless", "res://tests/q2_exp.tscn"], cwd=game_dir,
                   env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        return json.loads(pathlib.Path(out).read_text())
    except Exception:
        return None
    finally:
        pathlib.Path(out).unlink(missing_ok=True)


def merge(parts):
    m = None
    for p in parts:
        if p is None:
            continue
        if m is None:
            m = p
            continue
        for k in ("n", "ms", "base_g", "base_w"):
            m[k] += p[k]
        m["rows"] += p["rows"]
        for k in ("hr_g", "hr_w", "pair_g", "pair_w", "lane_g", "lane_w", "opt_g", "opt_w", "opt_10", "opt_01"):
            for h, v in p.get(k, {}).items():
                m[k][h] = m[k].get(h, 0) + v
    return m


def cmd_run(a):
    godot = os.environ["GODOT"]
    raw = pathlib.Path(a.raw)
    raw.mkdir(parents=True, exist_ok=True)
    plan = []
    for nb in (1, 3, 5):
        plan.append(("draft", nb, a.draft, 500))
    plan.append(("plans", 5, a.plans, 40))
    for nb in (1, 3, 5):
        plan.append(("heroes", nb, a.heroes, 1000))
    if a.only:
        plan = [x for x in plan if x[0] in a.only.split(",")]
    for mode, nb, total, chunk in plan:
        target = raw / f"{mode}_{nb}.json"
        if target.exists():
            print("have", target)
            continue
        seeds = list(range(1, total // chunk + 1))
        base = {"draft": 5000, "plans": 7000, "heroes": 9000}[mode] + nb * 100
        with cf.ThreadPoolExecutor(a.jobs) as ex:
            parts = list(ex.map(lambda s: run_chunk(godot, a.game_dir, mode, nb, chunk, base + s), seeds))
        bad = sum(1 for p in parts if p is None)
        m = merge(parts)
        m["failed_chunks"] = bad
        target.write_text(json.dumps(m))
        print(mode, nb, "games", m["n"] if m else 0, "failed chunks", bad, flush=True)


def heroes_names():
    rows = json.loads((ROOT / "game/data/heroes.json").read_text())
    rows = rows["heroes"] if isinstance(rows, dict) else rows
    return {str(h["id"]): str(h["name"]) for h in rows}


def pct(w, g):
    return 100.0 * w / g if g else float("nan")


def section_a(raw, names, md):
    md.append("## a) Hero win rate by lane (equal teams, real drafts)\n")
    md.append(f"Teams are moved to the same mean rating, so a hero's win rate is the hero, the draft around it and the lane. A hero "
              f"counts as used in a lane with at least {ROLE_MIN} games there. Band {HERO_BAND[0]:.0f} to {HERO_BAND[1]:.0f}%.\n")
    out_rows = []
    for nb in (1, 3, 5):
        f = raw / f"heroes_{nb}.json"
        if not f.exists():
            md.append(f"- {nb} bans: no data.\n")
            continue
        d = json.loads(f.read_text())
        used = 0
        outside = []
        for k, g in d["hr_g"].items():
            if g < ROLE_MIN:
                continue
            used += 1
            h, s = k.split("|")
            wr = pct(d["hr_w"].get(k, 0), g)
            if wr < HERO_BAND[0] or wr > HERO_BAND[1]:
                outside.append((wr, names.get(h, h), LANE[s], g))
        outside.sort()
        md.append(f"- **{nb} ban{'s' if nb > 1 else ''} a side** ({d['n']:,} games): {used} hero-lane pairs used; "
                  f"{len(outside)} outside the band.")
        for wr, nm, ln, g in outside:
            md.append(f"  - {nm} in {ln}: {wr:.1f}% ({g:,} games)")
            out_rows.append((nb, nm, ln, wr, g))
        md.append("")
    return out_rows


def section_b(raw, md):
    md.append("## b) Game Plan sweep (equal teams, 5 bans a side)\n")
    f = raw / "plans_5.json"
    if not f.exists():
        md.append("No data.\n")
        return []
    d = json.loads(f.read_text())
    base = pct(d["base_w"], d["base_g"])
    md.append(f"{d['base_g']:,} base games. Each is played with both plans neutral (side A wins {base:.1f}%), then once per option "
              f"with only that option on side A, same draft and seed. Delta = option's win rate minus neutral, in points; the "
              f"error is the paired standard error. Flag: delta above +{FLAG_PTS:.0f} points. Nothing was tuned.\n")
    md.append("| Option (side A) | Games | Win % | Delta | +-SE | Flag |")
    md.append("|---|---|---|---|---|---|")
    flags = []
    rows = []
    for k, g in d["opt_g"].items():
        n10 = d["opt_10"].get(k, 0)
        n01 = d["opt_01"].get(k, 0)
        delta = 100.0 * (n10 - n01) / g
        var = (n10 + n01) - (n10 - n01) ** 2 / g
        se = 100.0 * math.sqrt(max(var, 0.0)) / g
        rows.append((delta, k, g, pct(d["opt_w"].get(k, 0), g), se))
    rows.sort(reverse=True)
    for delta, k, g, wr, se in rows:
        flag = "FLAG" if delta > FLAG_PTS else ""
        if flag:
            flags.append((k, delta, se))
        md.append(f"| {k} | {g:,} | {wr:.1f} | {delta:+.1f} | {se:.1f} | {flag} |")
    md.append("")
    singles = [r for r in rows if " " not in r[1]]
    pairs = [r for r in rows if " " in r[1]]
    if singles and pairs:
        best_single = max(singles)
        dominant = [p for p in pairs if p[0] > best_single[0] + 2.0 * p[4]]
        md.append(f"Best single option: {best_single[1]} ({best_single[0]:+.1f}). Dominant combinations (beat the best single "
                  f"option by more than two standard errors): " + (", ".join(f"{p[1]} ({p[0]:+.1f})" for p in dominant) or "none") + ".\n")
    return flags


def section_c(raw, md):
    md.append("## c) Does the draft decide too much?\n")
    md.append("**Draft score** of a side = the mean of the 15 phase ratings the match is given, divided by the same players' mean "
              "with a plain hero in every lane (own lane, full familiarity, no difficulty, power 50, patch 1.0), times "
              "(1 + composition bonus x its fight weight). 1.00 = the draft adds nothing; it holds hero fit, familiarity, hero "
              "power, the patch and the composition. The lane matchup bonus is not in it. **Player gap** = the difference of "
              "the plain-hero means (rating points). Natural ratings, real clubs, real AI drafts. A tie in draft score (under "
              "0.001) is left out.\n")
    md.append("| Bans a side | Player gap | Games | Better draft wins | Better draft also has the better players |")
    md.append("|---|---|---|---|---|")
    nums = []
    buckets = [(0, 2), (2, 5), (5, 10), (10, 999)]
    for nb in (1, 3, 5):
        f = raw / f"draft_{nb}.json"
        if not f.exists():
            continue
        d = json.loads(f.read_text())
        allg = allw = 0
        for lo, hi in buckets:
            g = w = same = 0
            for gap, db, dr, blue_won in d["rows"]:
                if not (lo <= abs(gap) < hi) or abs(db - dr) < 0.001:
                    continue
                better_blue = db > dr
                g += 1
                if better_blue == blue_won:
                    w += 1
                if (gap > 0) == better_blue:
                    same += 1
            allg += g
            allw += w
            label = f"{lo} to {hi}" if hi < 999 else f"{lo}+"
            md.append(f"| {nb} | {label} | {g:,} | {pct(w, g):.1f}% | {pct(same, g):.0f}% |")
            nums.append((nb, label, g, pct(w, g)))
        md.append(f"| {nb} | all | {allg:,} | {pct(allw, allg):.1f}% | |")
        # the draft against the players: the better draft with the weaker players
        g2 = w2 = 0
        for gap, db, dr, blue_won in d["rows"]:
            if abs(db - dr) < 0.001 or abs(gap) < 2:
                continue
            better_blue = db > dr
            if (gap > 0) != better_blue:
                g2 += 1
                if better_blue == blue_won:
                    w2 += 1
        nums.append((nb, "upset", g2, pct(w2, g2)))
    md.append("")
    for nb, label, g, wr in nums:
        if label == "upset":
            md.append(f"- {nb} bans: when the better draft has the WEAKER players (gap 2+), the better draft wins {wr:.1f}% ({g:,} games).")
    md.append("")
    return nums


def section_d(raw, names):
    pair_g, pair_w, hr_g, hr_w, n = {}, {}, {}, {}, 0
    for nb in (1, 3, 5):
        f = raw / f"heroes_{nb}.json"
        if not f.exists():
            continue
        d = json.loads(f.read_text())
        n += d["n"]
        for src, dst in ((d["pair_g"], pair_g), (d["pair_w"], pair_w)):
            for k, v in src.items():
                dst[k] = dst.get(k, 0) + v
        for k, v in d["hr_g"].items():
            h = k.split("|")[0]
            hr_g[h] = hr_g.get(h, 0) + v
        for k, v in d["hr_w"].items():
            h = k.split("|")[0]
            hr_w[h] = hr_w.get(h, 0) + v
    heroes = {}
    for h in sorted(hr_g):
        base = hr_w.get(h, 0) / hr_g[h]
        rows = []
        for k, g in pair_g.items():
            x, y = k.split("|")
            if x != h or g < PAIR_MIN:
                continue
            wr = pair_w.get(k, 0) / g
            delta = 100.0 * (wr - base)
            z = (wr - base) / math.sqrt(max(base * (1 - base), 1e-9) / g)
            if delta <= -STRUGGLE_PTS and z <= -STRUGGLE_Z:
                rows.append({"vs": y, "win_pct": round(100 * wr, 1), "delta_pts": round(delta, 1), "games": g})
        rows.sort(key=lambda r: r["delta_pts"])
        heroes[h] = {"win_pct": round(100 * base, 1), "games": hr_g[h], "struggles_against": rows[:3]}
    doc = {
        "_doc": ("Hero matchups (Founder's queue 2026-11-24, Q2d). Display only: nothing in the simulation reads this file. "
                 "From simulated games with equal teams (both moved to the same mean rating) and real AI drafts in the 1, 3 and "
                 "5 ban formats (tools/q2_analysis.py). For hero X, 'struggles_against' lists up to 3 heroes Y such that X's win "
                 f"rate in games where Y is on the other team is at least {STRUGGLE_PTS:.0f} points below X's own win rate "
                 f"(win_pct), with z <= -{STRUGGLE_Z} and at least {PAIR_MIN} games for the pair (games). delta_pts = X's win rate "
                 "against Y minus X's own, in points. Regenerate only with tools/q2_analysis.py."),
        "games": n, "min_pair_games": PAIR_MIN, "struggle_pts": STRUGGLE_PTS, "struggle_z": STRUGGLE_Z, "heroes": heroes,
    }
    (ROOT / "game/data/hero_matchups_v1.json").write_text(json.dumps(doc, indent=1, sort_keys=True) + "\n")
    with_rows = sum(1 for h in heroes.values() if h["struggles_against"])
    return n, with_rows, len(heroes)


def cmd_report(a):
    raw = pathlib.Path(a.raw)
    names = heroes_names()
    md = ["# Q2 analyses: hero by lane, Game Plan sweep, draft weight (2026-11-24)\n",
          "Founder's queue Q2 (`docs/design/ESMO-LESSONS.md`). Read-only: the simulation was run, never changed (golden hash "
          "unchanged). Harness `game/tests/q2_exp.gd`, runner `tools/q2_analysis.py`. Desktop simulation only.\n"]
    sec_a = section_a(raw, names, md)
    flags = section_b(raw, md)
    nums = section_c(raw, md)
    n, with_rows, total = section_d(raw, names)
    md.append("## d) Matchup table\n")
    md.append(f"`game/data/hero_matchups_v1.json` from {n:,} equal-team games (a) above: {with_rows} of {total} heroes have at "
              f"least one \"struggles against\" entry (at least {PAIR_MIN} games a pair, {STRUGGLE_PTS:.0f}+ points below the "
              f"hero's own win rate, z <= -{STRUGGLE_Z}). The definition is inside the file. Display only.\n")
    (ROOT / "docs/design/Q2-ANALYSIS.md").write_text("\n".join(md) + "\n")
    print(json.dumps({"a_outside": len(sec_a), "b_flags": flags, "d": [n, with_rows, total]}))


def cmd_plans_report(a):
    """Print only the Game Plan sweep section (markdown) for a re-measure; writes nothing."""
    md = []
    flags = section_b(pathlib.Path(a.raw), md)
    print("\n".join(md))
    print(json.dumps({"b_flags": flags}))


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("--game-dir", required=True)
    r.add_argument("--raw", required=True)
    r.add_argument("--jobs", type=int, default=6)
    r.add_argument("--heroes", type=int, default=40000)
    r.add_argument("--draft", type=int, default=5000)
    r.add_argument("--plans", type=int, default=2000)
    r.add_argument("--only", default="", help="comma list of modes to run: draft, plans, heroes")
    p = sub.add_parser("report")
    p.add_argument("--raw", required=True)
    pr = sub.add_parser("plans-report")
    pr.add_argument("--raw", required=True)
    a = ap.parse_args()
    {"run": cmd_run, "report": cmd_report, "plans-report": cmd_plans_report}[a.cmd](a)


if __name__ == "__main__":
    main()
