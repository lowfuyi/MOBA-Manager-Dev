# UI Pass 2: layout redesign spec (workstream W3)

Date: 2026-11-08 (revised the same day, wave 1b; pass 1c numbers alignment) - Author: UI/UX Designer - Status: spec for review (Art Director, Lead Game Designer, QA Manager), then the Founder checkpoint. No game code was changed.
Answers Founder feedback 3: "everything is displayed linearly, the design is boring" (see `docs/ALPHA-0.7-PLAN.md`).
Scope: Home, Squad, Draft, Game Plan, Standings, Match Report, and (new in the wave 1b revision) the **Match screen HUD for the Alpha 0.8 arena** (section 6.7). Alpha 0.7 keeps today's match screen. Visual styling (colour, gradients, type, glow, illustration) is the art bible's job; here it is only referenced ("see the art bible"). This document fixes structure, hierarchy, sizes and interaction. The tutorial spec (W1) and the art bible (W2) were written in parallel; section 7 lists the hooks they need from this spec.

**Wave 1b revision (review `company/reviews/2026-11-08-wave1.md`; Producer rulings, which the Founder may overrule at the checkpoint):**
1. **Type scale (C1):** the sizes of 2.2 stand (Body 32, Small 26, Caption 24 floor). `ART-BIBLE.md` 5.2 (pass 2b and 2c) is now the one token table and this spec cites it: Display 64, Title 48, Value and screen or sheet title 40, Heading 36, Body 32, Small 26, Caption 24.
2. **Standings (C2):** three views (Table with a Points / Form switch, Playoffs, History). Unchanged from 6.5.
3. **Squad (C3):** lane map plus bench grid; five avatar cards is the fallback. Unchanged; a gap is closed (a starter's player sheet, 6.2).
4. **One helper name (C11):** **Coach** everywhere. "Advisor" is gone from this spec; the game strings that change are listed in `TUTORIAL.md` section 13.
5. **In-arena and side colours (C4):** you = circle in the accent colour, them = hexagon in the coral colour. Blue / Red side is a **word plus a flag glyph** on Home and the draft board only (never in the arena, never colour alone).
6. **"?" slot (C12):** the Draft header wireframe now shows it (6.3), and the Home hero states its contrast (6.1).
7. **Club colour and needs-attention (C13):** club colour follows the art bible's strength rule (a flat 10 percent wash behind the 248 px header block, `VOID` skyline at 55 to 70 percent, ART-BIBLE 3.7 rule 8); needs-attention items are **attention cards** (96 px high, 6 px `WARN` left rail, Body 32 label, chevron, no gold fill, two side by side at 330 px, ART-BIBLE 3.7 rule 9). Both are fixed numbers now, not "pending".
8. **Match HUD (C9):** new section 6.7, with a text-channel budget, the scoreboard strip, controls and large-text behaviour, and a list of things in `ACTION-VOCABULARY.md` and `ARENA-MAP.md` that do not fit, with proposed cuts.

**Pass 1c (review `company/reviews/2026-11-08-wave1b.md` sections 4.1 to 4.3; numbers only, no new content):** A1 to A3 and A5 to A12 of the review's list and B15 are done here; A4 is done in both documents. What changed: `S_BIG` 40 and `S_HEAD` 36 (A1); section labels are Caption 24 px `TEAL_HI` capitals and card titles are Heading 36 (A2); the Squad token is 96 px at the bible's six anchors and the backdrop is code-drawn, so its asset row is gone (A3); Draft titles are sentence case, "Your ban", "Your pick", "Their ban", "Their pick", 141 to 161 px in a 200 px room (A4, Producer ruling); Home attention cards and the 10 percent wash use the bible's numbers (A5); the top-right 120 x 120 px request was accepted in ART-BIBLE 3.7 rule 8 (A6); role icons and the 40 px icon size are gone, the Home tile has a 32 px icon slot (A7); map labels 24 px with a 5 px `VOID` outline (A9); `SIDE_RED` is `#F58080` (A10); `[v]` and `[^]` in the wireframes are icon slots (the font has no arrows). **Producer rulings on 6.7.1 (review 4.3):** P1 accepted (text strip 198, controls 132); P2 **rejected** (label limit stays 28, tag limit 24: a measurement with the real font found 0 of 19,881 label pairs overflowing at normal size), so D8 now reads "both coaches' labels shown, no shortening" with the large-text "show only yours" fallback kept; P3, P4, P6 to P13 accepted as written; P5 **not accepted** (the mid push window is not moved to 47.5 s; the scheduler may drop that pill). B15 is settled by P5, and the scheduler model was re-run and saved (6.7.4). `ACTION-VOCABULARY.md` pass 1c already carries the accepted Gameplay items.

## 0. Summary for the Founder (read this first)

- **The problem is real and measurable.** In the Alpha 0.6 screenshots, every screen is one column of same-looking cards; Home needs a scroll to show its four tiles, the Game Plan puts a 590 px text block above all its controls, the draft is a text grid with no pictures, and the Standings tab names break in the middle of a word ("Playo-ffs", "Trophi-es").
- **The plan.** Each of the six screens gets one strong shape instead of a stack:
  - Home: a club header with badge, one raised "next match" card, a swipe row of upcoming games, a 2 x 2 tile grid.
  - Squad: your five starters placed on a small lane map (like the arena), the bench as avatar cards, a swipe row of free agents.
  - Draft: a five-lane board (you on the left, them on the right) above a grid of hero pictures; a bottom sheet to confirm; the Coach bar suggests a hero in one tap.
  - Game Plan: a timeline (Overall, Early, Mid, Late) with big stepped sliders, and the expected result always visible on top.
  - Standings: a podium for the top three, your own row highlighted and pinned, a bracket for the playoffs.
  - Report: a three-part story strip (Early, Mid, Late), one big hero number, then what changed.
  - Match (Alpha 0.8, the arena): a scoreboard strip above, a text strip below, and a strict budget of how many words can appear at once (6.7).
- **One decision per screen stays.** Home: play. Squad: who plays which role. Draft: this ban or pick. Game Plan: how we play. Report: continue. Standings has no decision; it answers "where do I stand and what do I need".
- **Two things I need you to know.** (1) To meet the 16 sp / 48 dp rule on a 360 dp phone, text and buttons get about 15 percent bigger than today (body 28 to 32 px, buttons 92 to 96 px). Today many buttons are only 64 to 76 px, which is 32 to 38 dp: too small. (2) The art bible generates club badges and hero silhouettes in code, and gives players an initial avatar (a letter on a role ring, no faces). So the layouts never wait for painted art; only icons, empty-state pictures and backdrops are real asks (section 8.4).
- **Recommendation:** approve the layouts below; start building with Home, Draft and Report because they are on every match day. Decisions are in section 9. (D7, the body size, is settled by the Producer ruling: 32.)

## 1. What I reviewed, and the limits

Read: the agent charter, `docs/ALPHA-0.7-PLAN.md` (Founder feedback, verbatim), `UI-UX-REFERENCE-v1.md`, and the UI code (`ui.gd`, `screen.gd`, `main.gd`, `screen_hub.gd`, `screen_roster.gd`, `screen_draft.gd`, `screen_game_plan.gd`, `screen_standings.gd`, `screen_report.gd`, `player_view.gd`, `bond_pentagon.gd`), plus `screen_plan.gd`, `screen_club.gd`, `screen_prematch.gd`, the sim and game state APIs that feed these screens, `data/heroes.json`, `players.json`, `clubs.json`, `game_plan_v0.json`.

Screenshots studied in `docs/design/art/current/` (each looked at twice: first for layout and hierarchy, second for text fit, touch size, colour dependence and what is missing):
`04_hub`, `04b_hub_lower`, `19_hub_after`, `04c_tab_plan`, `05_roster`, `06_roster_picker`, `07_roster_detail`, `07d_free_agents`, `08_prematch`, `08e_chemistry`, `09_draft_start`, `10_draft_ban_2`, `10_draft_slotpanel_4`, `10_draft_slotpanel_8`, `11_draft_done`, `11b_gameplan`, `11c_gameplan_trigger`, `12_match_mid`, `14_report_top`, `15_report_mid`, `15b_report_lines`, `16_standings`, `16b_standings_form`, `17_standings_results`, `19b_trophies`.

What the second pass changed:
- `07_roster_detail.png` is a pixel copy of `05_roster.png` (the detail never opened in that capture), so the player-detail layout was judged from code only, not from a picture.
- `19_hub_after.png` shows the tile "Squad mood: fine" in red (the colour follows the form number, the word says "fine"): colour and word disagree.
- `11_draft_done.png` shows the opponent's composition bonus "+12.0%" in the same green as ours (+2.0%), which reads as good for us; it is good for them.
- In `16_standings.png` the selected tab is taller than the others, because two-line labels make the tab strip uneven.

Limits (honest): nothing here was built or run. Heights and positions are paper estimates, accurate to about 10 percent until a prototype exists. I cannot judge touch feel, scroll feel, frame rate or heat on a phone. The carousel and drag behaviours in particular are untested assumptions (see risks).

## 2. Ground rules that drive every layout

### 2.1 Units: design pixels, dp and sp

- Design canvas: 720 x 1280 px, portrait (`project.godot`: stretch mode `canvas_items`, aspect `expand`). A 360 dp-wide phone shows that canvas at **2 px per dp** (a 411 dp phone at 1.75 px per dp). I design for the harsher 2 px per dp case.
- So: **48 dp touch target = 96 px; 16 sp body text = 32 px.** Visuals may be smaller than the hit area (extend the hit area with padding), but the tappable area is at least 96 x 96 px, or 96 px high by at least 96 px wide.
- Today's tokens miss this: `S_BODY` 28 px (14 sp), `S_SMALL` 22 px (11 sp), chip text 20 px (10 sp), `BTN_H` 92 px, many buttons 64 to 76 px, the draft back button 80 x 64 px, tab buttons 88 px, `Screen` header buttons 80 px high.

### 2.2 Token changes this spec assumes (one global change, then re-shoot all screens)

**Status (Producer ruling C1, 2026-11-08; closed in pass 1c):** these sizes are adopted and `ART-BIBLE.md` 5.2 is the single token table: Display 64, Title 48, Value and screen or sheet title 40 (`S_BIG`), Heading 36 (`S_HEAD`, new), Body 32, Small 26, Caption 24 (the floor). Where this section and the bible differ, the bible wins. Two rules from the bible that this spec follows: (1) a **card title** is Heading 36 in `TEXT`, never teal; a **section label** (the row above a group) is Caption 24 px SemiBold, upper case, +8 percent tracking, `TEAL_HI`; (2) every arrow, tick, cross and star is a drawn icon, never a typed character (the font has none).

| Token | Now | Pass 2 | Reason |
|---|---|---|---|
| `S_BODY` (anything the player reads to decide) | 28 | **32** | 16 sp |
| `S_SMALL` (secondary lines, units, hints) | 22 | **26** | 13 sp; same as the art bible; never the only place a key fact lives |
| `S_CAPTION` (chips, tab labels, section labels; the floor) | 20 to 22 | **24** | 12 sp; the art bible now says 24 as well (5.2); nothing is smaller |
| `S_BIG` / `S_HEAD` (new) / `S_TITLE` | 38 / none / 46 | **40 / 36 / 48** | ART-BIBLE 5.2: Value and screen or sheet title 40, Heading 36 (card titles, the go button label), Title 48 (the hero name of a screen) |
| `S_DISPLAY` (new: result word, hero stat, score line) | 64 ad hoc | **64** | one display size, the art bible's Display |
| Button height (`BTN_H`) and minimum hit area | 92 / 64+ | **96 / 96** | 48 dp |
| Header height and header icon buttons | 80 | **96** | 48 dp |
| Tab bar buttons / `TAB_H` | 88 / 104 | **96 / 112** | 48 dp |
| `R_CARD` / `GAP` | 20 / 14 | **24 / 16** | softer, more air |
| Screen side margin | 24 | 24 | unchanged |

Rule for small text: 24 and 26 px text may not carry a number the player needs to decide (put it in 32 px); a caption is at most one line, or two when it wraps. Nothing in the game is below 24 px.

### 2.3 Space budget (what a screen really has)

| Mode | Logical canvas | Usable height with tab bar | Without tab bar |
|---|---|---|---|
| Normal, 16:9 (design case) | 720 x 1280 | 1084 | 1208 |
| Normal, tall phone (20:9) | 720 x 1560 | 1364 | 1488 |
| Large text (+15 percent) | 626 x 1113 | 917 | 1041 |

(Usable = canvas minus 48 top safe area, 24 bottom margin, and tab bar 112 + 12 gap. Large text works by `content_scale_factor = 1.15` in `app.gd`, so the layout width shrinks to 626 px, side margins leave **578 px** of content; the layout must reflow, not just scale.)
Design rules that follow:
1. **Design for 720 x 1280 first, and test 626 x 1113 (large text) and 720 x 1560 (tall) as well.** If it works at 626 x 1113 it works everywhere.
2. Columns come from the width: `columns = floor((content_width + gap) / (min_cell + gap))`. Never a fixed column count.
3. A label in a fixed-width slot wraps at word boundaries, to at most two lines. A number never wraps and has a minimum width. A button caption never breaks inside a word (today's tabs do).
4. Above the fold (what is visible without scrolling) must contain the screen's one primary decision, in normal and large text.

### 2.4 Colour-blind and colour-meaning rules (apply to every screen)

The colour-blind palette swaps good/bad to sky blue `GOOD_CB` (`#7FD0FF`) and orange `BAD_CB` (`#F2924A`). Problems the current code has, and the rules that fix them:
- In colour-blind mode, "good" (`GOOD_CB`, sky blue) is close in feel to the Blue-side flag cloth (`SIDE_BLUE` `#5AA9FF`), and the Red-side cloth (`SIDE_RED` `#F58080`) now has the value of the default `BAD` and is not swapped by the colour-blind switch (ART-BIBLE 3.3). **Rule: a side is never told by colour alone.** In every board, "You" is always on the left and "Them" on the right (whichever side you play). The side itself is a **word plus a flag glyph** ("Blue side", "Red side") on Home and on the draft board header; it is never shown in the arena, where you are a circle and they are a hexagon.
- **Rule: good/bad is never colour alone.** Every green or red value carries a sign (+ or -), an arrow glyph (up, down, flat), or a tick or cross shape. Row tints and fills are reinforcement only.
- **Rule: selected is never hue alone.** Selected = filled background + ring + check or thumb notch.
- **Rule: role identity = icon + short code (TOP, JG, MID, BOT, SUP), colour second.** Role colours must come from a colour-blind-safe set and must not reuse the good/bad or coral/teal hues (see the art bible for the values).
- **Rule: colour follows the word.** If the word says "fine", the colour is neutral (fixes `19_hub_after`). A comparison is coloured from the player's point of view (fixes the +12.0% opponent bonus in `11_draft_done`).
- Teal vs coral (accent vs primary action) stay distinct by position and shape: coral is only ever the one big "go" button.

### 2.5 Reconciliation with the art bible and the tutorial spec

`ART-BIBLE.md` and `TUTORIAL.md` were written in parallel by other agents. I read both and changed this spec where they conflict; where I disagree I say so and ask (section 9).

| Topic | Art bible / W1 says | This spec | Result |
|---|---|---|---|
| Body size | Body 30 px (15 sp) | Body 32 px (16 sp), because the brief and the UI reference say 16 sp | **Settled by Producer ruling C1 (D7): 32.** The font is narrower, so line length is about the same. Adopted in ART-BIBLE 5.2 |
| Small and caption | Small 26, Caption 22 | Small 26 (same), Caption 24 | **Settled by ruling C1:** Caption 24 is the floor everywhere (also the tutorial and the arena) |
| Display, Value, Heading, Title | 64 / 40 / 36 / 48 | Same | Adopted from ART-BIBLE 5.2 |
| Hero tiles | 3 per row, 96 px circular silhouette | Same (216 px cards) | Adopted; my earlier 4-column grid is dropped |
| Players | Initial avatar, no faces | Avatar everywhere in this spec | Adopted; "portrait kit" dropped |
| Badges | Generated from the club id, 40 to 112 px | Hero 112, Next card 96 (large text 80), podium 88 / 72 / 72, rows 56, chips 44 | Adopted; all within the art bible's range |
| Squad | Five role rows | Lane map plus avatar bench grid | **Settled by ruling C3 (D3):** lane map plus bench grid; five avatar cards in a row is the fallback. The art bible's row component serves the picker. Done: ART-BIBLE 8.2 Squad row and 6.4 (anchors) |
| Chemistry | Lane-map layout | Squad map is the same idea | Compatible; UI Pass 3 can share the component |
| Help "?" | 96 x 96 corner on every screen | Reserved in `ScreenHeader` (5.2) | Met. The Draft header now shows the slot (6.3), Home states its contrast over the hero art (6.1), and the arena puts it at the right end of the controls row (6.7.6) |
| Colour never the only cue | Rule (W1 contract 5) | Section 2.4 and every screen's (e) | Met |
| Standings tabs break words | Fix with the redesign | Three views, segmented, scroll fallback | Met |
| Squad card opens below the fold | Contract 4: scroll it into view | A bottom sheet opens in place, nothing is below the fold | Met; TUTORIAL v1.1 replaced contract items 3, 4 and 6 and added the sheet contract (overlay above `BottomSheet`) |
| Control ids | W1 section 8 ids stay | Section 7.3 maps every id to a component | Met, with two cautions for W1 |

## 3. Layout ideas evaluated

| Idea | Verdict | Where, and why |
|---|---|---|
| Hero header with club badge + next-game card with depth | **Use (Home)**; a smaller version as the result hero on Report | Gives Home an identity and one obvious thing to do. Card overlaps the header by 64 px for depth. Not used elsewhere: a hero on every screen would eat the space the controls need. |
| Two-column tile grids | **Use** | Home tiles (exists, made richer); Squad bench (2 columns of avatar cards); Game Plan "where you stand" (2 x 2 meters). **Reject** for Game Plan controls and the draft board: they are text-heavy and need the full width. |
| Horizontal carousels | **Use, only for secondary content**: Home "Up next", Squad "Free agents" | Both are "look around" content, so hiding half of it off-screen is fine; each has a "See all" button so a swipe is never the only way. **Reject** for the bench (5 cards: a grid shows all of them at once), the hero pool (40 heroes: needs filter and full view) and anything the player must decide on. |
| Player cards as a grid (avatar, role colour, status chips) | **Use** (bench, free agents, picker) | Replaces long text rows ("Brikai - Top - age 24 - 48  -  tired -3  -  in form, happy"). **Adapt**: the starting five are not a grid but a lane map (below). |
| Lane map for the starting five (new idea, from the UI reference v1 backlog UI-5) | **Use (Squad)** | Five tokens placed like the arena map; answers "who plays where" at a glance and shares the map with the W4 arena. |
| Draft board with five role lanes per team + hero grid below | **Use (Draft)** | You left, them right, one row per role, bans under it; a 3-column hero grid below (216 px cards, 96 px circular silhouettes, 6 heroes fully visible plus a peeking third row). Compact (52 px rows) at 1280 px height, full (72 px rows) on taller phones. |
| Game Plan as a visual timeline | **Use** | Four nodes (Overall, Early, Mid, Late) map exactly to the sim's contests (`Report.FEED_ORDER`, `GamePlan.EARLY`). One phase at a time instead of nine stacked cards. |
| Game Plan as a dial set (rotary) | **Reject** | Circular drag is hard on a small screen and for thumbs, has no room for end labels (the effect text is the whole point), seven dials need about 1,400 px, and it is the least accessible. Use a horizontal 5-detent track instead: same stepped feel, 96 px hit, labelled ends. |
| Standings with a podium and highlighted own row | **Use** | Podium for the top three; own row gets fill + accent bar + YOU pill, and is pinned when scrolled out of view. **Add:** a drawn bracket for Playoffs (the sim has semi-finals and a final). |
| Report with a story strip (early, mid, late) and one hero stat | **Use** | Strip = the three phases and their eight contests, from data the sim already gives. Hero stat = the single biggest factor in "why it went this way", including luck, stated honestly. |
| Bottom sheets instead of inline expansion / page swaps | **Use everywhere** | Today a tap pushes the page down (roster picker) or replaces the page (draft slot panel) and the context is lost. A sheet keeps the board or map visible. |
| Parallax or gyro depth on the hero | **Reject** | Cost on low-end phones, no help to the decision. Depth comes from layered cards and static art. |
| Swipe between bottom tabs | **Reject** | Conflicts with carousels and the Game Plan phase swipe. |
| Floating action button for Play | **Reject** | Play already lives in the next-match card; a second Play competes with it. |
| Masonry (uneven) grids | **Reject** | Uneven reading order for a decision screen. |
| Two-pane split screens | **Reject** as a true split (720 px is too narrow); **use** mirrored "You | Them" rows (Draft board, Draft complete). |

## 4. Global pattern list

1. **Card with depth.** Three elevations: flat (inside lists and grids), raised (hero cards: Next match, Report hero), sheet. Recipe in 5.1; the look (gradients, colour) is the art bible's. Performance rule: grids and long lists use the cheap flat card (1 px highlight, 2 px bottom edge, baked 9-slice, no live blur); only hero surfaces and sheets get a real soft shadow. At most 8 shadowed nodes on screen.
2. **Section header.** A Caption section label (24 px SemiBold, upper case, +8 percent tracking, `TEAL_HI`, ART-BIBLE 5.2) + optional count chip + optional action on the right ("See all", a mini segmented control). 56 px high, action hit area 96 px. Always the same, so the eye learns it. Card titles are not section headers: they are Heading 36 in `TEXT`. A "?" help slot (96 x 96) lives in the screen header for W1.
3. **Screen header.** 96 px: back (96 x 96), title (40 px Bold, `TEXT`), up to two icon actions (96 x 96 each), help "?". Title may wrap to two lines.
4. **Chip.** Passive status tag (44 px high, 24 px text, icon + word). Tappable chips are `Segmented` options or buttons, not chips. Status chips always have an icon so the meaning does not hang on colour.
5. **Segmented control.** 2 to 4 options, equal width, 96 px high, never wraps inside a word. If any label does not fit its slot (large text), it becomes a horizontally scrolling strip with the selected item scrolled into view. 5 or 6 options (role filter) are stacked icon over a three-letter code.
6. **Bottom sheet.** The only way to pick, confirm or inspect. Close by: drag down, tap the scrim, a close button, or Android Back (Back closes the sheet before it leaves the screen). Primary action pinned in the footer, 104 px.
7. **Empty state.** Illustration slot (384 x 288), one line of what is empty, one line of why or what to do, one action button. Never a blank screen (today's `17_standings_results` and `09_draft_start`).
8. **Preview, then commit.** Any change that moves a number shows the change (+3, -1.8, arrow) before the tap; reversible commits show an Undo toast (`Main.toast` already supports an action button); irreversible ones (release player, leave draft) use a confirm sheet.
9. **One coral.** Coral is reserved for the one "go" action of a screen (Play, Pick, Start the match, Continue). Nothing else tappable on the same screen is coral (coral as the "them" hexagon or bar half is allowed, ART-BIBLE 3.8). A Ban is the outlined `ban` button (ART-BIBLE 8.1), so a ban step has no coral action.
10. **Reveal, don't dump.** Primary content first (the hero), details one tap down in a sheet or "Dig deeper" tab. Expanders use a real chevron icon, not the "+ " and "- " text prefixes the code has now.
11. **In-place updates.** A tap changes the component's value; it does not delete and rebuild the whole page (today `_rebuild()` runs on every tap in Roster, Draft and Game Plan; with richer cards this will stutter on low-end phones).
12. **Scroll hints.** 24 px fade at the top and bottom edge of any scroll area that has more content; carousels show a 48 px peek of the next card.
13. **Motion.** Press scale 0.97 within 100 ms (exists); sheet slide 220 ms ease-out; numbers count up (exists); nothing over 250 ms except the Report reveal (about 2 s total, tap to skip). Everything honours `UI.animate` (Settings) and is instant when off.
14. **Icons beside words.** Every icon-only button has an accessible name and a long-press tooltip; never an icon alone for a decision.

## 5. Reusable components (build once, in `src/ui/components/`)

Existing helpers in `ui.gd` (`card`, `chip`, `chips`, `tile`, `section`, `kv_row`, `versus_bar`, `bar`, `count_up`, `fill_in`) stay and are re-skinned to the new tokens; the components below are new or extended. Sizes are design px at 720 wide. Every component takes an optional `tut_id` (a stable name the W1 coach overlay can spotlight, see section 7.3).

### 5.1 DepthCard (extends `UI.card`)
- Anatomy: shadow (hero only) > edge (2 px bottom line) > body (vertical gradient) > top highlight (1 px) > optional glow ring (selected).
- Sizes: full width 672 (578 large text); padding 24; radius 24.
- Variants: `flat`, `raised`, `inset` (darker, for map and board backgrounds).
- States: normal; pressed (scale 0.97, body darkens 10 percent); selected (3 px accent ring + glow); disabled (60 percent opacity, no press).
- Sketch:
```text
 layer 4   glow ring 3 px accent + 12 px accent blur at 35%   (selected only)
 layer 3   highlight: 1 px line, white at 8%, along the top edge
 layer 2   body: gradient top-to-bottom, PANEL -> PANEL darkened 8%
 layer 1   edge: 2 px darker line along the bottom (the "thickness")
 layer 0   shadow: 0 px blur on lists/grids (baked), real blur only on
           hero surfaces (Next-match card, sheets): 10 px, offset y 6
```

### 5.2 SectionHeader and ScreenHeader
- SectionHeader: 56 px; label Caption 24 px SemiBold, upper case, +8 percent tracking, `TEAL_HI`; optional count chip; optional right action (hit 96). ScreenHeader: 96 px; back 96; title 40 px Bold `TEXT` (the bible's Value and screen title size, 5.2); up to two 96 px icon buttons; "?" 96 px. The Draft header and the arena do not use the standard ScreenHeader (6.3 and 6.7 place the "?" themselves).
- States: action pressed/disabled. Title wraps to two lines before it ever clips.

### 5.3 Chip (extends `UI.chip`)
- Anatomy: icon (28) + text (24) + padding 16/8. Height 44, radius 22. Variants: `neutral`, `good`, `bad`, `warn`, `accent` (tint of the colour at 16 percent + border at 45 percent, as now), each with its own icon so colour is never the only cue.
- Priority when space is short (shown first to last): tired/exhausted, contract ends, out of form, in form, unhappy, happy. Show at most 2 chips on a card plus a "+n" chip.

### 5.4 Segmented
- Anatomy: container (PANEL2, radius 24), options, selected pill (accent fill + dark text, ring).
- Sizes: height 96; options equal width (three options at 578 px are 192 px wide, which fits labels up to 8 characters at 32 px, for example "Playoffs"). The role filter uses stacked options (icon over a three-letter code) so six options fit in 578 px.
- Behaviour: `fit="equal"` or `fit="scroll"` (automatic fallback when a label does not fit); never wraps inside a word. States: normal, selected, disabled, locked (lock glyph, e.g. a filled draft lane).

### 5.5 BottomSheet
- Anatomy: scrim (60 percent), sheet (radius 28 top), grab handle 64 x 8 inside a 96 px drag zone, header (title 40 + close 96), scrollable content, pinned footer (primary action 104 px).
- Sizes: `S` (fits content, max 40 percent of height), `M` (60 percent), `L` (85 percent). Opens 220 ms ease-out; instant with animations off.
- Behaviour: drag down more than 120 px or tap scrim or Back = close; the screen behind keeps updating (the draft board stays live). Only one sheet at a time.
- Sketch:
```text
 scrim 60% black ---------------------------------------------------
 +----------------------------------------------------------------+  corner 28
 |  ======  grab handle 64x8 inside a 96 px drag zone              |
 |  title (40)                                          [ close ] |  header 96
 |  ------------------------------------------------------------  |
 |  content (scrolls if taller than the sheet)                    |
 |  ------------------------------------------------------------  |
 |  [ pinned primary action, 104 px ]                             |  footer
 +----------------------------------------------------------------+
```

### 5.6 PlayerCard (avatar card)
- Variants: `Tall` 330 x 264 (grid cell, 2 columns; reflows to 283 wide at 626 px), `Row` 672 x 112 (picker and report rows), `Token` 96 (lane map, ART-BIBLE 6.4: the 96 px outer diameter is itself the 96 px hit area), `Mini` 56 (draft board: hero silhouette or avatar).
- Anatomy (Tall): initial avatar 120 (letter on a role ring, art bible 6.2), name (32, up to 2 lines), role pill (icon + code), age, big "rating here" number (40) with caption, status chips (max 2 + "+n"), role colour as an 8 px bar on the left edge.
- States: normal; selected (ring); starter (small "starts" tag so the bench cards are distinct); disabled (not in club); no art needed (the initial avatar is the art, drawn in code).
- Data: name, `role_primary`, `age_of`, `slot_score`, `fatigue_of`, `form_of`, `morale_of`, `seasons_left`.
- Sketch:
```text
 PlayerCard Tall 330 x 264        PlayerCard Row 672 x 112     Token 96
 +---------------------------+    +----------------------------+  .------.
 | .------.  Brikai          |    | .----. Brikai  [Top]  48   |  |  av  |56
 | |  av  |  [Top] age 24     |    | | av | [v tired] [final]    |  '------'
 | | 120  |                   |    | '----'                     |  Soldor
 | '------'  48 here         |    +----------------------------+  (v)  (^)
 | [v tired] [contract: last]|
 +---------------------------+
 role colour = 8 px bar on the left edge + role icon; never colour alone
```

### 5.7 HeroCard (draft grid)
- 216 x 196 (3 columns at 672 with a 12 px gap; 183 x 196 at 578 in large text). Circular hero silhouette 96 (art bible 6.2, role-colour ring), name 26 px on one line, number chip, patch arrow, archetype icon. In a 560 px grid area under the 88 px Coach bar, 2 rows (6 heroes) are fully visible and a third row peeks in, which tells the player the grid scrolls.
- Name fit (measured from `10_draft_ban_2`: "Gravenstone" is 135 px wide at 22 px, so about 160 px at 26 px): a 216 px card (about 190 px of text room) holds it, and at 183 px (about 160 px of room) it fits by a few pixels, so it is a test fixture (section 7.1) and the grid clips with an ellipsis, never wraps, if a name ever does not fit. All 40 current names fit on one line in both modes, so no renaming is needed. Rule: a data check flags any new display name over 12 characters.
- States: normal, recommended (coach star + coral border), banned (grey + X, not tappable), picked (tick + side stripe, not tappable), pressed.
- Sketch:
```text
 HeroCard 216 x 196 (183 x 196 in large text)
 +----------------+
 |(*)   .----.  (S)|  top-left: coach star   top-right: archetype icon
 |     ( 96 px )  |  circular silhouette, role ring (art bible 6.2)
 |      '----'    |  banned: grey + big X   picked: tick + side stripe
 | Gravenstone    |  name 26 px, one line; all 40 names fit (longest is 11)
 | (v) -1.6   82  |  bottom-left: patch arrow;  bottom-right: number
 +----------------+
```

### 5.8 LaneRow and LaneBoard (draft)
- LaneRow: 52 px compact or 72 px full; left slot (hero silhouette Mini + hero name or "Open" + player name), centre role glyph 32 beside its code (TOP, JG, MID, BOT, SUP), right slot mirrored. LaneBoard = header + 5 LaneRows + bans row.
- States per slot: empty (dashed outline, player name shown so the player sees who plays here), pulsing (this lane is the pick target), filled, banned.

### 5.9 Carousel
- Horizontal scroller with snap and a 48 px peek of the next card; card widths 300 (free agents) or 560 (upcoming games); a page-dots line when 3 or more cards; direction lock (a drag that starts mostly vertical scrolls the page, a drag that starts mostly horizontal scrolls the carousel; threshold 12 px). Always paired with a "See all" action. Empty state when 0 cards.

### 5.10 EdgeMeter
- A centre-zero bar 20 px high (the bible's bar height, 8.1): left half = them, right half = you; fill length = the edge; the value is printed as signed text (+5.6%), 32 px. Used in Game Plan (contests) and Report (phase margin). Colour is reinforcement only (rule in 2.4).

### 5.11 DetentTrack (replaces the "-- - 0 + ++" button row)
- Five stops, track 8 px, thumb 56 px, hit area 96 px high by the full width. Tap a stop or drag the thumb; it snaps. Ends have 26 px labels (short words), the live effect line below is 28 px (the existing `gp.c.*.neg/pos/balanced` strings).
- States: normal, focused (ring), inert (lock glyph + "no effect in this plan", see Game Plan), disabled.
- Sketch:
```text
 TEMPO                                             Balanced   <- name + value
 [o--------o--------(O)--------o--------o]                    <- 96 px hit, track 8 px,
  Push early                       Scale late                    thumb 56 px, 5 detents
  Balanced: no trade between lanes and the late game.         <- live effect (28 px)
 Keyboard/screen-reader: left and right change one detent; value is read as a word.
```

### 5.12 PhaseStrip
- Horizontal form (Game Plan): 4 nodes (Overall, Early, Mid, Late) joined by a line; node 56 px circle with a phase icon, label 26 px, one caption line ("lead 2/4"). Hit area per node = a quarter of the width by 96 px.
- Vertical form (Report story): 3 nodes (Early, Mid, Late) down the left edge, each joined to the next, with a band of contest chips (112 px high) to its right. Chip = icon + label + tick or cross; band wraps to 2 x 2 chips in large text.
- States: normal, selected (filled + ring), inert/locked (lock glyph), result tint (win/lose with a tick or cross).

### 5.13 Podium and RankRow (standings)
- Podium: 3 columns (2nd, 1st, 3rd), pedestal heights 88 / 120 / 64, badge 88 (1st) and 72 / 72 (2nd, 3rd) as the art bible sets, name 2 lines, points 40 px.
- RankRow: 672 x 104: rank (56) + badge 56 (ART-BIBLE 8.2; it was 40 in the Alpha) + name in Body 32 (1 or 2 lines) + right column (points Heading 36 over record Small 26). Own row: PANEL3 fill + 8 px accent bar + "YOU" pill (text). Playoff line: dashed divider with a label after rank 4.
- Sketch:
```text
 RankRow 672 x 104 (own row: PANEL3 fill + 8 px accent bar + YOU pill)
 | 9 | (b 56) | Northreach Corsairs  [YOU]            0 pts |
 |   |        | 0-1                                    ...  |
 Right column: points 36 px over record 26 px. Name takes 1 or 2 lines.
```

### 5.14 HeroStat
- Display number (64) + one sentence (32) + two chips (best, worst). Counts up. Used in Report; reusable for Home milestones later.

### 5.15 EmptyState, IconButton, Toast
- EmptyState: illustration slot 384 x 288, title 32, helper 26, action 96. IconButton: 96 x 96 with accessible name. Toast: exists in `main.gd`; keep, set min height 96 when it has an action.

### 5.16 Proposed API (for engineering; names are suggestions)
`UI.depth_card(parent, elevation := 1, tint := PANEL, selected := false) -> VBoxContainer`; `Segmented.new(options, selected, on_change, fit := "auto")`; `BottomSheet.open(title, build_content: Callable, build_footer: Callable, size := "M")`; `PlayerCard.make(pid, variant, opts)`; `HeroCard.make(hid, state, opts)`; `PhaseStrip.new(phases, selected, on_select, vertical := false)`; `DetentTrack.new(id, value, on_change, labels)`; `EdgeMeter.new(value)`; `Podium.new(rows)`; `Carousel.new(card_w, items, see_all)`.

## 6. Screen specs

Wireframe key: the frame is 720 px wide (1 character is about 10 px across; heights are written beside the frame). `(b)` = club badge, `[ ]` = a tappable control, `[x]` / `(x)` = a filled state (or a cross, where the text says lost), `ok` = tick, `(+)` `(-)` = ahead and behind, `face` = portrait. **`[v]`, `[^]` and `(v)`, `(^)` are icon slots** (a drawn down or up arrow icon, never a typed character: the font has no arrows, ticks, crosses or stars, ART-BIBLE 5.1); `ok` and `x` are tick and cross icons. **Upper-case text inside a frame is a Caption section label** (24 px, `TEAL_HI`, +8 percent tracking); screen titles, buttons and the result word are sentence case. Each frame shows the normal-text case at 720 x 1280.

---

### 6.1 Home (`screen_hub.gd`, tab "home")

#### (a) Diagnosis (`04_hub`, `04b_hub_lower`, `19_hub_after`)
- No identity: the club name is a 46 px text line; no badge, no colour, nothing says "this is your club".
- The welcome tip card (about 280 px) sits above the Play card; Play is pushed to y 750 to 840 and the four tiles only appear after a scroll (`04b`). The first screen the Founder sees is mostly instructions.
- All blocks are the same shape: tip, next game, attention, tiles are grey rounded boxes of the same weight. The next-game card has a coral outline but no depth, no opponent picture.
- "Needs your attention" is a card around a single full-width button; it reads like a form field.
- Unused data that would make Home alive: last five results, the next opponents, the table position as a picture.
- Colour contradicts the word on the mood tile (`19_hub_after`: red "fine").
- Touch size: the "Auto-play" button is 76 px (38 dp); tab buttons 88 px.

#### (b) New layout (above the fold ends at about y 1132)
```text
+----------------------------------------------------------------------+
|~~ page gradient + 10% club wash + skyline art, under status bar ~~   |  <- hero 0-248
|  .--------.   Northreach Corsairs                            [ ? ]   |
|  | BADGE  |   Season 1 - Round 1 of 18 - Patch P1                    |
|  |  112   |   Rank #9    0-1    (L)(-)(-)(-)(-)   last five games    |
|  '--------'                                                          |
| +----------------------------------------------------------------+   |  <- card top y=184
| | NEXT LEAGUE GAME - ROUND 1                  [flag  Red side]   |   |
| |                                                                |   |
| |   (BADGE  96)              VS              (BADGE  96)         |   |
| |   Northreach                                Mossgate           |   |
| |   Corsairs                                  Wardens            |   |
| |                                                                |   |
| |  You 53.5 [=========teal=====|=======coral======] Them 51.5    |   |
| |  [short draft] [+0.9% chem] [5 tired]                          |   |
| |  [        Play game   (coral, 104 px)                       ]  |   |  <- the one coral
| |        Auto-play this game   (text button, 96 px hit)          |   |
| +----------------------------------------------------------------+   |  <- bottom y~850
|  #[!] 5 tired starters  >  #[!] 10 contracts end  >    (swipe)       |  <- cards 96
|  UP NEXT                                            See all  >       |  <- header 56
| - - - - - - - - - - - - - - fold at y~1132 - - - - - - - - - - -     |
|  +--------------+ +--------------+ +--------------  (peek 48 px)     |
|  | R2  (b) Foxes| | R3  (b) Owls | | R4 ...                          |  <- cards 200
|  | Blue - even  | | Red - harder | |                                 |
|  +--------------+ +--------------+ +--------------                   |
|  +--------------------------+ +--------------------------+           |
|  | STANDING            [ic] | | CASH                [ic] |           |
|  | #9  of 10   [ladder]     | | 2,617   (^) +17 a week   |           |
|  | 0-1 - 0 pts              | |                          |           |
|  +--------------------------+ +--------------------------+           |
|  | CHEMISTRY           [ic] | | SQUAD MOOD          [ic] |           |
|  | +0.9%  (ring gauge)      | | ( av ) fine   form 0.0   |           |
|  +--------------------------+ +--------------------------+           |
| [ Home ][ Squad ][ Plan ][ Club ][ More ]   tab bar, 96 px buttons   |
+----------------------------------------------------------------------+
```
Notes on the frame:
- The hero header is 248 px, full bleed under the status bar. **Club colour follows the art bible's strength rule (C13, ART-BIBLE 3.7 rule 8):** club colour is identity, not status, so the hero is the normal page gradient (`BG_GLOW` `#14284A` falling to `BG`) with a flat **10 percent wash** of the club's primary behind this club's own 248 px header block only, `VOID` skyline silhouettes at 55 to 70 percent, and the badge at full colour with its rim and shadow; buttons, bars, chips and the chrome stay teal and coral. My first draft said "club-colour gradient"; that is withdrawn (white `TEXT` on the ten club primaries is only 2.2 to 3.2:1, bible 3.7). Badge 112 on the left, club name Title 48 (two lines if needed), season line 26 px, rank + record + five form pips (a pip is a circle with the letter W or L inside, so it is not colour alone).
- **The "?" over the hero art (C12).** The hero art sits behind the "?" slot. The button is a solid 88 px circle (fill `PANEL3`, glyph `TEXT`, 7.1:1) with a 2 px ring in `TEXT2`; the **ring** carries the contrast, because the circle fill alone is only 1.1 to 1.8:1 against the hero (computed from the art bible's hex values, not seen on a device). Ring against the page gradient top `BG_GLOW` is 8.6:1; against a worst-case 10 percent club wash 7.5 to 8.0:1; against a skyline shape lifted 20 percent towards white 4.6:1 (all three above the 3:1 needed for a control boundary). **Accepted by the Art Director (ART-BIBLE 3.7 rule 8, pass 2c, review A6):** the top-right 120 x 120 px of the hero art stays clear of anything lighter than `BG_GLOW` lifted 20 percent towards white (`#43536E`); no badge, glow, coach star or lit shape is drawn in that corner. The "never opened" dot is a shape (a filled circle on the ring), so it does not rely on colour.
- The Next match card is raised and overlaps the hero by 64 px. It is the only raised card on the screen. Play is the only coral element. Auto-play drops to a text button (still a 96 px hit area), because it is the less common path.
- The welcome tip card disappears from the layout: W1's coach overlay replaces it. Until W1 ships, a tip renders as a one-line banner (96 px) under the hero, not a 280 px card.
- "Needs you" appears only when something needs a decision: a horizontal strip of **attention cards** (ART-BIBLE 3.7 rule 9; the structure was mine, the card is the bible's). Each card is **96 px high** (it is tappable, so it is not a 44 px chip), a `PANEL` surface, a **6 px `WARN` rail on the left**, a drawn warning icon in `WARN`, the label in `TEXT` at **Body 32**, a chevron in `TEXT2`; no gold fill and no gold text. **Two cards fit side by side at 330 px** (2 x 330 + a 12 px gap = 672); more scroll sideways with a 48 px peek. Label room in a 330 px card is about 220 px (6 rail + 16 padding + 32 icon + 8 gap + label + 8 gap + 24 chevron + 16 padding); measured in Barlow Semi Condensed Regular 32 px, "5 tired starters" is 184 px and "10 contracts end" 204 px, so both fit with 16 px to spare, while "Debt: cash below zero" (271 px) does not and takes a full-width 672 px card. In large text a card is 530 px wide (the next one peeks 48 px). Tiles: flat `PANEL` cards with a **32 px icon slot at the top right** (ART-BIBLE 8.1 `tile()`: icon slot, delta line with an arrow icon), label Caption 24, value `S_BIG` 40.
- Playoff state: the card shows the series ("Semi-final, best of 3") with win pips under the badges. Season over: the card becomes a "Champions" or "Season complete" card with the Season summary as its primary button. Eliminated: the "your season is over" line plus "Finish the season".

#### (c) Data and functions feeding each block
| Block | Source (existing unless marked NEW) |
|---|---|
| Hero: club name, season line | `gs.club_name(me)`, `gs.d["season"]`, `gs.d["round"]`, `gs.total_rounds()`, `gs.patch_label()` (same strings as `hub.when.*`) |
| Hero: badge and colours | NEW art asset per club id; NEW `colors` field per club in `data/clubs.json` (primary, secondary) |
| Hero: rank, record, last five | `gs.standings()` row for `me`; last five from `gs.d["history"]` entries (`won`), newest first (practice games are not stored there, correct) |
| Next card | `gs.next_game()` (`blue`, `red`, `kind`, `full`, `series`, `game`); `App.world.team_rating(gs.lineup())` vs `gs.lineup_for(opp)`; `UI.versus_bar`; chips from `gs.chem_bonus()`, `gs.tired_starters().size()`; series pips from `gs.d["playoffs"]["series"]` (`wins_a`, `wins_b`, `best_of`) |
| Play / Auto-play | unchanged: `App.pace_t0 = ...; App.go(ScreenPreMatch.new(g))` and `_quick(g)` -> `ScreenHub._finish_game` |
| Needs you | the existing `_attention()` list (tired starters, expiring contracts, debt) |
| Up next carousel | NEW `GameState.upcoming(n)`: the first n unplayed fixtures in `d["fixtures"]` where `blue` or `red` is `club()`, with round, side, opponent; opponent strength `team_rating(lineup_for(opp))`; word Favoured / Even / Underdog from the rating gap (suggested thresholds: 2.0 rating points either way; the Match day screen uses 1.5 per lane; Systems to confirm) |
| Tiles | Standing: `standings()` row; Cash: `gs.cash()`, `gs.weekly_net()`; Chemistry: `gs.chem()` (0 to 100, for the ring), `gs.chem_bonus()`, `gs.bond_mean()`; Mood: the existing average of `morale_of` and `form_of`, word from `Bonds.mood_word` |

#### (d) Interactions
- Tap Play: goes to the match day screen as now. Tap the Next card body (not a button): opens a "Match preview" bottom sheet (size M) with the five lane matchups (the content of `screen_prematch.gd`'s matchup list) and "Change lineup" and "Rest tired starters" buttons. This is additive; the Match day screen stays in 0.7 (see decision D4).
- Tap an attention card: goes to the place that fixes it (Squad, or Finance), as now.
- Swipe the "Up next" carousel; tap a card: sheet (size S) with the opponent's rating, table position, Form rank and your last result against them (no commit, read-only). "See all" opens a sheet (size L) listing every remaining fixture (round, side, opponent).
- Tap a tile: Standing opens Standings; Cash opens Finance; Chemistry opens Team chemistry; Mood opens Squad.
- Long-press the badge in the hero: nothing in 0.7 (reserved for club details). No long-press is required for anything on this screen.
- Pull and swipe: vertical scroll only on the page. The attention-card strip and the carousel scroll sideways only.

#### (e) Large text and colour-blind
- Large text (626 px logical): hero badge 88, hero 220 px high; the club name may take two lines; Next card badges 80, names two lines; the Next card's chip row wraps to two lines; attention cards are 530 px wide; tiles stay two per row (283 px wide each, values 40 px, captions wrap to two lines); the carousel peek stays 48 px. Play remains above the fold (about y 840 of a 965 px fold); the carousel and tiles are below it.
- Colour-blind: form pips carry the letter W or L; the versus bar uses teal vs coral (not the good/bad pair); "Favoured / Even / Underdog" is a word with an arrow; the cash trend is an arrow glyph plus a signed number; the mood word and its colour agree (neutral for "fine").

#### (f) One primary decision
"Play the next game." It is the only coral element and the first thing visible. Everything else on Home is secondary and sits below or beside it.

---

### 6.2 Squad (`screen_roster.gd`, tab "squad"; also opened from the Match day screen with the tab bar hidden)

#### (a) Diagnosis (`05_roster`, `06_roster_picker`, `07d_free_agents`; detail judged from code)
- A 440 px "Team rating" card with a hint, three text lines and two big buttons sits above the lineup; the lineup itself starts at y 600 and fills the rest of the screen, so the bench is two screens away (`05`).
- The lineup is five identical centred buttons ("Top: Soldor (56)"). No avatar, no role cue, no status; a tired or unhappy starter looks the same as a fresh one until you read a suffix of text.
- Tapping a slot inserts a list of up to ten more identical buttons inside the card and pushes everything down (`06`); the lineup you are editing is no longer visible.
- The bench rows are long strings ("name - role - age - rating  -  tired -3  -  in form, happy") that wrap badly in large text; the player detail opens inline under the row with eight stat bars, a career log, contract and release buttons: one very long page (from code).
- "Team chemistry" and "Free agents" are two wide buttons inside the header card; free agents are another list of identical two-line buttons (`07d`).
- Touch size: slot buttons are 76 px (38 dp), picker rows 66 px (33 dp).

#### (b) New layout
```text
+----------------------------------------------------------------------+
| Squad                                    [ Auto lineup ]   [ ? ]     |  <- header 96
| [Rating 53.5] [Chem +0.9% >] [Squad 10/10] [Wages 265/wk]            |  <- strip 120
| STARTING FIVE      tap a token to change who plays the role          |  <- header 56
| +----------------------------------------------------------------+   |  <- map 672x440
| |  (the top edge cuts the lake, on purpose: ART-BIBLE 6.4)       |   |
| |                                                                |   |
| |   .-------.                                        .-------.   |   |
| |   | av  56|                                        | av  58|   |   |
| |   '-------'                                        '-------'   |   |
| |  Soldor [v] .-------.      .-------.              Talfin [^]   |   |
| |             | av  50|      | av  52|            .-------.      |   |
| |             '-------'      '-------'            | av  52|      |   |
| |              Yorric         Caeldor             '-------'      |   |
| |                                                  Lummir        |   |
| |                                                                |   |
| |  your base (plaza, Cairn) is at the bottom, always             |   |
| +----------------------------------------------------------------+   |
| BENCH (5)                                       sort: rating  v      |  <- header 56
| +---------------------------+ +---------------------------+          |
| | .------.  Brikai          | | .------.  Nyxwyn          |          |  <- card 330x264
| | |  av  |  [Top] age 24     | | |  av  |  [Bot] age 20     |        |
| | '------'  48 here         | | '------'  43 here         |          |
| | [v tired] [contract: last]| | [^ in form]               |          |
| +---------------------------+ +---------------------------+          |
| ... 3 rows (5 players + 1 market card)                               |
| REINFORCEMENTS (free agents)                      See all  >         |  <- header 56
| +--------------+ +--------------+ +--------------  (peek)            |  <- cards 300
| |  av  Eldvik  | |  av  Bramgus | |                                  |
| | Jg - 23      | | Bot - 24     | |                                  |
| | 60 (pot 68)  | | 54 (pot 61)  | |                                  |
| | asks 44/wk   | | asks 29/wk   | |                                  |
| +--------------+ +--------------+ +--------------                    |
| [ Home ][ Squad ][ Plan ][ Club ][ More ]                            |
+----------------------------------------------------------------------+
```
Notes on the frame:
- The **lane map** is the hero of the page: the player's half of Hollowmere in a 672 x 440 inset card (578 x 380 in large text), five **96 px tokens** at the anchors of ART-BIBLE 6.4 (arena x, y; then card px at 672 x 440): Top (0.110, 0.540) at 74, 114; Jungle (0.270, 0.700) at 181, 227; Mid (0.500, 0.720) at 336, 241; Support (0.840, 0.742) at 565, 257; Bot Carry (0.889, 0.540) at 597, 114. The wireframe above is to those x positions and only roughly to the y positions. The 128 px token and the placeholder percentages of my first draft are withdrawn: at 128 px the tokens touched each other and hid the roads (bible 6.4). Each token: initial avatar (inner disc 78 px, 6 px role ring, 2 px `VOID` outer ring, initial 44 px SemiBold), a 36 px `PANEL3` rating disc at the upper right (24 px Bold number), at most one 32 px status icon chip at the lower right (tired or in form), the name under it (26 px Medium `TEXT`, 5 px `VOID` outline, 76 px below the token centre, two lines in large text). **No role glyph on the map: the lane is the role** (glyphs appear on the bench cards and the picker rows). The backdrop is **drawn in code** (ART-BIBLE 6.4: `VOID`, two `MAP_LAND` pockets, the `PANEL2` plaza, the `MAP_MERE` lake with a `MAP_SHORE` rim, three `PANEL3` lanes), so the 1344 x 880 backdrop asset is cancelled. Spacing, ring to ring (bible 6.4): Support to Bot 52 px, Jungle to Mid 60, Top to Jungle 61; at 578 x 380 the smallest are 31, 39 and 39 px, and no token overlaps another or its neighbour's name.
- The **team strip** is four stat pills (rating, chemistry, squad count, wages) instead of a text card; chemistry is tappable.
- The **bench** is a 2-column avatar-card grid (Tall cards). The sixth cell holds a "Find a player" card that opens the free-agent market.
- **Reinforcements** is a carousel of free agents (top six by rating) with "See all".
- Match-day variant (opened from the Match day screen): no tab bar; a pinned footer button "Done" (coral is not used here: Play is not on this screen, so "Done" is teal) returns to the Match day screen.

Lane picker sheet (opens when a token is tapped):
```text
+----------------------------------------------------------------------+
| (map visible and dimmed behind the scrim; sheet is 60% of the height)|
| +----------------------------------------------------------------+   |
| |                         -------  (grab handle, 96 px hit)      |   |
| | Who plays Mid?                                        [ close ]|   |
| | +------------------------------------------------------------+ |   |
| | | .----. Caeldor  [Mid]            52 here       now playing | |   |
| | | | av | form 0.0 - morale ok                                | | | |
| | | '----'                                                     | |   |
| | +------------------------------------------------------------+ |   |
| | | .----. Talfin   [Bot] [off-role]  44 here    -8 (v)        | |   |
| | | | av | swaps with Talfin <-> Caeldor: team -1.8            | | | |
| | | '----'                                                     | |   |
| | +------------------------------------------------------------+ |   |
| | | .----. Brikai   [Top] [v tired]   41 here   -11 (v)        | |   |
| | +------------------------------------------------------------+ |   |
| |   rows are 112 px, sorted by rating in this role; the number    |  |
| |   on the right is the change in TEAM rating if you tap the row  |  |
+----------------------------------------------------------------------+
```

#### (c) Data and functions feeding each block
| Block | Source |
|---|---|
| Team strip | `w.team_rating(lu)`, `gs.chem_bonus()`, `gs.roster_slots_used()` / `Economy.data()["max_roster"]`, `gs.wage_bill()` |
| Tokens | `gs.lineup()` (slot -> player), `w.slot_score(p, s)`, `w.player_fit(p, s)` (below 1.0 = off-role icon), `w.fatigue_of`, `w.form_of`, `w.morale_of` (the same thresholds as `UI.fatigue_tag` and `UI.mood_tag`), initial avatar (first letter, role ring) drawn in code from the player's name and role; no art asset |
| Bench cards | `w.club_players(gs.club())` minus starters, sorted by `_best`; `w.age_of(p)`; `gs.seasons_left(pid)` for the contract chip; `p["role_primary"]` |
| Picker sheet rows | candidates sorted by `w.slot_score(p, slot)` (as `_picker` does now); the delta = `w.team_rating(lineup_with_swap) - w.team_rating(lineup)` computed on a copy of `gs.lineup()` (NEW small helper); the swap note comes from `gs.assign` (it swaps when the player already starts elsewhere) |
| Commit | `gs.assign(slot, pid)` then `App.autosave()`; an Undo toast restores the previous `d["lineup"]` |
| Auto lineup | `gs.reset_lineup()` with an Undo toast |
| Player detail sheet | `PlayerView.stat_block`, `PlayerView.career_section`, `PlayerView.best_heroes_line`, `PlayerView.contract_text`, `gs.can_release`, `gs.release_cost`, the existing renew and release calls |
| Reinforcements | `gs.fa_players()` top six by rating, `gs.asking_wage(pid)`; opens `ScreenNegotiation` as now |

#### (d) Interactions
- Tap a token: lane picker sheet (size M, opened with the rows already scrolled so the current player is visible). Each row shows the change in team rating if you tap it, so the number is the preview. Tap a row: commits, closes, toast "Talfin now plays Mid" with Undo. **Tap the "now playing" row** (the current starter, a chevron on its right): it changes nothing, so it opens that starter's player sheet. This closes a gap in my first draft, where bench cards opened the player sheet but a starter had no way to (found while rewriting the tutorial's steps 5 and 6). Id `squad.picker.card`. The picker header carries id `squad.picker.head`.
- **Token positions (C10, closed):** the anchors are the bible's (6.4, read from `arena_map.json`), which already follow Hollowmere's real arrangement: Top and Bot Carry on the two arcs, Mid on the causeway, Jungle in the left pocket, Support behind the carry. The old diagonal placeholders are gone. If the Level Designer moves a node, the bible table is re-read, not this spec.
- Tap a bench card: player detail sheet (size L) with a segmented control Overview | Stats | Career. Overview: avatar 160, status bars (fatigue, form, morale as three 20 px bars with signed numbers), contract line, bond line, best heroes. Footer: "Put in lineup" (opens the lane picker for this player's best role), "Renew" when the contract ends within one season, and "Release" (a second sheet asks to confirm, with the cost, exactly as the current confirm text).
- Long-press a bench card (400 ms): lifts it; drag it onto a token to swap. This is an accelerator only; the tap path always works. (Untested on touch: see risks.)
- Swipe the Reinforcements carousel; tap a card to negotiate; "See all" opens the full Free agents screen.
- "Auto lineup" (header): applies the best rested lineup, with Undo. Tapping the chemistry pill opens Team chemistry.
- Back: inside a sheet, closes the sheet. On the Match day variant, returns to Match day.

#### (e) Large text and colour-blind
- Large text: the map card is 578 x 380 and **tokens stay 96 px, only their centres move** (anchors at 578 x 380 in ART-BIBLE 6.4); names may wrap to two lines under tokens; the team strip becomes 2 x 2 pills; the bench grid keeps two columns (283 px cards, avatar 100, name two lines, only one status chip shown plus "+n"); Reinforcements cards 280 px. The first row of the bench stays visible below the map on a 1113 px canvas only if the strip collapses to one row; if not, the bench starts below the fold, which is acceptable because the lineup (the decision) is fully visible.
- Colour-blind: status is an icon plus a word (in the sheet and on cards) and the picker delta is a signed number with an arrow; off-role is an icon plus the words "off-role"; the role ring has the role code letters; the selected token has a ring and a check, not just a colour.

#### (f) One primary decision
"Who plays which role." The map and its five tokens are the whole top of the page; the bench and the market exist only to feed that decision.

---

### 6.3 Draft (`screen_draft.gd`, no tab bar)

#### (a) Diagnosis (`09_draft_start`, `10_draft_ban_2`, `10_draft_slotpanel_4`, `10_draft_slotpanel_8`, `11_draft_done`)
- While the other side chooses, the screen is nearly empty: a plain-text board and one floating button in 700 px of black (`09`). The most exciting moment of the loop looks like a waiting room.
- The hero pool is text only: two columns of buttons reading "Veshra / Shade their best 82". 40 heroes with no pictures, no roles, no sense of who counters whom. The only meta cue is green or grey text colour, which a colour-blind player cannot read.
- The board is a three-column text grid with Blue first, so "my side" changes position from game to game; picks are names without pictures.
- The timer is a text "10 s"; nothing warns that it is running out except the colour turning red at 3 seconds.
- Choosing a hero replaces the whole page with a slot list (`10_slotpanel_*`): the board disappears, so the player cannot see which lanes are already filled while choosing one. Five identical wide buttons.
- Draft complete (`11`): two text cards listing the picks, then two stacked buttons; the composition lines are both green although the opponent's +12.0% is bad for the player.
- Touch size: the back button is 80 x 64 px (32 dp high); the Coach button ("Take advisor's choice" in today's strings, renamed in `TUTORIAL.md` section 13) is 68 px.

#### (b) New layout (compact board, the 1280 px case)
```text
+----------------------------------------------------------------------+
| [<]  Your ban        ( 8 )  [ Auto-finish ]  [ ? ]                   |  <- header 104
| steps: [x][x][ ][ ][ ][ ][ ][ ][ ][ ][ ][ ]   ban short, pick tall   |
| YOU [flag] Blue              ROLE              Red [flag] THEM       |  <- board 330
| +--------------------------+ ( top ) +--------------------------+    |  <- rows 52
| | [img] Open - Soldor      |         | Ottomere  [img]          |    |
| +--------------------------+ ( jg  ) +--------------------------+    |
| | [img] Open - Yorric      |         | Veshra    [img]          |    |
| +--------------------------+ ( mid ) +--------------------------+    |
| | [img] Open - Caeldor     |         | Embrel    [img]          |    |
| +--------------------------+ ( bot ) +--------------------------+    |
| | [img] Open - Talfin      |         | Sparrowe  [img]          |    |
| +--------------------------+ ( sup ) +--------------------------+    |
| | [img] Open - Lummir      |         | Vellgrim  [img]          |    |
| +--------------------------+         +--------------------------+    |
| bans  [X][ ]                                              [X][ ]     |  <- row 52
| Needs [x Frontline] [ Initiator] [ Wave clear]                       |  <- 56
| [ All ][ Top ][ Jg ][ Mid ][ Bot ][ Sup ]   (segmented, 96 px)       |  <- 96
| +----------------------------------------------------------------+   |  <- grid area
| | * Coach suggests   Veshra  (Shade)                    [ Take ] |   |  <- scrolls
| +----------------------------------------------------------------+   |
| +----------------+ +----------------+ +----------------+             |
| |  (*)  .----.   | |       .----.   | |       .----.   |             |
| |      ( 96 px)  | |      ( img  )  | |      ( img  )  |             |
| |       '----'   | |       '----'   | |       '----'   |             |
| | Veshra         | | Gravenstone    | | Ottomere       |             |
| | (S) 82     (v) | | (B) 77     (^) | | (B) 76         |             |
| +----------------+ +----------------+ +----------------+             |
|   3 columns, card 216 wide (183 large text), number = threat         |
| ... scrolls (40 heroes, 6 fully visible, third row peeks)            |
+----------------------------------------------------------------------+
```
Notes on the frame:
- **Header (104 px) with the "?" slot (C12).** Five parts, left to right: back (96 x 96), title (40 px Bold, sentence case: **"Your ban", "Your pick", "Their ban", "Their pick"**, Producer ruling A4), timer ring (72 px circle that drains; digits inside; at 3 s or less it turns the warning colour, shows a "!" icon and pulses), **Auto-finish** (text button, 26 px label, 176 x 96 hit; the label is 116 px wide in SemiBold 26) and **"?" (96 x 96 hit, 88 px circle, top right, the same corner as every other screen)**. **Width budget at 720 (672 usable): 96 + 72 + 176 + 96 = 440 for the four fixed parts plus 4 gaps of 8 = 32, which leaves 200 px for the title** (the bible's 2b figure of 260 px was wrong and is deleted, ART-BIBLE 5.2 and 8.2). Measured in Barlow Semi Condensed Bold 40 (the bible's numbers, re-measured here): "Your ban" 141 px, "Your pick" 150, "Their ban" 152, "Their pick" 161, so every title fits on one line with 39 px or more to spare. At 578 px (large text) 106 px is left, so the title takes two lines ("Their" 84 px and "pick" 69 px both fit 106) and the header is 128 px high (2 lines of about 46 px). The older "YOUR TURN: BAN" is gone (229 px in sentence case, 271 in capitals: it does not fit beside the "?" at either size); the AI's turn is named in the grid overlay ("Mossgate is choosing a ban..."). Contrast of the "?" on this screen: the page gradient only, same circle and ring as Home (6.1), no art behind it. The 12 (or 16) step segments underneath show the whole order: bans are short bars, picks tall, the current one is highlighted, done ones carry the side flag.
- **Board:** You are always on the left, Them on the right. The column headers carry the side as a **word plus a flag glyph** ("Blue" with a flag, "Red" with a flag), never colour alone and never a bare letter. Rows are 52 px compact (hero silhouette Mini 44 + hero name; open slots show "Open" and the player's name so you can see who plays the lane) or 72 px full when the available height allows (rule below). Bans sit under the lanes (one slot at short drafts, three at full).
- **Needs strip (56 px):** the existing "Frontline / Initiator / Wave clear" checklist as ticked or empty chips; once three heroes are picked it adds the live composition style chip ("Skirmish +2.0%").
- **Role filter (segmented, 96 px):** All, Top, Jg, Mid, Bot, Sup, with a tick on a role whose lane you have already filled. It filters by `role_primary` or `role_secondary`; "All" is the default. It never hides what the sim allows (off-role picks stay legal).
- **Hero grid:** 3 columns of HeroCards (216 x 196, 12 px gap, 6 heroes fully visible plus a peeking third row; the art bible's 3-per-row tile); sorted exactly as today (by familiarity times fit, or by their best in the ban phase), so the best candidate is top left. The first row of the scroll area is the **Coach suggests** bar (88 px) with a one-tap **Take** (today's "Take advisor's choice", renamed: the helper is **Coach**). The bar reads "Coach suggests: Veshra" and is also shown in the ban phase (the suggested ban).
- **Board size rule (deterministic, testable):** the grid area must be at least 560 px high. If `usable_height - (header 104 + needs 56 + filter 96 + full board 400 + gaps 48)` is less than 560, use the compact board (330), otherwise the full board. At 720 x 1280 that is compact (grid about 574 px, 2.9 rows); at 720 x 1560 it is full. In large text the needs strip merges into the board header and the grid shows two rows of three.
- **AI's turn:** the grid dims to 50 percent with a one-line overlay ("Mossgate is choosing a ban...") and the chosen hero flies from the grid into its lane (300 ms; instant when animations are off). No empty screen.

Pick or ban confirm (bottom sheet, the board stays live above):
```text
+----------------------------------------------------------------------+
| (board stays visible and live above; grid is dimmed behind the scrim)|
| +----------------------------------------------------------------+   |
| |                         -------  (grab handle)                 |   |
| | .--------.  Brixley                                    [close] |   |
| | |  img   |  Gunner  [scales late] [split push]  mixed damage   |   |
| | |  128   |  Patch -1.6% (v)     Difficulty  o o o . .          |   |
| | '--------'                                                     |   |
| | POWER      early 43   |   mid 51   |   late 59    (3 columns)   |  |
| | STRONG VS  (img) Dovrin   (img) Sparrowe                       |   |
| | PLAYS AS   [Top 85%][Jg 85%][Mid 85%][ BOT 100% ][Sup 85%]     |   |
| |            ^ best fit is preselected; filled lanes are locked   |  |
| | [      Pick for Bot Carry - Talfin     (coral, 104 px)      ]  |   |
| +----------------------------------------------------------------+   |
+----------------------------------------------------------------------+
```
Draft complete (replaces the two text cards):
```text
+----------------------------------------------------------------------+
| Draft complete                                           [ ? ]       |  <- header 96
| +----------------------------------------------------------------+   |
| |  YOU                      VS                      THEM         |   |
| |  [img] Brixley   Top   Ottomere [img]                          |   |
| |  [img] Cindrel   Jg    Veshra   [img]                          |   |
| |  [img] Corvane   Mid   Embrel   [img]                          |   |
| |  [img] Dovrin    Bot   Sparrowe [img]                          |   |
| |  [img] Fennimore Sup   Vellgrim [img]                          |   |
| +----------------------------------------------------------------+   |
| +----------------------------------------------------------------+   |
| | COMPOSITION    You: Skirmish (+2.0%)    Them: Siege (+12.0%)   |   |
| | Net edge for you from the draft:  -10.0% (v)    <- one number  |   |
| +----------------------------------------------------------------+   |
| [ Game plan: Balanced  > ]                  (secondary, 96 px)       |
| [          Start the match      (coral, 112 px)            ]         |
+----------------------------------------------------------------------+
```

#### (c) Data and functions feeding each block
| Block | Source |
|---|---|
| Step segments, header | `draft.current()` (`team`, `kind`, `n`), `draft.order`, `draft.step`; timer `_time_left`, `_limit` (10 s short, 15 s full) as now |
| Board | `draft.picks[team]` (slot -> hero), `draft.bans[team]`, `draft.lineups[team][slot]` (player name for open slots), `App.world.heroes` for the silhouettes (drawn from hero id, role and archetype) |
| Needs strip | the existing `_needs_of(heroes)` and `Comp.evaluate(heroes)` (once 3 or more picks) |
| Role filter | `hero["role_primary"]`, `hero["role_secondary"]`; filled lanes from `draft.open_slots(my_side)` |
| Hero grid | `draft.avail`, the existing `scored` list (familiarity times `hero_fit`, or threat in the ban phase), `draft.meta[hid]` for the patch arrow (up if above 1.015, down if below 0.985, flat otherwise), archetype icon from `hero["archetype"]` |
| Coach bar | `draft.ai_choice()` (as now; the code name stays, the player-facing word is Coach) |
| Pick sheet | hero fields (`archetype`, `tags`, `damage_type`, `power_early/mid/late`, `difficulty`, `strong_vs`), `w.hero_fit(h, s)`, `w.familiarity(p, hid)` for each open lane; the best lane = highest familiarity times fit (the inline `best_slot` logic in `_actions`; move it to a `Draft` helper, NEW) |
| Confirm | `_apply({"hero": hid, "slot": s})` for a pick, `_apply({"hero": hid, "slot": ""})` for a ban; timeout still applies `draft.ai_choice()` |
| Auto-finish | `_auto_rest()` (`draft.finish_with_ai()`), now with an inline "Sure?" second tap |
| Draft complete | `draft.picks`, `draft.lineups`, `Comp.evaluate`; NEW one number "net edge from the draft for you" = my `ev["mod"]` minus their `ev["mod"]`, coloured from my point of view; the Game plan button label from `GamePlan.is_neutral(...)` as now; launch via `ScreenDraft.launch(game, draft)` |

#### (d) Interactions
- Tap a hero card: opens the sheet (size M, about 52 percent of the height) with hero details, "Plays as" (a 5-option segmented control, filled lanes locked, the best lane preselected so the common case is two taps: hero, confirm) and one big confirm button ("Pick for Bot Carry - Talfin", or "Ban Veshra" in the outlined `ban` variant: a `WARN` rim and a drawn warning icon on a `PANEL2` fill, never a pink, red or coral fill, ART-BIBLE 8.1 and 9.1; Pick is the coral go button). While the sheet is open the target lane on the board shows the hero as a ghost with the fit percentage.
- Ban phase: no lane control; the confirm button is "Ban Veshra".
- Tap "Take" on the coach bar: applies `ai_choice()` in one tap (this keeps the fast path for the 5-minute game).
- Tap a role in the filter: filters the grid; tap "All" to reset. No swipe gestures in the draft (a swipe would fight the scroll under a running timer).
- Long-press a hero card: peeks the same details as the sheet without the confirm button (a read-only sheet size S). Optional; a tap always gives the full sheet.
- Timer reaches 0: the Coach's choice is applied and a toast says so ("Time is up: Coach picked Veshra").
- Back or Android Back: closes the sheet first; with no sheet open it asks "Leave the draft?" in a size S confirm sheet (today it leaves silently).
- "Auto-finish": first tap changes the label to "Sure?" for 3 s; a second tap lets the Coach finish the draft. (While the tutorial's step 15 is up the armed state holds until tapped, `TUTORIAL.md` 3.2a.)

#### (e) Large text and colour-blind
- Large text: the grid stays 3 columns and the cards narrow to 183 px (every current hero name fits on one line at 26 px, up to 11 characters); the header title wraps to two lines (header 128); the board is always compact with 48 px rows; the sheet is size L (68 percent) so the lane control and the confirm button both fit.
- Colour-blind: banned = grey plus a large X (not just dimmed); picked = tick plus the side stripe; recommended = a star shape; patch strength = an up, down or flat arrow glyph plus its percent in the sheet; the timer is a ring plus digits plus "!" at 3 s; the side is the left or right column plus the word and flag glyph in the column header; the role filter uses icons and codes; the sheet's best lane is marked "best" in words.

#### (f) One primary decision
"This ban or this pick." The screen shows only that choice at any time; the board is context and the sheet is the commit.

---

### 6.4 Game Plan (`screen_game_plan.gd`, no tab bar; opened from Draft complete)

#### (a) Diagnosis (`11b_gameplan`, `11c_gameplan_trigger`)
- The page is a linear form about 2,600 px long (more than two screens): an intro paragraph, a "Where you stand" card of eight text lines (590 px), three tab-like buttons, then eight stacked control cards (seven sliders and the jungle row). The first control starts at y 985 (`11b`), so the player sets a control and cannot see the result: the "Expected edge" number is scrolled away.
- Each control is a card with five identical buttons labelled "--  -  0  +  ++" and one text line; the labels mean nothing until you read the line under them, which changes after you tap.
- The Default / If behind / If ahead choice looks identical to the control buttons below it, and "Plan on (tap to remove)" is another full-width button (`11c`).
- Hidden problem found in the code: the trigger plans only take effect from the mid-game on. `GamePlan.simulate` uses the Default plan's hooks for the four early contests and the chosen plan's hooks for the rest (`_hooked`, `choose`). So on the If behind and If ahead tabs, Lane aggression and Jungle focus have **no effect at all**, and the early half of Tempo, Fight style and Support is also ignored; the screen shows them as live. A player can spend taps on controls that do nothing.
- The page never uses the real structure of the game: eight contests in three phases (early lanes, mid objective and fight, late objective and fight).
- Touch size: control buttons 64 px (32 dp), plan buttons 72 to 76 px.

#### (b) New layout
```text
+----------------------------------------------------------------------+
| [<]  Game plan               [ Plan: Default v ]        [ ? ]        |  <- header 96
| +----------------------------------------------------------------+   |
| | EXPECTED EDGE                                    -31.5%        |   |  <- hero 128
| | You 47 [====teal===|=======coral=======] 53 Them               |   |
| | [Balanced -36.7%]  [This plan +5.1% (^)]                       |   |
| +----------------------------------------------------------------+   |
|   (Overall)---------(Early)---------(Mid)---------(Late)             |  <- timeline 128
|    2 controls       lead 2/4         lead 0/2      lead 0/2          |
| ===== EARLY GAME  (page changes when you tap a node or swipe) =====  |
| Where you stand                                                      |
| Top lane    -----|====+5.6      Mid lane   ====|-----  -20.7         |  <- 2x2 meters
| Bot lane    -----|=====+10.5    Jungle     ======|---  -43.5         |
| TEMPO                                              Balanced          |
| [o--------o--------(O)--------o--------o]      5 detents, 96 hit     |
|  Push early                              Scale late                  |
|  Balanced: no trade between lanes and the late game.   (live line)   |
| LANE AGGRESSION                                    Balanced          |
| [o--------o--------(O)--------o--------o]                            |
|  Cautious                                 Aggressive                 |
| SUPPORT                                            Balanced          |
| ... (Jungle focus: [None][Top][Mid][Bot] segmented)                  |
| [ Coach ] [ Reset ] [       START THE MATCH  (coral)        ]        |  <- footer 112
+----------------------------------------------------------------------+
```
Notes on the frame:
- **Edge hero (sticky, 128 px):** the expected edge as a 56 px number plus a "You | Them" bar, and two chips: "Balanced plan -36.7%" and "This plan +5.1%". It stays on screen while the controls change, so every tap has a visible result; the number counts up on each change. The text "Before luck: the draw and the dice can still change a single game" becomes the caption under the number (or in the "?" help).
- **Plan selector:** a chip "Plan: Default" in the header opens a bottom sheet with three radio rows (Default, If behind, If ahead). The two trigger rows have an On/Off switch (today's `_toggle_trigger`) and the sentence "Used from the mid-game on if you are clearly behind after the early game". Progressive disclosure: a first-time player sees one plan. When a trigger plan is on, the chip reads "If behind" etc. and a small dot appears on it.
- **PhaseStrip (128 px):** Overall, Early, Mid, Late. Each node shows how many of its contests you lead ("lead 2/4"), with an arrow glyph. Tap a node (or swipe the page left and right) to change the controls below.
- **Page content, one phase at a time:**
  - Overall: Fight style (`g`), Risk (`r`).
  - Early: "Where you stand" (Top, Mid, Bot, Jungle as four small EdgeMeters in a 2 x 2 grid), then Tempo (`t`), Lane aggression (`a`), Support (`s`), Jungle focus (segmented: None, Top, Mid, Bot).
  - Mid: "Where you stand" (Mid objective, Mid fight), then Mid-game objectives (`m`).
  - Late: "Where you stand" (Late objective, Decisive teamfight), then Late objectives (`l`).
- Each control is a DetentTrack: name + current word, a 5-stop track, two short end labels, and the live effect line from the existing strings. Each control also shows tiny phase pips ("moves: Early, Late") so the player sees which phases it touches (data: `data/game_plan_v0.json`, the `mod` and `var` maps per control).
- **Footer (112 px):** `[Coach]` (180 px), `[Reset]` (icon, 96) and **Start the match** (coral).
- **Coach** no longer overwrites the plan silently: it opens a sheet (size M) that lists the changes ("Tempo: balanced to scale", "Fight style: balanced to group up") and "Expected edge: -36.7% to -31.5%", with "Apply" (pinned). Apply is a normal change with an Undo toast.
- **Trigger plans (If behind / If ahead):** the Early node is locked (lock glyph, caption "uses your Default plan"); Lane aggression and Jungle focus are not shown; Tempo, Fight style and Support show their effect line with "only the late-game part applies in this plan". Mid and Late pages work as normal.

#### (c) Data and functions feeding each block
| Block | Source |
|---|---|
| Edge hero | `GamePlan.expected_final(_ta, _tb, p, {my_side: plan_set})` and the balanced version (exactly `_edge_preview` today); bar from team ratings |
| Node captions and EdgeMeters | `GamePlan.contest_ratings(_ta, _tb, MatchRunner.sim_params())` -> edge per contest as in `_standing()`; "lead n/m" counts contests with edge above 0 in that phase. Phases: Early = `GamePlan.EARLY` (top, mid_lane, bot, jungle); Mid = obj_mid, fight_mid; Late = obj_late, fight_late |
| Controls | `GamePlan.SLIDERS` (`g t m l a s r`), `GamePlan.STEPS`, `GamePlan.JUNGLE_CHOICES`, the plan dictionary from `App.gs.plan_set()`; existing strings `gp.c.<id>.name / neg / pos / balanced`; NEW short end labels (list in 7.4) |
| Phase pips per control | derived from `data/game_plan_v0.json` (`controls.<id>.mod` and `.var` keys mapped to phases) |
| Inert controls in trigger plans | `a` and `jf` have only early effects; `t`, `g`, `s` have mixed. Derived from the same JSON; no sim change |
| Coach | `GamePlan.suggest(_ta, _tb, p, my_side)` (as now), shown as a diff before applying |
| Plan selector | `plan_set()["default"]`, `["triggers"]`, `_toggle_trigger()` |
| Start | `App.autosave(); ScreenDraft.launch(game, draft)` unchanged |

#### (d) Interactions
- Tap or drag a stop on a track: sets the value (`_set_value`), recalculates the hero edge, haptic tick if enabled. Tap the "i" beside a control name: a size S help sheet with both effect lines (`neg` and `pos`) side by side.
- Tap a PhaseStrip node or swipe the page horizontally: changes the phase page (the strip and page stay in sync).
- Tap the Plan chip: plan selector sheet. Tap "Coach": preview sheet, then Apply. Tap "Reset": sets the current plan to neutral with an Undo toast.
- Back: returns to Draft complete (as now); the plan is saved on every change (as now).
- Long-press a control name: nothing extra. No gesture is the only way to do anything (the swipe has the node tap, the drag has the stop tap).

#### (e) Large text and colour-blind
- Large text: PhaseStrip nodes are a quarter of 578 px (144 px each; labels 26 px fit "Overall"); the plan chip shows the short name only; header title may wrap to two lines; the 2 x 2 EdgeMeters become a 1-column list of four rows of 56 px; each DetentTrack keeps its 96 px hit area and the end labels stay on one line each ("Spread out" and "Group up" fit); the page scrolls inside a region between the fixed hero/strip and the footer. The fixed parts (header 96 + hero 128 + strip 128 + footer 112 = 464 px) leave about 450 px of scroll area at 917 usable.
- Colour-blind: EdgeMeters are centre-zero (direction, not hue) with signed numbers; "lead 2/4" has an arrow; the detent thumb has a notch and the value is a word ("Balanced", "Scale late"); inert controls show a lock glyph and words; Coach diff uses "to" and signed numbers.

#### (f) One primary decision
"How do we want to play." One phase page and one control at a time; the edge hero is the feedback; Coach is the one-tap path for a player who does not want to decide; **Start the match** is the single coral action.

---

### 6.5 Standings (`screen_standings.gd`, tab "club")

#### (a) Diagnosis (`16_standings`, `16b_standings_form`, `17_standings_results`, `19b_trophies`)
- Five tabs in a wrapping strip: "Playoffs" breaks as "Playo / ffs" and "Trophies" as "Trophi / es" (`16`, `19b`), and the strip changes height from tab to tab (about 114 px in `16`, 74 px in `16b`).
- The table is a plain text grid in one card; your club is marked only by teal text (colour only). There are no badges, no podium, no sense of the playoff line (the top four qualify, `_start_playoffs`).
- "Form" is a second table of the same shape; "My games" is one line (`17`); "Trophies" is one card (`19b`). Half of each screen is empty, and none of them uses the space.
- The playoffs tab is a list of cards with text, although the structure is a bracket (two semi-finals into a final).
- The form column shows a bare "#5": a rank with no meaning to a new player.

#### (b) New layout (Table view)
```text
+----------------------------------------------------------------------+
| [<] Standings                                              [ ? ]     |  <- header 96
| [   Table   ] [  Playoffs  ] [  History  ]                           |  <- segmented 96
| LEAGUE TABLE                                [ Points | Form ]        |  <- header 88
|             .----------.                                             |
|             |  BADGE   |                                             |
|  .--------. | Emberfen | .--------.                                  |  <- podium 300
|  | BADGE  | |  Hounds  | | BADGE  |                                  |
|  | Mossg. | |  3 pts   | | Stormv.|                                  |
|  | 3 pts  | +----------+ | 3 pts  |                                  |
|  +--------+ |    1     | +--------+                                  |
|  |   2    | |          | |   3    |                                  |
|  +--------+ +----------+ +--------+                                  |
| 4  (b) Thornwick Stags                         3 pts   1-0           |  <- rows 104
| - - - - - - - - - -  PLAYOFF LINE (top 4)  - - - - - - - - - - -     |
| 5  (b) Saltmarrow Gulls                        3 pts   1-0           |
| 6  (b) Ironquill Wolves                        0 pts   0-1           |
| 7  (b) Duskwater Foxes                         0 pts   0-1           |
| 8  (b) Gildmoor Raiders                        0 pts   0-1           |
| 9  (b) Northreach Corsairs  [YOU]              0 pts   0-1           |  <- own row
| 10 (b) Pinehollow Owls                         0 pts   0-1           |
| +----------------------------------------------------------------+   |
| | 9  (b) Northreach Corsairs [YOU]   1 win and 3 pts to the line |   |  <- pinned row
| +----------------------------------------------------------------+   |
| [ Home ][ Squad ][ Plan ][ Club ][ More ]                            |
+----------------------------------------------------------------------+
```
- **Three views, not five** (Table, Playoffs, History): Form becomes a switch in the Table header ("Points | Form" changes the number on the right of each row and re-sorts); Trophies and My games merge into History. Three labels fit in large text (192 px per option at 578 px) and never wrap in a word.
- **Podium** for the top three (2nd, 1st, 3rd): badges, short names, points; pedestal heights show the order.
- **Rows 4 to 10** use RankRow (104 px high, 56 px badge, ART-BIBLE 8.2). A dashed **playoff line** after rank 4 (the top four qualify). Your row has a PANEL3 fill, an 8 px accent bar and a "YOU" pill (text, so it works without colour).
- **Pinned row:** when your row is scrolled out of view, a 96 px row pinned above the tab bar shows your rank, club and one sentence about the line ("1 win and 3 pts to the line", or "Safe: 5 pts clear of 5th"). It disappears when your own row is on screen.

Playoffs view (a drawn bracket):
```text
+----------------------------------------------------------------------+
| [<] Standings                                              [ ? ]     |
| [   Table   ] [  Playoffs  ] [  History  ]                           |
| CUT LINE: top 4 go through.  You are 9th, 3 points behind.           |  <- status line
| SEMI-FINALS  (best of 3)                                             |
| +----------------------------+     +----------------------------+    |
| | (b) 1 Emberfen Hounds    2 |     | (b) 2 Mossgate Wardens   1 |    |
| | (b) 4 Thornwick Stags    0 |     | (b) 3 Stormvale Herons   2 |    |
| | pips: (x)(x)( )            |     | pips: (x)( )(x)            |    |
| +-------------+--------------+     +-------------+--------------+    |
|               |                                  |                   |
|               +----------------+-----------------+                   |
|                                |                                     |
| +--------------------------------------------------------------+     |
| | GRAND FINAL (best of 5)                                       |    |
| | (b) Emberfen Hounds      0     vs     0     Stormvale Herons  |    |
| | winner of SF1                          winner of SF2          |    |
| +--------------------------------------------------------------+     |
| your series: accent bar + YOU pill; finished: tick on the winner     |
+----------------------------------------------------------------------+
```
- Before the playoffs start it shows the projected bracket from the current top four in a ghost style (dashed outline) and the cut-line sentence. During the playoffs, series cards show wins as pips and a tick on the winner; your series card has the accent bar and the YOU pill. After the final, the champion gets a crown.

History view (replaces My games and Trophies):
- A trophy shelf: one slot per finished season (gold cup for champion, silver for runner-up, bronze for finalist, an empty slot for "missed"), horizontally scrolling, with the totals as chips (Titles, Finals, Playoffs, Prize money).
- Below, "Recent games" (the last 40 are kept): one card per game: result pill with the letter W or L, opponent badge and name, round, margin word, a three-dot mini story strip (early, mid, late). Tap a card: a sheet (size M) with the story strip and the draft recap from the stored game (`picks`, `bans`, `comp`, `style`, `lineups`, `contests`, `phases` are all saved in `d["history"]`).
- Empty state when no games are played: illustration, "No games yet", "Your first result will show up here", button "Go to Home".

#### (c) Data and functions feeding each block
| Block | Source |
|---|---|
| Podium, rows | `gs.standings()` (rank, `club`, `w`, `l`, `pts`, `margin`), `gs.club_name`, badges by club id |
| Form metric | `gs.form_ranking()` (`rank`, `rating`), toggled in place |
| Playoff line, pinned sentence | rank 4 cut from `_start_playoffs` (top four); gap = `pts` of rank 4 minus your `pts` (NEW tiny helper `GameState.cut_gap()` returns the points gap and games left) |
| Bracket | `gs.d["playoffs"]["series"]` (`id` SF1, SF2, F; `a`, `b`, `wins_a`, `wins_b`, `best_of`, `done`, `winner`), `["seeds"]`; before the playoffs: top four of `standings()` |
| History list | `gs.d["history"]` (last 40 games, newest first); `won`, `blue`, `red`, `round`, `final` (margin word via `Report.result_word`), `phases` |
| Trophy shelf | `gs.d["seasons_done"]` (`season`, `rank`, `w`, `l`, `result`, `prize`) with the existing `RESULT_KEYS` |

#### (d) Interactions
- Tap a view in the segmented control: switches (in place; the scroll position resets to the top).
- Tap "Points | Form": changes the metric and re-sorts with a 200 ms row move (instant when animations are off).
- Tap a row or a podium column: a sheet (size S) with the club's badge, record, Form rating and rank, last result against you and "Their best lineup rating" (read-only).
- Tap a bracket card: the same club sheet for each side; tap a trophy slot: a sheet with the season's line (rank, record, result, prize).
- Swipe the trophy shelf sideways. No other gestures.
- Back: to the Club tab (as now).

#### (e) Large text and colour-blind
- Large text: three views fit in one row; podium columns are 192 px with club names on two lines (26 px, not truncated); RankRow names wrap to two lines and the caption (record) moves under the points; the pinned row wraps to two lines (row 128). The table needs scrolling in every mode (10 rows of 104 px plus the podium is more than 917 px), which is why the pinned row exists.
- Colour-blind: own row = fill + accent bar + "YOU" pill; podium = numerals and medal shapes; playoff line = dashed line with a text label; bracket winners = tick; wins = pips with a filled shape; Form vs Points uses the same layout, no colour code.

#### (f) One primary decision
There is none: Standings is a read-only screen. Its single job is to answer "where do I stand and what do I need" (the pinned sentence). I deliberately add no coral button here; Play stays on Home.

---

### 6.6 Match Report (`screen_report.gd`, no tab bar)

#### (a) Diagnosis (`14_report_top`, `15_report_mid`, `15b_report_lines`)
- The result card is good but alone: "Defeat" in 64 px, club names, a margin line. There is no score, so the headline has no number.
- A long stack of same-style blocks: standout, a nine-row changes table, tip, a tutorial card ("After every game"), Continue, then the expanded "Why it went this way" with seven bars, then three collapsed sections. The Continue button first appears after about one and a half screens of scrolling (`15`) and appears twice (the second at the very bottom).
- The story of the game (what happened early, mid, late) exists only inside a collapsed list of timestamped lines ("02:25 Top lane: they win it (clearly)"); the player never sees the shape of the match.
- The biggest bar is "Luck of the game -53%" (`15`), and the line above it, "Biggest problem: Luck of the game", is the headline of the explanation. A loss that is mostly luck is honest, but it is not framed; it reads like an excuse.
- "Standout: Talfin ... decided 10% of the result" is a sentence with nothing to look at.
- Expanders use "+ " and "- " text prefixes (`15b`), not an icon.
- Touch size: expander headers are 70 px.

#### (b) New layout
```text
+----------------------------------------------------------------------+
| [<] Match report                                          [ ? ]      |  <- header 96
| +----------------------------------------------------------------+   |
| |  Defeat                              (display 64, with a shape)|   |  <- hero ~300
| |  (BADGE)     15  -  24     (BADGE)        team kills, display  |   |
| |  Northreach Corsairs  vs  Mossgate Wardens                     |   |
| |  A decisive result - 13:30         Best of 3:  (x)( )( )       |   |
| +----------------------------------------------------------------+   |
| THE STORY    "They won every phase"                                  |  <- tag 56
| (-)  EARLY   [ TOP x ][ MID x ][ BOT ok ][ JUNGLE x ]                |  <- band 112
|  |                                                                   |
| (-)  MID     [ OBJECTIVE x ]      [ FIGHT x ]                        |  <- band 112
|  |                                                                   |
| (-)  LATE    [ OBJECTIVE x ]      [ FIGHT x ]                        |  <- band 112
|      tap a band: the moments with clock times                        |
| +----------------------------------------------------------------+   |
| | 53%   of the result was luck                 (display 64)      |   |  <- hero stat 180
| | A swingy game: a better plan would not have changed much.      |   |
| | Best: Bot lane +10%   Worst: Draft -16%      [ all factors > ] |   |
| +----------------------------------------------------------------+   |
| WHAT THIS GAME CHANGED                                               |  <- 240
| ( av )Soldor ( av )Yorric ( av )Caeldor ( av )Talfin ( av )Lummir    |
| form -1.4     form -1.4   form -1.4     form -1.4    form -1.4       |
| morale -2     morale -2   morale -1     morale -1    morale -2       |
| [Bonds 34 (^)] [Chemistry +1.0%] [Cash +8 (^)]                       |
| BEFORE THE NEXT GAME   10 contracts end this season.   [ Open squad ]|
| DIG DEEPER  v        [ Players | Moments | Draft ]                   |
| [          Continue   (coral, sticky footer 112 px)          ]       |
+----------------------------------------------------------------------+
```
Notes on the frame:
- **Result hero (about 300 px):** the result word at display size with a shape (a flag for victory, a broken flag for defeat) so it is not colour alone; a **score line** (team kills, 64 px) between the two badges. The score is `Report.kda(res)` summed per team: it is display-only data that the sim already guarantees consistent (the winner always has more kills, one side's kills are the other's deaths). Under it: the margin word (`Report.result_word`), game length, and the series pips for playoff games.
- **The story (about 360 px):** a vertical timeline of three bands (Early, Mid, Late). Each band has a node tinted by the phase result (`res["sim"]["early"|"mid"|"late"]`, signed) with a plus or minus glyph, and chips for the phase's contests (Early: Top, Mid, Bot, Jungle; Mid: Objective, Fight; Late: Objective, Fight), each with a tick or cross; the margin word (narrow, clear, decisive) is shown as 1 to 3 dots on the chip and in words in the sheet. A one-line **story tag** above the strip names the shape ("Led early, lost the late fights", "Comeback"), chosen from the sign pattern of the three phases (a table of eight patterns; Narrative writes the words).
- **Hero stat (about 180 px):** one big number and one sentence: the single biggest factor in `Report.attribution`, by absolute share. If that is luck, the sentence says so plainly ("53% of this result was luck. A swingy game: a better plan would not have changed much."). Two chips: best factor and worst factor. **Tap the hero stat** (or its "all factors" link) to open a size-L sheet with the full factor bars (today's "Why" content), so the answer to "why" is one tap from the hero.
- **What this game changed (about 240 px):** the five starters as avatar chips in a wrapping row, each with form and morale deltas (signed numbers, arrow glyph), then three stat tiles (Bonds average, Chemistry, Cash). Replaces the nine-row table.
- **Tip card:** "Before the next game" with an optional single action link (for the tip about tired players: "Open squad"; contracts: "Open squad").
- **Dig deeper (collapsed):** a chevron expander that opens a segmented control (Players, Moments, Draft). Players = the kills, deaths and assists lines; Moments = the timestamped feed; Draft = the recap. One at a time instead of four stacked accordions.
- **Continue** is a sticky footer (112 px, coral), always visible; the duplicate at the bottom is removed. The tutorial card ("After every game") is gone from the layout (W1 coach overlay).
- **Reveal sequence** (about 2 s, tap anywhere to skip, instant with animations off): result word fades in (250 ms), score counts up, story strip nodes fill from left to right, hero stat counts up, then the changes appear. This is the payoff moment the UI reference asks for (P9).
- **Practice games:** the same hero and story strip, the practice card instead of "What this game changed", no tip. **Playoff games:** series pips in the hero.

#### (c) Data and functions feeding each block
| Block | Source |
|---|---|
| Result, margin, length | `res["blue_won"]`, `Report.result_word(float(res["final"]))`, `Report.game_minutes(res)` |
| Score line | NEW `Report.team_kills(res)` = sum of `Report.kda(res)[side][slot]["k"]` per side |
| Story bands | `Report.feed(res, my_side)` (8 events: `key`, `mine`, `size`, `value`, `t`), grouped by `Report.FEED_ORDER` into early (4), mid (2), late (2); phase verdict from `res["sim"]["early"]`, `["mid"]`, `["late"]` signed by side |
| Story tag | NEW rule table over the three phase signs; copy from Narrative |
| Hero stat | `Report.attribution(res, my_side)["factors"]` (`id`, `value`, `share`); best and worst by sign |
| Standout player | the existing `_standout` logic (slot factor, `res["lineups"]`, `res["picks"]`), shown as an avatar chip in the changes row |
| What changed | `App.last_payoff` (`Payoff.compare`): `rows`, `bond_a/b`, `chem_a/b`, `cash_d` |
| Tip | `Payoff.tip(App.gs)` (`key`, `args`); the action link maps `tip.rest` and `tip.contract` to Squad, `tip.scrim` to Plan |
| Dig deeper | existing `_lines`, `_moments`, `_draft_recap` content, one per segment (Players, Moments, Draft); the `_why` factor bars live in the hero-stat sheet |
| Continue | existing `_leave()` |

#### (d) Interactions
- Tap anywhere during the reveal: jumps to the final state. Tap a story band: sheet (size M) with that phase's lines with their clock times (the `_moments` lines for that phase) and the contests' margin words.
- Tap the hero stat: sheet (size S) that explains the number in plain words (the existing `report.why_note`, "from replaying the game without it").
- Tap a starter chip: sheet (size S) with that player's lines (K/D/A for this game, form and morale change) and "Open in Squad".
- Tap the hero stat: size-L sheet with the factor bars (Why). Tap "Dig deeper": expands; tap a segment (Players, Moments, Draft) to switch content.
- Tap the tip link: goes to the named place (confirm if leaving would lose nothing: the report is saved, so no confirm needed).
- Back = Continue (as now). No swipes.

#### (e) Large text and colour-blind
- Large text: the early band's four chips wrap to 2 x 2 (four chips of 160 px do not fit in the 498 px beside the node); the five starter chips reflow 3 + 2; stat tiles become a 1-column stack; the score line stays 64 px on one line (it is two numbers); Continue stays pinned. In normal text hero (300) + tag (56) + story (360) + hero stat (180) + header (96) + gaps is about 1,040 px, inside the 1,096 px left above the sticky footer; in large text the hero stat is one scroll below, which is acceptable because the hero already shows the result.
- Colour-blind: result word has a flag shape and the word; contests use tick and cross glyphs with a count of dots (1 to 3) and the margin word in the sheet; phase verdicts have plus and minus glyphs; deltas are signed numbers with arrows; hero stat is a number and words.

#### (f) One primary decision
"Continue." The page is a reward and an explanation; the only thing to do is to move on. The tip's action link is secondary and optional.

---

### 6.7 Match screen HUD (arena, Alpha 0.8)

Added in the wave 1b revision (review conflict C9: nobody owned this HUD, and the sources do not fit on one phone screen). **Nothing here was built or run.** Text widths in 6.7.1 are measured with the real Barlow Semi Condensed files outside Godot (the Producer's measurement; I re-ran the longest label, the longest tag and the worst pair and got the same numbers), and the font has never been loaded in Godot. I read `ARENA-MAP.md`, `ACTION-VOCABULARY.md` (sections 1.4, 2.4, 4, 5), `ESPORTS-NOTES.md` (2.4, 4), `game/i18n/en.json` (the `feed.*` and `match.*` strings) and the art bible tokens. I did not edit any of them. Section 6.7.1 now records the **Producer's ruling on each proposal** (review wave 1b, 4.3), and the Gameplay Designer's pass 1c in `ACTION-VOCABULARY.md` already carries the accepted ones (the 4-word `gp.switch.short.<id>` banner, labels hidden at x2, the `intent_ping` ring without a line, the short feed form, an "If behind" chip that says only that, the loss tone as an edge vignette plus the `BAD` Defeat glyph on the end card only).

**Which release.** **Alpha 0.7 keeps today's match screen** with the 75 s watch (feed list, bar, Speed x1 / x2, Skip to the end, See the report). It only gets the global changes (new tokens, 96 px buttons, the "?" in the standard top-right corner, the ids `match.controls` and `match.report_btn`). **Alpha 0.8 replaces it with the arena** (`ARENA-MAP.md`: a 720 x 760 arena between a scoreboard strip and a text strip), and everything below is the HUD around that arena. The result, the length and every number are decided before the show starts; the HUD is playback only and never changes them (ACTION-VOCABULARY H1 to H6).

#### 6.7.1 Diagnosis and rulings: what the sources ask for against the room

**Rulings (Producer, review wave 1b 4.3):** P1 accepted. **P2 rejected: label limit stays 28 and tag limit 24.** P3, P4, P6, P7, P8, P9, P10, P11, P12, P13 accepted as written. **P5 not accepted: the mid push window stays at 46.0 s;** the scheduler may drop that pill, or Gameplay deletes it.

| Source asks for | Room | Ruling and what changes |
|---|---|---|
| Scoreboard 190 px (ARENA-MAP 4) with clock, kills, towers, two objectives, gold lead, lead graph (ACTION-VOCABULARY 5), plus two banners, a phase chip and a status tag | The 190 px starts at the top of the screen, so it **includes the 48 px status bar and notch**: 142 px of content. Three rows (44 + 46 + 44) fit, four do not | **Does not fit as listed.** Cuts: the two objectives become **markers on the lead graph** at their beats (a stone glyph and a moon glyph in the owner's shape), not a separate row; the gold lead sits beside the clock; banners show the badge and the club's last word (at most 8 characters: "Corsairs", "Wardens"; **P10 accepted**, the longest last word in `clubs.json` is 8), not the full name |
| Text strip 150 px under the arena (ARENA-MAP 4, "my assumption, for UI/UX to confirm") with an intent pill per side, a plan chip, an "If behind" chip, a 3-line feed, a commentary line, banners | Plan row 44 + gap 8 + intent row 48 + gap 8 + feed block 80 + bottom 10 = **198 px**, not 150 | **P1 accepted.** Text strip **198**, controls strip **132** (12 gap + 96 button + 24 bottom margin). The sums: 44 + 8 + 48 + 8 + 80 + 10 = 198 and 12 + 96 + 24 = 132. The arena stays 720 x 760 at y 190 to 950 and the scoreboard stays 190, so no arena redraw. Level Designer edits ARENA-MAP 4, `layout_px` (`feed_y` [950, 1148], `controls_y` [1148, 1280]) and the preview (B1) |
| Intent label up to 28 characters per side, both shown (R3); 26 characters is the longest | Two pills side by side on a 672 px row (578 in large text). **Measured** with Barlow Semi Condensed SemiBold 24 px: longest label 239 px ("Fight now, objective later", 26 characters); a pair with 52 px of padding per pill (side glyph 16, gap 8, 14 either side: the figure the measurement used) and a 16 px gap is at most 599 of 672 px | **P2 rejected: no shortening.** Label limit stays 28 (ACTION-VOCABULARY R1). **Both coaches' labels are shown.** At normal size 0 of 19,881 label pairs overflow; in large text (578 px) 49 (0.25 percent) do, which the rule "if the pair does not fit, show only yours" already covers. The font has not been loaded in Godot (test 4 checks it there) |
| `intent_ping`: "a ring on the target zone with a line to the label" (2.5 s) | The label is 200 to 760 px below the zone; the line would cross the arena | **P6 accepted: the ring only, no line** (ACTION-VOCABULARY 3.2 and R3 say so). A circle ring for your label, a hexagon ring for theirs (the same shape as the pill's glyph), so the eye links them without a line |
| Status tags up to 24 characters ("Still level, still tense"), "centre status tag" | Scoreboard centre slot is 348 px (280 in large text). **Measured:** the longest tag is 234 px ("Nobody saw that coming", 22 characters). With a 32 px side glyph (the bible's inline icon size, 6.1) that is 266 of 348 px, and 266 of 280 in large text, 14 px to spare | **P2 rejected: tag limit stays 24.** Fits at both sizes. The 266 is the Producer's 274 (which used a 40 px glyph) with the 32 px glyph: my arithmetic, not a new measurement. Large text is the first place to break if the font loads wider in Godot |
| Plan chip with up to 3 parts, "If behind" chip with its top 2 parts (ACTION-VOCABULARY 4.2) | Chip row 672 px (578 in large text) | **P12 accepted.** The "If behind" chip says only "If behind"; its parts open in a read-only size S sheet on tap. The plan chip is the only chip with parts: at most 3, it drops its last part until it fits the row, never an ellipsis (ACTION-VOCABULARY 4.2 says the same) |
| Esports: commentary line plus a 3-line feed | Feed block holds 2 lines at 26 px (80 px); 1 line in large text | **P13 accepted: 2 lines.** The second line is the previous result, or a commentary line in a calm gap, never both. ARENA-MAP 4 and the preview change (Level Designer, B1 and B4) |
| Feed line text = the Report's feed text, "identical" (ACTION-VOCABULARY 1.2): "02:25  Top lane: they win it (narrowly)" is 7 words | The four lane results arrive 2.25 s apart (13.5, 15.75, 18.0, 20.25). Two 7-word lines are 14 words in 2.5 s, against a budget of about 10 | **P8 accepted: the short feed form.** The arena shows "Top lane: they win it" (5 words: `feed.line.short` with `feed.win.short` and `feed.loss.short`; no clock stamp because the scoreboard shows the clock; the size as 1 to 3 dots plus the tick or cross icon). Same event, order and stamp as the Report, which keeps its full line (ACTION-VOCABULARY 1.2 and test 9 now read this way). Systems adds the three strings, Narrative sets one contest name set |
| `kill_ping`: killer flash, **"+gold" text**, skull mark (ACTION-VOCABULARY 3.2) | About 20 to 30 kills in 75 s, mostly in two fights | **P7 accepted: no "+gold" text.** The ledger has no per-hero gold (section 2.5 of the vocabulary), and floating text over 40 px tokens cannot meet the 24 px floor in a fight. The skull mark stays |
| Plan switch banner uses the existing `gp.switch.<id>` text, 13 words ("Early game over: you are behind, switching to your 'if behind' plan.") | A 2 s banner (ACTION-VOCABULARY plan_check) at 21.0 s, 0.75 s after the jungle result | **P3 accepted:** the arena shows a short form of at most **4 words**, `gp.switch.short.<id>` (for example "Switching to If behind"), in the amber `WARN` banner; the long `gp.switch.<id>` line stays in the Report and help. Gameplay edits `plan_check` (done in pass 1c); Narrative writes the five strings |
| Map labels 20 px bold (ARENA-MAP 9) | Floor is 24 px | **P9 accepted (with B4 and A9):** 24 px Bold, +1.5 px tracking, `TEXT` with a **5 px `VOID` outline** (ART-BIBLE 3.9; the 3 px I first proposed is replaced). The Level Designer adds a label-overlap check with the widths of ART-BIBLE 5.2 (STONEBACK 128, MOONHULK 118, MOSSBACK 116, TOP 41, MID 37, BOT 42 px) and puts STONEBACK above or left of its icon. The validator checks icon overlap only. In large text the zone labels are hidden (6.7.7) |
| Intent windows are 2.5 s, 1.25 s at x2 (R3) | A 4-word label needs about 2 s to read at the Esports rate of 2 words a second | **P4 accepted:** at Speed x2 both intent labels are hidden (ACTION-VOCABULARY R3 and test 6); feed lines and tags stay. The windows are not re-timed |
| Four pill windows start within 1.5 s of a feed line: jungle 12.5 (1.0 s before the 13.5 lane line), plan check 21.2, mid push 46.0 and close 71.5 (0.95, 1.0 and 0.25 s after a line) | The scheduler (6.7.4) decides, pill by pill | **P5 not accepted: the mid push window stays at 46.0 s** (both mid-push tower falls are at 46.0 and 47.2 s, so a "Pushing the tower" label at 47.5 s would trail its own event; the commentary slot at 47.5 to 49.0 s is also kept, which settles B15: the model shows that a pill moved to 47.5 s would leave only 3 of the 4 commentary slots). Model result (6.7.4): in a game with no wipe the jungle and plan-check pills keep only your label and the mid push and close pills are dropped; when the mid fight is a wipe the mid push pill survives as yours only. **Recommendation to Gameplay (it decides): delete `push_tower` and `push_dive`**, because they are dropped in most games and the tower falls still show on the scoreboard count |

#### 6.7.2 Layout

Vertical stack at 720 x 1280 (the design case). The arena is fixed; the strips give way.

| Strip | y from | y to | Height | Holds |
|---|---|---|---|---|
| Safe area | 0 | 48 | 48 | nothing drawn (status bar, notch; use the display's real safe area where reported) |
| Scoreboard | 48 | 190 | 142 | row A 44, row B 46, row C 44, gaps 4 + 4 |
| Arena | 190 | 950 | 760 | `ARENA-MAP.md`, 720 wide, not interactive |
| Text strip | 950 | 1148 | 198 | plan row 44, gap 8, intent row 48, gap 8, feed block 80, bottom 10 |
| Controls | 1148 | 1280 | 132 | 12 gap, buttons 96, 24 bottom margin |

```text
+----------------------------------------------------------------------+
| status bar and notch: 48 px, nothing drawn                           |  <- safe 0-48
| (b) CORSAIRS         04:57   (o) +1,500          WARDENS (b)         |  <- A 44
| [K] 7   [T] 3          [ Mid ]  or a tag         [K] 5   [T] 1       |  <- B 46
| lead graph ~~~/\___~~~(S)~~~~~~~~~~~~~~(M)~~~~~~~~~~~~~~~~~~~~~      |  <- C 44
+----------------------------------------------------------------------+  y 190
|                                                                      |
|        ARENA  720 x 760   (docs/design/ARENA-MAP.md)                 |
|        your units: circles, at the bottom. theirs: hexagons.         |
|        no text here except 24 px zone labels (6.7.1)                 |
|        not interactive in 0.8: no taps on the map                    |
|                                                                      |
+----------------------------------------------------------------------+  y 950
| plan:  [ Group up, Contest them ]  [ If behind ]                     |  <- plan row 44
| (o) Going for Stoneback              Chip them from range (h)        |  <- intent row 48
| ok  Top lane: you win it  ..                                         |
|  x  Mid lane: they win it  .   (previous line, dim)                  |  <- feed block 80
+----------------------------------------------------------------------+  y 1148
| [ Speed x1 ]  [    Skip to the end    ]            [ ? ]             |  <- controls 132
+----------------------------------------------------------------------+  y 1280
 key: (b) badge 40 px   (o) circle glyph = you   (h) hexagon glyph = them
      [K] kills glyph  [T] towers glyph  (S) stone glyph  (M) moon glyph
      ok / x = tick and cross shapes   . / .. / ... = margin dots 1 to 3
 The frame shows a busy moment on purpose: both pills and two feed lines.
 The budget (6.7.4) allows it only because the feed lines are over 2.5 s old.
```

The same wireframe in words:

- **Row A (44 px):** left banner (badge 40, last word of the club name at 26 px), centre (clock 32 px and the gold lead 32 px with the leader's shape glyph and a sign: "(o) +1,500" means you lead), right banner mirrored. You are always left, them right, and the player's base is always at the bottom of the arena (ARENA-MAP 4).
- **Row B (46 px):** left: kills and towers with glyphs, numbers 32 px; right: the same for them; **centre slot 348 px: the phase chip ("Early", "Mid", "Late", 24 px) or, for 2.0 s, the status tag** (glyph plus up to 24 characters, 24 px; the longest tag line is 234 px, 266 px with a 32 px glyph, in a 348 px slot).
- **Row C (44 px):** the lead graph, a 20 px band across 672 px (time on x, the lead ladder of ACTION-VOCABULARY F4 on y, centre line = even, above = you), with 8 beat markers, the two **objective markers** (stone at 45 percent of the width, moon at 80 percent: an empty outline before the beat, the owner's shape glyph after it) and two ticks at the phase borders (24.0 s and 51.0 s). Markers are 28 px glyphs straddling the band. No text on the graph.
- **Plan row (44 px):** the plan chip ("Group up, Contest them", the first two or three parts) and the "If behind" chip (it says only "If behind", P12; dim until the plan check at 21.0 s, lit after it if that plan is in force). Both are static: they fade in at 3.0 s, after the opening labels, so the first 2.5 s are not overloaded. A tap on either opens a read-only size S sheet with the whole plan (the show pauses while it is open). No plan chip for the opponent exists (ACTION-VOCABULARY R7, request S1).
- **Intent row (48 px):** your label left with a circle glyph, theirs right with a hexagon glyph, each a pill of at most 28 characters at 24 px (P2: no shortening). If the pair does not fit its row (672 px, 578 in large text), only yours shows.
- **Feed block (80 px):** line 1 is the newest result, line 2 is the previous result (dim) or, in a calm gap, a commentary line. A banner takes over both lines.
- **Controls (132 px):** Speed, Skip, "?" (6.7.6).

#### 6.7.3 What is in the scoreboard strip (ACTION-VOCABULARY section 5)

| Item | Where | Size | Source and rule |
|---|---|---|---|
| Clock | row A centre | 32 px, tabular figures | `show_time / 75 * Report.game_minutes(res) * 60` (1.4), so the report's stamps read the same |
| Gold lead | row A centre, right of the clock | 32 px, glyph and sign | F7; the leader's shape glyph, never colour alone; "+0" shows no glyph |
| Kills per side | row B, outer left and right | 32 px, glyph | F10: `Report.kda(res)` team kills; never recomputed |
| Towers per side | row B, next to kills | 32 px, glyph | F8, 0 to 6; the two guard towers are scenery and never counted (C5) |
| Objectives (Stoneback, Moonhulk) | row C, on the graph | 28 px glyph | F12: the sign of `obj_mid` and `obj_late`; the owner's shape (circle or hexagon) over the stone or moon glyph |
| Lead graph | row C | 20 px band | F4 ladder, one marker per beat; a flip (F5) pops a diamond marker; the gold number also flashes (`lead_flash`) |
| Phase chip | row B centre | 24 px | Early until 24.0 s, Mid from 24.0, Late from 51.0 (the Report's three bands; 6.7.5) |
| Status tag | row B centre, 2.0 s | 24 px, at most 24 characters | `tag_flip`, `tag_back`, `tag_upset`, `tag_snow`, `tag_close` (2.4); replaces the phase chip meanwhile |
| Banners (club) | row A | badge 40, last word 26 px | `Corsairs`, `Wardens`: the longest last word in `clubs.json` is 8 characters; a data check flags a longer one |

#### 6.7.4 The text budget: how many text channels at once

**The answer in one line.** At most **3 transient text items visible at once** (a pair of intent labels counts as one item, the status tag is one, the feed block is one), plus the static plan row; a banner leaves **one**. And at most **10 new words in any 2.5 seconds**. Every text is 24 px or larger (feed lines 26, banners 26 or 32). Static numbers (clock, kills, towers, gold lead, graph, phase chip) do not count: they are glanced, not read.

The 10 words is the Esports Manager's own unmeasured estimate (ESPORTS-NOTES 2.4: about 2 words a second, about 10 new words in 2.5 s). I keep it as the test number; if a tester session shows a different reading speed, change the one constant.

| # | Channel | Where | Max at once (normal / large text) | Time on screen | Size | Rule when it cannot show |
|---|---|---|---|---|---|---|
| 1 | Plan chip | plan row, left | 1 / 1 (two parts) | whole show from 3.0 s | 24 | never dropped; loses its last part until it fits |
| 2 | "If behind" chip | plan row, right | 1 / 1 | whole show, dim until 21.0 s | 24 | never dropped |
| 3 | Intent label, yours | intent row, left | 1 / 1 | 2.5 s (hidden at x2) | 24 | dropped if the word budget is full |
| 4 | Intent label, theirs | intent row, right | 1 / 0 | 2.5 s (hidden at x2) | 24 | dropped if the budget is full, if the pair does not fit 672 px, always in large text |
| 5 | Centre status tag | row B centre | 1 / 1 | 2.0 s | 24 | dropped if the budget is full; the graph marker and gold flash still show the event |
| 6 | Feed line | feed block, line 1 | 1 new (+1 previous, dim) / 1 | newest 4 s | 26 | **never dropped**: it is the sim's result; a banner holds it and it returns |
| 7 | Commentary line | feed block, line 2 | 1 / 0 | 2.5 s | 24 | only in a calm gap; at most 2 per game (6.7.4 below) |
| 8 | Banner | feed block, both lines (hides the intent row) | 1 / 1 | plan switch 2.0 s; wipe 2.0 s; end card stays | 26, end card 32 | wins over everything below it |

**Admission order** (highest first): banner, feed line, status tag, intent pair, intent (yours only), commentary. The scheduler never delays and never shrinks text: it admits an item if no 2.5 s window then holds more than 10 new words, otherwise it drops it. A wipe banner ("Team wiped", 2 words) **replaces** the feed line of that beat (the Report's Moments list still has the full line). Both limits are one function of the show script, so QA can test it without a phone.

**What the model says** (re-run in pass 1c with a saved script, `docs/design/ui/hud_budget.py` (the Producer copies it into the repo; I was told to edit only two files): it counts the new words that start inside any 2.5 s span and applies the admission order above; the earlier script was not saved. Assumptions, not measurements on a phone: 15 label windows from ACTION-VOCABULARY 4.1, feed stamps from 1.4, a pair of labels averages 6.9 words (the 156 labels average 3.47: 11 are 2 words, 66 are 3, 75 are 4, 3 are 5 and 1 is 6; a yours-only label is 3.45), a feed line 5 words in the short form (7 in the long form), a status tag 3 words offered at the 8 stamps and at 62.0 s, a short banner 4 words (counted when the scheduler runs, not in the unmanaged case), a wipe banner 2 words that replaces the feed line of its beat, a commentary line 8 words):

| Case | Result |
|---|---|
| Unmanaged: both labels in all 15 windows, 7-word feed lines (clock and size word), a tag at every stamp, a 7-word commentary line 1.0 s after each stamp | More than 10 new words in **73 of 291** quarter-second span starts; the worst span has **30.9 words** (at 19.0 s). Items on screen at once are not counted here; by hand it is up to 7. (The earlier figures, 142 of 291 and 34 words, came from the unsaved script and are not reproduced by the saved one; they are replaced.) |
| Same, with 7-word feed lines **under the scheduler** | nothing else is admitted at all: the lane stamps (2.25 s apart) already use 14 words in 2.5 s. This is why the feed needs the 5-word short form |
| Scheduler, 5-word feed lines, no plan switch, no wipe | **at most 3 items at once** (by construction: pair, tag, feed block); both labels shown in **11** of 15 windows, yours only in **2** (jungle 12.5 and plan check 21.2), none in **2** (mid push 46.0 and close 71.5, because a feed line lands 1.0 and 0.25 s before them); 4 of the 9 possible tag slots keep their text (the others rely on the graph marker and the gold flash) |
| Scheduler, 5-word feed lines, plan switch and two wipes (worst case) | at most 3 items at once; labels both in **11**, yours only in **3** (jungle 12.5, mid push 46.0, close 71.5), none in **1** (plan check 21.2, which the plan-switch banner covers anyway). Under P5 the mid push pill stays at 46.0 s: it survives only because the wipe banner replaced a 5-word feed line with a 2-word one |
| Where a commentary line (8 words) still fits the budget | 26.75 to 28.5 s, 39.5 to 42.5 s, 47.5 to 49.0 s, 66.0 to 68.75 s (start times). In the worst case above the third slot opens only from 48.5 s, because a yours-only mid push pill is still up. **At most 2 commentary lines per game**; the Narrative Designer writes for those four slots. Esports' "recap in the plan check" (ESPORTS-NOTES 2.2, item 4) has no room at 21 to 24 s, because the jungle result (20.25 s), the plan banner and the rotation labels (24.2 s) already fill the budget; move it to the first slot |

Per moment, in the Esports Manager's terms (ESPORTS-NOTES 2.4) and what the layout does with it:

| Moment | New text allowed | Layout |
|---|---|---|
| Calm (opening, rotation, reset, siege hold) | pill pair, one tag, one commentary line | pills in the intent row; the commentary line in feed line 2 only in the four slots above |
| Fight (the windows around 45.0 and 71.25 s) | tag plus one feed line; pills already on screen stay | no new pills; commentary waits |
| Resolve stamp (1 s after any stamp) | tag plus one feed line | nothing else starts |
| Closing hold (74.0 to 75.0 s) | one: the end card | everything else fades; see 6.7.6 |

#### 6.7.5 The Report's story vocabulary on the HUD (Early, Mid, Late)

The player should see the same story twice, once live and once in the report (UI-PASS-2 7.6 item 3).

| Report story (6.6) | On the arena HUD |
|---|---|
| Three phase bands **Early, Mid, Late** | The phase chip in row B (24 px) and two ticks on the lead graph. Boundaries come from the show timeline: **Early 0 to 24.0 s** (opening, lanes, jungle, plan check), **Mid 24.0 to 51.0 s** (Stoneback and the mid fight with its push), **Late from 51.0 s** (reset, Moonhulk, the late fight, the close). They are the Report's contests grouped as `Report.FEED_ORDER` groups them: Early four, Mid two, Late two |
| Contest chips: Top, Mid, Bot, Jungle / Objective, Fight / Objective, Fight, each with a tick or a cross and 1 to 3 dots | Feed lines use the game's own contest names (`feed.t.*`: "Top lane", "Mid lane", "Bot lane", "Jungle control", "Mid-game objective", "Mid-game fight", "Late objective", "Decisive teamfight"), a tick or cross glyph in front, 1 to 3 dots after. Note for Narrative: the Report chips say "Objective" and "Fight" under Mid and Late, the feed says "Mid-game objective", "Decisive teamfight". Use one name set in both |
| "Mid" is both a lane (Early, a lane contest) and a phase | The lane is always "Mid lane" in feed text and carries the role icon; the phase is the chip "Mid". The Report's Early chip `[ MID ]` should read "MID LANE" for the same reason (note for 6.6 and for Narrative) |
| Size words narrow, clear, decisive (`Report.margin_word`) | The dots (1, 2, 3) in the feed; the words appear on the end card and in the Report (arena I8) |
| Story tag from the eight phase-sign patterns (6.6) | The end card's second line is **the same story tag** the Report shows, one function (`Report.story`, request S3), not the arena's own arc names (close, comeback, stomp, steady) |
| Hero stat: the biggest factor, luck included | The end card's "Decided by:" line uses the same factor text (ACTION-VOCABULARY 5.3) |

#### 6.7.6 Controls, skip, speed, "?" and the end of the show

| Control | Rule |
|---|---|
| **Speed x1 / x2** | One toggle button, 200 x 96 px, label shows the current speed; id `match.controls` covers Speed and Skip together. A tap changes the playback rate; it never changes a result. At x2: both intent labels hidden, feed hold 4 s of real time or until the next line, tags and banners unchanged. The four lane lines arrive 1.1 s apart at x2, so they will flash by; they are all in the Report, and the model above only budgets x1 |
| **Skip to the end** | One tap, no confirm (watching or skipping never changes the result, and the 5-minute pillar says do not add taps). It jumps show time to 75 s: the scoreboard shows its final state in one frame (it is a function of show time, ACTION-VOCABULARY H4), labels and commentary do not replay, the feed block shows the end card. Neutral button, not coral |
| **Android Back** | During the show it acts as Skip (the result is decided and saved; the report is the only exit). After the show it acts as See the report. No "Leave the match?" sheet |
| **"?"** | 96 x 96 at the **right end of the controls row** (the one place it is not top right, because the scoreboard owns the top). Opens the help sheet; **the show pauses while any sheet is open** and resumes on close (ACTION-VOCABULARY H4 keeps the 75 s as playback length, so pausing does not change it). Tutorial step 19 highlights `match.controls`; the "?" is outside that hole |
| **Arena taps** | None in 0.8. No hero, tower or camp can be tapped, so nothing can be hit by accident while the player reaches for Speed or Skip |
| **End of show (74 to 75 s, then stays)** | The Cairn falls at 74.0 s and holds to 75.0 s. Then the feed block becomes the **end card**: line 1 the result word at 32 px with a flag shape (for a defeat the `BAD` Defeat glyph, the one place `BAD` appears in the arena) and the margin word and length (`Report.result_word`, `Report.game_minutes`), line 2 "Decided by:" and the Report's factor text, 26 px. Speed and Skip are replaced by one **See the report** button (coral, 96 px high, the only coral on the screen; id `match.report_btn`) and the "?" stays |
| Quick mode (Settings) | The arena is not shown; the flow goes straight to the report as today |

#### 6.7.7 Large text, tall phones, colour-blind, and the other modes

- **Large text (626 x 1113 logical).** Text in the arena is drawn in screen space and takes the text scale; the map art scales with the width, so the arena is **626 x 661**. The stack becomes: safe 48, scoreboard 122 (row A 40, row B 44, row C 34, gaps 2 + 2), arena 661, text strip 150 (plan row 44, intent 48, one feed line 38, gaps 8 + 8, 4 spare), controls 132 = 1113. Changes: **one** intent label (yours), **one** feed line (no previous line), **no commentary**, the plan chip shows two parts, the centre slot is 280 px (every tag line fits: the longest is 266 of 280 px with the 32 px glyph), the arena's zone labels are hidden (token slot letters stay). Showing only your intent label is the large-text fallback that D8 keeps; the measurement says both would fit in 99.75 percent of pairs, so revisit it once the font has been loaded in Godot. The budget numbers of 6.7.4 apply with the "large" column.
- **Tall phone (720 x 1560).** The arena stays 720 x 760 and the controls stay at the bottom. The extra 280 px goes to the lead graph (row C grows by 40, a taller story) and the text strip (the feed block shows the last 4 results, 5 lines, +120); the rest is air above the scoreboard. No new text channel is added.
- **Colour-blind.** You are a **circle**, they are a **hexagon** in the pills, the gold lead glyph, the objective markers and the zone rings: shape first, colour second (`ACCENT` for you and `CORAL` for them, ART-BIBLE 3.8; the colour-blind palette swap does not touch these two). Feed lines carry a tick or cross shape. The lead graph has a centre line and a fill pattern, not a hue pair. `BAD` appears in the arena only as the Defeat glyph on the end card; the loss tone is the cool edge vignette (ACTION-VOCABULARY 2.2); a feed line is never coloured, and `BAD` never marks "them". Blue / Red side does not appear in the arena at all (C4).
- **Animations off.** Pills, tags and banners appear and disappear instantly; the graph updates in steps; the show still plays at its own pace (that is the 75 s, not an animation setting; ARENA-MAP 8 covers reduced camera motion).
- **Contrast.** Pills and chips sit on the E1 strip surface, where tinted chips are allowed (art bible 3.4: 4.5 to 6.5:1). Banners are on a solid E3 fill with `TEXT`, never `DIM`. Nothing in the HUD sits on the map art; text on the map (zone labels) is `TEXT` with a 5 px `VOID` outline (ART-BIBLE 3.9).

#### 6.7.8 Data feeding the HUD

| Block | Source |
|---|---|
| Show time, clock | the show script's clock; `Report.game_minutes(res)` |
| Kills, towers, objectives, gold lead, graph | the ledger of ACTION-VOCABULARY section 5 (F4, F7 to F12), ideally one function `Report.story(res, my_side)` (request S3 to the Systems Designer) so the arena, the Report and QA share it |
| Feed lines | `Report.feed(res, my_side)` events (key, mine, size, t) with the short form |
| Intent labels, tags | the label catalogue of ACTION-VOCABULARY 4.3 and the tag table in 2.4 (owner: Gameplay) |
| Plan chips | `App.gs.plan_set()` today, `res.plans` after request S1 |
| Commentary | Narrative Designer, 4 slots, at most 2 used |
| End card | `Report.result_word`, `Report.game_minutes`, `Report.attribution`, `Report.story` |

#### 6.7.9 Interactions: summary

Speed toggles, Skip jumps, Back skips, "?" opens a sheet and pauses, the plan row opens a read-only sheet and pauses, the arena is inert, See the report leaves. No gesture is needed for anything.

#### 6.7.10 Tests QA Automation can run without a phone

1. **Budget:** for 10,000 seeded shows, in normal and large text: at most 10 new words in any 2.5 s window, at most 3 transient items visible at once (1 under a banner), no feed line dropped, no label ellipsised.
2. **Floor:** every `Label` in the HUD has a font size of 24 px or more; feed lines 26; numbers 32.
3. **Geometry:** at 720 x 1280, 720 x 1560 and 626 x 1113 the arena is 720 x 760 (626 x 661 large), strips do not overlap (48 + 142 + 760 + 198 + 132 = 1280), all buttons are at least 96 px high, the "?" is inside the controls row.
4. **Fit:** with the theme font, a pill, tag or chip that fits is not ellipsised, and one that does not fit is dropped by the rule, not clipped (the widths in 6.7.1 were measured outside Godot; this test checks them in the engine).
5. **Skip and speed:** one tap each; Back acts as Skip; a sheet pauses the show clock and closing resumes it; the final scoreboard after Skip equals the one after a full play (kills, towers, objectives, gold lead).
6. **Tie-out:** kills, towers and gold lead equal the Report's numbers (ACTION-VOCABULARY I1 to I8).

#### 6.7.11 One primary decision

None while the show plays: it is a spectator screen, which is why Skip and Speed are neutral and the arena takes no taps. When the show ends the one decision is **See the report** (the only coral).

#### 6.7.12 What I could not check, and what I need from others

The text widths in 6.7.1 are the Producer's measurement with the real font files; I re-ran the longest label (239 px), the longest tag (234 px) and the worst pair (599 of 672 px) and got the same numbers (my own count of overflowing pairs in large text, with the place names and lanes filled in differently, was 72 of 31,329, 0.23 percent, against the Producer's 49 of 19,881, 0.25 percent: the same order). Barlow has never been loaded in Godot, so in-engine widths are untested (6.7.10 test 4). I could not see the arena (it does not exist yet) and could not test touch. The 10-word budget is an unmeasured estimate by the Esports Manager. The model in 6.7.4 shows the budget is **tight but possible only with the cuts accepted in 6.7.1**, above all the short feed form; without them the lane phase alone breaks it.

| To | Ask |
|---|---|
| Level / World Designer | Ruling P1: edit ARENA-MAP 4, `layout_px` and the preview to a text strip of 198 and a controls strip of 132 (B1); map labels 24 px Bold, +1.5 px tracking, `TEXT`, 5 px `VOID` outline, a label-overlap check, STONEBACK above or left of its icon (B4, P9); confirm the player's base at the bottom and the 142 px scoreboard content height (the 190 px includes the status bar) |
| Gameplay / Champion Designer | Already in `ACTION-VOCABULARY.md` pass 1c: P3 (`gp.switch.short.<id>`, 4 words), P4, P6, P7, P8, P12, and P5 (the window is not moved). Label limit stays 28 and tag limit 24 (P2 rejected). Open for you to decide: delete the `push_tower` and `push_dive` pills (recommended, they are dropped in most games, 6.7.4); confirm "no pronouns" is not needed for the short feed form |
| Systems Designer | `Report.story(res, my_side)` (S3) as the single source for scoreboard, end card and story tag; a short feed form `feed.line.short` ("{title}: {result}") with `feed.win.short` "you win it" and `feed.loss.short` "they win it" and the size as dots |
| Esports Manager / Narrative Designer | P11 accepted: commentary at most 2 lines per game, 8 words or fewer, for the slots 26.75 to 28.5, 39.5 to 42.5, 47.5 to 49.0 and 66.0 to 68.75 s (the 47.5 slot stays valid because the mid push pill is not moved); one contest name set for feed and Report chips; Esports edits ESPORTS-NOTES per B11 |
| Art Director | The tokens, 24 px outlined map labels and the Match row are done in ART-BIBLE 2b and 2c. Remaining: the Report chip `[ MID ]` as "MID LANE"; the `BAD` Defeat glyph for the end card |
| Technical Designer | The HUD scheduler is a pure function of the show script (testable); keep text out of the show data except label ids |

## 7. Cross-cutting requirements

### 7.1 Test matrix every screen must pass (acceptance for "fits 720 px in normal and large text")

| Axis | Values |
|---|---|
| Size and text | normal text at 720 x 1280 (design case); normal text at 720 x 1560 (tall phone); large text (+15 percent, which is a 626 x 1113 logical canvas) |
| Palette | default, colour-blind |
| Content | normal save, plus the worst-case fixtures below |

That is 3 x 2 x 2 = 12 screenshots per screen; for six screens, 72 images. The existing `tests/ui_shots.gd` tour (Xvfb) can produce them; it needs the large-text and colour-blind switches and the fixtures.

Worst-case fixtures (so overflow shows up before the Founder finds it):
- Longest club name: "Northreach Corsairs" (19 characters; the longest in `clubs.json`) as your club and as the opponent.
- Longest hero names: "Gravenstone" (11), "Tanglewick" (10), "Fennimore" (9) in the grid, board and sheet.
- Longest player name: 8 characters ("Brammont", "Brampyre"). A three-digit rating where relevant.
- Statuses: a player who is exhausted, out of form, unhappy and on a final contract at once (shows the chip priority and "+n").
- Squad with 12 players (grid growth), a draft with 3 bans per side (full draft), a playoff final in progress, a season with zero games played, and a season with all 18 played.
- A Game Plan with every control at +2 and one at -2 (largest text on the effect lines).

Automated audits worth adding (cheap, headless, no phone needed):
1. Touch target audit: walk the node tree of each screen; every `BaseButton` and every tappable `Control` has a hit rectangle of at least 96 x 96 px (in design px, after content scale).
2. Text size audit: no `Label` or `Button` font below 24 px (the Caption floor); text a player decides with is 32 px; secondary lines 26 px.
3. No mid-word wrap: for labels in Segmented and in chips, measure with the theme font and fail when a word is wider than its slot.
4. Reachability: the primary action of each screen is inside the visible area at 720 x 1280 and at 626 x 1113 without scrolling (Home Play, Draft grid and Coach bar, Game Plan Start, Report Continue, Squad tokens).
5. UI never writes to the sim: preview helpers (team rating after a swap, coach diff, edge preview) work on copies; a test asserts `gs.d` is unchanged after opening and cancelling every sheet.

### 7.2 Large text and colour-blind: the shared behaviours (so each screen does not re-invent them)

- Reflow, never scale-down: HFlow containers for chips, grids computed from width, columns collapse by priority (Standings: rank, badge, name, points always; record moves under points).
- Fixed parts (headers, hero strips, footers) are budgeted so a scroll area of at least 400 px remains at 917 px usable height. Where it does not, the hero shrinks (hero badge 112 to 88) before text shrinks.
- Text never goes below 24 px; if content does not fit, it wraps (up to two lines) or moves into a sheet.
- Palette: every status has an icon or glyph; the rules of section 2.4 apply to every new component, and a component is not done until it passes a colour-blind screenshot.

### 7.3 Hooks for the tutorial (W1) and the "?" help

I adopt W1's mechanism (`TUTORIAL.md` section 8): a control is tagged with `UI.tag(control, "id")`, tags are applied again whenever a component is rebuilt, and **existing ids keep their names**. My components take an `id` argument and call `UI.tag`. New ids follow the same dotted style. Where a W1 id points at a control this redesign moves or replaces, the table says what it now points at.

| W1 id (step) | Now points at | Note |
|---|---|---|
| `tabbar`, `tab.home`, `tab.squad`, `tab.plan`, `tab.club`, `tab.more` | the five tab buttons (96 px) | unchanged |
| `help.button`, `screen.back` | `ScreenHeader` "?" slot and back button | every screen |
| `home.next_card` (step 2) | the Next-match card | unchanged |
| `home.play` | the coral Play button in that card | unchanged |
| `home.attention` | the strip of attention cards | unchanged |
| `home.tile.standing`, `home.tile.chem` | two of the four tiles in the 2 x 2 grid | unchanged |
| `home.offer` | an inline offer card placed under the attention cards | new slot, 0 px when empty |
| `roster.row.0` (v1 step 5) | **retired.** Replaced by `squad.bench.0`, the first bench card (a read-only player sheet opens; a token opens the lane picker, which can change the lineup) | TUTORIAL v1.1 step 5 uses `squad.bench.0` |
| `roster.card.head` (step 6) | the header of the player sheet (avatar, name, status bars) | the sheet opens in place; no scrolling needed |
| `roster.row.expiring` (L3) | **retired.** Replaced by `squad.bench.expiring`, the first bench card with the contract chip | all ten contracts end together, so a bench card with the chip exists |
| `roster.card.contract`, `.renew`, `.release` | the contract line and footer buttons in the player sheet | inside a sheet: see the sheet contract below this table |
| `squad.picker.head`, `squad.picker.card` (new) | the lane picker's header, and the "now playing" row that opens that starter's player sheet | the header is the hole of tutorial variant 5-B |
| `prematch.matchups`, `prematch.start_draft` | not changed here (Match day is left as is, D4) | |
| `draft.choices` (steps 12 and 13) | the Coach suggests bar plus the hero grid together | the text names the Take button on the Coach bar |
| `draft.hero_grid` | the 3-column HeroCard grid | no longer a first-run target |
| `draft.slot_list` (step 14) | the "Plays as" lane row in the hero sheet | the sheet replaces the old role list; same job |
| `draft.sheet.confirm` (new; steps 12 and 14) | the Ban or Pick button pinned in the hero sheet's footer | step 14's hole is the bounding box of `draft.slot_list` and this button |
| `draft.auto_rest` (step 15) | the Auto-finish text button in the header (26 px label, 176 x 96 hit) | two taps in the real game (Sure?); the tutorial holds the armed state |
| `draft.game_plan` | the "Game plan" button on the new Draft-complete screen | |
| `gp.edge` | the sticky Edge hero | |
| `gp.contests` | the 2 x 2 EdgeMeters (Top, Mid, Bot, Jungle) | |
| `gp.tabs` | the PhaseStrip (Overall, Early, Mid, Late) | |
| `gp.sliders` | the group of DetentTrack cards | |
| `gp.coach` (step 17) | the Coach button in the footer | opens the diff sheet; raises `gp:coach_open` |
| `gp.coach_apply` (new; step 17 stage B) | Apply, pinned in the Coach sheet; a sheet with nothing to change shows Close and raises `gp:coach_close` | |
| `gp.start_match` | the coral Start the match button | |
| `report.result` (step 21) | the result hero | |
| `report.why` (step 22) | the **hero stat** card; a tap opens the factor sheet (event `open:report_why`) | TUTORIAL v1.1 makes step 22 a tap on this card |
| `report.why_sheet` (new; step 22 stage B) | the factor bars inside the size-L sheet | Next on the tutorial card closes the sheet |
| `report.payoff`, `report.tip` | the "What this game changed" block and the tip card | |
| `report.continue` (step 23) | the sticky coral Continue footer | |
| `standings.tabs` | the Table / Playoffs / History segmented control | three, not five. TUTORIAL v1.1 lesson L1 and the Standings help row are rewritten for it (C2) |
| `standings.table` | the table (podium plus rows) | |
| `stand.metric` (step 26; replaces `standings.form_list`) | the Points / Form switch in the Table header | the Club tile "Form Rating" opens Standings with the switch already on Form; the step asks for a tap on Points |
| `match.controls`, `match.report_btn` | 0.7: today's Speed, Skip and See the report buttons. 0.8: the controls row and the end-of-show button (6.7) | ids unchanged; the 0.8 arena also holds `help.button` at the right end of the controls row |

New ids from this spec (all optional for the tutorial unless marked in `TUTORIAL.md` section 8): `squad.map`, `squad.token.<slot>`, `squad.bench`, `squad.bench.<n>`, `squad.market`, `squad.auto`, `draft.timer`, `draft.steps`, `draft.board`, `draft.lane.<slot>`, `draft.needs`, `draft.filter`, `draft.coach`, `draft.card.<hid>`, `draft.sheet.lane_control`, `plan.chip`, `plan.phases`, `plan.control.<id>`, `plan.reset`, `stand.views`, `stand.podium`, `stand.own_row`, `stand.metric`, `stand.line`, `stand.bracket`, `report.story`, `report.stat`, `report.changed`, `report.dig`; for the arena: `match.scoreboard`, `match.graph`, `match.plan_row`, `match.intent_row`, `match.feed`.

**The sheet contract (settled with TUTORIAL v1.1; it was two cautions in my first draft).** (1) The coach overlay draws above every `BottomSheet` (its own canvas layer), so a step can spotlight a control inside a sheet, and the sheet's scrim is never the topmost node under the hole. (2) The overlay's dim panels cover a sheet's scrim and drag zone, so a sheet cannot be dismissed during a tutorial step. (3) `draft.hero_grid` scrolls, so first-run steps target `draft.choices` (the Coach bar sits in the first row, scrolled to the top at step start). (4) Sheets raise open events (`open:player_card`, `draft:sheet`, `gp:coach_open`, `open:report_why`), and the Coach sheet shows a Close button when it has no change to apply.

Every `ScreenHeader` reserves the 96 x 96 "?" slot (top right) and takes a `help_key`, matching the tutorial's contract item 2. **One wireframe did have to change** (my first draft said none would): the Draft header had no slot and now shows it (6.3). Home states its contrast over the hero art (6.1). The arena has no top-right header; its "?" sits at the right end of the controls row (6.7).

### 7.4 New copy needed (Narrative Designer), all through `Strings`, none hard-coded

- Game Plan: a short end label pair per control (8 controls, 16 short words; for example Fight style: "Spread out" / "Group up"), phase names (Overall, Early, Mid, Late), contest short names (Top, Mid, Bot, Jungle, Objective, Fight), the "only the late-game part applies in this plan" line, the "uses your Default plan" caption, the Coach preview sheet text.
- Report: eight story tags for the phase patterns (+++, ++-, +-+, +--, -++, -+-, --+, ---), the hero-stat sentences (for a normal factor and for luck; the luck sentence must be honest, see 7.6), "Dig deeper" tab names (Players, Moments, Draft), the title of the factor sheet (Why this happened), the tip action labels (Open squad).
- Standings: view names (Table, Playoffs, History), the cut-line sentences (above, on, below the line, and after the playoffs), "YOU", empty-state lines.
- Squad: sheet titles and the delta line ("team +1.2"), the swap note, "Find a player".
- Draft: header lines in sentence case ("Your ban", "Your pick", "Their ban", "Their pick"), the "Leave the draft?" confirm, "Time is up: Coach picked X", "Coach suggests: X", "Take", "Auto-finish", "Sure?", filter names (All and five role codes), the side words with a flag glyph ("Blue", "Red"). The game strings that change for the **Coach** rename are in `TUTORIAL.md` section 13.
- Standings: the Points / Form switch says "Form" while player cards say "form" (recent performance). The switch label might read "Form Rating" if it fits (about 130 px at 24 px in a two-option switch): Narrative's call.
- Match (arena, 6.7): phase chip words (Early, Mid, Late), a short plan-switch banner of at most 4 words for each `gp.switch.<id>` line (`gp.switch.short.<id>`), the status tags and intent labels (Gameplay owns these), and at most two commentary lines per game (Narrative).
- Everything is plain words, short, and counted against the 24, 26 and 32 px slots in this spec.

### 7.5 Small additions to game code that these layouts need (engineering, no sim or balance change)

| Need | Where | Why |
|---|---|---|
| `GameState.upcoming(n)` | `game_state.gd` | Home carousel; read-only over `d["fixtures"]` |
| `GameState.cut_gap()` | `game_state.gd` | Standings pinned sentence; read-only over `standings()` |
| `Report.team_kills(res)` | `report.gd` | Report score line; sums `Report.kda` |
| Team rating after a swap (copy of the lineup) | helper in `roster` UI or `World` | Picker sheet preview |
| `Draft.best_slot_for(team, hid)` | `draft.gd` | The inline "best slot" logic in `_actions` moves out so the sheet can preselect |
| Club `colors` and `badge` ids | `data/clubs.json` + assets | Hero header, badges everywhere |
| Club badge generator (art bible 6.3), hero silhouette and initial avatar drawers (6.2), icons (8.4) | code and assets | All screens |
| Per-control phase map | derived from `data/game_plan_v0.json` at load | Phase pips and inert controls |

### 7.6 Findings for other roles (found while designing, not mine to change)

1. **Lead Game Designer / Systems Designer:** on the "If behind" and "If ahead" plans, Lane aggression and Jungle focus have no effect (their contests are early; early contests always use the Default plan), and the early parts of Tempo, Fight style and Support are ignored (`game_plan.gd`: `_hooked`, `simulate`). The layout hides or marks them inert. Please confirm this is the intended rule; if the intent was a full plan swap, the sim, not the UI, should change (and the GDD 7.8 text should say which).
2. **Systems Designer / W4 owners:** the Report score line and the later arena scoreboard must show the same kills. `Report.kda` is the single source (it already guarantees winner has more kills); the arena should read it, not invent its own.
3. **W4 owners:** the Report's story strip uses the three phases and eight contests of `Report.FEED_ORDER`; the arena should use the same phase names (Early, Mid, Late) and contest names so the player sees the same story twice.
4. **Narrative / Lead Game Designer:** luck is the largest factor in the attribution of the sample loss (53 percent, `15_report_mid`). The hero stat will say so plainly; the "Results felt fair and believable" tester question may need a short explanation of what luck means ("the draw and the dice"), shown in the hero stat sheet.
5. **Data / Narrative:** hero names: the longest (Gravenstone 11, Tanglewick 10) fit the 216 px card (and the 183 px card in large text) at 26 px. Keep display names to 12 characters or fewer; a data check should flag longer ones.

---

## 8. Build order, risks, assets

### 8.1 Build order and rough sizes

Sizes are developer days for one Gameplay Programmer including their own testing; they are designer estimates with low confidence (no prototype yet). S about 2 days, M 3 to 4, L 5 to 7.

| Step | What | Size | Why here |
|---|---|---|---|
| 0 | Spike: nested horizontal-in-vertical scrolling, long-press drag, a sheet, and the cost of 40 cards with shadows, measured on the build computer with simulated touch (`ui_touch.gd` style) | S | Settles the three riskiest assumptions before the components are built; cheap |
| 1 | Tokens (section 2.2) + components 5.1 to 5.5 and 5.10 to 5.12, 5.15 with the art bible's code-drawn badges, silhouettes and avatars; re-shoot the 20 existing screens | L | Everything depends on it; the token change touches every screen, so it lands once |
| 2 | **Home** (hero, Next card, tiles; carousel last) | M | First thing the Founder sees; smallest data surface; proves the hero and card depth |
| 3 | **Draft** (board, grid, sheet, done state) | L | Biggest eyesore and the most-used screen in the loop; highest value |
| 4 | **Game Plan** (edge hero, PhaseStrip, DetentTracks, coach sheet, trigger rules) | M to L | Follows Draft in the loop; also fixes the dead-control problem |
| 5 | **Report** (hero, story, hero stat, reveal) | M | Closes the loop; also the payoff moment |
| 6 | **Squad** (lane map, bench cards, picker and detail sheets, market carousel) | L | Weekly use, not per match; biggest layout; needs the arena map for final token positions |
| 7 | **Standings** (podium, rows, bracket, history) | M | Read-only; lowest risk; can move up to step 2 if a safe early win is wanted |
| 8 | Polish and the full 72-image test matrix, audits of 7.1, fixes | M | Acceptance |
| (parallel) | Plan and Club tab tiles move to the 2 x 2 tile grid and new tokens (the two tabs are still stacked wide tiles, `04c_tab_plan`); the Match day screen adopts the new components | S | Not in the six screens but they will look out of place next to them |
| (0.8, after the arena exists) | **Match HUD** (6.7): scoreboard strip, text strip with the scheduler, controls, end card, large-text rules, tests of 6.7.10 | M | Not in the 0.7 total; depends on the arena, the short feed form and `Report.story`; designer guess, low confidence |

About 38 developer days in total for 0.7 plus QA (the 0.8 HUD adds about 3 to 4 more). If time is short, cut in this order: Home carousel, drag-to-swap on Squad, History mini story strips, Report starter chips sheet.

### 8.2 Biggest risks and what to do about them

| # | Risk | Why it matters | Mitigation |
|---|---|---|---|
| R1 | **Low-end phone performance.** Richer cards (shadows, gradients, drawn silhouettes and badges) and the current pattern of deleting and rebuilding the whole page on every tap (`_rebuild()` in Roster, Draft, Game Plan) | A grid of 40 shadowed cards or a 100-node rebuild per slider tap can drop frames on a 2 GB phone; the Draft also runs a timer every frame | Flat baked cards in grids (no live blur; at most 8 shadows on screen); update components in place; the timer ring redraws only when the displayed second changes; atlas the 40 hero portraits into one texture and decode player portraits only for the lineup, bench, opponent and visible free agents (about 25 at a time); no per-frame tweens on hidden nodes; measure before and after on the build computer, then on the Founder's phone |
| R2 | **Text overflow.** Longest strings: club names to 19 characters, hero names to 11, large text at 626 px, 3-column grids | The Standings tab bug and the 1-character-per-line `kv_row` bug are the same class (`UI-UX-REFERENCE-v1.md`, section 10) | Rules 2.3 (3) and (4); the fixtures and the audits of 7.1; a hero name length lint; components own their wrapping, screens do not |
| R3 | **Touch gestures are unverified.** Horizontal carousels inside a vertical scroll, drag-to-swap, sheet drag-to-dismiss and phase swipe can all steal each other's drags | A broken scroll is worse than a plain list; the existing comments in `ui.gd` show this was already a problem once (buttons stealing swipes) | Step 0 spike; every gesture has a tap alternative; direction lock with a 12 px threshold; drag-to-swap and phase swipe are the first features cut |
| R4 | **Token change ripples.** Body 28 to 32 and buttons to 96 lengthen every unredesigned screen (Finance, Training, Chemistry, Free agents, Settings, Match day) and may overflow them | A half-updated app looks worse than either version | Land tokens once in step 1, re-shoot all 20 existing screens, fix overflows in that step; budget in 8.1 includes it |
| R5 | **Art not ready.** Icons, empty-state pictures and backdrops are the remaining dependencies (badges, silhouettes and avatars are code) | Layouts look bare without icons | Every icon slot ships with a simple code-drawn shape and a text label; no step waits for art; swap is a texture change |
| R6 | **Colour-blind collisions** (blue side vs good, red side vs bad) | A colour-blind tester cannot tell sides or results | Rules in 2.4; the colour-blind screenshot is part of every component's definition of done |
| R7 | **Information density on 16:9 phones.** The draft shows about 11 heroes at once; the Game Plan scrolls inside a fixed frame | A cramped feel on the very screen that should feel exciting | Board size rule (deterministic); tall phones get the full board; role filter and coach bar mean the player rarely scrolls; check on real phones |
| R8 | **Honesty of the report copy.** A luck-heavy loss framed badly feels like an excuse; a luck-heavy win framed as skill is false | Fairness is a tester question (W4 acceptance) | Hero stat copy is reviewed by Narrative and the Lead Game Designer; luck is always named as luck |
| R9 | **Scope.** Six screens, 16 components, two other workstreams in parallel | Late components block everything | Components are specified once here; screens only compose them; cut list in 8.1 |

### 8.3 What I could not check

Nothing here ran. I could not check scroll feel, gesture conflicts, frame time, texture memory, haptics, or whether the lane map reads at a glance; the heights are paper estimates. The first real evidence will be the step 0 spike, then the 72-image matrix, then the Founder's phone and a usability session with new testers (UI-12 in the reference doc, still open and needing real people).

### 8.4 Assets needed from the Art department

All art is original and goes to the IP & Originality Checker (the art bible sets the style). Counts and sizes are what the layouts above use; sources should be 2 times the largest display size so they stay sharp on 3x phones. Where I say "atlas", please deliver as sprite sheets so the engine can batch them. Not in this table because they are done or drawn in code: the five role icons (`ic_role_*.svg`, ART-BIBLE 6.1; used at 28 in a chip, 32 beside the code, 48, never alone under 32), the Squad lane-map backdrop (code-drawn, ART-BIBLE 6.4), club badges, hero silhouettes and initial avatars.

| Asset | Count | Source size | Displayed at | Notes |
|---|---|---|---|---|
| Club badges | 10 | generated in code from the club id (art bible 6.3, no file) | 112 (Home hero), 96 (Next card; 80 large), 88 / 72 / 72 (podium), 56 (rows), 44 (chips) | Needs `colors` and `badge` ids added to `clubs.json`; art bible says all six shapes differ at 40 px |
| Hero silhouettes | 40 | drawn in code (art bible 6.2), no file | 96 (grid), 128 (sheet), 44 (board), 40 (chips) | Cache one texture per hero and size; archetype shows in the silhouette |
| Player avatars | 140 | drawn in code: letter on a role ring (art bible 6.2), no faces | 160 (detail), 120 (bench card), 96 (lane-map token), 72 (rows), 56 (mini) | Painted portraits postponed to pre-launch (Founder decision) |
| Archetype icons | 7 (bruiser, gunner, bulwark, shade, spellcaster, binder, mender) | 96 | 32 | Corner badge on hero cards |
| Tag icons | 8 (frontline, engage, pick, waveclear, protect, splitpush, poke, scaling) | 80 | 32, 28 | Sheet and chips |
| Status and UI glyphs | about 24 (tired, in form, out of form, happy, unhappy, contract ends, off-role, coach star, lock, tick, cross, ban X, arrow up, down, flat, help, back, close, chevron, coach wand, reset, branch, plus, minus) | 96 | 28 to 48 | Shapes must differ without colour |
| Phase and contest icons | 6 (overall, early, mid, late, objective, fight) | 96 | 32 inside the 56 px node, 28 in chips | Lanes reuse the role icons |
| Game Plan control icons | 8 (fight style, tempo, mid objectives, late objectives, lane aggression, support, risk, jungle focus) | 96 | 32 | Beside each control name |
| Mood faces | 4 (high, ok, low, poor) | 128 | 64 | Home mood tile |
| Podium and trophy art | 3 medals, 1 crown, 3 cups (gold, silver, bronze), 1 empty slot | 256 | 96, 64 | Trophy shelf and champion |
| Empty-state illustrations | 4 (no games yet, no free agents, no upcoming games or season over, playoffs not started) | 768 x 576 | 384 x 288 | Same style as the hero art |
| Home hero backdrop | 1 (`VOID` skyline silhouettes at 55 to 70 percent over the page gradient; the flat 10 percent club wash behind the 248 px block is code, ART-BIBLE 3.7 rule 8) | 1440 x 496 | 720 x 248 | Tileable edges; the top-right 120 x 120 px has nothing lighter than `#43536E` (the "?" sits there, 6.1; accepted by the Art Director, A6) |
| Card depth set | 1 nine-slice (flat card, raised card, sheet top, grab handle) | 96 x 96 with 32 px slices | any | Baked shadows, so grids stay cheap |
| Fonts | as the art bible decides | n/a | n/a | Must keep numerals tabular (aligned columns in tables) and cover the characters in `en.json` |

### 8.5 Not in the six screens, left as they are for now

The live Match screen (0.7: today's screen with the 75 s watch, Speed x1 / x2, Skip and See the report; the 0.8 arena HUD is section 6.7), Match day (pre-game), Team chemistry (pentagon), Training, Finance, Free agents, Negotiation, Settings, the Plan and Club tab roots, Practice, Season end. They keep working with the new tokens (step 1) but will look older than the six. Suggested follow-up (UI Pass 3): the Chemistry pentagon becomes the same lane map as Squad (the UI reference v1 backlog item UI-5), Match day becomes a sheet on Home (D4 below), Plan and Club tabs use the 2 x 2 tile grid.

---

## 9. Decisions needed

For the Founder (recommendation first, plain words):

| # | Decision | Recommendation |
|---|---|---|
| D1 | Make text and buttons about 15 percent bigger across the game so they meet the 16 sp and 48 dp rule on a normal phone | **Yes.** Today many buttons are about 32 to 38 dp; small hands and tired eyes are the first complaint of a mobile game |
| D2 | Cut Standings from five tabs to three views (Table with a Points/Form switch, Playoffs, History) | **Yes.** Fits in large text, no broken words, fewer taps |
| D3 | Show your five starters on a small lane map instead of five rows | **Yes.** It is the one new idea that makes Squad look like a different game screen; fallback if it does not read well in testing: five avatar cards in a row |
| D4 | Match day (the screen between Home and the draft): keep it for 0.7, or fold it into a "Match preview" sheet on Home | **Keep for 0.7**, fold it in with UI Pass 3; changing the flow now adds risk to the tutorial (W1) |
| D5 | Build with the art bible's code-drawn badges, hero silhouettes and initial avatars (no painted art needed), and simple code shapes for icons until the icon set lands | **Yes**, so the layouts are testable now and no step waits |
| D6 | Home "Up next" swipe row: build it, or leave it out for now | **Build it last**; it is the least important block and the first to cut |
| D7 | Body text at 32 px (16 sp) as the brief asks, or the art bible's 30 px (15 sp) | **32.** The brief and the UI reference both say 16 sp; the narrower font keeps the line length about the same. Fallback: 30 and accept 15 sp. **Producer ruling C1: 32 adopted by default; the Founder may overrule at the checkpoint** |
| D8 | (new) Arena text: show **both** coaches' labels in the live match, or only yours | **Both, no shortening** (Producer ruling P2: label limit stays 28, tag limit 24; in the real font the longest label is 239 px and the worst pair 599 of 672 px). In large text only yours show (that fallback stays; 0.25 percent of pairs would not fit there). If testers find the labels hard to read: yours only |

For other roles: see the findings in 7.6 (Lead Game Designer and Systems Designer on the inert plan controls and kills consistency; Narrative on copy and the 12-character name check; Art Director on the asset list and the role-colour rules; W1 on the `tut_id` table).

## 10. Hand-offs

- **Art Director:** the token table, the 40 px title token, the section-label colour, the club wash strength, the attention card, the in-arena you and them tokens, the 120 x 120 px clear zone, the Squad anchors, 56 px Standings badges and 24 px map labels are all settled in ART-BIBLE 2b and 2c and this spec now cites them. Still open for you: confirm the asset counts and sizes in 8.4 (role icons and the Squad backdrop are no longer on the list), delete the 260 px "Your turn: ban" example (A4), and say whether the Squad map needs a role code beside each name (6.2: the bible has no role glyph on the map, and rule 2.4 asks for icon plus code).
- **Concept / Character / Environment Artists:** icons per 8.4, empty-state pictures, the Home hero backdrop, the lane-map backdrop, mood faces and trophies. Badges, hero silhouettes and initial avatars are code (art bible), so no painting is needed for them.
- **Gameplay Programmer (Alpha 0.7 build):** steps 0 to 8 of 8.1; the small helpers in 7.5; do not rebuild whole pages on a tap.
- **Engine / Graphics Programmer:** performance budget for the points in R1 (atlas, shadow limit, timer redraw, texture count), and a view on the spike.
- **Level / World Designer, Gameplay / Champion Designer, Systems Designer, Esports Manager, Technical Designer:** the cuts and asks for the arena HUD are in 6.7.1 and 6.7.12 (strip heights, label and tag lengths, short feed form, commentary slots, `Report.story`).
- **Lead Game Designer:** the helper is **Coach** and the player is the **Manager**; GDD v1 line 12 ("owner and head coach") and 7.8 ("the coach's second lever") should follow (`TUTORIAL.md` section 13).
- **Narrative Designer:** the Coach strings in `TUTORIAL.md` section 13, the "Form" switch label (7.4), one contest name set for feed and Report chips (6.7.5).
- **UI/UX Designer (me), next:** tutorial flow (`docs/design/TUTORIAL.md`, v1.2 matches this spec) uses the id mapping in 7.3 and the sheet contract; after the Founder checkpoint, a pixel-level pass on each screen (spacing, states) once the art bible lands.
- **Narrative Designer:** the copy list in 7.4; display names of at most 12 characters.
- **Lead Game Designer and Systems Designer:** decide on the inert-controls question (7.6 item 1) and the kills source (item 2).
- **QA Manager / QA Automation:** the 72-image matrix, the fixtures and the five audits (7.1).
- **Studio Manager:** nothing has been run; every size here is a paper estimate until step 0 and step 1 are done.
