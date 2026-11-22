# Match Sim v2: design

Version 1.0, 2026-11-19. Owner: Producer (acting for Systems Designer, Gameplay / Champion Designer, Level / World Designer, Technical Director and IP & Originality Checker; every ruling below is logged in `company/DECISIONS.md`). Source: the Founder decisions of 2026-11-19 (GDD v1.12 section 18).

Status: Phase 1 design. Nothing here has run on a phone; every cost figure is a desktop estimate or a headless desktop measurement, and is said to be so.

---

## 1. What changes and why

The v1 simulator (`src/sim/match_sim.gd`) decides a game with eight abstract contests (four lanes and jungle, then an objective and a fight in the mid and late game) and a weighted sum. The arena (Alpha 0.8) then invents a show that agrees with the result: `ShowScript` places towers and kills on fixed beats and `Choreo` walks tokens to fixed places at fixed times. The Founder's verdict: players follow scripted orders instead of acting out their roles (decision 6), heroes have no kits (decision 2), and there are no items (decision 1).

Match Sim v2 reverses the order. The simulation itself is a game of ten role-driven agents on the map: they farm, trade, gank, rotate, take objectives, fight with their kits, buy items and push the base. It writes an **event log**. The arena plays the log back; it no longer invents anything. The report, the scoreboard, kills, deaths, assists, gold and the post-match story all read the same log, so nothing on screen can contradict the result.

What stays: the draft, the Game Plan's eight controls and triggers, Team Bonds, Form, Morale, Fatigue, familiarity, MetaMod, formats, the PCG32 generator and determinism given a seed. Every management lever that feeds a player's phase rating today keeps feeding v2 through the same rating (section 5.1), so no lever goes dead.

## 2. Requirements

| Id | Requirement |
|---|---|
| Q1 | Deterministic: the same inputs and seed give the same event log, bit for bit, on every platform. The v2 path uses only `+ - * /`, `sqrt`, comparisons and PCG32 integers. No `sin`, `cos`, `log`, `exp`, `tanh` or `pow` in anything that decides the result (they are not bit-identical across libm builds; v1 tolerated 1e-9, v2 does not need to). Normal draws use an Irwin-Hall sum of four uniforms. |
| Q2 | One model for every game: the managed club's games, AI-vs-AI league games, playoffs, practice, the tutorial game and calibration all run the same simulator. No second "fast" model that could disagree. |
| Q3 | Fast enough to simulate a whole match day of AI games while the player waits: target median 15 ms, ceiling 40 ms per game in the headless desktop benchmark (section 6.4). Phone cost is estimated at 5 to 8 times desktop and is **not measured**. |
| Q4 | Calibrated: the GDD section 9 bands still hold (a +10 rating team wins about 70 percent, and so on; section 6.3), hero win rates at equal skill stay inside 45 to 55 percent, game length and kill counts look like a mobile MOBA. |
| Q5 | Readable: every decision an agent makes is in the log with its reason (intent), so the arena can show it and the report can name it. |
| Q6 | Presentation never feeds the result (rule R7 and arena rule A1 stay). `src/arena/` never calls the simulator. |
| Q7 | Saves change only by additive keys; `GameState.VERSION` is unchanged (rule R6). |

## 3. Hero kits (decision 2)

### 3.1 Schema

`game/data/heroes_v2.json` (new file; `heroes.json` keeps the identity fields the draft and screens already use, and v2 adds a `kit_id` that points into the new file). One entry per hero:

```
{
  "id": "brannoch",
  "kit_version": 1,
  "title": "short epithet, original",
  "stats": {"hp": 640, "hp_lvl": 92, "atk": 62, "atk_lvl": 3.4, "aspd": 0.68, "armor": 34, "armor_lvl": 3.6,
            "resist": 30, "resist_lvl": 1.4, "range_u": 0.012, "move_u_s": 0.066},
  "passive": {ability},
  "abilities": [{ability a1}, {ability a2}, {ability a3}, {ability ult}],
  "build_default": {"top": ["item ids, 6 finished items in buy order"], "jg": [...]},   // only the slots the hero is played in
  "lore": "one line, original"
}
```

An ability:

```
{
  "id": "brannoch.a1", "slot": "a1" | "a2" | "a3" | "ult" | "passive",
  "name": "original name", "text": "one sentence a player reads",
  "kind": ["damage", "cc", "mobility", "shield", "heal", "buff", "zone", "execute", "stealth", "summon", "wave"],
  "target": "enemy" | "ally" | "self" | "area" | "line",
  "dmg": 80, "dmg_lvl": 22, "ratio": 0.6, "dtype": "phys" | "magic" | "true",
  "cc": "stun" | "root" | "slow" | "knockup" | "silence" | "taunt" | "", "cc_s": 1.0,
  "shield": 0, "heal": 0, "ratio_def": 0.0,
  "range_u": 0.05, "radius_u": 0.0, "cd": 9.0, "cd_lvl": -0.4, "cast_s": 0.25,
  "hit": 0.85,                 // base chance to land (skill shots below 1.0; point-and-click 1.0)
  "dash_u": 0.0, "dur_s": 0.0, // mobility distance; lasting effects
  "unlock": 1 | 3 | 6          // hero level; ult at 6
}
```

Notes:
- The fields are what the fight resolver (section 5.4) needs: damage, control, mobility, protection, cooldown, range and how hard it is to land. Text is for players; the simulator never reads text.
- A **passive** uses a small fixed vocabulary of triggers (`on_hit_nth`, `low_hp`, `on_kill`, `on_ability`, `aura`, `stacks_per_min`, `out_of_combat`) with the same numeric fields, so every passive is simulated, not decoration.
- Abilities level with the hero (`dmg_lvl`, `cd_lvl`); there is no skill-point choice (a manager game: the player sees the kit, not a skill order).
- No mana. Cooldowns are the only cost (genre-common on mobile; one less resource to simulate and explain).

### 3.2 Identity rules

- Each of the seven archetypes has a kit pattern (Bruiser: sustained melee damage and one dash; Bulwark: two controls and a shield; Spellcaster: area damage and waveclear; Gunner: auto-attack scaling and one escape; Shade: burst, stealth or dash, execute; Mender: heal or shield and one control; Binder: long-range control). The hero's tags (Engage, Poke, Protect, Pick, Splitpush, Frontline, Waveclear, Scaling) must be visible in the kit: an Engage hero has a gap-closer with control, a Waveclear hero has an area ability with `wave`, and so on. A data test checks every tag against the kit (section 13).
- `power_early`, `power_mid` and `power_late` stay in `heroes.json` (the draft, the Game Plan preview and the analytic predictor use them). They must agree with the kit's scaling: a test measures each hero's damage at levels 4, 9 and 14 with its default build and checks the ordering matches the three numbers.

## 4. Gold, experience and items (decisions 1 and 3)

### 4.1 Gold and experience

| Source | Gold | XP | Notes |
|---|---|---|---|
| Passive income | 2 g/s from 1:30 | none | |
| Wave (6 minions, every 30 s per lane from 0:45) | 20 g per melee, 26 g per caster, 60 g siege (every third wave) | 60 per minion shared among heroes within range | The share a laner takes (last hits) depends on LAN and MEC and on lane pressure (5.2). |
| Jungle camp (6 per side, respawn 90 s) | 60 to 100 | 90 to 140 | Camp sizes and values live in data. |
| Hero kill | 300 base; bounty +50 per kill streak step (max 700); shutdown | 150 + 20 x level | Assist pool 50 percent of the kill gold, split. |
| Tower | 250 to the team, 100 local | 100 | |
| Stoneback (river, from 4:00, respawn 5:00) | 100 each | 200 each | Team buff: +8 percent move speed out of combat for 90 s. |
| Moonhulk (river, from 12:00, respawn 6:00) | 150 each | 300 each | Team buff for 120 s: +15 percent damage to structures and empowered minions. |

Levels 1 to 15 (mobile pace), XP curve `xp_to_next = 180 + 90 x level`. Respawn time `6 + 2.2 x level` seconds (8 s at 1, 39 s at 15). All numbers are v0 placeholders in `game/data/sim_v2_params.json`, tuned only by calibration.

### 4.2 Items

`game/data/items_v2.json`. About 48 entries:

- 14 components (300 to 1,100 g), 28 finished items (2,300 to 3,200 g), 6 boots (two tiers: 300 g basic, upgraded to 900 to 1,100 g).
- Stats: `atk`, `ap` (ability power), `hp`, `armor`, `resist`, `aspd`, `crit`, `haste` (cooldown reduction, capped at 40), `lifesteal`, `omnivamp`, `move`, `pen_armor`, `pen_resist`, `shield_power`, `heal_power`.
- At most one **unique effect** per finished item from a fixed vocabulary the simulator implements: `burn` (damage over time on ability hit), `antiheal` (40 percent less healing for 3 s), `on_hit` (bonus damage on attacks), `crit_amp`, `spellblade` (next attack after an ability), `guard` (a shield when hit below 30 percent, 60 s cooldown), `revive_once` (stasis, once per item), `slow_on_hit`, `aura_armor` (allies near), `aura_haste`, `execute` (bonus damage to targets below 25 percent), `splash` (attacks hit near targets; waveclear).
- A finished item names its components. Buying happens only at the base (on a recall or a respawn), in the build's order: the next unfinished item's cheapest missing component first, so a hero visibly gets stronger in steps.
- Six slots: boots plus five items; a full build costs about 15,000 g.

### 4.3 Builds (decision 3)

- A **build** is an ordered list of six item ids (boots first by default) for one hero in one slot.
- The **coach suggestion** is computed, never hand-written per hero: for the hero's kit (damage type, ratios, range, tags) and the opponents' drafted heroes (their damage mix, healing, crowd control), score every legal finished item and fill the six slots in order. Example rules: pick `antiheal` once if the enemy has two or more heal or lifesteal sources; armor if 3 or more enemy damage is physical; resist if magic; `guard` or `revive_once` for a carry against a heavy-dive comp. The rules live in data (`items_v2.json` `coach_rules`), so they can be tuned.
- The **manager** edits a build before the game (the build editor, Phase 5): reorder, swap an item for another legal one, or reset to the coach's suggestion. An edited build is stored per player and hero (additive save key `builds`).
- AI clubs always use the coach suggestion. A build is an input to the simulation and enters the outcome seed text (GDD 8.4), so changing a build re-rolls the luck exactly like changing a pick.

## 5. Role AI (decision 6)

### 5.1 How player quality enters

Each agent carries the player's **phase ratings** (`team.ratings[early|mid|late][slot]`, the same numbers v1 uses, which already include Form, Morale, Fatigue, familiarity, HeroFit, PlayerFit, hero power and MetaMod), `team_mod` (Team Bonds), `comp_mod`, the comp style and the lane counters. From them, per agent and phase:

- **Effectiveness** `q = (rating x (1 + team_mod)) / 50`. It scales damage dealt, healing and shielding (`x q^0.5` per ability, so a 20 percent better player deals about 10 percent more), and the share of farm in lane (5.2). The exponent is a calibration constant.
- **Decision quality** from the visible stats, used as probabilities and timings in the role behaviours below: SEN (danger read: when to back off, ward awareness), MAC (rotation timing, objective calls, wave management), LAN (trade choice and last hits), TFT (target choice and positioning in fights), MEC (chance to land skill shots, combo speed), CLU (late fights), CON (the spread of every per-agent draw, as v1's `noise_scale`).
- **Team levers:** `comp_mod` multiplies the fight resolver's damage and control for that team; the style edge (+-4 percent) applies in team fights only (5 or more heroes involved), as in v1; lane counters (+10 percent) apply to that lane's trades.

This keeps every v1 lever wired, and lets calibration tune the size of each effect to the v1 bands (section 6.3).

### 5.2 Shared world model

- **Map graph:** nodes and edges of the v2 map (section 11; same canonical frame as `arena_map.json`: x 0 west to 1 east, y 0 north (Red) to 1 south (Blue)). Distances are in map units.
- **Lanes:** each lane has a wave state: a front position along the lane (0 = Blue tower line, 1 = Red), wave sizes, and the tower states. Minions are simulated per wave, not per minion: a wave has a health pool and a damage rate; two waves meeting trade until one dies; a wave reaching a tower damages it. Heroes add to their wave's damage (waveclear) and take a share of its gold (last hits).
- **Vision:** abstract. Each zone (lane segment, jungle quadrant, river) has a vision value per team that rises with that team's presence and the support's and jungler's warding (MAC, SEN). A gank into a zone the target team sees is detected earlier (the target's SEN check gets a bonus).
- **Decision clock:** each agent re-decides at its **decision points**: arriving somewhere, a fight ending, a wave or camp event, a call from the team, or every 4 to 8 seconds (shorter for higher SEN). Between decision points it carries out its intent; nothing re-decides every frame.

### 5.3 The five role behaviours

Each role is a small priority list of **intents** with scores; the agent picks the best scoring legal intent at each decision point (ties broken by fixed order, noise from the agent's stream). Intents: `farm_lane`, `trade`, `all_in`, `recall`, `clear_camp`, `gank`, `roam`, `ward`, `group`, `contest_objective`, `take_objective`, `siege`, `defend`, `split`, `escape`, `follow` (stay with an ally), `chase`.

**Top (solo side lane).** Default `farm_lane` top. Trades when its lane power (level, kit damage, items, q, LAN) is ahead or the enemy is low; `all_in` when the kill chance is high (SEN gates the risk). Recalls on low health or a full component's gold after pushing the wave. From the mid game: joins the team's `group` call for Moonhulk and sieges; if it has the Splitpush tag, or the plan says Spread out, it takes `split` on the side lane opposite the team's action when the team is not contesting an objective. Never leaves lane in the first 3 minutes unless the plan's jungle focus is top and an enemy is diving.

**Jungle.** Opens with a full clear of its side's camps in an order set by side and plan (the route is data). After each clear, scores every lane for a **gank**: the enemy laner's position (pushed past the river line scores high), health, level gap, the ally laner's control, the jungler's distance, vision in the zone and the plan's jungle focus. Ganks if the score clears a threshold that MAC and SEN move. Tracks Stoneback and Moonhulk timers (MAC): moves to set up 30 to 45 seconds before a spawn and calls the team. Counter-jungles (steals an enemy camp) when the enemy jungler was last seen on the far side. Smite is not a spell: the jungler's objective damage gets a fixed bonus, and a contested objective's last hit goes to the side whose jungler wins a MEC and SEN check.

**Mid.** Default `farm_lane` mid. After pushing a wave in, scores a **roam** to a side lane (MAC, SEN, kit mobility, the side lane's gank score) and joins the jungler's ganks and river fights. Contests every river objective. In the late game it groups with the carry.

**Bot (carry).** Default `farm_lane` bot with the support (`follow` binds them). Most gold-hungry: farms safely, trades only with the support beside it, recalls to buy on component thresholds. From about 12 minutes (or the second item) it groups for objectives and positions at the back of fights (TFT); in the late game it is the main damage and the main target.

**Support.** Default `follow` the carry in bot lane, wards the river and the enemy jungle entrance (MAC, SEN), trades and engages with control (kit). Roams (the plan's Support stays / roams slider and the gank score) to mid or for objectives. In fights it engages (Engage kits) or protects the carry (Protect kits), by kit and TFT.

**Team calls.** One "shot caller" per team (the highest MAC starter) makes team decisions at objective timers and after kills: group for Stoneback or Moonhulk, siege a lane after a won fight, defend a pushed lane, or recall together. Each starter then answers the call with a probability that rises with COM and the pair's Bond (Team Bonds), so a poorly bonded team arrives late. This is where Team Bonds become visible.

**Game Plan (GDD 7.8).** The eight controls act on the behaviours instead of contest weights. Each keeps the zero-sum intent: it trades one thing for another, and calibration checks that no control beats neutral by more than the GDD 9.2 limits.

| Control | Behaviour |
|---|---|
| Spread out / Group up | Group: answers team calls sooner and sieges together; laners leave lanes earlier (less farm). Spread: more split pushing and farming, later arrivals. |
| Tempo / Scale | Tempo: more early ganks, trades and early Stoneback calls; Scale: safer farming, fewer early risks, recalls on time. |
| Mid objectives | Weight of Stoneback in team calls, against fight caution in the mid game. |
| Late objectives | Weight of Moonhulk and sieges, against late fight caution. |
| Lane aggression | The trade and all-in thresholds in lane (variance up, no rating change). |
| Jungle focus | The gank score bonus for one lane; the jungler farms less elsewhere. |
| Support stays / roams | The support's roam threshold. |
| Play safe / Take risks | The spread of every per-agent draw (`variance_mult`). |

Triggers keep their meaning: "ahead after early" and "behind after early" are read at the 8:00 mark from the gold lead (thresholds re-calibrated so each still fires in about 18 percent of equal games), and the chosen plan applies from then on.

### 5.4 Fights

A **fight** starts when opposing heroes are within engagement range in the same zone and at least one side's agent chose to fight (`trade`, `all_in`, `gank`, `contest_objective`, `chase`, a defended siege). The resolver then runs in steps of 0.25 seconds of game time over the heroes in the fight and anyone who arrives:

- Each step: cooldowns tick; each hero picks a target (role and TFT: frontliners take the nearest, assassins the lowest-health carry in reach, carries the nearest in range, supports protect the most threatened ally) and either casts the best ready ability whose range reaches (a combo order per kit), or attacks.
- Landing: an ability lands with probability `hit x (0.75 + 0.25 x MEC/100)`, adjusted by the target's mobility and control state. Controlled targets cannot act.
- Damage: `(dmg + dmg_lvl x level + ratio x power) x q^0.5 x team factors x 100/(100 + effective armor or resist)`; items add their stats and effects.
- Each step each hero checks whether to leave: health below a SEN-moved threshold while losing, or outnumbered, or its intent completed. Leaving is a run toward its base; chasers follow while a kill is likely.
- The fight ends when one side is dead or gone or nobody wants to continue. A kill records killer, assists (everyone who damaged or controlled the victim in the last 10 seconds) and gold.
Fights are the expensive part; the budget assumes about 25 to 60 fights a game with 6 to 40 steps each.

### 5.5 Structures and the end

Three towers per lane per side (outer, inner, gate) and the Cairn (the base core) with two gate towers (as today's map). Towers shoot the nearest minion, or a hero that hits an allied hero under the tower. Destroying the Cairn ends the game (sudden death, GDD 8.7). A siege needs a wave or 3 or more heroes; Moonhulk's buff makes waves siege-capable. A safety stop at 35:00 awards the game to the side with more structures, then more gold (it should never trigger; a test counts it).

## 6. Two simulation approaches

### 6.1 Approach A: fixed-step spatial simulation

Every hero and minion has a continuous position; the world advances in steps of 0.25 seconds; every hero re-decides every step; every attack and ability is simulated everywhere, all game.

- For: the most faithful; positions are exact everywhere; easy to reason about locally.
- Against: about 4,000 steps x (10 heroes + about 60 minions) per game. In GDScript that is an estimated 0.5 to 1.5 s per game on desktop and several seconds on a phone, so a match day of four AI games would freeze the phone, and 40,000-game calibration rows would take days. It breaks Q3, and the usual fix (a second, faster model for AI games) breaks Q2.

### 6.2 Approach B: event-driven macro simulation with fight micro (recommended)

Agents act on the map graph by **intents** with durations (walk from A to B takes distance / speed; a camp clear takes the camp's time; farming a wave takes until the next wave event). The world jumps from event to event in a priority queue (arrivals, wave spawns and clashes, camp and objective spawns, respawns, decision points). Waves are simulated per wave, not per minion. Only fights are resolved step by step (5.4), because only fights need it.

- For: estimated 500 to 1,500 events and 25 to 60 fights per game, about 5 to 25 ms on desktop in GDScript (to be measured in Phase 3). One model for every game (Q2). Every intent is a logged decision (Q5), which is exactly what the arena needs to show roles.
- Against: positions between events are interpolated (a hero walking a path is on the path, exactly; a hero farming stands at the wave front with small idle motion added by the arena, which is presentation only). Calibration must check that the macro model (wave pressure, farm shares) behaves like the genre.

**Recommendation: Approach B.** It meets Q2 and Q3 with margin, and its event log is the role behaviour the Founder asked to see.

### 6.3 Calibration

- **Harness:** `tools/calibrate_v2.gd` runs as a headless Godot scene: batches of seeded games from fixture teams (rating gaps, CON levels, comps, plans, heroes) and writes a JSON report. Several Godot processes run in parallel on the desktop (one per core).
- **Targets** (the GDD 9 table is kept as the acceptance bands, with v2 sampling tolerance): win rate by uniform rating advantage 0 / +5 / +10 / +20 / +30 = 50 / 60 / 70 / 84 / 93 percent plus or minus 3 points; Blue 49 to 53 percent; CON 20 / 50 / 80 at +10 rising; one-phase +10 advantage 54 to 60 percent each phase; CompMod +10 percent about +6 to +9 points; Dive vs Siege +3 to +6; lane counters about +2; comeback rate (behind by 1,500 gold at 8:00, wins) 20 to 40 percent; game length median 13 to 16 game minutes with 90 percent between 9 and 24; team kills per game median 18 to 30; each hero's win rate at equal skill inside 45 to 55 percent over at least 2,000 games; no item in more than 60 percent of coach builds of its class; the Game Plan limits of GDD 9.2 test 1.
- **Sample sizes:** 4,000 games per win-rate row (standard error 0.8 points) for the sweep, 20,000 for the final sign-off rows; hero rows 2,000 games each. The tolerance is wider than v1's because v2 games are about 100 times dearer; the rows that matter most get the larger sample.
- **Knobs** (in `sim_v2_params.json`): the exponent of q, the decision-quality slopes per stat, the comp and style multipliers, the trade thresholds, wave and gold values. Tuning is a recorded sweep, never by hand on one seed.

### 6.4 Phone cost

- Measured in Phase 3 with `tests/bench_sim_v2.tscn` (headless, desktop): median, 90th percentile and worst time per game over 500 games, and the event and fight counts. The results go in `docs/design/MATCH-SIM-V2-CALIBRATION.md` and in this section.
- Phone estimate: a low-end Android phone runs GDScript about 5 to 8 times slower than this desktop. At a 15 ms desktop median that is about 75 to 120 ms per game, so a match day of four AI games is under half a second. **Not measured on a phone.** If a phone turns out slower, the match day runs the AI games across frames behind the existing "advancing" state, which needs no model change.

## 7. The event log

`MatchSimV2.simulate()` returns the v1 result keys (so every consumer keeps working; section 9.1) plus `log`:

```
log = {
  "v": 2, "len_s": 842.0,
  "heroes": {"B.top": {"hero": id, "player": id, "build": [...]}, ...},
  "ev": [ [t, type, ...fields], ... ]   // sorted by t, compact arrays
}
```

Event types (fields after `t` and `type`):

| type | fields | meaning |
|---|---|---|
| `move` | hero, from_node, to_node, t_arrive, intent | walking; the arena draws the path |
| `intent` | hero, intent, target (zone, lane, hero or objective), reason | a decision (the role AI's choice and why) |
| `farm` | hero, lane or camp, t_end, gold, xp | farming until t_end |
| `wave` | lane, side, front_from, front_to, t_end | the minion front moves |
| `fight` | id, zone, heroes, t_end | a fight starts; ends at t_end |
| `cast` | hero, ability_id, target, hit | an ability in a fight (only fights log casts) |
| `hp` | hero, hp_fraction | health samples (in fights, at each change; elsewhere on change) |
| `kill` | killer, victim, assists, gold, shutdown | |
| `respawn` | hero | |
| `buy` | hero, item_id, gold_left | at the base |
| `level` | hero, level | |
| `tower` | tower_id, by_side, by_hero | a tower falls |
| `objective` | id (stoneback, moonhulk), side, by_hero | taken |
| `call` | side, call, target | a team call |
| `recall` | hero | starts a recall |
| `end` | winner, reason | the Cairn falls |

A test checks the log's invariants: times never go backwards per hero; a dead hero has no events until its respawn; every kill's victim is alive just before; gold and items add up to `buy` events; team kills equal the sum of hero kills; the winner destroyed the loser's Cairn.

Size: about 3,000 to 8,000 events a game, about 150 to 400 KB as arrays in memory. The log is never saved (section 9.3); it can be rebuilt from the inputs and seed in one simulation.

## 8. Report, attribution and the story

### 8.1 What the report reads

- **Score line, kills, deaths, assists:** counted from `kill` events (replaces `Report.kda`'s drawn numbers; GDD 9.2 test 6 holds by construction).
- **Game length:** `len_s` (replaces `Report.game_minutes`' cosmetic clock).
- **Feed and phases:** the eight v1 feed items become **moments** picked from the log: first blood, lane results at 8:00 (gold and level lead per lane), each objective, each tower, each fight with two or more kills, the decisive fight, the end. `Report.feed` returns moments in the same shape `{t, key, mine, size, value}` (t is now a fraction of `len_s`), so the Report screen and the arena HUD keep their layout.

### 8.2 Attribution ("Decided by")

v1's exact counterfactual re-simulation does not carry over: in an agent simulation a changed input changes the whole sequence of events, so "the same noise" no longer exists, and averaging many re-simulations is too dear on a phone.

v2 splits the question in two:

1. **Edges going in** (pre-match, no noise): the analytic predictor (the v1 contest model evaluated at zero noise, `GamePlan.expected_final`, re-fitted in calibration so its prediction matches v2's win rates) gives each factor's expected edge: each slot's rating gap, the draft (comp, style, counters), the Game Plan, Team Bonds.
2. **What happened** (the log): per player, gold, damage share, kills and assists, objectives, the decisive fight.

The "Decided by" line names the factor with the largest edge **in the winner's favour** when the winner was favoured; when the loser was favoured, it says the game went against the odds and names the moment that turned it (the decisive fight from the log). Luck is reported as how far the result was from the expectation. Shares still add up to 100 percent. Nothing can contradict the outcome, because the edges are stated as edges going in and the turning point comes from the log.

### 8.3 The post-match story (Phase 5)

Per player, one or two lines from the log, picked by rules: "Top: won the lane by 1,100 gold and took the first tower", "Jungle: four ganks, three kills, both Stonebacks", "Support: saved the carry twice in the Moonhulk fight". Lines are templates in `en.json` (through `merge_copy.py`), filled with numbers from the log.

## 9. Migration

### 9.1 Code

- New: `src/sim/v2/` (`match_sim_v2.gd`, `agent.gd`, `role_ai.gd`, `fight.gd`, `world_v2.gd`, `items.gd`, `kits.gd`, `event_log.gd`). The v1 files stay for the analytic predictor (8.2), the Game Plan preview and old-save replays.
- `MatchRunner.finish` and `MatchRunner.auto` call v2. The result keeps `blue_won`, `final` (now the end margin: `tanh`-free, `clamp((structure lead x 0.08 + gold lead / 10,000), -1, 1)` signed for Blue, never 0 for the winner's side, so the Form Rating, the series tables and every reader of `final` keep working), `sim` (with `contests` filled from the 8:00 lane leads and the objective and fight moments, for old readers), `team_a`, `team_b`, `plans`, `picks`, `bans`, `lineups`, `comp`, `style`, plus `log`, `v = 2` and `builds`.
- Every call site found by `grep` (GameState, ScreenDraft, ScreenGamePlan, ScreenReport, ScreenMatch, ShowScript, ArenaHud, ArenaLabels, Career) is migrated in the same increment that changes what it reads (rule R3).

### 9.2 Golden vectors

- v1's `tests/golden/sim_vectors.json`, `rng_vectors.json` and the pipeline vectors stay and keep being checked (the analytic predictor and PCG32 still depend on them).
- New: `tests/golden/sim_v2_vectors.json`: 24 cases (equal teams, rating gaps, each comp style, each Game Plan control, a build edit, CON extremes, a hero mirror), each with inputs, seed, and the expected winner, length, team kills, gold per side, tower counts and the sha256 of the canonical event log. Generated by Godot itself (`tools/gen_golden_v2.gd`), because v2 has no Python twin: keeping a second implementation of an agent simulation in step would cost more than it protects, and Q1 makes the GDScript result exact on every platform.
- `check_fast.sh`'s recorded golden hash is updated once, in the increment that adds the v2 vectors, and logged. After that it is locked again: any later change to v2 behaviour must regenerate the vectors in its own increment with a logged reason.

### 9.3 Saves

- Additive keys only: `builds` (manager-edited builds: `{player_id: {hero_id: [item ids]}}`), and per stored match result `sim_v` = 2 plus the v2 summary (length, kills per player, gold, towers). The event log is never saved.
- Old saves load unchanged (`check_save_compat` fixtures 0.6, 0.7, 0.8). Their past results have no `sim_v` and are shown as v1 results (score line from the stored values or from `Report.kda` as today).
- A game in progress when the player updates (draft started, not finished) is simply simulated by v2 when it finishes.

### 9.4 The outcome seed

The v2 outcome seed text adds both teams' builds to the drafts and plans (GDD 8.4), so a changed build re-rolls the luck. Per-agent decisions draw from named streams `v2:<side>.<slot>:dec`, fights from `v2:fight:<n>`, waves from `v2:wave:<lane>`: changing one hero does not shift another hero's stream.

## 10. Show length (decision 4)

- One tunable value: `show_seconds` in `game/data/sim_v2_params.json` (default **180**, the real seconds a median-length game takes at normal speed). The show speed for a game is `len_s / show_seconds x (median length / len_s)^0.5`, so a long game takes somewhat longer to watch than a short one but not proportionally. Speed x2 and x4 and Skip stay.
- Quiet stretches (no fight, no objective, no tower in the next 6 seconds of game time) play at up to 2.5 times the base speed; fights play at the base speed. The total still lands on the formula above because the quiet-time multiplier is solved per game.
- The pace log (Settings) keeps recording real watch time, skips and speed-ups, so testers' numbers can move `show_seconds`.

## 11. Map v2 concept (decision 5)

### 11.1 What is adopted and what is not

Adopted from the Founder's description of the reference: a steep tilt (about 55 degrees) with mild perspective; three material zones (pale flagstone at bases and lane approaches, packed dirt lanes and trails, grass with rocks and conifers in the jungle) and river water; irregular flagstones with moss; upright units small against the map; thin segmented team-coloured health bars; numbers on structures; tower range rings; lane edges of walls, trees and rocks; braziers; camps in pits; team-colour glow only at crystals (our Cairns), towers and floor emblems; a floating rounded island in dark mist with a vignette; a follow camera and a corner minimap.

Not taken: the reference's geometry (bases at opposite corners, a diagonal mid lane, a diagonal river), its base, camp and objective positions, its emblems, turret and crystal shapes, its colours, and any pixels.

### 11.2 Three original layouts

**L1 "Wrenfell Rise" (vertical, recommended).** Bases at the south and north ends of a tall rounded island (Blue south, Red north; mirrored for the player on Red, as today). Mid lane runs straight north-south; top and bot lanes swing out along the west and east edges in wide arcs. The river is not a diagonal but the **Mere**, a round lake at the centre with **Moonhulk's island** in it, fed by two streams to the west and east edges; **Stoneback** sits in a stone pit on the east stream, a second early camp (the Mossback) on the west stream. Each half has six camps in three pockets (thicket, hollow, rise). Extends the current Alpha 0.8 map (`arena_map.json`, map id hollowmere), so the existing graph, node names and validator carry over.
IP verdict (IP & Originality Checker): **clear**. North-south axis with a central lake and island is not the reference's corner-to-corner diagonal; the lake-and-island centrepiece, the two stream objectives on opposite sides and the three-pocket jungle are our own. Genre conventions only (three lanes, a jungle, river objectives, towers, bases).

**L2 "Twin Weirs" (horizontal).** Bases at the west and east ends of a wide island; a weir (dam) crosses the middle north-south with two sluice gates as objective arenas. IP verdict: **clear**, but it needs a landscape screen or a sideways read in portrait, and nothing from the current map carries over.

**L3 "Hollow Crown" (ring).** A round island; the three lanes are spokes from two bases on a ring road; the jungle sits between spokes; the objectives in a crater at the centre. IP verdict: **caution**. Original, but a ring-and-spokes map reads less like the genre the player knows, and a central crater with the big objective edges towards some arena designs in other games. Usable, not preferred.

**Chosen: L1 "Wrenfell Rise".** It is clearly original, it keeps the player's base at the bottom of a portrait screen with the enemy "up the map" (the natural direction for a tilted camera), and it reuses the tested map graph.

### 11.3 Orientation: portrait

Every other screen of the game is portrait, the game is played one-handed between other tasks, and turning the phone for one screen and back is a cost every game. A tilted camera looking north up a tall map uses the portrait height as depth, which is exactly where the tilt is most legible. Landscape would show more width, which a follow camera does not need. **Ruling: portrait** (logged). A landscape mode can be added later because the camera and the map are independent of the screen shape.

### 11.4 Camera method (draw-call budget)

No 3D. Three layers:

1. **Ground:** the whole island is baked ONCE into a texture (2,048 x 2,048 at most, in the canonical top-down frame) from procedural tiles: flagstones with moss cracks, dirt with ruts, grass with stones and conifer clusters, water with shore foam, the lake, inscribed slabs and glowing team emblems (our own designs). Mipmaps are generated once. On screen the ground is ONE quad drawn with a small canvas shader that maps each screen pixel back to the ground (the inverse of a tilted pinhole camera: tilt about 55 degrees, a narrow field of view so the far edge is about 10 to 15 percent narrower). One draw call, one texture fetch per pixel.
2. **Upright sprites:** heroes, minions, towers, Cairns, trees and rocks along lane edges, braziers and camp monsters are sprites from one atlas, each placed at `project(ground point)` and scaled by depth, sorted far to near. Drawn from one canvas item with one texture they batch into a few draw calls. Health bars and structure numbers come from the same atlas (bars) and one font (numbers).
3. **Overlays in screen space:** the minimap (the same ground texture at a small size, plus dots), the scoreboard and the text strip.

The projection is one function (`ArenaCam.project`) shared by the shader (as uniforms) and GDScript, so sprites sit exactly on the ground. The follow camera picks a focus from the log (a fight, then an objective, then a siege, then the player's team), eases between them and never cuts faster than 0.6 seconds.

Budget: ground 1, sprites about 8 to 15 (atlas batches broken by text), minimap 2, HUD about 25: **about 40 to 50 draw calls, under the 60 target**. Fill rate: one textured full-arena quad plus sprites; not measured on a phone.

## 12. IP review plan (about 200 abilities and the item catalogue)

1. **Name lists.** `tools/ip_names.py` holds a deny list of distinctive hero, ability, item and place names from the major MOBAs and hero games (written from public knowledge; never copied art or text) and generic words that are allowed. Each name of ours is normalised and checked by exact match, token overlap and edit similarity (a ratio above 0.8 is flagged). Generic genre words on their own ("Shield", "Dash", "Boots") are allowed; distinctive compounds and coined names are not.
2. **Kit shapes.** A kit is flagged when its passive plus three or more abilities match a well-known hero's signature set in the same order and theme (for example a hook that pulls, a damage aura and a channelled bite on one hero). The IP & Originality Checker reviews each archetype's ten heroes as a group, so two of our heroes do not drift into one famous kit between them.
3. **Item effects.** Effects are a small generic vocabulary (4.2); names and the pairing of stats and effect are checked against the deny list's famous items (for example a crit-damage amplifier with that well-known name, or a stasis item).
4. **Output.** `docs/design/IP-REVIEW-KITS-ITEMS.md`: every name with its verdict (clear, renamed, caution), every flagged kit with the change made. `tools/test_content.py` runs the name check on every commit, so a later rename cannot reintroduce a clash.
5. Not covered: this is not a trademark search or legal clearance. The trademark search for "Gloamline" stays a Founder item.

## 13. Test plan

| Test | Where | What it proves |
|---|---|---|
| Kit and item schema | `tools/validate_data.py`, `tools/test_content.py` | Every hero has a passive and four abilities with the required fields; tags are visible in the kit; items have legal stats, components that sum below the price, one effect from the vocabulary; every default build is legal. |
| IP names | `tools/test_content.py` (with `tools/ip_names.py`) | No name of ours matches the deny list. |
| Determinism | `tests/sim_v2_tests.gd` | Same inputs and seed give the identical log twice; different seeds differ. |
| Golden v2 | `tests/sim_v2_tests.gd` + `check_fast.sh` hash | The 24 vectors reproduce exactly. |
| Log invariants | `tests/sim_v2_tests.gd` | Section 7's invariants over 200 seeded games. |
| Levers live | `tests/sim_v2_tests.gd` (small samples) and the calibration report (large) | Each v1 lever (rating, CON, comp, style, counters, each plan control, Bonds) moves the win rate in the right direction. |
| Role behaviour | `tests/sim_v2_tests.gd` | Junglers clear camps and gank; supports stay with the carry in lane and ward; tops stay top early; mids roam after a push; everyone groups for Moonhulk at least once in a long game. |
| Calibration | `tools/calibrate_v2.gd` (offline, before sign-off) | Section 6.3 bands. |
| Benchmark | `tests/bench_sim_v2.tscn` | Section 6.4. |
| Saves | `check_save_compat` (extended) | Old fixtures load; `builds` is additive; a v2 save round-trips. |
| Arena v2 | `check_arena_v2`, `check_ui_match` (migrated), pictures | Tokens are where the log says at every t; the camera follows; draw calls under 60; nothing in `src/arena` calls the simulator (grep test, rule A1). |
| Manager layer | `check_ui_heroes`, `check_ui_build`, `check_ui_report` (migrated) | Hero pages show the kit; the build editor saves, resets and feeds the next game; the story lines match the log. |

## 14. Build plan

| Phase | Increment | Content | Gate |
|---|---|---|---|
| 0 | P0 | Decisions in DECISIONS.md and GDD v1.12 | fast |
| 1 | P1 | This document | fast |
| 2 | D1 | Kit schema, validator and IP name tool | fast |
| 2 | D2 | 40 kits and stats (`heroes_v2.json`) | fast |
| 2 | D3 | Item catalogue and coach rules (`items_v2.json`) | fast |
| 2 | D4 | IP review document, renames | fast |
| 3 | S1 | Map graph v2 data (L1, extends `arena_map.json`) | fast |
| 3 | S2 | Simulator core: world, waves, agents, intents, event queue, log | fast |
| 3 | S3 | Fight resolver, kits, items, buying | fast |
| 3 | S4 | Role AI, team calls, Game Plan mapping | fast |
| 3 | S5 | Wiring: MatchRunner, Report from the log, analytic predictor, save keys, golden v2, every call site migrated | fast |
| 3 | S6 | Calibration and benchmark report; constants tuned | full |
| 4 | V1 | Ground bake and tilted camera shader | fast |
| 4 | V2 | Log playback: sprites, bars, structures, minimap, follow camera | fast |
| 4 | V3 | Role visibility (intent labels from the log), fights and casts, show-length pacing | full |
| 5 | M1 | Hero pages | fast |
| 5 | M2 | Build editor with coach suggestion | fast |
| 5 | M3 | Post-match story | full |
| end | R | Version, notes, one signed APK | full |

## 15. Risks

| Risk | Mitigation |
|---|---|
| v2 too slow on phones | Approach B budget; benchmark in S6; AI games can run across frames. |
| Calibration does not reach the v1 bands | The q exponent and decision slopes are the main knobs; the analytic predictor is re-fitted to whatever v2 does, so the Report stays honest either way. |
| Role behaviour looks robotic | Decision points use noise and SEN-scaled timing; the arena adds idle motion; testers judge. |
| 200 abilities hide an IP clash | Two-stage review (names by tool, kit shapes by the checker) and a commit-time name test. |
| The log is too big for memory on a phone | Compact arrays (about 150 to 400 KB a game); only the watched game keeps its log. |
| Existing screens read v1 fields | v2 fills every v1 key (9.1); every call site migrated in S5 with its tests. |

## 16. Implementation notes (Phase 3, increment S-A, 2026-11-19)

- **Clock.** Approach B is built as fixed macro steps of `dt` = 2 s (agents act by intents and re-decide only at decision points) instead of a priority queue; fights run in 0.25 s steps. Simpler, the same behaviour, and the event log is identical in kind. The acting order of the ten heroes is reshuffled every step (stream `v2:order`) and the encounter loop alternates sides, so neither side moves first.
- **Player quality.** Effectiveness is linear: `qe = 1 + q_k x (q - 1)` with `q_k` = 0.25, used by fights, farming and every decision-time power estimate (design Q1 rules out `pow`). First calibration, 200 side-alternated games per row with random role-correct drafts: rating gap +5 wins 57.5 percent (target 60), +10 69.0 (70), +20 83.5 (84), each inside the plus or minus 3 band. Game length median about 14 game minutes (9 to 21), team kills median about 25 to 30.
- **Side bias found and fixed.** The first build had Blue winning 84 percent of identical drafts played from both sides: the loader converted Red's tower positions a second time (the map data already measures them from Blue's gate). After the fix the same test gives 26 to 24.
- **The log** is sorted by time at the end (fights write ahead), cut at the Cairn's fall (kills, deaths and assists recounted from what remains), and the position track's alive flag is rewritten from the kill and respawn times.
- **Speed, measured** (headless desktop, `tests/sim_v2_tests.gd` and the lab runs): about 180 to 260 ms per game. This is **over the 15 ms target and the 40 ms ceiling of Q3**. Fights are about 20 percent, decisions about 20 percent, the rest is the per-step world (lanes, movement, calls). An optimisation pass is owed in S6; the fallback is to run AI-vs-AI games on worker threads (the simulator holds only plain data). Not measured on a phone; at 5 to 8 times slower a game would take about 1 to 2 s there.
- **Calibration harness:** `tests/calib_v2.tscn` (offline; env CAL_GAP, CAL_N, CAL_SEED, CAL_CON_A, CAL_CON_B, CAL_COMP).

## 17. Match views: Field, Action, All (Founder decision 2026-11-22)

The Founder kept the Arena v2 look after his phone test and asked for three views the player can switch at any time with a three-part control "Field | Action | All" above Speed and Skip. The choice is the device setting `[arena] camera` (default Action). Data: `game/data/arena_view_v1.json`. Code: `ArenaVision`, `ArenaChase`, `ArenaView.set_mode`.

| View | Fog of war | Camera | Input |
|---|---|---|---|
| Field | on: only what your team sees | the whole island, fixed (pitch 64 degrees, distance fitted so the four corners stay in view) | none |
| Action | on | chases the action (below), eases between targets | drag to look; 5 s after the last touch it eases back to the chase |
| All | off | the whole island, fixed | none |

**Vision** (`ArenaVision`, display only). Sources: your team's living heroes, its minion waves at each lane front (from 0:45), its standing towers and Cairn, and its wards (each "ward" event of the log at the warder's position, for `vision_ward_s` seconds). Radii in ground units in the data (hero 0.085, minion 0.05, tower 0.095, Cairn 0.13, ward 0.075). The fog is a 64 x 64 mask over the ground texture (alpha 0 where seen), redrawn at most 4 times a real second, read by the ground shader (fogged ground greyed and darkened) and drawn over the minimap: one texture, no extra draw call per unit. Enemy heroes, minions, casts, kill bursts and intent labels outside vision are simply not drawn. Structures and objective camps always show their state (public knowledge in the genre). Rule A1 holds (nothing calls the simulator) and so does R7 (nothing feeds a result).

**Feed in fog (decided).** Kills, towers and objective takes are still announced in the text feed and the scoreboard even when they happen in the fog, as a caster would; the map shows the place only when your team sees it (a kill burst in the fog is not drawn, and the Action camera does not go there).

**Chase** (`ArenaChase`). Candidates at game time t, best first by priority: a decisive play 5 (a fight with 3 or more kills, or a Cairn falling), an objective take 4 (Stoneback, Moonhulk; window 6 s before to 1.5 s after), a tower falling 3, a fight 2 (plus 0.05 per hero in it), a kill 1.5, else your team's centre 0. With fog only candidates your team can see count (a fight counts if any of its heroes is seen). The camera keeps one target at least 2.5 real seconds (the minimum dwell), then moves to a better one or, when its event is over, to the best one on; it eases (rate 2.6 per second), so it never jumps. The v2 log has no `decisive` flag; "decisive" is derived here for the camera only.

**Readability.** Field and All draw tokens 2.3 times and health bars 2 times bigger than Action and labels at 26 px (24 px in Action, the floor). Screenshots at 720 x 1280 in normal, large text, colour-blind and tall are in the shots matrix (module `match`).

**Cost (desktop, headless renders; not a phone).** Match screen 26 nodes and 29 to 31 draw calls in every view (was 22 nodes, 23 to 25): the mask texture on the minimap and the view control. Building the mask is about 20 sources times their bounding boxes of cells, a few thousand cell tests 4 times a second.
