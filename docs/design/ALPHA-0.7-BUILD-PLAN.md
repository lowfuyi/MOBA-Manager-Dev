# Alpha 0.7 "Guide and Look": Build Plan

Version 1.0 · Date 2026-11-09 · Author: Lead Programmer · Status: for the Producer, Technical Director and QA Manager to review, then to hand to the Gameplay Programmer.

Inputs: `ALPHA-0.7-PLAN.md`, `UI-PASS-2.md`, `TUTORIAL.md`, `ART-BIBLE.md`, `PERF-BUDGET.md`, `COPY-0.7.md` and `copy/en_0_7.json`, the last section of `company/DECISIONS.md`, `company/reviews/2026-11-08-wave1b.md`, and the code in `game/src/core`, `game/src/ui`, `game/src/game`, `game/src/sim` and `game/tests` as it stands today (version label 0.6.0 alpha).

**Every effort number in this document is an estimate** (tool calls for one agent, including its own testing and redo). Nobody has built any of this yet. The measured numbers (section 2) were taken on this build computer, headless or under a software renderer, and say nothing about a phone.

---

## 0. Summary (phone-length)

- **What this is.** 26 build steps (I-00 to I-25). Each is small enough to build, test and screenshot in one sitting (about 25 to 140 tool calls, estimate). The total is about 1,400 to 2,050 tool calls (estimate), or roughly 20 to 28 working days for one builder, fewer with two lanes in parallel.
- **Order.** Safety net and spikes first, then look foundations (type sizes, colours, font, frame), then shared components, then the tutorial engine, then the six screens (Home, Draft, Game Plan, Report, Squad, Standings), then help sheets, lessons and acceptance. This follows UI-PASS-2 8.1 with three changes explained in section 4: the tutorial plumbing (tags and events) lands before the first screen, so no screen is built twice; Report moves ahead of Squad (shorter, and it closes the match-day loop); a spike for the 40-hero grid is added.
- **Three checkpoints** where the Founder can see something real: CP1 after I-04 (same game, new type, colours and font), CP2 after I-16 (Home and Draft redesigned, tutorial engine playable: first APK for the phone test), CP3 after I-25 (everything, full check).
- **Biggest findings from the code** (measured, section 2): every tap on Game Plan, Squad and Draft deletes and rebuilds the whole page (22 ms, 16 ms and 22 ms on this computer; 131 nodes on Game Plan). This is the pattern the plan replaces with build once and update in place. A tutorial that points at a button cannot survive a page that deletes the button on every tap, so this is a hard dependency, not a nicety.
- **Old saves keep loading.** No change to `GameState.VERSION`. Tutorial progress is a new additive `tutorial` key with its own version; missing means "legacy". Section 5.
- **One thing that cannot be settled here:** how it feels and performs on a real phone. First chance is the APK at CP2. Nothing in this plan has run on a phone.
- **Decisions for the Founder: none.** Seven small decisions for other roles in section 12, each with a recommendation.

---

## 1. Evidence and limits

What I did (all on this build computer, Godot 4.3 stable, desktop, headless or Xvfb with software rendering):

| Done | Result | Where it lands in the plan |
|---|---|---|
| Read the specs, the review and all the UI and core code named above | Section 2 and 3 | whole plan |
| Counted nodes per screen (headless) and timed `_rebuild` | Section 2.1 | I-07, I-15 to I-20 |
| Read the font spike and export measurements already made by Engine/Graphics (`PERF-BUDGET.md` 6 and 8) and re-checked tnum widths myself | Barlow and `tnum` work in Godot 4.3 on desktop; `tnum` '1111' = '8888' = 62 px | I-02 |
| Built scratch probes (not repo files) for: B11 (tap through a hole to a button in a sheet on a lower layer), nested horizontal scroll inside a vertical scroll with simulated touch, SVG rasterisation | B11 passed on desktop; the nested carousel **stole a mostly vertical diagonal swipe** (fail); SVG strings rasterise fast enough at start-up | I-01, I-05, I-08 |
| Took the baseline test results from `PERF-BUDGET.md` 6 (Engine/Graphics ran them with the new default font; I did not re-run the full set for this plan) | `ui_smoke` 210 checks, `ui_touch` 50 checks, 0 failures | I-00 re-runs them first |

What I could not do, and the plan does not pretend otherwise:

1. Nothing ran on a phone. Touch feel, scroll feel, frame rate, heat, GPU cost of shadows and glows, text width at real scaled sizes (a pixel or two of drift), and `tnum` or SVG rendering on Android are all **unverified**. The plan puts these in a phone-test list (section 9.4) and an APK at CP2.
2. The draw-call and texture figures need an OpenGL driver; headless reports zero. They are measured under Xvfb with `--rendering-driver opengl3` (software), which is exact for counts and useless for milliseconds.
3. The probes ran against current screens, not the redesigned ones. The redesigned costs are budgets with gates (section 6), not measurements.
4. I did not read all of `COPY-0.7.md` line by line (851 lines). I read its summary, rules and decision table, and the first lines of `copy/en_0_7.json` (540 keys). The plan relies on its stated facts: 540 keys, 16 replace existing keys, "Coach" and "Manager" everywhere.

---

## 2. What the current code does (findings that shape the plan)

### 2.1 Rebuild on every tap (`_rebuild`)

**Cause.** There are 56 references to `_rebuild` in 10 screens: `screen_roster` (9), `screen_game_plan` (8), `screen_training` (8), `screen_draft` (5), `screen_negotiation` (5), `screen_practice` (5), `screen_settings` (5), `screen_finance` (4), `screen_free_agents` (4), `screen_standings` (3). The pattern (for example `screen_game_plan.gd` line 49): `_rebuild()` calls `UI.clear(body)` (`ui.gd` line 197: `queue_free` on every child), then builds the whole page again from `gs` state. Every handler (`_set_value`, `_set_tab`, `_toggle_trigger`, `_choose`, `_toggle_player`, `_on_hero`) mutates state and calls `_rebuild()`. `Main.show_screen` (`main.gd` line 98 to 133) frees the old screen with `queue_free` and fades; that part is fine.

**What it costs (measured, desktop headless, mean of 50 runs; not phone numbers):**

| Screen | Nodes now | Cost per tap |
|---|---|---|
| Home | 60 | not measured (it rebuilds on a few taps only) |
| Squad (closed / picker open) | 36 / 49 | `_rebuild` 16.0 ms |
| Draft (ban step, 40-hero list) | 81 | `_rebuild` 22.3 ms; `_process` timer text 34 microseconds per frame |
| Game Plan | 131 | `_rebuild` 22.0 ms; whole `_set_value` with autosave 24.2 ms |
| Standings (table) | 82 | not measured |
| Autosave alone | | 1.6 ms (JSON stringify and write, a 15.9 KB file), so autosave is not the problem |

A phone is probably 3 to 6 times slower per CPU operation than this computer (my guess; unmeasured), so a slider tap on Game Plan could cost 70 to 150 ms on a low-end phone: visible lag. The richer cards of UI-PASS-2 (shadows, drawn portraits) would make each rebuild heavier.

**Why it also breaks the tutorial.** The coach overlay follows a control's rectangle. A control freed by the next tap leaves the overlay pointing at nothing; the sheet-through-hole path (B11) depends on the button surviving. Scroll position, tween state and the `?` help dot also reset on every tap.

**The replacement rule (every redesigned screen follows it; section 3.2 states the checklist):**

1. `_build()` runs once in `_ready`: it creates the nodes and keeps references.
2. `_refresh()` only sets values: `Label.text`, `value`, `visible`, `modulate`, StyleBox variants. Every component setter ignores a value equal to the one it holds (`set_value(v)` returns early if `v == _v`).
3. Lists that change length (hero grid filtered by role, bench, rows) use one `ListSync.sync(container, keys, make_fn)` helper: keyed reconcile with `move_child` for order, creation for new keys, `visible = false` (not free) for filtered-out keys in the 40-hero grid.
4. Pages and views inside one screen (Game Plan phases, Standings tabs, Squad variants) are children toggled with `visible`, not rebuilt.
5. Sheets close with `call_deferred("queue_free")` after their button's signal has finished (the studio rule: never free a screen inside its own signal). The page behind a sheet is never rebuilt while it is open.
6. Timers and counters redraw only when the displayed text changes (the Draft timer string changes once a second, not every frame).
7. A test proves it (section 3.2, "in-place audit"): record `get_instance_id()` of the scroll container, the first control of every list and every slider before a tap, tap, and require the same ids.

Screens not redesigned in 0.7 (Finance, Training, Free agents, Negotiation, Practice, Settings, Chemistry) keep `_rebuild`; the tutorial steps that touch them (the Practice matches tile on the Plan tab, the Quick Match button) are tagged in I-21. They are listed in the cut list in section 10 as the next candidates.

### 2.2 Tokens, theme and font today

- `ui.gd`: sizes `S_BODY` 28, `S_SMALL` 22, `S_BIG` 38, `S_TITLE` 46, `BTN_H` 92, `R_CARD` 20, `GAP` 14. Colours `BG PANEL PANEL2 PANEL3 ACCENT CORAL GOOD BAD WARN TEXT DIM BLUE RED` as `const`. `box()` builds a new `StyleBoxFlat` on every call (no cache). `make_theme()` builds the theme. Not in code yet: `S_HEAD`, `S_CAPTION`, `S_DISPLAY`, the role colours, `VOID`, `TEXT2` and the rest of the art bible 3 token table.
- Button kinds today: `primary`, `play`, `danger`, `flat`, plus normal. The art bible wants one coral action per screen and an outlined `ban` kind; a `Section` header uses a text prefix ("+ " and "- ") that tests find by string (`ui_shots._open_section`).
- Font: Engine/Graphics has already added Barlow Semi Condensed (five weights, OFL) and `default_font.tres` (a `FontVariation` over Regular with a system fallback), set in `project.godot` as `gui/theme/custom_font`. Result: every existing screen is already in Barlow Regular. **Weights are not wired** (no SemiBold buttons, Bold titles) and **`tnum` is not applied** to numbers. `OFL.txt` is **not in the APK** (the export preset filter lists only `*.json`); licence text must ship with the font (fix is in I-02, `export_presets.cfg` is mine).
- Large text is `Window.content_scale_factor = 1.15` (`App.LARGE_SCALE`), so the logical canvas becomes 626 x 1113; the design canvas is 720 x 1280, stretch `canvas_items`, aspect `expand`. A tall phone is 720 x 1560.

### 2.3 Frame

`main.gd`: a `ColorRect` background, margins 24/48/24/24, a tab bar of five buttons (`TAB_H` 104), toasts as a `Control` inside `Main`, no `CanvasLayer`. `screen.gd`: `setup(title, back, scroll)`, an 80 px header with a typed "<" back, a `ScrollContainer` with a `body` `VBoxContainer`, `tab_id()` and `is_tab_root()`. `App.go()` swaps screens; `App.go_tab()` builds a fresh tab root each time.

Consequence for the new work: sheets need a `CanvasLayer` above the screen (layer 20), toasts above that (30), the coach overlay above all (100). None exist. They are built in I-03.

### 2.4 The test contract (what existing tests touch, so a redesign does not silently break them)

Tests call private methods by name. A redesign either keeps the name as a thin wrapper or migrates the test in the same step (rule R4 in section 3.1).

| Screen | Names called by `ui_smoke.gd`, `ui_touch.gd`, `ui_shots.gd`, `ui_pass_tests.gd` |
|---|---|
| Main | `_current`, `_tabbar`, `_tab_buttons`, `_toasts` |
| Roster (Squad) | `_toggle_slot`, `_assign`, `_toggle_player`, `_auto` |
| Draft | `_on_hero`, `_apply`, `_sel_hero`, `_start_match`, `_ai_wait`, `_process` |
| Game Plan | `_set_tab`, `_set_value`, `_toggle_trigger`, `_set_jf`, `_coach`, `_reset` |
| Standings | `_set_tab` (smoke also calls `_tab` on another screen) |
| Match | `_shown`, `_finished`, `_continue`, `_process` |
| Settings | `_rebuild`, `_confirm_reset` |
| Training, Negotiation, Free agents, Finance, Practice, Prematch | `_choose`, `_toggle`, `_toggle_heroes`, `_coach_all`, `_adj`, `_wage`, `_set_len`, `_make_offer`, `_done`, `_msg`, `_next_sort`, `_next_role`, `_more`, `_confirm_release`, `_release`, `_start`, `_quick_match`, `_finish_game` |

String-matching tests: `ui_shots` finds section buttons by the "+ " text prefix and by label text (`_tap_text`); renaming strings (the Coach rename, 16 replaced keys) can break these. I-00 greps for every key used in tests and fixes them in the same step as the merge.

### 2.5 Save and device state today

- `GameState.VERSION := 1`. `load_save()` returns `null` when the `version` field differs, so **bumping the version would silently discard every old save**. It must not change.
- `GameState.from_dict` fills defaults for missing keys (that is how Alpha 0.2 and 0.3 saves still load). `next_season()` builds a `carry` dictionary (line about 842) and calls `new_game(..., carry)`; a key not copied there is lost at season end.
- Device state lives in `user://settings.cfg` (`[ui]`, `[tips]`), written by `App._write_setting`; one-time hints are `App.tip_seen/tip_mark/tips_reset`.

### 2.6 Strings

`game/i18n/en.json` has 645 keys, ASCII only. `tools/check_strings.py` reads `en.json` only (and the code's `Strings.t("key")` uses). The word "advisor" appears at two keys and "owner and coach" at one (the Coach rename list is in `COPY-0.7.md` 6.2). Narrative has written `docs/design/copy/en_0_7.json`: 540 keys, 524 new and 16 replacing existing ones, to be **merged once** into `en.json` (Narrative did not touch `en.json`). Decision: merge once in I-00, so lanes never edit `en.json` in parallel (after the merge, only the UI lane adds keys, section 4 ownership table).

### 2.7 Performance baseline and gates

Baseline (Engine/Graphics, `PERF-BUDGET.md`, and my node counts above): the current screens are small (36 to 131 nodes). Proposed budgets from `PERF-BUDGET.md`: draw calls per screen target 60, hard 100; nodes per screen target 120, hard 200; texture memory target 32 MB, hard 48 MB; at most 6 shadowed and 2 glowing surfaces visible; shadow and glow size at or under 18 px; no blur shaders; at most two full-screen layers; timers redraw only when the displayed value changes. The budgets are still a proposal; this plan treats them as gates that fail a check (I-00 builds the check) and asks the Technical Director to confirm them (section 12).

**The 40-hero draft grid is the cliff.** If a hero card is a `PanelContainer` with 5 child nodes, 40 cards cost 240 nodes, over the 200 hard limit before anything else is on screen. HeroCard must therefore be **one `Control` that draws itself in `_draw`** (portrait, name, tag, state marks). Spike S4 (I-01) measures the alternatives and settles it.

---

## 3. Rules for every increment

### 3.1 Rules

- **R1. Definition of done for any increment.** (a) Builds with no script errors; `--import` was run if a `class_name` file was added. (b) The fast check loop (3.3) is green. (c) New tests exist and pass (3.2). (d) Screenshots were taken at the matrix subset named in the increment and looked at twice (first pass layout, second pass text fit, touch size, colour dependence). (e) Strings: no hard-coded visible text; `check_strings.py` clean. (f) The in-place audit passes for a redesigned screen. (g) A handback in the studio format, with what was not tested.
- **R2. One increment, one dispatch, one owner.** Lanes in section 4. If an increment needs a change in a file owned by another lane, it lists it as an "integration line" for the owner (at most about 5 lines) and does not edit it.
- **R3. No simulation change.** `src/sim/*.gd` and `data/*.json` of the sim are not changed except the read-only helpers named in I-06. The golden vectors (`tests/golden`) must not change; I-00 records their hash and the fast loop checks it.
- **R4. Test migration happens in the same increment as the screen change.** A screen increment either keeps each old private method name (thin wrapper over the new code) or edits the old test lines, in the same dispatch. Never leave a red test for the next step.
- **R5. Explicit types for `:=` on untyped values; no method named `_set`; no screen freed inside its own signal; `--import` after adding a `class_name` file** (a script load error hangs the engine; run every Godot command with `timeout`).
- **R6. Presentation never feeds back into results.** The match, report and plan are decided first; views only show them. The tutorial game and the help system never write game results (section 7).
- **R7. Rollback.** Every increment ends in a state that can be reverted on its own: new files plus a few integration lines. Where an increment changes a shared file, the handback lists the exact hunks. The Producer commits after review, one commit per increment (so rollback is `git revert` of that commit).

### 3.2 Standard tests ("T-std") and how tests are organised

The existing big files (`ui_smoke.gd` 403 lines, `ui_touch.gd` 291, `ui_shots.gd` 204, `run_tests.gd` 138) are single files that every lane would edit. I-00 changes the structure so lanes can add tests without sharing a file:

- **`run_tests.gd` auto-discovers `res://tests/*_tests.gd`** (each file has `run(check: Callable)`), loaded with `load(path).new()` so no `class_name` or `--import` is needed. New logic tests are new files.
- **Screen tests are per-area scenes** named `res://tests/check_<area>.tscn` (headless, ends with " N checks, 0 failures"), and touch ones `check_touch_<area>.tscn` (need `override.cfg` with `pointing/emulate_touch_from_mouse=true`). `tools/run_all_checks.sh` and the new `tools/check_fast.sh` loop over `tests/check_*.tscn`. The old `ui_smoke`, `ui_touch` and `ui_shots` stay and keep running; only the UI lane edits them.
- **Screenshot matrix.** `tests/shots_matrix.tscn` runs under Xvfb and discovers modules `tests/shots/shots_<screen>.gd`, each with `static func run(ctx)`. A run takes env `SCREENS=home,draft` and `VARIANTS=normal,large,cb,tall` to select a subset. Variants: **normal** (720 x 1280), **large** (content scale 1.15), **cb** (colour-blind mode on), **tall** (720 x 1560). Output PNG name: `<screen>_<state>_<variant>.png`. The full UI-PASS-2 7.1 matrix is 6 screens x several states x 4 variants (72 images); each screen step takes only its own screen's subset, the full set runs in I-25.

The T-std set every screen increment adds (names are the check labels):

| Test | What it proves | Type |
|---|---|---|
| `build_<screen>` | the screen builds with a fresh game, every state in the shot list, no `ERROR:`/`SCRIPT ERROR` in the log | smoke, headless |
| `fit_<screen>_<variant>` | no control's rect leaves the 720 px (626 px large) frame; no Label is clipped to fewer than N characters (the Standings "Playo-ffs" class of bug); button hit area at least 96 x 96 px | headless audit, fixtures from UI-PASS-2 7.1 (longest club name 19 characters, hero names to 11, 5 digits of cash) |
| `inplace_<screen>` | the in-place rule: instance ids unchanged across each state-changing tap; `_rebuild` is not called (a counter on the screen) | smoke |
| `touch_<screen>` | a vertical swipe starting on a card, a button, a carousel and a slider scrolls the page; a tap taps; Android back (`GO_BACK`) navigates | touch scene, simulated |
| `cb_<screen>` | in colour-blind mode, no meaning is carried by colour alone: every state-bearing control has a text, shape or icon cue (checked by reading a `cue` meta set by components, plus screenshot review) | smoke plus review |
| `nocolour_words` | no visible string uses a colour word (Narrative's script as a test) | pure logic |
| `tags_<screen>` | the tutorial ids listed for this screen in TUTORIAL 8 exist and are visible on the right state | smoke |

### 3.3 Check commands

`$GODOT` is the Godot 4.3 binary. All Godot commands are run from `game/` with `timeout`.

**Fast loop** (after every change; new file `tools/check_fast.sh`, written in I-00, target a few minutes, estimate):

```
python3 tools/validate_data.py
python3 tools/check_strings.py
cd game && timeout 600 $GODOT --headless --import                          # after any new class_name file
timeout 600 $GODOT --headless --script res://tests/run_tests.gd            # logic, golden vectors, string and data tests, all *_tests.gd
timeout 600 $GODOT --headless res://tests/ui_smoke.tscn                    # must end " 0 failures"
for each tests/check_*.tscn: timeout 600 $GODOT --headless res://tests/<name>.tscn
touch scenes with override.cfg present, then removed (as run_all_checks.sh does)
sha256 of game/tests/golden/* equals the value recorded in I-00
```

**Per-screen screenshot run** (under Xvfb, software OpenGL; never in the headless loop):

```
SHOT_DIR=<dir> SCREENS=<screen> VARIANTS=normal,large,cb,tall \
  xvfb-run -a -s "-screen 0 720x1280x24" $GODOT --rendering-driver opengl3 res://tests/shots_matrix.tscn
SHOT_DIR=<dir> xvfb-run -a -s "-screen 0 720x1280x24" $GODOT --rendering-driver opengl3 res://tests/ui_shots.tscn   # old tour, 49 images
```

**Perf gates** (I-00 adds `tests/perf_baseline.gd` and a one-line scene, from `PERF-BUDGET.md` 7; run under Xvfb opengl3; prints `PERF|` lines and fails above the hard limits): draw calls 100, nodes 200, texture memory 48 MB per screen.

**Full check** (`bash tools/run_all_checks.sh $GODOT`, about 25 minutes, run in the background): **only at the end of 0.7 (I-25)**, and once at CP2 before the APK. It adds `calibrate.py 40000 --check`, `pytest`, the soak run and everything above. Since R3 forbids simulation changes, the calibration is expected unchanged; the fast loop's golden hash is the early warning.

---

## 4. Architecture, lanes and file ownership

### 4.1 Lanes

| Lane | Who | Works in (only) |
|---|---|---|
| **G1 (UI lane)** | Gameplay Programmer | all existing files in `game/src/ui/`, `game/src/core/app.gd`, `game/i18n/en.json` (after the I-00 merge), `game/tests/ui_smoke.gd`, `ui_touch.gd`, `ui_shots.gd`, `ui_pass_tests.gd`, `alpha6_tests.gd`, new `game/src/ui/components/`, new `game/tests/check_ui_*`, `check_touch_*`, `tests/shots/` |
| **G2 (Guide lane)** | Gameplay Programmer (second instance, or the same one after G1 reaches the gate) | new `game/src/tutorial/`, new `game/src/core/device_state.gd`, new data `game/data/tutorial_v1.json`, `help_v1.json`, `glossary_v1.json`, `lessons_v1.json`, new `game/src/game/tutorial_game.gd`, **and** the read-only game-code helpers of I-06 (`game_state.gd`, `sim/draft.gd`, `sim/report.gd`, `data/clubs.json`), `game/tests/tutorial_tests.gd`, `check_tutorial_*`, `check_save_compat` |
| **E (Art/Perf lane)** | Engine / Graphics Programmer | new `game/src/ui/art/` (`tex_cache.gd`, `icons.gd`, `badge_style.gd`, `silhouette.gd`, `avatar.gd`, `surface.gd`), `game/assets/`, `game/tests/perf_baseline.gd`, `art_tests.gd`, `check_art.tscn` |
| **Q (QA)** | QA Automation | reads everything; writes the audits listed in I-25 under `game/tests/audit_*`; owns the seed fixtures in `game/tests/fixtures/` |
| **N (Narrative)** | Narrative Designer | `docs/design/copy/*.json` only; the Producer or G1 merges; Narrative never edits `en.json` |
| **L (Lead Programmer)** | me | `tools/run_all_checks.sh`, `tools/check_fast.sh`, `game/export_presets.cfg`, review of every handback, this plan |

When there is a single Gameplay Programmer, G1 and G2 run one after the other in the order given in section 4.3; the file split is the same so a later switch to two agents costs nothing.

### 4.2 Ownership of hot files (never two writers)

| File | Writer | Others who need a change |
|---|---|---|
| `src/ui/ui.gd`, `main.gd`, `screen.gd`, `app.gd` | G1 only | G2 and E send "integration lines" in their handbacks (each is a few lines: create the overlay in `Main`, forward events, add `help_id()`) |
| `src/ui/screen_*.gd` | G1 only | G2's tags are added by G1 as each screen is rebuilt (the tag list per screen is in the increment) |
| `src/game/game_state.gd`, `sim/draft.gd`, `sim/report.gd` | G2 in I-06 and I-13 only; **nobody else in 0.7** | G1 needs a data helper: request it in a handback; G2 adds it in the next G2 slot |
| `i18n/en.json` | G1 (append only, one block of keys per increment, sorted by prefix) | G2 and others hand G1 a key list; Narrative's patch files are the source |
| `tests/run_tests.gd`, `tools/run_all_checks.sh` | L (I-00 only) | nobody, because of auto-discovery |
| `project.godot`, `export_presets.cfg` | L | any change request goes in a handback |
| `data/clubs.json` (club `colors` and `badge` ids), `data/heroes.json` | G2 in I-06 for clubs (additive fields only); heroes are read-only | |

### 4.3 Dependency order and what can overlap

```
I-00 -> I-01 -> I-02 -> I-03 -> I-04 (CP1)
                  |       |
                  |       +-> I-05 (E, art code; starts after I-02) --+
                  +-> I-06 (G2, core hooks; starts after I-00) -------+
I-03 -> I-07 -> I-08 -> I-09 -> I-10    (components, G1; need I-05 for badges and silhouettes)
I-06 -> I-11 -> I-12 -> I-13 -> I-14    (tutorial, G2; I-12 needs I-03 hooks and I-08 BottomSheet)
I-10 -> I-15 Home -> I-16 Draft (CP2) -> I-17 Game Plan -> I-18 Report -> I-19 Squad -> I-20 Standings -> I-21
I-14 + I-16 -> I-22 Help and glossary -> I-23 Lessons -> I-24 -> I-25 (CP3)
```

Real parallelism with two builders: G1 runs I-02 to I-04, I-07 to I-10, I-15 to I-21; E runs I-05 beside them; G2 runs I-06, I-11 to I-14 beside I-07 to I-10, then I-22 to I-24 beside the later screens. The screen tags that the tutorial needs arrive with each screen (G1); the first-run walkthrough only plays end to end when I-16 to I-20 are done, so G2 tests it earlier on the old screens through "fallback card" mode (tag missing, step shows its card without a hole) and runs the full 20-test set in I-25.

---

## 5. Save-file compatibility plan

1. **No `GameState.VERSION` bump.** (A bump makes `load_save` return `null` and drops the player's save.)
2. **New additive key `tutorial`** (TUTORIAL 6.1): `{"v": 1, "state": "running"|"done"|"skipped"|"legacy", "step": "<id>", "game": {"live": bool, "n": int, "plan": {...}}}`. Its own `v` is the tutorial schema version.
3. **`from_dict` default.** A missing `tutorial` key becomes `{"v": 1, "state": "legacy"}`. This is the whole migration for 0.1 to 0.6 saves.
4. **`TutorialState.migrate(dict)`** (pure function, in I-11): `v` absent or 1 returns the dict unchanged; an **unknown higher `v`** (a save from a future build opened by an older one) is treated as `legacy` and not modified, so it never crashes; a malformed `state` string falls back to `legacy`; a `step` id that no longer exists in `tutorial_v1.json` falls back to the first step of its chapter (resume survives data edits).
5. **Carry across seasons.** `next_season()`'s `carry` dictionary and `new_game()`'s carry handling must copy `tutorial` (otherwise it resets to `legacy` at season end; found by reading line about 842). I-06 does it and tests it.
6. **Device state** in `settings.cfg` sections `[tutorial]`, `[lessons]`, `[help]` (old `[tips]` keys map into `[help]`) via a new `DeviceState` class (I-11), so `app.gd` is not edited by G2. The existing `tip_seen/tip_mark/tips_reset` stay until I-24 retires the old tips.
7. **Fixtures.** I-00 captures real 0.6 saves as `game/tests/fixtures/save_0_6_a.json` (new game, round 1), `_b` (mid-season with a custom plan and a hired free agent), `_c` (season end, before `next_season`). Test `check_save_compat` loads each through `GameState.from_dict`, runs `plans_for`, `next_game`, a full game, `next_season`, `to_dict`, reloads, and asserts the tutorial key is `legacy` and survives. It also runs a save written with `tutorial.v = 99`.
8. **Sandbox games never touch the save.** The tutorial game writes nothing to `d["fixtures"]`, standings, Form Rating, morale, cash, pace log, fatigue or `save_seed` stream (I-13 tests all of them by deep-comparing `gs.d` before and after, except the `tutorial` key).
9. **`Delete save and start over`** also clears the save's tutorial state (the save is gone); device flags stay (TUTORIAL 6.3).

---

## 6. Gates (budgets that fail a check)

| Gate | Limit | Where checked |
|---|---|---|
| Nodes per screen (the whole `_current`) | target 120, hard 200 | `perf_baseline` in I-00, from I-07 on every screen step |
| Draw calls per frame | target 60, hard 100 | same, Xvfb opengl3 |
| Texture memory | target 32 MB, hard 48 MB | same |
| Shadowed surfaces visible / glowing | 6 / 2 | audit in the components gallery and per screen |
| Idle redraws | none when nothing changes (`Engine.get_frames_drawn()` constant for 2 s) | I-25 with the Settings low-processor decision |
| Tap response | no component rebuild on tap; in-place audit | each screen step |
| `_rebuild` on a redesigned screen | zero calls on a state-changing tap | `inplace_<screen>` |
| Touch target | 96 x 96 px hit area, text floor 24 px | `fit_<screen>` |
| Golden vectors | unchanged hash | fast loop |

---

## 7. The increments

Format for each: **Goal · Lane · Needs · Files (create C, change M) · Helpers and components · Strings · Tests · Acceptance · Rollback · Effort (estimate)**. "Screenshots" means the matrix subset. Component names follow UI-PASS-2 section 5 and 5.16 (names there are suggestions; these are the names to use).

### I-00 Safety net, structure and the one string merge

- **Goal.** Make everything after this measurable and conflict-free: structure for tests, fixtures, baselines, and merge Narrative's 540 keys once.
- **Lane / Needs.** L designs, G1 does the work; nothing before it.
- **Files.** C `tools/check_fast.sh`; C `game/tests/perf_baseline.gd` and `.tscn` (the probe from `PERF-BUDGET.md` 7); C `game/tests/shots_matrix.gd` and `.tscn`, `game/tests/shots/shots_baseline.gd` (wraps the existing 49-shot tour as one module); C `game/tests/fixtures/save_0_6_*.json`; C `game/tests/check_save_compat.gd/.tscn`; M `game/tests/run_tests.gd` (auto-discovery loop; keep the existing explicit calls until their files are renamed, then delete them); M `tools/run_all_checks.sh` (loop over `check_*.tscn`; add golden hash and perf gate); M `game/i18n/en.json` (merge `docs/design/copy/en_0_7.json` through a one-off script kept at `tools/merge_copy.py` that refuses duplicates and reports the 16 replaced keys); M `game/tests/*` where a test or `ui_shots` matches a replaced string.
- **Helpers.** None new in game code.
- **Strings.** 540 keys merged (524 new, 16 replaced; the Coach and Manager rename comes with the merge, so `advisor` and `owner and coach` disappear here, not later). `check_strings.py` must show 0 unknown keys; unused-key notes are expected (the new keys are not used yet) and are informational by design.
- **Tests.** Fast loop green before and after the merge; `check_save_compat` (fixtures A to C load, full game, next season); perf baseline printed for the 6 main screens and stored in the handback as the "before" table; golden hash recorded in `tools/check_fast.sh`.
- **Acceptance.** Fast loop green; the 49-image tour still runs; no old test line failed because of a replaced string (all fixed); baseline numbers recorded.
- **Rollback.** Revert the commit (the merge is one commit; `en.json` is the only shared file).
- **Effort (estimate).** 25 to 40 tool calls.

### I-01 Spikes made permanent

Four short spikes. Each ends as a test that stays in the repo, because the answers decide later designs.

| Spike | Question | Pass condition | If it fails |
|---|---|---|---|
| **S1 Nested scroll** | A horizontal carousel inside the vertical page: does a mostly vertical diagonal swipe starting on the carousel still scroll the page? **Scratch result: it stole the swipe (fail).** | A custom direction lock in the Carousel: after 12 px of travel, a drag is horizontal only if |dx| > |dy|, otherwise it is forwarded to the parent `ScrollContainer`. Tested with simulated touch from 5 start angles | Carousel becomes a plain horizontal `HFlowContainer` with a "See all" link (Home upcoming row, Squad market row); the cut list says this feature goes first anyway |
| **S2 B11 Hole tap** | A tap inside the coach overlay's hole reaches a button inside a `BottomSheet` on a lower layer, with the other three dim panels blocking. **Scratch result: pass on desktop in the probe (not run on a phone).** | The same test, in the repo, using the real `BottomSheet` once I-08 exists; until then, a scratch `CanvasLayer` pair | Stage-B steps become card-only (Next on the card runs the control's action; TUTORIAL 11 fallback); the sheet steps lose their ring but keep their text |
| **S3 Surface** | `StyleBoxFlat` (one draw call per card, shadow adds fill area only) against a baked 9-slice `StyleBoxTexture` from one shared atlas (one draw call for 10 cards in `PERF-BUDGET.md` 5, but it breaks when text or icons interleave) | Measure a Draft-like screen with 8 cards in both ways, draw calls under Xvfb | Keep `StyleBoxFlat` + shared `UI.box()` cache; baked 9-slice stays the documented first fix if the phone test shows jank |
| **S4 HeroCard nodes** | A 40-hero grid as 40 `PanelContainer`s with children against 40 single-`Control` cards that draw themselves | Node count at most 60 for the grid; frame work per filter change under 5 ms headless | Virtualise: build only the visible 12 to 16 cards and recycle them while scrolling |

- **Files.** C `game/tests/spike_*.gd` plus scenes (kept in `tests/spikes/`, excluded from the export by the existing `tests/*` filter); C `game/tests/check_gestures.gd/.tscn` (S1 and S2 as permanent checks, with `override.cfg` touch emulation).
- **Strings / helpers.** none.
- **Acceptance.** Each row has a measured result written in the handback and copied into section 9 of this plan by L. The Carousel and HeroCard designs are chosen from the result.
- **Rollback.** Delete the spike files.
- **Effort (estimate).** 30 to 45 tool calls.

### I-02 Tokens, theme, font weights, large text

- **Goal.** One global change to the look: all type sizes, colours, radius, button height and the font weights, then the whole app re-shot and fixed. The app still plays exactly as before.
- **Lane / Needs.** G1 (`ui.gd`, `app.gd`) plus L for `export_presets.cfg`. Needs I-00.
- **Files.** M `src/ui/ui.gd`; M `src/core/app.gd` (large-text hook only); M `game/export_presets.cfg` (add `assets/fonts/OFL.txt` to `include_filter`; L does this); C `game/assets/fonts/font_weights.tres` set if needed.
- **Helpers.** In `ui.gd`: sizes `S_DISPLAY 64, S_TITLE 48, S_BIG 40, S_HEAD 36, S_BODY 32, S_SMALL 26, S_CAPTION 24`, `BTN_H 96`, `R_CARD 24`, `GAP 16`, `TAB_H 112`, `HEADER_H 96`; the ART-BIBLE 3 colour tokens (`VOID, TEXT2, TEAL_HI`, the five role colours, side colours) kept alongside the old names so unredesigned screens do not break (old names become aliases); `UI.font(weight: String, tnum: bool = false) -> Font` returning cached `FontVariation`s for Regular, Medium, SemiBold, Bold, ExtraBold with `opentype_features = {"tnum": 1}` for numbers; `UI.num_label(...)` that applies tnum; `UI.box()` gets a cache keyed by (colour, radius, border, shadow); `make_theme()` sets weights per control (buttons SemiBold). `UI.button` clamps `custom_minimum_size.y` to at least 96 (the quick fix for the 64 to 76 px buttons on unredesigned screens).
- **Strings.** none new.
- **Tests.** `check_tokens` (a pure-data test of token values against the ART-BIBLE 5.2 table, so a drifting constant fails); font test: `tnum` digits '1111' and '8888' have the same width in `UI.font("SemiBold", true)`; all five `.fontdata` resolve; the 49-image tour in normal and large text; fit audit on the six existing main screens.
- **Screenshots.** The full old tour (49), normal and large. First look: overflow and clipped text; second look: weights, tnum columns, button heights.
- **Acceptance.** No overflow on the old screens at 720 and 626 px; every button at least 96 px high; the OFL text in a test export listing (`--export-debug` to scratch, list the APK); smoke and touch green; node counts within 10 percent of baseline.
- **Rollback.** Revert; the aliases mean no other file changed.
- **Effort (estimate).** 40 to 60 tool calls.

### I-03 Frame and tutorial hooks

- **Goal.** Build the layers and the two small registries the tutorial and the sheets need, before any screen is rebuilt.
- **Lane / Needs.** G1. Needs I-02.
- **Files.** M `src/ui/main.gd`, `src/ui/screen.gd`, `src/core/app.gd`; C `src/ui/event_bus.gd` (`EventBus`, a small `Node` created by `Main`, reachable as `App.bus`); C `game/tests/check_frame.gd/.tscn`.
- **Helpers.**
  - `Main`: a content layer, a sheet layer (`CanvasLayer` 20), a toast layer (30), an overlay slot (`CanvasLayer` 100, empty until I-12); header 96 px, tab bar buttons 96 and `TAB_H` 112; tab labels never wrap mid-word (one line, shrink to fit or ellipsis at the Caption floor; this fixes "Trophi/es").
  - `UI.tag(control, id, tap_source := true)`: stores the id in the control's meta, registers in a registry, and (when `tap_source`) connects `pressed` to `App.bus.emit("tap:" + id)`. `UI.find_tag(id) -> Control` returns the live visible control or null. Registry entries are weak and cleaned when a node exits the tree.
  - `EventBus.emit(name: String, data: Dictionary = {})`, `seen(name)`; a bounded ring buffer of recent events (for `skip_if event_seen`).
  - `Main.show_screen` raises `screen:<help_id>`; `Screen.help_id() -> String` (default: derived from the class name; each screen overrides).
  - `Screen` frame gets an empty slot for the "?" button (filled in I-22) and exposes `scroll_to(control)`.
- **Strings.** none.
- **Tests.** `check_frame`: the layer order (instance order and `layer` values), a tag is found only while visible, freeing a tagged node removes the entry, `tap:` events fire from a button press and from a simulated tap, `screen:` events fire on `show_screen`, back button still works (touch scene); tab label "Trophies" fits on one line at 626 px.
- **Screenshots.** Old tour subset: Home, Plan, Club, Settings (normal and large).
- **Acceptance.** Old tests green; no screen changed except the frame.
- **Rollback.** Revert; no data changes.
- **Effort (estimate).** 50 to 70 tool calls.

### I-04 Overflow sweep of the screens that are not redesigned (CP1)

- **Goal.** Everything that is not one of the six screens looks right at the new sizes: Finance, Training, Chemistry, Free agents, Negotiation, Practice, Prematch (Match day), Settings, Club select, Title, About, Season end, Game over, Match.
- **Lane / Needs.** G1. Needs I-02, I-03.
- **Files.** M the matching `screen_*.gd` and `player_view.gd` (layout fixes only: wraps, minimum sizes, `kv_row` that squeezed values to one character per line); M `ui_shots.gd` only if a name changes.
- **Strings.** none.
- **Tests.** `check_fit_legacy`: the fit audit runs over all of these screens in normal, large and tall.
- **Screenshots.** The old tour in all four variants (49 images times 4; looked at by pixel diff against I-02 first, then by eye for the changed ones).
- **Acceptance.** No overflow, no mid-word break, all targets 96 px; **CP1: the Producer can show the Founder the same game in the new type, colours and font.**
- **Rollback.** Per-screen revert.
- **Effort (estimate).** 40 to 60 tool calls.

### I-05 Art code: icons, badges, silhouettes, avatars (E lane, parallel)

- **Goal.** Everything the screens draw that is not a font: club badges, hero silhouettes, initial avatars, role icons, drawn icons for arrows, ticks, stars (the font has none).
- **Lane / Needs.** E. Needs I-02 (tokens); can start in parallel with I-03.
- **Files.** C `src/ui/art/tex_cache.gd` (`TexCache`: key to `ImageTexture`, rasterises SVG strings with `Image.load_svg_from_string`, one cache, evicts nothing in 0.7, tracks bytes), `icons.gd` (`Icons.draw(canvas_item, id, rect, colour)` and `Icons.tex(id, size)`), `badge_style.gd` (`BadgeStyle.for_club(club_id) -> Dictionary`: the HSL algorithm of ART-BIBLE 6.3, **pure logic, no UI classes**, so it is unit-tested headless), `silhouette.gd` (`Silhouette.draw(ci, hero_id, rect)` by role family), `avatar.gd` (`Avatar.draw(ci, player_id, rect, ring)`: initial on a role ring, teal circle for you, coral hexagon for them), `surface.gd` (decided by S3); C `game/assets/icons/*.svg` (starting from `docs/design/art/ic_role_*.svg`); C `game/tests/art_tests.gd` (headless logic) and `check_art.tscn` (draws into a `SubViewport`, compares the non-empty bounding box).
- **Strings.** none (labels come from the owner screens).
- **Tests.** `art_tests`: the **10-club badge table** of ART-BIBLE 6.3 (each club id gives the documented hue, accent and shape, and no two clubs collide within the stated distance); deterministic output for a seed; every one of the 40 heroes and all players produce a drawable silhouette or avatar; colour-blind pairs stay distinguishable by shape (teal circle against coral hexagon). `check_art`: texture memory after warm-up under 8 MB (budget).
- **Screenshots.** A badge sheet, a silhouette sheet and an icon sheet (one image each, normal and colour-blind).
- **Acceptance.** All three sheets look right on two passes; IP and Originality Checker has the list of shapes (hand-off).
- **Rollback.** Delete the directory; nothing else depends on it until I-07.
- **Effort (estimate).** 60 to 90 tool calls.

### I-06 Core hooks: read-only helpers and the tutorial save key (G2)

- **Goal.** Everything the screens and the tutorial need from game code, in one place, with no change to results.
- **Lane / Needs.** G2. Needs I-00. **Requires Systems Designer approval** of the helper list (they are read-only, section 12).
- **Files.** M `src/game/game_state.gd`: `upcoming(n) -> Array` (read-only over `d["fixtures"]`), `cut_gap() -> Dictionary` (over `standings()`), `tutorial() -> Dictionary` and `set_tutorial(dict)` (read and write the `tutorial` key), default in `from_dict`, `tutorial` copied in `next_season()`'s `carry`; M `src/sim/report.gd`: `Report.team_kills(res)` (sums `Report.kda`); M `src/sim/draft.gd`: `Draft.best_slot_for(team, hero_id)` (extracted from the inline logic in the Draft screen's `_actions`; the screen is not changed yet); M `data/clubs.json`: additive `colors` and `badge` ids (validated by `tools/validate_data.py`, which G2 extends); C `game/tests/hooks_tests.gd`.
- **Strings.** none.
- **Tests.** `upcoming` and `cut_gap` against hand-made fixtures; `best_slot_for` equals the old inline result over every hero in a recorded draft (so the screen can switch later with no behaviour change); `team_kills` equals the sum; `tutorial` default is `legacy`; `next_season` keeps it; golden hash unchanged; `validate_data.py` passes with the new club fields; the 3 save fixtures from I-00 still load.
- **Acceptance.** All logic tests green with unchanged golden vectors; no sim constant touched.
- **Rollback.** Revert the commit.
- **Effort (estimate).** 25 to 40 tool calls.

### I-07 Components A (flat, no gestures) and the gallery

- **Goal.** The building blocks every screen reuses that need no gesture.
- **Lane / Needs.** G1. Needs I-03, I-05.
- **Files.** C `src/ui/components/depth_card.gd` (`DepthCard`: elevation 0 to 2, tint, selected outline (**shape cue as well as colour**), pressed state), `section_header.gd` (replaces the "+ "/"- " text prefix with a drawn chevron; **the old tests that look for the prefix are migrated here**, rule R4), `chip.gd`, `segmented.gd` (`Segmented.new(options, selected, on_change, fit)`), `icon_button.gd` (96 x 96 hit area, smaller visual), `empty_state.gd`, `edge_meter.gd`, `hero_stat.gd`, `list_sync.gd` (`ListSync.sync(container, keys, make_fn)`), `toast.gd` (moved out of `main.gd`; the `App.toast` API is unchanged); C `tests/components_gallery.tscn/.gd` (one scene that shows every component in every state, used for screenshots and for the audit); C `tests/check_components.gd/.tscn`.
- **Helpers.** Every component has a `tut_id` optional parameter (calls `UI.tag`), an equality-guarded setter for each value, and sets a `cue` meta for the colour-blind audit. Components recompute on `resized` (never from a fixed 720 px).
- **Strings.** none new (uses merged keys).
- **Tests.** For each component: builds; setter with the same value changes nothing (instance ids and a `draw` counter); fits the long-text fixtures in normal and large; hit area; colour-blind cue present; shadow count in the gallery within the gate (at most 6 shadowed, 2 glowing).
- **Screenshots.** Gallery: normal, large, colour-blind, tall.
- **Acceptance.** Gallery looks right on two passes; node count per component recorded (budget in the handback).
- **Rollback.** Delete `components/`; the `section_header` migration of tests is the only shared hunk.
- **Effort (estimate).** 50 to 70 tool calls.

### I-08 BottomSheet and Carousel (the gesture components)

- **Goal.** The two components with real touch risk, with the touch tests that guard them.
- **Lane / Needs.** G1. Needs I-01 (S1, S2 results), I-07.
- **Files.** C `src/ui/components/bottom_sheet.gd` (`BottomSheet.open(title, build_content, build_footer, size := "M")`, own `CanvasLayer` 20, scrim is one `ColorRect` (no blur), drag handle, tap on scrim and Android back close it, `close()` always `call_deferred`), `carousel.gd` (`Carousel.new(card_w, items, see_all)` with the S1 direction lock); C `tests/check_sheet.gd/.tscn`; C `tests/check_touch_gestures.gd/.tscn`.
- **Strings.** `sheet.close` (merged copy has the keys).
- **Tests.** Sheet: opens and closes by every route (button, scrim, back, swipe down), the page behind keeps its scroll position and its instance ids, only one sheet at a time, a sheet opened from a sheet replaces it; a button inside the sheet receives a real tap (B11 uses this in I-12); Carousel: horizontal swipe scrolls the carousel, **vertical and diagonal swipes starting on the carousel scroll the page** (5 start angles), a tap on a card taps, items beyond 8 show "See all"; both in large text.
- **Screenshots.** Gallery subset: sheets in S, M, L sizes; carousel at rest and scrolled.
- **Acceptance.** The gesture tests pass; if S1's lock cannot be made reliable, the plain-row fallback ships and Home's carousel is cut (section 10).
- **Rollback.** Revert; no screen depends on it before I-15.
- **Effort (estimate).** 60 to 80 tool calls.

### I-09 Cards: PlayerCard, HeroCard, LaneRow and LaneBoard

- **Goal.** The three picture-led components of the draft and the squad.
- **Lane / Needs.** G1. Needs I-05, I-07; S4 result from I-01.
- **Files.** C `src/ui/components/player_card.gd` (`PlayerCard.make(pid, variant, opts)`: avatar card for bench, lane token, free-agent card), `hero_card.gd` (`HeroCard.make(hid, state, opts)`: **one `Control` drawing itself**, states: available, selected, banned (a drawn X and a text cue, not colour only), picked by you, picked by them (circle against hexagon)), `lane_row.gd` and `lane_board.gd` (five rows, you left and them right); C `tests/check_cards.gd/.tscn`.
- **Strings.** from the merged copy (`draft.*`, `squad.*` keys); add none unless a gap is found, in which case G1 asks N.
- **Tests.** Nodes for a 40-card grid at most 60 (S4 gate), 40 cards in under 5 ms to update a filter (headless; ratio against baseline, not an absolute claim), the longest hero name "Gravenstone" at Small 26 fits the 183 px large-text card (measured 128 to 130 px in `PERF-BUDGET.md` 6), all five state cues present, avatar for 19-character club names and 11-character player names.
- **Screenshots.** Gallery: grid in all states, lane board with two filled and three empty rows; normal, large, colour-blind (**the banned and picked states must be readable in grayscale**), tall.
- **Acceptance.** Gate numbers recorded; colour-blind screenshot looked at twice.
- **Rollback.** Delete the files.
- **Effort (estimate).** 70 to 100 tool calls.

### I-10 PhaseStrip, DetentTrack, Podium and RankRow

- **Goal.** The Game Plan and Standings components.
- **Lane / Needs.** G1. Needs I-07.
- **Files.** C `src/ui/components/phase_strip.gd` (`PhaseStrip.new(phases, selected, on_select, vertical := false)`; the "Overall, Early, Mid, Late" strip, pips show which controls act in which phase from a per-control phase map derived from `data/game_plan_v0.json` at load), `detent_track.gd` (`DetentTrack.new(id, value, on_change, labels)`: big stepped slider, replaces the "-- - 0 + ++" button row, dragging snaps to 5 detents, keyboard-free, 96 px hit area, an **inert** look for controls that do nothing in the selected phase, per UI-PASS-2 7.6 finding 1), `podium.gd`, `rank_row.gd`; C `tests/check_plan_components.gd/.tscn`.
- **Strings.** from the merged copy (`gp.*`, `standings.*`).
- **Tests.** Setting a value from code and from a drag gives the same result; a drag across the page scrolls it when started outside the track; equality guard; tnum widths in `RankRow`; Podium with 3 equal clubs, with 19-character names.
- **Screenshots.** Gallery subset, four variants.
- **Acceptance.** As I-09. This closes the component set.
- **Rollback.** Delete the files.
- **Effort (estimate).** 50 to 70 tool calls.

### I-11 Tutorial state, data and persistence (G2; pure logic)

- **Goal.** The brain of the tutorial, testable with no UI.
- **Lane / Needs.** G2. Needs I-06.
- **Files.** C `src/tutorial/tutorial_state.gd` (`TutorialState`: pure; `feed(event) -> Array` of effects; stages and chapters; `skip_if event_seen`; resume; Skip with Undo; `migrate()` (section 5); **no UI classes, so it runs in `run_tests.gd`**), `src/core/device_state.gd` (`DeviceState`: typed access to `[tutorial]`, `[lessons]`, `[help]` in `settings.cfg`; reads via `ConfigFile`, old `[tips]` mapped), C `data/tutorial_v1.json` (the 27 steps of TUTORIAL 3.2 with ids and events; text keys point to the merged `tut.*` strings), C `game/tests/tutorial_tests.gd` (tests 1 to 9 of the 20-test plan in TUTORIAL 9 that need no UI: step order, events completing steps, skip rules, resume after save and load, `legacy`, unknown `v`, malformed step id, replay increments `game.n`, debug line text).
- **Strings.** none (keys in the merged patch). A test checks every `text_key` in the JSON exists in `en.json`.
- **Tests.** As listed; plus `validate_tutorial.py` added to `tools/` (every step id in TUTORIAL 8 appears exactly once, every event name is in the legal list of TUTORIAL 7.5, every key exists), wired into `check_fast.sh` by L.
- **Acceptance.** The full step table loads; the state machine walks the happy path and the skip path with a scripted event list.
- **Rollback.** Delete `src/tutorial/` and the data file; nothing depends on it.
- **Effort (estimate).** 50 to 70 tool calls.

### I-12 CoachOverlay (spotlight hole)

- **Goal.** The visible half: dim, hole, ring, pointer and card.
- **Lane / Needs.** G2. Needs I-03 (hooks, layer slot), I-08 (BottomSheet), I-11.
- **Files.** C `src/tutorial/coach_overlay.gd` (`CoachOverlay`, on `CanvasLayer` 100: **four dim panels** around a hole rectangle (no shader), an info-step blocker over the hole, a pulsing ring, a pointer, a card with Next and Skip and an optional one-tap shortcut button; it follows `UI.find_tag(id)` each frame **only while the rectangle changes** and waits for layout to settle for 2 frames; scrolls the target into view (`ensure_control_visible` in nested scrolls); clips the hole to the screen for tall targets; a fallback card when the tag is missing; at most one animation at a time; animations off when `UI.animate` is false; handles Android back (Skip with Undo)), `src/tutorial/tutorial_runner.gd` (`TutorialRunner`: owns state, overlay and the `EventBus` subscription; the only object `Main` talks to); C `tests/check_tutorial_overlay.gd/.tscn`, `check_touch_tutorial.gd/.tscn`.
- **Integration lines for G1** (listed in the handback, a few lines in `main.gd` / `app.gd`): create the runner after the first screen, add `App.tutorial` accessor, add the debug line to `App.debug_info()`.
- **Strings.** none new.
- **Tests.** Hole follows a moving target; the three dim panels swallow taps while the hole passes a tap to the control under it (**B11 on the real `BottomSheet`**); a tap on the hole control fires its normal action and the event; info steps block the hole; large text at 626 px (card never covers the target where space allows, otherwise above or below); tall phone; the overlay survives `Main.show_screen` between steps; Skip then Undo; back key; no overlay node left after finish.
- **Screenshots.** One per step type (info, tap, sheet, shortcut, fallback), normal and large.
- **Acceptance.** B11 passes in the repo; if it fails, the card-only fallback ships and the failing steps are listed.
- **Rollback.** Delete `coach_overlay.gd` and `tutorial_runner.gd`; remove the integration lines.
- **Effort (estimate).** 70 to 100 tool calls.

### I-13 The tutorial game (flagged Quick Match, sandbox)

- **Goal.** The first practice game cannot change the player's season.
- **Lane / Needs.** G2. Needs I-06, I-11.
- **Files.** C `src/game/tutorial_game.gd` (`TutorialGame`: chooses an opponent close to your strength and not stronger (documented rule), a seed id `tut:<seed>:<n>` from its own stream so the main seed stream is untouched, a sandbox plan via the existing `plan_set()` hook in a copy, quick-mode timing overrides, and a flag on the result so Report, Payoff, pace log, Form Rating, morale, fatigue, cash, standings and fixtures skip it); M `src/game/game_state.gd` (only the flag handling in `finish_game`-type paths, and only after Systems Designer approval); C `tests/tutorial_tests.gd` additions and `check_tutorial_game.gd/.tscn`.
- **Integration lines for G1.** Report shows the tutorial result card (G1 does this in I-18); Prematch and Match screens read the flag (a few lines).
- **Tests.** Deep compare of `gs.d` before and after a tutorial game (except `tutorial`) is identical; main-stream next game result identical with and without a tutorial game played first (RNG isolation); replay twice gives two different seeds; the opponent is never stronger than the player in 200 random clubs and saves; a legacy save can run it.
- **Acceptance.** Sandbox proven by the deep compare.
- **Rollback.** Revert; the flag path is the only shared hunk.
- **Effort (estimate).** 50 to 70 tool calls.

### I-14 First-run flow: offers, Skip, resume, Settings card

- **Goal.** The player meets the tutorial correctly in every situation of TUTORIAL 6.2 and can replay it.
- **Lane / Needs.** G2 (new files) plus G1 integration lines. Needs I-12, I-13.
- **Files.** C `src/tutorial/offer_card.gd` (the inline Home card), `src/tutorial/settings_help_card.gd` ("Help and learning": Replay, Lessons, Glossary, Show help hints again); **integration lines for G1**: add the card at the top of Settings, the offer card on Home, remove the old "Show the welcome tips again" button; C `tests/check_tutorial_flow.gd/.tscn`.
- **Strings.** merged copy (`tut.offer.*`, `settings.*`).
- **Tests.** Tests 5 to 9 and 13 of TUTORIAL 9 on the legacy path; fresh device (modal welcome), returning device (inline card), `legacy` (one card once), `running` (resume card), `done` and `skipped` (nothing); Replay from Settings confirm sheet; Reset also clears the save's tutorial state; first-run total time measured with a scripted tapper (counts steps and taps, not minutes).
- **Acceptance.** Every row of the TUTORIAL 6.2 table has a passing test.
- **Rollback.** Revert; integration lines are listed.
- **Effort (estimate).** 40 to 60 tool calls.

### I-15 Home

- **Goal.** First redesigned screen: club header with badge, one raised Next-match card, an upcoming-games row, a 2 x 2 tile grid. It proves the whole component stack and sets the pattern for the rest.
- **Lane / Needs.** G1. Needs I-06, I-07, I-08, I-10.
- **Files.** M `src/ui/screen_hub.gd` (rewrite on `_build()` and `_refresh()`); M `ui_smoke.gd`, `ui_touch.gd`, `ui_shots.gd` (the lines that touch Home, rule R4); C `tests/check_ui_home.gd/.tscn`, `tests/shots/shots_home.gd`.
- **Helpers.** `DepthCard`, `HeroStat`-style header, `Carousel` (upcoming(n) from I-06; **cut first if S1 failed**), tile grid (`UI.tile` re-skinned), Badge from `BadgeStyle`. Tags: `home_card`, `home_play`, `tab_*` and the rest in TUTORIAL 8 for Home. Needs-attention note appears only from round 9 (finding in TUTORIAL 11; Lead Game Designer to confirm, section 12).
- **Strings.** `home.*` from the merged copy; `Tips.show(body, "hub")` removed in I-24 (kept working until then).
- **Tests.** T-std all rows; Home stays under the node target (120) with the carousel; the play button is the only coral action; tapping Play still starts the same game path as before (smoke walks a season).
- **Screenshots.** Home: first round, mid-season, season end, a 19-character club name, 5-digit cash; normal, large, cb, tall.
- **Acceptance.** Looks right on two passes; no scroll needed to see the Play button on 720 x 1280 in normal text (UI-PASS-2 space budget); old smoke and touch green.
- **Rollback.** Revert `screen_hub.gd` and the three test hunks.
- **Effort (estimate).** 60 to 80 tool calls.

### I-16 Draft (CP2)

- **Goal.** The biggest eyesore and the most-used screen: lane board, hero picture grid, role filter, bottom sheet to confirm, Coach bar with Take.
- **Lane / Needs.** G1. Needs I-09, I-15 (pattern), I-08.
- **Files.** M `src/ui/screen_draft.gd` (rewrite; keep `_on_hero`, `_apply`, `_sel_hero`, `_start_match`, `_ai_wait`, `_process` as thin wrappers, rule R4); M `ui_smoke.gd` and `ui_touch.gd` hunks; C `check_ui_draft.gd/.tscn`, `shots/shots_draft.gd`.
- **Helpers.** `LaneBoard`, `HeroCard` grid with `ListSync` (filter by role hides cards, never frees them), `BottomSheet` (hero sheet with role fit percentage, best slot pre-chosen through `Draft.best_slot_for`), Coach bar (`Take`, `Auto-finish` then `Sure?` two-tap confirm), timer ring that redraws only when the second changes. Tags and events: `draft:sheet`, `draft:ban`, `draft:pick`, `draft:done` (TUTORIAL 7.5), all draft ids in TUTORIAL 8. Pre-existing opponent-bonus colour problem (green for them) fixed by side cue (UI-PASS-2 section 1).
- **Strings.** `draft.*`, `coach.*`.
- **Tests.** T-std; **the 40-card grid stays under the node gate**; a full draft played by tapping through the real controls (not by calling methods) ends in the same lineup as the same sequence through the old methods (equivalence on 20 seeds); AI turn timing unchanged; ban then pick through the sheet; Auto-finish confirm; `draft:*` events fire once each; in-place audit across 6 taps.
- **Screenshots.** Ban step, pick step, sheet open, role filter, done state, opponent's turn; four variants (24 images).
- **Acceptance.** Gates green; **CP2: APK built by the Producer for the Founder's phone test** (Home and Draft redesigned, tutorial engine playable on the old screens, honest list of what is not done). I run the full check once here (background, about 25 minutes, estimate).
- **Rollback.** Revert the screen and its test hunks.
- **Effort (estimate).** 90 to 130 tool calls.

### I-17 Game Plan

- **Goal.** A timeline (Overall, Early, Mid, Late), big stepped sliders, the expected result always visible, the trigger rules, the Coach sheet, dead controls shown inert.
- **Lane / Needs.** G1. Needs I-10, I-08.
- **Files.** M `src/ui/screen_game_plan.gd` (rewrite; keep `_set_tab`, `_set_value`, `_toggle_trigger`, `_set_jf`, `_coach`, `_reset` as wrappers); M test hunks; C `check_ui_plan.gd/.tscn`, `shots/shots_plan.gd`.
- **Helpers.** `PhaseStrip`, `DetentTrack`, `EdgeMeter` (the expected edge), `BottomSheet` (Coach diff sheet: current against suggested, Apply or Close). Events: `gp:coach_open`, `gp:coach_apply`, `gp:coach_close`. **Autosave stays per tap** (1.6 ms measured, no debounce; the problem was the rebuild, not the write).
- **Strings.** `gp.*`.
- **Tests.** T-std; every slider value reachable by drag and by tap on a detent; the plan written to `gs` equals the old screen's result for 30 random click sequences (equivalence); inert controls for the If-behind plan have no effect and say so; `Apply` and `Reset` undo; the in-place audit **proves `_rebuild` count is zero over 50 taps**.
- **Screenshots.** Overall, Early, Mid, Late, If behind, Coach sheet open; four variants.
- **Acceptance.** As I-16; measured tap cost against the 22 ms baseline (desktop ratio only, honest note).
- **Rollback.** Revert the screen and hunks.
- **Effort (estimate).** 80 to 110 tool calls.

### I-18 Match Report

- **Goal.** Three-part story strip (Early, Mid, Late), one big hero number, then what changed; the "why this happened" factor sheet; the tutorial result card.
- **Lane / Needs.** G1. Needs I-06 (`team_kills`), I-10, I-08, I-13 (flag).
- **Files.** M `src/ui/screen_report.gd`; M test hunks; C `check_ui_report.gd/.tscn`, `shots/shots_report.gd`.
- **Helpers.** `HeroStat`, `PhaseStrip` (read-only mode), `BottomSheet` (factors; event `open:report_why`), count-up numbers use `UI.num_label` (tnum). Tags per TUTORIAL 8. Honest luck copy (Narrative and Lead Game Designer reviewed, UI-PASS-2 R8).
- **Strings.** `report.*`; retire `report.why_h` once the new name is live.
- **Tests.** T-std; a win, a loss, a draw, a tutorial game, and a long game fixture; the score line equals `team_kills`; the Continue button is the one coral action; the story strip texts come only from the existing `Report.story` data (no new claims).
- **Screenshots.** Win, loss, tutorial win, factor sheet; four variants.
- **Acceptance.** As above.
- **Rollback.** Revert.
- **Effort (estimate).** 70 to 100 tool calls.

### I-19 Squad

- **Goal.** Your five starters on a small lane map, bench as avatar cards, a free-agent row, the lane picker and the player card sheets.
- **Lane / Needs.** G1. Needs I-09, I-08, I-05.
- **Files.** M `src/ui/screen_roster.gd` (rewrite; keep `_toggle_slot`, `_assign`, `_toggle_player`, `_auto`); M `player_view.gd` (becomes the player-card sheet content); M test hunks; C `check_ui_squad.gd/.tscn`, `shots/shots_squad.gd`.
- **Helpers.** `PlayerCard`, token anchors from the Squad anchors table in ART-BIBLE (Top 0.110/0.540, Jungle 0.270/0.700, Mid 0.500/0.720, Support 0.840/0.742, Bot 0.889/0.540), `BottomSheet`, `Carousel` (market row; cut with the Home one if S1 failed), tap-to-swap (drag-to-swap is on the cut list, UI-PASS-2 8.1). Events `open:player_card`, `open:lane_picker`. Opened also from Match day with the tab bar hidden.
- **Strings.** `squad.*`.
- **Tests.** T-std; assigning, swapping and auto-fill leave the same lineup as the old methods (equivalence on 20 random rosters); the **team rating preview in the picker equals the rating after the swap**; the Match day entry still works; large text with all 5 anchors reachable.
- **Screenshots.** Closed, picker open, player card sheet, bench with 9 players, an empty lane; four variants.
- **Acceptance.** As above. Note: final token positions depend on the 0.8 arena map; the anchors table is the interim.
- **Rollback.** Revert.
- **Effort (estimate).** 100 to 140 tool calls.

### I-20 Standings and History

- **Goal.** A podium for the top three, your row highlighted and pinned, the Points or Form Rating switch, a playoff bracket, history strips.
- **Lane / Needs.** G1. Needs I-10, I-06 (`cut_gap`).
- **Files.** M `src/ui/screen_standings.gd` (keep `_set_tab`); M test hunks; C `check_ui_standings.gd/.tscn`, `shots/shots_standings.gd`.
- **Helpers.** `Podium`, `RankRow` (tnum), `Segmented` (Points | Form Rating), `PhaseStrip` as tabs; event `stand:metric`; the pinned sentence from `cut_gap()`.
- **Strings.** `standings.*`.
- **Tests.** T-std; the table order equals `gs.standings()` for 20 saved seasons; own row marked by a shape cue (marked YOU), not colour; 19-character club names; no tab label breaks mid-word.
- **Screenshots.** Table, form view, bracket, history; four variants.
- **Acceptance.** As above.
- **Rollback.** Revert.
- **Effort (estimate).** 70 to 100 tool calls.

### I-21 Plan and Club tabs, Match day adopt the new components (parallel S)

- **Goal.** Tabs that are not in the six screens stop looking old next to them.
- **Lane / Needs.** G1. Needs I-15 to I-20.
- **Files.** M `screen_plan.gd`, `screen_club.gd`, `screen_prematch.gd`; tests as usual.
- **Tests.** T-std (build, fit, touch); `Practice matches` and `Play a Quick Match` tags exist (tutorial steps 7 and 8).
- **Acceptance.** Looks consistent; Tutorial ids found.
- **Rollback.** Revert.
- **Effort (estimate).** 30 to 50 tool calls.

### I-22 Help sheets, "?" button and glossary

- **Goal.** A help sheet on every one of the 20 screens, a glossary of 49 terms.
- **Lane / Needs.** G2 (new files) plus G1 integration. Needs I-14, I-16 (so the draft pause hook is real), the screens.
- **Files.** C `src/tutorial/help_sheet.gd` (reads `data/help_v1.json`), `src/tutorial/screen_glossary.gd`, `data/help_v1.json` (20 screens, "see, do, know" lines), `data/glossary_v1.json` (49 terms); **integration lines for G1**: the "?" button in the `Screen` header slot (I-03), the dot memory, pause hooks for Draft timer and Match, replace `Tips.show` calls.
- **Strings.** from the merged patch (`help.*`, `gl.*`; 60 help lines and 49 definitions).
- **Tests.** Tests 11, 12, 14, 16 of TUTORIAL 9; every screen's `help_id()` has an entry; opening a sheet pauses the draft timer; the dot clears after opening; every glossary key exists; no help text is over its word limit (script from Narrative reused as `tools/check_copy_limits.py`).
- **Screenshots.** One help sheet, the glossary list and one term; four variants.
- **Acceptance.** Every screen has a working "?".
- **Rollback.** Revert; integration lines listed.
- **Effort (estimate).** 70 to 100 tool calls.

### I-23 Lessons and offers

- **Goal.** Eight optional lessons (33 steps) with unlock rules, and the offers on Home, Report, Draft complete, Club and Season summary.
- **Lane / Needs.** G2 (new files) plus G1 integration. Needs I-22.
- **Files.** C `src/tutorial/screen_lessons.gd`, `src/tutorial/lesson_offer.gd`, `data/lessons_v1.json`; integration lines for the five screens.
- **Strings.** `les.*` (merged).
- **Tests.** Test 10 of TUTORIAL 9; unlock round numbers (guesses in the spec, kept in data so they can change without code); status flow absent to offered to snoozed to dismissed or done; `Show help hints again` resets dismissed and snoozed but keeps done.
- **Acceptance.** Each lesson runs on the redesigned screens.
- **Rollback.** Revert.
- **Effort (estimate).** 60 to 90 tool calls.

### I-24 Cleanup: old tips, rename check, About and Licences

- **Goal.** Remove what is replaced and prove the rename.
- **Lane / Needs.** G1. Needs I-22.
- **Files.** M `tips.gd` and the three `Tips.show` calls (removed), `screen_about.gd` (Barlow credit and a Licences entry reading the licence text), `en.json` (retire `tip.hub*`, `tip.prematch*`, `tip.report*`; the Payoff `tip.*` keys stay); C `tools/check_rename.py` (fails on "advisor", "assistant", "owner and coach", and "coach" in lower case when it means the helper) wired into `check_fast.sh` by L.
- **Tests.** Rename script clean; the licence text is shown from a data file that is in the APK.
- **Acceptance.** `check_strings.py` has no unused-key warnings for the retired families.
- **Rollback.** Revert.
- **Effort (estimate).** 25 to 40 tool calls.

### I-25 Acceptance (CP3)

- **Goal.** The proof that everything works together, then the handback for review.
- **Lane / Needs.** Q runs the audits, G1 fixes, L runs the full check. Needs all.
- **Work.** (1) The full UI-PASS-2 7.1 matrix: 6 screens, all states, 4 variants (72 images or more), each looked at twice. (2) The audits of 7.1 on every screen: fit, hit area, colour-blind cue, in-place. (3) All 20 tutorial tests (TUTORIAL 9) including the end-to-end walk of the 27 steps on the new screens, counted in steps and taps. (4) Perf gates under Xvfb for all 6 screens plus the sheets. (5) The idle-redraw check and the low-processor decision with Engine/Graphics. (6) Save-compat fixtures. (7) `bash tools/run_all_checks.sh $GODOT` in the background (about 25 minutes, estimate). (8) A debug APK export, size compared with the 24.7 MB of `PERF-BUDGET.md` 8. (9) Version label 0.7.0 alpha (`App.VERSION_LABEL`, G1), export preset version (L), `docs/ALPHA-0.7-NOTES.md` (Producer).
- **Acceptance.** Full check exit 0; no `ERROR:` in logs; every gate in section 6 green or a named exception signed by the Technical Director.
- **Rollback.** Not applicable; this step only fixes.
- **Effort (estimate).** 60 to 90 tool calls.

---

## 8. Estimate summary (all estimates)

| Block | Increments | Tool calls (estimate) |
|---|---|---|
| Safety net, spikes | I-00, I-01 | 55 to 85 |
| Look foundations | I-02 to I-04 | 130 to 190 |
| Art code (E) | I-05 | 60 to 90 |
| Core hooks (G2) | I-06 | 25 to 40 |
| Components | I-07 to I-10 | 230 to 320 |
| Tutorial engine (G2) | I-11 to I-14 | 210 to 290 |
| Six screens and tabs | I-15 to I-21 | 500 to 710 |
| Help, lessons, cleanup, acceptance | I-22 to I-25 | 215 to 320 |
| **Total** | 26 increments | **about 1,400 to 2,050** |

The design documents' own estimates are 38 developer days for the layouts and 19 for the tutorial (about 57), both flagged by their authors as low confidence. I cannot convert tool calls to days with any evidence; my reading is 20 to 28 working days for one builder and about 14 to 20 with two lanes, and that is a guess to be replaced by the real pace after I-04 and I-07 are done. **Re-estimate after I-07** (first real component increment) and again after I-15 (first screen); the Producer should expect the plan to move at those two points.

---

## 9. Risks and spikes

### 9.1 Table

| # | Risk | Evidence so far | Handled by |
|---|---|---|---|
| K1 | **Sheet-through-hole tap (TUTORIAL B11):** a tap in the overlay hole must reach a button inside a sheet on a lower layer | Scratch probe passed on desktop; **not run on a phone, not run with the real `BottomSheet`** | I-01 S2, then I-12 on the real sheet. Fallback: card-only steps |
| K2 | **Nested carousel steals diagonal swipes** | Scratch probe: **failed** (a mostly vertical diagonal swipe starting on the carousel moved the carousel, not the page) | I-01 S1 designs the direction lock; I-08 tests five angles; fallback plain row; cut list |
| K3 | **Barlow in Godot.** Weights, `tnum`, fallback, size | Files and `default_font.tres` already in the repo; desktop: `tnum` works, widths match the art bible; APK +0.3 MB; weights not wired; OFL text not in the APK | I-02 wires weights and fixes the export filter. **Android `tnum` unverified** (the text server in the Android template is TextServerAdvanced, so expected to work); phone-test item |
| K4 | **Texture and draw-call budget** | Counts exact on this renderer: `StyleBoxFlat` card is one call with or without shadow; 9-slice from one atlas batches to 1; a `CPUParticles2D` is one call. Real batching with interleaved text and icons is not proven. Fill-rate cost is not measurable here | I-01 S3, gates in section 6, `perf_baseline` in every screen step; phone test |
| K5 | **Node cliff in the hero grid** (40 cards) | Current Draft screen has 81 nodes; a 5-node card would cost 240 | I-01 S4: HeroCard is one self-drawing `Control`; fallback virtualised list |
| K6 | **Rebuild-on-tap makes overlay and sheets unstable** | 16 to 22 ms per tap measured | Section 2.1 rule; in-place audit in every screen step |
| K7 | **Token change ripples** into the 14 unredesigned screens (UI-PASS-2 R4) | Font change alone already changed every screenshot | I-02 plus I-04 land it once with a full re-shoot; CP1 |
| K8 | **String merge breaks tests** (16 keys replaced, 3 rename edits) | Unknown until merged | I-00 does the merge first, in its own commit |
| K9 | **SVG rasterisation on Android** (ThorVG in the Android template) | Fast on desktop at start-up; Android untested | I-05 draws everything in code where possible; SVG only for the five role icons; Engine/Graphics to confirm ThorVG in the Android export; phone-test item |
| K10 | **Hot-file collisions between two agents** | Real: `ui.gd`, `main.gd`, `screen.gd`, `app.gd`, `en.json`, `game_state.gd`, big test files | Section 4 ownership table, auto-discovered tests, integration lines |
| K11 | **Text widths on a phone** drift by a pixel or two at scaled sizes (the "Gravenstone" room is a few pixels) | Exact on desktop only | Margin audit in `fit_*`; phone test; hero names stay at Small 26 |
| K12 | **Time of the first game** (4 to 6 minutes for 27 steps is unmeasured) | TUTORIAL 11 | I-14 counts taps and steps; Founder phone test measures minutes; cut steps 3 and 10 first |
| K13 | **Scope.** About 1,400 to 2,050 tool calls (estimate) | | Cut list (section 10), checkpoints, re-estimate after I-07 and I-15 |

### 9.2 What would make me stop and replan

- S1 and S2 both fail (no reliable carousel, no hole-tap): drop the carousel, make the tutorial card-only, and the tutorial cost falls; the layouts do not change otherwise.
- S4 shows a self-drawing card cannot hold a 40-hero grid under 200 nodes and 100 draw calls: virtualise the grid (more code in I-09 and I-16, about 20 to 30 calls more, estimate).
- The `Strings` merge in I-00 breaks more than about 10 tests: pause and fix before anything else.

### 9.3 Spikes already run (scratch, not in the repo)

Files under the session scratchpad (`probe07/`): node counts, rebuild timings, font widths, B11, nested scroll, SVG. They are probes, not deliverables; I-01 re-creates the ones that matter inside `game/tests/` so the result is repeatable by anyone.

### 9.4 Phone-test list (open until a phone has run a match)

Scrolling stutter on Home and Draft; whether the phone warms over one full match with the draft; text that looks wrong or boxy; `tnum` columns on Android; SVG icons on Android; the hole tap through a sheet on a real touchscreen; the carousel direction lock on a real finger; overlay timing; shadow and glow cost on a low-end GPU; real draw calls and frame time (needs a debug overlay, `PERF-BUDGET.md` 9 item 3, small piece of work; propose it as part of I-02 if the Technical Director agrees).

---

## 10. Cut list, checkpoints and what waits

**Cut order if time is short** (taken from UI-PASS-2 8.1 and my own risk list; each cut leaves a working app):

1. Home and Squad carousels become plain rows with "See all" (also the fallback if S1 fails).
2. Drag-to-swap on Squad (tap-to-swap stays).
3. History mini story strips on Standings.
4. Report "starter chips" sheet.
5. Lessons beyond the first three (I-23).
6. Plan and Club tab restyle (I-21) and overflow-only treatment kept from I-04.

Never cut: tokens and weights (I-02), the in-place rule on redesigned screens, the tutorial's sandbox proof (I-13), save compatibility (section 5), the colour-blind cues.

**Checkpoints**

| CP | After | What exists | For whom |
|---|---|---|---|
| CP1 | I-04 | Same game, new type, colours, font, 96 px targets, frame layers | Founder can look at screenshots; no phone test needed |
| CP2 | I-16 | Home and Draft redesigned, tutorial engine and first game playable (fallback cards where the other screens are not rebuilt yet), APK, one full check | **Founder phone test** (PERF-BUDGET 4: scrolling, warmth, text) |
| CP3 | I-25 | All six screens, help everywhere, lessons, 0.7.0 APK | Founder, then testers |

**What waits for Alpha 0.8 (the arena), and why**

- The **Match HUD** (UI-PASS-2 6.7): scoreboard strip, text strip with the scheduler, controls, end card. Depends on the arena scene, the short feed form and `Report.story`.
- `tut.watch.arena` (tutorial step 19 text) and the match step events in arena form; 0.7 keeps `screen_match.gd` as it is and tags its Speed and Skip buttons.
- Final lane-token positions on Squad (tied to the arena map; the anchors table is interim).
- Arena budgets (PERF-BUDGET 3.5, 3.6): 600 canvas items, particle limits, `CPUParticles2D` only.
- Low-processor mode, which the Technical Director should decide after an arena trial (PERF-BUDGET 9 item 1).
- Everything online: not planned.

---

## 11. Naming of things the Gameplay Programmer will search for

| Thing | Name | File |
|---|---|---|
| Event bus | `EventBus`, `App.bus` | `src/ui/event_bus.gd` |
| Tag registry | `UI.tag`, `UI.find_tag` | `src/ui/ui.gd` |
| Tutorial brain | `TutorialState` | `src/tutorial/tutorial_state.gd` |
| Device settings | `DeviceState` | `src/core/device_state.gd` |
| Overlay | `CoachOverlay` | `src/tutorial/coach_overlay.gd` |
| Runner | `TutorialRunner` | `src/tutorial/tutorial_runner.gd` |
| Tutorial game | `TutorialGame` | `src/game/tutorial_game.gd` |
| Components | `DepthCard`, `SectionHeader`, `Chip`, `Segmented`, `IconButton`, `EmptyState`, `EdgeMeter`, `HeroStat`, `ListSync`, `BottomSheet`, `Carousel`, `PlayerCard`, `HeroCard`, `LaneRow`, `LaneBoard`, `PhaseStrip`, `DetentTrack`, `Podium`, `RankRow` | `src/ui/components/` |
| Art code | `TexCache`, `Icons`, `BadgeStyle`, `Silhouette`, `Avatar`, `Surface` | `src/ui/art/` |
| Game hooks | `GameState.upcoming`, `cut_gap`, `tutorial`, `set_tutorial`; `Report.team_kills`; `Draft.best_slot_for` | `game_state.gd`, `sim/report.gd`, `sim/draft.gd` |

---

## 12. Decisions needed (none for the Founder)

| # | For | Decision | My recommendation |
|---|---|---|---|
| D1 | Technical Director | Adopt the `PERF-BUDGET.md` limits (100 draw calls, 200 nodes, 48 MB per screen) as failing checks | Yes. They are generous against the baseline and catch the 40-card cliff |
| D2 | Technical Director | A small debug overlay (FPS, draw calls, nodes, texture memory) for the phone tests | Yes, in I-02; it is the only way to get numbers off a phone |
| D3 | Systems Designer | Approve the read-only helpers in I-06 (`upcoming`, `cut_gap`, `team_kills`, `best_slot_for`) and the tutorial flag handling in I-13 | Approve; none changes a result, and the golden hash proves it |
| D4 | Producer | Run the full 25-minute check at CP2 and I-25 only; use the fast loop otherwise | Yes |
| D5 | Producer | One commit per increment so rollback is a revert | Yes |
| D6 | Lead Game Designer | Home "contracts end this season" note only from round 9 (TUTORIAL 11); and the stricter opponent rule for the first game | Yes to both |
| D7 | Narrative, UI/UX | The three open items in `COPY-0.7.md` 2: "Mid" as lane and phase, "Jg" and "Sup" filter labels, `chem.pentagon_hint` colour-only wording | Take Narrative's recommendations; the third needs a non-colour cue before I-04's colour-blind check can pass for Chemistry |

---

## 13. Hand-offs

- **Producer:** dispatch I-00 first; commit one increment at a time; APK at CP2 and CP3; log that the Founder's feedback supersedes the earlier "guided first game stays optional" decision; ALPHA-0.7 notes at I-25.
- **Narrative:** copy patch is the source; nothing to write unless a screen step finds a gap (G1 asks); re-run limit scripts when keys change.
- **Engine / Graphics:** lane E (I-05), the gates and `perf_baseline`, ThorVG in the Android template, the debug overlay if approved, `OFL.txt` in the export filter (L edits the preset).
- **QA Automation:** audits and the matrix in I-25; `check_strings.py` extended if a split string file is ever used (not needed: one merge); seed pinning for the tutorial tests.
- **Systems Designer:** D3 approval.
- **IP and Originality Checker:** Barlow licence entry (already logged by Engine/Graphics; confirm the OFL text now ships); badge, silhouette and icon shapes from I-05.
- **UI/UX Designer:** answer D7; non-colour cue for the Chemistry hint; confirm interim Squad anchors.
