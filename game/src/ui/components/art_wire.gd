class_name ArtWire
extends RefCounted
## The one place that connects the component hooks to the art code of I-05 (build plan I-09):
##   wire_icons()      IconHook.draw_fn -> Icons.draw, through IconHook.art_id(id). An id the art set does not have ("dot", the
##                     chip icon of the neutral variant) keeps the placeholder drawing: ask E for a `dot` icon, or keep it.
##   prepare(club_ids, heroes)
##                     once per save (new game and load): the league's badge styles with their clash rules (BadgeStyle.set_league,
##                     one fixed list per save), the baked badge atlases (Badge.prepare), and the hero table of the silhouettes
##                     (Silhouette.register). Calling it again with the same lists is cheap and changes nothing.
##   ensure()          what a card does on its first draw, so a screen that forgot prepare() still shows art: wires the icons and,
##                     when the game world exists and prepare() has not run, prepares from App.world.
## None of it touches game state or results; it only tells the drawing code which clubs and heroes exist.

static var icons_wired := false
static var prepared := false
static var _club_key := ""
static var _hero_key := ""


static func _draw_icon(ci: CanvasItem, id: String, rect: Rect2, colour: Color) -> void:
	var art := IconHook.art_id(id)
	if Icons.has(art):
		Icons.draw(ci, art, rect, colour)
	else:
		IconHook.placeholder(ci, id, rect, colour)


static func wire_icons() -> void:
	IconHook.draw_fn = _draw_icon
	icons_wired = true


static func unwire_icons() -> void:
	IconHook.draw_fn = Callable()
	icons_wired = false


## Club ids (the league of the save, fixed per save) and hero rows (heroes.json: id, role_primary, archetype).
static func prepare(club_ids: Array, heroes: Array) -> void:
	wire_icons()
	var ck := ",".join(PackedStringArray(club_ids.map(func(x: Variant) -> String: return str(x))))
	if ck != _club_key:
		_club_key = ck
		BadgeStyle.set_league(club_ids)
		Badge.prepare(BadgeStyle.resolve(club_ids))
	var hk := str(heroes.size())
	if hk != _hero_key or not prepared:
		_hero_key = hk
		Silhouette.register(heroes)
	prepared = true


static func ensure() -> void:
	if not icons_wired:
		wire_icons()
	if not prepared:
		var w: Variant = App.world if is_instance_valid(App) else null
		if w != null:
			prepare((w as World).club_ids, (w as World).heroes.values())


## Forget everything (tests that want the default state again).
static func reset() -> void:
	unwire_icons()
	prepared = false
	_club_key = ""
	_hero_key = ""
