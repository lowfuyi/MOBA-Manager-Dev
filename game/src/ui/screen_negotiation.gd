class_name ScreenNegotiation
extends Screen
## One player's contract talk: signing a free agent or renewing a final-year contract (GDD 7.2).
## Up to three offers; the player only ever answers "close", "below" or "far below", never the number.

var _pid: String
var _renewal: bool
var _from: String
var _wage := 0
var _len := 2
var _msg := ""
var _msg_color: Color = UI.DIM
var _done := false


func _init(pid: String = "", renewal: bool = false, from: String = "fa:hub") -> void:
	super._init()
	_pid = pid
	_renewal = renewal
	_from = from


func go_back() -> void:
	App.autosave()
	if _from.begins_with("fa:"):
		App.go(ScreenFreeAgents.new(_from.substr(3)))
	elif _from == "roster":
		App.go(ScreenRoster.new("hub"))
	elif _from == "season":
		App.go(ScreenSeasonEnd.new())
	else:
		App.go(ScreenFreeAgents.new())


func _ready() -> void:
	setup(Strings.t("neg.title_renew" if _renewal else "neg.title_sign"), go_back)
	var gs := App.gs
	var ask := gs.asking_wage(_pid)
	_wage = maxi(ask, int(gs.contract_of(_pid).get("wage", 0))) if _renewal else ask
	_rebuild()


func _rebuild() -> void:
	UI.clear(body)
	var gs := App.gs
	var w := App.world
	var p: Dictionary = w.players[_pid]
	var head := UI.card(body, UI.PANEL2)
	head.add_child(UI.label(p["name"], UI.S_TITLE, UI.TEXT))
	head.add_child(UI.label(Strings.f("neg.who", {"role": Strings.t("role." + p["role_primary"]), "age": w.age_of(p), "rating": "%.0f" % Economy.best_slot_rating(w, p),
			"pot": "%.0f" % Economy.potential_rating(w, p)}), UI.S_BODY, UI.ACCENT))
	head.add_child(UI.label(Strings.f("roster.detail", {"personality": Strings.t("personality." + p["personality"]), "country": p["country"]}), UI.S_SMALL, UI.DIM))
	head.add_child(UI.label(Strings.t("neg.personality_hint." + p["personality"]), UI.S_SMALL, UI.DIM))
	if _done:
		var okc := UI.card(body, UI.PANEL2)
		okc.add_child(UI.label(_msg, UI.S_BODY, UI.GOOD))
		okc.add_child(UI.button(Strings.t("common.continue"), go_back, "primary"))
		_stats(p)
		return
	var c := UI.card(body)
	if _renewal:
		c.add_child(UI.label(Strings.f("neg.current", {"line": PlayerView.contract_text(_pid)}), UI.S_SMALL, UI.DIM))
	c.add_child(UI.label(Strings.f("neg.asking", {"wage": gs.asking_wage(_pid)}), UI.S_SMALL, UI.DIM))
	c.add_child(UI.label(Strings.f("neg.offer_wage", {"wage": _wage}), UI.S_BIG, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var steps := UI.hbox()
	for dlt in [-5, -1, 1, 5]:
		steps.add_child(UI.button("%+d" % dlt, _adj.bind(dlt), "normal", 80))
	c.add_child(steps)
	c.add_child(UI.label(Strings.t("neg.length"), UI.S_SMALL, UI.DIM))
	var lens := UI.hbox()
	for n in range(1, int(Economy.data()["max_length"]) + 1):
		lens.add_child(UI.button(str(n), _set_len.bind(n), "primary" if n == _len else "normal", 80))
	c.add_child(lens)
	if not _renewal:
		c.add_child(UI.label(Strings.f("neg.fee", {"fee": PlayerView.money(gs.signing_fee(_wage))}), UI.S_SMALL, UI.TEXT))
	var cur := float(gs.contract_of(_pid).get("wage", 0.0)) if _renewal else 0.0
	var after := gs.wage_bill() - cur + float(_wage)
	c.add_child(UI.label(Strings.f("neg.budget", {"cash": PlayerView.money(gs.cash()), "bill": PlayerView.money(after), "cap": PlayerView.money(gs.wage_cap())}), UI.S_SMALL,
			UI.BAD if after > gs.wage_cap() else UI.DIM))
	var block := gs.offer_block(_pid, _wage, _renewal)
	if block != "":
		c.add_child(UI.label(_block_text(block), UI.S_SMALL, UI.WARN))
	if _msg != "":
		c.add_child(UI.label(_msg, UI.S_BODY, _msg_color))
	var left := int(Economy.data()["negotiation_rounds"]) - gs.negotiation_rounds_used(_pid)
	c.add_child(UI.label(Strings.f("neg.rounds_left", {"n": left}), UI.S_SMALL, UI.DIM))
	var b := UI.button(Strings.t("neg.make_offer"), _make_offer, "primary")
	b.disabled = block != ""
	c.add_child(b)
	_stats(p)


func _stats(p: Dictionary) -> void:
	var st := UI.card(body)
	PlayerView.stat_block(st, p, false)
	PlayerView.best_heroes_line(st, p)


func _block_text(block: String) -> String:
	var gs := App.gs
	match block:
		"locked":
			return Strings.f("neg.block.locked", {"n": gs.lockout_left(_pid)})
		"cap":
			return Strings.f("neg.block.cap", {"cap": PlayerView.money(gs.wage_cap())})
	return Strings.t("neg.block." + block)


func _adj(dlt: int) -> void:
	_wage = maxi(1, _wage + dlt)
	_rebuild()


func _set_len(n: int) -> void:
	_len = n
	_rebuild()


func _make_offer() -> void:
	var gs := App.gs
	var res := gs.offer(_pid, _wage, _len, _renewal)
	var code: String = res["code"]
	var name: String = App.world.players[_pid]["name"]
	match code:
		"accepted":
			_msg = Strings.f("neg.accepted_renew" if _renewal else "neg.accepted", {"name": name, "wage": _wage, "n": _len})
			_msg_color = UI.GOOD
			_done = true
		"close", "below", "far":
			_msg = Strings.f("neg.say." + code, {"name": name})
			_msg_color = UI.WARN if code == "close" else UI.BAD
		"walked":
			_msg = Strings.f("neg.say.walked", {"name": name, "n": gs.lockout_left(_pid)})
			_msg_color = UI.BAD
		_:
			_msg = ""
	App.autosave()
	_rebuild()
