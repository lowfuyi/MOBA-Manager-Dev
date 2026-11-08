# Esports notes: making the live match feel like real MOBA esports

Owner: Esports Manager. Date: 2026-11-08. For workstream W4 (Alpha 0.7 plan). Advice only: the simulation decides the result, and the arena only plays it back. Map and objective names are the GDD placeholders (Hollowmere, Stoneback, Moonhulk, the Cairn).

## 1. Phases of a pro match and what viewers see

| Phase | Real match (about) | What viewers see | Our sim contest and time |
|---|---|---|---|
| Laning | 0 to 12 min | Heroes farm waves one-on-one or two-on-two. Small trades, one lane pushed in, one hero short of health. The jungler passes through and may strike one lane. | Top, Mid, Bot, Jungle results at 0.25L |
| First rotations | 8 to 15 min | Lanes break, heroes walk together, scouts check bushes, the first tower falls. Tension is in who arrives first. | Early objective (Stoneback) at 0.45L |
| Objective fights | 12 to 25 min | Both teams stack around a neutral objective. One side starts the take, the other tries to steal or punish. | Mid fight 0.60L, late objective (Moonhulk) 0.80L |
| Team fights | any time after about 12 min | Ten heroes collide for 5 to 15 seconds. Someone initiates, someone is caught, the losing team breaks apart. | Mid fight 0.60L, late fight 0.95L |
| Comeback | after a long deficit | The behind team wins one fight or objective and the lead shrinks. It needs one clean pick or a smart defence. | Only when the sim supports it (see section 2) |
| Closing out | last 3 to 5 min | The leading team pushes lanes together, towers drop, then the base core. A single lost fight can flip it. | Base siege at 1.0L |

## 2. A 75-second highlight

Show only moments where the lead changes or is defended, and let a quiet stretch last a second or two so the next beat lands.

| Seconds | Beat | Show | Skip |
|---|---|---|---|
| 0 to 5 | Setup | Both five-hero rosters, plan labels, clock starts | Walking out from base |
| 5 to 22 | Lanes | Four short beats, about 4 s each, ordered by size of result (largest first) | Farming with no result |
| 22 to 34 | First objective | The approach, the take or the steal, who gets the reward | Waiting for it to spawn |
| 34 to 47 | Mid fight | Full team collision, one clear initiator, a visible turn | Individual last hits |
| 47 to 57 | Late objective | Setup, a risk, a payoff, a lead number that jumps | Recalls and shopping |
| 57 to 69 | Late fight | The longest fight, slowed slightly at the decisive moment | Repeating earlier kills |
| 69 to 75 | Closing | Siege on the Cairn, last hit, a 2 s hold on the result | Credits, statistics |

Pacing: loudest effects on the two big fights and the final hit; a calm beat between them so release is felt.

Stomp versus close game:
- **Stomp:** the lead line climbs steadily, fights end early and one-sided; speed through the middle, let the loser try one idea that fails, finish with a calm siege.
- **Close game:** the lead line crosses zero at least once; hold fights longer, show a near-miss, keep the result unclear until the late fight.
- **Comeback or snowball:** dramatise one only when the sim's signed contest results show it. Never invent a swing.

## 3. How casters and graphics communicate

| Item | Purpose | Phone portrait? |
|---|---|---|
| Scoreboard: kills, towers, objectives, clock | State at a glance | Yes. One slim top bar. |
| Gold-lead graph | Shows who is ahead and when it flipped | Yes. A thin line over the match so far, with markers for each contest. |
| Objective timers | Tells viewers when a fight is likely | Yes, but only the next one, as a single chip. |
| Intent label (a short reason for movement) | Explains why heroes are going somewhere | Yes. Best single feature. One label per side at most. |
| Kill and take notices | Confirms events | Yes. A short, fading feed of 3 lines. |
| Play of the game | Names the match's best moment | Yes, once, at the end, as a replayed beat on the result screen. |
| Five player panels with items and levels | Detail for experts | Behind a tap only. |

Broadcast lessons: keep the action clear during fights, show only data you can trust, and pair kills with gold and objectives.

## 4. Commentary style

- **Tone:** warm, excited but not shouting, fair to both sides.
- **Length:** 4 to 9 words in fights, up to 14 in calm moments; one line at a time, on screen about 2.5 s.
- **Variety:** at least 3 phrasings per event type, no repeat within 20 lines, a mix of facts and feeling.
- **Truth:** every line comes from a real sim event; never predict a result the sim has not produced.

Sample lines (original; replace names with the actual hero, lane and club names):

| Situation | Lines |
|---|---|
| Opening | 1. "Both teams are in position, and the clock is running." 2. "Five heroes each, three lanes, one Cairn each to protect." |
| Lane lead | 3. "{Top hero} is clearly ahead, and the wave is leaning their way." 4. "A quiet lane, but that small lead will matter later." |
| Lane swing | 5. "The jungler has arrived, and that lane just flipped." 6. "A narrow escape, and the pressure drops." |
| Objective | 7. "Everyone is gathering around Stoneback." 8. "It is taken cleanly, and the buff goes to {team}." 9. "A steal attempt, and it nearly works!" |
| Team fight start | 10. "They commit, and it is five against five." 11. "The first strike lands on the back line." |
| Team fight result | 12. "One side is falling apart, and the other presses." 13. "Three down for {team}. That decides this fight." |
| Comeback | 14. "A small chance appears, and {team} grabs it." 15. "The gold gap is shrinking, and the crowd feels it." |
| Stomp | 16. "There is no answer to this pressure." 17. "Towers fall one after another." |
| Closing | 18. "The Cairn is exposed, and nobody can stop the push." 19. "One last hit, and it is over." |
| Close finish | 20. "That was a game decided by one fight." |

## 5. Do not copy

- Real teams, players, leagues, tournaments, heroes, items, map or objective names.
- Branded overlays, colour schemes, logos or layouts that look like a known broadcast.
- Signature phrases or recurring jokes of any real caster, and fan-community catchphrases.
- Real region names are allowed for competitions (Founder decision), never beside a real club or person.

## 6. Recommendations for the match arena

1. Show one slim scoreboard and a thin gold-lead graph above the arena so the story of the match is readable at a glance.
2. Give every fight a visible beat order (approach, first strike, turn, result), with the camera nearest the decisive moment.
3. Put one intent label per side near its heroes, and make each label come from the Game Plan or the sim's contest.
4. Spend the 75 s by the table in section 2, giving the two big fights and the closing most of the time.
5. End on a 2 s hold with a "play of the game" caption that matches the first line of the report's "why you won or lost".

## Sources

- LHM, "What makes a good League of Legends broadcast overlay?" (lhm.gg/blog/what-makes-a-good-lol-broadcast-overlay), used for overlay hierarchy and fight-safe display.
- gaming.net, "League of Legends things to watch beyond kill score", used for gold, objectives and what viewers watch.
- Studio files: GDD-v1.11 sections 2, 8.3, 8.5, 8.7; UI-UX-REFERENCE-v1 section 2.3; ALPHA-0.7-PLAN.
- Phase timings and pacing are general genre knowledge, not measured.
