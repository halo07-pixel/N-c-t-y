class_name Hitbox
extends Area2D
## The damaging area of an attack. Attack states switch it on and off; when it
## touches an enemy hurtbox it reports through `hit_landed`. Each activation
## hits a given hurtbox at most once.

signal hit_landed(info: HitInfo)

## Developer aid: draws active hitboxes as translucent red boxes (F2 in the overlay).
static var show_debug: bool = false

const DEBUG_COLOR := Color(1.0, 0.2, 0.2, 0.4)

var fighter_id: int = 0
var is_active: bool = false

var _move: MoveData
var _facing: int = 1
var _damage_scale: float = 1.0
var _already_hit: Array[Hurtbox] = []
## Physics frame of the last deactivate(). A fighter hit in the same tick as it
## swings still lands its own hit, so simultaneous hits trade instead of one being lost.
var _deactivated_frame: int = -1

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func setup(id: int) -> void:
	fighter_id = id


func activate(move: MoveData, facing: int, damage_scale: float = 1.0) -> void:
	_move = move
	_facing = facing
	_damage_scale = damage_scale
	_already_hit.clear()
	var rectangle := RectangleShape2D.new()
	rectangle.size = move.hitbox_size
	_shape.shape = rectangle
	_shape.position = Vector2(move.hitbox_offset.x * float(facing), move.hitbox_offset.y)
	is_active = true
	set_deferred("monitoring", true)
	queue_redraw()


## Stretches the hitbox so it covers everything between where the fighter was (`from`) and now
## (`to`): a dash or a teleport hurts whoever is on its path, not only whoever is at the end.
func cover_path(from: Vector2, to: Vector2) -> void:
	if not is_active or _move == null or _move.hitbox_size.x <= 0.0:
		return
	var size := _move.hitbox_size
	var offset := Vector2(_move.hitbox_offset.x * float(_facing), _move.hitbox_offset.y)
	var start := Rect2(from + offset - size * 0.5, size)
	var end := Rect2(to + offset - size * 0.5, size)
	var box := start.merge(end)
	var rectangle := RectangleShape2D.new()
	rectangle.size = box.size
	_shape.shape = rectangle
	_shape.position = box.get_center() - global_position
	queue_redraw()


func deactivate() -> void:
	if is_active:
		_deactivated_frame = Engine.get_physics_frames()
	is_active = false
	set_deferred("monitoring", false)
	queue_redraw()


func _process(_delta: float) -> void:
	if is_active and show_debug:
		queue_redraw()


func _draw() -> void:
	if not (is_active and show_debug) or _shape.shape == null:
		return
	var size := (_shape.shape as RectangleShape2D).size
	draw_rect(Rect2(_shape.position - size * 0.5, size), DEBUG_COLOR)


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or not hurtbox.is_active:
		return
	var swung_this_tick := _deactivated_frame == Engine.get_physics_frames()
	if not (is_active or swung_this_tick):
		return
	if hurtbox.fighter_id == fighter_id or _already_hit.has(hurtbox):
		return
	_already_hit.append(hurtbox)
	var info := HitInfo.new()
	info.attacker_id = fighter_id
	info.damage = _move.damage * _damage_scale
	info.base_knockback = _move.base_knockback
	info.knockback_growth = _move.knockback_growth
	info.direction = Knockback.direction(_move.angle_degrees, _facing)
	info.is_throw = _move.is_throw
	if not hurtbox.evading:
		hit_landed.emit(info)
	hurtbox.receive_hit(info)
