# Art production brief (Gloamline, Alpha 0.12)

Written 2026-11-23 by the Producer (acting as Art Director), overnight run, for the Founder's art-route decision. Nothing has been bought or commissioned. **All prices and timelines are estimates**, not quotes. They are rough market ranges from the Producer's general knowledge and were not checked with vendors. Get real quotes before deciding.

Today every picture in the game is drawn by code: role-ring portraits, generated club crests, map shapes, and token silhouettes per archetype. They are readable and original, but plain. This brief is the shopping list for real art. It is written so that any route below can use the same list, the same style guide and the same rules.

## 1. Asset list

Sizes are the delivered master size. The game scales down, and atlases are baked at build time (draw-call rule, `docs/design/PERF-BUDGET.md`). Every asset comes as a layered source file plus a PNG with transparency.

| # | Asset | Count | Master size | Where it shows | Notes |
|---|---|---|---|---|---|
| A1 | Hero portrait, bust | 40 | 512 x 512 | Draft grid, hero cards, hero page, report | Head and shoulders, readable at 96 px; neutral background (the game adds the role ring) |
| A2 | Hero in-match token sprite | 40 heroes x 4 frames (idle, move, cast, down) = 160 | 128 x 128 | Arena (tokens drawn at 40 to 48 px) | Top-down 3/4 view, strong silhouette, no fine detail; one palette swap per side is done in code |
| A3 | Hero splash (optional, later) | 40 | 1080 x 1350 | Hero page header | Only if the budget allows; not needed for Beta |
| A4 | Ability icons | 200 (40 x 5) | 128 x 128 | Hero page, build sheet, tooltips | Flat, one-colour glyph on a shaped plate; the kind (damage, cc, heal...) is a frame colour drawn by code |
| A5 | Item icons | 51 (31 finished, 14 components, 6 boots) | 128 x 128 | Build editor, Builds sheet, hero page | Same plate style as A4 |
| A6 | Map ground | 1 (two halves mirrored) | 2048 x 3640 | Arena | Painted or tiled ground of Wrenfell: plazas, lanes (Reedrun, Hush Causeway, Lanternway), the Mere and the Moonhulk isle, the Thicket and the Shallows |
| A7 | Map props | about 30 (towers x 2 sides, Cairn x 2, Cairn Gate, camps: Moss, Bramble, Mossback; Stoneback, Moonhulk; trees x 6, rocks x 6, planks, reeds, lanterns) | 256 to 512 | Arena | Separate pieces so code can place them and show damage states (towers: whole, cracked, fallen) |
| A8 | Effects (VFX) sprite sheets | 7 archetypes x 4 effects (hit, burst, shield, heal) = 28, plus 8 shared (tower shot, objective take, death, level up, ward, recall, Cairn fall, victory) = 36 | 8 to 12 frames at 128 x 128 | Arena | Additive-friendly, small; frame count kept low for phones |
| A9 | Club crests | 10 default clubs (generated crests stay for the rest) | 256 x 256 | Everywhere a club shows | Optional: the generated crests already work |
| A10 | UI set | about 40 icons (tabs, actions, stats, roles x 5, sides, ban glyph) | 96 x 96, SVG preferred | All screens | Must match the existing glyph language (see 2) |
| A11 | Key art and store art | 1 key art, 6 phone screenshots framed, 1 feature graphic (1024 x 500), app icon (1024 x 1024) | as listed | Store pages | Needed before any public release |

Totals for Beta without A3 and A9: about 40 portraits, 160 sprite frames, 251 icons, 1 map, about 30 props, 36 effect sheets, about 40 UI icons, and the store set.

## 2. Style guide: Arena Dusk (summary of `docs/design/ART-BIBLE.md`)

- **Mood:** a sports arena at nightfall. Calm, friendly, fantasy-lite; never grimdark, never cyberpunk. Heroes are folk-tale people and creatures (shepherds, frogs, lamp-lighters, whalers), not soldiers.
- **Palette:** deep navy page (`#0A1120` to `#14284A`), cards `#162842`, teal light `#3FD0B8` (you, selection, progress), coral sun `#FF8A5C` (the one "go" action, and "them" in a match, always as a hexagon). Gold `#F2C14E` for warnings and trophies. Role colours are rings and glyphs only: Top `#9797F7`, Jungle `#B7F797`, Mid `#68DCF3`, Bot `#EFD139`, Support `#F36896`.
- **Sides:** teal circle = your team, coral hexagon = the other team. Red and Blue only ever appear as a word plus a flag glyph. Art must never use red or blue to mean a side.
- **Light:** lit from above, a thin bright top edge, a soft shadow below, dusk glow behind. On the map, warm lanterns against cool water.
- **Shapes:** rounded, chunky, readable at small sizes; bold outer silhouette, 2 to 3 interior shapes, no thin lines under 2 px at token size.
- **Motifs:** the Horizon (a teal-to-coral line), the Lane Bows `( | )` (the three lanes of Wrenfell), the role map glyph.
- **Type:** Barlow Semi Condensed (OFL). No text inside art except the logo.

## 3. Silhouette notes per archetype

Each archetype must read from its outline alone, at 40 px, in one colour.

| Archetype | Heroes | Silhouette rule |
|---|---|---|
| Bruiser (8) | Brannoch, Skarrow, Hegwin, Orlund, Barrowick, Tarskel, Marrek, Wyldrim | Wide shoulders, one big weapon or tool held high; forward lean |
| Gunner (8) | Harkin, Pellam, Tamsel, Jorreck, Brixley, Dovrin, Ketterick, Sparrowe | Slim body plus a long horizontal shape (sling, harpoon, bow, bell rope); always sideways |
| Bulwark (6) | Dunmarrow, Ottomere, Vellgrim, Gravenstone, Bastrel, Corvane | Biggest mass, a flat front (shield, shell, wall, stone); planted, low |
| Shade (5) | Nimbrel, Quillith, Sootwing, Veshra, Dusken | Narrow, hooked or pointed outline, one trailing shape (cloak, wing, smoke); crouched |
| Spellcaster (5) | Ellowen, Cindrel, Maurelle, Tessarine, Embrel | Tall vertical with a raised hand or staff and one floating shape above |
| Binder (5) | Orisande, Lanthorn, Tanglewick, Wyncote, Fennimore | Round or rooted base with tendrils, chains, vines or a lantern line reaching out |
| Mender (3) | Sunnivah, Alderwyn, Oriel | Soft round shape with an open halo or leaf circle; arms open |

Within an archetype, each hero needs one unique shape cue (Fennimore: frog crouch and lily pad; Harkin: harpoon and coil; Sunnivah: sundial halo). The hero texts and kits in `game/data/heroes.json` and `kits_v2.json` are the brief for each hero.

## 4. IP rules (non-negotiable)

1. **No reference to any existing game's art.** Artists must not be given, or use, screenshots, character art or icons from other MOBAs or esports managers. That includes ESMO, Dota 2, League of Legends, Mobile Legends, Arena of Valor, Pokémon Unite and Wild Rift. Reference boards may use real-world photos, museum art in the public domain and our own code-drawn assets.
2. **Contract terms:** work made for hire, or a full assignment of copyright to the company, worldwide and all media, with moral rights waived where the law allows. The artist confirms the work is original. If AI tools are used, the artist states which tools and their terms, and confirms those terms allow commercial use and do not give the tool owner rights in the output.
3. **No AI output trained to imitate a named living artist or a named game.** Prompts must not name artists or games.
4. **Review:** every delivery goes through the IP & Originality Checker (`docs/design/IP-RISK-LOG.md`) before it enters `game/`. Similar-looking heroes in other games are checked by name and by silhouette.
5. **Fonts and textures:** only licences that allow commercial use in a game (OFL, CC0, or bought with a game licence). Keep the licence file with the asset.
6. **Trademark:** the name "Gloamline" still needs a trademark search before any store page (Founder decision owed).

## 5. Three routes (estimates only)

| | A. AI-assisted, in-house finishing | B. Freelance artists | C. Art outsourcing studio |
|---|---|---|---|
| How | Generate drafts with an image model whose terms allow commercial use; a paid human artist then repaints and cleans up each asset and makes the sprite frames; the Producer bakes atlases | 2 to 3 freelancers (character, icons, environment/VFX) through a portfolio site or a curated marketplace, with an Art Director review each week | One studio does the whole list with its own art lead, QA and pipeline |
| Rough cost for the Beta list (A1, A2, A4 to A8, A10, A11) | USD 6,000 to 20,000 (mostly the human finishing work) | USD 20,000 to 60,000 | USD 50,000 to 150,000 |
| Rough time | 6 to 10 weeks | 10 to 16 weeks | 8 to 14 weeks after contract |
| Consistency | Medium; depends on the finishing artist | Medium to high with a strong style sheet | High |
| IP risk | Highest: copyright in pure AI output is weak in many countries and model terms vary; human repaint lowers it | Low with a good contract | Lowest; studios carry contracts and QA |
| Founder effort | High (many reviews) | Medium | Low |

Ways to save, in any route: buy portraits and icons first (A1, A4, A5: they show on every screen). Keep the code-drawn map and effects longer, because they already work and are inside the phone budget. A middle path: a studio does the hero set (A1, A2), and a freelancer does the icons (A4, A5).

Producer recommendation: **route B for portraits and icons first** (A1, A4, A5: about 290 assets). It is the best quality for the money, with clear ownership. Decide on sprites and the map after testers react to the new portraits. This is the Founder's decision.

## 6. How to judge vendors

- **Portfolio fit:** at least 3 pieces in a friendly, readable, stylised look; at least 1 set of small icons that still read at 64 px.
- **Paid test:** 1 portrait (Fennimore) plus 3 item icons from this brief, paid at the normal rate, judged blind against the style guide: silhouette at 40 px, palette, originality, file hygiene (layers, names).
- **Process:** sketch, then colour, then final, with a review at each step; turnaround under a week for a test.
- **Contract:** IP terms as in section 4; a fixed price per asset or milestone; two revision rounds included; source files delivered.
- **References:** one past client contacted. A clear answer on AI-tool use.
- **Red flags:** reluctance to assign copyright, work that looks like a famous game, no layered files, a price far below the others.

## 7. Ready-to-send commission brief (copy, fill in the brackets)

> **Commission: hero portraits and icons for a mobile esports manager game (Gloamline)**
>
> We are a small studio making an original esports manager game for phones. We are looking for [hero portraits / item and ability icons] in a friendly, stylised fantasy-lite look, a sports arena at nightfall.
>
> **Scope, first batch:** [8] hero bust portraits (512 x 512, transparent PNG plus layered source) and [20] item icons (128 x 128). The full set is 40 portraits and 251 icons, offered to the artist who does the first batch well.
>
> **Style:** deep navy and teal with one warm coral accent. Soft top light, bold readable silhouettes that work at 64 to 96 px, no text in the art. Heroes are folk-tale characters, for example an old frog sage, a harpoon whaler or a shepherd with a sling. We send a style sheet, our palette, and a short text for each hero.
>
> **Originality:** the art must be original. Please do not use or copy art from other games. We review every piece for similarity. If you use AI tools at any stage, tell us which ones.
>
> **Rights:** full copyright assignment to the company (or work for hire), all media, worldwide, with source files.
>
> **Test:** a paid test of 1 portrait and 3 icons at your normal rate before the main order.
>
> **Please send:** portfolio link, price per portrait and per icon, turnaround for the test and for the batch, and how many revision rounds are included.
>
> Contact: [Founder's business email]. Budget range: [to be set by the Founder].

## 8. Decisions owed (Founder)

1. The route: A, B, C, or a mix.
2. The budget ceiling for the Beta art set.
3. The business email and company name to use on contracts.
4. The trademark search for "Gloamline", before any store art (A11) is made.
