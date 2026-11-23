# Comeback proposal (overnight Q8, 2026-11-24). NOT APPLIED

Founder note: "a team 2,400 gold up at 8:00 wins about 88 percent". This page measures it on 0.12 and proposes what to do. **Nothing here is applied**; `sim_v2_params.json` and the sim are unchanged. All numbers are from desktop runs of Match Sim v2, not a phone.

## 1. What the game does today (0.12 data, 2,400 games)

Probe: 2,400 league games between the default world's clubs (real AI drafts, 5 bans, real ratings, so teams differ in strength), six seeds. "Lead" is the team gold difference at 8:00.

| Gold lead at 8:00 | Games | Team ahead wins |
|---|---|---|
| 0 to 499 | 272 | 56.6% |
| 500 to 999 | 270 | 61.5% |
| 1,000 to 1,499 | 260 | 66.5% |
| 1,500 to 1,999 | 299 | 73.6% |
| **2,000 to 2,999** | 533 | **82.9%** (2,000 to 2,800: 82.1%) |
| 3,000 to 3,999 | 311 | 91.3% |
| 4,000 and more | 446 | 98.0% |

Standard errors 0.7 to 3 points. Over all games, the team ahead at 8:00 wins 78.5%. The median lead at 8:00 is about 2,100. Games the trailing team wins run about 2.6 minutes longer (16.5 against 13.9 min, leads of 2,000 or more).

So the Founder's reading is close: a 2,400 lead at 8:00 wins about 82 to 85% here (88% would be the 3,000 mark).

## 2. The catch-up levers that already exist

`sim_v2_params.json`: passive gold +1 a second for every hero of a team 2,000 or more behind (`catchup_gold`, `catchup_gold_from`); kill gold on a team that leads, up to x2.5 (`comeback_lead` 4,000, `comeback_max` 1.5); XP +25% per level behind (`xp_catchup`).

## 3. What was tried (scratch copy only, same 2,400 games)

| Variant | Change | Team ahead at 8:00 wins (all games) | With a 2,000 to 2,800 lead | Median lead at 8:00 |
|---|---|---|---|---|
| Today | none | 78.5% | 82.1% | 2,128 |
| A | catch-up gold 3 a second; the kill bounty is full at a 2,500 lead | 76.7% | 87.1% | 1,679 |
| B | A plus XP catch-up 0.4 and catch-up gold from a 1,500 deficit | 74.5% | 91.7% | 1,320 |
| C | objectives pay the trailing team up to double (from a 1,500 deficit) | 78.7% | 82.9% | 2,128 |

**Reading.** Stronger early catch-up (A, B) makes leads at 8:00 smaller, but barely changes who wins: the leader still wins 75 to 77%. The win rate at a given lead even goes up, because only a much stronger team still gets a 2,400 lead. Objective gold (C) does nothing measurable. The main cause in these games is team strength: the stronger club both builds the lead and wins (a 20-point rating gap is worth about 82% on its own, GDD 9). Gold levers mostly move the 8:00 number, not the result.

## 4. Proposal (Founder decision)

1. **Decide the target first.** Recommendation: "between equal teams, a 2,400 lead at 8:00 wins about 70 to 75%". That is a comeback in roughly 1 game in 4, which keeps early play meaningful and late games alive. With unequal teams the number will stay higher, and should: it is the stronger team.
2. **Measure it between equal teams** with the ban experiment's equal-team mode (`BX_GAPS=0`, `game/tests/ban_exp.gd`): about 2,000 games, 15 minutes on 7 processes. That separates the snowball from team strength. Not done tonight, because it needs a small new output column in that tool (gold at 8:00 per game). It is a tooling change, not a game change.
3. **If equal teams still read above 80%, change fights, not gold.** Lever, in order:
   - (a) **Defender's edge:** towers hit harder against a team that leads by 2,000 or more (the existing `fortify_mult` idea extended past the first 6 minutes). This gives the trailing side a place where it can win fights.
   - (b) **Shutdown bounty:** killing a hero on a 3+ streak pays an extra 150 to 300 to the whole trailing team (a genre-standard rule).
   - (c) **Longer respawns for the leading team after 20:00:** (+10%), so a won late fight by the trailing team converts into towers.
   Each is tested the same way (2,400 games plus 2,000 equal-team games), and the GDD 9 rating bands must stay in tolerance (the 40,000-game ban experiment) before anything ships.
4. Golden vectors would change (a sim change), so the Founder's yes comes first, then one increment with the re-record.

Raw rows: the probe prints `[lead at 8:00, blue won, length s]` per game (`probe_comeback.gd`, run from a scratch copy of game/).
