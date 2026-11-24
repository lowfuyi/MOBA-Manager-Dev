# ESMO lessons: the Founder's queue of 2026-11-24

Saved as given by the Founder (Q0a). Ideas from competitor research are taken as ideas only: no names, label text, art or
layouts are copied, and no competitor name appears in any player-facing text. Progress is logged in `docs/OVERNIGHT-LOG.md`;
parked items are in `docs/PENDING-CONFIRMATION.md`.

---

Founder note, 2026-11-24. Keep working while I finish my ESMO and Gloamline game recordings. Work through the queue below in order, unattended. Do not stop to ask: anything that needs my decision goes into docs/PENDING-CONFIRMATION.md (item, why, options, your recommendation) and you move on.

RULES (unchanged)
- CLAUDE.md build rules R1 to R7. No change to src/sim/ without my approval, and the golden hash stays. Read-only use of the sim is fine.
- One increment = one commit with explicit paths. bash tools/check_fast.sh must print ALL GREEN before every commit. Push after each green commit.
- Copy only through tools/merge_copy.py. Respect the perf budget and the 24 px type floor. Saves change only by additive keys.
- Log rulings in company/DECISIONS.md and notes in company/LEDGER.md.
- Max 2 tries per item, then park it as BLOCKED with the reason.
- The ideas come from competitor research (ESMO). Take ideas only: never copy names, label text, art or layouts. No competitor name in any player-facing text.
- Do not build an APK until Q5. Check free disk space on C: first.

Q0 Housekeeping
a. Save this whole message as docs/design/ESMO-LESSONS.md, and Part B as docs/PENDING-CONFIRMATION.md.
b. DECISIONS.md: Founder decision 2026-11-24: the in-match map's bases go DIAGONAL (opposite corners, the genre standard), not top and bottom ends. Implementation waits for my recordings (see P1). Also log in IP-RISK-LOG: our camera view name "Field" matches the competitor's "Cam: Field" button (generic word, low risk; the IP Checker confirms).
c. Tester notes: if docs/TESTER-UPDATES.md or its CLAUDE.md rule is missing, create them. Rule: every release gets a plain-language tester note, newest first, in the format *[Gloamline] [version] Updates, Major|Minor update* with sections What's new, What to try, Known issues, Where to find it, How to update, Feedback. Major = the middle number changes, and Major notes get a themed title. Mark systems that do not affect results yet as "informational only for now". Say clearly whether saves carry over (only if check_save_compat passed). Never post anywhere yourself. Write the 0.12.0 note (Major) now.
d. Refresh the CLAUDE.md "Current state" to 0.12.0 and this queue.

Q1 Audit (read-only): docs/design/ESMO-AUDIT.md. For every item in Q2d and Q4, mark HAVE, PARTIAL or MISSING in Gloamline, with file references and effort (S/M/L). Q4 items are built only if the audit says PARTIAL or MISSING and they fit one increment.

Q2 Read-only analysis tools (results into docs/design/, no sim changes)
a. Win rate per hero per role on 40,000 real-draft games per format (we have per hero only). List any hero outside 45 to 55% in a role it is used in.
b. Game Plan exploit sweep: run every existing Game Plan option, and the obvious pairs, against a neutral plan. Report win-rate deltas. Flag any option above +3 points or any dominant combination. Report only, tune nothing.
c. "Does the draft decide too much" metric: how often the team with the better draft wins, by rating-gap bucket. State your definition of draft score.
d. Matchup table: "struggles against X" per hero from simulated games, with the minimum sample size stated. Write game/data/hero_matchups_v1.json with its definition in the file. Display only.

Q3 Feasibility note only (prep for P1, no map edits): docs/design/MAP-DIAGONAL-FEASIBILITY.md
How does the sim's map graph relate to arena_map.json and the event-log positions? Can the lane order and travel distances stay identical while the drawn layout goes diagonal (Top along the west then north edge, Bot along the south then east edge, Mid a diagonal causeway across the lake)? List what must change: map data, ground art, Squad anchors, role glyphs, Choreo, vision. Estimate effort. Do not edit the map.

Q4 Gameplay-screen work (each one commit, no arena or match-view changes)
1. Role fit number wherever a role is set (Draft, Game Plan lineup, Squad), plus "to move to X, train A and B". Only if a real role-fit value already exists.
2. Scouting summary on player cards and recruit lists: letter grade, one-line note, up to 2 pros and 2 cons, from existing attributes with fixed templates. Player labels and multi-sort if cheap.
3. Reasons when a player declines or counters a contract ("wage too low", "squad too weak"). Expose the existing decision's reason; do not change the decision.
4. "Why did my rating move" breakdown in Report or Standings, using only values we really compute. Never invent components.
5. Club finance: a short-period income and expense mini chart plus income and expense by category, if a ledger exists. Additive save keys only.
6. Player records and achievements on the player page, and a prize leaderboard, from existing career data.
7. One-tap "skip and claim all" through a batch of finished matches or rewards, if missing.
8. Hero matchup hint on hero pages, from Q2d.
9. Saved draft plan per opponent (priority picks, bans, fallback; runs automatically if I skip the draft). Only if it fits one increment, otherwise park it.
Game Plan slider wording (word ends, one-line effect under each) only where the audit shows a gap. The DetentTrack already has end labels and an effect line.

Q5 Release
Version 0.12.1 (Minor, code 20): full gate (tools/run_all_checks.sh), signed APK, web redeploy to the tester link (verify build id, noindex header, title screen), the 0.12.1 tester note, APK copied to C:\Users\Fuyi\Downloads, and docs/MORNING-REPORT.md (done, skipped, BLOCKED, the Q2a to c numbers, phone test list, decisions I need to make).

PART B: PARKED. Do not start. Each needs my recordings, my decision, or approval to change the simulation. Put all in docs/PENDING-CONFIRMATION.md.
P1 Diagonal map redesign (Q3 prepares it). Needs the recording, a map concept, an IP re-screen and my sign-off.
P2 In-match HUD changes: full-width gold-lead bar, objective respawn timers on the map, per-lane gold difference between opposing rows, camera button in the top bar, bottom player panel. Needs the recording.
P3 New Game Plan choices (win condition, objective style, fight discipline, level-1 plan, "when behind" plan with a gold threshold), comeback levers (COMEBACK-PROPOSAL.md), pre-match Team Talk. These change the simulation, so they need my approval and the Q2b sweep first.
P4 Condition and fatigue that gate training, hidden per-attribute potential with scouted estimates, hero difficulty affecting results. Gameplay changes; my decision.
P5 Sponsors with missions, manager level and talents, extra tournament formats (Swiss, double elimination).
P6 Linked cloud save, remote balance data, Steam, monetisation. Beta items.
P7 AI-vs-AI on v2 after a phone measurement. Art route, trademark search, release keys, iOS: mine.
