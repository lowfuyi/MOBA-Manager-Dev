# Game Design Document v1.8

Status: DRAFT v1.8. v1.8 records how recruitment of free agents, contracts, the cash ledger and the sponsor were implemented in Alpha 0.3 (sections 7.2 and 7.6, Implementation notes). v1.7 records how training, fatigue and ageing were implemented in Alpha 0.2 (section 7.3, Implementation notes) and the Game Plan QA result (CALIBRATION-9.1 addendum). v1.6 adds the Founder's match formats and pacing rule (section 8.7). v1.5 re-tunes the draft constants after the full-pipeline calibration (section 9.1, P-003). v1.4 answered the independent QA review of v1.3; v1.5 re-tunes the draft constants after the full-pipeline calibration (section 9.1, P-003). Findings and fixes are in section 16. **v1.4 to v1.8 have not had a second independent review yet.** Author: Game Design Lead and Systems Lead. Date: 2026-11-07.
Next: Founder review. Done: P-001 (skeleton), P-002 (simulator with golden tests), content data, P-003 first pass (9.1). Open: paired lever tests, Phase 1 rating-scale calibration, joint Game Plan test.

All numbers in this document are **v0 placeholders** unless marked otherwise. They exist so the rules can be tested. QA & Balance tunes them against the targets in section 9, using `tools/proto_sim.py` as the reference model.

---

## 1. Vision

A mobile esports **manager** game, MOBA only. The player is the club owner and head coach. They scout and sign players, train them, build a roster, and win matches through preparation and draft decisions. Matches are simulated; the player never controls a hero.

**One-line pitch:** Build a team from unknown talents into a world champion by out-thinking rivals in the draft.

### Pillars

1. **The draft is the game.** Pick and ban decisions should be one of the biggest levers in a match, and no draft should be "solved".
2. **Every player is a person.** Players have strengths, weaknesses, form, morale and growth. Losing a star hurts.
3. **Results are readable.** After every match the player can see why they won or lost, and what to change.
4. **Fair progression.** Skill and planning beat spending. (Monetization stance is a Founder decision; see `DECISIONS.md`.)
5. **Short sessions.** In Full mode one game takes at most about 5 minutes from tapping Play to the result, draft included (budget in section 8.7, a Founder requirement). In Quick mode (auto-draft, skim the result) it takes under a minute.

### Non-goals for v1

Direct hero control, real-time multiplayer matches, a 3D map, voice chat, esports betting, real-money trading of players.

### Editions and roadmap (Founder decision)

The game ships in stages, and the edition name changes with the stage. "MOBA Esports" is a working title.

| Edition | Adds | In this document |
|---|---|---|
| **MOBA Esports: Single Player** (first release, Android first, English text) | Offline play on the local device | Everything except the items below |
| MOBA Esports: Multiplayer | Internet hosting and matching, friends, sale and transfer of players, ranked ladder | Not specified yet (tasks D-012, D-015) |
| MOBA Esports: Global | Seasons, regional tournaments (real-world regions), mid-season invitationals, a World Cup, multi-tier leagues | Not specified yet (task D-018) |

All player-facing text lives in translatable string tables from day one; languages beyond English arrive at the live release.

---

## 2. The match world (genre conventions, original names)

Genre conventions we use freely: three lanes, a jungle, waves of minions, towers, neutral objectives, gold and experience, items, an enemy base to destroy, five players per team.

Original names (all **placeholders pending IP Checker name search**):

| Concept | Placeholder name |
|---|---|
| The map | Hollowmere |
| The base core | The Cairn |
| Lane minions | Waves |
| Early neutral objective (gold and speed buff) | Stoneback |
| Late neutral objective (decisive team buff) | Moonhulk |
| Jungle camps | Moss camps |
| Lanes | Top, Mid, Bot |
| Playable characters | Heroes |

The map is an abstraction in v1: the simulator reasons about lanes, the jungle and objectives, not coordinates. A minimap view is a presentation layer added later.

---

## 3. Roles and slots

Five **slots** per team: Top, Jungle, Mid, Bot Carry, Support. The five starters are assigned to slots in the **lineup** before the draft. Each player has one **primary** role and may have one **secondary** role.

- **BaseRating uses the slot's weights** (section 4.3) applied to the player's stats.
- **PlayerFit** (player vs slot): primary 1.00, secondary 0.93, unfamiliar 0.80.
- **HeroFit** (hero vs slot): the hero's primary role 1.00, secondary role 0.95, other 0.85.
- In the draft, every pick is made **for a slot**. The AI sets its lineup before the draft starts, and its picks respect HeroFit.
- **AI lineup rule:** choose the assignment of five starters to five slots that maximizes the sum of `BaseRating(slot) * PlayerFit`; ties broken by the higher sum of primary-role matches. Exactly 5 starters, one per slot.

| Slot | Lane | Job in the sim |
|---|---|---|
| Top | Top | Frontline or duelist, strong laning |
| Jungle | Jungle | Tempo, objectives, ganks, early lane influence |
| Mid | Mid | Burst or control damage, roams, wave control |
| Bot Carry | Bot (with Support) | Sustained damage, scales hardest into late game |
| Support | Bot (with Carry) | Vision, protection, engage or peel, objective setup |

---

## 4. Players

### 4.1 Visible stats (1 to 100)

| Stat | Meaning |
|---|---|
| MEC (Mechanics) | Execution speed and accuracy |
| SEN (Game Sense) | Awareness and decision quality |
| LAN (Laning) | Early trading and wave control |
| TFT (Teamfighting) | Positioning and target selection in fights |
| MAC (Macro) | Rotations, objectives, vision, tempo |
| COM (Communication) | Teamwork; feeds team chemistry |
| CON (Consistency) | Reduces randomness; the team average sets how noisy a match is |
| CLU (Clutch) | Performance in late, high-pressure fights |

### 4.2 Hidden and dynamic values

| Value | Range | Notes |
|---|---|---|
| Potential | 1 to 100 **per stat** | Soft cap for each stat's growth; each of the 8 stats has its own ceiling. Revealed only through scouting and time |
| Player Form | -10 to +10 | Moves with results (section 8.6); each day `Form = Form * 0.9` (mean-reverts to 0). Not the same thing as the club's Form Rating (section 10.1) |
| Morale | 0 to 100 | Results and playing time (section 8.6); each day drifts 1 point toward 60; a starter who has missed 2 or more matches in a row loses 6 more per further match missed (about -12 a week against +7 drift, so a benched starter really does sour) |
| Fatigue | 0 to 100 | See section 7.3 |
| Hero familiarity | 0 to 100 per hero | Starts 0 to 30 for new heroes; grows when played and trained; clamped to 0 to 100 |
| Age | 16 to 35 | Affects growth rate and eventual decline |
| Personality | one of 4 | Professional, Balanced, Casual, Temperamental. Visible on the player card; see the table below |
| Languages | list of (language, fluency 0 to 100) | Feeds Understanding in section 7.7. Phase 1 data: everyone speaks English at 100 |
| Country and region | text, from a fixed list | Display (flag) and later leaderboards. Never changes gameplay by itself |

**Personality (v0 values, tuned in D-013).** No personality is strictly best; each trades one thing for another.

| Personality | Training gain | Morale swing after results | Bond growth | Contract negotiation |
|---|---|---|---|---|
| Professional | x1.05 | x0.8 | x1.0 | Accepts at 1.00 x asking wage |
| Balanced | x1.00 | x1.0 | x1.0 | Accepts at 0.95 x asking wage |
| Casual | x0.90 | x1.0 | x1.1 | Accepts at 0.90 x asking wage |
| Temperamental | x1.00 | x1.5 | x0.8 | Accepts only at 1.10 x asking wage and walks away after round 2 |

**Help text.** Every stat, plus Morale, Fatigue and Personality, has a short help sheet with two lines: what it does in a match and what it does outside matches (training, bonds, fatigue). Stored as translatable strings.

### 4.3 Slot weights

Each slot converts the five performance stats into a **base rating** (rows sum to 1.00).

| Slot | MEC | SEN | LAN | TFT | MAC |
|---|---|---|---|---|---|
| Top | 0.25 | 0.15 | 0.30 | 0.20 | 0.10 |
| Jungle | 0.15 | 0.25 | 0.05 | 0.20 | 0.35 |
| Mid | 0.30 | 0.20 | 0.25 | 0.15 | 0.10 |
| Bot Carry | 0.35 | 0.10 | 0.25 | 0.25 | 0.05 |
| Support | 0.10 | 0.30 | 0.10 | 0.20 | 0.30 |

`BaseRating = sum(weight[stat] * stat)`

### 4.4 Match rating

For each match, each starter's **rating per phase** is:

```
Cond        = Form*0.4 + (Morale-50)*0.06 - 0.15*max(0, Fatigue-25)        (points)
HeroFactor  = (0.94 + 0.06*Familiarity/100) * (0.90 + 0.10*min(1, MEC/(15*Difficulty)))
Fit         = PlayerFit * HeroFit
PhaseBase   = Early: 0.7*BaseRating + 0.3*EarlyStat(slot)
              Mid:   BaseRating
              Late:  0.8*BaseRating + 0.2*CLU
EarlyStat   = LAN for Top, Mid, Bot Carry; MAC for Jungle; SEN for Support
Rating(phase) = (PhaseBase + Cond) * HeroFactor * Fit
                * (1 + (HeroPower[phase] - 50)/200) * MetaMod
```

`HeroPower[phase]` is the hero's early, mid or late power (section 5). `MetaMod` is the hero's current patch modifier (0.97 to 1.03). `Difficulty` is the hero's 1 to 5 rating: a hero needs about 15 MEC per difficulty point to be played at full effect.

---

## 5. Heroes

Heroes are **data**: attributes and tags. Names and visual identity are created by the Content Lead and screened by the IP Checker. In v1 a hero's abilities are summarized as tags; full ability text is not needed for the simulation.

### 5.1 Archetypes (original names) and default tags

| Archetype | Typical slots | Default tags |
|---|---|---|
| Bruiser | Top, Jungle | Frontline |
| Bulwark | Top, Support, Jungle | Frontline, Engage |
| Spellcaster | Mid | Waveclear (Poke or Scaling added by Content) |
| Gunner | Bot Carry | Scaling |
| Shade | Mid, Jungle | Pick |
| Mender | Support | Protect |
| Binder | Support, Mid | Pick (Engage or Poke added by Content) |

Each hero has 2 to 4 tags: the archetype defaults plus up to two more chosen by the Content Lead.

### 5.2 Attributes (data schema)

| Field | Values |
|---|---|
| id, name | Unique; name screened by IP Checker |
| archetype | One of the seven above |
| role_primary, role_secondary | Slots |
| power_early, power_mid, power_late | 38 to 62 each; the three sum to `144 + 3*difficulty` (147 to 159), so harder heroes are stronger when played well |
| damage_type | Physical, Magic, Mixed |
| range | Melee, Mid, Long (display and AI hint only in Phase 1; feeds no formula) |
| difficulty | 1 to 5 |
| tags | Engage, Poke, Protect, Pick, Splitpush, Frontline, Waveclear, Scaling (Splitpush is display and AI hint only in Phase 1; the other seven feed section 5.3) |
| strong_vs | Up to 3 hero ids this hero counters |

### 5.3 Composition scoring

Each team's picks produce a **CompMod** and a **comp style**. `CompMod = clamp(sum of the terms below, -15%, +15%)` (constants calibrated in P-003, section 9.1; v1.2 had 10%).

- **Needs:** at least one Frontline, at least one Engage or Pick, at least one Waveclear. Each missing need is -5%.
- **Damage balance:** Physical counts 1 physical, Magic 1 magic, Mixed 0.5 of each. If either total is 3.5 or more, -6%.
- **Synergy pairs:** four pair types exist: Engage with Pick, Protect with Scaling, Poke with Waveclear, Frontline with Engage. Each pair type counts **once** if both tags are present on two different heroes. +4% each, so the raw maximum is +16% (the clamp holds it at +15%).
- **Comp style:** Dive score = count of Engage + Pick tags; Siege score = Poke + Waveclear; Protect score = Protect + Scaling. The style is the highest score if it is at least 4 and at least 1 above the second; any tie or lower score gives Skirmish. (Waveclear is required by Needs, so a Siege score of 1 is normal and does not make a Siege comp.)
- **Style triangle:** Dive beats Siege beats Protect beats Dive. The winning style gets **+4% and the losing style gets -4%** on **teamfight** contests only (an 8% relative swing; this is what the prototype tests). Skirmish is neutral. `StyleEdge` below means this signed +4% or -4%.
- **Lane matchups:** in the Top, Mid and Jungle contests, a hero that is `strong_vs` its opposing hero gives that contest +10%. In the Bot lane, any `strong_vs` link between the two heroes on either side counts, capped at +10% for the lane.

**Realistic draft range.** Simulator level (prototype, equal players, unchanged by P-003): a +5% comp beats none 54.0%; +10% beats none 57.4%; +5% beats -5% 57.4%. With the real 40 heroes, over all 32,768 one-hero-per-slot lineups, CompMod has a median of about +7%, a standard deviation of 4.4 points, and sits at the +15% cap in 3.3% of lineups; the worst lineups reach about -11%. In the full pipeline (section 9.1) two sensible drafts differ by about 3 win-rate points on average, and a careful drafter beats a comfort-pick drafter by about 5 points. The draft is a margin lever; squad strength still dominates.

### 5.4 Patches and the meta

The league runs on **patches** (for example every two in-game weeks). Each patch changes MetaMod for a subset of heroes by small amounts, so strong picks rotate. The AI drafts using current MetaMod, so the meta is visible to the player.

---

## 6. Draft

Both teams draft before every match. The hero pool is **40 heroes** (about 8 per slot).

**Sides:** Blue picks first. In a league match the higher-ranked team chooses the side; in the prototype Blue is assigned by a seeded coin flip.

**Sequence (v1, our own order):**

1. Ban phase 1: Blue, Red, Blue, Red (2 bans each).
2. Pick phase 1: Blue 1, Red 1, Red 2, Blue 2, Blue 3, Red 3.
3. Ban phase 2: Red, Blue (1 ban each).
4. Pick phase 2: Red 4, Blue 4, Blue 5, Red 5.

Each team ends with 3 bans and 5 picks; 16 heroes leave the pool of 40. The order can change in later versions.

**Rules:** a hero can be picked or banned once per match. Off-role picks are always allowed (at HeroFit 0.85). **Role floor:** after any pick, each slot must still have at least as many available heroes with that primary role as the number of teams that still need that slot; after any ban, at least that number plus 1. A move that would break this is blocked. Because off-role picks are always allowed, the floor is a safety net that should almost never bind; QA proves no draft dead-ends with a property test of 100,000 random AI-vs-AI drafts plus an exhaustive search on a reduced pool (12 heroes, 4 per team sequence), and the floor is removed if it never triggers. (The full 40-hero tree has about 10^24 sequences, so it cannot be searched.) Timers and the short draft profile are in section 8.7 (the v1.5 figure of 20 seconds for all 16 decisions broke the 5-minute game budget).

**Player experience:** the draft screen shows each starter's familiarity with every available hero, current MetaMod, and a live preview of CompMod, style, and lane matchups.

**AI drafting (v1):** each pick scores candidates as `familiarity fit * 0.35 + MetaMod * 0.20 + composition need * 0.20 + counter value vs known enemy picks * 0.25`, plus noise that grows as AI difficulty drops. Bans target the opponent's highest `familiarity * MetaMod` heroes, with a 25% chance of banning by MetaMod alone so decoy familiarity does not work reliably.

---

## 7. Management loops

### 7.1 Calendar

Time advances in **days** when the player taps Continue. A **full season** has two splits (9 weeks each, 2 match days per week, 18 league matches per split) plus playoffs per split and a short off-season, so about 42 player matches. Phase 1 plays **one split plus playoffs** (18 league matches plus up to 6 playoff matches) as its "season". Promotion and relegation use split standings. Ranking: points (win 3, loss 0), then head-to-head wins, then the sum over league matches of the simulator's `Final` from the club's side (a margin measure), then a seeded draw from the stream `sched:<split id>:tiebreak`. A league match is one game (best of 1) in Phase 1; each game of a longer series has its own match id `<series id>-g<k>`, its own draft and its own seed. Fatigue, Bond and familiarity update per game played; Form Rating and player Form update once per series. Real-time timers are not used offline: a day passes only when the player presses Continue or plays a match, with no waiting, no daily-login missions and no wall-clock events. Contract length is counted in splits and wages are paid and shown per week.

### 7.2 Roster and contracts

- 5 starters, up to 5 substitutes (max 10 players). Substitutes may be swapped in before any match.
- Contracts have a length (in splits), a wage, and optional clauses (release fee, bonus).
- Free agents and other clubs' players can be approached. The AI values an offer on wage versus the player's value, role need, club standing and playing time. Exact valuation is task D-007. **Phase 1 recruitment (free agents only; club-to-club transfers belong to the Multiplayer edition):**
  - **Player database:** the free agents, with filters (role, age, rating range, languages, price) and saved searches.
  - **Reports workflow:** each scouted player has a report that the manager marks Shortlisted or Rejected (New by default).
  - **Negotiation:** up to 3 rounds. The manager proposes wage, length (1 to 4 splits) and **prize weight** (50 to 90, a share weight, not a percentage of the prize). The asking wage is `max(20, 2 * (BestSlotRating - 40)) * PotentialFactor` per week, where `PotentialFactor = clamp(1 + 0.01 * (mean Potential - mean stat), 1.0, 1.3)`, so promising youngsters are not cheap. Each player has a hidden acceptance noise of plus or minus 5 percent, fixed by a seeded draw from his id. He accepts if the offer is at least his personality's threshold times the asking wage (Personality table), adjusted by plus or minus 2 percent for length and prize share. A refusal only says *far below*, *below* or *close*, never the exact number, and after a failed negotiation the player will not talk to the club again for 14 days, so the club cannot bisect to the minimum. The club must be under its wage cap and have the cash for the signing. Exact acceptance maths is task D-013.
  - **Release and expiry:** releasing a player costs 50 percent of the remaining contract wages (v0). The club always gets a warning before a contract ends (a free safety net, never a paid perk).
  - **Prize share:** when the club wins prize money, 40 percent of it (v0) goes to a player pool, divided among the players on the roster for that event in proportion to their prize weights; the club keeps 60 percent. A higher weight raises willingness to sign and gives a small morale lift after prize wins.
  - **Career log:** signings, departures, birthdays, awards and notable matches are recorded per player.


**Implementation notes (Alpha 0.3, 2026-11-08; constants in `game/data/economy_v0.json`).** Built: free-agent market, negotiation, renewal, release, expiry, wage cap. Not built yet: saved searches, scouting reports, languages filter, prize weight and the player prize pool, clauses, career log.
- **Contracts** exist for the managed club only. A contract is `{wage per week, seasons left}`; "left" counts the current season, so 1 means final year. Starting contracts are the asking wage x a hidden +-8% jitter, 1 to 3 seasons (seeded by player id).
- **Asking wage** is the 7.2 formula `max(20, 2 x (BestSlotRating - 40)) x PotentialFactor`, rounded, shown to the manager as "market value". What a player really accepts is `asking wage x personality threshold (Professional 1.00, Balanced 0.95, Casual 0.90, Temperamental 1.10) x (1 +- 5% hidden noise seeded by player id) x (1 + 0.01 x (2 - length))`. He answers only "close" (95 to 100 percent of that), "below" (80 to 95) or "far" (under 80). Longer contracts are up to 2 percent cheaper.
- **Negotiation:** 3 offers, then a 4-round lockout. A Temperamental player walks after the second refusal. A released player is locked out for 4 rounds as well. Offers are blocked (before they count) when the squad is full (10), the balance is negative or below the signing fee, or the new wage bill would pass the wage cap.
- **Signing fee** is 2 weeks of wages; renewing a final-year contract has no fee and adds the new length to the seasons left. **Release** costs 50 percent of the wages still owed (weeks left in this season plus the full later seasons) and needs at least 6 players on the roster. The roster maximum is 10.
- **Season change:** every contract loses one season; players whose contract ran out leave to the free-agent pool. If that would leave fewer than 6 players the board keeps the best of them on one-year deals. After the season is over the expiring players no longer take a squad place, so replacements can be signed before the new season starts.
- **Free agents** train on the coach's plan and age like everybody else; released and expired players join the pool. AI clubs do not sign, release or pay anybody (their rosters are the data files').

### 7.3 Training and fatigue

Each player has one **training focus** per week: a stat, a hero's familiarity, or a **team scrim** (builds chemistry).

```
gain = max(0, base * (1 + 0.1*CoachLevel + 0.05*FacilityLevel) * (1 - stat/Potential) * AgeFactor * (1 - Fatigue/200))
```

`base` is 0.5 points per week. `CoachLevel` and `FacilityLevel` are 1 to 5 and add together inside the bracket. Player generation guarantees `stat <= Potential`; if it ever isn't, `gain` is 0. `AgeFactor`: 16 to 20 = 1.3, 21 to 23 = 1.1, 24 to 26 = 0.8, 27 to 29 = 0.5, 30 and over = 0.25. From age 29, MEC declines about 1 point per season, and from age 31 TFT and SEN decline about 0.5 per season (v0).

Fatigue (clamped 0 to 100, reset to 0 at the off-season): +15 per match played, +5 per training week, -(5 + 0.5 x FacilityLevel) per rest day. A day with an Exhibition or Quick Match is not a rest day. A normal week for a starter (2 matches, 5 rest days) nets `+10 - 2.5 x FacilityLevel`: +7.5 at Facility 1 (the penalty line of 25 is crossed around week 4 and fatigue is near 68 by week 9), +2.5 at Facility 3, zero at Facility 4. So a low-facility club must rotate, and facility upgrades have a real payoff. QA checks that no schedule is strictly dominant and that rotation is sometimes right.

Familiarity: +3 per match played with the hero, +1.5 x (1 + 0.1 x CoachLevel) per week of focused training, -0.5 per week if unused and above 50.


**Implementation notes (Alpha 0.2, 2026-11-08; constants in `game/data/training_v0.json`).**
- One calendar tick is one match day (half a week): weekly values are halved, so a starter who trains nets +2.5 fatigue per match day, +5 per week, as in the text above (Facility 2).
- Coach and Facility are fixed at level 2 for every club until staff and facilities exist (D-007).
- Training focus options in Alpha 0.2: one of the eight stats, one hero's familiarity, or **Rest** (no training, no training fatigue). Team scrim waits for Team Bonds. The default is the coach's pick: the stat with the largest (slot weight x room below Potential) for the player's main role. Every AI player always uses it.
- Fatigue enters the match rating through `Cond` exactly as in 4.4 (`-0.15 x max(0, Fatigue - 25)`); Form and Morale terms are not built yet.
- AI lineups rotate: start from the best lineup, then a bench player replaces a starter when his rating here minus his own fatigue penalty is higher. With no fatigue this is exactly the best lineup. AI clubs refresh their best lineup on patch days.
- Ageing happens at the start of the next season: everybody is one year older, MEC -1 from age 29, TFT and SEN -0.5 from age 31 (ages as of the season just finished), fatigue resets to 0.
- Playoffs: the managed club's playoff games tick fatigue and training like a match day; AI-versus-AI playoff games do not tick (they have no calendar in Phase 1).
- Familiarity gains from match play and training are not capped per week; the decay of an unused hero (-0.5 per week above 50) is not built yet.

### 7.4 Scouting

Scouts are assigned to a role (regions arrive with the Global edition). Each report reveals stats as ranges with half-width `max(3, 16 - 2*ScoutLevel - 2*ReportsSoFar)` points, where `ReportsSoFar` counts reports on that player. The true value is always inside the range, but the range is centred at an offset of up to half the width, drawn once per player and stat from the stream `scout:<player id>` and never redrawn, so ranges mislead without being false and combining several reports never reveals more than the narrowest one. Potential is shown as a star range that narrows over time. Hidden gems and overrated players both exist. Because Potential is per stat, a report shows each stat's current range and its ceiling range, so the manager can see where a young player can grow. A player's profile has an **Ability / Potential** toggle.

### 7.5 Staff and facilities

| Staff | Effect |
|---|---|
| Head Coach (level 1 to 5) | Training gain multiplier |
| Analyst (level 1 to 5) | StaffBonus +0.4% per level to team ratings (max +2%). The draft preview is always exact (section 6) |
| Scout (level 1 to 5) | Narrower reports |

Facilities (levels 1 to 5): each level adds +5% training gain and +0.5 fatigue recovery per rest day.

### 7.6 Finance

**Phase 1 income:** a sponsor contract (signing bonus plus objective rewards), prize money, and one-time tutorial goal rewards. **Expenses:** player wages, staff wages and facility upkeep. Transfer fees and transfer income arrive with the Multiplayer edition. There is no way to buy in-game money with real money.

- **Sponsor lite:** at the start of a season the manager picks 1 of 3 offers. Each pays a signing bonus and per-split objective rewards (for example reach the playoffs, win a set number of matches, start a rookie). Missing an objective loses that reward only. Daily missions are not part of Single Player.
- **Tutorial goals:** one-time goals ("set a training plan", "make a Game Plan") with a small cash reward, to teach a new player the game.
- **Ledger:** an Overview (balance and a week chart), Analytics (profit and loss over time, income and expense by source) and History (every payment as one line).
- **Rules:** each tier has a wage cap. A balance below zero blocks new signings, staff and facility upgrades. If the balance stays below zero for 4 weeks in a row the board dismisses the manager (a game-over screen offering the last autosave), so the economy test in 9.2 has a hard failure to look for; the full lose-condition design comes before launch (section 13). Exhibition and Quick Match payouts, goals and objectives do not exist: sponsor objectives and tutorial goals count league and playoff matches only, except a tutorial goal that names an Exhibition. Money numbers are task D-007.


**Implementation notes (Alpha 0.3, 2026-11-08; constants in `game/data/economy_v0.json`).** Built: balance, per-round wages and retainer, sponsor choice with objective, league and playoff prize money, wage cap, debt and dismissal, History ledger. Not built yet: Analytics tab, tutorial goals, staff and facility costs.
- **Time:** a league round is half a week; wages and the sponsor retainer are paid after every round (18 rounds = 9 weeks of cash a season). Playoffs cost nothing and pay prize money.
- **Revenue base R0** = the wage bill of the club's starting roster x 1.25, growing 3 percent a season. Every sponsor offer and prize is a multiple of R0, so all ten clubs have the same shape of economy (a strong club earns and spends more, not relatively more). Starting balance = 8 weeks of the wage bill (plus the sponsor bonus). Wage cap = 1.05 x R0 a week.
- **Sponsors (pick 1 of 3 before the first game; fixed afterwards):** Steady Partner 0.85 R0 a week, bonus 1.5 R0, no target. Playoff Backer 0.70 R0, bonus 1.0 R0, +5 R0 for finishing at or above the target rank. Win Bonus Brand 0.55 R0, no bonus, +8 R0 for reaching the target wins. **Targets scale with the club's strength rank at the start of the season** (wins = expected wins at a win rate from 72 percent for the strongest club to 28 percent for the weakest, over 18 games; rank = strength rank minus one, never better than 2nd or worse than 6th), so every club faces a roughly fair gamble. The default roster is covered by Steady Partner (about +6 percent a week); a missed target costs 1.9 R0 (Playoff Backer) or 4.2 R0 (Win Bonus Brand) against Steady Partner.
- **Prize money:** league rank 1 to 6 pays 3.0, 2.2, 1.6, 1.2, 0.6, 0.6 R0 (paid when the league phase ends); champion 6.0 R0, runner-up 3.0 R0.
- **Dismissal:** 8 rounds in a row below zero (the rule's 4 weeks, at two rounds a week). The game-over screen offers the last autosave from before the dismissal, which stays on disk (saving is disabled once dismissed), a new career or the menu.

### 7.7 Team Bonds (replaces the single Chemistry number)

Chemistry is no longer one hidden number. Each pair of starters has a **Bond** and each direction has an **Understanding**.

- **Bond** (0 to 100, symmetric). Stored for **every pair on the roster** (up to 45), because rotating substitutes in is a real choice; a pair is deleted when either player leaves, and a re-signed player starts again at 20. Each event gives `gain = base * (100 - Bond)/70 * growth`, so gains shrink as a pair matures: `base` is +4 per game the two play together, +3 per team-scrim week (both players must have the scrim as their focus), +2 per Exhibition game (section 7.9); `growth` is the geometric mean of the two players' Bond growth factors (Personality table). A new club's bonds start at 30. A new starter's bonds with the four others start at 20. Minimum 0. At the default rate a pair needs about 30 games together to pass 85, so bonds are a season-long investment, not a quick farm.
- **Language factor** `Lang(i,j)`: 1.0 if the two share a language with fluency at least 50 for both, else 0.65 (v0).
- **Understanding** (0 to 100, directional, 20 values among the starters): `U(i<-j) = Lang(i,j) * Bond(i,j) * (0.4 + 0.6 * COM_j/100)`. Read it as "how well player i takes in what player j says".
- **Team chemistry** `Chem` = the mean of the 20 Understanding values.
- `ChemBonus = 0.042 * Chem/100` (maximum 0.042). `TeamMod = ChemBonus + StaffBonus`, as before.

**Worked numbers (v0, checked by the unit tests):** Bond 60 and COM 60 give `U = 60 * 0.76 = 45.6`, so ChemBonus = **1.92 percent** (target 1.7 to 2.0). A new club (Bond 30, COM 60) starts at 0.96 percent. At Bond 100 and COM 60 the bonus is 3.19 percent, and at Bond 100 and COM 100 it is 4.2 percent. Replacing one starter at Bond 60 means eight of the twenty values drop from 60 to 20, which costs about 0.5 percent; a shared-language mismatch multiplies the affected values by 0.65. Raising the whole roster's COM by 40 (from 60 to 100) adds about 0.6 percent at Bond 60 and 1.0 percent at Bond 100. The whole Bond range (30 to 100) is worth about 2.2 percent, roughly 3 win-rate points, so Bonds matter but never outweigh the draft (CompMod up to 15 percent).

**Change from v1.2:** COM enters through Understanding only (the old formula also multiplied by `0.5 + avgCOM/100`), and a replaced starter costs the new pairs rather than a flat -25 for everyone. The full-pipeline calibration in section 9.1 must be re-run with bonds in the loop.

**Screens:** a pentagon of the five starters (link thickness for Bond, colour for Understanding), a 5x5 Understanding grid, and a languages list per player. In Phase 1 every player speaks English at 100, so `Lang` is always 1.0 and the grid is a pure display of Bond and COM. The maths is tested with synthetic multi-language rosters in the unit tests, so switching real languages on later needs no rework. Language fluency is a gameplay trait only, never tied to nationality or ethnicity in text or art.

### 7.8 Game Plan (the coach's second lever besides the draft)

A **Game Plan** is a set of 8 controls (7 sliders from -100 to +100 and one 4-way choice; default 0 / none = neutral) with an optional **trigger**. A player keeps one default plan plus up to 3 triggered plans (convenience, never extra strength: section 11). The plan acts on the simulator only through three hooks that the simulator input already carries (section 8.1): `contest_mod` (a fraction added to the team's rating entering one named contest), `contest_var` (a multiplier on the team's noise in one contest) and `variance_mult` (noise in every contest). **Plans never change the contest weights**, so all weights still sum to 1.00 and the carry-over term keeps its meaning.

Each control below is **zero-sum in rating**: the final-score-weighted sum of its `contest_mod` values is 0. The final-score weights are top 0.084, mid lane 0.084, bot 0.084, jungle 0.048, early objective (obj_mid) 0.105, mid fight 0.195, late objective (obj_late) 0.100, late fight 0.300. A control therefore moves strength between contests and helps only when the team is stronger in the contests it favours; or it changes variance, which helps the underdog and hurts the favourite. With `x = slider / 100`:

| Control | contest_mod / contest_var at +100 (the mirror applies at -100) |
|---|---|
| Spread out / Group up (g) | both fights +0.020g; top, mid lane, bot, jungle -0.033g |
| Tempo / Scale (t, + favours late) | top, mid lane, bot, jungle -0.030t; obj_late and fight_late +0.0225t |
| Mid objectives (m) | obj_mid +0.030m; fight_mid -0.0161m |
| Late objectives (l) | obj_late +0.030l; fight_late -0.0100l |
| Lane aggression (a) | contest_var of top, mid lane and bot x(1 + 0.25a); no rating change |
| Jungle focus (choice: none, Top, Mid, Bot) | jungle -0.020; the chosen lane contest +0.0114 |
| Support stays / roams (s) | bot -0.020s; obj_mid and obj_late +0.0082s |
| Play safe / Take risks (r) | `variance_mult` x(1 + 0.20r) |

The exact numbers live in `game/data/game_plan_v0.json` (task D-009), and a unit test checks every control's weighted rating sum is within 0.0005 of zero. (The old Peel/Engage and Comeback-focus sliders were removed: Peel/Engage duplicated the draft's style lever without a defined cost, and Comeback focus was free.)

**Triggers (v0):** `default`; `ahead after early` (`A_early > +0.40`); `behind after early` (`A_early < -0.40`) (each fires in about 18 percent of equal-team matches; the earlier +-0.15 fired in about 73 percent combined, which made plans meaningless); `against Dive`, `against Siege`, `against Protect` (the opponent's composition style). Triggers are listed in a priority order the player sets; the first match wins, and the default plan applies otherwise. A phase-outcome trigger changes only the mid and late contests: the engine runs the match once with the default plan to read `A_early` (early contests do not depend on later hooks and the noise is identical), picks the plan, then runs the final pass with the early hooks of the default plan and the mid and late hooks of the chosen plan.

**AI clubs** get plans generated from their roster and composition. **Reports** state which control mattered, by the same counterfactual method as the draft edge (section 8.5).

**QA requirements (section 9.2):** no control or combination of controls beats neutral by more than 3 win-rate points on held-out seeds, and the best plan differs between rosters and opponents. Out of scope in v1: items, spells, per-hero micro positioning, vision.

### 7.9 Exhibition and Quick Match

Two offline modes for practice. They never change the league table, the Form Rating (section 10.1), Form or Morale.

- **Exhibition:** pick any club in your league and play best of 1, 3 or 5. Each series uses up one calendar day (so it competes with training and rest). Fatigue +5 per game (instead of +15), Bond +2 per game for the starters (section 7.7). Intended for testing drafts and Game Plans.
- **Quick Match:** an instant best-of-1 against a random club whose team rating is within 5 points of yours. Same rules; uses a calendar day.
- Both can be played in Full or Quick mode.
- **Exclusions:** Exhibition and Quick Match results do not count toward sponsor objectives, tutorial goals (unless a goal names them), the career log, kills/deaths/assists season totals or any award, so winning easy practice games earns nothing. Their seeds come from the stream `exh:<save id>:<n>`, independent of any league match, so an Exhibition says nothing about a later league game's luck. Quick Match falls back to the club nearest in team rating when none is within 5 points. **Team Rating** (used here and in section 9) is the mean `BaseRating` of the five starters in their assigned slots, with no form, fatigue or hero terms.

---

## 8. Match simulation (the core model)

The simulator is **deterministic given a seed**, fast, and produces a readable report. It reasons in three phases made of named contests. The reference implementation is `tools/sim_core.py` (PCG32); `tools/proto_sim.py` is the older prototype kept for history.

### 8.1 Inputs

Per team: five ratings per phase (section 4.4), average CON, `TeamMod` (section 7.7), `CompMod` and style (section 5.3), lane matchup bonuses, and the three Game Plan hooks `contest_mod`, `contest_var` and `variance_mult` (section 7.8; all default to no change), plus a Blue-side advantage. This input interface is frozen for Phase 1 (see `tools/sim_core.py`); the golden vectors cover it.

A slot's effective rating is `Rating * (1 + TeamMod)`. Lane contests also multiply by `(1 + lane bonus)`.

### 8.2 The contest function

```
noise_scale(avgCON)  = 1.4 - 0.8*(avgCON/100)             (1.4 at 0, 1.0 at 50, 0.6 at 100)
sigma_eff            = sqrt((sigma_A^2 + sigma_B^2)/2),  sigma_X = sigma * noise_scale(avgCON_X)
contest(a, b, carry) = tanh( (a - b)/D + gamma*carry + Normal(0, sigma_eff) )
```

The result is in (-1, +1); positive favors Team A (Blue). `carry` is the lead carried from earlier phases. **v0 constants:** `D = 25`, `sigma = 2.0`, `gamma = 0.8`, side bonus `0.02` (applied as carry to each early contest). Higher team consistency shrinks the noise of the whole match, so it helps whichever team is the favourite: CON is a *reliability* stat (performing to your level), not a plain strength stat. A high-CON underdog makes the match more predictable and so slightly lowers its own chances; contract valuation must treat CON accordingly (D-007).

### 8.3 Phases

**Early game (first 35% of the match):** four contests.

| Contest | Compares |
|---|---|
| Top lane | Top vs Top (with lane bonus) |
| Mid lane | Mid vs Mid (with lane bonus) |
| Bot lane | Average of Bot Carry and Support vs the opposing pair |
| Jungle | Jungle vs Jungle (with lane bonus) |

`A_early = 0.28*(top + mid + bot) + 0.16*jungle`

**Mid game (35% to 70% of the match):** two contests with different inputs, carrying `A_early` forward.

```
Objective rating = sum(OBJ_W[slot]  * rating) * (1 + CompMod)
Teamfight rating = sum(FIGHT_W[slot]* rating) * (1 + CompMod + StyleEdge)   (StyleEdge: +4% for the winning style, -4% for the losing style, section 5.3; teamfights only)
OBJ_W   = Jungle 0.30, Support 0.25, Mid 0.15, Top 0.15, Bot 0.15
FIGHT_W = Bot 0.25, Mid 0.25, Top 0.20, Jungle 0.15, Support 0.15
A_mid = 0.35*objectives + 0.65*teamfights
```

**Late game (last 30%):** the same two contests with late ratings, carrying `0.5*A_early + 0.5*A_mid`.

`A_late = 0.25*objectives + 0.75*teamfights`

**Winner:** `Final = 0.30*A_early + 0.30*A_mid + 0.40*A_late`. Team A wins if `Final > 0`. Early and mid results count directly, not only through carry-over, so early leads and early-power heroes matter.

### 8.4 Randomness and determinism

- RNG: **PCG32** (XSH-RR), floats from the top 24 bits, Box-Muller normal draws that consume exactly two uniform draws and cache no spare. (Done in P-002: the reference simulator `tools/sim_core.py` uses PCG32 and the section 9 calibration was re-run, see the PCG32 table in section 9. Constants live in `game/data/sim_params.json`; golden vectors are `game/tests/golden/sim_vectors.json`, reproduced by the Godot module.) Match seed = hash(save seed, match id), fixed when the match is generated, before the draft.
- Each contest draws from its own named substream: `Pcg32(splitmix64(match_seed ^ fnv1a64(contest id)), fnv1a64(contest id))`, so replaying a match with a changed input uses the same noise (exact counterfactuals). Reserved stream-name prefixes: `contest ids` (`top`, `mid_lane`, `bot`, `jungle`, `obj_mid`, `fight_mid`, `obj_late`, `fight_late`), `length`, `draft:<match id>:<pick number>` (AI draft noise), `resim:<match id>:<k>:<contest>` (report re-simulations), `sched:<split id>[:tiebreak]`, `gen:<save id>:<entity>`, `scout:<player id>`, `exh:<save id>:<n>`. Ties in any AI choice (draft scores, lineups, standings) break by ascending id.
- **Outcome seed:** the live league match is simulated with `outcome_seed = splitmix64(match_seed ^ fnv1a64(canonical text of both drafts and both Game Plans))`, so changing the draft or plan after a reload re-rolls the luck, while reloading with nothing changed gives the same result. Reports re-simulate with that stored outcome seed, which keeps counterfactuals exact. This blocks "reload and keep every close loss's noise" but not trying many plans (each try is a fresh draw), which stays an accepted offline risk.
- Floating point: Python and Godot use the same libm families but can differ in the last bit of `log`, `cos` and `tanh`; the golden vectors compare with a tolerance of 1e-9 and a winner flip needs `|Final| < 1e-9`, which is treated as a Red win.
- Engineering produces golden test vectors (inputs, seed, outputs) from the reference implementation (`tools/gen_golden_sim.py`); the Godot module must reproduce them.
- Offline single player accepts save-reload redrafting as a known risk; competitive modes use a single autosave.

### 8.5 Match report and attribution

- **What the report may say.** Lines about who won which contest come from the *signed contest results* of that match, never from the ratings, so a line can never contradict the outcome. With realistic noise the winner loses both late contests in about 4 to 5 percent of matches and wins 3 or fewer of 8 contests in about 5 to 8 percent; those matches get a "snowball" or "comeback" wording rather than a clean one.
- **Attribution by counterfactual.** The contribution of slot `s` is `Final(actual) - Final(with team A's slot-s rating set equal to team B's in every phase, same outcome seed)`; the same method gives the draft edge, the Game Plan edge and the Bond edge (with and without each). **Luck** is `Final(all rating gaps set to zero, same seed)`: the result the same noise would give two equal teams (shown as "variance"). Shares are normalised to the absolute sum, so they always add to 100 percent even though the model is not linear (tanh saturation, carry-over and the bot-lane average prevent exact additivity). Because the match is calibrated so a +10 favourite wins about 68 percent of games, Luck legitimately is the largest single item in most reports; the report says so plainly instead of hiding it.
- **Draft edge** is also reported as a win-probability swing: re-simulate about 200 times with and without the draft bonuses (streams `resim:...`) and show the difference, or a simple "the draft flipped this result" flag.
- Example lines: "Red won Mid lane by a large margin", "Blue's Gunner scaled and won the late fight", "Draft edge: Dive beat Siege".
- Timeline times are fractions of the match length `L`: four lane/jungle results 0.25L, early objective 0.45L, mid fight 0.60L, late objective 0.80L, late fight 0.95L, base siege 1.0L.
- Match length (cosmetic game clock, never an input to the result): `L = clamp(11 + 6*(1 - mean(|A_mid|, |A_late|)) + Normal(0, 1) from stream length, 9, 16)` game minutes, the pace of a mobile MOBA. (v1.5 had 22 to 42; the Founder ruled that too long, section 8.7.) The feed plays the game clock at about 8x, so the playback is roughly 1 to 2 minutes.

### 8.6 After the match

Form moves toward the result (+/-2), morale +/-5 to 10 based on result and playing time, fatigue +15 for players who played, familiarity of picked heroes +3, Bond +4 for each pair of starters who played together (section 7.7), and the Form Rating updates for league and playoff matches (section 10.1); Exhibition and Quick Match change none of these except fatigue and Bond (section 7.9). All values are clamped to the ranges in section 4.2.

### 8.7 Match formats and pacing (Founder decision, 2026-11-07)

**Rule:** one game must never take more than about 5 minutes of the player's time, draft included, or players will quit. Quick mode (auto-draft, instant result) is always available and takes under a minute.

**Formats.**

| Format | Where | Rule |
|---|---|---|
| **Sudden death** (single game) | Casual match, Quick Match, Exhibition best of 1, Single Player league matches, later public and bot matchmaking | One game, no draw: the first team to destroy the enemy base wins. The simulator already ends every game this way (the final siege decides the winner), so nothing in the simulator changes. |
| **Series** | Tournaments, playoffs, finals, Exhibition best of 3 or 5 | Best of 3, with best of 5 for finals. Each game is its own sudden-death game with its own draft and seed (section 7.1). |

**Draft profiles** (a timeout auto-picks the recommended hero; the AI side decides instantly):

| Profile | Used for | Bans and picks per side | Timer per human decision | Longest human time |
|---|---|---|---|---|
| **Short** | Casual, Quick Match, Exhibition, league matches, games 2 and later of a series | 1 ban, 5 picks (order: Blue ban, Red ban, then the pick order of section 6 phases 1 and 2) | 10 s | 60 s |
| **Full** | Game 1 of a tournament or playoff series | 3 bans, 5 picks (section 6) | 15 s | 120 s |

**Time budget per game** (Full mode, worst case; most games are quicker):

| Part | Casual and league | Tournament game |
|---|---|---|
| Draft | at most 60 s | at most 120 s |
| Game Plan check (optional, section 7.8) | skippable | at most 20 s |
| Event feed (game clock about 8x) | at most 120 s, with 2x speed and Skip | at most 120 s, same controls |
| Result and report | skippable | skippable |
| **Total** | **about 3 minutes** | **about 4.5 minutes** |

A best-of-3 series is therefore about 8 to 12 minutes and a best-of-5 final about 15 to 20 minutes, or seconds in Quick mode. Players can always choose to sim a series instead of watching.

**Consequences to check.** (1) The short draft removes two bans, so 9.1 must be re-run with the short profile; the effect on the draft lever is expected to be small. (2) The playback target for the presentation phase is about 7 to 8 seconds of feed per game minute (the 8x clock), so a 16-minute game plays in 2 minutes. (3) Multiplayer edition (public matching): human timers apply to both drafters, and what happens when no opponent is found (a bot opponent after a short wait is the plan) is decided in that edition's design.

---

## 9. Balance targets (QA acceptance criteria)

Measured on 40,000 simulated matches, equal CON of 50 unless stated. Tolerance is **plus or minus 2.0 points** for absolute win rates (standard error about 0.25). **Lever tests (CompMod, style, lane counters, Game Plan controls) are measured as paired differences:** the same match seeds with and without the lever, which cancels most sampling noise, and must land within the stated range plus or minus 0.5 points (lane counter +5 percent in all lanes: 1.5 to 2.5 points; Dive vs Siege: 3.5 to 5.5; CompMod +10 percent: 6 to 9; CompMod +5 percent: 3 to 5). A lever that does nothing therefore fails. The Blue 50 to 52 percent target cannot be verified to better than 0.5 points at this sample size. Calibration must also be repeated at **Phase 1 rating scale (about 45, not the prototype's 60)**, because CompMod +10 percent gives 55.8 percent there against 57.4 at 60, and clubs differ by up to 32 rating points best to worst. **Honest note:** the targets in the first table come from the design intent (a +10 team should win about 7 in 10); the "other check" ranges were set after seeing the prototype and are sanity bands, not independent evidence. The prototype takes finished ratings as input, so these numbers test the contest model, not HeroFactor, fit, chemistry or the draft pipeline.

| Rating advantage (all five slots) | Target win rate | Prototype v0.2 |
|---|---|---|
| 0 | 50% (Blue 50 to 52%) | 50.4% |
| +5 | 60% | 59.5% |
| +10 | 70% | 68.3% |
| +20 | 84% | 82.7% |
| +30 | 93% | 91.9% |

| Other check | Target | Prototype v0.2 |
|---|---|---|
| +10 advantage with avg CON 20 / 50 / 80 | rises with CON; about 64 to 66 / 67 to 70 / 72 to 76% | 64.6 / 68.3 / 74.0% |
| Late-heavy heroes (power 38/50/62) vs early-heavy (62/50/38), equal skill | 50% plus or minus 5 | 50.3% |
| +10 rating advantage in one phase only | 55 to 58% each phase, none below 55% | early 57.0, mid 55.6, late 57.0% |
| CompMod +10% (the cap) vs none, equal players | about +6 to +9 points | 57.4% |
| CompMod +5% vs none | about +3 to +5 points | 54.0% |
| Dive vs Siege (winner +4%, loser -4%), equal players | about +3 to +6 points | 54.6% |
| Lane counter bonus +5% in all three lanes | about +2 points | 52.1% |
| Comeback rate (team behind after early game, |A_early| of 0.2 or more, wins) | 25 to 40% | 27.8% |

**PCG32 re-run (P-002, `tools/calibrate.py`, 40,000 matches per row, seeds fixed):** all rows are inside their bands, so no constant changed. Win rate: +0 50.4%, +5 59.7%, +10 **67.8%**, +20 82.5%, +30 92.1%. CON 20/50/80 at +10: 64.8 / 68.2 / 74.0%. Late-heavy vs early-heavy 49.8%. One-phase +10: early 57.1, mid 55.5, late 56.9%. CompMod +10% 57.2%, +5% 53.9%. Dive vs Siege 54.4%. Lane counter 52.0%. Comeback 28.1%. Bands are the numbers above plus a sampling tolerance of two standard errors (0.25 points at this sample size). **Watch item:** +10 sits 0.2 points under its 68% lower edge and passes only through that tolerance; the +20 and +30 rows are also on the low side. If the full-pipeline test (9.1) shows the favourite underperforming, nudge `D` down slightly (for example 24) rather than adding new terms.

### 9.1 Full-pipeline calibration (required before Pillar 1 is locked; runs after the content data exists)

The tests above change one lever at a time. Before locking Pillar 1, QA runs a full-pipeline test with the real 40 heroes, generated player pools, AI lineups and drafted teams, and reports: how often the draft changes the winner; win rate of a team that drafts best-for-composition versus best-for-familiarity; Blue versus Red win rate with the draft AI in the loop (Red picks last, so the side bonus may need to rise); and the effect of consistency (a weak team at CON 20 against a favourite at CON 80). If familiarity beats every draft lever, HeroFactor is reduced further or MetaMod and CompMod are widened. It is run once more after Team Bonds and Game Plan are implemented (they add TeamMod and plan hooks but not new simulator inputs, so the golden vectors stay valid).

**9.1 results (P-003, 2026-11-07, full text in `docs/design/CALIBRATION-9.1.md`, reproduce with `tools/pipeline_report.py 1800`).** With the v0 constants familiarity dominated: familiarity-heavy drafting beat composition-heavy by 3 to 6 points, the default AI draft only tied it, and a value-maximising probe beat the default by 0.0. After the sweep the adopted constants are: HeroFactor familiarity weight 0.06 (was 0.10), synergy +4%, missing need -5%, damage imbalance -6%, CompMod cap 15%, lane counter +10%. Results now (3,600 side-swapped matches each): composition-heavy vs familiarity-heavy 49.5%, default vs familiarity-heavy 51.8%, default vs composition-heavy 52.1%; the expert probe beats familiarity-heavy by about 5 points. A +10 rating gap wins 71.4% (target 70), +20 wins 86.2% (target 84): HeroFactor, fit and noise cost the favourite almost nothing, so D stays at 25. Mirror matches: Blue 50.1% over 3,600 (50.8% over 4,000 in a separate check), inside the 50 to 52% target, so the side bonus stays at 0.02; the 48% readings from 900-match runs were sampling noise. The draft flips the winner in about 3% of matches, consistent with a draft worth about 3 win-rate points. CON has almost no effect on a +30 favourite (83.8 / 82.8%), which is expected at that gap; its effect between close teams belongs to the paired lever tests. **Still open under 9.1:** paired common-random-number lever tests, calibration at the Phase 1 rating scale (about 45), the joint Game Plan test, and a rerun after Team Bonds and Game Plan are implemented.

Additional targets for the full game: no hero outside agreed pick/win bands at equal skill; no comp style beats the others by more than about 5 points in the league average; no training or fatigue schedule is strictly dominant.


### 9.2 Additional QA tests (v1.3)

1. **No dominant Game Plan:** (a) for each control, sweep it with the others neutral using paired seeds, pick the best setting on one seed set and measure it on a separate held-out seed set (this removes the best-of-200 selection bias); no control gains more than 1.0 point. (b) Joint test: coordinate ascent over all eight controls from neutral against each AI club, measured on held-out seeds; no plan beats neutral by more than 3.0 points. (c) The best plan differs between at least 30 percent of (roster, opponent) pairs, by a difference larger than noise (section 7.8).
2. **Bond farming:** because gains shrink with `(100 - Bond)/70`, the fastest legal way to raise Bond (scrims, Exhibition, playing together) must not beat normal play by more than 20 percent over a split; Exhibition fatigue, no-rest-day and the calendar-day cost must make spamming it a bad plan.
3. **Chemistry curve:** Bond 60 and COM 60 gives a ChemBonus of 1.7 to 2.0 percent (it is 1.92); replacing one starter costs about 0.5 percent; a roster with no shared language gets the 0.65 factor (unit test with a synthetic multi-language roster).
4. **Economy (Phase 1):** simulate 20 default-play splits of the weekly ledger with a fixed roster: the default club never trips the 4-weeks-negative dismissal, never ends a split with more than 20 splits' worth of wages in cash (no snowball), and each of the 3 sponsor offers is viable. *The 10-season version needs an off-season, aging, regen and AI contracts and moves to the seasons phase.*
5. **Form Rating:** with all clubs starting at 1500 and K = 24, the rating after one 18-match split has a mean Spearman correlation of at least 0.75 with true club strength over 3,000 simulated leagues (the ideal logistic model reaches about 0.85); an upset moves the ratings more than an expected win; exhibitions never move it; a series result moves it once (section 10.1).
6. **Derived statistics:** per-player kills, deaths and assists add up to the team totals and never contradict the result (display only, never fed back).
7. **Personality:** no personality is strictly best in a multi-split simulation (moves to the seasons phase together with item 4's 10-season version).
8. **Per-stat Potential:** generated players satisfy `stat <= Potential_stat` for all 8 stats; scouting ranges always contain the true values and the offset never changes between reports.
9. **Game Plan zero-sum:** every control's final-weighted `contest_mod` sum is within 0.0005 of zero (section 7.8).
10. **Determinism:** the Godot module reproduces the golden vectors (RNG and simulator) to 1e-9 (already enforced by `tools/run_all_checks.sh`).

---

## 10. League structure

| Item | v1 |
|---|---|
| Tiers | 4 |
| Teams per tier | 10 (the player's club plus 9 AI clubs in the prototype) |
| Regular season | Double round robin per split (18 matches) |
| Playoffs | Top 4, best of 3 |
| Promotion and relegation | Bottom 2 relegated, top 2 of the tier below promoted |
| Phase 1 uses | One tier of 10 teams, one split and playoffs |
| Later (Global edition) | Multiple tiers with promotion and relegation, cups, invitationals, qualifier chains, regional leagues on real-world regions (task D-018) |

### 10.1 Form Rating and trophy cabinet

Each club has a **Form Rating**, an Elo-style number shown in the league table and on the club page.

```
Expected(self vs opp) = 1 / (1 + 10^(-(Form_self - Form_opp)/400))
Form_self += K * Importance * (Result - Expected)          (the opponent moves by the opposite amount)
```

`K` = 24 (v0). `Result` is 1 for a win and 0 for a loss, applied **once per series**; for a best of 3 or 5, `Expected` is the series win probability from the per-game `Expected` `p` (`p^2(3-2p)` for best of 3, `p^3(10 - 15p + 6p^2)` for best of 5). `Importance`: league match 1.0, playoff round 1.25, final 1.5, times a series multiplier of 1.0 (best of 1), 1.2 (best of 3) or 1.4 (best of 5). Exhibition and Quick Match have importance 0. Every club starts at 1500 in a new save, plus `13 * (Team Rating - league mean Team Rating)` for clubs that should start the world ranked (the constant 13 per rating point matches the calibration: a +10 rating gap is about 68 percent). The rating is a ranking aid for the player and a tiebreak display; it never feeds the simulator. Quick Match opponents are chosen by Team Rating (section 7.9), not by Form Rating.

**Why Elo:** the first draft measured `Result - Expected` against the simulator's own win probability, which averages zero for every club however strong, so the number was pure luck (its spread over 8 matches is about 1.4 times K). With Expected taken from the clubs' own ratings, a club that wins more than its rating predicts rises, and the rating converges on strength.

The **trophy cabinet** on the club page records prize money earned, titles and medals.

---

## 11. Monetization (deferred, Founder decision)

Not built in v1. Principles to protect: no paid advantage in match outcomes, no random-paid-item mechanics (store policies and local law), clear price display. Safety nets (for example a warning before a contract ends) are never paywalled. Subscriptions sell convenience, customization and support. Details in a separate document after the Founder decision.

---

## 12. Scope of the first prototype (Phase 1)

- Single player, offline.
- One league of 10 teams, 5 slots, **40 original heroes**, about 140 generated players (10 per club plus 40 free agents). **Generation (v0):** each stat is drawn from a normal distribution with mean 50 + 4 * (club strength offset, -4 to +4) and standard deviation 8, clamped to 25 to 90; `Potential_stat = stat + a draw of 0 to 25 per stat (younger players get larger draws)`, at most 99; on top of that a **role tilt** of `30 * (slot weight - 0.2)` is added to the five performance stats of the primary slot (about plus or minus 4.5 points, so a primary Bot Carry really has more MEC and less MAC); personality drawn evenly from the four; languages English at 100; age 17 to 32; every player has a primary role and 40% have a secondary role. **Role guarantee:** every club's roster of 10 has at least one primary player and at least two players able to play (primary or secondary) in each of the five slots, so no club lacks a Support.
- **Content files (v0, generated and reproducible):** `game/data/heroes.json` (40 placeholder heroes, 8 per slot, listed in `docs/design/HERO-SET-v0.md`), `players.json` (140 players), `clubs.json` (10 clubs with strength offsets from -4 to +4, best-to-worst team rating spread about 31 points) and `names/block_list.json`. Tags and damage types were tuned by `tools/tune_tags.py` so that, over all 32,768 one-hero-per-slot lineups, Dive, Siege and Protect are each about 20 percent of lineups, the damage-balance penalty hits about 20 percent, and the +10 percent CompMod cap is rare. All names are placeholders.
- Draft, match simulation with text match report, roster screen, simple training.
- **Added in v1.3:** Game Plan (7.8), Team Bonds with pair grid (7.7), Exhibition and Quick Match (7.9), recruitment and negotiation for free agents (7.2), sponsor lite and the finance ledger (7.6), Form Rating and trophy cabinet (10.1), per-stat Potential and help sheets (4.2), simple per-player kills, deaths and assists in match reports, and a player career log. **Not in Phase 1:** manager level and talents (D-014), transfers between clubs (D-015), multi-tier leagues and cups (D-018), daily missions, subscriptions, the animated map.
- **Build order inside Phase 1:** skeleton and string tables (done), headless simulator with golden tests and a frozen input interface (done, including the Game Plan hooks), **content data (40 heroes, generated players) before** the full-pipeline calibration (9.1), then core screens (roster, draft, match), then Team Bonds, Game Plan, recruitment, finance and the extra modes. Contracts count splits and Phase 1 is one split, so expiry and release are exercised by a forced scenario in the unit tests and by an end-of-split contract screen.
- **Play modes:** Full (player drafts every match) and Quick (auto-draft, skim result for non-key matches).
- Plain placeholder visuals.

**Exit criteria:** the Phase 1 "season" (one split plus playoffs, about 24 player matches) can be played in about 15 minutes in Quick mode, where "key matches" (playoffs and matches against the top 3) still show the draft; the 40,000-match batch tests meet the targets in section 9; a non-developer can understand why they lost a match from the report; the extra QA tests in section 9.2 pass, except items 4 (10-season part) and 7, which move to the seasons phase.

---

## 13. Required before launch (not in v1)

Lose conditions (bankruptcy, being fired), onboarding and tutorial, save format and cloud save, analytics, accessibility (colour blind modes, text size), difficulty modes, localization, a privacy review for accounts, store policy review.

---

## 14. Risks

| Risk | Mitigation |
|---|---|
| Balance feels random or solved | Batch simulation and the targets in section 9 before UI work |
| Too much content | Data-driven content, 40 heroes to start |
| Scope creep (online, PvP, animation) | Phase gates in `WORKFLOW.md`; Founder gate for any addition |
| Looks like another game | IP Checker review, original names, lawyer review before launch |
| Store policy (monetization, AI art, data) | Policy check before each store step |
| Player data and privacy once accounts exist | Privacy review in the backend phase |

---

## 15. Open questions and parameters still to define

Founder questions are in `company/DECISIONS.md`. Parameters still to define are tracked on the task board: economy and wage caps and contract valuation (D-007), recruitment and contract maths (D-013), the Game Plan v0 mapping and Team Bonds re-tuning (D-009, D-010), Form Rating constants (D-017), per-stat Potential generation and name block list (D-008, D-016), hero data schema samples and 40-hero set (D-005, D-008), player generation rules (D-008), the PCG32 and golden-vector spec (P-002).

---

## 16. Change log

| Date | Change | By |
|---|---|---|
| 2026-11-07 | v1 draft | Game Design Lead, Systems Lead |
| 2026-11-07 | v1.1 after independent review: model rebuilt so early and mid phases count (final score across all phases); objectives and teamfights use different slot weights; draft levers (CompMod up to 10%, style, lane counters) now simulated; slot assignment and hero fit defined; counterfactual draft attribution; determinism spec; constants re-tuned (D 25, sigma 2.0, gamma 0.8); pool raised to 40 with role floors; draft AI reweighted; missing parameters added; exit criteria use Quick mode; IP-sensitive names replaced (Heartstone, Ashen Vale, Ancient Colossus, Champions, mastery) | Game Design Lead, Systems Lead |
| 2026-11-07 | v1.2 after second independent review: style edge defined as +4% winner / -4% loser (matches prototype); CompMod rescaled (synergy +2.5% per pair type, cap +10%, clamp -10% to +10%) with realistic-range numbers; role-floor rule rewritten to prevent dead ends; draft order changed to our own (2+1 bans each); Phase 1 season defined as one split plus playoffs; training, fatigue (threshold 25, +15 per match), form/morale/chemistry rules, AI lineup rule, Phase 1 signing rule and player generation added; early-phase stat per slot; HeroFactor floor 0.90; power budget tied to difficulty; scouting formula fixed; luck line and win-probability draft edge in reports; full-pipeline calibration (9.1) required | Game Design Lead, Systems Lead |
| 2026-11-07 | v1.3: Founder-approved Game Plan (7.8) and Team Bonds (7.7, replaces the single Chemistry number; COM now enters via Understanding; replacement cost per pair); Exhibition and Quick Match (7.9); free-agent recruitment, negotiation, prize share, release and expiry warning (7.2); sponsor lite and ledger (7.6); Potential per stat, personality, languages, country, help sheets (4.2, 7.4); Form Rating and trophy cabinet (10.1); editions and roadmap (section 1); extra QA tests (9.2); Phase 1 scope updated (12) | Game Design Lead, Systems Lead |
| 2026-11-07 | v1.4 after independent QA review of v1.3 (3 critical, 9 serious findings): Form Rating redefined as Elo (the old definition was noise); Game Plan rebuilt on three simulator hooks and zero-sum controls (8 controls, triggers moved to +-0.40, Peel/Engage and Comeback removed); Team Bonds numbers corrected (ChemBonus 1.92 percent at Bond 60 / COM 60, diminishing Bond gains, bonds stored for all roster pairs); fatigue and morale numbers fixed so they actually build; recruitment (asking wage floor and Potential factor, prize weights, coarse refusals and lockout, personality thresholds), bankruptcy dismissal rule, Exhibition exclusions; determinism spec completed (outcome seed, stream names, tolerance); report attribution by counterfactual; standings tiebreaks defined; lever tests paired with tighter bands; economy and personality 10-season tests deferred; build order puts content before 9.1; dead data and minor items fixed | Game Design Lead, Systems Lead |
| 2026-11-07 | v1.5 after the full-pipeline calibration (P-003): draft constants re-tuned so familiarity no longer dominates (HeroFactor familiarity weight 0.06; synergy +4%; needs -5%; damage balance -6%; CompMod cap 15%; lane counter +10%); 9.1 results recorded; hero set re-checked against the new constants | Systems Lead, QA & Balance |
| 2026-11-07 | v1.6 Founder pacing decision: one game at most about 5 minutes including the draft; sudden-death single games for casual, quick, league and public play; best of 3 (finals best of 5) for tournaments; Short and Full draft profiles with timers; cosmetic game clock shortened to 9 to 16 minutes; new section 8.7 | Founder, Game Design Lead |
| 2026-11-08 | v1.7 implementation notes for 7.3 (tick = match day, Coach and Facility fixed at 2, Rest focus, AI rotation rule, ageing timing, playoff ticking); Game Plan QA 9.2.1 passed (see CALIBRATION-9.1 addendum) | Systems Lead, Engineering Lead |
| 2026-11-08 | v1.8 implementation notes for 7.2 and 7.6 (contracts, free-agent market, negotiation, cash ledger, sponsors, wage cap, dismissal); economy QA (see CALIBRATION-9.1 addendum) | Systems Lead, Engineering Lead |
