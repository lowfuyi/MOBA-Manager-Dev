"""Match Sim v2 data checks (MATCH-SIM-V2-DESIGN sections 3, 4, 12 and 13): kits, items and the IP name screen."""
import json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
D = ROOT / "game/data"
HEROES = {h["id"]: h for h in json.loads((D / "heroes.json").read_text())}
KITS = {k["id"]: k for k in json.loads((D / "kits_v2.json").read_text())["kits"]}
ITEMS_DOC = json.loads((D / "items_v2.json").read_text())
ITEMS = {i["id"]: i for i in ITEMS_DOC["items"]}
HARD_CC = {"stun", "root", "knockup", "silence", "taunt"}
SLOTS = ["a1", "a2", "a3", "ult"]

sys.path.insert(0, str(ROOT / "tools"))
import ip_names  # noqa: E402


def _abil(k):
    return k["abilities"]


def test_every_hero_has_a_kit():
    assert set(KITS) == set(HEROES)


def test_kit_shape():
    for hid, k in KITS.items():
        assert [a["slot"] for a in _abil(k)] == SLOTS, hid
        assert [a["unlock"] for a in _abil(k)] == [1, 1, 3, 6], hid
        assert k["passive"]["slot"] == "passive" and k["passive"]["trigger"], hid
        ult = _abil(k)[3]
        assert ult["cd"] > max(a["cd"] for a in _abil(k)[:3]), hid
        for a in _abil(k) + [k["passive"]]:
            assert a["id"].startswith(hid + "."), a["id"]
            assert 3 <= len(a["name"]) <= 24, a["name"]
            assert a["text"].endswith(".") and len(a["text"]) <= 110, a["text"]
        for a in _abil(k):
            assert a["kind"], a["id"]
            assert a["dtype"] in ("phys", "magic", "true"), a["id"]
            assert 0.0 <= a["dmg"] <= 260 and 0.0 <= a["ratio"] <= 1.6, a["id"]
            assert 0.0 < a["cd"] <= 80 and a["cd_lvl"] <= 0, a["id"]
            assert 0.5 <= a["hit"] <= 1.0, a["id"]
            if "damage" in a["kind"]:
                assert a["dmg"] > 0, a["id"]
            if a["cc"]:
                assert "cc" in a["kind"] and a["cc_s"] > 0, a["id"]
            if "shield" in a["kind"]:
                assert a["shield"] > 0, a["id"]
            if "heal" in a["kind"]:
                assert a["heal"] > 0, a["id"]
            if "mobility" in a["kind"]:
                assert a["dash_u"] > 0, a["id"]
        s = k["stats"]
        assert 500 <= s["hp"] <= 760 and 0.009 <= s["range_u"] <= 0.04 and 0.025 <= s["move_u_s"] <= 0.032, hid


def test_names_unique():
    names = [a["name"].lower() for k in KITS.values() for a in _abil(k) + [k["passive"]]]
    names += [i["name"].lower() for i in ITEMS.values()]
    assert len(names) == len(set(names))


def _has(k, pred):
    return any(pred(a) for a in _abil(k))


def test_tags_are_visible_in_the_kit():
    """GDD 5.1 tags must show in the kit (design 3.2)."""
    bad = []
    for hid, h in HEROES.items():
        k = KITS[hid]
        p = k["passive"]
        for tag in h["tags"]:
            if tag == "frontline":
                ok = h["archetype"] in ("bruiser", "bulwark") and k["stats"]["hp"] >= 640
            elif tag == "engage":
                ok = _has(k, lambda a: "mobility" in a["kind"] and a["cc"] in HARD_CC) or _has(k, lambda a: a["cc"] in ("taunt",))
            elif tag == "pick":
                ok = _has(k, lambda a: a["cc"] in HARD_CC and a["target"] in ("enemy", "line")) or _has(k, lambda a: "execute" in a["kind"]) or p["cc"] in HARD_CC
            elif tag == "waveclear":
                ok = _has(k, lambda a: "wave" in a["kind"])
            elif tag == "poke":
                ok = _has(k, lambda a: "damage" in a["kind"] and a["range_u"] >= 0.045)
            elif tag == "protect":
                ok = _has(k, lambda a: ("shield" in a["kind"] or "heal" in a["kind"]) and a["target"] in ("ally", "area")) or p["trigger"] == "aura"
            elif tag == "scaling":
                ok = h["power_late"] >= h["power_early"] or p["trigger"] in ("stacks_per_min", "on_kill") or p["stat"] in ("aspd", "crit", "ap", "atk")
            elif tag == "splitpush":
                ok = p["trigger"] in ("vs_structure", "isolated") or _has(k, lambda a: "mobility" in a["kind"])
            else:
                raise AssertionError(f"unknown tag {tag}")
            if not ok:
                bad.append(f"{hid}: tag {tag}")
    assert not bad, f"tags not visible in the kit: {bad}"


def test_items_legal():
    eff = set(ITEMS_DOC["effects"])
    stats = set(ITEMS_DOC["stats"])
    for iid, it in ITEMS.items():
        assert it["effect"] in eff and set(it["stats"]) <= stats, iid
        for c in it["components"]:
            assert c in ITEMS and ITEMS[c]["tier"] in ("component", "boots_base"), (iid, c)
        if it["tier"] in ("finished", "boots"):
            assert it["cost"] > sum(ITEMS[c]["cost"] for c in it["components"]), iid
        if it["tier"] == "finished":
            assert 1800 <= it["cost"] <= 3300 and it["text"], iid
        v = sum(ITEMS_DOC["stat_gold"][s] * x for s, x in it["stats"].items()) / it["cost"]
        assert 0.70 <= v <= 1.35, (iid, round(v, 2))
    fin = [i for i in ITEMS.values() if i["tier"] == "finished"]
    for cls in ("carry", "fighter", "mage", "tank", "support"):
        assert len([i for i in fin if i["class"] == cls]) >= 4, cls
    assert len([i for i in ITEMS.values() if i["tier"] == "boots"]) >= 4


def test_coach_rules_cover_archetypes():
    rules = ITEMS_DOC["coach_rules"]
    for h in HEROES.values():
        assert h["archetype"] in rules["class_by_archetype"] and rules["boots_by_archetype"][h["archetype"]] in ITEMS


def test_ip_name_screen_clean():
    assert ip_names.main() == 0


def test_ip_screen_catches_known_names():
    deny = ip_names.deny_list()
    assert ip_names.screen("Infinity Edge", deny)
    assert ip_names.screen("Blade of the Ruined Kings", deny)
    assert ip_names.screen("Rolling Boulder", deny)
    assert ip_names.screen("Monolith Fall", deny)
    assert not ip_names.screen("Tumbling Slab", deny)
