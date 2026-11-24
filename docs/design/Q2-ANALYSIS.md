# Q2 analyses: hero by lane, Game Plan sweep, draft weight (2026-11-24)

Founder's queue Q2 (`docs/design/ESMO-LESSONS.md`). Read-only: the simulation was run, never changed (golden hash unchanged). Harness `game/tests/q2_exp.gd`, runner `tools/q2_analysis.py`. Desktop simulation only.

## a) Hero win rate by lane (equal teams, real drafts)

Teams are moved to the same mean rating, so a hero's win rate is the hero, the draft around it and the lane. A hero counts as used in a lane with at least 300 games there. Band 45 to 55%.

- **1 ban a side** (40,000 games): 83 hero-lane pairs used; 23 outside the band.
  - Sunnivah in Bot: 32.2% (908 games)
  - Bastrel in Bot: 34.5% (1,255 games)
  - Wyncote in Bot: 37.1% (847 games)
  - Fennimore in Bot: 40.3% (566 games)
  - Tanglewick in Bot: 40.6% (721 games)
  - Corvane in Jungle: 40.9% (4,569 games)
  - Oriel in Bot: 42.7% (1,277 games)
  - Gravenstone in Top: 42.7% (5,660 games)
  - Alderwyn in Bot: 43.5% (1,417 games)
  - Tanglewick in Support: 44.5% (5,180 games)
  - Wyncote in Mid: 44.5% (512 games)
  - Brannoch in Mid: 44.7% (4,183 games)
  - Dovrin in Support: 44.8% (623 games)
  - Quillith in Jungle: 44.8% (6,893 games)
  - Dusken in Jungle: 45.0% (3,103 games)
  - Vellgrim in Support: 55.8% (4,408 games)
  - Orlund in Jungle: 56.0% (609 games)
  - Wyldrim in Jungle: 56.1% (3,389 games)
  - Tanglewick in Mid: 58.3% (852 games)
  - Hegwin in Mid: 59.6% (3,265 games)
  - Quillith in Mid: 59.9% (6,105 games)
  - Embrel in Top: 61.0% (5,672 games)
  - Sootwing in Top: 63.2% (304 games)

- **3 bans a side** (40,000 games): 91 hero-lane pairs used; 25 outside the band.
  - Sunnivah in Bot: 30.8% (1,068 games)
  - Lanthorn in Top: 33.3% (330 games)
  - Bastrel in Bot: 38.5% (1,713 games)
  - Corvane in Bot: 41.0% (388 games)
  - Gravenstone in Top: 41.6% (4,546 games)
  - Wyncote in Bot: 41.7% (1,145 games)
  - Dusken in Jungle: 42.4% (4,087 games)
  - Tanglewick in Bot: 42.7% (897 games)
  - Corvane in Jungle: 42.8% (4,578 games)
  - Brixley in Support: 43.5% (430 games)
  - Harkin in Support: 43.9% (713 games)
  - Oriel in Bot: 43.9% (1,851 games)
  - Tanglewick in Support: 44.2% (5,200 games)
  - Barrowick in Jungle: 44.5% (728 games)
  - Embrel in Mid: 44.8% (9,973 games)
  - Dovrin in Support: 44.9% (779 games)
  - Dunmarrow in Jungle: 55.3% (356 games)
  - Quillith in Mid: 56.1% (4,437 games)
  - Gravenstone in Mid: 56.3% (602 games)
  - Vellgrim in Support: 56.8% (4,068 games)
  - Orlund in Jungle: 58.1% (458 games)
  - Tanglewick in Mid: 58.6% (1,549 games)
  - Cindrel in Bot: 58.6% (449 games)
  - Hegwin in Mid: 59.8% (2,745 games)
  - Embrel in Top: 63.0% (5,542 games)

- **5 bans a side** (40,000 games): 104 hero-lane pairs used; 31 outside the band.
  - Sunnivah in Bot: 31.1% (1,086 games)
  - Lanthorn in Top: 36.6% (454 games)
  - Hegwin in Bot: 37.2% (304 games)
  - Bastrel in Bot: 37.8% (1,710 games)
  - Corvane in Bot: 38.3% (418 games)
  - Brixley in Support: 38.9% (768 games)
  - Hegwin in Support: 39.0% (382 games)
  - Wyncote in Bot: 40.8% (1,291 games)
  - Tanglewick in Bot: 42.0% (1,301 games)
  - Orlund in Bot: 42.7% (499 games)
  - Sunnivah in Top: 42.7% (358 games)
  - Dusken in Jungle: 42.9% (3,672 games)
  - Barrowick in Jungle: 43.0% (890 games)
  - Gravenstone in Top: 43.2% (4,063 games)
  - Embrel in Mid: 43.3% (9,573 games)
  - Corvane in Jungle: 43.3% (3,954 games)
  - Lanthorn in Support: 44.2% (4,542 games)
  - Tamsel in Mid: 55.9% (508 games)
  - Sparrowe in Jungle: 55.9% (304 games)
  - Tanglewick in Mid: 56.2% (2,112 games)
  - Sootwing in Top: 56.2% (368 games)
  - Cindrel in Jungle: 56.5% (527 games)
  - Gravenstone in Mid: 56.8% (732 games)
  - Cindrel in Bot: 57.2% (640 games)
  - Maurelle in Support: 58.2% (550 games)
  - Tessarine in Support: 58.2% (469 games)
  - Hegwin in Mid: 59.3% (1,751 games)
  - Vellgrim in Support: 59.4% (3,068 games)
  - Nimbrel in Top: 59.5% (326 games)
  - Orlund in Mid: 60.7% (359 games)
  - Embrel in Top: 61.2% (5,079 games)

## b) Game Plan sweep (equal teams, 5 bans a side)

2,000 base games. Each is played with both plans neutral (side A wins 50.8%), then once per option with only that option on side A, same draft and seed. Delta = option's win rate minus neutral, in points; the error is the paired standard error. Flag: delta above +3 points. Nothing was tuned.

| Option (side A) | Games | Win % | Delta | +-SE | Flag |
|---|---|---|---|---|---|
| a+100 jf=bot | 2,000 | 56.2 | +5.5 | 1.3 | FLAG |
| t+100 a+100 m+100 l+100 g+100 r+100 | 2,000 | 54.9 | +4.0 | 1.3 | FLAG |
| m-100 | 2,000 | 54.5 | +3.7 | 1.3 | FLAG |
| g+100 t+100 | 2,000 | 54.2 | +3.4 | 1.3 | FLAG |
| m-50 | 2,000 | 53.5 | +2.8 | 1.3 |  |
| jf=bot | 2,000 | 53.0 | +2.2 | 1.3 |  |
| r+50 | 2,000 | 53.0 | +2.1 | 1.3 |  |
| t+100 m+100 | 2,000 | 52.7 | +1.9 | 1.3 |  |
| t+100 a+100 | 2,000 | 52.4 | +1.6 | 1.3 |  |
| g+100 | 2,000 | 52.4 | +1.6 | 1.3 |  |
| a+100 jf=top | 2,000 | 52.2 | +1.4 | 1.3 |  |
| a+100 | 2,000 | 51.9 | +1.1 | 1.3 |  |
| s-50 | 2,000 | 51.7 | +0.9 | 1.0 |  |
| a+100 jf=mid_lane | 2,000 | 51.6 | +0.8 | 1.3 |  |
| g+100 r+100 | 2,000 | 51.5 | +0.7 | 1.3 |  |
| r-100 | 2,000 | 51.4 | +0.6 | 1.3 |  |
| r+100 | 2,000 | 51.3 | +0.5 | 1.3 |  |
| a+50 | 2,000 | 51.2 | +0.4 | 1.3 |  |
| s-100 | 2,000 | 51.1 | +0.3 | 1.2 |  |
| m+100 | 2,000 | 51.1 | +0.3 | 1.3 |  |
| g+50 | 2,000 | 51.0 | +0.2 | 1.3 |  |
| r+100 l+100 | 2,000 | 50.9 | +0.1 | 1.3 |  |
| t-50 | 2,000 | 50.9 | +0.1 | 1.3 |  |
| t+100 | 2,000 | 50.9 | +0.1 | 1.3 |  |
| m+100 l+100 | 2,000 | 50.7 | -0.1 | 1.3 |  |
| a-50 | 2,000 | 50.5 | -0.2 | 1.3 |  |
| l+100 | 2,000 | 50.5 | -0.3 | 1.2 |  |
| t-100 | 2,000 | 50.1 | -0.7 | 1.3 |  |
| l+50 | 2,000 | 50.1 | -0.7 | 1.1 |  |
| r-50 | 2,000 | 50.0 | -0.8 | 1.3 |  |
| jf=mid_lane | 2,000 | 50.0 | -0.8 | 1.3 |  |
| s+50 | 2,000 | 49.9 | -0.9 | 1.2 |  |
| t+50 | 2,000 | 49.8 | -1.0 | 1.3 |  |
| l-50 | 2,000 | 49.6 | -1.2 | 1.0 |  |
| l-100 | 2,000 | 49.5 | -1.2 | 1.1 |  |
| jf=top | 2,000 | 49.5 | -1.2 | 1.3 |  |
| t-100 l+100 | 2,000 | 49.3 | -1.5 | 1.3 |  |
| m+50 | 2,000 | 49.2 | -1.6 | 1.2 |  |
| g-50 | 2,000 | 49.1 | -1.6 | 1.3 |  |
| a-100 | 2,000 | 48.9 | -1.9 | 1.3 |  |
| s+100 a+100 | 2,000 | 47.5 | -3.3 | 1.3 |  |
| s+100 | 2,000 | 47.0 | -3.9 | 1.3 |  |
| g-100 | 2,000 | 47.0 | -3.9 | 1.3 |  |
| g-100 r-100 | 2,000 | 45.0 | -5.8 | 1.3 |  |

Best single option: m-100 (+3.7). Dominant combinations (beat the best single option by more than two standard errors): none.

## c) Does the draft decide too much?

**Draft score** of a side = the mean of the 15 phase ratings the match is given, divided by the same players' mean with a plain hero in every lane (own lane, full familiarity, no difficulty, power 50, patch 1.0), times (1 + composition bonus x its fight weight). 1.00 = the draft adds nothing; it holds hero fit, familiarity, hero power, the patch and the composition. The lane matchup bonus is not in it. **Player gap** = the difference of the plain-hero means (rating points). Natural ratings, real clubs, real AI drafts. A tie in draft score (under 0.001) is left out.

| Bans a side | Player gap | Games | Better draft wins | Better draft also has the better players |
|---|---|---|---|---|
| 1 | 0 to 2 | 310 | 57.1% | 50% |
| 1 | 2 to 5 | 685 | 55.2% | 57% |
| 1 | 5 to 10 | 1,365 | 51.4% | 48% |
| 1 | 10+ | 2,576 | 59.4% | 60% |
| 1 | all | 4,936 | 56.5% | |
| 3 | 0 to 2 | 321 | 55.1% | 46% |
| 3 | 2 to 5 | 638 | 56.7% | 61% |
| 3 | 5 to 10 | 1,321 | 55.3% | 50% |
| 3 | 10+ | 2,651 | 59.7% | 59% |
| 3 | all | 4,931 | 57.8% | |
| 5 | 0 to 2 | 358 | 52.2% | 42% |
| 5 | 2 to 5 | 655 | 52.4% | 59% |
| 5 | 5 to 10 | 1,300 | 55.6% | 55% |
| 5 | 10+ | 2,610 | 61.6% | 61% |
| 5 | all | 4,923 | 58.1% | |

- 1 bans: when the better draft has the WEAKER players (gap 2+), the better draft wins 26.7% (2,045 games).
- 3 bans: when the better draft has the WEAKER players (gap 2+), the better draft wins 28.1% (1,987 games).
- 5 bans: when the better draft has the WEAKER players (gap 2+), the better draft wins 26.5% (1,868 games).

## d) Matchup table

`game/data/hero_matchups_v1.json` from 120,000 equal-team games (a) above: 38 of 40 heroes have at least one "struggles against" entry (at least 400 games a pair, 3+ points below the hero's own win rate, z <= -2.5). The definition is inside the file. Display only.

