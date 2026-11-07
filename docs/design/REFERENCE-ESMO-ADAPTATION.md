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

## 8. Manager talents, finances, sponsorship, recruitment and contracts (third set of screenshots)

**Seen:**
- **Talents.** The manager earns 1 talent point per manager level. There are four trees: a general *Negotiator* tree (20 points) and one specialist tree per game genre (75 to 77 points each). The MOBA tree is a branching grid of small nodes with icons (mood, energy, speed, focus, vision, shield, callout and similar), where each node is unlocked after its parent. A Reset button refunds points. Manager level comes from XP, and missions pay XP.
- **Finances.** Three tabs. *Overview*: balance and a week bar chart of income and expense. *Analytics*: daily profit and loss, an income donut by source (sponsor signing bonus, cash prize, sponsor mission reward) and an expense donut (player wages). *History*: a day-by-day ledger, one line per payment.
- **Sponsorship.** One active sponsor contract (an entry-level "Amateur Program" tier) and a list of missions tagged Daily, each with a progress bar (for example "assign 8 hours of Rest", 5 of 8) and a small cash plus XP reward.
- **Recruitment hub.** Balance and total daily wage at the top, then: player database (free agents and the transfer list, with a New Search button), scouting reports (tabs New, Shortlisted, Rejected; sort by last scouted), negotiations (Ongoing, Accepted, Rejected), provisional agreements (Reached, Closed), transfer list (Buy and Sell tabs, with an Add Player flow), transfer offers (Received and Sent) and a history timeline.
- **Player cards.** Name, age, country flag, the player's top three role ratings plus a "+N more" chip, a personality label (Casual, Balanced, Temperamental, Professional), morale %, energy %, current club and an asking price.
- **Contract sheet.** Club, type (Full-Time), job (Player), duration (42 days), wage per day, and a **cash prize split** between club and player (for example club 20 percent, player 80 percent).
- **Help cards.** One-time explanation cards with an "Understood" button. They explain that negotiations agree contract terms, that an agreement with a player who has a club creates a *provisional agreement*, that free agents sign directly, and that a provisional agreement is needed before a transfer offer to the player's club.

**What we learn (design observations, not rules):**
- The reference runs on real-time days with daily missions and tiny money numbers. That suits an online live-service game. Our Single Player edition is turn-based: a day passes when the manager presses Next Day or Play Match. There is no waiting and no daily-login pressure.
- Splitting prize money between club and player is a clever contract term: it is one more thing to negotiate and it ties player happiness to results.
- Talent trees give long-term progression, but a tree that adds match strength would let a high manager level beat good drafting. Our calibration (GDD section 9.1) is built around the draft and roster levers mattering.
- The provisional agreement step (agree terms with the player first, then the fee with the selling club) is a good flow for club-to-club transfers.
- Help cards, filter chips, empty-state text and a floating search button are good mobile patterns for a first-time player.

**Edition mapping:**

| Feature | Phase 1 (Single Player) | Later |
|---|---|---|
| Finances: Overview, Analytics, History | **Yes**, simple ledger and charts (see D-007) | Multiplayer adds trade income |
| Income: sponsor signing bonus, sponsor objective rewards, prize money. Expense: player and staff wages, facility upkeep | Yes | Merch and match-day income later |
| Sponsor contract | **Yes, "lite"**: choose 1 of 3 offers at the start of a season. Signing bonus plus per-split objectives (for example reach the playoffs, win a set number of matches, start a rookie). Missing an objective loses that reward only | Sponsor tiers tied to club reputation in Global |
| Daily missions | **No** (real-time habit loop) | Possibly Multiplayer and Global, where live operations make sense |
| One-time tutorial goals (for example "set a training plan", "make a Game Plan") with a small cash reward | **Yes**: gentle onboarding for new players | n/a |
| Player database of free agents with filters and saved searches | **Yes** | n/a |
| Scouting reports with New, Shortlisted, Rejected | **Yes** (uses the scouting formula in GDD) | n/a |
| Negotiation and contracts for free agents: wage, length (in splits), prize split | **Yes**, a short negotiation of up to 3 rounds | Negotiator talent later |
| Release or non-renewal of players, contract expiry | Yes | n/a |
| Club history timeline (joins, leaves, contracts) | Yes (cheap) | n/a |
| Manager level, XP and talents | **No**, deferred (D-014) | A later Single Player update, once the core loop is balanced |
| Club-to-club transfers, provisional agreements, transfer list, transfer offers | **No** (the Founder placed sale and transfer of players in the Multiplayer edition) | Multiplayer edition (D-015) |

**Adaptation rules (ours, for the Systems Lead):**
1. **Time.** Contract length is counted in splits (1 to 4), not days. Wages are paid per week of game time and shown per week, not per day.
2. **Economy balance.** All money figures are our own (task D-007). QA test: simulate 10 seasons for a default club under default play. It must not go bankrupt and must not snowball. There is no way to buy in-game money with real money (monetization principle: no paid advantage).
3. **Prize split.** A contract term between 50 and 90 percent to the player. A higher player share raises the player's willingness to sign and lifts morale after wins.
4. **Personality.** The four labels seen (Casual, Balanced, Temperamental, Professional) are common English words and fine to use. We map them to numbers: how steady training gains are, how fast Bond grows (Team Bonds), how swingy morale is, and how hard negotiation is. The Systems Lead sets the values.
5. **Talents (later).** If built: about 30 nodes, one MOBA-only tree, small bonuses, effects only on support systems (training speed, scouting accuracy, negotiation, energy recovery, Bond growth). No node adds match strength directly. The tree layout, icons and names are our own.
6. **Player names.** Generated from our own name tables per region. The generator must never produce the handle of a real pro player (right of publicity and IP). Names are data, not UI text.
7. **Flags.** Real country flags are fine and are display only. Languages are a separate field used by Team Bonds and are never derived from country (decided in GDD v1.4, section 4.2).
8. **Help cards.** One-time help cards with an "Understood" button, stored as translatable strings. The UI/UX Lead lists which screens get one.

**Draft design for the Multiplayer transfer market (not for Phase 1):**
- Flow: provisional agreement with the player (contract terms), then a transfer offer to the selling club (fee), then acceptance and signing. Offers expire.
- **No real-money trading of players or clubs.** It would be a store-policy and legal risk and it breaks the no-paid-advantage rule. Fees are in-game cash only.
- Anti-abuse: a fee band tied to the player's valuation (no gifting or price laundering between accounts), cooldowns on re-selling, a transfer history log, and a report function.
- Needs a backend and moderation, so it waits for the Multiplayer edition.

## 9. Player profile, attributes, mastery, tasks and career log (fourth set of screenshots)

**Seen:**
- **Squad list.** Each player card shows an avatar with a level ring, name, flag, age, morale % and condition %, contract days left, which genre the player is assigned to, the current task, and the top three role ratings plus a "+N more" chip.
- **Player profile.** Personality label, morale, condition, a role-rating strip, and a grid of **16 attributes** (Accuracy, Anticipation, Bravery, Communication, Composure, Concentration, Decisions, Dexterity, Determination, Flair, Leadership, Memory, Stamina, Quickness, Vision, Teamwork) with bars. A drop-down switches the grid between **Ability** (current) and **Potential** (the ceiling for each attribute, shown per attribute). Colour tells low from high at a glance. Buttons lead to Dynamics (bonds), Mastery, Talents, Analytics, Contract, Tasks and Cash Prize.
- **Help sheets.** Tapping Morale, Condition or Personality opens a short explanation ("performance might drop if morale or condition is too low; assign a Rest task"). Tapping an attribute opens a sheet with Current and Potential and two explanations: what it does **outside matches** and what it does **in a match** for each game genre, in plain words.
- **Mastery.** An XP level for the player, per role and per hero, with KDA and win-loss next to each.
- **Player analytics.** Date-range filter; games, win rate, KDA, farm per minute, damage per minute, vision per game; per-hero rows and a matchups table.
- **Contract page.** Club, type, job, duration with days left, wage, prize split; buttons Renew contract, Sell player, Release player. A paid-tier banner offers expiry reminders. A **career log** lists births, birthdays, signings and departures with a link back to each contract.
- **Tasks.** A per-player list of past and current tasks (Rest, a ladder practice session of 4 hours, replay analysis, scouting), each marked Reviewed once finished.
- **Cash Prize.** Total prize money earned and medal counts (gold, silver, bronze).

**What we learn:**
- Showing **Potential per attribute** is a better idea than one Potential number per player. It answers an open review item (S8: single Potential, undefined growth targets) and it makes scouting and training decisions concrete.
- The "outside matches / in a match" help text turns a stat list into something a newcomer can learn. It also forces every stat to have a job.
- Mastery per hero is our Familiarity (GDD 4.4); the idea of a visible XP level and a W-L record per hero is easy and motivating.
- Per-player match statistics are fun, but they must not become a second hidden model.
- One banner is a warning sign for our own monetization: a reminder before a contract expires is a basic safety net, and a new player who loses a star to an unnoticed expiry will feel cheated if it is paywalled.

**Our adaptation (recommended, proceeding unless the Founder objects):**
1. **Keep our 8 stats** (MEC, SEN, LAN, TFT, MAC, COM, CON, CLU) for Phase 1. They are what the calibrated match model uses. Sixteen attributes would multiply the calibration work and the screens, with no benefit before the core loop works.
2. **Change Potential to per stat.** Each of the 8 stats has its own ceiling. The training formula in GDD 7.3 is already per stat (`1 - stat/Potential`), so this is a data change, not a formula change. Generation (D-008): `Potential_stat = stat + a draw`, larger for younger players, capped at 99. Scouting shows each stat's ceiling as a range that narrows with reports. The profile gets an Ability / Potential toggle.
3. **A later "Deep attributes" view (optional, after the core loop works):** about a dozen small attributes that roll up into the 8 stats and also drive systems outside matches (Communication, Leadership and Teamwork feed Team Bonds; Stamina feeds condition; Determination and Concentration feed training gain; Memory feeds how fast Familiarity grows). Names are generic English words and are fine, but this view is not in Phase 1.
4. **Help sheets for every stat, plus Morale, Condition and Personality.** Two lines each: "outside matches" and "in a match". Stored as translatable strings. One-time help cards (see section 8) cover the first view.
5. **Hero and role mastery (Phase 1):** show Familiarity as a level with a W-L record per hero and per role. Data comes from our match log.
6. **Per-player match statistics (Phase 1, kept simple):** kills, deaths and assists per player in the match report, **derived from the simulated fights** (team totals consistent, shares weighted by the player's slot and rating). They are display only and never feed back into the model. Damage, farm and vision per minute are a later polish item. The QA test: totals add up, and no statistic contradicts the result (for example the winner never has fewer kills AND fewer objectives with no comeback story).
7. **Career log:** a timeline of signings, departures, birthdays, awards and notable matches. Cheap and nice.
8. **Per-player weekly plan:** one training focus per week, as in GDD 7.3. The reference's hourly tasks are a real-time system, so we skip them. Practice session wording: use "Practice Session", not the reference's phrase.
9. **Expiry reminders are free.** A club always gets a warning before a contract ends. Paid tiers add comfort and cosmetics, never safety nets (add to the monetization principles).

**IP notes:**
- The screenshots show the reference game's own hero names. We must not use these names, or close variants, in our 40 heroes. They are recorded in the IP risk log as names to avoid.
- Hero portraits, avatars and the talent icons are the reference game's art. We copy none of it. Avatars for players come in the visual phase.
- The reference player names mix unrelated origins and look machine-generated. Ours come from our own name tables (section 8, rule 6).

## 10. Competitions, the competitive rating and regions (fifth set of screenshots)

**Seen:**
- **Competitions hub.** Tabs Schedule, Featured and History, a region filter, a career summary (prize earnings, medal counts) and a rating card. Events are listed by wall-clock time with a type badge: *Open* (anyone can register), *Invitational* (invite only), a top-tier badge for a qualifier-fed event, and a *Promotion Tournament* for moving up a league. Running events show a LIVE badge. A banner says how many more competitions the club can register for or qualify for in the next 24 hours.
- **Competitive rating (a per-game ladder).** Moves with recent results, gives more credit for difficult or meaningful wins (upsets, bigger events, longer series), and lets older results fade over 28 days. New or inactive rosters sit at 0 and active ones can go below 0. There are two values: **Published** (a stable value from a nightly refresh, used for the official leaderboard and rank) and **Provisional** (recomputed live after every match, becoming the next published value). The leaderboard ranks positive ratings and can be filtered by state and by region.
- **Region picker.** A tree with checkboxes: world, then big regions, then sub-regions, then countries. Parent boxes show a partial state when only some children are chosen.

**What we learn:**
- A rating that rewards upsets, important matches and long series, and that **fades with time**, tells a manager "how are we playing now", which is more useful than a lifetime total.
- Splitting **published (nightly) from provisional (live)** is a sound online design. It stops leaderboard jitter, makes farming harder and reduces server load. It is irrelevant offline.
- The reference's events run on real clock times with daily caps. That is a live-service model. Ours is calendar-based.
- A region tree with partial-selection checkboxes is a good filter pattern, and it keeps region data-driven.

**Edition mapping:**

| Feature | Phase 1 (Single Player) | Later |
|---|---|---|
| **Form Rating** (our version of the rolling rating): one number per club, shown in the league table and club page | **Yes** (task D-017) | Multiplayer: published and provisional versions |
| Trophy cabinet: prize money earned, titles and medals, on the club page | **Yes** (cheap) | n/a |
| Single league plus playoffs | Yes (GDD 11) | n/a |
| Multi-tier leagues, promotion and relegation, open cups, invitationals, qualifier chains | **No** | **Global edition** (D-018) |
| Region filters and region leaderboards | Data fields only (`region`, `country` on clubs and players) | Multiplayer and Global |
| LIVE events and wall-clock schedules | No | Multiplayer and Global, where live operations exist |

**Draft design for the Form Rating (Phase 1, for the Systems Lead to refine):**
- Per club, `Form = sum over matches in the last 28 game days of K * Importance * (Result - Expected) * Fade`, where `Result` is 1 for a win and 0 for a loss, `Expected` is the model's own win probability from the two teams' ratings (so it matches our calibration table), and `Fade = max(0, 1 - age_days / 28)`.
- `Importance`: league match 1.0, playoff round 1.25, final 1.5; series length multiplier 1.0 for best of 1, 1.2 for best of 3, 1.4 for best of 5. Exhibition and Quick Match: 0 (they never move the rating, as decided in section 7).
- `K` is set so a normal league season ends with ratings spread over a readable range (target: the best club around +100, the worst around -100). QA test: the rating ranks clubs close to their true strength after one split, and an upset moves it more than an expected win.
- Quick Match opponents are chosen by team rating (GDD 4.4), not by the Form Rating.
- The name "ECR" and its description are the reference game's. We use our own name and wording ("Form Rating").

**Draft design for the Multiplayer and Global editions (not for Phase 1):**
- Rating state: a stable value refreshed on a schedule for the official ladder, plus a live provisional value. The refresh interval can be nightly.
- Anti-farming: diminishing returns against the same opponent, bot matches labelled and worth less, and no rating gain from private matches.
- Competition formats need **our own names**. Placeholder families: Open Cup (anyone registers), Invitational (rating threshold), Qualifier Series feeding a Premier event, Promotion Series (moves a club up a tier). Avoid "Masters" and other tier names used by existing esports circuits, and do not copy the reference's event titles.
- Regions: real countries are fine as player nationality (flags, languages for Team Bonds). The competition geography can be real regions or fictional realms to fit the fantasy-lite setting; that is a Founder decision for the Global edition. Keep the region tree in data.

**IP notes:**
- The leaderboard screenshot shows **real esports organizations** (for example well-known pro clubs, one with its real logo). We never use real organization names, logos, team names or pro-player handles in the game (trademark and right of publicity). All clubs are generated and fictional.
- Event names in the reference mix real cities and generic words. City names alone are fine, but we avoid the reference's exact event titles and any tier word tied to a real circuit.

## Decisions (Founder, 2026-11-07)
1. **Game Plan in Phase 1: YES**, the small version (about 8 sliders, a default plan, triggers "ahead" and "behind"), built after the core draft calibration.
2. **Team Bonds in Phase 1: YES**, with English-only data and the pair grid and maths in place.
3. Exhibition and Quick Match in Phase 1: recommended, proceeding unless the Founder objects.
4. **Time model, Phase 1 (recommended, proceeding unless the Founder objects):** turn-based calendar, no real-time waiting, no daily missions in Single Player.
5. **Recruitment, Phase 1 (recommended):** free agents only, with scouting reports, negotiation and contracts. Club-to-club transfers wait for the Multiplayer edition, as the Founder's release path says. Open question for the Founder: allow transfers with AI clubs in a later Single Player update?
6. **Sponsors, Phase 1 (recommended):** sponsor "lite" (one contract, objectives per split) plus one-time tutorial goals. Daily missions are not in Single Player.
7. **Manager level and talents (recommended):** deferred until the core loop is balanced. If built, no talent adds match strength directly.
8. **Finances screens (Overview, Analytics, History):** included in Phase 1 (task D-007).
9. **Player profile (recommended):** keep our 8 stats for Phase 1, change Potential to per stat, add stat help sheets, hero and role mastery levels, simple derived KDA and a career log (section 9). A deeper attribute view is a later option.
10. **Expiry reminders stay in the free tier** (a safety net, not a perk).
11. **Form Rating in Phase 1 (recommended):** one rolling rating per club with a 28-day fade and an importance weighting, plus a trophy cabinet. Multi-tier leagues, cups and invitationals wait for the Global edition.
12. **Competition geography for the Global edition: real regions (Founder, 2026-11-07).** Players, clubs and competitions use real-world regions and countries (for example Southeast Asia, Europe, the Americas). Clubs, teams and players themselves stay fictional (see the IP rules in section 10).
