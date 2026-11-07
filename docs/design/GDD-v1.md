# Game Design Document v1

Status: DRAFT for review. Author: Game Design Lead and Systems Lead. Date: 2026-11-07.
Reviewers: Systems Lead, IP Checker, then Founder.

All numbers in this document are **v0 placeholders** unless marked otherwise. They exist so the rules can be tested. QA & Balance tunes them against the targets in section 9.

---

## 1. Vision

A mobile esports **manager** game, MOBA only. The player is the club owner and head coach. They scout and sign players, train them, build a roster, and win matches through preparation and draft decisions. Matches are simulated; the player never controls a hero.

**One-line pitch:** Build a team from unknown talents into a world champion by out-thinking rivals in the draft.

### Pillars

1. **The draft is the game.** Pick and ban decisions should matter more than any other single choice, and no draft should be "solved".
2. **Every player is a person.** Players have strengths, weaknesses, form, morale and growth. Losing a star hurts.
3. **Results are readable.** After every match the player can see why they won or lost, and what to change.
4. **Fair progression.** Skill and planning beat spending. (Monetization stance is a Founder decision; see `DECISIONS.md`.)
5. **Short sessions.** A match day takes about 3 to 5 minutes. A full action loop fits a commute.

### Non-goals for v1

Direct hero control, real-time multiplayer matches, a 3D map, voice chat, esports betting, real-money trading of players.

---

## 2. The match world (genre conventions, original names)

Genre conventions we use freely: three lanes, a jungle, waves of minions, towers, neutral objectives, gold and experience, items, an enemy base to destroy, five players per team.

Original names (all **placeholders pending IP Checker review**):

| Concept | Placeholder name |
|---|---|
| The map | Ashen Vale |
| The base core | Heartstone |
| Lane minions | Waves |
| Early neutral objective (gold and speed buff) | Stoneback |
| Late neutral objective (decisive team buff) | Ancient Colossus |
| Jungle camps | Moss camps |
| Lanes | Top, Mid, Bot |
| Heroes | Champions (generic genre term; may be renamed) |

The map is an abstraction in v1: the simulator reasons about lanes, the jungle and objectives, not coordinates. A minimap view is a presentation layer added later.

---

## 3. Roles

Five roles per team. Each player has one **primary** role and may have one **secondary** role.

| Role | Lane | Job in the sim |
|---|---|---|
| Top | Top | Frontline or duelist, strong laning, teleport-style map pressure |
| Jungle | Jungle | Tempo, objectives, ganks, early lane influence |
| Mid | Mid | Burst or control damage, roams, wave control |
| Bot Carry | Bot (with Support) | Sustained damage, scales hardest into late game |
| Support | Bot (with Carry) | Vision, protection, engage or peel, objective setup |

Playing a champion outside the player's primary or secondary role applies a **role-fit multiplier**: primary 1.00, secondary 0.93, unfamiliar 0.80.

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
| CON (Consistency) | Reduces randomness in the player's results |
| CLU (Clutch) | Performance in late, high-pressure fights |

### 4.2 Hidden and dynamic values

| Value | Range | Notes |
|---|---|---|
| Potential | 1 to 100 | Soft cap for each stat's growth; revealed only through scouting and time |
| Form | -10 to +10 | Moves with recent results; mean-reverts to 0 |
| Morale | 0 to 100 | Affected by results, playing time, contract, team atmosphere |
| Fatigue | 0 to 100 | Rises with matches and training; falls with rest |
| Champion mastery | 0 to 100 per champion | Grows when played and trained |
| Age | 16 to 35 | Affects growth rate and eventual decline |

### 4.3 Role weights

Each role converts the five performance stats into a **base rating** using these weights (rows sum to 1.00).

| Role | MEC | SEN | LAN | TFT | MAC |
|---|---|---|---|---|---|
| Top | 0.25 | 0.15 | 0.30 | 0.20 | 0.10 |
| Jungle | 0.15 | 0.25 | 0.05 | 0.20 | 0.35 |
| Mid | 0.30 | 0.20 | 0.25 | 0.15 | 0.10 |
| Bot Carry | 0.35 | 0.10 | 0.25 | 0.25 | 0.05 |
| Support | 0.10 | 0.30 | 0.10 | 0.20 | 0.30 |

`BaseRating = sum(weight[stat] * stat)`

### 4.4 Match rating

For each match, each player's **match rating** per phase is:

```
Cond       = Form*0.4 + (Morale-50)*0.06 - 0.15*max(0, Fatigue-40)     (points)
Champ      = 0.85 + 0.15*(Mastery/100)                                 (0.85 to 1.00)
RoleFit    = 1.00 | 0.93 | 0.80
PhaseBase  = Early: 0.6*BaseRating + 0.4*LAN
             Mid:   BaseRating
             Late:  0.8*BaseRating + 0.2*CLU
Rating(phase) = (PhaseBase + Cond) * Champ * RoleFit
                * (1 + (ChampPower[phase] - 50)/200) * MetaMod
```

`ChampPower[phase]` is the champion's early, mid or late power (section 5). `MetaMod` is the champion's current patch modifier (0.97 to 1.03).

---

## 5. Champions

Champions are **data**: attributes and tags. Names and any visual identity are created by the Content Lead and screened by the IP Checker. Kits (abilities) are summarized as tags in v1; full ability descriptions are not needed for the simulation.

### 5.1 Archetypes (original names)

| Archetype | Typical role | Identity |
|---|---|---|
| Bruiser | Top, Jungle | Durable fighter, wins extended trades |
| Bulwark | Top, Support, Jungle | Tank, engage and frontline |
| Spellcaster | Mid | Magic burst or control |
| Gunner | Bot Carry | Sustained ranged damage, late scaling |
| Shade | Mid, Jungle | Mobile assassin, picks and roams |
| Mender | Support | Heals, shields, protects the carry |
| Binder | Support, Mid | Crowd control and setup |

### 5.2 Attributes

| Attribute | Values |
|---|---|
| Early / Mid / Late power | 38 to 62 each; the three sum to 150 plus or minus 6 (power budget) |
| Damage type | Physical, Magic, Mixed |
| Range | Melee, Mid, Long |
| Difficulty | 1 to 5 (the champion needs MEC of about 15 x difficulty to be played at full mastery effect) |
| Role fit | Primary role(s) and secondary role(s) |
| Tags | Engage, Poke, Protect, Pick, Splitpush, Frontline, Waveclear, Scaling |

### 5.3 Composition scoring

Each team's draft produces a **composition modifier** applied to the team's phase ratings:

- **Needs:** at least one Frontline, at least one Engage or Pick, at least one Waveclear. Each missing need is -1.5%.
- **Damage balance:** 4 or more champions of one damage type is -3%.
- **Comp style:** derived from tags as Dive (Engage and Pick heavy), Siege (Poke and Waveclear heavy), Protect (Protect and Scaling heavy), or Skirmish (mixed). Style triangle for mid and late game: **Dive beats Siege beats Protect beats Dive**, worth +/-3%. Skirmish is neutral.
- **Synergy bonuses:** specific tag pairs, for example Engage with Pick, or Protect with Scaling, grant +1% each, capped at +4%.
- The total composition modifier is capped at +/-6%.

### 5.4 Patches and the meta

The league runs on **patches** (for example every two in-game weeks). Each patch changes MetaMod for a subset of champions by small amounts (0.97 to 1.03), so strong picks rotate. The AI drafts using current MetaMod, so the meta is visible to the player.

---

## 6. Draft

Both teams draft before every match. Blue side picks first.

**Sequence (v1):**

1. Ban phase 1: Blue, Red, Blue, Red, Blue, Red (3 bans each).
2. Pick phase 1: Blue 1, Red 1, Red 2, Blue 2, Blue 3, Red 3.
3. Ban phase 2: Red, Blue, Red, Blue (2 bans each).
4. Pick phase 2: Red 4, Blue 4, Blue 5, Red 5.

Rules: a champion can be picked or banned once per match. Each pick is assigned to one of the team's five starters; role-fit and mastery apply immediately. Timer per decision: 20 seconds in v1 (optional for single player; turn-based without a timer is acceptable in prototype).

**Player experience:** the draft screen shows each starter's mastery with every available champion, current MetaMod, and a live preview of the composition modifier and the comp style triangle.

**AI drafting (v1):** each AI pick scores candidates as `mastery fit * 0.5 + MetaMod * 0.2 + composition need * 0.2 + counter value vs known enemy picks * 0.1`. Bans target the opponent's highest-mastery and highest-MetaMod champions. The AI has a difficulty level that adds noise to its scores.

---

## 7. Management loops

### 7.1 Calendar

Time advances in **days** when the player taps Continue. A season has two splits and a playoff. Each week has up to two match days. Other days are for training, scouting and management. Real-time timers are not used offline.

### 7.2 Roster and contracts

- 5 starters, up to 5 substitutes (max 10 players).
- Contracts have a length (in splits), a wage, and optional clauses (release fee, bonus).
- Players can be offered new contracts, released, or transferred. Free agents and other clubs' players can be approached. The AI evaluates offers on wage, role, club standing and playing time.

### 7.3 Training

Each player has one **training focus** per week: a stat, a champion's mastery, or a **team scrim** (builds chemistry). Gains:

```
gain = base * (1 + 0.1*CoachLevel) * (1 - stat/Potential) * AgeFactor * (1 - Fatigue/200)
```

`base` is about 0.5 points per week. Training raises fatigue; rest days lower it. Young players with high Potential grow fastest; players past about 28 decline slowly in MEC.

### 7.4 Scouting

Scouts are assigned to a region and role. Reports reveal a player's stats as **ranges**; the range narrows with repeated reports and scout level. Potential is shown as a star range that narrows over time. Hidden gems and overrated players both exist.

### 7.5 Staff and facilities

| Staff | Effect |
|---|---|
| Head Coach | Training gain multiplier |
| Analyst | Draft preview accuracy, scrim effectiveness |
| Scout | Narrower reports, wider region coverage |
| Psychologist (later) | Morale recovery |

Facilities (gaming house, training room) have upgrade levels that raise training and recovery rates.

### 7.6 Finance

Income: sponsors (scale with league tier and results), prize money, transfers. Expenses: wages, staff, facilities, transfer fees. Each league tier has a **wage cap**. Running out of money restricts signings.

### 7.7 Chemistry

Team chemistry (0 to 100) rises with matches together and team scrims. It adds up to +3% to team ratings. Changing starters lowers it.

---

## 8. Match simulation (the core model)

The simulator is **deterministic given a seed**, fast, and produces a readable report. It reasons in three phases, each made of named contests. The prototype for calibration is `tools/proto_sim.py`.

### 8.1 Inputs

For each team: the five match ratings per phase (section 4.4), average CON, the composition modifier, chemistry, staff bonus, and a small side advantage for Blue.

**Team phase rating** for a given role slot is the player's rating multiplied by `(1 + CompMod + Chemistry + StaffBonus)`.

### 8.2 The contest function

```
noise_scale(avgCON) = 1.4 - 0.8*(avgCON/100)         (1.4 at 0, 1.0 at 50, 0.6 at 100)
sigma_eff           = sqrt((sigma_A^2 + sigma_B^2)/2) with sigma_X = sigma * noise_scale(avgCON_X)
contest(a, b, carry) = tanh( (a - b)/D + gamma*carry + Normal(0, sigma_eff) )
```

Result is in (-1, +1). Positive favors Team A (Blue). `carry` is the lead carried from earlier phases. Calibrated v0 constants: `D = 20`, `sigma = 1.5`, `gamma = 0.7`.

### 8.3 Phases

**Early game (about 0 to 14 min):** four contests.

| Contest | Compares |
|---|---|
| Top lane | Top vs Top ratings |
| Mid lane | Mid vs Mid ratings |
| Bot lane | Average of Bot Carry and Support vs the opposing pair |
| Jungle | Jungle vs Jungle ratings |

`A_early = 0.28*(top + mid + bot) + 0.16*jungle`

**Mid game (about 15 to 28 min):** two contests, both using the team average mid-game rating and carrying `A_early` forward.

`A_mid = 0.35*objectives + 0.65*teamfights`

**Late game (29 min onward):** the same two contests with late ratings, carrying `0.4*A_early + 0.6*A_mid`.

`A_late = 0.25*objectives + 0.75*teamfights`

**Winner:** Team A wins if `A_late > 0`.

A lead can be carried and also thrown away: because `gamma < 1` and late-game ratings differ (Scaling champions), comebacks happen.

### 8.4 Match report

The report ranks reasons by absolute contribution, for example:

1. "Red won Mid lane by a large margin" (from the Mid contest).
2. "Blue's Gunner scaled and won the Colossus fight" (late contests).
3. "Draft edge: Dive beat Siege" (composition modifier).

It also shows a timeline (lane results about minute 8, first Stoneback about 13, major fights about 20, 27, 34, base siege), an MVP (highest contribution), and the post-match changes to form, morale and fatigue.

Match length: `clamp(26 + 12*(1 - mean(|A_mid|, |A_late|)) + Normal(0, 2), 22, 48)` minutes.

### 8.5 After the match

Form moves toward the result (+/-2), morale +/-5 to 10 based on result and playing time, fatigue +10 to 15 for players who played. Mastery of picked champions rises slightly. Chemistry rises slightly for the starting five.

---

## 9. Balance targets (QA acceptance criteria)

Targets for the stronger team's win rate when all five role ratings differ by the given amount, equal CON of 50, from 40,000 simulated matches. The v0 prototype already achieves these.

| Rating advantage | Target win rate | Prototype v0 |
|---|---|---|
| 0 | 50% (Blue side 50 to 52%) | 50.3% |
| +5 | about 60% | 60.4% |
| +10 | about 70% | 69.7% |
| +20 | about 84% | 84.2% |
| +30 | about 93% | 92.9% |

Consistency check at a +10 advantage: average CON 20 gives about 65%, CON 50 about 70%, CON 80 about 77%.

Additional targets: no champion should win or be picked far outside agreed bands at equal skill; no composition style beats the others by more than about 5 points in the full-league average; comeback rate (team behind after early game wins) between about 25% and 40%.

---

## 10. League structure

| Item | v1 |
|---|---|
| Tiers | 4 |
| Teams per tier | 10 (the player's club plus 9 AI clubs in the prototype) |
| Regular season | Double round robin per split (18 matches) |
| Playoffs | Top 4, best of 3 |
| Promotion and relegation | Bottom 2 relegated, top 2 of the tier below promoted |
| Later | Cups, international events, regional leagues |

---

## 11. Monetization (deferred, Founder decision)

Not built in v1. Principles to protect: no paid advantage in match outcomes, no random-paid-item mechanics (store policies and local law), clear price display. Details in a separate document after the Founder decision.

---

## 12. Scope of the first prototype (Phase 1)

- Single player, offline.
- One league of 10 teams, 5 roles, 30 original champions, about 60 generated players.
- Draft, match simulation with text match report, roster screen, simple training.
- Plain placeholder visuals.

**Exit criteria:** a full season can be played in about 15 minutes of real time; 10,000-match batch tests meet the targets in section 9; a non-developer can understand why they lost a match from the report.

---

## 13. Risks

| Risk | Mitigation |
|---|---|
| Balance feels random or solved | Batch simulation and the targets in section 9 before UI work |
| Too much content | Data-driven content, only 30 champions to start |
| Scope creep (online, PvP, animation) | Phase gates in `WORKFLOW.md`; Founder gate for any addition |
| Looks like another game | IP Checker review, original names, lawyer review before launch |
| Store policy (monetization, AI art, data) | Policy check before each store step |
| Player data and privacy once accounts exist | Privacy review in the backend phase |

---

## 14. Open questions

See `company/DECISIONS.md`: single player vs online first, match presentation, setting, monetization stance, game name, platforms, languages.

---

## 15. Change log

| Date | Change | By |
|---|---|---|
| 2026-11-07 | v1 draft | Game Design Lead, Systems Lead |
