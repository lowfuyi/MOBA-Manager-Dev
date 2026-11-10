# Alpha 0.7: Spike results (I-01, "Spikes made permanent")

Date 2026-11-10 · Author: Gameplay Programmer · Plan: `ALPHA-0.7-BUILD-PLAN.md` section 7, I-01 (spikes S1 to S4), rules in sections 3 and 4 · Status: measured, for the Lead Programmer to copy into plan section 9.

**What every number here is.** Taken on the build computer, Godot 4.3 stable, desktop. Touch is simulated (finger events pushed into the viewport, with `override.cfg` `pointing/emulate_touch_from_mouse=true`, as `ui_touch.gd` does). Draw calls, node counts and texture memory are counts from Xvfb with `--rendering-driver opengl3` (software, llvmpipe): **counts carry to a phone, milliseconds do not**. **Nothing here ran on a phone.** The four spikes pass the plan's conditions, with two findings that change the plan's designs (S1 card rule, S4 draw calls).

## Summary

| Spike | Result | Decision |
|---|---|---|
| **S1 nested scroll** | **Pass with the direction lock**, 10 of 10 swipe rows, taps right. The plain ScrollContainer carousel fails 4 of 10 (reproduces K2). **Finding:** the lock only works if the cards inside the Carousel are not Buttons (not `MOUSE_FILTER_PASS` children) and the Carousel owns hit-testing and the tap | Build the Carousel with the lock and owned taps (I-08). Plain-row fallback not needed on this evidence |
| **S2 B11 hole tap** | **Pass** on a scratch `CanvasLayer` pair (sheet 20, overlay 100), 8 of 8 rows including a leak control | Keep the plan: four dim panels plus blocker, no shader. Re-run on the real `BottomSheet` in I-08 and I-12. Card-only fallback not needed on this evidence |
| **S3 Surface** | `StyleBoxFlat` and baked 9-slice **cost the same draw calls once text or icons are on the cards** (17 against 17, 25 against 25 for 8 cards). A shadow adds **0** calls. Baked 9-slice only wins when the backgrounds sit on a separate layer behind the content (17 down to 3) | **Keep `StyleBoxFlat` and the shared `UI.box()` cache** (the plan's fallback). Baked 9-slice stays the documented first fix |
| **S4 HeroCard grid** | One self-drawing `Control` per card passes the node gate (41 against 281 nodes) but **fails the draw-call gate as drawn (107 visible calls, hard limit 100 for the whole screen)**. Two measured fixes: one atlas and one font size per card (65 calls), or **one HeroGrid Control drawing all 40 in three passes (7 calls, 1 node)** | **Do not virtualise** (it does not touch the failing number). Build the Draft grid as **one HeroGrid Control** (recommended), or per-card Controls with one atlas and one text size under a waiver |

---

## S1 Nested scroll (horizontal carousel inside the vertical page)

**Question.** Does a mostly vertical diagonal swipe that starts on the carousel still scroll the page?

**Method.** `tests/spikes/s1_measure.gd`. A page (vertical `ScrollContainer`, scrolled to 360) holds a carousel (200 px tall, 8 cards, 220 px wide). Ten swipes of 240 px in 12 moves, each starting at the middle of the carousel: five angles from the vertical (0, 20, 40, 60, 90 degrees) in two directions (up and left, down and right). Pass rule: under 45 degrees the page must move at least half the swipe's vertical travel and the carousel at most 2 px; 45 and over, the carousel moves at least half the horizontal travel and the page at most 3 px. Fresh rig per mode.

**Result (px moved; page scroll includes the page's own fling after release).**

| Angle, direction | Plain `ScrollContainer` carousel (Button cards) | Lock, Button cards (PASS) | **Lock, cards owned by the Carousel** |
|---|---|---|---|
| 0, up-left | page 437, carousel 0 OK | page 595 OK | page 437, carousel 0 **OK** |
| 20, up-left | page 0, **carousel 160 FAIL** | page 559 OK | page 410, carousel 0 **OK** |
| 40, up-left | page 0, **carousel 381 FAIL** | page 363 OK | page 334, carousel 0 **OK** |
| 60, up-left | carousel 515 OK | page 0, **carousel 17 of 208 FAIL** | page 0, carousel 208 **OK** |
| 90, up-left | carousel 475 OK | page 0, **carousel 20 of 240 FAIL** | page 0, carousel 240 **OK** |
| 0, down-right | page 360 OK | page 360 OK | page 360 **OK** |
| 20, down-right | page 0, **carousel 148 FAIL** | page 360 OK | page 360, carousel 0 **OK** |
| 40, down-right | page 0, **carousel 281 FAIL** | page 360 OK | page 335, carousel 0 **OK** |
| 60, down-right | carousel 300 OK | carousel 17 **FAIL** | carousel 208 **OK** |
| 90, down-right | carousel 300 OK | carousel 20 **FAIL** | carousel 240 **OK** |

Taps on the owned-cards lock: a tap on card 1 gives card 1; a tap with 6 px of finger jitter still gives card 1; a horizontal swipe and a vertical swipe that start on a card tap nothing.

**Why it passes, and the rule it forces.** The lock: after 12 px of finger travel the Carousel decides once per touch (horizontal if |dx| > |dy|, else vertical). Horizontal: it moves its own content and **swallows both the drag and the emulated mouse motion** (if it only swallows the drag, the page scrolls from the mouse motion). Vertical: it stops swallowing, so the page scrolls. Until the decision it swallows (the page does not twitch). **When the cards are `Button`s, or any control with a non-IGNORE mouse filter, the engine keeps routing the later drag events to that child and the page, not to the Carousel, and the lock fails at 60 and 90 degrees (third column).** So: the Carousel is one `Control`, its cards are `MOUSE_FILTER_IGNORE`, and it hit-tests the card under the finger itself and emits `card_tapped(index)` on release if the finger has not moved more than 12 px (screen distance). The same tap rule was needed by the hero grid in S4 (without it a swipe ends as a tap on whatever card is now under the finger).

**Consequences for the plan.**
- I-08 `Carousel.new(card_w, items, see_all)` must take display items (drawn or non-interactive controls), not Buttons. Home's upcoming-games cards and Squad's market row are cards, so this fits; any button inside such a card is not tappable on its own (the card taps).
- Pass condition met. Fallback (plain row plus "See all") and the cut-list item stay in the plan as insurance for the phone test, not as a decision now.
- Reference code: `game/tests/spikes/spike_carousel.gd` (about 90 lines). No inertia on the carousel (the spike moves content only while the finger is down); a fling would be added in I-08.

**Not tested.** A real finger on a real touchscreen. In this engine setup a touch-only stream (no emulated mouse events) did not scroll a plain `ScrollContainer` page at all, and one touch-only run left state behind that changed the next run; so the simulation sends touch and mouse events together (as the existing touch scenes do), and any difference between that and a phone's event order is unverified. Large text (content scale 1.15), the real card art, vertical swipe starting on the carousel's gap, multi-touch.

## S2 B11 hole tap

**Question.** Does a tap inside the coach overlay's hole reach a button inside a `BottomSheet` on a lower layer, with the other dim panels blocking?

**Method.** `tests/spikes/hole_rig.gd` and `s2_measure.gd`: a page button (layer 0), a sheet on `CanvasLayer` 20 (a full-screen scrim, STOP, that counts taps; a sheet panel, STOP; two buttons), an overlay on `CanvasLayer` 100 made of four dim `ColorRect`s (STOP, no shader) around a hole, and an info-step blocker over the hole. The hole is empty space: nothing of the overlay covers it. Taps are simulated finger down and up.

| Row | Result |
|---|---|
| Control: with the dim panels hidden, the same taps reach the scrim and the sheet panel | OK (the leak is detectable) |
| Tap in the middle of the hole presses the sheet button; nothing else reacts | OK |
| Taps on the four dim panels, over the scrim and over the page button are swallowed | OK, no counter moved |
| Edge: first pixel inside the hole presses, 2 px outside is swallowed | OK |
| Tap in the 8 px margin of the hole (outside the button) reaches the sheet panel, not the scrim | OK |
| Info step: the blocker over the hole swallows the tap | OK |
| The hole moves to a second target: it presses and the old target is blocked | OK |
| A drag that starts in the hole and leaves it does not press the button | OK |

**Consequence.** Pass condition met on the scratch pair: keep four dim panels plus the info blocker. I-08 and I-12 re-run the same rows against the real `BottomSheet`: in the check, set `rig.sheet_btn` and the hole to the real controls. The card-only fallback is not needed on this evidence.

**Not tested.** The real `BottomSheet` and `CoachOverlay` (they do not exist yet), a real touchscreen, a drag that starts in the hole and scrolls a `ScrollContainer` inside the sheet (TUTORIAL step 17 style), Android back during a sheet step, large text.

## S3 Surface: `StyleBoxFlat` against baked 9-slice

**Question.** Draw calls of a Draft-like screen of 8 cards, 720 x 1280, under Xvfb software OpenGL.

**Method.** `tests/spikes/spike_surface.gd`: a page background, a title, and 8 cards of 120 px in a `VBoxContainer`. Backgrounds: `flat` (`StyleBoxFlat`, radius 20, border 2), `flat+shadow` (same, shadow 12 px offset 6), `baked9` (`StyleBoxTexture` from one shared 192 x 64 atlas, margin 24, region tile 0), `baked9 layered` (the same baked backgrounds as a separate container behind the text container). Content: none, one label, an icon plus two labels (icon is one shared texture).

| Background | Content none | One label | Icon and two labels |
|---|---|---|---|
| empty page (reference) | 1 | | |
| `flat` | 10 | 17 | 25 |
| `flat+shadow` | 10 | 17 | 25 |
| `baked9` (card holds its content) | 3 | 17 | 25 |
| `baked9 layered` (backgrounds behind) | 3 | 3 | 19 |

Nodes for the same rows: 12, 28, 44 for the first three kinds; the layered kind adds a second container: 21, 37, 53. Texture memory is 6.69 MB for the empty page and 6.83 MB with any of the card kinds (6,694,080 and 6,825,152 bytes, a difference of 131 KB; not broken down further). Runs are repeatable (two runs gave identical counts).

**Reading.**
- A flat card is one call, with or without the shadow (the shadow adds fill area, not calls; matches `PERF-BUDGET.md` 5).
- The baked 9-slice batches to one call **only while nothing else is drawn between the cards**. With a label in each card the draw order alternates card background, text, card background, text, and the count equals `StyleBoxFlat` (17 against 17, 25 against 25). This is the plan's "breaks when text or icons interleave" confirmed.
- The only way to the big saving is a **two-layer card** (backgrounds in one container behind, content in one in front): 17 down to 3 with text, 25 down to 19 with an icon (the icon is a second texture and breaks the text run). The price is a second container with the same row heights, +9 nodes per 8 cards, and every layout change done twice. Not worth it as a default.
- The cost of a surface is not the problem; texture switches are: each switch between the glyph atlas, an icon texture and an untextured shape is one more call (see S4).

**Decision.** The pass condition ("measure") is met; the plan's fallback applies: **keep `StyleBoxFlat` plus the shared `UI.box()` cache**; baked 9-slice remains the documented first fix if the phone test shows jank, and if it is used it should be the two-layer form.

**Looked at (two passes).** Screenshots of the three icon-and-label variants were joined into one sheet and then a 2x crop of flat+shadow against baked layered was opened. First pass: all variants show rounded cards, an icon and a text line, equivalent layout, so the comparison is fair. Second pass: the baked card has crisp corners and border with no seam at the 9-slice margins; the shadow of the flat card is visible and the baked one has none (**the baked tile used has no shadow halo, so the comparison excludes baked elevation; a tile with a halo needs larger margins and content outside the card rectangle and was not measured**); the icon is stretched to an ellipse by the `TextureRect` (a spike artefact, it does not change counts); the layered text sits 16 px lower and to the right (a margin in the spike, cosmetic).

**Not measured.** Fill rate and overdraw (the real cost of shadows on a low-end GPU), milliseconds, a baked tile with a shadow halo, real Android batching (counts come from the same renderer code, but this is not proven on a phone).

## S4 HeroCard: 40-hero grid

**Question.** Node count (gate at most 60) and frame work per filter change (gate under 5 ms headless), and, because section 6 gates draw calls, draw calls too.

**Method.** `tests/spikes/spike_herogrid.gd` with the 40 heroes of `data/heroes.json` (read only), 3 columns of 183 px cards (the large-text card width), inside a vertical page (grid about 2,800 px tall, so about 19 cards are on screen). One filter change = show one role, hide the rest, and set 8 cards to banned or picked states. "Setters plus layout" is the property changes plus a synchronous container sort, headless. Draw calls under Xvfb at the top and bottom of the scroll.

| Design | Nodes in the grid | Setters plus layout, headless | Draw calls on screen, top / bottom |
|---|---|---|---|
| **A** 40 `PanelContainer`s, each `VBoxContainer` plus portrait, name, tag, mark, role chip | **281** (7 per card) | 0.35 ms | 98 / 88 |
| **B** one Control per card, draws itself (style box, disc, lines, text at 3 sizes) | 41 | 0.11 ms | **107 / 97** |
| **B2** as B, every shape from one atlas texture | 41 | 0.13 ms | **107 / 97** |
| **B3** as B2, name and tag at one font size, no initial letter | 41 | 0.15 ms | **65 / 59** |
| **C** one HeroGrid Control draws all 40 in three passes, text grouped by font size, owns hit-testing | **1** | 0.06 ms | **7 / 7** |

(The headless frame itself is paced at about 6.9 ms; the figures above are the work, not the frame. Milliseconds are this computer's, a phone is slower. Counts carry over.)

**Reading.**
- The plan's two gates: nodes at most 60 passes for B, B2, B3 and C and fails for A (281, over the 200 hard limit; the plan's 240 estimate was low). Filter-change work is far under 5 ms for all designs.
- **The draw-call gate is the real finding.** B and B2 emit 5 to 6 calls per visible card, so the grid alone is over the screen's hard limit of 100, before any header, tab bar or slot list. The cause is texture and shape switching inside each card: text at 40, 26 and 22 px (three glyph textures), then untextured shapes. B2 (one atlas for shapes) changes nothing because text dominates. B3 (one text size) halves it to 65.
- **C** wins everything because one Control can order its draws: all backgrounds, then all discs and marks (one atlas run), then the text, grouped by font size (one run per size). Seven calls for all 40 cards, 1 node. Off-screen cards are drawn into the same canvas item, so its cost does not fall when scrolled, but at 7 calls that does not matter.
- **The plan's fallback for S4 (virtualise: build only 12 to 16 visible cards and recycle them) would not help**: the 107 calls are for the visible cards only (by the numbers, off-screen cards of separate Controls are not drawn: 107 calls over about 19 visible cards is 5.6 per card, whereas all 40 would be about 224). Section 9.2's "virtualise" line should be replaced.
- Hit-testing: both C and B3 need the tap rule found in S1 (a release more than 12 px from the press is a drag). `check_gestures` proves, for C and B3, that a tap on the first card taps `brannoch` and a swipe that starts on a card scrolls the page and taps nothing.

**Decision for I-09 and I-16 (recommendation).**
1. **Primary: `HeroGrid`, one Control drawing the whole grid** (C), with the per-hero drawing kept in a small static helper `HeroCard.draw(canvas, rect, hero, state)` so the hero sheet preview and the lane tokens can use the same code. State changes are plain data and a single `queue_redraw`. It follows the S1 rule: it owns hit-testing and the 12 px tap slop. Costs: no per-card focus node (accessibility and keyboard focus are the grid's job), and one redraw covers all 40.
2. **If the Lead Programmer wants one node per hero** (B3): one atlas and one font size per card, and the Draft screen then sits near 65 calls for the grid plus the rest of the page, so it needs the one waiver line of section 6 (between target 60 and hard 100). B and B2 as drawn here are not acceptable.
3. The art bible's card (name at Small 26 and a tag at a smaller size) needs the tag at the same size for B3, or the grouped-by-size drawing of C. This is a one-line question for the UI/UX owner if B3 is chosen.

**Not measured.** Real portraits (placeholder discs here: a real silhouette atlas may add a second texture and a call), the colour-blind marks beyond a text cue and a shape, millisecond cost of drawing 40 cards on a phone's CPU (C redraws all 40 when one changes), large text names such as "Gravenstone" at 26 px (the text is real, the fit audit is I-09's), tall phone, a phone.

---

## How to run (from `game/`, `$G` is the Godot binary, always with `timeout`)

```
# permanent checks (S1, S2 and the touch rows of S4): 27 checks, relaunches itself with touch emulation if needed
timeout 300 $G --headless res://tests/check_gestures.tscn
# spike tables
printf '[input_devices]\n\npointing/emulate_touch_from_mouse=true\n' > override.cfg
timeout 300 $G --headless res://tests/spikes/spike_nested_scroll.tscn      # S1 table, three carousel kinds
timeout 100 $G --headless res://tests/spikes/spike_hole_tap.tscn           # S2 rows
rm -f override.cfg
timeout 100 $G --headless res://tests/spikes/spike_herogrid.tscn           # S4 nodes and timing
# draw calls (software renderer; counts carry to a phone, milliseconds do not)
xvfb-run -a -s "-screen 0 720x1280x24" timeout 170 $G --rendering-driver opengl3 res://tests/spikes/spike_surface.tscn   # S3 (SHOT_DIR=<dir> saves PNGs)
xvfb-run -a -s "-screen 0 720x1280x24" timeout 120 $G --rendering-driver opengl3 res://tests/spikes/spike_herogrid.tscn  # S4 draw calls
```

A script parse error hangs the engine without a message: run `--check-only --script <file>` under `timeout` after editing a spike.

## Files

`game/tests/check_gestures.gd` and `.tscn`; `game/tests/spikes/`: `touch_sim.gd`, `spike_carousel.gd`, `nested_rig.gd`, `s1_measure.gd`, `spike_nested_scroll.gd/.tscn`, `hole_rig.gd`, `s2_measure.gd`, `spike_hole_tap.gd/.tscn`, `spike_surface.gd/.tscn`, `hero_atlas.gd`, `hero_card_probe.gd`, `hero_card_atlas.gd`, `hero_grid_probe.gd`, `s4_touch.gd`, `spike_herogrid.gd/.tscn`. No `class_name` files (no `--import` needed). No change to `src/`, `i18n`, `tools/` or existing tests.
