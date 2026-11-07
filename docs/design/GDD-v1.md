# Game Design Document v1.3

Status: DRAFT v1.3 (v1.2 was revised after two independent reviews; v1.3 folds in the Founder-approved and recommended items from `REFERENCE-ESMO-ADAPTATION.md`; findings and fixes in section 16). **v1.3 has not had an independent review yet**: new sections 7.7 to 7.9, 9.2 and 10.1 are marked for QA and Systems Lead review. Author: Game Design Lead and Systems Lead. Date: 2026-11-07.
Next: Founder review. Engineering may start P-001 (project skeleton) now; P-002 (simulator) starts after the full-pipeline calibration in section 9.1 is scheduled.

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
5. **Short sessions.** In Full mode a match day takes about 3 to 5 minutes. In Quick mode (auto-draft, skim the result) it takes under a minute.

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
| Form | -10 to +10 | Moves with results (section 8.6); each day `Form = Form * 0.9` (mean-reverts to 0) |
| Morale | 0 to 100 | Results and playing time (section 8.6); each day drifts 2 points toward 60; starters who sit 3+ matches lose 3 per match |
| Fatigue | 0 to 100 | See section 7.3 |
| Hero familiarity | 0 to 100 per hero | Starts 0 to 30 for new heroes; grows when played and trained; clamped to 0 to 100 |
| Age | 16 to 35 | Affects growth rate and eventual decline |
| Personality | one of 4 | Professional, Balanced, Casual, Temperamental. Visible on the player card; see the table below |
| Languages | list of (language, fluency 0 to 100) | Feeds Understanding in section 7.7. Phase 1 data: everyone speaks English at 100 |
| Country and region | text, from a fixed list | Display (flag) and later leaderboards. Never changes gameplay by itself |

**Personality (v0 values, tuned in D-013).** No personality is strictly best; each trades one thing for another.

| Personality | Training gain | Morale swing after results | Bond growth | Contract negotiation |
|---|---|---|---|---|
| Professional | x1.05 | x0.8 | x1.0 | Accepts a fair offer quickly |
| Balanced | x1.00 | x1.0 | x1.0 | Standard |
| Casual | x0.90 | x1.0 | x1.1 | Accepts slightly below asking |
| Temperamental | x1.00 | x1.5 | x0.8 | Demands above asking and may walk away after round 2 |

**Help text.** Every stat, plus Morale, Condition and Personality, has a short help sheet with two lines: what it does in a match and what it does outside matches (training, bonds, condition). Stored as translatable strings.

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
HeroFactor  = (0.90 + 0.10*Familiarity/100) * (0.90 + 0.10*min(1, MEC/(15*Difficulty)))
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
| range | Melee, Mid, Long |
| difficulty | 1 to 5 |
| tags | Engage, Poke, Protect, Pick, Splitpush, Frontline, Waveclear, Scaling |
| strong_vs | Up to 3 hero ids this hero counters |

### 5.3 Composition scoring

Each team's picks produce a **CompMod** and a **comp style**. `CompMod = clamp(sum of the terms below, -10%, +10%)`.

- **Needs:** at least one Frontline, at least one Engage or Pick, at least one Waveclear. Each missing need is -3%.
- **Damage balance:** Physical counts 1 physical, Magic 1 magic, Mixed 0.5 of each. If either total is 3.5 or more, -4%.
- **Synergy pairs:** four pair types exist: Engage with Pick, Protect with Scaling, Poke with Waveclear, Frontline with Engage. Each pair type counts **once** if both tags are present on two different heroes. +2.5% each, so the maximum is +10%.
- **Comp style:** Dive score = count of Engage + Pick tags; Siege score = Poke + Waveclear; Protect score = Protect + Scaling. The style is the highest score if it is at least 4 and at least 1 above the second; any tie or lower score gives Skirmish. (Waveclear is required by Needs, so a Siege score of 1 is normal and does not make a Siege comp.)
- **Style triangle:** Dive beats Siege beats Protect beats Dive. The winning style gets **+4% and the losing style gets -4%** on **teamfight** contests only (an 8% relative swing; this is what the prototype tests). Skirmish is neutral. `StyleEdge` below means this signed +4% or -4%.
- **Lane matchups:** in the Top, Mid and Jungle contests, a hero that is `strong_vs` its opposing hero gives that contest +5%. In the Bot lane, any `strong_vs` link between the two heroes on either side counts, capped at +5% for the lane.

**Realistic draft range (from the prototype, equal players):** a +5% comp beats none 54.0%; +10% beats none 57.4%; +5% beats -5% 57.4%; the best realistic draft (+8% comp, three lane counters, a style win) beats a mildly poor one (-3%) 63.7%.

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

**Rules:** a hero can be picked or banned once per match. Off-role picks are always allowed (at HeroFit 0.85). **Role floor:** after any pick, each slot must still have at least as many available heroes with that primary role as the number of teams that still need that slot; after any ban, at least that number plus 1. A move that would break this is blocked. QA must prove with an exhaustive AI-vs-AI draft test that no draft dead-ends. Timer: 20 seconds per decision in Full mode (no timer in the prototype).

**Player experience:** the draft screen shows each starter's familiarity with every available hero, current MetaMod, and a live preview of CompMod, style, and lane matchups.

**AI drafting (v1):** each pick scores candidates as `familiarity fit * 0.35 + MetaMod * 0.20 + composition need * 0.20 + counter value vs known enemy picks * 0.25`, plus noise that grows as AI difficulty drops. Bans target the opponent's highest `familiarity * MetaMod` heroes, with a 25% chance of banning by MetaMod alone so decoy familiarity does not work reliably.

---

## 7. Management loops

### 7.1 Calendar

Time advances in **days** when the player taps Continue. A **full season** has two splits (9 weeks each, 2 match days per week, 18 league matches per split) plus playoffs per split and a short off-season, so about 42 player matches. Phase 1 plays **one split plus playoffs** (18 league matches plus up to 6 playoff matches) as its "season". Promotion and relegation use split standings. Ranking: points (win 3, loss 0), then head-to-head, then game-time-adjusted score difference, then a seeded draw. Real-time timers are not used offline: a day passes only when the player presses Continue or plays a match, with no waiting, no daily-login missions and no wall-clock events. Contract length is counted in splits and wages are paid and shown per week.

### 7.2 Roster and contracts

- 5 starters, up to 5 substitutes (max 10 players). Substitutes may be swapped in before any match.
- Contracts have a length (in splits), a wage, and optional clauses (release fee, bonus).
- Free agents and other clubs' players can be approached. The AI values an offer on wage versus the player's value, role need, club standing and playing time. Exact valuation is task D-007. **Phase 1 recruitment (free agents only; club-to-club transfers belong to the Multiplayer edition):**
  - **Player database:** the free agents, with filters (role, age, rating range, languages, price) and saved searches.
  - **Reports workflow:** each scouted player has a report that the manager marks Shortlisted or Rejected (New by default).
  - **Negotiation:** up to 3 rounds. The manager proposes wage, length (1 to 4 splits) and prize share (50 to 90 percent to the player). The asking wage is `2 * (BestSlotRating - 40)` per week; the player accepts if the offer is at least his personality's threshold times the asking wage (see Personality table), adjusted slightly by length and prize share. The club must be under its wage cap and have the cash for the signing. Exact acceptance maths is task D-013.
  - **Release and expiry:** releasing a player costs 50 percent of the remaining contract wages (v0). The club always gets a warning before a contract ends (a free safety net, never a paid perk).
  - **Prize share:** when the club wins prize money, the player share goes to the players on the roster for that event in proportion to their contract percentage. A higher share raises willingness to sign and gives a small morale lift after prize wins.
  - **Career log:** signings, departures, birthdays, awards and notable matches are recorded per player.

### 7.3 Training and fatigue

Each player has one **training focus** per week: a stat, a hero's familiarity, or a **team scrim** (builds chemistry).

```
gain = max(0, base * (1 + 0.1*CoachLevel + 0.05*FacilityLevel) * (1 - stat/Potential) * AgeFactor * (1 - Fatigue/200))
```

`base` is 0.5 points per week. `CoachLevel` and `FacilityLevel` are 1 to 5 and add together inside the bracket. Player generation guarantees `stat <= Potential`; if it ever isn't, `gain` is 0. `AgeFactor`: 16 to 20 = 1.3, 21 to 23 = 1.1, 24 to 26 = 0.8, 27 to 29 = 0.5, 30 and over = 0.25. From age 29, MEC declines about 1 point per season, and from age 31 TFT and SEN decline about 0.5 per season (v0).

Fatigue (clamped 0 to 100, reset to 0 at the off-season): +15 per match played, +5 per training week, -6 per rest day. A normal week (2 matches, 5 rest days) nets about +5, so fatigue builds slowly across a split; the penalty in section 4.4 starts at 25, so a heavy load or a dense playoff schedule hurts and rotating substitutes matters. QA checks that no schedule is strictly dominant and that rotation is sometimes right.

Familiarity: +3 per match played with the hero, +1.5 per week of focused training (scaled by coach), -0.5 per week if unused and above 50.

### 7.4 Scouting

Scouts are assigned to a region and role. Each report reveals stats as ranges with half-width `max(3, 16 - 2*ScoutLevel - 2*ReportsSoFar)` points, where `ReportsSoFar` counts reports on that player. The true value is always inside the range, but the range is centred at a random offset of up to half the width, so ranges mislead without being false. Potential is shown as a star range that narrows over time. Hidden gems and overrated players both exist. Because Potential is per stat, a report shows each stat's current range and its ceiling range, so the manager can see where a young player can grow. A player's profile has an **Ability / Potential** toggle.

### 7.5 Staff and facilities

| Staff | Effect |
|---|---|
| Head Coach (level 1 to 5) | Training gain multiplier |
| Analyst (level 1 to 5) | StaffBonus +0.4% per level to team ratings (max +2%); draft preview accuracy |
| Scout (level 1 to 5) | Narrower reports, wider region coverage |

Facilities (levels 1 to 5): each level adds +5% training gain and +1 fatigue recovery per rest day.

### 7.6 Finance

**Phase 1 income:** a sponsor contract (signing bonus plus objective rewards), prize money, and one-time tutorial goal rewards. **Expenses:** player wages, staff wages and facility upkeep. Transfer fees and transfer income arrive with the Multiplayer edition. There is no way to buy in-game money with real money.

- **Sponsor lite:** at the start of a season the manager picks 1 of 3 offers. Each pays a signing bonus and per-split objective rewards (for example reach the playoffs, win a set number of matches, start a rookie). Missing an objective loses that reward only. Daily missions are not part of Single Player.
- **Tutorial goals:** one-time goals ("set a training plan", "make a Game Plan") with a small cash reward, to teach a new player the game.
- **Ledger:** an Overview (balance and a week chart), Analytics (profit and loss over time, income and expense by source) and History (every payment as one line).
- **Rules:** each tier has a wage cap. A balance below zero blocks new signings but does not end the game in Phase 1 (lose conditions come before launch, section 13). Money numbers are task D-007.

### 7.7 Team Bonds (replaces the single Chemistry number)

Chemistry is no longer one hidden number. Each pair of starters has a **Bond** and each direction has an **Understanding**.

- **Bond** (0 to 100, symmetric, 10 pairs): +4 per match the two play together, +3 per team-scrim week, +2 per Exhibition game (section 7.9), all multiplied by the two players' Bond growth factors (Personality table, geometric mean). A new club's bonds start at 30. When a starter is replaced, the new player's bonds with the four others start at 20; the other six pairs keep their values. Minimum 0.
- **Language factor** `Lang(i,j)`: 1.0 if the two share a language with fluency at least 50 for both, else 0.65 (v0).
- **Understanding** (0 to 100, directional, 20 values): `U(i<-j) = Lang(i,j) * Bond(i,j) * (0.5 + COM_j/200)`. Read it as "how well player i takes in what player j says".
- **Team chemistry** `Chem` = the mean of the 20 Understanding values.
- `ChemBonus = 0.035 * Chem/100` (maximum 0.035). `TeamMod = ChemBonus + StaffBonus`, as before.

**Change from v1.2:** COM now enters through Understanding only (the old formula multiplied by `0.5 + avgCOM/100` as well), and a replaced starter now costs the new pairs rather than a flat -25 for everyone. **The numbers are v0 and must be re-tuned so a typical roster (Bond 60, COM 60) gives a bonus of about 1.7 to 2.0 percent, close to the old curve, and the full-pipeline calibration in section 9.1 must be re-run with bonds in the loop.**

**Screens:** a pentagon of the five starters (link thickness for Bond, colour for Understanding), a 5x5 Understanding grid, and a languages list per player. In Phase 1 every player speaks English at 100, so `Lang` is always 1.0 and the grid is a pure display of Bond and COM. The maths is tested with synthetic multi-language rosters in the unit tests, so switching real languages on later needs no rework. Language fluency is a gameplay trait only, never tied to nationality or ethnicity in text or art.

### 7.8 Game Plan (the coach's second lever besides the draft)

A **Game Plan** is a set of 10 sliders, each from -100 to +100 (default 0 = neutral), with an optional **trigger**. The engine uses the first plan whose trigger matches, otherwise the default plan. Phase 1 keeps at least one fully usable Game Plan for free; extra saved plans and triggers are convenience, never extra strength (section 11).

| Slider (-100 / +100) | What it trades in the model (v0; max effect at +-100) |
|---|---|
| Spread out / Group up | Teamfight contest weight in mid and late phases x(1 + 0.15 g); lane and jungle weights x(1 - 0.15 g) |
| Tempo / Scale | Early rating x(1 + 0.03 t) while late rating x(1 - 0.03 t) (t = -1 favours scaling) |
| Early objective priority | `w_mid_obj` x(1 + 0.20 e); lane weights x(1 - 0.10 e); variance of that contest up |
| Late objective priority | `w_late_obj` x(1 + 0.20 l); risk when behind rises |
| Farm safely / Lane aggression | Lane contest differences amplified x(1 + 0.20 a) and contest noise x(1 + 0.25 a); safe side flattens both |
| Jungle focus: Top / Mid / Bot | A fixed jungle bonus added to the chosen lane contest and subtracted from the others (total unchanged) |
| Support stays / Support roams | Bot lane strength down and objective-contest strength up by the same amount |
| Peel / Engage | Teamfight style interaction: moves the team's effective style towards Dive (engage) or Protect (peel) by 0.5 steps |
| Play safe / Take risks | Noise of every contest x(1 + 0.20 r) |
| Comeback focus | When behind after the early phase, late-phase variance up and late rating x(1 + 0.02 c) |

Every slider has a cost, so no setting is free. **Triggers (v0):** `default`; `ahead after early` (`A_early > +0.15`); `behind after early` (`A_early < -0.15`); `against Dive`, `against Siege`, `against Protect` (the opponent's composition style). A trigger on a phase outcome re-applies the plan for the mid and late phases only.

**AI clubs** get plans generated from their roster and composition. **Reports** state which plan setting mattered, using the same win-probability swing method as the draft edge (section 8.5).

**QA requirements (section 9.2):** across the league average no setting beats neutral by more than 1.5 win-rate points, and the best setting differs by roster and opponent. Out of scope in v1: items, spells, per-hero micro positioning, vision.

### 7.9 Exhibition and Quick Match

Two offline modes for practice. They never change the league table, the Form Rating (section 10.1), Form or Morale.

- **Exhibition:** pick any club in your league and play best of 1, 3 or 5. Each series uses up one calendar day (so it competes with training and rest). Fatigue +5 per game (instead of +15), Bond +2 per game for the starters (section 7.7). Intended for testing drafts and Game Plans.
- **Quick Match:** an instant best-of-1 against a random club whose team rating is within 5 points of yours. Same rules; uses a calendar day.
- Both can be played in Full or Quick mode.

---

## 8. Match simulation (the core model)

The simulator is **deterministic given a seed**, fast, and produces a readable report. It reasons in three phases made of named contests. The reference implementation for calibration is `tools/proto_sim.py`.

### 8.1 Inputs

Per team: five ratings per phase (section 4.4), average CON, `TeamMod` (section 7.7), `CompMod` and style (section 5.3), lane matchup bonuses, and a Blue-side advantage.

A slot's effective rating is `Rating * (1 + TeamMod)`. Lane contests also multiply by `(1 + lane bonus)`.

### 8.2 The contest function

```
noise_scale(avgCON)  = 1.4 - 0.8*(avgCON/100)             (1.4 at 0, 1.0 at 50, 0.6 at 100)
sigma_eff            = sqrt((sigma_A^2 + sigma_B^2)/2),  sigma_X = sigma * noise_scale(avgCON_X)
contest(a, b, carry) = tanh( (a - b)/D + gamma*carry + Normal(0, sigma_eff) )
```

The result is in (-1, +1); positive favors Team A (Blue). `carry` is the lead carried from earlier phases. **v0 constants:** `D = 25`, `sigma = 2.0`, `gamma = 0.8`, side bonus `0.02` (applied as carry to each early contest). Higher team consistency makes the favorite more reliable; this is a design feature, not a bug.

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

- RNG: **PCG32** with Box-Muller for normal draws. (The prototype uses Python's own generator, so P-002 must re-run the section 9 calibration after the switch and store the numbers beside the golden vectors.) Match seed = hash(save seed, match id), fixed when the match is generated, before the draft.
- Each contest draws from its own named substream (`seed + contest id`), so replaying a match with a changed input uses the same noise. This allows exact counterfactuals for reports.
- Engineering produces golden test vectors (inputs, seed, outputs) from the reference implementation in task P-002; the Godot module must reproduce them.
- Offline single player accepts save-reload redrafting as a known risk; competitive modes use a single autosave.

### 8.5 Match report and attribution

- **Contribution** of slot `s` to contest `c` = `phase weight * contest weight * slot weight * (rating_A,s - rating_B,s) / D` (signed). The report ranks the largest absolute contributions, and the MVP is the player with the highest total on the winning team.
- **Luck line:** every report also shows the noise term, so a win that came from luck is labelled as such. Contributions are shown as signed shares of the rating gap, and a "Luck" share is added so shares sum to the result.
- **Draft edge** is reported as a win-probability swing: re-simulate the match about 200 times with and without the draft bonuses (same seeds) and show the difference, or a simple "the draft flipped this result" flag.
- Example lines: "Red won Mid lane by a large margin", "Blue's Gunner scaled and won the Moonhulk fight", "Draft edge: Dive beat Siege".
- Timeline times are fractions of the match length `L`: lane results 0.25L, first Stoneback 0.40L, mid fights 0.60L, Moonhulk 0.80L, base siege 1.0L.
- Match length: `L = clamp(26 + 12*(1 - mean(|A_mid|, |A_late|)) + Normal(0, 2), 22, 48)` minutes.

### 8.6 After the match

Form moves toward the result (+/-2), morale +/-5 to 10 based on result and playing time, fatigue +15 for players who played, familiarity of picked heroes +3, Bond +4 for each pair of starters who played together (section 7.7), and the Form Rating updates for league and playoff matches (section 10.1); Exhibition and Quick Match change none of these except fatigue and Bond (section 7.9). All values are clamped to the ranges in section 4.2.

---

## 9. Balance targets (QA acceptance criteria)

Measured on 40,000 simulated matches, equal CON of 50 unless stated. Tolerance is **plus or minus 2.0 points** for win rates (standard error about 0.25); the QA regression gate tightens to plus or minus 1.0 once the real engine exists. **Honest note:** the targets in the first table come from the design intent (a +10 team should win about 7 in 10); the "other check" ranges were set after seeing the prototype and are sanity bands, not independent evidence. The prototype takes finished ratings as input, so these numbers test the contest model, not HeroFactor, fit, chemistry or the draft pipeline.

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

### 9.1 Full-pipeline calibration (required before P-002 is closed)

The tests above change one lever at a time. Before locking Pillar 1, QA runs a full-pipeline test with the real 40 heroes, generated player pools, AI lineups and drafted teams, and reports: how often the draft changes the winner; win rate of a team that drafts best-for-composition versus best-for-familiarity; Blue versus Red win rate with the draft AI in the loop (Red picks last, so the side bonus may need to rise); and the effect of consistency (a weak team at CON 20 against a favourite at CON 80). If familiarity beats every draft lever, HeroFactor is reduced further or MetaMod and CompMod are widened.

Additional targets for the full game: no hero outside agreed pick/win bands at equal skill; no comp style beats the others by more than about 5 points in the league average; no training or fatigue schedule is strictly dominant.


### 9.2 Additional QA tests (v1.3)

1. **No dominant Game Plan:** for each slider, sweep it with other sliders neutral across the league average; no setting beats neutral by more than 1.5 points, and the best setting differs by roster and opponent (section 7.8).
2. **Bond farming:** the fastest way to raise Bond (scrims, Exhibition, playing together) must not beat normal play by more than a small margin; Exhibition fatigue and the calendar-day cost must make spamming it a bad plan.
3. **Chemistry curve:** a typical roster (Bond 60, COM 60) lands at about 1.7 to 2.0 percent ChemBonus; replacing one starter costs less than the old flat -25 on average; a roster with no shared language gets the 0.65 factor.
4. **Economy:** simulate 10 seasons for a default club under default play. It must not go bankrupt and must not snowball; sponsor choices must each be viable.
5. **Form Rating:** after one split the rating ranks clubs close to their true strength; an upset moves it more than an expected win; exhibitions never move it.
6. **Derived statistics:** per-player kills, deaths and assists add up to the team totals and never contradict the result (display only, never fed back).
7. **Personality:** no personality is strictly best in the 10-season simulation.
8. **Per-stat Potential:** generated players satisfy `stat <= Potential_stat` for all 8 stats; scouting ranges always contain the true values.

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

Each club has a **Form Rating** that shows how it has played lately. It is shown in the league table and on the club page.

```
Form = sum over matches in the last 28 game days of K * Importance * (Result - Expected) * Fade
Fade = max(0, 1 - age_days / 28)
```

`Result` is 1 for a win and 0 for a loss. `Expected` is the simulator's own win probability for the two teams' ratings (so it matches the calibration table). `Importance`: league match 1.0, playoff round 1.25, final 1.5, times a series multiplier of 1.0 (best of 1), 1.2 (best of 3) or 1.4 (best of 5). Exhibition and Quick Match have importance 0. New clubs start at 0 and can go below 0. `K` is set so a normal league season spreads ratings from about -100 to +100 (v0). Quick Match opponents are chosen by team rating, not by Form.

The **trophy cabinet** on the club page records prize money earned, titles and medals.

---

## 11. Monetization (deferred, Founder decision)

Not built in v1. Principles to protect: no paid advantage in match outcomes, no random-paid-item mechanics (store policies and local law), clear price display. Safety nets (for example a warning before a contract ends) are never paywalled. Subscriptions sell convenience, customization and support. Details in a separate document after the Founder decision.

---

## 12. Scope of the first prototype (Phase 1)

- Single player, offline.
- One league of 10 teams, 5 slots, **40 original heroes**, about 140 generated players (10 per club plus 40 free agents). **Generation (v0):** each stat is drawn from a normal distribution with mean 50 + 4 * (club strength offset, -4 to +4) and standard deviation 8, clamped to 25 to 90; `Potential_stat = stat + a draw of 0 to 25 per stat (younger players get larger draws)`, at most 99; personality drawn evenly from the four; languages English at 100; age 17 to 32; every player has a primary role and 40% have a secondary role.
- Draft, match simulation with text match report, roster screen, simple training.
- **Added in v1.3:** Game Plan (7.8), Team Bonds with pair grid (7.7), Exhibition and Quick Match (7.9), recruitment and negotiation for free agents (7.2), sponsor lite and the finance ledger (7.6), Form Rating and trophy cabinet (10.1), per-stat Potential and help sheets (4.2), simple per-player kills, deaths and assists in match reports, and a player career log. **Not in Phase 1:** manager level and talents (D-014), transfers between clubs (D-015), multi-tier leagues and cups (D-018), daily missions, subscriptions, the animated map.
- **Build order inside Phase 1:** skeleton and string tables, headless simulator with golden tests, full-pipeline calibration (9.1), content data, core screens (roster, draft, match), then Team Bonds, Game Plan, recruitment, finance and the extra modes.
- **Play modes:** Full (player drafts every match) and Quick (auto-draft, skim result for non-key matches).
- Plain placeholder visuals.

**Exit criteria:** the Phase 1 "season" (one split plus playoffs, about 24 player matches) can be played in about 15 minutes in Quick mode, where "key matches" (playoffs and matches against the top 3) still show the draft; the 40,000-match batch tests meet the targets in section 9; a non-developer can understand why they lost a match from the report; the extra QA tests in section 9.2 pass.

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
| 2026-11-07 | v1.3 (not yet independently reviewed): Founder-approved Game Plan (7.8) and Team Bonds (7.7, replaces the single Chemistry number; COM now enters via Understanding; replacement cost per pair); Exhibition and Quick Match (7.9); free-agent recruitment, negotiation, prize share, release and expiry warning (7.2); sponsor lite and ledger (7.6); Potential per stat, personality, languages, country, help sheets (4.2, 7.4); Form Rating and trophy cabinet (10.1); editions and roadmap (section 1); extra QA tests (9.2); Phase 1 scope updated (12) | Game Design Lead, Systems Lead |
