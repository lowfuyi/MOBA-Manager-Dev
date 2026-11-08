# Arena map: Hollowmere (live match view)

Status: DRAFT v0.3 (pass 1c, alignment with the wave 1b review; no new places), 2026-11-09. Owner: Level / World Designer. Workstream W4 of `docs/ALPHA-0.7-PLAN.md`.
Data: `game/data/arena_map.json` (map 0.3.0, schema 1, additive changes only; no id was renamed). Check: `python3 tools/validate_arena_map.py` (`--report` prints the numbers, `--selftest` runs the broken copies).
Colours: this document names token names only. **All values are owned by `docs/design/ART-BIBLE.md`** (Art Director); section 9 maps every map part to a bible token.
Picture: `docs/design/art/arena-map-preview.png` (full view) and `arena-map-preview.focus.png` (camera zoom 1.3, where the place names show). Both are drawn by `docs/design/art/arena-map-preview.py` from the data, with the colours read from the bible.

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
| Text strip: plan row 44, gap 8, intent row 48, gap 8, feed block 80, bottom 10 | 950 | 1148 | **198** |
| Controls: 12 gap, 96 button, 24 bottom margin | 1148 | 1280 | **132** |

Ruling P1 (wave 1b review 4.3, UI-PASS-2 6.7.2): 48 px moved from the controls strip to the text strip (it was 150 and 180). The arena is still 720 x 760 at y 190 to 950 and the scoreboard still 190, so nothing in the map moved. The sums: 44 + 8 + 48 + 8 + 80 + 10 = 198 and 12 + 96 + 24 = 132. The validator now fails if either strip is not exactly this.

**Decision: the player's team is always at the bottom.** When the player is Red the picture is flipped top to bottom (`y` becomes `1 - y`, `x` unchanged). It is a mirror, never a rotation.

- The player's own base is next to the thumb and the Skip button, and "forward" always means "up".
- Top lane stays on the left and Bot on the right in every match, so the player learns one picture. A 180 degree turn would swap them.
- The map is mirror-symmetric, so both sides are fair. The simulation's small Blue-side bonus (0.02) stays a number, not a place.
- Text and icons are drawn in screen space and are never flipped.
- Colour follows the scoreboard and feed, not "Blue/Red" (rulings C4 and R2): **you = `ACCENT` teal circle**, **them = `CORAL` flat-top hexagon**, the same pair as the versus bar (ART-BIBLE 3.8). **The hexagon means "them" and nothing else**: Stoneback is a rhombus (ruling B2). `BAD` is status and loss tone only and never appears in the arena (the loss tone is the edge vignette and the Defeat glyph on the end card). The words Blue and Red, with a flag glyph, appear on Home and the draft board and **never in the arena**. The shape differs as well as the colour, so it works in colour-blind mode.

## 5. Coordinates and speed

| Item | Value |
|---|---|
| Frame | `x` 0 to 1 = 720 px west to east; `y` 0 to 1 = 760 px north to south. Canonical data has **Blue (B) in the south, Red (R) in the north**, neutral (N) on `y = 0.5` |
| Mirror rule | Every `B.x` has an `R.x` at `(x, 1 - y)` |
| Distance unit | 1 map unit (u) = 760 px. `dist = hypot(dx * 0.9474, dy)` |
| **Walk speed** | **0.060 u/s = 45.6 px/s** |
| Other speeds | rotate = 1.5 x walk (68 px/s): the Stoneback to Mossback swing, **the lane-to-Stoneback walk (leave by 20.25 s, arrive by 31.0 s)**, the tower-site-to-island walk and the held-gate heroes' legs; rush = 2 x walk (91 px/s): the reserve pack, the winners' last run to the Cairn. Section 7.0 has every leg |
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
| Stoneback | obj_mid | (0.780, 0.500) | 48 px | **rhombus** with a shell mark (a fan), `VOID` plate, `WARN` rim. Not a hexagon: the hexagon is "them" |
| Moonhulk | obj_late | (0.500, 0.500), on the island | 48 px | disc with a crescent: `VOID` plate, `TEXT2` rim, `TEXT` crescent |
| The Cairn (x2) | siege | (0.500, 0.925) / (0.500, 0.075) | 48 px | stacked stones, `VOID` plate, rim in `ACCENT` (yours) or `CORAL` (theirs) |

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

The gate zone (r 64 px) cannot hold ten 36 px bodies (they fill 79 percent of its area). The 81 percent case therefore has its own formation, `clean_gate` (7.2): the defenders inside the gate plaza, the attackers in a line at the causeway mouth.

### 7.0 Walks that start in the lanes and at the tower sites

The first table above starts every walk at the Cairn or at a fight place. The Gameplay Designer found that the walks the vocabulary needs start elsewhere (review items B7 and B17), so the validator now checks them too (`walk_legs` in the data; `--report` prints each one). A lane origin is the clash point anywhere in the lane's shift range (`clash_rule`), so both ends of the range are checked, not just the middle. Rule for every leg: needs at most (window minus 1 s).

| Leg (vocabulary beat) | Leaves, due | Speed | Worst origin | Needs | Window | Result |
|---|---|---|---|---|---|---|
| Top lane to Stoneback (`rotate_stone`) | 20.25 s, 31.0 s | rotate | neutral clash point | 9.6 s | 10.75 s | passes, 1.15 s spare, the tightest |
| Mid lane to Stoneback | 20.25, 31.0 | rotate | the isle | 6.8 s | 10.75 s | passes |
| Bot lane to Stoneback | 20.25, 31.0 | rotate | clash shifted 0.15 | 2.6 s | 10.75 s | passes |
| Jungler (Mossback) to Stoneback | 20.25, 31.0 | rotate | the clearing | 8.5 s | 10.75 s | passes |
| Tower sites `top.2`, `mid.1`, `bot.2`, `bot.3` and the clearing to the island (`reset`) | 51.0 s, 60.0 s | rotate | `bot.3` | 7.7 s (top.2 7.5, bot.2 6.7, clearing 6.9, mid.1 2.6) | 9.0 s | pass |

Legs that fail, and that the validator asserts keep failing (so the finding cannot go stale):

| Leg | Needs | Window | Meaning |
|---|---|---|---|
| Top lane to Stoneback at walk speed, leaving 24.0 s | 14.4 s | 7.0 s | the vocabulary's first assumption: the top hero would arrive at 38.4 s, after the take resolves at 33.75 s. Fix: leave by 20.25 s at rotate speed |
| Same at walk speed, leaving 20.25 s | 14.4 s | 10.75 s | still too slow: the lane legs need rotate speed (1.5 x) |
| Tower site `top.3` to the island at rotate speed, leaving 51.0 s | 8.2 s | 9.0 s | arrives at 59.2 s, 0.8 s before the take resolves, under the 1 s rule. **Open for the Gameplay Designer:** accept the late arrival (the vocabulary already says "inside the take, not at its start") or leave at 50.5 s |
| Island to the Cairn after the fight resolves, at rush speed, 71.25 s to 74.0 s | 3.5 s | 2.75 s | the 4.8 s (island to gate) and 2.3 s (gate to Cairn) walks pass on their own (4.8 of 11.25 s; 2.3 of 3.75 s) but together they are 7.1 s at walk speed. So no hero walks them after the resolve: the held variants move only the reserve pack, and `clean_gate` has the winners at the gate before the resolve |

Rotate speed on the lane legs and the tower-site legs is confirmed (answer to ACTION-VOCABULARY hand-off 4a); section 5 now lists it.

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

Confirmed for the Gameplay Designer (pass 1c): in `held_island` nobody walks, so a hero of W that falls rises at its own formation point of the table above with no walk (all five points are on the isle; the mid and bot bodies reach 75.6 px of the 76 px rim, so they touch it); in `held_gate` the heroes' legs start at 61.0 s, inside the Moonhulk payoff (60.0 to 63.0 s), W's walk to `R.mid.1` needs 3.9 s and U's rotate to `R.mid.gate` 3.2 s, both due by 66.0 s. They cannot start at 63.0 s: W's walk needs 3.9 s of the 3.0 s that the vocabulary's approach window (63.0 to 66.0 s) has.

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

### 7.2 The clean ending: the match winner also wins `fight_late` (81 percent of games), formation `clean_gate`

Review item B17: this case had no formation of its own, and the old text pointed at `held_gate`, which is the 19 percent alternative. Now it has one in the data (`late_fight_variants`, variant `clean_gate`, kind `clean`, default for this case), checked the same way as the held ones (tokens at least 36 px apart, on land, off the towers, inside their zone, walks fit their clock, the timeline ends with the Cairn falling).

| | `clean_gate` |
|---|---|
| Place | U's gate (`gate.R` plaza) for U; a line of W at the causeway mouth just south of it |
| U formation | front: top (0.444, 0.200), sup (0.500, 0.200), jg (0.556, 0.200); back: mid (0.472, 0.157), bot (0.528, 0.157). Five bodies fill 40 percent of the gate zone (the validator allows 50), so U fits and W does not stand in the zone |
| W formation | top (0.342, 0.284), jg (0.394, 0.284), mid (0.447, 0.284), bot (0.553, 0.284), sup (0.606, 0.284): 64 px from U's front rank, with a 40 px gap on the Mid axis because the two Mid towers stand there (the same line as `held_gate`) |
| Legs | W `N.moonhulk` to `R.mid.1` walk, 61.0 to 66.0 s (3.9 s); U `N.moonhulk` to `R.mid.gate` rotate, 61.0 to 66.0 s (3.2 s); W `R.mid.1` to `R.mid.gate` walk, 69.0 to 71.25 s (0.9 s: W steps in as U breaks); W `R.mid.gate` to `R.cairn` at rush speed, 71.25 to 72.5 s (1.1 s of the 1.25 s run window; 0.1 s of margin, the one leg that is allowed under the usual 1 s) |
| Timeline | 63.0 formation; 66.0 clash cues; 71.25 resolves for W as the ledger says; 72.0 and 72.4 guard towers fall; 72.5 the Cairn cracks; 74.0 it falls; 74.0 to 75.0 end card |
| Kills | the ledger's, nothing added (`kills_change` is `ledger`) |

Not proven: nobody has seen it drawn, and 1.1 s of rush for five bodies through a 64 px plaza may look like a blur. The prototype of 7.3 includes it as the control ending.

### 7.3 What the Technical Designer must prototype, and what decides

Nothing in 7.1 or 7.2 is proven. The data holds the brief (`late_fight_variants.prototype`); in short:

**Build** (a throwaway Godot scene, no simulation link): the ending from 60.0 s to 75.0 s for three cases, `clean_gate`, `held_island` and `held_gate`, reading every position, leg and event time from the data file. The two held endings use the same fixture (W leads, U wins the last fight, the lead number steps down and stays positive). Tokens at 36 px, the reserve pack as six 14 px dots, the guard towers and the Cairn from the events. Both seats (the player as W and as U). It prints each leg's arrival against `arrive_by_s`, the smallest gap between two tokens, and the frame time (budget: 10 tokens, 6 dots, 4 guard towers).

**Ask the testers** after each ending: (1) "The result felt fair and believable", 1 to 5; (2) "Who won the last fight?"; (3) "Why did the Cairn fall?" (the lead was bigger, the last fight, not sure).

**What decides** (my proposal, not a ruling; the numbers 5, 4.0, 4 of 5, 3 of 5 and 0.5 are mine): at least 5 testers who have not seen the plan; each sees `clean_gate` first, then the two held endings in random order. A held staging passes if its mean on question 1 is at least 4.0 (the Alpha 0.7 acceptance bar), at least 4 of 5 name U as the last fight's winner, and at least 3 of 5 say the lead was bigger. Both pass: ship `held_island` (no hero walks) unless `held_gate` scores 0.5 higher. One passes: ship that one. Neither passes: it does not ship as drawn; letting W win the last fight on screen is not an option (it breaks HF1 and invariant I9), so it goes back to the Gameplay and Systems Designers. **What this cannot tell:** touch feel, speed or heat on a phone, and whether five testers are enough (it is a screen, not a proof).

## 8. Camera

| Setting | Value |
|---|---|
| Default | Whole map, zoom 1.0, no pan. Lanes 1 to 4 (13 to 20 s) stay here because three scenes run at once |
| Focus | Contests 5 to 9 ease in to at most **1.3 x** on the fight, 0.45 s in, hold at least 2 s, 0.6 s out, never showing past the map edge |
| Reduced motion | Stay at 1.0. No shake ever |
| Place-name labels | **Shown only while the camera is at 1.2 x or more** (proposal, section 9). Lane tags TOP, MID and BOT are always shown |

## 9. Readability budget, labels and colours

| Thing | Size | Shape cue |
|---|---|---|
| Hero token | 40 px (36 px in big fights) | circle (you), flat-top hexagon (them), slot letter T J M B S |
| Tower | 28 px | round plate with a tower, team-colour rim; guard towers at 55 percent opacity |
| Camps | 24 / 28 / 36 px | moss leaf, bramble wheel, Mossback dome |
| Objectives, Cairn | 48 px | see section 6 (Stoneback is a rhombus) |
| Labels | **24 px Bold, +1.5 px tracking, `TEXT`, 5 px `VOID` outline** | never smaller (ART-BIBLE 5.2 and 3.9) |
| Minions (suggested) | 14 px dots, not icons | one wave of 4 every 10 s from 2 s, 0.05 u/s |

The validator also checks that no two icons overlap at these sizes.

### 9.1 Labels (review items B4 and P9)

Widths measured with the real font (Barlow Semi Condensed Bold 24 px, +1.5 px tracking), equal to ART-BIBLE 313: STONEBACK 128, MOONHULK 118, MOSSBACK 116, TOP 41, MID 37, BOT 42. The check (`check_labels`, shown by `--report`) puts a box round each label (text width plus the 5 px outline, by 24 px) and fails if the box comes within 2 px of any lane other than its own, any camp, tower, objective icon, spawn pad or other label, if it leaves the arena, or if it crosses the lake shore or the island rim. A lane tag must sit on its own lane. Labels are drawn at 24 px whatever the camera does, so at camera zoom z the box covers 1/z of the map.

**Finding: at the full view not all labels can be placed.** STONEBACK needs 133 px, and the gap between the lake shore and the inner edge of the Bot lane at its row is 117 px, so at zoom 1.0 it cannot sit next to its icon without crossing the shore (a search of the whole arena in 4 px steps found that the closest position clear of everything is 135 px from its icon, too far to name it). MOONHULK has the same problem (123 px box against an island chord of about 107 px at the label's row; on the water the Mid causeway is in the way; closest clear position 135 px away). So the labels are split:

| Label | When | Where (canonical frame, px of the 720 x 760 arena) | Checked at zoom |
|---|---|---|---|
| TOP, MID, BOT | always | on their own lane at (79, 443), (360, 486), (639, 441) | 1.0 and 1.3 |
| STONEBACK | camera 1.2 x or more | (545, 424), below its icon, between the shore and the Bot lane | 1.2 and 1.3 |
| MOONHULK | camera 1.2 x or more | (360, 416), on the island below its icon | 1.2 and 1.3 |
| MOSSBACK | camera 1.2 x or more | (160, 412), below its icon between the Top lane and the bramble camp | 1.2 and 1.3 |

The camera focus holds 1.3 x for at least 2 s on contests 5 to 9 (section 8), so a place name is on screen exactly when that place is the subject. A label that does not fit wholly inside the camera window is hidden (at 1.3 x the Top and Bot tags are cut off at the edge when the camera is centred, so they hide). At 1.2 x the STONEBACK box clears the Bot lane by 4.5 px, the shore by 4.5 px, the bramble camp by 8 px and its own icon by 10 px (`--report` has the full table). The Red-side flip mirrors the labels with the map (drawn and viewed, scratch files).

**This is a proposal, not an accepted rule.** It changes when a label shows, so it needs the UI/UX Designer (6.7.1 row 9 said "raise to 24 px or hide zone labels") and the Art Director. The alternative that needs no ruling is to hide the three place names for good and keep only TOP, MID and BOT; the icons are unique shapes. A label that crosses the shore is not offered as a third choice: ART-BIBLE 3.3 says nothing sits on the shore, and the validator fails it unless a ruling is written into `labels.rim_crossing_waived`.

### 9.2 Colours: token names only, values owned by the ART-BIBLE

The `ARENA_*` placeholders are gone; the bible's 3.8 and 3.9 now give the final tokens. Mapping (`look.tokens` in the data; the validator fails any name that is not a token of bible 3.1 to 3.9, and `BAD`, `GOOD` and the `SIDE_*` flag colours are never allowed on the map):

| Map part | Token |
|---|---|
| Ground | `MAP_LAND` |
| Lake body; its rim and ripple strokes | `MAP_MERE`; `MAP_SHORE` (strokes only, nothing sits on it) |
| Lanes (one road colour, 2 px edge lines white 18 percent) | `PANEL3` |
| Plazas, the island | `PANEL2` |
| Plates under towers, camps and the Cairn | `VOID`, with a 3 to 3.5 px rim in `ACCENT` (yours) or `CORAL` (theirs) |
| Camps (leaf, wheel, dome by shape) | the Jungle ring colour (`#B7F797`, bible 3.5) |
| Moonhulk | disc rim `TEXT2`, crescent `TEXT` |
| Stoneback | `WARN`, rhombus |
| Hero tokens | you: solid `ACCENT` circle, letter `INK_TEAL`; them: solid `CORAL` flat-top hexagon, letter `INK_CORAL`; both with a 3 px `TEXT` rim at 70 percent |
| Labels | `TEXT`, 5 px `VOID` outline |

**Not in the bible** (list for the Art Director): (1) the Jungle ring colour has a value (3.5) and 3.9 says camps use it, but no constant has a name, so the data calls it `JUNGLE_RING`; please name it. (2) The lane edge line (white 18 percent, 2 px) is a value in 3.9, not a token. (3) The 55 percent opacity of the guard towers and the pocket tint (the jungle colour at 7 percent) are my effect values, not colours. Nothing else on the map is new.

## 10. How it was checked

- `python3 tools/validate_arena_map.py --report`: 18 checks pass, plus a text lint of this document (structure, ids, range, mirror, lanes, spawns, towers, camps, water, spacing, stages, units, tally, variants, and four new in 0.3: look, labels, walks, clash).
- `python3 tools/validate_arena_map.py --selftest`: 54 broken copies built in memory and kept in the validator, so anyone can re-run them: 50 of the data (the old 150 px strip, a hexagon Stoneback, an `ARENA_` token, a label on the Bot lane, a label on a camp, a label at zoom 1.0, 20 px labels, a lane leg at walk speed, a missing lane leg, a rejected leg that now fits, `clean_gate` on a Mid tower, winners arriving after the crack, a deleted prototype brief, and the older tower, mirror, spawn, lake and stage cases) and 4 of the document. Every one trips the check it targets; seven also trip a neighbouring check, which is listed in the output.
- Label widths were measured with the real font file (all six equal ART-BIBLE 313). The label positions were found by a search over the arena (the numbers in 9.1 are from it) and then checked by the validator at the zooms in the table.
- The preview was regenerated from the data with the bible's colours read from `ART-BIBLE.md`, and viewed twice: the full frame, then enlarged crops of the east half at zoom 1.0 and at zoom 1.3 (rhombus, labels, shore); the flipped picture (player on Red) was drawn and viewed once as well.

**Not tested:** none of the three late-fight endings has been prototyped or shown to anyone (see 7.3); the place-name rule of 9.1 has not been seen on a phone or by UI/UX; a real phone (touch feel, speed, heat, whether 24 px labels read at arm's length), frame rate, a colour-blind simulation, the flip inside the engine (only drawn), the Barlow font inside Godot (the preview used the font file in a browser), and any trademark or store search.

## 11. Hand-offs

| To | Ask |
|---|---|
| Technical Designer | Read `stages`, `zones`, `nodes` and `edges`. Build the prototype of 7.3 (`late_fight_variants.prototype`): `clean_gate`, `held_island` and `held_gate`, and let the tester question decide between the two held ones. Key choreography on the ids of section 12; use the legs of 7.0 (rotate speed on the lane and tower-site legs) |
| Engine / Graphics Programmer | One `y` flip when the player is Red; labels in screen space at 24 px, shown by the rule of 9.1; budget about 45 icons (16 towers, 13 camps, 4 objectives, 10 tokens) |
| UI/UX Designer | Strips 198 and 132 px are in the map and the validator (P1). Rule on 9.1: place names only while the camera is at 1.2 x or more (alternative: hide them for good). The teal circle / coral hexagon rule stands (R2) |
| Art Director | Name the Jungle ring colour (`JUNGLE_RING` in the data, 9.2) and say whether the lane edge line needs a token. Bible 3.8 and the map agree on the rhombus (B2): delete the "map wins on shapes" ambiguity for Stoneback. B12 (token 36 px circle and 40 px hexagon in big fights) is yours and not done here |
| Gameplay Designer | Confirmations of 7.1 are in (held_island: no walk, a fallen W hero rises at its formation point; held_gate: legs start 61.0 s). Open: the `reset` leg from `top.3` arrives 0.8 s before the take resolves (7.0). Clean ending now has `clean_gate` (7.2). The wave-front formula is the vocabulary's (12.5) |
| IP & Originality Checker | Screen section 3 names and the layout; the Stoneback rhombus and the preview |

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
| `fight_late` | 71.25 | `gate.*` of the match loser laid out as `clean_gate` (7.2), or `held_island` / `held_gate` of 7.1 | `team_fight` (late), then `close_push` |
| `siege` | 75.0 | `cairn.*` of the match loser | `close_push` |

Other ids: lanes `top`, `mid`, `bot` (flavour names Reedrun, Hush Causeway, Lanternway); slots `top`, `jg`, `mid`, `bot`, `sup`; towers `{B,R}.{top,mid,bot}.{outer,inner}` (6 counted per side) and `{B,R}.guard.l`, `{B,R}.guard.r` (scenery); camps as in 12.2 plus `N.mossback`; objectives `N.stoneback`, `N.moonhulk`, `B.cairn`, `R.cairn`; areas `thicket`, `shallows`, `mere`; late-fight variants `clean_gate` (the 81 percent case), `held_island`, `held_gate` (the 19 percent case).

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

Things the numbers say: two bodies do not fit abreast in Bot (64 px against 72 px), so the duo staggers by one step, which the vocabulary already asks for; Top is single file. A long-range hero on the isle reaches every other token there (the isle is 152 px across against a 180 px range), so long range needs no walking in that fight. The wave front is the vocabulary's formula (ACTION-VOCABULARY 2.2, adopted, review item B8): `front = 0.6 * abs(c)` runs from 0 to 0.60, and the clash point moves from `neutral_s` 0.5 towards the loser by `shift_s = (front / 0.60) * max_shift_s`, with `max_shift_s` 0.15, 0.29 and 0.15 for Top, Mid and Bot (`clash_rule` in the data, checked by the validator). A decisive lane beat (front 0.60) ends just in front of the loser's outer tower.
