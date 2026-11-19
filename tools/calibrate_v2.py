#!/usr/bin/env python3
"""Match Sim v2 calibration driver (MATCH-SIM-V2-DESIGN 6.3). Runs the rows of game/tests/calib_v2.tscn in parallel Godot
processes (each row split into chunks with their own seeds), merges them and writes docs/design/MATCH-SIM-V2-CALIBRATION.md.

    GODOT=/path/to/godot python3 tools/calibrate_v2.py [--scale 1.0] [--jobs 7] [--quick]

--scale multiplies every row's game count (1.0 = the sign-off sizes below); --quick runs the win-rate rows only.
Not part of the fast gate (it takes tens of minutes). Bands are the GDD section 9 targets with the v2 tolerance (design 6.3).
"""
import argparse, concurrent.futures as cf, json, math, os, pathlib, statistics, subprocess, tempfile, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = ROOT / "game"

# (row id, label, env, games, band low, band high) ; band on A's win rate (percent)
ROWS = [
    ("gap0", "Equal teams (A plays both sides)", {"CAL_MODE": "gap", "CAL_GAP": "0"}, 1200, 47.0, 53.0),
    ("gap5", "Rating +5", {"CAL_MODE": "gap", "CAL_GAP": "5"}, 800, 57.0, 63.0),
    ("gap10", "Rating +10", {"CAL_MODE": "gap", "CAL_GAP": "10"}, 1200, 67.0, 73.0),
    ("gap20", "Rating +20", {"CAL_MODE": "gap", "CAL_GAP": "20"}, 800, 81.0, 87.0),
    ("gap30", "Rating +30", {"CAL_MODE": "gap", "CAL_GAP": "30"}, 600, 90.0, 96.0),
    ("con20", "+10 with both CON 20", {"CAL_MODE": "con", "CAL_GAP": "10", "CAL_CON_A": "20", "CAL_CON_B": "20"}, 800, 61.0, 69.0),
    ("con80", "+10 with both CON 80", {"CAL_MODE": "con", "CAL_GAP": "10", "CAL_CON_A": "80", "CAL_CON_B": "80"}, 800, 69.0, 79.0),
    ("comp10", "CompMod +10% vs none", {"CAL_MODE": "comp", "CAL_COMP": "0.10"}, 1200, 55.0, 60.0),
    ("comp5", "CompMod +5% vs none", {"CAL_MODE": "comp", "CAL_COMP": "0.05"}, 1200, 52.0, 56.0),
    ("dive", "Dive vs Siege (style edge)", {"CAL_MODE": "style", "CAL_STYLE_A": "dive", "CAL_STYLE_B": "siege"}, 1200, 52.5, 56.5),
    ("counter", "Lane counter +5% in all lanes", {"CAL_MODE": "counter", "CAL_LM": "0.05"}, 1200, 50.5, 54.5),
]
PLAN_ROWS = [(f"plan_{c}{'p' if v > 0 else 'm'}", f"Plan {c} {v:+d}", {"CAL_MODE": "plan", "CAL_CTL": c, "CAL_VAL": str(v)}, 600, 44.0, 56.0)
             for c in ["g", "t", "m", "l", "a", "s", "r"] for v in (100, -100)]
HERO_ROW = ("heroes", "Per-hero win rate (random drafts, equal teams)", {"CAL_MODE": "heroes", "CAL_GAP": "0"}, 3000, 45.0, 55.0)


def run_chunk(godot, env_extra, n, seed):
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tf:
        out = tf.name
    env = dict(os.environ, CAL_N=str(n), CAL_SEED=str(seed), CAL_OUT=out, **env_extra)
    subprocess.run(["timeout", "1500", godot, "--headless", "res://tests/calib_v2.tscn"], cwd=GAME, env=env,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        return json.loads(pathlib.Path(out).read_text())
    finally:
        pathlib.Path(out).unlink(missing_ok=True)


def merge(parts):
    m = {"n": 0, "a_wins": 0, "stats": {"len": [], "kills": [], "final": [], "more_kills_won": 0, "ahead8_won": 0, "ahead8_n": 0,
                                        "behind_trig": 0, "ahead_trig": 0, "safety": 0}, "hero_g": {}, "hero_w": {}, "ms": 0}
    for p in parts:
        m["n"] += p["n"]
        m["a_wins"] += p["a_wins"]
        m["ms"] += p["ms"]
        for k, v in p["stats"].items():
            if isinstance(v, list):
                m["stats"][k] += v
            else:
                m["stats"][k] += v
        for h, g in p.get("hero_g", {}).items():
            m["hero_g"][h] = m["hero_g"].get(h, 0) + g
        for h, w in p.get("hero_w", {}).items():
            m["hero_w"][h] = m["hero_w"].get(h, 0) + w
    return m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--rows", default="", help="comma-separated row ids to run (default: all)")
    ap.add_argument("--out", default=str(ROOT / "docs/design/MATCH-SIM-V2-CALIBRATION.md"))
    a = ap.parse_args()
    godot = os.environ.get("GODOT")
    assert godot, "set GODOT"
    rows = ROWS + ([] if a.quick else PLAN_ROWS + [HERO_ROW])
    rows.insert(0, ("plan_none", "Plan: neutral baseline (same seeds as the plan rows)", {"CAL_MODE": "plan", "CAL_CTL": ""}, 600, 47.0, 53.0)) if not a.quick else None
    if a.rows:
        keep = set(a.rows.split(","))
        rows = [r for r in rows if r[0] in keep]
    chunk = 100
    jobs = []
    t0 = time.time()
    with cf.ThreadPoolExecutor(max_workers=a.jobs) as ex:
        for ri, (rid, label, env, n, lo, hi) in enumerate(rows):
            n = max(chunk, int(n * a.scale))
            for c in range((n + chunk - 1) // chunk):
                # plan rows share seeds so they are paired with the neutral baseline
                seed = 1000 + c if rid.startswith("plan") else 5000 * (ri + 1) + c
                jobs.append((rid, ex.submit(run_chunk, godot, env, chunk, seed)))
        results = {}
        for rid, fut in jobs:
            results.setdefault(rid, []).append(fut.result())
    wall = time.time() - t0
    lines = ["# Match Sim v2 calibration report", "",
             f"Generated by `tools/calibrate_v2.py` (scale {a.scale}) on {time.strftime('%Y-%m-%d')}; {wall/60:.1f} minutes wall clock with {a.jobs} parallel headless Godot processes on the development desktop. "
             "Synthetic teams (uniform ratings, generic players with all stats 60, random role-correct picks, sides alternated). Bands: GDD section 9 targets with the v2 tolerance (design 6.3). "
             "**Not run on a phone.**", "", "| Row | Games | A wins | Band | Verdict |", "|---|---|---|---|---|"]
    all_ok = True
    summary = {}
    for rid, label, env, n, lo, hi in rows:
        m = merge(results[rid])
        rate = 100.0 * m["a_wins"] / max(1, m["n"])
        se = 100.0 * math.sqrt(max(1e-9, rate / 100 * (1 - rate / 100)) / max(1, m["n"]))
        ok = lo - 2 * se <= rate <= hi + 2 * se if rid != "heroes" else True
        all_ok = all_ok and ok
        summary[rid] = m
        if rid != "heroes":
            lines.append(f"| {label} | {m['n']} | {rate:.1f}% (SE {se:.1f}) | {lo:.0f} to {hi:.0f}% | {'in band' if ok else 'OUT'} |")
    gaps = [summary[r] for r in summary if r.startswith("gap")] or list(summary.values())
    st = merge(gaps)["stats"]
    lens = sorted(st["len"])
    kills = sorted(st["kills"])
    fin = sorted(st["final"])
    n_all = len(lens)
    pct = lambda xs, q: xs[min(len(xs) - 1, int(q * len(xs)))]
    lines += ["", "## Game statistics (all rating-gap rows)", "",
              f"- Games: {n_all}. Length median {statistics.median(lens):.1f} game minutes, 5th to 95th percentile {pct(lens, .05):.1f} to {pct(lens, .95):.1f} (target median 13 to 16, 90 percent within 9 to 24).",
              f"- Team kills per game median {statistics.median(kills)}, 5th to 95th {pct(kills, .05)} to {pct(kills, .95)} (target median 18 to 30).",
              f"- The team with more kills won {100.0 * st['more_kills_won'] / n_all:.1f} percent of games.",
              f"- |final| median {statistics.median(fin):.3f}; narrow (< 0.15) {100.0 * sum(1 for x in fin if x < 0.15) / n_all:.0f}%, clear (0.15 to 0.40) {100.0 * sum(1 for x in fin if 0.15 <= x < 0.40) / n_all:.0f}%, decisive {100.0 * sum(1 for x in fin if x >= 0.40) / n_all:.0f}% (v1 wording targets about 25 / 35 / 40).",
              f"- Plan triggers at 8:00 (gold lead past the threshold): behind fired in {100.0 * st['behind_trig'] / n_all:.1f}% of games, ahead in {100.0 * st['ahead_trig'] / n_all:.1f}% (target about 18 each in equal games; this sample mixes gaps).",
              f"- A team ahead by the trigger margin at 8:00 went on to win {100.0 * st['ahead8_won'] / max(1, st['ahead8_n']):.1f}% (comeback rate {100.0 - 100.0 * st['ahead8_won'] / max(1, st['ahead8_n']):.1f}%, target 20 to 40).",
              f"- Safety stop (35:00) used in {st['safety']} games (should be 0).",
              f"- Cost: {sum(summary[r]['ms'] for r in summary) / max(1, sum(summary[r]['n'] for r in summary)):.0f} ms per game per process (headless desktop, not a phone)."]
    if "heroes" in summary:
        m = summary["heroes"]
        rows_h = sorted(((100.0 * m["hero_w"].get(h, 0) / g, h, g) for h, g in m["hero_g"].items()))
        out_band = [r for r in rows_h if not (45.0 <= r[0] <= 55.0)]
        lines += ["", "## Heroes at equal skill (random drafts)", "",
                  f"{len(rows_h)} heroes, {min(r[2] for r in rows_h)} to {max(r[2] for r in rows_h)} games each. Band 45 to 55 percent. Outside the band: {len(out_band)}.", "",
                  "| Hero | Games | Win rate |", "|---|---|---|"]
        for wr, h, g in rows_h:
            lines.append(f"| {h} | {g} | {wr:.1f}%{' (OUT)' if not (45.0 <= wr <= 55.0) else ''} |")
    lines += ["", f"Overall: {'every win-rate row in band' if all_ok else 'some rows OUT of band (see table)'}."]
    pathlib.Path(a.out).write_text("\n".join(lines) + "\n")
    if "heroes" in summary:
        m = summary["heroes"]
        json_out = {h: m["hero_w"].get(h, 0) / g for h, g in m["hero_g"].items()}
        pathlib.Path(a.out).with_suffix(".heroes.json").write_text(json.dumps(json_out, indent=1, sort_keys=True))
    print("\n".join(lines[:40]))
    print("written", a.out)


if __name__ == "__main__":
    main()
