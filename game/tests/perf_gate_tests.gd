extends RefCounted
## Headless tests for the perf gate logic (tests/perf_gate.gd) and the allowance file (tests/perf_allowances.json),
## PERF-BUDGET.md 3.1a. Nothing here needs a renderer or an autoload; the probe itself (perf_baseline.gd) is run
## under Xvfb by tools/run_all_checks.sh. Negative controls: a row exceeded fails, a missing row falls back to the
## hard limits, a broken table is reported, a waiver cannot pass the hard limit.

const Gate = preload("res://tests/perf_gate.gd")


static func _m(draws: int, nodes: int, extra: Dictionary = {}) -> Dictionary:
	var m := {"draws": draws, "nodes": nodes, "canvas": 300, "tex": 10 * 1048576, "vid": 16 * 1048576, "tree": nodes + 20,
			"shadows": 0, "glows": 0}
	m.merge(extra, true)
	return m


static func _legacy(draws: int, nodes: int) -> Dictionary:
	return {"status": "legacy", "measured": {"draws": draws, "nodes": nodes}, "draws": Gate.allowance_for(draws), "nodes": Gate.allowance_for(nodes)}


static func _table(rows: Dictionary) -> Dictionary:
	return {"version": 1, "rows": rows}


func _fails(state: String, m: Dictionary, data: Dictionary) -> int:
	return (Gate.judge(state, m, data)["fails"] as Array).size()


func run(check: Callable) -> void:
	_rounding(check)
	_real_file(check)
	_legacy_rows(check)
	_no_row(check)
	_redesigned(check)
	_other_limits(check)
	_validation(check)
	_file_round_trip(check)
	_shadow_counter(check)


func _rounding(check: Callable) -> void:
	# measured + 10 percent, next 5 (the PERF-BUDGET 3.1a rule); the float trap: 50 * 1.1 is 55.000000000000007
	var want := {0: 0, 1: 5, 8: 10, 10: 15, 12: 15, 20: 25, 36: 40, 40: 45, 45: 50, 50: 55, 55: 65, 60: 70, 100: 110, 133: 150, 149: 165, 150: 165, 153: 170}
	var bad: Array = []
	for k in want:
		if Gate.allowance_for(int(k)) != int(want[k]):
			bad.append("%d gives %d, want %d" % [k, Gate.allowance_for(int(k)), want[k]])
	check.call(bad.is_empty(), "allowance = measured + 10 percent, next 5 (%s)" % ("; ".join(bad) if not bad.is_empty() else "%d values" % want.size()))


func _real_file(check: Callable) -> void:
	var f: Dictionary = Gate.load_file("res://tests/perf_allowances.json")
	check.call(f["ok"], "perf_allowances.json loads and validates (%s)" % "; ".join(f["problems"]))
	var d: Dictionary = f["data"]
	var rows: Dictionary = d.get("rows", {})
	check.call(rows.size() >= int(d.get("min_states", 999)) and rows.size() >= 49, "perf_allowances.json has a row for each of the 49 tour states (%d)" % rows.size())
	var hard := Gate.limits(d, "hard")
	var tgt := Gate.limits(d, "target")
	check.call(hard["draws"] == 100 and hard["nodes"] == 200 and hard["canvas"] == 1200 and hard["tex_bytes"] == 48 * 1048576 and hard["shadows"] == 6 and hard["glows"] == 2 and hard["font_cache"] == 16, "hard limits are the PERF-BUDGET numbers")
	check.call(tgt["draws"] == 60 and tgt["nodes"] == 120 and tgt["canvas"] == 700 and tgt["tex_bytes"] == 32 * 1048576 and tgt["font_cache"] == 12, "targets are the PERF-BUDGET numbers")
	var every_row_formula := true
	for s in rows:
		var r: Dictionary = rows[s]
		if r.get("status") == "legacy":
			if int(r["draws"]) != Gate.allowance_for(int(r["measured"]["draws"])) or int(r["nodes"]) != Gate.allowance_for(int(r["measured"]["nodes"])):
				every_row_formula = false
	check.call(every_row_formula, "every legacy row is measured + 10 percent rounded up to the next 5")
	# the I-02 numbers handed over with the task: state -> [draws measured, nodes measured, draw allowance, node allowance]
	var six := {"04_hub": [45, 60, 50, 70], "05_roster": [34, 36, 40, 40], "10_draft_ban_2": [38, 81, 45, 90],
			"11c_gameplan_trigger": [26, 133, 30, 150], "14_report_top": [20, 153, 25, 170], "16_standings": [29, 82, 35, 95]}
	for s in six:
		var r = rows.get(s, {})
		var w: Array = six[s]
		check.call(r is Dictionary and r.get("status") == "legacy" and int(r["measured"]["draws"]) == w[0] and int(r["measured"]["nodes"]) == w[1] and int(r["draws"]) == w[2] and int(r["nodes"]) == w[3],
				"%s row: measured %d draw calls, %d nodes; allowance %d / %d" % [s, w[0], w[1], w[2], w[3]])
	# the worst screen in the game is named, with its allowance above the hard limit
	var chem = rows.get("08f_chemistry_lower", {})
	check.call(chem is Dictionary and int(chem["draws"]) == 165, "Chemistry scrolled keeps the 165 draw-call allowance (a legacy exception to the hard 100)")
	# negative control on the real file: one more draw call than any row allows fails that row, exactly at the allowance passes
	var all_ok := true
	var all_bad := true
	for s in rows:
		var r: Dictionary = rows[s]
		if r.get("status") != "legacy":
			continue
		if _fails(s, _m(int(r["draws"]), int(r["nodes"])), d) != 0:
			all_ok = false
		if _fails(s, _m(int(r["draws"]) + 1, int(r["nodes"])), d) == 0 or _fails(s, _m(int(r["draws"]), int(r["nodes"]) + 1), d) == 0:
			all_bad = false
	check.call(all_ok, "every real row passes at exactly its allowance")
	check.call(all_bad, "every real row fails one draw call or one node over its allowance")


func _legacy_rows(check: Callable) -> void:
	var d := _table({"a": _legacy(40, 50)})   # allowance 45 draw calls, 55 nodes
	check.call(_fails("a", _m(45, 55), d) == 0, "legacy: at the allowance passes")
	check.call(_fails("a", _m(46, 55), d) == 1, "legacy: one draw call over the allowance fails")
	check.call(_fails("a", _m(45, 56), d) == 1, "legacy: one node over the allowance fails")
	check.call(_fails("a", _m(60, 70), d) == 2, "legacy: both over gives two failures")
	var j: Dictionary = Gate.judge("a", _m(46, 55), d)
	check.call(j["mode"] == "legacy" and String(j["fails"][0]).contains("46 draw calls") and String(j["fails"][0]).contains("allowance 45"), "legacy failure line names the number and the allowance (%s)" % (j["fails"][0] if not j["fails"].is_empty() else ""))
	# a legacy allowance replaces the hard limit for draws and nodes (Chemistry scrolled: 165 against 100)
	var chem := _table({"c": {"status": "legacy", "measured": {"draws": 150, "nodes": 114}, "draws": 165, "nodes": 130}})
	check.call(_fails("c", _m(150, 114), chem) == 0 and _fails("c", _m(166, 114), chem) == 1, "legacy 165 allowance passes 150 and fails 166, above the hard 100")
	# the ratchet: a state that now needs less prints "tighten to N"
	var t: Dictionary = Gate.judge("a", _m(30, 40), d)
	check.call("tighten draws to 35" in t["notes"] and "tighten nodes to 45" in t["notes"] and t["fails"].is_empty(), "legacy: 'tighten to N' printed when the state needs less (%s)" % ", ".join(t["notes"]))
	var u: Dictionary = Gate.judge("a", _m(40, 50), d)
	check.call(u["notes"].is_empty(), "legacy: no tighten note at the measured value")
	var v: Dictionary = Gate.judge("a", _m(42, 52), d)
	check.call(v["notes"].is_empty(), "legacy: no tighten note when the allowance is still the right size for the state")


func _no_row(check: Callable) -> void:
	var d := _table({"a": _legacy(40, 50)})
	var j: Dictionary = Gate.judge("unknown", _m(100, 200), d)
	check.call(j["mode"] == "norow" and j["fails"].is_empty() and j["notes"].size() == 1 and String(j["notes"][0]).begins_with("NO ROW"), "missing row: 100 draw calls and 200 nodes pass and print NO ROW")
	check.call(_fails("unknown", _m(101, 100), d) == 1 and _fails("unknown", _m(50, 201), d) == 1, "missing row: defaults to the hard limits (101 draw calls fails, 201 nodes fails)")
	var j2: Dictionary = Gate.judge("unknown", _m(101, 100), d)
	check.call(String(j2["fails"][0]).contains("hard limit 100"), "missing row failure names the hard limit (%s)" % j2["fails"][0])
	# no file at all: the same
	var f: Dictionary = Gate.load_file("res://tests/does_not_exist.json")
	check.call(not f["ok"] and (f["data"] as Dictionary).is_empty() and not (f["problems"] as Array).is_empty(), "missing allowance file is reported, not silently ignored")
	check.call(_fails("x", _m(101, 10), f["data"]) == 1 and _fails("x", _m(100, 200), f["data"]) == 0, "missing allowance file: hard limits apply to every state")
	# a state with a row whose status is unreadable also falls back to the hard limits
	var odd := _table({"b": {"status": "legacy"}})
	check.call(Gate.judge("b", _m(10, 10), odd)["mode"] == "norow", "a legacy row without numbers is treated as no row")
	var g: Array = Gate.stale_rows(_table({"a": _legacy(1, 1), "gone": _legacy(1, 1)}), ["a", "new"])
	check.call(g == ["gone"], "stale_rows lists a row the tour no longer visits")


func _redesigned(check: Callable) -> void:
	var d := _table({"r": {"status": "redesigned", "since": "I-15"},
			"w": {"status": "redesigned", "since": "I-17", "waiver": {"nodes": 140, "reason": "two tab pages built at once", "approved_by": "Technical Director"}},
			"big": {"status": "redesigned", "since": "I-17", "waiver": {"draws": 150, "reason": "x", "approved_by": "TD"}}})
	check.call(_fails("r", _m(60, 120), d) == 0, "redesigned: exactly the target (60 draw calls, 120 nodes) passes")
	check.call(_fails("r", _m(61, 120), d) == 1 and _fails("r", _m(60, 121), d) == 1, "redesigned: one over the target fails with no waiver")
	check.call(_fails("w", _m(60, 140), d) == 0 and _fails("w", _m(60, 141), d) == 1, "redesigned: a waiver of 140 nodes passes 140 and fails 141")
	check.call(_fails("w", _m(61, 130), d) == 1, "redesigned: a nodes waiver does not loosen draw calls")
	check.call(_fails("big", _m(100, 100), d) == 0 and _fails("big", _m(101, 100), d) == 1, "redesigned: a waiver above the hard limit is capped at the hard limit (100)")
	check.call(not Gate.validate(d).is_empty(), "validate flags the waiver that is above the hard limit")
	var j: Dictionary = Gate.judge("r", _m(10, 10), d)
	check.call(j["mode"] == "redesigned" and j["notes"].is_empty(), "redesigned row prints no tighten note")


func _other_limits(check: Callable) -> void:
	var d := _table({"a": _legacy(40, 50)})
	check.call(_fails("a", _m(10, 10, {"canvas": 1200}), d) == 0 and _fails("a", _m(10, 10, {"canvas": 1201}), d) == 1, "canvas items: 1,200 passes, 1,201 fails")
	check.call(_fails("a", _m(10, 10, {"tex": 48 * 1048576}), d) == 0 and _fails("a", _m(10, 10, {"tex": 48 * 1048576 + 1}), d) == 1, "texture memory: 48 MB passes, one byte more fails")
	check.call(_fails("a", _m(10, 10, {"vid": 64 * 1048576 + 1}), d) == 1, "video memory over 64 MB fails")
	check.call(_fails("a", _m(10, 10, {"tree": 251}), d) == 1 and _fails("a", _m(10, 10, {"tree": 250}), d) == 0, "whole tree: 250 passes, 251 fails")
	check.call(_fails("a", _m(10, 10, {"shadows": 6}), d) == 0 and _fails("a", _m(10, 10, {"shadows": 7}), d) == 1, "shadow gate: 6 passes, 7 fails")
	check.call(_fails("a", _m(10, 10, {"glows": 2}), d) == 0 and _fails("a", _m(10, 10, {"glows": 3}), d) == 1, "glow gate: 2 passes, 3 fails")
	var j: Dictionary = Gate.judge("a", _m(10, 10, {"canvas": 800}), d)
	check.call(j["over_target"] and j["fails"].is_empty(), "canvas items over the 700 target are counted, not failed")
	var ex := {"version": 1, "rows": {}, "canvas_target_exceptions": ["about"]}
	check.call(not Gate.judge("about", _m(10, 10, {"canvas": 1018}), ex)["over_target"] and Gate.judge("other", _m(10, 10, {"canvas": 1018}), ex)["over_target"], "a named canvas exception is not counted over target, any other state is")
	check.call(Gate.judge_font_cache(16, d)["fail"] == "" and Gate.judge_font_cache(17, d)["fail"] != "" and Gate.judge_font_cache(13, d)["over_target"] and not Gate.judge_font_cache(12, d)["over_target"], "font cache: 16 passes, 17 fails, 13 is over the 12 target")


func _validation(check: Callable) -> void:
	check.call(Gate.validate(_table({"a": _legacy(40, 50)})).is_empty(), "validate: a correct legacy row is clean")
	check.call(not Gate.validate({"version": 1}).is_empty(), "validate: no rows object is a problem")
	check.call(not Gate.validate(_table({"a": {"status": "legacy", "draws": 45}})).is_empty(), "validate: legacy row missing nodes and measured is a problem")
	check.call(not Gate.validate(_table({"a": {"status": "soon"}})).is_empty(), "validate: unknown status is a problem")
	# the ratchet only goes down
	var up := _legacy(40, 50)
	up["draws"] = 50   # measured 40 allows 45
	check.call(not Gate.validate(_table({"a": up})).is_empty(), "validate: an allowance above measured + 10 percent without a raise is a problem")
	up["raise"] = {"reason": "I-04 reflow", "approved_by": ""}
	check.call(not Gate.validate(_table({"a": up})).is_empty(), "validate: a raise with no approver is still a problem")
	up["raise"] = {"reason": "I-04 reflow", "approved_by": "Technical Director"}
	check.call(Gate.validate(_table({"a": up})).is_empty(), "validate: a raise with reason and approver is accepted")
	var down := _legacy(40, 50)
	down["draws"] = 42
	check.call(Gate.validate(_table({"a": down})).is_empty(), "validate: tightening an allowance is allowed")
	var w := {"status": "redesigned", "waiver": {"nodes": 130, "reason": "", "approved_by": "TD"}}
	check.call(not Gate.validate(_table({"a": w})).is_empty(), "validate: a waiver with no reason is a problem")
	w["waiver"] = {"nodes": 130, "reason": "two pages", "approved_by": "TD"}
	check.call(Gate.validate(_table({"a": w})).is_empty(), "validate: a waiver with reason and name is clean")
	w["waiver"] = {"reason": "two pages", "approved_by": "TD"}
	check.call(not Gate.validate(_table({"a": w})).is_empty(), "validate: a waiver naming no number is a problem")
	var lw := _legacy(40, 50)
	lw["waiver"] = {"nodes": 60, "reason": "x", "approved_by": "TD"}
	check.call(not Gate.validate(_table({"a": lw})).is_empty(), "validate: a legacy row cannot carry a waiver")


func _file_round_trip(check: Callable) -> void:
	var path := "user://perf_gate_test_table.json"
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string(JSON.stringify({"version": 1, "rows": {"a": {"status": "legacy", "measured": {"draws": 40, "nodes": 50}, "draws": 99, "nodes": 55}}}))
	bad.close()
	var f: Dictionary = Gate.load_file(path)
	check.call(not f["ok"] and not (f["problems"] as Array).is_empty(), "a hand-raised allowance in a file is reported by load_file (%s)" % ("; ".join(f["problems"])))
	var junk := FileAccess.open(path, FileAccess.WRITE)
	junk.store_string("not json at all")
	junk.close()
	var g: Dictionary = Gate.load_file(path)
	check.call(not g["ok"] and (g["data"] as Dictionary).is_empty(), "an unparsable allowance file is reported and gives hard limits only")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _box(shadow: int, color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.shadow_size = shadow
	sb.shadow_color = color
	return sb


func _shadow_counter(check: Callable) -> void:
	var root := Control.new()
	var neutral := PanelContainer.new()
	neutral.add_theme_stylebox_override("panel", _box(12, Color(0, 0, 0, 0.38)))
	var coral := Button.new()
	coral.add_theme_stylebox_override("normal", _box(16, Color(1.0, 0.36, 0.3, 0.42)))
	var flat := PanelContainer.new()
	flat.add_theme_stylebox_override("panel", _box(0, Color(0, 0, 0, 0.38)))
	var clear := PanelContainer.new()
	clear.add_theme_stylebox_override("panel", _box(12, Color(0, 0, 0, 0.0)))
	var hidden := PanelContainer.new()
	hidden.visible = false
	hidden.add_theme_stylebox_override("panel", _box(12, Color(0, 0, 0, 0.38)))
	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", _box(8, Color(0, 0, 0, 0.3)))
	hidden.add_child(inner)
	var nested := PanelContainer.new()
	var inner2 := PanelContainer.new()
	inner2.add_theme_stylebox_override("panel", _box(8, Color(0.1, 0.1, 0.12, 0.5)))
	nested.add_child(inner2)
	for n in [neutral, coral, flat, clear, hidden, nested]:
		root.add_child(n)
	var c: Dictionary = Gate.count_shadows(root)
	check.call(c["shadows"] == 2 and c["glows"] == 1, "shadow counter: 2 neutral shadows (one nested), 1 coloured glow; flat, transparent and hidden ones not counted (%d, %d)" % [c["shadows"], c["glows"]])
	check.call(Gate.count_shadows(Control.new())["shadows"] == 0, "shadow counter: an empty control has none")
	# the gate fires: seven shadowed panels is over 6
	var seven := Control.new()
	for i in 7:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _box(10, Color(0, 0, 0, 0.4)))
		seven.add_child(p)
	var s: Dictionary = Gate.count_shadows(seven)
	check.call(s["shadows"] == 7 and _fails("x", _m(10, 10, {"shadows": s["shadows"]}), {"rows": {}}) == 1, "7 shadowed panels count as 7 and fail the shadow gate (limit 6)")
	root.free()
	seven.free()
