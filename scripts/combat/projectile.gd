class_name Projectile
extends Area2D
## A flying (or stationary) attack fired by a special move. It reports a landed
## hit with a signal; the hurtbox it touches handles the rest, exactly like a hitbox.

signal hit_landed(info: HitInfo)

const HURTBOX_LAYER_VALUE := 16 # physics layer 5
const OFFSCREEN_LIMIT := 1600.0
const CORE_SCALE := 0.55

var owner_id: int = 0

var _data: ProjectileData
var _move: MoveData
var _facing: int = 1
var _damage_scale: float = 1.0
var _velocity: Vector2 = Vector2.ZERO
var _frames_left: int = 0
var _freeze_left: int = 0
var _already_hit: Array[Hurtbox] = []


## Sets everything up; call before adding to the scene tree.
func launch(
	data: ProjectileData, move: MoveData, id: int, facing: int, damage_scale: float, origin: Vector2
) -> void:
	_data = data
	_move = move
	owner_id = id
	_facing = facing
	_damage_scale = damage_scale
	_velocity = Vector2(data.velocity.x * float(facing), data.velocity.y)
	_frames_left = data.lifetime_frames
	top_level = true
	position = origin + Vector2(data.offset.x * float(facing), data.offset.y)
	collision_layer = 0
	collision_mask = HURTBOX_LAYER_VALUE
	monitorable = false
	var rectangle := RectangleShape2D.new()
	rectangle.size = data.size
	var shape := CollisionShape2D.new()
	shape.shape = rectangle
	add_child(shape)


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	Events.ultimate_started.connect(_on_ultimate_started)


func _physics_process(delta: float) -> void:
	if _freeze_left > 0:
		_freeze_left -= 1
		return
	position += _velocity * delta
	_frames_left -= 1
	if _frames_left <= 0 or position.length() > OFFSCREEN_LIMIT:
		queue_free()


func _draw() -> void:
	if _data == null:
		return
	var half := _data.size * 0.5
	var outer := PackedVector2Array([
		Vector2(-half.x, 0.0), Vector2(0.0, -half.y), Vector2(half.x, 0.0), Vector2(0.0, half.y)
	])
	draw_colored_polygon(outer, _data.color)
	var inner := PackedVector2Array()
	for point in outer:
		inner.append(point * CORE_SCALE)
	draw_colored_polygon(inner, Color.WHITE)


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
	hit_landed.emit(info)
	hurtbox.receive_hit(info)
	if not _data.pierce:
		queue_free()
