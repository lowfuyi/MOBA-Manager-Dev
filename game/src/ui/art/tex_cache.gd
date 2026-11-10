class_name TexCache
extends RefCounted
## One cache for every texture the art code makes. Key to texture, evicts nothing in Alpha 0.7 (the set is small and fixed),
## counts hits and misses, and tracks the bytes it holds so a test can hold it to the budget (PERF-BUDGET 3.2).
##
## SVG strings are rasterised once with Image.load_svg_from_string (ThorVG) and packed into ATLASES (one texture per
## family and size), because every texture switch is one more draw call: all icons of one size share one texture, all
## portrait parts share one. The raw texture size is validated against MAX_SIDE.
##
## If the SVG loader is missing or fails (it is in the Android export template, but nothing was run on a phone) the cell
## stays empty, `svg_failures` counts it, and the callers (Icons, Silhouette) draw their code fallback instead.

const BUDGET_BYTES := 8 * 1024 * 1024   # I-05 acceptance: texture memory after warm-up
const MAX_SIDE := 1024                    # PERF-BUDGET 3.2 target for the largest single texture
const ATLAS_SIDE_TARGET := 512            # PERF-BUDGET 3.2: the icon atlas is at most 512 x 512 (1024 hard)

static var _tex: Dictionary = {}          # key -> Texture2D or atlas Dictionary
static var _sizes: Dictionary = {}        # key -> bytes
static var _bytes := 0
static var hits := 0
static var misses := 0
static var svg_failures := 0
static var svg_calls := 0
static var force_fail := false            # test hook: every rasterise() fails, as if the SVG loader were missing
static var rasterise_usec := 0


static func reset() -> void:
	_tex.clear()
	_sizes.clear()
	_bytes = 0
	hits = 0
	misses = 0
	svg_failures = 0
	svg_calls = 0
	rasterise_usec = 0
	force_fail = false


static func bytes() -> int:
	return _bytes


static func count() -> int:
	return _tex.size()


static func has(key: String) -> bool:
	return _tex.has(key)


static func largest_side() -> int:
	var m := 0
	for k in _sizes:
		m = maxi(m, int(_sizes[k] >> 32))
	return m


## key -> texture; `maker` is called with no arguments only on a miss and must return an Image.
static func get_or_make(key: String, maker: Callable) -> Texture2D:
	if _tex.has(key) and _tex[key] is Texture2D:
		hits += 1
		return _tex[key]
	misses += 1
	var img: Image = maker.call()
	return _store(key, img)


static func _store(key: String, img: Image) -> Texture2D:
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	var b := img.get_width() * img.get_height() * 4
	_sizes[key] = b | (maxi(img.get_width(), img.get_height()) << 32)
	_bytes += b
	return tex


## Rasterise an SVG string; `scale` multiplies its declared size. Returns null when the loader is missing or fails.
static func rasterise(svg: String, scale: float) -> Image:
	svg_calls += 1
	if force_fail:
		svg_failures += 1
		return null
	var t0 := Time.get_ticks_usec()
	var img := Image.new()
	var err := img.load_svg_from_string(svg, scale)
	rasterise_usec += Time.get_ticks_usec() - t0
	if err != OK or img.is_empty():
		svg_failures += 1
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


## One SVG into one cached texture of `px` x `px` (the SVG is square). Null on failure (and the miss is not cached).
static func svg_tex(key: String, svg: String, box: float, px: int) -> Texture2D:
	if _tex.has(key) and _tex[key] is Texture2D:
		hits += 1
		return _tex[key]
	var img := rasterise(svg, float(px) / box)
	if img == null:
		return null
	misses += 1
	return _store(key, img)


## An atlas: cells = [{"key": String, "svg": String}], every cell `cell` px square on a grid `cols` wide. Returns
## {"tex": Texture2D, "rects": {key: Rect2}, "cell": int, "failed": [keys]} and caches it under `name`.
static func atlas(atlas_name: String, cells: Array, box: float, cell: int, cols: int) -> Dictionary:
	if _tex.has(atlas_name) and _tex[atlas_name] is Dictionary:
		hits += 1
		return _tex[atlas_name]
	misses += 1
	var rows := int(ceil(float(cells.size()) / float(cols)))
	var img := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	var rects := {}
	var failed: Array = []
	for i in cells.size():
		var c: Dictionary = cells[i]
		var pos := Vector2i((i % cols) * cell, (i / cols) * cell)
		rects[c["key"]] = Rect2(Vector2(pos), Vector2(cell, cell))
		var cimg := rasterise(str(c["svg"]), float(cell) / box)
		if cimg == null:
			failed.append(c["key"])
			continue
		if cimg.get_width() != cell or cimg.get_height() != cell:
			cimg.resize(cell, cell, Image.INTERPOLATE_BILINEAR)
		img.blit_rect(cimg, Rect2i(0, 0, cell, cell), pos)
	var tex := ImageTexture.create_from_image(img)
	var out := {"tex": tex, "rects": rects, "cell": cell, "failed": failed, "w": img.get_width(), "h": img.get_height()}
	_tex[atlas_name] = out
	var b := img.get_width() * img.get_height() * 4
	_sizes[atlas_name] = b | (maxi(img.get_width(), img.get_height()) << 32)
	_bytes += b
	return out


## Problems against the budget (empty = fine): total bytes, one texture over MAX_SIDE, too many textures (PERF-BUDGET 3.2).
static func violations() -> Array:
	var v: Array = []
	if _bytes > BUDGET_BYTES:
		v.append("texture bytes %d over the %d budget" % [_bytes, BUDGET_BYTES])
	for k in _sizes:
		var side := int(_sizes[k] >> 32)
		if side > MAX_SIDE:
			v.append("texture %s is %d px on a side, over %d" % [k, side, MAX_SIDE])
	if _tex.size() > 30:
		v.append("%d distinct textures, over the target of 30" % _tex.size())
	return v


static func stats() -> Dictionary:
	return {"textures": _tex.size(), "bytes": _bytes, "hits": hits, "misses": misses, "svg_calls": svg_calls,
		"svg_failures": svg_failures, "rasterise_ms": float(rasterise_usec) / 1000.0, "largest_side": largest_side()}
