class_name Timings
extends RefCounted
## Tester timings (0.12, overnight Q1): real numbers from the tester's own phone or browser, carried in the debug lines and
## the "Copy feedback note" text (App.debug_info), so feedback brings phone speed with it. Session only: nothing is saved,
## nothing is sent anywhere. Measures: the device and browser, how long a draft stays open (the human draft time, AI turns
## included), the time from Start the match to the first arena frame (the game start after the draft), and arena frame times
## per match view (Field, Action, All). Never feeds a result (R7). Data only: no node is kept here.

const KEEP := 20                # last drafts and starts kept
const SETTLE_S := 1.0           # arena frames in the first second after the match screen opens are not counted (loading)
const SLOW_MS := 33.4           # a frame slower than 30 fps

var draft_t0 := -1              # msec when the current draft opened (-1 = none open)
var drafts: Array = []          # seconds per finished draft
var launch_t0 := -1             # msec when Start the match was tapped (-1 = none waiting)
var starts: Array = []          # msec from Start the match to the first arena frame
var frames: Dictionary = {}     # view id -> [frames, total ms, worst ms, slow frames]


static func now() -> int:
	return Time.get_ticks_msec()


## A new draft opened (a fresh draft; coming back to a finished one does not count).
func draft_opened(t: int = -1) -> void:
	draft_t0 = now() if t < 0 else t


## The draft is complete. Returns the seconds it took, or -1 if none was open.
func draft_done(t: int = -1) -> float:
	if draft_t0 < 0:
		return -1.0
	var s := float((now() if t < 0 else t) - draft_t0) / 1000.0
	draft_t0 = -1
	_keep(drafts, s)
	return s


## Start the match was tapped (before the game is simulated).
func launched(t: int = -1) -> void:
	launch_t0 = now() if t < 0 else t


## The first arena frame was shown. Returns the msec since Start the match, or -1.
func match_shown(t: int = -1) -> int:
	if launch_t0 < 0:
		return -1
	var ms := (now() if t < 0 else t) - launch_t0
	launch_t0 = -1
	_keep(starts, ms)
	return ms


## One arena frame of `dt` seconds in a view ("field", "action", "all"), `watch_s` seconds after the screen opened.
func frame(view: String, dt: float, watch_s: float) -> void:
	if watch_s < SETTLE_S or dt <= 0.0:
		return
	var ms := dt * 1000.0
	var f: Array = frames.get(view, [0, 0.0, 0.0, 0])
	f[0] = int(f[0]) + 1
	f[1] = float(f[1]) + ms
	f[2] = maxf(float(f[2]), ms)
	f[3] = int(f[3]) + (1 if ms > SLOW_MS else 0)
	frames[view] = f


static func _keep(a: Array, v: Variant) -> void:
	a.append(v)
	while a.size() > KEEP:
		a.pop_front()


static func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / float(a.size())


## The device and browser the tester is on (OS, model, graphics, screen, browser user agent on the web).
static func device_line() -> String:
	var parts: Array = [OS.get_name()]
	var model := OS.get_model_name()
	if model != "" and model != "GenericDevice":
		parts.append(model)
	var gpu := RenderingServer.get_video_adapter_name()
	if gpu != "":
		parts.append(gpu)
	var scr := DisplayServer.screen_get_size()
	parts.append("screen %dx%d" % [scr.x, scr.y])
	parts.append("cpus %d" % OS.get_processor_count())
	return "device=" + " | ".join(parts)


static func browser_line() -> String:
	if not OS.has_feature("web"):
		return ""
	var ua = JavaScriptBridge.eval("navigator.userAgent")
	return "browser=" + (String(ua).left(180) if ua != null else "?")


func lines() -> Array:
	var out: Array = [device_line()]
	var b := browser_line()
	if b != "":
		out.append(b)
	if not drafts.is_empty():
		out.append("draft time s last=%.0f avg=%.0f n=%d" % [float(drafts[-1]), _avg(drafts), drafts.size()])
	if not starts.is_empty():
		out.append("game start ms last=%d avg=%.0f n=%d" % [int(starts[-1]), _avg(starts), starts.size()])
	var views: Array = []
	for v in ["field", "action", "all"]:
		if frames.has(v):
			var f: Array = frames[v]
			views.append("%s avg=%.1f worst=%.0f slow=%d n=%d" % [v, float(f[1]) / maxf(1.0, float(f[0])), float(f[2]), int(f[3]), int(f[0])])
	if not views.is_empty():
		out.append("arena frame ms: " + "; ".join(views))
	return out
