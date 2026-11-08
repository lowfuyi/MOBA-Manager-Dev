# Esports notes: making the live match feel like real MOBA esports

Owner: Esports Manager. First written 2026-11-08, reworked 2026-11-08 (wave 1b, fix list in `company/reviews/2026-11-08-wave1.md` section 1, conflict C7), pass 1c 2026-11-08 (item B11 of `company/reviews/2026-11-08-wave1b.md`: aligned to `UI-PASS-2.md` 6.7). For workstream W4 (Alpha 0.7 plan). Advice only: the simulation decides the result, and the arena only plays it back. Map and objective names are the GDD placeholders (Wrenfell, Stoneback, Moonhulk, the Cairn).

**Authority.** All second-by-second numbers live in `ACTION-VOCABULARY.md` section 1.4 and in the `stages` of `game/data/arena_map.json`. Both follow `Report.FEED_ORDER` (`game/src/sim/report.gd`). This file gives genre guidance only: what to show, what to skip, where to put emphasis. If a number here ever disagrees with those two files, they win. **Text budget.** The Match HUD owns it: `UI-PASS-2.md` 6.7.4 (at most 3 transient text items at once, at most 10 new words in any 2.5 s, a feed block of 2 lines). Section 2.4 only gives the genre reasons and the wording lines; where it differs from 6.7.4, 6.7.4 wins.

## 1. Phases of a pro match and where our fixed stamps sit

The sim fixes eight contests at these fractions of game time (`Report.FEED_ORDER`), plus the siege at 1.0. The four lane results are spread from 0.18 to 0.27, not all at 0.25 (the GDD 8.5 text says 0.25L; the code is the truth). In the 75 s show the stamps are 13.5, 15.75, 18.0, 20.25, 33.75, 45.0, 60.0, 71.25 and 75 s. The scoreboard clock is `show time / 75 x game minutes` (game length is clamped to 9 to 16 min), so in a 12 min game the stamps read 2:10, 2:31, 2:53, 3:14, 5:24, 7:12, 9:36, 11:24, 12:00.

| Phase | Real match (about) | What viewers see | Our contest and stamp |
|---|---|---|---|
| Laning | 0 to 12 min | Heroes farm waves one-on-one or two-on-two. Small trades, one lane pushed in, one hero short of health. The jungler passes through and may strike one lane. | Top 0.18 (13.5 s), Mid 0.21 (15.75 s), Bot 0.24 (18.0 s), Jungle 0.27 (20.25 s) |
| First rotations | 8 to 15 min | Lanes break, heroes walk together, scouts check bushes, the first tower falls. Tension is in who arrives first. | Early objective (Stoneback) 0.45 (33.75 s); first towers in the 25 to 28 s rotation window (see 2.4) |
| Team fight | any time after about 12 min | Ten heroes collide for 5 to 15 seconds. Someone initiates, someone is caught, the losing team breaks apart. | Mid fight 0.60 (45.0 s), late fight 0.95 (71.25 s) |
| Objective fights | 12 to 25 min | Both teams stack around a neutral objective. One side starts the take, the other tries to steal or punish. | Stoneback 0.45, late objective (Moonhulk) 0.80 (60.0 s) |
| Comeback | after a long deficit | The behind team wins one fight or objective and the lead shrinks. It needs one clean pick or a smart defence. | Only when the sim's arc says so (2.3) |
| Closing out | last 3 to 5 min | The leading team pushes lanes together, towers drop, then the base core. A single lost fight can flip it. | Siege at 1.0 (75 s), Cairn falls at 74 s |

Honest limit: our games are 9 to 16 min against roughly 25 to 35 min in a real pro match, so everything is compressed about 2.5 times. The "real match" column is general genre knowledge, not measured. A genre-literate viewer will accept the compression if three things hold: nothing happens before it plausibly could (no tower at minute 2), the order of events is the order of the clock, and the clock is labelled as game time. Call the four early beats "lane lead", not "lane phase result": in a real game the lane phase is only judged at around minute 10 to 14, which here is about the first towers.

## 2. The 75 s show on the fixed stamps

### 2.1 Mapping (windows copied from ACTION-VOCABULARY 1.4)

| Window (s) | Beat | Stamp inside | Show (genre reason) | Skip |
|---|---|---|---|---|
| 0 to 4 | Opening | none | Two five-hero rosters, plan labels, clock starts. Viewers need to know who is who before anything happens. | Walking out from base |
| 4 to 21 | Four lane beats | 13.5 top, 15.75 mid, 18.0 bot, 20.25 jungle | One small trade per lane and a pressure arrow. The jungler is seen walking toward a lane before it flips, as real ganks come before the flip. | Farming with no result |
| 21 to 24 | Plan check | none | A calm beat: the plan chip, a lead-graph marker. Quiet time lets the next beat land. | Anything loud |
| 24 to 31 | Rotation, early towers | none (towers 25.0 to 28.0) | The map opens: heroes leave lanes, first towers fall, both teams walk to the same place. | Recalls and shopping |
| 31 to 36.5 | First objective | 33.75 | Approach, the take or the steal attempt, who gets the reward. | Waiting for it to spawn |
| 36.5 to 51 | Mid fight, then push | 45.0 | Full team collision, one clear initiator, a visible turn, then the winner pushes. | Individual last hits |
| 51 to 54 | Reset | none | A breath: reposition, heal, lead number settles. | Shopping detail |
| 54 to 63 | Late objective | 60.0 | Setup, a risk, a payoff, a lead number that jumps. | Repeating earlier takes |
| 63 to 71.25 | Late fight | 71.25 | The longest fight and the most important one. | Repeating earlier kills |
| 71.25 to 75 | Closing | Cairn falls at 74.0 | Siege, last hit, a 1 s hold on the result. | Credits, statistics |

Rule for all of them: the resolve stamp never moves, and a quiet stretch of a second or two before it makes the stamp feel bigger.

### 2.2 Lane beats: emphasis, not order

Real broadcasts show lanes as they happen, and rank them only in a recap. So the playback order is chronological (top, mid, bot, jungle) and the report stamps match. What can still say "this lane mattered most" (three levers, no extra text):

1. Tier effects from ACTION-VOCABULARY 2.2 (zoom, flash, sound strength): the largest result gets the strongest allowed tier, the smallest stays calm.
2. Hold length inside its slot. Slots are 2.25 s apart (13.5, 15.75, 18.0), so a hold is at most about 2 s; give the biggest result the full hold and the smallest about 1 s.
3. Camera: on the biggest result, stay close to the winner; on a narrow one, keep both heroes in frame.

There is no recap line in the plan-check window (21 to 24 s). The HUD budget has no room there: the jungle result, the plan banner and the rotation labels already fill it (`UI-PASS-2.md` 6.7.4). The biggest lane is told by items 1 to 3 only.

### 2.3 Stomp, close game and comeback with fixed stamps

A fixed-stamp show cannot move a fight earlier, add a beat or stretch a window. It can vary these five things, all already allowed by ACTION-VOCABULARY 2.2:

| Lever | Stomp (decisive tiers, arc "stomp") | Close game (narrow tiers, arc "close") |
|---|---|---|
| Tier effects | Zoom, edge flash and the big sound on the two fights and the last hit. | Soft sounds, no flash until the late fight. Save the big sound for the last hit. |
| Hold lengths inside a window | Kills are front-loaded, so the fight ends early; the freed seconds go to the loser's one failed idea and a calm siege. | Kills are spread to the end of the window; hold the camera on the near-miss (loser retreats at low health, last strike). |
| Camera | Follows the winner, wide shot of pressure. | Keeps both sides in frame until the last second. |
| Sound | Rising pressure, no tension drops. | A tension pad that only resolves at the late stamp. |
| Text | Fewer lines, plain ("Towers fall one after another"). | A lead-flip tag when the lead line crosses zero; if the HUD uses a commentary slot before the late fight (66.0 to 68.75 s), a line that says it is open. |

Comeback and snowball: dramatise only what the sim's arc (F6) and lead flip (F5) report. Never invent a swing. When the match winner loses the late fight but still wins (about 19% of simulated games, from ACTION-VOCABULARY 1.3), the genre has a ready story: the lead carried the push, or the teams traded and one had more. Say that, as a short status tag or end-card word (there is no commentary slot after 68.75 s), in words like "lead still stands", and never show the loser celebrating. This is advice for the staging question C8; the Technical Designer and the tester question decide.

### 2.4 Text on screen at once (advice for the Match HUD; UI/UX Designer decides layout)

Four text channels compete on a portrait phone: the intent label per side (a pill, 28 characters at most), the status tag (centre, 24 characters at most), the commentary line (8 words at most, and at most 2 lines in a whole game) and the feed (2 lines). The feed lines are the eight contest results (for example "Top lane: you win it"); kills are shown as skull marks, not as feed text. Numbers (clock, kills, towers, gold lead) are glanced, not read, and the plan chip is static after the first seconds, so none of those count toward the budget. My estimate, not measured: a viewer reading at a glance while watching action takes in about two words per second, so no more than about 10 new words should appear in any 2.5 s span.

| Moment | New text allowed at once | What to hold back |
|---|---|---|
| Calm (opening, plan check, rotation, reset, siege hold) | Up to three transient items: the pair of intent pills (counts as one), the status tag, the feed block. A commentary line takes the second feed line, only in a calm gap and only in the four slots of section 4 | Nothing else; keep new items one at a time |
| Fight (the windows around 45.0 and 71.25 s, about 3 s each side of the stamp) | Up to three: the two pills already on screen, the status tag, and one feed line. No commentary line in the fight window | New pills and commentary. The feed shows the contest result, newest first (kills are skull marks on the arena), older line dim, fading at 4 s |
| Resolve stamp (the 1 s after any stamp) | Two: status tag and one feed line | Commentary and new intent labels |
| Closing hold (74 to 75 s) | One: the end caption ("play of the game", matching the first line of the report's "why") | Everything else fades |

Why: real broadcasts clear the middle of the screen during a fight and bring summaries back afterwards (LHM, see Sources, opened and read). In our case the "middle" is the arena. Also keep animation short: it should show a change, not delay it.

### 2.5 Answers to ACTION-VOCABULARY section 10 (items 1 and 2)

1. **Chronological lane beats: I agree.** The genre shows events in clock order and ranks them afterwards, so chronological playback plus emphasis (2.2) is more authentic than largest-first, and it keeps the report stamps true. I withdraw "ordered by size" from my first draft. One caution: the jungle result at 0.27 comes last, but real jungle ganks cause lane flips. Keep the jungler's visible walk from 12.5 s (as the vocabulary already has it) so the viewer sees the cause before the flip.
2. **Early towers at 25 to 28 s: I agree.** At 0.33 to 0.37 of the game clock this is about 4:00 to 4:30 in a 12 min game, which scaled by the 2.5 times compression is about minute 10 to 11 of a real match, where first towers fall. A tower at 2 to 3 min on the clock would look wrong to anyone who knows the genre. Three conditions, all advice: (a) only outer towers in this window; (b) the earliest fall of the match gets the one "First tower" tag, as a first kill would; (c) if one side takes two or three towers in the 3 s window, show one banner for the sweep, not three tags. Small disagreement: top at 25.0, mid 26.5, bot 28.0 mirrors the lane order, which is good, but if the ledger gives one side all three, that side has a lead that real games would call a snowball; make sure the "snowball" overlay agrees with it.

## 3. How casters and graphics communicate

| Item | Purpose | Phone portrait? |
|---|---|---|
| Scoreboard: kills, towers, objectives, clock | State at a glance | Yes. One slim top bar. |
| Gold-lead graph | Shows who is ahead and when it flipped | Yes. A thin line over the match so far, with markers for each contest. |
| Objective timers | Tells viewers when a fight is likely | Yes, but only the next one, as a single chip. |
| Intent label (a short reason for movement) | Explains why heroes are going somewhere | Yes. Best single feature. One label per side at most. |
| Contest results (feed) and kill marks | Confirms events | Yes. A short, fading feed of 2 lines (the contest results); kills are skull marks on the arena, not text. |
| Play of the game | Names the match's best moment | Yes, once, at the end, as a replayed beat on the result screen. |
| Five player panels with items and levels | Detail for experts | Behind a tap only. |

Broadcast lessons: a scoreboard should show who is ahead, by how much, and where it came from, so kills alone are not enough (gold and towers too, LHM and gaming.net, see Sources). Keep the action clear during fights, show only data you can trust, and pair kills with gold and objectives. Viewers also watch preparation before an objective, and what the winner does with the reward afterwards (gaming.net); the rotation and push windows serve that.

## 4. Commentary style

- **Tone:** warm, excited but not shouting, fair to both sides.
- **Length and count:** 8 words or fewer, one line at a time, on screen about 2.5 s, and **at most 2 commentary lines in a whole game** (`UI-PASS-2.md` 6.7.4). The HUD has four slots: 26.75 to 28.5 s (rotation, early towers), 39.5 to 42.5 s (mid fight start), 47.5 to 49.0 s (after the mid fight) and 66.0 to 68.75 s (before the late fight). My advice: pick two of them per game, preferring the one after the mid fight and the one before the late fight, because a line after a result is the most meaningful; the Narrative Designer decides.
- **Variety:** across games, at least 3 phrasings per slot, no repeat within 20 lines, a mix of facts and feeling.
- **Truth:** every line comes from a real sim event; never predict a result the sim has not produced.
- **Ownership:** these are tone samples. The Narrative Designer owns final commentary (conflict C14); the Gameplay Designer owns intent labels and status tags.

**The samples below are tone only.** They are not a script, and the game does not say them all. Only 2 commentary lines are used per game, in the four slots above. A sample whose moment has no slot (lane lead, jungle swing, the fights' results, closing, close finish) is a tone reference for status tags, the end card and the Report text, not an extra commentary line. Samples of 9 words or more must be shortened to 8 before use. Original lines; replace names with the actual hero, lane and club names. "Genre moment" uses the stamps of section 2 and is not a schedule:

| Situation | Genre moment | Lines |
|---|---|---|
| Opening | 0.5 to 3 s | 1. "Both teams are in position, and the clock is running." 2. "Five heroes each, three lanes, one Cairn each to protect." |
| Lane lead | after 13.5 / 15.75 / 18.0 s | 3. "{Top hero} is clearly ahead, and the wave is leaning their way." 4. "A quiet lane, but that small lead will matter later." |
| Lane swing | 20.25 s, only if the jungle result flips a lane | 5. "The jungler has arrived, and that lane just flipped." 6. "A narrow escape, and the pressure drops." |
| Objective | 31 to 36.5 s, 54 to 63 s | 7. "Everyone is gathering around Stoneback." 8. "It is taken cleanly, and the buff goes to {team}." 9. "A steal attempt, and it nearly works!" |
| Team fight start | 36.5 s, 63 s | 10. "They commit, and it is five against five." 11. "The first strike lands on the back line." |
| Team fight result | after 45.0 / 71.25 s | 12. "One side is falling apart, and the other presses." 13. "Three down for {team}. That decides this fight." |
| Comeback (arc "comeback" only) | after the flip | 14. "A small chance appears, and {team} grabs it." 15. "The gold gap is shrinking, and the crowd feels it." |
| Stomp (arc "stomp" only) | push windows | 16. "There is no answer to this pressure." 17. "Towers fall one after another." |
| Lead carries (match winner lost the late fight) | 71.25 to 74 s | 18. "A fight lost, but the lead still stands." |
| Closing | 71.25 to 75 s | 19. "The Cairn is exposed, and nobody can stop the push." 20. "One last hit, and it is over." |
| Close finish | 74 to 75 s | 21. "That was a game decided by one fight." |

## 5. Do not copy

- Real teams, players, leagues, tournaments, heroes, items, map or objective names.
- Branded overlays, colour schemes, logos or layouts that look like a known broadcast.
- Signature phrases or recurring jokes of any real caster, and fan-community catchphrases.
- Real region names are allowed for competitions (Founder decision), never beside a real club or person.

## 6. Recommendations for the match arena

1. Show one slim scoreboard and a thin gold-lead graph above the arena so the story of the match is readable at a glance.
2. Give every fight a visible beat order (approach, first strike, turn, result), with the camera nearest the decisive moment.
3. Put one intent label per side near its heroes, and make each label come from the Game Plan or the sim's contest.
4. Spend the 75 s on the fixed stamps of section 2.1. Do not reorder beats; vary tier effects, hold length, camera, sound and text (2.2 and 2.3).
5. Keep to the HUD text budget (`UI-PASS-2.md` 6.7.4, reasons in 2.4): three transient text items at most, a 2-line feed, at most 2 commentary lines a game, one line at a time.
6. End on a short hold (about 1 s, inside the 74 to 75 s window) with a "play of the game" caption that matches the first line of the report's "why you won or lost".

## Sources

Both web sources were opened with a page-fetch tool on 2026-11-08 (pass 1c). That tool returns a summary of the page, not the full text, so I read summaries, not every paragraph. The titles below name a real game; they are reference only and nothing from them is copied into the game.

- LHM.gg, "What Makes a Good League of Legends Broadcast Overlay?", Michael Majka, published 19 July 2026. Opened; the Studio Manager also verified title, author and date. Used for: persistent-information order (team identity, game state, timer, economy, objectives, player status), the scoreboard should show who is ahead and by how much (so gold and towers, not kills alone), fight-safe display (keep the centre clear, suppress non-essential panels, detail before fights, not during), and "animation should communicate a state change, not delay it".
- Gaming.net, "League of Legends: 7 Things to Watch Beyond the Kill Score", byline Jordan Pike, published 26 October 2026, page `https://www.gaming.net/league-of-legends-things-to-watch-beyond-kill-score/`. **I can open it now** (fetched 2026-11-08; I found the address by a web search, so it may differ from the one the Studio Manager tried, which returned an error). The byline names Jordan Pike as an AI research agent and says the article is AI-generated and reviewed by the site's editorial team, so it is **weak support**: no rule in this file rests on it alone. Used only for: gold (not kills) shows an advantage, farming, vision, and preparation before an objective plus what the winner does with the reward. LHM also supports the gold point.
- Studio files: `ACTION-VOCABULARY.md` sections 1.3, 1.4, 2.2, 10; `game/data/arena_map.json` stages; `game/src/sim/report.gd` (`FEED_ORDER`, `game_minutes`); GDD-v1.11 sections 2, 8.3, 8.5, 8.7; UI-UX-REFERENCE-v1 section 2.3; ALPHA-0.7-PLAN.
- Phase timings, the 2.5 times compression, the reading-speed figure and the pacing advice are general genre knowledge and my estimates, not measured. Nothing here has been tested on a phone.
