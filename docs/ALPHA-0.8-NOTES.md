# Alpha 0.8 "Arena" - install and test notes

## Update 0.8.1 (2026-11-18): Fight pass
Build: `build/gloamline-0.8.1-alpha.apk` (25.3 MB, sha256 2acbc82d..., versionCode 12, same debug key; installs over 0.8.0 and 0.8.0b and keeps your save).
Your four decisions were applied as recommended: a short slow-down on the deciding kill, crowded kills grouped as double and
triple kills, Speed x2 kept, and the role letters kept on the tokens (hero silhouettes come in 0.8.2).
- **Fights now look like fights.** Each group fight has an engage (one hero charges in), a trade (both sides hit, health bars
  fall), kills spaced out across the fight (or a quick double or triple kill, with a tag), then the losers run back and, after
  the Mossback fight, the winners chase.
- **Heroes act by type:** melee heroes dash in and recoil, gunners fire bolts, spellcasters wind up and burst, binders tether,
  menders send a green plus that lifts an ally's bar.
- **Health bars** above each token while it is hurt. A bar reaches zero only on a real kill; it refills on respawn and slowly
  outside fights.
- **No filling ring in teamfights.** At Stoneback and Moonhulk the fight comes first; the ring shows only afterwards, for about
  1.5 seconds, while the winners take it.
- **The deciding kill** gets a small shake, a quick zoom and a brief slow-down (made up straight after, so the game still lasts
  75 seconds), plus the tag "The deciding kill". With Settings > Animations off: no shake, zoom or slow-down; the flash and tag
  stay.
- Nothing about results changed: same simulator, same kills, towers and objectives as the Report (checked on hundreds of games).
- **Not measured: nothing has run on a phone.** Frame time, heat and battery with the extra effects are unknown. The busiest
  fight frame is 44 draw calls on the computer (0.8 was 40; the budget is 60).

What to test: do fights read as fights now? Can you tell who is winning a fight before the kill? Is the slow-down on the
deciding kill nice or annoying? Does x2 still feel too quick?

## Update 0.8.0b (2026-11-18): Frame rate setting
Build: `build/gloamline-0.8.0b-alpha.apk` (25.3 MB, sha256 f9853e17..., versionCode 11, same debug key; installs over 0.8.0 and keeps your save).
- **Settings > Frame rate**: "30 (saves battery)" or "60 (smoother)". 60 is the default. It is kept on the phone, not in your save.
- Matches play the same at both: the same results, kills and towers, and a game still takes 75 seconds (37.5 at x2). At 30 it only moves less smoothly. The computer checks compare both rates on 40 games.
- **Please try both** and tell us: does 30 look too choppy on the map? Does the phone run cooler or the battery last longer at 30? **Heat and battery at 30 vs 60 are not measured**: nothing has run on a phone except your own test.
- Nothing else changed from 0.8.0. The Fight pass (Alpha 0.8.1) is next.


Build: `build/gloamline-0.8.0-alpha.apk` (25.3 MB, sha256 11c508d8..., Android 5.0+, arm64, debug-signed with the same key as 0.7, package `com.lowfuyi.mobaesports.alpha`, version 0.8.0 alpha, versionCode 10).
It installs over Alpha 0.7 and 0.6 and keeps your save. The match rules and numbers did not change: same simulator, same results for the same game (the golden check is unchanged). The arena only shows a result that was decided before the first frame.
This is a testing build. The signing key is the shared debug key, so it must never go to a store.

## What is new since 0.7
1. **A live arena instead of the text feed.** Your game plays out on a map for about 75 seconds:
   - **Your team is the circles at the bottom, theirs the hexagons at the top** (whichever side you play). The letter on each token is the role: T, J, M, B, S.
   - The lanes duel first, the junglers fight over the camps, then both teams walk to the objectives (Stoneback, then Moonhulk), fight in the middle of the map, push towers, and the game ends at the loser's base (the Cairn).
   - Every kill, tower and objective on the map is the real one: the kill score and the towers at the end are exactly the Report's.
   - Small flashes mark hits; a skull marks a kill; a ring in the winner's shape marks who won each part of the game; the camera moves in a little on the big moments (off when Settings > Animations is off).
2. **A scoreboard at the top:** the clock, the kills and towers of each side, who is ahead in gold (with that side's shape), the phase (Early, Mid, Late) and a lead graph with the two objectives.
3. **What each side is trying**, in short labels under the map (for example "Going for Stoneback", "Poking from range"), your plan at the top of that strip (tap it to see it in full), a banner when a plan switches, and the result of each part of the game as it is decided.
4. **The end card** says who won, the kill score, and what decided the game ("Decided by: ..."), the same reason the Report leads with. Then See the report.
5. **For testers: Settings > "Testers: last fight at the gate".** In about one game in five the winner loses the very last fight and still wins (it was further ahead than that fight took back). The arena can show that ending in two ways: on the island (default) or at the gate. Please try both and tell us which felt fairer.
6. Speed x2, Skip to the end, the "?" and Quick mode work as before; Back during the match skips to the end. Any sheet you open pauses the match.

## What to test (the questions that matter)
1. **Did the arena make the match more exciting to watch?** Would you watch it rather than skip it?
2. **Could you follow it?** Did you always know which team was yours, who was winning, and why the game ended the way it did?
3. **Did the result feel fair and believable**, especially when the winner lost the last fight? (1 to 5, and which ending: island or gate.)
4. **Speed and heat**: does the arena run smoothly on your phone? Does the phone get warm during a match?
5. Anything confusing, slow, ugly or broken. A screenshot helps most.

## How to report
Settings > "Copy feedback note", paste it into the message with what you saw. Screenshots help.

## What the computer checks cover now
All pass on this build (the full check, 2026-11-18, exit 0): 2,571 logic checks (among them the arena's own: the show script's nine invariants on 400 games, the walks on 120 games and all three endings, the effects on 60 games in both seats, the words and the text budget on 600 shows); 208 screen-flow checks through a whole season; every rebuilt-screen check, including the new Match screen (34: layout in normal, large and tall, Speed, Skip, Back, pause, the tester switch, and that watching changes neither the result nor the save); the guided first game with no "cannot find" card; simulated touch; save compatibility with 0.6 saves; the copy rules; the balance calibration at 40,000 matches per row (0 out of band); a 6-season soak (1,176 checks); and the golden results unchanged (same simulator). On the computer the busiest arena frame is 40 draw calls (the budget is 60) and no rebuilt screen redraws while idle. The arena was pictured in four variants (normal, large text, colour-blind, tall) and every picture looked at twice.

## Not in yet
Commentary lines (the label slots exist; the writers have not written them), sound, haptics, hero art on the tokens (tokens show a role letter), tapping heroes on the map, and the hero "fly-in" of the draft. The kill rate is the Report's (busy in some games: up to about 40 kills); a calmer kill rate waits for tester scores.

## Known limits (honest list)
- Built and tested on a computer (logic checks on hundreds of simulated games, the real screens, simulated touch, pictures at phone size in normal, large-text, colour-blind and tall variants). **The arena has never run on a phone**: frame time with ten moving tokens and effects, heat and battery are not measured.
- The "If behind" plan in the plan sheet shows only its one-line description, not its sliders.
- The arena is not interactive in 0.8 (by design: watching never changes the result).
