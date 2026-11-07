class_name Projectile
extends Area2D
## A flying (or stationary) attack fired by a special move. It reports a landed
## hit with a signal; the hurtbox it touches handles the rest, exactly like a hitbox.

signal hit_landed(info: HitInfo)

const HURTBOX_LAYER_VALUE := 16 # physics layer 5
const SOLID_LAYER_VALUE := 32 # physics layer 6: walls of ice
const OFFSCREEN_LIMIT := 1600.0
const CORE_SCALE := 0.55
const MIN_ART_SCALE := 0.35
const TRAP_GROUP := &"traps"
const SHOT_GROUP := &"shots"
const COMMAND_GROUP := &"commandable"
const COMMAND_DAMAGE_SCALE := 1.3
const COMMAND_MIN_LIFE := 50
const REFLECT_MIN_LIFE := 40

var owner_id: int = 0

var _data: ProjectileData
var _move: MoveData
var _facing: int = 1
var _damage_scale: float = 1.0
var _velocity: Vector2 = Vector2.ZERO
var _frames_left: int = 0
var _freeze_left: int = 0
var _already_hit: Array[Hurtbox] = []
var _art: Texture2D
var _size: Vector2 = Vector2.ONE
var _pierce: bool = false
var _age: float = 0.0
## What is left of a wall that can break, and the last swing of each fighter it already felt.
var _wall_health: float = 0.0
var _felt_swings: Dictionary = {}
var _trail: Array[Vector2] = []
## Set by reflect() while the hit that was parried is still being handled.
var _reflected_now: bool = false


## Sets everything up; call before adding to the scene tree.
var _planted: bool = false


func launch(
	data: ProjectileData, move: MoveData, id: int, facing: int, damage_scale: float, origin: Vector2,
	size_scale: float = 1.0, speed_scale: float = 1.0, force_pierce: bool = false
) -> void:
	_data = data
	_move = move
	owner_id = id
	_facing = facing
	_damage_scale = damage_scale * data.damage_scale
	_size = data.size * size_scale
	_pierce = data.pierce or force_pierce
	_velocity = Vector2(data.velocity.x * float(facing), data.velocity.y) * speed_scale
	_frames_left = data.lifetime_frames
	top_level = true
	position = origin + Vector2(data.offset.x * float(facing), data.offset.y)
	collision_layer = 0
	collision_mask = HURTBOX_LAYER_VALUE
	monitorable = false
	var rectangle := RectangleShape2D.new()
	rectangle.size = _size
	var shape := CollisionShape2D.new()
	shape.shape = rectangle
	add_child(shape)


## An effect sprite to draw instead of the plain diamond; null keeps the diamond.
func set_art(texture: Texture2D) -> void:
	_art = texture
	queue_redraw()


## Keeps the projectile alive a few frames longer.
func sustain(frames: int) -> void:
	_frames_left += frames


func is_trap() -> bool:
	return _data != null and _data.trap


## Sends the projectile flying `direction` (-1/1) at `speed`; it can hit again and hits harder.
func command(direction: int, speed: float) -> void:
	_velocity = Vector2(float(direction) * speed, 0.0)
	_facing = direction
	_frames_left = maxi(_frames_left, COMMAND_MIN_LIFE)
	_damage_scale *= COMMAND_DAMAGE_SCALE
	_already_hit.clear()
	_pierce = true


## True for an ordinary shot: traps and ultimates are not sent back by a parry.
func can_reflect() -> bool:
	if _data == null or is_trap():
		return false
	var special := _move as SpecialData
	return special == null or special.cinematic_frames <= 0


## A parry sends the shot back: it now belongs to `new_owner`, flies the other way, and can hit
## whoever fired it. Nobody is credited for it until the new owner connects to `hit_landed`.
func reflect(new_owner: int) -> void:
	for connection in hit_landed.get_connections():
		hit_landed.disconnect(connection["callable"])
	owner_id = new_owner
	_velocity = -_velocity
	_facing = -_facing
	_already_hit.clear()
	_trail.clear()
	_frames_left = maxi(_frames_left, REFLECT_MIN_LIFE)
	_reflected_now = true
	if _data.style != &"":
		Events.projectile_flash.emit(position, _velocity.normalized(), _data.color, false)


func _ready() -> void:
	add_to_group(SHOT_GROUP)
	if _data != null and _data.commandable:
		add_to_group(COMMAND_GROUP)
	if is_trap():
		add_to_group(TRAP_GROUP)
	area_entered.connect(_on_area_entered)
	if _data != null and _data.solid:
		_add_solid_body()
		_wall_health = _data.wall_health
	Events.ultimate_started.connect(_on_ultimate_started)
	if _data != null and _data.style != &"" and not _data.trap:
		Events.projectile_flash.emit(position, _velocity.normalized(), _data.color, false)
	if _data != null and _data.style != &"":
		if _data.rim.a <= 0.0: # a dark rimmed projectile is drawn solid, not added to the light
			var additive := CanvasItemMaterial.new()
			additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			material = additive
		z_index = 10


func _process(_delta: float) -> void:
	if _data != null and _data.style != &"":
		queue_redraw()


## Held up/down at the moment of firing bends the shot (Byakurai).
func steer(extra_vertical: float) -> void:
	_velocity.y += extra_vertical


## Drops a planted projectile onto the floor below it, point first.
func _plant() -> void:
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, 220.0), 5)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = float(hit["position"].y) - _size.y * 0.5 + 3.0


func _physics_process(delta: float) -> void:
	if _data.plant and not _planted:
		_planted = true
		_plant()
	if _freeze_left > 0:
		_freeze_left -= 1
		return
	position += _velocity * delta
	if _data.slow_scale < 1.0:
		_slow_enemies()
	if _data.absorbs:
		_absorb_enemy_shots()
	if _data.solid and _data.wall_health > 0.0:
		_feel_melee()
		if _wall_health <= 0.0:
			_break_wall()
			return
	_age += delta
	if _data.style != &"" and GameSettings.screen_effects:
		_trail.append(position)
		if _trail.size() > ProjectileArt.TRAIL_POINTS:
			_trail.pop_front()
	_frames_left -= 1
	if _frames_left <= 0 or position.length() > OFFSCREEN_LIMIT:
		if _data.style != &"" and not _data.trap and position.length() <= OFFSCREEN_LIMIT:
			Events.projectile_flash.emit(position, _velocity.normalized(), _data.color, true)
		queue_free()


## A breakable wall loses health to the shots it eats and the melee swings that reach it.
func _wear(damage: float) -> void:
	_wall_health -= damage
	Events.mechanic_triggered.emit(owner_id, &"armor", position)
	queue_redraw()


## Each active swing of an enemy that overlaps the wall wears it down once.
func _feel_melee() -> void:
	var mine := Rect2(position - _size * 0.5, _size)
	for node in get_tree().get_nodes_in_group(Fighter.FIGHTER_GROUP):
		var other := node as Fighter
		if other == null or other.player_id == owner_id or not other.hitbox.is_active:
			continue
		if _felt_swings.get(other.player_id, -1) == other.hitbox.activations:
			continue
		if mine.intersects(other.hitbox.world_rect()):
			_felt_swings[other.player_id] = other.hitbox.activations
			_wear(other.hitbox.swing_damage())


## A breakable wall fades as it wears: from solid to half see-through.
func _wall_tint() -> Color:
	var tint := _data.color
	if _data.solid and _data.wall_health > 0.0:
		tint.a *= 0.5 + 0.5 * clampf(_wall_health / _data.wall_health, 0.0, 1.0)
	return tint


func _break_wall() -> void:
	Events.projectile_flash.emit(position, Vector2.UP, _data.color, true)
	Events.screen_shake.emit(2.0)
	queue_free()


## A wall of ice: a static body on the terrain layer fighters collide with.
func _add_solid_body() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = SOLID_LAYER_VALUE
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = _size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


## A snow veil slows every enemy fighter standing in it.
func _slow_enemies() -> void:
	var zone := Rect2(position - _size * 0.5, _size)
	for node in get_tree().get_nodes_in_group(Fighter.FIGHTER_GROUP):
		var other := node as Fighter
		if other != null and other.player_id != owner_id and zone.has_point(other.global_position + Vector2(0.0, -12.0)):
			other.slow_down(_data.slow_scale)


## Destroys every enemy projectile overlapping this one (traps and other absorbers excepted).
func _absorb_enemy_shots() -> void:
	var mine := Rect2(position - _size * 0.5, _size)
	for node in get_tree().get_nodes_in_group(SHOT_GROUP):
		var other := node as Projectile
		if other == null or other.owner_id == owner_id or other.is_trap() or other.is_queued_for_deletion():
			continue
		if other._data.absorbs:
			continue
		if mine.intersects(Rect2(other.position - other._size * 0.5, other._size)):
			if _data.solid and _data.wall_health > 0.0:
				_wear(other._move.damage * other._damage_scale)
			other.queue_free()


func _draw() -> void:
	if _data == null:
		return
	if _data.style != &"":
		var local_trail := PackedVector2Array()
		for point in _trail:
			local_trail.append(point - position)
		var angle := _velocity.angle() if _velocity != Vector2.ZERO else (0.0 if _facing > 0 else PI)
		ProjectileArt.draw(self, _data.style, _size, _wall_tint(), angle, _age, local_trail, _data.rim)
		return
	if _art != null:
		_draw_art()
		return
	var half := _size * 0.5
	var outer := PackedVector2Array([
		Vector2(-half.x, 0.0), Vector2(0.0, -half.y), Vector2(half.x, 0.0), Vector2(0.0, half.y)
	])
	draw_colored_polygon(outer, _data.color)
	var inner := PackedVector2Array()
	for point in outer:
		inner.append(point * CORE_SCALE)
	draw_colored_polygon(inner, Color.WHITE)


## The effect sprite, shrunk to fit the hitbox (never stretched out of shape),
## turned along the flight direction and mirrored when flying left.
func _draw_art() -> void:
	var texture_size := _art.get_size()
	var fit := minf(_size.x / texture_size.x, _size.y / texture_size.y)
	var drawn := texture_size * maxf(fit, MIN_ART_SCALE)
	var angle := _velocity.angle() if _velocity != Vector2.ZERO else (0.0 if _facing > 0 else PI)
	var flip := -1.0 if absf(angle) > PI * 0.5 else 1.0
	draw_set_transform(Vector2.ZERO, angle, Vector2(1.0, flip))
	draw_texture_rect(_art, Rect2(-drawn * 0.5, drawn), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_ultimate_started(player_id: int, freeze_frames: int, _title: String) -> void:
	if player_id != owner_id:
		_freeze_left = maxi(_freeze_left, freeze_frames)


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or not hurtbox.is_active:
		return
	if hurtbox.fighter_id == owner_id or _already_hit.has(hurtbox) or _data.slow_scale < 1.0:
		return
	_already_hit.append(hurtbox)
	var info := HitInfo.new()
	info.attacker_id = owner_id
	info.damage = _move.damage * _damage_scale
	info.base_knockback = _move.base_knockback * _data.knockback_scale
	info.knockback_growth = _move.knockback_growth * _data.knockback_scale
	info.direction = Knockback.direction(_move.angle_degrees, _facing)
	info.projectile = self
	info.move = _move
	if not hurtbox.evades(info):
		hit_landed.emit(info)
	hurtbox.receive_hit(info)
	if _reflected_now:
		_reflected_now = false
		return # a parry sent it back: it lives on
	if not _pierce:
		queue_free()
