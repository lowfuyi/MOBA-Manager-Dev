# IP risk log

Maintained by the IP Checker. Screening only, not legal advice. A qualified IP lawyer should review before launch.

| Date | Item | Concern | Verdict | Action |
|---|---|---|---|---|
| 2026-11-07 | Placeholder names: Hollowmere (map), The Cairn (base), Stoneback and Moonhulk (objectives), Moss camps, Waves | Original placeholders replacing earlier names that sat too close to existing games (a map name, a base-core name and a final-boss name from popular titles). "Cairn" and "Hollowmere" are common English words and place names | Pending, first scan done 2026-11-08: Hollowmere Change, Moonhulk/Mossback/The Cairn Watch, the rest Clear (see Scan 1) | Run a trademark search before launch; rename Hollowmere now |
| 2026-11-07 | Term "Champions" (replaced by "Heroes") and "Mastery" (replaced by "Familiarity") | Both are used by a major game for the same concepts | Changed | Replaced throughout the docs. "Heroes" is a generic genre word. Keep checking new terms as they appear |
| 2026-11-07 | Working title "MOBA Manager" | Generic; not distinctive enough to trademark | Change (scan 1: exact-name collisions found) | See Scan 1, section F |
| 2026-11-07 | Draft order | The first version matched the competitive format of a major game. Changed to our own order (2+1 bans each, 3+2 picks in a different order) | Changed | None |
| 2026-11-07 | Slot names (Bot Carry), tag words (Poke, Engage, Waveclear, Splitpush), style names (Dive, Siege, Protect), "Blue/Red" sides, early and late neutral objectives | Genre vocabulary and structure shared with the genre leader; low risk individually | Pass, watch | Rename in the visual/polish phase if the name search or lawyer review suggests. The objective mechanic mirrors the genre's, which is allowed; names are ours |
| 2026-11-07 | ESMO naming | Not yet screened against ESMO's store listing and in-app terms | Partly done 2026-11-08: store listings found (Scan 1, section F); in-app terms still unread | Producer to supply every hero and mode name seen in the reference video so the block list can grow |
| 2026-11-07 | Working title collision | A Steam game called "MOBA GM" exists | Pending, wider than first thought: five MOBA manager titles share the generic name (Scan 1, section F) | Pick a distinctive final name |
| 2026-11-07 | Numbers and tables (slot weights, hero power budget, tags) | Must be our own | Pass | All numbers are our own placeholders, tuned with our simulator. No tables from ESMO or any other game were used or consulted |
| 2026-11-07 | Reference hero names seen in screenshots: Dredge, Gauntlet, Monolith, Oculus (and any others later) | These belong to the reference game. Our 40 heroes must not use them or close variants | Open rule | Content Lead checks every hero name against this list; IP Checker confirms |
| 2026-11-07 | Reference art: hero portraits, avatars, talent icons, UI icons | Not to be copied or traced. Our art comes in the visual phase | Rule | Visual phase must use original or licensed assets only |
| 2026-11-07 | Practice-session wording and other task names | Use our own words ("Practice Session"), keep genre-generic terms only | Rule | Naming glossary D-006 |
| 2026-11-07 | Real esports organization names and logos appear in the reference leaderboard | Trademark and publicity risk if we used any real club, team or pro-player name or logo | Rule | All clubs and players are generated and fictional; name generator checks against a block list (D-008) |
| 2026-11-07 | Competition tier words and event titles (a "Masters"-style tier, the reference event names) | Tier words tied to real circuits and the reference titles are not ours | Rule | Original format names in D-018; IP Checker reviews |
| 2026-11-07 | Rating name and help text ("ECR" and its description) | Reference wording | Rule | Ours is "Form Rating" with our own text |
| 2026-11-07 | The 40 hero names (v0), 10 club names and the player name generator (`tools/gen_heroes.py`, `tools/gen_players.py`) | Invented words and syllable mixes, so coincidence with an existing hero, org or handle is possible. Checked only against the reference hero names and a best-effort block list of well-known handles and orgs; no store, trademark or web search yet | Pending, first scan done 2026-11-08: heroes Orrick and Tuskal Change, 4 Watch, 34 Clear; clubs 1 Watch (Corsairs) and 1 Watch (Pinehollow), 8 Clear (Scan 1). Trademark search still open | Run a trademark search on every hero and club name before they leave placeholder status (`placeholder: true` in the data); player tags are generated per save and checked against the block list at generation time |

---

# Scan 1: Alpha 0.7 wave 1 specs (2026-11-08)

Scope: names, labels, font, badge shapes and role glyphs, layouts in the wave 1 documents. Verdicts: **Clear** (no action), **Watch** (low risk, keep an eye, cheap swap ready), **Change** (rename or redraw now, while it is cheap). Evidence, queries and failed searches: `company/reviews/2026-11-08-ip-scan-wave1.md`.

**What this scan cannot prove.** It is a screening step, not a trademark search and not legal advice. I searched Steam, the Apple App Store, itch.io, nine game wikis (970 hero names) and two Liquipedia wikis. I did **not** search Google Play, any trademark register (USPTO, EUIPO, WIPO, IPOS, MyIPO), Wild Rift, Heroes of the Storm, Arena of Valor or ESMO's own hero list. General web engines were blocked or returned junk. "Clear" means "I found no collision", not "free to use". A trademark search and an IP lawyer are still needed before launch, in the countries where the game will be sold.

## A. Places and objects (`ARENA-MAP.md`, `arena_map.json`)

| Name | Verdict | Reason | If Change or swap wanted (three ideas, each looked up on Steam and the App Store; no title found) |
|---|---|---|---|
| **Hollowmere** (map) | **Change** | Exact title of a Steam game and of three App Store apps, plus six or more itch.io titles. Same fantasy mood, not a MOBA. Used in 17 files but only in `arena_map.json` as data, so a rename is cheap now | Larkmere, Wrenfell, Thornmere |
| Moonhulk (late objective) | Watch | No title found. But "hulk" evokes Marvel's Hulk (a character and brand, and a hero in Marvel Rivals). It is also a plain nautical word, and the object is an island | Moonbarrow, Glimmerholm, Moonholm (holm = small island) |
| Mossback (big camp) | Watch | Exact title of one Steam game (coming soon) and one App Store app, neither a MOBA. Plain English word | Mossbrook, Fernhide, Lichenhide |
| The Cairn (base) | Watch | "Cairn" is a common word, but "Cairn" is also a 2026 Steam game (The Game Bakers) and a tabletop RPG. Different genre and a base is a base. The block list already avoids "Cairn" in club names | The Heartcairn, The Standing Stone, The Lantern Stone |
| Stoneback (early objective) | Clear | No game title, hero or objective found. Surname only | none needed |
| Reedrun, Hush Causeway, Lanternway (lanes) | Clear | No hits (one itch.io asset pack uses "Lanternway"). The screen shows Top / Mid / Bot anyway | none needed |
| The Mere, The Thicket, The Shallows, Cairn Gate, Moss, Bramble | Clear | Ordinary English landscape words; no MOBA map or objective found with them on the wikis searched | none needed |
| Arena Dusk (theme) | Clear | No hits | none needed |

## B. Hero names (`heroes.json`, 40 heroes)

All 40 were compared with 970 hero names from nine games, then searched as titles. Full table in the review file, section 2.2.

| Hero | Verdict | Reason | Replacement ideas (checked the same way) |
|---|---|---|---|
| **Orrick** | **Change** | Sounds almost the same as Yorick (League of Legends): edit distance 2, both melee frontline | Orlund, Ormsett, Ordwin |
| **Tuskal** | **Change** | Contains the whole name of Tusk (Dota 2), a hero of the same genre | Tarskel, Brokhal, Grundal |
| Skarrow | Watch | Same first four letters as Skarner (LoL), different ending | Skarvane, Skerrin, Scarrowen |
| Barrowick | Watch | Shares "-wick" with Warwick (LoL), sounds different | Barrowin, Bartholm, Burrowick |
| Quillith | Watch | Near Lillith (Paladins), a hero shooter | Quillen, Quivaris, Quillo |
| Orisande | Watch | Begins with the whole name Orisa (Overwatch), a hero shooter | Orsande, Osandre, Orvisande |
| The other 34 | Clear | Nothing close in the rosters or titles searched. "Oriel" is also an unrelated app; "Lanthorn" an unrelated puzzle app | none needed |

All replacement ideas in sections A and B were looked up on Steam and the App Store (no title found); they were not compared with the hero rosters except the Change rows. Renaming needs `tools/gen_heroes.py`, `heroes.json` (ids too), the generated `HERO-SET-v0.md` and the sample files regenerated: a Content Lead or tools task.

## C. Intent labels and commentary (`ACTION-VOCABULARY.md` 4.3, `ESPORTS-NOTES.md` section 4)

| Item | Verdict | Reason |
|---|---|---|
| 52 intents, 156 lines | Clear | Plain English describing a posture. Genre words only (gank, dive, poke, peel, skirmish, snowball, counter-jungle). Five lines equal short existing titles ("Ready for anything", "No time to waste", "Going all in", "Turning point", "Anything can happen"); generic phrases, not names, no action. I know of no caster catchphrase here, but could not search phrases on a general web engine |
| The labels that name places (`Stoneback`, `Moonhulk`, `the Cairn` in 11 lines) | Follows section A | If Moonhulk or Hollowmere is renamed, those lines change with the data. Keep place names as `{place}` fills, not typed into lines |
| 20 commentary samples | Clear | Generic and original; no real names |
| Sources list names a real game's overlay article | Clear | A citation, not use. Studio Manager already asked to keep the title out of the body |

## C2. Club names (`clubs.json`, 10 clubs; these also appear in the docs and on the style tile)

| Club | Verdict | Reason | Swap idea if wanted |
|---|---|---|---|
| Northreach Corsairs | Watch | "Corsairs" sits close to CORSAIR, a well-known gaming hardware brand and esports sponsor, in the same gaming world as our store listing. A fictional club in a game is a low risk, and I cannot check the register | Northreach Kestrels, Northreach Harriers, Northreach Selkies |
| Pinehollow Owls | Watch | "Pinehollow" differs only by a space from the Steam game "Pine Hollow" and the app "Pine Hollow Club" | Hollinpine Owls, Larchwood Owls (the word Larchwood is also an unrelated small app), Firhollow Owls (not looked up) |
| Ironquill Wolves, Duskwater Foxes, Gildmoor Raiders, Mossgate Wardens, Emberfen Hounds, Stormvale Herons, Thornwick Stags, Saltmarrow Gulls | Clear | No title equal to the full name on Steam, App Store or itch.io; no team found with the first word on Liquipedia (League of Legends, Mobile Legends); none contains a word from the 40-entry org block list. Gildmoor and Saltmarrow (League of Legends) and Thornwick (Mobile Legends) Liquipedia queries were rate limited, so those three are not checked there. "Mossgate", "Emberfen", "Ironquill", "Thornwick" appear only as itch.io asset packs and small indie titles | none needed |

## D. Font: Barlow Semi Condensed

| Field | Value |
|---|---|
| Verdict | **Clear** (licence verified from the source; the font is not bundled yet) |
| Licence | SIL Open Font License 1.1 (26 February 2007) |
| Source of the text | `https://raw.githubusercontent.com/jpt/barlow/master/OFL.txt`, retrieved 2026-11-08. Copyright line: "Copyright 2017 The Barlow Project Authors (https://github.com/jpt/barlow)". **No Reserved Font Name is declared** |
| Confirmed by | Google Fonts, "Barlow Semi Condensed - Google Fonts", `https://fonts.google.com/specimen/Barlow+Semi+Condensed/license`, retrieved 2026-11-08 (names Jeremy Tribby as project lead; licence text not shown in the fetched page). OFL official text and FAQ, `https://openfontlicense.org/open-font-license-official-text/` and `.../ofl-faq/`, both last updated 12 January 2026 |
| What it lets us do | Bundle and embed in the game and sell the game. The FAQ lists "mobile device applications" and games as allowed bundling |
| What we must do in the Android build | (1) Ship the upstream `OFL.txt` (with its copyright line) next to the font files inside the project so it travels in the exported package; (2) show the notice and licence text, or a link to it, on an About or Licences screen (the OFL text must accompany each copy; the FAQ says it may be omitted in a bundled program but strongly recommends including it); (3) ship the fonts unmodified if possible: subsetting or converting counts as a Modified Version, which must stay under the OFL; (4) never sell the font files alone; (5) never use the authors' names to promote the game. Credit to the designer is not required, but is good practice |
| What it does not require | The game's own code and art do not become open source. No Reserved Font Name rule applies to Barlow as published (the art bible's sentence about it is harmless but moot) |
| Open items | Use the `OFL.txt` that ships in the actual download. Verify glyph coverage (art bible says Latin and Vietnamese only) before adding languages. Godot's own licence notice is a separate to-do and was not checked here. Add the entry to the licence log below when the files are imported |

## E. Club badge shapes, role glyphs and silhouettes (`ART-BIBLE.md`, `style-tile.svg/.png`; PNG viewed twice)

| Item | Verdict | Reason | Fix |
|---|---|---|---|
| Six badge shapes: shield, roundel, pointed-top hexagon, diamond, swallowtail banner, arch | Clear | Plain heraldic forms with one flat letter and a band or chevron. No emblem, no animal, no known crest detail. Nothing on the tile resembles a famous club crest or rank badge | When the planned animal marks (wolf, fox, hound, heron, stag, gull, owl) are drawn, send them here: wolf and stag crests are common in real sport |
| **Role glyph set** ("the map as a rounded square with a faint diagonal, Top upper-left L, Mid the diagonal, Bot lower-right, Jungle gems, Support plus") | **Change** | The art bible calls it an "original idea", but a square lane map with the role's lane lit is the same concept as the well-known League of Legends position icons (from my knowledge, not verified in this session). The art bible's own do-not list bans "a map or icon set modelled on a specific game". It also clashes with the Hollowmere shapes (conflict C10), so redrawing fixes two problems | Redraw from the Hollowmere shapes: a small stadium oval; Top = left arc lit, Mid = centre causeway lit, Bot = right arc lit, Jungle = a pocket lit, Support = a lantern or a small round shield beside the Bot arc. Three alternatives if the Art Director prefers: (a) plain letter tiles with role colour; (b) role symbols not drawn on a map (helm, hood, orb, bow, lantern); (c) lane stripes only |
| Five role silhouettes (helmed bruiser, hooded jungler with a horn, orb mage, capped gunner, haloed supporter with a lantern) | Clear | Generic fantasy archetypes in flat navy; none matches a known character | Keep new accessories away from signature items of existing heroes |
| Role ring colours, circular portrait with ring | Clear | Common and generic. Periwinkle Top ring is near the reference's lavender buttons, already handled by "rings only" | Keep the rule |
| Hexagon "them" token and rose colour on the arena | Clear | A basic shape. Note only that the hexagon is also a badge shape; this is a readability point for the Art Director, not an IP point | none |

## F. Working title and the reference

| Item | Verdict | Reason | Fix |
|---|---|---|---|
| Working title "MOBA Manager" | **Change** (before any public use) | Exact-name games exist on Steam: "MOBA Manager" (Alagesia, 3 Nov 2026), "MOBA Manager 2026" (Trexeth, 8 Oct 2026), and "MOBA Esport Manager 25"; on the App Store "Moba Manager: Esports Coach" (4 Nov 2026) and "Ban Pick: Esports Manager Sim". The generic name cannot be protected or found | Pick a distinctive final name; do not use "MOBA", "Esports Manager" or "Manager Online" as the main words. Founder decision (see handback) |
| ESMO listing | Info | Steam "ESMO: Esports Manager Online" (Cymbale Studio, MOBA plus tactical shooter plus car soccer, coming soon; demo 19 Jul 2026); App Store "ESMO: Esports Manager Online" (2025). Name, "Esports Manager Online" and "ESMO+" must stay out of our title, keywords and store text | Add to the store-text rules: never name ESMO in keywords |

## G. Layout resemblance (`UI-PASS-2.md`, Hollowmere map), against well-known MOBAs and the ESMO-style reference

I did not see the reference recording; I rely on `UI-UX-REFERENCE-v1.md`. Ideas, flows and genre structure are free to use; what must differ is the expression: layout, icons, colour, wording.

| Item | Verdict | What is the same | What is different | Action |
|---|---|---|---|---|
| Draft board and **pick sheet** (You left, Them right, one row per role, bans under; bottom sheet with one full-width confirm) | Watch | The reference uses a bottom sheet with a full-width Ban (pink) or Pick (green) button and a 3-step stepper; most MOBA pick screens mirror two columns of five | Ours: 12-segment order strip instead of a 3-step stepper; ring timer, not amber chips; "Plays as" lane control with best lane preselected; Coach bar; Needs strip; Pick is coral | Make Ban an outlined or neutral button with a warning icon instead of a solid pink fill (the one visible match with the reference). Keep the tick (not a lock) on a filled role. No other change |
| **Hero grid** (3 columns of cards, role filter strip, circular ring portraits) | Watch | Reference has a hero grid with role filter tabs and a lock on a filled role. Every MOBA picker is a grid with a role filter | 216 px cards with ring portraits, patch arrow, number chip, Coach star; filter has a tick and codes; own silhouettes | None beyond the Ban button. Re-check when portraits are drawn (no level badge in a corner, no gold wing frames) |
| **Squad lane map** (five tokens on a small map) | Clear | A team on a field is a general sports-manager pattern | The reference shows a pentagon of avatars; ours is a lane map. Positions are placeholders; the map shapes will come from Hollowmere | Take token positions from the arena map (conflict C10). No IP action |
| **Hollowmere overall** (oval world, lake with island, three lanes, two jungle pockets, two objectives on the centre line) | Watch (low) | Three lanes, jungle, towers, two neutral objectives, bases at both ends: genre parts the Founder chose. Early objective on one side lane and a late objective in the centre echo the genre's dragon and baron pattern | No river or diagonal, a closed oval ring around a lake, a plank causeway as Mid, mirror (not rotational) symmetry, a portrait layout with bases top and bottom. I know of no popular MOBA map with a central lake and island; not proven | A person should hold a screenshot of ESMO's map next to `arena-map-preview.png` once and confirm they do not look alike (I could not). Keep the map free of a river and of two pits placed on one diagonal. The IP lawyer should see the preview |

## H. Licence log (assets we did not make)

| Date | Asset | Source and URL | Licence | Where it ships | Required text | Status |
|---|---|---|---|---|---|---|
| 2026-11-08 | Barlow Semi Condensed (Regular, Medium, SemiBold, Bold, ExtraBold), planned | `https://github.com/jpt/barlow` (OFL.txt retrieved from master, 2026-11-08); also `https://fonts.google.com/specimen/Barlow+Semi+Condensed` | SIL OFL 1.1 | Godot `res://` fonts folder, Android package | Copyright line and licence text from the shipped `OFL.txt` | Verified from source; not yet imported; log final file hashes at import |

## I. Open items and who acts

1. Founder: pick a distinctive final game name (F). Recommendation: yes, now, before any art uses the wordmark.
2. Producer: approve renaming Hollowmere, Orrick, Tuskal (cheap); decide on Moonhulk and Mossback (Watch).
3. Art Director: redraw the role glyph set from Hollowmere shapes (E); make Ban a non-pink button (G); send the animal marks here when drawn.
4. Content Lead: apply any approved hero renames through `tools/gen_heroes.py`; extend `block_list.json` with every ESMO hero name the Producer lists.
5. Founder or Producer: before launch, a trademark search (USPTO, EUIPO, WIPO, IPOS, MyIPO as relevant) for the final game name and for any names the Founder keeps, then an IP lawyer.


## Renames applied 2026-11-09 (Producer, Founder delegated)

| Old | New | Where | Note |
|---|---|---|---|
| Hollowmere (map) | Wrenfell | arena_map.json, ARENA-MAP, ART-BIBLE, UI-PASS-2, ACTION-VOCABULARY, ESPORTS-NOTES, art files | Steam and App Store search 2026-11-09: no title named Wrenfell, Larkmere or Orlund; Thornmere returned an unrelated App Store hit. Not a trademark search. |
| Orrick (hero) | Orlund | tools/gen_heroes.py DISPLAY_RENAMES, heroes.json, HERO-SET-v0.md | id `orrick` kept |
| Tuskal (hero) | Tarskel | same | id `tuskal` kept |
| MOBA Manager / MOBA Esports (title) | Gloamline | en.json app.title, project.godot, export label, README, GDD | name search as in DECISIONS.md; trademark search still open |

Scan 2 still to run: role glyphs (pass 2b), flags, rhombus, style tile, the new names above, and the 18 label lines that use the `{place}` placeholder (Scan 1 counted 11).
