class_name SaveCode
extends RefCounted
## Save codes (0.11.1 web playtest; Settings "Your save"): the whole save as one line of text, so a tester can keep a season
## when the browser clears its storage, or move it to another device. Format: "GLS1:" + the JSON's byte length + ":" +
## base64 of the gzipped save JSON (the same JSON as user://save.json). Nothing new is stored in the save itself.

const PREFIX := "GLS1:"
const MAX_BYTES := 64 * 1024 * 1024

static var _B64 := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")


static func encode(d: Dictionary) -> String:
	var raw := JSON.stringify(d).to_utf8_buffer()
	return PREFIX + str(raw.size()) + ":" + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))


## The save dictionary inside a code, or {} when the text is not a save of this version. Anything pasted is checked;
## spaces and line breaks (added by messenger apps) are ignored.
static func decode(code: String) -> Dictionary:
	var c := code.strip_edges().replace("\n", "").replace("\r", "").replace(" ", "")
	if not c.begins_with(PREFIX):
		return {}
	var rest := c.substr(PREFIX.length())
	var k := rest.find(":")
	if k <= 0 or not rest.substr(0, k).is_valid_int():
		return {}
	var n := int(rest.substr(0, k))
	if n <= 0 or n > MAX_BYTES:
		return {}
	var b64 := rest.substr(k + 1)
	if b64.length() % 4 != 0 or not _B64.search(b64):
		return {}    # checked first: the engine prints an error for bad base64
	var z := Marshalls.base64_to_raw(b64)
	if z.size() < 18 or z[0] != 0x1f or z[1] != 0x8b or z.decode_u32(z.size() - 4) != n:
		return {}    # gzip header, and its last 4 bytes (the length) must match: a cut code never reaches the decompressor
	var raw := z.decompress_dynamic(n, FileAccess.COMPRESSION_GZIP)
	if raw.size() != n:
		return {}
	var data = JSON.parse_string(raw.get_string_from_utf8())
	if not (data is Dictionary) or int(data.get("version", 0)) != GameState.VERSION:
		return {}
	for key in ["club", "season", "phase", "round", "save_seed"]:
		if not data.has(key):
			return {}
	return data


## A GameState from a code, or null.
static func state(code: String, w: World) -> GameState:
	var d := decode(code)
	return null if d.is_empty() else GameState.from_dict(w, d)
