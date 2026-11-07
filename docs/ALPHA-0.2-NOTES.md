# Alpha 0.2 - install and test notes

Build: `build/moba-esports-alpha.apk` (Android 5.0+, arm64, debug-signed, package `com.lowfuyi.mobaesports.alpha`, version 0.2.0 alpha, versionCode 3).
It installs over Alpha 0.1.x and keeps your save (older saves load with neutral Game Plan, no training changes and zero fatigue).
This is a testing build. The signing key is the shared debug key, so it must never go to a store.

## What is new since 0.1.1
1. **Game Plan** (after the draft, before the match). Eight controls, five steps each: Fight style, Tempo, Mid-game objectives, Late objectives, Lane aggression, Support, Risk, Jungle focus. A control moves strength between parts of the game (it never adds free strength), except Risk and Lane aggression, which only change how swingy the game is and help the underdog. "Where you stand" shows your rating edge in each part of the game. "Coach's suggestion" fills in a sensible plan. You can set a separate plan for "if behind" or "if ahead" after the early game; the match feed tells you when it switched. The report has a new factor, "Your game plan".
2. **Training** (Club office -> Training). Each player works on one stat, practises one hero, or rests. Defaults to the coach's pick, so you can ignore it. Growth is slow and shrinks as a player nears his ceiling (the roster shows stat / ceiling and what changed this season).
3. **Fatigue.** Playing makes starters tired; above 25 fatigue costs rating (0.15 per point). The roster, match day and Training screens show who is tired, and "Rest tired starters" on match day picks the best rested lineup. AI clubs train and tire by the same rules and rotate their squads.
4. **Ageing.** At the end of a season everybody is a year older; from 29 Mechanics declines, from 31 Teamfighting and Game Sense. Fatigue resets in the off-season. The season summary lists who grew.

## What to test (the questions that matter)
1. Game Plan: do you understand what each control does from its text? Does the coach's suggestion help? Does "if behind / if ahead" feel useful?
2. Training: is it worth opening? Can you tell, season to season, that your players grew?
3. Fatigue: do you notice it in time? Is "Rest tired starters" enough, or do you want more control?
4. Pace: is a game still about 5 minutes or less with the draft and the plan?
5. Anything confusing, slow, ugly beyond placeholder level, or broken.

## How to report
Settings -> "Copy debug info", then paste it into the message with what you saw. Screenshots help.

## Not in yet
Recruitment and free agents, contracts, finances, sponsors, Team Bonds, Form and Morale, manager level, animated map, sound, real art, Multiplayer and Global editions. Hero and player names are placeholders. Coach and facility levels are fixed at 2 until staff and facilities exist.

## Known limits (honest list)
- Built and tested on a computer (logic checks, headless runs through whole seasons, touch-input simulation, screenshots at phone size). I cannot run it on a physical phone; your tests on the phone are what show touch feel and performance.
- A young player on a focused stat gains roughly 3 to 5 points in a season, veterans about 1 or less, and growth stops at each stat's ceiling. All clubs train, so the whole league slowly gets stronger; resting everybody is better inside the first season, training pays off from the second. If growth feels invisible or too fast, tell me.
- There is no youth intake yet, so a very long save drifts towards an older league; recruitment (next) fixes that.
- Playoff games of AI clubs do not tire or train them; your club's playoff games do.
