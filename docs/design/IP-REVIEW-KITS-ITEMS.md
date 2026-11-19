# IP review: hero kits and items (Match Sim v2, Phase 2)

Version 1.0, 2026-11-19. Reviewer: the Producer acting as IP & Originality Checker (MATCH-SIM-V2-DESIGN section 12). Scope: the 40 kits in `game/data/kits_v2.json` (40 titles, 40 passives, 160 abilities) and the 51 items in `game/data/items_v2.json`. **This is an originality screen, not legal clearance or a trademark search;** the trademark search for "Gloamline" stays a Founder item.

## 1. Method

1. **Name screen (tool).** `tools/ip_names.py` holds a deny list of about 600 distinctive names from well-known MOBAs and hero games (abilities, items, objectives, places, hero names), written from public knowledge (names only). Every name of ours is flagged when it equals a denied name, contains a one-word denied name as a word, shares two or more words with a denied name, or is within an edit-similarity ratio of 0.85. Flags are either renamed or cleared with a recorded reason (`REVIEWED` in the tool). `tools/test_kits_items.py` runs the screen in every fast gate, so a later rename cannot bring a clash back.
2. **Kit shapes (review).** Each kit was compared, as a whole, with the signature kits of well-known heroes of the same role: a kit is changed when its passive and three or more abilities match one hero's set in order and theme, or when one ability plus the hero's theme reads as a known hero.
3. **Item effects.** Effects come from a small generic vocabulary (burn, anti-heal, on-hit, crit amplifier, spellblade, guard shield, one-time stasis, slow on hit, armour and haste auras, execute, splash). Each name and its pairing of stats and effect were checked against the famous items.

## 2. Name screen results

First pass: 28 flags under a stricter rule (one shared ordinary word). The rule was tuned so ordinary English words ("spirit", "mark", "shell") do not count alone, and the second pass gave 10 flags. Outcome:

| Name | Flag | Verdict |
|---|---|---|
| Stampede Path (Tarskel) | shares "Stampede" (a famous charge ultimate) | renamed **Tuskline Run** |
| Undertow Slip (Veshra) | "Undertow" is a known ability | renamed **Eelslip Dash** |
| Smoke Shroud (Sootwing) | "Shroud" in a known stealth ability | renamed **Sootcloak** |
| Gust (Wyncote passive) | equals a known ability | renamed **Vane Wake** |
| Omen (Corvane passive) | a hero-shooter character name | renamed **Raven's Eye** |
| Rolling Boulder (Gravenstone) | equals a known ability | renamed **Tumbling Slab** |
| Monolith Fall (Gravenstone) | "Monolith" is on the existing block list | renamed, then replaced by **Standing Circle** (kit review) |
| Bell Sharpshooter (Tamsel title) | "Sharpshooter" is a known ultimate | renamed **Belfry Marksman** |
| First Light Barrage (Sparrowe) | "Barrage" is a known ability | renamed **Daybreak Flurry** |
| Fen Sage (Fennimore title) | "Sage" is a hero-shooter character | renamed **Fen Elder** |
| Sparkfall (Embrel passive) | close in spelling to a known ability (Starfall) | renamed **Cinderdrift** |
| Tuskline Charge | contains "Charge" | renamed **Tuskline Run** (as above) |
| Trail Boots | close to a known boots item | renamed **Roadworn Boots** |
| Lighthouse Charge, Spade Toss, Ember Toss | contain the ordinary verbs "charge" and "toss" | **cleared**: plain English verbs in our own compounds |
| Harpoon Shot, Harpoon Gunner | contain "Harpoon" (an item name elsewhere) | **cleared**: a common noun naming the hero's weapon |

Final screen: 291 names, 0 open flags, 5 cleared with reasons.

## 3. Kit-shape review

Kits changed because their shape was too close to a well-known hero's:

| Hero | Too close to | Change |
|---|---|---|
| Orlund | a famous duelist (percent-health vitals passive, lunge, parry that stuns, attack-speed buff, multi-strike) | passive is now a critical after a quiet moment; the parry became **Wading Sweep** (area slow); the attack-speed buff became **Mire Guard** (shield per nearby enemy) |
| Bastrel | a famous armoured roller (rolling charge knock-up, curl, area leap slam) | **Pincer Grip** (single-target hold) replaces the charge; the ultimate is a line rush, **Sidelong Surge**, not an area leap; Claw Snap now slows |
| Ottomere | a famous lantern warden (armour from souls, lantern that shields an ally) | passive gains health, not armour (**Salt-Cured**); the weapon is an anchor; **Kept Watch** shields only himself |
| Gravenstone | living-rock heroes with an unstoppable area charge | ultimate is **Standing Circle**, a ring of stones that stuns after a delay (no leap) |
| Sootwing | a famous blade-dancer's takedown reset | passive is **Ash Brand** (abilities brand, the next attack burns) |
| Veshra | an ultimate that jumps between enemies | **Tide Severance** is now a line rush |
| Cindrel | a famous fire mage (burn passive, line, area) | passive **Fired Clay** (shield on cast); **Kiln Door** (a dash leaving fire) replaces the plain shield |
| Maurelle | a famous sea mage's rolling-wave ultimate | ultimate **Rising Pool**, a flood zone that shields allies and slows enemies |
| Lanthorn | lantern plus pull reads as the same lantern warden | **Beckon** (pull) replaced by **Flicker** (blink) |

Checked and kept, with one shared mechanic each (genre-common, different theme and kit): Dunmarrow's tether-then-root, Hegwin's hook-and-stun, Tarskel's boar theme (a hunter wearing tusks, not a rider), Marrek's spinning ultimate, Nimbrel's delayed burst, Ellowen's silence ring, Tanglewick's line root and ally shield, Ketterick's stun after three abilities, Wyldrim's leap to an ally.

Every kit keeps its hero's tags visible (a test, `test_tags_are_visible_in_the_kit`).

## 4. Items

No finished item pairs a famous item's name with its signature effect. Two pairings carry a generic effect worth naming: the one-time stasis (**Stillwater Phial**, ability power and armour, water theme) and the critical-damage amplifier (**Gloamcutter**). Both are standard genre effects with our own names and stat lines. Renamed during review: Trail Boots became **Roadworn Boots**; "Tidewall Bulwark" became **Tidewall Rampart** (Bulwark is one of our archetype names); "Lamplighter's Codex" became **Lamplighter's Ledger** (Codex is a famous component name); "Nettle Censer" became **Nettle Brazier** (Censer appears in a famous support item).

## 5. Open

- Art for abilities and items does not exist yet (placeholder icons only); IP Scan 3 covers it when the Founder chooses an art route.
- Not a trademark search. Hero and item names have not been searched in trademark registers.
