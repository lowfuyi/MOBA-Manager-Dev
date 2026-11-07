# How the studio works

This is a virtual game studio. Each "agent" is Claude working under one role charter (`company/charters/`). Agents work when a session is run, and they communicate only through files in this repository. The repository is the single source of truth.

## Org chart

```
Founder (Fuyi)  ........ vision, final approval, all "Founder decisions"
 └─ Producer ........... plans, assigns, tracks, enforces process
     ├─ Game Design Lead ......... rules, progression, economy, league structure
     ├─ Systems Lead ............. match simulation, formulas, numbers
     ├─ Content Lead ............. original champions, items, names, lore
     ├─ UI/UX Lead ............... screen flows, wireframes, UX rules
     ├─ Engineering Lead ......... Godot code, data loading, builds
     ├─ QA & Balance Lead ........ test plans, simulation runs, balance reports
     └─ IP Checker ............... originality and store-policy screening
```

## Task lifecycle

Every piece of work moves through the same four gates.

1. **Spec**: the owning lead writes a short spec (goal, inputs, outputs, acceptance criteria) and the Producer adds it to `TASKBOARD.md`.
2. **Build**: the owner (or the Engineering Lead for code) produces the deliverable.
3. **Review**: a different role reviews it against the acceptance criteria and writes findings. The author fixes them. The reviewer for each deliverable type is listed below.
4. **Sign-off**: anything marked **Founder gate** goes to the Founder with a one-page summary and the open questions. Nothing downstream starts until it is approved.

Status values: `Backlog`, `Spec`, `In build`, `In review`, `Needs Founder`, `Done`, `Blocked`.

## Who reviews whom

| Deliverable | Author | Reviewer | Founder gate? |
|---|---|---|---|
| Game Design Document sections | Game Design Lead | Systems Lead + IP Checker | Yes, major changes |
| Match sim formulas and parameters | Systems Lead | QA & Balance Lead | Yes, when core feel changes |
| Champions, items, names | Content Lead | IP Checker + QA & Balance Lead | Yes, the first full set |
| Screen flows and wireframes | UI/UX Lead | Game Design Lead | Yes, the first full flow |
| Code | Engineering Lead | QA & Balance Lead | No (tests must pass) |
| Test plans and balance reports | QA & Balance Lead | Systems Lead | No |
| Any public-facing text or store listing | Producer | IP Checker | Yes |

## Rules

- Decisions that affect more than one department are recorded in `DECISIONS.md` with the date and who decided.
- Numbers (stats, costs, formulas' constants) live in `data/`, not inside prose or code, so QA can change them without touching logic.
- If a spec is ambiguous, the author asks the Producer; the Producer asks the Founder only when the answer changes the product.
- Nothing is copied from another game: no names, art, kits, item lists, lore, UI layouts or text. Genre mechanics are fine.
- AI-generated art and audio are out of scope until the visual phase and need a separate policy check before use.
- A task is Done only when its acceptance criteria are met and its reviewer has signed off in the file.

## Honest limits

- Agents are not running continuously. Work advances in sessions; the Producer leaves the board in a state that any session can pick up.
- IP Checker is a screening filter, not legal advice. A real IP lawyer should review before launch.
- Visual assets, audio, and store accounts need human-owned accounts and paid tools later.
