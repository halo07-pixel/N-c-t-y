class_name Fighter
extends CharacterBody2D
## A fighter on the stage. It owns its data, its input and the shared movement
## helpers. What the fighter is doing at the moment lives in the child states.

signal state_changed(state_name: StringName)

const SOFT_PLATFORM_LAYER_VALUE := 4 # physics layer 3
const DROP_THROUGH_FRAMES := 20
const DROP_THROUGH_PUSH_SPEED := 120.0
const FLOOR_NORMAL_MAX_Y := -0.7

@export var player_id: int = 1
@export var data: CharacterData

var input: InputFrame = InputFrame.new()
var facing: int = 1
var air_jumps_left: int = 0
var is_fast_falling: bool = false

var _input_source: InputSource
var _drop_through_frames_left: int = 0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _body: PlaceholderBody = $PlaceholderBody
@onready var _state_machine: FighterStateMachine = $StateMachine


func _ready() -> void:
	assert(data != null, "Fighter needs CharacterData")
	var rectangle := RectangleShape2D.new()
	rectangle.size = data.body_size
	_shape.shape = rectangle
	_shape.position = Vector2(0.0, -data.body_size.y * 0.5) # origin sits at the feet
	_body.setup(data, player_id)
	air_jumps_left = data.max_air_jumps
	_state_machine.state_changed.connect(_on_state_changed)
	_state_machine.setup(self, &"Fall")


func _physics_process(delta: float) -> void:
	if _input_source != null:
		input = _input_source.get_frame()
	_tick_drop_through()
	_state_machine.physics_update(delta)
	move_and_slide()
	_body.sync_to(_state_machine.current_name, facing, velocity)


func set_input_source(source: InputSource) -> void:
	if _input_source != null:
		_input_source.queue_free()
	_input_source = source
	add_child(source)


func get_state_name() -> StringName:
	return _state_machine.current_name


func respawn_at(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	is_fast_falling = false
	refill_jumps()
	_end_drop_through()
	_state_machine.transition_to(&"Fall")


# --- Movement helpers used by the states -------------------------------------

func face_input() -> void:
	if input.move.x > 0.0:
		facing = 1
	elif input.move.x < 0.0:
		facing = -1


func apply_horizontal(
	delta: float, direction: float, max_speed: float, accel: float, friction: float
) -> void:
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * max_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func apply_gravity(delta: float, fast_fall: bool = false) -> void:
	var limit := data.fast_fall_speed if fast_fall else data.max_fall_speed
	velocity.y = minf(velocity.y + data.gravity * delta, limit)


func start_jump() -> void:
	velocity.y = -data.jump_velocity
	is_fast_falling = false
	Events.fighter_jumped.emit(player_id, false)


func can_air_jump() -> bool:
	return air_jumps_left > 0


func start_air_jump() -> void:
	air_jumps_left -= 1
	velocity.y = -data.air_jump_velocity
	is_fast_falling = false
	Events.fighter_jumped.emit(player_id, true)


func refill_jumps() -> void:
	air_jumps_left = data.max_air_jumps


func notify_landed() -> void:
	refill_jumps()
	is_fast_falling = false
	Events.fighter_landed.emit(player_id)


# --- Soft platforms ----------------------------------------------------------

func is_standing_on_soft_platform() -> bool:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider() as CollisionObject2D
		if collider == null:
			continue
		var is_soft := (collider.collision_layer & SOFT_PLATFORM_LAYER_VALUE) != 0
		if is_soft and collision.get_normal().y < FLOOR_NORMAL_MAX_Y:
			return true
	return false


func start_drop_through() -> void:
	_drop_through_frames_left = DROP_THROUGH_FRAMES
	collision_mask &= ~SOFT_PLATFORM_LAYER_VALUE
	velocity.y = DROP_THROUGH_PUSH_SPEED
	Events.fighter_dropped_through.emit(player_id)


func is_dropping_through() -> bool:
	return _drop_through_frames_left > 0


func _tick_drop_through() -> void:
	if _drop_through_frames_left <= 0:
		return
	_drop_through_frames_left -= 1
	if _drop_through_frames_left == 0:
		collision_mask |= SOFT_PLATFORM_LAYER_VALUE


func _end_drop_through() -> void:
	_drop_through_frames_left = 0
	collision_mask |= SOFT_PLATFORM_LAYER_VALUE


func _on_state_changed(_previous: StringName, current: StringName) -> void:
	_body.set_pose(current)
	state_changed.emit(current)
	Events.fighter_state_changed.emit(player_id, current)
