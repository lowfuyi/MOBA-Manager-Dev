class_name HeroStat
extends VBoxContainer
## The one big number of a screen (UI-PASS-2 5.14): a Display 64 number that counts up, one sentence (32) and two chips,
## best (good) and worst (bad). Used in the Report; reusable for Home milestones. Text is passed in (Strings at the caller);
## `fmt` formats the number ("%.0f", "%+.1f"). set_value counts up from the held value when animations are on (UI.animate).
## Built once; set_value / set_sentence / set_best / set_worst change it in place (a chip text of "" hides that chip).

var value := 0.0
var fmt := "%.0f"
var sentence := ""
var applied := 0
var _num: Label
var _sentence: Label
var _chips: HFlowContainer
var _best: Chip
var _worst: Chip


func _init(p_value: float = 0.0, p_fmt: String = "%.0f", p_sentence: String = "", p_best: String = "", p_worst: String = "", p_tut_id: String = "") -> void:
	value = p_value
	fmt = p_fmt
	sentence = p_sentence
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", 8)
	_num = UI.num_label(fmt % value, UI.S_DISPLAY, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_num)
	_sentence = UI.label(sentence, UI.S_BODY, UI.TEXT2)
	add_child(_sentence)
	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", 10)
	_chips.add_theme_constant_override("v_separation", 10)
	_chips.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_chips)
	_best = Chip.new(p_best, "good")
	_best.visible = p_best != ""
	_chips.add_child(_best)
	_worst = Chip.new(p_worst, "bad")
	_worst.visible = p_worst != ""
	_chips.add_child(_worst)
	CompKit.tag(self, p_tut_id)


func set_value(v: float, count: bool = true) -> void:
	if is_equal_approx(v, value):
		return
	var from := value
	value = v
	applied += 1
	if count:
		UI.count_up(_num, v, fmt, from)    # the final text is set first, so with animations off it simply shows the answer
	else:
		_num.text = fmt % v


func set_sentence(v: String) -> void:
	if v == sentence:
		return
	sentence = v
	applied += 1
	_sentence.text = UI.tidy(v)


func set_best(v: String) -> void:
	if v == _best.text:
		return
	applied += 1
	_best.visible = v != ""
	_best.set_text(v)


func set_worst(v: String) -> void:
	if v == _worst.text:
		return
	applied += 1
	_worst.visible = v != ""
	_worst.set_text(v)


func number_text() -> String:
	return _num.text


func best_chip() -> Chip:
	return _best


func worst_chip() -> Chip:
	return _worst
