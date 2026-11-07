#!/usr/bin/env python3
"""Prototype match simulator for calibration (Systems Lead, GDD v1 section 8).

Purpose: check that the formulas in docs/design/GDD-v1.md can hit the target
win-probability curve before any engine code is written. This is NOT the game
code. All constants live in PARAMS so QA can tune them.

Usage: python3 tools/proto_sim.py [n_matches]
"""
import math
import random
import sys

PARAMS = {
    "D": 20.0,           # rating points per 1.0 of contest input
    "sigma": 1.5,        # base noise per contest
    "gamma": 0.7,        # how much earlier lead carries into later contests
    "w_lane": 0.28,      # weight of each of top / mid / bot lane in early advantage
    "w_jungle": 0.16,    # weight of jungle contest in early advantage
    "w_mid_obj": 0.35,   # objectives share of mid-game advantage
    "w_late_obj": 0.25,  # objectives share of late-game advantage
    "carry_early": 0.4,  # share of early advantage carried into late contests
    "side_bonus": 0.02,  # blue side starts with this carry-over advantage
}


def noise_scale(avg_consistency):
    """Sigma multiplier: 1.4 at consistency 0, 1.0 at 50, 0.6 at 100."""
    return 1.4 - 0.8 * (avg_consistency / 100.0)


def contest(a, b, carry, sigma_eff, rng, p=PARAMS):
    x = (a - b) / p["D"] + p["gamma"] * carry + rng.gauss(0.0, sigma_eff)
    return math.tanh(x)


def simulate(team_a, team_b, rng, p=PARAMS):
    """team = dict with 'early','mid','late' -> dict(role->rating),
    'con' -> avg consistency. Returns (a_won, details)."""
    s_a = p["sigma"] * noise_scale(team_a["con"])
    s_b = p["sigma"] * noise_scale(team_b["con"])
    sigma_eff = math.sqrt((s_a ** 2 + s_b ** 2) / 2.0)

    def duo(t, ph):
        return (t[ph]["bot"] + t[ph]["sup"]) / 2.0

    def mean(t, ph):
        return sum(t[ph].values()) / 5.0

    carry0 = p["side_bonus"]
    r_top = contest(team_a["early"]["top"], team_b["early"]["top"], carry0, sigma_eff, rng, p)
    r_mid = contest(team_a["early"]["mid"], team_b["early"]["mid"], carry0, sigma_eff, rng, p)
    r_bot = contest(duo(team_a, "early"), duo(team_b, "early"), carry0, sigma_eff, rng, p)
    r_jg = contest(team_a["early"]["jg"], team_b["early"]["jg"], carry0, sigma_eff, rng, p)
    a_early = p["w_lane"] * (r_top + r_mid + r_bot) + p["w_jungle"] * r_jg

    r_obj = contest(mean(team_a, "mid"), mean(team_b, "mid"), a_early, sigma_eff, rng, p)
    r_fight = contest(mean(team_a, "mid"), mean(team_b, "mid"), a_early, sigma_eff, rng, p)
    a_mid = p["w_mid_obj"] * r_obj + (1 - p["w_mid_obj"]) * r_fight

    carry2 = p["carry_early"] * a_early + (1 - p["carry_early"]) * a_mid
    r_obj2 = contest(mean(team_a, "late"), mean(team_b, "late"), carry2, sigma_eff, rng, p)
    r_fight2 = contest(mean(team_a, "late"), mean(team_b, "late"), carry2, sigma_eff, rng, p)
    a_late = p["w_late_obj"] * r_obj2 + (1 - p["w_late_obj"]) * r_fight2

    return a_late > 0.0, {"early": a_early, "mid": a_mid, "late": a_late}


def flat_team(rating, con=50.0):
    roles = {"top": rating, "jg": rating, "mid": rating, "bot": rating, "sup": rating}
    return {"early": dict(roles), "mid": dict(roles), "late": dict(roles), "con": con}


def win_rate(diff, n, seed=1, con=50.0):
    rng = random.Random(seed)
    a, b = flat_team(60.0 + diff, con), flat_team(60.0, con)
    wins = sum(simulate(a, b, rng)[0] for _ in range(n))
    return wins / n


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
    print("rating diff -> blue win rate (n=%d)" % n)
    for d in (0, 2, 5, 10, 15, 20, 30):
        print("  +%-2d  %.3f" % (d, win_rate(d, n)))
    print("consistency effect at +10 diff:")
    for c in (20, 50, 80):
        print("  avg CON %-2d  %.3f" % (c, win_rate(10, n, con=c)))
