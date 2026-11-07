# MOBA Manager (working title)

A mobile esports **manager** game focused entirely on the MOBA genre. You are the club owner and head coach: scout and sign players, train them, draft heroes on match day, and climb through the league tiers. You never control a hero directly. Matches are simulated from your roster, your draft and your preparation.

Inspired by the management loop of ESMO: Esports Manager Online, but MOBA-only, with all names, art, heroes, items and maps being original.

## Status

Phase 0: design. No code yet. See `company/TASKBOARD.md` for the current state.

## Repository layout

```
README.md
company/
  WORKFLOW.md        How the virtual studio works: roles, chain of command, review rules
  TASKBOARD.md       Current tasks, owners, status
  DECISIONS.md       Founder decisions and open questions
  charters/          One charter per role (what the role owns, outputs, reviewer, done criteria)
docs/
  design/
    GDD-v1.md        Game Design Document (source of truth for rules)
data/                (later) heroes, items, players as CSV/JSON, no art
src/                 (later) Godot project
```

## Principles

1. Design before code. Rules live in `docs/design/`, numbers live in `data/`, code reads both.
2. Nobody approves their own work. Every deliverable has a different reviewer.
3. Visuals come last. Placeholder names and plain icons until the pre-launch phase.
4. Originality. Genre conventions are free to use; names, art, lore and exact hero kits are ours alone.
