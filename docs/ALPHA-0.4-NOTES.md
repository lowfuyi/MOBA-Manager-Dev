# Alpha 0.4 - install and test notes

Build: `build/moba-esports-alpha.apk` (Android 5.0+, arm64, debug-signed, package `com.lowfuyi.mobaesports.alpha`, version 0.4.0 alpha, versionCode 5).
It installs over Alpha 0.1.x to 0.3 and keeps your save (an older save opens as a "new club": every pair of players starts at Bond 30, nobody is in or out of form, morale is the neutral 60).
This is a testing build. The signing key is the shared debug key, so it must never go to a store.

## What is new since 0.3
1. **Team Bonds.** Every pair on your roster has a Bond from 0 to 100. A new club starts at 30; a player you sign starts at 20 with everybody; a player who leaves takes his pairs with him (and starts again at 20 if you ever sign him back). The five starters gain Bond after every game they play together (+4, less as the pair matures; Casual players bond a little faster, Temperamental ones slower). Substitutes build nothing, so rotating players in has a real price.
2. **Team chemistry** (Club office -> Team chemistry, also from Roster). A pentagon of your five starters (thicker line = stronger Bond, greener line = better understanding), a 5x5 grid showing how well each starter takes in what each teammate says (Bond combined with the speaker's Communication stat), the languages of the starters, and the bench's bond with the starters. Chemistry (0 to 100) becomes a rating bonus for the whole team: about +0.9% for a new club, about +1.9% at Bond 60 and up to +4.2% at the very top. It is shown on the Club office card, the match-day screen, the roster and the match report.
3. **Team scrim** (Training -> tap a player -> Team scrim). A player on a scrim trains no stat that week. Every pair of players who are both on a scrim builds Bond a little (+1.5 a week, about a fifth on top of what playing together gives). It is a small extra, not a shortcut.
4. **Form** (-10 to +10): moves 2 points toward the result after every game a starter plays and fades by 10% a day. In match it is worth 0.4 rating points per point of Form. Rows in the Roster say "in form" or "out of form" when it is large.
5. **Morale** (0 to 100, neutral 60): starters swing about 6 points with each result (playoffs 1.5 times as much), the bench 1 point; Professional players swing less, Temperamental ones much more. It drifts one point a day back toward 60. A starter who sits out three or more matches in a row loses 6 more for every further match, so a benched star does sour. In match it is worth 0.06 rating points per point away from 50. Roster rows say "happy" or "unhappy".
6. Computer-run clubs have all of this too: each AI squad keeps one bond level that grows with every game it plays, and its players have form and morale. After the off-season form fades and morale returns toward 60; bonds carry over.

## What to test (the questions that matter)
1. Can you read the chemistry screen without help? Do the pentagon and the grid tell you what to do (keep the five together, or accept a cost when you swap one)?
2. Does it feel right that swapping a starter hurts for a while? Too harsh, too soft, or invisible?
3. Do "in form", "out of form", "happy" and "unhappy" make sense when you see them? Did a player's morale ever surprise you?
4. Is the Team scrim worth choosing, or never?
5. Pace: is a game still about 5 minutes or less?
6. Anything confusing, slow, ugly beyond placeholder level, or broken.

## How to report
Settings -> "Copy debug info", then paste it into the message with what you saw. Screenshots help.

## Not in yet
Transfers with other clubs, youth intake, Exhibition and Quick Match, staff (the staff part of the team bonus), the club Form Rating, prize share for players, animated map, sound, real art, Multiplayer and Global editions. Everyone speaks English at 100 in this data, so the language factor is always 1.0 here (the maths is tested with made-up multi-language squads). Hero and player names are placeholders.

## Known limits (honest list)
- Built and tested on a computer (logic checks, headless runs through whole seasons, touch-input simulation, screenshots at phone size). I cannot run it on a physical phone; your tests on the phone are what show touch feel and performance.
- Over 40 simulated league splits the new model keeps strength a good predictor of results (Spearman 0.83, same as before); the strongest three clubs win 72% of their games (71% before) and the weakest three 29% (31% before). If a few games feel decided by "mood" rather than strength, tell me which game.
- The scrim bonus is +1.5 a week, half of what the design document says, because the document's own bond-farming limit (no route more than 20% faster than playing) would be broken at +3. Computer-run squads use one bond level per club instead of 45 pairs.
- Morale and Form do not change contract talks yet.
