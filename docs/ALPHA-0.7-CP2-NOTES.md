# Alpha 0.7 checkpoint 2 (CP2): phone test notes

Build: `build/gloamline-0.7.0-cp2.apk` (Android 5.0+, arm64, debug-signed, package `com.lowfuyi.mobaesports.alpha`, version 0.7.0-cp2, versionCode 8). Built 2026-11-17. **Nothing in this build has run on a phone before; this is the first test.**

## Install
Copy the APK to the phone and open it (allow "install unknown apps" for your file manager). It should install over Alpha 0.6 and keep your save. If Android says the app "conflicts with an existing package", uninstall Alpha 0.6 first (that loses the 0.6 save).

## What is new since 0.6
- **Home**: club header with your last five results, the next game as a raised card with one Play button, cards for things that need attention, the coming games, four tiles.
- **Draft**: a lane board (you left, them right), a timer ring, a step bar, a role filter, the Coach's suggestion with one-tap Take, the hero grid; tap a hero for its sheet ("Plays as" with the best lane chosen, then Pick or Ban). Auto-finish needs a second tap.
- **Game Plan**: the expected edge stays at the top while you change things; Overall, Early, Mid, Late pages; big sliders you can tap or drag; Coach shows what it would change before you apply it; Undo after Apply and Reset; "If behind" and "If ahead" plans live under the Plan chip and say which controls do nothing in them.
- **Match report**: the result with the kill score, "How the game went" (early, mid, late), the one biggest reason in a big number (tap it for all the reasons), what changed for your starters, one tip, Continue always at the bottom.
- **Guided first game**: on a new club the guide offers to play a practice game with you. It changes nothing in your season.

## The guide at this checkpoint
It works from the welcome card to the league table. **Three steps show a plain card with a Next button instead of a highlight**: step 5 (tap a bench player) and step 6 (the player card) in the Squad part, and step 26 (the switch on the standings). Squad and Standings are rebuilt after this build. Tap Next on them.

## What I would like you to judge
1. Does scrolling feel smooth on Home, the Draft hero grid and the Report? Any stutter?
2. Is all text readable, and does anything look cut off? (Try Settings > Large text once.)
3. Are the buttons easy to hit? Do the Game Plan sliders drag well with a thumb?
4. Does the phone get warm in a long session?
5. How long does the guided first game take you (minutes)?
6. Anything confusing, ugly or slow: a screenshot helps most.

## Known gaps (on purpose, later increments)
Squad and Standings still use the old look (I-19, I-20). No hero "fly-in" animation in the draft, no long-press preview, no swipe between Game Plan pages, no tap-to-skip reveal on the report. The app icon is the default Godot icon.
