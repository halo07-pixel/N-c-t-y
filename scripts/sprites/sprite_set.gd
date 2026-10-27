class_name SpriteSet
extends RefCounted
## One character's sprite animations, built from an atlas and its JSON by
## SpriteSetLoader. Frames face right; the anchor is the feet / body centre.

var frames: SpriteFrames
var anchor: Vector2 = Vector2.ZERO
## Height of the character above the anchor in sprite pixels (for markers).
var top_px: float = 48.0
## Effect name to texture (projectiles and similar).
var effects: Dictionary = {}
## Animation name to a motion hint such as "spin_fade" for sets without that animation.
var code_motion: Dictionary = {}


func has_animation(animation: StringName) -> bool:
	return frames != null and frames.has_animation(animation)


func frame_count(animation: StringName) -> int:
	return frames.get_frame_count(animation) if has_animation(animation) else 0
