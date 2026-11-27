# Diagonal map with a river: three concepts (Match Day M3, 2026-11-27)

Design only: no game file changed. Founder decision D1 of 2026-11-27 (DECISIONS H-1): the map follows the genre structure
the Founder showed in his reference pictures, **with a river** on the other diagonal. This supersedes the "no river" rule
and the c3 recommendation of `MAP-DIAGONAL-CONCEPTS.md` (R3). Route A of `MAP-DIAGONAL-FEASIBILITY.md` still holds: a
display-only warp, so results, balance and the golden vectors stay.

**Reference pictures:** when M3 started, the folder `C:\Users\Fuyi\Downloads\wildrift-ref\` did not exist. The Founder then
said the pictures were there, but at 14:20 SGT the folder held only one file, `QUEUE-MATCH-DAY.md` (the queue text again),
and no image anywhere in Downloads was newer than the run. So I have still not seen the 13 pictures. The concepts follow the structure the
Producer measured from them and wrote into the queue (`docs/design/QUEUE-MATCH-DAY.md`, M3). Nothing was traced.

Pictures: `docs/design/art/arena-map-diagonal-d1.png`, `-d2.png`, `-d3.png` (and SVGs), drawn from
`game/data/arena_map.json` by `python3 docs/design/art/arena-map-preview.py --diagonal d1` (or d2, d3). Layout only: the
0.8 preview's flat drawing, placeholder header and buttons. Desktop rendering; not seen on a phone.

## 1. Our topology already has a river axis (checked in arena_map.json)

| Fact in the data | Value |
|---|---|
| Centre line of the simulation | y = 0.5 (the mirror line between Blue's half and Red's half) |
| On it, west to east | Mossback in the Thicket (0.215, 0.5); the Mere with the Moonhulk isle (0.5, 0.5); Stoneback in the Shallows (0.78, 0.5) |
| Top and Bot cross it | at their midpoints, the clash zones `top_clash` (0.11, 0.5) and `bot_clash` (0.89, 0.5) |
| The jungle pockets | Thicket camps at y 0.585 to 0.70 (Blue) and 0.30 to 0.415 (Red); Shallows camps likewise: each pocket is split by the line, so there are **four quarters** (Blue west, Blue east, Red west, Red east) |
| The two side objectives | at the two ends of that line, inside the pockets |

So the river is a **drawing of the existing centre line**: through the warp it lies on the other diagonal (north-west to
south-east), crosses Top and Bot at their clash points, widens into the Mere around the Moonhulk isle, and puts Mossback
and Stoneback in its water at its two ends. No simulation position moves. Our river is called **the Wend**; the Mere is
where the Wend widens into a lake around the isle.

## 2. The three concepts

All three: Blue's Cairn in the south-west corner, Red's in the north-east; Mid a straight diagonal (d3 slightly bent)
crossing the Mere on its causeway to the isle; the Wend about 0.13 of the map wide, ending at the side lanes (short of the
corners); four jungle quarters with our own low ridges bent around each quarter's three camps (never the reference's wall
pattern) and brush patches beside the river crossings; our towers, names, icons and colours.

| | d1 "River cross" (close to the reference) | d2 "Bending river" | d3 "Wrenfell water" (more of ours) |
|---|---|---|---|
| Outline | Square, north-west corner rounded | Square with small even corners (IP screen: the rounded north-west corner removed) | Softly lobed square (our own island edge) |
| Bases | Quarter-disc plazas in the corners | Same | Our slanted oval plazas |
| Side lanes | Along the edges with soft corners | Wide bows | Wide bows |
| Mid | Straight | Straight | A visible S across the Mere |
| River | Straight band | An S bend about 40 px deep across its flow, back on the line at the isle and at both pits | Width changes by up to 38%, a double bend about 34 px deep |
| The Mere | 128 px | 128 px | 160 px (wider lake) |
| Mossback (west pit) from the lake | 322 px | 224 px | 262 px |
| Stoneback (east pit) from the lake | 273 px | 254 px | 215 px |
| Each pit to both Cairns | equal (530 / 502 px) | equal (477 / 491 px) | equal (496 / 473 px) |

**Objectives fair but not twins:** each pit is the same drawn distance from both Cairns (it sits on the perpendicular
bisector, like the simulation's), but the two pits are at different distances from the lake, in differently shaped
quarters, with different icons and roles (Mossback small and early, Stoneback the mid-game buff). Moonhulk stays alone at
the centre.

## 3. Side lanes look faster: numbers and the replay speed factor

The simulation's side lanes are already about 1.5 times as long as Mid (Top 669, Bot 641, Mid 441 arena px). What a viewer
sees is the ratio of drawn length to sim length, side lane against Mid:

| Concept | Top drawn / sim | Mid drawn / sim | Bot drawn / sim | Side lanes look faster than Mid | Replay speed factor |
|---|---|---|---|---|---|
| d1 | 1,024 / 669 | 574 / 441 | 1,042 / 641 | Top 17%, Bot 25% | 0.85, 0.80 |
| d2 | 944 / 669 | 574 / 441 | 916 / 641 | 8 to 10% | 0.92, 0.91 |
| d3 | 920 / 669 | 631 / 441 | 938 / 641 | Top 4% slower, Bot 2% faster | about 1.0: none needed |

The factor applies as in R3: the walk cycle plays faster by the look factor (every view), and in Action, when the camera
holds one side lane, the show clock may run at the factor. One clock serves all ten heroes, so Field and All cannot slow
one lane. d3 needs none.

## 4. Deliberately the same as the genre, and ours

| Deliberately the same as the genre (Founder decision D1) | Ours |
|---|---|
| Square map, bases in opposite corners | The lake (the Mere) with the Moonhulk isle at the centre, Mid crossing it on a causeway |
| Three lanes: two along the edges, Mid on the diagonal | Our lane curves (the bows of d2 and d3), lane names Reedrun, Hush Causeway, Lanternway |
| A river on the other diagonal | Its name (the Wend), its widening into the Mere, its width and bends |
| Jungle in four quarters | Our camps (Moss, Bramble), their places, our ridges and brush, the trails |
| Neutral objectives at the two river ends | Which objectives they are (Mossback and Stoneback, not the late one), not twins: different distance, shape, role and timing; the late objective (Moonhulk) on the isle, not in a river pit |
| Towers along the lanes | Our tower icons, guard towers as scenery, the Cairns |
| | Every name, icon, colour token and the art (ART-BIBLE), the mirror symmetry across the river (the reference is turned-around) |

## 5. IP self-screen (habits from IP-RISK-LOG; H2 and H3 are now deliberate)

H1 corner bases; H2 a river on the other diagonal; H3 two neutral pits on that river; H4 side lanes along the edges with a
straight diagonal Mid; H5 four jungle quarters; H6 role icons drawn as a square map with a diagonal.

| Habit | d1 | d2 | d3 |
|---|---|---|---|
| H1 corner bases | Deliberate (Founder D1) | Deliberate | Deliberate |
| H2 river | Deliberate; straight band | Deliberate; bends | Deliberate; uneven, bends |
| H3 two pits in the river | Deliberate; not twins, late objective central | Same | Same |
| H4 edge lanes + straight Mid | **Close**: soft corners, quarter-disc bases, rounded north-west corner: the reference silhouette | Partly: bowed lanes | Partly: bowed lanes, bent Mid |
| H5 four quarters | Deliberate; our ridges and camps | Same | Same, plus our plazas and outline |
| H6 role icons | New glyphs needed for any concept; never a square-with-diagonal glyph (row 95) | Same | Same |
| **Self-screen** | **Watch (medium-high)**: the outline, bases and lanes all follow the reference | **Watch (medium)** | **Watch (low-medium)**: the structure is shared, the shapes are ours |

**IP Checker's screen (2026-11-27, a separate role pass, two looks at each picture; not legal advice; no trademark search;
the reference pictures not seen):** d1 **Change** (do not build as drawn: the rounded north-west corner, quarter-disc bases
and a straight river follow the reference outline and serve no game purpose); d2 **Watch medium** (fixes: no rounded
corner, oval plazas, bends at least 0.04 of the map deep, varied width); d3 **Watch low** (preferred: the outline, plazas
and lake that set it apart are visible from afar). The first pass found the river bends too faint to see: they were
offset along the river instead of across it; fixed, and d2 lost the rounded corner. Names: "the Wend" likely clear (a
common word, not searched); Moonhulk and Mossback stay Watch (Scan 1); spare names Moonholm, Moonbarrow. Rows in
IP-RISK-LOG section G (2026-11-27); row 116's "no river" rule is marked superseded. This is not legal advice: a trademark
search and a lawyer's look are still owed before any public release.

## 6. Option B: the late objective at a river end (NOT approved, not built)

In the references both big objectives sit at the river ends and the centre is only a crossing. Ours has Moonhulk (the late
objective) on the isle at the centre. Moving it to a river end would change the simulation's map (route B).

**What would change in the simulation**
- **Positions and graph:** `N.moonhulk` is a node of the Mid lane in `arena_map.json` (the Hush Causeway runs through the
  isle). It would leave the Mid lane; a new node and edges at a river end; Mossback or Stoneback would have to move or
  share that end. Edge lengths and shortest paths change.
- **Distance checks:** about 25 straight-line checks in `src/sim/v2/` (objective reach, group calls, "enemies near",
  fight radius and joining, the Moonhulk threat range) would measure from the new spot.
- **Contest order and travel:** today the Mid laners stand on the Moonhulk spot all game and the whole team gathers in the
  centre; at a river end, the side lane next to it (Top or Bot, by which end) and the jungler would be nearer. That moves
  the late game's weight from Mid to one side lane, changes rotations, and changes the call timing (`group_from_s`,
  `call_lead_s` in `role_ai.gd`).
- **Results:** a new calibration (rating bands), a new 40,000-game hero-by-lane and ban experiment, a Game Plan sweep (the
  objective controls act on these contests), new golden vectors, and very likely a hero tuning pass (Mid and side-lane
  heroes shift).

**Effort:** about two weeks of increments (map data and sim, then about 20 to 30 hours of measurement and tuning on this
machine), on top of the route A build. **Risk:** high: it touches every result, can undo the 0.11.1 and 0.12.3 balance,
and the lane look factors change again.

**Recommendation: keep Moonhulk on the isle (route A).** It keeps all tuning, and it is the single biggest thing that
keeps our map from being a copy of the reference (a lake with an island objective at the centre, instead of a crossing).
Revisit only if testers find the centre unreadable once the river is drawn.

## 7. Recommendation

**d3 "Wrenfell water"**, in line with the IP Checker: it has everything the Founder asked for (river, corner bases, four
quarters, pits at the river ends), all lanes look the same speed (no replay factor), and the parts that make it ours (lobed
outline, oval plazas, the wide Mere, the bent Wend and Mid) read at a glance. If the Founder prefers d2's corner plazas and
straight Mid, the IP Checker's mix works: d2's lanes with d3's outline and plazas and a visibly bent river (needs the walk
cycle factor, about 9%). d1 is the closest to the reference: IP Checker "Change"; not recommended.

The map BUILD waits for the Founder's pick (M9). Not started.
