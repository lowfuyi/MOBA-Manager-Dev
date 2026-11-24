# Morning report: ESMO-lessons queue, night of 2026-11-24 to 25

The queue (Q0 to Q5, `docs/design/ESMO-LESSONS.md`) ran unattended. Every increment was its own commit, run through the fast gate (ALL GREEN) and pushed. No change was made to `src/sim/`, and the golden hash is unchanged. **Nothing here was measured on a physical phone.** The previous morning report (0.12.0) is in git history.

## 1. Done

| Item | What | Commit |
|---|---|---|
| Q0 | Housekeeping: queue saved, PENDING-CONFIRMATION, diagonal-map decision logged, tester-note format | (before the night) |
| Q1 | Audit of every idea: HAVE, PARTIAL or MISSING, with files and effort (`docs/design/ESMO-AUDIT.md`) | 4621282 |
| Q2 | Read-only analyses a to d (`docs/design/Q2-ANALYSIS.md`) and `game/data/hero_matchups_v1.json` | 47f1443 |
| Q3 | Diagonal-map feasibility note (`docs/design/MAP-DIAGONAL-FEASIBILITY.md`). Recommends a display-only warp, effort L; map not edited | 330621e |
| Q4-1 | Role fit per lane on the Squad card, plus "to play X better, train A and B"; the lane picker chip shows the fit % | 0ac9744 |
| Q4-2 | Scouting summary: grade A to D, one-line note, up to 2 pros and 2 cons. Shown on Negotiation and the Squad card; grade on free-agent rows | 9d29413 |
| Q4-3 | A contract refusal shows what the player weighs (offer vs market value, personality, length); the decision itself is unchanged | a7ddd6b |
| Q4-4 | Report card: why the Form Rating moved, from the real inputs only (additive save key `rate_last`) | fe1c130 |
| Q4-5 | Finance: chart of the last 8 rounds and this season by category, from the existing ledger | 6b10923 |
| Q4-6 | Career tab: achievements and club records | 1ed7921 |
| Q4-7 | Home: "Play the rest of the league", with a confirm sheet and one result line. Hidden while the first-run guide or a lesson runs | 631a1c1 |
| Q4-8 | Hero pages: "Harder against" (up to 3 heroes, from Q2d), with the sample size; informational only | 72aecf1 |
| Q5 | Release 0.12.2 (code 20): see section 6 | 630545d, plus this report |

## 2. Skipped, parked or BLOCKED

- **BLOCKED:** none.
- **Two tries:**
  - Q4-4: the first card broke the Report node baseline; it is now one panel and one label.
  - Q4-7: the first button broke the guided first-run walk (24 fallbacks); it now waits until the guide is answered.
  - The Q2 run stopped once on its chunk time limit and was re-run.
- **Parked**, details in `docs/PENDING-CONFIRMATION.md`:
  - Q4-9 saved draft plan per opponent: more than one increment.
  - Q4-2 player labels and multi-sort.
  - Q4-6 prize leaderboard: other clubs keep no prize record.
- **Not built where nothing real exists:** role fit on Draft and Game Plan, because neither sets roles. Q4-7 has nothing to "claim", because prizes and sponsor money are already paid automatically.
- **Part B (P1 to P7):** untouched, as you asked.

## 3. Q2 numbers (desktop simulation, equal teams, real AI drafts)

**a) Hero by lane.** 40,000 games per format; a hero counts in a lane with 300+ games there.

| Bans a side | Hero-lane pairs used | Outside 45–55% |
|---|---|---|
| 1 | 83 | 23 |
| 3 | 91 | 25 |
| 5 | 104 | 31 |

- Most of the outliers are heroes played away from their usual lane. Sunnivah in Bot sits at about 31%.
- Main-lane outliers:
  - Embrel in Top: 61–63%.
  - Hegwin in Mid: about 59–60%.
  - Vellgrim in Support: 56–59%.
  - Gravenstone in Top: 42–43%.
  - Corvane in Jungle: 41–43%.

**b) Game Plan sweep.** 2,000 paired games per setting; error about ±1.3 points. Four settings beat a neutral plan by more than +3 points:

| Setting | Gain over neutral |
|---|---|
| Lane aggression full + Jungle focus Bot | +5.5 |
| Every control at full | +4.0 |
| Mid-game objectives at minimum | +3.7 |
| Fight style full + Tempo full | +3.4 |

- No combination dominates the best single option.
- The weakest setting is Fight style and Risk both at minimum: −5.8.
- Nothing was tuned.

**c) Does the draft decide too much?** Draft score is the side's mean phase rating with its real heroes, divided by the same players with a plain hero, times the composition bonus.

| Bans a side | Better draft wins | …when its players are weaker (gap 2+) |
|---|---|---|
| 1 | 56.5% | 26.7% |
| 3 | 57.8% | 28.1% |
| 5 | 58.1% | 26.5% |

So the players still matter more than the draft.

**d) Matchup table.** Built from 120,000 games. 38 of 40 heroes have at least one "struggles against" entry. The bar for an entry is at least 400 games for the pair, 3+ points below the hero's own rate, and z ≤ −2.5.

## 4. Phone test list (0.12.2)

1. **Squad.** Open a player card, Stats tab. Do the lane fit and the "train A and B" line make sense? Is the picker chip readable?
2. **Club → Free agents.** Is the grade on each row readable? Open one: do the note and the pros and cons help?
3. **Contracts.** Offer a low wage and get refused. Do the reasons read fairly?
4. **Report after a league game.** Is the Form Rating card clear or too technical?
5. **Club → Finance**, after a few games. Is the chart readable at phone size?
6. **Career tab** of a long-serving player: achievements and records.
7. **Home, late in a season.** Use "Play the rest of the league". Is the confirm text clear? How long did it take on the phone?
8. **Plan → Heroes → any hero.** Is the "Harder against" line useful, or noise?
9. **Large text.** Repeat steps 1, 2 and 8.

## 5. Your decisions

1. **Q2b Game Plan flags:** leave them, re-measure with 6,000 games, or soften "jungle to Bot with full lane aggression". Any tuning changes the simulation and needs your approval.
2. **Q2a lane outliers:** tune the main-lane outliers (Embrel Top, Hegwin Mid, Vellgrim Support, Gravenstone Top, Corvane Jungle), and/or stop the AI drafting heroes into lanes where they lose.
3. **Parked items:**
   - Q4-9 saved draft plan: its own milestone after the diagonal map?
   - Q4-2 labels and multi-sort.
   - Q4-6 prize leaderboard.
4. **Version number:** Q5 shipped as **0.12.2 (code 20)** instead of 0.12.1, because 0.12.1 was already on the web. Say if you want it otherwise.
5. **Still open from before:**
   - art route;
   - trademark search;
   - release key;
   - iOS;
   - comeback target;
   - AI games on v2;
   - the diagonal map (P1, waiting for your recordings).

## 6. Release 0.12.2

- **Full gate** (`tools/run_all_checks.sh`): exit 0, with no allowance raised.
  - 2,698 logic checks, all screen and touch scenes.
  - Save compat: 219 checks.
  - Soak: 6 seasons, 1,176 checks.
  - Golden vectors unchanged.
  - check_art: 7 + 37 checks.
  - Perf: 49 states, 0 failures (9 over a target and under the hard limit, as before).
  - The fast gate also showed ALL GREEN on the same tree.
- **APK:** `build/gloamline-0.12.2-alpha.apk`, 25.5 MB, versionCode 20, versionName 0.12.2-alpha.
  - Signed with the debug key; apksigner verified it.
  - Copied to `C:\Users\Fuyi\Downloads\gloamline-0.12.2-alpha.apk`. C: had 20 GB free before the build.
- **Web:** https://gloamline-playtest.vercel.app, build `0.12.2-alpha-web-630545d-20261124-2200`.
  - Before the deploy, the Playwright flow passed on a local server: title to report, with 5 bans, 5 picks and a full match. 0 errors; the new Form Rating card showed on the Report.
  - `vercel whoami` printed lowfuyi-1301.
  - Live checks: `/build.txt` returns the build id; the `x-robots-tag: noindex, nofollow, noarchive` header is present; the title screen shows "Version 0.12.2 alpha" with 0 errors (desktop Chromium, phone viewport).
- **Tester note:** `docs/TESTER-UPDATES.md`, 0.12.2. Saves carry over, because save compat passed.
- **Not measured on a phone.** The web run's "arena frame" times come from software WebGL in a headless browser on this machine; they are not a phone reading.
