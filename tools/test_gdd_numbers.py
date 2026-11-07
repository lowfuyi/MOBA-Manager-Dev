"""Executable checks for numbers quoted in the GDD (v1.4), so the document cannot drift from the maths."""
import math, random

# ---- 7.7 Team Bonds
def chem_bonus(bond, com, lang=1.0, k=0.042):
    u = lang * bond * (0.4 + 0.6 * com / 100)
    return k * u / 100  # all 20 values equal -> mean equals u

def test_chem_targets():
    assert 0.017 <= chem_bonus(60, 60) <= 0.020
    assert abs(chem_bonus(60, 60) * 100 - 1.92) < 0.01
    assert abs(chem_bonus(30, 60) * 100 - 0.96) < 0.01
    assert abs(chem_bonus(100, 60) * 100 - 3.19) < 0.01
    assert abs(chem_bonus(100, 100) * 100 - 4.2) < 0.001
    assert abs((chem_bonus(60, 100) - chem_bonus(60, 60)) * 100 - 0.6) < 0.05   # COM +40 at Bond 60
    assert abs((chem_bonus(100, 100) - chem_bonus(100, 60)) * 100 - 1.0) < 0.05  # COM +40 at Bond 100

def test_replacing_one_starter_costs_about_half_a_point():
    u_old, u_new = 60 * 0.76, 20 * 0.76
    chem = (12 * u_old + 8 * u_new) / 20          # 8 of 20 directional values involve the new player
    assert abs((chem_bonus(60, 60) - 0.042 * chem / 100) * 100 - 0.5) < 0.05

def test_bond_gain_shrinks_and_takes_about_30_games():
    b, games = 30.0, 0
    while b < 85:
        b += 4 * (100 - b) / 70
        games += 1
    assert 25 <= games <= 35

# ---- 7.3 fatigue
def weekly_net(facility, matches=2, rest_days=5):
    return 15 * matches + 5 - rest_days * (5 + 0.5 * facility)

def test_fatigue_builds_and_facilities_matter():
    assert weekly_net(0) == 10 and weekly_net(1) == 7.5 and weekly_net(3) == 2.5 and weekly_net(4) == 0
    assert 25 / weekly_net(1) < 4 and 9 * weekly_net(1) > 60

# ---- 7.8 Game Plan zero-sum
W = {"top": .084, "mid_lane": .084, "bot": .084, "jungle": .048, "obj_mid": .105, "fight_mid": .195, "obj_late": .100, "fight_late": .300}
PLANS = {
    "group": {"fight_mid": .02, "fight_late": .02, "top": -.033, "mid_lane": -.033, "bot": -.033, "jungle": -.033},
    "tempo": {"top": -.03, "mid_lane": -.03, "bot": -.03, "jungle": -.03, "obj_late": .0225, "fight_late": .0225},
    "mid_obj": {"obj_mid": .03, "fight_mid": -.0161},
    "late_obj": {"obj_late": .03, "fight_late": -.01},
    "support": {"bot": -.02, "obj_mid": .0082, "obj_late": .0082},
    "jungle_to_top": {"jungle": -.02, "top": .0114},
    "jungle_to_mid": {"jungle": -.02, "mid_lane": .0114},
    "jungle_to_bot": {"jungle": -.02, "bot": .0114},
}

def test_final_weights_sum_to_one():
    assert abs(sum(W.values()) - 1.0) < 1e-9

def test_every_game_plan_control_is_zero_sum():
    for name, mods in PLANS.items():
        assert abs(sum(W[c] * v for c, v in mods.items())) < 0.0005, name

# ---- 10.1 Form Rating (Elo)
def spearman(a, b):
    ra = {i: r for r, i in enumerate(sorted(range(len(a)), key=lambda i: a[i]))}
    rb = {i: r for r, i in enumerate(sorted(range(len(b)), key=lambda i: b[i]))}
    n = len(a)
    return 1 - 6 * sum((ra[i] - rb[i]) ** 2 for i in range(n)) / (n * (n * n - 1))

def test_elo_ranks_clubs_after_one_split():
    rnd = random.Random(1)
    true = [-16 + 32 * i / 9 for i in range(10)]
    rhos = []
    for _ in range(1500):
        elo = [1500.0] * 10
        games = [(i, j) for i in range(10) for j in range(10) if i != j]
        rnd.shuffle(games)
        for i, j in games:
            p = 1 / (1 + 10 ** (-(true[i] - true[j]) * 13 / 400))
            res = 1 if rnd.random() < p else 0
            e = 1 / (1 + 10 ** (-(elo[i] - elo[j]) / 400))
            elo[i] += 24 * (res - e); elo[j] -= 24 * (res - e)
        rhos.append(spearman(true, elo))
    assert sum(rhos) / len(rhos) >= 0.75

def test_elo_upset_moves_more_than_expected_win():
    e = 1 / (1 + 10 ** (-(200) / 400))      # favourite
    assert 24 * (0 - e) * -1 > 24 * (1 - e)  # upset loss magnitude > expected win gain

def test_elo_constant_matches_calibration():
    # +10 rating points -> about 68 percent with 13 Form points per rating point
    assert abs(1 / (1 + 10 ** (-(10 * 13) / 400)) - 0.68) < 0.02
