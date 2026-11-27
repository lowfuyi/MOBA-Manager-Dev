# Pending confirmation

Items that wait for the Founder: his recordings, his decision, or his approval to change the simulation. Nothing here is
started. Each item: why it waits, the options, and the Producer's recommendation. Newest additions at the end of section 2.

## 1. Part B of the Founder's queue of 2026-11-24 (parked by the Founder)

| Item | Why it waits | Options | Recommendation |
|---|---|---|---|
| P1 Diagonal map redesign | Needs the Founder's recording, a map concept, an IP re-screen and his sign-off. Founder decision already made: bases go diagonal (opposite corners). | Redraw only (sim graph and travel times unchanged) or redraw plus new travel distances | Redraw only, as `docs/design/MAP-DIAGONAL-FEASIBILITY.md` (Q3) lays out, so results and the golden vectors stay |
| P2 In-match HUD: full-width gold-lead bar, objective respawn timers on the map, per-lane gold difference between opposing rows, camera button in the top bar, bottom player panel | Needs the recording | Each piece separately, or one HUD pass | One HUD pass after the recording, measured against the arena draw-call budget |
| P3 New Game Plan choices (win condition, objective style, fight discipline, level-1 plan, "when behind" plan with a gold threshold), comeback levers (`COMEBACK-PROPOSAL.md`), pre-match Team Talk | They change the simulation: need the Founder's approval and the Q2b sweep first | Approve one at a time with a sweep each, or none for now | Read the Q2b sweep first; add choices only with a measured effect inside +3 points |
| P4 Condition and fatigue gating training, hidden per-attribute potential with scouted estimates, hero difficulty affecting results | Gameplay changes; Founder decision | Yes, no, or later | Later: after the scouting summary (Q4-2) has been seen by testers |
| P5 Sponsors with missions, manager level and talents, extra tournament formats (Swiss, double elimination) | Founder decision | - | After Beta scope is set |
| P6 Linked cloud save, remote balance data, Steam, monetisation | Beta items | - | Beta |
| P7 AI-vs-AI on Match Sim v2 after a phone measurement; art route; trademark search; release keys; iOS | Founder's own items | - | See `docs/MORNING-REPORT.md` section 5 |

## 2. Raised during the run (Producer)

| Item | Why it waits | Options | Recommendation |
|---|---|---|---|
| Q4-2 player labels and multi-sort | The audit (Q1) found them not cheap: a label store per player and a sort editor | Build later as one increment, or drop | Later, after testers see the scouting summary |
| Q4-6 prize leaderboard for all clubs | Other clubs' prize money is not kept anywhere; it needs a new per-club save record and season-end logic, not "existing career data" | Add the record (additive save key) in a later increment, or show only your own prize history | Add it with the next season-end work |
| Q4-9 saved draft plan per opponent | More than one increment: a plan editor, a save key, and auto-draft logic that follows it | Build it as its own small milestone, or keep using Auto-finish | Own milestone after the diagonal map |
| Next version number | The queue names Q5 "0.12.1 (code 20)", but 0.12.1 already went to the web on 2026-11-24 (large-text fixes) | Re-use 0.12.1, or call Q5 0.12.2 | 0.12.2 (code 20), so testers never see two different builds with one number. Applied in Q5 unless the Founder says otherwise |
| Q2b Game Plan options above +3 points (report only, nothing tuned) | Four settings beat a neutral plan by more than 3 points on equal teams, 2,000 paired games each (error about 1.3 points): Lane aggression full + Jungle focus Bot +5.5; every control at full +4.0; Mid-game objectives at minimum +3.7; Fight style full + Tempo full +3.4. Two are near the noise line; no combination dominates the best single option. Details in docs/design/Q2-ANALYSIS.md section b | (1) leave as is; (2) soften the jungle-to-Bot bonus when lane aggression is high and re-check; (3) re-run the sweep with 6,000 games a setting first | (3) then (2) if the first two still clear +3: tuning changes the simulation and needs your approval |
| Q2a heroes outside 45-55% in a lane | 23 / 25 / 31 hero-lane pairs (1 / 3 / 5 bans) are outside the band; most are heroes played away from their usual lane (e.g. Sunnivah in Bot about 31%), a few in their main lane (Embrel Top about 61-63%, Hegwin Mid about 59-60%, Vellgrim Support 56-59%) | (1) tune the main-lane outliers only; (2) also stop the AI from drafting heroes into lanes where they lose; (3) leave for now | (1) and (2), as one balance increment after your approval (simulation change) |

## 3. Raised in the run of 2026-11-27 (queue `docs/design/QUEUE-2026-11-27.md`)

| Item | Why it waits | Options | Recommendation |
|---|---|---|---|
| R3 diagonal map concept | Founder's choice, then his recordings, the IP Checker's screen and sign-off (P1) | c1 "Corner roads", c2 "Long bows", c3 "Winding causeway" (`docs/design/MAP-DIAGONAL-CONCEPTS.md`, pictures in `docs/design/art/arena-map-diagonal-*.png`) | c3: our own S-shaped causeway, the objectives fair but not a mirror pair, and all lanes look the same speed (no replay factor) |
| R4 HUD ideas (P2) | Need the recording; one needs a simulation change | Camera button in the Board, gold-lead bar, respawn countdowns, level badge (all display only); lane gold as a sheet; no ability chips (our heroes have no ability ranks) (`docs/design/ARENA-HUD-2.md`) | Build the four display-only parts after the recording, camera button first (+about 100 px of arena) |
| Per-player gold in the game log | The lane gold sheet (R4 2.3) needs gold per player over time; the log has team gold only. Adding it is an additive log field written by `src/sim/`, so the golden vectors' log hash changes: outside the R2 approval | Approve with the next simulation change, or drop the lane gold idea | Approve together with the next approved sim change, so the golden vectors are re-recorded once |

## 4. Raised in the Match Day run (queue `docs/design/QUEUE-MATCH-DAY.md`)

| Item | Why it waits | Options | Recommendation |
|---|---|---|---|
| M3 map concept | Founder's pick (d1, d2 or d3, `MAP-RIVER-CONCEPTS.md`); M9 waits for it | d1 River cross (IP Checker: Change), d2 Bending river (Watch medium), d3 Wrenfell water (Watch low) | d3, or the IP Checker's d2/d3 mix |
| Line-up panel rows below the 96 px floor (DECISIONS H-9) | The rows are 60 px; ruled a display, one tap target for the whole panel | Confirm, or ask for bigger rows (the arena gets shorter) | Confirm |
| Caster names Rosco and Imogen | Narrative Designer's placeholders; name and trademark search owed before release | Keep, or choose others | Keep for the alpha |
| How loud the commentary is | About 56 lines a game, a line on screen almost all the time | Keep, thin it (more calm gaps), or a setting | Keep for the phone test; decide after testers |
