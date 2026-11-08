# Studio management: how agent work is monitored

Owner: Studio Manager (`.claude/agents/studio-manager.md`), reporting directly to the Founder. It sits outside the Executive Producer's tree on purpose, so the people who plan the work are not the ones grading it.

## What it can and cannot see

It judges only what is written down and observable: the files an agent changed, the tests and screenshots it ran, its handback, and the task board and ledger entries. It cannot read an agent's reasoning or measure behaviour on a real phone. It audits and recommends. It never produces the deliverables it reviews and never edits another agent's files; it writes only to `company/reviews/`, `company/LEDGER.md` and the status column of `company/TEAM.md`.

## The loop (every dispatch)

1. **Dispatch.** The Producer adds a line to `company/LEDGER.md`: date, task id, agent, one-line brief, acceptance criteria.
2. **Work.** The agent returns the handback in the standard seven parts (Done, Files, Evidence, Not done or risky, Decisions needed, Effort, Hand-offs).
3. **Review.** The Studio Manager scores the handback, checks the claims against the files and test output, and records a verdict.
4. **Act.** Accept: the Producer commits. Rework: the Producer re-dispatches with the Studio Manager's exact fix list. Reject or Reassign: the task goes back to the plan.
5. **Report.** After each batch, the Studio Manager gives the Founder a one-screen team report.

## Scorecard (0 to 5 each, written with one line of evidence)

Quality
- **Spec fit:** does it meet the acceptance criteria as written?
- **Evidence:** were claims tested (commands, results, screenshots), and are gaps stated?
- **Founder pillars:** ease of use, customer satisfaction, own flair, about 5 minutes per game, no upsell in the core loop.
- **Originality:** no copying; names, art and audio logged for the IP & Originality Checker.
- **Handback clarity:** can the Producer act on it without a follow-up question?

Efficiency
- **Rework rounds:** 0 is full marks; each extra round costs a point.
- **Scope discipline:** stayed in its lane, no unrequested extras, no duplicated work.
- **Effort vs result:** tool calls and time compared with similar past tasks in the ledger.
- **Blocked time:** questions that should have been asked up front.

## Verdicts

| Verdict | When | Effect |
|---|---|---|
| Accept | Quality average 4 or more, no criterion below 3 | Producer commits |
| Rework | Fixable gaps | Exact fix list; counts as a rework round |
| Reject | Wrong approach or unusable | Back to the plan; charter reviewed |
| Reassign | Wrong role for the task | Name the right agent |

Three Rework or Reject verdicts in a row for one agent trigger a charter review: the Studio Manager proposes a clearer charter or a different split of ownership, and tells the Founder.

## Team-level checks (in every report)

- **Utilisation:** which agents were used, which sat idle, whether any ON CALL role should become ACTIVE or an ACTIVE role should rest. Cost control matters, so more agents is not the goal; right agents is.
- **Bottlenecks and overlap:** two agents touching the same file, tasks waiting on one role, duplicated ownership.
- **Quality trend:** average score and rework rate per agent and per department, last five dispatches.
- **Risks:** anything threatening the Alpha exit checklist or the Founder's pillars.
- **Recommendations:** at most three, each with an owner.

## Report to the Founder (one phone screen)

Headline in one sentence; a short table of verdicts (agent, task, score, verdict); the top three risks; the decisions needed with a recommendation each. Plain words, no jargon.

## Files

- `company/LEDGER.md`: one row per dispatch (see its header for columns).
- `company/reviews/YYYY-MM-DD-<topic>.md`: the scorecards and the team report for that batch.
- `company/TEAM.md`: roster and status, generated from `tools/team_roster.py`.
