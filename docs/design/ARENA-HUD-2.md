# Arena HUD 2: design note (R4, P2; 2026-11-27)

Design only: no game file changed. Source: the Founder's description of a competitor's match screen (ideas only; nothing
is copied: names, label text, art and layout are ours). Five ideas: (1) a full-width gold-lead bar under the header with
the difference marked; (2) objective respawn timers as countdown circles on the map; (3) a gold difference between each
pair of opposing lane rows in a bottom panel; (4) ability level chips and a level badge per player; (5) a camera mode
button in the top bar. Each is checked against our arena (teal circle = you, coral hexagon = them, shape before colour;
Arena Dusk; 24 px type floor; 96 px touch floor), against the data the game log really has, and against the arena
draw-call budget.

## 1. Where we start

- **Screen today** (`ScreenMatch`, `src/arena/v2/arena_hud2.gd`): Board (club names, clock, kills, towers, the gold lead
  as a word line "Gold +1,240", who holds Stoneback and Moonhulk), the arena (about 600 px high in normal text, 560 to
  575 px in large text), the view row (Field | Action | All, one button height), Notes (one line of what your team is
  doing, or a commentary line), Feed (two newest events), Speed and Skip.
- **Budget** (`PERF-BUDGET.md` 3.5, arena): 60 draw calls target, 100 hard; 180 nodes target. **Measured today: 29 to 32
  draw calls, 26 nodes** on the Match screen (desktop under Xvfb, DECISIONS C-5 and Q5-2; not a phone).
- **Draw-call rules here** (Godot 4.3 GL Compatibility): every `draw_circle`, `draw_arc` and `draw_colored_polygon` is its
  own draw call; each distinct font size in one control is one more; atlas sprites drawn one after another batch into one.
  So circles and rings are drawn as regions of the arena atlas, never with `draw_arc`.
- **What the game log holds** (the result is decided before the show starts; the HUD only reads the log, rules A1 and R7):
  team gold sampled every 2 s (`log.gold`), kills, towers, objective takes and the times objectives come back
  (`obj_up`), casts, each hero's level-ups (`level` events). **Not in the log:** gold per player over time, ability ranks
  (our kits have no per-ability levels; heroes have one level), cooldowns.

## 2. The five ideas

### 2.1 Gold-lead bar (adopt)

- **Ours:** a thin bar across the full width under the Board (8 px track, the Board keeps its height by moving the gold
  word line into the bar's label). The bar is centred: a teal fill grows to the left when you lead, a coral fill to the
  right when they lead, so the side reads from position and shape of the end mark (a circle end for you, a hexagon end for
  them), not only colour. The difference is written once next to the end mark, 24 px SemiBold ("+1,240"), rounded to
  the nearest 10. Scale: full width = 10,000 gold, clamped; the half-way tick marks 5,000.
- **Data:** `ArenaPlayer.score(t)["gold"]` (already used by the Board). Same number at x1, x2 and after Skip.
- **Cost:** drawn inside the Board control: 2 rects (batch), 1 end mark from the atlas, the label in a size the Board
  already uses: **+1 to +2 draw calls, +0 nodes.**
- **Waits for the recording:** only the look in motion (how often the label changes; we update it at most twice a second).

### 2.2 Objective respawn countdowns on the map (adopt)

- **Ours:** when Mossback, Stoneback or Moonhulk is down, its map icon is replaced by a ring that empties clockwise
  (12 steps baked into the arena atlas, the objective's own colour: gold for Stoneback, moon-blue for Moonhulk, moss green
  for Mossback) with the minutes and seconds left under it at 24 px Bold with the map labels' 5 px outline ("1:24"). Under
  30 s the ring pulses once. When it comes back, the icon returns. No timer for camps (too many marks at once).
- **Data:** the take time (`objs`) and the next `obj_up` event: both known before the show starts.
- **Views:** Field and All show all three; Action shows the ones in frame. In fog the countdown still shows (the time is
  public), but not who is standing near it.
- **24 px floor:** the label is wider than the icon (about 56 px for "1:24"); in Field and All at 720 x 1280 the three
  objectives are far enough apart that labels never touch. Large text: same 24 px (map labels already are), no change.
- **Cost:** rings are atlas regions drawn with the other map icons (batch: **+0 to +1**); the time labels share one font
  size with the place labels: **+1**. **+1 to +2 draw calls, +0 nodes** (labels are drawn, not Label nodes).
- **Waits for the recording:** whether the competitor's timer placement collides with fights on a phone; how big the ring
  needs to be to read at a glance.

### 2.3 Gold difference per lane pair in a bottom panel (do not build yet)

- **Ours, if built:** five rows (Top, Jungle, Mid, Bot, Support), your hero left with a circle, theirs right with a
  hexagon, and between them the gold difference of that pair with an arrow towards the one ahead.
- **Blocked by data:** the log has team gold only. Gold per player over time would be a new, additive field in the log
  written by the simulation, which changes the golden vectors' log hash: a change to `src/sim/`, outside the R2
  approval. **Needs the Founder's approval** before it can be built (log it with the next simulation change).
- **Blocked by space:** five rows at the 24 px floor with two names and a number need at least 5 x 48 = 240 px. Today the
  arena is about 600 px of 1,280; the panel would cut it to about 400 px, or replace the Feed and Notes (they carry the
  kill and objective lines and the commentary). In large text it does not fit at all without a scroll.
- **Proposal:** not a permanent panel. A **"Lanes" sheet** opened from the Board (tap), pausing the show as every sheet
  does: one row per lane pair with the gold difference at that moment, the two levels, and the kills. It costs nothing
  while closed. A sheet is measured with the screen under it (PERF-BUDGET 3.1a): about +6 draw calls while open.
- **Waits for:** the Founder's approval of per-player gold in the log; the recording (how the competitor's panel reads at
  phone size, and whether it hides the map).

### 2.4 Ability level chips and a level badge (badge only)

- **Ability chips: not ours to show.** Our heroes have no ability ranks; chips would show numbers the game does not have.
  Not built. (If kits gain ranks one day, that is a design change with its own approval.)
- **Level badge: adopt, small.** Each hero token gets its level as a number on a small plate at the token's lower right,
  in the side's shape (circle plate for you, hexagon plate for them). 24 px is the floor, so the plate is about 30 px.
  That fits beside Action's tokens (about 44 to 56 px) but would cover Field's and All's (about 30 px), so the badge
  shows in Action and in the Lanes sheet only. (Token sizes are estimates from the match shots, not measured.)
- **Data:** the log's `level` events.
- **Cost:** plates are atlas regions (batch with tokens: **+0**); numbers: one more font size on the token layer: **+1**.
- **Waits for the recording:** whether a level number on every token is wanted, or only on yours.

### 2.5 Camera mode button in the top bar (adopt; biggest win)

- **Ours:** one round button in the Board's top-right corner (96 x 96 touch area, drawn 72 px) showing the current view's
  glyph and its word under it (Field, Action, All); a tap cycles to the next view and shows a short toast with the new
  view's name. No "Cam:" prefix or the competitor's button design (IP-RISK-LOG row of 2026-11-24 on "Field").
- **Why:** the view row costs one full button height (96 px plus gaps). Moving it into the Board gives the arena about
  **+100 px** (600 to about 700 px in normal text; in large text 575 to about 670), more than any other change here.
- **Touch:** 96 px target at the top corner is reachable with a thumb on a 6-inch phone held in one hand only with a
  stretch; Speed and Skip stay at the bottom where the thumb is. Changing the view is rare, so the corner is acceptable.
- **Cost:** replaces the segmented row: **-1 to 0 draw calls, -3 nodes.**
- **Waits for the recording:** where the competitor's button sits relative to its score (so ours is visibly different),
  and the Founder's feel for one-tap cycling against three visible choices.

## 3. Totals and a sketch

| Idea | Decision | Draw calls | Nodes | Needs |
|---|---|---|---|---|
| Gold-lead bar | Adopt | +1 to +2 | 0 | Recording (look) |
| Respawn countdowns | Adopt | +1 to +2 | 0 | Recording (placement) |
| Lane gold panel | Sheet, later | +6 while open | +4 while open | Founder approval (log field), recording |
| Ability chips | Not built | 0 | 0 | Kits have no ranks |
| Level badge | Adopt (Action and sheet) | +1 | 0 | Recording |
| Camera button in the Board | Adopt | -1 to 0 | -3 | Recording |
| **All adopted parts** | | **about 32 to 36 of 60** | **about 23 of 180** | |

```
+----------------------------------------------+
| (o) Corsairs     12:40      Wardens (hex) [V]|  Board; [V] = view button (glyph + word)
|   o 7 towers      12 - 9       4 towers hex  |
|   Stoneback: you                Moonhulk: -  |
| [==========o|        ]  +1,240              |  gold-lead bar (circle end = you ahead)
+----------------------------------------------+
|                                              |
|        arena, about 700 px (was 600)         |
|     (ring 1:24) countdown on a down objective|
|     tokens in Action: level plate "9"        |
|                                              |
+----------------------------------------------+
|  o  Ganking Bot lane                          |  Notes
|  o  Ves took the outer tower in Top           |  Feed
|  [ Speed x1 ]   [ Skip to the end ]   [ ? ]   |
+----------------------------------------------+
```

## 4. Recommendation and order

1. **Camera button in the Board** (one increment; frees about 100 px of arena, which every later idea needs).
2. **Gold-lead bar** and **respawn countdowns** (one increment each; display only, no sim change).
3. **Level badge** in Action.
4. **Lanes sheet** only after the Founder approves per-player gold in the log (a sim change with golden vectors
   re-recorded) and has seen the recording.

All of it after the Founder's recordings (P2 in `docs/PENDING-CONFIRMATION.md`) and, if the diagonal map is built first,
on the new map (the countdown placement depends on where the objectives are drawn: `MAP-DIAGONAL-CONCEPTS.md`). None of
it is measured on a phone.
