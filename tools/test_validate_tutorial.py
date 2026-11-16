"""Negative controls for the tutorial data checks in validate_data.py (build plan 0.7 I-11).
The real file passes; each broken copy must be caught by the rule it breaks."""
import copy, json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import validate_data as V

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOC = json.loads((ROOT / "game/data/tutorial_v1.json").read_text())
SCHEMA = json.loads((ROOT / "game/data/schema/tutorial.schema.json").read_text())
STR = json.loads((ROOT / "game/i18n/en.json").read_text())


def errs(mutate):
    d = copy.deepcopy(DOC)
    mutate(d)
    return V.check_tutorial(d, SCHEMA, STR)


def step(d, sid): return next(s for s in d["steps"] if s["id"] == sid)


def test_real_file_is_clean():
    assert V.check_tutorial(DOC, SCHEMA, STR) == []
    assert len(DOC["steps"]) == 27


def test_missing_text_key():
    assert any("not in en.json" in e for e in errs(lambda d: step(d, "tabs").update(key="tut.no_such_key")))
    assert any("not in en.json" in e for e in errs(lambda d: step(d, "ban")["stage_b"].update(key="tut.ban.nope")))
    assert any("not in en.json" in e for e in errs(lambda d: step(d, "result").update(key_loss="tut.result.nope")))


def test_key_check_is_skipped_without_strings():
    d = copy.deepcopy(DOC); step(d, "tabs")["key"] = "tut.no_such_key"
    assert V.check_tutorial(d, SCHEMA, None) == []


def test_tag_not_in_section_8():
    assert any("TUTORIAL.md 8" in e for e in errs(lambda d: step(d, "tabs").update(target=["made.up"])))
    assert any("TUTORIAL.md 8" in e for e in errs(lambda d: step(d, "ban")["stage_b"].update(target=["draft.nowhere"])))


def test_illegal_event():
    assert any("7.5" in e for e in errs(lambda d: step(d, "ban").update(done_on=["draft:nothing"])))
    assert any("7.5" in e for e in errs(lambda d: step(d, "role").update(skip_if="event_seen:draft:nothing")))
    assert any("7.5" in e for e in errs(lambda d: step(d, "tab_squad").update(done_on=["tap:made.up"])))


def test_tap_event_must_name_a_highlighted_target():
    assert any("does not highlight" in e for e in errs(lambda d: step(d, "tab_squad").update(done_on=["tap:tab.plan"])))


def test_step_ids_unique_and_ordered():
    def dup(d): d["steps"][3]["id"] = "tabs"
    assert any("duplicate" in e for e in errs(dup))
    def swap(d): d["steps"][1], d["steps"][2] = d["steps"][2], d["steps"][1]
    assert any("in order" in e for e in errs(swap))


def test_not_27_steps():
    assert errs(lambda d: d["steps"].pop())
    assert errs(lambda d: d["steps"].append(copy.deepcopy(d["steps"][0])))


def test_chapter_and_resume():
    assert any("chapter" in e for e in errs(lambda d: step(d, "ban").update(chapter=5)))
    assert any("resume step" in e for e in errs(lambda d: d["chapters"][2].update(resume="gone")))
    assert errs(lambda d: d["chapters"].pop())


def test_skip_and_shortcut_consistency():
    assert any("Skip button" in e for e in errs(lambda d: step(d, "finish").update(buttons=["go_home", "skip"])))
    assert any("shortcut" in e for e in errs(lambda d: step(d, "coach_rest").update(buttons=["skip"])))
    assert any("hold_armed" in e for e in errs(lambda d: step(d, "tabs").update(hold_armed=True)))


def test_kind_counts_and_modal_target():
    assert any("kinds" in e for e in errs(lambda d: step(d, "tabs").update(kind="tap")))
    assert any("modal" in e for e in errs(lambda d: step(d, "welcome").update(target=["tabbar"])))
    assert any("needs a target" in e for e in errs(lambda d: step(d, "tabs").update(target=[])))


def test_unknown_field_is_a_schema_error():
    assert errs(lambda d: step(d, "tabs").update(colour="red"))
