# Copy for Alpha 0.7 (Gloamline)

Version 1.0 · Date 2026-11-09 · Author: Narrative Designer · Status: final copy for the Producer to merge. **Nothing here has been run in Godot or on a phone.** Word counts, limits, colour words and key checks were run by script (section 3).

Patch file: `docs/design/copy/en_0_7.json` has exactly the 540 keys below (524 new, 16 replace an existing string). Merge it into `game/i18n/en.json`; I did not edit that file. Sources: `TUTORIAL.md` (27 coach texts, lessons, glossary, help rows, section 12 chrome, section 13 rename), `UI-PASS-2.md` 7.4, `ESPORTS-NOTES.md` 4, `ART-BIBLE.md` 5.1 (font).

## 0. Read this first

1. **Every string the spec asks for is written**, with the spec's keys and step ids kept. 39 strings changed from the spec text (section 5, each with a reason); the other spec strings are word for word.
2. **Coach and Manager:** the helper is "Coach" and the player is "Manager" in every merged string. Two old strings said "advisor" and one said "owner and coach"; all three are replaced (section 6). After the merge no string contains "advisor" or the helper in lower case.
3. **The Points / Form switch** reads **Points** and **Form Rating** (not "Form"). Player "form" and club "Form Rating" then never share a word.
4. **Contest names** are one set: Top, Mid, Bot, Jungle (chips) and "Top lane", "Mid lane", "Bot lane", "Jungle" (feed lines). Objective and Fight are the other two.
5. **Three things need a human decision** (section 2): the word "Mid" is both a lane and a phase, the Draft role filter still says "Jg" and "Sup", and the Chemistry hint still says "Greener line" (a colour-only cue, not mine to fix).

## 1. Voice rules used

These are the rules behind every string (ESPORTS-NOTES 4 for commentary tone; the art bible has no voice section). They go into `docs/design/VOICE-AND-TONE.md` when the Producer lets me create it (I was told to edit only two files today).

- **Plain and friendly.** Short sentences, everyday words, for a reader in Singapore or Malaysia whose English is good but not literary. No idioms ("better bets", "sours", "where your players live" were changed), no slang that needs explaining, no jokes.
- **One name for each thing.** Coach (the helper, capital C, never "advisor", "assistant" or "AI"); Manager (the player, never "the coach"); Form Rating (a club's score, capital R) against form (a player's recent results); team rating (lower case r, as the existing strings); Game plan (sentence case everywhere); role (a player's job) against lane (a path on the map); contest names Top, Mid, Bot, Jungle, Objective, Fight.
- **Quote the screen.** A coach text names a control exactly as its label reads. Script check: 37 labels quoted by coach, help and lesson texts were found in the string table (all found).
- **No colour words** in any new string (colour-blind mode swaps green and red for blue and orange). A shape, arrow, sign or word carries the meaning ("up arrow", "plus means", "marked YOU"). Only exceptions: the side names Blue and Red beside a flag icon, and the two strings that describe the colour-blind setting itself.
- **No gendered pronouns** for players ("their", "they", "the player"). Existing strings still use "he" and "his" (section 6).
- **Honest about luck.** Nothing promises a result. Loss texts say it was practice; luck is defined as the random part that no plan controls. Story tags say only what the phase signs show.
- **Limits.** Coach 25 words, lesson 25, glossary 22, help line 20, banner 4 words. `{club}` counts as 2 words. Other limits (button 4, toast 12, chip 4, empty title 5, story tag 7 and so on) are my own and are in the rule list below.

## 2. Decisions I made, and three that need you

| Clash | What I did | Why |
|---|---|---|
| Standings switch says "Form", player cards say "form" | Switch options are **Points** and **Form Rating** (`standings.metric.points`, `standings.metric.form`) | `tut.form_switch`, `les.l1.metric` and `help.standings` already say Form Rating. About 120 to 130 px at 24 px per UI-PASS-2 7.4: UI/UX must confirm it fits the 88 px header row in large text (not measured, no font in the repo). Fallback if it does not fit: "Rating" |
| Contest names | Chips Top, Mid, Bot, Jungle, Objective, Fight (`gp.contest.*`); feed keeps "Top lane", "Mid lane", "Bot lane" and now "Jungle" (was "Jungle control") | One set everywhere; "lane" is added only in sentences |
| Helper and player | "Coach" and "Manager" | Producer ruling, TUTORIAL.md 13 |
| Game plan / Game Plan | "Game plan" | The button, `gp.title` and `draft.game_plan` already use sentence case |
| "Scale" (tempo end label) | "Play for late" in `gp.end.t.pos` and `gp.c.t.pos`; hero tag "scales late" becomes "strong late" | "Scale" needs explaining; the Coach sheet prints it in a sentence |
| If behind / If ahead caption | "Only the part from the mid-game on applies in this plan" (UI-PASS-2 drafted "late-game") | The trigger plans take over from the mid-game on (`gp.trigger_hint.*`, `les.l5.plan`), so "late-game" was too narrow |
| Factor sheet name | "Why this happened" (new layout) | `report.why_h` "Why it went this way" is the old name; two names for one thing. Retire the old one when the new Report ships |

**Decisions needed** (recommendation first):

1. **"Mid" is a lane and a phase.** The Game Plan strip (Overall, Early, Mid, Late) and the Report story bands use "Mid" for the mid-game; the lane chip is also "Mid". They sit in different places, and lane chips only appear inside the Early band. Recommendation: keep both, and have testers look at it. If it confuses, the phase becomes "Mid game" (`gp.phase.mid`, `match.phase.mid`: two keys).
2. **Draft role filter shows "Jg" and "Sup"** (`role.short.jg`, `role.short.sup`). "Jg" is genre shorthand a new player will not know. Recommendation: UI/UX measures "Jungle" and "Support" at 26 px in the six-chip filter; if they fit, change both keys (I did not, because the lane-row codes JG and SUP are the UI/UX Designer's). Not in the patch.
3. **`chem.pentagon_hint`** says "Greener line: better understanding". If understanding is drawn in colour only, that is a colour-only cue and breaks colour-blind mode. Recommendation: UI/UX adds a non-colour cue (line style or a number), then I rewrite the hint. Not in the patch.

## 3. Numbers and checks (run by script)

| Check | Result |
|---|---|
| Keys in the patch | 540 (524 new, 16 replacing an existing key) |
| `tut.*` keys, longest | 66 keys, longest 24 words (`tut.ban`), limit 25 |
| `les.*` lesson steps, longest | 33 steps, longest 24 words (`les.l5.contests`), limit 25 |
| Glossary definitions, longest | 49 terms, longest 22 words (`gl.potential.def`), limit 22 |
| Help lines (see, do, know), longest | 60 lines, longest 20 words (`help.gameplan.know`), limit 20 |
| `gp.switch.short.<id>` | 5 strings, longest 4 words (`gp.switch.short.behind_early`), limit 4 |
| Track end labels | 14 strings, longest 3 words and 14 characters at most |
| Words counted | by splitting on spaces; `{club}` counted as 2 words (`tut.welcome` is 22 words counted this way) |
| Any string over its limit | none (540 rows checked) |
| Colour words in the 540 new or replaced strings | none (side names `draft.side.blue` and `draft.side.red` are allowed by rule; the check also ran on all 1169 merged strings: the only hits left are the two names `hub.side.*`, the two colour-blind setting strings, and `chem.pentagon_hint`, listed in section 6) |
| "advisor", "assistant", "owner and coach" in the merged table | 0 (before the patch: 3 keys) |
| Real game names in the patch | none found (searched for the reference game and 11 other well-known titles) |
| Glossary ids used by help sheets all exist | yes (49 terms; one id, `jungle`, was in the draft match row but is not a term, so I removed it and explained the Jungle in `gl.lane.def`) |
| Spec keys missing from the patch | none that are strings (`tut.advisor_rest` is the retired name; `help.home` and the like are sheet ids) |
| Hero display names over 12 characters (UI-PASS-2 7.6 item 5) | none. 40 heroes, longest `Gravenstone` (11), then `Tanglewick` (10), `Tessarine` (9). Club names: longest `Northreach Corsairs` (19). Arena objective names: Stoneback, Moonhulk, The Cairn (all 12 or fewer) |
| `tools/check_strings.py` on the merged table (temp copy, repo untouched) | `strings OK` (before: `strings OK`); 588 keys not yet used by code, which is expected until the build adds them |
| Checker negative controls | the colour check flagged "Tap the green button" and "Greener line"; the word check flagged a 30-word text; the helper check flagged "advisor" |

Rules (the code in the last column of every table):

| Code | Rule |
|---|---|
| COACH | Coach text: 25 words or fewer, one idea, exact on-screen labels, no colour word (TUTORIAL.md 1.2, test 14) |
| LESSON | Lesson step: 25 words or fewer, no colour word |
| GLOSS | Glossary definition: 22 words or fewer, neutral pronouns, no colour word |
| HELP | Help line: 20 words or fewer, no colour word |
| BTN | Button label: 4 words or fewer; an action starts with a verb; exact label that coach texts quote |
| TOAST | Toast: 12 words or fewer, says what happened |
| TITLE | Title or heading: 6 words or fewer, sentence case |
| NOTE | Short note or sheet line: 25 words or fewer |
| LABEL | Label: 8 words or fewer |
| CHIP | Chip, tab or small label: 4 words or fewer |
| CAPTION | Caption under a control: 8 words or fewer |
| BANNER | Match banner: 4 words or fewer (ACTION-VOCABULARY P3) |
| END | Track end label: 3 words and 14 characters or fewer, fits one line |
| TAG | Story tag: 7 words or fewer, claims only what the phase signs say |
| SENT | Status or hero-stat sentence: 20 words or fewer |
| EMPTY_H | Empty-state title: 5 words or fewer |
| EMPTY_B | Empty-state helper: 14 words or fewer, says what to do or why |
| BODY | Paragraph for About or the feedback note |
| REF | Reference to a help sheet id (data, not text) |

## 4. The strings

Column "vs spec": **same** is word for word as TUTORIAL.md or UI-PASS-2; **changed** is in section 5; **not in spec** is written by me for a UI-PASS-2 copy need or a rename (the keys are new unless the row says it replaces an existing one). Placeholders such as `{hero}` are filled by code.

### 4.1 Guided first game: the 27 coach texts

One row per step (step 21 has a win and a loss text). Step ids are unchanged from TUTORIAL.md 3.2. `{club}` is counted as 2 words (worst case: a two-word club name).

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `tut.welcome` | Welcome, Manager. You run {club}. Let's play one practice game together. It takes a few minutes, and nothing in it counts. | 22 | COACH | changed |
| `tut.home_card` | This is your next match day: who you play and how you compare. Home always shows what to do next. | 20 | COACH | same |
| `tut.tabs` | Five tabs hold your club: Home, Squad, Plan, Club and More. They are always here, so you cannot get lost. | 20 | COACH | same |
| `tut.tab_squad` | Squad is where you see your players. Tap Squad. | 9 | COACH | changed |
| `tut.squad_bench` | Your five starters stand on the map and play every game. Tap a bench player to open their card. | 19 | COACH | same |
| `tut.player_card` | This is a player card. The bars show tiredness, form and morale. Tired or unhappy players play worse. | 18 | COACH | same |
| `tut.tab_plan` | Plan is where you prepare between games: training, team chemistry and practice. Tap Plan. | 14 | COACH | same |
| `tut.plan_practice` | Practice games never count: not the table, not Form Rating, not morale. A safe place to learn. Tap Practice matches. | 20 | COACH | same |
| `tut.quick_match` | A Quick Match is one game against a club close to your strength. Tap Play a Quick Match. | 18 | COACH | same |
| `tut.matchups` | Each row compares your player with theirs in that role. Higher numbers are better. Look for roles where you are ahead. | 21 | COACH | same |
| `tut.start_draft` | Next is the draft, where both teams ban and pick heroes. Tap Start draft. | 14 | COACH | same |
| `tut.ban` | First, a ban. Banning a hero stops the other team using it. Tap any hero, then Ban, or tap Take on the Coach bar. | 24 | COACH | same |
| `tut.pick` | Now pick a hero for your team. Heroes with an up arrow are strong this patch. Tap a hero, or tap Take. | 22 | COACH | same |
| `tut.role` | Choose which role plays this hero. The percentage is how well it fits that role. The best fit is already chosen. Tap Pick. | 23 | COACH | changed |
| `tut.coach_rest` | You can pick every hero yourself, or let the Coach finish the draft. Tap Auto-finish, then tap Sure? to confirm. | 20 | COACH | same |
| `tut.open_plan` | Draft done. Next, a game plan tells your team how to play: fights, tempo, objectives. Tap Game plan. | 18 | COACH | changed |
| `tut.coach_suggest` | Not sure what to set? Tap Coach. It suggests a plan from how your team compares with theirs. | 18 | COACH | same |
| `tut.start_match` | Happy with the plan? Tap Start the match to watch the game. | 12 | COACH | same |
| `tut.watch` | Results appear in the feed as each part of the game is decided. Try Speed x2, or Skip to the end. | 21 | COACH | changed |
| `tut.see_report` | The game is over. Tap See the report. | 8 | COACH | same |
| `tut.result.win` | Victory. The report starts with the result and the margin. This was practice, so nothing changed in your season. | 19 | COACH | same |
| `tut.result.loss` | Defeat. That is fine. It was practice, and nothing changed in your season. The report shows why it went this way. | 21 | COACH | changed |
| `tut.why` | This number is the biggest factor in the result. Tap it to see every factor. Luck is one of them. | 20 | COACH | same |
| `tut.continue` | Tap Continue to leave the report. After real games it also shows what changed for your players. | 17 | COACH | same |
| `tut.tab_club` | Club holds money, the league table and Form Rating. Tap Club. | 11 | COACH | same |
| `tut.form_tile` | Form Rating is a skill score for every club. Beating strong clubs raises it. Practice games never count. Tap it. | 20 | COACH | same |
| `tut.form_switch` | This list ranks clubs by Form Rating. Tap Points to switch to league points. Your club is marked YOU in both. | 21 | COACH | changed |
| `tut.finish` | You are ready. Go to Home and tap Play game for your first real match. The ? button explains any screen. | 21 | COACH | same |

### 4.2 Stage-B lines, shortcut buttons and variants

Stage-B lines replace the card text when a step's second control appears (TUTORIAL.md 3.2, 7.6). Shortcut buttons are the one-tap routes (3.2a). Variants are the Alpha 0.8 arena line and the two layout alternatives.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `tut.ban.confirm` | Tap Ban to confirm. | 4 | COACH | same |
| `tut.coach_rest.sure` | Tap Sure? to let the Coach finish. | 7 | COACH | same |
| `tut.coach_suggest.apply` | These are the changes. Tap Apply to use them. | 9 | COACH | same |
| `tut.why.sheet` | Each bar is how much one factor moved the result. Luck is the random part of every game. | 18 | COACH | same |
| `tut.shortcut.coach_rest` | Let the Coach finish | 4 | BTN | same |
| `tut.shortcut.apply` | Apply for me | 3 | BTN | same |
| `tut.watch.arena` | Your team is the circles. Watch the fight, or use Speed x2 or Skip to the end. | 17 | COACH | same |
| `tut.squad_bench.alt` | Your five starters play every game. Tap a bench player to open their card. | 14 | COACH | same |
| `tut.squad_token` | Your five starters stand on the map. Tap one to see who else could play that role. | 17 | COACH | same |
| `tut.picker` | Each row shows the change to team rating if you pick that player. We will not change anything now. | 19 | COACH | same |

### 4.3 Tutorial chrome: buttons, toasts, offers, chapter names

From TUTORIAL.md section 12. Every `tut.*` key is held to the 25-word coach limit by test 14.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `tut.next` | Next | 1 | BTN | same |
| `tut.start` | Start | 1 | BTN | same |
| `tut.skip` | Skip tutorial | 2 | BTN | same |
| `tut.go_home` | Go to Home | 3 | BTN | same |
| `tut.nudge` | Tap the highlighted spot to continue. | 6 | COACH | changed |
| `tut.skipped_toast` | Tutorial skipped. You can replay it in Settings. | 8 | TOAST | same |
| `tut.left` | Leaving the tutorial here. You can replay it in Settings. | 10 | TOAST | same |
| `tut.back.h` | Leave the tutorial? | 3 | TITLE | same |
| `tut.back.body` | Your game is safe. You can replay the tutorial any time in Settings. | 13 | NOTE | same |
| `tut.back.keep` | Keep going | 2 | BTN | same |
| `tut.resume` | Welcome back. Continue the guided first game? | 7 | NOTE | same |
| `tut.resume.go` | Continue | 1 | BTN | same |
| `tut.offer.legacy` | New: a guided first game and help on every screen. | 10 | NOTE | same |
| `tut.offer.returning` | Welcome back, Manager. Want the guided first game again? | 9 | NOTE | same |
| `tut.offer.yes` | Show me | 2 | BTN | same |
| `tut.offer.no` | No thanks | 2 | BTN | same |
| `tut.fallback` | We cannot find that on this screen. Tap Next to continue. | 11 | COACH | changed |
| `tut.report_card.h` | Practice result | 2 | TITLE | same |
| `tut.report_card.body` | Nothing in your season changed. This game was only for learning. | 11 | NOTE | same |
| `tut.practice.note` | Tutorial match: nothing in it counts. | 6 | NOTE | same |
| `tut.draft.note` | No timer in the tutorial. Take your time. | 8 | NOTE | same |
| `tut.ch.1` | Find your way | 3 | TITLE | not in spec |
| `tut.ch.2` | Your squad | 2 | TITLE | not in spec |
| `tut.ch.3` | Set up a game | 4 | TITLE | not in spec |
| `tut.ch.4` | The draft | 2 | TITLE | not in spec |
| `tut.ch.5` | Plan and watch | 3 | TITLE | not in spec |
| `tut.ch.6` | The result | 2 | TITLE | not in spec |
| `tut.ch.7` | The league | 2 | TITLE | not in spec |

### 4.4 Lessons (8 lessons, 33 steps) and the Lessons screen

Step ids and keys are as in TUTORIAL.md 4.2. L3 and L5 mention the contest name set; `les.l5.contests` now defines what a contest is.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `lesson.title.l1` | The league table and playoffs | 5 | TITLE | not in spec |
| `lesson.title.l2` | Training and rest | 3 | TITLE | not in spec |
| `lesson.title.l3` | Contracts | 1 | TITLE | not in spec |
| `lesson.title.l4` | Bonds and chemistry | 3 | TITLE | not in spec |
| `lesson.title.l5` | Game plan in depth | 4 | TITLE | not in spec |
| `lesson.title.l6` | Money and the wage cap | 5 | TITLE | not in spec |
| `lesson.title.l7` | Signing a player | 3 | TITLE | not in spec |
| `lesson.title.l8` | What a game changed | 4 | TITLE | not in spec |
| `les.l1.open` | Tap Standing to open the league table. | 7 | LESSON | same |
| `les.l1.table` | A win is worth 3 points. The top four clubs reach the playoffs. Ties go to head-to-head wins, then total margin. | 21 | LESSON | same |
| `les.l1.metric` | Switch between Points and Form Rating. Your club is marked YOU in both. | 13 | LESSON | changed |
| `les.l1.tabs` | Playoffs shows the title series as a bracket. History keeps your recent games and your trophies. | 16 | LESSON | same |
| `les.l2.open` | Players grow a little between match days. Tap Training to choose what each one works on. | 16 | LESSON | same |
| `les.l2.preview` | These chips show how many starters are tired now, and after the next game. Tired starters lose rating. | 18 | LESSON | same |
| `les.l2.player` | Tap a player to choose a focus: a stat, a hero, a team scrim or rest. | 16 | LESSON | same |
| `les.l2.rest` | Rest adds no tiredness and clears some. Pick it for a worn starter. Changes apply at once, and you can Undo. | 21 | LESSON | same |
| `les.l3.open` | Contracts last a set number of seasons. Tap Squad to see who is close to the end. | 17 | LESSON | same |
| `les.l3.row` | Tap a bench player whose contract is ending. | 8 | LESSON | same |
| `les.l3.contract` | The card shows the weekly wage and the seasons left. When none are left, the player leaves unless you renew. | 20 | LESSON | same |
| `les.l3.renew` | Renew starts talks. Young players with high potential ask for more, and the wage cap limits what you can afford. | 20 | LESSON | same |
| `les.l4.open` | Bonds grow when players play together. Tap Team chemistry to see yours. | 12 | LESSON | same |
| `les.l4.summary` | Chemistry turns the bonds of your five starters into a small rating bonus for the whole team. | 17 | LESSON | same |
| `les.l4.map` | Each line is a bond between two starters. Thicker lines mean stronger bonds. | 13 | LESSON | same |
| `les.l4.scrim` | Team scrims in Training build bonds a little faster. Swapping a starter costs chemistry until the new pairs have played. | 20 | LESSON | same |
| `les.l5.open` | Tap Game plan to look at your options. | 8 | LESSON | same |
| `les.l5.edge` | Expected edge is your advantage before luck. Your plan moves it. Luck can still change a single game. | 18 | LESSON | same |
| `les.l5.contests` | Each row is one contest: a lane, the jungle, an objective or a fight. Plus means you are stronger there, minus means they are. | 24 | LESSON | changed |
| `les.l5.phases` | Overall, Early, Mid and Late are the phases of a game. Tap one to see its settings and where you stand. | 21 | LESSON | same |
| `les.l5.plan` | Plan: Default is used from the start. If behind or If ahead can take over from the mid-game, after a one-sided early game. | 23 | LESSON | changed |
| `les.l5.sliders` | Each setting trades one strength for another. Risk and aggression make games swingier, which helps the underdog. | 17 | LESSON | same |
| `les.l6.club` | Tap Club to find your money. | 6 | LESSON | same |
| `les.l6.finance` | Tap Finance to see where your cash goes. | 8 | LESSON | same |
| `les.l6.balance` | Balance is your cash. Wages are paid every round. If it stays below zero too long, the board dismisses you. | 20 | LESSON | same |
| `les.l6.cap` | The wage cap is the most you can pay players each week. Signings over the cap are blocked. | 18 | LESSON | same |
| `les.l6.sponsor` | A sponsor pays a weekly retainer and a bonus for hitting its target. You can change it until your first game. | 21 | LESSON | same |
| `les.l6.sponsor_locked` | A sponsor pays a weekly retainer and a bonus for hitting its target. This season's deal is fixed. | 18 | LESSON | same |
| `les.l7.open` | Free agents have no club. Young players with high potential grow into stars but ask for more. Tap Free agents. | 20 | LESSON | same |
| `les.l7.filters` | Filter by role and sort by rating, potential, age or price. | 11 | LESSON | same |
| `les.l7.row` | Tap a player to start talks. What they will accept is a secret, so make an offer and read the reply. | 21 | LESSON | same |
| `les.l8.payoff` | This card shows what the game did to form, morale, bonds and cash. Form and morale change how players perform next time. | 22 | LESSON | same |
| `les.l8.tip` | The tip points at the most useful thing to fix before your next game. | 14 | LESSON | same |
| `lesson.offer` | New lesson: {title} (about a minute) | 6 | NOTE | same |
| `lesson.show` | Show me | 2 | BTN | not in spec |
| `lesson.later` | Later | 1 | BTN | not in spec |
| `lesson.new` | New | 1 | CHIP | not in spec |
| `lesson.done` | Done | 1 | CHIP | not in spec |
| `lesson.na` | Not available right now | 4 | NOTE | same |
| `lessons.title` | Lessons | 1 | TITLE | not in spec |
| `lessons.time` | About a minute | 3 | CHIP | not in spec |
| `lessons.start` | Start | 1 | BTN | not in spec |
| `lessons.opens_in_draft` | Opens during a draft | 4 | NOTE | not in spec |

### 4.5 Help sheet chrome

The sheet frame (TUTORIAL.md 5.1). `help.got_it` replaces `tip.got_it`.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `help.button` | Help | 1 | CHIP | not in spec |
| `help.got_it` | Got it | 2 | BTN | same |
| `help.see` | What you see | 3 | CHIP | not in spec |
| `help.do` | What to do | 3 | CHIP | not in spec |
| `help.know` | Good to know | 3 | CHIP | not in spec |
| `help.words` | Words on this screen | 4 | CHIP | same |
| `help.lesson` | Take the lesson | 3 | BTN | same |
| `help.glossary` | Open the glossary | 3 | BTN | same |

### 4.6 Help sheets (20 screens)

One title and three lines per screen (TUTORIAL.md 5.1), and the words chips as a comma-separated list of glossary ids (`.terms`; the Settings sheet has no words, so no key). `.terms` is a string because `Strings.t()` returns strings: the programmer splits it on commas. Where a sheet offers a lesson, the mapping is listed under the table.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `help.home.title` | Home | 1 | TITLE | not in spec |
| `help.home.see` | Your next match day, how you compare with the other club, and four summary tiles. | 15 | HELP | same |
| `help.home.do` | Tap Play game to start. Tap a tile to open that part of your club. | 15 | HELP | same |
| `help.home.know` | "Needs your attention" lists things to fix before you play, like tired starters. | 13 | HELP | same |
| `help.home.terms` | team_rating,patch,chemistry,form | - | REF | same |
| `help.squad.title` | Squad | 1 | TITLE | not in spec |
| `help.squad.see` | Your five starters on a small map, one per role, and the bench below. | 14 | HELP | same |
| `help.squad.do` | Tap a starter to change who plays that role. Tap a bench player to open their card. | 17 | HELP | same |
| `help.squad.know` | A player out of position loses rating. Pick best lineup for me fixes it in one tap. | 17 | HELP | changed |
| `help.squad.terms` | role,rating,fatigue,form,morale | - | REF | same |
| `help.player.title` | Player card | 2 | TITLE | not in spec |
| `help.player.see` | Tiredness, form and morale bars, the contract, bonds and best heroes. Stats and Career are one tap away. | 18 | HELP | changed |
| `help.player.do` | Tap Stats to read what each stat does. Renew a contract that is ending. | 14 | HELP | same |
| `help.player.know` | Potential is the most a stat can grow to. Young players grow fastest. | 13 | HELP | same |
| `help.player.terms` | potential,stats,contract,bonds | - | REF | same |
| `help.plan.title` | Plan | 1 | TITLE | not in spec |
| `help.plan.see` | Training, team chemistry, practice matches and your game plan status. | 10 | HELP | changed |
| `help.plan.do` | Tap a tile to open it. Check training before every match day. | 12 | HELP | same |
| `help.plan.know` | You set the game plan during each draft, after the picks, because it depends on the heroes. | 17 | HELP | changed |
| `help.plan.terms` | training_focus,chemistry,practice_match,game_plan | - | REF | same |
| `help.training.title` | Training | 1 | TITLE | not in spec |
| `help.training.see` | What every player works on until the next match day, and how tired your starters will be. | 17 | HELP | same |
| `help.training.do` | Tap a player to pick a stat, a hero, a team scrim or rest. | 14 | HELP | same |
| `help.training.know` | Training adds a little tiredness. Resting adds none and clears some. | 11 | HELP | same |
| `help.training.terms` | training_focus,fatigue,rest,scrim | - | REF | same |
| `help.chemistry.title` | Team chemistry | 2 | TITLE | not in spec |
| `help.chemistry.see` | The bonds between your five starters, who understands whom, languages and the bench. | 13 | HELP | same |
| `help.chemistry.do` | Look for weak pairs. Use team scrims in Training to build bonds. | 12 | HELP | same |
| `help.chemistry.know` | Swapping a starter costs chemistry until the new pairs have played together. | 12 | HELP | same |
| `help.chemistry.terms` | bonds,chemistry,understanding,scrim | - | REF | same |
| `help.practice.title` | Practice matches | 2 | TITLE | not in spec |
| `help.practice.see` | Quick Match and Exhibition. They never count for the table or Form Rating. | 13 | HELP | same |
| `help.practice.do` | Play a Quick Match for a fast game. Choose Exhibition for a club and a series length. | 17 | HELP | same |
| `help.practice.know` | One practice series per match day. Starters get a little tired and bond a little. | 15 | HELP | same |
| `help.practice.terms` | practice_match,quick_match,exhibition | - | REF | same |
| `help.prematch.title` | Match day | 2 | TITLE | not in spec |
| `help.prematch.see` | Your club against theirs, role by role, with each player's rating in that role. | 14 | HELP | same |
| `help.prematch.do` | Check the rows, rest tired starters if offered, then tap Start draft. | 12 | HELP | same |
| `help.prematch.know` | Tired starters play below their rating. "Auto-play this game" skips the watching. | 12 | HELP | same |
| `help.prematch.terms` | rating,role,fatigue,draft | - | REF | same |
| `help.draft.title` | Draft | 1 | TITLE | not in spec |
| `help.draft.see` | Whose turn it is, you on the left and them on the right, and the heroes you can choose. | 19 | HELP | same |
| `help.draft.do` | Ban heroes their players know best. Pick heroes your players know and that fit the role. | 16 | HELP | same |
| `help.draft.know` | If the timer runs out the Coach chooses for you. Auto-finish hands the draft to the Coach. | 17 | HELP | same |
| `help.draft.terms` | coach,ban,pick,familiarity,fit,patch_strength,composition | - | REF | same |
| `help.gameplan.title` | Game plan | 2 | TITLE | not in spec |
| `help.gameplan.see` | Your expected edge on top, then settings for each phase: fights, tempo, objectives, lanes, support and risk. | 17 | HELP | same |
| `help.gameplan.do` | Tap a stop on a track to change it. Tap Coach to see a suggested plan. | 16 | HELP | same |
| `help.gameplan.know` | Edge is before luck. Risk helps the underdog and hurts the favourite. Your plan is kept for the next game. | 20 | HELP | same |
| `help.gameplan.terms` | coach,edge,game_plan,risk,objective,teamfight | - | REF | same |
| `help.match.title` | Match | 1 | TITLE | not in spec |
| `help.match.see` | The clock, kills, towers and who is ahead, with each result shown as it is decided. | 16 | HELP | changed |
| `help.match.do` | Watch, tap Speed x2 to go faster, or Skip to the end. | 12 | HELP | same |
| `help.match.know` | The result was decided before you watched, so watching or skipping never changes it. | 14 | HELP | same |
| `help.match.terms` | lane,objective,teamfight,base | - | REF | changed |
| `help.report.title` | Match report | 2 | TITLE | not in spec |
| `help.report.see` | The result, the standout player, what the game changed, one tip, and why it went this way. | 17 | HELP | same |
| `help.report.do` | Tap the big number to see why this happened. Tap Continue when done. | 13 | HELP | changed |
| `help.report.know` | Luck is a factor. A big luck share means the game could have gone either way. | 16 | HELP | changed |
| `help.report.terms` | margin,standout,luck,form,morale,bonds | - | REF | same |
| `help.club.title` | Club | 1 | TITLE | not in spec |
| `help.club.see` | Money, the league table, Form Rating and free agents, each with one line of status. | 15 | HELP | same |
| `help.club.do` | Tap a tile to open it. | 6 | HELP | same |
| `help.club.know` | If cash stays below zero too long, the board dismisses you. | 11 | HELP | changed |
| `help.club.terms` | cash,form_rating,free_agent | - | REF | same |
| `help.standings.title` | Standings | 1 | TITLE | not in spec |
| `help.standings.see` | The league table with a podium, the playoff bracket, and your history of games and trophies. | 16 | HELP | same |
| `help.standings.do` | Tap Table, Playoffs or History. Tap Points or Form Rating to change the ranking. Your club says YOU. | 18 | HELP | changed |
| `help.standings.know` | A win is worth 3 points. Ties go to head-to-head wins, then total margin. | 14 | HELP | same |
| `help.standings.terms` | table,form_rating,playoffs,best_of | - | REF | same |
| `help.finance.title` | Finance | 1 | TITLE | not in spec |
| `help.finance.see` | Your cash, weekly income and wages, the sponsor and every payment. | 11 | HELP | same |
| `help.finance.do` | Pick a sponsor before your first game of the season. Watch the wage cap. | 14 | HELP | same |
| `help.finance.know` | Wages are paid every round. Over the cap, signings are blocked. | 11 | HELP | same |
| `help.finance.terms` | cash,wage,wage_cap,sponsor | - | REF | same |
| `help.freeagents.title` | Free agents | 2 | TITLE | not in spec |
| `help.freeagents.see` | Players with no club, with rating, potential and the wage they ask. | 12 | HELP | same |
| `help.freeagents.do` | Filter by role, sort by what matters, tap a player to talk. | 12 | HELP | same |
| `help.freeagents.know` | Your squad has a limit. A signing needs cash for the fee and room under the wage cap. | 18 | HELP | same |
| `help.freeagents.terms` | free_agent,potential,signing_fee,wage_cap | - | REF | same |
| `help.negotiation.title` | Contract talks | 2 | TITLE | not in spec |
| `help.negotiation.see` | The player, what a deal does to your wages, cap and cash, and your offers left. | 16 | HELP | same |
| `help.negotiation.do` | Set the wage and length, then tap Make offer. | 9 | HELP | changed |
| `help.negotiation.know` | What a player will accept is secret. A temperamental player walks away after two refusals. | 15 | HELP | same |
| `help.negotiation.terms` | contract,wage,personality,signing_fee | - | REF | same |
| `help.season.title` | Season summary | 2 | TITLE | not in spec |
| `help.season.see` | How the season ended, your history, who grew, and contracts that end now. | 13 | HELP | same |
| `help.season.do` | Renew players you want to keep before starting the next season. | 11 | HELP | same |
| `help.season.know` | A player with an ended contract leaves when the new season starts. | 12 | HELP | same |
| `help.season.terms` | contract,potential,playoffs | - | REF | same |
| `help.settings.title` | Settings | 1 | TITLE | not in spec |
| `help.settings.see` | Quick mode, animations, comfort options, help and learning, feedback and the save. | 12 | HELP | same |
| `help.settings.do` | Try the Comfort options, such as larger text. Replay the tutorial any time. | 13 | HELP | changed |
| `help.settings.know` | Your game is saved only on this device. | 8 | HELP | same |
| `help.clubselect.title` | Choose your club | 3 | TITLE | not in spec |
| `help.clubselect.see` | Every club with its team rating, strength tier and rank. | 10 | HELP | changed |
| `help.clubselect.do` | Pick the club you will manage. The middle of the table is a fair first choice. | 16 | HELP | same |
| `help.clubselect.know` | Starting a new game later lets you try another club. | 10 | HELP | same |
| `help.clubselect.terms` | team_rating,rating | - | REF | same |

Lessons offered from a help sheet (the "Take the lesson" button, data for the programmers, not a string): standings: standings (L1); training: training (L2); player: contracts (L3); season: contracts (L3); chemistry: chemistry (L4); gameplan: gameplan (L5); finance: money (L6); freeagents: freeagents (L7); report: payoff (L8).

### 4.7 Glossary chrome

Group chips and screen labels. The 49 terms follow.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `gl.title` | Glossary | 1 | TITLE | not in spec |
| `gl.group.players` | Players | 1 | CHIP | not in spec |
| `gl.group.match` | Match and draft | 3 | CHIP | not in spec |
| `gl.group.league` | League | 1 | CHIP | not in spec |
| `gl.group.club` | Club and money | 3 | CHIP | not in spec |
| `gl.where` | Where to see it | 4 | BTN | not in spec |

### 4.8 Glossary terms (49)

Keys `gl.<id>.name`, `.def` and `.where` (the help sheet id that "Where to see it" opens). Definitions use neutral pronouns ("their", "they") because players can be any gender.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `gl.team_rating.name` | Team rating | 2 | CHIP | changed |
| `gl.team_rating.def` | The average skill of your five starters in the roles they play. It leaves out form, tiredness and heroes. | 19 | GLOSS | same |
| `gl.team_rating.where` | home | - | REF | not in spec |
| `gl.rating.name` | Rating | 1 | CHIP | same |
| `gl.rating.def` | A player's skill in one role, built from their stats. Playing out of position lowers it. | 16 | GLOSS | changed |
| `gl.rating.where` | squad | - | REF | not in spec |
| `gl.role.name` | Role | 1 | CHIP | same |
| `gl.role.def` | A player's job on the team: Top, Jungle, Mid, Bot Carry or Support. | 13 | GLOSS | same |
| `gl.role.where` | squad | - | REF | not in spec |
| `gl.stats.name` | Stats | 1 | CHIP | same |
| `gl.stats.def` | The eight skills that make up a rating. Tap a stat on a player card to read what it does. | 20 | GLOSS | same |
| `gl.stats.where` | player | - | REF | not in spec |
| `gl.potential.name` | Potential | 1 | CHIP | same |
| `gl.potential.def` | The most a player can grow to in a stat. Young players with high potential become stars but ask for more money. | 22 | GLOSS | changed |
| `gl.potential.where` | player | - | REF | not in spec |
| `gl.form.name` | Form | 1 | CHIP | same |
| `gl.form.def` | How well a player has done lately. Results move it, and it fades over the days. A player in form plays better. | 22 | GLOSS | same |
| `gl.form.where` | squad | - | REF | not in spec |
| `gl.morale.name` | Morale | 1 | CHIP | same |
| `gl.morale.def` | How happy a player is. Results and playing time raise it. A starter who sits out for a while gets unhappy. | 21 | GLOSS | changed |
| `gl.morale.where` | squad | - | REF | not in spec |
| `gl.fatigue.name` | Fatigue | 1 | CHIP | same |
| `gl.fatigue.def` | Tiredness from playing. Tired starters lose rating, shown as worn, tired or exhausted. | 13 | GLOSS | same |
| `gl.fatigue.where` | squad | - | REF | not in spec |
| `gl.bonds.name` | Bonds | 1 | CHIP | same |
| `gl.bonds.def` | How well two players know each other. They grow when the pair plays together. A new teammate starts low. | 19 | GLOSS | same |
| `gl.bonds.where` | chemistry | - | REF | not in spec |
| `gl.understanding.name` | Understanding | 1 | CHIP | same |
| `gl.understanding.def` | How clearly one player takes in what a teammate says. Bond, Communication and a shared language all help. | 18 | GLOSS | same |
| `gl.understanding.where` | chemistry | - | REF | not in spec |
| `gl.chemistry.name` | Chemistry | 1 | CHIP | same |
| `gl.chemistry.def` | Your five starters' bonds and understanding, turned into a small rating bonus for the whole team. | 16 | GLOSS | same |
| `gl.chemistry.where` | chemistry | - | REF | not in spec |
| `gl.personality.name` | Personality | 1 | CHIP | same |
| `gl.personality.def` | How a player behaves in talks: Professional, Balanced, Casual or Temperamental. | 11 | GLOSS | same |
| `gl.personality.where` | negotiation | - | REF | not in spec |
| `gl.training_focus.name` | Training focus | 2 | CHIP | same |
| `gl.training_focus.def` | What a player works on between match days: one stat, a hero, a team scrim or rest. | 17 | GLOSS | same |
| `gl.training_focus.where` | plan | - | REF | not in spec |
| `gl.rest.name` | Rest | 1 | CHIP | same |
| `gl.rest.def` | A training choice that adds no tiredness and clears some. Use it for a worn starter. | 16 | GLOSS | same |
| `gl.rest.where` | training | - | REF | not in spec |
| `gl.scrim.name` | Team scrim | 2 | CHIP | same |
| `gl.scrim.def` | A practice week that builds bonds a little faster. It adds no stat growth. | 14 | GLOSS | same |
| `gl.scrim.where` | training | - | REF | not in spec |
| `gl.coach.name` | Coach | 1 | CHIP | same |
| `gl.coach.def` | Your club's helper. It suggests bans, picks, game plans and training. You always decide. | 14 | GLOSS | same |
| `gl.coach.where` | draft | - | REF | not in spec |
| `gl.draft.name` | Draft | 1 | CHIP | same |
| `gl.draft.def` | Before each game both teams take turns to ban and pick heroes. If the timer runs out, the Coach chooses. | 20 | GLOSS | changed |
| `gl.draft.where` | draft | - | REF | not in spec |
| `gl.ban.name` | Ban | 1 | CHIP | same |
| `gl.ban.def` | Removing a hero so neither team can use it. Ban the heroes their players know best. | 16 | GLOSS | same |
| `gl.ban.where` | draft | - | REF | not in spec |
| `gl.pick.name` | Pick | 1 | CHIP | same |
| `gl.pick.def` | Choosing a hero for one of your players. Each hero plays one role. | 13 | GLOSS | same |
| `gl.pick.where` | draft | - | REF | not in spec |
| `gl.hero.name` | Hero | 1 | CHIP | same |
| `gl.hero.def` | The character a player controls. Each has a style, strengths and a role it suits. | 15 | GLOSS | same |
| `gl.hero.where` | draft | - | REF | not in spec |
| `gl.familiarity.name` | Familiarity | 1 | CHIP | same |
| `gl.familiarity.def` | How well a player knows a hero. Higher means better play. It grows a little after each real game. | 19 | GLOSS | changed |
| `gl.familiarity.where` | draft | - | REF | not in spec |
| `gl.fit.name` | Fit | 1 | CHIP | same |
| `gl.fit.def` | How well a hero suits the role it is given. 100 percent is perfect and less costs rating. | 18 | GLOSS | same |
| `gl.fit.where` | draft | - | REF | not in spec |
| `gl.patch_strength.name` | Patch strength | 2 | CHIP | same |
| `gl.patch_strength.def` | How strong a hero is in the current patch. Strong heroes are the better choice. | 15 | GLOSS | changed |
| `gl.patch_strength.where` | draft | - | REF | not in spec |
| `gl.patch.name` | Patch | 1 | CHIP | same |
| `gl.patch.def` | A balance update that changes which heroes are strong. Home shows the current one, like P1. | 16 | GLOSS | same |
| `gl.patch.where` | home | - | REF | not in spec |
| `gl.composition.name` | Composition | 1 | CHIP | same |
| `gl.composition.def` | How your five heroes work together. It has a style, such as Dive or Siege, and gives a bonus or a penalty. | 22 | GLOSS | same |
| `gl.composition.where` | draft | - | REF | not in spec |
| `gl.game_plan.name` | Game plan | 2 | CHIP | changed |
| `gl.game_plan.def` | Your instructions for how the team plays: fights, tempo, objectives, lanes, support and risk. You set it after the draft. | 20 | GLOSS | same |
| `gl.game_plan.where` | gameplan | - | REF | not in spec |
| `gl.edge.name` | Expected edge | 2 | CHIP | same |
| `gl.edge.def` | Your advantage before luck, from ratings, heroes and plan. Luck can still change a single game. | 16 | GLOSS | same |
| `gl.edge.where` | gameplan | - | REF | not in spec |
| `gl.risk.name` | Risk | 1 | CHIP | same |
| `gl.risk.def` | How swingy you want the game. More risk helps the underdog and hurts the favourite. | 15 | GLOSS | same |
| `gl.risk.where` | gameplan | - | REF | not in spec |
| `gl.lane.name` | Lane | 1 | CHIP | same |
| `gl.lane.def` | One of the three paths between the bases: Top, Mid and Bot. The Jungle is the space between them. | 19 | GLOSS | changed |
| `gl.lane.where` | match | - | REF | not in spec |
| `gl.objective.name` | Objective | 1 | CHIP | same |
| `gl.objective.def` | A big neutral target in the middle or late game. Winning it gives your team a lead. | 17 | GLOSS | same |
| `gl.objective.where` | gameplan | - | REF | not in spec |
| `gl.teamfight.name` | Teamfight | 1 | CHIP | same |
| `gl.teamfight.def` | A fight with all five players. The mid and late fights often decide the game. | 15 | GLOSS | same |
| `gl.teamfight.where` | match | - | REF | not in spec |
| `gl.base.name` | Base | 1 | CHIP | same |
| `gl.base.def` | The main building. The team that destroys the enemy base wins the game. | 13 | GLOSS | same |
| `gl.base.where` | match | - | REF | not in spec |
| `gl.margin.name` | Margin | 1 | CHIP | same |
| `gl.margin.def` | How big a result was: narrow, clear or decisive. | 9 | GLOSS | same |
| `gl.margin.where` | report | - | REF | not in spec |
| `gl.standout.name` | Standout | 1 | CHIP | same |
| `gl.standout.def` | The player whose role moved the result most for your team. | 11 | GLOSS | same |
| `gl.standout.where` | report | - | REF | not in spec |
| `gl.luck.name` | Luck | 1 | CHIP | same |
| `gl.luck.def` | The random part of every game that no plan or draft controls. The report shows how much it moved the result. | 21 | GLOSS | changed |
| `gl.luck.where` | report | - | REF | not in spec |
| `gl.table.name` | League table | 2 | CHIP | same |
| `gl.table.def` | Clubs ranked by points. A win is worth 3. Ties go to head-to-head wins, then total margin. | 17 | GLOSS | same |
| `gl.table.where` | standings | - | REF | not in spec |
| `gl.form_rating.name` | Form Rating | 2 | CHIP | same |
| `gl.form_rating.def` | A running skill score for every club. Beating strong clubs in big games lifts it most. Practice games never count. | 20 | GLOSS | changed |
| `gl.form_rating.where` | standings | - | REF | not in spec |
| `gl.playoffs.name` | Playoffs | 1 | CHIP | same |
| `gl.playoffs.def` | After the league rounds, the best clubs play short series for the title. | 13 | GLOSS | same |
| `gl.playoffs.where` | standings | - | REF | not in spec |
| `gl.best_of.name` | Best of | 2 | CHIP | same |
| `gl.best_of.def` | A series won by the first side to take most of the games. Best of 3 needs two wins. | 19 | GLOSS | same |
| `gl.best_of.where` | standings | - | REF | not in spec |
| `gl.practice_match.name` | Practice match | 2 | CHIP | same |
| `gl.practice_match.def` | A game that never counts for the table, Form Rating, form, morale or sponsor goals. | 15 | GLOSS | same |
| `gl.practice_match.where` | practice | - | REF | not in spec |
| `gl.quick_match.name` | Quick Match | 2 | CHIP | same |
| `gl.quick_match.def` | One practice game against a club close to your strength. | 10 | GLOSS | same |
| `gl.quick_match.where` | practice | - | REF | not in spec |
| `gl.exhibition.name` | Exhibition | 1 | CHIP | same |
| `gl.exhibition.def` | A practice series against any club you choose: best of 1, 3 or 5. | 14 | GLOSS | same |
| `gl.exhibition.where` | practice | - | REF | not in spec |
| `gl.contract.name` | Contract | 1 | CHIP | same |
| `gl.contract.def` | A player's deal: a weekly wage and a number of seasons. When it ends, the player leaves unless you renew. | 20 | GLOSS | changed |
| `gl.contract.where` | negotiation | - | REF | not in spec |
| `gl.wage.name` | Wage | 1 | CHIP | same |
| `gl.wage.def` | What a player is paid each week. Wages are paid every round. | 12 | GLOSS | same |
| `gl.wage.where` | finance | - | REF | not in spec |
| `gl.wage_cap.name` | Wage cap | 2 | CHIP | same |
| `gl.wage_cap.def` | The most you can pay players each week. A signing that goes over it is blocked. | 16 | GLOSS | same |
| `gl.wage_cap.where` | finance | - | REF | not in spec |
| `gl.cash.name` | Cash | 1 | CHIP | same |
| `gl.cash.def` | Your club's money. If it stays below zero too long, the board dismisses you. | 14 | GLOSS | same |
| `gl.cash.where` | finance | - | REF | not in spec |
| `gl.sponsor.name` | Sponsor | 1 | CHIP | same |
| `gl.sponsor.def` | A partner that pays a weekly retainer and a bonus for hitting a target such as wins or a playoff place. | 21 | GLOSS | same |
| `gl.sponsor.where` | finance | - | REF | not in spec |
| `gl.free_agent.name` | Free agent | 2 | CHIP | same |
| `gl.free_agent.def` | A player with no club. You can sign them if you have cash, squad room and room under the wage cap. | 21 | GLOSS | changed |
| `gl.free_agent.where` | club | - | REF | not in spec |
| `gl.signing_fee.name` | Signing fee | 2 | CHIP | same |
| `gl.signing_fee.def` | A one-off payment to sign a player: two weeks of their wage. | 12 | GLOSS | changed |
| `gl.signing_fee.where` | freeagents | - | REF | not in spec |

### 4.9 Settings: Help and learning

TUTORIAL.md 6.3. `settings.tips_again` and `settings.tips_done` are retired by `settings.help_reset` and `settings.help_reset_done`.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `settings.help_h` | Help and learning | 3 | TITLE | same |
| `settings.replay` | Replay the guided first game | 5 | LABEL | same |
| `settings.replay_confirm` | Replay the guided first game? It is a practice game. Nothing in your save changes. | 15 | NOTE | same |
| `settings.replay_yes` | Replay it | 2 | BTN | same |
| `settings.lessons` | Lessons | 1 | BTN | same |
| `settings.glossary` | Glossary | 1 | BTN | same |
| `settings.help_reset` | Show help hints again | 4 | BTN | same |
| `settings.help_reset_done` | Help hints will show again. | 5 | TOAST | same |

### 4.10 Draft

UI-PASS-2 6.3 and 7.4. Header titles are sentence case and fit the 200 px room (141 to 161 px, measured by the Art Director). `draft.side.*` are side names shown with a flag icon, the only place besides `hub.side.*` where a colour word is a proper name.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `draft.title.your_ban` | Your ban | 2 | TITLE | not in spec |
| `draft.title.your_pick` | Your pick | 2 | TITLE | not in spec |
| `draft.title.their_ban` | Their ban | 2 | TITLE | not in spec |
| `draft.title.their_pick` | Their pick | 2 | TITLE | not in spec |
| `draft.coach_suggests` | Coach suggests: {hero} | 3 | LABEL | not in spec |
| `draft.coach_take` | Take | 1 | BTN | not in spec |
| `draft.auto_rest` | Auto-finish | 1 | BTN | replaces existing; not in spec |
| `draft.auto_sure` | Sure? | 1 | BTN | not in spec |
| `draft.timeout_toast` | Time is up: Coach picked {hero} | 6 | TOAST | not in spec |
| `draft.timeout_toast_ban` | Time is up: Coach banned {hero} | 6 | TOAST | not in spec |
| `draft.leave.h` | Leave the draft? | 3 | TITLE | not in spec |
| `draft.leave.body` | A draft in progress is not saved. | 7 | NOTE | not in spec |
| `draft.leave.stay` | Stay | 1 | BTN | not in spec |
| `draft.leave.go` | Leave | 1 | BTN | not in spec |
| `draft.filter.all` | All | 1 | CHIP | not in spec |
| `draft.side.blue` | Blue | 1 | CHIP | not in spec |
| `draft.side.red` | Red | 1 | CHIP | not in spec |
| `draft.club_turn` | {club} is choosing a {what}... | 6 | LABEL | not in spec |
| `draft.slot_open` | Open | 1 | CHIP | not in spec |
| `draft.sheet.plays_as` | Plays as | 2 | CHIP | not in spec |
| `draft.sheet.best` | best | 1 | CHIP | not in spec |
| `draft.sheet.power` | Power | 1 | CHIP | not in spec |
| `draft.sheet.strong_vs` | Strong against | 2 | CHIP | not in spec |
| `draft.sheet.difficulty` | Difficulty | 1 | CHIP | not in spec |
| `draft.sheet.pick_for` | Pick for {role} - {name} | 5 | LABEL | not in spec |
| `draft.sheet.ban` | Ban {hero} | 2 | BTN | not in spec |
| `draft.net_edge` | Net edge for you from the draft: {v} | 8 | NOTE | not in spec |
| `draft.meta_hint` | An up arrow means strong in this patch, a down arrow means weak. Numbers are player familiarity. | 17 | NOTE | replaces existing; not in spec |

### 4.11 Game plan, plan switch banners, Coach preview

UI-PASS-2 6.4, 7.4 and ACTION-VOCABULARY P3. The five `gp.switch.short.<id>` strings are at most 4 words and all read the same way. `gp.trigger_late_only` differs from the UI-PASS-2 draft: the If behind and If ahead plans apply from the mid-game on (`les.l5.plan`, `gp.trigger_hint.*`), so the caption says that, not "late-game". The eighth control, Jungle focus, is a segmented control (None, Top, Mid, Bot: `gp.jf.*`) with no end labels, so there are 7 end-label pairs.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `gp.switch.short.behind_early` | Plan switch: If behind | 4 | BANNER | not in spec |
| `gp.switch.short.ahead_early` | Plan switch: If ahead | 4 | BANNER | not in spec |
| `gp.switch.short.vs_dive` | Plan switch: vs Dive | 4 | BANNER | not in spec |
| `gp.switch.short.vs_siege` | Plan switch: vs Siege | 4 | BANNER | not in spec |
| `gp.switch.short.vs_protect` | Plan switch: vs Protect | 4 | BANNER | not in spec |
| `gp.end.g.neg` | Spread out | 2 | END | not in spec |
| `gp.end.g.pos` | Group up | 2 | END | not in spec |
| `gp.end.t.neg` | Push early | 2 | END | not in spec |
| `gp.end.t.pos` | Play for late | 3 | END | not in spec |
| `gp.end.m.neg` | Ignore | 1 | END | not in spec |
| `gp.end.m.pos` | Contest | 1 | END | not in spec |
| `gp.end.l.neg` | Fight first | 2 | END | not in spec |
| `gp.end.l.pos` | Secure | 1 | END | not in spec |
| `gp.end.a.neg` | Cautious | 1 | END | not in spec |
| `gp.end.a.pos` | Aggressive | 1 | END | not in spec |
| `gp.end.s.neg` | Stay close | 2 | END | not in spec |
| `gp.end.s.pos` | Roam | 1 | END | not in spec |
| `gp.end.r.neg` | Play safe | 2 | END | not in spec |
| `gp.end.r.pos` | Take risks | 2 | END | not in spec |
| `gp.phase.overall` | Overall | 1 | CHIP | not in spec |
| `gp.phase.early` | Early | 1 | CHIP | not in spec |
| `gp.phase.mid` | Mid | 1 | CHIP | not in spec |
| `gp.phase.late` | Late | 1 | CHIP | not in spec |
| `gp.contest.top` | Top | 1 | CHIP | not in spec |
| `gp.contest.mid` | Mid | 1 | CHIP | not in spec |
| `gp.contest.bot` | Bot | 1 | CHIP | not in spec |
| `gp.contest.jungle` | Jungle | 1 | CHIP | not in spec |
| `gp.contest.obj` | Objective | 1 | CHIP | not in spec |
| `gp.contest.fight` | Fight | 1 | CHIP | not in spec |
| `gp.lead` | lead {n}/{m} | 2 | CHIP | not in spec |
| `gp.pips` | Moves: {phases} | 2 | CAPTION | not in spec |
| `gp.trigger_locked` | Uses your Default plan | 4 | CAPTION | not in spec |
| `gp.trigger_late_only` | Only the part from the mid-game on applies in this plan. | 11 | NOTE | not in spec |
| `gp.coach.h` | Coach's plan | 2 | TITLE | not in spec |
| `gp.coach.change` | {control}: {from} to {to} | 4 | CAPTION | not in spec |
| `gp.coach.edge` | Expected edge: {from} to {to} | 5 | CAPTION | not in spec |
| `gp.coach.apply` | Apply | 1 | BTN | not in spec |
| `gp.coach.close` | Close | 1 | BTN | not in spec |
| `gp.coach.none` | No changes needed. Your plan already suits this matchup. | 9 | NOTE | not in spec |
| `gp.toast.applied` | Coach's plan applied. | 3 | TOAST | not in spec |
| `gp.toast.reset` | Plan reset. | 2 | TOAST | not in spec |
| `gp.coach` | Coach | 1 | BTN | replaces existing; not in spec |
| `gp.c.t.pos` | Play for late: stronger late game, weaker lanes | 8 | NOTE | replaces existing; not in spec |

### 4.12 Match report

UI-PASS-2 6.6 and 7.4. The eight story tags are written from the Manager's side and say only what the phase signs say; they never claim a winner (a side can lead early and mid and still lose, so no tag says won or lost the game). Patterns are early, mid, late, plus for ahead. Hero-stat sentences assume the report knows whether the top factor helped or hurt (`report.helped` and `report.hurt` already do).

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `report.story_h` | How the game went | 4 | TITLE | not in spec |
| `report.story.ppp` | Ahead in every phase | 4 | TAG | not in spec |
| `report.story.ppm` | Ahead, then lost the late game | 6 | TAG | not in spec |
| `report.story.pmp` | Ahead early and late, behind mid-game | 6 | TAG | not in spec |
| `report.story.pmm` | Led early, then lost control | 5 | TAG | not in spec |
| `report.story.mpp` | Slow start, then you took over | 6 | TAG | not in spec |
| `report.story.mpm` | Behind early, ahead only in the middle | 7 | TAG | not in spec |
| `report.story.mmp` | Behind until the late game | 5 | TAG | not in spec |
| `report.story.mmm` | Behind in every phase | 4 | TAG | not in spec |
| `report.hero.help` | {what} helped most. It decided {pct}% of the result. | 9 | SENT | not in spec |
| `report.hero.hurt` | {what} cost you most. It decided {pct}% of the result. | 10 | SENT | not in spec |
| `report.hero.luck_for` | Luck helped you. {pct}% of this result was luck, the random part of every game. | 15 | SENT | not in spec |
| `report.hero.luck_against` | Luck was against you. {pct}% of this result was luck, the random part of every game. | 16 | SENT | not in spec |
| `report.luck_note` | Luck is the random part of every game, the part no plan or draft controls. | 15 | NOTE | not in spec |
| `report.all_factors` | All factors | 2 | BTN | not in spec |
| `report.why_sheet_h` | Why this happened | 3 | TITLE | not in spec |
| `report.dig_h` | More detail | 2 | BTN | not in spec |
| `report.dig.players` | Players | 1 | CHIP | not in spec |
| `report.dig.moments` | Moments | 1 | CHIP | not in spec |
| `report.dig.draft` | Draft | 1 | CHIP | not in spec |
| `report.tip.open_squad` | Open squad | 2 | BTN | not in spec |
| `report.best_factor` | Best | 1 | CHIP | not in spec |
| `report.worst_factor` | Worst | 1 | CHIP | not in spec |

### 4.13 Standings and History (including the Points / Form switch label)

UI-PASS-2 6.5 and 7.4. The switch says **Points** and **Form Rating**, never "Form": a player's form (recent performance) and a club's Form Rating are different things (TUTORIAL.md 11), and tut.form_switch, les.l1.metric and help.standings already say Form Rating. The cut-line sentences use four states, which Systems or the programmers must map: `in` (rank 1 to 4 and ahead of 5th), `on` (level on points with 4th), `out` (below the line) and `after` (the league rounds are over). `{n}` is a points gap computed by `GameState.cut_gap()`.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `standings.view.table` | Table | 1 | CHIP | not in spec |
| `standings.view.playoffs` | Playoffs | 1 | CHIP | not in spec |
| `standings.view.history` | History | 1 | CHIP | not in spec |
| `standings.table_h` | League table | 2 | TITLE | not in spec |
| `standings.metric.points` | Points | 1 | CHIP | not in spec |
| `standings.metric.form` | Form Rating | 2 | CHIP | not in spec |
| `standings.you` | YOU | 1 | CHIP | not in spec |
| `standings.playoff_line` | Playoff line (top 4) | 4 | CAPTION | not in spec |
| `standings.cut.in` | Top 4 go through. You are #{rank}, {n} pts clear of 5th. | 12 | SENT | not in spec |
| `standings.cut.on` | Top 4 go through. You are #{rank}, level on points with the line. | 13 | SENT | not in spec |
| `standings.cut.out` | Top 4 go through. You are #{rank}, {n} pts behind the line. | 12 | SENT | not in spec |
| `standings.cut.after` | The league rounds are over. The top 4 are in the playoffs. | 12 | SENT | not in spec |
| `standings.pin.in` | Safe: {n} pts clear of 5th | 6 | CAPTION | not in spec |
| `standings.pin.on` | On the line with 4th place | 6 | CAPTION | not in spec |
| `standings.pin.out` | {n} pts behind the line | 5 | CAPTION | not in spec |
| `standings.bracket.sf` | Semi-finals | 1 | TITLE | not in spec |
| `standings.bracket.final` | Grand final | 2 | TITLE | not in spec |
| `standings.bracket.bo` | Best of {bo} | 3 | CAPTION | not in spec |
| `standings.bracket.winner_of` | Winner of {id} | 3 | CAPTION | not in spec |
| `standings.bracket.ghost` | If the season ended now | 5 | CAPTION | not in spec |
| `history.recent_h` | Recent games | 2 | TITLE | not in spec |
| `history.chip.titles` | Titles | 1 | CHIP | not in spec |
| `history.chip.finals` | Finals | 1 | CHIP | not in spec |
| `history.chip.playoffs` | Playoffs | 1 | CHIP | not in spec |
| `history.chip.prize` | Prize money | 2 | CHIP | not in spec |
| `empty.history.h` | No games yet | 3 | EMPTY_H | not in spec |
| `empty.history.b` | Your first result will show up here. | 7 | EMPTY_B | not in spec |
| `empty.history.btn` | Go to Home | 3 | BTN | not in spec |

### 4.14 Home, Squad, Match and the other empty states

UI-PASS-2 6.1, 6.2, 6.7 and 7.4. `squad.swap_note` is shown when the chosen player already starts in another role, so the two swap; check against the real picker.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `home.up_next` | Up next | 2 | TITLE | not in spec |
| `home.see_all` | See all | 2 | BTN | not in spec |
| `home.preview_h` | Match preview | 2 | TITLE | not in spec |
| `home.fav` | Favoured | 1 | CHIP | not in spec |
| `home.even` | Even | 1 | CHIP | not in spec |
| `home.underdog` | Underdog | 1 | CHIP | not in spec |
| `empty.upnext.h` | No more league games | 4 | EMPTY_H | not in spec |
| `empty.upnext.b` | All league games are played. Check Standings for the playoffs. | 10 | EMPTY_B | not in spec |
| `empty.upnext.btn` | Open Standings | 2 | BTN | not in spec |
| `squad.find` | Find a player | 3 | BTN | not in spec |
| `squad.delta` | Team {delta} | 2 | CHIP | not in spec |
| `squad.now_playing` | Playing now | 2 | CHIP | not in spec |
| `squad.bench_h` | Bench | 1 | TITLE | not in spec |
| `squad.swap_note` | {name} already starts, so you two will swap roles. | 9 | NOTE | not in spec |
| `squad.toast.moved` | {name} now plays {role} | 4 | TOAST | not in spec |
| `squad.toast.auto` | Best lineup set. | 3 | TOAST | not in spec |
| `match.phase.early` | Early | 1 | CHIP | not in spec |
| `match.phase.mid` | Mid | 1 | CHIP | not in spec |
| `match.phase.late` | Late | 1 | CHIP | not in spec |
| `feed.t.jungle` | Jungle | 1 | LABEL | replaces existing; not in spec |

### 4.15 Coach and Manager rename, About, Licences, feedback note

The strings that change because the helper is Coach and the player is Manager (TUTORIAL.md 13), the stale About text, the font credit, and interim replacements for retired strings so that no merged string has a forbidden word before the code stops using it. `about.included.b`, `about.test.b` and `about.limits.b` describe Alpha 0.7 as specified in ALPHA-0.7-PLAN W1; the Producer must re-read them against what actually ships. The font credit is my wording from ART-BIBLE 5.1 (copyright line read from the font files); the IP & Originality Checker confirms it.

| Key | Text | Words | Rule | vs spec |
|---|---|---|---|---|
| `club.pick.hint` | You are the Manager. Your Coach helps, but you decide. Players pick their own heroes; you steer the draft and set the lineup. | 23 | NOTE | replaces existing; not in spec |
| `draft.recommended` | Take Coach's choice: {hero} | 4 | BTN | replaces existing; not in spec |
| `tip.prematch` | Rows show where you are stronger or weaker. Tired starters play worse, so rest or rotate them. Next comes the draft: bans and picks run on a short timer, and if it runs out the Coach chooses for you. | 39 | BODY | replaces existing; not in spec |
| `about.title` | About Alpha 0.7 | 3 | TITLE | replaces existing; not in spec |
| `about.included.b` | One full single-player season: pick a club, set your lineup and training, draft heroes against the clock, set your game plan, watch the match, read the report. 10 clubs, 18 league rounds, then a top-4 playoff. You also run the money, sign and renew players, and build team chemistry. New in this build: a guided first game, a ? help button on every screen, lessons and a glossary. Your progress saves automatically. | 72 | BODY | replaces existing; not in spec |
| `about.test.b` | New in this build: the guided first game, help on every screen, lessons and the glossary. Did you know what to do next without asking anyone? Which step slowed you down? Is a game still about 5 minutes with the draft? Anything confusing, slow or broken? | 46 | BODY | replaces existing; not in spec |
| `about.limits.b` | Transfers between clubs and youth intake. The live match arena comes in Alpha 0.8. Hero and player names are placeholders. | 20 | BODY | replaces existing; not in spec |
| `about.licences.h` | Licences | 1 | TITLE | not in spec |
| `about.licences.font` | Text font: Barlow Semi Condensed. Copyright 2017 The Barlow Project Authors. Used under the SIL Open Font License 1.1. | 19 | NOTE | not in spec |
| `feedback.template` | Feedback for Gloamline alpha\n\nWhat I was doing:\n\nWhat happened:\n\nWhat I expected:\n\n--- details for the developer ---\n{info} | 20 | BODY | replaces existing; not in spec |
| `plan.gp.h` | Game plan | 2 | TITLE | replaces existing; not in spec |
| `plan.gp.body` | You set the game plan during each draft, after the picks, because it depends on the heroes. Your choices are saved for the next game. | 25 | NOTE | replaces existing; not in spec |
| `tag.scaling` | strong late | 2 | CHIP | replaces existing; not in spec |

### 4.16 Quick index: empty states, toasts, banners

- **Empty states** (title, helper, button): `empty.history.*`, `empty.upnext.*`. Existing empty states left as they are: `standings.no_results`, `trophies.none`, `career.none`, `fa.none`, `fin.history_none`, `train.last_none`, `season.contracts_none`, `season.growth_none`.
- **Toasts:** `tut.skipped_toast`, `tut.left`, `settings.help_reset_done`, `draft.timeout_toast`, `draft.timeout_toast_ban`, `gp.toast.applied`, `gp.toast.reset`, `squad.toast.moved`, `squad.toast.auto`. Undo is the existing `common.undo`.
- **Match banners (4 words at most):** `gp.switch.short.behind_early`, `gp.switch.short.ahead_early`, `gp.switch.short.vs_dive`, `gp.switch.short.vs_siege`, `gp.switch.short.vs_protect`.

## 5. Changes from the spec text (39)

| Key | Spec text | Final text | Why |
|---|---|---|---|
| `tut.welcome` | You run {club}. Let's play one practice game together. It takes a few minutes, and nothing in it counts. | Welcome, Manager. You run {club}. Let's play one practice game together. It takes a few minutes, and nothing in it counts. | Adds "Manager": the player is the Manager and the helper is Coach (TUTORIAL.md 13). |
| `tut.tab_squad` | Squad is where your players live. Tap Squad. | Squad is where you see your players. Tap Squad. | "Where your players live" is a figure of speech; plainer. |
| `tut.role` | Choose who plays this hero. Fit is how well the hero suits the role. The best lane is already chosen. Tap Pick. | Choose which role plays this hero. The percentage is how well it fits that role. The best fit is already chosen. Tap Pick. | The sheet's control is called a role everywhere else (glossary, Squad); "best lane" mixed role and lane. Also says what the percentage is. |
| `tut.open_plan` | Draft done. Now a Game Plan tells your team how to play: fights, tempo, objectives. Tap Game plan. | Draft done. Next, a game plan tells your team how to play: fights, tempo, objectives. Tap Game plan. | Sentence case "game plan" (the button reads "Game plan"); "Now" to "Next". |
| `tut.watch` | Contests appear in the feed as they are decided. Try Speed x2, or Skip to the end. | Results appear in the feed as each part of the game is decided. Try Speed x2, or Skip to the end. | "Contests" is not explained until lesson 5; plain words in the first game. |
| `tut.result.loss` | Defeat. That is fine: it was practice, and nothing changed in your season. The report shows why it went this way. | Defeat. That is fine. It was practice, and nothing changed in your season. The report shows why it went this way. | Colon split into two sentences; easier to read after a loss. |
| `tut.form_switch` | This list ranks clubs by Form Rating. Tap Points to switch to league points. Your club is marked in both. | This list ranks clubs by Form Rating. Tap Points to switch to league points. Your club is marked YOU in both. | Names the pill the player will see (YOU), so no marker has to be guessed. |
| `tut.nudge` | Tap the glowing spot to go on. | Tap the highlighted spot to continue. | "Glowing spot to go on" to "highlighted spot to continue": plainer, and the ring is a shape, not only light. |
| `tut.fallback` | We cannot find that on this screen. Tap Next to go on. | We cannot find that on this screen. Tap Next to continue. | "go on" to "continue" (same reason). |
| `les.l1.metric` | Switch between league Points and Form Rating. Your club is marked in both. | Switch between Points and Form Rating. Your club is marked YOU in both. | The switch says Points and Form Rating; names the YOU pill. |
| `les.l5.contests` | Each row is one contest in the game. A plus sign means you are stronger there, a minus sign means they are. | Each row is one contest: a lane, the jungle, an objective or a fight. Plus means you are stronger there, minus means they are. | Defines "contest" in four words and uses the contest name set (lane, jungle, objective, fight). "Plus means" saves 3 words, keeping it within 25. |
| `les.l5.plan` | Plan: Default is used from the start. If behind and If ahead take over from the mid-game after a one-sided early game. | Plan: Default is used from the start. If behind or If ahead can take over from the mid-game, after a one-sided early game. | "can take over": the trigger plans only apply if triggered. |
| `help.squad.know` | A player out of position loses rating. Auto lineup fixes it in one tap. | A player out of position loses rating. Pick best lineup for me fixes it in one tap. | Quotes the real button label "Pick best lineup for me" (`roster.auto`), not "Auto lineup". |
| `help.player.see` | Tiredness, form and morale bars, the contract, bonds and best heroes; Stats and Career are one tap away. | Tiredness, form and morale bars, the contract, bonds and best heroes. Stats and Career are one tap away. | A semicolon split into two sentences. |
| `help.plan.see` | Training, team chemistry, practice matches and your Game Plan status. | Training, team chemistry, practice matches and your game plan status. | "game plan" sentence case. |
| `help.plan.know` | The Game Plan is set during each draft, after the picks, because it depends on the heroes. | You set the game plan during each draft, after the picks, because it depends on the heroes. | "game plan" sentence case; active voice ("You set..."). |
| `help.match.see` | The clock, kills, towers and who is ahead, with each contest shown as it is decided. | The clock, kills, towers and who is ahead, with each result shown as it is decided. | "Contest" not defined yet at this point; "result" is plainer. |
| `help.match.terms` | lane,jungle,objective,teamfight,base | lane,objective,teamfight,base | `jungle` is not one of the 49 glossary ids (test 14 would fail); the Jungle is now explained in `gl.lane.def`. |
| `help.report.do` | Open "Why it went this way" to see the factors. Tap Continue when done. | Tap the big number to see why this happened. Tap Continue when done. | The factor sheet is titled "Why this happened" in the new layout and there is no longer a link with the old name; points at the big number instead. |
| `help.report.know` | Luck is a factor. A big luck share means a close game could have gone either way. | Luck is a factor. A big luck share means the game could have gone either way. | "a close game" was wrong when luck is large in a one-sided game; "the game could have gone either way" is the claim luck share supports. |
| `help.club.know` | Cash below zero for too long gets the manager dismissed. | If cash stays below zero too long, the board dismisses you. | "the manager dismissed" read as a third person; "the board dismisses you" matches `fin.debt`. |
| `help.standings.do` | Tap Table, Playoffs or History. Tap Points or Form to change the ranking. Your club says YOU. | Tap Table, Playoffs or History. Tap Points or Form Rating to change the ranking. Your club says YOU. | The switch option is Form Rating, not Form. |
| `help.negotiation.do` | Set the wage and length, then Make offer. | Set the wage and length, then tap Make offer. | Adds "tap" so the line is a complete instruction. |
| `help.settings.do` | Turn on larger text or colour-blind colours if they help. Replay the tutorial any time. | Try the Comfort options, such as larger text. Replay the tutorial any time. | Avoids the word colour in a help line; points at the Comfort card by its real name (`settings.access_h`). |
| `help.clubselect.see` | Every club with its Team Rating, strength tier and rank. | Every club with its team rating, strength tier and rank. | "team rating" lower case, as in `club.pick.line`. |
| `gl.team_rating.name` | Team Rating | Team rating | Matches the existing strings "Team rating" (`roster.team_rating`, `club.pick.line`). "Form Rating" stays capitalised: it is a named league score. |
| `gl.rating.def` | A player's skill in one role, built from his stats. Playing out of position lowers it. | A player's skill in one role, built from their stats. Playing out of position lowers it. | Neutral pronoun (players can be any gender). |
| `gl.potential.def` | The most a player can grow to in a stat. High-potential young players become stars but ask for more money. | The most a player can grow to in a stat. Young players with high potential become stars but ask for more money. | Neutral reorder; 22 words, exactly the limit. |
| `gl.morale.def` | How happy a player is. Results and playing time raise it. A starter who sits out for a while sours. | How happy a player is. Results and playing time raise it. A starter who sits out for a while gets unhappy. | "sours" is an idiom; "gets unhappy" is plain and matches the mood word `mood.unhappy`. |
| `gl.draft.def` | Before each game both teams ban and pick heroes in turn. Blue acts first. If the timer runs out, the Coach chooses. | Before each game both teams take turns to ban and pick heroes. If the timer runs out, the Coach chooses. | Drops "Blue acts first": it names a colour and the side is already shown by word and flag on the draft screen. |
| `gl.familiarity.def` | How well a player knows a hero. Higher is better play. It grows a little after each real game. | How well a player knows a hero. Higher means better play. It grows a little after each real game. | "Higher is better play" is not a sentence; "Higher means better play". |
| `gl.patch_strength.def` | How strong a hero is in the current patch. Strong heroes are the better bets. | How strong a hero is in the current patch. Strong heroes are the better choice. | "better bets" is an idiom. |
| `gl.game_plan.name` | Game Plan | Game plan | Sentence case, as `gp.title` and `draft.game_plan` already do. |
| `gl.lane.def` | One of the three paths between the bases. Top, Mid and Bot results decide who leads early. | One of the three paths between the bases: Top, Mid and Bot. The Jungle is the space between them. | Adds the Jungle (the glossary had no entry for it) and uses the contest names Top, Mid, Bot. |
| `gl.luck.def` | The random part of every game. The report shows how much it moved the result. | The random part of every game that no plan or draft controls. The report shows how much it moved the result. | Adds what luck is not controlled by, matching `report.luck_note`. |
| `gl.form_rating.def` | A running skill score for every club. Beating strong clubs in big games lifts it most. Practice never counts. | A running skill score for every club. Beating strong clubs in big games lifts it most. Practice games never count. | "Practice games never count", the exact phrase used in `tut.plan_practice`. |
| `gl.contract.def` | A player's deal: a weekly wage and a number of seasons. When it ends, he leaves unless you renew. | A player's deal: a weekly wage and a number of seasons. When it ends, the player leaves unless you renew. | Neutral pronoun. |
| `gl.free_agent.def` | A player with no club. You can sign him if you have cash, squad room and room under the wage cap. | A player with no club. You can sign them if you have cash, squad room and room under the wage cap. | Neutral pronoun. |
| `gl.signing_fee.def` | A one-off payment to sign a player: two weeks of his wage. | A one-off payment to sign a player: two weeks of their wage. | Neutral pronoun. |

## 6. Existing strings in `game/i18n/en.json`

### 6.1 Replaced by the patch (16 keys)

| Key | Old text | New text | Why |
|---|---|---|---|
| `draft.auto_rest` | Let the advisor finish the draft | Auto-finish | Rename and new layout: the Auto-finish text button of UI-PASS-2 6.3 (old text said "advisor"). |
| `draft.meta_hint` | Green = strong in this patch, grey = weak. Numbers are player familiarity. | An up arrow means strong in this patch, a down arrow means weak. Numbers are player familiarity. | Colour wording ("Green = strong, grey = weak"). Merge with the build that draws the up and down arrows (UI-PASS-2 6.3); until then the old screen still shows colour. |
| `gp.coach` | Coach's suggestion | Coach | UI-PASS-2 6.4 renames the footer button to "Coach". |
| `gp.c.t.pos` | Scale: stronger late game, weaker lanes | Play for late: stronger late game, weaker lanes | "Scale" needs explaining; "Play for late" matches the new end label. |
| `feed.t.jungle` | Jungle control | Jungle | "Jungle control" to "Jungle": one contest name set. |
| `club.pick.hint` | You are the owner and coach. Players pick their own heroes in the draft, you steer the draft and set the lineup. | You are the Manager. Your Coach helps, but you decide. Players pick their own heroes; you steer the draft and set the lineup. | Player is the Manager, not "owner and coach" (TUTORIAL.md 13). Also introduces the Coach early. |
| `draft.recommended` | Take advisor's choice: {hero} | Take Coach's choice: {hero} | Rename (old text said "advisor"). Interim wording for the old layout; **retire** when the Coach bar ships (`draft.coach_suggests` and `draft.coach_take` replace it). |
| `tip.prematch` | Green rows are roles where you are stronger, red where you are weaker. Tired starters play worse, so rest or rotate them. Next comes the draft: bans and picks run on a short timer, and if it runs out the coach chooses for you. | Rows show where you are stronger or weaker. Tired starters play worse, so rest or rotate them. Next comes the draft: bans and picks run on a short timer, and if it runs out the Coach chooses for you. | Lower-case "coach" and the colour wording ("Green rows ... red"). Interim only: **retire** the whole key when the Pre-match help sheet ships (TUTORIAL.md 5.2). |
| `about.title` | About Alpha 0.4 | About Alpha 0.7 | Said "Alpha 0.4" while the build is 0.7. |
| `about.included.b` | One full single-player season: pick a club, set your lineup, set each player's training, draft heroes against the clock, set your game plan, watch the match feed, read the report. 10 clubs, 18 league rounds, then a top-4 playoff (semi-finals best of 3, final best of 5). Players grow with training and tire from playing; veterans decline over the years. You also run the money: sign free agents, renew or release players, choose a sponsor, and stay out of debt. Your players also bond: starters who play together build Team chemistry (a small rating bonus), and every player has Form and Morale that follow results and playing time. Your progress saves automatically. | One full single-player season: pick a club, set your lineup and training, draft heroes against the clock, set your game plan, watch the match, read the report. 10 clubs, 18 league rounds, then a top-4 playoff. You also run the money, sign and renew players, and build team chemistry. New in this build: a guided first game, a ? help button on every screen, lessons and a glossary. Your progress saves automatically. | Stale (0.4). Rewritten for 0.7 as specified; check against what ships. |
| `about.test.b` | New in this build: Team chemistry (club office), Form and Morale, and the Team scrim training option. Do you understand why a player is 'in form' or 'unhappy'? Does it feel right that changing a starter costs a little chemistry? Is a game still quick (about 5 minutes with the draft)? Anything confusing, slow or broken? | New in this build: the guided first game, help on every screen, lessons and the glossary. Did you know what to do next without asking anyone? Which step slowed you down? Is a game still about 5 minutes with the draft? Anything confusing, slow or broken? | Stale: asked about Alpha 0.4 features. Now asks the 0.7 tester questions. |
| `about.limits.b` | Transfers between clubs, youth intake, Exhibition and Quick Match, animations and art. Match results are text only. Hero and player names are placeholders. | Transfers between clubs and youth intake. The live match arena comes in Alpha 0.8. Hero and player names are placeholders. | Stale: listed Exhibition and Quick Match as missing (they exist since 0.6) and "text only" results. Check against what ships. |
| `feedback.template` | Feedback for MOBA Esports alpha\n\nWhat I was doing:\n\nWhat happened:\n\nWhat I expected:\n\n--- details for the developer ---\n{info} | Feedback for Gloamline alpha\n\nWhat I was doing:\n\nWhat happened:\n\nWhat I expected:\n\n--- details for the developer ---\n{info} | Said "MOBA Esports alpha"; the game is Gloamline. |
| `plan.gp.h` | Game Plan | Game plan | "Game Plan" to "Game plan": sentence case as `gp.title`. |
| `plan.gp.body` | You set the Game Plan during each draft, after the picks, because it depends on the heroes. Your choices are saved for the next game. | You set the game plan during each draft, after the picks, because it depends on the heroes. Your choices are saved for the next game. | "Game Plan" to "game plan" in running text, same as the Plan help sheet. |
| `tag.scaling` | scales late | strong late | "scales late" is jargon, same reason as `gp.c.t.pos`. Hero tag chip. |

### 6.2 Coach and Manager rename: the full list

I searched every existing value for advisor, assistant, AI, coach, owner, manager, suggest, chooses. Results:

| Key | Today | After the patch |
|---|---|---|
| `draft.recommended` | Take advisor's choice: {hero} | Take Coach's choice: {hero} (retire later) |
| `draft.auto_rest` | Let the advisor finish the draft | Auto-finish |
| `club.pick.hint` | You are the owner and coach. ... | You are the Manager. Your Coach helps, but you decide. ... |
| `tip.prematch` | ...if it runs out the coach chooses for you. | ...the Coach chooses for you. (retire later) |
| `gp.coach` | Coach's suggestion | Coach |
| `train.coach_all`, `train.auto_btn` | Coach picks for everyone / Coach's choice | no change (already Coach) |
| `tip.hub.h` | Welcome, Manager | no change; retire with `tip.hub*` (the Manager word moves to `tut.welcome`) |

Nothing else in the file names the helper or the player. Outside `en.json` (not mine, from TUTORIAL.md 13): GDD v1 line 12, 7.3 and 7.8 and a code comment in `game_plan.gd` still call the player the coach.

### 6.3 Retire after the code stops using them (not in the patch, so nothing breaks today)

`tip.hub.h`, `tip.hub`, `tip.prematch.h`, `tip.prematch`, `tip.report.h`, `tip.report`, `tip.got_it` (replaced by the Help sheets and `help.got_it`); `settings.tips_again`, `settings.tips_done` (replaced by `settings.help_reset`, `settings.help_reset_done`); `draft.recommended` (replaced by `draft.coach_suggests` and `draft.coach_take`); `report.why_h` (replaced by `report.why_sheet_h`); the old Standings tab labels `standings.tab.table`, `.playoffs`, `.results`, `.form`, `.trophies` and `standings.form` (replaced by `standings.view.*` and `standings.metric.*`). Do **not** delete the Payoff tips `tip.rest`, `tip.morale`, `tip.contract`, `tip.scrim`, `tip.keep` (TUTORIAL.md 5.2).

### 6.4 Findings I did not change

- **Colour words left in existing strings:** `chem.pentagon_hint` ("Greener line"); `hub.side.blue` and `hub.side.red` (side names, fine); `settings.colorblind` and `settings.colorblind_hint` (they describe the setting, fine). `draft.meta_hint` and `tip.prematch` are fixed by the patch.
- **Gendered pronouns** ("he", "his", "him") in 12 existing strings: `chem.bench_hint`, `neg.asking`, `neg.block.locked`, `neg.pv.bench`, `neg.pv.h_sign`, `release.block.unknown`, `release.confirm`, `release.yes`, `season.contracts_hint`, `stat.help.mec`, `stat.help.pot`, `train.squad_h`. Players can be any gender; the spec's glossary note says "their" is safer. I did not change them (not in this task's two files) and can do it in a small follow-up.
- **"Game Plan" with a capital P** remaining after the patch: none. `plan.gp.h` and `plan.gp.body` were the two hits and are in the patch.
- **Two similar names for two actions:** "Auto-play this game" (`hub.quick`, skips the whole game) and "Auto-finish" (finishes the draft). Different screens, so I left both; add "did you confuse these" to the tester questions.
- **Player card tabs:** `help.player.do` says "Tap Stats"; I found no `Stats` or `Career` tab label in `en.json` (`career.h` is "Career with us"). UI/UX to confirm the real labels.

## 7. Not covered, and hand-offs

- **Match commentary** (at most 2 lines per game, 3 or more phrasings per slot) belongs to the Alpha 0.8 arena and was not in this task. `ESPORTS-NOTES.md` 4 is the tone brief; I can write it next.
- **`docs/design/VOICE-AND-TONE.md`** does not exist. Section 1 above is its content; the Producer can ask me to create it.
- **Programmers:** `help.<id>.terms` is a comma-separated string; split it. `gl.<id>.where` is a help id, not text. The help-sheet-to-lesson mapping is listed under the help sheets table (section 4.6). The new keys are unused until the build uses them.
- **UI/UX Designer:** confirm the switch width ("Form Rating"), the role filter words, the Chemistry hint cue, the Stats and Career labels, and the four cut-line states (`standings.cut.*`, `standings.pin.*`) with `GameState.cut_gap()`.
- **IP & Originality Checker:** the font credit line `about.licences.font`; the names Gloamline, Coach and Manager are generic. No new hero, club or place names were written.
- **Lead Game Designer:** `gp.end.t.pos` and `tag.scaling` change the words "Scale" and "scales late"; say if the sim docs need to follow.

