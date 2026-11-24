class_name FinFlow
extends RefCounted
## Club finance summary (0.12, ESMO Q4-5), read only from the ledger GameState._earn keeps (d["ledger"]: season s, round r,
## kind k, amount a; the last 160 entries). No save change.

const ROUNDS := 8


## The last `n` rounds that have entries, oldest first: [{"s", "r", "in", "out"}] ("out" is a positive number).
static func rounds(ledger: Array, n: int = ROUNDS) -> Array:
	var order: Array = []
	var by := {}
	for e in ledger:
		var key := "%d:%d" % [int(e["s"]), int(e["r"])]
		if not by.has(key):
			by[key] = {"s": int(e["s"]), "r": int(e["r"]), "in": 0.0, "out": 0.0}
			order.append(key)
		var a := float(e["a"])
		if a >= 0.0:
			by[key]["in"] += a
		else:
			by[key]["out"] += -a
	var out: Array = []
	for i in range(maxi(0, order.size() - n), order.size()):
		out.append(by[order[i]])
	return out


## Totals by kind for one season: {"in": [[kind, amount]], "out": [[kind, amount]]}, largest first.
static func by_kind(ledger: Array, season: int) -> Dictionary:
	var t := {}
	for e in ledger:
		if int(e["s"]) != season:
			continue
		var k := String(e["k"])
		t[k] = float(t.get(k, 0.0)) + float(e["a"])
	var ins: Array = []
	var outs: Array = []
	for k in t:
		var v := float(t[k])
		if v > 0.05:
			ins.append([k, v])
		elif v < -0.05:
			outs.append([k, -v])
	ins.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and String(a[0]) < String(b[0])))
	outs.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and String(a[0]) < String(b[0])))
	return {"in": ins, "out": outs}


## The bar chart: income up (UI.GOOD), costs down (UI.WARN) from one zero line, one pair per round. Rectangles only (batched).
class Chart extends Control:
	var data: Array = []
	var draw_count := 0

	func _init(p_data: Array) -> void:
		data = p_data
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0.0, 140.0)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_count += 1
		var top_in := 0.0
		var top_out := 0.0
		for d in data:
			top_in = maxf(top_in, float(d["in"]))
			top_out = maxf(top_out, float(d["out"]))
		var span := maxf(1.0, top_in + top_out)
		var usable := size.y - 8.0
		var mid := 4.0 + usable * top_in / span    # one scale: the line sits where the highest income and cost meet
		var n := maxi(1, data.size())
		var slot := size.x / float(FinFlow.ROUNDS)
		var bw := maxf(6.0, slot * 0.32)
		var x0 := size.x - float(n) * slot    # newest round at the right edge
		for i in data.size():
			var d: Dictionary = data[i]
			var x := x0 + float(i) * slot + slot * 0.5
			var hi := usable * float(d["in"]) / span
			var ho := usable * float(d["out"]) / span
			if hi > 0.5:
				draw_rect(Rect2(x - bw - 1.0, mid - hi, bw, hi), UI.GOOD)
			if ho > 0.5:
				draw_rect(Rect2(x + 1.0, mid, bw, ho), UI.WARN)
		draw_rect(Rect2(0.0, mid - 1.0, size.x, 2.0), UI.DIM)
