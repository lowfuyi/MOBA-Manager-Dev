# Diagonal map: feasibility (Q3, 2026-11-24)

Prep for P1 (the Founder's decision: bases in opposite corners). A note only: the map was not edited. Read-only look at
`game/data/arena_map.json`, `game/src/sim/v2/sim_data.gd`, the v2 sim, and `game/src/arena/v2/`.

## 1. How the sim's map, the drawn map and the event log relate today

- **One file, one frame.** `arena_map.json` holds 57 nodes and 80 edges in the canonical frame (x 0 = west, 1 = east; y 0 =
  north = Red's end, 1 = south = Blue's end; every Blue point mirrors a Red one at (x, 1 - y)). `SimData.map()` builds the
  sim's graph from it: edge lengths are the distances between node positions (`SimData.du`, with the map's `x_scale`), lane
  lengths are sums of those, and shortest paths are computed from them.
- **The sim also measures straight-line distance**, about 25 times in `src/sim/v2/`: tower range, fight radius and joining
  a fight, camp and objective reach, "enemies near", the Moonhulk threat range, chase limits. So positions are not just a
  drawing: moving a node, a tower or a camp changes results.
- **The event log stores sim positions** in the same frame (hero positions per step, ward spots since 0.12 Q3, fight
  centres). The arena replays them: `ArenaPlayer` interpolates, `ArenaCam.ground()` / `canon()` turn canonical points
  into ground units and back, `ArenaCam.project()` puts them on screen.
- **The ground art is baked** by `ArenaGround` from the same data (lanes, the Mere, bridges, pits, bases) into one texture
  in the canonical frame.

So today the drawn map IS the sim's map. Lanes are straight: Top along the west side, Bot along the east, Mid down the middle,
bases at the south (Blue) and north (Red) ends.

## 2. Can lane order and travel distances stay identical while the drawing goes diagonal?

**Yes, if the diagonal look is a display-only warp.** The sim and its data positions stay exactly as they are (results, golden
vectors and balance unchanged); a new function maps a canonical point to its drawn point, and every drawing and every
tap goes through it.

The warp that gives the Founder's layout (Top along the west then the north edge, Bot along the south then the east edge, Mid
a diagonal causeway across the lake):
- Let `t` = progress from Blue's base to Red's (1 - y) and `a` = the lateral position (x).
- `P_top(t)` runs from the south-west corner up the west edge to the north-west corner, then along the north edge to the
  north-east corner; `P_bot(t)` runs along the south edge to the south-east corner, then up the east edge.
- Drawn point = blend of `P_top(t)` and `P_bot(t)` by `a`. At `a` = 0.5 the blend is the straight diagonal (Mid); the jungle
  on each side fills the two triangles between Mid and a side lane; the Mere sits on the diagonal.
- Blue's base lands in the south-west corner and Red's in the north-east, as in the genre standard.

**What does not stay identical: the look of speed.** Each side lane is drawn about 1.4 times longer than Mid (two edges of the
square against its diagonal), while the sim's lanes keep their lengths. Heroes in Top and Bot would seem to move about 40%
faster on screen than in Mid, and side fights would look more spread out. Two ways to handle it:

| Route | What changes | Results | Effort |
|---|---|---|---|
| A. Display warp only | Drawing, camera, taps, fog, art | Unchanged (golden hash stays) | M to L (see 3) |
| B. Real diagonal geometry in the sim | `arena_map.json` positions (side lanes really longer), plus A | Change: lane travel, rotations, tower and fight distances move; needs a new calibration, ban experiment and golden vectors, and the Founder's approval (rule R1) | L (A plus about a week of tuning) |

**Recommendation: route A first.** It keeps everything the Founder has already tuned. If the faster-looking side lanes bother
him in a prototype, the warp can stretch time on screen (a per-lane speed factor in the replay only) before route B is
considered.

## 3. What must change (route A)

| Part | Files | Change | Effort |
|---|---|---|---|
| Map data | `game/data/arena_map.json` | Add a `draw` block only (corner layout, warp parameters, drawn lake and bridge outlines). Sim fields untouched; `tools/validate_arena_map.py` learns the new block | S |
| The warp itself | new `ArenaWarp` (display only, never read by the sim; the A1 grep test keeps it out of `src/sim/`) | `to_drawn(p)`, `to_canon(q)` (inverse for taps; numeric, the blend is smooth and one-to-one inside the island) | M |
| Camera | `src/arena/v2/arena_cam.gd` | `ground()` / `canon()` go through the warp; the overview now fits a square, so `arena_view_v1.json` overview fill and pitch need a new pass (the tall-phone work of 0.12 Q6 is redone) | M |
| Ground art | `src/arena/v2/arena_ground.gd`, `arena_ground.gdshader` | Lanes, the Mere, streams, bridges, stairs and bases redrawn in the drawn frame (bake through the warp, or new shapes); scenery placement along the new lane edges; new texture size (square) | L (the biggest part: art, and an IP re-screen of the new layout) |
| Sprites and effects | `arena_view.gd` (`_Sprites`), `arena_fx2.gd`, `arena_hud2.gd` labels | All go through `cam.project`, so they follow the warp; check facing and the "up" direction for portraits | S |
| Fog | `src/arena/v2/arena_vision.gd` | The fog mask is computed in canonical space; either draw it through the warp (a warped mesh) or compute it in the drawn frame. Vision ranges stay sim ranges | M |
| Action camera | `src/arena/v2/arena_chase.gd` | Targets come from sim positions, so they follow the warp; the chase framing and pan limits need re-tuning for a square map | S |
| Squad lane map | `src/ui/components/squad_kit.gd` (ART-BIBLE 6.4 anchors) | New anchors and the schematic lanes drawn diagonally; token positions and the large-text layout re-checked | M |
| Role glyphs | `src/ui/art/icons.gd` (code-drawn role glyphs: the Top and Bot arcs suit the old straight layout) | Redraw Top and Bot as corner shapes; check every place they appear (Draft lane board, Squad, filters) | S to M |
| Choreo | retired with Match Sim v2 (no `Choreo` class left); `walk_legs`, `stages` and `late_fight_variants` remain in the map file | Leave them (unused by the v2 arena) or drop them in the same change | S |
| Tests | `check_touch_arena`, `arena_views_tests`, shots, `check_art` | New expectations for fills, taps and pictures | M |

**Total for route A: about L** (one to two weeks of increments), most of it the ground art and its review. Nothing in
`src/sim/` changes. Before building: the Founder's recordings, a map concept picture, an IP re-screen of the new layout
(IP-RISK-LOG, rows of 2026-11-24), and his sign-off (P1 in `docs/PENDING-CONFIRMATION.md`).
