# Alpha 0.9 "Exit hardening" - install and test notes

Build: `build/gloamline-0.9.0-alpha.apk` (25.3 MB, sha256 54ecaa12..., versionCode 13, Android 5.0+, arm64, debug-signed with the
same key as 0.6 to 0.8, so it installs over any of them and keeps your save). It asks for one permission only: vibration.
This is a testing build: the debug key must never go to a store.

**Nothing in this build has run on a phone.** Every number below comes from the computer.

## Update 0.9.3 (2026-11-19, made while you test 0.9.2)
Build: `gloamline-0.9.3-alpha.apk` (versionCode 15, same key; installs over 0.9.2 and keeps your save). Nothing here changes how
matches play.
- **Back during the guided first game now asks first.** Before, the phone's Back gesture skipped the tutorial at once (with Undo).
  Now it asks "Leave the tutorial?" with Keep going and Skip tutorial; Back again closes the question.
- **Draft hero grid no longer goes blank.** The grid draws only the rows you can see; when something above it changed height (or
  the text size changed) without a scroll, rows could stay empty until you scrolled. Fixed and tested.
- **Wording:** player cards say "Age 23" (was "age 23"); a banned hero says "Banned" under its name; twelve older texts that called
  every player "he" now say "they" or "this player".
- Still not run on a phone.

## Update 0.9.2 (2026-11-18, made while you test 0.9.0)
Build: `build/gloamline-0.9.2-alpha.apk` (25.3 MB, sha256 15453d95..., versionCode 14, same key; installs over 0.9.0 and keeps your save). Optional: finish
your 0.9.0 test first if you like; nothing here changes how matches play.
- **Team chemistry** is lighter to draw (the heaviest screen in the game: 151 draw calls when scrolled, now 55) and the lines
  between starters now show how well they understand each other by **style** as well as colour: solid = well, dashed = fairly
  well, dotted = poorly (easier for colour-blind players). The hint under the picture says so.
- **Rings on the map for intent labels:** when a label such as "Going for Stoneback" shows, a ring marks that place on the map
  (circle for yours, hexagon for theirs).
- Still not run on a phone.

## What is in it (since 0.8.0)
- 0.8.0b: Frame rate setting, 30 or 60.
- 0.8.1 Fight pass: heroes act by type, health bars, real fight arcs with retreat and chase, the ring only after objective
  fights, and a beat on the deciding kill (details in `ALPHA-0.8-NOTES.md`).
- 0.8.2 Polish: hero shapes on the tokens (the role letter stays as a badge), up to two commentary lines a game, placeholder
  sounds and vibration (Settings > Sound and vibration).
- 0.9: no new features. Checks, fixes to the check tools, old saves tested, the tester pack, and the exit lists.
- Not changed, on purpose: the kill rate and the held-fight ending (island). Both wait for tester scores.

## What was checked on the computer
- Full check exit 0: 2,591 logic checks, ui smoke 208, every screen and touch check, pytest 133, calibration 0 out of band,
  golden vectors unchanged, perf gate 0 failures, art picture checks under a renderer 37.
- 125 simulated seasons (5 careers of 25 seasons), 25,605 checks, 0 failures.
- Saves made by the real 0.6, 0.7 and 0.8 builds open, keep the guide state and plans, and play into the next season (219 checks).
- 864 pictures in four layouts (normal, large text, colour-blind, tall), every group looked at on contact sheets. One known
  exception: a lesson card over the old Chemistry screen in the tall layout draws 136 times per frame (limit 100). Chemistry is
  the one screen still waiting for its redesign.

## What you need to do
See `docs/ALPHA-EXIT-FOUNDER-TODO.md` (phone tests, seasons, a first-time player, other phones, tester scores, key and
distribution, trademark search). For testers: `docs/TESTER-PACK.md`.
