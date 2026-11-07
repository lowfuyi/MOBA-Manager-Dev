import json, pathlib, sys, copy
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import validate_data as V
import check_strings as C

ROOT = pathlib.Path(__file__).resolve().parent.parent
HS = V.load(ROOT / "game/data/schema/hero.schema.json")
PS = V.load(ROOT / "game/data/schema/player.schema.json")

def test_sample_data_is_valid():
    assert V.validate_dir(ROOT / "game/data") == []

def test_hero_power_sum_rule_catches_errors():
    h = copy.deepcopy(V.load(ROOT / "game/data/samples/heroes.sample.json"))
    h[0]["power_late"] += 3
    assert any("power sum" in e for e in V.check_heroes(h, HS))

def test_hero_counter_must_exist_and_not_be_self():
    h = copy.deepcopy(V.load(ROOT / "game/data/samples/heroes.sample.json"))
    h[0]["strong_vs"] = ["nobody"]
    assert any("unknown id" in e for e in V.check_heroes(h, HS))
    h[0]["strong_vs"] = [h[0]["id"]]
    assert any("counters itself" in e for e in V.check_heroes(h, HS))

def test_player_potential_must_not_be_below_stat():
    p = copy.deepcopy(V.load(ROOT / "game/data/samples/players.sample.json"))
    p[0]["potential"]["mec"] = p[0]["stats"]["mec"] - 1
    assert any("potential must be" in e for e in V.check_players(p, PS))
    p[0]["potential"]["mec"] = 100
    assert any("potential must be" in e for e in V.check_players(p, PS))

def test_player_needs_all_eight_stats():
    p = copy.deepcopy(V.load(ROOT / "game/data/samples/players.sample.json"))
    del p[0]["stats"]["clu"]
    assert V.check_players(p, PS)

def test_strings_lint_passes_and_has_every_stat_and_role():
    errs, _ = C.check()
    assert errs == []
    en = json.loads((ROOT / "game/i18n/en.json").read_text())
    for k in ["mec", "sen", "lan", "tft", "mac", "com", "con", "clu"]:
        assert f"stat.{k}" in en
    for k in ["top", "jg", "mid", "bot", "sup"]:
        assert f"role.{k}" in en
    for k in ["professional", "balanced", "casual", "temperamental"]:
        assert f"personality.{k}" in en

def test_gdscript_validators_match_python_constants():
    gd = (ROOT / "game/src/core/data_loader.gd").read_text()
    for token in ['"mec", "sen", "lan", "tft", "mac", "com", "con", "clu"', '"top", "jg", "mid", "bot", "sup"',
                  '"professional", "balanced", "casual", "temperamental"', "144 + 3 * d"]:
        assert token in gd
