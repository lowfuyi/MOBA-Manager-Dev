# Gloamline Alpha 0.12.0: support pass, tester timings, commentary, icons and effects

Version 0.12.0 alpha (versionCode 19), 2026-11-24, built in the Founder's overnight run (queue Q0 to Q9). **Not run on a physical phone.** Browser and desktop numbers in these notes are not phone speed.

## What changed

- **Fennimore is a real support now (0.11.2).** Fen Fog also heals your whole team a little when it lands, and Leap Frog gives Fennimore a small shield. Fennimore now wins 46 to 49% at equal teams (was 42 to 46%), inside the 45 to 55% band in every ban format.
- **Rating counts a bit more** (+7% over 0.11.0 instead of +5%). Teams 10 and 20 points stronger win about 68 to 69% and 81.5 to 83%; every row is inside the GDD bands within tolerance. 39 to 40 of 40 heroes are inside 45 to 55% (Tanglewick 44.5% in Classic only). Ten heroes moved by 6% or less. Full before and after: `docs/design/BAN-EXPERIMENT.md`.
- **Your phone's numbers in the feedback note.** Settings, "Copy feedback note", now carries the build, your device (and browser on the web), how long your last draft took, how long the game took to start after the draft, and the arena's average and worst frame time in each view (Field, Action, All). Nothing is saved or sent; it is only in the text you copy.
- **Commentary.** At most two short lines a game, under the map, only in quiet moments: after a decisive fight, a Moonhulk or an early Stoneback, the lead at 8:00, or the lead near the end. None in large text.
- **Item icons.** Every item has a placeholder icon (tier, class and main stat at a glance) in the build editor, the draft Builds sheet and the hero pages.
- **Ability effects.** Casts look different by hero type: slashes, travelling bolts, rings, sparks; heals rise as a plus, shields arc around the hero, crowd control circles above the target, and ultimates are bigger.
- **Tall phones.** Field and All look more steeply down, so the island takes more of the screen (on a 19.5:9 phone from 59% to 69% of the arena's height; on 16:9 from 79% to 88%).
- **The game log** records where each ward was placed and which fights decided the game; the fog and the Action camera use them.
- **Web build:** iPhone launch images and a Home Screen name. Checked in WebKit (Safari's engine) at an iPhone size as well as Chromium.

## Not changed (prepared or proposed only)

- Games between two AI clubs still use the old model. The switch to Match Sim v2 is prepared and tested but off: it costs about 10 times more per game (`docs/design/AI-GAMES-V2-COST.md`).
- Comeback rules: proposal only (`docs/design/COMEBACK-PROPOSAL.md`).
- Large-text Draft (the first row of hero cards is about 25 px short on 16:9) and the large-text Game Plan controls: options logged, not fixed.

## What to test on the phone

1. Play a league game, then Settings, "Copy feedback note", and paste it to the Producer. The note carries the phone's real draft time, game start and frame times per view. This is the first real phone speed data.
2. Switch Field, Action and All during a big fight, then copy the note again: the frame times per view should all appear.
3. Pick Fennimore (support): does the fog's heal read? Is the shield visible when it leaps?
4. Watch for the commentary line under the map (amber dot). Does it come at a calm moment? Is it ever in the way?
5. Open a hero page and the build editor: do the item icons help you tell items apart?
6. Ability effects in a fight at x1: can you tell a heal from a hit? Are they too small?
7. On the web link in iPhone Safari (if available): add to Home Screen, open it, and check the launch image and sound after the first tap.
