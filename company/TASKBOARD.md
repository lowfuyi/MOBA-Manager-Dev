# Task board

Last updated: 2026-11-07 by Producer

## Phase 0: Design

| ID | Task | Owner | Reviewer | Status |
|---|---|---|---|---|
| D-001 | Repo structure, workflow, role charters | Producer | Founder | In review |
| D-002 | Game Design Document v1.2 (two independent reviews done) | Game Design Lead | Systems Lead + IP Checker | In review |
| D-003 | Founder decisions on open questions (see DECISIONS.md) | Founder | n/a | Needs Founder |
| D-004 | Prototype of the match formula (done as `tools/proto_sim.py` v0.2; calibrated to GDD section 9) | Systems Lead | QA & Balance Lead | Done (re-review passed with fixes) |
| D-007 | Economy (also: CON is a reliability stat, so valuation must not treat it as plain strength; asking wage floor and Potential factor; 4-week-negative dismissal rule): wages, contract valuation, sponsor lite (offers, objectives, tutorial goals), finance screens (Overview, Analytics, History), 10-season no-bankruptcy and no-snowball test | Systems Lead | QA & Balance Lead | Backlog |
| D-008 | Player generation rules and the 40-hero set (data): v0 done and tested (`tools/gen_heroes.py`, `tools/gen_players.py`, `tools/tune_tags.py`; 15 content tests; Godot loads and validates it). Open: IP name search, runtime generator port for new saves, pool of names for Global edition | Content Lead | IP Checker + QA | In review |
| D-009 | Game Plan: v1.4 spec written (8 zero-sum controls on 3 simulator hooks, triggers at +-0.40). Remaining: `game/data/game_plan_v0.json`, engine two-pass trigger logic, no-dominant-plan tests (9.2.1) | Systems Lead | QA & Balance Lead + IP Checker | In progress (Founder approved) |
| D-010 | Team Bonds spec: pairwise Bond and Understanding, languages field, analytics screens | Systems Lead + UI/UX | QA + IP Checker | Backlog (Founder approved) |
| D-005 | Original role/archetype set and 40 heroes (names + data only) | Content Lead | IP Checker + QA | Done for v0 with placeholder names (see D-008); IP name search pending |
| D-006 | Original naming glossary (map, objectives, items, terms) | Content Lead | IP Checker | Backlog |
| D-011 | Exhibition and Quick Match modes (single player, no league effect) | Game Design Lead | Systems Lead | Backlog |
| D-012 | Multiplayer ladder, ranks, matchmaking and club search spec (Multiplayer edition, later) | Systems Lead | QA + IP Checker | Parked |
| D-013 | Recruitment and contracts spec: free-agent database and saved searches, scouting reports (New, Shortlisted, Rejected), up-to-3-round negotiation, contract terms (wage, splits, prize share), personality mapping, release and expiry, club history log | Systems Lead + Game Design Lead | QA + IP Checker | Backlog (proposed) |
| D-014 | Manager level, XP and talents (one MOBA tree, about 30 nodes, no direct match strength) | Systems Lead | QA & Balance Lead | Parked until core loop is balanced |
| D-015 | Multiplayer transfer market spec (provisional agreement, offers, fee bands, no real-money trading) | Systems Lead | QA + IP Checker | Parked (Multiplayer edition) |
| D-016 | Player profile spec: per-stat Potential (changes D-008 generation and the scouting display), stat help sheets, hero and role mastery levels, derived match statistics (KDA) with consistency tests, career log | Systems Lead + Game Design Lead | QA & Balance Lead | Backlog (proposed) |
| D-017 | Form Rating (Elo-style, K 24, v1.4), trophy cabinet, region and country data fields; QA test for ranking accuracy (9.2.5, number check already in `tools/test_gdd_numbers.py`) | Systems Lead | QA & Balance Lead | Backlog (proposed) |
| D-018 | Global edition competitions spec: tiers, open cups, invitationals, qualifier chains, promotion series, regions, original format names | Game Design Lead | QA + IP Checker | Parked (Global edition) |

## Phase 1: Prototype (starts after D-003 is decided)

| ID | Task | Owner | Reviewer | Status |
|---|---|---|---|---|
| P-001 | Godot project skeleton, string tables, data loaders and schemas, PCG32 reference and golden vectors | Engineering Lead | QA | Done: 14 Python tests and 61 headless Godot checks pass (Godot 4.3 official build, checksum verified); negative test confirmed tests can fail |
| P-002 | Match simulator as a headless module with unit tests (Python reference `tools/sim_core.py` on PCG32, Godot port `game/src/sim/match_sim.gd`, 25 golden cases, frozen input interface incl. Game Plan hooks, calibration re-run) | Engineering Lead | QA | Done; QA review of GDD v1.3 raised no defect in the simulator code itself. 33 Python tests, 588 Godot checks pass |
| P-003 | Batch harness: full-pipeline run (9.1) DONE 2026-11-07 (draft constants re-tuned, `docs/design/CALIBRATION-9.1.md`, `tools/pipeline*.py`). Remaining: paired common-random-number lever tests with the v1.4 bands, calibration at Phase 1 rating scale (about 45), joint Game Plan coordinate-ascent test (9.2.1), 10,000-match report | QA & Balance Lead | Systems Lead | In progress (9.1 part done) |
| D-018 | Pacing and formats (GDD 8.7): re-run 9.1 with the Short draft profile; add draft timers and auto-pick to the draft spec; game clock L in match report; playback speed and Skip in the match screen spec | Systems Lead | QA & Balance Lead | Backlog |
| P-004 | Roster screen, draft screen, match result screen (placeholder visuals) | Engineering + UI/UX | Game Design Lead | Done in Alpha 0.1 (A-004) |
| A-004 | Alpha 0.1: installable Android build of the Single Player loop (club pick, lineup, 10 s draft, feed, report, season with standings and playoffs). Game state and report logic tested headless (1,514 checks), UI smoke test through a whole season, screenshot QA at 720x1280, APK exported and signature verified. Not yet run on a physical phone. Notes: `docs/ALPHA-0.1-NOTES.md` | Engineering Lead + UI/UX | QA (independent review pending) | Delivered for Founder game test |

## Later phases

Scouting and training, seasons and league structure, finances, backend and online leagues, visual and audio pass, store release.

## Phase 1 plan (Single Player edition, Android first, English text only)

Order of work: P-001 project skeleton and string tables, P-002 headless simulator with golden tests, P-003 batch harness and the section 9.1 full-pipeline calibration, D-005/D-008 content data (40 heroes, player generation), then P-004 screens. Subscriptions, online play and the animated map are later phases.
