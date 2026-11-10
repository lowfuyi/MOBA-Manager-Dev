extends Control
## Spike S1 carousel (build plan I-01): a horizontal card row that lives inside a vertical page.
## Two modes, so the failure and the fix are measured side by side:
##   "naive"  : a plain horizontal ScrollContainer (what a first implementation would be). It takes every drag that
##              moves it by even one pixel, so a mostly vertical diagonal swipe that starts on it moves the row and
##              the page does not scroll (scratch probe result of the plan, K2).
##   "locked" : the direction lock. The carousel is a clipped Control that moves its own content. After LOCK_PX
##              (12 px) of finger travel it decides once per touch: horizontal when |dx| > |dy|, otherwise vertical.
##              Horizontal: it moves the cards and swallows the drag. Vertical: it stops swallowing, so the drag
##              reaches the parent ScrollContainer, which scrolls the page. Until the decision it swallows the
##              drag (the page does not twitch). Cards must be MOUSE_FILTER_PASS so touch events reach the carousel.
## No class_name on purpose (no --import needed); this is the reference for the I-08 `Carousel` component.

const LOCK_PX := 12.0

var dbg := false
var mode := "locked"
var card_w := 220.0
var gap := 14.0
var cards: Array[Button] = []
var log_pressed: Array = []                  # card indexes whose `pressed` fired (tap detection)
var decisions: Array = []                    # "h" / "v" per touch that reached the lock

var _content: HBoxContainer
var _naive: ScrollContainer
var _state := 0                              # 0 idle, 1 undecided, 2 horizontal, 3 vertical
var _acc := Vector2.ZERO
var _x := 0.0


func setup(m: String, n_cards: int, h: float) -> void:
	mode = m
	custom_minimum_size = Vector2(0, h)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", int(gap))
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	for i in n_cards:
		var b := Button.new()
		b.text = "Card %d" % i
		b.custom_minimum_size = Vector2(card_w, h)
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.pressed.connect(func() -> void: log_pressed.append(i))
		_content.add_child(b)
		cards.append(b)
	if mode == "naive":
		_naive = ScrollContainer.new()
		_naive.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		_naive.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_naive.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_naive.add_child(_content)
		add_child(_naive)
	else:
		add_child(_content)
		_content.position = Vector2.ZERO


func h_offset() -> float:
	if mode == "naive":
		return float(_naive.scroll_horizontal)
	return _x


func max_offset() -> float:
	return maxf(0.0, _content.get_combined_minimum_size().x - size.x)


func set_h_offset(v: float) -> void:
	if mode == "naive":
		_naive.scroll_horizontal = int(v)
	else:
		_x = clampf(v, 0.0, max_offset())
		_content.position.x = -_x


func _gui_input(event: InputEvent) -> void:
	if dbg:
		print("gi ", event.as_text(), " state=", _state)
	if mode != "locked":
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_state = 1
			_acc = Vector2.ZERO
		else:
			_state = 0
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _state == 1:
			_acc += sd.relative
			if _acc.length() >= LOCK_PX:
				if absf(_acc.x) > absf(_acc.y):
					_state = 2
					decisions.append("h")
				else:
					_state = 3
					decisions.append("v")
				_cancel_card_press()
				if _state == 2:
					set_h_offset(h_offset() - _acc.x)     # catch up with the travel swallowed so far
			accept_event()                                # undecided: swallow, the page does not twitch
		elif _state == 2:
			set_h_offset(h_offset() - sd.relative.x)
			accept_event()
		# _state 3: not accepted, the parent ScrollContainer gets the drag and scrolls the page


## A press that turned into a drag must not become a tap on the card under the finger. Setting `disabled`
## clears a Button's press state (press_attempt / pressing_inside); it is set back at once, so nothing looks different.
func _cancel_card_press() -> void:
	for b in cards:
		b.disabled = true
	for b in cards:
		b.disabled = false
