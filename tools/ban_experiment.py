#!/usr/bin/env python3
"""Ban experiment (Founder decision 2026-11-22): Classic (1 ban a side, 3 in game 1 of a playoff series) against Standard
(3 bans, 5 in league and playoffs). Runs game/tests/ban_exp.tscn in parallel Godot processes for 1, 3 and 5 bans a side,
adds the role-floor property test (random drafts, pure Python) and writes docs/design/BAN-EXPERIMENT.md.

    GODOT=/path/to/godot python3 tools/ban_experiment.py [--games 40000] [--jobs 7] [--counts 1,3,5] [--floor 100000]

Not part of the fast gate (about an hour on 7 cores for 3 x 40,000 games).
"""
import argparse, concurrent.futures as cf, json, os, pathlib, random, statistics, subprocess, tempfile, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
SLOTS = ["top", "jg", "mid", "bot", "sup"]
BANDS = {"0": (47.0, 53.0), "5": (57.0, 63.0), "10": (67.0, 73.0), "20": (81.0, 87.0), "30": (90.0, 96.0)}
HERO_BAND = (45.0, 55.0)
HERO_MIN_GAMES = 300


def run_chunk(godot, nb, n, seed, game_dir=GAME):
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tf:
        out = tf.name
    env = dict(os.environ, BX_BANS=str(nb), BX_N=str(n), BX_SEED=str(seed), BX_OUT=out)
    subprocess.run(["timeout", "3000", godot, "--headless", "res://tests/ban_exp.tscn"], cwd=game_dir, env=env,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
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
        for k in ("n", "n0", "blue_wins0", "ms", "ms_draft", "floor_binds"):
            m[k] += p[k]
        for k in ("comfort_lost", "raw_gap_won", "len", "kills"):
            m[k] += p[k]
        for g, r in p["rows"].items():
            mr = m["rows"].setdefault(g, {"n": 0, "a_wins": 0})
            mr["n"] += r["n"]
            mr["a_wins"] += r["a_wins"]
        for k in ("hero_g", "hero_w", "hero_pick", "hero_ban"):
            for h, v in p[k].items():
                m[k][h] = m[k].get(h, 0) + v
        for s in ("B", "R"):
            m["comfort_lost_side"][s] += p["comfort_lost_side"][s]
            m["famf"][s] += p["famf"][s]
        for k in ("lost", "lost_won"):
            m["lost_win"][k] += p["lost_win"][k]
    return m


def floor_test(order, roles, drafts, seed):
    """Random drafts (any available hero, any open lane). Returns (dead ends, drafts where the GDD 6 floor would bind)."""
    rng = random.Random(seed)
    dead = bound = 0
    heroes = list(roles)
    for _ in range(drafts):
        avail = heroes[:]
        open_ = {"B": SLOTS[:], "R": SLOTS[:]}
        hit = False
        for team, kind in order:
            if not avail:
                dead += 1
                break
            avail.remove(rng.choice(avail))
            if kind == "pick":
                if not open_[team]:
                    dead += 1
                    break
                open_[team].remove(rng.choice(open_[team]))
            for s in SLOTS:
                need = (s in open_["B"]) + (s in open_["R"])
                if need and sum(1 for h in avail if roles[h] == s) < need + (1 if kind == "ban" else 0):
                    hit = True
        else:
            if open_["B"] or open_["R"]:
                dead += 1
        bound += hit
    return dead, bound


def pct(a, b):
    return 100.0 * a / b if b else 0.0


def summary(m):
    n0 = max(1, m["n0"])
    rows = {g: (pct(r["a_wins"], r["n"]), r["n"]) for g, r in m["rows"].items()}
    games = m["n"]
    presence = {}
    for h in set(m["hero_pick"]) | set(m["hero_ban"]) | set(m["hero_g"]):
        presence[h] = (m["hero_pick"].get(h, 0), m["hero_ban"].get(h, 0))
    heroes_wr = {h: (pct(m["hero_w"].get(h, 0), g), g) for h, g in m["hero_g"].items()}
    cl = m["comfort_lost"]
    return {"rows": rows, "blue0": pct(m["blue_wins0"], n0), "n0": m["n0"], "games": games, "presence": presence, "wr": heroes_wr,
            "comfort_mean": statistics.mean(cl) if cl else 0.0, "comfort_ge2": pct(sum(1 for x in cl if x >= 2), len(cl)),
            "comfort_ge3": pct(sum(1 for x in cl if x >= 3), len(cl)), "comfort_max": max(cl) if cl else 0,
            "comfort_side": {s: m["comfort_lost_side"][s] / max(1, games) for s in "BR"},
            "famf": {s: m["famf"][s] / max(1, games) for s in "BR"},
            "lost_win": pct(m["lost_win"]["lost_won"], m["lost_win"]["lost"]), "lost_n": m["lost_win"]["lost"],
            "len": statistics.median(m["len"]) if m["len"] else 0.0, "kills": statistics.median(m["kills"]) if m["kills"] else 0,
            "ms_game": m["ms"] / max(1, games), "ms_draft": m["ms_draft"] / max(1, games), "floor_binds": m["floor_binds"]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--games", type=int, default=40000)
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    ap.add_argument("--counts", default="1,3,5")
    ap.add_argument("--floor", type=int, default=100000)
    ap.add_argument("--chunk", type=int, default=400)
    ap.add_argument("--game-dir", default=str(GAME), help="a copy of game/ to run in (so game/ can change meanwhile)")
    ap.add_argument("--json", default=str(ROOT / "docs/design/ban_experiment_raw.json"))
    a = ap.parse_args()
    godot = os.environ.get("GODOT")
    assert godot, "set GODOT"
    counts = [int(x) for x in a.counts.split(",")]
    t0 = time.time()
    res = {}
    with cf.ProcessPoolExecutor(max_workers=a.jobs) as ex:
        futs = {}
        for nb in counts:
            for c in range(max(1, a.games // a.chunk)):
                futs[ex.submit(run_chunk, godot, nb, a.chunk, 1000 * nb + c + 1, a.game_dir)] = nb
        parts = {nb: [] for nb in counts}
        for f in cf.as_completed(futs):
            parts[futs[f]].append(f.result())
    for nb in counts:
        res[nb] = summary(merge(parts[nb]))
        res[nb]["failed_chunks"] = sum(1 for p in parts[nb] if p is None)
    fmt = json.loads((GAME / "data/draft_formats_v1.json").read_text())
    heroes = json.loads((GAME / "data/heroes.json").read_text())
    roles = {h["id"]: h["role_primary"] for h in (heroes if isinstance(heroes, list) else heroes.values())}
    floor = {nb: floor_test([tuple(x) for x in fmt["orders"][str(nb)]], roles, a.floor, 99 + nb) for nb in counts}
    out = {"games_per_count": a.games, "elapsed_s": time.time() - t0, "res": {str(k): v for k, v in res.items()},
           "floor": {str(k): v for k, v in floor.items()}, "floor_drafts": a.floor}
    pathlib.Path(a.json).write_text(json.dumps(out, indent=1))
    for nb in counts:
        r = res[nb]
        bad_bands = [g for g, (v, _) in r["rows"].items() if not BANDS[g][0] <= v <= BANDS[g][1]]
        wr_in = [h for h, (v, g) in r["wr"].items() if g >= HERO_MIN_GAMES]
        out_band = [h for h in wr_in if not HERO_BAND[0] <= r["wr"][h][0] <= HERO_BAND[1]]
        print(f"bans {nb}: rows {{{', '.join(f'{g}: {v:.1f}' for g, (v, _) in sorted(r['rows'].items(), key=lambda x: int(x[0])))}}} "
              f"blue0 {r['blue0']:.1f} out-of-band rows {bad_bands} heroes rated {len(wr_in)} out {len(out_band)} "
              f"floor {floor[nb]} comfort {r['comfort_mean']:.2f} failed {r['failed_chunks']}")
    print(f"elapsed {time.time() - t0:.0f} s; raw results in {a.json}")


if __name__ == "__main__":
    main()
