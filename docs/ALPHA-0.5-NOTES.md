# Alpha 0.5 - install and test notes (UI pass 1)

Build: `build/moba-esports-alpha.apk` (Android 5.0+, arm64, debug-signed, package `com.lowfuyi.mobaesports.alpha`, version 0.5.0 alpha, versionCode 6).
It installs over Alpha 0.1.x to 0.4 and keeps your save. Nothing about the game rules changed in this build: same simulator, same numbers. What changed is how the game looks, where things are and how it talks to you.
This is a testing build. The signing key is the shared debug key, so it must never go to a store.

## What is new since 0.4
1. **A new look: "Arena Dusk".** Deep navy and teal, light text, and one warm coral button per screen: the one you most likely want to press. Green and red are used only for gains and losses, amber for a warning. Cards have thin outlines, text is larger, and every tap target is at least 64 px high.
2. **A bottom tab bar** with Home, Squad, Plan, Club and More. Nothing is deeper than two taps from a tab. Plan holds Training, Team chemistry and the Game Plan summary; Club holds Finance, Standings and Free agents; More holds Settings and About. On match day (pre-match, draft, Game Plan, match, report) the bar is hidden so a game is one focused flow. The phone's back button always goes one step up: from a page to its tab, from a tab to Home, from Home to the title.
3. **A new Home page.** One big card for the next game: the opponent, a You-versus-Them strength bar, small tags (side, draft length, chemistry bonus), a coral Play button and an Auto-play button. Below it, "Needs your attention" (tired players, contracts ending, unhappy starters), then four tiles (Standing, Cash, Chemistry, Squad mood) that open their pages.
4. **A new "What this game changed" screen after every game.** Victory or Defeat, the standout player (only when someone really decided the game), a table of Form and Morale changes for the five starters, the team bond average, the chemistry bonus and the cash from the game, and one tip for the next game. "Why the game went this way", the key moments and the draft recap are collapsed sections one tap below.
5. **Previews before you commit.** Training focus changes apply at once and show an Undo message. The Game Plan screen shows the expected edge, with the plan as it is now against a balanced plan, and updates on every tap. A signing or renewal shows "If you sign him": wages, cap, cash after the fee, squad size and whether he would start.
6. **A fixed watch time.** Every game's live feed now takes about 75 seconds at normal speed, whatever the game length shown on the clock (9 to 16 game minutes). 2x and Skip are still there. See the question below.
7. **A pace log** in Settings: how many games were timed, the average and longest real time from tapping Play to the report, how long you watched the feed, how often you skipped or sped it up, and how many games you auto-played. It stays on the phone. Please paste it with your feedback.
8. **An Animations switch** in Settings (short press and number count-up animations). Off gives a still screen.
9. Small fixes found in the screenshot check: the Team chemistry page no longer runs past the right edge of the phone, and the new rows no longer wrap numbers one character per line.

## What to test (the questions that matter)
1. **Match length (your question).** Play a week of games and then open Settings -> Pace log. Does about 75 seconds of watching feel right, too long, or too short? Do you skip the feed most of the time? If you skip most games, the next step is a shorter window, not a longer one.
2. **Navigation.** Without help, can you find Training, Finance, Free agents and Standings? Does the tab bar feel natural, or do you reach for a back arrow? Does the hidden bar on match day confuse you?
3. **Home page.** Do you know what to do next in the first two seconds? Is the coral Play button obviously the one to press? Is "Needs your attention" useful or noise?
4. **The result screen.** Does the Form and Morale table tell you something you did not know? Does the tip feel helpful? Would you read it every game, or tap Continue?
5. **Previews.** Does the Undo message feel safe? Does the "If you sign him" box change what you decide?
6. **Look and readability.** Is the text big enough in daylight? Is any screen too busy, too empty, or hard to read? Any colour you cannot tell apart?
7. Anything confusing, slow, ugly beyond placeholder level, or broken.

## How to report
Settings -> "Copy debug info" (it now includes the pace line), then paste it into the message with what you saw. Screenshots help.

## Not in yet (UI backlog, kept in `docs/design/UI-UX-REFERENCE-v1.md`)
Lane-based Team chemistry layout, a story-first match view (the feed as a story with a lane map), a redesigned draft screen, dismissible hints, text size and colour-blind options, sound and haptics, real art and icons. Transfers with other clubs, youth intake, Exhibition and Quick Match, staff, the club Form Rating, Multiplayer and Global editions are still later.

## Known limits (honest list)
- Built and tested on a computer (logic checks, headless runs through whole seasons, touch-input simulation, screenshots at phone size 720x1280). I cannot run it on a physical phone; your tests are what show touch feel, readability in real light and performance.
- The 75-second window is my best answer to your question, not a measured fact. It comes from the existing game lengths (68 to 120 seconds at 1x before this build) and from how long a feed with eight events can hold attention with nothing to do. The pace log exists so your play decides.
- Animations are deliberately small (a short press pulse, number count-up, fade of the result card). There is no sound yet.
- Text is English only; all visible text goes through the string table, ready for translation.
