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
| 8 | fight_late | 71.3 s | **Cairn Gate** of the team that loses the match | Decisive fight on the way in |
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
- Wave 1b: 24 further broken copies (for units, tally, variants and a few old checks) all exit 1, each tripping the check it targets. List in the handback of that task; the copies are not kept in the repo.
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
