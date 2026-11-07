# Game Design Document v1.1

Status: DRAFT, revised after independent review. Author: Game Design Lead and Systems Lead. Date: 2026-11-07.
Reviewers: Systems Lead + IP Checker (first review done, findings addressed in section 16), then Founder.

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
| Potential | 1 to 100 | Soft cap for each stat's growth; revealed only through scouting and time |
| Form | -10 to +10 | Moves with recent results; mean-reverts to 0 |
| Morale | 0 to 100 | Affected by results, playing time, contract, team atmosphere |
| Fatigue | 0 to 100 | See section 7.3 |
| Hero familiarity | 0 to 100 per hero | Starts 0 to 30 for new heroes; grows when played and trained |
| Age | 16 to 35 | Affects growth rate and eventual decline |

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
Cond        = Form*0.4 + (Morale-50)*0.06 - 0.15*max(0, Fatigue-40)        (points)
HeroFactor  = (0.85 + 0.15*Familiarity/100) * (0.90 + 0.10*min(1, MEC/(15*Difficulty)))
Fit         = PlayerFit * HeroFit
PhaseBase   = Early: 0.6*BaseRating + 0.4*LAN
              Mid:   BaseRating
              Late:  0.8*BaseRating + 0.2*CLU
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
| power_early, power_mid, power_late | 38 to 62 each; the three sum to 150 plus or minus 6 (power budget) |
| damage_type | Physical, Magic, Mixed |
| range | Melee, Mid, Long |
| difficulty | 1 to 5 |
| tags | Engage, Poke, Protect, Pick, Splitpush, Frontline, Waveclear, Scaling |
| strong_vs | Up to 3 hero ids this hero counters |

### 5.3 Composition scoring

Each team's picks produce a **CompMod** (range -10% to +10%) and a **comp style**.

- **Needs:** at least one Frontline, at least one Engage or Pick, at least one Waveclear. Each missing need is -3%.
- **Damage balance:** Physical counts 1 physical, Magic 1 magic, Mixed 0.5 of each. If either total is 3.5 or more, -4%.
- **Synergy pairs** (each pair counts once when both tags are present, on different heroes): Engage with Pick, Protect with Scaling, Poke with Waveclear, Frontline with Engage. +1.5% each, capped at +6%.
- **Comp style:** Dive score = number of Engage + Pick tags; Siege score = Poke + Waveclear; Protect score = Protect + Scaling. The style is the highest score if it is at least 4 and at least 1 above the second; otherwise Skirmish.
- **Style triangle:** Dive beats Siege beats Protect beats Dive. The winner gets +4% on **teamfight** contests only. Skirmish is neutral.
- **Lane matchups:** in each lane contest, a hero that is `strong_vs` its opposing hero gives that lane +5%. In the Bot lane, either of the two heroes counts, capped at +5%.

### 5.4 Patches and the meta

The league runs on **patches** (for example every two in-game weeks). Each patch changes MetaMod for a subset of heroes by small amounts, so strong picks rotate. The AI drafts using current MetaMod, so the meta is visible to the player.

---

## 6. Draft

Both teams draft before every match. The hero pool is **40 heroes** (about 8 per slot).

**Sides:** Blue picks first. In a league match the higher-ranked team chooses the side; in the prototype Blue is assigned by a seeded coin flip.

**Sequence (v1):**

1. Ban phase 1: Blue, Red, Blue, Red, Blue, Red (3 bans each).
2. Pick phase 1: Blue 1, Red 1, Red 2, Blue 2, Blue 3, Red 3.
3. Ban phase 2: Red, Blue, Red, Blue (2 bans each).
4. Pick phase 2: Red 4, Blue 4, Blue 5, Red 5.

Each team ends with 5 bans and 5 picks; 20 heroes leave the pool.

**Rules:** a hero can be picked or banned once per match. **Role floor:** a ban or pick is blocked if it would leave fewer than 3 available heroes whose primary role is any slot that still needs a pick. Timer: 20 seconds per decision in Full mode (no timer in the prototype).

**Player experience:** the draft screen shows each starter's familiarity with every available hero, current MetaMod, and a live preview of CompMod, style, and lane matchups.

**AI drafting (v1):** each pick scores candidates as `familiarity fit * 0.35 + MetaMod * 0.20 + composition need * 0.20 + counter value vs known enemy picks * 0.25`, plus noise that grows as AI difficulty drops. Bans target the opponent's highest `familiarity * MetaMod` heroes, with a 25% chance of banning by MetaMod alone so decoy familiarity does not work reliably.

---

## 7. Management loops

### 7.1 Calendar

Time advances in **days** when the player taps Continue. A season has two splits (9 weeks each, 2 match days per week, 18 matches) plus playoffs and a short off-season. Real-time timers are not used offline.

### 7.2 Roster and contracts

- 5 starters, up to 5 substitutes (max 10 players). Substitutes may be swapped in before any match.
- Contracts have a length (in splits), a wage, and optional clauses (release fee, bonus).
- Free agents and other clubs' players can be approached. The AI values an offer on wage versus the player's value, role need, club standing and playing time. Exact valuation is task D-007.

### 7.3 Training and fatigue

Each player has one **training focus** per week: a stat, a hero's familiarity, or a **team scrim** (builds chemistry).

```
gain = base * (1 + 0.1*CoachLevel) * (1 - stat/Potential) * AgeFactor * (1 - Fatigue/200)
```

`base` is 0.5 points per week. `CoachLevel` is 1 to 5. `AgeFactor`: 16 to 20 = 1.3, 21 to 23 = 1.1, 24 to 26 = 0.8, 27 to 29 = 0.5, 30 and over = 0.25. From age 29, MEC declines about 1 point per season.

Fatigue: +12 per match played, +5 per training week, -8 per rest day. The penalty in section 4.4 starts at 40, so a light load is free and a heavy load hurts; QA checks that no training schedule dominates.

Familiarity: +3 per match played with the hero, +1.5 per week of focused training (scaled by coach), -0.5 per week if unused and above 50.

### 7.4 Scouting

Scouts are assigned to a region and role. Reports reveal stats as ranges with half-width `max(2, 14 - 3*ScoutLevel - 2*ReportsSoFar)` points. Potential is shown as a star range that narrows over time. Hidden gems and overrated players both exist.

### 7.5 Staff and facilities

| Staff | Effect |
|---|---|
| Head Coach (level 1 to 5) | Training gain multiplier |
| Analyst (level 1 to 5) | StaffBonus +0.4% per level to team ratings (max +2%); draft preview accuracy |
| Scout (level 1 to 5) | Narrower reports, wider region coverage |

Facilities (levels 1 to 5): each level adds +5% training gain and +1 fatigue recovery per rest day.

### 7.6 Finance

Income: sponsors (scale with league tier and results), prize money, transfers. Expenses: wages, staff, facilities, transfer fees. Each tier has a **wage cap**. Running out of money restricts signings. Numbers are task D-007.

### 7.7 Chemistry

Chemistry points (0 to 100): +4 per match together, +3 per scrim week, -25 whenever a starter is replaced (minimum 0). `ChemBonus = min(0.035, 0.03 * (Chem/100) * (0.5 + avgCOM/100))`. Team modifier `TeamMod = ChemBonus + StaffBonus`.

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

**Early game (about 0 to 14 min):** four contests.

| Contest | Compares |
|---|---|
| Top lane | Top vs Top (with lane bonus) |
| Mid lane | Mid vs Mid (with lane bonus) |
| Bot lane | Average of Bot Carry and Support vs the opposing pair |
| Jungle | Jungle vs Jungle |

`A_early = 0.28*(top + mid + bot) + 0.16*jungle`

**Mid game (about 15 to 28 min):** two contests with different inputs, carrying `A_early` forward.

```
Objective rating = sum(OBJ_W[slot]  * rating) * (1 + CompMod)
Teamfight rating = sum(FIGHT_W[slot]* rating) * (1 + CompMod + StyleEdge)
OBJ_W   = Jungle 0.30, Support 0.25, Mid 0.15, Top 0.15, Bot 0.15
FIGHT_W = Bot 0.25, Mid 0.25, Top 0.20, Jungle 0.15, Support 0.15
A_mid = 0.35*objectives + 0.65*teamfights
```

**Late game (29 min onward):** the same two contests with late ratings, carrying `0.5*A_early + 0.5*A_mid`.

`A_late = 0.25*objectives + 0.75*teamfights`

**Winner:** `Final = 0.30*A_early + 0.30*A_mid + 0.40*A_late`. Team A wins if `Final > 0`. Early and mid results count directly, not only through carry-over, so early leads and early-power heroes matter.

### 8.4 Randomness and determinism

- RNG: **PCG32** with Box-Muller for normal draws. Match seed = hash(save seed, match id), fixed when the match is generated, before the draft.
- Each contest draws from its own named substream (`seed + contest id`), so replaying a match with a changed input uses the same noise. This allows exact counterfactuals for reports.
- Engineering produces golden test vectors (inputs, seed, outputs) from the reference implementation in task P-002; the Godot module must reproduce them.
- Offline single player accepts save-reload redrafting as a known risk; competitive modes use a single autosave.

### 8.5 Match report and attribution

- **Contribution** of slot `s` to contest `c` = `phase weight * contest weight * slot weight * (rating_A,s - rating_B,s) / D` (signed). The report ranks the largest absolute contributions, and the MVP is the player with the highest total on the winning team.
- **Draft edge** = `Final` minus `Final` recomputed with CompMod, StyleEdge and lane bonuses set to zero, using the same seed (counterfactual).
- Example lines: "Red won Mid lane by a large margin", "Blue's Gunner scaled and won the Moonhulk fight", "Draft edge: Dive beat Siege".
- Timeline times are fractions of the match length `L`: lane results 0.25L, first Stoneback 0.40L, mid fights 0.60L, Moonhulk 0.80L, base siege 1.0L.
- Match length: `L = clamp(26 + 12*(1 - mean(|A_mid|, |A_late|)) + Normal(0, 2), 22, 48)` minutes.

### 8.6 After the match

Form moves toward the result (+/-2), morale +/-5 to 10 based on result and playing time, fatigue +12 for players who played, familiarity of picked heroes rises, chemistry +4.

---

## 9. Balance targets (QA acceptance criteria)

Measured on 40,000 simulated matches, equal CON of 50 unless stated. Tolerance is **plus or minus 2.0 points** for win rates (standard error about 0.25).

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
| CompMod +10% vs none, equal players | about +6 to +9 points | 57.4% |
| Dive vs Siege, equal players | about +3 to +6 points | 54.6% |
| Lane counter bonus +5% in all three lanes | about +2 points | 52.1% |
| Comeback rate (team behind after early game, |A_early| of 0.2 or more, wins) | 25 to 40% | 27.8% |

Additional targets for the full game: no hero outside agreed pick/win bands at equal skill; no comp style beats the others by more than about 5 points in the league average; no training or fatigue schedule is strictly dominant.

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
- One league of 10 teams, 5 slots, **40 original heroes**, about 140 generated players (10 per club plus 40 free agents).
- Draft, match simulation with text match report, roster screen, simple training.
- **Play modes:** Full (player drafts every match) and Quick (auto-draft, skim result for non-key matches).
- Plain placeholder visuals.

**Exit criteria:** a full season (about 24 player matches) can be played in about 15 minutes in Quick mode; the 40,000-match batch tests meet the targets in section 9; a non-developer can understand why they lost a match from the report.

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

Founder questions are in `company/DECISIONS.md`. Parameters still to define are tracked on the task board: economy and wage caps and contract valuation (D-007), hero data schema samples and 40-hero set (D-005, D-008), player generation rules (D-008), the PCG32 and golden-vector spec (P-002).

---

## 16. Change log

| Date | Change | By |
|---|---|---|
| 2026-11-07 | v1 draft | Game Design Lead, Systems Lead |
| 2026-11-07 | v1.1 after independent review: model rebuilt so early and mid phases count (final score across all phases); objectives and teamfights use different slot weights; draft levers (CompMod up to 10%, style, lane counters) now simulated; slot assignment and hero fit defined; counterfactual draft attribution; determinism spec; constants re-tuned (D 25, sigma 2.0, gamma 0.8); pool raised to 40 with role floors; draft AI reweighted; missing parameters added; exit criteria use Quick mode; IP-sensitive names replaced (Heartstone, Ashen Vale, Ancient Colossus, Champions, mastery) | Game Design Lead, Systems Lead |
