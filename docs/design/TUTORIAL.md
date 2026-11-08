# Guided tutorial and in-context help (workstream W1)

Version: spec v1.1 (wave 1b reconciliation) · Date: 2026-11-08 · Author: UI/UX Designer · Status: design for the Founder checkpoint. **Nothing here is built or run.** It answers the Founder's feedback 2 ("Game Tutorial is close to non-existent ... users will need us to explain and guide them") in `docs/ALPHA-0.7-PLAN.md`.

Read with: `docs/design/UI-PASS-2.md` (the layout redesign). v1 was written 8 minutes before UI-PASS-2 was finished; v1.1 matches the final layouts. This spec points at controls by **stable ids**, not by position, so the layout can change under it. Section 8 lists the ids the programmers must add.

**What changed in v1.1** (review `company/reviews/2026-11-08-wave1.md`, conflicts C1, C2, C3, C11 and section 8):

| Area | Change |
|---|---|
| Helper name | "advisor" is gone. The helper is **Coach** everywhere (steps, help, glossary, strings). Section 13 lists the game strings that must change. |
| Squad (C3) | Steps 5 and 6 use a **bench card** (`squad.bench.0`) and the player sheet. The lane picker is a variant (5-B), not the default. Lesson L3 ids changed. |
| Draft (C11) | Steps 12 to 14 follow the new hero sheet; step 15 arms then confirms; **step 17** Coach opens a diff sheet then Apply. Each still has a one-tap route (section 3.2a). |
| Report (C11) | Step 22 is now a tap on the hero stat, then Next closes the factor sheet. |
| Standings (C2) | Three views plus a Points / Form switch. Steps 25 and 26, lesson L1 and the help row follow it. Step 26 is now a tap on the switch. |
| Overlay | Draws **above** `BottomSheet` (own canvas layer). Sheet steps use a compact card. |
| Numbers (C1) | Body 32, Small 26, Caption 24 (floor), card radius 24, from UI-PASS-2 2.2. Anything the Art Director may still change is marked "per ART-BIBLE token table". |
| Counts | Do-steps 20 of 27 (was 18), info 5 (was 7), modal 2; first-run ids 27 (was 25); glossary 49 terms (was 48, adds Coach); tests 20 (was 18). |

What it replaces: three dismissible one-time tips (`Tips.show` for Home, Pre-match and Report). They never point at anything and cannot be replayed except as a block.

## 0. The answer in ten lines

1. **One guided first game of 27 steps** (about 5 to 6 minutes, estimate only, not measured): Home, the five tabs, Squad and a player card, Practice, Pre-match, Draft (ban, pick, role, Coach), Game Plan, watching, the report and "why it went this way", Standings and Form Rating.
2. The game it teaches on is a **tutorial-flagged Quick Match** (the practice machinery that already exists, with its small costs removed). It cannot touch the table, Form Rating, Form, Morale, bonds, fatigue, cash, sponsor, career, plan or pace log. Section 2.
3. A **coach overlay** dims the screen, leaves a hole around the real control, and waits for the player to tap it. Three quarters of the steps (20 of 27) are do-steps that finish when the player does the real thing. Where the real thing takes two taps (a sheet, a "Sure?"), the card offers a one-tap route (section 3.2a).
4. **Skip** is on every card: one tap, with an Undo toast. Android back asks first. Returning players and old saves are never forced into it.
5. **Eight short optional lessons** (2 to 5 steps each, about a minute) cover what the first game leaves out: league table, training and rest, contracts, chemistry, Game Plan in depth, money, free agents, "what a game changed". They are offered once when they become useful, never auto-started.
6. A **"?" on every screen** opens a short sheet (what you see, what to do, good to know, and the words on that screen). A **glossary** of 49 terms sits behind it and in Settings.
7. Progress is stored in the **save** (so a new save gets its own offer) and the **device** (so a returning player is not nagged). Old saves are treated as "already know the game".
8. Replay, lessons and glossary live in a new **Help and learning** card at the top of Settings.
9. Every animation is 250 ms or less; nothing loops; "Animations off" makes everything instant.
10. QA can script a full run, a skip at every step, a tap-elsewhere run at every step, a one-tap audit and a large-text run (section 9). Build is about 19 programmer days in three milestones (section 10); v1.1 adds about half a day for sheet steps (inside B2 and B3), not re-estimated by the programmers.

## 1. Principles

1. **Learn by doing.** At least two steps in three finish when the player taps the real control (20 of 27 here). The rest are one-line explanations with a Next button, and none of them comes before the player has seen the thing.
2. **One idea per step.** 25 words or fewer, plain friendly English, no colour words (colour-blind mode swaps green and red for blue and orange), no jargon that the glossary does not define. Coach text uses the exact on-screen label ("Coach", "Auto-finish", "Start draft"). The helper in the text is always **Coach** (section 13).
3. **Always skippable, never more than one tap.** "Skip tutorial" is on every card, one tap, never hidden behind a menu. No step needs more than one tap to continue or skip: a do-step's real control takes one tap, and where the real flow takes two (a hero sheet, "Sure?", Apply) the card carries a one-tap route (section 3.2a). After a skip a toast says where to replay it and offers Undo for 4.5 seconds (the same pattern the Training screen already uses).
4. **Never blocks a returning player.** A save from before this alpha never starts a tutorial by itself. A player who already finished or skipped it on this device sees an inline offer card, never a full-screen welcome. Lessons are offers, never auto-starts.
5. **Works in large-text mode** (+15 percent, `content_scale_factor` 1.15, so the logical screen is about 626 px wide). The card is built from the live viewport size, never from 720 x 1280 constants; text is never below 24 px (the Caption floor, UI-PASS-2 2.2); the card never covers more than 45 percent of the screen height (35 percent on sheet steps); targets scroll into view.
6. **Nothing real is changed.** The tutorial game, the plan it edits, and every lesson step are sandboxed or read-only. A lesson step may open things but never confirms a deal, releases a player or changes a training focus.
7. **Honest about luck.** We do not rig the game. The only lever is choosing a tutorial opponent that is not stronger than the player, and the texts work for a win and for a loss.
8. **Calm.** No animation over 250 ms, no looping animation, nothing that moves while the player reads. Respects Settings, Animations.
9. **It cannot get stuck.** If a target is missing the card still appears (without a hole, with Next). If anything goes wrong the exit is always one tap away.
10. **Local only.** Progress is kept on the device and in the save. Nothing is sent anywhere (Settings, Privacy says so). Drop-off data for testers goes into the existing "Copy debug info" text.

## 2. The tutorial game

### 2.1 What it must do

Teach the whole loop on a real game (Pre-match, Draft, Game Plan, Watch, Report) without changing the season, and be replayable at any time.

### 2.2 Facts from the code that shape the choice

(from `screen_practice.gd`, `game_state.gd`, `screen_report.gd`, `screen_match.gd`, GDD 7.9; not run)

- A practice game goes through the same screens as a league game: Pre-match, Draft (always the short draft: 1 ban, 5 picks, 10 s timer), Game Plan, Match, Report. It never changes the table, Form Rating, Form, Morale, sponsor goals, career or history.
- It is **not** free: each starter gets +5 fatigue, each pair of starters +2 bond, the starters get no training or rest that day (`exh_busy`), and only one practice series is allowed per match day (`exh_day`). It only works in the league phase.
- Its report has no "what this game changed" card and no tip (`_practice_card()` replaces them), so it cannot teach the payoff card. That becomes lesson 8, taught after the first real game.
- The Game Plan screen edits the **real** saved plan (`gs.plan_set()`), so tapping Coach and then Apply in a practice game would change the plan for the next league game. This is a hidden pollution a plain "use practice" answer misses.
- `ScreenMatch` returns at once if Quick mode is on (Settings), and the draft timer keeps running while a card would be on screen. A tutorial must override both.
- `ScreenMatch._continue` writes every game, practice included, into the pace log. A tutorial game should not.
- The real Quick Match opponent is random within 5 rating points, so the first game could be a hard one.

### 2.3 Options compared

| | A. Practice Quick Match as it is | **A+. Practice Quick Match, tutorial-flagged (recommended)** | B. The real first league game, with coaching | C. A bespoke scripted tutorial game |
|---|---|---|---|---|
| Season pollution | Small: +5 fatigue, +2 bond, day's training lost, plan edits stick | **None** (flagged game skips all of it, sandbox plan) | Full: a guided game decides rank, Form Rating, morale; a coached loss on day one feels bad | None |
| Replay later | Only in the league phase, once per match day | **Any time, any phase** | Impossible without a new save | Any time |
| Learning transfers to real play | Yes: same screens | **Yes: same screens, same code** | Yes | Partly: a special path can differ from the real one |
| Shows the payoff card | No | No (lesson 8 does) | Yes | Could |
| Build cost | None | **Small to medium** (about 3 days: flag, opponent rule, sandbox plan, switches) | Small, but coach logic must cope with real stakes | Large: new game mode, new opponent data, new tests |
| Test cost | Low | **Low** (seed pinned, no state to diff) | High (outcome changes the season) | High |
| Honesty about luck | Yes | **Yes** | Yes | Weak: a "scripted win" teaches the wrong lesson |
| Risk | The first impression is "my starters are tired and my plan changed and I did not touch anything" | Slightly different from a real Quick Match (no fatigue) which the practice intro text explains | New players face a real loss with a coach in their ear | Two code paths to keep honest |

### 2.4 Recommendation: A+ (tutorial-flagged Quick Match)

Reasons: it is the only option that is both **safe** (nothing counts) and **real** (the same screens and rules the player will meet next), and it can be replayed. It also keeps the Founder's own sentence true on screen: "Practice games never count".

The tutorial game is a normal practice game with `tutorial: true` and these rules (for the Gameplay Programmer and Lead Game Designer):

1. **Built on the practice path**: `kind` stays `"exhibition"` (so Report and Pre-match already treat it as practice), short draft, one game.
2. **No side effects**: none of these may change: `EXH_FATIGUE`, `EXH_BOND`, `exh_day`, `exh_busy`, `exh_n`, the pace log, familiarity, history, career, Form Rating. It stores nothing in `d["exh"]`, so there is no half-finished series to resume.
3. **Any time**: it ignores `practice_available()` and the league-phase rule. In tutorial mode the Practice screen shows only a Quick Match card (labelled as in the real one) and hides Exhibition.
4. **Sandbox plan**: while a tutorial game is live, `gs.plan_set()` returns a private copy (`d["tutorial"]["game"]["plan"]`, starts neutral). The real plan is never touched. The copy is dropped when the game is left, when the tutorial is skipped, or on load.
5. **Opponent rule**: the club with the highest Team Rating that is **not above ours**; if every club is above ours, the nearest one above. This is fairness, not a rigged result: the simulation, draft and luck run as normal. A loss is possible, and the report text for a loss is written to be useful (step 21).
6. **Seed**: its own stream `tut:<save seed>:<n>`, independent of every league game. `n` is the replay count, so a replay is a different game; tests pin `n` so scripted runs are repeatable.
7. **Switches while it is live**: Quick mode (Settings) is ignored so the player sees a real watch; the draft timer is off (the draft head says "No timer in the tutorial"); the "Auto-play this game" buttons are outside every hole so they cannot be tapped.
8. **Report card**: the practice card is replaced by "Practice result: nothing in your season changed. This game was only for learning." (`tut.report_card.*`).

**Fallback if the schedule is tight (A-minimal):** ship the tutorial on the real Quick Match exactly as it is and say its costs out loud in the Practice text (it already does). Cuts about 2 of the 3 days, but gives the polluted first impression above and no replay on the same day. Recommended only as a stop-gap.

**Why not B or C:** B puts a coached first loss into the Founder's own table and Form Rating; C doubles the code paths for a lesson that must match the real game.

### 2.5 Where the first real game fits

The tutorial ends on Home with the next real match day waiting. The first real game gets no coach overlay at all: only the "?" dots and, on the first real report, the offer of lesson 8 ("what a game changed"). This keeps the pillar "about 5 minutes per game" and "ease of use first": the player already did every step once.

## 3. The first-run tutorial

### 3.1 Chapters and resume

The card shows the chapter name and a thin progress bar. It does **not** show "step 9 of 27" (a long counter discourages).

| Chapter | Steps | Resume at (after quitting and coming back) |
|---|---|---|
| 1 Find your way | 1 to 4 | step 2 |
| 2 Your squad | 5 to 6 | step 4 |
| 3 Set up a game | 7 to 11 | step 7 |
| 4 The draft | 12 to 15 | step 7 (a game in flight is not saved, so the game restarts) |
| 5 Plan and watch | 16 to 20 | step 7 |
| 6 The result | 21 to 23 | step 24 (the game is over) |
| 7 The league | 24 to 27 | step 24 |

On Continue, if the save says the tutorial is running, Home shows an inline card "Welcome back. Continue the guided first game?" with Continue and Skip tutorial (not a modal).

### 3.2 Step table

Kinds: **modal** (centred card, no hole), **info** (hole plus Next), **tap** (hole, waits for the real tap), **event** (waits for a game event). Dim: **full** 80 percent, **light** 45 percent, **none**. Skip codes and tap-elsewhere codes are defined under the table. "Lands" is where the player is when the step completes.

| # | id · screen | Highlight (coach id) · kind · dim | Key and exact coach text | Completes when → lands on | Skip · elsewhere |
|---|---|---|---|---|---|
| 1 | `welcome` · Home | none · modal · full | `tut.welcome` "You run {club}. Let's play one practice game together. It takes a few minutes, and nothing in it counts." Buttons: Start, Skip tutorial | Start tapped → Home | SK-A · TE |
| 2 | `home_card` · Home | `home.next_card` · info · full | `tut.home_card` "This is your next match day: who you play and how you compare. Home always shows what to do next." | Next → Home | SK-A · TE |
| 3 | `tabs` · Home | `tabbar` · info · full | `tut.tabs` "Five tabs hold your club: Home, Squad, Plan, Club and More. They are always here, so you cannot get lost." | Next → Home | SK-A · TE |
| 4 | `tab_squad` · Home | `tab.squad` · tap · full | `tut.tab_squad` "Squad is where your players live. Tap Squad." | `tap:tab.squad` → Squad tab | SK-A · TE |
| 5 | `squad_bench` · Squad | `squad.bench.0` · tap · full | `tut.squad_bench` "Your five starters stand on the map and play every game. Tap a bench player to open their card." | `open:player_card` → Squad, player sheet open in place (nothing below the fold) | SK-A · TE |
| 6 | `player_card` · Squad | `roster.card.head` (sheet header) · info · full, compact card | `tut.player_card` "This is a player card. The bars show tiredness, form and morale. Tired or unhappy players play worse." | Next (also closes the sheet) → Squad | SK-A · TE |
| 7 | `tab_plan` · Squad | `tab.plan` · tap · full | `tut.tab_plan` "Plan is where you prepare between games: training, team chemistry and practice. Tap Plan." | `tap:tab.plan` → Plan tab | SK-A · TE |
| 8 | `plan_practice` · Plan | `plan.tile.practice` · tap · full | `tut.plan_practice` "Practice games never count: not the table, not Form Rating, not morale. A safe place to learn. Tap Practice matches." | `tap:plan.tile.practice` → Practice | SK-A · TE |
| 9 | `quick_match` · Practice | `practice.quick` · tap · full | `tut.quick_match` "A Quick Match is one game against a club close to your strength. Tap Play a Quick Match." | `tap:practice.quick` → Pre-match (tutorial game starts, sandbox plan opens) | SK-A · TE |
| 10 | `matchups` · Pre-match | `prematch.matchups` · info · full | `tut.matchups` "Each row compares your player with theirs in that role. Higher numbers are better. Look for roles where you are ahead." | Next → Pre-match | SK-B · TE |
| 11 | `start_draft` · Pre-match | `prematch.start_draft` · tap · full | `tut.start_draft` "Next is the draft, where both teams ban and pick heroes. Tap Start draft." | `tap:prematch.start_draft` → Draft | SK-B · TE |
| 12 | `ban` · Draft | `draft.choices` (Coach bar plus hero grid) · event · full. Stage B: `draft.sheet.confirm` | `tut.ban` "First, a ban. Banning a hero stops the other team using it. Tap any hero, then Ban, or tap Take on the Coach bar." Stage B `tut.ban.confirm` "Tap Ban to confirm." | `draft:ban` (my ban applied, by Ban or by Take) → Draft | SK-B · TE |
| 13 | `pick` · Draft | `draft.choices` · event · full | `tut.pick` "Now pick a hero for your team. Heroes with an up arrow are strong this patch. Tap a hero, or tap Take." | `draft:sheet` (hero sheet open, best lane preselected) or `draft:pick` (Take) → Draft | SK-B · TE |
| 14 | `role` · Draft | `draft.slot_list` plus `draft.sheet.confirm` (one hole) · event · full, compact card | `tut.role` "Choose who plays this hero. Fit is how well the hero suits the role. The best lane is already chosen. Tap Pick." | `draft:pick` (pick applied) → Draft. Passed over if step 13 already saw `draft:pick` | SK-B · TE |
| 15 | `coach_rest` · Draft | `draft.auto_rest` · tap, two stages · full | `tut.coach_rest` "You can pick every hero yourself, or let the Coach finish the draft. Tap Auto-finish, then tap Sure? to confirm." Stage B `tut.coach_rest.sure` "Tap Sure? to let the Coach finish." One-tap button `tut.shortcut.coach_rest` "Let the Coach finish" | `draft:done` (draft complete) → Draft complete. Passed over if the draft is already done | SK-B · TE |
| 16 | `open_plan` · Draft complete | `draft.game_plan` · tap · full | `tut.open_plan` "Draft done. Now a Game Plan tells your team how to play: fights, tempo, objectives. Tap Game plan." | `tap:draft.game_plan` → Game Plan | SK-B · TE |
| 17 | `coach_suggest` · Game Plan | `gp.coach` · tap, two stages · full. Stage B: `gp.coach_apply` | `tut.coach_suggest` "Not sure what to set? Tap Coach. It suggests a plan from how your team compares with theirs." Stage B `tut.coach_suggest.apply` "These are the changes. Tap Apply to use them." One-tap button `tut.shortcut.apply` "Apply for me" | `gp:coach_apply` or `gp:coach_close` (Coach had nothing to change) → Game Plan (sandbox plan filled). `gp:coach_open` moves the step to stage B | SK-B · TE |
| 18 | `start_match` · Game Plan | `gp.start_match` · tap · full | `tut.start_match` "Happy with the plan? Tap Start the match to watch the game." | `tap:gp.start_match` → Match | SK-B · TE |
| 19 | `watch` · Match | `match.controls` · event · none (ring only) | `tut.watch` "Contests appear in the feed as they are decided. Try Speed x2, or Skip to the end." | `match:speed` or `match:skip` or `match:end` → Match | SK-B · TP |
| 20 | `see_report` · Match | `match.report_btn` · tap · light | `tut.see_report` "The game is over. Tap See the report." (shows only when the button is visible; no card while the game is still running) | `tap:match.report_btn` → Report | SK-B · TE |
| 21 | `result` · Report | `report.result` · info · full | Win: `tut.result.win` "Victory. The report starts with the result and the margin. This was practice, so nothing changed in your season." Loss: `tut.result.loss` "Defeat. That is fine: it was practice, and nothing changed in your season. The report shows why it went this way." | Next → Report | SK-C · TE |
| 22 | `why` · Report | `report.why` (the hero stat) · tap, two stages · full. Stage B: `report.why_sheet`, compact card | `tut.why` "This number is the biggest factor in the result. Tap it to see every factor. Luck is one of them." Stage B `tut.why.sheet` "Each bar is how much one factor moved the result. Luck is the random part of every game." | `open:report_why` moves to stage B; **Next** in stage B closes the sheet and completes → Report. Next is also on the card in stage A (one-tap route) | SK-C · TE |
| 23 | `continue` · Report | `report.continue` · tap · full | `tut.continue` "Tap Continue to leave the report. After real games it also shows what changed for your players." | `tap:report.continue` → Practice (Plan tab) | SK-C · TE |
| 24 | `tab_club` · Practice | `tab.club` · tap · full | `tut.tab_club` "Club holds money, the league table and Form Rating. Tap Club." | `tap:tab.club` → Club tab | SK-C · TE |
| 25 | `form_tile` · Club | `club.tile.form` · tap · full | `tut.form_tile` "Form Rating is a skill score for every club. Beating strong clubs raises it. Practice games never count. Tap it." | `tap:club.tile.form` → Standings, **Table view with the Form switch already on** (deep link, contract item 6) | SK-C · TE |
| 26 | `form_switch` · Standings (Table, Form) | `stand.metric` (the Points / Form switch) · tap · full | `tut.form_switch` "This list ranks clubs by Form Rating. Tap Points to switch to league points. Your club is marked in both." | `stand:metric` (the switch changed) → Standings, Points | SK-C · TE |
| 27 | `finish` · Standings | none · modal · full | `tut.finish` "You are ready. Go to Home and tap Play game for your first real match. The ? button explains any screen." Button: Go to Home | Go to Home tapped → Home; state becomes done | none (no Skip on the last card) · TE |

Codes:

- **SK-A** (steps 1 to 9, before the tutorial game exists): Skip ends the tutorial. The player stays on the same screen. Toast: "Tutorial skipped. You can replay it in Settings." with Undo. Nothing else changes, because nothing in the save was touched.
- **SK-B** (steps 10 to 20, the tutorial game exists): Skip ends the tutorial and removes all coaching, but the tutorial game carries on as an ordinary game where nothing counts: the sandbox plan stays until the game is left, the draft stays timer-free, and Report and Continue work as usual.
- **SK-C** (steps 21 to 26, after the game): Skip ends the tutorial; the player stays on the current screen.
- **TE** (tap elsewhere): the tap is swallowed by the dim. The card does a 120 ms nudge and the ring pulses once. After 2 stray taps within 5 seconds, a second line appears under the text: "Tap the glowing spot to go on." (`tut.nudge`). After 4, the Skip button pulses. A stray tap never advances a step and never reaches the screen below.
- **TP** (tap passes through, step 19 only): the watch must stay visible and tappable, so the overlay does not block. Only the ring and the card show; nothing is dimmed.
- Android back on any step: shows the "Leave the tutorial?" sheet (section 3.4), it never goes back a screen under the overlay.

- **Skip on a sheet step** (12 to 15, 17, 22): the overlay goes, a sheet the player opened stays open and is closed the normal way; the sandbox rules of SK-B and SK-C apply as before.

Counts: 2 modal (1, 27), 5 info (2, 3, 6, 10, 21), 20 do-steps (4, 5, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 22, 23, 24, 25, 26). Reading time at about 6 seconds per info step and 6 seconds per do-step, plus the 75-second watch (or about 5 seconds with Skip): 4 to 6 minutes. Sheet steps add about 2 seconds each for the second tap. **Estimate, never measured**; QA times a scripted run and testers time real ones (section 9).

**Alpha 0.8 variant of step 19.** When the match screen becomes the arena (UI-PASS-2 6.7), the step 19 text is out of date ("Contests appear in the feed"). From 0.8 it reads `tut.watch.arena` "Your team is the circles. Watch the fight, or use Speed x2 or Skip to the end." (17 words, no colour word, the shape carries the meaning). Target `match.controls`, event and dim as before (ring only, nothing dimmed). Step 20 and the id `match.report_btn` do not change.

**Fallback layout text for step 5.** If the five-avatar-card fallback of Squad ships instead of the lane map (UI-PASS-2 D3), `squad.bench.0` stays on the first bench card and the text is `tut.squad_bench.alt` "Your five starters play every game. Tap a bench player to open their card." (14 words), because "the map" would be wrong.

**Variant 5-B (only if the Founder wants the lineup picker taught).** Step 5 targets a lane-map token (`squad.token.top`), completes on `open:lane_picker`; step 6 targets the picker header (`squad.picker.head`) only, so the rows below it are blocked by the dim (a tap on a row would commit a **real** lineup change, which breaks "nothing real is changed"). Text for 5-B: `tut.squad_token` "Your five starters stand on the map. Tap one to see who else could play that role." (17 words) and `tut.picker` "Each row shows the change to team rating if you pick that player. We will not change anything now." (19 words). I did not make 5-B the default because the bench-card sheet is read-only and cannot change the lineup.

### 3.2a Steps that open a sheet or need a confirm: how each still obeys "one tap to continue or skip"

A **stage** is a second hole inside the same step (the step stays up, the card text swaps to the stage-B line, the hole moves). A **one-tap route** is a way to leave the step with exactly one tap. A card shortcut button runs the same code path as the real control (it never skips a state change) and raises the same completing event.

| Step | Real route (taps) | One-tap route to continue | Skip |
|---|---|---|---|
| 5 | 1: the bench card | the same tap | 1 |
| 6 | 1: Next (info) | the same tap | 1 |
| 12 ban | 2: any hero, then Ban in the sheet | **Take** on the Coach bar (1 tap, raises `draft:ban`) | 1 |
| 13 pick | 1: a hero (step completes when its sheet opens) | the same tap, or **Take** | 1 |
| 14 role | 1: Pick (lane preselected) | the same tap; passed over if Take was used in 13 | 1 |
| 15 | 2: Auto-finish, then Sure? | card button **Let the Coach finish** (1 tap, same call as the confirmed Auto-finish, raises `draft:done`) | 1 |
| 17 | 2: Coach, then Apply | card button **Apply for me** (1 tap, applies the suggestion to the sandbox plan, raises `gp:coach_apply`) | 1 |
| 22 | 2: the hero stat, then Next | **Next** shown on the card in stage A (1 tap, skips the factor sheet) | 1 |
| 26 | 1: Points on the switch | the same tap | 1 |

Rules that keep this safe:
1. **Armed state holds.** While step 15 is up the "Sure?" state of Auto-finish does not time out after 3 seconds (UI-PASS-2 6.3 says 3 seconds in the real game); it holds until the player taps Sure? or the step ends. Otherwise the card would say "Tap Sure?" about a button that has changed back.
2. **A step is passed over, never silently skipped, when its completing event has already happened** (`skip_if: event_seen`): step 14 after Take in step 13, step 15 if the player picked all five heroes by hand.
3. **A sheet cannot be dismissed during a sheet step** except by the step's own controls: the four dim panels cover the sheet's scrim and drag zone. To change their mind the player picks another lane in the sheet. This is deliberate; Skip tutorial is still one tap.
4. **The hole is the smallest rectangle that contains the real control(s).** Step 14 targets two ids (lane row and confirm button) and the hole is their bounding box; the card sits above it.
5. **Compact card on sheet steps** (6, 14, stage B of 12, 17 and 22): chapter row hidden, text only, at most 35 percent of the screen, so card plus the sheet part under the hole never meets the status bar. A bottom sheet is size M (60 percent) or L (85 percent), so the card is placed over the dimmed upper part of the sheet.

### 3.3 Why these steps, in this order

- **Home first, because it is the hub.** The next-match card is the one thing Home always answers, and the tab bar is the whole map of the game (steps 2 and 3). Step 4 makes the player use it.
- **Squad before the game.** A new player has never seen a player card; it appears in the pre-match numbers and in every report. One tap on a bench card, one explanation (steps 5 and 6). The bench card opens a read-only sheet, so nothing can change. The lineup picker is left to the "tired starters" notice and the Squad help sheet (or variant 5-B), because a tap on a picker row would change the real lineup.
- **Practice as the vehicle** (steps 7 to 9). The player visits Plan and Practice once, which is also how they will find practice later. The line "Practice games never count" is said at the moment it matters.
- **Pre-match, then Draft.** Matchups first, because they are the first numbers the player can act on. The draft is four steps: ban, pick, role, then "let the Coach finish". The role step sits on the lane row of the hero sheet (fit and the preselected best lane), which is where a pick becomes a decision. The Coach shortcut (Take, Auto-finish) is taught so the player knows they can always hand the draft over, which protects the five-minute promise.
- **Game Plan: open, press Coach, apply, start.** Four taps on the real route (Game plan, Coach, Apply, Start the match), three with the one-tap route of step 17. The explanation of "expected edge", the phase strip and the tracks is lesson 5, because teaching 8 settings in a first game would break the one-idea rule.
- **Watch: one step, no dim.** Speed and Skip are the only controls; the dim is off so the player can actually watch. If the match ends before they tap, the step completes by itself.
- **Report: result, why, continue.** "Why it went this way" is the best learning moment the game has, so it gets its own step; the player taps the hero stat (the biggest factor) and reads the factor sheet.
- **Standings and Form Rating last.** It uses the one number that practice cannot move, which makes the "never counts" lesson visible, and ends the tutorial in the league context the player will play for. The last real tap, on the Points / Form switch, shows that the same table has two rankings.

### 3.4 Global behaviour of the overlay

| Situation | What happens |
|---|---|
| Target not yet on screen (the draft is waiting for the AI, the Report button is still hidden) | No dim, no card. Waits up to 6 seconds, then shows the fallback card. |
| Target missing for 2 seconds after its screen is up (layout changed) | Fallback: the card appears at the bottom without a hole, same text, with Next. `Coach.fallbacks` goes up and is shown in Debug info. QA treats any fallback in a scripted run as a failure. |
| Target is off screen inside a scroll area | The overlay scrolls it into view (240 ms), then shows the hole. Nested and horizontal scroll areas are walked from the inside out. |
| Target moves while the step is up (the player scrolls inside the hole, large-text toggled) | The hole follows every frame (cheap: one rect). |
| The player completes the step in a way the text did not ask for (taps Take on the Coach bar on the ban step) | Accepted if it raises the same event. Steps list their events, not their buttons. |
| The target is inside a `BottomSheet` (steps 6, 12 stage B, 14, 17 stage B, 22 stage B) | The overlay is on its own canvas layer above sheets, so the hole shows the sheet control and the dim covers the sheet's scrim. The sheet's own scrim must not swallow a tap inside the hole: the hole is uncovered by the overlay, and the scrim is never the topmost node there (spike B11). |
| A sheet the step opened is still open when the step ends | Next on step 6 and step 22 closes it; Pick, Ban and Apply close it by themselves. A step never leaves a sheet over the next step's target. |
| A step asks for a control that is under a sheet (for example `gp.start_match` while the Coach sheet is open) | No dim, no card, wait up to 6 seconds, then the fallback card (the existing rule for targets not yet on screen). Section 3.2a rule 2 prevents it in normal play. |
| The player switches Settings, Quick mode on | Ignored for the tutorial game only. |
| Draft timer | Off in the tutorial game. |
| Match running under an info card | The match keeps running (the 75-second watch is a Founder decision). Step 19 has no dim for this reason. |
| Android back | "Leave the tutorial?" sheet: "Your game is safe. You can replay the tutorial any time in Settings." Buttons: Keep going, Skip tutorial. Back again closes the sheet. |
| App backgrounded or killed | Progress is saved at every step change (section 6). On return, resume per the chapter table. |
| Toast appears while a card is up | Queued and shown when the step ends. |
| Large-text toggled while a step is up | The overlay rebuilds on the viewport size change. |
| Help "?" tapped | It is outside the hole, so it is blocked during a step. Lessons and the tutorial never overlap with a help sheet. |
| Tutorial skipped, then Undo | Restores the same step if the toast is still up, otherwise the tutorial stays skipped. |

## 4. Lessons: short optional follow-ups

### 4.1 What goes where

**First-run (27 steps):** Home and next match card, five tabs, Squad and a player card, Practice, Pre-match, Draft (ban, pick, role, Coach), Game Plan basics (open, Coach, Apply, start), watching (speed, skip), the report and why you won or lost, Form Rating and the Points / Form switch.

**Lessons (optional, offered when useful):**

| # | Lesson (title) | Why it is not first-run | Unlocks when | Offered where |
|---|---|---|---|---|
| L1 | The league table and playoffs (`standings`) | The first game only needs Form Rating | First real game left, back on Home | Home offer card |
| L2 | Training and rest (`training`) | Needs a tired player to mean something | A starter is worn (fatigue 25 or more) or round 2 | Home, in "Needs your attention" |
| L3 | Contracts (`contracts`) | Contracts matter at half season and season end (all ten contracts end the same season at the start) | Round 9 or later with an ending contract, or the Season summary is opened | Inline card above the Contracts card on Season summary, and Home |
| L4 | Bonds and chemistry (`chemistry`) | Bonds only move after several games | Round 3 or later | Home offer card |
| L5 | Game Plan in depth (`gameplan`) | Eight settings break the one-idea rule | The first Draft complete screen of a real game | Inline card on Draft complete |
| L6 | Money and the wage cap (`money`) | No money decision in the first game | Round 4 or later | Inline card at the top of the Club tab |
| L7 | Signing a player (`freeagents`) | Squad is full at the start | Round 6 or later, or a player left | Inline card at the top of the Club tab |
| L8 | What a game changed (`payoff`) | Practice reports do not have the card | The first real league or playoff report | Inline card at the top of that report |

Offer rules: never during the tutorial or on the first real match day; at most one new offer per match day; every offer has Show me and Later; Later snoozes for 3 match days, and after 3 snoozes the offer is dismissed for good (the lesson stays in the Lessons list with a "New" tag). Round numbers are first guesses for the Lead Game Designer to tune.

Lessons use the same overlay, the same Skip and the same ids. **Lessons never change the club:** a "tap" step only navigates or opens something; a step that would change data is an info step with Next.

### 4.2 Lesson step tables

Skip for every lesson step: ends the lesson, player stays where they are, nothing is saved as done. Tap elsewhere: TE, as above. Word counts are checked by script (section 9, test 14).

**L1 The league table and playoffs** (start route: Home)

| id | Highlight · kind | Key and text | Completes → lands |
|---|---|---|---|
| `l1.open` | `home.tile.standing` · tap | `les.l1.open` "Tap Standing to open the league table." | `tap:home.tile.standing` → Standings |
| `l1.table` | `standings.table` · info | `les.l1.table` "A win is worth 3 points. The top four clubs reach the playoffs. Ties go to head-to-head wins, then total margin." | Next |
| `l1.metric` | `stand.metric` · info | `les.l1.metric` "Switch between league Points and Form Rating. Your club is marked in both." | Next |
| `l1.tabs` | `standings.tabs` · info | `les.l1.tabs` "Playoffs shows the title series as a bracket. History keeps your recent games and your trophies." | Next → end |

**L2 Training and rest** (start route: Plan tab)

| id | Highlight · kind | Key and text | Completes → lands |
|---|---|---|---|
| `l2.open` | `plan.tile.training` · tap | `les.l2.open` "Players grow a little between match days. Tap Training to choose what each one works on." | `tap:plan.tile.training` → Training |
| `l2.preview` | `training.preview` · info | `les.l2.preview` "These chips show how many starters are tired now, and after the next game. Tired starters lose rating." | Next |
| `l2.player` | `training.row.0` · tap | `les.l2.player` "Tap a player to choose a focus: a stat, a hero, a team scrim or rest." | `open:training_picker` (opens only, no choice made) |
| `l2.rest` | `training.picker` · info | `les.l2.rest` "Rest adds no tiredness and clears some. Pick it for a worn starter. Changes apply at once, and you can Undo." | Next → end |

**L3 Contracts** (start route: Squad tab)

| id | Highlight · kind | Key and text | Completes → lands |
|---|---|---|---|
| `l3.open` | `tab.squad` · tap | `les.l3.open` "Contracts last a set number of seasons. Tap Squad to see who is close to the end." | `tap:tab.squad` → Squad |
| `l3.row` | `squad.bench.expiring` (the first bench card with the contract chip, else `squad.bench.0`) · tap | `les.l3.row` "Tap a bench player whose contract is ending." | `open:player_card` (player sheet opens, read-only) |
| `l3.contract` | `roster.card.contract` (the contract line in the sheet) · info | `les.l3.contract` "The card shows the weekly wage and the seasons left. When none are left, the player leaves unless you renew." | Next |
| `l3.renew` | `roster.card.renew` (else `roster.card.release`; the sheet footer) · info | `les.l3.renew` "Renew starts talks. Young players with high potential ask for more, and the wage cap limits what you can afford." | Next, which closes the sheet → end (Renew and Release are **not** tapped: an info step covers its hole with a blocker, section 7.1) |

Note on L3: a starter whose contract ends is a lane-map token, and a token opens the lane picker, not the player sheet (UI-PASS-2 6.2). The lesson therefore points at a **bench** card, which always opens the sheet. All ten contracts end in the same season, so a bench card with the chip exists whenever the lesson is offered. The sheet footer holds Renew and Release; to keep the rule "lessons never change the club", **info steps cover their hole with a transparent blocker** (section 7.1), so the highlighted Renew button cannot be tapped. v1 left the hole open on info steps, which would have let a tap reach Renew or Release; that is fixed here.

**L4 Bonds and chemistry** (start route: Plan tab)

| id | Highlight · kind | Key and text | Completes → lands |
|---|---|---|---|
| `l4.open` | `plan.tile.chem` · tap | `les.l4.open` "Bonds grow when players play together. Tap Team chemistry to see yours." | `tap:plan.tile.chem` → Chemistry |
| `l4.summary` | `chem.summary` · info | `les.l4.summary` "Chemistry turns the bonds of your five starters into a small rating bonus for the whole team." | Next |
| `l4.pentagon` | `chem.pentagon` · info | `les.l4.pentagon` "Each line is a bond between two starters. Thicker lines mean stronger bonds." | Next |
| `l4.scrim` | `chem.training` · info | `les.l4.scrim` "Team scrims in Training build bonds a little faster. Swapping a starter costs chemistry until the new pairs have played." | Next → end |

**L5 Game Plan in depth** (start: the Draft complete screen of a real game, or from the Lessons list through an AI-drafted sandbox game that opens its Game Plan screen; the sandbox start is an optional small extra)

| id | Highlight · kind | Key and text | Completes → lands |
|---|---|---|---|
| `l5.open` | `draft.game_plan` · tap (skipped if already on the Game Plan screen) | `les.l5.open` "Tap Game plan to look at your options." | `tap:draft.game_plan` → Game Plan |
| `l5.edge` | `gp.edge` · info | `les.l5.edge` "Expected edge is your advantage before luck. Your plan moves it. Luck can still change a single game." | Next |
| `l5.contests` | `gp.contests` · info | `les.l5.contests` "Each row is one contest in the game. A plus sign means you are stronger there, a minus sign means they are." | Next |
| `l5.phases` | `gp.tabs` (the phase strip: Overall, Early, Mid, Late) · info | `les.l5.phases` "Overall, Early, Mid and Late are the phases of a game. Tap one to see its settings and where you stand." | Next |
| `l5.plan` | `plan.chip` (the Plan chip in the header) · info | `les.l5.plan` "Plan: Default is used from the start. If behind and If ahead take over from the mid-game after a one-sided early game." | Next |
| `l5.sliders` | `gp.sliders` (the detent tracks) · info | `les.l5.sliders` "Each setting trades one strength for another. Risk and aggression make games swingier, which helps the underdog." | Next → end |

(L5 grew from 5 to 6 steps in v1.1 because the old `gp.tabs` meant Default / If behind / If ahead, and UI-PASS-2 moved those into the Plan chip. L5 start text: the first step `l5.open` still points at `draft.game_plan`.)

**L6 Money and the wage cap** (start route: Home)

| id | Highlight · kind | Key and text | Completes → lands |
|---|---|---|---|
| `l6.club` | `tab.club` · tap | `les.l6.club` "Tap Club to find your money." | `tap:tab.club` → Club |
| `l6.finance` | `club.tile.finance` · tap | `les.l6.finance` "Tap Finance to see where your cash goes." | `tap:club.tile.finance` → Finance |
| `l6.balance` | `fin.balance` · info | `les.l6.balance` "Balance is your cash. Wages are paid every round. If it stays below zero too long, the board dismisses you." | Next |
| `l6.cap` | `fin.cap` · info | `les.l6.cap` "The wage cap is the most you can pay players each week. Signings over the cap are blocked." | Next |
| `l6.sponsor` | `fin.sponsor` · info | Open: `les.l6.sponsor` "A sponsor pays a weekly retainer and a bonus for hitting its target. You can change it until your first game." Locked: `les.l6.sponsor_locked` "A sponsor pays a weekly retainer and a bonus for hitting its target. This season's deal is fixed." | Next → end |

**L7 Signing a player** (start route: Club tab)

| id | Highlight · kind | Key and text | Completes → lands |
|---|---|---|---|
| `l7.open` | `club.tile.fa` · tap | `les.l7.open` "Free agents have no club. Young players with high potential grow into stars but ask for more. Tap Free agents." | `tap:club.tile.fa` → Free agents |
| `l7.filters` | `fa.filters` · info | `les.l7.filters` "Filter by role and sort by rating, potential, age or price." | Next |
| `l7.row` | `fa.row.0` · info | `les.l7.row` "Tap a player to start talks. What they will accept is a secret, so make an offer and read the reply." | Next → end |

**L8 What a game changed** (starts on the first real report; offered inline there)

| id | Highlight · kind | Key and text | Completes → lands |
|---|---|---|---|
| `l8.payoff` | `report.payoff` · info | `les.l8.payoff` "This card shows what the game did to form, morale, bonds and cash. Form and morale change how players perform next time." | Next |
| `l8.tip` | `report.tip` · info | `les.l8.tip` "The tip points at the most useful thing to fix before your next game." | Next → end |

If a target is missing in a lesson step, the same fallback card applies. If a lesson cannot start (for example L7 when the Club tab has no Free agents tile), it is hidden from offers and shown in the Lessons list as "Not available right now".

### 4.3 The Lessons list

A small screen from Settings: one card per lesson with title, "about a minute", a **New** tag until opened, a tick when done, and a Start button. Start navigates to the lesson's start route and runs it. L5's Start says "Opens during a draft" unless the sandbox start is built.

## 5. Contextual help

### 5.1 The "?" button and the sheet

- **Button:** `help.button`, top right of every screen that has a title or a head card. It is part of the shared `Screen` frame (UI-PASS-2 `ScreenHeader`, 5.2), so one change covers every page. A 96 x 96 px corner is reserved on every screen. 88 px visible circle, 96 px hit area. A coral dot on it means "never opened on this device" (dot colour per ART-BIBLE token table; a dot is a shape, so it does not rely on colour). Two screens lay out around it specially:
  - **Draft:** the header is back, title, timer ring, Auto-finish, "?" (UI-PASS-2 6.3 wireframe now shows the slot). The title is shortened to "YOUR BAN", "YOUR PICK", "THEIR BAN" so it fits beside the four fixed parts.
  - **Match (arena, Alpha 0.8):** the top of the screen is the scoreboard, so "?" sits at the **right end of the controls row** (UI-PASS-2 6.7), the one place where it is not top right. The 0.7 match screen keeps the standard top-right corner.
  - **Home:** the "?" sits over the hero art; UI-PASS-2 6.1 states its contrast (solid circle plus a ring) and asks the Art Director to keep a 120 x 120 px clear zone in the art (pending ART-BIBLE re-issue).
- **Sheet:** a bottom sheet over a 60 percent dim (UI-PASS-2 5.5, size M, size L in large text): a title, then three short blocks, then the words on the screen, then two buttons. It scrolls inside if needed, slides up in 220 ms (the `BottomSheet` motion), closes on Got it, a tap on the dim, drag down, or Android back.

  1. **What you see** (one or two lines).
  2. **What to do** (two lines).
  3. **Good to know** (one or two lines).
  4. **Words on this screen:** chips that open the glossary entry in place (with a Back).
  5. Buttons: **Got it**; **Take the lesson** (only where a lesson exists); a quiet link "Open the glossary".
- **While a sheet is open the draft timer and the match playback pause**, and resume on close. (The 75-second watch is a fixed length of playback, so a pause does not change the result.)
- **Dot memory:** per screen, on the device. Opening the sheet clears the dot. No sheet ever opens by itself.

Draft wording for the Narrative Designer to polish. Each line is 20 words or fewer. The helper is **Coach** in every line (section 13). Keys: `help.<id>.title`, `.see`, `.do`, `.know`, `.terms` (a list of glossary ids).

| Screen (help id) | What you see | What to do | Good to know | Words (glossary ids) |
|---|---|---|---|---|
| Home (`home`) | Your next match day, how you compare with the other club, and four summary tiles. | Tap Play game to start. Tap a tile to open that part of your club. | "Needs your attention" lists things to fix before you play, like tired starters. | team_rating, patch, chemistry, form |
| Squad (`squad`) | Your five starters on a small map, one per role, and the bench below. | Tap a starter to change who plays that role. Tap a bench player to open their card. | A player out of position loses rating. Auto lineup fixes it in one tap. | role, rating, fatigue, form, morale |
| Player card (`player`) | Tiredness, form and morale bars, the contract, bonds and best heroes; Stats and Career are one tap away. | Tap Stats to read what each stat does. Renew a contract that is ending. | Potential is the most a stat can grow to. Young players grow fastest. | potential, stats, contract, bonds |
| Plan (`plan`) | Training, team chemistry, practice matches and your Game Plan status. | Tap a tile to open it. Check training before every match day. | The Game Plan is set during each draft, after the picks, because it depends on the heroes. | training_focus, chemistry, practice_match, game_plan |
| Training (`training`) | What every player works on until the next match day, and how tired your starters will be. | Tap a player to pick a stat, a hero, a team scrim or rest. | Training adds a little tiredness. Resting adds none and clears some. | training_focus, fatigue, rest, scrim |
| Chemistry (`chemistry`) | The bonds between your five starters, who understands whom, languages and the bench. | Look for weak pairs. Use team scrims in Training to build bonds. | Swapping a starter costs chemistry until the new pairs have played together. | bonds, chemistry, understanding, scrim |
| Practice (`practice`) | Quick Match and Exhibition. They never count for the table or Form Rating. | Play a Quick Match for a fast game. Choose Exhibition for a club and a series length. | One practice series per match day. Starters get a little tired and bond a little. | practice_match, quick_match, exhibition |
| Pre-match (`prematch`) | Your club against theirs, role by role, with each player's rating in that role. | Check the rows, rest tired starters if offered, then tap Start draft. | Tired starters play below their rating. "Auto-play this game" skips the watching. | rating, role, fatigue, draft |
| Draft (`draft`) | Whose turn it is, you on the left and them on the right, and the heroes you can choose. | Ban heroes their players know best. Pick heroes your players know and that fit the role. | If the timer runs out the Coach chooses for you. Auto-finish hands the draft to the Coach. | coach, ban, pick, familiarity, fit, patch_strength, composition |
| Game Plan (`gameplan`) | Your expected edge on top, then settings for each phase: fights, tempo, objectives, lanes, support and risk. | Tap a stop on a track to change it. Tap Coach to see a suggested plan. | Edge is before luck. Risk helps the underdog and hurts the favourite. Your plan is kept for the next game. | coach, edge, game_plan, risk, objective, teamfight |
| Match (`match`) | The clock, kills, towers and who is ahead, with each contest shown as it is decided. | Watch, tap Speed x2 to go faster, or Skip to the end. | The result was decided before you watched, so watching or skipping never changes it. | lane, jungle, objective, teamfight, base |
| Report (`report`) | The result, the standout player, what the game changed, one tip, and why it went this way. | Open "Why it went this way" to see the factors. Tap Continue when done. | Luck is a factor. A big luck share means a close game could have gone either way. | margin, standout, luck, form, morale, bonds |
| Club (`club`) | Money, the league table, Form Rating and free agents, each with one line of status. | Tap a tile to open it. | Cash below zero for too long gets the manager dismissed. | cash, form_rating, free_agent |
| Standings (`standings`) | The league table with a podium, the playoff bracket, and your history of games and trophies. | Tap Table, Playoffs or History. Tap Points or Form to change the ranking. Your club says YOU. | A win is worth 3 points. Ties go to head-to-head wins, then total margin. | table, form_rating, playoffs, best_of |
| Finance (`finance`) | Your cash, weekly income and wages, the sponsor and every payment. | Pick a sponsor before your first game of the season. Watch the wage cap. | Wages are paid every round. Over the cap, signings are blocked. | cash, wage, wage_cap, sponsor |
| Free agents (`freeagents`) | Players with no club, with rating, potential and the wage they ask. | Filter by role, sort by what matters, tap a player to talk. | Your squad has a limit. A signing needs cash for the fee and room under the wage cap. | free_agent, potential, signing_fee, wage_cap |
| Negotiation (`negotiation`) | The player, what a deal does to your wages, cap and cash, and your offers left. | Set the wage and length, then Make offer. | What a player will accept is secret. A temperamental player walks away after two refusals. | contract, wage, personality, signing_fee |
| Season summary (`season`) | How the season ended, your history, who grew, and contracts that end now. | Renew players you want to keep before starting the next season. | A player with an ended contract leaves when the new season starts. | contract, potential, playoffs |
| Settings (`settings`) | Quick mode, animations, comfort options, help and learning, feedback and the save. | Turn on larger text or colour-blind colours if they help. Replay the tutorial any time. | Your game is saved only on this device. | (none) |
| Club select (`clubselect`) | Every club with its Team Rating, strength tier and rank. | Pick the club you will manage. The middle of the table is a fair first choice. | Starting a new game later lets you try another club. | team_rating, rating |

Screens with no sheet: Title, About and Game over.

### 5.2 How the existing three tips fold in

| Today | Becomes |
|---|---|
| `tip.hub` "Welcome, Manager..." on Home | The Home sheet (`help.home`) and steps 1 to 4 of the tutorial. No more auto card on Home. |
| `tip.prematch` "Before the game..." | The Pre-match sheet (`help.prematch`) and steps 10 and 11. Its colour wording ("green rows") is retired: it fails in colour-blind mode. |
| `tip.report` "After every game..." | The Report sheet (`help.report`), steps 21 to 23 and lesson 8. |
| `tip.got_it` | Reused as `help.got_it`. |
| `App.tip_seen`, `tip_mark`, `tips_reset` | Kept, renamed `help_seen`, `help_mark`, `help_reset`, and used for the "?" dot. Old device records map across: a device where the old Home tip was dismissed counts as Home help already seen. |
| Settings "Show the welcome tips again" | "Show help hints again" (clears dots and lesson offers). |

Not touched: the **Payoff tips** (`tip.rest`, `tip.morale`, `tip.contract`, `tip.scrim`, `tip.keep`) that `Payoff.tip()` puts on every real report ("Before the next game"). They are a different feature that shares the `tip.` prefix. Programmers must not delete the whole prefix.

### 5.3 Glossary

Reachable from Settings, from every sheet footer and from the word chips. One screen with four group chips (Players, Match and draft, League, Club and money); tap a term to open its line and a "Where to see it" button. Keys: `gl.<id>.name`, `gl.<id>.def`, `gl.<id>.where` (a help id). Each definition is 22 words or fewer, in plain English, and matches the rules in the GDD (checked against the existing help strings, not re-simulated).

| Group | id · Term | One-line definition |
|---|---|---|
| Players | `team_rating` Team Rating | The average skill of your five starters in the roles they play. It leaves out form, tiredness and heroes. |
| Players | `rating` Rating | A player's skill in one role, built from his stats. Playing out of position lowers it. |
| Players | `role` Role | A player's job on the team: Top, Jungle, Mid, Bot Carry or Support. |
| Players | `stats` Stats | The eight skills that make up a rating. Tap a stat on a player card to read what it does. |
| Players | `potential` Potential | The most a player can grow to in a stat. High-potential young players become stars but ask for more money. |
| Players | `form` Form | How well a player has done lately. Results move it, and it fades over the days. A player in form plays better. |
| Players | `morale` Morale | How happy a player is. Results and playing time raise it. A starter who sits out for a while sours. |
| Players | `fatigue` Fatigue | Tiredness from playing. Tired starters lose rating, shown as worn, tired or exhausted. |
| Players | `bonds` Bonds | How well two players know each other. They grow when the pair plays together. A new teammate starts low. |
| Players | `understanding` Understanding | How clearly one player takes in what a teammate says. Bond, Communication and a shared language all help. |
| Players | `chemistry` Chemistry | Your five starters' bonds and understanding, turned into a small rating bonus for the whole team. |
| Players | `personality` Personality | How a player behaves in talks: Professional, Balanced, Casual or Temperamental. |
| Players | `training_focus` Training focus | What a player works on between match days: one stat, a hero, a team scrim or rest. |
| Players | `rest` Rest | A training choice that adds no tiredness and clears some. Use it for a worn starter. |
| Players | `scrim` Team scrim | A practice week that builds bonds a little faster. It adds no stat growth. |
| Match and draft | `coach` Coach | Your club's helper. It suggests bans, picks, game plans and training. You always decide. |
| Match and draft | `draft` Draft | Before each game both teams ban and pick heroes in turn. Blue acts first. If the timer runs out, the Coach chooses. |
| Match and draft | `ban` Ban | Removing a hero so neither team can use it. Ban the heroes their players know best. |
| Match and draft | `pick` Pick | Choosing a hero for one of your players. Each hero plays one role. |
| Match and draft | `hero` Hero | The character a player controls. Each has a style, strengths and a role it suits. |
| Match and draft | `familiarity` Familiarity | How well a player knows a hero. Higher is better play. It grows a little after each real game. |
| Match and draft | `fit` Fit | How well a hero suits the role it is given. 100 percent is perfect and less costs rating. |
| Match and draft | `patch_strength` Patch strength | How strong a hero is in the current patch. Strong heroes are the better bets. |
| Match and draft | `patch` Patch | A balance update that changes which heroes are strong. Home shows the current one, like P1. |
| Match and draft | `composition` Composition | How your five heroes work together. It has a style, such as Dive or Siege, and gives a bonus or a penalty. |
| Match and draft | `game_plan` Game Plan | Your instructions for how the team plays: fights, tempo, objectives, lanes, support and risk. You set it after the draft. |
| Match and draft | `edge` Expected edge | Your advantage before luck, from ratings, heroes and plan. Luck can still change a single game. |
| Match and draft | `risk` Risk | How swingy you want the game. More risk helps the underdog and hurts the favourite. |
| Match and draft | `lane` Lane | One of the three paths between the bases. Top, Mid and Bot results decide who leads early. |
| Match and draft | `objective` Objective | A big neutral target in the middle or late game. Winning it gives your team a lead. |
| Match and draft | `teamfight` Teamfight | A fight with all five players. The mid and late fights often decide the game. |
| Match and draft | `base` Base | The main building. The team that destroys the enemy base wins the game. |
| Match and draft | `margin` Margin | How big a result was: narrow, clear or decisive. |
| Match and draft | `standout` Standout | The player whose role moved the result most for your team. |
| Match and draft | `luck` Luck | The random part of every game. The report shows how much it moved the result. |
| League | `table` League table | Clubs ranked by points. A win is worth 3. Ties go to head-to-head wins, then total margin. |
| League | `form_rating` Form Rating | A running skill score for every club. Beating strong clubs in big games lifts it most. Practice never counts. |
| League | `playoffs` Playoffs | After the league rounds, the best clubs play short series for the title. |
| League | `best_of` Best of | A series won by the first side to take most of the games. Best of 3 needs two wins. |
| League | `practice_match` Practice match | A game that never counts for the table, Form Rating, form, morale or sponsor goals. |
| League | `quick_match` Quick Match | One practice game against a club close to your strength. |
| League | `exhibition` Exhibition | A practice series against any club you choose: best of 1, 3 or 5. |
| Club and money | `contract` Contract | A player's deal: a weekly wage and a number of seasons. When it ends, he leaves unless you renew. |
| Club and money | `wage` Wage | What a player is paid each week. Wages are paid every round. |
| Club and money | `wage_cap` Wage cap | The most you can pay players each week. A signing that goes over it is blocked. |
| Club and money | `cash` Cash | Your club's money. If it stays below zero too long, the board dismisses you. |
| Club and money | `sponsor` Sponsor | A partner that pays a weekly retainer and a bonus for hitting a target such as wins or a playoff place. |
| Club and money | `free_agent` Free agent | A player with no club. You can sign him if you have cash, squad room and room under the wage cap. |
| Club and money | `signing_fee` Signing fee | A one-off payment to sign a player: two weeks of his wage. |

49 terms (v1 had 48; v1.1 adds `coach`). Notes for the Narrative Designer: (1) **Decided (Producer ruling, wave 1b): one helper name, "Coach".** Today's game says "advisor" in two strings and "Coach" in the Game Plan and Training; section 13 lists what changes. The player is the **Manager** (Home and the offer cards already say "Manager"). (2) Where the text says "his" it follows the existing strings; "their" is safer if players can be of any gender.

## 6. State

### 6.1 What is stored and where

| Data | Where | Why there |
|---|---|---|
| Tutorial progress for this club | **Save**: `gs.d["tutorial"] = {"v": 1, "state": "running" / "done" / "skipped" / "legacy", "step": "<id>", "game": {"live": bool, "n": int, "plan": {...}}}` | A new save is a new club, so it gets its own offer. The sandbox plan belongs to a game in flight. |
| "I have seen the welcome", "finished once", "skipped once", "dismissed the legacy offer" | **Device**: `settings.cfg`, section `[tutorial]` | A returning player on a new save is not nagged. |
| Lesson status per lesson: absent, `offered`, `snoozed:<n>`, `dismissed`, `done` | **Device**: `settings.cfg`, section `[lessons]` | A lesson learned once is not offered again on the next save. |
| "?" dots (sheet opened on this screen) | **Device**: `settings.cfg`, section `[help]` (old `[tips]` keys map across) | Same pattern as today's tips. |
| Debug lines: `tutorial=done step_skipped=<id> total_s=<n> fallbacks=<n>` | Appended to `App.debug_info()` | Testers paste it with feedback, so drop-off is visible without any analytics. |

No save-version bump is needed: `GameState.from_dict` already fills missing keys for older saves (the same way it did for Alpha 0.2 and 0.3 saves). A missing `tutorial` key becomes `{"state": "legacy"}`.

### 6.2 Who sees what

| Player | What happens |
|---|---|
| First ever new game on this device | Welcome modal (step 1) with Start and Skip tutorial. |
| New game on a device that finished or skipped it before | Inline card on Home: "Welcome back, Manager. Want the guided first game again?" with Show me and No thanks. No modal. |
| Continue with a save made before this alpha (`legacy`) | Nothing starts. One inline card on Home, once per device: "New: a guided first game and help on every screen." with Show me and No thanks. |
| Continue with a save where the tutorial is `running` | Resume card (section 3.1). |
| Continue with `done` or `skipped` | Nothing. |

### 6.3 Replay, reset and Settings

A new card, **Help and learning**, sits at the top of Settings (it is the first thing under the title, because help should not be hunted for). Buttons, one tap each:

| Button | Key and text | What it does |
|---|---|---|
| Replay the guided first game | `settings.replay` | Confirm sheet "Replay the guided first game? It is a practice game. Nothing in your save changes." Replay it / Cancel. Sets `state=running`, `step=welcome`, increases `game.n`, goes to Home. Works in any phase. If there is no next game (phase done), step 2 is skipped automatically. |
| Lessons | `settings.lessons` | Opens the Lessons list. |
| Glossary | `settings.glossary` | Opens the glossary. |
| Show help hints again | `settings.help_reset` | Clears the "?" dots and sets snoozed or dismissed lessons back to "offered" (done lessons keep their tick). Toast "Help hints will show again." |

The old "Show the welcome tips again" button is removed. "Delete save and start over" also clears the save's tutorial state, because the save is gone; device flags stay.

### 6.4 Old saves

`legacy` saves never auto-start anything. They get the one inline offer, the "?" dots, lessons by the normal unlock rules, and Replay in Settings. Replay works on them because the tutorial game is sandboxed and independent of `exh` and the league day.

## 7. Overlay mechanism for Godot 4.3

(Design only. I could not run Godot here. Items marked **spike** must be proven first, in about half a day.)

### 7.1 Scene structure (built in code, like every other screen)

```
Main (existing)
 ├─ ... screens, TabBar
 ├─ CanvasLayer  layer 20   BottomSheet (UI-PASS-2 5.5): scrim + sheet
 ├─ CanvasLayer  layer 30   Toast
 └─ CanvasLayer  layer 100  CoachOverlay  (Control, full rect, visible only while a step is up)
     ├─ DimTop / DimBottom / DimLeft / DimRight   4 ColorRects, mouse_filter STOP
     ├─ HoleBlocker (Control over the hole, mouse_filter STOP, on while the step is an info step)
     ├─ Ring     (Control, mouse_filter IGNORE, custom _draw: rounded outline + soft glow)
     ├─ Pointer  (Control, mouse_filter IGNORE, custom _draw: a small triangle)
     └─ Card     (PanelContainer, mouse_filter STOP)
         ├─ ChapterRow : Label (chapter name, S_SMALL, TEXT2) + thin ProgressBar (hidden on compact cards)
         ├─ Body       : Label (S_BODY, autowrap, TEXT)
         └─ Buttons    : HBox [ Skip tutorial (flat) | Next or one-tap shortcut (primary) ]
```

**Z-order (C11).** The overlay is the topmost canvas layer, **above `BottomSheet`** (layer 20) and the toast (30), so a step can spotlight a control inside a sheet (steps 6, 12 stage B, 14, 17 stage B, 22 stage B; lessons L3). Because the overlay sits above the sheet's scrim, the scrim is never the topmost node under the hole, so it cannot swallow the tap the step waits for. Layer numbers are suggestions; the rule is "overlay above every sheet, dialog and toast". **spike** B11: prove with real touch events that a tap in the hole reaches a button inside a sheet on a lower layer, in Godot 4.3 on Android.

**Why four panels and not a shader or a hit-test override:** the four dim rectangles surround the hole and leave it uncovered, so touches inside the hole reach the real control with no input tricks, and the hole logic is plain rectangle maths that headless tests can check. (An alternative, one full-screen shader with a rounded-rectangle hole plus overriding `_has_point` on the dim, looks smoother at the corners. It is a nice-to-have **spike**: the ring drawn over the square hole hides the difference.)

**Info steps block the hole.** On an info step (Next on the card) the `HoleBlocker` covers the hole, so the highlighted control cannot be tapped (v1 left it live, which would let a tap reach Renew or Release in lesson L3). On tap and event steps the hole is open and the blocker is off.

One target id gives one rectangle. If a step needs two controls (ban step: Coach bar and hero grid), the programmers tag their common container (`draft.choices`). A step may also list two ids; the hole is the bounding rectangle of both (step 14: lane row and confirm button), clamped to the sheet.

### 7.2 Finding and following the target

1. Controls are tagged with `UI.tag(control, "id")`, which stores a registry entry (id to weak reference, cleaned on `tree_exited`) and adds a `pressed` listener that emits `tap:<id>`. Screens call it where they build the control, so a rebuilt screen re-registers.
2. A step stays in a "settle" state until the target exists and has a non-zero size (controls report size 0 until the frame after they enter the tree; allow up to 12 frames), then scrolls into view, then shows.
3. Every frame while a step is up, the overlay reads `target.get_global_rect()` and repositions the four panels, the ring and the card. One rect per frame, no allocations.
4. **Scroll into view:** walk the target's ancestors; for each `ScrollContainer` (vertical and horizontal) call `ensure_control_visible`, then tween `scroll_vertical` so the target sits at about 40 percent of the visible height (a target taller than the view aligns its top edge 24 px below the top). 240 ms. **spike** (nested scrolls inside the roster page).
5. **Hole size:** the control rect plus 8 px of padding, clamped to the screen. A target smaller than 96 px high is still drawn at its own size (a bigger hole would let a stray tap reach a neighbour).
6. **Large target** (the Report "why" section is taller than the screen): the hole is clipped to the visible part above the card.

### 7.3 The card and phone-safe sizes

The design screen is 720 x 1280. On common phones 1 dp is about 1.75 to 2.0 px of it, so 48 dp is 84 to 96 px.

| Part | Size |
|---|---|
| Card width | viewport width minus 32 px (16 px each side); never wider than 680 |
| Card padding | 24 px (UI-PASS-2 spacing scale), radius `UI.R_CARD` (24), fill `UI.PANEL3` (the overlay surface, so it reads against dimmed screens and over sheets), 2 px border `UI.ACCENT` at 70 percent, so it reads as "the helper" (fill and border per ART-BIBLE token table) |
| Body text | `UI.S_BODY` (32). Never below `UI.S_CAPTION` (24) anywhere on the card (v1 said 28 and 22) |
| Chapter label | `UI.S_SMALL` (26), `TEXT2` (the `DIM` token is not allowed on the overlay surface, ART-BIBLE 3.2); progress bar 8 px high |
| Buttons | at least 96 px high; Next or the one-tap shortcut primary (expand, 60 percent), Skip tutorial flat (expand, 40 percent). On do-steps only Skip shows, centred, except steps 15, 17 and 22 stage A, which also show their one-tap button |
| Card height | at most 45 percent of the screen (35 percent on compact sheet steps); the chapter row is dropped first, then the body scrolls inside, if it ever needs more |
| Safe margins | top at least 48 + 16 px (the existing top margin plus a gap), bottom at least 24 + 16 px; use the display safe area where the phone reports one |
| Card side | below the hole if the hole's centre is in the top half, above it otherwise; never covers the hole |
| Ring | 4 px outline (`TEAL_HI` is the art bible's focus ring; per ART-BIBLE token table), corner radius equal to the target's own (about 20 to 24) plus 6, plus a 10 px glow at 25 percent. A shape, not just a colour |
| Pointer | 36 px triangle on the card-facing edge of the hole; hidden when the hole is larger than 40 percent of the screen |
| Dim | `UI.BG` at 80 percent (full) or 45 percent (light); none for step 19 |

**Large text:** all of the above is computed from the live viewport (about 626 x 1113 logical when `content_scale_factor` is 1.15). Paper estimate with the new sizes, not measured: inner text width 626 - 32 - 48 = 546 px; a 25-word text (about 150 characters) wraps to 4 lines in the narrower art-bible font and up to 6 in today's font. Worst case: 6 lines x 43 px = 259, chapter row 50, buttons 96, padding 48, gaps 24, so **about 477 px, 43 percent of 1113, only about 24 px under the cap** (v1 estimated 300 to 360 px at 28 px). That is why the chapter row is the first thing dropped and the body scrolls as the last resort. At 720 x 1280 the same text is at most 5 lines, about 434 px or 34 percent. A step that cannot fit shows the fallback layout (card at the bottom, hole clipped) rather than overflowing. Test 4 measures it.

### 7.4 Animation limits

Every motion is 250 ms or less and none loops. Values (all instant when `UI.animate` is false):

| Motion | Time |
|---|---|
| Dim fade in or out | 160 ms |
| Hole and ring move to the next target | 220 ms, ease out |
| Card swap (fade plus 24 px slide) | 160 ms |
| Scroll into view | 240 ms |
| Ring pulse (scale 1.00 to 1.06 and back), twice on step start and once on a stray tap | 2 x 120 ms |
| Card nudge on a stray tap | 120 ms |
| "Step done" tick on the progress bar | 180 ms |
| Help sheet slide up (the shared `BottomSheet`, UI-PASS-2 5.5) | 220 ms |
| Hole moves to the stage-B control inside a sheet | 220 ms, same as a new target |

No `process` work runs while no step is up. Budget: the overlay must not add measurable cost on a low-end phone (checked on the build computer only; section 9, test 15).

### 7.5 Events the engine listens to

Steps list events, not buttons, so a different route to the same result still counts.

| Event | Raised by |
|---|---|
| `tap:<coach id>` | any tagged button's `pressed` |
| `screen:<help id>` | `Main.show_screen` |
| `open:player_card` | the Squad screen when the player sheet opens (from a bench card, or from "Player card" in the lane picker) |
| `open:lane_picker` | the Squad screen when a token opens the lane picker (variant 5-B only) |
| `open:training_picker` | Training when a row expands |
| `draft:sheet` | the draft screen when the hero sheet opens (ban or pick; the event carries `kind`) |
| `draft:ban`, `draft:pick` | a ban or a pick applied, by the sheet's confirm button or by Take on the Coach bar |
| `draft:done` | the draft is complete (by hand, by Auto-finish confirmed, or by the card's one-tap button) |
| `draft:hero` | **retired.** v1 raised it when a hero was chosen and a role list opened; the hero sheet replaces that list, so `draft:sheet` takes its place |
| `gp:coach_open` | the Coach diff sheet opened |
| `gp:coach_apply` | Apply tapped (or the card's "Apply for me") |
| `gp:coach_close` | the Coach sheet closed with nothing applied |
| `gp:coach` | **retired.** v1 raised it when the old button filled the plan at once |
| `open:report_why` | the Report's factor sheet opened (from the hero stat or its "all factors" link) |
| `stand:metric` | the Standings Points / Form switch changed |
| `match:speed`, `match:skip`, `match:end` | the match screen (0.7) or the arena controls (0.8) |

### 7.6 Step data

Steps are data, not code (one JSON file, `game/data/tutorial_v1.json`, read by a small `Tutorial` class), so the Narrative Designer and QA can read it:

```
{"id": "ban", "chapter": 4, "screen": "draft", "target": ["draft.choices"], "kind": "event",
 "dim": "full", "done_on": ["draft:ban"], "key": "tut.ban",
 "stage_b": {"on": "draft:sheet", "target": ["draft.sheet.confirm"], "key": "tut.ban.confirm", "compact": true},
 "skip": "B", "skip_if": ""}

{"id": "coach_rest", "chapter": 4, "screen": "draft", "target": ["draft.auto_rest"], "kind": "tap",
 "dim": "full", "done_on": ["draft:done"], "key": "tut.coach_rest", "hold_armed": true,
 "stage_b": {"on": "tap:draft.auto_rest", "target": ["draft.auto_rest"], "key": "tut.coach_rest.sure"},
 "shortcut": {"key": "tut.shortcut.coach_rest", "does": "draft_auto_finish"},
 "skip": "B", "skip_if": "event_seen:draft:done"}
```

`skip_if` uses a tiny fixed vocabulary: `no_next_game` (step 2 on Home in the playoffs or done phase), `target_missing` (never skip silently), `already_on:<screen>`, `event_seen:<event>` (the completing event already happened during an earlier step; the step is passed over and progress still saves). A step with a win and a loss text has `key_win` and `key_loss`. `target` is a list; two ids give one bounding-box hole. `stage_b` swaps the hole and the card text when its event arrives. `shortcut` adds a primary card button that runs the named action (the same code path as the real control). `hold_armed` suspends the 3-second revert of the "Sure?" state while the step is up. `compact` uses the sheet-step card (no chapter row, at most 35 percent).

## 8. Ids the programmers must add

**First-run needs these 27** (marked ★; v1 had 25). The rest serve lessons and help. Where a control is rebuilt (`_rebuild()` screens) the tag is applied again each time. If UI-PASS-2 renames or moves a control, the id stays; if it removes a control, the layout agent says so and the step gets a new target. Ids that UI-PASS-2 7.3 already maps are not repeated in its "new ids" list.

| Screen | Ids |
|---|---|
| Main frame | ★`tabbar`, ★`tab.squad`, ★`tab.plan`, ★`tab.club`, `tab.home`, `tab.more` |
| Every screen | `help.button`, `screen.back` |
| Home | ★`home.next_card`, `home.play`, `home.attention`, `home.tile.standing`, `home.tile.chem`, `home.offer` (the inline offer card) |
| Squad | ★`squad.bench.0` (first bench card; **new, replaces `roster.row.0`**), ★`roster.card.head` (header of the player sheet), `squad.bench.expiring` (replaces `roster.row.expiring`), `roster.card.contract`, `roster.card.renew`, `roster.card.release` (all three inside the player sheet; "card" now means the sheet), variant 5-B only: `squad.token.top`, `squad.picker.head` |
| Plan | ★`plan.tile.practice`, `plan.tile.training`, `plan.tile.chem` |
| Practice | ★`practice.quick` |
| Training | `training.preview`, `training.row.0`, `training.picker` |
| Chemistry | `chem.summary`, `chem.pentagon`, `chem.training` |
| Pre-match | ★`prematch.matchups`, ★`prematch.start_draft` |
| Draft | ★`draft.choices` (Coach bar plus the hero grid, steps 12 and 13), ★`draft.slot_list` (the "Plays as" lane row in the hero sheet), ★`draft.sheet.confirm` (**new**: the sheet's Pick or Ban button), ★`draft.auto_rest` (the Auto-finish text button in the header), ★`draft.game_plan`, `draft.hero_grid` (no longer a first-run target) |
| Game Plan | ★`gp.coach`, ★`gp.coach_apply` (**new**: Apply in the Coach sheet), ★`gp.start_match`, `gp.edge`, `gp.contests`, `gp.tabs` (the phase strip), `plan.chip` (the Plan chip, lesson L5), `gp.sliders` (the detent tracks) |
| Match | ★`match.controls` (Speed and Skip together), ★`match.report_btn` |
| Report | ★`report.result`, ★`report.why` (the hero stat), ★`report.why_sheet` (**new**: the factor bars in the sheet), ★`report.continue` (the sticky coral footer), `report.payoff`, `report.tip` |
| Club | ★`club.tile.form`, `club.tile.finance`, `club.tile.fa` |
| Standings | ★`stand.metric` (the Points / Form switch; **replaces `standings.form_list`**), `standings.table`, `standings.tabs` (the three views) |
| Finance | `fin.balance`, `fin.cap`, `fin.sponsor` |
| Free agents | `fa.filters`, `fa.row.0` |
| Settings | `settings.help_card`, `settings.replay` |

**Contract with the layout redesign (UI-PASS-2).** Items 1, 2 and 5 are as in v1; items 3, 4 and 6 are replaced because the sheets and the three-view Standings made them moot.

1. Every id above must exist on its screen in the state the step needs it.
2. A 96 x 96 px corner is reserved for `help.button` on every screen. Top right everywhere except the arena (right end of the controls row). The Draft header wireframe now shows the slot.
3. **(was: give Squad rows a card edge.)** Every tagged target is a DepthCard, chip, button or lane-map token (UI-PASS-2 5.1), so the hole always has a visible boundary. Never tag a bare Label. Lane-map tokens and bench cards meet this by construction.
4. **(was: scroll an opened Squad row into view.)** A player sheet opens in place, so nothing is below the fold. Replaced by the **sheet contract**: (a) the overlay draws above `BottomSheet`; (b) the sheet's scrim must not swallow a tap inside the hole; (c) every sheet control a step needs has an id (`draft.sheet.confirm`, `gp.coach_apply`, `report.why_sheet`, `roster.card.*`); (d) sheets raise their open events (`open:player_card`, `draft:sheet`, `gp:coach_open`, `open:report_why`); (e) a Coach sheet with nothing to change shows a Close button and raises `gp:coach_close`.
5. **Colour must not be the only cue** for anything a step names: stronger and weaker rows in Pre-match, strong heroes this patch (an up arrow, UI-PASS-2 6.3), "your club" in the standings (the YOU pill). Colour-blind mode only swaps the two colours; it does not add a cue.
6. **(was: the five Standings tabs break words.)** Standings has **three views** (Table, Playoffs, History) and a **Points / Form switch** in the Table header (UI-PASS-2 6.5). The Club tile "Form Rating" must open Standings on the Table view with the switch already on Form (a `metric` argument to the screen), because step 26 asks the player to tap Points. The tab ids `standings.tabs` and `stand.metric` stay; the five old tab ids are gone.
7. **New:** two controls may share a hole. A step that lists two ids gets their bounding rectangle (step 14: `draft.slot_list` plus `draft.sheet.confirm`). The two must sit within one sheet and within 300 px of each other.
8. **New:** the Auto-finish "Sure?" state must be holdable (`hold_armed`) while step 15 is up, and the Coach bar's Take must raise `draft:ban` or `draft:pick`.

## 9. Test plan for QA Automation

The existing suites already run the real Main scene headless (`ui_smoke.gd`) and inject real touch events (`ui_touch.gd`, `finger()`). The tutorial tests belong in a new `tests/tutorial_tests.gd` plus scene, using both: logic checks through a small testing interface, and real finger events for taps.

**Hooks the programmers expose for tests** (read-only except the pins): `Coach.step_id`, `Coach.is_up()`, `Coach.target_rect()`, `Coach.hole_rect()`, `Coach.card_rect()`, `Coach.fallbacks`, `Coach.nudges`, `Coach.skip()`, `Tutorial.steps()`, `Tutorial.pin_seed(n)`, `Tutorial.reading_pace(seconds)` (0 in tests).

**Snapshot used for "no pollution":** before and after the tutorial game compare `Payoff.snapshot(gs)`, the standings table, `form_rating` of every club, every player's form, morale, fatigue, `d["bonds"]`, `d["plan"]`, `d["exh"]`, `exh_day`, `exh_n`, `d["history"]`, `d["career"]`, `d["pace"]`, cash and the ledger, `d["round"]`, sponsor. Every one must be equal.

| # | Test | How | Pass when |
|---|---|---|---|
| 1 | **Scripted full run** | New game, pin seed. Loop: read `step_id`, check the target exists, has a non-zero rect inside the viewport and the hole equals it plus padding, check the text key resolves and has 25 words or fewer, then inject a real touch at the hole's centre (or press Next for info steps; on a two-stage step touch stage A, wait for the hole to move, touch stage B). Compare with the expected sequence from the step table. | All 27 steps in order, state ends `done`, the no-pollution snapshot is equal, the scripted run finishes in under 60 seconds of test time. |
| 2 | **Skip at every step** | For k in 1..26: fresh save, advance k steps, press Skip. | Overlay gone; every tab and button works; state `skipped`; for k in 10..20 the game can be finished by hand and leaves no `exh` state; the real plan is untouched; Undo within 4.5 s restores step k; after the toast, the tutorial stays skipped. |
| 3 | **Tap elsewhere at every step** | At each step inject taps at 5 points outside the hole (corners, centre, over the tab bar). | No step change, no screen change, no game-state change; `nudges` rises; the second line shows after 2 taps; Skip pulses after 4. Step 19 passes taps through (screen buttons outside the ring still work). |
| 4 | **Large-text run** | `App.set_large_text(true)`, repeat test 1 and add per-step geometry checks. | Card inside the safe area, not overlapping the hole, at most 45 percent of the height (35 percent on compact sheet steps), buttons at least 96 px high, no body line below 24 px, no body line clipped (line count times line height fits), hole inside the viewport. Record the largest card height seen (paper estimate is 477 px of 1113). |
| 5 | **Colour-blind and animations off** | Repeat test 1 with `UI.colorblind` on and then with `UI.animate` off. | Same sequence; with animations off every motion is instant (no running tween on the overlay); no coach text contains a colour word. |
| 6 | **Resume** | Save and reload at every step. | Resume card shows; Continue rewinds to the chapter start in the table; stale sandbox plan and `game.live` are cleared; no duplicate game. |
| 7 | **Old save** | Load a fixture save without a `tutorial` key. | No overlay; one inline offer on Home; "No thanks" removes it for good on the device; "Show me" starts step 1. |
| 8 | **Replay** | Finish, then Settings, Replay; repeat in the playoffs and done phases and when practice was already used that day. | Runs end to end each time; step 2 is skipped when there is no next game; the replay game is a different game (`n` rose); no pollution. |
| 9 | **Returning player** | New game after a finished tutorial. | Inline offer card, no modal. |
| 10 | **Lessons** | For each lesson: set the unlock state, take the offer, run it with real touches, then also skip it midway. | Each unlocks only on its rule; at most one offer per match day; none during the tutorial or round 0; Later snoozes three match days then dismisses; steps run in order; **no lesson changes the game state** (same snapshot, no contract signed or released, no focus changed). |
| 11 | **Help sheets** | Open "?" on every screen in section 5.1, then close three ways (Got it, dim tap, Android back). | Content present; dot clears and stays cleared after reload; draft timer and match clock pause while open and resume after; the match result is identical with and without opening it. |
| 12 | **Glossary** | Open every term from the Glossary and from sheet chips. | 49 entries, each with name, definition, where; "Where to see it" goes to the right screen; Back returns to the sheet. |
| 13 | **Fallback** | Remove one target (hide its control) in a test build. | Fallback card within 2 seconds, `fallbacks` increments, the tutorial can still finish with Next. Test 1 fails if `fallbacks` is more than 0 in a normal run, so a layout change that drops an id is caught on the next build. |
| 14 | **Strings audit** | Script over `i18n/en.json`. | Every `tut.*`, `les.*`, `help.*`, `gl.*`, `settings.help*`, `tut.nudge` key exists; no `[[` placeholders; coach text at most 25 words (every `tut.*` key, including stage-B lines and shortcut buttons, counted on its own), definitions at most 22, help lines at most 20; no colour words in coach text; every glossary id referenced by a sheet exists; **no player-facing string contains "advisor"** and the helper is "Coach" in every `draft.*`, `gp.*`, `train.*` and `club.*` string (section 13). |
| 15 | **Overlay cost** | Measure average process time while a step is up, and with none up. | No process work when no step is up; under 1 ms per frame on the build computer. Phones are not covered (see risks). |
| 16 | **Android back** | Send the go-back notification at steps 1, 12 and 21. | The leave sheet shows, nothing under the overlay moves; back again closes the sheet. |
| 17 | **Pollution of the tutorial game itself** | Run the tutorial game and compare the snapshot. Also check Quick mode on, a pre-used practice day, and the pace log. | Equal in every case; Quick mode ignored in the tutorial game only; pace log unchanged. |
| 18 | **Existing tests** | Update `ui_smoke.gd` lines 156 to 173, which assume the Home tip card, to the new "?" dot logic. `ui_pass_tests.gd` (Payoff tips) is untouched. Also update any test that reads `draft.auto_rest`, `gp.coach` or the strings listed in section 13. | The whole existing suite stays green. |
| 19 | **One-tap audit** (new in v1.1) | For every step, fresh game at that step: count the real touches needed along the shortest route to the next step (the real control, or the card's one-tap button), and along Skip. Cover each shortcut (Take, Let the Coach finish, Apply for me, Next on step 22). | Every step needs exactly 1 touch to continue and 1 to skip, on every route; each shortcut leaves the game in the same state as the two-tap route (compare the sandbox plan, the draft state, the open sheets); a step is passed over (not skipped silently) when `skip_if` fires. |
| 20 | **Sheet steps and z-order** (new in v1.1) | At steps 6, 12, 14, 17, 22 and lesson L3: inject real touches. Touch the dim, the sheet's scrim, the drag zone and Android back; then touch inside the hole. Also run an info step over a Renew button. | The overlay is above the sheet; touches in the hole reach the sheet control; the scrim and drag zone cannot close the sheet; the info-step blocker swallows a tap on Renew (no negotiation opens); no step leaves a sheet open over the next target. |

Manual checks the scripts cannot do (for testers): the form question "In my first 5 minutes I understood what to do next" (the existing feedback form has "First 5 minutes understood (1-5)", target average 4 or more), a stopwatch on the first game, and any step where a new tester hesitates for more than 10 seconds.

## 10. Build tasks for the Lead Programmer

Sizes are my rough guesses: S is half a day, M is one to two days, L is three days. They have not been checked with the programmers.

| # | Task | Size |
|---|---|---|
| B1 | `UI.tag()` registry, automatic `tap:` events, `Main.show_screen` `screen:` event, `Screen.help_id()`; tag the 27 first-run ids and the lesson ids (section 8) | M |
| B2 | `CoachOverlay`: own canvas layer above `BottomSheet`, four-panel dim, info-step hole blocker, ring, pointer, card (compact variant), Next, Skip and one-tap shortcut button, settle wait, scroll into view, large-target clipping, fallback card, nudge rules, toast queue, back handling, animation limits | L |
| B3 | `Tutorial` engine and `tutorial_v1.json`: step state machine, stages, shortcuts, `skip_if event_seen`, events (section 7.5), chapters, resume, Skip with Undo, device and save state, `legacy` handling, Debug info line | M |
| B4 | The tutorial game: `tutorial` flag, no side effects, opponent rule, sandbox plan, Quick mode and timer overrides, Practice tutorial mode, report card, pace log exclusion, seed stream | L |
| B5 | `help.button` in the `Screen` frame, `HelpSheet`, dot memory, pause hooks for draft and match, replace `Tips.show` | M |
| B6 | Help content for 20 screens, glossary data (49 terms) and `ScreenGlossary`, about 255 new strings | M |
| B7 | Lessons: unlock rules, offers (Home, Report, Draft complete, Club, Season summary), `ScreenLessons`, eight lesson definitions | M |
| B8 | Settings card "Help and learning", Replay and Reset, old-tip migration, legacy offer, returning-player offer | S |
| B9 | Strings: add every key in this spec to `i18n/en.json`, make the Coach renames of section 13, retire `tip.hub*`, `tip.prematch*`, `tip.report*` (not the Payoff `tip.*` keys) | S |
| B10 | `tests/tutorial_tests.gd` and scene (section 9, 20 tests) | M |
| B11 | Spike first: rect-following overlay with real touch on the Squad page, **a tap in the hole reaching a button inside a `BottomSheet` on a lower layer**, `ensure_control_visible` in nested scrolls, large text, the optional `_has_point` hole | S |

**Milestones.** M1, first-run tutorial playable and tested: B11, B1, B2, B3, B4, B8 (offers only), B9 (first-run keys), B10 (tests 1 to 9, 13, 17, 19, 20): about 12 days, plus about half a day for the v1.1 sheet steps (my guess, not checked with the programmers). M2, help everywhere: B5, B6, rest of B9, tests 11, 12, 14, 16: about 4 days. M3, lessons: B7, test 10: about 3 days. Total about 19 days. Build **after** the layout (UI-PASS-2) settles, or in step with it by tagging ids as each screen is rebuilt.

## 11. Risks and limits

- **Nothing here has been run.** No Godot, no phone. The overlay, scroll-into-view in nested scroll areas, large-text geometry and touch pass-through through the hole are all designed from reading the code and screenshots. The spike (B11) comes first for that reason.
- **Time budget is an estimate.** 4 to 6 minutes for 27 steps has not been measured. If testers need more than 7 minutes, cut steps 3 and 10 (info only) first, then 6 (v1 also listed 26, which is now a tap step and stays).
- **The first game can still be lost.** The opponent rule only avoids a stronger club. Step 21 has a loss text, but a first-ever loss may still sting; the Lead Game Designer may want a stricter rule.
- **Word choices rely on UI changes outside this document** (section 8, contract items 3 to 6). If those cues are not added, steps 10, 13 (the up arrow) and 26 (the marked club) name something a colour-blind player cannot see.
- **Sheet steps are the riskiest part of v1.1.** An overlay above a sheet, with a tap passing through the hole into the sheet, is designed from the Godot docs, not run. If the spike fails, the fallback is to draw the stage-B hole as a card-only step (Next on the card runs the control's action, as the shortcuts already do).
- **Two names for the player were possible.** The GDD calls the player "the club owner and head coach" and `club.pick.hint` says "You are the owner and coach". With one helper called Coach, the player must be called **Manager** (or owner) in every string, or players will think the Coach is them. Section 13 lists the string; the GDD wording belongs to the Lead Game Designer.
- **"Form" means two things.** The Points / Form switch says "Form" (a club's Form Rating); player cards say "form" (recent performance). Step 26 and the help row say "Form Rating" to keep them apart; the switch label itself is the Narrative Designer's call (hand-off in UI-PASS-2 7.4).
- **Step 19 text changes in 0.8** (the arena). It is written (`tut.watch.arena`) but cannot be checked until the arena exists.
- **Round numbers for lesson offers are guesses.**
- **The existing welcome-tips decision in `company/DECISIONS.md`** ("a guided first game stays optional until testers show they need it") is superseded by the Founder's feedback; the Producer should log that.
- **Data worth a second look by the Lead Game Designer:** Home shows "10 contracts end this season" under "Needs your attention" on round 1 of 18 (`04_hub.png`). It competes with the first thing a new player should see. Suggest showing it only from round 9.

## 12. Strings for the chrome around the steps

Exact English for the Strings table (coach text is in sections 3 and 4.2, glossary in 5.3, help sheets in 5.1).

| Key | Text |
|---|---|
| `tut.next` | Next |
| `tut.start` | Start |
| `tut.skip` | Skip tutorial |
| `tut.go_home` | Go to Home |
| `tut.nudge` | Tap the glowing spot to go on. |
| `tut.skipped_toast` | Tutorial skipped. You can replay it in Settings. |
| `tut.back.h` | Leave the tutorial? |
| `tut.back.body` | Your game is safe. You can replay the tutorial any time in Settings. |
| `tut.back.keep` | Keep going |
| `tut.resume` | Welcome back. Continue the guided first game? |
| `tut.resume.go` | Continue |
| `tut.offer.legacy` | New: a guided first game and help on every screen. |
| `tut.offer.returning` | Welcome back, Manager. Want the guided first game again? |
| `tut.offer.yes` | Show me |
| `tut.offer.no` | No thanks |
| `tut.fallback` | We cannot find that on this screen. Tap Next to go on. |
| `tut.left` | Leaving the tutorial here. You can replay it in Settings. |
| `tut.report_card.h` | Practice result |
| `tut.report_card.body` | Nothing in your season changed. This game was only for learning. |
| `tut.practice.note` | Tutorial match: nothing in it counts. |
| `tut.draft.note` | No timer in the tutorial. Take your time. |
| `tut.ban.confirm` | Tap Ban to confirm. |
| `tut.coach_rest.sure` | Tap Sure? to let the Coach finish. |
| `tut.coach_suggest.apply` | These are the changes. Tap Apply to use them. |
| `tut.why.sheet` | Each bar is how much one factor moved the result. Luck is the random part of every game. |
| `tut.watch.arena` | Your team is the circles. Watch the fight, or use Speed x2 or Skip to the end. |
| `tut.squad_token`, `tut.picker` | Variant 5-B only: see section 3.2 |
| `tut.shortcut.coach_rest` | Let the Coach finish |
| `tut.shortcut.apply` | Apply for me |
| `tut.ch.1` to `tut.ch.7` | Find your way / Your squad / Set up a game / The draft / Plan and watch / The result / The league |
| `help.got_it` | Got it |
| `help.see` / `help.do` / `help.know` | What you see / What to do / Good to know |
| `help.words` | Words on this screen |
| `help.lesson` | Take the lesson |
| `help.glossary` | Open the glossary |
| `lesson.offer` | New lesson: {title} (about a minute) |
| `lesson.show` / `lesson.later` | Show me / Later |
| `lesson.new` / `lesson.done` | New / Done |
| `lesson.na` | Not available right now |
| `lesson.title.l1` to `.l8` | The league table and playoffs / Training and rest / Contracts / Bonds and chemistry / Game Plan in depth / Money and the wage cap / Signing a player / What a game changed |
| `settings.help_h` | Help and learning |
| `settings.replay` | Replay the guided first game |
| `settings.replay_confirm` | Replay the guided first game? It is a practice game. Nothing in your save changes. |
| `settings.replay_yes` | Replay it |
| `settings.lessons` | Lessons |
| `settings.glossary` | Glossary |
| `settings.help_reset` | Show help hints again |
| `settings.help_reset_done` | Help hints will show again. |

## 13. One helper name: Coach (Producer ruling, wave 1b)

**Rule.** In every player-facing string, the helper that suggests bans, picks, game plans and training is **Coach** (capital C, no "the advisor", "assistant" or "AI"). The player is the **Manager** (or "owner"); the player is never "the coach", or players will think the Coach is them. This matches the GDD's fixed Coach staff level (Head Coach, level 2 for every club): the Coach is that staff member. The code keeps `ai_choice()` and `gp.coach` as identifiers; only the words change.

**Game strings in `game/i18n/en.json` that must change** (line numbers as of this review; found with a search for advisor, coach, suggest, AI, chooses):

| Key (line) | Today | Must become | Why |
|---|---|---|---|
| `draft.recommended` (151) | Take advisor's choice: {hero} | Retire. Replace with `draft.coach_suggests` "Coach suggests: {hero}" and `draft.coach_take` "Take" (the Coach bar of UI-PASS-2 6.3) | name, and the new layout has a bar plus a button |
| `draft.auto_rest` (162) | Let the advisor finish the draft | "Auto-finish" (the header text button of UI-PASS-2 6.3). New `draft.auto_sure` "Sure?" for the armed state | name, and the two-tap confirm |
| `gp.coach` (244) | Coach's suggestion | "Coach" (the footer button; UI-PASS-2 6.4 renames it). New keys for the diff sheet: title, "Apply", "No changes needed", close | the button is now a short name and opens a sheet |
| `club.pick.hint` (44) | You are the owner and coach. Players pick their own heroes in the draft, you steer the draft and set the lineup. | You are the owner and manager. Players pick their own heroes in the draft, you steer the draft and set the lineup. | the player must not be called "coach" while the helper is Coach |
| `tip.prematch` (628) | ... if it runs out the coach chooses for you. | Already says "coach"; make it "Coach". The whole key is retired by section 5.2 (its "green rows" wording fails in colour-blind mode); the Pre-match help sheet carries the line | consistency |
| new `draft.timeout_toast` | (none) | "Time is up: Coach picked {hero}" (UI-PASS-2 6.3 writes it with a lower-case "coach") | name |
| `train.coach_all` (296), `train.auto_btn` (310) | Coach picks for everyone / Coach's choice | **No change.** Already Coach. | listed so nobody changes them |

Outside `en.json` (not mine; for the Lead Game Designer): GDD v1 line 12 ("the club owner and head coach"), 7.8 ("the coach's second lever") and 7.3 name the player as the coach; code comments in `game_plan.gd` do the same. They are not shown to players, but they will confuse the next writer. Suggested: "owner and manager" and "the Manager's second lever".

Tutorial and help keys already use "Coach": `tut.coach_suggest`, `tut.coach_rest` (renamed from `tut.advisor_rest`), `tut.shortcut.coach_rest`, `gl.coach.*`, `help.draft.*`, `help.gameplan.*`.
