extends RefCounted
## Pure logic of the performance gate (PERF-BUDGET.md 3.1a, build plan I-00c). No autoloads, no renderer: the
## probe (perf_baseline.gd) measures, this file judges, and perf_gate_tests.gd tests it headless.
##
## Allowance file: res://tests/perf_allowances.json
##   {"version": 1, "min_states": N,
##    "hard":   {draws, nodes, canvas, tex_bytes, vid_bytes, tree, shadows, glows, font_cache},
##    "target": {draws, nodes, canvas, tex_bytes, vid_bytes, font_cache},
##    "canvas_target_exceptions": [state, ...],
##    "rows": {"<state>": {"status": "legacy" | "redesigned", ...}}}
## A "legacy" row: {"status","leaves_with":"I-15","measured":{"draws":N,"nodes":N},"draws":ALLOWANCE,"nodes":ALLOWANCE,
##   optional "raise":{"reason","approved_by"}}. Rule 1: its draws and nodes allowance replaces the hard limit for
##   those two numbers only. The ratchet: an allowance may not exceed allowance_for(measured) (measured + 10 percent,
##   next 5) unless the row carries a "raise" with a reason and a name (rule 4).
## A "redesigned" row: {"status","since":"I-15", optional "waiver":{"draws"?,"nodes"?,"reason","approved_by"}}. Rule 2:
##   target limits, or the waiver number if there is one; the hard limit always fails.
## A state with no row (rule 3): hard limits, reported as NO ROW.

const KEYS := ["draws", "nodes"]
const HARD_DEFAULT := {"draws": 100, "nodes": 200, "canvas": 1200, "tex_bytes": 48 * 1048576, "vid_bytes": 64 * 1048576,
		"tree": 250, "shadows": 6, "glows": 2, "font_cache": 16}
const TARGET_DEFAULT := {"draws": 60, "nodes": 120, "canvas": 700, "tex_bytes": 32 * 1048576, "vid_bytes": 48 * 1048576,
		"font_cache": 12}
## Style box names that are the visible background of the usual controls.
const BOX_NAMES := ["panel", "normal", "fill", "background"]


## Measured + 10 percent, rounded up to the next 5 (integer arithmetic: 50 * 1.1 must be 55, not 60).
static func allowance_for(measured: int) -> int:
	var plus10 := (measured * 11 + 9) / 10
	return ((plus10 + 4) / 5) * 5


## The limits that apply: hard and target, with the file's numbers over the built-in defaults.
static func limits(data: Dictionary, which: String) -> Dictionary:
	var base: Dictionary = (HARD_DEFAULT if which == "hard" else TARGET_DEFAULT).duplicate()
	var over = data.get(which, {})
	if over is Dictionary:
		for k in over:
			base[k] = int(over[k])
	return base


## Reads the allowance file. Returns {"ok": bool, "data": Dictionary, "problems": Array[String]}. A missing or
## unparsable file is not ok, and data is then empty, so every state has no row and the hard limits apply.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": {}, "problems": ["allowance file %s not found (hard limits only)" % path]}
	var js := JSON.new()   # JSON.new().parse reports through its return code; parse_string would print an engine ERROR line
	var parsed = js.data if js.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not (parsed is Dictionary):
		return {"ok": false, "data": {}, "problems": ["allowance file %s is not a JSON object (hard limits only)" % path]}
	var problems := validate(parsed)
	return {"ok": problems.is_empty(), "data": parsed, "problems": problems}


## Everything wrong with an allowance table, one line each. Empty means the table is usable.
static func validate(data: Dictionary) -> Array:
	var out: Array = []
	var hard := limits(data, "hard")
	if not data.has("rows") or not (data["rows"] is Dictionary):
		return ["no \"rows\" object"]
	for state in data["rows"]:
		var r = data["rows"][state]
		if not (r is Dictionary):
			out.append("%s: row is not an object" % state)
			continue
		var status := String(r.get("status", ""))
		if status == "legacy":
			for k in KEYS:
				if not (r.has(k) and (r[k] is float or r[k] is int)) or int(r[k]) <= 0:
					out.append("%s: legacy row needs a positive number for %s" % [state, k])
			var m = r.get("measured", null)
			if not (m is Dictionary and m.has("draws") and m.has("nodes")):
				out.append("%s: legacy row needs measured {draws, nodes}" % state)
			else:
				for k in KEYS:
					var cap := allowance_for(int(m[k]))
					if int(r.get(k, 0)) > cap and not _named(r.get("raise", null)):
						out.append("%s: %s allowance %d is above measured %d + 10 percent (%d) and has no raise with reason and name (the ratchet only goes down)" % [state, k, int(r.get(k, 0)), int(m[k]), cap])
			if r.has("waiver"):
				out.append("%s: a legacy row cannot carry a waiver (waivers are for redesigned screens)" % state)
		elif status == "redesigned":
			var w = r.get("waiver", null)
			if w != null:
				if not _named(w):
					out.append("%s: waiver needs a reason and approved_by (the Technical Director's name)" % state)
				if w is Dictionary:
					var any := false
					for k in KEYS:
						if w.has(k):
							any = true
							if int(w[k]) > int(hard[k]):
								out.append("%s: waiver %s %d is above the hard limit %d (a waiver can never exceed it)" % [state, k, int(w[k]), int(hard[k])])
					if not any:
						out.append("%s: waiver names no number (draws or nodes)" % state)
		else:
			out.append("%s: status must be \"legacy\" or \"redesigned\", got \"%s\"" % [state, status])
	return out


static func _named(d) -> bool:
	return d is Dictionary and String(d.get("reason", "")).strip_edges() != "" and String(d.get("approved_by", "")).strip_edges() != ""


## Judge one state. m: nodes, draws, canvas, tex, vid, tree, shadows, glows. Returns
## {"mode": "legacy"|"redesigned"|"norow", "fails": [..], "notes": [..], "over_target": bool}.
## Notes are "NO ROW", "tighten to N" and similar; fails make the check exit 1.
static func judge(state: String, m: Dictionary, data: Dictionary) -> Dictionary:
	var hard := limits(data, "hard")
	var target := limits(data, "target")
	var rows = data.get("rows", {})
	var row = rows.get(state, null) if rows is Dictionary else null
	var fails: Array = []
	var notes: Array = []
	var mode := "norow"
	var lim := {"draws": int(hard["draws"]), "nodes": int(hard["nodes"])}
	var over_target := false
	if row is Dictionary and String(row.get("status", "")) == "legacy" and row.has("draws") and row.has("nodes"):
		mode = "legacy"
		for k in KEYS:
			lim[k] = int(row[k])
			var have := int(m[k])
			var better := allowance_for(have)
			if better < int(row[k]):
				notes.append("tighten %s to %d" % [k, better])
		over_target = int(m["draws"]) > int(target["draws"]) or int(m["nodes"]) > int(target["nodes"])
	elif row is Dictionary and String(row.get("status", "")) == "redesigned":
		mode = "redesigned"
		var w = row.get("waiver", null)
		for k in KEYS:
			lim[k] = int(target[k])
			if w is Dictionary and w.has(k):
				lim[k] = mini(int(w[k]), int(hard[k]))
	else:
		notes.append("NO ROW (held to the hard limits %d draw calls, %d nodes; add a row at the measured value)" % [int(hard["draws"]), int(hard["nodes"])])
		over_target = int(m["draws"]) > int(target["draws"]) or int(m["nodes"]) > int(target["nodes"])
	var names := {"draws": "draw calls", "nodes": "nodes"}
	for k in KEYS:
		if int(m[k]) > int(lim[k]):
			var what := "allowance" if mode == "legacy" else ("target or waiver" if mode == "redesigned" else "hard limit")
			fails.append("%s: %d %s (%s %d)" % [state, int(m[k]), names[k], what, int(lim[k])])
		# the hard limit always fails, on redesigned screens and on states without a row; a legacy row replaces it
		elif mode != "legacy" and int(m[k]) > int(hard[k]):
			fails.append("%s: %d %s (hard limit %d)" % [state, int(m[k]), names[k], int(hard[k])])
	# canvas items: one rule for every screen, no rows; named exceptions to the target only
	var exc = data.get("canvas_target_exceptions", [])
	if int(m["canvas"]) > int(hard["canvas"]):
		fails.append("%s: %d canvas items (hard limit %d)" % [state, int(m["canvas"]), int(hard["canvas"])])
	elif int(m["canvas"]) > int(target["canvas"]) and not (exc is Array and exc.has(state)):
		over_target = true
	var more := [["tex", "tex_bytes", "bytes of texture memory"], ["vid", "vid_bytes", "bytes of video memory"],
			["tree", "tree", "nodes in the whole tree"], ["shadows", "shadows", "shadowed surfaces visible"],
			["glows", "glows", "glowing surfaces visible"]]
	for t in more:
		if m.has(t[0]) and int(m[t[0]]) > int(hard[t[1]]):
			fails.append("%s: %d %s (hard limit %d)" % [state, int(m[t[0]]), t[2], int(hard[t[1]])])
	if int(m.get("tex", 0)) > int(target["tex_bytes"]) or int(m.get("vid", 0)) > int(target["vid_bytes"]):
		over_target = true
	return {"mode": mode, "fails": fails, "notes": notes, "over_target": over_target}


## Rows in the table whose state was not visited (a renamed state leaves a stale row and a new state with no row).
static func stale_rows(data: Dictionary, visited: Array) -> Array:
	var out: Array = []
	var rows = data.get("rows", {})
	if rows is Dictionary:
		for s in rows:
			if not visited.has(s):
				out.append(String(s))
	return out


## Font cache gate (UI.font_cache_size(), the number of FontVariations alive). Returns a fail line or "".
static func judge_font_cache(n: int, data: Dictionary) -> Dictionary:
	var hard := limits(data, "hard")
	var target := limits(data, "target")
	var res := {"fail": "", "over_target": n > int(target["font_cache"])}
	if n > int(hard["font_cache"]):
		res["fail"] = "font cache: %d font variations (hard limit %d)" % [n, int(hard["font_cache"])]
	return res


## Shadowed and glowing surfaces visible in a subtree (PERF-BUDGET 3.1 and 3.4). A node counts once if the style box
## it shows (panel, normal, fill or background) is a StyleBoxFlat with shadow_size above 0 and a shadow colour that is
## not transparent. A glow is a shadow whose colour is coloured (saturation above 0.25, art bible 4.2: coral and role
## colours); a neutral black or grey shadow is a shadow. Hidden nodes (visible = false) and their children are skipped.
## Limit: surfaces drawn by hand in a _draw override (draw_style_box) cannot be seen from here.
static func count_shadows(root: Node) -> Dictionary:
	var res := {"shadows": 0, "glows": 0}
	_walk(root, res)
	return res


static func _walk(n: Node, res: Dictionary) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control:
		var c := n as Control
		var seen := false
		for bn in BOX_NAMES:
			if seen:
				break
			if c.has_theme_stylebox(bn):
				var sb := c.get_theme_stylebox(bn)
				if sb is StyleBoxFlat and (sb as StyleBoxFlat).shadow_size > 0 and (sb as StyleBoxFlat).shadow_color.a > 0.0:
					seen = true
					if (sb as StyleBoxFlat).shadow_color.s > 0.25:
						res["glows"] += 1
					else:
						res["shadows"] += 1
	for ch in n.get_children():
		_walk(ch, res)
