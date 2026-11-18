# Alpha 0.8 "Arena": build plan v1.1

Owner: Producer (acting as Lead Programmer in Claude Code). Date: 2026-11-18. Status: plan, built in the order below, one commit per increment, reviewed and logged as in Alpha 0.7. v1.1 (A-05): the intent labels, status tags, plan row and word budget moved from A-05 to A-07, where their copy is written; the controls row stays in A-06 with the screen.

## 0. What 0.8 is

The Founder's Alpha 0.6 feedback said the match playback "lacks action". Alpha 0.7 rebuilt everything around the match; Alpha 0.8 replaces the text feed of the Match screen with a **live arena**: the Wrenfell map on screen, the ten heroes as tokens walking the lanes, every contest staged where and when it happens, a scoreboard that is a pure function of the show time, short feed captions, the coach's intent labels and an end card. The Founder's decisions that bound it:

- **Spectator only. No mid-match interventions.** The simulation decides the result before the first frame; the arena only plays it back (ACTION-VOCABULARY H1 to H6).
- The watch window stays **75 s** at normal speed; x2 and Skip stay free; Quick mode still skips the watch.
- Teal circle = you, coral hexagon = them; Blue and Red only as a word and a flag glyph.
- **Held-fight staging is decided by tester scores** (ARENA-MAP 7.3). 0.8 builds the three endings from the data, ships `held_island` as the provisional default for the 19 percent of games where the match winner loses the last fight (the data's default and the tie rule of 7.3), and gives testers a switch to see the other ending. The Founder decides after the scores.

## 1. Sources (the authority for each part)

| Part | Source |
|---|---|
| What the arena may read, the beats, the 75 s timeline, scoreboard formulas, invariants I1 to I9, intent labels | `docs/design/ACTION-VOCABULARY.md` |
| Map geometry, ids, walks, stages, camera, labels, held-fight variants | `game/data/arena_map.json` (authority) and `docs/design/ARENA-MAP.md` |
| The HUD on a 720 x 1280 screen, text budget, controls, large text, colour-blind | `docs/design/UI-PASS-2.md` 6.7 |
| Colours, token shapes, type scale | `docs/design/ART-BIBLE.md` |
| Draw-call and node budget | `docs/design/PERF-BUDGET.md` (a redesigned screen: target 60 draw calls, hard 100) |

## 2. Rules (carried from 0.7)

R1 no change to `game/src/sim/`; the golden hash stays `0b81a41b...ee3c`. R2 one increment = one commit by explicit paths, after `tools/check_fast.sh` is ALL GREEN. R3 tests migrated in the same change. R4/R5 typed `:=`, no `_set*` names. R6 the save changes only by additive keys. R7 presentation never feeds results. Plus, for the arena: **A1** the arena never calls `MatchSim`, `GamePlan.simulate` or `Report.attribution` to find an outcome and never writes `res` (a grep test); **A2** its only randomness is a `show` stream seeded from `res.mseed`, never a simulation stream; **A3** the same result plays the same show (a determinism test); **A4** the map is baked to a texture once, tokens and effects are drawn from atlases, so a frame stays within the budget.

## 3. Increments

| # | Increment | What | Tests (headless unless marked) |
|---|---|---|---|
| A-01 | **Show script** | `ShowScript.build(res, my_side)`: the beat list with windows and resolve times (1.4), per-contest triple, size and winner (F1, F2), lead ladder (F4), flips (F5), arc (F6), tower credits, kill ledger, objectives (section 5), plan check; `score_at(t)` as a pure function of show time; the `show` stream (A2). No UI. | `check_show_script`: invariants I1 to I9 on 2,000 results; resolve stamps equal `Report.FEED_ORDER`; `score_at(75)` ties out with `Report.kda` and `res.final`; determinism; the A1 grep |
| A-02 | **Map view** | `ArenaMap`: the Wrenfell terrain from `arena_map.json` baked once into a texture (lake, island, plazas, lanes, pockets, camps, objectives, 8 towers a side, the Cairn), flipped so the player is always at the bottom; place and lane labels; camera (whole map, focus up to 1.3x) | Fit at 720 x 1280 and large text; flip test; perf rig (Xvfb) |
| A-03 | **Tokens and walks** | Ten hero tokens (teal circles yours, coral hexagons theirs, 36 px, role ring) moving along the graph per the stages and walk legs, reserve dots, minion waves as ambient dots; deaths and respawns from the kill ledger | Arrival against `arrive_by_s`; no two tokens overlap at rest; deterministic positions at any time t |
| A-04 | **Beats on screen** | Lane trades, jungle play, plan check banner, rotation, Stoneback, team fights, tower breaks and pushes, Moonhulk, reset, close push and the Cairn; effect cues by margin (2.2) from a small baked atlas; "against the odds" tag | Every resolve shows its winner at its stamp; no effect claims a kill the ledger did not count (H5) |
| A-05 | **HUD (numbers and feed)** | `ArenaHud.Board`: the scoreboard strip (banners with the side shape, clock, gold lead with the leader's shape, kills, towers, phase chip, the lead graph with objective markers and phase ticks); `ArenaHud.Feed`: newest result and the previous one dimmed (tick or cross, the contest name, size dots) and the end card, from existing copy. Glyphs from the arena's own texture | `check_arena_hud`: tie-out with the show script and `Report.kda` in both seats, feed lines at their stamps, end card, row A fit at 720 and 626 px with the league's longest name, text floor |
| A-06 | **Ending and the new Match screen** | The arena replaces the text feed in `ScreenMatch` (Quick mode, Skip, x2, pace log, tutorial game unchanged); end card (winner, arc line, "Decided by"); the three late-fight endings from the data with `held_island` as the provisional default and a tester switch in Settings | The guided-game walk still 0 fallbacks; Skip shows the final scoreboard; result and save identical to 0.7 for the same game (R7) |
| A-07 | **Copy, labels, help, comfort** | Arena copy through `merge_copy.py`: intent labels (the 156-line catalogue, 4.3), status tags (2.4), the plan row (plan chip and "If behind"), "Decided by" on the end card, the arena help sheet and tutorial step variant `watch.arena`; the text scheduler and word budget of UI-PASS-2 6.7.4 (moved here from A-05 in v1.1 because they need this copy); reduced motion, colour-blind and large text | check_copy rules (label 28 characters, tag 24); the 6.7.10 budget test (at most 10 new words in 2.5 s, 3 items at once, no feed line dropped); check_ui_help covers the arena sheet |
| A-08 | **Perf and acceptance** | Perf probe states for the arena (lanes, a fight, the end), idle and battery check, the full check, screenshot matrix of the arena in four variants looked at twice, APK, `docs/ALPHA-0.8-NOTES.md` | Full check exit 0; arena within the budget or a named exception |

## 4. Things this plan cannot settle

- How it feels and performs on a phone (frame time with ten moving tokens and effects; heat). The 0.7 phone test was fine for static screens only.
- The held-fight ending (tester scores, ARENA-MAP 7.3).
- Two requests to the Systems Designer stay out of 0.8 because they change the simulation (R1): `res.plans` in the result (the plan chip reads `App.gs.plan_set()`, which is correct for the managed club) and a kill rate tuned for a 75 s show (`docs/design/KILL-RATE-PROPOSAL.md`, awaiting tester scores). The arena shows the kills `Report.kda` already gives.
- Narrative owns commentary lines; 0.8 ships the vocabulary's intent labels and the short feed lines only, no caster sentences.
