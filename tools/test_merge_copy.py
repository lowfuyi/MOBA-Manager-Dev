"""Tests for tools/merge_copy.py (add mode, hold list, allow-list, update mode).
Run: python3 -m pytest tools/test_merge_copy.py -q
Each refusal test is a negative control: the same call with the fault removed must succeed, and a refused call must
leave every file byte for byte as it was."""
import json, pathlib, sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import merge_copy as M
import check_copy as C

ROOT = pathlib.Path(__file__).resolve().parent.parent
EN0 = {"a.one": "One", "a.two": "Two {n}", "b.three": "Three", "c.locked": "Held old", "d.free": "Not owned"}


def setup(tmp_path, en=None, owned=("a.one", "a.two", "b.three", "c.locked"), hold=None):
    d = tmp_path
    (d / "en.json").write_bytes(M.canonical(en or EN0).encode())
    (d / "owned.txt").write_text("# header\n" + "".join(k + "\n" for k in owned))
    (d / "hold.json").write_text(json.dumps(hold if hold is not None else {"c.locked": {"release_in": "later"}}))
    return d


def files(d):
    return {p.name: p.read_bytes() for p in d.iterdir() if p.name in ("en.json", "owned.txt", "hold.json")}


def run(d, upd=None, *extra, mode="update", patch=None):
    argv = ["--en", str(d / "en.json"), "--owned", str(d / "owned.txt"), "--hold", str(d / "hold.json")]
    if mode == "update":
        (d / "upd.json").write_text(json.dumps(upd))
        argv += ["--update", str(d / "upd.json")]
    else:
        (d / "patch.json").write_text(json.dumps(patch))
        argv += ["--patch", str(d / "patch.json")]
    return M.main(argv + list(extra))


def refused(d, upd, *extra, **kw):
    before = files(d)
    rc = run(d, upd, "--write", *extra, **kw)
    assert rc == 1
    assert files(d) == before, "a refused call must write nothing"


# ------------------------------------------------------------------ update mode: the good path
def test_update_changes_only_the_value(tmp_path):
    d = setup(tmp_path)
    before = (d / "en.json").read_text()
    assert run(d, {"a.one": "Uno", "a.two": "Two {n}"}, "--write", "--expect-changed", "1") == 0
    after = (d / "en.json").read_text()
    b, a = before.splitlines(), after.splitlines()
    assert len(a) == len(b)
    assert [i for i, (x, y) in enumerate(zip(b, a)) if x != y] == [1]      # one line differs
    assert json.loads(after) == {**EN0, "a.one": "Uno"}
    assert list(json.loads(after)) == list(EN0)                            # key order kept
    assert after.endswith("\n") and "\r" not in after


def test_dry_run_writes_nothing_and_prints_table(tmp_path, capsys):
    d = setup(tmp_path)
    before = files(d)
    assert run(d, {"a.one": "Uno"}) == 0
    out = capsys.readouterr().out
    assert "CHANGED a.one" in out and "'One'" in out and "'Uno'" in out and "dry run" in out
    assert files(d) == before


def test_placeholder_change_allowed_only_with_flag(tmp_path):
    d = setup(tmp_path)
    refused(d, {"a.two": "Two {m}"})
    assert run(d, {"a.two": "Two {m}"}, "--write", "--allow-placeholder-change") == 0
    assert json.loads((d / "en.json").read_text())["a.two"] == "Two {m}"


# ------------------------------------------------------------------ update mode: refusals (whole file, nothing written)
def test_refuses_key_not_on_allow_list(tmp_path):
    d = setup(tmp_path)
    refused(d, {"d.free": "Changed"})
    assert run(d, {"d.free": "Changed"}, "--write", "--owned", str(d / "owned.txt")) == 1
    (d / "owned.txt").write_text("d.free\n")                    # control: once owned, the same edit passes
    assert run(d, {"d.free": "Changed"}, "--write") == 0


def test_one_bad_key_refuses_the_whole_file(tmp_path):
    d = setup(tmp_path)
    refused(d, {"a.one": "Uno", "d.free": "Changed"})           # a.one alone would pass


def test_refuses_new_key_even_if_owned(tmp_path):
    d = setup(tmp_path, owned=("a.one", "z.new"))
    refused(d, {"z.new": "Brand new"})


def test_refuses_held_key(tmp_path):
    d = setup(tmp_path)
    refused(d, {"c.locked": "Released too early"})
    (d / "hold.json").write_text("{}")                          # control: not held, passes
    assert run(d, {"c.locked": "Released"}, "--write") == 0


def test_refuses_non_ascii_and_non_string(tmp_path):
    d = setup(tmp_path)
    refused(d, {"a.one": "Café"})
    refused(d, {"a.one": 5})
    assert run(d, {"a.one": "Cafe"}, "--write") == 0


def test_refuses_duplicate_key_in_update_file(tmp_path):
    d = setup(tmp_path)
    (d / "upd.json").write_text('{"a.one": "x", "a.one": "y"}')
    before = files(d)
    assert M.main(["--en", str(d / "en.json"), "--owned", str(d / "owned.txt"), "--hold", str(d / "hold.json"),
                   "--update", str(d / "upd.json"), "--write"]) == 1
    assert files(d) == before


def test_refuses_when_nothing_changes_and_when_expectation_fails(tmp_path):
    d = setup(tmp_path)
    refused(d, {"a.one": "One"})
    refused(d, {"a.one": "Uno"}, "--expect-changed", "2")


def test_refuses_en_json_not_in_canonical_format(tmp_path):
    d = setup(tmp_path)
    (d / "en.json").write_text(json.dumps(EN0, indent=4) + "\n")         # different indentation
    refused(d, {"a.one": "Uno"})
    (d / "en.json").write_bytes(M.canonical(EN0).replace("\n", "\r\n").encode())   # CRLF
    refused(d, {"a.one": "Uno"})


def test_copy_check_error_stops_the_write(tmp_path, capsys):
    d = setup(tmp_path, en={"tut.x": "Tap the button.", "a.one": "One"}, owned=("tut.x", "a.one"), hold={})
    refused(d, {"tut.x": "Tap the green button."})              # colour word: check_copy error
    assert "colour word" in capsys.readouterr().out
    refused(d, {"a.one": "Ask her"})                            # gendered pronoun
    assert run(d, {"tut.x": "Tap the big button."}, "--write") == 0     # control


def test_never_deletes_keys(tmp_path):
    d = setup(tmp_path)
    assert run(d, {"a.one": "Uno"}, "--write") == 0
    assert set(json.loads((d / "en.json").read_text())) == set(EN0)
    with pytest.raises(ValueError):
        M.update(EN0, {}, ["a.one"])                            # an empty file cannot delete or do anything


# ------------------------------------------------------------------ add mode and the allow-list
def test_add_mode_writes_new_keys_into_owned_file(tmp_path):
    d = setup(tmp_path)
    patch = {"a.one": "Uno", "n.new1": "New 1", "n.new2": "New 2", "c.locked": "Released text"}
    assert run(d, mode="add", patch=patch) == 0                  # dry run
    assert "n.new1" not in (d / "owned.txt").read_text()
    assert run(d, None, "--write", mode="add", patch=patch, ) == 0
    en = json.loads((d / "en.json").read_text())
    assert en["n.new1"] == "New 1" and en["a.one"] == "Uno"
    assert en["c.locked"] == "Held old"                          # held: old text kept
    owned = M.read_owned(d / "owned.txt")
    assert owned[-2:] == ["n.new1", "n.new2"] and "c.locked" in owned
    assert owned.count("a.one") == 1                             # no duplicate lines
    assert (d / "owned.txt").read_text().startswith("# header\n")    # comments kept


def test_add_mode_refuses_check_error_and_writes_neither_file(tmp_path):
    d = setup(tmp_path)
    before = files(d)
    assert run(d, None, "--write", mode="add", patch={"n.bad": "Tap the red button."}) == 1
    assert files(d) == before
    assert run(d, None, "--write", mode="add", patch={"n.bad": "Tap the big button."}) == 0     # control


def test_add_mode_refuses_placeholder_change_and_non_ascii_and_already_merged(tmp_path):
    d = setup(tmp_path)
    before = files(d)
    for patch in ({"a.two": "Two {m}"}, {"n.x": "Café"}, {"a.one": "One"}):
        assert run(d, None, "--write", mode="add", patch=patch) == 1
        assert files(d) == before


def test_hold_key_unknown_everywhere_is_an_error_but_other_patch_hold_is_fine(tmp_path):
    d = setup(tmp_path, hold={"c.locked": {}, "x.typo": {}})
    before = files(d)
    assert run(d, None, "--write", mode="add", patch={"n.new": "New"}) == 1      # x.typo is nowhere
    assert files(d) == before
    (d / "hold.json").write_text(json.dumps({"c.locked": {}}))
    assert run(d, None, "--write", mode="add", patch={"n.new": "New"}) == 0      # c.locked is in en, not in this patch


def test_seed_owned(tmp_path):
    d = setup(tmp_path, owned=())
    (d / "patch.json").write_text(json.dumps({"a.one": "One", "c.locked": "x", "n.not_in_en": "y"}))
    argv = ["--en", str(d / "en.json"), "--owned", str(d / "owned.txt"), "--hold", str(d / "hold.json"),
            "--patch", str(d / "patch.json"), "--seed-owned"]
    assert M.main(argv) == 0 and M.read_owned(d / "owned.txt") == []             # dry run
    assert M.main(argv + ["--write"]) == 0
    assert M.read_owned(d / "owned.txt") == ["a.one"]            # held and not-in-en keys are not owned


# ------------------------------------------------------------------ the check_strings step
def test_check_strings_runs_on_the_real_table_and_catches_a_removed_key():
    en = M.load_unique(M.DEFAULT_EN)
    errs, _, notes = M.run_checks(en, M.DEFAULT_EN)
    assert errs == [] and "check_strings run on a scratch copy" in notes
    broken = {k: v for k, v in en.items() if k != "chem.pentagon_hint"}      # used literally by screen_chemistry.gd
    errs, _, _ = M.run_checks(broken, M.DEFAULT_EN)
    assert any(e.startswith("check_strings:") and "chem.pentagon_hint" in e for e in errs)


# ------------------------------------------------------------------ the real files
def test_real_allow_list_shape():
    owned = M.read_owned(M.DEFAULT_OWNED)
    assert len(owned) == len(set(owned))
    en = M.load_unique(M.DEFAULT_EN)
    assert set(owned) <= set(en)
    patch = M.load_unique(ROOT / "docs/design/copy/en_0_7.json")
    hold = M.load_unique(ROOT / "docs/design/copy/hold_0_7.json")
    older = ["role.short.jg", "role.short.sup", "chem.pentagon_hint"] + [
        k for k in C.KNOWN_OPEN if k not in ("chem.pentagon_hint", "tip.hub", "draft.meta_hint")]
    assert len(older) == 15 and set(older) <= set(owned)
    assert {k for k in patch if k not in hold} <= set(owned)     # the keys written by the I-00 merge
    assert not (set(hold) - {"chem.pentagon_hint"}) & set(owned)  # held patch keys are not owned yet
    for k in ("player.tab.overview", "player.tab.stats", "player.tab.career"):
        assert k in owned


def test_real_en_json_is_canonical_and_patch2_applied():
    raw = M.DEFAULT_EN.read_bytes().decode()
    assert M.canonical(M.load_unique(M.DEFAULT_EN)) == raw
    en = M.load_unique(M.DEFAULT_EN)
    assert (en["role.short.jg"], en["role.short.sup"]) == ("Jungle", "Support")
    assert en["player.tab.overview"] == "Overview" and en["player.tab.stats"] == "Stats" and en["player.tab.career"] == "Career"
    assert "dashed" not in en["chem.pentagon_hint"].lower()       # held: old text kept
    hold = M.load_unique(ROOT / "docs/design/copy/hold_0_7.json")
    assert hold["chem.pentagon_hint"]["release_in"] == "Chemistry line styles built (UI pass)"


def test_real_update_dry_run_does_not_touch_files(tmp_path):
    before = (M.DEFAULT_EN.read_bytes(), M.DEFAULT_OWNED.read_bytes())
    upd = tmp_path / "u.json"
    upd.write_text(json.dumps({"role.short.sup": "Supp"}))
    assert M.main(["--update", str(upd)]) == 0
    assert (M.DEFAULT_EN.read_bytes(), M.DEFAULT_OWNED.read_bytes()) == before
    upd.write_text(json.dumps({"draft.meta_hint": "Changed"}))            # held and not owned
    assert M.main(["--update", str(upd), "--write"]) == 1
    assert M.DEFAULT_EN.read_bytes() == before[0]


def test_known_open_lets_held_draft_meta_hint_pass_but_only_as_warning(monkeypatch):
    en = C.load_unique(C.EN)
    assert C.main([str(C.EN)]) == 0
    e, w = C.check(en, {})
    assert e == [] and any("draft.meta_hint" in x for x in w)
    monkeypatch.setattr(C, "KNOWN_OPEN", {k: v for k, v in C.KNOWN_OPEN.items() if k != "draft.meta_hint"})
    e, _ = C.check(en, {})                                         # negative control: without the entry it is an error
    assert any("draft.meta_hint" in x for x in e)
