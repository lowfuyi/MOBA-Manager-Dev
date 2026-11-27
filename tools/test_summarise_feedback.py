"""Tests for tools/summarise_feedback.py (Founder's queue 2026-11-27, R6) with sample notes in the format of
App.feedback_text and Timings.lines."""
import pathlib, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import summarise_feedback as sf  # noqa: E402

NOTE_WEB = """[27/11/2026, 10:14] Alex Tan: Feedback for Gloamline alpha

What I was doing:
drafting
What happened:
fine
What I expected:

--- details for the developer ---
Gloamline 0.12.2 alpha  build 0.12.2-alpha-web-630545d-20261124-2200
godot 4.3-stable (official)
club=c03 season=1 phase=league round=4 seed=123
pace n=3 total_s=900 watch_s=600 skips=0 fast=1 quick=0
startup=2100 ms  mem=180 MB  text=normal  colours=default
device=Web | ANGLE (Apple, Apple A16 GPU) | screen 390x844 | cpus 6
browser=Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1
draft time s last=84 avg=77 n=3
game start ms last=1450 avg=1320 n=3
arena frame ms: field avg=17.2 worst=58 slow=12 n=2400; action avg=18.0 worst=41 slow=8 n=900
"""

NOTE_APK = """27/11/2026, 11:02 - Bea: Gloamline 0.12.2 alpha  build 0.12.2-alpha-android
godot 4.3-stable (official)
device=Android | SM-A145F | Mali-G52 | screen 720x1600 | cpus 8
draft time s last=120 avg=120 n=1
game start ms last=3900 avg=3900 n=1
arena frame ms: field avg=38.5 worst=210 slow=640 n=1000; all avg=41.0 worst=180 slow=300 n=500
"""


def test_parse_note_fields():
    who, text = sf.split_notes(NOTE_WEB, None)[0]
    assert who == "Alex Tan"
    n = sf.parse_note(text)
    assert n["build"] == "0.12.2-alpha-web-630545d-20261124-2200"
    assert n["version"] == "0.12.2 alpha"
    assert n["device"].startswith("Web | ANGLE")
    assert "Safari" in n["browser"]
    assert (n["draft_last"], n["draft_avg"], n["draft_n"]) == (84, 77, 3)
    assert (n["start_last"], n["start_avg"], n["start_n"]) == (1450, 1320, 3)
    assert n["views"]["field"] == {"avg": 17.2, "worst": 58, "slow": 12, "n": 2400}
    assert set(n["views"]) == {"field", "action"}


def test_split_many_notes_and_whatsapp_names():
    rows = sf.collect([(None, NOTE_WEB + "\n" + NOTE_APK + "\n" + NOTE_WEB)])
    assert [w for w, _ in rows] == ["Alex Tan", "Bea", "Alex Tan"]
    assert rows[1][1]["build"] == "0.12.2-alpha-android"


def test_developer_line_inside_form_note_is_one_note():
    assert len(sf.split_notes(NOTE_WEB, None)) == 1


def test_table_and_summary_lines():
    rows = sf.collect([(None, NOTE_WEB + NOTE_APK + NOTE_WEB)])
    t = sf.table(rows)
    assert "Field avg/worst" in t and "17.2/58" in t and "38.5/210" in t
    lines = sf.summaries(rows)
    assert len(lines) == 2
    assert lines[0].startswith("Alex Tan: 2 notes") and "arena smooth" in lines[0] and "game start about 1.3 s" in lines[0]
    assert lines[1].startswith("Bea: 1 note;") and "arena slow" in lines[1]


def test_folder_names_and_missing_lines(tmp_path):
    (tmp_path / "chris.txt").write_text("Feedback for Gloamline alpha\n--- details for the developer ---\nGloamline 0.12.2 alpha  build x\n")
    rows = sf.collect(sf.read_sources([str(tmp_path)]))
    assert rows[0][0] == "chris"
    n = rows[0][1]
    assert n["views"] == {} and n["draft_avg"] is None
    assert "no match watched" in sf.summaries(rows)[0]
    assert sf.main([str(tmp_path)]) == 0


def test_no_notes(tmp_path, capsys):
    (tmp_path / "empty.txt").write_text("hello\n")
    assert sf.main([str(tmp_path / "empty.txt")]) == 1
