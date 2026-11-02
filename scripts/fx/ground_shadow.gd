class_name GroundShadow
extends Node2D
## A soft round shadow on the ground under a fighter, the same for every
## character. A ray looks straight down for the floor or platform below; the
## shadow shrinks and fades the higher the fighter is. Visual only.

const MAX_DROP := 140.0
const BASE_RADIUS := 14.0
const SQUASH := 0.28
const MAX_ALPHA := 0.6
const RINGS := 5

var _owner_body: CollisionObject2D
var _drop: float = 0.0
var _found: bool = false


func setup(owner_body: CollisionObject2D) -> void:
	_owner_body = owner_body
	top_level = true # the shadow stays on the ground while the fighter moves


## Distance from `from` down to the floor, or -1 when nothing is below within MAX_DROP.
static func find_drop(space: PhysicsDirectSpaceState2D, from: Vector2, mask: int, exclude: Array[RID]) -> float:
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, MAX_DROP), mask)
	query.exclude = exclude
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return -1.0
	return (hit["position"] as Vector2).y - from.y


## Size and opacity of the shadow for a given height above the ground (0..1 each).
static func look_for_drop(drop: float) -> Vector2:
	var height := clampf(drop / MAX_DROP, 0.0, 1.0)
	return Vector2(1.0 - 0.5 * height, 1.0 - height)


func _physics_process(_delta: float) -> void:
	if _owner_body == null or not _owner_body.visible:
		visible = false
		return
	var origin := _owner_body.global_position + Vector2(0.0, -2.0)
	var space := get_world_2d().direct_space_state
	var drop := find_drop(space, origin, _owner_body.collision_mask, [_owner_body.get_rid()])
	_found = drop >= 0.0
	visible = _found
	if _found:
		_drop = drop
		global_position = origin + Vector2(0.0, drop)
		queue_redraw()


func _draw() -> void:
	if not _found:
		return
	var look := look_for_drop(_drop)
	for ring in RINGS:
		var fraction := 1.0 - float(ring) / float(RINGS)
		var radius := BASE_RADIUS * look.x * fraction
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SQUASH))
		draw_circle(Vector2.ZERO, radius, Color(0.0, 0.0, 0.0, MAX_ALPHA * look.y / float(RINGS)))
	# A thin ring in the player's colour so you can tell the fighters apart on the ground.
	var ring_color := Color(0.95, 0.3, 0.3) if _player_id() == 1 else Color(0.3, 0.55, 0.95)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SQUASH))
	draw_arc(Vector2.ZERO, BASE_RADIUS * look.x * 0.85, 0.0, TAU, 24, Color(ring_color, 0.55 * look.y), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _player_id() -> int:
	if _owner_body == null:
		return 1
	return int(_owner_body.get("player_id")) if _owner_body.get("player_id") != null else 1
