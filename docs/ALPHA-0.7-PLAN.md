# Alpha 0.7 plan: from the Founder's play-test feedback

Date: 2026-11-08. Source: the Founder's own play of Alpha 0.6. This plan is the shared brief for every agent working on it.

## The Founder's feedback (verbatim)

1. "visual design of the UI is acceptable for Alpha version however is a long way to visually pleasing."
2. "Game Tutorial is close to non-existent, much improvement needed, users will need us to explain and guide them how to navigate and play the game. Insufficient guide will result in user confusion and frustrations."
3. "what i see as a user playing the game is that everything is displayed linearly, the design is boring"
4. "when playing a match, there isnt much going on, unlike the video i gave you for reference, it should have battle actions, team decisions, player movements in-game, etc to make watching the game progress exciting and worthwhile to watch."

These outrank every other open item. The standing pillars still apply: customer satisfaction and ease of use first, our own flair, about 5 minutes per game including the draft, no ads or upsell in the core loop, 75 s fixed watch window (a Founder decision on record).

## Workstreams

### W1. Guided tutorial and in-context help (feedback 2)
Problem: three dismissible tips are not a tutorial. A new player cannot learn the loop.
Goal: a first-run guided game where the player learns by doing, plus help available everywhere.
- A coach overlay that spotlights the real control and waits for the player to tap it (Home next match day, Squad, Draft, Game Plan, Watch, Report, Standings).
- A "?" on every screen opening a short plain-words explanation of that screen, and a glossary reachable from Settings.
- Replayable from Settings; skippable at any step; remembers progress.
Acceptance: a person who has never seen the game finishes a first match day without outside help (tested by script, then by new testers); tester form question "In my first 5 minutes I understood what to do next" averages 4 or more; no step needs more than one tap to continue or skip.
Lead roles: UI/UX Designer (flow), Narrative Designer (words), Gameplay Programmer (build), QA Automation (scripted run).

### W2. Visual design pass 2 (feedback 1)
Problem: acceptable, not pleasing. Flat boxes, little depth, no illustration.
Goal: a look that feels crafted: richer colour and depth within Arena Dusk, hero portraits, club badges, an icon set, glow, gradients, considered typography, tasteful motion.
Acceptance: Founder approves a concept sheet before build, then before-and-after screenshots; all screens still fit large-text and colour-blind modes; all art is original and logged.
Lead roles: Art Director (art bible), Concept Artist, Character Artist, Environment Artist, Lighting Artist, Animator.

### W3. Layouts that are not a straight list (feedback 3)
Problem: every screen is a vertical stack of cards and rows.
Goal: screens with shape and rhythm: a hero area, two-column tiles, horizontal carousels, card grids with portraits, side-by-side comparisons, a draft board with role lanes, a podium for standings. One primary decision per screen stays true.
Acceptance: each main screen (Home, Squad, Draft, Game Plan, Standings, Report) has a new layout spec and a built version that fits 720 px width in normal and large text; Founder approves screenshots.
Lead roles: UI/UX Designer, Art Director, Gameplay Programmer, Engine / Graphics Programmer.

### W4. Live Match Arena (feedback 4)
Problem: the match is a clock, a bar and a text feed.
Goal: a 2D top-down arena in portrait where you watch the match happen: five heroes per side move along lanes and through the jungle, trade hits, take objectives, push towers, and fight as a team; the coach's decisions appear as short intent labels ("taking the big objective", "holding the wave"); a scoreboard and a feed run alongside; commentary lines add drama; sound and effects add weight; skip and fast-forward stay free.
Hard rules:
- The result is decided first by the simulation. The arena is a deterministic playback (same seed, same show) and can never change who wins.
- The arena must reflect the real simulated contests: early lane results (top, mid, bot, jungle), mid and late objective and fight outcomes, the final margin, and the Game Plan the player chose.
- The whole watch stays 75 s at normal speed.
- It must hold frame rate on a low-end phone (budget set by the Engine / Graphics Programmer).
Acceptance: the same match always plays identically; the visible story matches the report's "why you won or lost"; tester questions "Matches felt exciting" and "Results felt fair and believable" average 4 or more.
Lead roles: Level / World Designer (map), Gameplay / Champion Designer (action vocabulary), Esports Manager (authenticity), Technical Designer (choreography data), Systems Designer (what the sim can truthfully say), VFX Artist, Animator, Sound Designer, Gameplay Programmer, Engine / Graphics Programmer.

## Order of work

Spec stage (agents in parallel, then Studio Manager review), then a Founder checkpoint, then build.

Wave 1 (now): arena map, action vocabulary, esports notes, tutorial and layout spec, art bible pass 2.
Wave 2: choreography data and sim feasibility, concept sheets, tutorial copy, build plan and performance budget.
Build (recommended order, subject to the Founder's choice at the checkpoint):
- Alpha 0.7 "Guide and Look": W1 tutorial, W2 visual pass, W3 layouts, because testers cannot judge the game if they are lost, and the art made here feeds the arena.
- Alpha 0.8 "Arena": W4 live match arena.

## Honest limits

- Everything is checked with headless tests, simulated touch and screenshots on the build computer. Nothing has been run on a physical phone, so feel, speed and heat need the Founder's and testers' phones.
- Agents produce text, code, data and code-drawn art (SVG, generated sprites). They cannot paint, record, sculpt 3D models or hire people. Sound and music here are synthesised placeholders.
- With two testers so far, feedback is anecdotal until more arrive.

## Decisions for the Founder at the checkpoint

1. Build order: tutorial and look first (recommended), or the arena first.
2. In-match decisions: show the coach's decisions as labels derived from your Game Plan and the simulation (recommended for now), or let the player intervene during the match (for example a tactical pause that changes the result). The second needs simulation changes, calibration and a GDD update, and fits Beta better.
3. Approve one visual concept direction from the concept sheet.
