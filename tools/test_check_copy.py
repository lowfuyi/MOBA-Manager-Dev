"""Tests for tools/check_copy.py. Run: python3 -m pytest tools/test_check_copy.py -q"""
import json, pathlib, sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import check_copy as C

ROOT = pathlib.Path(__file__).resolve().parent.parent
PATCH_KEYS = 540        # keys in docs/design/copy/en_0_7.json; update here if the patch file is ever edited


def errs(subject, context=None):
    return C.check(subject, context)[0]


def has(errors, *needles):
    return any(all(n in e for n in needles) for e in errors)


# ------------------------------------------------------------------ the real files
def test_patch_file_is_clean():
    patch = C.load_unique(C.PATCH)
    assert len(patch) == PATCH_KEYS
    e, w = C.check(patch, C.load_unique(C.EN))
    assert e == [] and w == []


def test_patch_merged_into_en_json_is_clean():
    # what the game will hold after the merge: only known-open warnings are allowed, no errors
    merged = {**C.load_unique(C.EN), **C.load_unique(C.PATCH)}
    e, w = C.check(merged, {})
    assert e == []
    assert all(any(k in line for k in C.KNOWN_OPEN) for line in w)


def test_every_known_open_key_is_a_real_key_today():
    # a stale entry hides nothing but clutters: when a string is fixed, delete its entry
    en = C.load_unique(C.EN)
    merged = {**en, **C.load_unique(C.PATCH)}
    assert set(C.KNOWN_OPEN) <= set(merged)


def test_cli_exit_codes(tmp_path, capsys):
    assert C.main([]) == 0
    bad = tmp_path / "bad.json"
    bad.write_text(json.dumps({"tut.x": "Tap the green button."}))
    assert C.main([str(bad), "--context", str(tmp_path / "bad.json")]) == 1
    assert "colour word 'green'" in capsys.readouterr().out
    assert C.main([str(C.PATCH), "--expect-keys", "1"]) == 1


def test_duplicate_keys_are_an_error(tmp_path):
    dup = tmp_path / "dup.json"
    dup.write_text('{"a.b": "x", "a.b": "y"}')
    with pytest.raises(ValueError):
        C.load_unique(dup)
    assert C.main([str(dup), "--context", str(dup)]) == 1


# ------------------------------------------------------------------ word limits
def test_coach_text_limit_is_25_words():
    ok = " ".join(["word"] * 25)
    assert errs({"tut.a": ok}) == []
    assert has(errs({"tut.a": ok + " more"}), "tut.a", "26 words")


def test_club_placeholder_counts_as_two_words():
    text = "{club} " + " ".join(["word"] * 24)        # 1 token + 1 extra + 24 = 26
    assert has(errs({"tut.a": text}), "26 words")


@pytest.mark.parametrize("key,words,limit", [
    ("les.l1.open", 25, 25), ("gl.rating.def", 22, 22), ("help.home.see", 20, 20),
    ("help.home.do", 20, 20), ("help.home.know", 20, 20), ("gp.switch.short.vs_dive", 4, 4)])
def test_limits_by_key_class(key, words, limit):
    ctx = {"gl.rating.name": "R", "gl.rating.where": "home", "help.home.title": "H"}
    at = " ".join(["word"] * limit)
    over = " ".join(["word"] * (limit + 1))
    assert errs({key: at}, ctx) == []
    assert has(errs({key: over}, ctx), key, f"{limit + 1} words")


def test_track_end_label_limits():
    assert errs({"gp.end.t.pos": "Play for late"}) == []
    assert has(errs({"gp.end.t.pos": "Play now for the late game"}), "words")
    assert has(errs({"gp.end.t.pos": "Extraordinarily"}), "characters")


def test_other_keys_have_no_word_limit():
    assert errs({"about.included.b": " ".join(["word"] * 80)}) == []


# ------------------------------------------------------------------ colour words
@pytest.mark.parametrize("text", ["Tap the green button.", "Greener line is better.", "Red rows are weak.",
                                  "A blue badge", "grey means weak", "Orange ones"])
def test_colour_words_flagged(text):
    assert has(errs({"tut.a": text}), "colour word")


def test_colour_words_not_flagged_inside_other_words():
    assert errs({"tut.a": "Reduce fatigue, a bored player, an infrared sensor, a redo?"}) == []


def test_side_names_allowed_only_on_side_keys_and_only_blue_red():
    assert errs({"draft.side.blue": "Blue", "draft.side.red": "Red", "hub.side.blue": "Blue", "hub.side.red": "Red"}) == []
    assert has(errs({"draft.side.blue": "Green"}), "colour word")
    assert has(errs({"draft.side.blue": "Blue side is strong"}) + errs({"tut.side": "You are Blue"}), "colour word")


def test_colour_blind_setting_strings_may_name_colours():
    assert errs({"settings.colorblind": "Colour-blind colours", "settings.colorblind_hint": "Swaps green and red for blue and orange."}) == []


def test_chem_hint_is_a_warning_not_an_error():
    e, w = C.check({"chem.pentagon_hint": "Greener line: better understanding"})
    assert e == [] and has(w, "chem.pentagon_hint", "known")


# ------------------------------------------------------------------ rename: values only
@pytest.mark.parametrize("text,needle", [
    ("Let the advisor finish the draft", "advisor"),
    ("Your assistant picks", "assistant"),
    ("You are the owner of the club", "owner"),
    ("If the timer ends the coach chooses for you", "lower-case coach"),
    ("You are the Coach", "calls the player a coach"),
    ("The AI helper picks", "AI"),
])
def test_rename_words_flagged(text, needle):
    assert has(errs({"draft.x": text}), needle)


def test_correct_names_are_fine():
    assert errs({"draft.x": "Your Coach helps, but you decide. You are the Manager.",
                 "gp.coach": "Coach", "train.auto_btn": "Coach's choice"}) == []


def test_key_names_and_id_lists_are_never_scanned():
    # key names contain coach / advisor-like ids, and the glossary id lists hold the id "coach" as data
    ctx = {"gl.coach.name": "Coach", "gl.coach.def": "Your helper.", "gl.coach.where": "draft",
           "help.draft.title": "Draft"}
    subject = {"tut.coach_suggest": "Tap Coach.", "help.draft.terms": "coach", "gl.coach.where": "draft"}
    assert errs(subject, ctx) == []


def test_gendered_pronouns_flagged_neutral_ones_not():
    assert has(errs({"draft.x": "Rest him if he is tired"}), "pronoun")
    assert has(errs({"draft.x": "Her form is up"}), "pronoun")
    assert errs({"draft.x": "Rest them if they are tired, and check their form. The player is here."}) == []


# ------------------------------------------------------------------ labels
def test_tapped_labels_must_exist():
    ctx = {"pre.start_draft": "Start draft", "x.ban": "Ban"}
    assert errs({"tut.a": "Next is the draft. Tap Start draft."}, ctx) == []
    assert errs({"tut.b": "Tap any hero, then Ban, or tap Ban."}, ctx) == []
    assert has(errs({"tut.c": "Tap Launch rocket."}, ctx), "label 'Launch rocket'")


def test_quoted_labels_must_exist():
    ctx = {"a": "Needs your attention"}
    assert errs({"help.home.know": '"Needs your attention" lists things.'}, ctx) == []
    assert has(errs({"help.home.know": '"Needs nothing at all" lists things.'}, ctx), "label")


def test_label_allow_list(monkeypatch):
    monkeypatch.setattr(C, "LABEL_ALLOW", {"drawn by code"})
    assert errs({"tut.a": "Tap Drawn by code."}) == []


# ------------------------------------------------------------------ ids and placeholders
def test_glossary_ids_in_help_sheets_must_exist():
    ctx = {"help.home.title": "Home", "gl.fit.name": "Fit", "gl.fit.def": "d", "gl.fit.where": "home"}
    assert errs({"help.home.terms": "fit"}, ctx) == []
    assert has(errs({"help.home.terms": "fit, nothing_here"}, ctx), "nothing_here")


def test_glossary_where_must_name_a_help_sheet():
    assert has(errs({"gl.fit.name": "Fit", "gl.fit.def": "d", "gl.fit.where": "nowhere"}), "not a help sheet")


def test_half_written_term_is_an_error():
    assert has(errs({"gl.fit.name": "Fit", "gl.fit.where": "x"}, {"help.x.title": "X"}), "gl.fit.def", "missing")


def test_placeholders_must_not_change_on_replaced_keys():
    ctx = {"draft.recommended": "Take advisor's choice: {hero}"}
    assert errs({"draft.recommended": "Take Coach's choice: {hero}"}, ctx) == []
    assert has(errs({"draft.recommended": "Take Coach's choice"}, ctx), "placeholders changed")


def test_non_ascii_flagged():
    assert has(errs({"tut.a": "Tap ✓ now"}), "non-ASCII")
