#!/usr/bin/env python3
"""Summarise tester feedback notes (Founder's queue 2026-11-27, R6).

Reads the text testers paste from Settings -> "Copy feedback note" (App.feedback_text: the form text, then the lines of
App.debug_info, including the Timings lines) and prints one table row per note and one summary line per tester.

    python3 tools/summarise_feedback.py notes.txt            # one file, may hold many notes (a WhatsApp export works)
    python3 tools/summarise_feedback.py feedback_folder/     # every .txt file in a folder
    pbpaste | python3 tools/summarise_feedback.py -          # standard input

Who sent a note: the WhatsApp header in front of it ("[27/11/2026, 10:14] Name: ..." or "27/11/2026, 10:14 - Name: ...")
if there is one, else the file name (folder mode), else "tester N". Nothing is sent anywhere; it only reads text.
"""
import argparse, pathlib, re, sys

NOTE_START = re.compile(r"^(?:.*?:\s*)?(Feedback for Gloamline\b.*|Gloamline \d+\.\d+.*\bbuild\b.*)$")
WA_HEADER = re.compile(r"^\[?\d{1,2}/\d{1,2}/\d{2,4},? \d{1,2}:\d{2}(?::\d{2})?(?:\s?[APap][Mm])?\]?(?:\s*-)?\s*([^:]{1,40}):")
VIEWS = ("field", "action", "all")
SMOOTH_MS = 20.0        # average frame time at or under this reads as smooth (50 fps or better)
SLOW_SHARE = 0.05       # more than 5 % of frames slower than 30 fps reads as "some slow frames"


def _num(s, cast=float):
    try:
        return cast(s)
    except (TypeError, ValueError):
        return None


def parse_note(text):
    """One note's text -> dict with the fields we table. Missing lines give None."""
    n = {"version": None, "build": None, "device": None, "browser": None, "draft_last": None, "draft_avg": None,
         "draft_n": None, "start_last": None, "start_avg": None, "start_n": None, "views": {}, "pace_n": None}
    for raw in text.splitlines():
        line = WA_HEADER.sub("", raw.strip()).strip()
        m = re.match(r"^Gloamline (\d+\.\d+\.\d+[^ ]*(?: alpha)?)\s+build (\S+)", line)
        if m:
            n["version"], n["build"] = m.group(1), m.group(2)
            continue
        if line.startswith("device="):
            n["device"] = line[len("device="):].strip()
            continue
        if line.startswith("browser="):
            n["browser"] = line[len("browser="):].strip()
            continue
        m = re.match(r"^draft time s last=(\S+) avg=(\S+) n=(\d+)", line)
        if m:
            n["draft_last"], n["draft_avg"], n["draft_n"] = _num(m.group(1)), _num(m.group(2)), _num(m.group(3), int)
            continue
        m = re.match(r"^game start ms last=(\S+) avg=(\S+) n=(\d+)", line)
        if m:
            n["start_last"], n["start_avg"], n["start_n"] = _num(m.group(1)), _num(m.group(2)), _num(m.group(3), int)
            continue
        if line.startswith("arena frame ms:"):
            for part in line[len("arena frame ms:"):].split(";"):
                m = re.match(r"^\s*(\w+) avg=(\S+) worst=(\S+) slow=(\d+) n=(\d+)", part)
                if m:
                    n["views"][m.group(1)] = {"avg": _num(m.group(2)), "worst": _num(m.group(3)),
                                              "slow": int(m.group(4)), "n": int(m.group(5))}
            continue
        m = re.match(r"^pace n=(\d+)", line)
        if m:
            n["pace_n"] = int(m.group(1))
    return n


def split_notes(text, default_who):
    """Split pasted text into (who, note text) pairs. A note starts at 'Feedback for Gloamline' (the form text) or, when
    only the developer lines were pasted, at the 'Gloamline <version> build <id>' line."""
    notes, cur, who, cur_who = [], [], None, None
    have_form = False
    for line in text.splitlines():
        h = WA_HEADER.match(line)
        if h:
            who = h.group(1).strip()
        m = NOTE_START.match(line.strip())
        starts = False
        if m:
            body = m.group(1)
            if body.startswith("Feedback for Gloamline"):
                starts, have_form = True, True
            elif not have_form:      # a developer block with no form text in front of it
                starts = True
            else:
                have_form = False    # the version line inside a form note: same note
        if starts:
            if cur:
                notes.append((cur_who, "\n".join(cur)))
            cur, cur_who = [], who
        if cur or starts:
            cur.append(line)
    if cur:
        notes.append((cur_who, "\n".join(cur)))
    return [(w or default_who, t) for w, t in notes]


def short_device(dev, browser):
    if not dev:
        return "?"
    parts = [p.strip() for p in dev.split("|")]
    keep = [p for p in parts if not p.startswith("cpus")]
    out = " ".join(keep[:3])[:40].rstrip()
    if browser:
        for name in ("Edg/", "Chrome/", "Firefox/", "Safari/"):
            if name in browser:
                out += " / " + name.rstrip("/").replace("Edg", "Edge")
                break
    return out


def fmt(v, digits=0):
    if v is None:
        return "-"
    return f"{v:.{digits}f}"


def view_cell(n, v):
    x = n["views"].get(v)
    if not x:
        return "-"
    return f"{fmt(x['avg'], 1)}/{fmt(x['worst'])}"


def verdict(views):
    """Plain words for a set of view stats pooled over notes."""
    frames = sum(x["n"] for x in views.values())
    if frames == 0:
        return "no match watched"
    slow = sum(x["slow"] for x in views.values())
    avg = sum(x["avg"] * x["n"] for x in views.values()) / frames
    share = slow / frames
    if avg <= SMOOTH_MS and share <= SLOW_SHARE:
        return f"smooth (avg {avg:.1f} ms, {100 * share:.0f}% slow frames)"
    if avg <= 33.4:
        return f"some slow frames (avg {avg:.1f} ms, {100 * share:.0f}% slow)"
    return f"slow (avg {avg:.1f} ms, {100 * share:.0f}% slow)"


def table(rows):
    head = ["Tester", "Device", "Build", "Draft s last/avg", "Start ms avg", "Field avg/worst", "Action avg/worst",
            "All avg/worst"]
    body = []
    for who, n in rows:
        body.append([who, short_device(n["device"], n["browser"]), n["build"] or "?",
                     f"{fmt(n['draft_last'])}/{fmt(n['draft_avg'])}" if n["draft_avg"] is not None else "-",
                     fmt(n["start_avg"]), view_cell(n, "field"), view_cell(n, "action"), view_cell(n, "all")])
    w = [max(len(str(r[i])) for r in [head] + body) for i in range(len(head))]
    out = [" | ".join(h.ljust(w[i]) for i, h in enumerate(head)), "-+-".join("-" * x for x in w)]
    for r in body:
        out.append(" | ".join(str(c).ljust(w[i]) for i, c in enumerate(r)))
    return "\n".join(out)


def summaries(rows):
    by = {}
    for who, n in rows:
        by.setdefault(who, []).append(n)
    out = []
    for who, ns in by.items():
        builds = sorted({n["build"] for n in ns if n["build"]})
        dev = next((short_device(n["device"], n["browser"]) for n in ns if n["device"]), "?")
        pooled = {}
        for n in ns:
            for v, x in n["views"].items():
                p = pooled.setdefault(v, {"avg": 0.0, "n": 0, "slow": 0, "worst": 0.0})
                tot = p["avg"] * p["n"] + (x["avg"] or 0.0) * x["n"]
                p["n"] += x["n"]
                p["avg"] = tot / p["n"] if p["n"] else 0.0
                p["slow"] += x["slow"]
                p["worst"] = max(p["worst"], x["worst"] or 0.0)
        drafts = [n["draft_avg"] for n in ns if n["draft_avg"] is not None]
        starts = [n["start_avg"] for n in ns if n["start_avg"] is not None]
        bits = [f"{who}: {len(ns)} note{'s' if len(ns) != 1 else ''}", dev, "build " + (", ".join(builds) or "?")]
        if drafts:
            bits.append(f"draft about {sum(drafts) / len(drafts):.0f} s")
        if starts:
            bits.append(f"game start about {sum(starts) / len(starts) / 1000:.1f} s")
        bits.append("arena " + verdict(pooled))
        out.append("; ".join(bits))
    return out


def read_sources(paths):
    """-> list of (default tester name, text)."""
    if not paths or paths == ["-"]:
        return [(None, sys.stdin.read())]
    out = []
    for p in paths:
        pp = pathlib.Path(p)
        if pp.is_dir():
            for f in sorted(pp.glob("*.txt")):
                out.append((f.stem, f.read_text(encoding="utf-8", errors="replace")))
        else:
            out.append((None, pp.read_text(encoding="utf-8", errors="replace")))
    return out


def collect(sources):
    rows = []
    k = 0
    for default_who, text in sources:
        for who, note in split_notes(text, default_who):
            if who is None:
                k += 1
                who = f"tester {k}"
            rows.append((who, parse_note(note)))
    return rows


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("paths", nargs="*", help="files or folders of pasted notes; - or nothing reads standard input")
    a = ap.parse_args(argv)
    rows = collect(read_sources(a.paths))
    if not rows:
        print("No feedback notes found.")
        return 1
    print(table(rows))
    print()
    for line in summaries(rows):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
