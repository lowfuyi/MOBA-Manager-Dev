# Art bible, pass 2c: "Arena Dusk, richer" (reconciled, small fixes)

Owner: Art Director. Date: 2026-11-08. Workstream W2 of `docs/ALPHA-0.7-PLAN.md`. Status: proposal for the Creative Director and the Founder's concept approval. Nothing here has been built in Godot or run on a phone.

**Pass 2b (wave 1b reconciliation, same day).** This file is the single source for type sizes, colour tokens, side colours, role glyphs and club colour use. Where `UI-PASS-2.md`, `ARENA-MAP.md`, `ACTION-VOCABULARY.md` or `TUTORIAL.md` disagree with it on those five things, this file wins; they win on structure and on the arena's places and geometry (where things stand, zone sizes, lane paths). **Every symbol is the bible's, with no exception** (2c, B2 ruled by the Producer): Stoneback is a gold rhombus with a shell mark, and "them" is a flat-top coral hexagon, so the hexagon is never an objective. The rulings below are **defaults from the Producer, written down so the Founder can overrule them at the checkpoint**: R1 type scale, R2 side colours, R3 Standings and Squad rows, R4 glyphs and motif, R5 club colour strength. Sections changed in 2b: 0, 2, 3.3, 3.5 to 3.7, 3.8 and 3.9 (new), 4.3, 5.1, 5.2, 6.1, 6.2, 6.4 (new), 8.1, 8.2, 9, 10. **Pass 2c (review wave 1b, items A4, A6, A8, B2, B12 and the IP scan's art findings; no new content).** (1) Draft header titles are the sentence-case "Your ban", "Your pick", "Their ban", "Their pick" (141 to 161 px at 40 px Bold, measured), and the 260 px title room of 2b was wrong: the room is 200 px (5.2, 8.2). (2) The Hub keeps the top-right 120 x 120 px of the header art clear for the "?" (3.7 rule 8). (3) The Match row now says "structure per `UI-PASS-2.md` 6.7, tokens per 3.8" (8.2); the match clock is 32 px, not Display. (4) Arena tokens are 36 px (circle) and 40 px (hexagon) in big fights (3.8). (5) Ban is an outlined button with a warning icon, never a solid pink or red fill; Pick stays the one coral action (8.1, 8.2, 9.1, 9.2, style tile section 4). (6) How the role glyphs differ from a square lane-map position icon is written down for the IP re-screen (6.1). Files changed in 2c: this file, `style-tile.svg` and `style-tile.png` (new pick-sheet sample, section 4).

Files added in 2b: `docs/design/art/ic_role_*.svg` (5), `bg_lane_bows.svg`, `tools/colour_checks.py`, `tools/font_checks.py`.

Companion image: `docs/design/art/style-tile.svg` (source) and `style-tile.png` (720 px wide, 7,025 px tall, rendered with the real Barlow Semi Condensed files). Open it first: every token below is drawn on it. New in 2b: type scale in the real font, role glyphs (`ic_role_*.svg`) and the Lane Bows motif (`bg_lane_bows.svg`), the side tokens and map surfaces with contrast numbers, the Squad lane map, and the Home wash comparison.

## In short (for a phone read)

- The Alpha look is not wrong, it is flat. The three surface colours are almost the same brightness (only 1.16 to 1.26 times apart), there are no shadows, no icons, no pictures, and the same two-colour button is used for everything.
- Fix: keep Arena Dusk (navy, teal, one coral "go"), but add depth (four elevations with shadow and a top highlight), a dusk gradient behind pages, glow on the one important button, a real type scale, and pictures: a role-ring hero portrait and a generated badge for every club.
- Everything is drawn in code or SVG by us, so it is original. Real painted art needs a human artist later.
- Needs your OK: the free font Barlow Semi Condensed (licence SIL OFL 1.1, free to bundle in a game), and the style tile as the visual direction.
- New in 2b, in plain words: text is about 15 percent bigger than the Alpha (body 32 px instead of 28, nothing under 24); in the match, **you are always a teal circle and they are always a coral hexagon**, red and blue only ever appear as a small flag beside the words "Red side" and "Blue side"; the five role icons are redrawn from the real map (left arc Top, vertical bridge Mid, right arc Bot); your club's colour is a 10 percent tint behind your own header, not a full colour wall (a full-colour header would make white text unreadable: 2.2 to 3.2:1, measured).

## 0. How this was produced (and what it is not)

- Read: `art-director.md`, `ALPHA-0.7-PLAN.md`, `UI-UX-REFERENCE-v1.md` (5.2, 5.3), `game/src/ui/ui.gd`, `game/project.godot`, `game/data/clubs.json` and `heroes.json`, `IP-RISK-LOG.md`, `DECISIONS.md`.
- Looked at all 49 screenshots in `docs/design/art/current/` twice. Pass 1: a critique screen by screen. Pass 2: re-looked for what pass 1 missed (it found: the wrapped tab words, the green opponent bonus, the brown matrix cells, the invisible switches, the grey scrollbar, the tiny text in dp, the 92 px buttons). Those are cited below.
- Numbers (contrast ratios, colour-blind distance, badge values) were computed with small Python scripts: WCAG 2.x relative-luminance contrast; colour-blind simulation with the Machado 2009 matrices (protan, deutan, tritan at full severity) and CIE76 Lab distance (dE). These are approximations, not a lab test. The scripts are not in the repo (I was asked to write only the named files); the formulas are in section 3 so QA can re-check.
- Pass 2b method: the same WCAG and Machado/CIE76 formulas, re-implemented in a small Python module (it reproduced the pass-2 numbers to within 1: good/bad dE 96.7 / 29.7 / 5.7 against the quoted 97 / 29 / 6; role minimum 47.3 / 30.0 / 28.6 / 28.3 against 47.3 / 29.9 / 29.2 / 28.4). Text widths were measured with the real Barlow Semi Condensed TTFs (PIL, basic layout, plus or minus 2 percent). The font files were downloaded once from the public Google Fonts repository to read their name table, features and coverage; they are not in the repo. The checks are now in the repo so QA can re-run them: `python3 docs/design/art/tools/colour_checks.py` prints the colour numbers quoted in 3.7 to 3.9, and `python3 docs/design/art/tools/font_checks.py <folder with the Barlow TTFs>` prints the font facts and string widths quoted in 5.1 and 5.2.
- Not done: no Godot run, no phone, no screenshot of the changed game. The style tile is a picture of intent, drawn in SVG, not a render of Godot widgets. In 2b the tile is rendered with the real Barlow Semi Condensed files (through a private font-config folder; the SVG names the family first and falls back to Inter, so anyone without the font sees a wider stand-in). The big tile (6,569 px in 2b, 7,025 px in 2c) was viewed in 1,000 px strips twice: a first pass found a duplicated token, a missing background below the old end of the tile, overlapping captions and over-long notes; a second pass after the fixes checked every section again.

## 1. Honest critique of the current look

Evidence is by file name in `docs/design/art/current/`. Measured values are from the `ui.gd` tokens and from pixels sampled in the screenshots.

### 1.1 Why it feels flat

1. **Surfaces barely separate.** Contrast between neighbouring surfaces: page `#0a1120` to card `#132036` is 1.16:1, card to raised `#1d3150` is 1.25:1, raised to overlay `#27406a` is 1.26:1. The card border (7 percent white) is 1.23:1 against the card. So cards, buttons and cards-inside-cards melt together (`06_roster_picker.png`, `07e_negotiation_full.png`, `08_prematch.png`). Depth is the first thing that makes an app look "crafted".
2. **No light, no shadow, no gradient.** Every fill is one flat colour (`ui.gd` box()), so nothing looks lit or raised. The only depth cue is a hairline.
3. **Boxes inside boxes, all the same.** A card holds buttons that look like smaller cards (`05_roster.png`, `07d_free_agents.png`, `08b_training.png`, `10_draft_slotpanel_*.png`). Nothing is a clear primary, a row, or a tile.
4. **No pictures at all.** In 49 screenshots there is no icon, portrait, badge, trophy or illustration. Clubs, heroes and players are text. `03_clubselect.png` is ten identical text cards; `10_draft_ban_2.png` picks heroes from a text grid; `16_standings.png` is a bare table.
5. **Centre-aligned text on every button and list row** (`05_roster.png`, `07d_free_agents.png`, `08b_training.png`, `19c_roster_career.png`). Rows of data should be left-aligned with a leading picture and a right-aligned number; centred text is what makes them read as a stack of buttons, not a roster.
6. **Colour has no consistent meaning.** Teal is a heading (every card title), a selected state, a good number (`04b_hub_lower.png` chemistry), a primary button and a link. Coral is the Play button, but also a random label colour: "Next league game", "If you sign him" (`07e`), "Before the next game" (`14_report_top.png`), and "Them". Gold is a warning and a trophy title. The viewer cannot learn the code.
7. **Too many saturated fills compete.** `04_hub.png` has a solid teal "Got it" above a solid coral "Play game"; the primary action starts at 58 percent of the screen height (y 748 of 1280) because a welcome card sits above it. `19_hub_after.png` has teal "Got it", teal "Season summary", gold headline and coral all in one view.
8. **Type does one job.** Body is 28, headings are 28 in teal, so section titles (`Starting lineup`, `Squad`, `Lane matchups`) do not stand out from the content. There is no display size for results ("Defeat" in `14_report_top.png` is the only big word in the game).
9. **Dead space.** `12_match_mid.png` and `13_match_end.png` are a card and five lines of text with 45 percent of the screen empty and black. `09_draft_start.png`, `17_standings_results.png`, `19e_practice.png`, `04c_tab_club.png` are mostly void. The page background is one flat colour everywhere (`BG #0a1120`); there is no gradient, no horizon, no hint of an arena.
10. **Off-palette defaults leak through.** The scrollbar is neutral grey `#717377` (`04_hub.png`); the chemistry matrix cells are brown `#6c4828` and the links orange `#f1a657` (`08e_chemistry.png`, `08f_chemistry_lower.png`), neither of which is in the palette; the progress track `#0a1119` is almost the page colour (1.45:1 against the card, `12_match_mid.png`).

### 1.2 Why it is not pleasing to use (readability and craft)

11. **Switches are invisible.** The "off" switch track `#1b2535` is 1.06:1 against its card (`18_settings.png`, `04c_tab_more.png`). A player cannot see the state at a glance. The "on" state is not shown in any screenshot (all captured off), so it is untested.
12. **Tab words break mid-word.** "Playo/ffs" and "Trophi/es" (`16_standings.png`, `16b_standings_form.png`, `17_standings_results.png`, `19b_trophies.png`) because five equal tabs at 28 px do not fit 672 px. This is a layout fault the type and tab style must prevent (section 5, section 8).
13. **Text is smaller than the UI reference promised.** The reference sets body at 16 sp or larger. On a 360 dp-wide phone the 720 px canvas maps 2 px to 1 dp, so body 28 px is 14 dp, `S_SMALL` 22 px is 11 dp, chips 20 px are 10 dp. (Assumption: canvas_items stretch from 720 px, 360 dp phone; a wider phone scales everything up equally, the ratio stays.) Buttons are `BTN_H` 92 px = 46 dp, under the 48 dp touch target the reference sets; the tab bar items are about 88 px = 44 dp (`04_hub.png`).
14. **Colour-blind bad colour fails as text.** `BAD_CB` `#d55e00` is 3.38:1 on the raised surface (`ui.gd` PANEL2), below 4.5:1, and 4.22:1 even on the card. In colour-blind mode it is also close in feel to coral (section 3.6).
15. **Polarity confusion.** `11_draft_done.png` shows the opponent's "Composition: Siege (+12.0%)" in the same green that means "good for you". "Red side" is written in the same red as "bad" (`04_hub.png`).
16. **Hierarchy inside a card is unclear.** `07c_finance.png` and `19c_roster_career.png` stack six to ten lines of equal weight; the number the player acts on is not larger than its label.

### 1.3 What already works (keep it)

- The Arena Dusk base (navy, teal, coral) is calm, readable (body text on cards 7 to 14:1) and distinct from ESMO's charcoal and lavender.
- The Home "next match" card and the pill tab bar are the right structure (`04_hub.png`). The versus bar and chips are the right components; they only need depth and icons.
- Preview panels ("If you sign him") and the "Why it went this way" bars (`15_report_mid.png`) are good ideas that deserve better drawing.

## 2. Target feel

Arena Dusk, richer: **a sports arena at nightfall**. The page is a deep navy sky that lifts slightly towards the top, cards are lit from above with a thin bright top edge and a soft shadow below, and the single warm coral of the setting sun is saved for the one thing the player should press. Teal is the cool arena light: used for selection, progress and links. Heroes and clubs get their own small, bold pictures (a role-ringed portrait, a generated crest) so the game stops being a list of words. Calm and friendly, never aggressive: fantasy-lite, not cyberpunk.

Three signature motifs make it ours: **the Horizon** (a thin 3 to 4 px teal-to-coral line under screen titles and at the end of cards, the sky meeting the sun), **the Lane Bows** (a faint `( | )` page pattern: two bowed arcs and a straight bridge, the three lanes of Wrenfell; it replaces the old 35 degree "Lane Diagonal", because the real map has no diagonal) and **the role map glyph** (icons for the five roles drawn as the same three lanes with the role's own lane or place highlighted, section 6.1).

## 3. Tokens

All values are final proposals. "Now" is the current `ui.gd` constant. Constants keep their names where possible, so screens keep compiling and the whole game changes at once.

### 3.1 Surfaces (three elevations plus two bases)

| Token | Hex | Now | Use |
|---|---|---|---|
| `VOID` (new) | `#070D1A` | `#0a1119` track | wells, progress tracks, switch tracks, pressed |
| `BG` | `#0a1120` | same | page base |
| `BG_GLOW` (new) | `#14284A` | none | top of the page gradient only |
| `PANEL` = surface 1, card | `#162842` (top `#1D3354`) | `#132036` | cards, rows |
| `PANEL2` = surface 2, raised | `#223A5E` (top `#2C4A78`) | `#1d3150` | hero card, secondary buttons, cards inside cards |
| `PANEL3` = surface 3, overlay | `#30507F` (top `#3C629C`) | `#27406a` | sheets, selected tab pill, pressed secondary |
| `LINE` | white 6 percent | white 7 percent | outer hairline |
| `LINE_HI` (new) | white 14 to 18 percent | none | 1.5 px inner highlight along the top edge |

Each surface is drawn as a top-to-bottom gradient from its "top" value to its base value. Surface step contrast: page to card 1.27:1, card to raised 1.30:1, raised to overlay 1.41:1 (was 1.16, 1.25, 1.26). The gradient (top lighter by about 1.17:1 on the card) plus shadow and highlight do the rest of the separation, so surfaces do not need to be far apart in colour, which keeps text contrast high.

### 3.2 Text

| Token | Hex | On page | On card | On raised | On overlay | Use |
|---|---|---|---|---|---|---|
| `TEXT` (text 1) | `#EAF0F7` | 16.4 | 12.9 | 10.0 | 7.1 | titles, values, body |
| `TEXT2` (new) | `#B9C8DA` | 11.1 | 8.7 | 6.7 | 4.8 | secondary lines, row subtitles |
| `DIM` (text 3) | `#96AAC4` (was `#9db0c6`) | 7.9 | 6.2 | 4.8 | 3.4 | captions, hints, table headers (never on overlay) |
| `TEXT_OFF` (new) | `#62748C` | 3.9 | 3.1 | 2.4 | 1.7 | disabled only (WCAG exempts disabled; never carries information alone) |
| `INK_TEAL` | `#04120F` | | | | | text on teal fills: 11.8:1 to 7.8:1 across the gradient |
| `INK_CORAL` | `#1C0B04` | | | | | text on coral fills: 9.8:1 to 6.5:1 |

Rules: informational text is 4.5:1 or better against what is directly behind it. `DIM` is not allowed on overlay (3.4). On overlay use `TEXT` or `TEXT2`.

### 3.3 Accent, status, sides

| Token | Hex | Now | On page | On card | On raised | Use |
|---|---|---|---|---|---|---|
| `ACCENT` teal 500 | `#3FD0B8` | same | 9.8 | 7.7 | 6.0 | selection, progress, links, confirm buttons |
| `TEAL_HI` teal 300 (new) | `#7BE3D2` | | 12.4 | 9.7 | 7.5 | section titles, selected tab text, focus ring (5.3 on overlay) |
| `TEAL_LO` teal 700 (new) | `#1F8E80` | | 4.7 | 3.7 | | fills and gradient ends only, never text |
| `TEAL_DEEP` teal 900 (new) | `#0F4A4A` | | | | | tints and wells |
| `CORAL` coral 500 | `#FF8A5C` | same | 8.1 | 6.4 | 4.9 | two jobs, never mixed up because of shape: (1) THE go action, one coral action per screen; (2) "them" in the match, always a hexagon, a bar half or a flat glyph that cannot be tapped (3.8) |
| `CORAL_HI` coral 300 (new) | `#FFB594` | | | | | coral text on overlay (4.8) |
| `CORAL_LO` coral 700 (new) | `#E4602F` | | | | | pressed state |
| `WARN` gold | `#F2C14E` | same | 11.2 | 8.8 | 6.8 | warnings, "needs attention", trophies |
| `GOOD` | `#5BD68A` | same | 10.3 | 8.1 | 6.2 | gains, wins |
| `BAD` | `#F58080` (was `#ef6b6b`) | | 7.4 | 5.8 | 4.5 | status and loss tone only: losses, damage, tired, the "Defeat" glyph. **Never a side, never a map token** (3.8). Lifted so it reaches 4.5:1 on the raised surface (the old value gives 3.8 there) |
| `GOOD_CB` | `#7FD0FF` (was `#56b4e9`) | | 11.1 | 8.7 | 6.7 | colour-blind good |
| `BAD_CB` | `#F2924A` (was `#d55e00`) | | 8.1 | 6.3 | 4.9 | colour-blind bad (was 3.38 on raised) |
| `SIDE_BLUE` | `#5AA9FF` | `BLUE` | 7.7 | 6.0 | 4.7 | the cloth of the "Blue side" flag glyph, nothing else; the word always sits beside it |
| `SIDE_RED` (retired as a separate hue) | `#F58080` = `BAD_DEFAULT` | `RED` | 7.4 | 5.8 | 4.5 | the cloth of the "Red side" flag glyph, nothing else. The old `#FF7A7A` was dE 7.1 from `BAD` (same colour to the eye), so it is merged: keep a constant named `SIDE_RED` with the value of `BAD_DEFAULT` that the colour-blind switch does **not** swap |
| `MAP_LAND` (new) | `#173629` | | 1.4 | 1.1 | 1.2 | Wrenfell ground and the Squad map's pockets; a fill, never text. `TEXT` on it 11.5:1 |
| `MAP_MERE` (new) | `#0E3550` | | 1.5 | 1.2 | 1.1 | Wrenfell lake body; a fill, never text. `TEXT` on it 11.1:1 |
| `MAP_SHORE` (new) | `#2F7F8F` | | 4.1 | 3.2 | 2.5 | the lake rim and ripple **strokes only**. As a background it is too light: `ACCENT` fill on it 2.4:1, `CORAL` 2.0:1, `TEXT` 4.0:1, `TEXT2` 2.7:1, so no token or label ever sits on it |

The other map colours are merged into existing tokens, not added; the full table is in 3.9.

Rule for status text on overlay (surface 3): status colours drop to 3.2 to 4.8 there, so on overlay show the number in `TEXT` and put the status in an arrow or glyph. Hover and pressed states use the `LO` values.

**Gradients (for fills):** teal button `#5FE0CB` to `#2FB9A2`; coral button `#FFA37B` to `#F2703E`; good bar `#86E8AB` to `#43BD70`; bad bar `#FF9E9E` to `#DE5E5E`; page `#14284A` at the top to `#0A1120` at 18 percent to `#070D1A` at the bottom.

### 3.4 Chips

Chip fill is the chip colour at 16 percent over the surface it sits on; the border is the colour at 45 to 50 percent; text is the colour. Measured text on its own tint: on card 4.5 to 6.5 (all pass); on raised, coral, bad, teal and both side colours fall to 3.6 to 4.4. Rule: **on raised, lift the chip text 25 percent towards white** (`color.lerp(WHITE, 0.25)`: then 4.5 to 5.6). **Never put a tinted chip on overlay**; use a solid chip there (colour fill, ink text).

### 3.5 Role colours (rings and glyphs only, never text)

| Role | Hex | On card |
|---|---|---|
| Top | `#9797F7` | 5.7 |
| Jungle | `#B7F797` | 11.8 |
| Mid | `#68DCF3` | 9.3 |
| Bot Carry | `#EFD139` | 9.8 |
| Support | `#F36896` | 5.1 |

Chosen by search for the best worst-case separation. Smallest distance (CIE76 dE) between any two roles: 47.3 for normal vision, 29.9 protanopia, 29.2 deuteranopia, 28.4 tritanopia (a dE under about 10 is hard to tell apart; above about 25 is clear). Colour is never the only cue: each role also has its own silhouette and its own map glyph (section 6). Role colours are not allowed as button fills (the Top periwinkle is close in feel to the reference game's lavender buttons; keeping it to rings avoids that look). 2b additions: the Jungle lime is also the colour of jungle camp icons (3.9); role rings are used on the Squad lane map and on portraits and avatars, **not** on arena hero tokens (there the side shape and colour win, and the slot letter names the role). Role rings against the Squad map surfaces: land 4.5 to 10.5:1, lake 4.4 to 10.2:1 (the 2 px dark outer ring separates the rest); never on the shore.

### 3.6 Colour-blind-safe pairing

- Default pair `GOOD #5BD68A` / `BAD #F58080` is hard for red-green colour blindness by design: dE 97 normal but 29 protan and only 6 deutan. That is why the setting exists.
- Colour-blind pair `GOOD_CB #7FD0FF` (sky) / `BAD_CB #F2924A` (orange): dE 94 normal, 77 protan, 88 deutan, 96 tritan. Trade-off, stated honestly: both are lighter than the old pair so that text reaches 4.5:1 on every surface; the brightness ratio between them is 1.38:1 (the old pair was 1.68:1), so they separate a little less in greyscale. Arrows and signs carry that gap; total colour blindness (monochromacy) is covered only by those cues.
- **Always three cues, never colour alone:** sign (+/-), arrow icon (up triangle, down triangle) and word. `UI.delta_color` callers must add the arrow (section 8). The arrow is a **drawn icon, not a typed character**: the font has no arrow, tick, cross or star glyph (5.1), so a typed one would come from a different device font or show as a box.
- In colour-blind mode coral and `BAD_CB` look alike (dE 13 normal, 7 deutan). Rule: coral is only ever a button or bar *fill* with dark text, a versus-bar half or a side token; `BAD_CB` is only ever text or glyph with a down arrow. They never sit in the same row.
- Sides (Blue and Red) and "you and them" are settled in 3.8: teal circle against coral hexagon in the match, `BAD` never a side, Blue and Red only as a word plus a flag glyph.
- **Opponent polarity:** anything that benefits the opponent is neutral or coral, never `GOOD`. Fixes `11_draft_done.png`.

### 3.7 Club-colour rules

Every club has a primary and a secondary colour generated from its id (section 6.3). Rules:
1. Club colour is **identity, not status**. Allowed: the badge, a 4 px stripe on the left of a club card, a 10 percent wash behind that club's own header, the standings row marker and the podium base. Not allowed: text colour (club names are always `TEXT`), buttons, bars, status chips. The UI chrome stays teal and coral whichever club the player picks.
2. Primary is generated within a fixed brightness window (WCAG relative luminance 0.24 to 0.36), which guarantees at least 4.1:1 against the card (so the badge reads) and at least 5.2:1 for the dark initial letter on it. Measured over the 10 clubs: min 4.1:1 against card, 5.2:1 ink letter.
3. Secondary is either a pale tint (HSL 35 percent saturation, 90 percent lightness) or a deep shade (55 percent, 16 percent) of the same hue, so primary against secondary is at least 2.3:1 (measured min).
4. Patterns never sit under the initial letter (top band, bottom band, bottom chevron only).
5. Every badge has a 3 px white 35 percent rim and a shadow, so it holds its outline on any surface, including when its colour is close to the surface.
6. Two clubs in one league never share a hue and never share a shape plus pattern pair, so they stay distinguishable even in greyscale or colour-blind view (shape, pattern and the letter differ).
7. A versus bar or a prematch screen never colours the two clubs by their club colours; it uses teal (you) and coral (them), so two similar clubs can never clash.
8. **Strength: the bible wins over `UI-PASS-2.md` 6.1 (R5).** A full-strength club-colour gradient behind the Home header is not allowed. Measured: white `TEXT` on the ten club primaries is only 2.2 to 3.2:1 (the brightness window that makes badges readable also makes them too light for white text), so a "club-colour gradient" would fail the text rule the moment the club name sits on it. What the Home hero becomes: the page gradient (`BG_GLOW` `#14284A` at the top, falling to `BG`), the club's primary at a flat **10 percent** over it behind the 248 px header block only, and the arena skyline art as neutral `VOID` silhouettes at 55 to 70 percent. The badge itself keeps its full colour, rim and shadow; that is where the club colour lives. Measured over the ten clubs: `TEXT` on the washed hero 10.9 to 11.3:1, `TEXT2` 7.3 to 7.6, `DIM` 5.3 to 5.5; the badge primary against the washed hero 3.6 to 4.9:1 (the rim and shadow make up the rest); the wash moves the page colour by dE 5.2 to 14.5, so it is a tint, not a colour. The tile (section 10) shows both versions side by side. **The "?" corner (accepted in 2c, A6):** the top-right 120 x 120 px of the Home header art stays clear of anything lighter than `BG_GLOW` lifted 20 percent towards white (`#43536E`, a pale step above the page gradient top). The neutral `VOID` skyline is darker than `BG_GLOW` by construction, so it already passes; the rule is that no badge, glow, coach star or lit shape is drawn in that corner. The 88 px "?" circle keeps its `TEXT2` ring as the contrast carrier (`UI-PASS-2.md` 6.1).
9. **Needs attention (R5): structure from UI-PASS-2, colour from this bible.** Keep the swipeable row, but each item is an **attention card**, not a chip: 96 px high (it is tappable, so it is not a passive 44 px chip), `PANEL` E1 surface, a 6 px `WARN` rail on the left, a drawn warning icon in `WARN`, the label in `TEXT` at Body 32, a chevron in `TEXT2`. No gold fill, no gold text (gold text on a card is fine at 8.8:1 but the rail already says "attention"). Two cards fit side by side at 330 px; more scroll with a 48 px peek.

### 3.8 Sides: one rule for the whole match (R2)

The player is always **teal and a circle**; the opponent is always **coral and a hexagon**. This is the same pair as the versus bar. Blue and Red (the draft sides) are a word plus a flag, never a colour wash and never in the arena.

| Where | You | Them |
|---|---|---|
| Arena hero token (40 px; **36 px in big fights**, 2c B12) | circle, solid `ACCENT`, 3 px `TEXT` rim at 70 percent, slot letter T J M B S in `INK_TEAL` 24 px Bold | flat-top hexagon (point-to-point width 44, the same area as the 40 px circle; **40 px in big fights**, the same area as the 36 px circle; so a hexagon is 1.1 times the width of its circle and the map validator's spacing check uses 1.1 x for hexagons), solid `CORAL`, same rim, letter in `INK_CORAL` |
| Towers and the Cairn | dark `VOID` plate, 3 to 3.5 px `ACCENT` rim | dark `VOID` plate, 3 to 3.5 px `CORAL` rim |
| Scoreboard, feed lines | a 16 px circle or hexagon glyph in the side colour before the club name, kills and feed text; text itself stays `TEXT` | the hexagon glyph |
| Versus bar | left half, teal gradient | right half, coral gradient; a centre notch |
| Draft board and Draft complete | left column, headed by the circle glyph | right column, headed by the hexagon glyph |
| Home card and draft board "Blue side" / "Red side" | a neutral chip (`TEXT` word on the raised chip colour) with a 28 px flag glyph: Blue = pennant, `SIDE_BLUE`; Red = swallowtail, `SIDE_RED` (the `BAD` value) | same |

Why solid tokens and dark plates: a token that is a solid side-colour fill cannot be mistaken for a tower, a camp or a Cairn (all dark plates with a rim), and a solid fill needs no outline to survive the Mere or the road. `BAD` is for status and loss tone only (a losing number, the "Defeat" glyph, "tired"), so a rose hexagon can no longer mean both "enemy" and "bad news".

**Relaxed rule:** one coral *action* per screen. Coral as a side identity (hexagon tokens, the right half of a bar, the hexagon glyph) is allowed on the same screen as the coral go button because it is a different shape and can never be tapped. Honest risk: coral now means "go" and "them"; shape and position carry the difference, and Match is the one screen with both (five hexagon tokens, coral-rimmed plates and a go button below the arena). The QA colour-blind shot of Match must show them apart.

Colour-blind checks (all computed; teal `#3FD0B8` against coral `#FF8A5C`):

| Check | Normal | Protan | Deutan | Tritan |
|---|---|---|---|---|
| dE, teal against coral | 94.7 | 33.9 | 50.6 | 103.0 |
| dE, teal gradient ends against coral gradient ends (top / bottom) | 79.2 / 101.2 | 28.2 / 39.0 | 42.0 / 56.4 | 91.6 / 112.3 |
| dE, coral against `BAD` | 23.9 | 25.4 | 22.6 | **2.8** |
| dE, coral against `BAD_CB` | 13.2 | 11.6 | 6.8 | 5.0 |
| dE, teal against `GOOD_CB` | 44.6 | 33.4 | 31.0 | 9.4 |

Reading: teal and coral are clear to every viewer by hue (all above 28). Their brightness is almost equal (relative luminance 0.496 and 0.402, ratio 1.21:1), so in greyscale or monochromacy only the **shape (circle against hexagon), the letter and the position (bottom against top, left against right)** separate them. That is why the shape rule is not optional and why a side is never a fill colour alone. Coral and `BAD` are the same colour to a tritan viewer (dE 2.8): `BAD` therefore never appears on the arena. The colour-blind switch does **not** change teal or coral (the shapes do the job); it only swaps `GOOD` and `BAD` for status, and those two never sit in the arena either.

Token contrast on the map surfaces (non-text, needs 3:1; flat fills, dark ink letters 9.9:1 on teal and 8.2:1 on coral):

| Surface | `ACCENT` fill | `CORAL` fill | Note |
|---|---|---|---|
| `MAP_LAND` | 6.8 | 5.7 | |
| Road = `PANEL3` | 4.2 | 3.5 | the lowest pair; the 3 px `TEXT` rim (6.4:1 on land) protects the outline anyway |
| Plaza = `PANEL2` | 6.0 | 4.9 | |
| `MAP_MERE` | 6.6 | 5.5 | |
| `MAP_SHORE` | 2.4 | 2.0 | **fails**: the shore is a rim line only, tokens never rest on it |

Feed lines: a line is the side glyph plus `TEXT` words plus a sign or arrow icon for who won the beat. It is not coloured text and not `BAD`. (`ACTION-VOCABULARY.md` 2.2 says the loss tone includes "feed line in the BAD colour": the Gameplay Designer should change that to the side glyph; the loss tone is then the cool edge vignette and the `BAD` "Defeat" glyph in the end card.)

### 3.9 Map and effect colours: what became a token, what merged (R2)

Source: `arena-map-preview.svg` (about 50 distinct colours) and `ARENA-MAP.md` section 9. Distances are CIE76 dE (normal / protan / deutan / tritan).

| Map colour | Decision | Evidence |
|---|---|---|
| Moonhulk lilac `#B9C6FF` | **merged into `TEXT2` `#B9C8DA`** (crescent in `TEXT`) | dE 21.0 to `TEXT2`: a pale blue-grey moon reads fine. Keeps a second lavender off the screen (the Top ring is already the only periwinkle) and removes a lilac that was 5.6 dE from the Mid ring under deutan |
| Moss `#8FCF7A` | **merged into the Jungle ring `#B7F797`** | dE 14.5: two greens for one idea. Lime means "jungle" everywhere (role ring, camps, jungle contest chips). `GOOD` stays distinct (lime to `GOOD` dE 23.4) |
| Bramble `#E0A35A` | **merged into the same lime**; bramble stays a wheel shape, moss a leaf, Mossback a dome | bramble against coral is 25.8 normal but **0.4 under deutan**: an orange camp would be a coral hexagon to a deutan viewer |
| Stoneback amber | `WARN` `#F2C14E` (existing) | the only gold on the map; dE to coral 40.7 / 30.9 / 16.9 / 29.9. Shape: a **rhombus** with a shell mark (not a hexagon: the hexagon is "them") |
| Lake `#0E3550` to `#103F58` | `MAP_MERE` token; the lighter inner steps are baked into the lake art, not tokens | dE to `PANEL` 7.2 |
| Shore `#2F7F8F` | `MAP_SHORE` token, strokes only | dE to `TEAL_LO` 20.9 |
| Land `#173629` | `MAP_LAND` token | dE to `TEAL_DEEP` 13.2, to `BG` 27.5. Under tritan it is 5.5 from the lake body: the shore line and the ripple strokes separate them |
| Grass tufts `#5FAE7A`, `#7BB86F`, trail dots `#A8D8C0` | baked art, not tokens; at most 30 percent alpha; never lime | decoration |
| Three lane colours `#2C4A70`, `#456A98`, `#4A5B7E` | **one road colour, `PANEL3` `#30507F`**, 2 px edge lines white 18 percent | the old three differ by role and by side feel; one road makes lanes read as one system, identity comes from the label and the role glyph. dE 6.1 to the first |
| Plaza `#1E3556` | `PANEL2` | dE 2.9 |
| Tower plates `#0D1A2C`, `#0F2B33`, `#33161A` | `VOID` plate with a side-colour rim | the dark team tints were the same dark in two hues |
| Label colours (green, amber, lilac) | `TEXT` with a 5 px `VOID` outline | `TEXT` on the four map surfaces: land 11.5, Mere 11.1, plaza 10.0, road 7.1 (5.4 on the lighter top of `PANEL3`); never on the shore (4.0) |
| Damage effects (`ACTION-VOCABULARY.md` section 3) | physical = `WARN` mixed 60 percent to `TEXT` (`#EDDDB3`); magic = `TEXT2`; never teal or coral | teal and coral now mean sides, so a hit effect in either would read as a team colour. Physical against magic dE 34.4. The vocabulary's "violet-teal" becomes pale blue-grey, which also keeps violet off the screen |

Net: three new tokens (`MAP_LAND`, `MAP_MERE`, `MAP_SHORE`); everything else on the map is an existing token. `ARENA-MAP.md` section 9's own colour list is replaced by this table (the Level Designer applies it).

## 4. Depth and light

**Light model:** one light from above. Highlights sit on top edges, shadows fall straight down, nothing is lit from the side. The page lifts slightly lighter at the top (the sky), the coral "sun" sits low and very faint behind the bottom edge.

### 4.1 Elevation rules

| Level | Used for | Fill | Shadow (offset y / blur / black alpha) | Edge | Inner highlight |
|---|---|---|---|---|---|
| E0 well | tracks, input wells, pressed | `VOID` flat | none | black 50 percent 1 px | black 50 percent 2 px line at the top (inset) |
| E1 card | cards, list rows, tiles | `PANEL` gradient | 4 / 10 / 38 percent | white 7 percent 1 px | white 14 percent 1.5 px, top edge, inset 20 px from the corners |
| E2 raised | hero card, secondary buttons, card in card | `PANEL2` gradient | 8 / 18 / 45 percent | white 7 to 16 percent | white 16 to 20 percent |
| E3 overlay | bottom sheets, dialogs, selected tab pill | `PANEL3` gradient | 14 / 28 / 55 percent | white 16 percent | white 20 percent |

Corner radius: card 24 (was 20), button 20 (was 18), chip full pill, small 14, sheets 28 on the top corners only.
Spacing: gap 16 (was 14), card padding 24 (was 20), scale 4/8/12/16/24/32.

**How to build it in Godot (for the Lead and the Engine programmer):** `StyleBoxFlat` has corner radius, border, shadow (`shadow_color`, `shadow_size`, `shadow_offset`) but **no gradient and no per-side border colour**. So:
- Bake the three surface looks once at start-up as small 9-slice textures (gradient, inner top highlight, edge and, if the shadow cost matters, the shadow in the transparent margin through `expand_margin_*`), cached by elevation and colour, and use `StyleBoxTexture`. One textured quad per card is cheap on a low-end phone and keeps ten cards in a scroll fast.
- If baking is not wanted, `StyleBoxFlat` with `shadow_*` plus a 2 px highlight `Panel` child on top also works, but every card then has an extra node and an extra shadow pass. Budget: no more than about 6 shadowed surfaces visible at once; the rest use a baked shadow or none (E1 rows inside a card need no shadow, only the edge).
- I could not measure the cost of either (nothing ran on a device). The Engine / Graphics Programmer owns the choice and the frame-rate budget; the visual spec above is the target either way.

### 4.2 Glow (important actions only)

- The one coral go action (`UI.button(..., "play")`): gradient fill, 1.5 px white 45 percent inner highlight on the top edge, and a glow: coral at 38 to 45 percent, blur 16 to 18, offset y 6 (`StyleBoxFlat.shadow_color` set to coral does this natively). Pressed: gradient to `CORAL_LO`, glow off.
- Selected hero or club card: a 2 px ring in the role or club colour plus a 35 percent glow of the same colour, blur 10.
- The card that holds the go button (the Home hero card) may carry a 1.5 px coral edge at 55 percent, so the eye links card and button. Nothing else gets a coral edge.
- Focus ring (keyboard or accessibility focus): 3 px `TEAL_HI`, 12.4:1 on the page.
- Glow budget: at most two glowing things on screen at once. A glow is a signal; if everything glows, nothing does.
- Ambient pulse: the coral glow may breathe (alpha 0.25 to 0.45, 2 s period) on the Home Play button only after 3 s idle; off with Animations off, and paused while scrolling.

### 4.3 Backgrounds

- **Pages:** one vertical gradient, `#14284A` to `#0A1120` at 18 percent to `#070D1A`, drawn as one stretched texture (not a shader). Optional: the Lane Bows pattern (`docs/design/art/bg_lane_bows.svg`, one 144 x 192 px tile: two bowed arcs and a straight line, white 3.5 percent, 1.5 px strokes, not rotated), tiled once. It replaces the old 35 degree stripe. The style tile shows it at 4 times and at real strength. Text never sits directly on the pattern; body text lives on opaque cards.
- **Banding:** dark gradients can show visible bands on phone screens. Add a 128 px noise tile at about 1.5 percent alpha over the gradient if bands show on the first device test. Not tested.
- **Title screen only:** the full dusk: a teal glow at the top left (16 percent, 70 percent radius), a coral glow low in the centre (14 percent), and 3 faint concentric arcs (white 4 percent) behind the wordmark. Max two background layers beyond the gradient.
- **Never busy:** the background may vary the brightness behind any text by no more than about 6 percent. No photo, no particles behind lists, no animated backgrounds.
- **Wordmark:** use the working title as text (Display 64, ExtraBold) with the Horizon line underneath. Do not draw a logo until the final name clears the trademark search (`IP-RISK-LOG.md`).
- **Arena (Alpha 0.8):** the Environment and Lighting Artists build the map on the same palette, using only the tokens of 3.8 and 3.9: ground `MAP_LAND`, lake `MAP_MERE` with a `MAP_SHORE` rim line, roads `PANEL3`, plazas `PANEL2`, plates `VOID`. Heroes are the side tokens of 3.8 (teal circle for you, coral hexagon for them, slot letter inside), **not** role rings and **not** blue or red team tints; Blue and Red never appear in the arena. Camps lime, Stoneback gold (`WARN`), Moonhulk `TEXT2`. Hit effects are `WARN`-white and `TEXT2`, never teal or coral. No effect may be brighter than the coral glow.

## 5. Typography

### 5.1 Font recommendation

**Barlow Semi Condensed** (Jeremy Tribby), Latin, free, **SIL Open Font Licence 1.1** (OFL). Why:
- It is narrower than the default font. **Measured in 2b** (real TTFs, "Northreach Corsairs", the longest club name): Barlow Semi Condensed Regular 32 px is 250 px wide; Inter Regular 32 px, used as a proxy for the Open Sans look of Godot's default, is 306 px. So 32 px Barlow is as wide as about 26 px of the old font: the 15 percent size increase costs no line length. (The pass-2 guess of "30 px is as wide as 26 to 27 px" held up.)
- It has a sporty, friendly, slightly rounded-corner feel without being a "tech" display face, and clear numerals for scores, ratings and money.
- Static TTF weights (Regular, Medium, SemiBold, Bold, ExtraBold) load straight into Godot's `FontFile`; no variable-font handling is needed on Android. The five files total 544,976 bytes (about 0.5 MB in the APK).

**Facts read from the font files themselves (2b):**

| Check | Result |
|---|---|
| Files | Regular, Medium, SemiBold, Bold, ExtraBold; sha256 (first 16 hex) `e8c7242f612b13d0`, `4998b693a190b76f`, `bd299f4bc5b44d30`, `5bd6757e459a110d`, `a8096d0dc3ff22ea`; `OFL.txt` `186d750eb496a4c1`. Version 1.408, designer Jeremy Tribby, 694 glyphs |
| Licence text inside the font (name IDs 13 and 14) | "licensed under the SIL Open Font License, Version 1.1", URL `http://scripts.sil.org/OFL` |
| Copyright line | "Copyright 2017 The Barlow Project Authors (https://github.com/jpt/barlow)". It declares **no Reserved Font Name**. (Pass 2 said we may not reuse the Reserved Font Name; the OFL rule is generic and this file declares none. It is moot anyway: we do not modify or rename the font.) |
| Tabular numerals | **Not the default.** Default digits are proportional (the "1" is 303 units, the "0" 504). The OpenType `tnum` feature is present and maps the digits to `.tf` glyphs. So the Theme font must switch it on (`FontVariation.opentype_features = {"tnum": 1}` in Godot 4; **not tested in Godot**). The pass-2 fallback to the non-condensed Barlow is useless: its digits are also proportional by default. Fallback if `tnum` does not take: right-align numbers in fixed-width slots. |
| Coverage | Basic Latin 95 of 95, Latin-1 96 of 96, Latin Extended-A 119 of 128, Vietnamese additions 90 of 90; Greek 4 of 144, Cyrillic 0 of 256 |
| **Missing symbols** | No arrows (U+2191, U+2193), triangles (U+25B2, U+25BC), check or cross marks (U+2713, U+2717), star (U+2605) or right arrow (U+2192). Present: minus (U+2212), multiplication sign (U+00D7), bullet (U+2022). **Rule: every arrow, tick, cross and star in the UI is a drawn icon (`ic_*.svg`), never a typed character.** The wireframes' `[v]` and `[^]` are icon slots; `UI.delta_text` returns an icon id plus a signed number |

Licence use, as far as the files show: the OFL text in `OFL.txt` (93 lines, standard OFL 1.1) says the fonts "can be bundled, embedded, redistributed and/or sold with any software" provided reserved names are not used by derivative works, and may not be sold by themselves. So we may bundle and embed the font in the game and sell the game; we may not sell the font on its own. Put `OFL.txt` next to the font files and the credit in the About screen. The IP & Originality Checker logs it (name, source, licence, date, the hashes above).

**What I could not verify:** that these files are byte-identical to the upstream release (I downloaded them from the public Google Fonts repository over the session's proxy, today, and did not compare against the upstream project's own release); that no other licence or trademark claim applies to the name "Barlow"; the legal reading (I am not a lawyer; the IP & Originality Checker and, if the Founder wants, a lawyer decide); that the font imports and renders correctly in Godot 4.3 on Android; the About-screen credit wording. The files are in my scratch folder, not in the repo: adding them to `game/assets` is the Lead Programmer's job after the IP log entry.

**Fallback chain** in the Theme: Barlow Semi Condensed, then Godot's built-in default font, then a system font (`SystemFont` with `sans-serif`; on Android this reaches Roboto and the Noto CJK fonts). Barlow covers Latin and Vietnamese only (table above), so languages beyond Latin that a Singapore and Malaysia release may want (for example Chinese or Tamil; Malay is Latin and is covered) need the system fallback or a second OFL family (Noto Sans, also OFL). Verify glyph coverage before localising.

If the Founder prefers a rounder, warmer look: **Nunito Sans** (OFL) or **Rubik** (OFL). Both are wider than the default, so the scale below would drop by about 10 percent.

### 5.2 Type scale: the one table (R1; 720 px design width; dp = px / 2)

Adopted from `UI-PASS-2.md` 2.2 as the Producer ruled: **Body 32, Small 26, Caption 24, and nothing in the game is below 24 px.** Reason: on a 360 dp phone the 720 px canvas is 2 px per dp, so Body 32 is 16 dp, which meets the UI reference's 16 sp rule (pass 2's 30 px was 15 dp and missed it; the Alpha's 28 px was 14 dp). This table replaces the pass-2 table and the sizes in `UI-PASS-2.md` 2.2, `ARENA-MAP.md` 9 and `TUTORIAL.md` 7.3.

| Style | `ui.gd` | px | dp | Large text, effective dp (x1.15) | Weight | Line height | Colour | Use |
|---|---|---|---|---|---|---|---|---|
| Display | `S_DISPLAY` (new) | 64 | 32 | 36.8 | ExtraBold | 1.05 | `TEXT` | result word ("Victory"), the end-card score line, hero-stat number, wordmark (the match HUD clock is Body 32 in a 44 px row, `UI-PASS-2.md` 6.7.3) |
| Title | `S_TITLE` (was 46) | 48 | 24 | 27.6 | Bold | 1.1 | `TEXT` | the one name that is the hero of a screen: the club name on Home, a champion |
| Value and screen title | `S_BIG` (was 38) | 40 | 20 | 23.0 | Bold for titles, SemiBold for numbers | 1.15 | `TEXT` | screen and sheet titles (the `ScreenHeader` and `BottomSheet` title); numbers the player acts on (tile value, rating, points, cash) |
| Heading | `S_HEAD` (new) | 36 | 18 | 20.7 | SemiBold (Bold on the go button) | 1.2 | `TEXT` | card titles, the go button label, a podium or hero-stat sentence |
| Body | `S_BODY` (was 28) | 32 | 16 | 18.4 | Regular (SemiBold on buttons and segmented labels) | 1.35 | `TEXT` | paragraphs, row names, button labels, anything the player decides from |
| Small | `S_SMALL` (was 22) | 26 | 13 | 14.95 | Medium (SemiBold for hero names) | 1.3 | `TEXT2` | secondary lines, hero names in the grid, podium names, phase labels; never the only place a decisive number lives |
| Caption | `S_CAPTION` (new) | 24 | 12 | 13.8 | SemiBold | 1.25 | `TEXT2` or the chip colour | chips, tab-bar labels, map labels (Bold, outlined), **section labels**; the floor |

The sheet and screen title is **folded into the 40 px Value size, not into Title (48)**. Measured in the real font, the five screen and sheet titles I picked as the longest ("Why this happened", "Team chemistry", "Draft complete", "Who plays Mid?", "Match report") all fit one line at 40 px in the narrowest header room I estimate (362 px at large text: 578 minus a 96 px back button, a 96 px help slot and 24 px of gap): 306, 258, 242, 245 and 207 px. At 48 the longest would be 367 px and wrap. Title 48 is kept only for names that are the hero of a screen (Home club name: "Northreach Corsairs" 391 px in a 466 px room). The 40 and 36 px sizes are 11 percent apart, close; the weights (Bold or SemiBold against Regular) and colour (`TEXT` against `TEXT2`) do the rest, which is why card titles are never regular weight.

**Section titles: the contradiction is resolved as follows.** There are two different things and each has one rule.
1. **Card title** = Heading 36, `TEXT`, never teal (pass 2's rule stands: teal is selection, progress and links, and a teal heading on every card was critique item 6).
2. **Section label** (the row above a group: "Starting five", "Bench", "Up next", the thing `UI-PASS-2.md` calls SectionHeader) = Caption 24, SemiBold, **upper case, letter-spacing +8 percent, `TEAL_HI`** (12.4:1 on the page, 9.7 on a card). It names a group and is the only teal text besides links and selected states. `UI-PASS-2.md` 4 (pattern 2) and 5.2 say "32 px, accent colour": that becomes 24 px in `TEAL_HI`; the 56 px row height, the count chip and the 96 px action hit area do not change. A Horizon hairline sits under it only where a screen starts a new major group, not under every label.

**Large-text mode (+15 percent, 626 x 1113 logical canvas, 578 px of content width).** It works by `content_scale_factor = 1.15`, so the logical pixel sizes in the table do not change; the canvas gets narrower and every pixel is drawn 1.15 times bigger. The effective sizes are in the table's fifth column: **the largest become Display 73.6 px-equivalent (36.8 dp) and Title 55.2 (27.6 dp); body becomes 18.4 dp and the floor 13.8 dp.** No separate cap on Display and Title is needed (pass 2 asked for about 1.1): measured in the real font, every long string fits its large-text room on one line: "Season complete" at Display 450 px in 530; the score line "15 - 24" 197 px between two 88 px badges (about 400 px free); "Northreach Corsairs" Title 391 px in 466 (578 minus an 88 px badge and a 24 px gap); Heading 288 in 530 (card inner width); Body 250 in 298 (my estimate of the Standings name slot at large text: rank 56, badge 56, points column 120, three 16 px gaps; the tightest of all); "Playoffs" 103 in a 160 px segmented slot; "Gravenstone" Small 130 in a 160 px card; the longest chip, "+0.9% chemistry", 161 px. **Draft header titles (corrected in 2c, A4).** The titles are the sentence-case "Your ban", "Your pick", "Their ban" and "Their pick" at Bold 40 px, measured in the real font at 141, 150, 152 and 161 px. The room beside the back button, the timer ring, Auto-finish and the "?" is **200 px** at normal size and 106 px in large text (`UI-PASS-2.md` 6.3): all four fit on one line at normal size, and in large text they take two lines ("Their" 84 px and "pick" 69 px both fit 106). 2b's "Your turn: ban" (229 px) and its "fits 260 px" were wrong and are deleted; a long title like that does not fit beside the "?" at either size. A width audit is still needed on every screen (the measurements are of the strings I could find in the specs, plus or minus 2 percent, not of built screens).

**Map labels (24 px) and large text.** The arena is 720 design px wide and must be fitted to the 626 px logical canvas, so its scale is 0.869 and the map labels render at 24 design px in both modes: 12 dp, not 13.8. They do not grow with large text (a limit, stated plainly). The text audit must measure a label's size as font size times content scale times the map fit scale, not the font size alone. Widths at 24 px Bold with +1.5 px tracking: STONEBACK 128, MOONHULK 118, MOSSBACK 116, TOP 41, MID 37, BOT 42. STONEBACK centred on its icon (x 0.78, 561.6 px) spans 497.6 to 625.6 px, which crosses the Bot lane's inner edge near x 609 (the lane is 64 px wide centred on x 0.89): the Level Designer should place that label above or to the left of its icon. Never smaller than 24.

Rules: numbers that the player acts on are one size up from their label (Value above Small). Money, ratings, scores, times and standings use tabular numerals (`tnum`, 5.1). Sentence case everywhere, except the Caption section label, which is upper case with tracking, and map lane and place labels; no all-caps italic extended headings (section 9). Tabs and chips are single line and never wrap mid-word: if a label does not fit, the control scrolls sideways or takes a shorter label. Minimum button height 96 px (48 dp), was 92 px; chip height 44 px (text 24); the tile's own annotation text (swatch hex codes, type labels) is documentation, not UI, and is smaller than 24 on purpose.

## 6. Iconography and illustration

### 6.1 Icon style

- Grid 48 x 48 px (24 dp), live area 40 px, 4 px padding. Stroke 4 px (2 dp), round caps and round joins, outer corner radius 6 px. No fills except a single accent shape (a dot, a gem, the highlighted lane).
- Two tones: a `TEXT2` stroke and one accent fragment in `TEAL_HI` (or role colour). **Icon sizes (R1 and R4 update):** 28 px inside a chip (chip height 44, text 24), 32 px inline and the smallest size a role glyph may be used alone, 48 px buttons and the tab bar, 64 px tiles, 96 px hero or empty-state use (the glyph tile on the style tile); header icon buttons are 96 x 96 px hit areas around a 48 px icon; the portrait corner chip is 26 px (glyph 20 px). Hit area is always at least 96 px even where the picture is smaller.
- Author as white strokes on transparent SVG and tint with `modulate`. (Godot's SVG import has no `currentColor`.) One file per icon in the Art folder, named `ic_<name>.svg`. Done in 2b: `ic_role_top.svg`, `ic_role_jungle.svg`, `ic_role_mid.svg`, `ic_role_bot.svg`, `ic_role_support.svg` (white, faint context lanes at 40 percent alpha, the role's own lane at full alpha) and `bg_lane_bows.svg`.
- Shape language: friendly geometry, soft corners, one idea per icon, no sharp "tech" notches, no skulls, bolts or flames.
- Set to draw first (about 30): tabs Home, Squad, Plan, Club, More; roles Top, Jungle, Mid, Bot Carry, Support (done); status fatigue, form, morale, contract, cash; actions ban, pick, lock, play, skip, speed, help (?), back, close; misc trophy, star (coach suggests), arrow up, arrow down, arrow flat, tick, cross, coin, clock, flag (two: pennant for Blue, swallowtail for Red), warning triangle, chevron, and the side glyphs (circle for you, flat-top hexagon for them). **Arrows, ticks, crosses and stars are icons, never typed characters** (the font has none, 5.1).
- **Role glyphs, redrawn from Wrenfell (R4).** The glyph is the real map's three lanes on the 48 px grid: a bowed arc on the left (the Top lane, Reedrun), a straight vertical line in the middle (the Mid causeway, Hush Causeway), a bowed arc on the right (the Bot lane, Lanternway). All three are drawn faint (`TEXT2` at 40 percent); the role then draws its own place at full strength in the role colour, and each has a different shape so the set works with colour removed:
  - **Top:** the left arc, thick.
  - **Jungle:** two small filled diamond (kite) gems in the pockets between the lanes (the left one larger: the open Thicket, the right one smaller: the tight Shallows).
  - **Mid:** the causeway line entering a ring at its middle (the Moonhulk isle).
  - **Bot Carry:** the right arc, thick, with a filled dot on it (the carry).
  - **Support:** the right arc, thick, with a short cross-bar through it (a plus: the one who helps).
  Rendered and viewed at 96, 64, 48, 32 and 24 px, in colour and in `TEXT2` only (style tile, section 7). Honest limits: Top and Bot Carry are mirror images apart from the dot, so at 24 px they separate mostly by side; Support's bar and Bot's dot are 2 to 3 px at 24 px. **A glyph used alone is therefore never smaller than 32 px**, and wherever it is 32 px or smaller it sits beside the role code (TOP, JG, MID, BOT, SUP) or the role name. The glyph is also the Squad lane map layout (6.4) and the Chemistry layout; the arena itself uses the slot letters T J M B S on side tokens, not these glyphs.
  **How the set differs from a square lane-map position icon (2c, for the IP re-screen of Scan 1 section E).** The IP Checker's concern is that a map with the role's lane lit is the concept of a well-known game's position icons (from the IP Checker's knowledge, not verified by me; I describe that set as a square map with its outer lanes along two edges and a diagonal, and I could not look at it). The idea "show the role's place on a map" is generic; the expression here differs in three concrete ways, all visible in the SVG paths of `ic_role_*.svg`:
  1. **No frame, no square, no corner, no diagonal.** The glyph is three free-standing vertical strokes, a bowed arc on each side (`M16 6 C3 17 3 31 16 42` and `M32 6 C45 17 45 31 32 42`) and a straight vertical between them (`M24 6 V42`). Nothing in the set turns a right angle, and the only strokes are vertical, bowed vertical and one short horizontal bar. A square tile with an L-shaped lit edge or a lit diagonal cannot be drawn from these parts. The shapes are Wrenfell's: a closed oval ring with two bowed side lanes and a plank causeway as Mid.
  2. **Each role is a different mark, not a different lit region of one picture.** Mid is the causeway broken by a ring (`M24 6 V17 M24 31 V42` plus `circle r=6.5` at the centre: the Moonhulk isle); Jungle is two small diamonds between the lanes (`M15 15.5 L20.5 24 L15 32.5 L9.5 24 Z` and `M33 17.5 L37 24 L33 30.5 L29 24 Z`) with no lane lit; Bot is the right arc plus a filled dot (`circle r=5.2` at 41.5, 24); Support is the same arc plus a plus-bar (`M35 24 H47 M41.5 18 V30`). Role marks (a ring, a dot, a bar, two gems) are ours.
  3. **Top and Bot are left and right of one vertical axis, not opposite corners.** The set reads as a bracket-and-bar sign `( | )`, mirror-symmetrical left to right, where the compared icons read as a square with a path from corner to corner. Support deliberately shares Bot's arc (the map says Support's home is beside the carry), so that pair separates by the bar and the dot, not by place.
  **My verdict:** acceptable as it is, no redraw. The remaining overlap is the generic idea of showing a role's place on a map, which nobody owns; the do-not list (9.2) forbids a set modelled on a specific game, and this one is built from our own map with our own marks. Residual risk, stated plainly: the set is still a map-based position set, so the IP Checker's re-screen (review item B14) should look at it next to the other set before launch. The three alternatives in Scan 1 (letter tiles, non-map role symbols, lane stripes only) stay as the cheap fallback if the verdict stays Change: it needs five new SVG files with the same names. I rendered the five glyphs at 4 times size and looked twice: the paths above match the drawing; the Jungle gems come within about 0.5 px of the centre stroke on the 48 px grid (tight, left as it is) and the Support bar ends under 1 px inside the grid edge.

### 6.2 Hero portraits (40 placeholder heroes, 5 roles)

Original, drawn in code or SVG, readable from 48 to 96 px. See the 96, 64 and 48 px samples on the style tile.
- **Frame:** circle. Ring in the role colour: 5 px at 72 px and larger, 7 px at 64 and below (so it stays visible), plus a 2 px dark outer ring so it separates from any surface. Selected: add the role-colour glow. Banned: desaturate the portrait, draw a 45 degree slash in `BAD`, and drop the ring to `TEXT_OFF`. Locked pick: add a small lock glyph at the lower right.
- **Background:** a radial gradient from the role colour mixed 52 percent into the page colour (upper left) to 16 percent (lower right), so the dark silhouette always has a lighter field behind it.
- **Silhouette per role** (a bust, filled `#0D1526`, with a role-colour rim light offset 2.4 px up and left to follow the top-left light), recognisable with colour removed:
  - Top: broad, square, heavy shoulders with two rounded pauldrons, a helmet with a crest, a visor slit.
  - Jungle: a pointed hood and a hooked horn on one side, two slanted eyes.
  - Mid: a tall narrow bust with a high collar, a round head, a floating orb on the upper right.
  - Bot Carry: a leaning bust with a cap and brim and a long diagonal weapon held low across the chest.
  - Support: round soft shoulders, a hood, a halo ring above the head, a small lantern at the lower right.
- **Accent:** eyes, visor, orb, halo and lantern are the only parts drawn in the role colour. They are what make a face read at 64 px.
- **Detail by size:** at 96 px full detail; at 64 px and below only silhouette, accent and ring (no hair lines, no texture).
- **Corner role glyph at 56 px and below (new in 2b).** The pass-2 tile review found that at 48 px the Jungle, Bot Carry and Support silhouettes are weak and the ring colour carries the identity, so "recognisable with colour removed" held at 96 px but not at 48. Rule: a hero portrait or avatar of **56 px or less** gets the role glyph in a 26 px dark `VOID` chip with a 1.5 px role-colour rim at the lower right (glyph 20 px). Portraits of 64 px and above do not need it. Shown on the tile (section 7). Honest limit: at 20 px the glyph is a hint, not a label, so lists still print the role code beside a small portrait.
- **Per hero variation:** the hero id picks, by hash, one of 3 head and hat variants per role (15 silhouettes in all) and a small hue offset (plus or minus 10 degrees) on the background, so the 8 heroes of a role are related but not identical. Archetype (bruiser, bulwark, shade, spellcaster, binder, gunner, mender) can later add a small accessory.
- **Players:** managed players are people, not heroes. Until a human artist paints them, show an **initial avatar**: circle, role ring, role-colour wash, the first letter in `TEXT`, role glyph at the lower right. Do not draw faces.
- **Honest limit:** silhouettes are stylised code art. They look consistent and readable, not painted. Characterful illustration needs a human artist, and the Founder's earlier decision postpones final character art to the pre-launch phase.

### 6.3 Club badges (generated from the club id)

Drawn on a 100 x 100 box, shown at 40 to 112 px. Every badge is: shape, body in the club primary, a pattern in the club secondary, an ink initial, a 3 px white 35 percent rim, a soft top-left gloss and a shadow.

- **Shapes (6):** 0 shield, 1 roundel, 2 hexagon (pointed top), 3 diamond, 4 swallowtail banner, 5 arch. All six have different silhouettes at 40 px.
- **Patterns (4):** 0 plain, 1 chief (top band, 28 percent), 2 base (bottom band, 28 percent), 3 chevron (bottom V). None reaches the initial.
- **Initial:** the first letter of the club name, uppercased, ExtraBold, ink `#0B1220`, centred at 66 percent of the height. One letter only: it stays legible at 40 px. (A later pass can add a tiny animal mark for the mascot: wolf, fox, hound, heron and so on. That is Concept Artist work; not specified here.)

**Algorithm (deterministic; the same id always gives the same badge).**
```
HUES = [4, 24, 44, 76, 128, 160, 196, 216, 242, 270, 304, 338]   # hand-spread so neighbours differ
h = FNV-1a 32-bit of the UTF-8 bytes of the club id           # start 0x811C9DC5; per byte: h ^= b; h = (h * 0x01000193) & 0xFFFFFFFF
hue_idx = h % 12;  q = h / 12 (integer)
shape = q % 6; q /= 6; pattern = q % 4; q /= 4; sec_mode = q % 2; q /= 2; lt = q % 4; q /= 4; sat = q % 3
# clash resolution, clubs processed in sorted id order:
#   hue: if fewer than 12 hues used, while hue_idx is used: hue_idx = (hue_idx + 5) % 12
#   shape+pattern: if fewer than 24 pairs used, while (shape, pattern) is used: shape = (shape + 1) % 6, and whenever shape wraps to 0 and the pair is still used: pattern = (pattern + 1) % 4
hue = HUES[hue_idx]
primary: HSL(hue, S = 0.62 + 0.06 * sat, L found by 24-step bisection on L in [0.15, 0.85]
         so the WCAG relative luminance of the colour reaches 0.24 + 0.04 * lt)
secondary: sec_mode 0 -> HSL(hue, 0.35, 0.90);  sec_mode 1 -> HSL(hue, 0.55, 0.16)
hex: each channel = int(value * 255 + 0.5)    # round half up, not banker's rounding
```
Note for the programmer: HSL here is the CSS definition, not Godot's HSV (`Color.from_hsv`). Write a 15-line HSL to RGB helper.

**Expected output for the 10 current clubs** (use as the unit test; allow plus or minus 1 per channel because of float rounding in the bisection):

| club id | hash | hue | shape | pattern | primary | secondary | ink on primary | primary vs secondary | primary vs card |
|---|---|---|---|---|---|---|---|---|---|
| duskwater_foxes | 0608c2e9 | 270 | shield | plain | `#BC8FEA` | `#29123F` | 7.4 | 6.6 | 5.8 |
| emberfen_hounds | 462833c5 | 24 | roundel | chevron | `#DA9160` | `#3F2412` | 7.3 | 5.6 | 5.8 |
| gildmoor_raiders | a0cdac0f | 76 | diamond | chief | `#82A520` | `#333F12` | 6.6 | 4.0 | 5.2 |
| ironquill_wolves | ceb0648d | 160 | banner | chevron | `#1AAF7D` | `#DDEEE8` | 6.7 | 2.3 | 5.3 |
| mossgate_wardens | 03f49819 | 196 | banner | chief | `#20A4D5` | `#12333F` | 6.5 | 4.7 | 5.2 |
| northreach_corsairs | a6ef26b0 | 128 | roundel | plain | `#22B035` | `#123F18` | 6.5 | 4.2 | 5.2 |
| pinehollow_owls | 8e0ff5c2 | 44 | hexagon | chief | `#AF8C29` | `#3F3312` | 5.9 | 3.9 | 4.7 |
| saltmarrow_gulls | 861a265b | 216 | roundel | chief | `#4886E4` | `#DDE4EE` | 5.2 | 2.8 | 4.1 |
| stormvale_herons | 300c8fd2 | 4 | banner | plain | `#E57B74` | `#3F1512` | 6.6 | 5.6 | 5.2 |
| thornwick_stags | 73950e4b | 338 | hexagon | plain | `#DC6B95` | `#EEDDE3` | 5.9 | 2.4 | 4.6 |

Checks on these ten: 10 distinct hues, 10 distinct shape plus pattern pairs, ink letter at least 5.2:1, primary against card at least 4.1:1, primary against secondary at least 2.3:1. For more than 12 clubs hues repeat, for more than 24 shape plus pattern pairs repeat; the league has 10, so this holds today. The sec_mode, lt and sat values add variety but are not used for uniqueness.

Honest notes: the colours skew soft because of the brightness window (needed for letter and surface contrast). If the Founder wants bolder clubs, widen the window and switch the letter to white for dark clubs; that needs a second contrast rule. The club names and the hues are still placeholders with the names.

### 6.4 Squad lane map: token positions from the arena map (R3, R4)

The Squad screen's hero is a 672 x 440 px inset card (578 x 380 in large text) that shows **the player's half of Wrenfell**: the window is x 0 to 1 and y 0.38 to 1.00 of the arena (the player's half plus a little past the centre line, so the lake's lower half and the clash points are in frame). Mapping: card x = `x` times 672; card y = (`y` minus 0.38) times 760 times (672 / 720) = (`y` minus 0.38) times 709.3. Because the arena always puts the player at the bottom (`ARENA-MAP.md` 4), the map is the same whichever side the player has. Tokens use the data in `game/data/arena_map.json` (checked 2026-11-08, 20:43 version).

| Slot | Anchor, arena (x, y) | Where it comes from | Card px at 672 x 440 | Card px at 578 x 380 |
|---|---|---|---|---|
| Top | 0.110, 0.540 | on the Top lane, between node `B.top.4` (0.110, 0.580) and the clash point `N.top.mid` (0.110, 0.500) | 74, 114 | 64, 98 |
| Jungle | 0.270, 0.700 | midpoint of camps `B.w1` (0.215, 0.700) and `B.w2` (0.300, 0.650) is (0.2575, 0.675), nudged 0.025 u so it clears Top | 181, 227 | 156, 195 |
| Mid | 0.500, 0.720 | on the causeway, 0.015 above node `B.mid.1` (0.500, 0.735) | 336, 241 | 289, 207 |
| Support | 0.840, 0.742 | node `B.bot.2`: the Bot lane, behind the carry (the map says Support's home is "Bot lane, beside the carry") | 565, 257 | 485, 221 |
| Bot Carry | 0.889, 0.540 | on the Bot lane, between `B.bot.4` (0.887, 0.580) and `N.bot.mid` (0.890, 0.500) | 597, 114 | 514, 98 |

(The placeholder positions in `UI-PASS-2.md` 6.2, TOP 18/20, JG 68/28, MID 45/50, BOT 80/80, SUP 58/84 percent, are replaced by this table. They put Jungle top-right and Support bottom-centre, which is a third arrangement that matches neither the arena nor the glyph.)

- **Token:** 96 px outer diameter (exactly the 96 px touch minimum, so the hit area is the token itself; in large text the tokens stay 96 px and only the centres move). Initial avatar (6.2): inner disc 78 px in the role colour mixed 55 percent into `BG`, 6 px role ring, 2 px `VOID` outer ring, the initial in 44 px SemiBold `TEXT`. Rating badge: a 36 px `PANEL3` disc at the upper right with the number in 24 px Bold. Status icon: a 32 px `VOID` chip with a 2 px rim at the lower right, only when the player is tired or in form (a down or up triangle icon, `WARN` or `GOOD`, shape differs so colour is not the only cue; a status the player must act on also gets a word in the picker). Name: 26 px Medium `TEXT`, a 5 px `VOID` outline, 76 px below the token centre, wrapping to two lines in large text. **No role glyph on the lane map**: the lane is the role. (Glyphs appear on the bench cards and in the picker rows.)
- **Spacing check (computed from the table, ring to ring, token 95 px across the dark ring):** Sup to Bot 52 px, Jungle to Mid 60, Top to Jungle 61, Mid to Support 134; at 578 x 380 with 96 px tokens the smallest are Sup to Bot 31 px, Jungle to Mid 39, Top to Jungle 39. No token overlaps another or its neighbour's name.
- **Backdrop (code-drawn, no asset needed):** `VOID` fill; two `MAP_LAND` pocket ellipses at 85 percent (centres (0.22, 0.66) and (0.78, 0.66), radii 0.13 and 0.12 of the card width and 0.17 u high); the plaza ellipse (196 x 80 arena px, scaled) in `PANEL2` with a 2 px `ACCENT` stroke at 45 percent and the Cairn plate; the Mere circle (128 arena px radius) in `MAP_MERE` with a 3 px `MAP_SHORE` rim and the island (76 px) in `PANEL2` with a `TEXT2` crescent; the three lanes as 40 / 56 / 64 arena px wide strokes in `PANEL3` with a white 12 percent centre line. The top of the card cuts the lake, on purpose. Shown on the style tile (section 9), where it was rendered and looked at twice.
- **Why 96 px and not the 128 px of `UI-PASS-2.md` 5.6:** drawn at 128 px the five tokens covered most of the card, touched each other (12 px gaps at the first anchors tried) and hid the roads, so the card read as five bubbles over a blur, not as a map. At 96 px the lanes, the lake and the plaza are all visible. The `Token` variant in 5.6 ("Token 128") should read 96, and the Tall card's 120 px avatar can stay.
- **Fallback (D3):** if the map does not read in testing, five role cards in a row or two columns: the role glyph at 48 px, the avatar, name, rating and status. The same tokens, no backdrop.
- **Chemistry** (`UI-PASS-2.md` 8.5, UI Pass 3) reuses the same card, anchors and tokens, and draws its bond lines between them in `DIM` to `ACCENT`.
- Not tested: a thumb on a phone, whether the map reads at a glance, 5 tokens plus names at 578 x 380 in a real large-text run.

## 7. Motion principles

The reference (UI-UX-REFERENCE 5.3) already fixes: press feedback within 100 ms, count-ups, ease-out bar fills, no transition longer than 250 ms. This pass keeps those and adds:

**Interpretation to confirm with the Creative Director:** the 250 ms limit applies to **transitions** (screen changes, sheets, tab changes, toasts) and to any motion that blocks input. **Reveals** (a number counting up, a bar filling, a result stamp) may run up to 600 ms (the existing `T_COUNT`) if they never block a tap and a tap completes them at once. **Ambient loops** (the Play glow) are allowed on one element only, slow, and off when animations are off.

| Event | Duration and curve | Detail |
|---|---|---|
| Button press | 80 to 120 ms down, spring back | scale 0.97, fill moves to the pressed gradient, glow off; existing `_pulse` |
| Tab change | 160 ms fade, no slide | the selected pill slides to the new tab in 180 ms ease-out |
| Forward screen | 220 ms slide ease-out | back is the reverse in 180 ms |
| Bottom sheet | 220 ms up, 160 ms down | shadow E3 fades in with it |
| Card enter | 160 ms: fade plus 8 px rise | lists stagger 20 ms per item for the first 6, so the whole list is in within 250 ms |
| Toast | 180 ms in, 160 ms out | |
| Count-up, bar fill | up to 600 ms ease-out cubic | skipped by tap; a small white spark rides the bar end |
| Result stamp ("Victory") | 220 ms: scale 1.15 to 1.0 with a 2 px overshoot | plus gold sparkle burst, see below |
| Draft pick lock-in | 200 ms | portrait scales 1.1 to 1.0, ring flashes to `TEXT`, lock glyph pops in |
| Draft ban | 180 ms | portrait desaturates, slash draws across |
| Draft timer | continuous | ring turns `WARN` at 5 s and ticks once a second; low urgency, no shake |

With Animations off in Settings: everything switches state in one frame, glows stay static, no ambient loop.

**What the Animator should do:** build the table above as reusable tween helpers in one place (`UI.anim_*`), with the 250 ms and 600 ms rules enforced in the helper; design the tab pill slide, card entrance, result stamp, lock-in and ban; check every timing against the limits; add a "reduced motion" path for each.

**What the VFX Artist should do:** (a) gold sparkle burst for Victory and a trophy: 10 to 24 particles, 600 ms life, one `CPUParticles2D`, round soft dots in `WARN` and `TEAL_HI`; (b) a one-off 400 ms light sweep across a trophy or a new-best card (a pre-baked gradient strip, not a shader); (c) the pick-lock ring flash; (d) the Play glow breath. Budget: no full-screen blur, no post-process, no screen-space shaders; glows are pre-baked textures or `StyleBox` shadows (the project uses the GL Compatibility renderer, so keep to simple 2D). Everything stays under about 24 live particles. Effects for the arena (Alpha 0.8) are planned with the Engine / Graphics Programmer's budget.

## 8. Per-screen upgrade list

Layout belongs to the UI/UX Designer (W3); this list gives the visual treatment and the helper each one needs. Helper changes are in 8.1; the Lead Programmer implements them in `game/src/ui/ui.gd` with me.

### 8.1 Changes to `ui.gd` helpers

| Helper | Change |
|---|---|
| Tokens | Update the values in 3.1 to 3.3 in place (`PANEL`, `PANEL2`, `PANEL3`, `DIM`, `BAD`, `GOOD_CB`, `BAD_CB`); add `VOID`, `BG_GLOW`, `TEXT2`, `TEXT_OFF`, `TEAL_HI/LO/DEEP`, `CORAL_HI/LO`, the five role colours, `SIDE_BLUE` and `SIDE_RED` (flag cloth only; `SIDE_RED` has the value of `BAD_DEFAULT` and is not swapped in colour-blind mode; today's `BLUE` and `RED` become these), `MAP_LAND`, `MAP_MERE`, `MAP_SHORE` (the only new map colours; nothing else from `ARENA-MAP.md` 9 becomes a token); sizes, one set (5.2): `S_DISPLAY` 64, `S_TITLE` 48, `S_BIG` 40, `S_HEAD` 36, `S_BODY` 32, `S_SMALL` 26, `S_CAPTION` 24 (the floor); `R_CARD` 24, `R_BTN` 20, `GAP` 16, `BTN_H` 96, `CHIP_H` 44 |
| `make_theme()` | Default font and fallbacks; Button/Panel styles from the new surfaces; `ScrollBar`: 4 px rounded, `DIM` at 40 percent, hidden when idle (replaces the grey `#717377`); `CheckButton`/switch: track `PANEL3` off, `ACCENT` on, white knob 28 px, a 2 px edge (fixes 1.06:1); `ProgressBar` background `VOID` with an inset top line |
| `box()` / new `surface(elev)` | `surface(1..3)` returns the cached gradient 9-slice style (4.1); `box()` stays for flat uses |
| `card(parent, ...)` | Add `elev` (1 default, 2 for hero and nested) and `rail` (a 4 px club or status stripe on the left); padding 24. Old callers passing `PANEL2` map to `elev` 2 |
| `button(..., kind)` | Kinds: `play` (coral gradient, glow, highlight; one per screen), `primary` (teal gradient, confirm and selected), `normal` = secondary (`PANEL2` gradient, edge, `TEXT`), `ghost` (was `flat`), `danger`, and **`ban`** (2c): outlined, never filled with a colour. `ban` is a `PANEL2` gradient fill, a 2.5 px `WARN` rim, a drawn warning-triangle icon in `WARN` before the label (the icon is a drawn shape, not a typed "!"), the label in `TEXT` Heading 36 SemiBold ("Ban Gravenstone" 241 px of 624). Measured: `WARN` rim on the `PANEL3` sheet 3.7 to 4.9:1 (needs 3:1), `WARN` icon on the button 5.3 to 6.8:1, `TEXT` on the button 7.8 to 10.0:1. It is never pink, red, coral or `BAD`: the pink Ban of the reference game is the one visible match the IP Checker found, and a red button would also tell the player that banning is a mistake. The only coral action on the draft sheet is Pick (`play`), and the two never show together: the sheet carries one full-width 96 px button for the current phase. Add optional leading icon. Left-aligned variant for rows. Pressed look uses the `LO` values. Disabled: `PANEL` with `TEXT_OFF` |
| `chip()` / `chips()` | Full pill, 44 px high, 24 px SemiBold, `on` argument (1, 2) applying the lift rule (3.4), optional 28 px icon (the chip text and the icon both come from the one token set; a tappable thing is a button or an attention card, not a chip) |
| `bar()` / `versus_bar()` | Height 20; track `VOID` inset; fill gradient with rounded ends and a spark; optional `potential` ghost segment (current solid, potential at 25 percent alpha) and a threshold tick. Versus bar: 6 px gap, teal vs coral gradients, a centre notch |
| `tile()` | Add an icon slot (top right, 32 px), a delta line with arrow, E1 surface; `tile` stays one button |
| `kv_row()` | Label `TEXT2`/`DIM`, value `TEXT`, tabular numerals, optional arrow |
| `delta_color()` | Keep; add `UI.delta_text(x)` returning an **arrow icon id** and the signed number (never a typed arrow character: the font has none, 5.1) so colour is never the only cue |
| `section()` | Header as a row with chevron icon; title `Heading` in `TEXT`; open content on a lighter surface |
| New | `page_bg()` (gradient, optional Lane Bows pattern); `section_title(parent, text, icon)` (the Caption section label of 5.2: 24 px SemiBold, upper case, +8 percent tracking, `TEAL_HI`; Horizon underline only for a major group); `row(portrait, title, subtitle, trailing)` left-aligned list row (replaces centred buttons); `segmented(items)` for tabs (single line, scrolls, never wraps); `portrait(hero_id, role, size)` (adds the corner role glyph at 56 px and below); `avatar(name, role, size)`; `badge(club_id, name, size)`; `icon(name, size, color)`; `flag(side)` (pennant for Blue, swallowtail for Red); `side_glyph(is_me, size)` (circle for you, flat-top hexagon for them); `side_token(is_me, letter)` (the arena hero token of 3.8); `lane_map(lineup, size)` (the Squad and Chemistry card of 6.4); `attention_card(text, on_tap)` (3.7 rule 9); `anim_*` tween helpers |

### 8.2 Screens

| Screen (file) | Visual upgrade | Helpers |
|---|---|---|
| Title (`screen_title.gd`) | Full dusk background (teal and coral glows, faint arcs); wordmark Display with the Horizon line; New game as the single coral go button, About as ghost; version in `DIM` | `page_bg`, `button play/ghost` |
| Club select (`screen_club_select.gd`) | Each club a card with its 72 px badge, name, rating chip and tier chip, 4 px left stripe in the club colour; "Take over" as secondary, only the first pick or hovered one gets teal; no coral | `card rail`, `badge`, `chip` |
| Hub (`screen_hub.gd`) | Remove the welcome card above Play (it moves into the W1 coach overlay), so Play sits in the top 40 percent. **Hero (R5):** page gradient plus the club colour at a flat 10 percent behind the 248 px header block, neutral `VOID` skyline silhouettes, the badge at 112 px in full colour; no full-strength club gradient (3.7 rule 8). Next-match card E2 with both club badges at 96 px, the versus bar (you teal on the left, them coral on the right), a neutral "Blue side" or "Red side" chip with a flag icon (3.8), and the one glowing coral Play. Tiles with icon and delta arrow icon. **"Needs your attention":** UI-PASS-2's swipe row, drawn as 96 px attention cards with a `WARN` left rail (3.7 rule 9). Page gradient | `card elev 2`, `badge`, `button play`, `tile`, `page_bg`, `flag`, `attention_card` |
| Tab bar (`main.gd`) | Icons at 48 px plus 24 px labels; selected is a `PANEL3` pill gliding in 180 ms with `TEAL_HI` icon and label; the bar is E2 with the shadow cast upward; attention dot on a tab: 14 px `BAD` with a 2 px page-colour ring | `icon`, `surface` |
| Squad (`screen_roster.gd`; was Roster) (R3) | **Lane map and bench grid.** Header "Auto lineup" button; a strip of four stat pills (rating, chemistry, squad count, wages) as 44 px chips; the lane-map card of 6.4 (672 x 440; five 96 px initial-avatar tokens at the anchors of 6.4: Top (0.110, 0.540), Jungle (0.270, 0.700), Mid (0.500, 0.720), Support (0.840, 0.742), Bot (0.889, 0.540); rating badge and one status icon per token; name below; no role glyph on the map because the lane is the role); the bench as a 2-column grid of Tall player cards (role colour as an 8 px left bar plus the role glyph and code, avatar 120, name, rating, at most two status chips plus "+n"); a Reinforcements carousel; picker and detail as E3 sheets (rows 112 px with the role glyph, signed team-rating change, no `BAD` on the row itself); stat bars with potential ghost segment; renew is teal, release is ghost. Section labels as the Caption label (5.2). **Fallback (D3):** five role cards in a row or two columns (glyph 48, avatar, name, rating, status), same tokens, no backdrop | `lane_map`, `avatar`, `row`, `bar potential`, `chip`, `section_title` |
| Chemistry (`screen_chemistry.gd`, `bond_pentagon.gd`) | The same lane-map card and anchors as Squad (6.4) with the tokens as nodes; link thickness plus colour from `DIM` (weak) to `ACCENT` (strong); matrix cells a teal ramp instead of brown `#6c4828`, number in `TEXT`; legend with arrow icons | `lane_map`, `avatar`, tokens |
| Training (`screen_training.gd`) | Rows with avatar, focus icon chip, before and after bars with delta arrow; "Coach picks" is teal; tired and rest shown with icons and chips, never colour alone | `row`, `bar`, `chip`, `delta_text` |
| Match day (`screen_prematch.gd`) | Five lane rows: role glyph centred, your number and theirs, a split bar and an arrow (colour plus arrow, not coloured text only); club badges at the top; tired warning as a gold rail card | `row`, `versus_bar`, `badge` |
| Draft (`screen_draft.gd`) | Header: step pips (12) and a timer ring that turns gold at 5 s; the title in sentence case at 40 px Bold: "Your ban", "Your pick", "Their ban", "Their pick" (141 to 161 px, 200 px room, two lines in large text, 5.2); board: you on the left under a circle glyph, them on the right under a hexagon glyph, each side's Blue or Red word with its flag icon (this is the only place besides Home where Blue and Red appear); hero tiles 3 per row with 96 px portrait, name `Small` SemiBold, archetype chip, "best 82" in `DIM`; ban state desaturated with slash; pick state ring and glow; "Coach suggests" a teal star icon chip on the best tile; role filter as `segmented` with role glyphs at 32 px beside the code; slot panel as an E3 bottom sheet with one full-width 96 px button for the phase: **Ban is the outlined `ban` button** (warning icon, `WARN` rim, no fill colour), **Pick is the coral `play` button**, so the draft screen has at most one coral action (sample on the style tile, section 4) | `portrait`, `segmented`, `chip`, `surface 3`, `flag`, `side_glyph` |
| Draft done (`screen_draft.gd`) | Two team columns with portraits in role order, circle and hexagon column glyphs; composition chips; the opponent's composition in neutral or the coral hexagon style, never `GOOD`; Start the match as the coral go button | `portrait`, `chip`, `button play`, `side_glyph` |
| Game plan (`screen_game_plan.gd`) | Expected edge as a large centre-zero gauge; per-contest rows with a mini bar and arrow; five-step controls as a segmented row with the zero step marked; Default, If behind, If ahead as `segmented` | `bar`, `segmented`, `delta_text` |
| Match (`screen_match.gd`; Alpha 0.7 keeps today's screen with the global tokens, the arena HUD is Alpha 0.8) | **Structure per `UI-PASS-2.md` 6.7, tokens per 3.8 and 3.9.** The stack, strip heights, clock (32 px in the 44 px row A), lead graph (row C), the two-line feed with no timestamp, the plan and intent rows and the controls come from UI-PASS-2 6.7.2 and 6.7.3, not from this file. What this file fixes: both club badges in the scoreboard; the side glyph (circle or hexagon) before the words of every feed line, the words in `TEXT`, an icon (tick or cross shape) for who won the beat, no timestamp, no `BAD` text and no Blue or Red; the lead graph's band teal above the centre line and coral below it (a bar half, never text; the objective markers carry the owner's shape); the arena of `ARENA-MAP.md` drawn with the tokens of 3.8 and 3.9 (teal circles and coral hexagons, 36 and 40 px in big fights); "See the report" is the one coral go button, a rounded rectangle with words, so it cannot be confused with the hexagons above it | `row`, `badge`, `versus_bar`, `side_glyph`, `side_token` |
| Report (`screen_report.gd`) | Result banner: "Victory" in Display with the stamp and a gold sparkle; "Defeat" in `TEXT` with a calm `BAD` glyph, not a red wall; MVP as a 96 px portrait with its percent; change rows with delta arrows; "Why it went this way" bars with gradient fill and arrows; Continue is the coral go button | `card elev 2`, `portrait`, `bar`, `delta_text`, `anim_stamp` |
| Standings (`screen_standings.gd`) (R3) | **Three views**, not five: Table, Playoffs, History as one `segmented` row (three labels fit one line at 578 px: "Playoffs" 103 px of 160). **Table:** a Points / Form switch in the header (Form changes the number on each row and re-sorts; it is no longer a chip or a tab); top three on a podium with 88 / 72 / 72 px badges; rank rows 104 px high with a **56 px badge** (was 40), name Body (up to two lines), points at Heading 36 over the record in Small 26; the dashed playoff line after rank 4 with a text label; own row on `PANEL3` with an 8 px `ACCENT` left bar and a "YOU" pill (club colour appears only in the badge, never as the row tint); a pinned own-row sentence above the tab bar. **Playoffs:** a drawn bracket, series cards with win pips, a tick on the winner, your series with the accent bar and the YOU pill. **History:** trophy shelf (gold, silver, bronze cups) and recent-games cards with a W or L pill (shape and letter, not colour alone). No coral anywhere on the screen | `segmented`, `badge`, `row` |
| Finance (`screen_finance.gd`) | Balance hero card with the number in Display and one wage-versus-cap bar; sponsors as three cards with a coin icon, selected has a teal ring and glow; no wall of centred text | `card`, `bar`, `icon` |
| Free agents (`screen_free_agents.gd`) | Rows with avatar and role ring, rating `Value`, potential ghost bar, ask in a coin chip; filters as chips (single line, scroll) | `row`, `avatar`, `chip` |
| Negotiation (`screen_negotiation.gd`) | Keep the preview panel (before to after rows with arrows) on an E2 surface; offers left as three pips; Offer as `Value` with steppers; Accept is teal | `kv_row`, `chip`, `button primary` |
| Settings (`screen_settings.gd`) | New switches (visible on and off); group headers with icons; a preview line under each comfort option; the colour-blind option shows both swatch pairs | `make_theme`, `section_title` |
| Season end (`screen_season_end.gd`, `screen_game_over.gd`) | A code-drawn trophy in gold gradient with a one-off sweep and sparkle for a title; champion badge large; growth list as delta chips | `badge`, `chip`, `anim_*` |
| Plan, Club tab, Practice, About (`screen_plan.gd`, `screen_club.gd`, `screen_practice.gd`, `screen_about.gd`) | Tiles with icons and deltas; empty states get an icon and one line, not a void (`19e_practice.png`, `17_standings_results.png`); About keeps text on cards with `Body` 32 | `tile`, `card`, `icon` |

## 9. Do-not list and originality rules

### 9.1 Do not

- No neon cyan plus magenta "cyberpunk" glow, no glitch, scan-line or chromatic-aberration effects.
- No angular chamfered "tech frames" with notched corners; no hazard stripes; no carbon-fibre or metal textures; no hex-grid backgrounds.
- No fire, lightning-bolt, skull, claw-mark or flaming-animal mascots; no lens flares; no heavy purple-to-pink gradients; no "gold and black premium" panels.
- No all-caps italic extended headings; no more than two weights per card.
- No colour on its own to mean good or bad, side, role or club; always sign, arrow icon, glyph, shape or word.
- No coral on anything but the one go action and "them" (the hexagon token, the right half of a versus bar, the hexagon glyph); **no more than one coral action (anything tappable) per screen**. (2b: relaxed from "one coral thing".)
- No `BAD` on a side, a token or a map element; no Blue or Red tint anywhere in the arena (Blue and Red are a word plus a flag icon on Home and the draft board only); no teal or coral hit effects.
- No typed arrow, tick, cross or star characters (the font has none): drawn icons only.
- No full-strength club-colour fill behind text; the club colour is a 10 percent wash behind that club's own header and the badge itself.
- No tinted chip on an overlay surface; no `DIM` text on an overlay surface; **no text smaller than 24 px in the UI** (2b: was 22; the style tile's own annotation captions are documentation and exempt). Map labels are 24 px at their rendered size.
- No centred text rows in lists; no text laid directly on the background pattern.
- No more than two glowing things on screen; no animated background; no particle effect that blocks a tap.
- No pentagon of avatars for Chemistry (already decided); no club-coloured UI chrome.
- No pink Ban and green Pick button pair, **no solid pink, red or coral Ban button** (Ban is outlined with a warning icon, 8.1), no Install-style bright banners, no upsell tile or lock icon in the core loop (Founder pillar).
- No logo until the final name clears the trademark search.

### 9.2 Anything resembling ESMO or any other game

- The reference game is dark charcoal with lavender buttons and olive-gold upsell tiles. Our buttons are teal and coral on navy. Lavender or periwinkle is allowed only as the small Top role ring, never as a button or fill. Olive-gold is not used (our gold `#F2C14E` is a warm yellow, for warnings and trophies).
- Our Ban is a desaturated portrait with a slash and a `BAD` edge, and its sheet button is the outlined `ban` button (a `WARN` rim and a warning icon on `PANEL2`); our Pick is a teal ring with a lock, and its sheet button is the coral go button. Do not reproduce the reference's pink Ban and green Pick bottom-sheet buttons.
- Do not copy layouts, icons, hero art, colour values, names or wording of any game. Do not trace, colour-pick from or screenshot reference material into our assets. The ads and Install pages in the recordings are third-party material and are not reference.
- Do not use the visual conventions that are another game's signature: no champion-portrait frame with a level badge in a corner, no gold-wing rank crests, no hextech or runic ornament, no map or icon set modelled on a specific game. Role glyphs and silhouettes here are our own constructions.

### 9.3 Originality rules

1. Every shipped picture is drawn by us in code or SVG, or is a third-party asset under a licence that allows bundling (OFL, CC0) and is **logged**: name, source, licence, date. The font is the first entry.
2. No image generator output in shipped art unless the Founder and the IP & Originality Checker have approved its licence terms (unknown today).
3. All club, hero and player names and all art go to the IP & Originality Checker before they leave placeholder status. Entries to add to `IP-RISK-LOG.md`: the role map glyph set (2b: redrawn as the Wrenfell "Lane Bows", `ic_role_*.svg`) and the `bg_lane_bows.svg` motif; the five role silhouettes and the halo, orb, horn and crest motifs; the six badge shapes; the side glyphs (circle and flat-top hexagon) and the two flag icons; the font and its licence (with the file hashes in 5.1); the periwinkle Top ring colour (a low risk, noted because of the reference's lavender; 2b also removed the lilac moon so there is one periwinkle, not two).
4. No real club, team, brand or esports organisation logo or name; mascot animals stay generic (no famous crest shapes). Check the six badge shapes against well-known club crests before launch.
5. The Founder approves the concept direction (style tile) before the build, then before-and-after screenshots (plan W2 acceptance).

## 10. Open items, risks and decisions

- **Decision (Founder):** approve the style tile as the visual direction. Recommendation: approve. It stays inside what you already chose (Arena Dusk) and changes depth, pictures and type, not identity.
- **Decision (Founder):** the font. Recommendation: Barlow Semi Condensed (free, OFL). Alternative: Nunito Sans.
- **Decision (Creative Director):** confirm the reading of the 250 ms rule (transitions 250 ms, reveals up to 600 ms, one ambient glow). Recommendation: confirm.
- **Defaults the Founder may overrule at the checkpoint (2b, from the Producer):** R1 text 15 percent bigger (body 32 px, floor 24 px); R2 you teal circle and them coral hexagon in the whole match, Blue and Red only as a word and a flag; R3 Standings as three views and Squad as a lane map with five role cards as the fallback; R4 role icons redrawn from the real map; R5 club colour as a 10 percent tint, not a colour wall. Recommendation: accept all five; each was checked with numbers (3.7, 3.8, 5.2, 6.4).
- **Risk:** baked 9-slice surfaces, shadows and gradient banding have not been tried on a low-end phone. The Engine / Graphics Programmer should test on the lowest target device before the visual pass is committed.
- **Risk (2b, updated):** the font was read and measured in 2b (5.1) but never loaded in Godot. Open: does Godot 4.3 on Android honour `tnum` through `FontVariation`; do the five static TTFs import cleanly; does the `SystemFont` fallback give consistent glyphs on a real phone. Digits are proportional without `tnum`, so a failed `tnum` breaks column alignment in tables.
- **Risk:** the colour-blind pair separates less in greyscale than the old one (1.38 against 1.68:1) because it was lightened for text contrast; arrows and signs are mandatory for that reason.
- **Risk (2b):** teal and coral are about equally bright (1.21:1), so in greyscale or monochromacy the sides differ only by shape, letter and position; coral also means "go" and "them" and Match is the one screen with both. QA needs a greyscale and a colour-blind screenshot of Match to confirm hexagons and the go button are not confused.
- **Risk (2b):** the lane map at 578 x 380 in large text has 31 to 39 px between tokens and was only drawn, never run; the five-card fallback exists for that reason.
- **Risk (2b):** the arena cannot grow with large text (it must fit 626 px), so map labels stay at 24 design px (12 dp), not 13.8 dp.
- **Risk:** the club colours skew soft by design (section 6.3); the Founder may want bolder ones.
- **Risk (2b, replaces the old Display cap note):** large-text mode changes the canvas, not the pixel sizes, so no cap is needed; the string widths were measured (5.2) but only for strings I could find in the specs. QA must still re-run large-text and colour-blind screenshots on every screen above.
- **Risk (2c):** Ban is now an outlined button, so a ban-phase screen has no coral action and the commit button is less loud than Pick. The full width, the 96 px height and the hero name in the label are the answer; add "does the player find the Ban button on the first try" to the Alpha 0.7 tester questions. Not run on a phone.
- **Risk (2c):** the role-glyph verdict is my own reading of a comparison I could not look at (6.1). The IP Checker's re-screen decides; the fallback set is cheap.
- Hand-offs are listed in the handback of this task.
