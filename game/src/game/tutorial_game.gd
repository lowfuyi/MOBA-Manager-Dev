class_name TutorialGame
extends RefCounted
## The guided first game (build plan 0.7 I-13, TUTORIAL.md 2.4 "A+"): a practice Quick Match that is flagged `tutorial: true`
## and is a SANDBOX. Playing it cannot change the player's season. Pure logic over a GameState (no autoloads, no UI classes), so
## it runs in run_tests.gd. Everything here is static; nothing is stored in `gs.d` (the save), not even the tutorial key.
##
## THE FLAG. The game Dictionary carries `"tutorial": true` (and `kind` stays "exhibition", so Report and Pre-match already
## treat it as a practice game). `stamp(res, g)` copies the flag onto the finished result (App.last_result) so a screen that only
## holds the result can still tell. `is_tutorial(x)` reads either. What the flag skips (the readers are listed for G1 in the
## hand-back): GameState.record_human_game (so no fatigue, bond, familiarity, history, career, standings, fixtures, Form Rating,
## morale, cash, `exh_n`, `exh_day`, `exh_busy`), the Payoff snapshot and compare, the pace log (`logs_pace`), the Quick-mode
## shortcut of the Match screen (`quick_applies`) and the draft timer (`timed`).
##
## THE OPPONENT RULE (TUTORIAL 2.4 item 5, build plan I-13). `opponent(gs)` is deterministic, with no random draw:
##   1. among the other clubs whose Team Rating is NOT above ours (rating <= ours), the one with the HIGHEST rating, so the
##      game is as close as it can be without ever being against a stronger club; ties go to the club first in the league's
##      file order (`world.club_ids`);
##   2. if every other club is above ours (we are the weakest), the NEAREST one above (lowest rating above ours; ties as above).
## Fairness, not a rigged result: the draft, the plan and the simulation run as normal and a loss is possible. The same save and
## the same lineup always give the same opponent, so a Replay is the same club on a different seed. NOTE: rule 2 is the only case
## where the opponent is stronger than the player; the plan wording "never stronger" cannot hold for the weakest club (see the hand-back).
##
## THE SEED. The match id is `tut:<save seed>:<n>` where `n` is the replay count `game.n` of the tutorial key (TutorialState:
## Start and Replay raise it, a resume after a kill does not). The simulation seeds are pure hashes of (save seed, match id), so a
## `tut:` id has its own streams and the league's `exh-pick`, `sched` and fixture streams are never read or advanced.
##
## THE PLAN. `start()` gives `gs.sandbox_plan` a neutral plan set; while it is filled, `gs.plan_set()` (the hook the Game Plan,
## Draft and Plan screens use) returns it, and `gs.plans_for(g)` plays it for a tutorial game only. The saved plan (`d["plan"]`)
## is never read or written meanwhile. `leave()` empties it (the game is over, backed out of, or the tutorial was skipped and
## the game left). It is never saved: after a load there is no sandbox, which is the resume rule of section 5 item 10.

const KIND := "exhibition"
const SERIES := "X"
## The draft timer of a tutorial game in seconds: 0 means no timer ("No timer in the tutorial", `tut.draft.note`).
const DRAFT_LIMIT_S := 0.0


## True for a game Dictionary or a result Dictionary of the tutorial game.
static func is_tutorial(x) -> bool:
	return x is Dictionary and bool((x as Dictionary).get("tutorial", false))


## The replay count of this save's tutorial (0 for a legacy save that never started it).
static func game_n(gs: GameState) -> int:
	var g = gs.tutorial().get("game")
	return int((g as Dictionary).get("n", 0)) if g is Dictionary else 0


## `tut:<save seed>:<n>`: the match id, and so the seed stream, of the current tutorial game.
static func seed_id(gs: GameState) -> String:
	return "tut:%d:%d" % [int(gs.d["save_seed"]), game_n(gs)]


## The match seed the simulation derives from the id (what MatchRunner.prepare computes).
static func match_seed(gs: GameState) -> int:
	return Pcg32.match_seed(int(gs.d["save_seed"]), seed_id(gs))


## The opponent club id (rule in the header). "" only when the league has no other club.
static func opponent(gs: GameState) -> String:
	var mine: float = gs.world.team_rating(gs.lineup_for(gs.club()))
	var below := ""
	var below_r := -1e18
	var above := ""
	var above_r := 1e18
	for c in gs.world.club_ids:
		if c == gs.club():
			continue
		var r: float = gs.world.team_rating(gs.lineup_for(c))
		if r <= mine:
			if r > below_r:
				below_r = r
				below = c
		elif r < above_r:
			above_r = r
			above = c
	return below if below != "" else above


## Begin the tutorial game: the game Dictionary (same shape as GameState.practice_game(), plus `tutorial`), and an empty-neutral
## sandbox plan. Writes nothing to `gs.d`. Works on any save (legacy included), in any phase, whatever the practice day says.
## Returns {} when the league has no opponent.
static func start(gs: GameState) -> Dictionary:
	var opp := opponent(gs)
	if opp == "":
		return {}
	gs.sandbox_plan = GamePlan.neutral_set()
	return {"kind": KIND, "id": seed_id(gs), "blue": gs.club(), "red": opp, "full": false, "round": int(gs.d["round"]),
			"series": SERIES, "game": 1, "best_of": 1, "tutorial": true}


## The game is over or was left: the sandbox plan goes. Safe to call at any time, any number of times.
static func leave(gs: GameState) -> void:
	gs.sandbox_plan = {}


## True while a tutorial game's sandbox plan is in flight.
static func is_live(gs: GameState) -> bool:
	return not gs.sandbox_plan.is_empty()


## A copy of the sandbox plan, for TutorialRunner.set_game_plan() (the machine keeps a copy in the key; the key's copy is cleared on load).
static func plan_copy(gs: GameState) -> Dictionary:
	return gs.sandbox_plan.duplicate(true)


## Copy the flag from the game onto its finished result. Returns the same result. Never changes a simulated number.
static func stamp(res: Dictionary, g: Dictionary) -> Dictionary:
	if is_tutorial(g):
		res["tutorial"] = true
	return res


## Quick mode (Settings) is ignored for a tutorial game: the player gets a real watch. G1: replace `gs.is_quick()` in ScreenMatch.
static func quick_applies(gs: GameState, g: Dictionary) -> bool:
	return gs.is_quick() and not is_tutorial(g)


## The draft timer runs for every game but the tutorial game (G1: ScreenDraft, with DRAFT_LIMIT_S).
static func timed(g: Dictionary) -> bool:
	return not is_tutorial(g)


## The pace log (`pace_add`, `pace_quick`) skips the tutorial game.
static func logs_pace(g: Dictionary) -> bool:
	return not is_tutorial(g)
