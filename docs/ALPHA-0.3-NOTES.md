# Alpha 0.3 - install and test notes

Build: `build/moba-esports-alpha.apk` (Android 5.0+, arm64, debug-signed, package `com.lowfuyi.mobaesports.alpha`, version 0.3.0 alpha, versionCode 4).
It installs over Alpha 0.1.x and 0.2 and keeps your save (older saves get contracts and a balance when they are first opened; contracts are generated from each player's value, so a loaded save starts with about 8 weeks of cash).
This is a testing build. The signing key is the shared debug key, so it must never go to a store.

## What is new since 0.2
1. **Free agents** (Club office -> Free agents, also from Roster). About 40 players have no club. Filter by role, sort by rating, potential, age or price. Each row shows his rating now, what he could become ("pot") and what he asks per week.
2. **Contracts.** Every player on your roster now has a weekly wage and a number of seasons left (Roster -> tap a player). In his final season you can **renew** him; if you do not, he leaves when the next season starts and joins the free agents. You can also **release** a player (costs half of the wages still owed).
3. **Negotiation.** You make up to three offers (wage and 1 to 4 seasons). The player only says "close", "below what I am worth" or "far too low". Players differ: Professional is fair, Balanced wants a fair deal, Casual accepts a little less, Temperamental wants more and walks away after two refusals. After the talks fail you must wait a few rounds. Signing costs a fee of two weeks of wages.
4. **Finance** (Club office -> Finance). Balance, weekly sponsor income against wages, the wage cap, the sponsor, and a history of every payment. Wages and the sponsor are paid after every league round (a round is half a week). Prize money comes at the end of the league and the playoffs.
5. **Sponsor.** Before your first game of a season pick one of three offers: *Steady Partner* (safe income, no target), *Playoff Backer* (less income, a big reward for finishing high enough) and *Win Bonus Brand* (little income, a very big reward for enough league wins). The targets depend on how strong your club is, so a weak club is asked for less than a strong one. The offer shows the season total with and without the target. Missing a target costs real money.
6. **Dismissal.** If the balance stays below zero for 8 rounds in a row the board dismisses you. The game-over screen lets you load your last autosave from before it happened. The Club office warns you while you are in debt.
7. Squad limits: at most 10 players, at least 6. The wage bill cannot pass the wage cap (about a third above your starting wage bill), and a negative balance blocks signings.

## What to test (the questions that matter)
1. Is it clear what a player costs and why an offer was refused? Does "close / below / far" give enough to find the right price in three offers?
2. Is the money tight enough to make choices (renew or replace? pick the risky sponsor?) but not unfair? Did you ever feel stuck, or never care about cash at all?
3. Do free agents give you a real reason to rebuild your squad? Are the best ones too strong or too cheap?
4. Do the Season-end contract list and the release screen make sense? Did any player leave when you did not expect it?
5. Pace: is a game still about 5 minutes or less?
6. Anything confusing, slow, ugly beyond placeholder level, or broken.

## How to report
Settings -> "Copy debug info", then paste it into the message with what you saw. Screenshots help.

## Not in yet
Transfers with other clubs, youth intake, saved searches and scouting reports, prize share for players, clauses, staff and facility costs, Team Bonds, Form and Morale, manager level, animated map, sound, real art, Multiplayer and Global editions. Hero and player names are placeholders. Computer-run clubs do not sign, release or pay anybody; their squads stay as they were in the data.

## Known limits (honest list)
- Built and tested on a computer (logic checks, headless runs through whole seasons, touch-input simulation, screenshots at phone size). I cannot run it on a physical phone; your tests on the phone are what show touch feel and performance.
- Money numbers are a first guess checked by simulation over 5 to 6 seasons (see CALIBRATION-9.1 addendum). In the simulation a club that recruits and keeps the safe sponsor is never dismissed; one that recruits hard and takes the risky sponsor with a weak club often is. If cash piles up with nothing to spend it on, or you cannot afford a sensible plan, tell me which season and club.
- Free agents are the only source of new players, so the pool is small. There is still no youth intake.
