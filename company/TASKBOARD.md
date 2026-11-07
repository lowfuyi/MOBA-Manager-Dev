# Task board

Last updated: 2026-11-07 by Producer

## Phase 0: Design

| ID | Task | Owner | Reviewer | Status |
|---|---|---|---|---|
| D-001 | Repo structure, workflow, role charters | Producer | Founder | In review |
| D-002 | Game Design Document v1.2 (two independent reviews done) | Game Design Lead | Systems Lead + IP Checker | In review |
| D-003 | Founder decisions on open questions (see DECISIONS.md) | Founder | n/a | Needs Founder |
| D-004 | Prototype of the match formula (done as `tools/proto_sim.py` v0.2; calibrated to GDD section 9) | Systems Lead | QA & Balance Lead | Done (re-review passed with fixes) |
| D-007 | Economy: wages, contract valuation, sponsor lite (offers, objectives, tutorial goals), finance screens (Overview, Analytics, History), 10-season no-bankruptcy and no-snowball test | Systems Lead | QA & Balance Lead | Backlog |
| D-008 | Player generation rules and the 40-hero set (data) | Content Lead | IP Checker + QA | Backlog |
| D-009 | Game Plan spec: sliders, triggers, model mapping, no-dominant-plan test (see REFERENCE-ESMO-ADAPTATION.md) | Systems Lead | QA & Balance Lead + IP Checker | Backlog (Founder approved) |
| D-010 | Team Bonds spec: pairwise Bond and Understanding, languages field, analytics screens | Systems Lead + UI/UX | QA + IP Checker | Backlog (Founder approved) |
| D-005 | Original role/archetype set and 40 heroes (names + data only) | Content Lead | IP Checker + QA | Backlog |
| D-006 | Original naming glossary (map, objectives, items, terms) | Content Lead | IP Checker | Backlog |
| D-011 | Exhibition and Quick Match modes (single player, no league effect) | Game Design Lead | Systems Lead | Backlog |
| D-012 | Multiplayer ladder, ranks, matchmaking and club search spec (Multiplayer edition, later) | Systems Lead | QA + IP Checker | Parked |
| D-013 | Recruitment and contracts spec: free-agent database and saved searches, scouting reports (New, Shortlisted, Rejected), up-to-3-round negotiation, contract terms (wage, splits, prize share), personality mapping, release and expiry, club history log | Systems Lead + Game Design Lead | QA + IP Checker | Backlog (proposed) |
| D-014 | Manager level, XP and talents (one MOBA tree, about 30 nodes, no direct match strength) | Systems Lead | QA & Balance Lead | Parked until core loop is balanced |
| D-015 | Multiplayer transfer market spec (provisional agreement, offers, fee bands, no real-money trading) | Systems Lead | QA + IP Checker | Parked (Multiplayer edition) |

## Phase 1: Prototype (starts after D-003 is decided)

| ID | Task | Owner | Reviewer | Status |
|---|---|---|---|---|
| P-001 | Godot project skeleton, data loaders for CSV/JSON | Engineering Lead | QA | Backlog |
| P-002 | Match simulator as a headless module with unit tests | Engineering Lead | QA | Backlog |
| P-003 | Batch simulation harness (10,000 matches, win-rate report) | QA & Balance Lead | Systems Lead | Backlog |
| P-004 | Roster screen, draft screen, match result screen (placeholder visuals) | Engineering + UI/UX | Game Design Lead | Backlog |

## Later phases

Scouting and training, seasons and league structure, finances, backend and online leagues, visual and audio pass, store release.

## Phase 1 plan (Single Player edition, Android first, English text only)

Order of work: P-001 project skeleton and string tables, P-002 headless simulator with golden tests, P-003 batch harness and the section 9.1 full-pipeline calibration, D-005/D-008 content data (40 heroes, player generation), then P-004 screens. Subscriptions, online play and the animated map are later phases.
