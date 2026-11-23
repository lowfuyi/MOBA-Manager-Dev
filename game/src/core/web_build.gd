class_name WebBuild
extends RefCounted
## The web playtest build (0.11.1 web, Founder request of 2026-11-22): what differs in a browser. tools/build_web.sh writes
## res://build_info.json ({build, feedback_url, built}) just before the export and deletes it after, so it is never
## committed and the phone build has none. Static and data-only (no node in a static var).

const INFO_PATH := "res://build_info.json"

static var _info: Dictionary = {}
static var _read := false


## Running in a browser (the web export), not an installed app.
static func is_web() -> bool:
	return OS.has_feature("web")


static func info() -> Dictionary:
	if not _read:
		_read = true
		var f := FileAccess.open(INFO_PATH, FileAccess.READ)
		if f != null:
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary:
				_info = data
	return _info


## What testers quote: the web build id (version, commit, time), else the version label.
static func build_id(version_label: String) -> String:
	return String(info().get("build", version_label))


## The tester feedback form, set when the web build is made; "" = none (the feedback note is still copied).
static func feedback_url() -> String:
	return String(info().get("feedback_url", ""))


## Web: keep the portrait 9:16 frame with bars on wide screens (desktop, a phone turned sideways); tall phones keep the
## full height (the tall layout every screen already supports). Returns the aspect it chose.
static func fit(root: Window) -> Window.ContentScaleAspect:
	var s := root.size
	var a := Window.CONTENT_SCALE_ASPECT_KEEP if s.x * 16 > s.y * 9 else Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_aspect = a
	return a


static var _probe_cb: JavaScriptObject = null    # a JavaScript callback (RefCounted), never a node


## Browser test probe (Playwright, 0.11.1 web), only with ?probe=1 in the page address: window.glProbe() fills
## window.glProbeOut with the current screen and every visible button (text, tag, rect in window pixels), so a test can
## tap real buttons by their text. Testers never see it; it reads, it never changes the game.
static func install_probe(tree: SceneTree) -> void:
	if not is_web() or _probe_cb != null:
		return
	if not String(JavaScriptBridge.eval("location.search")).contains("probe=1"):
		return
	_probe_cb = JavaScriptBridge.create_callback(func(_args: Array) -> void:
		var win := JavaScriptBridge.get_interface("window")
		win.glProbeOut = JSON.stringify(probe(tree)))
	JavaScriptBridge.get_interface("window").glProbe = _probe_cb


static func probe(tree: SceneTree) -> Dictionary:
	var out := {"screen": "", "buttons": [], "labels": [], "fps": Engine.get_frames_per_second(), "build": build_id("")}
	var main = tree.root.get_node_or_null("Main")
	if main == null:
		for c in tree.root.get_children():
			if c is Control:
				main = c
	var cur = main.get("_current") if main != null else null
	if cur != null and cur.get_script() != null:
		out["screen"] = String(cur.get_script().resource_path.get_file().get_basename())
	_walk(tree.root, out)
	out["timings"] = App.timings.lines()   # the tester timings (Q1), so browser runs can read them
	return out


static func _walk(n: Node, out: Dictionary) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is Control:
		var c := n as Control
		var xf := c.get_viewport().get_final_transform() * c.get_global_transform_with_canvas()
		var r := Rect2(xf * Vector2.ZERO, xf.basis_xform(c.size))
		if n is BaseButton and not (n as BaseButton).disabled:
			var t := String(n.get("text")) if n.get("text") != null else ""
			(out["buttons"] as Array).append({"text": t, "name": String(n.name), "tag": String(c.get_meta(UI.TAG_META, "")),
					"rect": [r.position.x, r.position.y, r.size.x, r.size.y]})
		elif n is Label and (out["labels"] as Array).size() < 60:
			(out["labels"] as Array).append(String((n as Label).text).left(80))
	for ch in n.get_children():
		_walk(ch, out)
