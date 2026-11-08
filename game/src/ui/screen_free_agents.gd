class_name ScreenFreeAgents
extends Screen
## The free-agent market: every player without a club, with what he asks for (GDD 7.2).

const ROLES := ["all", "top", "jg", "mid", "bot", "sup"]
const SORTS := ["rating", "potential", "age", "price"]

var _role := 0
var _sort := 0
var _from: String


func _init(from: String = "hub") -> void:
	super._init()
	_from = from


func tab_id() -> String:
	match _from:
		"season":
			return ""
		"roster":
			return "squad"
	return "club"


func go_back() -> void:
	if _from == "season":
		App.go(ScreenSeasonEnd.new())
	elif _from == "roster":
		App.go(ScreenRoster.new("hub"))
	else:
		App.go_tab("club")


func _ready() -> void:
	setup(Strings.t("fa.title"), go_back)
	_rebuild()


func _rebuild() -> void:
	UI.clear(body)
	var gs := App.gs
	var w := App.world
	var head := UI.card(body, UI.PANEL2)
	head.add_child(UI.label(Strings.f("fa.squad", {"n": gs.roster_slots_used(), "max": Economy.data()["max_roster"]}), UI.S_BODY, UI.TEXT))
	head.add_child(UI.label(Strings.f("neg.budget", {"cash": PlayerView.money(gs.cash()), "bill": PlayerView.money(gs.wage_bill()), "cap": PlayerView.money(gs.wage_cap())}), UI.S_SMALL, UI.DIM))
	head.add_child(UI.label(Strings.t("fa.hint"), UI.S_SMALL, UI.DIM))
	var bar := UI.hbox()
	var role_txt := Strings.t("fa.role_all") if ROLES[_role] == "all" else Strings.t("role." + ROLES[_role])
	bar.add_child(UI.button(Strings.f("fa.filter", {"role": role_txt}), _next_role, "normal", 76))
	bar.add_child(UI.button(Strings.f("fa.sort", {"by": Strings.t("fa.sort." + SORTS[_sort])}), _next_sort, "normal", 76))
	body.add_child(bar)
	var ps := w.free_agent_players()
	var list: Array = []
	for p in ps:
		if ROLES[_role] != "all" and p["role_primary"] != ROLES[_role] and p.get("role_secondary", "") != ROLES[_role]:
			continue
		list.append(p)
	var key := func(p: Dictionary) -> float:
		match SORTS[_sort]:
			"potential":
				return Economy.potential_rating(w, p)
			"age":
				return -float(w.age_of(p))
			"price":
				return -float(gs.asking_wage(p["id"]))
		return Economy.best_slot_rating(w, p)
	list.sort_custom(func(a, b):
		var ka: float = key.call(a)
		var kb: float = key.call(b)
		return ka > kb or (ka == kb and String(a["id"]) < String(b["id"])))
	if list.is_empty():
		body.add_child(UI.label(Strings.t("fa.none"), UI.S_BODY, UI.DIM))
	for p in list:
		var tag := ""
		if gs.lockout_left(p["id"]) > 0:
			tag = "  -  " + Strings.t("fa.locked")
		var line := Strings.f("fa.row1", {"name": p["name"], "role": Strings.t("role." + p["role_primary"]), "age": w.age_of(p)}) + "\n" \
				+ Strings.f("fa.row2", {"rating": "%.0f" % Economy.best_slot_rating(w, p), "pot": "%.0f" % Economy.potential_rating(w, p), "wage": gs.asking_wage(p["id"])}) + tag
		body.add_child(UI.button(line, _open.bind(p["id"]), "normal", 104))


func _next_role() -> void:
	_role = (_role + 1) % ROLES.size()
	_rebuild()


func _next_sort() -> void:
	_sort = (_sort + 1) % SORTS.size()
	_rebuild()


func _open(pid: String) -> void:
	App.go(ScreenNegotiation.new(pid, false, "fa:" + _from))
