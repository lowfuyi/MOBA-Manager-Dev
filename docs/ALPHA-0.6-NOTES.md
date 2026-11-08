# Alpha 0.6 - install and test notes (Phase 1 features complete, comfort options)

Build: `build/moba-esports-alpha.apk` (Android 5.0+, arm64, debug-signed, package `com.lowfuyi.mobaesports.alpha`, version 0.6.0 alpha, versionCode 7).
It installs over Alpha 0.1.x to 0.5 and keeps your save. Old saves get a starting Form Rating for every club, and your players' career records start from your next game. The match rules and numbers did not change: same simulator, same results for the same game.
This is a testing build. The signing key is the shared debug key, so it must never go to a store.

## What is new since 0.5
1. **Practice matches** (Plan tab). *Quick Match*: one game against a club close to your strength. *Exhibition*: pick any club in the league and play best of 1, 3 or 5. Practice never changes the table, your Form Rating, Form, Morale, sponsor goals or the career record. Each practice game tires your starters a little (+5 fatigue) and bonds them (+2). A practice series uses up the match day's training and rest, so you can play one series a day. Use it to try a draft or a Game Plan without risk.
2. **Form Rating** for every club (Standings -> Form, a Form column in the table, and a tile on the Club tab). It is an Elo-style score: beating strong clubs in big games lifts it most, and it follows how strong a club really is. It is a guide for you; it never changes a game.
3. **Trophy cabinet** (Standings -> Trophies): every finished season with your rank, record, playoff result and prize money, and totals for titles, finals and money.
4. **Career with us** on every player card: games, wins, kills, deaths and assists, the KDA ratio, best game, this season, and a short log (signed, renewed, released, birthdays, titles, big games).
5. **Player lines** in every game report: kills, deaths and assists for your five starters. These are display figures drawn from the game's result; they never change an outcome.
6. **Stat help.** Tap any stat on a player card to read what it does. The number after the slash is the stat's Potential.
7. **Comfort options** (Settings -> Comfort): larger text and buttons (about 15 percent bigger), colour-blind friendly colours (blue and orange instead of green and red), and "Show the welcome tips again".
8. **Welcome tips**: three small cards (Home, before a game, after a game), each gone for good after one tap on "Got it".
9. **Privacy and feedback** (Settings): a line saying the game keeps everything on your phone, and a "Copy feedback note" button that copies a short form plus the debug lines (version, season, pace, start-up time, memory, text size).
10. Small fixes: the Standings tabs wrap instead of running off the screen, long button captions wrap instead of widening a page, "-0%" no longer shows in the report.

## What to test (the questions that matter)
1. **Practice.** Does Quick Match make sense without explanation? Do you use Exhibition to try drafts and plans? Is "one series per match day" clear, or annoying?
2. **Form Rating.** Do you understand it after reading the one-line note on the Form tab? Do you look at it, or only at the table? Is the number (about 1300 to 1700) meaningful to you?
3. **Player lines and career.** Do the kills, deaths and assists feel believable? Does "Career with us" make you care about a player more, or is it noise?
4. **Stat help.** Is one line enough? Which stat did you not understand?
5. **Comfort.** Turn on larger text: does every screen still fit? If you can, check the colour-blind colours with someone who is colour-blind. Are the tips useful or in the way?
6. **Feedback.** Tap "Copy feedback note", paste it into a message: does it work, and is it easy?
7. **Match length** (still open from 0.5): after a week of games, Settings -> Pace log. Does 75 seconds of watching feel right?
8. Anything confusing, slow, ugly beyond placeholder level, or broken.

## How to report
Settings -> "Copy feedback note" (or "Copy debug info"), paste it into the message with what you saw. Screenshots help.

## What the computer checks cover now
All pass on this build: 1,794 logic checks (new: Form Rating maths and zero-sum, KDA consistency, career record, practice rules, old-save opening), 220 screen-flow checks (a whole season through the real screens, a practice series, a Quick Match, every new screen, large text fitting every screen), 50 touch checks (swipe, tap, Android back), 48 Python and data checks, the balance calibration at 40,000 matches per row (0 of 18 out of band), and a short soak. Separately, a long soak of 125 full seasons with random manager behaviour (25,654 invariant checks) found no error, and the calibration was repeated at the lower rating scale of about 45 (0 of 18 out of band).

## Not in yet
Lane-based Team chemistry layout, a story-first match view, a redesigned draft screen, sound and haptics, real art and icons (UI backlog in `docs/design/UI-UX-REFERENCE-v1.md`). Transfers with other clubs, youth intake, staff, medals in the trophy cabinet, a guided step-by-step first game, Multiplayer and Global editions are later.

## Known limits (honest list)
- Built and tested on a computer (logic checks, headless runs through whole seasons, touch-input simulation, screenshots at phone size 720x1280, a 125-season soak). I cannot run it on a physical phone; your tests show touch feel, readability in daylight, speed and battery.
- The 75-second watch window is still my best answer, not a measured fact; the pace log decides.
- The colour-blind colours follow a common safe pair (blue and vermillion) but have not been tried by a colour-blind person.
- Stat help is one line per stat, not the two-line sheets the design document describes.
- Practice always uses the short draft.
- Two things the economy run showed: the two strongest clubs win most titles when nobody manages them, and rich clubs pile up cash they cannot spend. Both are for you to judge in play (can you take a mid-table club to a title in ten seasons?).
- Text is English only; all visible text goes through the string table, ready for translation.
