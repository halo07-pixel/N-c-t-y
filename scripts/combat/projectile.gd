class_name Projectile
extends Area2D
## A flying (or stationary) attack fired by a special move. It reports a landed
## hit with a signal; the hurtbox it touches handles the rest, exactly like a hitbox.

signal hit_landed(info: HitInfo)

const HURTBOX_LAYER_VALUE := 16 # physics layer 5
const OFFSCREEN_LIMIT := 1600.0
const CORE_SCALE := 0.55
const MIN_ART_SCALE := 0.35
const TRAP_GROUP := &"traps"
const SHOT_GROUP := &"shots"
const COMMAND_GROUP := &"commandable"
const COMMAND_DAMAGE_SCALE := 1.3
const COMMAND_MIN_LIFE := 50

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
var _trail: Array[Vector2] = []


## Sets everything up; call before adding to the scene tree.
func launch(
	data: ProjectileData, move: MoveData, id: int, facing: int, damage_scale: float, origin: Vector2,
	size_scale: float = 1.0, speed_scale: float = 1.0, force_pierce: bool = false
) -> void:
	_data = data
	_move = move
	owner_id = id
	_facing = facing
	_damage_scale = damage_scale
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


func _ready() -> void:
	add_to_group(SHOT_GROUP)
	if _data != null and _data.commandable:
		add_to_group(COMMAND_GROUP)
	if is_trap():
		add_to_group(TRAP_GROUP)
	area_entered.connect(_on_area_entered)
	Events.ultimate_started.connect(_on_ultimate_started)
	if _data != null and _data.style != &"" and not _data.trap:
		Events.projectile_flash.emit(position, _velocity.normalized(), _data.color, false)
	if _data != null and _data.style != &"":
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
		z_index = 10


func _process(_delta: float) -> void:
	if _data != null and _data.style != &"":
		queue_redraw()


func _physics_process(delta: float) -> void:
	if _freeze_left > 0:
		_freeze_left -= 1
		return
	position += _velocity * delta
	if _data.absorbs:
		_absorb_enemy_shots()
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
			other.queue_free()


func _draw() -> void:
	if _data == null:
		return
	if _data.style != &"":
		var local_trail := PackedVector2Array()
		for point in _trail:
			local_trail.append(point - position)
		var angle := _velocity.angle() if _velocity != Vector2.ZERO else (0.0 if _facing > 0 else PI)
		ProjectileArt.draw(self, _data.style, _size, _data.color, angle, _age, local_trail)
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
	if hurtbox.fighter_id == owner_id or _already_hit.has(hurtbox):
		return
	_already_hit.append(hurtbox)
	var info := HitInfo.new()
	info.attacker_id = owner_id
	info.damage = _move.damage * _damage_scale
	info.base_knockback = _move.base_knockback
	info.knockback_growth = _move.knockback_growth
	info.direction = Knockback.direction(_move.angle_degrees, _facing)
	if not hurtbox.evading:
		hit_landed.emit(info)
	hurtbox.receive_hit(info)
	if not _pierce:
		queue_free()
