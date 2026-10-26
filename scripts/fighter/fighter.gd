class_name Fighter
extends CharacterBody2D
## A fighter on the stage. It owns its data, its input and the shared movement
## helpers. What the fighter is doing at the moment lives in the child states.
## Combat: the Hurtbox reports hits with a signal, the Hitbox reports landed
## hits with a signal; this class turns them into damage, launch and hitlag.

signal state_changed(state_name: StringName)

const SOFT_PLATFORM_LAYER_VALUE := 4 # physics layer 3
const DROP_THROUGH_FRAMES := 20
const DROP_THROUGH_PUSH_SPEED := 120.0
const FLOOR_NORMAL_MAX_Y := -0.7
const MAX_PERCENT := 999.0
const RESPAWN_INVINCIBLE_FRAMES := 120
const BLINK_PERIOD_FRAMES := 4

@export var player_id: int = 1
@export var data: CharacterData

var input: InputFrame = InputFrame.new()
var facing: int = 1
var air_jumps_left: int = 0
var is_fast_falling: bool = false
var percent: float = 0.0
var hitstun_frames_left: int = 0
var hitlag_left: int = 0
var invincible_left: int = 0

var _input_source: InputSource
var _drop_through_frames_left: int = 0

@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
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
	hurtbox.setup(player_id, data.body_size)
	hitbox.setup(player_id)
	hurtbox.hit_received.connect(_on_hit_received)
	hitbox.hit_landed.connect(_on_hit_landed)
	air_jumps_left = data.max_air_jumps
	_state_machine.state_changed.connect(_on_state_changed)
	_state_machine.setup(self, &"Fall")
	Events.fighter_percent_changed.emit(player_id, percent)


func _physics_process(delta: float) -> void:
	_tick_invincibility()
	if hitlag_left > 0:
		hitlag_left -= 1
		_body.sync_to(_state_machine.current_name, facing, velocity)
		return
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


func is_ko() -> bool:
	return _state_machine.current_name == &"Ko"


func set_attack_visual(kind: StringName, phase: StringName) -> void:
	_body.set_attack_visual(kind, phase)


# --- Damage ------------------------------------------------------------------

func set_percent(value: float) -> void:
	percent = clampf(value, 0.0, MAX_PERCENT)
	Events.fighter_percent_changed.emit(player_id, percent)


func _on_hit_received(info: HitInfo) -> void:
	set_percent(percent + info.damage)
	var launch_speed := Knockback.magnitude(
		info.base_knockback, info.knockback_growth, percent, data.weight
	)
	velocity = info.direction * launch_speed
	hitstun_frames_left = Knockback.hitstun_frames(launch_speed)
	hitlag_left = Knockback.hitlag_frames(info.damage)
	is_fast_falling = false
	if absf(info.direction.x) > 0.1:
		facing = -1 if info.direction.x > 0.0 else 1
	_state_machine.transition_to(&"Hitstun")
	Events.fighter_hit.emit(info.attacker_id, player_id, info.damage)


func _on_hit_landed(info: HitInfo) -> void:
	hitlag_left = Knockback.hitlag_frames(info.damage)


# --- Knock-out and respawn -----------------------------------------------------

## Called when the fighter has left the blast zone. Hidden and inert until respawn_at.
func enter_ko() -> void:
	hurtbox.set_active(false)
	hitlag_left = 0
	invincible_left = 0
	_body.modulate.a = 1.0
	velocity = Vector2.ZERO
	_state_machine.transition_to(&"Ko")
	hide()


func respawn_at(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	show()
	set_percent(0.0)
	is_fast_falling = false
	hitlag_left = 0
	hitstun_frames_left = 0
	refill_jumps()
	_end_drop_through()
	invincible_left = RESPAWN_INVINCIBLE_FRAMES
	hurtbox.set_active(false)
	_state_machine.transition_to(&"Fall")


func _tick_invincibility() -> void:
	if invincible_left <= 0:
		return
	invincible_left -= 1
	var blink_phase := floori(float(invincible_left) / BLINK_PERIOD_FRAMES)
	_body.modulate.a = 0.35 if blink_phase % 2 == 0 else 1.0
	if invincible_left == 0:
		_body.modulate.a = 1.0
		hurtbox.set_active(true)


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
	# A launched fighter may be moving faster than the fall limit; never slow them down here.
	if velocity.y < limit:
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
