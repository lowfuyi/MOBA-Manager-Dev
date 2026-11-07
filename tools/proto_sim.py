#!/usr/bin/env python3
"""Prototype match simulator for calibration (Systems Lead, GDD section 8).

Purpose: check that the formulas in docs/design/GDD-v1.md hit the QA targets in
GDD section 9 before any engine code is written. This is NOT the game code.
All constants live in PARAMS so QA can tune them.

Team A is always Blue side in this prototype.

Usage:
    python3 -I tools/proto_sim.py [n_matches]     run the calibration report
"""
import math
import random
import sys

PARAMS = {
    "D": 25.0,            # rating points per 1.0 of contest input
    "sigma": 2.0,         # base noise per contest
    "gamma": 0.8,         # how much earlier lead carries into later contests
    "w_lane": 0.28,       # weight of each of top / mid / bot lane in A_early
    "w_jungle": 0.16,     # weight of the jungle contest in A_early
    "w_mid_obj": 0.35,    # objectives share of A_mid (rest is teamfights)
    "w_late_obj": 0.25,   # objectives share of A_late (rest is teamfights)
    "carry_early": 0.5,   # share of A_early (vs A_mid) carried into late contests
    "f_early": 0.30,      # weight of each phase in the final score
    "f_mid": 0.30,
    "f_late": 0.40,
    "side_bonus": 0.02,   # blue side starts with this carry-over advantage
    "style_edge": 0.04,   # rating bonus for winning the comp-style triangle
}

# Slot weights for mid and late contests (each sums to 1.00).
OBJ_W = {"jg": 0.30, "sup": 0.25, "mid": 0.15, "top": 0.15, "bot": 0.15}
FIGHT_W = {"bot": 0.25, "mid": 0.25, "top": 0.20, "jg": 0.15, "sup": 0.15}

# Comp-style triangle: key beats value.
STYLE_BEATS = {"dive": "siege", "siege": "protect", "protect": "dive"}


def noise_scale(avg_consistency):
    """Sigma multiplier: 1.4 at consistency 0, 1.0 at 50, 0.6 at 100."""
    return 1.4 - 0.8 * (avg_consistency / 100.0)


def style_edge_for_a(style_a, style_b, p=PARAMS):
    if STYLE_BEATS.get(style_a) == style_b:
        return p["style_edge"]
    if STYLE_BEATS.get(style_b) == style_a:
        return -p["style_edge"]
    return 0.0


def contest(a, b, carry, sigma_eff, rng, p=PARAMS):
    x = (a - b) / p["D"] + p["gamma"] * carry + rng.gauss(0.0, sigma_eff)
    return math.tanh(x)


def weighted(ratings, weights):
    return sum(weights[s] * ratings[s] for s in weights)


def simulate(team_a, team_b, rng, p=PARAMS):
    """team = dict:
        ratings   {phase: {slot: rating}}  phases early/mid/late, slots top jg mid bot sup
        con       average consistency of the five starters
        team_mod  chemistry + staff bonus (fraction, e.g. 0.02)
        comp_mod  draft composition modifier (fraction), applies to objectives and fights
        lane_mod  {lane: fraction} counter-pick matchup bonus for top/mid/bot/jg
        style     'dive' | 'siege' | 'protect' | 'skirmish'
    Returns (a_won, details). details holds the contest results used for reports."""
    s_a = p["sigma"] * noise_scale(team_a["con"])
    s_b = p["sigma"] * noise_scale(team_b["con"])
    sigma_eff = math.sqrt((s_a ** 2 + s_b ** 2) / 2.0)

    def eff(team, phase, slot, lane_key=None):
        r = team["ratings"][phase][slot] * (1.0 + team["team_mod"])
        if lane_key:
            r *= 1.0 + team["lane_mod"].get(lane_key, 0.0)
        return r

    carry0 = p["side_bonus"]
    d = {}
    d["top"] = contest(eff(team_a, "early", "top", "top"), eff(team_b, "early", "top", "top"), carry0, sigma_eff, rng, p)
    d["mid_lane"] = contest(eff(team_a, "early", "mid", "mid"), eff(team_b, "early", "mid", "mid"), carry0, sigma_eff, rng, p)
    duo_a = (eff(team_a, "early", "bot", "bot") + eff(team_a, "early", "sup", "bot")) / 2.0
    duo_b = (eff(team_b, "early", "bot", "bot") + eff(team_b, "early", "sup", "bot")) / 2.0
    d["bot"] = contest(duo_a, duo_b, carry0, sigma_eff, rng, p)
    d["jungle"] = contest(eff(team_a, "early", "jg", "jg"), eff(team_b, "early", "jg", "jg"), carry0, sigma_eff, rng, p)
    a_early = p["w_lane"] * (d["top"] + d["mid_lane"] + d["bot"]) + p["w_jungle"] * d["jungle"]

    edge = style_edge_for_a(team_a["style"], team_b["style"], p)

    def phase_team_ratings(team, phase, style_bonus):
        ratings = {s: eff(team, phase, s) for s in ("top", "jg", "mid", "bot", "sup")}
        obj = weighted(ratings, OBJ_W) * (1.0 + team["comp_mod"])
        fight = weighted(ratings, FIGHT_W) * (1.0 + team["comp_mod"] + style_bonus)
        return obj, fight

    def phase(ph, carry, w_obj):
        obj_a, fight_a = phase_team_ratings(team_a, ph, edge)
        obj_b, fight_b = phase_team_ratings(team_b, ph, -edge)
        r_obj = contest(obj_a, obj_b, carry, sigma_eff, rng, p)
        r_fight = contest(fight_a, fight_b, carry, sigma_eff, rng, p)
        return w_obj * r_obj + (1.0 - w_obj) * r_fight, r_obj, r_fight

    a_mid, d["obj_mid"], d["fight_mid"] = phase("mid", a_early, p["w_mid_obj"])
    carry2 = p["carry_early"] * a_early + (1.0 - p["carry_early"]) * a_mid
    a_late, d["obj_late"], d["fight_late"] = phase("late", carry2, p["w_late_obj"])

    final = p["f_early"] * a_early + p["f_mid"] * a_mid + p["f_late"] * a_late
    d.update(early=a_early, mid=a_mid, late=a_late, final=final)
    return final > 0.0, d


def make_team(rating, con=50.0, powers=(50, 50, 50), team_mod=0.0, comp_mod=0.0,
              lane_mod=None, style="skirmish"):
    """Build a team where all five slots have the same base rating.
    powers = hero (early, mid, late) power; applied as (1 + (power - 50)/200)."""
    ratings = {}
    for ph, pw in zip(("early", "mid", "late"), powers):
        r = rating * (1.0 + (pw - 50.0) / 200.0)
        ratings[ph] = {s: r for s in ("top", "jg", "mid", "bot", "sup")}
    return {"ratings": ratings, "con": con, "team_mod": team_mod, "comp_mod": comp_mod,
            "lane_mod": lane_mod or {}, "style": style}


def win_rate(team_a, team_b, n, seed=1):
    rng = random.Random(seed)
    return sum(simulate(team_a, team_b, rng)[0] for _ in range(n)) / n


def comeback_rate(n, seed=2, threshold=0.2):
    """Equal teams, no side bonus. Of matches where one team leads after the early
    game by |A_early| >= threshold, how often does the team that was behind win?"""
    rng = random.Random(seed)
    p = dict(PARAMS, side_bonus=0.0)
    a, b = make_team(60.0), make_team(60.0)
    behind_wins = total = 0
    for _ in range(n):
        won, d = simulate(a, b, rng, p)
        if abs(d["early"]) >= threshold:
            total += 1
            leader_is_a = d["early"] > 0
            if won != leader_is_a:
                behind_wins += 1
    return behind_wins / max(1, total)


def report(n):
    print("Calibration report (n=%d)" % n)
    print("\nRating advantage -> Blue win rate (equal CON 50, neutral heroes)")
    for diff in (0, 5, 10, 20, 30):
        print("  +%-2d  %.3f" % (diff, win_rate(make_team(60 + diff), make_team(60), n)))
    print("\nConsistency effect at +10 advantage")
    for c in (20, 50, 80):
        print("  avg CON %-2d  %.3f" % (c, win_rate(make_team(70, c), make_team(60, c), n)))
    print("\nHero power curve (equal skill): late-heavy vs early-heavy (powers 62/50/38 swapped)")
    print("  late-heavy win rate  %.3f" % win_rate(make_team(60, powers=(38, 50, 62)),
                                                  make_team(60, powers=(62, 50, 38)), n))
    print("\nOne-phase-only advantage (+10 rating in that phase, equal elsewhere)")
    for ph in ("early", "mid", "late"):
        a = make_team(60)
        for s in a["ratings"][ph]:
            a["ratings"][ph][s] += 10
        print("  %-5s %.3f" % (ph, win_rate(a, make_team(60), n)))
    print("\nDraft effect (equal players): comp_mod +10%%/0%%: %.3f" %
          win_rate(make_team(60, comp_mod=0.10), make_team(60), n))
    print("Style triangle (dive vs siege, equal players): %.3f" %
          win_rate(make_team(60, style="dive"), make_team(60, style="siege"), n))
    print("Counter-pick lane bonus +5%% in top/mid/bot: %.3f" %
          win_rate(make_team(60, lane_mod={"top": .05, "mid": .05, "bot": .05}), make_team(60), n))
    print("\nComeback rate (team behind after early game wins): %.3f" % comeback_rate(n))


if __name__ == "__main__":
    report(int(sys.argv[1]) if len(sys.argv) > 1 else 40000)
