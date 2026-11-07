# Alpha 0.1 - install and test notes

Build: `build/moba-esports-alpha.apk` (Android 5.0+, arm64, debug-signed, package `com.lowfuyi.mobaesports.alpha`, version 0.1.0 alpha).
This is a testing build. The signing key is the shared debug key, so it must never go to a store.

## Install
1. Copy the APK to the phone (or open the download link on it).
2. Open the file. Android asks to allow installs from this source (Chrome, Files, ...): allow it once.
3. Install, open "MOBA Esports Alpha".

## What is in
Pick a club (10 fictional clubs) -> set the lineup -> draft against the clock (10 s per action, short draft: 1 ban + 5 picks each; playoff game 1 uses the full 3-ban draft with 15 s) -> live text feed with game clock (Skip and x2 available) -> report (why it went this way, key moments, draft recap) -> 18-round double round robin -> top 4 playoffs (semi-finals best of 3, final best of 5) -> next season. The game saves automatically after every game.

## What to test (the questions that matter)
1. Pace: from tapping Play to the report, how long does one game take? Target is about 5 minutes or less (expected 3 to 4).
2. Draft: is the 10 second timer fair? Do you understand what the numbers (familiarity, fit, green = strong this patch) mean? Does it feel like your choices matter?
3. Report: does "why it went this way" make sense and feel honest? Are the bars believable?
4. Season: after 18 rounds, is it worth playing another season?
5. Anything confusing, slow, ugly beyond placeholder level, or broken.

## How to report
Settings -> "Copy debug info", then paste it into the message with what you saw. Screenshots help.

## Not in yet
Training, recruitment and free agents, finances, sponsors, Team Bonds, Game Plan, manager level, animated map, sound, real art, Multiplayer and Global editions. Hero and player names are placeholders.

## Known limits (honest list)
- Built and tested on a computer (1,514 logic checks, a headless run through a whole season, and screenshots at phone size). It has never run on a physical phone yet, so touch feel, text size and performance are exactly what this test finds out.
- The managed club has no AI manager other than "Take advisor's choice" in the draft.
- Quick mode (Settings) skips the live feed and speeds up the draft.
- "Luck of the game" in the report is the share of the result that came from randomness with equal teams. It is often large because games are deliberately uncertain; tell me if it feels wrong.
