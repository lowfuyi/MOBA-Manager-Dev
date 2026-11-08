# Alpha exit checklist

Purpose: the gate between Alpha (founder-only testing, features still being added) and Beta (feature-complete for the agreed scope, rules frozen apart from balance fixes, outside testers). Proposed by the Producer on 2026-11-08, approved by the Founder to be built and worked through the same day. Numbers marked "proposed" are the Producer's suggestions and the Founder may change them.

**Rule.** Alpha ends when every item in groups 1 to 5 is Done and the Founder signs. Group 6 must be Done before the first outside tester joins. Group 7 may run in early Beta but must be Done before launch.

Status words: **Done** (evidence given), **Partly**, **Not started**, **Founder** (only the Founder can do or judge it), **Phone** (needs a real phone, cannot be measured on a computer).

Last updated: 2026-11-08 (end of Alpha 0.6 work).

**Where it stands.** Everything that can be finished and proven on a computer is Done: groups 1 and 3 completely, the computer side of group 2, and the build work of group 6. What is left for the end of Alpha needs a real phone or the Founder: 2.5 (seasons played on phones), 3.7 and 4.1 to 4.4 (the pace log and a first-time player), and 5.1 to 5.3 (phone performance). Group 6 still needs 6.4 and 6.5 from the Founder before the first outside tester, and group 7 waits for a chosen name (7.1) and the later reviews.

## 1. Feature-complete for Phase 1 (GDD section 12)

| ID | Item | Status | Evidence or next step |
|---|---|---|---|
| 1.1 | Single-player league: club pick, lineup, draft, live feed, report, season, playoffs | Done | Alpha 0.1; UI smoke plays whole seasons |
| 1.2 | Game Plan (7.8) | Done | Alpha 0.2; QA 9.2.1 |
| 1.3 | Training, fatigue, ageing (7.3) | Done | Alpha 0.2 |
| 1.4 | Recruitment, contracts, finance, sponsor, dismissal (7.2, 7.6) | Done | Alpha 0.3 |
| 1.5 | Team Bonds, chemistry, Form, Morale, scrim (7.7, 8.6) | Done | Alpha 0.4 |
| 1.6 | Exhibition and Quick Match (7.9) | Done | Alpha 0.6: Plan tab -> Practice matches; Quick Match, best of 1, 3 or 5; no effect on table, Form Rating, Form, Morale, sponsor or career; +5 fatigue and +2 bond per game; one series per match day. Unit tests and a full practice series through the real screens in the UI smoke test |
| 1.7 | Player career log (4.2, 12) | Done | Alpha 0.6: "Career with us" on each player card (games, wins, kills/deaths/assists, KDA ratio, best game, this season, last milestones) and a "Player lines" section in every game report. KDA is display only and passes the consistency tests (winner has more kills, kills equal deaths on the other side, no self-assists, 18 to 44 kills a game) |
| 1.8 | Per-stat Potential and stat help sheets (4.2) | Done, simplified | Potential per stat was already shown. Alpha 0.6: tap any stat row on a player card for a one-line help. The GDD asked for two lines and sheets for Morale, Fatigue and Personality too; the player card already explains those in place, so they are not separate sheets (recorded in GDD 4.2 notes) |
| 1.9 | Form Rating (Elo) and trophy cabinet (10.1) | Done | Alpha 0.6: Form column and ranking in Standings, tile on the Club tab, trophy cabinet (every season with rank, record, playoff result and prize money, plus totals). Ratings are zero-sum and follow strength (Spearman above 0.6 in the unit test). Medals are not built |
| 1.10 | Scope freeze: nothing outside GDD section 12 (no transfers, manager level, multi-tier leagues, animated map) enters Beta without a Founder decision | Done by rule | GDD 12, WORKFLOW.md gate |

## 2. Stability

| ID | Item | Status | Evidence or next step |
|---|---|---|---|
| 2.1 | All automated checks pass (data, strings, Python tests, calibration, logic, UI smoke, touch) | Done | Alpha 0.6 full run: 1,794 logic checks, 220 UI smoke checks, 50 touch checks, 48 Python tests, data and strings checks, calibration 0 out of band at 40,000 matches per row, short soak 1,176 invariant checks. All pass |
| 2.2 | No known crash or save-loss bug | Done on the computer | None known; 125-season soak clean (2.4). Phone sessions (2.5) can still find device-only problems |
| 2.3 | Older saves still open after each update (migration tested) | Done for 0.6 | Unit tests open a save without any 0.6 key (Form Ratings, career, practice) and play on; repeat for every new field |
| 2.4 | Headless soak: at least 20 full seasons on varied seeds, all features, no engine error, no invalid state | Done | `game/tests/soak.gd`: 5 clubs x 25 seasons = 125 seasons with random training, lineup, Game Plan, practice, signing, release and renewal choices and a save round trip every season: 25,654 invariant checks, 0 failures, about 3.6 s a season. A short version (3 seasons x 2 clubs) is part of `tools/run_all_checks.sh` |
| 2.5 | At least 5 full seasons played on real phones without a crash (3 by the Founder, proposed) | Phone, Founder | Needs the Founder's play |

## 3. Balance

| ID | Item | Status | Evidence or next step |
|---|---|---|---|
| 3.1 | Section 9 contest targets met | Done | `tools/calibrate.py`, 0 out of band |
| 3.2 | Full pipeline (draft, fit, HeroFactor) calibrated | Done | CALIBRATION-9.1 |
| 3.3 | Calibration repeated at Phase 1 rating scale (about 45) | Done | `tools/calibrate.py --base=45`: 0 of 18 out of band; two rows at the lower edge (CALIBRATION-9.1 addendum) |
| 3.4 | Game Plan joint test rerun with chemistry (9.2.1) | Done, with a ruling | Mean joint gain +0.75; the maximum +4.30 is the single 10 percent underdog matchup (same as Alpha 0.2); balanced matchups gain 0.0 to 0.5. The 3-point limit is read as applying within 30 rating points. Producer decision, Founder may overrule |
| 3.5 | Multi-season run with bonds, form and morale: strength still predicts results, no runaway club | Done | Spearman 0.81 on 20 splits, same as the old model; ten-season runs and the soak show no runaway club (CALIBRATION-9.1 addendum) |
| 3.6 | 10-season economy run: no bankruptcy for sensible play, no snowball | Done, two observations | 0 of 10 dismissed for passive and sensible active play; the Win Bonus all-in gamble loses 5 of 10. Observations for play-testers: titles concentrate in the two strongest clubs, and cash piles up at the top because AI clubs have nothing to spend on |
| 3.7 | Match length: average game about 5 minutes or less including the draft | Partly | 75-second watch window in 0.5; Phone data from the pace log needed |

## 4. Ease of use (needs real play)

| ID | Item | Status | Evidence or next step |
|---|---|---|---|
| 4.1 | A new player finishes a first game and a first season without asking for help | Phone, Founder | Test with someone who has not seen the game |
| 4.2 | Pace log: median total time per game about 5 minutes or less; fewer than half of live feeds skipped | Phone, Founder | Settings -> Pace log |
| 4.3 | A non-developer can say why they lost from the result screen (GDD exit criterion) | Partly | Payoff screen and "why" section built in 0.5; needs a person to judge |
| 4.4 | No screen the Founder could not work out | Phone, Founder | Alpha 0.5 questions in ALPHA-0.5-NOTES |

## 5. Phone performance

| ID | Item | Status | Evidence or next step |
|---|---|---|---|
| 5.1 | Smooth on 2 to 3 different Android phones, one of them low-end | Phone | Founder's phone plus borrowed phones |
| 5.2 | No long loading; start-up time recorded | Phone | Done on the computer side: Debug info now shows start-up time (to the first screen) and memory. The numbers that matter come from a phone |
| 5.3 | No overheating or heavy battery drain in a 30-minute session | Phone | Founder |

## 6. Ready for outside testers

| ID | Item | Status | Evidence or next step |
|---|---|---|---|
| 6.1 | First-game tutorial that can be dismissed | Done, light version | Three one-time tips (Home, before a game, after a game), each dismissed with one tap and remembered on the device; Settings can show them again. A step-by-step guided first game is not built; add it if testers still get lost |
| 6.2 | Text size option and colour-blind-safe option | Done | Settings -> Comfort: larger text and buttons (+15 percent, every screen tested to fit the narrower layout), colour-blind friendly colours (blue and orange for good and bad). Not yet tried by a colour-blind person |
| 6.3 | Privacy line in the app (nothing leaves the phone in Alpha) and a simple feedback route | Done | Settings shows a privacy line and a "Copy feedback note" button (a short template plus the debug lines). The note says to send it to "whoever gave you this build": the contact for outside testers is the Alpha feedback form (see ALPHA-FEEDBACK-FORM.md); the Founder runs the script once to create it, then sends the link with the APK |
| 6.4 | Closed-beta distribution set up (Play Console closed track or direct APK) | Founder | Needs a developer account decision |
| 6.5 | Signed with a proper release key (debug key must never ship) | Founder | Key kept by the Founder |

## 7. Legal and content (before launch)

| ID | Item | Status | Evidence or next step |
|---|---|---|---|
| 7.1 | Game-name and trademark search | Not started | Needs a chosen name first (Founder) |
| 7.2 | IP check of hero, player and club names | Partly | Block list and IP-RISK-LOG exist; final names are still placeholders |
| 7.3 | Second independent review of the design document (v1.4 to latest) | Not started | A fresh reviewer with no sight of how it was written |
| 7.4 | Store policy review (age rating, data, monetization) | Not started | Before the first store upload |

## Sign-off

Alpha ends on: ______ (Founder). Open exceptions the Founder accepts: ______
