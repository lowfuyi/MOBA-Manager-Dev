# IP and originality scan 1: Alpha 0.7 wave 1 specs (search record)

Reviewer: IP & Originality Checker. Date: 2026-11-08. Task: hand-off from `company/reviews/2026-11-08-wave1.md` (section 9). Verdicts are in `docs/design/IP-RISK-LOG.md`, section "Scan 1". This file keeps the evidence: what was searched, what came back, what could not be done.

This is a screening step, not a trademark search and not legal advice. Searching a few public catalogues cannot prove a name is free. It can only show a collision that already exists.

## 1. How the searching was done (and what failed)

The `WebSearch` tool was not available to me in this session. I queried public catalogue and wiki search interfaces directly with `curl` through the session proxy. All runs on 2026-11-08.

| Source | How | Used for | Worked? |
|---|---|---|---|
| Steam store search and app details (`store.steampowered.com/api/storesearch`, `appdetails`) | JSON, US store | Game titles equal to or containing a name | Yes |
| Apple App Store (iTunes Search API, `entity=software`, US store, 25 results) | JSON | Mobile app titles | Yes |
| itch.io search page | HTML title list | Indie titles and asset packs | Yes |
| Fandom wiki APIs: League of Legends, Dota 2, Mobile Legends, Honor of Kings, Smite, Marvel Rivals, Paladins, Overwatch, Valorant | Category lists and title search | Hero rosters (970 names in total) and map or objective names | Yes (roster sizes below) |
| Liquipedia search (League of Legends and Mobile Legends wikis) | JSON, 2 s gaps | Real esports team names | Mostly (3 of 40 queries rate limited) |
| Google Fonts specimen page, upstream `jpt/barlow` OFL.txt, openfontlicense.org (licence text and FAQ) | Page fetch | Font licence | Yes |
| Bing, DuckDuckGo, Google, Brave, Wikipedia API | Page or API | General web | **No.** Bing returned unrelated results (banks, shipping), DuckDuckGo showed a bot challenge, Wikipedia and Brave returned HTTP 429 |
| Google Play | Page fetched (1.5 MB) | App titles | **Not parsed.** Google Play was not checked |

Roster sizes used for the hero check: League of Legends 173, Dota 2 127, Mobile Legends 157, Honor of Kings 117, Smite 191 (includes some non-hero page names), Marvel Rivals 58, Paladins 61, Overwatch 55, Valorant 31. **Not covered:** Wild Rift, Heroes of the Storm, Arena of Valor, Pokemon Unite, Vainglory, Deadlock, and every hero of the ESMO reference beyond the four names already on the block list.

Hero method: every one of the 40 names was compared with all 970 roster names (string similarity at 0.74 or more, edit distance 2 or less, shared first four letters with similarity 0.6 or more, or one name contained in the other). Then each name was searched on Steam and the App Store.

## 2. Findings that matter

### 2.1 Names that already exist as game titles

| Our name | Where it exists | What it is |
|---|---|---|
| **Hollowmere** | Steam "Hollowmere" (Mantle Point Studio, top-down zombie survival, release date not announced) and "Hollowmere: Seven Year Promise" (Corvantia Interactive, farming and RPG, early access 11 Mar 2027); App Store "Hollowmere: Cozy Witch Farm", "Hollowmere Manor", "Hollowmere"; itch.io at least six titles (Hollowmere Haunt, The Harvest, Angler, Old School Browser RPG, a village kit and others) | None is a MOBA. The word is a popular fantasy place name |
| **Mossback** | Steam "Mossback" (Saluki, farm on a turtle's back, coming soon); App Store "Mossback" (William Lawrence) | Not MOBAs. Our Mossback is a camp name |
| **The Cairn / Cairn** | Steam "Cairn" (The Game Bakers, climbing survival, released 29 Jan 2026, with DLC), "Cairn: Mathair's Curse", "Castle Cairn" | Not MOBAs. "Cairn" is a common English word |
| **MOBA Manager** (working title) | Steam "MOBA Manager" (Alagesia, free to play, 3 Nov 2026), "MOBA Manager 2026" (Trexeth, free to play, 8 Oct 2026), "MOBA Esport Manager 25" (Manager H, coming soon); App Store "Moba Manager: Esports Coach" (Okan Paskap, 4 Nov 2026) and "Ban Pick: Esports Manager Sim" (YT Lab, 25 Aug 2026) | **Direct same-genre collisions.** At least five MOBA manager games came out between Aug and Nov 2026 |
| Moonhulk, Stoneback, Reedrun, Hush Causeway, Lanternway, Cairn Gate, The Mere | No Steam, App Store or Fandom title hits. Lanternway: one itch.io asset pack ("Lanternway Free Rest Stop"). "The Shallows" is an itch.io title | No collision found |
| Arena Dusk (theme name) | No hits | No collision found |

### 2.2 Hero names close to existing hero names

| Our hero | Closest roster name | Similarity | Note |
|---|---|---|---|
| **Orrick** | Yorick (League of Legends) | 0.83, edit distance 2 | Sounds almost the same said aloud (YOR-ick against OR-ick). Both melee frontline types |
| **Tuskal** | Tusk (Dota 2) | 0.80, contains the whole name | Dota 2 is a MOBA. Tuskal is Tusk plus two letters |
| Skarrow | Skarner (League of Legends) | 0.71 | Same first four letters, different ending |
| Barrowick | Warwick (League of Legends) | 0.75 | Shared "-wick" ending |
| Quillith | Lillith (Paladins) | 0.80 | Shared "-llith" ending, Paladins is a hero shooter |
| Orisande | Orisa (Overwatch) | 0.77, begins with the whole name | Overwatch is a hero shooter |
| Gravenstone, Cindrel, Veshra, Marrek, Lanthorn, Bastrel, Corvane, Dovrin, Embrel, Maurelle, Oriel | Graves, Kindred, Leshrac, Marcel, Pantheon, Bastet, Corvus, Dori, Emre, Rell, Orisa | 0.60 to 0.77 | Weak: different sounds or only a short shared piece |

Steam and App Store exact-title hits for hero names: only "Oriel" (an unrelated app by Vinay Shah). "Lanthorn: Cozy Block Puzzle" and "Orrick Events" are other unrelated apps. The other 36 names returned nothing relevant.

### 2.3 Club names

Steam, App Store and itch.io: no title equal to any of the 10 full club names. First words: "Pinehollow" is near the Steam game "Pine Hollow" and the app "Pine Hollow Club"; "Mossgate", "Emberfen", "Ironquill" and "Thornwick" appear only as itch.io asset packs and small indie titles. Liquipedia (League of Legends and Mobile Legends team search) returned no team for the first words, except three queries (Gildmoor and Saltmarrow on League of Legends, Thornwick on Mobile Legends) that were rate limited and are **not checked**. `game/data/names/block_list.json` lists 40 org words and none appear in the 10 names. "Corsairs" sits close to the gaming hardware brand CORSAIR (a known esports sponsor); no search tool I had can say how that mark is registered.

### 2.4 Intent labels (156 lines) and commentary (20 lines)

Parsed section 4.3 of `ACTION-VOCABULARY.md`: 52 intents, 156 distinct lines, longest 26 characters (matches the Studio Manager's count). Each line was checked against Steam and App Store titles for an exact match. Five generic phrases equal an existing title: "Ready for anything", "No time to waste", "Going all in", "Turning point", "Anything can happen". Short generic English phrases are not protectable as a UI line, and none of these is used as a name, so no action. I know of no caster catchphrase in the 156 lines or the 20 commentary lines, but **I could not run phrase searches on a general web engine**, so that is my reading, not a search result. Genre words used (gank, dive, poke, peel, skirmish, snowball, counter-jungle, last hits) are the shared vocabulary of the genre.

### 2.5 Font

Verified from the upstream project and the licence steward:
- `https://raw.githubusercontent.com/jpt/barlow/master/OFL.txt`, retrieved 2026-11-08. First line: "Copyright 2017 The Barlow Project Authors (https://github.com/jpt/barlow)". Licence: "SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007". **No Reserved Font Name is declared** after the copyright line.
- `https://fonts.google.com/specimen/Barlow+Semi+Condensed/license`, page title "Barlow Semi Condensed - Google Fonts", retrieved 2026-11-08. Says the family is part of Barlow (Barlow, Barlow Semi Condensed, Barlow Condensed, 9 weights each in roman and italic) and that the project is led by Jeremy Tribby, San Francisco. The licence text itself did not render in the fetched page, so the licence rests on the upstream OFL.txt above.
- `https://openfontlicense.org/open-font-license-official-text/`, "SIL Open Font License Official Text", page last updated 12 January 2026. Text matches the upstream file.
- `https://openfontlicense.org/ofl-faq/`, OFL FAQ, last updated 12 January 2026. Section 1.4: a package that includes the fonts can be sold, and the examples include games and mobile device applications. Section 1.1.2: no acknowledgement is required. Section 1.10: the licence text may be omitted only when a font is embedded in a document or bundled in a program, and including the text is strongly recommended.

## 3. Look and layout checks (items 5 and 6)

Viewed: `docs/design/art/style-tile.png` (720 x 3650) in two passes, then crops of the portrait and badge sections at 100 percent; `docs/design/art/arena-map-preview.png` (720 x 1280) in two passes, second pass on a 150 percent crop of the arena.

Style tile pass 1: palette, type scale, elevations, sample card, five role portraits, ten badges as described in the art bible. Pass 2 found: the six shapes are all plain heraldic forms with one letter, no animal or emblem yet; the Jungle silhouette (hood, horn, slanted eyes) and the Support silhouette (halo, lantern) are generic archetypes; the Mossgate banner and the Thornwick hexagon carry a letter on a flat fill, so no crest detail exists to resemble anything; nothing on the tile resembles a known crest, rank badge or champion frame.

Arena preview pass 1: oval stadium shape with two plazas, left and right lane arcs, a vertical plank causeway, a lake with a round island and a crescent moon, two green pockets, an amber hexagon for Stoneback, rook-style tower icons on round plates, hexagon tokens (them) against circles (you). Pass 2 found: the world is a closed ring around a lake, so the picture does not read as the usual diagonal map; the tower plate and the stacked-stone Cairn icon are generic; names and colours are not the genre's well-known ones.

Genre comparison, documented in this session: Dota 2 map (Fandom "Map"): two diagonal halves split by a river, three lanes, Roshan at the river's western end. Smite Conquest (Fandom): two bases at opposite sides joined by three lanes, a jungle maze between with neutral camps, Fire Giant and Gold Fury camps on either side of the middle lane. From my own knowledge and **not verified in this session** (the wiki pages for these returned no text): League of Legends Summoner's Rift is a square map with a diagonal river, two neutral objective pits in the river and a role icon set that shows a square lane map with the role's lane highlighted; Mobile Legends Land of Dawn and Honor of Kings are also lane maps with a river and neutral objectives. I did not see the ESMO reference's map (the recording is not in the repository); `UI-UX-REFERENCE-v1.md` says only that the live match has a "map view", so the Hollowmere comparison against the reference rests on the Founder's description and that document.
