# The Broadcast: match commentary (Match Day M4, 2026-11-27)

Founder decision D4 (DECISIONS H-4): commentary runs for the whole match, in the voice of two shoutcasters hosting a
broadcast, and its emotion rises and falls with the game. It replaces the 0.12 ArenaComment (at most two lines a game).

**Rules.** Display only (A1, R7): `ArenaCast` (`game/src/arena/v2/arena_cast.gd`) reads the ArenaPlayer (the finished
game's log) and never the simulation. Deterministic: the same game gives the same lines (variants are picked by a hash of
the game id, the event and the time; no global random numbers). Spoiler rule: a line at game time t uses only log events
at or before t, plus what a viewer can know (the draft, positions, static hero data); nothing says who will win before
the end. Truth rule: every number, hero, lane, objective and "who leads" in a line is true at t; `tests/check_cast`
replays games and checks each line's claims against the log. All numbers below live in `game/data/cast_params_v1.json`.

## 1. Excitement e(t), 0 to 1

Built once per game from the log, on a grid of show time (the time a viewer sees at x1). Each event adds an impulse;
e rises to the sum within the attack time and decays slowly. e = min(1, sum of decaying impulses).

| Moment (from the log) | Impulse | Notes |
|---|---|---|
| A fight starts (2 to 3 heroes / 4 to 6 / 7 or more) | 0.15 / 0.30 / 0.45 | "fight" events, size = heroes involved |
| A kill | 0.18 | each "kill" event |
| First blood | +0.25 | the first kill of the game |
| A double / triple / quadra (one hero, kills within 10 game seconds) | +0.15 / +0.30 / +0.45 | on top of the kills |
| A team wipe (all five of one side dead at once) | +0.50 | |
| A close fight (each side lost at least one) | +0.10 | at the fight's end |
| A tower falls (outer / inner) | 0.20 / 0.30 | "tower" events |
| An objective is taken (Mossback / Stoneback / Moonhulk) | 0.15 / 0.30 / 0.45 | "objective" events |
| A steal (taken by the side that did not call the group on it) | +0.30 | "call" events in the 30 game seconds before |
| Gold swing over the last 30 game seconds (team) | 0.10 per 1,000 gold, at most 0.30 | team gold samples |
| The gold lead changes side (at least 1,000 either way) | 0.35 | lead flip |
| A comeback (the side now ahead was 3,000 or more behind) | 0.50 | |
| A base is open (an inner tower of either side has fallen) | floor 0.35 from then on | late tension; tied to the open base, never to the end time (that would give the ending away) |
| The Cairn falls | 1.0 | the final blow |

Attack 1.5 s, decay half-life 4 s (so most of an impulse is gone after 8 to 10 s). Show time at x1. No gold talk before 2:00 of game time.

**Measured on 60 desktop games (check_cast, 2026-11-27):** about 56 lines a game (calm 6%, building 24%, hot 33%, peak 3%, aftermath 17%, by line count), a line on screen 99.8% of show time, the analyst about 30% of lines; 0 false claims, 0 spoilers, 0 repeats. Not measured on a phone; how loud this feels is the Founder's call.

## 2. Emotion tiers

| Tier | e | Length of a line | Style | Silence at most |
|---|---|---|---|---|
| calm | below 0.20 | 12 to 20 words | conversational: scene setting, the draft, the lanes, analysis | 6 s |
| building | 0.20 to 0.45 | 6 to 12 words | anticipation | 3 s |
| hot | 0.45 to 0.75 | 3 to 8 words | exclamations | 2 s |
| peak | 0.75 and up | 1 to 5 words, quick bursts | the strongest words; 32 px Bold | 2 s |
| aftermath | after a peak, while e falls below 0.45 (up to 12 s) | 10 to 22 words, slower | stunned or reflective, the analyst explains | 6 s |

Valence: for moments with a side, wording can lean towards the club you manage (awe, relief when it goes your way;
disbelief, a groan when it does not), through the play-by-play caster's exclamation lines; the event lines name teams and
heroes and stay fair to both. Emotion shows in words, length, punctuation, weight and size and one small mark, never colour
alone and never ALL-CAPS lines.

## 3. Two voices (text only)

- **Play-by-play** (voice `p`): fast, emotional, short; calls what happens.
- **Analyst** (voice `a`): explains why: the draft, the lanes, gold, items, who changed the game; now and then answers the
  play-by-play after a big moment.
- Their names and personalities: `arena.cast.name.p`, `arena.cast.name.a` (Narrative Designer; original names). An optional
  hook `ArenaCast.on_line` exists for a later voice or TTS; no audio is built.

## 4. Coverage and pacing

- A line is on screen for the whole match. A line stays up at least max(2.0 s, 0.28 s per word) of show time, then until
  the next line, at most 4 s longer; silence after that is at most the tier's limit above.
- Queue priority: events, then emotion (exclamations), then analysis, then filler. A stale event line is dropped (a kill
  line more than 4 s of show time old; others 6 s).
- No line repeated within 120 s; never the same first word twice in a row.
- Above x1 only key lines (events of hot and peak, objectives, towers); after Skip, no catch-up; at the end, a wrap-up line
  with the result; the screen keeps its "Decided by" line.
- An intro before the game: the welcome, the line-ups by lane, a signature pick, a lane matchup (static hero data and
  `hero_matchups_v1.json`). Tap to skip. In the guided tutorial game only the welcome.
- Large text: the commentary stays (at most two lines, 26 px or more). Colour-blind: no colour-only cue.

## 5. Line catalogue (keys in `game/i18n/en.json`, merged only through `tools/merge_copy.py`)

Key form: `arena.cast.<voice>.<event>.<n>`, n = 1, 2, 3, ... with no gaps. Slots in braces; a line uses only the slots
listed for its event. `{team}` and `{team2}` are club names, `{hero}` and `{hero2}` hero names, `{lane}` Top, Mid or Bot
(or Jungle, Support for intro lines), `{place}` an objective or map place name, `{n}` a small number, `{gold}` a gold
amount written with a thousands comma, `{item}` an item name. Word counts by tier (section 2). ASCII only.

| Key (voice.event) | Tier | Slots | At least |
|---|---|---|---|
| p.intro.welcome | calm | team, team2 | 8 |
| p.intro.lane | calm | lane, hero, hero2 | 8 |
| p.calm.scene | calm | team, team2 | 14 |
| p.calm.farm | calm | lane | 10 |
| p.recall | calm | hero | 8 |
| p.gank | building | hero, lane | 10 |
| p.ward | building | team, place | 8 |
| p.spike | building | hero, item | 10 |
| p.obj.up | building | place | 8 |
| p.obj.start | building | team, place | 10 |
| p.obj.take | hot | team, place | 10 |
| p.obj.steal | peak | team, place | 8 |
| p.fight.start | building | team, place | 14 |
| p.fight.big | hot | place | 10 |
| p.fight.end.clean | hot | team | 10 |
| p.fight.end.narrow | hot | team | 10 |
| p.fight.end.even | building | (none) | 8 |
| p.first_blood | peak | hero, hero2 | 10 |
| p.kill.solo | hot | hero, hero2 | 18 |
| p.kill.trade | hot | hero, hero2 | 8 |
| p.kill.double | hot | hero | 10 |
| p.kill.triple | peak | hero | 8 |
| p.kill.quadra | peak | hero | 8 |
| p.kill.wipe | peak | team | 10 |
| p.kill.streak | hot | hero, n | 8 |
| p.kill.shutdown | hot | hero, hero2 | 8 |
| p.tower.fall | hot | team, lane | 14 |
| p.tower.inner | hot | team, lane | 10 |
| p.base.race | peak | (none) | 6 |
| p.gold.swing | hot | team, gold | 8 |
| p.lead.flip | peak | team | 10 |
| p.comeback | peak | team | 8 |
| p.late.tension | building | (none) | 10 |
| p.final.blow | peak | team | 10 |
| p.ex.hot.good / p.ex.hot.bad / p.ex.hot.neutral | hot | (none) | 10 each |
| p.ex.peak.good / p.ex.peak.bad / p.ex.peak.neutral | peak | (none) | 10 each |
| a.intro.welcome | calm | team, team2 | 6 |
| a.intro.pick | calm | team, hero, lane | 10 |
| a.intro.matchup | calm | hero, hero2 | 8 |
| a.intro.late | calm | team | 6 |
| a.intro.early | calm | team | 6 |
| a.lanes.lead | calm | team, gold | 10 |
| a.lanes.even | calm | (none) | 8 |
| a.gold.lead | calm | team, gold | 12 |
| a.gold.even | calm | (none) | 8 |
| a.spike | calm | hero, item | 10 |
| a.after.fight.numbers | aftermath | team | 8 |
| a.after.fight.gold | aftermath | team | 8 |
| a.after.fight.even | aftermath | (none) | 8 |
| a.after.kill | aftermath | hero | 10 |
| a.after.wipe | aftermath | team | 8 |
| a.after.obj.stoneback / a.after.obj.moonhulk / a.after.obj.mossback | aftermath | team | 8 each |
| a.after.tower | aftermath | team, lane | 10 |
| a.after.flip | aftermath | team | 8 |
| a.plan.switch | building | team | 8 |
| a.plan.read | calm | team | 12 |
| a.comp.read | calm | team | 12 |
| a.late.tension | aftermath | (none) | 8 |
| a.wrap.win | aftermath | team | 8 |
| a.wrap.close | aftermath | team | 6 |
| a.calm.filler | calm | (none) | 16 |
| name.p, name.a | | | 1 each |

About 650 lines in all. Wording rules: plain English a teenager understands; no real casters' catchphrases, memes or
famous call-outs; no competitor names; no "wins the game" or anything that predicts the result except in p.final.blow and
a.wrap.*; "swung the game" style only in aftermath lines (they come after the moment); no ALL-CAPS words; at most one
exclamation mark; no line that would be false if the team or hero were swapped (each line must be true for any slot value).
