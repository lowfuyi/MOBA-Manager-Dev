# UI Pass 2: layout redesign spec (workstream W3)

Date: 2026-11-08 · Author: UI/UX Designer · Status: spec for review (Art Director, Lead Game Designer, QA Manager), then the Founder checkpoint. No game code was changed.
Answers Founder feedback 3: "everything is displayed linearly, the design is boring" (see `docs/ALPHA-0.7-PLAN.md`).
Scope: Home, Squad, Draft, Game Plan, Standings, Match Report. Visual styling (colour, gradients, type, glow, illustration) is the art bible's job; here it is only referenced ("see the art bible"). This document fixes structure, hierarchy, sizes and interaction. The tutorial spec (W1) and the art bible (W2) are written in parallel; section 7 lists the hooks they need from this spec.

## 0. Summary for the Founder (read this first)

- **The problem is real and measurable.** In the Alpha 0.6 screenshots, every screen is one column of same-looking cards; Home needs a scroll to show its four tiles, the Game Plan puts a 590 px text block above all its controls, the draft is a text grid with no pictures, and the Standings tab names break in the middle of a word ("Playo-ffs", "Trophi-es").
- **The plan.** Each of the six screens gets one strong shape instead of a stack:
  - Home: a club header with badge, one raised "next match" card, a swipe row of upcoming games, a 2 x 2 tile grid.
  - Squad: your five starters placed on a small lane map (like the arena), the bench as portrait cards, a swipe row of free agents.
  - Draft: a five-lane board (you on the left, them on the right) above a grid of hero pictures; a bottom sheet to confirm.
  - Game Plan: a timeline (Overall, Early, Mid, Late) with big stepped sliders, and the expected result always visible on top.
  - Standings: a podium for the top three, your own row highlighted and pinned, a bracket for the playoffs.
  - Report: a three-part story strip (Early, Mid, Late), one big hero number, then what changed.
- **One decision per screen stays.** Home: play. Squad: who plays which role. Draft: this ban or pick. Game Plan: how we play. Report: continue. Standings has no decision; it answers "where do I stand and what do I need".
- **Two things I need you to know.** (1) To meet the 16 sp / 48 dp rule on a 360 dp phone, text and buttons get about 15 percent bigger than today (body 28 to 32 px, buttons 92 to 96 px). Today many buttons are only 64 to 76 px, which is 32 to 38 dp: too small. (2) Everything here needs pictures (badges, portraits, icons). Until Art delivers, the build uses code-drawn placeholders (initials on a coloured disc), so the layouts are never blocked.
- **Recommendation:** approve the layouts below; start building with Home, Draft and Report because they are on every match day. Decisions are in section 9.

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

| Token | Now | Pass 2 | Reason |
|---|---|---|---|
| `S_BODY` (anything the player reads to decide) | 28 | **32** | 16 sp |
| `S_SMALL` (captions, units, hints) | 22 | **26** | 13 sp; never the only place a key fact lives |
| Chip text | 20 | **26** | readable |
| `S_BIG` / `S_TITLE` | 38 / 46 | **40 / 48** | keeps the ratio |
| `S_DISPLAY` (new: result word, hero stat, podium points) | 64 ad hoc | **72** | one display size |
| Button height (`BTN_H`) and minimum hit area | 92 / 64+ | **96 / 96** | 48 dp |
| Header height and header icon buttons | 80 | **96** | 48 dp |
| Tab bar buttons / `TAB_H` | 88 / 104 | **96 / 112** | 48 dp |
| `R_CARD` / `GAP` | 20 / 14 | **24 / 16** | softer, more air |
| Screen side margin | 24 | 24 | unchanged |

Rule for captions: 26 px text may not carry a number the player needs to decide (put it in 32 px); a caption is at most one line, or two when it wraps.

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

The colour-blind palette swaps good/bad to sky blue (`56b4e9`) and vermillion (`d55e00`). Problems the current code has, and the rules that fix them:
- In colour-blind mode, "good" (sky blue) is nearly the same as the Blue-side colour (`5aa9ff`), and "bad" (vermillion) is close to the Red-side colour (`ff7a7a`). **Rule: a side is never told by colour alone.** In every board, "You" is always on the left and "Them" on the right (whichever side you play), with a small B or R pip for the side.
- **Rule: good/bad is never colour alone.** Every green or red value carries a sign (+ or -), an arrow glyph (up, down, flat), or a tick or cross shape. Row tints and fills are reinforcement only.
- **Rule: selected is never hue alone.** Selected = filled background + ring + check or thumb notch.
- **Rule: role identity = icon + short code (TOP, JG, MID, BOT, SUP), colour second.** Role colours must come from a colour-blind-safe set and must not reuse the good/bad or coral/teal hues (see the art bible for the values).
- **Rule: colour follows the word.** If the word says "fine", the colour is neutral (fixes `19_hub_after`). A comparison is coloured from the player's point of view (fixes the +12.0% opponent bonus in `11_draft_done`).
- Teal vs coral (accent vs primary action) stay distinct by position and shape: coral is only ever the one big "go" button.

## 3. Layout ideas evaluated

| Idea | Verdict | Where, and why |
|---|---|---|
| Hero header with club badge + next-game card with depth | **Use (Home)**; a smaller version as the result hero on Report | Gives Home an identity and one obvious thing to do. Card overlaps the header by 64 px for depth. Not used elsewhere: a hero on every screen would eat the space the controls need. |
| Two-column tile grids | **Use** | Home tiles (exists, made richer); Squad bench (2 columns of portrait cards); Game Plan "where you stand" (2 x 2 meters). **Reject** for Game Plan controls and the draft board: they are text-heavy and need the full width. |
| Horizontal carousels | **Use, only for secondary content**: Home "Up next", Squad "Free agents" | Both are "look around" content, so hiding half of it off-screen is fine; each has a "See all" button so a swipe is never the only way. **Reject** for the bench (5 cards: a grid shows all of them at once), the hero pool (40 heroes: needs filter and full view) and anything the player must decide on. |
| Player cards as a portrait grid with role colour and status chips | **Use** (bench, free agents, picker) | Replaces long text rows ("Brikai - Top - age 24 - 48  -  tired -3  -  in form, happy"). **Adapt**: the starting five are not a grid but a lane map (below). |
| Lane map for the starting five (new idea, from the UI reference v1 backlog UI-5) | **Use (Squad)** | Five tokens placed like the arena map; answers "who plays where" at a glance and shares the map with the W4 arena. |
| Draft board with five role lanes per team + hero grid below | **Use (Draft)** | You left, them right, one row per role, bans under it; a 4-column hero grid below. Compact (52 px rows) at 1280 px height, full (72 px rows) on taller phones. |
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
2. **Section header.** Title (32 px, accent colour) + optional count chip + optional action on the right ("See all", a mini segmented control). 56 px high, action hit area 96 px. Always the same, so the eye learns it. A "?" help slot (96 x 96) lives in the screen header for W1.
3. **Screen header.** 96 px: back (96 x 96), title, up to two icon actions (96 x 96 each), help "?". Title may wrap to two lines.
4. **Chip.** Passive status tag (44 px high, 26 px text, icon + word). Tappable chips are `Segmented` options or buttons, not chips. Status chips always have an icon so the meaning does not hang on colour.
5. **Segmented control.** 2 to 4 options, equal width, 96 px high, never wraps inside a word. If any label does not fit its slot (large text), it becomes a horizontally scrolling strip with the selected item scrolled into view. 5 or 6 options (role filter) are stacked icon over a three-letter code.
6. **Bottom sheet.** The only way to pick, confirm or inspect. Close by: drag down, tap the scrim, a close button, or Android Back (Back closes the sheet before it leaves the screen). Primary action pinned in the footer, 104 px.
7. **Empty state.** Illustration slot (384 x 288), one line of what is empty, one line of why or what to do, one action button. Never a blank screen (today's `17_standings_results` and `09_draft_start`).
8. **Preview, then commit.** Any change that moves a number shows the change (+3, -1.8, arrow) before the tap; reversible commits show an Undo toast (`Main.toast` already supports an action button); irreversible ones (release player, leave draft) use a confirm sheet.
9. **One coral.** Coral is reserved for the one "go" action of a screen (Play, Pick, Start the match, Continue). Nothing else on the same screen is coral.
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
- SectionHeader: 56 px; title 32 px; optional count chip; optional right action (hit 96). ScreenHeader: 96 px; back 96; title 40 px; up to two 96 px icon buttons; "?" 96 px.
- States: action pressed/disabled. Title wraps to two lines before it ever clips.

### 5.3 Chip (extends `UI.chip`)
- Anatomy: icon (28) + text (26) + padding 16/8. Height 44, radius 22. Variants: `neutral`, `good`, `bad`, `warn`, `accent` (tint of the colour at 16 percent + border at 45 percent, as now), each with its own icon so colour is never the only cue.
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

### 5.6 PlayerCard (portrait)
- Variants: `Tall` 330 x 264 (grid cell, 2 columns; reflows to 283 wide at 626 px), `Row` 672 x 112 (picker and report rows), `Token` 128 (lane map), `Mini` 56 (draft board, standings).
- Anatomy (Tall): portrait 120, name (32, up to 2 lines), role pill (icon + code), age, big "rating here" number (40) with caption, status chips (max 2 + "+n"), role colour as an 8 px bar on the left edge.
- States: normal; selected (ring); starter (small "starts" tag so the bench cards are distinct); disabled (not in club); loading portrait (monogram on the club colour).
- Data: name, `role_primary`, `age_of`, `slot_score`, `fatigue_of`, `form_of`, `morale_of`, `seasons_left`.
- Sketch:
```text
 PlayerCard Tall 330 x 264        PlayerCard Row 672 x 112     Token 128
 +---------------------------+    +----------------------------+  .------.
 | .------.  Brikai          |    | .----. Brikai  [Top]  48   |  | face |56
 | | face |  [Top] age 24     |    | |face| [v tired] [final]    |  '------'
 | | 120  |                   |    | '----'                     |  Soldor
 | '------'  48 here         |    +----------------------------+  (v)  (^)
 | [v tired] [contract: last]|
 +---------------------------+
 role colour = 8 px bar on the left edge + role icon; never colour alone
```

### 5.7 HeroCard (draft grid)
- 156 x 196 (4 columns at 672, 3 at 578). Portrait 156 square, name 26 px on one line, number chip, patch arrow, archetype icon.
- Name fit (measured from `10_draft_ban_2`: "Gravenstone" is 135 px wide at 22 px, so about 160 px at 26 px): a 156 px card holds a name of up to 9 characters (about 131 px). 38 of the 40 hero names qualify; **Gravenstone (11) and Tanglewick (10) do not.** Rule: hero display names are at most 9 characters (a data check fails on a longer one); hand-off to Narrative/Systems to rename or add a short display name. Until then the grid clips with an ellipsis, and the full name appears on the board and in the sheet. At 3 columns (183 px cards, large text) every current name fits.
- States: normal, recommended (coach star + coral border), banned (grey + X, not tappable), picked (tick + side stripe, not tappable), pressed.
- Sketch:
```text
 HeroCard 156 x 196
 +--------+
 |[* img ]|  top-left: coach star   top-right: archetype icon
 |[ 156  ]|  banned: grey + big X   picked: tick + side stripe
 | Veshra |  name 26 px, one line, 11 characters fit
 | ^ 82   |  bottom-left: patch arrow;  bottom-right: number (threat or familiarity)
 +--------+
```

### 5.8 LaneRow and LaneBoard (draft)
- LaneRow: 52 px compact or 72 px full; left slot (portrait Mini + hero name or "Open" + player name), centre role icon (40), right slot mirrored. LaneBoard = header + 5 LaneRows + bans row.
- States per slot: empty (dashed outline, player name shown so the player sees who plays here), pulsing (this lane is the pick target), filled, banned.

### 5.9 Carousel
- Horizontal scroller with snap and a 48 px peek of the next card; card widths 300 (free agents) or 560 (upcoming games); a page-dots line when 3 or more cards; direction lock (a drag that starts mostly vertical scrolls the page, a drag that starts mostly horizontal scrolls the carousel; threshold 12 px). Always paired with a "See all" action. Empty state when 0 cards.

### 5.10 EdgeMeter
- A centre-zero bar 24 px high: left half = them, right half = you; fill length = the edge; the value is printed as signed text (+5.6%), 32 px. Used in Game Plan (contests) and Report (phase margin). Colour is reinforcement only (rule in 2.4).

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
- Podium: 3 columns (2nd, 1st, 3rd), pedestal heights 88 / 120 / 64, badge 96 (1st: 120), name 2 lines, points 40 px.
- RankRow: 672 x 104: rank (56) + badge (56) + name (1 or 2 lines) + right column (points 36 over record 26). Own row: PANEL3 fill + 8 px accent bar + "YOU" pill (text). Playoff line: dashed divider with a label after rank 4.
- Sketch:
```text
 RankRow 672 x 104 (own row: PANEL3 fill + 8 px accent bar + YOU pill)
 | 9 | (b 56) | Northreach Corsairs  [YOU]            0 pts |
 |   |        | 0-1                                    ...  |
 Right column: points 36 px over record 26 px. Name takes 1 or 2 lines.
```

### 5.14 HeroStat
- Display number (72) + one sentence (32) + two chips (best, worst). Counts up. Used in Report; reusable for Home milestones later.

### 5.15 EmptyState, IconButton, Toast
- EmptyState: illustration slot 384 x 288, title 32, helper 26, action 96. IconButton: 96 x 96 with accessible name. Toast: exists in `main.gd`; keep, set min height 96 when it has an action.

### 5.16 Proposed API (for engineering; names are suggestions)
`UI.depth_card(parent, elevation := 1, tint := PANEL, selected := false) -> VBoxContainer`; `Segmented.new(options, selected, on_change, fit := "auto")`; `BottomSheet.open(title, build_content: Callable, build_footer: Callable, size := "M")`; `PlayerCard.make(pid, variant, opts)`; `HeroCard.make(hid, state, opts)`; `PhaseStrip.new(phases, selected, on_select, vertical := false)`; `DetentTrack.new(id, value, on_change, labels)`; `EdgeMeter.new(value)`; `Podium.new(rows)`; `Carousel.new(card_w, items, see_all)`.

## 6. Screen specs

Wireframe key: the frame is 720 px wide (1 character is about 10 px across; heights are written beside the frame). `(b)` = club badge, `[ ]` = a tappable control, `[x]` / `(x)` = a filled state (or a cross, where the text says lost), `ok` = tick, `[v]` `[^]` = down and up arrow glyphs, `(+)` `(-)` = ahead and behind, `face` = portrait. Each frame shows the normal-text case at 720 x 1280.

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
|~~ club-colour gradient + arena skyline art, under status bar ~~      |  <- hero 0-248
|  .--------.   Northreach Corsairs                            [ ? ]   |
|  | BADGE  |   Season 1 - Round 1 of 18 - Patch P1                    |
|  |  128   |   Rank #9    0-1    (L)(-)(-)(-)(-)   last five games    |
|  '--------'                                                          |
| +----------------------------------------------------------------+   |  <- card top y=184
| | NEXT LEAGUE GAME - ROUND 1                       [ Red side ]  |   |
| |                                                                |   |
| |   (BADGE 112)              VS              (BADGE 112)         |   |
| |   Northreach                                Mossgate           |   |
| |   Corsairs                                  Wardens            |   |
| |                                                                |   |
| |  You 53.5 [=========teal=====|=======coral======] Them 51.5    |   |
| |  [short draft] [+0.9% chem] [5 tired]                          |   |
| |  [        PLAY GAME   (coral, 104 px)                       ]  |   |  <- the one coral
| |        Auto-play this game   (text button, 96 px hit)          |   |
| +----------------------------------------------------------------+   |  <- bottom y~850
|  [! 5 tired starters  >]  [! 10 contracts end  >]   (swipe)          |  <- needs you 96
|  UP NEXT                                            See all  >       |  <- header 56
| - - - - - - - - - - - - - - fold at y~1132 - - - - - - - - - - -     |
|  +--------------+ +--------------+ +--------------  (peek 48 px)     |
|  | R2  (b) Foxes| | R3  (b) Owls | | R4 ...                          |  <- cards 200
|  | Blue - even  | | Red - harder | |                                 |
|  +--------------+ +--------------+ +--------------                   |
|  +--------------------------+ +--------------------------+           |
|  | STANDING                 | | CASH                     |           |
|  | #9  of 10   [ladder]     | | 2,617   (^) +17 a week   |           |
|  | 0-1 - 0 pts              | |                          |           |
|  +--------------------------+ +--------------------------+           |
|  | CHEMISTRY                | | SQUAD MOOD               |           |
|  | +0.9%  (ring gauge)      | | (face) fine   form 0.0   |           |
|  +--------------------------+ +--------------------------+           |
| [ Home ][ Squad ][ Plan ][ Club ][ More ]   tab bar, 96 px buttons   |
+----------------------------------------------------------------------+
```
Notes on the frame:
- The hero header is 248 px, full bleed under the status bar (art and gradient from the art bible, tinted with the club colours). Badge 128 on the left, club name 48 px (two lines if needed), season line 26 px, rank + record + five form pips (a pip is a circle with the letter W or L inside, so it is not colour alone).
- The Next match card is raised and overlaps the hero by 64 px. It is the only raised card on the screen. Play is the only coral element. Auto-play drops to a text button (still a 96 px hit area), because it is the less common path.
- The welcome tip card disappears from the layout: W1's coach overlay replaces it. Until W1 ships, a tip renders as a one-line banner (96 px) under the hero, not a 280 px card.
- "Needs you" appears only when something needs a decision: a horizontal strip of tappable warning chips (96 px high each), swipeable when there are more than two.
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
- Tap a "Needs you" chip: goes to the place that fixes it (Squad, or Finance), as now.
- Swipe the "Up next" carousel; tap a card: sheet (size S) with the opponent's rating, table position, Form rank and your last result against them (no commit, read-only). "See all" opens a sheet (size L) listing every remaining fixture (round, side, opponent).
- Tap a tile: Standing opens Standings; Cash opens Finance; Chemistry opens Team chemistry; Mood opens Squad.
- Long-press the badge in the hero: nothing in 0.7 (reserved for club details). No long-press is required for anything on this screen.
- Pull and swipe: vertical scroll only on the page. The needs strip and the carousel scroll sideways only.

#### (e) Large text and colour-blind
- Large text (626 px logical): hero badge 96, hero 220 px high; the club name may take two lines; Next card badges 96, names two lines; the chips row wraps to two lines; tiles stay two per row (283 px wide each, values 40 px, captions wrap to two lines); the carousel peek stays 48 px. Play remains above the fold (about y 840 of a 965 px fold); the carousel and tiles are below it.
- Colour-blind: form pips carry the letter W or L; the versus bar uses teal vs coral (not the good/bad pair); "Favoured / Even / Underdog" is a word with an arrow; the cash trend is an arrow glyph plus a signed number; the mood word and its colour agree (neutral for "fine").

#### (f) One primary decision
"Play the next game." It is the only coral element and the first thing visible. Everything else on Home is secondary and sits below or beside it.

---

### 6.2 Squad (`screen_roster.gd`, tab "squad"; also opened from the Match day screen with the tab bar hidden)

#### (a) Diagnosis (`05_roster`, `06_roster_picker`, `07d_free_agents`; detail judged from code)
- A 440 px "Team rating" card with a hint, three text lines and two big buttons sits above the lineup; the lineup itself starts at y 600 and fills the rest of the screen, so the bench is two screens away (`05`).
- The lineup is five identical centred buttons ("Top: Soldor (56)"). No face, no role cue, no status; a tired or unhappy starter looks the same as a fresh one until you read a suffix of text.
- Tapping a slot inserts a list of up to ten more identical buttons inside the card and pushes everything down (`06`); the lineup you are editing is no longer visible.
- The bench rows are long strings ("name - role - age - rating  -  tired -3  -  in form, happy") that wrap badly in large text; the player detail opens inline under the row with eight stat bars, a career log, contract and release buttons: one very long page (from code).
- "Team chemistry" and "Free agents" are two wide buttons inside the header card; free agents are another list of identical two-line buttons (`07d`).
- Touch size: slot buttons are 76 px (38 dp), picker rows 66 px (33 dp).

#### (b) New layout
```text
+----------------------------------------------------------------------+
| SQUAD                                    [ Auto lineup ]   [ ? ]     |  <- header 96
| [Rating 53.5] [Chem +0.9% >] [Squad 10/10] [Wages 265/wk]            |  <- strip 120
| STARTING FIVE      tap a token to change who plays the role          |  <- header 56
| +----------------------------------------------------------------+   |  <- map 672x440
| | lane-map backdrop (same map as the arena, see W4)              |   |
| |  TOP                                          JUNGLE           |   |
| |  .------.                                     .------.         |   |
| |  | face | 56                                  | face | 50      |   |
| |  '------' Soldor  (v)                         '------' Yorric   |  |
| |                           MID                                  |   |
| |                          .------.                              |   |
| |                          | face | 52                           |   |
| |                          '------' Caeldor                      |   |
| |                                    SUP            BOT          |   |
| |                                   .------.       .------.      |   |
| |                                   | face | 52    | face | 58   |   |
| |                                   '------' Lummir'------' Talfin|  |
| +----------------------------------------------------------------+   |
| BENCH (5)                                       sort: rating  v      |  <- header 56
| +---------------------------+ +---------------------------+          |
| | .------.  Brikai          | | .------.  Nyxwyn          |          |  <- card 330x264
| | | face |  [Top] age 24     | | | face |  [Bot] age 20     |        |
| | '------'  48 here         | | '------'  43 here         |          |
| | [v tired] [contract: last]| | [^ in form]               |          |
| +---------------------------+ +---------------------------+          |
| ... 3 rows (5 players + 1 market card)                               |
| REINFORCEMENTS (free agents)                      See all  >         |  <- header 56
| +--------------+ +--------------+ +--------------  (peek)            |  <- cards 300
| | face Eldvik  | | face Bramgus | |                                  |
| | Jg - 23      | | Bot - 24     | |                                  |
| | 60 (pot 68)  | | 54 (pot 61)  | |                                  |
| | asks 44/wk   | | asks 29/wk   | |                                  |
| +--------------+ +--------------+ +--------------                    |
| [ Home ][ Squad ][ Plan ][ Club ][ More ]                            |
+----------------------------------------------------------------------+
```
Notes on the frame:
- The **lane map** is the hero of the page: five 128 px tokens placed on a small map in the same arrangement as the arena (Top upper left, Jungle upper right, Mid centre, Bot and Support lower right; exact positions come from the W4 map; placeholder positions in percent of the map: TOP 18/20, JG 68/28, MID 45/50, BOT 80/80, SUP 58/84). The map is a 672 x 440 inset card; tokens scale with the card width. Each token: face, role code ring, rating badge (36 px) on one corner, one status icon (tired, in form, out of form, off-role) on the other, the name under it (26 px).
- The **team strip** is four stat pills (rating, chemistry, squad count, wages) instead of a text card; chemistry is tappable.
- The **bench** is a 2-column portrait grid (Tall cards). The sixth cell holds a "Find a player" card that opens the free-agent market.
- **Reinforcements** is a carousel of free agents (top six by rating) with "See all".
- Match-day variant (opened from the Match day screen): no tab bar; a pinned footer button "Done" (coral is not used here: Play is not on this screen, so "Done" is teal) returns to the Match day screen.

Lane picker sheet (opens when a token is tapped):
```text
+----------------------------------------------------------------------+
| (map visible and dimmed behind the scrim; sheet is 60% of the height)|
| +----------------------------------------------------------------+   |
| |                         -------  (grab handle, 96 px hit)      |   |
| | WHO PLAYS MID?                                        [ close ]|   |
| | +------------------------------------------------------------+ |   |
| | | .----. Caeldor  [Mid]            52 here       now playing | |   |
| | | |face| form 0.0 - morale ok                                | | | |
| | | '----'                                                     | |   |
| | +------------------------------------------------------------+ |   |
| | | .----. Talfin   [Bot] [off-role]  44 here    -8 (v)        | |   |
| | | |face| swaps with Talfin <-> Caeldor: team -1.8            | | | |
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
| Tokens | `gs.lineup()` (slot -> player), `w.slot_score(p, s)`, `w.player_fit(p, s)` (below 1.0 = off-role icon), `w.fatigue_of`, `w.form_of`, `w.morale_of` (the same thresholds as `UI.fatigue_tag` and `UI.mood_tag`), portrait asset by player id |
| Bench cards | `w.club_players(gs.club())` minus starters, sorted by `_best`; `w.age_of(p)`; `gs.seasons_left(pid)` for the contract chip; `p["role_primary"]` |
| Picker sheet rows | candidates sorted by `w.slot_score(p, slot)` (as `_picker` does now); the delta = `w.team_rating(lineup_with_swap) - w.team_rating(lineup)` computed on a copy of `gs.lineup()` (NEW small helper); the swap note comes from `gs.assign` (it swaps when the player already starts elsewhere) |
| Commit | `gs.assign(slot, pid)` then `App.autosave()`; an Undo toast restores the previous `d["lineup"]` |
| Auto lineup | `gs.reset_lineup()` with an Undo toast |
| Player detail sheet | `PlayerView.stat_block`, `PlayerView.career_section`, `PlayerView.best_heroes_line`, `PlayerView.contract_text`, `gs.can_release`, `gs.release_cost`, the existing renew and release calls |
| Reinforcements | `gs.fa_players()` top six by rating, `gs.asking_wage(pid)`; opens `ScreenNegotiation` as now |

#### (d) Interactions
- Tap a token: lane picker sheet (size M, opened with the rows already scrolled so the current player is visible). Each row shows the change in team rating if you tap it, so the number is the preview. Tap a row: commits, closes, toast "Talfin now plays Mid" with Undo.
- Tap a bench card: player detail sheet (size L) with a segmented control Overview | Stats | Career. Overview: face 160, status bars (fatigue, form, morale as three 24 px bars with signed numbers), contract line, bond line, best heroes. Footer: "Put in lineup" (opens the lane picker for this player's best role), "Renew" when the contract ends within one season, and "Release" (a second sheet asks to confirm, with the cost, exactly as the current confirm text).
- Long-press a bench card (400 ms): lifts it; drag it onto a token to swap. This is an accelerator only; the tap path always works. (Untested on touch: see risks.)
- Swipe the Reinforcements carousel; tap a card to negotiate; "See all" opens the full Free agents screen.
- "Auto lineup" (header): applies the best rested lineup, with Undo. Tapping the chemistry pill opens Team chemistry.
- Back: inside a sheet, closes the sheet. On the Match day variant, returns to Match day.

#### (e) Large text and colour-blind
- Large text: the map card is 578 x 380 and tokens are 112 px; names may wrap to two lines under tokens; the team strip becomes 2 x 2 pills; the bench grid keeps two columns (283 px cards, portrait 100, name two lines, only one status chip shown plus "+n"); Reinforcements cards 280 px. The first row of the bench stays visible below the map on a 1113 px canvas only if the strip collapses to one row; if not, the bench starts below the fold, which is acceptable because the lineup (the decision) is fully visible.
- Colour-blind: status is an icon plus a word (in the sheet and on cards) and the picker delta is a signed number with an arrow; off-role is an icon plus the words "off-role"; the role ring has the role code letters; the selected token has a ring and a check, not just a colour.

#### (f) One primary decision
"Who plays which role." The map and its five tokens are the whole top of the page; the bench and the market exist only to feed that decision.

---

### 6.3 Draft (`screen_draft.gd`, no tab bar)

#### (a) Diagnosis (`09_draft_start`, `10_draft_ban_2`, `10_draft_slotpanel_4`, `10_draft_slotpanel_8`, `11_draft_done`)
- While the other side chooses, the screen is nearly empty: a plain-text board and one floating button in 700 px of black (`09`). The most exciting moment of the loop looks like a waiting room.
- The hero pool is text only: two columns of buttons reading "Veshra / Shade their best 82". 40 heroes with no faces, no roles, no sense of who counters whom. The only meta cue is green or grey text colour, which a colour-blind player cannot read.
- The board is a three-column text grid with Blue first, so "my side" changes position from game to game; picks are names without pictures.
- The timer is a text "10 s"; nothing warns that it is running out except the colour turning red at 3 seconds.
- Choosing a hero replaces the whole page with a slot list (`10_slotpanel_*`): the board disappears, so the player cannot see which lanes are already filled while choosing one. Five identical wide buttons.
- Draft complete (`11`): two text cards listing the picks, then two stacked buttons; the composition lines are both green although the opponent's +12.0% is bad for the player.
- Touch size: the back button is 80 x 64 px (32 dp high); the "advisor" button is 68 px.

#### (b) New layout (compact board, the 1280 px case)
```text
+----------------------------------------------------------------------+
| [<]  YOUR TURN: BAN                      ( 8 s )   [ Auto-finish ]   |  <- header 104
| steps: [x][x][ ][ ][ ][ ][ ][ ][ ][ ][ ][ ]   ban short, pick tall   |
| YOU                          ROLE                          THEM      |  <- board 330
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
| | * COACH SUGGESTS   Veshra  (Shade)                    [ Take ] |   |  <- scrolls
| +----------------------------------------------------------------+   |
| +--------+ +--------+ +--------+ +--------+                          |
| |[* img ]| |[ img  ]| |[ img  ]| |[ img  ]|                 4 columns|
| | Veshra | |Gravens.| |Ottomere| |Sparrowe|    card 156 wide         |
| | (S) 82 | | (B) 77 | | (B) 76 | | (G) 75 |   number = threat        |
| +--------+ +--------+ +--------+ +--------+                          |
| +--------+ +--------+ +--------+ +--------+  ... scrolls (40 heroes) |
+----------------------------------------------------------------------+
```
Notes on the frame:
- **Header (104 px):** back (96), "YOUR TURN: BAN" (40 px, wraps to two lines in large text), timer ring (72 px circle that drains; digits inside; at 3 s or less it turns the warning colour, shows a "!" and pulses), and "Auto-finish" (text button, 96 px hit). The 12 (or 16) step segments underneath show the whole order: bans are short bars, picks tall, the current one is highlighted, done ones carry the side pip.
- **Board:** You are always on the left, Them on the right, with a B or R pip for the side. Rows are 52 px compact (portrait Mini 44 + hero name; open slots show "Open" and the player's name so you can see who plays the lane) or 72 px full when the available height allows (rule below). Bans sit under the lanes (one slot at short drafts, three at full).
- **Needs strip (56 px):** the existing "Frontline / Initiator / Wave clear" checklist as ticked or empty chips; once three heroes are picked it adds the live composition style chip ("Skirmish +2.0%").
- **Role filter (segmented, 96 px):** All, Top, Jg, Mid, Bot, Sup, with a tick on a role whose lane you have already filled. It filters by `role_primary` or `role_secondary`; "All" is the default. It never hides what the sim allows (off-role picks stay legal).
- **Hero grid:** 4 columns of HeroCards (156 x 196); sorted exactly as today (by familiarity times fit, or by their best in the ban phase), so the best candidate is top left. The first row of the scroll area is the **Coach suggests** bar (88 px) with a one-tap "Take" (this is today's "Take advisor's choice").
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
| | [      PICK FOR BOT CARRY - TALFIN     (coral, 104 px)      ]  |   |
| +----------------------------------------------------------------+   |
+----------------------------------------------------------------------+
```
Draft complete (replaces the two text cards):
```text
+----------------------------------------------------------------------+
| DRAFT COMPLETE                                           [ ? ]       |  <- header 96
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
| [          START THE MATCH      (coral, 112 px)            ]         |
+----------------------------------------------------------------------+
```

#### (c) Data and functions feeding each block
| Block | Source |
|---|---|
| Step segments, header | `draft.current()` (`team`, `kind`, `n`), `draft.order`, `draft.step`; timer `_time_left`, `_limit` (10 s short, 15 s full) as now |
| Board | `draft.picks[team]` (slot -> hero), `draft.bans[team]`, `draft.lineups[team][slot]` (player name for open slots), `App.world.heroes` for portraits |
| Needs strip | the existing `_needs_of(heroes)` and `Comp.evaluate(heroes)` (once 3 or more picks) |
| Role filter | `hero["role_primary"]`, `hero["role_secondary"]`; filled lanes from `draft.open_slots(my_side)` |
| Hero grid | `draft.avail`, the existing `scored` list (familiarity times `hero_fit`, or threat in the ban phase), `draft.meta[hid]` for the patch arrow (up if above 1.015, down if below 0.985, flat otherwise), archetype icon from `hero["archetype"]` |
| Coach bar | `draft.ai_choice()` (as now) |
| Pick sheet | hero fields (`archetype`, `tags`, `damage_type`, `power_early/mid/late`, `difficulty`, `strong_vs`), `w.hero_fit(h, s)`, `w.familiarity(p, hid)` for each open lane; the best lane = highest familiarity times fit (the inline `best_slot` logic in `_actions`; move it to a `Draft` helper, NEW) |
| Confirm | `_apply({"hero": hid, "slot": s})` for a pick, `_apply({"hero": hid, "slot": ""})` for a ban; timeout still applies `draft.ai_choice()` |
| Auto-finish | `_auto_rest()` (`draft.finish_with_ai()`), now with an inline "Sure?" second tap |
| Draft complete | `draft.picks`, `draft.lineups`, `Comp.evaluate`; NEW one number "net edge from the draft for you" = my `ev["mod"]` minus their `ev["mod"]`, coloured from my point of view; the Game plan button label from `GamePlan.is_neutral(...)` as now; launch via `ScreenDraft.launch(game, draft)` |

#### (d) Interactions
- Tap a hero card: opens the sheet (size M, about 52 percent of the height) with hero details, "Plays as" (a 5-option segmented control, filled lanes locked, the best lane preselected so the common case is two taps: hero, confirm) and one big confirm button ("Pick for Bot Carry - Talfin", or "Ban Veshra" with the danger variant). While the sheet is open the target lane on the board shows the hero as a ghost with the fit percentage.
- Ban phase: no lane control; the confirm button is "Ban Veshra".
- Tap "Take" on the coach bar: applies `ai_choice()` in one tap (this keeps the fast path for the 5-minute game).
- Tap a role in the filter: filters the grid; tap "All" to reset. No swipe gestures in the draft (a swipe would fight the scroll under a running timer).
- Long-press a hero card: peeks the same details as the sheet without the confirm button (a read-only sheet size S). Optional; a tap always gives the full sheet.
- Timer reaches 0: the coach choice is applied and a toast says so ("Time is up: coach picked Veshra").
- Back or Android Back: closes the sheet first; with no sheet open it asks "Leave the draft?" in a size S confirm sheet (today it leaves silently).
- "Auto-finish": first tap changes the label to "Sure?" for 3 s; a second tap finishes the draft with the advisor.

#### (e) Large text and colour-blind
- Large text: grid becomes 3 columns of 183 px cards (every current hero name fits on one line at 26 px, up to 11 characters); the header title wraps to two lines (header 128); the board is always compact with 48 px rows; the sheet is size L (68 percent) so the lane control and the confirm button both fit.
- Colour-blind: banned = grey plus a large X (not just dimmed); picked = tick plus the side stripe; recommended = a star shape; patch strength = an up, down or flat arrow glyph plus its percent in the sheet; the timer is a ring plus digits plus "!" at 3 s; the side is the left or right column with a B or R pip; the role filter uses icons and codes; the sheet's best lane is marked "best" in words.

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
|    2 dials          lead 2/4         lead 0/2      lead 0/2          |
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
- **Rows 4 to 10** use RankRow. A dashed **playoff line** after rank 4 (the top four qualify). Your row has a PANEL3 fill, an 8 px accent bar and a "YOU" pill (text, so it works without colour).
- **Pinned row:** when your row is scrolled out of view, a 96 px row pinned above the tab bar shows your rank, club and one sentence about the line ("1 win and 3 pts to the line", or "Safe: 5 pts clear of 5th"). It disappears when your own row is on screen.

Playoffs view (a drawn bracket):
```text
+----------------------------------------------------------------------+
| [<] Standings                                              [ ? ]     |
| [   Table   ] [  Playoffs  ] [  History  ]                           |
| CUT LINE: top 4 go through.  You are 5th, 3 points behind.           |  <- status line
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
- "Standout: Talfin ... decided 10% of the result" is a sentence without a face.
- Expanders use "+ " and "- " text prefixes (`15b`), not an icon.
- Touch size: expander headers are 70 px.

#### (b) New layout
```text
+----------------------------------------------------------------------+
| [<] Match report                                          [ ? ]      |  <- header 96
| +----------------------------------------------------------------+   |
| |  DEFEAT                              (display 72, with a shape)|   |  <- hero ~300
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
| | 53%   of the result was luck                 (display 72)      |   |  <- hero stat 180
| | A swingy game: a better plan would not have changed much.      |   |
| | Best: Bot lane +10%     Worst: Draft and composition -16%      |   |
| +----------------------------------------------------------------+   |
| WHAT THIS GAME CHANGED                                               |  <- 240
| (face)Soldor (face)Yorric (face)Caeldor (face)Talfin (face)Lummir    |
| form -1.4     form -1.4   form -1.4     form -1.4    form -1.4       |
| morale -2     morale -2   morale -1     morale -1    morale -2       |
| [Bonds 34 (^)] [Chemistry +1.0%] [Cash +8 (^)]                       |
| BEFORE THE NEXT GAME   10 contracts end this season.   [ Open squad ]|
| DIG DEEPER  v     [ Why | Players | Moments | Draft ]                |
| [          CONTINUE   (coral, sticky footer 112 px)          ]       |
+----------------------------------------------------------------------+
```
Notes on the frame:
- **Result hero (about 300 px):** the result word at display size with a shape (a flag for victory, a broken flag for defeat) so it is not colour alone; a **score line** (team kills, 72 px) between the two badges. The score is `Report.kda(res)` summed per team: it is display-only data that the sim already guarantees consistent (the winner always has more kills, one side's kills are the other's deaths). Under it: the margin word (`Report.result_word`), game length, and the series pips for playoff games.
- **The story (about 360 px):** a vertical timeline of three bands (Early, Mid, Late). Each band has a node tinted by the phase result (`res["sim"]["early"|"mid"|"late"]`, signed) with a plus or minus glyph, and chips for the phase's contests (Early: Top, Mid, Bot, Jungle; Mid: Objective, Fight; Late: Objective, Fight), each with a tick or cross; the margin word (narrow, clear, decisive) is shown as 1 to 3 dots on the chip and in words in the sheet. A one-line **story tag** above the strip names the shape ("Led early, lost the late fights", "Comeback"), chosen from the sign pattern of the three phases (a table of eight patterns; Narrative writes the words).
- **Hero stat (about 180 px):** one big number and one sentence: the single biggest factor in `Report.attribution`, by absolute share. If that is luck, the sentence says so plainly ("53% of this result was luck. A swingy game: a better plan would not have changed much."). Two chips: best factor and worst factor.
- **What this game changed (about 240 px):** the five starters as portrait chips in a wrapping row, each with form and morale deltas (signed numbers, arrow glyph), then three stat tiles (Bonds average, Chemistry, Cash). Replaces the nine-row table.
- **Tip card:** "Before the next game" with an optional single action link (for the tip about tired players: "Open squad"; contracts: "Open squad").
- **Dig deeper (collapsed):** a chevron expander that opens a segmented control (Why, Players, Moments, Draft). Why = the existing factor bars; Players = the kills, deaths and assists lines; Moments = the timestamped feed; Draft = the recap. One at a time instead of four stacked accordions.
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
| Standout player | the existing `_standout` logic (slot factor, `res["lineups"]`, `res["picks"]`), shown as a portrait chip in the changes row |
| What changed | `App.last_payoff` (`Payoff.compare`): `rows`, `bond_a/b`, `chem_a/b`, `cash_d` |
| Tip | `Payoff.tip(App.gs)` (`key`, `args`); the action link maps `tip.rest` and `tip.contract` to Squad, `tip.scrim` to Plan |
| Dig deeper | existing `_why`, `_lines`, `_moments`, `_draft_recap` content, one per segment |
| Continue | existing `_leave()` |

#### (d) Interactions
- Tap anywhere during the reveal: jumps to the final state. Tap a story band: sheet (size M) with that phase's lines with their clock times (the `_moments` lines for that phase) and the contests' margin words.
- Tap the hero stat: sheet (size S) that explains the number in plain words (the existing `report.why_note`, "from replaying the game without it").
- Tap a starter chip: sheet (size S) with that player's lines (K/D/A for this game, form and morale change) and "Open in Squad".
- Tap "Dig deeper": expands; tap a segment to switch content.
- Tap the tip link: goes to the named place (confirm if leaving would lose nothing: the report is saved, so no confirm needed).
- Back = Continue (as now). No swipes.

#### (e) Large text and colour-blind
- Large text: the early band's four chips wrap to 2 x 2 (four chips of 160 px do not fit in the 498 px beside the node); the five starter chips reflow 3 + 2; stat tiles become a 1-column stack; the score line stays 72 px on one line (it is two numbers); Continue stays pinned. In normal text hero (300) + tag (56) + story (360) + hero stat (180) + header (96) + gaps is about 1,040 px, inside the 1,096 px left above the sticky footer; in large text the hero stat is one scroll below, which is acceptable because the hero already shows the result.
- Colour-blind: result word has a flag shape and the word; contests use tick and cross glyphs with a count of dots (1 to 3) and the margin word in the sheet; phase verdicts have plus and minus glyphs; deltas are signed numbers with arrows; hero stat is a number and words.

#### (f) One primary decision
"Continue." The page is a reward and an explanation; the only thing to do is to move on. The tip's action link is secondary and optional.

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
2. Text size audit: no `Label` or `Button` font below 26 px; body text 32 px or above.
3. No mid-word wrap: for labels in Segmented and in chips, measure with the theme font and fail when a word is wider than its slot.
4. Reachability: the primary action of each screen is inside the visible area at 720 x 1280 and at 626 x 1113 without scrolling (Home Play, Draft grid and Coach bar, Game Plan Start, Report Continue, Squad tokens).
5. UI never writes to the sim: preview helpers (team rating after a swap, coach diff, edge preview) work on copies; a test asserts `gs.d` is unchanged after opening and cancelling every sheet.

### 7.2 Large text and colour-blind: the shared behaviours (so each screen does not re-invent them)

- Reflow, never scale-down: HFlow containers for chips, grids computed from width, columns collapse by priority (Standings: rank, badge, name, points always; record moves under points).
- Fixed parts (headers, hero strips, footers) are budgeted so a scroll area of at least 400 px remains at 917 px usable height. Where it does not, the hero shrinks (badge 128 to 96) before text shrinks.
- Text never goes below 26 px; if content does not fit, it wraps (up to two lines) or moves into a sheet.
- Palette: every status has an icon or glyph; the rules of section 2.4 apply to every new component, and a component is not done until it passes a colour-blind screenshot.

### 7.3 Hooks for the tutorial (W1) and the "?" help

Each component accepts a `tut_id`. Stable ids the coach overlay can spotlight (the W1 spec can use these directly; I will not rename them without telling W1):

| Screen | `tut_id` values |
|---|---|
| Home | `home.next_card`, `home.play`, `home.needs`, `home.upnext`, `home.tile.standing`, `home.tile.cash`, `home.tile.chem`, `home.tile.mood`, `tab.home`, `tab.squad`, `tab.plan`, `tab.club`, `tab.more` |
| Squad | `squad.map`, `squad.token.top` ... `squad.token.sup`, `squad.auto`, `squad.bench`, `squad.card.<pid>`, `squad.market`, `squad.sheet.picker`, `squad.sheet.confirm` |
| Draft | `draft.timer`, `draft.steps`, `draft.board`, `draft.lane.<slot>`, `draft.needs`, `draft.filter`, `draft.coach`, `draft.grid`, `draft.card.<hid>`, `draft.sheet.lane_control`, `draft.sheet.confirm`, `draft.auto` |
| Game Plan | `plan.edge`, `plan.chip`, `plan.phases`, `plan.control.<id>`, `plan.coach`, `plan.reset`, `plan.start` |
| Standings | `stand.views`, `stand.podium`, `stand.own_row`, `stand.metric`, `stand.line`, `stand.bracket` |
| Report | `report.hero`, `report.story`, `report.stat`, `report.changed`, `report.tip`, `report.dig`, `report.continue` |

Every ScreenHeader reserves the 96 x 96 "?" slot (right side) and a `help_key` so the explanation text can be looked up by screen. The layouts already leave that room; none of the wireframes needs to change when W1 adds the button.

### 7.4 New copy needed (Narrative Designer), all through `Strings`, none hard-coded

- Game Plan: a short end label pair per control (8 controls, 16 short words; for example Fight style: "Spread out" / "Group up"), phase names (Overall, Early, Mid, Late), contest short names (Top, Mid, Bot, Jungle, Objective, Fight), the "only the late-game part applies in this plan" line, the "uses your Default plan" caption, the Coach preview sheet text.
- Report: eight story tags for the phase patterns (+++, ++-, +-+, +--, -++, -+-, --+, ---), the hero-stat sentences (for a normal factor and for luck; the luck sentence must be honest, see 7.6), "Dig deeper" tab names (Why, Players, Moments, Draft), the tip action labels (Open squad).
- Standings: view names (Table, Playoffs, History), the cut-line sentences (above, on, below the line, and after the playoffs), "YOU", empty-state lines.
- Squad: sheet titles and the delta line ("team +1.2"), the swap note, "Find a player".
- Draft: header lines (they exist), the "Leave the draft?" confirm, "Time is up: coach picked X", "Sure?", filter names (All and five role codes).
- Everything is plain words, short, and counted against the 26 and 32 px slots in this spec.

### 7.5 Small additions to game code that these layouts need (engineering, no sim or balance change)

| Need | Where | Why |
|---|---|---|
| `GameState.upcoming(n)` | `game_state.gd` | Home carousel; read-only over `d["fixtures"]` |
| `GameState.cut_gap()` | `game_state.gd` | Standings pinned sentence; read-only over `standings()` |
| `Report.team_kills(res)` | `report.gd` | Report score line; sums `Report.kda` |
| Team rating after a swap (copy of the lineup) | helper in `roster` UI or `World` | Picker sheet preview |
| `Draft.best_slot_for(team, hid)` | `draft.gd` | The inline "best slot" logic in `_actions` moves out so the sheet can preselect |
| Club `colors` and `badge` ids | `data/clubs.json` + assets | Hero header, badges everywhere |
| Hero portrait, player portrait, icons | assets (section 8.4) | All screens |
| Per-control phase map | derived from `data/game_plan_v0.json` at load | Phase pips and inert controls |

### 7.6 Findings for other roles (found while designing, not mine to change)

1. **Lead Game Designer / Systems Designer:** on the "If behind" and "If ahead" plans, Lane aggression and Jungle focus have no effect (their contests are early; early contests always use the Default plan), and the early parts of Tempo, Fight style and Support are ignored (`game_plan.gd`: `_hooked`, `simulate`). The layout hides or marks them inert. Please confirm this is the intended rule; if the intent was a full plan swap, the sim, not the UI, should change (and the GDD 7.8 text should say which).
2. **Systems Designer / W4 owners:** the Report score line and the later arena scoreboard must show the same kills. `Report.kda` is the single source (it already guarantees winner has more kills); the arena should read it, not invent its own.
3. **W4 owners:** the Report's story strip uses the three phases and eight contests of `Report.FEED_ORDER`; the arena should use the same phase names (Early, Mid, Late) and contest names so the player sees the same story twice.
4. **Narrative / Lead Game Designer:** luck is the largest factor in the attribution of the sample loss (53 percent, `15_report_mid`). The hero stat will say so plainly; the "Results felt fair and believable" tester question may need a short explanation of what luck means ("the draw and the dice"), shown in the hero stat sheet.
5. **Data / Narrative:** hero names longer than 9 characters (Gravenstone, Tanglewick) do not fit the 156 px grid card at the required size. Rename or add a short display name.

---

## 8. Build order, risks, assets

### 8.1 Build order and rough sizes

Sizes are developer days for one Gameplay Programmer including their own testing; they are designer estimates with low confidence (no prototype yet). S about 2 days, M 3 to 4, L 5 to 7.

| Step | What | Size | Why here |
|---|---|---|---|
| 0 | Spike: nested horizontal-in-vertical scrolling, long-press drag, a sheet, and the cost of 40 cards with shadows, measured on the build computer with simulated touch (`ui_touch.gd` style) | S | Settles the three riskiest assumptions before the components are built; cheap |
| 1 | Tokens (section 2.2) + components 5.1 to 5.5 and 5.10 to 5.12, 5.15 with monogram placeholders for portraits and badges; re-shoot the 20 existing screens | L | Everything depends on it; the token change touches every screen, so it lands once |
| 2 | **Home** (hero, Next card, tiles; carousel last) | M | First thing the Founder sees; smallest data surface; proves the hero and card depth |
| 3 | **Draft** (board, grid, sheet, done state) | L | Biggest eyesore and the most-used screen in the loop; highest value |
| 4 | **Game Plan** (edge hero, PhaseStrip, DetentTracks, coach sheet, trigger rules) | M to L | Follows Draft in the loop; also fixes the dead-control problem |
| 5 | **Report** (hero, story, hero stat, reveal) | M | Closes the loop; also the payoff moment |
| 6 | **Squad** (lane map, bench cards, picker and detail sheets, market carousel) | L | Weekly use, not per match; biggest layout; needs the arena map for final token positions |
| 7 | **Standings** (podium, rows, bracket, history) | M | Read-only; lowest risk; can move up to step 2 if a safe early win is wanted |
| 8 | Polish and the full 72-image test matrix, audits of 7.1, fixes | M | Acceptance |
| (parallel) | Plan and Club tab tiles move to the 2 x 2 tile grid and new tokens (the two tabs are still stacked wide tiles, `04c_tab_plan`); the Match day screen adopts the new components | S | Not in the six screens but they will look out of place next to them |

About 38 developer days in total plus QA. If time is short, cut in this order: Home carousel, drag-to-swap on Squad, History mini story strips, Report starter chips sheet.

### 8.2 Biggest risks and what to do about them

| # | Risk | Why it matters | Mitigation |
|---|---|---|---|
| R1 | **Low-end phone performance.** Richer cards (shadows, gradients, portraits) and the current pattern of deleting and rebuilding the whole page on every tap (`_rebuild()` in Roster, Draft, Game Plan) | A grid of 40 shadowed cards or a 100-node rebuild per slider tap can drop frames on a 2 GB phone; the Draft also runs a timer every frame | Flat baked cards in grids (no live blur; at most 8 shadows on screen); update components in place; the timer ring redraws only when the displayed second changes; atlas the 40 hero portraits into one texture and decode player portraits only for the lineup, bench, opponent and visible free agents (about 25 at a time); no per-frame tweens on hidden nodes; measure before and after on the build computer, then on the Founder's phone |
| R2 | **Text overflow.** Longest strings: club names to 19 characters, hero names to 11, large text at 626 px, 4-column grids | The Standings tab bug and the 1-character-per-line `kv_row` bug are the same class (`UI-UX-REFERENCE-v1.md`, section 10) | Rules 2.3 (3) and (4); the fixtures and the audits of 7.1; a hero name length lint; components own their wrapping, screens do not |
| R3 | **Touch gestures are unverified.** Horizontal carousels inside a vertical scroll, drag-to-swap, sheet drag-to-dismiss and phase swipe can all steal each other's drags | A broken scroll is worse than a plain list; the existing comments in `ui.gd` show this was already a problem once (buttons stealing swipes) | Step 0 spike; every gesture has a tap alternative; direction lock with a 12 px threshold; drag-to-swap and phase swipe are the first features cut |
| R4 | **Token change ripples.** Body 28 to 32 and buttons to 96 lengthen every unredesigned screen (Finance, Training, Chemistry, Free agents, Settings, Match day) and may overflow them | A half-updated app looks worse than either version | Land tokens once in step 1, re-shoot all 20 existing screens, fix overflows in that step; budget in 8.1 includes it |
| R5 | **Art not ready.** Portraits, badges and icons are the biggest dependency | Layouts look empty without them | Every component ships with a code-drawn placeholder (monogram on role or club colour); no step waits for art; swap is a texture change |
| R6 | **Colour-blind collisions** (blue side vs good, red side vs bad) | A colour-blind tester cannot tell sides or results | Rules in 2.4; the colour-blind screenshot is part of every component's definition of done |
| R7 | **Information density on 16:9 phones.** The draft shows about 11 heroes at once; the Game Plan scrolls inside a fixed frame | A cramped feel on the very screen that should feel exciting | Board size rule (deterministic); tall phones get the full board; role filter and coach bar mean the player rarely scrolls; check on real phones |
| R8 | **Honesty of the report copy.** A luck-heavy loss framed badly feels like an excuse; a luck-heavy win framed as skill is false | Fairness is a tester question (W4 acceptance) | Hero stat copy is reviewed by Narrative and the Lead Game Designer; luck is always named as luck |
| R9 | **Scope.** Six screens, 16 components, two other workstreams in parallel | Late components block everything | Components are specified once here; screens only compose them; cut list in 8.1 |

### 8.3 What I could not check

Nothing here ran. I could not check scroll feel, gesture conflicts, frame time, texture memory, haptics, or whether the lane map reads at a glance; the heights are paper estimates. The first real evidence will be the step 0 spike, then the 72-image matrix, then the Founder's phone and a usability session with new testers (UI-12 in the reference doc, still open and needing real people).

### 8.4 Assets needed from the Art department

All art is original and goes to the IP & Originality Checker (the art bible sets the style). Counts and sizes are what the layouts above use; sources should be 2 times the largest display size so they stay sharp on 3x phones. Where I say "atlas", please deliver as sprite sheets so the engine can batch them.

| Asset | Count | Source size | Displayed at | Notes |
|---|---|---|---|---|
| Club badges | 10 | 512 x 512 (SVG master) | 128 (Home hero), 112 (Next card), 96 (podium), 56 (rows), 44 (chips) | Must be told apart by **silhouette and emblem, not only colour** (colour-blind). Plus primary and secondary club colours added to `clubs.json` |
| Hero portraits | 40 | 320 x 320, square bust, transparent edge | 156 (grid), 128 (sheet), 44 (board), 40 (chips) | One atlas, 2048 x 2048 or less; consistent framing so the grid reads as a set; archetype visible in the silhouette |
| Player portraits | 140 players (about 20 on screen at once) | 256 x 256 from a kit: face shapes, skin tones, hair, brows, mouth, club-coloured outfit | 160 (detail), 128 (token), 120 (bench card), 72 (rows), 56 (mini) | A **portrait kit** composed from parts and seeded by player id (140 hand-drawn faces is not realistic here); 3 expressions optional (neutral, tired, happy) |
| Role icons | 5 (top, jungle, mid, bot, support) | 128 | 48, 40, 32 | Mono and tinted versions; with the three-letter code |
| Archetype icons | 7 (bruiser, gunner, bulwark, shade, spellcaster, binder, mender) | 96 | 40 | Corner badge on hero cards |
| Tag icons | 8 (frontline, engage, pick, waveclear, protect, splitpush, poke, scaling) | 80 | 40, 28 | Sheet and chips |
| Status and UI glyphs | about 24 (tired, in form, out of form, happy, unhappy, contract ends, off-role, coach star, lock, tick, cross, ban X, arrow up, down, flat, help, back, close, chevron, coach wand, reset, branch, plus, minus) | 96 | 28 to 48 | Shapes must differ without colour |
| Phase and contest icons | 6 (overall, early, mid, late, objective, fight) | 96 | 56, 40, 32 | Lanes reuse the role icons |
| Game Plan control icons | 8 (fight style, tempo, mid objectives, late objectives, lane aggression, support, risk, jungle focus) | 96 | 40 | Beside each control name |
| Mood faces | 4 (high, ok, low, poor) | 128 | 64 | Home mood tile |
| Podium and trophy art | 3 medals, 1 crown, 3 cups (gold, silver, bronze), 1 empty slot | 256 | 96, 64 | Trophy shelf and champion |
| Empty-state illustrations | 4 (no games yet, no free agents, no upcoming games or season over, playoffs not started) | 768 x 576 | 384 x 288 | Same style as the hero art |
| Home hero backdrop | 1 (tintable by club colour) | 1440 x 496 | 720 x 248 | Gradient plus arena skyline strip; tileable edges |
| Card depth set | 1 nine-slice (flat card, raised card, sheet top, grab handle) | 96 x 96 with 32 px slices | any | Baked shadows, so grids stay cheap |
| Squad lane-map backdrop | 1 (inset) | 1344 x 880 | 672 x 440 | Aligned with the W4 arena map (coordinate with the Level / World Designer) |
| Fonts | as the art bible decides | n/a | n/a | Must keep numerals tabular (aligned columns in tables) and cover the characters in `en.json` |

### 8.5 Not in the six screens, left as they are for now

Match day (pre-game), Team chemistry (pentagon), Training, Finance, Free agents, Negotiation, Settings, the Plan and Club tab roots, Practice, Season end. They keep working with the new tokens (step 1) but will look older than the six. Suggested follow-up (UI Pass 3): the Chemistry pentagon becomes the same lane map as Squad (the UI reference v1 backlog item UI-5), Match day becomes a sheet on Home (D4 below), Plan and Club tabs use the 2 x 2 tile grid.

---

## 9. Decisions needed

For the Founder (recommendation first, plain words):

| # | Decision | Recommendation |
|---|---|---|
| D1 | Make text and buttons about 15 percent bigger across the game so they meet the 16 sp and 48 dp rule on a normal phone | **Yes.** Today many buttons are about 32 to 38 dp; small hands and tired eyes are the first complaint of a mobile game |
| D2 | Cut Standings from five tabs to three views (Table with a Points/Form switch, Playoffs, History) | **Yes.** Fits in large text, no broken words, fewer taps |
| D3 | Show your five starters on a small lane map instead of five rows | **Yes.** It is the one new idea that makes Squad look like a different game screen; fallback if it does not read well in testing: five portrait cards in a row |
| D4 | Match day (the screen between Home and the draft): keep it for 0.7, or fold it into a "Match preview" sheet on Home | **Keep for 0.7**, fold it in with UI Pass 3; changing the flow now adds risk to the tutorial (W1) |
| D5 | Build with code-drawn placeholder portraits and badges until the art arrives | **Yes**, so the layouts are testable now and no step waits |
| D6 | Home "Up next" swipe row: build it, or leave it out for now | **Build it last**; it is the least important block and the first to cut |

For other roles: see the findings in 7.6 (Lead Game Designer and Systems Designer on the inert plan controls and kills consistency; Narrative on copy and the 9-character hero names; Art Director on the asset list and the role-colour rules; W1 on the `tut_id` table).

## 10. Hand-offs

- **Art Director:** use this spec's component list and section 8.4 for the art bible: depth recipe (5.1), role colours that are colour-blind safe and not good/bad hues (2.4), the portrait kit approach, the club colour fields, text sizes (2.2). Please confirm the asset counts and sizes, or tell me what should change.
- **Concept / Character / Environment Artists:** badges (10), hero busts (40), portrait kit, lane-map backdrop and hero backdrop; icons per 8.4.
- **Gameplay Programmer (Alpha 0.7 build):** steps 0 to 8 of 8.1; the small helpers in 7.5; do not rebuild whole pages on a tap.
- **Engine / Graphics Programmer:** performance budget for the points in R1 (atlas, shadow limit, timer redraw, texture count), and a view on the spike.
- **UI/UX Designer (me), next:** tutorial flow (`docs/design/TUTORIAL.md`) uses the `tut_id` table in 7.3; after the Founder checkpoint, a pixel-level pass on each screen (spacing, states) once the art bible lands.
- **Narrative Designer:** the copy list in 7.4; names for heroes (9 characters at most).
- **Lead Game Designer and Systems Designer:** decide on the inert-controls question (7.6 item 1) and the kills source (item 2).
- **QA Manager / QA Automation:** the 72-image matrix, the fixtures and the five audits (7.1).
- **Studio Manager:** nothing has been run; every size here is a paper estimate until step 0 and step 1 are done.
