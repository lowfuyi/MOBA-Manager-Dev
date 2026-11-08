# Art bible, pass 2: "Arena Dusk, richer"

Owner: Art Director. Date: 2026-11-08. Workstream W2 of `docs/ALPHA-0.7-PLAN.md`. Status: proposal for the Creative Director and the Founder's concept approval. Nothing here has been built in Godot or run on a phone.

Companion image: `docs/design/art/style-tile.svg` (source) and `style-tile.png` (720 px wide). Open it first: every token below is drawn on it.

## In short (for a phone read)

- The Alpha look is not wrong, it is flat. The three surface colours are almost the same brightness (only 1.16 to 1.26 times apart), there are no shadows, no icons, no pictures, and the same two-colour button is used for everything.
- Fix: keep Arena Dusk (navy, teal, one coral "go"), but add depth (four elevations with shadow and a top highlight), a dusk gradient behind pages, glow on the one important button, a real type scale, and pictures: a role-ring hero portrait and a generated badge for every club.
- Everything is drawn in code or SVG by us, so it is original. Real painted art needs a human artist later.
- Needs your OK: the free font Barlow Semi Condensed (licence SIL OFL 1.1, free to bundle in a game), and the style tile as the visual direction.

## 0. How this was produced (and what it is not)

- Read: `art-director.md`, `ALPHA-0.7-PLAN.md`, `UI-UX-REFERENCE-v1.md` (5.2, 5.3), `game/src/ui/ui.gd`, `game/project.godot`, `game/data/clubs.json` and `heroes.json`, `IP-RISK-LOG.md`, `DECISIONS.md`.
- Looked at all 49 screenshots in `docs/design/art/current/` twice. Pass 1: a critique screen by screen. Pass 2: re-looked for what pass 1 missed (it found: the wrapped tab words, the green opponent bonus, the brown matrix cells, the invisible switches, the grey scrollbar, the tiny text in dp, the 92 px buttons). Those are cited below.
- Numbers (contrast ratios, colour-blind distance, badge values) were computed with small Python scripts: WCAG 2.x relative-luminance contrast; colour-blind simulation with the Machado 2009 matrices (protan, deutan, tritan at full severity) and CIE76 Lab distance (dE). These are approximations, not a lab test. The scripts are not in the repo (I was asked to write only the named files); the formulas are in section 3 so QA can re-check.
- Not done: no Godot run, no phone, no screenshot of the changed game. The style tile is a picture of intent, drawn in SVG, not a render of Godot widgets. The recommended font is not installed on the build computer, so the tile shows the type scale in Inter as a stand-in (Inter is wider than the recommended font, so layouts that fit in the tile will also fit in the real font).

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

Three signature motifs make it ours: **the Horizon** (a thin 3 to 4 px teal-to-coral line under screen titles and at the end of cards, the sky meeting the sun), **the Lane Diagonal** (a faint 35 degree stripe in backgrounds and badge patterns, from the map's mid lane) and **the role map glyph** (icons for the five roles drawn as the map with the lane highlighted).

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
| `CORAL` coral 500 | `#FF8A5C` | same | 8.1 | 6.4 | 4.9 | THE go action; one per screen; also "them" in versus bars |
| `CORAL_HI` coral 300 (new) | `#FFB594` | | | | | coral text on overlay (4.8) |
| `CORAL_LO` coral 700 (new) | `#E4602F` | | | | | pressed state |
| `WARN` gold | `#F2C14E` | same | 11.2 | 8.8 | 6.8 | warnings, "needs attention", trophies |
| `GOOD` | `#5BD68A` | same | 10.3 | 8.1 | 6.2 | gains, wins |
| `BAD` | `#F58080` (was `#ef6b6b`) | | 7.4 | 5.8 | 4.5 | losses, damage. Lifted so it reaches 4.5:1 on the raised surface (the old value gives 3.8 there) |
| `GOOD_CB` | `#7FD0FF` (was `#56b4e9`) | | 11.1 | 8.7 | 6.7 | colour-blind good |
| `BAD_CB` | `#F2924A` (was `#d55e00`) | | 8.1 | 6.3 | 4.9 | colour-blind bad (was 3.38 on raised) |
| `SIDE_BLUE` / `SIDE_RED` | `#5AA9FF` / `#FF7A7A` | `BLUE` / `RED` | 7.7 / 7.5 | 6.0 / 5.9 | 4.7 / 4.5 | side tags only, see 3.6 |

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

Chosen by search for the best worst-case separation. Smallest distance (CIE76 dE) between any two roles: 47.3 for normal vision, 29.9 protanopia, 29.2 deuteranopia, 28.4 tritanopia (a dE under about 10 is hard to tell apart; above about 25 is clear). Colour is never the only cue: each role also has its own silhouette and its own map glyph (section 6). Role colours are not allowed as button fills (the Top periwinkle is close in feel to the reference game's lavender buttons; keeping it to rings avoids that look).

### 3.6 Colour-blind-safe pairing

- Default pair `GOOD #5BD68A` / `BAD #F58080` is hard for red-green colour blindness by design: dE 97 normal but 29 protan and only 6 deutan. That is why the setting exists.
- Colour-blind pair `GOOD_CB #7FD0FF` (sky) / `BAD_CB #F2924A` (orange): dE 94 normal, 77 protan, 88 deutan, 96 tritan. Trade-off, stated honestly: both are lighter than the old pair so that text reaches 4.5:1 on every surface; the brightness ratio between them is 1.38:1 (the old pair was 1.68:1), so they separate a little less in greyscale. Arrows and signs carry that gap; total colour blindness (monochromacy) is covered only by those cues.
- **Always three cues, never colour alone:** sign (+/-), arrow glyph (up triangle, down triangle) and word. `UI.delta_color` callers must add the arrow (section 8).
- In colour-blind mode coral and `BAD_CB` look alike (dE 13 normal, 7 deutan). Rule: coral is only ever a button or bar *fill* with dark text or a versus-bar side; `BAD_CB` is only ever text or glyph with a down arrow. They never sit in the same row.
- Side colours `SIDE_BLUE`/`SIDE_RED` are used only as a tinted surface, a 4 px stripe, or a flag glyph next to the word "Blue side" or "Red side". They are not "good" and "bad". Red side text is never red text alone: use `TEXT` with a red flag glyph. This fixes `04_hub.png`.
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

- **Pages:** one vertical gradient, `#14284A` to `#0A1120` at 18 percent to `#070D1A`, drawn as one stretched texture (not a shader). Optional: a very faint lane-diagonal (white 3.5 percent, 1.5 px lines, spacing 96 px, rotated -35 degrees) tiled once. Text never sits directly on the pattern; body text lives on opaque cards.
- **Banding:** dark gradients can show visible bands on phone screens. Add a 128 px noise tile at about 1.5 percent alpha over the gradient if bands show on the first device test. Not tested.
- **Title screen only:** the full dusk: a teal glow at the top left (16 percent, 70 percent radius), a coral glow low in the centre (14 percent), and 3 faint concentric arcs (white 4 percent) behind the wordmark. Max two background layers beyond the gradient.
- **Never busy:** the background may vary the brightness behind any text by no more than about 6 percent. No photo, no particles behind lists, no animated backgrounds.
- **Wordmark:** use the working title as text (Display 64, ExtraBold) with the Horizon line underneath. Do not draw a logo until the final name clears the trademark search (`IP-RISK-LOG.md`).
- **Arena (Alpha 0.8):** the Environment and Lighting Artists build the map on the same palette: terrain from `VOID`/`PANEL` desaturated teal, lane paths in `TEXT2` at low alpha, blue side `#5AA9FF`, red side `#FF7A7A` used as team tints and flags, hero tokens use the portrait ring system, effects in teal, coral and gold. No effect may be brighter than the coral glow.

## 5. Typography

### 5.1 Font recommendation

**Barlow Semi Condensed** (Jeremy Tribby), Latin, free, **SIL Open Font Licence 1.1** (OFL). Why:
- It is slightly narrower than the default font (the screenshots show Godot's built-in default, an Open Sans look). The narrower width buys larger text in the same 672 px of room and is the main fix for wrapped tab words and wrapped club names in large-text mode.
- It has a sporty, friendly, slightly rounded-corner feel without being a "tech" display face, and clear numerals for scores, ratings and money. Whether its figures are tabular by default or by the OpenType `tnum` feature has to be checked when the files are imported (not checked here). Scores and standings need tabular numerals; if it lacks them, fall back to Barlow (not condensed) for numerals only.
- Static TTF weights (Regular, Medium, SemiBold, Bold, ExtraBold) load straight into Godot's `FontFile`; no variable-font handling is needed on Android.

Licence use: OFL lets us bundle and embed the font in the game and sell the game. We may not sell the font on its own and may not reuse its Reserved Font Name for a modified copy. Put `OFL.txt` next to the font files and the credit in the About screen. The IP & Originality Checker logs it in the licence log.

**Fallback chain** in the Theme: Barlow Semi Condensed, then Godot's built-in default font, then a system font (`SystemFont` with `sans-serif`; on Android this reaches Roboto and the Noto CJK fonts). Barlow covers Latin and Vietnamese but, as far as I know, not Cyrillic, Greek or CJK; the plan to add languages at the live release (the Founder's Malaysia and Singapore context) will need the system fallback or a second OFL family (Noto Sans, also OFL). Verify glyph coverage before localising.

If the Founder prefers a rounder, warmer look: **Nunito Sans** (OFL) or **Rubik** (OFL). Both are wider than the default, so the scale below would drop by about 10 percent.

### 5.2 Type scale (720 px design width; dp = px / 2)

| Style | px | dp | Weight | Line height | Use | `ui.gd` |
|---|---|---|---|---|---|---|
| Display | 64 | 32 | ExtraBold | 1.05 | "Victory", title wordmark, big score | `S_DISPLAY` (new) |
| Title | 48 | 24 | Bold | 1.1 | screen titles | `S_TITLE` (was 46) |
| Value | 38 | 19 | SemiBold | 1.15 | tile numbers, card hero values | `S_BIG` (same) |
| Heading | 32 | 16 | SemiBold | 1.2 | card titles, buttons | `S_HEAD` (new) |
| Body | 30 | 15 | Regular | 1.35 | paragraphs, rows | `S_BODY` (was 28) |
| Small | 26 | 13 | Medium | 1.3 | secondary lines, kv rows | `S_SMALL` (was 22) |
| Caption | 22 | 11 | SemiBold | 1.25 | chips, tab labels; the floor, nothing smaller | `S_CAPTION` (new, was 20 to 22 in places) |

The condensed face makes 30 px Barlow Semi Condensed about as wide as 26 to 27 px of the current font (my estimate, not measured), so the larger sizes should not cost line length. Larger-text mode multiplies every size by 1.15 as now; it must never wrap a tab or a chip mid-word: tabs and chips are single line and scroll sideways, or take a shorter label.

Rules: card titles are `Heading`, in `TEXT` (not teal); the teal `Caption` label above a group (letter-spacing +8 percent) names sections and nothing else is teal text except links and selected states. Numbers that the player acts on are one size up from their label. Money, ratings, scores and standings use tabular numerals. Sentence case everywhere, except the short teal Caption group label, which may be upper case with letter-spacing as on the style tile; no all-caps italic extended headings (see section 9). Minimum button height 96 px (48 dp), was 92 px.

## 6. Iconography and illustration

### 6.1 Icon style

- Grid 48 x 48 px (24 dp), live area 40 px, 4 px padding. Stroke 4 px (2 dp), round caps and round joins, outer corner radius 6 px. No fills except a single accent shape (a dot, a gem, the highlighted lane).
- Two tones: a `TEXT2` stroke and one accent fragment in `TEAL_HI` (or role colour). Sizes: 32 px inline, 48 px buttons and tab bar, 64 px tiles.
- Author as white strokes on transparent SVG and tint with `modulate`. (Godot's SVG import has no `currentColor`.) One file per icon in the Art folder, named `ic_<name>.svg`.
- Shape language: friendly geometry, soft corners, one idea per icon, no sharp "tech" notches, no skulls, bolts or flames.
- Set to draw first (about 30): tabs Home, Squad, Plan, Club, More; roles Top, Jungle, Mid, Bot Carry, Support; status fatigue, form, morale, contract, cash; actions ban, pick, lock, play, skip, speed, help (?), back, close; misc trophy, star (coach suggests), arrow up, arrow down, coin, clock, flag.
- **Role glyphs (original idea):** the map as a rounded square with a faint diagonal; each role highlights its place in the role colour: Top is the upper-left corner lane (an L), Mid is the diagonal, Bot Carry is the lower-right lane (a reversed L), Jungle is two small gems in the spaces between lanes, Support is a plus beside the lower-right lane. They double as the Chemistry map layout and the lane labels in the arena.

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
| Tokens | Update the values in 3.1 to 3.3 in place (`PANEL`, `PANEL2`, `PANEL3`, `DIM`, `BAD`, `GOOD_CB`, `BAD_CB`); add `VOID`, `BG_GLOW`, `TEXT2`, `TEXT_OFF`, `TEAL_HI/LO/DEEP`, `CORAL_HI/LO`, role colours, `SIDE_BLUE/RED`, sizes `S_DISPLAY`, `S_HEAD`, `S_CAPTION`; `R_CARD` 24, `R_BTN` 20, `GAP` 16, `BTN_H` 96 |
| `make_theme()` | Default font and fallbacks; Button/Panel styles from the new surfaces; `ScrollBar`: 4 px rounded, `DIM` at 40 percent, hidden when idle (replaces the grey `#717377`); `CheckButton`/switch: track `PANEL3` off, `ACCENT` on, white knob 28 px, a 2 px edge (fixes 1.06:1); `ProgressBar` background `VOID` with an inset top line |
| `box()` / new `surface(elev)` | `surface(1..3)` returns the cached gradient 9-slice style (4.1); `box()` stays for flat uses |
| `card(parent, ...)` | Add `elev` (1 default, 2 for hero and nested) and `rail` (a 4 px club or status stripe on the left); padding 24. Old callers passing `PANEL2` map to `elev` 2 |
| `button(..., kind)` | Kinds: `play` (coral gradient, glow, highlight; one per screen), `primary` (teal gradient, confirm and selected), `normal` = secondary (`PANEL2` gradient, edge, `TEXT`), `ghost` (was `flat`), `danger`. Add optional leading icon. Left-aligned variant for rows. Pressed look uses the `LO` values. Disabled: `PANEL` with `TEXT_OFF` |
| `chip()` / `chips()` | Full pill, 22 px SemiBold, `on` argument (1, 2) applying the lift rule (3.4), optional 22 px icon or dot |
| `bar()` / `versus_bar()` | Height 20; track `VOID` inset; fill gradient with rounded ends and a spark; optional `potential` ghost segment (current solid, potential at 25 percent alpha) and a threshold tick. Versus bar: 6 px gap, teal vs coral gradients, a centre notch |
| `tile()` | Add an icon slot (top right, 32 px), a delta line with arrow, E1 surface; `tile` stays one button |
| `kv_row()` | Label `TEXT2`/`DIM`, value `TEXT`, tabular numerals, optional arrow |
| `delta_color()` | Keep; add `UI.delta_text(x)` returning the arrow glyph and sign so colour is never the only cue |
| `section()` | Header as a row with chevron icon; title `Heading` in `TEXT`; open content on a lighter surface |
| New | `page_bg()` (gradient, optional lane diagonal); `section_title(parent, text, icon)` (teal caption plus Horizon underline); `row(portrait, title, subtitle, trailing)` left-aligned list row (replaces centred buttons); `segmented(items)` for tabs (single line, scrolls, never wraps); `portrait(hero_id, role, size)`; `avatar(name, role, size)`; `badge(club_id, name, size)`; `icon(name, size, color)`; `anim_*` tween helpers |

### 8.2 Screens

| Screen (file) | Visual upgrade | Helpers |
|---|---|---|
| Title (`screen_title.gd`) | Full dusk background (teal and coral glows, faint arcs); wordmark Display with the Horizon line; New game as the single coral go button, About as ghost; version in `DIM` | `page_bg`, `button play/ghost` |
| Club select (`screen_club_select.gd`) | Each club a card with its 72 px badge, name, rating chip and tier chip, 4 px left stripe in the club colour; "Take over" as secondary, only the first pick or hovered one gets teal; no coral | `card rail`, `badge`, `chip` |
| Hub (`screen_hub.gd`) | Remove the welcome card above Play (it moves into the W1 coach overlay), so Play sits in the top 40 percent; hero card E2 with both club badges at 96 px and the versus bar; glowing Play; tiles with icon and delta arrow; "Needs your attention" as a gold left rail card; page gradient | `card elev 2`, `badge`, `button play`, `tile`, `page_bg` |
| Tab bar (`main.gd`) | Icons at 48 px plus 22 px labels; selected is a `PANEL3` pill gliding in 180 ms with `TEAL_HI` icon and label; the bar is E2 with the shadow cast upward; attention dot on a tab: 14 px `BAD` with a 2 px page-colour ring | `icon`, `surface` |
| Roster (`screen_roster.gd`) | Lineup as five role rows: role glyph, avatar, name, rating `Value` right, fatigue and form chips; no more centred buttons; squad as compact rows; detail as an E3 sheet; stat bars with potential ghost segment; renew is teal, release is ghost | `row`, `avatar`, `bar potential`, `chip` |
| Chemistry (`screen_chemistry.gd`, `bond_pentagon.gd`) | Lane map layout (Top, Jungle, Mid, Bot, Support placed as on the map) with role portraits as nodes; link thickness plus colour from `DIM` (weak) to `ACCENT` (strong); matrix cells a teal ramp instead of brown `#6c4828`, number in `TEXT`; legend with arrows | `portrait/avatar`, tokens |
| Training (`screen_training.gd`) | Rows with avatar, focus icon chip, before and after bars with delta arrow; "Coach picks" is teal; tired and rest shown with icons and chips, never colour alone | `row`, `bar`, `chip`, `delta_text` |
| Match day (`screen_prematch.gd`) | Five lane rows: role glyph centred, your number and theirs, a split bar and an arrow (colour plus arrow, not coloured text only); club badges at the top; tired warning as a gold rail card | `row`, `versus_bar`, `badge` |
| Draft (`screen_draft.gd`) | Header: step pips (12) and a timer ring that turns gold at 5 s; hero tiles 3 per row with 96 px portrait, name `Small` SemiBold, archetype chip, "best 82" in `DIM`; ban state desaturated with slash; pick state ring and glow; "Coach suggests" a teal star chip on the best tile; role filter as `segmented`; slot panel as an E3 bottom sheet | `portrait`, `segmented`, `chip`, `surface 3` |
| Draft done (`screen_draft.gd`) | Two team columns with portraits in role order; composition chips; the opponent's composition in neutral or coral, not green; Start the match as the coral go button | `portrait`, `chip`, `button play` |
| Game plan (`screen_game_plan.gd`) | Expected edge as a large centre-zero gauge; per-contest rows with a mini bar and arrow; five-step controls as a segmented row with the zero step marked; Default, If behind, If ahead as `segmented` | `bar`, `segmented`, `delta_text` |
| Match (`screen_match.gd`) | Scoreboard header with both badges, clock in Display, momentum versus bar; feed rows with a lane glyph, timestamp in `DIM`, text, and a 4 px left rail plus arrow for who won it (180 ms rise-in); See the report is the coral go button; the empty lower half is filled by the Alpha 0.8 arena | `row`, `badge`, `versus_bar` |
| Report (`screen_report.gd`) | Result banner: "Victory" in Display with the stamp and a gold sparkle; "Defeat" in `TEXT` with a calm `BAD` glyph, not a red wall; MVP as a 96 px portrait with its percent; change rows with delta arrows; "Why it went this way" bars with gradient fill and arrows; Continue is the coral go button | `card elev 2`, `portrait`, `bar`, `delta_text`, `anim_stamp` |
| Standings (`screen_standings.gd`) | `segmented` tabs on one line (fixes "Playo/ffs"); top three on a podium with 88/72/72 px badges; table rows with a 40 px badge, own club on `PANEL2` with a teal left rail; form as a chip | `segmented`, `badge`, `row` |
| Finance (`screen_finance.gd`) | Balance hero card with the number in Display and one wage-versus-cap bar; sponsors as three cards with a coin icon, selected has a teal ring and glow; no wall of centred text | `card`, `bar`, `icon` |
| Free agents (`screen_free_agents.gd`) | Rows with avatar and role ring, rating `Value`, potential ghost bar, ask in a coin chip; filters as chips (single line, scroll) | `row`, `avatar`, `chip` |
| Negotiation (`screen_negotiation.gd`) | Keep the preview panel (before to after rows with arrows) on an E2 surface; offers left as three pips; Offer as `Value` with steppers; Accept is teal | `kv_row`, `chip`, `button primary` |
| Settings (`screen_settings.gd`) | New switches (visible on and off); group headers with icons; a preview line under each comfort option; the colour-blind option shows both swatch pairs | `make_theme`, `section_title` |
| Season end (`screen_season_end.gd`, `screen_game_over.gd`) | A code-drawn trophy in gold gradient with a one-off sweep and sparkle for a title; champion badge large; growth list as delta chips | `badge`, `chip`, `anim_*` |
| Plan, Club tab, Practice, About (`screen_plan.gd`, `screen_club.gd`, `screen_practice.gd`, `screen_about.gd`) | Tiles with icons and deltas; empty states get an icon and one line, not a void (`19e_practice.png`, `17_standings_results.png`); About keeps text on cards with `Body` 30 | `tile`, `card`, `icon` |

## 9. Do-not list and originality rules

### 9.1 Do not

- No neon cyan plus magenta "cyberpunk" glow, no glitch, scan-line or chromatic-aberration effects.
- No angular chamfered "tech frames" with notched corners; no hazard stripes; no carbon-fibre or metal textures; no hex-grid backgrounds.
- No fire, lightning-bolt, skull, claw-mark or flaming-animal mascots; no lens flares; no heavy purple-to-pink gradients; no "gold and black premium" panels.
- No all-caps italic extended headings; no more than two weights per card.
- No colour on its own to mean good or bad, side, role or club; always sign, arrow, glyph or word.
- No coral on anything but the one go action (and the "them" side of a versus bar); no more than one coral button per screen.
- No tinted chip on an overlay surface; no `DIM` text on an overlay surface; no text smaller than 22 px.
- No centred text rows in lists; no text laid directly on the background pattern.
- No more than two glowing things on screen; no animated background; no particle effect that blocks a tap.
- No pentagon of avatars for Chemistry (already decided); no club-coloured UI chrome.
- No pink Ban and green Pick button pair, no Install-style bright banners, no upsell tile or lock icon in the core loop (Founder pillar).
- No logo until the final name clears the trademark search.

### 9.2 Anything resembling ESMO or any other game

- The reference game is dark charcoal with lavender buttons and olive-gold upsell tiles. Our buttons are teal and coral on navy. Lavender or periwinkle is allowed only as the small Top role ring, never as a button or fill. Olive-gold is not used (our gold `#F2C14E` is a warm yellow, for warnings and trophies).
- Our Ban is a desaturated portrait with a slash and a `BAD` edge; our Pick is a teal ring with a lock. Do not reproduce the reference's pink Ban and green Pick bottom-sheet buttons.
- Do not copy layouts, icons, hero art, colour values, names or wording of any game. Do not trace, colour-pick from or screenshot reference material into our assets. The ads and Install pages in the recordings are third-party material and are not reference.
- Do not use the visual conventions that are another game's signature: no champion-portrait frame with a level badge in a corner, no gold-wing rank crests, no hextech or runic ornament, no map or icon set modelled on a specific game. Role glyphs and silhouettes here are our own constructions.

### 9.3 Originality rules

1. Every shipped picture is drawn by us in code or SVG, or is a third-party asset under a licence that allows bundling (OFL, CC0) and is **logged**: name, source, licence, date. The font is the first entry.
2. No image generator output in shipped art unless the Founder and the IP & Originality Checker have approved its licence terms (unknown today).
3. All club, hero and player names and all art go to the IP & Originality Checker before they leave placeholder status. Entries to add to `IP-RISK-LOG.md`: the role map glyph set; the five role silhouettes and the halo, orb, horn and crest motifs; the six badge shapes; the font and its licence; the periwinkle Top ring colour (a low risk, noted because of the reference's lavender).
4. No real club, team, brand or esports organisation logo or name; mascot animals stay generic (no famous crest shapes). Check the six badge shapes against well-known club crests before launch.
5. The Founder approves the concept direction (style tile) before the build, then before-and-after screenshots (plan W2 acceptance).

## 10. Open items, risks and decisions

- **Decision (Founder):** approve the style tile as the visual direction. Recommendation: approve. It stays inside what you already chose (Arena Dusk) and changes depth, pictures and type, not identity.
- **Decision (Founder):** the font. Recommendation: Barlow Semi Condensed (free, OFL). Alternative: Nunito Sans.
- **Decision (Creative Director):** confirm the reading of the 250 ms rule (transitions 250 ms, reveals up to 600 ms, one ambient glow). Recommendation: confirm.
- **Risk:** baked 9-slice surfaces, shadows and gradient banding have not been tried on a low-end phone. The Engine / Graphics Programmer should test on the lowest target device before the visual pass is committed.
- **Risk:** Barlow's numerals, glyph coverage and tabular figures are unchecked (not installed here). Check on import; fallbacks are set.
- **Risk:** the colour-blind pair separates less in greyscale than the old one (1.38 against 1.68:1) because it was lightened for text contrast; arrows and signs are mandatory for that reason.
- **Risk:** the club colours skew soft by design (section 6.3); the Founder may want bolder ones.
- **Risk:** large-text mode is +15 percent on every size; with the new scale, the Display and Title sizes need a cap of about 1.1 so they do not wrap. QA must re-run large-text and colour-blind screenshots on every screen above.
- Hand-offs are listed in the handback of this task.
