# Performance budget for a low-end Android phone (Alpha 0.7)

Owner: Engine / Graphics Programmer. Date: 2026-11-09. Status: proposal for review by the Lead Programmer and Technical Director. It covers the Alpha 0.7 screens and the arena that arrives in Alpha 0.8.

**Revision 2026-11-09 (review wave 2a, fix 5).** Changed: the gates in 3.1 now start from the baseline (per-screen allowances with a ratchet, section 3.1a); the shadow limit and the font-pair limit are each one number (3.1a, 3.2); the OFL finding in section 8 is marked fixed; section 7 and 9 now say the probe exists. **Nothing was re-measured in this revision.** Every number below is still from the 2026-11-09 run described in section 2; this revision only re-read that table, the build plan, the art bible, UI-PASS-2 and the code. No Godot run was made for this edit.

**Honest limit up front.** Everything below that is a *measurement* was taken on the build computer with software rendering (Mesa llvmpipe under Xvfb, Godot 4.3 GL Compatibility, 720 x 1280 window). Nothing was run on a phone. Every *budget number* is my proposal from engineering judgement plus those baselines; no number has been checked against real hardware. The Founder's phone, and a low-end phone, decide whether they hold (Alpha exit item 5.1).

## 1. Reference device and frame targets (proposed)

| Item | Proposal | Why |
|---|---|---|
| Reference "low-end" class | Android 9 or newer, 2 to 3 GB RAM, entry GPU (Adreno 505/610, Mali-G52 or PowerVR GE8320 class), HD+ screen (about 720 x 1600), OpenGL ES 3.0 | The game is GL Compatibility, arm64 only (export preset). The canvas is 720 px wide, so the design pixels roughly equal device pixels on such a phone |
| Menus and lists | 60 fps target, never below 30 | Scrolling is where jank is noticed |
| Arena (Alpha 0.8) | 30 fps floor, 60 target; script time per frame at most 4 ms | The show is playback of a finished result (no feedback into the match), so a dropped frame costs looks only |
| Cold start to title | 4 s or less on the reference phone | Founder pillar: ease of use. Not measurable here |
| Memory | Whole app at most 250 MB resident on a 2 GB phone | Unmeasured; phone only |

## 2. Baseline measured today (49 screen states of the current Alpha, after the font change)

Method: `game/tests/ui_shots.gd` tour (the same 49 states the screenshot test visits), with `shot()` replaced by the probe in section 7. Numbers are read from Godot's `Performance` monitors after the frame is drawn. Run on 2026-11-09.

| Screen state | Nodes in screen | Visible | Draw calls | Canvas items | Texture mem (MB) | Video mem (MB) |
|---|---|---|---|---|---|---|
| Title | 10 | 10 | 8 | 105 | 7.7 | 14.1 |
| Home hub | 60 | 60 | 55 | 443 | 9.1 | 15.7 |
| Roster | 36 | 36 | 40 | 347 | 9.1 | 15.7 |
| Free agents | 55 | 55 | 40 | 560 | 8.9 | 16.0 |
| Chemistry (top / scrolled lower) | 114 | 114 | 100 / **150** | 704 / 830 | 9.2 | 16.0 |
| Draft, ban step 2 | 81 | 81 | 42 | 496 | 9.2 | 16.3 |
| Game plan (with trigger plan) | 133 | 133 | 49 | 636 | 9.2 | 16.4 |
| Match (current text-and-clock stub, not the arena) | 20 | 19 | 12 | 221 | 9.2 | 15.7 |
| Match report | **153** | 109 to 127 | 24 to 52 | 482 to 577 | 9.0 | 15.7 |
| Standings | 82 | 82 | 29 | 351 | 9.0 | 15.5 |
| Settings | 65 | 65 | 40 | 514 | 9.0 | 15.7 |
| Season end | 50 | 50 | 21 | 505 | 9.0 | 15.7 |

Across all 49 states: nodes per screen min 10, median 51, 90th percentile 131, max 153; draw calls min 8, median 40, 90th percentile 55, max 150 (Chemistry scrolled, where the bond pentagon draws many separate lines and chips); canvas items median 451, max 1,018 (About, mostly glyphs); texture memory 7.7 to 9.2 MB and video memory 14.1 to 16.4 MB, all of it fonts and render targets because the Alpha has no pictures yet. Whole tree (including the root, tab bar and toasts) is 17 nodes more than the screen figure.

How to read "draw calls": in the Compatibility renderer a draw call is one batch. A `StyleBoxFlat` panel costs one draw call each and breaks the batch around it, so a screen of many cards and labels interleaved costs roughly one call per card plus one per text run. Forty `Label`s on their own cost one draw call (one glyph atlas) but 910 canvas items.

**What the font change did to the baseline (A/B on the same tour, before = Godot default font, after = Barlow Semi Condensed default).** Median draw calls 36 to 40, max unchanged at 150; canvas items median 412 to 451; texture and video memory identical to the byte; hub frame time 24.0 / 25.0 / 23.9 ms before and 23.9 / 24.2 / 25.0 ms after (three alternating runs each, software rendering, so no difference visible). The draw-call rise is because narrower text lets more rows fit on screen (the Home screen now shows the Standing and Cash cards that were below the fold). It is a content-per-screen effect, not a cost per item.

## 3. The budget (proposed; "hard" = fail the check, "target" = aim for)

### 3.1 Screens other than the arena

The "Target" and "Hard limit" columns are the limits for a **redesigned** screen (a screen rebuilt in Alpha 0.7 increments I-15 to I-21, and every new sheet, overlay or component). A screen that is not redesigned yet is held to its own per-screen allowance instead (3.1a), because the baseline already breaks several of these numbers on screens nobody is changing in 0.7.

| Resource | Target | Hard limit | Baseline today | How measured | Where |
|---|---|---|---|---|---|
| Draw calls in one frame | 60 | 100, at the top **and** at the bottom of the scroll (the earlier "scrolled content may peak at 120" is dropped: it was written without a scrolled baseline, and the only scrolled state that is over 100 today is Chemistry, which is a legacy allowance) | median 40, p90 55, max 150 (Chemistry scrolled) | `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` in the probe | Computer (count is renderer-side and the same on a phone; frame time is not) |
| Canvas items in one frame | 700 | 1,200 | median 451, max 1,018 (About); Chemistry scrolled 830 | `RENDER_TOTAL_OBJECTS_IN_FRAME` | Computer |
| Nodes in a screen | 120 | 200 | median 51, p90 131, max 153 (Report) | recursive node count of `App.main._current` | Computer |
| Nodes in the whole tree | 150 (report only) | 250 | max about 170 (screen max 153 plus 17 chrome) | `get_tree().get_node_count()` | Computer |
| Long lists (free agents, results, log) | build at most 30 rows; more rows page or build on scroll | 60 rows | not yet over 30 | node count on the longest data set (a 40-hero grid is 3 columns, 14 rows) | Computer |
| Shadowed surfaces visible at once | **6, one number: the gate is the limit** (reason in 3.1a) | 6 | 0 today (flat panels) | count `StyleBoxFlat` with `shadow_size` > 0 in the visible tree | Computer (count); cost only on phone |
| Glowing things visible at once | 2 | 2 | 0 | same | Computer |
| Screen transition (tab, sheet) | 250 ms or less, no frame over 50 ms | same | not measured | frame times through a transition in the probe | Computer gives a ratio; phone gives the truth |

### 3.1a Gates: allowances for legacy screens, hard limits for redesigned ones

**Why this section exists.** The first version of this document made 100 draw calls and 120 nodes into failing checks for every screen. Against its own baseline that fails on day one: Chemistry scrolled is 150 draw calls (limit 100) and Report is 153 nodes (target 120), Game plan 133. Chemistry is not redesigned in Alpha 0.7 (build plan section 2.1 lists it among the screens that keep `_rebuild`), so a gate that fails there trains everyone to ignore the check. Two kinds of screen, two rules.

**Rule 1, legacy screen (not yet redesigned): the ratchet.** Its row in the allowance table below is its limit for draw calls and nodes. The check fails if a legacy screen goes above its row. A row may go down, never up, except at the two named re-baselines (rule 4). Counts are exact and repeatable (the probe uses a fixed seed and a fixed state), so the headroom in the first column is not for noise; it is the single allowance for what Alpha 0.7 does to every legacy screen before they are redesigned (I-02 raises body text from 28 to 32 px, I-04 clamps buttons to 96 px, both reflow every screen). The headroom is my guess of 10 percent, rounded up to the next 5; it was not measured. Rows that sit 10 percent or more under their allowance make the check print "tighten to N" (the ratchet going down is cheap to automate and keeps the allowance honest).

**Rule 2, redesigned screen: target, hard limit, no ratchet.** When the increment that redesigns a screen lands, its row is **deleted from the allowance table in the same commit**. From then on the screen must be at or under the **target** (60 draw calls, 120 nodes, 700 canvas items) at the top and bottom of every scroll. A screen between target and hard limit needs one waiver line in the table: the number, the reason, and the Technical Director's name; a waiver can never go above the **hard limit** (100 draw calls, 200 nodes, 1,200 canvas items), and the hard limit always fails the check. New sheets, overlays and components start in this tier; a sheet or overlay is measured together with the screen under it.

**Rule 3, a state with no row.** A state the check visits that has no row is held to the hard limits and printed as "NO ROW". From the aggregate figures only Chemistry scrolled is known to be over 100 draw calls and no state is over 200 nodes (max 153), but the 90th percentile is 55 draw calls and 131 nodes, so roughly four other states could sit above 55 and I did not itemise them in this document. The first run of the extended check lists every state of the 49 and each one gets a row at its measured value in that same commit.

**Rule 4, re-baselines.** Exactly two moments may raise a legacy row, each as one commit reviewed by the Technical Director with every changed row written next to its old value: after I-04 (the overflow sweep has landed, so token sizes are final) and after I-22 (the "?" button and help hooks add nodes to every legacy screen). At a re-baseline each legacy row is reset to its measured value, up or down. Outside these two moments a raise needs the Technical Director's written reason in the table.

**Allowances today.** "Today" is the measured value from section 2; the allowance is today plus 10 percent, rounded up to the next 5. Rows marked I-xx leave the table when that increment lands (rule 2); the "then" column is the limit from that day. Only the 12 states itemised in section 2 have rows; the other 37 states of the 49 have no per-state numbers in this document (rule 3).

| Screen state | Status | Draw calls today | Draw-call allowance | Nodes today | Node allowance | Then (redesigned) |
|---|---|---|---|---|---|---|
| Title | legacy, I-04 sweep only | 8 | 10 | 10 | 15 | n/a |
| Home hub | I-15 | 55 | 65 | 60 | 70 | target 60 / 120 |
| Roster (Squad) | I-19 | 40 | 45 | 36 | 40 | target 60 / 120 |
| Free agents | legacy | 40 | 45 | 55 | 65 | n/a |
| Chemistry, top | legacy, not in 0.7 | 100 | 110 | 114 | 130 | n/a |
| Chemistry, scrolled lower | legacy, not in 0.7 | **150** | **165** | 114 | 130 | n/a |
| Draft, ban step 2 | I-16 | 42 | 50 | 81 | 90 | target 60 / 120 |
| Game plan (trigger plan open) | I-17 | 49 | 55 | **133** | 150 | target 60 / 120 |
| Match (text-and-clock stub) | legacy until the arena (0.8) replaces it, then section 3.5 | 12 | 15 | 20 | 25 | arena limits |
| Match report | I-18 | 52 (24 to 52 across states) | 60 | **153** | 170 | target 60 / 120 |
| Standings | I-20 | 29 | 35 | 82 | 95 | target 60 / 120 |
| Settings | legacy | 40 | 45 | 65 | 75 | n/a |
| Season end | legacy | 21 | 25 | 50 | 55 | n/a |

What this table says in words. Chemistry scrolled stays the worst screen in the game (150 draw calls, 2.7 times the 90th percentile) and the table admits it instead of hiding it; it keeps its allowance until someone redesigns it, which Alpha 0.7 does not plan. My reading of the cause (from the pentagon drawing many separate lines and chips, section 2; **not profiled**) suggests drawing the pentagon in one `_draw` as the cheap fix; I did not measure how many calls that would save. Report (153 nodes) and Game plan (133 nodes) are the two nodes allowances above the 120 target, and both are redesigned in 0.7 (I-18, I-17), where rule 2 makes the target binding: if the redesigned versions cannot reach 120 nodes, that is a waiver with a reason, not a quiet raise of the number.

**Canvas items.** One rule for all screens, no allowance rows: target 700, hard 1,200. Two states are known over the 700 target today and are named exceptions to the target only (both are under the hard limit): Chemistry scrolled (830) and About (1,018, mostly glyphs). The other states' canvas-item counts are not itemised here.

**What the check does today, against this table (read from the code, not re-run).** `game/tests/perf_baseline.gd` visits six screens (Home, Squad, Draft, Game plan, Report, Standings) and fails only on the flat hard limits (nodes 200, draw calls 100, texture memory 48 MB); targets are counted and printed, not failed. By my baseline all six are under the hard limits today, so it does not fail on day one, but it also does not visit Chemistry, Settings, Free agents or any scrolled state, and it has no allowance file. To make this section real, the check needs three changes (requests in section 9, for the Lead Programmer or Tools Engineer): read the allowance table from a data file, visit all states including a scrolled one, and apply rules 1 to 3.

**Shadow limit: 6, one number.** Three documents disagreed: the build plan gate said 6, this document said target 6 and hard 8, and `UI-PASS-2.md` 5.1 says "at most 8 shadowed nodes". Pick 6, as target and hard limit at once. Reason: a shadow adds no draw calls here (section 3.4), so its whole cost is fill area on the phone GPU, which I cannot measure on this computer; with no data, the cautious number is the right one, and loosening a limit after a phone test costs one edit, while tightening it after seven screens are built around eight shadows costs a rework. The design already needs few: art bible 4.1 gives real soft shadows to hero surfaces and sheets (Next match, Report hero, the open sheet, the selected tab pill), and `UI-PASS-2.md` 5.1 already says grids and long lists use the flat card. The build plan already says 6 and needs no change. **`UI-PASS-2.md` 5.1 must change from 8 to 6.** Also for the UI/UX Designer: `ART-BIBLE.md` 4.1 lists "cards, list rows, tiles" at E1 with a shadow, which a screen full of rows cannot afford under any limit; the E1 text should say that rows inside a list use the flat variant and only the card that holds them is shadowed. The first redesigned screen (Home, I-15) is the first real count against the 6; none exists yet.

### 3.2 Textures and memory

| Resource | Target | Hard limit | How measured | Where |
|---|---|---|---|---|
| Texture memory, whole app (Godot monitor) | 32 MB | 48 MB | `RENDER_TEXTURE_MEM_USED` | Computer (decoded size is the same; a phone with ETC2/ASTC uses less) |
| Video memory, whole app | 48 MB | 64 MB | `RENDER_VIDEO_MEM_USED` | Computer |
| Distinct textures alive | 30 | 50 | count of `.import` files loaded by a screen | Computer |
| Largest single texture | 1024 x 1024 | 2048 x 2048 (RGBA8 is 16 MB; only the arena ground, and only VRAM-compressed) | file check; `tools/` script over `assets/` | Computer |
| Icons | one shared atlas of at most 512 x 512 for the 30 UI icons and 45 arena icons, drawn at display size x 1 (an icon shown at 48 px is imported at 48 px) | 1024 x 1024 | file check | Computer |
| 9-slice card textures (if the baked-card route of art bible 4.1 is taken) | 3 textures of 128 x 128 or smaller, one per elevation, all in one atlas so the cards batch | 6 | draw calls of ten cards: 10 with `StyleBoxFlat`, **1** with `StyleBoxTexture` sharing one texture (measured, section 5) | Computer |
| Compression | UI art and gradients lossless (PNG/WebP lossless); ETC2/ASTC only for the arena ground, after a banding check | n/a | visual check on a phone; ETC2 bands smooth gradients | Phone for the look |
| Fonts (APK) | 5 static weights, Regular default | 0.5 MB compressed | export size (section 6) | Computer |
| Font memory at runtime | **12 weight-and-size pairs** (the one number: exactly what the art bible 5.2 type scale needs; see below) | 16 (the 12 plus `tnum` variants of the number styles) | count of distinct `(weight, size)` pairs requested through the type scale; the `tnum` variants counted separately | Computer count; RAM on phone |
| Whole APK | 26 MB | 30 MB | export | Computer |

**Font pairs: 12, one number.** The earlier target of 8 could not be met by the approved type scale. Counting `ART-BIBLE.md` 5.2 row by row (weight and size, not the style name): Display ExtraBold 64; Title Bold 48; Value Bold 40 and SemiBold 40; Heading SemiBold 36 and Bold 36 (the go button); Body Regular 32 and SemiBold 32 (buttons); Small Medium 26 and SemiBold 26 (hero names); Caption SemiBold 24 and Bold 24 (map labels, arena only). That is **11 pairs on the Alpha 0.7 screens and 12 once the arena's Bold 24 map labels arrive**; the "about 11" in the first version of this document was the 0.7 count. Getting to 8 would mean merging weights (for example Medium 26 into SemiBold, Bold 36 into SemiBold, dropping the Bold 24 map label), which changes the look that the Producer ruled in R1. The cost side is small and measured: whole-app texture memory is 9.2 MB today with the Regular font at several sizes, against a 32 MB target, so the pair count is not what protects memory. The texture-memory limits in this section do. What a pair costs on a phone (glyph atlas RAM) is **not measured**, and I have not measured what a `tnum` variant adds (I expect it to be a separate glyph cache, from how `FontVariation` works; unverified). So: 12 is the limit, 16 is the hard limit so the number styles can have `tnum` variants, and if the phone test shows memory trouble the weights to merge first are Medium 26 and Bold 36. **No other document has to change for this number.** `ART-BIBLE.md` 5.2 should carry one line "12 weight-and-size pairs, 11 before the arena" so a later scale change updates the count (UI/UX Designer), and the I-02 `UI.font()` helper should expose how many variations it has cached, so the check counts instead of reading the table by hand (Lead Programmer).

### 3.3 Redraw rules for timers and animation

The measured fact driving these rules: Godot redraws the **whole frame every frame** whether or not anything changed, unless `application/run/low_processor_mode` is on. On an idle Home screen, 3 seconds of waiting drew **129 frames with the default and 0 frames with low processor mode on** (this computer, software rendering, `UI.animate` off; `Engine.get_frames_drawn()`). On a phone that is the difference between a warm battery and a cool one, but I could not measure power.

1. **Menus and lists: draw only on change.** Recommended: turn on `application/run/low_processor_mode` for the whole game after the arena has been tried with it (section 8, decision 1). With it on, any tween, label change or `queue_redraw` still draws a frame; a static screen costs nothing. Not yet turned on: it changes behaviour for every screen and I cannot test it on a phone.
2. **A timer changes its text only when the displayed value changes** (draft timer 10 s to 0 s, match clock mm:ss): once per second, never per `_process`. Use a one-second `Timer` or compare the integer before setting `Label.text`. Setting the same text again re-shapes the text and wastes a frame.
3. **The draft timer ring and any progress bar** change through one `Tween` or at most 30 updates per second, not per frame; a ring is a `TextureProgressBar` or one `_draw` call, never a shader.
4. **No `_process` or `_physics_process` in screens that are static.** Turn processing off (`set_process(false)`) when a screen is hidden, covered by a sheet, or the app is paused.
5. **Ambient loops** (the Play button glow breath, art bible 4.2): only after 3 s idle, at most one at a time, paused while scrolling, off when Animations is off. With low processor mode on, a breathing glow keeps the screen drawing continuously; that is the one place a loop costs battery, so the glow breath should be a tween with a long period and be removed if the phone test shows heat.
6. **The arena** draws every frame while playing; at speed x2 it still renders at the same frame rate (the show time runs faster, not the frame rate). When Skip is pressed or the end card shows, the arena stops processing.
7. **Backgrounding:** when the app loses focus, pause the show clock and processing (Android `NOTIFICATION_APPLICATION_PAUSED`).

### 3.4 Shadow and glow cost

Measured here (micro-test, section 5): a `StyleBoxFlat` card costs **one draw call each, with or without the shadow**, so a shadow does not add calls; it adds **fill area** (a 16 px shadow with a 6 px offset grows the quad by about 22 px each side), which is what hurts on a low-end GPU. Overdraw is the real cost and cannot be measured on software rendering in any way that transfers to a phone.

Rules: at most 6 shadowed and 2 glowing surfaces visible; no shadow on rows inside a card (edge only); glow and shadow sizes at or under 18 px; the glow is a pre-baked texture or a `StyleBoxFlat` shadow, never a blur shader (matches art bible 7); no more than two full-screen layers (page gradient plus one scrim); a modal scrim is one `ColorRect`, never a blur. If the phone test shows jank on the chemistry or report screens, the first fix is the baked 9-slice route (draw calls 10 to 1 in the micro-test) and the second is dropping shadows on all but the top two surfaces.

### 3.5 Arena (Alpha 0.8) budget

Counts from `ARENA-MAP.md` 12: 16 towers, 13 camps, 4 objectives, 10 tokens (about 45 icons), plus labels and HUD.

| Resource | Target | Hard limit |
|---|---|---|
| Draw calls in one frame (map, icons, tokens, HUD, feed) | 60 | 100 |
| Canvas items | 600 | 1,000 |
| Nodes in the arena scene (excluding the HUD screen chrome) | 180 | 250 |
| Static map (ground, lake, roads, lane arcs) | baked once into **one** texture, at most 720 x 1040, or drawn in one `_draw` | 2 textures |
| Dynamic sprites per frame | 10 tokens, 16 towers (swap state, do not free), 13 camps, 4 objectives; one atlas so they batch | 60 |
| Labels in the map (24 px, `ARENA-MAP.md` 9) | 12 | 16; text set once per beat, not per frame |
| Ring and ping effects (`intent_ping`) | 3 live at once, pooled, `Sprite2D` scaled, not `_draw`-ed per frame | 5 |
| Texture memory added by the arena | 8 MB | 16 MB (total stays under 48 MB) |
| Script time per frame in the arena (token positions, scoreboard) | 2 ms | 4 ms, measured with `Performance.TIME_PROCESS` plus a manual timer |
| Paths and positions | every position is looked up from the show script built before the first frame; no pathfinding, no per-frame allocation (no `Array` or `Vector2` lists built in `_process`) | none |

### 3.6 Particle limits for Alpha 0.8

Art bible 7 and the VFX brief already say under about 24 live particles per effect. Proposed limits:

| Rule | Limit |
|---|---|
| Node type | `CPUParticles2D` only. `GPUParticles2D` is not used until it has run on the low-end phone (I have no evidence either way on older Mali and PowerVR drivers, so it is not tried before the phone test) |
| Live particles, one effect | 24 (the art bible's figure) |
| Live particles on screen at once | 60 |
| Simultaneous emitters | 3, taken from a pool of 4 emitters that are re-triggered with `restart()` and `one_shot`, not instanced and freed per event |
| Lifetime | 1.0 s or less; looping emitters are not allowed in the arena (bursts at kills, tower falls, objective take) |
| Particle texture | one 32 x 32 soft dot from the shared atlas; at most 16 px on screen |
| Blend | alpha or add, no more than 12 additive particles overlapping a text area (readability: an effect never covers the 24 px labels or blocks a tap) |
| Screen-space | no full-screen particles, no trails, no sub-emitters, no collision |
| Animations off | no particles |

Measured here: a `CPUParticles2D` is **one draw call** whether it holds 24 or 300 particles, and software frame time did not change between 24 and 300 (6.7 to 8.2 ms against 7.5 ms with an empty scene, which is noise at this resolution). So the draw-call count is not the risk. The CPU work of updating each particle on a phone processor is the risk, and that is not measurable on this computer; the limits above are conservative guesses to be raised or cut after the phone test.

## 4. What can be measured where

| Measure | This computer (software render, headless or Xvfb) | Phone only |
|---|---|---|
| Node counts per screen, tree size | Yes, exact (headless is enough: `get_node_count()` and a recursive count) | |
| Draw calls, canvas items, texture and video memory (Godot monitors) | Yes, but only under `--rendering-driver opengl3` with a display (Xvfb). Headless uses a dummy renderer and reports 0 | |
| Texture file sizes, atlas sizes, import settings, APK and PCK size | Yes (file checks, `--export-pack`, `--export-debug`) | |
| Text widths in the real font | Yes, exact in the Godot text server (see section 6, font spike) | |
| Frame time | Only as a **ratio between two builds** on the same machine (hub: 24 ms at 720 x 1280 with a software rasteriser, 7.5 ms for an empty scene). Absolute values say nothing about a phone | Real frame time, 1 percent lows, jank |
| Idle redraw count (does the game draw when nothing changes) | Yes (`Engine.get_frames_drawn()`, section 3.3) | Power and heat |
| Overdraw, fill rate, shadow and glow cost, particle CPU cost | No | Yes (Godot's own `Performance` monitors on a debug build, then Android GPU Inspector or `adb shell dumpsys gfxinfo` for frame times) |
| GPU driver quirks (tnum glyphs, SystemFont fallback, ETC2 banding) | No | Yes |
| RAM and cold start time | No | Yes (`adb shell dumpsys meminfo`, `am start -W`) |
| Thermal throttling after 5 minutes of play | No | Yes (a match is about 5 minutes, so one full session) |

**Phone test to ask the Founder for (cheap, no tools needed):** install the debug APK, play one full match with the draft, and tell us (a) did scrolling ever stutter, (b) did the phone warm up, (c) did any text look wrong or boxy. For numbers: an in-game debug overlay with the Godot monitors (FPS, draw calls, nodes) is a small piece of work I can specify for the Lead Programmer (decision 3).

## 5. Micro-tests behind the shadow, 9-slice and particle statements

One throwaway scene, 720 x 1280, GL Compatibility, Xvfb software rendering, Panels of 330 x 100 px with radius 24. Draw calls are exact; milliseconds are software and noisy (the empty scene was 7.5 ms).

| Case | Draw calls | Canvas items |
|---|---|---|
| 6 `StyleBoxFlat` cards, radius 24 | 6 | 6 |
| 6 with a 2 px border | 6 | 6 |
| 6 with shadow 16, offset y 6 | 6 | 6 |
| 6 with a glow shadow 18 | 6 | 6 |
| 6 `StyleBoxTexture` 9-slice, one shared texture | **1** | 6 |
| 10 `StyleBoxFlat` cards, same four variants | 10 each | 10 |
| 10 `StyleBoxTexture` 9-slice | **1** | 10 |
| 40 Labels at 28 px | 1 | 910 |
| `CPUParticles2D` 24, 100 or 300 particles | 1 | 1 |

What this proves: batching behaviour and counts on this renderer. What it does not prove: that the same batching holds in a real screen where textured cards are interleaved with labels and icons (any texture change between two cards splits the batch), or any GPU cost.

## 6. Font spike (Barlow Semi Condensed, SIL OFL 1.1)

Files: `game/assets/fonts/BarlowSemiCondensed-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf`, `OFL.txt` (93 lines, standard OFL 1.1) and `default_font.tres`. SHA-256 first 16 hex: Regular `e8c7242f612b13d0`, Medium `4998b693a190b76f`, SemiBold `bd299f4bc5b44d30`, Bold `5bd6757e459a110d`, ExtraBold `a8096d0dc3ff22ea`, OFL `186d750eb496a4c1`: all equal to the values in art bible 5.1 and the IP log, so the files in the repo are the files that were checked. The Italic file was not added (the type scale has no italic).

`default_font.tres` is a `FontVariation` over the Regular file with a `SystemFont` (sans-serif) fallback, and `project.godot` sets `gui/theme/custom_font` to it. It takes effect through the existing `UI.make_theme()` theme because that theme sets no default font; checked in the spike by resolving the font of a `Label` and a `Button` under a theme of the same shape, and by the screenshots.

Measured in Godot 4.3's own text server (`game/tests/font_spike.gd`, headless, run twice; exit 0, "ALL OK"):

| Spec claim | Measured | Verdict |
|---|---|---|
| 156 intent labels, longest 239 px at 24 px SemiBold | 156 lines parsed from `ACTION-VOCABULARY.md` 4.3; longest "Following your game plan" **239 px** (with `{lane}`, `{place}`, `{hero}` filled with every real value; Regular 233, Medium 237, Bold 244) | Agrees exactly. Note the widest line is not the longest by characters (26-character "Fight now, objective later" is narrower) |
| Draft titles at Bold 40: 141, 150, 152, 161 px | "Your ban" 141, "Your pick" 150, "Their ban" 152, "Their pick" 161 | Agree exactly. Large-text split "Their" 84 and "pick" 69 fit the 106 px room; all four fit 200 px |
| "Gravenstone" at Small 26 in the 183 px card (text room about 160) | Medium 26 **128 px**, SemiBold 26 **130 px**; widest of all 40 hero names | Fits. The task also asked about **Heading size**: SemiBold 36 is **180 px** and Bold 36 is **183 px**, which equals the whole card and leaves no padding. So Heading 36 does **not** fit a name in the 183 px large-text card (160 px room); hero names must stay at Small 26 (spec already says so) |
| Other art-bible figures | "Northreach Corsairs" Regular 32 = 250, Bold 48 = 391; "Season complete" ExtraBold 64 = 450 | Agree exactly |
| `tnum` through `FontVariation.opentype_features = {"tnum": 1}` | Seven digits at 32 px, Regular: proportional 1s 66 px, 0s 113 px; with tnum every digit string is 108 px (1, 0, 8). Same for SemiBold (114) and Bold (117). "1,111" equals "9,999" and "-12" equals "-88" in width. Rendered picture checked: columns line up with tnum, not without | **Works in Godot 4.3 on desktop.** On Android: the arm64 export template contains `TextServerAdvanced` (the shaping engine that honours OpenType features; strings in `libgodot_android.so`), so I expect it to work, but it was **not run on a phone** |

Every measured width is a whole number of pixels (I did not investigate why; hinting and advance rounding are the likely cause). On a phone the canvas is scaled (for example 1.5x to 2.2x, and 1.15x more in large-text mode), glyphs are rasterised at the scaled size, and widths in logical pixels may differ by a pixel or two. The room margins in the specs (a few pixels for "Gravenstone"-class cases, 3 px at Heading) are therefore the cases to check on a phone.

**What the theme default changed in existing screens.** Same code, same sizes, every one of the 49 screenshots differs. Text is narrower and lighter (Barlow has a smaller x-height and Regular weight is used everywhere, including buttons, where the art bible wants SemiBold; weights are not wired yet by design). Visible effects: Home now fits more above the fold (the Standing and Cash cards peek in), paragraph cards are shorter, long lines wrap less. Nothing overflowed or clipped in the screens I looked at (compared before and after: Home, draft, match, standings, chemistry, roster, report; the other 42 states were diffed by pixel only, not looked at). One pre-existing problem remains and is not worse: the Standings tab label "Trophies" wraps to "Trophie/s" (it was "Trophi/es" before). Test results with the new default: `ui_smoke.tscn` 210 checks, 0 failures; `ui_touch.tscn` 50 checks, 0 failures; screenshot tour exit 0, 49 images. The smoke and touch tests do not check pixels, so they say the screens still build and respond, not that they still look right.

## 7. Measurement probe (reproducing the baseline)

Replace `shot()` in `game/tests/ui_shots.gd` with the version below (in a scratch copy of the project) and run `xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-driver opengl3 res://tests/ui_shots.tscn`; read the `PERF|` lines.

```gdscript
func _count(n: Node) -> Array:
	var total := 1
	var vis := 1 if (n is CanvasItem and (n as CanvasItem).is_visible_in_tree()) else 0
	for c in n.get_children():
		var r := _count(c)
		total += r[0]
		vis += r[1]
	return [total, vis]

func shot(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var sc := _count(App.main._current)
	print("PERF|%s|screen_nodes=%d|visible=%d|draw_calls=%d|objects=%d|tex_mem=%d|vid_mem=%d" % [name, sc[0], sc[1],
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)])
```

The probe is now a repo file, `game/tests/perf_baseline.gd` with `perf_baseline.tscn`, and `tools/run_all_checks.sh` calls it (found on re-reading the repo for this revision; its author is not recorded in the file, I did not run it, and I have not checked that it prints the same numbers as the listing above). It visits six screens, not the 49 states, and applies flat hard limits only (3.1a). The font spike is: `godot --headless --path game --script res://tests/font_spike.gd` (add `-- render=<dir>` under Xvfb for the tnum picture).

## 8. Export size and Android preset (APK impact of the fonts)

Measured with real exports on this computer (`--export-debug "Android"` to a scratch folder, same preset, arm64):

| | Bytes |
|---|---|
| APK before fonts (current repo, default font only) | 24,411,782 |
| APK after fonts | 24,720,434 |
| **Difference** | **+308,652 (+1.26 percent, about 0.3 MB)** |
| Source TTFs | 544,976 (5 files) |
| In the package: imported `.fontdata`, compressed at import | 61,795 + 61,750 + 58,978 + 58,625 + 60,876 = 302,024 |

The `export_presets.cfg` filter (`all_resources`, exclude `tests/*`, include `*.json`) lists all five fonts (as imported `.fontdata` plus `.import` files) and `default_font.tres`, so unused weights ship too (they are small). Checked by listing the exported APK. The pre-existing 24.4 MB APK is almost entirely the engine library (`libgodot_android.so` is 20.1 MB compressed), so the fonts are not the size problem.

**Finding (fixed).** When I measured the two exports above, `assets/fonts/OFL.txt` was **not** in the APK: `all_resources` exports resources only, a `.txt` is not one, and the preset's include filter listed only `*.json`. The OFL says the licence text must accompany the font when it is redistributed, and the About-screen credit does not replace it. **Fixed in commit `d78038d`**: `include_filter` in `game/export_presets.cfg` is now `*.json, assets/fonts/OFL.txt`. Verified by someone other than me, by listing the APK in the repo (`build/moba-esports-alpha.apk`, 24,720,507 bytes): `assets/assets/fonts/OFL.txt`, 4,377 bytes, is in it (Studio Manager review of 2026-11-09). I did not re-export or re-list the APK in this revision. Keep the listing as a standing check on every release APK. The "+308,652 bytes" row above was measured before the fix; the licence file adds 4,377 bytes (arithmetic, not a new export).

## 9. Open items and requests

1. Decision: turn on `application/run/low_processor_mode` after an arena trial (my recommendation: yes, it is free and the idle-redraw measurement is stark).
2. The probe exists as `game/tests/perf_baseline.gd` and is in `tools/run_all_checks.sh`, but it covers six screens with flat hard limits. To match 3.1a it must (a) read the per-screen allowance table from a data file (suggested `game/tests/perf_allowances.json`, one row per state: draw calls, nodes, status, increment, waiver reason), (b) visit all 49 states plus the scrolled state of every scrolling screen, (c) fail legacy screens over their row, redesigned screens over target without a waiver, any screen over a hard limit, and print "NO ROW" and "tighten to N" (Lead Programmer or Tools Engineer, small; it edits game test code, which I do not own).
2a. A shadow counter for the same check (count visible `StyleBoxFlat` with `shadow_size` above 0, gate 6; glowing, gate 2). It does not exist in the probe (Lead Programmer).
3. A debug-only overlay (FPS, draw calls, nodes, texture memory) for phone tests (Lead Programmer, small).
4. Weights are not wired: Bold titles, SemiBold buttons and numbers, tnum on money, ratings, scores and times need `UI.font(weight, tnum)` helpers (UI Programmer, see handback).
5. Everything marked "phone only" in section 4 stays open until the Founder's phone or a borrowed low-end phone has run a full match.
