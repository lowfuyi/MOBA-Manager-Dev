class_name EventBus
extends Node
## A small message line for "something happened" (build plan I-03, TUTORIAL 7.5). The UI raises events by name
## ("tap:tab.squad", "screen:home", "draft:ban", "match:end"); the tutorial and the help system listen. It only
## carries news: nothing in the game reads an event to decide a result (build plan R6).
##
## Main creates one and stores it in App.bus. Every event goes into a bounded ring buffer (the last CAPACITY
## events) so a tutorial step can ask "has this already happened?" (`skip_if event_seen`). The buffer is bounded
## on purpose: an event older than CAPACITY newer ones is forgotten.

## Fired after the event is in the ring buffer. `data` is the dictionary given to emit() (never null).
signal raised(event_name: String, data: Dictionary)

const CAPACITY := 64

var _names: Array = []       # ring buffer, fixed size once full
var _datas: Array = []
var _seqs: Array = []
var _head := 0               # next slot to write
var _count := 0
var _seq := 0                # events raised so far; also the id of the newest one


func _init() -> void:
	_names.resize(CAPACITY)
	_datas.resize(CAPACITY)
	_seqs.resize(CAPACITY)


## Raise an event. Listeners connected to `raised` run at once, after the event is already visible to seen().
func emit(event_name: String, data: Dictionary = {}) -> void:
	_seq += 1
	_names[_head] = event_name
	_datas[_head] = data
	_seqs[_head] = _seq
	_head = (_head + 1) % CAPACITY
	_count = mini(_count + 1, CAPACITY)
	raised.emit(event_name, data)


## True when `event_name` is among the recent events. `since` (a value from sequence()) limits it to events
## raised after that point: `var mark := bus.sequence()` ... `bus.seen("draft:ban", mark)`.
func seen(event_name: String, since: int = 0) -> bool:
	return last(event_name, since) != -1


## The sequence number of the newest matching event, or -1. Sequence numbers rise by one per event.
func last(event_name: String, since: int = 0) -> int:
	for k in _count:
		var i := (_head - 1 - k + CAPACITY * 2) % CAPACITY
		if int(_seqs[i]) <= since:
			return -1
		if _names[i] == event_name:
			return int(_seqs[i])
	return -1


## The data of the newest matching event ({} when none is in the buffer).
func last_data(event_name: String) -> Dictionary:
	for k in _count:
		var i := (_head - 1 - k + CAPACITY * 2) % CAPACITY
		if _names[i] == event_name:
			return _datas[i]
	return {}


## How many events have been raised in total (not capped). Use it as a bookmark for seen(name, since).
func sequence() -> int:
	return _seq


## The names still in the buffer, oldest first (for tests and the debug line).
func recent() -> Array:
	var out: Array = []
	for k in range(_count - 1, -1, -1):
		out.append(_names[(_head - 1 - k + CAPACITY * 2) % CAPACITY])
	return out


## Forget the buffer (a new tutorial run starts from nothing). Does not reset sequence().
func clear() -> void:
	_head = 0
	_count = 0
	for i in CAPACITY:
		_names[i] = null
		_datas[i] = null
		_seqs[i] = 0
