class_name ArenaComment
extends RefCounted
## Commentary for Match Sim v2 games (0.12, overnight Q4; Narrative Designer). At most two short lines a game, each shown in
## the notes line under the map for SHOW_S show seconds, only in calm moments (no fight, kill, tower or objective near it),
## and never in large text (the screen does not build one). Lines come from real log events: the gold lead at 8:00, the
## first Moonhulk (else an early Stoneback), the first decisive fight (the log's "decisive" flag, Q3), and the lead a minute
## before the end. Display only (rules A1 and R7): reads the ArenaPlayer, never the sim.

const SHOW_S := 3.0            # show seconds a line stays up (about 2.5 to 3 s at speed x1)
const MAX_LINES := 2
const SLIDE_S := 30.0          # game seconds a line may move later to find a calm moment
const GAP_S := 120.0           # game seconds between the two lines at least
const LEAD_GOLD := 1500        # a lead at 8:00 counts from here
const LATE_GOLD := 2000

var lines: Array = []          # [game t0, game t1, text key, vars], in time order


static func build(pl: ArenaPlayer) -> ArenaComment:
	var c := ArenaComment.new()
	var cands: Array = []      # [priority, game t, key base, vars]
	# the first decisive fight (Q3 flag) and who won it
	for e in pl.log["ev"]:
		if String(e[1]) == "decisive" and String(e[2]) == "fight":
			var fid := int(e[3])
			for f in pl.fights:
				if int(f["id"]) == fid:
					var w := _fight_winner(pl, f)
					if w != "":
						cands.append([4, float(f["t1"]) + 2.0, "arena2.comment.fight_" + ("you" if w == pl.my_side else "them"), {}])
					break
			break
	# Moonhulk, else an early Stoneback
	var obj_done := false
	for want in ["moonhulk", "stoneback"]:
		if obj_done:
			break
		for o in pl.objs:
			if String(o[1]) == want and (want == "moonhulk" or float(o[0]) < 900.0):
				var who := "you" if String(o[2]) == pl.my_side else "them"
				cands.append([3, float(o[0]) + 3.0, "arena2.comment.%s_%s" % ["moon" if want == "moonhulk" else "stone", who], {}])
				obj_done = true
				break
	# the lead after the lanes (8:00)
	if pl.end_t > 600.0:
		var lead := int(ArenaHud2.board_values(pl, 480.0)["gold"])
		cands.append([2, 480.0, "arena.comment.lanes_" + ("you" if lead >= LEAD_GOLD else ("them" if lead <= -LEAD_GOLD else "even")), {}])
	# a minute before the end
	if pl.end_t > 900.0:
		var g := pl.end_t - 60.0
		var lead2 := int(ArenaHud2.board_values(pl, g)["gold"])
		cands.append([1, g, "arena.comment.late_" + ("you" if lead2 >= LATE_GOLD else ("them" if lead2 <= -LATE_GOLD else "close")), {}])
	cands.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	for cd in cands:
		if c.lines.size() >= MAX_LINES:
			break
		var g0 := c._calm_from(pl, float(cd[1]))
		if g0 < 0.0:
			continue
		var clash := false
		for l in c.lines:
			if absf(float(l[0]) - g0) < GAP_S:
				clash = true
		if clash:
			continue
		var g1 := pl.game_t(pl.show_t(g0) + SHOW_S)
		var v := 1 + int(g0) % 3
		c.lines.append([g0, g1, "%s.%d" % [String(cd[2]), v], cd[3]])
	c.lines.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	return c


## The side that got more kills in a fight ("" if even).
static func _fight_winner(pl: ArenaPlayer, f: Dictionary) -> String:
	var n := {"B": 0, "R": 0}
	for k in pl.kills:
		if float(k[0]) >= float(f["t0"]) - 0.5 and float(k[0]) <= float(f["t1"]) + 0.5 and String(k[2]) in f["keys"]:
			var s := ArenaPlayer.side_of(String(k[1]))
			if n.has(s):
				n[s] += 1
	if int(n["B"]) == int(n["R"]):
		return ""
	return "B" if int(n["B"]) > int(n["R"]) else "R"


## The first calm game time at or after g (within SLIDE_S), or -1.
func _calm_from(pl: ArenaPlayer, g: float) -> float:
	var x := g
	while x <= g + SLIDE_S and x < pl.end_t - 5.0:
		if is_calm(pl, x):
			return x
		x += 2.0
	return -1.0


## Nothing happens from 2 s before a line until 1 s after it goes away: no fight, kill, tower or objective.
static func is_calm(pl: ArenaPlayer, g: float) -> bool:
	var g1 := pl.game_t(pl.show_t(g) + SHOW_S)
	var a := g - 2.0
	var b := g1 + 1.0
	for f in pl.fights:
		if float(f["t0"]) <= b and float(f["t1"]) >= a:
			return false
	for arr in [pl.kills, pl.towers, pl.objs]:
		for e in arr:
			if float(e[0]) >= a and float(e[0]) <= b:
				return false
	return true


## The line on screen at game time t, or "".
func text_at(t: float) -> String:
	for l in lines:
		if float(l[0]) <= t and t <= float(l[1]):
			return Strings.f(String(l[2]), l[3])
	return ""
