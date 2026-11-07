"""Reference match simulator (GDD section 8). P-002.

Deterministic: the result depends only on (team_a, team_b, match_seed, params).
Each contest draws one Normal(0,1) from its own named PCG32 substream, so
changing an input and replaying with the same match seed reuses the same noise
(exact counterfactuals). The Godot module (game/src/sim/match_sim.gd) must
reproduce game/tests/golden/sim_vectors.json generated from this file.

Team A is Blue side. A team is a dict:
  ratings   {"early"|"mid"|"late": {"top","jg","mid","bot","sup": float}}
  con       average consistency of the five starters
  team_mod  TeamMod fraction (chemistry + staff)
  comp_mod  CompMod fraction (draft composition)
  lane_mod  {"top","mid","bot","jg": fraction}
  style     "dive" | "siege" | "protect" | "skirmish"
Optional Game Plan hooks (interface frozen in v1; defaults leave results unchanged):
  contest_mod   {contest: fraction}  multiplies this team's rating entering that contest
  variance_mult float                multiplies this team's sigma in every contest (default 1)
  contest_var   {contest: float}     multiplies this team's sigma in one contest (default 1)
Contest weights (w_lane, obj_w, ...) are never changed by a plan; plans act only
through these three hooks.
"""
import json
import math
import pathlib

from pcg32 import contest_stream, fnv1a64

ROOT = pathlib.Path(__file__).resolve().parent.parent
SLOTS = ("top", "jg", "mid", "bot", "sup")
CONTESTS = ("top", "mid_lane", "bot", "jungle", "obj_mid", "fight_mid", "obj_late", "fight_late")


def load_params(path=None):
    p = json.loads(pathlib.Path(path or ROOT / "game/data/sim_params.json").read_text())
    return p


PARAMS = load_params()


def noise_scale(avg_con):
    """1.4 at consistency 0, 1.0 at 50, 0.6 at 100."""
    return 1.4 - 0.8 * (avg_con / 100.0)


def style_edge_for_a(style_a, style_b, p):
    if p["style_beats"].get(style_a) == style_b:
        return p["style_edge"]
    if p["style_beats"].get(style_b) == style_a:
        return -p["style_edge"]
    return 0.0


def weighted(ratings, weights):
    # fixed key order (the weights dict order) so the Godot port sums identically
    total = 0.0
    for s in weights:
        total += weights[s] * ratings[s]
    return total


def simulate(team_a, team_b, mseed, p=PARAMS):
    """Returns a dict: a_won, final, early, mid, late, contests{name: result},
    noise{name: draw (sigma_eff already applied)}."""
    base_a = p["sigma"] * noise_scale(team_a["con"]) * team_a.get("variance_mult", 1.0)
    base_b = p["sigma"] * noise_scale(team_b["con"]) * team_b.get("variance_mult", 1.0)
    noise = {}

    def contest(name, a, b, carry):
        a = a * (1.0 + team_a.get("contest_mod", {}).get(name, 0.0))
        b = b * (1.0 + team_b.get("contest_mod", {}).get(name, 0.0))
        s_a = base_a * team_a.get("contest_var", {}).get(name, 1.0)
        s_b = base_b * team_b.get("contest_var", {}).get(name, 1.0)
        sigma_eff = math.sqrt((s_a ** 2 + s_b ** 2) / 2.0)
        z = contest_stream(mseed, name).next_normal() * sigma_eff
        noise[name] = z
        return math.tanh((a - b) / p["D"] + p["gamma"] * carry + z)

    def eff(team, phase, slot, lane_key=None):
        r = team["ratings"][phase][slot] * (1.0 + team["team_mod"])
        if lane_key:
            r *= 1.0 + team["lane_mod"].get(lane_key, 0.0)
        return r

    c = {}
    carry0 = p["side_bonus"]
    c["top"] = contest("top", eff(team_a, "early", "top", "top"), eff(team_b, "early", "top", "top"), carry0)
    c["mid_lane"] = contest("mid_lane", eff(team_a, "early", "mid", "mid"), eff(team_b, "early", "mid", "mid"), carry0)
    duo_a = (eff(team_a, "early", "bot", "bot") + eff(team_a, "early", "sup", "bot")) / 2.0
    duo_b = (eff(team_b, "early", "bot", "bot") + eff(team_b, "early", "sup", "bot")) / 2.0
    c["bot"] = contest("bot", duo_a, duo_b, carry0)
    c["jungle"] = contest("jungle", eff(team_a, "early", "jg", "jg"), eff(team_b, "early", "jg", "jg"), carry0)
    a_early = p["w_lane"] * (c["top"] + c["mid_lane"] + c["bot"]) + p["w_jungle"] * c["jungle"]

    edge = style_edge_for_a(team_a["style"], team_b["style"], p)

    def team_ratings(team, phase, style_bonus):
        r = {s: eff(team, phase, s) for s in SLOTS}
        obj = weighted(r, p["obj_w"]) * (1.0 + team["comp_mod"])
        fight = weighted(r, p["fight_w"]) * (1.0 + team["comp_mod"] + style_bonus)
        return obj, fight

    def phase(ph, carry, w_obj):
        oa, fa = team_ratings(team_a, ph, edge)
        ob, fb = team_ratings(team_b, ph, -edge)
        r_obj = contest("obj_" + ph, oa, ob, carry)
        r_fight = contest("fight_" + ph, fa, fb, carry)
        c["obj_" + ph], c["fight_" + ph] = r_obj, r_fight
        return w_obj * r_obj + (1.0 - w_obj) * r_fight

    a_mid = phase("mid", a_early, p["w_mid_obj"])
    carry2 = p["carry_early"] * a_early + (1.0 - p["carry_early"]) * a_mid
    a_late = phase("late", carry2, p["w_late_obj"])
    final = p["f_early"] * a_early + p["f_mid"] * a_mid + p["f_late"] * a_late
    return {"a_won": final > 0.0, "final": final, "early": a_early, "mid": a_mid,
            "late": a_late, "contests": c, "noise": noise}


def make_team(rating, con=50.0, powers=(50, 50, 50), team_mod=0.0, comp_mod=0.0,
              lane_mod=None, style="skirmish"):
    """All five slots at the same base rating; hero power scales a phase by
    (1 + (power - 50)/200)."""
    ratings = {}
    for ph, pw in zip(("early", "mid", "late"), powers):
        r = rating * (1.0 + (pw - 50.0) / 200.0)
        ratings[ph] = {s: r for s in SLOTS}
    return {"ratings": ratings, "con": con, "team_mod": team_mod, "comp_mod": comp_mod,
            "lane_mod": lane_mod or {}, "style": style}
