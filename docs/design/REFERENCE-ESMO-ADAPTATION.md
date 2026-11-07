# Reference notes: ideas to adapt from the reference game's screens

Status: design notes, not yet part of the GDD. Owner: Game Design Lead. Reviewer: IP Checker, then Founder.
Source: screenshots supplied by the Founder on 2026-11-07 (team hub, Dynamics, Roster analytics, Playbook and Strategies). The images are **not** stored in the repo; only our own descriptions are.

## Rules for using the reference
- We adapt **ideas and player needs** (what information a manager wants, what levers they want). We do not copy layouts, wording, icons, tactic names, hero names or numbers.
- Several tactic labels in the screenshots use another popular MOBA's vocabulary for its objectives and structures. We do not use those words. Our map has its own objectives (Stoneback, Moonhulk) and structures; our words will be our own.
- Anything a feature needs from the simulator must be defined in the GDD and calibrated (section 9) before it is built.

## 1. Team hub (home screen of a club)
**Seen:** five starters in a row, each with role, overall number, name, and a mood and energy icon. Tiles for Playbook, Skins, Analytics, Dynamics. Further cards for matchmaking (placement matches), competitions (with a badge count), a team rating (published versus provisional) and a schedule shown as a week calendar.

**Adapt for Phase 1 (Single Player):**
- Starter strip: role, overall for that slot, name, Form (mood icon), Fatigue (energy icon). These map straight to our Form, Morale and Fatigue values.
- Tiles: **Game Plan** (the Playbook idea), **Analytics**, **Team Bonds** (the Dynamics idea). Cosmetics tile comes in the visual phase.
- Cards: next match and league table (replaces matchmaking and competitions in offline play), week calendar for the schedule.
- Later editions: team rating and placement matches arrive with Multiplayer; tournament cards with Global.

## 2. Team Bonds (the "Dynamics" screens)
**Seen:** two tabs. *Bonds*: links between players; thicker means more games together, brighter means a stronger partnership. *Communication*: a pentagon graph of mutual understanding, a grid showing how well each player understands each other (direction matters: "rows speak, columns listen"), and each player's languages with a fluency ring. A player who speaks a different first language scores about 55% to 66% with teammates, versus 85% to 92% among shared-language players.

**Why it matters for us:** it turns team chemistry from one hidden number into something the manager can see and act on, and it makes roster building a puzzle (a star who does not fit the team).

**Adaptation (proposal, replaces the single Chemistry number in section 7.7):**
- Per pair of starters keep **Bond** (0 to 100, rises with games together and scrim weeks, as today but per pair) and **Understanding** (0 to 100 per direction, from shared language and communication stat).
- Team chemistry = average over the 20 directed pairs, feeding `ChemBonus` as now, so the simulator does not change.
- Screen: a pentagon of the five starters with link thickness for Bond and colour for Understanding, a 5x5 grid, and a languages list per player.
- Languages become a **player data field from Phase 1** (English only in test data), so the multi-language live release does not need a data rewrite. The mechanic itself can start with one language and switch on later. (Founder decision wanted: build the pair grid in Phase 1, or only the data field? Recommendation: build the grid, with every player speaking English, so the screen and the maths are tested early.)
- Careful with real-world sensitivity: language fluency is a gameplay trait, never tied to nationality or ethnicity in text or art.

## 3. Roster analytics
**Seen:** a date filter; team totals (games, win rate, kills-deaths ratio, gold per minute, objective damage per minute, vision per game); objective control (towers, two kinds of neutral objectives, a boss, base structures, each with "first %"); most picked and most banned heroes per position; a trend chart of gold, creeps and experience difference over the first 20 minutes; a table of results against each opponent.

**Adaptation:** our simulator is abstract (section 8), so we show only what it really produces and do not invent fake kill or gold numbers:
- Win rate, and win rate when leading or trailing after the early game (comeback rate).
- Result of each contest by phase (lanes, jungle, objectives, teamfights) as "won / lost by how much".
- Objective control from the objective contests (Stoneback, Moonhulk) and "who was first".
- Most picked and banned heroes per slot, for us and for opponents.
- **Lead trend chart** with three points (early, mid, late) from `A_early`, `A_mid`, `A_late`. When the animated map arrives, the same stored match record can feed a finer timeline.
- Results versus each opponent, and head-to-head.
- Date and competition filters.
These are derived from stored match records, which is also what the later animated map will replay.

## 4. Playbook, Game Plans and Draft tools
**Seen:** three tabs: Heroes, Draft, Strategies. *Draft* offers an autopilot for the draft (paid). *Strategies* holds a limited number of in-game strategies on the free plan; each has a **Trigger** (conditions for when it applies; one with no trigger is the default) and **Tactics** in groups (team macro, objectives, lane plans, roaming, jungle, combat and targeting, spells and items, recovery, survival, vision, micro positioning). Each tactic is a slider from strongly avoid to strongly prefer, shown as a percentage, with "Default" meaning untouched. A count shows how many are customized.

**Why it fits:** it gives the club owner a second lever besides the draft, and it is exactly the "coach who does not play" fantasy: you set how the team behaves, and the team executes.

**Adaptation: "Game Plan" (proposal for GDD v1.3, spec task D-009):**
- A Game Plan is a set of sliders (-100 to +100, default 0) plus an optional **trigger** (for example "when I am ahead after the early game", "when I am behind", "against a Dive comp", "default"). The engine picks the first matching plan, else the default.
- Our sliders must map to things the simulator really has, so the first set is small (about 8 to 10) and each is a **trade-off**, not a free bonus:

| Group | Slider (our names, draft) | What it trades in the model (v0 idea) |
|---|---|---|
| Macro | Group up <-> Spread out | Weight between teamfight contests and lane/jungle contests |
| Macro | Tempo <-> Scale | Early and mid rating up, late rating down (and the reverse) |
| Objectives | Early objective priority | More weight and variance on the Stoneback contest, less on lanes |
| Objectives | Late objective priority | More weight on the Moonhulk contest, risk when behind |
| Lanes | Lane aggression | Early lane contest swing up (win or lose bigger), noise up |
| Lanes | Farm safely | Early swing down, noise down, scaling up |
| Jungle | Jungle focus lane (Top / Mid / Bot) | Jungle bonus to one lane contest, penalty to the others |
| Roaming | Support roaming <-> Support stays | Bot-lane strength against objective-contest strength |
| Combat | Engage <-> Peel | Interacts with comp style (Dive/Siege/Protect) in teamfights |
| Safety | Take risks <-> Play safe | Variance of every contest, up or down |

- **No dominant plan:** every slider has a cost, and plans interact with the opponent's comp and roster (a plan good against Siege is poor against Dive). QA must show by simulation that no setting beats neutral across the league average, but the best setting differs by roster and opponent.
- **Auto-plan:** the AI clubs get plans generated from their roster and comp.
- **Reports (Pillar 3):** the match report says which plan setting mattered ("your Lane aggression won Top but lost Mid"), using the same win-probability swing method as the draft edge.
- **Quota and money:** the free tier keeps at least one Game Plan with all sliders usable, so the free game is complete. Extra saved plans, folders and triggers are the convenience paid for (monetization draft), never extra strength.
- Out of scope in v1: items and spell choices (our sim has no items yet), per-hero micro positioning, vision. These can come with an item system.

## 5. Draft autopilot
Seen as a paid feature. Our Quick mode auto-draft stays free (Pillar 5). A paid extra could be rule-based autopilot presets (for example "prefer comfort picks", "ban the opponent's top threat"). Keep it convenience only.

## 6. Other items in the screenshots
- Placement matches and a team rating: Multiplayer edition.
- Competitions list: grows into Global edition (seasons, regional tournaments, invitationals, World Cup).
- Skins and club customization: visual phase and paid tiers.

## 7. Matchmaking, ranks and leaderboards (second set of screenshots)

**Seen:** a matchmaking hub with three modes: *Competitive* (a season with a countdown, a leaderboard, a ranks guide, placement matches before you get a rank), *Quick Match* (queue-time preference: balanced, faster, or higher quality; fairness setting: standard, strict, expanded), and *Friendly* (a quick match against a chosen club, best of 1, 3 or 5, with a club search). A settings sheet lets the player allow matches against bots to cut queue time and choose whether their matches are public. The leaderboard lists clubs with logo, flag, rank and points. The ranks guide shows nine ranks, each with five divisions for the lower ranks and none at the top; hidden skill rating decides points won or lost; 100 points promotes you; dropping below 0 demotes you unless a "points shield" protects you (earned from losses and on promotion); top ranks use thresholds that move with how many players are in each rank, and inactivity slowly lowers points. Each rank shows a season reward.

**Edition mapping:**
- **Multiplayer edition (online):** the full competitive ladder, Quick Match, Friendly, club search, privacy settings and leaderboards belong here. Draft below.
- **Single Player edition (Phase 1):** only two of these make sense offline, and both are cheap:
  - **Exhibition (the Friendly idea):** pick any club in your league, play best of 1, 3 or 5. No effect on the league table; reduced fatigue and no form or morale change. Useful for testing drafts and Game Plans, and it is where "scrim" for chemistry can live.
  - **Quick Match:** an instant game against a random club of similar strength, same no-effect rule.
  Recommendation: include both in Phase 1.
- **Global edition:** seasons with countdown, season rewards and tournaments.

**Draft design for the Multiplayer ladder (not for Phase 1):**
- Hidden rating (Elo-style, with uncertainty) decides points gained or lost; placement matches set the starting point; ranks have divisions; a points shield softens demotion; top ranks use population-based thresholds; inactivity decay; a season reset. This is a standard ladder design and the maths is ours to choose.
- **Our own rank names.** The reference's rank names are the same well-known ladder words used by the genre leader, so we do not use them. Placeholder names Tier 1 to Tier 10 until the Content Lead proposes original names (task D-006) and the IP Checker clears them.
- **Honesty about bots:** if bots fill queues, label them in the match record. Store policies and fairness expectations favour clear disclosure.
- **Fairness settings:** queue-time and fairness options are good ideas. Keep two simple controls and show expected wait.
- **Rewards:** season rewards are in-game items and cosmetics only. No real-money prizes without legal review (prize games and gambling rules differ by country).
- **Privacy:** matches public or private is a per-club setting; competitive matches are public.
- **Moderation:** club names and tags need a filter and a report function before any online release.

## Decisions (Founder, 2026-11-07)
1. **Game Plan in Phase 1: YES**, the small version (about 8 sliders, a default plan, triggers "ahead" and "behind"), built after the core draft calibration.
2. **Team Bonds in Phase 1: YES**, with English-only data and the pair grid and maths in place.
3. Exhibition and Quick Match in Phase 1: recommended, proceeding unless the Founder objects.
