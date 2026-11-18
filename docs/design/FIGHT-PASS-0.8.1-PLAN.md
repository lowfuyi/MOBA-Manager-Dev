# Alpha 0.8.1 "Fight pass": build plan v1.0 (2026-11-18, producer)

Founder feedback on 0.8 (phone): the moving map and seeing plans play out are liked, but fights do not feel like fighting.
"Heroes gather, a ring fills, the fight is over": the stats seem to fight, not the players. At x2 the game felt under a minute.

Goal: every fight on the map reads as **engage, trade, kills, retreat and chase**, with heroes acting by archetype, health bars
that fall as they are hit, and one big beat on the kill that decides the game. The result is still decided before the first
frame and the show only plays it back.

## 1. Rules kept (unchanged from 0.8)
- R1: no change to `game/src/sim`; golden hash `0b81a41b...ee3c` stays.
- The final kills, deaths per hero (Report.kda), towers and objectives equal the Report. Presentation never feeds results (R7).
- Rule A1: no simulation or attribution calls in `src/arena`. A2: randomness only from the `show` streams. A3: the same result
  gives the same show. Every frame is still a pure function of show time `t` (now also of the "beat clock", section 4).
- Draw-call budget: the busiest Match frame stays at 60 or fewer (target 50; 0.8 is 40). All new art is regions of the one
  baked icon strip, so it batches with the tokens.
- Animations off (reduced motion) is honoured: no shake, no zoom, no slow-down.

## 2. What changes (the five asks)
| # | Ask | What the player will see | Where |
|---|-----|--------------------------|-------|
| 1 | Hero action by archetype | **Melee** (bruiser, bulwark, shade): a dash into the target and a recoil back. **Ranged** (gunner): a projectile that flies to the target. **Caster** (spellcaster, binder): a wind-up then a burst on the target area (binder: a tether line). **Mender**: a pulse that lifts an ally's bar. | new `data/arena_actions_v1.json` (Champion Designer + VFX), `Choreo` and `ArenaFx` |
| 2 | Health bars | A small bar above every token in a fight. It falls with each hit, reaches zero exactly at a death the ledger has, never otherwise, and refills on respawn and slowly out of fights. | `ShowScript` (pure HP curve from the kill schedule), `ArenaMap` (bar regions) |
| 3 | A readable fight arc | **Engage** (the initiator dashes in, 0.6 to 1 s), **trade** (both sides hit, bars drop), **kills spaced** across the fight (at least 0.4 s apart unless a double kill), **retreat** (the low-HP losers turn and run), **chase** (the winners follow and finish). | `ShowScript` re-times kills *inside* each fight window (counts unchanged), `Choreo` (retreat and chase paths) |
| 4 | Decisive-kill beat | On the kill that decides the game (and the one that wins the late fight): a short camera shake, a punch-in zoom and a brief slow-down (about 0.6 s at half speed), then normal speed. With Animations off: a still flash and the word tag only. | `ArenaFx.camera_at`, the beat clock (section 4) |
| 5 | No filling ring in teamfights | Mossback and the late fight have no ring. At Stoneback and Moonhulk the **fight comes first**, and the ring appears only after it, while the winners take the objective (about 1.5 s). | `ArenaFx.arcs_at`, the TAKE windows |

## 3. Increments (one commit each, fast gate ALL GREEN before each, push after each)
- **F-01 Action vocabulary (design, no code).** The Gameplay/Champion Designer and VFX Artist write `docs/design/ACTION-VOCABULARY.md`
  section 5 "Fight pass": the per-archetype action (timing, travel, size, icon cells), the fight-arc timings, the HP rules and
  the decisive beat. It also covers the data table `game/data/arena_actions_v1.json` and its schema check in `validate_data`.
- **F-02 Fight script.** `ShowScript` gets a fight timeline per group beat: engage, trade, kill times re-spaced inside the window,
  retreat and chase marks. It also gets `hp_at(hero, t)`. Tests: per-hero kills and deaths still equal Report.kda; every kill
  is inside its fight; HP hits 0 only at a ledger death; spacing rules; same result, same timeline.
- **F-03 Actions on the map.** Dash and recoil offsets in `Choreo`; projectiles, bursts, tethers and heal pulses in `ArenaFx`
  (new icon cells). Health bars drawn from the atlas, batched with the tokens. Raise the live-cue cap from 12 to 24 if the
  draw-call probe allows. Tests: every projectile starts at a living shooter and ends at a living target; no action by a hero
  who is down.
- **F-04 Retreat, chase and rings.** Losers' retreat and winners' chase paths. The objective ring only after the fight; none in
  teamfights. Tests: no arc during Mossback or the late fight; at the objectives the ring starts after the last fight kill.
- **F-05 Decisive beat.** The beat clock (section 4), shake and zoom. Tests: the show still ends at 75 s of real time (±1 frame)
  at 30 and 60 fps and at x2; with Animations off there is no camera offset or slow-down; the decisive kill is the ledger's.
- **F-06 Acceptance.** Copy (any new tag words through `merge_copy.py`), perf probe (busiest frame ≤ 60 draw calls), pictures
  in four variants looked at twice, a short "fight strip" contact sheet of one fight frame by frame, full check exit 0,
  version 0.8.1 alpha (code 12), APK, notes that say plainly nothing has run on a phone.

## 4. The beat clock (how the slow-down keeps 75 s)
The show clock `show_t` still runs 0 to 75 s in real time. A slow-down is a local remap: during the 0.6 s around the decisive kill,
the map is drawn at `beat_t = remap(show_t)`. It runs at half speed there and catches up over the next 1.2 s of walking, where
nothing is happening. So the scoreboard, the words and the end time are unchanged. The kill still lands on its ledger moment
(within one frame), and `remap` is a pure function of `show_t`, so Skip, pause and x2 stay exact.

## 5. Risks
- Busy games (up to about 40 kills) make spaced kills crowded. The plan groups them into double and triple kills inside the
  fight window rather than changing the kill count. The real fix is the kill-rate retune, which waits for tester scores.
- More moving parts per frame: the probe and the cue cap guard draw calls, but **frame time, heat and battery on a phone are
  unmeasured** until the Founder tries 0.8.1.
- Readability at x2: actions are timed in show time, so at x2 a dash takes 0.15 s. If that reads as noise, x2 can drop to x1.5
  (decision 3 below).

## 6. Decisions for the Founder (recommendations in bold)
1. Slow-down on the decisive kill: **yes, about 0.6 s at half speed, made up by the walk after it (the game stays 75 s)**, or
   no slow-down (shake and zoom only).
2. Busy games: **group crowded kills into double and triple kills (no change to the numbers)**, or wait for the kill-rate
   retune first.
3. Speed button: **keep x2**, or change it to x1.5 so a game is about 50 s instead of 37.5 s.
4. Hero look: **tokens keep the role letter and gain the archetype action (no new hero art in 0.8.1)**, or add archetype
   silhouettes now (more art time).
