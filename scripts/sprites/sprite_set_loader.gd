class_name SpriteSetLoader
extends RefCounted
## Reads <id>_atlas.png and <id>_frames.json (the art handoff format) into a
## SpriteSet. Three JSON shapes exist: a list of frame rectangles (ichigo),
## a dictionary keyed by frame number with a fixed cell (uryu) and a dictionary
## keyed by pose name with a `frame_order` list (noble, sovereign).
## Returns null when the files are missing so callers can fall back.

static var _cache: Dictionary = {}


static func load_set(dir: String, id: String) -> SpriteSet:
	if dir == "" or id == "":
		return null
	var key := dir + id
	if not _cache.has(key):
		_cache[key] = _build(dir, id)
	return _cache[key]


static func clear_cache() -> void:
	_cache.clear()


static func _build(dir: String, id: String) -> SpriteSet:
	var json_path := "%s%s_frames.json" % [dir, id]
	if not FileAccess.file_exists(json_path):
		return null
	var json_text := FileAccess.get_file_as_string(json_path)
	var atlas := _load_texture("%s%s_atlas.png" % [dir, id])
	var data: Variant = JSON.parse_string(json_text)
	if atlas == null or not data is Dictionary:
		return null
	var set := SpriteSet.new()
	var cell: Array = data["cell"]
	set.anchor = Vector2(float(data["anchor"][0]), float(data["anchor"][1]))
	set.frames = _build_frames(data, atlas)
	set.effects = _build_effects(data, dir, atlas)
	set.top_px = _measure_height(data, atlas, set)
	for animation_name: String in data["animations"]:
		var hint: String = data["animations"][animation_name].get("code_motion", "")
		if hint != "":
			set.code_motion[StringName(animation_name)] = hint
	if cell.size() < 2 or set.frames.get_animation_names().is_empty():
		return null
	return set


static func _build_frames(data: Dictionary, atlas: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for animation_name: String in data["animations"]:
		var info: Dictionary = data["animations"][animation_name]
		var key := StringName(animation_name)
		frames.add_animation(key)
		frames.set_animation_speed(key, float(info["fps"]))
		frames.set_animation_loop(key, bool(info["loop"]))
		for reference: Variant in info["frames"]:
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2(frame_rect(data, int(reference)))
			texture.filter_clip = true
			frames.add_frame(key, texture)
	return frames


## The pixel rectangle of a frame, whichever of the three JSON shapes is used.
static func frame_rect(data: Dictionary, reference: int) -> Rect2i:
	var cell: Array = data["cell"]
	var frames: Variant = data["frames"]
	if frames is Array:
		for entry: Dictionary in frames:
			if int(entry.get("id", -1)) == reference:
				return Rect2i(int(entry["x"]), int(entry["y"]), int(entry["w"]), int(entry["h"]))
		var fallback: Dictionary = frames[reference]
		return Rect2i(int(fallback["x"]), int(fallback["y"]), int(fallback["w"]), int(fallback["h"]))
	var key := str(reference)
	if data.has("frame_order"):
		key = data["frame_order"][reference]
	var entry: Dictionary = frames[key]
	return Rect2i(int(entry["x"]), int(entry["y"]), int(cell[0]), int(cell[1]))


static func _build_effects(data: Dictionary, dir: String, atlas: Texture2D) -> Dictionary:
	var effects := {}
	var source: Dictionary = data.get("effects", {})
	if data.has("effects_atlas"):
		var effect_atlas := _load_texture(dir + str(data["effects_atlas"]))
		if effect_atlas == null:
			return effects
		for effect_name: String in source:
			var rect: Dictionary = source[effect_name]
			effects[StringName(effect_name)] = _region(effect_atlas, Rect2i(
				int(rect["x"]), int(rect["y"]), int(rect["w"]), int(rect["h"])
			))
		return effects
	for effect_name: String in source:
		var cell_rect := frame_rect(data, int(source[effect_name]))
		effects[StringName(effect_name)] = _region(atlas, _trim(atlas, cell_rect))
	return effects


static func _region(texture: Texture2D, rect: Rect2i) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = texture
	result.region = Rect2(rect)
	result.filter_clip = true
	return result


## The part of a rectangle that is not transparent.
static func _trim(texture: Texture2D, rect: Rect2i) -> Rect2i:
	var image := texture.get_image()
	if image == null:
		return rect
	var used := image.get_region(rect).get_used_rect()
	if used.size == Vector2i.ZERO:
		return rect
	return Rect2i(rect.position + used.position, used.size)


static func _measure_height(data: Dictionary, atlas: Texture2D, set: SpriteSet) -> float:
	var idle: Array = data["animations"].get("idle", {}).get("frames", [])
	if idle.is_empty() or atlas.get_image() == null:
		return set.top_px
	var rect := frame_rect(data, int(idle[0]))
	var used := atlas.get_image().get_region(rect).get_used_rect()
	return maxf(set.anchor.y - float(used.position.y), 8.0)


## Imported textures load normally; a raw PNG that has not been imported yet is read directly.
static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null:
			return ImageTexture.create_from_image(image)
	return null
