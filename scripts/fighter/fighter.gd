class_name Fighter
extends CharacterBody2D
## A fighter on the stage. It owns its data, its input and the shared movement
## helpers. What the fighter is doing at the moment lives in the child states.
## Combat: the Hurtbox reports hits with a signal, the Hitbox and projectiles
## report landed hits with a signal; this class turns them into damage, launch,
## hitlag and Reiatsu.

signal state_changed(state_name: StringName)
## A special move fired a projectile; whoever owns the scene adds it to the tree.
signal projectile_spawned(projectile: Projectile)

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
var reiatsu: float = 0.0
var bankai_frames_left: int = 0
var gauge: float = 0.0
var combo_count: int = 0
var last_attacker_id: int = 0
var guard_energy: float = GuardRules.ENERGY_MAX
## 0..1 while a special is being charged (drawn as a glow around the fighter).
var special_charge: float = 0.0
var guard_age: int = 0
var dodge_frames_left: int = 0
var shunpo_cooldown: int = 0
var air_shunpo_used: bool = false
var damage_multiplier: float = 1.0
var speed_scale: float = 1.0

var _input_source: InputSource
var _drop_through_frames_left: int = 0
var _invincible_blinks: bool = false
var _queued_move: MoveData
var _combo_frames: int = 0
var _gauge_idle_frames: int = 0

@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var _shape: CollisionShape2D = $CollisionShape2D
var _body: FighterBody
@onready var _state_machine: FighterStateMachine = $StateMachine


func _ready() -> void:
	assert(data != null, "Fighter needs CharacterData")
	var rectangle := RectangleShape2D.new()
	rectangle.size = data.body_size
	_shape.shape = rectangle
	_shape.position = Vector2(0.0, -data.body_size.y * 0.5) # origin sits at the feet
	_body = BodyFactory.create(data, player_id)
	add_child(_body)
	move_child(_body, 1) # drawn behind the hit areas, right after the collision shape
	var shadow := GroundShadow.new()
	add_child(shadow)
	move_child(shadow, 1) # under the body
	shadow.setup(self)
	var glow := ChargeGlow.new()
	add_child(glow)
	glow.setup(self)
	var shield := GuardShield.new()
	add_child(shield)
	shield.setup(self)
	hurtbox.setup(player_id, data.body_size)
	hitbox.setup(player_id)
	hurtbox.hit_received.connect(_on_hit_received)
	hitbox.hit_landed.connect(_on_hit_landed)
	Events.ultimate_started.connect(_on_ultimate_started)
	Events.transform_started.connect(_on_transform_started)
	Events.fighter_defeated.connect(_on_fighter_defeated)
	Events.fighter_guarded.connect(_on_guarded_by_other)
	gauge = clampf(data.starting_gauge, 0.0, CombatGauge.MAX)
	air_jumps_left = data.max_air_jumps
	_state_machine.state_changed.connect(_on_state_changed)
	_state_machine.setup(self, &"Fall")
	Events.fighter_percent_changed.emit(player_id, percent)
	Events.fighter_reiatsu_changed.emit(player_id, reiatsu)
	Events.fighter_gauge_changed.emit(player_id, gauge)


func _physics_process(delta: float) -> void:
	_tick_invincibility()
	if hitlag_left > 0:
		hitlag_left -= 1
		_body.sync_to(_state_machine.current_name, facing, velocity)
		return
	_tick_bankai()
	_tick_gauge()
	_tick_defense()
	_tick_reiatsu()
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


func set_attack_visual(kind: StringName, phase: StringName, aerial: bool = false, special: bool = false) -> void:
	_body.set_attack_visual(kind, phase, aerial, special)


# --- Damage ------------------------------------------------------------------

func set_percent(value: float) -> void:
	percent = clampf(value, 0.0, MAX_PERCENT)
	Events.fighter_percent_changed.emit(player_id, percent)


func _on_hit_received(info: HitInfo) -> void:
	if hurtbox.evading:
		_evade_hit(info)
		return
	if is_guarding():
		_block_hit(info)
		return
	set_percent(percent + info.damage)
	last_attacker_id = info.attacker_id
	combo_count = 0
	add_gauge(info.damage * CombatGauge.GAIN_TAKEN)
	add_reiatsu(info.damage * Reiatsu.GAIN_TAKEN)
	var launch_speed := Knockback.magnitude(
		info.base_knockback, info.knockback_growth, percent, data.weight
	)
	velocity = info.direction * launch_speed
	hitstun_frames_left = Knockback.hitstun_frames(launch_speed)
	hitlag_left = Knockback.hitlag_frames(info.damage)
	is_fast_falling = false
	_body.flash_hit()
	if absf(info.direction.x) > 0.1:
		facing = -1 if info.direction.x > 0.0 else 1
	_state_machine.transition_to(&"Hitstun")
	Events.fighter_hit.emit(info.attacker_id, player_id, info.damage)
	Events.fighter_launched.emit(player_id, launch_speed, info.direction)
	Events.hit_impact.emit(
		global_position + Vector2(0.0, -14.0), info.direction, info.damage, launch_speed, info.attacker_id
	)


func _on_hit_landed(info: HitInfo) -> void:
	hitlag_left = Knockback.hitlag_frames(info.damage)
	add_reiatsu(info.damage * Reiatsu.GAIN_DEALT)
	_register_landed_hit(info.damage)


## A projectile we fired connected: gain Reiatsu, but no hitlag (we may be doing something else).
func _on_projectile_hit(info: HitInfo) -> void:
	add_reiatsu(info.damage * Reiatsu.GAIN_DEALT)
	_register_landed_hit(info.damage)


# --- Guard and Shunpo ----------------------------------------------------------

func is_guarding() -> bool:
	return _state_machine.current_name == &"Guard"


## The state to enter when the guard key is pressed: a Shunpo with a direction held, a Guard
## otherwise, nothing when the guard energy is too low.
func guard_press_state() -> StringName:
	if absf(input.move.x) > 0.0 and can_shunpo():
		return &"Shunpo"
	return &"Guard" if guard_energy >= GuardRules.ENERGY_MIN_TO_GUARD else &""


func can_shunpo() -> bool:
	return shunpo_cooldown <= 0 and (is_on_floor() or not air_shunpo_used)


func begin_shunpo() -> void:
	dodge_frames_left = GuardRules.SHUNPO_DODGE_FRAMES
	shunpo_cooldown = GuardRules.SHUNPO_COOLDOWN
	is_fast_falling = false
	if not is_on_floor():
		air_shunpo_used = true


func _tick_defense() -> void:
	if shunpo_cooldown > 0:
		shunpo_cooldown -= 1
	if dodge_frames_left > 0:
		dodge_frames_left -= 1
	if not is_guarding():
		guard_energy = minf(guard_energy + GuardRules.RECOVER_PER_FRAME, GuardRules.ENERGY_MAX)
	var perfect_window := is_guarding() and guard_age < GuardRules.PERFECT_WINDOW_FRAMES
	hurtbox.evading = dodge_frames_left > 0 or perfect_window


## A hit that arrived during a perfect-guard window or a Shunpo: nothing happens to us.
func _evade_hit(info: HitInfo) -> void:
	var spot := global_position + Vector2(0.0, -14.0)
	add_gauge(GuardRules.PERFECT_GAUGE)
	add_reiatsu(Reiatsu.PERFECT_GAIN)
	if is_guarding():
		Events.fighter_guarded.emit(player_id, info.attacker_id, true, spot)
	else:
		Events.fighter_dodged.emit(player_id, info.attacker_id, spot)


## A hit absorbed by the guard: a little damage, a little push, the guard energy drains.
func _block_hit(info: HitInfo) -> void:
	set_percent(percent + info.damage * GuardRules.DAMAGE_SCALE)
	last_attacker_id = info.attacker_id
	add_gauge(info.damage * GuardRules.BLOCK_GAUGE_RATIO)
	guard_energy -= info.damage * GuardRules.BLOCK_DRAIN_PER_DAMAGE
	var push := Knockback.magnitude(info.base_knockback, info.knockback_growth, percent, data.weight)
	velocity.x = info.direction.x * push * GuardRules.KNOCKBACK_SCALE * GuardRules.PUSHBACK_SCALE
	hitlag_left = Knockback.hitlag_frames(info.damage)
	Events.fighter_guarded.emit(player_id, info.attacker_id, false, global_position + Vector2(0.0, -14.0))
	if guard_energy <= 0.0:
		_state_machine.transition_to(break_guard())


## The guard broke: a long stun, and only a little energy back. Returns the state to enter.
func break_guard() -> StringName:
	guard_energy = GuardRules.BREAK_RESTORE
	hitstun_frames_left = GuardRules.BREAK_STUN_FRAMES
	velocity.x = 0.0
	_body.flash_hit()
	Events.fighter_guard_broken.emit(player_id)
	return &"Hitstun"


func _on_guarded_by_other(victim_id: int, attacker_id: int, perfect: bool, _spot: Vector2) -> void:
	if perfect and attacker_id == player_id and victim_id != player_id:
		hitlag_left = maxi(hitlag_left, GuardRules.PERFECT_ATTACKER_HITLAG)


# --- Combat Gauge ---------------------------------------------------------------

func add_gauge(amount: float) -> void:
	if amount > 0.0:
		_gauge_idle_frames = 0
	set_gauge(gauge + amount)


func set_gauge(value: float) -> void:
	var clamped := clampf(value, 0.0, CombatGauge.MAX)
	if is_equal_approx(clamped, gauge):
		return
	gauge = clamped
	Events.fighter_gauge_changed.emit(player_id, gauge)


## A hit of ours connected: fill the gauge (more in a combo) and lengthen the form.
func _register_landed_hit(damage: float) -> void:
	combo_count = combo_count + 1 if _combo_frames > 0 else 1
	_combo_frames = CombatGauge.COMBO_WINDOW_FRAMES
	if is_bankai():
		bankai_frames_left = CombatGauge.extend_form(bankai_frames_left)
	else:
		add_gauge(CombatGauge.gain_for_hit(damage, combo_count))


func _tick_gauge() -> void:
	if _combo_frames > 0:
		_combo_frames -= 1
		if _combo_frames == 0:
			combo_count = 0
	if is_bankai() or gauge <= 0.0:
		return
	_gauge_idle_frames += 1
	if _gauge_idle_frames > CombatGauge.IDLE_FRAMES:
		set_gauge(gauge - CombatGauge.DECAY_PER_FRAME)


func _on_transform_started(transformer_id: int, _title: String, frames: int) -> void:
	if transformer_id != player_id:
		hitlag_left = maxi(hitlag_left, frames)


func _on_fighter_defeated(victim_id: int, attacker_id: int) -> void:
	if attacker_id == player_id and victim_id != player_id and not is_ko():
		add_gauge(CombatGauge.KO_BONUS)


# --- Reiatsu, Bankai and ultimates ---------------------------------------------

func add_reiatsu(amount: float) -> void:
	set_reiatsu(reiatsu + amount)


func can_afford(cost: float) -> bool:
	return reiatsu >= cost - 0.001


## Pays `cost` when affordable and says whether it did.
func try_spend_reiatsu(cost: float) -> bool:
	if cost <= 0.0:
		return true
	if not can_afford(cost):
		return false
	spend_reiatsu(cost)
	return true


func _tick_reiatsu() -> void:
	if reiatsu >= Reiatsu.MAX:
		return
	var rate := Reiatsu.REGEN_PER_FRAME * (Reiatsu.FORM_REGEN_MULTIPLIER if is_bankai() else 1.0)
	add_reiatsu(rate)


func spend_reiatsu(amount: float) -> void:
	set_reiatsu(reiatsu - amount)


func set_reiatsu(value: float) -> void:
	reiatsu = clampf(value, 0.0, Reiatsu.MAX)
	Events.fighter_reiatsu_changed.emit(player_id, reiatsu)


func is_bankai() -> bool:
	return bankai_frames_left > 0


func can_bankai() -> bool:
	return not is_bankai() and gauge >= CombatGauge.MAX


func can_ultimate() -> bool:
	return data.ultimate != null and is_bankai() and reiatsu >= Reiatsu.ULTIMATE_COST


## What pressing the charge key does right now. Returns the state to enter.
func charge_press_state() -> StringName:
	if can_ultimate():
		spend_reiatsu(Reiatsu.ULTIMATE_COST)
		_queued_move = data.ultimate
		var safe_frames := data.ultimate.startup_frames + data.ultimate.active_frames
		grant_invincibility(safe_frames + Reiatsu.ULTIMATE_SAFE_FRAMES)
		return &"Attack"
	if can_bankai():
		return &"Transform"
	return &""


func start_bankai() -> void:
	set_gauge(0.0)
	bankai_frames_left = CombatGauge.FORM_FRAMES
	damage_multiplier = CombatGauge.DAMAGE_SCALE
	speed_scale = CombatGauge.SPEED_SCALE
	_body.set_bankai(true)
	Events.fighter_bankai_changed.emit(player_id, true)


func end_bankai() -> void:
	if bankai_frames_left == 0 and damage_multiplier == 1.0:
		return
	bankai_frames_left = 0
	damage_multiplier = 1.0
	speed_scale = 1.0
	_body.set_bankai(false)
	Events.fighter_bankai_changed.emit(player_id, false)


func _tick_bankai() -> void:
	if bankai_frames_left <= 0:
		return
	bankai_frames_left -= 1
	if bankai_frames_left == 0:
		end_bankai()


func _on_ultimate_started(attacker_id: int, freeze_frames: int, _title: String) -> void:
	if attacker_id != player_id:
		hitlag_left = maxi(hitlag_left, freeze_frames)


# --- Attacks and specials ------------------------------------------------------

func wants_attack() -> bool:
	return input.attack_just_pressed or input.special_just_pressed


func current_specials() -> SpecialSet:
	if is_bankai() and data.bankai_specials != null:
		return data.bankai_specials
	return data.specials


## The move for the button just pressed and the direction held.
func pick_move(aerial: bool) -> MoveData:
	if input.special_just_pressed:
		return current_specials().select(input.move)
	return data.moveset.select(aerial, input.move)


## Queues a move for the attack state to play next (an ultimate or a follow-up).
func queue_move(move: MoveData) -> void:
	_queued_move = move


## An ultimate queued by charge_press_state(); consumed once by the attack state.
func take_queued_move() -> MoveData:
	var move := _queued_move
	_queued_move = null
	return move


## `charge` (0..1) is how long the special was charged; it scales the projectile (see SpecialData).
func spawn_projectile(projectile_data: ProjectileData, move: MoveData, charge: float = 0.0) -> void:
	var projectile := Projectile.new()
	var special := move as SpecialData
	var scales := special.charge_scales(charge) if special != null else {"damage": 1.0, "size": 1.0, "speed": 1.0, "pierce": false}
	projectile.launch(
		projectile_data, move, player_id, facing, damage_multiplier * scales["damage"], global_position,
		scales["size"], scales["speed"], scales["pierce"]
	)
	if projectile_data.style == &"":
		projectile.set_art(_body.effect_texture(projectile_data.art))
	projectile.hit_landed.connect(_on_projectile_hit)
	projectile_spawned.emit(projectile)


# --- Knock-out and respawn -----------------------------------------------------

## Called when the fighter has left the blast zone. Hidden and inert until respawn_at.
func enter_ko() -> void:
	hurtbox.set_active(false)
	hitlag_left = 0
	invincible_left = 0
	dodge_frames_left = 0
	guard_energy = GuardRules.ENERGY_MAX
	_queued_move = null
	if not is_bankai():
		add_gauge(CombatGauge.STOCK_LOSS_PITY)
	Events.fighter_defeated.emit(player_id, last_attacker_id)
	last_attacker_id = 0
	combo_count = 0
	end_bankai()
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
	grant_invincibility(RESPAWN_INVINCIBLE_FRAMES, true)
	_state_machine.transition_to(&"Fall")


## No damage for a while. `blink` makes the body flicker (used after a respawn).
func grant_invincibility(frames: int, blink: bool = false) -> void:
	invincible_left = maxi(invincible_left, frames)
	_invincible_blinks = blink
	hurtbox.set_active(false)


func _tick_invincibility() -> void:
	if invincible_left <= 0:
		return
	invincible_left -= 1
	if _invincible_blinks:
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
		velocity.x = move_toward(velocity.x, direction * max_speed * speed_scale, accel * delta)
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
	Events.dust_puff.emit(global_position, 0.55)


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
	air_shunpo_used = false
	is_fast_falling = false
	Events.fighter_landed.emit(player_id)
	Events.dust_puff.emit(global_position, 1.0)


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
