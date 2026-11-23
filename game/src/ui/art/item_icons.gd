class_name ItemIcons
extends RefCounted
## Placeholder item icons (0.12, overnight Q5), drawn in code as small SVGs and baked once into one atlas (TexCache, 64 px
## cells, 512 px wide), so a row of items costs one draw call. Shape says the tier (a circle for a component, a rounded
## square for a finished item, a boot plate for boots); the edge colour says the class (carry, mage, tank, fighter, support,
## boots: the role colours, rings and glyphs only); the glyph says the main stat; a gold pip marks an item with a special
## effect. Original shapes, no text. Real art replaces these later (docs/design/ART-PRODUCTION-BRIEF.md A5).

const CELL := 64
const BOX := 64.0
const ATLAS := "items@64"
const CLASS_COL := {"carry": "#EFD139", "mage": "#68DCF3", "tank": "#9797F7", "fighter": "#B7F797", "support": "#F36896", "boots": "#B9C8DA", "": "#96AAC4"}
const NORM := {"atk": 60.0, "ap": 100.0, "hp": 500.0, "armor": 60.0, "resist": 50.0, "aspd": 0.4, "crit": 0.25, "haste": 20.0,
		"move": 0.1, "lifesteal": 0.15, "omnivamp": 0.12, "pen_armor": 0.3, "pen_resist": 0.3, "heal_power": 0.2, "shield_power": 0.15}
const GLYPH := {
	"atk": "<path d='M19 45 L41 23 L46 18 L44 25 L22 47 Z'/><path d='M17 39 L25 47' stroke='#EAF0F7' stroke-width='4' stroke-linecap='round'/>",
	"ap": "<path d='M32 15 L36 28 L49 32 L36 36 L32 49 L28 36 L15 32 L28 28 Z'/>",
	"hp": "<path d='M32 46 C20 38 17 30 23 24 C27 20 32 23 32 27 C32 23 37 20 41 24 C47 30 44 38 32 46 Z'/>",
	"armor": "<path d='M32 16 L45 21 L45 31 C45 40 39 45 32 48 C25 45 19 40 19 31 L19 21 Z'/>",
	"resist": "<circle cx='32' cy='32' r='11' fill='none' stroke='#EAF0F7' stroke-width='5'/><circle cx='32' cy='32' r='4'/>",
	"aspd": "<path d='M18 42 L30 22 M28 42 L40 22 M38 42 L50 22' stroke='#EAF0F7' stroke-width='4' stroke-linecap='round'/>",
	"crit": "<path d='M32 14 L35 27 L47 20 L39 31 L50 36 L37 37 L41 50 L32 40 L23 50 L27 37 L14 36 L25 31 L17 20 L29 27 Z'/>",
	"haste": "<path d='M21 17 H43 L34 32 L43 47 H21 L30 32 Z'/>",
	"move": "<path d='M18 20 L30 32 L18 44 M32 20 L44 32 L32 44' fill='none' stroke='#EAF0F7' stroke-width='5' stroke-linecap='round' stroke-linejoin='round'/>",
	"lifesteal": "<path d='M32 16 C38 26 43 33 43 38 A11 11 0 0 1 21 38 C21 33 26 26 32 16 Z'/>",
	"pen": "<path d='M16 32 H44' stroke='#EAF0F7' stroke-width='4'/><path d='M44 24 L52 32 L44 40 Z'/><path d='M30 20 V44' stroke='#EAF0F7' stroke-width='3' stroke-dasharray='4 3'/>",
	"heal_power": "<path d='M27 17 H37 V27 H47 V37 H37 V47 H27 V37 H17 V27 H27 Z'/>",
}


## The stat that best describes the item (biggest against a typical value); boots always show speed.
static func main_stat(it: Dictionary) -> String:
	if String(it["tier"]) in ["boots", "boots_base"]:
		return "move"
	var best := ""
	var bv := -1.0
	var stats: Dictionary = it["stats"]
	for k in stats:
		var v := float(stats[k]) / float(NORM.get(k, 1.0))
		if v > bv:
			bv = v
			best = String(k)
	return best


static func glyph_of(stat: String) -> String:
	if stat in ["pen_armor", "pen_resist"]:
		return GLYPH["pen"]
	if stat == "omnivamp":
		return GLYPH["lifesteal"]
	if stat == "shield_power":
		return GLYPH["armor"]
	return String(GLYPH.get(stat, GLYPH["ap"]))


static func svg_of(iid: String) -> String:
	var it := SimData.item(iid)
	var tier := String(it["tier"])
	var cls := String(it["class"])
	var edge := String(CLASS_COL.get("boots" if tier in ["boots", "boots_base"] else cls, CLASS_COL[""]))
	var plate := ""
	match tier:
		"component":
			plate = "<circle cx='32' cy='32' r='27' fill='#223A5E' stroke='%s' stroke-width='3'/>" % edge
		"boots", "boots_base":
			plate = "<path d='M9 12 H55 V44 Q55 56 43 56 H21 Q9 56 9 44 Z' fill='#1D3354' stroke='%s' stroke-width='3'/>" % edge
		_:
			plate = "<rect x='6' y='6' width='52' height='52' rx='11' fill='#1D3354' stroke='%s' stroke-width='3'/>" % edge
	var pip := "<circle cx='50' cy='14' r='5' fill='#F2C14E'/>" if String(it["effect"]) != "" else ""
	return "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>%s<g fill='#EAF0F7'>%s</g>%s</svg>" % [plate, glyph_of(main_stat(it)), pip]


static func ids() -> Array:
	var out: Array = []
	for it in SimData.items_doc()["items"]:
		out.append(String(it["id"]))
	return out


## The atlas of every item icon (built on first use, cached in TexCache).
static func atlas() -> Dictionary:
	if TexCache.has(ATLAS):
		return TexCache.atlas(ATLAS, [], CELL * 8)
	var cells: Array = []
	for iid in ids():
		cells.append({"key": iid, "svg": svg_of(iid), "box": BOX, "w": CELL})
	return TexCache.atlas(ATLAS, cells, CELL * 8)


## One icon as an AtlasTexture (for a Button's icon). Null if the item is unknown or its cell failed to bake.
static func tex(iid: String) -> Texture2D:
	var a := atlas()
	if not (a["rects"] as Dictionary).has(iid) or (a["failed"] as Array).has(iid):
		return null
	var at := AtlasTexture.new()
	at.atlas = a["tex"]
	at.region = a["rects"][iid]
	return at


## A row of item icons drawn by one control from the one atlas (one draw call), with a fallback plate if baking failed.
class Row extends Control:
	var items: Array = []
	var cell := 56.0
	var gap := 8.0

	func _init(p_items: Array, p_cell: float = 56.0) -> void:
		items = p_items.duplicate()
		cell = p_cell
		custom_minimum_size = Vector2(float(items.size()) * (cell + gap) - gap, cell)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var a := ItemIcons.atlas()
		for i in items.size():
			var iid := String(items[i])
			var r := Rect2(Vector2(float(i) * (cell + gap), 0.0), Vector2(cell, cell))
			if (a["rects"] as Dictionary).has(iid) and not (a["failed"] as Array).has(iid):
				draw_texture_rect_region(a["tex"], r, a["rects"][iid])
			else:
				draw_rect(r, UI.PANEL2)
