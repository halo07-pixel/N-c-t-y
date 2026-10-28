class_name Vignette
extends CanvasLayer
## A light dark edge around the screen. Sits above the world and below the HUD.

const EDGE_ALPHA := 0.42
const CLEAR_UNTIL := 0.55


func _ready() -> void:
	layer = 10
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, CLEAR_UNTIL, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.05, EDGE_ALPHA),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
