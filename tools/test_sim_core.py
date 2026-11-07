import json, pathlib, sys, copy
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import sim_core as S
import calibrate as C
from pcg32 import match_seed

ROOT = pathlib.Path(__file__).resolve().parent.parent
GOLD = json.loads((ROOT / "game/tests/golden/sim_vectors.json").read_text())


def test_deterministic():
    a, b = S.make_team(65), S.make_team(60)
    s = match_seed(1, "m1")
    assert S.simulate(a, b, s) == S.simulate(a, b, s)


def test_different_seed_changes_noise():
    a, b = S.make_team(65), S.make_team(60)
    assert S.simulate(a, b, match_seed(1, "m1"))["noise"] != S.simulate(a, b, match_seed(1, "m2"))["noise"]


def test_counterfactual_keeps_noise_but_changes_result_inputs():
    a, b = S.make_team(60), S.make_team(60)
    a2 = copy.deepcopy(a); a2["comp_mod"] = 0.10
    s = match_seed(7, "cf")
    r1, r2 = S.simulate(a, b, s), S.simulate(a2, b, s)
    assert r1["noise"] == r2["noise"]
    assert r2["final"] > r1["final"]


def test_golden_file_matches_reference():
    save_seed = (GOLD["save_seed"]["hi"] << 32) | GOLD["save_seed"]["lo"]
    for c in GOLD["cases"]:
        assert S.simulate(c["team_a"], c["team_b"], match_seed(save_seed, c["match_id"])) == c["expect"]


def test_equal_teams_without_side_bonus_are_even():
    p = dict(S.PARAMS, side_bonus=0.0)
    n = 20000
    w = sum(S.simulate(S.make_team(60), S.make_team(60), match_seed(3, "eq%d" % i), p)["a_won"] for i in range(n))
    assert abs(w / n - 0.5) < 0.012


def test_more_rating_never_hurts():
    n, prev = 6000, 0.0
    for diff in (0, 5, 10, 20, 30):
        w = C.win_rate(S.make_team(60 + diff), S.make_team(60), n, "mono%d" % diff)
        assert w > prev
        prev = w


def test_calibration_bands_hold_at_reduced_sample():
    rows = C.run(10000)
    bad = [(n, v, lo, hi) for n, v, lo, hi in rows if not lo <= v <= hi]
    assert bad == []


def test_plan_hooks_default_to_no_change():
    a, b = S.make_team(63), S.make_team(60)
    a2 = copy.deepcopy(a)
    a2.update(contest_mod={}, variance_mult=1.0, contest_var={})
    s = match_seed(5, "hooks")
    assert S.simulate(a, b, s) == S.simulate(a2, b, s)


def test_contest_mod_moves_only_that_contest_input():
    a, b = S.make_team(60), S.make_team(60)
    a2 = copy.deepcopy(a); a2["contest_mod"] = {"fight_late": 0.05}
    s = match_seed(5, "hooks2")
    r1, r2 = S.simulate(a, b, s), S.simulate(a2, b, s)
    assert r1["noise"] == r2["noise"]
    assert r1["contests"]["top"] == r2["contests"]["top"]
    assert r2["contests"]["fight_late"] != r1["contests"]["fight_late"]


def test_variance_mult_scales_noise_in_every_contest():
    a, b = S.make_team(60), S.make_team(60)
    a2 = copy.deepcopy(a); a2["variance_mult"] = 1.5
    s = match_seed(5, "hooks3")
    n1, n2 = S.simulate(a, b, s)["noise"], S.simulate(a2, b, s)["noise"]
    assert all(abs(n2[k]) > abs(n1[k]) * 1.1 or n1[k] == 0 for k in n1)
