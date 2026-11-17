# Alpha 0.7 "Guide and Look" - install and test notes

Build: `build/gloamline-0.7.0-alpha.apk` (Android 5.0+, arm64, debug-signed, package `com.lowfuyi.mobaesports.alpha`, version 0.7.0 alpha, versionCode 9).
It installs over Alpha 0.6 and over the 0.7 checkpoint build (CP2) and keeps your save. The match rules and numbers did not change: same simulator, same results for the same game (the golden check is unchanged).
This is a testing build. The signing key is the shared debug key, so it must never go to a store.

## What is new since 0.6
1. **A guided first game.** A new club is offered a practice game played together with a Coach card that points at the real buttons, from the first tap to the league table (27 steps, about 31 taps). It is a practice game: nothing in your season changes. You can skip it at any step, replay it from Settings, or come back to it after closing the app.
2. **A new look on every main screen** (dusk colours, Barlow text, about 15 percent bigger type):
   - **Home**: your club, the next game in a raised card with one Play button, things that need attention, the coming games, four tiles.
   - **Squad**: your five starters on a small map of your half of the arena; tap one to see who else could play that role and how the team rating would change; the bench as player cards; a player card with Overview, Stats and Career.
   - **Draft**: a lane board (you left, them right), a timer ring, the Coach's suggestion with one-tap Take, the hero grid, and a sheet per hero with "Plays as" (the best lane chosen for you).
   - **Game Plan**: the expected edge stays at the top while you change things; Overall, Early, Mid and Late pages; big sliders; Coach shows what it would change before you apply it; Undo.
   - **Match report**: the kill score, how the game went (early, mid, late), the biggest reason in one number (tap it for all of them), what changed for your starters, one tip.
   - **Standings**: a podium, your row marked YOU and pinned when it scrolls away, Points or Form Rating, a playoff bracket, and your history.
   - **Plan, Club and Match day** use the same tiles and cards; the lane matchups say Stronger, Even or Weaker with an arrow.
3. **"?" help on every screen**: what you see, what to do, good to know, and the words on the screen. A dot shows until you open it once. The draft timer and the match pause while it is open.
4. **A glossary** of 49 words (Settings, or from any help sheet).
5. **Eight short lessons** (about a minute each): the league table, training and rest, contracts, bonds and chemistry, the Game Plan in depth, money and the wage cap, signing a player, and what a game changed. They are offered when they become useful (Show me or Later) and are all in Settings > Lessons.
6. **Battery**: the game no longer redraws a screen that is not changing (low-processor mode). Untested on a phone; tell me if the phone runs cooler or if anything stops moving.
7. Smaller things: About shows the font licence; the old one-time tips are gone (the guide, the "?" and the lessons replace them).

## What to test (the questions that matter)
1. **The guided first game.** Start a new club and follow it. Did you always know what to tap? Which step slowed you down? How many minutes did it take?
2. **The new screens.** Is anything hard to read, cut off or too small to tap? Try Settings > Large text once.
3. **"?" and the glossary.** Open "?" on a screen you find confusing. Did it answer your question?
4. **Lessons.** When a lesson was offered, did it come at the right moment? Did Later behave as you expected?
5. **Speed and heat.** Is scrolling smooth? Does the phone get warm in a long session, compared with 0.6?
6. Anything confusing, slow, ugly or broken. A screenshot helps most.

## How to report
Settings > "Copy feedback note", paste it into the message with what you saw. Screenshots help.

## What the computer checks cover now
All pass on this build (the full check, 2026-11-17): 2,519 logic checks; 208 screen-flow checks through a whole season; 2,882 checks on the rebuilt screens (fit in normal and large text, every button at least 96 px, colour-blind cues, built once and changed in place, the guided game's 27 steps on the real screens with no "cannot find" card, all 8 lessons, help on every screen, save compatibility with 0.6 saves); 460 simulated-touch checks; 132 Python and data checks including the copy rules and the Coach rename; the balance calibration at 40,000 matches per row (0 of 18 out of band); a 6-season soak (1,176 checks); and the golden results unchanged. The screens were rendered in four variants (188 pictures, all inside the draw-call and node limits) and 72 of them were looked at twice. On the computer, no rebuilt screen redraws while you are not touching it.

## Not in yet
The live match arena (Alpha 0.8). The Chemistry screen keeps its older look (its new line styles come with a later UI pass). The hero "fly-in" in the draft, long-press previews, drag-to-swap on the Squad, the Report's reveal sequence, haptics, sound, and a real app icon. Transfers with other clubs and youth intake are later.

## Known limits (honest list)
- Built and tested on a computer (logic checks, whole seasons through the real screens, simulated touch, screenshots at phone size in normal, large-text, colour-blind and tall variants). The checkpoint build ran on the Founder's phone with no problem reported; this build has not run on a phone yet.
- In large text the Draft's hero grid and the Game Plan's control area are short and scroll.
- Home has no header, so its "?" sits in the top-right corner and can cover the edge of the game card once the page scrolls.
- Low-processor mode is a guess about battery and heat until it is measured on a phone.
