# Diagonal map: three concepts (R3, 2026-11-27)

Design only: no game file changed. Founder decision of 2026-11-24 (bases in opposite corners), route A of
`MAP-DIAGONAL-FEASIBILITY.md` (a display-only warp: the simulation's map, results and golden vectors stay as they are).
Pictures drawn from `game/data/arena_map.json` by the existing art-preview script, with a new option:

    python3 docs/design/art/arena-map-preview.py --diagonal c1     # or c2, c3; writes docs/design/art/arena-map-diagonal-<c>.svg

PNGs rendered with headless Chromium (`docs/design/art/arena-map-diagonal-c1.png`, `-c2.png`, `-c3.png`). Colours are the
ART-BIBLE tokens the preview already reads. The pictures show **layout only**: they use the 0.8 preview's flat drawing, not
the v2 arena's baked ground art, and the header, text strip and buttons are the preview's placeholders.

## 1. What stays in every concept

- **Our own parts, re-placed:** the Mere (the lake) with the Moonhulk island at the exact centre of the main diagonal, the
  Mid causeway across it, the two jungle pockets with their Moss and Bramble camps and trails, Mossback (west pocket) and
  Stoneback (east pocket), 16 towers, the Cairns and the spawn pads. Blue's Cairn is in the south-west corner and Red's in
  the north-east, as the Founder decided.
- **No river.** Nothing crosses the map on the other diagonal; the lake is the only water.
- **The two neutral objectives are not a mirror pair.** In the simulation Mossback and Stoneback sit at the same distance
  from both bases (fair). The warp keeps them fair on screen (equal drawn distance to each Cairn) but puts them at clearly
  different distances from the lake and in differently shaped pockets, so they do not read as one objective mirrored
  across the map. Moonhulk stays alone on the main diagonal.
- **Display only.** Every number the simulation uses (lane lengths, tower and fight distances, travel times) is unchanged.
  A drawn distance is not a sim distance; section 3 deals with the one place this shows.

## 2. The three concepts

How the warp works: each point's progress from Blue's Cairn to Red's (t) and its side position (s: -1 Top lane, 0 Mid,
+1 Bot lane) are placed on a square. Mid is the main diagonal; a side lane leaves the diagonal by a corner shape h(t)
(a rounded corner, or a bow); an uneven side profile g(s) moves the jungle pockets so the two objectives differ.
Parameters are in the script (`CONCEPTS`).

| | c1 "Corner roads" | c2 "Long bows" | c3 "Winding causeway" |
|---|---|---|---|
| Picture | `art/arena-map-diagonal-c1.png` | `art/arena-map-diagonal-c2.png` | `art/arena-map-diagonal-c3.png` |
| Side lanes | Run along two edges of the square with a rounded corner | Wide arcs that never touch the corners | Wide arcs, as c2 |
| Mid | Straight causeway over the lake | Straight causeway | A gentle S across the lake: leaves Blue's base bending west, crosses the island at the centre, reaches Red's base bending east |
| Mossback (west) | Far out, near Top's corner bend: 327 px from the lake | Close to the lake: 214 px | Far out: 266 px |
| Stoneback (east) | Close to the lake: 260 px | Out by Bot's bow: 258 px | Close to the lake: 212 px |
| Each objective to both Cairns | Equal (495 and 533 px) | Equal (494 and 472 px) | Equal (471 and 498 px) |
| Jungle pockets | Two near-triangles between Mid and the corners | Two rounded pockets | Two pockets of different shape (the S cuts into the west pocket on Blue's half and the east pocket on Red's half) |

## 3. Side lanes look longer: the numbers and the replay speed factor

The feasibility note estimated that side lanes would be drawn about 1.4 times longer than Mid (two edges of a square
against its diagonal). Measured on the concepts, that is not the whole story: **the simulation's side lanes are already
about 1.5 times as long as Mid** (Top 669 px, Bot 641 px, Mid 441 px in arena units), because today's oval map bends them.
What matters on screen is the ratio of drawn length to sim length, Mid against a side lane: a hero walks the sim distance
in the sim's time, so where the drawn lane is relatively longer the hero seems to move faster.

| Concept | Top drawn / sim px | Mid drawn / sim px | Bot drawn / sim px | Side lanes look this much faster than Mid | Replay speed factor for side lanes |
|---|---|---|---|---|---|
| c1 Corner roads | 1,019 / 669 | 574 / 441 | 1,045 / 641 | Top 17%, Bot 25% | 0.86 (Top), 0.80 (Bot) |
| c2 Long bows | 950 / 669 | 574 / 441 | 914 / 641 | 9% | 0.92, 0.91 |
| c3 Winding causeway | 917 / 669 | 631 / 441 | 939 / 641 | Top 4% slower, Bot 2% faster | about 1.0: none needed |

The replay speed factor is 1 / (how much faster it looks): the share of normal speed at which a side-lane walk would have
to be shown so that every lane looks equally fast. Honest limit: the arena has **one clock for all ten heroes**, so a
walk in Top cannot be slowed while Mid plays at normal speed. Where the factor can apply:
- **Action view** (the camera frames one place at a time): when the camera holds a side lane and no other area is on
  screen, the show clock runs at the factor (0.80 to 0.92). The game's result and the log are untouched; the show only
  takes a few seconds longer. Field and All show the whole island and cannot use it.
- **Walk cycle:** a hero's step animation plays faster by the same ratio (1.09 to 1.25 times) so feet do not appear to
  slide; this works in every view.
- **c3 needs neither**: its winding Mid is drawn long enough that all three lanes look the same speed within 4%.

## 4. IP self-screen against the genre habits (IP-RISK-LOG)

Habits checked, from IP-RISK-LOG rows 11, 95, 116, 153 and 172: (H1) bases in opposite corners; (H2) a river along the
other diagonal splitting the map; (H3) two neutral pits as a mirrored pair on that river; (H4) side lanes as two straight
edges meeting at right-angle corners, Mid a straight diagonal (the genre leader's well-known silhouette); (H5) four
mirrored jungle quadrants; (H6) role icons drawn as a square map with a diagonal (row 95: the same concept as a major
game's position icons).

| Habit | c1 Corner roads | c2 Long bows | c3 Winding causeway |
|---|---|---|---|
| H1 corner bases | Shared convention (row 172: pass) | Same | Same |
| H2 river | None | None | None |
| H3 mirrored objective pair | No: different distances and pockets; Moonhulk on the main diagonal, not on a river | No | No |
| H4 corner lanes + straight diagonal Mid | **Close**: rounded, but edges and a straight Mid give the familiar silhouette | Partly: arcs, but a straight Mid | Clear: arcs and an S-shaped Mid through a lake |
| H5 four mirrored quadrants | Two pockets, nearly triangular: watch | Two rounded pockets | Two pockets of different shape |
| H6 role icons | The current "Lane Bows" glyphs (row 153) are drawn from the oval map; any concept needs new glyphs, and a square-with-diagonal glyph must be avoided (row 95) | Same | Same; the S-bend gives a glyph shape of our own |
| **Self-screen** | **Watch (medium)**: the closest to the genre leader's map read at a glance | **Watch (low)** | **Pass (low)** |

This is the Producer's self-screen, not the IP Checker's review; the chosen concept still gets the IP Checker's screen
before it is built (row 172) and the Founder's look against the reference recording.

## 5. Recommendation

**c3 "Winding causeway".** It is the most clearly our own (an S-shaped causeway through our lake to the Moonhulk island,
bow lanes, two pockets of different shape), it keeps the objectives fair on screen without mirroring them, and it is the
only concept where all three lanes look the same speed, so the replay needs no speed factor and no special case in the
Action camera. Costs: the S-bend brings Mid's towers closer to the jungle trails on screen (labels and tap targets there
need a check), and the curved Mid makes the overview fit slightly less tight than c1.

c2 is the fallback if the Founder wants a straight Mid (needs the walk-cycle factor, about 9%). c1 is not recommended: it
reads most like the genre leader's map, and its side lanes look up to 25% faster.

Waiting for the Founder: the choice of concept, his recordings, and sign-off (P1 in `docs/PENDING-CONFIRMATION.md`).
Build effort for route A is unchanged (about L, `MAP-DIAGONAL-FEASIBILITY.md` section 3); c3 adds the winding term to the
warp (small) and new role glyphs (S to M, any concept).
