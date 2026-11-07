import json, math, pathlib, statistics, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import pcg32 as P
import gen_golden_rng as G

ROOT = pathlib.Path(__file__).resolve().parent.parent

def test_known_reference_vector():
    # Published output of the reference PCG32 demo for seed 42, sequence 54.
    g = P.Pcg32(42, 54)
    assert [g.next_u32() for _ in range(6)] == [0xA15C02B7, 0x7B47F409, 0xBA1D3330, 0x83D2F293, 0xBFA4784B, 0xCBED606E]

def test_deterministic_and_seed_sensitive():
    a = [P.Pcg32(1, 1).next_u32() for _ in range(3)]
    assert a == [P.Pcg32(1, 1).next_u32() for _ in range(3)]
    assert P.Pcg32(1, 1).next_u32() != P.Pcg32(2, 1).next_u32()

def test_float_range_and_resolution():
    g = P.Pcg32(5, 9)
    for _ in range(10000):
        x = g.next_float()
        assert 0.0 <= x < 1.0
        assert (x * 16777216.0).is_integer()

def test_normal_moments():
    g = P.Pcg32(99, 3)
    xs = [g.next_normal() for _ in range(40000)]
    assert abs(statistics.fmean(xs)) < 0.02
    assert abs(statistics.pstdev(xs) - 1.0) < 0.02
    assert all(math.isfinite(x) for x in xs)

def test_normal_consumes_two_draws():
    a, b = P.Pcg32(3, 4), P.Pcg32(3, 4)
    a.next_normal()
    b.next_u32(); b.next_u32()
    assert a.next_u32() == b.next_u32()

def test_substreams_are_independent_and_repeatable():
    ms = P.match_seed(1, "m1")
    s1 = [P.contest_stream(ms, "lane_top").next_u32() for _ in range(1)]
    s2 = [P.contest_stream(ms, "lane_mid").next_u32() for _ in range(1)]
    assert s1 != s2
    again = P.contest_stream(ms, "lane_top")
    assert again.next_u32() == s1[0]
    assert P.match_seed(1, "m1") != P.match_seed(1, "m2")
    assert P.match_seed(1, "m1") != P.match_seed(2, "m1")

def test_golden_file_is_current():
    stored = json.loads((ROOT / "game/tests/golden/rng_vectors.json").read_text())
    assert stored == G.build(), "run: python3 tools/gen_golden_rng.py"
