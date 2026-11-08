# Decisions log

## Decided

| Date | Decision | Decided by |
|---|---|---|
| 2026-11-07 | Game is MOBA-only (no other esports genres) | Founder |
| 2026-11-07 | Copy genre logic (roles, lanes, jungle, objectives, draft); invent all names, art, heroes, items | Founder |
| 2026-11-07 | Visual design for characters and items is postponed to the pre-launch phase | Founder |
| 2026-11-07 | Engine: Godot (provisional, revisit at P-001) | Producer, pending Founder |
| 2026-11-07 | Single player (offline, local device) is the first release; online comes in later updates | Founder |
| 2026-11-07 | Match presentation: text and event feed first; animated map is the end goal | Founder |
| 2026-11-07 | Setting: fantasy-lite; may change and develop later | Founder |
| 2026-11-07 | Monetization: tiered monthly or annual subscriptions (Basic, Pro+, Esports, our own version), modelled loosely on the reference game's tier structure. Postponed until the final game release; nothing is built in Phase 1 | Founder |
| 2026-11-07 | Release path and naming: the game's edition name changes with the update phase (see below) | Founder |
| 2026-11-07 | Platform: Android first; iOS only when demand grows | Founder |
| 2026-11-07 | Language: English for testing; more languages added at the live release (all text must be kept in translatable string tables from day one) | Founder |
| 2026-11-07 | Game Plan (small version: about 8 sliders, default plan, "ahead" and "behind" triggers) is in Phase 1 | Founder |
| 2026-11-07 | Team Bonds (pairwise Bond and Understanding, languages data field) is in Phase 1 | Founder |
| 2026-11-07 | Proposed by Producer, proceeding unless the Founder objects: turn-based calendar; free agents only in Phase 1; sponsor "lite" plus tutorial goals; finances screens; manager talents deferred (see REFERENCE-ESMO-ADAPTATION.md section 8 and decisions 4 to 8) | Producer (pending Founder) |
| 2026-11-07 | Proposed by Producer, proceeding unless the Founder objects: keep the 8 player stats; Potential becomes per stat; stat help sheets, mastery levels, derived KDA, career log; contract expiry reminders always free (see REFERENCE-ESMO-ADAPTATION.md section 9) | Producer (pending Founder) |
| 2026-11-07 | Global edition competition geography uses real regions; all clubs and players stay fictional | Founder |
| 2026-11-07 | Proposed by Producer, proceeding unless the Founder objects: Form Rating (redefined in GDD v1.4 as an Elo-style rating, K 24, because the 28-day-fade version measured only luck) and a trophy cabinet in Phase 1; multi-tier leagues, cups and region leaderboards wait for Global (see REFERENCE-ESMO-ADAPTATION.md section 10) | Producer (pending Founder) |

## Release path (Founder, 2026-11-07)
| 2026-11-07 | Producer decisions after the independent QA review (GDD v1.4), proceeding unless the Founder objects: Game Plan has 8 controls (within the approved 8 to 10), all zero-sum in rating, acting through three simulator hooks, with triggers at +-0.40; Peel/Engage and Comeback-focus sliders dropped; Team Bonds numbers corrected (Bond 60 / COM 60 gives 1.92 percent) and Bond gains shrink as a pair matures; a club that stays in the red for 4 weeks in a row gets the manager dismissed (game over, retry from autosave) in Phase 1 so the economy has a real failure case; Exhibition and Quick Match earn no objectives, goals or awards; prize money is 40 percent to a player pool by prize weights; 10-season economy and personality tests wait for the seasons phase | Producer (pending Founder) |

| Phase | Edition | What it adds |
|---|---|---|
| Single Player | MOBA Esports: Single Player | Offline play on the local device |
| Multiplayer | MOBA Esports: Multiplayer | Internet multiplayer hosting and matching, friends, sale and transfer of players |
| Global | MOBA Esports: Global | Game seasons, regional tournaments, mid-season invitationals, a World Cup |

"MOBA Esports" is the working title only. A distinctive final name still needs a trademark and store search (see IP-RISK-LOG).

## Founder decision: match formats and pacing (2026-11-07)

- **One game must take at most about 5 minutes of the player's time, draft included.** Players get frustrated and quit if matches drag.
- **Casual, quick, league and (later) public or bot matches are sudden death:** one game, first team to destroy the enemy base wins.
- **Tournaments are a series:** best of 3, finals best of 5, each game under the same time budget.
- Producer follow-through (GDD v1.6, section 8.7): Short draft (1 ban, 5 picks, 10 s timer) for casual play, Full draft (3 bans, 5 picks, 15 s timer) for game 1 of tournament series; game clock cosmetic 9 to 16 minutes; feed playback at most 2 minutes with Skip. Numbers are tunable; the 5-minute ceiling is not.

## Producer decision log: P-003 (2026-11-07)

- **Draft constants re-tuned** (producer call within the GDD 9.1 rule, no Founder gate needed): HeroFactor familiarity weight 0.10 to 0.06, synergy +2.5% to +4%, missing need -3% to -5%, damage imbalance -4% to -6%, CompMod cap 10% to 15%, lane counter +5% to +10%. Reason: with the old numbers, picking comfort heroes beat smart drafting. Now they tie, and a careful drafter gains about 5 points. GDD v1.5.
- **Draft is a margin lever** (about 3 win-rate points between sensible drafts; squad strength dominates). If playtests find it too small, widen MetaMod next. Founder may overrule.
- **Side bonus stays 0.02.** The 48% Blue mirror readings were noise (4,000 matches: 50.8%).

## Still open

1. **Final game name.** Working title: "MOBA Esports" with the edition suffixes above. Needs a name search before launch.
2. **Monetization details.** Reference images received; concept drafted in `docs/design/MONETIZATION-DRAFT.md`. Postponed until the final release.
3. **Transfers with AI clubs in Single Player.** The release path puts sale and transfer of players in the Multiplayer edition. Should a later Single Player update also allow transfers with AI-run clubs? Recommendation: not in Phase 1; decide after the core loop is balanced.
4. **Ads in the Single Player edition.** Still open (see MONETIZATION-DRAFT.md).

## Producer decision log: Alpha 0.2 (2026-11-08)

- **Training base rate raised from 0.5 to 1.5 points per week** and hero practice from 1.5 to 3.0 familiarity per week (GDD 7.3 formula otherwise unchanged). With the GDD's 0.5 the QA run showed "never train" beat the coach's training for every club in season 1 and most clubs in season 2, i.e. training was a trap. After the change training pays back from season 2 and resting is better inside season 1 (see CALIBRATION-9.1 addendum). Founder may overrule.
- **Coach and Facility levels fixed at 2** for every club until staff and facilities (D-007) exist.
- **Alpha 0.2 scope chosen by the Producer** (the Founder's game test gave no gameplay feedback): Game Plan, then training, fatigue and ageing; Alpha 0.3 is recruitment (free agents), contracts and a light finance layer.

## Producer decision log: Alpha 0.3 (2026-11-08)

- **Alpha 0.3 scope chosen by the Producer** (the Founder said "proceed"): free-agent recruitment, contracts and negotiation, and a light finance layer with sponsors (D-013 part, D-007 part). Saved searches, scouting reports, prize weight and the player prize pool, Analytics, tutorial goals and staff and facility costs are postponed.
- **Money is a margin lever, not a shortcut.** Revenue is a multiple of the starting wage bill so every club has the same economy shape. Economy QA (CALIBRATION-9.1 addendum) found two problems in the first settings and both were fixed: sponsor targets are now scaled by club strength (a fixed 12-win target was a trap for weak clubs) and the wage cap was tightened from 1.15 to 1.05 times revenue. Founder may overrule any number in `game/data/economy_v0.json`.
- **Dismissal rule kept as in the GDD** (8 rounds in debt = 4 weeks). The last autosave from before it stays loadable; saving is disabled once dismissed. Founder may prefer a softer rule (for example a warning season) if testers find it unfair.
- **Computer-run clubs do not sign, release or pay anybody** in Phase 1; their squads stay as in the data. Free agents train and age like everybody else.
- **Still open after Alpha 0.3:** 10-season economy run (5 to 6 seasons done), rich clubs have no cash sink, no youth intake, so the only new talent is the 40-player pool (it never refills except with released and expired players).


## Producer decision log: Alpha 0.4 (2026-11-08)

- **Alpha 0.4 scope chosen by the Producer** (the Founder said "Go ahead" to my offer): Team Bonds (GDD 7.7) and Player Form and Morale (4.2, 8.6), the part of Phase 1 that makes squad changes and rotation matter. Exhibition and Quick Match stay for a later alpha.
- **Scrim bonus halved (+3 to +1.5 per week).** The design document gave +3 but also forbade any bond route more than 20 percent faster than normal play; with two games a week the two could not both hold (37 percent). I kept the QA rule and changed the number. Founder may want a different trade-off (for example scrims at +3 with a fatigue cost); it is one constant in `bonds_v0.json`.
- **Computer-run clubs use one bond level per squad** (start 30, same gain rule), not 45 pairs each. Their chemistry still uses the real lineup's Communication, so it follows who actually plays. This keeps the season simulation fast; pair-level bonds for AI clubs would only matter once AI clubs trade players.
- **One match day = 3.5 calendar days** for the "each day" rules of Form and Morale. Without this the Form decay (x0.9 a day) would have been applied once per match day, leaving Form 2.5 times as large.
- **Morale does not yet enter contract talks or the player's willingness to renew.** It affects only the rating in matches in this build.
- **Old saves open as a new club** (every pair at 30, neutral form and morale) rather than being refused.
- **Still open after Alpha 0.4:** multi-season run with bonds, joint Game Plan rerun with chemistry, Exhibition and Quick Match, staff bonus, the club Form Rating (GDD 10.1), the earlier open items (second GDD review, name search, monetization, rating-scale calibration, role review of Alpha, youth intake).


## Producer decision log: Alpha 0.5, UI pass 1 (2026-11-08)

- **Founder approved** (a) visual direction A "Arena Dusk" (deep navy and teal, warm coral reserved for the one primary action) and (b) the first UI pass (UI-1 tab bar and Home card, UI-2 tokens, UI-3 components, UI-4 preview panels, UI-7 payoff screen), on condition that the order of building does not hurt later parts; no steps are skipped and notes for later passes are saved in `docs/design/UI-UX-REFERENCE-v1.md`.
- **Match length: fixed 75-second watch window per game at 1x** (answer to the Founder's question about lethargy while the player cannot act). Every game now plays in the same real time whatever its cosmetic length (9 to 16 game minutes), with 2x and Skip kept. Reason: the old design (playback at a fixed game-clock rate) gave 68 to 120 seconds, so a long game felt like a slow one; a fixed window removes that without touching results. A local pace log (Settings) records real time per game, skips, speed-ups and auto-plays so the Founder's playtest decides whether 75 seconds stays. If most feeds are skipped the window gets shorter. Founder may overrule: one constant, `ScreenMatch.WATCH_SECONDS`.
- **Undo versus confirm.** Reversible actions (training focus, Game Plan sliders) apply at once with an Undo message; irreversible ones (signing, renewing, releasing) show a preview panel and then ask for the tap. Reason: fewer taps for the many safe actions, a pause only where a mistake costs money or a player.
- **Tab bar hidden on match day.** Pre-match, draft, Game Plan, match and report are one focused flow without the bar; the phone back button goes one step up everywhere.
- **No game rule changed in this build.** Tests that guard the rules (1,727 headless checks before this build) are unchanged and pass.
- **Still open after Alpha 0.5:** UI backlog UI-5, UI-6, UI-8 to UI-12 (see the UI reference), a real-phone usability session with the Founder, plus the older open items (second independent GDD review, name search, monetization, rating-scale calibration, role review, youth intake, Exhibition and Quick Match).


## Producer decision log: Alpha 0.6, Alpha exit checklist (2026-11-08)

- **Founder approved** turning the Alpha exit criteria into a checklist and working through every item that can be done on a computer. The checklist is `docs/ALPHA-EXIT-CHECKLIST.md`: Alpha ends when groups 1 to 5 are Done and the Founder signs; group 6 before the first outside tester; group 7 before launch.
- **Scope of Alpha 0.6** (Producer's call): finish the Phase 1 features that were still missing (Exhibition and Quick Match, Form Rating and trophy cabinet, career log with derived kills/deaths/assists, stat help), the comfort options and tips that outside testers need, the long-run QA, and a soak test. No rule of the match simulator changed.
- **Game Plan limit ruling.** The 3-point limit of GDD 9.2.1 is read as applying between clubs within 30 rating points. The single 10 percent underdog matchup gains +4.3 from variance, the same as in Alpha 0.2; it is the comeback valve, not a dominant plan. Founder may overrule.
- **Practice matches use no calendar day of training or rest** for the starters that played them (their day is spent playing), and use the short draft. Exhibition is limited to one series per match day and to the league phase.
- **Stat help is one line per stat** instead of the two-line sheets in GDD 4.2; Morale, Fatigue and Personality are explained in place on the player card.
- **Colour-blind option** swaps green and red for sky blue and vermillion; text size option is one step (+15 percent). Both are stored on the device, not in the save.
- **Welcome tips are a light version of a tutorial** (three one-time cards). A guided first game stays optional until testers show they need it.
- **Still open after Alpha 0.6:** the phone items (2.5, 3.7, 4.1 to 4.4, 5.1 to 5.3), the Founder items (6.4 distribution, 6.5 release key, 7.1 game name and trademark search), the independent second GDD review (7.3, not started: a fresh reviewer is needed), store policy review (7.4), and the older items (monetization, role review, youth intake, transfers).

