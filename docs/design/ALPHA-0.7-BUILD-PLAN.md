# Alpha 0.7 "Guide and Look": Build Plan

Version 1.2 · Date 2026-11-10 · Author: Lead Programmer · Status: v1.2 patch after the I-01 spike results and the Producer decisions of 2026-11-10; for the Producer to hand to the Gameplay Programmer (I-00, I-00b and I-01 are built; I-00 review pending; the next dispatch is I-00c, then I-02).

**Change log, v1.1 to v1.2** (sources: `docs/design/SPIKE-RESULTS-0.7.md`, the Producer log of 2026-11-10 in `company/DECISIONS.md`)

| # | Change | Where |
|---|---|---|
| 1 | **I-01 recorded as built and accepted.** All four spikes pass their conditions; two designs change (S1 and S4). The three result tables (S1, S3, S4) and the S2 rows are copied into the new section 9.5. `check_gestures` keeps that name (27 checks); the real-component touch checks of I-08 are `check_touch_gestures`. | 3.2, I-01, 9.5 |
| 2 | **I-08 Carousel:** one `Control` that owns hit-testing; cards are non-interactive (`MOUSE_FILTER_IGNORE`); direction lock after 12 px; 12 px tap slop; emits `card_tapped(i)`. The plain-row fallback is no longer needed on this evidence (kept as phone-test insurance and cut-list item 1). I-08 and I-12 re-run the S1 and S2 rows on the real components. | I-08, I-12, I-15, I-19, K2, 9.2, 10 |
| 3 | **I-09 hero grid is design C:** one `HeroGrid` `Control` draws all 40 cards in three passes and owns hit-testing; per-hero drawing is a static helper (`HeroCard.draw`) the hero sheet preview and the lane tokens reuse. Measured: 40 `PanelContainer`s = 281 nodes, one `Control` per card = 107 draw calls (hard limit 100). The "virtualise 12 to 16 cards" fallback and the "240 nodes" estimate are replaced by the measured numbers; B3 (one font size, one waiver) is the alternative. | 2.1, 2.7, I-09, I-16, K5, 9.2, 11 |
| 4 | **I-00b recorded as built** (update mode in `tools/merge_copy.py`, `patch2` applied). The allow-list is `docs/design/copy/owned_keys.txt` (the Producer log), not `update_allow.json` as v1.1 wrote. The perf allowance data file was not part of what was built: **new small increment I-00c** (10 to 20 calls): `tests/perf_allowances.json`, read by `perf_baseline.gd` per `PERF-BUDGET.md` 3.1a. | I-00b, I-00c, 3.3, 4.2, 4.3, 6, 13 |
| 5 | `tools/check_fast.sh` should also run `pytest tools` (it runs none today; `tools/test_merge_copy.py` and the other `tools/test_*.py` only run in the full check). | 3.3, 13 |
| 6 | Effort re-added by script after the new I-00c: base 1,470 to 2,130 (was 1,460 to 2,110), with allowance about 1,760 to 2,770 (was 1,750 to 2,740). Dispatches 29. Checkpoint call counts moved by the same 10 to 20. | 0, 8, K13 |

Not part of this patch: section 12.1 (U1 to U5) still lists the UI/UX answers as owed, although `company/DECISIONS.md` (2026-11-10) records them as accepted (UI-PASS-2 section 11); to be closed with the next patch.

**Change log, v1.0 to v1.1** (source: `company/reviews/2026-11-09-wave2a.md` section 4; the number in brackets is that review's fix number)

| # | Change | Where |
|---|---|---|
| 1 | **Four copy keys are held out of the I-00 merge** (`draft.meta_hint`, `about.title`, `about.included.b`, `about.test.b`); `tools/merge_copy.py` takes a hold-list; I-00 merges 536 keys; release at I-16 and I-24/I-25. I-00 is recorded as **amended**, not a redo. [1] | 2.6, I-00, I-16, I-24, I-25 |
| 2 | **CP2 moved from after I-16 to after I-18**, and the tag-only part of I-21 is pulled forward as **I-21a** (right after I-14). The Founder's first look at the tutorial now has 3 fallback steps of 27 instead of 15. The exact fallback list per checkpoint is in section 10. [2] | 0, 4.3, I-14, I-16, I-18, I-21a, 10 |
| 3 | **Tutorial state of a brand-new save** defined (`new`, written by `new_game()`, not `legacy`); **resume after a kill** mid-tutorial-game defined; fresh-save fixture `save_0_6_d` added to the fixtures and to the I-00 and I-06 tests. [3] | 5, I-00, I-06, I-11, I-14 |
| 4 | Stale statements removed: the OFL licence step is done (commit `d78038d`, verified by listing the APK); "Report moves ahead of Squad" was not a change from UI-PASS-2 8.1; the dangling "explained in section 4" pointer is gone. [4] | 0, 2.2, I-02, 4.3, K3, 13 |
| 5 | Old welcome tips against the new Home offer card and the "Play without scrolling" acceptance: **the Home tip retires in I-15, the Report tip in I-18, the Pre-match tip in I-21a**, I-24 only deletes what is left. [9] | I-15, I-18, I-21a, I-24 |
| 6 | Effort: tutorial block sum fixed (210 to 300), small increments re-costed, a **20 to 30 percent rework and review allowance** added, the day figures labelled a guess, and the screenshot counts that only fit when batched are named. [10] | 0, 3.1 R1, 8, 9.1 K13 |
| 6b | I-00 recorded as built (review pending) with its fixed-seed perf table; **new small increment I-00b** (copy update route with an allow-list, and the perf allowance data file); section 6 now refers to `PERF-BUDGET.md` 3.1a (per-screen allowances with a ratchet, shadows 6, font pairs 12) instead of flat gates [review fix 5, 7]; wording fixes: saves are `JSON.stringify(gs.d)` then `from_dict` (no `to_dict`), Q owns the fixtures folder, `tools/check_copy.py` is used for the I-22 and I-24 tests and there is no `check_rename.py`. | 4.2, 6, I-00, I-00b, I-04, I-22, I-24, 5 |
| 7 | Added: the Founder's "no mid-match interventions" quoted; I-00 tooling ownership (Gameplay Programmer builds, Lead Programmer reviews, Tools Engineer on call); permission for a second Gameplay Programmer instance on the guide lane (G2) from I-06; the five UI/UX answers still owed as an open table with owners. | 0, 4.1, 4.2, 12.1 |
| 8 | Small knock-on fixes made while patching: tab bar tags added to I-03 (steps 3, 4, 7 and 24 need them), Match screen tags assigned to I-21a (no increment had them), K8 answered by the review's grep, D7 clause about "I-04's colour-blind check" corrected. | I-03, I-21a, K8, D7 |

Not part of this patch (owners named by the review, still open): B11 / nested / SVG outputs [11], GDD "coach" lines [13], and the one-word addition of the state `new` to `TUTORIAL.md` 6.1. See section 13. (Review fixes 5, 7 and 8 are now covered by section 6, I-00b and `tools/check_copy.py`.)

Inputs: `ALPHA-0.7-PLAN.md`, `SPIKE-RESULTS-0.7.md`, `UI-PASS-2.md`, `TUTORIAL.md`, `ART-BIBLE.md`, `PERF-BUDGET.md`, `COPY-0.7.md` and `copy/en_0_7.json`, the last section of `company/DECISIONS.md`, `company/reviews/2026-11-08-wave1b.md`, `company/reviews/2026-11-09-wave2a.md`, and the code in `game/src/core`, `game/src/ui`, `game/src/game`, `game/src/sim` and `game/tests` as it stands today (version label 0.6.0 alpha).

**Every effort number in this document is an estimate** (tool calls for one agent, including its own testing and redo). Nobody has built any of this yet. The measured numbers (section 2) were taken on this build computer, headless or under a software renderer, and say nothing about a phone.

---

## 0. Summary (phone-length)

- **Founder decision, final (company/DECISIONS.md):** "NO mid-match interventions. The player never changes anything during a match." Nothing in this plan adds one: `screen_match.gd` stays spectator-only (only its Speed, Skip and See-the-report buttons are tagged), and the tutorial and help never write a match result.
- **What this is.** 26 build steps (I-00 to I-25; I-21 is split in two and the small follow-ups I-00b and I-00c are added, so 29 dispatches). Each is small enough to build, test and screenshot in one sitting (about 15 to 140 tool calls, estimate). The base total is about 1,470 to 2,130 tool calls (estimate). With a 20 to 30 percent allowance for rework and review (5 of the 13 earlier dispatches needed a second round) it is **about 1,760 to 2,770 tool calls**. In days that is roughly 24 to 38 working days for one builder and 17 to 26 with two lanes. **The day figures are a guess**: nothing converts tool calls to days yet (the design documents' own figure is 57 developer days). Section 8.
- **Order.** Safety net and spikes first, then look foundations (type sizes, colours, font, frame), then shared components, then the tutorial engine, then the six screens (Home, Draft, Game Plan, Report, Squad, Standings), then help sheets, lessons and acceptance. The screen order is the one in UI-PASS-2 8.1 (Home, Draft, Game Plan, Report, Squad, Standings), unchanged. What this plan adds to 8.1: the tutorial plumbing (tags and events) lands before the first screen, so no screen is built twice; the nested-scroll spike of 8.1 step 0 grows into four spikes, including surface cost (S3) and the 40-hero grid (S4); and the tag-only work for screens that are not redesigned (I-21a) is done before the Founder sees the tutorial.
- **Three checkpoints** where the Founder can see something real: CP1 after I-04 (same game, new type, colours and font), **CP2 after I-18** (Home, Draft, Game Plan and Report redesigned, so the whole match-day loop is new; the guided first game is playable with 3 of 27 steps still showing a "cannot find that" card: first APK for the phone test), CP3 after I-25 (everything, full check). An optional **engine-preview APK** after I-16 is for scrolling, warmth and text only: the guide on it has 8 fallback steps and the Founder should tap Skip tutorial. Exact lists in section 10.
- **Biggest findings from the code** (measured, section 2): every tap on Game Plan, Squad and Draft deletes and rebuilds the whole page (22 ms, 16 ms and 22 ms on this computer; 131 nodes on Game Plan). This is the pattern the plan replaces with build once and update in place. A tutorial that points at a button cannot survive a page that deletes the button on every tap, so this is a hard dependency, not a nicety.
- **Old saves keep loading.** No change to `GameState.VERSION`. Tutorial progress is a new additive `tutorial` key with its own version; a missing key means `legacy` (a save from before 0.7) and a brand-new save is written as `new` by `new_game()`. Section 5.
- **One thing that cannot be settled here:** how it feels and performs on a real phone. First chance is the engine-preview APK after I-16 (if the Producer builds it) or CP2. Nothing in this plan has run on a phone.
- **Decisions for the Founder: none.** The Producer should tell the Founder which tutorial steps are cards at each checkpoint (section 10). Eight small decisions for other roles in section 12, each with a recommendation; five UI/UX answers are still owed (12.1).

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
3. Lists that change length (hero grid filtered by role, bench, rows) use one `ListSync.sync(container, keys, make_fn)` helper: keyed reconcile with `move_child` for order, creation for new keys, `visible = false` (not free) for filtered-out keys. The 40-hero grid does not use it (v1.2): `HeroGrid` (I-09) is one `Control` and a role filter is data plus one `queue_redraw`.
4. Pages and views inside one screen (Game Plan phases, Standings tabs, Squad variants) are children toggled with `visible`, not rebuilt.
5. Sheets close with `call_deferred("queue_free")` after their button's signal has finished (the studio rule: never free a screen inside its own signal). The page behind a sheet is never rebuilt while it is open.
6. Timers and counters redraw only when the displayed text changes (the Draft timer string changes once a second, not every frame).
7. A test proves it (section 3.2, "in-place audit"): record `get_instance_id()` of the scroll container, the first control of every list and every slider before a tap, tap, and require the same ids.

Screens not redesigned in 0.7 (Finance, Training, Free agents, Negotiation, Practice, Settings, Chemistry) keep `_rebuild`; the tutorial steps that touch them (the Practice matches tile on the Plan tab, the Quick Match button) are tagged in I-21a, before the Founder's first look at the guide. They are listed in the cut list in section 10 as the next candidates.

### 2.2 Tokens, theme and font today

- `ui.gd`: sizes `S_BODY` 28, `S_SMALL` 22, `S_BIG` 38, `S_TITLE` 46, `BTN_H` 92, `R_CARD` 20, `GAP` 14. Colours `BG PANEL PANEL2 PANEL3 ACCENT CORAL GOOD BAD WARN TEXT DIM BLUE RED` as `const`. `box()` builds a new `StyleBoxFlat` on every call (no cache). `make_theme()` builds the theme. Not in code yet: `S_HEAD`, `S_CAPTION`, `S_DISPLAY`, the role colours, `VOID`, `TEXT2` and the rest of the art bible 3 token table.
- Button kinds today: `primary`, `play`, `danger`, `flat`, plus normal. The art bible wants one coral action per screen and an outlined `ban` kind; a `Section` header uses a text prefix ("+ " and "- ") that tests find by string (`ui_shots._open_section`).
- Font: Engine/Graphics has already added Barlow Semi Condensed (five weights, OFL) and `default_font.tres` (a `FontVariation` over Regular with a system fallback), set in `project.godot` as `gui/theme/custom_font`. Result: every existing screen is already in Barlow Regular. **Weights are not wired** (no SemiBold buttons, Bold titles) and **`tnum` is not applied** to numbers. The font licence text **ships**: `export_presets.cfg` has `include_filter="*.json, assets/fonts/OFL.txt"` since commit `d78038d`, and the Studio Manager's listing of the repo APK shows `assets/assets/fonts/OFL.txt` (4,377 bytes). Nothing is left to do for it in 0.7 except to keep the listing check in I-02 and I-25 (the earlier "not in the APK" finding in `PERF-BUDGET.md` 8 is stale).
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

`game/i18n/en.json` has 645 keys, ASCII only. `tools/check_strings.py` reads `en.json` only (and the code's `Strings.t("key")` uses). The word "advisor" appears at two keys and "owner and coach" at one (the Coach rename list is in `COPY-0.7.md` 6.2). Narrative has written `docs/design/copy/en_0_7.json`: 540 keys, 524 new and 16 replacing existing ones (Narrative did not touch `en.json`). Decision: merge in I-00, so lanes never edit `en.json` in parallel (after the merge, only the UI lane adds keys, section 4 ownership table). **Amended in v1.1: four keys are held out of the merge** because their new text describes things that do not exist until later, and the Founder's CP2 phone build would otherwise tell testers about features that are not in it. All four are among the 16 replaced keys, so they already exist in `en.json` with their old text, and the old text simply stays until release:

| Held key | New text says | Released in |
|---|---|---|
| `draft.meta_hint` | "An up arrow means strong in this patch" (the Draft screen still shows green text until the arrows are drawn) | I-16 (Draft) |
| `about.title` | "About Alpha 0.7" (the version label is 0.6.0 until I-25) | I-25, together with `App.VERSION_LABEL` 0.7.0 |
| `about.included.b` | a guided first game, a ? button on every screen, lessons, a glossary | I-24 (help sheets exist from I-22, lessons from I-23) |
| `about.test.b` | tester questions about the guided first game, help, lessons, glossary | I-24 |

`tools/merge_copy.py` takes a hold-list (`--hold <file>`, default `docs/design/copy/hold_0_7.json`, one entry per key with its release increment and reason), copies every other key, **prints the held keys by name**, shows each replacement with old and new text, and refuses a patch with duplicate keys, non-ASCII text or a changed `{placeholder}`. A dry run writes nothing; `--write` writes, and `--expect-total 536 --expect-replaced 12 --expect-new 524 --expect-held 4` makes the run fail if the counts differ. **To release a key, the increment that owns it deletes the key's entry from the hold file and runs the script again with `--write`** (it overwrites the old text on purpose and prints that). *(As found in the working tree on 2026-11-09: the script and the hold file exist, and `en.json` has 1,169 keys with the four held keys still on their old text; I have read them but have not run the script.)* I-00 merges **536 keys: 524 new and 12 replaced**. The key set of `en.json` is the same as in the full merge (1,169 keys, so 0 unknown keys in `check_strings.py` and the same "unused" count the review found, 588, which depends on the key set and the code, not on the text). The old `about.title` text ("About Alpha 0.4") was already stale before this patch; it stays stale until I-25 and says nothing untrue about 0.7.

### 2.7 Performance baseline and gates

Baseline (Engine/Graphics, `PERF-BUDGET.md`, and my node counts above): the current screens are small (36 to 131 nodes). Proposed budgets from `PERF-BUDGET.md`: draw calls per screen target 60, hard 100; nodes per screen target 120, hard 200; texture memory target 32 MB, hard 48 MB; at most 6 shadowed and 2 glowing surfaces visible; shadow and glow size at or under 18 px; no blur shaders; at most two full-screen layers; timers redraw only when the displayed value changes. The budgets are still a proposal; this plan treats them as gates that fail a check (I-00 builds the check) and asks the Technical Director to confirm them (section 12).

**The 40-hero draft grid is the cliff, and S4 measured it (v1.2).** 40 `PanelContainer`s with children are **281 nodes** (the v1.0 estimate of 240 was low), over the 200 hard limit before anything else is on screen. One self-drawing `Control` per card fixes the nodes (41) but **not the draw calls: 107 on screen, against a hard limit of 100 for the whole screen**, because each card switches between three glyph textures and untextured shapes. What works: **one `HeroGrid` `Control` that draws all 40 cards in three passes, 1 node and 7 draw calls** (design C, I-09). Virtualising the grid would not help, because the 107 calls are already only for the visible cards. Numbers in 9.5; computer-side counts, nothing measured on a phone.

---

## 3. Rules for every increment

### 3.1 Rules

- **R1. Definition of done for any increment.** (a) Builds with no script errors; `--import` was run if a `class_name` file was added. (b) The fast check loop (3.3) is green. (c) New tests exist and pass (3.2). (d) Screenshots were taken at the matrix subset named in the increment and looked at twice (first pass layout, second pass text fit, touch size, colour dependence). **Looking is batched**: images are joined into contact sheets of 6 (3 x 2, each image at half size) before they are viewed, and the headless fit audit, not the eye, carries the text-fit check on the unchanged ones; a single image is opened at full size only when a sheet shows a problem or a change. The tool-call figures in this plan assume this (see section 8). (e) Strings: no hard-coded visible text; `check_strings.py` clean. (f) The in-place audit passes for a redesigned screen, **and its perf allowance row is deleted and the screen is at or under target (section 6)**. (g) A handback in the studio format, with what was not tested.
- **R2. One increment, one dispatch, one owner.** Lanes in section 4. If an increment needs a change in a file owned by another lane, it lists it as an "integration line" for the owner (at most about 5 lines) and does not edit it. The two largest increments (I-16 Draft, I-19 Squad) may each be dispatched as two halves, "build" and then "tests and shots", if the Producer sees the first half run long; the increment is only done when both halves are.
- **R3. No simulation change.** `src/sim/*.gd` and `data/*.json` of the sim are not changed except the read-only helpers named in I-06. The golden vectors (`tests/golden`) must not change; I-00 records their hash and the fast loop checks it.
- **R4. Test migration happens in the same increment as the screen change.** A screen increment either keeps each old private method name (thin wrapper over the new code) or edits the old test lines, in the same dispatch. Never leave a red test for the next step.
- **R5. Explicit types for `:=` on untyped values; no method named `_set`; no screen freed inside its own signal; `--import` after adding a `class_name` file** (a script load error hangs the engine; run every Godot command with `timeout`).
- **R6. Presentation never feeds back into results.** The match, report and plan are decided first; views only show them. The tutorial game and the help system never write game results (section 7).
- **R7. Rollback.** Every increment ends in a state that can be reverted on its own: new files plus a few integration lines. Where an increment changes a shared file, the handback lists the exact hunks. The Producer commits after review, one commit per increment (so rollback is `git revert` of that commit).

### 3.2 Standard tests ("T-std") and how tests are organised

The existing big files (`ui_smoke.gd` 403 lines, `ui_touch.gd` 291, `ui_shots.gd` 204, `run_tests.gd` 138) are single files that every lane would edit. I-00 changes the structure so lanes can add tests without sharing a file:

- **`run_tests.gd` auto-discovers `res://tests/*_tests.gd`** (each file has `run(check: Callable)`), loaded with `load(path).new()` so no `class_name` or `--import` is needed. New logic tests are new files.
- **Screen tests are per-area scenes** named `res://tests/check_<area>.tscn` (headless, ends with " N checks, 0 failures"), and touch ones `check_touch_<area>.tscn` (need `override.cfg` with `pointing/emulate_touch_from_mouse=true`). `tools/run_all_checks.sh` and the new `tools/check_fast.sh` loop over `tests/check_*.tscn`. **(v1.2)** `check_gestures` (built in I-01, 27 checks) keeps that name although it is a touch test: it relaunches itself with touch emulation, so the headless loop runs it like any `check_*`. The touch checks of the real `BottomSheet` and `Carousel` (I-08) are `check_touch_gestures`, run by the touch loop with `override.cfg`. The old `ui_smoke`, `ui_touch` and `ui_shots` stay and keep running; only the UI lane edits them.
- **Screenshot matrix.** `tests/shots_matrix.tscn` runs under Xvfb and discovers modules `tests/shots/shots_<screen>.gd`, each with `static func run(ctx)`. A run takes env `SCREENS=home,draft` and `VARIANTS=normal,large,cb,tall` to select a subset. Variants: **normal** (720 x 1280), **large** (content scale 1.15), **cb** (colour-blind mode on), **tall** (720 x 1560). Output PNG name: `<screen>_<state>_<variant>.png`. The full UI-PASS-2 7.1 matrix is 6 screens x several states x 4 variants (72 images); each screen step takes only its own screen's subset, the full set runs in I-25.

The T-std set every screen increment adds (names are the check labels):

| Test | What it proves | Type |
|---|---|---|
| `build_<screen>` | the screen builds with a fresh game, every state in the shot list, no `ERROR:`/`SCRIPT ERROR` in the log | smoke, headless |
| `fit_<screen>_<variant>` | no control's rect leaves the 720 px (626 px large) frame; no Label is clipped to fewer than N characters (the Standings "Playo-ffs" class of bug); button hit area at least 96 x 96 px | headless audit, fixtures from UI-PASS-2 7.1 (longest club name 19 characters, hero names to 11, 5 digits of cash) |
| `inplace_<screen>` | the in-place rule: instance ids unchanged across each state-changing tap; `_rebuild` is not called (a counter on the screen) | smoke |
| `touch_<screen>` | a vertical swipe starting on a card, a button, a carousel and a slider scrolls the page; a tap taps; Android back (`GO_BACK`) navigates | touch scene, simulated |
| `cb_<screen>` | in colour-blind mode, no meaning is carried by colour alone: every state-bearing control has a text, shape or icon cue (checked by reading a `cue` meta set by components, plus screenshot review) | smoke plus review |
| `nocolour_words` | no visible string uses a colour word (`tools/check_copy.py`, Narrative's script, now saved in the repo, run as a test with its allow-list) | pure logic |
| `tags_<screen>` | the tutorial ids listed for this screen in TUTORIAL 8 exist and are visible on the right state | smoke |

### 3.3 Check commands

`$GODOT` is the Godot 4.3 binary. All Godot commands are run from `game/` with `timeout`.

**Fast loop** (after every change; new file `tools/check_fast.sh`, written in I-00, target a few minutes, estimate):

```
python3 tools/validate_data.py
python3 tools/check_strings.py
python3 -m pytest tools -q                                                # v1.2: to be added to check_fast.sh (not there today)
cd game && timeout 600 $GODOT --headless --import                          # after any new class_name file
timeout 600 $GODOT --headless --script res://tests/run_tests.gd            # logic, golden vectors, string and data tests, all *_tests.gd
timeout 600 $GODOT --headless res://tests/ui_smoke.tscn                    # must end " 0 failures"
for each tests/check_*.tscn: timeout 600 $GODOT --headless res://tests/<name>.tscn
touch scenes with override.cfg present, then removed (as run_all_checks.sh does)
sha256 of game/tests/golden/* equals the value recorded in I-00
```

**(v1.2) `pytest tools` belongs in the fast loop.** `tools/check_fast.sh` as built in I-00 runs `validate_data.py` and `check_strings.py` but no `pytest`; `tools/test_merge_copy.py` (I-00b), `tools/test_check_copy.py` and the other `tools/test_*.py` therefore only run in the full check at the end. The Lead Programmer adds one step (`python3 -m pytest tools -q`, which needs `pytest` installed) to `check_fast.sh` in the next Lead Programmer slot; until then run it by hand after any change under `tools/`.

**Per-screen screenshot run** (under Xvfb, software OpenGL; never in the headless loop):

```
SHOT_DIR=<dir> SCREENS=<screen> VARIANTS=normal,large,cb,tall \
  xvfb-run -a -s "-screen 0 720x1280x24" $GODOT --rendering-driver opengl3 res://tests/shots_matrix.tscn
SHOT_DIR=<dir> xvfb-run -a -s "-screen 0 720x1280x24" $GODOT --rendering-driver opengl3 res://tests/ui_shots.tscn   # old tour, 49 images
```

**Perf gates** (`tests/perf_baseline.gd` and its scene, built in I-00 from `PERF-BUDGET.md` 7; run under Xvfb opengl3; prints `PERF|` lines): the limits are those of section 6, i.e. per-screen allowances for legacy screens and target / hard limits for redesigned ones (`PERF-BUDGET.md` 3.1a). Until I-00c adds the allowance data file the probe applies only the flat hard limits (draw calls 100, nodes 200, texture memory 48 MB), which passes on the six screens the probe visits today but does not ratchet.

**Full check** (`bash tools/run_all_checks.sh $GODOT`, about 25 minutes, run in the background): **only at the end of 0.7 (I-25)**, and once at CP2 before the APK. It adds `calibrate.py 40000 --check`, `pytest`, the soak run and everything above. Since R3 forbids simulation changes, the calibration is expected unchanged; the fast loop's golden hash is the early warning.

---

## 4. Architecture, lanes and file ownership

### 4.1 Lanes

| Lane | Who | Works in (only) |
|---|---|---|
| **G1 (UI lane)** | Gameplay Programmer | all existing files in `game/src/ui/`, `game/src/core/app.gd`, `game/i18n/en.json` (after the I-00 merge), `game/tests/ui_smoke.gd`, `ui_touch.gd`, `ui_shots.gd`, `ui_pass_tests.gd`, `alpha6_tests.gd`, new `game/src/ui/components/`, new `game/tests/check_ui_*`, `check_touch_*`, `tests/shots/` |
| **G2 (Guide lane)** | Gameplay Programmer. **A second Gameplay Programmer instance is permitted on this lane from I-06** (the Producer decides when to start it; the file split below is what makes two instances safe). With one instance, G2 work follows G1 in the order of 4.3 | new `game/src/tutorial/`, new `game/src/core/device_state.gd`, new data `game/data/tutorial_v1.json`, `help_v1.json`, `glossary_v1.json`, `lessons_v1.json`, new `game/src/game/tutorial_game.gd`, **and** the read-only game-code helpers of I-06 (`game_state.gd`, `sim/draft.gd`, `sim/report.gd`, `data/clubs.json`), `game/tests/tutorial_tests.gd`, `check_tutorial_*`, `check_save_compat` |
| **E (Art/Perf lane)** | Engine / Graphics Programmer | new `game/src/ui/art/` (`tex_cache.gd`, `icons.gd`, `badge_style.gd`, `silhouette.gd`, `avatar.gd`, `surface.gd`), `game/assets/`, `game/tests/perf_baseline.gd`, `art_tests.gd`, `check_art.tscn` |
| **Q (QA)** | QA Automation | reads everything; writes the audits listed in I-25 under `game/tests/audit_*`; owns the seed fixtures in `game/tests/fixtures/` |
| **N (Narrative)** | Narrative Designer | `docs/design/copy/*.json` only; the Producer or G1 merges; Narrative never edits `en.json` |
| **L (Lead Programmer)** | me | `tools/run_all_checks.sh`, `tools/check_fast.sh`, `game/export_presets.cfg`, `project.godot`, review of every handback, this plan |
| **T (Tools Engineer)** | Tools Engineer, **on call, not active** | The Producer may call T for a tool that is more than a script of a few dozen lines (shot matrix, perf baseline, contact-sheet builder). T edits only the file it is asked to write, and L reviews it as for any other lane |

**I-00 tooling ownership (v1.1).** The Gameplay Programmer builds the I-00 tooling (`tools/check_fast.sh`, `tools/merge_copy.py`, `tests/perf_baseline.gd`, `tests/shots_matrix.gd`, the fixtures and `check_save_compat`) and edits `tests/run_tests.gd` and `tools/run_all_checks.sh` **in I-00 only**; the Lead Programmer reviews every one of those files before the Producer commits. After I-00, `run_tests.gd` and `run_all_checks.sh` are L-only again and nobody else needs to touch them, because of auto-discovery. The Tools Engineer is on call if a tool turns out to be large. I-00 is already in build with the hold-list and the fresh-save fixture; **it is recorded here as amended, not as a redo**. I-00b and I-00c are built and reviewed the same way.

When there is a single Gameplay Programmer, G1 and G2 run one after the other in the order given in section 4.3; the file split is the same so a later switch to two agents costs nothing.

### 4.2 Ownership of hot files (never two writers)

| File | Writer | Others who need a change |
|---|---|---|
| `src/ui/ui.gd`, `main.gd`, `screen.gd`, `app.gd` | G1 only | G2 and E send "integration lines" in their handbacks (each is a few lines: create the overlay in `Main`, forward events, add `help_id()`) |
| `src/ui/screen_*.gd` | G1 only | G2's tags are added by G1 as each screen is rebuilt (the tag list per screen is in the increment) |
| `src/game/game_state.gd`, `sim/draft.gd`, `sim/report.gd` | G2 in I-06 and I-13 only; **nobody else in 0.7** | G1 needs a data helper: request it in a handback; G2 adds it in the next G2 slot |
| `i18n/en.json` | G1 (append only, one block of keys per increment, sorted by prefix); the I-00 merge and every later release of a held key go through `tools/merge_copy.py`, and G1 deletes the key from `docs/design/copy/hold_0_7.json` in the releasing increment (the one exception to "Narrative owns `docs/design/copy/`"). **Copy edits after the merge (route A, built in I-00b):** Narrative writes a patch file, `tools/merge_copy.py --update` applies it only to keys named in the allow-list `docs/design/copy/owned_keys.txt` (add mode appends every key it merges; changing the list is a Producer or Lead Programmer edit, never Narrative's), G1 runs it in the increment that needs the edit | G2 and others hand G1 a key list; Narrative's patch files are the source |
| `tests/run_tests.gd`, `tools/run_all_checks.sh` | G1 in I-00 only, reviewed by L; L afterwards | nobody, because of auto-discovery |
| `tools/validate_data.py` | L owns; G2 may extend it in I-06 only (club fields), reviewed by L | |
| `tests/fixtures/` | created by G1 in I-00 (`save_0_6_a` to `_d` and `gen_save_fixtures.gd`, now present); **owned by Q from now on** (every later fixture, including any new save fixture, is Q's) | the generator says "do not regenerate with later code": new fixtures are new files |
| `project.godot`, `export_presets.cfg` | L | any change request goes in a handback (in wave 2a the font default and the OFL filter were edited by roles other than L; from now a change is requested in a handback) |
| `data/clubs.json` (club `colors` and `badge` ids), `data/heroes.json` | G2 in I-06 for clubs (additive fields only); heroes are read-only | |

### 4.3 Dependency order and what can overlap

```
I-00 -> I-01 -> I-00b -> I-00c -> I-02 -> I-03 -> I-04 (CP1)
                  |                |
                  |                +-> I-05 (E, art code; starts after I-02) --+
                  +-> I-06 (G2, core hooks; starts after I-00) ----------------+
I-03 -> I-07 -> I-08 -> I-09 -> I-10    (components, G1; need I-05 for badges and silhouettes)
I-06 -> I-11 -> I-12 -> I-13 -> I-14    (tutorial, G2; I-12 needs I-03 hooks and I-08 BottomSheet)
I-14 -> I-21a Tag-only work on the screens that stay as they are (G1; run it directly before I-15)
I-10 + I-21a -> I-15 Home -> I-16 Draft (engine preview, optional APK) -> I-17 Game Plan -> I-18 Report (CP2)
             -> I-19 Squad -> I-20 Standings -> I-21b Plan, Club, Match day restyle
I-14 + I-16 -> I-22 Help and glossary -> I-23 Lessons -> I-24 -> I-25 (CP3)
```

Screen order is UI-PASS-2 8.1 as written (Home, Draft, Game Plan, Report, Squad, Standings, then the parallel Plan and Club restyle); the plan does not reorder it. The additions to 8.1 are the ones named in section 0.

Real parallelism with two builders: G1 runs I-00b, I-00c, I-02 to I-04, I-07 to I-10, I-21a, I-15 to I-21b; E runs I-05 beside them; G2 (a second Gameplay Programmer instance is permitted from I-06) runs I-06, I-11 to I-14 beside I-07 to I-10, then I-22 to I-24 beside the later screens. The screen tags that the tutorial needs arrive with each screen (G1), except the screens that are not redesigned, whose tags arrive early in I-21a; the first-run walkthrough only plays end to end when I-17, I-18, I-19 and I-20 are done, so until then the steps for screens still to come show their card without a hole ("fallback card" mode: tag missing) and G2 runs the full 20-test set in I-25. Section 10 lists which steps are fallback cards at each checkpoint.

---

## 5. Save-file compatibility plan

1. **No `GameState.VERSION` bump.** (A bump makes `load_save` return `null` and drops the player's save.)
2. **New additive key `tutorial`** (TUTORIAL 6.1): `{"v": 1, "state": "new"|"running"|"done"|"skipped"|"legacy", "step": "<id>", "game": {"live": bool, "n": int, "plan": {...}}}`. Its own `v` is the tutorial schema version. **v1.1 adds the state `new`** to the four of TUTORIAL 6.1 (the TUTORIAL document needs the same one-word addition, section 13).
3. **Two different defaults, two different meanings (v1.1).**
   - **`legacy`** means "this save was made before the guide existed". `from_dict` turns a **missing** `tutorial` key into `{"v": 1, "state": "legacy"}`. This is the whole migration for 0.1 to 0.6 saves, and a player who made a new game in 0.6 and then updates is also `legacy` (one inline card on Home, no modal).
   - **`new`** means "this save was made by 0.7 or later and the player has not yet answered the guide". **`GameState.new_game()` writes it explicitly**: `{"v": 1, "state": "new", "step": "welcome", "game": {"live": false, "n": 0, "plan": {}}}`, unless a `carry` dictionary brings its own `tutorial` (next season, below). Because the key is written, a reload never turns a brand-new save into `legacy`.
   - **What `new` does on Home.** The first time Home is shown with state `new`: if this device has never answered the guide (`[tutorial] welcome_seen` absent), the welcome modal (step 1) shows with Start and Skip tutorial; otherwise (the device finished or skipped it before) the inline card "Welcome back" shows with Show me and No thanks (TUTORIAL 6.2). **Start** or **Show me** sets `running` (step `welcome`, resume rules below) and sets `welcome_seen`; **Skip tutorial** or **No thanks** sets `skipped` and sets `welcome_seen`. Until one of those taps, the state stays `new` and the device flag stays unset, so killing the app at the welcome modal simply shows it again. This is the difference from `legacy`: `legacy` never shows a modal and is offered once per device; `new` always asks until answered. `Delete save and start over` makes a `new` save, device flags unchanged, so the second club gets the inline card and not the modal.
4. **`TutorialState.migrate(dict)`** (pure function, in I-11): `v` absent or 1 returns the dict unchanged apart from the resume rule in item 10; an **unknown higher `v`** (a save from a future build opened by an older one) is treated as `legacy` and not modified, so it never crashes; a malformed `state` string falls back to `legacy`; a `step` id that no longer exists in `tutorial_v1.json` falls back to the first step of its chapter (resume survives data edits).
5. **Carry across seasons.** `next_season()`'s `carry` dictionary and `new_game()`'s carry handling must copy `tutorial` whatever its state (otherwise it resets at season end; found by reading line about 842). `new` stays `new`, `running` stays `running`. I-06 does it and tests it for all five states.
6. **Device state** in `settings.cfg` sections `[tutorial]`, `[lessons]`, `[help]` (old `[tips]` keys map into `[help]`) via a new `DeviceState` class (I-11), so `app.gd` is not edited by G2. The existing `tip_seen/tip_mark/tips_reset` stay until I-24 retires the old tips.
7. **Fixtures.** I-00 captures real 0.6 saves (written by the 0.6 game code; never regenerate them with later code) as `game/tests/fixtures/save_0_6_a.json` (new game, round 1), `_b` (mid-season with a custom plan and a hired free agent), `_c` (season end, before `next_season`), and, added in v1.1, **`_d` (a brand-new game, first club, round 1, nothing played, written through the real `GameState.save()` so it is a file the game itself wrote, not a stringified dictionary)**. `_a` and `_d` hold the same situation; the difference is how the file was written, and `_d` is the "fresh save" the reviewer asked for. Test `check_save_compat` loads each through `GameState.from_dict`, runs `plans_for`, `next_game`, a full game, `next_season`, a save (`JSON.stringify(gs.d)`, which is what `GameState.save()` writes; there is no `to_dict`), reloads it through `JSON.parse_string` and `GameState.from_dict`, and asserts the tutorial key is `legacy` and survives. It also runs a save written with `tutorial.v = 99`. **The 0.7 fresh save is tested in I-06 without a new fixture file**: after I-06, `new_game()` then `save()` to a temporary path then `load_save()` must give state `new` with `game.n == 0`, and the same through `to_dict`/`from_dict`.
8. **Sandbox games never touch the save.** The tutorial game writes nothing to `d["fixtures"]`, standings, Form Rating, morale, cash, pace log, fatigue or `save_seed` stream (I-13 tests all of them by deep-comparing `gs.d` before and after, except the `tutorial` key).
9. **`Delete save and start over`** also clears the save's tutorial state (the save is gone); device flags stay (TUTORIAL 6.3). The next `new_game()` writes `new` again (item 3).
10. **Resume after the app is killed mid-tutorial (v1.1).** What is saved: the `tutorial` key, including `game.live`, is written with every autosave. What is **not** saved: a draft in progress (`draft.leave.body` already says so) and anything of the tutorial game's match; the tutorial game writes no result to the save (item 8). So after a kill the game cannot be continued, and the rule is: on load, `TutorialState.migrate()` applies the "resume at" column of TUTORIAL 3.1 and clears the sandbox: if state is `running` and `game.live` is true, or the step lies in chapters 3 to 5 (steps 7 to 20), then `step` becomes `tab_plan` (step 7), `game.live` becomes false and `game.plan` is emptied; if the step lies in chapter 6 (steps 21 to 23), it becomes `tab_club` (step 24, the game is over and nothing to review remains); chapters 1 and 2 resume at steps 2 and 4 as in the table, and chapter 7 at step 24. `game.n` is **not** changed by a resume (it rises only on Start and on Replay), so the restarted game is the same game: same seed id, same opponent, no duplicate. Home then shows the inline "Welcome back. Continue the guided first game?" card with Continue and Skip tutorial, never a modal. A pause without a kill (the app is backgrounded and comes back) keeps everything in memory and changes nothing. Tests: I-11 (pure logic, every step), I-14 (save and reload at steps 12, 18 and 21 through the real files), TUTORIAL 9 test 6.

---

## 6. Gates (budgets that fail a check)

**Source of the limits: `PERF-BUDGET.md` section 3.1a (rewritten in review wave 2a), not a flat number.** v1.0 of this plan made 100 draw calls and 200 nodes a hard fail for every screen; against the baseline that fails on day one (Chemistry scrolled 150 draw calls, Report and Game Plan over 120 nodes). The rules now are:

| Gate | Limit | Where checked |
|---|---|---|
| Draw calls and nodes, **legacy screen** (not yet redesigned) | Its **row in the allowance table** (3.1a rule 1): today's measured value plus 10 percent, rounded up to the next 5. A row may go down, never up. The check prints "tighten to N" when a row is 10 percent or more over its measurement | `perf_baseline` (flat hard limits until I-00c adds the data file), every screen step |
| Draw calls, nodes, canvas items, **redesigned screen** | **Target 60 / 120 / 700, hard 100 / 200 / 1,200**, at the top and at the bottom of every scroll; one waiver line (number, reason, the Technical Director's name) between target and hard; **the screen's allowance row is deleted in the same commit as its redesign**; new sheets, overlays and components start here, measured together with the screen under them | same |
| A visited state with **no row** | Held to the hard limits and printed "NO ROW"; it gets a row at its measured value in the commit that finds it | same |
| Re-baselines | Exactly two: **after I-04** (token sizes final) and **after I-22** ("?" button and help hooks add nodes everywhere). Each is one commit reviewed by the Technical Director with every changed row beside its old value. Any other raise needs the Technical Director's written reason in the table | I-04, I-22 |
| Texture memory | target 32 MB, hard 48 MB | same |
| Shadowed surfaces visible / glowing | **6 / 2, one number each** (the gate is the limit) | audit in the components gallery and per screen |
| Font weight-and-size pairs | **12** (what the ART-BIBLE 5.2 type scale needs; 16 hard with the `tnum` variants) | font test in I-02, `PERF-BUDGET.md` 3.2 |
| Idle redraws | none when nothing changes (`Engine.get_frames_drawn()` constant for 2 s) | I-25 with the Settings low-processor decision |
| Tap response | no component rebuild on tap; in-place audit | each screen step |
| `_rebuild` on a redesigned screen | zero calls on a state-changing tap | `inplace_<screen>` |
| Touch target | 96 x 96 px hit area, text floor 24 px | `fit_<screen>` |
| Golden vectors | unchanged hash | fast loop |

The starting point of the ratchet is the I-00 fixed-seed table in the I-00 status (nodes / draw calls: Home 60 / 55, Squad 36 / 40, Draft 81 / 42, Game Plan 133 / 49, Report 151 / 24, Standings 82 / 29) and the per-state rows of `PERF-BUDGET.md` 3.1a. **Only the 6 screens the probe visits have exact fixed-seed numbers; the other states have rows from the earlier 12-state measurement or none (rule 3).** Everything here is a computer-side count; none of it has been measured on a phone.

---

## 7. The increments

Format for each: **Goal · Lane · Needs · Files (create C, change M) · Helpers and components · Strings · Tests · Acceptance · Rollback · Effort (estimate)**. "Screenshots" means the matrix subset. Component names follow UI-PASS-2 section 5 and 5.16 (names there are suggestions; these are the names to use).

### I-00 Safety net, structure and the one string merge

- **Status (v1.1, updated 2026-11-10).** **Built by the Gameplay Programmer; review by the Lead Programmer pending.** It was **amended, not redone**, by two v1.1 items: the merge takes a hold-list and the fixture set gains `save_0_6_d`. Facts from the I-00 handback (I have not re-run them): 536 keys merged (524 new, 12 replaced), 4 held through `docs/design/copy/hold_0_7.json`; fixtures `save_0_6_a` to `_d` exist under `game/tests/fixtures/`; `check_save_compat`, `perf_baseline`, `shots_matrix` and `tools/check_fast.sh` exist. **Fixed-seed perf "before" table** (nodes / draw calls): Home 60 / 55, Squad 36 / 40, Draft 81 / 42, Game Plan 133 / 49, Report 151 / 24, Standings 82 / 29 (the Report node count is 151 here against 153 in `PERF-BUDGET.md` section 2, a different state or seed; the fixed-seed table is the one the ratchet starts from, unless the Technical Director says otherwise). Follow-ups it leaves are in I-00b (built) and I-00c.
- **Goal.** Make everything after this measurable and conflict-free: structure for tests, fixtures, baselines, and merge Narrative's keys (536 now, 4 later).
- **Lane / Needs.** The Gameplay Programmer (G1) builds all of it; the Lead Programmer reviews every file before it is committed (section 4.1); the Tools Engineer is on call if a tool turns out large. Nothing before it.
- **Files.** C `tools/check_fast.sh`; C `game/tests/perf_baseline.gd` and `.tscn` (the probe from `PERF-BUDGET.md` 7); C `game/tests/shots_matrix.gd` and `.tscn`, `game/tests/shots/shots_baseline.gd` (wraps the existing 49-shot tour as one module); the fixtures `game/tests/fixtures/save_0_6_a.json` to `_d.json` with `gen_save_fixtures.gd` (already in the working tree, adopted, not recreated); C `game/tests/check_save_compat.gd/.tscn`; M `game/tests/run_tests.gd` (auto-discovery loop; keep the existing explicit calls until their files are renamed, then delete them); M `tools/run_all_checks.sh` (loop over `check_*.tscn`; add golden hash and perf gate); M `game/i18n/en.json` (merge `docs/design/copy/en_0_7.json` through `tools/merge_copy.py`, **with the hold file `docs/design/copy/hold_0_7.json` of section 2.6**: it reports the 12 replaced keys it applied and **names the 4 it held**); M `game/tests/*` where a test or `ui_shots` matches a replaced string (the review's grep found none; still confirm by running).
- **Helpers.** None new in game code.
- **Strings.** **536 keys merged** (524 new, 12 replaced) and 4 held (`draft.meta_hint`, `about.title`, `about.included.b`, `about.test.b`; section 2.6 gives the release increments). The Coach and Manager rename comes with the merge, so `advisor` and `owner and coach` disappear here, not later (none of the 3 old strings is among the 4 held). `check_strings.py` must show 0 unknown keys; unused-key notes are expected (the new keys are not used yet) and are informational by design.
- **Tests.** Fast loop green before and after the merge; `check_save_compat` (fixtures A to D load, full game, next season, each reads `legacy`; **`_d`, the brand-new 0.6 game written through `save()`, must read `legacy` too, which proves a 0.6 new game upgrades without a modal**); a merge test (a scratch copy of `en.json`: merging with the hold-list leaves the 4 old texts byte-identical and adds 524 keys; merging with an empty hold-list gives the review's 1,169 keys); perf baseline printed for the 6 main screens and stored in the handback as the "before" table; golden hash recorded in `tools/check_fast.sh`.
- **Acceptance.** Fast loop green; the 49-image tour still runs; no old test line failed because of a replaced string (all fixed); baseline numbers recorded; the merge report lists the 4 held keys.
- **Rollback.** Revert the commit (the merge is one commit; `en.json` is the only shared file).
- **Effort (estimate).** 25 to 45 tool calls (was 25 to 40; the hold-list and its test add about 5).

### I-00b Copy update route (follow-up to I-00, small)

- **Status (v1.2, 2026-11-10).** **Built** (per the Producer log; I read `tools/merge_copy.py`, `tools/test_merge_copy.py`, `docs/design/copy/owned_keys.txt` and `docs/design/copy/en_0_7_patch2.json` in the working tree, and have **not run** the script or its test). What exists: `tools/merge_copy.py --update FILE` (update mode: changes the text of keys that already exist and are on the allow-list; dry run by default, `--write` writes, `--expect-changed N`, `--allow-placeholder-change` for a programmer only, `--seed-owned` once); the allow-list is **`docs/design/copy/owned_keys.txt`** (v1.1 called it `update_allow.json`; the Producer's log of 2026-11-10 names `owned_keys.txt`); add mode appends every key it merges to the list; `tools/check_copy.py` runs on the whole result before any write and one error stops it. **`patch2` is applied** (`en_0_7_patch2.json`, six keys: `role.short.jg`, `role.short.sup`, `chem.pentagon_hint`, `player.tab.overview`, `player.tab.stats`, `player.tab.career`). **Not built here:** the perf allowance data file, now **I-00c**.
- **Goal.** After the one-off merge, copy edits needed a route into `en.json` (the review's X9: Narrative never edits `en.json`, and `merge_copy.py` refuses duplicates).
- **Lane / Needs.** The Gameplay Programmer built it, the Lead Programmer reviews, the Tools Engineer is on call (section 4.1). Needed I-00.
- **Files.** M `tools/merge_copy.py` (update mode, route A: refuses a key that is not on the allow-list, a key that does not exist yet, a held key, a changed `{placeholder}`, non-ASCII text or a duplicate; prints old and new text for every change); C `docs/design/copy/owned_keys.txt`; C `tools/test_merge_copy.py`.
- **Strings.** none.
- **Tests.** `tools/test_merge_copy.py` (runs only under `pytest tools`; see 3.3, it is not in the fast loop yet).
- **Acceptance.** An allowed copy edit goes through the script with a visible diff.
- **Rollback.** Revert the commit.
- **Effort (estimate).** 15 to 25 tool calls (the original estimate, which also covered the perf allowance file; that half moved to I-00c, so the two lines are slightly double counted, on the safe side; the spent effort was not reported).

### I-00c Perf allowance data file (follow-up to I-00b, small; v1.2, new)

- **Goal.** `perf_baseline.gd` applies only the flat hard limits (read from the source, not run), while `PERF-BUDGET.md` 3.1a asks for per-screen allowances with a ratchet. This is the half of the old I-00b that was not built.
- **Lane / Needs.** The Gameplay Programmer builds, the Lead Programmer reviews. Needs I-00 (the fixed-seed table). Run it right after I-00b and before I-04, whose re-baseline no. 1 edits this file's rows.
- **Files.** M `game/tests/perf_baseline.gd`; C `game/tests/perf_allowances.json` (one row per visited state: draw calls, nodes, status `legacy` or `redesigned`, the increment that retires it, waiver reason; seeded from the I-00 fixed-seed "before" table and `PERF-BUDGET.md` 3.1a). The check fails a legacy screen over its row, a redesigned screen over target without a waiver, and any screen over a hard limit; it prints "NO ROW" for a state without a row and "tighten to N" when a row is 10 percent or more over its measurement.
- **Strings.** none.
- **Tests.** `perf_baseline` (under Xvfb, as today) fails on a deliberately lowered row in a scratch copy of the file and prints "NO ROW" for an unlisted state; fast loop green.
- **Acceptance.** The perf check reads its limits from `perf_allowances.json`; the six probed screens pass on their seeded rows.
- **Rollback.** Revert the commit.
- **Effort (estimate).** 10 to 20 tool calls.

### I-01 Spikes made permanent

- **Status (v1.2, 2026-11-10).** **Built and accepted** (Producer log 2026-11-10). Results: `docs/design/SPIKE-RESULTS-0.7.md`, copied into section 9.5 of this plan. All four spikes pass their conditions; two designs change: **S1** (the lock only works with non-interactive cards owned by the Carousel, I-08) and **S4** (one self-drawing `Control` per card fails the draw-call gate, 107 calls; one `HeroGrid` `Control` is the design, I-09). `check_gestures.gd/.tscn` (27 checks) keeps that name. I have read the results document and have not re-run the spikes. Nothing ran on a phone.

Four short spikes. Each ends as a test that stays in the repo, because the answers decide later designs.

| Spike | Question | Pass condition | If it fails |
|---|---|---|---|
| **S1 Nested scroll** | A horizontal carousel inside the vertical page: does a mostly vertical diagonal swipe starting on the carousel still scroll the page? **Scratch result: it stole the swipe (fail).** | A custom direction lock in the Carousel: after 12 px of travel, a drag is horizontal only if |dx| > |dy|, otherwise it is forwarded to the parent `ScrollContainer`. Tested with simulated touch from 5 start angles | Carousel becomes a plain horizontal `HFlowContainer` with a "See all" link (Home upcoming row, Squad market row); the cut list says this feature goes first anyway |
| **S2 B11 Hole tap** | A tap inside the coach overlay's hole reaches a button inside a `BottomSheet` on a lower layer, with the other three dim panels blocking. **Scratch result: pass on desktop in the probe (not run on a phone).** | The same test, in the repo, using the real `BottomSheet` once I-08 exists; until then, a scratch `CanvasLayer` pair | Stage-B steps become card-only (Next on the card runs the control's action; TUTORIAL 11 fallback); the sheet steps lose their ring but keep their text |
| **S3 Surface** | `StyleBoxFlat` (one draw call per card, shadow adds fill area only) against a baked 9-slice `StyleBoxTexture` from one shared atlas (one draw call for 10 cards in `PERF-BUDGET.md` 5, but it breaks when text or icons interleave) | Measure a Draft-like screen with 8 cards in both ways, draw calls under Xvfb | Keep `StyleBoxFlat` + shared `UI.box()` cache; baked 9-slice stays the documented first fix if the phone test shows jank |
| **S4 HeroCard nodes** | A 40-hero grid as 40 `PanelContainer`s with children against 40 single-`Control` cards that draw themselves | Node count at most 60 for the grid; frame work per filter change under 5 ms headless (**and, added after the run, draw calls inside the screen's hard limit of 100**) | (v1.2) Virtualising was the v1.1 fallback and would not help (it does not touch the failing number, 9.5); the answer found is one `HeroGrid` `Control`, with B3 as the alternative |

- **Files.** C `game/tests/spike_*.gd` plus scenes (kept in `tests/spikes/`, excluded from the export by the existing `tests/*` filter); C `game/tests/check_gestures.gd/.tscn` (S1 and S2 as permanent checks, with `override.cfg` touch emulation).
- **Strings / helpers.** none.
- **Acceptance.** Each row has a measured result written in the handback and copied into section 9 of this plan by L (done in v1.2, section 9.5). The Carousel and hero grid designs are chosen from the result (I-08, I-09).
- **Rollback.** Delete the spike files.
- **Effort (estimate).** 30 to 45 tool calls.

### I-02 Tokens, theme, font weights, large text

- **Goal.** One global change to the look: all type sizes, colours, radius, button height and the font weights, then the whole app re-shot and fixed. The app still plays exactly as before.
- **Lane / Needs.** G1 (`ui.gd`, `app.gd`). Needs I-00.
- **Files.** M `src/ui/ui.gd`; M `src/core/app.gd` (large-text hook only); C `game/assets/fonts/font_weights.tres` set if needed. (The OFL step of v1.0 is removed: `export_presets.cfg` already ships `assets/fonts/OFL.txt`, commit `d78038d`.)
- **Helpers.** In `ui.gd`: sizes `S_DISPLAY 64, S_TITLE 48, S_BIG 40, S_HEAD 36, S_BODY 32, S_SMALL 26, S_CAPTION 24`, `BTN_H 96`, `R_CARD 24`, `GAP 16`, `TAB_H 112`, `HEADER_H 96`; the ART-BIBLE 3 colour tokens (`VOID, TEXT2, TEAL_HI`, the five role colours, side colours) kept alongside the old names so unredesigned screens do not break (old names become aliases); `UI.font(weight: String, tnum: bool = false) -> Font` returning cached `FontVariation`s for Regular, Medium, SemiBold, Bold, ExtraBold with `opentype_features = {"tnum": 1}` for numbers; `UI.num_label(...)` that applies tnum; `UI.box()` gets a cache keyed by (colour, radius, border, shadow); `make_theme()` sets weights per control (buttons SemiBold). `UI.button` clamps `custom_minimum_size.y` to at least 96 (the quick fix for the 64 to 76 px buttons on unredesigned screens).
- **Strings.** none new.
- **Tests.** `check_tokens` (a pure-data test of token values against the ART-BIBLE 5.2 table, so a drifting constant fails); font test: `tnum` digits '1111' and '8888' have the same width in `UI.font("SemiBold", true)`; all five `.fontdata` resolve; the 49-image tour in normal and large text; fit audit on the six existing main screens.
- **Screenshots.** The full old tour (49), normal and large. First look: overflow and clipped text; second look: weights, tnum columns, button heights.
- **Acceptance.** No overflow on the old screens at 720 and 626 px; every button at least 96 px high; the OFL text still in a test export listing (`--export-debug` to scratch, list the APK; a check that it has not been lost, since the fix is already done); smoke and touch green; node counts within 10 percent of baseline.
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
  - **Tab bar tags (v1.1; v1.0 left them unassigned):** `Main` tags the tab bar as `tabbar` and its five buttons `tab.home`, `tab.squad`, `tab.plan`, `tab.club`, `tab.more` (TUTORIAL 8). Tutorial steps 3, 4, 7 and 24 point at them, so they are real at every checkpoint.
- **Strings.** none.
- **Tests.** `check_frame` (also: all six tab ids are found while the tab bar is visible, and `tap:tab.squad` fires on a press): the layer order (instance order and `layer` values), a tag is found only while visible, freeing a tagged node removes the entry, `tap:` events fire from a button press and from a simulated tap, `screen:` events fire on `show_screen`, back button still works (touch scene); tab label "Trophies" fits on one line at 626 px.
- **Screenshots.** Old tour subset: Home, Plan, Club, Settings (normal and large).
- **Acceptance.** Old tests green; no screen changed except the frame.
- **Rollback.** Revert; no data changes.
- **Effort (estimate).** 55 to 75 tool calls (was 50 to 70; the tab bar tags add about 5).

### I-04 Overflow sweep of the screens that are not redesigned (CP1)

- **Goal.** Everything that is not one of the six screens looks right at the new sizes: Finance, Training, Chemistry, Free agents, Negotiation, Practice, Prematch (Match day), Settings, Club select, Title, About, Season end, Game over, Match.
- **Lane / Needs.** G1. Needs I-02, I-03.
- **Files.** M the matching `screen_*.gd` and `player_view.gd` (layout fixes only: wraps, minimum sizes, `kv_row` that squeezed values to one character per line); M `ui_shots.gd` only if a name changes.
- **Strings.** none.
- **Tests.** `check_fit_legacy`: the fit audit runs over all of these screens in normal, large and tall.
- **Screenshots.** The old tour in all four variants (49 images times 4 = **196 images**; pixel diff against I-02 first, then the changed ones by eye). **196 images inside 40 to 60 calls only fits if looking is batched** (R1(d)): 196 images are 33 contact sheets of 6, and the range holds only if the pixel diff leaves at most about half of them to be looked at, twice, and the fit audit carries the text-fit check. Looked at one by one, two passes would be about 400 views and the increment would not be 40 to 60 calls.
- **Acceptance.** No overflow, no mid-word break, all targets 96 px; **perf re-baseline no. 1 of 2 (section 6): every legacy row in the allowance table is reset to its measured value, one commit reviewed by the Technical Director, old and new values side by side**; **CP1: the Producer can show the Founder the same game in the new type, colours and font.**
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
- **Files.** M `src/game/game_state.gd`: `upcoming(n) -> Array` (read-only over `d["fixtures"]`), `cut_gap() -> Dictionary` (over `standings()`), `tutorial() -> Dictionary` and `set_tutorial(dict)` (read and write the `tutorial` key), **`new_game()` writes the `new` state of section 5 item 3**, `from_dict` defaults a missing key to `legacy`, `tutorial` copied in `next_season()`'s `carry`; M `src/sim/report.gd`: `Report.team_kills(res)` (sums `Report.kda`); M `src/sim/draft.gd`: `Draft.best_slot_for(team, hero_id)` (extracted from the inline logic in the Draft screen's `_actions`; the screen is not changed yet); M `data/clubs.json`: additive `colors` and `badge` ids (validated by `tools/validate_data.py`, which G2 extends); C `game/tests/hooks_tests.gd`.
- **Strings.** none.
- **Tests.** `upcoming` and `cut_gap` against hand-made fixtures; `best_slot_for` equals the old inline result over every hero in a recorded draft (so the screen can switch later with no behaviour change); `team_kills` equals the sum; **tutorial state (v1.1):** a missing key (fixtures `save_0_6_a` to `_d`) reads `legacy`, **including `_d`, the 0.6 brand-new game**; `new_game()` then `save()` to a temporary path then `load_save()` gives state `new`, step `welcome`, `game.n` 0, `game.live` false, and the same through `JSON.stringify(gs.d)` then `JSON.parse_string` then `GameState.from_dict` (a reload never turns it into `legacy`); `Delete save and start over` followed by `new_game()` gives `new` again; `next_season` keeps the state for all five values; a save with `tutorial.v = 99` reads `legacy`; golden hash unchanged; `validate_data.py` passes with the new club fields; the 4 save fixtures from I-00 still load.
- **Acceptance.** All logic tests green with unchanged golden vectors; no sim constant touched.
- **Rollback.** Revert the commit.
- **Effort (estimate).** 30 to 45 tool calls (was 25 to 40; the fresh-save and five-state tests add about 5). G2 may run as a second Gameplay Programmer instance from this increment (section 4.1).

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
- **Files.** C `src/ui/components/bottom_sheet.gd` (`BottomSheet.open(title, build_content, build_footer, size := "M")`, own `CanvasLayer` 20, scrim is one `ColorRect` (no blur), drag handle, tap on scrim and Android back close it, `close()` always `call_deferred`); C `src/ui/components/carousel.gd` (`Carousel.new(card_w, items, see_all)`). **Carousel design (v1.2, from the S1 result):** one `Control` that **owns hit-testing**. Its cards are display items (drawn, or controls with `mouse_filter = MOUSE_FILTER_IGNORE`), **never Buttons**: with a Button or any non-IGNORE child the engine keeps routing later drags to that child and the lock fails at 60 and 90 degrees (9.5, S1). **Direction lock:** after 12 px of finger travel it decides once per touch, horizontal if |dx| > |dy|, otherwise vertical. Horizontal: it moves its own content and swallows both the drag and the emulated mouse motion (swallowing only the drag lets the page scroll from the mouse motion). Vertical: it stops swallowing, so the page scrolls. Until the decision it swallows, so the page does not twitch. **Tap:** it finds the card under the finger itself and emits `card_tapped(i)` on release if the finger has moved at most 12 px in screen distance (12 px tap slop). A button inside a card is not tappable on its own; the card taps. Items beyond 8 show "See all". No inertia in the spike; a fling is added here. Reference code: `game/tests/spikes/spike_carousel.gd` (about 90 lines). C `tests/check_sheet.gd/.tscn`; C `tests/check_touch_gestures.gd/.tscn` (the real components; not `check_gestures`, which stays the spike check).
- **Strings.** `sheet.close` (merged copy has the keys).
- **Tests.** Sheet: opens and closes by every route (button, scrim, back, swipe down), the page behind keeps its scroll position and its instance ids, only one sheet at a time, a sheet opened from a sheet replaces it; a button inside the sheet receives a real tap. **S2 re-run on the real `BottomSheet` (v1.2):** the 8 rows of the S2 table in 9.5, with `rig.sheet_btn` and the hole set to the real sheet's controls (the overlay is still the scratch four-panel pair until I-12). **S1 re-run on the real `Carousel` (v1.2):** the 10 swipe rows of 9.5 (5 start angles, 2 directions, same pass rule: under 45 degrees the page moves at least half the vertical travel and the carousel at most 2 px; 45 and over the carousel moves at least half the horizontal travel and the page at most 3 px); a tap on card 1 gives card 1, a tap with 6 px of jitter still gives card 1, a horizontal and a vertical swipe that start on a card tap nothing; a vertical swipe that starts in the gap between cards (not tested in the spike); items beyond 8 show "See all"; all in large text.
- **Screenshots.** Gallery subset: sheets in S, M, L sizes; carousel at rest and scrolled.
- **Acceptance.** The gesture tests pass: S1 10 of 10 rows and S2 8 of 8 rows on the real components. **The plain-row fallback is no longer needed on this evidence (v1.2)**; it stays as insurance for the phone test (a real finger, section 9.4) and as cut-list item 1 (section 10), a decision for after that test, not now.
- **Rollback.** Revert; no screen depends on it before I-15.
- **Effort (estimate).** 60 to 80 tool calls.

### I-09 Cards: PlayerCard, HeroGrid (with the HeroCard drawing helper), LaneRow and LaneBoard

- **Goal.** The picture-led components of the draft and the squad.
- **Lane / Needs.** G1. Needs I-05, I-07; S4 result from I-01 (design C, section 9.5).
- **Files.** C `src/ui/components/player_card.gd` (`PlayerCard.make(pid, variant, opts)`: avatar card for bench, lane token, free-agent card); C `src/ui/components/hero_grid.gd` (`HeroGrid`, **v1.2, design C**: one `Control` that draws all 40 cards itself in **three passes** in `_draw`: all card backgrounds, then all portrait discs and state marks (one atlas run), then all text grouped by font size (one run per size); it **owns hit-testing** by the S1 rule (a release more than 12 px from the press is a drag, not a tap) and emits `hero_tapped(hero_id)` (the signal name is mine); state is plain data (`set_heroes(ids)`, `set_state(hero_id, state)` or a dictionary, `set_filter(role)`), every setter ignores an equal value, and a change ends in one `queue_redraw`; its `custom_minimum_size` follows the filtered row count; reference code `game/tests/spikes/hero_grid_probe.gd` and `s4_touch.gd`); C `src/ui/components/hero_card.gd` (`HeroCard`, **a static drawing helper, no node**: `HeroCard.draw(ci, rect, hero, state, pass := -1)`; `pass` 0, 1 or 2 draws one pass for the grid, -1 draws all three for a single card, which is what the **hero sheet preview and the lane tokens** use, so one piece of code draws a hero everywhere; the `pass` parameter is my addition to the spike's `draw(canvas, rect, hero, state)`); states: available, selected, banned (a drawn X and a text cue, not colour only), picked by you, picked by them (circle against hexagon); C `lane_row.gd` and `lane_board.gd` (five rows, you left and them right); C `tests/check_cards.gd/.tscn`; C `tests/check_touch_cards.gd/.tscn`.
- **Costs of design C, accepted by the Producer log of 2026-11-10.** No per-card focus node (focus and accessibility are the grid's job, so a screen reader sees one control; the grid offers `cue_for(hero_id) -> String` for the colour-blind audit and for tests); one redraw repaints all 40 cards, so a change to one card costs the whole grid (0.06 ms headless in the spike, a phone is slower); off-screen cards sit in the same canvas item, so its cost does not fall when scrolled (at 7 calls this does not matter).
- **Alternative if design C hits a wall (B3).** One `Control` per card with one atlas and **one font size** for name and tag (no initial letter): measured 65 draw calls for the grid on screen, so the Draft screen sits near 65 plus the rest of the page, which needs the one waiver line of section 6 (between target 60 and hard 100) and a UI/UX answer on the tag size, since the art bible's card has the name at Small 26 and a smaller tag. B and B2 as measured (107 calls) are **not** acceptable, and virtualising does not help.
- **Strings.** from the merged copy (`draft.*`, `squad.*` keys); add none unless a gap is found, in which case G1 asks N.
- **Tests.** The 40-hero grid is **1 node** (measured; the S4 gate of at most 60 stays as the ceiling) and **at most 15 draw calls** at the top and at the bottom of the scroll under Xvfb (7 measured with placeholder discs; the margin allows a silhouette atlas as a second texture; the 15 is my choice, to be confirmed by the Technical Director); a filter change and 8 state changes in under 5 ms headless (0.06 ms measured; ratio against baseline, not an absolute claim); **touch, re-run on the real `HeroGrid` (v1.2):** a tap on the first card gives `brannoch`, a tap with 6 px of jitter still taps, a swipe that starts on a card scrolls the page and taps nothing; the longest hero name "Gravenstone" at Small 26 fits the 183 px large-text card (measured 128 to 130 px in `PERF-BUDGET.md` 6); all five state cues present (`cue_for`); avatar for 19-character club names and 11-character player names; `HeroCard.draw` with `pass` -1 equals the three passes in sequence (same pixels in a `SubViewport`).
- **Screenshots.** Gallery: grid in all states, lane board with two filled and three empty rows; normal, large, colour-blind (**the banned and picked states must be readable in grayscale**), tall.
- **Acceptance.** Gate numbers recorded; colour-blind screenshot looked at twice. If real silhouettes push the grid over 15 calls, or a per-card focus turns out to be needed, the Lead Programmer decides between a second texture run and B3 before I-16 starts.
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
- **Tests.** As listed; plus (v1.1) the state `new` (Start and Show me give `running`, Skip and No thanks give `skipped`, nothing else changes it; a device that has answered before gets the inline card, not the modal), and **resume after a kill at every one of the 27 steps** (`migrate()` with `game.live` true and false: steps 7 to 20 resume at step 7 with `live` false and an empty `plan`, steps 21 to 23 at step 24, `game.n` unchanged, no duplicate game; section 5 item 10); plus `validate_tutorial.py` added to `tools/` (every step id in TUTORIAL 8 appears exactly once, every event name is in the legal list of TUTORIAL 7.5, every key exists), wired into `check_fast.sh` by L.
- **Acceptance.** The full step table loads; the state machine walks the happy path and the skip path with a scripted event list.
- **Rollback.** Delete `src/tutorial/` and the data file; nothing depends on it.
- **Effort (estimate).** 50 to 70 tool calls.

### I-12 CoachOverlay (spotlight hole)

- **Goal.** The visible half: dim, hole, ring, pointer and card.
- **Lane / Needs.** G2. Needs I-03 (hooks, layer slot), I-08 (BottomSheet), I-11.
- **Files.** C `src/tutorial/coach_overlay.gd` (`CoachOverlay`, on `CanvasLayer` 100: **four dim panels** around a hole rectangle (no shader), an info-step blocker over the hole, a pulsing ring, a pointer, a card with Next and Skip and an optional one-tap shortcut button; it follows `UI.find_tag(id)` each frame **only while the rectangle changes** and waits for layout to settle for 2 frames; scrolls the target into view (`ensure_control_visible` in nested scrolls); clips the hole to the screen for tall targets; a fallback card when the tag is missing; at most one animation at a time; animations off when `UI.animate` is false; handles Android back (Skip with Undo)), `src/tutorial/tutorial_runner.gd` (`TutorialRunner`: owns state, overlay and the `EventBus` subscription; the only object `Main` talks to); C `tests/check_tutorial_overlay.gd/.tscn`, `check_touch_tutorial.gd/.tscn`.
- **Integration lines for G1** (listed in the handback, a few lines in `main.gd` / `app.gd`): create the runner after the first screen, add `App.tutorial` accessor, add the debug line to `App.debug_info()`.
- **Strings.** none new.
- **Tests.** Hole follows a moving target; the four dim panels swallow taps while the hole passes a tap to the control under it (**B11 on the real `BottomSheet`; v1.2: re-run all 8 S2 rows of 9.5 on the real `CoachOverlay` and `BottomSheet`**, including the control row, the edge row (first pixel inside presses, 2 px outside is swallowed), the 8 px margin row, the info-step blocker, the hole moving to a second target, and a drag that starts in the hole and leaves it); a tap on the hole control fires its normal action and the event; info steps block the hole; large text at 626 px (card never covers the target where space allows, otherwise above or below); tall phone; the overlay survives `Main.show_screen` between steps; Skip then Undo; back key; no overlay node left after finish.
- **Screenshots.** One per step type (info, tap, sheet, shortcut, fallback), normal and large.
- **Acceptance.** B11 passes in the repo on the real components (S2 passed on the scratch pair with 8 of 8 rows, so a failure here would be a defect in the real components, not in the idea); if it fails, the card-only fallback ships and the failing steps are listed.
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
- **Files.** C `src/tutorial/offer_card.gd` (the inline Home card), `src/tutorial/settings_help_card.gd` ("Help and learning": Replay, Lessons, Glossary, Show help hints again); **integration lines for G1**: add the card at the top of Settings, the offer card on Home, remove the old "Show the welcome tips again" button (the new "Show help hints again" also clears the old `[tips]` flags until I-24, so the tips still on screen can be brought back); C `tests/check_tutorial_flow.gd/.tscn`. Until I-15 retires the Home tip, the old Home shows its welcome tip and the new offer card together; that state is seen by developers only, never at a checkpoint.
- **Strings.** merged copy (`tut.offer.*`, `settings.*`).
- **Tests.** Tests 5 to 9 and 13 of TUTORIAL 9 on the legacy path; **a brand-new save from `new_game()` (state `new`, section 5 item 3) on a fresh device (modal welcome) and on a returning device (inline card)**; `legacy` (one card once; includes fixture `save_0_6_d`, which must not show the modal), `running` (resume card), `done` and `skipped` (nothing); **kill and reload at steps 12, 18 and 21 through real save files (resume per section 5 item 10: step 7, step 7, step 24; `live` false; `game.n` unchanged; the resume card, never a modal)**; Replay from Settings confirm sheet; Reset also clears the save's tutorial state; first-run total time measured with a scripted tapper (counts steps and taps, not minutes).
- **Acceptance.** Every row of the TUTORIAL 6.2 table has a passing test.
- **Rollback.** Revert; integration lines are listed.
- **Effort (estimate).** 45 to 65 tool calls (was 40 to 60; the new-save and kill tests add about 5).

### I-15 Home

- **Goal.** First redesigned screen: club header with badge, one raised Next-match card, an upcoming-games row, a 2 x 2 tile grid. It proves the whole component stack and sets the pattern for the rest.
- **Lane / Needs.** G1. Needs I-06, I-07, I-08, I-10.
- **Files.** M `src/ui/screen_hub.gd` (rewrite on `_build()` and `_refresh()`); M `ui_smoke.gd`, `ui_touch.gd`, `ui_shots.gd` (the lines that touch Home, rule R4); C `tests/check_ui_home.gd/.tscn`, `tests/shots/shots_home.gd`.
- **Helpers.** `DepthCard`, `HeroStat`-style header, `Carousel` (upcoming(n) from I-06; its cards are display items and the card as a whole taps, I-08; first to cut if time is short, section 10), tile grid (`UI.tile` re-skinned), Badge from `BadgeStyle`. Tags: `home.next_card`, `home.play`, `home.offer` and the rest in TUTORIAL 8 for Home (the tab ids are already tagged in I-03). The inline offer card of I-14 sits **below** the Next-match card and the Play button, never above them; UI/UX Designer to confirm the position. Needs-attention note appears only from round 9 (finding in TUTORIAL 11; Lead Game Designer to confirm, section 12).
- **Strings.** `home.*` from the merged copy. **Old welcome tip retires here (v1.1):** the rewritten `_build()` does not carry `Tips.show(body, "hub")`, so the old welcome tip never shows together with the new offer card and the "Play without scrolling" acceptance below is measured without it. The tip's lines in `ui_smoke.gd` (156 to 173, TUTORIAL 9 test 18) are migrated to the new offer-card and "?" dot logic in this increment (rule R4); the `tip.hub*` strings stay in `en.json` until I-24 retires them. The Pre-match and Report tips are retired in I-21a and I-18.
- **Tests.** T-std all rows; Home stays under the node target (120) with the carousel; **Home shows no `Tips` card in any state**; the play button is the only coral action; tapping Play still starts the same game path as before (smoke walks a season).
- **Screenshots.** Home: first round, mid-season, season end, a 19-character club name, 5-digit cash; normal, large, cb, tall.
- **Acceptance.** Looks right on two passes; no scroll needed to see the Play button on 720 x 1280 in normal text (UI-PASS-2 space budget), **measured with the inline offer card showing (the worst case: a `legacy` or `new` save on a returning device)**; old smoke and touch green.
- **Rollback.** Revert `screen_hub.gd` and the three test hunks.
- **Effort (estimate).** 60 to 80 tool calls.

### I-16 Draft (optional engine-preview APK; CP2 moved to I-18)

- **Goal.** The biggest eyesore and the most-used screen: lane board, hero picture grid, role filter, bottom sheet to confirm, Coach bar with Take.
- **Lane / Needs.** G1. Needs I-09, I-15 (pattern), I-08.
- **Files.** M `src/ui/screen_draft.gd` (rewrite; keep `_on_hero`, `_apply`, `_sel_hero`, `_start_match`, `_ai_wait`, `_process` as thin wrappers, rule R4); M `ui_smoke.gd` and `ui_touch.gd` hunks; C `check_ui_draft.gd/.tscn`, `shots/shots_draft.gd`.
- **Helpers.** `LaneBoard`, `HeroGrid` (v1.2: one `Control`; the role filter is data plus one redraw, no `ListSync`, nothing is built or freed on a tap), `BottomSheet` (hero sheet with role fit percentage, best slot pre-chosen through `Draft.best_slot_for`), Coach bar (`Take`, `Auto-finish` then `Sure?` two-tap confirm), timer ring that redraws only when the second changes. Tags and events: `draft:sheet`, `draft:ban`, `draft:pick`, `draft:done` (TUTORIAL 7.5), all draft ids in TUTORIAL 8. Pre-existing opponent-bonus colour problem (green for them) fixed by side cue (UI-PASS-2 section 1).
- **Strings.** `draft.*`, `coach.*`. **Release `draft.meta_hint` here (v1.1):** delete it from `docs/design/copy/hold_0_7.json` and re-run `tools/merge_copy.py --write`, in the same commit as the arrows (an up arrow means strong), so the hint is never true before the arrows exist. The six-chip role filter needs the UI/UX answer on "Jungle" and "Support" (section 12.1, fallback: the short forms "Jg" and "Sup" of the old filter).
- **Tests.** T-std; **the draft screen shows the arrows exactly where the hint text says so** (a test reads `draft.meta_hint` and checks that the strong-hero cue is a drawn arrow, not colour only); **the 40-card grid stays within the I-09 gates (1 node, at most 15 draw calls) and the Draft screen stays at or under the draw-call target of 60, hard 100, at the top and bottom of the scroll**; a full draft played by tapping through the real controls (not by calling methods) ends in the same lineup as the same sequence through the old methods (equivalence on 20 seeds); AI turn timing unchanged; ban then pick through the sheet; Auto-finish confirm; `draft:*` events fire once each; in-place audit across 6 taps.
- **Screenshots.** Ban step, pick step, sheet open, role filter, done state, opponent's turn; four variants (24 images, 4 contact sheets, looked at twice).
- **Acceptance.** Gates green. **No longer CP2 (v1.1).** At this point the Producer *may* build an **engine-preview APK** for a phone test of scrolling, warmth and text on Home and Draft (PERF-BUDGET 4). It is not the first look at the guide: on it, **8 of the 27 tutorial steps are fallback cards** (list in section 10), so the Founder should tap Skip tutorial and judge speed and feel only. I run the fast loop here; the full check (background, about 25 minutes, estimate) moves to I-18.
- **Rollback.** Revert the screen and its test hunks.
- **Effort (estimate).** 90 to 130 tool calls (may be dispatched as two halves, R2).

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
- **Strings.** `report.*`; retire `report.why_h` once the new name is live. **Old Report tip retires here (v1.1):** the rewrite does not carry `Tips.show(body, "report")` (the three Report tutorial steps and the first-run result card replace it); `tip.report*` strings stay until I-24.
- **Tests.** T-std; **no `Tips` card on Report**; a win, a loss, a draw, a tutorial game, and a long game fixture; the score line equals `team_kills`; the Continue button is the one coral action; the story strip texts come only from the existing `Report.story` data (no new claims).
- **Screenshots.** Win, loss, tutorial win, factor sheet; four variants.
- **Acceptance.** As above. **CP2 (v1.1): the Home, Draft, Game Plan and Report loop is rebuilt, so the Producer builds the APK for the Founder's phone test here** (section 10 lists the 3 steps still shown as cards: 5, 6 and 26). `tags_*` tests for Home, Draft, Game Plan, Report, the tab bar and the I-21a screens all pass, and a scripted walk of the guided first game from the welcome card to the Standings card ends with `fallbacks` equal to exactly 3 (the three expected steps) and no other. I run the full check here, once, in the background (about 25 minutes, estimate).
- **Rollback.** Revert.
- **Effort (estimate).** 70 to 100 tool calls.

### I-19 Squad

- **Goal.** Your five starters on a small lane map, bench as avatar cards, a free-agent row, the lane picker and the player card sheets.
- **Lane / Needs.** G1. Needs I-09, I-08, I-05.
- **Files.** M `src/ui/screen_roster.gd` (rewrite; keep `_toggle_slot`, `_assign`, `_toggle_player`, `_auto`); M `player_view.gd` (becomes the player-card sheet content); M test hunks; C `check_ui_squad.gd/.tscn`, `shots/shots_squad.gd`.
- **Helpers.** `PlayerCard`, token anchors from the Squad anchors table in ART-BIBLE (Top 0.110/0.540, Jungle 0.270/0.700, Mid 0.500/0.720, Support 0.840/0.742, Bot 0.889/0.540), `BottomSheet`, `Carousel` (market row; the card as a whole taps; cut with the Home one if time is short), tap-to-swap (drag-to-swap is on the cut list, UI-PASS-2 8.1). Events `open:player_card`, `open:lane_picker`. Opened also from Match day with the tab bar hidden.
- **Strings.** `squad.*`. Needs two UI/UX answers (section 12.1): the real Player card tab labels ("Stats", "Career") and the interim Squad anchors.
- **Tests.** T-std; assigning, swapping and auto-fill leave the same lineup as the old methods (equivalence on 20 random rosters); the **team rating preview in the picker equals the rating after the swap**; the Match day entry still works; large text with all 5 anchors reachable.
- **Screenshots.** Closed, picker open, player card sheet, bench with 9 players, an empty lane; four variants.
- **Acceptance.** As above. Note: final token positions depend on the 0.8 arena map; the anchors table is the interim. **Tutorial steps 5 and 6 become real here** (`tags_squad`; fallbacks at the scripted walk fall from 3 to 1).
- **Rollback.** Revert.
- **Effort (estimate).** 100 to 140 tool calls (may be dispatched as two halves, R2).

### I-20 Standings and History

- **Goal.** A podium for the top three, your row highlighted and pinned, the Points or Form Rating switch, a playoff bracket, history strips.
- **Lane / Needs.** G1. Needs I-10, I-06 (`cut_gap`).
- **Files.** M `src/ui/screen_standings.gd` (keep `_set_tab`); M test hunks; C `check_ui_standings.gd/.tscn`, `shots/shots_standings.gd`.
- **Helpers.** `Podium`, `RankRow` (tnum), `Segmented` (Points | Form Rating), `PhaseStrip` as tabs; event `stand:metric`; the pinned sentence from `cut_gap()`.
- **Strings.** `standings.*`. Needs the UI/UX answer on whether "Form Rating" fits the Points / Form Rating switch at large text (section 12.1, fallback label "Rating"). **Tutorial step 26 becomes real here** (`stand.metric`; with this increment the walk has `fallbacks` 0).
- **Tests.** T-std; the table order equals `gs.standings()` for 20 saved seasons; own row marked by a shape cue (marked YOU), not colour; 19-character club names; no tab label breaks mid-word.
- **Screenshots.** Table, form view, bracket, history; four variants.
- **Acceptance.** As above.
- **Rollback.** Revert.
- **Effort (estimate).** 70 to 100 tool calls.

### I-21a Tag-only work on the screens that stay as they are (G1; run directly before I-15)

- **Goal (v1.1, new).** Give the tutorial real targets on the screens that are not redesigned, **before** the Founder's first look at the guide. These tags and events stay valid when I-21b restyles the screens later, so none of this work is thrown away.
- **Lane / Needs.** G1. Needs I-03 (tags, bus) and I-14 (the engine, so the tags can be tested against it). Runs right after I-14, before I-15. Small: a few lines per screen, no layout change.
- **Files.** M `screen_plan.gd` (tag the three Plan tiles `plan.tile.practice`, `plan.tile.training`, `plan.tile.chem`); M `screen_practice.gd` (`practice.quick`); M `screen_prematch.gd` (`prematch.matchups`, `prematch.start_draft`; **remove `Tips.show(body, "prematch")`**, the old Pre-match tip, so it never sits under a tutorial step); M `screen_club.gd` (the existing Form Rating tile, which already opens `ScreenStandings.new("form")`: `club.tile.form`, `club.tile.finance`, `club.tile.fa`); M `screen_match.gd` (**v1.0 gave these to no increment**: `match.controls` over Speed and Skip together, `match.report_btn`, and the events `match:speed`, `match:skip`, `match:end` of TUTORIAL 7.5; the match itself is not touched, only observed); C `tests/check_tags_legacy.gd/.tscn`. Each tag is applied again after any `_rebuild()` (TUTORIAL 8).
- **Strings.** none (the Pre-match tip strings `tip.prematch*` stay in `en.json` until I-24).
- **Tests.** `tags_plan`, `tags_practice`, `tags_prematch`, `tags_club`, `tags_match`: each id exists and is visible in the state the step needs; the Pre-match screen shows no `Tips` card; `tap:` and `match:*` events fire; **a match played with the tags present gives the same result as without them** (R6, same seed); old smoke and touch green.
- **Screenshots.** none needed (no layout change); one contact sheet of the five screens to prove nothing moved.
- **Acceptance.** Tutorial steps 8, 9, 10, 11, 19, 20 and 25 find their targets on the old screens.
- **Rollback.** Revert; the hunks are a few lines per screen.
- **Effort (estimate).** 15 to 25 tool calls.

### I-21b Plan and Club tabs and Match day adopt the new components (parallel S)

- **Goal.** Tabs that are not in the six screens stop looking old next to them.
- **Lane / Needs.** G1. Needs I-15 to I-20 and I-21a.
- **Files.** M `screen_plan.gd`, `screen_club.gd`, `screen_prematch.gd` (restyle only; the I-21a tags move with their controls); tests as usual.
- **Tests.** T-std (build, fit, touch); the I-21a tag tests still pass (`Practice matches` and `Play a Quick Match` ids exist: tutorial steps 8 and 9).
- **Acceptance.** Looks consistent; Tutorial ids found.
- **Rollback.** Revert.
- **Effort (estimate).** 20 to 35 tool calls (I-21a and I-21b together: 35 to 60, against 30 to 50 for the old I-21).

### I-22 Help sheets, "?" button and glossary

- **Goal.** A help sheet on every one of the 20 screens, a glossary of 49 terms.
- **Lane / Needs.** G2 (new files) plus G1 integration. Needs I-14, I-16 (so the draft pause hook is real), the screens.
- **Files.** C `src/tutorial/help_sheet.gd` (reads `data/help_v1.json`), `src/tutorial/screen_glossary.gd`, `data/help_v1.json` (20 screens, "see, do, know" lines), `data/glossary_v1.json` (49 terms); **integration lines for G1**: the "?" button in the `Screen` header slot (I-03), the dot memory, pause hooks for Draft timer and Match, replace `Tips.show` calls.
- **Strings.** from the merged patch (`help.*`, `gl.*`; 60 help lines and 49 definitions).
- **Tests.** Tests 11, 12, 14, 16 of TUTORIAL 9; every screen's `help_id()` has an entry; opening a sheet pauses the draft timer; the dot clears after opening; every glossary key exists; no help text is over its word limit (`tools/check_copy.py`).
- **Screenshots.** One help sheet, the glossary list and one term; four variants.
- **Acceptance.** Every screen has a working "?". **Perf re-baseline no. 2 of 2 (section 6):** the "?" button and hooks add nodes to every legacy screen, so every remaining legacy row is reset to its measured value in one commit reviewed by the Technical Director, old and new side by side.
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
- **Files.** **the three `Tips.show` calls are already gone** (hub in I-15, report in I-18, prematch in I-21a): this increment proves no call remains and removes what is dead (`tip.hub*`, `tip.prematch*`, `tip.report*` in `en.json`, and the `tip_seen`/`tip_mark` paths nothing calls; the Payoff `tip.*` keys stay); M `screen_about.gd` (Barlow credit and a Licences entry reading the licence text); **release `about.included.b` and `about.test.b` here (v1.1):** help sheets (I-22), lessons and glossary (I-23) now exist, so delete both from `docs/design/copy/hold_0_7.json` and run `tools/merge_copy.py --write`; rename check: wire `tools/check_copy.py` (it scans string values only, never the `.terms` id lists, so lower-case "coach" in glossary id lists is not a hit; seen in the working tree, not run by me) into `check_fast.sh` by L. **There is no separate `check_rename.py`** (v1.1): `check_copy.py` check 4 already covers "advisor", "assistant", "owner", a lower-case "the coach" and "AI helper" (per its header; I have not run it).
- **Tests.** Rename check clean; no `Tips.show(` call with `hub`, `prematch` or `report` remains (grep as a test); the About screen shows the new included and tester text (not the older text that describes chemistry as the new feature); the licence text is shown from a data file that is in the APK.
- **Acceptance.** `check_strings.py` has no unused-key warnings for the retired families.
- **Rollback.** Revert.
- **Effort (estimate).** 25 to 40 tool calls.

### I-25 Acceptance (CP3)

- **Goal.** The proof that everything works together, then the handback for review.
- **Lane / Needs.** Q runs the audits, G1 fixes, L runs the full check. Needs all.
- **Work.** (1) The full UI-PASS-2 7.1 matrix: 6 screens, all states, 4 variants (72 images or more), each looked at twice. (2) The audits of 7.1 on every screen: fit, hit area, colour-blind cue, in-place. (3) All 20 tutorial tests (TUTORIAL 9) including the end-to-end walk of the 27 steps on the new screens, counted in steps and taps. (4) Perf gates under Xvfb for all 6 screens plus the sheets. (5) The idle-redraw check and the low-processor decision with Engine/Graphics. (6) Save-compat fixtures. (7) `bash tools/run_all_checks.sh $GODOT` in the background (about 25 minutes, estimate). (8) A debug APK export, size compared with the 24.7 MB of `PERF-BUDGET.md` 8. (9) Version label 0.7.0 alpha (`App.VERSION_LABEL`, G1), export preset version (L), **and release `about.title` ("About Alpha 0.7") from the hold file in the same commit as the version label (v1.1); the hold file must then be empty, and the merge script's dry run reports 0 held keys**, `docs/ALPHA-0.7-NOTES.md` (Producer). (10) The OFL licence file is still in the APK listing. **Screenshots (v1.1):** 72 images looked at twice is 12 contact sheets of 6, looked at twice, which is what fits 60 to 90 calls; looked at one by one, two passes would be 144 views and the increment would not fit.
- **Acceptance.** Full check exit 0; no `ERROR:` in logs; every gate in section 6 green or a named exception signed by the Technical Director.
- **Rollback.** Not applicable; this step only fixes.
- **Effort (estimate).** 60 to 90 tool calls.

---

## 8. Estimate summary (all estimates)

| Block | Increments | Tool calls (estimate) |
|---|---|---|
| Safety net, follow-ups, spikes | I-00, I-00b, I-00c, I-01 | 80 to 135 |
| Look foundations | I-02 to I-04 | 135 to 195 |
| Art code (E) | I-05 | 60 to 90 |
| Core hooks (G2) | I-06 | 30 to 45 |
| Components | I-07 to I-10 | 230 to 320 |
| Tutorial engine (G2) | I-11 to I-14 | 215 to 305 |
| Six screens and tabs | I-15 to I-21b (I-21 is now I-21a and I-21b) | 505 to 720 |
| Help, lessons, cleanup, acceptance | I-22 to I-25 | 215 to 320 |
| **Base total (builder's own testing and redo of its own mistakes only)** | 26 increments plus I-00b and I-00c, 29 dispatches | **1,470 to 2,130** |
| Rework and review allowance, 20 to 30 percent | | +295 to +640 |
| **Total with allowance** | | **about 1,760 to 2,770** |

The v1.0 table said 1,400 to 2,050 (its blocks actually added up to 1,425 to 2,055). Two things changed: the tutorial block was added up wrongly (I-11 to I-14 sum to 210 to 300, not 210 to 290; v1.1 has 215 to 305 after the new-save and kill tests), and five increments were re-costed for the v1.1 changes (I-00 +5 high, I-03 +5, I-06 +5, I-14 +5, I-21 split from 30 to 50 into 35 to 60) and the new I-00b adds 15 to 25. I re-added every block from the "Effort" line of each increment in section 7 (the sums above are those sums, checked by script, not typed). **v1.2:** the new I-00c adds 10 to 20, so the base moves from 1,460 to 2,110 to 1,470 to 2,130 and the allowance to +294 to +639 (shown rounded to 295 and 640), total 1,764 to 2,769, checked by script again; I-00b is kept at its original 15 to 25 although half of it moved to I-00c, so these two lines are slightly double counted, on the safe side. The day figures below do not move at their rounding (about 24 to 38 for one builder).

**Why the allowance.** The base figures assume each increment is right the first time. The ledger says otherwise: 5 of the 13 earlier dispatches needed a second round. The allowance of 20 to 30 percent (a judgement, not a measurement; the Studio Manager proposed the same range) covers one rework round and one review round per increment (my review of the handback, then the fixes). It does **not** cover the Studio Manager's and the Producer's own review time, or waiting for the UI/UX answers in 12.1; those are outside this plan.

**Days: a guess.** The design documents' own estimates are 38 developer days for the layouts and 19 for the tutorial (about 57), both flagged by their authors as low confidence. Nothing converts tool calls to days: no pace has been measured. v1.0's "20 to 28 days" works out to about 72 calls a day, which is itself an assumption. With that same division the allowance total is **about 24 to 38 working days for one builder, and about 17 to 26 with two lanes**. The plan's figure and the designers' 57 days differ by a factor of 1.5 to 2.4 and **cannot both be right**; I would not promise the Founder a date from either. The only safeguard is to replace the guess with the real pace: **re-estimate after I-07** (first real component increment), **after I-15** (first screen) and **after I-18** (CP2, the first complete loop); the Producer should expect the plan to move at those three points.

**Where the Founder's checkpoints fall in this estimate (base calls, before the allowance).** CP1 after I-04: 215 to 330. Old CP2 (after I-16, as in v1.0): 900 to 1,300 (about 61 percent). **New CP2 (after I-18 and I-21a): 1,065 to 1,535 (about 72 percent)**. That is 165 to 235 calls later, about 3 to 4 working days at the same guessed pace with the allowance. CP3: the end.

**Screenshot counts that only fit if batched.** Two figures in the plan are only plausible with contact sheets of 6 images (R1(d)): **I-04, 196 images inside 40 to 60 calls**, and **I-25, 72 images each looked at twice inside 60 to 90 calls**. Unbatched, I-04 would need about 400 views and I-25 144. The per-screen counts of I-15 to I-20 (24 images or so per screen) fit in about 4 sheets, looked at twice, without a problem. If batching turns out to hide problems (a sheet at half size cannot show a one-pixel clip), the fit audit is the safety net and the figure for I-04 goes up, not the quality of the look.

## 9. Risks and spikes

### 9.1 Table

| # | Risk | Evidence so far | Handled by |
|---|---|---|---|
| K1 | **Sheet-through-hole tap (TUTORIAL B11):** a tap in the overlay hole must reach a button inside a sheet on a lower layer | Scratch probe and the I-01 S2 check **passed** (8 of 8 rows, 9.5) on desktop on a scratch layer pair; **not run on a phone, not run with the real `BottomSheet`** | I-01 S2 (done), re-run in I-08 and I-12 on the real sheet and overlay. Fallback: card-only steps |
| K2 | **Nested carousel steals diagonal swipes** | Scratch probe: **failed**; I-01 S1 reproduced it (a plain `ScrollContainer` carousel fails 4 of 10 swipe rows) and **passed 10 of 10 with the direction lock and non-interactive cards owned by the Carousel** (9.5). Not tried on a real finger | I-08 builds the lock and re-runs the 10 rows on the real component; the plain row stays as phone-test insurance and cut-list item 1 |
| K3 | **Barlow in Godot.** Weights, `tnum`, fallback, size | Files and `default_font.tres` already in the repo; desktop: `tnum` works, widths match the art bible; APK +0.3 MB; weights not wired; the OFL text **is** in the APK (preset fixed in `d78038d`, verified by listing the APK) | I-02 wires weights; I-02 and I-25 keep the APK-listing check. **Android `tnum` unverified** (the text server in the Android template is TextServerAdvanced, so expected to work); phone-test item |
| K4 | **Texture and draw-call budget** | Counts exact on this renderer: `StyleBoxFlat` card is one call with or without shadow; **S3 measured: a baked 9-slice costs the same as `StyleBoxFlat` once text or icons sit on the cards (17 against 17, 25 against 25 for 8 cards)**, and wins only with a separate background layer (9.5); a `CPUParticles2D` is one call. Real batching on Android is not proven. Fill-rate cost is not measurable here | I-01 S3 (done: keep `StyleBoxFlat` and the shared `UI.box()` cache), gates in section 6, `perf_baseline` in every screen step; phone test |
| K5 | **Node cliff in the hero grid** (40 cards) | **Measured (S4, 9.5):** 40 `PanelContainer`s = 281 nodes; one `Control` per card = 41 nodes but **107 draw calls** (hard limit 100 for the whole screen); one atlas and one font size (B3) = 65 calls; one `HeroGrid` `Control` = **1 node and 7 calls** | I-09 `HeroGrid` (design C, accepted). Alternative B3 with one waiver. Virtualising does not help (it does not touch the failing number) |
| K6 | **Rebuild-on-tap makes overlay and sheets unstable** | 16 to 22 ms per tap measured | Section 2.1 rule; in-place audit in every screen step |
| K7 | **Token change ripples** into the 14 unredesigned screens (UI-PASS-2 R4) | Font change alone already changed every screenshot | I-02 plus I-04 land it once with a full re-shoot; CP1 |
| K8 | **String merge breaks tests** (12 keys replaced now, 4 held; 3 rename edits) | The Studio Manager grepped `game/tests`, `game/src` and `tools` for all 16 replaced keys and their old texts and found no test that depends on one; `ui_smoke` and `ui_touch` have **not** been re-run after the merge (no Godot on the review machine) | I-00 does the merge first, in its own commit, and runs both |
| K9 | **SVG rasterisation on Android** (ThorVG in the Android template) | Fast on desktop at start-up; Android untested | I-05 draws everything in code where possible; SVG only for the five role icons; Engine/Graphics to confirm ThorVG in the Android export; phone-test item |
| K10 | **Hot-file collisions between two agents** | Real: `ui.gd`, `main.gd`, `screen.gd`, `app.gd`, `en.json`, `game_state.gd`, big test files | Section 4 ownership table, auto-discovered tests, integration lines |
| K11 | **Text widths on a phone** drift by a pixel or two at scaled sizes (the "Gravenstone" room is a few pixels) | Exact on desktop only | Margin audit in `fit_*`; phone test; hero names stay at Small 26 |
| K12 | **Time of the first game** (4 to 6 minutes for 27 steps is unmeasured) | TUTORIAL 11 | I-14 counts taps and steps; the CP2 phone test measures minutes (with 3 fallback steps, so slightly off); cut steps 3 and 10 first |
| K13 | **Scope.** About 1,470 to 2,130 base tool calls, 1,760 to 2,770 with the rework allowance (estimate); the day figures are a guess | 5 of 13 earlier dispatches needed a second round | Cut list (section 10), checkpoints, re-estimate after I-07, I-15 and I-18; a second Gameplay Programmer instance on G2 from I-06 |
| K14 | **The Founder's first look at the tutorial shows cards instead of highlights** (v1.1) | In v1.0, CP2 after I-16 would have shown 15 of 27 steps as "cannot find" cards (the review counted 13; two more are the Match screen steps, which no increment tagged) | CP2 moved to I-18, tag-only I-21a pulled forward; 3 cards left at CP2 (steps 5, 6, 26), listed in section 10; the Producer tells the Founder |
| K15 | **A new save or a killed app gets the wrong tutorial state** (v1.1) | Review X8: the plan had no state for a brand-new save and nothing for a kill mid-game | Section 5 items 3 and 10; fixture `save_0_6_d`; tests in I-06, I-11, I-14 |

### 9.2 What would make me stop and replan

- (v1.2: S1 and S2 passed on the computer, so this is now a phone-test trigger.) The carousel lock or the hole tap fails on a real finger or on the real components (no reliable carousel, no hole-tap): drop the carousel to a plain row, make the tutorial card-only, and the tutorial cost falls; the layouts do not change otherwise.
- (v1.2, replaces "virtualise the grid", which S4 showed would not help.) `HeroGrid` on real silhouettes needs more than about 15 draw calls (7 measured with placeholder discs), or the Draft screen as a whole cannot sit under 100: switch the grid to B3 (one font size) with the one waiver line of section 6, and ask the UI/UX Designer about the tag size. The measured reference: 40 `PanelContainer`s 281 nodes; one `Control` per card 107 calls; B3 65 calls; `HeroGrid` 7 calls.
- The `Strings` merge in I-00 breaks more than about 10 tests: pause and fix before anything else.

### 9.3 Spikes already run (scratch, not in the repo)

Files under the session scratchpad (`probe07/`): node counts, rebuild timings, font widths, B11, nested scroll, SVG. They are probes, not deliverables; I-01 re-created the ones that matter inside `game/tests/` (`check_gestures`, `game/tests/spikes/`), so the result is repeatable by anyone. The I-01 results are in 9.5.

### 9.4 Phone-test list (open until a phone has run a match)

Scrolling stutter on Home and Draft; whether the phone warms over one full match with the draft; text that looks wrong or boxy; `tnum` columns on Android; SVG icons on Android; the hole tap through a sheet on a real touchscreen; the carousel direction lock on a real finger; overlay timing; shadow and glow cost on a low-end GPU; real draw calls and frame time (needs a debug overlay, `PERF-BUDGET.md` 9 item 3, small piece of work; propose it as part of I-02 if the Technical Director agrees).

### 9.5 I-01 spike results (measured 2026-11-10, copied from `SPIKE-RESULTS-0.7.md`)

Taken by the Gameplay Programmer on the build computer, Godot 4.3 stable, desktop. Touch is simulated (finger events pushed into the viewport with `emulate_touch_from_mouse` on, as `ui_touch.gd` does). Draw calls, node counts and texture memory come from Xvfb with `--rendering-driver opengl3` (software): **counts carry to a phone, milliseconds do not. Nothing here ran on a phone.** I copied the tables below; I did not re-run the spikes. How to run them is in the results document.

| Spike | Result | Decision |
|---|---|---|
| S1 nested scroll | **Pass with the direction lock**, 10 of 10 swipe rows, taps right; plain `ScrollContainer` carousel fails 4 of 10 | Carousel with lock and owned taps (I-08); plain row not needed on this evidence |
| S2 hole tap | **Pass**, 8 of 8 rows incl. a leak control, on a scratch `CanvasLayer` pair (sheet 20, overlay 100) | Keep four dim panels plus blocker, no shader; re-run on the real components in I-08 and I-12 |
| S3 surface | `StyleBoxFlat` = baked 9-slice in draw calls once text or icons are on the cards; a shadow adds 0 calls | Keep `StyleBoxFlat` and the shared `UI.box()` cache |
| S4 hero grid | One `Control` per card passes nodes (41) and **fails draw calls (107)**; one `HeroGrid` = 7 calls, 1 node | `HeroGrid`, design C (I-09); B3 with a waiver is the alternative |

**S1: swipes that start on the carousel** (200 px tall, 8 cards, in a vertical page scrolled to 360; ten swipes of 240 px in 12 moves from the middle of the carousel; px moved, page scroll includes its own fling after release). Pass rule: under 45 degrees the page moves at least half the swipe's vertical travel and the carousel at most 2 px; 45 and over, the carousel moves at least half the horizontal travel and the page at most 3 px.

| Angle from vertical, direction | Plain `ScrollContainer` carousel (Button cards) | Lock, Button cards | **Lock, cards owned by the Carousel (chosen)** |
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

Taps on the owned-cards lock: a tap on card 1 gives card 1; a tap with 6 px of finger jitter still gives card 1; a horizontal swipe and a vertical swipe that start on a card tap nothing. **The rule it forces:** with Button cards, or any child whose mouse filter is not IGNORE, the engine keeps routing later drag events to that child and the lock fails at 60 and 90 degrees (third column of the table above, middle). The lock must swallow both the drag and the emulated mouse motion when horizontal. **Not tested:** a real finger, a touch-only stream (in this engine setup it did not scroll a plain `ScrollContainer` at all, so the simulation sends touch and mouse together), large text, a swipe that starts in the gap between cards, multi-touch.

**S2: hole tap** (a page button on layer 0; a sheet on layer 20 with a counting scrim and two buttons; an overlay on layer 100 of four dim `ColorRect`s around a hole, no shader, and an info-step blocker). These are the 8 rows I-08 and I-12 re-run on the real components:

| Row | Result |
|---|---|
| Control: with the dim panels hidden, the same taps reach the scrim and the sheet panel (the leak is detectable) | OK |
| Tap in the middle of the hole presses the sheet button; nothing else reacts | OK |
| Taps on the four dim panels, over the scrim and over the page button are swallowed | OK |
| Edge: first pixel inside the hole presses, 2 px outside is swallowed | OK |
| Tap in the 8 px margin of the hole (outside the button) reaches the sheet panel, not the scrim | OK |
| Info step: the blocker over the hole swallows the tap | OK |
| The hole moves to a second target: it presses and the old target is blocked | OK |
| A drag that starts in the hole and leaves it does not press the button | OK |

Not tested: the real `BottomSheet` and `CoachOverlay`, a real touchscreen, a drag that starts in the hole and scrolls a `ScrollContainer` inside the sheet (TUTORIAL step 17 style), Android back during a sheet step, large text.

**S3: draw calls of a Draft-like screen** (page background, title, 8 cards of 120 px in a `VBoxContainer`, 720 x 1280, software OpenGL; two runs gave identical counts).

| Background | Content none | One label | Icon and two labels |
|---|---|---|---|
| empty page (reference) | 1 | | |
| `flat` | 10 | 17 | 25 |
| `flat+shadow` | 10 | 17 | 25 |
| `baked9` (card holds its content) | 3 | 17 | 25 |
| `baked9 layered` (backgrounds behind) | 3 | 3 | 19 |

Nodes for the same rows: 12, 28, 44 for the first three kinds; the layered kind 21, 37, 53 (a second container, +9 nodes per 8 cards, every layout change done twice). Texture memory 6.69 MB for the empty page and 6.83 MB with any card kind. Reading: a shadow adds fill area, not calls; a baked 9-slice batches to one call only while nothing else is drawn between the cards; each texture switch (glyph atlas, icon, untextured shape) is one more call. The baked tile used has no shadow halo, so baked elevation was not compared. Not measured: fill rate and overdraw (the real shadow cost on a low-end GPU), milliseconds, real Android batching.

**S4: 40-hero grid** (the 40 heroes of `data/heroes.json`, 3 columns of 183 px cards inside a vertical page, about 19 cards on screen; "setters plus layout" is one role filter plus 8 state changes, headless; the headless frame itself is paced at about 6.9 ms; milliseconds are this computer's).

| Design | Nodes in the grid | Setters plus layout, headless | Draw calls on screen, top / bottom |
|---|---|---|---|
| **A** 40 `PanelContainer`s, each `VBoxContainer` plus portrait, name, tag, mark, role chip | **281** (7 per card) | 0.35 ms | 98 / 88 |
| **B** one Control per card, draws itself (style box, disc, lines, text at 3 sizes) | 41 | 0.11 ms | **107 / 97** |
| **B2** as B, every shape from one atlas texture | 41 | 0.13 ms | **107 / 97** |
| **B3** as B2, name and tag at one font size, no initial letter | 41 | 0.15 ms | **65 / 59** |
| **C** one HeroGrid Control draws all 40 in three passes, text grouped by font size, owns hit-testing | **1** | 0.06 ms | **7 / 7** |

Reading: nodes at most 60 passes for B, B2, B3 and C and fails for A. **The draw-call gate is the real finding:** B and B2 emit 5 to 6 calls per visible card (text at three sizes means three glyph textures, then untextured shapes), over the screen's hard limit of 100 before any header or tab bar; B2's atlas changes nothing because text dominates; B3 halves it. C orders its draws (all backgrounds, all discs and marks, then text by font size) for 7 calls. Virtualising would not help, because the 107 calls are already for the visible cards only. Hit-testing for C and B3 needs the S1 tap rule (a release more than 12 px from the press is a drag). **Not measured:** real portraits (placeholder discs here; a silhouette atlas may add a second texture and a call), colour-blind marks beyond a text cue and a shape, millisecond cost of drawing 40 cards on a phone's CPU (C redraws all 40 when one changes), large-text names such as "Gravenstone" at 26 px, tall phone, a phone.

---

## 10. Cut list, checkpoints and what waits

**Cut order if time is short** (taken from UI-PASS-2 8.1 and my own risk list; each cut leaves a working app):

1. Home and Squad carousels become plain rows with "See all" (v1.2: S1 passed in I-01, so this is now only for time, or if the phone test shows the direction lock failing on a real finger).
2. Drag-to-swap on Squad (tap-to-swap stays).
3. History mini story strips on Standings.
4. Report "starter chips" sheet.
5. Lessons beyond the first three (I-23).
6. Plan and Club tab restyle (I-21b) and overflow-only treatment kept from I-04.

Never cut: tokens and weights (I-02), the in-place rule on redesigned screens, the tutorial's sandbox proof (I-13), save compatibility (section 5), the colour-blind cues, and the tags of I-21a (cutting I-21b keeps them).

**Checkpoints (v1.1)**

| CP | After | What exists | For whom |
|---|---|---|---|
| CP1 | I-04 | Same game, new type, colours, font, 96 px targets, frame layers. No guide yet (the tutorial engine arrives in I-11 to I-14) | Founder can look at screenshots; no phone test needed |
| Engine preview (optional) | I-16 | Home and Draft redesigned, tutorial engine and first game playable, **8 of 27 steps are cards** (below). APK built by the Producer, no full check | A phone test of scrolling, warmth and text only (PERF-BUDGET 4). Founder taps Skip tutorial |
| **CP2** | **I-18** (moved from I-16) | Home, Draft, Game Plan and Report redesigned: the whole match-day loop is new. Guided first game playable from the welcome card to the Standings card with **3 of 27 steps shown as cards**. APK, one full check | **Founder phone test**: the first real look at the guide |
| CP3 | I-25 | All six screens, help everywhere, lessons, 0.7.0 APK, all 27 steps real | Founder, then testers |

### 10.1 CP2 re-plan (review fix 2): the choice, the cost, the recommendation

**The problem.** The guide has 27 steps (TUTORIAL 3.2: 2 modal, 5 info, 20 do-steps; 4 to 6 minutes by estimate). A step is real only when its screen carries the tag it points at. In v1.0 the first phone build came after I-16 (Home and Draft). By then only the tab bar (I-03), Home (I-15) and Draft (I-16) were tagged, so **15 of 27 steps would have shown the "We cannot find that on this screen" card**. The Studio Manager counted about 13; I count 15 because no increment tagged the Match screen (steps 19 and 20). The Founder's loudest complaint was the tutorial, and this would have been his first look at it.

**Which step becomes real where** (this is the whole table; it adds up to 27):

| Made real by | Steps |
|---|---|
| I-03 tab bar tags, and the I-14 modal cards | 1 (welcome), 3 (tabs), 4 (Squad tab), 7 (Plan tab), 24 (Club tab), 27 (finish) |
| I-15 Home | 2 (next match card) |
| I-16 Draft | 12 (ban), 13 (pick), 14 (role), 15 (Auto-finish), 16 (open Game Plan) |
| I-17 Game Plan | 17 (Coach), 18 (Start the match) |
| I-18 Report | 21 (result), 22 (why), 23 (Continue) |
| I-19 Squad | 5 (bench player), 6 (player card) |
| I-20 Standings | 26 (Points / Form switch) |
| **I-21a tag-only (new)** | 8 (Practice tile), 9 (Quick Match), 10 (matchups), 11 (Start draft), 19 (watch), 20 (See the report), 25 (Form tile) |

**Option A, tag the old screens early.** Put tags and events on the old Squad, Game Plan, Report and Standings inside I-11 to I-14, plus the Plan, Practice, Pre-match, Club and Match tags. Cost: the Plan, Practice, Pre-match, Club and Match tags are permanent (about 15 to 25 calls, needed under any option). The tags on the old Game Plan, Report and Squad are **thrown away** when I-17, I-18 and I-19 rewrite those screens, about 25 to 40 calls, plus the same tests again later (estimate). And it does not finish the job: steps 6, 17 stage B and 22 stage B point into a **sheet** (the old screens have none; sheets come with the rewrites), step 26 points at a switch that does not exist yet, and step 5's text says "the map" about a screen that has none. About 5 of 27 steps would still be cards or would say something untrue. CP2 would stay at about 890 to 1,280 base calls (after I-16).

**Option B, move CP2 later.** CP2 after I-18, with the permanent tag-only part of A pulled forward as I-21a (right after I-14, before I-15). Nothing is thrown away. Extra cost: **0 calls** (the same I-21 work, moved earlier). Price: the first Founder look comes **165 to 235 base calls later** (I-17, I-18 and I-21a), about 3 to 4 working days at the guessed pace with the allowance. Cards left at CP2: **3 of 27** (steps 5, 6 and 26), and the steps that are real are really real (sheet steps 12 to 15, 17 and 22 included). New CP2 sits at 1,055 to 1,515 base calls, about 72 percent of the plan.

**Recommendation: Option B with I-21a**, plus the optional engine-preview APK after I-16. In numbers: A pays 25 to 40 throwaway calls and still leaves about 5 cards; B pays nothing and leaves 3. The only real loss of B is that the first phone check of scrolling and heat comes 3 to 4 days later, and the engine-preview APK gives that check back at the earlier date at no build cost beyond an export (the Founder is told to tap Skip tutorial on it). Because the tutorial is the Founder's loudest complaint, I would rather he first meets it at 24 of 27.

**Exactly which steps are cards, by checkpoint** (for the Producer to tell the Founder):

| Build | Cards (steps) | Count | Real |
|---|---|---|---|
| v1.0 plan, CP2 after I-16 (dropped) | 5, 6, 8, 9, 10, 11, 17, 18, 19, 20, 21, 22, 23, 25, 26 | 15 | 12 |
| Engine preview after I-16 (with I-21a) | 5, 6, 17, 18, 21, 22, 23, 26 | 8 | 19 |
| **CP2 after I-18** | **5, 6, 26** | **3** | **24** |
| After I-19 | 26 | 1 | 26 |
| CP3 after I-20 and later | none | 0 | 27 |

In plain words for the Founder at CP2: "The guided first game works from the welcome card to the league table. Two small bits in the Squad part (tap a bench player, and the player card) and the last switch on the standings show a plain text card with a Next button instead of a glowing highlight, because those two screens are rebuilt after this build. Tap Next on them." On the engine preview: "Tap Skip tutorial. This one is for how fast it scrolls and how warm the phone gets."

**What the build must guarantee at CP2** (tested in I-18): the cards are exactly steps 5, 6 and 26 and no other (the scripted walk counts `fallbacks` and fails on any other number); every card's Next works; Skip works at every step; the old Squad and Standings still do everything they did.

**What waits for Alpha 0.8 (the arena), and why**

- The **Match HUD** (UI-PASS-2 6.7): scoreboard strip, text strip with the scheduler, controls, end card. Depends on the arena scene, the short feed form and `Report.story`.
- `tut.watch.arena` (tutorial step 19 text) and the match step events in arena form; 0.7 keeps `screen_match.gd` as it is and tags its Speed, Skip and See-the-report buttons (I-21a).
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
| Components | `DepthCard`, `SectionHeader`, `Chip`, `Segmented`, `IconButton`, `EmptyState`, `EdgeMeter`, `HeroStat`, `ListSync`, `BottomSheet`, `Carousel`, `PlayerCard`, `HeroGrid`, `HeroCard` (static drawing helper), `LaneRow`, `LaneBoard`, `PhaseStrip`, `DetentTrack`, `Podium`, `RankRow` | `src/ui/components/` |
| Art code | `TexCache`, `Icons`, `BadgeStyle`, `Silhouette`, `Avatar`, `Surface` | `src/ui/art/` |
| Game hooks | `GameState.upcoming`, `cut_gap`, `tutorial`, `set_tutorial`; `Report.team_kills`; `Draft.best_slot_for` | `game_state.gd`, `sim/report.gd`, `sim/draft.gd` |

---

## 12. Decisions needed (none for the Founder)

| # | For | Decision | My recommendation |
|---|---|---|---|
| D1 | Technical Director | Adopt the `PERF-BUDGET.md` 3.1a limits as failing checks: per-screen allowances with a ratchet for legacy screens, target 60 / 120 / 700 and hard 100 / 200 / 1,200 for redesigned ones, 48 MB texture, shadows 6, font pairs 12; and review the two re-baselines (after I-04 and I-22) | Yes. The allowances start from the measured baseline, so the check passes on day one and still catches the 40-card cliff |
| D2 | Technical Director | A small debug overlay (FPS, draw calls, nodes, texture memory) for the phone tests | Yes, in I-02; it is the only way to get numbers off a phone |
| D3 | Systems Designer | Approve the read-only helpers in I-06 (`upcoming`, `cut_gap`, `team_kills`, `best_slot_for`) and the tutorial flag handling in I-13 | Approve; none changes a result, and the golden hash proves it |
| D4 | Producer | Run the full 25-minute check at CP2 (now after I-18) and I-25 only; use the fast loop otherwise | Yes |
| D5 | Producer | One commit per increment so rollback is a revert | Yes |
| D6 | Lead Game Designer | Home "contracts end this season" note only from round 9 (TUTORIAL 11); and the stricter opponent rule for the first game | Yes to both |
| D7 | Narrative, UI/UX | The three open items in `COPY-0.7.md` 2: "Mid" as lane and phase, "Jg" and "Sup" filter labels, `chem.pentagon_hint` colour-only wording | Take Narrative's recommendations. The second and third are rows 2 and 3 of the open table in 12.1. The third needs a non-colour cue before the colour-blind audit of Chemistry in I-25 can pass (v1.0 said "I-04's colour-blind check", but I-04 runs only a fit audit; the `cb_<screen>` checks exist for redesigned screens only) |
| D8 | Producer | Move CP2 from after I-16 to after I-18, pull the tag-only part of I-21 forward as I-21a, and optionally build an engine-preview APK after I-16 (section 10.1) | Yes to all three. It costs no extra calls and delays the Founder's first look at the guide by about 3 to 4 working days (a guess), in return for 3 cards of 27 instead of 15 |

### 12.1 Open answers still owed by the UI/UX Designer (five)

Nobody owned these before v1.1. Each is raised by Narrative or by this plan, each blocks or shapes one increment, and each has a fallback so the build is never stuck. Owner of every answer: **UI/UX Designer**. Until the Producer decides who applies a string change after the I-00 merge (the review's fix 7 is still open), the answer goes to Narrative for the wording and G1 applies it in the increment named.

| # | Question | Raised by | Needed by | Fallback if still unanswered | Lands in |
|---|---|---|---|---|---|
| U1 | Does "Form Rating" fit the Points / Form Rating switch in the Standings table header at large text (626 px)? | Narrative (`COPY-0.7.md` open decision) | I-20 | Label "Rating" (Narrative's fallback) | `standings.*` in I-20 |
| U2 | Do "Jungle" and "Support" fit the six-chip role filter on the Draft screen, or do the short forms "Jg" and "Sup" stay? | Narrative | I-16 | Keep "Jg" and "Sup" | `draft.*` in I-16 |
| U3 | What non-colour cue does the Chemistry hint (`chem.pentagon_hint`) get? Today it explains the screen by colour only | Narrative; this plan, D7 | I-04 (the sweep already touches Chemistry); latest I-25 (the colour-blind audit) | None that passes the colour-blind rule; if still open at I-25 it is a named exception signed by the Technical Director | `screen_chemistry.gd` in I-04 |
| U4 | What are the real tab labels of the Player card sheet: "Stats" and "Career"? | Narrative | I-19 | The labels as written in the copy patch ("Stats", "Career") | `squad.*` in I-19 |
| U5 | Are the interim Squad token anchors right (Top 0.110/0.540, Jungle 0.270/0.700, Mid 0.500/0.720, Support 0.840/0.742, Bot 0.889/0.540)? | This plan, I-19 | I-19 | Use the ART-BIBLE table as written; final positions move with the 0.8 arena map anyway | `screen_roster.gd` in I-19 |


---

## 13. Hand-offs

- **Producer:** I-00, I-00b and I-01 are built (I-00 waits for the Lead Programmer's review); commit each as its own commit; dispatch **I-00c**, then I-02 onward in order; commit one increment at a time; **decide D8** (CP2 after I-18, I-21a first, optional engine-preview APK; the Producer log of 2026-11-10 already records it) and **tell the Founder the card lists of section 10.1 before each APK**; APK at CP2 and CP3; permit the second Gameplay Programmer instance on G2 from I-06 if wanted; log that the Founder's feedback supersedes the earlier "guided first game stays optional" decision; ALPHA-0.7 notes at I-25.
- **Narrative:** the copy patch is the source; after the merge, copy edits go in a patch file applied by `merge_copy.py --update` with an allow-list (I-00b); the allow-list is `docs/design/copy/owned_keys.txt` (v1.2; Producer or Lead Programmer edits it); `patch2` is applied; re-run `tools/check_copy.py` when keys change.
- **Engine / Graphics:** lane E (I-05), the per-screen allowance table and its ratchet (`PERF-BUDGET.md` 3.1a; I-00c moves it into `game/tests/perf_allowances.json`), ThorVG in the Android template, the debug overlay if approved. The OFL licence file is already in the APK; nothing to do. Mark section 8 of `PERF-BUDGET.md` as the review asked if not yet done.
- **Lead Programmer (me), small:** add the `python3 -m pytest tools -q` step to `tools/check_fast.sh` (section 3.3); review I-00, I-00b and I-00c files before the Producer commits them.
- **Technical Director:** D1; confirm the 15 draw call ceiling for `HeroGrid` (I-09); the two re-baselines (after I-04, after I-22); every waiver between target and hard limit.
- **QA Automation:** **owns `game/tests/fixtures/` from now on**; audits and the matrix in I-25; seed pinning for the tutorial tests; `check_save_compat` extended with new fixtures only as new files.
- **Systems Designer:** D3 approval.
- **IP and Originality Checker:** Barlow licence entry (already logged by Engine/Graphics; the OFL text ships, verified by APK listing); badge, silhouette and icon shapes from I-05.
- **UI/UX Designer:** the five answers of 12.1 (U1 to U5), each with the increment that needs it; confirm where the inline offer card sits on Home (below Next-match and Play, I-15).
- **Owner of `TUTORIAL.md`:** add the state `new` to 6.1 and 6.2 (a brand-new save before the player answers the guide; section 5 item 3) and the kill-resume rule of section 5 item 10.
- **Producer / Game Design Lead (still open from the review):** the three GDD lines and the code comment that still call the player "the coach" (fix 13); the B11, nested-scroll and SVG probe outputs are still not in the repo (fix 11, Lead Programmer or QA Automation, small).
