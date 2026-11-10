class_name ArtPalette
extends RefCounted
## The colours the art code needs, as plain constants, so the art classes (and their headless tests) never load ui.gd
## (ui.gd uses the Strings and App autoloads, which a `--script` run does not have). Values are ART-BIBLE section 3;
## `check_art.tscn` compares every constant here with the constant of the same name in `UI`, so a drifting token fails.

const VOID := Color("070d1a")
const BG := Color("0a1120")
const PANEL := Color("162842")
const PANEL2 := Color("223a5e")
const PANEL3 := Color("30507f")
const TEXT := Color("eaf0f7")
const TEXT2 := Color("b9c8da")
const DIM := Color("96aac4")
const TEXT_OFF := Color("62748c")
const INK_TEAL := Color("04120f")
const INK_CORAL := Color("1c0b04")
const ACCENT := Color("3fd0b8")
const TEAL_HI := Color("7be3d2")
const CORAL := Color("ff8a5c")
const WARN := Color("f2c14e")
const BAD_DEFAULT := Color("f58080")
const SIDE_BLUE := Color("5aa9ff")
const SIDE_RED := Color("f58080")
const ROLE_TOP := Color("9797f7")
const ROLE_JUNGLE := Color("b7f797")
const ROLE_MID := Color("68dcf3")
const ROLE_BOT := Color("efd139")
const ROLE_SUPPORT := Color("f36896")

## Data role ids (heroes.json role_primary, players.json role_primary) in slot order.
const ROLES := ["top", "jg", "mid", "bot", "sup"]
const ROLE_LETTER := {"top": "T", "jg": "J", "mid": "M", "bot": "B", "sup": "S"}


static func role_color(role: String) -> Color:
	match role:
		"top": return ROLE_TOP
		"jg": return ROLE_JUNGLE
		"mid": return ROLE_MID
		"bot": return ROLE_BOT
		"sup": return ROLE_SUPPORT
	return DIM
