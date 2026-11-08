# Kill rate proposal (S2) - display only

Author: Systems Designer. Date: 2026-11-08. Status: PROPOSAL, nothing in `game/src` is changed. Needs Lead Game Designer and QA & Balance sign-off before anyone builds it.

## 1. Why

`Report.kda` draws about 30 kills a game. The planned 75 s arena show (ACTION-VOCABULARY section 2.5, S2) would carry one kill every 2.5 s, and the most-killed hero dies about 7 times. Kills are a **display** number: the match result (`final`, `a_won`, the 8 contests) is decided before `Report.kda` runs and never reads it. The kill model in the simulator is not touched by this proposal.

## 2. Measured now

Method: a headless GDScript (`/tmp/claude-0/-home-claude/f6889c24-9ce5-5465-b345-99bece397d73/scratchpad/kill_measure.gd`, run with the Godot 4.3 binary from `game/`) that plays **2,000 real games** through `MatchRunner.auto` (the 10 default clubs, best lineups, AI drafts, neutral plans, save seed 8101) and calls the real `Report.kda`. `tools/sim_core.py` has no kill code, so it cannot measure this. Game length (`Report.game_minutes`): mean 13.55 min (9.00 to 16.00).

| Measure | Now (2,000 games) | Proposed (same 2,000 games) |
|---|---|---|
| Total kills per game, mean | 29.75 | 16.22 |
| Total kills, p10 / median / p90 | 24 / 30 / 35 | 13 / 16 / 19 |
| Total kills, min / max | 18 / 41 | 10 / 24 |
| Winner / loser kills, mean | 19.36 / 10.39 | 10.78 / 5.45 |
| Deaths of the most-killed hero: mean / median / p90 / max | 6.78 / 7 / 9 / 14 | 4.03 / 4 / 5 / 7 |
| Hero lines with 5 or more kills | 22.6% | 3.9% |

The "now" column agrees with the Gameplay Designer's 40,000-game Python prototype (winner 19.4, loser 10.6, about 30 total).

## 3. The retune (as suggested, plus two numbers I had to choose)

1. Total = `clamp(round(1.2 x game minutes + noise), 10, 26)`. Noise is Normal with standard deviation **1.5** (my choice; now 2.0 on 2.2 per minute; the Gameplay Designer gave none). The cap of 26 was never reached.
2. Soft per-hero cap: deaths of one hero at most `ceil(team deaths / 3) + 1`. I applied **the same cap to kills** (my addition, so one hero cannot take most of a 10 to 16 kill game). Caps always add up to at least the team total, so every kill is still handed out.
3. Kept as is: winner always has more kills, the winner's share rule (0.55 + 0.25 x dominance), lane-weighted kill and death weights, assists capped at `team kills - own kills`, own stream `kda`.

All rules the existing test checks (sums tie out, no negatives, nobody assists his own kill, winner has more kills) held on all 2,000 prototype games.

## 4. Who reads `Report.kda` (all display or record only)

| Consumer | Effect |
|---|---|
| `screen_report._lines` (the per-player lines) | Smaller numbers, same layout. |
| `Career.record_game` (`career.gd`): career and per-season K/D/A, `best_k`, the "best game" log | Totals grow about 45% slower. `NOTABLE_KILLS := 8` would almost never fire (0.0% of hero lines). **Needs 5** (3.9% of lines, close to today's 4.1% at 8). `career.gd` is not mine; request below. Existing saves keep old-rate totals and old `best_k` records, so old and new numbers mix; a new record may be hard to beat. |
| `player_view` K/D/A ratio ((k + a) / d) | About the same ratio, smaller counts. |
| Arena show scoreboard (planned, S3 `Report.story`) | The intended beneficiary: about 16 kills in 75 s. |
| Tests | `alpha6_tests.gd` `_kda`: "kills per game stay between 18 and 44" must become 10 to 26. The other `_kda` checks should still hold (winner share 66% is inside 55 to 85%); the "bot kills over 1.5 x sup" check is **not yet measured** with the caps. |

## 5. What must be re-run

- GDD 9.2 test 6 (derived statistics): `alpha6_tests.gd` `_kda` plus the career check in `_career_and_practice`, on the new code. Add a check that no hero exceeds the cap, and one that all 10 hero lines tie to the team totals.
- No calibration run is needed for win rates: `final`, `a_won` and the contests are produced by `MatchSim`/`GamePlan` and never see kills. Golden vectors (`sim_vectors.json`, `rng_vectors.json`) are unaffected. The `kda` stream is a separate substream, so no other draw moves.
- QA & Balance should still confirm the 40,000-game sample, because GDD 8.5 and the report wording ("big game") quote kill counts.

## 6. Recommendation

Approve the retune with `NOTABLE_KILLS` 5, as one change, together with S3 (the story ledger), so the arena and the report show the same numbers. It is about 15 lines in `Report.kda`. GDD wording (section 4.2 note: "a game has 18 to 44 kills") must change to "10 to 26".
