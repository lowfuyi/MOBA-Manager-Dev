# Arena map: Hollowmere (live match view)

Status: DRAFT v0.2 (wave 1b reconciliation), 2026-11-08. Owner: Level / World Designer. Workstream W4 of `docs/ALPHA-0.7-PLAN.md`.
Data: `game/data/arena_map.json` (map 0.2.0, schema 1, additive changes only; no id was renamed). Check: `python3 tools/validate_arena_map.py`.
Colours: this document names colour tokens only. **All values are owned by `docs/design/ART-BIBLE.md`** (Art Director).
Picture: `docs/design/art/arena-map-preview.png` (source `arena-map-preview.svg`).

The map is a stage for a playback that the simulation has already decided. It cannot change who wins. It gives every simulated contest one clear place to happen.

## 1. The map at a glance

- A tall oval world for a portrait phone. A round lake, **The Mere**, sits in the middle with an island, **Moonhulk**, in its centre.
- Two stone plazas, one at each end, hold the **Cairn** (the base) and five hero spawn pads.
- Three lanes join the plazas: **Top** and **Bot** bow outward around the lake; **Mid** is a plank causeway straight across the lake and over the island.
- Two jungle pockets sit between the bow lanes and the lake: the open **Thicket** (west) and the tight **Shallows** (east).
- Two neutral objectives, both on the centre line: **Stoneback** (early, in the Shallows) and **Moonhulk** (late, on the island).
- The whole map is on screen all the time. No scrolling.

## 2. Why it is not a copy

| Genre habit | Hollowmere |
|---|---|
| Square map, lanes on the edges plus a diagonal, a river across the middle | Tall oval for a portrait phone. A lake in the middle, no river |
| Edge lanes run in straight lines | Top and Bot are arcs that curve around the lake. Top is long and narrow (40 px), Bot is shorter and wide (64 px) for two heroes |
| Mid is a plain corridor | Mid is a bridge over water that ends on the Moonhulk island. Winning mid means standing next to the late objective |
| Objective pits on the river | Stoneback in a tight pocket on the east bank, Moonhulk on an island. Neither is on a lane |
| Four jungle quarters | Two pockets, one wide and one tight, plus one big camp shared by both teams |
| Bases in two corners | Bases are plazas at the two ends with a fan of five spawn pads |
| Turned-around (rotational) symmetry | Mirror symmetry across the centre line. The picture is flipped, never rotated |

Honest limit: three lanes, a jungle, towers and two neutral objectives are genre parts the Founder chose to keep. The shapes, places and names above are ours. I looked at no other game's map to draw this, and two quick web searches found no MOBA map page using these names. That is not a trademark search; the IP & Originality Checker still reviews it.

## 3. Names

| Part | Name | Note |
|---|---|---|
| Map | Hollowmere | GDD placeholder, IP check pending |
| Lake / island | The Mere / the Moonhulk isle | new |
| Top, Mid, Bot lanes | **Reedrun**, **Hush Causeway**, **Lanternway** | new. The screen keeps the words "Top / Mid / Bot" (as the feed does); flavour names only appear in commentary |
| Jungle pockets | The Thicket (west), The Shallows (east) | new |
| Early / late objective | Stoneback / Moonhulk | GDD placeholders |
| Base core | The Cairn | GDD placeholder |
| Camps | Moss (small), Bramble (medium), **Mossback** (big, shared) | Moss camps is the GDD word |
| Base plaza | Cairn Gate | new |

## 4. Fit on a 720 x 1280 screen, and which side is at the bottom

| Strip | y from | y to | Height |
|---|---|---|---|
| Scoreboard | 0 | 190 | 190 |
| **Arena** | 190 | 950 | **760** (720 wide) |
| Intent label and feed (my assumption, for UI/UX to confirm) | 950 | 1100 | 150 |
| Controls | 1100 | 1280 | 180 |

**Decision: the player's team is always at the bottom.** When the player is Red the picture is flipped top to bottom (`y` becomes `1 - y`, `x` unchanged). It is a mirror, never a rotation.

- The player's own base is next to the thumb and the Skip button, and "forward" always means "up".
- Top lane stays on the left and Bot on the right in every match, so the player learns one picture. A 180 degree turn would swap them.
- The map is mirror-symmetric, so both sides are fair. The simulation's small Blue-side bonus (0.02) stays a number, not a place.
- Text and icons are drawn in screen space and are never flipped.
- Colour follows the scoreboard and feed, not "Blue/Red" (ruling C4): **you = `ACCENT` teal circle**, **them = `CORAL` hexagon**, the same pair as the versus bar. `BAD` is for status and loss tone only (for example a feed line you lost). The words Blue and Red, with a flag glyph, appear on Home and the draft board and **never in the arena**. The shape differs as well as the colour, so it works in colour-blind mode.

## 5. Coordinates and speed

| Item | Value |
|---|---|
| Frame | `x` 0 to 1 = 720 px west to east; `y` 0 to 1 = 760 px north to south. Canonical data has **Blue (B) in the south, Red (R) in the north**, neutral (N) on `y = 0.5` |
| Mirror rule | Every `B.x` has an `R.x` at `(x, 1 - y)` |
| Distance unit | 1 map unit (u) = 760 px. `dist = hypot(dx * 0.9474, dy)` |
| **Walk speed** | **0.060 u/s = 45.6 px/s** |
| Other speeds | rotate = 1.5 x walk (68 px/s), used only for the Stoneback to Mossback swing; rush = 2 x walk (91 px/s), unused so far |
| Fast-forward | 2 x doubles all of these; Skip jumps to the end |

| Lane | Name | Width | Length | End to end at walk speed |
|---|---|---|---|---|
| Top | Reedrun | 40 px | 0.877 u = 666 px | 14.6 s |
| Mid | Hush Causeway | 56 px | 0.580 u = 441 px | 9.7 s |
| Bot | Lanternway | 64 px | 0.841 u = 639 px | 14.0 s |

Walkers follow the waypoints exactly (straight segments). The art draws a smooth curve through them; the biggest gap is 4.1 px (Top), less than a quarter of the lane width.

## 6. The parts (Blue half; Red is the mirror)

**Bases and spawns.** Cairn `(0.500, 0.925)`; base yard radius 0.22 u; Cairn Gate `(0.500, 0.790)`, radius 64 px.

| Slot | Spawn | Home |
|---|---|---|
| top | (0.335, 0.862) | Top lane |
| jg | (0.415, 0.838) | The Thicket and Shallows |
| mid | (0.500, 0.822) | Mid lane |
| bot | (0.585, 0.838) | Bot lane |
| sup | (0.665, 0.862) | Bot lane, beside the carry |

Spawn pads are at least 60 px apart (40 px tokens).

**Lane waypoints** (gate, then towards the centre; the centre point is shared; the Red half mirrors):

| Lane | Waypoints (x, y) |
|---|---|
| Top | (0.300, 0.845) (0.210, 0.822) (0.148, 0.760) (0.118, 0.670) (0.110, 0.580) **(0.110, 0.500)** |
| Mid | (0.500, 0.790) (0.500, 0.735) (0.500, 0.672) lake edge (0.500, 0.600) island edge **(0.500, 0.500)** |
| Bot | (0.700, 0.845) (0.780, 0.808) (0.840, 0.742) (0.874, 0.660) (0.887, 0.580) **(0.890, 0.500)** |

**Towers.** Per side: two on each lane (inner, outer) and two gate towers. 16 in all. Icon 28 px.

**Tower tally (ruling C5).** The scoreboard counts **6 towers per side**: outer and inner in each of Top, Mid and Bot (`scoreboard: true` in the data). The 2 guard towers at each gate are **scenery** (`scoreboard: false`): never counted, never part of `T_X`, and they fall only in the closing push, at 72.0 s and 72.4 s, between the resolve of `fight_late` (71.25 s) and the fall of the Cairn (74.0 s). The repair tower of the vocabulary (F8) is a counted lane tower, not a guard tower. The preview draws the guard towers dimmer. Data: `tower_tally` and the per-tower flag; the validator fails if a guard tower is counted, if a lane tower is not, or if a guard tower falls outside the closing push.

| Tower | Blue position | Arc fraction `s` from own gate |
|---|---|---|
| Top inner / outer | (0.179, 0.791) / (0.118, 0.666) | 0.15 / 0.31 |
| Mid inner / outer | (0.500, 0.744) / (0.500, 0.691) | 0.08 / 0.17 (outer must stay on land) |
| Bot inner / outer | (0.809, 0.776) / (0.874, 0.659) | 0.15 / 0.31 |
| Gate left / right | (0.405, 0.765) / (0.595, 0.765) | none |

**Lane clash point.** It starts at `s = 0.5`. A lane winner shifts it towards the loser by up to `max_shift_s`: **Top 0.15, Mid 0.29, Bot 0.15**. At the maximum the fight stands just in front of the enemy outer tower.

**Jungle camps.** Per side: six camps, three in each pocket. Plus one shared big camp.

| Camp | Pocket | Kind | Blue position |
|---|---|---|---|
| w1, w2, w3 | Thicket | moss, moss, bramble | (0.215, 0.700) (0.300, 0.650) (0.235, 0.585) |
| e1, e2, e3 | Shallows | moss, moss, bramble | (0.760, 0.705) (0.700, 0.655) (0.745, 0.600) |
| Mossback | Thicket, centre line | big, shared | (0.215, 0.500) |

Dotted trails link camps to the lanes and pockets. They are walkable edges in the data (57 nodes, 80 edges) so choreography can route heroes without a pathfinder. Only the two causeway edges cross water.

**Objectives.**

| Name | Sim contest | Position | Icon | Shape and colour |
|---|---|---|---|---|
| Stoneback | obj_mid | (0.780, 0.500) | 48 px | hexagon with a shell pattern, token `WARN` |
| Moonhulk | obj_late | (0.500, 0.500), on the island | 48 px | disc with a crescent, placeholder token `ARENA_MOON_PALE` |
| The Cairn (x2) | siege | (0.500, 0.925) / (0.500, 0.075) | 48 px | stacked stones, rim in `ACCENT` (yours) or `CORAL` (theirs) |

**Fight zones** (circle, radius in px): top_clash (0.110, 0.5) 48; mid_clash (0.5, 0.5) 76; bot_clash (0.890, 0.5) 48; mossback_clearing (0.215, 0.5) 78; stoneback_pit (0.780, 0.5) 70; moonhulk_isle (0.5, 0.5) 76; thicket and shallows (own half) 90; gate 64; cairn 52. The island holds ten tokens only just (r 76 px): use 36 px tokens in the big fights.

## 7. Each contest has a place and a time

Times are the sim's own feed moments (`Report.FEED_ORDER`) times the 75 s watch window, at normal speed.

| # | Sim contest | Real time | Place | What the viewer sees (suggested) |
|---|---|---|---|---|
| 1 | top | 13.5 s | Reedrun midpoint, west | Top lane duel, jungler may gank |
| 2 | mid_lane | 15.8 s | Hush Causeway, on the isle | Mid duel; winner pushes the clash point along the bridge |
| 3 | bot | 18.0 s | Lanternway midpoint, east | 2 v 2, bot and support |
| 4 | jungle | 20.3 s | Both pockets and Mossback | Junglers clear camps; the winner invades across the centre line |
| 5 | obj_mid | 33.8 s | **Stoneback**, Shallows | Five heroes take the early objective |
| 6 | fight_mid | 45.0 s | **Mossback Clearing**, Thicket | Team fight in the open; the teams swung west (rotate speed) |
| 7 | obj_late | 60.0 s | **Moonhulk**, island | Take the late objective; mid control decides who arrives first |
| 8 | fight_late | 71.3 s | **Cairn Gate** of the team that loses the match, when the match winner also wins this fight (81 percent of games). When the match winner loses it (19 percent) see 7.1 | Decisive fight on the way in |
| 9 | siege (end) | 75.0 s | The losing Cairn | Last push, base falls |

Walking time versus the time before each contest, from the validator (walk speed unless noted):

| Walk | Needs | Has |
|---|---|---|
| Spawn to top / mid / bot / jungle place | 7.9 / 5.4 / 8.8 / 6.6 s | 13.5 / 15.8 / 18 / 20.3 s |
| Cairn to Stoneback | 9.5 s | 33.8 s |
| Stoneback to Mossback (rotate) | 8.5 s | 11.3 s |
| Mossback to Moonhulk | 10.3 s | 15.0 s |
| Island to the enemy gate | 4.8 s | 11.3 s |
| Gate to Cairn | 2.3 s | 3.8 s |

Every walk keeps at least 1 s to spare. Tight ones: the Stoneback swing and the last push.

One more limit, found while writing 7.1: the gate zone (r 64 px) cannot hold ten 36 px bodies (they fill 79 percent of its area). For the 81 percent case use the `held_gate` formation of 7.1 as a starting layout: the defenders inside the gate plaza, the attackers in a line at the causeway mouth.

### 7.1 Held fight: the match winner loses `fight_late` (19 percent of games)

**Problem.** The sim sums three phases, so the side that wins the match can lose the last fight. Showing the winner beaten at the loser's gate and then breaking the Cairn reads as "won the fight, lost the match", and fails the tester question "Results felt fair". **Idea for both stagings.** The fight is a stand-off that the match loser (U) holds; nobody dies beyond the kill ledger (no kill count change); the match winner's (W) lead arrives as a **reserve pack** (six 14 px dots in W's colour, running at rush speed, 91 px/s), the guard towers fall as scenery, and the Cairn breaks at 74.0 s. The default is `held_island` (the wave 1 review's recommendation: hold the fight at the island or the gate). **Neither staging has been prototyped or shown to a tester; nothing here is proven.** Data: `late_fight_variants` in `arena_map.json`; the validator checks the formations and the walks.

Frame: W is drawn as Blue (south) and U as Red (north). If W is Red, mirror every point to `(x, 1 - y)` and swap B and R in node ids; the player's own flip comes after that. Tokens are 36 px bodies. W and U slots are the five hero slots.

| | `held_island` (default) | `held_gate` (alternative) |
|---|---|---|
| Place | Moonhulk isle (`moonhulk_isle`, r 76 px), where both teams already stand after `obj_late` | U's gate (`gate.R` plaza) for U; a line of W at the causeway mouth just south of it |
| W formation (map coordinates) | front: top (0.444, 0.526), sup (0.500, 0.526), jg (0.556, 0.526); back: mid (0.472, 0.571), bot (0.528, 0.571) | top (0.342, 0.284), jg (0.394, 0.284), mid (0.447, 0.284), bot (0.553, 0.284), sup (0.606, 0.284) |
| U formation | mirror of W through the isle centre (y becomes 1 - y) | front: top (0.444, 0.200), sup (0.500, 0.200), jg (0.556, 0.200); back: mid (0.472, 0.157), bot (0.528, 0.157) |
| Gaps | front ranks 40 px apart (centre to centre); the Moonhulk icon fades under the tokens | front ranks 64 px apart (melee steps up to 28 px forward and back); 40 px clear gap in W's line for the lane |
| Heroes move | not at all (they are already there) | W walks from the isle to `R.mid.1`, U rotates back to `R.mid.gate`, both leave at 61.0 s |
| Reserve pack | isle to `R.mid.1` at 68.0 s, waits, then to `R.cairn` at 71.25 s | Mossback to `R.mid.1` at 66.0 s (the Thicket trail), waits, then to `R.cairn` at 71.25 s |
| Reads as | a neutral draw on the island; the push happens elsewhere | a held door; the push comes round the side |
| Risk | ten tokens on a 152 px isle is dense; pack runs through the fight's north edge | long walk for the pack looks odd if the camera is tight; W stands among the gate towers |

Shared timeline (seconds on the 75 s clock): 63.0 formation; 66.0 clash cues; 71.25 fight resolves, "held", no position change, no kill count change (the tag text is for Gameplay and Narrative to set); 72.0 and 72.4 the two guard towers fall; 72.5 the Cairn cracks; 74.0 the Cairn falls; 74.0 to 75.0 end card. In `held_gate` the pack also waits at the causeway mouth from 69.2 s.

Walk checks (validator, rule: needed time at most the time available minus 1 s):

| Variant | Who | Walk | Speed | Needs | Leaves, due | Spare |
|---|---|---|---|---|---|---|
| `held_island` | pack | `N.moonhulk` to `R.mid.1` (0.235 u) | rush | 2.0 s | 68.0, 71.25 | 1.3 s |
| `held_island` | pack | `R.mid.1` to `R.cairn` (0.190 u) | rush | 1.6 s | 71.25, 74.0 | 1.2 s |
| `held_gate` | W | `N.moonhulk` to `R.mid.1` (0.235 u) | walk | 3.9 s | 61.0, 66.0 | 1.1 s |
| `held_gate` | U | `N.moonhulk` to `R.mid.gate` (0.290 u) | rotate | 3.2 s | 61.0, 66.0 | 1.8 s |
| `held_gate` | pack | `N.mossback` to `R.mid.1` (0.384 u) | rush | 3.2 s | 66.0, 71.25 | 2.0 s |
| `held_gate` | pack | `R.mid.1` to `R.cairn` (0.190 u) | rush | 1.6 s | 71.25, 74.0 | 1.2 s |

The walks fit on paper. They say nothing about how the ten bodies look together, whether the pack reads as "the lead", or whether the viewer believes the Cairn falls; only a prototype and a tester can say. The two heroes' legs in `held_gate` start at 61.0 s, during the Moonhulk payoff (60.0 to 63.0 s); the vocabulary's approach window is 63.0 to 66.0 s, and the walk cannot fit it at walk speed (it needs 3.9 s).

## 8. Camera

| Setting | Value |
|---|---|
| Default | Whole map, zoom 1.0, no pan. Lanes 1 to 4 (13 to 20 s) stay here because three scenes run at once |
| Focus | Contests 5 to 9 ease in to at most **1.3 x** on the fight, 0.45 s in, hold at least 2 s, 0.6 s out, never showing past the map edge |
| Reduced motion | Stay at 1.0. No shake ever |

## 9. Readability budget

| Thing | Size | Shape cue |
|---|---|---|
| Hero token | 40 px | circle (you), hexagon (them), slot letter T J M B S |
| Tower | 28 px | round plate with a tower, team-colour rim |
| Camps | 24 / 28 / 36 px | moss leaf, bramble wheel, Mossback dome |
| Objectives, Cairn | 48 px | see section 6 |
| Labels | 20 px bold with outline | never smaller |
| Minions (suggested) | 14 px dots, not icons | one wave of 4 every 10 s from 2 s, 0.05 u/s |

The validator also checks that no two icons overlap at these sizes.

Colours (token names only; **values owned by ART-BIBLE**): you `ACCENT`, them `CORAL`, Stoneback `WARN`, status text `BAD` / `GOOD`, surfaces `VOID`, `PANEL`, `TEXT2`. The map needs a few colours the bible does not yet define. Until the Art Director issues them, these descriptive placeholders stand in: `ARENA_LAKE_DEEP`, `ARENA_LAKE_EDGE` (the Mere), `ARENA_MOON_PALE` (Moonhulk and its pulse), `ARENA_MOSS` (leaf camps, Mossback, pocket shade), `ARENA_BRAMBLE` (camp wheels), `ARENA_LANE` (lane paths). Watch-outs for the Art Director: `ARENA_MOON_PALE` must stay apart from the Top role ring, `ARENA_MOSS` apart from `GOOD` and the Jungle ring, and `ARENA_BRAMBLE` apart from `CORAL` (ten coral hexagons stand near amber camps).

## 10. How it was checked

- `python3 tools/validate_arena_map.py --report`: all 14 checks pass (structure, ids, range, mirror, lanes, spawns, towers, camps, water, spacing, stages, plus three new in 0.2: units, tally, variants).
- Wave 1b: 24 further broken copies (for units, tally, variants and a few old checks) all exit 1, each tripping the check it targets (copies built by a throwaway script, not kept in the repo).
- 11 deliberately broken copies of the file (a tower moved, a coordinate at 1.2, a spawn deleted, a lane cut, a tower in the lake, a walk that is too slow, and others) all fail with exit code 1.
- Wave 1b: the preview was recoloured (them = coral hexagons, guard towers dimmed), re-rendered and viewed twice (full frame, then enlarged crops of both halves).
- The preview was drawn, looked at and corrected twice: first pass found a missing moon crescent, a star icon that read as UI, tags hiding towers, clipped text and floating bases; the second found a label touching a tag and checked a flipped version.

**Not tested:** neither held-fight staging has been prototyped or shown to anyone (see 7.1); a real phone (touch feel, speed, heat), frame rate, a colour-blind simulation, the flip inside the engine (only drawn), and any trademark or store search.

## 11. Hand-offs

| To | Ask |
|---|---|
| Technical Designer | Read `stages`, `zones`, `nodes` and `edges`; decide who stands where in each zone. The match winner can lose the late fight (19 percent of games): build both stagings of section 7.1 (`late_fight_variants` in the data) and let the tester question decide. Key choreography on the ids of section 12 |
| Engine / Graphics Programmer | One `y` flip when the player is Red; budget about 45 icons (16 towers, 13 camps, 4 objectives, 10 tokens) |
| UI/UX Designer | Confirm the 150 px strip under the arena and the teal circle / coral hexagon rule (ruling C4) |
| Art Director | Issue the colour tokens named in section 9 (placeholders `ARENA_*`); map labels are still 20 px and the type scale wants 24 (C1), which needs a redraw of the preview |
| Gameplay Designer | Re-key the vocabulary to the ids of section 12; confirm the wave-front reading in 12.5 and the `lead_carries` tag text |
| IP & Originality Checker | Screen section 3 names and the layout |

## 12. Id map (one page)

For the Technical Designer's choreography table and the Gameplay Designer's vocabulary. Every id below is in `arena_map.json` and none was renamed in wave 1b. Notation: `{B,R}.x` means both `B.x` and `R.x`; B is Blue (south in the canonical frame), R is Red (north), N is neutral on `y = 0.5`. "Own" and "enemy" are resolved by the choreography from the side letter.

### 12.1 Zones (14): where a hero is standing

| Id | Hero-facing meaning | r px |
|---|---|---|
| `top_clash` | the Top duel place, middle of Reedrun | 48 |
| `mid_clash` | the Mid duel place on the isle; the winner shifts the front along the causeway | 76 |
| `bot_clash` | the Bot 2 v 2 place, middle of Lanternway | 48 |
| `mossback_clearing` | open ground in the Thicket by the shared big camp: the mid-game team fight | 78 |
| `stoneback_pit` | tight ground round the Stoneback: the early objective, five heroes each side | 70 |
| `moonhulk_isle` | the island: the late objective, and the `held_island` stand-off | 76 |
| `thicket.B`, `thicket.R` | west jungle pocket of that side: three camps; the jungler's home | 90 |
| `shallows.B`, `shallows.R` | east jungle pocket of that side: three camps | 90 |
| `gate.B`, `gate.R` | the plaza before that side's Cairn between its two guard towers: defenders stand here | 64 |
| `cairn.B`, `cairn.R` | the Cairn itself: siege ground, where the game ends | 52 |

### 12.2 Nodes (57): where a hero walks

| Ids | Hero-facing meaning |
|---|---|
| `N.top.mid`, `N.bot.mid` | centre of Reedrun / Lanternway; the neutral clash points (zones `top_clash`, `bot_clash`) |
| `N.moonhulk` | the isle centre: Moonhulk, the Mid lane centre, zone `moonhulk_isle` |
| `N.mossback` | the shared big camp, zone `mossback_clearing`; the west waypoint of rotations |
| `N.stoneback` | the Stoneback, zone `stoneback_pit` |
| `{B,R}.top.gate`, `{B,R}.mid.gate`, `{B,R}.bot.gate` | where that lane leaves the plaza; `mid.gate` is the middle of zone `gate.*` |
| `{B,R}.top.1` to `.top.4`, `{B,R}.bot.1` to `.bot.4` | lane waypoints from the gate towards the centre (1 near the gate, 4 near the centre) |
| `{B,R}.mid.1`, `.mid.shore`, `.mid.rim` | Mid waypoints: on land before the causeway, last land before the bridge, the isle edge. Walking `shore` to `rim` crosses water on the plank bridge |
| `{B,R}.spawn.top`, `.jg`, `.mid`, `.bot`, `.sup` | the hero's rising place at its own base, one per slot |
| `{B,R}.w1`, `.w2`, `.w3` | Thicket camps (moss, moss, bramble) of that side |
| `{B,R}.e1`, `.e2`, `.e3` | Shallows camps (moss, moss, bramble) of that side |
| `{B,R}.cairn` | the Cairn, the end of every siege walk |

### 12.3 Stages (9): when and where (sim contest ids; time on the 75 s clock)

| Stage id | t | Zone | Vocabulary beat (ACTION-VOCABULARY 2.3) |
|---|---|---|---|
| `top` | 13.5 | `top_clash` | `lane_trade` (top) |
| `mid_lane` | 15.75 | `mid_clash` | `lane_trade` (mid) |
| `bot` | 18.0 | `bot_clash` | `lane_trade` (bot and sup) |
| `jungle` | 20.25 | `thicket.*`, `shallows.*`, `mossback_clearing` | `jungle_play` |
| `obj_mid` | 33.75 | `stoneback_pit` | `objective_stone` |
| `fight_mid` | 45.0 | `mossback_clearing` | `team_fight` (mid) |
| `obj_late` | 60.0 | `moonhulk_isle` | `objective_moon` |
| `fight_late` | 71.25 | `gate.*` of the match loser, or a variant of 7.1 | `team_fight` (late), then `close_push` |
| `siege` | 75.0 | `cairn.*` of the match loser | `close_push` |

Other ids: lanes `top`, `mid`, `bot` (flavour names Reedrun, Hush Causeway, Lanternway); slots `top`, `jg`, `mid`, `bot`, `sup`; towers `{B,R}.{top,mid,bot}.{outer,inner}` (6 counted per side) and `{B,R}.guard.l`, `{B,R}.guard.r` (scenery); camps as in 12.2 plus `N.mossback`; objectives `N.stoneback`, `N.moonhulk`, `B.cairn`, `R.cairn`; areas `thicket`, `shallows`, `mere`; held-fight variants `held_island`, `held_gate`.

### 12.4 From the vocabulary's placeholder ids to the map's ids

| Vocabulary (2.3) | Map id |
|---|---|
| `base_B`, `base_R` | spawn pads `{B,R}.spawn.<slot>` for rising and walking out; `gate.B`, `gate.R` for defending; `cairn.B`, `cairn.R` for the siege |
| `lane_top`, `lane_mid`, `lane_bot` | lane `top`, `mid`, `bot` (a place along it is an arc fraction `s` from Blue's gate: 0 Blue gate, 0.5 centre, 1 Red gate); the neutral clash place is `top_clash`, `mid_clash`, `bot_clash` |
| `jungle_B`, `jungle_R` | the jungler's home is `thicket.B` / `thicket.R`; the other pocket is `shallows.B` / `shallows.R`; the shared camp is `N.mossback` |
| `pit_stone` | `stoneback_pit` (node `N.stoneback`) |
| `pit_moon` | `moonhulk_isle` (node `N.moonhulk`) |
| `tw.<side>.<lane>.<outer\|inner>` | `<side>.<lane>.<tier>`, for example `B.top.outer` (side first, then lane, then tier) |
| `cairn.<side>` | `cairn.<side>` (zone), `<side>.cairn` (node), objective `<side>.cairn` |

### 12.5 Body widths, map units and pixels

One **body width** is the 36 px token used in big fights (the lane token is 40 px; multiply by 1.11 if a fight is drawn at 40). One **step** in the vocabulary is one body width.

| Quantity | Body widths | Pixels | Map units (u, 1 u = 760 px) |
|---|---|---|---|
| Body width, one step | 1 | 36 | 0.0474 |
| Melee reach | 1 | 36 | 0.0474 |
| Mid range | 3 | 108 | 0.1421 |
| Long range | 5 | 180 | 0.2368 |
| Walk speed per second | 1.27 | 45.6 | 0.060 |
| Rotate / rush speed per second | 1.9 / 2.5 | 68 / 91 | 0.090 / 0.120 |
| Lane width: Top / Mid / Bot | 1.1 / 1.6 / 1.8 | 40 / 56 / 64 | 0.053 / 0.074 / 0.084 |

To convert in normalised arena coordinates: one body width is 0.0500 in `x` (36 / 720) and 0.0474 in `y` (36 / 760). Screen pixels in the arena are `x * 720` and `y * 760` (add 190 to `y` for the 720 x 1280 screen). Distances in `u` use `hypot(dx * 0.9474, dy)`.

Things the numbers say: two bodies do not fit abreast in Bot (64 px against 72 px), so the duo staggers by one step, which the vocabulary already asks for; Top is single file. A long-range hero on the isle reaches every other token there (the isle is 152 px across against a 180 px range), so long range needs no walking in that fight. The wave front of the vocabulary ("0.6 times the margin of the lane length, from the centre towards the loser's outer tower") is ambiguous; this map reads it as 0.6 times the margin times the distance from the centre to the loser's outer tower (0.19 of the lane for Top and Bot, 0.33 for Mid), which stays inside the data's `max_shift_s` (0.15, 0.29, 0.15). The Gameplay Designer confirms or corrects this.
