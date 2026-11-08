# Task board

Last updated: 2026-11-08 by Producer

## Phase 0: Design

| ID | Task | Owner | Reviewer | Status |
|---|---|---|---|---|
| D-001 | Repo structure, workflow, role charters | Producer | Founder | In review |
| D-002 | Game Design Document v1.2 (two independent reviews done) | Game Design Lead | Systems Lead + IP Checker | In review |
| D-003 | Founder decisions on open questions (see DECISIONS.md) | Founder | n/a | Needs Founder |
| D-004 | Prototype of the match formula (done as `tools/proto_sim.py` v0.2; calibrated to GDD section 9) | Systems Lead | QA & Balance Lead | Done (re-review passed with fixes) |
| D-007 | Economy (also: CON is a reliability stat, so valuation must not treat it as plain strength; asking wage floor and Potential factor; 4-week-negative dismissal rule): wages, contract valuation, sponsor lite (offers, objectives, tutorial goals), finance screens (Overview, Analytics, History), 10-season no-bankruptcy and no-snowball test | Systems Lead | QA & Balance Lead | Backlog |
| D-008 | Player generation rules and the 40-hero set (data): v0 done and tested (`tools/gen_heroes.py`, `tools/gen_players.py`, `tools/tune_tags.py`; 15 content tests; Godot loads and validates it). Open: IP name search, runtime generator port for new saves, pool of names for Global edition | Content Lead | IP Checker + QA | In review |
| D-009 | Game Plan: 8 zero-sum controls, triggers at +-0.40, coach suggestion. Engine, data (`game_plan_v0.json`), editor screen, draft/match/report integration done in Alpha 0.2. QA 9.2.1 passed on held-out seeds (best single control +0.87 pt, joint +1.56 pt mean against limit 3.0, best plan differs in 15 of 15 matchups); 1,547 headless checks, UI smoke covers the screen. See CALIBRATION-9.1 addendum | Systems Lead + Engineering | QA & Balance Lead + IP Checker | Done (Alpha 0.2); re-run QA after Team Bonds |
| D-010 | Team Bonds spec: pairwise Bond and Understanding, languages field, analytics screens | Systems Lead + UI/UX | QA + IP Checker | Done in Alpha 0.4 (A-007): constants in `game/data/bonds_v0.json`, GDD 7.7 implementation notes |
| D-005 | Original role/archetype set and 40 heroes (names + data only) | Content Lead | IP Checker + QA | Done for v0 with placeholder names (see D-008); IP name search pending |
| D-006 | Original naming glossary (map, objectives, items, terms) | Content Lead | IP Checker | Backlog |
| D-011 | Exhibition and Quick Match modes (single player, no league effect) | Game Design Lead | Systems Lead | Done in Alpha 0.6 |
| D-012 | Multiplayer ladder, ranks, matchmaking and club search spec (Multiplayer edition, later) | Systems Lead | QA + IP Checker | Parked |
| D-013 | Recruitment and contracts spec: free-agent database and saved searches, scouting reports (New, Shortlisted, Rejected), up-to-3-round negotiation, contract terms (wage, splits, prize share), personality mapping, release and expiry, club history log | Systems Lead + Game Design Lead | QA + IP Checker | Partly done in Alpha 0.3 (free-agent market, negotiation, contracts, release, expiry; saved searches, scouting reports, prize weight and career log still open) |
| D-014 | Manager level, XP and talents (one MOBA tree, about 30 nodes, no direct match strength) | Systems Lead | QA & Balance Lead | Parked until core loop is balanced |
| D-015 | Multiplayer transfer market spec (provisional agreement, offers, fee bands, no real-money trading) | Systems Lead | QA + IP Checker | Parked (Multiplayer edition) |
| D-016 | Player profile spec: per-stat Potential (changes D-008 generation and the scouting display), stat help sheets, hero and role mastery levels, derived match statistics (KDA) with consistency tests, career log | Systems Lead + Game Design Lead | QA & Balance Lead | Done in Alpha 0.6 (one-line stat help, KDA and career log) |
| D-017 | Form Rating (Elo-style, K 24, v1.4), trophy cabinet, region and country data fields; QA test for ranking accuracy (9.2.5, number check already in `tools/test_gdd_numbers.py`) | Systems Lead | QA & Balance Lead | Done in Alpha 0.6 (Elo, trophy cabinet; region and country fields are later) |
| D-018 | Global edition competitions spec: tiers, open cups, invitationals, qualifier chains, promotion series, regions, original format names | Game Design Lead | QA + IP Checker | Parked (Global edition) |

## Phase 1: Prototype (starts after D-003 is decided)

| ID | Task | Owner | Reviewer | Status |
|---|---|---|---|---|
| P-001 | Godot project skeleton, string tables, data loaders and schemas, PCG32 reference and golden vectors | Engineering Lead | QA | Done: 14 Python tests and 61 headless Godot checks pass (Godot 4.3 official build, checksum verified); negative test confirmed tests can fail |
| P-002 | Match simulator as a headless module with unit tests (Python reference `tools/sim_core.py` on PCG32, Godot port `game/src/sim/match_sim.gd`, 25 golden cases, frozen input interface incl. Game Plan hooks, calibration re-run) | Engineering Lead | QA | Done; QA review of GDD v1.3 raised no defect in the simulator code itself. 33 Python tests, 588 Godot checks pass |
| P-003 | Batch harness: full-pipeline run (9.1) DONE 2026-11-07 (draft constants re-tuned, `docs/design/CALIBRATION-9.1.md`, `tools/pipeline*.py`). Remaining: paired common-random-number lever tests with the v1.4 bands, calibration at Phase 1 rating scale (about 45), joint Game Plan coordinate-ascent test (9.2.1), 10,000-match report | QA & Balance Lead | Systems Lead | In progress (9.1 part done) |
| D-018 | Pacing and formats (GDD 8.7): Short draft re-test done (draft lever preserved, low-powered n=400; 4,000+ run goes into P-003); draft timers, auto-pick, Skip and playback speed are in the Alpha 0.1 screens | Systems Lead | QA & Balance Lead | Done (Alpha 0.2) |
| P-004 | Roster screen, draft screen, match result screen (placeholder visuals) | Engineering + UI/UX | Game Design Lead | Done in Alpha 0.1 (A-004) |
| A-004 | Alpha 0.1: installable Android build of the Single Player loop (club pick, lineup, 10 s draft, feed, report, season with standings and playoffs). Game state and report logic tested headless (1,514 checks), UI smoke test through a whole season, screenshot QA at 720x1280, APK exported and signature verified. Not yet run on a physical phone. Notes: `docs/ALPHA-0.1-NOTES.md` | Engineering Lead + UI/UX | QA (independent review pending) | Delivered for Founder game test |
| A-005 | Alpha 0.2: Game Plan screen and engine (D-009), training focus, fatigue with rotation, ageing and growth (GDD 7.3) for every club, growth summary. Constants in `game/data/training_v0.json` (Coach 2, Facility 2 fixed until D-007). 1,590 headless checks, UI smoke and touch tests cover the new screens, QA `tools/train_qa.gd` (no schedule dominant). Notes: `docs/ALPHA-0.2-NOTES.md` | Engineering Lead + Systems Lead | QA (independent review pending) | Delivered for Founder game test |
| A-006 | Alpha 0.3: free-agent market, contracts and negotiation (D-013 part), cash ledger with per-round wages and sponsor, sponsor choice with strength-scaled targets, prize money, wage cap, dismissal and game-over screen (GDD 7.2, 7.6). Constants in `game/data/economy_v0.json`. 1,672 headless checks, UI smoke and touch tests cover the new screens, economy QA `tools/econ_qa.gd`. Notes: `docs/ALPHA-0.3-NOTES.md` | Engineering Lead + Systems Lead | QA (independent review pending) | Delivered for Founder game test |
| A-007 | Alpha 0.4: Team Bonds (pair store for the managed roster, one level per AI squad), Understanding and chemistry bonus into TeamMod, Team chemistry screen (pentagon, 5x5 grid, languages, bench), Player Form and Morale in the match rating, Team scrim training focus, save migration (GDD 4.2, 7.7, 8.6). Constants in `game/data/bonds_v0.json`. Headless checks, UI smoke and touch tests cover the new screens; QA in CALIBRATION-9.1 addendum (`tools/chem_qa.gd`). Version 0.4.0 alpha, versionCode 5. | Engineering + Systems Lead | QA | Done, with Founder to game test |

## Later phases

Scouting and training, seasons and league structure, finances, backend and online leagues, visual and audio pass, store release.

## Phase 1 plan (Single Player edition, Android first, English text only)

Order of work: P-001 project skeleton and string tables, P-002 headless simulator with golden tests, P-003 batch harness and the section 9.1 full-pipeline calibration, D-005/D-008 content data (40 heroes, player generation), then P-004 screens. Subscriptions, online play and the animated map are later phases.
| A-008 | Alpha 0.5 (UI pass 1, UI-1 to UI-4 and UI-7 of the UI reference): Arena Dusk tokens and components, bottom tab bar with Plan and Club pages, new Home page, payoff screen after a game (`Payoff` snapshot and compare, one tip), preview panels and Undo (training, Game Plan, negotiation), fixed 75-second watch window and local pace log, Animations switch. No rule changes. Version 0.5.0 alpha, versionCode 6. Notes: `docs/ALPHA-0.5-NOTES.md` | Engineering + UI/UX | QA (independent review pending) | Done, with Founder to game test |
| A-009 | UI pass 2 backlog: lane-based chemistry (UI-5), story-first match view (UI-6), draft redesign (UI-8), dismissible hints (UI-9), text size and colour-blind options (UI-10), sound and haptics (UI-11), real-phone usability test (UI-12) | UI/UX + Engineering | Founder | Backlog |
| A-010 | Alpha 0.6 (Alpha exit checklist work): Exhibition and Quick Match (GDD 7.9), Form Rating and trophy cabinet (10.1), career record and derived KDA (4.2), stat help, comfort options (large text, colour-blind colours), one-time tips, privacy line and feedback note, start-up time in Debug info, `soak.gd` (125 seasons clean), calibration at rating scale 45, Game Plan rerun with chemistry, ten-season economy run. GDD v1.11. Version 0.6.0 alpha, versionCode 7. Notes: `docs/ALPHA-0.6-NOTES.md`, checklist: `docs/ALPHA-EXIT-CHECKLIST.md` | Engineering + Systems Lead + UI/UX | QA (independent review pending) | Done, with Founder to game test |

| A-011 | Alpha 0.7 / 0.8 from the Founder's play-test feedback (see `docs/ALPHA-0.7-PLAN.md`): W1 guided tutorial and in-context help, W2 visual pass 2, W3 non-linear layouts, W4 live match arena. Wave 1 specs delivered (esports notes, tutorial, art bible and style tile, Hollowmere arena map with validator, action vocabulary, layout redesign); Studio Manager review in `company/reviews/2026-11-08-wave1.md`. Wave 2 and build wait for the Founder checkpoint. | Producer + design agents; Studio Manager reviews | Founder | Spec stage |
