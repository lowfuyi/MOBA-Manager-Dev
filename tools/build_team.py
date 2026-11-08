#!/usr/bin/env python3
"""Generate .claude/agents/*.md and company/TEAM.md from tools/team_roster.py."""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from team_roster import ROSTER  # noqa: E402

TOOLS = {
    "code": "Read, Write, Edit, Bash, Grep, Glob",
    "design": "Read, Write, Edit, Bash, Grep, Glob, WebSearch, WebFetch",
    "art": "Read, Write, Edit, Bash, Grep, Glob",
    "review": "Read, Write, Edit, Bash, Grep, Glob",
    "manage": "Read, Write, Edit, Bash, Grep, Glob",
}

NAMES = {"founder": "Founder (Fuyi, CEO)"}
for r in ROSTER:
    NAMES[r["id"]] = r["title"]

ENGINEERING_NOTES = """
## Engineering notes (code roles)
- Godot 4.3, GDScript, game in `game/`. Headless logic tests: `godot --headless --script res://tests/run_tests.gd` (no autoloads there, so logic tests must not touch UI classes). Screen tests: `res://tests/ui_smoke.tscn` and `ui_touch.tscn`. Full check: `bash tools/run_all_checks.sh` (about 25 minutes, run it in the background).
- Do not name a method `_set`. Do not free a screen inside its own signal. A script load error hangs the engine, so run `--import` after adding a `class_name` file. Use explicit types for `:=` on untyped values. All visible text goes through `Strings.t("key")` with keys added to `game/i18n/en.json`.
- Presentation never feeds back into results: the match is decided first, the view only plays it back.
"""


MANAGER_NOTES = """
## How you work (Studio Manager)
Read `company/STUDIO-MANAGEMENT.md` and follow it exactly.
1. For each handback you are given, open the files it lists and re-run or re-read the evidence it cites. A claim you cannot verify is scored as unverified, not as true.
2. Score the nine criteria 0 to 5, each with one line of evidence. Give a verdict: Accept, Rework (with an exact numbered fix list), Reject, or Reassign (name the right agent).
3. Write the scorecards to `company/reviews/YYYY-MM-DD-<topic>.md` and complete the ledger row in `company/LEDGER.md`.
4. End with the team report: utilisation, bottlenecks and overlap, quality trend, risks, at most three recommendations. Then a Founder summary that fits one phone screen.
5. Be fair and specific. Praise what is good, name what is weak, and never grade your own work or edit another agent's files.
"""


def agent_file(r):
    status = r["status"]
    reports = NAMES[r["reports_to"]]
    reviewers = ", ".join(NAMES[x] for x in r["reviewed_by"].split(", "))
    desc = (f"{r['title']} ({r['dept']}). {r['duties'].split('. ')[0].rstrip('.')}. "
            f"Status: {status}. Use when a task needs this role's work.")
    body = f"""---
name: {r['id']}
description: {json.dumps(desc)}
tools: {TOOLS[r['kind']]}
---
# {r['title']}

Department: {r['dept']}  |  Reports to: {reports}  |  Status: {status}

You are the {r['title']} of a small virtual game studio. The studio is building an original, IP-safe, single-player MOBA esports manager mobile game (Godot 4.3, Android first, English). The Founder is Fuyi, a non-technical entrepreneur. The Producer (the main session) dispatches you with a task, and the Studio Manager reviews the quality and efficiency of your handback.

## Your job in this game
{r['duties']}

## You own
{r['owns']}

## What you cannot do (be honest about it)
{r['limits']}

## Reviewed by
{reviewers}; the Studio Manager scores every handback (see `company/STUDIO-MANAGEMENT.md`).

## Studio rules (every agent)
1. Read first: `company/WORKFLOW.md`, `company/DECISIONS.md` (Founder decisions are final), the GDD sections your task touches (`docs/design/GDD-v1.md`), and `docs/design/UI-UX-REFERENCE-v1.md` for anything players see. Roster and who owns what: `company/TEAM.md`.
2. Founder pillars: customer satisfaction and ease of use come first; the game has its own flair and look; about 5 minutes per game including the draft; no ads or upsell in the core loop; subscriptions are postponed.
3. Originality: copy nothing from ESMO or any other game. Names, art and audio are original or licence-logged, and go to the IP & Originality Checker.
4. Evidence, not claims: say a thing works only if you ran it. State plainly what you could not test. Nothing here has been run on a physical phone.
5. Any image or video you are given gets two analysis passes: a first analysis, then a second one to double-check and catch what was missed.
6. Stay in your lane. Edit only what you own; put requests for other roles in your handback. Do not commit or push (the Producer does that after review). Do not contact the Founder directly.
7. Keep anything meant for the Founder short enough to read on a phone, in plain words, with a recommendation for every decision you ask for.
{ENGINEERING_NOTES if r['kind'] == 'code' else ''}{MANAGER_NOTES if r['id'] == 'studio-manager' else ''}
## Handback format (end every task with this, in this order)
1. **Done**: what you finished, in two or three lines.
2. **Files**: every file you created or changed.
3. **Evidence**: tests run and results, screenshots checked, numbers measured.
4. **Not done or risky**: gaps, assumptions, things you could not test.
5. **Decisions needed**: for the Founder or another role, each with your recommendation.
6. **Effort**: roughly how many tool calls you used and how many times you had to redo something.
7. **Hand-offs**: what other roles should do next because of your work.
"""
    return body


def team_md():
    lines = ["# Studio team", "",
             "Generated by `tools/build_team.py` from `tools/team_roster.py`. Edit the roster, not this file.", "",
             "The Founder (Fuyi) is the CEO. Every role below is an agent definition in `.claude/agents/`. "
             "The Producer (the main Claude session) dispatches agents, the Studio Manager reviews their work.", "",
             "## How it really works", "",
             "- Agents are dispatched one task at a time by the Producer. They do not talk to each other or start other agents, so the reporting lines below say who reviews whom and who owns what; they do not mean an agent manages another agent live.",
             "- ACTIVE roles are used in the current Alpha. ON CALL roles are used only when a task needs them. DORMANT roles wait for the named phase. This keeps usage cost under control.",
             "- Every handback is scored by the Studio Manager before the Producer commits it (`company/STUDIO-MANAGEMENT.md`).",
             "- Agents write text, code, data and code-drawn art. They cannot paint, record, sculpt 3D models or test on a physical phone.", ""]
    counts = {}
    for r in ROSTER:
        k = r["status"].split(":")[0]
        counts[k] = counts.get(k, 0) + 1
    lines.append(f"Agents: {len(ROSTER)} ({counts.get('ACTIVE', 0)} active, {counts.get('ON CALL', 0)} on call, {counts.get('DORMANT', 0)} dormant).")
    lines.append("")
    # tree
    kids = {}
    for r in ROSTER:
        kids.setdefault(r["reports_to"], []).append(r)

    def walk(pid, depth):
        for r in kids.get(pid, []):
            lines.append("  " * depth + f"- **{r['title']}** (`{r['id']}`, {r['status']})")
            walk(r["id"], depth + 1)

    lines += ["## Reporting lines", "", "- **Founder / CEO (Fuyi)**"]
    walk("founder", 1)
    lines += ["", "## Roster", "", "| Role | Department | Status | In charge of (this game) | Cannot do |", "|---|---|---|---|---|"]
    for r in ROSTER:
        d = r["duties"].split(". ")[0].rstrip(".")
        lines.append(f"| {r['title']} | {r['dept']} | {r['status']} | {d} | {r['limits'].split('. ')[0].rstrip('.')} |")
    lines += ["", "## Earlier eight roles and where they went", "",
              "| Earlier role | Now |", "|---|---|",
              "| Producer | Producer / Scrum Master (and Senior Producer for planning) |",
              "| Game Design Lead | Lead Game Designer |",
              "| Systems Lead | Systems Designer |",
              "| Content Lead | Gameplay / Champion Designer (heroes, items) and Narrative Designer (names, lore) |",
              "| UI/UX Lead | UI/UX Designer |",
              "| Engineering Lead | Lead Programmer |",
              "| QA & Balance Lead | QA Manager and Balance Designer |",
              "| IP Checker | IP & Originality Checker (kept; not in the Founder's table) |",
              "", "The old charters in `company/charters/` stay as history. Where they differ from `.claude/agents/`, the agent files win.", ""]
    return "\n".join(lines)


def main():
    out = ROOT / ".claude" / "agents"
    out.mkdir(parents=True, exist_ok=True)
    for r in ROSTER:
        (out / f"{r['id']}.md").write_text(agent_file(r))
    (ROOT / "company" / "TEAM.md").write_text(team_md())
    print(f"wrote {len(ROSTER)} agents and company/TEAM.md")


if __name__ == "__main__":
    main()
