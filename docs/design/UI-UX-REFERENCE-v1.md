# UI/UX Reference Analysis v1 — ESMO+ (two videos) and our own direction

Date: 2026-11-08 · Author: Claude (producer) · Status: findings for founder review. No game code was changed.

Sources (screen recordings supplied by the founder, analysed frame by frame):
- Video A, `37650.mp4`, 12:17: a tour of the menus and management screens.
- Video B, `37653.mp4`, 22:11: one practice match from matchmaking to the end of the game.

## 1. How this was analysed (two passes, as requested)

- **Pass 1:** even sampling (A every 10 s, B every 15 s), contact sheets, notes on every screen.
- **Pass 2:** different sampling offsets (A at 5 s + 10 s steps, B every 7 s over the first 280 s), scene-change detection, full-resolution frames of the live match and the end, and an audio check.
- **What pass 2 changed:**
  - The video does not end on the "Red win" dialog. It cuts to a full-screen third-party ad with an Install button. The after-match result screen is never shown.
  - The match is about 36 minutes of game time, watched at 2x, which is about 18 real minutes.
  - About 3½ minutes pass between pressing "Find match" and the first gameplay (queue about 70 s, server wait, draft about 90 s, tactics, loading).
  - Pass 2 added many details pass 1 had missed (listed at the end of the working notes).
  - Both videos are essentially silent (A is silent; B has a few short sound peaks, no speech), so nothing was lost without audio.
- **Limits:** this is analysis from recordings, not hands-on play. I cannot judge frame rate, touch feel or loading times on a real phone, and I never saw the post-match report.

## 2. What ESMO+ does

### 2.1 Structure
- Home is a long scrolling dashboard of tiles. There is no bottom tab bar. Every sub-screen has a back arrow and a title.
- The tiles are: Inbox, Meetings, Talents, subscription, Finance (mini bar chart), Sponsorship (ring), Players (idle count and contract days), Recruitment.
- A second hub, "Team" (5 player cards on top, then Playbook, Skins, Analytics, Dynamics, Matchmaking, Competitions, Schedule), is where you start a match.
- Depth is high. Examples: Players → player → Dynamics → Bonds → tap a link. Playbook → Heroes → hero → Meta → matchups.

### 2.2 Management loop
- **Training:** "Assign a task" with a task type, 1 / 3 / 7 hours, a player list, and an "Impacts" panel (Experience, Ability, Morale, Condition as 5-dot ratings). Then a big "Start the task" button.
- **Results:** a "Task complete!" screen with a pager, "+1 Accuracy" lines per player, and a "Lv. Up!" tag.
- **Missions:** Sponsorship daily and weekly missions with progress bars and "Claim".
- **Scouting:** scouted players show attribute ranges (for example "Accuracy 48-54") and a Knowledge: Limited badge, so uncertainty is shown honestly.
- **Rows:** player rows show condition %, morale %, role-rating chips, and a rest timer.

### 2.3 Match flow (video B)
- Matchmaking has three tabs, queue and fairness dropdowns with explanation sheets, an in-queue state with Cancel, and a gold ad banner.
- A globe animation with real clubs and regions fills the "server allocation" wait.
- Draft: a 3-step stepper (DRAFT / TACTICS / GAME), amber timer chips, BAN / PICK labels, a hero grid with role filter tabs that show a lock when a role is filled, a bottom sheet with a full-width Ban (pink) or Pick (green) button, and picks listed with the hero name and role icons.
- Tactics: 7 collapsible sections with count badges, "41 customized", Load / Save, a READY toggle, and a 3-minute timer.
- Live match: scoreboard, map view, intent labels, a feed, five head-to-head rows, objective chips, and a settings sheet.
- End: a dim overlay "Red win" with "Remove Ads", then a full-screen ad.

## 3. What works well (keep the idea, make it ours)

1. **Showing what an action will do before you commit:** the Impacts dots and the Match Fairness / Queue Time explanation sheets.
2. **Honest uncertainty:** scouting ranges plus a Knowledge badge.
3. **Tutorial hints that can be dismissed once:** green "Understood" cards, and "Preview feature" and "Bonds are informational" banners that set expectations.
4. **A visible stepper through a long flow:** DRAFT / TACTICS / GAME.
5. **Intent labels on the map** ("take drake now", "holding wave"): the player sees why the AI acts. This is the best idea in video B.
6. **Colour as meaning:** green for gains and wins, pink for ban, amber for time, red dot for attention, tinted rows for wins.
7. **Skeleton loaders** and consistent back arrow and title placement.
8. **Head-to-head rows** that make comparison easy.
9. **Team Plan pre-fill with counts** (Load / Save) so repeat matches are fast.

## 4. Pain points (these are where we can win customers)

| # | Problem seen | Why it hurts satisfaction | Evidence |
|---|---|---|---|
| P1 | Upsell and ads everywhere: an ESMO+ tile on Home, banners on matchmaking, "Remove Ads" in the end dialog, a full-screen ad right after the match, features locked behind a plan ("Skip & Claim All" with a lock, historical data, strategy folders, quotas) | Feels like paying to remove friction that was put there on purpose. Trust drops. | A 0:49-1:09, 5:39-7:39, 9:24; B throughout and at the end |
| P2 | The match is far too long: about 36 game-minutes (about 18 real minutes at 2x), after about 3½ minutes of queue, server wait and loading | Cannot be played on a commute. Players watch or leave. | B 0:34-4:18 and 4:37-22:08 |
| P3 | Waiting theatre: matchmaking queue, "server is being allocated, up to 2 minutes", globe, three-step loading | Dead time before the thing the player came for | B 0:34-4:18 |
| P4 | No bottom navigation, long dashboard, deep menus (3-5 taps to a player's Bonds) | Hard to build a mental map; easy to get lost | A throughout |
| P5 | Dense text and tiny grey-on-black type on stat-heavy screens (hero Stats, Meta tables, Items) | Hard to read on a phone, risk for older or tired players | A 5:09-9:14 |
| P6 | Dense live HUD: scoreboard, objective chips, map, feed and 5 rows all on one portrait screen; map objects are tiny | Hard to follow what matters; the story of the match is hidden in the feed | B 4:37-22:08 |
| P7 | Features that look interactive but only inform: Bonds "don't affect match results yet", Dynamics preview | Teaches players to ignore the screen | A 3:19 |
| P8 | Modals that block with an external call to action ("Join the Discord", OS camera permission for QR) | Leaves the game flow | A 5:49, 11:04 |
| P9 | Result and reward feedback is thin: no after-match screen seen, a bare "Red win" | No payoff moment | B 22:05 |
| P10 | Idle management is chore-like: assign hours of Rest to complete a mission | Reward loop feels like homework | A 2:44 |

## 5. Our direction: our own flair and design

### 5.1 Principles
1. **Five-minute rhythm.** Every screen is built so that a whole match day (check, pick, play, see result) can be done in about 5 minutes and about 10 taps. Skip and fast-forward are always free.
2. **One next step.** Home leads with a single big "Next match day" card. Everything else is a clearly secondary tile.
3. **Bottom tab bar** with 5 places (Home, Squad, Plan, Club, More). Nothing is deeper than 2 taps from a tab.
4. **Zero ads, zero upsell walls in the core loop.** Subscriptions are postponed (founder decision). If monetisation returns, it must never block or delay the match loop.
5. **Preview, then commit, then celebrate.** Every action shows the expected change as numbers with arrows before the confirm button, and a payoff screen after.
6. **Explain the why.** Intent labels, "why this changed" lines, and tap-for-details on every number.
7. **Big, calm, readable.** Minimum touch target 48 dp, body text 16 sp or larger, contrast checked for both dark and light.
8. **No fake waiting.** We are offline and single player, so no queue, no server screen.

### 5.2 Visual identity (founder decision needed, visuals stay last)
Three directions, all original and none close to ESMO+ (which is dark charcoal with lavender buttons and olive-gold upsell):
- **A. "Arena Dusk":** deep navy and teal, warm coral accent, soft glows, rounded cards. Fantasy-lite, friendly.
- **B. "Parchment Pro":** warm off-white and ink, one bold accent colour per club, serif headings. Distinct from every esports app, readable outdoors.
- **C. "Neon Draft Room":** near-black with two saturated team colours, sharp geometric shapes. Closest to the genre; riskiest for looking generic.

My recommendation: **A as the default theme, with a light theme later**, because it is distinctive, fits fantasy-lite, and keeps contrast easy. Final choice is yours.

### 5.3 Motion and feedback ("how it reacts")
- Press state on every button within 100 ms, and a subtle scale on press.
- Numbers count up (gold, XP, form) instead of jumping.
- Bars fill with an ease-out, and a tick appears when a threshold is crossed.
- Toasts for small events, a full result card for big ones.
- Haptics and sounds: short, optional, off-switchable in Settings (ESMO+ has a vibration toggle, we add sound too).
- Transitions between screens: slide for forward, fade for tabs. No transition longer than 250 ms.

## 6. Mapping to our screens

| Our screen | ESMO+ equivalent | Keep | Avoid | Our improvement |
|---|---|---|---|---|
| Hub | Home dashboard and Team hub | Tiles with a live mini-chart | Long scroll, upsell tiles | "Next match day" hero card, tab bar, 4-6 tiles max, red dot only for decisions that need you |
| Roster | Players list | Condition/morale chips, rest timer | Tiny chips, grey text | Larger rows, mood face from our Form/Morale, tap for detail sheet instead of a new page |
| Chemistry | Dynamics (Communication / Bonds) | Heat-map idea, tap a link for details | "Informational only" | Ours affects results, so say so. Change the layout from a generic pentagon of avatars to a **lane-based map layout** (Top / Jungle / Mid / Bot / Support placed like a map), which is more original and more meaningful |
| Training | Assign a task and Impacts dots | Preview of impacts | Hours-as-chore missions | Show exact deltas ("Form +1.5, Fatigue -0.2") and a before/after bar |
| Draft | Draft screen with stepper | Stepper, amber timers, role lock icons, bottom-sheet confirm | Long timers, tiny grid | Larger portraits, a "Coach suggests" chip, counters shown on tap, 15-20 s timers to fit the 5-minute game |
| Game Plan | Tactics sections | Count badges, Load/Save, READY | 7 deep sections | 3 sliders and 3 toggles that matter, with an "Auto" button |
| Match feed | Live map and feed | Intent labels, gold-diff strip | 36 game-minutes, dense HUD | Story-first: highlights as cards, 3 speeds plus Skip, objective timeline, tap a player to expand |
| Report | Not seen | n/a | Bare "Red win" | A payoff screen: score, MVP, Form and Morale changes, bonds that moved, one "what to try next" tip |
| Free agents | Scouting cards | Attribute ranges and Knowledge badge | Hidden quotas | Same ranges, show scout quality honestly, no paywalls |
| Finance | Finances tabs | Overview / Analytics split | Wage rows only | One chart, one number to act on ("You can afford X more wage") |
| Settings | Settings and Sounds & Vibrations | Per-mode toggles, UI vibrations | Account and ads items | Sound, haptics, text size, colour-blind mode, language, reset save |

## 7. Proposed UI backlog (for a later Alpha, after you decide)

| ID | Item | Effort | Impact on ease of use |
|---|---|---|---|
| UI-1 | Bottom tab bar and a "Next match day" hero card | M | Very high |
| UI-2 | Design tokens (colours, type scale, spacing) and the chosen theme | M | High |
| UI-3 | Button, card, chip and sheet components with press feedback | M | High |
| UI-4 | Preview-before-commit panels (training, signing, game plan) | M | High |
| UI-5 | Lane-based Chemistry layout | S | Medium (originality) |
| UI-6 | Story-first match view: highlights, 3 speeds, Skip | L | Very high |
| UI-7 | Payoff screen after each match | M | High |
| UI-8 | Draft redesign: larger grid, coach suggestion, shorter timers | M | High |
| UI-9 | Dismissible first-time hints | S | Medium |
| UI-10 | Text size and colour-blind options | S | Medium |
| UI-11 | Sound and haptics set | M | Medium |
| UI-12 | Real-phone usability test with 5 people | S | Very high (cannot be done by me) |

## 8. IP-safety rules for everything we build from this

- Learn flows and principles. Do not copy layouts one-to-one, icons, hero art, colour scheme, names or wording.
- Use our own terms (not Playbook, Dynamics, Talents, Solo Queue, ESMO+).
- The ads and Install page in the recording belong to third parties and are not reference material.
- The recording shows the founder's personal account details on the Settings screen. They were not used or copied anywhere.

## 9. Decisions needed from the founder

1. Pick a visual direction (A recommended) or ask for a different one.
2. Approve UI-1 to UI-4 plus UI-7 as the first UI pass (Alpha 0.5 candidate), or reorder the list.
3. Confirm that match length stays at 5 minutes or less, with a Skip button, even if the story view is richer.

## 10. Founder decisions and what was built (2026-11-08, Alpha 0.5)

- **Visual direction:** A "Arena Dusk" approved (the recommendation). B and C are not pursued.
- **First UI pass approved:** UI-1 (tab bar and Home card), UI-2 (tokens), UI-3 (components), UI-4 (preview panels) and UI-7 (payoff screen) are built in Alpha 0.5. The Founder's condition: the order must not hurt later parts, nothing is skipped, and notes are carried forward. Notes carried forward: the tab ids and back targets are per-screen (`tab_id()`), so a later pass can move a page between tabs without touching the others; all colours and sizes are tokens in `src/ui/ui.gd`; all visible text is in `i18n/en.json`.
- **Match length:** Founder was unsure; fixed 75-second watch window with a pace log (see GDD 8.7 and DECISIONS). Decided by data from the first playtest.
- **Found while checking screenshots (lessons for the next pass):** an expanding key label next to a shrink-to-end value label squeezes the value into one character per line, so value labels now have no wrap and a minimum width (`UI.kv_row`); a pentagon canvas wider than the card interior pushed the chemistry page past the screen edge (minimum width cut to 560); "decided 0% of the result" is meaningless, so a standout line shows only at 3 percent or more.
- **Next in the backlog:** UI-5, UI-6, UI-8 to UI-12 (section 7). UI-12 needs the Founder on a real phone.

