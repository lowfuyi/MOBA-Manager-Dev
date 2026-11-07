"""Tests for the generated content (heroes, players, clubs). D-005 / D-008."""
import collections, itertools, json, pathlib, statistics, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import validate_data as V
from comp import comp_eval, CAP
import gen_players as GP

ROOT = pathlib.Path(__file__).resolve().parent.parent
D = ROOT / "game/data"
H = json.loads((D / "heroes.json").read_text())
P = json.loads((D / "players.json").read_text())
C = json.loads((D / "clubs.json").read_text())
SLOTS = ("top", "jg", "mid", "bot", "sup")
PID = {p["id"]: p for p in P}


def test_whole_data_dir_validates():
    assert V.validate_dir(D) == []


def test_generated_files_are_reproducible():
    ps, cs = GP.build()
    assert ps == P and cs == C
    import gen_heroes
    assert gen_heroes.build() == H


# ---------------- heroes
def test_forty_heroes_eight_per_slot_unique_names():
    assert len(H) == 40
    assert collections.Counter(h["role_primary"] for h in H) == {s: 8 for s in SLOTS}
    names = [h["name"].lower() for h in H]
    assert len(set(names)) == 40
    block = json.loads((D / "names/block_list.json").read_text())["reference_hero_names"]
    assert not {n.lower() for n in block} & set(names)


def test_counter_graph_is_balanced_and_never_mutual():
    indeg = collections.Counter(t for h in H for t in h["strong_vs"])
    ids = {h["id"] for h in H}
    assert all(1 <= indeg[i] <= 3 for i in ids)
    edges = {(h["id"], t) for h in H for t in h["strong_vs"]}
    assert not any((b, a) in edges for a, b in edges)
    same_slot = {h["id"]: h["role_primary"] for h in H}
    for h in H:
        for t in h["strong_vs"]:
            assert same_slot[t] == h["role_primary"] or (h["role_primary"] == "sup" and same_slot[t] == "bot")


def test_identity_rules_for_tags():
    for h in H:
        if h["archetype"] != "gunner" and "scaling" in h["tags"]:
            assert h["power_late"] > h["power_early"], h["id"]          # scaling tag needs a late-leaning curve
        if "poke" in h["tags"]:
            assert h["range"] != "melee", h["id"]                        # poke needs reach


def test_power_curves_are_balanced_across_the_set():
    means = [statistics.mean(h[k] for h in H) for k in ("power_early", "power_mid", "power_late")]
    assert max(means) - min(means) < 3.0, means
    shapes = collections.Counter((h["power_early"] > h["power_late"] + 4, h["power_late"] > h["power_early"] + 4) for h in H)
    assert shapes[(True, False)] >= 6 and shapes[(False, True)] >= 8      # early-heavy and late-heavy heroes both exist


def test_composition_scoring_over_all_lineups_behaves():
    by = {s: [h for h in H if h["role_primary"] == s] for s in SLOTS}
    mods, styles, dmg, needs = [], collections.Counter(), 0, 0
    for combo in itertools.product(*(by[s] for s in SLOTS)):
        m, st, parts = comp_eval(list(combo))
        mods.append(m); styles[st] += 1
        dmg += parts["balance"] < 0; needs += parts["needs"] < 0
    n = len(mods)
    assert n == 8 ** 5
    for st in ("dive", "siege", "protect"):
        assert 0.15 <= styles[st] / n <= 0.27, (st, styles[st] / n)       # no style dominates or is unreachable
    assert 0.30 <= styles["skirmish"] / n <= 0.45
    assert 0.12 <= dmg / n <= 0.28 and 0.08 <= needs / n <= 0.20
    assert sum(m >= CAP - 1e-4 for m in mods) / n <= 0.05                 # the cap is rare
    assert min(mods) <= -0.05                                             # truly bad drafts exist
    assert statistics.median(mods) <= 0.6 * CAP                            # a typical draft is well under the cap
    assert statistics.pstdev(mods) >= 0.035                               # the draft has real spread to play with


def test_every_tag_and_difficulty_is_used():
    tags = collections.Counter(t for h in H for t in h["tags"])
    assert all(tags[t] >= 6 for t in ("engage", "poke", "protect", "pick", "frontline", "waveclear", "scaling"))
    assert tags["splitpush"] >= 4
    assert {h["difficulty"] for h in H} == {1, 2, 3, 4, 5}


# ---------------- players and clubs
def test_league_shape():
    assert len(P) == 140 and len(C) == 10
    fa = [p for p in P if p["club"] is None]
    assert len(fa) == 40 and collections.Counter(p["role_primary"] for p in fa) == {s: 8 for s in SLOTS}
    assert all(len(c["player_ids"]) == 10 for c in C)


def base_rating(p, slot):
    w = GP.SLOT_W[slot]
    return sum(w[i] * p["stats"][s] for i, s in enumerate(GP.STATS[:5]))


def test_club_strength_follows_offset():
    for c in C:
        ps = [PID[i] for i in c["player_ids"]]
        mean_stat = statistics.mean(p["stats"][s] for p in ps for s in GP.STATS)
        assert abs(mean_stat - (50 + 4 * c["strength_offset"])) < 4.0, c["id"]
    assert [c["strength_offset"] for c in C] == sorted(c["strength_offset"] for c in C)


def team_rating(c):
    ps = [PID[i] for i in c["player_ids"]]
    return statistics.mean(max(base_rating(p, s) for p in ps if p["role_primary"] == s) for s in SLOTS)


def test_team_rating_spread_is_wide_enough_to_matter_but_not_absurd():
    r = [team_rating(c) for c in C]
    assert r == sorted(r) or sum(1 for a, b in zip(r, r[1:]) if b < a) <= 2     # roughly ordered by offset
    assert 20 <= max(r) - min(r) <= 40, max(r) - min(r)                         # best vs worst, rating points


def test_role_tilt_makes_primary_slot_the_best_slot():
    gaps = []
    for p in P:
        own = base_rating(p, p["role_primary"])
        others = statistics.mean(base_rating(p, s) for s in SLOTS if s != p["role_primary"])
        gaps.append(own - others)
    assert statistics.mean(gaps) > 0.8


def test_potential_and_ages():
    assert all(17 <= p["age"] <= 32 for p in P)
    young = statistics.mean(sum(p["potential"][s] - p["stats"][s] for s in GP.STATS) / 8 for p in P if p["age"] <= 20)
    old = statistics.mean(sum(p["potential"][s] - p["stats"][s] for s in GP.STATS) / 8 for p in P if p["age"] >= 27)
    assert young > old + 5
    assert collections.Counter(p["personality"] for p in P).most_common()[-1][1] >= 20   # all four personalities appear often


def test_free_agents_are_a_real_market_not_a_gold_mine():
    fa = [p for p in P if p["club"] is None]
    best_fa = max(base_rating(p, p["role_primary"]) for p in fa)
    best_club_player = max(base_rating(p, p["role_primary"]) for p in P if p["club"])
    club_means = [team_rating(c) for c in C]
    assert best_fa < best_club_player                       # the very best are signed
    assert best_fa > statistics.mean(club_means)            # but useful players are available


def test_name_screen_catches_blocked_names():
    block = GP.load_block()
    assert GP.is_blocked("Faker", block) and GP.is_blocked("xFakerx", block) and GP.is_blocked("Dredge", block)
    assert not GP.is_blocked("Ashkai", block)
