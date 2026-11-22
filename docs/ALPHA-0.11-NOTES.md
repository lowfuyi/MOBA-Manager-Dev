# Gloamline Alpha 0.11.0: visible bans, more bans, three match views

Version 0.11.0 alpha (versionCode 17), 2026-11-22. Built from the Founder's feedback of 2026-11-22 on 0.10.0 (GDD 19, `company/DECISIONS.md`). The arena look of 0.10 is kept. **Nothing in this build has run on a physical phone.** Only the Founder's phone test measures touch feel, frame time and how long a draft takes a person.

## What changed

- **Bans are obvious.** Ban steps say "Ban phase", with a violet header and violet segments on the progress strip. The progress strip is grouped by phase, with bans thin and violet and picks in each side's colour. The no-entry glyph and the word "Ban" always go with the colour, which is never teal or coral. The button reads "Ban" in violet or "Pick". The Coach bar says "Coach suggests banning: X". Each team has a "Bans" row on the lane board that fills with struck-through portraits. Banned heroes are greyed and struck through in the grid, and the opponent's moves appear as a line ("Ironquill Wolves ban X").
- **More bans.** Standard (the default) uses 5 bans a side in league games and in every playoff game (semi-final Bo3, final Bo5), and 3 in Quick Match and Exhibition. Classic, in Settings under "Draft bans", brings back the old 1, or 3 in game 1 of a playoff series. The 5-ban order is in GDD 19. Tutorial and lesson games are unchanged.
- **Three match views**, in a row above Speed: **Field** (the whole map with your team's fog of war), **Action** (the default: the camera chases fights, objectives, towers and kills, with fog; drag to look around, and after 5 s it goes back to the action) and **All** (the whole map, no fog). The choice is remembered. The minimap shows the fog and the camera frame.
- The help sheets, the tutorial and the lesson texts say "Pick" instead of "Take" and explain the views.

## Still placeholder

- All arena art (units, towers, ground) is drawn in code in the Arena Dusk style, waiting for the art route.
- Wards are placed where the warder stands; the log does not record a ward's exact spot.
- "Decisive play" is worked out for the camera (a fight with 3 or more kills, or a Cairn falling), because the game log has no such flag yet.
- Games between two AI clubs still use the old contest model.

## Decisions for the Founder (from the ban experiment, `docs/design/BAN-EXPERIMENT.md`)

- With real AI drafts, teams 10, 20 and 30 rating points stronger win 1 to 2 points less often than the GDD 9 bands. This happens in Classic too, so bans are not the cause. Proposal: about 5% more weight on rating. Not applied.
- 13 to 15 of the 40 heroes win outside 45 to 55% at equal teams with real drafts, also in Classic. Proposal: a hero balance pass from real-draft data. Not applied.

## What to test on the phone

1. A league draft (5 bans each). Can you tell at a glance whether it is your ban or your pick? Do the ban rows and the struck-through heroes read clearly? How long did the whole draft take you? (The worst case if every timer runs out is about 2 min 40 s.)
2. Settings, "Draft bans": switch to Classic and back. The next league game should show 1 ban, then 5 again.
3. Quick Match and Exhibition: 3 bans each.
4. In a match, switch Field, Action and All. Does the fog make sense? Can you read the units in Field and All? In Action, drag the map, let go, and check that it goes back to the action after about 5 s.
5. Leave the match on Field, start another match, and check that it opens in Field.
6. Frame rate during a big fight in each view. The fog is new GPU work on the ground.
7. Colour-blind mode (Settings): the ban look and the match views.
