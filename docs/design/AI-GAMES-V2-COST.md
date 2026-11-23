# AI-vs-AI games on Match Sim v2: cost (overnight Q7, 2026-11-24)

Founder queue Q7: prepare, but do not enable, the switch that plays AI-vs-AI games (league fixtures and playoff series without the player) with Match Sim v2 instead of the v1 contest model. **The switch stays off** (`"ai_games_v2": false` in `game/data/sim_v2_params.json`). Turning it on is one data change plus a re-run of the season checks.

## What is ready

- `MatchRunner.auto_ai` already routes on the switch (MATCH-SIM-V2-DESIGN 16, ruling S-B-2). Both models return the same fields the season code reads (`final`, the signed margin for Blue, and `blue_won`), so standings, ratings and playoff series need no change.
- New test `game/tests/ai_switch_tests.gd`: the switch is in the data and off; with it off, AI games come from v1; with it on, from v2 (results carry `v` and the v2 log), with the same `final` and `blue_won` contract; the test leaves it off.

## Cost (desktop, headless, one process; not a phone)

`probe_ai.gd`, 60 AI games each with real AI drafts (5 bans, league format), the default world's clubs:

| Model | Mean | Median | 90th percentile | Max |
|---|---|---|---|---|
| v1 (today) | 22 ms | 18 ms | 42 ms | 66 ms |
| Match Sim v2 | 226 ms | 227 ms | 269 ms | 320 ms |

About **10 times the cost per game** (about +205 ms each on this desktop).

**Per season.** A season has 90 league games in 18 rounds; 72 are AI-vs-AI (4 a round), plus the playoff series without the player.
- Per round: 4 x 227 ms = **about 0.9 s on this desktop** (v1: about 0.09 s).
- Per league season: 72 x 227 ms = **about 16 s on this desktop** (v1: about 1.6 s), spread over the 18 rounds.
- On a phone: not measured. If a mid-range Android phone is 3 to 5 times slower than this desktop (a guess, not a measurement), a round would add **about 3 to 5 s** after the player's own game. That is noticeable, because today the step after a game feels instant.

## Before turning it on (recommendation)

1. Measure on the Founder's phone first. The Q1 tester timings show the game start (one v2 game plus the screen) in the feedback note, which gives the phone-to-desktop ratio.
2. If a round costs more than about 1 s on the phone, run the 4 AI games of a round during the player's own match (spread over frames while the arena plays: about 1 game per 15 s of watching), so the round ends with no wait. That is a contained change in `GameState` and does not touch the sim.
3. Re-run the season checks (title concentration, soak) with the switch on, because v2 upsets differ from v1.

Owner of the decision: the Founder (it changes how the league plays out). Nothing here changes a result while the switch is off.
