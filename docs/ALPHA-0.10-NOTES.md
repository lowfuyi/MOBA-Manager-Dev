# Gloamline Alpha 0.10.0: Match Sim v2

Version 0.10.0 alpha (versionCode 16), 2026-11-20. Built from the Founder decisions of 2026-11-19 (GDD 18, `company/DECISIONS.md`). **Nothing in this build has run on a physical phone.**

## What changed

- **Heroes have kits.** Each of the 40 heroes has a passive and four abilities (three basic, one ultimate), all original and IP-screened (`docs/design/IP-REVIEW-KITS-ITEMS.md`). Plan tab, Heroes: every hero's page with the kit, the Coach's build and your players' builds.
- **Items and builds.** 51 items (components, boots, finished items with one effect each). The Coach suggests a build per hero against the enemy draft; you can edit any player's build on a hero page or from the draft's Builds button. Builds play from the next game.
- **Match Sim v2.** Your club's games are played by ten role-driven players on the map: laning and trades, jungle clears and ganks, mid roams, support warding, team calls for Stoneback and Moonhulk that each player answers more often with good communication and Bonds, fights resolved with kits and items, towers and the Cairn. The draft, Game Plan, Bonds, Form, Morale, Fatigue and familiarity all still act. Calibrated to the GDD win-rate bands (`docs/design/MATCH-SIM-V2-CALIBRATION.md`).
- **Arena v2.** The Match screen plays the game as it happened: a tilted camera over an original island (the "Wrenfell Rise" layout: a lake with Moonhulk's isle at the centre, streams to the east and west), upright units with team rings and health bars, a follow camera and a corner minimap, a scoreboard, a feed and what your team is doing ("Gank", "Roam", "Backs off").
- **Show length** is one tunable value (`show_seconds`, now 180 real seconds for a median game); quiet stretches play faster; Speed x1, x2, x4 and Skip.
- **The report** tells what each of your players did (lane lead at 8:00, ganks, objectives, damage share, healing), and kills, deaths and assists are the real ones from the game.

## Still placeholder

- All art in the arena (units, towers, Cairns, trees, monsters, the ground) is drawn in code in the Arena Dusk style, waiting for your choice of an art route.
- Games between two AI clubs are still decided by the old contest model (a v2 game costs about 0.2 s on the desktop); a data switch turns v2 on for them once it is fast enough on phones.
- Commentary lines, ability visual effects per hero, item icons.

## Known limits

- Speed: about 200 ms per game on the desktop; on a phone perhaps 1 to 2 s when a game starts. Not measured.
- Comebacks are rarer than the old target (a team 2,400 gold up at 8:00 wins about 88 percent).
- "Decided by" often names luck after a v2 game; the attribution's scale will be tuned with tester feedback.
- The ground shader's cost on a phone GPU is unmeasured.
