class_name AuraLayer
extends Node2D
## The glow around a fighter who is charging or in Bankai: soft ellipses drawn with
## additive blending plus a few rising embers. Purely visual; SpriteBody owns it.

const LAYERS := 9
const PULSE_SPEED := 9.0
const EMBER_COUNT := 14

var color: Color = Color(1.0, 0.8, 0.3)
## Height of the fighter in screen pixels at the sprite scale (world units of the body node).
var body_height: float = 30.0

var _time: float = 0.0
var _embers: CPUParticles2D


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


func _ready() -> void:
	_embers = CPUParticles2D.new()
	_embers.amount = EMBER_COUNT
	_embers.lifetime = 0.9
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.direction = Vector2.UP
	_embers.spread = 18.0
	_embers.gravity = Vector2.ZERO
	_embers.initial_velocity_min = 14.0
	_embers.initial_velocity_max = 34.0
	_embers.scale_amount_min = 1.0
	_embers.scale_amount_max = 2.0
	_embers.emitting = false
	add_child(_embers)
	configure(color, body_height)


func configure(new_color: Color, new_height: float) -> void:
	color = new_color
	body_height = new_height
	if _embers == null:
		return
	_embers.position = Vector2(0.0, -4.0)
	_embers.emission_rect_extents = Vector2(body_height * 0.25, 2.0)
	_embers.color = color.lerp(Color.WHITE, 0.35)


func set_active(active: bool) -> void:
	visible = active
	set_process(active)
	if _embers != null:
		_embers.emitting = active and GameSettings.screen_effects
	if active:
		queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + 0.1 * sin(_time * PULSE_SPEED)
	var center := Vector2(0.0, -body_height * 0.5)
	for layer in LAYERS:
		var grow := 1.0 + 0.11 * float(layer)
		var radius_x := body_height * 0.36 * grow * pulse
		var radius_y := body_height * 0.62 * grow * pulse
		draw_set_transform(center, 0.0, Vector2(1.0, radius_y / radius_x))
		var alpha := 0.075 * (1.0 - float(layer) / float(LAYERS)) + 0.01
		draw_circle(Vector2.ZERO, radius_x, Color(color.r, color.g, color.b, alpha))
	draw_set_transform(center, 0.0, Vector2(1.0, 1.7))
	draw_circle(Vector2.ZERO, body_height * 0.2 * pulse, Color(1.0, 1.0, 1.0, 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
