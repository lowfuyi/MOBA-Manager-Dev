# Action vocabulary v1: what the player sees, and which simulation output says so

Owner: Gameplay / Champion Designer. Date: 2026-11-08. Workstream W4 (live match arena, Alpha 0.7 plan). Status: draft for review by the Lead Game Designer, Systems Designer, Esports Manager, Technical Designer, VFX Artist and the IP & Originality Checker.

This is the contract between the simulation and the arena. The simulation decides the match first. The arena only plays it back, and it can never change who wins. Every name here is a placeholder that follows the GDD (map Hollowmere, early objective Stoneback, late objective Moonhulk, base core the Cairn, hero names from HERO-SET-v0) and still goes to the IP & Originality Checker.

Revision 2026-11-08 (wave 1b, reconciliation): places, nodes and towers now use the ids of `game/data/arena_map.json` (C6); the scoreboard counts 6 towers per side and the 2 guard towers are scenery (C5); the late fight has a held-fight rule and a new invariant I9 for the case where the match winner loses it (C8); the loose claims in the review are corrected (sections 0, 4.1, 2.1); colours follow the one-rule ruling (C4); the two open questions are settled (section 10).

### Who owns what in this file

| Part | Owner | Note |
|---|---|---|
| Beats, cues, scoreboard rules, invariants | Gameplay / Champion Designer | The scoreboard maths is also read by the Systems Designer, who owns `Report.story` once it exists (S3) |
| **Intent labels and status tags (all of section 4.3)** | Gameplay / Champion Designer | The 52 intents and their ids, the rule that decides when each shows, and the length limit |
| **Commentary lines** (the caster-style sentence line, any text that is not an intent label or a status tag) | **Narrative Designer** | Written to the Esports Manager's tone rules (`docs/design/ESPORTS-NOTES.md`). Not written in this file |
| Tutorial and help copy | UI/UX Designer drafts, Narrative Designer polishes | Not in this file |
| Map ids, positions, unit conversion of "body width" | Level / World Designer | `game/data/arena_map.json` is the authority |
| Colour tokens | Art Director | This file names roles only (see the colour rule in section 2.2) |

If the Narrative Designer rewrites an intent label or a status tag for tone, the id, the "shown when" rule, the 28-character limit and the checks in section 4.1 stay as they are here. Gameplay re-runs the label check after any such edit.

## 0. Summary

1. The arena reads one finished result (`res`) and builds a **show script** before the first frame. Nothing in the script is decided during playback.
2. There are twelve beat ids. Not every one is tied to a simulation trigger, and this file says so plainly in section 2.1: eight read a field of the result directly (a contest, `plan_used`, the final or the picks), two are derived from formulas over sim outputs (`tower_break`, `tower_push`), and two are cosmetic walking with no sim link (`rotate_stone`, `reset`). Every one of the eight real contests becomes one visible beat at the same moment the existing feed and the report's "Key moments" already stamp it (`Report.FEED_ORDER`: 0.18, 0.21, 0.24, 0.27, 0.45, 0.60, 0.80, 0.95 of the game clock). In the 75 s window that is 13.5, 15.75, 18.0, 20.25, 33.75, 45.0, 60.0 and 71.25 s. So the arena clock, the feed line and the report agree to the second.
3. The scoreboard is a pure function of the contests: a lead ladder whose last step equals `res.final` exactly, tower credits from a pressure sum, kills taken from `Report.kda`, objectives from the signs of `obj_mid` and `obj_late`. Section 5 gives the formulas, a worked example and eight invariants. I ran the formulas on 40,000 simulated matches and all invariants held (section 9).
4. Variety (who strikes first, small path jitter, which wording) comes only from a new stream family named `show`, seeded from `res.mseed`. It never touches a simulation stream, and the same seed plays the same show.
5. Intent labels (52 intents, 156 lines, all 28 characters or fewer) show the coach's posture before a beat. They say what a side is trying, never what will happen. Gameplay owns them; the Narrative Designer owns commentary lines (see "Who owns what").
6. Two things the arena needs are not in the result today: the Game Plan sets (`res.plans`, which also exposes a bug in the report's attribution) and a kill rate that suits a 75 s show. Both are in section 2.5 for the Systems Designer.

## 1. The contract

### 1.1 Hard rules

| # | Rule |
|---|---|
| H1 | The arena is playback only. It never calls `MatchSim`, `GamePlan.simulate` or `Report.attribution` to find an outcome, and never writes to `res`. A test greps the arena code for those calls. |
| H2 | The winner of every beat, its size word and the final winner come from `res.sim.contests`, `res.final` and `Report.margin_word` / `Report.result_word`. |
| H3 | Everything the arena shows as a number (kills, towers, objectives, gold lead) is derived by the formulas in section 5, and ties out with `Report.kda` and `Report.attribution` at the end. |
| H4 | The watch window is 75 s at normal speed (Founder decision, `ScreenMatch.WATCH_SECONDS`). Beats may not borrow time from each other. 2x speed and Skip stay free. Skip jumps the show time to 75 s and the scoreboard shows the final state, because the scoreboard is a function of show time. |
| H5 | If a beat cannot be supported by a real output it is marked **Cosmetic** or **Unsupported** (section 2) and never presented as news (no kill that the ledger did not count, no "first blood" claim unless the ledger says so). |
| H6 | No colour-only meaning. Every cue also has a shape or a word. The Settings switches (Animations, colour-blind colours, larger text) apply. |

### 1.2 What the arena may read

| Input | Exact field | Used for |
|---|---|---|
| Eight signed contests (positive favours Blue) | `res.sim.contests[k]`, k in `top, mid_lane, bot, jungle, obj_mid, fight_mid, obj_late, fight_late` | Winner and size of each beat, lead ladder, pressure |
| Luck of each contest | `res.sim.noise[k]` | "Against the odds" tag |
| Phase results | `res.sim.early`, `res.sim.mid`, `res.sim.late` | Plan trigger check, arc |
| Final | `res.final`, `res.blue_won` (equals `res.sim.a_won`) | The ending and the tie-out |
| Plan switch | `res.sim.plan_used` = `{B: id, R: id}`, id is `default` or a trigger id | Plan check beat |
| Heroes and players | `res.picks[side][slot]` (hero ids, look up in `App.world.heroes`), `res.lineups[side][slot]` | Who is on the map |
| Comp style and mod | `res.style[side]`, `res.comp[side]` | Fight and push choreography, opening labels |
| Draft counters | `res.team_a.lane_mod`, `res.team_b.lane_mod` (keys `top, mid, jg, bot`) | `lane_counter` label |
| Match seed | `res.mseed` | Root of the `show` streams |
| Feed events | `Report.feed(res, my_side)` | Captions, identical text to the feed panel |
| Game clock | `Report.game_minutes(res)` | Clock display and stamps |
| Kills, deaths | `Report.kda(res)` | Kill ledger (section 5) |
| Why | `Report.attribution(res, my_side)` | End card reason |
| Your plan | `App.gs.plan_set()` today; `res.plans` after request S1 | Plan chip and plan labels |

Blue is simulator team A. `my_side` is `B` or `R` as in `ScreenMatch`.

### 1.3 Derived values the arena uses

These are formulas over the table above. No new random numbers.

| Id | Name | Formula |
|---|---|---|
| F1 | Contest triple | `c = contests[k]`. `z = noise[k]`. `x = atanh(clamp(c, -(1-1e-9), 1-1e-9)) - z`. `x` is the edge going into that contest before its own luck (ratings, draft, plan and the lead carried in), `z` is its own luck. Checked: for the four early contests `tanh(x)` equals the noise-free contest to 2e-11. |
| F2 | Size | `Report.margin_word(c)`: narrow below 0.60, clear below 0.97, decisive from 0.97. The sign of `c` times `sgn(side)` says who won. |
| F3 | Contest weights | `fw` = `game_plan_v0.json: final_weights`: top 0.084, mid_lane 0.084, bot 0.084, jungle 0.048, obj_mid 0.105, fight_mid 0.195, obj_late 0.100, fight_late 0.300 (this is also the beat order). These equal `f_phase * w` from `sim_params.json`, so `res.final = sum(fw[k] * c[k])` exactly. |
| F4 | Lead ladder | `L_k = sum over j <= k of fw[j] * c[j]`. `L_8 = res.final`. After jungle it equals `0.30 * early`, after `fight_mid` it equals `0.30 * early + 0.30 * mid`: the same checkpoints `ScreenMatch._reveal` uses for its bar today, so the ladder only adds steps in between. For the game winner W, `l_k = sgn(W) * L_k`. |
| F5 | Lead flip | State `S_k` is +1 if `l_k >= 0.03`, -1 if `l_k <= -0.03`, otherwise the previous state (start 0). A flip happens at beat k when `S_k != S_{k-1}` and `S_{k-1} != 0`. The dead band stops flicker. |
| F6 | Story arc | `close` if `result_word(final)` is narrow. Else `comeback` if `min(l_k) <= -0.12`. Else `stomp` if there is no flip (F5), `min(l_k) >= -0.03` and `result_word(final)` is decisive. Else `steady`. |

On the simulated sample (section 9): arcs are close 26%, comeback 12%, stomp 24%, steady 39%; at least one flip in 55% of games; the game winner loses `fight_late` in 19% of games and loses both objectives in 14%. So "the lead carried the push" and "won the game without the objectives" are ordinary stories, not rare ones, and the vocabulary has a proper beat for each.

### 1.4 The 75 s timeline (fixed)

Windows do not overlap, so the shares add to 100%. Resolve times are the feed stamps and never move.

| Window (s) | Beat | Length (s) | Share | Resolve times inside |
|---|---|---|---|---|
| 0.0 to 4.0 | `opening` | 4.0 | 5.3% | none |
| 4.0 to 21.0 | `lane_phase`: `lane_trade` top, mid, bot and `jungle_play` | 17.0 | 22.7% | top 13.5, mid 15.75, bot 18.0, jungle 20.25 |
| 21.0 to 24.0 | `plan_check` | 3.0 | 4.0% | none (reads `plan_used`) |
| 24.0 to 31.0 | `rotate_stone` (with `tower_break` at 25.0 to 28.0; far-lane heroes start walking earlier, see 2.3) | 7.0 | 9.3% | none |
| 31.0 to 36.5 | `objective_stone` | 5.5 | 7.3% | obj_mid 33.75 |
| 36.5 to 51.0 | `team_fight` mid, then `tower_push` | 14.5 | 19.3% | fight_mid 45.0 |
| 51.0 to 54.0 | `reset` | 3.0 | 4.0% | none |
| 54.0 to 63.0 | `objective_moon` | 9.0 | 12.0% | obj_late 60.0 |
| 63.0 to 71.25 | `team_fight` late | 8.25 | 11.0% | fight_late 71.25 |
| 71.25 to 75.0 | `close_push` (with the two scenery guard towers of the loser falling, 2.3) | 3.75 | 5.0% | Cairn falls at 74.0, hold to 75.0 |

The game clock shown on the scoreboard is `show_time / 75 * Report.game_minutes(res) * 60`, so resolve stamps read like the report ("01:58 Top lane" in the worked example).

Two deliberate choices, settled in section 10: (1) lane beats stay in chronological order, size is shown by tier effects and camera, never by order. (2) Early tower credits fall in the rotation window (25.0 to 28.0 s, about minute 3:40 to 4:10 of an 11 min game), not at the lane resolves (minute 2 to 3).

## 2. Beats

### 2.1 Beat index

**What "tied to a sim trigger" means, plainly.** Of the twelve beat ids (`opening`, `lane_trade`, `jungle_play`, `plan_check`, `rotate_stone`, `tower_break`, `objective_stone`, `team_fight`, `tower_push` with its `tower_dive` variant, `objective_moon`, `reset`, `close_push`): eight read a field of the result directly (`opening`, `lane_trade`, `jungle_play`, `plan_check`, `objective_stone`, `team_fight`, `objective_moon`, `close_push`), two are Derived (`tower_break`, `tower_push`), and **two are Cosmetic with no sim link at all: `rotate_stone` and `reset`**. They exist so the heroes can walk from one place to the next, they carry 13.3% of the 75 s, and nothing in them is ever shown as news. Even inside the eight, some staging is Interpretive (gank or invade, who starts a take) and is marked so in the rows below.

Support levels: **Direct** = the sim output itself says it. **Derived** = a deterministic formula over sim output (section 5). **Interpretive** = a story told from a real output, with the choice rule stated. **Cosmetic** = no sim link at all, never shown as news.

| Beat id | Triggering output | Support | Share of 75 s |
|---|---|---|---|
| `opening` | `res.picks`, `res.style`, plan set | Direct (who, style, plan) | 5.3% |
| `lane_trade` top / mid / bot | `contests.top` / `mid_lane` / `bot` (bot is the duo average) | Direct (winner, size) | inside 22.7% |
| `jungle_play` (gank or invade) | `contests.jungle` plus the lane signs | Direct (winner, size). Gank vs invade: Interpretive | inside 22.7% |
| `plan_check` | `sim.plan_used[B]`, `[R]` | Direct | 4.0% |
| `rotate_stone`, `reset` | none | Cosmetic (movement only) | 9.3% + 4.0% |
| `tower_break` | tower credits of the four early beats (F9) | Derived | inside 9.3% |
| `objective_stone` | `contests.obj_mid` | Direct. "Steal" staging: Interpretive | 7.3% |
| `team_fight` mid | `contests.fight_mid`, `res.style` | Direct (winner, size). Kill order: Cosmetic inside real counts | 19.3% with push |
| `tower_push` / `tower_dive` | tower credits of the fight, `res.style[W]` | Derived. Dive vs siege flavour: Interpretive | inside 19.3% |
| `objective_moon` | `contests.obj_late` | Direct | 12.0% |
| `team_fight` late | `contests.fight_late` | Direct | 11.0% |
| `close_push` | `res.blue_won`, `contests.fight_late` | Direct (winner). `clean_close` vs `lead_carries` is Direct from the signs. The two guard towers falling is Cosmetic (scenery, never counted) | 5.0% |
| overlay `lead_flip` | rule F5 | Derived | no time |
| overlay `upset` | F1: `abs(x) >= 0.8`, sign of x differs from sign of c | Derived | no time |
| overlay `snowball`, `comeback` | arc F6 | Derived | no time |
| overlay `wipe` | all five heroes of one side fall in one fight beat in the kill ledger | Derived | no time |

### 2.2 Look by margin (shared by every beat)

Sizes come from `Report.margin_word`. A loss is the same picture from the other side: your units are on the losing end of the same tier, plus a loss tone (cool edge vignette at 12% opacity for 0.8 s at the resolve moment, feed line in the status-loss colour, no celebratory sound). A decisive loss shows a decisive collapse of your units. We never soften it with a fake near-win. The one place the look of a result is held back is the held fight (section 2.3, `close_push`), and there the result itself is still shown truthfully.

**Colour rule (Founder-level ruling, C4; the Art Director owns every token).** In the arena **you = teal circle, them = coral hexagon**, the same pair as the versus bar. The status-loss colour (`BAD`) means only status and loss tone: the loss vignette, a loss feed line, a lost-lead number. It never marks the opponent's units. Blue side and Red side are never shown as colours in the arena (only as a word plus a flag glyph on Home and the draft board). Every cue also keeps its shape (circle against hexagon, rule H6). This file names roles ("amber", "pale blue", "warm white-gold") as a description of the intent, not as token values; the Art Director maps them to tokens.

| Tier | Lane trade and jungle | Objective | Team fight | Camera and sound |
|---|---|---|---|---|
| Narrow (below 0.60) | Wave stays near the middle (front at most 0.36 of the way to the loser's tower). Both laners above 60% health. A kill only if the ledger has one. Calm. | Progress ring ends within 10% of even. Both sides stay in range. The loser gets one last strike (staging only). | Clash uses the whole window. Both sides keep at least two heroes visible until the last second. Loser retreats at low health. | Steady camera. Short, soft hit sounds. No flash. |
| Clear (0.60 to 0.97) | Wave front at 0.36 to 0.58. Loser laner at or below 65% and stops last-hitting. | Winner takes it with the loser stepping back. | The loser breaks at about 70% of the clash. Winner chases for about 2 s. | Light zoom (5%) toward the winner at resolve. One medium sound. |
| Decisive (0.97 and up) | Wave front at 0.58 to 0.60, at the loser's tower. Loser laner at or below 50% and leaves the lane for 2 s. | Winner takes it with the loser's units gone or retreating. Aura flare. | The loser collapses at about 40% of the clash. A wipe banner if all five of a side's heroes fall (ledger). | 10% zoom, 0.12 s edge flash, big sound. Allowed once per beat. |

Front-loading: the kill times inside a beat's kill window are warped by `u^g` with `g` = 1.0 narrow, 0.8 clear, 0.6 decisive, so decisive beats finish their killing earlier and narrow beats stay open until the end.

Wave front formula for a lane beat: `front = 0.6 * abs(c)`, measured from the centre toward the loser's outer tower, eased in over the beat, so `front = 0.60` is the farthest the clash goes. In map terms the clash point moves from `neutral_s` (0.5) toward the loser by `(front / 0.60) * max_shift_s`, with `max_shift_s` from `arena_map.json` lanes (top 0.15, mid 0.29, bot 0.15 of the arc). A decisive beat therefore ends just in front of the loser's outer tower, which is what the tier table says.

### 2.3 Beat cards

**Ids.** Every place, node and tower below is keyed on `game/data/arena_map.json` (the Level / World Designer's authority; ARENA-MAP.md has the id map). Beat ids (section 2.1) and cue ids (section 3.2) are this file's and did not change. Sim contest ids (`top`, `mid_lane`, `bot`, ...) are the sim's. The key:

| Idea | Map id(s) | Note |
|---|---|---|
| Hero start | node `<side>.spawn.<slot>`, slot in `top jg mid bot sup` | e.g. `B.spawn.top` |
| Lane duel place | zones `top_clash`, `mid_clash`, `bot_clash` | `mid_clash` is the island end of the causeway, node `N.moonhulk`; the sim's `mid_lane` is the map's lane id `mid` |
| Lane waypoints | nodes `<side>.<lane>.gate`, `.1` to `.4`, centres `N.top.mid`, `N.bot.mid` | lane ids `top`, `mid`, `bot` |
| Own jungle | zones `thicket.<side>` and `shallows.<side>` | camps `<side>.w1` to `w3` (Thicket), `<side>.e1` to `e3` (Shallows) |
| Big shared camp and the mid-fight place | node `N.mossback`, zone `mossback_clearing` | |
| Early objective | objective `N.stoneback`, zone `stoneback_pit` | sim contest `obj_mid` |
| Late objective | objective `N.moonhulk`, zone `moonhulk_isle` | sim contest `obj_late` |
| Base | zones `gate.<side>` (Cairn Gate) and `cairn.<side>`; node and objective `<side>.cairn` | |
| Scored towers (12) | `<side>.<lane>.<tier>`, lane in `top mid bot`, tier in `outer inner` | e.g. `B.top.outer`; tower ids name the side that owns the tower |
| **Scenery towers (4)** | `<side>.guard.l`, `<side>.guard.r` | never counted, see F8 |

`B` and `R` in a map id are the simulator's Blue and Red in the canonical map (Blue south). They are not "you" and "them": the arena mirrors the picture so the player's team is at the bottom, and you are teal circles, them coral hexagons, whichever letter you are. W means the side that won the beat's contest, U the other side. Health bars are decoration: a hero's bar reaches zero only at a kill event of the ledger.

#### opening (0.0 to 4.0 s)

Trigger: none (lineups, styles, plans). Heroes rise on their spawn pads (`<side>.spawn.<slot>`) and walk to their zones: top to `top_clash`, mid to `mid_clash`, bot and sup to `bot_clash`, jungler to its own jungle (`thicket.<side>`). The map's validator gives the walks as 7.9, 5.4, 8.8 and 6.6 s, all inside the first contest times. Banners show the two club names. Each side has a style chip from `res.style[side]` (Dive, Siege, Protect, Skirmish). Your side also shows the plan chip (section 4.2). Labels: `open_plan` or `open_free` for you, `style_*` for the opponent.

#### lane_trade (top, mid, bot) (build 4.0 s to resolve, payoff 2.5 s after)

Triggers: `contests.top` (resolve 13.5 s), `contests.mid_lane` (15.75 s), `contests.bot` (18.0 s). The bot contest is the average of bot and support. Spotlight (the region of interest the camera favours) goes to each lane for the 2.25 s ending 0.75 s after its resolve: top 12.0 to 14.25, mid 14.25 to 16.5, bot 16.5 to 18.75. Before 12.0 s the wide view shows all lanes.

| Slot | Winning side W | Losing side U |
|---|---|---|
| top (`top_clash`) | Steps to the lane centre (`N.top.mid`), lands short trades every 1.0 to 1.5 s, last-hits, shoves the wave forward by the front formula | Falls back toward its own outer tower (`<U>.top.outer`), last-hits only in tower range, health bar drops by about `0.5 * abs(c)` |
| mid (`mid_clash`, on the island end of the causeway) | Same as top. Ranged mid heroes poke from range, melee ones short trade | Backs off along the causeway, wave pushed against it |
| bot and sup (duo, `bot_clash`) | Both hold the centre (`N.bot.mid`), sup stands one step behind the carry (mender) or one step ahead (bulwark, binder). Duo trades twice as often | Duo stacks under the tower, carry last-hits at the edge of tower range |
| jg | In the lane phase it is shown only in `jungle_play`. Otherwise clears camps | Same |

Kills: only the ledger's kills for this beat (section 5), using the killer and victim rule P2 in section 5.2. Payoff: a pressure arrow over the lane pointing at U's outer tower (`<U>.<lane>.outer`, lane in `top mid bot`), the wave sitting at the front position, and the feed line. No tower falls here; plates and tower shake are decoration. Tower credits fall in `tower_break`.

#### jungle_play (resolve 20.25 s, build from 12.5 s)

Trigger: `contests.jungle`. Winner side J. Place (map stage `jungle`): `thicket.*`, `shallows.*` and `mossback_clearing`.

Variant choice (Interpretive, deterministic): let `m_L = sgn(J) * c[L]` for lanes top, mid_lane, bot. If any `m_L > 0` then the variant is **gank** into the lane with the largest `m_L` (ties: top, mid, bot). Otherwise **invade**. So a gank is only ever shown into a lane the same side actually won. If the winner's plan has a jungle focus that matches a won lane, that lane is the target.

| Slot | Variant gank | Variant invade |
|---|---|---|
| jg of J | Leaves its jungle (`thicket.<J>` or `shallows.<J>`) at 12.5 s, passes through the jungle edge, appears behind U's laner at about resolve minus 1.5 s with `blink_fade` or `charge_trail`, trades with the lane | Crosses the centre line into `thicket.<U>` or `shallows.<U>` (the big camp `N.mossback` is shared), takes camps (a camp's rim flips to the taker's marker shape and colour, circle or hexagon, never colour alone), then fights the arriving jungler |
| lane hero of J in the target lane | Hits together with the jungler | Keeps farming |
| jg of U | Arrives late along the opposite path with a trail that ends one step short, then retreats | Arrives, loses the trade, is pushed back |
| lane hero of U in the target lane | Takes the damage, retreats or dies per ledger | Keeps farming |

Tier effects: narrow = U's jungler is still in the picture, both sides trade evenly and J wins by a step. Clear = J leaves with about 50% health or more. Decisive = U's jungler leaves the lane picture for the rest of the lane phase. Elig rule for kills in this beat: killer and victim are drawn from J's jungler and the target lane slot first (section 5, P2).

#### plan_check (21.0 to 24.0 s)

Trigger: `res.sim.plan_used[B]` and `[R]`. This is the real moment: `GamePlan.simulate` reads the early result with the default plans and then applies the trigger plan to the mid and late contests only.

| Case | What happens |
|---|---|
| `plan_used[side] == default` | Plan chip pulses once, label `plan_hold`. A dimmed "If behind" chip stays dim (honest: it was not needed) |
| anything else | A banner sweeps across that side in the amber WARN colour for 2.0 s with the existing strings `gp.switch.<id>`. The plan chip swaps to the new plan's top controls. Label `plan_behind`, `plan_ahead` or `plan_vs_*`. Formation shifts by the new plan's `g` (section 4.2) |

For the opponent the banner is smaller and uses the same rule. The opponent's plan controls are not in the result today, so its chip says only "Plan switched" until request S1 is done.

#### rotate_stone and tower_break (24.0 to 31.0 s)

Cosmetic movement plus Derived tower events. All five heroes of each side walk to `stoneback_pit`. Group shape follows the chosen plan's `g`: `g > 0` walks in one tight pack, `g < 0` has top and bot arrive last with their waves still shoving behind them, `g = 0` loose. All five are always present at the pit by 31.0 s, because `obj_mid` is rated on all five slots.

**Walk check (new, from `arena_map.json`).** I ran a shortest-path search over the map's 80 edges at the map's walk speed (0.060 u/s) and rotate speed (1.5 x):

| From | To `stoneback_pit` at walk speed | At rotate speed |
|---|---|---|
| `top_clash` (`N.top.mid`) | 14.4 s | 9.6 s |
| `mid_clash` (`N.moonhulk`) | 10.3 s | 6.8 s |
| `bot_clash` (`N.bot.mid`) | 1.7 s | 1.2 s |
| `mossback_clearing` (`N.mossback`, the jungler) | 12.7 s | 8.5 s |

The validator checks the walk from the Cairn (9.5 s) but not from the lanes. If the top hero leaves at 24.0 s it arrives at 38.4 s at walk speed, which is after the take resolves at 33.75 s. So the staging rule is: heroes leave their lane **when the jungle contest resolves (20.25 s) at the latest**, and the top, mid and jungle heroes walk at rotate speed. Arrivals are then top 29.9 s, mid 27.1 s, jungler 28.8 s, all before 31.0 s. This uses `rotate_mult` on a leg where ARENA-MAP says it is "used only for the Stoneback to Mossback swing"; it needs the Level Designer's confirmation (hand-off 4). The windows in section 1.4 do not change, because the walking is Cosmetic and starts inside the lane phase.

`tower_break`, 25.0 to 28.0 s: ledger tower credits of the lane beats fall here, top at 25.0, mid at 26.5, bot at 28.0. **The shoved minion wave and a `tower_hit_beam` break the tower; no hero does it**, because the heroes are already on their way to the pit (walk check above). Then `tower_crack` and `tower_fall`. Which tower falls is rule F9; the id is `<owner>.<lane>.<tier>`, for example `R.top.outer`.

#### objective_stone (31.0 to 36.5 s) and objective_moon (54.0 to 63.0 s)

Triggers: `contests.obj_mid` (resolve 33.75 s, place `stoneback_pit`) and `contests.obj_late` (resolve 60.0 s, place `moonhulk_isle`). Winner W takes it. The island holds ten tokens only just (radius 76 px), so the Moonhulk fight and take use the 36 px token size (ARENA-MAP). Moonhulk has a longer approach: approach 54.0 to 57.0, take 57.0 to 60.0, payoff 60.0 to 63.0.

Initiator (Cosmetic staging, deterministic): the side whose chosen plan has `m > 0` (Stoneback) or `l > 0` (Moonhulk); else the side whose style is dive; else a coin from the bare `show` stream. The initiator starts the progress ring. If W is not the initiator the staging is a **steal**: the ring flips to W's colour in its last 10%. The winner is always real; only who starts is staging.

| Slot | Winning side W | Losing side U |
|---|---|---|
| jg (weight 0.30 in the contest) | In the pit with the ring: strikes the objective, or `blink_fade` into a steal | Contests: strikes, or knocked back (clear, decisive) |
| sup (0.25) | Beside the jungler: shield or heal (mender), taunt ring (bulwark), tether to hold the enemy jungler back (binder) | Last-ditch shield, then steps back |
| top, mid, bot (0.15 each) | Guard the three approaches, face outward, cast at anyone who steps in | Try to break the guard, get pushed back |

Kills in the beat come from the ledger. Payoff: Stoneback gives W an amber `objective_burst` and a 15 s warm aura (`buff_aura`) plus a gold pop. Moonhulk gives W a pale-blue pulse and an aura that stays to the end of the show. The aura is decoration; it marks who won the contest.

#### team_fight (mid 36.5 to 51.0 s, late 63.0 to 71.25 s)

Triggers: `contests.fight_mid` (resolve 45.0 s, place `mossback_clearing`) and `contests.fight_late` (resolve 71.25 s). Phases for the mid fight: the teams leave the pit when the take resolves (33.75 s, rotate speed), approach 36.5 to 41.2, clash 41.2 to 45.0, payoff 45.0 to 51.0 (chase and `tower_push`). **Changed in this revision:** the clash used to start at 40.0 s. The walk from `stoneback_pit` to the clearing centre is 8.5 s at rotate speed (12.7 s at walk speed), so the teams reach the zone rim at about 41.1 s and the centre at 42.25 s; the kill window of `fight_mid` is now 41.2 to 45.0 (section 5.1). Kill counts do not change. Late fight: approach 63.0 to 66.0, clash 66.0 to 71.25, then `close_push`. Late-fight place when the game winner also wins it: `gate.<U>`, U being the game loser (the map's `fight_late` stage); the island to that gate is 4.8 s at walk speed, so the teams are there by 64.8 s. When the game winner loses it, see the held fight in `close_push`.

Initiator (Cosmetic): a side with style dive if exactly one has it, else the side with the higher chosen-plan `g`, else a coin from `show`. Style decides the opening move of each side, because the style triangle is a real fight input (`style_edge`):

| Style of a side | Opening move |
|---|---|
| dive | Everyone crosses the gap together toward the enemy back line (`charge_trail`) |
| siege | Stops at range, three volleys of poke (`projectile`, `zone_ring`) before anyone commits |
| protect | Forms a ring around the carry, support leads (`shield_bubble`), commits last |
| skirmish | Splits into two groups, one baits and one flanks |

Per slot in the clash (hints only; the ledger decides who falls):

| Slot | Winning side W | Losing side U |
|---|---|---|
| top | Holds the front, takes the first hits, usually still standing at resolve when the tier is clear or better | Fights at the front, falls or retreats first |
| jg | Flanks from the side onto the back line | Arrives late or is caught mid-flank |
| mid | Casts from the second row (zone, volley, tether) | Is collapsed on, or kited out of range |
| bot | Steady fire from behind the front, kite step with each volley | The priority target of W's dive |
| sup | Heal, shield, peel or pull depending on archetype | Last-ditch shield, then retreats or falls |

Kill order and who strikes first: from the ledger and the `show` stream (section 6). A fight beat with more than 5 deaths on one side shows a second round: dead heroes re-enter 1.2 s after death from the lane edge and rejoin (never teleport). Tier shapes: section 2.2 (front-loading `g`, loser collapse points). At resolve the loser's heroes retreat or are gone and the winner's survivors face the enemy base.

`wipe` overlay: if all five heroes of one side are victims inside one fight beat (five different victims in the ledger's pairing), the banner "Team wiped" shows at resolve. Many deaths of fewer heroes (a hero who respawns and falls again) are not a wipe.

#### tower_push and tower_dive (mid fight payoff 45.0 to 51.0 s; late fight payoff 71.25 s on)

Trigger: the tower credits the ledger gives this fight beat (rules F8 and F9). Tower ids are `<owner>.<lane>.<tier>` (12 scored towers per game, six per side). Tower fall times: spread evenly from resolve plus 1.0 s to the end of the payoff (mid 51.0, late 73.8).

| Style of W | Visual |
|---|---|
| dive (and tier clear or decisive) | Heroes enter tower range together, the tower targets one hero, the rest strike (`push_dive`) |
| siege | Stays at the edge of tower range, poke projectiles do the damage |
| protect | Tight group with shields, slow and steady |
| skirmish or narrow tier | Two groups push two lanes |

#### reset (51.0 to 54.0 s)

Cosmetic. Units regroup and walk toward `moonhulk_isle`. If the chosen plan has `t != 0`, label `tempo_scale` or `tempo_push` at 51.5 s. Walk check, same method as `rotate_stone`: from the tower sites of the lane pushes (nearest lane nodes `<side>.top.2` and `.3`, `<side>.mid.1`, `<side>.bot.2` and `.3`) the island is 10.0 to 12.4 s at walk speed and 6.7 to 8.2 s at rotate speed, and from `mossback_clearing` it is 10.3 s (6.9 s). A team that is still pushing a tower at 51.0 s therefore reaches the island at 57.7 to 59.2 s at rotate speed, inside the take (57.0 to 60.0 s) but not at its start. So `reset` is walked at rotate speed, and the Moonhulk take may start with its guards still arriving; the ring is shown from 57.0 s regardless. The map's own check (island from the clearing, 10.3 s of 15.0 s) assumes the team stands at the clearing at 45.0 s and does not cover the tower pushes (hand-off 4).

#### close_push (71.25 to 75.0 s)

Trigger: `res.blue_won` (the game winner W) and the sign of `contests.fight_late`.

| Variant | Condition | Visual |
|---|---|---|
| `clean_close` | W also won `fight_late` | The fight was at `gate.<U>`. W's survivors run straight to the Cairn (`cairn.<U>`); gate to Cairn is 2.3 s at walk speed, so this leg is run at rush speed (2 x walk, 1.15 s) inside the 1.25 s run window |
| `lead_carries` (the **held fight**) | W lost `fight_late` (18.9% of games in the 40,000-match run; 55% of them are close games) | Staged by the held-fight rules HF1 to HF6 below. The visible story is: the last fight went to U, W's lead was bigger than the fight took back, the Cairn falls to W |

Timeline: 71.25 to 72.5 run, 72.5 to 74.0 Cairn cracks (`cairn_crack`), 74.0 Cairn falls (`cairn_fall`), 74.0 to 75.0 victory or defeat hold with the end card. If the ledger has a repair tower (F8) it falls at 73.0. **The two guard towers of U (`<U>.guard.l` at 72.7 s and `<U>.guard.r` at 73.3 s) crumble** (`tower_crack`, `tower_fall`; no `tower_hit_beam`, no gold pop, no scoreboard change): they are scenery, never counted, and fall only here (rule F8). The loser's units defend and die or scatter, never win the match.

**Held fight (C8).** The sim sums three phases, so the match winner can lose the last fight and still win the game. Before `fight_late` the lead for W is `l_7 = final_W + 0.30 * abs(c_fight_late)`, and after it `l_8 = final_W`; both are positive, and the difference is exactly what the lost fight took back (checked on 40,000 matches, invariant I9). In gold: W leads by +6,400 before the fight in the median game and by at least +2,200 in 95% of held fights; at 75 s the lead is +2,500 in the median held fight, under +1,000 in about a fifth of them, and never below +100. If the fight is staged the way the first draft did it (U wins at its own gate, then W's units walk in and break the Cairn), a viewer sees "won the fight, lost the match", which fails the tester question "Results felt fair". The rules:

| # | Rule |
|---|---|
| HF1 | **The result is shown truthfully.** U is the fight's winner, with the size word, kills and feed line of the ledger. The arena adds, removes or moves no kill, death or tower (I9e). The fight is never renamed "a hold" in any text. |
| HF2 | **Place and timing belong to the Level / World Designer's held-fight staging** (ARENA-MAP section 7 and the stage data). Default: the fight is held away from `gate.<U>`, at the island or the mid gate, and W's reserves arrive as "the lead". An alternative staging is allowed; both obey HF1 and HF3 to HF6. Constraints from this file: the Cairn still falls at 74.0 s (F13), and W's units must be at `gate.<U>` in time. Gate to Cairn is 2.3 s at walk speed and island to gate is 4.8 s, so a fight that stays on the island until 71.25 s cannot finish the push by 74.0 s (4.8 + 2.3 = 7.1 s against 2.75 s); the clash has to drift toward the gate in its last seconds, or the staging has to accept the Cairn falling later than 74.0 s in this variant. I did not decide this; it is hand-off 3. |
| HF3 | **"The lead" is the number, not extra units.** Reserves are W's own heroes who fell in this fight, re-entering 1.2 s after death (the second-round rule in `team_fight`), plus ambient minions. They are never additional heroes and never add or remove a kill, death or assist. At 71.25 s the gold lead number steps down by the fight's step and **stays positive and visible**, with `lead_flash` at the same moment; the lead graph for W stays above zero. |
| HF4 | **The look of the result is held back, not changed.** U's win keeps its tier look except: no chase, no zoom toward U, no `edge_flash`, no `buff_aura`, camera stays wide. W's loss keeps its tier look except that its heroes fall back toward their reserves instead of scattering, and the `wipe` banner is not shown for W in this fight (the deaths still are). A wipe of W in the late fight happens in 14% of held fights (52 of 377 in a 2,000-match run). |
| HF5 | **Labels and tags.** At 71.5 s W shows `push_lead` and U shows `def_last`; `push_base` never shows in a held fight. No `lead_flip`, `tag_flip` or `tag_back` is shown at `fight_late` (the lead cannot flip there, see I9b). The end card is the normal Victory card for W; "Play of the game" is never `fight_late`, because its step for W is negative. |
| HF6 | **Both seats.** The same picture is shown whether the player is W or U. If the player is U, the player sees the fight won, then W's `push_lead` and a lead number that explains why the Cairn still falls; no extra string is added. A one-line commentary sentence that says "the lead was bigger than the last fight" is the Narrative Designer's to write (hand-off 5). |

The Technical Designer's prototype of the two stagings on this case and the Founder's tester question decide which staging ships. Neither may break HF1 or I9.

### 2.4 Overlays (no time of their own)

| Overlay | Trigger | What the player sees |
|---|---|---|
| `lead_flip` | rule F5 | The lead number flashes, a marker is added to the lead graph, tag `tag_flip` or `tag_back` |
| `upset` | `abs(x) >= 0.8` and sign of x differs from sign of c | Tag `tag_upset` on the winner's side (about 3% of contests, at least once in 18% of games) |
| `snowball` | arc stomp | Tag `tag_snow` at `fight_mid` resolve; a thin gold trail behind the leading side's heroes |
| `comeback` | arc comeback | `tag_back` at the flip toward the game winner |
| `close` | arc close | Tag `tag_close` at 62.0 s |
| `wipe` | all five heroes of one side fall in one fight beat | Banner "Team wiped" |

An upset is judged on `x`, the edge going in, not on ratings, because the simulation is luck-heavy (in the sample the contest went against the side the edge favoured 37% of the time even when `abs(x) >= 0.4`). So the arena never pre-announces a favourite.

### 2.5 What cannot be shown truthfully, and what the Systems Designer would have to add

| Wanted | Status | What it needs |
|---|---|---|
| Your Game Plan sliders on screen, the opponent's plan, "your plan helped" | **Not available.** `MatchRunner.finish` (match_runner.gd line 49) returns no `plans`. | **S1:** add `"plans": sets` to the result (Blue simulator team A as `B`). Found while reading: `Report.attribution` (report.gd line 78) reads `result.get("plans", {})`, gets `{}`, and re-simulates both sides with neutral plans while `actual = result["final"]` was played with the real plans (and the opponent's coach plan). So today the "why" bars include the plan effect inside the slot and draft bars, and the "Your game plan" bar can never appear. Not run in Godot here (no Godot on this machine); read from the code. Fix independent of the arena. |
| A kill rate that a 75 s show can carry | Works, but busy. `Report.kda` averages 30 kills a game (18 to 41) and in the median game the most-killed hero dies 7 times (about one death every 10 s of the 75 s show) in my 40,000-match prototype. | **S2:** display-only retune of `Report.kda`: for example 1.2 kills per game minute, clamp 10 to 26, and a soft cap of ceil(team deaths / 3) + 1 deaths per hero. Needs a recheck of GDD 9.2 test 6. The vocabulary works with either (second rounds, 1.2 s respawn), the arena only looks calmer with S2. |
| One implementation of the ledger | Not in code yet | **S3:** a pure function `Report.story(res, my_side)` returning the section 5 numbers, owned by the Systems Designer, with the invariants below as unit tests, so the arena, the report and QA share it. The Python check in section 9 can seed it. |
| Reserved stream name | Missing | **S4:** add `show` and `show:<purpose>` to the reserved list in GDD 8.4. |
| Weights match | True today | **S5:** a test that `game_plan_v0.json final_weights` equals `f_phase * w` from `sim_params.json`, because the ledger depends on it. |
| True ganks, true steals, first blood, per-hero damage, gold, items, levels, cooldowns | **Unsupported.** The sim has eight team-level contests and nothing below them. | Not recommended for Alpha 0.8. The arena shows no per-hero gold, level, items or damage numbers. Gank, invade and steal are staged from real contest signs by the rules above. |
| Player intervention (tactical pause) | Unsupported | Needs simulation changes (Founder decision 2 at the checkpoint). |

One more note for the Lead Game Designer: GDD 8.5 says the four lane results fall at 0.25L, while `Report.FEED_ORDER` spreads them over 0.18 to 0.27. This document follows the code. GDD 8.4 describes an outcome seed built from the drafts and plans, while the code uses `res.mseed`. `show` follows whatever root the sim streams use, so a changed draft re-rolls the show together with the result.

## 3. Hero actions

### 3.1 Archetype to action style

Every hero's on-screen behaviour comes from `archetype` and `range` in `game/data/heroes.json`, plus its tags. Range is melee 1 body width of reach, mid 3, long 5 (the Level / World Designer converts to map units). Damage type sets the hit colour: physical warm white-gold, magic violet-teal, mixed alternates both. Shape differs as well as colour (H6): physical hits are sharp sparks, magic hits are soft rings.

| Archetype | Action style | Lane and wave | Fight | Objective and tower | Main cues |
|---|---|---|---|---|---|
| Bruiser (melee, mostly top and jungle) | Brawler: steps in, wide cleave, shoves | Short trades, shoves hard | Second wave in, finishes wounded targets | Strong at tower dive and split push | `slash_arc`, `charge_trail`, `hit_spark` |
| Bulwark (melee, top, support, jungle) | Anchor: shield-bash charge, taunt ring, knock-up | Holds position, soaks | Opens the fight, then holds the front | Holds the entrance, wins pit trades | `charge_trail`, `taunt_ring`, `knock_up`, `shield_bubble` |
| Shade (mid or melee, mid and jungle) | Skulker: vanishes, strikes an isolated target, fades out | Waits for the wave to crash, jabs | Flanks the back line | Steals: `blink_fade` into the ring | `blink_fade`, `slash_arc`, `kill_ping` |
| Spellcaster (long or mid, mid) | Caster: ground zones, volleys, wave sweeps | Clears waves with sweeps, pokes | Second row, zones the front | Poke on towers from range | `wave_sweep`, `zone_ring`, `projectile` |
| Binder (mid or long, support and mid) | Weaver: tether line, snare, pull | Hooks a wandering laner | Catches a single target, holds it | Holds the enemy jungler off the ring | `tether_line`, `root_ring`, `projectile` |
| Gunner (long, bot) | Marksman: steady stream, kite step | Last-hits with ranged shots | Back-line damage, steps back with each volley | Tower damage from range | `projectile`, `hit_spark`, kite step |
| Mender (mid or long, support) | Warden: heal pulses, shield bubbles | Stays with the carry | Heals, shields, peels | Shields the jungler at the ring | `heal_pulse`, `shield_bubble` |

Tag modifiers, added on top of the archetype style:

| Tag | Effect on screen |
|---|---|
| Poke | Three volleys before the clash starts (siege opening) |
| Engage | Leads the cross of the gap (`charge_trail`) |
| Pick | Prefers an isolated enemy as a target hint (`blink_fade`, `tether_line`) |
| Protect | Keeps a shield or heal on the lowest-health friend |
| Splitpush | In `rotate_stone` with `g < 0` it is the one that stays in its lane |
| Waveclear | Sweeps minion waves in the lane phase (`wave_sweep`) |
| Frontline | Stands in front; hit flash is smaller |
| Scaling | Effects grow with the phase (next rule) |

Effect size (Cosmetic, from data): `effect_scale(phase) = clamp(0.8 + 0.4 * (power_phase - 40) / 22, 0.8, 1.2)` where `power_phase` is `power_early`, `power_mid` or `power_late` of the hero (data range 41 to 61). A late-power hero shows bigger effects in the late fight. It is never used for an outcome.

Signature choice: each hero uses one of the three main cues of its archetype as its signature, picked by `fnv1a64(hero id) mod 3`. No stream is used, so it is always the same for a hero. The Technical Designer can store it in a data file later (`heroes_show.json`).

Hints, never overrides: where a table says "usually" or "prefers", the visual layer follows it only when it agrees with the ledger. The hero the ledger kills is the hero that falls.

### 3.2 Effect cues for the VFX Artist

Tier 1 must exist on a low-end phone. Tier 2 should. Tier 3 is dropped first when the frame budget is tight (the Engine / Graphics Programmer sets the budget and the number of live cues; suggested cap 12). Every cue has a shape that works without colour.

| Cue id | Kind | Used for | Look | Length (s) | Tier |
|---|---|---|---|---|---|
| `hit_spark` | contact | Any basic hit | Sharp spark (physical) or soft ring (magic) | 0.2 | 1 |
| `slash_arc` | contact | Melee swing | Crescent trail in front of the hero | 0.25 | 1 |
| `projectile` | projectile | Long and mid range hits | Bolt or streak, 2 sizes | 0.3 | 1 |
| `zone_ring` | area | Spellcaster zone | Ground ring that pulses twice | 0.8 | 2 |
| `wave_sweep` | area | Wave clear | Wide crescent across the lane | 0.4 | 2 |
| `charge_trail` | mobility | Engage lunge, dive | Speed lines behind the hero | 0.4 | 2 |
| `taunt_ring` / `knock_up` | control | Bulwark | Expanding ring, then a small hop of the target | 0.5 | 2 |
| `blink_fade` | mobility | Shade steal and gank | Hero fades to a shimmer, reappears with a flash | 0.5 | 2 |
| `tether_line` | control | Binder | Bright thread between two heroes | 0.8 | 2 |
| `root_ring` | control | Binder snare | Ring on the ground at the target | 0.6 | 3 |
| `shield_bubble` | support | Mender, bulwark | Translucent bubble, hexagon edge | 1.0 | 2 |
| `heal_pulse` | support | Mender | Rising plus-shaped pulses | 0.6 | 2 |
| `kill_ping` | event | Every kill | Killer flash, "+gold" text, tiny skull mark | 0.6 | 1 |
| `death_dissolve` / `respawn_rise` | event | Death and respawn at base | Dissolve into motes; rise from the fountain | 0.5 / 0.6 | 1 |
| `tower_hit_beam` | structure | Tower damage | Thin beam, spark at the tower | 0.4 | 1 |
| `tower_crack` / `tower_fall` | structure | Tower credit | Cracks spread, then the tower collapses into dust | 0.6 / 0.9 | 1 |
| `objective_burst` | event | Stoneback (amber), Moonhulk (pale blue) | Burst ring from the pit | 0.8 | 1 |
| `buff_aura` | event | Winner of an objective | Soft glow ring under the winning team | 15.0 / to end | 2 |
| `cairn_crack` / `cairn_fall` | structure | Finale | Core cracks, then breaks into light | 1.5 / 1.0 | 1 |
| `plan_switch_sweep` | UI | `plan_check` | Amber band sweeps across a side's banner | 2.0 | 1 |
| `lead_flash` | UI | Lead flip | The gold number flashes and the graph marker pops in | 0.6 | 2 |
| `intent_ping` | UI | Each intent label | A ring on the target zone with a line to the label | 2.5 | 1 |
| `edge_flash` | UI | Decisive resolve | 0.12 s flash at the screen edge | 0.12 | 3 |

## 4. Intent labels and the Game Plan on screen

### 4.1 Rules

| # | Rule |
|---|---|
| R1 | 28 characters or fewer after filling placeholders (`{lane}` counts as 3, `{hero}` as 11). All 156 lines were measured: the longest is 26 characters. |
| R2 | A label states a posture or decision ("Going for Stoneback"). It never states or predicts a result. A side that attempts and fails still told the truth. Four lines that predicted a result ("win later", "late wins", "No stopping them", "One fight decides it") were reworded, and "Big lead, safe push" was reworded because the lead at 75 s is under 1,000 gold in about a fifth of held fights (section 2.3). |
| R3 | One label per side at a time, on screen 2.5 s (1.25 s at 2x speed), shown as a pill on that side's banner with an `intent_ping` at the target zone. Windows are fixed (the table below) so two labels of one side never collide. |
| R4 | Variant choice is order independent: for each (intent, side) pair there is a stream `show:label:<intent>:<side>`. The k-th use in a match draws the k-th value, `v = u mod 3`, and if it equals the previous variant of that pair it becomes `(v + 1) mod 3`. Adding a label elsewhere never shifts another. |
| R5 | A plan label shows only when the matching control of the plan in force is non-zero. "Taking a big risk" never shows when `r` is 0. |
| R6 | Wording that reads correctly on either banner. A label sits on one side's banner, so "their" and "them" always mean the other side, and "it" means the thing the line names (the objective, the plan, the game, or an idiom such as "Playing it by ear"). "You", "your" and "we" appear only in lines shown to the player's own side alone, which today is only `open_plan`. (The first version of this rule said "no pronouns"; that was false for 17 lines. I changed the rule, not the lines, because those lines read correctly on both banners. Three of the 17 were also replaced for another reason, see R2.) |
| R7 | Until request S1 is done the opponent's labels use style, jungle and lane context only. |
| R8 | Precedence when two rules fit (highest first): plan switch, plan control, objective role, style, lane or fallback. |

Label windows (show seconds): opening 0.5 to 3.0. Lanes: top 5.0, mid 7.5, bot 10.0 (2.5 s each). Jungle action 12.5. Plan check 21.2. Rotation 24.2. Stoneback 31.0. Mid fight 37.0. Mid push 46.0 (only after the mid fight; the late fight has no separate push label). Tempo 51.5. Late rotation 54.5. Moonhulk 57.0. Late fight 63.5. Close 71.5 (game winner and loser). Tags at the resolve time of their beat.

### 4.2 The player's Game Plan on screen

| Element | Rule |
|---|---|
| Plan chip (under your banner, always visible) | The up to three most important parts of the plan in force: non-zero sliders sorted by `abs(value)` (ties in the order g, t, m, l, a, s, r), then the jungle focus lane if set. Names are the Game Plan screen's own: Fight style, Tempo, Mid-game objectives, Late objectives, Lane aggression, Support, Risk, Jungle focus. Direction words are the screen's own (Group up, Spread out, Scale, Push early, Contest them, Ignore them, Secure them, Fight first, Aggressive lanes, Cautious lanes, Roams, Stays with the carry, Take risks, Play safe). Example: "Group up, Contest them, Jungle: Top". No sliders set: "Plan: neutral". |
| "If behind" chip | Shown next to the plan chip only if the player's set has a trigger plan. It lists that plan's top two parts and stays dim until `plan_check`. |
| The switch | At 21.0 s, if `plan_used[my_side] != default`: the amber banner (`plan_switch_sweep`) with the existing line `gp.switch.<id>`, the plan chip swaps to the trigger plan's parts, the "If behind" chip lights up and then replaces the first chip for the rest of the show. A label from `plan_behind`, `plan_ahead` or `plan_vs_*` shows. If it is `default` the "If behind" chip fades and a `plan_hold` label shows. |
| Effect on units | Only from the mid and late contests on, because the switch only changes those hooks. `g` changes the rotation shape and `fight_group`; `m` and `l` change the objective label; `r` changes the fight label; `t` the tempo label; `jf` the jungle focus label; `s` the support label in the bot lane. |
| What is not claimed | The arena says what the plan was and when it switched. It does not say the plan decided the game. After S1, if `Report.attribution` has a `plan` factor with a share of 3% or more, the end card adds "Your plan helped" or "Your plan cost you" from that factor. |

### 4.3 Label catalogue

**Opening, 0.5 to 3.0 s**

| Id | Shown when | Variant 1 | Variant 2 | Variant 3 |
|---|---|---|---|---|
| `open_plan` | Your side, when the default plan is not neutral (`GamePlan.is_neutral` false) | Plan is set, here we go | Following your game plan | Plan locked in, coach |
| `open_free` | Your side, when the plan is neutral | Playing it by ear | Reading the game first | No plan, just instincts |
| `style_dive` | Opponent side only (your style shows as a chip), `res.style[side] == dive` | Looking to dive in | Dive draft, strike fast | Engage and punish |
| `style_siege` | Same, `res.style[side] == siege` | Poke first, siege later | Siege draft: patience | Chip them from range |
| `style_protect` | Same, `res.style[side] == protect` | Protect the carry | Shields and patience | Late-game insurance |
| `style_skirmish` | Same, `res.style[side] == skirmish` | Flexible, skirmish draft | Ready for anything | Mixed draft, stay loose |

**Lanes, 5.0 to 14.5 s (one lane per 2.5 s slot: top 5.0, mid 7.5, bot 10.0)**

| Id | Shown when | Variant 1 | Variant 2 | Variant 3 |
|---|---|---|---|---|
| `jg_focus` | Side whose active plan has `jf` equal to this lane (replaces the lane label) | Jungler leans {lane} | Jungle helps {lane} | Plan: jungle to {lane} |
| `lane_aggr` | Side whose active plan has `a` > 0 | Trading hard in {lane} | Aggressive in {lane} | Fighting for {lane} |
| `lane_safe` | Side whose active plan has `a` < 0 | Playing {lane} safe | Cautious in {lane} | Waiting for the jungler |
| `lane_counter` | Side with `team.lane_mod[lane] > 0` (draft counter). Bot lane only checks `bot` | Matchup edge in {lane} | Draft counter in {lane} | Counter pick, lean in |
| `lane_roam` | Bot slot only: plan `s` > 0 | Support leaves bot | Support roams early | Support goes exploring |
| `lane_stay` | Bot slot only: plan `s` < 0 | Support stays with carry | Duo lane stays tight | Support guards the carry |
| `lane_calm` | Fallback | Farming under tower | Last hits, no risks | Sizing up the lane |

**Jungle action, 12.5 to 15.0 s**

| Id | Shown when | Variant 1 | Variant 2 | Variant 3 |
|---|---|---|---|---|
| `jg_gank` | Side that won `contests.jungle` and won at least one lane (target = its best lane margin) | Jungler ganks {lane} | Gank on {lane} lane | Jungler crashes {lane} |
| `jg_invade` | Side that won `contests.jungle` and won no lane | Invading their camps | Stealing moss camps | Counter-jungle time |
| `jg_farm` | Side that lost `contests.jungle` | Clearing moss camps | Camps first, lanes next | Farming the jungle |

**Plan check, 21.2 to 23.7 s**

| Id | Shown when | Variant 1 | Variant 2 | Variant 3 |
|---|---|---|---|---|
| `plan_hold` | `sim.plan_used[side] == default` | Plan holds, stay calm | No change, same plan | Reading the game |
| `plan_behind` | `plan_used[side] == behind_early` | Behind: Plan B is on | Switching to the backup | New plan, fresh start |
| `plan_ahead` | `plan_used[side] == ahead_early` | Ahead: press the lead | Lead plan switched on | Cashing in the lead |
| `plan_vs_dive` | `plan_used[side] == vs_dive` | Switching vs their dive | Countering the dive | Dive plan is on |
| `plan_vs_siege` | `plan_used[side] == vs_siege` | Switching vs their siege | Countering the siege | Siege plan is on |
| `plan_vs_protect` | `plan_used[side] == vs_protect` | Switching vs protect | Countering the shields | Protect plan is on |

**Rotation and tempo**

| Id | Shown when | Variant 1 | Variant 2 | Variant 3 |
|---|---|---|---|---|
| `rot_group` | 24.2 s, chosen plan `g` > 0 | Grouping up as five | All five heading mid | Walking together |
| `rot_split` | 24.2 s, chosen plan `g` < 0 | Staying spread out | Lanes keep pushing | Split up, hold lanes |
| `rot_pit` | 24.2 s, `g` = 0 | Moving to the objective | Rotating to the pit | Heading for Stoneback |
| `rot_late` | 54.5 s, both sides | Heading for Moonhulk | Rotating to Moonhulk | Regroup at Moonhulk |
| `tempo_scale` | 51.5 s, chosen plan `t` > 0 | Scaling for late game | Farm now, fight later | Patience, late power |
| `tempo_push` | 51.5 s, chosen plan `t` < 0 | Pushing the early pace | Speed up, snowball | No time to waste |

**Objectives (Stoneback 31.0 s, Moonhulk 57.0 s)**

| Id | Shown when | Variant 1 | Variant 2 | Variant 3 |
|---|---|---|---|---|
| `obj_plan_pos` | Chosen plan `m` > 0 (Stoneback) or `l` > 0 (Moonhulk); wins over the next two rows | Plan: secure objectives | Objectives come first | Objective is the plan |
| `obj_plan_neg` | Chosen plan `m` < 0 or `l` < 0 | Fight now, objective later | Ignoring the objective | Fight first, then take |
| `obj_start_mid` | Initiator side of Stoneback (rule in section 2.3) | Starting Stoneback | Going for Stoneback | Taking Stoneback now |
| `obj_cont_mid` | The other side | Contesting Stoneback | Looking to steal it | Making them hurry |
| `obj_start_late` | Initiator side of Moonhulk | Starting Moonhulk | Going for Moonhulk | Taking Moonhulk now |
| `obj_cont_late` | The other side | Contesting Moonhulk | Looking for a steal | Delaying the take |

**Fights (mid 37.0 s, late 63.5 s)**

| Id | Shown when | Variant 1 | Variant 2 | Variant 3 |
|---|---|---|---|---|
| `fight_risk` | Chosen plan `r` > 0 (first in precedence) | Going all in | High risk, high reward | Taking a big risk |
| `fight_safe` | Chosen plan `r` < 0 | Playing it safe | Waiting for mistakes | No risky plays |
| `fight_group` | Chosen plan `g` > 0 (after `r`) | Fighting as one unit | Five together, no gaps | Stick close, fight tight |
| `fight_dive` | `res.style[side] == dive` (after plan labels) | Diving the back line | Jumping on the carry | Everyone goes in |
| `fight_siege` | `siege` | Poking from range | Softening them up | Chip damage first |
| `fight_protect` | `protect` | Peeling for the carry | Shields up, hold tight | Holding the line |
| `fight_skirmish` | `skirmish` | Looking for a pick | Circling for a catch | Skirmish, stay loose |
| `fight_hold` | Non-initiator side with no plan or style label left | Standing their ground | Backing off to regroup | Looking for an answer |

**After fights and the close**

| Id | Shown when | Variant 1 | Variant 2 | Variant 3 |
|---|---|---|---|---|
| `push_tower` | 46.0 s, side with a tower credit on `fight_mid` | Pushing the tower | Siege on their tower | Taking the outer tower |
| `push_dive` | Same, its style is `dive` and the fight tier is clear or decisive (replaces push_tower) | Diving under the tower | Tower dive, no fear | Dive and delete |
| `push_base` | 71.5 s, game winner, clean close (it also won `fight_late`) | Pushing for the Cairn | The Cairn is open | Everyone to the Cairn |
| `push_lead` | 71.5 s, game winner lost `fight_late` (held fight, lead carries, section 2.3) | Lead carries the push | Ahead, pushing on | Pushing with the lead |
| `def_last` | 71.5 s, game loser (also when it won `fight_late`) | Defending the Cairn | Last stand at the Cairn | Holding on at the Cairn |

**Status tags (centre of the screen, 2.0 s, at the beat's resolve time)**

| Id | Shown when | Variant 1 | Variant 2 | Variant 3 |
|---|---|---|---|---|
| `tag_upset` | Beat winner had `x` of the wrong sign with `abs(x)` >= 0.8; tag goes to the winner's side | Against the odds! | Nobody saw that coming | The underdog strikes |
| `tag_flip` | Lead flips (rule F5) and it is not a comeback flip | The lead changes hands | Turning point | Momentum swings |
| `tag_back` | Lead flips to the game winner and the arc is comeback (replaces tag_flip) | Comeback is on | Back from behind | Never out of it |
| `tag_snow` | Arc is stomp: at `fight_mid` resolve | Snowball rolling | Ahead and pressing | Pressure everywhere |
| `tag_close` | Arc is close: at 62.0 s, before the last fight | Anything can happen | Still level, still tense | Neck and neck |


## 5. Scoreboard rules

The scoreboard shows clock, kills, towers, the two objectives, gold lead, and a thin lead graph with a marker per beat. Everything is derived. Notation: `c_k` the eight contests in the order of F3, `L_k` the lead ladder of F4, `s_X` = +1 for Blue and -1 for Red, W the game winner, U the other side, `fw` the contest weights.

### 5.1 Formulas

| Id | Rule |
|---|---|
| F7 | Gold lead for side X after beat k: `G = 100 * round(200 * s_X * L_k)` (the lead of F4 times 20,000 gold per 1.00, rounded to 100). The step for beat k eases in with smoothstep over the 2.0 s starting at that beat's resolve time. Sign guard: at 75 s, if the rounded lead is 0 but `final != 0`, show +100 for W (this happens in 0.45% of games). |
| F8 | Pressure and tower totals: `P_X = sum over k of fw[k] * max(0, s_X * c[k])`. Identity: `P_B - P_R = res.final`. Towers destroyed by X: `T_X = min(6, round(8 * P_X))`. **The scoreboard counts six towers per side: the outer and the inner tower in each of the three lanes (ids `<side>.<lane>.outer` and `<side>.<lane>.inner`, lane in `top mid bot`).** The map has eight towers per side; the other two, `<side>.guard.l` and `<side>.guard.r` at the gate, are **scenery**: they are never counted in `T_X`, never in a tower credit, never in the tower line of the scoreboard or the report, and they fall only in the closing push (the loser's pair crumbles at 72.7 and 73.3 s, section 2.3). Ruling C5. Ordering repair: if `T_W <= T_U` then `T_W = T_U + 1`; if that exceeds 6 then `T_W = 6` and `T_U = 5`. The repair tower (needed in 11% of games) falls during `close_push` at 73.0 s ("the push takes a tower on the way"). |
| F9 | Tower placement: split `T_X` (minus the repair tower) over the beats by Hamilton's method with weights `fw[k] * max(0, s_X * c[k])` (the jungle beat gets weight 0, because no lane tower belongs to it). Hamilton: quota `q_i = N * w_i / sum(w)`, take floors, give the remaining units to the largest fractional parts, ties to the earlier beat; if the sum of weights is 0, all go to the first beat. Lane of each tower (lane keys here are the sim's `top`, `mid_lane`, `bot`; the tower id uses `top`, `mid`, `bot`): for a lane beat, that lane first. For other beats, the lanes sorted by X's lane margin `s_X * c[lane]` descending. After each tower the lane goes to the back of the order. Tier: outer first, then inner. Times: lane beats in `tower_break` (25.0, 26.5, 28.0 for top, mid, bot); objective beats at resolve plus 2.0 s, plus 1.2 s each further; fight beats spread from resolve plus 1.0 s to the end of the payoff; repair tower at 73.0 s. |
| F10 | Kill totals: `K_X = Report.kda(res).team[X].k`. Never recomputed. Report guarantees `K_W > K_U`, and `K_U` kills are `W`'s deaths. |
| F11 | Kill placement: each side's kills are split over nine beats (the eight contests plus `base_push`) by Hamilton with weights `KP[k] * (1 + 0.8 * s_X * c[k])`, where `KP` is top 0.6, mid_lane 0.6, bot 0.9, jungle 0.7, obj_mid 1.0, fight_mid 3.0, obj_late 1.2, fight_late 4.0, base_push 0.5. For `base_push` the margin term is +0.5 for W and -0.5 for U. Fight rule: in both fights the winner must have at least as many kills as the loser. If not, move one kill of the winner from its non-fight beat with the most kills into the fight, else move one kill of the loser out of the fight into any other beat, repeating (at most 40 moves). Needed in 1.1% of games. |
| F12 | Objectives: Stoneback to the side with `s_X * c[obj_mid] > 0`, Moonhulk to the side with `s_X * c[obj_late] > 0`. The tally is exactly that, no repair. The game winner can lose both (14% of games), and the staging then shows why the game was still won (the fights). |
| F13 | The Cairn (`cairn.<U>`) falls at 74.0 s to W. No other beat can end the game. The two guard towers of U fall at 72.7 and 73.3 s, are scenery, and change no number on the scoreboard. |

Kill windows (each ends at the beat's resolve time, so a beat's kills are complete when it resolves): top 8.0 to 13.5, mid_lane 9.5 to 15.75, bot 11.0 to 18.0, jungle 13.0 to 20.25, obj_mid 31.5 to 33.75, fight_mid 41.2 to 45.0, obj_late 57.0 to 60.0, fight_late 66.0 to 71.25, base_push 71.5 to 74.0.

### 5.2 Per-hero pairing (who kills whom)

`Report.kda` gives, for each of the ten heroes, kills `k` and deaths `d` (and assists `a`). The arena uses them as hard totals and plays only the pairing.

| Step | Rule |
|---|---|
| P1 | Each beat has `n` kill events for each side (F8). Event times: draw `u` from `show:timing`, place the j-th of `n` at `window_start + len * ((j + u) / n)^g` (g from section 2.2), sort, then shuffle which side takes which time slot with `show:timing` (Fisher-Yates). |
| P2 | Killer and victim: candidates are the heroes of the right side with kills (or deaths) remaining. Prefer the beat's own slots (top lane beat: top; mid lane: mid; bot: bot and sup; jungle beat with a gank: the jungler and the target lane slot; other beats: any). Pick by weight = remaining count, drawing from `show:pair`. If the preferred set is empty, use any hero with remaining counts. |
| P3 | Victim comfort: avoid a victim who died less than 2.0 s ago or already twice in this beat, unless no other hero has deaths left. |
| P4 | Because the totals of kills and deaths are equal, every event can be filled. After the last event all remaining counts are zero (tested). |
| P5 | Assists are not played event by event. The scoreboard shows team kills only. Per-hero lines (K/D/A) appear on the end sheet and equal `Report.kda` exactly. |

### 5.3 End card and tie-out with the report

| Item | Rule |
|---|---|
| Result | Victory or defeat, the margin word `Report.result_word(final)`, the length as the report shows it. |
| Decided by | Computed once at show start (`Report.attribution` runs about a dozen re-simulations) and cached for the report. Same ordering as `ScreenReport._why`: for a win, the largest positive factor of `Report.attribution`, text `factor.<id>`; for a loss, the largest negative factor. The strings are the report's own, so the arena and the report say the same thing. When Luck is the biggest, say so. |
| Play of the game | The beat with the largest step for the winner: `argmax over k of s_W * fw[k] * c[k]`. Its name and stamp come from the feed event, so the report's Key moments list shows the same line. |
| Final numbers | Kills equal the team lines of `Report.kda`. Towers: `T_W > T_U`. Gold lead at 75 s equals `100 * round(200 * abs(final))`. |

### 5.4 Invariants (each is a test)

| Id | Statement |
|---|---|
| I1 | `L_8 = res.final` within 1e-9, and `P_B - P_R = res.final` within 1e-9. |
| I2 | Gold lead of the game winner at 75 s is positive. |
| I3 | Kills per side equal `Report.kda` team kills, and the winner has more. |
| I4 | Per-hero kills and deaths from the events equal `Report.kda` per hero. |
| I5 | `T_W > T_U`, both at most 6, and the placed towers add up to `T`. Every placed tower id is one of the 12 scored tower ids of `arena_map.json`; a guard tower id (`*.guard.l`, `*.guard.r`) is never placed, never counted, and falls only inside `close_push`. |
| I6 | The objective tally equals the signs of `obj_mid` and `obj_late`. |
| I7 | In each fight the contest winner has at least as many kills as the loser. |
| I8 | Every size word and result word in the arena is the output of `Report.margin_word` and `Report.result_word`. |
| I9 | **Held fight.** Whenever the game winner W loses `fight_late` (18.9% of games): (a) `l_7 > l_8 > 0` and `l_7 - l_8 = 0.30 * abs(c_fight_late)` within 1e-9, so W is ahead before the fight and after it, and the fight took back only part of the lead; (b) no lead flip exists at `fight_late`, so no `tag_flip` or `tag_back` can show there; (c) the label of W at the close is `push_lead` (never `push_base`) and the label of U is `def_last`; (d) the gold lead of W is positive before the fight and at 75 s (it is the sign-guarded F7 number); (e) the staging adds no kill, death or tower: the events in every beat equal the ledger's counts per side; (f) the match is still won by W with the Cairn at 74.0 s (F13). Where W wins `fight_late` the close label is `push_base`. Not simulated here, to be tested on stage data: in the held case the `fight_late` zone is not `gate.<U>` unless the Level Designer's staging says so. |

### 5.5 Worked example

The numbers come from running `tools/sim_core.py` (the reference the Godot simulator is tested against) on a synthetic pair of teams, with the two-pass Game Plan logic of `game_plan.gd` re-implemented in Python, seed `9477814822553415875`. The hero names are overlaid from HERO-SET-v0 for readability (Blue: Skarrow top, Nimbrel jungle, Ellowen mid, Harkin bot, Corvane support, style Siege; Red: Dunmarrow, Gravenstone, Dusken, Sparrowe, Alderwyn, style Skirmish). In the game they come from `res.picks`. You are Blue. Your default plan is Group up 50, Contest objectives 50, Jungle focus Top. Your "if behind" plan is Group up 100, Secure late objectives 50, Take risks 50. Red plays neutral.

| Contest | Stamp (clock) | c (you) | Size | z | x | Step `fw*c` | Lead L | Gold lead |
|---|---|---|---|---|---|---|---|---|
| top | 13.5 s (01:58) | +0.995 | decisive win | +2.79 | +0.21 | +0.0836 | +0.0836 | +1,700 |
| mid_lane | 15.75 s (02:18) | -0.983 | decisive loss | -2.89 | +0.50 | -0.0826 | +0.0010 | +0 |
| bot | 18.0 s (02:38) | -0.973 | decisive loss | -2.28 | +0.13 | -0.0817 | -0.0808 | -1,600 |
| jungle | 20.25 s (02:58) | -0.943 | clear loss | -2.44 | +0.67 | -0.0453 | -0.1260 | -2,500 |
| obj_mid | 33.75 s (04:57) | +0.489 | narrow win | +0.21 | +0.32 | +0.0514 | -0.0747 | -1,500 |
| fight_mid | 45.0 s (06:36) | +1.000 | decisive win | +7.70 | +0.34 | +0.1950 | +0.1203 | +2,400 |
| obj_late | 60.0 s (08:48) | -0.965 | clear loss | -2.88 | +0.86 | -0.0965 | +0.0238 | +500 |
| fight_late | 71.25 s (10:27) | +0.989 | decisive win | +1.59 | +1.01 | +0.2968 | +0.3206 | +6,400 |

Checks. `early = -0.4201` is below -0.40, so your "if behind" plan fires (`plan_used = {B: behind_early, R: default}`). Final = +0.3206 = L_8, a clear win. Arc: not close, `min(l) = -0.126` is at or below -0.12, so **comeback**. Flips: at bot (you lose the lead) and at fight_mid (you take it back). Upset: obj_late has `x = +0.86` in your favour and you lost it decisively, so Red gets `tag_upset`. Game length 11.01 minutes.

Pressure: `P_B = 0.6267`, `P_R = 0.3061`, difference 0.3206 = final. Towers: `T_B = round(8 * 0.6267) = 5`, `T_R = round(2.449) = 2`. No repair. Placement over the nine beats: Blue [top 1, fight_mid 2, fight_late 2], Red [mid_lane 1, obj_late 1]. Kills: `Report.kda` gives 16 for you, 9 for Red (total 25). Hamilton placement over the nine beats (top, mid_lane, bot, jungle, obj_mid, fight_mid, obj_late, fight_late, base_push): you [1, 0, 0, 0, 2, 5, 0, 7, 1], Red [0, 1, 2, 1, 1, 1, 2, 1, 0]. The fight rule held with no repair. Objectives: Stoneback to you, Moonhulk to Red (1 to 1).

Per hero totals from `Report.kda` and from the played events (equal): Skarrow 5 / 1, Nimbrel 4 / 1, Ellowen 3 / 2, Harkin 3 / 4, Corvane 1 / 1; Dunmarrow 5 / 8, Gravenstone 3 / 2, Dusken 0 / 3, Sparrowe 1 / 3, Alderwyn 0 / 0. Dunmarrow's 8 deaths are the reason for request S2: he falls four times in the late fight, which the comfort rule (P3) cannot avoid once the other Red heroes have no deaths left.

## 6. Randomness

The arena owns one stream family named **`show`**, seeded the same way as the contest streams: `Pcg32.contest_stream(res.mseed, name)`. Names do not collide with `top`, `mid_lane`, `bot`, `jungle`, `obj_mid`, `fight_mid`, `obj_late`, `fight_late`, `length`, `kda` or any reserved prefix in GDD 8.4 (request S4 adds `show` to that list). A stream has its own state, so using it never consumes or alters a simulation stream.

| Stream | Used for |
|---|---|
| `show` | Header draws: who initiates each objective and fight when plan and style do not decide it (two coins for the objectives, then one per fight), which hero of a side strikes first in a fight among those the ledger allows |
| `show:pair` | Killer and victim choice (P2) |
| `show:timing` | Kill times and slot order (P1) |
| `show:path` | Small path jitter: lateral offset of at most 0.35 of a hero's radius, from eight pre-drawn points per hero per beat, interpolated smoothly |
| `show:label:<intent>:<side>` | Wording variant (R4) |

Rules that keep it deterministic:

1. All draws happen once, when the show script is built, before the first frame. Playback only reads the script. Frame rate, 2x speed and Skip cannot change a draw.
2. No use of Godot's own `randf`, `randi` or `randomize`, no time of day, and no physics result decides anything. Hero positions are pure functions of show time and the script, so a skipped or sped-up show lands in the same final state.
3. Events fire when show time crosses their stamp (`while next_event.time <= T`), the way `ScreenMatch` already reveals feed lines.

What `show` may vary: wording variant, killer and victim pairing inside the ledger's counts, kill times inside their windows, who starts a take or a fight, small path jitter, which camp is stolen. What it may never vary: the number of kills, towers or objectives, who wins any beat, the gold lead, the kill and death totals, the resolve times, the winner.

## 7. Example timeline (the match of section 5.5, 75 s)

Blue is you. Score is kills Blue to Red, towers Blue to Red, objectives (Stoneback, Moonhulk) Blue to Red, then your gold lead after the step that starts on that row has settled (2 s later).

| Time | Beat | What the player sees | Label | Score after |
|---|---|---|---|---|
| 0.0 | opening | Ten heroes rise at their bases and walk out. Plan chip: "Group up, Contest them, Jungle: Top". Style chips: Siege (you), Skirmish (Red) | You: "Following your game plan". Red: "Mixed draft, stay loose" | 0-0, 0-0, 0-0, +0 |
| 5.0 | lane_phase | Lanes meet. Nimbrel (jungler) drifts toward the top lane | You: "Plan: jungle to Top" | same |
| 9.8 | lane_trade top | Skarrow lands the first kill on Dunmarrow, wave starts to lean to Red's tower | | 1-0, 0-0, 0-0, +0 |
| 12.5 | jungle_play | Gravenstone (Red jungler) leaves the jungle toward mid | Red: "Jungler ganks Mid" | same |
| 13.5 | lane_trade top resolves | Decisive win: wave crashes into Red's top tower, Dunmarrow leaves the lane. Feed: "Top lane: you win it (decisively)" | | 1-0, 0-0, 0-0, +1,700 |
| 14.06 | jungle_play gank | Gravenstone arrives behind Ellowen and kills him | | 1-1 |
| 15.75 | mid_lane resolves | Decisive loss: the Red wave sits at your mid tower | | 1-2, 0-0, 0-0, +0 |
| 18.0 | bot resolves | Decisive loss: your duo is under its tower. Red also kills Ellowen (16.5, second gank) and Harkin (17.4) | | 1-4, 0-0, 0-0, -1,600 |
| 20.25 | jungle resolves | Clear loss: Nimbrel is a step late everywhere; the lead graph is at its lowest | | 1-4, 0-0, 0-0, -2,500 |
| 21.0 | plan_check | Amber banner across your side: "Early game over: you are behind, switching to your 'if behind' plan." Plan chip becomes "Group up, Secure them, Take risks". Red's chip pulses "Plan holds" | You: "Switching to the backup". Red: "Reading the game" | same |
| 24.2 | rotate_stone | All five of you walk together to Stoneback; Red walks loosely | You: "All five heading mid". Red: "Moving to the objective" | same |
| 25.0 / 26.5 | tower_break | Your shoved top wave and a beam break Red's top outer tower (`R.top.outer`, falls at 25.0), while Skarrow is already walking to the pit. Red's mid wave breaks your mid outer tower (`B.mid.outer`, 26.5) | | 1-4, 1-1, 0-0, -2,500 |
| 31.0 | objective_stone | You start the ring, Red tries to steal | You: "Starting Stoneback". Red: "Making them hurry" | |
| 33.75 | objective_stone resolves | Narrow win: the ring flips back in your colour in its last 8%. Amber burst and aura on your team. Skarrow, Ellowen get kills, Dunmarrow gets one (31.9 to 33.1) | | 3-5, 1-1, 1-0, -1,500 |
| 37.0 | team_fight mid approach | You advance together, Red splits to bait | You: "Going all in". Red: "Skirmish, stay loose" | same |
| 45.0 | team_fight mid resolves | Decisive win. Nimbrel flanks and removes three of Red's heroes in 1.0 s (42.4 to 43.4); Red's Dunmarrow trades one of yours. Red collapses at about 40% of the clash. Lead flips to you | Tag: "Back from behind" | 8-6, 1-1, 1-0, +2,400 |
| 46.0 / 47.2 | tower_push | Your siege style stays at range edge; Red's top inner (`R.top.inner`, 46.0) and bot outer (`R.bot.outer`, 47.2) fall | You: "Pushing the tower" | 8-6, 3-1, 1-0, +2,400 |
| 51.0 | reset | Both sides regroup toward Moonhulk | none (tempo 0) | same |
| 54.5 | rotate (late) | Both sides rotate | You: "Heading for Moonhulk". Red: "Regroup at Moonhulk" | same |
| 57.0 | objective_moon | Red starts the ring; you contest | You: "Objectives come first". Red: "Starting Moonhulk" | |
| 60.0 | objective_moon resolves | Clear loss. Red takes Moonhulk despite the edge going in (x = +0.86 for you). Pale-blue pulse on Red. Red's Dunmarrow and Gravenstone get the kills (58.2, 59.1) | Tag on Red: "Against the odds!" | 8-8, 3-1, 1-1, +500 |
| 62.0 | tower | Red takes your mid inner tower (`B.mid.inner`) | | 8-8, 3-2, 1-1, +500 |
| 63.5 | team_fight late approach | You: group, risk. Red: skirmish | You: "Taking a big risk". Red: "Circling for a catch" | same |
| 71.25 | team_fight late resolves | Decisive win: seven Red deaths in 66 to 71 s (Harkin takes three), Red's Dunmarrow trades Nimbrel at 71.15. Edge flash. No wipe banner: only three different Red heroes fall (Dunmarrow four times, Sparrowe twice, Dusken once), so it is two rounds of fighting, not a wipe | | 15-9, 3-2, 1-1, +6,400 |
| 71.5 | close_push (clean_close) | You walk straight to the Cairn. Red's survivors scatter | You: "The Cairn is open". Red: "Last stand at the Cairn" | |
| 72.25 / 73.45 | tower_push | Red's bot inner (`R.bot.inner`, 72.25) and mid outer (`R.mid.outer`, 73.45) fall on the way; Ellowen takes the last kill at 72.36 | | 16-9, 5-2, 1-1, +6,400 |
| 72.7 / 73.3 | close_push (scenery) | Red's two gate towers (`R.guard.l`, `R.guard.r`) crumble as your units pass. No beam, no gold pop, and the tower count stays 5-2 (they are not counted, F8) | | same |
| 74.0 | close_push | Cairn cracks at 72.5 and falls at 74.0 | | same |
| 74.0 to 75.0 | end card | "Victory", "Clear win", length 11:00. "Decided by" the largest positive factor of `Report.attribution`. Play of the game: Decisive teamfight (step +0.2968) | | 16-9, 5-2, 1-1, +6,400 |

Note on this table: it was produced by running the formulas in Python, not from a Godot build, and nothing here has run on a phone. Dunmarrow falling four times in the late fight comes straight from `Report.kda` giving him 8 deaths (request S2).

## 8. Acceptance tests (for QA Automation and the Technical Designer)

1. Same match twice gives the identical script (events, labels, times). Hash it.
2. Replace the `show` streams with differently seeded ones: the scoreboard, kills, towers, objectives, gold and result are identical. Only wording, pairing and times may differ.
3. `res` is unchanged by building and playing the arena (deep compare), and the arena code contains no call to `MatchSim`, `GamePlan.simulate` or `Report.attribution` for outcomes.
4. Invariants I1 to I8 over at least 10,000 seeds.
5. Skip, then the final scoreboard equals the scoreboard of a full play.
6. 2x speed gives the same event order, labels shown for 1.25 s.
7. Every label is 28 characters or fewer with `{lane}` as Top, Mid or Bot and `{hero}` as the longest hero name.
8. A plan label never shows for a control that is 0.
9. The captions for the eight resolves are the same strings as the feed lines in the report's Key moments.

## 9. Evidence: what I ran

- Read: the files named in the brief, plus `game_plan_v0.json`, `sim_params.json`, `heroes.json`, `pcg32.gd` and `i18n/en.json` strings for `gp.*` and `feed.*`.
- Looked at `docs/design/art/current/12_match_mid.png` twice. Pass 1: a clock, one bar and a text feed, over half the screen empty. Pass 2 caught more: the bar shows "They are ahead" at about 22% fill but the bar is teal, the same colour as when you lead, so colour alone does not say who leads; the feed stamps (02:25, 02:50, 03:14, 03:38) are the report's own stamps; there are no hero names anywhere; the amber plan-switch line is the one place the game already explains a decision, and the arena keeps it.
- Wrote a Python prototype of every formula in sections 1 and 5 (`/tmp/claude-0/-home-claude/f6889c24-9ce5-5465-b345-99bece397d73/scratchpad/ledger.py`, `showgen2.py`, `labels.py`; outside the repo, so nothing in game/ changed) and ran it on 40,000 matches from `tools/sim_core.py` with synthetic teams. The synthetic generator reproduces the report's own stated medians (median contest size 0.88, median final 0.30) and the tier mix (contests 27% narrow, 43% clear, 30% decisive; final 26%, 38%, 36%), but these are not real league games. All assertions held on every match: `L_8 = final`, `P_B - P_R = final`, kill sums, winner kills above loser kills, `T_W > T_U`, towers at most 6, tower sums.
- Rates measured: repair tower 11%, fight kill repair 1.1%, gold rounds to zero 0.45%, arcs close 26% / comeback 12% / stomp 24% / steady 39%, any lead flip 55%, game winner loses the last fight 19%, loses both objectives 14%, `abs(x) >= 0.8` upset 3.0% of contests (at least once in 18% of games), winner towers mean 4.4, loser 1.7, winner kills mean 19.4, loser 10.6, total 30 (range 18 to 41), median hero with the most deaths 7.
- Ported `Report.kda` to Python to check the per-hero tie-out; the worked example's pairing used it and the totals matched.
- Not run: Godot (not installed here), any phone, any real save. The port of `Report.kda` and of the two-pass plan logic is by hand and is not proven identical to the GDScript. The label lengths were measured by script.

## 10. Open items for review

1. Chronological lane beats (this document) against the Esports notes' size order: recommendation chronological, because the report stamps must match.
2. Early towers at 25 to 28 s instead of at the lane resolve: recommendation as written, Esports Manager to confirm.
3. S1 to S5 in section 2.5, in this order of urgency: S1 (also a report bug), S2, S3, S4, S5.
4. The 52 intents and the placeholder names Stoneback, Moonhulk, Cairn, Hollowmere and the hero names go to the IP & Originality Checker. The wording is generic genre vocabulary, and no line copies a title or a catchphrase that I know of.
5. For the Level / World Designer: confirm or rename the zone ids in section 2.3. For the Technical Designer: choreography data should key on the beat ids of section 2.1 and the cue ids of section 3.2.
